# Eternal Return macOS rendering corruption conclusion

## Status

- Investigation status: closed
- Target: CrossOver 26.1.0 only
- Game: Eternal Return
- Date concluded: 2026-07-24
- Production workaround: Eternal Return-specific DXMT pixel-output sanitization
- No Wine core patch is justified by the collected evidence.

## Executive conclusion

The rendering corruption is not supported by evidence of pointer truncation,
row-pitch corruption, stride corruption, buffer-size truncation, or another
generic Wine data-transport failure.

The strongest explanation is a floating-point compatibility problem at the
Direct3D shader-to-macOS graphics boundary:

1. Eternal Return contains pixel-shader arithmetic that can generate infinity
   and NaN for degenerate input.
2. The issue reproduces through three independent macOS rendering paths:
   WineD3D/Apple OpenGL, DXVK/MoltenVK/Metal, and DXMT/Metal.
3. The equivalent DXVK path is not affected on Linux.
4. The current DXMT workaround fixes the visible corruption by replacing
   non-finite pixel outputs with zero.
5. CrossOver's bundled MoltenVK has a concrete inconsistency between Vulkan
   float-control reporting and its default Metal fast-math compilation policy.

Therefore the engineering conclusion is:

> Eternal Return exposes a NaN/Inf handling difference in the Apple graphics
> compiler/driver stack and its translation backends. Wine core is not the
> primary suspect.

"Driver issue" in this document means the macOS graphics backend boundary as a
whole. It includes Apple OpenGL/Metal shader compilation and the MoltenVK or
DXMT translation layer. It does not claim that the fault has been isolated to a
specific instruction inside Apple's closed-source GPU driver.

## Rendering paths and the common boundary

| Path | Translation route | Observed result |
| --- | --- | --- |
| WineD3D on macOS | DXBC -> GLSL -> Apple OpenGL/CGL | Corruption reproduces |
| DXVK on macOS | DXBC -> SPIR-V -> MoltenVK/SPIRV-Cross -> MSL -> Metal | Corruption reproduces |
| DXMT on macOS | DXBC -> LLVM/AIR -> Metal | Corruption reproduces without the workaround |
| DXVK on Linux | DXBC -> SPIR-V -> native Vulkan driver | No known corruption |

These paths do not share one Wine graphics-data converter. They do share the
game's Direct3D shader and, on macOS, eventually enter Apple's graphics
software stack.

## Capture material examined

The following raw captures were used during the investigation and were moved
out of the active project after this conclusion was recorded:

- `EternalReturn-WineD3D.20260724T002627.trace`
  - apitrace OpenGL capture
  - approximately 7.1 GiB allocated on disk
  - approximately 58.1 GiB apparent file size
  - valid trace through call 18,928,416
- Two split Xcode GPU capture archives for frame 55,798.
- Two split Xcode GPU capture archives for frame 147,895.
- An extracted `eternalreturn.trace` Xcode/Instruments trace.

The raw captures previously occupied approximately 9.1 GiB of allocated disk
space in a separate external diagnostics directory.

## What the WineD3D capture ruled out

The WineD3D apitrace was checked for the originally suspected macOS/ARM data
transport failure. No supporting evidence was found:

- Buffer ranges, offsets, and sizes were internally consistent.
- Vertex strides and offsets did not show 32-bit truncation.
- Row pitch and texture upload sizes were consistent with the calls.
- Mapped and copied addresses above 4 GiB were preserved.
- Large texture payloads were present in the trace rather than shortened.
- The relevant render sequence did not report a corresponding OpenGL runtime
  error.
- The final render path remained structurally valid through the final blit.

This does not prove that every game-generated float is bit-identical between
macOS and Linux. It does rule out the concrete pointer/size truncation theory
that motivated the capture.

The restored stock CrossOver `winemac.so` examined during the work had SHA-256:

```text
eb9601eca65bc33e45aedb2cef73bd00a4637ae079e1dfdfffabd5ccea052d9e
```

## Non-finite shader evidence

The captured WineD3D fragment shader for program 148 contained the following
sequence:

```glsl
R0.w = dot(R0.xyz, R0.xyz);
R0.w = inversesqrt(abs(R0.w));
R2.xyz = ((-R0.xyz * R0.www) + -ps_cb0[3].xyz);
R0.xyz = R0.www * R0.xyz;
```

