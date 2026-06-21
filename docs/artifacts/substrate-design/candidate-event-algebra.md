# Candidate substrate algebra — the EVENT-ALGEBRA lens

Status: **CANDIDATE for adversarial de-poisoning** (not frozen). One design,
committed fully to a single lens: **the committed event log IS the primitive.**

> **The lens, held without flinching.** There is no "world." There is a seed and
> a totally-ordered, content-addressed log of *events*. Every other notion —
> entity, location, time, the rock, the glyph, the player — is a **fold** (a
> deterministic reduction) over a *projection* (a filtered slice) of that log.
> "State" is not stored and advanced; "state" is the *value returned by a fold
> evaluated at a cut of the log.* Time is not a clock that ticks; time is a
> **coordinate carried on events**, and "jumping 3 years" is choosing a later cut
> and folding — never stepping. Materialization is **memoization of a fold**, and
> the eager↔lazy continuum is *how far the memoized prefix of each fold has been
> forced.* This lens is honored everywhere below; where it strains, the strain is
> named, not papered over.

This is deliberately **the game's lambda calculus**, not a feature API. Nine
primitives, no more. If a tenth seems needed it is first checked for
expressibility from these nine.

---

## 0. The shape, in one breath

```
state(query, cut) = fold( reducer(query),  project(query, log, cut) )
```

- `log` — the seed plus the append-only, totally-ordered set of committed events.
- `project(query, …)` — selects the sub-log relevant to a query (which events
  can possibly affect this answer). The *causal cone* of the query.
- `fold` — replays that sub-log through a `reducer` to produce the answer.
- a **cut** — a position in the log's order (a time-and-causality coordinate). The
  answer is always relative to a cut; "now" is just the latest cut.

Everything else is machinery to make this **cheap, deterministic, capability-safe,
and facade-free.** Eager vs lazy is *purely* how much of a fold is forced and
cached; it changes performance, never the answer.

---

## 1. The primitive set (nine)

Notation: `E` = Event, `Log` = the committed log, `Cut` = log coordinate,
`Query` = canonical fact-key, `Frame` = capability-attenuated handle, `Val` = the
universal data value (the defocus `Value`: Null/Bool/Int/Float/String/Array/
Record/Ref — *data, never closures*). Reducers and generators are **data ASTs**
(defocus-style `Expr = Val`), never opaque code.

### P1 — `commit`  (the only writer; the only mutation in the system)

```
commit : (Frame, Intent, Cut) -> E        -- appends; returns the committed event
```

- `Intent` is a **data** record `{verb, payload, evidence}` — what is being
  asserted/created/observed. It is *not* code.
- `commit` is the **sole** state-changing operation. Nothing else writes. An
  event, once appended, is immutable and content-addressed: `E.id = H(seed,
  parents, intent, author_frame_digest)`. Identical intents from identical
  causal positions collapse to the same `E.id` (idempotent under replay).
