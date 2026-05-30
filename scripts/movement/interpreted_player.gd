## InterpretedPlayer — a CharacterBody3D driven by the data-driven
## MovementInterpreter instead of hand-written GDScript. SLICE 1 validation
## vehicle: it proves the interpreter reproduces ground+jump behaviour.
##
## It is intentionally minimal — no camera, no FOV, no collider resize (those are
## render/Slice-2 concerns). It mirrors PlayerController's body setup (capsule,
## floor handling, spawn capture, kill-plane respawn, jump-buffer-on-edge via the
## interpreter's input sampling) so the existing real-input test harness drives it
## the same way it drives the imperative controller.
class_name InterpretedPlayer
extends CharacterBody3D

@export var kit_path: String = "res://movement/base.kit.json"
@export var stand_height: float = 0.9
@export var max_slope_angle: float = 45.0
@export var kill_y: float = -25.0
@export var spawn_path: NodePath

var interpreter: MovementInterpreter
var kit: MovementKit
var _capsule: CapsuleShape3D
var _collision_shape: CollisionShape3D
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _yaw: float = 0.0

func _ready() -> void:
	_spawn_transform = global_transform
	if not spawn_path.is_empty():
		var spawn_node := get_node_or_null(spawn_path)
		if spawn_node is Node3D:
			_spawn_transform = (spawn_node as Node3D).global_transform

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

	kit = MovementKit.load_from_file(kit_path)
	if not kit.is_valid():
		push_error("InterpretedPlayer: invalid kit at %s: %s" % [kit_path, str(kit.load_errors)])
		return
	interpreter = MovementInterpreter.new()
	interpreter.setup(kit, self)

func _physics_process(delta: float) -> void:
	if interpreter == null:
		return
	# Out-of-bounds recovery (the pre-tick below_y check is a Slice-2 condition;
	# Slice 1 keeps it as a host guard so the kill-plane test still passes).
	if global_position.y < kill_y:
		_respawn()
		return
	interpreter.yaw = _yaw
	interpreter.step(delta)

## Apply yaw/pitch from look input. Mouse-look stays separate from the sim and
## feeds wish-dir via yaw only (sampled once per tick by the interpreter).
func _apply_look_yaw(delta_yaw: float) -> void:
	_yaw += delta_yaw
	rotation.y = _yaw

func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	if interpreter != null:
		interpreter.timers.clear()
		interpreter.active_state = kit.initial
		for action in kit.inputs:
			interpreter.timers[action] = 0.0
		for t in ["coyote", "jump_buffer", "jump_hold"]:
			interpreter.timers[t] = 0.0
