# Body / Transformation Substrate

## A. Purpose, scope, and status

The body/transformation **substrate** for aeriea: the thin floor over which authors
build every body-shaped and transformation-shaped behavior as ordinary data and
ordinary expressions.

**Status: EXPERIMENTAL — built, not user-certified, Not green.** A working substrate
now exists in `scripts/sim/tf/` (`tf_part.gd`, `tf_tree.gd`, `tf_rng.gd`,
`tf_marinada.gd`, `tf_library.gd`, `tf_engine.gd`) and is wired into the canonical
runner as `tf_substrate_test` (8 cases, evaluator conformance + 7 contract cases). No
game surface depends on it yet and the user has not verified it. Do not treat it as
settled; see `scripts/sim/tf/README.md` for the code-level account this doc summarizes.

The model that was actually built is much plainer than the model this doc used to
describe. The earlier design explored a radically-generic "blesses nothing" substrate
(uninterpreted metadata, a same-property non-commutative fold, per-run state living
inside one author-keyed value advanced by one map-over-the-list expression, an author
priority override, and — in the reasoning artifacts — fold-cells / value|expr unions /
per-quantity previous-tick buffers). **That model was torn down during design.** The
built substrate is a plain-struct tree plus stateless marinada transformations. The
retired concepts are catalogued in Section E so they do not read as the live design.

Every claim below carries one of three confidence tags:

- **[CONFIRMED]** — an invariant the **user explicitly decided** this session. These
  are the load-bearing commitments; do not relitigate them without the user.
- **[AS-BUILT]** — an implementer-chosen specific of the current build. It works and is
  tested, but it is **not** user-certified — a later design pass may revise it.
- **[OPEN]** — genuinely unresolved / deliberately left unfilled.

Nothing here is "green"; green is the user's to grant.

---

## B. [CONFIRMED] — invariants the user decided

- **[CONFIRMED] Structure is a tree.** Each part has exactly one parent. Cross-part
  effects (hormones, signals, regional fields) are expressed by predicate-guided
  traversal over fields + structure — never graph edges. There is no structural second
  parent; every "graph-like" relation is author data layered over the tree.
- **[CONFIRMED] A part is a plain struct (DATA); a transformation is a separate,
  stateless function (COMPUTATION).** A part is a bag of named fields (each a plain
  value — number / string / bool / list / dict), an ordered list of children, and a
  parent link. A field holds a value read directly; there is no value|expr union, no
  cell, no accessor, no discriminator, no blessed id. A body is the root part plus its
  subtree. Parts carry no behavior; the transformation that changes them is authored
  elsewhere. Data and computation are separate.
- **[CONFIRMED] Transformations are authored marinada DATA referencing shared
  definitions by NAME.** A transformation is a marinada expression (data), authored in a
  marinada module and looked up by name. It is not engine code. A transition record
  names its definition; that content-reference to a shared authored definition is the
  only blessed "reference to a shared something" — it is NOT a runtime id/registry for
  simulation entities (the tree stays id-free).
- **[CONFIRMED] Identity lives in FIELDS; location lives in STRUCTURE.** What a part IS
  (kind / form) is a field, true wherever the part is attached; where a part IS is the
  attachment structure, the single source of truth. There is **no region / location
  field** and no id. A part detached and re-attached carries its identity unchanged.
  Cross-part reference is by field predicate ("a breast" = `kind == "breast"`) plus
  relational traversal (nearest matching ancestor, topmost-in-chain, has-ancestor) —
  never an index path, never an id.
- **[CONFIRMED] Cycle / feedback resolution is evaluation-order ONLY — no stored
  previous value.** A deterministic evaluation order runs over in-place state; a
  backward / lateral reference reads whatever value is currently in place, so any
  one-tick lag **emerges from the order**. There is NO previous-state buffer of any
  kind — no per-quantity recurrence buffer, no whole-world snapshot. The author controls
  immediate-vs-lagged purely by where things sit in the order.
- **[CONFIRMED] A tick evaluates ALL transitions; pause and probability are authored
  early-returns, not primitives.** There is no scheduler selecting a subset to advance.
  Pause is an authored transformation that returns the current value unchanged when its
  condition holds. Probabilistic transformation is an authored transformation that
  performs a seeded draw and returns a no-op unless it passes. Both are ordinary
  expression shapes, not substrate mechanisms.
- **[CONFIRMED] Determinism is `seed + action log`.** All state is derivable from the
  seed and the action log; replay reproduces identical final state with no stored world
  snapshot. Any randomness is a pure function of the seed and deterministic state — never
  a clock, never a native/global RNG stream.
- **[CONFIRMED] Two concurrent out-of-step runs of the same transformation on the same
  target must be expressible.** (Satisfied as-built by parallel entries in the
  transition list, each carrying its own progress — see Section C.)

### Explicitly rejected — do not reintroduce

- **[CONFIRMED]** Control unit / control variable / direction / driver-for-control.
- **[CONFIRMED]** "Progress values" / "instances" / "runs" as blessed, state-bearing
  substrate entities. (Progress is ordinary field state; a "run" is just a list entry.)
