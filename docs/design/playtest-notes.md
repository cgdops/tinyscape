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

No tuning feedback yet on chop pacing, trip length or the XP curve. The numbers most likely to need
it, in order: chop interval (1.8 s), tree hit points (3/4/6), and the level-15 pine gate at
2 670 XP — about 90 minutes of cutting on the current assumptions.
