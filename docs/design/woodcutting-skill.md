# Skill Design — Woodcutting

**Status:** `approved`.
**Owners:** gameplay engineer (`GEMINI.md`) for systems; 3D asset specialist (`AGENTS.md`) for
assets. The two halves are independent and should be built in parallel.
**Touches:** [scripts/player.gd](../../scripts/player.gd),
[scripts/world.gd](../../scripts/world.gd), [scripts/hud.gd](../../scripts/hud.gd),
[tests/test_woodcut.gd](../../tests/test_woodcut.gd), plus new tree and item assets.

---

## 1. The four questions

**Fantasy.** You are a newcomer learning a trade that built this coast. Felling a tree is physical,
slow and satisfying, and the woodland notices how you treat it.

**Loop.** Walk to a tree → chop → receive logs and XP → carry logs somewhere that wants them →
better trees become available → repeat with better yields.

**Inputs and outputs.** In: an axe, time, inventory space. Out: logs of a given type, Woodcutting XP,
and a stump that regrows.

**Unlocks.** Higher levels open better tree types, which produce more valuable logs and feed
production skills later. Level is also standing with the **Timber Charter** — see §7.

---

## 2. Current behaviour

From the code as it stands:

| Aspect | Current |
| --- | --- |
| Chop interval | `1.8 s`, matching the animation clip length |
| Yield | `logs += 1` per interval, unbounded, no inventory |
| XP | Flat `25` per chop regardless of tree |
| Level | `1 + int(xp / 100)` — linear, unbounded |
| Tree types | `pine` and `oak` exist in `world.gd`, but **chopping ignores type** |
| Felling | One chop turns the tree into a stump; `respawn_timer = 25.0 s` |
| Sink | **None.** Logs only accumulate |

**The core problem:** logs are a number that only goes up. Nothing consumes them, level does
nothing, and tree type is cosmetic. This design closes that loop.

---

## 3. Requirements — systems

### R1 — Logs become items in an inventory

Logs stop being an integer on the player. Add a simple inventory: a fixed **28 slots**, each slot
holding a stack of one item type. Woodcutting produces a typed `log` item; a full inventory stops
chopping with the message *"Your rucksack is full."*

28 slots is the RuneScape convention and it exists to create a **trip loop**: fill up, walk back,
unload. That trip is the loop, not an inconvenience — do not raise the cap to avoid it.

### R2 — Tree types have distinct tiers

Chopping reads the tree's `type` and applies its row:

| Tree | Level req | XP per log | Chop interval | Respawn | Where |
| --- | --- | --- | --- | --- | --- |
| Willow | 1 | 20 | 1.8 s | 20 s | Village edge, by the pond |
| Oak | 1 | 25 | 1.8 s | 25 s | Common throughout |
| Pine | 15 | 45 | 2.7 s | 35 s | Lumber clearing, denser stands |

Willow is new and is the *deliberate low tier* — it exists so the pond edge is a valid, slightly
worse place to train, and because the village is called Willowmere and has no willows in it.

Attempting a tree above your level gives *"You need Woodcutting level 15 to cut pine."* and does not
start the animation.

### R3 — XP curve

Replace `1 + int(xp / 100)` with a table. Levels 1–20 for now; the curve is roughly geometric at
about 1.10× per level, which is the shape RuneScape uses and the reason early levels feel quick.

| Level | Total XP | Level | Total XP |
| --- | --- | --- | --- |
| 1 | 0 | 11 | 1 625 |
| 2 | 85 | 12 | 1 870 |
| 3 | 180 | 13 | 2 125 |
| 4 | 290 | 14 | 2 390 |
| 5 | 415 | 15 | 2 670 |
| 6 | 560 | 16 | 3 200 |
| 7 | 725 | 17 | 3 830 |
| 8 | 915 | 18 | 4 570 |
| 9 | 1 135 | 19 | 5 440 |
| 10 | 1 390 | 20 | 6 460 |

**Levels 11-15 are deliberately flattened** (per-level steps of 235, 245, 255, 265, 280 against the
255 that preceded them) so that level 15 lands on 2 670 exactly, as approved. The curve resumes its
intended acceleration at 16, where the step jumps to 530. That discontinuity sits immediately *after*
the pine gate, which is the right place for it: the run-up to pine stays predictable, and levels past
it slow down again.

> **Fixed 2026-09-10 — the curve was not monotonic.** Level 10 was 1 390 XP and level 11 was
> 1 250, so a player de-levelled crossing 10. The two-column table was authored wrong and
> `scripts/woodcutting_data.gd:19` implements the error faithfully. Levels 11-15 are now flattened
> to reach 2 670 at level 15 as approved. **Gameplay engineer: `XP_TABLE` needs syncing to the
> table above.** See the pacing warning below — the magnitude of the whole curve is a separate,
> still-open question.

**Pacing intent: level 15 should be about 90 minutes of steady cutting** — a real but not punishing
wall in front of pine.

> **Open — the curve does not deliver that, by roughly an order of magnitude (raised 2026-09-10).**
> Oak gives 25 XP per log and yields one log per 1.8 s chop
> ([woodcutting_data.gd:42](../../scripts/woodcutting_data.gd)). 2 670 XP is therefore **107 oak
> logs — 192 seconds of swinging.** Allowing for walking between trees, respawns and a deposit trip
> every 28 logs, an effective 3.7 s per log puts level 15 at **six to eight minutes**, not ninety.
> The original 90-minute figure was never checked against the tier table.
>
> Closing the gap means scaling the whole curve up about **tenfold** — level 15 at 26 700 XP is
> ~1 070 oak logs, or **65-70 minutes**. The alternative, cutting per-log XP to a tenth, is worse:
> small numbers going up feel miserly, and the tier values are good as they are.
>
> **Not applied.** Multiplying an approved curve by ten is a pacing change, not a bug fix.

