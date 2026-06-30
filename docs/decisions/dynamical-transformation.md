# Design: Dynamical transformation — bodies as driven transitions

Status: **Design pass — no code. Not green.** Awaits the user's express approval before any
implementation. New work lands under `docs/FEATURES.md` → Not green.

**Relationship to `transformation-system.md`: this EXTENDS it; the graph is UNCHANGED.** The
compositional segment graph (`{material, covering, props, tags, children}`, three open axes,
convention tags, structural/ordinal targeting, the deterministic seeded applier, the
TFHolder on `sim_clock`, reversibility/undo, description-from-state) stands exactly as
written. This doc reframes **how a body changes continuously over time** — and nothing else.
It also extends `compound-parts-and-fluids.md`: fluids (lactation, seed, nectar) become
driven transitions, not binary toggles — the worked example in §8.

**Two axes, never conflated — TOPOLOGY (discrete) vs. MAGNITUDE (continuous).** A part has a
**topology** — whether it is in the graph at all and where it attaches (parent, ordinal, tags) —
which is **discrete**, and **magnitudes** — `volume_ml`, `length_cm`, axis scalars, fluid
amounts — which are **continuous**. These never interpolate into each other. A part "growing in"
is **not** a topology interpolation: it is **grafted at ~zero extent in one discrete log event**,
then a **continuous magnitude transition 0→full** carries its size up. Gradual structural
appearance = **discrete graft + continuous scalar**, never a half-existing part. §9.1 generalizes
this to arbitrary subtree changes as a **bundle of authored, per-part targeted transitions** — no
whole-structure diff, no inferred correspondence.

**State rides IDENTITY, not structure.** A transition transforms a part **in place**, preserving
its **segment identity** (its stable id). Everything attached to that identity — fluid amounts,
the drivers acting on it, any in-flight sub-transitions — **rides along** through the
transformation. A breast resized while lactating keeps its milk and keeps producing. This is the
core principle of §9.2. A structural change is authored as **targeted ops** (§9.1): an in-place
change keeps the **same id** (state carries); an add is an explicit **graft of new ids** growing
in from zero; a remove is an explicit **targeted shrink-to-zero-then-drop** on selector-resolved
existing ids. There is **no graph-matching**: "which part" is always an authored selector (id,
tag, ordinal, or structural query) resolved deterministically, never an inferred correspondence
between two structures. This is the clean form of the *stable identity / fact identity* crux of
`simulation-depth-and-materialization.md` — identity is **authored, not matched**.

