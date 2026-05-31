#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PUBLIC_SUPABASE_URL:-}" ]]; then
  echo "PUBLIC_SUPABASE_URL is required" >&2
  exit 1
fi

if [[ -z "${PUBLIC_SUPABASE_ANON_KEY:-}" ]]; then
  echo "PUBLIC_SUPABASE_ANON_KEY is required" >&2
  exit 1
fi

if [[ "$PUBLIC_SUPABASE_ANON_KEY" == *"sbp_"* || "$PUBLIC_SUPABASE_ANON_KEY" == *"service_role"* ]]; then
  echo "Do not use Supabase PAT or service_role key in frontend config" >&2
  exit 1
fi

cat > personal_admin_site/config.js <<EOF
window.APP_CONFIG = {
  supabaseUrl: "${PUBLIC_SUPABASE_URL}",
  supabaseAnonKey: "${PUBLIC_SUPABASE_ANON_KEY}"
};
EOF

echo "Cloudflare config generated"
