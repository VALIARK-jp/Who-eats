#!/usr/bin/env bash
# Run the app locally against valiark-prod by temporarily swapping in .env.prod.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_PROD="$ROOT/.env.prod"
if [[ ! -f "$ENV_PROD" ]]; then
  echo "Create .env.prod from .env.prod.example first." >&2
  exit 1
fi

node "$ROOT/scripts/check-prod-config.mjs"
chmod +x "$ROOT/scripts/ios_google_service_info.sh"

ORIGINAL_ENV_EXISTS=0
BACKUP_ENV="$(mktemp "${TMPDIR:-/tmp}/whoeats-env.XXXXXX")"
sanitize_env_file() {
  local src="$1"
  local dst="$2"
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$src" > "$dst"
}
cleanup() {
  "$ROOT/scripts/ios_google_service_info.sh" dev >/dev/null 2>&1 || true
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
  cp "$ENV_PROD" "$BACKUP_ENV"
fi

"$ROOT/scripts/ios_google_service_info.sh" prod
sanitize_env_file "$BACKUP_ENV" .env
flutter run "$@"
