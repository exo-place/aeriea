# Design: Dynamical transformation — bodies as driver-driven state machines

Status: **Design pass — no code. Not green.** Awaits the user's express approval before any
implementation. New work lands under `docs/FEATURES.md` → Not green.

**Relationship to `transformation-system.md`: this EXTENDS it; the graph is UNCHANGED.** The
compositional segment graph (`{material, covering, props, tags, children}`, three open axes,
convention tags, structural/ordinal targeting, the deterministic seeded applier, the
TFHolder on `sim_clock`, reversibility/undo, description-from-state) stands exactly as
written. This doc reframes **how continuous scalar PROPERTIES evolve** — and nothing else.
Structure/topology (graft/remove/reparent, adding fingers/nipples) stays a discrete event.
It also extends `compound-parts-and-fluids.md`: fluids (lactation, seed, nectar) become
driver-driven production, not binary toggles — the worked example in §8.

Refs read: `transformation-system.md` (the settled graph + applier + holder; §3–§5 cited
throughout); `compound-parts-and-fluids.md` (fluids as per-segment integer state; the
lactation tie-in §5.4, here generalized); `simulation-depth-and-materialization.md` (the
per-query-cost / global-consistency crux that "very many inputs" lands in — §7 here grapples
with it honestly).

Aeriea principles honored: data over code at a seam; deterministic seeded sim; description
derived from state; **the discrete model is subsumed, not discarded** (retire-don't-deprecate
in the direction of generalization — the old op is the special case of the new one).

---

## 1. Status

- Design pass, **no code yet**, **Not green**, awaits the user's express approval.
- Extends, does not supersede, `transformation-system.md` and `compound-parts-and-fluids.md`.
  The body graph, the op vocabulary's **structural** ops, the applier, the holder, undo, and
  description are all unchanged. The delta is confined to **continuous scalar properties**
  (§9 states it precisely so a later rebuild knows exactly what changes).

---

## 2. The reframe (the thesis)

**Today** (`transformation-system.md` §4–§5), a transformation is a list of discrete
op-records — `prop_delta` / `fluid_delta` / `graft_subtree` / `set_material` — applied at
staged clock ticks. A staged TF is a step function: at each `stage_seconds` boundary the
applier rolls a delta and writes it. Between boundaries nothing moves; the property is a
piecewise-constant staircase, and "how a body changes over time" is encoded implicitly in
how many stages have fired.

**The reframe.** A body's **continuous scalar properties** — breast `volume_ml`, a tail's
`length_cm`, a fluid's production, "how chitinous" a region is — become **STATE VARIABLES**.
Each state variable's value at any time `T` is a **deterministic function of a set of INPUT
DRIVERS plus elapsed time**:

> `value(T) = F(drivers over [t₀, T], baseline, T)`

A **driver** is an open, user-named scalar input — `"estrogen"`, `"prolactin"`,
`"arousal"`, `"chitin_signal"`, or any custom name — exactly as open as tags / materials /
coverings already are (no enum, §3). A **transformation** is no longer "write a delta"; it is
**"set or modulate a driver."** The body then *evolves on its own* under that driver until the
driver changes again. An **effect** is a function from `(drivers, current state, time)` to how
state evolves — i.e. to a **rate**.

Time/elapsed is **one input among many**, not privileged. The driver set is the general
input; the clock supplies `T`.

### 2.1 Why this subsumes the discrete model rather than discarding it

The discrete ops are the **degenerate special cases** of the continuous law, and they stay in
the log as instantaneous events:

| old discrete op | new framing |
|---|---|
| `prop_delta` (instantaneous step) | a **driver impulse**: a state variable's value jumps at one log instant — the special case where the "rate" is a Dirac spike (an instantaneous offset), not a sustained rate. Identical result. |
| staged `prop_delta` over N ticks | a **sustained driver** held over an interval — the *general* case the staircase was approximating. The closed form (§5) gives the smooth value at any `T`, not just at tick boundaries. |
| `graft_subtree` / `remove_subtree` / `reparent` | **UNCHANGED** — a discrete structural event in the log. Topology is never a continuous variable. |
| `set_material` / `set_covering` (categorical) | **UNCHANGED as a discrete categorical set.** A *continuous* "chitin-ness" is instead modeled as a driver-driven scalar property `props.chitin` ∈ [0,1] that the describe layer bands; the categorical `material` field flips discretely when that scalar crosses a threshold (a discrete event the content emits), so both coexist. |

