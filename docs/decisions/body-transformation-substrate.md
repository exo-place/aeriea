# Body / Transformation Substrate

## A. Purpose and scope

This is the design of a radically-generic body/transformation **substrate** for
aeriea. Nothing here is implemented — it is a design record only, and the user
gates all design before any code is written. The substrate's defining ambition is
that it blesses almost nothing: it is the thin invariant floor over which authors
build every body-shaped and transformation-shaped behavior as ordinary data and
ordinary expressions.

Every claim below carries one of three confidence tags, and the tags are the point
of the document — its job is to *not* launder reasoning as settled:

- **[CONFIRMED]** — the user explicitly confirmed it.
- **[REASONED]** — derived during this design session but **not** user-confirmed;
  pending the user's check.
- **[OPEN]** — genuinely unresolved; deliberately left unfilled.

When confidence was unclear, the claim was downgraded. Nothing is tagged
[CONFIRMED] that is not in the confirmed set the user blessed.

---

## B. [CONFIRMED] — substrate invariants the user blessed

- **[CONFIRMED]** The substrate blesses almost nothing. **No semantic concept is a
  substrate concept** — not `material`, `covering`, `fluids`, `tags`, `kind`, or
  `role`; not `transformation`, `transition`, `run`, or `instance`; not `driver`,
  `direction`, `control-unit`, `control-variable`, or `progress`; not `identity`,
  `uid`, or `handle`. These may all exist as author-level data, never as blessed
  substrate primitives.
- **[CONFIRMED]** There is **no guaranteed metadata of any kind**: no built-in id,
  no time, no order, no provenance. Metadata is arbitrary, uninterpreted,
  author-defined key-values. The substrate never interprets a metadata value.
- **[CONFIRMED]** Provenance, time, order, identity, "most recent", and grouping
  are all **author-level patterns built from ordinary metadata** — not substrate
  features. Provenance-in-metadata is the user's own stated answer for how authors
  address things.
- **[CONFIRMED]** Determinism comes from a **deterministic evaluation order over
  in-place mutated state**. There is **no previous-state buffer** and **no
  whole-world snapshot**. Replay is `seed + action log`, nothing else.
- **[CONFIRMED]** Coupling is **not a substrate concern**. An external system
  writes coupling metadata onto **both** involved entities; each body reads only
  its own metadata; the substrate never represents a cross-body edge. There is
  **no timeline fusion** — a fused / mega-timeline was explicitly rejected as
  wrong.
- **[CONFIRMED]** A transition is **not a body part** and is **not a node in the
  body tree**.
- **[CONFIRMED]** Paths and structural routes (absolute or relative) do **not**
  generalize across body plans. Selecting a part must be **topology-independent**.
- **[CONFIRMED]** `uid` is **not a substrate thing**. It is just metadata, like any
  other field.
- **[CONFIRMED]** The substrate must support **two concurrent out-of-step runs of
  the same transformation on the same target**.
- **[CONFIRMED]** Transitions are **expressions that return the new value of a
  property**. The property's current value is **one input among many**, not
  special-cased.
- **[CONFIRMED]** Same-property writes combine in a **deterministic order** — a
  sequential, non-commutative fold. The default is authoring order; an author
  priority override is available.
- **[CONFIRMED]** **Reverse and pause are authored**, not substrate primitives.

### Explicitly rejected — do not reintroduce

- **[CONFIRMED]** The **"library"** framing.
- **[CONFIRMED]** **Control unit**, **control variable**, **direction**, and
  **driver-for-control**.
- **[CONFIRMED]** **Progress values** as a blessed concept.
- **[CONFIRMED]** **"Instances" / "runs"** as blessed, state-bearing entities.
- **[CONFIRMED]** **Fused timelines.**
- **[CONFIRMED]** Blessed **identity / uid / store / cells / resolver.**

---

## C. [REASONED] — cross-access synthesis (NOT user-confirmed)

These are derived from a four-frame decorrelated pass (locality, capability,
minimal, identity) and an adversarial synthesis over them. They are **reasoned, not
confirmed**, and await the user's check. Backing:
`docs/artifacts/substrate-reasoning/synthesis.md` and the four
`docs/artifacts/substrate-reasoning/crossaccess-{locality,capability,minimal,identity}.md`.

- **[REASONED]** Reaching state beyond a part is by **content / predicate selection
  over metadata** (topology-independent), plus **intrinsic 1-hop structure**
  (immediate parent / direct children, which is plan-robust), plus
  **predicate-guided traversal** ("nearest ancestor matching P") — **never** a
  fixed structural route.
- **[REASONED]** "One of several": **order candidates by the tree's intrinsic
  structural order** (attachment positions), then pick by first / last, by
  criterion, or by seeded draw. Durable individual tracking is just a **predicate
  over distinguishing author metadata** — no `uid` concept is required.
- **[REASONED]** Cycle / aggregate resolution: the deterministic evaluation order
  yields an **implicit one-tick lag** for backward / lateral edges, with **no
  buffer**; the author controls immediate-vs-lagged by choosing the order.
- **[REASONED]** The **tree likely stands** — nothing intra-body shown so far
  forces promotion to a graph backbone.

These four are the session's best current synthesis and explicitly remain **pending
the user's check**.

---

## D. [OPEN] — unresolved (deliberately not filled in)

- **[OPEN]** All **operational semantics are undefined**: what a metadata value may
  be; what a predicate may read; `select`'s scope, return, ordering, and
  determinism guarantee; an expression's exact inputs, what it may write, when it
  runs, and the evaluation order; what drives the tick; the exact intrinsic
  structural-order rule and its tie-breaks.
- **[OPEN]** **Tree vs graph** — the user said "idk". Section C reasons the tree
  likely stands, but this is not decided.
- **[OPEN]** The **cycle-resolution policy** is reasoned (Section C) but **not
  user-confirmed**.
- **[OPEN]** **No evidence of a floor.** The model has **not** been pinned to
  operational semantics, nor adversarially tested against the hard-case battery:
  gradual transformation; pause-most-recent; two out-of-step copies; a cross-part
  signal; one-of-several; a non-standard / already-transformed body. **Until a
  pass/fail table exists showing each case expressible with NO new noun,
  completeness is unestablished.** Producing that table is the **immediate next
  work**.
- **[OPEN]** **Precise pause mechanics** are unresolved (pause is authored — Section
  B — but the exact mechanism is not pinned).

---

## E. Corrections applied to the prior doc

The previous version of this doc over-claimed in several places. Recorded here so
the downgrades are explicit and not silently lost:

- **"A body is a graph of generic segments"** — **downgraded**. This was stronger
  than the evidence; tree-vs-graph is now **[OPEN]** (Section D), with the synthesis
  reasoning that the tree likely stands (Section C).
- **The control-unit / control-variable / direction / driver-for-control section** —
  **deleted**. The user explicitly rejected these concepts; they are listed under
  "Explicitly rejected" (Section B) so they are not reintroduced.
- **The fused-timeline framing for coupling** — **replaced**. Coupling is now an
  external system depositing metadata on **both** involved entities, with each body
  reading only its own; no timeline fusion (Section B).
- **Blessed identity / uid / store / cells / resolver language** — **removed**.
  `uid` is ordinary metadata; identity, store, cells, and resolver are not substrate
  things (Section B).
