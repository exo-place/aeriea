# TF substrate — plain struct + stateless function transformation model

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

**Behaviour is separate and stateless.** A transformation is a plain function
`func(root, part, tr, ctx) -> void` that reads the tree and writes next field values. Parts
carry no transformation code; a transition record just names its `kind`, and a plain dispatch
table (`transforms: Dictionary` of kind → Callable) maps names to functions. Data and
computation are separate.

**Progress is accumulated plain state.** A part's active transitions live in an ordinary field
`fields["transitions"]` — a plain Array of plain dicts. Appending starts one; list position is
recency (last = most recent). Each entry holds its own `prog`, so parallel entries advance
independently and out of step. Progress is stepped by the transformation, never computed from a
clock or tick count.

**Execution is one deterministic total order** (`tf_engine.gd`, `TFEngine.tick`): parts in tree
pre-order, and within a part its transition list in order. Fields mutate in place — no snapshot,
no previous-state buffer. A cross-part read sees this-tick values from sources earlier in the
order and last-tick values from sources later; the one-tick lag is emergent from the order, not
a stored buffer. There is no priority field and no authoring index.

**Determinism is seed + action log.** An action (`TFEngine.apply_action`) is a plain-data record
that mutates the tree / starts-stops transitions / writes fields. `TFEngine.run_log` folds a log
of actions and `tick` markers over a freshly-built tree; the same seed + same log reproduce
identical final state with no stored world snapshot. Any randomness (`tf_rng.gd`, `TFRng`) is a
pure function of (seed + a deterministic coordinate + a per-transition draw counter) — never
wall-clock, never a native/global RNG stream.

**Pause and stochastic are not primitives** — they are how a transformation is written. Pause =
the function reads a plain condition field and declines to advance while it holds (the condition
is written by an action or another transformation). Probabilistic = a seeded draw that early
-returns to a no-op unless it passes.

**Cross-part reference is by field + structure** (`tf_tree.gd`, `TFTree`). A transformation finds
another part by matching on its own fields (`find_all`, `find_first`, `field_is`) and by
relational traversal (`nearest_ancestor`, `nearest_ancestor_excluding`, `topmost_in_chain`,
`has_ancestor`) — never a pointer, id, or brittle index path. Principle: **identity lives in
fields** (kind / form — what a part is, true wherever attached); **location lives in structure**
(attachment is the single source of truth for where a part is). There is no redundant
location/region field.

## Files

- `tf_part.gd` — `TFPart`: the plain struct + tree ops + deep clone/equals.
- `tf_tree.gd` — `TFTree`: pre-order flatten + field/relational queries.
- `tf_rng.gd`  — `TFRng`: seeded, coordinate-keyed deterministic draws.
- `tf_engine.gd` — `TFEngine`: the tick, actions, and the replay driver.
- `../../../tests/tf_substrate_test.gd` — the suite (7 contract cases).
