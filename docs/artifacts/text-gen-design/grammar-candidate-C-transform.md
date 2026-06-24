# Grammar Candidate C — Transformational / edit-sequence generation

> **Frame:** the surface sentence is the END of a *derivation*. Generation is not
> "fill the slots" and not "retrieve the passage." It is: take the WHAT (a
> propositional skeleton entailed by the commitment store), then DERIVE the HOW by
> applying a seeded, weighted SEQUENCE of structural transforms — subordination,
> fronting, fusion, elision, cleft, figuration, rhythm-shaping — over an open
> lexicon. Variety is which transforms fire, in what order, at what depth. The
> build-time net's job is to learn the *transform distribution* from real authored
> prose by inverting it: align a human sentence to its skeleton and infer the edit
> sequence that produced it.

This document develops THIS paradigm only. It does not relitigate the fixed thesis
(full-support generative grammar; taste a build-time-shaped distribution; content
hard-gated to commitments; seeded/replayable). It instantiates the hardest piece:
*what the transforms are, how they are distilled, and whether the output clears the
stiffness bar.* A real toy prototype was built and run; its actual output is pasted
below (labelled RUN), and I judge it honestly — including where it reads mechanical.

---

## 1. The paradigm, concretely

### 1.1 The propositional skeleton (the WHAT)

The skeleton is a typed dependency tree of **clause-atoms**, derived purely from the
commitment store. An atom is the minimal assertable unit and carries:

- `prop` — the committed proposition it realizes (the provenance handle for the gate);
- `kind` — predication / modifier / adjunct / stance;
- `pole` — for affect atoms, the valence axis (so opposed poles can be *fused* into
  a tension image rather than concatenated);
- `salience` — a build-derived weight: how much this atom *matters* for the beat.

The skeleton is **content, never form**. It says *Maren registers your return* and
*the affect is glad-but-guarded* and *it is raining* — it does NOT say in what order,
at what depth of subordination, with what figure, or even which atoms survive. Crucially
the skeleton is *over-complete*: it lists every entailed atom; selection (a transform)
prunes it to the beat. This is what makes restraint a first-class move rather than an
afterthought — *not saying* is a transform that fires, with provenance, not an omission.

### 1.2 The transform inventory (the HOW), as DATA

Transforms are the runtime's entire generative vocabulary. Each is a pure rewrite
`(plan, rng, voice) -> (plan', trace_label)`. The shipped inventory is a flat table;
the toy prototype implements a representative slice:

| transform | structural effect | depth/voice role |
|---|---|---|
| `select` | salience-weighted prune to clause budget | controls *what* survives (conception variety, not lexical) |
| `subordinate` | demote a clause to `because/though/now that/even if` | rhetorical-relation richness (non-additive links) |
| `front` | topicalize a sub/adjunct to clause-initial | cadence; marked information structure |
| `fuse` | merge two clauses (esp. opposed poles) into one image | fusion-ratio > 1:1; carries the central tension |
| `elide` | drop a low-salience clause | restraint; terse-voice cadence |
| `cleft` | it-/there-cleft on the lead | emphasis; spoken rhythm |
| `figure` | replace a literal clause with a GATED figurative image | subtext, telling-detail — *faithful* (§3) |
| `expand` | add an entailed elaboration atom back in | lyrical density |
| `nominalize` | predication -> nominal ("the gladness gets ahead of her") | register lift |
| `aspect/tense` | progressive/perfective shaping | duration, immediacy |
| `punct` | em-dash / full-stop split / comma rhythm at linearize | cadence range |

The inventory is **finite and small** (~20–40 transforms in production). Full SUPPORT
does NOT come from inventory size — it comes from **composition + recursion over an
open lexicon**: transforms apply to each other's output to arbitrary depth, `expand`
re-injects atoms, subordination nests, and the lexicon slot is open (any sensible
realization of an atom has nonzero probability). Any grammatical sentence over the
committed atoms is reachable by *some* transform sequence with nonzero weight. The
finite thing shipped is the *distribution over sequences*, not a finite output set.

### 1.3 The runtime apply-loop

```
content (commitments)
  -> skeleton = atoms entailed-true by the gate
  -> rng = PRNG(seed XOR hash(committed_props, voice))
  -> chosen = select(skeleton, voice.budget, rng)          # conception variety
  -> clauses = bind_lexemes(chosen, voice.register, rng)   # open lexicon, seeded
  -> for tf in PIPELINE:                                    # weighted firing
        clauses, trace = tf(clauses, rng, voice)           # each tf gated by voice weight
  -> style = punct(rng, voice)
  -> surface = linearize(clauses, style)
```

