# Candidate 4 — Operational Semantics under MAXIMIZE-FLEXIBILITY

Frame: design the model that makes the **widest range of unnamed author futures**
expressible without ever extending the substrate. Rich opaque values, predicates
that read anything reachable by 1-hop + predicate-guided traversal, `select`
returning ordered multisets, write-by-selection, an expression language general
enough that concurrency, cross-part signaling, and partial bodies are *just usage*.

Every mechanism below is run through the **new-noun gate**: the substrate may know
only (a) a tree of parts with intrinsic ordered children, (b) an opaque per-part
metadata map, (c) a set of author expressions, (d) a deterministic eval order, (e)
a deterministic same-property fold, (f) a canonical total order over values (for
determinism only). If a mechanism makes the substrate *interpret* anything else, it
fails. Near-misses are flagged honestly in §F.

---

## 1. Metadata values (full range) + opacity; what a predicate may read

**Value domain V — maximal, closed under construction.** A metadata value is any
element of:

- scalars: number, string, boolean, unit/none;
- **ordered tuple/list** of V;
- **unordered set** of V;
- **map** (association) from V to V;

nested arbitrarily and recursively. This is deliberately the richest container
algebra: a single property may hold `{ A: {p:0.3, rate:0.1, started:7},
B: {p:0.7, rate:0.05, started:12} }`. Plurality and structure live *inside* values.

**How it stays opaque.** The substrate's *entire* repertoire of operations on a
value is:

1. structural equality;
2. a fixed **canonical total order** over V (used ONLY for deterministic
   iteration of sets/maps and for tie-breaks — never given semantic meaning);
3. container construction / projection / iteration (build a map, read key `k`,
   iterate keys in canonical order, length, membership);
4. arithmetic / boolean / string ops invoked *explicitly by an author expression*.

The substrate attaches meaning to **no key and no value**. `started`, `run_id`,
`provenance`, `t` are author conventions. The substrate never knows that the map
above is "two runs"; it sees a map with two keys it can iterate in canonical order.
This is the opacity guarantee: structure is rich, interpretation is zero.

**What a predicate may read.** A predicate `P(part)` is a *pure boolean* expression
over a candidate part. Readable surface:

- the candidate's **own metadata map** (full nested read, any depth);
- **intrinsic 1-hop structure**: the candidate's parent part and its direct
  children — and *their* metadata (1 hop);
- **predicate-guided traversal**: combinators `ascend(Q)` / `descend(Q)` that
  iterate the parent / child links until a part matching `Q` is found, returning it
  (or none). This is "nearest ancestor/descendant matching Q" — bounded multi-hop,
  but *only ever guided by a predicate*, never by a fixed path index. It is just
  iterated 1-hop over already-blessed structure; it introduces no route noun.

Predicates are read-only and read **in-place current** state (no buffer, no
snapshot). Traversal that reads metadata mutated earlier this tick sees the mutated
value — consistent with the eval-order determinism (§3).

---

## 2. `select` — scope, return, ordering, determinism

`select(P)` filters parts by predicate `P`. **No path argument** —
topology-independent selection (the [CONFIRMED] requirement).

- **Scope.** The body's entire part tree (one body = one tree). Cross-body reach
  does not exist; coupling deposits metadata on each body and each body's `select`
  ranges over its own tree only ([CONFIRMED] no edge, no fusion).
- **Return type.** An **ordered multiset of parts** — concretely a *sequence*.
  Distinct parts each appear once, but the sequence is the input to a combinator
  algebra that *produces* multisets of values: `map(f)`, `filter(Q)`, `first()`,
  `last()`, `nth(i)`, `count()`, `fold(f, init)`, `seededDraw(seedValue)`. So an
  author can compute aggregates, ordered picks, or a seeded single pick uniformly.
- **Ordering rule.** The sequence is the parts in **intrinsic structural order**
  (§5), filtered to matches. This order depends only on tree shape — **not** on
  metadata, **not** on a path, **not** on creation timestamp.
