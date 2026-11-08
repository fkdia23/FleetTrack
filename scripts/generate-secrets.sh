#!/usr/bin/env bash
set -euo pipefail

mkdir -p secrets

for name in \
  postgres_superuser_password \
  app_db_password \
  keycloak_db_password \
  grafana_db_password \
  keycloak_admin_password \
  grafana_admin_password \
  grafana_oidc_client_secret \
  kc_user_admin_password \
  kc_user_commercial1_password \
  kc_user_analyst1_password \
  kc_user_support1_password
do
  file="secrets/${name}.txt"
  if [ -f "$file" ]; then
    echo "[=] $file existe déjà, conservé"
  else
    head -c 96 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32 > "$file"
    echo "[+] $file généré"
  fi
done

# Fichiers remplis plus tard par scripts/vault-bootstrap.sh.
# Docker Compose exige qu'ils existent, même vides.
for name in api_vault_role_id api_vault_secret_id; do
  file="secrets/${name}.txt"
  if [ -f "$file" ]; then
    echo "[=] $file existe déjà, conservé"
  else
    : > "$file"
    echo "[+] $file créé (vide, rempli par vault-bootstrap.sh)"
  fi
done