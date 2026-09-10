# TinyScape adventurer

An original Blender-created, faceted adventurer with a shaped teal tunic, saffron scarf, canvas rucksack, leather belt pouch, fitted trousers, boots, expressive eyes and swept walnut hair. All geometry is original procedural modeling; there are no external textures, downloads or character licenses to manage.

## Files

The optional axe-equipped character and new Wood Cutting animation are documented in [woodcutting-assets.md](woodcutting-assets.md), including the right-hand attachment setup and separate source/export files.

- `assets/models/adventurer.glb` — the runtime asset. One armature, one skinned mesh, 17 bones, and flat-shaded materials with no texture dependencies.
- `assets/source/adventurer.blend` — editable Blender source, including the character, both Actions and muted NLA tracks, and a portrait lighting setup.
- `assets/source/.gdignore` — excludes authoring files from Godot's automatic Blender importer.
- `tools/create_character.py` — reproducible asset generation, export, portrait rendering and binary validation.
- `assets/source/character-verification.json` — counts and numerical validation produced from the exported GLB.
- `screenshots/character.png` — rendered portrait.

## Engine conventions

The rest pose stands approximately **1.94 m** tall with soles at the origin. Blender uses +Z up and -Y forward; the GLB export converts this to **Godot +Y up, +Z forward**. Keep scale at `(1, 1, 1)`. Rotate the player pivot toward the movement direction; no corrective model rotation is required.

The single `AdventurerMesh` has an Armature modifier and explicit vertex groups for every vertex. The separated faceted clothing and anatomy sections use rigid skinning, so the design stays crisp as joints move. `Root`, `Hips`, `Spine`, `Neck`, `Head`, and left/right thigh, shin, foot, upper arm, forearm and hand bones form the skeleton.

| Clip | Duration | Behavior |
| --- | --- | --- |
| `Idle` | 3.0 s | Subtle chest expansion, head movement, arm relaxation and weight shift. |
| `Walk` | 1.0 s | In-place opposing legs and arms, analytically solved knees, planted stance feet, lifted swing feet, and a small vertical hip motion. |

Both clips have matching start/end transforms. **Set both Godot Animation resources to `Animation.LOOP_LINEAR`**; glTF stores the animation samples but has no playback-loop flag. Blend clips over about 0.15 seconds. Walk contains no horizontal root motion; game code owns translation and navigation. Adjust the playback speed to match the prototype's movement speed and tile scale.

## Regeneration

From the repository root in PowerShell:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python tools/create_character.py
```

The script creates directories, rebuilds the source asset, exports only the armature and character, renders the portrait, and validates the binary GLB. It verifies the two clip names and durations, one skin, joint/weight attributes on every primitive, normalized nonnegative weights for every exported vertex, matching animation endpoints, and ankle contact throughout stance phases. Counts in `character-verification.json` reflect the generated file.

To preview an animation in Blender, select the `Adventurer` armature and choose `Idle` or `Walk` in the Action Editor. NLA tracks are intentionally muted in the saved source to avoid layering both motions while editing. The source is saved with `Idle` active. Objects prefixed `PREVIEW ONLY` belong to the portrait stage and are excluded from the GLB selection.
