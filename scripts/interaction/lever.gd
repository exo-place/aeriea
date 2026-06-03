## Lever — a thin scene shim over the data-driven `lever` interactable in
## interaction/sandbox.kit.json. SLICE 3 of the affordance substrate (the payoff
## proof): the toggle verb, its Throw/Reset prompt, the `thrown` state field, and
## the `lever_changed` event all live in DATA + the InteractionInterpreter — the
## SAME `command`/`toggle_state`/`emit` primitives the valve uses, ZERO new engine
## code. This node only: registers under kit id "lever"; exposes `is_thrown` as a
## READ of the interpreter state (parity surface + diegetic visual); drives the
## handle rotation off that state. It carries NO verb/guard/effect logic.
class_name Lever
extends StaticBody3D

const KIT_ID := "lever"

@export var handle_path: NodePath

var _world: InteractionWorld
var _handle: Node3D
var _last_thrown: bool = false

## Parity surface: the test reads `lever.is_thrown`. Pure read of `thrown`.
var is_thrown: bool:
	get:
		if _world != null:
			return bool(_world.get_state(KIT_ID, "thrown", false))
		return false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("lever")
	_handle = get_node_or_null(handle_path) as Node3D
	_world = _find_world()
	if _world != null:
		_world.register(KIT_ID, self)
	_refresh_visual()


func _process(_dt: float) -> void:
	if is_thrown != _last_thrown:
		_last_thrown = is_thrown
		_refresh_visual()


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _refresh_visual() -> void:
	if _handle:
		_handle.rotation.x = deg_to_rad(50.0) if is_thrown else deg_to_rad(-50.0)
