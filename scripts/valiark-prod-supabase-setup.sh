#!/usr/bin/env bash
# Valiark prod Supabase helper for Who eats.
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

usage() {
  echo "Usage: $0 db|functions|all" >&2
  echo "  db        - supabase link + db push to valiark-prod" >&2
  echo "  functions - deploy send-push Edge Function" >&2
  echo "  all       - db then functions" >&2
  exit 1
}

cmd="${1:-}"
[[ -z "$cmd" ]] && usage

run_db() {
  echo "==> Pushing migrations to prod ref: $PROD_REF"

  if [[ -n "${SUPABASE_DB_URL:-}" ]]; then
    echo "    Using SUPABASE_DB_URL (--db-url)"
    supabase db push --db-url "$SUPABASE_DB_URL"
    echo "==> Done. Verify tables / RLS / RPCs in Dashboard."
    return
  fi

  local link_args=(--project-ref "$PROD_REF")
  local push_args=()
  if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
    link_args+=(-p "$SUPABASE_DB_PASSWORD")
    push_args+=(-p "$SUPABASE_DB_PASSWORD")
  fi

  if [[ "${DB_PUSH_SKIP_POOLER:-}" == "1" ]]; then
    link_args+=(--skip-pooler)
    echo "    WARNING: skip-pooler uses IPv6 direct host. If it fails, unset DB_PUSH_SKIP_POOLER." >&2
  fi

  if [[ -d "$ROOT/supabase/.temp" ]] && [[ "${SUPABASE_LINK_FRESH:-}" == "1" ]]; then
    rm -rf "$ROOT/supabase/.temp"
    echo "    Cleared supabase/.temp (SUPABASE_LINK_FRESH=1)"
  fi

  supabase link "${link_args[@]}"
  if [[ "${SUPABASE_DB_INCLUDE_ALL:-}" == "1" ]]; then
    push_args+=(--include-all)
    echo "    Using --include-all (SUPABASE_DB_INCLUDE_ALL=1)"
  fi
  if [[ ${#push_args[@]} -gt 0 ]]; then
    supabase db push "${push_args[@]}"
  else
    supabase db push
  fi
  echo "==> Done. Verify tables / RLS / RPCs in Dashboard."
}

run_functions() {
  echo "==> Deploying Edge Functions to prod ref: $PROD_REF"
  supabase link --project-ref "$PROD_REF"
  supabase functions deploy send-push
  echo "==> Done. If send-push is enabled, set FCM secrets as documented in docs/push_notification_prod_setup.md."
}

case "$cmd" in
  db) run_db ;;
  functions) run_functions ;;
  all)
    run_db
    run_functions
    ;;
  *) usage ;;
esac
