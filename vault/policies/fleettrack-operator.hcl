# Politique de l'opérateur humain : remplace le root token au quotidien.

# Tous les secrets FleetTrack (data/, metadata/, delete/, destroy/ ...)
path "fleettrack/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Gestion des politiques
path "sys/policies/acl" {
  capabilities = ["list"]
}
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Gestion des rôles AppRole (rotation du secret_id)
path "auth/approle/role" {
  capabilities = ["list"]
}
path "auth/approle/role/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Lecture de l'inventaire des moteurs et méthodes d'authentification
path "sys/mounts" {
  capabilities = ["read"]
}
path "sys/auth" {
  capabilities = ["read"]
}