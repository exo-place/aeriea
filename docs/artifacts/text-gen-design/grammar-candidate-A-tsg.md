# Candidate A — Probabilistic Tree-Substitution / Tree-Adjoining Grammar (TSG/TAG)

Status: design candidate (one of four). Develops the FIXED thesis's runtime
generator as a **net-weighted TSG/TAG with an open lexicon**. Build-time frontier
net + authored-prose corpus induce the elementary trees and the weight tables;
runtime is net-free, seeded, deterministic. Three mechanisms stay factored:
**SUPPORT** = full language (recursive adjunction + open lexicon); **TASTE** =
the weight tables, conditioned on (voice, mood, register); **FAITHFULNESS** = a
hard content gate over a commitment store.

A toy prototype of the FORM was built and run — its real output is in §4 and is
labelled `[ACTUAL RUN]`. The hand-derivations are labelled `[HAND]`.

---

## 1. The paradigm, concretely

### 1.1 Why TAG and not CFG / pure TSG

A context-free phrase grammar generates by rewriting nonterminals; its only
structural lever is *which* production fires, and recursion is buried in
nonterminal self-reference. That is the classic wooden-grammar trap: the cadence
is an emergent side effect of rule depth you cannot independently steer, so you
get syntactic permutations of one rhythm.

**Tree-Adjoining Grammar splits structure into two operations that map cleanly
onto the two things prose cadence actually is:**

- **Substitution** fills an open *argument* slot (a leaf marked `↓`) with an
  initial tree — this realizes *content* (who/what/the proposition).
- **Adjunction** splices an *auxiliary* tree (one with a distinguished **foot
  node** `*` matching its root label) into the middle of an existing tree — this
  realizes *modification, subordination, framing, rhythm extension* without
  touching the content skeleton.

The decisive property: **adjunction is independently recursive.** You can adjoin
zero, one, or many auxiliary trees at any matching node. Sentence length,
subordination depth, the number of asides, the rhythm — all become a *separately
weighted count* (how many adjunctions, of which families, at which sites), not a
byproduct of which clause you picked. **That is the structural-variety axis the
thesis demands, expressed as its own knob.** A CFG cannot give you "same content,
short clipped cadence" vs "same content, three nested subordinate clauses" by
turning one weight; TAG can, because adjunction count is the weight.

Full support follows from two facts: adjunction recursion is unbounded (any
finite sentence structure is reachable), and the lexicon is **open** (§2.4) — so
any sensible grammatical sentence has nonzero probability, satisfying the
hard-constraint. Finite-support disqualifiers (pools, retrieval) are absent:
nothing here is a finite list of sentences; the sentences are *derived*.

### 1.2 Data shapes (the shipped artifact's atoms)

Everything is plain serializable data — no closures, no embedded code — so it
caches, diffs, replays (per the data-over-code seam principle).

**Elementary tree** (initial or auxiliary):

```
ElemTree {
  id:        u32,
  kind:      INITIAL | AUXILIARY,
  root:      Label,              # e.g. S, NP, VP, ADVP, PP
  nodes:     [Node],             # tree topology, flat-indexed
  subst:     [SlotId],           # leaves marked ↓ : substitution sites (content)
  foot:      NodeId?,            # AUXILIARY only: the * node (adjunction recursion)
  anchor:    LexClass?,          # which lexical class lexicalizes this tree
  # semantic guard: which proposition TYPE this tree can carry
  carries:   PropType?,          # e.g. EVENT, AFFECT, AMBIENT, STATE  (None for pure-syntax aux)
}
Node { label: Label, children: [NodeId], mark: NONE|SUBST|FOOT }
```

**Weight table** (the taste, the net's output):

```
# A production weight is conditioned on a CONTEXT SIGNATURE.
WeightTable : map< (RuleFamily, CondSig) , [ (TreeId|LexId, u16_weight) ] >

CondSig = packed bits of (voice_id, mood_bucket, register_id, slot_role, depth_bucket)
```

All weights are **integers** (`u16`). No floats anywhere in the draw → no
cross-platform float nondeterminism (the hard constraint). Probabilities are
`weight / Σweight` computed only conceptually; the actual draw is integer modulo
(§1.4).

**Open lexicon**: concept → register-tagged surface options with integer base
weights (§2.4). The build-time net seeds these and can extend them; the *form*
admits any string, so support is open.

### 1.3 Derivation at runtime (the generation loop)

Input: `(salient committed propositions [gate-passed], voice, mood, register,
seed)`. Output: a string.

1. **Frontier selection.** For each salient proposition, the realizer is required
   to choose an initial tree whose `carries` matches the proposition's `PropType`.
   This is the content gate biting at the *structural* level: a tree that carries
   AFFECT cannot be substituted with an EVENT proposition. The choice among
   matching trees is a weighted draw on `(SELECT_INITIAL, CondSig)`.
2. **Substitution.** Fill each `↓` slot by lexicalizing its concept from the open
   lexicon, weighted by `(LEX, register)` — and, recursively, by substituting a
   sub-tree where the slot is phrasal.
3. **Adjunction (the cadence engine).** At each adjoinable node, draw from
   `(ADJOIN_AT<label>, CondSig)` whose options include a distinguished **STOP**
   token. Drawing a real auxiliary tree splices it in (subordination, modifier,
   framing aside, rhetorical-relation join) and *recurses* on the new node;
   drawing STOP ends adjunction at that site. **The STOP weight, conditioned on
   voice/mood, is literally the cadence dial**: a terse voice has high STOP weight
   (few adjunctions → short clauses); a run-on-warm voice has low STOP weight at
   join sites (adjunctions stack → long breathing sentences).
4. **Clause joining** is itself adjunction: a rhetorical-relation auxiliary tree
   (concession / contrast / cause / parataxis / asyndeton / run-on) adjoins at the
   `S` root to attach the next clause. The *relation* is a weighted draw — this is
   the RST-richness the prose-gen doc asked for, expressed as adjunction.
5. **Linearize** the finished derived tree → surface string; one terminal-
   punctuation pass.

Every draw in steps 1–4 is a `Rng.pick(weighted)` on the seeded integer PRNG.
Determinism is total.

### 1.4 Determinism & seeding

The PRNG is **splitmix64** over `u64` integer state — chosen because it is a pure
integer recurrence (no float ops, no platform-specific hashing in the draw):

```
s += 0x9E3779B97F4A7C15
z = s; z = (z ^ z>>30) * 0xBF58476D1CE4E5B9
        z = (z ^ z>>27) * 0x94D049BB133111EB
        z =  z ^ z>>31
draw = z
pick(weighted) = first item where cumulative_weight > (draw mod Σweight)
```

The seed for a render is `mix(global_seed, intent_hash, salience_hash, voice_id)`
where every input is an integer derived from the event log (no string hashing
enters the draw — voice is an integer id assigned at build time). Same
`(intent, brain-state, seed)` → identical draw sequence → **bit-for-bit identical
prose** (the determinism axis). The prototype's `DETERMINISM CHECK` confirms a
re-run is byte-identical.

---

## 2. Distillation — build-time net + authored prose → grammar + weights

This is the nut. Programmatic analysis alone is insufficient (the user's
guidance, and obviously true — you cannot induce *taste* by counting). The
frontier net does the heavy lifting; corpus statistics calibrate and ground it.

**Sources: REAL high-quality authored prose** — literary fiction, strong authored
RP — NOT the mediocre gemma/SillyTavern logs (those are a *benchmark*, per
`ref-corpus.md`, and a content-safety minefield). The corpus is the taste source;
the SillyTavern set is only the gap-to-beat yardstick.

### 2.1 Pipeline

1. **Parse authored prose into derivations.** A frontier LLM (build-time, at the
   leaves — sanctioned) is prompted/tooled to produce, for each authored sentence,
   a **TAG derivation**: the elementary trees used, the substitution fillers, and
   the adjunction sites. (This is "supervised TAG induction with an LLM as the
   parser." A statistical TAG parser alone is brittle on literary prose; the LLM
   gives robust, taste-aware bracketing. Corpus stats then *validate* the induced
   trees against held-out sentences — tests-are-the-spec.)
2. **Cluster into an elementary-tree inventory.** Merge derivations across the
   corpus; the recurring elementary trees (initial clause skeletons, auxiliary
   modifier/subordination/join trees) become the finite tree inventory. This is
   finite and shippable — a few hundred to low-thousands of elementary trees, the
   way real TAG grammars (XTAG) are sized.
3. **Induce conditioned weights.** For each `(RuleFamily, CondSig)`, count how
   often each tree/lexeme was chosen in derivations *attributed to that
   condition*. Condition attribution (which sentence is "terse vs lyrical",
   "guarded vs warm") is itself an LLM labeling pass over the corpus — the net
   maps prose → (voice, mood, register) tags, then the weights are the
   conditional choice frequencies, **smoothed** so nothing goes to zero (preserves
   full support). This is where TASTE becomes a number: the voice "lyrical-warm"
   *is* its weight vector over trees and lexemes.
4. **Span the taste-SPACE, not one taste.** The net is asked to produce **several
   distinct voice weight-vectors** (terse-guarded, lyrical-warm, plain, run-on-
   warm, clinical, …) by conditioning the corpus-labeling on style axes, and the
   shipped tables interpolate between them at runtime (mood/register shift the
   `CondSig`, selecting a blended weight vector). The thesis's "taste-space, never
   one locked taste" is exactly: the weight tables are *parameterized by voice id*,
   and voice ids are a continuum the build pass populates.
5. **Open the lexicon.** The net seeds each concept's surface pool (register-
   tagged) from the corpus and can extend it; runtime support stays open because
   the *form* accepts any string filler — the shipped pool is a high-probability
   subset, not a hard boundary.

