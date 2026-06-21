# Candidate substrate algebra — RELATIONAL / DATALOG lens

Status: **CANDIDATE for adversarial de-poisoning** (2026-06-22). One design, one
lens, committed fully. Not frozen, not the winner-by-default.

> **The lens, held to the end.** The world is a set of **typed relations**
> (tuples). There are no objects, no actors, no messages, no methods — those are
> *views* over relations. **Rules are queries** (Datalog-style views): a derived
> relation is the answer to a standing query over base + other derived relations.
> **Materialization is query evaluation.** **Identity is keys** — a tuple is
> identified by its key columns, nothing else; there is no hidden object box that
> "has" the tuple. Everything below is forced through this lens, including the
> parts where the lens fights back (time, attention, the eager↔lazy slide). Where
> it strains, that is recorded honestly rather than smuggled into an object model.

This is deliberately the *opposite* shape from `defocus` (the studied prior art),
which is an **object/actor** substrate: objects own state, receive messages, run
handlers, walk prototype chains. That is a fine lens — it is just **not this one.**
In the relational lens, `defocus`'s `Object{id,state,handlers}` is nothing but
three relations keyed on `id` (`state(id,key,val)`, `handler(id,verb,rule)`,
`iface(id,verb)`), and its per-object `query` is a degenerate one-relation
selection. The relational lens *subsumes* that as a special case and gains joins,
which the object lens cannot express without reaching across object boundaries by
hand.

---

## 0. The substrate law, restated in relational terms

| Law clause | Relational reading |
|---|---|
| Never store the world | Store only **base tuples** that were *committed* (created/observed) + the seed. Everything else is a **derived relation** computed by query, never stored. |
| Deterministic `state = f(seed, log)` | The committed base relations *are* the log (an append-only **EDB**, extensional database). Derived relations (**IDB**, intensional) are a pure function of EDB + seed. |
| No facades | Query answers are **deterministic revelation**: a derived tuple is *entailed* by EDB+seed+rules, never fabricated. "Incomplete" = the tuple is underivable *yet*; "wrong" = a tuple contradicting the EDB, which the closure forbids. |
| Event-driven, never tick | Events are **tuple insertions** (`assert`). No clock sweeps relations. Time is a *column*, not a loop (§3). |
| Eager↔lazy continuum | A relation is **materialized** (cached as if EDB) or **virtual** (recomputed on read) — and any tuple can slide between, per-tuple, by demand. Same continuum, one mechanism: the **demand-driven evaluation frontier** (§4). |
| Rules as data | Rules are tuples in a relation `rule(head, body)` whose body is a serializable query AST. Inspectable, diffable, no opaque code. |
| Capability security | A query can only range over relations reachable from the **capabilities** (relation-handles) it was granted; `grant` attenuates. Nothing forges a relation it wasn't handed (§5). |

The whole substrate is therefore **one idea**: *a deterministic, demand-driven
Datalog whose EDB is the append-only commit log and whose RNG is seeded by the
key of the tuple being derived.*

---

## 1. The value & tuple model (the only data there is)

```
Value   ::= Null | Bool | Int | Rat | Sym | Bytes | Tuple[Value…] | Cap
Rat     = exact rational (i128/i128)         ; determinism: NO float in the core
Sym     = interned symbol (relation names, column tags, enum values)
Cap     = capability handle (an attenuated relation-reference; §5)
Key     = Tuple[Value…]                       ; a tuple's identity is a prefix of its columns
Fact    = (relation: Sym, cols: Tuple[Value…]) ; one row
```

- **No float.** The core is exact (rationals). Cross-platform float determinism is
  the door `npc-mind-and-language.md`/`movement-substrate.md` keep open; this lens
  shuts it by construction in the core and pushes float to a *rendering leaf*. (A
  real poison risk — see §8 — for physics-heavy consumers.)
- **A `Fact` is the only noun.** There is no Object, Entity, Component, or Node as
  a primitive. "Entity = key" — an entity is just the set of facts sharing a key.

