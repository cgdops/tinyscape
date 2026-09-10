# Design Requirement — Player-Controlled Camera Zoom

**Status:** `approved` — requested by the user.
**Owner:** gameplay engineer (`GEMINI.md`, branch `gemini/gameplay-engineering`).
**Touches:** [scripts/camera.gd](../../scripts/camera.gd), the controls hint in
[scripts/hud.gd](../../scripts/hud.gd), and `tests/test_game.gd` if camera state is asserted there.

## Intent

> The player should be able to zoom in and out from their character as they like.

Zoom is currently possible but it does not behave like zooming *on the character*. The framing
drifts, the close end is a separate mode rather than a continuation of the range, and the step size
feels inconsistent. The player should be able to move freely and continuously between "looking at
the whole village" and "looking at my character", with the character staying put on screen the
whole way.

This also resolves the open art-direction note that the adventurer reads small and generic at
default distance ([art-direction.md](../art-direction.md) §9): the answer is that the player can
simply come closer.

## Current behaviour

From `scripts/camera.gd` as it stands:

| Aspect | Current |
| --- | --- |
| Projection | Orthogonal; `size` is lerped toward `zoom` |
| Zoom range | `clampf(zoom ± 1.5, 6.0, 34.0)`, default `24.0` |
| Zoom step | Fixed `1.5` per wheel notch |
| Focus point | `target.position + Vector3(0, 0.6, -4.5 * zoom / 24.0)` |
| Close view | `V` toggles `inspecting`: snaps `zoom = 7.5`, `pitch = 0.42`, `yaw = 0.45`, and changes the focus offset to `(0, 0.9, 0)` |
| Pitch clamp | `0.50 … 1.22` rad (≈29° … 70°) |
| Reset | `Home` restores yaw `0.63`, pitch `0.83`, zoom `24.0` |

Three problems follow from this:

1. **Zoom is not centred on the character.** The focus offset scales with `zoom`, so the character
   slides within the frame as you zoom. Zooming in does not converge on them.
2. **The close view is a separate mode.** `V` is the only way to get properly close, it overrides
   the player's chosen yaw and pitch, and its focus offset is discontinuous with normal zoom.
3. **The step is linear, so it feels uneven.** `6.0 → 7.5` is a 25% jump; `32.5 → 34.0` is 4.6%.
   Zooming in feels coarse and zooming out feels sluggish.

## Requirements

**R1 — Zoom is continuous across the whole range.** One control (mouse wheel) moves smoothly from
the widest to the closest framing. No mode boundary, no snap, no discontinuity in focus, yaw or
pitch anywhere in the range.

**R2 — The character stays framed while zooming.** The focus point must not scale with zoom. The
camera targets a fixed point on the character — `target.position + Vector3(0, 0.9, 0)`,
roughly chest height — at every zoom level. Zooming in converges on the character; the character
does not drift toward an edge.

**R3 — Zoom steps are proportional.** Each wheel notch multiplies the zoom by a constant factor
rather than adding a constant. Use `zoom *= 1.12` / `zoom /= 1.12`, clamped to the range in R4.
Every notch should feel like the same amount of zoom regardless of where the player is in the range.

**R4 — The range reaches genuinely close and comfortably wide.** Orthographic `size` clamped to
**`3.5 … 40.0`**, default `24.0`.

- At `3.5`, the ~1.94 m adventurer fills roughly half the viewport height — close enough to read the
  face, tunic and the axe animation clearly. This is the close end the player is asking for.
- At `40.0`, the whole village slab and its fence line are comfortably in frame.

**R5 — Pitch eases down as the player zooms in.** A 70° top-down angle looks wrong up close. The
minimum allowed pitch scales with zoom so close views can sit lower and more portrait-like, while
wide views stay diorama-like:

- Minimum pitch at `size ≤ 6.0`: **0.28 rad** (≈16°)
- Minimum pitch at `size ≥ 20.0`: **0.50 rad** (≈29°) — the current value
- Interpolate linearly between those two points; maximum pitch stays `1.22` rad throughout.

The player's chosen pitch is never *forced* to change — only the clamp moves. If zooming in widens
the allowed range, the current pitch is left alone; if zooming out would leave the pitch below the
new minimum, ease it up rather than snapping.

**R6 — Zoom does not disturb yaw.** Zooming never alters the player's chosen orbit angle. This is
the main regression risk from removing the `V` mode's snap.

**R7 — `V` becomes a preset, not a mode.** Keep the key. Pressing `V` eases zoom to `4.0` and
pitch to `0.35`, **leaving yaw untouched**, and is a normal position in the continuous range — the
player can immediately wheel out of it. Pressing `V` again returns to the previous zoom and pitch.
Remove the `inspecting` branch and its separate focus offset.

**R8 — `Home` still resets fully.** Yaw `0.63`, pitch `0.83`, zoom `24.0`, eased rather than
snapped.

**R9 — Zoom smoothing is preserved.** Keep the existing frame-rate-independent easing
(`1.0 - exp(-10.0 * delta)` on `size`). Zoom input sets a target; the camera eases toward it.

**R10 — Near plane must not clip the character.** At the closest zoom with the lowest pitch, the
adventurer must not be clipped by `near`. Verify and adjust `near` if needed.

## Deliberately not required

- No zoom-to-cursor. Zoom stays centred on the character; this is a character-follow camera.
- No collision or terrain avoidance. The camera may pass through props at close range — acceptable
  for the prototype. Flag it if it looks bad rather than building a collision system.
- No FOV or perspective change. The orthographic projection is part of the diorama look
  ([art-direction.md](../art-direction.md) §4) and must not change.
- No change to `Q`/`E` or right-drag orbit behaviour.

## Acceptance criteria

1. Wheeling from the widest to the closest framing and back produces no visible jump in position,
   pitch or framing at any point.
2. At every zoom level the character remains at the same point in the frame.
3. Each wheel notch produces a visually similar amount of zoom at both ends of the range.
4. At maximum zoom-in the adventurer fills roughly half the viewport height and is not clipped.
5. At maximum zoom-out the village slab and fence line are fully visible.
6. Zooming in then out returns the yaw the player set.
7. `V` eases to a close view without changing yaw; pressing it again returns to the previous view.
8. `Home` restores the default view from any state.
9. The HUD controls hint still describes zoom correctly.

## Verification

```powershell
godot --headless --path . --script tests/test_game.gd
godot --path . --script tests/capture.gd
```

Capture screenshots at minimum, default and maximum zoom, and check them against
[art-direction.md](../art-direction.md) — particularly that the close view still reads as flat-shaded
and chunky rather than exposing faceting as an artefact. If close range reveals that the character
needs more geometric detail, that is an art-direction question to raise, not a modelling change to
make unilaterally.
