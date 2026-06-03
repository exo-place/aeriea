## Spout — an Area3D under the valve that, while the valve is flowing, fills any
## Jug whose body is inside it. This is the seam where the valve's STATE (flowing)
## and the jug's STATE (fill level) compose: neither edge alone fills the jug —
## the valve must be open AND the jug must be carried into the stream. The fill is
## continuous (rate × delta) so "hold the jug under the running spout" is a real,
## legible action with a visible result (the jug's fill rises).
class_name Spout
extends Area3D

@export var valve_path: NodePath
## Litres-equivalent filled per second while a jug sits in the stream.
@export var fill_rate: float = 1.5
@export var stream_path: NodePath

var _flowing: bool = false
var _stream: Node3D


func _ready() -> void:
	var valve := get_node_or_null(valve_path)
	if valve and valve.has_signal("flow_changed"):
		valve.flow_changed.connect(_on_flow_changed)
		_flowing = valve.is_flowing
	_stream = get_node_or_null(stream_path) as Node3D
	_refresh_stream()


func _on_flow_changed(flowing: bool) -> void:
	_flowing = flowing
	_refresh_stream()


func _refresh_stream() -> void:
	# Diegetic water-stream cue: show the stream mesh only while flowing.
	if _stream:
		_stream.visible = _flowing


func _physics_process(delta: float) -> void:
	if not _flowing:
		return
	for body in get_overlapping_bodies():
		var jug := _jug_of(body)
		if jug != null:
			jug.add_fill(fill_rate * delta)


func _jug_of(node: Node) -> Node:
	var n := node
	while n != null:
		if n.is_in_group("jug") and n.has_method("add_fill"):
			return n
		n = n.get_parent()
	return null
