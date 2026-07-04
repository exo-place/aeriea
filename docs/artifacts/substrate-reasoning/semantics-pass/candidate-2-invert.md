# Candidate 2 — INVERT THE DEPENDENCY (carrier-owned progress)

Operational-semantics pass for the body/transformation substrate. One frame,
committed hard. Grounded in `docs/decisions/body-transformation-substrate.md`
(its [CONFIRMED] invariants are honored, not relitigated).

## The frame, stated as a thesis

Flip ownership of progress. **The body holds no per-run state.** The external
thing that *causes* a transformation carries its own progress/parameters and
writes onto the target each tick. Two out-of-step runs = two distinct carriers,
each with its own progress, both writing the same target. The target part holds
only its *actual* properties (the result), never bookkeeping about how far any
run has come.

### The one load-bearing reinterpretation (stated up front, honestly)

"Off-body" is reinterpreted as **off-target-ownership, NOT off-tree.** A carrier
is an ordinary **part attached into the target's part tree**, author-marked by
metadata as a carrier. It is *structurally* on the tree (so the uniform tick walk
reaches it) but *semantically* owns the run's progress instead of the target
owning it.

This is forced. A carrier that floats genuinely outside the tree could only be
ticked by a substrate-held **registry** of carriers to iterate — and a registry
is a blessed new noun (FAIL by the gate). Keeping carriers as tree parts means
the substrate enumerates them by the same DFS walk it uses for every part, with
**zero new noun**. The whole frame rests on: *applying a causer = the external
system depositing a carrier part into the target's tree* (which is exactly the
[CONFIRMED] "external system writes onto both entities" — here the body-side
write is a carrier subtree). Everything below depends on this move; §"weak
points" owns the consequence.

---

## 1. What a metadata value may be; what a predicate may read

- **No property/metadata distinction.** Everything on a part is one
  author-defined, substrate-uninterpreted key→value map. A "property" is just a
  key that some transition expression chooses to write; the substrate does not
  bless the distinction.
- A **value** is: a scalar (number, bool, symbol/string), a flat record/tuple of
  scalars, or an **author expression** (a closure evaluated in the tick context).
  The substrate never reads *meaning* from any value — `role:"carrier"`,
  `kind:"mammary"`, `prog:0.3` are all opaque to it.
- A **predicate** is an author expression `(candidate, ctx) -> bool`. It may read:
  the candidate part's own map; the anchor part's map (where the predicate is
  hosted); and **intrinsic 1-hop structure** of any part it holds — immediate
  parent, direct children. It may NOT name a path or a topological route
  (topology-independent, [CONFIRMED]). Multi-hop reach is expressed as
  predicate-guided traversal ("nearest ancestor matching P"), still content-keyed.

## 2. `select`

- **Signature:** `select(pred) -> [part]`.
- **Scope:** the entire connected part tree under the body's root (carriers
  included — they are parts).
- **Return type:** an ordered sequence of **ephemeral handles**, valid only
  within this tick's evaluation. A handle is not a uid, is never stored, never
  persists across ticks. (Durable individual targeting is a *predicate over
  distinguishing metadata*, not a retained handle — §case 5.)
- **Ordering rule:** the tree's **intrinsic structural order** = pre-order DFS
  from root, siblings in **attachment-index order** (the stable slot at which each
  child was attached to its parent — structural data, not metadata). The
  *predicate* is content (topology-independent); the *order of results* is
  structure. Both deterministic.
- **Determinism:** pure function of (tree shape, attachment indices, metadata) at
  eval time. No RNG unless the author threads a seeded draw through the predicate.

## 3. Expressions

- An expression is **hosted on a part** (its anchor). Its anchor need not be what
  it writes — that asymmetry is the whole frame.
- **Inputs:** (a) the anchor's own map; (b) parts returned by any `select(pred)`
  it runs, and those parts' maps; (c) intrinsic 1-hop structure of held parts;
  (d) the seed (for seeded draws / probabilistic TF); (e) the **current value of
  the (part, key) it is about to write**, read in-place. There is **no
  previous-tick buffer, no snapshot** ([CONFIRMED]); a backward/lateral read sees
  whatever is in place now, so one-tick lag emerges from order alone.
- **What it may write:** zero or more `write(part, key, value)` where `part` is the
  anchor or any selected part. A write is a *value*, optionally tagged with a fold
  ordering key (§fold).
- **When it runs:** **every expression on every part, every tick.** Full stop, no
  scheduler ([CONFIRMED]). PAUSE = authored early-return (return current value,
  no advance). PROBABILISTIC = seeded draw early-returning to no-op unless it
  passes.
