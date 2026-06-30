# Cross-access, the STRICT LOCALITY / CELLULAR frame

Status: **one independent design pass, single assigned frame. Reasoning artifact,
no code, not green.** This argues the cellular position on the open question "how
does a transition read/influence state beyond its host part?" as hard as it will
go, then turns hostile on itself. Sibling to whatever other frames answer the same
question; do not read as the decided answer.

Grounding read first: `docs/decisions/body-transformation-substrate.md` (structure,
dynamics, previous-state recurrence, same-property ordered fold, coupling-is-
external), `docs/artifacts/substrate-reasoning/B3-ports.md` (the coupling-as-scope-
correct-relation pass) and `adversarial.md` (the six-frame stress test, whose ONE
shared blind spot — *same-tick mutual dependency / cycles* — turns out to be the
exact thing this frame is built to dissolve). I treat those as constraints, and flag
two places where the assigned constraints contradict the decision doc.

---

## 0. The frame in one line

Every transition is a **cell update**: a pure function of a **fixed, tiny
neighborhood** — its host's own metadata + its host's parent + its host's direct
children — and nothing else, ever. Anything farther than one tree-hop is reached
only by **propagation over successive ticks**. Hormones are not globals; they are
per-part values that flow parent↔child. Coupling is not a cross-body read; it is a
local interaction at a contact adjacency. No transition ever names a part it is not
touching.

This is morphogenesis, not teleology. It is the position that the body is a
**cellular automaton on a tree** and a transformation is a **field evolving on it**.

---

## 1. The precise rule (what a transition may touch)

