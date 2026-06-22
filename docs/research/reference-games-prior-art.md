# Reference games — prior-art synthesis

Status: **PRIOR-ART SYNTHESIS — read-only study of five cloned reference
codebases + folded-in prior aeriea research (2026-06-22); deepened with four
targeted code-depth dives (`prior-art/deep/*.md`, 2026-06-22)**

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
| **Corruption of Champions** | ActionScript 3 / Flash | Two-layer prose engine: a templating parser (`parseText`) over state→fragment descriptors with per-type **synonym pools**; the **`dogScore`/`foxScore` argmax discriminant** that derives identity from the trait bag (TiTS scaled it to ~40 scores) | Adopt the two-layer split with a **TYPED dispatch** seam; **draw variants from the seeded timeline** so prose replays; derive identity by **argmax over the trait bag**, same scores feeding prose AND the visual channel |
| **Trials in Tainted Space** | ActionScript 3 / Flash | `race()` — species/identity **derived** from ~40 body-part feature-scores every call, never stored (and the authors documented the correct normalized-argmax selector but shipped a fragile ordered-`if` waterfall) | Compute identity (race, build, presented-gender vs anatomical-sex) as a **classification over current parts+tags**, so transformation updates it for free — but build the *intended* argmax selector, not the shipped hack |
| **Nimin (Fetish Master)** | ActionScript 3 / Flash | Affinity/"blood" TF model: continuous 0–100 race scores → thresholded morphology, with **gain/lose symmetry** + a susceptibility stat | Keep affinity→threshold→morphology, but make it **data** (per-species config) on a structured part/tag system — new species = content, not code |
| **Lilith's Throne** | Java / JavaFX WebView | Composable sex engine: act = **value-typed tuple** `(participant, performingArea, targetedArea)` (equals/hashCode/reverse) × position × pace, validity from a **predicate cascade** not an allow-list; **deformation as Capacity/Elasticity/Plasticity** with a closed body-state→fit→arousal+prose+deformation loop | Adopt the value-typed act tuple as cache/replay/diff-able **data** over a thin part-area interface; make validity a **predicate** over presence/free/exposed/known so new parts compose; adopt the 3-axis (current/resistance/permanence) deformation model |
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
   free. This is a direct fit for aeriea's "simulation underneath, rendering on top"
   (identity is a render-time projection of the simulated body).
   `prior-art/tits.md`; **full mechanism in `prior-art/deep/tits-body-taxonomy.md`.**

   **The depth pass nails down exactly how, and exactly where TiTS got it wrong.**
   `race():String` (`Creature.as:9617-9701`) stores *nothing*; the only stored
   identity is `originalRace`, used solely to narrate drift. Classification is two
   stages: (1) per-race `*Score():int` functions (37 of them) tally signature
   features as **weighted feature-voting** — with *negative* votes (`humanScore`:
   `hasTail()` → `counter--`), *conditional gating* (`ausarScore`: a human face
   counts only once `counter>0`), *threshold cascades* (`kaithritScore`:
   `counter>1 / >2 / >3 / >5` stack), and *hard vetoes* (`leithan`: wrong eyes →
   `counter--`). (2) Selection is **NOT max-score** — `race()` is a ~60-line ordered
   `if (xScore()>=N) race="…"` waterfall where *the last assignment that fires wins*,
   priority encoded in source line order, thresholds hand-tuned magic ints. **The
   authors left a comment (`9624-9632`) describing the correct normalized-argmax-with-
   natural-max-tiebreak design and shipped the ordered-`if` hack anyway** — so aeriea
   should build the *commented* design, not the *shipped* one. Same projection
   pattern carries `bodyType()` (build = pure fn of `thickness×tone` grid) and gender:
   `mfn()` (weighted femininity → male/neuter/female, **presented gender**) cleanly
   separated from `rawmfn()` (hard `hasCock`/`hasVagina`, **anatomical sex**) — both
   projected, neither stored. The cautionary leak: `raceShort`/`stripRace` derives the
   *coarse* family key by **string-parsing the prose label** (drop `-morph`/`-taur`
   affixes, collapse synonyms), so renaming a label silently breaks classification —
   derive coarse keys from features, never from text.

