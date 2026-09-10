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
| Stump colour blocked: `world.gd` trunks `#573f2e` vs art bible Walnut `#976a4d` | art | Art bible was wrong — it listed screenshot-sampled lit values, not materials. Stumps resolved to `#573f2e`. **The palette itself was not actually corrected at the time**; see 2026-09-10 below, where it blocked modelling a second time |

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

---

## 2026-09-10 — Two art-direction blockers, reported by the asset specialist

Modelling on Mabb Truet was blocked by the art bible. Both blockers had the same root cause.

| Observation | Kind | Outcome |
| --- | --- | --- |
| Stump brown still contradicts the bible — `#573f2e` in the build, `#976a4d` in §2 | art | **The whole palette was screenshot-sampled lit values, not albedo.** Every entry was wrong for authoring, not just Walnut. §2 rebuilt from `world.gd` `COLORS` and `create_character.py`, with the lit values kept in a clearly-labelled second column for composition judgement |
| Mabb needs grey hair and a weathered face; the palette has neither | art | The palette had no character colours at all — the adventurer shipped with sixteen of its own, invented outside the document. Those are now recorded in §2, plus four new named entries: Skin weathered, Skin weathered light, Hair ash, Hair ash light |

**The lesson worth keeping:** sampling a palette from screenshots produces a document that is
confidently wrong in a way that only shows up when an asset comes back a value-step too light. The
build's material values are the ground truth; the bible is a record of them, not a parallel source.

**The near miss:** the earlier entry above says the palette was corrected. It was not — only the
stump was. A note that records an intention as though it were an outcome is worse than no note, and
this one cost a second round trip.

---

## 2026-09-10 — Dialogue and NPCs, first session

Dialogue, quest state and Mabb's model all merged. The user's verdict on the NPC and dialogue work
was that it reads well; all feedback below is about the surface around it.

| Observation | Kind | Outcome |
| --- | --- | --- |
| Must right-click the tree's *base tile* to chop, not the tree itself | design | Root cause: all picking is a ground-plane raycast (`main.gd:146`) and nothing above the plane is pickable. Now fixable cheaply because the world refactor turned trees into real entities. Spec: [object-picking.md](object-picking.md) R1-R4 |
| Hovered objects should show a white border | design | [object-picking.md](object-picking.md) R5. Inverted-hull outline in a new palette entry, `Highlight` `#fff6e4` — warm, not pure white. The green tile tint over trees is dropped; one thing highlighted one way |
| Wants a visual 28-slot bag and a menu bar (journal, bag, settings) | design | [ui-shell.md](ui-shell.md) R2-R3. 4 x 7 grid, bottom right, mutually exclusive windows |
| Remove the logo from the top left | design | [ui-shell.md](ui-shell.md) R1. Wordmark belongs on a title screen. Corner assignments now written into [art-direction.md](../art-direction.md) §7 so the corner stays empty |
| The bottom-left box should be a running log of actions, and examine text should go there instead of screen centre | design | [ui-shell.md](ui-shell.md) R4. 100 lines, scrollback, repeats collapsed to a multiplier. The centre hint line is removed outright; continuous walk/chop status stays in the left panel so the log does not fill with noise |
| Item icons should be the item's own 3D model | design | [ui-shell.md](ui-shell.md) R5 and §4. Rendered once per item type into a cached texture, the same trick as the dialogue chathead — so the model stays the single source of truth and no PNG is re-exported when it changes. Asset specialist owns the `IconAnchor` pose convention |

All six were scope calls rather than bugs, so all six are written up rather than tweaked. No tuning
feedback on chop pacing, trip length or the new XP curve yet — the curve has still not been played
at its corrected magnitude.

---

## 2026-09-10 — Right-drag opens context menus

| Observation | Kind | Outcome |
| --- | --- | --- |
| Right-dragging to pan the camera opens a tree's context menu | bug | Right-click and right-drag both fire from the same button press (`main.gd:189`), so the menu opens before the game can know a drag was intended. Fix: menu opens on release, only under 6 px of travel. Spec: [object-picking.md](object-picking.md) R8 |

`camera.gd` already tracks drag distance at a 5 px threshold for its own purposes and nothing reads
it. The spec requires one shared threshold rather than a second copy, or the two will drift.

