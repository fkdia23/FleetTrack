$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path "secrets" | Out-Null

$names = @(
    "postgres_superuser_password",
    "app_db_password",
    "keycloak_db_password",
    "grafana_db_password",
    "keycloak_admin_password",
    "grafana_admin_password",
    "grafana_oidc_client_secret",
    "kc_user_admin_password",
    "kc_user_commercial1_password",
    "kc_user_analyst1_password",
    "kc_user_support1_password"
)

$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

foreach ($name in $names) {
    $path = Join-Path (Get-Location) "secrets\$name.txt"
    if (Test-Path $path) {
        Write-Host "[=] secrets\$name.txt existe deja, conserve"
        continue
    }
    $bytes = New-Object byte[] 48
    $rng.GetBytes($bytes)
    $password = ([Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]', '').Substring(0, 32)
    [System.IO.File]::WriteAllText($path, $password)
    Write-Host "[+] secrets\$name.txt genere"
}

# Fichiers remplis plus tard par scripts/vault-bootstrap.sh.
# Docker Compose exige qu'ils existent, meme vides.
foreach ($name in @("api_vault_role_id", "api_vault_secret_id")) {
    $path = Join-Path (Get-Location) "secrets\$name.txt"
    if (Test-Path $path) {
        Write-Host "[=] secrets\$name.txt existe deja, conserve"
    } else {
        [System.IO.File]::WriteAllText($path, "")
        Write-Host "[+] secrets\$name.txt cree (vide, rempli par vault-bootstrap.sh)"
    }
}