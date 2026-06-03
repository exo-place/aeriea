# Decision: Data-driven, composable affordance substrate

Status: **designed, not yet implemented** (2026-06-03)

Scope: the architecture for aeriea's interaction kit — the "second kit," the
interaction analogue of the movement substrate (`movement-substrate.md`). This
doc is the spec. It does **not** contain implementation code; the build is
staged in "Incremental implementation plan" below.

---

## Why this exists

If movement is the per-second dopamine engine, interaction is the *graph*:
what you can DO at a spot and how those verbs chain into state changes and
unlocks. `reference-analysis.md` names the whole product goal in graph terms —
a **dense, composable interaction graph; few barren nodes; no non-composing
navigational lattices; no stochastic self-loops standing in for play**, with
each state offering a small (Miller-compliant, ≤7) set of *composing command*
edges surfaced diegetically by removal. The pure-text litmus is the unit test:
the affordance graph must survive being rendered as text.

The current prototype (`scripts/interaction/interactor.gd` + the seven
interactable scripts) proves the *structure*: standing at one spot the player
is offered several distinct command affordances that chain into one another and
into movement, producing real state changes and an unlock. The valve→spout→
jug→pedestal→beacon chain and the box-stack→parkour→beacon chain converge on a
beacon that fires only when `armed ∧ reached`. But every interactable is a
hand-written GDScript node, and every verb/guard/effect is hardcoded:

- the valve's "toggle is_flowing + emit flow_changed" is imperative code;
- the spout's "while flowing, fill any overlapping jug" is a hand-wired
  `_physics_process` loop + a signal connection;
- the pedestal's "accept a jug, and if `held.is_full()` then arm the beacon" is
  a bespoke cross-object state read plus a `signal activated`;
- the beacon's `armed ∧ reached` AND-gate is two hand-wired signal handlers.

That conflicts with the same two committed principles the movement substrate
serves:

- **"Prefer data over code at every seam — serializable AST/struct/JSON over
  closures, embedded DSLs, or source text, so artifacts cache, replay,
  transport, and diff."** (CLAUDE.md, Ecosystem Design Principles)
- **"Library-first; projection-from-one-definition."** The interactable's live
  verb set, its diegetic prompt, and (later) compiled per-tick code should be
  one definition projected to many surfaces, never hand-maintained per node.

And it conflicts with the product goal: the slice's interactables are a
*starting vocabulary*. The novel substrate is not "we have a valve and a jug" —
it is that **an interactable is recomposable, reconfigurable data**: a designer
(later, a player) authors a new dense node — its verbs, the guards that gate
them, the state transitions they fire, the cross-object reads that compose
chains — without touching engine code. That is what keeps the interaction
graph dense without an engine edit per node, the exact anti-barren-node
posture `reference-analysis.md` §6 demands.

So: the interaction system is **an affordance graph expressed as data**, with
**guards and effects that are themselves an enumerable, serializable vocabulary
of primitives** — never embedded closures or source text. It rhymes with the
movement kit by construction: states→interactables, transitions→verbs,
conditions→guards, effects→effects, first-match→ordered verb resolution,
interpreter-is-the-spec→compiler-equivalence.

---

## The duck-typed contract the slice converged on (the thing to generalize)

The interactor (`interactor.gd`) dispatches against a duck-typed interactable
surface that the substrate must reproduce exactly as a projection:

- `affordance_prompt(interactor) -> String` — the contextual verb prompt for
  what is possible *right now* (the HUD shows it verbatim).
- `interact(interactor) -> void` — run the primary verb.
- `grab_body(interactor) -> RigidBody3D` (optional) — hand the interactor a
  body to carry (grab is special-cased before `interact`).
- `accepts_held(body) -> bool` (optional) — while carrying, this target accepts
  the held body, so the place/compose verb routes here instead of drop.

Plus the interactor's own carry verbs (grab / drop / throw / force_release) and
its capability discipline: it acts only on the **one interactable under the
reticle** (or the one held) — never arbitrary world state. The substrate keeps
that capability scoping; a verb's `target` is resolved to exactly *focus* or
*held*, never an arbitrary node path.

The load-bearing observations the schema must capture:

1. **Verbs are context-dependent on live state.** "Open valve" vs "Close
   valve"; "Pick up jug (40%)" vs "Pick up full jug". The prompt is a pure
   projection of the *currently-available* verb set.
2. **A verb's availability is a guard.** The pedestal's place verb is only
   meaningful while carrying a jug; its *activation* is gated on `held.is_full()`
   — a guard that reads **another object's state**.
3. **Effects cross objects.** Valve toggling flow changes which edges exist at
   the spout; the pedestal consuming a jug arms the beacon. These are declared
   state transitions across named handles, not bespoke signals.
4. **Convergence is an AND of independent chains.** The beacon = `armed ∧
   reached` where `armed` and `reached` come from two separately-composed
   upstream chains.

---

## Design decisions

### 1. The serializable schema

An interaction world's affordances are a single serializable document (JSON on
disk; in-engine a typed Resource / struct tree). The unit is the
**Interactable**, and the kit is the set of interactable *definitions* plus the
shared primitive vocabulary. Node kinds:

1. **Params** — the tuning surface, exactly as in the movement kit. A flat map
   of named scalars referenced **by name** (`fill_rate`, `full_threshold`,
   `throw_impulse`, `hold_distance`). Today's `@export` vars lifted into data;
   one place to tune, same numbers in interpreter and compiled paths.

2. **State schema** — each interactable declares its **state fields**: named,
   typed, serializable slots (`bool`, `number`, `enum`, `ref`, `socket`). These
   are the *only* mutable state a verb may read or write. Examples:
   - valve: `flowing: bool = false`
   - jug: `fill: number = 0`
   - pedestal: `active: bool = false`, `socketed: socket = empty`
   - beacon: `armed: bool = false`, `triggered: bool = false`

   State is **data, not hidden fields** — the whole point of "simulation
   underneath" and of the seeded-sim hash (§5). A `socket` field holds a handle
   to a consumed object (the placed jug); a `ref` field names another
   interactable for cross-object reads.

3. **Verbs** — the affordance edges. A Verb is data:
   ```
   Verb = { name, kind, target, when: Guard, prompt: PromptTemplate, do: [Effect] }
   ```
   - `name` — stable id (`open`, `fill`, `place`, `grab`, `drop`, `throw`).
   - `kind` ∈ `{ command, grab, place, carry_release }` — maps onto the
     interactor's dispatch (a `grab` verb hands back a body; a `place` verb is
     the held×target compose edge gated by `accepts_held`; `command` is the
     plain `interact`; `carry_release` is drop/throw on the held body). This
     enum collapses the interactor's hand-wired branching to data.
   - `target` ∈ `{ self, focus, held }` — the capability scope. A valve's
     `open` targets `self`; the pedestal's `place` targets `self` but reads
     `held`; a drop targets `held`. No arbitrary paths — capability security
     by construction.
   - `when` — a single **Guard** (closed union, below); the verb is in the live
     edge set iff its guard is true. Absent guard = always available.
   - `prompt` — a **PromptTemplate** (closed: literal string with `{field}` /
     `{pct field}` interpolation over readable state). The prompt is *derived*
     from the same guards/state, never hand-written per branch (see §3).
   - `do` — an ordered list of **Effects** (closed union, below) run when the
     verb fires.

4. **Guards** — a small **closed, tagged-union vocabulary** of predicate
   primitives over three state scopes: **self** (this interactable), **held**
   (the carried object), **focus/target** (the object being acted on / the
   other endpoint of a compose edge), plus **world** (player reach). A Guard is
   data: `{ "op": "...", ...args }`, composable via `all` / `any` / `not`. The
   leaf predicates are the irreducible set:

   | op | args | meaning |
   |----|------|---------|
   | `state_bool` | `scope, field, value` | a bool state field equals value (`self.flowing == true`) |
   | `state_cmp` | `scope, field, cmp, value` | numeric state-field comparison (`held.fill >= full_threshold`) — the **load-bearing case**: scope `held` reads the carried object's fill |
   | `state_enum` | `scope, field, eq` | enum field equals a tag |
   | `socket_empty` | `scope, field` | a socket field holds nothing (pedestal not yet filled) |
   | `is_held` | — | the interactor is carrying something |
   | `held_is` | `tag` | the held body has tag/group `tag` (`jug`) |
   | `focus_is` | `tag` | the focused target has tag/group `tag` |
   | `in_region` | `region` | a body overlaps this interactable's region/Area (spout stream, beacon reach) |
   | `reached_by_player` | — | the player body is in this interactable's region (the beacon's "reached") |
   | `all` / `any` / `not` | `of: [Guard]` | boolean composition |

   `cmp` ∈ `{ge, gt, le, lt, eq}`. `value` is a number, a param name, or a
   *cross-scope state path* (`held.full_threshold`). `scope` ∈ `{self, held,
   focus, world}`. This set covers every guard in the slice (validated in
   "Worked example"). New leaf predicates are added only when a verb genuinely
   cannot be expressed — reviewed against "collapse asymmetries to primitives,"
   never a per-node hack.

