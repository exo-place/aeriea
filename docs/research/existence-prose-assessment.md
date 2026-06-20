# `existence` prose quality assessment: boilerplate or deep prose?

Status: **EVIDENCE STUDY — real runtime output; read-only on `existence`** (2026-06-20)

Scope: this is an honest, evidence-based assessment of the prose quality produced
by `existence`'s realizer (`js/realization.js`, 4,018 LOC). The question is
whether `existence` is prior art for *rich/deep procedural prose* — the target
of `docs/decisions/prose-generation.md` — or only for state-faithful functional
description. All prose samples are **real runtime output** produced by running
`realize()` directly via `bun -e` in the `existence` dev shell. No outputs are
reconstructed or fabricated. Cross-references: `docs/research/existence-prior-art.md`
(substrate/architecture prior-art study) and `docs/decisions/prose-generation.md`
(the prose-generation moonshot this assessment bears on).

---

## Verdict

`existence`'s prose is boilerplate in the honest technical sense: every sentence
is assembled at runtime from pre-authored string fragments selected by weighted
random pick from lexical pools, with weights modulated by the character's
neurochemical state (NT snapshot: GABA, NE, adenosine, serotonin, dopamine) and
by observation properties (thermal.cold, interoception.gnawing, sight.grey,
etc.). The resulting sentences are short, structurally monotone (subject →
predicate ± modifier, or body-as-subject, or bare NP fragment), and lexically
narrow — each sensation source has 5–10 subject candidates, 6–10 predicate
candidates, 3–6 modifier candidates. Under varied seeds the fridge produces
"The fridge settles, as always." / "The fridge clicks off." / "The fridge kicks
on." in rotation; structural variety is limited to eight sentence architectures
that each resolve to one of three basic shapes. There is no system aimed at
prose *quality* or *depth* — no grammar, no constituent stacking, no semantic
composition, no build-time learned representation, no mechanism for generating
novel phrasing. What the system *does well* is state-faithfulness: the selected
fragments shift meaningfully and consistently with neurochemical state (high
adenosine prefers vague subjects like "something"; low GABA prefers unsettled
predicates; low serotonin prefers tautological flat descriptions). This is a
carefully tuned **slot-substitution system with NT-weighted selection** —
sophisticated mad-libs, not deep prose generation. The owner's recollection
("very very boilerplate, no deep prose-generation system") is confirmed by the
evidence.

---

## Samples

All samples are real runtime output from `realize()` called directly in bun,
with the observation objects and NT states stated below each sample.
Seed: xorshift32 with the stated seed, or explicit RNG sequences (`mkRng`).

**Sample 1** — `fridge`, calm, neutral NT (seeds 10–14, repetition check):
```
10: The fridge kicks on, as always.
11: The fridge clicks off.
12: The fridge settles.
13: The fridge kicks on.
14: The fridge clicks off.
```
Source: `js/realization.js` `LEX.fridge`, `buildShortDeclarative`. The five
outputs are drawn from the same pools: subjects × predicates × modifiers.
Two distinct predicates appear across five seeds ("kicks on", "clicks off",
"settles"). "As always" is the only modifier that fires (serotonin 0.5 neutral).

**Sample 2** — `fatigue`, calm, high-adenosine (FOGGY = aden:0.8), body-as-subject:
```
The body doesn't lift.
```
Source: `buildBodyAsSubject`, `LEX.fatigue.body_subjects` × `body_predicates`.

**Sample 3** — reframe-dash: `fatigue`, flat, `mkRng(0.66, 0.0, 0.0, 0.0)`:
```
Not tired — somewhere past it.
```
Source: `buildReframeDash`, `LEX.fatigue.reframe_pairs`. Template: `Not {rough} — {precise}.`
This is the most distinctive architecture — the pairs are pre-authored
(e.g. `{ rough: 'tired', precise: 'somewhere past it' }`), not composed.

**Sample 4** — interpretive-escape: `fridge`, calm, `mkRng(0.9, 0.1, 0.1, 0.1)`:
```
The fridge hums, and the sound was just a sound.
```
Source: `buildInterpretiveEscape`. Template: `{subject} {predicate}, and {escape}.`

**Sample 5** — source-ambiguity: `fridge`, dissociated, `mkRng(0.8, 0.0, 0.1, 0.1)`:
```
Something — the fridge, maybe, or the heat — hums.
```
Source: `buildSourceAmbiguity`. Template: `Something — {primary}, maybe, or {alt} — {predicate}.`
The template is fixed; only the alt and predicate vary.

**Sample 6** — conditional-inversion: `fatigue`, calm foggy, `mkRng(0.92, 0.0, 0.0, 0.0)`:
```
Something has weight to it, but only when she stopped moving.
```
Source: `buildConditionalInversion`. Template: `{subject} {predicate}, {inversion_condition}.`

**Sample 7** — overwhelmed polysyndeton: `fatigue`+`fridge`+`traffic_outdoor`, seed 101:
```
The body has weight to it and the refrigerator clicks off, too loud and the street.
```
Source: `realize()` overwhelmed path — each obs is realized independently and joined
with " and ". The third obs's sentence truncates to just "the street" (bare fragment).

**Sample 8** — three-obs anxious passage, seed 333:
```
Hunger makes itself known. Something is there and unreasonable. Something clicks off, too loud.
```
Source: independent path, three sentences. The third sentence incorrectly attributes
`fridge` as "something" (adenosine weighting raised "something" above "the fridge").

**Sample 9** — trauma echo + anxiety, anxious, high NE (0.80), seed 1:
```
Something lands wrong, and the room changes shape. Something has no object for this.
```
Source: `LEX.trauma_echo` `buildInterpretiveEscape` + `LEX.anxiety_signal` short declarative.
The escape pool for trauma_echo includes "and the room changes shape" — an interesting
fragment, but it is a fixed authored string, not generated.

**Sample 10** — flat tautology: `fatigue`, flat, `mkRng(0.88, 0.0, 0.0, 0.0)`:
```
Still tired.
```
Source: `buildFlatTautology`, `LEX.fatigue.flat_descriptions`. A pool of
3 pre-authored one-liners; this picks the first.

---

## How the prose is generated

The mechanism, verified against `js/realization.js`:

**Layer 0 — Observation**: `senses.getObservations()` returns typed `Observation`
objects with a `sourceId` (e.g. `'fridge'`, `'fatigue'`, `'anxiety_signal'`),
`channels`, `salience`, and `properties` (typed per source: `thermal.cold`,
`interoception.gnawing`, etc.). The caller filters by salience and habituation
before passing to `realize()`.

**Layer 1 — Architecture selection**: `realize()` draws 4 random values per
observation. The first (`r1`) selects one of 8–9 sentence architectures using a
weighted-pick (`wpick`) over `ARCH_WEIGHTS[hint]` — a table of architecture
weights per NT hint (`'calm'`, `'anxious'`, `'dissociated'`, `'overwhelmed'`,
`'flat'`, `'heightened'`). Architectures:
- `short` → `buildShortDeclarative`: `{subject} {predicate}[, {modifier}].`
- `body` → `buildBodyAsSubject`: `{body_subject} {body_predicate}.`
- `bare` → `buildBareFragment`: `{fragment}.`
- `ambig` → `buildSourceAmbiguity`: `Something — {primary}, maybe, or {alt} — {predicate}.`
- `escape` → `buildInterpretiveEscape`: `{subject} {predicate}, and {escape}.`
- `reframe` → `buildReframeDash`: `Not {rough} — {precise}.`
- `char_pred` → `buildSensationCharacter`: `{subject} {char_predicate}.`
- `flat_taut` → `buildFlatTautology`: picks from `flat_descriptions` pool.
- `inversion` → `buildConditionalInversion`: `{subject} {predicate}, {condition}.`

