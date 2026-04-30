# Detailed Textures — AI Context

Reference notes for working with the Cold Ice Remastered detailed-textures project.

## What detail textures are

Half-Life's `r_detailtextures 1` console variable enables a second high-resolution
overlay applied multiplicatively on top of base map textures at close range. This
gives surfaces the appearance of much higher detail without changing BSP geometry
or replacing the original WAD textures (which would alter lightmap baking and break
demo/server compatibility).

Each map ships with a `<mapname>_detail.txt` file that maps base WAD texture names
to overlay TGA files in `gfx/detail/`, plus a horizontal and vertical scale.

## File locations

- `maps/<mapname>_detail.txt` — per-map mapping files. Loaded by the engine when the
  map is started with detail textures enabled.
- `gfx/detail/*.tga` — the actual detail overlay images. Filenames here are referenced
  (without extension) from the mapping files. Lookups are case-sensitive on some
  filesystems but conventionally written in mixed/lower case.
- `maps/<mapname>/<mapname>.map` — source J.A.C.K./Hammer map. Texture names appear as
  the 4th token after the three `( x y z )` plane-point triples on each brush face line.

## `_detail.txt` format

```
// optional comments

// [texture name]   [detail texture name]    [hscale]   [vscale]
c1a0_w4             detail/C1A0_W4           1.0        1.0
+0~light5a          detail/crystallized1     1.0        1.0
{icicle1            detail/dt_metal1         1.0        1.0
```

Rules and conventions observed across existing files:

- One mapping per line. Whitespace-separated; tabs are typical, but any whitespace works.
- `[texture name]` is the WAD texture name as it appears on a brush face. Case is
  insensitive when the engine looks up textures, but lower-case is the established
  convention in these files.
- Special texture-name prefixes are preserved verbatim:
  - `{`  transparent textures (e.g. `{icicle1`, `{ladder1`)
  - `!`  liquids (e.g. `!cir_water01`, `!waterblue`)
  - `+0…+9`, `+a…+j`  animated frame chains (each frame mapped individually; usually
    same detail target)
  - `-0…-3`  tiling/large-texture variants (each variant typically maps to the same
    `-0…` detail target)
  - `~`  self-illuminated/light variants
- `[detail texture name]` is always prefixed with `detail/` and refers to a TGA in
  `gfx/detail/` *without* the `.tga` extension. The actual TGA must exist on disk or
  the entry is silently dropped at runtime.
- `[hscale]` / `[vscale]` are float multipliers controlling detail tiling density.
  `1.0  1.0` is the overwhelmingly used default. Smaller values stretch the detail
  pattern (less repetition); larger values tile it more densely.
- Skip non-rendering tool textures: `null`, `origin`, `aaatrigger`, `contentwater`,
  `clip`, `hint`, `skip`, `bevel`, `sky` (visually `sky` is sometimes mapped, but it
  has no real effect).
- File traditionally ends with `// End detail texture file.` and a snarky comment
  block. Auto-tooling preserves that footer.

## Mapping authoring patterns

When picking a `detail/<X>` for a base texture, the project's existing files form
strong precedent. Common patterns:

- A detail TGA exactly named after the base texture is preferred when present
  (e.g. `c1a0_w4` → `detail/C1A0_W4`, `tnnl_w7b` → `detail/tnnl_w7b`).
- Light/glow textures (`+0~light*`, `~light*`, `light_*`) → `detail/crystallized1` or
  `detail/light3b`. `crystallized1` is preferred for animated `+0~`/`+a~` lights.
- Snow/ice surfaces (`cir_snow*`, `ci_flake*`, `{cir_tree*`) → `detail/snow2`.
- Brick variants → `detail/brickwall034a`, `detail/wall`, `detail/stone`.
- Rock/stone (`cir_rock*`, `cir_rocks*`, `cir_stone*`) → `detail/cir_rocks08`,
  `detail/stone3`, `detail/rockout`.
- Wood (`cir_wood*`) → `detail/cir_wood07a`, `detail/cir_wood12a`.
- Metal panels, doors, signs, generic dark surfaces → `detail/dt_metal1`. This is the
  catch-all fallback — useful but high-noise when applied automatically.
- Water/liquids (`!water*`, `!cir_water01`, `scrollwater*`) → `detail/!WATERBLUE`.
- Sky → `detail/SKY` (or omit).

## Build / runtime pipeline

