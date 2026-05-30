## PlayerController — parkour-2.0 first-person character controller.
##
## Design intent (from DESIGN.md):
##   - Momentum-preserving, fluid, compositional — carving and flow, not stop-start.
##   - Hollow Knight verb model: small clean primitives, depth in chains.
##   - Redout 2 carving feel: every input modifies every other; velocity preserved across inputs.
##   - Mirror's Edge / Ghostrunner / Dying Light parkour lineage.
##
## State machine verbs: GROUND, AIR, SLIDE, WALL_RUN, WALL_JUMP_GRACE, CLIMB
##
## All @export constants are tunable in the editor without touching this file.
## Runtime overrides (mouse_sensitivity, dynamic FOV) are read from the
## GameSettings autoload so they survive restart.
## coyote_time and jump_buffer_time are designer-tuning @export vars only —
## they are not player-facing and are not read from GameSettings.

class_name PlayerController
extends CharacterBody3D

# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
## Degrees clamped for pitch
@export var pitch_min: float = -89.0
@export var pitch_max: float = 89.0
@export var camera_height_stand: float = 0.85
@export var camera_height_crouch: float = 0.55
## How fast camera lerps to target height
@export var camera_height_lerp_speed: float = 12.0
## FOV during normal movement
@export var fov_base: float = 90.0
## Additional FOV added at full sprint speed
@export var fov_sprint_bonus: float = 10.0
## Additional FOV during wall-run
@export var fov_wall_run_bonus: float = 5.0
## How fast FOV lerps to target
@export var fov_lerp_speed: float = 6.0
## How much the camera rolls during wall-run (degrees)
@export var wall_run_camera_tilt: float = 8.0
## How fast camera roll lerps
@export var camera_roll_lerp_speed: float = 10.0

# ---------------------------------------------------------------------------
# Ground movement
# ---------------------------------------------------------------------------

@export_group("Ground Movement")
## Top speed walking (m/s)
@export var walk_speed: float = 5.5
## Top speed sprinting (m/s)
@export var sprint_speed: float = 10.0
## Acceleration applied toward desired direction (m/s²)
@export var ground_acceleration: float = 60.0
## Friction deceleration when no input (m/s²)
@export var ground_friction: float = 30.0
## Extra friction when actively braking (input opposite to velocity)
@export var ground_brake_friction: float = 60.0
## Slope limit (degrees). Above this, player slides down.
@export var max_slope_angle: float = 45.0

# ---------------------------------------------------------------------------
# Air movement
# ---------------------------------------------------------------------------

@export_group("Air Movement")
## Air-strafing acceleration — lower than ground for feel
@export var air_acceleration: float = 20.0
## Cap on air-strafe speed boost above launch speed
@export var air_speed_cap: float = 12.0
## Gravity scale (applied on top of project gravity)
@export var gravity_scale: float = 2.2
## Gravity scale while holding jump (floaty apex)
@export var jump_hold_gravity_scale: float = 1.2
## Minimum time jump is held before full gravity resumes (seconds)
@export var jump_hold_max_time: float = 0.25

# ---------------------------------------------------------------------------
# Jump
# ---------------------------------------------------------------------------

@export_group("Jump")
## Jump impulse velocity (m/s)
@export var jump_velocity: float = 9.5
## Coyote time window (seconds) — allows jumping slightly after leaving ground.
## Designer-tunable in the editor; not exposed to players.
@export var coyote_time: float = 0.12
## Jump buffer window (seconds) — allows pre-pressing jump before landing.
## Designer-tunable in the editor; not exposed to players.
@export var jump_buffer_time: float = 0.15

# ---------------------------------------------------------------------------
# Slide
# ---------------------------------------------------------------------------

@export_group("Slide / Crouch")
## Horizontal speed at/above which pressing crouch enters a SLIDE (m/s).
## Below this, pressing crouch enters CROUCH-WALK instead. Tuned near run speed
## so a slide is a deliberate "crouch while running" rather than any crouch.
@export var slide_entry_speed: float = 8.0
## Speed impulse added when initiating a slide (m/s, along current velocity)
@export var slide_boost: float = 3.0
## Friction during slide (m/s²) — low to preserve momentum
@export var slide_friction: float = 4.0
## Speed below which slide automatically ends (bleeds into crouch-walk/run)
@export var slide_exit_speed: float = 3.0
## Maximum slide duration (seconds) — prevents infinite slides
@export var slide_max_time: float = 1.8
## How strongly wish-direction input steers/carves the slide (m/s²). Lower than
## ground accel so the slide stays momentum-led, but clearly responsive.
@export var slide_steer_accel: float = 16.0
## Sustained wish-input alignment (dot of input vs velocity, 0..1) held for
## slide_steer_exit_time that bleeds the slide out into running. Pushing into
## your motion "stands you up" smoothly.
@export var slide_steer_exit_time: float = 0.18
## Speed multiplier gained per unit of downward slope angle during slide
@export var slope_acceleration: float = 18.0
## Hard cap on horizontal speed while sliding (m/s).
## Prevents slope-accel and re-entry boost from compounding unboundedly.
@export var max_slide_speed: float = 22.0
## Top speed while crouch-walking (m/s) — reduced from walk_speed.
@export var crouch_walk_speed: float = 2.8
## Collision capsule half-height when crouched
@export var crouch_height: float = 0.6
## Collision capsule half-height when standing
@export var stand_height: float = 0.9

