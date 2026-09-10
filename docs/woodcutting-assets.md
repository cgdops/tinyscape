# Wood-cutting assets

Approved direction: **option 1, Chunky Low Poly**. Use broad flat-shaded facets, honey-colored wood, dark steel and a light cutting bevel for related tools unless a different style is requested. These are modeled assets, not the earlier AI concept image.

## Deliverables

- `assets/source/wood_cutting_axe.blend`: editable axe with a render camera and lighting.
- `assets/models/wood_cutting_axe.glb`: standalone axe, 160 triangles, four flat-color materials, no textures. Approximately 0.865 m overall height; origin at the grip, 0.13 m above the handle butt.
- `assets/source/adventurer_woodcutting.blend`: existing character with the axe attached, new socket, and editable Wood Cutting action. Opens at the wind-up pose; press Play to preview. Select the Adventurer armature to edit poses.
- `assets/models/adventurer_woodcutting.glb`: character, removable axe, one skeleton, and Idle, Walk, and Wood Cutting clips.
- `screenshots/woodcutting/wood-cutting.gif`: actual rendered animation preview.
- `screenshots/woodcutting/axe.png`: actual axe render.
- `screenshots/woodcutting/pose-sheet.jpg`: ready, wind-up, strike and recovery poses.

The original `adventurer.blend` and `adventurer.glb` remain the inputs. The new assets are delivered separately; gameplay integration is outside this asset task.

## Right-hand attachment

The new hierarchy is `Hand.R` → `AxeSocket.R` → `AxeMount.R` → `WoodCuttingAxe`. The axe is already attached in the character source and export. The grip stays at the palm throughout the animation. The existing simplified hand uses a rigid grip without individual finger bones.

For a replacement or standalone axe, keep `AxeMount.R`, remove its current axe child, and parent the standalone asset's `AxeGrip` root under that mount. Reset the new child's local position and rotation to zero and scale to one. No hand-offset tuning is required. Keep the mount's own transform: it handles the Blender/glTF axis conversion. Do not reset it or parent the standalone asset straight to the exported bone expecting the same orientation.

In Blender, the standalone axe points +Z toward its head and -Y toward its cutting edge. Its GLB uses +Y toward the head and +Z toward the edge, matching the project's export conventions. All dimensions use meters.

## Animation

`Wood Cutting` is a **1.8-second one-handed sideways chopping cycle**, sampled at 30 fps, with no root translation. The axe sweeps from the character's right toward the left in a horizontal plane, perpendicular to a vertical tree trunk. The cutting edge stays at approximately 1.22 m height while the torso twists into the strike. The left arm provides counterbalance; feet stay planted. The trunk contact location is a staging target, not a collision or gameplay event.

| Pose | Blender frame | Clip time |
| --- | --- | --- |
| Ready | 1 | 0.00 s |
| Wind-up | 22 | 0.70 s |
| Strike | 32 | 1.033 s |
| Recovery | 39 | 1.267 s |
| Matching end | 55 | 1.80 s |

All three actions are stored with muted NLA tracks for export; Wood Cutting is active in the saved source. Select Idle or Walk in the Action Editor to preview those clips. Their exported samples match the originals exactly. For looping in Godot, set the imported Wood Cutting animation's loop mode to Linear; glTF does not store a playback-loop flag.

## Verification and regeneration

The authoring run checked closed axe mesh components, arm reach, grip position, stationary feet, root translation, matching cycle endpoints, clip names and durations, and exported mount hierarchy. A binary export check also confirmed normalized skin weights, finite vertex positions, matching Wood Cutting endpoints, and unchanged Idle/Walk samples. Results are in `assets/source/woodcutting-verification.json`. The axe and representative animation poses were visually inspected in Blender renders; no engine playback test was performed.

Run from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python tools/create_woodcutting_assets.py
```

This rebuilds the two new source files, GLBs, individual rendered frames, and authoring validation report from the original character. It overwrites these generated outputs, so preserve manual edits before regeneration. The GIF, pose sheet, and additional binary-comparison report fields were assembled during delivery rather than by the authoring script.
