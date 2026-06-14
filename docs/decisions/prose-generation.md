# Deterministic prose generation — output that beats handwritten and LLM

Status: **FOUNDATIONAL R&D DIRECTION — open problem, not a frozen spec** (2026-06-14)

Scope: this doc deepens the *language-output* (NLG) half of the
`npc-mind-and-language.md` spine — the side that doc explicitly left open (its
*Open threads*, "the generator's concrete approach … the realization grammar …
which components are build-time-learned"). The project is pivoting toward
text-based systemic gameplay, and this records the design *direction* for the
prose-OUTPUT engine: the realizer that turns systemic state plus communicative
intent into rendered prose. It does **not** cover the player-INPUT half (the
composable social/physical affordances, designed in `affordance-substrate.md`) —
that substrate is the input vocabulary and is out of scope here. It states the
superiority target, names a previously-missing prose *quality bar*, sketches a
generator architecture, designs the semantic-layer→NLG interface, walks one
concrete example, and reconciles the whole pipeline with the determinism
invariant. It is a design doc only: it contains **no engine code**, and the
sandbox entrypoint `scripts/text_sandbox.gd` is untouched. It does **not**
contradict the spine — it lowers one of the spine's open seams toward a
buildable shape, while keeping every genuinely-open sub-problem marked open.

---

## Why this exists

The pivot is to text-based systemic gameplay. The output target is concrete and
hard: a **deterministic prose-OUTPUT engine whose rendered text is superior both
to handwritten prose** (Fenoxo's *Trials in Tainted Space*, Innoxia's *Lilith's
Throne*) **and to LLM prose** — produced with **no hot-loop LLM**. Inference is
permitted only at build time / at the leaves; an LLM may never be an excuse to
skip building a subsystem.

Two scope corrections, stated plainly so this doc does not drift into the
neighbouring pillars:

- **INPUT is out of scope.** The player's half of an interaction — composable
  social verbs and physical affordances, with guards that read brain state and
  effects that mutate it — is the already-designed semantic affordance
  substrate (`affordance-substrate.md`). This doc does not redesign it; it
  consumes the *resulting* systemic state.
- **OUTPUT is the target.** The NLG realizer — `systemic state + communicative
  intent → prose` — is what this doc is about. In the spine's vocabulary, this
  is the **text/NLG channel** (`npc-mind-and-language.md` → *Realization
  channels*): one realizer among several, here examined in depth.

This is a design doc. There is no engine code here, and `scripts/text_sandbox.gd`
is not touched. What this deepens is the NLG side that `npc-mind-and-language.md`
deliberately left open (its *Open threads*: "The semantic-representation
formalism for communicative intent, the realization grammar, and which
components are build-time-learned (vs hand-built / procedural) are open"). The
spine — brain → communicative intent → multi-channel realization, with text as
one channel and the whole chain a deterministic function of `seed + event log` —
stands. This doc operates strictly inside that frame.

---

## The superiority thesis (why both rivals lose)

"Superior" is not a single axis. It is a **four-way product**:

> **faithfulness-to-true-rich-state × quality-phrasing × determinism × freshness.**

Neither rival hits all four — each is missing at least one factor, and a product
with a zero factor is zero. Aeriea's claim is to be nonzero on all four at once,
which is a position neither rival can occupy.

- **Handwritten loses on COVERAGE.** Authors write for the states they
  *anticipate*. But the true systemic state space — every body detail, fluid,
  position, mood, relationship-history value, sensory specific the sim holds — is
  combinatorial and vastly exceeds what any author can enumerate. So handwritten
  prose is high-quality *per instance* where the author reached, and at the edges
  it degrades to a **generic fallback** or to **mad-libs slot-substitution** (a
  canned line with the variable bits poked in). It is excellent and *not faithful
  to arbitrary rich state*: where the author did not anticipate the state, the
  prose stops describing the real state. (This is the same diagnosis
  `reference-analysis.md` makes of TiTS/FS — content-deep, then thin at the
  combinatorial edges.)

- **LLM loses on GROUND TRUTH + DETERMINISM.** An LLM is fluent, but it does not
  *know* the true systemic state — it sees a context window and **confabulates
  beyond it**, drifts across a long scene, and contradicts established facts
  (a fluid it forgot, a body part it mis-described, a relationship beat it never
  saw). It is also non-replayable: the same `seed + event log` does not yield the
  same text, so it cannot live in a seeded sim. LLM prose is *plausible, not
  true*, and *not reproducible*.

- **Aeriea wins by holding all four.** The simulation already holds the **full
  true systemic state as ground truth** — every body detail, fluid, position,
  mood, relationship history, sensory specific. The NLG renders *that* state
  (faithfulness: it can describe the actual rich state, not a generic fallback),
  with **build-time-corpus quality phrasing** (quality), **deterministically**
  (seed + event log → bit-for-bit replay), and **freshly** (state-driven and
  non-repeating across equivalent situations). The superiority is the *product*:
  faithful AND high-quality AND deterministic AND fresh — a combination
  unavailable to either rival, because each rival is structurally missing a
  factor (the author cannot cover the combinatorial state; the LLM cannot be
  faithful-and-deterministic).

A precision note against over-claiming from the reference work: `reference-
analysis.md` establishes that dense composable *procedural recombination*
delivers **volume and variety** without LLMs (LT's act×target×position×body-state
combinatorial space). It does **not** claim recombination beats handwritten on
*quality*. This doc's harder, unproven claim — beating handwritten on *quality*,
not merely on coverage/volume — is exactly the moonshot, and it is marked as such
throughout (see *Risks*).

---

## The prose quality bar

`npc-mind-and-language.md` mandates "real grammar + semantics" and rules out the
copouts, but it never *defines* "superior" prose operationally. This is that
missing spec. "Superior" is defined along five axes, each with a crisp
operational definition and a **build-time** measurement. These five are the gates
the eval harness checks (see *Generator architecture → 5*).

- **Faithfulness** — every asserted detail is true of the state; **zero
  confabulation**. *Measured:* assert→state-fact provenance check. Every rendered
  claim must trace to a state proposition that was true at render time; any clause
  with no backing proposition is a faithfulness failure. This is the axis the LLM
  structurally fails.

- **Specificity** — the prose renders the *actual rich state* (the specific body /
  fluid / arousal / position / relationship facts), not a generic fallback.
  *Measured:* a specificity score — how much of the salient available state the
  rendered text actually surfaced, versus collapsing to boilerplate. This is the
  axis handwritten fails at the combinatorial edges.

- **Coherence** — register and affect are consistent with the brain's
  communicative intent. *Measured:* the register/affect tags recoverable from the
  output match the intent's register/affect tags. (Tender intent must not render
  as clinical or crude prose, and vice versa.)

- **Freshness** — non-repeating across equivalent situations. *Measured:* n-gram /
  phrasing diversity across repeated invocations on similar state — the same
  situation must not read identically twice. This is the anti-grind axis (the
  `reference-analysis.md` "samey/grindy" complaint, answered at the prose layer).

- **Determinism** — seeded replay is bit-for-bit. *Measured:* golden-trace
  equality — the same `(intent, brain state, seed)` renders the same bytes.

**Validation is BUILD-TIME ONLY — never runtime.** The harness is golden traces
plus a **build-time judge** (human and/or an offline LLM evaluated at build time)
scoring rendered output against handwritten exemplars on the five axes. An
offline LLM used as a build-time judge is *permitted* by the leaf / build-time
principle ("the LLM is an oracle at the leaves, never the control loop") — it is
exactly the sanctioned build-time-inference position. A **runtime judge would be
a hot-loop LLM and is forbidden**. The quality bar is a build-time gate on the
shipped deterministic artifact, not a thing consulted while the game runs.

---

## Generator architecture

The realizer is a pipeline. Each genuinely-open sub-problem is marked **OPEN**.
The two copouts are forbidden here, restated for the avoidance of doubt:

> **No template mad-libs** — a label that maps 1:1 to a canned line with slots is
> string substitution, not generation, and cannot carry the brain's nuance.
> **No per-query / hot-loop LLM** — forbidden by the ecosystem principle and a
> determinism violation; it offloads the hard problem to an online black box.
>
> (Both restated verbatim in spirit from `npc-mind-and-language.md` → *every
> honest approach is first-class — no copouts*.)

### 1. Content determination + salience

Decide **what to say**: from the full systemic state, select which facts are
worth uttering — those that are **novel** (changed since last described),
**intense** (high arousal / strong affect / extreme value), or **relevant to the
current communicative intent** (the propositional content the intent references).

This stage is *simultaneously* two engines:

- the **faithfulness engine** — only state-true propositions enter the selection,
  so nothing downstream can assert what is not in the state; and
- the **anti-repetition engine** — by describing *change and intensity* rather
  than re-describing the static scene every tick, it structurally avoids
  boilerplate. (If nothing salient changed, the right output is often *less*
  prose, not a re-statement.)

**OPEN:** the salience function and the novelty model — how "changed since last
described," "intense," and "relevant to intent" are scored and combined, and how
the per-tick salience budget interacts with the semantic LOD budget (below).

### 2. Semantic-grounded realization grammar

Turn the selected, typed propositions about state into surface forms via a
**compositional grammar** whose fragments come from a build-time-generated /
curated corpus. The governing motto is **"generalize, don't multiply"**: a
*modest* set of rules applied to *rich* state yields combinatorial surface
variety — the same virtue `reference-analysis.md` credits to LT's sex engine,
where "a modest primitive vocabulary (act × target × position × body-state)
yields a combinatorial space." We carry that precedent from the *interaction*
graph to the *prose* surface.

Lexical choice is **body/fluid/arousal/register-aware**: which word realizes a
given concept is driven by the semantic graph's **prevalence weights** (toward
typical phrasing) and pulled by the **intent's affect/register** (toward marked
or atypical choices when the affect warrants — tender vs crude vs clinical for
the same underlying act). The phrasing is *meaning about the world turned into
words*, with that meaning drawn from the semantic layer (`semantic-layer.md` →
"The NLG speaks from it").

