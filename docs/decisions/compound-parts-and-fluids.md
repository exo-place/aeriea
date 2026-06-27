# Design: Compound parts, genitalia & fluids

Status: **Design pass — no code. Not green.** Awaits the user's express approval before any
implementation. New work lands under `docs/FEATURES.md` → Not green.

This doc closes the single biggest parity gap flagged in `tf-depth-and-species.md` §4.B.5/8:
**genitalia, compound (multiple) parts, and a fluids sub-model**. It sits **on** the settled
compositional body graph (`transformation-system.md`) with **no special-casing** — compound
parts and genitalia are ordinary tagged segments, and the *only* genuinely new primitive is
**fluids as per-segment state**. Everything else falls out of the graph and the existing op
vocabulary.

Refs read: `docs/decisions/transformation-system.md` (the settled model — body = mutable
compositional graph of generic segments `{material, covering, props, tags, children}`; three
open axes; convention tags; deterministic seeded applier; description from state),
`docs/decisions/tf-depth-and-species.md` (this is its Stage-0 gap-5/gap-8 sub-design),
`docs/artifacts/text-gen-design/ref-coc.md` (CoC's `cocks[]`/`vaginas[]`/`breastRows[]` +
per-part struct — the granularity yardstick, lifted as **open props**, not a closed struct).

Setting-neutral and clinical throughout: this is **structure only** — parts, fluids,
derivation. NSFW *content* (prose, acts, interaction mechanics) is the user's domain and is
explicitly deferred (§8), as is the 3D embodiment (deferred in the parent model).

---

## 1. Status

- Design pass, **no code yet**, **Not green**, awaits the user's express approval.
- This is the Stage-0 sub-design for `tf-depth-and-species.md` gaps **5** (genitalia /
  compound parts) and **8** (fluids), extending — not modifying — `transformation-system.md`.

---

## 2. The central claim

CoC/TiTS/BDCC all reach for a **sub-object array** for the granular sexual parts:
`cocks: Cock[]`, `vaginas: VaginaClass[]`, `breastRows: BreastRowClass[]`. That array type is
**exactly what our graph already is.** A body with N of a thing is **N segments sharing a
convention tag** — no `Cock[]` type, no `breastRows[]` field, no bolt-on. "The 2nd cock" is
"the second segment tagged `genital`+`phallic` under the groin, in node-id order." Adding one
is `graft_subtree`; removing one is `remove_subtree`; growing one is `prop_delta`. These are
the **same four FORM/PROPERTY ops** that graft a tail or a quadruped lower body.

So this design adds **almost no machinery**. Concretely it adds:

1. **conventions** — which tags mark a compound member / a genital / its kind; a stable
   ordering rule so "the Nth" is deterministic;
2. **one new primitive** — `fluids`, a per-segment state block (the parent model's segments
   carry no fluid concept);
3. **two new ops** — `set_fluid_type`, `fluid_delta` (consistent with the existing op table);
4. **a derivation** — `derive_sex(body)`, a pure read over the configuration (no stored
   gender enum);
5. **a few describe-paths** — emit fluid state and member ordinals.

That is the entire surface. The rest is data.

---

## 3. Compound parts fall out of the graph

### 3.1 The convention

> **N of a thing = N sibling segments sharing a convention tag.**

No array type. A body with three phalluses is three segments, each tagged `genital` +
`phallic`, all docked under the groin region. A body with two breast-rows is two segments
tagged `breast`. The graph already permits arbitrary numbers of children at an attachment
point (`transformation-system.md` §3.1, §3.8 — coherence unenforced), so "multiple" needs
**nothing new**.

### 3.2 Stable identity & ordering — so "the Nth" is deterministic

Referencing "the 2nd cock" must be deterministic and replay-safe. Two layers, both already
native to the model:

- **Identity** is the segment's **node id** (`transformation-system.md` §3.4 — ids are unique
  within a body and stable across edits/undo). A specific member is *always* addressable by id
  regardless of order: `#genital_2`.
