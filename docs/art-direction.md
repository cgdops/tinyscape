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

## 2. Palette — `approved`, sampled from the build

The original spec palette was darker and cooler than what was actually built. These are the real
values.

### Ground and vegetation

| Name | Hex | Used for |
| --- | --- | --- |
| Meadow | `#adc56f` | The dominant grass green — light, yellow-leaning |
| Meadow shade | `#9fb266` | Adjacent tiles, subtle checker variation |
| Canopy | `#849552` | Deciduous foliage mid-tone |
| Canopy shadow | `#4c583a` | Underside foliage, shadowed masses |
| Deep pine | `#283c31` | Conifers, the darkest value in the scene |
| Pine mid | `#334537` | Lit conifer faces |

### Ground surfaces

| Name | Hex | Used for |
| --- | --- | --- |
| Path butter | `#fae39a` | Footpaths — pale, warm, high-value |
| Pale rock | `#c7cd9c` | Boulders, well stonework, slab edging |
| Cream plaster | `#f8f7ca` | Cottage walls, awning stripe |

### Wood, water, accent

| Name | Hex | Used for |
| --- | --- | --- |
| Walnut | `#976a4d` | Trunks, fences, bridge, timber framing |
| Walnut dark | `#89543c` | Shadowed timber, structural beams |
| Pond teal | `#79d0b2` | Water — green-leaning, bright, calm |
| **Terracotta** | `#ca7854` | Roofs. **The scene's single saturated warm accent.** |
| Terracotta shade | `#b46e52` | Roof planes turned from the key light |
| Brass | `#d4b16d` | UI edging, lamp fittings, small metal |

### The environment ground

| Name | Hex | Used for |
| --- | --- | --- |
| Sage void | `#a7bdaa` | The background behind the diorama. Not a sky — a flat colour |

### Palette rules

1. **Terracotta is the focal point, and it is rationed.** The cottage roof is the only large
   saturated warm mass in a field of greens, which is precisely why the eye goes to it. **One
   saturated warm accent per scene area.** A second red roof nearby would flatten the composition.
2. **Greens separate by value, not hue.** Meadow `#adc56f` against deep pine `#283c31` is a wide
   value gap; that gap is what makes the tree line read. Never place two greens of similar value
   against each other.
3. **The high end carries the light.** Path butter and cream plaster are near-white. They are what
   makes the scene read as sunlit — do not darken them toward "realistic" stone.
4. **Water is green-leaning teal, not blue.** It sits between the meadow and the sage void, so it
   never fights the roof for attention.
5. **New colours get added to these tables with a name and a purpose.** Never invent a colour
   per-asset.

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
place names and the wordmark; quiet sans-serif for controls. Panels sit in the corners; the centre
of the screen stays clear.

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

- **Character scale in frame.** The adventurer reads small and generic at default camera distance
  compared to the props around them. Worth deciding whether the character gets chunkier proportions
  or the default camera comes in closer — a design question, not an asset bug.
- No direction set yet for: architecture beyond the cottage, NPC visual variation, terrain and
  foliage variety beyond the two tree archetypes, item icons, or anything in the Longwood.
