# Prior Art: Nimin (Fetish Master)

Status: Studied 2026-06-22. Source: full clone of https://github.com/XaderaDiddle/Nimin at `~/git/nimin` (the "Nimin v1" tree, ~27k LOC ActionScript 3, Flash/AS3, version 0.975o).

Scope: A CoC-lineage (Corruption of Champions) text-based transformation game. Studied as prior art for aeriea's body/transformation, NSFW content, and prose-generation threads. Goal is to learn patterns and anti-patterns, NOT to adopt code (it is AS3/Flash, single-player, no determinism). This is an *early-2010s hobbyist* codebase — many lessons here are cautionary.

Codebase shape: 56 `.as` files under `Nimin v1/code/` + `Events/`. Largest: `Items.as` (3410), `Transformations.as` (1696), `Enemies.as` (1408), `SaveLoad.as` (1130), `Leveling.as` (967), `Appearances.as` (671), `Descriptions.as` (822). No build system, no tests, no data files — everything is code.

---

## Data model: one flat god-object

The entire player is `code/Character.as` — a single class with ~330 public primitive fields (`int`/`Boolean`/`Number`), no nesting, no composition. Body parts (`cockSize`, `breastSize`, `tail`, `ears`, `legType`, `hairColor`...), statuses (`heat`, `lactation`, `pregStatus`...), per-race affinities (`humanAffinity`...`bugAffinity`), per-NPC relationship state (`lilaRep`, `jamieChildren`, `silTied`...), per-fetish weights, per-baby-species counters, and per-recipe alchemy-knowledge booleans are ALL flat sibling fields on one object.

Worse: `code/GameSetup.as` re-declares every one of those fields *again* as module-level globals (`var human:int`, `var str:int`, ...). The Character instance `p` exists mainly for serialization (`registerClassAlias("Character", Character)`); gameplay reads/writes the globals, and save/load shuttles values between `p` and the globals by hand. Two parallel copies of the same state.

- LEARN: the *flat-addressable* feel is part of why authoring prose is easy — `cockTotal`, `lust`, `boobTotal` are right there with no traversal. aeriea's prose layer wants a similarly cheap read path over body state.
- AVOID: the god-object + duplicated-global pattern is unmaintainable and unserializable-by-default. aeriea's commitment (data over code, simulation underneath) means body state should be *structured data* (parts as a typed collection / frond-style tags), not 330 hand-named sibling ints, and there must be ONE source of truth, not a class mirrored into globals.

## Body / transformation: the "blood / affinity" model (the standout idea)

`code/Transformations.as` (header comment lines 3-20) documents the core mechanic cleanly: each race has a "blood"/affinity value 0-100; the highest becomes `dominant`; crossing thresholds drives change. This is a genuinely good *systemic* TF model worth remembering.

- `affinity(...)` / `aff(race, change, otherChange)` nudge multiple race scores at once; a global `changeMod` multiplier scales all change (humans get `changeMod += .5` — "more adaptive"), so susceptibility is itself a stat.
- `affinityChange()` (line 74) recomputes `dominant` by pushing all `affinity+delta` sums into an array, numeric-sorting, and popping the max — then fires per-race threshold prose.
- Threshold crossings use **hysteresis-aware paired conditions**: gaining fires `(affinity+delta) >= 40 && affinity < 40`; losing fires the mirror `(affinity+delta) < 40 && affinity >= 40`. Tiers stack per race (40, 55, 70...). Both directions are separately authored, so de-transformation reads as well as transformation.

Body parts beyond race are independent axes changed by their own functions (`cockChange`, `cockLoss`, `vagChange`, `boobChange`, `udderChange`, `legChange`, `lactChange`) — multiple cocks of mixed species (`humanCocks`, `horseCocks`...) tracked as separate counts summing to `cockTotal`.