- **Ordinal** ("the 2nd cock") is a **derived index**, not a stored field. The applier resolves
  a compound set by tag, then **sorts by node id (lexicographic)** to get a stable order, and
  the ordinal is the position in that sorted list. Node ids are assigned by a **seeded counter
  off the action log** (same seed source as rolls — `transformation-system.md` §5.1), so the
  id ordering is itself deterministic and replay-safe. Grafting a new member appends a new id;
  it lands at a deterministic ordinal.

This means: an author writes `#genital_2` to mean a *specific* segment forever, or writes an
**ordinal selector** to mean "whatever is currently 2nd." Both are deterministic.

A new selector form (a thin addition to the structural-query targeting of
`transformation-system.md` §3.7) makes ordinals first-class:

```
{ "select": "nth_tagged", "tag": "genital", "kind": "phallic", "index": 1 }
   # 0-based: index 1 = "the 2nd phallic genital", by node-id order
{ "select": "all_tagged", "tag": "breast" }
   # the whole compound set, for fan-ops
```

`nth_tagged` resolves to **zero or one** node (no-op if the body has fewer than N+1 — the
correct no-op behavior of §3.7); `all_tagged` resolves to the set, for ops that fan across
every member. Both reduce to the existing tag/structural resolution — they are **sugar over
`resolve_targets`**, not a new targeting mechanism.

### 3.3 TF ops add/remove/target the Nth — no new ops

| want | existing op | target |
|---|---|---|
| add an Nth member | `graft_subtree` | `(groin_node, at)` |
| remove the Nth member | `remove_subtree` | `nth_tagged genital index=N` (or `#id`) |
| grow the Nth member | `prop_delta` | `nth_tagged …` / `#id` |
| convert one member's material | `set_material` | `#id` |
| retype a member | `tag` add/remove | `#id` |
| fan across all members | any of the above | `all_tagged …` (subtree-style fan, §4.2 parent) |

Every row uses an op **already in the parent's table** (`transformation-system.md` §4.2).
Compound parts add **no op** — only the two ordinal selectors (§3.2), which are targeting
sugar.

### 3.4 Worked example — a body with 2 genital segments + 2 breast segments

A biped torso with a groin region carrying two phallic genitals and one vaginal genital, plus
two breast segments on the chest. Generic segments throughout; only `tags` mark roles, and the
new `fluids` block (§4) sits on the producing segments. (Genital/fluid props are introduced in
§4–5; shown here in full to make the graph concrete.)

```
{ "root": {
  "id":"torso", "material":"flesh", "covering":"skin", "props":{}, "tags":["torso"],
  "children":[
    { "at":"neck", "node":{ "id":"head","material":"flesh","covering":"skin",
                            "props":{},"tags":["head"],"children":[] } },

    { "at":"chest_l", "node":{ "id":"breast_l","material":"flesh","covering":"skin",
        "props":{"volume_ml":650}, "tags":["breast"],
        "fluids":[ {"type":"milk","amount":0,"capacity":400} ], "children":[] } },
    { "at":"chest_r", "node":{ "id":"breast_r","material":"flesh","covering":"skin",
        "props":{"volume_ml":650}, "tags":["breast"],
        "fluids":[ {"type":"milk","amount":0,"capacity":400} ], "children":[] } },

    { "at":"groin", "node":{ "id":"pelvis","material":"flesh","covering":"skin",
        "props":{}, "tags":["pelvis","groin"], "children":[

          { "at":"genital_mount_a", "node":{ "id":"genital_1",
              "material":"flesh","covering":"skin",
              "props":{"length_cm":15,"girth_cm":11,"knot":false},
              "tags":["genital","phallic"],
              "fluids":[ {"type":"seed","amount":0,"capacity":30} ], "children":[] } },

          { "at":"genital_mount_b", "node":{ "id":"genital_2",
              "material":"flesh","covering":"skin",
              "props":{"length_cm":22,"girth_cm":14,"knot":true},
              "tags":["genital","phallic"],
              "fluids":[ {"type":"seed","amount":0,"capacity":50} ], "children":[] } },

          { "at":"genital_mount_c", "node":{ "id":"genital_3",
              "material":"flesh","covering":"skin",
              "props":{"depth_cm":12,"looseness":0,"wetness":0},
              "tags":["genital","vaginal"],
              "fluids":[ {"type":"nectar","amount":0,"capacity":40} ], "children":[] } }
    ] } }
  ] } }
```

