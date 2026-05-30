## InterpretedPlayer — a CharacterBody3D driven by the data-driven
## MovementInterpreter instead of hand-written GDScript. This is the LIVE player
## for the data-driven movement substrate (the imperative PlayerController is kept
## only as the parity oracle until the compiler slice proves equivalence).
##
## SLICE 2: it now carries the full verb surface — slide, crouch-walk, wall-run,
## wall-jump, vault, kill-plane respawn — all expressed in movement/base.kit.json
## and executed by the interpreter. This script owns only the irreducible
## Godot/world primitives the interpreter delegates to (capsule resize, wall/ledge
## raycasts, camera nodes, spawn transform) via the host_* protocol; all
## conditionals and tuning live in data.
##
## It exposes a parity-compatible surface (the `State` enum, `_state`,
## `_is_crouched`, `_capsule`, the timer accessors, `_wall_normal`/`_wall_run_side`,
## `_transition`, `_apply_look`, `_input`, `mouse_sensitivity`, and the slide/wall
## tuning vars) so the SAME behavioral assertion suite that drives the imperative
## PlayerController drives this player unchanged. The enum order mirrors
## PlayerController.State exactly so cross-target assertions compare equal.
class_name InterpretedPlayer
extends CharacterBody3D

# State enum mirrors PlayerController.State EXACTLY (same ordinals) so the shared
# behavioral suite's `== PlayerController.State.SLIDE` comparisons hold when it
# reads our `_state`. Kept as data: the interpreter works in string state names;
# this maps the active kit state name to the parity ordinal.
enum State { GROUND, AIR, SLIDE, CROUCH, WALL_RUN, VAULT }

const _STATE_NAME_TO_ENUM := {
	"GROUND": State.GROUND, "AIR": State.AIR, "SLIDE": State.SLIDE,
	"CROUCH": State.CROUCH, "WALL_RUN": State.WALL_RUN, "VAULT": State.VAULT,
}

## The movement kit source. A `.manifest.json` is composed (base ⊕ verb overlays,
## docs/decisions/movement-substrate.md §2); a plain `.kit.json` loads directly.
## Default is the composed playable kit (base + bullet_jump and any future verbs).
@export var kit_path: String = "res://movement/default.manifest.json"
@export var kill_y: float = -25.0
@export var spawn_path: NodePath

## When true, this host is driven by the COMPILED projection
## (CompiledBaseMovement, generated from the kit) instead of the interpreter.
## The two drivers share an identical surface (setup/step/reset_state +
## active_state/timers/wall_normal/wall_side/yaw), so the same host and the same
## tests exercise either path. The golden-trace harness asserts they're identical;
## the live scene keeps the interpreter (hot-reload), the compiled path is
## validated via tests. See docs/decisions/movement-substrate.md §4.
@export var use_compiled: bool = false

# --- Camera tuning (render-side; mirrors PlayerController defaults) ----------
@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
@export var pitch_min: float = -89.0
@export var pitch_max: float = 89.0
@export var camera_height_stand: float = 0.85
@export var camera_height_crouch: float = 0.55
@export var fov_base: float = 90.0

# --- Collider / slope --------------------------------------------------------
@export_group("Body")
@export var stand_height: float = 0.9
@export var crouch_height: float = 0.6
@export var max_slope_angle: float = 45.0

# --- Parity tuning surface (read by the shared test suite; the kit is the
#     source of truth for the sim — these MIRROR the kit params for assertions
#     like `speed_before >= player.slide_entry_speed`). Loaded from the kit in
#     _ready so there is one source of truth. -------------------------------
@export_group("Parity (mirrors kit params)")
@export var slide_entry_speed: float = 8.0
@export var max_slide_speed: float = 22.0
@export var wall_run_speed: float = 9.0
@export var wall_run_max_time: float = 1.4
@export var wall_detect_distance: float = 0.65

# --- Vault tuning (world-query geometry; mirrors PlayerController) -----------
@export_group("Vault")
@export var vault_detect_forward: float = 0.9
@export var vault_ledge_ray_high: float = 1.8
@export var vault_ledge_ray_low: float = 1.1
@export var vault_duration: float = 0.28
@export var vault_overshoot: float = 0.6

