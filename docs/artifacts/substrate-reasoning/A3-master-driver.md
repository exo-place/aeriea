# A3 — Frame: ONE master driver, per-part expressions remap it

Single-pass reasoning. Frame assigned: there is exactly one master progress
per transformation; every part's transition is an expression over that master
(plus elapsed/vars) with per-part gating/offset/curve. Controlling the master
controls all parts.

## Shapes

**The master driver.** A single scalar `M`, the *integrated* progress of the
transformation unit — NOT raw elapsed. Each deterministic tick:

```
M += direction * speed(elapsed) * dt
direction ∈ {-1, 0, +1}      # the ONLY control surface
M = clamp(M, 0, 1)           # or unclamped if the TF overshoots/loops
```

`M` is self-referential (next value reads current value) — this is exactly the
"feed current progress back in" mechanism in the substrate brief. Pause/reverse
fall out of `direction`. The host advances *only* `M`. Everything else is a pure
function of `M`.

Why integrated, not `M = elapsed/duration`: elapsed only grows, so it cannot be
driven backward. To reverse you must reverse the *progress*, and progress must
therefore be a state variable, not a clock readout.

**A per-part expression.** Each part stores a pure remap of `M`. The canonical
shape is affine-gate → curve:

```
local_i  = clamp((M - start_i) / (end_i - start_i), 0, 1)   # gate + offset + rescale
p_i      = curve_i(local_i)                                  # easing / self-ref shape
```

Then the part's authored *step* formula consumes `p_i ∈ [0,1]` to interpolate
attachment positions and metadata. `start_i` is the gate ("legs start later"),
`(start_i,end_i)` is offset+window, `curve_i` is shape — including
**non-monotonic** shapes (swell-then-shrink as `M` rises). add/remove primitives
are gated the same way: `add` fires when `local_i` first exceeds 0; its inverse
fires when `local_i` returns to 0.

**Discipline (load-bearing):** part expressions read `M`, never raw `elapsed`,
or reversibility breaks for that part (see strain). `elapsed` is available but is
an escape hatch that voids the reverse guarantee.

## Control propagation

Because every `p_i = g_i(M)` is a pure function of one scalar:

- **Pause** = `direction := 0`. `M` frozen ⇒ every `p_i` frozen. No per-part
  bookkeeping.
- **Reverse** = `direction := -1`. `M` decreases ⇒ every `p_i` retraces its own
  curve. Gated parts un-gate sensibly: as `M` falls below `start_i`, `local_i`
  clamps to 0, the part retracts, and its `add` is undone by the symmetric
  `remove`.
- **Stop** = pause, optionally snap `M` to 0 or 1.
- **Replay** = deterministic: `M`'s trajectory is fully determined by
  `(start_time, the control-event log of direction changes, speed expr, fixed
  dt)`. Same log ⇒ same `M` sequence ⇒ identical parts. No RNG.

## Cases

**(a) become-a-taur.** `M: 0→1`.
- torso: `start=0, end=0.6` ⇒ `local_torso = clamp(M/0.6,0,1)`.
- legs (added hindquarters): `start=0.3, end=1.0` ⇒
  `local_legs = clamp((M-0.3)/0.7,0,1)`; `add` hindquarter segments when
  `local_legs > 0`, drive their growth by `curve_legs(local_legs)`.
- At `M=0.45`: torso `0.75`, legs `0.214`.

**(b) pause.** `direction:=0` at `M=0.45`. torso held at `0.75`, legs at
`0.214`. Nothing else to do.

**(c) reverse from 60%.** `M=0.6`, `direction:=-1`. legs `local = clamp(0.3/0.7)
= 0.43`; torso `local = 1.0` (already capped). As `M→0.3`, legs `local→0` and the
hindquarters retract then `remove`; below `0.3` they are gone. torso retraces from
`M=0.6` down. All parts follow because each is `g_i(M)` and `M` is moving down —
no part needs to "know" it is reversing.

**(d) replay identical.** Same direction-change event log + fixed dt reproduces
the exact `M` trajectory and therefore every `p_i`. Bitwise replay.

**(e) THE HARD ONE — genuinely independent schedules.**

Split into two sub-kinds, because the frame answers them oppositely.

*e1 — different shapes/orderings on one timeline.* "Legs must fully finish before
torso even begins," plus a tail that swells then shrinks. This is NOT a problem:
legs `(0,0.3)`, torso `(0.3,1)`, tail `curve = sin(π·local)`. All are functions
of one `M`. The frame handles arbitrary per-part *shape and ordering* cleanly —
"independent-looking" but still one clock. This is the frame's real strength.

*e2 — different causal clocks.* A part whose timing is driven by a **hormone**
`H(t)` that integrates on its own (rises while you sleep/eat, asynchronous to the
visual TF). Express it as `p_hormonepart = g(H)`. Now:
- `H` is not a function of `M`. Pausing the master (`direction:=0`) does NOT pause
  `H` — the hormone keeps secreting. The "master controls all parts" invariant is
  **false** for this part.
- Reversing `M` should retract the master-driven parts, but you cannot
  *un-secrete* a hormone. `g(H)` must not reverse. So master-reverse and this
  part's correct behavior **actively conflict**.
- You could write `p = g(M, H)`, but then the part is no longer purely
  master-driven and the clean propagation guarantee is gone for it.

**Verdict on (e):** a single master expresses *e1* fully and *e2* not at all.
Genuinely independent *schedules in the sense of independent causal clocks* break
the frame.

## Honest strain — where one master breaks

1. **"Independent" is ambiguous, and the frame only covers one meaning.** One
   master captures *any schedule that is a pure function of a single shared
   progress scalar*: arbitrary gates, offsets, windows, non-monotonic curves,
   any ordering. That is genuinely expressive — far more than "monotonic
   offsets." But it is still ONE timeline with ONE control. Parts are
   reparametrizations of the same clock; they cannot pause, reverse, or replay
   *independently*.

2. **The break is causal independence, not shape independence.** The moment two
   parts must respond to controls or external events *differently* — one driven
   by an asynchronous variable (hormone, ambient temperature, another TF's
   progress), one part you want to reverse while another keeps going — a single
   master cannot represent it without either (a) reading a non-master variable
   (which voids "master controls all"), or (b) introducing a second driver.

3. **This actually defines the unit boundary cleanly.** The set of parts sharing
   a master IS the controllable transformation unit. "Genuinely independent
   schedule" = "belongs to a different control unit" = "different master." So the
   right reading is: **one master per control-unit**; the frame is correct
   *within* a unit and honestly *delegates across units to multiple drivers*.
   The single-master frame does not so much fail as reveal that two independently
   controllable things were never one transformation. Where the brief's case (e)
   insists they ARE one unit yet schedule-independent, the frame cannot hold both
   and collapses toward the multi-driver frame.

4. **The `elapsed` escape hatch.** Part expressions may read `elapsed`, but
   `elapsed` only grows, so any part using it is non-reversible. Reversibility is
   a *convention* (read `M`, not `elapsed`), not a structural guarantee — a real
   footgun.

**Bottom line.** One master is the right primitive for a *single controllable
unit* and is more expressive than it first looks (all shapes/orderings of one
clock). It is honestly insufficient the instant parts need independent causal
clocks or independent control; there the design must admit multiple drivers, and
the master-per-unit reading is the graceful way to say so.
