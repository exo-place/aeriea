# Text-generation architecture (the decision)

This doc REPLACES an earlier, now-wrong draft of this file that was built around
BDCC's Form/Filler/Adder authored-passage model. That foundation is discarded.
The architecture below is the synthesized output of a long collaborative
design-it-twice pass (four decorrelated generative paradigms, each prototyped with
real run output; four adversarial judges) recorded under
`docs/artifacts/text-gen-design/`. Every claim here is grounded in those artifacts.

---

## 1. Status

**Design pass only. NO code is written.** The existing text sandbox is untouched.
This lands in `docs/FEATURES.md` under **"Not green"** and stays there until the
user personally verifies it is good. Green is the user's alone; nothing here is
self-promoted, and a passing first experiment is not a promotion.

Frame this honestly as a **BET**, not a certainty. The user's own words were
"worth a try." The central uncertainty is named in §7 and is not hidden behind the
architecture's tidiness: it is genuinely unproven whether the chosen mechanism does
enough *generative* work to clear "a very sophisticated chooser over authored
fragments." The first experiment (§8) exists precisely to test that.

**This doc SUPERSEDES the load-bearing foundations of** `docs/decisions/prose-generation.md`,
`docs/decisions/npc-mind-and-language.md`, and `docs/decisions/semantic-layer.md`
(they remain in the tree as historical record; new work is not built on their
foundations), **and REPLACES the prior BDCC-based draft of this file.**

---

## 2. Corrected failure diagnosis

The prior text-sandbox failure was **not** "a generator that lacked taste." It was a
**process sin**: the previous session **imported BDCC2's affect/mood engine
wholesale** — `scripts/sim/mood.gd`, `scripts/sim/memory.gd`,
`scripts/sim/relationship.gd` are BDCC2 ports — and **ignored aeriea's own design**.
The visible symptom was a scalar stimulus→arousal pump (`mood.gd:59` turns a greet
into a rising "arousal" scalar surfaced raw to the player), which is exactly the
scalar-affect-lens that `prose-generation.md` had *already forbidden*. It was
reintroduced by importing a foreign engine instead of designing for aeriea. The
lesson: **design for aeriea, do not port a foreign engine.**

---

## 3. Rejected foundations (design against these; do not reintroduce)

- **(a) Prose as a deterministic LENS over numeric scalars** (mood / rapport / lust
  rendered into text). Depth-bearing prose is authored writing, not a number
  re-skinned.
- **(b) The brain → communicative-intent → multi-channel-realizer spine**
  (`npc-mind-and-language.md`'s modality-independent intent tuple expanded by a
  realizer). Not the architecture.
- **(c) The prevalence-weighted RDF-triple semantic graph** (`semantic-layer.md`) as
  a prose substrate.
- **(d) Any runtime LLM / relaxing determinism.** Per-query inference in the hot loop
  is out of the player's compute budget AND a copout. Determinism is a hard
  invariant.
- **(e) Blessing a single game's mechanism as a template** — specifically BDCC's
  Form/Filler/Adder, the basis of this file's prior draft. One game's authored-passage
  scheme is not the generative grammar this design needs.
- **(f) The mediocre SillyTavern RP corpus as a quality bar.** `ref-corpus.md`: it is
  a **benchmark** (the gap-to-beat: a strong gemma-4-26B turn), and a content-safety
  minefield (minors-in-abuse material to hard-exclude), **never a source to mine for
  taste.**
- **(g) Detection / critics as a substitute for taste in the generator.** A net
  cannot add judgment the generator lacks; faithfulness and quality must be
  generation-side, not a post-hoc filter.

---

## 4. The thesis — three cleanly-factored mechanisms

A **deterministic, runtime-net-free GENERATIVE GRAMMAR of prose.** Factored into
three orthogonal mechanisms:

- **SUPPORT = the full language.** Any sentence a competent author might put on the
  page has nonzero probability — **including deliberate non-standard / "ungrammatical"
  forms** (fragments, run-ons, comma-splices, dialect, modern flow) and especially
  **dialogue** (people do not speak in clean sentences). The support boundary is
  "what a competent author might write," **NOT grammaticality.** This disqualifies
  every finite-support design (authored pools, retrieval, verbatim beats, lookups).
- **DISTRIBUTION = taste.** *Which* of the infinite support is likely — voice,
  cadence, aptness, and the standard-vs-deliberate-deviation balance — is probability
  mass: a taste-**SPACE** (never one locked taste), shaped at **build time** by a
  frontier LLM and moved at **runtime** by character / mood / register.
