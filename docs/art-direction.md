# TinyScape Art Direction

**Status:** `approved` for everything marked so below. This is the single source of truth for what
TinyScape looks like. Asset work should be built against this document; where it is silent, ask
rather than assume, and the answer gets written back here.

Ownership: art direction is set in this document (see [CLAUDE.md](../CLAUDE.md)) and executed by
the 3D asset specialist (see [AGENTS.md](../AGENTS.md)). Technical conventions for existing assets
live in [character.md](character.md) and [woodcutting-assets.md](woodcutting-assets.md) and are
authoritative for those assets — this document does not override them.

---

## 1. The look in one line

**A hand-made diorama you could pick up.** Faceted, chunky, warm, and readable at a glance —
built objects rather than rendered ones.

## 2. Palette — `approved`

From the design spec. These are the whole palette; new colours get added here with a name and a
purpose rather than invented per-asset.

| Name | Hex | Used for |
| --- | --- | --- |
| Moss | `#71844b` | Ground cover, grass, the dominant green |
| Deep pine | `#283e34` | Foliage masses, shadowed vegetation, UI panels |
| Pond blue | `#579b9f` | Water, calm and slightly desaturated |
| Warm stone | `#c2b698` | Paths, walls, the well, worked stone |
| Walnut | `#573f2e` | Timber, trunks, structural wood |
| Brass | `#d4b16d` | Metal fittings, UI edging, small bright accents |

Also in play from the character: teal tunic, saffron scarf, canvas, leather. From the axe: honey
wood, dark steel. These are `approved` in place; if they become general-purpose, promote them into
the table with names.

**Rules.** Brass is an accent — small areas, high value, never a large surface. Water stays calm and
low-contrast. Greens carry the world; keep them separated in value, not in hue, so foliage reads
against grass.

## 3. Form language — `approved`

- **Flat-shaded facets, no textures.** Every material is a flat colour. No image textures, no
  normal maps, no external asset licences to manage. This is a hard constraint, not a preference.
- **Chunky Low Poly** is the approved direction, established with the wood-cutting axe: broad flat
  facets, generous chamfers, a light bevel where a cutting or worn edge needs to read.
- **Readable silhouette first.** Every object must be identifiable in outline at typical game camera
  distance. Detail that doesn't survive that test is wasted.
- **Individually placed, not scattered.** Vegetation and props are placed deliberately. The village
  is composed like a diorama.

**Poly budget.** The axe is 160 triangles with four materials, and is the reference for a small
hand prop. Larger props and architecture scale up proportionally, but the test is always the
silhouette, not the count.

## 4. Scale and engine conventions — `approved`

Set by the existing assets; do not deviate without flagging the cost.

- Godot **+Y up, +Z forward**; Blender +Z up, -Y forward, converted on export.
- The adventurer stands **~1.94 m** with soles at the origin. All props are sized against them.
- Scale stays `(1, 1, 1)`. Metres throughout.
- Held items attach via a named socket on the hand bone (`Hand.R` → `AxeSocket.R` → `AxeMount.R`);
  keep the mount's transform, it carries the axis conversion.

## 5. Lighting and camera — `approved`

Soft directional shadows, a single clear key direction, calm water. The 3D diorama fills the
screen: the village is the focal point, not the UI. Nothing should read as harsh, high-contrast or
cinematic — the mood is a well-lit afternoon.

## 6. UI — `approved`

Dark timber-green panels with fine brass edges. Large serif for the village title; quiet
sans-serif for controls. UI is discreet chrome around a diorama, never a dashboard.

## 7. How the world's fiction shapes the art

From the [world bible](world/lore/world-bible.md). The setting is a working frontier, and the art
should agree:

- **Things are used.** Willowmere's pond is a log holding pond, the footbridge is a working log
  crossing, the well is the oldest thing in the village. Props should look worked, not decorative.
- **Two registers.** Guild and charter objects are new, standardised, slightly officious — clean
  edges, stamped brass, matched sets. Village and Custom objects are older, hand-made and
  mismatched. Both belong; the contrast is the setting.
- **The Custom is underplayed.** Offerings at stumps and the well are small, ordinary objects
  placed with care. Never glowing, never runic, never obviously magical.
- **The Longwood is older.** As assets move away from the coast, forms get larger, darker in value
  and less regular. This is the difficulty dial made visible.

Status: `draft` — this section follows from approved lore but no assets have been built to it yet.

## 8. Open

- No direction set yet for: architecture beyond the existing cottage, NPC visual variation, terrain
  and foliage variety, item icons, or anything in the Longwood.
- Nothing here has been re-validated against a fresh render since the axe. When the next asset
  lands, check it against §2–§6 and update whatever this document failed to predict.
