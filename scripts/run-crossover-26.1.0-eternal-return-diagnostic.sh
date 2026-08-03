#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WINE_PROJECT_ROOT="${WINE_PROJECT_ROOT:-$(cd "$ROOT/../wine-build" && pwd)}"
CROSSOVER_ROOT="${CROSSOVER_ROOT:-$WINE_PROJECT_ROOT/artifacts/wine-crossover-26.1.0/wine-crossover-26.1.0}"
DXMT_RUNTIME="${DXMT_RUNTIME:-$ROOT/dxmt-runtime-crossover-26.1.0-diagnostic}"
DIAGNOSTIC_CROSSOVER_ROOT="${DIAGNOSTIC_CROSSOVER_ROOT:-$ROOT/crossover-26.1.0-diagnostic-runtime}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
DIAGNOSTICS_PATH="${DIAGNOSTICS_PATH:-$ROOT/diagnostics/crossover-26.1.0/game-$RUN_ID}"
PROTECTED_PREFIX="${PROTECTED_PREFIX:-${HOME:?}/WineSteam}"
CROSSOVER_ER_PREFIX="${CROSSOVER_ER_PREFIX:-}"

if [[ -z "$CROSSOVER_ER_PREFIX" ]]; then
  echo "CROSSOVER_ER_PREFIX must point to a disposable CrossOver 26.1.0 test prefix." >&2
  exit 1
fi

if [[ "$CROSSOVER_ER_PREFIX" == "$PROTECTED_PREFIX" && "${ALLOW_ORIGINAL_PREFIX:-0}" != "1" ]]; then
  echo "refusing to mutate the original prefix: $PROTECTED_PREFIX" >&2
  echo "use an APFS clone and set CROSSOVER_ER_PREFIX to the clone" >&2
  exit 1
fi

STEAM_EXE="$CROSSOVER_ER_PREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
for path in \
  "$CROSSOVER_ROOT/bin/wine" \
  "$DXMT_RUNTIME/x86_64-windows/d3d11.dll" \
  "$DXMT_RUNTIME/x86_64-unix/winemetal.so" \
  "$CROSSOVER_ER_PREFIX/system.reg" \
  "$STEAM_EXE"; do
  if [[ ! -e "$path" ]]; then
    echo "missing: $path" >&2
    exit 1
  fi
done

mkdir -p "$DIAGNOSTICS_PATH"

if [[ ! -x "$DIAGNOSTIC_CROSSOVER_ROOT/bin/wine" ]]; then
  mkdir -p "$DIAGNOSTIC_CROSSOVER_ROOT"
  rsync -a "$CROSSOVER_ROOT/" "$DIAGNOSTIC_CROSSOVER_ROOT/"
fi

mkdir -p \
  "$DIAGNOSTIC_CROSSOVER_ROOT/lib/wine/x86_64-windows" \
  "$DIAGNOSTIC_CROSSOVER_ROOT/lib/wine/x86_64-unix" \
  "$DIAGNOSTIC_CROSSOVER_ROOT/lib/wine/i386-windows"
for name in d3d10core.dll d3d11.dll dxgi.dll winemetal.dll; do
  cp -p "$DXMT_RUNTIME/x86_64-windows/$name" \
    "$DIAGNOSTIC_CROSSOVER_ROOT/lib/wine/x86_64-windows/$name"
  cp -p "$DXMT_RUNTIME/i386-windows/$name" \
    "$DIAGNOSTIC_CROSSOVER_ROOT/lib/wine/i386-windows/$name"
done
cp -p "$DXMT_RUNTIME/x86_64-unix/winemetal.so" \
  "$DIAGNOSTIC_CROSSOVER_ROOT/lib/wine/x86_64-unix/winemetal.so"

env WINEPREFIX="$CROSSOVER_ER_PREFIX" \
  "$DIAGNOSTIC_CROSSOVER_ROOT/bin/wineserver" -k >/dev/null 2>&1 || true

if [[ ! -e "$CROSSOVER_ER_PREFIX/drive_c/windows/system32/winemetal.dll" ||
      ! -e "$CROSSOVER_ER_PREFIX/drive_c/windows/syswow64/winemetal.dll" ]]; then
  echo "Registering the diagnostic DXMT modules in the disposable prefix..."
  env WINEPREFIX="$CROSSOVER_ER_PREFIX" \
    "$DIAGNOSTIC_CROSSOVER_ROOT/bin/wineboot" -u
fi

echo "CrossOver runtime: $DIAGNOSTIC_CROSSOVER_ROOT"
echo "test prefix:       $CROSSOVER_ER_PREFIX"
echo "diagnostics:       $DIAGNOSTICS_PATH"
echo "When the corruption is visible, press F10 once to capture the next frame."

cd "$DIAGNOSTICS_PATH"
env \
  WINEPREFIX="$CROSSOVER_ER_PREFIX" \
  DXMT_SHADER_CACHE=0 \
  DXMT_CONFIG='d3d11.sanitizeOutput=True;' \
  DXMT_ER_DIAGNOSTICS=1 \
  DXMT_ER_MARK_NONFINITE=1 \
  DXMT_ER_DIAGNOSTICS_PATH="$DIAGNOSTICS_PATH" \
  DXMT_LOG_PATH="$DIAGNOSTICS_PATH" \
  DXMT_LOG_LEVEL=info \
  MTL_CAPTURE_ENABLED=1 \
  DXMT_CAPTURE_EXECUTABLE=EternalReturn \
  "$DIAGNOSTIC_CROSSOVER_ROOT/bin/wine" \
  'C:\Program Files (x86)\Steam\steam.exe' -applaunch 1049590

echo "diagnostics: $DIAGNOSTICS_PATH"
