import logging
import os
import time

import hvac
import requests
from fastapi import FastAPI, HTTPException
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

logger = logging.getLogger("fleettrack")
logging.basicConfig(level=logging.INFO)


def read_secret(env_var: str) -> str:
    """Lit un secret depuis le fichier dont le chemin est donné par une variable d'environnement."""
    path = os.environ[env_var]
    with open(path, encoding="utf-8") as secret_file:
        return secret_file.read().strip()


def fetch_db_credentials_from_vault() -> tuple[str, str]:
    """Se connecte à Vault (AppRole), lit fleettrack/api/db, puis révoque son jeton."""
    vault_addr = os.environ["VAULT_ADDR"]
    role_id = read_secret("VAULT_ROLE_ID_FILE")
    secret_id = read_secret("VAULT_SECRET_ID_FILE")

    attempts = 30
    for attempt in range(1, attempts + 1):
        client = hvac.Client(url=vault_addr, timeout=5)
        try:
            client.auth.approle.login(role_id=role_id, secret_id=secret_id)
            response = client.secrets.kv.v2.read_secret_version(
                path="api/db",
                mount_point="fleettrack",
                raise_on_deleted_version=True,
            )
            data = response["data"]["data"]
            return data["username"], data["password"]
        except (hvac.exceptions.VaultDown, requests.exceptions.RequestException) as error:
            # Vault scellé, pas encore prêt ou injoignable : on réessaie.
            logger.warning(
                "Vault indisponible (%s), tentative %d/%d", type(error).__name__, attempt, attempts
            )
            time.sleep(2)
        except hvac.exceptions.VaultError as error:
            # Refus d'accès, mauvais secret_id, chemin absent : inutile de réessayer.
            raise RuntimeError(
                f"Vault a refusé la demande ({type(error).__name__}). "
                "Vérifie secrets/api_vault_*.txt et relance scripts/vault-bootstrap.sh."
            ) from None
        finally:
            if client.token:
                try:
                    client.logout(revoke_token=True)
                except Exception:
                    pass
    raise RuntimeError("Vault est resté indisponible (scellé ? lance 'vault operator unseal').")


def load_db_credentials() -> tuple[str, str]:
    """Vault en priorité ; repli sur un fichier secret uniquement hors Docker Compose."""
    if os.environ.get("VAULT_ADDR"):
        return fetch_db_credentials_from_vault()
    logger.warning("VAULT_ADDR absent : lecture du mot de passe depuis un fichier (dev local uniquement)")
    return os.environ["DB_USER"], read_secret("DB_PASSWORD_FILE")


APP_ENV = os.environ.get("APP_ENV", "dev")

DB_USER, DB_PASSWORD = load_db_credentials()

DATABASE_URL = URL.create(
    drivername="postgresql+psycopg",
    username=DB_USER,
    password=DB_PASSWORD,
    host=os.environ["DB_HOST"],
    port=int(os.environ.get("DB_PORT", "5432")),
    database=os.environ["DB_NAME"],
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True)

app = FastAPI(
    title="FleetTrack API",
    version="0.2.0",
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