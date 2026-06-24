# Grammar Candidate B — Construction Grammar (CxG) realizer

Status: **DESIGN CANDIDATE** (one of four parallel designs for the text-gen
grammar thesis). Instantiates the fixed thesis (full-support generative grammar,
build-time-LLM-shaped distribution, hard content gate) under the **Construction
Grammar** paradigm. Includes a real, run toy prototype (`/tmp/cxg_proto/cxg.py`)
whose actual output is pasted in §4.

---

## 0. One-paragraph claim

A construction is a typed **form-meaning pairing** with slots. Generation is a
deterministic, seeded **top-down recursive realization** of a committed-content
goal: pick a licensed construction for the goal's semantic type, fill its typed
slots by recursively picking lower-grain constructions, down to lexical leaves.
Because constructions exist at **multiple grains** — discourse → clause /
argument-structure → phrasal idiom → word — the *first* choice the realizer makes
is **which clause-frame / discourse-frame stages the beat**, so cadence and
structure vary at the root, not just the lexicon. The constructicon (the inventory
+ its register/selectional/preference weights) is **mined at build time by a
frontier LLM from high-quality authored prose**; it ships as a **finite, static,
net-free data table**. The content gate is structural: a construction is
**licensed only if its `requires` commitments hold**, so no proposition can be
asserted that the commitment store does not entail. Taste is a **register-affinity
vector** (a point/region in a taste-space) that re-weights construction choice;
voice/mood/register move it without locking it.

This factors the thesis's three mechanisms exactly:
- **SUPPORT** = the constructicon's productive recombination + open lexical
  constructions (any grammatical sentence is reachable; finite *inventory*, infinite
  *output language*).
- **TASTE** = the register-affinity weighting over construction choice (the
  taste-space).
- **FAITHFULNESS** = the `requires`/license gate on every construction.

---

## 1. The paradigm, concretely

### 1.1 What a construction IS (data shape)