- **FAITHFULNESS = a hard content-gate.** Asserted content is **hard-constrained** to
  a commitment store (world-facts + epistemic / speech / perceptual frames). Falsity
  enters **only via an explicit license**: POV / incomplete-knowledge, a character
  lying or mistaken in dialogue, or altered senses — and in each case the apparent
  falsehood is itself a committed truth one level up (she *says* X; she *believes* X).

Constraints throughout: deterministic, seeded, replayable, cross-platform (flat /
PCVR / Quest); no runtime net; must **meet-or-beat a frontier model's range + craft**
(falling below a small MoE = failure); three variety axes — **content**,
**structure / cadence**, **taste / voice** — none of which may lock; not mad-libs,
not stiff.

---

## 5. The design-it-twice result

Four decorrelated generative paradigms were designed AND prototyped with **real run
output** (`/tmp/tsg`, `/tmp/cxg_proto`, `/tmp/transform_proto`, `/tmp/schema_proto`),
then adversarially judged on four lenses. Honest summary, with scores:

- **A — Probabilistic TSG/TAG** (tree-substitution/adjoining grammar).
- **B — Construction Grammar (CxG)** (form-meaning constructions at multiple grains).
- **C — Transformational / edit-sequence** (derive the surface by a seeded sequence of
  structural transforms over a propositional skeleton).
- **D — Analogical Schema Induction** (the unit is a deep rhetorical *move*).

| Judge lens | Result | Pick |
|---|---|---|
| **Output quality, by MECHANISM** (`judge2-output-quality.md`) | D≈B (both ~6 on the page) > A (4) > C (3) | **B** — quality is attributable to the *mechanism*, not a pre-authored showcase; D reads prettiest but its beauty is a finite hand-authored string pool (375 distinct outputs / 4000 seeds). |
| **Full support incl. ungrammaticality** (`judge2-full-support.md`) | **B (8)** > C (7) > D (4) > A (3) | **B** — no grammaticality predicate exists; non-standard forms are first-class. **A FAILS**: its support boundary literally IS grammaticality. |
| **Distillation buildability** (`judge2-distillation.md`) | **C (7)** > A (5) > D (4) > B (3) | **C** — bounded artifact + a *machine* validation filter. **B is worst**: its mining = "human-sign tens-of-thousands of constructions" — the authoring ceiling renamed. |
| **Determinism + content-gate** (`judge2-determinism-gate.md`) | **C (16)** > A (13) > B (11) > D (10) | **C** — the only lexically-sound gate (assertion provenance falls out of atom→commitment keying) + defensive total-ordering of every draw. **B denies a real lexeme-level assertion leak** (its `lit` strings assert uncommitted facts while the design claims the gate is airtight). |

**The split is clean and decisive:** **B (Construction Grammar) wins quality +
expressiveness** (mechanism-attributable craft, full support including controllable
ungrammaticality, taste as distribution). **C (transformational) wins engineering
rigor** (bounded checkable distillation, lexically-sound gate, deterministic
discipline). The decision (§6) is to take B's spine and graft C's disciplines.

---

## 6. The decision — Construction Grammar spine + C's three disciplines

**Base the architecture on Construction Grammar (B).** It wins the axes that define
the bar:

- **Mechanism-attributable quality** — B's strongest samples are all *run* output
  with no hand-derived showcase; its subtext is carried by a productive grammatical
  unit (`S.glad_undercut` fuses both stances in one construction), not a single canned
  string repeated (`judge2-output-quality.md`).
- **Full support including controllable ungrammaticality** — there is *no
  grammaticality predicate anywhere in the realizer*; a comma-splice, a dialect line,
  a fragment, an aborted clause are ordinary constructions that ride the **same
  voice-affinity dial as register** — distributional by construction, never a wall
  (`judge2-full-support.md`).
- **Taste as a distribution** — register-affinity vectors are a taste-*space*;
  mood/register move the point continuously without new constructions.

**Graft the three disciplines the judges say the winner MUST adopt** (each one fixes
a named B weakness):

1. **Lexeme-level provenance gate (from C).** Gate on **what the surface text
   ASSERTS**, down to every `lit` / lexeme keyed to a commitment —
   `asserted_props(construction) ⊆ commitments` — not on a separate `requires`
   annotation the frozen text can silently contradict. This closes B's **denied
   hallucination leak** (`judge2-determinism-gate.md` reproduced `C.head_comes_up`
   asserting "you cross the threshold" with no such commitment).
