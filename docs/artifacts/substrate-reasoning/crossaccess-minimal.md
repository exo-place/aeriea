# Cross-access: the substrate-minimal / one-primitive frame

Status: **Reasoning artifact for ONE open question** — how a transition reads/influences
state beyond its host part — argued from the assigned frame: the substrate exposes exactly
ONE navigation/addressing primitive; the author builds all higher addressing on top. Not a
decision. Adversarial against its own frame in §6.

Grounding: `docs/decisions/body-transformation-substrate.md` (tree of generic parts;
substrate blesses nothing semantic, guarantees no id/time/order/provenance; transition is
metadata on its host part, operand = self; coupling is external), and the post-adversarial
dynamics the question fixes: authored expressions, deterministic eval order, in-place
mutation, **no previous-state buffer**, determinism = seed + action log, no live pointers,
no whole-world snapshot.

---

## 1. The single minimal primitive

**`parent` — a single upward hop from the host part to the one part it is attached to.
Read-only. That is the entire navigation primitive.**

Precisely:
- From a part, an expression may obtain the part it hangs from (its unique attaching
  parent) and read that part's metadata bag and running values.
- That is the only structural addressing the substrate gives an expression. Multi-hop is
  the author composing `parent` in a recursive expression (walk up the ancestor chain,
  testing a predicate per hop). "Find the X" is the author's bounded walk, not a primitive.
- It is strictly **upward**. There is no `children`, no sibling enumeration, no descendant
  search, no global lookup in the expression language.

### Why nothing smaller suffices, and why nothing larger should be blessed

**Self-only (candidate c, "nothing beyond self") is incoherent for the common case, not
merely lossy.** A transition reading only self can never see a value another part owns, so
*no* intra-body influence exists in the dynamics at all — including parent→child scale, the
most basic, intrinsic, ubiquitous relationship in a jointed body. To restore it you push the
copy to an external system; but that system, to copy parent-scale onto children, must itself
navigate the tree **and write to non-self parts** each tick — reintroducing exactly the
cross-part write + evaluation-ordering hazard the local model avoids, and turning the cheap
intrinsic case into an expensive whole-tree mirror pass. Self-only does not eliminate
navigation; it **relocates** it to a costlier place and adds cross-writes. So zero is not a
floor — it is a regression.

**A predicate query over a bounded subtree (candidate b) is not primitive — it decomposes
into navigation.** "Find the part where P" must enumerate candidates and test P on each;
enumeration *is* structural navigation, and testing P is expression evaluation the substrate
already has. So query = navigation + author predicate. The converse fails: you can fake
single-step navigation out of a query only by having parts store parent-pointers as
metadata (redundant with the real attachment tree, and desyncs under reversal/remove) and
then resolving them — and resolution itself bottoms out in enumeration = navigation. **(a)
sits strictly below (b).** Navigation is the irreducible thing; the query is a composition.

**Why upward, not symmetric (parent *and* children)?** This is the load-bearing
restriction, and it is what makes the *no-buffer, in-place* determinism honest:

- With reads pointed only upward, the inter-part dependency graph is the tree edges directed
  child→parent. Evaluate parts **top-down (parents before children, pre-order DFS from
  root)** and every read of an ancestor sees that ancestor's already-advanced current-tick
  value. No previous-state buffer is needed; the order alone makes the read well-defined and
  deterministic. The graph is **acyclic by construction.**
- The instant you add downward reads (a parent reading a child, or a sibling reading a
  sibling), you can form a cycle (parent↔child, left↔right). A cycle has no fixpoint under
  single-pass in-place eval and forces *either* a previous-state buffer (violates the
  question's constraint) *or* a declared two-phase read-all/write-all tick (a buffer in
  disguise). Upward-only is therefore **the largest navigation primitive that keeps the
  per-tick evaluation acyclic and buffer-free.** That is the real reason it is the floor:
  not aesthetics, but the determinism budget.

This converts every downward/lateral influence into a **pull**: a descendant reads its
ancestor and scales *itself*; "torso grows, arms follow" is each arm pulling torso scale,
not the torso pushing. No part ever writes another part, so structural navigation
contributes **zero** same-property cross-part write contention.

---

## 2. Building the three targets on top of `parent`

### Hormone read — diffuse value by upstream locality
Place the hormone scalar on an **ancestor reservoir** part (a bloodstream/root node, or a
gland authored to sit upstream of its targets). A consumer's step expression walks up until
it hits the nearest ancestor bearing key `estrogen` (a bounded ancestor walk testing each
bag), reads it, and feeds it into its delta. "Diffuse" falls out of locality: every part
under that ancestor reads the same value — diffusion *is* shared-ancestor pull. The
reservoir's own value is advanced by its **own** transition (autonomous dynamics or an
exogenous logged driver). Endocrine *feedback* — gland responding to peripheral tissue —
needs the gland to sense its descendants, which is downward and **deliberately
inexpressible**; it is a whole-body sense, handled like coupling: an external system reads
the body and writes the reservoir scalar. (See §6.5 — this exile is principled, not a gap.)