**OPEN:** the grammar formalism itself — what the rule and fragment
representation is, how composition is typed, how lexical-choice weighting is
expressed.

### 3. Build-time-trained deterministic realizer surrogate

Rule-grammars can read **stiff** — correct but wooden. For where they do, the
design permits a **fixed-weight, offline-trained, seeded-deterministic-eval
realizer**. This is **licensed** by `npc-mind-and-language.md`'s permitted
build-time-trained realizer: "A fixed-weight learned realizer — trained offline,
evaluated deterministically at runtime — is not a hot-loop LLM and is compatible
with the build-time-inference / deterministic-hot-loop principle precisely
because it is deterministic." It is the *same precedent* as the trained soft-body
surrogate (TODO.md body/animation backlog; `DESIGN.md` → *Secondary / soft-body
physics*): offline accuracy lowered to a deterministic runtime surrogate — the
"beyond-SOTA yet deterministic" shape. This is what rivals **LLM fluency without
a hot-loop LLM**.

**OPEN:** the trained-vs-rule split (which work the grammar keeps vs the surrogate
takes — e.g. surrogate for clause smoothing / cohesion over a grammar-fixed
propositional skeleton, vs surrogate for full realization); and the corpus +
training strategy.

### 4. Seeded variation / anti-repetition

The realizer must be **deterministic yet non-repeating**. The mechanism: a
function of `seed + state-hash` selects among the *equivalent* realizations of the
same selected content — so the same situation **never reads identically twice**,
yet **replays bit-for-bit** on the same seed and log. Determinism and freshness
are not in tension: the variation is itself a deterministic, seeded selection.
This ties directly to the determinism invariant (below) — the seed that
reproduces the run also reproduces the "random" phrasing choice.

