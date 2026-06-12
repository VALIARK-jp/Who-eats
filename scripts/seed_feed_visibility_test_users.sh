#!/usr/bin/env bash
# Seed 9-pattern feed visibility test users on linked Supabase project (default: valiark-dev).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL_FILE="$ROOT/scripts/seed_feed_visibility_test_users.sql"
REFS_FILE="$ROOT/scripts/valiark-project-refs.env"

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
if [[ -z "$PROJECT_REF" && -f "$REFS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$REFS_FILE"
  PROJECT_REF="${VALIARK_DEV_PROJECT_REF:-}"
fi
PROJECT_REF="${PROJECT_REF:-rothadmykmuxncagbwqd}"

TOKEN_RAW="$(security find-generic-password -s "Supabase CLI" -w 2>/dev/null || true)"
if [[ -z "$TOKEN_RAW" ]]; then
  echo "Supabase CLI access token not found. Run: supabase login" >&2
  exit 1
fi
TOKEN="$(printf '%s' "$TOKEN_RAW" | sed 's/^go-keyring-base64://' | base64 -d)"

TMP_IMG="/tmp/vis_test_seed_upload.png"
python3 -c "
import base64, pathlib
b=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2Ze4gAAAAASUVORK5CYII=')
pathlib.Path('$TMP_IMG').write_bytes(b)
"

echo "==> Uploading shared post image to storage (skip if exists)"
supabase storage cp "$TMP_IMG" ss:///post-images/vis_test_seed/shared.png \
  --linked --yes --experimental >/dev/null 2>&1 || true
rm -f "$TMP_IMG"

SQL="$(cat "$SQL_FILE")"
PAYLOAD="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.stdin.read()}))' <<<"$SQL")"

echo "==> Seeding feed visibility test data on project: $PROJECT_REF"
RESP="$(curl -sS -X POST "https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")"

if echo "$RESP" | grep -qi '"message"'; then
  if echo "$RESP" | grep -qi '"id"'; then
    : # success array may contain objects with id
  else
  echo "$RESP" >&2
  echo "Seed may have failed. Check response above." >&2
  exit 1
  fi
fi

echo "==> Done. Log in as 134fc8a8-41ba-4403-92a2-11662b494600 and search feed for [VIS-TEST T01]..T09."
