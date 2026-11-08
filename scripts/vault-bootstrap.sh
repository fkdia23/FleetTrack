#!/usr/bin/env bash
# Configure Vault pour FleetTrack : moteur KV v2, politiques, AppRole,
# secrets de l'API, jeton opérateur.
# À lancer depuis la racine du projet : bash scripts/vault-bootstrap.sh
set -euo pipefail

VAULT_CONTAINER="ft-vault"
FRONTEND_CIDR="172.28.1.0/24"

read -r -s -p "Vault root token (saisie masquée) : " VAULT_TOKEN
echo
export VAULT_TOKEN

# Exécute la CLI vault DANS le conteneur. "-e VAULT_TOKEN" (sans valeur) transmet
# le jeton depuis l'environnement sans l'écrire dans la ligne de commande.
vault() { docker exec -i -e VAULT_TOKEN "$VAULT_CONTAINER" vault "$@"; }

echo "==> 1/7 Vault est-il déverrouillé ?"
if ! vault status >/dev/null 2>&1; then
  echo "Vault est scellé ou injoignable. Lance : docker exec -it ft-vault vault operator unseal" >&2
  exit 1
fi

echo "==> 2/7 Moteur de secrets KV v2 sur fleettrack/"
mounts="$(vault secrets list -format=json)"
if ! grep -q '"fleettrack/"' <<<"$mounts"; then
  vault secrets enable -path=fleettrack kv-v2
else
  echo "    déjà actif"
fi
vault kv metadata delete fleettrack/test >/dev/null 2>&1 || true

echo "==> 3/7 Politiques"
vault policy write fleettrack-api - < vault/policies/fleettrack-api.hcl
vault policy write fleettrack-operator - < vault/policies/fleettrack-operator.hcl

echo "==> 4/7 Méthode d'authentification AppRole + rôle fleettrack-api"
auth_methods="$(vault auth list -format=json)"
if ! grep -q '"approle/"' <<<"$auth_methods"; then
  vault auth enable approle
else
  echo "    déjà actif"
fi
vault write auth/approle/role/fleettrack-api \
  token_policies="fleettrack-api" \
  token_ttl=15m \
  token_max_ttl=1h \
  secret_id_ttl=720h \
  secret_id_bound_cidrs="$FRONTEND_CIDR" \
  token_bound_cidrs="$FRONTEND_CIDR"

echo "==> 5/7 Identifiants AppRole écrits dans secrets/"
vault read -field=role_id auth/approle/role/fleettrack-api/role-id | tr -d '\r\n' > secrets/api_vault_role_id.txt
vault write -f -field=secret_id auth/approle/role/fleettrack-api/secret-id | tr -d '\r\n' > secrets/api_vault_secret_id.txt

echo "==> 6/7 Identifiants de la base de données stockés dans Vault"
vault kv put fleettrack/api/db username=fleettrack_app password=- < secrets/app_db_password.txt

echo "==> 7/7 Jeton opérateur (8 h)"
OPERATOR_TOKEN="$(vault token create -policy=fleettrack-operator -ttl=8h -field=token)"
echo
echo "Jeton opérateur : $OPERATOR_TOKEN"
echo "Utilise-le à la place du root token. Il expire dans 8 h."