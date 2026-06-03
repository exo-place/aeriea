## Valve — a thin scene shim over the data-driven `valve` interactable in
## interaction/sandbox.kit.json. SLICE 1 of the affordance substrate: the toggle
## verb, its Open/Close prompt, the `flowing` state field, and the `flow_changed`
## event all live in DATA + the InteractionInterpreter. This node only:
##   - registers itself with the InteractionWorld under kit id "valve";
##   - exposes `is_flowing` as a READ of the interpreter's state (parity surface
##     for the behavioral test + the diegetic visual);
##   - drives the diegetic visual (handle rotation + indicator) off that state.
## It carries NO verb/guard/effect logic — that is the kit's. (Kept as the render
## layer + parity oracle, mirroring how movement kept the imperative controller.)
class_name Valve
extends StaticBody3D

const KIT_ID := "valve"

@export var handle_path: NodePath
@export var indicator_path: NodePath

var _world: InteractionWorld
var _handle: Node3D
var _indicator: MeshInstance3D
var _indicator_mat: StandardMaterial3D
var _last_flowing: bool = false

## Parity surface: the test reads `valve.is_flowing`. It is a pure read of the
## interpreter's `flowing` state field (the data is the source of truth).
var is_flowing: bool:
	get:
		if _world != null:
			return bool(_world.get_state(KIT_ID, "flowing", false))
		return false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("valve")
	_handle = get_node_or_null(handle_path) as Node3D
	_indicator = get_node_or_null(indicator_path) as MeshInstance3D
	if _indicator:
		_indicator_mat = StandardMaterial3D.new()
		_indicator_mat.emission_enabled = true
		_indicator.material_override = _indicator_mat
	_world = _find_world()
	if _world != null:
		_world.register(KIT_ID, self)
	_refresh_visual()


## Compat verb entry (the behavioral test's chain-B setup calls valve.interact()
## directly to open the valve). Drives the REAL data-driven toggle: it fires one
## interpreter step with this valve focused and the interact edge set, so the kit's
## toggle verb runs — not a hand-set flag.
func interact(_interactor) -> void:
	if _world != null:
		_world.step_with(KIT_ID, { "interact": true, "throw": false }, 1.0 / float(Engine.physics_ticks_per_second))
	_refresh_visual()


func _process(_dt: float) -> void:
	# Diegetic visual follows the data state (render layer over the sim).
	if is_flowing != _last_flowing:
		_last_flowing = is_flowing
		_refresh_visual()


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _refresh_visual() -> void:
	if _handle:
		_handle.rotation.z = deg_to_rad(90.0) if is_flowing else 0.0
	if _indicator_mat:
		_indicator_mat.emission = Color(0.0, 0.9, 0.2) if is_flowing else Color(0.4, 0.05, 0.05)
		_indicator_mat.emission_energy_multiplier = 2.5 if is_flowing else 0.4