# ---------------------------------------------------------------------------
# Wall run
# ---------------------------------------------------------------------------

@export_group("Wall Run")
## Minimum horizontal speed to trigger wall-run (m/s)
@export var wall_run_min_speed: float = 5.0
## Max time before gravity starts pulling player off wall (seconds)
@export var wall_run_max_time: float = 1.4
## Gravity scale while wall-running (low — nearly zero at start, ramps up)
@export var wall_run_gravity_scale: float = 0.15
## Wall-run gravity ramp: how quickly gravity grows toward full as time passes
@export var wall_run_gravity_ramp: float = 1.8
## Detection raycast length for wall proximity (m)
@export var wall_detect_distance: float = 0.65
## Upward velocity added when initiating a wall-run
@export var wall_run_vertical_boost: float = 1.5
## Horizontal speed along wall maintained during wall-run
@export var wall_run_speed: float = 9.0
## Wall-jump lateral impulse (away from wall, m/s)
@export var wall_jump_lateral: float = 6.5
## Wall-jump upward impulse (m/s)
@export var wall_jump_up: float = 8.0
## Grace period after leaving wall where wall-jump is still possible (seconds)
@export var wall_jump_grace: float = 0.12

# ---------------------------------------------------------------------------
# Respawn / out-of-bounds recovery
# ---------------------------------------------------------------------------

@export_group("Respawn")
## Y position below which the player is considered out of bounds and respawned.
@export var kill_y: float = -25.0
## Optional explicit spawn point. If left empty, the player's start transform
## (captured in _ready) is used as the spawn.
@export var spawn_path: NodePath

# ---------------------------------------------------------------------------
# Vault / mantle / ledge climb
# ---------------------------------------------------------------------------

@export_group("Vault and Climb")
## Horizontal distance at which ledge detection rays are cast (m, forward from player)
@export var vault_detect_forward: float = 0.9
## Height of the upper ledge-check ray from ground (m)
@export var vault_ledge_ray_high: float = 1.8
## Height of the lower clearance-check ray from ground (m)
@export var vault_ledge_ray_low: float = 1.1
## Minimum approach speed to trigger vault (m/s)
@export var vault_min_speed: float = 2.5
## Duration of vault animation tween (seconds)
@export var vault_duration: float = 0.28
## Duration of mantle/climb animation tween (seconds)
@export var mantle_duration: float = 0.45
## How far above the ledge the player ends up (m)
@export var vault_overshoot: float = 0.6

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

enum State {
	GROUND,
	AIR,
	SLIDE,
	CROUCH,
	WALL_RUN,
	VAULT,
}

var _state: State = State.AIR
var _camera_pivot: Node3D
var _camera: Camera3D
var _collision_shape: CollisionShape3D
var _capsule: CapsuleShape3D

## Current yaw (horizontal look, radians)
var _yaw: float = 0.0
## Current pitch (vertical look, radians)
var _pitch: float = 0.0

## Timers
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_hold_timer: float = 0.0
var _wall_run_timer: float = 0.0
var _wall_jump_grace_timer: float = 0.0
var _slide_timer: float = 0.0
var _vault_timer: float = 0.0
## Accumulated time the player has pushed wish-input forward into the slide —
## when it crosses slide_steer_exit_time the slide bleeds out into running.
var _slide_steer_timer: float = 0.0

## Wall run state
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_run_side: float = 0.0  # +1 = right wall, -1 = left wall

## Whether player is currently holding jump (for floaty apex)
var _jump_held: bool = false

## Whether mouse is currently captured — synced from Input.mouse_mode.
var _mouse_captured: bool = true

## Vault state
var _vault_start: Vector3 = Vector3.ZERO
var _vault_end: Vector3 = Vector3.ZERO
var _is_vaulting: bool = false

## Reference gravity (project setting)
var _gravity: float = 0.0

