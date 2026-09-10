# System Design — Object Picking and Hover Highlight

**Status:** `approved` · **Owning agent:** gameplay engineer (`GEMINI.md`) · **Source:** playtest
feedback, 2026-09-10 ([playtest-notes.md](playtest-notes.md))

Two related complaints with one cause: the game does not know what the cursor is pointing at, only
which patch of ground it is over.

---

## 1. Current behaviour

Read from the build at `5b58eda`.

- **All picking is a ground-plane raycast.** `tile_under_cursor()` (`scripts/main.gd:146`) projects
  the cursor ray onto `Plane(Vector3.UP, 0.0)` and converts the intersection to a tile. It never
  touches an object. A tree's trunk and canopy occupy space *above* that plane, so pointing at the
  visible tree returns whatever tile is behind it, and only the base tile works.
- **Hover feedback is a flat quad on the ground.** `_hover_marker` (`main.gd:86`) is a `PlaneMesh`
  tinted green over trees, gold over walkable tiles and red over blocked ones (`main.gd:361`). It
  marks a *tile*, not a thing.
- **Interactive objects are now real nodes.** `TreeNode` (`scripts/tree_node.gd`) and
  `LogPileNode`, `NpcNode` are `Node3D`s with `MeshInstance3D` children. **None of them have
  collision shapes**, so there is currently nothing for a physics ray to hit. This is the gap to
  close — and it only became cheap to close when the world was refactored out of batched multimeshes
  into entities.
- Static scenery (cottage, well, bridge, fences) is still batched geometry via `_box()` and is
  **not** an entity. It is not interactive and does not need to be.

---

## 2. Requirements

### R1 — Interactive objects are picked by their model, not their tile

Every interactive entity carries a collision shape covering its **visible extent**, and picking
casts a physics ray from the camera through the cursor.

| Entity | Shape | Covers |
| --- | --- | --- |
| `TreeNode`, standing | Cylinder | Trunk **and** canopy, to the full height of the model |
| `TreeNode`, stump | Cylinder | The stump only — a felled tree must stop being a tall target the instant it falls |
| `LogPileNode` | Box | The current visible state; empty frame and stacked pile differ |
| `NpcNode` | Capsule | Roughly 0.45 m across, the character's full height |

Shapes are **generous rather than exact**. A player aiming at a canopy edge should hit the tree. Do
not attempt per-triangle accuracy on faceted foliage; a cylinder that contains the silhouette is
correct and cheaper.

Put these on a dedicated physics layer so the ray tests only interactive objects and never terrain.

### R2 — The ground plane stays the fallback

Picking resolves in this order:

1. Physics ray hits an interactive entity → that entity is the target.
2. No hit → fall back to the existing `tile_under_cursor()` ground-plane result.

Clicking bare ground to walk must behave **exactly** as it does today. This is the requirement most
likely to regress, because it is the one nobody thinks to test.

An entity is also still associated with a tile, and every existing tile-based behaviour — pathing
adjacent, blocking navigation, the walk-then-act flow at `main.gd` — continues to work off that
tile. **This changes how a target is identified, not what happens to it.**

### R3 — Right-click acts on the picked object

`_handle_right_click()` (`main.gd:199`) currently matches the clicked *tile* against
`world.LOGPILE_TILE`, `world.is_tree_at()` and `world.is_npc_at()`. It should instead take the
picked *entity* and build its menu from that entity's own advertised options.

Each entity type exposes its context options — *Chop* / *Talk-to* / *Deposit logs*, plus *Examine*
and *Cancel*. This removes the growing tile-matching chain in `main.gd` and means the next
interactive object needs no change there at all.

### R4 — Left-click on an object does the obvious thing

Left-clicking an interactive object performs its **primary action** — chop a tree, talk to an NPC,
deposit at the pile — rather than trying to walk into it. Left-clicking ground still walks.

This was not asked for, and it is a genuine convenience, but flag it if it fights the existing
"left click always walks" muscle memory in testing; the fallback is to leave left-click as walk-only
and keep every action on right-click.

### R5 — Hover highlight

The hovered interactive object is outlined in a **white border**.

- **Colour:** `Highlight` `#fff6e4` ([art-direction.md](../art-direction.md) §2) — a warm near-white,
  not pure `#ffffff`, which reads clinical against this palette.
- **Method:** an inverted-hull outline — a `next_pass` material on the entity's meshes with
  front-face culling, unshaded `Highlight`, and a small grow. Suggested grow **0.02 m**, tuned so the
  line reads roughly 2 px at default zoom and does not balloon when the player zooms in
  ([camera-zoom.md](camera-zoom.md)).
- Depth testing stays **on**. The outline must not shine through the cottage.
- The outline covers the **whole entity** — a hovered tree outlines trunk and canopy together, as one
  object.
- Appears on hover, clears the moment the cursor leaves. No fade, no pulse. The destination marker
  already pulses; two pulsing things is one too many.

### R6 — The ground marker survives, with a narrower job

Keep `_hover_marker`, but it now only marks **walkable and blocked ground**: gold for walkable, red
for blocked, exactly as today. Drop the green tree tint — trees are outlined now, and highlighting
the same thing twice in two visual languages is worse than either alone.

### R7 — Suppression

No highlight and no picking while the camera is orbiting or a dialogue is open — the same conditions
`main.gd:362` already checks. Picking also does not run under the cursor when it is over a UI panel.

---

## 3. Acceptance criteria

1. Pointing anywhere on a tree's trunk or canopy targets that tree; right-click offers *Chop*.
2. Felling a tree immediately shrinks its pick shape to the stump.
3. Pointing at Mabb's body targets Mabb, not the tile behind her.
4. Clicking bare ground walks there, exactly as before this change.
5. The hovered object is outlined in `#fff6e4`; the outline clears on leaving and never shows
   through solid geometry.
6. Only one thing is highlighted at a time.
7. No outline appears while orbiting or while a dialogue box is open.
8. Adding a new interactive entity requires no edit to `_handle_right_click()`.
9. Existing pathfinding, tile blocking, walk-then-act and chop interruption are unchanged.

## 4. Verification

Re-run the movement, woodcutting and dialogue checks. New coverage: a ray hitting a tree's canopy
resolving to that tree; the same ray after felling resolving to ground; ground-click walking
unaffected; the outline clearing on hover exit.
