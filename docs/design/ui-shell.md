# System Design — UI Shell: Menu Bar, Bag, and the Message Log

**Status:** `approved` · **Owning agents:** gameplay engineer (`GEMINI.md`), with §5 addressed to the
3D asset specialist (`AGENTS.md`) · **Source:** playtest feedback, 2026-09-10
([playtest-notes.md](playtest-notes.md))

The HUD was built to demonstrate a movement prototype. It now has to serve a game with an inventory,
a journal, a skill and a speaking NPC. This replaces the demo furniture with a shell those systems
can hang off.

---

## 1. Current behaviour

Read from the build at `5b58eda`, all in `scripts/hud.gd`.

- **Top left:** `_build_identity()` (line 78) draws `assets/icon.svg` at 58 × 58 beside the word
  "tinyscape" at 48 pt and the tagline "A small world. A first adventure."
- **Bottom left:** `hint_label` (line 175), a single centred line near the bottom of the screen.
  `show_message()` (line 335) writes to it with a countdown; when the countdown expires
  `update_state()` overwrites it with walking/chopping status. **Every message the game produces
  goes here and is then destroyed** — examine text, level-ups, Mabb's deposit line, refusals.
- **Left panel:** name, status, tile, the woodcutting readout, steps travelled.
- **Bottom centre:** a row of buttons — Grid, Character, Recenter, Controls.
- **Bottom right:** two footer lines of control hints and `Single-player prototype v0.1`.
- **Inventory is a number.** `player.inventory` is an `Array[Dictionary]` of
  `{type, name, value}` with 28 slots (`woodcutting_data.gd:5`), surfaced only as `Logs 12/28` in a
  text label. There is no inventory UI.
- The quest journal from [quest-system.md](quest-system.md) R5 exists on `J`.

---

## 2. Requirements

### R1 — Remove the wordmark block

Delete `_build_identity()` and its call. The logo, title and tagline all go. The top-left corner
becomes empty and stays empty.

The wordmark belongs on a title screen, not over the game. The place name "Willowmere" in the map
panel already tells the player where they are, and it stays.

### R2 — A menu bar

A single horizontal bar of icon buttons, **bottom right**, above the existing footer text.

| Button | Opens | Key |
| --- | --- | --- |
| Bag | The inventory window (R3) | `B` |
| Journal | The quest journal | `J` |
| Character | The existing inspect/orbit view | `V` |
| Settings | The existing pause screen | `Esc` |

Requirements:

- Each button shows its **shortcut key** in its tooltip, and the bar is the discoverable route to
  every window. A player who never learns a hotkey must be able to reach everything by clicking.
- The **active** window's button is visibly held down, so the bar reads as state, not just actions.
- Windows are **mutually exclusive** — opening the bag closes the journal. Two floating panels
  competing for the same corner is the failure mode here.
- The existing Grid and Recenter buttons move into the footer as small text controls or are dropped
  into the settings screen. They are debug affordances and should stop occupying prime real estate.
- Styled per [art-direction.md](../art-direction.md) §7: dark timber-green panel, fine brass edging,
  warm off-white glyphs.

### R3 — The bag window

A **28-slot** inventory panel, matching `MAX_INVENTORY_SLOTS`.

- **Grid: 4 columns × 7 rows.** This is the shape the slot count implies and the one the genre has
  trained players to read.
- Anchored above the menu bar, bottom right. It does not move and is not draggable.
- Each filled slot shows the item's **icon** (R5) and, where an item stacks, a small count in the
  upper left. Logs do not stack today — each occupies a slot — so the count is for later and should
  simply not render at 1.
- Empty slots are visible as empty recesses. **The player must be able to see how full they are at a
  glance**, which is the entire reason this window exists: the current failure is discovering a full
  rucksack only when chopping stops.
- **Hovering a slot** outlines it in `Highlight` `#fff6e4` and shows the item's name and value.
- **Right-clicking a slot** offers *Examine* and *Drop*. Examine writes to the message log (R4).
  Drop removes the item; it does not spawn anything in the world.
- The window opens and closes without pausing the game.
- When the bag fills, its button in the menu bar takes a subtle warm outline until the player next
  opens it.

### R4 — The message log

The single centre hint line is replaced by a **scrolling history** of everything that happens.

- **Position:** bottom left, roughly 460 px wide and 6 lines tall, in the standard panel style.
- **Content:** newest at the bottom, older scrolling up. Keeps the last **100** lines; the player can
  scroll back through them with the wheel while the cursor is over the panel.
