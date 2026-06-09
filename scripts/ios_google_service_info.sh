#!/usr/bin/env bash
# Swap the active iOS GoogleService-Info.plist between dev and prod.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEV_PLIST="$ROOT/ios/Runner/GoogleService-Info.plist"
PROD_PLIST="$ROOT/ios/Runner/GoogleService-Info prod.plist"
BACKUP_PLIST="${TMPDIR:-/tmp}/whoeats-ios-GoogleService-Info.dev.plist"

usage() {
  echo "Usage: $0 dev|prod|status" >&2
  exit 1
}

mode="${1:-}"
[[ -z "$mode" ]] && usage

case "$mode" in
  status)
    if [[ -f "$BACKUP_PLIST" ]]; then
      echo "active: prod"
    else
      echo "active: dev"
    fi
    ;;
  dev)
    if [[ -f "$BACKUP_PLIST" ]]; then
      cp "$BACKUP_PLIST" "$DEV_PLIST"
      rm -f "$BACKUP_PLIST"
    fi
    echo "Switched active iOS plist to dev."
    ;;
  prod)
    if [[ ! -f "$BACKUP_PLIST" ]]; then
      cp "$DEV_PLIST" "$BACKUP_PLIST"
    fi
    cp "$PROD_PLIST" "$DEV_PLIST"
    echo "Switched active iOS plist to prod."
    ;;
  *)
    usage
    ;;
esac
