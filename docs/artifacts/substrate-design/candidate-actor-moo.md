# Candidate substrate algebra — ACTOR / MESSAGE-PASSING MOO

Status: **candidate for adversarial de-poisoning** (2026-06-22). One design,
committed fully to the actor / message-passing / prototype-delegation MOO lens
(defocus lineage). Not frozen.

---

## The lens, held without flinching

Everything in the world is an **object**: a bag of state, a set of **handlers**
keyed by message **verb**, and a **prototype** it delegates to. Nothing happens
except by **sending a message** (asynchronously) to an object's **capability
reference**. Behavior is selected by walking the delegation chain to find a
handler. A handler is **data** — a serializable AST, not a closure, not source
text, not a neural net. A reference is a **capability**: holding one is the only
way to message the object it names, and a reference can only be **attenuated**
(narrowed), never widened. There is no ambient authority, no global "world"
object you can reach without a ref, no `eval` of arbitrary text.

This is defocus's model. defocus is the closest existing substrate and it is
**wrong on three of aeriea's laws**: it is tick-driven (`advance(to_tick)` over a
`BTreeMap<u64,…>` schedule), it stores the whole world (`objects: BTreeMap`
persisted), and it calls the LLM in the hot loop (`["llm", …]` during eval).
This candidate keeps defocus's algebra and *repairs exactly those three seams*
inside the same actor lens — without adding a feature API.

The single repair that does all three: **an object's existence is itself a
message it has not yet been forced to answer.** Materialization is `resolve` —
the act of delivering an object its own constructor-message — and that act is
deterministic, lazy, capability-gated, and event-logged. Eager vs. lazy is just
*when* `resolve` is forced. There is no second mechanism.

---

## The core algebra (the game's lambda calculus)

Eleven primitives. Everything else — physics, NPC minds, weathering, prose,
inventory — is objects-with-handlers expressed *in* this algebra, never new
primitives. The set is closed: no primitive may be added without showing an
existing one cannot express the case.

Notation: `Cap` = a capability reference; `Verb` = a string; `Value` = the
defocus value lattice (Null/Bool/Int/Float/String/Array/Record/Cap) plus one
addition, `Stub` (below); `AST` = a `Value` interpreted as an expression.

### 1. `OBJECT` — the only noun

```
OBJECT = {
  proto:    Cap | Null          # delegate target (prototype chain)
  state:    Record<Verb→Value>  # committed facts about this object
  handlers: Record<Verb→AST>    # behavior, as data
  seed:     Bytes               # this object's slice of the deterministic seed
}
```

Semantics: an object is the unit of identity, state, behavior, and
materialization. It is **never** addressed directly — only through a `Cap` to it
(primitive 3). `state` holds *only committed facts* (see law: never store the
world). `handlers` are ASTs selected by delegation. `seed` is the object's
deterministic entropy: every generated detail of this object is a pure function
of `seed` + the messages it has answered. An object with empty `state` and a
`genesis` handler it has not yet run is a **stub** — fully genuine, just not yet
forced.

### 2. `SEND` — the only verb of action (asynchronous)

```
SEND(to: Cap, verb: Verb, payload: Value) → ()        # fire-and-forget
```

Semantics: enqueue the message `{verb, payload}` for delivery to `to`, *iff*
`verb` is permitted by `to`'s attenuation (else silently dropped — deny by
capability, defocus's exact rule). `SEND` returns immediately; it does **not**
return a reply. Asynchrony is total: the sender does not block, does not observe
the receiver's state, cannot assume ordering beyond causal (a message sent *by*
handler H is enqueued after the message that triggered H). This is the actor law
and it is the reason there is no global clock: time *is* the partial order of
message causality, nothing else.

Delivery: when dequeued, the receiver's handler for `verb` is found by
`RESOLVE`-then-delegation-walk (primitive 5), evaluated, its effects applied. A
message to a verb with no handler anywhere in the chain is a no-op (logged).

### 3. `CAP` — the only reference (capability)

```
CAP(id) is unforgeable; obtained only by:
  - being passed one in a message payload,
  - reading one already in your own state,
  - ATTENUATE-ing one you already hold,
  - receiving one as the result of SPAWN.
ATTENUATE(c: Cap, verbs: Set<Verb>) → Cap   # narrow only; verbs ⊆ c.verbs
```

