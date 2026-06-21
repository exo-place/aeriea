# Candidate substrate algebra — the world as a growing constraint store

Status: **candidate for adversarial de-poisoning** (2026-06-22). One design,
committed fully to a single lens. Not frozen, not recommended over its siblings —
this is one horse in the race.

## The lens (held without abandonment)

**The world is a growing constraint store. Materialization is constrained
solving on observation. Constrain-then-generate is not a technique bolted on; it
is the *native shape of the substrate* — because in this lens, to constrain is
the only write and to solve is the only read.** Everything below is forced by
taking that literally:

- A *fact about the world* is a **constraint** in a store.
- *Asking the world anything* is a **query** = "find a value for these variables
  consistent with the store."
- *Materializing* an entity is **solving** for the variables the query touches,
  under the store.
- *Committing* — the player acts, an NPC reasons, the realizer renders — is
  **adding constraints** (the answer, and what it entails).
- *No-facade* is **unsatisfiability detection**: the substrate never fabricates;
  it returns a witness that satisfies the store, reports *incomplete* (no
  constraint yet pins this), or reports *unsat* (the store forbids it). It
  cannot return a falsehood because a falsehood is, by definition, a value that
  violates a constraint — and the solver rejects those by construction.
- *Eager vs lazy* is **when you choose to solve**: at commit time (eager pole)
  or at first query (lazy pole). One knob — *solve urgency* — slid per variable
  by attention/causal-load, over one continuum.

This is the whole bet: **if the world IS a constraint store, then "deterministic
revelation, never fabrication" stops being a discipline you impose and becomes a
property you get for free** — the solver structurally cannot emit an unsatisfying
witness. The `substrate-foundations.md` law's hardest clause (no facades) is
discharged by the choice of substrate, not by vigilance.

The constrain-then-generate doc's `G(seed, constraints, query) → answer` is, in
this lens, *literally a constraint solver*: `G = solve`. The doc's open crux
("CSP-under-determinism over a growing constraint set", "painting into a corner",
"locality lever") is therefore not a hazard this design stumbles into — it is the
**named, owned, central hardness** this design organizes itself around. Choosing
the constraint-store lens is choosing to make that crux the *one* hard problem
and pay for everything else with it.

---

## The primitive set (the game's lambda calculus, constraint dialect)

Nine primitives. Three for the store's contents (`Var`, `Constraint`, `Domain`),
three for the two operations (`pose`, `solve`, `commit`), three for the
attention/time/identity machinery the law demands (`attend`, `at`, `key`). No
tenth without a real consumer forcing it.

Everything is **data**, serializable: a `Constraint` is an AST, never a closure;
a `Var` is a key, never a pointer; `solve` is the only thing that is *code*, and
it is a single pure fixed function (the solver), not per-entity behavior. Rules
live as `Constraint` data the solver interprets — the data-over-code seam.

### 1. `Var` — a hole in the world

```
Var ::= key: Key                      -- canonical, access-path-independent identity
        domain: DomainRef             -- what kind of value can fill this hole
```

**Semantics.** A `Var` is an *un-materialized degree of freedom* — a question the
world has not yet been forced to answer. "The depth of the glyph on rock#42",
"NPC#7's affective memory of their parent's cooking", "the weather over the
eastern ridge at t=2y" are each a `Var`. A `Var` is **not** storage; it holds no
value. It is a name for something the store *could be queried about*. The world
is, formally, an unbounded set of `Var`s (most never named) plus a finite set of
`Constraint`s over the named ones.

The `Var`'s `domain` is the substrate's only built-in typing: it says "a witness
for this hole is drawn from *this* space" (a length in metres ≥ 0; a member of
the apple-color distribution; a well-formed NPC-memory record). Domains are
themselves data (see `Domain`).

This is the *lazy pole made primitive*: an unobserved entity is a `Var` (or a
cluster of `Var`s) with no constraints pinning it — a genuine hole, not a stub
holding fake defaults. There is no facade because there is *nothing there yet* —
and "nothing there yet" is honest (`incomplete`), where a stub-with-defaults
would be a fabrication.

