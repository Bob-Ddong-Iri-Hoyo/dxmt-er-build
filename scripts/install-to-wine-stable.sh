#!/usr/bin/env bash
set -eu

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DXMT_TAG="${DXMT_TAG:-v0.80}"
APP_WINE="${APP_WINE:-/Applications/Wine Stable.app/Contents/Resources/wine}"
DXMT_RUNTIME="${DXMT_RUNTIME:-$ROOT/dxmt-runtime}"
BACKUP_ROOT="${BACKUP_ROOT:-$ROOT/backups}"

if [ ! -d "$DXMT_RUNTIME/x86_64-windows" ]; then
  echo "missing DXMT runtime: $DXMT_RUNTIME" >&2
  echo "run ./scripts/build-dxmt.sh first, or set DXMT_RUNTIME" >&2
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
backup_tag="$(printf '%s' "$DXMT_TAG" | tr '/ ' '--')"
BACKUP="$BACKUP_ROOT/wine-stable-builtin-before-$backup_tag-builtin-$STAMP"

mkdir -p "$BACKUP/x86_64-windows" "$BACKUP/i386-windows" "$BACKUP/x86_64-unix"

for dll in dxgi.dll d3d11.dll d3d10core.dll winemetal.dll; do
  cp -p "$APP_WINE/lib/wine/x86_64-windows/$dll" "$BACKUP/x86_64-windows/$dll"
  cp -p "$APP_WINE/lib/wine/i386-windows/$dll" "$BACKUP/i386-windows/$dll"
  cp -p "$DXMT_RUNTIME/x86_64-windows/$dll" "$APP_WINE/lib/wine/x86_64-windows/$dll"
  cp -p "$DXMT_RUNTIME/i386-windows/$dll" "$APP_WINE/lib/wine/i386-windows/$dll"
done

cp -p "$APP_WINE/lib/wine/x86_64-unix/winemetal.so" "$BACKUP/x86_64-unix/winemetal.so"
cp -p "$DXMT_RUNTIME/x86_64-unix/winemetal.so" "$APP_WINE/lib/wine/x86_64-unix/winemetal.so"

echo "backup=$BACKUP"
shasum -a 256 \
  "$DXMT_RUNTIME/x86_64-windows/d3d11.dll" "$APP_WINE/lib/wine/x86_64-windows/d3d11.dll" \
  "$DXMT_RUNTIME/x86_64-windows/dxgi.dll" "$APP_WINE/lib/wine/x86_64-windows/dxgi.dll" \
  "$DXMT_RUNTIME/x86_64-unix/winemetal.so" "$APP_WINE/lib/wine/x86_64-unix/winemetal.so"
