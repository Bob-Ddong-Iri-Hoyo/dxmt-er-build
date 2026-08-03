#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DXMT_TAG="${DXMT_TAG:-v0.80}"
DXMT_SRC="${DXMT_SRC:-$ROOT/sources/dxmt-$DXMT_TAG}"
WINE_PROJECT_ROOT="${WINE_PROJECT_ROOT:-$(cd "$ROOT/../wine-build" && pwd)}"
CROSSOVER_BUILD="${CROSSOVER_BUILD:-$WINE_PROJECT_ROOT/build/crossover-26.1.0}"
DIAGNOSTIC_PATCH="${DIAGNOSTIC_PATCH:-$ROOT/patches/dxmt-v0.80-crossover-26.1.0-er-diagnostic.patch}"
DXMT_BUILD="${DXMT_BUILD:-$ROOT/build-crossover-26.1.0-diagnostic}"
DXMT_RUNTIME="${DXMT_RUNTIME:-$ROOT/dxmt-runtime-crossover-26.1.0-diagnostic}"

if [[ ! -d "$CROSSOVER_BUILD" ]]; then
  echo "missing CrossOver 26.1.0 build: $CROSSOVER_BUILD" >&2
  exit 1
fi

DXMT_TAG="$DXMT_TAG" DXMT_SRC="$DXMT_SRC" "$ROOT/scripts/fetch-dxmt.sh"

if git -C "$DXMT_SRC" apply --reverse --check "$DIAGNOSTIC_PATCH" >/dev/null 2>&1; then
  echo "Diagnostic patch already applied: $DIAGNOSTIC_PATCH"
else
  git -C "$DXMT_SRC" apply --check "$DIAGNOSTIC_PATCH"
  git -C "$DXMT_SRC" apply "$DIAGNOSTIC_PATCH"
  echo "Diagnostic patch applied: $DIAGNOSTIC_PATCH"
fi

git -C "$DXMT_SRC" diff --check

WINE_BUILD="$CROSSOVER_BUILD" \
DXMT_BUILD="$DXMT_BUILD" \
DXMT_RUNTIME="$DXMT_RUNTIME" \
PACKAGE_ARTIFACT=0 \
"$ROOT/scripts/build-dxmt.sh"

echo "CrossOver 26.1.0 diagnostic DXMT runtime: $DXMT_RUNTIME"