Reading off this graph, **with no array type anywhere**:
- "the 2nd cock" = `nth_tagged genital/phallic index=1` → `#genital_2` (by id order).
- "all breasts" = `all_tagged breast` → `{#breast_l, #breast_r}`.
- a TF that adds a third phallus = one `graft_subtree` at `(#pelvis, genital_mount_d)`.
- a TF that removes the vaginal genital = `remove_subtree` of `nth_tagged genital/vaginal 0`.

This is structurally identical to grafting a tail. **Compound parts are not a special case.**

---

## 4. Genitalia conventions

Genitalia are ordinary segments. The conventions below are *agreements content opts into*
(like all convention tags — `transformation-system.md` §3.7), not a schema the engine
polices.

### 4.1 Tagging

- A genital segment carries the tag **`genital`** (marks it as a member of the compound
  genital set for ordering/derivation).
- A **kind tag** marks its form, open-vocabulary: `phallic`, `vaginal`, `cloacal`, `ovipositor`,
  `tentacular`, … (ship a few; open like all tags). Kind is a *tag*, not a `kind` field — the
  parent model has **no `kind` field** by design (§3.1) and this honors that.
- Optional **flavour tags** reuse the cross-part `TYPE_*`-style family from
  `tf-depth-and-species.md` §1.2 (`canine`, `equine`, `draconic`, …): e.g. a knotted canine
  phallus is `["genital","phallic","canine"]`. Flavour is a tag, exactly as elsewhere.

### 4.2 Attachment region

Genitals attach under a **groin/pelvis** region: a segment tagged `pelvis`/`groin` exposes
genital-mount attachment points. The pelvis is itself a generic segment under the torso (see
§3.4). This is convention only — a body may dock a genital anywhere the graph permits
(coherence unenforced, §3.8); the convention is just where content *expects* to find them.

### 4.3 Size / shape via extent + props (CoC granularity as open props)

CoC's `Cock` struct (`{_cockLength, _cockThickness, _cockType, _knotMultiplier, _isPierced…}`)
maps onto **per-segment open `props` + tags**, never a closed struct:

| CoC field | here |
|---|---|
| `_cockLength` | `props.length_cm` (number) |
| `_cockThickness` | `props.girth_cm` (number) |
| `_cockType` | kind/flavour **tags** (`phallic` + `canine`) |
| `_knotMultiplier` | `props.knot` (bool) / `props.knot_girth_cm` (number) |
| `_isPierced` | `props.pierced` (bool) — or a pierced **child segment** if structural |
| vaginal looseness/wetness | `props.looseness`, `props.wetness` (numbers); plus a `fluids` entry (§5) |
| `BreastRowClass.breastRating` (cup) | `props.volume_ml` (number), **banded** for description |
| `nipplesPerBreast` | `props.nipple_count` (number) |
| `lactationMultiplier` | a `milk` **fluid** with a production rate (§5.4) |

Because these are **open props**, an author adds `props.barb_count` for a feline phallus or
`props.ovipositor_bore_mm` with zero schema change — the same openness the three axes already
have (§3.2). Nothing here is a closed record. Banding (cup bands, length bands) for description
is the same `band(props)` concern as elsewhere (`transformation-system.md` §6) — content, not
structure.

---

## 5. Fluids — the one genuinely new primitive

The parent model's segments carry **no fluid concept**. This is the only structural addition.

### 5.1 Data shape — per-segment fluid state

A segment gains an **optional** `fluids` array. Each entry is a small fluid-state block:

