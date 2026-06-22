# TiTS body taxonomy & `race()`-as-projection — deep dive

Prior art for aeriea's typed body/transformation system and the playmate/`frond` typed-tag
direction. Source read: `~/git/tits` (ActionScript 3, Flash/AIR). Citations are real
files/line-ranges as of the read.

The one idea worth stealing: **race/build/gender are never stored — they are pure functions
of the current parts+flags.** Transformation only edits parts; identity recomputes for free.
The schema underneath that idea is a cautionary tale, not a model.

---

## 1. The part/slot data model

A creature is a flat bag of slot fields on one giant class. `classes/Creature.as` is **17,753
lines**; every body slot is a public field plus an unlock-gate and a locked-message method,
all hand-written per slot.

### 1a. Scalar/enum slots (the "type" + "flags" pair)

Each major slot is two fields: a `*Type:Number` (an enum index) and a `*Flags:Array`
(a list of small ints). From `Creature.as`:

```
skinType:Number   skinFlags:Array   (568, 593)
faceType:Number   faceFlags:Array   (603, 613)
tongueType:Number tongueFlags:Array (623, 633)
earType:Number    earLength:Number  (655, 656)   // no earFlags
armType:Number    armFlags:Array    (723, 732)
legType:Number    legCount:Number   legFlags:Array (759, 774, 787)
tailType:Number   tailCount:Number  tailFlags:Array tailGenitalArg:Number (828, 857, 876, 887)
wingType:Number   wingCount:Number  (746, 745)    // no wingFlags
hornType:Number   horns:Number      hornLength:Number (701, 690, 712)
antennaeType:Number antennae:Number (678, 666)
```

Note the asymmetry already: some slots have a flags array, some don't; `earLength` is a raw
scalar with no flags; `horns`/`antennae` use a count field named for the part rather than a
uniform `*Count`. There is **no `Slot` type** — each slot is bespoke fields.

The `*Type` values are integer enum constants in `classes/GLOBAL.as` (73 `TYPE_*` constants,
`GLOBAL.as:136+`): `TYPE_HUMAN=0, TYPE_EQUINE=1, TYPE_BOVINE=2, TYPE_CANINE=3, TYPE_FELINE=4,
TYPE_VULPINE=5, …`. The same `TYPE_*` namespace is shared across *all* slots — `legType`,
`armType`, `cType` (cock), `tailType` all draw from one flat int enum. Some are aliases
(`TYPE_NAGA = TYPE_SNAKE`, `TYPE_CENTAUR = TYPE_EQUINE`, `GLOBAL.as:150-151`) and at least one
was renumbered with an apology comment (`TYPE_TANUKI:int = 24; //Changed from 18 to 24 soz is
the same as kui-tan`, `GLOBAL.as:157`).

### 1b. The flag (tag) vocabulary

Flags are the closest thing TiTS has to a typed-tag system. They are small ints in a shared
namespace (`GLOBAL.as:32-76`, 43 flags) with a parallel `FLAG_NAMES` array for display
(`GLOBAL.as:78-123`):

```
FLAG_LONG=1, FLAG_PREHENSILE=2, FLAG_LUBRICATED=3, FLAG_FLUFFY=4, FLAG_SQUISHY=5,
FLAG_SMOOTH=6, FLAG_TAPERED=7, FLAG_FLARED=8, FLAG_KNOTTED=9, FLAG_BLUNT=10, …
FLAG_PLANTIGRADE=16, FLAG_DIGITIGRADE=17, … FLAG_HOOVES=22, FLAG_PAWS=23, …
FLAG_CHITINOUS=34, FLAG_FEATHERED=35, FLAG_GOOEY=37, … FLAG_BEAK=43
```

Flags are **multi-dimensional jammed into one flat list**: texture (`FLUFFY`, `SMOOTH`,
`SCALED`, `CHITINOUS`), shape (`TAPERED`, `FLARED`, `KNOTTED`, `BLUNT`, `DOUBLE_HEADED`),
stance (`PLANTIGRADE`/`DIGITIGRADE`), foot-form (`HOOVES`/`PAWS`/`HEELS`), and behavioural
(`APHRODISIAC_LACED`, `LUBRICATED`). Nothing enforces that a "stance" flag and a "texture"
flag are mutually distinct or mutually exclusive — `PLANTIGRADE` and `DIGITIGRADE` can both be
absent (`hasLeg()` returns false, `Creature.as:4399`) or, with a buggy add, both present.

