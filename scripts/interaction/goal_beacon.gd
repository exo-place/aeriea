## GoalBeacon — a thin scene shim over the data-driven `beacon` interactable in
## interaction/sandbox.kit.json. SLICE 1: the convergence AND-gate (armed ∧
## reached) is now DATA — a `tick` effect gated by a `while` guard combining
## `state_bool(self.armed)` and `reached_by_player(reach)`; arming is a `reaction`
## on the pedestal's `activated` event (replacing the signal/connect). Unarmed
## reach is inert automatically (the guard is false). This node only: registers
## under kit id "beacon" with its `reach` Area3D region (the physics seam — the
## interpreter reads the player-overlap from the once-per-tick frame); exposes
## `is_armed` / `is_triggered` as the parity surface; drives the beacon visual.
class_name GoalBeacon
extends Area3D

const KIT_ID := "beacon"

@export var pedestal_path: NodePath   # kept for scene clarity; ref is data now
@export var mesh_path: NodePath

var _world: InteractionWorld
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _last_armed := false
var _last_triggered := false

var is_armed: bool:
	get:
		if _world != null:
			return bool(_world.get_state(KIT_ID, "armed", false))
		return false

var is_triggered: bool:
	get:
		if _world != null:
			return bool(_world.get_state(KIT_ID, "triggered", false))
		return false


func _ready() -> void:
	_mesh = get_node_or_null(mesh_path) as MeshInstance3D
	if _mesh:
		_mat = StandardMaterial3D.new()
		_mat.emission_enabled = true
		_mesh.material_override = _mat
	_world = _find_world()
	if _world != null:
		_world.register(KIT_ID, self, { "reach": self })
	_refresh_visual()


func _process(_dt: float) -> void:
	if is_armed != _last_armed or is_triggered != _last_triggered:
		_last_armed = is_armed
		_last_triggered = is_triggered
		_refresh_visual()


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _refresh_visual() -> void:
	if _mat == null:
		return
	if is_triggered:
		_mat.emission = Color(1.0, 0.95, 0.3)
		_mat.emission_energy_multiplier = 5.0
	elif is_armed:
		_mat.emission = Color(0.2, 1.0, 0.4)
		_mat.emission_energy_multiplier = 4.0
	else:
		_mat.emission = Color(0.5, 0.1, 0.1)
		_mat.emission_energy_multiplier = 0.6
