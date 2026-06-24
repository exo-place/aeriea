# Candidate D — Analogical Schema Induction

Status: **design candidate (one of four), with a RUN toy prototype.** Instantiates
the fixed thesis (SUPPORT=full language / TASTE=distribution / FAITHFULNESS=hard
gate) under the **deep-schema** paradigm. Not green; not self-promoted.

The bet of this candidate: the unit of generation is a **deep structural-rhetorical
schema** — *the move a sentence makes* — not a lexical template. The build-time
frontier net does the one thing programmatic analysis cannot: it reads real
high-quality authored prose and abstracts each passage **upward** to the rhetorical
move it performs, discarding the words. Generation re-instantiates and recombines
those moves, filling them through an **open lexicon / sub-grammar** so that no
schema yields a fixed string. Full support comes from `schema-recombination ×
open-instantiation`; faithfulness comes from a hard commitment gate that runs at
both schema-selection and lexicon-provenance level; taste comes from a build-time
distribution over schemas and registers.

---

## 1. The paradigm concretely

### 1.1 What a SCHEMA *is*, as a data shape

A schema is **not** a string with holes. It is a small typed program over
**rhetorical ROLES** (not word slots). Its fields:

```
Schema {
  name        : the rhetorical MOVE it makes (documentation, not a key into prose)
  moves       : ordered list of Move        # the structural skeleton
  joiner      : RST relation realized between moves (sentence_breaks | concessive | causal | ...)
  affinity    : register -> int weight       # which voices this move belongs to (TASTE)
}
Move {
  role        : anchor | speech | tell | reflect | ...   # rhetorical function
  selector    : a COMMITMENT QUERY            # what kind of state-fact may fill it
  realizer    : a generative sub-grammar fn   # recurses into the OPEN LEXICON
}
```

The load-bearing property: **a move binds to a *kind of commitment* via a query,
and realizes through a *generative* sub-grammar.** It contains no words. The words
are produced by `realizer`, which itself chooses among **structurally different
constructions** (not synonyms) and can recurse further into the semantic-graph
grammar. So one schema is a productive *family*, not a template.

### 1.2 A real deep schema abstracted from an authored sentence

Take the strong gemma-4-26B exemplar from `ref-corpus.md`:

> *The scent of red wine and seared beef hangs thick. … Christine rests her back
> against the velvet chair. Her wine glass sits empty, though she stares at it with
> intent. … "The service here is slow tonight," Christine says, her voice a smooth,
> low rasp.*

A **shallow** (mad-libs) abstraction would lift slots: `The scent of {X} and {Y}
hangs thick`. That is the death this candidate must avoid.

The **deep** abstraction the net is asked for, instead, names the *rhetorical move*:

```
SCHEMA  ANCHOR_then_WITHHELD_then_TELL
  move 1  anchor   : <ambient sensory fact>     # ground the scene in a concrete percept
  move 2  speech   : <emotional truth, WITHHELD># a line that says LESS than the felt content
  move 3  tell     : <bodily/postural fact>     # the body betrays what speech withheld
  joiner  sentence_breaks
  the move: "establish a concrete world-anchor, let the character UNDERSTATE the
            real emotional beat in speech, and leak the truth through a body tell."
```

Nothing here is wine, beef, or velvet. The schema captures **restraint +
literal-vs-felt gap + bodily leak** — the craft, not the content. Re-instantiated
on *rain / reunion / guarded innkeeper*, the same move produces wholly different
words and a wholly different scene, yet performs the same rhetorical work. That is
analogical re-use of a deep move, which is the whole thesis of this candidate.

### 1.3 The inventory

The shipped artifact is a **schema inventory**: a few hundred to a few thousand such
typed schemas, each tagged with its rhetorical move, its move-skeleton, its joiner,
and its register/voice affinities. They are *typed by rhetorical function*, so they
compose: an `anchor` move from one schema can be spliced before the `speech+tell`
of another (recombination, §1.5). Plus the **open lexicon / sub-grammars** that
realize each role, also build-time-induced (these recurse into `semantic-layer.md`'s
prevalence-weighted graph in the real engine).

### 1.4 Runtime selection + instantiation

Given `(communicative intent, salient committed state, seed)`:

1. **Select** a schema. Candidates = schemas whose every move-selector is satisfied
   by the commitment store (the gate at selection), weighted by `register affinity ×
   intent fit`. Seeded weighted pick.
2. **Instantiate** each move: run its selector against the commitments to bind a
   concrete fact, then call the realizer sub-grammar (seeded) to render it — the
   realizer choosing among structurally distinct constructions.
