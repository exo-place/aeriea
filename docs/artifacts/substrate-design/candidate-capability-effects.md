# Candidate substrate algebra — CAPABILITY-OBJECT / ALGEBRAIC EFFECTS

Status: **adversarial design candidate** (2026-06-22). One of several
independently-framed candidates for aeriea's minimal core substrate algebra. Not
a decision. Held until red-teamed against a real consumer.

> **Lens (committed, not abandoned mid-design):** Entities ARE capabilities.
> Behavior IS algebraic effects interpreted by handlers. Attention and
> materialization are THEMSELVES effects — not engine machinery sitting above the
> algebra, but operations *in* it. Determinism = pure interpreters folding over a
> logged effect trace. Everything below is forced through this single lens; where
> the lens fights the substrate law, I say so rather than escape it.

---

## 0. The one-sentence shape

> The world is a **pure interpreter** that folds a **handler environment** over an
> **append-only trace of performed effects**, where every entity is a **capability
> handle** carrying its own handlers-as-data, and the *only* way anything happens —
> including being looked at, being made detailed, and time passing — is by
> **performing an effect that some handler in scope answers.**

There is no world store, no tick loop, no privileged "engine." There is a trace,
a set of handlers, and a fold. `state = fold(interpret, seed, trace)`.

---

## 1. Why this lens, against the law

The substrate law's four hard parts map *onto effects*, which is the whole bet:

| Law requirement | In this algebra it is… |
|---|---|
| event-driven, never tick | the trace is a list of `Perform`; there is no clock that ticks. "Later" is an effect (`Advance`), performed only when something needs it. |
| never store the world | the trace stores *performed effects* (creations + observations); world-state is the *fold result*, recomputed, never persisted as truth. |
| no facade / deterministic revelation | `Materialize` is an effect whose handler is a **pure deterministic generator** keyed by stable identity + committed constraints. It reveals; it cannot fabricate, because its output is a function of inputs already on the trace. |
| eager↔lazy continuum | eager = the handler for `Observe` synchronously performs `Materialize` to full depth; lazy = it returns a **capability stub** and defers `Materialize`. Same two effects, different *handler*, slid per-entity by an attention parameter. |

The lens earns its place by making the four hard parts *the same kind of thing*
(effects with handlers) instead of four bespoke engine subsystems.

---

## 2. The primitive set (the lambda calculus)

Eleven primitives. Three are **values** (the data the algebra moves), four are
**effects** (the verbs of the algebra), four are **interpretation** (the pure
machinery). Nothing is a feature; each is irreducible under the lens.

### 2a. Values — what the algebra moves

Everything is a `Value`. Code is data: an effect, a handler, a rule, a constraint
are all `Value`s. This is the data-over-code seam.

```
Value :=
  | Atom(bytes)                         -- opaque leaf: number, text, symbol, blob
  | Tuple([Value])                      -- ordered composite
  | Map({Key: Value})                   -- keyed composite (BTree-ordered → canonical)
  | Cap(CapHandle)                      -- a capability handle to an entity
  | Effect(EffName, Value)              -- a *suspended* effect = data until performed
  | Handler(Pattern, Body)              -- a rule: pattern over effects → body, as data
```

`Effect(...)` and `Handler(...)` being ordinary `Value`s is the load-bearing
move: behavior is inspectable data (hard constraint: rules-as-data, no opaque
runtime net). A neural net may *produce* a `Handler` value at build time; at
runtime only the data `Handler` runs, deterministically.

---

#### P1 — `Cap` : capability handle (the entity primitive)

```
Cap = { id: Identity, rights: Set<EffName> | ALL, since: TraceIndex }
```

**Semantics.** A `Cap` is the *only* way to denote an entity. It is **not** the
entity's state — it is an unforgeable handle authorizing a set of effects against
an identity. Holding a `Cap` is the sole authority to `Perform` an effect on that
entity (capability security: nothing forges authority; there is no ambient "look
up entity by id"). `rights` is an allow-list (attenuation, never amplification);
`since` pins which trace prefix the handle was minted under, so a handle cannot
reach effects committed before it could legally exist.

A `Cap` is *not* "materialized" or "stub" — that distinction does not live in the
entity. It lives in *how its `Observe` handler responds*. The entity is always
just a handle; depth is a property of the answer, never of the thing. **This is
how the eager↔lazy continuum avoids being tiers:** there is no field that says
"I am eager." There is only attention flowing into handlers.

---

#### P2 — `Identity` : stable, access-path-independent name

```
Identity = derive(parent_identity, salt: Value)        -- pure, total
```

**Semantics.** Identity is **generated, never stored as a counter**, by a pure
derivation from a parent identity + a salt value. `derive(root_seed, "glyph@rock#3/layer/weathering")`
yields the *same* identity however it is reached — through the rock, through the
player's memory, through a conversation about the glyph (this is the substrate
law's open "stable query/fact identity" problem, answered structurally: identity
is a pure function of a content-path, so two access paths to the same thing
collide by construction). Identity is the canonical key; `Cap` wraps it with
rights. No global registry — the namespace is the free monoid over salts under a
seed.

