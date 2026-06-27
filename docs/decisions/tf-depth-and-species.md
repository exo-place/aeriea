# Research + Design: TF depth & species mapping

Status: **Design/research pass — no content built, no species designed. Not green.**
Awaits user direction. This doc inventories transformation (TF) *depth* across the
reference games and maps it onto aeriea's compositional body model
(`docs/decisions/transformation-system.md`) — the "flesh it out toward parity" step,
**before** any content rows or custom species are authored. Custom-species co-design is a
later, separate step the user wants to do *with* us; this doc only marks where it slots in.

Method note: CoC, TiTS, BDCC, and Lilith's Throne were surveyed **from local source**
(file paths cited). CoC2 had **no local source** and is surveyed from general knowledge —
**flagged unverified** wherever it appears. Created-species licensing was researched on the
web with sources cited; treat licensing as *best-effort as of 2026-06*, not legal advice.

Refs read: `docs/decisions/transformation-system.md` (the settled model),
`docs/artifacts/text-gen-design/ref-coc.md`, `ref-bdcc-game.md`.

---

## 1. TF depth across the reference games (the parity yardstick)

The point of this section is to size "parity": how many species, how many TF effects, and
how granular the body taxonomy is. Counts are from source where the source is local.

### 1.1 Corruption of Champions (CoC) — verified

Source: decompiled AS3→TS at `/home/me/reincarnate/flash/cc/out/frame1/`; original AS3 at
`~/git/coc`. Body model is a **flat field-bag on `Creature.ts`**: enum *type* + scalar
*magnitude* per part, plus sub-object arrays for compound parts.

| axis | scale (counted from `Creature.ts` / enums) |
|---|---|
| TAIL types | 18 (`TAIL_TYPE_*`) |
| FACE types | 19 (`FACE_*`) |
| EAR types | 14 (`EARS_*`) |
| LOWER_BODY types | 21 (`LOWER_BODY_*`) — incl. centaur, naga, hooved, etc. |
| COCK types | 14 (`CockTypesEnum`) |
| SKIN types | 5 base (plain/fur/scales/goo/undefined) + tone strings |
| BREAST cup enum | 100 values (`BREAST_CUP_FLAT`=0 … `ZZZ_LARGE`=99) — content bulk, not structure |
| compound parts | `cocks[]`, `vaginas[]`, `breastRows[]`, single `ass` — multiple of each |
| TF items (the Consumables dir) | ~13 in the decompile's Consumables folder; full game ~116 consumables incl. non-TF (`ConsumableLib`) |

"Species" in CoC is **emergent, not a field** — there is no species type. You become
"naga-ish" by accumulating naga parts (snake lower body + scales + …). Hybrids are the
**default state**: parts are independent, so any mix is reachable and most playthroughs are
chimeric. TF mechanic: an item reads state, rolls seeded RNG, mutates a field, narrates;
type-changers "spend a change-budget down a prioritized if-ladder" (BeeHoney pattern).

### 1.2 Trials in Tainted Space (TiTS) — verified, and the single most relevant ref

Source: full AS3 at `~/git/tits` (`classes/Creature.as`, `classes/GLOBAL.as`,
`classes/Items/Transformatives/`). TiTS is CoC's successor and **its body/species model is
the closest existing thing to ours** — worth studying in detail.

| axis | scale (counted from source) |
|---|---|
| TF/transformative items | **65** files in `classes/Items/Transformatives/` |
| part-type enum values (`TYPE_*` in GLOBAL) | **73** shared type tags (e.g. `TYPE_CANINE`, `TYPE_EQUINE`, `TYPE_DRAGON`…) |
| trait flags (`FLAG_*`) | **44**, incl. `FLAG_DIGITIGRADE`, `FLAG_PLANTIGRADE`, `FLAG_FURRED`, `FLAG_SCALED`, `FLAG_FEATHERED`, `FLAG_CHITINOUS`, `FLAG_GOOEY`, `FLAG_SMOOTH` |
| race-score functions | **~37** (`canineScore`, `avianScore`, `dragonScore`, `gooScore`, `nyreaScore`, …) |
| compound parts | `cocks[]`, `vaginas[]`, `breastRows[]` (same as CoC) |

**Two findings here directly validate our model and are worth lifting wholesale:**

1. **A shared `TYPE_*` family applied across many parts.** The same `TYPE_CANINE` tag is
   set on ears, tail, arms, legs, face, cock, etc. — exactly our idea that a part's
   "species flavour" is a *tag*, not a part-kind. We generalize this from a closed enum to
   open convention tags (§3.7 of the model doc).

