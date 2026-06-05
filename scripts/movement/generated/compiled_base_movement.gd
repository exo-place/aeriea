## GENERATED from res://movement/default.manifest.json — do not edit by hand.
## Regenerate with:
##   nix develop --command bash -lc 'xvfb-run -a godot4 --path . res://tools/regen_compiled_movement.tscn --quit-after 120'
##
## This is the COMPILED projection of the movement kit (see
## docs/decisions/movement-substrate.md §4b and scripts/movement/movement_compiler.gd).
## It is a faithful lowering of MovementInterpreter's reference semantics to
## direct branching code: transitions are inlined if/elif chains in priority
## order, conditions are inline boolean expressions, effects are straight-line
## kernel calls. The golden-trace harness asserts interpreter == compiled.
class_name CompiledBaseMovement
extends RefCounted

# Mirrors MovementInterpreter's public surface so the same host (InterpretedPlayer)
# can drive either path and the same tests exercise both.
class InputFrame:
	extends RefCounted
	var pressed: Dictionary = {}
	var wish_dir: Vector3 = Vector3.ZERO
	func is_pressed(action: String) -> bool:
		return bool(pressed.get(action, false))

var kit: MovementKit
var body: CharacterBody3D
var active_state: String = ""
var timers: Dictionary = {}
var gravity: float = 9.8
var wall_normal: Vector3 = Vector3.ZERO
var wall_side: float = 0.0
var _held_last: Dictionary = {}
var yaw: float = 0.0
var pitch: float = 0.0
var toggle_actions: Dictionary = {}

class ToggleHold:
	extends RefCounted
	var mode: int = 0
	var _latched: bool = false
	var _held_prev: bool = false
	func resolve(held_now: bool) -> bool:
		var active: bool
		if mode == 1:
			if held_now and not _held_prev:
				_latched = not _latched
			active = _latched
		else:
			active = held_now
		_held_prev = held_now
		return active
	func reset() -> void:
		_latched = false
		_held_prev = false

# --- Params lowered to consts (referenced by name in the kit) ---
const P_air_steer_rate := 14.0
const P_bullet_jump_base_up := 6.0
const P_bullet_jump_buffer_time := 0.15
const P_bullet_jump_cooldown := 0.6
const P_bullet_jump_impulse := 13.0
const P_camera_height_crouch := 0.55
const P_camera_height_lerp_speed := 12.0
const P_camera_height_stand := 0.85
const P_camera_roll_lerp_speed := 10.0
const P_camera_roll_level := 0.0
const P_comment_thresholds := 0.0
const P_coyote_time := 0.12
const P_crouch_height := 0.6
const P_crouch_walk_speed := 2.8
const P_glide_fall_cap := -2.5
const P_glide_gravity_scale := 0.18
const P_glide_max_time := 2.5
const P_glide_strafe_accel := 22.0
const P_glide_strafe_cap := 9.0
const P_gravity_scale := 2.2
const P_ground_acceleration := 60.0
const P_ground_friction := 30.0
const P_ground_snap_bias := -0.5
const P_jump_buffer_time := 0.15
const P_jump_hold_gravity_scale := 1.2
const P_jump_hold_max_time := 0.25
const P_jump_velocity := 9.5
const P_kill_y := -25.0
const P_max_slide_speed := 22.0
const P_slide_boost := 3.0
const P_slide_entry_speed := 8.0
const P_slide_exit_speed := 3.0
const P_slide_friction := 4.0
const P_slide_max_time := 1.8
const P_slide_steer_accel := 16.0
const P_slide_steer_exit_time := 0.18
const P_slope_acceleration := 18.0
const P_slope_min_angle := 2.0
const P_sprint_speed := 10.0
const P_stand_height := 0.9
const P_vault_duration := 0.28
const P_vault_min_speed := 2.5
const P_walk_speed := 5.5
const P_wall_cling_gravity_scale := 0.0
const P_wall_cling_max_time := 1.2
const P_wall_cling_min_vy := -0.5
const P_wall_detect_distance := 0.65
const P_wall_jump_grace := 0.12
const P_wall_jump_lateral := 6.5
const P_wall_jump_up := 8.0
const P_wall_max_normal_y := 0.3
const P_wall_run_camera_tilt := 8.0
const P_wall_run_gravity_ramp := 1.8
const P_wall_run_gravity_scale := 0.15
const P_wall_run_max_time := 1.4
const P_wall_run_min_speed := 5.0
const P_wall_run_speed := 9.0
const P_wall_run_speed_rate := 54.0
const P_wall_run_vertical_boost := 1.5