For a zero-length vector:

```text
dot(0, 0)       = 0
inversesqrt(0)  = +Inf
0 * +Inf        = NaN
```

The affected shader therefore has a natural path to a non-finite result without
requiring corrupt CPU data.

Relevant calls in the capture:

- Program 148 shader source: call 16,976,791
- Program 148 draw into FBO 17 / texture 2261: call 18,928,196
- Final blit: call 18,928,416

Texture 2261 used `GL_RGBA16F`, so NaN or infinity could enter a floating-point
render target and propagate into later blending or presentation work. Programs
142 and 151 also contained unguarded division paths, but program 148 provided
the clearest `dot -> inverse square root -> multiply` chain in the final image
path.

## WineD3D static analysis

### Common Wine code

CrossOver 26.1.0 and the local WineHQ 11 reference trees do not differ in a way
that explains an input-data conversion failure:

- `dlls/d3d11` and `dlls/dxgi` have no relevant CrossOver-only divergence.
- `context_gl.c` and `texture.c` were byte-identical in the compared trees.
- `WINED3DFMT_R16G16B16A16_FLOAT` maps directly to `GL_RGBA16F_ARB`.

For shader model 4 and later, both CrossOver and WineHQ generate the same
unguarded form:

```glsl
inversesqrt(abs(value))
```

CrossOver contains a legacy special-value guard, but it is restricted to shader
models below 4:

```c
guard_inf = wined3d_settings.multiply_special == 1
        && shader_version < WINED3D_SHADER_VERSION(4, 0);
```

The Eternal Return shader is outside that guarded range. WineD3D also assigns
the translated pixel output directly to the GLSL color output without an
`isnan()` or `isinf()` epilogue.

### macOS and Linux driver split

The macOS Wine driver loads:

```text
/System/Library/Frameworks/OpenGL.framework/OpenGL
```

and obtains OpenGL entry points from that framework. Its non-accelerated pixel
format selects `kCGLRendererGenericFloatID`. Consequently, the CrossOver
"software renderer" test still uses Apple's OpenGL/CGL implementation and its
shader behavior. It is not an independent reference implementation that
bypasses the Apple graphics stack.

The Linux X11 path instead loads the system `libGL`/EGL or GLX implementation.
This provides a platform-dependent shader compiler and driver after common
WineD3D has generated its GLSL.

The software-renderer reproduction therefore does not point back to Wine core.
It is compatible with a difference in Apple's OpenGL shader/runtime semantics.

## DXMT static analysis

DXMT is an independent D3D10/D3D11 implementation. The game calls DXMT's
replacement `d3d11.dll`, and DXMT passes work to its Metal-side implementation
through `winemetal`. WineD3D is not inserted between the game and DXMT.

Relevant observations:

- `UpdateSubresource1` copies the supplied source data directly.
- The `winemetal` thunk is specific to DXMT and is not used by WineD3D.
- DXBC `rsq` lowers to an AIR floating-point unary operation.
- `AIRBuilder::CreateFPUnOp()` selects the `air.fast_rsqrt` variant by default.
- Pixel and compute shaders receive relaxed floating-point flags including
  contraction, reassociation, reciprocal transformation, approximate
  functions, and no-signed-zero behavior.
- The source contains an explicit TODO to provide an option for NaN/Inf
  handling.

This provides a direct route from the risky DXBC arithmetic to relaxed Metal
math without a shared Wine float conversion.

## DXVK and MoltenVK static analysis

The fact that DXVK is correct on Linux but affected on macOS is especially
important. The DXVK DXBC front end remains substantially the same; the
platform-specific difference begins when the generated SPIR-V is consumed by
MoltenVK and Metal.

### DXVK side

DXVK lowers DXBC `rsq` to SPIR-V `InverseSqrt`.

DXVK enables `d3d11.floatControls` by default. When the Vulkan device reports
FP32 signed-zero/Inf/NaN preservation, DXVK:

1. enables its `PreserveNan32` float-control flag;
2. emits the SPIR-V `SignedZeroInfNanPreserve` execution mode; and
3. does not automatically enable its render-target NaN-to-zero workaround.