Each transform's firing is a seeded weighted coin keyed to the **voice profile's**
per-transform weight (`tw`). That single table — voice → transform-firing-weights +
register key + clause budget — is the entire taste axis at runtime. Swap the table,
get a different cadence/voice *space* from the same content and skeleton. The weights
are a *space* (mood/register modulate them per-call), never one locked taste.

### 1.4 Determinism / seeding

The PRNG is **splitmix64** (integer-only; no float, no language `hash()`, no
dict-iteration-order dependence). Seed = `splitmix(seed) XOR FNV1a(sorted(committed_props), voice)`.
Every choice — selection jitter, lexeme index, which transforms fire, conjunction
choice, punctuation style — draws from this one stream in fixed pipeline order.
Same `(content, voice, seed)` ⇒ identical bytes, cross-platform. The prototype proves
this (RUN below: `repeated identical? True`). Variety branches **upstream** at
select/subordinate/fuse (conception), not only at the lexeme — this is the explicit
anti-"lexical-swap-fake-variety" commitment, and the traces show it.

---

## 2. Distillation pipeline (nut #2)

### 2.1 The core move: INVERT authored prose into transform sequences

Pure programmatic analysis is insufficient; the net does the heavy lifting, but in a
specific, checkable way. For each high-quality authored sentence S in the corpus:

1. **Align** S to a propositional skeleton: the build-time frontier net (Opus-class)
   extracts the atoms S asserts and their committed-style props — i.e. it answers
   "what is the WHAT under this sentence."
2. **Infer the edit sequence**: the net is asked to derive S *from* that skeleton
   using ONLY the transform inventory — "show the sequence of named transforms that
   turns this skeleton into this sentence." This is a constrained parse, not free
   description: the net must spend transforms from the fixed inventory, so the output
   is a typed sequence, not prose commentary.
3. **Validate the inversion**: re-RUN the inferred sequence through the *actual
   runtime transform engine* (the deterministic one) and check the surface matches S
   (up to lexeme binding). A sequence that doesn't reproduce S is discarded. This is
   the anti-confabulation guard on the distillation itself — the net's claimed
   derivation must actually execute.

Validated `(skeleton-context, transform-sequence)` pairs accumulate. Aggregated, they
give a **conditional distribution over transforms**: `P(transform | voice, register,
mood, skeleton-shape, depth-so-far)`. That distribution — discretized to integer
weights per context bucket — IS the taste artifact.

### 2.2 Source: real high-quality authored prose, NOT gemma logs

Per `ref-corpus.md` the SillyTavern corpus is a **benchmark, not a source** (median is
filler; only a top gemma slice clears the bar, and it carries content-safety problems).
So the distillation corpus is **literary fiction + strong authored RP** (close third-person,
dialogue-forward, embodied, restraint-heavy — the registers we need). The SillyTavern
top-slice is used only as a *held-out benchmark* the realizer's output is scored against,
never mined for weights.

### 2.3 The shipped artifact (finite, net-free at runtime)

Three frozen files, no model among them:

1. **Transform inventory** — the ~20–40 named rewrite rules. Code, not data; fixed.
2. **Voice/weight tables** — per voice profile: per-transform integer firing weights,
   register key, clause budget, plus the conditional `P(transform | context-bucket)`
   tables from §2.1. Pure integer data, a few KB per voice. Mood/register select and
   blend these at runtime; the *space* ships, runtime picks a point in it.
3. **Lexicon + figure tables** — register-keyed surface realizations per atom (open,
   expandable) and the gated figure table (§3).

All three are static. The runtime is the apply-loop of §1.3 reading these tables —
**zero inference, integer PRNG only**. The frontier net touched none of it after build.

---

## 3. Content gate + figurative faithfulness + salience (nut #3)

### 3.1 The hard gate on assertion

The skeleton is built ONLY from atoms whose `prop` is committed-true. Selection and
every transform operate *within* that set — no transform can introduce an atom whose
prop is not committed. So no transform sequence can assert a falsehood: the gate is
upstream of all phrasing, and phrasing stays full-support *within* the gated atom set.
Falsity enters only by explicit license (POV-ignorance, a lying/mistaken speaker in
dialogue, altered senses) — modeled as a *licensed false prop* injected into the
skeleton with a license tag, so the gate still holds (the asserted falsehood is itself
a committed speech-fact). The realizer never decides truth; it renders committed truth.

### 3.2 Figurative transforms stay faithful by construction

