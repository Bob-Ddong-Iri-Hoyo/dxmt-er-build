#!/bin/sh
set -eu

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
exec "$ROOT/scripts/fetch-toolchains.sh"
