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
  filesystems (Linux servers/clients), so write the target in the exact on-disk casing
  (`detail/BLACK`, `detail/SKY`, `detail/METAL_BORD05`). Older files often don't.
- Map sources are **not** under `detailed-textures/`. Paths are relative to `workspace/`:
  - core maps: `maps/<mapname>/<mapname>.map`
  - add-on maps: `add-ons/<mapname>/maps/<mapname>/<mapname>.map`, with the map's own
    WAD sources as BMPs in `add-ons/<mapname>/wads/<mapname>/*.bmp`.
  Texture names appear as the 4th token after the three `( x y z )` plane-point triples
  on each brush face line.

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
- `detail/cir_rocks03` does not exist in `gfx/detail/`; any legacy references
  should be normalized to `detail/cir_rocks08`.
- Wood (`cir_wood*`) → `detail/cir_wood07a`, `detail/cir_wood12a`.
- Metal panels, doors, signs, generic dark surfaces → `detail/dt_metal1`. This is the
  catch-all fallback — useful but high-noise when applied automatically.
- Water/liquids (`!water*`, `!cir_water01`, `scrollwater*`) → `detail/!WATERBLUE`.
- Sky → `detail/SKY` (or omit).

### Named detail TGAs are layout-specific — check before reusing

Most `gfx/detail/<name>.tga` files named after a base texture are a hi-res grayscale
relief of **that exact image**: vents, seams, rivets and panel edges are baked in at
fixed positions (e.g. `c3a2b_reac2c` has a louvred vent top-centre, `c1a0_labw4` a grille
strip along the top, `fifties_case` a specific panel/vent arrangement). Putting one on
a sibling texture with a different layout ghosts those features in the wrong place.

- Reuse a named detail on another texture only when the two share layout: tiling
  variants (`-1…-9` → its `-0`/base detail), animation frames (`+a…+j`, `+1…+9` →
  the `+0` detail), colour-only variants (`c2a3_gar4` → `c2a3_gar3`), or a detail that
  is plain enough to have no features to misplace (`c1a4_silo2b`, `tnnl_flr4`).
- Otherwise use a **tileable material** instead, even when a same-family name exists.
  A family-name match (`c3a2a_w1k` vs `c3a2a_w1`, `xcrate12b` vs `xcrate11b`) is not
  evidence of a shared layout.
- Precedent frequency measures habit, not fit. Many maps map `+0recharge` →
  `dt_metal1` (13×) although an exact `+0recharge.tga` HEV relief exists; some low-count
  sibling mappings (e.g. `crete2_flr03a` → `crete2_flr03ac`: mesh grid vs diamond plate)
  are visual mismatches. Prefer the exact TGA, then a verified same-layout sibling,
  then a material.

Vetted tileable materials (what each actually looks like):

| Detail | Look | Good for |
| --- | --- | --- |
| `dt_metal1` | scratched/veined grey metal | painted metal panels, doors, signs, crates, machinery |
| `METAL_BORD05` | vertical brushed-metal streaks | vertically grained metal (`generic029`, `generic031`) |
| `wall_generic`, `wall_generic2` | smooth plaster/concrete | painted walls (`c1a1w1*`, `c1a1_w1`), paths |
| `crete4_flr01`, `crete2_flr01` | plain concrete | seamless concrete floors |
| `stone3` | fine grain, 128px | subtle rough surfaces |
| `rockout`, `cir_rocks08` | organic / rocky noise | rock, dirt, Xen flesh (`c4a1a_swmpwl`, `c2a5mound*`) |
| `light3b` | two horizontal glowing bars | twin-bar lights (`~light3e`, `~light5f`) |
| `crystallized1` | hex cells | animated/other lights |
| `snowsphinc` | centred Xen orifice | `c4a1a_sphinc*` (same layout) |
| `!WATERBLUE` | blue caustics (coloured, 32bpp) | liquids; it tints, so expect a blue shift on non-blue fluids |

### Textures the `.map` does not list

The engine swaps in textures at runtime that never appear on a brush face:
animation frames (`+a…`, `+1…+9` alongside a `+0…` face) and random tiling variants
(`-1…-9` alongside a `-0…` face). Each needs its own line or those frames/tiles render
without detail. Enumerate them from the map's WAD (for add-ons, the BMPs in
`add-ons/<mapname>/wads/<mapname>/`; otherwise inspect the WAD named in the map's
`"wad"` key) rather than from the `.map`.

## Build / runtime pipeline

- `Build-Textures-Pack.ps1` and `Copy-To-Redist.ps1` (at the `detailed-textures/` root)
  bundle TGAs and every `maps/*_detail.txt` (core and add-on maps alike) into the
  redist drop the mod ships.
- The `powershell/` folder holds project-specific helpers used by those builders.
- The engine reads `<mapname>_detail.txt` on map load when `r_detailtextures 1`. The
  console var must be set before or at map start; mid-map changes do not always take.

## AI/automation tooling — `scripts/`

Standalone PowerShell utilities authored to bulk-analyze and bulk-edit the detail
mapping files.

**Always pass both paths explicitly.** The built-in defaults resolve relative to the
`detailed-textures/` folder and point at a non-existent
`detailed-textures\detailed-textures\maps`, so a bare run throws. Each run only scans
maps found under `-MapsDir`, so core and add-on maps need separate runs:

```powershell
cd c:\hl-mods\workspace\detailed-textures
.\scripts\scan-gaps.ps1 -DetailDir .\maps -MapsDir ..\maps                      # core maps
.\scripts\scan-gaps.ps1 -DetailDir .\maps -MapsDir ..\add-ons\frost_party\maps  # one add-on
```

