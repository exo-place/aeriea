# Operational Semantics — SYNTHESIS (semantics-pass bake-off)

> **Design only. User-gated.** No engine code, no `docs/FEATURES.md` change, no edit
> to the decision doc, no commit. This is the synthesized operational-semantics model
> for the body/transformation substrate, produced from candidates 1–4 and three
> adversarial judges (noun-gate, hard-case, determinism). It honors the [CONFIRMED]
> invariants of `docs/decisions/body-transformation-substrate.md` and does not
> relitigate them.
>
> **Base:** Candidate 3 (pure fold; per-run progress = a LIST of run-state records in
> one author-keyed property, advanced by ONE expression that maps over the list).
> **Grafts:** C4's author discriminator field for stable run re-identification; C2's
> honesty that reversal/pre-image is an explicit author-deposited value.
> **Rejected:** C1 key-name plurality (smuggles key-parsing + grouping + value-order;
> co-bound instances tie on the full eval tuple → undefined fold); C4
> canonical-order-over-values (breaks opacity); C4 write-by-selection push
> (data-dependent contributor set); native-hashmap iteration (replay-fatal).

---

## 0. The model in one paragraph

The world is a **tree of parts**; each part is a **map of opaque author metadata**;
some metadata entries are **expressions** (pure authored functions). A **tick** derives
the full set of expressions from the tree, sorts them into **one global total order**,
and folds them left over the in-place metadata — each expression reads whatever values
are currently in place and overwrites exactly **its own one (part, key)**. The
substrate interprets **no value**, blesses **no run / progress / uid / driver / store**,
and never compares two arbitrary values. Plurality (concurrent runs) lives **inside one
value** — a list of records advanced by one map-over-the-list expression — never as
multiple co-bound expressions. Every visible/shared property is authored as a **pure
recompute** `base + f(list-of-run-states)`, never as an accumulator baked into the cell;
that single discipline is what makes concurrent absolute-value runs reconcile, makes
run-removal reverse for free, and makes post-consumption reversal recoverable. Pause and
probabilistic transformation are authored **early-returns**, not mechanisms.

---

## A. The operational semantics

### A.1 Metadata value model (opaque)

A metadata value is one of:

- a **scalar**: number, boolean, or symbol/string — the substrate never interprets the
  symbol (`"estrogen"`, `"carrier"`, `"horns"` are all opaque);
- a finite **record** (map symbol→value) or **list** of values, nested to finite depth;
- an **expression** (§A.4): a pure authored function. Expressions are *just metadata* —
  a part's behavior is data on the part, so **the tree IS the registry**; there is no
  separate store.

**No blessed value types.** No part-handle, no id, no reference, no closure-over-a-part.
A value never *points at* another part; the only way to reach another part is `select`
over content (§A.3). This is what keeps selection topology-independent — you cannot
store a path.

**What the substrate MAY do to a value:** structural equality; container
construction/projection/iteration where order is **positional (lists) or
authoring/insertion (records)**; arithmetic/boolean/string ops only when an author
expression invokes them explicitly.

**What the substrate may NOT do to a value:** impose a canonical total order over values
(no value-comparator; rejected from C4 — recursing into a value to order it *is*
interpreting structure, which the opacity clause forbids); parse key-name lexical
structure (no `#`-delimiter destructuring; rejected from C1); iterate a record/map by
native hash order (replay-fatal); attach meaning to any key or symbol. There is **no
property/metadata distinction** — one namespace `key → value`; a key is "a property"
only colloquially because some expression rewrites it.

### A.2 What a predicate may read (read-only)

A predicate (argument to `select`, or a guard inside an expression) is a pure,
side-effect-free boolean. Of each candidate part it may read:

1. that part's **own current in-place metadata** (any key);
2. its **intrinsic 1-hop structure**: immediate parent's metadata and direct children's
   metadata (plan-robust);
3. **predicate-guided traversal** — `ascend(Q)` / `descend(Q)` / "nearest ancestor
   matching Q", i.e. iterated 1-hop over already-blessed structure, **never a fixed path
   index**;
4. the **host** part's own metadata (lexical closure of the calling expression);
5. the **seed** (for seeded predicates).