- LEARN: continuous affinity scores → discrete thresholded morphology is a clean way to make TF feel gradual yet legible, and the gain/lose symmetry is the right instinct. The "adaptiveness as a stat" (`changeMod`) is a nice second-order knob. Cross-reference playmate's `frond` tag system here — frond is the structured-data version of what Nimin does ad hoc.
- AVOID: the threshold prose is hardcoded inline in one 1700-line function with copy-pasted `if`-blocks per race × tier × direction. Adding a race means editing the mega-function in N places. aeriea wants the *mechanic* (affinity→threshold→effect+text) as data/config so new species are content, not code edits.

## Prose generation: procedural concatenation of authored fragments, with rolled variation

This is the most directly relevant thread for aeriea. There is no template/parser DSL like LT's `[pc.cockNoun]`. Instead prose is built by **imperative string concatenation gated on state**, with a layer of small descriptor helper functions.

- `code/Appearances.as` `appearanceGo()` is the full-body description: ~250 lines of `tempStr += "..." + helper() + "..."` with `if (condition)` guards for every body feature, clothing, status, and item. E.g. breast prose branches on `boobTotal == 2/4/6/8/10`; nipple-firmness prose branches on `lust < 50 / < 75 / else`; cum descriptions branch on a 7-bucket volume table (`getCum <= 24`, `<= 72`, ... `> 20000`).
- `code/Descriptions.as` is the noun/adjective helper layer: `bodyDesc()`, `tailDesc()`, `cockDesc()`, `nipDesc()`, etc. map state → an adjective/noun phrase. Two nice tricks:
  - **`plural(topic)`** (line 12) centralizes singular/plural agreement: one function returns the right suffix/pronoun ("s", "their", "it's"/"they're", "is"/"are", "penises", "pussies") for 16 grammatical cases keyed by `cockTotal`/`vagTotal`. This is the seed of a proper grammar/agreement layer.
  - **Rolled descriptor variation**: `tailDesc()` calls `percent()` and picks among adjective variants by chance band (`if (chance <= 50)`), so the same body reads differently across viewings — cheap variety from authored alternatives.
- **Visible-error defaults**: every descriptor initializes to `"BODY ERROR "+gender+" "+body` / `"ITEM NAME ERROR "+ID` etc. Unhandled state surfaces loudly in the text instead of silently emitting "". A poor-man's exhaustiveness check.
- `decGet(value, decimals)` converts a raw size stat into a believable inches measurement inline in prose (`breastSize*.5`, `cockSize*cockSizeMod*.25`) — quantities are *computed from stats*, not authored.

- LEARN: (1) a centralized grammar-agreement helper (`plural`) is worth having from day one; aeriea's prose should not scatter `s`/`es` logic. (2) rolled variation among authored fragments gives texture cheaply — but in aeriea it MUST draw from the seeded RNG (Nimin's `percent()` is non-deterministic; this would break aeriea's replay invariant). (3) loud error-defaults are a good cheap guard. (4) deriving numbers (inches, volume) from stats keeps prose consistent with sim state.
- AVOID: monolithic `tempStr +=` walls are unmaintainable, untestable, and impossible to retarget (no way to render the same state as SFW, or in another tense/POV, or as structured data). aeriea's "prefer data over code at a seam" applies hard here: the *description* of a body should be data (a structured set of clauses/fragments with conditions and slots) consumed by a renderer, so it can be diffed, cached, SFW-toggled, and reused across surfaces. Nimin is the canonical example of the code-seam failure this principle warns against.

## NSFW content engine: organ-dispatched authored scenes, lust-gated

