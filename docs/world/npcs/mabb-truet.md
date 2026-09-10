# NPC — Mabb Truet

**Status:** `approved` · **Location:** Willowmere, the lumber clearing · **First appears:** the
Woodcutting loop ([woodcutting-skill.md](../../design/woodcutting-skill.md) §6) · **Requires:**
[dialogue-system.md](../../design/dialogue-system.md), [quest-system.md](../../design/quest-system.md)

Willowmere's woodcutter, and the first person in TinyScape who says anything. She is the game's
tutorial, its first quest giver, and the reason logs are worth cutting — all without ever being told
she is any of those things.

---

## 1. Who she is

Fifties. Terse. Has cut this stretch of the Sallow since before the Timber Charter existed and has
opinions about the Charter she does not share with strangers. She buys logs because Harrowick's
shipwrights need them and she is the one who floats them downriver — every Thursday, water
permitting.

She is not impressed by you and does not pretend otherwise. She is also not unkind: she will tell
you exactly what you need to know, once, without decoration, and then go back to work. The warmth is
in the fact that she keeps answering.

**Her one Custom detail:** she leaves something small at the stump of every tree she fells, and
never mentions it or explains it. If asked directly she changes the subject. The player will see it
happen and will not be told why. That is the correct amount of the Custom at this stage — do not
have her explain it, in this quest or the next one.

---

## 2. Voice

- **Short sentences.** She uses about half the words the situation calls for.
- **Work first.** She answers questions in terms of what needs doing, not how she feels.
- **Dry, never winking.** The humour comes from her flatness, not from jokes.
- **No exposition.** She never explains the world; she mentions parts of it and moves on. Harrowick,
  the float, the Charter and the Longwood get named without being defined.
- **Never says the word "quest", "adventurer" or "level."** If a line could appear in a tooltip, it
  is the wrong line.

Sample cadence, for anyone writing new lines for her:

> "Willows first. Oak when your arms know what they're doing."
>
> "It floats Thursday or it sits till next Thursday. Sallow doesn't take requests."

---

## 3. Placement

- **Home tile:** `Vector2i(21, 2)` — the lumber clearing, standing beside the log pile at
  `LOGPILE_TILE = Vector2i(22, 1)` (`world.gd:14`). If that tile is blocked or unreachable, the
  gameplay engineer should move her to the nearest walkable clearing tile adjacent to the pile and
  note the change here.
- **Facing:** toward the pile, `Vector2i(1, -1)`, so the player approaching from the village sees
  her three-quarters rather than from behind.
- **Examine line:** *"Willowmere's woodcutter. She has not stopped working to look at you."*
- She does not move in this pass ([dialogue-system.md](../../design/dialogue-system.md) R1).

---

## 4. Look — for the asset specialist

Build to [art-direction.md](../../art-direction.md), including §7b. This is the **Village register**,
never the Charter register: hand-made, mended, mismatched.

- **Height ~1.70 m**, against the adventurer's 1.94 m. She should read as shorter and **broader** —
  a wider shoulder-to-hip silhouette than the player's. She is the only character in the scene who
  looks like she does this for a living.
- **Silhouette at 5 m:** a squat, wide, planted shape with a strong horizontal at the shoulders. No
  cape, no long hem, nothing that flutters. Legible against the log pile by being wider and darker
  than it.
- **Palette,** from the approved table — no new colours:
  - Sleeveless overtunic in **Canopy shadow** `#4c583a`, over long sleeves in **Cream plaster**
    `#f8f7ca` pushed slightly grey.
  - Heavy apron and gloves in **Walnut** `#976a4d`, worn dark to **Walnut dark** `#89543c` at the
    edges where the work happens.
  - Trousers and boots in **Deep pine** `#283c31` — the darkest value on her, anchoring her to the
    ground.
  - **Brass** `#d4b16d` on exactly one thing: a buckle or a tally-hook at her belt. One point of
    metal, no more.
  - **No terracotta.** That accent belongs to the roofs, and it should stay theirs.
- **Grey hair, short, tied back and out of the way.** A weathered face — the head is what carries
  her in the chathead box, so it takes more facet detail than the body does.
- **Held or nearby:** a felling axe, heavier and plainer than the player's. Leaning against the pile
  is better than in her hand — it lets the idle animation be her hands working rather than posing.

---

## 5. Dialogue

