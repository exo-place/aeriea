## PressurePlate — a thin scene shim over the data-driven `plate` interactable in
## interaction/sandbox.kit.json. SLICE 3: the "a placed/standing weight holds the
## plate down" affordance is now a kit `tick` (two complementary entries gated by
## in_region / not in_region over the `pad` Area3D), exactly mirroring how the
## spout's fill is a tick gated by in_region — ZERO new engine code. The Area3D
## overlap test itself stays engine physics (read into the once-per-tick frame);
## the MEANING ("a weight on the pad presses it") is data. This node only registers
## its `pad` Area3D as the plate's region with the InteractionWorld and drives the
## diegetic depressed-pad visual off the `pressed` state.
class_name PressurePlate
extends Area3D

const KIT_ID := "plate"

@export var pad_path: NodePath

var _world: InteractionWorld
var _pad: Node3D
var _pad_base_y: float = 0.0
var _last_pressed: bool = false

## Parity surface: the test reads `plate.is_pressed`. Pure read of `pressed`.
var is_pressed: bool:
	get:
		if _world != null:
			return bool(_world.get_state(KIT_ID, "pressed", false))
		return false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("plate")
	_pad = get_node_or_null(pad_path) as Node3D
	if _pad:
		_pad_base_y = _pad.position.y
	_world = _find_world()
	if _world != null:
		# Register the pad region (this Area3D itself is the weight-overlap test).
		_world.register(KIT_ID, self, { "pad": self })
	_refresh_visual()


func _process(_dt: float) -> void:
	if is_pressed != _last_pressed:
		_last_pressed = is_pressed
		_refresh_visual()


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _refresh_visual() -> void:
	if _pad:
		_pad.position.y = _pad_base_y - 0.08 if is_pressed else _pad_base_y
