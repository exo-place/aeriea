# CoC Consumables Catalog — Source Pointer

The ~62-item Corruption of Champions consumable/transformation catalog that was originally
captured across part-A.md through part-E.md is **not committed verbatim** here. It was
third-party open-source game text (AS3 source and in-game strings) from the Corruption of
Champions codebase, which we prefer not to carry in the pushed tree.

The material is fully re-fetchable from its original source.

---

## Source repository

**GitHub mirror (community fork, Ormael7):**
https://github.com/Ormael7/Corruption-of-Champions

Original game by Fenoxo. The repository is open-source AS3.

**Raw file prefix (GitHub CDN):**
https://raw.githubusercontent.com/Ormael7/Corruption-of-Champions/master/

---

## Specific files / directories to fetch

**Primary — consumables directory (the part-A..E content lives here):**
```
classes/classes/Items/Consumables/
```
Each `.as` file in this directory is one consumable item. The catalog covered
approximately A–Z alphabetically across five bands:
- A band (part-A): AbstractEquinum.as through CumBread.as
- B band (part-B): DeBimbo.as through KitsuneGift.as (approx.)
- C band (part-C): Lactaid.as through mid-alphabet
- D band (part-D): PhoukaWhiskey.as and surrounding items
- E band (part-E): SkinOil.as through late-alphabet / OvipositionElixir, Reducto

**Supporting files (referenced inline in the captured content):**
- `classes/classes/Items/Consumables/ConsumableLib.as` — shared constants
  (DEFAULT_VALUE, change-limit helpers, etc.)
- `classes/classes/Items/Mutations.as` — mutation/perk registry (PerkLib references
  throughout the consumable code point here)
- `classes/classes/Creature.as` and `classes/classes/Appearance.as` — body-model
  descriptor functions (`cockDescript`, `vaginas[]`, `breastRows[]`, skin/fur/scale
  accessors, etc.) that the outputText strings call into; these define what the
  template placeholders resolve to

Note: Mutations.as, Appearance.as, and Creature.as were not cited by URL in the part files
directly — they were identified from the code references in the captured content. Fetch them
from the same repository root under `classes/classes/`.

**Wiki (supplementary lore / mechanic descriptions):**

The CoC fan wiki was referenced as a secondary source for lore context. Known mirrors:
- https://coc.miraheze.org/ (fenwiki on Miraheze — the active community wiki as of 2025)
- Search for "Corruption of Champions wiki" if the above has moved

---

## What was there and why it matters

The five part files together constituted the ground-truth mechanical reference for CoC's
transformation system, used during the TF substrate expressiveness audit
(`tf-substrate-expressiveness.md`). The content covered:

- **~62 consumable items** spanning the full A–Z range of the Consumables/ directory
- **Per-item detail:** item description string, canUse() gating conditions, transformation
  change pool (rand-driven branches), stat modifications (str/tou/spe/int/wis/lib/sen/cor),
  body-part mutations (cock type/count, vagina type/looseness/wetness, breast rows, tail,
  ears, fur, scales, horns, wings, lower body), prerequisite checks, and quoted outputText
  game strings
- **Tiered body-change mechanics:** changeLimit caps, additionalTransformationChances,
  bad-end branches (e.g. feral horse), heat/rut induction, perk gain/removal
- **Representative breadth:** equine TFs (AbstractEquinum, Centaurinum), bimbo/debimbo
  reversal pair, dragon blood (EmberTF), sphinx hybrid (Enigmanium), growth items (GroPlus),
  combat throwables (BangBall series, BallsOfFlame), cosmetic items (HairDye, SkinOil,
  BodyLotion), and more

A future reader wanting to re-mine this material should fetch the Consumables/ directory
from the repo above and read each .as file; the content is the same material that was
captured in part-A..E.
