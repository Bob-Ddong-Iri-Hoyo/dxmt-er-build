#!/bin/sh
set -eu

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DXMT_TAG="${DXMT_TAG:-v0.80}"
DXMT_SRC="${DXMT_SRC:-$ROOT/sources/dxmt-$DXMT_TAG}"
DXMT_BUILD="${DXMT_BUILD:-$ROOT/build}"
WINE_BUILD="${WINE_BUILD:-$ROOT/wine-build/build64}"
DXMT_RUNTIME="${DXMT_RUNTIME:-$ROOT/dxmt-runtime}"
LLVM_NATIVE="${LLVM_NATIVE:-$ROOT/toolchains/llvm}"
PACKAGE_ARTIFACT="${PACKAGE_ARTIFACT:-1}"

if [ ! -d "$WINE_BUILD" ]; then
    echo "missing Wine build: $WINE_BUILD" >&2
    echo "set WINE_BUILD to a Wine build directory, or symlink it to $ROOT/wine-build/build64" >&2
    exit 1
fi
WINE_BUILD="$(cd "$WINE_BUILD" && pwd)"

if [ ! -d "$ROOT/toolchains/llvm-mingw/bin" ] || [ ! -d "$LLVM_NATIVE" ]; then
    "$ROOT/scripts/fetch-toolchains.sh"
fi

if [ ! -f "$DXMT_SRC/build-win64.txt" ]; then
    DXMT_TAG="$DXMT_TAG" DXMT_SRC="$DXMT_SRC" "$ROOT/scripts/fetch-dxmt.sh"
fi

export PATH="$ROOT/toolchains/llvm-mingw/bin:/usr/local/opt/llvm/bin:/opt/homebrew/opt/llvm/bin:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)}"
if [ -n "$SDKROOT" ]; then
    export SDKROOT
fi
export CC="clang"
export CXX="clang++"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:/opt/homebrew/lib/pkgconfig:/opt/homebrew/share/pkgconfig:${PKG_CONFIG_PATH:-}"
unset CFLAGS
unset CXXFLAGS
unset LDFLAGS
unset CPPFLAGS

rm -rf "$DXMT_BUILD/build-win64-local" "$DXMT_BUILD/build-win32-local" "$DXMT_RUNTIME"
mkdir -p "$DXMT_RUNTIME/x86_64-windows" "$DXMT_RUNTIME/i386-windows" "$DXMT_RUNTIME/x86_64-unix"

meson setup \
--cross-file "$DXMT_SRC/build-win64.txt" \
-Dnative_llvm_path="$LLVM_NATIVE" \
-Dwine_build_path="$WINE_BUILD" \
-Dwine_builtin_dll=true \
-Ddxmt_debug=false \
-Denable_nvapi=true \
-Denable_nvngx=true \
-Denable_tests=false \
--buildtype release \
"$DXMT_BUILD/build-win64-local" \
"$DXMT_SRC"

meson compile -C "$DXMT_BUILD/build-win64-local" -j "$(sysctl -n hw.ncpu)"

meson setup \
--cross-file "$DXMT_SRC/build-win32.txt" \
-Dwine_build_path="$WINE_BUILD" \
-Dwine_builtin_dll=true \
-Ddxmt_debug=false \
-Denable_tests=false \
--buildtype release \
"$DXMT_BUILD/build-win32-local" \
"$DXMT_SRC"

meson compile -C "$DXMT_BUILD/build-win32-local" -j "$(sysctl -n hw.ncpu)"

copy_one() {
    src_file="$(find "$1" -name "$2" -type f | head -n 1)"
    if [ -z "$src_file" ]; then
        echo "missing build output: $2 from $1" >&2
        exit 1
    fi
    cp "$src_file" "$3/$2"
}

copy_one "$DXMT_BUILD/build-win64-local" "d3d10core.dll" "$DXMT_RUNTIME/x86_64-windows"
copy_one "$DXMT_BUILD/build-win64-local" "d3d11.dll" "$DXMT_RUNTIME/x86_64-windows"
copy_one "$DXMT_BUILD/build-win64-local" "dxgi.dll" "$DXMT_RUNTIME/x86_64-windows"
copy_one "$DXMT_BUILD/build-win64-local" "winemetal.dll" "$DXMT_RUNTIME/x86_64-windows"
copy_one "$DXMT_BUILD/build-win64-local" "winemetal.so" "$DXMT_RUNTIME/x86_64-unix"

copy_one "$DXMT_BUILD/build-win32-local" "d3d10core.dll" "$DXMT_RUNTIME/i386-windows"
copy_one "$DXMT_BUILD/build-win32-local" "d3d11.dll" "$DXMT_RUNTIME/i386-windows"
copy_one "$DXMT_BUILD/build-win32-local" "dxgi.dll" "$DXMT_RUNTIME/i386-windows"
copy_one "$DXMT_BUILD/build-win32-local" "winemetal.dll" "$DXMT_RUNTIME/i386-windows"

DXMT_TAG="$DXMT_TAG" \
DXMT_SRC="$DXMT_SRC" \
DXMT_RUNTIME="$DXMT_RUNTIME" \
LLVM_PROJECT_SRC="$ROOT/sources/llvm-project-llvmorg-15.0.7" \
LLVM_MINGW_INSTALL="$ROOT/toolchains/llvm-mingw-20260407-ucrt-macos-universal" \
WINE_BUILD="$WINE_BUILD" \
  "$ROOT/scripts/stage-dxmt-licenses.sh"

find "$DXMT_RUNTIME" -type f -maxdepth 2 -print | sort

if [ "$PACKAGE_ARTIFACT" != "0" ]; then
    DXMT_TAG="$DXMT_TAG" DXMT_RUNTIME="$DXMT_RUNTIME" WINE_BUILD="$WINE_BUILD" \
      "$ROOT/scripts/package-dxmt.sh"
fi