So: **structure/topology and categorical axis values stay discrete events**; **continuous
scalar properties become driver-driven**. The instantaneous `prop_delta` survives as
"impulse a state variable" — a zero-duration driver application. Nothing is lost; the
staircase becomes a special, coarse reading of a law that is now queryable at any `T`.

---

## 3. Drivers as open, user-defined variables (data shape)

A driver is a **named scalar input**, baked into no enum, governed by the same convention
discipline as tags (`transformation-system.md` §3.7). "A hormone is just a named driver" —
the engine interprets none of them; content agrees on `estrogen` / `prolactin` / `arousal`
and invents more freely.

Drivers live in a per-body **driver timeline** — a log, ordered by `sim_clock` full-time, of
when each driver was set/changed. The timeline is **derived from the action log** (each
driver change is a logged action carrying its full-time stamp), so it is itself a function of
`seed + action log` and replays exactly.

```
DriverTimeline = {
  # one entry per (driver, change), append-only, full-time-ordered.
  # Between two consecutive entries for a driver, its value is CONSTANT (piecewise-constant).
  "estrogen":  [ {"t": 0, "v": 0}, {"t": 3600, "v": 80}, {"t": 90000, "v": 20} ],
  "prolactin": [ {"t": 0, "v": 0}, {"t": 3600, "v": 60} ]
}
```

- `t` is `sim_clock` full-time (integer seconds, §`sim_clock.gd`); `v` is the driver value
  (fixed-point integer, §6). Each list is sorted ascending by `t` (append-only, monotone).
- A driver absent from the timeline reads its baseline (0 by convention) for all `t`.
- **Drivers are global-to-the-body or scoped to a tag/segment.** Default: body-wide (one
  `estrogen`). A driver may be scoped (`"estrogen@#breast_l"`) when one region must respond
  differently — same timeline shape, namespaced key. Scoping is convention, not new
  machinery.

### 3.1 The effect map — driver → rate-on-a-property

An **effect** binds a driver (and optionally current state) to a **rate** on a state
variable. Effects are **data records**, content-authored, open:

```
Effect = {
  "id": "estrogen_grows_breasts",
  "driver": "estrogen",                 # which input variable
  "target": {"select":"all_tagged","tag":"breast"},   # which segments (existing targeting)
  "prop":   "volume_ml",                # which scalar state variable
  "rate":   {"kind":"linear", "per_unit_per_hour": 5},  # dV/dt = 5 ml/h per unit of estrogen
  "clamp":  [0, 4000000]                # fixed-point bounds (µL here — §6)
}
```

`rate.kind`:
- **`linear`** (the common, closed-form case): `dProp/dt = per_unit_per_hour × driver_value`.
  The rate depends only on the (piecewise-constant) driver, so the property is closed-form
  (§5). This is the **preferred path** and covers the overwhelming majority of effects.
- **`saturating`** (state-coupled, still closed-form on each interval): a logistic/decay form
  like `dProp/dt = k × driver × (1 − Prop/ceiling)`. Within one constant-driver interval this
  is a **linear ODE** with a closed-form exponential solution (§5.3) — still no numerical
  integration, still queryable at any `T`. This is how "growth slows as it approaches a cap"
  is expressed without leaving the closed-form world.
- **`coupled`** (the fallback, §5.4): genuinely nonlinear coupling between *multiple* evolving
  state variables that has no closed form. Specified, fenced, and used only where unavoidable.

An effect with `rate` is the general (continuous) case. An effect may instead carry
`"impulse": <amount>` — an instantaneous step applied once when a driver crosses a condition
— which is exactly the old `prop_delta` (§2.1), recorded as a discrete log event.

---

## 4. State variables — what's stored vs. what's derived

A continuous scalar property is **not stored as a materialized number that the holder keeps
re-writing every tick.** That is the staircase model and its drift risk. Instead:

> **A state variable's value at query time `T` is RECOMPUTED on read from
> `(baseline, driver timeline, effect map, T)`.** The segment stores only the **baseline**
> (the value at `t₀`, or at the last discrete impulse/structural reset) plus the elapsed-time
> integral of driver-driven rate. Nothing is cached that can drift.

```
Segment.props = {
  "volume_ml": { "base": 650000, "base_t": 0 }   # fixed-point µL; value at base_t
}
```