```
Fluid = {
  "type":     "milk",   # OPEN string — milk / seed / nectar / venom / ink / …; engine bakes in none
  "amount":   0,        # current quantity, INTEGER (mL); 0..capacity
  "capacity": 400       # max quantity, INTEGER (mL)
}
```

- `fluids` is an **array** so one part may hold **multiple** fluids (a hybrid gland, a venom +
  lubricant duct). Most parts have zero or one. Absence of the key ⇒ no fluids (the default;
  back-compatible with every existing segment — a body without `fluids` is unchanged).
- `type` is an **open string**, governed by the same convention discipline as tags — content
  agrees on `milk`/`seed`/`nectar`, invents more freely; the engine interprets none.
- Identity of a fluid within a part is `type` (one entry per type per part — `set_fluid_type`
  and deltas key on it). Ordering across parts reuses node-id order (§3.2).
- **Integers only — no float in the path** (mL, capacity). This keeps determinism exact
  (`transformation-system.md` §5.1 — replay must be bit-for-bit; floats accumulate drift).
  Production rates (§5.4) are integer-mL-per-tick.

`fluids` is per-**segment**, which subsumes "per-part": a compound member is a segment, so its
fluids are its own (each phallus its own `seed` reservoir, each breast its own `milk`). No
per-part-vs-per-segment ambiguity — there is only the segment.

### 5.2 New ops — consistent with the existing op vocabulary

Two ops join the parent's op table (`transformation-system.md` §4.2). Both carry a region
target (id / tag / structural / ordinal §3.2) and an optional `when` predicate, exactly like
every existing op:

| effect | axis | what it does |
|---|---|---|
| `set_fluid_type` | FLUID | set/rename the fluid `type` on the target (add the entry if absent; key the entry by old type or by index) |
| `fluid_delta` | FLUID | add to a fluid's `amount` and/or `capacity` on the target, **seeded + clamped to integers** |

`fluid_delta` mirrors `prop_delta` exactly:

```
{ "effect":"fluid_delta", "target":{"select":"all_tagged","tag":"breast"},
  "fluid":"milk",
  "amount":{"roll":"uniform_int","lo":10,"hi":40},   # seeded integer roll
  "capacity_delta": 0,
  "clamp_amount":[0, null] }   # null hi ⇒ clamp to the entry's capacity
```

Semantics, all clamped to integers:
- `amount` resolves through the **seeded RNG** (`{"roll":...}`) or a literal, identical to
  `prop_delta` (`transformation-system.md` §5.1) — `uniform_int`, never a float roll.
- new `amount` is **clamped to `[0, capacity]`** (the `null` hi means "this entry's capacity").
- `capacity_delta` grows/shrinks the reservoir (e.g. lactation-capacity TF); clamped `≥ 0`.
  When capacity shrinks below amount, amount is re-clamped down (deterministic).
- `set_fluid_type` on a non-existent entry **adds** it (with `amount:0` and a given/zero
  `capacity`) — the add/no-op symmetry of the FORM ops (§3.3).

`set_fluid_type` + `fluid_delta` reuse the applier's `capture(before)/apply/capture(after)`
reversible-effect machinery (`transformation-system.md` §5.2) unchanged — undo restores the
prior `fluids` entry, coalescing sums `fluid_delta`s on the same (node, type) just as it sums
`prop_delta`s (§5.4 parent). **No new applier machinery** — two more rows in `apply_op`'s
switch.

### 5.3 Description from fluid state

Description stays **derived on read** (`transformation-system.md` §6). The traversal, at each
segment with a `fluids` array, emits a phrase from `(type, amount, capacity)`:

```
for fluid in segment.fluids:
  fullness = band(fluid.amount, fluid.capacity)   # empty / partial / full / overfull
  emit fluid_phrase(fluid.type, fullness)         # convention phrase per type+band
```