A predicate may **not** read: evaluation order, any stored "previous value", any
provenance the author did not write, any absolute/relative route, wall-clock, native
RNG. "Time", "most recent", "provenance", "order" are **author values the author
stamped**, read like any other value. This is what makes selection topology-independent.

### A.3 `select` — scope, return, ordering, determinism

```
select(pred, root := body_root(host)) -> Seq<Part>
```

- **Scope.** A traversal over the subtree rooted at `root`; default `root` is the host's
  **body root** (found by walking `parent` to the top — recomputed each call, never a
  stored route). One body = one tree; cross-body reach does not exist (coupling deposits
  metadata on each body and each body's `select` ranges over its own tree only —
  [CONFIRMED] no edge, no fusion).
- **Return type.** An **ordered sequence of parts** (possibly empty), each exposing its
  current in-place metadata. Always a sequence (never a set) so determinism has a defined
  order and "one-of-several" has first/last/nth. Handles are ephemeral (valid this tick
  only), never stored, never a uid.
- **Ordering rule.** Ascending **intrinsic structural order** = the part's index in the
  deterministic pre-order DFS of `root` (§A.7). The *predicate* matches on content
  (topology-independent); the *order of results* is the tree's own shape — **never**
  metadata-value order, never a path, never creation timestamp (except the disclosed
  last-resort sibling tie-break, §A.7).
- **Determinism.** Total and content-only: result depends solely on predicate + current
  in-place metadata + tree shape. Two structurally identical bodies with identical
  metadata yield identical sequences regardless of how they were built. Stochastic choice
  is layered *on top* by the author: `select(p).nth(seeded_draw(seed, <coord>, len))` —
  the draw is an ordinary seeded expression, not a property of `select`.

"One of several" = `select(pred).first` / `.last` / `.nth(seeded_draw(...))` /
`argmax(criterion)`. "Track this individual durably" = `select(p => p.meta.mark == m)`
where `mark` is author metadata the expression stamped (a hand-rolled mark-by-convention,
honestly a residual, §C).

### A.4 Expression — inputs, write, timing, order, fold

**Bound target.** Every expression is bound to exactly one `(host part, key)` — the one
value it recomputes. Its identity is **positional and derived** (`(host preorder index,
key, authoring index)`), never stored as an id.

**Inputs** (all read at call time, all current in-place):

- `current` — the value currently in place at `(host, key)`. **One input among many**
  ([CONFIRMED]), special only in that it seeds the fold accumulator. There is **no
  previous-tick buffer** — `current` is simply whatever is in the cell now.
- `host.meta` — the host's other current metadata.
- 1-hop structure of host: `parent.meta`, `[child.meta]`; predicate-guided traversal.
- results of any `select(...)` the expression calls (other parts' current in-place
  metadata).
- `seed`.

**What it may write.** Exactly **its own bound (host, key)** — pull, not push. It may
*read* anywhere via `select`, but it **writes only its own cell**. Cross-part effects are
achieved by the *target* running an expression that reads the source (a gland does not
write the skin; the skin reads the gland). This single-writer rule is what makes the fold
well-defined: every key's value is the fold of exactly the expressions statically bound
to it — a statically knowable writer set. (C4's write-by-selection push is **rejected**:
it makes a cell's contributor set depend on same-tick mutations, destroying the
static-writer-set guarantee even though raw determinism survives.)

**When it runs.** Every tick, every expression runs **exactly once** ("full stop", no
scheduler — [CONFIRMED]). Returning `current` unchanged is a no-op: this is how **pause**
and **failed probabilistic draws** are expressed (authored early-return), never a
substrate mechanism.

**The GLOBAL total evaluation order.** At tick start, walk the tree in pre-order DFS and
collect every expression; `E` is produced already in total order by the traversal. Each
element sorts by the lexicographic tuple:

```
( host_preorder_index , priority , authoring_index )
```

1. **`host_preorder_index`** — the host part's position in the body's pre-order DFS
   (§A.7). Derived from structure every tick; never stored; not an id. Earlier-in-tree
   evaluates first.
