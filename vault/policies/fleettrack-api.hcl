# Politique de l'API : lecture seule des secrets sous api/.
# KV v2 insère "data/" dans le chemin réel : "kv put fleettrack/api/db"
# s'écrit donc "fleettrack/data/api/db" dans une politique.
path "fleettrack/data/api/*" {
  capabilities = ["read"]
}