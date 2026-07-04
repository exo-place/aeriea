# Candidate 3 — The Tick as a Pure Fold over an Ordered Expression Set

> Frame (committed): a tick is the deterministic evaluation, in a fixed total
> order, of a **set of authored expressions**, each reading current in-place
> metadata and writing a property's new value, combined by a **non-commutative
> fold**. There is no "run", no "progress" primitive, no "driver" — only metadata
> values and the **trajectory** they trace across ticks. A "run" is an author's
> *reading* of a metadata trajectory, never a stored entity.
>
> Design only. Honors the [CONFIRMED] invariants of
> `docs/decisions/body-transformation-substrate.md`; does not relitigate them.

---

## 0. The one-sentence model

The world is a **tree of parts**, each part is a **map of metadata**, some
metadata entries are **expressions** (a key's value is a pure function), and a
**tick** derives the total set of expressions from the tree, sorts them into one
total order, and folds them left over the in-place metadata — each expression
reading whatever values are currently in place and overwriting one key.

Everything else (runs, progress, pause, provenance, "most recent", stochastic,
concurrency) is an author *reading* or *pattern* over that, never a substrate
noun.

---

## 1. What a metadata value may be; what a predicate may read

**A metadata value** is one of:

- a **scalar**: number, boolean, or symbol/string (the substrate never
  interprets the symbol — `"estrogen"` is opaque);
- a finite **record** (map of symbol → value) or **list** of values, nested to
  finite depth;
- an **expression** (§3): a pure authored function. (Expressions are *just
  metadata* — a part's "behavior" is data on the part, so the tree IS the
  registry; there is no separate store.)

There are **no blessed values**: no part-handle type, no id type, no reference
type. A value never *points at* another part. The only way to reach another part
is `select` over content (§2), so "value" carries no topology.

**A predicate** (the argument to `select`, and any guard inside an expression)
is a pure boolean function that may read, of each candidate part:

1. that part's **current in-place metadata** (any key);
2. the candidate's **intrinsic 1-hop structure**: its immediate parent's
   metadata and its direct children's metadata (plan-robust, blessed);
3. the **host** part's own metadata (lexical closure of the calling expression);
4. the **seed** (for seeded predicates).

A predicate may **not** read: evaluation order, any "previous value", any stored
provenance the author did not write, or any path/route. It sees only
content + 1-hop shape + seed. This is what makes selection
**topology-independent**.

---

## 2. `select` — scope, return, ordering, determinism

```
select(pred, root := body_root(host)) -> Seq<Part>
```

- **Scope.** A traversal over the subtree rooted at `root`. Default `root` is the
  host's **body root**, found by walking `parent` repeatedly to the top (1-hop
  structure applied transitively — not a stored route, recomputed each call).
  An author may pass `root := host` (subtree only) or any part reached by 1-hop
  walking. No absolute paths exist to pass.
- **Return type.** A **sequence of parts** (each exposing its current in-place
  metadata view). Not a set — it is **ordered**.
- **Ordering rule.** Ascending **intrinsic structural order** = the part's index
  in the deterministic pre-order DFS of `root` (§5). This is the SAME order that
  drives evaluation; `select` and the tick share one structural order.
- **Determinism.** Total and content-only: the result depends solely on the
  predicate, the current in-place metadata, and the tree shape — never on the
  call site, the calling expression's position, or wall-clock. Two structurally
  identical bodies with identical metadata yield identical sequences regardless
  of how they were built. Topology-independent because the *predicate* matches on
  content; topology only orders the matches.

"One of several" is then: `select(pred)` then `.first()` / `.last()` /
`.nth(seeded_draw(seed, len))` / `argmin/argmax(criterion)`. No id needed —
"track this individual durably" = `select(p => p.meta.discriminator == d)` where
`discriminator` is author metadata.

---

## 3. An expression — inputs, output, when it runs

An expression is an authored pure function bound to a **(host part, target key)**
by virtue of being the value of that key (or living in the host's authored
expression-list for that key — see fold). Its **identity is positional**:
`(host's pre-order index, target key, authoring-index)` — derived, never stored
as an id.

**Inputs** (all read at call time, all current in-place):

- `current` — the value currently in place at `(host, target key)`. **One input
  among many**, not special-cased except that it seeds the fold accumulator.