- **Determinism.** Because the structural order is a *total* order over distinct
  parts (a tree has no two parts in one slot), `select` is fully deterministic and
  topology-independent in the certified sense: *which* parts match is by predicate;
  *what order* they come back in is the tree's own intrinsic shape. `seededDraw`
  consumes an author-supplied seed value and the canonical order, so it too is
  reproducible.

---

## 3. Expressions — inputs, write target, when, eval order, the fold

**An expression is a triple** `(target, key, body)`:

- `target` is a **selection** (`self`, `select(P)`, or a traversal result) naming
  *which parts* this expression writes — this is the flexibility lever: writing is
  by selection, so cross-part *push* is expressible, not only pull.
- `key` is the metadata key (possibly a nested path) it writes on each target part.
- `body` is a pure expression returning the **new value** for `(part, key)`.

**Inputs available to `body`** (all read in-place, no snapshot):

- `current` — the current value of `(part, key)`. One input among many, never
  special-cased ([CONFIRMED]).
- the **host part's** own metadata (the part the expression is authored on).
- the **target part's** metadata.
- anything reachable via `select` / 1-hop / predicate-guided traversal (§1).
- pure deterministic `draw(values…)` — a seeded hash over its explicit value args.
  There is **no blessed tick counter**: if an author wants per-tick variation they
  store and advance their own counter in metadata and pass it to `draw`. This keeps
  "tick/time" out of the substrate ([CONFIRMED] out of scope).

**What it may write.** Exactly the value of `(target part, key)` — one property per
target part. It may not scatter writes across arbitrary keys (that would need an
effect/write-set noun and would wreck the fold). To affect another property, author
another expression. Rich *values* mean one property can still carry a whole map, so
this is not a real restriction on range.

**When it runs.** Every tick, **every** expression is evaluated exactly once
([CONFIRMED] full-stop, no scheduler). Pause / probability are authored
early-returns inside `body` (return `current`; or `draw(...)`-gated no-op).

**Evaluation order.** Resolve every `(expression, target-part)` pair into a
**write-event**. The unit of evaluation is a **property-cell** `(part, key)`. All
cells are placed in one **total deterministic order**:

> sort cells by `(structural-order(part), canonical-order(key))`.

Cells are evaluated in that order; each cell's fold (below) runs to completion and
writes its result **in place** before the next cell. A later cell reading an earlier
cell sees the new value; an earlier cell reading a later cell sees the old value —
**one-tick lag emerges purely from order**, no buffer ([CONFIRMED]).

**The same-property fold (non-commutative; priority + tie-break).** When several
expressions target the *same* cell, they are **folded**, not last-wins:

1. collect the contributing expressions for this cell;
2. order them by `(priority, authoring-index)` — default order = authoring order
   via the monotonic authoring-index; an author `priority` value overrides;
   `authoring-index` is the unique stable tie-break ([CONFIRMED]);
3. fold sequentially: `v0 = current`; `v1 = expr₁.body(v0)`;
   `v2 = expr₂.body(v1)`; … final `vₙ` is written in place once.

Non-commutative because each contributor reads the running folded value as its
`current`. This is the [CONFIRMED] "sequential non-commutative fold, default
authoring order, priority override."

---

## 4. Where per-run progress lives — two out-of-step concurrent runs, NO run noun

**Answer: progress is entries in an opaque metadata map keyed by an author
discriminator.** Because a value may be a map, a single property holds:

```
tf_progress = { <discriminatorA>: <stateA>, <discriminatorB>: <stateB>, … }
```

- A **"run" is one key→state entry**. Two concurrent runs = two keys. The substrate
  sees an opaque map and iterates its keys in canonical order; it never knows the
  word "run."
- The **discriminator** is any author value: an initiator's label, a seed, the
  emitter's metadata, an incrementing author counter. ([CONFIRMED] uid/identity are
  ordinary metadata — this is exactly that, used as a map key.)
