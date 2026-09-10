# Quest — Thursday's Float

**Status:** `approved` · **Quest id:** `thursdays_float` · **Estimated play time:** 8–12 minutes

---

## 1. Hook

Mabb is one raft short for Thursday and does not have the arms to fix it herself.

## 2. Prerequisites

None. This is the first quest in the game and must be completable by a player who has just spawned.

## 3. Required systems

| System | Status |
| --- | --- |
| Dialogue ([dialogue-system.md](../../design/dialogue-system.md)) | Designed, not built |
| Quest state ([quest-system.md](../../design/quest-system.md)) | Designed, not built |
| Woodcutting, inventory, coins ([woodcutting-skill.md](../../design/woodcutting-skill.md)) | **Built** |

**This quest cannot ship until the first two land.** It needs nothing else — no combat, no shop, no
timers, no persistence.

**There is no clock in the game.** "Thursday" is fiction, not a deadline. The quest cannot be failed
and cannot expire. Do not implement a timer.

## 4. NPCs and locations

- **Mabb Truet**, at the log pile in the lumber clearing ([mabb-truet.md](../npcs/mabb-truet.md)).
- **Willow trees**, already in the world.
- No new location, no new prop.

## 5. Objectives

1. Talk to Mabb and accept.
2. Cut **20 willow logs**. Any willows anywhere; the quest does not care which.
3. Return to Mabb with all 20 in your rucksack at once and hand them over.

The rucksack holds 28 ([woodcutting_data.gd](../../../scripts/woodcutting_data.gd)), so 20 fits in a
single trip. That is deliberate — the first quest should not also be a lesson in inventory
management.

**Alternate paths and edge cases:**

- **The player deposits their logs at the pile before returning.** They lose them and must cut more.
  Mabb's `active` line covers this without mocking the player.
- **The player declines.** State goes to `offered`, the offer stays available, and her re-offer line
  differs from the first pitch.
- **The player arrives with fewer than 20.** The hand-in option is hidden by its `has_items`
  condition, and her `active` line reports the shortfall using `{logs}`.
- **The player arrives with more than 20.** Take exactly 20 and leave the rest.

Objective progress is derived from inventory at read time ([quest-system.md](../../design/quest-system.md) R4).

## 6. Journal lines

| State | Line |
| --- | --- |
| `offered` | Mabb Truet needs willow logs for Thursday's float. She has not had an answer yet. |
| `active` | Cut 20 willow logs and bring them to Mabb Truet at the lumber clearing. |
| `complete` | Mabb's raft went down the Sallow on Thursday. She said to come back when your arms are better. |

## 7. Dialogue

Final text. These options are inserted into Mabb's standing menu
([mabb-truet.md](../npcs/mabb-truet.md) §5.3), above *"Never mind."*

### 7.1 The offer — `quest_state: [thursdays_float, unstarted]`

Menu option: *"Anything you need doing?"*

> **Mabb:** "There is, since you ask."
>
> **Mabb:** "I'm a raft short for Thursday. Willow, twenty logs. It's not skilled work and it's not
> quick, and I've a shoulder that says it isn't mine to do this week."
>
> **Mabb:** "Cut them, bring them to me here. I'll see you right."

Then a choice node:

| # | Option | Result |
| --- | --- | --- |
| 1 | "Sure, I can do that." | → `accept` |
| 2 | "Not right now." | → `decline` |

### 7.2 `accept`

Effect: `set_quest: [thursdays_float, active]`, `message: "Quest started: Thursday's Float"`

> **Mabb:** "Twenty. Willow, mind — the drooping ones. Oak's no use to me for this."
>
> **Mabb:** "Come back when your rucksack's heavy."

Falls back to `menu`.

### 7.3 `decline`

Effect: `set_quest: [thursdays_float, offered]`

> **Mabb:** "Suit yourself. The river's not in a hurry either."

Falls back to `menu`.

