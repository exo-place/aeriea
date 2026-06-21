# Aeriea substrate core — the synthesized minimal algebra

Status: **DESIGN OUTPUT of the design-it-twice pass — PENDING empirical
consumer-validation** (2026-06-22). This is the synthesized winner of five
adversarially-de-poisoned candidate lenses. It is *not* frozen and *not* yet
validated: every primitive below carries assumptions that are invisible from
inside the interface, and the closing section names exactly which ones a minimal
first consumer must stress before any of this is trusted. The cathedral trap is
real; this doc is a poison-detector's target, not a cathedral.

Scope: the minimal, assumption-free core algebra ("the game's lambda calculus")
for aeriea's substrate — the primitive set, its semantics, the hard case worked
end-to-end through it, the root-framing disagreement among the candidates and its
resolution, the single shared blind spot all five candidates harbored, and the
empirical de-poisoning agenda. Upstream thesis: `substrate-foundations.md`. The
five candidate artifacts this synthesizes are under
`docs/artifacts/substrate-design/`.

---

## What this synthesizes

Five independently-framed candidates were generated, each committed fully to one
lens, then red-teamed adversarially:

- `docs/artifacts/substrate-design/candidate-relational.md` — Datalog / typed
  relations (**survives**, adversary score 6.5 — the only survivor).
- `docs/artifacts/substrate-design/candidate-event-algebra.md` — log-as-sole-
  primitive, state = fold∘project (score 4.5).
- `docs/artifacts/substrate-design/candidate-actor-moo.md` — defocus-lineage
  objects+messages+RESOLVE (score 42 *against*, i.e. heavily poisoned).
- `docs/artifacts/substrate-design/candidate-constraint-store.md` — world as a
  growing constraint store, solve = materialize (score 4).
- `docs/artifacts/substrate-design/candidate-capability-effects.md` — entities
  are capabilities, behavior is algebraic effects (score 5.5).

The relational/Datalog candidate is taken as the **base** (highest-surviving),
and the safe, verdict-flagged best ideas from the other four are grafted onto it.
The result is a hybrid, as expected: a relational base whose generation seam is
re-shaped by the constraint-store's *trichotomy*, whose write discipline is the
event-algebra's *commit-unifies-create-and-observe*, and whose capability model
is the shared capability-handle design all five converged on independently.

---

## 1. The root-framing disagreement, named and resolved

The candidates do **not** merely differ in detail — two of them disagree with the
other three on the *root framing of what the substrate fundamentally is*, and
that disagreement is exactly where the deepest bug lives.

**The split: is the primitive a NOUN-bearing process, or a derivation?**

- **Process-framing (actor-MOO, capability-effects).** The world is a population
  of *things that act*: objects that receive messages, capabilities that answer
  effects. State lives *in* the thing; materialization is *the thing being forced
  to answer*. The substrate's job is to host autonomous loci of behavior.
- **Derivation-framing (relational, event-algebra, constraint-store).** There are
  no things. There is a seed plus an append-only record, and *everything else is a
  pure function of it* — a query answer (relational), a fold result
  (event-algebra), a solver witness (constraint-store). State is never *in*
  anything; it is *derived*. The substrate's job is to be a deterministic
  derivation engine.

**This is not a stylistic choice — it is the load-bearing decision, and the
adversary scores settle it decisively.** The two process-framed candidates scored
*worst* (actor-MOO 42-against, capability-effects 5.5) for the *same structural
reason*: the process framing keeps state *inside* a locus, which (a) re-creates
"store the world" the moment any locus caches what it computed (defocus's verified
`objects: BTreeMap<Identity, Object>` world store, `world.rs:118`), and (b)
re-opens the facade hole, because a locus that can *read another locus's state
directly* during evaluation bypasses deterministic revelation (defocus's verified
`eval` reading `world_objects` across the whole map, `eval.rs:1135`). The process
framing's own honest poison-sections admit both: actor-MOO concedes
monotone-`RESOLVE` is asserted not enforced and global consistency is "pushed to
the margins"; capability-effects concedes its memoized fold checkpoints "must be
provably pure caches or they silently become the world-store the law forbids."