func setup(p_kit: MovementKit, p_body: CharacterBody3D) -> void:
	kit = p_kit
	body = p_body
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	active_state = "AIR"
	timers = {}
	for action in kit.inputs:
		timers[action] = 0.0
	for vn in kit.vars:
		timers[vn] = 0.0
	for action in kit.inputs:
		_held_last[action] = false

func reset_state() -> void:
	active_state = "AIR"
	wall_normal = Vector3.ZERO
	wall_side = 0.0
	for k in timers:
		timers[k] = 0.0

func step(dt: float) -> void:
	var frame := _sample_input(dt)

	# Pre-tick transitions (e.g. below_y → respawn). A firing pre_tick aborts the tick.
	if (body.global_position.y < P_kill_y):
		body.host_respawn()
		active_state = "AIR"
		return

	# Decrement DECAYING numeric vars (decay:false counters excluded), §B.
	for tname in timers:
		if _is_decaying(tname):
			timers[tname] = maxf(0.0, float(timers[tname]) - dt)

	# Transition evaluation with bounded reenter loop, then tick.
	var guard := 0
	while guard < 8:
		guard += 1
		if not _eval_transitions(frame, dt):
			break
	_run_tick(frame, dt)

func _sample_input(dt: float) -> InputFrame:
	var frame := InputFrame.new()
	var actions := ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]
	for a in kit.inputs:
		if not actions.has(a):
			actions.append(a)
	for a in actions:
		frame.pressed[a] = InputMap.has_action(a) and Input.is_action_pressed(a)
	for a in toggle_actions:
		var th: ToggleHold = toggle_actions[a]
		frame.pressed[a] = th.resolve(bool(frame.pressed.get(a, false)))
	for action in kit.inputs:
		var spec: MovementKit.InputSpec = kit.inputs[action]
		var held_now: bool = frame.is_pressed(action)
		var held_prev: bool = bool(_held_last.get(action, false))
		if spec.buffer_param != "" and held_now and not held_prev:
			timers[action] = kit.params.get(spec.buffer_param, 0.0)
		if spec.track_hold:
			if held_now:
				timers["jump_hold"] = float(timers.get("jump_hold", 0.0)) + dt
			else:
				timers["jump_hold"] = 0.0
		_held_last[action] = held_now
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

