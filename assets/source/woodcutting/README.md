# Woodcutting environment assets

First asset pass for approved `docs/design/woodcutting-skill.md` on main, commit
`b996ff1`. Implements A1, A3 and A4 using `docs/art-direction.md` and the established
axe honey-wood materials. These are editable 3D models, not concept images.

## Files

`woodcutting_props.blend` contains four named asset collections at ground-centred
origins. It opens with the willow visible and the preview camera framed. Toggle
collection eye and render-camera icons in the Outliner to isolate another asset;
only one should be visible at a time, since export origins coincide. The
`PREVIEW ONLY` collection contains the camera, lighting and floor, never exported.

Exports are in `assets/models/woodcutting/`:

| Export | Triangles | Size in metres (width X / depth Z / height Y in glTF) |
| --- | ---: | --- |
| `WillowTree.glb` | 774 | 4.610 / 4.209 / 3.650 |
| `CutLog.glb` | 60 | 1.250 / 0.340 / 0.340 |
| `LogPileEmpty.glb` | 224 | 1.197 / 1.872 / 1.103 |
| `LogPileStacked.glb` | 764 | 1.375 / 1.872 / 1.168 |

Actual Blender renders: `screenshots/woodcutting/willow-tree.png` and
`screenshots/woodcutting/log-pile-states.png`. On the prop sheet, empty is left,
stacked is right, and the separate log is in front. Arrangement is for the render
only; it is not baked into exports or the editable source.

## Art and use

- Willow: low umbrella crown with seven hanging, broad faceted lobes, a short
  branching trunk, and no stacked oak balls or pine cones. Existing Canopy light,
  Reed and Canopy supply the lighter yellow-green foliage; Walnut and
  Walnut dark supply the trunk. Base trunk radius is 0.32 m.
- Log: eight-sided bark with bevelled honey cut ends. Bark uses the bible's
  Walnut pair. End grain uses the exact linear RGB values of the existing axe's
  honey materials. No invented palette swatches, image textures or UV dependency.
- Rack: mismatched stakes, slightly uneven rails and bevelled bearers in the
  established honey wood. The loaded version contains the identical frame plus
  nine logs in a 4/3/2 stack. Both states share the same origin and orientation.
- All transforms are baked into editable meshes, with unit object scales.
  Blender +Z up converts to glTF/Godot +Y up. Logs run along X. Place at ground
  level with identity scale. Sources use metres against the 1.94 m adventurer.
- Mesh parts remain separate for editing. Intersections at trunk branches and
  canopy lobes are intentional; this is a game prop, not a watertight union for
  printing. Each individual mesh component is closed.

## Verification

The authoring run checks finite vertices, closed manifold components, positive
signed volume, nonzero polygon areas, ground bounds, and unit scales. GLB checks
verify headers, byte length, matching triangle counts, unit node scales, and no
textures, skins or animation tracks. Results are in `verification.json`.
Both final renders were visually inspected for silhouette, material readability,
framing and rack/log contacts. Engine import and gameplay playback are not tested
in this asset-only pass; no game code or scenes were changed.

Regenerate only these outputs (overwrites any manual edits to them):

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python-exit-code 1 --python tools/create_woodcutting_props.py
```

## Pending work / owner handoff

### Bag log icon — UI shell R5 / A1–A3

`CutLog.glb` now includes `IconAnchor`, a camera transform in item-local space.
Copy its global transform to the icon camera: **-Z looks toward the log, +Y is
camera up**, with a **30-degree vertical perspective FOV**, square 128 px target.
The node's position supplies camera distance as well as its orientation. The view
shows the cut end and the log's length together and fills approximately 85% of the
square's width. All current log types share this model; no species-specific art
has been invented.

`cut_log_icon.blend` is the isolated editable icon source, with the delivered GLB
reimported, its anchor, and a preview camera and warm lighting. Original geometry,
materials and the 60-triangle count are preserved. No mesh exaggeration was needed.
`screenshots/woodcutting/cut-log-icon.png` is a visually inspected **preview only**;
the bag must render the GLB at runtime, not load this PNG.

Regenerate the pose, source and preview after running the base props generator:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python-exit-code 1 --python tools/create_log_icon.py
```

Verification: original GLB binary buffers preserved, anchor transform checked
after export/reimport, 60 triangles, transparent 128 px image, and unclipped
silhouette occupying approximately 85% of the width. Results are in
`log-icon-verification.json`. Blender preview inspected; engine bag not tested.

Gameplay handoff: the current gameplay-branch `scripts/icon_generator.gd` copies
the anchor transform and uses 30-degree FOV, which matches this asset. However,
it reads the viewport image immediately after creating the viewport, without
waiting for a rendered frame, then frees it. The gameplay owner must verify/fix
that capture timing to satisfy R5; this asset change cannot establish that the
in-game icon appears correctly.

- **A2 stumps delivered:** `WillowStump.glb`, `OakStump.glb`, `PineStump.glb`;
  editable source `stumps.blend`. See `../villagers/README.md` and its verification
  report. The corrected main art bible now approves Walnut albedo `#573f2e` and
  Walnut dark `#3a3026`. This pass also reauthors willow/log bark to those values
  and willow foliage to approved albedos, preserving geometry and export names.
  Existing interactive oak and pine base radii are 0.28 and 0.23 m; willow is
  0.32 m. All stumps have eight radial segments and Walnut light cut surfaces.
- Gameplay engineer: place the willow, replace the yard pile and switch between
  its two exports on deposit, using the approved skill requirements. These assets
  have no collision, interaction, inventory or respawn behaviour attached.
- The palette blocker is resolved by main `ed925e8`; no director decision remains.
- A5 optional falling/shaking feedback is deferred: it needs animation and an
  engine trigger beyond this static asset pass. Existing axe and chop clips are
  preserved.
