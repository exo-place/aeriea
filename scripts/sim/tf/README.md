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
op names. **A bare string in argument position is a variable reference if bound, else a string
literal** — the pragmatic reading that reconciles the spec's "bare string is a string literal"
with its fn/let/match bodies referencing bound names as bare strings.

**Implemented ops:** get, get-in, set, set-in; + - * / %; == != < > <= >=; and or not;
if, cond, do, let, letrec, fn, call, match (over capitalized DU constructors); array, count,
array-get, array-push, array-slice; record (added — see below), record-get, record-set,
record-del, record-keys, record-vals, record-merge; floor, ceil, round, abs, min, max, pow,
sqrt, int->float, float->int; to-string, str-concat; untyped/as (identity — no checker).

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
- `../../../tests/tf_substrate_test.gd` — the suite (evaluator conformance + 7 contract cases).