2. **`priority`** — an optional author-metadata integer on the expression (the blessed
   "author priority override"); default a single neutral value; lower sorts earlier. The
   author's **edit-stable** lever for immediate-vs-lagged coupling *within a part*.
3. **`authoring_index`** — **GLOBAL** monotonic registration order over distinct static
   expressions (NOT per-key, NOT per-part — pinned explicitly; per-key-local would
   reintroduce ties for two same-priority expressions on one part writing different
   keys). This alone is already a strict total order over static expressions.

**Sibling tie-break for the structural component** → action-log attachment order (the
replay-blessed last resort, §A.7). This tuple is **total** and **noun-free**: no element
is a blessed sequence/id; `host_preorder_index` is a reading of the tree,
`priority`/`authoring_index` are author/registration data.

> **Why this is total here but was NOT in C1:** plurality lives inside one value advanced
> by ONE expression (§A.6), so there is never instance-multiplication. C1 bound one
> expression to a key-pattern that instantiated N co-bound writers to one cell; all N
> shared host-index, priority, AND authoring-index → tied on the full tuple → the
> non-commutative fold's result was undefined by the stated order. The list-of-records
> model structurally cannot produce that tie.

**The same-property fold (non-commutative).** Multiple expressions may target the same
`(part, key)`; they occupy a contiguous run of `E`, already sorted by `(priority,
authoring_index)`. The key's new value is the **left fold**:

```
acc := current in-place value of (part, key)        # NOT a snapshot — whatever is in place
for e in writers(part, key) in (priority, authoring_index) order:
    acc := e(current := acc, host.meta, 1-hop, select(...), seed)
    write acc in place at (part, key) immediately   # next writer sees it
value of (part, key) := acc
```

Non-commutative because each writer's `current` is the previous writer's output;
reordering changes the result. Default order = authoring order; `priority` overrides. The
fold is not a separate mechanism — it is the in-place eval order applied to co-bound
expressions. Distinct keys never fold.

**How in-place mutation yields the one-tick lag.** `E` is folded in one pass in total
order. When `e_k` (writing `A.P`) reads `B.Q` via `select`:

- if `B.Q`'s writers sort **before** `e_k` → they already ran this tick → `e_k` reads
  `B.Q`'s **this-tick** value → **immediate** coupling;
- if they sort **after** → not yet run → `e_k` reads the value **left in place from last
  tick** → **one-tick lag**.

A mutual cycle `A.P ↔ B.Q`: exactly one is earlier; the later reads fresh, the earlier
reads stale. **Exactly one lag edge, located purely by order, no buffer, no snapshot**
([CONFIRMED]). "Last tick's value" is simply the value still sitting in the cell because
nothing overwrote it yet this tick.

### A.5 Order-freeze disclosure (venial, not a value-snapshot)

The *shape and order* of `E` is fixed for the duration of one tick (so the fold has a
stable order); structural writes (adding/removing parts) take effect on the **next**
tick's derivation, not mid-tick. This freezes **order, not values** — values stay
mutated in place with no buffer, replay is still `seed + log` with `E` re-derived each
tick. The certified ban is on previous-*value* buffers / whole-world *value* snapshots;
this is an evaluation discipline, not a noun. (All three judges concur: venial /
legitimate ordering. Stated as "structural writes take effect next tick" without
materializing `E`.)

### A.6 Where per-run progress lives — the list-of-records model + recompute discipline

