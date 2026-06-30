# B3 — Problem B (coupling) from the PORTS / interfaces frame

Status: **one independent design pass, single frame. Reasoning artifact, no code,
not green.** Sibling to other B-passes; do not read as the decided answer.

Frame assigned: a part exposes PORTS (connection interfaces with a profile:
shape/size, openness, kind). A COUPLING JOINS two ports. SEAL TIGHTNESS is DERIVED
from the FITMENT between the two joined profiles. A PORTAL is a port that links
elsewhere; self/cross-body is just joining any two ports.

Grounding I read first (so this sits on the established substrate, not a fresh one):
`substrate-foundations.md` (state = f(seed, log); never store the world; no facades),
`substrate-core-design.md` (derivation-framing is the root: no state lives in a locus;
the facade hole = a locus reading another locus's state directly), and
`compound-parts-and-fluids.md` (body = graph of generic segments + open metadata;
fluids = per-segment state `{type, amount, capacity}`; §9 Q1 leaves inter-body
fluid transfer open, current lean = "just two `fluid_delta`s the act emits, no new
structure"). This pass is, in effect, a concrete proposal for that open question.

---

## 1. The load-bearing decision: is PORT blessed, or convention + library?

The substrate blesses almost nothing structural — segments, attachments (intra-body,
positional), open metadata, and fluids-as-segment-state. Material, covering, role,
kind are all *metadata the core never interprets*. Blessing "port" as a first-class
structural noun distinct from segment would be the **second structural primitive in
the system**, and it would fight the radically-generic thesis head-on.

So I do **not** bless port. The resolved shape:

> **A PORT is a segment** (usually a leaf child segment) **carrying
> `port`-convention profile metadata.** Nothing new structurally. This is the exact
> move `compound-parts-and-fluids.md` already makes for genitalia ("N of a thing =
> N sibling segments sharing a convention tag"). A port is a segment tagged `port`
> whose metadata holds a profile.

Why a *segment* and not a sub-site `(seg_id, port_name)`: a named sub-site with its
own profile is a second addressing scheme — precisely the "second structural concept"
the frame must avoid. Anything that needs an independent port (a tube with a distinct
in-mouth and out-mouth; a portal stone with two faces) is **just two child segments**,
each tagged `port`. Then a port collapses back to "a segment with profile metadata,"
addressed by the node-id the substrate already gives every segment. Zero new
addressing, zero new structural noun.

**Profile = OPEN props, not a closed `Port` struct** (same discipline as CoC's
per-part struct being lifted as open props, not a sealed type). Candidate fields,
in the substrate's canonical mm (`units-and-scale.md`):

| field | meaning | nature |
|---|---|---|
| `shape_family` | token: `taper` / `slot` / `ring` / … | gates compatibility |
| `role` | `insertor` / `receptor` / `bidir` | **metadata**, not a blessed polarity |
| `caliber_mm` | insertor girth | static-ish config |
| `bore_mm` | receptor resting aperture | static-ish config |
| `length_mm` / `depth_mm` | engagement extent | static-ish config |
| `elasticity` 0..1 | how `bore_mm` stretches to admit | static-ish config |
| `rigidity` 0..1 | insertor resistance to deform | static-ish config |
| `openness` 0..1 | relaxed↔clenched / flaccid↔erect | **DYNAMIC state** |

Only `openness` is live state (changed by arousal/act events via the same
`fluid_delta`-style prop op). The rest are configuration that TF ops mutate.

## 2. The JOIN: the one primitive coupling actually forces

A coupling is **NOT an attachment** (the problem says so) and it must not be
metadata-on-a-port either. It is a **binary relation row in the log**:

```
coupled{ a: (body_id, seg_id), b: (body_id, seg_id), at_event, props? }
```

— an edge in a *second graph* orthogonal to the attachment graph. Attachments are
intra-body, hierarchical, positional (containment); couplings are peer edges, possibly
**inter-body**, non-positional. That orthogonality is the precise structural meaning of
"a coupling is not an attachment": the body structure stays a tree/DAG via attachments;
couplings cross-cut it.

**Why a relation and not a `coupled_to` field on the port.** Two hard reasons, both from
the core:
- A coupling is symmetric; a denormalized field on each end can desync. The relation row
  is the single normalized source of truth.
- For a cross-body join, the other port lives in a **different body's sub-derivation**.
  An intra-body metadata field pointing into a foreign body *is* the facade hole
  `substrate-core-design.md` flags — one locus reading another locus's state directly.
  The coupling must live at the **lowest log scope that dominates both ports** (a
  scene/world log), reached through deterministic revelation, never a raw cross-body
  pointer. A self-join (both ends one body) can live in that body's own log; a cross-body
  join lives one scope up. This is the load-bearing invariant of the whole frame (§7).

So coupling adds **exactly one blessed primitive** — the scope-correct peer relation.
Ports add **zero** blessed primitives. Fluids already exist.

## 3. Fitment → tightness → flow: where it lives (honestly: the LIBRARY)

The frame's headline is "tightness is DERIVED from fitment." True — but the derivation
**reads and physically interprets unblessed metadata** (`caliber_mm`, `bore_mm`,
`elasticity`, `openness`). Interpreting body semantics is exactly what the core refuses.
So fitment is a **consumer library**, shipped at the same status as the describe-layer
banding standards in `compound-parts-and-fluids.md` §9.3 — a sensible configurable
default, not core. The substrate stores the relation + reservoirs; the library computes.

Fitment sketch (library, pure over current profiles):
```
effective_bore = bore_mm * (1 + elasticity * f_open(openness))   # clenched lowers
overlap        = caliber_mm - effective_bore
tightness      = sigmoid(overlap / k)        # girthy-in-tight → ~1 ; gap → ~0
if not compatible(shape_family_a, shape_family_b): tightness = 0   # no seal
engagement     = min(length_mm, depth_mm)
leak_fraction  = clamp(1 - tightness) ( + overflow if delivered > capacity_left )
```

**Flow does NOT add a core op.** This is where ports *earn their keep* over bare
fluid_deltas. The §9-Q1 lean is "the act emits two `fluid_delta`s." Ports keep that —
but the act now emits only *how much is pushed* (`amount=Q`); the port library
**deterministically splits** it via the coupling:
```
delivered = min(Q * tightness_containment, capacity_left_of_receptor)
leaked    = Q - delivered           # → environment / spill sink segment
```
and emits the two (or three) `fluid_delta`s. The act stops hard-coding leakage; fitment
decides the split. That is the concrete value-add: a deterministic *splitter* sitting on
the act's deltas, not a new structure.

## 4. Cases

**(a) member→orifice, fitment→tightness→leak.** member: child seg under groin, `port`,
`{role:insertor, caliber_mm:38, length_mm:160, shape:taper, rigidity:0.8}`. orifice:
`{role:receptor, bore_mm:22, elasticity:0.6, depth_mm:120, openness:0.4, shape:slot}`.
JOIN appends `coupled(member,orifice)` to the scene log. Library: effective_bore ≈ 30,
overlap +8 → tightness ≈ 0.7, leak ≈ 0.3, engagement = 120. Act pushes Q → ~70% delivered
to the orifice reservoir, ~30% leaks to a spill sink.

**(b) loose vs tight → different flow.** Same orifice, thin member `caliber_mm:14` <
effective_bore 30 → tightness ≈ 0.1, leak ≈ 0.9: most of Q spills around the gap, little
contained. Same orifice clenched (`openness:0.05`) → effective_bore drops to ~20; a
`caliber_mm:22` member → tightness ≈ 0.9, near-zero leak. Tightness moved purely by a
dynamic profile field — no new join.

**(c) portal port.** Here the frame **over-claims**, honestly. Because the coupling is a
non-positional log relation by construction, *position-independence is already free* —
every coupling is a "portal" in the position-independent sense. A *standing* portal (a
fixed open channel fluids pass through continuously) is just a coupling whose profiles are
wide-open (`openness:1`, large bore, unbounded depth) → tightness low, ~free flow. So
"portal as a distinct port kind" is **redundant**; it reduces to a wide-open coupling. The
only residue worth a flag is an authored standing link that exists *before* any fluid act
— still just a pre-existing `coupled` row. No new concept survives.

**(d) self-join (futanari / oviposition).** `coupled(seg_a, seg_b)` where both ids share a
body-root. The relation is indifferent to whether the ids share a root, so this is the
*easier* case: it lives in the body's **own** log scope (no scope escalation), fitment is
identical. Oviposition = a self-join whose insertor reservoir holds discrete `egg` fluid/
items the splitter routes inward.

**(e) part transformed mid-join (size changes) — live?** **Yes, by construction.** The
coupling row stores only the two port identities + join event; it stores **no** tightness.
Tightness is a derivation over *current* profiles. `prop_delta` grows the member
`caliber_mm 38→52`; the next tightness query re-derives against 52 → tighter, less leak.
The derivation-framing forbids caching state in the coupling, so live update is not a
feature I add — it's the only thing the law permits. Replay-safe too: tightness "as of
event T" re-derives from the profile-as-of-T, itself a fold of the `prop_delta`s up to T;
no snapshot needed. **Strain:** when caliber exceeds the orifice's elastic limit
(52 vs max-stretch 35), does the coupling tear / auto-eject / strain? The substrate
**cannot decide** — it reports tightness over-limit; break-vs-strain is consumer/act-layer
policy. Don't over-bless.

**(f) cross-body determinism / save-load.** Bodies A and B are sub-derivations of a scene
log. `coupled(A.member, B.orifice)` is a row in the **scene** log (the scope dominating
both). Save = scene seed + log (both bodies' events + the coupling event). Load =
re-derive; tightness at any T = pure f(both profiles-as-of-T, the row). Holds **iff**
port addresses are globally stable: a port's global address is `(body_id, seg_id)`, with
`body_id` assigned by the **scene log's seeded counter** and `seg_id` by the body's seeded
counter. **Failure mode to flag:** if `body_id` is assigned per-session (join order,
wall-clock) instead of seeded off the scene log, replay breaks. Seed it off the log.

## 5. Honest strain (the real tensions, not a victory lap)

1. **Genericity is real at the core seam, soft at the library seam.** The core blesses no
   port and no profile — good. But the shipped fitment library reads `caliber_mm`,
   `bore_mm`, `openness` by name, so those fields become *de-facto privileged metadata*
   the moment the standard library exists. The frame must **not** claim "nothing blessed";
   it blesses a *convention*, exactly the project's accepted compromise (convention-by-
   library, like the genital/breast tags and the banding standard). Honest framing: the
   genericity holds where it's load-bearing (the core), and softens into a strong
   convention where a default has to live somewhere.

2. **The headline mildly over-promises.** "Seal tightness is DERIVED from fitment" reads
   as *the substrate computes it*. It doesn't — the **library** does. The substrate
   supplies only the relation + reservoirs + the deltas. If fitment crept into core, the
   core would be interpreting body physics = the poison `substrate-foundations.md` forbids.

3. **Where the port model over-blesses, called out.** (a) **portal** as a port kind is
   redundant (§4c). (b) **member/orifice polarity** — the frame imports an asymmetry, but
   the relation is symmetric and `role` is just metadata the fitment lib reads; blessing
   polarity would re-add a refused semantic. (c) a closed `Port` struct would over-commit
   the schema — must stay open props.

4. **THE biggest tension — coupling forces a scope-crossing relation, and the whole
   determinism story rests on keeping it a relation at the *right* scope.** A body is no
   longer a closed derivation: its fluid state at T can depend on a row in a *parent* log
   and on *another body's* profile. That is structurally the same shape as the facade hole
   core-design flagged. It is safe **iff** every coupling lives at the lowest-common-
   ancestor scope of its two ports and is **never** denormalized into intra-body metadata.
   The tempting optimization — a `coupled_to` field on the port — silently re-opens the
   facade hole and breaks cross-body replay. That single invariant is the load-bearing
   constraint of the entire ports frame, and it is exactly the easiest one to violate.

## 6. Net

Ports, taken seriously inside *this* substrate, **dissolve into convention + a library**
rather than a new structural layer: port = segment + `port` profile metadata (zero new
primitive); coupling = one new blessed scope-correct peer relation; fitment/tightness/
leak/flow-split = a shipped consumer library that reads unblessed metadata, leaving the
core uninterpreting. The frame's genuine contribution over bare "two fluid_deltas" is the
**deterministic splitter**: the act says how much is pushed, fitment decides how much
seals vs leaks. Its genuine cost is one scope-crossing relation whose discipline is
fragile. Its honest over-reaches are *portal* and *polarity*, both of which reduce away.
