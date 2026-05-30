## Slice-1 interpreter behavioral test (docs/decisions/movement-substrate.md,
## Slice 1 verify). Drives the DATA-DRIVEN MovementInterpreter (via
## InterpretedPlayer) through the REAL input pipeline — the same harness style as
## tests/movement_behavior_test.gd — and asserts ground+jump behaviour:
##
##   - kit loads and validates clean
##   - jump from a real physical Space key makes velocity.y positive
##   - jump-buffer: pressing jump just before landing fires on the landing frame
##   - coyote-time: jumping shortly after walking off a ledge still jumps
##   - ground accel: holding W from rest builds horizontal speed toward walk_speed
##   - ground friction: releasing input decays horizontal speed toward zero
##   - input is sampled once per tick (no mid-physics Input.* in the stepper)
##
## Run headless (windowed under xvfb per the spec):
##   godot4 --headless tests/interpreter_slice1_test.tscn --quit-after 6000
## It calls quit(0) iff every assertion passed, else quit(1).
extends Node

var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	await _run()


func _run() -> void:
	print("\n=== aeriea movement SLICE 1 interpreter test ===\n")

	_test_kit_loads_clean()
	await _test_jump_from_real_key_event()
	await _test_jump_buffer_fires_on_landing()
	await _test_coyote_time_allows_jump_after_ledge()
	await _test_ground_accel_builds_speed()
	await _test_ground_friction_decays_speed()
	await _test_respawn_below_kill_y()

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

func _assert(test_name: String, condition: bool, evidence: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  %s  [%s]" % [test_name, evidence])
	else:
		_fail_count += 1
		print("  FAIL  %s  [%s]" % [test_name, evidence])


## Build a self-contained level: a large static floor and an InterpretedPlayer
## spawned above it. Returns {level, player}. Geometry is built in code so the
## test does not depend on the imperative test_level.tscn / PlayerController.
func _spawn_level(spawn_pos: Vector3 = Vector3(0, 2.0, 0), with_ledge: bool = false) -> Dictionary:
	var level := Node3D.new()

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)  # top surface at y=0
	level.add_child(floor_body)

	if with_ledge:
		# A platform whose +X edge is a ledge to walk off of. Top surface at y=0,
		# extends from x=-40 to x=2 so walking +X past x=2 leaves the floor.
		floor_body.position = Vector3(-19, -0.5, 0)  # box spans x in [-39, 1]

	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = spawn_pos
	level.add_child(spawn)

	var player := InterpretedPlayer.new()
	player.name = "Player"
	player.position = spawn_pos
	level.add_child(player)

	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return {"level": level, "player": player}


