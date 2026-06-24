# Candidate C — The Bible Compiler: prose as a compiled scene-graph of authored situated passages

> **Frame:** Build-time Opus is a COMPILER, not an oracle. It ingests a deeply
> human-authored *character bible* and compiles it into a frozen, deterministic
> runtime artifact that the engine EXECUTES with no model in the loop.

---

## 1. Thesis

**A character is authored once as a deep prose bible; Opus compiles that bible
offline into a frozen, addressable LIBRARY OF SITUATED PASSAGES — fully-realized
prose fragments, each indexed by a canonicalized *situation signature* and stitched
by a small set of compiled deterministic continuity-edits — and the runtime is a
pure indexer-and-stitcher over that library with zero inference.**

The compiled runtime artifact is **NOT** a numeric→prose lens, an intent-spine, a
triple-graph, or a runtime grammar. It is a **content-addressed passage store plus
a compiled stitch program**: a frozen `.aeb` ("aeriea bible") blob containing
(a) tens of thousands of Opus-authored, situation-keyed prose passages, each
carrying provenance back to a state-predicate set, and (b) a compiled, branch-free
*stitch table* that the runtime walks to assemble, vary, and continuity-correct
passages deterministically. The soul lives in the **bible** (human-written) and is
*carried forward verbatim* by the compiler — the compiler curates and expands
authored voice, it never paraphrases state into prose with a rule.

---

## 2. Architecture

### 2.1 The input spec — the Character Bible (what a human authors; the soul lives here)

The author does **not** write `if mood > 0.8`. The author writes a **character
bible** — the document a novelist or a TTRPG author would write — in a structured
but prose-first format. Concretely, per character, a bible file containing:

- **Voice & interiority** — a long-form prose portrait: how this character speaks,
  what she notices, what she withholds, her tics, her cadence, her contradictions,
  her self-image, her private history. This is *pure prose*, multiple pages. It is
  the irreducible human input — the thing no scalar can hold — and it is the
  **conditioning context** every compiled passage is generated under.
- **Relationship arcs** — authored as *named stations on a trajectory*, not numbers:
  `wary-stranger → guarded-warmth → easy-intimacy → (betrayed) → cold-civility`.
  Each station is a paragraph of authored texture: what she does at this station,
  what she will and won't say, what the player's past actions *mean* to her here.
- **Situations** — the author enumerates the *kinds of moment* that matter:
  "player compliments her at guarded-warmth after a long absence," "player pushes
  her away at easy-intimacy," "she greets the player she remembers fondly." These
  are written as **prose sketches with holes named in plain language**, not slots:
  "she half-says the thing and stops; the absence should weigh."
- **Continuity hooks** — authored rules in plain language for what must persist:
  "if she was complimented and it landed, a later cool moment should carry the
  memory as a thing now *withdrawn*." These become compiled stitch-edits.
- **The world bible** (shared, not per-character) — places, objects, rituals,
  their connotations, authored once as prose the situations can reference.

The bible is **the spec**. It is *authored*, *reviewable*, *diffable*, and it is
the single artifact a human edits to change the character. Crucially the soul is in
the **voice portrait + the station textures + the situation sketches** — all prose,
all human, all carrying the implication/subtext/restraint the quality bar demands.

### 2.2 The build-time compile step (what Opus does — as compiler, not oracle)

Opus runs **offline, at build time**, as a deterministic-output *expander* over the
bible. It does NOT improvise per query. It does four things, each producing a
checked-in artifact:

1. **Situation enumeration & canonicalization.** From the authored situations and
   the relationship stations, the compiler enumerates the **finite cross-product of
   situation signatures that the bible declares to matter** — `(station × player-act
   × salient-memory-state × scene-context-bucket × affect-shade)`. Crucially the
   axes and their *buckets* are **declared by the author in the bible**, not
   invented by the model — this is what bounds the cross-product (see §7). The
   compiler emits the explicit, finite list of signatures.