`band` is the same integer-banding helper used for props (§6 parent) — `amount/capacity` into
empty/partial/full/leaking bands. The **commitment gate** (§6 parent) applies unchanged: a
fluid is described only if the segment actually carries that `fluids` entry — no phantom milk.
Concrete prose ("milky", "swollen", "dripping") is **deferred content** (§8) — structure emits
a `(type, fullness)` token; the realizer turns it to words later.

### 5.4 Optional production-over-time tie-in to `sim_clock` (noted, not over-built)

Fluids that refill over time (lactation, seed) fit the **existing staged-TF machinery** with
**no new clock concept**. A segment may carry an optional integer production prop, e.g.
`props.milk_rate_ml_per_h`, and a **standing staged TF** (`transformation-system.md` §4.1,
`staged:true`) does one `fluid_delta` per stage:

```
{ "id":"lactation_production", "staged":true, "stage_seconds":3600, "max_stages":null,
  "gate":{"op":"has_tag","tag":"breast"},
  "ops":[ {"effect":"fluid_delta","target":{"select":"all_tagged","tag":"breast"},
           "fluid":"milk", "amount":{"prop":"milk_rate_ml_per_h"},
           "clamp_amount":[0,null]} ] }
```

This advances on `sim_clock` exactly like every other staged TF, is seeded/replay-safe, and
clamps at capacity (so it self-limits). **This is deliberately minimal:** production is just a
staged `fluid_delta`, not a bespoke sub-sim. Draining (emptying a reservoir) is a `fluid_delta`
with a negative amount, triggered by whatever act-layer exists later. We **note** this tie-in
and stop — the rich production/consumption economy is deferred content (§8), not structure.

---

## 6. Gender / sexual characteristics = DERIVED, not stored

There is **no gender field, no sex enum.** "Gender"/sex presentation is a **read over the
configuration** — which genital/breast segments and tags are present — produced by a pure
derivation function. This is the direct analogue of TiTS's `canineScore()` (species = a score
over parts, never a stored field — `tf-depth-and-species.md` §1.2) and BDCC's multi-valued
`getSpecies()`: **sex is a configuration, not a stored value, and any mix falls out.**

### 6.1 The derivation

```
derive_sex(body) -> { has_phallic, has_vaginal, has_breasts, counts, presentation_tokens }:
  genitals = all_tagged(body, "genital")
  phallic  = [g for g in genitals if "phallic" in g.tags]
  vaginal  = [g for g in genitals if "vaginal" in g.tags]
  breasts  = all_tagged(body, "breast")
  return {
    "has_phallic": len(phallic) > 0,
    "has_vaginal": len(vaginal) > 0,
    "has_breasts": len(breasts) > 0,
    "counts": { "phallic": len(phallic), "vaginal": len(vaginal), "breast": len(breasts) },
    "presentation_tokens": tokens(...)   # see below — open, combinatorial
  }
```

`presentation_tokens` is an **open, combinatorial** read, never a single enum value. A
convention mapping (content-owned, not engine-baked) turns the booleans into tokens — and a
body can satisfy several at once or none:

| configuration | derived tokens |
|---|---|
| phallic, no vaginal, no breasts | `{male}` |
| vaginal + breasts, no phallic | `{female}` |
| phallic + vaginal (+/- breasts) | `{herm, intersex}` |
| breasts + phallic, no vaginal | `{male, busty}` (cowboy-ish) |
| none of the three | `{neuter, agender}` |
| 3 phallic + 1 vaginal + 4 breasts | `{herm}` + counts surfaced structurally |

Crucially the tokens are **derived labels**, like the optional aliases of
`transformation-system.md` §3.6 (a `taur` alias over a configuration). The **configuration is
ground truth**; "female"/"male"/"herm" are *shorthand read off it*, never stored, and a novel
configuration simply yields whatever token set its parts license — there is no enum to fall
outside of, so every configuration is describable (exactly the §3.6 property).

### 6.2 Why this avoids an enum (and what "feminization" targets)

