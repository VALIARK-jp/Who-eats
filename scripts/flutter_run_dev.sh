#!/usr/bin/env bash
# Ensure `.env` exists for the Flutter asset bundle, then run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

sanitize_env_file() {
  local src="$1"
  local dst="$2"
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$src" > "$dst"
}

ORIGINAL_ENV_EXISTS=0
BACKUP_ENV="$(mktemp "${TMPDIR:-/tmp}/whoeats-env.XXXXXX")"
cleanup() {
  if [[ "$ORIGINAL_ENV_EXISTS" -eq 1 ]]; then
    mv -f "$BACKUP_ENV" .env
  else
    rm -f .env "$BACKUP_ENV"
  fi
}
trap cleanup EXIT INT TERM

if [[ -f .env ]]; then
  cp .env "$BACKUP_ENV"
  ORIGINAL_ENV_EXISTS=1
else
  cp .env.example "$BACKUP_ENV"
fi

sanitize_env_file "$BACKUP_ENV" .env
if [[ "$ORIGINAL_ENV_EXISTS" -eq 0 ]]; then
  echo "Created .env from .env.example — fill WHOEATS_SUPABASE_* and API keys." >&2
fi

exec flutter run "$@"
