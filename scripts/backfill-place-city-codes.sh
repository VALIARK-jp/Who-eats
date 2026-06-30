#!/usr/bin/env bash
# 既存 whoeats_places の city_code を geolonia 境界から一括バックフィル。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" && -z "${WHOEATS_SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "SUPABASE_SERVICE_ROLE_KEY is required (service role bypasses RLS)." >&2
  exit 1
fi

ARGS=()
if [[ "${1:-}" == "--dry-run" ]]; then
  ARGS+=(--dry-run)
fi

node "$ROOT/scripts/backfill-place-city-codes.mjs" "${ARGS[@]+"${ARGS[@]}"}"