### Coupling — another body
Not a navigation problem at all: a partner part lives in a **different tree**, no shared
ancestor, unreachable by `parent`. This *confirms* the `[SETTLED]` coupling decision rather
than extending the primitive. An external system holds the relation (via the `[SETTLED]`
stable body-id+segment-id resolution — a *different layer*, see §6.4), reads both bodies, and
**deposits the partner's relevant scalar as local metadata** on a part of this body each
tick. The transition then reads that mirror via self or a bounded ancestor walk. No new
in-expression addressing. Cross-body fuses timelines for the coupling's lifetime — already
priced as the external system's problem.

### Pause the most-recent transformation
"Most recent" is **provenance/order**, which the substrate blesses *nothing* about. So
recency is author metadata: each transition's local bag carries an author-stamped
`started_at` (read deterministically from the action log's tick). "Pause the most-recent TF
in this body" must rank transitions across parts — but doing that as a per-tick branching
subtree scan is the expensive walk we forbid. Instead it is a **one-shot command** (player
action, not per-tick dynamics) that consults an **author-maintained control-unit registry**
— the control-unit object (`[REASONED]`) carrying its members and `started_at`, updated
*incrementally* at add/remove, not scanned at query time. Pick max `started_at`, flip its
direction flag to frozen; all member parts follow because they pull that one control
variable. **Zero navigation**: order/provenance is author metadata + an incremental index,
never a tree walk. This is the legitimate role of "author-maintained indices" (candidate c):
not to replace the navigation primitive, but to keep *global/provenance* queries O(1)
instead of O(body)-per-tick.

---

## 3. Tree-walk: irreducible kind vs. avoidable kind

Split the question. There are two walks:

- **Branching / global walk** (descendant subtree scan, "find any part where P in the
  body," "most recent across the body"): O(subtree) or O(body), branches, the dangerous one.
  **Avoidable and forbidden.** Each instance is re-expressed away: descendant influence →
  pull from ancestor; lateral mutual → external/cyclic regime (§6.5); global provenance →
  incremental index. None is done by the primitive.
- **Linear ancestor walk** (`parent` composed up the chain, optionally until a predicate):
  the irreducible floor. **Necessary but honest**, because upward navigation **never
  branches** (exactly one parent per hop), so the walk is strictly linear and its length is
  bounded by tree **height** H.

So: walking is irreducible, but only the bounded linear upward kind. **The unbounded
O(world) walk is genuinely avoidable** — you avoid it precisely by forbidding the direction
that branches.

**Cost bound.** Per read: O(D), D = ancestor hops the expression takes, D ≤ H. Per tick:
Σ over active transitions of D ≤ (#active transitions) × H. H is a content quantity (bodies
are shallow, ~tens of levels); #active transitions is content-bounded. No descendant
branching, no cross-body reach, no global scan in the hot path. Categorically not O(world).

---

## 4. Tree vs. graph

The entire result **depends on single-parent-ness, i.e. a TREE.** Upward navigation is a
unique non-branching linear walk *only* because each part has exactly one attaching parent;
the acyclic-by-construction, buffer-free top-down eval *only* holds when "upward" cannot
branch or revisit. Under a true graph (multi-parent, or cyclic attachment) "upward" branches
and can cycle: the walk loses its bound and the inter-part dependency graph can cycle →
buffer/fixpoint required. The frame is honest **only under a tree.**

The decision doc currently says "graph of segments" (`§Structure [SETTLED]`). This frame
forces a clarifying split the doc conflates:

- **Spanning tree** = the single-parent positioned-attachment hierarchy. This is what
  `parent` walks and what per-tick dynamics use. Intrinsic structure the substrate already
  stores; it can never desync because it *is* the body.
- **Relations** = couplings, a hand grasping the opposite arm, any non-tree edge. These are
  external relation metadata, cyclic-capable, **never walked by the per-tick primitive**,
  read/maintained out of band (the coupling treatment, generalized).

Recommendation to surface for the doc: the substrate's *navigation primitive* addresses a
**tree**; extra graph edges may exist as relations but are not navigation and not part of
buffer-free per-tick evaluation. "Tree for dynamics, graph for relations."

---

## 5. The division of labor this frame yields

- **self** — the operand. Free.
- **`parent` (→ bounded linear ancestor walk)** — the ONE navigation primitive. Covers all
  *acyclic hierarchical* influence: ancestor→descendant (as pull), shared-ancestor-driven
  sibling symmetry, upstream-reservoir hormone diffusion.
- **Author metadata + incremental indices** — provenance/order/"most recent X" and
  id-keyed lookups. No per-tick navigation.
- **External systems / exogenous logged drivers** — everything *cyclic or cross-tree*:
  cross-body coupling, lateral peer-to-peer mutual reaction, gland-senses-body feedback.
  Deposited as local mirrors or driven as logged timelines.

The line is exactly: **acyclic intrinsic structure lives inside the cheap local pull; cyclic
or extrinsic relations are externalized.** That is the same line the `[SETTLED]` coupling
decision already drew — this frame *generalizes* it and shows intra-body lateral mutual
coupling is the *same* problem (a same-tick cycle) as cross-body coupling, so it earns the
same exile rather than a new primitive.

---

## 6. Adversarial pass against my own frame

**6.1 "Upward-only is a semantic blessing."** Partly true and must be named, not hidden.
The tree's direction is already given by attachment + a chosen root, so `parent` blesses no
new *entity* (not "torso is special"). But it *does* bless an asymmetry: influence is
up-readable / down-pullable by default. That is a real, non-zero substrate-level bias. It is
the *minimal* bias that buys buffer-free determinism; the symmetric alternative buys a
buffer. Defensible, but the bias is genuine and should be stated in the doc, not smuggled.

**6.2 "A predicate-tested ancestor walk IS a query — you needed (b)."** No: testing the
predicate is author expression evaluation over a bag the substrate already exposes; the
*primitive* is only "give me the parent." (a) decomposes (b); (b) does not decompose (a).

**6.3 "Author 'most recent' indices desync."** Yes — an author can forget to update the
registry on remove. But blessing order/time/provenance is exactly what the substrate
constraints forbid, so this risk is inherited by *any* faithful frame, not introduced by
this one. This frame at least *localizes* it to the registry instead of smearing it across a
per-tick scan.

**6.4 "You smuggled a second primitive (stable-id resolution)."** Acknowledged and scoped:
there are TWO addressing facilities at different layers — (i) **in-expression navigation**
(`parent`, the answer to *this* question) and (ii) **external-system stable-id resolution**
(already `[SETTLED]` identity, an O(1)-with-substrate-index facility used by external
systems). They are not the same and I do not claim one mechanism for the whole engine. The
question asks how a *transition* reaches beyond self — that is layer (i), answered by
`parent`. Cross-body is layer (ii) + external deposit, *not* the transition reaching out. The
"one primitive" claim is scoped to in-expression navigation; stated plainly to avoid
overclaiming. Why not let expressions just use id-resolution for cross-access? Because that
is a global lookup, requires the author to store and maintain a target id in self's bag
(dangles under remove/re-add during reversal), and needs a substrate-maintained global
index; `parent` reads the *live* tree edge, never dangles, needs no upkeep, bounded without
any global index. Navigation is the better in-expression primitive; id-resolution stays the
external facility.

**6.5 The strongest one — "upward-only can't express endocrine feedback or lateral
diffusion, which are real and common."** True, and this is the frame's sharpest edge, not a
hole. Gland-responds-to-tissue and arm1↔arm2 mutual reaction are **same-tick cycles**
(M→part→H→part; left↔right). The adversarial doc's central finding is that a one-way
primitive must NOT pretend to solve cycles. This frame *honors* that by refusing to let
navigation form a cycle at all: cyclic influence is named as a distinct regime and handled
by exogenous logged drivers or external whole-body readers depositing mirrors — the same
machinery coupling already uses. The cost is honest: "the body senses itself" is not a
per-tick navigation primitive. The alternative (bless downward/symmetric reads) silently
buys back the buffer/fixpoint/order-dependence the determinism constraint forbids. So the
loss is *chosen*, and it draws the cycle/acyclic line in exactly the place the substrate's
own determinism law already needs it drawn.

**6.6 "Is the floor actually zero (self + external deposit for everything)?"** Considered in
§1: zero over-externalizes — it forces the intrinsic, can't-desync, ubiquitous hierarchical
case to pay the expensive external whole-tree mirror-pass-with-cross-writes price. `parent`
internalizes exactly the acyclic intrinsic structure (the tree edge the substrate already
stores, costing no new state/buffer/index) and externalizes exactly the cyclic extrinsic
relations. That is why the floor is `parent`, not zero.

---

## 7. Bottom line

The single minimal in-expression navigation primitive is a **read-only single upward hop to
the unique attaching parent**. Everything else — multi-hop, predicate "find," hormone read,
"most recent," cross-body coupling — is author-built on top of it plus author metadata,
incremental indices, and the existing external-relation machinery. Tree-walking is
irreducible **only in its bounded, non-branching, upward form** (cost ≤ tree height per
read); the dangerous unbounded/branching/global walk is avoidable and is avoided by
re-expression (pull / incremental index / external deposit). The whole result is honest
**only over a tree** with a single parent per part; genuine graph edges must live outside the
navigation primitive as external relations — the coupling decision, generalized.