3. **Recombine** via the joiner (the RST relation: plain sentence breaks, or a
   *concessive/causal fusion* that collapses two moves into one clause — genuine
   syntactic change, fusion-ratio > 1).

### 1.5 Recombination (why it isn't a fixed template set)

Because moves are **typed by rhetorical role and gated by commitment**, the
generator does not pick from a closed list of whole schemas. It can:

- **reorder** moves (anchor-first vs button-last → different cadence),
- **splice** a move from schema A into schema B (role-type compatible),
- **fuse** two moves under an RST joiner (concessive/causal) → new syntax,
- **drop** moves (restraint: salience says *say less*).

The realized space is `Σ over schema-skeletons × move-orderings × splices × joiner
choices × per-move open-lexicon realizations`. The schema *inventory* is finite; the
*realized space* is not (§5).

### 1.6 Determinism / seeding

Every choice site has a **stable string id**; selection is a single integer-only
`splitmix64(seed ⊕ state_hash ⊕ fnv1a(site_id))`. No floats, no salted `hash()`
anywhere on the generative path — so it is **cross-platform bit-identical** and
replayable from `seed + event log`. (The prototype uses exactly this; see the
`Rng` class.) The branch happens **upstream** at schema/move/joiner selection — *what*
and *how*, not merely *word* — satisfying the conception-not-lexicon variety demand.

---

## 2. Distillation pipeline

**Input:** real high-quality authored prose (curated, content-gated, transformed —
per `ref-corpus.md`: strong gemma/gemini-pro turns + true literary exemplars, never
verbatim, minor/abuse material hard-excluded).

**The net's job (the part programmatic analysis cannot do):** for each
sentence/passage, **abstract upward** to its rhetorical move — emit a `Schema`:
the ordered roles, the move it performs, the RST joiner, and (from many examples) the
register/voice affinity weights. The net is doing *deep structural induction*:
"this passage = concrete-anchor → withheld-beat → bodily-tell, joiner=breaks, voice
∈ {lyrical, plain}." It also induces the **open-lexicon sub-grammars** per role:
the structurally-distinct construction families that realize an `anchor` for a
weather fact, a `tell` for guardedness, etc.

**The shipped artifact (net-free at runtime):**

```
artifact = {
  schemas   : [ Schema ... ]            # typed move-skeletons + joiners
  affinities: schema × register -> int  # the TASTE distribution (build-time net)
  lexicon   : role -> sub-grammar       # open, recursive construction families
  selectors : commitment-query bindings # how moves bind to the commitment store
}
```

All integers/structured data — **no net, no float, no string-template-with-holes**
ships. At runtime the engine reads this data and the seeded chooser; the frontier
net is gone. This is exactly the "data over code at a seam" principle: the schema is
a faithful serialization of a rhetorical move, which caches/replays/diffs.

**Finite artifact, full support:** the inventory is finite; the **realized space is
not**, because (a) recombination (reorder/splice/fuse/drop) multiplies skeletons,
and (b) each move realizes through an *open* sub-grammar that recurses into the full
lexicon/semantic graph — so any sensible grammatical sentence is reachable with
nonzero probability provided some schema's move-shape can host it. §5 confronts where
that claim is strong and where it is conditional.

---

## 3. Content gate + salience

**Hard gate, two levels (a real finding from the prototype):**

1. **Selector level.** A schema/move only fires if its `selector` finds a backing
   commitment. No commitment for `weather.raining` → no rain anchor can be selected.
   This is the obvious gate and the prototype implements it: removing the
   `weather.raining` commitment, **zero** outputs asserted rain via the anchor.
2. **Lexicon-provenance level (the subtle one).** The prototype surfaced a genuine
   bug-class: a *withheld-speech* lexicon entry (`"look what the rain dragged in"`)
   itself asserts rain. A selector gate on the move is **not enough** — every lexicon
   construction must carry its own **proposition-provenance tags**, and a
   construction is admissible only if *all* propositions it asserts are committed.
   So the gate is: `admissible(construction) ⟺ asserted_props(construction) ⊆
   commitments`. This is the same assert→state-fact provenance check
   `prose-generation.md` mandates, pushed down to the lexicon. Honest note: the toy
   does not yet tag lexicon provenance, which is why that entry *could* have leaked —
   it didn't fire by luck of the seed, not by construction. The real engine **must**
   tag it. This is a buildability cost I am not hiding.

**Falsity only via explicit license.** A lie/mistake/POV-ignorance is modeled as a
*licensed* commitment: the speech-frame commitment `believes(Maren, P)` licenses
asserting `P` in her dialogue even when world-`P` is false. The gate checks against
the *frame-appropriate* commitment set, so lying is reachable but never accidental.