### 2.2 The shipped artifact (finite, net-free at runtime)

A single serialized bundle:

```
grammar.bin = {
  trees:    [ElemTree]            # the induced elementary-tree inventory (finite)
  lexicon:  map<concept, map<register, [(surface, u16)]>>
  weights:  WeightTable           # conditioned integer weight tables
  voices:   map<voice_id, CondSig-base>   # the taste-space anchors
}
```

This is **pure data**. At runtime the engine is a small deterministic interpreter
(tree substitution + adjunction + integer PRNG) reading this table — **no net, not
even a frozen one.** The net's entire contribution is *baked into integer weights
and a tree inventory at build time.* That is precisely the thesis's "build-time
LLM is the taste source; runtime is net-free." The artifact is finite and ships;
support is full because derivation (not lookup) produces sentences.

### 2.3 Why this isn't mad-libs

Mad-libs = one fixed cadence, lexical slot-fills. Here the **structure itself is
drawn**: which initial trees, how many adjunctions, which rhetorical-relation
joins, what subordination depth — all weighted draws that *vary the tree*, hence
the cadence, hence the rhythm. Lexical choice is the *last* and least of the
variety sources, not the only one. §4 shows 1-, 2-, and 3-sentence outputs with
different join relations from one content set — structural variety mad-libs
cannot produce.

### 2.4 Open lexicon detail

A concept (`returned`, `guarded`) maps to register-bucketed pools. The build net
seeds these from authored prose; e.g. `guarded → lyrical → ["holds herself like
a door only cracked", "keeps the table between you on purpose", …]`. The pool is
*open* in form (the realizer can be given a generated filler at build time for any
concept); it is *high-probability-subset* in the shipped table. Support is
nonzero for any sensible surface because the substitution slot's type accepts any
matching lexeme.

---

## 3. Content gate + salience steering

### 3.1 Hard gate

The realizer consumes a **commitment store**: a set of typed propositions known
true (world-facts + epistemic/perceptual frames). **The gate is structural, not a
post-filter:** step 1 of derivation requires that every initial tree substituted
into the frontier has a `carries: PropType` matching a *present* commitment, and
every `↓` content slot is lexicalized from a *committed* concept. There is no path
by which the derivation can assert a proposition absent from the store —
unasserted content has no tree to ride and no slot to fill.

