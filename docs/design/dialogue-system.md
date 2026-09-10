# System Design — Dialogue and NPCs

**Status:** `approved` · **Owning agent:** gameplay engineer (`GEMINI.md`), with an asset
dependency on the 3D asset specialist (`AGENTS.md`, §5 below) · **Depends on:**
[quest-system.md](quest-system.md), which lands in the same pass.

This is the system that lets the world talk back. It is deliberately the *next* system rather than
Firemaking: burning logs is only meaningful once Cooking exists to consume the fire, and Cooking is
not designed. Dialogue, by contrast, is the delivery mechanism for every system after it — it is
how the player is taught Woodcutting, how a quest is offered, and how coins earned at the log pile
eventually become a reason to want combat equipment.

---

## 1. The four questions

- **Fantasy** — the villagers of Willowmere are people with small problems, and you can ask them
  about it. Nobody is waiting for a hero; they are waiting for Thursday.
- **Loop** — approach an NPC, right-click, *Talk-to*, read, choose, act, come back changed.
- **Inputs and outputs** — inputs: player state (skill level, inventory, coins, quest flags).
  Outputs: quest flags, XP, coins, and the player knowing what to do next.
- **Unlocks** — quests, tutorialisation, shops, and the standing meaning of a skill level
  ([woodcutting-skill.md](woodcutting-skill.md) §7).

---

## 2. Current behaviour

Read from the build at `5000c81`.

- **There are no NPCs.** No character other than the player exists in the scene.
  `scripts/world.gd` builds only terrain and props.
- **Interaction is right-click context menus.** `scripts/main.gd:168` `_handle_right_click()`
  matches the clicked tile against `world.LOGPILE_TILE` and `world.is_tree_at()` and calls
  `hud.show_context_menu()` (`scripts/hud.gd:275`) with an array of
  `{ "text": String, "callback": Callable }`. This is the pattern new interactions extend.
- **Walk-then-act already exists.** `_start_woodcut_action()` (`scripts/main.gd:228`) finds the
  best adjacent walkable tile, calls `travel_to()`, stores `_pending_chop_tree`, and completes the
  action on arrival in `_process()` (`scripts/main.gd:284`). **Talking must reuse this pattern**,
  not invent a second one.
- **All feedback is one line of HUD text.** `hud.show_message()` (`scripts/hud.gd:335`) sets
  `hint_label` for N seconds. Mabb Truet currently exists only as the deposit string at
  `scripts/main.gd:226`.
- **Keyboard input is grabbed by the HUD.** `hud.gd:249` `_input()` handles `Esc` (pause), `G`
  (grid) and `H`/`F1` (controls). Dialogue input must be handled *before* these.
- **Player state that dialogue can read** (`scripts/player.gd`): `woodcut_level`, `woodcut_xp`,
  `coins`, `inventory` (array of `{type, name, value}`), the `logs` computed property, `steps`,
  `motion.current_tile`.
- **The game pauses via `get_tree().paused`** (`hud.gd:240`), and the HUD sets
  `process_mode = PROCESS_MODE_ALWAYS` (`hud.gd:35`) so it survives the pause.

---

## 3. Requirements — systems

### R1 — NPCs are entities in the world

An NPC is a node placed at a tile with an identity, a model, and a dialogue tree. Minimum fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | String | Stable key, e.g. `mabb_truet`. Used by quest flags and dialogue files |
| `display_name` | String | `"Mabb Truet"` — shown in the context menu and the dialogue nameplate |
| `examine` | String | One line for the *Examine* option |
| `home_tile` | Vector2i | Where they stand |
| `facing` | Vector2i | Which way they face at rest |
| `dialogue` | String | Path to the dialogue file (R5) |

The NPC's tile is **blocked for pathfinding** — the player walks adjacent, not through — the same
way `world.gd:466` blocks `LOGPILE_TILE`. NPCs do **not** wander in this pass. A standing NPC with
an idle animation is the requirement; wandering is explicitly out of scope.

### R2 — Talking is a walk-then-act interaction

Right-clicking an NPC's tile opens the existing context menu with:

```
Talk-to Mabb Truet
Examine
Cancel
```