## The movement driver: a MovementInterpreter (reference semantics) or a
## CompiledBaseMovement (the lowered projection) when use_compiled is set. Both
## expose the same surface, so this stays duck-typed. Named `interpreter` for
## parity with the accessors/tests that read it.
var interpreter
var kit: MovementKit

var _capsule: CapsuleShape3D
var _collision_shape: CollisionShape3D
var _camera_pivot: Node3D
var _camera: Camera3D
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _yaw: float = 0.0
var _pitch: float = 0.0
var _mouse_captured: bool = true

## Crouched-collider flag — mirrors PlayerController._is_crouched so the suite's
## `player._is_crouched` reads identically. Set by host_set_collider_height.
var _is_crouched: bool = false

## Vault scripted-move endpoints, captured on vault entry (world query).
var _vault_start: Vector3 = Vector3.ZERO
var _vault_end: Vector3 = Vector3.ZERO

# ---------------------------------------------------------------------------
# Parity accessors — the shared suite reads these. They project the
# interpreter's string state / timers onto the names the suite expects.
# ---------------------------------------------------------------------------

var _state: int:
	get:
		if interpreter == null:
			return State.AIR
		return _STATE_NAME_TO_ENUM.get(interpreter.active_state, State.AIR)

var _jump_buffer_timer: float:
	get: return float(interpreter.timers.get("jump_buffer", 0.0)) if interpreter else 0.0

var _wall_normal: Vector3:
	get: return interpreter.wall_normal if interpreter else Vector3.ZERO
	set(v):
		if interpreter: interpreter.wall_normal = v

var _wall_run_side: float:
	get: return interpreter.wall_side if interpreter else 0.0
	set(v):
		if interpreter: interpreter.wall_side = v

var _wall_run_timer: float:
	get: return float(interpreter.timers.get("wall_run", 0.0)) if interpreter else 0.0
	set(v):
		if interpreter: interpreter.timers["wall_run"] = v

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------

func _ready() -> void:
	_spawn_transform = global_transform
	if not spawn_path.is_empty():
		var spawn_node := get_node_or_null(spawn_path)
		if spawn_node is Node3D:
			_spawn_transform = (spawn_node as Node3D).global_transform

	# Camera rig (mirrors PlayerController so look/FOV/roll effects have a target).
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	add_child(_camera_pivot)
	_camera_pivot.position.y = camera_height_stand
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = fov_base
	_camera_pivot.add_child(_camera)

	# Collision capsule, centred at body origin (matches PlayerController).
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = stand_height * 2.0
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = _capsule
	_collision_shape.position = Vector3.ZERO
	add_child(_collision_shape)

	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = 0.5

	if kit_path.ends_with(".manifest.json"):
		kit = MovementKit.load_from_manifest(kit_path)
	else:
		kit = MovementKit.load_from_file(kit_path)
	if not kit.is_valid():
		push_error("InterpretedPlayer: invalid kit at %s: %s" % [kit_path, str(kit.load_errors)])
		return
	# One source of truth: mirror tuning the suite reads from the kit params.
	slide_entry_speed = float(kit.params.get("slide_entry_speed", slide_entry_speed))
	max_slide_speed = float(kit.params.get("max_slide_speed", max_slide_speed))
	wall_run_speed = float(kit.params.get("wall_run_speed", wall_run_speed))
	wall_run_max_time = float(kit.params.get("wall_run_max_time", wall_run_max_time))
	wall_detect_distance = float(kit.params.get("wall_detect_distance", wall_detect_distance))

	if use_compiled:
		interpreter = CompiledBaseMovement.new()
	else:
		interpreter = MovementInterpreter.new()
	interpreter.setup(kit, self)

	# Accessibility (#5): register the sprint tap-vs-hold resolver from GameSettings.
	# The interpreter's once-per-tick InputFrame then exposes a single coherent
	# "sprint active" signal regardless of mode, so the kit's sprint condition is
	# mode-agnostic. Reusable: register another action's ToggleHold the same way.
	_refresh_input_modes()
	var gs := get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("settings_changed") and not gs.settings_changed.is_connected(_refresh_input_modes):
		gs.settings_changed.connect(_refresh_input_modes)

	if Engine.is_editor_hint():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## (Re)build the per-action tap-vs-hold resolvers from GameSettings. Called on