**Per-run progress lives in ONE author-keyed property holding a LIST of records.** A
property has one value (the fold's result), so two concurrent runs cannot both *be* the
value of `tail_length` — they would fuse. The substrate-honest home is a single
list-valued metadata key, **one record per run**:

```
target.meta.morph = [
  { disc: "horns", started: 11, p: 0.30, rate: 0.05, paused: false },
  { disc: "horns", started: 27, p: 0.72, rate: 0.05, paused: false },
]
```

- **Per-run progress** = the `p` field of one list record. The "run" is the author's
  *reading* of one record's `p`-trajectory across ticks — never a stored entity.
- **`disc`** = an author **discriminator field inside each record** (grafted from C4 to
  fix C3's hand-rolled-identity weakness): a stable re-identification key so "the same
  run" is addressable across ticks even though the list is rewritten each tick. It is an
  **inert field the substrate never reads** — not a uid. Its origin is constrained
  (§A.8).
- **ONE expression writes `morph`**; its body **maps over the list element-wise**,
  advancing each record's `p` independently (and early-returning per record on its own
  `paused`). Two runs of the same transformation = two records sharing the advance-rule
  but carrying different `p`. **Unbounded runs = append a record** (`old ++ [new]`); a
  third mid-flight run needs **no slot table**, no cap, no minter beyond §A.8.
- Iteration is **positional** (list order) — no value-comparator anywhere. (A
  discriminated *map* keyed by `disc` is acceptable *only* if iterated by
  insertion/authoring order — at which point it is an ordered list-of-pairs, i.e. this
  model. Native-hashmap iteration is forbidden, replay-fatal.)

**THE RECOMPUTE DISCIPLINE (load-bearing, central).** A visible/shared property must be
authored as a **PURE RECOMPUTE** from `base + f(list-of-run-states)`, **never** as an
accumulator baked into the cell:

```
target.meta.tail_length := base_len + f(morph)      # f reads the WHOLE list
```

where `f` is the author's chosen composition over all live runs (`max`, `sum`, `last`,
`argmax-by-started`, …) and `base_len` is per-body metadata captured at apply-time. This
single discipline is what makes:

- **(a) two absolute-value concurrent runs reconcile correctly** — `f` has simultaneous
  access to every run's `(started, p)`, so e.g. `f = argmax(morph, .started).p` renders
  the latest run's absolute value without erasing the other's state (the accumulator/
  last-write-wins style loses a run);
- **(b) run-removal reverse for free** — drop a record, recompute, the value falls
  correctly; the contribution was never baked in;
- **(c) case-6 reversal-after-causer-consumed work** — see §A.8 / case 6.

The accumulator style (`current + rate` baked into the cell, C2 deltas, C4 worked
example) is the **trap** that makes (a)/(b)/(c) impossible. Recompute-from-base is the
discipline that makes them native.

### A.7 Intrinsic structural order + tie-breaks (guaranteed total)

- **Order = pre-order DFS**: visit a part, then recurse into children in sibling order.
- **Sibling order = attachment position** (the intrinsic structural ordinal at which a
  child was attached to its parent — structural data, not metadata, not an author uid).
- **Tie-break (disclosed):** if two siblings share an attachment position (or the plan
  gives none), break by **action-log attach order** — the replay-blessed last resort. No
  noun (the log is `replay = seed + action log`), fully reconstructible, but it means
  structural order is **partly a function of build history, not pure geometry**: two
  geometrically identical bodies built in different log orders can evaluate differently.
  Mitigation in-design: `priority` is the **edit-stable** lever — an author who wants
  stable lag uses priority, not tree placement. (If the user wants pure geometric
  determinism, the body-plan layer must guarantee unique attachment positions — a
  constraint pushed outward onto authors.)
- **Guaranteed-total rule:** `(host_preorder_index [DFS + attachment + log-order
  fallback], priority, authoring_index[GLOBAL])` is a strict total order over all
  expressions — every component resolves, the final `authoring_index` (global) never
  ties two distinct static expressions.

### A.8 Pause, probabilistic TF, recency, discriminator origin, pre-image

- **Pause** = authored early-return: the per-record advance returns the record unchanged
  when the paused-predicate holds. No progress advances; no mechanism.
- **Probabilistic TF** = a `seeded_draw(seed, <deterministic coord>)` inside the
  expression that early-returns to a no-op unless it passes (e.g. 10%/tick). Deterministic
  via the seed.
- **Pause-most-recent recency = author-stamped ACTION-INDEX metadata**, not tick-time.
  Tick-time ties on same-tick starts → `argmax` over runs ties → the substrate breaks it
  by positional order, deterministic-but-arbitrary (not the run the player means).
  Action-index (monotonic per action in the log, never ties) is the discipline; with it,
  "pause most recent" = `argmax(filter(unpaused, morph), .started)` then set that
  record's `paused`. (Filtering `unpaused` also handles "most-recent already paused".)
