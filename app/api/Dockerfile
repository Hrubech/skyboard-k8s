# --- étape 1 : dépendances --------------------------------------------------
FROM python:3.12-slim AS build
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- étape 2 : image finale, non-root ----------------------------------------
FROM python:3.12-slim
# ARG = valeur figée au build (tag), ENV = valeur par défaut surchargée par K8s
ARG APP_VERSION=v1
ENV APP_VERSION=${APP_VERSION} PORT=8000 PYTHONUNBUFFERED=1
COPY --from=build /install /usr/local
WORKDIR /app
COPY main.py .
RUN useradd --uid 10001 --no-create-home skyboard
USER 10001
EXPOSE 8000
# exec form : uvicorn est PID 1 et reçoit bien SIGTERM
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
