#!/usr/bin/env bash
# Build a prod Android release bundle or APK against valiark-prod.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_PROD="$ROOT/.env.prod"
if [[ ! -f "$ENV_PROD" ]]; then
  echo "Create .env.prod from .env.prod.example first." >&2
  exit 1
fi

node "$ROOT/scripts/check-prod-config.mjs"

ORIGINAL_ENV_EXISTS=0
BACKUP_ENV="$(mktemp "${TMPDIR:-/tmp}/whoeats-env.XXXXXX")"

sanitize_env_file() {
  local src="$1"
  local dst="$2"
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$src" > "$dst"
}

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
  cp "$ENV_PROD" "$BACKUP_ENV"
fi

sanitize_env_file "$ENV_PROD" .env

case "${1:-appbundle}" in
  appbundle)
    shift || true
    flutter build appbundle --release "$@"
    ;;
  apk)
    shift || true
    flutter build apk --release "$@"
    ;;
  *)
    echo "Usage: $0 [appbundle|apk] [flutter build args...]" >&2
    exit 1
    ;;
esac