## ready and whenever settings change. Preserves an existing sprint latch across a
## pure mode-change so the player doesn't get a surprise sprint flip.
func _refresh_input_modes() -> void:
	if interpreter == null:
		return
	var gs := get_node_or_null("/root/GameSettings")
	var sprint_mode := 0
	if gs:
		sprint_mode = int(gs.sprint_mode)
	var th = interpreter.toggle_actions.get("sprint")
	if th == null:
		# The ToggleHold class is nested in whichever driver is active (interpreter
		# or compiled). Both expose the same surface; construct the matching one.
		if use_compiled:
			th = CompiledBaseMovement.ToggleHold.new()
		else:
			th = MovementInterpreter.ToggleHold.new()
		interpreter.toggle_actions["sprint"] = th
	th.mode = sprint_mode

# ---------------------------------------------------------------------------
# Physics / input
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if interpreter == null:
		return
	interpreter.yaw = _yaw
	# Feed the camera pitch into the sim too, so verbs naming the `aim`/look space
	# launch along the FULL 3D look direction (Warframe bullet jump: look up → up,
	# down → dive, level → forward arc). Only the `aim` space reads it; all other
	# motion is yaw-only, so this changes nothing for the rest of the kit. Mirrors
	# the existing yaw plumbing (mouse-look already maintains _pitch in _apply_look).
	interpreter.pitch = _pitch
	interpreter.step(delta)

func _input(event: InputEvent) -> void:
	_mouse_captured = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if _mouse_captured and event is InputEventMouseMotion:
		_apply_look((event as InputEventMouseMotion).relative)
	if not _mouse_captured and not get_tree().paused:
		if event is InputEventMouseButton:
			var mev := event as InputEventMouseButton
			if mev.pressed and mev.button_index == MOUSE_BUTTON_LEFT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true
				get_viewport().set_input_as_handled()

## Apply a relative mouse-motion delta to yaw/pitch. Mouse-look feeds the sim via
## yaw only (sampled once per tick by the interpreter); pitch is render-only.
func _apply_look(relative: Vector2) -> void:
	_yaw -= relative.x * mouse_sensitivity
	_pitch -= relative.y * mouse_sensitivity
	_pitch = clampf(_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	rotation.y = _yaw
	if _camera_pivot:
		_camera_pivot.rotation.x = _pitch

## Parity shim: PlayerController._transition(State) sets its state. The
## interpreter is state-machine-of-record, but tests force WALL_RUN directly, so
## map the enum back to the interpreter's active string state.
func _transition(new_state: int) -> void:
	if interpreter == null:
		return
	for name in _STATE_NAME_TO_ENUM:
		if _STATE_NAME_TO_ENUM[name] == new_state:
			interpreter.active_state = name
			return

# ---------------------------------------------------------------------------
# host_* protocol — the irreducible world/scene primitives the interpreter
# delegates to. Conditionals/tuning stay in data; only these touch Godot.
# ---------------------------------------------------------------------------

## Resize the collision capsule, keeping feet planted. Idempotent (no-op if the
## target half-height is already in effect) to avoid the resize jitter the prior
## fix removed. When growing (standing up) with require_headroom, only resize if
## there is clearance — otherwise stay low. Mirrors PlayerController._set_crouch_shape
## + _end_slide/_can_stand.
func host_set_collider_height(half_height: float, require_headroom: bool) -> void:
	var new_height := half_height * 2.0
	if is_equal_approx(_capsule.height, new_height):
		return
	var growing := new_height > _capsule.height
	if growing and require_headroom and not host_can_stand():
		return  # blocked — stay crouched
	var old_height := _capsule.height
	var shrink := old_height - new_height   # positive when shrinking (crouch)
	_capsule.height = new_height
	# Keep feet planted: origin moves DOWN by shrink/2 on shrink, UP on grow.
	global_position.y -= shrink * 0.5
	_is_crouched = new_height < stand_height * 2.0 - 0.0001

func host_can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.UP * (stand_height * 2.0 + 0.1),
		collision_mask)
	params.exclude = [self]
	return space.intersect_ray(params).is_empty()

