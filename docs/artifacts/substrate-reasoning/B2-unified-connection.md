# B2 — Unified "Connection" Primitive (one frame, pushed hard)

Frame assigned: collapse ATTACHMENT and COUPLING into a single `Connection`.
Goal is not to advocate unification but to *test* it — find where it holds and
where it strains, then give an honest verdict.

## The unified primitive (as designed)

```
Connection {
  id:        ConnId
  a:         PartRef          # (body_id, segment_id)
  b:         PartRef          # (body_id, segment_id)
  type:      ConnType         # the flavor axis
  props:     Metadata         # arbitrary, per the substrate's no-blessed-semantics rule
}
```

`PartRef` must be `(body_id, segment_id)` even for the intra-body case, because a
coupling can cross bodies. That single decision is already load-bearing — hold it.

`ConnType` is the flavor axis. Two canonical flavors:

- **`attach`** — structural/hierarchical. Adds: `position` (transform in parent
  frame), `parent_side` (which of `a`/`b` is the parent). Defines the body's tree.
- **`couple`** — non-hierarchical link. Adds: `seal { tightness, ... }`. No
  position, no parentage; may be cross-body, position-independent (portal), or self.

In a unified design these "adds" live in `props` (the substrate already says all
semantics are metadata), so structurally there is exactly one record type. The
question is whether that one record type is one *thing* or two things in a costume.

## Field-presence matrix (the first tell)

| field            | attach flavor | couple flavor |
|------------------|---------------|---------------|
| a, b, id, type   | yes           | yes           |
| position         | **required**  | meaningless   |
| parent_side      | **required**  | meaningless   |
| seal/tightness   | meaningless   | **required**  |
| cross-body       | forbidden*    | allowed       |

\*forbidden because the body tree is per-body; an attach edge that crossed bodies
would make "the body" undefined (see case e).

The disjointness is near-total. The only genuinely shared fields are the
identity/endpoint tuple `(id, a, b, type)` — which is just "an edge in a graph."
Everything that makes an attachment an *attachment* (position + parentage) is null
for couplings, and everything that makes a coupling a *coupling* (seal, cross-body
legality) is null for attachments. Putting them in `props` hides the nulls but does
not remove the disjointness; it relocates it from struct fields to a tagged-union
discriminator that every consumer must switch on anyway.

## Is "position" meaningful for a coupling?

No, and trying to make it so is instructive. A coupling's geometry, *if* it has
any, is derived: when a member is inserted into an orifice, the rendered pose comes
from the two parts' existing world transforms plus a contact solve — it is an
output, not a stored attachment transform in a parent frame. A portal coupling is
explicitly position-*independent*: the two ends may be arbitrarily far apart in
world space. So `position` is not merely unused for couplings; for portals it is
semantically prohibited — there is no shared frame to express it in. An attachment's
`position` is intra-body, in the parent segment's frame, and is *the* thing it
stores. Same word, incompatible meaning.

## Is parentage/hierarchy meaningful for a coupling?

No, and this is the sharper break. Attachment parentage is what makes the body a
*tree* (or near-tree): each segment has one structural parent, transforms compose
up the chain, and "remove the upper arm" deterministically orphans the forearm and
hand. A coupling has no parent. member↔orifice is symmetric-ish; neither end owns
the other's transform; decoupling leaves both parts exactly where they were. If you
forced `parent_side` onto a coupling you would assert a transform-composition
relationship that does not exist, and a naive renderer would try to compose through
it. Hierarchy is not just absent from couplings — it is the property whose absence
*defines* them.

## Cases

**(a) Normal limb attachment.** `Connection{a: torso, b: upper_arm,
type: attach, props:{position: T, parent_side: a}}`. Clean. This is the case the
unified record was shaped around, so of course it fits.

**(b) Cross-body member↔orifice coupling with tightness.**
`Connection{a:(body1, member), b:(body2, orifice), type: couple,
props:{seal:{tightness:0.7}}}`. Works *as a record*. But note what it forced:
`PartRef` had to carry `body_id`, and the connection cannot live "inside" either
body's part-graph the way an attachment does — it is a third-party edge over two
trees. More on this in (e).

**(c) Portal coupling.** Same as (b) but `body_id`s may be equal or different and
there is no spatial relationship at all. `position` absent, and *must* be absent.
This is the case that proves `position` cannot be promoted to a shared field.

**(d) Self-coupling (futanari / oviposition).** `a` and `b` share a `body_id`;
`type: couple`. Structurally trivial in the unified model — just an edge whose two
endpoints happen to be in the same body. Notably this is the one case where the
unified model earns something: a coupling and an attachment can both be "same body,
two segments," and the *only* difference is the flavor + which fields are live. So
within the couple-flavor, self vs cross-body is genuinely a non-distinction —
unification across *that* axis is real. But that is unifying couplings with
couplings, not attachments with couplings.