func _eval_transitions(frame: InputFrame, dt: float) -> bool:
	if active_state == "GROUND":
		if (float(timers.get("jump", 0.0)) > 0.0):
			body.velocity.y = P_jump_velocity
			timers["jump_buffer"] = 0.0
			timers["jump_hold"] = 0.0
			active_state = "AIR"
			return false
		elif ((_speed_h() > P_vault_min_speed) and body.host_check_vault()):
			timers["vault"] = P_vault_duration
			active_state = "VAULT"
			return false
		elif (frame.is_pressed("crouch") and (_speed_h() >= P_slide_entry_speed)):
			_k_add_velocity(frame, P_slide_boost, "velocity", false, false)
			_k_clamp_speed_h(P_max_slide_speed)
			body.host_set_collider_height(P_crouch_height, false)
			timers["slide"] = P_slide_max_time
			timers["slide_steer"] = 0.0
			active_state = "SLIDE"
			return false
		elif frame.is_pressed("crouch"):
			body.host_set_collider_height(P_crouch_height, false)
			active_state = "CROUCH"
			return false
		elif (not body.is_on_floor()):
			timers["coyote"] = P_coyote_time
			active_state = "AIR"
			return true
		return false
	elif active_state == "AIR":
		if ((float(timers.get("jump", 0.0)) > 0.0) and (float(timers.get("coyote", 0.0)) > 0.0)):
			body.velocity.y = P_jump_velocity
			timers["coyote"] = 0.0
			timers["jump_buffer"] = 0.0
			timers["jump_hold"] = 0.0
			active_state = "AIR"
			return true
		elif ((float(timers.get("jump", 0.0)) > 0.0) and (float(timers.get("wall_jump_grace", 0.0)) > 0.0)):
			_k_add_velocity(frame, P_wall_jump_lateral, "wall_normal", true, false)
			body.velocity.y = P_wall_jump_up
			timers["wall_jump_grace"] = 0.0
			timers["jump_buffer"] = 0.0
			active_state = "AIR"
			return true
		elif ((not body.is_on_floor()) and frame.is_pressed("cling") and _probe_walls("any")):
			body.velocity.y = 0.0
			_k_clamp_speed_h(0.0)
			timers["wall_cling"] = P_wall_cling_max_time
			active_state = "WALL_CLING"
			return false
		elif ((_speed_h() >= P_wall_run_min_speed) and (not body.is_on_floor()) and _probe_walls("any") and (frame.wish_dir.length_squared() >= 0.001)):
			body.velocity.y = maxf(body.velocity.y, P_wall_run_vertical_boost)
			timers["wall_run"] = P_wall_run_max_time
			active_state = "WALL_RUN"
			return false
		elif ((_speed_h() > P_vault_min_speed) and body.host_check_vault()):
			timers["vault"] = P_vault_duration
			active_state = "VAULT"
			return false
		elif ((not body.is_on_floor()) and frame.is_pressed("aim") and (body.velocity.y < 0.0)):
			timers["glide"] = P_glide_max_time
			active_state = "GLIDE"
			return false
		elif (body.is_on_floor() and (body.velocity.y <= 0.0) and frame.is_pressed("crouch") and (_speed_h() >= P_slide_entry_speed)):
			_k_add_velocity(frame, P_slide_boost, "velocity", false, false)
			_k_clamp_speed_h(P_max_slide_speed)
			body.host_set_collider_height(P_crouch_height, false)
			timers["slide"] = P_slide_max_time
			timers["slide_steer"] = 0.0
			active_state = "SLIDE"
			return false
		elif (body.is_on_floor() and (body.velocity.y <= 0.0)):
			body.velocity.x = 0.0
			body.velocity.z = 0.0
			active_state = "GROUND"
			return true
		return false
	elif active_state == "SLIDE":
		if ((float(timers.get("jump", 0.0)) > 0.0) and (float(timers.get("bullet_jump_cd", 0.0)) <= 0.0)):
			body.host_set_collider_height(P_stand_height, true)
			body.velocity.y = P_bullet_jump_base_up
			_k_add_velocity(frame, P_bullet_jump_impulse, "aim", false, true)
			timers["bullet_jump_cd"] = P_bullet_jump_cooldown
			timers["jump_buffer"] = 0.0
			timers["jump_hold"] = 0.0
			timers["slide_steer"] = 0.0
			active_state = "AIR"
			return false
		elif (not body.is_on_floor()):
			timers["coyote"] = P_coyote_time
			active_state = "AIR"
			return true
		elif (frame.is_pressed("crouch") and ((_speed_h() < P_slide_exit_speed) or (float(timers.get("slide", 0.0)) <= 0.0) or (float(timers.get("slide_steer", 0.0)) >= P_slide_steer_exit_time))):
			timers["slide_steer"] = 0.0
			active_state = "CROUCH"
			return false
		elif ((not frame.is_pressed("crouch")) or (_speed_h() < P_slide_exit_speed) or (float(timers.get("slide", 0.0)) <= 0.0) or (float(timers.get("slide_steer", 0.0)) >= P_slide_steer_exit_time)):
			body.host_set_collider_height(P_stand_height, true)
			timers["slide_steer"] = 0.0
			active_state = "GROUND"
			return false
		return false
	elif active_state == "CROUCH":
		if ((float(timers.get("jump", 0.0)) > 0.0) and (float(timers.get("bullet_jump_cd", 0.0)) <= 0.0)):
			body.host_set_collider_height(P_stand_height, true)
			body.velocity.y = P_bullet_jump_base_up
			_k_add_velocity(frame, P_bullet_jump_impulse, "aim", false, true)
			timers["bullet_jump_cd"] = P_bullet_jump_cooldown
			timers["jump_buffer"] = 0.0
			timers["jump_hold"] = 0.0
			active_state = "AIR"
			return false
		elif (not body.is_on_floor()):
			timers["coyote"] = P_coyote_time
			active_state = "AIR"
			return true
		elif (_speed_h() >= P_slide_entry_speed):
			timers["slide"] = P_slide_max_time
			timers["slide_steer"] = 0.0
			active_state = "SLIDE"
			return false
		elif (not frame.is_pressed("crouch")):
			body.host_set_collider_height(P_stand_height, true)
			active_state = "GROUND"
			return true
		return false
	elif active_state == "WALL_RUN":
		if (float(timers.get("jump", 0.0)) > 0.0):
			_k_add_velocity(frame, P_wall_jump_lateral, "wall_normal", true, false)
			body.velocity.y = P_wall_jump_up
			timers["wall_jump_grace"] = 0.0
			timers["jump_buffer"] = 0.0
			active_state = "AIR"
			return false
		elif (not _wall_still_near()):
			timers["wall_jump_grace"] = P_wall_jump_grace
			active_state = "AIR"
			return false
		elif (float(timers.get("wall_run", 0.0)) <= 0.0):
			timers["wall_jump_grace"] = P_wall_jump_grace
			active_state = "AIR"
			return false
		elif (not (frame.wish_dir.length_squared() >= 0.001)):
			timers["wall_jump_grace"] = P_wall_jump_grace
			active_state = "AIR"
			return false
		elif body.is_on_floor():
			active_state = "GROUND"
			return false
		return false
	elif active_state == "VAULT":
		if (float(timers.get("vault", 0.0)) <= 0.0):
			active_state = "GROUND"
			return false
		return false
	elif active_state == "GLIDE":
		if ((float(timers.get("jump", 0.0)) > 0.0) and (float(timers.get("coyote", 0.0)) > 0.0)):
			body.velocity.y = P_jump_velocity
			timers["coyote"] = 0.0
			timers["jump_buffer"] = 0.0
			active_state = "AIR"
			return true
		elif (not frame.is_pressed("aim")):
			active_state = "AIR"
			return true
		elif (float(timers.get("glide", 0.0)) <= 0.0):
			active_state = "AIR"
			return false
		elif (body.is_on_floor() and (body.velocity.y <= 0.0)):
			active_state = "GROUND"
			return true
		return false
	elif active_state == "WALL_CLING":
		if (float(timers.get("jump", 0.0)) > 0.0):
			timers["wall_jump_grace"] = P_wall_jump_grace
			active_state = "AIR"
			return true
		elif (not frame.is_pressed("cling")):
			timers["coyote"] = P_coyote_time
			active_state = "AIR"
			return true
		elif (not _wall_still_near()):
			active_state = "AIR"
			return false
		elif (float(timers.get("wall_cling", 0.0)) <= 0.0):
			active_state = "AIR"
			return false
		elif body.is_on_floor():
			active_state = "GROUND"
			return false
		return false
	return false