- **Discriminator origin — only from the seeded timeline.** Every `disc` originates one
  of exactly two ways: (1) a **literal value carried by an action** in the log
  (player/author choice); or (2) `seeded_draw(seed, <deterministic coordinate>)` where
  the coordinate is itself deterministic — `action_index` for action-spawned runs, or
  `(host_preorder_index, authoring_index, entry-order)` for a run spawned mid-tick by a
  transition. **Forbidden (replay-fatal):** wall-clock, native RNG outside the seed,
  pointer/hashmap address, or any tick-local counter not derived from the seed. This keeps
  replay = seed + action log even for mid-tick sub-run spawns.
- **Case-6 pre-image = ordinary body metadata deposited at apply-time.** Reversal needs
  the pre-image (`*_base`, optionally per-run-discriminated) written onto the body **at
  apply-time by the external action** — the certified "external system writes onto both
  entities" pattern — **NOT** a substrate snapshot/buffer. The substrate structurally
  cannot recover a pre-image; the floor forbids it. This is **required author
  discipline**, stated honestly: capture `base` as per-body metadata so a non-standard /
  already-transformed body reverses to *its own* pre-image, and author the visible
  property as `base + f(morph)` so dropping the run's record recomputes back to `base`.

---

## B. Hard-case PASS/FAIL table

All six cases, with the author pattern and the per-case noun verdict. Verdict legend:
**PASS** (clean), **PASS-WITH-DISCIPLINE** (clears with a stated author discipline, no
new noun), **CONDITIONAL** (a real surfaced constraint of the floor).

| # | Case | Verdict | Author pattern | Noun introduced |
|---|------|---------|----------------|-----------------|
| 1 | Gradual transformation | **PASS** | one `morph` record `{p, rate}`; one map-over-list advance expression; `tail_length := base + f(morph)`. `p`-trajectory IS the run. | **NONE** |
| 2 | Pause-most-recent | **PASS-WITH-DISCIPLINE** | `started` stamped as **action-index**; `argmax(filter(unpaused, morph), .started)` → set that record's `paused`; advance early-returns paused records. Discipline: action-index recency (not tick-time) + filter-unpaused. | **NONE** |
| 3 | Two out-of-step runs | **PASS** | two `morph` records with independent `p`; advanced element-wise by one expression; absolute reconciliation via `f` reading the whole list (e.g. `argmax(morph,.started).p`) recomputed each tick. Third run = append a record; no slot table. | **NONE** |
| 4 | Cross-part signal (hormone X→Y) | **CONDITIONAL** | Y pulls via `select(produces_H)` / `ascend(Q)`, reads sources' current value, recomputes its own cell. Lag set by structural order. | **NONE** (limitation is structural, not a noun) |
| 5 | One-of-several selection | **PASS** | `select(pred)` → structural-ordered seq → `.first`/`.last`/`.nth(seeded_draw)`/`argmax`. Durable tracking = stamp a `mark`, re-find by predicate over it. | **NONE** |
| 6 | Non-standard / already-transformed + reverse | **PASS-WITH-DISCIPLINE** | Selection is content-predicate + 1-hop → missing/extra/pre-altered parts just change matches; `current` is an input so re-application composes from present state. **Reverse:** pre-image `*_base` deposited as body metadata at apply-time + visible property authored as pure recompute `base + f(morph)`; drop the record → recompute → reverses for free. | **NONE** |

**Case 4 — the honest CONDITIONAL (structural-only immediacy).** Priority orders only
**within a part** — `host_preorder_index` dominates the eval tuple, so **priority can
NEVER reorder two different parts**. If skin `S` must read gland `G`'s **this-tick**
value but `G` sits deeper in DFS than `S` (anatomy fixes this), pre-order visits `S`
before `G`, so `S` reads `G`'s **stale** value. Forced same-tick cross-part immediacy
*against DFS direction* is **NOT generally achievable**: the only lever is **tree
placement** (re-root the gland earlier), which may contradict anatomy. The author gets a
**one-tick lag** instead, controlled by tree placement. The case as ordinarily stated
(lag acceptable) is PASS; the forced-immediate-against-DFS stress is CONDITIONAL. **This
is a real, surfaced constraint of the floor, not a defect to hide.**

