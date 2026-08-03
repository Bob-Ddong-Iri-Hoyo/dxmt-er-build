#!/usr/bin/env bash
set -eu

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

LLVM_NATIVE_TAG="${LLVM_NATIVE_TAG:-llvmorg-15.0.7}"
LLVM_PROJECT_REPO="${LLVM_PROJECT_REPO:-https://github.com/llvm/llvm-project.git}"
LLVM_PROJECT_SRC="${LLVM_PROJECT_SRC:-$ROOT/sources/llvm-project-$LLVM_NATIVE_TAG}"
LLVM_NATIVE_BUILD="${LLVM_NATIVE_BUILD:-$ROOT/build/llvm-$LLVM_NATIVE_TAG}"
LLVM_NATIVE_INSTALL="${LLVM_NATIVE_INSTALL:-$ROOT/toolchains/llvm-$LLVM_NATIVE_TAG}"

LLVM_MINGW_VERSION="${LLVM_MINGW_VERSION:-20260407}"
LLVM_MINGW_NAME="${LLVM_MINGW_NAME:-llvm-mingw-$LLVM_MINGW_VERSION-ucrt-macos-universal}"
LLVM_MINGW_ARCHIVE="${LLVM_MINGW_ARCHIVE:-$ROOT/sources/$LLVM_MINGW_NAME.tar.xz}"
LLVM_MINGW_URL="${LLVM_MINGW_URL:-https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_MINGW_VERSION/$LLVM_MINGW_NAME.tar.xz}"
LLVM_MINGW_INSTALL="${LLVM_MINGW_INSTALL:-$ROOT/toolchains/$LLVM_MINGW_NAME}"

mkdir -p "$ROOT/sources" "$ROOT/build" "$ROOT/toolchains"

if [ ! -d "$LLVM_PROJECT_SRC/.git" ]; then
  git clone --depth 1 --branch "$LLVM_NATIVE_TAG" "$LLVM_PROJECT_REPO" "$LLVM_PROJECT_SRC"
fi

if [ ! -x "$LLVM_NATIVE_INSTALL/bin/llvm-config" ]; then
  cmake -B "$LLVM_NATIVE_BUILD" -S "$LLVM_PROJECT_SRC/llvm" \
    -DCMAKE_INSTALL_PREFIX="$LLVM_NATIVE_INSTALL" \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DLLVM_HOST_TRIPLE=x86_64-apple-darwin \
    -DLLVM_ENABLE_ASSERTIONS=On \
    -DLLVM_ENABLE_ZSTD=Off \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_TARGETS_TO_BUILD="" \
    -DLLVM_BUILD_TOOLS=Off \
    -DBUG_REPORT_URL="https://github.com/3Shain/dxmt" \
    -DPACKAGE_VENDOR="DXMT" \
    -DLLVM_VERSION_PRINTER_SHOW_HOST_TARGET_INFO=Off \
    -G Ninja
  cmake --build "$LLVM_NATIVE_BUILD" -j "$(sysctl -n hw.ncpu)"
  cmake --install "$LLVM_NATIVE_BUILD"
fi

if [ ! -f "$LLVM_MINGW_ARCHIVE" ]; then
  curl -L "$LLVM_MINGW_URL" -o "$LLVM_MINGW_ARCHIVE"
fi

if [ ! -d "$LLVM_MINGW_INSTALL/bin" ]; then
  tmp_dir="$ROOT/.extract-llvm-mingw"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  tar -xJf "$LLVM_MINGW_ARCHIVE" -C "$tmp_dir"
  rm -rf "$LLVM_MINGW_INSTALL"
  mv "$tmp_dir/$LLVM_MINGW_NAME" "$LLVM_MINGW_INSTALL"
  rm -rf "$tmp_dir"
fi

ln -sfn "$(basename "$LLVM_NATIVE_INSTALL")" "$ROOT/toolchains/llvm"
ln -sfn "$(basename "$LLVM_MINGW_INSTALL")" "$ROOT/toolchains/llvm-mingw"

echo "native LLVM: $ROOT/toolchains/llvm"
echo "llvm-mingw:  $ROOT/toolchains/llvm-mingw"