func _run_tick(frame: InputFrame, dt: float) -> void:
	if active_state == "GROUND":
		_k_accelerate_toward(frame, dt, "wish", (P_sprint_speed if frame.is_pressed("sprint") else P_walk_speed), P_ground_acceleration)
		if (not (frame.wish_dir.length_squared() >= 0.001)):
			_k_apply_friction(frame, dt, P_ground_friction)
		body.velocity.y = P_ground_snap_bias
		body.move_and_slide()
		body.host_lerp_camera_height(P_camera_height_stand, P_camera_height_lerp_speed, dt)
		body.host_lerp_camera_roll(P_camera_roll_level, P_camera_roll_lerp_speed, dt)
	elif active_state == "AIR":
		_k_apply_gravity(dt, (P_jump_hold_gravity_scale if (frame.is_pressed("jump") and (float(timers.get("jump_hold", 0.0)) < P_jump_hold_max_time) and (body.velocity.y > 0.0)) else P_gravity_scale), false, INF)
		_k_carve(frame, dt, P_air_steer_rate)
		body.move_and_slide()
		body.host_lerp_camera_height(P_camera_height_stand, P_camera_height_lerp_speed, dt)
		body.host_lerp_camera_roll(P_camera_roll_level, P_camera_roll_lerp_speed, dt)
	elif active_state == "SLIDE":
		_k_slope_accelerate(dt, P_slope_acceleration, 45.0)
		_k_clamp_speed_h(P_max_slide_speed)
		_k_carve(frame, dt, P_slide_steer_accel)
		_k_apply_friction(frame, dt, P_slide_friction)
		if ((frame.wish_dir.length_squared() >= 0.001) and (_speed_h() > 0.001) and _wish_aligned(frame, "gt", 0.5)):
			timers["slide_steer"] = float(timers.get("slide_steer", 0.0)) + ((1.0) * dt)
		if (not ((frame.wish_dir.length_squared() >= 0.001) and (_speed_h() > 0.001) and _wish_aligned(frame, "gt", 0.5))):
			timers["slide_steer"] = maxf(0.0, float(timers.get("slide_steer", 0.0)) + ((-1.0) * dt))
		body.velocity.y = P_ground_snap_bias
		body.move_and_slide()
		body.host_lerp_camera_height(P_camera_height_crouch, P_camera_height_lerp_speed, dt)
		body.host_lerp_camera_roll(P_camera_roll_level, P_camera_roll_lerp_speed, dt)
	elif active_state == "CROUCH":
		_k_accelerate_toward(frame, dt, "wish", P_crouch_walk_speed, P_ground_acceleration)
		if (not (frame.wish_dir.length_squared() >= 0.001)):
			_k_apply_friction(frame, dt, P_ground_friction)
		body.velocity.y = P_ground_snap_bias
		body.move_and_slide()
		body.host_lerp_camera_height(P_camera_height_crouch, P_camera_height_lerp_speed, dt)
		body.host_lerp_camera_roll(P_camera_roll_level, P_camera_roll_lerp_speed, dt)
	elif active_state == "WALL_RUN":
		_k_apply_gravity(dt, _curve_ramp("wall_run", P_wall_run_max_time, P_wall_run_gravity_scale, 1.0, P_wall_run_gravity_ramp), true, -9.8)
		_k_accelerate_toward(frame, dt, "wall_tangent", P_wall_run_speed, P_wall_run_speed_rate)
		body.move_and_slide()
		body.host_lerp_camera_roll(signf(_read_state_scalar("wall_side")) * P_wall_run_camera_tilt, P_camera_roll_lerp_speed, dt)
	elif active_state == "VAULT":
		_k_tween_position("vault", P_vault_duration)
	elif active_state == "GLIDE":
		_k_apply_gravity(dt, P_glide_gravity_scale, true, P_glide_fall_cap)
		_k_air_strafe(frame, dt, "wish", P_glide_strafe_cap, P_glide_strafe_accel)
		body.move_and_slide()
		body.host_lerp_camera_roll(P_camera_roll_level, P_camera_roll_lerp_speed, dt)
	elif active_state == "WALL_CLING":
		_k_apply_gravity(dt, P_wall_cling_gravity_scale, true, P_wall_cling_min_vy)
		body.move_and_slide()
		body.host_lerp_camera_roll(signf(_read_state_scalar("wall_side")) * P_wall_run_camera_tilt, P_camera_roll_lerp_speed, dt)


