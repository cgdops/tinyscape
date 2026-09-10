# Playtest Notes

A dated log of playtest sessions: what was observed, how it was triaged, and what came of it.
Its purpose is to give tuned numbers a history — so a value that was set deliberately is not
"fixed" later by someone who does not know why it is what it is.

Triage kinds: **tuning** (design doc updated) · **bug** (gameplay engineer) · **art** (asset
specialist) · **design** (raised with the user first).

---

## 2026-09-10 — Woodcutting first pass

Camera zoom (PR #1) and the Woodcutting systems and assets merged to `main`. First session with the
closed loop playable.

| Observation | Kind | Outcome |
| --- | --- | --- |
| Mabb is only a log-pile message, not a visible NPC | — | Working as designed. She is scoped to two strings until a dialogue system exists ([woodcutting-skill.md](woodcutting-skill.md) §6) |
| Stump colour blocked: `world.gd` trunks `#573f2e` vs art bible Walnut `#976a4d` | art | Art bible was wrong — it listed screenshot-sampled lit values, not materials. Palette corrected to `world.gd` `COLORS`; stumps resolved to `#573f2e` |

No tuning feedback yet on chop pacing or trip length. The numbers most likely to need it, in order:
chop interval (1.8 s), tree hit points (3/4/6), and the level-15 pine gate.

---

## 2026-09-10 — Design audit while commissioning dialogue

Not a play session. Found by reading `scripts/woodcutting_data.gd` against the design doc.

| Observation | Kind | Outcome |
| --- | --- | --- |
| XP table de-levels the player crossing level 10 — L10 1 390, L11 1 250 | bug + tuning | The design doc's two-column table was authored wrong and the code implements it faithfully. Levels 11-15 flattened to rise monotonically ([woodcutting-skill.md](woodcutting-skill.md) §3). **Gameplay engineer must sync `XP_TABLE`** |
| "90 minutes to level 15" was never true | tuning | Asserted, never checked: 2 670 XP is 107 oak logs, about 6-8 minutes. Whole curve scaled ×10 on the user's call; level 15 is now 26 700 XP, ~66 minutes. Per-log XP deliberately unchanged |
| Thursday's Float's 250 XP reward became trivial under the new curve | tuning | Scaled with the curve to 2 500, preserving its meaning (level 3 from a standing start) |

**The lesson worth keeping:** a pacing claim in a design doc is a number that has to be multiplied
out against the action table, not a feeling. Both errors survived a full implementation pass because
nobody did the arithmetic.