- **No stored field to keep in sync.** A TF that grafts a vaginal genital or removes a phallic
  one *changes the derivation's output for free* — there is no `gender` field to also update,
  so the classic CoC/BDCC "set the flag *and* mutate the part" double-write bug cannot occur.
- **"Feminization" is not a sex-setter — it is ordinary part ops.** It is a TF that, e.g.,
  `remove_subtree`s phallic genitals, `graft_subtree`s a vaginal one, `graft_subtree`s breast
  segments, and `fluid_delta`s up a milk capacity. The derived sex *follows*. There is no
  `set_sex("female")` op and the op table needs no such thing.
- **Any mix is reachable** because the derivation is combinatorial over independent parts —
  the same reason hybrids fall out of the species model (`tf-depth-and-species.md` §3).

`derive_sex` is a **pure read** (like `describe`, re-derived on every query, never cached as
state) and adds **no op and no field** — it is a derivation function alongside `describe`.

---

## 7. Integration — what's actually new (kept minimal)

Against `transformation-system.md`, the complete delta:

**New data:**
- optional `fluids: Fluid[]` on a segment (§5.1) — integer `{type, amount, capacity}`. Absent
  ⇒ unchanged; fully back-compatible with every existing body.
- (no other new fields — genital size/shape are existing `props`; kind/flavour are existing
  `tags`; member count is the graph itself.)

**New ops (2):** `set_fluid_type`, `fluid_delta` (§5.2) — two rows in the applier's `apply_op`
switch, reusing the existing capture/clamp/seeded-roll/coalesce machinery. No new applier
structure.

**New targeting sugar (2 selectors):** `nth_tagged`, `all_tagged` (§3.2) — thin wrappers over
the existing `resolve_targets` (id / tag / structural). Not a new targeting mechanism.

**New derivations / describe-paths (2):**
- `derive_sex(body)` (§6) — a pure read alongside `describe`, no state.
- fluid description (§5.3) — one branch in the existing `describe` traversal emitting a
  `(type, fullness)` token, gated by the existing commitment gate.

**Unchanged:** the segment graph, the three axes, the deterministic seeded applier, the
TFHolder/sim_clock staging, reversibility/coalescing/undo, save/load round-trip, the
commitment gate, naming-as-convention, coherence-unenforced. Compound parts and genitalia ride
entirely on these.

That is the whole integration: **+1 optional field, +2 ops, +2 selectors, +2 read-paths.**

---

## 8. MVP slice — what to build first

The smallest thing that proves compound parts + genitalia + fluids + derived sex work as data
on the existing model (built *after* the parent model's own MVP, `transformation-system.md`
§7, exists):

- **A starting body with genitalia** (§3.4): a biped with a `pelvis`/`groin` region carrying
  ≥2 genital segments (mixed `phallic`/`vaginal`) and 2 `breast` segments, each producing
  segment carrying a `fluids` entry (`seed`/`nectar`/`milk`, integer amount/capacity).
- **A few compound/fluid TFs**, one per new path, all rows over the ops:
  1. `add_phallic_genital` — `graft_subtree` a phallic genital at a free groin mount (proves
     "the Nth member" grows by one; re-derive sex after).
  2. `remove_nth_genital` — `remove_subtree` of `nth_tagged genital index=N` (proves ordinal
     targeting + deterministic ordering; undo re-grafts it).
  3. `grow_member` — `prop_delta` on `nth_tagged genital …` (`length_cm`/`girth_cm`).
  4. `set_lactating` — `fluid_delta` `capacity_delta` on `all_tagged breast` (open the
     reservoir) + the optional standing `lactation_production` staged TF (§5.4) refilling on
     `sim_clock` and self-clamping at capacity.
  5. `feminize` — a TF composing remove-phallic + graft-vaginal + graft-breast + milk-capacity
     delta, to prove **derived sex changes with zero gender field** (§6.2).
- **Fluid description** (§5.3): the `describe` traversal emits `(type, fullness)` tokens off
  each segment's `fluids`, gated by the commitment gate (no phantom fluid).
