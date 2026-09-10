# TinyScape Art Direction

**Status:** `approved`, and validated against the shipped look — the user approved the current
Willowmere render as the reference. Where this document previously followed the original design
spec, it now follows the build. This is the single source of truth for what TinyScape looks like.

Ownership: art direction is set in this document (see [CLAUDE.md](../CLAUDE.md)) and executed by
the 3D asset specialist (see [AGENTS.md](../AGENTS.md)). Technical conventions for existing assets
live in [character.md](character.md) and [woodcutting-assets.md](woodcutting-assets.md) and are
authoritative for those assets — this document does not override them.

**Reference image:** [screenshots/willowmere.png](../screenshots/willowmere.png). All values below
were sampled from it. When a new asset is questioned, compare against that frame.

---

## 1. The look in one line

**A sunlit tabletop diorama.** A floating slab of countryside, lit high-key and warm, built from
broad flat facets — closer to a model village under a lamp than to a rendered landscape.

## 2. Palette — `approved`

**Every hex in this table is an albedo value: the colour you assign to the material.** It is not
what the pixel looks like on screen. The scene is lit by a warm key at 0.85 energy plus 0.40 warm
ambient (`main.gd:68`), which lifts and warms every surface considerably — meadow grass authored at
`#71844b` reads as roughly `#adc56f` in a screenshot.

That distinction is the single most expensive mistake this document has made. An earlier version of
this table listed screenshot-sampled *lit* values, which meant an asset built to the document came
out about one value-step too light and too warm once it was in the engine. **Author to the albedo
column. The lit column is for composition judgement only — never paste it into a material.**

Albedo values are the ground truth in `scripts/world.gd` `COLORS` (line 30) and
`tools/create_character.py` (line 41). Where the two disagree, the build wins and this table is
corrected to match, not the other way round.

### Ground and vegetation

| Name | Albedo | Lit ≈ | `world.gd` key | Used for |
| --- | --- | --- | --- | --- |
| Meadow | `#71844b` | `#adc56f` | `grass_a` | The dominant grass green |
| Meadow shade | `#6d8048` | `#9fb266` | `grass_d` | Adjacent tiles, subtle checker variation |
| Canopy | `#758747` | `#849552` | `oak` | Deciduous foliage mid-tone |
| Canopy light | `#8d9c55` | — | `oak_light` | Sunlit foliage faces |
| Canopy shadow | `#607840` | — | `oak_dark` | Underside foliage, shadowed masses |
| Pine mid | `#2c5140` | `#334537` | `pine` | Conifer body |
| Pine light | `#3b6350` | — | `pine_light` | Lit conifer faces |
| Deep pine | `#284636` | `#283c31` | `pine_dark` | The darkest value in the scene |
| Reed | `#91965b` | — | `reed` | Pond reeds |

### Ground surfaces

| Name | Albedo | Lit ≈ | `world.gd` key | Used for |
| --- | --- | --- | --- | --- |
| Path butter | `#bda77d` | `#fae39a` | `path_b` | Footpaths. Reads near-white when lit |
| Soil | `#75694d` | — | `soil` | Under water, cut earth |
| Pale rock | `#b6b39a` | `#c7cd9c` | `stone` | Boulders, well stonework, slab edging |
| Pale rock light | `#c8c1a5` | — | `stone_light` | Lit stone faces |
| Pale rock dark | `#858a78` | — | `stone_dark` | Shadowed stone |
| Cream plaster | `#e1cfaa` | `#f8f7ca` | `plaster` | Cottage walls, awning stripe |

### Wood, water, accent

| Name | Albedo | Lit ≈ | `world.gd` key | Used for |
| --- | --- | --- | --- | --- |
| **Walnut** | `#573f2e` | `#976a4d` | `wood` | **Trunks, stumps, fences, bridge, timber framing** |
| Walnut light | `#907044` | — | `wood_light` | Lit timber, planking highlights |
| Plank | `#ab8653` | — | `plank` | Sawn boards, decking |
| Walnut dark | `#3a3026` | `#89543c` | `wood_dark` | Shadowed timber, structural beams |
| **Terracotta** | `#a75339` | `#ca7854` | `roof` | Roofs. **The scene's single saturated warm accent** |
| Terracotta light | `#b96142` | — | `roof_light` | Lit roof planes |
| Terracotta shade | `#8f4836` | `#b46e52` | `roof_dark` | Roof planes turned from the key light |
| Pond teal | `#579b9f` | `#79d0b2` | `water` | Water — green-leaning, calm |
| Brass | `#d4b16d` | `#d4b16d` | `brass` | Fittings, small metal, UI edging |
| **Highlight** | `#fff6e4` | — | — | **New.** Hover outlines and selection. A warm near-white — never pure `#ffffff`, which reads clinical against this palette |
| Iron | `#414c46` | — | `iron` | Tool heads, hinges, nails |
| Canvas | `#e9d5a5` | — | `canvas` | Awnings, sacking, tent cloth |

