## MovementInterpreter — the deterministic fixed-tick stepper that runs a
## MovementKit as the reference semantics (docs/decisions/movement-substrate.md
## §3, §4a). SLICE 1: ground move + jump. SLICE 2: slide, crouch-walk, wall-run,
## wall-jump, vault/mantle, kill-plane respawn — the full verb set, ported from
## the imperative PlayerController into data.
##
## Determinism crux (Slice 1's key refactor): input is sampled ONCE per tick into
## an immutable InputFrame at the top of step(). No Condition or Effect reads
## Input.* — they read the frame. This removes the prototype's mid-physics
## Input.is_action_pressed reads.
##
## The interpreter mutates an explicit MovementRecord (velocity, position, timers,
## active state, wall_normal/wall_side, collider height). It drives a
## CharacterBody3D (the `body`) for the actual physics (move_and_slide /
## is_on_floor / raycasts). The body IS the simulation surface; the record mirrors
## the trajectory-relevant fields. Camera/FOV/roll are render-only — they are
## effects too, but excluded from the trajectory hash.
##
## A handful of operations need the physics world or scene nodes (wall/ledge
## raycasts, capsule resize, camera nodes, respawn transform). The interpreter
## stays the *semantics* layer: it calls back into the host (`body`, which is an
## InterpretedPlayer) for those world primitives via a small, named protocol
## (host_* methods). The conditionals stay in data; only the irreducible
## world-access kernels live on the host.
class_name MovementInterpreter
extends RefCounted

# ---------------------------------------------------------------------------
# Immutable per-tick input frame (sampled once, §3 step 1).
# ---------------------------------------------------------------------------

class InputFrame:
	extends RefCounted
	## action -> bool (pressed this tick).
	var pressed: Dictionary = {}
	## Wish direction in world space (yaw-rotated), already normalized or zero.
	var wish_dir: Vector3 = Vector3.ZERO
	func is_pressed(action: String) -> bool:
		return bool(pressed.get(action, false))

# ---------------------------------------------------------------------------
# Explicit mutable simulation record (§3). Everything the sim touches lives here
# or on the body; nothing hidden.
# ---------------------------------------------------------------------------

var kit: MovementKit
var body: CharacterBody3D
var active_state: String = ""
var timers: Dictionary = {}     # name -> float (>= 0 for countdowns; slide_steer accumulates)
var gravity: float = 9.8

## Currently-tracked wall (set by wall_detected when it fires; read by
## wall_still_near / wall_tangent / wall_normal / the wall-jump effect). +1 right,
## -1 left; Vector3.ZERO normal means "no wall tracked".
var wall_normal: Vector3 = Vector3.ZERO
var wall_side: float = 0.0

## Held-input edge state for buffered/hold actions. Updated in _sample_input from
## edges since last tick. Buffer timers live in `timers` keyed by action name.
var _held_last: Dictionary = {}   # action -> bool (held at end of previous tick)

## Source of yaw for wish-dir (radians). The body's rotation.y by default; the
## host can override for tests. Mouse-look stays separate (yaw only, sampled once).
var yaw: float = 0.0

## Source of pitch for the `aim`/look space (radians, +up). Fed by the host from
## its camera-pivot pitch each tick (parallel to `yaw`). Mouse-look already drives
## the camera transform; this wires that same look state into the sim so a verb can
## launch along the FULL 3D look direction (Warframe bullet jump). `yaw` alone is
## horizontal-only (`forward` space); `aim` = yaw+pitch. Render-only for every other
## effect — only verbs that name the `aim` space read it, so the rest of the sim is
## unchanged. Sampled once per tick (deterministic), like yaw.
var pitch: float = 0.0

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(p_kit: MovementKit, p_body: CharacterBody3D) -> void:
	kit = p_kit
	body = p_body
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	active_state = kit.initial
	# Initialise every timer this kit references to 0.
	timers = {}
	for action in kit.inputs:
		timers[action] = 0.0
	# Pre-declare the well-known timers the base kit uses; unknown names are
	# created on first set_timer anyway.
	for t in ["coyote", "jump_buffer", "jump_hold", "slide", "slide_steer",
			"wall_run", "wall_jump_grace", "vault"]:
		timers[t] = 0.0
	for action in kit.inputs:
		_held_last[action] = false