**(e) Determinism / save-load spanning two bodies.** This is where unification does
real damage. Pre-unification, an attachment is *part of a body's own graph*; a body
serializes its segments + attachments as a closed, self-contained tree. A coupling
spanning body1 and body2 belongs to *neither* graph — it is a relation in the world,
not in a body. If you unify and let `Connection` be "the edge type," you must decide
where a cross-body connection is stored. If it lives in body1's graph, then body1 is
no longer self-contained — loading body1 alone references a segment in body2, and
the body graph "suddenly has to handle cross-body state" exactly as the prompt
feared. The honest resolution is that couplings live in a **world/session-level
connection table**, keyed by `(body,segment)` pairs, *separate from* the per-body
attachment trees. But once couplings live in a different container than attachments,
"one primitive" is a record-shape coincidence, not an architectural unification:
they are stored apart, loaded apart, and have different lifetimes (a body's
attachments persist with the body; a coupling is session/world-scoped and transient).

**(f) Part removed mid-connection.** Remove `upper_arm`. For the *attachment*
flavor, removal cascades down the tree (forearm/hand orphaned or destroyed) — a
structural operation. For a *coupling* on that same arm, removal must instead
*sever* the coupling and resolve its seal (leak/spill resolution), with no cascade —
the other body is untouched. So the same verb ("part removed") triggers two
unrelated handlers selected entirely by flavor. The unified primitive does not
unify the *operations*; it just makes them switch on `type` instead of dispatching
to two types. The branching didn't disappear; it moved inside.

## Where unification genuinely holds

1. **Both are edges in a graph.** The identity/endpoint tuple is real shared
   substance. If the engine has a generic graph layer, attachments and couplings
   are both edges in it, and graph traversal/queries can be uniform.
2. **Within couplings, the self/cross-body/portal axis collapses cleanly** — case
   (d) and (c) show position-independence and same-body are non-distinctions for a
   coupling. That sub-unification is worth keeping and is *inside* the coupling
   flavor, not across the attach/couple line.
3. **`props` as open metadata** is already mandated by the substrate, so neither
   flavor needs blessed fields — consistent with the no-semantics rule.

## Where unification breaks

1. **Field disjointness is near-total** (matrix above): the only shared fields are
   "it's an edge." Everything characteristic is flavor-exclusive. A unified record
   is mostly-null in opposite directions per flavor — the classic two-things-one-name
   smell.
2. **Position and parentage are not just unused but *prohibited* for couplings**
   (portal has no shared frame; coupling has no transform-owner). These aren't
   optional fields; asserting them is a semantic error a renderer can act on.
3. **Storage/lifetime divergence (case e):** attachments are intra-body and
   serialize with the body; cross-body couplings cannot live in a body graph without
   destroying its self-containment, so they need a separate world-level table. Same
   record type, two homes, two lifetimes.
4. **Operations don't unify (case f):** removal, decomposition, and load all branch
   on flavor immediately. The primitive unifies the *noun* but every *verb* re-splits.

## Honest verdict

**Do not unify into one primitive. Unify one level up instead — share a graph-edge
substrate, keep two distinct edge types over it.**

The attachment-vs-coupling distinction is *real*, not incidental:

- An attachment is **intra-body, hierarchical, persistent, transform-bearing** — it
  *is* the body's structural tree and serializes with the body.
- A coupling is **possibly cross-body, non-hierarchical, transient, seal-bearing** —
  it is a world-level relation between two parts and serializes apart from any one
  body.

Collapsing them yields a record that is one thing only at the level of "an edge with
two endpoints and a type tag." Everything below that tag is disjoint: disjoint
fields, disjoint storage containers, disjoint lifetimes, disjoint operations. That
is the signature of two primitives wearing one name, and the cost is concrete — it
forces `PartRef` cross-body identity onto the clean intra-body tree, invites the
body graph to hold cross-body state, and makes every consumer switch on `type`
before doing anything.

The right factoring keeps the clean tree clean:

```
Edge (generic graph substrate: id, a:PartRef, b:PartRef, props)
 ├─ Attachment : Edge   # + position, parent_side; stored in body.graph; intra-body invariant
 └─ Coupling   : Edge   # + seal/tightness; stored in world.couplings; cross-body/portal/self
```

Share the edge layer (graph queries, generic traversal, the metadata bag); do not
share the primitive. The thing the prompt's frame correctly *found* — that self,
cross-body, and portal couplings are one primitive — is a unification *within*
coupling, and it stands. The unification *across* attach and couple does not.

### Residual tension (not hidden)

The cleanest counter-argument: if a future requirement makes attachments
cross-body (e.g., a grafted limb that is structurally part of body A but anchored to
body B), the intra-body invariant I leaned on in (e) cracks, and the storage
argument weakens. I think that case is actually a *coupling that also bears a
transform* — i.e. evidence the two flavors can blend at the edges — but I have not
worked it fully, and it is the place this verdict is most exposed. If that hybrid
turns out common rather than exotic, the two-types factoring would need a third
(transform-bearing cross-body) variant, at which point a single primitive with an
explicit capability set (`bears_transform`, `is_hierarchical`, `bears_seal`,
`is_cross_body`) becomes more defensible than three near-types. So: don't unify
*now*, on current cases; revisit if transform-bearing cross-body links prove common.
```
