## Headless behavioral test for the parkour movement prototype.
##
## This is NOT "does the project load". It instances the real test level and
## the real PlayerController, simulates input, steps the physics server, and
## ASSERTS observable outcomes (camera rotation, velocity, position variance,
## respawn). Each assertion reports PASS/FAIL with the measured value.
##
## It is a Node attached to tests/movement_behavior_test.tscn and is run by
## launching that scene headless so the project autoloads (InputSettings,
## GameSettings) are active exactly as in real gameplay:
##
##   godot4 --headless tests/movement_behavior_test.tscn --quit-after 6000
##
## (--quit-after is a frame-count safety net; the test calls quit() itself with
## exit code 0 only if every assertion passed.)
##
## It deliberately does NOT run during normal gameplay: it is not the main
## scene and not an autoload.

extends Node

## The suite runs against BOTH movement implementations: the interpreter-driven
## InterpretedPlayer (the data-driven substrate, now the live player) and the
## imperative PlayerController (the parity oracle). Same assertions, same real-
## input harness; every assertion that passes against the imperative reference
## must pass against the interpreter. State-enum ordinals are identical across the
## two player scripts, so `== S_SLIDE` holds for both.
const TEST_LEVEL_INTERPRETED := "res://scenes/test_level.tscn"
const TEST_LEVEL_IMPERATIVE := "res://scenes/test_level_imperative.tscn"
## The COMPILED projection (CompiledBaseMovement, generated from the same kit),
## driving the same InterpretedPlayer host via use_compiled=true. The compiled
## path must pass the SAME assertions as the interpreter and imperative oracle
## (docs/decisions/movement-substrate.md Slice 3 verify).
const TEST_LEVEL_COMPILED := "res://scenes/test_level_compiled.tscn"

# State ordinals, shared by both player scripts (InterpretedPlayer.State mirrors
# PlayerController.State exactly). Local copy so the suite is target-agnostic.
const S_GROUND := 0
const S_AIR := 1
const S_SLIDE := 2
const S_CROUCH := 3
const S_WALL_RUN := 4
const S_VAULT := 5

var _pass_count := 0
var _fail_count := 0

## Current target scene + label, set by _run for each implementation.
var _target_scene: String = TEST_LEVEL_INTERPRETED
var _target_label: String = "interpreter"


func _ready() -> void:
	_run()


func _run() -> void:
	print("\n=== aeriea movement behavioral test ===\n")

	for target in [
		{"scene": TEST_LEVEL_INTERPRETED, "label": "interpreter"},
		{"scene": TEST_LEVEL_COMPILED, "label": "compiled"},
		{"scene": TEST_LEVEL_IMPERATIVE, "label": "imperative"},
	]:
		_target_scene = target["scene"]
		_target_label = target["label"]
		print("\n--- target: %s (%s) ---\n" % [_target_label, _target_scene])
		# Clear residual physics bodies from the prior target's freed levels and any
		# lingering global input state before starting this target's suite, so each
		# target runs in a clean world (targets share one physics space + global Input).
		for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch", "jump"]:
			if InputMap.has_action(action):
				Input.action_release(action)
		Input.flush_buffered_events()
		for _i in 10:
			await get_tree().physics_frame
		await _run_suite()

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _run_suite() -> void:
	await _test_default_mouse_sensitivity_nonzero()
	await _test_mouse_motion_rotates_camera()
	_test_jump_binding_survives_autoload_init()
	_test_crouch_binding_survives_autoload_init()
	await _test_jump_from_real_key_event()
	await _test_ground_jump_from_settled_ground_state()
	await _test_crouch_from_real_key_event()
	await _test_jump_after_pause_unpause()
	await _test_crouch_no_vertical_jitter()
	await _test_wallrun_not_triggered_by_crouch()
	await _test_crouch_action_maps_to_crouch_only()
	await _test_low_speed_crouch_is_crouchwalk_not_slide()
	await _test_high_speed_crouch_is_slide()
	await _test_slide_is_steerable_and_cancelable()
	await _test_air_control_steers_without_adding_speed()
	await _test_jump_from_standstill_stays_horizontal_zero()
	await _test_moving_jump_preserves_horizontal_speed()
	await _test_landing_no_input_bleeds_momentum()
	await _test_bullet_jump_forward_up_burst()
	await _test_bullet_jump_tracks_aim_pitch()
	await _test_wall_cling_latches_and_suppresses_gravity()
	await _test_aim_glide_slows_descent()
	await _test_slope_holds_position_without_crouch()
	await _test_crouchwalk_no_vertical_jitter()
	await _test_slide_speed_does_not_compound()
	await _test_wallrun_backward_does_not_accelerate_forward()
	await _test_respawn_below_kill_y()


# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

func _assert(test_name: String, condition: bool, evidence: String) -> void:
	var labelled := "[%s] %s" % [_target_label, test_name]
	if condition:
		_pass_count += 1
		print("  PASS  %s  [%s]" % [labelled, evidence])
	else:
		_fail_count += 1
		print("  FAIL  %s  [%s]" % [labelled, evidence])


## Build a fresh level instance for the current target and return its player.
## The player is returned untyped (the two implementations share a duck-typed
## surface: _state, _is_crouched, _capsule, the timer accessors, _apply_look,
## _input, mouse_sensitivity, slide/wall tuning). Healing GameSettings to defaults
## first so tests are deterministic and independent of any persisted user config.
func _spawn_level() -> Dictionary:
	GameSettings.reset_all()  # deterministic, sane defaults
	var scene: PackedScene = load(_target_scene)
	var level: Node = scene.instantiate()
	add_child(level)
	# Let _ready run and a couple of physics frames settle the body on ground.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: CharacterBody3D = level.get_node("Player")
	return {"level": level, "player": player}