## Reset all sim state to spawn (used by respawn). Keeps the kit/body bindings.
func reset_state() -> void:
	active_state = kit.initial
	wall_normal = Vector3.ZERO
	wall_side = 0.0
	for k in timers:
		timers[k] = 0.0

# ---------------------------------------------------------------------------
# The tick (one _physics_process). §3 execution model.
# ---------------------------------------------------------------------------

func step(dt: float) -> void:
	# 1. Sample inputs once into an immutable frame.
	var frame := _sample_input(dt)

	# 2a. Pre-tick transitions (§3 step 2): e.g. below_y → respawn. Evaluated
	#     before timers/transitions, regardless of active state. A firing pre_tick
	#     transition runs its effects, sets its target state, and ABORTS the rest
	#     of the tick (mirrors the imperative pre-tick `return`).
	for tr: MovementKit.Transition in kit.pre_tick:
		if _eval_condition(tr.when_cond, frame):
			_run_effects(tr.do_effects, frame, dt)
			active_state = tr.to_state
			return

	# 2b. Pre-tick: decrement all named countdown timers by dt, in one place.
	#    jump_hold accumulates while held (handled in _sample_input); slide_steer
	#    is driven by an explicit add_timer effect, so neither is decremented here.
	for name in timers:
		if name == "jump_hold" or name == "slide_steer":
			continue
		timers[name] = maxf(0.0, float(timers[name]) - dt)

	# 3. Evaluate the active state's transitions in sorted order; first match wins.
	#    Loop to honour reenter (a transition may chain into the target's tick the
	#    same frame, matching the prototype's GROUND<->AIR handoff).
	var guard := 0
	while guard < 8:
		guard += 1
		var st: MovementKit.MovementState = kit.states[active_state]
		var fired: MovementKit.Transition = null
		for tr: MovementKit.Transition in st.transitions:
			if _eval_condition(tr.when_cond, frame):
				fired = tr
				break
		if fired == null:
			break
		var old_state: MovementKit.MovementState = st
		# on_exit (old) -> do -> on_enter (new)
		_run_effects(old_state.on_exit, frame, dt)
		_run_effects(fired.do_effects, frame, dt)
		active_state = fired.to_state
		var new_state: MovementKit.MovementState = kit.states[active_state]
		_run_effects(new_state.on_enter, frame, dt)
		if not fired.reenter:
			break
		# reenter: loop, re-evaluating the NEW state's transitions this frame.

	# 4. Run the active state's tick effects in listed order.
	var active: MovementKit.MovementState = kit.states[active_state]
	_run_effects(active.tick, frame, dt)

# ---------------------------------------------------------------------------
# §3 step 1 — input sampling. The ONLY place Input.* is read.
# ---------------------------------------------------------------------------

func _sample_input(dt: float) -> InputFrame:
	var frame := InputFrame.new()

	# Pressed-set for every action the kit's conditions might query. We sample the
	# move actions (for wish-dir) plus every declared input plus sprint/crouch.
	var actions := ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]
	for a in kit.inputs:
		if not actions.has(a):
			actions.append(a)
	for a in actions:
		frame.pressed[a] = InputMap.has_action(a) and Input.is_action_pressed(a)

	# Buffered-edge timers: an action with a `buffer` param arms its timer on the
	# rising edge (pressed now, not held last tick). jump_hold accumulates while held.
	for action in kit.inputs:
		var spec: MovementKit.InputSpec = kit.inputs[action]
		var held_now: bool = frame.is_pressed(action)
		var held_prev: bool = bool(_held_last.get(action, false))
		if spec.buffer_param != "" and held_now and not held_prev:
			timers[action] = kit.params.get(spec.buffer_param, 0.0)
		if spec.track_hold:
			# jump_hold timer: accumulate while held, reset to 0 when released.
			if held_now:
				timers["jump_hold"] = float(timers.get("jump_hold", 0.0)) + dt
			else:
				timers["jump_hold"] = 0.0
		_held_last[action] = held_now

	# Wish direction (yaw-only, sampled once) — mirrors PlayerController._get_wish_dir.
	var input := Vector2.ZERO
	if frame.is_pressed("move_forward"):
		input.y -= 1.0
	if frame.is_pressed("move_backward"):
		input.y += 1.0
	if frame.is_pressed("move_left"):
		input.x -= 1.0
	if frame.is_pressed("move_right"):
		input.x += 1.0
	if input.length_squared() >= 0.001:
		input = input.normalized()
		var basis_y := Basis(Vector3.UP, yaw)
		frame.wish_dir = basis_y * Vector3(input.x, 0.0, input.y)
	return frame

