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
	await _test_crouch_from_real_key_event()
	await _test_jump_after_pause_unpause()
	await _test_crouch_no_vertical_jitter()
	await _test_wallrun_not_triggered_by_crouch()
	await _test_crouch_action_maps_to_crouch_only()
	await _test_low_speed_crouch_is_crouchwalk_not_slide()
	await _test_high_speed_crouch_is_slide()
	await _test_slide_is_steerable_and_cancelable()
	await _test_bullet_jump_forward_up_burst()
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

	# Step frames — wall-run auto-detect fires when airborne + fast + wall close.
	# Give up to 20 frames for the detection to engage.
	var entered := false
	for _i in 20:
		await get_tree().physics_frame
		if player._state == S_WALL_RUN:
			entered = true
			break

	if not entered:
		# Fallback: force wall-run state with real geometry.
		# This keeps _is_wall_nearby() happy by placing the player flush to the wall.
		player.global_position = Vector3(2.6, 2.0, 6.0)
		player._yaw = 0.0
		player.rotation.y = 0.0
		player.velocity = Vector3(0.0, 0.5, player.wall_run_speed)
		player._wall_normal = Vector3(-1, 0, 0)
		player._wall_run_side = 1.0
		player._wall_run_timer = player.wall_run_max_time
		player._transition(S_WALL_RUN)
		await get_tree().physics_frame
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