### 7.4 The re-offer — `quest_state: [thursdays_float, offered]`

Menu option: *"About those logs."*

> **Mabb:** "Twenty willow. Still short."

Then the same accept/decline choice as 7.1.

### 7.5 In progress, short — `quest_state: [thursdays_float, active]`, fewer than 20 willow logs

Menu option: *"About the logs."*

> **Wanderer:** "I'm still cutting."
>
> **Mabb:** "You've {logs}. I need twenty willow. The pile isn't going to shrink on its own."

Falls back to `menu`.

### 7.6 Hand-in — `quest_state: [thursdays_float, active]` **and** `has_items: ["Willow Log", 20]`

Menu option: *"I've got your twenty willow logs."*

Effects, in order: `take_items: ["Willow Log", 20]`, `give_coins: 150`,
`give_xp: [woodcutting, 250]`, `set_quest: [thursdays_float, complete]`,
`set_flag: [mabb_trusts_you, true]`,
`message: "Quest complete: Thursday's Float"`

> **Mabb:** *(counting, without looking up)* "Twenty."
>
> **Mabb:** "Hundred and fifty. That's over the going rate and I'll thank you not to mention it in
> the village."
>
> **Mabb:** "You cut cleaner than you did on Monday. That's the whole trick — there isn't one."

Then, on a second say node:

> **Mabb:** "When you've coin enough, there's a pedlar comes up from Harrowick with iron. Buy
> something with an edge before you go past the gate."
>
> **Wanderer:** "What's past the gate?"
>
> **Mabb:** "Things that don't stand still and let you hit them."

Falls back to `menu`.

**Note for the gameplay engineer:** the pedlar and what is past the gate **do not exist**. These
lines are a hook for the combat work that comes next and must not be implemented as content. If the
player goes east through the gate they find the forest exactly as it is today.

### 7.7 After completion — `quest_state: [thursdays_float, complete]`

Menu option: *"Did the raft get away?"*

> **Mabb:** "Thursday, on the tide, same as it always does."
>
> **Mabb:** "Nothing else needs doing. Cut what you like — I'll buy it."

Falls back to `menu`.

## 8. Rewards

| Reward | Amount | Why |
| --- | --- | --- |
| Coins | 150 | Against 80 for selling the same logs at the pile. The quest is worth doing, and 150 is a meaningful fraction of a first weapon whenever one exists |
| Woodcutting XP | 250 | Ten oak logs' worth — level 3 from a standing start. It should feel like a shortcut, not a skip. **If the XP curve is scaled up ([woodcutting-skill.md](../../design/woodcutting-skill.md) §3), scale this with it** so the reward keeps the same meaning |
| Flag `mabb_trusts_you` | true | Not spent by anything yet. It is the hook the shop and the next quest read |
| World state | None | Nothing in the scene changes |

**Deliberately no item reward.** Equipment needs a system that does not exist, and a reward the
player cannot use is worse than coins they can.

## 9. Barks and idles

- No barks in this pass; there is no bark system and Mabb does not wander.
- If the asset specialist's felling idle ships, the moment where she sets something down at the stump
  is what sets `saw_offering` and unlocks her deflection line
  ([mabb-truet.md](../npcs/mabb-truet.md) §5.7). If it does not ship, set the flag on the player's
  first felled tree instead.

## 10. Acceptance criteria

1. The offer appears only at `unstarted`; the re-offer only at `offered`.
2. Accepting sets `active` and shows one HUD line.
3. The hand-in option is invisible below 20 willow logs and visible at 20 or more.
4. Handing in removes exactly 20 willow logs, pays 150 coins and 250 XP, and sets `complete`.
5. Handing in with 25 logs leaves the player 5.
6. Any XP awarded can trigger a level-up through the normal path.
7. The completed quest reads correctly in the journal and cannot be re-completed.
8. Nothing in the quest depends on real time.