A construction is a static record (ships as data, e.g. a Godot `Resource` /
packed dictionary; shown here as the prototype's dict):

```
Construction := {
  id        : stable name (e.g. "C.gaze_finds")
  sem       : the MEANING category it realizes   -- e.g. NOTICE_CLAUSE, AMBIENT,
                                                     GUARDED_OPENER, ACTOR_REF_POSS
  form      : ordered list of FORM ELEMENTS, each either
                ("lit",  "fixed text")
                ("slot", sem_type, role, register_pref?)   -- a typed hole
  reg       : set of register tags it carries   -- {terse, wry, lyric, intimate,
                                                     plain, gruff, ...}  (taste coord)
  requires  : list of commitment keys that must hold for it to be LICENSED  (gate)
  weight    : build-time-learned base preference mass (integer)
}
```

Key properties:

- **Form-meaning pairing at every grain.** Unlike a bare CFG nonterminal (pure
  syntax, no meaning), a construction's `sem` *is* a meaning, its `reg` *is* a
  usage/register, and its `requires` *is* a truth-condition. A clause-level
  **argument-structure construction** ("X's gaze finds Y", "X registers Y", the
  addressee-fronted "And then there you are again, …") carries idiomatic
  flavor and cadence as a unit — that flavor is the lever against stiffness (§5).
- **Slots are typed by meaning, not by part-of-speech.** A slot `("slot",
  "ABSENCE_ADJUNCT", …)` is filled by *any* construction whose `sem ==
  ABSENCE_ADJUNCT` and whose register is compatible. This is what gives **full
  support**: the slot is an open class, and new lower-grain constructions extend it
  without touching the parent.
- **Multi-grain.** A discourse construction's slot is filled by a clause
  construction; a clause construction's slot by a phrasal idiom or a lexical
  construction; ad infinitum down to open lexical leaves. Selectional preference
  (e.g. CASE: a possessor slot wants `ACTOR_REF_POSS`, a subject slot wants
  `ACTOR_REF_NOM`) is encoded in the slot's `sem_type` — agreement is part of the
  construction contract, not a post-hoc patch (the prototype demonstrates this
  fixing a real "She's head" agreement bug, §4/§5).

### 1.2 The constructicon structure

The shipped constructicon is **indexed by `sem`**: `BY_SEM[sem] -> [constructions]`.
Realization of a `sem` is "choose among `BY_SEM[sem]`". Grains are not a separate
type system — they fall out of which `sem`s appear as *parents* vs *slots*.
Discourse-grain `sem`s (BEAT_NOTICE) sit at the root; lexical-grain `sem`s
(ACTOR_REF_NOM) are pure leaves (`form` is all `lit`).

### 1.3 How composition + realization works at runtime (net-free, deterministic)

```
realize(sem, rng, voice, commit):
    cands   = [c in BY_SEM[sem] if licensed(c, commit)]      # CONTENT GATE
    weighted= [(c, c.weight * voice_affinity(c, voice)) for c in cands]   # TASTE
    chosen  = rng.pick(weighted)                              # SEEDED CHOICE
    out = []
    for element in chosen.form:
        if element is lit:  out += element.text
        else (slot):        out += realize(element.sem, rng, voice, commit)   # RECURSE
    return join(out)
```

- **Determinism.** All choice flows through a single seeded integer PRNG
  (splitmix64; **integer-only, no float, no runtime string hashing**) →
  cross-platform bit-stable. `rng.pick` is a deterministic weighted draw. Same
  `(seed, state, voice, constructicon)` → identical bytes. The prototype verifies
  byte-equality on repeat. The `state` feeds the seed as a frozen integer
  **state-key** (the salience layer, §3, derives it); the seed branches the choice
  tree.
- **Variety at the ROOT.** The first `realize("BEAT_NOTICE", …)` call picks the
  *discourse frame* (perception-first vs speech-first vs interior-only), then the
  *clause frame*. Structure/cadence variety is decided **before** any word — this
  is the anti-"lexical-swap-under-fixed-cadence" guarantee, baked into the
  mechanism (the enemy named in the constraints cannot occur, because the cadence is
  itself a seeded choice over argument-structure constructions).
- **Full support.** Output language is unbounded: open lexical constructions +
  productive slot-filling + recursive embedding mean any sentence the constructicon
  can compose is reachable with nonzero probability (every licensed cxn has nonzero
  weight). The *inventory* is finite and shippable; the *generated language* is not.

---

## 2. Distillation pipeline (build-time net + authored prose → constructicon)

The constructicon and its weights are **induced at build time**; nothing about this
runs at runtime.

**Sources (per the brief — REAL high-quality authored prose, not gemma logs).**
Literary fiction and strong authored RP. The SillyTavern corpus
(`ref-corpus.md`) is a **benchmark only** (mediocre, and content-gated for
minor/abuse material) — its top-quartile gemma turns set the *floor bar to beat*,
not a source to mine.

**Pipeline:**

1. **Construction mining (net does the heavy lifting).** The frontier LLM reads
   authored passages and abstracts recurring **form-meaning-register patterns**
   into candidate constructions: "this clause is an argument-structure construction
   meaning NOTICE, register {lyric}, form `X's gaze finds Y <absence-adjunct>`".
   Pure programmatic n-gram mining is insufficient — abstracting the form-meaning
   pairing (which spans are fixed `lit`, which are typed slots, what the slot's
   `sem` is) is exactly the semantic-abstraction job a net does and a regex cannot.
2. **Typing + slot abstraction.** The net proposes the slot `sem` types and the
   selectional preferences (case, animacy, the CASE split that fixes agreement),
   and the `requires` truth-conditions (which committed propositions license the
   construction). This is the LLM-as-oracle-at-the-leaf: it labels, it does not run
   the loop.
3. **Register/voice conditioning → weights.** The net tags each construction with
   register affinities and assigns base `weight` from corpus frequency conditioned
   on register. Distinct authored voices (a terse noir source vs a lyric literary
   source) yield distinct **register-affinity vectors** = the taste-space anchors
   (§1.3, the `VOICES` table in the prototype).
4. **Curation + dedup + content gate.** Human-signs-every-construction (per
   `ref-corpus.md` discipline); minor/abuse material hard-excluded; near-duplicate
   constructions collapsed.
5. **Freeze.** Emit the static table.

**THE SHIPPED ARTIFACT** is a **finite, static constructicon file**: a list of
construction records (id, sem, form, reg, requires, weight) + the per-voice
register-affinity vectors. It is **pure data, net-free, deterministic-eval**. No
weights of any neural network ship; no inference runs at runtime. Finiteness: the
*inventory* is finite (thousands–tens-of-thousands of constructions across grains);
the *output language* is infinite via recombination. This is the thesis's
"build-time net shapes the distribution; runtime is net-free" made literal — the
net's entire contribution is compiled into the table's *membership and weights*.

---

## 3. Content gate + salience steering

**Hard gate (no contradiction / no hallucination).** A construction is `licensed`
iff **every key in its `requires` holds in the commitment store**. The store holds
world-facts + epistemic/speech/perceptual frames (here: `event.notice_return`,
`event.long_absence`, `stance.guarded`, `stance.glad`, `ambient.raining`). A
construction that would assert an uncommitted proposition (e.g. "she smiles warmly"
requiring `stance.warm_open`, not committed) is **never in the candidate set**, so
it is unreachable — falsity is structurally impossible. **Phrasing stays
full-support** because the gate filters *which* constructions, never *how many ways*
the licensed meaning can be phrased: the entire phrasing freedom lives *below* the
gate. Falsity is reachable only via an **explicit license flag** on the commitment
(POV-ignorance / lying-in-dialogue / altered-senses) which flips a `requires` from
"true-fact" to "believed/asserted-fact" — not exercised in §4.

**Salience steering (toward the SALIENT committed content).** Not every committed
fact must surface. The salience layer (the upstream stage from
`prose-generation.md`) scores committed propositions by novelty/intensity/intent-
relevance and emits **(a)** the set of *must-realize* `sem` goals (here:
BEAT_NOTICE, which transitively pulls in the notice event + absence + stance +
ambient that the chosen frame's slots demand) and **(b)** the frozen integer
**state-key** that seeds the choice tree. Restraint falls out naturally: the
`D.interior_only` discourse construction (run 3) realizes the beat with **no spoken
line** — a guarded character who says nothing — because the salience+gate let a
licensed lower-arity frame win. The seed branches **at the discourse/clause frame**
(what to stage, what to leave unsaid), i.e. upstream variety of *conception*, not
lexicon — exactly the anti-degenerate-freshness requirement.

---

## 4. CONCRETE GENERATED OUTPUT (decisive — RUN, not hand-written)

Fixed committed content: **"Maren notices the player has returned after a long
absence; guarded but glad; it is raining."**

The following is **actual run output** of the toy prototype
(`/tmp/cxg_proto/cxg.py`, ~290 lines, hand-built micro-constructicon of ~30
constructions across 4 grains). **Labelled: RUN OUTPUT (verbatim), not
hand-derived.** Each shows the construction composition path so the mechanism is
visible.

```
--- Realization 1  (seed=101, voice=terse_wry) ---
"You came back," she says, not quite looking at you. She registers you after all this time. Rain ticks against the window.
  constructions: D.speech_then_percept > S.glad_undercut > GL.missed > T.tag_dry > C.registers > N.she.nom > A.after_all_this_time > R.rain_on_glass

--- Realization 2  (seed=202, voice=lyric_warm) ---
The rain is coming down soft and steady, blurring the street to grey. And then there you are again, the months since collapsing to nothing. "I didn't think you would," she says, not quite looking at you.
  constructions: D.percept_then_speech > R.rain_lyric > C.there_you_are > A.np_months > S.glad_undercut > GL.didnt_expect > T.tag_dry

--- Realization 3  (seed=303, voice=gruff_guard) ---
The rain is coming down soft and steady, blurring the street to grey. And then there you are again, the months since collapsing to nothing.
  constructions: D.interior_only > R.rain_lyric > C.there_you_are > A.np_months

--- Realization 4  (seed=404, voice=intimate_soft) ---
Outside, the rain keeps on. Maren's gaze finds you after all this time. "I didn't think you would," she says, not quite looking at you.
  constructions: D.percept_then_speech > R.rain_coda > C.gaze_finds > N.maren.poss > A.after_all_this_time > S.glad_undercut > GL.didnt_expect > T.tag_dry

--- Realization 5  (seed=505, voice=plain_flat) ---
Rain ticks against the window. Her head comes up the moment you cross the threshold. "So. You're back."
  constructions: D.percept_then_speech > R.rain_on_glass > C.head_comes_up > N.her.poss > S.guarded_dryline > G.youre_back

--- Realization 6  (seed=606, voice=lyric_warm) ---
The rain hushes everything past the glass. She registers you after being gone so long. "You came back," she says, and the wariness in it doesn't quite cover the rest.
  constructions: D.percept_then_speech > R.rain_intimate > C.registers > N.she.nom > A.so_long_gone > S.glad_undercut > GL.missed > T.tag_soft

DETERMINISM (seed 101 twice identical): True
```

**What the composition paths prove (real mechanism, not free-writing):**

- **Structure/cadence varies at the ROOT, not the lexicon.** Realizations differ in
  *discourse frame* — speech-first (1), perception-first (2,4,5,6), interior-only
  no-speech (3) — and in *clause/argument-structure construction* —
  caused-motion "gaze finds you" (4), transitive "registers you" (1,6),
  addressee-fronted existential "And then there you are again" (2,3),
  double-take "head comes up the moment you cross the threshold" (5). These are
  genuinely different sentence skeletons, not one skeleton with swapped words.
- **Voice/register varies independently.** `terse_wry` (1) → "registers you" + flat
  rain; `lyric_warm` (2,6) → "soft and steady, blurring the street to grey" + the
  "wariness…doesn't quite cover the rest" tag; `plain_flat` (5) → clipped "So.
  You're back." The same committed content reads in clearly different voices.
- **Guarded-but-glad is FUSED, not stated.** The `S.glad_undercut` construction
  (`"<glad core>," <guarded tag>`) carries both stances in one line: glad core ("You
  came back" / "I didn't think you would") + guarded tag ("not quite looking at
  you" / "the wariness…doesn't quite cover the rest"). The said and the meant are
  pulled apart inside one construction — subtext as a unit of the grammar, the CxG
  answer to the literal-vs-stance-gap depth move.
- **Content gate held.** Every clause traces to a committed proposition (notice /
  absence / stance / rain). Nothing uncommitted appears.
- **Determinism verified** (byte-identical on repeat).
- **Restraint emerged** (run 3: guarded → no spoken line, via a lower-arity
  discourse construction the gate licensed).

---

## 5. Stiffness confrontation (honest)

`prose-generation.md` conceded compositional grammars are "notorious for wooden
output" and waved it away. I may not. Honest judgment of the six outputs:

**Do they read stiff?** Mostly **no** — they clear the strong-gemma benchmark bar
(`ref-corpus.md`: sensory-grounded, voice-distinct, reactive, restraint-over-
statement). 1, 4, 5, 6 read like competent authored RP. **But** the woodenness risk
is real and I can name exactly where it bites:

1. **Idiom-tile seams — the central CxG risk.** When a slot's filler is a
   self-contained idiom, the join can read as *assembled tiles*: e.g. run 1's
   "…after all this time. Rain ticks against the window." — the rain coda is
   grammatical and on-register but feels **bolted on**, not woven. This is the
   "assembled idiom-tiles" failure the brief warns of. **Mitigation:** the join must
   itself be a construction (a discourse-grain cxn that *fuses* ambient into the
   clause — "Rain at the glass, and her gaze finds you anyway" — rather than two
   independent sentences). The prototype's discourse cxns concatenate with ". "; a
   real constructicon needs **cohesion constructions** (RST-style: contrast,
   concession, cause) as first-class members so adjacent material is *related*, not
   merely adjacent. This is the single most important anti-stiffness investment.
2. **Combinatorial register bleed.** Run 3 (gruff_guard voice) picked the *lyric*
   rain + lyric absence-NP, because register affinity is a **soft weight**, not a
   hard filter (deliberately — taste is a SPACE, not a lock). The output is still
   good, but the voice is less crisp than a pure-gruff draw. Honest trade: hard
   filters would crisp the voice but **shrink support and risk repetition**; soft
   weights keep full support at the cost of occasional cross-register draws. I keep
   soft weights and rely on a denser constructicon so each voice has enough
   on-register fillers that bleed is rare.
3. **Slot-granularity rigidity.** If constructions are too coarse (whole clauses as
   `lit`), output is high-quality but low-variety (few skeletons). If too fine
   (every word a slot), it degenerates toward mad-libs and stiffness returns. CxG's
   sweet spot is **mid-grain argument-structure + idiom constructions** with a few
   open lexical slots — which is exactly where the prototype sits and where it reads
   best.

**Where CxG is STRUCTURALLY stronger than a bare CFG against stiffness:** because
constructions carry **register and idiomatic flavor as whole units**, the realizer
emits *authored-feeling phrases* ("not quite looking at you", "doesn't quite cover
the rest") that a syntax-only grammar would have to assemble word-by-word (and
wood). The flavor is pre-baked into the construction by the build-time net from real
authored prose. **The honest verdict:** §4 clears the stiffness bar *given a
constructicon dense enough and with cohesion constructions*; the prototype is dense
enough to *show* this on one beat, and the named risks (#1 especially) are real
engineering, not solved.

---

## 6. Trade-offs + buildability

**For:**
- **Determinism is trivial and total** — pure data + seeded integer PRNG, no float,
  no runtime net. The hardest cross-platform invariant is the easiest thing here.
- **The gate is structural, not bolted-on** — `requires` filtering makes
  hallucination unreachable rather than detected-after-the-fact (the
  SESSION-RECORD's "detection is a copout" lesson respected: faithfulness is
  *generation-side*, not a critic).
- **Variety is at the root** — structure/cadence cannot collapse to lexical-swap,
  by construction.
- **Taste is a space** — register-affinity vectors interpolate; mood/register move
  the point continuously without new constructions.
- **The build-time net's contribution is fully compiled** — clean
  thesis-compliance.

**Against / risks:**
- **Idiom-tile seams** (§5#1) — the real woodenness risk; demands cohesion
  constructions, which are the hardest grain to mine. **Biggest risk.**
- **Constructicon size + curation cost** — mining tens of thousands of
  human-signed constructions from authored prose is a large build-time effort, and
  `prose-generation.md` flags exactly this ("the corpus may be hard to build").
- **Coverage** — a committed `sem` with no licensed construction produces a gap
  (`<SEM?>` in the prototype). Full support is *over the language*, but coverage
  *of every committed meaning* needs the constructicon to span the world-model's
  proposition types — an open, large surface.
- **Selectional-preference completeness** — the agreement bug fixed in §4 (CASE
  split) shows these must be exhaustive; missing ones produce real grammatical
  defects that only playtesting catches (per the SESSION-RECORD: test on REAL
  OUTPUT — which is why §4 is run, not hand-derived).

**Buildable now?** The *runtime* is small and shippable today (the prototype is the
runtime, ~120 lines of real logic; a Godot port is straightforward static-data +
seeded RNG). The *build-time mining pipeline* is the large unproven effort, shared
by every candidate. The runtime/gate/determinism are solved; the constructicon
density + cohesion constructions are the bet.

---

## Appendix: prototype provenance

- Code: `/tmp/cxg_proto/cxg.py` (ephemeral relay scratch, not tracked).
- §4 is **verbatim run output**, regenerated by `python3 cxg.py`. Determinism line
  is the prototype's own self-check.
- The prototype's micro-constructicon was hand-built to *demonstrate the
  mechanism*; in production it is the build-time-net-mined artifact of §2. The
  hand-built version is the existence proof that the data shape + recursive
  realizer + gate + seeded choice **actually run and produce varied, faithful,
  grammatical prose** — not a paper claim.