Let transition `T` be hosted on part `P` (its operand/"self" is `P`; its locals are
`T`'s own sub-bag).

> **Locality rule.** Within one tick, `T` may **read** the metadata of exactly:
> `P` itself, `P.parent`, and each of `P`'s **direct** children — the closed
> 1-ball around `P` in the attachment tree. `T` may **write** to `P`'s own metadata
> and to `T`'s locals freely; it may write to a neighbor (parent / a direct child)
> **only through a single antisymmetric edge-flux op** (see §3), never an arbitrary
> assignment. `T` may name **no other part** — no ancestor above the parent, no
> sibling, no descendant below a child, no part of any other body, no global/world
> bag. There is no "all parts" reduction and no "find part by tag" read.

Three consequences fall straight out:

- **Siblings are 2-hops, not adjacent.** Two arms coordinate only *through* their
  shared parent, and therefore only across **two ticks** (arm→shoulder, then
  shoulder→other arm).
- **The neighborhood is dynamic but always small.** `add`/`remove` change who the
  children are, but the read set is always `1 + 1 + deg_children(P)`, bounded by
  local fan-out, never by body size. State is trivially serializable: a transition
  is a closure over O(local-degree) values, no live pointers, no snapshot of the
  world. This is the frame's whole reason to exist.
- **No within-tick reach = no within-tick cycle.** Because every cross-part
  influence is a *neighbor* read and is realized only on the *next* tick, the system
  has **no same-tick mutual dependency at all.** (This is the strongest card; §6.)

### 1.1 A latent contradiction in the assigned constraints — name it now

The prompt's constraints say "**in-place mutation; NO previous-state buffer**." The
decision doc (§Determinism) says the opposite load-bearing thing: "**each tick
computes next-state from the previous state … cross-quantity dependencies read the
previous tick's state.**" These cannot both hold for a diffusing field:

- *Previous-state buffer (Jacobi)*: every cell reads the **old** neighborhood,
  writes the **new**. Order-independent, symmetric, true heat equation. This is what
  the decision doc demands and what makes the cycle-dissolution in §6 actually hold.
- *In-place, no buffer (Gauss-Seidel)*: a cell reads whatever neighbor values are
  *currently* there — some already updated this tick by an earlier-ordered cell. The
  result is **deterministic** (fixed seeded eval order) but **sweep-order-biased**:
  the field propagates faster in the sweep direction. Symmetric physics comes out
  asymmetric.

The cellular frame *can* run on either, but its quality claims (symmetry,
conservation, cycle-freedom) require the **previous-state buffer**. So either the
prompt's "no buffer" constraint is wrong for this frame, or the frame must accept a
seeded directional bias as a permanent artifact. I hold this as the frame's first
honest crack and assume Jacobi where I claim correctness, flagging where in-place
breaks it.

---

## 2. Hormone-driven growth across distant parts — worked sketch

Goal: a gonad part secretes "estrogen"; a distant breast part should grow in
response. No part may read across the body. The hormone must *travel*.

Represent the hormone as one metadata scalar `h` per part. Three authored
transition kinds, each strictly local:

**(a) Secretion (host = gonad).**
```
gonad.h += secretion_rate * dt        # local source term, reads only self
```

**(b) Diffusion (host = every part P).** The discrete graph-Laplacian, reading only
the 1-ball:
```
flux_up   = D * (P.parent.h - P.h)
flux_down = D * Σ_child (child.h - P.h)
P.h_next  = P.h + flux_up + flux_down
```
(Conservation handled in §3 — naively writing both ends double-counts.)

**(c) Response/growth (host = breast).** Purely local threshold on the value that
has now *arrived*:
```
if breast.h > threshold:
    breast.volume_ml += growth_curve(breast.h, progress) * dt
```

Dynamics: secretion raises `h` at the gonad; diffusion carries a gradient up the
pelvis, through the torso, out to the chest over a number of ticks ≈ the tree
distance / D. When the wavefront reaches the breast and crosses threshold, growth
begins. Reversal (estrogen falls) drains `h` back down the same gradient and growth
eases. **Nothing ever read a distant part.** The "hormone system" is emergent from
one local rule applied everywhere.

This is genuinely elegant for **morphogenetic** transformation: scales creeping
segment-to-segment, a feathering wave, a material/texture spreading to neighbors,
Turing reaction-diffusion patterning — all native, all beautiful here, all
impossible to express as cleanly in a "read the global hormone scalar" frame.

### 2.1 …and where it already smells

The breast does not respond to "estrogen level"; it responds to "estrogen level
*as diffused to its location*," which depends on tree distance, branch topology, and
every intervening part's `h` capacity. A long-necked body's head lags its hips by
more ticks than a compact body's. That spatial structure is sometimes *desired*
(local patterning) and sometimes *a bug* (a whole-body estrogen wash is supposed to
hit everything at once, not sweep limb by limb). The frame cannot tell the two apart
— it imposes propagation latency on **all** long-range influence, including the
influence that is conceptually instantaneous and global. Held for §5.

---

## 3. Conservation: the write-to-neighbor discipline

A true "amount of substance" must be conserved as it flows. Naive diffusion (§2b)
written by every part independently double-applies each edge: the edge (P, child) is
touched by P's transition (as a down-flux) **and** by child's transition (as an
up-flux). Two fixes, both inside the locality rule:

- **Edge ownership convention.** Each edge is *owned by its lower endpoint*. Only a
  child computes the flux across its up-edge, and that single op **writes both** ends
  antisymmetrically: `child.h -= φ; parent.h += φ`. Writing to the parent is legal
  (parent is in the 1-ball). Each edge is now computed exactly once → exact
  conservation.
- This is why the rule (§1) permits neighbor-writes **only** as an antisymmetric
  edge-flux, never a free assignment: an arbitrary `parent.h = …` cannot conserve
  and cannot be made order-safe.

Honest cost: conservation is a **convention the substrate blesses nothing about.**
The substrate guarantees no `h`, no edge ownership, no antisymmetry. One mis-authored
diffusion transition that writes a neighbor freely silently creates or destroys
substance, and nothing flags it. "Strict locality conserves" is an *authoring*
property, not a substrate guarantee — exactly the kind of unblessed-but-load-bearing
convention the project keeps having to accept (cf. B3 §5.1).

And note the in-place hazard returns here in full force: `child.h -= φ; parent.h +=
φ` mutates the parent mid-tick, so any part that reads its parent's `h` *after* the
child wrote it sees the post-flux value. Conservative **and** order-safe needs the
previous-state buffer again.

---

## 4. Coupling between two bodies — worked sketch, and where it cracks

Two bodies A and B; an act couples `A.member` to `B.orifice`. Under strict locality,
no transition in A may read into B and vice-versa. So how does fluid cross?

`A.member` and `B.orifice` are **leaves in two different trees**. They are **not**
parent/child of each other — there is no tree adjacency across bodies at all. The
locality rule as written (§1) therefore **literally forbids the coupling read.**
The frame has exactly three moves, and each costs something the frame claimed:

- **Move 1 — graft a contact edge (re-parenting).** For the coupling's duration,
  install a tree edge making `B.orifice` a neighbor of `A.member`. Now they are
  1-hop adjacent and a local flux op (§3) moves fluid across exactly as it moves `h`
  across a normal edge: `member.fluid -= φ; orifice.fluid += φ`, with tightness
  modulating `φ`. This *works* and is even pretty — coupling becomes "the same local
  flux op as everything else, on a temporarily-grafted edge." **But the grafted edge
  joins two formerly-disjoint trees into one structure, and on uncouple it splits
  again.** That is dynamic re-parenting / a cross-link by another name. The body is
  no longer a fixed tree; it is a graph whose edges appear and vanish.

- **Move 2 — a shared contact node.** Insert a "contact" part that is a child of
  *both* `A.member` and `B.orifice`. Fluid flows member→contact→orifice by two
  ordinary local fluxes. But a node with two parents is **a DAG, not a tree.** Same
  concession, dressed differently.

- **Move 3 — refuse, route through environment.** Keep both trees pristine; the act
  deposits efflux into `A.member`'s own "spill" metadata, and… it has nowhere local
  to go. To reach B it must pass through a shared world/field that *all* parts can
  read — which violates "no reads beyond the 1-ball" even harder than a cross-link
  does. A global environment field is *less* local than one cross-link.

So the cellular frame **cannot host coupling while remaining a strict tree.** Its
best move (1) is to redefine coupling as "a local interaction at a contact point" —
which is exactly the assigned framing — but only by *manufacturing the adjacency*,
i.e. conceding the cross-link the frame's strictness was supposed to forbid. The
frame does not avoid the cross-link; it **localizes** it (one edge at the contact,
not a global pointer graph) and pays for it with a no-longer-static topology.

This is, notably, *more* honest than B3's "scope-correct relation in the scene log":
B3 keeps the trees pristine but smuggles the cross-body dependency into a parent-
scope row that a consumer reads over *both* bodies — a non-local read. The cellular
frame makes the dependency a single physical edge with purely local flux. The
adversarial doc's B.1 bite (cross-body flow is a per-tick mutual lockstep barrier)
still lands either way: once the contact edge exists, advancing A.member's `fluid`
needs B.orifice's current state and vice-versa, so the two bodies must step in
lockstep for the coupling's life. The cellular frame doesn't escape the lockstep — it
just makes its locus a single edge instead of a scene-scoped integral. Determinism
holds on a *fused* timeline; "portable independent body" does not. Same wall.

---

## 5. The honest failure points — what this frame CANNOT express cleanly

1. **Global-and-synchronous influence comes out laggy and spatial.** Any effect that
   is conceptually "all parts feel the same value *now*" — a whole-body hormone wash,
   a uniform arousal level, an environmental temperature — is misrepresented as a
   wavefront sweeping the tree over O(diameter) ticks. Latency is not the worst of
   it; the **shape** is wrong: parts respond in topological order, near-source first.
   For emergent patterning that's the feature; for a coordinated transformation it's
   a bug the frame cannot switch off.

2. **It contradicts the decision doc's "whole-transformation control unit."** The
   doc's `[REASONED]` position is that a transformation shares **one control variable**
   that every part reads with a per-part offset — i.e. a **global** scalar every part
   sees the same tick. Strict locality **cannot deliver a shared scalar to all parts
   in one tick**; it can only diffuse it over many. So the cellular frame is in direct
   tension with the control-unit model: you cannot have both "no part reads beyond its
   neighbor" and "every part reads the one shared progress this tick." One of them
   must give. (The frame's rebuttal — "the control variable is itself just a field
   that diffuses" — produces a transformation whose parts visibly start at different
   ticks by *distance*, not by authored offset. That's a different, worse, semantics.)

3. **Aggregate / quantifier predicates are inexpressible.** "Grow proportional to
   total body mass," "stop when *any* part is fully transformed," "balance fluid
   across *all* limbs" are global reductions. The frame can only approximate them with
   a sum/argmax **diffused up the tree over ticks**, which lags and, for a moving
   target, never converges to the true global value. Conservation laws that are
   genuinely global (total blood volume) are only as good as the unenforced flux
   discipline (§3).

4. **Bilateral symmetry is 2-tick and order-fragile.** Symmetric paired parts (two
   arms, two breasts) coordinate only through their shared parent, so symmetric growth
   has an inherent 2-tick delay and, under in-place evaluation, a left/right bias from
   sweep order. A body's most basic expectation — paired parts match — is the
   awkward case.

5. **Non-tree contact in general is unrepresentable without the same concession as
   coupling.** Two thighs touching, a tail wrapping a leg, a hand resting on a belly —
   all are *graph* adjacencies the attachment **tree** simply does not contain. Any
   transformation that should respond to skin-to-skin contact (warmth spreading, a
   transferred texture) needs the §4 contact-edge move. Contact is intrinsically
   graph-shaped; the tree is the wrong substrate for it, and strict locality is what
   makes that undeniable.

6. **In-place evaluation reintroduces an order-dependence the frame was meant to
   kill.** Without the previous-state buffer (§1.1), every claim of symmetry and
   conservation degrades to "deterministic but sweep-biased." Determinism survives;
   *correctness* of the physics does not.

---

## 6. The frame's strongest card — it dissolves the adversarial doc's blind spot

The adversarial pass identified ONE shared fatal blind spot across all six prior
frames: they are **DAG-shaped answers to cycle-shaped problems** — same-property
contention, cross-body flow, and self-responsive hormones are all *same-tick mutual
dependencies* with no pinned evaluation order, no guaranteed fixpoint, possibly
oscillating.

**The cellular frame is the one frame with no same-tick cycle to pin.** Every
cross-part dependency is, by the rule, a *neighbor read realized next tick*. The
loop `M → part → hormone → part` is not a within-tick fixpoint; it is unrolled across
ticks by construction. Two transitions fighting over one property on *different*
parts never collide, because they touch different cells; even on the *same* part they
are an ordered local fold over that cell only (the decision doc's settled rule),
needing no global arbitration. There is no "which body samples the other first"
because neither samples the other within a tick — they exchange across an edge, next
tick. The cellular frame is **the native form of the temporal-recurrence answer** the
decision doc already settled on ("apparent cycles are temporal feedback loops resolved
across ticks"). It is, in a real sense, the *only* one of the frames that takes that
settled determinism rule literally for **spatial** dependencies too, not just
temporal ones.

**But** — and this is the closing honesty — that win is **exactly** the §1.1 buffer
tension. "No same-tick cycle" is true only if neighbor reads see the *previous* tick
(Jacobi). Under the prompt's literal "in-place, no buffer" constraint, the
neighborhood you read is half-updated, and order-dependence sneaks the cycle back in
through the sweep. So the frame's single best property and its single worst
constraint are the same coin. Resolve §1.1 toward the decision doc (keep a
previous-tick read for fields) and the cellular frame becomes the cleanest determinism
story in the whole set. Resolve it toward the prompt's "no buffer" and the frame keeps
its serializability but forfeits symmetry and its cycle-freedom claim.

---

## 7. Does this keep the body a strict tree? No.

The frame **forces the tree question into the open and answers "no, you need a
graph."** Three independent pressures each demand a non-tree edge:

- **Coupling** (§4) needs a cross-body contact edge (or a two-parent contact node /
  a global field that is even less local). There is no strict-tree expression of it.
- **Non-tree contact** (§5.5) — touching parts that are not parent/child — is a graph
  adjacency the tree lacks, for *intra*-body cases too.
- **Conservation** (§3) needs neighbor-writes, which are fine within the tree, but the
  moment a contact edge exists they cross bodies, fusing timelines (§4).

The honest verdict: strict locality is a *beautiful* rule for **fields on a fixed
tree** and the *correct* substrate for emergent/morphogenetic transformation and for
dissolving same-tick cycles — but the body is not a fixed tree the moment two parts
*interact by contact* rather than by attachment. The frame cannot be both
**strict-local** and **strict-tree**: contact is intrinsically a graph edge, and
locality's only way to host it is to *create* that edge locally. So the frame's own
logic converts "the body is a tree" into "the body is a tree of attachments plus a
dynamic, sparse set of contact edges, and a transition's neighborhood is the 1-ball
in *that* graph." That is a graph with cross-links — just **local, sparse, physical**
cross-links instead of arbitrary global pointers. Which is the most defensible thing
the frame discovers: not "no cross-links," but "**every cross-link is an edge you can
flux across locally, never a name you read across globally.**"

---

## 8. Net

The rule: a transition reads only the closed 1-ball around its host (self + parent +
direct children) and writes neighbors only via antisymmetric edge-flux; all longer
range is propagation over ticks. It **holds cleanly** for hormone-as-diffusing-field
and for morphogenetic/patterning transformation, and it is the **only** frame that
natively kills the adversarial doc's same-tick-cycle blind spot — *provided* it reads
the previous tick (which the decision doc wants but the prompt's "no buffer" forbids:
the central tension). It **fails** to express global-synchronous influence without
wrong spatial lag (colliding head-on with the settled "one shared control variable"
model), fails on aggregate/quantifier predicates, and **cannot host coupling or
non-tree contact at all without manufacturing the very cross-link it forbids** —
localizing it, not avoiding it. Decisive weakness: **coupling/contact is intrinsically
a non-tree graph edge**, so the frame cannot remain both strict-local and strict-tree;
pushed to its limit it concedes a sparse dynamic contact graph and a fused two-body
timeline, exactly the wall every other frame also hits.
