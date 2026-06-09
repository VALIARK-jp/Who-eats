#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

required_vars=(
  SUPABASE_PROJECT_REF
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  FCM_PROJECT_ID
  FCM_SERVICE_ACCOUNT_JSON
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required env var: $var" >&2
    exit 1
  fi
done

supabase secrets set \
  --project-ref "$SUPABASE_PROJECT_REF" \
  SUPABASE_URL="$SUPABASE_URL" \
  SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
  FCM_PROJECT_ID="$FCM_PROJECT_ID" \
  FCM_SERVICE_ACCOUNT_JSON="$FCM_SERVICE_ACCOUNT_JSON"