- **Out-of-step** is automatic: each entry's state carries its *own* progress (and
  rate, phase, paused flag). The *one* transition expression iterates the map and
  advances **each entry by its own state**, writing the updated map back. Plurality
  is in the data; the expression is singular.
- **Pause one run** = that entry's state holds a flag (or the expression's
  predicate over `started` selects it); for that entry the fold-step returns the
  entry unchanged. Other entries advance.

This is the crux win of the flexibility frame: concurrency, out-of-step progress,
and per-run pause are **all just opaque-map usage** — no `run`, `instance`, `store`,
`cell`, or `progress-primitive` is blessed. The substrate iterates a map.

(Why not "each run on its own part"? The two runs act on the *same* target parts, so
their progress cannot be partitioned by part — it must coexist on one property. A
discriminated map is the minimal noun-free carrier.)

---

## 5. Intrinsic structural order + tie-breaks

The tree is an **ordered tree**: each part has an *intrinsic* ordered list of
children. Sibling order = the order children were attached in the deterministic
action log (the same seed+log that defines replay). This is structural shape, not
metadata — it needs no guaranteed metadata field.

**Structural order over all parts = depth-first preorder:** visit a part, then
recurse into its children in sibling order. This yields a **total** order over
distinct parts.

- **Tie-breaks:** none are needed *between parts* (each part occupies a unique slot,
  so preorder is already total).
- Tie-breaks for **values** (set/map iteration, fold key ordering) use the
  **canonical total order over V** (§1.2) — purely mechanical, no semantics.
- `key` ordering within a cell sort (§3) likewise uses canonical order over V.

Topology-independence is preserved: selection never names a slot; ordering merely
*reads* the intrinsic shape, which is the [CONFIRMED] "order candidates by the
tree's intrinsic structural order (attachment positions)."

---

## 6. Hard-case battery — PASS/FAIL

| # | Case | Verdict | Forced noun |
|---|------|---------|-------------|
| 1 | gradual transformation | **PASS** | none |
| 2 | pause-most-recent | **PASS** | none |
| 3 | two concurrent out-of-step runs | **PASS** | none |
| 4 | cross-part signal | **PASS** | none |
| 5 | one-of-several selection | **PASS** | none |
| 6 | non-standard / already-transformed body | **PASS** | none |

### Case 1 — gradual transformation (PASS)
Expression on the torso: `target=self, key=shape, body = min(1, current + host.rate)`.
Each tick advances `shape` toward 1. No noun.

### Case 2 — pause-most-recent (PASS) — worked
Metadata on target part:
```
tf_progress = {
  "a": { p: 0.30, rate: 0.10, started: 7  },
  "b": { p: 0.55, rate: 0.05, started: 12 },   # most recent (max started)
}
```
Single expression `target=self, key=tf_progress`:
```
body(current):
  mostRecent = argmax_key(current, e -> e.started)   # author "recency" pattern over metadata
  return mapOverEntries(current, (k, e) ->
    (k == mostRecent)                                  # pause the most-recent run
      ? e                                              # early-return entry unchanged
      : e.with(p = min(1, e.p + e.rate)))              # advance the rest
```
"Most recent" is an author argmax over the author `started` field; pause is an
early-return for that entry. Substrate iterates an opaque map. **No noun.**

### Case 3 — two concurrent out-of-step runs (PASS) — worked
Same `tf_progress` map; two keys `"a"`,`"b"` with different `p` and `rate`:
```
body(current):
  return mapOverEntries(current, (k, e) ->
    e.paused ? e : e.with(p = min(1, e.p + e.rate)))
```
`"a"` advances at 0.10/tick, `"b"` at 0.05/tick — out of step, from one expression.
A third run is a third key. Each run's progress lives in its own map entry; the
discriminators `"a"/"b"` are author values. **No `run` noun.**

### Case 4 — cross-part signal (PASS)
Pull form: emitter writes `self.hormone = 0.8` into its own metadata; each receiver
expression reads `ascend(p -> p.meta.gland == "adrenal").hormone` or
`select(p -> p.meta.receptor == "X")` and responds — predicate-guided traversal over
in-place metadata, one-tick lag by order. Push form (flexibility): emitter
expression with `target = select(hasReceptorX), key = stimulus`. Either way no graph
edge is blessed — cross-part effect rides metadata + 1-hop/traversal. **No noun.**