### 2. `Domain` — the space a witness is drawn from

```
Domain ::= Finite([Value])                       -- explicit set
         | Interval(Ord, lo, hi)                  -- ordered range
         | Distribution(KnowledgeGraphRef, ctx)   -- prevalence-weighted draw
         | Struct({field: DomainRef})             -- record of sub-domains
         | Refine(DomainRef, [Constraint])        -- a sub-domain carved by constraints
```

**Semantics.** A `Domain` is the *generative prior* attached to a `Var` — the set
of a-priori-possible witnesses **and their typicality**. `Distribution` is the
load-bearing case: it points into the `semantic-layer.md` prevalence-weighted
knowledge graph. "Apple color" is `Distribution(graph, apple→hasColor)`: red
typical, green common, yellow less so. When `solve` has freedom (the store does
not uniquely pin the variable), it draws from the `Domain`'s prevalence weights,
seeded — *typicality is how the solver breaks ties*. This is exactly the
`semantic-layer.md` "graph is `G`'s prior" relationship, made a primitive: the
prior is not in the solver, it is in the `Domain` *data*.

`Domain` is data, so a `Var`'s prior is inspectable and replaceable — no opaque
generative net. `Refine` lets a domain be a parent domain narrowed by
constraints (the same `Constraint` primitive), which is how new kinds of thing
are introduced without new primitives: "a weathered glyph" is
`Refine(glyph-domain, [age > 0, edges-rounded ∝ age])`.

### 3. `Constraint` — the only thing the store stores

```
Constraint ::= rel: Relation                 -- a named relation (data, not code)
               args: [Term]                   -- Vars, literals, or applications
               provenance: EventKey           -- which commit added this (capability + replay)

Term ::= Lit(Value) | Of(Var) | App(Relation, [Term])
Relation ::= a symbol naming a relation the solver knows how to check/propagate
```

