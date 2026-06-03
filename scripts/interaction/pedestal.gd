## Pedestal — a thin scene shim over the data-driven `pedestal` interactable in
## interaction/sandbox.kit.json. SLICE 1: the place verb (available while carrying
## a jug and empty), its cross-object prompt (branches on the HELD jug's fullness),
## the guarded activation (consume always, activate only if `held.fill >=
## full_threshold`), and the `activated` event all live in DATA + the interpreter.
## This node only: registers under kit id "pedestal"; exposes `is_active` (read of
## the `active` state field) as the parity surface; provides `socket_transform()`
## for the host's consume_into_socket physics intent; drives the indicator visual.
class_name Pedestal
extends StaticBody3D

const KIT_ID := "pedestal"

@export var socket_path: NodePath
@export var indicator_path: NodePath

var _world: InteractionWorld
var _socket: Node3D
var _indicator: MeshInstance3D
var _indicator_mat: StandardMaterial3D
var _last_active := false

## Parity surface: the test reads `pedestal.is_active`. Pure read of `active`.
var is_active: bool:
	get:
		if _world != null:
			return bool(_world.get_state(KIT_ID, "active", false))
		return false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pedestal")
	_socket = get_node_or_null(socket_path) as Node3D
	_indicator = get_node_or_null(indicator_path) as MeshInstance3D
	if _indicator:
		_indicator_mat = StandardMaterial3D.new()
		_indicator_mat.emission_enabled = true
		_indicator.material_override = _indicator_mat
	_world = _find_world()
	if _world != null:
		_world.register(KIT_ID, self)
	_refresh_visual()


func _process(_dt: float) -> void:
	if is_active != _last_active:
		_last_active = is_active
		_refresh_visual()


## The host's consume_into_socket intent snaps the jug here.
func socket_transform() -> Transform3D:
	if _socket != null:
		return _socket.global_transform
	return global_transform


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _refresh_visual() -> void:
	if _indicator_mat:
		_indicator_mat.emission = Color(0.1, 0.7, 1.0) if is_active else Color(0.3, 0.3, 0.35)
		_indicator_mat.emission_energy_multiplier = 3.0 if is_active else 0.3