- `Build-Textures-Pack.ps1` and `Copy-To-Redist.ps1` (at repo root) bundle TGAs and
  the per-map `*_detail.txt` files into the redist drop the mod ships.
- The `powershell/` folder holds project-specific helpers used by those builders.
- The engine reads `<mapname>_detail.txt` on map load when `r_detailtextures 1`. The
  console var must be set before or at map start; mid-map changes do not always take.

## AI/automation tooling — `scripts/`

Standalone PowerShell utilities authored to bulk-analyze and bulk-edit the detail
mapping files. Run from any cwd; paths inside are absolute to this workspace.

- [scripts/scan-gaps.ps1](../scripts/scan-gaps.ps1)
  - For each `<mapname>_detail.txt`, parses the corresponding `maps/<mapname>/<mapname>.map`,
    extracts every brush-face texture, and reports textures used by the map but not
    yet defined in its detail file — *if and only if* that same texture has a known
    mapping in at least one other detail file in the project.
  - Output columns: `Map`, `Texture`, `Detail` (most common existing mapping),
    `Frequency` (how many other maps use that exact mapping), `Variants` (how many
    distinct detail targets the texture is mapped to across the project; `1` =
    unanimous).
  - Ends with a per-map gap count summary. Read-only; makes no edits.

- [scripts/apply-gaps.ps1](../scripts/apply-gaps.ps1)
  - Same scan logic as `scan-gaps.ps1`, but writes the high-confidence subset back
    into each `<mapname>_detail.txt`. Current selection criteria:
    - `Variants == 1` (unanimous mapping across the project)
    - `Frequency >= 3` (used by 3+ other maps)
    - excludes the `detail/dt_metal1` generic filler
  - Inserted entries are placed under a `// Auto-filled high-confidence mappings`
    header just before the `// End detail texture file.` footer (footer preserved).
  - Tunable: edit the three guard conditions in the script to broaden/narrow the
    scope (e.g. lower `Frequency`, allow `dt_metal1`, allow `Variants <= 2`).
  - Repeat runs skip already-defined textures, but the `// Auto-filled` block may
    still be appended again, so prefer running scan first and reviewing changes
    before rerunning.

### Adding a new map

1. Add `maps/<mapname>/<mapname>.map` (and the BSP build) to the workspace.
2. Run `scripts/scan-gaps.ps1` and review the new map's gap rows for inspiration.
3. Hand-author `maps/<mapname>_detail.txt` using the format above, leaning on the
   "Mapping authoring patterns" section for choice of `detail/<X>`.
4. Verify every chosen `detail/<X>` exists as `gfx/detail/<X>.tga`.
5. Optionally re-run `scripts/apply-gaps.ps1` to fill any unanimous, high-frequency
   gaps the hand-authored file missed.

### Validating that detail TGAs exist

Quick PowerShell check for a single file:

```powershell
$map = 'suspension'
$detail = "c:\hl-mods\workspace\detailed-textures\maps\${map}_detail.txt"
$gfx    = 'c:\hl-mods\workspace\detailed-textures\gfx\detail'
Get-Content $detail | ForEach-Object {
    $t = $_.Trim()
    if ($t -eq '' -or $t.StartsWith('//')) { return }
    $parts = $t -split '\s+'
    if ($parts.Count -lt 2) { return }
    $tga = Join-Path $gfx (($parts[1] -replace '^detail/','') + '.tga')
    if (-not (Test-Path -LiteralPath $tga)) { "MISSING: $($parts[0]) -> $($parts[1])" }
}
```

## Known gotchas

- The `.map` parser in `scan-gaps.ps1` keys off lines starting with `( ` and counts
  three `)` characters before reading the texture token. Custom map exporters with
  non-standard whitespace may slip past it; spot-check unfamiliar maps.
- Texture names in `.map` files appear in the case the editor wrote (often UPPER);
  the detail-file convention is lower. The scanner lower-cases both sides for
  comparison, so casing differences won't cause false gaps.
- Some mappings are intentionally divergent between maps (e.g. `{icicle1` is `snow2`
  in some maps and `dt_metal1` in others) for stylistic reasons. The "Variants > 1"
  filter in `apply-gaps.ps1` skips these so author intent isn't overwritten.
- `r_detailtextures` is disabled by default in vanilla Half-Life builds; users have
  to enable it explicitly. Don't assume players see these overlays.