**Salience steering.** The intent + novelty/intensity scores weight which moves are
*worth* firing (the `WITHHELD_only_minimal` schema exists precisely so salience can
choose **restraint** — one withheld line — when less is more). Salience also picks
the bound tell (`pick_tell`) from committed body tells. So salience steers toward
what matters and can *drop* moves, not just fill them.

---

## 4. Concrete generated output (RUN, not hand-waved)

Fixed committed content: **Maren (innkeeper) notices the player returned after a
long absence; she is glad but guarded; it is raining; she's at her counter.**

The following is **actual run output** of `/tmp/schema_proto.py` (a real, seeded,
float-free prototype with five hand-abstracted deep schemas, four registers, and a
small open lexicon of structurally-distinct constructions). Labeled **RUN**.

**RUN — 8 seeds, register auto-chosen by seed (varies STRUCTURE *and* voice):**

```
[seed 101] terse   / ANCHOR_fused_STAGING_then_WITHHELD
  Rain on the glass. Behind the bar, she looks up. "You're back." A statement, not a question.

[seed 202] wry     / STAGING_then_TELL_then_WITHHELD
  Behind the bar, same as ever, she clocks you mid-pour. Her hands plant themselves on
  the counter like they're guarding the till. "Well, look what the rain dragged in,"
  she says, which is as close to glad as she gets out loud.

[seed 303] terse   / WITHHELD_only_minimal
  "You're back." A statement, not a question.

[seed 404] lyrical / ANCHOR_then_WITHHELD_then_TELL
  Rain unspools down the pane, steady as an old argument. "You came back," she says,
  the way you'd touch something you weren't sure was real. A muscle works once at the
  hinge of her jaw and goes still.

[seed 505] lyrical / ANCHOR_then_WITHHELD_then_TELL
  Behind her the downpour blurs the lamps to smears of gold. "There you are," she says,
  and the smallness of it carries more than the words. Her shoulders hold their line,
  braced against a thing that isn't in the room.

[seed 606] terse   / STAGING_then_TELL_then_WITHHELD
  She's at the counter. Shoulders up. "Huh," she says. "You."

[seed 707] plain   / ANCHOR_fused_STAGING_then_WITHHELD
  Water runs down the glass behind her. She's behind the counter when you come in.
  "You're back," she says, and leaves it there.
```

(8 distinct texts among 8 seeds.) Note these differ in **rhetorical structure**:
seed 303 is bare restraint (one withheld line); seed 404 runs anchor→withheld→tell;
seed 606 stages→tells→withholds (the emotional button lands *last*, different
cadence); seed 707 fuses two anchors then withholds. This is **not** one frame with
swapped nouns — the *moves and their order* change.

**RUN — same content, register forced (TASTE axis isolated; content fixed):**

```
[plain  ] She looks up from the bar as the door swings shut. Her shoulders don't quite
          come down. "You're back," she says, and leaves it there.
[terse  ] Rain on the glass. "You're back." A statement, not a question. Shoulders up.
[lyrical] The rain has not let up; it threads the dark window in slow lines. "You came
          back," she says, the way you'd touch something you weren't sure was real. Her
          shoulders hold their line, braced against a thing that isn't in the room.
[wry    ] Behind the bar, same as ever, she clocks you mid-pour. Her shoulders stay up
          around her ears, ready for a fight nobody offered. "Well, look what the rain
          dragged in," she says, which is as close to glad as she gets out loud.
```

Same committed facts, four genuinely different **voices** — and the lyrical and
terse versions also differ in *structure*, not just diction.

**RUN — content gate (remove the `weather.raining` commitment):**

```
[seed 101] schema=STAGING_then_TELL_then_WITHHELD  asserts-rain=False
  Behind the bar, same as ever, she clocks you mid-pour. Her shoulders stay up around
  her ears, ready for a fight nobody offered. "You. Back. Hm." She files it away like
  she's not pleased, which fools no one.
[seed 202] schema=TELL_concessive_WITHHELD         asserts-rain=False
  A slow breath, but "Huh," she says. "You."
```

Rain de-committed → the rain anchor is gone and the structure re-routes. (Note: the
concessive-joiner output is the prototype's roughest line — capitalization of the
fused quote is wrong; flagged honestly as a known toy defect, see §6.)

**HAND-DERIVED, not run:** the depth reading of seed 404. `anchor` =
`weather.raining` (faithful); `speech` carries `affect.glad` *as withheld* — she
says "you came back" the way you'd *touch something you weren't sure was real*: the
gladness is rendered as the **gap** between the flat words and the simile, never
stated; `tell` = `affect.guarded` fused into one image (*a muscle works once… and
goes still*), fusion-ratio > 1. Three commitments, three rhetorical moves, zero
confabulation.