Semantics: a `Cap` names an object and carries an allow-list of verbs. You
cannot construct a `Cap` from an id string; you can only *come to hold* one by
the four routes above. `ATTENUATE` is monotone-decreasing — the result permits a
subset. There is no `widen`, no `Cap::root`, no registry you can enumerate
without already holding a cap into it. This is the whole of authority: the world
graph is the capability graph. (defocus's `Ref{id, verbs}` is exactly this; we
forbid the `with_ref("frame","local:frame")` string-construction backdoor that
defocus's *builder* allows — at the algebra level a `Cap` is opaque.)

### 4. `SPAWN` — bring an object into the addressable graph

```
SPAWN(proto: Cap|Null, genesis: AST, seed_salt: Value) → Cap
```

Semantics: create a new object whose `proto` is given, whose `seed` is
`derive(parent.seed, seed_salt)` (pure), whose `handlers` are empty (it inherits
from `proto`), and whose `genesis` handler is `genesis` (the constructor AST,
run lazily on first `RESOLVE`). Returns an unrestricted `Cap` to it. **This is
the only way new identity enters the world**, and it is logged: the event log
records *that* this cap was spawned with this `(proto, genesis, seed_salt)` —
**not** the resulting state. State is re-derived on replay by re-running
`genesis`. (Contrast defocus `Effect::Spawn{object}`, which logs the whole
materialized object.)

### 5. `RESOLVE` — the materialization primitive (the eager↔lazy continuum)

```
RESOLVE(c: Cap, demand: Detail) → ()    # force this object to depth `demand`
Detail = Int | Record   # a partial order: how deeply state must be committed
```

Semantics: this is the heart. `RESOLVE` delivers an object the implicit message
"become real to depth `demand`." It runs the object's `genesis` (if not yet run)
and any **deepening handlers** whose `demand`-threshold the request crosses,
*committing* the resulting facts into `state`. Crucially:

- **Idempotent & monotone.** `RESOLVE(c, d1)` then `RESOLVE(c, d2)` commits
  exactly the union; a shallow resolve is a *true prefix* of a deep one (the
  faithful-coarsening / no-popping law from `semantic-layer.md`). Re-resolving to
  a depth already reached is free.
- **Pure.** What `RESOLVE(c, d)` commits is `f(c.seed, c.state-so-far, d)` —
  independent of *when* or *via which path* it was called (the order-independence
  precondition from `simulation-depth-and-materialization.md`).
- **The continuum.** "Eager" = something `RESOLVE`s an object to high `demand`
  immediately (e.g. the object the player holds). "Lazy" = nobody has `RESOLVE`d
  it past `genesis`, so it is a `Stub`. There are **no tiers**: `demand` is a
  point on a partial order, and any object slides along it by who messages it and
  how hard. Attention and causal load are literally "how high a `demand` the
  surrounding objects send."

A reference to an unresolved object is a `Stub` value: it has identity (a `Cap`)
and a known `proto`, but its `state` is undetermined-but-determinable. Reading
`Stub` state without `RESOLVE` yields the typical-value projection from the
prototype (the cheap glance), explicitly marked as un-committed — never a fact.

### 6. `OBSERVE` — commitment-on-inspection (the no-facade gate)

```
OBSERVE(c: Cap, query: AST) → Value    # the ONLY way to read another object
```

Semantics: `OBSERVE` is the *synchronous read* primitive, and it is the **only**
operation that turns possibility into fact. It `RESOLVE`s `c` to exactly the
`demand` that `query` requires, then returns the queried slice of committed
state — and **appends the answer (and its entailments) to the event log as a
commitment** (the commit-on-observation rule). Before `OBSERVE`, the detail was
free to be anything the seed+constraints allow; after, it is bound forever and
every later generation must respect it.

This is how *no facade* is enforced mechanically: there is no read path that
does not go through `RESOLVE` (genuine deterministic revelation) + commit. You
cannot "describe" an object without making the described detail true. A cheap
glance and a deep inspection differ only in the `demand` they pass — never in
*kind* — so they cannot contradict. Fabrication is structurally impossible: the
only values `OBSERVE` can return are committed `state`, which is only ever
written by `RESOLVE`, which is pure over the seed.

(defocus has no `OBSERVE` — handlers read other objects' state directly via the
world map during eval. That is the facade hole: state can be read without being
made genuine. We close it: cross-object reads are messages, and reading commits.)

### 7. `SELF` / `SENDER` — reflexive identity (handler-local)

```
SELF   → Cap     # an unrestricted cap to the object running this handler
SENDER → Cap|Null  # attenuated cap to whoever sent the current message, or Null
```

Semantics: inside a handler, `SELF` is how an object messages or resolves itself
(deepening, self-modification); `SENDER` is the *only* authority a handler gains
from being messaged — and it is whatever cap the sender chose to include, so
authority flows strictly forward (you can only reply to who reached you, at the
attenuation they granted). External (player-origin) messages carry `SENDER =
Null`. This is defocus's self/sender binding, kept verbatim — it is already the
capability discipline done right.

### 8. `BECOME` — state commitment (the only mutation)

```
BECOME(facts: Record<Verb→Value>) → ()   # commit facts into SELF.state
```

Semantics: the sole writer. A handler `BECOME`s new committed facts about
itself. This is monotone in spirit (facts accumulate; a "change" is committing a
new value for a key, and the *prior* value remains in the event log, so history
is never lost — the substrate stores the log, derives the present). `BECOME` is
how `RESOLVE`'s deepening handlers commit generated detail, and how ordinary
gameplay mutates the world. An object can only `BECOME` *itself* — no object
writes another's state (writes are `SEND`s the target chooses to honor).
(defocus `perform set` → this, restricted to self.)

### 9. `EVAL` — interpret an AST (rules-as-data executor)

```
EVAL(ast: AST, env: Record) → Value      # pure interpreter over the value lattice
```

Semantics: handlers *are* ASTs; `EVAL` is the deterministic interpreter that
runs them (defocus's `eval`: `get`, `if`, `let`, `do`, `map`, `match`, arithmetic,
`concat`, …, plus the effect-performing forms which desugar to primitives 2/4/8).
`EVAL` is pure: no I/O, no clock, no RNG except seeded draws keyed to `SELF.seed`.
It is the reason behavior is **inspectable data** — any handler can be read,
diffed, transported, and re-run; there is no opaque executable anywhere. The
LLM, if used at all, is a **build-time** producer of ASTs and of the prevalence
prior (`semantic-layer.md`), never an `EVAL` operand. (We delete defocus's
runtime `["llm", …]` form outright — retire, don't deprecate.)

### 10. `AFTER` — causal scheduling without a clock (event-time, never tick)

```
AFTER(span: Causal, to: Cap, verb: Verb, payload: Value) → ()
Causal = a measure on the causal order (e.g. game-seconds), NOT a tick index
```

Semantics: "deliver this message when `span` of causal time has elapsed *at the
recipient*." Critically, `AFTER` does **not** schedule against a global tick
counter that something must sweep. It records a **deferred message stamped with a
causal coordinate**. The message is materialized *only when something forces the
recipient's timeline to or past that coordinate* — i.e. when the recipient is
next `RESOLVE`d/`OBSERVE`d at a logical-time ≥ the stamp. No observer ⇒ the
deferred message sits inert; it costs nothing and advances nothing. This is the
3-year-jump mechanism: elapsed time is a *coordinate*, and arrears are settled
lazily, in one deterministic computation, at the moment of attention — never by
3 years of ticks. (This **replaces** defocus's `schedule: BTreeMap<u64>` +
`advance(to_tick)` tick sweep entirely.)

### 11. `QUERY` — capability-scoped associative lookup

```
QUERY(scope: Cap, pattern: Record) → Array<Cap>
```

Semantics: find objects matching `pattern` *within the sub-graph reachable from
`scope`* (the room you hold a cap to, your own contents). Returns attenuated caps
(matching only — never the whole world; there is no `QUERY(world, …)` because no
one holds a cap to "the world"). Matching is over **already-committed** state
only — `QUERY` does not force `RESOLVE` (it would otherwise materialize the world
just to look for something), so a stub matches only on its prototype-typical
facts. This keeps "find the hostile NPCs in this room" (defocus's `query` test)
expressible while honoring both capability-scope and attention-bounding.

---

## How the substrate law's hard parts are expressed

**Attention-bounded materialization in SPACE.** Space is the capability graph; a
region is an object whose `state` holds caps to its contents. You materialize
only what you `RESOLVE`/`OBSERVE`, and you can only reach what you hold a cap to.
An unentered room is a stub cap inside a region; its contents don't exist as
committed state until something sends them `RESOLVE`. Cost is proportional to the
caps you actually traverse — engagement, not world size.

**Attention-bounded materialization in TIME.** `AFTER` stamps causal coordinates;
`RESOLVE`/`OBSERVE` carry a logical-time. An object's "current state" is
`f(seed, committed facts, all deferred messages whose stamp ≤ now-of-this-resolve)`
— settled in a single deterministic fold at the moment of attention. Unobserved
intervals are never iterated.

**Event-driven, never tick.** There is no `advance(to_tick)` and no global
schedule sweep — those are deleted. The only engine loop is "deliver the next
queued message," and the queue is fed by `SEND`/`AFTER`-matured messages and by
player input. `AFTER` defers by *causal coordinate settled on attention*, so the
absence of a sweep is not a gap to fill — there is genuinely nothing to do
between events.

**No-facade deterministic generation.** Every read is `OBSERVE` → `RESOLVE` →
pure `f(seed, …)` → commit. There is no code path that returns un-committed,
seed-inconsistent detail as fact. The cheap glance (`Stub` typical-projection) is
*explicitly marked non-fact*; the only way to get a fact is to commit it
genuinely. Faithful coarsening is structural: `RESOLVE` is monotone, so shallow ⊂
deep, so no popping.

**The eager↔lazy continuum.** One primitive, `RESOLVE(c, demand)`, with `demand`
a point on a partial order. Eager and lazy are not modes or tiers — they are
*how high a `demand` the neighborhood is currently sending an object*. The player's
held object gets high `demand` from the rendering/interaction loop; a pebble in
an unentered cave gets none and stays a stub. Same object, same primitive, slides
continuously.

---

## The hard case, worked end to end

> A player carves a glyph into a rock, walks away, returns 3 in-game years later
> and inspects it closely.

**Setup.** The cave region holds a stub cap `rock`. `rock`'s prototype is
`granite`, which carries (as handlers/AST) a `genesis` that commits coarse facts
(it is granite, ~80cm, grey) and a `deepen` handler that, given a higher
`demand`, commits grain, micro-fractures, and a *weathering function* — all pure
over `rock.seed`.

**1 — Carving = a commitment (`SEND` → `BECOME`, logged).**
The player's tool holds an attenuated cap to `rock` permitting `carve`. The carve
action is `SEND(rock, "carve", {glyph: "ᛟ", depth: 4mm, at: <face-coord>, t0:
<now>})`. `rock` is `RESOLVE`d to the `demand` carving needs (it must have a
committed surface to cut). Its `carve` handler runs (`EVAL`) and does
`BECOME({carving: {glyph:"ᛟ", depth0:4mm, at:…, t0:…, by:<player-cap>}})`. The
event log now records the *carve message* and the *committed carving fact*. This
is a genuine, bound fact — not a description. Nothing about the glyph's *future*
weathered appearance is computed or stored; only the cause (the cut, at t0) and
the seed are on the record. (This is the flinch example's shape: commit the
effect + the existence of a consistent history, never a guessed future.)

**2 — Walking away (no per-tick anything).**
The player leaves; nobody holds a live attention-cap into the cave. `rock`
receives no messages. The weathering of the glyph over the next 3 years is **not
simulated**. There is no schedule entry counting frames, no tick sweep visiting
the cave. The committed facts (granite, the carve at t0) and `rock.seed` sit
inert. Cost of 3 unobserved years: **zero**. The 3-year span exists only as the
*difference between two logical-time coordinates* that nothing has yet evaluated.

**3 — The 3-year jump (`AFTER`-style settle on attention, one computation).**
Return. The player re-enters the cave with logical-time `t0 + 3yr`. Entering
sends `rock` a `RESOLVE` at that logical-time. `rock`'s `deepen`/weathering logic
runs *once*: it computes the glyph's current state as a pure function

```
weathered = WEATHER(rock.seed, carving@t0, elapsed = (t0+3yr) − t0, local_conditions)
```

`elapsed` is a single subtraction of coordinates — **not** 3 years of iteration.
`WEATHER` is deterministic (seeded by `rock.seed` so this rock's lichen and
spalling pattern are *this rock's*, reproducible on replay) and monotone in
`demand`. At entry-distance `demand` is low: it commits "the glyph is softened,
darkened, partly lichened" — a coarse but true summary.

**4 — Inspecting closely (`OBSERVE` at high `demand`, zero facade).**
The player leans in: `OBSERVE(rock, {query: carving, detail: high})`. This
`RESOLVE`s `rock` to high `demand`, so `WEATHER` is forced deeper *on the same
seed and the same elapsed coordinate*: it now commits the specific micro-detail —
each stroke's edge rounded by 0.6mm, a hairline crack crossing the upper rune,
lichen colonizing the deepest cut where water pooled. Because `RESOLVE` is
monotone and pure, this deep answer **contains the coarse one as a prefix** (the
softening seen at distance is exactly the summary of the rounding seen up close —
no popping, no contradiction). Because it is keyed to `rock.seed` + the committed
`carving@t0` + `elapsed`, it is the *same* weathering the substrate would have
produced had anyone watched all 3 years — there was simply no need to watch.
These fine facts now commit to the log; a second inspection, or another player on
the shared log, sees identically. **Zero facade**: every weathered detail was
deterministically *revealed* from seed + the carve commitment + elapsed time,
never fabricated, and it could not have been read without being made genuinely,
permanently true.

---

## What this HIDES or ASSUMES (the poison, named honestly)

1. **`Detail`/`demand` as a partial order is the load-bearing unsolved piece.**
   The whole no-popping guarantee rests on `RESOLVE` being *monotone* in `demand`
   — shallow always a true prefix of deep. Authoring weathering/genesis handlers
   that are genuinely monotone across an arbitrary `demand` lattice is hard, and
   nothing in the algebra *enforces* it; a buggy handler can pop. This is the
   `semantic-layer.md` "LOD axis is OPEN" problem relocated, not solved. **Poison
   risk:** if `Detail` quietly becomes an integer "tier," I've reintroduced tiers
   under another name.

2. **Global consistency across objects is under-served.** This algebra makes
   *intra-object* generation clean (pure over `SELF.seed`), but the crux from
   `simulation-depth-and-materialization.md` — painting into a corner under a
   *growing global* constraint set — lives *between* objects, and my primitives
   push consistency onto `OBSERVE`'s "entailments" hand-wave. I assume most
   constraints are **local** (the locality lever) so per-object seed-purity
   mostly suffices. Cross-object invariants ("these two NPCs share a true
   history") have no first-class home here and would need a third object to own
   the joint fact — workable but not proven, and the NP-hard residue is untouched.

3. **`OBSERVE`-commits-everything may grow the log without bound.** Every read
   binds facts forever. A player who exhaustively inspects a city commits a city.
   The commitment-boundary question (`simulation-depth-and-materialization.md`,
   OPEN) is assumed-away: I commit on *every* observe. Real systems will need a
   policy for what *not* to bind (transient glances), which my algebra doesn't
   express — a premature-commitment risk in the literal sense.

4. **Asynchrony assumes a single canonical message order.** Actors give partial
   order; determinism needs a *total* order for the log. I assume a single
   well-defined delivery order (one runtime). Multiplayer's concurrent-commit
   ordering (OPEN upstream) is not addressed; two clients delivering in different
   orders fork. I've inherited, not solved, this.

5. **`AFTER` assumes elapsed effects are closed-form-foldable.** The 3-year jump
   is cheap *only if* weathering is a function of `elapsed`, not a path-dependent
   integral over events that happened meanwhile. If something causally
   interesting *should* have happened in those 3 years (a flood, a war passing
   through), there was no observer to commit it, so it generates backward on
   demand — but inter-event interactions that aren't expressible as a fold are a
   real expressivity hole I'm hiding behind "local, foldable" weathering.

6. **Identity is assumed stable & path-independent but not constructed.** `Cap`
   carries an `id`; I assert caps to the same object compare equal regardless of
   route, but I don't *build* the canonical-key namespace
   (`simulation-depth-and-materialization.md`, OPEN). Spawn-derived ids work;
   reached-two-ways identity for *generated* sub-objects (NPC#7's memory of
   parent#2's cooking) is assumed, not delivered.

7. **Float determinism.** `EVAL`/`WEATHER` use float arithmetic; bit-for-bit
   replay is runtime-bounded, same caveat all the sibling substrates carry. Kept
   shaped for a later fixed-point swap as a leaf change; not solved.

---

## Tradeoffs

**Bought:** a genuinely tiny, inspectable core (11 primitives, all data-or-pure)
that expresses attention-bounded materialization, event-time, no-facade, and the
eager↔lazy continuum with *one* materialization primitive (`RESOLVE`) and *one*
commitment gate (`OBSERVE`) — no feature API. Capability security is the graph
itself, not a bolted-on ACL. It repairs defocus's three law-violations (tick
sweep → `AFTER` causal settle; world-store → seed+log derivation; hot-loop LLM →
build-time AST/prior) *without leaving the actor lens*. Rules-as-data falls out
for free: handlers are ASTs `EVAL` runs.

**Paid:** the actor lens makes *intra-object* genuineness beautiful and pushes
the genuinely hard problem — *inter-object* global consistency under a growing
constraint set — to the margins, where it's served only by "entailments" and the
locality assumption. The hard CSP-under-determinism crux is *not* solved by this
algebra; it's relegated to handler-authoring discipline and the hope that
constraints stay local. Monotone `RESOLVE` is asserted, not enforced — the
no-popping law is only as good as the handlers. And commit-on-every-observe
trades a clean rule for unbounded log growth absent a boundary policy this
algebra can't yet state.

**Net:** the strongest fit to the *stated* lens and the cleanest expression of
the materialization/event-time/no-facade laws; the weakest coverage of the
cross-object satisfiability crux, which it honestly relocates rather than
resolves. A real consumer (the hard case above, built for real) is the poison
detector that would force #1, #2, and #3 into the open.
