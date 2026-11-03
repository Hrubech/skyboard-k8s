"""SkyBoard API — tableau des vols minimaliste, conçu pour être « Kubernetes-ready ».

Tout ce qu'un développeur doit savoir faire pour Kubernetes est ici :
- configuration par variables d'environnement (12 factors)
- /healthz (liveness) et /readyz (readiness) distincts
- arrêt propre sur SIGTERM (drain avant de quitter)
- dépendances externes optionnelles (Redis, PostgreSQL) avec repli
- logs sur stdout
"""
import asyncio
import logging
import os
import signal
import socket
import sys
import time
from contextlib import asynccontextmanager

from fastapi import APIRouter, FastAPI, HTTPException, Query, Response

# --- Configuration (uniquement via l'environnement) --------------------------
AIRPORT = os.getenv("AIRPORT", "LFBO")              # Toulouse-Blagnac par défaut
APP_VERSION = os.getenv("APP_VERSION", "v1")
FEATURE_BANNER = os.getenv("FEATURE_BANNER", "")     # bannière affichée par le front (v2)
REDIS_HOST = os.getenv("REDIS_HOST")                 # optionnel
DATABASE_URL = os.getenv("DATABASE_URL")             # optionnel, ex: postgresql://user:pwd@postgres:5432/skyboard
SHUTDOWN_DELAY = float(os.getenv("SHUTDOWN_DELAY", "5"))  # secondes de drain avant arrêt
PORT = int(os.getenv("PORT", "8000"))
HOSTNAME = socket.gethostname()

logging.basicConfig(stream=sys.stdout, level=logging.INFO,
                    format="%(asctime)s %(levelname)s [%(name)s] %(message)s")
log = logging.getLogger("skyboard")

if "AIRPORT" not in os.environ:
    log.warning("AIRPORT non défini, valeur par défaut %s", AIRPORT)

# Données de repli si pas de base
FLIGHTS = [
    {"flight": "AF7520", "from": "LFBO", "to": "LFPO", "std": "07:10", "status": "Departed"},
    {"flight": "EZY4411", "from": "LFBO", "to": "EGKK", "std": "08:05", "status": "Boarding"},
    {"flight": "AF7704", "from": "LFPO", "to": "LFBO", "sta": "09:40", "status": "On time"},
    {"flight": "VY8903", "from": "LEBL", "to": "LFBO", "sta": "10:15", "status": "Delayed"},
]

STATE = {"ready": True, "deadlock": False, "draining": False, "started_at": time.time()}


# --- Cycle de vie : démarrage et arrêt propre ---------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("démarrage %s version=%s aéroport=%s", HOSTNAME, APP_VERSION, AIRPORT)
    loop = asyncio.get_running_loop()

    def _on_sigterm(*_):
        # 1. on cesse d'être « ready » : Kubernetes nous retire des Endpoints
        # 2. on laisse SHUTDOWN_DELAY secondes aux requêtes en cours
        # 3. uvicorn termine (le handler par défaut est rétabli ensuite)
        STATE["ready"] = False
        STATE["draining"] = True
        log.info("SIGTERM reçu : draining pendant %.0fs", SHUTDOWN_DELAY)
        loop.call_later(SHUTDOWN_DELAY, lambda: os.kill(os.getpid(), signal.SIGINT))

    loop.add_signal_handler(signal.SIGTERM, _on_sigterm)
    yield
    log.info("arrêt terminé %s", HOSTNAME)


app = FastAPI(title="SkyBoard API", version=APP_VERSION, lifespan=lifespan)
# Les routes sont servies à la racine ET sous /api : un Ingress peut router /api sans réécriture.
api = APIRouter()


# --- Dépendances optionnelles --------------------------------------------------
def _redis():
    if not REDIS_HOST:
        return None
    import redis  # import tardif : la lib n'est utile que si Redis est configuré
    return redis.Redis(host=REDIS_HOST, port=int(os.getenv("REDIS_PORT", "6379")), socket_timeout=1)


def _flights_from_db():
    import psycopg
    with psycopg.connect(DATABASE_URL, connect_timeout=2) as conn:
        conn.execute("""CREATE TABLE IF NOT EXISTS flights(
            flight TEXT PRIMARY KEY, origin TEXT, dest TEXT, sched TEXT, status TEXT)""")
        rows = conn.execute("SELECT flight, origin, dest, sched, status FROM flights ORDER BY sched").fetchall()
    return [{"flight": f, "from": o, "to": d, "std": s, "status": st} for f, o, d, s, st in rows]


# --- Endpoints métier ----------------------------------------------------------
@api.get("/")
def root():
    return {"service": "skyboard-api", "version": APP_VERSION, "airport": AIRPORT,
            "banner": FEATURE_BANNER, "pod": HOSTNAME}


@api.get("/version")
def version():
    return {"version": APP_VERSION, "pod": HOSTNAME}


@api.get("/flights")
def flights():
    visits = None
    r = _redis()
    if r is not None:
        try:
            visits = r.incr(f"skyboard:{AIRPORT}:visits")
        except Exception as exc:  # Redis indisponible : on dégrade, on ne plante pas
            log.warning("redis indisponible: %s", exc)
    source = "memory"
    data = FLIGHTS
    if DATABASE_URL:
        try:
            data = _flights_from_db() or FLIGHTS
            source = "postgresql"
        except Exception as exc:
            log.error("base indisponible: %s", exc)
            raise HTTPException(status_code=503, detail="base de données indisponible")
    return {"airport": AIRPORT, "version": APP_VERSION, "source": source,
            "visits": visits, "pod": HOSTNAME, "flights": data}


# --- Sondes --------------------------------------------------------------------
@api.get("/healthz")
async def healthz():
    """Liveness : le process est-il sain ? Ne teste JAMAIS les dépendances externes."""
    if STATE["deadlock"]:
        await asyncio.sleep(3600)  # simule un process bloqué : la sonde expire
    return {"status": "ok"}


@api.get("/readyz")
def readyz(response: Response):
    """Readiness : puis-je recevoir du trafic maintenant ?"""
    if not STATE["ready"]:
        response.status_code = 503
        return {"status": "not ready", "draining": STATE["draining"]}
    return {"status": "ready", "uptime_s": round(time.time() - STATE["started_at"])}


# --- Endpoints d'administration pour les TP (jamais en prod !) -----------------
@api.post("/admin/ready")
def set_ready(state: bool = Query(...)):
    STATE["ready"] = state
    log.info("readiness forcée à %s", state)
    return {"ready": state}


@api.post("/admin/deadlock")
def deadlock():
    STATE["deadlock"] = True
    log.error("deadlock simulé : /healthz ne répondra plus")
    return {"deadlock": True}


app.include_router(api)
app.include_router(api, prefix="/api")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, log_level="info")