Brass is the one entry where albedo and lit value coincide, because it was sampled from the UI
rather than from a lit surface. Treat that as a coincidence, not a pattern.

### Characters

Sampled from the shipped adventurer (`tools/create_character.py:41`, converted from Blender's linear
Base Color to sRGB). These were built before this table existed; they are recorded here now so the
next character does not invent a second set.

| Name | Albedo | Used for |
| --- | --- | --- |
| Skin | `#ce9e7c` | Faces, hands. Warm, mid-value |
| Skin light | `#daaa86` | Nose, ears, lit facets |
| Skin weathered | `#b3805e` | **New.** Outdoor-worked faces — Mabb and villagers who cut, haul or fish. Ruddier and a value-step darker than Skin |
| Skin weathered light | `#c79a76` | **New.** Lit facets on a weathered face |
| Hair walnut | `#593a2c` | The adventurer's hair. Note it is within two points of Walnut `#573f2e` — hair and timber share a register deliberately |
| Hair walnut light | `#794f33` | Sunlit hair facets |
| Hair ash | `#8f8b7e` | **New.** Grey hair. Desaturated and slightly warm-green so it sits with Pale rock rather than reading as blue-grey |
| Hair ash light | `#a8a396` | **New.** Lit facets on grey hair |
| Eye ivory | `#f6f1df` | Eye whites |
| Ink | `#2c2f29` | Eyes, brows, the darkest character value |
| Mouth | `#814c3c` | Mouths |
| Teal tunic | `#3c9189` | The adventurer's tunic. **Reserved to the player** |
| Teal trim | `#52a697` | Its woven edging. **Reserved to the player** |
| Saffron | `#e6b85b` | The adventurer's scarf. **Reserved to the player** |
| Saffron light | `#f8d376` | Its folded edge. **Reserved to the player** |
| Charcoal blue | `#4d5b61` | Trousers |
| Chestnut leather | `#8a5f44` | Belts, pouches, boots, aprons |
| Chestnut leather light | `#a37a55` | Stitched edges, worn leather |
| Boot sole | `#4c4338` | Soles |
| Canvas pack | `#a6a079` | Rucksacks, sacking |

### The environment ground

| Name | Albedo | Used for |
| --- | --- | --- |
| Sage void | `#8eaa9c` | The flat background behind the diorama (`main.gd:58`). Not a sky |
| Sage fog | `#a7bdaa` | The distance fog tint (`main.gd:64`) |

### Palette rules

1. **Author to the albedo column.** The lit column exists so you can reason about how a scene will
   compose. It is never a material value.
2. **Terracotta is the focal point, and it is rationed.** The cottage roof is the only large
   saturated warm mass in a field of greens, which is precisely why the eye goes to it. **One
   saturated warm accent per scene area.** A second red roof nearby would flatten the composition.
   Terracotta does not appear on characters.
3. **Teal and saffron belong to the player.** The adventurer is the only teal-and-saffron figure in
   the world. That is how the player finds themselves in a crowd, and it is why villagers are built
   from greens, browns and greys.
4. **Greens separate by value, not hue.** Meadow `#71844b` against deep pine `#284636` is a wide
   value gap, and that gap is what makes the tree line read. Never place two greens of similar
   value against each other.
5. **The high end carries the light.** Path butter and cream plaster are already high-value and the
   key light pushes them near-white. Do not darken them toward "realistic" stone, and do not
   pre-brighten them to match the lit column.
6. **Water is green-leaning teal, not blue.** It sits between the meadow and the sage void, so it
   never fights the roof for attention.