DXVK only automatically enables `enableRtOutputNanFixup` when the Vulkan device
reports that FP32 signed-zero/Inf/NaN preservation is unavailable, apart from a
separate historical RADV condition.

### MoltenVK side

CrossOver 26.1.0 bundles MoltenVK 1.2.10 in the examined source tree.

MoltenVK reports:

```text
shaderSignedZeroInfNanPreserveFloat16 = true
shaderSignedZeroInfNanPreserveFloat32 = true
shaderSignedZeroInfNanPreserveFloat64 = false
```

SPIRV-Cross translates `InverseSqrt` to MSL `rsqrt()`.

MoltenVK correctly detects `SignedZeroInfNanPreserve` and marks that entry point
as not supporting fast math. However, its default configuration is:

```text
MVK_CONFIG_FAST_MATH_ENABLED = MVK_CONFIG_FAST_MATH_ALWAYS
```

The Metal compile option is then calculated as:

```text
fastMathEnabled =
    configuration == ALWAYS
    || (configuration == ON_DEMAND && shaderSupportsFastMath)
```

With the default `ALWAYS` setting, the shader's request to disable fast math is
ignored. MoltenVK's own configuration documentation states that Metal fast
math may violate IEEE 754 and recommends mode `2` (`ON_DEMAND`) for shaders
that request capabilities such as `SignedZeroInfNanPreserve`.

This is the strongest source-level defect candidate found for the DXVK macOS
path:

```text
MoltenVK reports FP32 preservation
    -> DXVK trusts the report and emits the preservation execution mode
    -> DXVK does not add its output NaN workaround
    -> MoltenVK sees that fast math should be disabled
    -> MoltenVK's default ALWAYS policy enables Metal fast math anyway
```

It does not prove that this is the only Apple-side issue, because WineD3D does
not use MoltenVK. It does demonstrate a concrete mismatch capable of explaining
why the same DXVK-generated shader behaves differently after entering the
macOS backend.

## Why this is not best described as a Wine core bug

Wine is present in every CrossOver path, but it does not perform one common
per-float rendering-data conversion before all three renderers:

- WineD3D translates D3D shaders and commands to OpenGL itself.
- DXVK provides its own D3D DLLs and translates to Vulkan/SPIR-V.
- DXMT provides its own D3D DLLs and translates to Metal AIR.

A hypothetical macOS/Rosetta CPU-side difference remains possible. For
example, the game could calculate a slightly different vector before uploading
it. No collected evidence demonstrates that scenario, and it is not needed to
explain the observed shader edge case. The structural capture audit, three
independent renderers, Linux comparison, and successful non-finite output
workaround all make it a lower-priority theory.

## Current workaround

The retained patch is:

```text
patches/dxmt-v0.80-sanitize-output-eternal-return.patch
```

It adds an Eternal Return application profile and sanitizes active pixel-shader
outputs immediately before they are returned to Metal.

The sanitizer is inserted into the generated shader, not executed as a CPU-side
Wine operation and not implemented as a Metal fixed-function render state:

```text
game DXBC pixel shader
    -> DXMT LLVM/AIR conversion
    -> injected non-finite output epilogue
    -> Metal shader compilation
    -> per-fragment execution on the GPU
    -> render-target write
```

Conceptually, each output component is processed as:

```text
absoluteBits = as_uint(value) & 0x7fffffff
nonFinite    = absoluteBits >= 0x7f800000
result       = select(nonFinite, 0.0, value)
```

This catches both NaN and positive/negative infinity.

### Why the sanitizer is relatively inexpensive

The emitted LLVM operation is a value `select`, not an `if`/`else` control-flow
branch. For the simple vector comparison used here, it is expected to lower to
GPU conditional-selection/dataflow instructions:

- every fragment follows the same instruction sequence;
- finite and non-finite fragments do not take separate shader paths;
- there is no intentional SIMD-lane divergence;
- the cost is a fixed set of bit operations, a comparison, a select, and some
  register pressure.

The operation is not free, and a compiler is ultimately responsible for final
lowering. Nevertheless, this branchless epilogue is much cheaper and more
predictable than divergent control flow. Restricting it to the Eternal Return
profile prevents the cost and semantic change from affecting other games.

### Why the workaround must remain application-specific

