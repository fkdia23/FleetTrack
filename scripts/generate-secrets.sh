#!/usr/bin/env bash
set -euo pipefail

mkdir -p secrets

for name in \
  postgres_superuser_password \
  app_db_password \
  keycloak_db_password \
  grafana_db_password \
  keycloak_admin_password \
  grafana_admin_password
do
  file="secrets/${name}.txt"
  if [ -f "$file" ]; then
    echo "[=] $file existe déjà, conservé"
  else
    head -c 96 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32 > "$file"
    echo "[+] $file généré"
  fi
done