func _speed_h() -> float:
	return Vector3(body.velocity.x, 0.0, body.velocity.z).length()

func _slope_angle() -> float:
	if not body.is_on_floor():
		return 0.0
	var n := body.get_floor_normal()
	return rad_to_deg(acos(clampf(n.dot(Vector3.UP), -1.0, 1.0)))

func _wish_aligned(frame: InputFrame, cmp: String, value: float) -> bool:
	if frame.wish_dir.length_squared() < 0.001:
		return false
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if horiz.length_squared() < 0.000001:
		return false
	var dot := frame.wish_dir.dot(horiz.normalized())
	match cmp:
		"ge": return dot >= value
		"gt": return dot > value
		"le": return dot <= value
		"lt": return dot < value
		"eq": return is_equal_approx(dot, value)
	return false

func _read_state_scalar(name: String) -> float:
	if name == "wall_side":
		return -wall_side
	return float(timers.get(name, 0.0))

func _is_decaying(name: String) -> bool:
	var vdef: Variant = kit.vars.get(name, null)
	if typeof(vdef) == TYPE_DICTIONARY:
		return bool(vdef.get("decay", true))
	return true

func _resolve_space(space: Variant, frame: InputFrame) -> Vector3:
	if typeof(space) == TYPE_DICTIONARY:
		var base: Vector3 = _resolve_space(str(space.get("base", "")), frame)
		if space.has("clamp_y_min"):
			var ymin: float = float(space.get("clamp_y_min"))
			if base.y < ymin:
				base.y = ymin
				if base.length() > 0.0001:
					base = base.normalized()
		var sf := str(space.get("sign_from", ""))
		if sf != "":
			base = base * signf(_read_state_scalar(sf))
		return base
	match str(space):
		"wish":
			return frame.wish_dir
		"forward":
			return -body.transform.basis.z
		"aim":
			var aim := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
			return aim.normalized()
		"wall_tangent":
			if wall_normal.length_squared() < 0.001:
				return Vector3.ZERO
			var along := wall_normal.cross(Vector3.UP).normalized()
			if along.dot(-body.transform.basis.z) < 0.0:
				along = -along
			return along
		"wall_normal":
			return wall_normal
	push_error("compiled: unknown space '%s'" % space)
	return Vector3.ZERO