**The core unit is a driven TRANSITION.** A transformation is not "a property accruing under a
rate"; it is a transition **`{from: state-snapshot, to: target-state, progress: driven_var ∈
[0,1]}`**, whose rendered value is `interpolate(from, to, progress(T))`. **Progress is itself
the driven state variable** — so the whole closed-form / replay-exact determinism apparatus of
this doc applies to PROGRESS, and every affected property is a deterministic interpolation
keyed off it. `from`/`to` are snapshots committed at the transition's start event in the action
log; progress evolves under drivers (§5), clamped to `[0,1]`. The old "a property evolves under
driver rates" model is now the **special case** of a transition whose `to` is open-ended (§2.1).

Refs read: `transformation-system.md` (the settled graph + applier + holder; §3–§5 cited
throughout); `compound-parts-and-fluids.md` (fluids as per-segment integer state; the
lactation tie-in §5.4, here generalized); `simulation-depth-and-materialization.md` (the
per-query-cost / global-consistency crux that "very many inputs" lands in — §7 here grapples
with it honestly).

Aeriea principles honored: data over code at a seam (a transition is a serializable
`{from,to,progress}` record, not a closure); deterministic seeded sim; description derived from
state; **the discrete model AND the old rate-on-property model are subsumed, not discarded**
(retire-don't-deprecate in the direction of generalization — each old construct is a special
case of the driven transition, §2.1).

---

## 1. Status

- Design pass, **no code yet**, **Not green**, awaits the user's express approval.
- Extends, does not supersede, `transformation-system.md` and `compound-parts-and-fluids.md`.
  The body graph, the op vocabulary's **structural** ops, the applier, the holder, undo, and
  description are all unchanged. The delta is confined to **how continuous properties change
  over time — as driven transitions** (§9 states it precisely so a later rebuild knows exactly
  what changes).

---

## 2. The reframe (the thesis)

**Today** (`transformation-system.md` §4–§5), a transformation is a list of discrete
op-records — `prop_delta` / `fluid_delta` / `graft_subtree` / `set_material` — applied at
staged clock ticks. A staged TF is a step function: at each `stage_seconds` boundary the
applier rolls a delta and writes it. Between boundaries nothing moves; the property is a
piecewise-constant staircase, and "how a body changes over time" is encoded implicitly in
how many stages have fired.

**The reframe — the core unit is a driven TRANSITION.** A transformation is a transition from a
**captured start state to a target state, parameterized by a driven progress variable**:

> **`Transition = { from: state-snapshot, to: target-state, progress: driven_var ∈ [0,1] }`**

The rendered value of every property the transition affects is a deterministic interpolation:

> **`value(T) = interpolate(from, to, progress(T))`**

`from` is a **snapshot of the affected state**, captured and committed at the transition's
**start event in the action log**. `to` is the **target state** the transition heads toward.
`progress(T) ∈ [0,1]` is **the driven state variable** — and this is the load-bearing move:
**progress is itself driven exactly the way a property was driven before.** Progress accrues
under drivers at piecewise-constant rates, in fixed-point, clamped to `[0,1]`, recomputed
lazily on read from `seed + action log`. Every closed-form / replay-exact result in §5 is
stated **about progress**, and `interpolate(from, to, ·)` is a pure deterministic function on
top. So a transformation is now two layers: **a driven scalar `progress` (the dynamical core,
§5)** and **an `interpolate` projection from `progress` to the affected property (§4.1).**

A **driver** is an open, user-named scalar input — `"estrogen"`, `"prolactin"`, `"arousal"`,
`"chitin_signal"`, or any custom name — exactly as open as tags / materials / coverings
already are (no enum, §3). A **transformation** is **"declare a transition (`from`/`to`) and
let drivers move its `progress`."** An **effect** is a function from `(drivers, current state,
time)` to a **rate on `progress`** — the same rate-on-a-scalar math as before, now applied to
the progress of a transition rather than directly to a property.

Time/elapsed is **one input among many**, not privileged. Drivers move progress; the clock
supplies `T`. **"When" a transition happens is driven, not scheduled** (§2.2).

### 2.1 Subsumption — what's now a special case of a transition

The driven transition is the general unit. Everything else is a special, degenerate case of
it, and the discrete structural ops stay in the log as instantaneous events:

| construct | as a driven transition |
|---|---|
| **rate-on-a-property** (the previous core: "a property evolves under a driver rate") | **A transition whose `to` is open-ended / far off** — `from` is the current value, `to` is the bound (or +∞ until a `clamp` bites), and `progress` accrues unboundedly so the rendered value tracks `from + rate·elapsed`. Demoted from the core to *this* special case. Closed-form §5 applies verbatim (the old "property rate" *is* the progress rate, with an affine interpolate). |
| `prop_delta` (instantaneous step) | **A transition whose `progress` jumps `0→1` in one log event** — `from`=old value, `to`=old+delta, progress saturates instantly. The old Dirac-impulse case; identical result, recorded as one discrete log event. |
| staged `prop_delta` growth over N ticks | **`progress` crossing thresholds over time** under a sustained driver — the smooth law the staircase approximated. The closed form gives the value at any `T`, not just at tick boundaries; describe-layer bands read off `progress` or the interpolated value. |
| `graft_subtree` / `remove_subtree` / `reparent` | **UNCHANGED** — a discrete structural event in the log. **Topology is never a transition; it is a discrete add/remove.** A part *growing in* is a graft-at-zero-extent (one discrete event, a new id) + a continuous 0→full magnitude transition (§9.1); a part *shrinking out* is a continuous full→0 magnitude transition on a **selector-resolved existing id** + a discrete drop at progress=1. The graft/drop themselves are each one log event. |
| `set_material` / `set_covering` (categorical, instant) | **UNCHANGED as a discrete categorical set.** A *gradual* material change (flesh→chitin) is instead a **qualitative transition** (§4.1): `from=flesh`, `to=chitin`, and the describe/render layer blends or threshold-crosses on `progress` ("60% chitinized"); the categorical `material` field flips discretely when progress crosses a pinned threshold (a discrete event content emits), so both coexist. |

So: **structure/topology and instant categorical sets stay discrete events**; **everything
continuous is a driven transition whose progress is driven.** The previous "rate-on-property"
model is no longer the core — it is the open-ended-`to` special case. Nothing is lost; the
staircase becomes a coarse reading of a progress law now queryable at any `T`.

### 2.2 "When" is driven, not scheduled

A transition does not run on a fixed stage schedule. It **starts, pauses, accelerates, and
reverses purely as a function of drivers** — because its rate-on-progress is the driver-driven
rate of §5:

- **Start.** A driver crossing a threshold gives `progress` a **positive rate** → the
  transition begins (the start event also commits the `from` snapshot, §4).
- **Pause / accelerate / decelerate.** Driver magnitude scales the progress rate; a driver at
  zero freezes progress where it is (`from`/`to` and current progress are retained — the
  transition is simply not moving).
- **Reverse / undo.** A driver dropping (or a different driver) gives `progress` a **negative
  rate** → progress decreases back toward 0, the rendered value interpolates back toward
  `from`. **Reversal is not a special mechanism** — it is just a negative rate on the same
  driven scalar. When progress returns to 0 the body is back at `from`; the transition has
  undone itself with no separate undo bookkeeping (contrast the old "staged TF" which needed an
  explicit reverse).

This **replaces the old staged-TF concept entirely** for continuous change. There is no stage
schedule, no `stage_seconds` clock for continuous transitions; modulation and reversal **fall
out for free** from the sign and magnitude of the progress rate. (Discrete *structural* staged
TFs — adding fingers one at a time — keep their staging mechanism; only continuous change moves
to driven progress.)

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

### 3.1 The effect map — driver → rate-on-PROGRESS

An **effect** binds a driver (and optionally current state) to a **rate on a transition's
`progress`**. Effects are **data records**, content-authored, open. The transition declares
`from`/`to` and what it interpolates; the effect supplies the **driver → progress-rate** law:

A transition references the **identities** of the parts it transforms, not their positions in the
graph: `target` resolves (at the start event) to a concrete set of **segment ids**, and the
transition is anchored to those ids. Re-resolving by identity is what makes "transform in place"
(§9.2) mean *the same segment*, so attached state rides along.

```
Transition = {
  "id": "estrogen_breast_growth",
  "target": {"select":"all_tagged","tag":"breast"},   # resolves to segment IDS at start (existing targeting)
  "affects": {"prop":"volume_ml"},      # the property this transition interpolates
  "from":   "snapshot",                 # captured at start event (the segment's value then)
  "to":     {"prop":"volume_ml","value":4000000},  # target value (µL — §6); open-ended ⇒ "to":"unbounded"
  "interp": "lerp",                     # scalar interpolation (§4.1); "blend"/"threshold" for categorical
  "driver": "estrogen",                 # which input drives progress
  "rate":   {"kind":"linear", "per_unit_per_hour": 0.05}  # dProgress/dt per unit of estrogen
}
```

`rate.kind` (the rate is now on **`progress ∈ [0,1]`**, always clamped to `[0,1]`):
- **`linear`** (the common, closed-form case): `dProgress/dt = per_unit_per_hour × driver_value`.
  The rate depends only on the (piecewise-constant) driver, so `progress` is closed-form (§5),
  and the rendered value is `interpolate(from, to, progress)`. The **preferred path**; covers
  the overwhelming majority of effects. *(The open-ended-`to` special case — old rate-on-property
  — sets `to:"unbounded"` and an affine interpolate, so `rate` reads in the property's own units.)*
- **`saturating`** (state-coupled, still closed-form on each interval): `dProgress/dt =
  k × driver × (1 − progress)` — progress eases toward 1. Within one constant-driver interval
  this is a **linear ODE** with a closed-form exponential solution (§5.3) — no numerical
  integration, queryable at any `T`. This is how "the transition slows as it completes" is
  expressed without leaving the closed-form world.
- **`coupled`** (the fallback, §5.4): genuinely nonlinear coupling between *multiple* evolving
  progress variables that has no closed form. Specified, fenced, used only where unavoidable.

A negative effective rate (driver dropped / opposed) drives **progress back toward 0** — the
transition reverses (§2.2), no special machinery. A transition whose `progress` is set to jump
`0→1` in one log event is the old instantaneous `prop_delta` impulse (§2.1), a discrete log
event.

---

## 4. What's stored vs. what's derived — the transition record

A continuous property is **not stored as a materialized number that the holder re-writes every
tick.** That is the staircase model and its drift risk. Instead the body stores **transition
records**, and the rendered value is recomputed on read:

> **A property's value at query time `T` is RECOMPUTED on read as
> `interpolate(from, to, progress(T))`.** The transition record stores `from` (the snapshot at
> the start event), `to` (the target), and the **progress baseline** `{prog_base, base_t}` —
> the value of `progress` at `base_t`. `progress(T)` is `prog_base` plus the closed-form
> driver-driven accrual from `base_t` to `T` (§5), clamped to `[0,1]`. Nothing is cached that
> can drift.

```
Segment.transitions = {
  "volume_ml": {                          # one active transition on this property
    "from":      650000,                  # µL snapshot at start (fixed-point — §6)
    "to":        4000000,                 # µL target ("unbounded" for open-ended rate-on-prop)
    "interp":    "lerp",
    "prog_base": 0,                       # progress value at base_t (fixed-point, §6)
    "base_t":    3600                      # full-time at which this baseline holds
  }
}
```

`progress(T)` walks the driver timeline from `base_t` and sums the closed-form rate (§5),
clamped to `[0,1]`; the rendered `volume_ml` is then `interpolate(650000, 4000000,
progress(T))`. A property with **no active transition** is a plain constant (its stored
`from`, which equals its old bare value). A discrete impulse (old `prop_delta`) or a structural
reset commits a **new transition record** — `from` = the value at that instant, fresh
`{prog_base, base_t}` — collapsing prior evolution into a fresh baseline so the sum never
reaches past the last event.

This is the same "derive on read, store the minimum" stance as description-from-state
(`transformation-system.md` §6) and derived-sex (`compound-parts-and-fluids.md` §6): the graph
stores ground truth (the transition records + the driver timeline), readable quantities are
pure functions of it.

### 4.1 The `interpolate` function — scalar (lerp) vs. categorical (blend / threshold)

`interpolate(from, to, p)` with `p = progress(T) ∈ [0,1]` is a **pure deterministic function**,
typed by what the property is. The progress math (§5) is identical in every case; only the
projection differs:

- **Scalar transition — `lerp` (interpolate).** For numeric properties (`volume_ml`,
  `length_cm`, an axis scalar): `interpolate(from, to, p) = from + ((to − from) · p)`, all
  fixed-point integer (§6): compute `(to − from) · p_fixed` then divide by the progress scale —
  exact, order-independent. Bounded transitions interpolate cleanly between two finite values —
  **a capability the pure rate-on-property model could not express** (it only accrued
  open-endedly toward a clamp). `from`/`to` give a true bounded segment.
- **Categorical / material transition — `blend` or `threshold` on progress.** For a qualitative
  change (`material: flesh → chitin`):
  - **`blend`**: the describe/render layer reads progress directly and reports a **mixture** —
    "60% chitinized" / a flesh↔chitin material blend weight `p` handed to the shader. The
    canonical state stays `from`+`to`+`p`; the blend is a render-layer projection. No discrete
    flip until content wants one.
  - **`threshold`**: the categorical `material` field flips **discretely** when `p` crosses a
    pinned threshold (e.g. `material := to` once `p ≥ 0.5`) — a discrete log event content
    emits, so the categorical axis stays a clean enum value while the transition supplies the
    *timing*. Below threshold it reads `from`; at/above, `to`.

Both categorical forms key off the **same driven `progress`**; the only difference from a
scalar transition is the projection function. So bounded scalar morphs and gradual material
changes are the *same* unit with different `interp`.

---

## 5. The deterministic formulation (the careful part)

The replay invariant is **non-negotiable**: body-state-at-query-`T` must be reproducible
**purely from `seed + action log`**, bit-for-bit, queryable at *any* `T`, independent of how
many times or in what order it was queried. Here is the formulation and its defense. **The
quantity §5 evolves is `progress ∈ [0,1]`** (the driven state variable of a transition); the
rendered property is `interpolate(from, to, progress(T))` (§4.1), a pure function on top — so
proving `progress(T)` replay-exact proves the whole rendered value replay-exact, since
`interpolate` is deterministic fixed-point with no time dependence of its own.

### 5.1 Why piecewise-constant drivers make this exact

**Drivers change only at discrete log events** (§3). A driver is set by an action; that action
is in the log with a full-time stamp; between two consecutive driver-change events the driver
value is **constant**. Therefore, for a `linear` effect, the **progress** rate `r =
per_unit_per_hour × driver_value` is **constant on each inter-event interval**. A constant rate
over a known duration is a closed-form product — **no integration, no step size, no drift.**

### 5.2 The closed-form sum (linear effects — the preferred path)

Let a transition's **`progress`** start at baseline `prog_base` at time `base_t`, and let the
driver timeline (restricted to drivers with effects on this transition) have change-points
`base_t = t₀ < t₁ < t₂ < … < tₙ ≤ T`, with the driver value (hence the progress-rate `rᵢ`)
constant on each interval `[tᵢ, tᵢ₊₁)`. Then:

```
progress(T) = clamp01( prog_base + Σ_{i=0}^{n-1}  rᵢ · (t_{i+1} − t_i)   +   rₙ · (T − t_n) )
                          ╰────────── full closed intervals ──────────╯   ╰─ final partial interval ─╯