### 5. The prose quality bar + build-time eval methodology

The quality bar is defined in *The prose quality bar* above; this stage is the
**eval harness** that enforces it. It runs at build time only: **golden traces**
(for the determinism gate) plus a **build-time judge** (human and/or offline LLM)
scoring rendered output against **handwritten exemplars** on the five axes —
faithfulness, specificity, coherence, freshness, determinism — used as **gates**
on the shipped artifact. No runtime evaluation; a runtime judge would be a
hot-loop LLM and is forbidden.

**OPEN:** the eval methodology specifics — exemplar selection, how the five axes
are scored and thresholded, how the judge's taste is calibrated and audited.

### The interface

The realizer's runtime interface is: `(communicative intent, brain state, seed,
salient state) → prose`, where *salient state* is the output of stage 1 over the
sim's true systemic state, and *communicative intent* is the spine's tuple
(speech-act type + propositional content + stance/affect + register + memory
references). The output is a string; the *contract* is the five-axis quality bar.

---

## Semantic-layer → NLG interface

`semantic-layer.md` *asserts* "The NLG speaks from it" but never mechanizes the
seam. This section designs that interface — the two concrete couplings — while
leaving the query API open.

- **Concept → typical-phrasing, via prevalence weights.** The semantic graph
  carries each association's *typicality* (apple→red typical, green common,
  yellow less so). The realizer's lexical choice **reads those weights**: by
  default it phrases toward the *typical* association (the unmarked, natural-
  reading word), but the **intent's affect/register can pull toward marked /
  atypical** choices when the communicative intent warrants it (deliberately
  unusual phrasing for emphasis, tenderness, crudeness, formality). This is how
  "meaning about the world" becomes *the right words* rather than *any* words —
  the prevalence weights are the prose's sense of what reads naturally.

- **Semantic LOD → utterance specificity.** The semantic layer's foveated
  reasoning ("mipmaps for meaning") maps directly to *how specific the rendered
  utterance is*. The **focal** NPC/object — the one the player is attending to —
  earns fine detail and specific prose; **peripheral** things get coarse mention.
  Crucially, the layer's **faithful-coarsening spine carries into prose**: a
  coarse mention must be a **true summary of the fine** detail — so a *glance*
  and an *inspection* never contradict **in the prose either**. No "popping" at
  the language layer: leaning in reveals *more* specific text, never *different*
  (contradictory) text. This is the `semantic-layer.md` mipmap property
  (faithful coarsening, seed-stable, no popping) owed by the prose surface.

**OPEN:** the concrete query / traversal API over the weighted graph — how the
realizer asks the graph for "the typical phrasing of this concept at this LOD,
pulled by this affect/register," and how the LOD budget is passed and honored.

---

## Worked example

A single trace, to show faithfulness (every phrase traces to a state fact) and
freshness (a second invocation on near-identical state seeds a *different
equivalent* realization). Embodied/NSFW-capable in spirit, kept tasteful and
illustrative.

**Systemic state (structured fields, the sim's ground truth):**

```
actor:        Maren
  arousal:        0.72        (high, rising)
  warmth_to:      { player: 0.81 }   (relationship: high, trusting)
  posture:        leaning_in
  contact:        { hand_on: player.forearm }
  recent_change:  arousal +0.18 since last described   (NOVEL, INTENSE)