No combinatorial act × target × position × body-state matrix (LT's approach). Nimin dispatches on **what organs you have**. `code/Masturbation.as` `doMasturbate()` shows menu options conditionally (`if (cockTotal > 0)`, `if (udders == true)`...), then routes to `doCockMasturbate` / `doVagMasturbate` / `doBoobMasturbate` / `doUdderMasturbate`. Within a scene, a random-eligible organ is chosen (`rndArray.push(...)` of present cock species → `chooseFrom()`), mapped to a flavor noun ("hard human rod", "pointy wolf meat"...), and outcome prose branches on `lust` thresholds and computed `cumAmount()`. Sex content lives in `Masturbation.as`, `Prostitution.as`, `Battling.as` (loss scenes), and the `Events/` files (NPC encounters like `DairyFarm`, `SizCalit`, `Den`).

Consent/flow: minimal. There is a `Preferences.as` and a *disabled* per-fetish lust-multiplier system — `doLust()` in `code/StatChanges.as` (lines 270-291) has the entire fetish-weighting block **commented out**. So the design *intended* fetish preferences to scale arousal per content tag, but it was never shipped. The `*Fetish` fields on Character exist but are largely inert.

- LEARN: organ-presence dispatch is a pragmatic middle ground — fewer combinations than a full matrix, content stays coherent with the morphology. The (aspirational) fetish-tag → arousal-multiplier idea is exactly the kind of player-preference knob aeriea's NSFW-first design wants — but Nimin proves it needs to be built in, not bolted on (theirs died as dead code).
- AVOID: scenes are bespoke functions; little reuse across scenes; no consent/flow model to speak of. aeriea should treat acts/targets/states as data so content combines, and should design preference-weighting as a first-class, live system (not commented-out intent).

## Animation / visual

None. Pure text. No paperdoll, no sprite, no hair physics — relevant only as the contrast: aeriea's CharacterViewer cannot crib visuals here, but the *textual* body model is the asset. (The two `.swf` files are the compiled Flash binaries.)

## Content / world structure

Content is authored as **integer-ID switch ladders**. `code/Items.as` (3410 lines) is `function itemName(ID)` / `itemDescription(ID)` / effect-handlers, each a long `if (ID == N) { ... }` chain; items 101..234+ each appear in multiple ladders. `Enemies.as`, `TownStuff.as`, `Leveling.as` (classes/perks), `Alchemy.as` (recipes) follow the same shape. Zones/NPCs are hand-coded functions under `Events/`. Scale: a few hundred items, ~a dozen races, ~a dozen zones — substantial for a hobby project, but every addition is a code edit across several parallel ladders keyed by the same ID.

- AVOID (strongly): ID-keyed parallel switch ladders are the textbook data-as-code anti-pattern aeriea's principles target. An item should be one data record (name, desc, effects, tags); Nimin smears each item across `itemName`, `itemDescription`, effect, shop, and crafting ladders that must stay in sync by hand.

## Determinism / save: snapshot, no seed, no replay

As expected, **no determinism model**. `percent()` is ungated `Math.random()` used everywhere (combat, TF variant selection, prose flavor). Save (`code/SaveLoad.as`) is a full mutable-state **snapshot** to Flash `SharedObject` slots (`Nimin_Save1`..`11`) plus `.nim` file export. Serialization is hand-rolled positional arrays per category (`statsSave`, `cockSave`, `affinitySave`, `repSave`, `majorFetishSave`...) assigned into `so.data.*`, with a `versionNumber` ("0.975o") for migration. Brittle: every new field means editing both the save-pack and load-unpack arrays in lockstep, and old saves need version-conditioned patching.

- LEARN/CONTRAST: this is the polar opposite of aeriea's "seed + action log, fully replayable" commitment. Nimin's save is a fragile photograph of mutable globals; aeriea's is a reproducible derivation. The pain Nimin shows — manual positional serialization, version-migration hand-coding, two copies of state — is exactly what determinism-from-seed + structured state avoids.

---

## Net takeaways for aeriea

- The **affinity/blood → threshold → morphology** model (with gain/lose symmetry and a global susceptibility multiplier) is the keeper idea. Make it data-driven (per-species config), seeded, and built on a structured tag/part system (cf. playmate `frond`).
- **Centralize grammar agreement** (Nimin's `plural()`) and **derive quantities from sim stats** for prose — both good instincts to carry over.
- **Rolled descriptor variation** is great texture, but route it through aeriea's seeded RNG, never `Math.random()`.
- The whole codebase is a **case study in the data-over-code failure**: god-object state, monolithic `tempStr +=` prose, ID-keyed switch ladders, hand-rolled positional saves. aeriea's principles (data at the seam, library-first projection, determinism) are precisely the corrections.
- The **commented-out fetish-weighting** is a reminder: player-preference content scaling must be designed in as a first-class system, or it dies as inert fields.
