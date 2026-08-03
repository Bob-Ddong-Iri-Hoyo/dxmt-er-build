#!/usr/bin/env bash
set -eu

if [ "$#" -ne 3 ]; then
    echo "usage: $0 <src> <dest> <move>" >&2
    echo "example: $0 /path/to/dxmt-runtime/x86_64-windows /path/to/wine/lib/wine/x86_64-windows /path/to/old-dxmt" >&2
    exit 1
fi

SRC="$1"
DEST="$2"
MOVE="$3"

if [ ! -d "$SRC" ]; then
    echo "missing src directory: $SRC" >&2
    exit 1
fi

mkdir -p "$DEST" "$MOVE"

move_old_file() {
    src_file="$1"
    rel_path="${src_file#$SRC/}"
    dest_file="$DEST/$rel_path"

    if [ ! -f "$dest_file" ]; then
        return
    fi

    old_dir="$MOVE/$(dirname "$rel_path")"
    old_file="$old_dir/$(basename "$rel_path").old"
    mkdir -p "$old_dir"

    if [ -e "$old_file" ]; then
        old_file="$old_dir/$(basename "$rel_path").old.$(date +%Y%m%d-%H%M%S)"
    fi

    echo "move old: $dest_file -> $old_file"
    mv "$dest_file" "$old_file"
}

copy_new_file() {
    src_file="$1"
    rel_path="${src_file#$SRC/}"
    dest_file="$DEST/$rel_path"

    mkdir -p "$(dirname "$dest_file")"
    echo "copy new: $src_file -> $dest_file"
    cp "$src_file" "$dest_file"
}

find "$SRC" -type f | while IFS= read -r src_file; do
    move_old_file "$src_file"
    copy_new_file "$src_file"
done

echo "done"