---

## 2. The primitive set (the game's lambda calculus)

Twelve primitives, grouped. Signatures use `→`; `[t]` = relation/stream of `t`.

### A. Schema & rules (the language is data)

**`relation`** `(name: Sym, key_arity: Int, col_arity: Int) → ()`
Declare a typed relation: which columns form the key (identity) and the total
arity. Schema is itself stored in the relation `relation(name,key_arity,col_arity)`
— the schema is queryable like everything else (no privileged metalayer).

**`rule`** `(head: Pattern, body: Query) → ()`
Define a **derived relation** as a Datalog rule: `head :- body`. `head` is a
relation pattern with variables; `body` is a `Query` AST (a serializable value —
joins, selects, negation-as-failure-stratified, `gen` calls). Rules live in the
relation `rule(head_rel, head_pat, body)`; **rules are data**, inspectable and
diffable. Recursion allowed; evaluation is stratified (negation/aggregation only
across strata) so the fixpoint is well-defined and deterministic.

> A "behavior" is a rule. An NPC's "flinch at fire" is
> `flinches(N,fire) :- observed_flinch(N,fire)` plus the entailment rule
> `consistent_history_exists(N,fire) :- flinches(N,fire)`. No code, no handler — a
> view.

### B. Commitment (the log; the only write)

