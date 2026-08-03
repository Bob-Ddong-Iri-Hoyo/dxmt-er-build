# License Scope

This repository contains independently authored project material and
third-party or derivative material. The license is selected by path and
component, not by the repository as a whole.

## Project material: MIT

The root `LICENSE` applies to the original, standalone material authored for
this repository, including the build and diagnostic scripts, documentation,
tests, and standalone tools, except where a file contains a different notice
or incorporates third-party code.

Copyright (c) 2026 fabyday

## DXMT material

Files under `patches/` are patches against DXMT and contain DXMT source
context. They and the patched DXMT source/runtime must be distributed with the
applicable DXMT terms and notices. The current DXMT LGPL-2.1-or-later notice is
preserved in `LICENSES/DXMT-LICENSE`, the full license text is in
`COPYING.LIB`, and the MIT terms originally shipped with DXMT v0.80 are in
`LICENSE.OLD`.

Applying the repository's MIT license to standalone project material does not
replace or weaken the license obligations of the resulting patched DXMT work.

## Wine and other components

Wine/CrossOver-linked files and all other bundled third-party components keep
their own licenses. Generated runtime archives include the exact notices
collected from the source and toolchain inputs under `share/licenses/`; see
`THIRD_PARTY_NOTICES.md` for the component list.