Falsity enters **only via explicit license**: a commitment can be flagged
`pov_belief(holder)` or `dialogue_assertion(speaker, truth=false)` — these license
the gate to admit a *false-but-framed* proposition (a character lying/mistaken in
dialogue, POV-ignorance, altered senses). The frame travels with the proposition,
so the realizer renders "she says X" / "she believes X", never bare false X.

Crucially **phrasing stays full-support while content is hard-bounded**: the gate
constrains *which propositions* may be asserted; the grammar's support over *how*
to phrase any admitted proposition is unrestricted. SUPPORT and FAITHFULNESS are
cleanly orthogonal — exactly the thesis's factoring.

### 3.2 Salience steering

Each commitment carries a `salience` score (novelty × intensity × intent-
relevance, computed upstream — out of scope here, consumed as a number). The
realizer:

- **selects** the top-`budget` salient commitments to render (drops the rest —
  the prototype drops `contact_none`, salience 2);
- **orders** them by salience, but voice can re-order (a guarded voice
  foregrounds the negative-polarity guard affect before the positive glad —
  `guard_first` in the prototype);
- **biases tree choice** toward foregrounding high-salience content in main
  clauses and low-salience content in adjoined asides (synecdoche/restraint: the
  telling detail in the main clause, the rest demoted to a modifier or omitted).

Salience thus steers *what gets a main clause vs an aside vs nothing* — a depth
move (restraint), not just inclusion.

---

## 4. CONCRETE GENERATED OUTPUT — the decisive section

**Fixed committed content** (the commitment store for this scene):

```
returned    EVENT   sal9  player returned, mod=after_long_absence
guarded     AFFECT  sal8  Maren, guarded, polarity −
glad        AFFECT  sal7  Maren, glad,    polarity +
rain        AMBIENT sal4  raining
contact_none STATE  sal2  no contact            (dropped by salience budget)
```

Salience budget = 4 → gate-passed salient set: `[returned, guarded, glad, rain]`.

### 4.1 `[ACTUAL RUN]` — real prototype output

These are verbatim from running the toy TSG (`/tmp/tsg/tsg.py`), pasted unedited.
Each is one `(seed, voice)` draw. The prototype is a hand-weighted micro-grammar
that implements the FORM (substitution + rhetorical-relation adjunction joins +
ambient adjunction + STOP-via-max_clauses + register-weighted open lexicon +
splitmix64 integer PRNG). It is deliberately small; it demonstrates *mechanism*,
not the full inventory.

```
[seed=101 terse_guarded]
  You're back after all this time, but she keeps her distance.

[seed=102 lyrical_warm]
  After a silence that had set like cement, you found your way back here, and
  she keeps the table between you on purpose, and something unknots behind her
  sternum.

[seed=103 plain_neutral]
  You've returned, but she keeps her distance.

[seed=104 clipped_runon_warm]
  It's raining. You came back, and she keeps her distance, and she's glad, and
  she lets it stand.

[seed=105 lyrical_warm]
  The rain keeps up its low argument on the roof. You walked back into the
  doorway, and she holds herself like a door only cracked, though a warmth she
  doesn't sanction moves through her, and she lets it stand.

[seed=106 terse_guarded]
  Still raining. Back finally, but she stays put.

[seed=107 clipped_runon_warm]
  It's raining. You came back after so long, though she doesn't move toward you,
  and she's glad for it.

DETERMINISM CHECK (re-run seed=102 lyrical_warm twice): match=True
```

### 4.2 The derivations (so a skeptic can verify it's mechanism)

The variety axes that moved, per output — verifiable against the run:

- **Sentence count / cadence (STRUCTURE):** seed=103 is **one** clause-pair;
  seed=102 is **one long three-clause run-on**; seed=104/105/107 are **two
  sentences** (ambient adjoined as a separate framing sentence + a multi-clause
  body); seed=106 is **two terse fragments**. Sentence length ranges ~3 words
  ("Still raining.") to ~35. This is adjunction-count variety, not lexical swap.
- **Rhetorical-relation join (STRUCTURE):** 101/103 use `but` (contrast);
  102/104 use `runon` (paratactic `, and …`); 105 mixes `runon` + `concession`
  (`though`); 107 uses `concession` + `cause` (`glad for it`). Different RST
  relations from identical content = real structural variation.