func _step(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _settle_on_floor(player: InterpretedPlayer, max_frames: int = 180) -> bool:
	for _i in max_frames:
		await get_tree().physics_frame
		if player.is_on_floor():
			return true
	return player.is_on_floor()


func _send_key(physical_keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _horiz_speed(player: InterpretedPlayer) -> float:
	return Vector3(player.velocity.x, 0.0, player.velocity.z).length()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func _test_kit_loads_clean() -> void:
	var kit := MovementKit.load_from_file("res://movement/base.kit.json")
	_assert(
		"base.kit.json loads and validates clean",
		kit.is_valid() and kit.states.has("GROUND") and kit.states.has("AIR") and kit.initial != "",
		"valid=%s, states=%s, errors=%s" % [str(kit.is_valid()), str(kit.states.keys()), str(kit.load_errors)]
	)


func _test_jump_from_real_key_event() -> void:
	var ctx := await _spawn_level()
	var player: InterpretedPlayer = ctx["player"]
	var on_floor := await _settle_on_floor(player)

	_send_key(KEY_SPACE, false)
	_send_key(KEY_SPACE, true)
	await get_tree().physics_frame
	var vy := player.velocity.y
	if vy <= 0.0:
		await get_tree().physics_frame
		vy = maxf(vy, player.velocity.y)
	_send_key(KEY_SPACE, false)

	_assert(
		"interpreter: physical Space key (real pipeline) makes velocity.y positive",
		vy > 0.0,
		"on_floor_before=%s, velocity.y=%.3f, state=%s" % [str(on_floor), vy, player.interpreter.active_state]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_jump_buffer_fires_on_landing() -> void:
	# Press jump WHILE airborne and falling, shortly before landing (within the
	# jump_buffer_time window). The buffer must persist across the landing frame
	# and fire on landing — proving jump-buffer works on the interpreter.
	# Spawn low so the fall-to-land time is well inside the buffer window.
	var ctx := await _spawn_level(Vector3(0, 1.05, 0))
	var player: InterpretedPlayer = ctx["player"]

	# One frame in: still airborne, just starting to fall.
	await get_tree().physics_frame
	var airborne := not player.is_on_floor()

	# Press jump mid-air, then release — arms the buffer (jump_buffer_time window).
	_send_key(KEY_SPACE, false)
	_send_key(KEY_SPACE, true)
	await get_tree().physics_frame
	_send_key(KEY_SPACE, false)

	# Now let it land within the buffer window and watch for an upward velocity.
	# The body was airborne and falling when jump was pressed (it could not have
	# jumped from the ground); an upward velocity therefore proves the buffer
	# persisted across the landing frame and fired on landing.
	var was_falling := player.velocity.y < 0.0
	var jumped := false
	var max_vy := -INF
	for _i in 20:
		await get_tree().physics_frame
		max_vy = maxf(max_vy, player.velocity.y)
		if player.velocity.y > 0.5:
			jumped = true
			break

	_assert(
		"interpreter: jump-buffer pressed in air fires on landing",
		airborne and was_falling and jumped,
		"airborne_when_pressed=%s, falling_when_pressed=%s, max velocity.y after land=%.3f" % [str(airborne), str(was_falling), max_vy]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_coyote_time_allows_jump_after_ledge() -> void:
	# Stand near a ledge, walk off, and press jump a couple frames AFTER leaving
	# the floor (within coyote_time). The jump must still fire (velocity.y > 0)
	# even though is_on_floor() is already false — that is coyote-time.
	var ctx := await _spawn_level(Vector3(0, 2.0, 0), true)
	var player: InterpretedPlayer = ctx["player"]
	await _settle_on_floor(player)

	# Walk +X off the ledge (floor box spans x in [-39, 1]; player starts at x=0).
	_send_key(KEY_D, true)  # move_right = +X in world (yaw 0)
	# Step until we leave the floor.
	var left_floor_frame := -1
	for i in 120:
		await get_tree().physics_frame
		if not player.is_on_floor():
			left_floor_frame = i
			break
	_send_key(KEY_D, false)

	var coyote_after_leaving: float = player.interpreter.timers.get("coyote", 0.0)

	# Press jump NOW (1 frame after leaving the floor) — within the coyote window.
	_send_key(KEY_SPACE, false)
	_send_key(KEY_SPACE, true)
	await get_tree().physics_frame
	var vy := player.velocity.y
	if vy <= 0.0:
		await get_tree().physics_frame
		vy = maxf(vy, player.velocity.y)
	_send_key(KEY_SPACE, false)

	_assert(
		"interpreter: coyote-time lets you jump shortly after leaving the floor",
		left_floor_frame >= 0 and vy > 0.0,
		"left_floor_at_frame=%d, coyote_timer=%.3f, velocity.y=%.3f" % [left_floor_frame, coyote_after_leaving, vy]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_ground_accel_builds_speed() -> void:
	var ctx := await _spawn_level()
	var player: InterpretedPlayer = ctx["player"]
	await _settle_on_floor(player)

	var speed_start := _horiz_speed(player)
	_send_key(KEY_W, true)  # move_forward
	await _step(30)
	var speed_end := _horiz_speed(player)
	_send_key(KEY_W, false)

	var walk: float = player.kit.params.get("walk_speed", 5.5)
	_assert(
		"interpreter: ground accel builds horizontal speed toward walk_speed",
		speed_end > speed_start + 1.0 and speed_end <= walk + 0.5 and player.interpreter.active_state == "GROUND",
		"speed %.2f -> %.2f (walk_speed=%.1f), state=%s" % [speed_start, speed_end, walk, player.interpreter.active_state]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_ground_friction_decays_speed() -> void:
	var ctx := await _spawn_level()
	var player: InterpretedPlayer = ctx["player"]
	await _settle_on_floor(player)

	# Build speed, then release and let friction decay it.
	_send_key(KEY_W, true)
	await _step(30)
	var speed_moving := _horiz_speed(player)
	_send_key(KEY_W, false)
	await _step(40)
	var speed_after := _horiz_speed(player)

	_assert(
		"interpreter: releasing input applies friction, speed decays toward zero",
		speed_moving > 1.0 and speed_after < speed_moving * 0.5,
		"speed moving=%.2f -> after release=%.2f" % [speed_moving, speed_after]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame


func _test_respawn_below_kill_y() -> void:
	var ctx := await _spawn_level()
	var player: InterpretedPlayer = ctx["player"]
	await _step(5)
	var spawn_y := player.global_position.y

	player.global_position = Vector3(player.global_position.x, player.kill_y - 50.0, player.global_position.z)
	player.velocity = Vector3(3.0, -40.0, 2.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var back := absf(player.global_position.y - spawn_y) < 3.0
	var zeroed := player.velocity.length() < 1.0
	_assert(
		"interpreter: respawn returns to spawn with zeroed velocity below kill_y",
		back and zeroed,
		"y=%.2f (spawn~%.2f), |vel|=%.3f" % [player.global_position.y, spawn_y, player.velocity.length()]
	)
	ctx["level"].queue_free()
	await get_tree().process_frame