- `host.meta` — the host part's other current metadata.
- 1-hop structure of host: `parent.meta`, `[child.meta]`.
- results of any `select(...)` the expression calls (other parts' current
  in-place metadata).
- `seed`.

**Output.** A single value: the new value for `(host, target key)`. Returning
`current` unchanged is a no-op (this is how **pause** and **failed stochastic
draws** are expressed — authored early-return, never a substrate mechanism).

**What it may write.** Exactly one key on its host: the target key. It may *read*
anywhere via `select`, but it **writes only its own (host, key)**. (Cross-part
*effects* are achieved by the *target* part running an expression that reads the
source — pull, not push. A gland does not write the skin; the skin reads the
gland.) This single-writer rule is what makes the fold well-defined: every key's
value is the fold of exactly the expressions whose target is that key.

**When it runs.** Every tick, every expression runs exactly once ("full stop", no
scheduler). Order is §4.

---

## 4. The total evaluation order — the centerpiece

### 4.1 Deriving the expression set `E`

At **tick start**, walk the tree in pre-order DFS (§5) and collect every
expression: for each part visited (in pre-order), for each target key the author
declared on it (in **authoring order** of keys), for each expression targeting
that key (in **authoring/priority order**), emit one element of `E`. `E` is thus
produced already in total order by construction — the order is not a separate
sort pass, it is the **traversal itself**.

> The traversal order (the shape of `E`) is fixed for the duration of the tick.
> This freezes *which expressions run and in what order*, NOT their values —
> values are still mutated in place with no buffer. Structural writes (adding /
> removing parts) therefore take effect on the **next** tick's derivation, not
> mid-tick. This is the only thing held stable across a tick, and it is order,
> not state. (Disclosed as a thin point in §7.)

### 4.2 The total order = lexicographic tuple

Each element `e ∈ E` sorts by the tuple:

```
( host_preorder_index ,  priority ,  authoring_index )
```

1. **`host_preorder_index`** — the host part's position in the body's pre-order
   DFS (§5). *Derived from structure every tick; never stored; not an id.* Parts
   higher/earlier in the tree evaluate first.
2. **`priority`** — an **optional author metadata number** on the expression
   (the blessed "author priority override"). Default = a single neutral value, so
   absent-priority expressions tie and fall to the next key. Lower sorts earlier.
   This is the lever an author pulls to make a coupling **immediate vs lagged**
   (§4.4) without touching tree shape.
3. **`authoring_index`** — the order the author wrote the expressions (blessed
   default fold order). Final, total tie-break; collisions are impossible because
   two distinct authored expressions have distinct authoring positions.

No element of this tuple is a blessed sequence/id noun: `host_preorder_index` is a
*reading* of the tree (like "most recent" is a reading of metadata),
`priority`/`authoring_index` are author-supplied. The order is `structure +
metadata + authoring order` exactly.

### 4.3 The same-property fold (non-commutative)

Multiple expressions may target the same `(part, key)` — e.g. growth +
hormone-suppression both writing `tail_length`. They occupy a **contiguous run of
`E`** (same `host_preorder_index`, same target key), already sorted by
`(priority, authoring_index)`. The key's new value is the **left fold**:

```
acc := current in-place value of (part, key)        # NOT a snapshot — whatever is in place
for e in writers(part, key) in (priority, authoring) order:
    acc := e(current := acc, host.meta, 1-hop, select(...), seed)
    write acc in place at (part, key) immediately    # next writer sees it
value of (part, key) := acc
```

- **Non-commutative**: each writer's `current` is the **previous writer's
  output**, so reordering changes the result. Default order = authoring order;
  `priority` overrides it. This is the blessed fold, made concrete: the fold is
  *function composition threaded through one mutable cell, in sorted order*.
- The accumulator **starts from the in-place value**, which — if no earlier
  writer this tick has touched the key — is **last tick's final value**. That is
  the trajectory carrying forward with no buffer.

### 4.4 How in-place mutation under this order yields the one-tick lag

The whole of `E` is folded in one pass in total order. When `e_k` (writing
`A.P`) calls `select` and reads `B.Q`:

- if `B.Q`'s writers sort **before** `e_k` in `E`, they have **already run this
  tick** → `e_k` reads `B.Q`'s **this-tick** value → **immediate** coupling;
