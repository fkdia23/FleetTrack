#!/usr/bin/env bash
# Affiche un access token Keycloak pour un utilisateur de test.
# Usage : bash scripts/kc-token.sh analyst1
set -euo pipefail

user="${1:?Usage: kc-token.sh <admin|commercial1|analyst1|support1>}"
password="$(cat "secrets/kc_user_${user}_password.txt")"

curl -s -X POST "http://localhost:8080/realms/fleettrack/protocol/openid-connect/token" \
  -d grant_type=password \
  -d client_id=fleettrack-api-test \
  -d username="$user" \
  --data-urlencode "password=${password}" \
| python3 -c 'import sys, json
r = json.load(sys.stdin)
if "access_token" not in r:
    sys.exit("Erreur Keycloak : " + json.dumps(r))
print(r["access_token"])'