## Spawn transform captured at _ready (or from spawn_path if set), used by
## the out-of-bounds respawn system.
var _spawn_transform: Transform3D = Transform3D.IDENTITY

## Whether collider is currently in crouch shape (avoids redundant resize).
var _is_crouched: bool = false

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------

func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	# Capture the spawn transform for out-of-bounds respawn. Prefer an explicit
	# spawn node if one was assigned; otherwise use the player's start position.
	_spawn_transform = global_transform
	if not spawn_path.is_empty():
		var spawn_node := get_node_or_null(spawn_path)
		if spawn_node is Node3D:
			_spawn_transform = (spawn_node as Node3D).global_transform

	# Build scene tree: CameraPivot child → Camera child
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	add_child(_camera_pivot)
	_camera_pivot.position.y = camera_height_stand

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = fov_base
	_camera_pivot.add_child(_camera)

	# Collision capsule — centred at the body origin.
	# CapsuleShape3D is centred, so half-height above/below origin = stand_height.
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = stand_height * 2.0
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = _capsule
	# Keep the CollisionShape at the body origin (y=0); we shift the body itself
	# when crouching to keep feet planted — see _set_crouch_shape.
	_collision_shape.position = Vector3.ZERO
	add_child(_collision_shape)

	# Floor handling: hold position on standable slopes (no involuntary slide).
	# floor_max_angle 45° keeps the ~15° test slope standable; stop_on_slope
	# cancels gravity-induced downhill drift while grounded. floor_snap_length
	# keeps the body glued across slope seams so the collider doesn't pop.
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = 0.5

	# Pull runtime-overridable settings from GameSettings autoload.
	_apply_game_settings()
	GameSettings.settings_changed.connect(_apply_game_settings)

	# Capture mouse on start
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Apply a relative mouse-motion delta to yaw/pitch using the current
## sensitivity. Separated from input gating so it is unit-testable headlessly
## (where the OS mouse cannot actually be captured).
func _apply_look(relative: Vector2) -> void:
	_yaw -= relative.x * mouse_sensitivity
	_pitch -= relative.y * mouse_sensitivity
	_pitch = clamp(_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	rotation.y = _yaw
	_camera_pivot.rotation.x = _pitch


func _apply_game_settings() -> void:
	mouse_sensitivity = GameSettings.mouse_sensitivity


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Sync captured flag from actual mouse mode (pause menu owns this state).
	_mouse_captured = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	# Mouse look — only while captured.
	if _mouse_captured and event is InputEventMouseMotion:
		_apply_look((event as InputEventMouseMotion).relative)

	# Click-to-recapture: when unpaused and mouse is freed, a left-click
	# inside the viewport recaptures. We check get_tree().paused to avoid
	# stealing clicks from active menu buttons.
	if not _mouse_captured and not get_tree().paused:
		if event is InputEventMouseButton:
			var mev := event as InputEventMouseButton
			if mev.pressed and mev.button_index == MOUSE_BUTTON_LEFT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true
				get_viewport().set_input_as_handled()
				return

	# Jump buffer — process regardless of mouse-capture state so the
	# buffer fires on first click-to-refocus too.
	# Guard: only when gameplay is actually running (not paused).
	if not get_tree().paused:
		if event.is_action_pressed("jump"):
			_jump_buffer_timer = jump_buffer_time
			_jump_held = true
		if event.is_action_released("jump"):
			_jump_held = false


# ---------------------------------------------------------------------------
# Physics process
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# Out-of-bounds recovery: if the player has fallen below the kill plane,
	# teleport back to spawn with zeroed velocity before doing anything else.
	if global_position.y < kill_y:
		respawn()
		return

	_tick_timers(delta)

	match _state:
		State.GROUND:
			_process_ground(delta)
		State.AIR:
			_process_air(delta)
		State.SLIDE:
			_process_slide(delta)
		State.CROUCH:
			_process_crouch(delta)
		State.WALL_RUN:
			_process_wall_run(delta)
		State.VAULT:
			_process_vault(delta)

	_update_camera(delta)


# ---------------------------------------------------------------------------
# Timer ticks
# ---------------------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	_coyote_timer = max(0.0, _coyote_timer - delta)
	_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)
	_wall_run_timer = max(0.0, _wall_run_timer - delta)
	_wall_jump_grace_timer = max(0.0, _wall_jump_grace_timer - delta)
	_slide_timer = max(0.0, _slide_timer - delta)
	_vault_timer = max(0.0, _vault_timer - delta)
	if _jump_held:
		_jump_hold_timer += delta
	else:
		_jump_hold_timer = 0.0