2. **Total-order every draw before selection (from C).** Every order-sensitive site
   is sorted to a total order before the pick; integer splitmix64, integer weights,
   **no floats, no Dict/Set-iteration order leaking into output.** This closes the
   cross-platform dict-order determinism hole that would diverge Godot/Rust from the
   CPython prototype (`judge2-determinism-gate.md`).
3. **Machine-validated distillation (from C).** The mined constructicon must
   **re-parse the authored corpus**; any construction whose claimed derivation does
   not re-execute is auto-discarded. This converts B's worst exposure — "human-sign
   ~30k mined constructions" — into a checkable mining loop with a program, not a
   human, as the confabulation filter (`judge2-distillation.md`).

**Central named risk: idiom-tile seams.** B's one live defect is adjacent
constructions reading *bolted-on* rather than woven ("She registers you after all
this time. Rain ticks against the window." — `judge2-output-quality.md`). The
in-formalism fix is **RST-style cohesion constructions** (contrast / concession /
cause as first-class members so adjacent material is *related*, not merely adjacent)
— which the distillation judge flags as **the hardest grain to mine**. This is the
research bet of the build-time pipeline, **not a side issue.**

---

## 7. The honest crux (the bet this rides on)

The output-quality judge re-ran all four prototypes and found a finding that cuts
across every candidate: **every candidate's prettiest words are PRE-AUTHORED.** The
beautiful images ("steady as an old argument," "the months since collapsing to
nothing," "not quite looking at you") are lexical strings typed into a table by a
good writer; the mechanism does the *structural / compositional* work *around* them
(`judge2-output-quality.md`: "the question is which mechanism does the most
generative work around those words").

This is **not automatically fatal** — a frontier LLM also reuses learned phrasings,
and authored construction-*forms* + productive recombination + cohesion constructions
can be genuinely generative rather than retrieval-in-disguise. But it IS **the
unproven bet**: whether CxG composition + cohesion does *enough* generative work to
clear the bar of "a very sophisticated chooser over authored fragments." If it does
not, the architecture degrades toward high-class retrieval wearing a grammar's
clothes. The first experiment (§8) exists to test exactly this, and nothing else.

---

## 8. First experiment (de-risk order — avoid the big-rebuild trap)

Concrete, small, **playtestable-by-reading**. It proves the **runtime mechanism
first**, before any net-mining (the expensive, uncertain build-time half stays
deferred until the cheap runtime bet validates):

- **Hand-author a micro-constructicon for TWO contrasting voices** — e.g. a guarded
  literary narrator + a slangy character whose dialogue uses deliberate
  comma-splices / fragments. No frontier net yet; the constructicon is hand-built to
  exercise the runtime.
- **Build the deterministic CxG realizer** with all **three C-disciplines**
  (lexeme-provenance gate, total-ordered draws, integer splitmix64) + a small
  **commitment store** (a few world-facts + **one licensed-falsity frame** — e.g. a
  character lying in dialogue, where the lie is itself a committed speech-fact).
- **Generate N realizations of ONE fixed committed content** across both voices,
  varied structure, **including at least one deliberately-ungrammatical dialogue
  case**. Then **READ the actual output** (orchestrator + implementer playtest, per
  the mandatory playtesting rule).
- **SUCCESS CRITERION:** composition + cohesion **demonstrably add generative value
  BEYOND the authored fragments** — an honest A/B against "just emit one construction
  verbatim" — and the output reads non-stiff with **no visible tile-seams**, **varies
  cadence not just words**, stays **bit-for-bit deterministic on replay**, and the
  gate both **blocks unlicensed falsehood** and **permits the licensed lie.**
- **Distillation** (frontier-net mining of the constructicon from real high-quality
  authored prose, + RST-cohesion mining) is **DEFERRED** until this runtime bet
  validates. Each step ends in readable output the user can judge.

---

## 9. Open / deferred / upstream

- **Net-mining distillation at scale + RST-cohesion mining** — the hard build-time
  research (constructicon density, cohesion constructions conceded the hardest grain,
  machine-validated re-parse loop), deferred behind the §8 runtime validation.
- **This realizer is DOWNSTREAM of the larger-scale layers** — the living world,
  long-horizon continuity, and situation generation remain **upstream, harder, and
  unsolved.** A good realizer cannot manufacture aliveness the world lacks; sentence
  craft is necessary, not sufficient, for the 100%-immersion goal.

---

This is a proposal. It awaits the user's express approval before any code is written.
