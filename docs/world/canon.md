# TinyScape Canon Index

The authoritative list of world, quest and skill documents. Nothing is canon until it is listed
here with status `approved`.

**Status values:** `draft` (proposed, may change freely) · `approved` (locked; changes need the
user's sign-off) · `implemented` (exists in the build).

## Setting at a glance

- **The Tallow Coast** — frontier of charters, guilds and harbour courts; the Longwood behind it
  keeps accounts. Status: `draft`.
- **Willowmere** — inland timber village a day up the Sallow from Harrowick; pond is a log holding
  pond, well is half a shrine. Status: `implemented` as geometry, `draft` as lore.
- **The adventurer** — the player character. Faceted, teal tunic, saffron scarf, rucksack.
  See [character.md](../character.md). Status: `implemented` (no name, history or voice approved).

## Lore

- [world-bible.md](lore/world-bible.md) — the Tallow Coast: guild-and-trade frontier with the
  Custom underneath. Direction `approved`; named specifics `draft`.
- [world-bible-proposals.md](lore/world-bible-proposals.md) — the three original directions.
  Status: `superseded` (kept for the reasoning).

## NPCs

- [mabb-truet.md](npcs/mabb-truet.md) — **Mabb Truet**, Willowmere's woodcutter. Buys logs, floats
  them to Harrowick, leaves something at every stump and never explains it. The game's first speaking
  character, tutorial and quest giver. Status: `approved`; depends on the dialogue system.

## Quests

- [thursdays-float.md](quests/thursdays-float.md) — **Thursday's Float.** Cut 20 willow logs for
  Mabb. The first quest; 8–12 minutes. Status: `approved`; blocked on dialogue and quest state.

## Skills

- [woodcutting-skill.md](../design/woodcutting-skill.md) — tiers, XP curve, inventory, log sink.
  Status: `approved`, `implemented`. **The XP curve was corrected on 2026-09-10** — it was
  non-monotonic at level 11 and an order of magnitude too small. Level 15 is now 26 700 XP,
  ~66 minutes. `scripts/woodcutting_data.gd` still holds the old values and needs syncing.

## Systems

- [dialogue-system.md](../design/dialogue-system.md) — NPCs, the OSRS-style dialogue box, chatheads,
  the dialogue data format. Status: `approved`, commissioned.
- [quest-system.md](../design/quest-system.md) — flags, quest states, the journal. Status:
  `approved`, commissioned.
- **Firemaking** — considered as the second skill and **shelved**. Burning logs is only meaningful
  once Cooking consumes the fire, and Cooking is not designed. Do not build it as a log sink.

## Changelog

- 2026-09-10 — Index created. No narrative canon established.
- 2026-09-10 — Three world bible directions proposed. None selected.
- 2026-09-10 — Direction chosen (Shipwright's Coast + Tithe). World bible written.
- 2026-09-10 — Woodcutting skill designed. Mabb Truet established as the first named NPC.
- 2026-09-10 — Woodcutting implemented and merged. Firemaking shelved as premature without Cooking.
- 2026-09-10 — Dialogue and quest state commissioned as the next system. Mabb Truet expanded into
  a full NPC with a chathead, tutorial dialogue and the first quest, *Thursday's Float*. NPC and
  chathead rules added to the art direction as §7b.
- 2026-09-10 — Woodcutting XP curve corrected: levels 11-15 flattened to remove a de-levelling bug,
  then the whole curve scaled ×10 so the level-15 pine gate takes ~66 minutes rather than ~7.
  Per-log XP, log values, intervals and hit points unchanged. Thursday's Float's XP reward scaled
  with it, to 2 500.