**Resolution: adopt the derivation-framing as the root.** `state = f(seed, log)`
is taken literally — there is no noun, no object box, no locus that *has* state.
The substrate is a deterministic derivation over an append-only log. This is the
relational candidate's clean unification (the EDB *is* the commit log) generalized:
the log is the sole source of truth, and entities/places/minds/time are all
*views* derived from it. The process-framing's one genuinely elegant idea —
"an entity's existence is a message it has not yet been forced to answer" — is
**kept as a framing for the eager↔lazy slide** (an underivable row is an
unanswered query) but **decoupled from state-living-in-a-locus**, which is the
poison the verdict flagged.

> The honest cost of this resolution: the derivation-framing **gives up genuine
> off-screen autonomy** — the world is reconstructed-on-encounter, not alive when
> unwatched. This is already the decided target (`substrate-foundations.md` →
> observer-indistinguishability; the parked "really real" direction). The
> resolution is consistent with the thesis, not a new concession.

---

## 2. THE SHARED BLIND SPOT (the single most important finding)

**Every one of the five candidates baked in the same hidden assumption: that the
content of a generated thing is a pure function of its NAME (its canonical key /
identity / descriptor).** This is the poison a single-pass design would have
shipped, because it is invisible from inside every one of the five interfaces —
all five independently reached for it, which is precisely the signature of a true
blind spot rather than a candidate-specific flaw.

Where it hides, candidate by candidate:

- **relational:** `gen(rel, key, prior)` seeds RNG by `hash(seed, rel, key)` —
  "the key is the canonical name," content = f(name). The verdict's top poison.
- **event-algebra:** `key : Descriptor → Query`, content-addressed by descriptor;
  `draw` keyed on `key(Query)`.
- **actor-MOO:** `RESOLVE` is pure over `(c.seed, c.state-so-far, demand)`, seed
  derived from the cap's identity path.
- **constraint-store:** `key(descriptor) → Key`, "identity derived from
  structure," `solve` pure over canonical-keys.
- **capability-effects:** `Identity = derive(parent_identity, salt)`, "identity
  is a pure function of a content-path."

**Why it is poison.** Content-determined-by-name is *false for anything whose
content genuinely depends on its causal neighborhood rather than its label*. The
weathered glyph's microdetail depends on three years of unobserved micro-events
and on its *neighbors* (the crack that propagated from the adjacent flaw, the
lichen that spread from the next rock), not on the string `g7`. The relational
candidate even half-admits this by smuggling the *interval* `(from,to)` into
`elapse`'s seed — quietly conceding that the key alone is not canonical, that a
*second* identity (the causal coordinate) had to be fused in. Once you grant that,
the dam breaks: content depends on the *cone*, not the name.

**The de-poisoned position (the correction this synthesis makes):** identity and
generative provenance are **two separate commitments that must not be fused.**

1. **Identity = a canonical key** (kept — it is the precondition for
   order-independence: the same thing reached two ways must be the same thing).
2. **Generative provenance = a pure function of `(seed, key, the committed cone
   the draw is constrained by)`** — *not* of the key alone. The draw is seeded by
   the key (so it is stable and replayable) **but constrained by, and drawn
   consistent with, the committed neighborhood** (so its content can depend on its
   causal neighbors). `draw(key, cone, salt)`, not `draw(key)`.

This is the constraint-store/event-algebra "constrain-then-generate" discipline,
elevated from a feature to *the* repair for the shared blind spot: the key names
*which* hole; the cone determines *what fills it*. A name with an empty cone draws
the prevalence-typical completion; a name in a rich cone draws the
neighborhood-consistent one. Both are deterministic; neither is name-only.

---

## 3. The synthesized primitive set

**Twelve primitives.** Derivation-framed (§1), key/cone-separated (§2). Grouped
as: the data model, the one write, the one read, the generation seam, time,
capability, and replay. Everything familiar (objects, components, ECS, messages,
handlers, scene graphs, the knowledge graph) is a *view* over these — never a
primitive (the relational candidate's §7 subsumption, retained as a hard
lower-bound requirement: the winning algebra must express all of those as cleanly
as the relational candidate did).