`base` is the value at `base_t`; the *current* value is `base` plus the accumulated
driver-driven change from `base_t` to `T`, computed by the closed-form sum (§5). A discrete
impulse (old `prop_delta`) or a structural reset writes a **new `(base, base_t)` pair** at
that log instant — collapsing all prior evolution into a fresh baseline, so the sum never has
to reach back past the last impulse.

This is the same "derive on read, store the minimum" stance as description-from-state
(`transformation-system.md` §6) and derived-sex (`compound-parts-and-fluids.md` §6): the
graph stores ground truth, readable quantities are pure functions of it.

---

## 5. The deterministic formulation (the careful part)

The replay invariant is **non-negotiable**: body-state-at-query-`T` must be reproducible
**purely from `seed + action log`**, bit-for-bit, queryable at *any* `T`, independent of how
many times or in what order it was queried. Here is the formulation and its defense.

### 5.1 Why piecewise-constant drivers make this exact

**Drivers change only at discrete log events** (§3). A driver is set by an action; that action
is in the log with a full-time stamp; between two consecutive driver-change events the driver
value is **constant**. Therefore, for a `linear` effect, the rate `r = per_unit_per_hour ×
driver_value` is **constant on each inter-event interval**. A constant rate over a known
duration is a closed-form product — **no integration, no step size, no drift.**

### 5.2 The closed-form sum (linear effects — the preferred path)

Let a state variable `P` start at baseline `base` at time `base_t`, and let the driver
timeline (restricted to drivers that have effects on `P`) have change-points
`base_t = t₀ < t₁ < t₂ < … < tₙ ≤ T`, with the driver value (hence the rate `rᵢ`) constant on
each interval `[tᵢ, tᵢ₊₁)`. Then:

```
P(T) = base + Σ_{i=0}^{n-1}  rᵢ · (t_{i+1} − t_i)   +   rₙ · (T − t_n)
                ╰───────────── full closed intervals ─────────╯   ╰─ final partial interval ─╯
```

where `rᵢ` is the **summed rate of every effect** active on `P` over interval `i` (multiple
drivers can drive one property; their rates add — a linear superposition). Each term is
`rate × duration`, integer fixed-point arithmetic (§6). The result is then clamped to the
effect's bounds.

**This is exact and replay-safe because:**
- Every `tᵢ` is a logged full-time stamp → a function of the action log.
- Every `rᵢ` is `per_unit_per_hour × driver_value` → integer fixed-point, no float.
- `(t_{i+1} − t_i)` is integer-second subtraction → exact.
- The sum is a finite sum of integer products → associative, order-independent, no
  accumulation error. **There is no per-tick stepping**, so there is *no step-size parameter
  and no drift to accumulate*: the same `T` always yields the same integer, whether queried
  once or a thousand times, in any order.
- It is queryable at **any** `T`, not just at tick boundaries — the final partial interval
  `rₙ · (T − tₙ)` handles arbitrary `T`. (Contrast the staircase, which only had values at
  `stage_seconds` multiples.)

The holder no longer steps anything per tick. It maintains only the **driver timeline**; the
property value is a **lazy read** that walks the (short) list of change-points and sums. Cost
is O(change-points since last baseline) per query — bounded by §7.

### 5.3 Saturating effects — still closed-form per interval

For `rate.kind = "saturating"` (e.g. `dP/dt = k·d·(1 − P/C)`), within a single
constant-driver interval `d` is constant, so this is a **first-order linear ODE with constant
coefficients**, whose closed-form solution is:

```
P(t_{i+1}) = C·(d̂) + (P(t_i) − C·(d̂))·exp(−(k·d/C)·(t_{i+1} − t_i))      where d̂ normalizes the driver
```

We compute this **per interval**, feeding each interval's endpoint as the next interval's
start `P(tᵢ)`. Still no fixed-step integration — one closed-form evaluation per interval.

**The honest caveat:** `exp` is transcendental and **not cross-platform-deterministic in
floating point.** So saturating effects use a **deterministic fixed-point `exp` approximation**
(a tabled / integer-series `exp` evaluated identically on every runtime — the same discipline
the movement and prose substrates keep for their float caveat, see
`simulation-depth-and-materialization.md` "cross-platform-float caveat"). This is a chosen,
pinned approximation function, identical on all runtimes by construction, **not** IEEE
`exp`. With that, saturating effects remain exactly replayable. If a content author needs
saturation but wants to avoid the `exp` table entirely, they can approximate with a **clamped
linear** effect (linear rate + a hard `clamp` ceiling) — fully in the §5.2 path, no `exp` —
at the cost of a hard knee instead of a smooth one.