## Cast a wall-detection ray to one side (+1 right, -1 left) out to `dist`.
## Returns the raw ray hit Dictionary (empty if none). The interpreter decides
## whether the hit counts (vertical-enough normal).
func host_wall_ray(side: float, dist: float) -> Dictionary:
	if side == 0.0:
		return {}
	var side_vec: Vector3 = transform.basis.x * side
	var from: Vector3 = global_position
	var to: Vector3 = from + side_vec * dist
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	params.exclude = [self]
	return space.intersect_ray(params)

## Vault check via the ray triple (mirrors PlayerController._check_vault). On a
## valid ledge, captures _vault_start/_vault_end for the tween and returns true.
func host_check_vault() -> bool:
	var forward := -transform.basis.z
	var space := get_world_3d().direct_space_state

	var high_from: Vector3 = global_position + Vector3.UP * vault_ledge_ray_high
	var high_to: Vector3 = high_from + forward * vault_detect_forward
	var ph := PhysicsRayQueryParameters3D.create(high_from, high_to, collision_mask)
	ph.exclude = [self]
	var high_hit: Dictionary = space.intersect_ray(ph)

	var low_from: Vector3 = global_position + Vector3.UP * vault_ledge_ray_low
	var low_to: Vector3 = low_from + forward * vault_detect_forward
	var pl := PhysicsRayQueryParameters3D.create(low_from, low_to, collision_mask)
	pl.exclude = [self]
	var low_hit: Dictionary = space.intersect_ray(pl)

	if low_hit and not high_hit:
		var low_pos: Vector3 = low_hit["position"]
		var top_from: Vector3 = low_pos + Vector3.UP * 1.2 + forward * 0.3
		var top_to: Vector3 = top_from + Vector3.DOWN * 2.0
		var pt := PhysicsRayQueryParameters3D.create(top_from, top_to, collision_mask)
		pt.exclude = [self]
		var top_hit: Dictionary = space.intersect_ray(pt)
		if not top_hit.is_empty():
			var ledge_top: Vector3 = top_hit["position"]
			var vault_height: float = ledge_top.y - global_position.y
			if vault_height >= -0.3 and vault_height <= 1.6:
				_vault_start = global_position
				_vault_end = ledge_top + forward * vault_overshoot + Vector3.UP * stand_height
				velocity = Vector3.ZERO
				return true
	return false

## Drive the vault scripted move. `remaining` is the vault timer countdown;
## `duration` its full length. Lerps position start→end; snaps + zeroes velocity
## at the end. Mirrors PlayerController._process_vault.
func host_tween_position(remaining: float, duration: float) -> void:
	if duration <= 0.0:
		duration = vault_duration
	if remaining <= 0.0:
		global_position = _vault_end
		velocity = Vector3.ZERO
		return
	var progress := 1.0 - (remaining / duration)
	global_position = _vault_start.lerp(_vault_end, progress)
	move_and_slide()

## Camera height ease (render-only).
func host_lerp_camera_height(target: float, rate: float, dt: float) -> void:
	if _camera_pivot:
		_camera_pivot.position.y = lerpf(_camera_pivot.position.y, target, rate * dt)

func host_lerp_fov(target: float, rate: float, dt: float) -> void:
	if _camera:
		_camera.fov = lerpf(_camera.fov, target, rate * dt)

func host_lerp_camera_roll(target_deg: float, rate: float, dt: float) -> void:
	if _camera_pivot:
		var cur := rad_to_deg(_camera_pivot.rotation.z)
		_camera_pivot.rotation.z = deg_to_rad(lerpf(cur, target_deg, rate * dt))

## Respawn: teleport to spawn, zero velocity + timers + parkour state. Mirrors
## PlayerController.respawn. Called via the `respawn` effect (below_y guard).
func host_respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	if _is_crouched:
		host_set_collider_height(stand_height, false)
	if interpreter:
		interpreter.reset_state()
