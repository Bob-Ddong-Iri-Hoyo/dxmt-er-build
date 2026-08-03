#!/usr/bin/env bash
set -eu

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DXMT_TAG="${DXMT_TAG:-v0.80}"
DXMT_RUNTIME="${DXMT_RUNTIME:-$ROOT/dxmt-runtime}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT/artifacts}"

if [ ! -d "$DXMT_RUNTIME/x86_64-windows" ]; then
  echo "missing DXMT runtime: $DXMT_RUNTIME" >&2
  echo "run ./scripts/build-dxmt.sh first, or set DXMT_RUNTIME" >&2
  exit 1
fi

if [ ! -f "$DXMT_RUNTIME/LICENSE" ] || [ ! -f "$DXMT_RUNTIME/COPYING.LIB" ] || \
   [ ! -f "$DXMT_RUNTIME/LICENSE.OLD" ] || [ ! -d "$DXMT_RUNTIME/share/licenses" ]; then
  DXMT_TAG="$DXMT_TAG" DXMT_RUNTIME="$DXMT_RUNTIME" \
    WINE_BUILD="${WINE_BUILD:-}" WINE_SOURCE="${WINE_SOURCE:-}" \
    "$ROOT/scripts/stage-dxmt-licenses.sh"
fi

artifact_tag="$(printf '%s' "$DXMT_TAG" | tr '/ ' '--')"
artifact="dxmt-$artifact_tag-builtin.tar.gz"
package_root="${artifact%.tar.gz}"

mkdir -p "$ARTIFACT_DIR"
rm -f "$ARTIFACT_DIR/$artifact" "$ARTIFACT_DIR/$artifact.sha256"

tmp_dir="$ROOT/.package-tmp"
rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"
rsync -a --delete --exclude='.DS_Store' "$DXMT_RUNTIME/" "$tmp_dir/$package_root/"

for license_file in LICENSE COPYING.LIB LICENSE.OLD THIRD_PARTY_NOTICES.md; do
  if [[ ! -f "$DXMT_RUNTIME/$license_file" ]]; then
    echo "missing staged runtime license file: $DXMT_RUNTIME/$license_file" >&2
    exit 1
  fi
  cp "$DXMT_RUNTIME/$license_file" "$tmp_dir/$package_root/$license_file"
done

(
  cd "$tmp_dir"
  tar -czf "$ARTIFACT_DIR/$artifact" "$package_root"
)

rm -rf "$tmp_dir"

(
  cd "$ARTIFACT_DIR"
  shasum -a 256 "$artifact" > "$artifact.sha256"
)

echo "$ARTIFACT_DIR/$artifact"
cat "$ARTIFACT_DIR/$artifact.sha256"
