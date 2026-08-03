#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WINE_PROJECT_ROOT="${WINE_PROJECT_ROOT:-$(cd "$ROOT/../wine-build" && pwd)}"
CROSSOVER_ROOT="${CROSSOVER_ROOT:-$WINE_PROJECT_ROOT/artifacts/wine-crossover-26.1.0/wine-crossover-26.1.0}"
SOURCE_PREFIX="${SOURCE_PREFIX:-${HOME:?}/WineSteam}"
CROSSOVER_ER_PREFIX="${CROSSOVER_ER_PREFIX:-${HOME:?}/WineSteam-CrossOver-26.1.0-FreshDiagnostic}"
SOURCE_STEAM="$SOURCE_PREFIX/drive_c/Program Files (x86)/Steam"
TARGET_STEAM="$CROSSOVER_ER_PREFIX/drive_c/Program Files (x86)/Steam"

if [[ "$SOURCE_PREFIX" == "$CROSSOVER_ER_PREFIX" ]]; then
  echo "source and target prefixes must differ" >&2
  exit 1
fi

for path in "$CROSSOVER_ROOT/bin/wine" "$SOURCE_PREFIX/system.reg" "$SOURCE_STEAM/steam.exe"; do
  if [[ ! -e "$path" ]]; then
    echo "missing: $path" >&2
    exit 1
  fi
done

mkdir -p "$CROSSOVER_ER_PREFIX"
if [[ ! -e "$CROSSOVER_ER_PREFIX/system.reg" ]]; then
  env WINEPREFIX="$CROSSOVER_ER_PREFIX" "$CROSSOVER_ROOT/bin/wine" cmd.exe /c exit
fi

if [[ ! -e "$TARGET_STEAM/steam.exe" ]]; then
  if [[ -e "$TARGET_STEAM" ]]; then
    echo "target Steam directory exists but steam.exe is missing: $TARGET_STEAM" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$TARGET_STEAM")"
  cp -cR "$SOURCE_STEAM" "$TARGET_STEAM"
fi

echo "CrossOver 26.1.0 test prefix ready: $CROSSOVER_ER_PREFIX"