### 5.4 The fallback — fixed deterministic integration (fenced, last resort)

Genuine nonlinearity that couples **multiple simultaneously-evolving state variables** (P
drives Q's rate while Q drives P's rate) has no closed form. For that — and **only** that —
the fallback is **fixed deterministic integration**, with this discipline:

- **Fixed step schedule tied to the clock**: a fixed integration step `Δ` (e.g. 60 s of
  full-time), stepped from the last baseline to the largest `step·Δ ≤ T`, then one final
  sub-step to `T`. The step boundaries are a pure function of `T` and `Δ` — **not** of the
  query history — so the trajectory to a given `T` is identical regardless of when/how often
  queried. (Two queries at the same `T` walk the same step sequence.)
- **Integer / fixed-point math only** (§6): the integrator accumulates in fixed-point; no IEEE
  float in the loop.
- **Seeded**: any stochastic term draws from the same `DetRng.seed_for(world_seed, action_id,
  stage_index, op_index)` coordinate the applier already uses (`tf_applier.gd`).

**Be honest: this is where drift and per-query cost risk live.** Fixed-step integration is
O((T − base_t)/Δ) per query — unbounded in elapsed time — and its result is only as accurate
as `Δ`. It is therefore **fenced**: an effect must explicitly declare `rate.kind:"coupled"` to
use it; the linter warns; and a `coupled` cluster must declare a **materialization cadence**
(§7) so the integral is advanced and re-based at bounded intervals rather than re-walked from
`t₀` on every read. **The MVP (§10) ships ZERO coupled effects** — closed-form only. The
fallback is specified so the door is open, and fenced so it is never the default.

### 5.5 The replay guarantee, stated precisely

> For any body, any state variable `P`, and any query time `T`: `P(T)` is a pure function of
> `(world_seed, action_log)` and `T`. It does not depend on **when** the query is issued,
> **how many times** it is issued, or **in what order** relative to other queries. The
> driver timeline and effect map are reconstructed from the action log; the closed-form sum
> (§5.2 / §5.3) is deterministic fixed-point arithmetic; impulses and structural events are
> discrete log entries that re-base the baseline. Replaying the action log on one runtime
> reproduces every `P(T)` bit-for-bit. The fixed-point representation (§6) removes the
> cross-platform-float hazard for the linear path; the saturating path's `exp` uses a pinned
> deterministic approximation; the coupled fallback is fixed-step fixed-point. Lazy reads are
> referentially transparent: a value read late equals the same value read eagerly.

This is the same `seed + action log` contract `sim_clock.gd` and `tf_applier.gd` already hold;
this doc keeps it under continuous evolution by **never stepping a mutable cache** and instead
**summing a closed form over the logged driver timeline.**

---

## 6. Numeric representation — fixed-point (and the integer-volume question answered)

**Decision: continuous state variables and driver values are FIXED-POINT — integer-backed at
a chosen per-quantity resolution.** Volume in **microlitres (µL)** (`volume_ml × 1000`),
lengths in **hundredths of a cm** (the unit `tf_applier.gd` already uses for `prop_delta`
draws — integer hundredths), fluids in **integer mL** (as `compound-parts-and-fluids.md` §5.1
already mandates), driver values in **hundredths**.

**Justification — why fixed-point over float:**
- **The rate×duration sum (§5.2) must be bit-identical across runtimes.** IEEE float
  *add/sub* is largely cross-platform-deterministic, **but** the rate term is a *multiply*
  (`per_unit_per_hour × driver × duration`) and the saturating path needs `exp` — and
  multiply chains, `exp`, division, and any nonlinear derived math are exactly where
  cross-platform float diverges (fused-multiply-add, x87 vs SSE rounding, libm differences).
  Fixed-point integer arithmetic has **none** of that: integer multiply/add are exact and
  identical everywhere. The existing code already learned this — `det_rng.gd` is integer-only
  "no float in the draw path," `tf_applier.gd` accumulates "integer hundredths," and
  `compound-parts-and-fluids.md` §5.1 mandates "integers only — no float in the path …
  floats accumulate drift."
