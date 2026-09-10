# Mabb Truet — developer handoff

Built against approved main `ed925e8`, `docs/design/dialogue-system.md` A1–A4,
`docs/world/npcs/mabb-truet.md`, and the corrected albedo palette in
`docs/art-direction.md`. These are editable 3D assets and actual Blender renders.

## Deliverables

| Runtime file under assets/models | Source | Details |
| --- | --- | --- |
| `villagers/MabbTruet.glb` | `MabbTruet.blend` | 1.70 m, 2,470 triangles, 17 bones, Idle and Talk |
| `villagers/MabbFellingAxe.glb` | `MabbFellingAxe.blend` | 88 triangles, 1.105 m high; separate nearby prop |
| `woodcutting/WillowStump.glb` | `../woodcutting/stumps.blend` | 44 triangles; radius 0.32 m, height 0.30 m |
| `woodcutting/OakStump.glb` | same | 44 triangles; radius 0.28 m, height 0.32 m |
| `woodcutting/PineStump.glb` | same | 44 triangles; radius 0.23 m, height 0.28 m |

All use metres, unit scale, Godot +Y up / +Z forward. Mabb's soles and each
stump base are at the origin. The axe origin is the haft butt; place it beside
the pile and rotate its placement parent to lean it. It is intentionally not
attached to Mabb's hands and does not use the player's grip socket.

## Rig and animation

Mabb has the familiar Root/Hips/Spine/Neck/Head and paired limb hierarchy.
`Head` is at the skull base, rest position `(0, 1.365, 0)` in model coordinates.
Its local +Z points toward model +Z; this is verified in the actual GLB hierarchy.
Local Y is the head's yaw axis; local X supplies the nod.

| Clip | Duration | Use |
| --- | --- | --- |
| `Idle` | 4 s | Planted feet, resting forward lean, upper-body shift and small look-around |
| `Talk` | 1.666667 s | 0.6 Hz, ±3 degree head yaw/nod; hands at rest |

Both are sampled at 30 fps with matching endpoints and no root motion.
Set imported animations to `Animation.LOOP_LINEAR`; glTF has no loop flag.
Use Talk on the live chathead clone when speaking; do not also add a procedural
bob or the motion will double. Idle/Talk are mutually exclusive, not additive.
There is no lip sync, finger rig, walk or felling clip in this stationary NPC pass.

The source opens on Idle. Select `MabbTruet` and choose Talk in the Action Editor
to preview it. Export tracks are stored muted in NLA, as on the adventurer.
Rigidly weighted, separate faceted clothing pieces preserve the established
character approach. This is not a smooth-deforming full-body animation rig.

## Reusable villager base

The editable source retains named body, apron, repair, hair and face meshes.
Duplicate it for another villager; replace the apron and hair shapes and use
approved palette swatches. `villager_body()` and `BASE` in the authoring script
expose the body proportions. There is no redundant neutral model to maintain.
Mabb's torso uses eight radial sides and her shaped face sixteen. She has a
short wide apron, a 1.37 shoulder-to-hip radius ratio, weathered skin, tied ash
hair, and exactly one brass buckle. No player teal/saffron or roof terracotta.

## Existing player chathead

Both `adventurer.glb` and `adventurer_woodcutting.glb` contain exactly one `Head`
joint. They are preserved. Their existing bone roll differs from Mabb's; use the
character root's forward direction for player camera facing rather than assuming
the player's bone-local axes are identical to Mabb's. Frame from the joint's
global position. The player's source skull-base height is 1.54 m.

## Verification and previews

`verification.json` records binary GLB counts, finite positions, normalized
normals and skin weights, unit scales, clip lengths and exact matching endpoints.
The authoring checks also cover closed mesh components, positive signed volumes,
nonzero face areas, height, and stationary feet at every animation frame (maximum
drift below 0.000001 m). Mabb's exported Head position and forward axis are asserted.
Flat-colour materials have no image textures and require no UV maps.

Actual renders in `screenshots/villagers/`: `mabb.png`, `chathead.png`,
`chathead-talk.png`, `felling-axe.png`, and `stumps.png` (willow/oak/pine, left to
right). Body, speaking pose, axe and stump renders were visually inspected.
Engine import, live dialogue framing and gameplay playback remain developer checks;
no game code, scenes or director documents were changed.

Regenerate only this handoff with:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python-exit-code 1 --python tools/create_villager_handoff.py
```

This overwrites these sources and exports; preserve manual edits before running.
Stump collections share an origin in the source; only WillowStump is initially
visible. Toggle collection visibility to edit the others.

Developer placement and gameplay integration follow the approved design docs.
Optional canopy shaking/falling feedback remains deferred. No asset decision is
pending for the required dialogue and woodcutting deliverables.
