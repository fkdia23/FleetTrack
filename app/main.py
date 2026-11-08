import os

from fastapi import FastAPI, HTTPException
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


def read_secret(env_var: str) -> str:
    """Lit un secret depuis le fichier dont le chemin est donné par une variable d'environnement."""
    path = os.environ[env_var]
    with open(path, encoding="utf-8") as secret_file:
        return secret_file.read().strip()


APP_ENV = os.environ.get("APP_ENV", "dev")

DATABASE_URL = URL.create(
    drivername="postgresql+psycopg",
    username=os.environ["DB_USER"],
    password=read_secret("DB_PASSWORD_FILE"),
    host=os.environ["DB_HOST"],
    port=int(os.environ.get("DB_PORT", "5432")),
    database=os.environ["DB_NAME"],
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True)

app = FastAPI(
    title="FleetTrack API",
    version="0.1.0",
    docs_url="/docs" if APP_ENV == "dev" else None,
    redoc_url=None,
    openapi_url="/openapi.json" if APP_ENV == "dev" else None,
)


@app.get("/health")
def health() -> dict:
    """Liveness : le processus Python répond."""
    return {"status": "ok", "env": APP_ENV}


@app.get("/health/db")
def health_db() -> dict:
    """Readiness : la base répond ET l'authentification scram-sha-256 + pg_hba.conf sont satisfaites."""
    try:
        with engine.connect() as connection:
            row = connection.execute(
                text("SELECT current_user, current_database(), inet_client_addr()::text")
            ).one()
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")
    return {
        "status": "ok",
        "db_user": row[0],
        "db_name": row[1],
        "client_addr": row[2],
    }