# ---------------------------------------------------------------------------
# State: GROUND
# ---------------------------------------------------------------------------

func _process_ground(delta: float) -> void:
	var wish_dir := _get_wish_dir()
	var is_sprinting := Input.is_action_pressed("sprint")
	var is_crouching := Input.is_action_pressed("crouch")
	var top_speed := sprint_speed if is_sprinting else walk_speed

	# Apply gravity to stick to slopes (small downward push)
	if not is_on_floor():
		# Left the ground — start coyote timer and transition to air
		_coyote_timer = coyote_time
		_transition(State.AIR)
		_process_air(delta)
		return

	# Horizontal velocity — project onto floor plane
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horiz_vel.length()

	if wish_dir.length_squared() > 0.001:
		# Accelerate toward wish direction
		var target_vel := wish_dir * top_speed
		var accel := ground_acceleration * delta
		horiz_vel = horiz_vel.move_toward(target_vel, accel)
	else:
		# Friction / decelerate
		var friction := ground_friction
		horiz_vel = horiz_vel.move_toward(Vector3.ZERO, friction * delta)

	# NOTE: no involuntary downhill push here. On a standable slope the body
	# must HOLD POSITION; floor_stop_on_slope + floor_max_angle do that for us.
	# Downhill acceleration is a deliberate SLIDE behaviour only (see _process_slide).

	velocity.x = horiz_vel.x
	velocity.z = horiz_vel.z
	velocity.y = -0.5  # small downward bias keeps the body snapped to the floor

	# Vault check — moving forward with sufficient speed toward a climbable ledge
	if speed > vault_min_speed and _check_vault():
		return

	# Crouch trigger — branch on horizontal speed.
	#   fast  → SLIDE (deliberate slide while running)
	#   slow  → CROUCH-WALK (lowered, slower, fully steerable)
	if is_crouching:
		if speed >= slide_entry_speed:
			_begin_slide()
		else:
			_begin_crouch()
		return

	# Jump
	if _jump_buffer_timer > 0.0:
		_do_jump()
		return

	move_and_slide()


# ---------------------------------------------------------------------------
# State: AIR
# ---------------------------------------------------------------------------

func _process_air(delta: float) -> void:
	# Gravity — floaty at apex when jump held
	var grav := _gravity * gravity_scale
	if _jump_held and _jump_hold_timer < jump_hold_max_time and velocity.y > 0.0:
		grav = _gravity * jump_hold_gravity_scale

	velocity.y -= grav * delta

	# Air strafe
	var wish_dir := _get_wish_dir()
	if wish_dir.length_squared() > 0.001:
		var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
		var current_speed_in_wish: float = horiz_vel.dot(wish_dir)
		var add_speed: float = minf(air_speed_cap - current_speed_in_wish, air_acceleration * delta)
		if add_speed > 0.0:
			horiz_vel += wish_dir * add_speed
		velocity.x = horiz_vel.x
		velocity.z = horiz_vel.z

	# Coyote jump
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_do_jump()
		_coyote_timer = 0.0
		return

	# Wall-jump (grace window)
	if _jump_buffer_timer > 0.0 and _wall_jump_grace_timer > 0.0:
		_do_wall_jump()
		return

	# Check for wall-run entry
	if _check_wall_run():
		return

	# Vault check in air (approaching a ledge)
	var horiz_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if horiz_speed > vault_min_speed and _check_vault():
		return

	# Landing — transition and immediately run ground logic this frame so a
	# buffered jump (or slide) fires on the landing frame instead of being
	# delayed/eaten. Mirrors how GROUND re-runs air logic when it leaves the floor.
	if is_on_floor():
		_transition(State.GROUND)
		_process_ground(delta)
		return

	move_and_slide()


# ---------------------------------------------------------------------------
# State: SLIDE
# ---------------------------------------------------------------------------

