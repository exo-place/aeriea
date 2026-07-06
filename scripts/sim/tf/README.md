# TF substrate — transformations as marinada expressions over a plain-struct tree

**Status: EXPERIMENTAL. Not user-certified. Not green.** This is a design-uncertified
substrate module. It is wired into the canonical test runner (`tf_substrate_test`) but no
game surface depends on it yet, and the user has not verified it. Do not treat it as settled.

It supersedes the throwaway demos formerly in `prototypes/tf-substrate/` (removed). Those were
expected-wrong learning artifacts around an over-built cell/fold/`Expr`/`mget` kernel; this is
the clean rebuild of the plain model they were converging toward.

## The model (exactly this — no more)

**State is a tree of plain structs.** A part (`tf_part.gd`, `TFPart`) is a bag of named
fields (each a plain value — number / string / bool / list / dict), an ordered list of
children, and a parent link. A field holds a value; you read it directly. No value|expr
union, no cell, no accessor, no id. A body is the root part plus its subtree.

**Behaviour is AUTHORED CONTENT, not engine code.** A transformation is a **marinada
expression** — data, authored in an authored marinada module (`tf_library.gd`) and looked up
by name. It is evaluated by a GDScript core evaluator (`tf_marinada.gd`). The old hardcoded
`kind → Callable` dispatch is gone: `tr["kind"]` now names a transformation-DEFINITION
exported by the authored `lib:tf-core` module, resolved once into a plain `kind → closure`
table the engine consumes exactly like the old dispatch table — but every entry is authored
data, not code. Data and computation are still separate; the computation is now content.

**Purity vs in-place mutation is reconciled by a return protocol.** Marinada `set`/`set-in`
are pure (return NEW records); our tick mutates in place. So a transformation is a PURE
marinada expression that RETURNS a result record

    { "transition": <new transition record>, "fields": <record field-name -> new value> }

and the ENGINE writes it: it replaces the transition-list entry with `transition` and writes
each `fields` entry into `part.fields` in place. Marinada stays pure; the engine owns
mutation and evaluation order. Each definition is a lambda over the fixed tuple
`(part, root, tr, seed, coord, idx, ntrans)` — see `tf_library.gd`.

**Structural mutation is a third, OPTIONAL return channel** — `structural`. The same result
record may carry a `structural` key: a plain-data Array of tree-edit DESCRIPTIONS the engine
applies (add/remove/move a subtree) via `TFPart.add_child` / `detach`. Marinada still returns
only plain data; the engine performs the edit. This is the discrete-TOPOLOGY half of the
topology(discrete) × magnitude(continuous) split (`dynamical-transformation.md`): a part
"grows in" as a discrete graft-at-zero-extent PLUS a continuous magnitude transition riding on
the new part — never a half-existing part. The common no-structural path is unchanged: absent
`structural`, nothing extra runs.

    { "transition": <new transition record>,
      "fields":     <field-name -> new value>,
      "structural": <Array of edit records — OPTIONAL> }

Each edit is a plain dict; `part`/`at`/`to` are opaque TFPart handles (from tree queries),
defaulting to the transition's own host part when omitted:

    { "op": "graft",    "node": <node-spec>, "at":   <TFPart?> }  — build node-spec, add as child of `at`
    { "op": "detach",                         "part": <TFPart?> }  — structural remove
    { "op": "reparent", "to":   <TFPart>,     "part": <TFPart?> }  — detach then re-add under `to`

A **node-spec** is plain data describing a new subtree, materialized by `TFEngine._materialize`
(fields deep-copied so grafts never alias the authored description):

    { "fields": <field bag — may include a "transitions" Array>, "children": [ node-spec, ... ] }

