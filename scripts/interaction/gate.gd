## Gate — a thin scene shim over the data-driven `gate` interactable in
## interaction/sandbox.kit.json. SLICE 3, the densest node of the payoff proof: the
## convergence AND-gate `open iff (lever.thrown AND plate.pressed)` is now DATA — a
## `tick` effect whose `while` guard is an `all` over two cross-object `state_bool`
## reads (ref:lever, ref:plate), with a second tick (`not all(...)`) that CLOSES it
## live. This is the SAME composition operator the beacon's `armed AND reached`
## uses, with a different independently-composed pair — proving the convergence
## pattern generalizes with ZERO new engine code. The converse (lever-alone or
## plate-alone) is inert by construction (the all-guard is false). This node only
## registers under kit id "gate", exposes `is_open` (parity surface), and slides
## the gate panel + recolours it off that state. It carries NO guard/effect logic.
class_name Gate
extends StaticBody3D

const KIT_ID := "gate"

@export var panel_path: NodePath

var _world: InteractionWorld
var _panel: Node3D
var _panel_base_y: float = 0.0
var _panel_mat: StandardMaterial3D
var _last_open: bool = false

## Parity surface: the test reads `gate.is_open`. Pure read of `open`.
var is_open: bool:
	get:
		if _world != null:
			return bool(_world.get_state(KIT_ID, "open", false))
		return false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("gate")
	_panel = get_node_or_null(panel_path) as Node3D
	if _panel:
		_panel_base_y = _panel.position.y
		if _panel is MeshInstance3D:
			_panel_mat = StandardMaterial3D.new()
			_panel_mat.emission_enabled = true
			(_panel as MeshInstance3D).material_override = _panel_mat
	_world = _find_world()
	if _world != null:
		_world.register(KIT_ID, self)
	_refresh_visual()


func _process(_dt: float) -> void:
	if is_open != _last_open:
		_last_open = is_open
		_refresh_visual()


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _refresh_visual() -> void:
	if _panel:
		# Slide the panel up into the lintel when open (diegetic "gate retracts").
		_panel.position.y = _panel_base_y + 2.0 if is_open else _panel_base_y
	if _panel_mat:
		_panel_mat.emission = Color(0.2, 1.0, 0.4) if is_open else Color(0.5, 0.1, 0.1)
		_panel_mat.emission_energy_multiplier = 3.0 if is_open else 0.5