7. **New colours get added to these tables with a name and a purpose.** Never invent a colour
   per-asset. If a new colour is genuinely needed, it comes here first.

## 3. Form language — `approved`

- **Flat-shaded facets, no textures.** Every material is a flat colour. No image textures, no
  normal maps, no external asset licences. A hard constraint, not a preference.
- **Chunky Low Poly.** Broad flat facets, generous chamfers, a light bevel where a cutting or worn
  edge needs to read. Established by the wood-cutting axe (160 triangles, four materials) — the
  reference for a small hand prop.
- **Two silhouette archetypes carry the vegetation:** rounded multi-lobe deciduous canopies and
  sharp conical pines. The contrast between blob and cone is doing the readability work. Keep new
  vegetation clearly on one side of that line or deliberately introduce a distinct third shape.
- **Readable silhouette first.** Identifiable in outline at game camera distance, or the detail is
  wasted.
- **Detail is placed, not scattered.** Individual flower clusters, grass tufts, lily pads and
  boulders are positioned deliberately. Density is low and uneven — clumps with clear space between
  them, never uniform ground cover.

## 4. Composition — `approved`

- **The world is a floating slab.** The terrain is a finite diorama with visible stone edging,
  sitting on flat sage void. There is no horizon and no skybox. New areas extend the slab; they do
  not open into distance.
- **The perimeter is fenced.** A timber post-and-rail fence rings the playable area — an in-world
  boundary rather than an invisible wall.
- **Ground reads as tiles.** Subtle value variation between adjacent grass and path tiles makes the
  grid legible without drawing it. Keep that variation small: it should be felt, not counted.
- **Paths structure the space.** Wide butter-coloured paths cross the village and lead the eye to
  the cottage.
- **The village is the subject.** UI is discreet chrome at the edges; the diorama fills the frame.

## 5. Lighting — `approved`

High-key, single warm directional key from the upper left. **Soft, long, low-contrast shadows** —
present enough to seat every object on the ground, never dark enough to hide colour. No ambient
occlusion crunch, no harsh terminators, no cinematic grading. The mood is a bright, still
afternoon.

## 6. Scale and engine conventions — `approved`

- Godot **+Y up, +Z forward**; Blender +Z up, -Y forward, converted on export.
- The adventurer stands **~1.94 m** with soles at the origin. All props are sized against them.
- Scale stays `(1, 1, 1)`. Metres throughout.
- Held items attach via a named socket on the hand bone (`Hand.R` → `AxeSocket.R` → `AxeMount.R`);
  keep the mount's transform, it carries the axis conversion.

## 7. UI — `approved`

Dark timber-green panels (`#415247`) with fine brass edging and warm off-white text. Large serif for
place names; quiet sans-serif for controls. **Panels sit in the corners and the centre of the screen
stays clear** — the diorama is the thing worth looking at.

**Corner assignments**, so windows stop competing for the same space
([design/ui-shell.md](design/ui-shell.md)):

| Corner | Holds |
| --- | --- |
| Top left | **Empty.** No wordmark, no logo — those belong to a title screen |
| Top right | Minimap and place name |
| Bottom left | The message log — a scrolling history of what the player has done |
| Bottom right | The menu bar, and whichever window it has opened above it |
| Centre | Nothing, except the dialogue box, which sits low and is dismissable |

**Only one window is open at a time.** Bag, journal and settings are mutually exclusive.

**Hover and selection are outlined, not tinted** — `Highlight` `#fff6e4`, a thin line, no fill, no
pulse. This applies equally to a tree in the world and a slot in the bag, so the player learns one
visual language for "this is what you are pointing at". The travel destination marker is the only
thing in the game that pulses, and it keeps that to itself.

**Item icons are renders of the item's own model**, not hand-drawn art, so an object and its icon can
never drift apart. The only 2D art in the game is UI furniture: menu glyphs and panel edging.

## 7b. NPCs and the chathead — `approved`

Added for [design/dialogue-system.md](design/dialogue-system.md). Villagers are the first characters
in the scene other than the player, and the rules that keep them coherent are these.

**Villagers are shorter and wider than the adventurer.** The adventurer is ~1.94 m; village adults
run **1.65–1.78 m**, with a **wider shoulder-to-hip ratio**. The player should read as the tall,
lightly-built newcomer among people built by work. This is the single most important proportion rule
here — get it wrong and the cast looks like reskins.