### Case 5 — one-of-several selection (PASS) — worked
Pick one finger of several:
```
fingers = select(p -> p.meta.kind == "finger")        # ordered by structural order
chosen  = fingers.seededDraw(target.meta.seed)          # OR fingers.first() / .last()
```
Durable tracking of "the chosen one" across ticks = a predicate over a
*distinguishing author field* the expression stamps on it (`chosen_mark = seed`),
re-found next tick by `select(p -> p.meta.chosen_mark == seed)`. **No uid noun** —
just metadata + the intrinsic structural order for the candidate sequence.

### Case 6 — non-standard / already-transformed body (PASS)
All reach is predicate + topology-independent, so a body missing parts, with extra
parts, or pre-advanced just yields different `select` results and different
`current` values. An already-transformed part has high `current`/`p`, so `body`
naturally no-ops (`min(1, …)` saturates) or continues from where it is. A
partly-run transformation is a pre-seeded `tf_progress` map. **No noun** — partial
state is ordinary metadata.

---

## 7. Two bonus patterns expressed for free (range demonstration)

1. **Quorum sensing / morphogen field (majority rule).** An expression computes
   `select(p -> p.meta.kind=="cell" && p.meta.signal > θ).count()` and thresholds it
   to flip its own state — cellular voting / reaction-diffusion-like fields, with
   one-tick lag from eval order. *Noun gate:* it is `select` + `fold/count`, no
   aggregate/field noun. **PASS.**
2. **Discriminated provenance layering / branchable history.** Each writer stamps
   its result under its own discriminator into a nested map
   (`layers = { writerA: v, writerB: v }`); a downstream expression folds the layers
   in canonical order to compose, or drops one key to "undo" that contributor.
   Branch/undo/provenance for free. *Noun gate:* opaque nested map + fold, no
   provenance/version noun. **PASS.**

Both reduce to "rich opaque values + select + fold" — the same primitives as the
battery, confirming the range is structural, not bolted-on.

---

## F. Honest weak points (where flexibility costs determinism / flirts with a noun)

1. **Canonical total order over V (the strongest near-miss).** To iterate opaque
   sets/maps and to tie-break folds deterministically, the substrate must impose a
   fixed total order on *values*. That is substrate-blessed structure over the value
   domain. I argue it carries **no semantics** (it never means "time" or "rank"; it
   is a mechanical iteration order), so it passes the gate — but it is the closest
   thing here to a smuggled noun ("ordering-of-values"). If the user rules even a
   semantics-free value order out of bounds, §4's map iteration and §3's fold key
   ordering lose their determinism guarantee and the model breaks. This is the
   single load-bearing concession.

2. **Write-by-selection makes the fold's contributor set data-dependent.** Allowing
   `target = select(P)` (the cross-part *push* flexibility) means *which*
   expressions hit a given cell can depend on metadata that earlier cells mutated
   *this same tick*. Determinism is preserved only by the rule "contributor
   membership and order are resolved against in-place state at the instant that
   cell's fold runs, in the global cell order" — which is deterministic but subtle,
   and an author can write a configuration whose contributor set is hard to predict.
   A stricter design (push forbidden, signaling pull-only) would be simpler but
   strictly less expressive. Under the maximize-range frame I keep push and accept
   the reasoning cost; flagged as the place flexibility most taxes determinism
   clarity.

3. (Minor) **Ordered tree blesses sibling insertion-order** as intrinsic structure.
   This is "an order the substrate knows," but it is *structural*, derived from the
   deterministic action log, not metadata — and it is exactly the [CONFIRMED]
   "intrinsic structural order (attachment positions)." Lower risk than (1)–(2) but
   noted for completeness.

---

*Design only. Not implemented, not promoted, not committed. Reasoned, pending the
user's check.*
