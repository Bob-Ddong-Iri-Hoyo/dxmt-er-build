# ER DXMT Build


Builds DXMT `v0.80` with the Eternal Return sanitize-output-only patch.

CrossOver 26.1.0-only investigation instructions are in
[`docs/crossover-26.1.0-er-diagnostics.md`](docs/crossover-26.1.0-er-diagnostics.md).

The patch only adds `d3d11.sanitizeOutput` and enables it for `EternalReturn.exe`. It does not enable `dxgi.forceSDR`, `sampleNaNToZero`, or `defuseFma` for Eternal Return.


## Patched DXMT Binary Repository
[Link](https://github.com/Bob-Ddong-Iri-Hoyo/anka-snack-house)

## License

Original standalone project material authored by `fabyday` is released under
the MIT License in [`LICENSE`](LICENSE). DXMT patches and the patched runtime
retain the applicable DXMT notices: the current LGPL-2.1-or-later notice is in
[`LICENSES/DXMT-LICENSE`](LICENSES/DXMT-LICENSE), its full text is in
[`COPYING.LIB`](COPYING.LIB), and the MIT notice originally shipped with DXMT
v0.80 is preserved in [`LICENSE.OLD`](LICENSE.OLD). Wine and other third-party
components retain their own terms.

See [`LICENSES/README.md`](LICENSES/README.md) for the path-based scope and
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for the component list.

## What Is Included

- `patches/dxmt-v0.80-sanitize-output-eternal-return.patch`
  Minimal patch against DXMT `v0.80`.
- `scripts/fetch-dxmt.sh`
  Clones DXMT from GitHub, checks out `v0.80`, initializes submodules, and applies the patch.
- `scripts/fetch-toolchains.sh`
  Fetches and builds the local toolchains under `./sources`, `./build`, and `./toolchains`.
- `scripts/build-dxmt.sh`
  Builds builtin Wine DLLs/SO into `./dxmt-runtime` and packages `artifacts/dxmt-{tag}-builtin.tar.gz`.
- `scripts/package-dxmt.sh`
  Packages an existing `./dxmt-runtime` directory as `artifacts/dxmt-{tag}-builtin.tar.gz`, with a matching `dxmt-{tag}-builtin/` top-level directory inside the archive.
- `scripts/stage-dxmt-licenses.sh`
  Builds the runtime's `share/licenses/` tree from the exact DXMT, LLVM,
  MinGW-w64, and Wine sources used for the build.
- `scripts/install-to-wine-stable.sh`
  Installs `./dxmt-runtime` into Wine Stable's builtin DLL directories with a timestamped backup.
- `toolchains/`, `sources/`, `build/`, `dxmt-runtime/`, and `artifacts/`
  Generated locally and ignored by git.

## Requirements

- macOS with Xcode command line tools
- `git`
- `curl`
- `cmake`
- `meson`
- `ninja`
- A Wine build tree for builtin DLL builds

By default, the builtin Wine build path is repo-relative:

```text
./wine-build/build64
```

Put or symlink a Wine build there, or override it with `WINE_BUILD`.

## 1. Fetch Toolchains

```sh
./scripts/fetch-toolchains.sh
```

This creates versioned source/build/install paths:

```text
./sources/llvm-project-llvmorg-15.0.7
./sources/llvm-mingw-20260407-ucrt-macos-universal.tar.xz
./build/llvm-llvmorg-15.0.7
./toolchains/llvm-llvmorg-15.0.7
./toolchains/llvm-mingw-20260407-ucrt-macos-universal
./toolchains/llvm
./toolchains/llvm-mingw
```

The last two are symlinks used by the build scripts.

## 2. Fetch DXMT

```sh
./scripts/fetch-dxmt.sh
```

This creates:

```text
./sources/dxmt-v0.80
```

`sources/` is ignored by git. The source is reproducible from DXMT GitHub plus the patch file.

## 3. Build Builtin DXMT

```sh
WINE_BUILD=/path/to/wine-build/build64 ./scripts/build-dxmt.sh
```

If you symlink your Wine build to `./wine-build/build64`, this is enough:

```sh
./scripts/build-dxmt.sh
```

If toolchains or DXMT have not been fetched yet, `build-dxmt.sh` automatically runs the fetch scripts.

Build output:

```text
./dxmt-runtime/i386-windows/
./dxmt-runtime/x86_64-windows/
./dxmt-runtime/x86_64-unix/
```

Artifact output:

```text
./artifacts/dxmt-v0.80-builtin.tar.gz
./artifacts/dxmt-v0.80-builtin.tar.gz.sha256
```

The archive extracts into a matching top-level directory:

```text
dxmt-v0.80-builtin/
```

The runtime and archive include `LICENSE`, `COPYING.LIB`, `LICENSE.OLD`,
`THIRD_PARTY_NOTICES.md`, and an exact component bundle under
`share/licenses/`. The archive's top-level `LICENSE` describes the DXMT
runtime; the repository project's MIT terms are stored at
`share/licenses/project/MIT.txt`. Packaging fails when a required license
source is missing.

Use another DXMT tag:

```sh
DXMT_TAG=v0.81 WINE_BUILD=/path/to/wine-build/build64 ./scripts/build-dxmt.sh
```

This fetches `v0.81` and writes `./artifacts/dxmt-v0.81-builtin.tar.gz`.

## 4. Install Into Wine Stable

```sh
./scripts/install-to-wine-stable.sh
```

Defaults:

```text
APP_WINE=/Applications/Wine Stable.app/Contents/Resources/wine
DXMT_RUNTIME=./dxmt-runtime
BACKUP_ROOT=./backups
```

Override example:

```sh
APP_WINE="/Applications/Wine Stable.app/Contents/Resources/wine" \
DXMT_RUNTIME="./dxmt-runtime" \
BACKUP_ROOT="./backups" \
./scripts/install-to-wine-stable.sh
```

The install script prints the backup path and SHA-256 hashes for the installed files.

## 5. Set Wine Overrides

For the target Wine prefix, use builtin DXMT first:

```text
d3d10core = builtin,native
d3d11     = builtin,native
dxgi      = builtin,native
winemetal = builtin,native
```

Example:

```sh
WINEPREFIX="/path/to/wine-prefix" winecfg
```

Then set the DLL overrides in the Libraries tab.

## 6. Run Eternal Return

Clear the DXMT shader cache for a clean test:

```sh
DXMT_SHADER_CACHE=0 /path/to/your/steam-launcher.sh
```

To verify that this patch is the active fix, disable only output sanitize:

```sh
DXMT_SHADER_CACHE=0 DXMT_DISABLE_OUTPUT_SANITIZE=1 /path/to/your/steam-launcher.sh
```

If the original corruption comes back with `DXMT_DISABLE_OUTPUT_SANITIZE=1`, the sanitize-output path is confirmed.

## Useful Environment Variables

```text
DXMT_REPO
DXMT_TAG
DXMT_SRC
PATCH
WINE_BUILD
DXMT_BUILD
DXMT_RUNTIME
LLVM_NATIVE
LLVM_NATIVE_TAG
LLVM_PROJECT_REPO
LLVM_PROJECT_SRC
LLVM_NATIVE_BUILD
LLVM_NATIVE_INSTALL
LLVM_MINGW_VERSION
LLVM_MINGW_NAME
LLVM_MINGW_ARCHIVE
LLVM_MINGW_URL
LLVM_MINGW_INSTALL
APP_WINE
BACKUP_ROOT
WINE_INSTALL
PREFIX
ARTIFACT_DIR
PACKAGE_ARTIFACT
```

Typical defaults:

```text
DXMT_REPO=https://github.com/3Shain/dxmt.git
DXMT_TAG=v0.80
DXMT_SRC=./sources/dxmt-v0.80
PATCH=./patches/dxmt-v0.80-sanitize-output-eternal-return.patch
LLVM_NATIVE_TAG=llvmorg-15.0.7
LLVM_MINGW_VERSION=20260407
WINE_BUILD=./wine-build/build64
DXMT_RUNTIME=./dxmt-runtime
BACKUP_ROOT=./backups
ARTIFACT_DIR=./artifacts
PACKAGE_ARTIFACT=1
```
