# Cross-access synthesis — intra-body, after scope correction

Status: **Adversarial synthesis of four decorrelated frames (locality, capability,
minimal, identity) against `body-transformation-substrate.md`.** Reasoning artifact,
not a decision. Resolves the one question — *how does a transition read/influence
state beyond its host part, within a single body, and does that force tree→graph
and/or a blessed stable part identity?* — under three hard scope corrections that
override what the four frames assumed:

1. **Cross-body coupling is OUT.** Coupling is metadata in external systems; the
   substrate never represents a cross-body edge; the fused-timeline cost lives
   outside. Every frame that named cross-body coupling as its decisive wall
   (locality §4/§7, capability §3) had that wall **voided** and is re-judged with
   cross-body deleted.
2. **Topology-independence is hard pass/fail.** A selector that names a structural
   slot or assumes a canonical topology FAILS (this kills capability's
   `DOWN@pos=p` routes and any "third child of root" path). A relative structural
   relation that exists on *every* tree (`parent`/ancestor-walk) and content/
   predicate selection both PASS.
3. **Co-location holds.** A transition is stored on the part it transforms; its
   operand is `self`; it rides its host across moves. "self" never needs tracking.
   Identity is *potentially* needed only when a transition must follow some OTHER
   specific part across structural moves within the body.

---

## 1. The synthesized model for intra-body cross-access

Three mechanisms, ordered by preference. The bias is to bless nothing; each
mechanism reads structure or metadata the substrate already stores.