---

## 5. Mad-libs + finiteness confrontation (this candidate's death-risk)

**Is it mad-libs?** Mad-libs = one fixed cadence, swap nouns. The decisive
disproof is in the RUN output: across seeds the **cadence and rhetorical structure
themselves change** — bare restraint (303) vs anchor→withheld→tell (404) vs
stage→tell→withhold with the button last (606) vs double-anchor-fusion (707). A
mad-libs system cannot do that; it has one frame. Moreover each move realizes through
**structurally distinct constructions** (e.g. the rain anchor is variously a
declarative `Rain on the glass.`, a subordinate-clause image `…threads the dark
window in slow lines`, a metaphor `steady as an old argument`) — not synonyms of one
template. **So: not mad-libs — *in the structural sense* — demonstrably.**

The honest caveat: this is only true **if the schemas are genuinely deep and the
sub-grammars genuinely open.** The candidate's death is if the build-time net,
under pressure, induces *shallow* schemas (effectively `The scent of {X}…`). Then it
collapses to mad-libs wearing role-labels. **Mitigation:** the build-time eval must
score schemas for *abstraction depth* — e.g. a schema is rejected if its realized
outputs across different bound content are too n-gram-similar (it's a template), and
the gap-to-Opus A/B from `prose-generation.md` is the holistic arbiter. This is a
real, unproven dependency, not a solved thing.

**Is the support secretly finite?** The toy's `distinct outputs over 4000 seeds =
375` is **finite — honestly.** That is because the toy lexicon is tiny (2–3
constructions per role) and there is no recursion into a real grammar. I am **not**
claiming the toy has full support; it demonstrably does not. The full-support claim
rests on two things the toy *stubs*:

1. **Open recursive sub-grammars.** Each role-realizer must recurse into the
   `semantic-layer.md` prevalence-weighted graph + a real compositional grammar, so
   an `anchor` for "rain" is not 3 strings but an open generative family (any
   grammatical rain-percept clause). With that, per-move support is already infinite.
2. **Recombination over typed moves.** Reorder/splice/fuse/drop over a few-thousand
   schema inventory multiplies skeletons combinatorially.

The product `open-instantiation × recombination` is what reaches full support. **The
honest position:** support is full *iff* the sub-grammars are truly open (claim #1).
If they degrade to finite construction-pools, support is finite and large — which is
**mad-libs at a larger scale**, the exact failure this candidate is most at risk of.
So the candidate **stands or falls on the openness of the role sub-grammars**, and
that openness is inherited from the semantic-graph grammar seam, which
`prose-generation.md` itself marks OPEN. I am not hiding this: it is the load-bearing
unproven dependency, and the toy does not yet discharge it.

---

## 6. Trade-offs + buildability

**Strengths.**
- The deep-schema unit is a *faithful serialization of a rhetorical move* — exactly
  the "data over code at a seam" the ecosystem prefers; schemas cache/diff/replay.
- Structure-and-voice variety is real and demonstrated (the RUN output varies
  cadence, not just lexicon), directly answering the "fake variety" disqualifier.
- The frontier net is used for the one thing it's uniquely good at (deep structural
  abstraction) and is *gone* at runtime — clean determinism story.
- The content gate fits naturally at two levels and the lying/POV license is clean.

**Weaknesses / risks (honest).**
- **The whole thing rests on schema *depth* and sub-grammar *openness*.** Shallow
  schemas → mad-libs; finite sub-grammars → finite support. Neither is proven; both
  are inherited-OPEN seams. This is the candidate's central fragility.
- **Lexicon provenance tagging is mandatory and non-trivial** (the rain-in-withheld
  finding). Every construction must carry its asserted-proposition set, or the gate
  leaks. Real build cost.
- **RST fusion is the hardest realizer** — the toy's concessive joiner produces the
  one bad line (mid-sentence quote capitalization). Genuine syntactic fusion that
  reads well is a real grammar-engineering problem, not a stub.
- **Inducing the schema inventory at quality** is a large build-time effort with the
  same judge-bias/Goodhart risks `prose-generation.md` records.

**Buildability.** The runtime is cheap and obviously deterministic (the toy is ~250
lines of integer-only Python; the Godot/Rust port is direct). The expensive,
unproven half is entirely **build-time**: inducing deep schemas + open sub-grammars
+ provenance tags from curated prose, and the eval that rejects shallow schemas. That
matches the thesis (build-time net is the taste/structure source; runtime is
net-free). The candidate is *buildable incrementally* — ship a few hand-authored deep
schemas first (the toy proves the runtime works today), then grow the inventory via
the net — but it is **not green** and its full-support claim is conditional on the
open sub-grammar seam being discharged.
