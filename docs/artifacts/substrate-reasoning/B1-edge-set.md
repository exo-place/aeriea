# Problem B — Frame 1: Couplings as a separate edge-set over part-references

*One independent pass. Frame: a coupling is an edge in a relation distinct from
the attachment hierarchy; an edge joins two part-refs, each of which can point at
any part in any body, so cross-body / portal / self all fall out of the same
shape.*

## Shapes

### Part-reference

```
PartRef = (BodyId, SegmentId)
```

Both halves are stable IDs, not indices. `BodyId` identifies a body instance
within a world/session; `SegmentId` is stable for the lifetime of the segment
inside its body (assigned at creation, never reused even after removal — a
removed segment's id stays burned so a dangling ref is *detectably* dead, not
silently aliased onto a new segment). A PartRef carries no positional or
structural information — resolving it means asking the named body "do you still
have segment S?" and getting the segment or `nil`.

This is the whole reason the frame works: the ref is opaque w.r.t. structure.
The attachment hierarchy lives inside a body; the PartRef reaches across the body
boundary by *name*, so structural adjacency is irrelevant. Portals are not a
special case — every coupling is already "action at a distance" because every
coupling addresses by id, not by position.

### Coupling edge

```
Coupling = {
  id:        CouplingId,        // stable, world-unique
  a:         PartRef,           // unordered? see below
  b:         PartRef,
  seal:      { tightness: f32, ... },   // substrate-known numeric props
  meta:      Metadata,          // opaque bag, same rules as segment metadata
}
```

`seal.tightness` is the one property the substrate gives first-class numeric
status — not because the substrate interprets *what* leaks, but because
tightness is the coupling-level scalar that a consumer needs in order to compute
flow and that transformations need to be able to drive with expressions (same as
any other numeric channel). Everything else about the coupling — which end is
"insertive", what role each part plays, depth — is `meta`, uninterpreted.

**Ordered or unordered?** The edge is stored unordered (a set of two refs) but
exposes a *labelled* view via metadata (`meta.a_role`, `meta.b_role`) when a
consumer needs directionality. The substrate does not bless "source/sink"; flow
direction is a consumer concern (below). Keeping the stored edge unordered avoids
a second source of truth for "which end is which" — the labels are just metadata.

Self-coupling is `a.body == b.body` with `a.segment != b.segment` (or even ==
for a degenerate self-loop, which we forbid: a part cannot couple to itself).
Nothing in the edge shape distinguishes self from cross-body — it is purely
whether the two BodyIds happen to match.

## Where the coupling-set lives

This is the load-bearing question and the frame's sharpest fork.

A coupling belongs to **no single body** — it spans two, and in the cross-body
case neither body can own it without one body holding a reference into another
body's id-space (which couples their save files and breaks independent
serialization). So the coupling-set is **world/session-level state**: a
`CouplingTable` owned by the same authority that owns the set of bodies (the
session/world). Bodies remain self-contained — a body's save blob contains its
own segments, attachments, metadata, and *nothing about couplings*. The
CouplingTable is a sibling top-level structure.

```
World = {
  bodies:    Map<BodyId, Body>,
  couplings: CouplingTable,   // Set<Coupling>, or Map<CouplingId, Coupling>
}
```

Determinism/replay: the CouplingTable is regular world state, so it is part of
the seeded simulation timeline exactly like body state. Couple/uncouple are
actions in the action-log; replaying the log rebuilds the table. Tightness
changes driven by transformation expressions are deterministic functions of
simulation state, same as any other channel. No new determinism machinery — the
table is just more state under the existing seed+log discipline.

Save/load with a cross-body coupling: you save the *world*, not a body in
isolation. A coupling references two BodyIds; both must be present in the loaded
world for the edge to resolve. If you load only one body (e.g. importing a
character into a different world), every coupling that named the absent body
is a dangling edge — handled by the same dead-ref path as part removal (below).
This is honest: a coupling is inherently a world-level fact, so "load one body
with its couplings intact" is *not a coherent operation* and the model refuses
to pretend otherwise.