func _process_slide(delta: float) -> void:
	if not is_on_floor():
		# Airborne mid-slide: leave the slide but stay crouched until we land
		# (don't pop up in the air). Standing-up is re-evaluated on the ground.
		_transition(State.AIR)
		_process_air(delta)
		return

	# Slide-jump — highest-priority exit; preserves momentum + forward boost.
	if _jump_buffer_timer > 0.0:
		_end_slide()
		_do_jump()
		var forward := -transform.basis.z
		velocity.x += forward.x * 2.5
		velocity.z += forward.z * 2.5
		return

	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)

	# Slope acceleration — sliding downhill speeds up, but this is NOT a lock:
	# all the exit conditions below still fire, so it can never be perpetual.
	# NOTE: gravity-driven downhill movement on slopes is intentional (user-confirmed
	# expected behaviour). We only cap the total speed, not the direction.
	var floor_normal := get_floor_normal()
	var slope_angle := rad_to_deg(acos(clampf(floor_normal.dot(Vector3.UP), -1.0, 1.0)))
	if slope_angle > 2.0:
		var down_slope := Vector3(floor_normal.x, 0.0, floor_normal.z).normalized()
		horiz_vel += down_slope * slope_acceleration * (slope_angle / 45.0) * delta
	# Hard cap: slope acceleration may not push speed past max_slide_speed.
	horiz_vel = horiz_vel.limit_length(max_slide_speed)

	# STEERABLE: wish-direction carves the slide. We steer the velocity vector
	# toward the wish direction at slide_steer_accel without forcing a target
	# speed, so momentum leads but the player clearly redirects the slide.
	# The re-normalise to speed_now preserves magnitude (carve, don't accelerate).
	var wish_dir := _get_wish_dir()
	var has_input := wish_dir.length_squared() > 0.001
	if has_input:
		var speed_now := horiz_vel.length()
		var steered := horiz_vel + wish_dir * slide_steer_accel * delta
		# Carve: redirect without inflating speed.
		if steered.length() > 0.001:
			horiz_vel = steered.normalized() * speed_now

	# Slide friction
	horiz_vel = horiz_vel.move_toward(Vector3.ZERO, slide_friction * delta)
	velocity.x = horiz_vel.x
	velocity.z = horiz_vel.z
	velocity.y = -0.5

	var speed := horiz_vel.length()

	# SUSTAINED-INPUT EXIT: pushing into your direction of motion for a short
	# window bleeds the slide out into normal locomotion (seamless stand-up).
	if has_input and speed > 0.001 and wish_dir.dot(horiz_vel.normalized()) > 0.5:
		_slide_steer_timer += delta
	else:
		_slide_steer_timer = max(0.0, _slide_steer_timer - delta)

	# EXIT CONDITIONS — any of: crouch released, speed decayed, timer expired,
	# or sustained forward input. All bleed momentum (no abrupt stop): we hand
	# the current velocity to GROUND or CROUCH-WALK, which carry it forward.
	var is_crouching := Input.is_action_pressed("crouch")
	var steered_out := _slide_steer_timer >= slide_steer_exit_time
	if not is_crouching or speed < slide_exit_speed or _slide_timer <= 0.0 or steered_out:
		_slide_steer_timer = 0.0
		# If crouch is still held and there's no headroom, fall through to
		# crouch-walk (stay low); otherwise stand and run.
		if is_crouching:
			_transition(State.CROUCH)  # stays crouched; velocity preserved
		else:
			_end_slide()  # stands up if headroom
			_transition(State.GROUND)
		return

	move_and_slide()


# ---------------------------------------------------------------------------
# State: CROUCH (crouch-walk) — lowered, slower, FULLY steerable like walking.
# ---------------------------------------------------------------------------

func _process_crouch(delta: float) -> void:
	if not is_on_floor():
		_coyote_timer = coyote_time
		_transition(State.AIR)
		_process_air(delta)
		return

	# Crouch released → try to stand and return to GROUND (headroom-checked).
	if not Input.is_action_pressed("crouch"):
		_end_slide()  # stands up only if there's headroom
		# Whether or not we could stand, hand momentum back to GROUND. If blocked,
		# _is_crouched stays true and the body remains low until headroom opens.
		_transition(State.GROUND)
		_process_ground(delta)
		return

	# Ensure crouched collider engaged (no-op if already crouched → no jitter).
	if not _is_crouched:
		_set_crouch_shape(true)

	var wish_dir := _get_wish_dir()
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)

	# FULLY steerable: wish-direction fully applies, just at a reduced top speed.
	if wish_dir.length_squared() > 0.001:
		var target_vel := wish_dir * crouch_walk_speed
		horiz_vel = horiz_vel.move_toward(target_vel, ground_acceleration * delta)
		# If still fast enough (e.g. arrived here from a slide), let it become a
		# slide again when the player is clearly running.
		if horiz_vel.length() >= slide_entry_speed:
			_begin_slide()
			return
	else:
		horiz_vel = horiz_vel.move_toward(Vector3.ZERO, ground_friction * delta)

	velocity.x = horiz_vel.x
	velocity.z = horiz_vel.z
	velocity.y = -0.5

	# Crouch-jump: stand (if headroom) and jump.
	if _jump_buffer_timer > 0.0 and _can_stand():
		_set_crouch_shape(false)
		_do_jump()
		return

	move_and_slide()


# ---------------------------------------------------------------------------
# State: WALL_RUN
# ---------------------------------------------------------------------------