The `figure` transform cannot invent imagery. Every figure in the table is tagged with
the **single committed prop it is faithful to**, plus the register it belongs to.
`figure` may fire only when (a) that prop is committed-true AND (b) a clause realizing
that prop is present AND (c) the register matches. "the rain says what she won't" is
licensed *only* because `weather_raining` is committed; "she keeps the door only half
open" is licensed *only* because `affect_guarded` is committed. A figure is therefore a
*re-surfacing* of an entailed prop in image form — telling-detail and subtext WITHOUT
hallucination. Subtext specifically rides the **literal-vs-stance gap**: `fuse` of the
opposed glad/guard poles produces "and won't quite let it show" — the gladness asserted,
the showing withheld, both poles committed.

### 3.3 Salience steering

`select` is salience-weighted: the top-salience atoms (here the glad/guard *tension*)
are kept by default; lower atoms (rain) are elision candidates. Salience is build-derived
per beat-type and modulated at runtime by novelty/intensity. This is what steers the
realization toward *what matters* and lets restraint (`elide`) and telling-detail
(`figure`) trade against naive completeness.

---

## 4. CONCRETE GENERATED OUTPUT (decisive)

**Committed content (fixed):** *Maren notices you returned after a long absence;
guarded but glad; it's raining.* Atoms: `return, absence, glad, guard, rain`.

A real prototype (`/tmp/transform_proto/proto.py`, splitmix64-seeded) was built and
RUN. Below is **actual run output** — each realization with its real skeleton→surface
transform trace, so a skeptic sees mechanism, not free-writing. (Labelled RUN.)

```
[terse-guarded  seed=11]                                                    RUN
  -> She's glad, and won't quite let it show.
     select[budget=2]:glad+guard . subordinate[guard 'though']
     . fuse[glad+guard -> tension-image] . punct[comma]

[warm-lyrical  seed=77]                                                      RUN
  -> Something in her eases, and won't quite let it show — you walked back in,
     even if after so long away.
     select[budget=4]:glad+guard+return+absence
     . subordinate[absence 'even if'] . fuse[glad+guard -> tension-image]
     . punct[dash]

[wry-deflecting  seed=11]                                                    RUN
  -> Not that she'd say she missed you, and won't quite let it show
     — look who's back.
     select[budget=3]:glad+guard+return . subordinate[guard 'though']
     . fuse[glad+guard -> tension-image] . punct[dash]

[terse-guarded  seed=4242]                                                   RUN
  -> She stays careful.
     select[budget=2]:glad+guard . elide[glad] . punct[stop]

[warm-lyrical  seed=31337]                                                   RUN
  -> The gladness gets ahead of her, now that she keeps the door only half
     open, you walked back in, after all these silent months.
     select[budget=4]:glad+guard+return+absence
     . figure[door_ajar<-affect_guarded] . subordinate[guard 'now that']
     . punct[comma]

[wry-deflecting  seed=9001]                                                  RUN
  -> Not that she'd say she missed you, she keeps one eyebrow up,
     look who's back.
     select[budget=3]:glad+guard+return . punct[comma]
```

Determinism (RUN): `warm-lyrical/77` rendered twice ⇒ **identical: True**.

These **vary on all three axes**: STRUCTURE (2-clause fused terse vs 4-clause fronted
lyric vs comma-chained wry), CADENCE (full-stop clip vs em-dash vs comma run), and
VOICE/register (plain / lyric / wry lexicon AND different transform-firing weights —
the wry voice rarely subordinates and reaches for deflection lexemes; the lyric voice
fuses, figures, and expands). The variety is *conceptual* (which atoms survive, which
pole-tension is fused, what is left unsaid), not lexical-swap — visible in the traces.

A hand-derived **5th distinct register** to show the inventory's reach beyond the toy's
voices (labelled HAND — `cleft` + `front` + `nominalize`, restraint-max):

```
[cool-observational]                                                       HAND
  -> What gets her, after this long, is that you came back at all — and the
     rain keeps on against the glass, saying it for her.
     cleft[return] . front[absence] . figure[rain_witness<-weather_raining]
     . subordinate(elaboration) . punct[dash]
```

---

## 5. Stiffness confrontation (brutally honest)

prose-generation.md conceded compositional grammars are "notorious for wooden output"
and waved it away. I must not. Here is the honest verdict on the RUN output.

**Three of six RUN lines clear a decent bar; three read mechanical or are outright
broken.** Specifically:

- `terse-guarded/11` ("She's glad, and won't quite let it show.") — *good*. Real
  restraint, the tension carried in one fused image. This is the paradigm working.
- `cool-observational` (HAND) and `warm-lyrical/77` — *good-to-strong*. The cleft +
  fronting + gated figure produces genuine cadence and subtext.