- **[CONFIRMED]** Fused / mega timelines for coupling. Coupling is an external system
  writing metadata onto both involved entities; each body reads only its own; the
  substrate never represents a cross-body edge.
- **[CONFIRMED]** Blessed identity / uid / store / cells / resolver as substrate things.
  A `uid` (if an author wants one) is ordinary field data, nothing more.
- **[CONFIRMED]** A runtime-registry "library" of simulation entities. (The authored
  marinada module resolved into a `kind → definition` table is CONTENT, not an
  entity registry — see the naming caution in Section C.)

---

## C. [AS-BUILT] — implementer-chosen specifics of the current build

These are how the confirmed invariants are realized in `scripts/sim/tf/`. They are
tested and working but **not** user-certified; a later pass may change any of them.

- **[AS-BUILT] The transition list.** A part's active transitions live in an ordinary
  field `fields["transitions"]` — a plain Array of plain dicts. Appending starts one;
  list POSITION is recency (last = most recent). Each entry carries its own `prog`, so
  parallel entries advance independently and out of step. This is how the confirmed
  "two out-of-step runs" requirement is met, with no blessed "run" noun.
- **[AS-BUILT] The eval-order tuple and total order.** `TFEngine.tick` walks parts in
  tree PRE-ORDER, and within a part its transition list in order. Each definition is a
  marinada closure called with the fixed argument tuple
  `(part, root, tr, seed, coord, idx, ntrans)` — where `idx`/`ntrans` expose recency
  (`idx == ntrans-1` is "most recent"). There is no priority field and no separate
  authoring index: pre-order × list-order IS the whole order. The one-tick lag for
  cross-part reads is emergent from this order (verified both directions in the suite).
- **[AS-BUILT] The pure-return protocol.** Marinada `set`/`set-in` are pure (return new
  records), but the tick mutates in place. So a transformation is a pure expression that
  RETURNS `{ "transition": <new transition record>, "fields": <field-name -> value> }`,
  and the ENGINE performs the write: it replaces the transition-list entry and writes
  each field into `part.fields` in place. Marinada stays pure; the engine owns mutation
  and order. (There is no same-property fold and no priority override — within a tick
  the last writer in eval order wins; see Section E.)
- **[AS-BUILT] The seeded-draw coordinate scheme.** `tf_rng.gd` is a seeded,
  coordinate-keyed splitmix64-style draw (`mix2`, `draw-int`, `draw-unit`, `chance`).
  The engine binds `seed` and a base `coord = mix2(part-index, transition-index)` into
  the definition. A transformation drawing more than once mixes in a per-transition draw
  counter it carries in its own transition record (`_draws`), so the coordinate is a
  pure function of deterministic state. Same seed + same log ⇒ identical draws.
- **[AS-BUILT] The weak-parent representation.** `TFPart._parent` is a `WeakRef`;
  `children` holds the owning strong refs. Weak-on-purpose so a dropped subtree frees
  (a strong parent link would form a RefCounted cycle). Read via `parent()`, never touch
  `_parent`.
- **[AS-BUILT] The `record` literal extension (flat form).** Marinada's spec lists
  `record-set` / `record-merge` but no literal record constructor. The substrate adds
  one as a documented gap-filler, in a FLAT form: `["record", k1, v1, k2, v2, ...]`.
  This is a local extension pending an upstream marinada decision (see Section D).
- **[AS-BUILT] `__module_env` anchor.** `TFLibrary.build()` returns the `kind → closure`
  table plus a reserved non-kind key `__module_env` holding the module frame alive
  (the def closures capture it weakly, sealed to avoid a refcount self-cycle). The
  engine only ever indexes the table by a transition `kind`, so the entry is inert to
  consumers. A lifetime detail, not a semantic one.
- **[AS-BUILT] Tree-binding by host ops over opaque handles.** Parts flow through the
  evaluator as opaque host values (TFPart objects evaluating to themselves); the tree is
  never reified into records. Navigation is a family of host ops wrapping `tf_tree.gd`
  (`part-field`, `part-parent`, `part-children`, `find-first`, `find-all`,
  `nearest-ancestor`, `nearest-ancestor-excluding`, `topmost-in-chain`, `has-ancestor`),
  and predicates are ordinary marinada lambdas. This keeps the confirmed
  identity-in-fields / location-in-structure model verbatim while keeping the core tiny.
- **[AS-BUILT] Marinada conformance — implemented vs skipped** (authority:
  `~/git/rhizone/dusklight/docs/marinada.md`). Implemented: get/get-in/set/set-in;
  arithmetic/comparison/boolean; if/cond/do/let/letrec/fn/call/match; array + record ops;
  math; string ops; the module resolver; plus the added `record` literal, the seeded-draw
  family, and the tree-nav family. Deliberately NOT implemented (not needed by a pure
  value transformation): reactive signals, algebraic effects, capabilities, the gradual
  type checker / linear types, optimizer/JIT/TCO, result-propagation and misc ops. A
  bare string in argument position is a variable reference if bound, else a string
  literal (the pragmatic reading of the spec).
