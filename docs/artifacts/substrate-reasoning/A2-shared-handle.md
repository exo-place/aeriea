# A2 — The shared-handle frame: no transformation object

Status: **Substrate reasoning, one frame of several. Not a decision.**

## The claim of this frame

There is **no transformation object**. A "transformation" is not a thing the engine stores;
it is an **emergent set** — the set of per-part transitions that happen to read the same
control handle. Per-part transitions are fully independent records, each carrying a reference
to a **shared driver handle**. "Stop/pause/reverse the whole thing" is one write to that handle.
"Find the whole thing" is a query: *all transitions whose handle == H*. Nothing owns the set;
the handle-id is the only thread tying it together.

This is deliberately the dual of the owning-object frame. The bet is that the owning object is
bookkeeping you don't need — a layer that exists only to fan a stop/reverse out to its members,
which a shared variable does for free. The honest job below is to find where that bet fails.

---

## 1. Data shapes

### 1.1 The handle (shared driver)

A handle is a **named scalar in the driver timeline** (the substrate already has driver
timelines — see `dynamical-transformation.md` §3). It is *not* a new kind of object; it is a
driver whose convention is "this exists to control a cohort of transitions."

```
# In the per-body driver timeline (append-only, full-time-ordered, derived from action log)
"tf:7af3" : [ {"t": 3600, "v": 0}, {"t": 3600, "v": 100}, {"t": 90000, "v": 0} ]
#            created at baseline   started (rate→+)        paused (rate→0)
```

- The handle key `tf:7af3` is a **content-opaque id**, minted deterministically at the start
  action (`handle_id = hash(action_id)` — a function of the action log, so replay-stable). The
  `tf:` namespace is convention, marking it as a cohort controller rather than a hormone.
- The handle carries a **rate**, not a progress. Its value `v` is the *speed and sign* the
  cohort advances at: `v>0` forward, `v=0` paused, `v<0` reverse. This is the one global knob.
- A handle is just a driver: piecewise-constant, replayable, costs nothing when unread.

### 1.2 A per-part transition

Each part-level transition is an independent record living **on the segment** (`Segment.transitions[prop]`),
exactly as the base substrate stores them. The only addition is `handle` + an offset:

```
Segment("#leg_l").transitions["pose"] = {
  "from":   "snapshot",            # captured at the transition's own start event
  "to":     {"value": ...},
  "interp": "lerp",
  "handle": "tf:7af3",            # THE shared thread — the only cohort linkage
  "offset": 7200,                 # this part starts 2h of handle-time after the handle's t0
  "gain":   1.0,                  # optional per-part rate scale (legs slower than torso)
  "prog_base": 0, "base_t": 3600  # progress baseline (as in base substrate)
}
```

Progress for this part is read as a closed-form integral of the **handle's** value, shifted by
the part's offset:

```
local_drive(t)  = handle_value(t − offset_in_handle_time)   # see §3 for the exact shift
progress(T)     = clamp01( prog_base + gain · ∫_{base_t}^{T} local_drive(τ) dτ )
value(T)        = interpolate(from, to, progress(T))
```

Because the handle is piecewise-constant, the integral is the same closed-form rate×duration
sum the base substrate already uses (§5.2 there). The part reads the handle; the handle knows
nothing about the part. **All coupling is one-directional: transition → handle.**

### 1.3 What a "transformation" is

It is **not stored anywhere**. It is the predicate `transition.handle == "tf:7af3"`. To
materialize "the whole," you query every segment's transitions for that handle. The set is
recomputed, never persisted. (See §4 on the cost of that.)

---

## 2. Per-part timing without an object: offset against the handle

Start-later is expressed **entirely against the shared handle**, two equivalent ways, and the
choice matters for the honest tensions:

- **(A) Offset in handle-time** (shown above): the part reads `handle_value(t − offset)`. The
  handle starts climbing at its t0; the legs, with `offset = 7200`, see the climb 7200s later.
  One handle, parts phase-shifted. Clean, but "handle-time" is a slightly subtle frame (the
  handle is a clock the parts read at a delay).
- **(B) Per-part gate threshold**: the part has `start_when: handle ≥ 30`, and its progress
  rate is zero until the *handle's accumulated value* crosses the gate. The torso gates at 0,
  the legs at 30. As the single handle ramps, parts switch on at different handle levels.

Both keep the **single control point** intact: there is exactly one knob (the handle), and
per-part timing is a pure function of that knob plus a per-part constant. Neither introduces a
second source of truth for "when." I lean (B) for authoring legibility (a threshold reads like
intent) and (A) for clean reversal symmetry (offsets reverse trivially; gates need care, §3c).

---

## 3. Stop / pause / reverse — all are one write to the handle