**`assert`** `(fact: Fact, by: Cap) → CommitId`
The **only mutator**. Append a base (EDB) tuple to the commit log, iff `by` grants
write to `fact.relation` (capability check, §5). Returns a `CommitId` (the
monotonic log position = the tuple's commit time, §3). **Idempotent on key**:
asserting an existing key with equal columns is a no-op; with *different* columns
it is a contradiction → rejected (no facades: you cannot overwrite a committed
fact, only supersede it via a time-keyed relation, §3). This is "commit-on-
observation": **only `assert` grows the world.**

**`retract`** is deliberately **absent.** Retire-don't-deprecate: you never delete
a committed fact (that would break replay determinism). "Removal" is asserting an
end-time into a temporal relation (§3). The log is append-only, full stop.

### C. Query (materialization = evaluation)

**`query`** `(q: Query, under: Cap, budget: Budget) → [Fact]`
Evaluate a query against the EDB + rules, **demand-driven**, ranging only over
relations reachable through `under`. Returns the entailed tuples. `Query` AST:

```
Query ::= Scan(rel, pattern)              ; base or derived relation, bind vars
        | Join(Query, Query)              ; natural join on shared vars
        | Select(Query, predicate)        ; filter (predicate is a pure Value→Bool AST)
        | Project(Query, cols)
        | Diff(Query, Query)              ; stratified negation
        | Agg(Query, group, fold)         ; aggregation (count/sum/min over rationals)
        | Gen(rel, key, prior)            ; deterministic generation (§ no-facade) — see `gen`
        | Recur(rel)                      ; reference a relation defined by `rule` (fixpoint)
```

`query` is *the* materialization primitive: a glance and a deep inspection are the
**same query** at two `budget`s; the cheap answer is a true prefix of the
expensive one (faithful coarsening, §6). Evaluation is **lazy by default** —
tuples are produced on demand up to `budget`, never the whole relation.

**`budget`** is itself a value: `Budget(steps: Int, depth: Int)` — a ceiling on
join steps and recursion/`gen` depth. It is the *only* knob on the eager↔lazy
slide and on attention-bounded materialization in **space** (depth = how far a
join chain expands) — see §4, §6.

### D. No-facade generation (the seeded oracle at the leaf)

**`gen`** `(rel: Sym, key: Key, prior: PriorRef) → Fact`
The crux primitive. When `query` needs a tuple of `rel` at `key` that the EDB does
**not** yet contain and no rule derives, it does **not** fabricate and it does
**not** return null — it **derives** the tuple deterministically from
`(seed, key, prior, current-EDB-constraints-on-this-key)`:

- The RNG is seeded **purely by the tuple's canonical key** (`hash(seed, rel,
  key)`) — *not* by access order, wall-clock, or call path. So the *same* tuple is
  generated identically however it is reached, on every machine, on replay. This is
  the stable-fact-identity requirement met by construction: **the key is the
  canonical name.**
- `prior` is a `PriorRef` into the **prevalence-weighted knowledge graph**
  (`semantic-layer.md`) — itself just relations (`prior(concept,pred,obj,weight)`).
  `gen` draws the *typical* completion under the seeded RNG, weighted by prior.
- The draw is **constrained**: it must satisfy every EDB fact whose key overlaps
  this key (the `consistent_history_exists`-style entailments). This is the
  CSP-under-determinism crux (`simulation-depth-and-materialization.md`) — `gen` is
  exactly `G(seed, constraints, query)`, expressed as a relational primitive. **It
  is build-time-trained / deterministic-eval, never a hot-loop LLM.**

**`gen` does NOT assert.** It returns a tuple. The tuple only joins the EDB if the
caller `assert`s it (commit-on-observation). Until then it is recomputed
identically each time it is needed — *virtual*, costing nothing when unobserved.
This is the eager↔lazy continuum's lazy pole and the "incomplete, never wrong"
property in one primitive: an ungenerated tuple is incomplete; a generated-but-
unasserted tuple is consistent-and-free; an asserted one is committed.

### E. Time (a column, never a tick)

**`at`** `(q: Query, t: Time) → Query`
Reframe a query **as of logical time `t`** (a `CommitId`, since commit order *is*
time). Temporal relations carry `[from, to)` validity columns; `at` selects the
version live at `t`. **There is no tick.** Advancing time is just choosing a larger
`t` in an `at` query — see §3 for how a 3-year jump costs O(events touching the
key), not O(years).

**`elapse`** `(key: Key, from: Time, to: Time, law: RuleRef) → Fact`
The **time analogue of `gen`**: derive the state of `key` *as of `to`* given it was
last committed at `from`, by applying a **closed-form / event-sparse law** (a rule
tuple), **not** by stepping. `law` is a relation `law(rel, transfer_fn)` whose
`transfer_fn` is a serializable function `(state, Δt) → state` evaluated **once**
over the whole interval. Determinism: seeded by `hash(seed, key, from, to)` for any
stochastic weathering. This is **attention-bounded materialization in TIME**: an
unobserved interval is never traversed; it is *integrated in one shot* on demand.

### F. Capabilities (nothing forges authority)

**`grant`** `(cap: Cap, rel: Sym, verbs: {read,write,gen}, filter: Predicate) → Cap`
Attenuate a capability into a narrower one: a handle that permits only the listed
verbs on `rel`, restricted to rows matching `filter`. You can only grant what you
hold (monotone attenuation; no amplification). A `query`/`assert` ranges/writes
**only** over relations reachable from its `Cap`. There is no ambient authority and
no global relation namespace at runtime — you reach a relation **only** through a
`Cap` you were handed. (`defocus`'s `Value::Ref{verbs}` attenuation, generalized
from object-refs to relation-handles.)

### G. Replay (determinism made operable)

**`replay`** `(log: [Fact], seed: Seed) → World`
Reconstruct the entire derivable world from seed + the append-only commit log.
Pure; bit-for-bit. This is not really a "new" primitive — it is the statement that
`assert` is the *only* writer and everything else is a pure query, so the log + seed
*is* the world. Included to make the law operable and testable (it is the test
harness's hook).

> **That's the whole algebra: `relation, rule, assert, query, budget, gen, at,
> elapse, grant, replay`** (+ the `Value`/`Query`/`Budget` data types). Ten
> verbs. No object, no message, no tick, no method, no inheritance — those are all
> *views* (`§7`).

---

## 3. Event-driven, never tick — time as a column

Time is the **commit order** of the log. `CommitId` is monotonic; it *is* the clock.

- **Nothing sweeps.** There is no `advance(to_tick)` that delivers scheduled
  messages tick-by-tick (contrast `defocus::World::advance`, which loops). A
  "scheduled future event" is just a fact `due(key, t, event)` in a relation; it is
  never *delivered* — it is **queried into existence** the first time some `query …
  at t'` with `t' ≥ t` ranges over it. The future is lazy.
- **A relation that changes over time** is keyed with a validity interval:
  `glyph_depth(glyph_id, depth, from, to)`. The "current" depth is
  `at(scan glyph_depth, now)`. Asserting a new depth supersedes by setting the old
  row's `to` and inserting a new row from `now` — append-only, no overwrite.
- **The 3-year jump is O(commits on the key), not O(years).** Years with no
  committed event touching a key contribute *zero* rows. `elapse` integrates the
  gap in one closed-form evaluation. Time has no length cost — only event-density
  cost. This is attention-bounded materialization across **time**, by the same
  demand-frontier mechanism as space (§4).

---

## 4. The eager↔lazy continuum — ONE mechanism

There are not two modes. There is one **demand-driven evaluation frontier**:

- Every derived/generated tuple is either **resident** (cached in a
  `materialized(rel, key, cols, as_of)` relation — itself just EDB) or **virtual**
  (absent; recomputed by `query`/`gen`/`elapse` on read).
- The slide is **per-tuple and continuous**, driven by two scalars on each key: an
  **attention** count (how often it's been queried recently — itself a relation
  `attention(key, score)` updated by `query` as a side-fact) and a **causal-load**
  count (how many *other* committed tuples join against it). A tuple with high
  attention×load is kept resident (eager pole); an untouched one decays to virtual
  (lazy pole). The policy `keep_resident(key) :- attention(key,a), load(key,l),
  a*l > threshold(b)` **is itself a rule** — the continuum's control law is data,
  tunable, inspectable.
- `existence` (eager, small-N) is this continuum pinned near the resident pole;
  `defocus` (stub-until-observed) is it pinned near the virtual pole. **Same
  substrate, two operating points** — exactly the law's claim, and here it is one
  caching predicate, not two code paths.
- `budget` is how a *caller* asks for a point on the slide for *this* query: a
  large `budget` forces deep eager expansion now; a small one returns the coarse
  resident prefix. Faithful coarsening (§6) guarantees they don't disagree.

---

## 5. Capability security, relationally

Authority = a `Cap` = an attenuated handle to a (relation, verb-set, row-filter).
There is no global relation table reachable at runtime; a consumer holds a root
`Cap` granted by the host and `grant`s narrower ones onward. A glyph-carving tool
handed `grant(world, glyph, {write}, filter: owner==me)` can write *only* glyph
rows it owns and can read nothing. Nothing forges a relation handle (you cannot
`Sym`-name your way to authority — naming a relation you lack a `Cap` for yields
*no rows*, never an error that leaks existence, and never a write). Allow-list by
construction.

---

## 6. Faithful coarsening (mipmaps for meaning) falls out for free

Because a query is **lazy and ordered**, the cheap answer is *literally a prefix*
of the expensive one:

- `query(q, budget=small)` expands the join/`gen`/`elapse` frontier to shallow
  depth and returns the high-prevalence tuples first (prior-weighted order is part
  of `gen`/`Scan` ordering, deterministic by key-seed).
- `query(q, budget=large)` continues the *same* ordered expansion deeper.
- The large answer ⊇ the small answer, tuple-for-tuple, because both are the same
  deterministic enumeration truncated at different depths. **No popping**: leaning
  in only ever *adds* tuples, never *changes* one — a committed tuple is immutable,
  and `gen` is key-seeded so re-deriving it deeper yields the identical row. This is
  the semantic-layer mipmap property, obtained as a theorem about ordered lazy
  evaluation rather than as a separately-engineered LOD system.

---

## 7. Everything familiar is a view (collapse asymmetries to primitives)

- **Object** = `entity(id)` ∪ the facts keyed on `id`. **Component** = a relation.
  **ECS** = the relational lens with the join restricted to one shared key column.
- **Message/handler** (the `defocus` model) = a rule:
  `effect(target,…) :- event(verb,target,payload), handler(target,verb,rule), …`.
  An actor send is `assert(event(…))`; the "step loop" is `query`ing the `effect`
  relation. The actor model is a *stratification discipline* over relations.
- **Inheritance/prototype** = a recursive rule:
  `has(O,K,V) :- state(O,K,V)` ; `has(O,K,V) :- proto(O,P), has(P,K,V), not state(O,K,_)`.
- **Scene graph / containment** = a relation `child(parent, kid)` with transitive
  closure as a recursive rule.
- **Knowledge graph** = base relations already; the substrate *is* the semantic
  layer's representation, not a separate thing bolted on.

One primitive set spans the world-state, the rules, the schema, the knowledge
graph, the capability system, and the LOD system — because they are all relations.

---

## 8. THE HARD CASE, worked end to end

> *A player carves a glyph into a rock, walks away, returns 3 in-game years later,
> and inspects it closely.*

### (a) The carve — a commitment

```
; tool holds: cap_g = grant(root, glyph, {write,read}, owner==P)
assert( (glyph,         [g7, rock42, P, "spiral"]),            cap_g )  ; key=[g7]
assert( (glyph_depth,   [g7, 0/1, t0, +∞]),                    cap_g )  ; depth 0, valid [t0,∞)
assert( (carved_at,     [g7, t0]),                             cap_g )
```

Three base tuples enter the log. The key is `g7` (the glyph's identity *is* its
key — no object box). What is **committed** is the *effect* (a spiral glyph of
initial depth exists on rock42, made by P at t0) and, by a rule, the *entailment*:

```
rule( weathering_law_applies(G) :-  glyph(G,_,_,_) )    ; no guessed weathered state committed
```

No future weathering is computed or stored. The next 3 years cost **nothing** —
the log grows by zero rows while the player is away; no tick advances; the glyph is
a virtual tuple at the lazy pole of the continuum (attention decays to 0).

### (b) The 3-year jump — no per-tick

The player returns at `t1 = t0 + 3y`. Returning is not a sweep; it is the engine
issuing queries for what the player can now perceive. There is **no loop over the
3 years.** A coarse glance:

```
query( at( Scan(glyph, [g7, rock42, ?, ?]), t1 ), under=cap_view, budget=small )
   → (glyph, [g7, rock42, P, "spiral"])        ; immutable base fact, unchanged