*Talk-to* must behave exactly like *Chop*: if already adjacent, open the dialogue immediately; if
not, path to the best adjacent walkable tile, show `"Walking to Mabb Truet..."`, and open the
dialogue on arrival. Reuse the `_pending_chop_tree` mechanism rather than duplicating it —
generalising it to a `_pending_interaction` of `{kind, tile}` is the suggested implementation, but
the requirement is only that walking away cancels it as cleanly as chopping already does.

On arrival, the player and the NPC **turn to face each other** before the box opens.

### R3 — The dialogue box

Deliberately modelled on Old School RuneScape, because that presentation is legible, keyboard-fast
and matches the game's register.

**Layout.** A single panel across the **bottom centre** of the screen: 62% of viewport width, capped
at 900 px, 168 px tall, sitting 24 px above the bottom edge. Two parts:

- **Chathead box** — a square on the **left**, the full height of the panel, showing the speaker's
  head (R4). The speaker's **name** sits beneath the head.
- **Text box** — the remainder. Body text, left-aligned, 2–4 lines.

When the **player** is speaking, the chathead shows the adventurer's head and the nameplate reads
`Wanderer`. Speaker alternation is the main thing that makes a conversation in this style readable —
do not skip it.

**Two node kinds:**

1. **Say node** — a speaker, 1–4 lines of text, and a next node. The bottom-right of the text box
   shows a gently pulsing `Click here to continue`.
2. **Choice node** — an optional prompt line, then 2–4 numbered options, one per line:

   ```
   1. Sure, I can do that.
   2. Not right now.
   ```

   Options highlight on hover. The number is part of the visible text, not decoration — it is what
   the keyboard shortcut refers to.

**Requirements:**

- Only one dialogue box may be open at a time.
- While it is open, the world does **not** pause — but player movement input, the context menu and
  tile hover are suppressed. Walking away mid-conversation is not possible; the conversation ends
  with `Esc` or by reaching a terminal node.
- The box suppresses `hint_label` messages until it closes.
- Text longer than 4 lines is split into consecutive say nodes by the **author**, not wrapped by the
  runtime. If a node overflows, that is an authoring bug and should print a warning.

### R4 — The chathead

**The chathead is rendered live from 3D, not authored as 2D art.** A `SubViewport` holds a small
scene containing the speaker's head, a camera framed on it, and a light matching the scene key
(`main.gd:68`). The viewport texture is drawn into the chathead box.

This is the right call for three reasons: it needs no new art pipeline, it inherits the faceted
style automatically, and every future NPC gets a chathead for free the moment they have a model.

- Render target **256 × 256**, transparent background over the panel's timber-green.
- Frame the head to fill ~80% of the square, chin at the lower third, angled slightly toward the
  text rather than straight at the camera.
- The head **bobs gently** while its owner is the active speaker — a slow ±3° yaw and nod at about
  0.6 Hz — and is still when they are not. This is what makes the box feel alive. It is a
  requirement, not a flourish.

### R5 — Input

| Input | Effect |
| --- | --- |
| `Space` or `Enter` | Advance a say node |
| Left click anywhere on the panel | Advance a say node |
| `1` – `4` | Select that numbered option on a choice node |
| Left click an option row | Select it |
| `Esc` | End the conversation immediately |

`Esc` must **not** fall through to the pause screen (`hud.gd:252`) while dialogue is open, and `G`
must not toggle the grid. Dialogue consumes input first and calls
`get_viewport().set_input_as_handled()`.

Guard against **advance-through**: for the first **0.25 s** after a node appears, `Space`, `Enter`
and clicks are ignored. Without this, holding space skips an entire conversation — the most common
complaint about this style of box.

### R6 — The dialogue data format

Dialogue is **data, not code**, so the director can write and revise it without a gameplay change.
One file per NPC: a dictionary of nodes keyed by node id.

```gdscript
{
  "start": {
    "type": "say", "speaker": "npc",
    "text": ["Aye?"],
    "next": "menu"
  },
  "menu": {
    "type": "choice",
    "options": [
      { "text": "Who are you?", "next": "who" },
      { "text": "Can I help with anything?", "next": "offer",
        "show_if": { "quest_state": ["thursdays_float", "unstarted"] } },
      { "text": "Never mind.", "next": "end" }
    ]
  },
  "offer": {
    "type": "say", "speaker": "npc",
    "text": ["Twenty willow logs by Thursday and I'll not have to do it myself."],
    "next": "menu",
    "effects": [ { "set_quest": ["thursdays_float", "offered"] } ]
  },
  "end": { "type": "end" }
}
```