- **Ambient attachment (STRUCTURE):** absent in 101/102/103; **pre-sentence
  framing** in 104/105/107; **tail** form available. Same proposition, different
  derivation site.
- **Register / lexicon (VOICE):** `returned` realizes as "back finally" (terse),
  "you've returned" (plain), "you found your way back here" / "you walked back
  into the doorway" (lyrical). `guarded` realizes as "she stays put" (terse) vs
  "she holds herself like a door only cracked" (lyrical). Register is a weighted
  draw per voice.
- **Salience ordering (CONTENT):** guarded voices foreground the negative guard
  affect (`guard_first`), warm voices let glad surface; `contact_none` (sal2) is
  gated out everywhere — never asserted (faithfulness).

### 4.3 `[HAND]` — two derivations the full grammar (not the toy) would add

To show the *form's* reach beyond the toy's small inventory, two hand-derived
outputs using elementary trees the build pass would induce but the toy omits:

- **Clipped-guarded, free-indirect interiority** (auxiliary tree:
  free-indirect-discourse adjunction at VP, STOP-high):
  > *"You're back." Flat. She doesn't get up — six months, and her hands stay
  > exactly where they are. The rain says the rest.*
  Derivation: initial EVENT tree (dialogue-anchored) → adjoin a *fragment-
  evaluation* auxiliary ("Flat.") at S → initial AFFECT(guarded) tree with a
  *concessive-temporal* auxiliary adjoined ("six months, and …") → ambient
  demoted to a synecdoche aside ("The rain says the rest" — restraint: glad is
  *withheld*, implied by the hesitation, not stated).
- **Lyrical-warm, subordination-deep, single sentence** (three stacked
  adjunctions, STOP-low at every site):
  > *When you came back — after the long quiet that had grown its own weather —
  > something in her that she'd have denied to your face eased, even as she kept
  > the table where it was.*
  Derivation: initial EVENT tree → temporal-subordinate auxiliary ("When …")
  adjoined at S → parenthetical-elaboration auxiliary ("— after … weather —")
  adjoined inside the temporal clause (recursion) → AFFECT(glad) initial with a
  *relative-clause* auxiliary ("that she'd have denied …") adjoined at NP →
  AFFECT(guarded) attached by a *concessive* join ("even as …"). Five
  adjunctions, one sentence — the depth dial turned all the way down on STOP.

These show the form spans terse-fragmentary → deeply-subordinate, and that
restraint/implication (withholding `glad`) is expressible as *omission of a tree*,
not a special case.

---

## 5. Stiffness confrontation (honest)

**Do the §4.1 outputs read stiff?** Mixed verdict, stated plainly:

- **Cleared the bar:** 101, 103, 106 read like competent clipped RP narration —
  better than mad-libs, comparable to a mid gemma turn. 105 and the §4.3
  hand-derivations read genuinely *literary*.