```

That's the cheap mipmap level — "a weathered spiral glyph" — and it touches only
the one base row. Cost: O(1). The 3 years contributed no rows to scan.

### (c) Close inspection — consistent weathered detail, ZERO facade

The player leans in. Same query, deeper budget, and now the *depth-at-t1* is asked
for. `glyph_depth` has only the `[g7, 0/1, t0, +∞]` row — no committed value at
`t1`. So `query` invokes the **time primitive**, not a tick loop:

```
elapse( key=[g7], from=t0, to=t1, law=law(glyph_depth, weather_fn) )
```

`weather_fn(depth0=0/1, Δt=3y)` is a serializable closed-form law — e.g. depth
*decreases* (erosion rounds the groove) by an integrated rate that depends on
rock-hardness and exposure. Where the law is stochastic (micro-pitting, a hairline
crack), `elapse` seeds its draw by `hash(seed, g7, t0, t1)` — **so the exact
weathered pattern is a deterministic function of the glyph's key and the interval**,
identical on replay and on every client. The fine detail (which grains spalled,
the lichen specks) comes from `gen`:

```
Gen( glyph_microdetail, key=[g7, t1], prior=ref(semantic: weathered_sandstone) )
   → (glyph_microdetail, [g7, t1, <lichen=2 specks, pit pattern …>])