# ---------------------------------------------------------------------------
# Condition evaluation (closed union).
# ---------------------------------------------------------------------------

func _eval_condition(cond: Dictionary, frame: InputFrame) -> bool:
	var op: String = str(cond.get("op", ""))
	match op:
		"on_ground":
			return body.is_on_floor()
		"airborne":
			return not body.is_on_floor()
		"speed_h":
			return _cmp(_speed_h(), str(cond.get("cmp", "")), _resolve_value(cond.get("value"), frame))
		"speed_v":
			return _cmp(body.velocity.y, str(cond.get("cmp", "")), _resolve_value(cond.get("value"), frame))
		"timer":
			var t: float = float(timers.get(str(cond.get("name", "")), 0.0))
			return _cmp(t, str(cond.get("cmp", "")), _resolve_value(cond.get("value"), frame))
		"input_pressed":
			return frame.is_pressed(str(cond.get("action", "")))
		"input_buffered":
			return float(timers.get(str(cond.get("action", "")), 0.0)) > 0.0
		"wish_input":
			# Bare form: any move input. With `aligned_with_velocity`: compare the
			# dot of (normalized) wish-dir and horizontal velocity direction.
			if frame.wish_dir.length_squared() < 0.001:
				return false
			if bool(cond.get("aligned_with_velocity", false)):
				var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
				if horiz.length_squared() < 0.000001:
					return false
				var dot := frame.wish_dir.dot(horiz.normalized())
				return _cmp(dot, str(cond.get("cmp", "gt")), _resolve_value(cond.get("value"), frame))
			return true
		"wall_detected":
			# Probe for a wall; on a hit, track it as the current wall. Mirrors
			# PlayerController._check_wall_run's side probing (right, then left).
			return _probe_walls(str(cond.get("side", "any")))
		"wall_still_near":
			# Re-probe the currently-tracked wall side (PlayerController._is_wall_nearby).
			return _wall_still_near()
		"ledge_vaultable":
			# The vault ray triple resolves to a climbable ledge (PlayerController._check_vault).
			return body.host_check_vault()
		"headroom":
			return body.host_can_stand()
		"slope_angle":
			return _cmp(_slope_angle(), str(cond.get("cmp", "")), _resolve_value(cond.get("value"), frame))
		"below_y":
			return body.global_position.y < _resolve_value(cond.get("value"), frame)
		"all":
			for sub: Variant in cond.get("of", []):
				if not _eval_condition(sub, frame):
					return false
			return true
		"any":
			for sub: Variant in cond.get("of", []):
				if _eval_condition(sub, frame):
					return true
			return false
		"not":
			var of: Array = cond.get("of", [])
			return not _eval_condition(of[0], frame) if of.size() > 0 else true
	push_error("MovementInterpreter: unhandled condition op '%s'" % op)
	return false

func _cmp(lhs: float, op: String, rhs: float) -> bool:
	match op:
		"ge": return lhs >= rhs
		"gt": return lhs > rhs
		"le": return lhs <= rhs
		"lt": return lhs < rhs
		"eq": return is_equal_approx(lhs, rhs)
	return false

# ---------------------------------------------------------------------------
# Effect execution (closed union). Effects mutate body.velocity / position /
# timers / collider / camera, or commit physics. Listed order is honoured.
# ---------------------------------------------------------------------------

func _run_effects(effects: Array, frame: InputFrame, dt: float) -> void:
	for e: Variant in effects:
		_run_effect(e, frame, dt)