Node kinds: `say`, `choice`, `end`. Node ids are unique within a file; `start` is required.

**Conditions** — `show_if` on an option, or on a say node's branch. All listed conditions must pass.

| Condition | Passes when |
| --- | --- |
| `skill_at_least: [skill, level]` | Player's skill level ≥ level |
| `has_items: [item_name, count]` | Inventory holds ≥ count of that item name |
| `coins_at_least: n` | `player.coins >= n` |
| `quest_state: [quest_id, state]` | Quest is in that state ([quest-system.md](quest-system.md)) |
| `flag: [flag_name, bool]` | Named boolean world flag matches |
| `not: { ... }` | Inverts the condition inside |

**Effects** run when a node is entered, in order:

| Effect | Does |
| --- | --- |
| `set_quest: [quest_id, state]` | Advances quest state |
| `set_flag: [flag_name, bool]` | Sets a world flag |
| `take_items: [item_name, count]` | Removes items. The node must be gated by a matching `has_items` |
| `give_coins: n` | Adds coins |
| `give_xp: [skill, amount]` | Awards XP through the existing level-up path so level-ups still fire |
| `message: "..."` | Shows a HUD line *after* the box closes |

If an option's condition fails it is **not rendered**, and the remaining options renumber so the
visible list is always `1..n` with no gaps.

### R7 — Text substitution

`{player_name}`, `{skill_level:woodcutting}`, `{coins}` and `{logs}` are substituted at display
time. Keep the list this short — it is for making a line read naturally, not for templating content.

### R8 — Preserve what works

Right-click context menus, walk-to-then-act, chop interruption, the HUD line and the pause screen
all work. Do not regress them. In particular, `Esc` → pause and `G` → grid must behave exactly as
they do today whenever no dialogue box is open.

---

## 4. Requirements — assets

For the 3D asset specialist. **These can start immediately and do not wait on the systems work.**
Build to [art-direction.md](../art-direction.md) §7b, added for this feature.

**A1 — Mabb Truet, villager model.** Willowmere's woodcutter. Full description, silhouette and
palette notes in [mabb-truet.md](../world/npcs/mabb-truet.md). Shares the adventurer's conventions
(`character.md`): soles at origin, `(1,1,1)` scale, flat-shaded, +Y up / +Z forward.

**A2 — A named `Head` node or head bone on that rig**, so the chathead SubViewport can target it
without special-casing per NPC. The adventurer's existing rig needs the same guarantee — check
`adventurer.glb` and say plainly if it does not have one, because R4 depends on it.

**A3 — Idle and talk animations.** A standing idle (weight shifted, an occasional look-around) and a
short talking loop for the chathead. Both short and cleanly loopable.

**A4 — A villager base.** Mabb should be built so a second and third villager can be derived from
her by swapping colours and one or two shapes. If building a neutral base first would be cheaper,
say so rather than doing it the expensive way.

---

## 5. Acceptance criteria

1. Right-clicking Mabb's tile offers *Talk-to Mabb Truet* / *Examine* / *Cancel*.
2. Talking from a distance walks the player adjacent and opens the box on arrival, facing her.
3. The box shows a live 3D chathead of the current speaker, their name, and their lines.
4. `Space`, `Enter` and clicking advance a say node; `1`–`4` and clicking select options.
5. Options whose conditions fail are hidden, and visible options are numbered `1..n` with no gaps.
6. Holding `Space` cannot skip more than one node per 0.25 s.
7. `Esc` closes the box and does **not** open the pause screen; pressing it again does.
8. Effects fire once per node entry — re-entering a node via a loop does not double-pay.
9. Dialogue content lives entirely in a per-NPC data file; adding a line requires no script change.
10. With no dialogue open, every existing control behaves exactly as it does today.

## 6. Verification

Re-run the existing movement and woodcutting checks in `tests/`. New coverage should include: a
conversation walked end to end, an option correctly hidden by a failed condition, an effect firing
exactly once, and `Esc` not leaking to the pause screen.