- if they sort **after** `e_k` → they have **not yet run** → `e_k` reads the
  value **left in place from last tick** → **one-tick lag**.

A mutual cycle `A.P ↔ B.Q`: exactly one of the two is earlier in `E`; the later
reads the earlier's fresh value, the earlier reads the later's stale (last-tick)
value. **Exactly one lag edge, located purely by order, no buffer, no snapshot.**
The author chooses immediate-vs-lagged by setting `priority` (or by where the
parts sit in the tree) — nothing else. There is no stored "previous value"; "last
tick's value" is simply "the value still sitting in the cell because nothing has
overwritten it yet this tick".

---

## 5. Intrinsic structural order + tie-breaks

- **Order = pre-order DFS**: visit a part, then recurse into its children in
  **sibling order**.
- **Sibling order = attachment position** (the blessed intrinsic structural
  order — a part is attached at some authored position on its parent, e.g. a slot
  ordinal). Sort siblings ascending by attachment position.
- **Tie-break (thin):** if two siblings share an attachment position (or the body
  plan supplies no position), break ties by **action-log insertion order** — the
  order the parts were created in the replay log. The action log is blessed
  (`replay = seed + action log`), so this is deterministic and adds no noun, but
  it means structural order is **not purely geometric**; it leans on creation
  order as a last resort. Disclosed in §7.

`host_preorder_index` (§4.2) is just each part's ordinal in this traversal.

---

## 6. Where per-run progress lives — two out-of-step concurrent runs, no "run" noun

A property has **one value** (the fold's result). Two independent runs therefore
**cannot both be** "the value of `tail_length`" — they would fold together and
fuse. So the substrate-honest home for concurrent runs is a **single list-valued
metadata key**, one **list element per run**:

```
target.meta.morph = [
  { disc: "horns",  p: 0.30, started: 11, paused: false },
  { disc: "horns",  p: 0.72, started: 27, paused: false },
]
```

- **Per-run progress** = the `p` field of one list element. The "run" is the
  author's reading of one element's `p`-trajectory across ticks. Out-of-step is
  trivially expressible: the two elements simply hold different `p`.
- **One** expression writes `morph`; its fold **maps over the list**, advancing
  each element's `p` independently (and early-returning per element on its own
  `paused`). Two runs of *the same* transformation = two elements that happen to
  share the same authored advance-rule but carry different `p`.
- The **observable body property** is a pure function of the list:
  `tail_length := f(morph)` — author picks how concurrent runs compose
  (`max`, `sum`, `last`, argmax-by-`started`, …). This is a *second* expression
  reading the list.
- **Starting** a run = the `morph` expression appends an element when a trigger
  predicate holds (returns `old ++ [new_element]`). **No "run" noun**: the
  substrate sees a list-valued key and an expression that maps over it.

The discriminator `disc`/`started` is **author metadata** (the blessed
provenance-in-metadata pattern), not a substrate uid. Honest caveat (§7): to
re-identify "the same run" across ticks when the list is rewritten, the author
must keep a stable discriminator — functionally identity, even though the
substrate blesses nothing.

---

## 7. Worked examples

### Case 1 — Gradual transformation (PASS)

```
# On the target part:
meta.morph = [ {disc:"tail", p:0.0, rate:0.05, paused:false} ]

# Expression targeting key `morph` (host = target):
fn morph_advance(current, host, ...):           # current = the list
  return current.map(el =>
    el.paused ? el : { ...el, p: min(1.0, el.p + el.rate) })

# Expression targeting key `tail_length` (host = target):
fn tail_len(current, host, ...):
  return base_len + max_or_0(host.meta.morph.map(el => el.p)) * 0.4
```

Eval order within this part: `morph` then `tail_length` (authoring order on the
key list), so `tail_length` reads **this-tick** `morph` → immediate. Each tick `p`
climbs 0.05; `tail_length` tracks it. Trajectory of `p` IS the run. **No new
noun.**

### Case 3 — Two concurrent out-of-step runs of one transformation (PASS)

```
meta.morph = [
  {disc:"horns", p:0.30, rate:0.05, started:11, paused:false},
  {disc:"horns", p:0.72, rate:0.05, started:27, paused:false},
]
# same morph_advance as Case 1: maps over the list element-wise
```

