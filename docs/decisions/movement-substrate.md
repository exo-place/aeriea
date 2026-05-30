# Decision: Data-driven, composable movement substrate

Status: **designed, not yet implemented** (2026-05-31)

Scope: the architecture for aeriea's movement kit. This doc is the spec.
It does **not** contain implementation code; the build is staged in
"Incremental implementation plan" below.

---

## Why this exists

Movement is the per-second dopamine engine of aeriea (DESIGN.md, *Movement
that doesn't waste your time*, *Variety of power fantasies §1*). The current
prototype (`scripts/player_controller.gd`) proves the *feel* — carving,
momentum preservation, coyote/buffer leniency, slide/wall-run/vault — but it
is a hand-written imperative state machine. Every verb is hardcoded GDScript.

That conflicts with two committed principles:

- **"Prefer data over code at every seam — serializable AST/struct/JSON over
  closures, embedded DSLs, or source text, so artifacts cache, replay,
  transport, and diff."** (CLAUDE.md, Ecosystem Design Principles)
- **"Library-first; projection-from-one-definition."** A movement *kit* should
  be one definition projected to an interpreter (live preview) and to compiled
  code (perf), never two hand-maintained surfaces.

And it conflicts with the product goal: the movement verbs (bullet jump, air
burst, charge, wormhole, teleport, aim, wall-cling — TODO.md backlog) are a
*starting vocabulary*. The novel substrate is not "we have these powers" — it
is that **the powers are recomposable, reconfigurable data**, not hardcoded
abilities. That is the thing that makes it not a Warframe ripoff: a designer
(later, a player) reshapes the kit without touching engine code.

So: the movement system is **a state machine expressed as data**, with
**conditions and effects that are themselves an enumerable, serializable
vocabulary of primitives** — never embedded closures or source text.

---

## Design decisions

### 1. The serializable schema

A movement kit is a single serializable document (JSON on disk; in-engine a
typed Resource / struct tree). Five node kinds:

1. **Params** — the tuning surface. A flat map of named scalars/vectors
   (`walk_speed`, `coyote_time`, `slide_friction`, …). These are exactly
   today's `@export` vars, lifted out of code into data. All other nodes
   reference params **by name**, never by literal, so designers tune in one
   place and the same numbers drive interpreter and compiled paths.

2. **States** — named nodes of the state machine (`GROUND`, `AIR`, `SLIDE`,
   `CROUCH`, `WALL_RUN`, `VAULT`, …). A state carries:
   - `on_enter`: ordered list of **Effects** run once on transition in.
   - `tick`: ordered list of **Effects** run every physics tick while active.
   - `on_exit`: ordered list of **Effects** run once on transition out.
   - `transitions`: ordered list of **Transitions** evaluated each tick.

3. **Transitions** — `{ when: Condition, to: state_name, do: [Effect] }`.
   `when` is a single Condition (composable, see below). `do` is an optional
   ordered effect list run *during* the transition (e.g. the slide-jump
   impulse). First transition whose guard is true wins (ordered, deterministic).

4. **Conditions** — a small **closed, tagged-union vocabulary** of predicate
   primitives. A Condition is data: `{ "op": "...", ...args }`. Composable via
   `all` / `any` / `not`. The leaf predicates are the irreducible set:

   | op | args | meaning |
   |----|------|---------|
   | `on_ground` | — | `is_on_floor()` |
   | `airborne` | — | `not is_on_floor()` |
   | `speed_h` | `cmp, value` | horizontal speed `>= / < / …` param/literal |
   | `speed_v` | `cmp, value` | vertical velocity comparison |
   | `timer` | `name, cmp, value` | a named timer comparison (e.g. `coyote > 0`) |
   | `input_pressed` | `action` | `Input.is_action_pressed(action)` (sampled, see §3) |
   | `input_buffered` | `action` | buffered-edge timer `> 0` (e.g. jump buffer) |
   | `wish_input` | (none) / `aligned_with_velocity, cmp, value` | any move input / dot of wish-dir vs velocity |
   | `wall_detected` | `side` | raycast wall probe (`any`/`left`/`right`) |
   | `wall_still_near` | — | re-probe of the currently-tracked wall |
   | `ledge_vaultable` | — | the vault ray triple resolves to a climbable ledge |
   | `headroom` | — | upward clearance ray is clear (can stand) |
   | `slope_angle` | `cmp, value` | floor-normal angle comparison |
   | `below_y` | `value` | `global_position.y < value` (kill plane) |
   | `all` / `any` / `not` | `of: [Condition]` | boolean composition |

   `cmp` ∈ `{ge, gt, le, lt, eq}`. `value` is a number **or** a param name.
   This set covers every guard in today's controller (validated in §"Worked
   examples"). New leaf predicates are added only when a verb genuinely cannot
   be expressed — and adding one is an engine change reviewed against
   "collapse asymmetries to primitives," not a per-verb hack.

5. **Effects** — a small **closed, tagged-union vocabulary** of mutation
   primitives. An Effect is data: `{ "do": "...", ...args }`. The irreducible set:

   | do | args | meaning |
   |----|------|---------|
   | `set_velocity_y` | `value` | `velocity.y = v` (jump impulse) |
   | `add_velocity` | `space, vector` | add to velocity in `world`/`wish`/`forward`/`wall_tangent`/`wall_normal` space |
   | `accelerate_toward` | `target, rate, max` | `move_toward` of horizontal velocity toward a target dir·speed at `rate` (ground accel, air-strafe, crouch accel) |
   | `apply_friction` | `rate` | `move_toward(0, rate·dt)` of horizontal velocity |
   | `carve` | `rate` | steer velocity *direction* toward wish-dir at `rate` without changing magnitude (the slide carve) |
   | `apply_gravity` | `scale` | `velocity.y -= gravity·scale·dt` (scale may be a curve, below) |
   | `clamp_speed_h` | `max` | `limit_length` of horizontal velocity |
   | `slope_accelerate` | `rate, ref_angle` | downhill push proportional to slope angle |
   | `set_collider_height` | `value` | resize capsule, keep feet planted |
   | `set_timer` | `name, value` | `timer = value` (start coyote/buffer/wall-run/slide) |
   | `lerp_camera_height` | `target, rate` | camera pivot height ease |
   | `lerp_fov` | `target, rate` | dynamic FOV ease |
   | `lerp_camera_roll` | `target, rate` | wall-run tilt |
   | `tween_position` | `from, to, duration_timer` | scripted move (vault/mantle) |
   | `respawn` | — | teleport to spawn, zero velocity + timers |
   | `move_and_slide` | — | commit the physics step (explicit, so its ordering is data) |

   `scale` and `rate` args may be a **literal**, a **param name**, or a small
   serializable **curve** `{ "curve": "ramp", over_timer, from, to, power }`
   (this is how wall-run's gravity ramp stays data, not code). Curves are a
   closed set too: `const | ramp | lerp`.

   Effects are **pure transforms over an explicit state record** (see §3); they
   read/write velocity, position, timers, collider, camera — nothing else.
   There are no closures and no inline expressions: an effect that needs a
   computed direction names a *space* (`wish`, `forward`, `wall_tangent`), and
   the interpreter supplies that vector from the tick's sampled state.

**Type sketch** (engine-side, the typed library; JSON is the wire form):

```
MovementKit  = { params: Map<str, Scalar|Vec3>, initial: str, states: [State] }
State        = { name, on_enter:[Effect], tick:[Effect], on_exit:[Effect], transitions:[Transition] }
Transition   = { when: Condition, to: str, do:[Effect] }
Condition    = { op: CondOp, ...typed args }      # closed union
Effect       = { do: EffectOp, ...typed args }    # closed union
Value        = number | param_name | Curve
```

The whole kit is one diffable, cacheable, transportable artifact. Two kits
diff cleanly; a verb is a reviewable patch.

### 2. Composition model

A **verb is a data unit**, not a code unit. A verb is one of:

- **a new transition** added to existing states (e.g. *bullet jump* = a
  transition out of `AIR` guarded by `input_buffered(ability_1)` whose `do`
  adds a velocity burst), and/or
- **a new state** with its own `tick`/`transitions` (e.g. *wall-cling* = a
  `WALL_CLING` state, entered from `WALL_RUN`/`AIR`, that zeroes velocity and
  exits on input or timer).

Composition is **kit overlay**. The base kit is `movement/base.kit.json`. A
verb is a small **patch document** `movement/verbs/bullet_jump.kit.json` that
declares: params to add, transitions to insert (into which state, at what
**priority**), and states to add. Loading = base ⊕ ordered list of enabled
verb patches → one flattened `MovementKit`. This is the seam for layering.

**Ordering / conflict resolution is explicit and data-driven**, because
transition evaluation is "first matching guard wins":

- Each transition carries an integer `priority`. Within a state, transitions
  are sorted by `priority` descending, then by insertion order, deterministically.
- A verb patch states the priority band it inserts at (e.g. slide-jump must
  out-prioritize the slide's decay-exit, exactly as the current code checks
  jump *before* the exit conditions). This makes today's implicit ordering —
  which is just statement order in `_process_slide` — **explicit data**.
- Two verbs targeting the same `(state, priority)` is a **load-time error**:
  the kit validator refuses ambiguous ordering rather than silently picking one.
  ("Validate against reality"; no silent nondeterminism.)
- Effects within a transition `do` / a state `tick` run in **listed order**;
  there is no implicit reordering. `move_and_slide` is an explicit effect, so a
  designer controls whether an impulse lands before or after the physics commit.

A designer adds "bullet jump" by dropping a JSON patch in `movement/verbs/`
and enabling it in the kit manifest. No engine edit. If the verb needs a
primitive that doesn't exist, *that* is the only time engine code changes —
and it changes by adding one leaf to the closed Condition/Effect vocabulary,
shared by every verb forever.

### 3. Determinism

The interpreter is a **pure fixed-tick stepper** and must fit the seeded-sim
commitment (DESIGN.md, *Deterministic seeded simulation*).

**Execution model, one physics tick** (`_physics_process(dt)` with Godot's
fixed physics tick; `dt` is constant):

1. **Sample inputs once** into an immutable `InputFrame` at the top of the
   tick: the pressed-set for each action, plus buffered-edge timers updated
   from the edges seen since last tick. No effect or condition reads `Input.*`
   directly — they read the `InputFrame`. (Today the controller reads
   `Input.is_action_pressed` mid-physics; that is the per-frame nondeterminism
   risk we remove. Mouse-look stays separate and does not feed the sim's
   horizontal-plane decisions — wish-dir uses yaw only, sampled once.)
2. **Pre-tick checks**: `below_y(kill_y)` → `respawn`, then decrement all named
   timers by `dt` (one place, deterministic).
3. **Evaluate the active state's `transitions` in sorted order.** First whose
   `when` is true: run its `on_exit` (old) → `do` → `on_enter` (new), set
   active state, and — matching today's "re-run target this frame" behavior —
   optionally continue into the new state's tick the same frame (a transition
   flag `reenter: true`, which is how GROUND→AIR and AIR→GROUND hand off now).
   No transition fires → fall through.
4. **Run the active state's `tick` effects in listed order.**
5. **Update camera** effects (height/FOV/roll) — these are render-side and
   *excluded from the sim hash* (see §6) since they don't affect trajectory.

All state lives in one explicit `MovementState` record: `velocity`,
`global_position`, `collider_height`, the named `timers` map, `wall_normal` /
`wall_side`, active state name. Effects transform this record; nothing hidden.

Evaluation order is total and data-defined (sorted transitions, listed
effects). Given the same seed, same `InputFrame` sequence, and same kit, the
trajectory is bit-reproducible **on one runtime**.

**Float/cross-platform determinism**: DESIGN.md already flags this and accepts
the Trackmania posture (replay validity bounded by runtime) as the fallback,
with fixed-point for the sim layer as the stronger option. This substrate
keeps that door open: because all arithmetic is funneled through the closed
Effect vocabulary, a later swap of the numeric type (float → fixed-point) is a
change to the *interpreter's number type and the few effect kernels*, not a
rewrite of every verb. The data layer is numeric-representation-agnostic. We do
**not** solve cross-platform float determinism now; we keep the substrate
shaped so we can.

### 4. Dual path: interpreter + compiler

Both paths consume the **same flattened `MovementKit`**. This is the
projection-from-one-definition invariant.

**(a) Interpreter** — `MovementInterpreter` (GDScript first). Loads the kit at
runtime, holds the `MovementState` record, and runs the §3 tick loop by
`match`-ing on the `op`/`do` tag of each Condition/Effect. Supports
**hot-reload**: re-load the kit file, keep the live `MovementState`, swap the
definition between ticks. This is the live designer-preview path. It is the
*reference semantics* — the compiled path must match it, not the other way.

**(b) Compiler** — lowers the same kit to branching code. **First target:
GDScript codegen** (pragmatic: the prototype is GDScript, no extra toolchain,
and it removes per-tick tag-dispatch + dictionary lookups for a real perf
edge). The codegen emits one `_physics_process`-shaped function per kit:
transitions become an ordered `if`/`elif` chain, effects become inlined
straight-line statements, params become consts. **Rust/gdext is the later
target** (DESIGN.md: "drop to Rust via gdext for hot paths") once the kit
shape is stable and we actually need it; the same lowering, different backend.

The compiler is a pure function `MovementKit → source text`. Its output is
committed-and-regenerated (like any codegen), header-stamped
`// GENERATED from movement/<kit> — do not edit`.

**Equivalence is the load-bearing test** (detailed in §6): a **golden-trace
harness** runs both paths over identical seed+input logs and asserts identical
`MovementState` trajectories. If they diverge, the compiler is wrong by
definition — the interpreter is the spec.

### 5. Configurability surface

- **Designer-facing config** lives in `movement/` at the project root:
  - `movement/base.kit.json` — the base state machine + params.
  - `movement/verbs/*.kit.json` — one file per composable verb (overlay patches).
  - `movement/<character>.manifest.json` — which base + which verbs + param
    overrides for a given playable kit. This is the file a designer edits to
    assemble a kit.
- **In-engine**, kits load as a typed Resource so they show in the Godot
  inspector; params remain inspector-tunable (preserving today's `@export`
  ergonomics) but the source of truth is the JSON, exported/imported.
- **Player-facing reconfiguration is a deliberate later seam, not built now.**
  Because a kit is data and composition is overlay, a player remap/loadout
  layer is "another overlay source above the designer manifest." We **leave the
  seam** (the loader already takes an ordered list of overlay sources) and
  build nothing player-facing yet. Note: coyote_time / jump_buffer_time stay
  designer-only, exactly as today.

### 6. Validation strategy ("tests are the spec")

Three layers, all xvfb-runnable headlessly (same harness as
`tests/movement_behavior_test.gd`, run via `xvfb-run godot4 --headless
<scene> --quit-after N`):

1. **Behavioral parity (port the existing spec).** The 18 assertions in
   `tests/movement_behavior_test.gd` (low-speed crouch → crouch-walk, high-speed
   crouch → slide, slide steerable+cancelable, slope holds position, no
   vertical jitter, slide speed doesn't compound / never exceeds cap, wall-run
   backward doesn't accelerate forward, respawn below kill_y, jump from real key
   event, …) become the acceptance test for the **data-defined** kit running on
   the interpreter. The verbs change representation; their observable behavior
   must not. These tests already inject real input through the InputMap → they
   exercise the §3 input-sampling path end to end.

2. **Golden traces (determinism + interpreter↔compiler equivalence).** A
   harness takes `(seed, kit, input_log)` where `input_log` is a per-tick list
   of action edges. It steps the **interpreter** and records the full
   `MovementState` trajectory (velocity, position, collider height, timers,
   active state) per tick — excluding camera/FOV/roll (render-only, not
   trajectory). Assertions:
   - **Determinism**: same inputs twice → identical trajectory hash.
   - **Equivalence**: interpreter trajectory == compiled-path trajectory, hash
     for hash. This is the projection-from-one-definition guarantee, mechanized.
   Golden traces are checked in; a behavioral change is a reviewable trace diff.

3. **Kit validation (load-time).** The kit loader rejects: unknown
   `op`/`do`/param references, ambiguous `(state, priority)` collisions, dangling
   `to:` targets, transitions referencing undefined timers. Invalid kits fail
   loudly at load, never silently at runtime.

---

## Worked examples (expressiveness validation)

These express today's hardest verbs in the schema, proving the primitives
suffice. (Param names mirror `player_controller.gd`.)

### Jump with coyote-time + jump-buffer

`input_pressed("jump")` edge sets the buffer timer (in input sampling, §3 step
1, via a per-action `buffer: jump_buffer_time` declaration on the action — data).
Leaving the ground arms coyote. The jump transitions:

```jsonc
// in state GROUND
{ "when": {"op":"input_buffered","action":"jump"},
  "to": "AIR", "priority": 80,
  "do": [ {"do":"set_velocity_y","value":"jump_velocity"},
          {"do":"set_timer","name":"jump_buffer","value":0} ] }

// GROUND→AIR on leaving floor arms coyote (reenter so air logic runs same tick)
{ "when": {"op":"airborne"}, "to":"AIR", "priority":10, "reenter":true,
  "do": [ {"do":"set_timer","name":"coyote","value":"coyote_time"} ] }

// in state AIR — coyote jump: buffered AND still within coyote window
{ "when": {"op":"all","of":[
            {"op":"input_buffered","action":"jump"},
            {"op":"timer","name":"coyote","cmp":"gt","value":0} ]},
  "to":"AIR", "priority":80,
  "do": [ {"do":"set_velocity_y","value":"jump_velocity"},
          {"do":"set_timer","name":"coyote","value":0},
          {"do":"set_timer","name":"jump_buffer","value":0} ] }
```

Floaty-apex (hold-jump) is an `apply_gravity` in AIR's `tick` whose `scale` is
a `ramp` curve gated by a `jump_held` buffered input + `jump_hold_timer` — all
existing primitives.

### Slide (entry threshold + boost + carve + cap + multi-exit)

```jsonc
// GROUND → SLIDE: crouch pressed AND fast enough
{ "when": {"op":"all","of":[
            {"op":"input_pressed","action":"crouch"},
            {"op":"speed_h","cmp":"ge","value":"slide_entry_speed"} ]},
  "to":"SLIDE", "priority":60,
  "do": [ {"do":"add_velocity","space":"forward","vector":"slide_boost"},   // clamped by entry guard below
          {"do":"clamp_speed_h","max":"max_slide_speed"},
          {"do":"set_collider_height","value":"crouch_height"},
          {"do":"set_timer","name":"slide","value":"slide_max_time"},
          {"do":"set_timer","name":"slide_steer","value":0} ] }

// SLIDE.tick — slope accel, cap, carve, friction, commit (LISTED ORDER MATTERS)
"tick": [
  {"do":"slope_accelerate","rate":"slope_acceleration","ref_angle":45},
  {"do":"clamp_speed_h","max":"max_slide_speed"},
  {"do":"carve","rate":"slide_steer_accel"},
  {"do":"apply_friction","rate":"slide_friction"},
  {"do":"move_and_slide"}
]

// SLIDE exits — highest priority: slide-jump (preserve momentum + boost)
{ "when":{"op":"input_buffered","action":"jump"}, "to":"AIR", "priority":90,
  "do":[ {"do":"set_velocity_y","value":"jump_velocity"},
         {"do":"add_velocity","space":"forward","vector":2.5},
         {"do":"set_timer","name":"jump_buffer","value":0} ] }
// airborne mid-slide → AIR (stay crouched)
{ "when":{"op":"airborne"}, "to":"AIR", "priority":70, "reenter":true }
// decayed / timed-out / steered-out / crouch-released → GROUND or CROUCH
{ "when":{"op":"any","of":[
           {"op":"not","of":[{"op":"input_pressed","action":"crouch"}]},
           {"op":"speed_h","cmp":"lt","value":"slide_exit_speed"},
           {"op":"timer","name":"slide","cmp":"le","value":0},
           {"op":"timer","name":"slide_steer","cmp":"ge","value":"slide_steer_exit_time"} ]},
  "to":"GROUND", "priority":40 /* CROUCH variant if crouch still held + no headroom */ }
```

The `slide_steer` timer is incremented by a `tick` effect when wish-input is
sustained-aligned with velocity (`wish_input` condition + `set_timer` delta) —
the "pushing into motion stands you up" behavior, as data. The entry-boost
"don't stack while already sliding" guard is implicit: the entry transition
only fires from GROUND/CROUCH, never SLIDE→SLIDE.

### Wall-run (auto-detect entry + directional input + gravity ramp + exits)

```jsonc
// AIR → WALL_RUN: fast enough, airborne, wall on a side
{ "when": {"op":"all","of":[
            {"op":"speed_h","cmp":"ge","value":"wall_run_min_speed"},
            {"op":"airborne"},
            {"op":"wall_detected","side":"any"} ]},
  "to":"WALL_RUN", "priority":50,
  "do": [ {"do":"set_velocity_y","value":"wall_run_vertical_boost"},   // max(vy, boost)
          {"do":"set_timer","name":"wall_run","value":"wall_run_max_time"} ] }

// WALL_RUN.tick — ramped gravity + run-along-wall + commit
"tick": [
  {"do":"apply_gravity","scale":{"curve":"ramp","over_timer":"wall_run",
        "from":"wall_run_gravity_scale","to":1.0,"power":"wall_run_gravity_ramp"}},
  {"do":"accelerate_toward","target":{"space":"wall_tangent","speed":"wall_run_speed"},
        "rate":"wall_run_speed_rate","max":"wall_run_speed"},   // forward input only; backward→0
  {"do":"move_and_slide"}
]

// WALL_RUN exits
{ "when":{"op":"input_buffered","action":"jump"}, "to":"AIR", "priority":90,
  "do":[ {"do":"add_velocity","space":"wall_normal","vector":"wall_jump_lateral"},
         {"do":"set_velocity_y","value":"wall_jump_up"},
         {"do":"set_timer","name":"jump_buffer","value":0} ] }
{ "when":{"op":"not","of":[{"op":"wall_still_near"}]}, "to":"AIR", "priority":70,
  "do":[ {"do":"set_timer","name":"wall_jump_grace","value":"wall_jump_grace"} ] }
{ "when":{"op":"timer","name":"wall_run","cmp":"le","value":0}, "to":"AIR", "priority":60 }
{ "when":{"op":"not","of":[{"op":"wish_input"}]}, "to":"AIR", "priority":55 }
{ "when":{"op":"on_ground"}, "to":"GROUND", "priority":50 }
```

The "backward input decelerates, lateral ignored, no input holds momentum"
nuance is the `accelerate_toward` reading the `wall_tangent` space, where the
interpreter resolves the target speed from longitudinal input sign (a property
of the `wall_tangent` space resolution, shared by all wall verbs — collapsed to
a primitive, not a per-verb branch). Wall-jump grace re-uses the same buffered-
jump transition in AIR, guarded by `timer(wall_jump_grace) > 0`.

**Vault/mantle** is a `VAULT` state whose `tick` is a single `tween_position`
from `vault_start` to `vault_end` over `vault_duration`, entered by a
`ledge_vaultable` condition. **Respawn** is the pre-tick `below_y` check.
**All current verbs fit.** No schema gap found.

---

## Incremental implementation plan

Each slice is independently xvfb-verifiable. Do not start a slice until the
prior slice's tests pass headlessly.

**Slice 1 — schema + interpreter, ground+jump.**
Define the typed `MovementKit` Resource + JSON loader + the closed
Condition/Effect enums for the primitives ground-move and jump need
(`on_ground`/`airborne`, `input_buffered`, `timer`, `accelerate_toward`,
`apply_friction`, `apply_gravity`, `set_velocity_y`, `set_timer`,
`move_and_slide`). Write `movement/base.kit.json` expressing GROUND + AIR +
jump with coyote + buffer. Interpreter steps it.
*Verify:* the jump-related assertions of `movement_behavior_test.gd`
(`_test_jump_from_real_key_event`, `_test_jump_after_pause_unpause`, binding
survival) pass against an interpreter-driven player. Risk: input-sampling
refactor (moving off mid-physics `Input.*`) is the subtle part — land it here.

**Slice 2 — port slide + crouch + wall-run.**
Add the remaining primitives (`carve`, `slope_accelerate`, `clamp_speed_h`,
`set_collider_height`, `wall_detected`/`wall_still_near`, `wall_tangent` space,
`headroom`, `wish_input`, `ledge_vaultable`, `tween_position`, ramp curve).
Express SLIDE/CROUCH/WALL_RUN/VAULT in `base.kit.json`.
*Verify:* the **full** `movement_behavior_test.gd` (all 18 assertions) passes
against the interpreter. This is the "behavioral parity == old controller"
gate. Risk: slide steer-exit and slope-accel cap ordering — covered by the
no-compound and steerable tests, so it self-checks.

**Slice 3 — compiler + equivalence.**
Build the GDScript codegen (`MovementKit → source`) and the golden-trace
harness. Generate the compiled controller from `base.kit.json`.
*Verify:* golden traces — same `(seed, kit, input_log)` → identical trajectory
hash for interpreter vs compiled vs determinism-repeat. Plus the full
behavioral suite passes against the **compiled** path too. Risk: hidden
nondeterminism (iteration order over a Dictionary, float accumulation order) —
the trace hash catches it immediately; fix by making the offending order data.

**Slice 4 — a new verb as pure data.**
Add `movement/verbs/bullet_jump.kit.json` (an AIR transition guarded by an
ability input, `do: add_velocity` burst, with a cooldown timer) and enable it
in the manifest. **No engine code changes.** Write one behavioral assertion for
it.
*Verify:* bullet-jump fires from real input on the interpreter; recompile →
compiled path matches via golden trace; the existing 18 assertions still pass
(the verb is additive). Risk: a needed primitive is missing — if so, that is
the *one* sanctioned engine change (add a leaf to the closed vocabulary), and
it proves the composition story.

**Later (not slices):** Rust/gdext compile backend; player-facing loadout
overlay (the seam is already there); fixed-point numeric swap for
cross-platform replay validity.

### Risks (summary)

- **Input-sampling refactor** (Slice 1): moving off mid-physics `Input.*` reads
  is the determinism crux; if missed, traces won't reproduce.
- **Ordering fidelity** (Slice 2/3): today's behavior depends on statement
  order in `_process_*`. The `priority` + listed-effect model must reproduce it
  exactly; the parity suite is the guard.
- **Float determinism across platforms** (deferred): explicitly *not* solved;
  substrate kept numeric-agnostic so a fixed-point swap stays a leaf change.
- **Codegen drift** (Slice 3): generated code must never be hand-edited; the
  golden-trace equivalence test fails loudly if interpreter and compiled drift.
- **Vocabulary creep**: every new leaf predicate/effect is an engine change —
  resist per-verb leaves; collapse to primitives. Reviewed against
  "collapse asymmetries to primitives."