func _run_effect(e: Dictionary, frame: InputFrame, dt: float) -> void:
	var op: String = str(e.get("do", ""))
	match op:
		"set_velocity_y":
			body.velocity.y = _resolve_value(e.get("value"), frame)
		"set_velocity_y_max":
			# velocity.y = max(velocity.y, value) — the wall-run vertical boost
			# ("don't reduce upward speed") from PlayerController._check_wall_run.
			body.velocity.y = maxf(body.velocity.y, _resolve_value(e.get("value"), frame))
		"set_timer":
			timers[str(e.get("name", ""))] = _resolve_value(e.get("value"), frame)
		"add_timer":
			# Accumulate/decay a timer by a delta scaled by dt, optionally gated by a
			# condition. Used for slide_steer ("pushing into motion stands you up"):
			#   when the gate holds, advance by +dt; otherwise decay toward 0 by -dt.
			var name := str(e.get("name", ""))
			var cur := float(timers.get(name, 0.0))
			var gate_ok := true
			var gate: Variant = e.get("when", null)
			if typeof(gate) == TYPE_DICTIONARY:
				gate_ok = _eval_condition(gate, frame)
			if gate_ok:
				timers[name] = cur + _resolve_value(e.get("by"), frame) * dt
			else:
				# Decay back to 0 (matches PlayerController's max(0, t - delta)).
				timers[name] = maxf(0.0, cur - _resolve_value(e.get("else_by", e.get("by")), frame) * dt)
		"add_velocity":
			_eff_add_velocity(e, frame)
		"accelerate_toward":
			_eff_accelerate_toward(e, frame, dt)
		"air_strafe":
			_eff_air_strafe(e, frame, dt)
		"apply_friction":
			_eff_apply_friction(e, frame, dt)
		"apply_gravity":
			_eff_apply_gravity(e, frame, dt)
		"carve":
			_eff_carve(e, frame, dt)
		"slope_accelerate":
			_eff_slope_accelerate(e, frame, dt)
		"clamp_speed_h":
			_eff_clamp_speed_h(e, frame)
		"set_collider_height":
			body.host_set_collider_height(_resolve_value(e.get("value"), frame), bool(e.get("require_headroom", false)))
		"lerp_camera_height":
			body.host_lerp_camera_height(_resolve_value(e.get("target"), frame), _resolve_value(e.get("rate"), frame), dt)
		"lerp_fov":
			body.host_lerp_fov(_resolve_value(e.get("target"), frame), _resolve_value(e.get("rate"), frame), dt)
		"lerp_camera_roll":
			body.host_lerp_camera_roll(_resolve_value(e.get("target"), frame), _resolve_value(e.get("rate"), frame), dt)
		"tween_position":
			_eff_tween_position(e, frame)
		"respawn":
			body.host_respawn()
		"move_and_slide":
			body.move_and_slide()
		_:
			push_error("MovementInterpreter: unhandled effect op '%s'" % op)

func _eff_add_velocity(e: Dictionary, frame: InputFrame) -> void:
	# Add a magnitude along a named space to velocity. For the slide entry boost,
	# `guard_not_in` names a state from which the boost must NOT re-apply (so it
	# never compounds while already sliding), and the add is along the *current
	# horizontal velocity direction* (space "velocity"), clamped via a later
	# clamp_speed_h effect. Mirrors PlayerController._begin_slide.
	var guard_state := str(e.get("guard_not_in", ""))
	if guard_state != "" and active_state == guard_state:
		return
	var mag := _resolve_value(e.get("vector"), frame)
	var space := str(e.get("space", "world"))
	if space == "velocity":
		var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if horiz.length_squared() < 0.001:
			return
		var dir := horiz.normalized()
		body.velocity.x += dir.x * mag
		body.velocity.z += dir.z * mag
		return
	var v := _resolve_space(space, frame) * mag
	# include_y: also apply the vertical component of the (3D) space vector. Default
	# false → horizontal-only, exactly as before (every existing add_velocity is
	# 2D and unaffected). The `aim`/look space is 3D, so bullet jump launches along
	# the full look vector (up/down/level) by setting include_y on its aim impulse.
	var include_y := bool(e.get("include_y", false))
	if bool(e.get("replace", false)):
		# Replace horizontal velocity with space*mag (wall-jump lateral: the
		# imperative controller sets velocity outright, it does not add). y is set
		# separately via set_velocity_y (unless include_y is set).
		body.velocity.x = v.x
		body.velocity.z = v.z
		if include_y:
			body.velocity.y = v.y
	else:
		body.velocity.x += v.x
		body.velocity.z += v.z
		if include_y:
			body.velocity.y += v.y