**Semantics.** A `Constraint` is one fact the world is bound to. It is an *AST
over `Var`s* — never a closure, always serializable, diffable, transportable,
cacheable (the data-over-code principle at the substrate's core seam).
`Constraint(causes, [Of(fire-flinch#7), exists-history-consistent-with(fire-flinch#7)])`
is the flinch example's commit: an effect plus the *existence* of a consistent
cause — no guessed history, exactly as the constrain-then-generate doc requires.

The store is **append-only and monotone**: constraints are only ever added, never
mutated or removed (retire-don't-deprecate at the data layer; it is also what
makes replay trivial). "The glyph gets deeper over the years" is not a mutation —
it is *more constraints* relating the glyph's depth-at-t to its depth-at-t₀ and
the intervening weather. State change is constraint accumulation, not cell
overwrite. This is the deepest commitment of the design and its sharpest
tradeoff (see *What this hides*).

`Relation`s are a **fixed, small, inspectable vocabulary** the solver knows
(equality, ordering, arithmetic, `exists`, `causes`, `monotone-in`,
spatial/temporal adjacency, graph-typicality). New *facts* are new `Constraint`
data over this vocabulary; new *kinds of fact* that need a genuinely new relation
are the one place the substrate grows — and that growth is a reviewed change to a
small list, not an API sprawl. This is the "collapse N special-cases to
primitives" ratchet applied to the relation set.

`provenance` is the capability hook: every constraint records the `EventKey` (see
`commit`) that authored it. Nothing forges a constraint without an event; an
event carries the authority (capability ref) that permitted it. Authority cannot
be forged because a constraint with no valid provenance is rejected at `commit`.

### 4. `pose` — name a hole and its prior, without solving it

```
pose(key: Key, domain: DomainRef) -> Var
```

**Semantics.** Bring a `Var` into the *named* set. Pure, cheap, commits nothing,
solves nothing — it just declares "this hole exists and is drawn from this
domain." Posing is how the lazy pole stays lazy: you can name "the weather over
the eastern ridge for every hour of the next 3 years" as a *parametric family of
`Var`s* without computing a single one. Posing a family is O(1) (the family is a
`Domain(Struct)` keyed by `at`), not O(years·hours).

`pose` is idempotent on `key`: posing the same canonical key twice yields the
same `Var`. This is where `key` (primitive 9) earns its keep — without a
canonical, access-path-independent key, "the same hole" reached two ways would be
two holes and the world would fork. `pose` is the gate that enforces "incomplete,
not yet solved" as a *first-class, nameable state* distinct from both "solved"
and "facade".

### 5. `solve` — the only read; constrained generation = materialization

```
solve(query: [Var], store: ConstraintStore, seed: Seed, budget: Budget)
    -> Sat({Var: Value}) | Incomplete | Unsat(witness: Constraint)
```

**Semantics.** `solve` is `G`. It is the *single pure function* that is the
substrate's only code-that-runs-in-the-hot-loop, and it contains **no LLM** — it
is a deterministic constraint solver (the `crux-prior-art` candidate stack:
SAT/ASP-style propagation + dynamic backtracking, so a corner is escaped without
discarding committed work). Given the `Var`s a query asks about, it returns one
of three things, and *these three are the whole no-facade guarantee*:

- **`Sat`** — a witness assignment for the queried `Var`s that satisfies *every
  constraint it touches*, with free choices drawn seeded from the `Domain`
  priors. This is "deterministic revelation": the value was *implied-or-allowed*
  by `seed + store`, generated now, never fabricated. Two queries reaching the
  same `Var` get the same witness because `solve` is pure over
  `(query-as-canonical-keys, store, seed)` — order-independent by construction
  (the `semantic-layer` faithful-coarsening / no-popping property, here forced by
  purity rather than asserted).

- **`Incomplete`** — the budget ran out before a witness was found, *and the
  store does not yet pin the variable*. This is the honest "the world has not
  been forced to answer this yet" — returned instead of a guess. A glance returns
  a coarse `Sat` (few `Var`s queried); a deep inspection queries more `Var`s and
  may push the boundary, but never *contradicts* the glance, because the glance's
  witness was committed (see `commit`) and now constrains the inspection. **This
  is the mipmap/faithful-coarsening property as a theorem, not a wish:** the
  coarse answer is a prefix of the fine answer because the coarse answer is a
  *constraint* the fine solve must satisfy.

- **`Unsat(witness)`** — the store *forbids* any value here; the returned
  `witness` is the minimal conflicting constraint set (the proof). This is
  **no-facade as unsatisfiability detection**, the lens's signature move: when
  the world cannot honestly answer, it says so *with a proof of why*, rather than
  papering over it. Unsat is not a failure mode to be hidden; it is the
  substrate's integrity made observable — the source-reader (per the
  inspectable-no-black-box constraint) can read the witness and verify the world
  did not lie.

`budget` makes "cost proportional to engagement" a primitive parameter, not an
emergent hope: a query carries its solve budget; an unprobed century is never
solved (cost 0); a deeply-probed conversation spends in proportion to the `Var`s
it forces. The eager↔lazy continuum *is* the budget+urgency setting per `Var`:
high attention ⇒ solve eagerly at commit with generous budget; zero attention ⇒
never solve, stay a posed `Var`. Same primitive, two ends, continuous slide.

### 6. `commit` — the only write; observation crystallizes constraints

```
commit(event: Event) -> ConstraintStore'
  where Event ::= { key: EventKey,
                    authority: CapabilityRef,
                    adds: [Constraint] }
```