func _process_wall_run(delta: float) -> void:
	# Check if wall is still there
	if not _is_wall_nearby():
		_exit_wall_run()
		return

	# Time limit reached — start falling off wall
	if _wall_run_timer <= 0.0:
		_exit_wall_run()
		return

	# If player moves away from wall or jumps
	if _jump_buffer_timer > 0.0:
		_do_wall_jump()
		return

	if not Input.is_action_pressed("move_forward") and \
	   not Input.is_action_pressed("move_left") and \
	   not Input.is_action_pressed("move_right") and \
	   not Input.is_action_pressed("move_backward"):
		_exit_wall_run()
		return

	# Gravity ramps up over wall-run duration
	var time_fraction := 1.0 - (_wall_run_timer / wall_run_max_time)
	var effective_grav_scale := wall_run_gravity_scale + (1.0 - wall_run_gravity_scale) * pow(time_fraction, wall_run_gravity_ramp)
	velocity.y -= _gravity * effective_grav_scale * delta
	velocity.y = max(velocity.y, -_gravity)  # clamp fall speed on wall

	# Move along wall surface.
	# The wall-tangent vector is derived from the wall normal × UP, then oriented
	# so that positive = the direction the camera is mostly facing.
	# Intended behaviour: forward input runs along the wall (full speed), backward
	# input decelerates/reverses (so pressing S does NOT push you forward along
	# the wall), and lateral input is ignored (player is locked to the wall plane).
	# No input: maintain speed (wall-run is not purely self-propelled — momentum
	# carries you, and the exit condition above already handles "no input" bail).
	var along_wall := _wall_normal.cross(Vector3.UP).normalized()
	if along_wall.dot(-transform.basis.z) < 0.0:
		along_wall = -along_wall

	# Read longitudinal (forward/back) input along the wall tangent.
	# Lateral keys (A/D) are intentionally ignored: sideways input on a wall is
	# ambiguous and the exit-on-no-input guard above already handles stepping off.
	var fwd_input := 0.0
	if Input.is_action_pressed("move_forward"):
		fwd_input += 1.0
	if Input.is_action_pressed("move_backward"):
		fwd_input -= 1.0

	# Project current wall-tangent speed, then apply input as a target.
	# Forward → run at wall_run_speed; backward → decelerate (target = 0 or negative);
	# no longitudinal input → hold current speed (momentum-preserving).
	var current_along := Vector3(velocity.x, 0.0, velocity.z).dot(along_wall)
	# REWORKED FEEL (issue #2): forward input SUSTAINS along-wall momentum (capped at
	# wall_run_speed), not a forced shove to a fixed speed; backward decelerates to 0;
	# no input carries momentum. wall_run_speed is a CAP. Matches the data kit /
	# interpreter so the oracle stays a faithful parity reference.
	var target_along: float
	if fwd_input > 0.0:
		target_along = clampf(current_along, 0.0, wall_run_speed)
	elif fwd_input < 0.0:
		# Backward decelerates toward zero; does NOT accelerate you forward.
		target_along = 0.0
	else:
		target_along = current_along  # no change — preserve momentum
	if current_along > wall_run_speed:
		target_along = wall_run_speed

	# Move toward target at a responsive-but-not-instant rate.
	var new_along := move_toward(current_along, target_along, wall_run_speed * 6.0 * delta)
	velocity.x = along_wall.x * new_along
	velocity.z = along_wall.z * new_along

	move_and_slide()

	# Re-check after move (wall may have ended)
	if is_on_floor():
		_exit_wall_run_land()


# ---------------------------------------------------------------------------
# State: VAULT
# ---------------------------------------------------------------------------

func _process_vault(delta: float) -> void:
	if not _is_vaulting:
		_transition(State.AIR)
		return

	var progress := 1.0 - (_vault_timer / vault_duration)
	if _vault_timer <= 0.0:
		global_position = _vault_end
		_is_vaulting = false
		velocity = Vector3.ZERO
		_transition(State.GROUND)
		return

	global_position = _vault_start.lerp(_vault_end, progress)
	move_and_slide()


# ---------------------------------------------------------------------------
# Jump helpers
# ---------------------------------------------------------------------------

func _do_jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_jump_hold_timer = 0.0
	_transition(State.AIR)


func _do_wall_jump() -> void:
	if _wall_normal == Vector3.ZERO:
		_do_jump()
		return

	var lateral := _wall_normal * wall_jump_lateral
	velocity.x = lateral.x
	velocity.z = lateral.z
	velocity.y = wall_jump_up
	_wall_normal = Vector3.ZERO
	_wall_jump_grace_timer = 0.0
	_jump_buffer_timer = 0.0
	_transition(State.AIR)