- Every `E` carries: `parents: [E.id]` (its causal predecessors — see P9),
  `t: TimeCoord` (the event's position on the time axis — see P5), `author:
  FrameDigest` (who had authority — see P8), `intent: Intent`.
- **Authority is checked here and only here.** `commit` rejects an `Intent` the
  `Frame` is not permitted to author (P8). Nothing forges authority because
  nothing else appends.

Semantics: `commit` is how *both* "I create a thing" and "I observe a thing"
enter the world. Creation and observation are the **same operation** — both are
"a fact becomes load-bearing." This collapses the suspicious asymmetry between
"writing the world" and "revealing the world": there is one verb.

### P2 — `project`  (the causal cone of a query)

```
project : (Query, Log, Cut) -> SubLog     -- the events that can affect this answer
```

- Returns the **minimal** prefix-closed slice of `log` at-or-before `Cut` whose
  events could causally influence `Query`. Prefix-closed = if `e ∈ SubLog` then
  `parents(e) ∩ relevant ⊆ SubLog`.
- Relevance is *data-defined*: a `Query` names a region of the **fact-namespace**
  (P6), and an event is relevant iff its `intent` touches that region. No event
  is invented and none that matters is dropped — projection is a **filter**, the
  no-facade guarantee at the read boundary.

Semantics: this is what makes "never store the world" affordable. You never fold
the whole log; you fold the cone. An unprobed century of unrelated events is not
in any cone you evaluate, so it costs nothing — *cost is proportional to the
causal cross-section of the query, not to world size or world age.*

### P3 — `fold`  (the only reader; derives all state)

```
fold : (Reducer, SubLog, Cut) -> Val      -- replays a sub-log to an answer
```

- `Reducer` is a **data AST** `{init: Val, step: Expr}` evaluated by the
  deterministic interpreter (defocus's `eval`, extended). `step` is pure over
  `(acc, event)`; no I/O, no clock, no RNG except `draw` (P7).
- `fold` is **total and pure**: same `(Reducer, SubLog, Cut)` ⇒ same `Val`, on
  every machine, every path, every replay. This is `state = f(seed, log)` made
  literal — *state is never stored; it is always a fold result.*
- An **entity is a fold.** "The rock" is `fold(rock_reducer, project(rock_query,
  log, cut), cut)`. There is no rock struct anywhere. Ask at a different cut, get
  the rock as it was then. Entities are *projections of the log*, exactly as the
  lens demands.

### P4 — `materialize`  (memoize a fold prefix — the eager↔lazy slider)

```
materialize : (Query, Cut, Budget) -> Memo -- forces & caches a fold prefix
```

- `Memo` is a cached `(SubLog-prefix-digest, partial-acc, frontier)` for a fold:
  "I have already folded events up to here; resume from `frontier`."
- `Budget` is attention/causal-load. `materialize(q, cut, ∞)` forces the whole
  cone (the **eager pole** — `existence`'s always-attended depth).
  `materialize(q, cut, 0)` forces nothing; the entity stays a **stub** (the
  **lazy pole** — defocus's unobserved objects). Any budget in between forces a
  *prefix*.
- **The slider is one axis, not tiers.** There is no "LOD level 2." There is "how
  many events of this fold's cone are currently forced," a continuous integer
  from 0 to `|cone|`. An entity under heavy attention slides its frontier forward;
  an ignored one lets it sit. **Crucially, the answer at frontier `k` is a true
  prefix of the answer at frontier `k+1`** — forcing more *refines*, never
  *contradicts* (faithful coarsening / no popping). This is guaranteed because
  both are folds of the *same* `SubLog` differing only in how much is forced;
  there is no second code path to disagree.

Semantics: this is the law's "eager and lazy are two ends of one continuum"
expressed *mechanically*: they are the same `fold`, memoized to different depths.
Materialization is an optimization that is *provably* invisible to results — drop
every `Memo` and re-derive, and every answer is bit-identical.

### P5 — `at`  (the time fold — jumps, never ticks)

```
at : Cut -> Cut'                           -- choose a coordinate to fold at
TimeCoord = a point on a totally-ordered time axis carried by events
```

- Time is a **coordinate on events**, not a loop. `at(later_cut)` simply selects
  a later fold position. There is **no per-tick stepping anywhere in the algebra**
  — `fold` does not iterate over absent intervals; it reduces over the *events
  that exist*, which between two cuts may be **zero**.
- "Advance 3 years" = `at(cut_now + 3y)`. The fold over the rock's cone now
  includes time-dependent reducer terms (weathering is a *function of `Δt =
  cut.t − carve_event.t`*, computed once, not 3·365·86400 times). Empty stretches
  of time are **free**: no events, no work.
- **Scheduled/latent events** (a seed that will sprout, an NPC who will return)
  are not pre-materialized timers. They are *deterministic functions of the cut*:
  `project` at a later cut includes any event the seed+log **entails** at that
  coordinate, generated on demand by `draw` (P7) and committed-on-observation.
  Time-driven becoming is "what does the cone entail at `t`," folded — never a
  wheel that turned 95 million times while you were away.

Semantics: this is "attention-bounded materialization across **time**." Skipping
3 years costs *the number of events whose existence the later cut entails and that
you actually probe* — typically O(1) for one weathered rock — not the duration.

### P6 — `key`  (canonical, access-path-independent fact identity)

```
key : Descriptor -> Query                  -- the canonical name of a fact/entity
```

- A `Query` is a **content-addressed canonical key** for a fact or entity, derived
  *purely* from a structural `Descriptor` (e.g. "the glyph carved by author A at
  spatial cell C") — **never** from how it was reached. `key(d)` is a pure hash of
  the normalized descriptor.
- This is the **identity primitive**, and it is deliberately *not* "object id."
  Identity is *derived*, so "the same rock reached by walking back, by querying the
  region, by an NPC's memory" all `key` to the **same** `Query` and therefore the
  **same fold** — order-independence, the precondition the whole scheme rests on
  (`simulation-depth-and-materialization.md` → *Determinism*). Spatial identity is
  just a descriptor over spatial coordinates; *space is not privileged*, it is one
  namespace among facts.

Semantics: "attention-bounded materialization across **space**" falls out of this
plus `project`: a spatial region is a `Descriptor`; `project(key(region))` is the
cone of events touching that region; folding it materializes exactly the
attended-to space. No global grid is stored.

### P7 — `draw`  (deterministic revelation — the no-facade generator)

```
draw : (Query, SubLog, Salt) -> Val        -- seeded, constraint-consistent reveal
```

- When a fold reaches a fact the log has **not yet committed** (the glyph's
  micro-fracture pattern, an NPC's never-probed childhood), `draw` produces it
  **deterministically** from `H(seed, key(Query), SubLog-digest, Salt)` as a seeded
  sample over the **prevalence-weighted prior** (`semantic-layer.md` — the graph is
  `draw`'s distribution).
- `draw` is **constrained**: it samples only from completions *consistent with the
  cone* (`simulation-depth-and-materialization.md` → constrain-then-generate). It
  reveals what seed+log already **imply**; it never fabricates a fact that
  contradicts a commitment. **This is the no-facade line, mechanized:** the
  difference between *revelation* and *fabrication* is whether the output is a
  pure function of (seed, key, constraints) — `draw` is, so leaning in cannot
  change the answer, only expose more of the *same* predetermined answer.
- `draw`'s output is **not** auto-committed. It is committed only **on observation**
  via `commit` (P1) — the instant it becomes load-bearing (rendered, reasoned over,
  caused a decision). Before that it constrains nothing; after, it binds forever.
  This is the constrain-then-generate "incomplete, never wrong": unprobed detail is
  *unwritten*, not *false*.

Semantics: `draw` is the engine of "universal genuineness." Every entity is
*genuinely deepenable* because `draw` can always reveal one level further,
deterministically and consistently, with no stored bottom. The depth is real
because it is *the same on every replay and every observer* — verifiable by a
source-reader (`substrate-foundations.md` → integrity-under-inspection).

> **Honest fight — the open crux lives inside `draw`.** "Constrained,
> deterministic, bounded-cost sampling that never paints into a corner" is exactly
> the NP-hard-in-general crux of `simulation-depth-and-materialization.md`. This
> algebra does not *solve* it; it **localizes** it to one primitive and adopts the
> doc's two levers: (a) keep constraints **local** (descriptor cones are mostly
> spatially/causally local, where corner-risk empirically vanishes); (b) commit
> **effects + "a consistent cause exists,"** never guessed causes, so `draw`
> back-generates causes to fit. The residue (unbounded-incremental global
> consistency) is the owned open frontier, fenced here, not hidden.

### P8 — `attenuate`  (capability security — nothing forges authority)

```
attenuate : (Frame, Filter) -> Frame'      -- derive a strictly weaker handle
```

- A `Frame` is an **unforgeable capability handle** carrying the set of intents it
  may `commit` and the queries it may `project/fold` (defocus's
  capability-attenuated `Ref`, generalized to authority over *the log* rather than
  over a stored object). The root `Frame` is granted by the host at session start;
  there is no other source.
- `attenuate` returns a handle that can do a **subset** — never a superset. You can
  only give away authority you hold (allow-list, monotone-decreasing). `commit`
  (P1) is the sole enforcement point: it checks `intent ∈ frame.allowed`.
- Authority cannot be forged because (i) the only writer is `commit`, (ii) `commit`
  records `author: FrameDigest` from the *presented* handle, and (iii) handles are
  derivable only by `attenuate` from a held handle, rooted in a host grant. No data
  value can name itself into authority — a `Ref` in `Val` is inert until presented
  *with* a `Frame` that already holds it.

Semantics: capability-security is structural, not a checklist. The carve in the
hard case is authored under the player's `Frame`; an NPC inspecting the glyph holds
a read-only attenuation and *cannot* alter the carve event — it can only `fold` it.

### P9 — `merge`  (deterministic ordering / multi-observer convergence)

```
merge : (Log, Log) -> Log                  -- deterministic join of two log views
```

- Events form a partial order via `parents` (a Merkle-DAG). `merge` deterministically
  linearizes concurrent events into the **one canonical total order** every observer
  agrees on, by a pure tiebreak `(t, E.id)` — never by wall-clock or arrival order.
- `merge` is associative, commutative, idempotent (a **CRDT-style join** over the
  event-DAG): self-hosted peers replaying in any receive order converge to the
  **same** linearization, hence the same constraint set, hence the same folds. This
  is what keeps "the world" single-valued across the self-hosted multiplayer set
  without a central clock.

Semantics: this is the determinism law extended to many observers
(`simulation-depth-and-materialization.md` → *Multi-observer*, the open one). It
does not solve concurrent-commit *conflict semantics* (two players carving the same
cell), but it guarantees that **whatever** the conflict-resolution reducer decides,
every peer decides it identically — it moves the open problem from "ordering" into a
*data-defined reducer*, where it is inspectable.

---

## 2. How the law's hard parts are expressed

| Law clause | Mechanism |
|---|---|
| Event-driven, never tick | `at` selects a cut; `fold` reduces over *events that exist*, never over intervals. Empty time = zero events = zero work. No scheduler wheel. |
| Never store the world | Only the seed + log are stored. Every entity/place/state is a `fold` (P3) of a `project` (P2). `Memo` (P4) is a *droppable* cache, not the source of truth. |
| No facades | `draw` (P7) is a pure function of (seed, key, constraints): *revelation*, provably not fabrication. `project` filters but never invents or drops. Leaning in forces more of the *same* answer (P4 prefix property). |
| Deterministic | `fold` pure; `draw` seeded; `key` access-path-independent; `merge` order-independent. `state = f(seed, log)` is literal: there is no other state. |
| Eager↔lazy one continuum | `materialize` (P4): a single `Budget` integer = how much of a fold's cone is forced/memoized. Eager = `∞`, lazy = `0`, no tiers, per-query, slide freely; results identical at every setting. |
| Attention-bounded in space | `key`(region) → `project` → cone of that region only. No global grid. |
| Attention-bounded in time | `at`(later cut) → cone of entailed events only. Duration is free; cost is probed-events. |
| Rules as data | Reducers, Intents, generators, filters are all `Val` ASTs (defocus model). No opaque code, no runtime neural net. `draw`'s prior is the inspectable weighted graph. |
| Capability security | `Frame`/`attenuate`/`commit` (P8): one writer, monotone authority, host-rooted, unforgeable. |

---

## 3. The hard case, all the way through

> *A player carves a glyph into a rock, walks away, returns 3 in-game years later,
> and inspects it closely.*

### (a) The carve — a commitment

```
gph = key({ kind: "carving", surface: key({cell: C, face: F}), author: A })
e1  = commit(player_frame, { verb:"carve",
                             payload:{ glyph: stroke_path, depth_mm: 2.0 },
                             evidence: tool_contact },  cut_now )
```

- `e1` appends one event. It carries `t = cut_now.t`, `parents = [last event in
  the rock's cone]`, `author = digest(player_frame)`.
- **No rock object is mutated** — there is no rock object. The rock is, and remains,
  `fold(rock_reducer, project(key(rock), log, ·), ·)`. After `e1`, that fold's cone
  contains the carve, so the rock-at-any-later-cut *folds in* the glyph. The carve
  is a fact in the log, nothing more.
- Authority: `commit` checks the player's `Frame` may author `carve` on a reachable
  surface. It can. The event is content-addressed; re-running the session replays
  `e1` identically.
- What is **committed** is the *effect* ("a 2mm glyph of this path exists here, by A,
  at t0") plus the *entailment* "a consistent weathering history will exist for it."
  **No future weathering is committed.** (constrain-then-generate.)

### (b) The 3-year jump — a fold, no per-tick

```
cut_future = at(cut_now + 3y)
```

- This is **one coordinate selection.** Nothing iterates. No weather ticked, no
  erosion loop ran 94,608,000 times. The 3 years contain, in the *glyph's cone*,
  essentially **zero new committed events** (the player was elsewhere; nothing
  probed the glyph) — so the jump's cost for the glyph is **O(1)**.
- Anything that *would* have been entailed and observed in those 3 years (a
  passing NPC who noticed the glyph) is itself an event in the log via that NPC's
  own commits; if no one probed the glyph, no such event exists, and the cone is
  unchanged. **Unobserved time is unwritten, not simulated.**

### (c) Close inspection — consistent weathered detail, zero facade

```
mat = materialize( gph, cut_future, Budget=high )   -- attention forces deep
detail = fold( glyph_reducer, project(gph, log, cut_future), cut_future )
```

The `glyph_reducer`, folding the cone `[e1]` at `cut_future`:

1. Reads the carve effect from `e1`: path, `depth_mm = 2.0`, `t0`.
2. Computes `Δt = cut_future.t − e1.t = 3y` — a **closed-form** weathering term,
   evaluated **once**: `effective_depth = weather(depth_mm, Δt, rock_material,
   exposure)`. `rock_material`/`exposure` are themselves folds of the rock's cone
   (or `draw`n consistently if never committed). This is the time-fold: erosion is
   `f(Δt)`, not a sum over ticks.
3. The **micro-detail** the player now leans into — individual frost-cracks, lichen
   specks, the softened stroke edges — was never committed. It is revealed by:
   ```
   crack_pattern = draw( key({glyph:gph, aspect:"microfracture"}),
                         project(...), salt="microfracture" )
   ```
   `draw` is a pure function of `(seed, that key, the cone)`. It samples the
   prevalence-weighted prior for "how granite of this exposure frost-cracks over 3
   years," **constrained** to be consistent with `e1` (cracks follow the 2mm
   stroke; none predate `t0`).
4. **No facade, provably:** had the player inspected at `Budget=low` first (a
   glance: "weathered glyph, a few cracks"), then leaned in (`Budget=high`: the
   exact fracture map), the glance is a **true prefix** of the close look — same
   fold, same `draw` seed, more of it forced (P4). Lean in twice, on two machines,
   across replay: **bit-identical** cracks every time. The detail was *latent in
   seed+log from the moment of the carve*; inspection only *forced* it.
5. **Commit-on-observation:** the revealed fracture map, now rendered to the player,
   becomes load-bearing and is `commit`ted:
   ```
   e2 = commit( player_frame, { verb:"observe",
                                payload:{ aspect:"microfracture", value:crack_pattern },
                                evidence:"close-inspection" }, cut_future )
   ```
   From now on it is a *committed fact*, binding all future folds (an NPC who later
   describes the glyph must match it). Before `e2` it constrained nothing; the world
   was **incomplete, never wrong.**

The whole inspection cost is proportional to *how deep the player probed*, paid at
`cut_future`, with **no work for the 3 intervening years** and **no stored rock.**

---

## 4. What this HIDES or ASSUMES (the poison, named)

1. **`draw`'s tractability is assumed, not delivered.** The no-facade /
   deterministic-revelation guarantee is only as real as a `draw` that is
   *constrained, deterministic, bounded-cost, and corner-free.* That is the
   NP-hard-in-general open crux. The algebra **localizes** it to one primitive but
   does **not** solve it. If `draw` cannot stay bounded-cost as the constraint set
   grows (the iterated-belief-revision residue), the whole "cost ∝ engagement"
   promise leaks. **This is the load-bearing assumption.**

2. **A total time order is baked in (`TimeCoord`, P5).** Committing to time as a
   *single totally-ordered coordinate axis* is a premature commitment against
   genuine relativity-of-simultaneity, branching/forked timelines, or
   multiple concurrent "nows." `merge` (P9) imposes one canonical order; a world
   wanting per-region independent time, or speculative branches as first-class,
   fights this. (Mitigation: `Cut` is abstract and `parents` is a DAG, so a later
   move to per-causal-domain clocks is a leaf change — but the *interface* assumes
   one axis today.)

3. **Identity is committed to "descriptor → content hash" (`key`, P6).** This
   assumes every fact *has* a stable, access-path-independent canonical descriptor.
   Facts whose very identity is observer-relative or fundamentally fuzzy ("the mood
   of the room," "roughly where I left it") have no clean `key`, and forcing one is
   poison. The hard case works because "glyph at cell C by A" *is* cleanly
   descriptable; not everything is.

4. **The eager↔lazy slider assumes the prefix property holds for `draw`, not just
   `fold`.** `fold`'s prefix property (force more = refine, never contradict) is
   structural. For `draw` it requires that a coarse `draw` is a *true marginal* of
   the fine `draw` (the mipmap/faithful-coarsening property of `semantic-layer.md`).
   If the generator does not guarantee this, leaning in *can* pop — and the
   no-facade claim breaks at exactly the moment it matters. Assumed here; owed by
   the generator.

5. **Float arithmetic in `fold`/`draw`/`weather` is not cross-platform
   deterministic.** Same caveat the whole project carries: replay validity is
   bounded by runtime until a fixed-point swap. The algebra is shaped so that swap
   is a leaf change, but today determinism is *per-runtime*, not universal.

6. **`commit`-on-observation defines the commitment boundary by fiat.** *What*
   exactly counts as "load-bearing enough to commit" (rendered? merely reasoned
   over? mentioned in passing?) is left to the consumer. Too eager → the log and
   constraint set explode (cost leak); too lazy → facts that should bind drift.
   The algebra exposes `commit` but does **not** decide the policy — it is an open
   knob that strongly affects whether the cost promise holds.

7. **"Cost ∝ causal cross-section" assumes cones stay small.** `project` is cheap
   only if the relevant slice is small — i.e. constraints are mostly **local**. A
   world dense with **global** constraints (a fact every glyph everywhere must
   respect) makes every cone large and the cost promise collapses. Tractability is
   therefore partly a **world-design discipline**, smuggled in as an assumption of
   the algebra rather than guaranteed by it.

8. **`merge` converges ordering, not conflict *meaning*.** Two players carving the
   same cell concurrently linearize identically on every peer — but *what that
   means* (overwrite? both? reject?) is punted to a data-defined reducer the
   algebra doesn't supply. Convergence is guaranteed; *desirable* convergence is
   not.

---

## 5. Real tradeoffs

- **Wins.** The lens pays off hardest exactly where the law is hardest: time-jumps
  are *free* (coordinate selection, not stepping), space and time are the *same*
  attention-bounded `project`+`fold` machinery, eager/lazy is *provably*
  result-invariant (drop all memos, re-derive, identical), and no-facade is a
  *type-level* property (`draw` is pure ⇒ revelation, not fabrication). Nine
  primitives, all data-driven, all inspectable by a source-reader. The whole thing
  is one equation (`state = fold ∘ project`) with capability and convergence
  guards.

- **The bet is entirely on `draw`.** Eight of nine primitives are clean and
  arguably *correct by construction*. The ninth, `draw`, carries the entire open
  research risk — and it carries *all* of it, because every genuineness/no-facade/
  depth claim cashes out as "`draw` did its job." This is the design's honesty and
  its danger: it does not spread the hard problem thin to look easy; it concentrates
  it in one named place and says *that* is the moonshot.

- **vs. defocus (the foil).** defocus is the same data-as-code, capability-ref,
  event-log lineage — but it **stores the world** (`objects: BTreeMap`) and is
  **tick-driven** (`advance(to_tick)`, a `schedule` keyed by tick, a `step` queue).
  This candidate *retires* both: there is no object store (entities are folds) and
  no tick (time is a coordinate, jumps are folds). defocus proves the data-AST
  interpreter and capability refs are real and ~10k-LOC-cheap; this algebra keeps
  those two organs and replaces its skeleton.

- **vs. constrain-then-generate (the parent doc).** This is the *same* architecture
  with the event log promoted from "the thing the constraint set is a function of"
  to **the single primitive.** `G(seed, constraints, query)` ≡ `fold(reducer,
  project(query, log, cut))` with `draw` as the generative core; the "constraint
  set" *is* the log's entailment-closure under `project`. The contribution is not a
  new architecture but a **minimal primitive basis** for that architecture, with the
  eager↔lazy continuum made mechanical (`materialize`) and identity/ordering/
  authority given first-class primitives (`key`/`merge`/`attenuate`) the parent doc
  left as open prose.

- **The standing risk if the bet loses.** If `draw` cannot be made bounded-cost and
  corner-free at unbounded scale, this algebra degrades gracefully to the
  **eager pole** (`materialize ∞`, i.e. `existence`-style small-N deep sim) — which
  *works* but abandons "cost ∝ engagement" and the lazy half of the continuum.
  That fallback is the floor; the moonshot is the whole slider.