**Semantics.** `commit` is the *only* mutation of the store, and it is
**append-only**: it folds `adds` (the observed answer plus its entailments) into
the store, after checking (a) `authority` actually permits each added constraint
(capability security — nothing forges authority; an unauthorized add is rejected,
not silently dropped), and (b) the addition keeps the store **satisfiable**
(forward-checking: a `commit` that would paint the world into an unsatisfiable
corner is *rejected at commit time*, surfacing as `Unsat` to the actor, never
committed). This second check is the design's translation of the crux's
"draws that preserve future satisfiability" — pushed to the *write* so reads stay
clean.

The event log of `substrate-foundations.md` *is* the sequence of `Event`s.
`store = fold(commit, seed-store, event-log)` — this is exactly
`state = f(seed, event log)`, with `commit` as `f`'s step function. Replay is
re-folding. Forking is folding a prefix (defocus's `branch_at`, but over
constraints instead of messages). **The world is never stored — only `seed` + the
`Event` log are; the store is derived by re-folding, and any `Var`'s value is
re-derived by `solve`.** Nothing else persists.

What counts as an observation (the crux's open "commitment boundary") is **a
policy expressed in data**, not baked into `commit`: a policy maps "the realizer
rendered X / an NPC reasoned over Y / the player acted Z" to the `[Constraint]`
it entails. Different policies (commit-on-render vs commit-on-mention) are
different data, swappable, testable — the premature-commitment poison about *what
observation means* is kept out of the primitive.

### 7. `attend` — set solve-urgency; slide an entity along the continuum

```
attend(vars: [Var], urgency: Urgency) -> ()    -- urgency ∈ [0,1] ∪ causal-load
```

**Semantics.** `attend` is the *only* control over where the substrate spends. It
sets, per `Var`, where on the eager↔lazy continuum it sits: `urgency=1` (the NPC
you are talking to, the object in your hand) ⇒ solve eagerly, generous budget,
commit the witness so it is stable under re-inspection; `urgency=0` (the
unobserved ridge) ⇒ never solve, stay posed. Causal-load is the second input:
a `Var` that *another* committed constraint depends on is forced regardless of
player attention (the flinch's *existence-of-history* must be solvable when an
NPC reasons from it, even if the player never asks). This is the continuum's
"attention AND causal load" clause as a single primitive: `urgency` is the max of
player-attention and causal-demand.

Crucially `attend` is **not a tier selector** and **not global**. It is a
per-`Var` real number, slid continuously, re-evaluated event-by-event. There is
no "near LOD / far LOD" enum anywhere — that enum would be exactly the
premature-commitment-to-scale poison the foundation forbids.

### 8. `at` — coordinates without committing to a clock or a metric

```
at(var-family: Var, coord: Coord) -> Var
Coord ::= { dims: {DimKey: Term} }     -- e.g. {t: 2y, x: ridge}, sparse, open
```

**Semantics.** `at` projects a parametric `Var`-family to a specific point in some
coordinate space — *time being just one dimension among others*. This is how the
substrate handles **time without ticks and without committing to a metric**: time
is a `DimKey` in a `Coord`, queried at arbitrary points, never swept. "The glyph
at t=0" and "the glyph at t=3y" are `at(glyph-depth-family, {t:0})` and
`at(glyph-depth-family, {t:3y})` — two `Var`s in one family, related by
`monotone-in(t)` weathering constraints. **Jumping 3 years is querying `at` with
`t=3y`; nothing in between is computed.** Event-driven, never tick-driven, falls
out: there is no loop advancing `t`; `t` is only ever a query coordinate.

`at` deliberately does **not** privilege time, space, or any ordering — `Coord`
is an open, sparse map of dimension-keys. This is the anti-poison move against
*premature commitment to time/scale/ordering*: the substrate has no built-in
clock, no built-in spatial grid, no built-in event order beyond the partial order
the constraints themselves impose. Whether a world is 3D-Euclidean or graph-
topological or has multiple time axes is `Domain`+`Constraint` data, not a
substrate assumption.

### 9. `key` — canonical, access-path-independent identity

```
key(descriptor: Value) -> Key      -- pure, total, collision-free over descriptors
```

**Semantics.** `key` mints the canonical name for a `Var` from a *structural
descriptor* of what the hole denotes — "NPC#7's affective memory of parent#2's
cooking" hashes to one `Key` whether reached through NPC#7, through parent#2, or
through a conversation about food. This is the crux's "stable query/fact identity"
sub-problem made a primitive: purity of `solve` requires that the same hole
reached two ways *is the same `Var`*, or the world forks. `key` is the function
that guarantees it: identity is **derived from structure**, never assigned by
allocation order (which would be premature commitment to identity/ordering — the
defocus `Identity = String` allocated-name approach, which this design rejects
precisely because allocated names are access-path-dependent).

---

## The hard parts, expressed (or honestly fought)

| Law clause | How this algebra expresses it |
|---|---|
| **No facade / deterministic revelation** | *Structural.* `solve` returns `Sat`/`Incomplete`/`Unsat`; it cannot emit an unsatisfying witness. Fabrication is not forbidden by rule — it is *unrepresentable*. |
| **Never store the world** | Only `seed` + `Event` log persist. Store = `fold(commit, …)`; any value = `solve(…)`. Re-derivable, never stored. |
| **Deterministic** | `solve` pure over `(canonical-keys, store, seed)`; `store` = pure fold of the log. Replay = re-fold. (Float caveat inherited, fixed-point door open — same as sibling substrates.) |
| **Event-driven, never tick** | Time is a `Coord` dimension queried by `at`. No loop advances time. The 3-year jump is one `at(…, {t:3y})`. |
| **Eager↔lazy continuum** | One knob: `attend`'s `urgency` per `Var` (= max of attention, causal-load). Eager = solve-at-commit; lazy = stay-posed. Continuous, per-entity, never tiered. |
| **Rules as data, no runtime net** | `Constraint`/`Domain` are ASTs; `Relation` a small fixed vocabulary; `solve` is one pure solver. The only learning (prevalence weights, build-time graph extraction) is baked into `Domain` data offline. |
| **Capability security** | Every `Constraint` carries `provenance: EventKey`; `commit` rejects adds whose `authority` does not permit them. No constraint without an authorizing event. |
| **The crux (CSP-under-determinism, painting-into-corner)** | *Owned, not hidden.* `commit`'s satisfiability check is forward-checking at write time; `solve` uses dynamic backtracking to escape corners without discarding work. The locality lever is a *design obligation on `Constraint` authors*: keep relations local; global constraints are the bounded, expensive, minimized case. This design does not solve the unbounded-incremental residue — it *localizes* it to one primitive (`commit`'s check) so it can be attacked in one place. |

