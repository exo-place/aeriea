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

const TEST_LEVEL := "res://scenes/test_level.tscn"

var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	_run()


func _run() -> void:
	print("\n=== aeriea movement behavioral test ===\n")

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
	await _test_respawn_below_kill_y()

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

func _assert(test_name: String, condition: bool, evidence: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  %s  [%s]" % [test_name, evidence])
	else:
		_fail_count += 1
		print("  FAIL  %s  [%s]" % [test_name, evidence])


## Build a fresh level instance and return its PlayerController.
## Healing GameSettings to defaults first so tests are deterministic and
## independent of any persisted user config.
func _spawn_level() -> Dictionary:
	GameSettings.reset_all()  # deterministic, sane defaults
	var scene: PackedScene = load(TEST_LEVEL)
	var level: Node = scene.instantiate()
	add_child(level)
	# Let _ready run and a couple of physics frames settle the body on ground.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := level.get_node("Player") as PlayerController
	return {"level": level, "player": player}


func _step_physics(_player: PlayerController, frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


## Step physics until the player is on the floor (or a frame budget elapses).
## Returns true if grounded. Used so jump tests run from a known grounded state
## rather than guessing a frame count.
func _settle_on_floor(player: PlayerController, max_frames: int = 120) -> bool:
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
	var player: PlayerController = ctx["player"]

	var yaw_before := player.rotation.y
	# Drive the real look math directly. The controller only gates this on
	# Input.mouse_mode == CAPTURED, which headless cannot honour (the OS mouse
	# can't be captured without a window), so we exercise the extracted handler
	# that _input calls. The sensitivity it uses is the live GameSettings value.
	player._apply_look(Vector2(100.0, 0.0))
	var yaw_after := player.rotation.y
	var delta := absf(yaw_after - yaw_before)
	var expected := 100.0 * player.mouse_sensitivity

	_assert(
		"mouse motion rotates camera by nonzero amount at default sensitivity",
		delta > 0.0001 and is_equal_approx(delta, expected),
		"yaw delta=%.5f rad for 100px motion (expected=%.5f, sens=%.5f)" % [delta, expected, player.mouse_sensitivity]
	)

	# Also confirm the gating: while NOT captured, _input must not rotate.
	player._mouse_captured = false
	var yaw_pre_gate := player.rotation.y
	player._input(_make_motion(100.0, 0.0))
	var gated_ok := is_equal_approx(player.rotation.y, yaw_pre_gate)
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
	var player: PlayerController = ctx["player"]

	var on_floor := await _settle_on_floor(player)

	# Clean key state, then inject a real Space-down through the input pipeline.
	_send_key(KEY_SPACE, false)
	_send_key(KEY_SPACE, true)
	var buffered := player._jump_buffer_timer
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
	var player: PlayerController = ctx["player"]

	await _settle_on_floor(player)

	# Give the player forward speed above slide_min_speed so a crouch triggers
	# a slide (the controller's crouch behaviour). Hold W + sprint, then Ctrl.
	_send_key(KEY_W, true)
	_send_key(KEY_SHIFT, true)
	await _step_physics(player, 30)
	var speed_before := Vector3(player.velocity.x, 0.0, player.velocity.z).length()

	var stand_h := player._capsule.height
	_send_key(KEY_CTRL, true)
	await _step_physics(player, 8)
	var crouched := player._is_crouched
	var crouch_h := player._capsule.height
	var state := player._state
	_send_key(KEY_CTRL, false)
	_send_key(KEY_W, false)
	_send_key(KEY_SHIFT, false)

	_assert(
		"physical Ctrl key (real input pipeline) engages crouch/slide",
		crouched and crouch_h < stand_h and state == PlayerController.State.SLIDE,
		"speed_before=%.2f, crouched=%s, capsule h %.2f->%.2f, state=%d (SLIDE=%d)" % [speed_before, str(crouched), stand_h, crouch_h, state, PlayerController.State.SLIDE]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_jump_after_pause_unpause() -> void:
	var ctx := await _spawn_level()
	var player: PlayerController = ctx["player"]
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
	var player: PlayerController = ctx["player"]

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
	var player: PlayerController = ctx["player"]

	await _step_physics(player, 10)

	# Press crouch (Ctrl) and step. The player must NOT enter WALL_RUN state
	# merely from pressing crouch on flat ground. Drive via the real pipeline.
	_send_key(KEY_CTRL, true)
	await _step_physics(player, 20)
	var state: int = player._state
	_send_key(KEY_CTRL, false)

	_assert(
		"crouch/Ctrl does NOT trigger wall-run",
		state != PlayerController.State.WALL_RUN,
		"state after crouch=%d (WALL_RUN=%d)" % [state, PlayerController.State.WALL_RUN]
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
# Item 4 — respawn / out-of-bounds recovery
# ---------------------------------------------------------------------------

func _test_respawn_below_kill_y() -> void:
	var ctx := await _spawn_level()
	var player: PlayerController = ctx["player"]

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