func _curve_ramp(over_timer: String, tmax: float, from: float, to: float, power: float) -> float:
	var t := float(timers.get(over_timer, 0.0))
	if tmax <= 0.0:
		tmax = 1.0
	var fraction := clampf(1.0 - t / tmax, 0.0, 1.0)
	if power <= 0.0:
		power = 1.0
	return from + (to - from) * pow(fraction, power)

func _curve_lerp(over_timer: String, tmax: float, from: float, to: float) -> float:
	var t2 := float(timers.get(over_timer, 0.0))
	if tmax <= 0.0:
		tmax = 1.0
	var f := clampf(1.0 - t2 / tmax, 0.0, 1.0)
	return lerpf(from, to, f)

func _probe_walls(side: String) -> bool:
	var sides: Array = []
	match side:
		"right": sides = [1.0]
		"left": sides = [-1.0]
		_: sides = [1.0, -1.0]
	for s: float in sides:
		var dist := float(kit.params.get("wall_detect_distance", 0.65))
		var hit: Dictionary = body.host_wall_ray(s, dist)
		if not hit.is_empty():
			var normal: Vector3 = hit["normal"]
			if absf(normal.y) < float(kit.params.get("wall_max_normal_y", 0.3)):
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
		return absf(normal.y) < float(kit.params.get("wall_max_normal_y", 0.3))
	return false

func _k_add_velocity(frame: InputFrame, mag: float, space_raw: Variant, replace: bool, include_y: bool) -> void:
	var space := str(space_raw) if typeof(space_raw) != TYPE_DICTIONARY else "<obj>"
	if space == "velocity":
		var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if horiz.length_squared() < 0.001:
			return
		var dir := horiz.normalized()
		body.velocity.x += dir.x * mag
		body.velocity.z += dir.z * mag
		return
	var v := _resolve_space(space_raw, frame) * mag
	if replace:
		body.velocity.x = v.x
		body.velocity.z = v.z
		if include_y:
			body.velocity.y = v.y
	else:
		body.velocity.x += v.x
		body.velocity.z += v.z
		if include_y:
			body.velocity.y += v.y

func _k_accelerate_toward(frame: InputFrame, dt: float, space: String, top_speed: float, rate: float) -> void:
	if space == "wall_tangent":
		_k_accelerate_along_wall(frame, dt, top_speed, rate)
		return
	if frame.wish_dir.length_squared() < 0.001:
		return
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var target := _resolve_space(space, frame) * top_speed
	horiz = horiz.move_toward(target, rate * dt)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _k_accelerate_along_wall(frame: InputFrame, dt: float, run_speed: float, rate: float) -> void:
	var tangent := _resolve_space("wall_tangent", frame)
	if tangent.length_squared() < 0.001:
		return
	var fwd_input := 0.0
	if frame.is_pressed("move_forward"):
		fwd_input += 1.0
	if frame.is_pressed("move_backward"):
		fwd_input -= 1.0
	var current_along := Vector3(body.velocity.x, 0.0, body.velocity.z).dot(tangent)
	# REWORKED FEEL (issue #2): forward input SUSTAINS along-wall momentum (capped at
	# run_speed), it does not snap to a fixed run_speed; backward decelerates to 0; no
	# input carries momentum. run_speed is a CAP. Mirrors MovementInterpreter.
	var target_along: float
	if fwd_input > 0.0:
		target_along = clampf(current_along, 0.0, run_speed)
	elif fwd_input < 0.0:
		target_along = 0.0
	else:
		target_along = current_along
	if current_along > run_speed:
		target_along = run_speed
	var new_along := move_toward(current_along, target_along, rate * dt)
	body.velocity.x = tangent.x * new_along
	body.velocity.z = tangent.z * new_along

func _k_air_strafe(frame: InputFrame, dt: float, space: String, cap: float, rate: float) -> void:
	if frame.wish_dir.length_squared() < 0.001:
		return
	var wish := _resolve_space(space, frame)
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var current_in_wish := horiz.dot(wish)
	var add_speed := minf(cap - current_in_wish, rate * dt)
	if add_speed > 0.0:
		horiz += wish * add_speed
		body.velocity.x = horiz.x
		body.velocity.z = horiz.z

func _k_apply_friction(frame: InputFrame, dt: float, rate: float) -> void:
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	horiz = horiz.move_toward(Vector3.ZERO, rate * dt)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _k_apply_gravity(dt: float, scale: float, has_min: bool, min_vy: float) -> void:
	body.velocity.y -= gravity * scale * dt
	if has_min:
		body.velocity.y = maxf(body.velocity.y, min_vy)

func _k_carve(frame: InputFrame, dt: float, rate: float) -> void:
	if frame.wish_dir.length_squared() < 0.001:
		return
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed_now := horiz.length()
	var steered := horiz + frame.wish_dir * rate * dt
	if steered.length() > 0.001:
		steered = steered.normalized() * speed_now
		body.velocity.x = steered.x
		body.velocity.z = steered.z

func _k_slope_accelerate(dt: float, rate: float, ref_angle: float) -> void:
	if not body.is_on_floor():
		return
	var floor_normal := body.get_floor_normal()
	var ang := rad_to_deg(acos(clampf(floor_normal.dot(Vector3.UP), -1.0, 1.0)))
	if ang <= float(kit.params.get("slope_min_angle", 2.0)):
		return
	if ref_angle <= 0.0:
		ref_angle = 45.0
	var down_slope := Vector3(floor_normal.x, 0.0, floor_normal.z).normalized()
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	horiz += down_slope * rate * (ang / ref_angle) * dt
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _k_clamp_speed_h(max_speed: float) -> void:
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z).limit_length(max_speed)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _k_tween_position(timer_name: String, duration: float) -> void:
	var remaining := float(timers.get(timer_name, 0.0))
	body.host_tween_position(remaining, duration)