---

## The hard case, all the way through

**"A player carves a glyph into a rock, walks away, returns 3 in-game years later
and inspects it closely."** Traced through the nine primitives, zero facade.

**1. The rock pre-exists as holes, unsolved.** Long before the player arrives,
the rock is a cluster of posed `Var`s with priors and *no pinning constraints*:
```
pose(key({rock:42, prop:"surface"}), surface-domain)
pose(key({rock:42, prop:"depth-field"}), depth-field-domain)   -- a Var-family over Coord
```
Nothing is solved. The rock's micro-surface at t=0 is `Incomplete` until looked
at — honest, not a default. No storage, no facade.

**2. The carve is a commit (constraints added).** The player acts. The
commit-policy maps "player carved glyph G into rock#42 at t=0" to constraints:
```
commit(Event {
  key: e1, authority: <player-cap>,
  adds: [
    Constraint(equals, [Of(at(glyph-shape-family-42, {t:0})), Lit(G)],            prov:e1),
    Constraint(equals, [Of(at(glyph-depth-field-42, {t:0})), Lit(fresh-sharp)],   prov:e1),
    Constraint(monotone-in, [glyph-depth-field-42, t, weathering-rate-of(rock:42)],prov:e1),
    Constraint(exists, [erosion-history-consistent-with(glyph-depth-field-42)],   prov:e1),
] })
```
The first two pin the glyph *now*. The third is the load-bearing one: it does
**not** compute the future — it *constrains* it (depth weathers monotonically per
the rock's material). The fourth commits the *existence* of a consistent erosion
history without computing it (the flinch pattern, applied to a rock). `commit`
checks the player's capability authorized carving this rock, and checks the store
stays satisfiable. The glyph-at-t=0 is now `Sat` and stable.

**3. Walk away — nothing happens, because nothing ticks.** The player leaves.
`attend([glyph-vars], 0)` — urgency drops to zero, no causal load (no NPC reasons
about this glyph). The substrate solves *nothing* for the glyph. No tick advances.
The eastern ridge's weather, the rock's neighbours, all stay posed-and-unsolved.
**Cost of 3 unobserved years = 0.** This is the "unprobed century costs nothing"
clause, literal.

**4. The 3-year jump is one query coordinate.** The player returns at game-time
t=3y. There is no catch-up simulation — `t=3y` is simply the coordinate the next
queries use. Time did not *pass*; it is *asked about*.

**5. Close inspection is a high-budget solve at t=3y — weathered, consistent,
zero facade.** Inspecting closely is:
```
attend([at(glyph-depth-field-42, {t:3y}), at(glyph-shape-family-42, {t:3y})], urgency=1)
solve(query=[at(glyph-depth-field-42, {t:3y}), at(glyph-shape-family-42, {t:3y})],
      store, seed, budget=generous)
```
`solve` must satisfy:
- `equals(glyph-shape@t0, G)` and `equals(glyph-depth@t0, fresh-sharp)` (committed),
- `monotone-in(depth, t, weathering-rate)` — so depth@3y is shallower than @0, by
  an amount the constraint pins to the rock's weathering rate and elapsed t,
- `exists(erosion-history-consistent-with …)` — so the rounding it generates *has*
  a consistent micro-history (queryable later if the player gets a magnifying
  glass; generated backward-from-effect then, faithfully).

The witness: the glyph at t=3y, edges rounded, depth reduced, *the original shape
G still legible underneath the weathering* — because `equals(shape@t0, G)` plus
monotone weathering forbids the shape from becoming something else. Free choices
(exactly *which* grains spalled, the precise lichen pattern) are drawn **seeded
from the `Domain` priors** — deterministic, same every replay, same for every
co-op observer. **The weathered detail was *implied* by `seed + the carve commit
+ the weathering constraint`, revealed now by `solve` — never fabricated.** A
later, deeper probe (the magnifying glass) returns a *refinement* of this
witness, never a contradiction, because this witness is now committed and
constrains the deeper solve. That is the no-popping guarantee, earned.

**6. Where unsat would fire (the integrity check).** Suppose a buggy mod tried to
`commit` "glyph@t=1y is *deeper and sharper* than @t=0" — `commit`'s
satisfiability check finds it violates `monotone-in(depth, t, weathering)`,
returns `Unsat` with the conflicting pair as witness, and **refuses the write**.
The world cannot be made to lie about its own past. That refusal, with proof, is
the no-facade law operating as designed.

---

## What this hides / assumes (the poison, named honestly)

1. **Append-only monotone store assumes the world is expressible as accumulating
   constraints.** Genuine *retraction* — a fact that was true becoming false, not
   "true-at-t1, false-at-t2" but actually withdrawn — is not native. Belief
   revision (an NPC was *wrong* about something and corrects) must be modeled as
   constraints *about beliefs-at-times*, not by removing constraints. This is the
   `crux` doc's "iterated belief revision residue" — the design does not solve it,
   it *relocates* it into the constraint language and bets most cases are
   monotone-with-time-indexing. **If that bet is wrong, the store needs
   non-monotonic logic and the whole "append-only ⇒ trivial replay" elegance
   cracks.** This is the design's single biggest assumed-away hazard.

2. **`solve` is assumed bounded-cost in the regime that matters.** The whole
   no-facade guarantee is only *affordable* if `solve` returns within `budget`
   for real queries. The `crux` prior art says completion-existence is NP-hard in
   general and tractable mostly when constraints are *local*. So this design
   **assumes world-authors keep constraints local** and treats global constraints
   as a rationed resource. If a real consumer needs many global constraints
   (e.g. a world-spanning conservation law), `solve` may not return in budget and
   the substrate degrades to `Incomplete` — honest, but possibly *unhelpfully*
   honest. Tractability is pushed onto the world's design, not guaranteed by the
   substrate.

3. **`key` assumes a canonical structural descriptor exists for every hole.**
   "NPC#7's affective memory of parent#2's cooking" must have one canonical
   structural form. For richly relational or *emergent* concepts ("the vibe of
   that one night") a stable structural key may not exist, and two access paths
   could mint two keys ⇒ a fork. The design assumes the descriptor space is
   canonicalizable; this is unproven over the full query space (the crux's open
   "stable identity" problem, assumed solved here by fiat).

4. **`Relation` vocabulary is a premature-commitment surface in waiting.** The
   claim "a small fixed relation set + data covers all facts" is the most likely
   place coverage breaks. Every genuinely new *kind* of relation is substrate
   growth — and the discipline that keeps that list small is human, not
   structural. If the list bloats, the "100-year minimal algebra" promise is
   broken from inside.

5. **`Domain(Distribution)` smuggles the semantic-layer's entire open problem in
   as a dependency.** Faithful, deterministic, prevalence-weighted priors are
   *assumed available*. The hard build-time graph-extraction problem is not
   solved here — it is consumed. This design is only as good as that graph.

6. **Multiplayer commit-ordering is assumed, not designed.** `commit` is a clean
   fold *given a single Event log*. Concurrent observers need one canonical order
   over their Events; the design names `provenance`/`EventKey` but does not define
   the distributed total order. The crux's multi-observer problem is inherited
   wholesale.

7. **Assumes `Incomplete` is acceptable UX.** Returning "the world hasn't been
   forced to answer that yet" is honest, but a player who *expects* an answer and
   gets `Incomplete` (budget exhausted) experiences a seam. The design trades
   *fabrication* for *occasional honest blankness* and assumes blankness-with-
   integrity beats plausible-lie — true to the law, but a real product cost.

---

## Real tradeoffs vs the sibling lenses

- **Won, structurally:** no-facade is *free* (unsatisfiability is detection, not
  a discipline); determinism and replay are *trivial* (pure fold + pure solve over
  an append-only log); the eager↔lazy continuum is *one number* (`attend`);
  time-without-ticks is *one primitive* (`at`). The law's hardest clauses are
  discharged by the substrate's shape rather than policed.

- **Paid for it:** the *entire* hardness concentrates in `solve` + `commit`'s
  satisfiability check — the NP-hard-in-general crux is not avoided, it is made
  *the one thing*. A process/actor lens (defocus's shape) spreads cost into many
  cheap message-handlers and never faces a global solve; it pays instead with
  facades (stubs with defaults) and weaker no-facade guarantees. This design
  makes the opposite bet: **concentrate all the hardness into one provably-honest
  solver, and live or die by whether that solver is tractable on local-constraint
  worlds.** If the locality lever holds, this wins decisively on integrity. If
  real worlds need global constraints, this is the lens most likely to return
  `Incomplete` when a player wanted an answer.

- **Vs an entity/process substrate:** loses *off-screen autonomy* completely
  (same as the constrain-then-generate doc already concedes — the world is
  reconstructed-on-encounter, never alive-when-unwatched) and loses the
  *operational intuitiveness* of "objects with methods." Gains *integrity under
  unbounded inspection* as a structural property no process lens can match.

The single sentence: **this design buys "the world structurally cannot lie" at
the price of "the world's hardness is one NP-hard solver, made affordable only by
disciplining constraints to be local."** That is the constraint-store lens's
honest bargain.
