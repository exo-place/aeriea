# A1 — Transformation as a first-class OWNING object

Frame: a transformation is a first-class object that **owns** its per-part
transitions. Control (stop/pause/reverse) acts on the object and fans to every
owned transition; per-part timing (start-offset, per-part expression) lives
under the object. This pass develops that frame to where it strains, and names
the strain rather than smoothing it.

## Core mechanism — one master clock, fanned to parts

The trick that makes whole-unit control *and* per-part independence both fall
out of one mechanism: the object owns a single **master clock** `U`, and every
per-part expression reads its **local elapsed** time as `U - offset_i`. Control
is implemented as *the advance rule for `U`* — nothing more. Pause freezes `U`;
reverse runs `U` backward; stop freezes `U` and marks the object inert. Because
all parts derive their input from the one clock, one control op on the object is
automatically felt by all parts. Per-part independence survives because each
part has its own `offset_i` and its own authored `expr_i`/`step_i`; the only
thing they share is the clock they read.

This is fully consistent with the substrate's "current-progress-as-input" rule:
each part still stores its `progress` and is re-evaluated from
`(progress, local_elapsed, vars)` each tick. The clock just supplies the
`local_elapsed` term in a way the *group* can steer.

## Data shapes

```
Transformation {            // first-class, in the action log; id = log index
  id        : TxId          // deterministic, stable across replay
  t0        : SimTime       // sim-time the apply-action landed
  control : {
    mode    : Play | Paused | Reversing | Stopped
    clock   : f64           // U — master unit-elapsed; the ONLY thing control touches
    rate    : f64           // optional authored unit rate multiplier (default 1)
  }
  parts     : [PartTransition]   // OWNED; lifetime nominally bound to the object
  claims    : set<(NodeId, PropKey)>   // what this tx writes — for arbitration (see strain #1)
}

PartTransition {
  target    : NodeRef | AttachmentRef
  primitive : TransformInPlace | Add | Remove
  offset    : f64            // start-offset, in clock units  (per-part timing)
  expr      : Expression     // progress = f(self_progress, local_elapsed, vars...)
  step      : Expression     // property value = g(progress)  (start→end mapping)
  progress  : f64            // cached recurrence state; derivable, not ground truth
  staged    : NodeSpec?      // for Add/Remove: the node to materialize / tombstone
}
```

Ground truth for replay is **not** `progress` or `clock` — those are caches. The
ground truth is the action log: `apply(tx, authorSpec)@t0`, then
`setMode(...)@tk` events, integrated against the deterministic dt stream. Clock,
local-elapsed, and progress are all pure functions of that, so they reconstruct
exactly.

## Tick

```
advance(tx, dt, vars):
  match tx.control.mode:
    Play      : tx.control.clock += dt * tx.control.rate
    Reversing : tx.control.clock  = max(0, tx.control.clock - dt * tx.control.rate)
    Paused    : pass
    Stopped   : return                       // inert
  U = tx.control.clock
  for p in tx.parts:
    le = U - p.offset
    if le <= 0:                              // not started yet, or reversed back below its offset
      p.progress = 0
      settle(p)                              // Add → unstaged/hidden; Remove → node restored
      continue
    p.progress = eval(p.expr, { self: p.progress, elapsed: le, ...vars })
    apply(p, eval(p.step, { progress: p.progress }))
```

## Cases

**(a) Become-a-taur, legs start after torso.** One `Transformation`. `parts`:
torso `TransformInPlace` with `offset=0`; hindquarters + legs as `Add` with
`offset=3.0`. While `U < 3.0` the leg parts sit at `progress=0`, staged-hidden.
Torso reshapes from `t0`. When `U` crosses 3.0 the legs begin growing on their
own `expr`. All three are one owned group. Per-part lateness is just a scalar
offset; nothing about the object had to special-case it.

