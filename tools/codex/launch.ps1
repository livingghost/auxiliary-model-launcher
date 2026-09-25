param(
  [Parameter(Mandatory)][string]$Route,
  [Parameter(ValueFromRemainingArguments)][string[]]$Rest
)

if ($Route -match '[\\/]|^\.\.|:$') {
  Write-Error "Invalid route name: $Route"
  exit 1
}

$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$pdir = Join-Path $root "routes\$Route"
if (-not (Test-Path $pdir)) {
  Write-Error "Unknown route '$Route': $pdir not found."
  exit 1
}

$toolCfg = Join-Path $pdir 'codex.toml'
if (-not (Test-Path $toolCfg)) {
  Write-Error "Route '$Route' has no codex.toml. It is not set up for Codex."
  exit 1
}
$raw = Get-Content $toolCfg -Raw -Encoding utf8

# API key: apikey.txt wins, otherwise fall back to the <NAME>_API_KEY env var.
$keyFile = Join-Path $pdir 'apikey.txt'
if (Test-Path $keyFile) {
  $apiKey = (Get-Content $keyFile -Raw).Trim()
} else {
  $envName = ($Route.ToUpper() -replace '[^A-Z0-9]', '_') + '_API_KEY'
  if (Test-Path "Env:$envName") {
    $apiKey = (Get-Item "Env:$envName").Value
  } else {
    Write-Error "No API key for '$Route'. Create $keyFile with your key on one line, or set the $envName environment variable."
    exit 1
  }
}

# --- Codex specifics live below this line. ---
$codexHome = Join-Path $env:USERPROFILE '.codex'

# Optional model catalog: routes/<name>/codex-models.json declares model
# metadata to Codex and silences the fallback-metadata warning.
$catalogLine = ''
$catalogSrc = Join-Path $pdir 'codex-models.json'
if (Test-Path $catalogSrc) {
  $catalogDst = Join-Path $codexHome "$Route.models.json"
  Copy-Item $catalogSrc $catalogDst -Force
  $catalogPath = ($catalogDst -replace '\\', '/')
  $catalogLine = "model_catalog_json = `"$catalogPath`"`n"
}

# The launcher-managed top-level key in the fragment is moved into the
# generated Codex provider table:
#   base_url  (required)
$baseUrl = $null
$m = [regex]::Match($raw, '(?m)^\s*base_url\s*=\s*"([^"]+)"')
if ($m.Success) {
  $baseUrl = $m.Groups[1].Value
  $raw = [regex]::Replace($raw, '(?m)^\s*base_url\s*=\s*"[^"]+"\r?\n?', '')
}
if (-not $baseUrl) {
  Write-Error "codex.toml needs a top-level base_url for route '$Route'."
  exit 1
}

# Launcher convention for the env var used to pass the API key.
$envKey = 'AUX_PROVIDER_API_KEY'

$routeTable = @"

[model_providers.$Route]
name = "$Route"
base_url = "$baseUrl"
env_key = "$envKey"
"@

("model_provider = `"$Route`"`n" + $catalogLine + $raw.TrimEnd() + $routeTable) |
  Set-Content (Join-Path $codexHome "$Route.config.toml") -Encoding utf8

Set-Item -Path "Env:$envKey" -Value $apiKey
& codex --profile $Route @Rest
