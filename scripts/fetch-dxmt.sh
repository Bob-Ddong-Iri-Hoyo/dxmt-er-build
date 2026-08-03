#!/usr/bin/env bash
set -eu

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DXMT_REPO="${DXMT_REPO:-https://github.com/3Shain/dxmt.git}"
DXMT_TAG="${DXMT_TAG:-v0.80}"
DXMT_SRC="${DXMT_SRC:-$ROOT/sources/dxmt-$DXMT_TAG}"
PATCH="${PATCH:-$ROOT/patches/dxmt-$DXMT_TAG-sanitize-output-eternal-return.patch}"

if [ -d "$DXMT_SRC/.git" ]; then
  echo "DXMT source already exists: $DXMT_SRC"
else
  mkdir -p "$(dirname "$DXMT_SRC")"
  git clone --recursive --branch "$DXMT_TAG" "$DXMT_REPO" "$DXMT_SRC"
fi

git -C "$DXMT_SRC" submodule update --init --recursive

if git -C "$DXMT_SRC" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  echo "Patch already applied: $PATCH"
else
  git -C "$DXMT_SRC" apply "$PATCH"
  echo "Patch applied: $PATCH"
fi

git -C "$DXMT_SRC" diff --check
echo "DXMT source ready: $DXMT_SRC"