func _eff_accelerate_toward(e: Dictionary, frame: InputFrame, dt: float) -> void:
	# Two modes:
	#  - space "wish": when there is wish input, move horizontal velocity toward
	#    wish_dir * top_speed at `rate`; no input → no-op (friction is separate).
	#  - space "wall_tangent": run along the wall. Longitudinal input sign sets the
	#    target speed along the tangent (forward → +speed, backward → 0, none →
	#    current). Lateral input is ignored. Mirrors PlayerController._process_wall_run.
	var space := str(e.get("space", "wish"))
	if space == "wall_tangent":
		_accelerate_along_wall(e, frame, dt)
		return
	if frame.wish_dir.length_squared() < 0.001:
		return
	var top_speed := _resolve_value(e.get("speed"), frame)
	var rate := _resolve_value(e.get("rate"), frame)
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var target := _resolve_space(space, frame) * top_speed
	horiz = horiz.move_toward(target, rate * dt)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _accelerate_along_wall(e: Dictionary, frame: InputFrame, dt: float) -> void:
	var tangent := _resolve_space("wall_tangent", frame)
	if tangent.length_squared() < 0.001:
		return
	var run_speed := _resolve_value(e.get("speed"), frame)
	var rate := _resolve_value(e.get("rate"), frame)
	# Longitudinal input along the wall: +forward, -backward; lateral ignored.
	var fwd_input := 0.0
	if frame.is_pressed("move_forward"):
		fwd_input += 1.0
	if frame.is_pressed("move_backward"):
		fwd_input -= 1.0
	var current_along := Vector3(body.velocity.x, 0.0, body.velocity.z).dot(tangent)
	var target_along: float
	if fwd_input > 0.0:
		target_along = run_speed
	elif fwd_input < 0.0:
		target_along = 0.0          # backward decelerates; never pushes forward
	else:
		target_along = current_along  # no input → preserve momentum
	var new_along := move_toward(current_along, target_along, rate * dt)
	body.velocity.x = tangent.x * new_along
	body.velocity.z = tangent.z * new_along

func _eff_air_strafe(e: Dictionary, frame: InputFrame, dt: float) -> void:
	# Additive air-strafe: add toward wish-dir up to `cap`, never decelerating.
	# Mirrors PlayerController._process_air strafe exactly.
	if frame.wish_dir.length_squared() < 0.001:
		return
	var cap := _resolve_value(e.get("cap"), frame)
	var rate := _resolve_value(e.get("rate"), frame)
	var wish := _resolve_space(str(e.get("space", "wish")), frame)
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var current_in_wish := horiz.dot(wish)
	var add_speed := minf(cap - current_in_wish, rate * dt)
	if add_speed > 0.0:
		horiz += wish * add_speed
		body.velocity.x = horiz.x
		body.velocity.z = horiz.z

func _eff_apply_friction(e: Dictionary, frame: InputFrame, dt: float) -> void:
	# only_when_no_wish: skip if there is wish input (accelerate_toward owns that case).
	if bool(e.get("only_when_no_wish", false)) and frame.wish_dir.length_squared() >= 0.001:
		return
	var rate := _resolve_value(e.get("rate"), frame)
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	horiz = horiz.move_toward(Vector3.ZERO, rate * dt)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _eff_apply_gravity(e: Dictionary, frame: InputFrame, dt: float) -> void:
	var scale := _resolve_value(e.get("scale"), frame)
	body.velocity.y -= gravity * scale * dt
	# Optional fall-speed clamp on the wall (PlayerController: velocity.y = max(vy, -g)).
	if e.has("min_vy"):
		body.velocity.y = maxf(body.velocity.y, _resolve_value(e.get("min_vy"), frame))

func _eff_carve(e: Dictionary, frame: InputFrame, dt: float) -> void:
	# Steer the horizontal velocity DIRECTION toward wish-dir at `rate` without
	# changing magnitude (the slide carve). Mirrors PlayerController._process_slide's
	# steer block: steered = horiz + wish*rate*dt; renormalize to speed_now.
	if frame.wish_dir.length_squared() < 0.001:
		return
	var rate := _resolve_value(e.get("rate"), frame)
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed_now := horiz.length()
	var steered := horiz + frame.wish_dir * rate * dt
	if steered.length() > 0.001:
		steered = steered.normalized() * speed_now
		body.velocity.x = steered.x
		body.velocity.z = steered.z