- **Everything discrete goes here** — examine text, level-ups, XP and coin gains, Mabb's deposit
  line, refusals like *"You need level 15 to cut pine"*, quest state changes, and the *"You swing
  your axe at the tree..."* line.
- **The centre hint line is removed entirely.** The centre of the screen stays clear, per
  [art-direction.md](../art-direction.md) §4.
- **Continuous status does not go here.** Walking and chopping state stays in `status_label` in the
  left panel. A log that fills with *"Walking to tile 4, 2"* is a log nobody reads.
- Repeated identical lines collapse to one with a multiplier — `Willow logs (×4)` — rather than
  printing four times. Chopping produces a lot of identical events and this is what keeps the log
  legible.
- Older lines dim slightly toward the top of the panel so the eye finds the newest without the panel
  needing a border between entries.
- No timestamps.

`show_message()` becomes the log's append function, so every existing caller keeps working. Its
`seconds` argument becomes meaningless and should be removed rather than ignored.

### R5 — Item icons are rendered from the item's own 3D model

Every item shows an icon derived from the model already in the build — the log icon is `CutLog.glb`.

**Render them at load into cached textures; do not hand-author 2D art, and do not run 28 live
viewports.** On first request for an item type, render its model once in a `SubViewport` to an
`ImageTexture`, cache it by item id, and reuse it in every slot.

This is the same trick the dialogue chathead already uses
([dialogue-system.md](dialogue-system.md) R4), and it is the right answer for the same reason: the
model stays the single source of truth. When the asset specialist revises `CutLog.glb`, the icon
changes with it and nobody re-exports a PNG.

- Render target **128 × 128**, transparent background.
- Lit by the scene's warm key so an icon and the item on the ground are recognisably the same
  object.
- Framed from the item's **icon pose** (§5), filling ~85% of the square.
- Icons are cached for the session. They do not need to persist.

### R6 — Preserve what works

The minimap and click-to-travel, the map panel, the pause screen, the dialogue box, the journal and
every keyboard shortcut keep working. `Esc` continues to close the topmost open window before it
reaches the pause screen — the same rule dialogue and the journal already follow.

---

## 3. Acceptance criteria

1. No logo, wordmark or tagline appears anywhere in the game view.
2. The menu bar opens the bag, journal, character view and settings by click and by hotkey.
3. Opening one window closes any other; the active button reads as held.
4. The bag shows 28 slots as 4 × 7, filled slots carrying an icon rendered from the item's model.
5. Cutting a log adds a visible item to the next free slot; depositing empties the bag.
6. A full bag is obvious from the window, and its menu button marks itself.
7. Examine text appears in the message log, not in the centre of the screen.
8. The log keeps 100 lines, scrolls back, and collapses repeats into a multiplier.
9. Walking and chopping status does not enter the log.
10. Item icons are rendered once per item type and reused.

---

## 4. Requirements — assets

For the 3D asset specialist.

**A1 — An icon pose convention, applied to every item model.** Each item GLB carries a node named
`IconAnchor` whose transform defines the camera-facing orientation used for its icon. The gameplay
side reads that node and frames the render from it; where a model lacks one, it falls back to a
three-quarter view from front-above.

Pick the angle that makes the object **most recognisable as a silhouette**, not the most flattering
one. For a cut log that is a three-quarter view showing the round cut face and the length together —
a log seen end-on is a disc, and a log seen square-on is a rectangle, and neither reads as a log.

**A2 — Apply it to `CutLog.glb` first**, since logs are the only item that exists.

**A3 — Confirm the item models read at 128 px.** An object designed to read at 5 m in a diorama may
lose its silhouette at icon size. If a log needs a slightly exaggerated cut face or a deeper facet
to survive the shrink, that is a legitimate change — say so rather than letting it render as a brown
smudge.

**A4 — Menu bar glyphs.** Four icons: bag, journal, character, settings. Flat, single-colour, in the
UI's warm off-white, readable at 24 px. These are the one place 2D art is correct rather than a
render, because they are UI furniture and not objects in the world.

---

## 5. Verification

Re-run the movement, woodcutting and dialogue checks. New coverage: an item entering and leaving a
slot; the log collapsing repeats and capping at 100 lines; `Esc` closing an open window before
reaching pause; icon cache returning the same texture for a second log.
