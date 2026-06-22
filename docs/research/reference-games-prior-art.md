# Reference games — prior-art synthesis

Status: **PRIOR-ART SYNTHESIS — read-only study of five cloned reference
codebases + folded-in prior aeriea research (2026-06-22)**

Scope: one comparative read across the reference-game lineage aeriea draws
on for **deep body/transformation, NSFW-first content, and procedural prose**.
It synthesizes five per-repo studies (each cloned and read firsthand) and folds
in what aeriea already learned about the embodiment lineage (BDCC2) and the
simulation-underneath lineage (`existence`). It is organized **by system, not by
game**, so the comparison is the point.

This doc **extends, does not replace**, `../decisions/reference-analysis.md` —
that doc evaluates three reference games (TiTS, Lilith's Throne, Flexible
Survival) through the *interaction-graph / affordance* rubric ("keep their content
graph, replace their world graph"). This doc is the **implementation-level**
companion: how the bodies, prose, content, and saves are actually built, and what
the concrete patterns are worth to aeriea. Read that doc for *why the world graph
is the thing to reject*; read this one for *what to take from the content graph*.

Honesty note up front: **nothing here is a commitment to execute.** Everything in
the takeaways section is framed as STUDY — a pattern observed in working code,
weighed for aeriea, with the anti-patterns called out. The aeriea design pillars
(`../decisions/`) remain the authority on what gets built.

The five firsthand studies (cross-linked throughout):

- `prior-art/coc.md` — Corruption of Champions (Fenoxo/Source) — the OG.
- `prior-art/tits.md` — Trials in Tainted Space — the CoC successor.
- `prior-art/nimin.md` — Nimin / Fetish Master — a CoC-lineage hobbyist game.
- `prior-art/liliths-throne.md` — Lilith's Throne — the composable sex engine.
- `prior-art/character-viewer.md` — Fenoxo CharacterViewer ("DIC") — the
  paperdoll *renderer* (the visual half of the parametric-body problem).

Folded-in prior research:

- `bdcc2-evaluation.md`, `../decisions/bdcc2-integration-plan.md`,
  `../decisions/bdcc2-mining-backlog.md` — the BDCC2 embodiment/NPC lineage.
- `existence-prior-art.md` — the deterministic simulation-underneath lineage.
- `../decisions/reference-analysis.md` — the interaction-graph framing this extends.

---

## Summary table

| Game | Engine / lang | Standout contribution | Biggest aeriea takeaway |
|---|---|---|---|
| **Corruption of Champions** | ActionScript 3 / Flash | Two-layer prose engine: a templating parser (`parseText`) over a library of state→fragment descriptors with per-type **synonym pools** | Adopt the two-layer prose pattern — AST templating over state→fragment descriptors with synonym pools — **but draw variants from the seeded timeline** so prose replays |
| **Trials in Tainted Space** | ActionScript 3 / Flash | `race()` — species/identity **derived** from body-part scores every call, never stored | Compute identity (race, build, presentation) as a **classification over current parts+tags**, so transformation updates it for free |
| **Nimin (Fetish Master)** | ActionScript 3 / Flash | Affinity/"blood" TF model: continuous 0–100 race scores → thresholded morphology, with **gain/lose symmetry** + a susceptibility stat | Keep affinity→threshold→morphology, but make it **data** (per-species config) on a structured part/tag system — new species = content, not code |
| **Lilith's Throne** | Java / JavaFX WebView | Composable sex engine: act = typed tuple `(participant, performingArea, targetedArea)` × position × pace; **orifice deformation as Capacity/Elasticity/Plasticity** | Model the act space as a **typed tuple over a part-area interface**, as serializable data; adopt the 3-axis (current/resistance/permanence) deformation model |
| **CharacterViewer (DIC)** | ActionScript 3 / Flash | **Quantize-at-the-seam** (continuous body → finite art index, map as data) + **graceful-degradation defaulter** for sparse combinatorial art | Quantize continuous body → finite art index at the render seam (map as data); steal the per-type defaulter so a sparse art set never hard-fails |
| **BDCC2** *(folded in)* | Godot 4.x / GDScript | Clean continuous-channel **facial expression rig** (`FaceAnimator`) + memory/relationship/mood NPC slice | Mine the expression rig + memory→relationship→mood slice **behind aeriea's own seams** (Path A), never as the architectural base |
| **existence** *(folded in)* | ES-module JS | Working **deterministic realizer** (`realize(observations, hint, ntCtx, random)`) + seeded multi-stream PRNG + fixed-draw-count discipline | The realizer and determinism kit transfer wholesale; the realizer-side contract is identical whether state is a snapshot or aeriea's `G` |

The Fenoxo lineage (CoC → TiTS → Nimin → CharacterViewer) and Lilith's Throne are
the **content-and-body** half; BDCC2 is the **embodiment/visual** half; `existence`
is the **determinism/realizer** half. aeriea wants the union of the three halves
under one invariant the references mostly lack: **seeded determinism + data over
code at the seams.**

---

## By system

### 1. Character creation / customization

The lineage agrees on one structural choice and one philosophy:

- **Creation is a guided interview, not a stat-allocation panel.** CoC's
  `charCreation.as` is a linear vignette flow (name → gender → history-perk →
  stats); TiTS's `creation.as` is a wizard of `addButton(...)` steps with long
  in-character race descriptions; CharacterViewer's creator cycles each part via a
  tiny data file (`DIC_Cycler.json` says *which index a button bumps* — no
  per-part button code).
- **Depth comes from play, not from chargen.** In every Fenoxo-lineage game the
  *real* customization happens post-creation via transformation items; chargen
  just seeds a personality + perk + body defaults. Lilith's Throne is the outlier
  — its `CharacterModificationUtils.java` is **6935 lines** of editable axes (hair,
  eyes, horns-with-row-counts, every genital dimension, 76 fetishes), so it front-
  loads more depth, but still treats it as a body-editor over the same part model.

**A clean idea worth keeping (CoC):** *history-as-authored-vignette granting a
mechanical perk* — "History: Whore → +15% tease damage." It fuses narrative
identity with a gameplay modifier at near-zero friction.

**A clean idea worth keeping (CharacterViewer):** *data-driven part cycling* — one
small JSON describes which index each UI control bumps, so the creator UI is
generated from data, not hand-wired per part. This is aeriea's library-first /
projection-from-data ethos applied to a character editor.

**What to avoid:** CoC's creator is event-number dispatch (`doCreation(eventNo)`),
i.e. unreusable control flow, not a data model. aeriea wants a structured,
serializable creation-space (it already has its own character creator scene per
`bdcc2-mining-backlog.md` #16), so chargen is a *projection* of the body schema,
not a bespoke flow.

### 2. Body / transformation / tag system — the core relevance

This is where the lineage is most instructive and most varied. Four distinct
encodings of "a deep, mutable, taggable body":

| | Body model | "Type" encoding | Tags | Identity (race) |
|---|---|---|---|---|
| **CoC** | one fat `creature` class; parts-as-arrays (`cocks[]`, `breastRows[]`) | bare ints w/ comment legend (0=human, 1=horse…) | perk/statusAffect = `{name, value1..4}` + magic-index `flags[]` | mostly stored / ad hoc |
| **TiTS** | parts-as-arrays of tagged part-objects | `cType:Number` + per-part `cockFlags:Array` of ints + parallel `FLAG_NAMES` | flat serializable int tag system | **derived** via `race()` over ~40 `*Score()` fns |
| **Nimin** | one ~330-field god-object (no nesting) | per-part counts (`humanCocks`, `horseCocks`…) | per-race 0–100 affinity scores | `dominant` = argmax of affinity scores |
| **Lilith's Throne** | flat `Body` of typed part objects; rich quantitative state per part | `AbstractType` (data-driven, mod-loadable) | `BodyPartTag` + abstract types loadable from XML | derived from part mix (subspecies, raceStage) |

Three patterns recur and are worth taking; one is the warning the whole lineage
teaches:

1. **Parts-as-arrays with first-class plurality** (CoC, TiTS, LT). N cocks, N
   breast-rows each with its own count/nipples/cup, N vaginas — the prose layer
   renders count off `array.length` ("two rows of…", "quad"). This is the right
   shape for a deep customizable body. `prior-art/tits.md`, `prior-art/coc.md`.

2. **The (scalars, tags) → geometry/prose separation** (TiTS, LT). TiTS's
   `CockClass.volume()` computes a real cylinder+hemisphere volume then reshapes
   the tip by `FLAG_FLARED`/`FLAG_TAPERED`/`FLAG_DOUBLE_HEADED`. Body math is a
   pure function of (scalars, tags) — cleanly separable. `prior-art/tits.md`.

3. **Identity-as-projection-of-body-state** (TiTS's `race()`, Nimin's
   `dominant`, LT's subspecies). The single most aeriea-relevant idea in the whole
   lineage: don't *store* "race"/"species"/"build" — *compute* it as a
   classification over current parts+tags so transformation re-derives it for
   free. TiTS even has a commented-out design note proposing a softmax refinement.
   This is a direct fit for aeriea's "simulation underneath, rendering on top"
   (identity is a render-time projection of the simulated body).
   `prior-art/tits.md`.

**Lilith's Throne's standout gem — persistent deformation on three orthogonal
axes.** `Capacity` (current cm diameter) vs `OrificeElasticity` (resists
stretching) vs `OrificePlasticity` (how permanently a stretch persists vs snaps
back). Capacity changes during use; elasticity/plasticity govern whether the
change is temporary or lasting. **The body accumulates real systemic history** —
and the pattern (current value / resistance / permanence) generalizes far beyond
NSFW to any wear/deformation system. `prior-art/liliths-throne.md`.

**Nimin's standout — the affinity/"blood" TF mechanic.** Each race has a 0–100
affinity; the highest is `dominant`; crossing per-tier thresholds drives
morphology. Two refinements worth carrying: **gain/lose symmetry** (de-
transformation is authored as well as transformation) and **susceptibility as a
second-order stat** (`changeMod` scales all change — humans are "more adaptive").
Threshold crossings use hysteresis-aware paired conditions —
`(aff+Δ)>=T && aff<T` fires exactly on the crossing, avoiding re-fire.
`prior-art/nimin.md`.

**The warning the whole lineage teaches:** every Fenoxo-lineage game encodes the
tag/type vocabulary as **bare integers** — CoC's comment-legend ints (meaning
lives in a comment, so a miswrite is silent), CoC/CharacterViewer's 4-untyped-slot
perk bags, and CoC's magic-index `flags[]` grab-bag. TiTS is the best of them (a
flat, serializable, append-only int enum with a `FLAG_NAMES` map) but it is still
*stringly/int-typed*, and its prose parser resolves tags by **runtime reflection
over a member path** (`"pc.cockBiggest"`), self-described in-source as tech debt.
The aeriea correction is the same everywhere: **lift the tag vocabulary to a
typed, validated, serializable schema** (cf. playmate's `frond`), and resolve
prose tags through a *typed binding*, not reflection or magic ints.

### 3. NSFW content engine — authored vs procedural/combinatorial

This is the sharpest split in the lineage, and it is the load-bearing distinction
for aeriea's systemic-intimacy ambition.

**Authored-scene games (CoC, TiTS, Nimin).** A scene is a hand-written function
(or event-code) that emits prose and offers next-buttons; *body state drives
branching inside the scene, but the scene itself is bespoke*. The recurring
pattern is good and worth keeping: **gate the menu by body predicates**
(`player.hasCock()`, `player.canOvipositBee() && lust>=33 && biggestCockArea()>100`
in CoC; `pc.isAss()`, cum-volume tiers in TiTS; organ-presence dispatch in Nimin)
so options respond to an arbitrary body without authoring every combination. The
*menu* is procedural over body state; the *scene bodies* are authored prose.

The cost is the explicit thing aeriea designs against: **combinatorial reach is
~zero per author-hour.** A scene only ever depicts the acts its author wrote; you
cannot recombine an act onto an unanticipated partner. Content scales linearly
with writing and never composes (TiTS's content layer is ~2x its engine — 137
named NPC files, ~1400 story flags). `prior-art/coc.md`, `prior-art/tits.md`,
`prior-art/nimin.md`.

**The combinatorial game (Lilith's Throne) — the positive exemplar.** LT's sex
engine is genuinely compositional: an act is a typed tuple
`SexType = (participant, performingArea, targetedArea)`, where both penetrators
(`SexAreaPenetration`) and orifices (`SexAreaOrifice`) implement one
`SexAreaInterface`, so **the act space is the Cartesian product** of the interface,
crossed with **position** and **pace** (SUB_RESISTING → DOM_ROUGH). Availability is
gated declaratively (`REQUIRES_EXPOSED`, ongoing-lifecycle tags), and consent is
modeled *through* the dom/sub pace state machine rather than as a yes/no gate. This
is exactly the act×target×position×body-state structure
`../decisions/reference-analysis.md` names as aeriea's target.
`prior-art/liliths-throne.md`.

But LT pays for it in **code-as-content**: **1349** `public static final
SexAction` Java objects + an 11203-line parser file. The combinatorics multiply
authored fragments; they don't replace authoring. The aeriea correction:
**keep the typed-tuple act space, but make acts serializable DATA (AST), not 1349
static Java objects** — aligning with the data-over-code seam principle.

**Two gaps the whole lineage leaves for aeriea to fill deliberately:**

- **Consent/intensity model.** CoC/TiTS/Nimin have *none* (corruption/lust act as
  soft dials at most). LT's pace-state-machine consent is the best reference, and
  fits an immersion-first sandbox. aeriea (NSFW-first with SFW toggle) must design
  this in as a first-class systemic state.
- **Preference weighting that actually ships.** Nimin *designed* a per-fetish
  arousal-multiplier — and shipped it as **commented-out dead code** (`doLust()`
  in `StatChanges.as`). The lesson: player-preference content scaling must be a
  first-class live system or it dies as inert fields. `prior-art/nimin.md`.

Note BDCC2's `SexEngine` (`bdcc2-mining-backlog.md` #14) is the *embodiment*-side
analogue of this same split — a 1600-line turn-based scene-mode hub. The backlog's
verdict is consistent with this section: **mine the vocabulary (activity taxonomy,
arousal channels), do not port the engine** — its separate menu-driven scene mode
contradicts aeriea's 100%-immersion / "scenes-as-core-unit is too shallow" stance,
and its force/leash machinery is BDCC2-prison-specific.

### 4. Prose / text generation

This is the most directly transferable system in the entire study, and the
lineage converges on **one architecture** with implementation variants ranging
from clean to cautionary. The architecture, stated once:

> **A templating layer (authored fragments with inline tags) over a library of
> state→fragment descriptors, with per-type synonym pools selected at render
> time.** Author writes the spine; the engine substitutes/conjugates/selects
> descriptors from live body state.

How each game realizes it:

- **CoC** — the canonical two-layer form. `parseText()` (`engineCore.as`) is a
  real templating parser: `[cock]`, `[cockFit 8]`, `[if (a==b) "x" else "y"]`.
  Under it, `descriptors.as` (3555 lines) holds per-type **synonym pools** rand-
  selected per call (`cockNoun`: horse-cock → 8 variants, demon → 11), so one
  `[cock]` tag renders varied prose keyed on the body discriminant.
  `prior-art/coc.md`.
- **TiTS** — same shape, but tags resolve by **reflection over the object graph**
  (`getObjectFromString("pc.cockBiggest")` walks members, calls if it lands on a
  function). They migrated *from* a hand-maintained tag→fn table *to* dynamic
  introspection — and the source is littered with `// TODO: Get rid of this shit`.
  Powerful, fragile, runtime-only failure. `prior-art/tits.md`.
- **Lilith's Throne** — the highest-leverage prose pattern: the **descriptor-suffix
  parser** `[npc.cock]` vs `[npc.cock+]`, where `+` injects adjectives derived from
  that part's *current state* (size/girth/material). Plus **auto-conjugated verbs**
  (`[npc.verb(let)]` conjugates to person/number; player↔npc targets invert when
  the player speaks). One authored fragment renders correctly across all body-
  states. The cost: an 11203-line `UtilText.java` monolith with special-case hacks.
  `prior-art/liliths-throne.md`.
- **Nimin** — no parser DSL at all; prose is **imperative string concatenation**
  (`tempStr += "..." + helper() + "..."`) gated on state. Two ideas survive the
  mess: **`plural(topic)`** centralizes 16 grammatical-agreement cases (s/es,
  it/them, is/are, penises/pussies) keyed by organ counts — the seed of a real
  grammar layer; and quantities are **computed from stats** (`decGet` turns a size
  stat into believable inches inline). `prior-art/nimin.md`.
- **CharacterViewer** — the descriptor backend as a **threshold-ladder lexicon**:
  `breastCup()` is a ~700-line `if (rating < N) return "X-cup"` ladder. Right idea
  (state→word via thresholds), wrong encoding (should be a sorted data table).
  `prior-art/character-viewer.md`.
- **existence** — the *working, deterministic* realization of this whole
  architecture: `realize(observations, hint, ntCtx, random) → prose`
  (`realization.js:3960`), an affect-weighted set of sentence architectures and
  passage shapes over per-source lexical sets, with **seeded** selection among
  equivalent realizations. It proves the no-mad-libs / no-hot-loop-LLM realizer is
  buildable, and its realizer-side contract is identical whether state is a
  snapshot or aeriea's `G`. `existence-prior-art.md`.

**Synthesis for aeriea's prose thread:** the target is CoC's two-layer split +
LT's `[part+]` descriptor-suffix + Nimin's centralized grammar agreement +
existence's seeded-deterministic selection — with the corrections every reference
demands: **store templates/synonym pools as data/AST (not regex-over-source-text,
not 700-line if-ladders, not reflection), resolve tags through a typed binding,
and draw every variant from the seeded timeline** so the same state yields
deterministic prose. See `existence-prose-assessment.md` and
`../decisions/prose-generation.md` for aeriea's own design built on exactly this.

### 5. Animation / visual / paperdoll

Most of the lineage is **text-first with zero relevant rendering** (CoC, Nimin
pure text; TiTS and LT use static authored PNGs/SVGs selected by coarse body-state
bucket — `kiro_busty.png`, `kiro_nude_biggerest_busty.png`). The sharp lesson
there is a **negative** one that doubles as validation of aeriea's premise: TiTS/LT
prove a body model can *vastly exceed* what is drawn and still deliver the
customization fantasy **through prose** — the deep-sim-under-shallow-render bet,
shared with `existence`. aeriea inverts the bet (rich 3D render is the point) but
keeps the decoupling: body truth in the sim, multiple projections (prose, then 3D)
on top. `prior-art/tits.md`, `prior-art/liliths-throne.md`.

**The one game that actually solved parametric-body rendering — CharacterViewer
(DIC).** It is the visual half of the problem CoC/TiTS leave open, and it carries
several patterns directly applicable to aeriea's body-render seam:

- **Quantize-at-the-seam.** Continuous sim body values → a small discrete art
  index via a threshold table (`SaveTranslator`), with the index→symbol map held
  as **data** (`*_Dictionary.json`), not code. The sim stays continuous; the art
  stays a finite authored set. `prior-art/character-viewer.md`.
- **Graceful-degradation defaulter (the standout engineering idea).** If an
  `(type, j, k, l)` art-index combo has no symbol, a per-type priority order
  (`CoC_Defaulter.json`) collapses unsupported indices to the nearest authored
  asset until one resolves. A sparse combinatorial art set **never hard-fails** —
  the single best idea for any combinatorial-asset renderer.
- **Author one base color, derive the palette by color math** (`ColorDictionary`:
  shade ≈ RGB×0.7 cool-biased; genital tint via HSV; fur tinted from hair). One
  authored hex yields a coordinated palette — slashes color authoring.
- **Named recolor segments + flat-tint-on-neutral-art** (art drawn in a key color,
  tinted per segment at runtime via `ColorTransform`).

Its anti-patterns are equally instructive: **global `Math.random()` in the render
path** (cock-fan layout, prose synonyms, random eye color — same save renders
differently each load, the exact determinism violation aeriea forbids), and
**ad-hoc 2D self-shadowing via cloned "dark" parts + masks** which the author
documents in-source as buggy and fragile. aeriea uses the engine's real lighting,
not hand-rolled 2D shadow faking.

**BDCC2 is aeriea's actual visual channel** (`bdcc2-evaluation.md`,
`../decisions/bdcc2-integration-plan.md`). It is the only reference that is native
Godot 4 and 3D: a clean continuous-channel **facial expression rig**
(`FaceAnimator`: 13 typed blend params, gesture-stack compositing, look-at,
blink/talk), runtime body morphs via blendshapes, interchangeable heads. The plan
is **Path A** — mine the expression rig (the clean extraction) behind aeriea's own
`apply_expression(ExprState)` seam, with BDCC2 as the first impl, never as the
base (its `Doll` hub + `GlobalRegistry` are the locus architecture aeriea refuses).
This is the embodiment-side instance of the same data-at-the-seam discipline the
text lineage teaches.

### 6. Content / world structure & scale

Every reference is **content-dominated**, and every one encodes content as some
flavor of **code-as-content** dispatched by an opaque key:

- **CoC** — ActionScript functions dispatched by **integer event codes**
  (`eventParser` routes ranges: <1000 system, 2000–4999 events, …); buttons store
  an int. Scale is sheer authored volume (`items.as` = 738 KB).
- **Nimin** — **ID-keyed parallel switch ladders**: an item is smeared across
  `itemName(ID)` / `itemDescription(ID)` / effect / shop / crafting ladders that
  must stay in sync by hand. The textbook data-as-code anti-pattern.
- **TiTS** — global scene functions + ~1400 `flags["KEY"]` story-state keys.
- **Lilith's Throne** — Java `static final` objects for scenes/acts/items, with
  XML only for moddable *types* (races, clothing). 1349 acts, 15 races, 76 fetishes.
- **CharacterViewer** — content is the art symbol library + indexing JSONs; notably
  it is **game-agnostic and selects the game by swapping a data triple**
  (dictionary/defaulter/cycler JSON) — library-from-data, in spirit, and the one
  bright spot.

The shared lesson: **content scale in this lineage is bought with authored volume
and opaque dispatch keys** (magic event numbers, parallel ID ladders, story-flag
strings). aeriea's correction is its standing principle — a **typed, named,
serializable content registry** (library-first / projection-from-one-definition),
not numeric/string dispatch. CharacterViewer's game-by-data-triple is the spirit
to follow; the rest is the anti-pattern to avoid.

### 7. Determinism / save

This is the **cleanest contrast in the whole study**, and it is unanimous: *every
content/body reference is the inverse of aeriea's hard invariant.*

| | RNG | Save model |
|---|---|---|
| **CoC** | unseeded `Math.random()` everywhere (combat, TF, prose) | full mutable-state snapshot to Flash `SharedObject` |
| **TiTS** | unseeded `int(Math.random()*max)` inline in prose+combat | reflective full-state dump (`describeType`) + per-class version upgraders |
| **Nimin** | ungated `percent()` = `Math.random()` | hand-rolled positional-array snapshot to `SharedObject`, version-string migration |
| **Lilith's Throne** | `new Random()` unseeded + bare `Math.random()` (237 files) | full XML serialization of the live object graph + version-migration branches |
| **CharacterViewer** | *actively* non-deterministic render (`Math.random()` drives layout, prose, eye color) | input save is a host-coupled `.sol` (loader "not working") |

So the entire Fenoxo/LT lineage is: **no seed, no event log, no replay, snapshot
saves, nondeterministic RNG in the hot loop** — and it pays the documented cost
(brittle versioned save-migration, no reproducible bug repro, prose that can't be
regenerated). They are the named counter-example to aeriea's invariant
(seeded RNG + event-log replay; all state derivable from seed + action log).

**`existence` is the one reference that did it right, and it transfers wholesale**
(`existence-prior-art.md`): seeded multi-stream PRNG with fixed derivation order, a
**cosmetic/mechanical stream split** (prose-only variation on `cosmeticRng` never
perturbs the causal timeline), action-log replay, and — the single most reusable
discipline — **fixed-draw-count**: never let the number of PRNG draws depend on an
outcome, or replay desyncs (one draw per game-minute regardless of what happens;
the fire-roll always drawn even on the empty path). This is the determinism kit
aeriea's `G` will require.

A note on save *philosophy*: aeriea's persistence is **architecturally different,
not just better-implemented** — seed + action log, not an object-graph dump
(`bdcc2-mining-backlog.md` #10 correctly flags BDCC2's serializer as solving a
problem aeriea designed away). The references' save code is therefore not a
pattern to mine; it is the shape aeriea avoids by construction.

---

## Cross-cutting patterns (the lineage's shared DNA)

Three patterns recur across *every* content/body reference, regardless of engine,
era, or author. They are the load-bearing DNA of the genre — and aeriea's design
pillars are largely the *corrected* version of each.

### Pattern 1 — Authored fragments × state-selection × recombination

**The genre's core prose/content engine, present in all five.** A human authors
*fragments* (sentences, synonym pools, scene spines); the engine *selects and
recombines* them against live body/world state (a `[cock]` tag resolves through a
per-type pool; a scene menu filters by `hasCock()`; LT's `[part+]` pulls adjectives
from current capacity/material). This is `../decisions/reference-analysis.md`'s
named pattern and the genre's answer to "hundreds of hours of content without an
LLM in the loop." It is also the pattern `existence` proves can be made
**deterministic** (seeded selection among equivalent realizations).

The aeriea version: **keep the pattern; fix the encoding and the RNG.** Fragments
and selection rules as data/AST (not source text, not if-ladders, not reflection);
every selection drawn from the seeded timeline so the recombination replays.

### Pattern 2 — Identity and description are *projections* of body state, not stored fields

Across the lineage, the richest games **derive** what they can rather than storing
it: TiTS's `race()` (species = argmax over ~40 body-part scores), Nimin's
`dominant` (race = argmax over affinity scores), LT's subspecies (computed from the
part mix), and *all* of them generate the body's *description* fresh from current
state every render rather than caching a description string. This is the genre
independently rediscovering aeriea's **"simulation underneath, rendering on top"**:
the body is the truth; identity, prose, and (in CharacterViewer) the paperdoll are
all **render-time projections** of it, so transformation updates everything for
free. aeriea generalizes this to *every* descriptor (race, build, presentation,
prose, 3D morph) being a projection of the simulated body.

### Pattern 3 — Continuous body state, finite/discrete surfaces — quantize at the seam

The body underneath is **continuous** (CoC's `femininity:50`, LT's capacity in cm,
graded affinity scores), but every *surface* the player meets is **finite**: prose
picks from a discrete synonym pool, CharacterViewer quantizes a continuous value to
a small art index, LT's deformation maps capacity to named tiers. The genre keeps
the sim continuous and quantizes **at the seam** to whatever the surface needs
(words, art indices, named tiers) — and CharacterViewer makes the quantization map
*data* and adds graceful degradation so a sparse surface never fails. aeriea's
body-render seam, prose-realization seam, and (per `bdcc2-integration-plan.md`)
expression/locomotion seams are all instances of this same "continuous sim →
quantize at a data-driven seam → finite surface" shape.

---

## Prior-art → aeriea: takeaways

**Framed as STUDY, not commitments.** Each is a pattern observed in working code,
weighed for aeriea; the `../decisions/` pillars remain the authority.

### Worth studying (ideas to consider adopting)

1. **Parts-as-arrays of tagged part-objects, with (scalars, tags) → geometry/prose
   separation** (CoC/TiTS/LT). The right shape for a deep customizable body —
   first-class plurality, clean separation — *with the tag vocabulary lifted to a
   typed, validated, serializable schema* (cf. playmate `frond`), not bare ints.
2. **Identity-as-projection** (TiTS `race()`). Compute race/build/presentation as a
   classification over current parts+tags; never store it. The single most aeriea-
   relevant idea in the lineage.
3. **Three-axis persistent deformation — current / resistance / permanence** (LT's
   Capacity/Elasticity/Plasticity). Bodies that carry systemic history; generalizes
   to any wear/deformation system, far beyond NSFW.
4. **Affinity → threshold → morphology TF, with gain/lose symmetry + a
   susceptibility stat** (Nimin) — made **data** (per-species config), seeded, on
   the structured part/tag system, so new species are content, not code.
5. **Act space as a typed tuple over a part-area interface** —
   `(participant, performingArea, targetedArea) × position × pace` (LT) — made
   **serializable data (AST)**, not 1349 static objects.
6. **The two-layer prose engine + `[part+]` descriptor-suffix + centralized grammar
   agreement** (CoC + LT + Nimin), with templates/pools as data and selection
   drawn from the seeded timeline (existence). See `../decisions/prose-generation.md`.
7. **Gate activity/intimacy menus by body predicates** (`hasX`/capacity checks) so
   content responds to an arbitrary body without authoring every combination
   (CoC/TiTS/Nimin) — the *good* part of authored-scene design.
8. **Quantize continuous body → finite art index at the render seam, map as data**
   + **graceful-degradation defaulter** + **author-one-color-derive-the-palette**
   (CharacterViewer) — for aeriea's combinatorial body/cosmetic rendering.
9. **The determinism kit, wholesale** (existence): seeded multi-stream PRNG with
   fixed derivation order, cosmetic/mechanical stream split, action-log replay, and
   the fixed-draw-count discipline. This is what aeriea's `G` requires.
10. **Mine BDCC2 embodiment + NPC systems behind aeriea's own seams (Path A)** — the
    expression rig first, then the memory→relationship→mood NPC slice on a
    deterministic clock (`../decisions/bdcc2-mining-backlog.md`).
11. **History-as-vignette-granting-a-perk** (CoC) and **data-driven part cycling**
    (CharacterViewer) — two low-friction creator ideas.

### Anti-patterns to avoid (the lineage's recurring failures)

1. **Unseeded `Math.random()` in the sim/prose/render hot loop** (CoC, TiTS, Nimin,
   LT, CharacterViewer — *all five*). Directly violates aeriea's determinism
   invariant. Variety must come from seeded RNG threaded through the timeline.
2. **Bare-int / comment-legend type enums, 4-untyped-slot perk bags, magic-index
   `flags[]`** (CoC, CharacterViewer; TiTS's ints are the least-bad). Meaning lives
   in a comment or an index — silent miswrites. Use typed, named, serializable tags.
3. **Stringly-typed reflection prose parser** (TiTS) — runtime-only failure, no
   schema, self-described as tech debt. Resolve tags through a typed binding.
4. **Prose as monolithic string concatenation / 700-line if-ladder lexicons /
   regex-over-source-text** (Nimin, CharacterViewer, CoC). Right idea, wrong
   encoding — make ladders and pools data tables, parse to/store an AST.
5. **Authored-scene-per-encounter NSFW with ~zero combinatorial reach** (CoC, TiTS,
   Nimin). Scales linearly with writing, never composes. aeriea's systemic
   (act×target×position×body-state) approach is the deliberate counter.
6. **Code-as-content at scale** (LT's 1349 static acts + 11k-line parser; the whole
   lineage's per-NPC monoliths). Push to faithful serialized data.
7. **Magic-number / ID-keyed parallel-ladder content dispatch** (CoC event codes,
   Nimin's parallel item ladders). Use a typed, named content registry.
8. **No consent/intensity model; preference-weighting shipped as dead code** (CoC/
   TiTS/Nimin none; Nimin's fetish-weighting commented out). aeriea must build
   consent/intensity and preference-scaling as first-class live systems.
9. **Snapshot / live-object-graph saves with hand-coded version migration** (all
   five). aeriea's persistence is seed + action log by construction — a different
   architecture, not a better dump.
10. **Ad-hoc 2D self-shadowing / hardcoded paint-order + positions** (CharacterViewer,
    documented as buggy by its own author). Use the engine's real lighting/rig.
11. **A separate menu-driven turn-based intimacy scene-mode hub** (LT's engine
    shape; BDCC2's `SexEngine`). Contradicts 100%-immersion; mine the *vocabulary*,
    not the engine (`../decisions/bdcc2-mining-backlog.md` #14).

---

## Coverage note

**Studied firsthand (cloned + read):** Corruption of Champions, Trials in Tainted
Space, Nimin, Lilith's Throne, CharacterViewer — the five `prior-art/*.md` studies.
**Folded in from prior aeriea research:** BDCC2 and `existence`.

**Not studied as a per-repo codebase:** **Flexible Survival** is in the
reference set and is evaluated in `../decisions/reference-analysis.md` (through the
interaction-graph rubric — the strongest case of the "walking sim + wait-to-roll"
failure), but it was **not cloned or read at the implementation level** for this
synthesis. Its content/body/prose internals are therefore covered only at the
design-rubric level, not the code level. If an implementation-level FS study is
wanted, it is the one gap in this lineage sweep.

Other reference-set games named in `../../DESIGN.md` (Warframe, Mirror's Edge /
Ghostrunner / Dying Light, VRChat, etc.) are **out of scope** here — this doc is
specifically the body/transformation/NSFW/prose lineage; the movement, place, and
embodiment references are studied in their own docs.

---

## Cross-links

- `prior-art/coc.md`, `prior-art/tits.md`, `prior-art/nimin.md`,
  `prior-art/liliths-throne.md`, `prior-art/character-viewer.md` — the five
  firsthand studies this synthesizes.
- `../decisions/reference-analysis.md` — the interaction-graph / affordance framing
  this doc extends ("keep their content graph, replace their world graph").
- `bdcc2-evaluation.md`, `../decisions/bdcc2-integration-plan.md`,
  `../decisions/bdcc2-mining-backlog.md` — the embodiment/NPC lineage (Path A).
- `existence-prior-art.md`, `existence-prose-assessment.md` — the determinism +
  realizer lineage that the references lack and aeriea adopts.
- `../decisions/prose-generation.md` — aeriea's prose design built on the
  authored-fragments + recombination pattern, made deterministic.
- `../../DESIGN.md` — the reference set + the 100%-immersion north star.