- **The integer-volume question (the user asked whether integer volume is justified):
  YES, justified — as fixed-point µL, not as "whole millilitres."** The objection to integer
  volume is loss of granularity (1 mL steps are coarse for slow growth). Fixed-point dissolves
  it: store **µL** (1000× finer), so a 0.005 mL/h trickle is still an exact integer rate, and
  the *displayed* mL is `µL / 1000` banded by the describe layer (`tf_measure.gd` already
  derives the human cup/unit from canonical integers — this is the same pattern). Integer
  volume is justified **at a fine fixed-point resolution**; it was only ever a problem at
  whole-mL resolution.
- **Float is the risk, not the convenience.** We keep float **only** at the describe boundary
  (deriving a displayed cm/mL/cup from the canonical integer, where a 1-ULP difference is
  invisible and never re-enters state). State and rates never touch float. This matches
  `tf_applier.gd` ("converted to float only for the final stored prop value").

Resolution per quantity is a **fixed table** (µL for volume, cm/100 for length, mL for fluid,
driver/100 for drivers), pinned once, never per-body. Round-trips through JSON as exact
integers (no float reload drift — same as `INT_PROPS` today).

---

## 7. Boundedness & cost (honest, referencing the simulation-depth crux)

"Very many inputs" + continuous evolution is exactly the **per-query-cost and
global-consistency crux** flagged in `simulation-depth-and-materialization.md` (pay-per-query,
bounded cost as the constraint/driver set grows, the locality lever). Stated honestly:

**What is bounded by construction (the good news):**
- **Lazy evaluation.** A property is computed **only when queried** (a describe pass, a gate
  check, a render). Unqueried properties cost nothing — the pay-per-engagement stance of the
  simulation-depth doc, applied to body state. An idle body with 50 drivers and no observer
  does zero work.
- **Closed-form is O(change-points), not O(elapsed time).** §5.2 walks the driver
  change-points since the last baseline, **not** every tick. A driver held constant for a year
  is *one* interval term. Re-basing on each impulse/structural event (§4) keeps the walk
  short — the list never grows unboundedly between baselines because each discrete event
  collapses it.
- **Locality / no dense interaction matrix.** This is the load-bearing design choice, straight
  from the simulation-depth doc's **locality lever** ("corner-risk / cost scales with global
  constraints; keep them local"). We **forbid the dense driver×property matrix**: an effect
  binds **one driver to one property-on-targeted-segments**. There is no implicit all-pairs
  coupling. Total cost per body is O(active effects), and the author controls that count
  directly. `coupled` clusters (§5.4) are the only place interactions exist, and they are
  fenced and small.

**What stays open / costs (the honest part):**
- **Bounded driver count is a discipline, not an invariant.** Nothing in the math *forbids*
  500 drivers on one body; it would just be slow and is bad content design. We **recommend** a
  soft cap (linter warning past, say, ~16 active drivers/body) but do **not** hard-enforce it
  — the open question is whether a hard cap is ever needed (§11).
- **The `coupled` fallback is genuinely O(elapsed/Δ).** If it is ever used, it needs the
  **materialization cadence** — periodically advance the coupled integral to "now" and re-base,
  so reads don't re-walk from `t₀`. Choosing that cadence (and proving it doesn't perturb
  replay) is real work, deferred with the fallback. The MVP avoids it entirely.
- **Global consistency across bodies** (e.g. an ambient driver shared by many bodies) is **out
  of scope** here — that is the simulation-depth doc's `G`/constraint-set problem, not the
  per-body dynamical model. Per-body, the driver timeline *is* the local constraint set, and
  it is small and append-only.

We do **not** claim to have solved the unbounded-incremental regime. We claim: **the linear
closed-form path is bounded, lazy, and replay-exact**, and everything expensive is fenced
behind explicit `coupled` opt-in that the MVP does not ship.

---

## 8. Worked example — estrogen grows breasts; prolactin drives lactation

The example exercises both the property-growth path (§5.2) and the fluid-production path
(generalizing `compound-parts-and-fluids.md` §5.4 from a binary toggle to a driver-driven
rate).

**Setup.** A body with two `breast` segments (`compound-parts-and-fluids.md` §3.4), each
carrying `props.volume_ml` (fixed-point µL baseline) and a `milk` fluid `{amount, capacity}`
(integer mL). Two effects in the content map:

```
# (a) estrogen → breast volume, linear, clamped (closed-form §5.2)
{ "id":"estrogen_grows_breasts", "driver":"estrogen",
  "target":{"select":"all_tagged","tag":"breast"}, "prop":"volume_ml",
  "rate":{"kind":"linear","per_unit_per_hour":5000},   # 5000 µL/h = 5 mL/h per estrogen-unit
  "clamp":[0, 4000000] }                                 # cap 4000 mL = 4,000,000 µL

# (b) prolactin (+ current breast volume) → milk production, saturating at capacity
{ "id":"prolactin_lactation", "driver":"prolactin",
  "target":{"select":"all_tagged","tag":"breast"}, "fluid":"milk",
  "rate":{"kind":"saturating","k":10,"ceiling_from":"capacity"} }  # dMilk/dt = 10·prolactin·(1−milk/cap)
```

**Transformation = set drivers** (each a logged action with a full-time stamp):
- At `t=3600` (1 h in): `set estrogen = 80`. Breasts begin growing.
- At `t=3600`: `set prolactin = 60`. Milk begins filling.
- At `t=90000`: `set estrogen = 20` (a later dose tapers). Growth slows but continues.

**Querying breast volume at any `T`** (closed-form, §5.2). Baseline `base = 650000 µL`
(`base_t = 0`). Rate per breast = `5000 µL/h × estrogen / 3600 s/h` per second. Over
`[0, 3600)` estrogen=0 → rate 0. Over `[3600, 90000)` estrogen=80 → rate
`5000·80/3600 ≈ 111 µL/s` (computed in fixed-point: `5000·80·(90000−3600)/3600` over the
whole interval = `5000·80·86400/3600 = 9,600,000 µL = 9600 mL` of growth). Over `[90000, T)`
estrogen=20 → `5000·20/3600 µL/s`. So:

```
volume(T) = 650000
          + 5000·80·(90000−3600)/3600          # interval [3600,90000): +9,600,000 µL
          + 5000·20·(T−90000)/3600              # interval [90000,T): partial, any T
   then clamp to [0, 4000000]                    # the cap bites — see below
```

The cap `4,000,000 µL` clamps the result, so the breast grows to 4000 mL and holds — the
`clamp` enforces the ceiling deterministically. The **displayed cup** is re-derived by
`tf_measure.gd` from `volume_ml/1000` + `band_cm` on every describe (unchanged) — so the cup
letter increases as volume crosses band thresholds, with no stored cup. **Queried at any `T`,
the value is the same integer every replay** — that is the §5.5 guarantee.

**Querying milk at any `T`** (saturating, §5.3). Over `[3600, T)` with prolactin=60 and
ceiling = `capacity`, milk follows `milk(T) = cap·(1 − exp(−(10·60/cap)·(T−3600)))` per the
pinned fixed-point `exp` — asymptotically filling to capacity and self-limiting (it never
exceeds `cap`, matching the old clamp). **Lactation is now a continuum, not a binary toggle:**
`prolactin = 0` → no production; `prolactin = 60` → fills over hours; `prolactin = 200` →
fills fast; lowering prolactin slows it; the milk amount is modulatable from *any* value by
moving the driver, and it is reproducible at any query time. Draining (an act emptying the
reservoir) is still a discrete `fluid_delta` impulse (a structural-style event re-basing the
fluid baseline). This is exactly the §5.4-of-`compound-parts-and-fluids` tie-in, generalized:
the "standing staged TF that does one fluid_delta per tick" is replaced by "a prolactin
driver + a saturating effect," which is smooth, queryable at any `T`, and modulatable.

---

## 9. How discrete structural events coexist with continuous evolution

Both live in the **same action log**, interleaved by full-time:

- **Discrete events** (graft/remove/reparent, categorical `set_material`/`set_covering`,
  adding a finger/nipple, an impulse `prop_delta`, a drain `fluid_delta`) are applied by the
  **existing `tf_applier.gd` unchanged**, at their log instant. A structural or impulse event
  that touches a continuous property **writes a fresh `(base, base_t)` baseline** at that
  instant (§4), collapsing all prior driver-driven evolution into the new baseline so the
  closed-form sum after it starts clean.
- **Continuous evolution** (driver-driven scalar properties) is **not applied at instants at
  all** — it is the closed-form read (§5) over the driver timeline between baselines.