- [scripts/scan-gaps.ps1](../scripts/scan-gaps.ps1)
  - For each `<mapname>_detail.txt`, parses `<MapsDir>/<mapname>/<mapname>.map`,
    extracts every brush-face texture, and reports textures used by the map but not
    yet defined in its detail file — *if and only if* that same texture has a known
    mapping in at least one other detail file in the project.
  - Blind spots: it only sees brush faces (no WAD-only `+a`/`-1` frames), skips `sky`,
    and only suggests textures some other map already maps. "0 gaps" means "nothing
    the project already knows is missing", not "complete".
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

1. Locate the `.map` (core: `workspace/maps/<m>/`, add-on: `workspace/add-ons/<m>/maps/<m>/`)
   and list its brush-face textures plus any WAD-only frames/tiling variants.
2. For each texture, gather every existing project mapping (`scan-gaps.ps1` only shows
   gaps for maps that already have a detail file, so for a brand-new map tally
   `maps/*_detail.txt` directly) and check whether an exact-name TGA exists.
3. Decide per texture: exact TGA → verified same-layout sibling → tileable material
   (see "Named detail TGAs are layout-specific"). Look at the images when unsure (below).
4. Hand-author `maps/<mapname>_detail.txt` in the format above, grouped by confidence
   with the standard footer. Skip only tool textures (`null`, `clip`, `origin`,
   `aaatrigger`, …).
5. Verify every `detail/<X>` exists as `gfx/detail/<X>.tga` with matching case, there
   are no duplicate keys, and every map + WAD texture is covered.
6. Run `scan-gaps.ps1` against the map's folder; expect `Total gaps: 0`. Avoid
   `apply-gaps.ps1` on a hand-authored file — it trusts precedent over layout.

Worked example: `frost_party_detail.txt` (add-on, 146 entries, every texture in
`frost_party.map` plus its WAD's `+a`/`-1…-3` variants).

### Previewing textures

Viewing images beats guessing from names. Base textures for add-ons are plain BMPs;
`gfx/detail` TGAs are type 2 (raw) or type 10 (RLE), 24/32-bpp, which
`System.Drawing` cannot open and Python/PIL is not installed. A ~15-line C# TGA
decoder loaded via `Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives`
(header bytes 12–17 = width, height, bpp, descriptor; bit 5 of the descriptor = top-down;
RLE packets: high bit = run) is enough to render base/detail pairs side by side into a
PNG contact sheet for review.

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

Full-project audit (all `*_detail.txt` files):

```powershell
$root = 'c:\hl-mods\workspace\detailed-textures'
$gfx  = Join-Path $root 'gfx\detail'
Get-ChildItem (Join-Path $root 'maps') -Filter '*_detail.txt' | ForEach-Object {
  $mapFile = $_.FullName
  Get-Content $mapFile | ForEach-Object {
    $t = $_.Trim()
    if ($t -eq '' -or $t.StartsWith('//')) { return }
    $parts = $t -split '\s+'
    if ($parts.Count -lt 2) { return }
    $name = $parts[1] -replace '^detail/',''
    $tga  = Join-Path $gfx ($name + '.tga')
    if (-not (Test-Path -LiteralPath $tga)) {
      "MISSING: $mapFile :: $($parts[0]) -> $($parts[1])"
    }
  }
}
```

### 2026-10-01 integrity sweep (applied)

One full pass was run over `maps/*_detail.txt` to verify every `detail/<name>` has
a matching `gfx/detail/<name>.tga`. The following broken references were found and
fixed:

- `+abutton4 -> detail/button4` (missing `button4.tga`) in:
  - `doublefrost_detail.txt`
  - `focus_detail.txt`
  - `ice_pit_detail.txt`
  - normalized to `detail/+0button4` (existing `+0button4.tga`, already used by
    `+0button4` and by `frostfire_detail.txt`).
- `generic106b -> detail/generic106b` (missing `generic106b.tga`) in:
  - `frozenwarehouse_detail.txt`
  - `training_detail.txt`
  - normalized to `detail/generic106a` (existing sibling detail texture).
- `crate11 -> detail/crate11_stalkyard` (missing `crate11_stalkyard.tga`) in:
  - `training_detail.txt`
  - normalized to `detail/crate10_stalkyard` (existing stalkyard crate family
    texture used in the same file).

Post-fix audit result: no unresolved detail mappings remain in
`workspace/detailed-textures/maps/*_detail.txt`.

## Known gotchas

- The `.map` parser in `scan-gaps.ps1` keys off lines starting with `( ` and counts
  three `)` characters before reading the texture token. Custom map exporters with
  non-standard whitespace may slip past it; spot-check unfamiliar maps.
- Texture names in `.map` files appear in the case the editor wrote (often UPPER);
  the detail-file convention is lower. The scanner lower-cases both sides for
  comparison, so casing differences won't cause false gaps.
- Legacy mappings may omit the required `detail/` prefix (for example
  `silo2_wet4d  silo2_wet4d`), which causes the engine lookup to fail even when the
  TGA exists (`gfx/detail/silo2_wet4d.tga`). Normalize these to
  `silo2_wet4d  detail/silo2_wet4d`.
- Some mappings are intentionally divergent between maps (e.g. `{icicle1` is `snow2`
  in some maps and `dt_metal1` in others) for stylistic reasons. The "Variants > 1"
  filter in `apply-gaps.ps1` skips these so author intent isn't overwritten.
- `r_detailtextures` is disabled by default in vanilla Half-Life builds; users have
  to enable it explicitly. Don't assume players see these overlays.
