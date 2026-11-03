#!/bin/sh
# Simule un import NOTAM : insère (ou met à jour) quelques vols dans PostgreSQL.
# Utilisé par le Job et le CronJob du TP4/TP6. Image : postgres:16-alpine (contient psql).
set -eu
: "${DATABASE_URL:?DATABASE_URL manquante}"
STAMP=$(date +%H:%M)
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
CREATE TABLE IF NOT EXISTS flights(flight TEXT PRIMARY KEY, origin TEXT, dest TEXT, sched TEXT, status TEXT);
INSERT INTO flights VALUES
  ('AF7520','LFBO','LFPO','07:10','Departed'),
  ('EZY4411','LFBO','EGKK','08:05','Boarding'),
  ('AF7704','LFPO','LFBO','09:40','On time'),
  ('VY8903','LEBL','LFBO','10:15','Delayed'),
  ('IMP$(date +%H%M)','LFBO','LFMN','$STAMP','Imported')
ON CONFLICT (flight) DO UPDATE SET status = EXCLUDED.status, sched = EXCLUDED.sched;
SELECT count(*) AS vols FROM flights;
SQL
echo "import terminé à $STAMP"