So a session reads, in log order: *graft a tail (discrete) → set `tailgrow` driver high
(continuous, tail length now evolves) → at some `T`, remove the tail (discrete, the driver
now drives nothing because the segment is gone) → graft a new tail (discrete, fresh baseline)
→ …*. The describe pass at any `T` reads each segment's current scalar via the closed-form sum
and its current structure/material directly off the graph — exactly as
`transformation-system.md` §6 describes, now with continuous scalars resolved lazily.

**Undo** (`transformation-system.md` §5.4) extends cleanly: a driver-set is a logged event
with a captured `before` driver value; undo restores it, and because property values are
*derived* from the timeline, restoring the driver restores all downstream property values for
free — **no per-property undo needed for continuous evolution** (only impulses and structural
events carry captured before/after, as today). This is strictly *less* undo bookkeeping than
the staircase model.

---

## 10. What changes vs. the current implementation (the delta for a later rebuild)

Stated precisely so a rebuild knows exactly what to touch. Against the code in
`scripts/body/tf/`:

**Unchanged (do not touch):** `body_graph.gd` (the graph, targeting, `INT_PROPS`,
`material_takes_covering`); the **structural** ops in `tf_applier.gd`
(`graft_subtree`/`remove_subtree`/`reparent`/`set_material`/`set_covering`/`tag_*`); undo for
those; `tf_validator.gd`; `tf_measure.gd` (derived cup/size); `tf_describe.gd` traversal
shape; `sim_clock.gd`; `det_rng.gd`. The save model (seed + action log) is unchanged.

**New (the delta):**
1. **A driver timeline** per body (§3): append-only, full-time-stamped, derived from the
   action log. New data + a small reader. A new action kind: **`set_driver(name, value)`**.
2. **An effect map** (§3.1): content-authored data records binding driver→rate→prop/fluid.
   New content table alongside the existing TF records.
3. **Continuous-property storage change** (§4): a scalar property that is driver-driven stores
   `{base, base_t}` instead of a bare number. **Migration:** existing bare-number props are the
   `base` at `base_t=0` with no driver — fully back-compatible (a prop with no effect is a
   constant, reads `base` forever).
4. **A closed-form property reader** (§5.2/§5.3): `prop_value(body, seg, prop, T)` — the
   fixed-point sum over driver change-points, clamped. This is the one genuinely new piece of
   math. `tf_describe.gd` and gate evaluation call it instead of reading a bare field.
5. **Fixed-point resolution table** (§6): µL / cm·100 / mL / driver·100. Volume props move
   from mL-int to µL-int (a 1000× rescale on migrate).

