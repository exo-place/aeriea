## Jug — a thin scene shim over the data-driven `jug` interactable in
## interaction/sandbox.kit.json. SLICE 1: the grab verb, the pct-interpolated
## prompt, and the `fill` state field live in DATA + the InteractionInterpreter.
## This node only: registers under kit id "jug"; exposes `fill` / `is_full()` /
## `add_fill()` as the parity surface (reads/writes of the interpreter's `fill`
## state field — the data is the source of truth); and drives the water-level
## visual off that state.
class_name Jug
extends RigidBody3D

const KIT_ID := "jug"

@export var full_threshold: float = 0.95
@export var water_path: NodePath

var _world: InteractionWorld
var _water: Node3D
var _water_base_scale_y: float = 1.0
var _water_base_y: float = 0.0
var _last_fill: float = -1.0

## Parity surface: the test reads `jug.fill`. Pure read of the interpreter state.
var fill: float:
	get:
		if _world != null:
			return float(_world.get_state(KIT_ID, "fill", 0.0))
		return 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("jug")
	mass = 1.0
	_water = get_node_or_null(water_path) as Node3D
	if _water:
		_water_base_scale_y = _water.scale.y
		_water_base_y = _water.position.y
	_world = _find_world()
	if _world != null:
		_world.register(KIT_ID, self)
	_refresh_water()


func _process(_dt: float) -> void:
	if absf(fill - _last_fill) > 0.0001:
		_last_fill = fill
		_refresh_water()


func is_full() -> bool:
	return fill >= full_threshold


## Write through to the interpreter state (the test drives a direct fill to set up
## chain B). Keeps the data the single source of truth.
func add_fill(amount: float) -> void:
	if _world == null or _world.interp == null:
		return
	var rec: Dictionary = _world.interp.state.get(KIT_ID, {})
	rec["fill"] = clampf(float(rec.get("fill", 0.0)) + amount, 0.0, 1.0)
	_refresh_water()


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _refresh_water() -> void:
	if _water == null:
		return
	var h := maxf(fill, 0.001)
	_water.scale.y = _water_base_scale_y * h
	_water.position.y = _water_base_y - _water_base_scale_y * (1.0 - h)
	_water.visible = fill > 0.01