Tick advances both: `p` → `0.35` and `0.77`. They stay out of step forever (Δ
preserved) because each element folds independently inside the one `morph` fold.
A body property that wants "the furthest-along horn run" reads
`argmax(morph, .p).p`. **Where progress lives: two list elements of `morph` on the
target part. No "run" noun, no uid blessed** (only author `disc`/`started`).

### Case 4 — Cross-part signal (hormone) (PASS, pull-model)

```
# Gland part G:
G.meta.kind = "ovary"
# G writes its own output key:
fn hormone_out(current, host, ...):
  return host.meta.active ? 0.8 : 0.0

# Skin part S, expression targeting key `pigment` (host = S):
fn pigment(current, host, select, ...):
  glands = select(p => p.meta.kind == "ovary")      # whole body, structural order
  dose   = sum(glands.map(g => g.meta.hormone_out))
  return clamp(current + 0.01 * dose)
```

Lag is decided by order: if `G`'s `host_preorder_index` < `S`'s, the skin reads
**this-tick** `hormone_out` (immediate); if the author wants a one-tick endocrine
delay, raise `pigment`'s `priority` so it sorts before `hormone_out`, and the skin
reads **last tick's** dose. No edge, no graph, no push — the skin **pulls** via
content `select`. **No new noun.**

---

## 8. Hard-case battery — PASS/FAIL

| # | Case | Verdict | Mechanism | Forced noun? |
|---|------|---------|-----------|--------------|
| 1 | Gradual transformation | **PASS** | `p` in a `morph` list element; advance-expression; trajectory = run | none |
| 2 | Pause-most-recent | **PASS** | "most recent" = argmax over author `started` ordinal; pause = per-element early-return (`paused`/argmax guard) returning `current` | none (uses author provenance metadata) |
| 3 | Two concurrent out-of-step runs | **PASS** | two list elements of one key, folded element-wise, independent `p` | none (author `disc`, not substrate uid) |
| 4 | Cross-part signal | **PASS** | target pulls via `select(content)`; lag set by `priority`/structure | none |
| 5 | One-of-several | **PASS** | `select(pred)` → structural-ordered seq → first/last/`nth(seeded)`/argmax | none |
| 6 | Non-standard / already-transformed body | **PASS** | selection is content-predicate + 1-hop, topology-independent; missing part → empty `select`, author handles; already-changed part has different metadata, matches or not | none |

All six expressible with **no new substrate noun**. Pre-order index, fold order,
and structural order are all **derived readings** of tree + metadata + authoring
order, not blessed ids/sequences/runs.

---

## 9. Honest thin points (weakest first)

1. **Sibling tie-break leans on action-log creation order.** When attachment
   positions collide or a plan gives none (§5), the only deterministic fallback is
   the order parts were created in the action log. That makes structural order —
   and therefore the entire evaluation order — **partly a function of creation
   history, not pure geometry**. It introduces no noun (the log is blessed), but
   it is an arbitrary rule, and two "geometrically identical" bodies built in
   different orders could evaluate differently. If the user wants pure
   geometric determinism, attachment positions must be **guaranteed unique** by
   the body-plan layer, which pushes a constraint outward onto authors.

2. **Order-freezing within a tick is a (structural) snapshot.** §4.1 fixes the
   shape/order of `E` at tick start so the fold has a stable order; structural
   writes land next tick. This snapshots **order, not values** (values stay
   in-place, buffer-free), so it is arguably within the certified
   "no previous-state buffer / no whole-world snapshot" (which is about *values*
   for replay). But it is a genuine bit of held state per tick, and a critic could
   call it a snapshot. The alternative — re-deriving order mid-tick as parts
   appear — makes the fold order ill-defined and non-deterministic, so freezing is
   the defensible call, but it is the second place this design spends something.

3. **Run re-identification edges toward identity.** §6's `disc` is author
   metadata, not a substrate uid — but to keep "the same run" addressable across
   ticks while its list is rewritten each tick, the author *must* maintain a stable
   discriminator. Functionally that is identity-by-convention. The substrate
   stays clean (it blesses nothing), but the *pattern* every gradual-TF author
   reaches for is a hand-rolled uid, which is worth being honest about.
