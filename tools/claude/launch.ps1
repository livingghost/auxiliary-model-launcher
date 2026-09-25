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

$toolCfg = Join-Path $pdir 'claude.json'
if (-not (Test-Path $toolCfg)) {
  Write-Error "Route '$Route' has no claude.json. It is not set up for Claude Code."
  exit 1
}

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

# --- Claude Code specifics live below this line. ---
# ANTHROPIC_AUTH_TOKEN is sent as Authorization: Bearer and takes precedence
# over a saved claude.ai login immediately. Setting ANTHROPIC_API_KEY too
# would only trigger a both-set warning, so it is deliberately not set here.
Set-Item -Path 'Env:ANTHROPIC_AUTH_TOKEN' -Value $apiKey

$tcfg = Get-Content $toolCfg -Raw -Encoding utf8 | ConvertFrom-Json
if (-not $tcfg.env.ANTHROPIC_BASE_URL) {
  Write-Warning "claude.json has no env.ANTHROPIC_BASE_URL. Requests will go to the default endpoint."
}
foreach ($p in $tcfg.env.PSObject.Properties) {
  Set-Item -Path "Env:$($p.Name)" -Value $p.Value
}

& claude @Rest
