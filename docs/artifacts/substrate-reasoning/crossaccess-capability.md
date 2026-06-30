# Cross-access — Frame: object-capability / references-handed-at-creation

Status: **Substrate reasoning, one assigned frame of several. Not a decision.** A hostile,
self-adversarial pass on a single thesis, so the synthesis later has a sharp version of it to
weigh. Grounding read first: `body-transformation-substrate.md` (the SETTLED tree + transitions),
`dynamical-transformation.md` (driven-progress transitions, driver timeline, closed-form replay,
the deterministic on-read walk), `A2-shared-handle.md` and `B1-edge-set.md` (the
id-into-a-world-table answers this frame is the deliberate dual of), and `adversarial.md` (the
cyclic-same-tick blind spot, which I must not re-introduce).

The question: **how does a transition (metadata on its host part, operand = `self`) influence or
read state BEYOND its host — an ancestor, a sibling, a diffuse "hormone", another body?**

The frame's thesis, stated maximally: **a transition can reach ONLY what it was explicitly GIVEN
when it was spawned. It never discovers, looks up, scans, or names-into-a-store. The spawner — an
action that already holds the relevant parts in hand — wires the transition's reach into it at
creation.** Authority is what you hold, not what you can name. The whole job below is to find the
one serializable form of "a handed reach" that survives save/load and crosses ticks without being
(a) a live pointer or (b) a global id indexing a store — and then to break it.

Crucial substrate tightening I hold to (from the prompt, stricter than the existing docs): **the
substrate guarantees NO built-in id, time, order, or provenance.** Identity is an author-level
metadata pattern, not a substrate primitive. So "name-into-a-store keyed by id" is not merely
inelegant here — the id it would need is *not a thing the substrate provides*. That is what makes
this frame interesting and what makes its collapse sharp.

---

## 1. What a capability IS, as serialized data, and how it resolves with no store

Three candidate encodings of "a handed reach." I take all three seriously, then keep two and
fence the third.

### 1.1 Candidate A — copied value (a frozen capability)

The spawner reads the referent's value at creation and bakes the *number* into the transition's
own locals bag. Serializes trivially (it is already plain data in the bag); resolves at call time
with zero work (read your own local).

**This is a capability to a CONSTANT, not to live state.** It cannot track a referent that
changes. For "this growth depends on a fixed parameter captured at the start" (the dose at the
moment of injection, the target the spawner computed) it is exactly right and exactly free. For
"read my parent's *current* hormone each tick" it fails — it reads the spawn-instant value
forever. So: **necessary, sufficient only for genuinely-fixed inputs, and honest about it.** Most
of the established model's `from`/`to` snapshots and the spawner-computed `to.value` are already
this. It is not the interesting case; it is the floor.

### 1.2 Candidate B — captured relative structural path (the load-bearing answer)

The spawner, holding both `self` and the referent, computes the **route through the tree from
`self` to the referent** and bakes that route into the transition as data. The route is a
sequence of **edge-traversal steps**, each step naming a neighbor by the *one structural
discriminator the substrate blesses* — **attachment position** (per `body-transformation-substrate.md`:
"N sibling parts differ by their attachment position, not a shared tag"). Concretely:

```
reach = { steps: [ UP, DOWN@pos=p2, DOWN@pos=p7 ] }     # from self: to parent, then into
                                                        # the child at position p2, then p7
```

- `UP` = traverse the attachment `self` hangs from (a tree has exactly one parent edge, so `UP`
  is unambiguous with no id).