- **Derived sex readout** (§6): `derive_sex(body)` printed in the harness, recomputed live —
  shown changing across the `feminize` TF and across add/remove-genital, with **no stored
  gender** anywhere in the save.
- **Determinism + save/load** carried from the parent MVP: integer fluids round-trip; the same
  seed+action-log reproduces identical fluid amounts and identical member ordering (node-id
  order); undo restores fluids and re-grafts removed members exactly.
- **Tests** (added to `tests/run.sh`, extending the parent suite): ordinal targeting hits only
  the Nth member and **no-ops past the end**; `fluid_delta` clamps to `[0, capacity]` and stays
  integer; `set_fluid_type` adds-if-absent; production staged TF self-limits at capacity;
  `derive_sex` returns the right token set across configurations (male / female / herm / neuter
  / multi-part) with no gender field present; undo of add/remove-genital and of `fluid_delta`
  restores the exact graph.
- **Playtest surface:** extend the parent's text harness (`RichTextLabel` + buttons) — pick a
  compound/fluid TF, advance the clock, watch fluid description and the derived sex readout
  update live, undo, make permanent. Observe the actual transcript (mandatory playtest).

**Ship it OPEN from day one** (same discipline as the parent §7): `fluids[].type`, genital
kind/flavour tags, and the sex-token mapping are **open vocabulary, few shipped values** — not
a closed enum. The applier and derivations work unchanged as values are added.

---

## 9. Open questions

Genuinely open (everything else is decided above):

1. **Connectivity / orifice pairing for the act layer.** Fluids model production/storage
   (`{type, amount, capacity}`); they do **not** model an orifice's connection to a partner or
   the *transfer* of fluid between bodies during an act. BDCC hangs `Orifice` + transfer off
   parts. Is inter-body fluid transfer (a) just two `fluid_delta`s the act-content emits (no new
   structure — current lean), or (b) does it want a small structural "duct/orifice connectivity"
   concept? Leaning (a) — defer until the act layer exists and pulls the requirement — but
   flagged because it is the one place the fluid model touches the deferred act content.

2. **Multi-fluid mixing semantics.** A part may hold multiple fluids (§5.1). Do mixed fluids
   ever *interact* (a combined description, a derived blend type), or do they stay independent
   entries that describe separately? Current lean: independent entries, blending is a
   description-layer concern — but unconfirmed, and a candidate first place over-modeling could
   creep in.

3. **Banding thresholds are content, but someone owns the defaults.** Cup/length/fullness bands
   (§4.3, §5.3) are description content, yet the MVP needs *some* default banding to read
   sensibly. Open: ship a minimal default band table here, or treat bands as wholly downstream
   content the MVP stubs? (Same shape as the parent's prop-banding question — likely resolves
   together.)

---

## 10. Deferred (explicitly out of scope)

Unchanged from the parent model's deferrals, plus this design's content layer:

- **The NSFW prose / act-level content / sexual interaction mechanics.** This design covers
  **structure only** — parts, fluids, derivation. *What a fluid/part feels like in prose, what
  acts exist, how interaction plays* is taste-laden, the user's domain, and authored later **as
  data on top of** this structure (the same way setting flavour is deferred off the pure TF
  system, `transformation-system.md` §2). Description here emits structural tokens
  (`(type, fullness)`, sex-token sets); the realizer that turns them into prose is the deferred
  prose engine (`docs/decisions/prose-generation.md`).
- **The 3D embodiment** — rig/mesh/animation for an arbitrary-topology body, including how a
  graft of an Nth genital or a filling reservoir *renders/animates*. The genuinely hard,
  unsolved, deferred problem from `transformation-system.md` §2.
- **The rich fluid economy** — sources/sinks beyond the single staged-production tie-in (§5.4),
  consumption modeling, fertility/pregnancy as sub-sims. Noted as adjacent layers
  (`tf-depth-and-species.md` §4.B.8), not built here.

---

*Design pass. No code. Setting-neutral, structure only. Not green. Awaits the user's express
approval.*
