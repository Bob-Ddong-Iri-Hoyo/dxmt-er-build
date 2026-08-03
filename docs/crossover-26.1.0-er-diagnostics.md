# CrossOver 26.1.0 Eternal Return diagnostics

This diagnostic path is restricted to the local CrossOver 26.1.0 build. It does
not install files into Wine Stable, WineHQ, `/Applications`, or the original
CrossOver artifact.

## What it observes

- Every Eternal Return pixel-shader DXBC blob is saved by SHA-1.
- The DXMT log records the matching Metal function as
  `ps_<first-eight-sha1>_<variant>`.
- With `DXMT_ER_MARK_NONFINITE=1`, a NaN or infinity in any active pixel output
  component makes that render target output white for the diagnostic run.
- F10 captures the next Eternal Return frame as an Xcode `.gputrace`.

The white marker is intentionally diagnostic. It is not a proposed game fix and
it is inactive unless the diagnostic environment variable is set.

## Build and verify without launching the game

```sh
./scripts/build-crossover-26.1.0-diagnostic.sh
./scripts/test-crossover-26.1.0-diagnostic.sh
```

The smoke test must finish with:

```text
pixel=255,255,255,255 expected=255,255,255,255
```

## Protect the existing WineSteam prefix

Do not point CrossOver 26.1.0 directly at `$HOME/WineSteam`. CrossOver
may update registry and prefix metadata. Prepare a fresh CrossOver prefix and
APFS-clone only the existing Steam directory:

```sh
./scripts/prepare-crossover-26.1.0-eternal-return-prefix.sh
```

This preserves the original prefix and normally consumes space on write. A full
Wine-prefix clone is deliberately avoided because converting an existing
WineHQ-style prefix can mix registry and driver state with CrossOver.

## One game run

```sh
CROSSOVER_ER_PREFIX="$HOME/WineSteam-CrossOver-26.1.0-FreshDiagnostic" \
  ./scripts/run-crossover-26.1.0-eternal-return-diagnostic.sh
```

Reproduce the corrupt scene, press F10 once while it is visible, wait for the
capture message, and quit. The script prints the timestamped diagnostics
directory. It contains the `.gputrace`, DXMT log, and dumped `*.dxbc` files.

## Reading the result

- If the black geometry becomes white, that draw produced NaN or infinity at
  the pixel-shader output. The Xcode fragment function name identifies the exact
  dumped DXBC shader.
- If the corruption remains black with no white marker, the value reaching the
  output is finite. Investigation should move earlier: constant-buffer contents,
  vertex/index buffers, resource uploads, format/stride conversion, or the
  vertex stage in the macOS Wine path.
- If an unrelated area turns white, use the captured draw's
  `ps_<sha1-prefix>_<variant>` name to separate it from the corrupt draw.

The game must be run once because a GPU trace records only commands and resource
state from an actual frame; the existing screenshots cannot reveal which live
draw and resource update produced the bad geometry.