**Removed / subsumed:** the **staged `prop_delta`/`fluid_delta` standing-TF pattern** for
*continuous growth* (`compound-parts-and-fluids.md` §5.4's "standing staged TF, one
fluid_delta per stage") is **replaced** by driver+effect. Instantaneous `prop_delta` /
`fluid_delta` **remain** as impulses (§2.1). The `one_op_per_stage` creeping-boundary
mechanism (`tf_applier.gd`) stays for *discrete* staged structural/categorical TFs.

---

## 11. MVP slice (smallest real version + the quick fixes)

The smallest thing that is a *real* dynamical-property system, built on the existing graph:

**The dynamical core (closed-form only, zero coupled effects):**
- **2 drivers:** `estrogen`, `prolactin` (open-vocabulary, two shipped values — same
  discipline as tags/materials).
- **2 driver-driven properties:** breast `volume_ml` (linear effect, §8a) and `milk` fluid
  production (saturating effect, §8b). One linear, one saturating — exercises both
  closed-form paths; **no `coupled` effect ships.**
- **The driver timeline + `set_driver` action + the closed-form reader** (§5.2/§5.3) in
  fixed-point (§6). `tf_describe.gd` and gates read through it.
- **Determinism test (added to `tests/run.sh`):** same seed + action log → identical
  `prop_value` at several arbitrary `T` (including non-tick `T`), queried in scrambled order →
  identical; save/load round-trip of the timeline → identical; undo of a `set_driver` restores
  all downstream property values; an impulse `prop_delta` re-bases correctly and coexists with
  a driver.
- **Playtest surface:** extend the text harness (`tools/tf_play.gd`) with driver sliders
  (`estrogen`, `prolactin`) and a "query at T" control; advance the clock, watch breast cup
  grow smoothly and milk fill toward capacity, scrub `T` backward/forward and confirm the same
  body reads the same values. **Observe the actual transcript** (mandatory playtest,
  CLAUDE.md) — smooth growth, correct cup banding, no staircase.

**The quick fixes (bundle them with this rebuild — they are small and the surface is already
being touched):**
- **Natural part nouns.** The describe layer currently can emit awkward tag-derived nouns
  (`spine` for a barrel, raw tag strings). Map convention tags to natural nouns in
  `tf_describe.gd` (`barrel`/`lower_body` → "lower body", not "spine"). Pure describe-layer.
- **Consistent body-core tags — drop `spine` as the lower-body core tag.** `tf_content.gd`
  tags the quadruped barrel `["spine","lower_body"]` and gates on `has_tag spine`
  (`tf_content.gd:71,93,175,178`). A horizontal quadruped barrel is **not** a spine; this tag
  is an inconsistent body-core marker. Replace the `spine`-as-core convention with a
  consistent core tag (e.g. `body_core` or simply gate on `lower_body`), and update the gates
  that key on it. Convention cleanup, no engine change.
- **No 300-second no-op.** A staged TF whose stage fires but produces no visible change (the
  `lo:150,hi:300` volume roll on a clamped/already-maxed prop at `tf_content.gd:336`, or a
  stage that gates out) currently "passes time" with nothing happening — a 300 s no-op the
  player can't see. Under the dynamical model this **disappears for continuous growth** (a
  driver either drives a rate or doesn't — there is no empty stage). For the remaining discrete
  staged TFs, the holder should **skip a stage that produces an empty effects list** rather
  than consume `stage_seconds` of clock for nothing (apply_stage already returns `[]`; the
  holder must treat `[]` as "no time consumed / advance to the next *productive* stage").

**Ship it OPEN from day one** (same discipline as the parent MVPs): drivers, effects, and the
fixed-point quantities are **open vocabulary / few shipped values**, never a closed enum. The
closed-form reader works unchanged as drivers and effects are added.

**Deferred:** the `coupled` nonlinear fallback (§5.4) and its materialization cadence; the
soft/hard driver-count cap question (§7); cross-body shared/ambient drivers (the
simulation-depth `G` problem); the 3D rendering of continuous morphing (the parent's deferred
3D embodiment problem — `transformation-system.md` §2/§3.0).

---

## 12. Open questions (genuine only)

1. **Does the `coupled` fallback ever earn its keep?** Every effect we can currently imagine
   is linear or saturating (closed-form). The fixed-step integrator (§5.4) is fully specified
   but unused. The open question is whether any *required* content (multi-variable feedback —
   e.g. arousal ↔ a fluid ↔ a size in a true loop) genuinely needs it, or whether clamped-
   linear + saturating cover the real space. Lean: defer until content pulls it; do not build
   the integrator on spec.

2. **Saturating `exp`: pinned table vs. clamped-linear-only.** §5.3 needs a deterministic
   fixed-point `exp`. Open: ship the pinned `exp` table (smooth saturation, more code, a
   pinned-approximation to validate cross-runtime), **or** restrict the MVP to clamped-linear
   only (a hard knee at the cap, zero `exp`, strictly §5.2). The MVP can land either way; the
   smooth `exp` is nicer but is the one new transcendental-determinism surface. Recommend
   starting clamped-linear and adding the `exp` table only if the knee reads badly in playtest.

3. **Driver-count bound — soft cap or hard cap?** §7 recommends a soft linter cap (~16) and no
   hard enforcement. Open whether a hard cap (or per-query effect budget) is ever needed for
   pathological content. Lean: soft only until a real body stresses it.

4. **Baseline re-basing policy under undo.** Re-basing on each impulse/structural event (§4)
   keeps the sum short, but undo of an impulse must *also* restore the prior baseline pair, not
   just the impulse delta. The mechanism is clear (capture `(base, base_t)` before/after, like
   any other prop capture); the open part is confirming the interaction of re-basing + undo +
   the closed-form read has no edge case where a stale baseline survives an undo. A test target,
   not a design gap — flagged for rigor.

---

*Design pass. No code. Extends `transformation-system.md` (graph unchanged) and
`compound-parts-and-fluids.md` (fluids driver-driven). Not green. Awaits the user's express
approval.*
