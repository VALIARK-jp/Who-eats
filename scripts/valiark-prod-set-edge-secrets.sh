#!/usr/bin/env bash
# Set the shared LINE channel secret on valiark-prod.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REFS_FILE="$ROOT/scripts/valiark-project-refs.env"
if [[ -f "$REFS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$REFS_FILE"
fi

PROD_REF="${VALIARK_PROD_PROJECT_REF:-}"
if [[ -z "$PROD_REF" ]]; then
  echo "Set VALIARK_PROD_PROJECT_REF in scripts/valiark-project-refs.env" >&2
  exit 1
fi

supabase link --project-ref "$PROD_REF"
supabase secrets set LINE_CHANNEL_ID="2010102462"

echo "LINE_CHANNEL_ID set on $PROD_REF."
echo "If you also need push notifications, follow docs/push_notification_prod_setup.md."
