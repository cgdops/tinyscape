# System Design — Quest State

**Status:** `approved` · **Owning agent:** gameplay engineer (`GEMINI.md`) · **Lands with:**
[dialogue-system.md](dialogue-system.md).

Dialogue without memory is scenery. This is the smallest state layer that lets a conversation
remember what happened, and it is deliberately small: flags, quest states, and a place to read them.
No journal UI beyond one panel, no quest chains, no branching completion.

---

## 1. Current behaviour

Read from the build at `5000c81`.

There is **no persistent state of any kind**. `scripts/player.gd` holds `woodcut_level`,
`woodcut_xp`, `coins` and `inventory` in memory for the session; `scripts/world.gd` holds tree stump
state and `set_logpile_has_logs()`. Nothing is saved and nothing is queryable by name. Quest state is
new construction, not a modification.

---

## 2. Requirements

### R1 — A single game-state store

One autoload or owned node holding two dictionaries:

- `flags: Dictionary[String, bool]` — named booleans, default `false` when absent.
- `quests: Dictionary[String, String]` — quest id to state string, default `"unstarted"`.

Both are readable and writable by dialogue effects and conditions
([dialogue-system.md](dialogue-system.md) R6). Nothing else in the codebase should hold quest
state — if woodcutting or the log pile needs to know something, it asks here.

### R2 — Quest states are a fixed, ordered vocabulary

| State | Meaning |
| --- | --- |
| `unstarted` | The player has not been offered it |
| `offered` | It has been offered and declined or not yet accepted |
| `active` | Accepted, in progress |
| `complete` | Finished and rewarded |

States move **forward only**. An attempt to move a quest backward is a bug and should print a
warning rather than silently succeeding. `offered` exists so an NPC can say *"changed your mind?"*
instead of repeating the pitch verbatim, which is the difference between a world that remembers you
and one that does not.

### R3 — A quest registry

A data file listing each quest's `id`, `display_name`, one-line `description`, and a per-state
**journal line** — the sentence the player sees telling them what to do next. Written by the
director alongside the quest design.

### R4 — Objective progress is derived, never stored

A quest that asks for twenty willow logs must count the player's inventory when asked. Do not keep a
separate counter — a counter can desynchronise from the inventory, and this project has no reason to
risk that. If a future quest needs progress that cannot be derived from world state, that is the
point to revisit this, and it should be raised rather than worked around.

### R5 — A quest journal

`J` opens a panel in the game's existing UI style ([art-direction.md](../art-direction.md) §7)
listing every quest that is not `unstarted`, its name, and its current journal line. Active quests
first, complete ones below and dimmed. `J` or `Esc` closes it. This is one panel and a list; it is
not a screen.

`Esc` closing the journal must not also open the pause screen, the same rule dialogue follows.

### R6 — A quest-state-changed signal

The store emits when a quest changes state, so the HUD can show a brief line
(`"Quest started: Thursday's Float"`) via the existing `hud.show_message()`. Keep it to one line and
quiet; there is no fanfare in this game.

### R7 — Persistence is out of scope

Nothing saves between runs. State living in one place is what makes save/load a small job later, and
that is the entire reason for R1 — but do not build it now.

---

## 3. Acceptance criteria

1. Flags and quest states are readable and writable from dialogue conditions and effects.
2. An unset flag reads `false`; an unregistered quest reads `unstarted`.
3. Quest state cannot move backward; attempting it warns.
4. `J` opens and closes the journal, and its `Esc` does not leak to the pause screen.
5. The journal shows the correct per-state line for each non-`unstarted` quest.
6. A state change emits a signal and shows one HUD line.
7. Objective counts are computed from inventory at read time, with no stored counter.

## 4. Verification

New coverage: a quest driven `unstarted` → `offered` → `active` → `complete` through dialogue; a
backward transition rejected; the journal reflecting each state; a derived objective count changing
when inventory changes without any explicit quest update.