Notation: `→` is signature; `Key = Tuple[Value…]`; `Cone` = the prefix-closed
slice of the log a derivation is constrained by; `Cap` = capability handle.

### Data model

**`Value`** — the only data. `Null | Bool | Int | Rat | Sym | Bytes | Tuple[Value…] | Cap | AST`.
Exact rationals, **no float in the core** (float is a rendering leaf; the
cross-platform-float door stays open as a leaf swap, per all sibling substrates).
`AST` is a serializable expression — **rules/reducers/constraints/generators are
all `Value`**, never closures, never opaque nets (the data-over-code seam all five
candidates and defocus share, grafted verbatim; the runtime LLM is **retired**,
relocated to a build-time AST/prevalence-prior producer).

**`Fact`** — `(rel: Sym, cols: Tuple[Value…])`. The only noun-shaped thing, and it
is not a noun: a `Fact` is one committed row. An "entity" is the set of facts
sharing a key; there is no object box (relational candidate, retained).

### The one write

**`commit`** `(intent: Intent, by: Cap, at: Cut) → Event`
The **sole mutator**, and it unifies *creation* and *observation* into one verb:
a fact becoming load-bearing (event-algebra's "creation and observation as one
verb," grafted as the strongest single collapse of a suspicious asymmetry). It
appends one immutable, content-addressed `Event` to the append-only log iff `by`
authorizes `intent` (capability check, the **sole** enforcement point). `Intent =
{verb, payload, evidence, adds: [Fact], entails: [Fact]}` — `adds` are the
committed effects; `entails` is *the existence of a consistent cause, never a
guessed cause* (the flinch discipline — commit "a fire-consistent history exists,"
not a childhood). **No `retract`** (retire-don't-deprecate): removal is committing
an end-coordinate into a temporal relation; the log is append-only, full stop
(relational candidate's deliberate absence of `retract`, made a hard rule). The
event carries `parents: [Event.id]` (a causal DAG), `t: Coord`, and
`author: CapDigest`.

> `commit` is the only thing that grows the world. This makes "never store the
> world / state = f(seed, log)" a *typing fact*, not a discipline — the relational
> candidate's EDB-is-the-commit-log unification, grafted regardless of lens.

### The one read

**`query`** `(q: AST, under: Cap, budget: Budget) → Answer`
Evaluate a derivation against the log, **demand-driven**, ranging only over
relations reachable through `under` (naming a relation you lack a cap for yields
*no rows*, never an error — no existence leak; relational candidate, grafted
verbatim). `query` is *the* materialization primitive: a glance and a deep
inspection are the **same query** at two `budget`s. It returns an **`Answer`**, and
the answer's *type* is the no-facade guarantee (constraint-store's trichotomy,
grafted as the single strongest idea there):

```
Answer ::= Sat([Fact])          -- a derivation consistent with every cone-fact it touched
         | Incomplete(frontier) -- honestly underivable yet (budget/unprobed); NOT a default, NOT a guess
         | Unsat(witness)       -- the log FORBIDS any answer here; witness = the minimal
                                --   conflicting facts, source-reader-verifiable
```

`Incomplete` is a first-class value distinct from both `Sat` and a facade — naming
the honest hole rather than papering it. `Unsat` makes "the world cannot honestly
answer" a *provable* return with verifiable evidence (trust-from-evidence at the
substrate level). Fabrication is unrepresentable: `query` can only return facts a
derivation entails.

**`materialize`** `(key: Key, at: Cut, budget: Budget) → Memo`
The eager↔lazy slide, as **one knob**. A `Memo` is a *droppable pure cache* of a
derivation prefix (drop every `Memo`, re-derive, get bit-identical answers — the
event-algebra's provably-invisible-memoization, with the capability-effects
warning made a hard invariant: **a cache that is not provably pure-and-droppable
silently becomes the forbidden world-store**). `budget = ∞` forces the whole cone
(eager pole, `existence`); `budget = 0` forces nothing (lazy pole, `defocus`); any
value in between forces a *prefix*. There are no tiers — `budget` is continuous,
per-key, slid by `attention × causal-load` (a derived quantity, itself a relation
the control law reads). **Faithful coarsening is a theorem, not a feature** (the
strongest reframe across all candidates): the budget-`k` answer is an *ordered
prefix* of the budget-`k+1` answer, so leaning in only ever *adds*, never
*changes* — mipmap-no-popping falls out of ordered lazy evaluation. *(Subject to
§2's draw-monotonicity, which is the open empirical question — see §6.)*

### The generation seam (the de-poisoned crux)

**`draw`** `(key: Key, cone: Cone, salt: Sym) → Answer`
The seeded oracle at the leaf, **re-shaped to kill the shared blind spot (§2)**.
When `query` needs a fact the log neither contains nor derives, `draw` produces it
**deterministically from `H(seed, key, cone-digest, salt)`** — seeded by the key
(stable, replayable, order-independent) **and constrained by the cone** (so content
depends on the causal neighborhood, not the name alone). It draws the
prevalence-typical completion (`semantic-layer.md`'s weighted graph is the prior,
itself just relations) *that is consistent with every cone-fact*. It returns an
`Answer` (so it can honestly say `Incomplete`/`Unsat`). **`draw` does NOT commit**
— it returns; the fact joins the log only if a caller `commit`s it
(commit-on-observation). Three-state lifecycle: *ungenerated* = incomplete /
*generated-but-uncommitted* = consistent-and-free / *committed* = bound forever
(relational candidate's crisp operationalization of "incomplete, never wrong,"
grafted).

> **`draw` is where the open crux lives, fully owned and not solved here.**
> Bounded-cost generation consistent with an unboundedly-growing constraint set is
> NP-hard in general (`substrate-foundations.md` →
> `crux-prior-art-constraint-generation.md`). This algebra *localizes* the crux to
> one primitive and adopts the two levers: (a) keep cones **local** (corner-risk
> scales with global constraints); (b) commit effects + existence-of-cause, never
> guessed causes, so `draw` back-generates causes to fit. The residue —
> unbounded-incremental global consistency — is fenced, not dissolved.

### Time

**`at`** `(q: AST, t: Coord) → AST`
Reframe a derivation **as of coordinate `t`**. Time is a *coordinate carried on
events*, never a tick; advancing time is choosing a larger `t`. The 3-year jump is
one coordinate selection costing *O(events touching the cone)*, not O(years).
`Coord` is an open sparse map of dimension-keys (`{t, x, …}`) — time is **not
privileged** over space (constraint-store's `at`, grafted; it decouples the
coordinate from any built-in clock or metric). `at` is **decoupled from a totally-
ordered fold** (the constraint-store verdict's explicit requirement) so it does not
contradict itself when timelines are coupled.

**`elapse`** `(key: Key, from: Coord, to: Coord, law: AST) → Answer`
The time-analogue of `draw`: derive `key`'s state as of `to` given last-commit at
`from`, by a serializable `law` evaluated **once over the interval** (closed-form
where the law allows), seeded by `H(seed, key, from, to)` and **constrained by the
cone** (§2 — weathering depends on neighbors, not just the key). Same shape as
`draw` (seeded-by-key, cone-constrained derivation under a budget) — the space/time
symmetry is real. **Flagged:** the closed-form assumption is poison where evolution
is path-dependent (an NPC's 3 years of relationships, a river that rerouted); there
`elapse` must compose with backward-generation over coupled timelines, and the tick
risks returning in disguise. Owned, not solved (§6).

### Capability

**`grant`** `(cap: Cap, rel: Sym, verbs: {read,write,draw}, filter: Pred) → Cap`
Attenuate a capability into a strictly narrower one (monotone-decreasing; no
amplification; you can only grant what you hold). Authority = an attenuated
relation-handle with `(verb-set, row-filter)`; the capability graph *is* the
authority graph; the host grants the root; nothing forges a handle. `commit` is the
sole enforcement point. This is the model all five candidates converged on
independently (and the one part of every candidate's "clean" claims that survived
red-teaming intact) — grafted verbatim, **with the reconciliation the actor-MOO
verdict demanded: the generator's need for a global cone is served by a privileged,
explicitly-granted constraint-oracle capability, never ambient authority.**

### Replay

**`replay`** `(log: [Event], seed: Seed) → World`
Reconstruct the entire derivable world from seed + log, bit-for-bit, pure. Not a
new mechanism — the *statement* that `commit` is the only writer and everything
else is a pure derivation, so log + seed *is* the world. The test harness's hook.

> **The whole algebra:** `Value, Fact, commit, query, materialize, draw, at,
> elapse, grant, replay` (+ `Intent`, `Answer`, `Budget`, `Cone`, `Coord` data
> types). Ten verbs, two nouns-that-aren't-nouns. No object, no message, no tick,
> no method, no inheritance, no `retract` — all of those are views or violations.

---

## 4. How the law's hard parts are discharged

| Law clause | Mechanism | Source graft |
|---|---|---|
| Never store the world | log is the sole truth; `commit` only writer; `materialize`'s `Memo` is a droppable pure cache | relational EDB=log + event-algebra fold + capability-effects cache-purity warning |
| Deterministic | `query`/`draw`/`elapse` pure; `commit` only mutation; `replay` re-derives | all candidates |
| No facades | `Answer` trichotomy (`Sat`/`Incomplete`/`Unsat`); `draw` is `f(seed,key,cone)` = revelation, not fabrication | constraint-store trichotomy + event-algebra purity-type |
| Event-driven, never tick | `at` selects a coordinate; `elapse` integrates an interval once; no loop | constraint-store `at` + relational `elapse` |
| Eager↔lazy continuum | `materialize`'s `budget`, continuous per-key, no tiers; coarse = ordered prefix of fine | event-algebra materialize + relational faithful-coarsening-as-theorem |
| Rules as data | `Value`/`AST` for all behavior; build-time-only LLM | defocus value-lattice, all candidates |
| Capability security | `grant` attenuation; `commit` sole gate; capability graph = authority graph | all five converged |
| The crux | localized to `draw`/`elapse`; cone-locality + commit-existence-of-cause levers | substrate-foundations, owned not solved |

---

## 5. The hard case, end-to-end through the synthesized algebra

> *A player carves a glyph into a rock, walks away, returns 3 in-game years later,
> and inspects it closely.*

**(a) The carve — one `commit`.** The tool holds `cap_g = grant(root, glyph,
{write,read}, owner==P)`. Carving is:

```
commit(
  intent = { verb:"carve",
             payload:{ shape:"spiral", depth: 4/1 (mm), face: <coord> },
             evidence: tool_contact,
             adds:    [ (glyph,       [g7, rock42, P, "spiral"]),
                        (glyph_depth, [g7, 4/1, t0, +∞]) ],
             entails: [ (weathering_history_exists, [g7]) ] },   -- existence, NOT a guessed future
  by = cap_g, at = {t: t0} )
```

One event enters the log. What is committed: the *effect* (a spiral glyph by P at
t0) plus the *entailment* (a consistent weathering history exists). **No future
weathering is computed or stored.** Authority is checked at `commit`; the event is
content-addressed and replays identically. The key `g7` *names* the glyph; it does
**not** determine its future content (§2).

**(b) Walk away — nothing happens, because nothing ticks.** The player leaves; no
cap into the cave is live; `attention × causal-load` for `g7` decays to 0;
`materialize(g7, …, budget→0)` forces nothing. The log grows by zero rows. **Cost
of 3 unobserved years: zero.** The 3 years are the difference between two
coordinates that nothing has evaluated.

**(c) The 3-year jump — one coordinate, no per-tick.** Return at `t1 = t0 + 3y`.
Entering issues queries for what the player can now perceive. A coarse glance:

```
query( at( Scan(glyph, [g7, rock42, ?, ?]), {t: t1} ), under=cap_view, budget=small )
  → Sat[ (glyph, [g7, rock42, P, "spiral"]) ]     -- immutable base fact, O(1)
```

The 3 years contributed no rows to scan. That is the cheap mipmap level — "a
weathered spiral glyph."

**(d) Close inspection — cone-constrained weathered detail, zero facade.** The
player leans in; the same query, deeper budget, asks for depth-at-`t1`.
`glyph_depth` has only the `t0` row, so `query` invokes `elapse` (not a tick loop):

```
elapse( key=[g7], from={t:t0}, to={t:t1}, law=law(glyph_depth, weather_fn) )
  → Sat[ (glyph_depth, [g7, d1, t1, +∞]) ]
```

`weather_fn(depth0=4/1, Δt=3y)` is a serializable closed-form law (erosion rounds
the groove). Stochastic microdetail comes from `draw`, **seeded by the key AND
constrained by the cone** — the §2 repair in action:

```
draw( key=[g7, t1], cone=<carve fact, material, exposure, ADJACENT rock-flaw facts>, salt="microfracture" )
  → Sat[ (glyph_microdetail, [g7, t1, <lichen=2 specks, hairline crack from the adjacent flaw, pit pattern>]) ]
```

The crack propagates *from the neighboring flaw in the cone* — content depends on
the causal neighborhood, not on the string `g7`. **No facade:** every revealed
detail is `f(seed, key, cone)` — not pre-stored (the world was not stored), not
fabricated (pure function of committed constraints), not name-only (§2). It is the
exact face the law + seed + neighborhood always implied. **Consistent with the
carve:** the glyph is still a spiral by P (immutable base row); only derivable
depth/microdetail are revealed, satisfying `weathering_history_exists(g7)`. **No
popping:** the coarse glance is an ordered prefix of the deep look; leaning in
*added* microdetail tuples, did not change the glance.

**(e) Commit-on-observation.** Because the player *observed* the weathered state,
the realizer `commit`s it: the old `glyph_depth` row's `to` is set to `t1` and a
new row `[g7, d1, t1, +∞]` plus the microdetail facts enter the log — now permanent
constraints. A return in 5 more years `elapse`s from `t1`'s committed depth, never
re-deriving the first interval. The world grew by exactly the rows the player's
attention paid for.

**(f) Replay / multi-observer.** `replay(log, seed)` reconstructs identically;
every derived fact re-derives from key+cone-seeded `draw`/`elapse`. Two clients
that both observe the inspection `commit` the same rows — *given a canonical commit
order*, which is **not designed here** (§6).

---

## 6. What can ONLY be detected empirically — the first consumer's stress agenda

The foundation discipline is explicit: *poison is invisible from inside the
interface; only a real consumer reveals it* (`substrate-foundations.md`). The
smallest honest consumer is **the §5 hard case, implemented for real**: a rock +
glyph, a `commit`-carve, a no-op gap, an `elapse`-jump, a deep cone-constrained
`draw`, then a `replay` asserting bit-identical output and asserting the coarse
glance is a true prefix of the deep inspect. Build that *before* trusting any of
this. It will surface, in priority order, the assumptions this synthesis could not
discharge on paper:

**The top 3 the first consumer MUST stress:**

1. **Does `draw`/`elapse` stay bounded-cost and corner-free once cone-constrained
   (the §2 repair's bill)?** The shared-blind-spot fix (content = f(key, cone), not
   f(key)) is *correct* but moves the entire open crux into the foreground: a
   cone-constrained draw is exactly CSP-under-determinism over a growing set, and a
   draw consistent with neighbors can paint into a corner a name-only draw never
   would. The consumer must measure: as the committed neighborhood grows, does
   `draw` return within budget, and does it ever `Unsat` a query that *should*
   have had an answer (a corner it drew itself into earlier)? This is the
   make-or-break number.

2. **Is faithful coarsening actually a theorem for `draw`, or only for `fold`?**
   The no-popping guarantee (coarse = ordered prefix of fine) is structural for
   ordered *query* evaluation, but for `draw` it requires that a coarse draw is a
   true *marginal* of the fine draw — that re-deriving deeper, under a cone that
   *grew between the glance and the lean-in*, yields the glance as a prefix and not
   a revised draw. The §2 repair (cone-dependence) is in direct tension with this:
   if the cone changed between glance and inspection, the draw can legitimately
   differ. The consumer must force a glance, commit something adjacent, then lean
   in — and assert the lean-in did not contradict the glance. If it pops here, the
   continuum's central promise breaks at exactly the moment it matters.

3. **Does a canonical key exist and stay stable for things reached many ways —
   and is the commitment boundary livable?** Two unsolved sub-problems the consumer
   exercises together. (a) `key`/identity: the glyph reached by walking back, by
   region query, by an NPC's memory must mint the *same* key, or the world forks;
   the consumer must reach `g7` by ≥2 access paths and assert key-equality
   (and probe the harder case — a generated sub-thing with no obvious canonical
   descriptor). (b) The commitment boundary: *what* counts as "observed" enough to
   `commit`. Commit-on-every-observe explodes the log (a player who inspects a city
   commits a city); commit-too-little drifts. The consumer must run a deep
   inspection and measure log growth, then test a commitment *policy* (expressed as
   data, swappable) that binds load-bearing detail without binding transient
   glances.

**Also owned, lower-priority, but real (detect once the top 3 are pinned):**

- **Multi-observer canonical commit order is assumed, not designed** — every
  candidate inherited this. `commit`'s coordinate assumes a totally-ordered log; a
  distributed self-hosted sequencer/merge-order is undesigned. Two clients in
  different orders fork.
- **`elapse`'s closed-form assumption fails for path-dependent evolution** — an
  NPC's 3 years, a rerouted river; the tick returns in disguise as backward-
  generation over coupled timelines. The consumer should add a *second* entity
  whose 3-year evolution is path-dependent and see whether `elapse` degrades
  gracefully or re-imports a sweep.
- **Append-only monotone facts vs. defeasible belief** — minds revise beliefs; the
  log forbids removal. Belief-as-defeasible (a constraint kind split into
  "true-of-world" vs "committed-belief") is sketched, not built; the relational
  base's stratified-negation ceiling (mutually-recursive trust/betrayal loops) is a
  real expressivity limit the consumer should probe with one social-belief case.
- **The relational tax on continuous/heterogeneous work** — physics integration in
  exact rationals, and genuinely one-off glue, may not fit the `AST` cleanly without
  bloating it toward a full language (the data-over-code principle is conditional;
  some seams are honestly code). Detect by adding one continuous-physics commit.

Until the consumer runs, this document is a *design output*, not a decision. Hold
what the consumer validates; cut what it poisons.

---

## Cross-links

- `docs/decisions/substrate-foundations.md` — the upstream thesis (the substrate
  law, the foundation discipline, the hard constraints) this synthesizes a core for.
- `docs/decisions/simulation-depth-and-materialization.md` — constrain-then-generate
  / `G(seed, constraints, query)`, which `draw`/`elapse` realize as primitives; the
  open crux this localizes.
- `docs/decisions/semantic-layer.md` — the prevalence-weighted graph that is
  `draw`'s prior; the faithful-coarsening / mipmaps-for-meaning requirement that
  `materialize` turns into a theorem (subject to §6.2).
- `docs/artifacts/substrate-design/candidate-relational.md` — the surviving base.
- `docs/artifacts/substrate-design/candidate-event-algebra.md` — commit-unifies-
  create-and-observe; provably-droppable memoization.
- `docs/artifacts/substrate-design/candidate-constraint-store.md` — the `Answer`
  trichotomy; `at` decoupled from a clock.
- `docs/artifacts/substrate-design/candidate-capability-effects.md` — cache-purity
  warning; the minimal-consumer test discipline.
- `docs/artifacts/substrate-design/candidate-actor-moo.md` — existence-as-
  unanswered-message (kept as framing); the verified defocus facade hole and world
  store this synthesis routes around.