```

where `rᵢ` is the **summed rate of every effect** active on this progress over interval `i`
(multiple drivers can drive one transition; their rates add — a linear superposition; a driver
opposing gives a negative term, so reversal §2.2 is the same sum with a sign). Each term is
`rate × duration`, integer fixed-point arithmetic (§6); the sum is **clamped to `[0,1]`**. The
rendered property is then `interpolate(from, to, progress(T))` (§4.1) — itself fixed-point and
order-independent, so it adds no drift.

**This is exact and replay-safe because:**
- Every `tᵢ` is a logged full-time stamp → a function of the action log.
- Every `rᵢ` is `per_unit_per_hour × driver_value` → integer fixed-point, no float.
- `(t_{i+1} − t_i)` is integer-second subtraction → exact.
- The sum is a finite sum of integer products → associative, order-independent, no
  accumulation error. **There is no per-tick stepping**, so there is *no step-size parameter
  and no drift to accumulate*: the same `T` always yields the same integer `progress`, whether
  queried once or a thousand times, in any order — and `interpolate(from, to, ·)` of an
  identical `progress` is an identical rendered value.
- It is queryable at **any** `T`, not just at tick boundaries — the final partial interval
  `rₙ · (T − tₙ)` handles arbitrary `T`. (Contrast the staircase, which only had values at
  `stage_seconds` multiples.)
- The `[0,1]` clamp is monotone and idempotent — a `progress` already pinned at 1 (transition
  complete, body at `to`) or at 0 (reversed back to `from`) reads the same on every query.

The holder no longer steps anything per tick. It maintains only the **driver timeline** and the
transition records (`from`/`to`/baseline); the rendered value is a **lazy read** that walks the
(short) list of change-points, sums into `progress`, and interpolates. Cost is O(change-points
since last baseline) per query — bounded by §7.

### 5.3 Saturating effects — still closed-form per interval

For `rate.kind = "saturating"` (progress eases toward 1: `dp/dt = k·d·(1 − p)`), within a
single constant-driver interval `d` is constant, so this is a **first-order linear ODE with
constant coefficients** on `progress`, whose closed-form solution is:

```
p(t_{i+1}) = 1 + (p(t_i) − 1)·exp(−(k·d̂)·(t_{i+1} − t_i))      where d̂ normalizes the driver
```

We compute this **per interval**, feeding each interval's endpoint as the next interval's start
`p(tᵢ)`. Still no fixed-step integration — one closed-form evaluation per interval — and the
rendered property is `interpolate(from, to, p)` on top, so saturation toward `to` falls out of
progress easing toward 1.

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

Genuine nonlinearity that couples **multiple simultaneously-evolving progress variables** (one
transition's progress drives another's rate while that one drives the first's) has no closed
form. For that — and **only** that — the fallback is **fixed deterministic integration** on the
coupled progresses, with this discipline:

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

> For any body, any transition with progress `p` and rendered property `value`, and any query
> time `T`: `p(T)` — and therefore `value(T) = interpolate(from, to, p(T))` — is a pure
> function of `(world_seed, action_log)` and `T`. It does not depend on **when** the query is
> issued, **how many times** it is issued, or **in what order** relative to other queries. The
> driver timeline, effect map, and transition records (`from`/`to`/baseline) are reconstructed
> from the action log; the closed-form sum (§5.2 / §5.3) over progress is deterministic
> fixed-point arithmetic clamped to `[0,1]`; `interpolate` (§4.1) is deterministic fixed-point
> with no time dependence of its own; impulses and structural events are discrete log entries
> that commit a fresh transition baseline. Replaying the action log on one runtime reproduces
> every `p(T)` — hence every `value(T)` — bit-for-bit. The fixed-point representation (§6)
> removes the cross-platform-float hazard for the linear path; the saturating path's `exp` uses
> a pinned deterministic approximation; the coupled fallback is fixed-step fixed-point. Lazy
> reads are referentially transparent: a value read late equals the same value read eagerly.

This is the same `seed + action log` contract `sim_clock.gd` and `tf_applier.gd` already hold;
this doc keeps it under continuous evolution by **never stepping a mutable cache** and instead
**summing a closed form over the logged driver timeline.**

---

## 6. Numeric representation — fixed-point (and the integer-volume question answered)

**Decision: progress, continuous state values, and driver values are FIXED-POINT —
integer-backed at a chosen per-quantity resolution.** **Progress** ∈ [0,1] is stored as an
integer fraction (e.g. millionths — `progress · 1_000_000`), so the §5.2 sum and the §4.1
interpolate are exact integer arithmetic. `from`/`to` snapshots carry the affected property's
own resolution: volume in **microlitres (µL)** (`volume_ml × 1000`), lengths in **hundredths of
a cm** (the unit `tf_applier.gd` already uses for `prop_delta` draws — integer hundredths),
fluids in **integer mL** (as `compound-parts-and-fluids.md` §5.1 already mandates), driver
values in **hundredths**.

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

Resolution per quantity is a **fixed table** (millionths for progress, µL for volume, cm/100
for length, mL for fluid, driver/100 for drivers), pinned once, never per-body. Round-trips through JSON as exact
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
  constraints; keep them local"). We **forbid the dense driver×transition matrix**: an effect
  binds **one driver to one transition's progress on targeted-segments**. There is no implicit
  all-pairs coupling. Total cost per body is O(active transitions/effects), and the author
  controls that count directly. `coupled` clusters (§5.4) are the only place progress↔progress
  interactions exist, and they are fenced and small.

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

The example exercises both a **bounded scalar transition** (§4.1 lerp, §5.2 linear progress)
and a **saturating transition** for fluid production (generalizing `compound-parts-and-fluids.md`
§5.4 from a binary toggle to a driven transition).

**Setup.** A body with two `breast` segments (`compound-parts-and-fluids.md` §3.4), each
carrying `props.volume_ml` (fixed-point µL) and a `milk` fluid `{amount, capacity}` (integer
mL). Two transitions in the content map:

```
# (a) estrogen → breast volume: a BOUNDED scalar transition (lerp, linear progress §5.2)
{ "id":"estrogen_breast_growth", "target":{"select":"all_tagged","tag":"breast"},
  "affects":{"prop":"volume_ml"},
  "from":"snapshot", "to":{"value":4000000},        # 650000 µL → 4,000,000 µL (4000 mL)
  "interp":"lerp",
  "driver":"estrogen", "rate":{"kind":"linear","per_unit_per_hour":0.025} }  # progress/h per estrogen-unit

