#!/usr/bin/env bash
set -eu

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WINE="${WINE:-$ROOT/wine-install}"
PREFIX="${PREFIX:-$ROOT/prefix}"
DXMT="${DXMT:-$ROOT/dxmt-runtime}"
DISABLED="$PREFIX/drive_c/windows/dxmt-native-disabled"

backup_once() {
  if [ -e "$1" ] && [ ! -e "$1.wine-original" ]; then
    cp "$1" "$1.wine-original"
  fi
}

mkdir -p "$WINE/lib/wine/x86_64-unix" "$WINE/lib/wine/x86_64-windows" "$WINE/lib/wine/i386-windows"
mkdir -p "$PREFIX/drive_c/windows/system32" "$PREFIX/drive_c/windows/syswow64"
mkdir -p "$DISABLED/system32" "$DISABLED/syswow64"

backup_once "$WINE/lib/wine/x86_64-unix/winemetal.so"
cp "$DXMT/x86_64-unix/winemetal.so" "$WINE/lib/wine/x86_64-unix/winemetal.so"

for dll in dxgi.dll d3d11.dll d3d10core.dll winemetal.dll; do
  backup_once "$WINE/lib/wine/x86_64-windows/$dll"
  backup_once "$WINE/lib/wine/i386-windows/$dll"
  cp "$DXMT/x86_64-windows/$dll" "$WINE/lib/wine/x86_64-windows/$dll"
  cp "$DXMT/i386-windows/$dll" "$WINE/lib/wine/i386-windows/$dll"
done

cp "$DXMT/x86_64-windows/winemetal.dll" "$PREFIX/drive_c/windows/system32/winemetal.dll"
cp "$DXMT/i386-windows/winemetal.dll" "$PREFIX/drive_c/windows/syswow64/winemetal.dll"

for dll in dxgi.dll d3d11.dll d3d10core.dll; do
  cp "$DXMT/x86_64-windows/$dll" "$PREFIX/drive_c/windows/system32/$dll"
  cp "$DXMT/i386-windows/$dll" "$PREFIX/drive_c/windows/syswow64/$dll"
done

for path in "$PREFIX/drive_c/windows/system32"/api-ms-win-crt-*.dll; do
  if [ -e "$path" ]; then
    mv "$path" "$DISABLED/system32/"
  fi
done

for path in "$PREFIX/drive_c/windows/syswow64"/api-ms-win-crt-*.dll; do
  if [ -e "$path" ]; then
    mv "$path" "$DISABLED/syswow64/"
  fi
done

echo "DXMT installed."
echo 'Use WINEDLLOVERRIDES="winemac.drv=b;winex11.drv=d;winewayland.drv=d"'