**Layer 2 — Lexical pool selection**: Each architecture uses the remaining 3
random values (`r2`, `r3`, `r4`) to pick items from per-source lexical pools
defined in the `LEX` constant (lines 138–3175 of `realization.js`). Each pool
item is a string or `{ text, w }` where `w` is either a constant or a function
`(nt, obs) => number`. The NT snapshot and observation properties modulate
weights: e.g. `{ text: 'something', w: nt => nt.aden > 0.6 ? 1.5 : 0.2 }`.

**Layer 3 — Passage shapes** (multi-obs): when 2+ observations are passed, an
additional shape is selected using `obs[0]`'s `r1` slot:
`'independent'` (one sentence per obs), `'appositive'` (two obs folded into
one compound sentence: `{main clause}, {appositive_np}.`), `'terminal_list'`
(comma-separated fragments), or `'arrival_seq'` (sentences joined with "Then").

**Layer 4 — Deterministic modifiers** (no extra RNG): acoustic modulation
(reverb/absorption suffixes), chromesthesia (colour fragments for sound sources
when `ntCtx.synesthesia` is true), APD (parse-fail fragments for speech sources
when `ntCtx.apd` is true), and flashbulb perception (hyperspecific fragments
for `has_ptsd && ne > 0.70`). All reuse `r1` as an index — no extra RNG calls.

**What it is not**: there is no grammar, no constituent recursion, no semantic
composition of sub-clauses, no corpus-trained model, no learned distribution,
no LLM, no template *expansion* (only *selection*). The full vocabulary of a
source like `fridge` is on the order of 30–40 unique strings across all pools.
Novelty is impossible — the system can only produce strings that were authored
in `LEX`.

---

## Bearing on aeriea

`existence`'s realizer is **not prior art for rich/deep procedural prose** in
any sense that transfers to `docs/decisions/prose-generation.md`'s target.

**What it does NOT prove:**
- That a deterministic system can generate sentences that are *novel*, *richly
  varied*, or *superior to handwritten prose* — existence's output is none of
  these; it rotates a finite authored vocabulary.
- That state-faithful description can exceed the qualitative ceiling of its
  author's lowest-common-denominator phrasing — "The fridge clicks off." /
  "Something has weight to it." are functional placeholders, not telling detail.
- That passage-level structure (appositive, arrival_seq, terminal_list) lifts
  prose quality significantly — the samples show it produces workable rhythm but
  not depth; the compound forms still resolve to small authored fragments.
- That this mechanism scales to the complexity of aeriea's state space (NSFW
  content, body-state specificity, relational dynamics, transformation sequences).

**What it DOES prove:**
- The plumbing: NT-weighted lexical selection is a viable, testable, deterministic
  architecture for a state-faithful realizer. It is provably implementable at
  game-loop speed with no hot-loop LLM.
- The multi-layer modifier pattern (Layer 4) shows a clean way to add
  character-specific perceptual coloring (synesthesia, APD, PTSD flashbulb)
  without breaking RNG invariants or adding call-count overhead.
- The observation+hint interface (`realize(observations, hint, ntCtx, random)`)
  is a clean boundary: the simulator produces typed observations with properties;
  the realizer is a pure function. This interface shape is worth emulating.
- The `reframe_pairs` (`Not tired — somewhere past it.`) and `trauma_echo`
  source show that thoughtful authoring of semantic structure (rough→precise
  reframe; somatic intrusion phenomenology) produces qualitatively better output
  than generic subject/predicate pools — suggesting that *what* is authored matters
  far more than the selection mechanism.

**The gap existence exposes for aeriea**: existence's ceiling is set by the
author's pre-written fragments. Every output is a recombination of fragments that
were typed by hand into `LEX`. The prose-generation moonshot in
`docs/decisions/prose-generation.md` targets outputs superior to handwritten
prose — which means the ceiling of a slot-substitution system like existence's
*is the problem to solve*, not a solution. Existence is honest evidence that
NT-weighted slot-substitution does not reach that bar. A build-time learned
component (as `prose-generation.md` contemplates) is not a nice-to-have; it
is the only known path to novelty and lexical variety beyond what any one author
can enumerate by hand.