# (b) prolactin → milk: a SATURATING transition (progress eases to 1 = full)
{ "id":"prolactin_lactation", "target":{"select":"all_tagged","tag":"breast"},
  "affects":{"fluid":"milk"},
  "from":"snapshot", "to":{"fluid":"milk","value":"capacity"},   # 0 → cap mL
  "interp":"lerp",
  "driver":"prolactin", "rate":{"kind":"saturating","k":10} } }  # dp/dt = 10·prolactin·(1−p)
```

**Transformation = declare the transitions' starts + set drivers** (each a logged action with a
full-time stamp; the start event commits each `from` snapshot):
- At `t=3600` (1 h in): `set estrogen = 80`. Breast transition starts (`from`=650000 µL
  captured), progress begins climbing — **growth is now driven, not scheduled** (§2.2).
- At `t=3600`: `set prolactin = 60`. Milk transition starts, progress eases toward 1.
- At `t=90000`: `set estrogen = 20` (a later dose tapers). Progress-rate drops; growth slows
  but continues. *(Were estrogen set to a negative-equivalent opposing driver, progress would
  fall and the breast would shrink back toward `from` — reversal for free, §2.2.)*

**Querying breast volume at any `T`** (§5.2 progress, then §4.1 lerp). The transition is
`from=650000`, `to=4000000`. Progress baseline `prog_base=0` at `base_t=3600`. Over
`[3600, 90000)` estrogen=80 → progress-rate `0.025·80/3600` per second; over `[90000, T)`
estrogen=20 → `0.025·20/3600` per second (all fixed-point millionths). So:

```
progress(T) = clamp01( 0
            + 0.025·80·(90000−3600)/3600          # interval [3600,90000)
            + 0.025·20·(T−90000)/3600 )           # interval [90000,T): partial, any T
volume(T)   = interpolate(650000, 4000000, progress(T))   # = 650000 + (4000000−650000)·progress(T)
```

Over `[3600, 90000)` progress accrues `0.025·80·86400/3600 = 48` — far past 1, so it **clamps
to 1**: the transition completes, the breast reaches exactly `to = 4,000,000 µL = 4000 mL` and
holds. The bound is **`to` itself**, not a separate `clamp` field — the bounded transition
*has* its ceiling built in, which the pure rate-on-property model could not express without a
side clamp. The **displayed cup** is re-derived by `tf_measure.gd` from `volume_ml/1000` +
`band_cm` on every describe (unchanged) — so the cup letter increases as the interpolated
volume crosses band thresholds, with no stored cup. **Queried at any `T`, progress (hence
volume) is the same integer every replay** — the §5.5 guarantee.

**Querying milk at any `T`** (saturating progress, §5.3, then lerp `from=0`→`to=cap`). Over
`[3600, T)` with prolactin=60, progress eases `p(T) = 1 − exp(−(10·60̂)·(T−3600))` per the
pinned fixed-point `exp`, and `milk(T) = interpolate(0, cap, p(T)) = cap·p(T)` — asymptotically
filling to capacity and self-limiting (progress never exceeds 1, so milk never exceeds `cap`).
**Lactation is now a driven transition, not a binary toggle:** `prolactin = 0` → progress
frozen, no production; `prolactin = 60` → fills over hours; `prolactin = 200` → fills fast;
**lowering prolactin slows it, an opposing driver reverses it** (progress falls, milk drains
down toward `from`); the milk amount is modulatable from *any* value by moving the driver, and
it is reproducible at any query time. An explicit drain act (emptying the reservoir) is still a
discrete `fluid_delta` impulse — a transition whose progress jumps to re-base the fluid (§2.1).
This is exactly the §5.4-of-`compound-parts-and-fluids` tie-in, generalized: the "standing
staged TF that does one fluid_delta per tick" is replaced by **a prolactin-driven saturating
transition** — smooth, queryable at any `T`, modulatable, and reversible.

### 8.1 Worked example — resize/reshape a lactating breast → milk and production carry

Now run a **size transition concurrently with the milk transition on the same segment** — the
motivating §9.2 case. The breast segment `#breast_l` is mid-lactation (the §8b prolactin
transition is in flight, milk amount climbing) when a *separate* reshape driver starts a
`volume_ml` transition on the **same** segment (e.g. estrogen ramps further, or a sculpt driver
reshapes it). Two transitions now ride the **same identity** `#breast_l`:

- the `milk` saturating transition (`from=0 → to="capacity"`, driven by prolactin) — **unchanged**;
- the new `volume_ml` transition (`from`=current µL → `to`=new µL, driven by the reshape driver).

Because both are anchored to `#breast_l`, **the reshape does not touch the milk.** At any `T`:
`volume_ml(T) = interpolate(from_vol, to_vol, progress_vol(T))` and `milk(T) = interpolate(0, cap,
progress_milk(T))` are computed **independently off their own progress baselines** — the breast
grows/reshapes while the milk keeps filling. **Nothing is lost; production never pauses.** If the
reshape **raises capacity** (a bigger breast holds more), the milk transition's `to="capacity"`
now resolves to the **new** cap, so `milk` eases toward the larger bound — the amount *transitions*
to the new capacity rather than being clipped or zeroed. If it **lowers** capacity below the
current amount, the milk amount transitions **down** to the new cap (excess drains, a continuous
full→new magnitude move — not a discrete loss). The contrast: had we **replaced** `#breast_l` with
a different segment instead of transforming it in place, the milk would have followed the
§9.2 fluid-handoff rule (handed to the successor, or spilled) — a genuinely different, lossy
operation. Identity-preserving transform is the default precisely so this concurrent case "just
works."

### 8.2 Worked example — structural transition: biped-lower → taur-lower via targeted ops

A whole-subtree reshape exercises §9.1. The lower body goes from a **biped lower** (`#hips` with
two `#leg_l`/`#leg_r` children) to a **taur lower** (`#hips` with a `#barrel` and four
`#leg_fl`/`#leg_fr`/`#leg_bl`/`#leg_br` children). There is **no `from-structure`/`to-structure`
diff and no correspondence map.** The author writes the change as a **bundle of per-part targeted
ops**, all sharing one progress driver `taurify`:

```
biped_to_taur = {                       # an authored bundle, one shared progress driver
  "driver": "taurify",
  "ops": [
    # 1. in-place change: existing #hips keeps its id, its scalars transition
    { "kind":"transform", "target":{"id":"#hips"},
      "affects":{"prop":"width_cm"}, "from":"snapshot", "to":{"value":...}, "interp":"lerp" },

    # 2. in-place change: the two existing legs transition to rear-leg form (same ids)
    { "kind":"transform", "target":{"id":"#leg_l"}, "affects":{"prop":"pose"}, ... },
    { "kind":"transform", "target":{"id":"#leg_r"}, "affects":{"prop":"pose"}, ... },

    # 3. add: graft a barrel + two front legs as NEW identities, each 0→full
    { "kind":"graft", "parent":{"id":"#hips"}, "subtree":"barrel",  "grow_in":true },
    { "kind":"graft", "parent":{"id":"#hips"}, "subtree":"leg_fl",  "grow_in":true },
    { "kind":"graft", "parent":{"id":"#hips"}, "subtree":"leg_fr",  "grow_in":true }
    # (no remove op here — the biped legs are reused in place by op 2, not dropped)
  ]
}
```

Driven by the shared `taurify` progress, the bundle runs:

- **`#hips`, `#leg_l`, `#leg_r`** (`transform` ops): each targets an **existing id**; its scalars
  **interpolate** in place, identity preserved, any attached state riding along (§9.2). The author
  *chose* to reuse the two biped legs as the rear legs — these are not deleted and recreated.
- **`#barrel`, `#leg_fl`, `#leg_fr`** (`graft` ops with `grow_in`): each is a **new identity**,
  grafted at zero extent in one discrete log event at progress=0, then a continuous **0→full**
  magnitude transition swells it as progress climbs.

Had the author instead wanted the biped legs **dropped** (a true four-new-legs taur), they would
write three `graft` ops for the new legs plus a `remove` op targeting the old legs by selector —
e.g. `{ "kind":"remove", "target":{"select":"all_tagged","tag":"biped_leg"} }` — which runs a
full→0 shrink on those resolved ids and drops them at progress=1. **The author's ops say exactly
which parts are reused, added, and dropped; nothing is matched or inferred.** Reverse the driver
and progress falls: grafted parts shrink back toward zero and drop at progress=0, transformed parts
interpolate back to biped form — the bundle undoes itself, graft/drop events firing at the
boundaries. Every magnitude move is the closed-form §5 progress read; every graft/drop is a
discrete log event; every selector resolves deterministically — all replay-exact (§9.3).

### 8.3 Worked example — more / fewer breasts (add = graft new ids, remove = nth_tagged + drop)

Changing breast *count* is two targeted ops, no diff. Start with two `breast` segments under
`#torso`; the author wants **four**, then later **back to two**.

```
# add two: graft two NEW identities under the torso, each growing in from zero
add_breasts = { "driver":"polymastia", "ops":[
  { "kind":"graft", "parent":{"id":"#torso"}, "subtree":"breast", "grow_in":true },
  { "kind":"graft", "parent":{"id":"#torso"}, "subtree":"breast", "grow_in":true } ] }

# remove two: target the LAST two by ordinal, shrink to zero, drop at progress=1
remove_breasts = { "driver":"polymastia", "ops":[
  { "kind":"remove", "target":{"select":"nth_tagged","tag":"breast","nth":[2,3]} } ] }
```

- **Add** = an explicit graft of new identities. Each new breast is in the graph from progress=0⁺
  at ~zero volume, its `volume_ml` a 0→full transition. Existing breasts are **untouched** — they
  keep their ids, their milk, their in-flight transitions.
- **Remove** = a **`nth_tagged`** selector (`nth:[2,3]`, ordered deterministically by id —
  `transformation-system.md`'s ordinal targeting) resolving to **exactly** the two the author
  named; each runs a full→0 `volume_ml` shrink and is dropped at progress=1. The selector says
  precisely which two go; there is no "which of the four corresponds to which of the two" question
  because there is no diff.

If `add_breasts` and `remove_breasts` ran with **overlapping** progress, the shrinking pair and the
growing pair would briefly both be present (four-ish breasts mid-transition). **That is an authoring
choice, not an edge case:** share one progress driver to overlap them, or **stagger** the drivers
(remove completes before add starts) to sequence them cleanly. The model imposes neither.

### 8.4 Worked example — a breast nested under a specific torso segment (query + identity)

Nesting is native. A breast can be a child of a *specific* torso segment (say `#torso_upper`, a
sub-segment of a segmented torso) rather than the torso root. It is reached and targeted by a
**structural query**, and its identity survives re-segmenting the parent:

```
# target: the breasts whose parent is the upper-torso segment
{ "kind":"transform",
  "target":{"select":"query","where":{"tag":"breast","parent":{"tag":"torso_upper"}}},
  "affects":{"prop":"volume_ml"}, "from":"snapshot", "to":{"value":...}, "interp":"lerp" }
```

- The breast is just a **child in the graph**, identified by its stable id and **reachable by the
  structural query** (`tag:breast` under `parent: torso_upper`) — no special "nested part" case.
- If a later op **re-segments the parent** (splits `#torso_upper`, or re-tags it), the breast's
  **id is unchanged** — it is **reparented** to the appropriate new parent segment by a discrete
  `reparent` log event, and **keeps its identity** (and its milk, drivers, in-flight transitions,
  §9.2). The child is never lost when the parent changes shape; nesting is native, not a special
  case, and identity rides through reparenting exactly as it rides an in-place transform.

---

## 9. How discrete structural events coexist with continuous evolution

Both live in the **same action log**, interleaved by full-time:

- **Discrete events** (graft/remove/reparent, categorical `set_material`/`set_covering`,
  adding a finger/nipple, an impulse `prop_delta`, a drain `fluid_delta`) are applied by the
  **existing `tf_applier.gd` unchanged**, at their log instant. A structural or impulse event
  that touches a continuous property **commits a fresh transition record** (`from`=value-now,
  fresh `{prog_base, base_t}`) at that instant (§4), collapsing all prior driven evolution into
  the new baseline so the closed-form progress sum after it starts clean.
- **Continuous evolution** (driven transitions) is **not applied at instants at all** — it is
  the closed-form progress read + `interpolate` (§5, §4.1) over the driver timeline between
  baselines.

So a session reads, in log order: *graft a tail (discrete) → start a `length_cm` transition
`from→to` + set `tailgrow` driver high (continuous, tail length now interpolates as progress
climbs) → at some `T`, remove the tail (discrete, the transition now drives nothing because the
segment is gone) → graft a new tail (discrete, fresh transition) → …*. The describe pass at any
`T` reads each segment's current scalar via `interpolate(from, to, progress(T))` and its
current structure/material directly off the graph — exactly as `transformation-system.md` §6
describes, now with continuous values resolved lazily through driven transitions.

**Undo** (`transformation-system.md` §5.4) extends cleanly: a driver-set is a logged event
with a captured `before` driver value; undo restores it, and because rendered values are
*derived* as `interpolate(from, to, progress(driver-timeline))`, restoring the driver restores
all downstream progress and property values for free — **no per-property undo needed for
continuous evolution** (only impulses, transition-starts that commit a baseline, and structural
events carry captured before/after, as today). This is strictly *less* undo bookkeeping than
the staircase model. (Note: driver-driven *reversal* §2.2 — progress falling because a driver
dropped — is distinct from *undo*; reversal is forward replay under new drivers, undo rewinds
the log itself.)

### 9.1 Structural transitions as a bundle of authored, per-part TARGETED transitions

A *single* part growing in (graft-at-zero + a 0→full magnitude transition, §2.1) generalizes to
**arbitrary part changes on arbitrary subtrees** with **no new mechanism and no whole-structure
diff.** A *structural transformation is a bundle of per-part TARGETED transitions* — the same
targeted ops the engine already has (`transformation-system.md`'s structural/ordinal/query
targeting), optionally sharing one progress driver. **There is no `from-structure` vs.
`to-structure` comparison and no inferred correspondence between two graphs.** Each op names what
it acts on by an authored **selector**: a stable segment id, tags, an ordinal (`nth_tagged`,
ordered deterministically by id), or a structural query. There are exactly three op kinds:

- **Add parts (`graft`)** — an explicit graft of **N new identities**, each growing in from zero
  extent: the new part is in the graph from progress=0⁺ via a discrete **graft-at-zero** log
  event, and its size is a continuous **0→full** magnitude transition (§2.1). Existing parts are
  **untouched**.
- **Remove parts (`remove`)** — an explicit **targeted shrink-to-zero-then-drop** on
  **selector-resolved existing identities** (e.g. `nth_tagged` on the last two, deterministic by
  id). The resolved parts run a continuous **full→0** magnitude transition and are **dropped in
  one discrete log event at progress=1** (`remove_subtree`). The author's selector says **exactly**
  which parts go.
- **Change parts in place (`transform`)** — target an **existing identity**; its properties
  transition (§4.1). **Identity is preserved** — and thus every attached fluid, driver, and
  in-flight sub-transition is preserved (§9.2).

A whole "form A → form B" (e.g. biped→taur, §8.2) is authored **as such targeted ops** — drop
these legs, graft this barrel + these legs as new identities, resize this — optionally all sharing
**one progress driver** so they move together. It is **never** a structure diff. So a transition's
`from`/`to` is **per-property on a targeted identity**, not per-whole-structure.

**"Correspondence" = authored targeting, deterministic, no matching/inference.** The question "which
old part becomes which new part" does not arise, because the author never describes a *new whole
structure* to be matched against the old one — they describe **ops on selected identities**. An
in-place change is the **same id** by construction; an add is a **new id**; a remove is a
**selector-resolved existing id**. Which state rides along (§9.2) is therefore unambiguous and
replay-deterministic: it follows the id the op named. The graph-matching ambiguity the old "diff
two graphs" framing carried is **gone** — there is nothing to match.

**Nesting is native, not a special case.** A part nested in a subpart (e.g. a breast under a
specific torso segment, §8.4) is just a **child in the graph**, identified by id and reachable by
a structural query. Re-segmenting the parent does **not** lose the child's identity: the child is
**reparented** (a discrete `reparent` event) and keeps its id and everything riding it. Nesting
needs no extra machinery; the same targeting reaches a child at any depth.

That is the **whole** mechanism: discrete graft/drop events at the boundaries (progress 0 for
grafts, progress 1 for drops), continuous magnitude transitions filling the interior, in-place
changes interpolating on a preserved id. No part is ever topologically half-present; "gradual
structural appearance" is always discrete-topology + continuous-scalar.

**The overlap note (an authoring choice, not an edge case).** When a remove (shrinking) and an add
(growing) share **overlapping** progress, both the old and new parts are briefly present together
(§8.3). That is **chosen** by how the author wires progress: **share one driver** to overlap them,
or **stagger** the drivers to sequence them (remove finishes before add starts). The model imposes
neither and treats neither as special — overlap and staggering are both ordinary authored progress
wiring.

### 9.2 State rides IDENTITY, not structure (the lactation-mid-TF case)

This is the **core principle**, and the motivating case is concrete: **a breast lactating WHILE
being transformed.** A driver reshapes the breast — resizes it, changes its form — at the same
time prolactin is driving its milk transition (§8). What happens to the milk?

**Answer: nothing is lost — because the transition transforms the part IN PLACE, preserving its
identity.** The breast keeps its **segment id** through the reshape. Everything attached to that
identity **rides along**:

- the **fluid amount** (`milk`) is unchanged by the reshape — it is attached to the segment id,
  not to its size;
- the **drivers** acting on the segment (`prolactin`, the reshape driver) keep acting;
- any **in-flight sub-transitions** (the saturating milk transition itself) keep running, at the
  same progress, off the same baseline.

So the breast is resized/reshaped **and** keeps its milk **and** keeps producing — concurrently,
with no special handling, because both the milk transition and the size transition are just
driven transitions anchored to the **same identity**. If the reshape changes the breast's
**capacity** (e.g. a larger breast holds more milk), the **fluid amount can itself transition** —
the `milk` transition's `to` ("capacity") tracks the new capacity, so the amount eases toward the
new bound rather than being clipped or reset. Capacity change is one more continuous magnitude
transition on the same identity; the milk rides it.

**Contrast — REPLACEMENT is a genuinely distinct operation, NOT a transformation.** Replacement
*deletes* one part and *creates* a different one (different identity). It is the right operation
when replacement is **actually meant** (a part is genuinely substituted, not morphed), and **only
replacement loses or relocates attached state** — because the old identity, and everything riding
it, is gone. We therefore **default to the identity-preserving transform** (a `transform` op
on an existing id, §9.1) and **reserve replacement** for when substitution is the real intent. When a transition
*does* replace a part, it MUST specify an explicit **fluid-handoff rule**: either **hand off** the
attached fluid to the successor part (amount transferred, clamped to the successor's capacity), or
**spill / lose** it (the fluid is released or discarded). There is no implicit default; replacement
that drops state silently is a defect. (The transform-vs-replace boundary and this handoff rule
are open questions — §12.)

**The tie to §9.1.** This is why the authored-targeted structural model (§9.1) is clean rather
than ambiguous — identity is decided by the op kind, not inferred:

- a **`transform`** op targets an **existing id** = **same identity transformed in place** → all
  attached state (fluids, drivers, sub-transitions) **carries**, per this section;
- a **`graft`** op introduces a **new id** → the added part starts with no attached state;
- a **`remove`** op targets a **selector-resolved existing id** → its attached state follows the
  fluid-handoff rule (handed to a successor the author names, else spilled/lost at the drop).

So the authored selector *is* the identity map, and identity is what state rides — **no graph
matching decides it.** This is the local, concrete instance of
`simulation-depth-and-materialization.md`'s **stable identity / fact identity** principle — *state
rides identity, not structure* — applied to bodies: a fact (a milk amount, a driver, an in-flight
progress) denotes the same thing across a transformation **because it is keyed to a stable segment
identity** the author targeted by id/tag/ordinal/query, not to a position or shape that the
transformation changes.

### 9.3 Why the targeted-ops + identity model does not break replay

The whole model is **fully inside the existing determinism envelope** (§5):

- **Progress is unchanged** — still the closed-form-over-piecewise-constant-drivers driven variable
  of §5.2/§5.3, clamped to `[0,1]`, fixed-point (§6). A structural transformation's ops may share
  **one** progress driver; in-place transitions, added parts' 0→full, and removed parts' full→0 all
  read the **same** progress(T). No new dynamical quantity is introduced.
- **The graft/drop events are discrete log events** — exactly the graft/drop events §9 already
  interleaves. A **graft-at-zero** fires once at an `graft` op's start (progress=0); a **drop**
  fires once when a `remove` op's shrink reaches progress=1. Each is a single logged
  `graft_subtree` / `remove_subtree` / `reparent` with a full-time stamp, applied by
  `tf_applier.gd` unchanged, and each commits fresh transition baselines on the parts it touches
  (§4) so the closed-form sum stays clean.
- **Every op's target is an authored selector** resolved **deterministically** — an id, a tag, an
  ordinal (`nth_tagged`, ordered by id), or a structural query — exactly as
  `transformation-system.md`'s targeting already resolves, and committed in the op record. There is
  **no graph matching anywhere** (not at author time, not at read time), so nothing about which part
  an op acts on depends on query order or runtime. Identity-preservation is therefore deterministic:
  the same id carries the same attached state on every replay.
- **Replacement's fluid-handoff** is a discrete log event carrying its captured before/after
  (amount moved or spilled) — ordinary impulse bookkeeping (§4, §9), replay-exact and undoable.

So a structural transformation replays bit-for-bit: discrete graft/drop/reparent/handoff events
from the log, continuous magnitude transitions from the closed-form progress sum, every target a
deterministically-resolved authored selector. The §5.5 guarantee holds verbatim — the
targeted-ops + identity model adds **no** new nondeterminism and **no** new per-tick stepping.

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
2. **Transition records + an effect map** (§3.1, §4): a transition is content-authored data —
   `{target, affects, from, to, interp}` — and an effect binds `driver→rate-on-progress` to it.
   A transition-start action commits the `from` snapshot and a `{prog_base, base_t}` baseline.
   New content table + per-segment `transitions` storage alongside the existing TF records.
3. **Driven progress as the core state** (§2, §4): each active transition stores its progress
   baseline `{prog_base, base_t}`; the rendered property is **derived**, not stored. **Migration:**
   an existing bare-number prop is a transition with no active driver — `from`=the number, no
   progress motion — so it reads as a constant forever (fully back-compatible).
4. **A closed-form progress reader + `interpolate` projection** (§5.2/§5.3, §4.1):
   `prop_value(body, seg, prop, T) = interpolate(from, to, progress(T))`, where `progress(T)` is
   the fixed-point sum over driver change-points clamped to `[0,1]`. This is the one genuinely
   new piece of math (progress sum) plus a small typed projection (lerp / blend / threshold).
   `tf_describe.gd` and gate evaluation call it instead of reading a bare field.
5. **Fixed-point resolution table** (§6): progress in millionths; µL / cm·100 / mL / driver·100.
   Volume props move from mL-int to µL-int (a 1000× rescale on migrate).
6. **Identity-anchored transitions** (§3.1, §9.2): a transition's `target` resolves to **segment
   ids** at its start event and anchors to those ids; attached state (fluids, drivers, in-flight
   sub-transitions) is keyed to the **segment id** so it rides a transform in place. Mostly a
   discipline on the existing graph (segments already have stable ids), plus storing the resolved
   id set on the transition record.
7. **Structural transformations as authored targeted-op bundles** (§9.1): a structural change is a
   **bundle of per-part targeted ops** — `transform` (existing id, in place), `graft` (new id,
   grow-in 0→full), `remove` (selector-resolved existing ids, shrink full→0 then drop) — optionally
   sharing one progress driver. Each op's `target` is a **deterministically-resolved authored
   selector** (id / tag / `nth_tagged` ordinal / structural query) — the existing targeting, reused.
   A small **bundle orchestrator** emits each `graft` at progress=0, runs each part's magnitude
   transition off the shared progress, and emits each `remove`'s drop at progress=1. Reuses
   `graft_subtree`/`remove_subtree`/`reparent` (`tf_applier.gd`) unchanged for the discrete events.
   **There is NO from/to-structure diff and NO correspondence map — nothing is matched or inferred**
   (the graph-matching hazard is gone; "which part" is always an authored selector).
8. **Transform-vs-replace + fluid-handoff** (§9.2): identity-preserving transform is the default;
   a **replace** op (delete one identity, create another) is a distinct, opt-in operation that MUST
   carry an explicit fluid-handoff rule (hand-to-successor or spill/lose), recorded as a discrete
   log event with captured before/after.

**Removed / subsumed:** the **staged-TF schedule for continuous change** is **replaced by driven
transitions** (§2.2) — there is no `stage_seconds` clock for continuous growth; start / pause /
accelerate / reverse all fall out of the progress rate's sign and magnitude. The
`compound-parts-and-fluids.md` §5.4 "standing staged TF, one fluid_delta per stage" becomes a
driven saturating transition. The previous **rate-on-property** core is demoted to the
open-ended-`to` special case (§2.1). Instantaneous `prop_delta` / `fluid_delta` **remain** as
progress-jump impulses (§2.1). The `one_op_per_stage` creeping-boundary mechanism
(`tf_applier.gd`) stays only for *discrete* staged structural/categorical TFs.

---

## 11. MVP slice (smallest real version + the quick fixes)

The smallest thing that is a *real* driven-transition system, built on the existing graph:

**The dynamical core (closed-form only, zero coupled effects):**
- **2 drivers:** `estrogen`, `prolactin` (open-vocabulary, two shipped values — same
  discipline as tags/materials).
- **2 driven transitions:** a **bounded scalar** breast `volume_ml` transition (`from→to`,
  lerp, linear progress — §8a) and a **saturating** `milk` fluid transition (`0→cap`, progress
  eases to 1 — §8b). One linear, one saturating; both expressed as `{from, to, progress}` —
  exercises both closed-form paths and the lerp projection; **no `coupled` effect ships.** (A
  `threshold`/`blend` categorical transition is *specified* in §4.1 but need not ship in the MVP;
  if it does, a flesh→chitin material transition is the cheapest demo.)
- **Transition records + driver timeline + `set_driver` action + the closed-form progress
  reader and `interpolate`** (§5.2/§5.3, §4.1) in fixed-point (§6). `tf_describe.gd` and gates
  read through `interpolate(from, to, progress(T))`.
- **One identity-carry case (small, ships):** the §8.1 concurrent case — a `volume_ml` transition
  and the `milk` transition active on the **same** breast segment id at once, demonstrating the
  reshape does not disturb the milk (state rides identity, §9.2). This needs no new machinery
  beyond anchoring both transitions to the segment id; it is the cheapest proof the identity model
  holds.
- **Determinism test (added to `tests/run.sh`):** same seed + action log → identical `progress`
  and `prop_value` at several arbitrary `T` (including non-tick `T`), queried in scrambled order
  → identical; progress clamps correctly at 0 and 1 (completion and full reversal); a driver
  dropped/opposed drives progress back down (reversal §2.2); save/load round-trip of the
  timeline + transition records → identical; undo of a `set_driver` restores all downstream
  values; an impulse `prop_delta` (progress-jump) re-bases correctly and coexists with a driven
  transition; **two transitions on the same segment id (size + milk) stay independent and the
  reshape leaves the milk amount untouched** (§8.1 identity-carry).
- **Playtest surface:** extend the text harness (`tools/tf_play.gd`) with driver sliders
  (`estrogen`, `prolactin`) and a "query at T" control; advance the clock, watch breast cup grow
  smoothly toward `to` and milk fill toward capacity, **drop a driver and watch it reverse**,
  scrub `T` backward/forward and confirm the same body reads the same values. **Observe the
  actual transcript** (mandatory playtest, CLAUDE.md) — smooth interpolation, correct cup
  banding, clean reversal, no staircase.

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

**Ship it OPEN from day one** (same discipline as the parent MVPs): drivers, transitions,
effects, and the fixed-point quantities are **open vocabulary / few shipped values**, never a
closed enum. The closed-form progress reader and `interpolate` work unchanged as drivers,
transitions, and effects are added.

**Deferred:** the **multi-part structural-transformation bundle** (§9.1) — a whole-subtree reshape
like §8.2's biped→taur, or §8.3's breast-count change — and the **replace op + fluid-handoff**
(§9.2); the MVP ships the **identity-carry property** (a single part transformed in place keeps its
attached state, §8.1) and the single-part grow-in/shrink-out (graft-at-zero + 0→full; full→0 +
drop) it already needs, but the *multi-op bundle orchestration sharing one progress driver* (each
op a deterministically-resolved authored selector — no diff, no matching) is the next slice, not
the first.
Also deferred: the `coupled` nonlinear fallback (§5.4) and its materialization cadence; the
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
   just the impulse delta. The mechanism is clear (capture `(prog_base, base_t)` and the prior
   `from`/`to` before/after, like any other prop capture); the open part is confirming the
   interaction of re-basing + undo + the closed-form read has no edge case where a stale
   baseline survives an undo. A test target, not a design gap — flagged for rigor.

5. **(NEW — raised by the transition reframe) Concurrent transitions on the same property —
   compose, queue, or last-writer-wins?** With the core unit a `{from, to, progress}` record,
   two transitions can target the *same* property on the *same* segment (e.g. an estrogen
   `volume_ml` growth transition still mid-progress when a *separate* surgical-reduction
   transition starts). Their `from`/`to`/progress disagree, and the rendered value is ambiguous.
   Three honest candidate policies, none yet chosen: **(a) last-writer-wins** — a new
   transition-start snapshots `from` = the *current interpolated value* and supersedes the old
   record (simplest, deterministic, but silently discards in-flight progress of the old one);
   **(b) queue** — the new transition waits until the current one completes/reverses to 0 before
   starting (clean but can stall, and "completes" is driver-dependent so it may never fire);
   **(c) compose** — multiple transitions on one property sum their *contributions* (each an
   independent driven `(from→to)·progress` term), which is the natural generalization of the old
   linear-superposition-of-rates (§5.2) but needs a defined meaning for two bounded transitions
   with disagreeing `to`. **Lean: last-writer-wins for the MVP** (matches today's single-record
   storage and is trivially replay-exact), with compose flagged as the likely eventual answer
   for genuinely independent simultaneous effects — but this is **not decided**, and §4's
   single-record `Segment.transitions[prop]` shape presumes (a) until it is. Flagged, not
   over-designed.

6. **(NEW — transform vs. replace) The transform/replace boundary and the fluid-handoff rule.**
   Identity-preserving **transform** is the default (§9.2); **replace** (delete one identity,
   create another) is the distinct, lossy operation reserved for genuine substitution. Open: where
   exactly the boundary sits — is a part that changes *material* (flesh→chitin) and *role*
   entirely still "the same part transformed," or a replacement? — and what makes that call
   deterministic and authorable rather than a judgment call. Open too: the **fluid-handoff rule**
   on replacement — hand-to-successor (and how the successor is named, and how the amount is
   clamped to the successor's capacity) vs. spill/lose, and whether there is ever a sane *default*
   or it must always be authored per replace. Lean: always-authored, no silent default, until the
   real cases cluster into a defensible rule. Flagged honestly; not over-designed.

---

*Design pass. No code. Extends `transformation-system.md` (graph unchanged) and
`compound-parts-and-fluids.md` (fluids driver-driven). Not green. Awaits the user's express
approval.*