**These numbers are tuning parameters. Implement them as a data table, not as constants scattered
through the code**, so they can be changed without touching logic.

### R4 — Felling takes more than one chop

A tree has **hit points**: willow 3, oak 4, pine 6. Each chop interval removes one and yields one
log. The tree becomes a stump when they reach zero. This makes felling feel like work and makes the
respawn timer meaningful.

### R5 — Logs have somewhere to go

Add a **log pile** at the woodcutter's yard (`world.gd` already places one — see the
"Woodcutter's logpile in lumber clearing" at line ~455). Interacting with it deposits all logs from
the inventory and pays out. Payment is a running **coin** count for now; a full economy is out of
scope.

| Log | Value |
| --- | --- |
| Willow | 4 |
| Oak | 6 |
| Pine | 14 |

Pine being more than twice oak is deliberate: it is the reason to want level 15.

The pile is owned by **Mabb Truet**, the village woodcutter (§6). She does not need dialogue for
this to work — a HUD message on deposit is enough. Do not build a dialogue system for this.

### R6 — HUD reflects the new state

The existing readout becomes level, XP toward next level, coins, and inventory count — e.g.
`Woodcutting: Lv 7 (915/1135 XP) | Logs 12/28 | 84c`. Keep it one line and quiet.

### R7 — Preserve what works

Walk-to-tree, the 1.8 s animation sync, interrupting a chop by moving, and the stump/respawn
visuals all work. Do not regress them. The chop animation stays at 1.8 s; for pine's 2.7 s interval,
loop the clip rather than slowing it.

---

## 4. Requirements — assets

Independent of the systems work; can start immediately. Build to
[art-direction.md](../art-direction.md).

**A1 — Willow tree.** A new silhouette, distinct from the existing oak blob and pine cone: a
shorter trunk with a broader, drooping canopy. This is the third archetype §3 of the art direction
permits. Palette: existing oak greens shifted lighter and yellower; no new colours unless the
document gains them.

**A2 — Stumps per tree type.** Three stumps matching the three trunks in width and colour. The
current stump is generic. Small, low, readable from directly above.

**A3 — Log item.** A short cut log, and the visual basis for a future inventory icon. Honey wood
per the axe's established material. Also usable as a ground/pile prop.

**A4 — Log pile prop, two states.** Empty frame and stacked. The deposit action should be visibly
worth doing. This is a **Village register** object under §8 of the art direction — hand-made,
mismatched, not a standardised Charter object.

**A5 — Optional, if cheap:** falling-tree or canopy-shake feedback on the final chop. Nice, not
required; say if it is expensive rather than building it at cost.

---

## 5. Interlock — where logs go next

Logs must feed a production skill or the sink in R5 is just a vending machine. **Firemaking is the
intended second skill** and is the cheapest possible consumer: logs in, XP out, no new items. That
comes in a separate design; this document only guarantees logs are a real item with a real value so
that it can.

Do not add further sinks here.

---

## 6. Narrative — the minimum

Only what the loop needs. No quest, no dialogue tree.

**Mabb Truet, the Willowmere woodcutter.** Fifties, terse, has cut this stretch since before the
Charter existed. She buys logs because Harrowick's shipwrights need them and she is the one who
floats them downriver. She is not a quest giver yet.

Her one characterising detail, which is all the Custom needs to be present at this stage: **she
leaves something small at the stump of every tree she fells, and never mentions it or explains it.**
The player will see it happen and will not be told why. That is the correct amount of the Custom in
a skill loop.

Two message strings carry the entire fiction of this feature:

- On deposit: *"Mabb counts your logs without looking up. 'They'll float Thursday.'"*
- On a full inventory: *"Your rucksack is full."*

That is the whole narrative requirement. Anything more waits for a dialogue system.

---

## 7. Level as standing — deferred

The world bible frames skill level as **Timber Charter rank** — who will do business with you. That
is the intended long-term meaning of a Woodcutting level, and it is **out of scope here** because it
needs NPCs and dialogue. Noted so the XP curve is not re-tuned later without remembering what it is
eventually for.

---

## 8. Acceptance criteria

1. Logs occupy inventory slots; a full rucksack stops chopping with the correct message.
2. Willow, oak and pine give different XP, intervals and log values.
3. Pine cannot be cut below level 15, and the refusal message names the level.
4. Levels follow the §3 table exactly; level 15 is reached at 2 670 XP.
5. Felling takes the hit points in R4, yielding one log per chop.
6. Depositing at the log pile empties the inventory, pays the §R5 values, and shows Mabb's line.
7. The log pile changes visual state when it holds logs.
8. Walking away mid-chop still interrupts cleanly; stumps still respawn.
9. XP, level, values, hit points and intervals all live in one data table.

## 9. Verification

```powershell
godot --headless --path . --script tests/test_woodcut.gd
godot --headless --path . --script tests/test_game.gd
godot --path . --script tests/capture.gd
```

Extend `test_woodcut.gd` to cover the level gate, the XP table boundaries, inventory limits and the
deposit payout. Capture a screenshot of the loaded log pile and check the willow silhouette against
[art-direction.md](../art-direction.md) §3 — it must not read as a third kind of oak.