scene:
  proximity:      close
  prior_beat:     player_complimented_her   (memory ref, 2 ticks ago)
```

**Communicative intent (the spine's tuple):**

```
speech_act:        confide
propositional:     { wants_closeness(self, player), feels_safe_with(self, player) }
stance/affect:     tender, slightly_bashful
register:          intimate, informal
memory_refs:       [ player_complimented_her ]
```

**Salience pick (stage 1):** of the available state, the salient facts are
`arousal +0.18 (novel, intense)`, `hand_on forearm (contact, relevant to
confide/closeness)`, and the `player_complimented_her` memory ref the intent
points at. The static facts (`proximity: close`) are *not* re-described — they
were described already, so re-stating them would be boilerplate; salience omits
them. This is the anti-repetition engine and the faithfulness engine acting at
once.

**Realization A** (seed `s1`):

> *Her hand stays on your forearm a beat longer than it needs to.*
> ¹  *"That thing you said earlier—"*² *she starts, and doesn't finish, color
> climbing her face.*³

- ¹ → `contact.hand_on: player.forearm` (faithful: stated contact)
- ² → `memory_refs: [player_complimented_her]` + `speech_act: confide` (referencing the prior beat, half-said)
- ³ → `affect: bashful` + `arousal +0.18` rendered as *color climbing* (faithful: rising-affect/arousal change, tender register)

**Realization B** (seed `s2`, near-identical state):

> *The pressure of her fingers on your arm shifts, and she leans a little nearer.*¹·⁴
> *"I keep thinking about earlier,"*² *she admits, quieter than before.*³

- ¹ → `contact.hand_on: player.forearm`
- ⁴ → `posture: leaning_in` / `proximity: close` (here surfaced as the *change* "leans nearer")
- ² → `memory_refs: [player_complimented_her]` + `speech_act: confide`
- ³ → `affect: tender, bashful` + `register: intimate` ("admits, quieter")

Both are **faithful** (every clause traces to a state proposition; neither
asserts anything the state does not hold — no confabulated detail), both carry
the **same intent** (confide / tender / intimate), and they are **fresh** (the
seed + state-hash selected two different equivalent realizations of the same
salient content). On the same seed, each replays byte-for-byte.

---

## Reconciliation with the determinism invariant

The whole pipeline is a **deterministic function of `(intent, brain state,
seed)`** — exactly the contract `npc-mind-and-language.md` sets for every
realizer. And the intent is itself a deterministic function of `seed + event
log` (the brain). Therefore the chain — brain → intent → salience → grammar /
realization → seeded variation → prose — **replays bit-for-bit** on one runtime,
under the **same cross-platform-float caveat** the movement and affordance
substrates carry.

The **build-time-trained realizer surrogate is deterministic-eval**, so it is
compatible with the determinism invariant — this is the *explicit permission*
`npc-mind-and-language.md` grants ("a fixed-weight learned realizer … is not a
hot-loop LLM … compatible … precisely because it is deterministic"), the same
reasoning that licenses the trained soft-body net. The seeded-variation stage's
"randomness" is a deterministic function of `seed + state-hash`, so freshness
does not break replay.

The **only** LLM use anywhere in this design is **offline / at the leaves**:
corpus generation/curation for the grammar and surrogate (build time), and the
build-time judge in the eval harness (build time). **Neither is the hot loop.**
There is no per-query inference at runtime — that remains forbidden.

---

## Risks

This is the R&D frontier, **not claimed solved**. Honest risks:

- **The trained surrogate may not actually beat LLM fluency.** A fixed-weight,
  deterministic-eval model trained on a buildable corpus might land below
  large-online-model fluency. The "beyond-SOTA yet deterministic" shape is a
  *bet*, not a guarantee.
- **The grammar may read stiff, and the corpus may be hard to build.** Compositional
  grammars are notorious for wooden output; the curated/generated corpus that
  feeds both grammar and surrogate is itself a large, unscoped build-time effort.
- **The build-time judge (if LLM) inherits LLM taste and bias.** An offline-LLM
  judge brings the same taste distortions it would as a generator; calibrating
  and auditing it against human exemplars is unsolved.
- **The quality-bar metrics may be gameable.** Specificity and freshness scores,
  in particular, can be satisfied by superficial tricks (padding detail, shuffling
  synonyms) that do not actually read better; the gates need anti-gaming care.
- **Combinatorial salience may explode.** Scoring novelty × intensity × relevance
  over rich state, per tick, within an LOD budget, is a hard real-time problem;
  naive salience could be too expensive or too noisy.
- **Faithful-coarsening in prose is hard to guarantee.** Ensuring a coarse mention
  is *always* a true summary of the fine detail — never a contradicting one — is
  harder in language than in a numeric mipmap; prose "popping" is a real risk.
- **"Beats handwritten on quality" is the unproven moonshot.** Coverage/volume
  superiority follows from composition (`reference-analysis.md`). *Quality*
  superiority over a skilled human author does not follow from anything proven
  here. This is the frontier claim, and it is confronted as such — owned, not
  designed away.

---

## Open threads (explicitly unsolved)

- **The realization-grammar formalism** — the rule/fragment representation, typing
  of composition, lexical-choice weighting.
- **The trained-vs-rule split** — which realization work the grammar keeps and
  which the build-time-trained surrogate takes.
- **The corpus + training strategy** — how the build-time corpus is generated /
  curated, and how the surrogate is trained against it.
- **The eval methodology** — exemplar selection, scoring and thresholding of the
  five axes, judge calibration and auditing.
- **The concrete semantic-graph query / traversal API** — how the realizer queries
  the prevalence-weighted graph for typical phrasing at an LOD, pulled by
  affect/register.
- **The salience / novelty function** — how novelty, intensity, and intent-relevance
  are scored and combined within the per-tick LOD budget.

These are unsolved. The architecture is a *direction*, not an implementation.

---

## Cross-links

- `docs/decisions/npc-mind-and-language.md` — **the spine.** This doc deepens its
  open NLG side (its *Open threads* → "the generator's concrete approach … the
  realization grammar … which components are build-time-learned"); it consumes the
  spine's communicative-intent tuple and inherits its determinism line and its
  permitted build-time-trained realizer. → *The spine*, *Determinism & the LLM
  line*.
- `docs/decisions/semantic-layer.md` — **what the NLG speaks from.** This doc
  mechanizes the asserted seam: prevalence weights → typical phrasing, and
  semantic LOD → utterance specificity (carrying the faithful-coarsening / no-
  popping spine into prose). → *It is the layer under the others*, *Semantic LOD*.
- `docs/decisions/affordance-substrate.md` — **the INPUT half, out of scope here.**
  The composable social/physical verbs are the player's input vocabulary; this
  doc is the OUTPUT/NLG half that renders the resulting systemic state.
- `docs/decisions/reference-analysis.md` — **the rivals and the recombination
  precedent.** Supplies the handwritten exemplars to beat (TiTS, LT) and the
  "generalize, don't multiply" act×target×position×body-state precedent the
  grammar carries from interaction to prose. Note: it credits recombination with
  *volume/variety*, not *quality* — this doc's quality claim is the harder,
  unproven one.
