# Adversarial attack on the two convergent syntheses

Status: **Adversarial reasoning artifact. Hostile-skeptic pass over six convergent
frames (A1–A3, B1–B3). Not a decision; a stress test.** Default stance: "this breaks,"
and prove it with constructed inputs.

Grounding read first: the six frame docs, and `docs/decisions/dynamical-transformation.md`
(the established substrate — transitions are `{from: snapshot, to: target, progress∈[0,1]}`,
`value(T) = interpolate(from, to, progress(T))`, `Segment.transitions` keyed by property
holding **one** active transition, drivers piecewise-constant, closed-form replay).

---

## Synthesis A — "one master scalar, parts are pure expressions over it"

### A.1 The sharpest breaking case: snapshots make absolute interpolation non-composable

Every frame models a part's value as `interpolate(from, to, progress)` where **`from` is a
snapshot captured by reading the live value at the transition's start event** (substrate §4:
`"from": "snapshot"`, "captured at start event"; A2 §1.2 `"from": "snapshot"`; A1 `staged`;
A3 "interpolate attachment positions and metadata"). This single shared choice — *change is
an absolute interpolation from a captured endpoint to a captured target* — is what breaks,
and the "deterministic reducer" the frames reach for (A1 strain 1, A2 case e) does not fix
it; it hides it.

**Constructed input.** One property, `#breast_l.volume_ml`. Baseline 200 (mL, fixed-point).

- `t=0`: TF1 "estrogen growth" starts. `from₁ = snapshot = 200`, `to₁ = 800`, progress₁
  driven by `estrogen`.
- `t=10`: TF1 has driven volume to ≈500. **Now TF2 "chastity/flatten" starts.** Its `from₂`
  is `"snapshot"` — it reads the *live* value **now**. But "the live value now" is itself the
  reducer's output over TF1. So `from₂ = reduce(TF1@t10) ≈ 500`. `to₂ = 100`.

Now the reducer must fold TF1 (heading to 800) and TF2 (heading to 100) over the *same*
property every tick. Examine each candidate reducer:

- **Last-writer-wins (id order):** TF2 wins → 100. TF1 is silently void. The substrate's own
  data shape *enforces this* — `Segment.transitions["volume_ml"]` holds exactly one record, so
  TF2's start **overwrites** TF1's record (substrate §4: a new transition "commits a fresh
  transition record … collapsing prior evolution into a fresh baseline"). TF1 is not arbitrated
  against; it is **destroyed**, with no audit trail (A2 case e: "hollowed out member-by-member
  with no error"). When you later pause/reverse the *master* that owned TF1, there is nothing
  to reverse — the record is gone.
- **Sum of absolute targets:** 800 + 100 = 900. Nonsense — neither transformation wanted 900.
- **Sum of deltas over a baseline:** requires a *baseline* both deltas are relative to. There is
  none: TF1's delta is relative to 200; TF2's `from₂` was captured as **500**, which already
  contains TF1's partial effect. So TF2's "delta" double-counts TF1. Subtracting to fix it means
  the reducer must *un-read* the snapshot it already took — i.e. reconstruct what the value
  *would have been* without TF1, which is not stored anywhere.

The corruption is structural, not a tuning problem: **`from₂` is captured by reading the
reduced live value, so TF2's very definition depends on the arbitration outcome of TF1.** The
transition is not a pure self-contained `{from, to, progress}` the frames claim — its `from`
is a function of every *other* transition active at its start instant. Two absolute
interpolations over one property are mutually entangled at capture time and **cannot be folded
by any fixed reducer**, because a fold presupposes independent operands and these are not
independent.

**Verdict: needs revision.** The synthesis survives only for *orthogonal-axis* multi-TF (A2's
genuine win: `volume_ml` and `material` on different keys — those compose because they never
share a slot). For **same-property** contention it is broken by construction. The revision is
not a better reducer; it is a **different value primitive**: model continuous change as a
**composable operator over a shared baseline** — a delta or a multiplier `value = baseline ⊕
Σ contributions(progressᵢ)` — *not* an absolute `interpolate(snapshot, target, progress)`.
Operators commute and sum; snapshots-to-targets do not. The frames "blessed nothing semantic"
yet quietly blessed the most consequential semantic choice in the system: that change seeks an
absolute target rather than composing a relative effect. (Honest counter: bounded
`from→to` interpolation buys a *true bounded segment* an open-ended delta cannot express —
substrate §4.1 makes this point. So the revision costs the clean bound. The fix: keep
`to` as a per-contribution *clamp on its own delta*, not as the rendered property's absolute
value. You recover boundedness without the shared-slot collision.)

### A.2 Second breaking case: reversibility makes state genuinely unbounded, and "authors decide" is a category error

To reverse TF1 an hour later (substrate §2.2; A1 strain 2), its record — and any node it
`Remove`d, now tombstoned (A1 strain 3) — must persist. The frames punt the lifetime to
"authors decide" / "periodic scan" (A1, A2 §6 GC). **This punt is incoherent:** whether a
transformation will be reversed is a *runtime player/session* fact, unknowable to the author
who wrote the TF. The author cannot decide a lifetime that depends on a future player action.
So the only sound policy is "keep every transformation ever applied, reversible forever" → the
live set the reducer must scan each tick is **monotonically growing in session length**, and
every `Remove` is a tombstone that can never truly free. This is not "bounded by good content
design" (substrate §7's claim for *driver* count); it is unbounded in *history*. The frames
each saw a piece (A1 strain 2, A2 GC) but none priced it: the reversibility guarantee and
bounded state are in direct contradiction, and *no frame chose*. **Revision required:** a
session-level **reverse-horizon** (after which a TF bakes irreversibly and its record + tombstones
GC) — a product decision the substrate must make, not delegate to authors.

### A.3 What survives

Replay determinism with an external async driver `H(t)` (attack (d)) **survives** — honestly.
If `H` is itself a deterministic function of `seed + action log` (substrate §3: drivers are a
logged timeline), then a part expression reading both `M` and `H` is still a pure function of
two replayable scalars; bit-identical replay holds (A2 case d is right). The *boundary* of the
"transformation as a unit" dissolves (A3 e2 is right: pausing `M` does not pause `H`, so
whole-unit pause is a lie for that part) — but **determinism is not the casualty; control
coherence is.** I will not overclaim a determinism break where there is only a control-semantics
break. (One real determinism caveat the frames mostly missed and A1 half-caught: the saturating
recurrence and any self-referential `expr` are *path-dependent*; running `M` backward retraces
the dynamical path, not the forward visual path — "reverse = clean rewind" is an authoring
property of affine/time-invariant exprs only, never a substrate guarantee. Fine as long as no
one *claims* the guarantee. A3's `elapsed` escape hatch is a genuine footgun: any part reading
`elapsed` is silently non-reversible.)

---

## Synthesis B — "coupling is a generic edge at the lowest dominating scope; flow is a consumer library reading metadata"

### B.1 The sharpest breaking case: a cross-body coupling is a per-tick distributed-consensus barrier, and the frames modeled it as a static row

All three B-frames converge on: the coupling is **a row/edge at the lowest log scope dominating
both parts** (B1 `World.couplings`; B2 world-level connection table; B3 scene-log relation), and
flow is computed by a consumer reading *both* endpoints' metadata + the relation. They treat the
edge as **static topology** — "just a row, fully serializable, no closures" (B1 case f). That
framing hides the lethal part.

**Constructed input (multiplayer, the project's stated architecture: self-hosted, deterministic,
replayable; bodies as portable characters).** Peer P1 hosts body A; peer P2 hosts body B. They
couple A.member ↔ B.orifice. A fluid act pushes `Q` while, concurrently, a transformation drives
`A.member.caliber_mm 38→52` (size changing every tick) and `B.orifice.openness` oscillates with
arousal. The fitment library (B3 §3) computes, **each tick**:

```
tightness(t) = sigmoid((caliber_A(t) − effective_bore_B(t)) / k)
delivered(t) = Q(t) · tightness(t);   leaked(t) = Q(t) − delivered(t)
B.orifice.milk += ∫ delivered(t) dt
```

`delivered` is an **integral over a product of two functions owned by two different peers**,
each evolving on its own logged timeline. For the result to be deterministic and identical on
both peers, the integral must be evaluated on a **common tick discretization with both bodies'
state synchronized to the same logical time**. That means:

1. **Neither body can advance its simulation independently across the coupling.** To compute
   `B.orifice.milk(t+dt)`, peer P2 needs `caliber_A(t)` — P1's *moment-to-moment* state. The
   coupling is a **synchronization barrier**: A and B must step in lockstep (or rollback-resync)
   for the duration of the coupling. The frames' "lowest dominating scope" answer names *where the
   row lives* but silently requires that **the derivation at that scope interleave both bodies
   tick-by-tick** — which in a self-hosted two-peer topology is distributed consensus on tick
   ordering, the hardest problem in the engine, introduced by *one row*.
2. **"A body is a self-contained / independently serializable derivation" is false** the instant a
   coupling exists. B3 strain 4 admits "a body is no longer a closed derivation"; B1's "pick two"
   admits couplings don't survive single-body export. But none priced the *active-session* cost:
   it is not merely that export is awkward — it is that **`B.orifice.milk(T)` is not computable from
   B's log + seed at all.** It is a function of A's entire caliber timeline. Under the substrate's
   own purist law (`state = f(seed, log)`, "never store the world," B3's grounding), body B *has no
   independent log*; only the *scene* has one. So "portable character" and "deterministic cross-body
   coupling" are mutually exclusive — exactly the goal-level contradiction the frames waved at but
   did not detonate.

**Verdict: survives as topology, breaks as a *dynamical distributed system*.** The edge-as-relation
factoring is correct and the frames' replay reasoning is locally sound *within one scene log*. What
they all missed — because they all framed flow as "a consumer reads the row + metadata," a **one-way
read** — is that flow across a cross-body coupling is a **per-tick mutual, bidirectional dependency**
that converts two independent sub-derivations into one inseparable lockstep system. **Revision:**
the substrate must explicitly state that a cross-body coupling **fuses the two bodies' simulation
into a single deterministic timeline for the coupling's lifetime** (lockstep or rollback-netcode),
and that fluid transfer must be defined as a discretized per-tick exchange on that fused timeline,
*not* an after-the-fact integral. This is a netcode/architecture commitment, not a metadata detail
— and it is the real cost the "it's just a row" framing concealed.

### B.2 Second breaking case (the cross-synthesis seam neither side could see): reversible transform of a coupled, then removed, part forces a scope violation

This breaks **only when A and B are composed**, which is why no single frame caught it — each was
scoped to its own problem.

**Constructed input.** A.member is coupled to B.orifice (row in scene log, per B). A *reversible*
transformation (Synthesis A) on body A `Remove`s A.member mid-flow. Per Synthesis A's reversibility,
the removed node is **tombstoned, retained by the transformation for later reverse** (A1 strain 3).
Per Synthesis B, removing the part leaves the coupling row with a dead ref, **reaped/tombstoned at
scene scope** (B1 lazy+tombstone; B2 sever+resolve seal).

Now reverse the body-A transformation an hour later. Synthesis A restores A.member (un-tombstones
the node — it must, or reverse is a lie). But the **coupling** that referenced it lived at *scene
scope* and was reaped there. To make reverse faithful, restoring A.member must **also restore a
scene-level coupling row** — i.e. a **body-scoped reverse operation must reach up into and mutate
parent-scope state.** That is precisely the `body → world` layering dependency / facade-hole that
*every* B-frame engineered the scope rule to forbid (B1 "layering smell," B3 strain 4 "the load-
bearing invariant … easiest to violate"). Synthesis A's reversibility requirement and Synthesis B's
scope invariant are in **direct contradiction** at this seam, and neither synthesis can resolve it
alone because each owns only one side of the scope boundary.

**Verdict: an unhandled cross-synthesis contradiction.** Revision: reverse must be defined as a
*forward* scene-scope action (a new log event at scene scope that re-establishes the coupling),
never as a body-local un-tombstone — meaning "reverse" is **not** body-local for any coupled part.
That, in turn, re-confirms B.1: the coupling fuses scopes, so even *undo* is scene-scoped.

### B.3 What survives

- **"Ports/portals/polarity dissolve" survives** (attack (d)). Position-independence is free once
  the edge addresses by id (B1 case b); "portal" reduces to a wide-open coupling (B3 §4c);
  member/orifice **polarity** genuinely dissolves into `role` metadata the fitment lib reads, and
  flow *direction* is derivable from a reservoir gradient (high→low) rather than a blessed end. The
  one load-bearing thing they came *closest* to dropping is **passive/continuous gradient flow**: B3
  models flow only as "an act emits `Q`, the splitter routes it," which cannot express a standing
  tube whose flow is driven by the pressure difference across it with no act. B1's "consumer reads
  both reservoirs and computes transfer" *can* express it. So the act-driven-splitter framing (B3)
  is too narrow, but the edge+consumer framing (B1) covers it. Minor, not fatal — polarity really
  does dissolve.
- **Mid-coupling transform with size changing continuously (attack (b)) survives within one scene
  log.** B3 case e is right that tightness re-derives from `profile-as-of-T` and the delivered fluid
  is a deterministic fold of `fluid_delta`s — *single-body / single-log*. Its teeth are entirely in
  the multiplayer case (B.1), where the same per-tick re-derivation becomes a cross-peer barrier.

---

## The ONE shared blind spot across all six frames (most dangerous)

**All six frames resolve every hard case by relocating *where state lives* — and none provides a
model for *cyclic, same-tick mutual dependency*, because all six independently assumed the system
is a one-way DAG of reads.**

The agreement that blinded them: *"current state is a pure function re-derived each tick from a
clean acyclic source"* — parts read one master (A); a consumer reads topology + metadata (B); a body
derives from its log. Every frame's clean win comes from a **one-way read**, and every hard case they
hit, they answered by **moving ownership/scope**: A's same-property collision → "a deterministic
reducer keyed by `(node, prop)`"; A's hormone case → "make it a separate driver"; B's cross-body
problem → "the row lives at the lowest dominating scope." **A relocation of state never resolves a
cycle.** And the actual hard cases are *cycles*:

- **A is a cycle:** two transitions over one property where TF2's `from = snapshot` reads the reduced
  value that TF1 is simultaneously producing (B.1 above) — output feeds input within the tick.
- **B is a cycle:** cross-body flow where `delivered` depends on both bodies' current state and writes
  back into both bodies' reservoirs — a bidirectional, same-tick mutual dependency (B.1 above).
- **The hormone case is a cycle** the frames assumed away: a hormone driver `H` that *responds to* the
  body state the transformation is changing (arousal rising *because* a part grew) closes the loop
  `M → part → H → part`. The frames only considered `H` *exogenous*.

A "deterministic reducer" and a "lowest-common-scope relation" are both **DAG-shaped answers to
cycle-shaped problems.** Worse for the project's non-negotiable: the frames *claim* bit-identical
replay, but that claim silently assumes acyclic evaluation. Under a genuine same-tick cycle,
"re-evaluate from current progress each tick" has an **evaluation-order dependence** (which transition
reads the shared slot first, in what order the reducer folds, when each body samples the other) that
**no frame pins down** — and an order-dependent result is, by the substrate's own §5.5 standard, a
determinism *defect*, even if it happens to look stable in the common case. The cycle may also have
*no* fixpoint (TF1 wants 800, TF2 wants 100, mutually snapshotting → oscillation) or multiple.

**The dangerous part is that the convergence itself manufactured the blind spot.** Six frames from
six framings all reached for a one-way primitive *because* one-way is clean, and unanimity read as
confidence. The thing they agreed on — derivation purity / acyclic reads — is exactly the assumption
the breaking cases violate. Before either synthesis is built, the substrate needs an explicit,
deterministic answer to: **when contributions to one quantity (or one flow) are mutually dependent
within a tick, what is the seeded evaluation order / fixpoint rule, and is it proven order-independent?**
Without it, "deterministic and replayable" is asserted past the evidence.