---

#### P3 — `Constraint` : a committed fact + its entailment (the no-facade primitive)

```
Constraint = { about: Identity, claim: Value, entails: [Value] }
```

**Semantics.** The unit of "what is true." When an effect is *observed* (enters
the trace), it commits a `Constraint`: a `claim` (the literal fact) plus its
`entails` (the existence-claims it logically forces — "a consistent cause
exists," never a *guessed* cause). This is the constrain-then-generate discipline
made primitive: the trace accumulates `Constraint`s; `Materialize` must produce
answers consistent with all `Constraint`s it touches. Commit effects + existence
of cause; never commit the cause. "Incomplete, never wrong" is the invariant on
this primitive: a `Constraint` is added, never edited or removed (append-only),
so the constraint set is monotone — the precondition for deterministic replay.

---

### 2b. Effects — the verbs (there are exactly four)

An effect is performed against a `Cap`. The verb set is closed and minimal:
everything in §3 (attention, time, generation) is *expressed through these four*,
not added as new verbs.

#### P4 — `Perform(cap, Effect(name, arg)) → Value`

**Semantics.** The single act of the algebra. Requires `name ∈ cap.rights`
(capability check; unauthorized perform is a no-op that commits nothing — not an
error that fabricates). `Perform` (a) appends the effect to the trace, (b) finds
the handler in scope answering `name` for `cap.id` (P9), (c) runs it under the
interpreter (P8), (d) returns the result `Value`. **Performing is the only thing
that mutates the trace.** No handler, no store, nothing else appends. This is
where "event-driven" is enforced at the type level: there is no API that advances
state without a `Perform`.

#### P5 — `Observe(cap, lens) → Value` *(an effect: attention is a verb)*

`Observe` is `Perform(cap, Effect("observe", lens))`, called out as a named
primitive because **attention is materialization's trigger and must be in the
algebra, not above it.** `lens` is a `Value` describing *how closely* and *along
what axis* (a glance vs. a close inspection; visual vs. semantic). The handler
for `observe`:

- decides, from `lens` + the entity's attention/causal-load, **how far to slide
  on the eager↔lazy continuum**: a shallow lens returns a coarse `Value` (a true
  *prefix*, faithful-coarsening / mipmaps-for-meaning); a deep lens performs
  `Materialize` to refine;
- **commits a `Constraint`** for exactly what it revealed (commit-on-observation),
  so the answer binds all later generation.

The faithful-coarsening law lives here: the coarse `Observe` result MUST be a
true prefix of the deep one (the handler is obligated to draw the coarse answer as
a deterministic projection of the same ground truth it would deepen — no popping).

#### P6 — `Materialize(cap, depth, constraints) → Value` *(an effect: generation is a verb)*

The deterministic generator `G`, *as an effect*. Its handler is a **pure function**
of `(seed, identity, depth, the constraint set it touches)` — never of wall-clock,
never of access order, never of an LLM call. It returns the entity's state to the
requested `depth`, consistent with every `Constraint` it reads. Because it is
keyed on identity + committed constraints and is pure, calling it twice yields the
same answer (no fabrication; only revelation). It may *itself* `Perform` further
effects to deepen sub-parts lazily (recursive descent down the continuum). This is
the substrate's open crux (CSP-under-determinism / painting-into-a-corner) sited
**inside one handler** — the algebra localizes the hard problem rather than
solving it, which is the honest move.

#### P7 — `Advance(cap, until) → Value` *(an effect: TIME is a verb, never a tick)*

The kill-shot against tick-driven sim. `Advance` performs the *elapse of time on
one entity* as a deterministic function of its state and an interval — **a jump,
not a sweep.** `until` is a logical point (a trace index, or a counterfactual "as
of N intervals later"). The handler computes the entity's state *at `until`
directly*, in closed form where the rule allows (e.g. weathering(Δt)), without
visiting intermediate points. No global clock advances; only the entity you touch
ages, only when you touch it, and only to the moment you ask for. Time is
per-entity, on-demand, O(1)-in-Δt where the rule is closed-form. **`Advance` is
how 3 in-game years pass with zero per-tick work.**

> Four effects: `Perform` (act), `Observe` (attend), `Materialize` (reveal),
> `Advance` (elapse). Attention, generation, and time are *verbs in the algebra*.
> This is the lens kept whole.

---

### 2c. Interpretation — the pure machinery (four)

#### P8 — `interpret : (Env, Effect) → (Value, [Constraint])`

The **pure interpreter**. Given an environment of handlers and a performed effect,
it (deterministically) selects a handler, evaluates its `Body` (the handler is a
`Value` — see eval as a fold over `Value` AST), and returns the result plus any
`Constraint`s committed. *Pure*: same `(Env, Effect)` → same output, on every
runtime and every path. All non-determinism (RNG) is seeded and threaded through
`Env`. This is where `state = f(seed, trace)` is literally true: the interpreter
is `f`.

#### P9 — `resolve : (Env, Identity, EffName) → Handler`

Handler lookup. Walks a **prototype/scope chain as data** (entity's own handlers →
prototype's → region's → root) to find the `Handler` answering an effect. Handlers
are values attached along the chain; resolution is pure and capability-scoped (you
can only resolve effects your `Cap` carries rights for). This is *the* extension
point: new behavior = a new `Handler` value in scope, never new interpreter code.
"Rules as data" is enforced because `resolve` returns a `Value`, and `interpret`
can only run `Value`s.

#### P10 — `Trace` : the append-only effect log (the only persistence)

```
Trace = [ (Identity, Effect, result_digest, [Constraint]) ]      -- append-only
```

**Semantics.** The single durable artifact. Stores **what was created or
observed** (performed) — *not the world*. Sparse by construction: unperformed
effects (unobserved centuries, unprobed NPCs) are simply absent, costing nothing.
Replay = `fold(interpret, seed, Trace)` reconstructs all state bit-for-bit. The
`result_digest` lets replay detect divergence (e.g. cross-runtime float drift) —
the trace is self-checking. **This is "never store the world" + "deterministic"
in one primitive.**

#### P11 — `fork : Trace → Trace` and `seed : () → Seed` (the deterministic frame)

`seed` is the single root of all derivation (identities, RNG, generation). `fork`
produces an independent trace sharing a prefix (for speculation, multiplayer
branch reconciliation, undo). Both are the *boundary* of the pure system: nothing
inside the algebra reads anything but `seed` and `Trace`. Everything else —
wall-clock, network, the player's actual eyeballs — only ever enters as a
`Perform` someone makes, becoming an effect on the trace. The membrane to reality
is exactly the set of `Perform` calls.

---

## 3. How the law's hard parts are expressed (or fought)

- **Attention-bounded materialization in SPACE.** `Observe(cap, lens)` with a
  shallow `lens` returns a coarse prefix and commits a coarse `Constraint`; a deep
  `lens` performs `Materialize` to refine. The *budget* is the `lens` itself —
  attention is literally the argument that bounds depth. Unobserved space is
  un-performed, hence absent from the trace, hence free.

- **Attention-bounded materialization in TIME.** `Advance(cap, until)` ages *only
  the touched entity*, *only to the asked moment*, in closed form. There is no tick
  budget because there is no tick. Time-depth is bounded by what you `Advance`, the
  same way space-depth is bounded by what you `Observe`.

- **Event-driven, never tick.** The trace is `[Perform]`. The interpreter is a
  fold, invoked by `Perform`, never by a clock. `Advance` makes "time passing"
  itself an event. There is no loop in the substrate that runs when no one acts —
  the law's hardest structural demand is met by *not having a loop primitive at
  all.*

- **No-facade deterministic generation.** `Materialize`'s handler is pure over
  `(seed, identity, depth, constraints)`. It cannot fabricate because its range is
  fixed by its inputs, and its inputs are all on the trace. It commits effects +
  *existence* of cause (`Constraint.entails`), never a guessed cause — so a later
  deep probe generates the cause *backward from the committed effect*, consistent,
  at query time. Incompleteness (unprobed = unwritten) is not lossiness
  (wrong-written). The no-facade law is the *purity + monotone-constraints*
  property of two primitives (P6, P3).

- **Eager↔lazy as ONE continuum.** Not tiers, not a flag. The *same* `Observe`
  handler, parameterized by an attention/causal-load scalar derived from how much
  the entity is being performed-against, chooses how much `Materialize` to perform
  inline. Heavy attention → synchronous deep materialize (the `existence` eager
  pole). No attention → return a `Cap` stub, materialize nothing (the lazy pole).
  An entity slides continuously frame to frame by how hard it is being looked at;
  the slide is just the argument to one handler.

---

## 4. The hard case, end to end, through the primitives

> *A player carves a glyph into a rock, walks away, returns 3 in-game years later
> and inspects it closely.*

**(a) The carve — a commitment.**
The player holds `Cap(rock, rights⊇{observe,carve,...})`. Carving is
`Perform(rock_cap, Effect("carve", {tool, glyph: "᚛ᚐᚎ᚜", force, at_surface_point}))`.
`resolve` finds the rock's `carve` `Handler` (a `Value` rule). `interpret` runs it
and it:
- commits `Constraint{ about: derive(rock.id,"glyph#0"), claim: {shape:"᚛ᚐᚎ᚜", depth_mm: f(force), tool: chisel}, entails: [ "a surface intersecting this glyph exists", "a weathering history starting now exists" ] }`;
- appends the `carve` effect to the `Trace` with that constraint.
Nothing about the *future weathered look* is stored — only the carve fact and the
*existence* of a weathering history beginning at this trace index. No facade: the
weathered detail is not invented now and is not promised as any particular shape;
only "a consistent weathering history exists" is committed.

**(b) Walk away — nothing happens (the point).**
The player performs effects elsewhere. The rock receives **no** effects. Because
the substrate has no tick loop, the rock does not age, is not visited, costs
nothing. Three in-game years are simply a *larger gap of trace indices on other
entities* — the rock's last trace entry is still the carve. **Genuineness is not
violated:** the rock is not "frozen"; it is *un-asked*, and an un-asked entity has
no observable state to be wrong about.

**(c) The 3-year jump — `Advance`, no per-tick.**
On return, the engine (because the player's gaze falls on the rock) performs
`Advance(glyph_cap, until = now)`. The glyph's `advance` handler computes
weathering *in closed form over Δt = 3yr*: it reads the committed
`Constraint` (carve depth, tool, the "weathering history exists" entailment) and
the rock's material/exposure (themselves `Observe`d/`Materialize`d as needed,
recursively down the continuum), and produces the weathering *state at +3yr
directly* — `erosion = weather_model(depth_mm, material, exposure, Δt=3yr)` — with
**zero intermediate steps**. No 3-years-of-ticks were ever run. The result commits
a `Constraint` "glyph weathering state at T+3yr = …", consistent with the original
"a weathering history exists" entailment (it *is* that history, finally
generated).

**(d) Close inspection — consistent materialization, zero facade.**
The player performs `Observe(glyph_cap, lens = {axis: visual, closeness: HIGH})`.
The deep `lens` drives the `observe` handler to `Materialize(glyph_cap, depth=FINE,
constraints = {carve fact, weathering@+3yr})`. `Materialize` is pure over
identity + those constraints + seed, so it deterministically reveals fine detail —
lichen in the deeper strokes, softened edges where erosion is highest, the chisel's
original bite still legible at the protected base — **as a function of the committed
facts**, not freshly imagined. Crucially:
- It is **consistent**: the fine answer is a deepening of any coarse glance the
  player took on approach (faithful coarsening — the glance was a true prefix).
- It is **zero-facade**: every fine detail is entailed by `seed + carve constraint
  + weathering constraint`; probe deeper (run a fingernail in a groove, ask an NPC
  geologist) and `Materialize`/`Observe` descend further, still consistent,
  because each new answer commits a `Constraint` the next must honor.
- It is **replayable**: the whole episode is `[carve, …gap…, advance, observe]` on
  the trace; `fold(interpret, seed, trace)` reproduces the exact weathered glyph
  bit-for-bit (modulo the float caveat the `result_digest` catches).

The carve was a *commitment*; the 3 years were a *single `Advance` jump*; the
weathered detail was *deterministic revelation under a deep `lens`* — all four
primitive-classes, no tick, no facade.

---

## 5. What this HIDES or ASSUMES (the poison, named honestly)

1. **`Materialize` hides the crux.** The single hardest unsolved problem
   (deterministic, bounded-cost generation satisfying an unboundedly-growing global
   constraint set without painting into a corner) is *inside one handler*. The
   algebra makes the hard part *local and named*, which is honest, but it does
   **not solve it** — a `Materialize` handler that draws greedily can still commit
   to an unsatisfiable future. The algebra assumes such handlers can be written;
   the prior art says that's NP-hard in general, tractable mostly by keeping
   constraints local. **This is the candidate's biggest IOU.**

2. **Closed-form `Advance` is assumed, and won't always exist.** The 3-year jump
   is O(1) *only* when the entity's evolution is closed-form in Δt (weathering,
   decay). For path-dependent evolution (an NPC's 3 years of relationships, a
   river that rerouted), `Advance` degenerates toward replaying sub-events — the
   tick comes back in disguise. The algebra hides *which* dynamics are closed-form;
   that classification is unsolved and is real premature-commitment risk if the
   `Advance` signature implies all dynamics jump cheaply.

3. **Identity-by-content-path assumes a canonical path exists.** P2 makes identity
   a pure function of a content-path, dissolving access-path divergence — but it
   *assumes every entity has one canonical content-path*. Emergent things with no
   natural address (the *third* ripple in a puddle, "the mood of the room") may
   have no canonical salt, forcing either fabrication of one (poison) or a
   fallback registry (breaks the "no global store" purity). Untested.

4. **The `lens` value is a premature-commitment magnet.** "How closely, along what
   axis" is doing enormous work and is barely specified. If `lens` bakes in a fixed
   set of axes (visual/semantic/…) or a scalar closeness, it commits to a model of
   attention that may not survive contact with VR foveation, NPC theory-of-mind
   attention, or multi-observer attention. I kept it an opaque `Value`
   deliberately, which *defers* the poison rather than removing it.

5. **Append-only monotone constraints assume no legitimate retraction.** Replay and
   no-facade rely on `Constraint`s never being removed. But beliefs are revisable
   (an NPC learns it was wrong; the player misremembers). Modeling revision *without*
   mutating the trace (e.g. as new constraints that *supersede* via a defeasible
   layer) is unaddressed — the algebra currently conflates "true" with "committed,"
   which is too strong for minds.

6. **Multi-observer ordering is assumed away.** `Perform` appends to *the* trace.
   With concurrent observers there is no single trace until an ordering is chosen;
   `fork` gestures at branch reconciliation but the canonical-order problem (the
   law's open multiplayer crux) is not in the primitives. This is a known hole, not
   a solution.

7. **Float determinism is punted** (shared with all sibling substrates): `interpret`
   is "pure" over float arithmetic, so cross-runtime replay is bounded by the
   runtime. `result_digest` *detects* divergence but does not *prevent* it; the
   fixed-point door is kept open as a leaf swap, not taken.

---

## 6. Real tradeoffs

- **Win: the four hard parts collapse to one mechanism.** Attention, time, and
  generation are all effects with handlers; there is genuinely *no* tick loop and
  *no* world store as primitives — the law's structural demands are met by absence,
  not by discipline-on-top. That is the strongest property of this candidate.

- **Win: maximal inspectability + capability security come free.** Behavior is
  `Handler` *values* on a chain; authority is `Cap` rights; persistence is one
  append-only trace. Every hard constraint (rules-as-data, no opaque net,
  nothing-forges-authority) is structural, not aspirational. Directly inherits
  defocus's validated value/Ref/handler-as-data model — but fixes its two
  law-violations (defocus is tick+schedule-driven, and runs the LLM in the step
  loop): here time is an effect and the LLM is build-time-only, producing `Handler`
  data.

- **Cost: the algebra is honest about being a *frame*, not an *engine*.** It
  localizes every hard problem into a handler (`Materialize`, `Advance`) and then
  the handlers are where all the unsolved difficulty actually lives. A skeptic can
  fairly say it "renames the crux as a handler." The defense: a frame that makes
  the crux *local, pure, inspectable, and replayable* is worth more than one that
  smears it across an engine — but it is a frame, and the IOUs in §5 are the price.

- **Cost: performance of replay-as-truth.** `state = fold(interpret, seed, trace)`
  is conceptually clean but means current state is a *recomputation*. Real systems
  will need memoized fold checkpoints (a cache of `Materialize` results), which must
  be provably *pure caches* (derivable, droppable) or they silently become the
  world-store the law forbids. The discipline line is thin.

- **Cost vs. eager candidates.** Against an always-eager `existence`-style sim, this
  pays a complexity tax (the continuum machinery, the constraint bookkeeping) to buy
  unbounded worlds at engagement-proportional cost. If the target world is small and
  always-attended, that tax is pure overhead — this candidate only wins when the
  world is large and sparsely probed, which is exactly aeriea's bet.

---

## 7. Minimal-consumer test (how to de-poison this empirically)

The candidate is unvalidated until a real consumer exercises it. The smallest
honest consumer is **the §4 hard case itself**, implemented: a rock + glyph, a
carve, a no-op gap, an `Advance`, a deep `Observe`, then `fold`-replay asserting
bit-identical weathered output and asserting the coarse glance was a true prefix of
the deep inspect. That single consumer pressures P3/P6/P7/P10 directly and will
immediately surface IOUs #1, #2, and #5. Build that before trusting any of this.