**Lilith's Throne's standout gem — persistent deformation on three orthogonal
axes.** `Capacity` (current cm diameter) vs `OrificeElasticity` (resists
stretching) vs `OrificePlasticity` (how permanently a stretch persists vs snaps
back). Capacity changes during use; elasticity/plasticity govern whether the
change is temporary or lasting. **The body accumulates real systemic history** —
and the pattern (current value / resistance / permanence) generalizes far beyond
NSFW to any wear/deformation system. The exact bands, the fit-predicate formula,
and the full body-state→fit→arousal+prose+deformation→body-state loop are detailed
in §3 below and in `prior-art/deep/lt-sex-engine.md §2`. `prior-art/liliths-throne.md`.

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
perk bags, and CoC's magic-index `flags[]` grab-bag. TiTS is the best of them but
its schema, read in depth (`prior-art/deep/tits-body-taxonomy.md`), is a cautionary
tale: a creature is a **flat bag of bespoke slot fields on one 17.7k-line god-class**,
each major slot a `*Type:Number` enum-index + a `*Flags:Array` of small ints, with
`has/add/remove/clearXFlag` **hand-duplicated per slot** (4 verbatim methods × N
slots — slot identity lives in the *method name*, not data). The `TYPE_*` namespace
is **one flat shared int enum across every slot** (73 constants, alias collisions
like `TYPE_NAGA==TYPE_SNAKE`, a `TYPE_TANUKI` renumbered 18→24 with an apology
comment). Flags (43 ints) **cram multiple dimensions into one list** — texture
(`FLUFFY`/`SMOOTH`/`CHITINOUS`), shape (`TAPERED`/`FLARED`/`KNOTTED`), stance
(`PLANTIGRADE`/`DIGITIGRADE`), behaviour (`LUBRICATED`) — with no slot-scoping and no
mutual-exclusion, so invalid states (both/neither stance) are representable.
`VALID_SKIN_FLAGS` is the *vestigial good instinct* — a 7-flag allow-list for skin
that is never actually checked at the add site. The one clean corner is the
sub-object parts (`CockClass`): raw+mod dimension pairs, its own `cType`/`cockFlags`,
and **derived geometry** (`volume()` builds a cylinder+hemisphere and branches on
`FLAG_FLARED`/`FLAG_TAPERED`/`FLAG_DOUBLE_HEADED`) — clean precisely because the scope
is small and the dimensions are real numbers, not enum-soup. The aeriea correction:
**lift the tag vocabulary to a typed, *dimensioned, slot-scoped* schema** (cf.
playmate's `frond` — finish the `VALID_SKIN_FLAGS` idea TiTS abandoned) so "can this
slot carry this tag" and "are these mutually exclusive" are answerable *from data*;
give parts a uniform `has/add/remove tag` path (adding a slot = data, not 4
copy-pasted methods); and resolve prose tags through a *typed binding*, not the
runtime member-path reflection (`"pc.cockBiggest"`) TiTS self-describes as tech debt.

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
engine is genuinely compositional, and the depth pass
(`prior-art/deep/lt-sex-engine.md`) pins the exact mechanism. **The atom** is a
*value-typed* tuple `SexType = (SexParticipantType asParticipant,
SexAreaInterface performingArea, SexAreaInterface targetedArea)`, with
`equals`/`hashCode` defined over those three fields (`SexType.java:44-62`) — so an
act is a **cache/replay/diff-able value**, and `getReversedSexType()` gives the
other participant's POV for free (swap performing↔targeted). Pace is **not** in the
tuple; it's pulled from global state at render time (`getPerformanceDescription
:113`), so the real selection key is the 5-tuple `(participant, perfArea, targetArea,
performerPace, targetPace)` + position + body-state. **The entire part vocabulary is
two enums behind one 51-line `SexAreaInterface`:** `SexAreaOrifice` (~13 constants —
VAGINA/ANUS/MOUTH/NIPPLE/URETHRA_*/SPINNERET/…) and `SexAreaPenetration` (~7 —
PENIS/CLIT/TONGUE/FINGER/FOOT/TAIL/TENTACLE). That's **~13×7≈91 base interactions
before pace(6)×position×body-gating — the surface is the cross product, not an
enumerated allow-list.** A player-facing `SexAction` wraps a
`Map<SexAreaInterface,SexAreaInterface>` (perf-area→target-area), so one action is a
*set* of simultaneous pairings (double penetration = two map entries), and arousal
gains / corruption gate / the pairing map are all **plain data on the action, not
code**.

**Selection is two layers, both predicate-driven (no hand-authored valid-combo
table).** (A) *Gating* — `SexActionInterface.toResponse()` (`:776`) is a predicate
cascade: content prefs, `isFree`/`isOrificeTypeExposed` (part present + free +
exposed), a *knowledge* gate (`:816` — you can't target a partner's parts you don't
know about), action-type rules, and `position.isActionBlocked` (`:781`). **Validity
*emerges* from predicates over (tuple, body-state, prefs, position)** — so new parts
compose automatically. (B) *Prose* — each enum constant overrides `getSexDescription`
with a nested `switch(targetArea)→tense→inanimate→switch(performerPace)→switch
(targetPace)`, splicing part names via `UtilText` `[npc.pussy+]` tags. A parallel
*pure* selection `getRelatedFetishes` (`SexType:190-387`) maps tuple+body-state → a
typed fetish list **as data** — the right shape, kept off the prose path. And
penetrations are **stateful "ongoing" entries** in an event-sourced occupancy map
(`START_ONGOING`/`ONGOING`/`STOP_ONGOING`); `isFree(part)` == "not in any ongoing
entry", so double-penetration / "free a hand" / "switch orifice" all fall out of one
replayable map — exactly aeriea-shaped (deterministic, event-log-replay). This is the
act×target×position×body-state structure `../decisions/reference-analysis.md` names
as aeriea's target. `prior-art/liliths-throne.md`.

**LT's standout body mechanism — the 3-axis deformation model, now with the loop.**
Each orifice carries a mutable **Capacity** (current cm of comfortably-fitting
diameter, 8 banded levels `Capacity.java:21-80`) plus two constant-per-body axes:
**Elasticity** (resistance — `stretchModifier` = fraction of over-stretch applied per
turn, `sizeTolerancePercentage` = slack before "too big") and **Plasticity**
(permanence — `capacityIncreaseModifier` = fraction of stretch that sticks,
`recoveryModifier` = cm/sec recovery toward base). The feedback loop
(`GameCharacter.java:10040`): each turn, if inserted *diameter* exceeds
`capacity*(1.01 + elasticity.sizeTolerance + lube)` (`Capacity.isPenetrationDiameter
TooBig`), capacity is incremented by `max(5%·diameter, overstretch·elasticity)`,
clamped to the diameter; permanent retention + per-tick recovery apply Plasticity.
The same `tooBig`/`tooSmall` fit predicates feed **arousal deltas AND which prose
branch fires** — a single `f(diameter, capacity, elasticity, lube)` join between
body-state, what changed, and how it reads. Pure, seedable, replayable — directly
portable and generalizes far beyond NSFW to any wear/deformation system.
(Caveats from the read: `stretchCount=5` and friends are undocumented magic fudge
constants buried in logic — aeriea should hoist tuning to named data-side params.)

But LT pays for it in **code-as-content**: **1349** `public static final
SexAction` Java objects + an 11203-line parser, with the *prose itself hand-written
as ~330 KB of nested Java `switch` statements inside each enum constant* (each part
embeds the full pace×tense×reaction prose for every other part — adding a part is
O(parts) edits and it does not cache/diff/transport). And `SexType` is **not
self-describing**: realization reaches into `Main.sex`/`Main.game` singletons for
pace/occupancy/prefs, so you can't render an act without the live world. The aeriea
correction: **keep the value-typed act tuple and the predicate-driven gating, but
make acts + prose serializable DATA, and make realization a pure function of (tuple,
state, ctx)** — passing an explicit context object, not reaching into globals.

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

- **CoC** — the canonical two-layer form, mechanism pinned in
  `prior-art/deep/coc-tits-prose.md §1-2`. **Layer 1** (`parseText`,
  `engineCore.as:339-872`) is **iterated greedy-regex rewriting** — 5 regexes
  applied most-complex-first (`branchTagElse → branchTag → paramTag → basicTag`),
  each in a `while(exec)`/`String.replace` loop, dispatching through two hardcoded
  switches (~80 + smaller). Conditions are a **strict left-fold** (`checkCondition`
  `:97-336`): pull the first `(a op b)` triple, eval via a typed-variable whitelist
  that branches on RHS-literal *type* into player stats/predicates, then consume a
  leading `||`/`&&` with **no precedence/grouping** — and **ifs cannot nest** (greedy
  regex; comment at `:359`). A nice trick worth stealing: continuous stats are
  discretized into **named bands at the resolver** (`cumHigh`/`cumMedium`), so
  authors test semantic bands, not magic numbers. **Layer 2** (`descriptors.as`,
  3555 lines): `[cock]` → `cockDescript()` reads body state, dispatches on the part's
  type enum to a per-type descriptor, ~50% prepends an adjective, then pulls a noun
  from a **per-type synonym pool** (`cockNoun :2227` — string literals weighted by
  which `rand` bucket maps to them). `prior-art/coc.md`.
- **THE keystone discriminant — `dogScore` vs `foxScore` (argmax over the trait
  bag).** An ambiguous "canine" cock resolves via `if (dogScore() >= foxScore())`
  (`descriptors.as:2238`); both scores (`creature.as:2902,2943`) are **additive
  feature-counters over the whole body** (face/ear/tail/lowerBody/genitals/breastRows,
  with fur GATED behind `counter>0` so unrelated traits don't leak). **Identity is
  DERIVED by argmax-over-scores, never stored** — this is what survives piecemeal
  transformation, and the *same scores feed both prose word-choice and the
  visual/paperdoll channel* (shared infra, not two impls). TiTS scaled this to ~40
  `*Score()` counters — but regressed the *selector* into a fragile ordered-`if`
  waterfall (see §2 above; full analysis in `coc-tits-prose.md §4`).
- **TiTS — what the rewrite changed (the cheap lesson).** Layer 1 was rebuilt as
  `ParseEngine.recursiveParser`/`recParser` (`ParseEngine.as:415-540`): **manual
  bracket-DEPTH scanning instead of regex, so tags genuinely nest**, plus a `\[`
  escape CoC lacked. Dispatch evolved CoC's switch → name→closure data tables
  (`singleArgLookups`/`doubleArgLookups`) → those tables now **all commented out** →
  `getObjectFromString` dotted-path **introspection over the object graph** +
  per-object `getDescription(aspect,arg)`. Each step removes engine edits as the cost
  of adding a tag — but the endpoint is **runtime reflection** (`"pc.cockBiggest"`),
  self-described as tech debt, runtime-only failure. Also worth stealing: TiTS's
  output-polish pass (smart-quotes, `--`→em-dash, repeated-space collapse `/  +/g`)
  papers over the "optional clause didn't fire, leaving a gap" artifact any
  optional-fragment realizer produces. *Caution the depth pass surfaced:* this clone
  is mid-migration — the parser rewrite shipped **before** re-porting conditionals
  CoC already had, leaving the new engine briefly a regression (the exact "finish
  migrations before building on top" anti-pattern). `prior-art/tits.md`.
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
deterministic prose. Two sharper deltas the depth pass added: **make the Layer-1↔2
seam a TYPED dispatch** (tag enum → descriptor), not a stringly-typed switch or
runtime member-path reflection, eliminating the unknown-tag error class at compile
time; and **derive identity by argmax over the trait bag, with the same scores
feeding both the prose realizer AND the visual channel** (one discriminant, two
projections). See `existence-prose-assessment.md`,
`../decisions/prose-generation.md`, and the full mechanism in
`prior-art/deep/coc-tits-prose.md`.

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
(DIC).** It is the visual half of the problem CoC/TiTS leave open — the *same*
numeric `Creature` body state the prose game runs on, turned into a finite, sparse,
hand-authored vector-art set via **four clean seams** (full pipeline in
`prior-art/deep/charviewer-render.md`):

- **(1) QUANTIZE-at-the-seam.** Continuous body scalars → small int "viewer indexes"
  via hand-tuned **non-uniform threshold ladders**, one method per dimension
  (`SaveTranslator.getRealBoobIndex :20-32` is a 10-bucket ladder *widening* with
  size — fine gradation where it's perceptible, one mega-asset for the huge end).
  Crucial detail: it quantizes the **render-relative** size (`value*heightMod`,
  `heightMod=82/tallness`), *not* the raw stat, so proportions stay self-consistent
  on a short vs tall body. (DIC's one self-inflicted wound: the ladders are *code*,
  not data — aeriea should table them.)
- **(2) SELECT + graceful-DEGRADE (the standout engineering idea).** A ragged/sparse
  3-deep `type→i→j→k→ClassNameString` JSON dictionary; a reviver resolves leaf
  strings to compiled-in Classes — **a missing/not-yet-drawn asset silently becomes
  an `undefined` hole, so the table can reference art that doesn't exist yet (the
  hole IS the TODO)**. On a miss, `getDefaultIndexes` runs a **minimal-collapse
  search**: `TiTS_Defaulter.json` gives each type a digit-string priority order
  (`body:"132"` = which axes to zero first, least-important first), trying to collapse
  the *fewest, least-important* axes until a drawn cell hits, terminally falling to
  `(0,0,0)` which every type must guarantee. A sparse combinatorial art set **never
  hard-fails** — the single best artifact here, and acute for aeriea (NSFW-first deep
  customization = a cross product no art set can fully cover). Author a base per axis
  + a priority order; never enumerate the cross product. (Generalize the *arity*:
  DIC hard-wires exactly 3 axes; aeriea needs variable-length tuple + defaulter.) A
  reverse `Class→[type,i,j,k]` index gives O(1) round-tripping + dependent-part
  coupling (ears track hair length, clit tracks vagina presence).
- **(3) COMPOSE.** z-order **IS the `addChild` call sequence** in `drawLayer` (fine
  for one pose, but aeriea's parkour/VR/many-poses needs *explicit data-driven*
  z-order). The continuity bridge worth stealing directly: the **top bucket is a
  *scalable* asset** (a child `MC` clip the code transforms) — render the bulk in
  discrete buckets, reserve a scalable asset for the tail end to regain continuity
  without N more drawings.
- **(4) COLOR — author one base, derive the rest.** Art drawn in flat near-black;
  `PartPainter` tints **named child segments** (7 slots: skin/hair/bits fill+shade,
  eyes) via `ColorTransform` offset-as-color. Only *fill* colors are authored from a
  tiny named palette; **shades are computed** (RGB darken ~30% + cool bias), missing
  bits-colors derived from skin (HSV), goo-skin from hair, perceptual blends in
  CIELab. One authored hex → a coordinated palette; color is a **separable late
  stage** that re-runs without re-resolving geometry. `prior-art/character-viewer.md`.

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
2. **Identity-as-projection** (TiTS `race()`/`mfn()`/`rawmfn()`; CoC's
   `dogScore`/`foxScore`). Compute race/build/presented-gender/anatomical-sex by
   **argmax over the trait bag**, never store it — *and use the same scores for both
   prose word-choice and the visual channel* (one discriminant, two projections). The
   single most aeriea-relevant idea in the lineage. Build the **normalized-argmax-with-
   natural-max-tiebreak** selector TiTS *documented but never shipped* (`Creature.as:
   9624-9632`), not its fragile ordered-`if` waterfall. (deep: `tits-body-taxonomy.md`,
   `coc-tits-prose.md §2.3,§4`.)
3. **Three-axis persistent deformation — current / resistance / permanence** (LT's
   Capacity/Elasticity/Plasticity), with the closed loop `f(diameter, capacity,
   elasticity, lube)` → arousal + prose-branch + deformation, all pure/seedable; the
   same fit predicate is the single join between body-state, what changed, and how it
   reads. Bodies that carry systemic history; generalizes to any wear/deformation
   system far beyond NSFW. Hoist the magic fudge constants to named data params.
   (deep: `lt-sex-engine.md §2`.)
4. **Affinity → threshold → morphology TF, with gain/lose symmetry + a
   susceptibility stat** (Nimin) — made **data** (per-species config), seeded, on
   the structured part/tag system, so new species are content, not code.
5. **Act space as a *value-typed* tuple over a thin part-area interface** —
   `(participant, performingArea, targetedArea)` with equals/hashCode/reverse + ambient
   pace × position (LT) — made **serializable data**, not 1349 static objects, with
   realization a **pure fn of (tuple, state, ctx)** (no `Main.sex` globals). Keep the
   vocabulary tiny (~13 orifices × ~7 penetrations) and let the **surface be the cross
   product, gated by a predicate cascade** (presence/free/exposed/known/enabled), never
   an enumerated valid-combo table. Model concurrent engagements as an **event-sourced
   `(part→occupant)` occupancy map** (`isFree` and double-penetration fall out free).
   (deep: `lt-sex-engine.md §1,§3,§5`.)
6. **The two-layer prose engine** (CoC + LT + Nimin), coupled by a **TYPED dispatch**
   (tag enum → descriptor, not stringly-typed switch or runtime member-path
   reflection), + `[part+]` descriptor-suffix + centralized grammar agreement +
   **discretize-continuous-state-into-named-bands at the resolver** (CoC `cumHigh`) so
   authors test semantics not magic numbers, + a depth-counted bracket parser with a
   `\[` escape (TiTS) so tags nest, + TiTS's cheap output-polish pass (smart-quotes,
   em-dash, double-space collapse). Templates/pools as data; selection drawn from the
   seeded timeline (existence). (deep: `coc-tits-prose.md`.) See
   `../decisions/prose-generation.md`.
7. **Gate activity/intimacy menus by body predicates** (`hasX`/capacity checks) so
   content responds to an arbitrary body without authoring every combination
   (CoC/TiTS/Nimin) — the *good* part of authored-scene design.
8. **Quantize continuous body → finite art index at the render seam** (ladders as
   *data*, normalized to render-scale first) + **`(type, index-tuple)→asset`
   dictionary** (an `undefined` hole = the TODO) + **per-type priority-collapse
   defaulter** (the single most valuable artifact — sparse art never hard-fails;
   generalize the arity beyond DIC's fixed 3 axes) + **reverse index** for
   round-tripping/dependent parts + **top-bucket-is-a-scalable-asset** continuity trick
   + **named-segment flat-tint with derived shades** from a tiny palette
   (CharacterViewer). Add a **build-time validator** so the lenient hole behavior masks
   TODOs, not bugs. (deep: `charviewer-render.md`.)
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
- **Targeted depth dives** (the full internals folded into the by-system sections
  above): `prior-art/deep/lt-sex-engine.md` (LT's act-tuple + Capacity/Elasticity/
  Plasticity), `prior-art/deep/coc-tits-prose.md` (the CoC/TiTS parser grammar +
  descriptors + the argmax discriminant + TiTS's evolution),
  `prior-art/deep/charviewer-render.md` (the quantize→select→compose→color render
  pipeline + the graceful-degradation defaulter), `prior-art/deep/tits-body-taxonomy.md`
  (TiTS parts+tags schema + `race()`/`mfn()`/`rawmfn()` as projection).
- `../decisions/reference-analysis.md` — the interaction-graph / affordance framing
  this doc extends ("keep their content graph, replace their world graph").
- `bdcc2-evaluation.md`, `../decisions/bdcc2-integration-plan.md`,
  `../decisions/bdcc2-mining-backlog.md` — the embodiment/NPC lineage (Path A).
- `existence-prior-art.md`, `existence-prose-assessment.md` — the determinism +
  realizer lineage that the references lack and aeriea adopts.
- `../decisions/prose-generation.md` — aeriea's prose design built on the
  authored-fragments + recombination pattern, made deterministic.
- `../../DESIGN.md` — the reference set + the 100%-immersion north star.
