$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$requiredFiles = @(
  "index.html",
  "styles.css",
  "app.js",
  "config.js",
  "supabase.sql",
  "_headers"
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path $path)) {
    throw "Missing file: $file"
  }
}

$config = Get-Content (Join-Path $root "config.js") -Raw
if ($config -match "YOUR_PROJECT_REF|YOUR_SUPABASE_ANON_KEY") {
  throw "config.js still contains placeholder values"
}

if ($config -match "sbp_|service_role") {
  throw "config.js contains a sensitive key that must not be shipped to frontend"
}

node --check (Join-Path $root "app.js")
Write-Host "Deploy check passed"