Every whole-unit control is **a single logged action that sets the handle's value**. No fan-out,
no iteration over members at write time.

- **Pause whole:** `set handle "tf:7af3" = 0` at time T. Every part's `local_drive` goes flat;
  every progress freezes at its current closed-form value. One log entry pauses an arbitrary
  number of parts.
- **Resume:** `set handle = 100`. Parts resume from frozen progress (their `prog_base` is
  re-based at the resume event, or — cheaper — left alone since the integral of a zero interval
  contributes nothing).
- **Reverse from 60%:** `set handle = −100` at the instant the cohort is at 60%. Now every
  part's `local_drive` is negative, every progress *decreases*, every `value` interpolates back
  toward its own `from`. Parts that started later (higher offset / later gate) are at *lower*
  progress and reach `from` sooner — the reversal naturally unwinds in opposite order, which is
  usually what you want (last-grown unwinds first). No per-part reverse bookkeeping: reversal is
  the sign of one shared scalar.

The whole-unit guarantee falls out of a single invariant: **every member reads the same handle,
so any change to the handle is simultaneously a change to every member, atomically, in one log
event.** That is the central strength of this frame — whole-control is *literally free* because
the members never stopped being individually-driven; they just share their driver.

---

## 4. Addressing "the whole" without an owner: the query

This is the load-bearing question for a no-object frame. Options, with honest costs:

- **(Q1) Scan-on-demand.** "The whole" = scan all segments, collect transitions where
  `handle == H`. O(parts) per enumeration. Fine for *control* writes (you don't even need to
  enumerate — you write the handle, not the members). Needed only for *introspection* ("show me
  this transformation's parts / overall progress"). Acceptable because introspection is rare and
  bodies are small (tens of segments).
- **(Q2) Handle registry index.** Keep a **derived** `handle → [segment_ids]` index, rebuilt
  from the graph (not authoritative — a cache of the scan). Makes enumeration O(members). But
  this index is *exactly the owning object's member-list creeping back in* — see §6. The honest
  read: if you need this index, the no-object frame has lost its advantage and you should
  reconsider the owning object.

"Overall progress of the whole" is **not well-defined without a policy**, because parts have
different offsets/gains and are at different progresses. You must pick: min-progress (the
laggard), mean, or the torso-as-representative. The owning-object frame would store one
canonical aggregate; here you compute it from the set under an explicit policy. Neither is
clearly better; the no-object frame just forces the policy to be named at the query, which is
arguably honest.

---

## 5. Cases

### (a) Become-a-taur, legs after torso
One start action mints handle `tf:c01a`, sets it to `+100`, and writes per-part transitions:
`#torso` (offset 0), `#hips` width (offset 0), `#leg_l/#leg_r` pose (offset 7200), and grafts
`#barrel`/front-legs as new ids with 0→full magnitude transitions also reading `tf:c01a` at
offset 7200. The handle ramps; torso reshapes immediately, legs/barrel begin 2h later. **One
handle, six+ transitions, per-part phasing via offset.** Grafts are still discrete log events
at the part's effective t0 (graft-at-zero), magnitude driven by the shared handle. ✔ works.

### (b) Pause the whole
`set tf:c01a = 0`. Every reader flattens. Torso (already advanced) and legs (barely started)
both freeze in place. One log entry. ✔ works, and is the cleanest case for this frame.

### (c) Reverse from 60%
`set tf:c01a = −100` when the cohort representative is at 60%. All readers reverse. Legs (lower
progress) hit `from` and their grafts shrink-to-zero-and-drop first; torso unwinds to biped
width; barrel shrinks out. ✔ works — **with one caveat for gate-based timing (§2B):** a part
gated `start_when handle ≥ 30` must also *un-gate* symmetrically on the way down, or it freezes
instead of reversing. Offset-based timing (§2A) reverses cleanly without this caveat. This is a
real reason to prefer offsets if reversal fidelity matters.

### (d) Replay identical
The handle is a driver in the timeline (function of action log); offsets/gains are constants in
the transition records (function of action log); progress is the closed-form integral (§1.2).
Nothing here is stored mutable or query-order dependent. Same `seed + action log` → same handle
timeline → same per-part integrals → bit-identical. ✔ The no-object frame is, if anything,
*more* obviously replay-safe: there is no aggregate cache to drift, because there is no object.

### (e) A part in two transformations (two handles) — the sharp case
A segment's `transitions` is keyed by **property**, so a part can host two transitions on two
properties, each reading a different handle: `#breast_l.transitions["volume_ml"]` reads
`tf:growth`, `#breast_l.transitions["material"]` reads `tf:chitinize`. **No conflict — different
axes, different handles, independent reads.** This composes beautifully.

**The conflict is when two handles drive the *same property*.** Two transformations both want
`#breast_l.volume_ml`. Now `transitions["volume_ml"]` can hold only one record → one handle. The
frame **cannot represent a property under two simultaneous shared controls** without a tiebreak.
Options, none free:
  - **Last-writer-wins:** the second transformation's start overwrites the first's transition on
    that property; the first transformation is now *silently missing a limb*. Its handle still
    controls its *other* parts. So "the whole" `tf:growth` has been **partially poisoned** by
    `tf:chitinize` claiming one of its parts — and **nothing recorded that**, because no object
    tracked membership. This is the frame's worst failure: a transformation can be hollowed out
    member-by-member with no error and no audit trail.
  - **Allow a list of records per property + a combine rule** (sum the deltas, or priority): now
    each property holds `[{handle, ...}, {handle, ...}]`. This works, but the moment you need
    per-property membership lists, you're maintaining the cohort structure inline — the object's
    bookkeeping has reappeared distributed across segments (§6).

So: orthogonal-axis sharing is a genuine strength; **same-property contention is where the
no-object frame either silently corrupts or grows the object back.**

---

## 6. Honest strain (the part that matters)

**Does "no object" actually remove bookkeeping, or relocate it?** Mostly relocate. The owning
object's job was: hold the member set, fan out control, define aggregate progress, and bound its
own lifetime. This frame deletes the *member set* and gets *fan-out control* for free (the
shared driver). But it pays that back elsewhere:

- **GC / orphaned handles.** No object owns the handle, so nothing knows when it is "done." A
  handle is finished when *every reader has either completed (progress pinned 0 or 1 and not
  reversible) or been removed.* Determining that **requires the very scan (Q1) the frame wanted
  to avoid.** Without it, the driver timeline accumulates dead `tf:*` entries forever. They're
  cheap (unread = free) and replay-harmless, but they are **leaked controllers** — and the only
  honest GC is a periodic scan that proves no transition reads handle H, then prunes it. So the
  object's lifetime-management didn't vanish; it became a sweep. (Mitigant: handles are pure
  driver entries; a "leak" is timeline bloat, not a dangling pointer — strictly less dangerous
  than an orphaned object, but still unbounded growth.)

- **Enumeration reliability.** "The whole" is only ever as reliable as the scan. If a part's
  transition is overwritten (case e) or its segment removed, it silently drops out of the set
  with no notification to the "transformation," because there is no notified party. The owning
  object would at least hold a stale member entry you could detect; here the absence is
  invisible. **The set is eventually-consistent with reality and has no integrity check** unless
  you add one — which is membership tracking — which is the object.

- **Hidden global.** The handle *is* a body-scoped global variable. Two unrelated content
  systems that both happen to mint `tf:` handles are fine (ids are unique), but a handle is
  reachable/writable by **anything that knows its id**. There is no capability boundary: the
  cohort is controlled by a string. The owning-object frame can hand out a typed handle with
  attenuated authority; here authority *is* knowledge of the id. For a deterministic single-body
  sim this is acceptable (no adversary inside the body), but it violates the ecosystem's
  capability-security instinct, and I won't pretend otherwise.

- **The "no aggregate" tax.** Every introspective question about the whole (overall %, ETA, "is
  it paused") requires a scan + a named aggregation policy. Frequent introspection (a UI showing
  transformation progress bars) turns this from "rare scan" into "scan every frame," at which
  point you build the Q2 index, at which point you have rebuilt the object's member list as a
  cache. **The frame is cheapest exactly when you never look at the whole, and degrades toward
  the object the more you introspect.**

---

## 7. Verdict from inside this frame

**Where it genuinely wins:** whole-unit pause/reverse is *free and atomic* (one driver write,
no fan-out), replay-safety is *more* obvious (no aggregate cache to drift), per-part timing is a
clean per-part constant against one knob, and orthogonal multi-transformation on different
properties composes with zero special handling. For the common case — start a cohort, ramp it,
pause/reverse it as a unit, never introspect mid-flight — this is simpler than an owning object.

**The fatal tension:** the frame's advantage is conditional on *never needing the member set*.
Three forces all demand it — GC (which handles are dead?), integrity (did a part get silently
stolen?, case e same-property contention), and introspection (overall progress) — and each one,
satisfied, rebuilds the owning object's bookkeeping as a derived index or a periodic scan. So
"no object" does not *eliminate* the transformation object; it **defers and distributes** it,
trading a clean owned member-list for a string-keyed global plus a sweep. That trade is good
when introspection and contention are rare, and bad when they aren't — and the same-property
silent-corruption case (e) is a real correctness hazard, not just a cost.

The honest one-liner: **this frame proves whole-unit control needs no object, but lifetime,
integrity, and aggregation arguably do — and those are most of what an object was for.**