# ---------------------------------------------------------------------------
# Slide helpers
# ---------------------------------------------------------------------------

func _begin_slide() -> void:
	# Entry boost: applied only when not already in SLIDE state, so re-entering
	# from CROUCH (or any other state that calls _begin_slide while already sliding)
	# does not stack the boost on top of existing slide speed.
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.length_squared() > 0.001 and _state != State.SLIDE:
		var boosted := horiz.length() + slide_boost
		# Clamp the boosted entry speed so we never launch above max_slide_speed.
		boosted = minf(boosted, max_slide_speed)
		velocity.x = horiz.normalized().x * boosted
		velocity.z = horiz.normalized().z * boosted
	_slide_timer = slide_max_time
	_slide_steer_timer = 0.0
	_set_crouch_shape(true)
	_transition(State.SLIDE)


## Enter crouch-walk (low-speed crouch). Lowers the collider; momentum preserved.
func _begin_crouch() -> void:
	_set_crouch_shape(true)
	_transition(State.CROUCH)


func _end_slide() -> void:
	# Check if there's headroom to stand — if not, stay crouched
	if _can_stand():
		_set_crouch_shape(false)


func _set_crouch_shape(crouching: bool) -> void:
	if _is_crouched == crouching:
		return  # No change — avoid redundant resize that can cause jitter.

	var old_height := _capsule.height  # full capsule height before change
	var new_half := crouch_height if crouching else stand_height
	var new_height := new_half * 2.0

	# The capsule is centred on the body origin, so its bottom (the feet) sits
	# half the height below the origin. When the capsule shrinks by `shrink`,
	# the feet would rise by shrink/2 unless we move the origin DOWN by the same
	# amount. When it grows, the origin must move UP so we don't clip the floor.
	#   shrink = old_height - new_height  (positive when crouching down)
	#   feet stay planted ⇔ origin.y -= shrink / 2
	var shrink := old_height - new_height
	_capsule.height = new_height
	global_position.y -= shrink * 0.5

	_is_crouched = crouching


func _can_stand() -> bool:
	# Ray cast upward to check for headroom
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.UP * (stand_height * 2.0 + 0.1),
		collision_mask
	)
	params.exclude = [self]
	var result: Dictionary = space.intersect_ray(params)
	return result.is_empty()


# ---------------------------------------------------------------------------
# Wall run helpers
# ---------------------------------------------------------------------------

func _check_wall_run() -> bool:
	var horiz_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if horiz_speed < wall_run_min_speed:
		return false
	if is_on_floor():
		return false

	# Cast rays left and right to detect walls
	var right: Vector3 = transform.basis.x
	var left: Vector3 = -right

	var sides: Array[Vector3] = [right, left]
	for side_vec: Vector3 in sides:
		var from: Vector3 = global_position
		var to: Vector3 = from + side_vec * wall_detect_distance
		var space := get_world_3d().direct_space_state
		var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
		params.exclude = [self]
		var result: Dictionary = space.intersect_ray(params)
		if not result.is_empty():
			var normal: Vector3 = result["normal"]
			# Wall must be roughly vertical
			if abs(normal.y) < 0.3:
				_wall_normal = normal
				_wall_run_side = 1.0 if side_vec == right else -1.0
				velocity.y = max(velocity.y, wall_run_vertical_boost)
				_wall_run_timer = wall_run_max_time
				_transition(State.WALL_RUN)
				return true

	return false


func _is_wall_nearby() -> bool:
	var side_vec: Vector3 = transform.basis.x * _wall_run_side
	var from: Vector3 = global_position
	var to: Vector3 = from + side_vec * (wall_detect_distance + 0.15)
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	params.exclude = [self]
	var result: Dictionary = space.intersect_ray(params)
	if not result.is_empty():
		var normal: Vector3 = result["normal"]
		_wall_normal = normal
		return abs(normal.y) < 0.3
	return false


func _exit_wall_run() -> void:
	_wall_jump_grace_timer = wall_jump_grace
	_wall_run_timer = 0.0
	_transition(State.AIR)


func _exit_wall_run_land() -> void:
	_wall_normal = Vector3.ZERO
	_wall_run_timer = 0.0
	_transition(State.GROUND)


# ---------------------------------------------------------------------------
# Vault helpers
# ---------------------------------------------------------------------------