func _step_physics(_player: CharacterBody3D, frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


## Step physics until the player is on the floor (or a frame budget elapses).
## Returns true if grounded. Used so jump tests run from a known grounded state
## rather than guessing a frame count.
func _settle_on_floor(player: CharacterBody3D, max_frames: int = 120) -> bool:
	for i in max_frames:
		await get_tree().physics_frame
		if player.is_on_floor():
			return true
	return player.is_on_floor()


func _make_motion(dx: float, dy: float) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	return ev


func _make_key(physical_keycode: int, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	ev.pressed = pressed
	return ev


## Drive a physical key through the REAL global input pipeline — the same path
## a hardware key press takes — rather than calling a controller method or
## Input.action_press(). This exercises the InputMap binding (physical key →
## action) end to end, which is what was silently bypassed before.
func _send_key(physical_keycode: int, pressed: bool) -> void:
	Input.parse_input_event(_make_key(physical_keycode, pressed))
	Input.flush_buffered_events()


## First InputEventKey bound to an action whose physical_keycode matches, or
## null if none. Used to assert the project default binding survived autoload
## init (InputSettings must never clobber a known action into unbound state).
func _action_has_physical_key(action: String, physical_keycode: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == physical_keycode:
			return true
	return false


# ---------------------------------------------------------------------------
# Item 1 — mouse sensitivity / look
# ---------------------------------------------------------------------------

func _test_default_mouse_sensitivity_nonzero() -> void:
	GameSettings.reset_all()
	var s: float = GameSettings.mouse_sensitivity
	_assert(
		"default mouse_sensitivity > usable floor",
		s >= GameSettings.MOUSE_SENS_MIN and s > 0.0,
		"mouse_sensitivity=%.5f, MIN=%.5f" % [s, GameSettings.MOUSE_SENS_MIN]
	)


func _test_mouse_motion_rotates_camera() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	var yaw_before := player.rotation.y
	# Drive the real look math directly. The controller only gates this on
	# Input.mouse_mode == CAPTURED, which headless cannot honour (the OS mouse
	# can't be captured without a window), so we exercise the extracted handler
	# that _input calls. The sensitivity it uses is the live GameSettings value.
	player._apply_look(Vector2(100.0, 0.0))
	var yaw_after := player.rotation.y
	var delta := absf(yaw_after - yaw_before)
	var expected: float = 100.0 * player.mouse_sensitivity

	_assert(
		"mouse motion rotates camera by nonzero amount at default sensitivity",
		delta > 0.0001 and is_equal_approx(delta, expected),
		"yaw delta=%.5f rad for 100px motion (expected=%.5f, sens=%.5f)" % [delta, expected, player.mouse_sensitivity]
	)

	# Also confirm the gating: while NOT captured, _input must not rotate.
	# _input re-reads the REAL Input.mouse_mode (the source of truth) on entry —
	# setting the cached _mouse_captured flag alone is overwritten immediately,
	# so we must set the actual mouse mode to exercise the gate. Under a real
	# window (xvfb) the mode is genuinely honoured; headless it's a no-op but the
	# code path is identical.
	var prev_mode := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var yaw_pre_gate := player.rotation.y
	player._input(_make_motion(100.0, 0.0))
	var gated_ok := is_equal_approx(player.rotation.y, yaw_pre_gate)
	Input.mouse_mode = prev_mode
	_assert(
		"look is gated off when mouse not captured",
		gated_ok,
		"yaw unchanged while uncaptured: before=%.5f after=%.5f" % [yaw_pre_gate, player.rotation.y]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Item 2 — jump, crouch jitter, dynamic FOV, leniency, recapture
# ---------------------------------------------------------------------------

## Binding-survival: after the InputSettings autoload has run its _ready
## (capture defaults + load/apply overrides), the project default Space→jump
## binding MUST still be present in the live InputMap. If InputSettings clobbers
## or fails to fall back to defaults, the action ends up unbound and physical
## Space does nothing in the running game — exactly the dead-jump bug. This is
## a pure InputMap assertion; it does not spawn the level.
func _test_jump_binding_survives_autoload_init() -> void:
	_assert(
		"Space→jump binding survives InputSettings autoload init",
		_action_has_physical_key("jump", KEY_SPACE),
		"jump events=%s" % str(InputMap.action_get_events("jump"))
	)


func _test_crouch_binding_survives_autoload_init() -> void:
	_assert(
		"Ctrl→crouch binding survives InputSettings autoload init",
		_action_has_physical_key("crouch", KEY_CTRL),
		"crouch events=%s" % str(InputMap.action_get_events("crouch"))
	)


## Drive jump by injecting a real physical Space key through Input.parse_input_event
## (NOT Input.action_press, NOT a direct method call) so the whole physical-key →
## InputMap action → controller pipeline is exercised. Asserts the body gains
## upward velocity.
func _test_jump_from_real_key_event() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	var on_floor := await _settle_on_floor(player)

	# Clean key state, then inject a real Space-down through the input pipeline.
	_send_key(KEY_SPACE, false)
	_send_key(KEY_SPACE, true)
	var buffered: float = player._jump_buffer_timer
	# Allow up to two physics frames: the jump may fire on the landing frame.
	await get_tree().physics_frame
	var vy := player.velocity.y
	if vy <= 0.0:
		await get_tree().physics_frame
		vy = maxf(vy, player.velocity.y)
	_send_key(KEY_SPACE, false)

	_assert(
		"physical Space key (real input pipeline) makes velocity.y positive",
		vy > 0.0,
		"on_floor_before=%s, buffer_set=%.3f, velocity.y=%.3f after Space" % [str(on_floor), buffered, vy]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## Plain GROUND jump from a fully-SETTLED standing state (issue #1 regression
## guard). The prior _test_jump_from_real_key_event pressed Space on the LANDING
## frame, while the interpreter was still transiently in AIR (is_on_floor() true
## but active_state==AIR): the jump fired via the AIR/landing-reenter path, so it
## passed even though a plain GROUND-state jump was DEAD in the live game. The live
## bug only manifests once the player is steady in GROUND for several ticks: the
## GROUND buffered-jump transition was `reenter:true`, so after it set vy and handed
## to AIR, the AIR->GROUND `on_ground` transition immediately bounced back the same
## tick (is_on_floor() stale-true before move_and_slide), and GROUND's tick clobbered
## the impulse with ground_snap_bias — vy stayed 0. This test reproduces the real
## path: settle, idle until active_state==GROUND for real, THEN tap. It FAILS against
## the broken kit (vy==0) and passes after (vy>0).
func _test_ground_jump_from_settled_ground_state() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)
	# Idle until the state machine is genuinely in GROUND (not the AIR landing
	# transient), then a few more ticks so we are unambiguously settled.
	var in_ground := false
	for _i in 30:
		await get_tree().physics_frame
		if player._state == S_GROUND:
			in_ground = true
			break
	await _step_physics(player, 5)
	var state_before: int = player._state

	# One real Space tap (down one frame, up) from the settled GROUND state.
	_send_key(KEY_SPACE, false)
	_send_key(KEY_SPACE, true)
	await get_tree().physics_frame
	_send_key(KEY_SPACE, false)
	var vy := player.velocity.y
	if vy <= 0.0:
		await get_tree().physics_frame
		vy = maxf(vy, player.velocity.y)

	_assert(
		"plain GROUND jump from a fully-settled standing state produces upward velocity",
		state_before == S_GROUND and vy > 0.0,
		"state_before=%d (GROUND=%d), reached_ground=%s, velocity.y=%.3f after Space tap" % [
			state_before, S_GROUND, str(in_ground), vy]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## Drive crouch by injecting a real physical Ctrl key through the input pipeline,
## while moving fast enough to slide, and assert the slide state + crouched
## collider engage. This exercises the polled Input.is_action_pressed("crouch")
## path through the real InputMap binding rather than Input.action_press.
func _test_crouch_from_real_key_event() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	await _settle_on_floor(player)

	# Give the player forward speed above slide_min_speed so a crouch triggers
	# a slide (the controller's crouch behaviour). Hold W + sprint, then Ctrl.
	_send_key(KEY_W, true)
	_send_key(KEY_SHIFT, true)
	await _step_physics(player, 30)
	var speed_before := Vector3(player.velocity.x, 0.0, player.velocity.z).length()

	var stand_h: float = player._capsule.height
	_send_key(KEY_CTRL, true)
	await _step_physics(player, 8)
	var crouched: bool = player._is_crouched
	var crouch_h: float = player._capsule.height
	var state: int = player._state
	_send_key(KEY_CTRL, false)
	_send_key(KEY_W, false)
	_send_key(KEY_SHIFT, false)

	_assert(
		"physical Ctrl key (real input pipeline) engages crouch/slide",
		crouched and crouch_h < stand_h and state == S_SLIDE,
		"speed_before=%.2f, crouched=%s, capsule h %.2f->%.2f, state=%d (SLIDE=%d)" % [speed_before, str(crouched), stand_h, crouch_h, state, S_SLIDE]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_jump_after_pause_unpause() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	var pause_menu: CanvasLayer = ctx["level"].get_node("PauseMenu")

	await _settle_on_floor(player)

	# Simulate pause then unpause via the pause menu's real code paths.
	pause_menu._pause()
	await get_tree().process_frame
	pause_menu._unpause()
	# Let physics resume and the body re-settle on the floor after unpausing.
	await _settle_on_floor(player)

	# Release jump first (clean state), then press — via the real input pipeline.
	_send_key(KEY_SPACE, false)
	_send_key(KEY_SPACE, true)
	# Allow up to two physics frames: the jump may fire on the landing frame.
	await get_tree().physics_frame
	var vy := player.velocity.y
	if vy <= 0.0:
		await get_tree().physics_frame
		vy = maxf(vy, player.velocity.y)

	_assert(
		"jump still works after pause -> unpause cycle",
		vy > 0.0,
		"velocity.y=%.3f after unpause+jump (paused now=%s)" % [vy, str(get_tree().paused)]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_crouch_no_vertical_jitter() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	# Settle on flat ground.
	await _step_physics(player, 15)

	# Hold crouch (Ctrl) while stationary on flat ground — via the real pipeline.
	_send_key(KEY_CTRL, true)
	# Step several frames to let any height transition settle.
	await _step_physics(player, 10)

	var samples: Array[float] = []
	for i in 30:
		await get_tree().physics_frame
		samples.append(player.global_position.y)
	_send_key(KEY_CTRL, false)

	# Compute variance of the body Y over the sampled window.
	var mean := 0.0
	for y in samples:
		mean += y
	mean /= samples.size()
	var variance := 0.0
	for y in samples:
		variance += (y - mean) * (y - mean)
	variance /= samples.size()

	_assert(
		"crouch does not oscillate body Y (variance < epsilon)",
		variance < 0.0005,
		"y variance=%.6f over %d frames (mean y=%.3f)" % [variance, samples.size(), mean]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Item 3 — wall-run automatic, Ctrl is crouch only
# ---------------------------------------------------------------------------

func _test_wallrun_not_triggered_by_crouch() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	await _step_physics(player, 10)

	# Press crouch (Ctrl) and step. The player must NOT enter WALL_RUN state
	# merely from pressing crouch on flat ground. Drive via the real pipeline.
	_send_key(KEY_CTRL, true)
	await _step_physics(player, 20)
	var state: int = player._state
	_send_key(KEY_CTRL, false)

	_assert(
		"crouch/Ctrl does NOT trigger wall-run",
		state != S_WALL_RUN,
		"state after crouch=%d (WALL_RUN=%d)" % [state, S_WALL_RUN]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_crouch_action_maps_to_crouch_only() -> void:
	# Verify the InputMap: the Ctrl key (KEY_CTRL) is bound to 'crouch' and
	# that 'crouch' is the ONLY action it triggers. There is no 'wall_run'
	# action at all (wall-run is automatic), so assert that too.
	var crouch_has_ctrl := false
	for ev in InputMap.action_get_events("crouch"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_CTRL:
			crouch_has_ctrl = true

	var no_wallrun_action := not InputMap.has_action("wall_run") and not InputMap.has_action("wallrun")

	# Ensure Ctrl is not also bound to any other rebindable action.
	var ctrl_other := false
	for entry in InputSettings.REBINDABLE_ACTIONS:
		var a: String = entry["action"]
		if a == "crouch":
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_CTRL:
				ctrl_other = true

	_assert(
		"Ctrl maps to crouch only; no wall_run action exists",
		crouch_has_ctrl and no_wallrun_action and not ctrl_other,
		"crouch_has_ctrl=%s, no_wallrun_action=%s, ctrl_bound_elsewhere=%s" % [str(crouch_has_ctrl), str(no_wallrun_action), str(ctrl_other)]
	)


# ---------------------------------------------------------------------------
# Slide / crouch state-machine behaviour (the reworked system)
# ---------------------------------------------------------------------------

## (a) Crouch at LOW speed → CROUCH-WALK, not SLIDE.
func _test_low_speed_crouch_is_crouchwalk_not_slide() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)

	# Walk (no sprint) for a moment, then ease off so speed is well below the
	# slide-entry threshold, then press crouch.
	_send_key(KEY_W, true)
	await _step_physics(player, 6)
	_send_key(KEY_W, false)
	await _step_physics(player, 6)
	var speed_before := Vector3(player.velocity.x, 0.0, player.velocity.z).length()

	_send_key(KEY_CTRL, true)
	await _step_physics(player, 6)
	var state: int = player._state
	var crouched: bool = player._is_crouched
	_send_key(KEY_CTRL, false)

	_assert(
		"low-speed crouch enters CROUCH-WALK, not SLIDE",
		state == S_CROUCH and crouched and state != S_SLIDE,
		"speed_before=%.2f (entry=%.1f), state=%d (CROUCH=%d SLIDE=%d), crouched=%s" % [
			speed_before, player.slide_entry_speed, state,
			S_CROUCH, S_SLIDE, str(crouched)]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## (b) Crouch at HIGH speed → SLIDE.
func _test_high_speed_crouch_is_slide() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)

	# Sprint forward to exceed slide_entry_speed, then crouch.
	_send_key(KEY_W, true)
	_send_key(KEY_SHIFT, true)
	await _step_physics(player, 30)
	var speed_before := Vector3(player.velocity.x, 0.0, player.velocity.z).length()

	_send_key(KEY_CTRL, true)
	await _step_physics(player, 4)
	var state: int = player._state
	_send_key(KEY_CTRL, false)
	_send_key(KEY_W, false)
	_send_key(KEY_SHIFT, false)

	_assert(
		"high-speed crouch enters SLIDE",
		state == S_SLIDE and speed_before >= player.slide_entry_speed,
		"speed_before=%.2f (entry=%.1f), state=%d (SLIDE=%d)" % [
			speed_before, player.slide_entry_speed, state, S_SLIDE]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## (c) While sliding, lateral/forward input measurably changes velocity direction
## AND/OR exits the slide — proving steerable + cancelable.
func _test_slide_is_steerable_and_cancelable() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)

	# Enter a slide at speed.
	_send_key(KEY_W, true)
	_send_key(KEY_SHIFT, true)
	await _step_physics(player, 30)
	_send_key(KEY_SHIFT, false)
	_send_key(KEY_CTRL, true)
	await _step_physics(player, 2)
	var entered_slide: bool = player._state == S_SLIDE
	var vel_dir_before := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()

	# Now steer hard to the left (and keep W) for several frames.
	_send_key(KEY_A, true)
	await _step_physics(player, 12)
	var vel_dir_after := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	var dir_change := rad_to_deg(vel_dir_before.angle_to(vel_dir_after))
	var exited: bool = player._state != S_SLIDE

	_send_key(KEY_A, false)
	_send_key(KEY_W, false)
	_send_key(KEY_CTRL, false)

	_assert(
		"slide is steerable (direction changes) and/or cancelable (exits) under input",
		entered_slide and (dir_change > 2.0 or exited),
		"entered_slide=%s, dir_change=%.2f deg, exited_slide=%s (state=%d)" % [
			str(entered_slide), dir_change, str(exited), player._state]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## PLAYTEST FIX (air control = steer only). While airborne, holding a movement
## direction must ROTATE the existing horizontal velocity toward wish-dir WITHOUT
## increasing its magnitude (magnitude-preserving carve), not add net speed
## (the old additive Quake-style air-strafe). Data paths only: the imperative
## oracle (PlayerController) intentionally keeps the old additive air-strafe and is
## not in scope for this fix, so it would (correctly) fail a steer-only assertion.
##
## (a) Airborne + held OFF-AXIS direction does NOT raise horizontal speed magnitude
## vs the pre-input magnitude. We jump, build a forward horizontal speed, then hold
## a perpendicular direction and confirm |horiz| does not grow.
func _test_air_control_steers_without_adding_speed() -> void:
	if _target_label == "imperative":
		return
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)

	# Put the player airborne in clear air, moving forward (-Z) at a known speed, with
	# yaw=0 so the wish-dir spaces are axis-aligned. This isolates the air-control
	# kernel from ground/jump timing — we are testing what held input does to an
	# EXISTING airborne horizontal velocity.
	player.global_position = Vector3(0.0, 6.0, 0.0)
	player._yaw = 0.0
	player.rotation.y = 0.0
	player.velocity = Vector3(0.0, 0.5, -6.0)   # ~6 m/s forward, slightly rising
	await get_tree().physics_frame
	var airborne_before: bool = not player.is_on_floor()
	var speed_before := Vector3(player.velocity.x, 0.0, player.velocity.z).length()

	# Hold a hard-perpendicular direction (D = strafe right, +X) while airborne.
	# Additive air-strafe would push |horiz| UP (adding +X speed on top of the -Z
	# speed); steer-only must keep magnitude ~flat (it rotates the vector instead).
	_send_key(KEY_D, true)
	var max_speed := speed_before
	for _i in 18:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
		max_speed = maxf(max_speed, Vector3(player.velocity.x, 0.0, player.velocity.z).length())
	_send_key(KEY_D, false)

	# Allow a tiny epsilon for float carve renormalization.
	var did_not_gain := max_speed <= speed_before + 0.2
	_assert(
		"air control steers without adding horizontal speed (magnitude preserved)",
		airborne_before and speed_before > 1.0 and did_not_gain,
		"airborne=%s, speed_before=%.3f, max_speed_while_steering=%.3f (gain=%+.3f, must be <= +0.20)" % [
			str(airborne_before), speed_before, max_speed, max_speed - speed_before]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## (b) From standstill: jump straight up and hold a direction → horizontal speed
## stays ~0 (carve of a ~zero vector adds nothing). Additive air-strafe would
## accelerate the body sideways from rest.
func _test_jump_from_standstill_stays_horizontal_zero() -> void:
	if _target_label == "imperative":
		return
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)
	# Standstill: airborne in clear air with ZERO horizontal velocity (a straight-up
	# jump from rest is exactly this — vy>0, no horizontal). yaw=0 so W = -Z wish.
	player.global_position = Vector3(0.0, 6.0, 0.0)
	player._yaw = 0.0
	player.rotation.y = 0.0
	player.velocity = Vector3(0.0, 6.0, 0.0)   # rising, no horizontal — "just jumped from standstill"
	await get_tree().physics_frame
	var airborne: bool = not player.is_on_floor()

	# Hold forward for many frames. Steer-only of a ~zero horizontal vector adds
	# ~nothing; additive air-strafe would accelerate sideways from rest.
	_send_key(KEY_W, true)
	var max_h := 0.0
	for _i in 18:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
		max_h = maxf(max_h, Vector3(player.velocity.x, 0.0, player.velocity.z).length())
	_send_key(KEY_W, false)

	_assert(
		"jump from standstill + held direction keeps horizontal speed ~0 (steer-only)",
		airborne and max_h < 0.5,
		"airborne=%s, max horizontal speed while holding W airborne from rest=%.4f (epsilon 0.5)" % [str(airborne), max_h]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## (c) Moving + jump: horizontal speed magnitude is PRESERVED through the jump (the
## jump is a vertical impulse only; air control redirects, doesn't boost). We hold
## W throughout, so the only forces on |horiz| in the air are carve (magnitude-
## preserving). Speed must not be boosted above the pre-jump ground speed.
func _test_moving_jump_preserves_horizontal_speed() -> void:
	if _target_label == "imperative":
		return
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)

	# The regular-jump transition in the kit is a vertical impulse ONLY (set_velocity_y
	# jump_velocity; no horizontal effect), so the horizontal magnitude entering AIR
	# equals the ground speed. We reproduce the post-jump airborne state deterministically:
	# the body airborne (vy = jump_velocity) carrying its forward speed, holding W
	# (forward, ALIGNED with motion). Holding a direction aligned with velocity must NOT
	# boost speed (steer-only); the magnitude must hold at the entry speed.
	player.global_position = Vector3(0.0, 6.0, 10.0)
	player._yaw = 0.0
	player.rotation.y = 0.0
	var speed_ground := float(player.kit.params.get("walk_speed", 5.5))
	player.velocity = Vector3(0.0, float(player.kit.params.get("jump_velocity", 9.5)), -speed_ground)
	await get_tree().physics_frame
	var airborne: bool = not player.is_on_floor()
	# Hold W (forward, aligned with the -Z motion) through the air.
	_send_key(KEY_W, true)
	var max_air := speed_ground
	for _i in 18:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
		max_air = maxf(max_air, Vector3(player.velocity.x, 0.0, player.velocity.z).length())
	_send_key(KEY_W, false)

	_assert(
		"moving jump preserves horizontal speed (not boosted by air input)",
		airborne and max_air <= speed_ground + 0.2,
		"airborne=%s, speed_ground=%.3f, max_air_speed=%.3f (gain=%+.3f, must be <= +0.20)" % [
			str(airborne), speed_ground, max_air, max_air - speed_ground]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## (d) Landing with NO input bleeds horizontal momentum to rest (no persistent
## post-landing slide). Build air speed, land, release all input, and confirm the
## horizontal speed decays to ~0 within a sensible window via ground friction.
func _test_landing_no_input_bleeds_momentum() -> void:
	if _target_label == "imperative":
		return
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)

	# Put the body airborne in clear air, moving forward at a real speed, with NO
	# input held — the post-jump airborne state carrying horizontal momentum. It will
	# fall, land, and (with the fix) ground friction must bleed the carried momentum to
	# rest. Deterministic (no shared-Input buffered-jump timing).
	player.global_position = Vector3(0.0, 4.0, 10.0)
	player._yaw = 0.0
	player.rotation.y = 0.0
	player.velocity = Vector3(0.0, 0.5, -6.0)   # ~6 m/s forward, slightly rising
	await get_tree().physics_frame
	var landed := false
	for _i in 120:
		await get_tree().physics_frame
		if player.is_on_floor() and player._state == S_GROUND:
			landed = true
			break
	var speed_on_land := Vector3(player.velocity.x, 0.0, player.velocity.z).length()

	# With no input, ground friction must bleed it to rest within ~1 s (60 frames).
	var speed_after := speed_on_land
	for _i in 60:
		await get_tree().physics_frame
		speed_after = Vector3(player.velocity.x, 0.0, player.velocity.z).length()
		if speed_after < 0.1:
			break

	_assert(
		"landing with no input bleeds horizontal momentum to rest (no lingering slide)",
		landed and speed_after < 0.1,
		"landed=%s, speed_on_land=%.3f -> speed_after_60f=%.4f (must be < 0.10)" % [
			str(landed), speed_on_land, speed_after]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## SLICE 4 — bullet jump as a PURE-DATA verb (movement/verbs/bullet_jump.kit.json,
## composed via the manifest overlay; NO engine code change). Warframe idiom:
## triggered by the JUMP key (Space) while in SLIDE or CROUCH — NOT a dedicated
## key. Get moving fast → crouch into a SLIDE → press Space: assert the forward+up
## burst (vy positive AND forward horizontal speed increased BEYOND a plain jump from
## the same approach). The verb lives only on the data paths (interpreter/compiled);
## the imperative oracle has no such verb, so there it must correctly NOT fire the
## burst (the plain slide stays in SLIDE since the base kit has no jump-from-slide
## without the verb).
func _test_bullet_jump_forward_up_burst() -> void:
	var is_data_path: bool = _target_label != "imperative"

	# --- (1) Plain-jump baseline: same fast forward approach from GROUND, then Space. ---
	var ctx1 := await _spawn_level()
	var p1: CharacterBody3D = ctx1["player"]
	await _settle_on_floor(p1)
	_send_key(KEY_W, true)
	_send_key(KEY_SHIFT, true)
	await _step_physics(p1, 30)
	var fwd1 := -p1.transform.basis.z
	fwd1.y = 0.0
	fwd1 = fwd1.normalized()
	_send_key(KEY_SPACE, true)
	await _step_physics(p1, 2)
	_send_key(KEY_SPACE, false)
	var jump_fwd_speed := Vector3(p1.velocity.x, 0.0, p1.velocity.z).dot(fwd1)
	var jump_vy := p1.velocity.y
	_send_key(KEY_W, false)
	_send_key(KEY_SHIFT, false)
	ctx1["level"].queue_free()
	await get_tree().process_frame

	# --- (2) Bullet jump: fast approach → crouch into SLIDE → press SPACE (same jump key). ---
	var ctx2 := await _spawn_level()
	var p2: CharacterBody3D = ctx2["player"]
	await _settle_on_floor(p2)
	_send_key(KEY_W, true)
	_send_key(KEY_SHIFT, true)
	await _step_physics(p2, 30)
	_send_key(KEY_CTRL, true)            # crouch → SLIDE at speed
	await _step_physics(p2, 4)
	var in_slide_or_crouch: bool = (p2._state == S_SLIDE or p2._state == S_CROUCH)
	var fwd2 := -p2.transform.basis.z
	fwd2.y = 0.0
	fwd2 = fwd2.normalized()
	# Fire bullet jump via the SAME jump key (Space) — Warframe idiom, no dedicated key.
	_send_key(KEY_SPACE, true)
	await _step_physics(p2, 2)
	_send_key(KEY_SPACE, false)
	await _step_physics(p2, 1)
	var bj_fwd_speed := Vector3(p2.velocity.x, 0.0, p2.velocity.z).dot(fwd2)
	var bj_vy := p2.velocity.y
	var bj_state: int = p2._state
	_send_key(KEY_CTRL, false)
	_send_key(KEY_W, false)
	_send_key(KEY_SHIFT, false)
	ctx2["level"].queue_free()
	await get_tree().process_frame

	if is_data_path:
		# The payoff: airborne, rising, and faster forward than a plain jump.
		var rising: bool = bj_vy > 0.0
		var faster_forward: bool = bj_fwd_speed > jump_fwd_speed + 1.0
		var went_air: bool = bj_state == S_AIR
		_assert(
			"bullet jump (Space from SLIDE) bursts forward+up beyond a plain jump (pure-data verb)",
			in_slide_or_crouch and rising and faster_forward and went_air,
			"bj_vy=%.3f (rising), bj_fwd=%.2f vs jump_fwd=%.2f (delta=%+.2f), bj_state=%d (AIR=%d)" % [
				bj_vy, bj_fwd_speed, jump_fwd_speed, bj_fwd_speed - jump_fwd_speed, bj_state, S_AIR]
		)
	else:
		# Imperative oracle has no bullet-jump verb: pressing Space from a slide
		# triggers the plain PlayerController slide-jump (which is the imperative
		# controller's own transition). The slide-jump does NOT have the bullet-jump's
		# forward burst, so bj_fwd_speed should not exceed jump_fwd_speed + 1.0.
		# We only verify it does NOT bullet-jump (no forward burst beyond the
		# plain-jump baseline) — we do NOT assert it stays in SLIDE (it will still
		# jump, just without the burst).
		var burst_fired: bool = bj_fwd_speed > jump_fwd_speed + 1.0 and bj_vy > 0.0 and bj_state == S_AIR
		_assert(
			"bullet jump forward burst correctly absent on imperative oracle (no data verb)",
			not burst_fired,
			"bj_vy=%.3f, bj_fwd=%.2f vs jump_fwd=%.2f (burst_delta=%+.2f), state=%d (no burst expected; AIR=%d)" % [
				bj_vy, bj_fwd_speed, jump_fwd_speed, bj_fwd_speed - jump_fwd_speed, bj_state, S_AIR]
		)


## Directionality: a bullet jump launches along the FULL LOOK/AIM vector (the new
## `aim` space = yaw+pitch). Look UP → greater vy; LEVEL → a sensible upward arc;
## DOWN → lower / negative vy (dive). Proves the burst tracks camera pitch. Data
## paths only (interpreter/compiled); the imperative oracle has no aim verb.
func _test_bullet_jump_tracks_aim_pitch() -> void:
	if _target_label == "imperative":
		return
	var vy_up := await _bullet_jump_vy_at_pitch(0.7)     # ~40 deg up
	var vy_level := await _bullet_jump_vy_at_pitch(0.0)   # level
	var vy_down := await _bullet_jump_vy_at_pitch(-0.7)   # ~40 deg down

	# vy_down is read after the physics commit: a downward dive launched from the
	# ground immediately re-contacts the floor, so move_and_slide clamps its
	# negative vy to 0 (it cannot gain height). Hence the floor-faithful assertion
	# is vy_down <= 0 (no upward gain), strictly below the level arc — together with
	# up > level this proves the burst tracks camera pitch. (The raw launch vy at
	# down-pitch is negative, ~base_up + sin(pitch)*impulse; the golden-trace
	# pitched case verifies the airborne trajectory bit-for-bit on both paths.)
	_assert(
		"bullet jump vy tracks aim pitch: up > level, level arcs up (>0), down does not gain height (<=0 and < level)",
		vy_up > vy_level and vy_level > vy_down and vy_level > 0.0 and vy_down <= 0.0,
		"vy_up=%.3f, vy_level=%.3f, vy_down=%.3f (expect up>level>down, level>0, down<=0)" % [
			vy_up, vy_level, vy_down]
	)


## Drive one bullet jump from a slide while looking at `pitch_rad` (radians, +up),
## return the post-burst velocity.y. Pitch is fed to the sim via the host each
## physics frame (host: interpreter.pitch = _pitch), exactly as mouse-look does.
func _bullet_jump_vy_at_pitch(pitch_rad: float) -> float:
	var ctx := await _spawn_level()
	var p: CharacterBody3D = ctx["player"]
	await _settle_on_floor(p)
	p._pitch = pitch_rad
	_send_key(KEY_W, true)
	_send_key(KEY_SHIFT, true)
	await _step_physics(p, 30)
	_send_key(KEY_CTRL, true)            # crouch → SLIDE at speed
	await _step_physics(p, 4)
	p._pitch = pitch_rad                 # ensure pitch held through the launch tick
	_send_key(KEY_SPACE, true)
	await _step_physics(p, 1)            # the SLIDE→AIR bullet-jump transition tick
	var vy := p.velocity.y
	_send_key(KEY_SPACE, false)
	_send_key(KEY_CTRL, false)
	_send_key(KEY_W, false)
	_send_key(KEY_SHIFT, false)
	ctx["level"].queue_free()
	await get_tree().process_frame
	return vy


## WALL-CLING as a PURE-DATA verb (movement/verbs/wall_cling.kit.json, composed
## via the manifest overlay; NO engine code change). Place the body airborne beside
## the right wall (WallB x=3.5, surface ~x=3.0) and HOLD `cling`: assert it LATCHES
## (enters WALL_CLING), gravity is SUPPRESSED (it does not fall like a free body over
## the hold window — vy stays ~0 and Y barely drops), and it RELEASES on letting go
## (leaves WALL_CLING). Data paths only (interpreter/compiled); the imperative oracle
## has no such verb. State ordinal WALL_CLING is appended in InterpretedPlayer.State.
const S_WALL_CLING := 6
const S_GLIDE := 7

func _test_wall_cling_latches_and_suppresses_gravity() -> void:
	if _target_label == "imperative":
		return
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	# Drop the body in airborne, right next to WallB (surface ~x=3.0). Capsule radius
	# 0.35 → centre x≈2.6 is within wall_detect_distance (0.65). Face +Z, no h-velocity.
	player.global_position = Vector3(2.6, 3.0, 4.0)
	player._yaw = 0.0
	player.rotation.y = 0.0
	player.velocity = Vector3(0.0, -1.0, 0.0)
	await get_tree().physics_frame

	# Hold cling and let it latch.
	Input.action_press("cling")
	Input.flush_buffered_events()
	var latched := false
	for _i in 12:
		await get_tree().physics_frame
		if player._state == S_WALL_CLING:
			latched = true
			break

	# Measure fall over a hold window while clinging vs a free-fall baseline.
	var y_at_latch := player.global_position.y
	var vy_samples_ok := true
	for _i in 25:
		await get_tree().physics_frame
		if absf(player.velocity.y) > 1.5:   # gravity suppressed: vy must stay near 0
			vy_samples_ok = false
	var y_drop := y_at_latch - player.global_position.y   # positive = fell
	var still_clinging: bool = player._state == S_WALL_CLING

	# Now RELEASE cling and confirm it drops off the wall (leaves WALL_CLING).
	Input.action_release("cling")
	Input.flush_buffered_events()
	var released := false
	for _i in 10:
		await get_tree().physics_frame
		if player._state != S_WALL_CLING:
			released = true
			break

	# Free-fall baseline over the same number of frames (no cling), same start.
	var fall_drop := await _free_fall_drop_over(25)

	_assert(
		"wall-cling latches, suppresses gravity (vy~0, Y barely drops vs free-fall), and releases on letting go (pure-data verb)",
		latched and still_clinging and vy_samples_ok and y_drop < fall_drop * 0.5 and released,
		"latched=%s, clinging_after_hold=%s, vy_suppressed=%s, cling_drop=%.3fm vs free_fall=%.3fm (cling < half), released_on_let_go=%s" % [
			str(latched), str(still_clinging), str(vy_samples_ok), y_drop, fall_drop, str(released)]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## Free-fall Y drop over `frames` physics ticks from the same airborne start, with no
## input — the gravity baseline the cling/glide assertions compare against.
func _free_fall_drop_over(frames: int) -> float:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	player.global_position = Vector3(0.0, 12.0, 0.0)   # high up, clear air
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var y0 := player.global_position.y
	for _i in frames:
		await get_tree().physics_frame
	var drop := y0 - player.global_position.y
	ctx["level"].queue_free()
	await get_tree().process_frame
	return drop


## AIM-GLIDE as a PURE-DATA verb (movement/verbs/aim_glide.kit.json). While airborne
## and DESCENDING, holding `aim` enters GLIDE and the descent is SLOWED (downward
## speed capped) vs a free fall over the same window. Assert: enters GLIDE, and the
## glide Y-drop is markedly less than free-fall. Data paths only.
func _test_aim_glide_slows_descent() -> void:
	if _target_label == "imperative":
		return
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	# High in clear air, already descending slightly so the glide entry guard
	# (airborne + aim held + speed_v<0) is satisfied immediately.
	player.global_position = Vector3(0.0, 12.0, 0.0)
	player.velocity = Vector3(0.0, -1.0, 0.0)
	await get_tree().physics_frame

	Input.action_press("aim")
	Input.flush_buffered_events()
	var glided := false
	for _i in 12:
		await get_tree().physics_frame
		if player._state == S_GLIDE:
			glided = true
			break

	var y_start := player.global_position.y
	var max_fall_speed := 0.0
	for _i in 40:
		await get_tree().physics_frame
		max_fall_speed = maxf(max_fall_speed, -player.velocity.y)  # downward speed
	var glide_drop := y_start - player.global_position.y
	var in_glide_after: bool = player._state == S_GLIDE
	var glide_cap: float = absf(player.kit.params.get("glide_fall_cap", -2.5))
	Input.action_release("aim")
	Input.flush_buffered_events()
	ctx["level"].queue_free()
	await get_tree().process_frame

	var fall_drop := await _free_fall_drop_over(40)

	_assert(
		"aim-glide enters GLIDE and slows the descent (fall capped near glide_fall_cap, drop << free-fall) (pure-data verb)",
		glided and in_glide_after and max_fall_speed <= glide_cap + 0.5 and glide_drop < fall_drop * 0.6,
		"glided=%s, in_glide_after=%s, max_fall_speed=%.3f (cap=%.2f), glide_drop=%.3fm vs free_fall=%.3fm (glide < 60%%)" % [
			str(glided), str(in_glide_after), max_fall_speed, glide_cap, glide_drop, fall_drop]
	)


## (d) Standing on the slope with NO crouch input → horizontal position is stable
## (no involuntary downhill slide).
func _test_slope_holds_position_without_crouch() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	# Place the player above the centre of the ~15° slope (z=-30) and let it
	# settle onto the surface. No movement / crouch input at all.
	player.global_position = Vector3(0.0, 5.0, -30.0)
	player.velocity = Vector3.ZERO
	# Let it fall and settle on the slope.
	await _settle_on_floor(player, 180)
	await _step_physics(player, 20)  # let any settling motion damp out

	var p0 := Vector2(player.global_position.x, player.global_position.z)
	var max_drift := 0.0
	for i in 40:
		await get_tree().physics_frame
		var p := Vector2(player.global_position.x, player.global_position.z)
		max_drift = maxf(max_drift, p.distance_to(p0))

	_assert(
		"player holds position on slope with no crouch input (no involuntary slide)",
		max_drift < 0.15,
		"max horizontal drift=%.4f m over 40 frames on the 15deg slope, state=%d, on_floor=%s" % [
			max_drift, player._state, str(player.is_on_floor())]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


## (e) Crouch collider does not jitter while crouch-MOVING on flat ground.
## (The stationary-crouch jitter case is covered by _test_crouch_no_vertical_jitter.)
func _test_crouchwalk_no_vertical_jitter() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)

	# Crouch-walk: hold W (slow) + crouch so we're in CROUCH-WALK and moving.
	_send_key(KEY_W, true)
	_send_key(KEY_CTRL, true)
	await _step_physics(player, 12)  # let the height transition settle

	var samples: Array[float] = []
	# Sample the body Y relative to a smoothly-advancing baseline is wrong on a
	# moving body on flat ground (y should be constant), so sample raw y — flat
	# ground means y must be flat too.
	for i in 30:
		await get_tree().physics_frame
		samples.append(player.global_position.y)
	_send_key(KEY_W, false)
	_send_key(KEY_CTRL, false)

	var mean := 0.0
	for y in samples:
		mean += y
	mean /= samples.size()
	var variance := 0.0
	for y in samples:
		variance += (y - mean) * (y - mean)
	variance /= samples.size()

	_assert(
		"crouch-walk does not oscillate body Y (variance < epsilon)",
		variance < 0.0005,
		"y variance=%.6f over %d frames (mean y=%.3f), state=%d" % [
			variance, samples.size(), mean, player._state]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Bug 1 — slide speed must not compound unboundedly on flat ground
# ---------------------------------------------------------------------------

## Enter a slide on flat ground and step many physics frames. Assert that
## horizontal speed does NOT increase over time (friction must win over any
## other force on flat ground) and stays under max_slide_speed at all times.
## On the buggy code (no max_slide_speed cap, no entry-boost guard) the speed
## would grow on repeated re-entry or via the uncapped slope-accel path. With
## the fix it must monotonically decay toward zero on flat ground.
func _test_slide_speed_does_not_compound() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]
	await _settle_on_floor(player)

	# Build up sprint speed, then enter a slide.
	_send_key(KEY_W, true)
	_send_key(KEY_SHIFT, true)
	await _step_physics(player, 30)
	_send_key(KEY_SHIFT, false)

	# Enter slide via real Ctrl key.
	_send_key(KEY_CTRL, true)
	await _step_physics(player, 3)
	var entered_slide: bool = player._state == S_SLIDE

	# Sample speed every frame for 60 frames of sliding on flat ground.
	# Allow one frame of "entry" settling, then assert: speed never increases
	# significantly and always stays under max_slide_speed.
	await get_tree().physics_frame
	var prev_speed := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	var grew := false
	var exceeded_cap := false
	var max_cap: float = player.max_slide_speed

	for _i in 60:
		await get_tree().physics_frame
		var sp := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
		# Speed must not climb by more than a negligible epsilon on flat ground.
		if sp > prev_speed + 0.05:
			grew = true
		if sp > max_cap + 0.01:
			exceeded_cap = true
		prev_speed = sp
		if player._state != S_SLIDE:
			break  # slide exited (speed decayed below exit threshold) — that's fine

	_send_key(KEY_CTRL, false)
	_send_key(KEY_W, false)

	_assert(
		"slide speed does not compound: never increases on flat ground",
		entered_slide and not grew,
		"entered_slide=%s, speed_grew=%s" % [str(entered_slide), str(grew)]
	)
	_assert(
		"slide speed never exceeds max_slide_speed cap",
		not exceeded_cap,
		"exceeded_cap=%s (max_slide_speed=%.1f)" % [str(exceeded_cap), max_cap]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Bug 2 — backward input during wall-run must NOT accelerate the player forward
# ---------------------------------------------------------------------------

## Place the player in the wall-run corridor (WallA at x=-3.5, WallB at x=3.5,
## both 18 m long in Z centred around z=8) so the automatic wall-run detection
## engages on the RIGHT wall (WallB, normal points -X). Then inject backward (S)
## input and assert the player does NOT gain forward speed along the wall.
##
## On the buggy code, `velocity = along_wall * wall_run_speed` was set
## unconditionally regardless of input, so backward (S) silently ran at full
## forward speed. With the fix, backward drives target_along = 0 and the speed
## must decay rather than hold or increase.
func _test_wallrun_backward_does_not_accelerate_forward() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	# Place player inside the wall corridor, near the right wall (WallB x=3.5).
	# Wall surface faces inward at x≈3.0; player capsule radius 0.35 → centre
	# at x≈2.6 is comfortably within wall_detect_distance (0.65) of the surface.
	# Face +Z (yaw=0) and give enough +Z velocity to trigger wall-run entry.
	player.global_position = Vector3(2.6, 2.0, 4.0)
	player._yaw = 0.0
	player.rotation.y = 0.0
	player.velocity = Vector3(0.0, 1.5, player.wall_run_speed + 1.0)

	# Step frames — wall-run engages when airborne + fast + wall close + INTENT.
	# Issue #2 reworked entry to REQUIRE movement input (no involuntary snap-in), so
	# hold forward (W) during detection to express intent. Give up to 20 frames.
	_send_key(KEY_W, true)
	var entered := false
	for _i in 20:
		await get_tree().physics_frame
		if player._state == S_WALL_RUN:
			entered = true
			break
	_send_key(KEY_W, false)

	if not entered:
		# Fallback: force wall-run state with real geometry, holding forward so the
		# new no-input exit (priority 55) doesn't immediately step off the wall.
		player.global_position = Vector3(2.6, 2.0, 6.0)
		player._yaw = 0.0
		player.rotation.y = 0.0
		player.velocity = Vector3(0.0, 0.5, player.wall_run_speed)
		player._wall_normal = Vector3(-1, 0, 0)
		player._wall_run_side = 1.0
		player._wall_run_timer = player.wall_run_max_time
		player._transition(S_WALL_RUN)
		_send_key(KEY_W, true)
		await get_tree().physics_frame
		_send_key(KEY_W, false)
		entered = (player._state == S_WALL_RUN)

	var in_wall_run: bool = (player._state == S_WALL_RUN)

	# Measure speed along the wall tangent (pointing in +Z when wall normal is -X).
	var along_wall: Vector3 = player._wall_normal.cross(Vector3.UP).normalized()
	if along_wall.dot(Vector3(0, 0, 1)) < 0.0:
		along_wall = -along_wall
	var speed_before := Vector3(player.velocity.x, 0.0, player.velocity.z).dot(along_wall)

	# Inject backward (S) and hold for several frames.
	_send_key(KEY_S, true)
	await _step_physics(player, 10)
	var speed_after := Vector3(player.velocity.x, 0.0, player.velocity.z).dot(along_wall)
	_send_key(KEY_S, false)

	# Backward input must NOT cause the forward-along-wall speed to increase.
	var backward_caused_forward_accel := speed_after > speed_before + 0.5

	_assert(
		"wall-run backward input does not accelerate the player forward",
		in_wall_run and not backward_caused_forward_accel,
		"in_wall_run=%s, speed_before=%.2f, speed_after=%.2f (accel=%s)" % [
			str(in_wall_run), speed_before, speed_after, str(backward_caused_forward_accel)]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Item 4 — respawn / out-of-bounds recovery
# ---------------------------------------------------------------------------

func _test_respawn_below_kill_y() -> void:
	var ctx := await _spawn_level()
	var player: CharacterBody3D = ctx["player"]

	await _step_physics(player, 5)
	var spawn_y := player.global_position.y

	# Teleport the player far below the kill plane and give it falling velocity.
	player.global_position = Vector3(player.global_position.x, player.kill_y - 50.0, player.global_position.z)
	player.velocity = Vector3(3.0, -40.0, 2.0)

	# A physics frame should detect out-of-bounds and respawn.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var back_near_spawn := absf(player.global_position.y - spawn_y) < 2.0
	var vel_zeroed := player.velocity.length() < 1.0

	_assert(
		"respawn returns to spawn with zeroed velocity when below kill_y",
		back_near_spawn and vel_zeroed,
		"y=%.2f (spawn~%.2f), |vel|=%.3f" % [player.global_position.y, spawn_y, player.velocity.length()]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame
