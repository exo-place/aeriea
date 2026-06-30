# Cross-part access — the identity/graph frame (bite the bullet)

Status: **Adversarial-in-good-faith reasoning artifact for ONE open substrate
question: how does a transition influence/read state beyond its host part?**
Assigned frame: argue that the anti-blessing instinct overreaches here, that
cross-references genuinely require stable serializable part identity, and that
this forces (or strongly favors) something graph-shaped. Not a decision. The job
is the strongest *honest* case AND the tightest possible minimization of what
gets blessed.

Grounding read: `docs/decisions/body-transformation-substrate.md`,
`docs/artifacts/substrate-reasoning/{B1-edge-set,adversarial}.md`.

A note that reframes everything below: the SETTLED doc *already* says "A body is
a graph of generic segments" and "Stable part identity (body id + segment id) so
external systems can reference parts," and the coupling section lists "stable
identity + queryability" as a substrate guarantee. The prompt handed me the
constraint as "Body = a TREE … blesses NOTHING semantic and guarantees NO
metadata." So my frame is not fighting the doc — it is reading the doc's own
settled commitment back to it and showing that the commitment is *load-bearing
and irreducible*, not an incidental convenience. Where the two disagree, the
purer "tree, no identity" reading is the thinner one, and this artifact is the
argument for why.

---

## 1. The smallest thing that must be blessed, and why it is irreducible

### 1.1 The blessing, stated as tightly as it goes

> **Every part carries a stable, opaque, serializable *handle* — a value, not a
> pointer. The runtime owns a keyed lookup `handle → part`, scoped to a body, so
> resolution is a table read the runtime performs. Handles are allocated by an
> append-only per-body counter and are *never reused*: a removed part's handle
> stays burned, so a reference to a gone part resolves to a detectable *dead*,
> never silently aliases onto a different part. Resolution returns part-or-nil
> and nothing else.**

That is the entire blessing. Concretely a handle is `(BodyId, SegmentId)` (B1's
`PartRef`), both opaque allocated ids.

What is deliberately **NOT** blessed, to keep this minimal:

- No semantics on the handle. It is not "arm" or "parent" or "producer"; it is
  an uninterpreted name.
- No liveness *guarantee*. Resolve may return nil. The substrate promises the
  lookup, not the existence.
- No metadata guarantee on the resolved part (unchanged from the existing rule).
- No blessed *relationship type*. "Resolve this handle" is the only operation.
  There is no blessed "parent-of", "produces", "couples-with" — those, if they
  exist, are uninterpreted edges *built out of* handles (§2).
- No blessed mutable global. The lookup table is not separate authoritative
  state; it is an index *reconstructable from the parts themselves* (each part
  knows its own id), so nothing new is serialized (§3).

### 1.2 Why this is irreducible — the elimination argument

A transition must sometimes read or write state beyond its host (the worked
cases in §5 show three independent reasons it must). Whatever it uses to *name*
the other part has to satisfy four constraints simultaneously, all of which are
already SETTLED elsewhere in the substrate:

1. **Serializable with no live pointers** (determinism rule: "must serialize
   with no live pointers, no whole-world snapshot").
2. **Stable under in-place mutation** of either part (transform-in-place is a
   primitive; the reference must survive its target being mutated).
3. **Stable under structural change** — add/remove are primitives, and removal +
   reversibility mean the structure is reindexed over time.
4. **Structure-independent**, because some references (coupling, portal,
   diffuse production) are explicitly *not* along the attachment backbone.

Now eliminate every candidate naming scheme against those four:

- **A raw pointer / live reference** fails (1) outright — cannot serialize.
- **An array index into the part list** fails (3): add/remove renumbers it; after
  one removal it names a *different* part. Silent aliasing is the worst failure
  (it resolves, wrongly).
- **A positional / structural path** ("third child of root", "my parent",
  "ovary under torso") fails (2) and (3): the path that addressed a part at
  creation no longer reaches it after the very transforms the system exists to
  perform move, re-parent, split, or retag that part. A path is stable only in a
  frozen tree, and this tree is never frozen.
- **A content hash / property-derived key** ("the part tagged kind:ovary") fails
  (2) catastrophically: transformation *changes content*, so the key changes
  out from under the reference; and it fails uniqueness (two ovaries).
- **An opaque allocated id with a runtime-owned lookup** satisfies all four by
  construction: it is a value (1), it is independent of the part's content (2)
  and of its position (3, 4), and burn-on-remove makes (3)'s dangling case
  *detectable* rather than silently aliased.

By elimination, the opaque-id-plus-lookup is not *a* design choice among
several — it is the *only* member of the candidate set that meets constraints
the substrate has already settled. That is what "irreducible" means here: drop
it and you must drop one of the four settled constraints instead.

### 1.3 The decisive move: a tree already blesses exactly this

The anti-blessing instinct says "a tree blesses nothing; identity is the graph's
new tax." That is false, and seeing why dissolves the whole objection.

A tree's parent/child link **is** a reference from one part to another. The doc
makes it heavier, not lighter: "attachments" are *one blessed concept* carrying
position, and N siblings "differ by their attachment position." So the substrate
*already* blesses a structural relation and stores it. The only question is how
that relation is *named* once the tree is mutable, serializable, and
deterministic — and the four constraints in §1.2 apply to the parent link with
equal force. A parent link that survives in-place mutation, add/remove, and
serialization-without-pointers is, when you implement it honestly, *already* "a
handle resolved by a runtime-owned lookup." You cannot have a mutable
serializable deterministic tree whose links are *not* stable identities; "the
parent of X" has to keep meaning the same node after X's siblings are removed and
the list reindexed, and only a burned id does that.

So the blessing in §1.1 is **not different in kind** from the tree's own
parent/child link. It is the *same mechanism* — an opaque reference the runtime
resolves — with the single restriction lifted that says "the only legal direction
to point is parentward." The graph's extra edges reuse the identity the tree was
already forced to bless. "No blessing" is therefore incoherent: even a tree
blesses structural adjacency, and adjacency over a mutable serializable structure
*is* stable identity. The honest debate is never "bless identity or not" — the
tree already did — it is "how many directions may a blessed reference point," and
the answer the worked cases force is: more than one.

---

## 2. Tree → graph: required, or optional sugar over identity?

The word "graph" conflates two separable promotions. Keep them apart and the
honest line is sharp.

- **(a) Backbone promotion** — does *structural containment* stay a tree (each
  part has exactly one attachment-parent) or become a DAG/graph (a part may have
  several structural parents — a fused organ, a conjoined segment)?
- **(b) Reference fabric** — is there a *second* relation of edges over handles,
  off the backbone, connecting parts that are not in a parent/child line
  (couplings, producer→field, control-op→target)?

**(b) is forced. (a) is not.**

The cross-references in §5 are exactly non-backbone edges. They force the
*existence* of a reference layer distinct from the attachment hierarchy: a set of
(handle, handle, opaque-meta) tuples, where the handles are already blessed
(§1) and the meta bag obeys the existing "substrate interprets nothing" rule.
B1's `Coupling` is precisely this tuple living at world scope. So the body is no
longer *only* a tree — it is **a tree backbone over identified parts, plus an
uninterpreted edge-set over identities**. That union is "a graph" only in the
trivial sense that any structure with cross-links is.

But (a) — giving a *part* two structural parents — is **not** forced by anything
in the worked cases. Every cross-reference is satisfied by an *edge in the
reference fabric*, not by a part needing two containment-parents. Keeping the
backbone a strict tree keeps the clean properties the whole substrate leans on:
unambiguous whole-body traversal, unambiguous "move this subtree", unambiguous
rendering parent. Promoting the backbone to a graph should be *resisted* until an
independent need appears (a genuinely two-parented part), and that need has not
appeared. The doc's leap to "a body is a graph of generic segments" is, by this
analysis, **stronger than its evidence**: the evidence forces "a tree of
identified parts plus an edge-set," and the minimal blessing in §1 buys exactly
the edges without dissolving the backbone.

So the precise answer: **stable identity is forced; a non-tree edge-set over
identities is forced; backbone graph-promotion is optional sugar that should be
declined until a two-parent case earns it.** The edge-set is not "blessing the
graph" — it is *using* the identity the tree already blessed, pointed sideways.

A sharper statement of where the line sits: the substrate blesses *handles and
their resolution*. It does **not** bless the edge-set as a typed structure —
edges are just data made of handles, the same way couplings are "metadata
maintained by external systems" (SETTLED). The substrate owns the *naming
substrate* (identity + lookup) and nothing about what the names are used to wire
together. That is the smallest thing that still makes every worked case
expressible.

---

## 3. Serialization and determinism

Identity must not introduce nondeterminism or a live-pointer save. It does not.

**Allocation is logged, not RNG.** Adding a part is already an action in the log.
Handle allocation is "take the body's next id from an append-only counter"; the
counter is body state, itself `seed + log`-derived. Replaying the log allocates
*the same handles in the same order*, bit-for-bit. No nondeterministic allocator,
no address-based identity — this is the one detail that makes opaque ids
compatible with "determinism = seed + action log."

**Serialization stores values, rebuilds the index.** Handles serialize as plain
integers / `(BodyId, SegmentId)` pairs — data, no closures, no pointers. The
`handle → part` lookup is *not* serialized as authoritative state; each part
carries its own id, so the table is rebuilt by indexing the part set on load.
That is why §1.1 can claim "nothing new is serialized": the blessing adds a field
to each part (its id) and an *ephemeral* index, not a persisted global registry.

**Cross-body refs.** Couplings store `(BodyId, SegmentId)` pairs at world scope
(B1). Resolution asks the named body. Loading a partial world (one body absent)
leaves dangling edges that resolve to nil and are reaped — the model is honest
that a coupling is a world-fact, not a body-fact. Identity does *not* add to the
cross-body determinism cost: the adversarial pass already established that a live
coupling fuses the two bodies into one lockstep timeline for its duration. That
fusion is a netcode commitment independent of how parts are named. Identity is
simply *what makes the fused derivation expressible at all* — without a
serializable name for "B's orifice as seen from A's peer," the fused integral has
no referent.

**Burn + tombstone make reverse coherent.** The per-body counter only increments;
a removed part's id stays burned. For reversibility (a SETTLED need), a removed
part is retained as a tombstone keyed by its still-burned id; reversing the
removal re-installs the *same* id, so any edge that named it resolves again.
This is the deepest reason identity is irreducible: "restore the part that was
here" is meaningless without a stable name for "the part that was here." Stable
identity is the precondition of reverse-of-remove, which the substrate already
promises. (The reverse-horizon / GC tension from the adversarial pass is real but
orthogonal — it bounds *how long* tombstones live, not *whether* they need
stable ids.)

---

## 4. The strongest objection to this frame, and the rebuttal

### 4.1 The purist's best shot

"You have smuggled in an object system and then minimized the receipt. A
runtime-owned lookup table is a global mutable registry; burn/tombstone is a
lifecycle; allocation policy and 'liveness' are semantics. That is not 'blesses
almost nothing.' And you did not even need it. A pure tree needs *no* identity,
because **every part is its position**: a transition references `self` (its host)
and at most `my parent` (one structural hop), both reachable without any handle.
Diffuse signals are a *field read by position*, not a part-to-part edge. Coupling
the SETTLED doc has already exiled to external systems. So every reference that
actually survives is backbone-local, which the tree gives for free. You promoted
to a graph to solve problems that either do not cross the host boundary or are
not the substrate's problem."

This is the genuinely strong version and it must be met on each worked case, not
waved at.

### 4.2 Rebuttal — the purist's position holds only if every cross-host read is one backbone hop or a positionless field, and it isn't

Run it against the three worked cases (full treatment in §5):

- **Endogenous hormone.** Grant the purist the *exogenous* case completely: a
  hormone that is a diffuse scalar *field at body scope* is read as a scoped
  variable, no part identity needed — and note the purist has *already conceded
  identity at the body grain*, since "body scope" presupposes a `BodyId`, which
  is a blessed name. But the transformation sandbox's whole point is *endogenous*
  signals: an ovary segment secretes estrogen; remove the ovary and production
  stops; arousal rises *because this part grew*. The field must now sum over a
  *set of producer parts*, and "which parts produce, as they are added and
  removed" is a reference from field to parts that survives those parts mutating —
  identity again. The feedback loop `part → field → part` must attribute the
  field to a part. Positionless-field works for the boring case and breaks for
  the case the system exists to model.

- **Pause-most-recent (entirely within one body, no coupling, no graph).** A
  control op must *name* the transition it pauses. A transition is stored as
  metadata on its host part; "most recent" resolves against the log to a target
  `(host-handle, transition-key)`. The positional naming the purist offers fails
  *immediately and on its own turf*: between starting the transition 200 ticks
  ago and pausing it now, a later transform may have moved, re-parented, split,
  or retagged the host — the path that addressed it at creation no longer reaches
  it. Only a stable handle survives "pause the thing I started, on a part that has
  since been transformed." This is the cleanest refutation: it needs no second
  body and no second structural parent, yet "every part is its position" is
  already false, because the positions are invalidated *by the very mutations the
  substrate is built to perform*. Control and reversibility are precisely the
  operations that must address parts *across* that invalidation.

- **Coupling.** Even granting exile to external systems, the SETTLED text says
  the substrate "provides generic bodies + stable identity + queryability" *to
  those very systems* — i.e. the doc itself blesses identity for exactly this
  reason. The purist's "no identity" line therefore contradicts the settled doc,
  not just this frame.

So "every part is its position" is true only in a frozen tree, and this tree is
never frozen. The moment mutation, control, and reversibility enter — all
SETTLED — position stops being identity and a stable handle is the only thing
left standing.

### 4.3 Conceding the real cost, and where the honest line lands

The purist lands one true hit: a runtime-owned lookup *is* more machinery than
"nothing," and calling it "almost nothing" must be earned by ruthless
minimization, not asserted. So the line is drawn exactly there:

- **Bless:** opaque per-part handle (logged allocation, burned on remove) +
  runtime `handle → part` resolution returning part-or-nil. Reconstructable
  index, not persisted registry.
- **Do *not* bless:** any structural graph backbone (keep the tree); any typed
  edge or relationship ("parent", "produces", "couples"); any liveness guarantee
  beyond resolve-or-nil; any semantics on the handle; any persisted global table.

Under that line the body is "a tree of identified parts plus an uninterpreted
edge-set over identities." Identity is forced and irreducible; the *graph* — in
the sense of backbone promotion — is *not* forced. The anti-blessing instinct is
right about almost everything and wrong about exactly one thing: it reads "few
references" as "no blessing," when the tree it defends had already blessed the
identical mechanism the first time a parent link had to survive a removal.

---

## 5. Worked cases

### 5.1 Hormone read

*Exogenous (purist wins):* `estrogen` is a body-scope scalar driven by its own
logged timeline. A transition expression reads `body.estrogen` as a scoped
variable. No part identity. Replays as a pure function of two replayable scalars
(this is the case the adversarial pass confirmed survives).

*Endogenous (identity forced):* `estrogen(t) = Σ over producer parts p of
secretion(p)`. The producer set is named by handles; add an ovary → its handle
enters the sum; remove it → its handle is burned and drops out, detectably. The
feedback case `arousal ↑ because breast volume ↑` is a `part → field → part`
loop; the field's contribution must be attributed to a *named* part so that
removing the part removes its contribution. Determinism: the loop is a temporal
feedback resolved by the previous-tick recurrence (SETTLED) — handles change
nothing about the recurrence; they only make "which parts feed the field"
expressible across add/remove. This is the case that defeats "diffuse field by
position."

### 5.2 Coupling (cross-body)

`Coupling{a:(P1,member), b:(P2,orifice), seal.tightness, meta}` at world scope
(B1). The two `PartRef`s are handles; resolution asks each named body. A consumer
reads both endpoints' fluid metadata + tightness and applies its own transfer
model, writing results back as expression-driven mutations. Determinism: the live
coupling fuses P1 and P2 into one lockstep timeline for its duration (adversarial
B.1) — a netcode commitment, *independent of* identity. Identity is what lets the
fused derivation *name* the two parts across serialization and mutation; without
it the per-tick mutual integral has no referent. Mid-coupling removal: the edge's
ref resolves to a burned/dead handle (detectable, never silently re-aliased) and
is lazily reaped. Reverse-of-remove re-installs the same burned id, so a
faithful reverse can re-establish the edge — though, per adversarial B.2, the
re-establishment must be a *forward* world-scope action, not a body-local
un-tombstone. Identity is the precondition; scope discipline is the separate
constraint.

### 5.3 Pause-most-recent

A control unit shares one self-referential progress variable (REASONED). "Pause
the most recent transition" resolves, against the log, to a target
`(host-handle, transition-key)`, then sets that unit's direction to frozen. The
handle is essential precisely because, between start and pause, transforms may
have moved/split/retagged the host: positional addressing is invalidated by the
intervening mutations, the stable handle is not. Determinism: pause is a log
action over the named unit; replay reproduces the same target because handle
allocation is itself logged (§3). This case needs no second body and no backbone
graph — it shows identity is forced *inside a single tree* the moment control and
reversibility act across mutation.

---

## 6. One-paragraph synthesis

The minimal thing that must be blessed is a stable opaque per-part *handle* that
serializes as a value, allocated by a logged append-only counter, never reused
(burned on removal), resolved by a runtime-owned `handle → part` lookup that
returns part-or-nil and guarantees nothing else. It is irreducible because a
cross-part reference must simultaneously serialize without live pointers and stay
stable under in-place mutation, add/remove, and structural transformation — and
opaque-id-plus-lookup is the *only* candidate that meets all four constraints the
substrate has already settled. It is not different in kind from the tree's own
parent/child link: a mutable serializable deterministic tree had to bless that
identical mechanism the first time a parent link survived a removal, so "no
blessing" is incoherent — the tree blesses structural adjacency, and adjacency
over a mutable structure *is* stable identity. Promoting the structural *backbone*
from tree to graph is **not** forced; what is forced is a second, uninterpreted
*edge-set over identities* alongside a backbone that should stay a tree until a
genuinely two-parented part earns the promotion. The honest line: bless handles
and their resolution; bless no typed edge, no liveness guarantee, no persisted
registry, no backbone graph.