```

- **No facade.** Every detail revealed is *entailed* by `seed + key + the committed
  facts` (initial depth, material, exposure, interval) under the weathering law and
  the prevalence prior. It was not pre-stored (the world wasn't stored) and not
  fabricated (it's a pure function of committed constraints). It is **deterministic
  revelation** — the exact face the law+seed always implied for `g7` at `t1`.
- **Consistent with the carve.** The `elapse`/`gen` draws are *constrained* by the
  committed base facts: the glyph is still a spiral by P (immutable base row); only
  the *derivable* depth/microdetail are revealed, and they must satisfy
  `weathering_law_applies(g7)` and not contradict any committed row. A query that
  re-glances coarsely still returns the same base row (faithful coarsening: the
  close view *added* microdetail tuples, it did not change the glance).
- **Commit-on-observation.** Because the player *observed* the weathered depth, the
  realizer `assert`s it: `assert((glyph_depth,[g7, d1, t1, +∞]), cap_g)` (and sets
  the old row's `to=t1`). Now the weathered state is committed — a permanent
  constraint. If the player returns *again* in 5 more years, `elapse` integrates
  from `t1`'s committed depth, never re-deriving the first interval. The world grew
  by exactly the rows the player's attention paid for, and not one more.

### (d) Determinism / replay check

`replay(log, seed)` reconstructs identically: the EDB is `[glyph, glyph_depth×2,
carved_at, glyph_microdetail, …]`; every derived tuple re-derives from key-seeded
`gen`/`elapse`; the demand frontier is a pure function of the query trace recorded
in the log. Two clients that both observe the inspection commit the **same** rows
in the **same** log order (multiplayer needs the shared commit order — §8 honesty
below), so neither forks.

---

## 9. What this HIDES or ASSUMES (the poison, named)

1. **Stratification is a baked ordering commitment.** Datalog's well-defined
   fixpoint needs *stratified* negation/aggregation. That bakes a partial order on
   rules into the interface — a premature ordering commitment the law warns against.
   Truly mutually-recursive negation (common in social/belief loops: "A trusts B
   iff B doesn't betray A iff …") is *not expressible* without choosing a semantics
   (well-founded? stable-model/ASP?). I have assumed stratification; that is a real
   restriction on what behaviors are rules.

2. **`gen`/`elapse` assume closed-form or key-local generation — the corner is not
   solved.** The whole no-facade story rests on `gen` producing a tuple **consistent
   with every overlapping committed fact** at bounded cost. That is exactly the
   open CSP-under-determinism crux (`simulation-depth-and-materialization.md`): for
   **global** (non-key-local) constraints `gen` can paint into a corner with no
   consistent completion, and detecting that is NP-hard in general. My algebra
   *names* this honestly (it lives in `gen`) but **does not solve it** — it assumes
   the locality lever (keep constraints key-local so joins are local) holds for the
   game's content. Where a constraint is genuinely global, this primitive set has no
   bounded-cost guarantee.

3. **Key = identity is a premature identity commitment.** Making the canonical RNG
   seed *be* the tuple's key is what buys order-independence and replay — but it
   assumes a **stable canonical key exists** for every generatable thing. "NPC#7's
   affective memory of parent#2's cooking" must have ONE canonical key reachable all
   ways (the open *stable query identity* problem). If the natural key is ambiguous
   or path-dependent, my determinism story breaks. I assumed keys are canonical;
   coining them for an unbounded lazy query space is unsolved.

4. **Exact rationals hide the float problem rather than solving it.** Banning float
   from the core makes the core deterministic cheaply, but pushes every continuous
   quantity (positions, forces, the soft-body surrogate) either into rationals (cost,
   precision blowup over integration) or into a non-deterministic rendering leaf
   (then physics-driven *commitments* aren't in the core). For a physics-heavy
   consumer this is a real premature-representation commitment — possibly the
   wrong one.

5. **The commitment boundary is assumed, not defined.** "Observation ⇒ `assert`"
   needs a sharp rule for *what* counts as observed and *which* entailments commit
   (commit too much → back-fitting; too little → drift). My algebra makes `assert`
   the seam but leaves the *policy* to the consumer — that policy is load-bearing and
   I have not specified it. (The open *commitment boundary* problem.)

6. **Multi-observer order is assumed given.** Replay determinism needs a single
   canonical commit order. With concurrent self-hosted observers, *what that order
   is* is unsolved; `assert`'s `CommitId` assumes a totally-ordered log, i.e. a
   consensus/sequencer I have not designed. (The open *multiplayer* problem.)

7. **Relations may be the wrong shape for irreducibly heterogeneous glue.** The
   data-over-code principle is *conditional*. Some seams (one-off scripted set-pieces,
   bespoke UI glue) are genuinely closures wearing a tuple costume; forcing them into
   `rule(head,body)` AST yields a leaky lowest-common-denominator `Query` language
   that grows without bound (every escape hatch becomes a new `Query` node). The
   honest cost: either the `Query` AST bloats toward a full programming language
   (un-minimal), or a code-seam escape hatch re-enters (un-pure). I have kept the AST
   minimal and *assumed* the game's logic is mostly relational; that assumption is
   the bet.

8. **Aggregation/recursion cost is hidden behind `budget`.** A `budget` ceiling
   makes cost *bounded* but can make an answer *incomplete in a way that's hard to
   distinguish from "no such tuple."* "Incomplete, never wrong" holds, but the
   consumer must treat budget-truncation correctly or it will read absence as
   falsehood — a sharp footgun the interface does not prevent.

---

## 10. Real tradeoffs

**Wins.**
- **One mechanism for six concerns.** World-state, rules, schema, knowledge graph,
  capability, and LOD are all relations + queries — maximal collapse of special
  cases to primitives, which is the explicit foundation-discipline target.
- **The law's hard parts become theorems, not features.** Faithful coarsening = lazy
  ordered evaluation is prefix-monotone. Eager↔lazy = one resident/virtual predicate.
  No-facade = entailment-only query. Determinism = append-only EDB + key-seeded
  `gen`. These *fall out* of the lens rather than being engineered alongside it.
- **No tick, genuinely.** Time as a column + `elapse` makes the 3-year jump O(events),
  not O(time) — the law's "across time" clause is met by construction, not by a
  cleverly-large tick.
- **Rules-as-data is native, not retrofitted** — a rule is a tuple; inspection,
  diffing, and capability-gating of *behavior* are the same operations as for data.

**Losses / risks.**
- **The open crux lives inside `gen` and is not closed** (poison #2): bounded-cost
  consistent generation under a growing global constraint set is exactly the
  NP-hard-in-general residue. The relational framing *localizes* it cleanly (and the
  locality lever maps to key-locality) but does not dissolve it.
- **Stratified Datalog is a real expressivity ceiling** (poison #1): the most
  interesting social/belief dynamics want non-stratified recursion-through-negation.
  Choosing ASP/stable-model semantics would lift the ceiling but re-imports
  NP-completeness into *every* query, not just `gen`.
- **The relational tax on imperative/continuous work** (poison #4, #7): physics
  integration and bespoke glue are awkward; expressing them relationally is either
  costly (rationals, recursive rules for stepping) or an escape hatch that erodes
  purity.
- **Cognitive distance.** Designers think in objects/actors; this substrate makes
  them think in relations and rules. Views (§7) recover the familiar surfaces, but
  the *base* mental model is further from how `defocus` (and most games) are built —
  an adoption cost that is real even though it is not a technical defect.

**Net.** The relational lens is the **strongest available fit for the law's
structural clauses** (no-store, no-facade, no-tick, LOD, rules-as-data, capability)
— it turns most of them into properties of one evaluation mechanism. It is the
**weakest fit for the law's hardest open clause** (bounded-cost consistent
generation), which it honestly relocates into `gen` without solving, and it carries
a genuine expressivity ceiling (stratification) and a continuous-math tax. It is a
candidate that wins the *architecture* and concedes the *crux* — which is the honest
state of the whole project.