- **[AS-BUILT] Naming caution — "library".** The earlier design rejected the "library"
  framing (Section B) because it meant a runtime registry of simulation entities. The
  built `TFLibrary` / `kind → closure` table is NOT that: it is an authored marinada
  module resolved into a lookup of authored DEFINITIONS. The rejected concept and the
  built file share a word, not a meaning; the tree remains id- and registry-free.

---

## D. [OPEN] — unresolved threads

- **[OPEN] Seeded draws have no stable identity across restructuring.** A stochastic
  stream is keyed off the tree position (`mix2(part-index, transition-index)` plus the
  per-transition `_draws` counter). Restructuring the tree — reordering children,
  grafting, detaching — changes those coordinates and therefore reshuffles the draws.
  Replay from the same seed + same log is exact (positions are reproduced), so this does
  NOT break determinism. But it means "this part's random stream" is not stable under
  restructuring. If restructure-stable randomness is ever wanted (e.g. a growth that must
  keep drawing the same series after the body is rearranged around it), that is a real
  design question needing an author-supplied stable coordinate — deferred, not decided.
- **[OPEN] The `record`-constructor upstream form (flat vs paired).** The local
  extension uses a flat `["record", k, v, k, v, ...]`. Whether marinada should adopt a
  flat or a paired (`[[k, v], ...]`) record literal upstream is the user's
  marinada-language design question, parked. The flat local extension works meanwhile;
  if upstream lands a different shape, the substrate follows it.
- **[OPEN — outside the substrate floor] Time-progression / tick-driver integration.**
  What advances ticks — how game-time or real-time maps onto ticks — is NOT part of the
  TF substrate. The substrate only assumes "a tick happens and runs all transitions."
  Wiring TF to whatever drives time belongs to integrating TF with the rest of the game
  and needs its own design pass. Tracked as a distinct open thread in `TODO.md`.

---

## E. SUPERSEDED — the torn-down model (kept only so it does not read as live)

The design earlier explored a much heavier model. It was abandoned in favor of the plain
struct + marinada model above. None of the following is the live design; each line points
at what replaced it.

- **Same-property non-commutative FOLD + authoring-order / action-log-order tie-break +
  author priority override** — SUPERSEDED. There is no same-property fold and no priority
  override. Each transformation writes its own field(s); within a tick, evaluation order
  (pre-order × list-order) fully determines the outcome and the last writer wins. Order,
  not a fold, is the whole mechanism.
- **Per-run state living inside ONE author-keyed value, advanced by one
  map-over-the-list expression** (the `synthesis.md` "pure fold" base) — SUPERSEDED.
  Concurrency is many independent entries in the `fields["transitions"]` list, each with
  its own `prog`, each advanced by its own definition call. No single fold expression maps
  over a run-list.
- **Fold-cells / `value|expr` (or `value|expr|fold-cell`) unions / accessors /
  discriminators** (the removed `prototypes/tf-substrate/` cell/fold/`Expr`/`mget`
  kernel) — SUPERSEDED / removed. A field holds a plain value read directly; there is no
  cell and no union.
- **Per-quantity previous-tick recurrence buffer** (the `synthesis.md` concession
  reconciling a "previous-tick need" with the buffer-free claim) — SUPERSEDED / RETIRED.
  The confirmed invariant is no stored previous value of any kind; the one-tick lag
  emerges only from reading in-place state under the chosen order.
- **"Recompute vs accumulate" as a substrate discipline / attachment-position metadata
  as a blessed ordering key** — SUPERSEDED. Progress is accumulated ordinary field state;
  ordering is the intrinsic pre-order × list-order, not a metadata field the substrate
  interprets.
- **Radical "blesses literally nothing / no `kind`, no metadata is ever read" framing** —
  PARTIALLY SUPERSEDED. Parts do carry arbitrary uninterpreted fields, but the built
  substrate does read two conventional keys as load-bearing: a transition's `kind` (names
  its authored definition) and the `fields["transitions"]` list (holds active
  transitions). These are as-built conventions (Section C), an honest narrowing of the
  "blesses nothing" aspiration.

The design-it-twice **synthesis** at
`docs/artifacts/substrate-reasoning/semantics-pass/synthesis.md` (pure-fold base, run-list
in one value, author discriminator) is **SUPERSEDED** by the plain model in this doc. That
artifact and the other files under `docs/artifacts/substrate-reasoning/` are kept untouched
as historical reasoning; they are not the live design.

---

## F. Relationship to `dynamical-transformation.md`

`docs/decisions/dynamical-transformation.md` is an older, separate design for
transformation-as-driven-transitions (topology vs magnitude, `{from, to, progress}`
transitions, state-rides-identity). Its transition/progress framing is now largely
subsumed by this plain substrate (progress is ordinary accumulated field state; a
transition is a plain list entry advanced by an authored definition). It has NOT been
reconciled against the as-built substrate here and may still hold ideas (e.g. the
discrete-graft-plus-continuous-magnitude account of structural growth) worth folding in.
Flagged as needing its own follow-up pass; not rewritten as part of this sync.