### M1 — Ancestor read + pull (hierarchical influence)
A transition reads up its **ancestor chain** via a relative `parent` hop (optionally
walking up until a predicate matches). `parent` is topology-independent: "my parent"
is well-defined on any tree without a canonical shape, so it survives correction 2.
Hierarchical influence (ancestor drives descendant) is a **pull**: the descendant
reads the ancestor and scales *itself*; no part writes another part. Diffuse/regional
signals are modeled as a **field on a containing ancestor** (root, or a region part),
read by every descendant beneath it — this is exactly the `dynamical-transformation.md`
*driver* model re-described ("diffuse" = "readable by descendants via ancestor
access"). Evaluated **top-down (pre-order, parents before children)**, M1 is acyclic
by construction and **buffer-free**: every ancestor read sees an already-advanced
current-tick value, no whole-world snapshot, no per-quantity recurrence. This covers
the large majority of cross-part influence with zero identity, zero buffer, tree
intact.

### M2 — Predicate / content selection (set or individual by metadata)
"The part(s) whose metadata satisfies predicate P." Matching is author-expression
evaluation over the metadata bag the substrate already exposes; it is
**topology-independent** (works on non-standard, already-transformed, non-humanoid
bodies — correction 2's only passing selector for an arbitrary target). Used for:
selecting by role/kind/tag; **aggregating over a producer set** (`Σ secretion over
parts where producer`); finding a control-unit's members (`parts where control_unit
== u`). Whether the substrate ships a blessed scan/match helper or the author
composes it from tree enumeration is a secondary representation choice — graph-matching
helpers are already `[SETTLED]` as "substrate MAY provide."

### M3 — Author-stamped opaque id, found by predicate (individual across moves)
The one case M1/M2 do not yet cover: a transition that must follow **one specific
individual** part across structural moves *and* across transformations that change
its content. The author stamps a **reserved, uninterpreted, stable key** the
transformation rules never touch (e.g. `_uid`), allocated **deterministically from
the action log** (the log already gives a per-event ordinal — no RNG, no collision,
no substrate primitive). The reference is M2 specialized: `find the part where _uid
== k`. This:

- **rides the part across moves** — metadata moves with the part; the scan finds it
  wherever it now hangs (structure-independent);
- **survives content transformation** — the key is reserved, *not* semantic, so the
  transforms that rewrite `kind`/`material` leave it alone (this defeats the
  identity frame's "content-hash key changes out from under you" objection — an
  author-stamped uid is not content);
- **serializes as plain data**, no live pointer;
- is **dangling-detectable** — no match resolves to nil, never silently re-aliases
  (author non-reuse of uids, again log-driven).

This is identity **without any substrate blessing**: a value in a bag, resolved by
the predicate machinery M2 already has.

### Determinism across the three
- **M1 hierarchical pull:** top-down eval, current-tick reads, **no buffer**.
- **M2/M3 lateral, upward-aggregation, or feedback** (descendant→ancestor,
  sibling↔sibling, field↔producer): a same-tick cycle, resolved by the **settled
  previous-tick temporal recurrence** — the dependent quantity reads the other
  quantity's *previous-tick* value. This recurrence state is **per-quantity**,
  carried as ordinary serializable state; it is **not** the forbidden whole-world
  snapshot. See §2.

---

## 2. Tension A — does upward-only + pull avoid the buffer? (resolved)

Minimal says upward-only read + descendants-pull + top-down eval is acyclic and
buffer-free. Locality says cross-part influence needs a Jacobi (previous-tick) read =
a buffer. **Both are right within their scope; they describe different influence
directions, and the apparent contradiction dissolves once two things called "buffer"
are separated.**

Take the named case — *a hormone produced in part X affecting growth in part Y
elsewhere* — and split it by how the hormone is modeled:

- **Field-from-above (recommended).** The hormone is a scalar on a **common
  ancestor**, advanced by an exogenous logged driver or the ancestor's own autonomous
  transition — i.e. a body/region level that rises over a timeline, *not* a live
  function of X's instantaneous state. Y pulls it via M1; top-down eval hands Y the
  current-tick value. **Genuinely buffer-free, identity-free, tree intact.** This is
  the majority of real "hormone" intent and Minimal is exactly right for it.

- **Endogenous-from-below.** The level must be a live function of X's current
  production (`estrogen = Σ secretion(producers)`), and the producers are not
  ancestors of the field node. Now the field must **aggregate downward** over a
  producer set — a descendant read / same-tick cycle. Upward-only-pull **cannot**
  express this; Locality is right that a previous-tick read is required. But that
  read is the **settled `[SETTLED]` temporal recurrence** (the field reads last
  tick's producer states), a bounded **per-quantity** previous value — **not** a
  whole-world buffer.

So: `parent`-only + pull avoids the buffer **only** for field-from-above. The cases
it cannot express are exactly the ones Locality says need a previous-tick read, and
that read is the recurrence the substrate already blessed, never a new forbidden
buffer. The reconciliation of the prompt's "no previous-state buffer" with the doc's
"read the previous tick's state": **"no buffer" = no whole-world snapshot held in
parallel** (the prompt also restates this as "no whole-world snapshot"); it does
**not** forbid a single quantity carrying its own previous value for a temporal
recurrence. Whole-world snapshot: forbidden, never needed. Per-quantity recurrence
state: settled, needed for the cyclic subset.

**Consequence for the model:** pure upward-only (Minimal's single primitive) is
**too weak** as the only navigation — it cannot express endogenous production,
sibling symmetry as mutual influence, or any aggregation, all of which are central
to a transformation sandbox. The navigation the substrate exposes must be broad
enough to **enumerate/match descendants** (M2), not just hop to the parent. That is
the one real concession against Minimal, and it is what makes M2/M3 possible.

---

## 3. Tension B — is a blessed opaque handle forced? (No.)

The identity frame's strongest *intra-body* cases, re-judged with cross-body deleted:

- **"Pause the most-recent transition."** With co-location (correction 3) the
  transition rides its host; you never navigate *to* it across moves. The control
  unit is addressed by author metadata (a `control_unit` tag found by M2, or a
  field on a host read by M1); "most recent" is author-stamped order from the log
  (the substrate blesses no provenance). The handle is **not** needed.

- **"Follow that specific gland wherever it moves, even after it is transformed."**
  This is the genuine individual-tracking case, and M3 covers it: an author-stamped
  reserved `_uid`, found by predicate. The identity frame's elimination argument
  (raw pointer fails serialization; array index renumbers; structural path breaks
  under moves; content-hash changes under transformation) eliminates every candidate
  **except opaque-id-plus-resolution** — but an **author-stamped opaque id in the
  metadata bag, resolved by predicate scan, IS an opaque-id-plus-resolution**. It
  meets all four of the frame's own constraints (serializable value; stable under
  in-place mutation because the key is reserved; stable under add/remove because it
  rides the part; structure-independent because the scan ignores position). The
  frame proved identity is irreducible; it did **not** prove the identity must be
  *substrate-blessed* rather than author-stamped.

**The exact minimal case that cannot be done without a substrate-blessed handle:
there is none, after the scope corrections.** A blessed handle (logged-counter
allocation, burned-on-remove, runtime `handle→part` index, resolve-or-nil) buys
exactly two things over author-stamped-uid + predicate:

1. **O(1) resolution** vs an O(body) predicate scan per read (which, summed over many
   transitions per tick, is O(body × transitions)). Solvable author-side by an
   **author-maintained incremental index** updated at add/remove (Minimal §2) — at
   the cost of author discipline (the index can desync).
2. **Guaranteed uniqueness + non-reuse + dangling-detection.** Achievable author-side
   by allocating uids from the log and never reusing — at the cost of author
   discipline (a careless author can collide or reuse).

Both are **ergonomics/perf/safety**, not capability. **Nothing intra-body forces the
blessing.** Bias to bless nothing → bless nothing; identity is author metadata.
(Note the settled doc already blesses an *external-facing* `(body id, segment id)`
"so external systems can reference parts." That is a **separate layer** (Minimal
§6.4), not the in-expression cross-access mechanism, and external systems are out of
scope for this question. Whether to expose that already-blessed external id to the
in-expression language is a convenience call, §6.)

---

## 4. Tension C — tree or graph? (The tree stands.)

With cross-body external, re-test every intra-body pressure the frames raised for a
**true second structural parent / backbone graph edge**:

- **Endogenous hormone / producer aggregation** — expressed as a field value
  (metadata) plus M2 predicate aggregation over producers. No second parent. Author
  data over the tree.
- **Follow a specific part** — M3 author-stamped id + predicate. No second parent.
- **Control-unit membership** — `control_unit == u` predicate, or descendants of a
  host read by M1. No second parent.
- **Intra-body non-tree contact** (a hand resting on the belly, a tail wrapping a
  leg, two thighs touching). This is the only remaining candidate. But it is the
  *same shape* as coupling — a **relation between two parts not in a parent/child
  line** — and the settled doc already exiles connectivity/coupling to **external
  systems as metadata**. Self-contact is intra-body coupling; it is author/external
  relation data, **not** a structural containment edge. The backbone is untouched.

**Verdict: nothing intra-body forces tree→graph.** The body backbone remains a
**single-parent tree**. Every "graph-like" relation (fields, producer sets, contact,
control-unit membership, "follow that part") is expressed as **author metadata —
predicates plus author-stamped ids — layered over the tree**, exactly as the identity
frame itself concluded ("an uninterpreted edge-set over identities is forced;
backbone graph-promotion is *not*"), and here even the edges are author data, not a
blessed edge-set. Single-parent is also what keeps M1's top-down evaluation acyclic
and buffer-free (§2); promoting the backbone would forfeit that. The **only** thing
that would force backbone promotion is a genuinely **two-structural-parented part**
(a fused organ, a conjoined segment) — and no worked intra-body transformation case
requires one. Park it: promote if and only if such a case appears.

This corrects the settled doc's "a body is a **graph** of generic segments," which is
**stronger than its evidence**: the evidence forces a *tree* of parts plus author
relation-metadata. Recommend the doc adopt Minimal's split — **"tree for dynamics,
graph (author relations) for connectivity"**: the navigation the expression language
walks is a single-parent tree; non-tree relations exist only as external/author
metadata never walked by per-tick evaluation.

---

## 5. What the substrate must bless (near-nothing)

Already exposed (unchanged): the single-parent attachment tree; per-part metadata
bags; authored expressions; deterministic evaluation order; the previous-tick
recurrence; log-derived ordinals (free, from determinism = seed + log).

**The one addition this question forces:** the expression language must be able to
**read other parts' metadata by navigating the tree it already stores** — at minimum
`parent` *and* child enumeration (enabling M2 predicate/subtree matching). Pure
upward-only is too weak (§2). This is **exposing existing structure to reads, not
blessing new semantics** — no new entity, no new stored state, no identity, no graph.

**Not forced, therefore not blessed** (bias to bless nothing):

- a part **handle / opaque-id resolution** — author-stamped uid + predicate covers
  every intra-body case (§3);
- any **graph backbone / second structural parent** (§4);
- any **typed edge or relationship** ("produces", "couples", "contacts") — author
  relation-metadata;
- any **liveness guarantee** beyond "predicate matches nothing → nil";
- any **provenance/order/time** primitive — author-stamped, log-derived.

So: bless tree reads (both directions) for the expression language; bless nothing
else for intra-body cross-access.

---

## 6. Residual decisions genuinely owed to the user

1. **Navigation breadth + the determinism reconciliation (needs sign-off, not a
   coin-flip).** The model requires navigation broader than upward-only — it must
   enumerate/match descendants (M2), without which endogenous hormones, sibling
   symmetry, and aggregation are inexpressible. That re-admits same-tick cyclic
   influence, resolved by the **settled per-quantity previous-tick recurrence**,
   which must be confirmed as *distinct from and not a violation of* the prompt's
   "no previous-state buffer" (= no whole-world snapshot). The user should confirm
   this reading; it reconciles Minimal's buffer-free claim with Locality's
   previous-tick requirement instead of choosing one.

2. **Bless a part handle, or keep identity author-level? (ergonomics vs. purity —
   the user's call.)** Strictly nothing forces a blessed handle; author-stamped uid
   + predicate (+ optional author-maintained index for O(1)) covers every intra-body
   individual-tracking case. But then *every* author who tracks an individual
   re-implements uid-stamping, deterministic allocation, non-reuse, and an index,
   and the failure modes (desync, reuse, silent re-alias) are subtle. Options:
   (a) bless the minimal handle (logged allocation, burned-on-remove,
   `handle→part` resolve-or-nil — the identity frame's tight form) as a shared
   convenience; (b) keep it author-level and ship graph-matching/index *helpers*
   instead; (c) expose the already-settled external `(body id, segment id)` to the
   in-expression language, making the marginal cost near-zero. (c) is the cheapest
   pragmatic path and tilts the call, but none of the three is *forced* — this is a
   genuine ergonomics/minimalism trade for the user, not a closure I should
   manufacture.

(Lower-order, foldable into #2: per-tick predicate-scan cost if neither a blessed
index nor an author index exists.)
