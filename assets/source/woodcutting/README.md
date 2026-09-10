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
  branching trunk, and no stacked oak balls or pine cones. Existing Meadow,
  Meadow shade and Canopy supply the lighter yellow-green foliage; Walnut and
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

- **A2 stumps are held for a palette decision.** A2 requires matching existing
  trunks in colour, but `scripts/world.gd` uses `wood = #573f2e` while the art bible
  specifies Walnut `#976a4d`. The question sent to the user is whether to use the
  bible and request an engineer change to those trunks, or preserve the existing
  trunk colour as an explicit exception. No palette exception has been assumed.
  Existing interactive oak and pine base radii are 0.28 and 0.23 m respectively;
  radial segments are eight. Willow's base radius is 0.32 m.
- Gameplay engineer: place the willow, replace the yard pile and switch between
  its two exports on deposit, using the approved skill requirements. These assets
  have no collision, interaction, inventory or respawn behaviour attached.
- Director: resolve the old trunk material versus the published Walnut palette
  once the user selects the intended path. This pass does not edit director docs.
- A5 optional falling/shaking feedback is deferred: it needs animation and an
  engine trigger beyond this static asset pass. Existing axe and chop clips are
  preserved.
