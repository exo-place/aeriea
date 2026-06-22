# Trials in Tainted Space (TiTS) — prior art

Status: studied 2026-06-22 from a full clone of
`github.com/Jacques00/sourceTiTS_public` at
`~/git/tits` (HEAD `0ade46101`). Read targetedly; not exhaustively.

Scope: TiTS is the CoC successor — a single-player, browser/AIR
text-RPG in ActionScript 3, NSFW-first, with deep creature/body
customization and transformation. Studied as prior art for aeriea's
body/transformation/tag system, NSFW content engine, and especially
the prose-from-state thread. Goal is to learn patterns, not adopt
code. AS3 is not a target language; nothing here transfers verbatim.

Codebase shape: `classes/` is the engine (~162k LOC, 836 files);
`includes/` is the content layer (~298k LOC, 220 `.as` files of
authored scenes). 137 named NPC files under `classes/Characters/`,
392 item classes under `classes/Items/`, and ~1400 distinct
`flags["KEY"]` story-state keys grepped across `includes/`. The
content layer is ~2x the engine — this is a content-dominated game.

---

## Body / transformation / tag system

The core model lives in `classes/Creature.as` (17.7k LOC — the base
class for PC and every NPC) plus small part classes
(`CockClass.as`, `VaginaClass.as`, `BreastRowClass.as`).

- **Parts are arrays of part-objects, not scalar fields.**
  `Creature.cocks:Array`, `vaginas:Array`, `breastRows:Array`
  (`classes/Creature.as:1044,1228,1306`). A creature can have N cocks,
  N vaginas, N rows of breasts (each row has its own count, nipple
  type, cup rating, lactation/fullness — `BreastRowClass.as`). Plurality
  is first-class; the prose layer (`allBreastsDescript`) renders "two
  rows of…", "quad", "four-tiered" off `breastRows.length`.
- **Tag system = integer constants + per-part flag arrays.**
  `classes/GLOBAL.as` holds 354 `public static const` (73 `TYPE_*`
  e.g. `TYPE_EQUINE`, `TYPE_CANINE`, …; 43+ `FLAG_*` e.g.
  `FLAG_KNOTTED`, `FLAG_TAPERED`, `FLAG_SHEATHED`, `FLAG_DIGITIGRADE`).
  Each part carries `cType:Number` plus a `cockFlags:Array` of flag
  ints, with `hasFlag/addFlag/delFlag` (`CockClass.as:128-147`). A
  parallel `FLAG_NAMES:Array` maps int→string. This is a flat,
  serializable, append-only enum tag system — exactly the kind of
  data-over-code seam aeriea favors, just expressed as ints rather
  than a richer schema.
- **Geometry derived from tags + scalars.** `CockClass.volume()`
  (`CockClass.as:92-116`) computes a real cylinder+hemisphere volume,
  then mutates it by flags: `FLAG_BLUNT`/`FLAG_FLARED`/`FLAG_TAPERED`/
  `FLAG_DOUBLE_HEADED` each reshape the tip math. Body math is a
  function of (scalars, tags) — a clean separable model.
- **STANDOUT GEM — race is *derived*, never stored.**
  `Creature.race()` (`classes/Creature.as:9617+`) computes a race
  label every call by running ~40 `*Score()` functions
  (`ausarScore()`, `horseScore()`, `gryvainScore()`, …) and applying
  a threshold cascade. Each score sums weighted evidence from parts:
  `ausarScore()` checks ear type, tail type+flags, arm/leg type, and
  *subtracts* for a muzzle. So "race" is an emergent classification of
  the current body, not a field — transformation mutates parts and the
  label re-derives for free. Source even contains a commented-out
  design note proposing a softmax-style "score all, scale, pick max"
  refinement. This is the single most aeriea-relevant idea here:
  identity-as-projection-of-body-state.

## Character creation / customization