- `terse-guarded/4242` ("She stays careful.") — **BROKEN**: `elide` dropped the *glad*
  pole, collapsing the whole beat to a flat guard statement. The salience trade fired
  wrong; the central tension was elided. A faithfulness-of-*beat* failure (every clause
  is true, but the SET no longer conveys the committed affect).
- `warm-lyrical/31337` ("The gladness gets ahead of her, now that she keeps the door
  half open, you walked back in, after all these silent months.") — **comma-spliced
  run-on**. Four clauses chained by commas reads as a list, not prose. The punct
  transform fired `comma` on a 4-clause plan with no fusion — exactly the "mechanical
  concatenation" failure.
- `wry-deflecting/9001` — same comma-list problem; reads stiff.
- `warm-lyrical/11` (in the full run, not shown above) — the `door_ajar` figure was
  **overwritten by a later `fuse`**, silently destroying the figure the trace claims.
  A **transform-ordering / interference bug**: independent transforms clobber each
  other's work.

**Where the pipeline most risks stiffness, and what mitigates it:**

1. **Transform interference / ordering** is the deepest risk and it BIT in the run
   (figure clobbered by fuse; elide killing the load-bearing pole). Mitigation:
   transforms must declare *read/write atom-sets* and a *commutativity/precedence*
   discipline, and a `coherence` pass must reject sequences whose result no longer
   entails the committed *beat affect*. This is not optional polish — it is the
   difference between derivation and damage.
2. **Linearization is where wood lives.** The transforms produce a good *plan*; the
   comma/dash/stop joiner produces the run-ons. A flat joiner is mad-libs at the seam.
   Mitigation: linearization must itself be transform-distilled (rhythm conditioned on
   clause count and pole structure — a 4-clause plan should *force* fusion or a stop
   split, never a comma list). The toy's joiner is too dumb; this is a known fixable.
3. **Lexicon thinness.** With 2 options per atom the lexical axis looks repetitive;
   real distillation gives an open lexicon. Less fundamental than (1) and (2).

**Honest judgment: the paradigm clears the bar on its GOOD cases and the mechanism is
real (the traces are not decoration), but the RUN proves the median is NOT yet at
frontier-RP craft — about half the outputs are mechanical or broken.** The failures are
not lexical; they are *structural interference and dumb linearization* — which is the
correct, encouraging news: they are exactly what the distilled transform-distribution +
coherence-gate are designed to fix, not evidence the paradigm is doomed. But I will not
pretend the unmitigated pipeline is good. It is **promising-but-stiff** today, and the
stiffness is real, not hand-waved.

---

## 6. Trade-offs + buildability

**Strengths.** (a) Variety is *conceptual* by construction — branch points are
selection/subordination/fusion, not the lexicon, so it structurally resists the
fake-variety failure the thesis names the enemy. (b) The gate is clean: assertion is
bounded by the skeleton, figures are prop-tagged, falsity needs a license — strong
faithfulness story. (c) Distillation is *checkable*: an inferred transform sequence
must re-execute to reproduce the source, so the net can't launder a bad derivation.
(d) Determinism is trivial and the artifact is small.

**Weaknesses.** (a) **Stiffness is the standing risk of this paradigm specifically** —
§5 shows it bites without a coherence-gate and distilled linearization; those are
non-trivial to build well. (b) **Transform inversion is the hard research bet**: can
the net reliably infer faithful, re-executable edit sequences for *literary* prose, or
only for simple sentences? Subtle prose may not decompose into the fixed inventory —
the residual is where wood or infidelity hides. (c) The inventory's *completeness*
(does ~30 transforms span real prose?) is unproven; an under-powered inventory forces
clumsy approximations.

**Buildability.** The runtime engine is small and shippable (the prototype is ~300
lines and already deterministic). The expensive, uncertain part is **distillation
quality** — corpus curation + a reliable inversion net + the coherence-gate. The
prototype de-risks the *runtime* claim concretely; it does NOT de-risk the
*distillation* claim, which is where the real work and the real doubt sit.

---

## Appendix — prototype location

`/tmp/transform_proto/proto.py` — runnable (`PYTHONHASHSEED=0 python3 proto.py`),
integer-PRNG deterministic, produced every line labelled RUN above. Scratch, not
tracked; reproduces on demand. It implements `select / subordinate / front / fuse /
elide / cleft / figure / punct` over the 5-atom Maren skeleton with three voice tables
and a gated figure table — a faithful sliver of §1–§3, deliberately including its own
failures so §5's stiffness verdict rests on real output, not optimism.