func _eff_slope_accelerate(e: Dictionary, frame: InputFrame, dt: float) -> void:
	# Downhill push proportional to slope angle (PlayerController._process_slide).
	# Only when on a non-trivial slope (> 2°). Direction = horizontal floor normal.
	if not body.is_on_floor():
		return
	var floor_normal := body.get_floor_normal()
	var ang := rad_to_deg(acos(clampf(floor_normal.dot(Vector3.UP), -1.0, 1.0)))
	if ang <= 2.0:
		return
	var rate := _resolve_value(e.get("rate"), frame)
	var ref_angle := _resolve_value(e.get("ref_angle"), frame)
	if ref_angle <= 0.0:
		ref_angle = 45.0
	var down_slope := Vector3(floor_normal.x, 0.0, floor_normal.z).normalized()
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	horiz += down_slope * rate * (ang / ref_angle) * dt
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _eff_clamp_speed_h(e: Dictionary, frame: InputFrame) -> void:
	var max_speed := _resolve_value(e.get("max"), frame)
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z).limit_length(max_speed)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _eff_tween_position(e: Dictionary, frame: InputFrame) -> void:
	# Scripted move (vault/mantle): lerp global_position from a captured start to a
	# captured end over the named timer. The host captures start/end on vault entry
	# (the ledge geometry is a world query); the interpreter drives the lerp here so
	# the motion is data-ordered. When the timer hits 0, snap to end and zero velocity.
	var timer_name := str(e.get("duration_timer", "vault"))
	var remaining := float(timers.get(timer_name, 0.0))
	var duration := _resolve_value(e.get("duration"), frame)
	body.host_tween_position(remaining, duration)

# ---------------------------------------------------------------------------
# Wall probing (irreducible world queries delegated to the host). The interpreter
# owns the *decision* (which side, what counts as a wall); the host owns the ray.
# ---------------------------------------------------------------------------

func _probe_walls(side: String) -> bool:
	# Mirror PlayerController._check_wall_run: try right then left (order matters),
	# accept a roughly-vertical wall. On a hit, record wall_normal + wall_side.
	var sides: Array = []
	match side:
		"right": sides = [1.0]
		"left": sides = [-1.0]
		_: sides = [1.0, -1.0]   # "any": right first, then left (matches prototype)
	for s: float in sides:
		var dist := float(kit.params.get("wall_detect_distance", 0.65))
		var hit: Dictionary = body.host_wall_ray(s, dist)
		if not hit.is_empty():
			var normal: Vector3 = hit["normal"]
			if absf(normal.y) < 0.3:
				wall_normal = normal
				wall_side = s
				return true
	return false

func _wall_still_near() -> bool:
	var dist := float(kit.params.get("wall_detect_distance", 0.65)) + 0.15
	var hit: Dictionary = body.host_wall_ray(wall_side, dist)
	if not hit.is_empty():
		var normal: Vector3 = hit["normal"]
		wall_normal = normal
		return absf(normal.y) < 0.3
	return false

# ---------------------------------------------------------------------------
# Value & space resolution. Numbers, param names, and the structured resolvers:
# `select` (sprint / floaty branch) and `curve` (const | ramp | lerp).
# ---------------------------------------------------------------------------

func _resolve_value(v: Variant, frame: InputFrame) -> float:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return float(v)
		TYPE_STRING:
			return float(kit.params.get(v, 0.0))
		TYPE_DICTIONARY:
			return _resolve_structured(v, frame)
	return 0.0