A *partial* attempt at typing exists: `VALID_SKIN_FLAGS:Array` (`GLOBAL.as:125-133`) lists the
7 flags skin is allowed to carry. But it is an opt-in advisory list, not enforced at the add
site — `addSkinFlag` doesn't consult it.

The flag accessors are hand-duplicated per slot — `hasFaceFlag/addFaceFlag/removeFaceFlag/
clearFaceFlags` (`Creature.as:4321-4341`), then `hasTailFlag…` (`4342-4360`), then `hasArmFlag…`
(`4361-4379`), then `hasLegFlag…` (`4380-4398`), each a verbatim linear scan over its own
array. The whole set is copy-paste per slot — the slot identity lives in the *method name*,
not in data.

### 1c. Sub-object parts (the better-typed half)

Genitalia/breasts are real classes held in arrays, not scalar slots — the one place TiTS uses
composition:

```
cocks:/*CockClass*/Array       (Creature.as:1044)
vaginas:/*VaginaClass*/Array   (Creature.as:1228)
breastRows:/*BreastRowClass*/Array (Creature.as:1306)
```

(The `/*CockClass*/` comment is AS3's way of faking a generic — the array is untyped `Array`,
the element type is documentation only.)

`CockClass` (`classes/CockClass.as`, 201 lines) is genuinely the cleanest part of the system:
dimensions are raw+mod pairs with a computed getter (`cLengthRaw`/`cLengthMod` →
`cLength(arg, apply)`, lines 15-39; same pattern for `cThicknessRatio`, 48-72), it has its own
`cType:Number` and `cockFlags:Array` (75, 82), and **derived geometry is computed, not stored**
— `volume()` builds a cylinder+hemisphere model and *branches on flags* (`FLAG_BLUNT`,
`FLAG_FLARED`, `FLAG_TAPERED`, `FLAG_DOUBLE_HEADED`, lines 92-116); `effectiveVolume()` adjusts
for `FLAG_LUBRICATED`/`FLAG_STICKY` (121-126). This is the exact "derive from parts+tags"
pattern, scoped to one part — and it's clean precisely because the scope is small and the
dimensions are real numbers, not enum-soup.

---

## 2. The classification mechanism: `race()` as a pure projection

`race():String` (`Creature.as:9617-9701`) stores **nothing**. It is recomputed on every call
from the current slots+flags. `originalRace:String` (`Creature.as:126`) is the only stored
identity, used purely to narrate drift ("you started as a human but have become a …",
`includes/appearance.as:56-59`).

### 2a. Score functions = weighted feature voting

Each candidate race has a `*Score():int` function (37 of them in `Creature.as`) that tallies
how many of its signature features the body currently has. `humanScore` (`9810-9823`):

```
if (skinType == GLOBAL.SKIN_TYPE_SKIN) counter++;
if (armType == GLOBAL.TYPE_HUMAN && !hasArmFlag(GLOBAL.FLAG_GOOEY)) counter++;
if (legType == GLOBAL.TYPE_HUMAN && legCount == 2 && hasLegFlag(GLOBAL.FLAG_PLANTIGRADE)) counter++;
if (faceType == GLOBAL.TYPE_HUMAN) counter++;
…
if (hasTail()) counter--;          // negative votes
if (isGoo() || isTaur() || isNaga() || isDrider()) counter -= 2;
```

`ausarScore` (`9824-9833`) is more interesting — it has **conditional gating** (a feature only
counts once a threshold is met):

```
if (counter > 0 && faceType == GLOBAL.TYPE_HUMAN) counter++;   // human face only counts if you already scored
if (hasFaceFlag(GLOBAL.FLAG_MUZZLED)) counter -= 2;            // a muzzle disqualifies
```

`kaithritScore` (`9844-9857`) stacks the gating: `counter > 1 && …`, `counter > 2 && …`,
`counter > 3 && … += 2`, `counter > 5 && …` — a hand-rolled cascade where later features only
register if enough earlier ones did. `leithanScore` (`9858-9869`) even has a hard veto:
`if (eyeType != GLOBAL.TYPE_LEITHAN) counter--`. So each score is an ad-hoc weighted feature
vote with per-race thresholds, gates, vetoes, and negative features — all in imperative `if`s.

### 2b. The selection: last-threshold-wins, ordered

`race()` does **not** pick the max score. It runs ~60 `if (xScore() >= N) race = "…"` lines in
sequence; **the last assignment that fires wins** (`Creature.as:9636-9698`). The thresholds are
hand-tuned per race (`horseScore >= 3`, `vulpineScore >= 4`, `kaithrit >= 6`, `gryvain >= 9`).
Ordering encodes priority: weaker partial races (`half-*`) are assigned early, stronger full
races later overwrite them, and special combinations come last (taur/naga/goo modifiers,
`9684-9694`; `if (race == "human" && humanScore() < 4) race = "alien hybrid"` as the final
fallback, `9698`).

