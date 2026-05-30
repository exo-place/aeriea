## MovementInterpreter — the deterministic fixed-tick stepper that runs a
## MovementKit as the reference semantics (docs/decisions/movement-substrate.md
## §3, §4a). SLICE 1: ground move + jump (coyote + buffer).
##
## Determinism crux (Slice 1's key refactor): input is sampled ONCE per tick into
## an immutable InputFrame at the top of step(). No Condition or Effect reads
## Input.* — they read the frame. This removes the prototype's mid-physics
## Input.is_action_pressed reads.
##
## The interpreter mutates an explicit MovementRecord (velocity, position, timers,
## active state). It drives a CharacterBody3D (the `body`) for the actual physics
## (move_and_slide / is_on_floor) — the body IS the simulation surface; the record
## mirrors the trajectory-relevant fields. Camera/FOV/roll are render-only and not
## part of this slice.
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
var timers: Dictionary = {}     # name -> float (>= 0)
var gravity: float = 9.8

## Held-input edge state for buffered/hold actions. Updated in _sample_input from
## edges since last tick. Buffer timers live in `timers` keyed by action name.
var _held_last: Dictionary = {}   # action -> bool (held at end of previous tick)

## Source of yaw for wish-dir (radians). The body's rotation.y by default; the
## host can override for tests. Mouse-look stays separate (yaw only, sampled once).
var yaw: float = 0.0

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
	for t in ["coyote", "jump_buffer", "jump_hold"]:
		timers[t] = 0.0
	for action in kit.inputs:
		_held_last[action] = false

# ---------------------------------------------------------------------------
# The tick (one _physics_process). §3 execution model.
# ---------------------------------------------------------------------------

func step(dt: float) -> void:
	# 1. Sample inputs once into an immutable frame.
	var frame := _sample_input(dt)

	# 2. Pre-tick: decrement all named timers by dt, in one place.
	for name in timers:
		var v: float = timers[name]
		# jump_hold is an accumulating timer while held; handled in _sample_input.
		if name == "jump_hold":
			continue
		timers[name] = maxf(0.0, v - dt)

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
# Condition evaluation (closed union, Slice 1 subset).
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
		"timer":
			var t: float = float(timers.get(str(cond.get("name", "")), 0.0))
			return _cmp(t, str(cond.get("cmp", "")), _resolve_value(cond.get("value"), frame))
		"input_pressed":
			return frame.is_pressed(str(cond.get("action", "")))
		"input_buffered":
			return float(timers.get(str(cond.get("action", "")), 0.0)) > 0.0
		"wish_input":
			return frame.wish_dir.length_squared() >= 0.001
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
# Effect execution (closed union, Slice 1 subset). Effects mutate body.velocity /
# timers / commit physics. Listed order is honoured.
# ---------------------------------------------------------------------------

func _run_effects(effects: Array, frame: InputFrame, dt: float) -> void:
	for e: Variant in effects:
		_run_effect(e, frame, dt)

func _run_effect(e: Dictionary, frame: InputFrame, dt: float) -> void:
	var op: String = str(e.get("do", ""))
	match op:
		"set_velocity_y":
			body.velocity.y = _resolve_value(e.get("value"), frame)
		"set_timer":
			timers[str(e.get("name", ""))] = _resolve_value(e.get("value"), frame)
		"accelerate_toward":
			_eff_accelerate_toward(e, frame, dt)
		"air_strafe":
			_eff_air_strafe(e, frame, dt)
		"apply_friction":
			_eff_apply_friction(e, frame, dt)
		"apply_gravity":
			_eff_apply_gravity(e, frame, dt)
		"move_and_slide":
			body.move_and_slide()
		_:
			push_error("MovementInterpreter: unhandled effect op '%s'" % op)

func _eff_accelerate_toward(e: Dictionary, frame: InputFrame, dt: float) -> void:
	# When there is wish input, accelerate horizontal velocity toward
	# wish_dir * top_speed at `rate`. When no input, do nothing here (friction is
	# a separate listed effect, mirroring the prototype's if/else).
	if frame.wish_dir.length_squared() < 0.001:
		return
	var top_speed := _resolve_value(e.get("speed"), frame)
	var rate := _resolve_value(e.get("rate"), frame)
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var target := _resolve_space(str(e.get("space", "wish")), frame) * top_speed
	horiz = horiz.move_toward(target, rate * dt)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

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

# ---------------------------------------------------------------------------
# Value & space resolution. Numbers, param names, and the two structured
# resolvers this slice needs (`select` for sprint/floaty). Curves are Slice 2.
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

## Structured value resolvers. `select` chooses between two param values based on
## tick state (sprint held, or the floaty-gravity gate). This keeps the
## conditional tuning as DATA without a per-verb code branch; it slots beside the
## `curve` resolver coming in Slice 2.
func _resolve_structured(d: Dictionary, frame: InputFrame) -> float:
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

## Resolve a named direction space to a unit-ish vector for this tick.
## Slice 1: `wish` and `forward`. (wall_tangent / wall_normal are Slice 2.)
func _resolve_space(space: String, frame: InputFrame) -> Vector3:
	match space:
		"wish":
			return frame.wish_dir
		"forward":
			return -body.transform.basis.z
	push_error("MovementInterpreter: unknown space '%s'" % space)
	return Vector3.ZERO

func _speed_h() -> float:
	return Vector3(body.velocity.x, 0.0, body.velocity.z).length()