## Structured value resolvers. `select` chooses between two values based on tick
## state; `curve` evaluates a serializable curve over a named timer. This keeps
## conditional tuning as DATA without a per-verb code branch.
func _resolve_structured(d: Dictionary, frame: InputFrame) -> float:
	if d.has("curve"):
		return _resolve_curve(d, frame)
	var kind: String = str(d.get("select", ""))
	match kind:
		"sprint":
			var held: bool = frame.is_pressed(str(d.get("if_held", "sprint")))
			return _resolve_value(d.get("then" if held else "else"), frame)
		"jump_floaty":
			# floaty when: jump held AND jump_hold < jump_hold_max_time AND rising (vy>0)
			var action: String = str(d.get("if_held", "jump"))
			var held: bool = frame.is_pressed(action)
			var gate: Dictionary = d.get("and_timer_lt", {})
			var timer_ok := true
			if not gate.is_empty():
				timer_ok = float(timers.get(str(gate.get("name", "")), 0.0)) < _resolve_value(gate.get("value"), frame)
			var rising_ok := true
			if bool(d.get("and_rising", false)):
				rising_ok = body.velocity.y > 0.0
			var floaty := held and timer_ok and rising_ok
			return _resolve_value(d.get("then" if floaty else "else"), frame)
	push_error("MovementInterpreter: unknown structured value 'select=%s'" % kind)
	return 0.0

## Curve resolvers (closed set: const | ramp | lerp). `ramp` reproduces the
## wall-run gravity ramp: a value that grows from `from` to `to` as a named
## COUNTDOWN timer drains from its max, with a `power` easing exponent.
##   time_fraction = 1 - timer/max ; value = from + (to-from) * fraction^power
func _resolve_curve(d: Dictionary, frame: InputFrame) -> float:
	var kind: String = str(d.get("curve", "const"))
	match kind:
		"const":
			return _resolve_value(d.get("value"), frame)
		"ramp":
			var t := float(timers.get(str(d.get("over_timer", "")), 0.0))
			var tmax := _resolve_value(d.get("max"), frame)
			if tmax <= 0.0:
				tmax = 1.0
			var fraction := clampf(1.0 - t / tmax, 0.0, 1.0)
			var from := _resolve_value(d.get("from"), frame)
			var to := _resolve_value(d.get("to"), frame)
			var power := _resolve_value(d.get("power"), frame)
			if power <= 0.0:
				power = 1.0
			return from + (to - from) * pow(fraction, power)
		"lerp":
			# Linear interpolation from `from` to `to` as a named countdown timer
			# drains from `max` (fraction = 1 - timer/max).
			var t2 := float(timers.get(str(d.get("over_timer", "")), 0.0))
			var tmax2 := _resolve_value(d.get("max"), frame)
			if tmax2 <= 0.0:
				tmax2 = 1.0
			var f := clampf(1.0 - t2 / tmax2, 0.0, 1.0)
			return lerpf(_resolve_value(d.get("from"), frame), _resolve_value(d.get("to"), frame), f)
	push_error("MovementInterpreter: unknown curve '%s'" % kind)
	return 0.0

## Resolve a named direction space to a unit-ish vector for this tick.
## `wish` / `forward` (Slice 1) + `wall_tangent` / `wall_normal` (Slice 2).
func _resolve_space(space: String, frame: InputFrame) -> Vector3:
	match space:
		"wish":
			return frame.wish_dir
		"forward":
			return -body.transform.basis.z
		"aim":
			# Full 3D look/aim direction: yaw + pitch (the camera forward), normalized.
			# `forward` is yaw-only (the body never pitches); `aim` includes the
			# camera-pivot pitch fed by the host. Looking up → +Y, down → -Y, level →
			# horizontal. This is the Warframe bullet-jump launch axis. Computed from
			# the sampled yaw/pitch so it is deterministic (no node read at resolve time).
			var aim := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
			return aim.normalized()
		"wall_tangent":
			# Along the wall = wall_normal × UP, oriented toward where the camera
			# (yaw) mostly faces (PlayerController._process_wall_run).
			if wall_normal.length_squared() < 0.001:
				return Vector3.ZERO
			var along := wall_normal.cross(Vector3.UP).normalized()
			if along.dot(-body.transform.basis.z) < 0.0:
				along = -along
			return along
		"wall_normal":
			return wall_normal
	push_error("MovementInterpreter: unknown space '%s'" % space)
	return Vector3.ZERO

func _speed_h() -> float:
	return Vector3(body.velocity.x, 0.0, body.velocity.z).length()

func _slope_angle() -> float:
	if not body.is_on_floor():
		return 0.0
	var n := body.get_floor_normal()
	return rad_to_deg(acos(clampf(n.dot(Vector3.UP), -1.0, 1.0)))
