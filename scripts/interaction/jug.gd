## Jug — a grabbable container with a FILL state (empty → full). It is both a
## grabbable physics prop (like a box) AND a stateful container, so it sits at the
## intersection of two affordance kinds. Its fill level is the payload that the
## pedestal checks: only a FULL jug placed in the pedestal completes the chain.
##
## Composition role: grab jug → (valve open) hold under spout → fill rises →
## carry full jug to pedestal → place. Four distinct command edges chained into
## one unlock. The fill level is visible (the water mesh scales with fill) so the
## player reads "full enough yet?" diegetically.
class_name Jug
extends RigidBody3D

## Current fill, 0..1. Threshold for "full" is `full_threshold`.
var fill: float = 0.0
@export var full_threshold: float = 0.95
@export var water_path: NodePath

var _water: Node3D
var _water_base_scale_y: float = 1.0
var _water_base_y: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("jug")
	mass = 1.0
	_water = get_node_or_null(water_path) as Node3D
	if _water:
		_water_base_scale_y = _water.scale.y
		_water_base_y = _water.position.y
	_refresh_water()


func is_full() -> bool:
	return fill >= full_threshold


func add_fill(amount: float) -> void:
	fill = clampf(fill + amount, 0.0, 1.0)
	_refresh_water()


func affordance_prompt(_interactor) -> String:
	var pct := int(round(fill * 100.0))
	if is_full():
		return "[E] Pick up full jug    (%d%%)" % pct
	return "[E] Pick up jug    (%d%% — fill at spout)" % pct


## Grabbable: hand the interactor this body.
func grab_body(_interactor) -> RigidBody3D:
	return self


func interact(_interactor) -> void:
	pass


## Scale a child "water" mesh to visualise fill (diegetic level readout).
func _refresh_water() -> void:
	if _water == null:
		return
	var h := maxf(fill, 0.001)
	_water.scale.y = _water_base_scale_y * h
	# Keep the water sitting on the jug floor as it rises.
	_water.position.y = _water_base_y - _water_base_scale_y * (1.0 - h)
	_water.visible = fill > 0.01