2. **Species is a *score computed from parts*, not a stored field.** `canineScore()` literally
   counts how many parts read as canine and how many flags match (`hasTailFlag(FLAG_FURRED)`,
   `legType==TYPE_CANINE && hasLegFlag(FLAG_DIGITIGRADE)`); a hybrid is just two scores both
   high. This **is** "a species is a configuration over parts" — already shipping in a real
   corpus. Our model's only delta: we don't hardcode the score functions, we derive
   description/aliases structurally from the graph (model §3.6, §6).

The `FLAG_*` covering/material flags (digitigrade/plantigrade, furred/scaled/feathered/
chitinous/gooey/smooth) map almost one-to-one onto our MATERIAL + COVERING axes — **and they
expose a gap**: TiTS treats digitigrade-vs-plantigrade as a first-class flag and we currently
have no notion of leg posture (§4).

### 1.3 BDCC — verified

Source: `~/git/BDCC` (Godot 3.x). Covered fully in `ref-bdcc-game.md`. For depth: body is a
**slotted dict of polymorphic part-objects** (Head, Body, Arms, Legs, Ears, Hair, Horns,
Tail, Breasts, Penis, Vagina, Anus), each a registered class with **species variants**
(`{Canine,Equine,Feline,Dragon,Human}Penis.gd`). Species is **multi-valued** —
`getSpecies()` returns an *array* — with `getSpeciesScores()` / `getHybridPriority()` /
`getCrossSpeciesCompatibility()` deciding what a hybrid's parts look like (again: species =
scored configuration, hybrids fall out). TF is a **first-class reversible staged holder**
(`TFHolder` + data-descriptor `TFEffect`s) — the pattern our model already adopts. TF
catalogue spans gender / species / granular-part edits (Feminization, Demonification, HuCow,
SpeciesTF, Skin/Breast/Penis/Vagina size & add/remove). Species classes: ~6
(Canine/Feline/Equine/Dragon/Demon/Human).

### 1.4 Lilith's Throne — verified

Source: `~/git/liliths-throne-public` (Java). The **most explicitly structured** body model
of the four, and a useful contrast because it hardcodes axes we keep open.

| axis | scale (counted from source) |
|---|---|
| Races | **21** (`Race.java`) |
| Subspecies | **57** (`Subspecies.java`) |
| Body-part *types* | ~30 type enums (`body/types/`: ArmType, LegType, TailType, HornType, WingType, AntennaType, TentacleType, …) |
| RaceStage | 6: `HUMAN → PARTIAL → PARTIAL_FULL → LESSER → GREATER → FERAL` |
| LegConfiguration | 8: `BIPEDAL, QUADRUPEDAL, TAIL_LONG, TAIL, ARACHNID, CEPHALOPOD, AVIAN, WINGED_BIPED` |

Two structural ideas to note:
- **`RaceStage`** is a "how far transformed toward this race" axis (human → partial → lesser
  → greater → feral). We don't model a discrete stage ladder; in our model "how far" is just
  *which segments have been converted*, read structurally — but the **feral** end (full
  quadruped, animal head) is a real configuration we must be able to express.
- **`LegConfiguration`** is literally our FORM-topology axis (biped / taur / naga / arachnid /
  cephalopod / avian) **as a closed enum**. This both validates the axis and shows the cost of
  hardcoding it: LT can only ever have these 8 lower-body shapes; our open graph can express
  any, but **owes the same set as shipped configurations** to reach parity.

### 1.5 CoC2 — **UNVERIFIED (no local source)**

No local source found (searched `~/git`, `~/reincarnate`). From general knowledge, flagged
unverified: CoC2 (a separate TEASE-developed title) uses a **TFCore / `_TFs/` data-driven
transformation system** — TF "rows" with a body-part target and effect, closer to data than
CoC1's per-item AS3. It ships on the order of dozens of races and 100+ TF items. **Do not
rely on these numbers**; if CoC2 becomes a load-bearing reference, obtain source and re-survey.

### 1.6 Parity summary — what "parity" numerically means

To match the *depth* of these games as **data on our compositional model**, the rough targets:

- **Part/segment vocabulary:** ~12–15 conventional region tags (head, torso, arm, hand, leg,
  foot, hip, spine, tail, ear, horn, wing, breast, genitals) — TiTS/LT/BDCC all sit here.
- **"Type" flavours (the cross-part tag family):** ~30–70 (TiTS 73 `TYPE_*`, LT 57 subspecies).
  These become **convention tags + per-segment covering/material**, not enums.
- **TF effect records:** ~60–115 to match TiTS (65) / CoC (~116) — but most are **rows over the
  same handful of ops** (graft/remove/set-material/set-covering/prop-delta/tag), not new code.
- **Compound/granular sexual parts:** multiple cocks/vaginas/breast-rows with per-part scalars
  — all four refs have this; it's a real gap in our model (§4).

The headline: **structural complexity is small; the depth is content volume** — exactly the
shape our model is built for ("more rows in the same tables"). The hard part stays the
deferred 3D embodiment, not the data.

---

## 2. Created / community species — openness & licensing verdict

This determines **what we can actually ship**. Created ("closed/open") species carry
creator-set terms that range from CC-licensed-open to strictly-closed-commercial. Researched
2026-06; **verify again before shipping any specific species** — terms change, and "open
species" in furry-community usage means *community-canon-governed*, which is **not** the same
as a copyright/IP license to use the design in a commercial game.

| Species | Creator | Verdict for shipping in aeriea | Terms (as found) | Source |
|---|---|---|---|---|
| **Avali** | RyuujinZERO | ✅ **Genuinely open & ship-safe** | Lore/concept under **CC BY-SA 4.0** — commercial OK, *must attribute*, **ShareAlike** (derivatives under same license — a real obligation to weigh) | [Avali Wiki Copyrights](https://avali.fandom.com/wiki/The_Official_Avali_Wiki:Copyrights), [WikiFur](https://en.wikifur.com/wiki/Avali) |
| **Synth** (Vader-San) | Vader-San | ✅ **Genuinely open & ship-safe** | Wiki content **CC BY 4.0** — "remix, transform, build upon for any purpose, even commercially," attribution required. (Per-file exceptions possible — check specific art.) | [Synth License](https://synthspecies.com/wiki/Synth:License) |
| **Protogen** | Malice-Risu / ZOR | ⚠️ **"Open species" but NOT a clean license** | Anyone may *make* Common/Uncommon protogens free (incl. commercial fursuits); Rare traits gated to paid MYO slots. BUT this is **community-canon governance, not a copyright grant** — there is **no CC/IP license** I could find permitting the *design* in a shipped game; off-rules designs are merely "non-canon," not legally cleared. **Treat as restricted for shipping** until explicit permission obtained. | [ZOR/Shapes guidelines](https://shapes.inc/fandom/protogens/legal-and-guidelines), [meowfursuits 2026](https://www.meowfursuits.com/blogs/news/what-is-a-protogen-fursuit-beginners-guide-2026) |
| **Sergal** | Mick Ono (mick39) / Kiki-UMA | ⛔ **Restricted** | Non-commercial use OK; **commercial use over ~$500/mo profit → partnership/permission required**. Part of the Vilous IP. Not ship-safe without a deal. | [Vilous ToU](https://www.vilous.net/tou.php), [WikiFur](https://en.wikifur.com/wiki/Sergal) |
| **Dutch Angel Dragon** | Ino (OfficialAngelDragons) | ⛔ **Open-but-regulated, not ship-safe as-is** | Personal/non-commercial fursuits free; **mass-produced/commercial use requires a license agreement + annual fee** with the creator; protected names/traits. A regulated IP, not open for a game. | [DAD guidelines](https://www.dutchangeldragons.com/guidelines), [design guidelines](https://www.dutchangeldragons.com/design-guidelines) |

**Verdict, plainly:**
- **Ship-safe today: Avali (CC BY-SA 4.0) and Synth (CC BY 4.0)** — with attribution, and for
  Avali the ShareAlike obligation noted. These are the two "created species" we could include
  by name with confidence.
- **Protogen — the most-requested — is NOT cleanly licensed.** Its "open species" status is
  community-canon permission to *make* protogens, not a copyright license to ship the design
  commercially. Default to **not shipping it by name**; if wanted, get explicit written
  permission from ZOR/the creator first.
- **Sergal, Dutch Angel Dragon — restricted/commercially-licensed.** Do not ship without a deal.
- **General principle for aeriea:** because our model is **compositional from generic
  segments**, we never *need* to ship anyone's named design. We can offer the *building blocks*
  (digitigrade legs, a feathered crest, a visor-face segment) and let players assemble their own.
  Shipping a named, creator-owned silhouette is the only thing that triggers licensing — and we
  can simply not do that, or do it only for the CC-licensed ones with attribution.

(Not separately verified here but commonly cited as open: **CABIT**, **Dutch**-adjacent
open derivatives, **Primagen** = strictly closed. Verify any before use.)

---

## 3. Species-as-configuration — worked mappings (the design)

Each species below is expressed in **our** model: a configuration = a subtree shape (FORM) +
per-segment MATERIAL + per-segment COVERING + an optional alias + convention tags. No
`kind`, no species enum. (Schemas abbreviated — full segment shape in model §3.1.) The
claim to demonstrate: **every one is just data on the three axes, and hybrids fall out of
mixing them with no special case.**

Legend: `M`=material, `C`=covering, tags in `[]`.

### (a) Wolf-anthro (biped)
- FORM: standard biped (torso + head + 2 arms + 2 legs + tail).
- per-segment: all `M:flesh`; `C:fur` on every segment; legs tagged `[leg, digitigrade]`
  (posture as a tag — see §4 gap); head tagged `[head, muzzle]`; tail `[tail]`.
- alias: `wolf-anthro`. Tags: each part also carries convention flavour tag `canine`
  (the TiTS `TYPE_CANINE` idea, generalized to an open tag).

### (b) Naga (serpentine lower)
- FORM: humanoid upper (torso/head/arms) grafted onto **one long tapering tail-segment** in
  place of legs (no leg subtree). Lower segment tagged `[lower_body, serpent_tail]`.
- per-segment: upper `M:flesh, C:skin`; lower `M:flesh, C:scales`.
- alias: `naga`. (This is LT's `LegConfiguration.TAIL_LONG` as graph data.)

### (c) Taur (quadruped lower)
- The canonical example already in model §3.5: humanoid upper + grafted quadruped-lower
  subtree (second spine + 4 legs) at the hip, tagged `[lower_body]`. Upper `C:skin`, lower
  `C:fur`. alias: `taur`. (LT `QUADRUPEDAL`.)

### (d) Slime person
- FORM: a normal biped graph — *shape* is unchanged.
- per-segment: **every** segment `M:slime, C:null`. Slime is just a material (model §3.2);
  the graph is its held shape; always-mutable form (§3.0) gives the flow.
- alias: `slime`. No special "unstable" machinery.

### (e) Bird-harpy
- FORM: biped torso/head/legs, but **arms replaced by wing subtrees** (graft wing where arm
  docked), legs tagged `[leg, digitigrade, talon]`.
- per-segment: `M:flesh`; `C:feathers` on torso/wings/head-crest; legs `C:scales` (scaled
  bird legs). Head tagged `[head, beak]`.
- alias: `harpy`. (LT `AVIAN`; combines wing-graft + per-segment covering split.)

### (f) Drider (arachnid lower)
- FORM: humanoid upper grafted onto an **arachnid abdomen + 8-leg subtree** at the hip,
  tagged `[lower_body, arachnid]`.
- per-segment: upper `M:flesh, C:skin`; lower abdomen + legs `M:chitin, C:null` (exoskeleton;
  chitin nulls covering, model §3.2).
- alias: `drider`. (LT `ARACHNID`; demonstrates a chitin lower on a flesh upper.)

### (g) Synth (CC-open, ship-safe) — a "tech-covering" demo
- FORM: biped; optional visor-face segment, optional back-mounted accessory subtrees.
- per-segment: `M:flesh` core with `C:fur` OR `M:synthetic` segments for plating; a
  **visor/screen** is a head-child segment `[head, visor]` with `M:synthetic, C:null`.
- alias: `synth`. **Needs a new material value `synthetic`** (an open add — model §3.2 says
  materials are open; we just haven't shipped this value). Attribution: CC BY 4.0, Vader-San.

### (h) Avali (CC-open, ship-safe) — feathered, digitigrade, four-eared
- FORM: small biped; digitigrade legs `[leg, digitigrade]`; head with **two ear-pairs**
  (graft 4 ear segments) `[ear]`; small wing/arm.
- per-segment: `M:flesh, C:feathers` throughout; tail `[tail]` feathered.
- alias: `avali`. Attribution: CC BY-SA 4.0, RyuujinZERO (ShareAlike obligation noted).

### Hybrids fall out — no special case

Mixing the axes already used above yields hybrids with **zero new machinery** — each is just
"take config X's subtree shape, swap one axis":

- **wolf-taur** = taur FORM (c) + wolf's `C:fur` everywhere + `canine` flavour tags. (Already
  the §3.5 example.)
- **chitin-naga** = naga FORM (b) with the lower tail segment's `M` set to `chitin, C:null`
  instead of `flesh/scales`. One `set_material` op.
- **slime-drider** = drider FORM (f) with every segment `M:slime`. One subtree `set_material`.
- **feathered-taur (avali-taur)** = taur FORM + `C:feathers` everywhere + digitigrade leg tags.
- **synth-naga** = naga FORM with plating segments `M:synthetic`.

Each hybrid is reachable by the **same** op vocabulary (graft / set_material / set_covering /
tag) that builds the base configs — confirming the model's central claim: **species and
hybrids are points in the same configuration space, addressed by the same ops.** The TiTS
race-score corpus (§1.2) is live proof this works: a hybrid there is just two part-derived
scores both high.

---

## 4. Gap analysis — what the model lacks for parity

Honest list of what parity needs that the model (`transformation-system.md`) does **not** yet
provide. Most are **content/vocabulary** gaps (open values we haven't shipped), a few are
**genuine model extensions**.

**A. Vocabulary not yet shipped (open-value gaps — easy, just data):**
1. **Materials beyond flesh/chitin/slime** — need at least `scale-hide`, `synthetic/metal`,
   `stone`, `energy`, `plant/wood`. The model says materials are open (§3.2); we just owe the
   values + their describe/behave rules.
2. **Coverings beyond skin/fur/scales** — need `feathers`, `chitin-as-surface`,
   `slime-as-surface`, `bare/synthetic`, `bark`. (All four refs have feathers; we don't.)
3. **Region tags** — need the full ~12–15 convention set (foot, horn, wing, ear, beak, muzzle,
   crest, breast, genitals) shipped as the lingua franca (§3.7).

**B. Genuine model extensions (need a design decision, not just rows):**
4. **Leg posture (digitigrade / plantigrade / unguligrade / taur / serpentine).** TiTS makes
   this a first-class `FLAG_DIGITIGRADE`/`FLAG_PLANTIGRADE`; LT has `LegConfiguration` (8). We
   currently have *no* posture concept. **Decision:** posture is most likely a **leg-segment
   tag/prop** (`[leg, digitigrade]`) read by describe + the deferred rig — it does *not* need a
   new axis. Record this as a convention.
5. **Genitalia & compound parts.** All four refs have **multiple** cocks/vaginas/breast-rows
   with per-part scalars (length, girth, type, knot, cup, fluid, sensitivity). Our model's
   genitals are "just more segments" in principle, but we have **not** worked the example, and
   "multiple breast-rows / multiple cocks" + per-part fluid/orifice sim is a real authoring
   surface that needs a deliberate sub-design. **This is the single biggest gap vs. the genre.**
   (NSFW-first is a project commitment — DESIGN.md — so this is core, not optional.)
6. **Sexual-dimorphism / gender as configuration.** CoC/TiTS/BDCC all have feminization/
   masculinization TFs and a sex/gender notion. In our model gender is *emergent* from which
   genital/breast segments + scalars exist — but we owe a worked mapping (what "feminization"
   targets) and an alias convention (`female`/`male`/`herm`/`null` as derived, not stored).
7. **Size / proportion system.** Refs have height, hip/butt rating, cup, ball-size, breast/
   muscle scalars. We have per-segment `props` (length_cm) and body `scalars` (height_cm) —
   the mechanism exists, but the **shipped prop vocabulary + banding for description** ("petite,"
   "towering," cup bands) is unbuilt.
8. **Fluids / wetness / lactation / pregnancy** as part-attached sub-sim. BDCC hangs
   `FluidProduction`/`Orifice`/`SensitiveZone` off each part; TiTS/CoC have cum/milk/fertility
   scalars. Our model has **no** fluid/orifice notion. **Decision needed:** are these
   per-segment props, attached sub-objects, or out of scope for the pure TF system (a sim
   layer on top)? Likely the latter — note it as a fenced adjacent layer.
9. **"Feral / how-far-transformed" expression.** LT's `RaceStage` (human→feral) — our model
   expresses "how far" structurally (which segments converted), which is *more* expressive, but
   we owe the **feral end** as an authored configuration (animal head + full quadruped) to prove
   the range.

**C. Non-gaps (the model already handles, worth stating):**
- Hybrids — fall out (§3, demonstrated).
- Per-region material/covering split — native (the whole point of the rewrite).
- Reversible staged TF, determinism, save/load — already designed (model §4–5).
- Novel/unnamed configs — describable structurally (§3.6, §6).

---

## 5. Path to parity — staged plan (all as data on the model)

Ordered so each stage is independently playtestable and nothing is built before its design
exists (feature-gating). **No content is authored by this doc; this is the route.**

**Stage 0 — finish the design gaps in §4.B first (design passes, no code).**
Decide: leg-posture-as-tag (gap 4); the **genitalia/compound-part sub-design** (gap 5 — the
big one); gender-as-derived-configuration (gap 6); fluids in-or-out (gap 8). Each gets a
`docs/decisions/` section before any rows. *This is the immediate next step.*

**Stage 1 — ship the open vocabulary (gaps A1–A3) as the MVP value set.**
~6 materials, ~7 coverings, ~15 region tags, plus a small **prop + banding** vocabulary
(gap 7). This is "few values, open property" (model §7) — the same applier, more rows.
Playtest: describe a body using each value; confirm transition zones read.

**Stage 2 — author the ~8 base configurations from §3 as data templates.**
wolf-anthro, naga, taur, slime, harpy, drider, + the two CC-open ones (synth, avali, with
attribution). Each is a stored configuration (subtree + per-segment axes + alias + tags).
Playtest: instantiate each, describe it, confirm the alias surfaces and structure is right.

**Stage 3 — author TF records toward TiTS-scale (~60 effects), all rows over the §4.2 ops.**
Grafts (gain tail/wings/quadruped-lower), material conversions (→chitin/slime/scale/synthetic),
covering creeps (→fur/feathers/scales), prop growers (height/length/size), feminize/masculinize
as genital-segment graft+remove. Each is data; the applier is unchanged. Playtest staged
unfolding + undo.

**Stage 4 — the genitalia/compound-part content** (depends on Stage 0's sub-design):
multiple-part support, per-part scalars, the feminize/masculinize and HuCow-style TFs. This is
where NSFW depth reaches genre parity. Playtest against transcript.

**Stage 5 — hybrid & novel-config validation pass.** Author the §3 hybrids (wolf-taur,
chitin-naga, slime-drider, …) and a couple of *unnamed* configs; confirm they need no new code
and describe cleanly. This is the proof-of-parity gate.

**Where custom-species co-design slots in:** *after* Stages 1–2 (the vocabulary + base configs
exist as the shared palette), as a **separate collaborative step with the user** — picking/
designing aeriea's own signature species as configurations over the shipped axes, and deciding
which (if any) CC-open external species to include with attribution. It is explicitly **not**
part of this doc and **not** started until the user directs it.

**Deferred throughout (unchanged from model §2):** the 3D rig/mesh/animation for arbitrary
topology (the genuinely hard part), the deep prose realizer, and live world/combat triggers.

---

## 6. Bottom line

- **Parity is content volume, not structural complexity.** TiTS (65 TF items, 73 type-tags,
  ~37 race scores), CoC (18 tails / 19 faces / 100-cup enum), LT (21 races / 57 subspecies),
  BDCC (slotted species-variant parts) all reduce to **rows over a small op set on a part graph**
  — which is exactly our model. The depth target is ~60–115 TF records and ~30–70 flavour tags,
  all data.
- **Our model is *already validated* by the refs:** TiTS's "species = score over part-tags +
  flags" and BDCC's multi-valued scored species are the same "species is a configuration,
  hybrids fall out" claim, shipping in real corpora. LT's `LegConfiguration` and TiTS's
  digitigrade/material `FLAG_*`s are our FORM/MATERIAL/COVERING axes hardcoded — we keep them open.
- **The real gaps** are: leg posture (→ tag), the **genitalia/compound-part sub-design** (the
  big one, NSFW-core), gender-as-derived, fluids in-or-out, and shipping the open vocabulary.
- **Licensing: only Avali (CC BY-SA 4.0) and Synth (CC BY 4.0) are clean to ship by name**
  (with attribution); **protogen's "open species" is community-canon, not a usable copyright
  license** — don't ship it by name without explicit permission; sergal and DAD are restricted.
  And because we build from generic segments, we never *need* a named design — we ship blocks.

**Unverified flags:** CoC2 (no local source — all CoC2 figures are from general knowledge).
Licensing is best-effort as of 2026-06 and must be re-verified before shipping any specific
species; "open species" in furry usage ≠ a copyright license.

---

*Design/research pass. No content built, no species designed. Not green. Awaits user direction.*
