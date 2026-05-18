#!/usr/bin/env bash
# Ensure `.env` exists for the Flutter asset bundle, then run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example — fill WHOEATS_SUPABASE_* and API keys." >&2
fi

exec flutter run "$@"