- **Did NOT clear it / read wooden:** seed=104 ("…and she's glad, and she lets it
  stand.") is the weakest — the run-on accumulation of bare `, and` clauses with a
  formulaic coda reads like a list, not prose. seed=102 and 107 have a faint
  template seam where two affect clauses are conjoined without fusion. The
  **enemy cadence — "clause, and clause, and clause" — appeared** at seed=104.
  This is the honest woodenness risk and I am not waving it away.

**Where this paradigm most risks woodenness, and the specific mitigations:**

1. **Concatenative joins read as lists (the seed=104 failure).** *Risk:* joining
   one-proposition-one-clause with `, and` is the flat 1:1 fusion ratio the prose
   doc warns against. *Mitigation in the form:* **multi-proposition fusion
   trees** — elementary trees whose single clause carries *two* propositions
   (the §4.3 "her hands stay exactly where they are" carries guarded+contact in
   one image; "something …eased, even as she kept the table" fuses glad+guarded).
   The build net induces these fusion trees from authored prose where one clause
   does several propositions' work; weighting them *above* concatenative joins for
   non-terse voices is the dial that kills seed=104's listiness. The toy lacks
   fusion trees — that is *why* seed=104 is its worst output, which is itself
   evidence the diagnosis is correct: the wooden output is exactly the output that
   used no fusion tree.
2. **A finite tree inventory could still feel samey across thousands of renders.**
   *Risk:* with too few elementary trees, structural variety saturates. *Mitigation:*
   adjunction recursion makes the *number* of derivable trees combinatorial in the
   inventory size (k adjunction sites × m auxiliary families × depth → exponential
   distinct derived trees), and the open lexicon multiplies it. A few hundred
   elementary trees yield astronomically many distinct sentences. Support is full.
3. **Conditioning could collapse to one cadence if voices aren't decorrelated.**
   *Risk:* if the build net's voice vectors are reworded versions of one taste,
   you get one rhythm. *Mitigation:* the build pass must induce voices from
   *genuinely different authored sources* (decorrelated style corpora) and the
   eval must check inter-voice cadence distance, not just intra-voice fluency.
4. **The hardest, un-finessed risk: fusion and implication are where TAG is
   weakest.** Substitution+adjunction compose *syntax* beautifully; they do not
   inherently compose *meaning into subtext*. Fusion trees push 1:1 off the floor
   but genuine implication (saying less than the propositional content and letting
   stance leak) is carried by *which trees the salience layer chooses to omit* —
   it leans hard on the salience/restraint layer (§3.2) and on the build net
   having induced subtext-bearing trees. **This is the real frontier and I do not
   claim it solved.** The form *admits* it (omission = not selecting a tree;
   subtext = a fusion tree whose surface understates its propositions); whether the
   build net can reliably *induce* such trees at quality is the open bet.

**Net honest judgment:** the form clears the non-trash floor everywhere and
clears the gemma-benchmark bar on most draws *as a toy with no fusion trees and a
~30-string lexicon*. With the induced fusion-tree inventory and a real lexicon it
plausibly reaches the meet-Opus-craft band on covered content. The seed=104-class
listy run-on is the live woodenness failure mode, it is *diagnosed to a specific
missing mechanism (fusion trees)*, and that mechanism is expressible in the same
formalism — which is the strongest thing I can honestly say short of building it.

---

## 6. Trade-offs + buildability of the distillation

**Strengths:**
- Cadence/structure is a **first-class independently-weighted axis** (adjunction
  count + join relation), not an emergent CFG side effect — directly answers "does
  tree-derivation give real structural variety": yes, via adjunction recursion.
- Shipped artifact is **pure finite serializable data** (trees + integer weight
  tables + open lexicon); runtime is a tiny net-free deterministic interpreter.
  Caches, diffs, replays — honors the data-over-code seam.
- Full support (recursive adjunction + open lexicon), clean three-way factoring
  (SUPPORT=grammar, TASTE=weights, FAITHFULNESS=structural gate), bit-for-bit
  determinism via integer splitmix64.

**Weaknesses / trade-offs:**
- **Meaning-fusion / subtext is not native** to substitution+adjunction; it is
  bolted on via induced fusion trees + the salience-restraint layer, and that
  induction is the unproven part (§5.4).
- **TAG induction from literary prose is hard.** The build pass leans on a frontier
  LLM as a TAG parser; corpus stats validate but the induction quality gates the
  whole grammar. This is a large, real build-time effort (the prose doc's "corpus
  may be hard to build" risk, inherited).
- **Linearization edge cases** (agreement, punctuation, pronoun binding across
  adjoined clauses) need a real morphology pass the toy fakes with `cap()` — a
  known, bounded engineering cost, not a research risk.

**Buildability verdict:** the *runtime* (tree interpreter + integer PRNG + gate)
is small and unambiguously buildable — days, not a moonshot. The *distillation*
(LLM-supervised TAG induction → tree inventory → conditioned smoothed weight
tables → decorrelated voice vectors → induced fusion trees) is a substantial
build-time pipeline whose **risk concentrates in inducing fusion/subtext-bearing
trees at quality**. Everything else (skeleton trees, register lexicon, join
relations, cadence dials) is straightforward induction the corpus supports.