A grafted part whose `fields["transitions"]` holds a magnitude transition (e.g. `accrue` on
`size` from 0) is the continuous half of "grows in". New parts grafted this tick are NOT in the
tick's pre-order snapshot, so they first tick NEXT tick — the same discipline as transitions
appended this tick. Applied in pre-order × list-order ⇒ fully replayable. `merge` / `split`
(transformation-system.md §4.2) are DEFERRED — graft/detach/reparent prove the mechanism and
merge/split compose from them plus field writes. The authoring layer has twin actions
`{"op":"graft",…}` / `{"op":"detach",…}` on `apply_action` (sharing `_materialize`), but the
RETURN channel is primary: "a transformation adds a part" means a transformation, mid-tick,
returns a graft.

**Transition `kind` is a string literal** — a transition's `kind` field must be the literal
definition-name string (e.g. `"accrue"`). Under the correct semantics a bare `"accrue"` IS
already a string literal — it evaluates to itself, never to the `accrue` closure. So `grow_tail`
authors the grafted transition kind as the bare string `"accrue"` directly; no `__lit` wrapper
is needed. The `["__lit", v]` form is kept as a deprecated alias only (it still evaluates to
`v` identically to a bare string). Variable references — the accrue closure when called as a
function — use `["var", "accrue"]`; that is a separate, explicit form that never appears in a
`kind` field. The engine guards against non-String or unrecognized kinds with `push_error`.

**§D [OPEN] draw-stream identity under restructuring** — a stochastic transition's `coord`
keys off `mix2(part-index, transition-index)`, and `part-index` is the part's slot in the
tick's pre-order. A graft/detach/reparent that changes how many parts sort before a given part
shifts its index next tick, reshuffling its draw series. Replay stays EXACT (same seed+log ⇒
same pre-order ⇒ same coords), so determinism holds; only "this part's stream is stable across
a rearrange" is what §D does not yet guarantee. Deliberately NOT fixed here (see
`tf_engine.gd` tick comment where `coord` is computed, and `grow_tail`'s note).

**Progress is accumulated plain state.** A part's active transitions live in an ordinary
field `fields["transitions"]` — a plain Array of plain dicts. Appending starts one; list
position is recency (last = most recent, exposed to the definition as `idx == ntrans-1`).
Each entry holds its own `prog`, so parallel entries advance independently and out of step.
Progress is stepped by the transformation returning a new `prog`, never from a clock.

**Execution is one deterministic total order** (`tf_engine.gd`, `TFEngine.tick`): parts in
tree pre-order, and within a part its transition list in order. Fields mutate in place — no
snapshot, no previous-state buffer. A cross-part read sees this-tick values from sources
earlier in the order and last-tick values from sources later; the one-tick lag is emergent
from the order, not a stored buffer. There is no priority field and no authoring index.

**Determinism is seed + action log.** An action (`TFEngine.apply_action`) is a plain-data
record that mutates the tree / starts-stops transitions / writes fields. `TFEngine.run_log`
folds a log of actions and `tick` markers over a freshly-built tree; the same seed + same log
reproduce identical final state with no stored world snapshot.

**Pause and stochastic are not primitives** — they are how a transformation is authored.
Pause = the marinada expression reads a plain condition field and conditionally returns the
current value unchanged. Probabilistic = a seeded draw that conditionally returns a no-op.

## Tree binding — decision: HOST OPS over opaque part handles (NOT reified records)

A transformation references other parts by field-predicate + relational traversal, never by
index path. Two shapes were possible: (a) reify the whole TFPart tree into nested marinada
records each eval, or (b) expose tree navigation as host ops that take opaque part handles.
**We chose (b).** Parts flow through the evaluator as **opaque host values** (TFPart objects
that evaluate to themselves); the tree is never copied into records. Navigation is a family
of host ops wrapping `tf_tree.gd` unchanged, and predicates are ordinary marinada lambdas
(`["fn", ["p"], ["==", ["part-field", "p", "kind"], "breast"]]`) that the host op applies per
part. This preserves the topology-independent by-field/relational reference model verbatim —
identity lives in fields, location lives in structure, no id and no location field — while
keeping the marinada core tiny. Reifying to records would have to re-encode parent links and
part identity as data, re-inventing exactly what `tf_tree.gd` already provides.

