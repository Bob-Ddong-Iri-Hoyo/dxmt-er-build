#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DXMT_TAG="${DXMT_TAG:-v0.80}"
DXMT_SRC="${DXMT_SRC:-$ROOT/sources/dxmt-$DXMT_TAG}"
DXMT_RUNTIME="${DXMT_RUNTIME:-$ROOT/dxmt-runtime}"
LLVM_PROJECT_SRC="${LLVM_PROJECT_SRC:-$ROOT/sources/llvm-project-llvmorg-15.0.7}"
LLVM_MINGW_INSTALL="${LLVM_MINGW_INSTALL:-$ROOT/toolchains/llvm-mingw-20260407-ucrt-macos-universal}"
WINE_BUILD="${WINE_BUILD:-}"
WINE_SOURCE="${WINE_SOURCE:-}"
LICENSE_ROOT="$DXMT_RUNTIME/share/licenses"

die() {
  echo "error: $*" >&2
  exit 1
}

copy_required() {
  local source_file="$1"
  local destination_file="$2"

  [[ -f "$source_file" ]] || die "missing license file: $source_file"
  mkdir -p "$(dirname "$destination_file")"
  cp -p "$source_file" "$destination_file"
}

if [[ -z "$WINE_SOURCE" && -n "$WINE_BUILD" && -f "$WINE_BUILD/Makefile" ]]; then
  WINE_SOURCE="$(sed -n 's/^srcdir = //p' "$WINE_BUILD/Makefile" | head -n 1)"
fi
[[ -n "$WINE_SOURCE" ]] || die "set WINE_BUILD or WINE_SOURCE to the exact Wine source used by this runtime"
[[ -d "$DXMT_RUNTIME" ]] || die "missing DXMT runtime: $DXMT_RUNTIME"

mkdir -p "$LICENSE_ROOT"

copy_required "$ROOT/LICENSES/DXMT-LICENSE" "$DXMT_RUNTIME/LICENSE"
copy_required "$ROOT/COPYING.LIB" "$DXMT_RUNTIME/COPYING.LIB"
copy_required "$ROOT/LICENSE.OLD" "$DXMT_RUNTIME/LICENSE.OLD"
copy_required "$ROOT/THIRD_PARTY_NOTICES.md" "$DXMT_RUNTIME/THIRD_PARTY_NOTICES.md"

copy_required "$ROOT/LICENSES/DXMT-LICENSE" "$LICENSE_ROOT/dxmt/LICENSE"
copy_required "$ROOT/COPYING.LIB" "$LICENSE_ROOT/dxmt/COPYING.LIB"
copy_required "$ROOT/LICENSE.OLD" "$LICENSE_ROOT/dxmt/LICENSE.OLD"
copy_required "$ROOT/THIRD_PARTY_NOTICES.md" "$LICENSE_ROOT/dxmt/THIRD_PARTY_NOTICES.md"
copy_required "$ROOT/LICENSE" "$LICENSE_ROOT/project/MIT.txt"
copy_required "$ROOT/LICENSES/README.md" "$LICENSE_ROOT/project/LICENSE-SCOPE.md"

copy_required "$DXMT_SRC/src/util/dxvk.LICENSE" "$LICENSE_ROOT/dxvk/LICENSE"
copy_required "$DXMT_SRC/include/native/directx/COPYING.MinGW-w64.txt" \
  "$LICENSE_ROOT/mingw-w64/COPYING.MinGW-w64.txt"
copy_required "$LLVM_PROJECT_SRC/llvm/LICENSE.TXT" "$LICENSE_ROOT/llvm/LICENSE.TXT"
copy_required "$LLVM_MINGW_INSTALL/LICENSE.TXT" "$LICENSE_ROOT/llvm-mingw/LICENSE.TXT"
copy_required "$WINE_SOURCE/LICENSE" "$LICENSE_ROOT/wine/LICENSE"
copy_required "$WINE_SOURCE/COPYING.LIB" "$LICENSE_ROOT/wine/COPYING.LIB"

upstream_commit="$(git -C "$DXMT_SRC" rev-parse HEAD)"
patch_source_commit="$(git -C "$ROOT" rev-parse HEAD)"
patch_source_url="${DXMT_PATCH_SOURCE_URL:-https://github.com/Bob-Ddong-Iri-Hoyo/dxmt-er-build}"

{
  printf 'component=DXMT\n'
  printf 'upstream_url=https://github.com/3Shain/dxmt.git\n'
  printf 'upstream_tag=%s\n' "$DXMT_TAG"
  printf 'upstream_commit=%s\n' "$upstream_commit"
  printf 'patch_source_url=%s\n' "$patch_source_url"
  printf 'patch_source_commit=%s\n' "$patch_source_commit"
  printf 'patches:\n'
  for patch_file in "$ROOT"/patches/*.patch; do
    [[ -f "$patch_file" ]] || continue
    printf '  %s  %s\n' "$(shasum -a 256 "$patch_file" | awk '{print $1}')" "$(basename "$patch_file")"
  done
} > "$LICENSE_ROOT/SOURCE-PROVENANCE.txt"

if grep -R -Fq '/Users/' "$LICENSE_ROOT"; then
  die "generated license bundle contains a private absolute path"
fi

echo "DXMT license bundle staged: $LICENSE_ROOT"