2. **Passage authoring (best-of-N + curation).** For each signature, Opus — *under
   the full voice portrait + station texture as conditioning context* — writes
   K candidate fully-realized passages (the half-said line, the withdrawn warmth,
   the telling detail). A second Opus pass **curates** (best-of-N against the bar:
   faithfulness to the signature's predicate set, subtext, no boilerplate) and a
   third **refines**. The output for each signature is a small set (3–6) of frozen,
   fully-written prose variants. *Opus's own curated output is the floor; this is
   the prose-generation.md "Opus as build-time ingredient" move, but the artifact is
   the curated PROSE, not weights or scalars.*

3. **Provenance extraction.** For each frozen passage, the compiler records the
   **predicate set it asserts** (`contact.hand_on(forearm)`,
   `affect.bashful`, `memory.compliment.withdrawn`) — extracted at build time and
   *verified against the signature* so the runtime can later guarantee faithfulness
   without a model: a passage is only ever emitted for a runtime state that entails
   its recorded predicates.

4. **Stitch-table compilation.** The continuity hooks compile into a **branch-free
   stitch program**: deterministic edits that join/condition passages at runtime —
   pronoun & tense agreement, a memory-callback clause selected from a frozen
   callback set, an absence-weight insertion, elision when a fact was already
   described last beat. These are *authored continuity rules lowered to a finite
   table of fixed string-transforms keyed by signature-delta*, NOT a generative
   grammar (no recursive production rules; a fixed finite transform table — see §6's
   anti-collapse argument).

The compiler is **idempotent and content-addressed**: same bible bytes → same `.aeb`
bytes. Opus's nondeterminism is consumed entirely at build time and frozen; the
shipped artifact is a static blob.

### 2.3 The shippable artifact — the `.aeb` blob (concrete shape + finiteness)

```
Bible.aeb
├── passages[]            # ~10k–60k frozen prose strings (per major NPC)
│     ├─ sig: SituationSignature           # canonical key (see below)
│     ├─ variants: [str, str, ...]          # 3–6 Opus-curated realizations
│     └─ asserts: PredicateSet              # provenance: what each variant claims
├── callbacks[]           # frozen memory-callback clauses, keyed by memory-event
├── stitch_table          # finite map: (sig-delta, continuity-flag) → string-transform
├── signature_index       # perfect-hash: SituationSignature → passage row
└── fallback_lattice      # ordered coarsening of signature axes (see §5)

SituationSignature := hash(station, player_act, memory_bucket,
                           scene_bucket, affect_shade)   # all authored-declared buckets
```

Finiteness is **structural**: the author declares the axes and their *finite bucket
sets*; the cross-product is therefore a finite, enumerable list the compiler emits
in full. There is no open-ended state — `arousal: 0.72` is bucketed to an
authored-named shade (`rising-bashful`) at the bible boundary, so two close numeric
states map to the same signature and the runtime never faces a continuous key.

### 2.4 The runtime executor (deterministic, no LLM)

Per interaction, the runtime:

1. **Canonicalizes** the live sim state into a `SituationSignature` using the
   author-declared bucketing (the *only* place numbers touch prose, and they touch
   it as a *key derivation*, not as a phrasing input — see anti-collapse §6).
2. **Indexes** `signature_index[sig]` → a passage row (or walks the
   `fallback_lattice` on a miss, §5).
3. **Selects a variant** deterministically: `variant = variants[hash(seed,
   state_hash, sig) % len]` — seeded, replayable, non-repeating across equivalent
   visits.
4. **Verifies provenance**: asserts the chosen variant's `asserts` predicate set is
   entailed by the live state; if not (only possible on a fallback), drops to the
   next lattice level. Faithfulness is a *runtime invariant enforced by the frozen
   provenance*, with no model.
5. **Stitches**: applies the compiled `stitch_table` transforms for continuity
   (memory callback clause, absence weight, elision of already-said facts, pronoun/
   tense). All transforms are finite fixed string-ops.

This is a **pure function of `(state, seed, history)`** — bit-for-bit replayable.
No inference. The executor is ~indexer + table-walker; it is small and fast.

---

## 3. Worked example (real trajectory, actual prose, deterministic mechanics)

NPC: **Maren**. Bible station currently: **guarded-warmth**. Player returns after a
long absence. Seed fixed.

**Action 1 — `wait` then return (long absence at guarded-warmth, memory: 2
compliments that landed).**

Sim state canonicalizes to:
`sig = (station=guarded-warmth, act=return-after-absence, mem=compliments-landed,
scene=her-place-evening, affect=composed-but-glad)`.
`signature_index[sig]` hits passage row R₁. Seeded variant pick → `variants[1]`:

> *She's already half-turned when the door goes, like she'd been listening for it
> without meaning to. "Oh — you're back." A beat where she decides not to make it a
> question.*

Stitch table sees `mem=compliments-landed` + `absence` flag → inserts the
authored callback clause C₁₂ (frozen, keyed to that memory-event):

> *Whatever you said last time is still doing its quiet work; she stands a little
> straighter for it.*

Both strings are Opus-authored at build time under Maren's voice portrait. The
runtime only indexed, picked, and concatenated.

**Action 2 — `compliment`.**
`sig = (guarded-warmth, act=compliment, mem=compliments-landed-x3, scene=…,
affect=caught-out)`. Row R₂, seeded variant → `variants[0]`:

> *"You keep saying that." It comes out dry, but she doesn't look away this time,
> and the dryness doesn't reach her eyes.*

Provenance check: variant asserts `{affect.caught-out, memory.compliment.repeated,
gaze.held}` — all entailed. Emitted.

**Action 3 — `push_away`.**
This crosses a station edge: the bible's continuity hook says a cold act at
guarded-warmth *withdraws* the warmth and carries the memory as loss.
`sig = (guarded-warmth→cooling, act=push-away, mem=compliments-now-withdrawn, …)`.
Row R₃, variant → `variants[2]`:

> *She takes the step back herself, before you can make it mean anything. The
> straightness goes out of her. "Right," she says, to the floor. "Sure."*

Stitch: `mem=compliments-now-withdrawn` fires the *withdrawal* transform — selects
callback C₁₂′ (the authored "withdrawn" counterpart):

> *The thing your earlier words built is just... set down, carefully, where you
> both can see it.*

**Action 4 — `compliment` again (now at cooling).**
`sig = (cooling, act=compliment, mem=compliment-after-the-cold, affect=closed)`.
Row R₄, variant → `variants[1]`:

> *"Don't." Not sharp. Just tired. She's heard you build to this before, and she
> knows where it goes now.*

Every line is human-authored prose, frozen at build time, selected and stitched
deterministically. The *station-crossing* and the *memory withdrawal* — the
aliveness — are authored continuity hooks compiled into the stitch table, not
numbers re-skinned. Re-running the exact trajectory on the same seed reproduces
these strings byte-for-byte. A *different* seed at action 1 would pick
`variants[0]` or `[2]` — equally-authored, equally-faithful — so a second playthrough
reads fresh, never identical.

---

## 4. How it achieves "alive"

- **Continuity** is *authored as trajectory* (the station model) and *compiled* into
  signature-delta edges, so the same act reads differently depending on where the
  relationship sits and what just happened — because the author wrote *that*
  station's version, not because a scalar crossed a threshold. The push-away at
  guarded-warmth and the push-away at intimacy are **different authored passages**,
  not the same line relabeled.
- **Memory** is concrete and *withdrawable*: memory-events bucket into the signature
  and select authored callback clauses (C₁₂ landed / C₁₂′ withdrawn). The NPC
  refers to *the specific thing* ("you keep saying that"), and the reference
  *changes meaning* as the relationship turns — the hallmark of an NPC who
  remembers you and has a life.
- **Reactivity**: every player act is an axis of the signature; the artifact has an
  authored passage for the *combination*, so reactions are specific, not generic.
- **Presence** comes from the **voice portrait** conditioning every passage — the
  same authorial hand across thousands of passages gives a consistent interiority no
  per-line template can fake. The character *sounds like one person* because one
  bible authored all of her.

The soul survives compilation because **the compiler never paraphrases state into
prose** — it carries authored prose forward verbatim and only *indexes* it by state.

---

## 5. Cache-miss / unseen situation (deterministic)

A miss = a live signature with no `signature_index` row (a combination the bible
didn't enumerate). Handled by the **fallback lattice**, a compiled, ordered
*coarsening* of the signature axes — the semantic-LOD "faithful coarsening" applied
to keys:

1. **Coarsen one axis at a time, in an author-declared priority order** (e.g. drop
   `scene_bucket` to `any`, then collapse `affect_shade` to its parent band), and
   re-index. The lattice is precompiled so the walk is a deterministic, finite
   descent — same miss → same fallback row every time.
2. At each level, **provenance is re-checked**: a coarser passage only asserts
   coarser predicates (authored to be true across the collapsed bucket), so a
   fallback is *less specific but never false* — no popping, no confabulation.
3. The **floor of the lattice** is a per-station "neutral but in-voice" passage set
   the author writes explicitly as the safety net — still Maren's voice, still
   non-boilerplate, just less situation-specific. This is the **non-trash floor**
   made concrete: the worst case is *authored generic*, never mad-libs.

Misses are also **logged at build-adjacent playtest** so the author can promote a
hot missed signature into a first-class authored passage — the bible grows toward
coverage where play actually goes, rather than enumerating dead combinations.

The runtime never invents prose on a miss; it descends a frozen lattice to the most
specific *authored* passage whose provenance still holds.

---

## 6. What it hides/assumes; trade-offs; why it does NOT collapse into the rejected designs

**Assumes / hides:**
- **The authoring burden is real and large** (§7). The soul-quality ceiling is the
  *bible's* quality — a thin bible yields thin prose (this is the honest
  "depth-is-upstream" inheritance, here relocated from sim-state to authored-bible).
- It assumes **the situation space the author declares actually covers what play
  reaches** — false at first; closed by the miss-driven authoring loop, not by
  magic generalization.
- It hides **combinatorial pressure** behind authored bucketing: if the author
  declares too many fine axes, the cross-product explodes (§7); too few, and prose
  is under-reactive. The bucketing *is* the design tension.

**Why it is NOT the rejected (a) "prose as a deterministic LENS over scalars":**
The rejected design *computes phrasing from numbers* (`if mood>0.8 → "eyes
bright"`). Here numbers are used in **exactly one place — deriving a discrete index
key** — and never as a phrasing input. The prose for a signature is **authored
verbatim by Opus under the voice portrait**, not synthesized from the scalar. Swap
the realizer's band-functions for a lookup of human prose and you have changed the
*kind* of artifact: the existing `npc_realizer.gd` *generates the sentence from the
band*; this *retrieves an authored sentence by the band*. The band is a filing
system, not a generator. (The current scaffold is literally (a); this replaces it.)

**Why it is NOT (b) the brain→intent→realizer spine:** there is no runtime
communicative-intent tuple and no realizer turning intent into surface. The brain's
state is canonicalized straight to a *content address*; there is no
meaning-representation intermediary being realized. The author's interiority lives
in *prose*, compiled to *prose*, addressed by *state* — the spine's middle seam is
absent by construction.

**Why it is NOT (c) a triple-graph:** no subject-predicate-object semantic graph,
no prevalence weights, no traversal-and-compose. The provenance predicate sets are
*verification tags*, not a generative substrate — they gate emission, they never
*produce* a sentence. Composition is a finite fixed stitch-table, not graph
traversal.

**Why it is NOT a runtime grammar:** the stitch table is **finite and branch-free
with no recursion** — a bounded set of fixed string-transforms, not productions that
compose unboundedly. It cannot generate a sentence that wasn't authored; it can only
join, elide, and agree across authored passages. That bound is what keeps craft at
the authored ceiling and forbids the mad-libs failure mode (a grammar's
recombination is exactly what produces boilerplate).

**Honest trade-offs:** ceiling = author's craft × Opus's curation (high, but capped
by authoring labor). Weakness = *coverage breadth* — novel combinations fall to the
lattice (good-not-great) until authored. Strength = *every emitted line is genuinely
good prose a human and Opus signed off on*, with hard faithfulness and determinism,
and a consistent voice across a whole character. It trades the rejected designs'
*infinite-but-shallow* generativity for *finite-but-deep* authored coverage that
grows toward play.

---

## 7. Buildability — finite/shippable, or fig leaf?

**It is buildable, and the scale is the honest cost — not a fig leaf.** Concretely:

- **Per major NPC**: declare ~5 axes with ~4–8 authored buckets each. Naive
  cross-product is large (8⁵≈33k) but the **author prunes to *reachable* combos** —
  most (station × act × memory) tuples are nonsensical and never enumerated. A
  realistic *authored* signature count per deep NPC is **~2k–8k passages × 3–6
  variants** = tens of thousands of frozen strings. Opus writes these at build time
  in batched best-of-N; this is hours-to-days of *offline GPU/$*, not a person
  hand-typing each — the human writes the **bible** (tens of pages), the compiler
  expands it.
- **The human cost** is writing and maintaining the bible per character (days of
  skilled authoring) — comparable to writing a deep TiTS/CoC companion, which is the
  proven-shippable reference. Aeriea's bet is that **one bible compiles to an
  order-of-magnitude more situated coverage** than a human typing each line, because
  Opus expands the authored voice across the declared signature space.
- **The blob ships**: tens of thousands of short strings per NPC is single-digit MB
  compressed — trivially shippable. A dozen deep NPCs is well within a game's asset
  budget.
- **The fig-leaf test**: a fig leaf would be "Opus generates it and we pretend it's
  finite." Here the artifact is *concretely finite* (enumerated signatures, frozen
  variants, a compiled table), *concretely authored* (the bible is the reviewable
  source), and *concretely shippable* (a static blob). The model is genuinely absent
  at runtime. The cost is genuine authoring + offline compile labor, paid honestly.

The unresolved risk is **breadth**: deep NPCs are affordable; a *world* of hundreds
of incidental NPCs at this depth is not, and they must fall to shallower shared
bibles or the lattice floor. That tiering (deep-bible principals vs. lattice-floor
extras) is the real open design question this candidate leaves on the table.