Host tree ops: `part-field` (with optional default), `part-parent`, `part-children`,
`find-first`, `find-all`, `nearest-ancestor`, `nearest-ancestor-excluding`,
`topmost-in-chain`, `has-ancestor`.

## Seeded draws — host ops keyed off (seed + deterministic coordinate)

Marinada has no RNG. We add a deterministic-draw family wrapping `tf_rng.gd`: `mix2`,
`draw-int`, `draw-unit`, `chance`. The engine binds `seed` and a base `coord = mix2(part-index,
transition-index)` into the definition's environment. A transformation that draws more than
once (or across ticks) mixes in a per-transition draw counter it carries in its own transition
record (`_draws`), so the coordinate is a pure function of deterministic state — never a clock,
never a global stream. Same seed + same log ⇒ identical draws; a different seed diverges.

## Marinada conformance — implemented vs skipped

Authority: `/home/me/git/rhizone/dusklight/docs/marinada.md`. We implement the pure
value/expression subset a transformation needs, conforming to the spec's atom-vs-call form and
op names. **A bare string ALWAYS evaluates to itself — it is a STRING LITERAL**, conforming to the
spec. Variable references are the EXPLICIT special form `["var", name]`, which looks up
`name` in the environment and errors loudly if unbound. Op names in HEAD position are
always taken literally. `["__lit", v]` is kept as a deprecated backward-compat alias: it
evaluates to `v` identically to a bare string — not the authoring path.

**Implemented ops:** get, get-in, set, set-in; + - * / %; == != < > <= >=; and or not;
if, cond, do, let, letrec, fn, call, match (over capitalized DU constructors); array, count,
array-get, array-push, array-slice; record (added — see below), record-get, record-set,
record-del, record-keys, record-vals, record-merge; floor, ceil, round, abs, min, max, pow,
sqrt, int->float, float->int; to-string, str-concat; untyped/as (identity — no checker);
var (variable reference — explicit env lookup, errors on unbound);
__lit (deprecated alias — evaluates to its payload, same as a bare string).

**Added (marinada gaps the substrate needs):** `record` (literal record constructor — the spec
lists `record-set`/`record-merge` but no way to build a record from nothing); the seeded-draw
family and the tree-navigation family above.

**Skipped (not needed by the substrate), and why:**
- Reactive signals — the substrate is a discrete tick, not a reactive graph.
- Algebraic effects (`perform`/`handle`), `Error`/`Async`/`Yield` — a transformation is a
  pure value computation; the only "effect" (field mutation) is the engine's return-protocol
  write, outside marinada.
- Capabilities / `call.method` — no world-boundary authority inside a transformation.
- Gradual type checker, linear/affine types, `is`/typed narrowing — evaluation-only; ill-typed
  authored content is a content bug, not enforced here.
- Optimizer / JIT / TCO — a straightforward interpreter suffices; recursion depth in
  transformations is shallow.
- `?` / result-propagation, bitwise ops, most higher string ops, `parse-int`/`parse-float`,
  inline `type` DU declarations (constructors are inferred from a capitalized head) — unused.

## Files

- `tf_part.gd` — `TFPart`: the plain struct + tree ops + deep clone/equals.
- `tf_tree.gd` — `TFTree`: pre-order flatten + field/relational queries (host-op backing).
- `tf_rng.gd`  — `TFRng`: seeded, coordinate-keyed deterministic draws (draw-op backing).
- `tf_marinada.gd` — `TFMarinada`: the marinada core evaluator (env, closures, match, host ops).
- `tf_library.gd` — `TFLibrary`: the authored `lib:tf-util` / `lib:tf-core` modules, the module
  resolver, and `build()` → the `kind → closure` transformation library.
- `tf_engine.gd` — `TFEngine`: the tick (applies definitions, writes results), actions, replay.
- `../../../tests/tf_substrate_test.gd` — the suite (evaluator conformance + 8 contract cases,
  the last being structural mutation: grow-a-tail via graft + magnitude transition).