5. **Effects** — a small **closed, tagged-union vocabulary** of state-transition
   primitives. An Effect is data: `{ "do": "...", ...args }`. The irreducible
   set, derived by collapsing the slice's hand-wired interactions:

   | do | args | meaning |
   |----|------|---------|
   | `set_state` | `scope, field, value` | set a state field (valve `flowing = true`) |
   | `toggle_state` | `scope, field` | flip a bool field (the valve toggle) |
   | `add_fill` | `scope, field, rate` | `field = clamp(field + rate·dt, lo, hi)` — continuous fill (spout→jug); `rate` may be a param, a literal, or `per_tick` |
   | `emit` | `signal` | raise a named **event** on this interactable (replaces ad-hoc Godot signals; events are data, see §2) |
   | `arm` | `scope, field` | sugar for `set_state(field, true)`, semantically "this gate is now satisfiable" (pedestal arms beacon's `armed`) |
   | `trigger` | `scope, field` | set the terminal/payoff field once (idempotent; the beacon's `triggered`) |
   | `consume_into_socket` | `scope, field` | take the held body out of carry (`force_release`) and bind it into a socket field (pedestal sockets the jug) |
   | `grab_body` | — | hand the interactor *this* body to carry (the grab verb) |
   | `release` | `mode` | drop (`mode: drop`) or throw (`mode: throw`, impulse along look) the held body |
   | `apply_impulse` | `space, magnitude` | velocity impulse on a body in `look`/`world` space (the throw's kick; collapses with `release(throw)` or stands alone) |

   `rate`/`magnitude` args may be a **literal** or a **param name** (mirroring
   the movement kit's Value rule). Effects are **pure transforms over the
   explicit state record** (§5): they read/write declared state fields, carry
   state (held/socket), and emit events — nothing hidden, no closures, no inline
   expressions. An effect that needs the held body's identity names the `held`
   scope; the interpreter supplies it from the tick's resolved focus/held.

   Continuous effects (`add_fill`) run in a **`tick` list** on the interactable
   (gated by a `while` guard), exactly mirroring a state's `tick` in the
   movement kit — that is how "hold the jug under the running spout" stays data.

**Reactions (cross-object wiring as data).** The valve→spout and
pedestal→beacon couplings are today GDScript `signal`/`connect`. The substrate
replaces them with declared **Reactions**:
```
Reaction = { on: EventRef, when: Guard?, do: [Effect] }
```
An interactable lists reactions; `on` names an event (`{ from: ref, event:
"flow_changed" }` or a state-change event). When the referenced event fires and
the optional guard holds, the reaction's effects run. The spout's "while valve
flowing, fill overlapping jug" becomes the spout interactable's `tick`
`add_fill` gated by `state_bool(focus=valve_ref, flowing, true) ∧
in_region(stream)`; the beacon's arming becomes a reaction `on: {from: pedestal,
event: armed} do: [arm(self.armed)]`. Wiring is now diffable data, not a graph
of signal connections.

**Type sketch** (engine-side, the typed library; JSON is the wire form):
```
InteractionKit = { params: Map<str, Scalar>, interactables: [Interactable] }
Interactable   = { id, tags:[str], state: Map<field, TypedSlot>,
                   verbs:[Verb], tick:[Effect-with-while], reactions:[Reaction],
                   regions:[RegionDecl] }
Verb           = { name, kind, target, when: Guard, prompt: PromptTemplate, do:[Effect] }
Guard          = { op: GuardOp, ...typed args }   # closed union
Effect         = { do: EffectOp, ...typed args }  # closed union
Reaction       = { on: EventRef, when: Guard?, do:[Effect] }
StatePath      = { scope, field } | param_name | number
```
The whole kit is one diffable, cacheable, transportable artifact. A new dense
node is a reviewable patch; the chain is a readable graph of refs and reactions.

### 2. Interactable & cross-object state as data

All interactable state lives in the declared `state` map (the typed slots), and
nowhere else. The valve→spout→jug→pedestal→beacon chain is expressed entirely
as **declared state transitions over named handles**, not signals:

- An interactable references another by a `ref` param (`spout.valve = @Valve`,
  `beacon.pedestal = @Pedestal`), resolved at load to a handle — *capability
  style*: it can only read/affect refs it was granted, never arbitrary nodes.
- Cross-object **reads** are guards with a non-`self` scope (`state_cmp(held,
  fill, ge, held.full_threshold)`; `state_bool(ref=valve, flowing, true)`).
- Cross-object **writes** happen through **events + reactions**, not direct
  pokes: an effect `emit`s an event on `self`; a downstream interactable
  declares a `Reaction` on that event. This keeps each interactable's writes
  scoped to itself (it only ever `set_state`s its own fields in reaction to
  *seeing* an upstream event), which is the capability-attenuation discipline.
- A consumed object (the placed jug) is held in a `socket` slot, so "the
  pedestal now contains a full jug" is serializable state, replayable from the
  log, and diffable — not a frozen RigidBody hidden in the scene tree.

### 3. Prompt as a pure projection

The HUD already treats the prompt as data handed up via `prompt_changed`. The
substrate makes the prompt a **pure function of the live verb set + guards**:

1. Compute the **available verb set**: every verb whose `when` guard is true
   under the current (self, held, focus, world) state.
2. Render each available verb's `prompt` template (state interpolated:
   `{pct fill}` → `40%`).
3. The interactor surfaces the contextual slice (today: the single primary
   verb's prompt, or the held-mode drop/throw line, or the place target's
   prompt). Surfacing is **removal-not-prioritization**: the live guard set
   *is* the ≤7 Miller-compliant edge set; legibility falls out of the data,
   not a hand-authored per-state string.

So `affordance_prompt`/`current_prompt` become a projection the interpreter
computes; the seven hand-written `affordance_prompt` methods collapse to
templates. This is the projection-from-one-definition invariant applied to the
diegetic surface — and it is what makes the **pure-text litmus** mechanical:
the text MUD reduction *is* "enumerate the available verb set per node," which
the substrate computes directly.

### 4. AND-gating / convergence as first-class

A payoff verb whose availability requires multiple independently-composed
upstream chains is just a verb with an `all`-composed guard. The beacon:
```jsonc
// beacon verb "complete" — fires only when both chains converged
{ "name":"complete", "kind":"command", "target":"self",
  "when": {"op":"all","of":[
            {"op":"state_bool","scope":"self","field":"armed","value":true},
            {"op":"reached_by_player"} ]},
  "do":[ {"do":"trigger","scope":"self","field":"triggered"} ] }
```
`armed` is set by a reaction on the pedestal's `armed` event (interaction×
interaction chain); `reached_by_player` is a world guard true when the player
body is in the beacon region (movement×interaction chain). The convergence
guard `armed ∧ reached` is **data** — the densest demonstration in the slice,
and the converse guard (unarmed reach is inert) is automatic: the guard is
false, the verb is not in the live set, nothing fires. No hand-wired
`if not is_armed: return`. AND-gating is *the same composition operator* the
movement kit uses (`all` over conditions); convergence is a first-class guard,
not a special node type.

### 5. Determinism

The interpreter is a **pure fixed-tick stepper** that must fit the seeded-sim
commitment (DESIGN.md, *Deterministic seeded simulation*) and align with the
movement interpreter's tick discipline (`movement-substrate.md` §3).

**Execution model, one physics tick** (`_physics_process(dt)`, fixed `dt`):

1. **Resolve the interactor context once** into an immutable frame: the focused
   interactable (raycast result), the held body, region overlaps (which bodies
   are in which regions). No guard/effect reads `Input.*` or re-raycasts
   mid-tick — they read this frame. Verb *firing* is driven by sampled input
   edges (the same `InputFrame` discipline as movement: `interact`/`throw`
   action edges are sampled once at tick top).
2. **Run each interactable's `tick` effects** (those with a `while` guard) in
   declared order over all interactables in a **stable, declared iteration
   order** (kit order — never Dictionary order). This is where `add_fill` runs:
   the spout, while its guard holds, fills the jug a deterministic `rate·dt`.
3. **Process the interactor's verb-fire**: if an input edge fired this tick,
   compute the available verb set on the focus/held target (guards over the
   resolved frame), pick the verb by `kind`/priority (grab before command,
   place before drop — the interactor's existing precedence, now data-ordered),
   run its `do` effects in listed order.
4. **Propagate events**: effects that `emit` enqueue events; reactions whose
   `on` matches and whose `when` holds run their effects — in a **bounded,
   ordered pass** (declared interactable order; a fixed max propagation depth,
   validated at load to be acyclic so propagation terminates deterministically).
5. **Recompute prompts** (projection, §3) for the HUD — render-side, excluded
   from the sim hash.

All state lives in one explicit record: per-interactable `state` maps + socket
contents + the interactor's held/focus. Effects transform this record; nothing
hidden. Evaluation order is total and data-defined (sorted verbs, declared tick
order, acyclic reaction propagation). Given the same seed, the same input-edge +
focus/region sequence, and the same kit, the interaction trajectory is
bit-reproducible **on one runtime** — the same posture and the same
float/cross-platform caveat as the movement kit (numeric-representation-agnostic;
fixed-point swap stays a leaf change; cross-platform float determinism is
*not* solved here).

**Physics composition stays in-engine.** Only the *verb/guard/effect/event
graph* extracts to data. The carry spring, the box-stack settling, the throw
arc, the Area3D overlap test itself remain Godot physics — the substrate reads
their *results* (region membership, held-body identity) into the resolved frame
as guard inputs, and writes *intents* (grab/release/impulse) back out. The seam
is: **the affordance graph is data; the physics that realizes a grab or an
overlap is engine.** (See §6 and Risks.)

### 6. Composition with the movement substrate

Interaction verbs and movement verbs coexist; the box-stack→parkour→beacon
chain crosses both. The seam, stated minimally (not over-designed):

- **Two kits, one tick, separate state.** The movement interpreter owns the
  player's `MovementState` (velocity/position/timers/active state); the
  interaction interpreter owns interactable state + held/focus. They run in the
  same `_physics_process` but do not share a state record.
- **They meet at the body and at regions.** Movement positions the player body;
  interaction's `reached_by_player` / `in_region` guards read that position via
  Area3D overlap. Grab/throw write a body's velocity (an interaction effect
  producing a physics intent); the box thus thrown then becomes terrain the
  movement kit lands on. Neither kit reaches into the other's state record —
  they compose through the **shared physics world**, exactly as the slice does
  (the stacked boxes are physics; the parkour off them is movement; the armed
  beacon is interaction; the convergence is a guard reading the player region).
- **No unified meta-kit now.** A future "the player has a movement loadout AND
  an interaction loadout" overlay is a natural extension (both are overlay-
  composed data), but it is a deliberate later seam, not built. Note it; move on.

### 7. Dual path: interpreter + compiler (mirror movement)

Both paths consume the **same flattened `InteractionKit`** — the projection-
from-one-definition invariant.

**(a) Interpreter** — `InteractionInterpreter` (GDScript first). Loads the kit,
holds the interactable state records, runs the §5 tick loop by `match`-ing on
the `op`/`do` tag of each Guard/Effect, and projects the prompt. Supports
hot-reload (swap the kit between ticks, keep live state). **It is the reference
semantics** — the compiled path must match it, not the reverse.

**(b) Compiler** — lowers the same kit to branching code. First target:
**GDScript codegen** (a generated interactable node per definition; guards
become `if` chains, effects inline statements, reactions wired event handlers).
Rust/gdext is the later target once the kit shape is stable. The compiler is a
pure function `InteractionKit → source text`, committed-and-regenerated,
header-stamped `// GENERATED from interaction/<kit> — do not edit`.

**Equivalence is the load-bearing test**: a **golden-trace harness** runs both
paths over identical seed + input-edge + focus/region logs and asserts identical
interactable-state trajectories (all state fields + socket contents + armed/
triggered, excluding prompt strings which are render-side). If they diverge the
compiler is wrong by definition — the interpreter is the spec. Exactly the
movement kit's §6 discipline.

### 8. Validation strategy ("tests are the spec")

Three layers, all xvfb-runnable headlessly via the existing harness
(`tests/interaction_behavior_test.tscn`):

1. **Behavioral parity (port the existing spec).** The 6 assertions in
   `interaction_behavior_test.gd` (look-at focus+prompt; grab/carry/throw;
   valve toggles flow; chain A fill→place→arms beacon; chain B stack→parkour→
   triggers; convergence guard: unarmed reach is inert) become the acceptance
   test for the **data-defined** interactables on the interpreter. The
   interactables change representation; their observable behavior must not. The
   test already drives the *real* interaction path (raycast focus + verb
   dispatch + real input) → it exercises the §5 frame-resolution path end to end.
2. **Golden traces (determinism + interpreter↔compiler equivalence).** A
   harness takes `(seed, kit, interaction_log)` where the log is per-tick focus/
   held/region + input edges; steps the interpreter; records the full
   interactable-state trajectory per tick. Asserts: same inputs twice → identical
   hash (determinism); interpreter == compiled, hash for hash (equivalence).
3. **Kit validation (load-time).** The loader rejects: unknown `op`/`do`/param/
   field references, dangling `ref`/event targets, cyclic reaction graphs
   (propagation must terminate), verbs whose `target` scope a guard can't be
   resolved against. Invalid kits fail loudly at load, never silently at runtime.

---

## Worked example (expressiveness validation)

Expressing the slice's full chain + the carry verbs in the schema, proving the
primitives suffice. Param names mirror the slice scripts.

### Carry verbs (grab / drop / throw) — the box

```jsonc
{ "id":"box", "tags":["grabbable_box"],
  "state": {},
  "verbs": [
    { "name":"grab", "kind":"grab", "target":"self",
      "when": {"op":"not","of":[{"op":"is_held"}]},
      "prompt":"[E] Pick up    (stack boxes to climb)",
      "do":[ {"do":"grab_body"} ] },
    { "name":"drop", "kind":"carry_release", "target":"held",
      "when": {"op":"is_held"},
      "prompt":"[E] Drop    [F] Throw",
      "do":[ {"do":"release","mode":"drop"} ] },
    { "name":"throw", "kind":"carry_release", "target":"held",
      "when": {"op":"is_held"},
      "prompt":"",   // throw shares the drop line; bound to the throw action
      "do":[ {"do":"release","mode":"throw"},
             {"do":"apply_impulse","space":"look","magnitude":"throw_impulse"} ] }
  ] }
```
Grab/drop/throw are entirely covered by `grab_body` / `release` / `apply_impulse`.
The carry spring stays in-engine (physics, §5); the verbs only express *intent*.

### Valve → spout → jug → pedestal → beacon

```jsonc
// VALVE — a stateful toggle. is_flowing as data; the prompt reads it.
{ "id":"valve", "tags":["valve"],
  "state": { "flowing": {"type":"bool","init":false} },
  "verbs": [
    { "name":"toggle", "kind":"command", "target":"self",
      "when": {},                                   // always usable
      "prompt":"[E] {flowing ? Close valve : Open valve}",   // template over state
      "do":[ {"do":"toggle_state","scope":"self","field":"flowing"},
             {"do":"emit","signal":"flow_changed"} ] } ] }

// SPOUT — while the valve flows AND a jug is in the stream region, fill it.
// (No bespoke _physics_process; this is a `tick` effect gated by a `while` guard.)
{ "id":"spout", "tags":["spout"], "refs": { "valve":"@valve" },
  "regions": [ {"name":"stream","kind":"area"} ],
  "tick": [
    { "while": {"op":"all","of":[
                 {"op":"state_bool","scope":"ref:valve","field":"flowing","value":true},
                 {"op":"in_region","region":"stream"} ]},
      "do": [ {"do":"add_fill","scope":"region:stream:jug","field":"fill","rate":"fill_rate"} ] } ] }

// JUG — a grabbable container with a fill field. Prompt interpolates pct.
{ "id":"jug", "tags":["jug"],
  "state": { "fill": {"type":"number","init":0,"lo":0,"hi":1} },
  "verbs": [
    { "name":"grab", "kind":"grab", "target":"self",
      "when": {"op":"not","of":[{"op":"is_held"}]},
      "prompt":"[E] {fill>=full_threshold ? Pick up full jug : Pick up jug}    ({pct fill}%)",
      "do":[ {"do":"grab_body"} ] } ] }

// PEDESTAL — accepts a held jug; activates only if it is FULL (cross-object read).
{ "id":"pedestal", "tags":["pedestal"],
  "state": { "active": {"type":"bool","init":false},
             "socketed": {"type":"socket","init":"empty"} },
  "verbs": [
    { "name":"place", "kind":"place", "target":"self",
      // available while carrying a jug and this pedestal is empty (accepts_held)
      "when": {"op":"all","of":[
                {"op":"socket_empty","scope":"self","field":"socketed"},
                {"op":"is_held"}, {"op":"held_is","tag":"jug"} ]},
      // prompt branches on the HELD jug's fullness — the load-bearing cross-object guard
      "prompt":"[E] {held.fill>=held.full_threshold ? Place full jug    (activates) : Place jug    (jug is not full)}",
      "do":[ {"do":"consume_into_socket","scope":"self","field":"socketed"},
             // activation is itself a guarded effect: only a FULL jug activates
             {"do":"set_state","scope":"self","field":"active","value":true,
              "when":{"op":"state_cmp","scope":"held","field":"fill","cmp":"ge","value":"held.full_threshold"}},
             {"do":"emit","signal":"activated",
              "when":{"op":"state_bool","scope":"self","field":"active","value":true}} ] } ] }

// BEACON — convergence: armed (reaction on pedestal) AND reached (player region).
{ "id":"beacon", "tags":["beacon"], "refs": { "pedestal":"@pedestal" },
  "regions": [ {"name":"reach","kind":"area"} ],
  "state": { "armed": {"type":"bool","init":false},
             "triggered": {"type":"bool","init":false} },
  "reactions": [
    { "on": {"from":"ref:pedestal","event":"activated"},
      "do":[ {"do":"arm","scope":"self","field":"armed"} ] } ],
  // the payoff verb is auto-fired by reach; modeled as a region-entry reaction
  "reactions+": [
    { "on": {"from":"self","event":"region_entered:reach:player"},
      "when": {"op":"state_bool","scope":"self","field":"armed","value":true},
      "do":[ {"do":"trigger","scope":"self","field":"triggered"} ] } ] }
```

Every slice behavior maps onto the primitive set:

- **valve toggle** → `toggle_state` + `emit`; prompt template reads `flowing`.
- **spout continuous fill** → a `tick` `add_fill` gated by a `while` guard
  combining a cross-object `state_bool(ref:valve)` and `in_region(stream)`.
- **jug fill + full check** → numeric `fill` state, `state_cmp(... ge
  full_threshold)` in the pedestal prompt and activation guard.
- **pedestal cross-object activation** → `consume_into_socket` then a *guarded*
  `set_state` reading `held.fill` — the verb whose effect depends on another
  object's state, expressed as a guarded effect, no bespoke code.
- **beacon arm** → a Reaction on the pedestal's `activated` event (replaces the
  `signal activated`/`connect`).
- **beacon AND-gate** → the trigger reaction's `when: armed` over a region-entry
  event; unarmed reach is inert because the guard is false. Convergence is data.

**No schema gap found.** The two new shapes beyond the movement kit — *guarded
effects* (an effect carrying its own `when`, for "consume always but activate
only if full") and *reactions* (event→effect wiring as data) — are the
irreducible additions interaction needs over movement, and both are still closed
data unions. If a future interactable needs a primitive that doesn't exist, that
is the *one* sanctioned engine change: add a leaf to the closed Guard/Effect
vocabulary, shared by every interactable forever.

---

## Incremental implementation plan

Each slice is independently xvfb-verifiable against
`tests/interaction_behavior_test.tscn`. The existing **6/6 must keep passing**
as interactions move to data. Do not start a slice until the prior slice's tests
pass headlessly.

**Slice 1 — schema + interpreter, reproduce the sandbox as data.**
Define the typed `InteractionKit` Resource + JSON loader + the closed Guard/
Effect/Verb/Reaction enums for every primitive the slice needs (`toggle_state`,
`set_state`, `add_fill`, `emit`, `arm`, `trigger`, `consume_into_socket`,
`grab_body`, `release`, `apply_impulse`; guards `state_bool`, `state_cmp`,
`socket_empty`, `is_held`, `held_is`, `in_region`, `reached_by_player`,
`all/any/not`). Write `interaction/sandbox.kit.json` expressing valve, spout,
jug, pedestal, beacon, box as data. Drive the interactor's verb dispatch and
prompt projection from the interpreter instead of the seven hand-written nodes.
*Verify:* the **full 6 assertions** of `interaction_behavior_test.gd` pass
against the interpreter-driven interactables. Risk: the frame-resolution refactor
(focus/region sampled once; no mid-tick re-raycast) is the determinism crux —
land it here. The carry spring / box physics stay in-engine.

**Slice 2 — compiler + golden-trace equivalence.**
Build the GDScript codegen (`InteractionKit → source`) and the golden-trace
harness (per-tick interactable-state trajectory hash). Generate the compiled
interactables from `sandbox.kit.json`.
*Verify:* golden traces — same `(seed, kit, interaction_log)` → identical state
trajectory hash for interpreter vs compiled vs determinism-repeat; plus the 6
behavioral assertions pass against the **compiled** path too. Risk: hidden
nondeterminism (interactable iteration order, reaction propagation order, float
fill accumulation order) — the trace hash catches it; fix by making the order
data (declared kit order, acyclic reaction pass).

**Slice 3 — a new interactable authored purely as data (the payoff proof).**
The analogue of movement's bullet-jump. Author a brand-new dense node entirely
in `interaction/` JSON with **no engine code change** — e.g. a **pressure
plate + door** (plate region-entry arms; a lever toggles; door opens on
`plate_held ∧ lever_on` — a *second* AND-gate convergence proving the pattern
generalizes), or a **two-jug recipe socket** (place jug A *and* jug B → mix).
Add one behavioral assertion for it.
*Verify:* the new node works from real input on the interpreter; recompile →
compiled path matches via golden trace; the existing 6 assertions still pass
(the node is additive). Risk: a needed primitive is missing — if so, that is the
*one* sanctioned engine change (add a leaf to the closed vocabulary), and it
proves the composition story exactly as bullet-jump did for movement.

**Later (not slices):** Rust/gdext compile backend; a player/designer authoring
surface for interactables (the kit is already data; the seam exists); a unified
movement+interaction loadout overlay; fixed-point numeric swap for cross-platform
replay validity.

### Risks (summary)

- **Frame-resolution refactor** (Slice 1): moving off mid-tick re-raycast /
  `Input.*` reads to a once-per-tick resolved frame is the determinism crux; if
  missed, golden traces won't reproduce.
- **Physics/affordance seam** (all slices): physics composition — box-stacking,
  the carry spring, throw arcs, Area3D overlap — **stays in-engine**; only the
  verb/guard/effect/event graph extracts. A guard reads physics *results*
  (region membership, held identity) into the frame; an effect writes physics
  *intents* (grab/release/impulse). Mis-drawing this seam (trying to make the
  spring or stack settling "data") is the over-design trap — don't.
- **Reaction-graph cycles** (Slice 2): event→reaction→event must be acyclic and
  bounded so propagation terminates deterministically; the load-time validator
  is the guard.
- **Ordering fidelity** (Slice 1/2): the interactor's verb precedence (grab
  before command, place before drop) and the spout's continuous-fill timing
  must reproduce exactly; the parity suite is the guard.
- **Float determinism across platforms** (deferred): explicitly *not* solved;
  substrate kept numeric-agnostic so a fixed-point swap stays a leaf change.
- **Codegen drift** (Slice 2): generated interactables must never be hand-edited;
  the golden-trace equivalence test fails loudly if interpreter and compiled
  drift.
- **Vocabulary creep**: every new leaf guard/effect is an engine change — resist
  per-node leaves; collapse to primitives. Reviewed against "collapse
  asymmetries to primitives."