## Tightness → flow: the substrate/consumer boundary

The substrate **does not compute flow.** Fluids are segment metadata
(`segment.meta.fluids = {...}`) and the substrate never interprets metadata, by
the established rules. So the substrate cannot know that "semen" should move from
A to B, nor how much, nor what "leak" means.

What the substrate **provides**:

1. The coupling exists and resolves to two live segments.
2. `seal.tightness` as a numeric channel readable/writable by expressions.
3. A *queryable relation*: "give me all couplings touching segment S", "resolve
   coupling C to its two segments and their current metadata".

What the **consumer** (a fluid-sim system, an author's transformation rules)
does:

- Reads the two segments' fluid metadata + the coupling's tightness, and applies
  *its own* transfer model: e.g. `transferred = source.fluids[k] * f(tightness)`,
  `leak = source.fluids[k] * (1 - f(tightness))` spilled to environment/another
  segment. The function `f` is the consumer's, not the substrate's.
- Writes results back as metadata mutations (which, to stay deterministic and
  replayable, are themselves expression-driven transformations over world
  state — the consumer is "an author" expressed in the same transformation
  language, not an out-of-band imperative loop).

So the precise boundary: **the substrate owns the topology and the tightness
scalar; the consumer owns the semantics of what flows and how much.** Tightness
is deliberately the *one* place the substrate leans toward flow — it is a scalar
slot reserved for "how restrictive is this coupling" — but it is still just a
number; the substrate attaches no meaning to high vs. low. A consumer that
ignores fluids entirely (two parts coupled with no fluid system loaded) still
gets a perfectly valid coupling; tightness is then inert. That is the right
factoring: the substrate is generic, flow is one application of it.

There is a real subtlety here I won't paper over: tightness being "blessed" as
numeric while fluids are "just metadata" is a *slight* asymmetry. The
justification is that tightness is a property *of the edge* (which the substrate
owns) whereas fluids are properties *of segments* (metadata the substrate already
refuses to interpret). The edge's own scalar is fair game; segment semantics are
not. But one could argue tightness should also be `meta` and the substrate should
bless *nothing*. I lean to blessing it because expressions need a stable typed
channel to drive, and "drive this coupling's tightness over time" is exactly the
kind of transformation the system exists to make deterministic. See strain.

## Cases

**(a) Two people, member↔orifice, tightness governs leak.**
`Coupling{a:(P1,seg_member), b:(P2,seg_orifice), seal.tightness:0.8}` lives in
`World.couplings`. A fluid consumer, each tick, resolves the edge, reads
`P1.seg_member.meta.fluids`, computes transfer/leak via its model scaled by
0.8, writes new fluid metadata to `P2.seg_orifice` (transferred) and to an
environment sink (leaked). Substrate did topology + scalar; consumer did
semantics. Works cleanly.

**(b) Portal coupling between non-adjacent parts.**
Identical edge shape. The two parts are not attachment-adjacent — irrelevant,
because the edge addresses by id. There is *no portal concept in the substrate
at all*; "portal" is just the observation that couplings never required
adjacency. The only thing a renderer needs extra is *where to draw* the
visual bridge, which is presentation metadata on the coupling
(`meta.visual = "portal"`), not substrate semantics. Clean — arguably the
frame's strongest case, because non-adjacency is free.

**(c) Self-penetration (same body).**
`Coupling{a:(P1,seg_x), b:(P1,seg_y)}`. Same BodyId twice. Lives in the same
world table. Nothing special. Futa self-penetration and oviposition's
source/destination both being in one body are the same shape. Works.

**(d) Oviposition (something passes through).**
The egg is itself a segment (or a small body). "Passing through the coupling" is
a *consumer* operation: an author rule observes the coupling, and over ticks
*moves* a segment — i.e. re-parents it in the attachment hierarchy from the
source body/cavity to the destination, gated by tightness (a wider seal passes
the egg faster / a too-tight seal blocks it). The coupling provides the
*channel and the gate scalar*; the act of re-attaching the egg-segment is an
attachment mutation the author drives. Note this couples two subsystems: the
coupling edge-set *and* the attachment hierarchy, via a consumer that reads one
and writes the other. The substrate keeps them separate; the *author* bridges
them. This is correct but it shows couplings are not self-sufficient for
"transit" — transit is attachment churn gated by a coupling, not a coupling
primitive.

**(e) Mid-coupling transform / part removal.**
A transformation removes `P2.seg_orifice` (or merges it, or P2 is deleted).
The edge in `World.couplings` now has a ref that resolves to `nil`. Options:
  - **Eager cascade:** the mutation that removes a segment also scans the
    CouplingTable and drops/marks edges touching it. Requires the body-mutation
    path to reach into world-level state — a coupling-direction dependency from
    body→world, which is a layering smell.
  - **Lazy / tombstone (preferred):** removal does nothing to the table; edges
    resolve lazily. A coupling with a dead ref is *detectably dead* (burned id
    never re-aliases) and is reaped by a world-level GC pass or treated as
    inert-until-reaped by consumers (a dead edge transfers no fluid). This keeps
    body mutation ignorant of couplings (good layering) at the cost of transient
    dangling edges (must be tolerated everywhere a coupling is read).
I take lazy+tombstone. But "transform mid-coupling" is subtler than removal:
if the orifice is *transformed* (rescaled, retagged) but still exists, the edge
*survives* and the consumer simply sees new metadata/tightness next tick —
which is the desired behavior (transformation flows through a live coupling).
The hard sub-case is a transform that *splits* a segment into two: which child
inherits the edge? The substrate can't decide (no semantics). The split
transformation must, as part of its definition, specify edge-rehoming — i.e.
edge-rehoming is a responsibility pushed onto authors of structure-changing
transforms. Honest cost.

**(f) Save/load + replay, cross-body.**
Save the world: both bodies + the CouplingTable serialize together. The table
stores `(BodyId, SegmentId)` pairs — plain data, fully serializable, no
closures, satisfying data-over-code. Load reconstructs the table; edges resolve
against the loaded bodies. Replay: couple/uncouple/tightness-drive are all log
actions over world state; re-running the log from seed reproduces the table
bit-for-bit. The only failure mode is loading a *partial* world (one body
absent) — covered under "where it lives": those edges dangle and are reaped,
and the model is explicit that a coupling is a world-fact, not a body-fact.

## Biggest honest tension

**Cross-body state ownership is genuinely uncomfortable, and it leaks into every
boundary.** The frame's clean answer — "the coupling-set is world-level, bodies
stay self-contained" — is right but it *demotes the body from the unit of
saving/sharing*. People will want to export "my character" and reasonably expect
their current couplings to ride along; the model says that's incoherent because
the other end belongs to someone else. We can offer a "snapshot" export that
*materializes* the foreign part into the exported world (copy, not reference),
but that silently forks identity — the exported coupling now points at a *copy*
of the partner, not the partner. There is no ownership story that is
simultaneously (1) bodies independently serializable, (2) couplings durable
across export, and (3) no identity forking. Pick two. I keep (1)+(3) and accept
that couplings are world-scoped and don't survive single-body export — but this
is a real product-facing limitation, not just an implementation detail, and a
different frame (couplings co-owned by both endpoints, or couplings as
attachments into a shared "junction" pseudo-body) might trade differently.

Secondary, smaller: the tightness-is-blessed / fluids-are-metadata asymmetry is
a defensible but not airtight line — it survives only as long as "tightness" is
the *single* edge-scalar consumers need. The moment a second flow-relevant edge
property shows up (viscosity gate? two-channel seal?), pressure mounts to either
bless more (substrate creep) or demote tightness back to metadata (consumer
computes everything, substrate owns pure topology). I currently bless exactly
one scalar; I am not confident that holds.
