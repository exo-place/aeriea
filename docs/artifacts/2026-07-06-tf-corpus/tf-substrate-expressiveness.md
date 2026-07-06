# TF substrate — adversarial expressiveness test against the mined corpus

Read-only analysis. Ground truth read directly from `scripts/sim/tf/*` (tf_part.gd,
tf_tree.gd, tf_marinada.gd, tf_engine.gd, tf_library.gd, tf_rng.gd) and
`tests/tf_substrate_test.gd` — not from the prompt summary.

## What the substrate can actually do (capability, from the code)

- **Body = tree of `TFPart` {fields, children, weak parent}** (tf_part.gd). Identity in
  fields, location in structure. Fields hold plain values.
- **A transformation = a marinada closure** returning `{transition, fields}` (tf_library.gd,
  tf_engine.gd `tick` lines 58-64). The engine writes each `fields` entry into
  `part.fields` **in place** — and writes NOTHING else.
- **Continuous magnitude = `prog` + lerp** (the `advance`/`accrue` defs, tf_library.gd
  56-90). This is the clean path for any scalar field.
- **Discrete field snap** = conditional write on a `prog`/field threshold (`if` in the
  evaluator, tf_marinada.gd 162).
- **Seeded stochastic** = `chance`/`draw-*` keyed off `(seed, coord)` with a per-transition
  `_draws` counter (`maybe_grow`, tf_library.gd 106-116; tf_rng.gd).
- **Relational cross-part READ** = `find-first`/`nearest-ancestor`/`topmost-in-chain`/
  `has-ancestor` with marinada lambda predicates (tf_tree.gd, tf_marinada.gd 311-316). The
  `track_breast` pattern (tf_library.gd 93-101) reads another part and writes its own field.
- **Actions** (external inputs, tf_engine.gd `apply_action` 95-116): `tick`, `set_field`,
  `start` (append transition), `stop` (drop transitions). **That is the entire action set.**

## What the substrate CANNOT do (the load-bearing limits, from the code)

1. **No structural mutation, anywhere in the deterministic pipeline.** The tick return
   protocol is `{transition, fields}` (tf_engine.gd 59-64) — a transformation can only
   rewrite fields on the part it rides. It cannot add a child, detach a part, split a part,
   or merge two parts. And `apply_action` (tf_engine.gd 95-116) has **no graft/detach op** —
   only `set_field`/`start`/`stop`. `TFPart.add_child`/`detach` exist (tf_part.gd 46-58) but
   **nothing in tick or the action log calls them.** So topology is frozen after `builder`
   builds the tree. The README's "discrete topology via graft/detach" is aspirational — it is
   not implemented on either the tick or action path.
2. **A transformation writes only its OWN part.** Cross-part is read-only (pull, never push).
3. **The tick takes ONE root** (tf_engine.gd `tick` 40). Two bodies cannot interact; there is
   no identity container separate from the tree.

These three are the entire adversarial surface. Almost every non-clean case below reduces to
limit #1.

---

## Per-case analysis (regular-stride sample, N=31)

Stride: shifti (28 cases) every ~4 → 1,5,9,13,17,21,25; giantessworld (13) every ~3 →
1,4,7,10,13; fictionmania (10 main) every ~2 → 1,3,5,7,9; TiTS (~30 substantive) walked ~every
5 → RedPill, Catnip, DracoGuard, ManUp, Virection, Hornitol; CoC part-A..E, two per file band →
AbstractEquinum, BimboLiqueur, Enigmanium, GroPlus, ManticoreVenom, OvipositionElixir, Reducto,
VampireBlood.

### Shifti

**S1 — "Gloves" (human → inflatable deer pool-toy).** VERDICT: **cannot.** Material swap
(skin→vinyl) is a clean field; the painted cartoon eye is a field swap. But an inflation
valve, a balloon tail, and a printed product tag *appear* (new parts = topology, limit #1),
and the endpoint is a *labeled commercial product* — an object identity, not a body. GAP:
BODY-MODEL (object-identity endpoint) + ENGINE (topology).

**S5 — "A Bee" (human → bumblebee, downscaled).** VERDICT: **expressible-awkwardly.**
Whole-body downscale is a `size` field lerp; if size is per-part it fans out to N transitions
(awkward). Insect anatomy (compaction, limb loss) is topology (limit #1). Hive-communication
sense = mind (OUT-OF-SCOPE). GAP: ENGINE (topology) for the anatomy; scale itself is clean.

**S9 — "Nothing Up My Sleeve" (human → hollow living fursuit).** VERDICT: **cannot.**
Skin→fabric is a field, but "no internal organs whatsoever" = remove every internal part
(topology), and the signature beat is **detachable parts that stay conscious and functional**
— a detached head is a subtree with no root, and "still works when detached" is behaviour/mind.
GAP: BODY-MODEL (hollow/no-root-living-part) + ENGINE (topology).

**S13 — "Not Beyond Conjecture" (man → dolphin-merman, reversible w/ residue).** VERDICT:
**needs-missing-primitive.** Gills open, a second tooth-row grows, webbing grows, breasts form,
legs fuse into a fluke — every beat is grow-or-fuse (topology, limit #1). The reversible-with-
residue arc IS clean (stop + start reverse transitions via the log; leave some un-reversed).
GAP: ENGINE (topology).

**S17 — "Not Awake Enough" (man → toaster).** VERDICT: **cannot.** Legs drop off, arm detaches,
torso crushes to a cube, tongue/teeth become heating elements → object. Topology + object
identity. GAP: BODY-MODEL + ENGINE.

**S21 — "Echoes of Extinction" (woman → theropod).** VERDICT: **needs-missing-primitive.**
Scales-through-skin (material field + reveal), bones grow/warp (size fields), head extends
(field), teeth reshape (enum) are all clean; but a counterbalancing **tail grows** and a
**blood-crest rises along the spine** (topology, limit #1). Mind absorbed = OUT-OF-SCOPE.
GAP: ENGINE (topology).

**S25 — "Conversions" (were-eagle, cyclic reversible, partial humanoid form).** VERDICT:
**expressible-awkwardly.** Hands→wings and feet→talons are part *type* swaps (clean enum);
feathers = field; beak = face enum. One tail growth = topology. Cyclic shift = the action log
(start/stop). Mostly enum-clean with a single topology snag. GAP: ENGINE (tail only). Mind
dissociation OUT-OF-SCOPE.

### Giantess World

**GW1 — "I want to be a GIANTESS" (slow dietary growth).** VERDICT: **expressible-cleanly.**
Pure scalar: `height` lerp, plus a separately-tracked `foot_size` lerp. The mundane majority.
No gap.

**GW4 — "A Rose By Any Other Name" (off-page → house-sized).** VERDICT: **expressible-cleanly.**
End-state is a `size` field set (or a fast lerp). No gap.

**GW7 — "America Runs on Hanna" (person → coffee, distributed across cups).** VERDICT:
**cannot.** Total loss of body/limbs/mouth → a liquid in a cup; sentience distributed across
*many* cups over time. No part tree; no single root. GAP: BODY-MODEL (become-substance +
distributed identity).

**GW10 — "Glitter" (person → glitter speck).** VERDICT: **cannot.** Endpoint is an inert
decorative particle indistinguishable from surrounding specks. Degenerate non-body. GAP:
BODY-MODEL (become-substance/particle).

**GW13 — "Fairysitter" (ongoing proportional shrink 180→16.5cm).** VERDICT:
**expressible-cleanly.** Continuous `size` lerp, still running mid-scene — exactly the `prog`
model. Strength differential and environment rescale = OUT-OF-SCOPE (world/rendering). No
body-model gap.

### Fictionmania (TG)

**FM1 — "Forever Hexed" (M→F, genitals-first, ordered waves).** VERDICT:
**needs-missing-primitive.** Penis-shrink, height-loss, muscle-dwindle, face-feminize,
hair-lengthen, pelvis-restructure are all clean field lerps, and the strict ordering is
sequential transitions gated on prior `prog`. But **breast tissue develops** (new part) and
**penis inverts to a vulva** (remove-part + create-part, or at minimum a create) — topology,
limit #1. The single commonest TG motion is blocked. GAP: ENGINE (topology).

**FM3 — "The River Goddess" (castration wound → female anatomy, ~1 year).** VERDICT:
**needs-missing-primitive.** Face/hair/limb softening = slow field lerps (gradual pace is the
`prog` sweet spot); genital site "heals into" a vulva could be a part reflavor (field). But
**breasts develop** = new part (topology). GAP: ENGINE (topology).

**FM5 — "Please, Honey" (whole-body swap between two people).** VERDICT: **out-of-scope.** The
bodies do not change — two *minds* relocate. Body-state is unchanged; the whole content is
mind-relocation + gradual memory bleed. Nothing for a body substrate to express (and the tick
can't see two roots anyway, limit #3). GAP: OUT-OF-SCOPE (mind-semantics).

**FM7 — "The Hunter's Fall" (M→F, roots reshape, purpose-built muscle, identity death).**
VERDICT: **needs-missing-primitive.** Hips widen, frame shrinks = fields; new vaginal channel /
breasts / "musculature designed for milking" = create-parts (topology). Identity-hollowing =
OUT-OF-SCOPE. GAP: ENGINE (topology).

**FM9 — "Dandelion Ch.7" (M→14ft alien female, overshoots human).** VERDICT:
**needs-missing-primitive.** Spine-elongate, rib-flare, waist-narrow, legs-to-11ft, translucent
skin, glow — all scalar/material fields, the substrate's strength even at absurd magnitudes.
But **breasts expand into being** (topology). The biomimetic suit = clothing (OUT-OF-SCOPE).
Personality escalation = OUT-OF-SCOPE. GAP: ENGINE (topology) — note this one is *scalar-
dominant*, blocked only by the one breast-growth beat.

### TiTS

**T-RedPill — myrmedion (ant-person).** VERDICT: **needs-missing-primitive.** Skin/legs/face/
eyes are field+enum (clean); but grow two antennae, grow vestigial wings, grow a **second pair
of breasts** = topology (limit #1). Per-dose bounded-random selection (changeLimit) adds a
budget-coordination strain (see GAP 4). GAP: ENGINE (topology) + authoring (budget).

**T-Catnip — feline, incl. taur route legCount 2→4→6.** VERDICT: **needs-missing-primitive.**
Ears/eyes/muzzle/tongue = enum (clean). But grow a tail, grow a tail-cock/tail-cunt sub-part,
and the **taur route grows extra leg pairs** = topology. GAP: ENGINE (topology).

**T-DracoGuard — gryvain dragon-folk.** VERDICT: **needs-missing-primitive.** Scales/eyes =
field; wings→draconic = enum, but the **second pair of wings** = topology; tail = topology;
and the signature **gryvain cunt = ring after ring of clitorises deepening down the canal,
count growing per dose** = a repeated child-part whose count grows (topology, the purest case).
GAP: ENGINE (topology, count-growth).

**T-ManUp — masculinization + grow-first-cock (race-keyed shape).** VERDICT:
**needs-missing-primitive.** Femininity/tone/lips/hips = clean fields; beard = field. But
**grow a first cock where none exists** and **grow a first pair of balls** = create-part
(topology); shrinking a breast row to nothing may be remove-part. The race-keyed cock-shape
switch itself is a clean enum once the part exists. GAP: ENGINE (topology).

**T-Virection — cock splits lengthwise into two identical cocks.** VERDICT:
**needs-missing-primitive.** Length/thickness/virility = clean fields, but the signature is
**one part → two parts** (split topology) — beyond even simple graft; the substrate has no
split. GAP: ENGINE (topology, split).

**T-Hornitol — horns (count 1→2→3, length scales, type switchable).** VERDICT:
**expressible-awkwardly.** Length = field lerp (clean), rhino↔narwhal type = enum (clean), but
**horn COUNT growth** = add-part (topology). A single-axis item that still trips limit #1 on
its count axis. GAP: ENGINE (topology, count).

### CoC

**C-AbstractEquinum — equine/unicorn/alicorn potion (changeLimit random pool).** VERDICT:
**needs-missing-primitive.** Stats (str/tou/int as root fields), fur (skin field), face/ears/
hooves (enum), eye color (field), horse-cock reflavor (enum) all clean. But **create a horse
cock where none exists, grow balls, grow a horse tail, grow unicorn horns, grow alicorn wings**
= topology, pervasively. The changeLimit/changes budget across a big pool = budget strain (GAP
4). Bad-end "become a sapient horse NPC" = OUT-OF-SCOPE (game state). GAP: ENGINE (topology) +
authoring (budget).

**C-BimboLiqueur — M→F bimbo.** VERDICT: **needs-missing-primitive.** Height/hips/butt/tone/
hair-color/face = clean fields. But **create a vagina, remove all cocks, remove balls,
grow/expand breasts** = topology. Bimbo-brains = OUT-OF-SCOPE (mind). GAP: ENGINE (topology).

**C-Enigmanium — sphinx (harpy+cat+human+centaur blend).** VERDICT:
**needs-missing-primitive.** Sphinx skin color = field; cat-cock reflavor = enum. But grow a
cat tail, grow a sheath, create balls, grow/shrink breasts = topology. GAP: ENGINE (topology).

**C-GroPlus — targeted enlargement (balls/breasts/clit/cock/nipples menu).** VERDICT:
**expressible-cleanly.** Every branch is a *scalar enlargement of an existing part*:
`ballSize`, `breastRating`, `clitLength`, `cockLength`/`cockThickness`, `nippleLength` — all
field lerps, one transition per target part. "Fuckable nipples" = bool field. The menu is just
which part gets a `start` action. This is the substrate's ideal case. No gap.

**C-ManticoreVenom — lion/scorpion/manticore chain.** VERDICT: **needs-missing-primitive.**
Stats/skin/eyes/face/tongue/ears = field+enum; vagina→manticore = enum. The **ordered
prerequisite chain** ("lion arms required before lion face," "scorpion tail required before
manticore pussy-tail") is a genuine substrate STRENGTH — exactly `find-first`/`has-ancestor`
predicate gating (tf_tree.gd). But growing the scorpion tail, the wings, and the lion-mane
rear-body = topology. GAP: ENGINE (topology); gating itself is clean.

**C-OvipositionElixir — egg-pregnancy state.** VERDICT: **expressible-cleanly.** `pregnancyType`
enum field, `incubation` integer counter, egg status = `{type, size, quantity}` integer fields;
upgrades/accelerations are integer arithmetic. This is precisely the "fluids = integer fields"
model, no topology. No gap.

**C-Reducto — shrink a chosen body part.** VERDICT: **expressible-cleanly** (with one caveat).
`ballSize -=`, `butt -=`, `clitLength /=`, `cockLength *= 2/3`, `hips -=`, `nippleLength /=` are
clean scalar shrinks; bee-cock→human-cock = enum. The lone caveat: `horns.count--` = remove-part
(topology). Dominant behaviour is clean scalar. GAP: ENGINE (topology) only on the horns branch.

**C-VampireBlood — vampire/bat (pure vs impure fork).** VERDICT: **needs-missing-primitive.**
Ears/eyes/face = enum, skin-pale = field (all clean). But **grow vampire/bat wings** and a
bat-collar rear-body = topology. GAP: ENGINE (topology); enum swaps clean.

---

## Aggregate

### Verdict distribution (N=31)
- **expressible-cleanly: 6** — GW1, GW4, GW13, GroPlus, OvipositionElixir, Reducto.
- **expressible-awkwardly: 3** — S5, S25, Hornitol.
- **needs-missing-primitive: 16** — S13, S21, FM1, FM3, FM7, FM9, RedPill, Catnip, DracoGuard,
  ManUp, Virection, AbstractEquinum, BimboLiqueur, Enigmanium, ManticoreVenom, VampireBlood.
- **cannot: 5** — S1, S9, S17, GW7, GW10.
- **out-of-scope: 1** — FM5.

Clean-or-awkward (substrate handles it as-is or with authoring effort): **9/31.**
Blocked on a missing capability: **21/31.** True body-model walls: **5/31.**

### Recurring gaps, ranked by prevalence

**GAP 1 — Structural mutation (grow / remove / split / merge parts). ~19/31 cases.**
The single dominant hole. The tick return protocol writes fields only (tf_engine.gd 59-64) and
the action set has no graft/detach (tf_engine.gd 95-116); `TFPart.add_child`/`detach` exist but
are unreachable from tick or the log. So NO authored transformation and NO logged action can add
a tail/wings/horns/second-breast-row/extra-legs/a-cock/breasts, remove balls/cocks/a-row, split
one cock into two, or fuse legs into a tail.
CLASS: this is neither a clean BODY-MODEL gap nor a clean CONTENT gap. The tree *can hold* both
before- and after-states (a tail is just a child `TFPart`), so it fails the BODY-MODEL test; but
it is *not authorable as marinada* today, so it fails the CONTENT test. It is an **ENGINE /
missing-primitive gap** — a real substrate limit, on the BODY-MODEL side of the split (needs new
machinery, not just authoring). Two tiers: (a) discrete graft/detach is a modest new action op +
a structural return-protocol slot; (b) *gradual, `prog`-driven* emergence (a tail filling in over
ticks) is deeper — the return protocol would have to touch structure, not just fields. Because
"grow breasts + build genitals" is the literal definition of most TG, and "grow tail+ears+wings"
of most furry/species TF, this one gap gates roughly two-thirds of the corpus.

**GAP 2 — Become-a-non-body-substance / distributed / hollow identity. 5/31 cases**
(S1, S9, S17, GW7, GW10). The model is a connected tree of body parts with one root
(tf_part.gd). A puddle/liquid/particle/appliance/hollow-shell has no meaningful part tree;
"distributed across many cups" has no single root; a detached-but-living part is a rootless
subtree. CLASS: **BODY-MODEL gap** (genuine — the tree literally can't hold the state). Real
prevalence: the inanimate/substance TF is a whole genre in shifti and giantessworld.

**GAP 3 — Cross-body / two-root coupling. ~1-2/31 in sample** (FM5; and the paired zero-sum
grow+shrink of GW2, sampled adjacent). `tick` takes one root (tf_engine.gd 40); two bodies can't
interact and there's no identity container distinct from the tree. CLASS: **BODY-MODEL gap**.
Low sample prevalence but structural; also underlies whole-body swaps and mass-migration TFs.

**GAP 4 — Per-dose bounded-random change budget (changeLimit/changes). ~8 CoC/TiTS cases.**
Encodable via seeded `chance` + per-candidate "already-applied" flags, but the shared budget
counter must be read across many transitions on different parts, and a transition can only WRITE
its own part (limit #2) — so decrementing a shared budget is awkward. CLASS: **CONTENT /
authoring-ergonomics** (expressible, not impossible) — NOT a substrate flaw, but a real strain
that the "write only your own fields" rule imposes on the corpus's most common TF engine shape.

**GAP 5 — Cross-part PUSH inversion. Pervasive, expressible.** A-affects-B must be authored as
B-pulls-from-A (the `track_breast` pattern, tf_library.gd 93-101); coordinated multi-part change
needs every affected part to carry its own puller transition. CLASS: **CONTENT / ergonomics** —
the model expresses it, awkwardly at scale.

**Correctly OUT-OF-SCOPE (not gaps):** mind/identity (bimbo-brains, identity-death, submission,
memory-bleed, dissociation), rendering/perspective (giantess environment rescale, strength
differential), world-interaction (observation-gating, become-NPC game state), clothing (biomimetic
suit). Very prevalent as co-occurring axes; correctly outside a body-state substrate's remit.

### BODY-MODEL (real substrate limits) vs CONTENT (just unwritten) — the clean split

- **BODY-MODEL / real limits:** GAP 1 (structural mutation, ~19 cases — the crux), GAP 2
  (non-body/substance/distributed, ~5), GAP 3 (cross-body, ~1-2). Fixing these needs new engine
  machinery.
- **CONTENT / authoring only (substrate already suffices):** every scalar field change (size,
  length, color, tone, femininity, libido, sensitivity), every part-type/enum reflavor (cock→horse,
  fur→scales, face→muzzle, legs→digitigrade+hooves), integer reproductive state (pregnancy, egg
  count), gradual pacing (`prog`), stochastic per-step application (`chance`), reversal/residue (the
  log), and prerequisite-gated ordering (`find-first`/`has-ancestor`). GAP 4 and GAP 5 are
  ergonomic strains within this bucket, not walls.

### Bottom line (honest)

The substrate expresses the corpus's **calm scalar-and-reflavor core faithfully and even
elegantly** — every single-attribute change and every part-type swap is a clean field write via
the `advance`/lerp pattern, integer reproductive state fits the fluids model exactly, gradual
pacing is the native `prog` idiom, and the relational prerequisite-gating that CoC/TiTS lean on
(require-lion-arms-before-lion-face) is a genuine strength of the `find-first`/`nearest-ancestor`
host ops. GroPlus, Reducto, the OvipositionElixir, and plain giantess grow/shrink drop in cleanly.
But the corpus's center of gravity is **not** scalar reflavor — it is **adding and removing parts**:
growing a tail/wings/horns/a second breast row/extra legs/a cock/breasts, removing balls/cocks/a
row, splitting one cock into two, fusing legs into a tail. That is the literal definition of most
TG and most species TF, and the substrate as built **cannot author any of it** — the tick return
protocol writes fields only (tf_engine.gd 59-64) and the action set has no graft/detach
(tf_engine.gd 95-116), so ~2/3 of the sample is blocked on one missing capability. A separate,
genuine BODY-MODEL wall gates the inanimate/substance genre (become coffee/glitter/toaster/
hollow-suit) and cross-body coupling. So: the substrate does NOT yet express the corpus's range.
One high-leverage missing primitive — structural mutation, ideally `prog`-drivable — would move
the bulk of the "needs-missing-primitive" 16 into reach; the "cannot" 5 need a deeper body-model
answer for non-body substrates; mind, rendering, and world-interaction are correctly out of scope.
The good news is that the hole is narrow and named, not diffuse: the scalar substrate underneath
is sound, and it is one capability short of the genre.