`includes/creation.as` (2.3k LOC). A **guided wizard**, not a slider
panel: race → sex → details, each step a screen of `addButton(slot,
label, fn, arg, tooltip, longDesc)`. Race buttons carry long
in-character descriptions of what that lineage grants
(`creation.as:133-187`). Race presets seed body defaults; a hidden
"Engineered" path (`testCharGenSelection`) opens full custom. Depth
comes less from the creator UI and more from the fact that the body
model is fully mutable post-creation via transformation items — you
become customized by *playing*, not only at chargen.

## NSFW content engine

Authored branching scenes, **not** combinatorial act×target×position
generation (the contrast with Lilith's Throne is the key finding).

- A scene is a global `public function fooScene():void` that calls
  `clearOutput()`, emits prose via `output("…")`, then offers
  `addButton(...)` choices wiring to the next scene function. NPC files
  (`includes/mhenga/kelly.as`, 4.7k LOC) are flat collections of these.
- **State drives branching, not generation.** Inside one authored
  scene (`getBlownByKelly`, `kelly.as:4484+`), the *flow* is fixed but
  prose forks on body state and personality: `if(pc.isAss())`,
  `if(pc.isMischievous())`, cum-volume tiers (`pc.cumQ() < 250 / 1000
  / 10000`), `pc.balls`, `pc.hasVagina()`. So a scene is a hand-authored
  spine with state-conditioned sentence variants spliced in.
- Persistent relationship/consent state is plain story flags:
  `flags["KELLY_SEXED"]`, `flags["KELLY_SKYSAP_COLLECT"]`, gated by
  `kellyAttraction()` thresholds. ~1400 such keys across content.
- Cost: enormous authored-prose volume, near-zero per-scene
  combinatorial reach. A given scene only ever depicts the acts its
  author wrote; you cannot recombine an act onto an unanticipated
  partner. This is the explicit thing aeriea's systemic NSFW thread
  wants to *avoid* by going combinatorial (act × target × position ×
  body-state) instead.

## Prose / text generation — the parser

The most directly transferable system. `classes/Parser/ParseEngine.as`.

- Authors write prose with bracket tags: `[pc.cockBiggest]`, `[pc.name]`,
  `[pc.thigh]`, `[if (cond) A | B]`, Spivak pronouns, `[pg]`. At render
  time `recursiveParser()` walks the string, matches brackets, and
  resolves each tag.
- **Resolution is reflection over the game object graph.**
  `getObjectFromString(ownerClass, "pc.cockBiggest")` splits on `.`
  and recursively dereferences members; if it lands on a Function it
  calls it, else stringifies (`ParseEngine.as:299-339, 82-150`).
  The legacy static `singleArgConverters` dictionary in
  `singleArgLookups.as` is now entirely commented out — they migrated
  from a hand-maintained tag→fn table to dynamic introspection.
- **The descriptors themselves are procedural recombination.**
  `cockDescript()` (`Creature.as:14666+`) picks a complexity tier by
  cock type (human→ultraSimple; canine/equine→70% complex), draws
  adjectives from `cockAdjectivesRedux`, a noun from a weighted pool
  (`RandomInCollection("cock","cock","dick","phallus","prick",
  "shaft",…)`), and assembles. `breastSize(val)` maps a cup number to a
  pool of adjectives by tier. So the output is authored-fragment ×
  state-selection × random recombination — fresh-ish each render.
- **Whole-body description from state:** `includes/appearance.as`
  (3.1k LOC) is the canonical "describe the body" aggregator — it reads
  height, race, worn armor, exposure, exhibitionism, then dispatches to
  per-part `*Descript()` builders. This is exactly the prose-from-state
  function aeriea's prose thread needs an analogue of, at much larger
  scale.

LEARN: the tag-as-reflection-path + procedural-recombination-of-
authored-fragments is a proven, low-ceremony way to get state-faithful,
non-repetitive prose. AVOID: resolution by stringly-typed reflection
(`"pc.cockBiggest"` → runtime member walk) is fragile — typos surface
as `!Unknown tag!` at runtime, no compile-time guarantee, and the code
is littered with `// TODO: Get rid of this shit` hacks
(`ParseEngine.as:104,219`). aeriea's data-over-code preference argues
for a typed/validated tag schema, not raw reflection.

## Animation / visual

No paperdoll, no morph rig, no procedural body rendering. Visuals are
**static authored bust PNGs** under `assets/images/npcs/<artist>/`,
selected by discrete state. The naming tells the whole story:
`kiro_busty.png`, `kiro_nude_big_busty.png`,
`kiro_nude_biggerest_busty.png` — a hand-painted variant per coarse
body-state bucket. `showBust(...)` (`classes/GUI.as:1404`) just swaps
the image. This is the sharpest contrast with aeriea: TiTS's body model
is far richer than its renderer can show, so the visual layer collapses
a continuous body space onto a handful of painted buckets. aeriea's
whole premise (3D morph targets, continuous body, mirrors) is the
thing TiTS could not do — but TiTS demonstrates that a deep *simulated*
body underneath a shallow render still delivers the customization
fantasy through prose. (Mirrors the `existence` "simulation underneath,
rendering on top" pattern.)

## Determinism / save

- **No seed, no replay, no event log.** `rand()` is
  `int(Math.random() * max)` (`Creature.as:7732`) — unseeded global
  RNG, called inline throughout prose generation and combat. Same
  state renders differently each time by design (variety), and there
  is no way to reproduce a session.
- **Save = full state snapshot via reflection.**
  `classes/DataManager/Serialization/VersionedSaveable.as` walks
  `describeType(this)` to serialize every variable/accessor into an
  Object, recursing into nested `ISaveable`s, with a per-class
  `version` int and upgrade hooks for migrating old saves.
  `_ignoredFields`/`neverSerialize` opt parts out.
- CONTRAST for aeriea: aeriea's hard invariant is seeded-RNG +
  event-log replay (state derivable from seed + action log). TiTS is
  the opposite pole — snapshot-the-world, nondeterministic RNG in the
  hot loop. Its save model (reflective full-state dump + versioned
  upgraders) is pragmatic and worth noting, but the replay/determinism
  property aeriea wants is simply absent and would have to be designed
  in from the start, not retrofitted.

---

## Takeaways for aeriea

- **Derive identity from body state (the `race()` pattern).** Don't
  store "race"/"species" as an authored field; compute it as a
  classification over current parts/tags so transformation updates it
  for free. Generalizes to any emergent descriptor (build, presentation).
- **Parts as arrays of tagged part-objects** gives arbitrary plurality
  and a clean (scalars, tags) → geometry/prose separation. aeriea can
  keep this but lift the tag vocabulary from bare ints to a typed,
  validated, serializable schema.
- **Prose = authored fragments × state-selection × recombination**,
  resolved through templated tags, is the workable shape for
  state-faithful description — but resolve tags through a *typed*
  binding, not stringly reflection.
- **The deep-sim-under-shallow-render lesson:** TiTS proves a body
  model can vastly exceed what's drawn and still satisfy, via prose.
  aeriea inverts the bet (rich 3D render is the point), but the
  decoupling — body truth in the sim, multiple projections (prose,
  bust, eventually 3D) on top — is sound and shared with `existence`.

## What to avoid

- Authored-only NSFW scenes: combinatorial reach is ~zero per author-hour;
  scales linearly with writing, never composes. aeriea's systemic
  (act×target×position×body-state) approach is the deliberate counter.
- Stringly-typed reflection parser: runtime-only failure, no schema,
  self-described as tech debt in the source.
- Unseeded inline `Math.random()` in generation: kills determinism/
  replay, which is a hard aeriea invariant. Variety must come from
  seeded RNG threaded through the deterministic timeline.
- Comment-stripped legacy cruft and dead dictionaries left in place
  (the commented-out `singleArgConverters`, the `April Fools` regex
  block in `ParseEngine.as:593`) — violates aeriea's "retire, don't
  deprecate" principle.
