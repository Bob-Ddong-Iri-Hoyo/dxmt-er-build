#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WINE_PROJECT_ROOT="${WINE_PROJECT_ROOT:-$(cd "$ROOT/../wine-build" && pwd)}"
CROSSOVER_ROOT="${CROSSOVER_ROOT:-$WINE_PROJECT_ROOT/artifacts/wine-crossover-26.1.0/wine-crossover-26.1.0}"
DXMT_RUNTIME="${DXMT_RUNTIME:-$ROOT/dxmt-runtime-crossover-26.1.0-diagnostic}"
DIAGNOSTIC_CROSSOVER_ROOT="${DIAGNOSTIC_CROSSOVER_ROOT:-$ROOT/crossover-26.1.0-diagnostic-runtime}"
TOOLCHAIN="${TOOLCHAIN:-$ROOT/toolchains/llvm-mingw/bin}"
TEST_BUILD="${TEST_BUILD:-$ROOT/build-crossover-26.1.0-diagnostic/smoke-test}"
TEST_PREFIX="${TEST_PREFIX:-$ROOT/test-prefix-crossover-26.1.0-diagnostic}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
DIAGNOSTICS_PATH="${DIAGNOSTICS_PATH:-$ROOT/diagnostics/crossover-26.1.0/$RUN_ID}"
SOURCE="$ROOT/tests/nonfinite-marker-smoke.c"
EXE="$TEST_BUILD/nonfinite-marker-smoke.exe"

for path in \
  "$CROSSOVER_ROOT/bin/wine" \
  "$DXMT_RUNTIME/x86_64-windows/d3d11.dll" \
  "$DXMT_RUNTIME/x86_64-unix/winemetal.so" \
  "$TOOLCHAIN/x86_64-w64-mingw32-clang" \
  "$SOURCE"; do
  if [[ ! -e "$path" ]]; then
    echo "missing: $path" >&2
    exit 1
  fi
done

mkdir -p "$TEST_BUILD" "$TEST_PREFIX" "$DIAGNOSTICS_PATH"

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

env WINEPREFIX="$TEST_PREFIX" "$CROSSOVER_ROOT/bin/wineserver" -k >/dev/null 2>&1 || true

"$TOOLCHAIN/x86_64-w64-mingw32-clang" -O2 "$SOURCE" -o "$EXE" \
  -ld3d11 -ld3dcompiler_47 -ldxgi

env \
  WINEPREFIX="$TEST_PREFIX" \
  DXMT_SHADER_CACHE=0 \
  DXMT_CONFIG='d3d11.sanitizeOutput=True;' \
  DXMT_ER_DIAGNOSTICS=1 \
  DXMT_ER_MARK_NONFINITE=1 \
  DXMT_ER_DIAGNOSTICS_PATH="$DIAGNOSTICS_PATH" \
  DXMT_LOG_PATH="$DIAGNOSTICS_PATH" \
  DXMT_LOG_LEVEL=info \
  "$DIAGNOSTIC_CROSSOVER_ROOT/bin/wine" "$EXE"

echo "diagnostics: $DIAGNOSTICS_PATH"