> **Correction to Candidate 3's worked example (case 4).** C3 claimed "raise `pigment`'s
> priority so it sorts before `hormone_out`" to flip the lag between skin `S` and gland
> `G`. **This is WRONG:** `pigment` (on S) and `hormone_out` (on G) are *different
> parts*; `priority` is the 2nd tuple element, *after* `host_preorder_index`, so it
> cannot reorder two parts. The lag *is* achievable — but **only by which part is
> structurally earlier**, never by the priority knob C3 cited. The synthesis adopts the
> structural-only truth and discards C3's incorrect knob claim.

**Does the floor HOLD?** Every case clears with **NO new substrate noun** — five clean or
clean-with-discipline, and case 4's residual is a *structural limitation of the tree
floor* (immediacy is DFS-directional), not a forced noun. **The floor HOLDS.** The two
disciplines (action-index recency; pre-image deposit + recompute-not-accumulate) and the
one structural limitation (cross-part immediacy is DFS-directional) are author-facing
costs, not substrate primitives.

---

## C. Residual open items (author-facing limitations / ergonomics — for the user to weigh)

These are **decisions/limitations, not blockers**. None is a substrate noun.

1. **Cross-part immediacy is structural-only (real limitation).** Same-tick cross-part
   coupling can only flow along DFS direction; forcing immediacy against DFS requires
   re-rooting in the tree, which can fight anatomy. The author's only general tool is a
   one-tick lag plus tree placement. *Decision for the user:* accept DFS-directional
   immediacy as the floor's honest ceiling, or invest in a body-plan convention that
   places signal sources structurally-early.

2. **Pre-image deposit is required author discipline for reversal.** Reversing a body
   after the causer is consumed requires the pre-image to have been deposited as ordinary
   body metadata **at apply-time** — the substrate cannot recover it (the floor forbids
   snapshots/buffers). *Decision for the user:* accept this as standard apply-time
   discipline ("external system writes onto both entities", already certified), knowing
   that an author who forgets to deposit `base` gets freeze, not rewind.

3. **Recompute-not-accumulate is an authoring burden.** Visible/shared properties must be
   authored as `base + f(list-of-runs)`, never as `current + delta` accumulators. This is
   what buys absolute-value reconciliation, free run-removal, and free reversal — but it
   is a discipline an author must hold, and the accumulator style (which "just works" for
   a single additive run) is a seductive trap that silently breaks concurrency and
   reversal. *Decision for the user:* whether to surface this as a strong authoring
   convention / lint, or document-and-trust.

4. **`broadcast`-sugar ergonomics (pull-only cost).** Single-writer / pull-only means a
   genuinely push-shaped intent ("this event stamps 50 parts at once") is re-expressed as
   50 parts each pulling — correct and deterministic, but more verbose, and it forces a
   pull mental model on authors who think "apply effect to region." *Decision for the
   user:* whether to provide a `broadcast` macro that compiles to per-target pulls
   (sugar over the floor, blesses nothing), or leave authors to write the pulls.

5. **(Minor) Durable identity of an indistinguishable part is a hand-rolled mark.**
   Tracking one of several byte-identical parts across ticks while siblings change requires
   stamping a distinguishing `mark` and re-finding by predicate — functionally a
   uid-by-convention. The substrate blesses nothing, but the pattern every such author
   reaches for is a hand-rolled identity. *Genuinely a convention cost, surfaced honestly.*

6. **(Minor / uncertain) Sibling tie-break leans on action-log creation order.** Where
   attachment positions collide or a plan supplies none, structural order — and thus the
   whole eval order and every lag edge — falls back to build history, so two geometrically
   identical bodies built in different orders can evaluate differently. Replay-deterministic
   (the log is blessed), but a latent surprise under tree edits. *Mitigated* by steering lag
   control to the edit-stable `priority` lever. **Marked uncertain:** whether the user wants
   to require the body-plan layer to guarantee unique attachment positions (pure geometry)
   or accept the log-order fallback is a genuine open call.