**Silhouette at 5 m.** Every villager must be identifiable by outline alone from the game camera.
That means one strong shape decision each — a wide apron, a stooped back, a hat brim — not a
costume detail. No capes, no long flowing hems, nothing that reads as adventuring gear.

**Register, per [§8](#8-how-the-worlds-fiction-shapes-the-art).** Village characters wear the
Village register: mended, mismatched, hand-made. Charter and guild characters, when they exist, wear
the Charter register: matched, stamped, slightly officious. A villager should never look issued.

**Palette.** Characters draw from the Characters table in §2 and add nothing. Work clothes take
**Canopy shadow** `#607840`, **Chestnut leather** `#8a5f44` and **Deep pine** `#284636`; linens take
**Cream plaster** `#e1cfaa`. Faces on anyone who works outdoors take **Skin weathered** `#b3805e`,
not the adventurer's **Skin** `#ce9e7c`. **Terracotta `#a75339` is reserved for roofs** and does not
appear on a character — it is the scene's one saturated warm accent and it stops working if it walks
around. **Teal `#3c9189` and saffron `#e6b85b` are reserved for the player.** **Brass `#d4b16d`
appears on exactly one small object per character** — a buckle, a hook, a clasp.

**Heads carry more facet detail than bodies.** A head that reads at 5 m is not the same as one that
reads at 256 px in a dialogue box. Give the head roughly **twice the facet density** of the torso,
concentrated on brow, cheekbone and jaw. Everything else stays as coarse as the props.

**Rig contract.** Every character carries a node or bone named `Head`, positioned at the base of the
skull, whose forward axis is the character's forward axis. The dialogue chathead frames itself from
this node, so a missing or misaligned `Head` is a broken feature, not a cosmetic flaw. All other
conventions from [§6](#6-scale-and-engine-conventions--approved) apply unchanged: soles at origin,
`(1,1,1)` scale, +Y up / +Z forward, flat-shaded and textureless.

**Chathead framing.** 256 × 256, transparent background, head filling ~80% of the square with the
chin on the lower third, turned a few degrees toward the text rather than facing the camera square
on. Lit by the same warm key as the scene ([§5](#5-lighting--approved)) so the head in the box and
the head in the world are recognisably the same person.

## 8. How the world's fiction shapes the art — `draft`

From the [world bible](world/lore/world-bible.md). The setting is a working frontier, and the art
should agree:

- **Things are used.** Willowmere's pond is a log holding pond, the footbridge is a working log
  crossing, the well is the oldest thing in the village. Props look worked, not decorative.
- **Two registers.** Guild and charter objects are new, standardised, slightly officious — clean
  edges, stamped brass, matched sets. Village and Custom objects are older, hand-made, mismatched.
  The contrast is the setting.
- **The Custom is underplayed.** Offerings at stumps and the well are small ordinary objects placed
  with care. Never glowing, never runic, never obviously magical.
- **The Longwood is older.** Moving away from the coast, forms get larger, darker in value and less
  regular — the difficulty dial made visible. This is where deep pine and canopy shadow dominate
  and terracotta disappears entirely.

No assets have been built to this section yet.

## 9. Open

- **Character scale in frame.** ~~The adventurer reads small at default camera distance.~~
  Resolved as a camera question: see [design/camera-zoom.md](design/camera-zoom.md). The player
  will be able to zoom close at will, so the character's proportions stay as they are. This does
  mean the adventurer will be seen at close range — re-check facet density and silhouette against
  §3 once that lands.
- **Item icons.** ~~No direction set.~~ Resolved: icons are rendered from the item's own 3D model
  rather than drawn, framed from an `IconAnchor` pose the asset specialist authors into each item
  GLB. See [design/ui-shell.md](design/ui-shell.md) R5 and §4, and §7 above for why no hand-drawn
  item art exists in this game.
- No direction set yet for: architecture beyond the cottage, terrain and foliage variety beyond the
  three tree archetypes, or anything in the Longwood.
- **NPC visual variation** is partly covered — §7b sets proportions, register, palette and the rig
  contract for a single villager, but says nothing about how a cast of six differs from each other.
  That direction is due before a second and third villager are commissioned.
