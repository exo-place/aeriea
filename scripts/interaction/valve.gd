## Valve — a STATEFUL switch (the first link of the interaction×interaction chain).
##
## Turning the valve toggles a flow ON/OFF. While ON, a spout flows and any jug
## held under the spout fills (the Spout node reads `is_flowing`). This is a
## command edge whose effect is a persistent state change, not a one-shot — the
## valve being ON is what makes the FILL edge at the jug available. That is
## composition: the valve edge changes which edges exist elsewhere.
##
## Diegetically legible: the valve handle rotates 90° when open, and an emissive
## indicator goes from dim to bright. The prompt reflects the toggle ("Open valve"
## / "Close valve") so the player reads the current state and the available verb
## from the world, no HUD state readout.
class_name Valve
extends StaticBody3D

## Emitted when the valve is toggled; the spout listens to start/stop the flow.
signal flow_changed(flowing: bool)

@export var handle_path: NodePath
@export var indicator_path: NodePath

var is_flowing: bool = false

var _handle: Node3D
var _indicator: MeshInstance3D
var _indicator_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("valve")
	_handle = get_node_or_null(handle_path) as Node3D
	_indicator = get_node_or_null(indicator_path) as MeshInstance3D
	if _indicator:
		_indicator_mat = StandardMaterial3D.new()
		_indicator_mat.emission_enabled = true
		_indicator.material_override = _indicator_mat
	_refresh_visual()


func affordance_prompt(_interactor) -> String:
	return "[E] Close valve" if is_flowing else "[E] Open valve"


## The use verb: toggle the flow. Emits flow_changed so the spout reacts.
func interact(_interactor) -> void:
	is_flowing = not is_flowing
	_refresh_visual()
	emit_signal("flow_changed", is_flowing)


func _refresh_visual() -> void:
	if _handle:
		# Diegetic state cue: rotate the handle 90° when open.
		_handle.rotation.z = deg_to_rad(90.0) if is_flowing else 0.0
	if _indicator_mat:
		# Dim red (closed) → bright green (open).
		_indicator_mat.emission = Color(0.0, 0.9, 0.2) if is_flowing else Color(0.4, 0.05, 0.05)
		_indicator_mat.emission_energy_multiplier = 2.5 if is_flowing else 0.4