- `DOWN@pos=p` = descend into the child reached by the attachment at position `p` (position
  discriminates siblings deterministically; this is the substrate's own guarantee).

**Serialization:** pure data — a short list of `{UP}` / `{DOWN, pos}` tokens. No pointer, no id,
no store reference, no closure. It round-trips through JSON as integers exactly like every other
fixed-point field. **It is a function of the action log** (the spawner computed it from the tree
state at the spawn event, itself a function of the log), so it is replay-stable by construction.

**Resolution at call time:** start at `self`, follow the steps against the *current* tree. O(path
length) pointer-chasing through tree edges the walker already holds — **no scan, no store, no
snapshot.** The referent is whoever the route lands on now.

This is the genuine object-capability shape: the route can express **only what is reachable from
`self` by tree navigation**, and it carries its authority structurally — you cannot widen a route
into reach you weren't handed; a `DOWN@pos=p2` route gives you that subtree and nothing lateral to
it. The spawner attenuates by handing a *specific* route.

### 1.3 Candidate C — re-handed each tick by the walker (capability as ambient context, serialized as NOTHING)

The established model already evaluates transitions by a **deterministic walk** of the tree on
read (`dynamical-transformation.md` §5: lazy, derive-on-read, deterministic order). A DFS walk
*holds the ancestor chain on its stack* the moment it reaches a part. So for the most common
reach — **an ancestor** — the transition does not need to serialize anything at all: the walker
hands the live ancestor bags into the expression's evaluation context as `ancestors[...]`,
reconstructed fresh every tick from the walk. Siblings come almost as free (the parent, on the
stack, exposes its other children).

**Serialization of this capability: there is none.** Nothing persists between ticks but the tree
itself. The "reach" is a property of the deterministic walk, regenerated each evaluation. This is
the cleanest possible answer to "how does it survive save/load" — it does not need to, because it
was never stored. It is also automatically immune to live-pointer rot (no pointer is ever saved)
and to store drift (no store exists).

Its limit is exactly its strength: the walker hands you only what its walk *naturally holds* —
your ancestor chain, and through the parent, your siblings. It does **not** hold a distant cousin,
a part in a sibling subtree two hops over, or another body. For those, Candidate C is silent and
you must fall back to Candidate B (an explicit captured route) or fail.

### 1.4 The synthesis of this frame

A capability is, in order of preference:

1. **(C) ambient walk-context** for ancestor/sibling reach — serialized as nothing, regenerated
   by the deterministic walk. The default and the cleanest.
2. **(B) a captured relative route** (list of `UP`/`DOWN@pos`) for tree-reachable targets the walk
   does not naturally hand — serialized as plain data, resolved by re-walking from `self`.
3. **(A) a copied value** for genuinely-fixed parameters — serialized as a local, resolved by
   reading it.

All three are **store-free, id-free, snapshot-free, scan-free.** None is a live pointer. This is
the frame at its strongest: within one tree, cross-access needs no identity and no global table at
all — it falls out of tree structure plus the walk the substrate already runs.

---

## 2. Worked sketch — hormone-driven growth

"A diffuse hormone-like value drives growth across many parts." The frame's move is to **refuse to
model a hormone as a message between two specific parts** and instead model it as a **field on a
containing part, read by the free ancestor capability.** Three scopes:

**(a) Body-global hormone (estrogen across the whole body).** The value lives in the **root part's
bag** (`root.bag["estrogen"]`) — or, equivalently, on the driver timeline the established model
already hangs at body scope, which is itself "a field on the body." Every growth transition,
anywhere in the tree, reads it via Candidate C: the root is the *bottom of every walk's ancestor
stack*, so `ancestors.root.bag["estrogen"]` is handed in free, live, every tick. **Serialized
reach: none.** This is the established `driver` model re-described as a capability: a driver is a
field on a containing scope, and "diffuse" means "readable by descendants via ancestor-access."
Determinism is unchanged — the field is piecewise-constant on the timeline, the read is the same
closed-form §5 walk.

**(b) Regional hormone (a gland in the torso; nearby parts respond).** The emitter is a *cousin*
of the responders, not their ancestor — Candidate C cannot hand it. The frame's answer: the
spawner (the action that starts this regional effect, holding the gland and the responders in
hand) **hoists the value to their lowest common ancestor's bag** — write `torso.bag["chitin_signal"]`
— and the responders read it by ancestor-access (free again, because the LCA *is* on their walk
stack). The spawner is exactly the actor positioned to choose the containing scope, because it
holds all the parts. So "regional diffusion" becomes "a field on the smallest part that contains
the affected region," consumed by the free ancestor capability. **No part ever names another part;
they name a containing scope they already structurally sit inside.** This is the frame's best,
most physically-honest move: a hormone is a property of the *medium/region*, not a directed edge
between two cells.

**(c) Truly point-to-point (gland G must drive only part P, not P's siblings).** Here neither a
field nor the walk suffices; the spawner hands P a **Candidate-B route to G** (`UP, UP, DOWN@pos=k`).
P's growth expression resolves the route each tick and reads `G.bag["secretion"]` live. This works
— and is precisely the case that exposes the decisive weakness (§4): the route follows G's *slot*,
not G.

Growth itself is unchanged from `dynamical-transformation.md`: the hormone read is just another
driver term in the closed-form progress sum. The frame only changes *where the driver value lives
and how the transition reaches it* — and its claim is that (a)/(b) cover the overwhelming majority
with zero serialized reach and zero identity.

## 3. Worked sketch — coupling between two bodies

This is where the frame is forced to be honest, and it is the sharpest case.

Two bodies are **two separate trees** with **two separate walks** and (under the established
purist law) two independent serialization units. A Candidate-C walk over body B holds B's ancestor
stack and *nothing of A* — it physically cannot hand A's parts in. A Candidate-B route is rooted
at `self` and traverses only `self`'s own tree — `UP` from B's root has nowhere to go; **a
relative route cannot cross trees.** And Candidate A (copied value) gives only a stale snapshot,
which fails the live per-tick exchange a coupling is.

So the spawner of a coupling (a couple-action holding both members in hand) has only two ways to
hand each side reach to the other:

- **(i) Hand a global identity** — a `(BodyId, SegmentId)` pair resolved against a world table of
  bodies. This is precisely **Frame B1's `PartRef` into a `World.couplings` store**, and it is
  precisely **the name-into-a-store this frame swore off.** It works (B1 shows it does), but it is
  the capability frame *abandoning itself*: authority becomes knowledge of an id again, and the id
  is a thing the tightened substrate does not even provide. **Collapse.**

- **(ii) Make the coupling a PART** — graft a **junction segment** that is a shared child of (or a
  tiny third tree attached to) *both* bodies. Now "the other body" is reachable as a structural
  **neighbor through the junction**: the exchanged field (`junction.bag["flow"]`, tightness, the
  fluid delta) lives on the junction, and *both* sides read/write it via ordinary
  ancestor/neighbor access — store-free, id-free, exactly the §2(b) field trick lifted to span two
  bodies. This is the only escape that keeps the capability discipline.

But (ii) has a price the frame must own: **the junction is a real shared node, so the two trees
are now structurally fused into one tree for the coupling's lifetime.** They are no longer
separately serializable — saving "body B" now must capture the junction and therefore reach into
body A. This is the *same* "a coupling fuses the bodies' timelines" cost the SETTLED
`body-transformation-substrate.md` §coupling already accepted and B1's "pick two" already named —
but the capability frame makes it **structural rather than relational**: the fusion is a node in
the graph, not a row in a side table. The honest reading: **this frame can keep coupling
identity-free only by abolishing the separateness of the two bodies** — making them one tree at
the junction. If the product insists bodies stay independently serializable *while coupled*, (ii)
is unavailable and you are forced to (i), i.e. to identity-into-a-store. There is no third option
the frame can offer.

(And per `adversarial.md` B.1: even (ii) does not escape the deeper truth that cross-body flow is
a per-tick *mutual* dependency — the fused tree must be walked in lockstep. The junction makes the
fusion honest in the data model; it does not make the distributed-systems cost go away. The
capability frame is a *naming/serialization* answer, not a *synchronization* answer, and must not
overclaim to be the latter.)

---

## 4. The decisive weakness — slots vs. individuals, and the collapse into identity

Push on "what happens when the referent moves or is removed." The two sub-cases split cleanly and
the split is the whole verdict.

**Referent REMOVED.** A relative route (B) or an ancestor read (C) resolves against the *current*
tree, so it cannot dangle. If a `DOWN@pos=p` step finds no child at position `p`, the route runs
off the tree and resolves to **nothing** — cleanly, detectably, with no dead pointer. If an
ancestor is removed, the walk simply produces a shorter chain and the transition reads its *new*
parent (the former grandparent). **This is a genuine STRENGTH over the id-into-a-store frames:** a
relative reference degrades gracefully because it names a route, not an object — there is no
tombstone to chase, no burned id, no dangling-edge GC (contrast B1 §e's lazy+tombstone reaping).
The capability that names a slot can never point at a corpse.

**Referent MOVED.** Here is the lethal case. A relative route names a **structural SLOT, not an
INDIVIDUAL.** If the specific gland the spawner meant is *reparented elsewhere*, or a sibling is
inserted ahead of it shifting positions, then:

- the route still resolves — to **whatever now occupies that slot**, which is a *different part*;
- nothing errors; the transition silently starts reading the wrong referent.

The capability **follows the slot, not the thing.** For "my parent," "my root," "the region that
contains me" this is *exactly right* — those are role/slot relationships and should follow the
slot. But for "that specific gland, wherever it ends up," it is silently, deterministically wrong.

To make a capability follow the **individual** across moves, you must give the referent a
discriminator that survives reparenting and re-positioning — i.e. something stable that is *not* its
structural position. That is **identity**. And once you have per-individual identity, resolving "the
part with id X, wherever it now is" requires finding it without knowing its route — i.e. an
**index from id to location**, i.e. **a store.** So:

> **The capability frame avoids identity precisely by giving up the ability to track a specific
> individual across structural change.** It tracks roles/slots, never things. The moment a use case
> genuinely needs "this *particular* part, no matter where it moves" — and point-to-point hormones
> (§2c), oviposition transit (B1 §d, a segment moving between bodies), and any cross-body coupling
> (§3) all do — the relative route is the wrong tool, and the *only* fix is identity, which is the
> store-keyed name this frame was built to avoid. **The frame collapses into B1/A2 exactly at the
> boundary of individual-tracking and cross-tree reach.**

Two further honest strains:

- **Capabilities are wired into a continuously-restructuring graph.** Object-capability normally
  assumes a stable object graph; here the substrate's entire purpose is that the graph *mutates*
  (transformation IS restructuring). A route captured at spawn is only as valid as the structural
  neighborhood it traverses *remains* between spawn and a later tick — and a concurrent
  transformation may graft/reparent right across that route. So "handed at creation" is in tension
  with "the thing it routes through changes after creation." The frame is most robust exactly where
  the traversed structure is stable (ancestor spine), and most fragile where it is churning
  (lateral routes through actively-transforming regions).

- **No reach to not-yet-existing parts.** The spawner can only wire reach to what exists at spawn.
  A capability to a part that will be *grafted later* (a future front leg that should respond to a
  hormone) cannot be handed at the original spawn — the part is not there to route to. This is
  actually consistent and not fatal: the *graft* is itself an action holding the new part and its
  context, so it hands the new part *its* reach at *its* creation (§2's field trick means the new
  leg just reads the region field via ancestor-access — free, no hand-off needed). But it means
  "reach" is established per-part at each part's creation event, **distributed across many spawn
  events** — re-handing, at structural-event granularity. The frame doesn't eliminate re-handing;
  it relocates it from per-tick (which C does for free) to per-structural-event (which B/graft does
  explicitly).

---

## 5. Tree vs. graph implication

This frame is **the most tree-respecting of all the cross-access answers**, and that is both why
it is clean and why it is bounded.

- **On a pure TREE, relative-path / ambient capabilities are native and complete-for-tree-reach.**
  A tree has a *unique* route between any two nodes (up to the LCA, down the other side), so a
  relative route is well-defined and unambiguous, and the walker has a clean ancestor *stack*
  precisely because the walk is a tree DFS. Ancestor, descendant, sibling, and cousin-via-LCA are
  all expressible with **no store and no identity** — using only the two things the substrate
  blesses (tree edges + attachment position). For everything that is genuinely a *tree-structural
  relationship* (which "diffuse hormone over a body region" naturally is, §2), this frame needs
  nothing the substrate doesn't already have.

- **Any genuine GRAPH edge breaks it.** A coupling, a portal, a cross-body link, or any non-tree
  cousin-reference-that-must-survive-moves is an edge the tree does not contain. On a graph:
  routes are **no longer unique** (which of several paths is "the" capability?), there is **no
  single ancestor stack** (the walk is not a tree DFS), and a non-tree edge that must survive its
  endpoint moving is, by §4, exactly **a named reference = identity = a store.** A graph edge *is*
  identity by another name. The frame cannot encode one as a relative route.

- **The one escape — the shared junction part (§3 ii) — works by refusing to be a graph.** It
  converts a would-be non-tree edge back into a *tree* edge by fusing the two trees at a shared
  node. It preserves the store-free capability discipline only by keeping the world a tree (now a
  bigger, fused one). So the frame's deep commitment is: **it can serve any cross-access that can
  be expressed as tree structure, and it answers every genuine graph edge by either (i) collapsing
  into identity or (ii) fusing the graph edge back into a tree edge.** It never lives comfortably
  on a graph.

**Net for the synthesis.** Object-capability-as-relative-route is the *right* answer for
within-tree cross-access — ancestors, regional/diffuse hormones-as-fields, sibling influence —
where it is store-free, identity-free, serializes as plain data (or as nothing), degrades
gracefully on removal, and uses only substrate-blessed structure. It is the *wrong* answer, and
collapses into the very id-into-a-store it opposed, for (a) tracking a specific individual across
structural moves and (b) any cross-tree / coupling edge. The cleanest overall substrate position
this frame argues *for* is therefore a **split**: model diffuse and regional cross-access as
**fields on containing parts consumed by free ancestor-access** (this frame's genuine win, costing
no identity), and accept that **individual-tracking and cross-body coupling are inherently
identity-bearing** and must be handled by the B1/A2 store-keyed mechanism — not pretended into a
relative route. The frame's most useful contribution is drawing that line exactly, and proving the
left side of it needs no store at all.
