$ErrorActionPreference = "Stop"

if (-not $env:PUBLIC_SUPABASE_URL) {
  throw "PUBLIC_SUPABASE_URL is required"
}

if (-not $env:PUBLIC_SUPABASE_ANON_KEY) {
  throw "PUBLIC_SUPABASE_ANON_KEY is required"
}

if ($env:PUBLIC_SUPABASE_ANON_KEY -match "sbp_|service_role") {
  throw "Do not use Supabase PAT or service_role key in frontend config"
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $root "config.js"

@"
window.APP_CONFIG = {
  supabaseUrl: "$env:PUBLIC_SUPABASE_URL",
  supabaseAnonKey: "$env:PUBLIC_SUPABASE_ANON_KEY"
};
"@ | Set-Content -Encoding UTF8 $configPath

Write-Host "Local config generated"
