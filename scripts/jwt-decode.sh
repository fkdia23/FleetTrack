#!/usr/bin/env bash
# Décode (sans vérifier la signature) la partie "payload" d'un JWT lu sur l'entrée standard.
# Usage : bash scripts/kc-token.sh analyst1 | bash scripts/jwt-decode.sh
set -euo pipefail

python3 -c 'import sys, json, base64
token = sys.stdin.read().strip()
payload = token.split(".")[1]
payload += "=" * (-len(payload) % 4)
print(json.dumps(json.loads(base64.urlsafe_b64decode(payload)), indent=2, ensure_ascii=False))'