The author left a comment block (`9624-9632`) explicitly noting this is *wrong* and that a
proper system would compute all scores, normalize them to a common scale, pick the highest, and
break ties by natural max. **They knew the right design and shipped the ordered-`if` hack
anyway** — a real warning about how this kind of taxonomy ossifies.

Sub-classifiers refine within a family by reading *more* features: `equineRace()`
(`9707-9718`) → alicorn/unicorn/pegasus/horse by `hasHorns()`+`hasWings()`+`horns==1`;
`bovineRace()` (`9719-9745`) branches on `femininity`, `hasCock()/hasVagina()`, `hasBreasts()`,
`hasLegFlag(FLAG_HOOVES)` to choose among ~12 labels (minotaur/holstaurus/cow-girl/bull-man/…).
`avianRace()` (`9764-9777`) cross-reads `legType`+`faceType` flags to distinguish
griffin/hippogriff/harpy/sirin.

### 2c. Normalization for downstream use: `raceShort` / `stripRace`

`raceShort(strict)` (`9702-9705`) calls `stripRace(race(), …)`
(`classes/Engine/Utility/stripRace.as`), which **strips the projection back to a family key**
by string-munging: drop `half-`/`part `/`-morph`/`-taur`/`-girl`/`-boy` affixes (lines 10-30),
then collapse synonyms via `InCollection` lookups (`["cow","bull","futaurus",…] → "bovine"`,
`["horse","alicorn","unicorn","pegasus"] → "equine"`, lines 35-43). So the pipeline is:
parts+flags → rich label (`race()`) → string surgery → coarse family (`raceShort`). The coarse
key is itself derived, never stored — but it's derived by **parsing the prose label**, which is
the leak (see §4).

---

## 3. Build & gender are also projections (same pattern, cleaner inputs)

The same compute-don't-store discipline applies to two more identity axes, and here the inputs
are continuous scalars, which works better:

- **Build/physique** — `bodyType()` (`Creature.as:8380+`) returns a prose body description as a
  pure function of two scalars, `thickness` (waistline 0-100) and `tone` (muscle 0-100), via a
  nested threshold grid (`thickness < 10/25/40/60/75/90/…` × `tone > 90/75/50/25/…`). Nothing
  is stored; change a scalar and the description follows. It also reaches into parts for
  conditional clauses (`if (hasVagina() || biggestTitSize() > 3 || hipRating() > 7 …) desc +=
  " and plenty of jiggle"`, `8427`).

- **Gender presentation** — `mfn(male, female, neuter)` (`9228-9265`) computes a `weighting`
  from `femininity` (`383`, default 50) plus contributions from `biggestTitSize()`,
  `hipRating()`, `hairLength`, `tone`, `lipRating()`, and a `-100` slam for `hasBeard()`
  (9236-9254), then thresholds: `<45 → male`, `45-55 → neuter`, `>55 → female`. Hard overrides
  exist as status effects (`"Force Fem Gender"` etc., 9230-9231). `rawmfn` (9269-9276) is the
  anatomical variant: pure `hasCock()`/`hasVagina()` with no femininity weighting. So TiTS
  cleanly separates **presented gender** (weighted-soft, `mfn`) from **anatomical sex**
  (`rawmfn`) — both projected, neither stored. This separation is a genuinely good idea worth
  taking wholesale.

---

## 4. Honest assessment: where it leaks vs where it's genuinely good

### Genuinely good (steal these)
- **Identity = pure function of parts+tags.** Transformation code only ever mutates slots;
  `race()`/`bodyType()`/`mfn()` recompute. No "update derived race after TF" bug class can
  exist. This is the load-bearing idea and it is correct.
- **Weighted feature-voting with negative features and vetoes** is a flexible, designer-tunable
  classifier — adding a race is "write one `scoreFn` + one threshold line," no migration.
- **Separating presented-gender (soft, weighted) from anatomical-sex (hard).**
- **`CockClass.volume()`** — derived geometry computed from dimensions and branched on flags;
  the right shape for a part, kept clean by small scope and real-number dimensions.

### Leaky / anti-patterns (do NOT copy)
- **Magic ints in one flat shared namespace.** 73 `TYPE_*` + 43 `FLAG_*` as bare ints, shared
  across every slot, with alias collisions (`TYPE_NAGA == TYPE_SNAKE`) and a renumber-with-
  apology (`TYPE_TANUKI` 18→24). No slot-scoping, no compiler help, no exhaustiveness.
- **Untyped slots, no `Slot`/`Part` abstraction.** Every slot is bespoke public fields +
  hand-duplicated `has/add/remove/clearXFlag` methods (4 methods × N slots, verbatim). 17.7k-line
  god-class. Asymmetric fields (`earLength` but no `earFlags`; `horns` not `hornCount`).
- **Flags are multi-dimensional crammed into one flat list** (texture+shape+stance+behaviour),
  with no enforcement of which flags are legal on which slot (`VALID_SKIN_FLAGS` exists but
  isn't checked at add-time) and no mutual-exclusion (stance flags can be both-absent or, by
  bug, both-present).
- **`race()` selection is ordered-last-wins, not max-score** — priority is encoded in source
  line order, thresholds are uncommented magic numbers, and the author's own comment admits the
  design is wrong. Fragile, non-explainable, order-dependent.
- **`raceShort`/`stripRace` derives the coarse key by *string-parsing the prose label*** — the
  family key depends on the spelling of the rich label. Renaming a label silently breaks
  classification. The coarse axis should have been computed from features directly, not scraped
  from text.

---

## 5. Concrete aeriea implications

aeriea is deterministic, NSFW-first, deep-customization, with a prose realizer + visual channel
+ typed body/tag system in progress. Mapping:

1. **Adopt identity-as-projection as a hard rule.** Body state stores only parts+tags; `race`,
   `build`, `presented_gender`, `anatomical_sex`, and any "what does this read as" label are
   `fn(body) -> label`, memoized per-frame at most, never persisted. This makes transformation
   trivially correct and keeps the prose realizer and visual channel reading from one source.
   (TiTS proves the pattern works at scale; copy the discipline, not the implementation.)

2. **Type the tag namespace; do NOT use flat magic ints.** Where TiTS has one int soup, aeriea
   should have *dimensioned, slot-scoped* typed tags (this is exactly the playmate/`frond`
   direction). A tag should know its dimension (texture / shape / stance / behaviour) and its
   legal slots, so "can this slot carry this tag" and "are these two tags mutually exclusive"
   are answerable from data, not enforced by hope. `VALID_SKIN_FLAGS` is the vestigial good
   instinct TiTS never followed through on — finish that idea.

3. **Make classification data, not ordered `if`s.** Per the ecosystem "data over code at a
   seam" principle: encode each race/archetype as a *serializable* scorer — a list of
   `(feature_predicate, weight)` rows with a threshold and optional vetoes — and a real
   max-score-with-tiebreak selector (the design TiTS' own comment at `9624-9632` describes but
   never built). Serializable rules cache, diff, replay, and stay deterministic; the
   ordered-last-wins `if`-cascade is none of those. (Caveat: predicates over body state may be
   the one genuinely-code seam — if a predicate can't be expressed as data without wrapping a
   closure, keep that leaf as code and keep the *weights/thresholds/order* as data.)

4. **Separate anatomical-sex from presented-gender from the start** (TiTS `rawmfn` vs `mfn`).
   For an NSFW-first sandbox both axes matter independently and both must be projections, with
   explicit hard-override hooks (TiTS' "Force * Gender" status effects) for player agency.

5. **Derive coarse keys from features, never by parsing prose.** Whatever the visual channel or
   gameplay needs as a family key must come from the body state directly. Do not regenerate
   TiTS' `stripRace`-on-the-label leak where the taxonomy depends on label spelling.

6. **Composition over god-class.** TiTS' 17.7k-line `Creature` with per-slot duplicated accessors
   is the cost of no `Slot`/`Part` abstraction. aeriea should have a uniform part/slot
   representation (one `has/add/remove tag` path) so adding a slot is data, not 4 copy-pasted
   methods + bespoke fields.

### Gotchas to carry forward
- TiTS shows magic-int taxonomies **ossify**: aliases collide, ints get renumbered with
  apologies, the author knows the right design and ships the hack because refactoring the int
  soup is too expensive. Pay the typing cost up front.
- Ordered-`if` classifiers are **order-dependent and non-explainable** — you can't ask "why is
  this body classified X." A scored/serialized classifier can emit its evidence.
- Deriving one derived value (coarse key) **from another derived value's text** (the label)
  couples spelling to logic. Always derive from the root state.
- TiTS flags mix dimensions in one list with no mutual-exclusion → invalid combinations are
  representable (both/neither stance). aeriea's typed tags should make invalid states
  unrepresentable per dimension.