**(b) Pause mid-way.** `setMode(tx, Paused)`. `U` freezes at `U*`. Every part's
`le = U* - offset_i` is now constant, so every `progress` holds — torso holds
partial, a mid-grown leg holds partial, a not-yet-started leg holds 0. One op,
fans to all, no per-part bookkeeping.

**(c) Reverse from 60% (all parts).** `setMode(tx, Reversing)`. `U` decreases.
Pleasant emergent property: because offsets gate *both* directions, the legs
(`offset=3.0`) hit `le <= 0` and retract to 0 *before* the torso finishes
reverting — the undo is the natural mirror of the staged do-order, for free.
`U → 0` ⇒ all parts at 0, body back to baseline.

Honest caveat: "reverse retraces the same visual path" holds cleanly only when
`expr` is effectively a function of `elapsed` (or a symmetric recurrence). For a
genuinely self-referential / hormone-coupled `expr`, running the clock backward
retraces the *dynamical* path, which need not mirror the forward path. The
substrate stays deterministic either way; whether it *looks* like a clean rewind
is an authoring property, not a substrate guarantee. I won't claim more.

**(d) Replay from seed+log.** Log = `apply(tx,spec)@t0`, `Paused@t1`,
`Reversing@t2`, … Re-integrating the same dt stream reproduces `clock`
identically; `expr`/`step` are pure; the `progress` recurrence is therefore
identical tick-for-tick. `id` = log index, so all references resolve the same.
Exact.

**(e) Two transformations over overlapping parts.** tx1 and tx2 each own a
`PartTransition` writing `(S, length)`. Each has its own clock and progress —
*that part is fine*. But the substrate node `S.length` is **one value**, and the
owning-object frame gives no answer to who wins. This is the frame's real crack
(strain #1).

## Where this frame strains — honestly

**1. Ownership of a transition is not ownership of the target (fatal-ish).**
The object owns the *transition* (intent + control handle), not the *property*
it mutates. Two objects can own transitions over the same `(node, prop)`, and
the property is shared mutable state the objects cannot arbitrate among
themselves. Resolution must live *outside* the objects: a deterministic reducer
keyed by `(node, prop)` that folds all live `claims` in `id` order (last-writer,
or an authored compose). So the object is honestly an **intent grouping + group
control handle**, not an owner of body state. The frame's name oversells what it
owns.

**2. Lifecycle / "done" is not intrinsic.** Under `Play` you'd call tx done when
`U` passes the max offset and every `expr` saturates — but a self-referential,
oscillating `expr` may have *no* terminal. So "done" needs an authored terminal
predicate, not a structural one. Worse: you usually must **not** destroy a
completed tx, because the player may want to reverse it an hour later — that
requires the object (and its clock history) to persist. Keep-alive ⇒ unbounded
accumulation of live transformation objects, each carrying claims the reducer
must scan every tick. Bake-and-destroy ⇒ you lose reversibility. There is no
free choice here; it's a standing tension between reversibility and bounded
state.

**3. Add/Remove couples node existence to object liveness.** A completed
`Remove` cannot truly delete the node if the tx may still reverse — the node
must be tombstoned and retained *by the object*. So generic-substrate node
lifetimes get entangled with transformation-object lifetimes. The owning frame
*introduces* exactly the kind of cross-coupling the generic substrate was meant
to avoid.

**4. Per-part independence is partly illusory.** Parts are independent in offset
and shape, but every part expression must be authored to read the object's
clock variable — they presuppose the owning object's clock contract. The shared
clock is simultaneously the source of whole-unit control *and* a coupling the
parts cannot escape. The frame's central strength and its central coupling are
the *same mechanism*; you cannot keep one and drop the other.

Net: the master-clock-owns-the-parts mechanism makes (a)–(d) clean and cheap,
but case (e) plus lifecycle (strains 1–3) show the object honestly owns
*control and intent*, not *body state* — and that gap forces an external
arbitrator and a reversibility-vs-bounded-state decision the frame itself can't
make.
