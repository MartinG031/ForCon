#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%s)"

for name in .build dist; do
  path="$ROOT_DIR/$name"
  if [ -e "$path" ]; then
    trash="$ROOT_DIR/$name.delete-$STAMP"
    mv "$path" "$trash" 2>/dev/null || true
    if [ -e "$trash" ]; then
      rm -rf "$trash" >/dev/null 2>&1 &
    fi
  fi
done