func _check_vault() -> bool:
	var forward := -transform.basis.z
	var space := get_world_3d().direct_space_state

	# High ray: checks for obstacle at ledge height
	var high_from: Vector3 = global_position + Vector3.UP * vault_ledge_ray_high
	var high_to: Vector3 = high_from + forward * vault_detect_forward
	var params_high := PhysicsRayQueryParameters3D.create(high_from, high_to, collision_mask)
	params_high.exclude = [self]
	var high_hit: Dictionary = space.intersect_ray(params_high)

	# Low ray: checks for obstacle below — if clear, there's a ledge to vault
	var low_from: Vector3 = global_position + Vector3.UP * vault_ledge_ray_low
	var low_to: Vector3 = low_from + forward * vault_detect_forward
	var params_low := PhysicsRayQueryParameters3D.create(low_from, low_to, collision_mask)
	params_low.exclude = [self]
	var low_hit: Dictionary = space.intersect_ray(params_low)

	# Vault: low ray hits wall but high ray is clear — there's a climbable ledge
	if low_hit and not high_hit:
		# Find the top of the obstacle via downward ray from above
		var low_pos: Vector3 = low_hit["position"]
		var top_check_from: Vector3 = low_pos + Vector3.UP * 1.2 + forward * 0.3
		var top_check_to: Vector3 = top_check_from + Vector3.DOWN * 2.0
		var params_top := PhysicsRayQueryParameters3D.create(top_check_from, top_check_to, collision_mask)
		params_top.exclude = [self]
		var top_hit: Dictionary = space.intersect_ray(params_top)
		if not top_hit.is_empty():
			var ledge_top: Vector3 = top_hit["position"]
			var vault_height: float = ledge_top.y - global_position.y
			# Only vault if ledge is in a reasonable height range
			if vault_height >= -0.3 and vault_height <= 1.6:
				_start_vault(ledge_top + forward * vault_overshoot)
				return true

	return false


func _start_vault(target: Vector3) -> void:
	_vault_start = global_position
	_vault_end = target + Vector3.UP * stand_height
	_vault_timer = vault_duration
	_is_vaulting = true
	velocity = Vector3.ZERO
	_transition(State.VAULT)


# ---------------------------------------------------------------------------
# Wish direction (input → world-space movement direction)
# ---------------------------------------------------------------------------

func _get_wish_dir() -> Vector3:
	var input := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input.y -= 1.0
	if Input.is_action_pressed("move_backward"):
		input.y += 1.0
	if Input.is_action_pressed("move_left"):
		input.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input.x += 1.0
	if input.length_squared() < 0.001:
		return Vector3.ZERO

	input = input.normalized()
	# Transform to world horizontal plane using player yaw only (not pitch)
	var basis_y := Basis(Vector3.UP, _yaw)
	return basis_y * Vector3(input.x, 0.0, input.y)


# ---------------------------------------------------------------------------
# Camera update
# ---------------------------------------------------------------------------

func _update_camera(delta: float) -> void:
	# Height — lerp to target based on state
	var target_height := camera_height_crouch if (_state == State.SLIDE or _state == State.CROUCH) else camera_height_stand
	_camera_pivot.position.y = lerp(_camera_pivot.position.y, target_height, camera_height_lerp_speed * delta)

	# FOV — dynamic (speed-based) unless disabled in GameSettings
	var horiz_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	var target_fov: float = fov_base
	if GameSettings.dynamic_fov_enabled:
		var sprint_fraction: float = clampf((horiz_speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0)
		target_fov += sprint_fraction * fov_sprint_bonus
		if _state == State.WALL_RUN:
			target_fov += fov_wall_run_bonus
	_camera.fov = lerp(_camera.fov, target_fov, fov_lerp_speed * delta)

	# Camera tilt for wall-run
	var target_roll := 0.0
	if _state == State.WALL_RUN:
		target_roll = -_wall_run_side * wall_run_camera_tilt
	var current_roll := rad_to_deg(_camera_pivot.rotation.z)
	_camera_pivot.rotation.z = deg_to_rad(lerp(current_roll, target_roll, camera_roll_lerp_speed * delta))


# ---------------------------------------------------------------------------
# State transition
# ---------------------------------------------------------------------------

func _transition(new_state: State) -> void:
	_state = new_state


# ---------------------------------------------------------------------------
# Respawn
# ---------------------------------------------------------------------------

## Teleport the player back to the captured spawn transform with all motion
## and parkour state cleared. Called automatically when below kill_y, and
## available for manual respawn (e.g. a reset key) later.
func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_jump_held = false
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_wall_run_timer = 0.0
	_wall_jump_grace_timer = 0.0
	_slide_timer = 0.0
	_vault_timer = 0.0
	_is_vaulting = false
	_wall_normal = Vector3.ZERO
	if _is_crouched:
		_set_crouch_shape(false)
	_transition(State.AIR)