Wine's D3D11 conformance test `test_fp_specials()` writes literal NaN, positive
infinity, and negative infinity to an `R32G32B32A32_FLOAT` render target and
expects those bit patterns to remain present.

Globally replacing every non-finite render-target output would therefore not be
a faithful general D3D implementation. The current patch is an intentional
compatibility workaround for one game, not a universal fix for DXMT.

## More targeted alternatives considered

1. **Affected shader hash only**
   - Lowest runtime scope.
   - Requires stable identification of every problematic shader variant.

2. **Application-profile output epilogue**
   - Current solution.
   - Small, predictable GPU cost.
   - Robust against shader variants within the same game.

3. **Disable relaxed math for selected shaders**
   - More semantically conservative.
   - Does not guarantee a visible fix because IEEE-correct `rsqrt(0)` and
     `0 * Inf` can still produce infinity and NaN.

4. **Disable fast math globally**
   - Useful as a diagnostic.
   - Excessive scope and possible performance cost for a shipping workaround.

5. **Modify Wine core data transport**
   - Rejected because the capture and source analysis do not identify a
     corresponding transport defect.

## Optional confirmation tests if the investigation is reopened

These are not required for the current CrossOver 26.1.0 engineering decision.

1. Run the DXVK/MoltenVK path with:

   ```text
   MVK_CONFIG_FAST_MATH_ENABLED=2
   ```

   Use a clean shader/pipeline cache. This asks MoltenVK to disable Metal fast
   math only when the SPIR-V execution mode requests it.

2. If mode `2` does not change the result, repeat with:

   ```text
   MVK_CONFIG_FAST_MATH_ENABLED=0
   ```

3. Test DXVK with `d3d11.enableRtOutputNanFixup=True` to determine whether
   NaN-only output cleanup is sufficient.

4. Use a minimal cross-backend shader containing the captured
   `dot -> rsq -> multiply` sequence and compare Windows, Linux Vulkan, Apple
   OpenGL, MoltenVK/Metal, and DXMT/Metal output bit patterns.

5. Capture the first affected render target immediately after the suspect draw
   if exact first-divergence proof is required.

## Preserved reproducibility material

The following small or reusable materials are intentionally retained:

- this conclusion;
- `docs/crossover-26.1.0-er-diagnostics.md`;
- the Eternal Return sanitizer patch;
- the CrossOver 26.1.0 diagnostic patch;
- build, run, prefix-preparation, and smoke-test scripts;
- the non-finite marker smoke test;
- the compact DXBC dumps and diagnostic logs;
- the finished DXMT artifact;
- source and toolchain directories required to rebuild.

Large raw GPU captures, disposable CrossOver diagnostic runtimes, temporary
diagnostic builds, and disposable test prefixes are not required to retain the
reasoning above and were cleaned up after documentation.

## Cleanup performed

The following disposable investigation material was moved to the macOS Trash
on 2026-07-24:

- the external `errordata` diagnostics directory
  - approximately 9.1 GiB allocated;
  - all raw apitrace and Xcode GPU capture material.
- CrossOver diagnostic build and runtime directories under `er-dxmt-build`
  - `build-crossover-26.1.0-diagnostic`;
  - `crossover-26.1.0-diagnostic-runtime`;
  - `crossover-26.1.0-diagnostic-runtime-run2`;
  - `dxmt-runtime-crossover-26.1.0-diagnostic`;
  - `test-prefix-crossover-26.1.0-diagnostic`;
  - approximately 3.8 GiB in total.
- Disposable external diagnostic prefixes
  - `$HOME/WineSteam-CrossOver-26.1.0-FreshDiagnostic`;
  - `$HOME/WineSteam-CrossOver-26.1.0-Diagnostic`;
  - approximately 49 GiB of displayed directory size in total.
- Large temporary analysis-tool copies
  - the downloaded RenderDoc archive;
  - the extracted RenderDoc tree;
  - the apitrace source/build tree;
  - approximately 602 MiB in total.

The reported aggregate is approximately 62.5 GiB, but it must not be interpreted
as exact newly reclaimable physical space. The apitrace file was sparse, and
the diagnostic Wine prefixes may contain APFS-cloned blocks. The items remain
recoverable from the Trash until it is emptied; disk space is reclaimed when
the Trash is emptied.
