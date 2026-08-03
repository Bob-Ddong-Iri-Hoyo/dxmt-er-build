# Third-Party Notices

This project builds a modified DXMT `v0.80` runtime. Each component remains
subject to its own license; no ownership of third-party code is claimed.

## Components

- **DXMT v0.80** — originally distributed under the MIT License. The original
  terms are preserved in `LICENSE.OLD`. DXMT patches and the patched runtime
  retain the applicable DXMT notices in `LICENSES/DXMT-LICENSE` and
  `COPYING.LIB`. Original standalone project material is separately released
  under the root MIT `LICENSE`; see `LICENSES/README.md` for scope.
- **LLVM 15.0.7** — statically linked into the native `winemetal.so` shader
  conversion path; Apache-2.0 with LLVM Exceptions.
- **DXVK-derived utility code** — zlib/libpng license. The upstream notice is
  copied from DXMT's `src/util/dxvk.LICENSE`.
- **MinGW-w64 and Wine-derived DirectX headers** — retain their per-file and
  upstream terms. DXMT's aggregate MinGW-w64 notice is included.
- **Microsoft DXBC parser portions** — MIT-licensed source whose copyright and
  license notices remain in the corresponding source files.
- **Wine/CrossOver Wine components** — the builtin runtime is linked against
  the exact Wine build supplied through `WINE_BUILD`; its `LICENSE` and
  `COPYING.LIB` are included in the generated license bundle.

The generated runtime records source URLs, commits, and patch checksums in
`share/licenses/SOURCE-PROVENANCE.txt`. Public binary releases should keep the
matching source repository and build instructions available alongside the
artifact.