- **Evaluation order (the global total order):** DFS pre-order over the tree (by
  attachment index); within one part, expressions in authoring order. This single
  order is what resolves cycles ([CONFIRMED] eval-order-only).
- **Same-property fold (non-commutative):** when several writes target the same
  `(part, key)` in one tick, they fold **sequentially**: each writing expression
  receives the *current folded value* as its current-value input and returns the
  next; `w2` sees `w1`'s output. There is no simultaneity to break — eval order is
  total. **Priority override** does not introduce a noun: each write carries an
  *ordering key* of the same type as its default (the eval sequence number); the
  fold sorts pending writes by ordering key, default = eval position, author may
  stamp an explicit number to reorder. This is the fold's own positional
  parameter, not a world-noun the substrate interprets semantically.

## 4. Where per-run progress lives, and how the tick reaches it

**Per-run progress lives on the carrier part**, as ordinary keys (`prog`, `rate`,
`paused`, `target_cap`, `applied_seq`, ...). The carrier IS the run — but it is
*not* a blessed "run" noun: to the substrate it is an indistinguishable part;
only author metadata (`role:"carrier"`) marks it, and the substrate never reads
that mark.

**How the tick reaches off-target expressions without a "run"/"driver" noun:**
the carrier is a part in the same tree, so the ordinary DFS tick walk evaluates
its expressions exactly like any anatomical part's. No registry, no scheduler, no
driver. A carrier's expression typically (e1) advances its *own* `prog` (a
same-part write on the carrier), then (e2) `select`s target parts by content
predicate and writes their properties as a function of `prog`/`rate` and the
target's current value.

The **target holds zero per-run fields.** It holds its real properties (the
result), which the carrier mutates in place. Removing the carrier removes the
run's *progress*; the result remains as plain body state.

## 5. Intrinsic structural-order rule + tie-breaks