Final text. Node ids match the format in [dialogue-system.md](../../design/dialogue-system.md) R6.
Quest-specific branches live in [thursdays-float.md](../quests/thursdays-float.md); this file holds
her standing conversation.

### 5.1 Greeting — first time ever

`start`, gated on `flag: [met_mabb, false]`. Sets `met_mabb` true.

> **Mabb:** "You're the one who came up the river road."
>
> **Mabb:** "Mabb Truet. I cut, I stack, I float it down to Harrowick. That's the whole of me."

Falls through to `menu`.

### 5.2 Greeting — thereafter

> **Mabb:** "Aye?"

### 5.3 The menu

Options appear in this order, with those whose conditions fail hidden and the rest renumbered.

| # | Option | Shown when | Goes to |
| --- | --- | --- | --- |
| — | *"How do I cut a tree?"* | `woodcut_level` is 1 **and** `flag: [chopped_a_tree, false]` | `teach_chop` |
| — | *"What do you do with the logs?"* | always | `teach_pile` |
| — | *"Anything worth cutting up here?"* | `skill_at_least: [woodcutting, 5]` | `teach_tiers` |
| — | *"What's that you left at the stump?"* | `flag: [saw_offering, true]` | `custom` |
| — | *(quest options)* | see [thursdays-float.md](../quests/thursdays-float.md) | — |
| — | *"Never mind."* | always | `end` |

The tutorial options **retire themselves**: once the player has chopped a tree, the first option
stops appearing. Nothing is more deadening than an NPC still explaining the controls forty minutes
in. `chopped_a_tree` is set by the woodcutting system on the player's first successful chop, and
`saw_offering` when the player is nearby as Mabb's felling idle plays out — the gameplay engineer
should set it on first fell of any tree if that idle does not exist yet.

### 5.4 `teach_chop` — the tutorial

> **Wanderer:** "How do I cut a tree?"
>
> **Mabb:** "Right-click the tree. Pick 'Chop'. Your legs will do the walking."
>
> **Mabb:** "Then you keep swinging until it's down. Willows come apart in three. Oak takes four,
> and you'll feel it."
>
> **Mabb:** "Walk off mid-swing and you've done nothing but tire yourself. Stand still and finish."

Falls back to `menu`.

### 5.5 `teach_pile` — the sink

> **Wanderer:** "What do you do with the logs?"
>
> **Mabb:** "They go on the pile. Pile goes on the water. Water goes to Harrowick, and Harrowick
> pays me for the trouble."
>
> **Mabb:** "Right-click the pile and put yours on it. I'll pay you the same as I'd pay anyone —
> four a willow, six an oak."
>
> **Mabb:** "Bring pine and we'll talk properly."

Falls back to `menu`.

### 5.6 `teach_tiers` — the level gate, without saying "level"

Shown from Woodcutting 5.

> **Wanderer:** "Anything worth cutting up here?"
>
> **Mabb:** "Willow's what the village burns. Oak's what the village builds with."
>
> **Mabb:** "Pine's what the shipwrights want, and pine's up the Longwood side. Fourteen a log."
>
> **Mabb:** "Don't go at it yet. You'd blunt the axe and waste the tree, and I'd have to say
> something about it."

Falls back to `menu`.

### 5.7 `custom` — the deflection

Shown once the player has seen her leave something at a stump.

> **Wanderer:** "What's that you left at the stump?"
>
> **Mabb:** "Nothing that concerns the axe."
>
> **Mabb:** *(after a moment)* "You'll do it too, if you're still here in a year. Nobody'll tell you
> to."

Falls back to `menu`. **She never explains this.** If a future quest is tempted to have her explain
it, that is the wrong quest.

### 5.8 `end`

> **Mabb:** "Mind the roots."

Terminal.

### 5.9 Existing string, unchanged

The log pile deposit line stays exactly as it is at `scripts/main.gd:226`:

> *"Mabb counts your logs without looking up. 'They'll float Thursday.'"*

---

## 6. What she is not, yet

- **Not a shop.** She buys logs at the pile and that is all. Selling the player equipment needs an
  inventory and shop UI that do not exist, and it is the natural bridge to combat when they do.
- **Not a source of lore.** The Charter, the Custom and the Longwood are named by her, never
  explained by her.
- **Not friendly on a timer.** Her warmth increases with what you have done, not with how many times
  you have clicked her.