Pre-order DFS from root; siblings ordered by **attachment index** (unique per
parent by construction → a total order on siblings). If an engine ever permitted
equal indices, break by **creation sequence** (intrinsic, monotonic), which is
total. The global expression eval order is this DFS; within a part, authoring
order. No metadata participates in the *structural* order (metadata only enters
via predicates and via the fold's explicit ordering key).

---

## Hard-case battery — PASS/FAIL

| # | case | verdict | forced noun |
|---|------|---------|-------------|
| 1 | gradual transformation | **PASS** | none |
| 2 | pause-most-recent | **PASS** | none |
| 3 | two concurrent out-of-step runs | **PASS** (additive/delta authoring); weak for absolute-value transforms | none |
| 4 | cross-part signal (hormone X→Y) | **PASS** | none |
| 5 | one-of-several selection | **PASS** | none |
| 6 | already-transformed / causer consumed | **PASS** for freeze; reversibility-after-consumption needs base deposited on the body | none |

### Case 1 — gradual (worked)

Carrier `C` deposited under the body root:

```
C.meta = {
  role: "carrier",                 // opaque author convention
  tf_tag: "lactation_induction",
  applied_seq: 17,                 // from action log; author "provenance"/"recency"
  prog: 0.0,                       // PER-RUN PROGRESS lives HERE
  rate: 0.01,
  paused: false,
}
C.expr (authoring order):
  e1 advance own progress:
    write(self, "prog",
      self.paused ? self.prog                       // early-return = pause
                  : min(1.0, self.prog + self.rate))
  e2 write target(s):
    for t in select(p -> p.kind == "mammary"):      // content predicate, topo-indep
      write(t, "milk_capacity",
        t.milk_capacity + (self.paused ? 0 : self.rate * t.base_cap))   // delta, reads current in place
```

Torso/mammary holds `milk_capacity` (real state). Carrier holds prog/rate/paused.
Tick DFS reaches C, evals e1 then e2. **PASS, no new noun.**

### Case 2 — pause-most-recent

"Most recent" is an author pattern: each carrier stamps `applied_seq` from the
action-log counter. Pausing the most recent run = set `paused:true` on the
carrier with the max `applied_seq` among carriers sharing the `tf_tag`. The actor
is either an external action (out of scope) or an author expression:
`select(p -> p.tf_tag=="breast_growth")` → reduce the result by max `applied_seq`
(the expression re-sorts its selected set by a metadata key; `select` gives
structural order, the expression re-orders by content) → `write(thatCarrier,
"paused", true)`. The carrier's own e1/e2 then early-return. **PASS, no new noun**
("most recent" = metadata pattern, not blessed order).

### Case 3 — two out-of-step runs (worked)

```
C_A.meta = { tf_tag:"breast_growth", applied_seq:5, prog:0.3, rate:0.01, paused:false, target_cap:3.0 }
C_B.meta = { tf_tag:"breast_growth", applied_seq:9, prog:0.7, rate:0.02, paused:true,  target_cap:3.0 }

each carrier's e2 (delta toward a SHARED cap):
  for t in select(p -> p.kind=="breast"):
    write(t, "size",
      min(self.target_cap, t.size + (self.paused ? 0 : self.rate)))   // additive delta
```

`prog_A=0.3`, `prog_B=0.7` are independent per-run progress, each on its own
carrier. The tick folds both writes on `torso.size` in eval order (or by an
author-stamped ordering key): C_A adds 0.01; C_B is paused, adds 0 (frozen at the
contribution already baked into `size`). Out-of-step is preserved — one advances,
one is frozen, each independently pausable/removable. Target holds `size` only;
**zero per-run fields. PASS, no new noun.**

> Honesty: this is clean because writes are **additive deltas toward a shared
> cap**. Two *absolute-value* writers (`size := lerp(base,target,prog_i)`) fold
> by last-write-wins and one run's contribution is erased. The invert frame
> *requires* delta/accumulator authoring for concurrent runs; see weak points.

### Case 4 — cross-part signal

Hormone is a key on producing parts. A receiving part Y's expression:
`for s in select(p -> p.produces == "estrogen"): acc += s.level * weight(...)` —
optionally weighting by predicate-guided traversal / 1-hop distance — then writes
Y's property from `acc` and Y's current value. Producers may themselves be
carrier parts. Topology-independent, content-keyed. **PASS, no new noun.**

### Case 5 — one-of-several

`select(pred)` returns candidates in intrinsic structural order; the expression
picks first / last / by-criterion / seeded-draw. Durable targeting of the *same*
individual across ticks = a predicate over distinguishing metadata (e.g. a
`marked:true` a prior tick wrote onto the chosen part), never a retained handle or
uid. **PASS, no new noun.**

### Case 6 — already-transformed / causer consumed (worked)

```
Before: torso.size = 2.4, written in place by a now-finished growth carrier.
External system consumes the item -> removes carrier part C from the tree.
Tick: no carrier with that tf_tag in the tree -> nothing advances size
      -> torso.size stays 2.4 permanently.
```

The **result persisted because it was written into the body's own key in place**;
only the **progress** (`prog`) died with C — which is correct: the transformation
is over. Re-applying a different item deposits carrier `C'`; its
`select(p -> p.kind=="breast")` finds the already-grown torso (content predicate,
indifferent to prior transforms) and proceeds from `size=2.4`. **PASS, no new
noun.**

> Honesty (the frame's thin edge): to *reverse* back to the pre-transform value
> after the item is gone, the original base must have been deposited on the
> **body** (`torso.size_base = 1.0`) at apply time — the [CONFIRMED] "external
> system writes onto both entities." If `base` lived only on the carrier, it is
> gone with the carrier (freeze, not rewind). So **"zero per-run fields on the
> body" holds for PROGRESS, not for post-consumption REVERSAL data.**

---

## Where this frame is thin (the two weakest points)

1. **Carrier-must-be-on-tree is the whole frame.** "Off-body" is really
   "on-tree, ownership-inverted." A genuinely external causer (an item still in
   an inventory, not yet a body part) cannot be ticked without a substrate
   **registry** of carriers — a blessed new noun (FAIL). So the frame is entirely
   load-bearing on the *deposit step*: applying a causer = the external system
   attaching a carrier subtree into the target's tree. If that deposit is
   disallowed (e.g. carriers must not pollute the anatomical tree), the frame
   collapses to needing a registry. The deposit itself is out-of-scope
   (external-system) — so the frame outsources its own crux.

2. **Absolute-value transforms break the concurrency story; reversal leaks state
   onto the body.** Two out-of-step runs compose cleanly *only* as additive
   deltas toward a shared cap; absolute-value (`:=`) writers lose a run under the
   last-write-wins fold. And post-consumption reversibility forces restore-data
   (`size_base`) onto the body, so the headline "body stores ZERO per-run fields"
   is true for progress/bookkeeping but **not** for reversal data the author
   chooses to make durable. The maximal claim — body stores literally zero — holds
   for *progress* and fails for *reversal*.
```