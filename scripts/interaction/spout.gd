## Spout — a thin scene shim over the data-driven `spout` interactable in
## interaction/sandbox.kit.json. SLICE 1: the "while the valve flows AND a jug
## overlaps the stream, fill it fill_rate*dt" behavior is now a kit `tick` effect
## gated by a `while` guard (no bespoke _physics_process, no signal connect). This
## node only registers its `stream` Area3D as the spout's region with the
## InteractionWorld (the physics seam: the interpreter reads region overlaps from
## the once-per-tick frame) and drives the diegetic stream visibility off the
## valve's data state.
class_name Spout
extends Area3D

const KIT_ID := "spout"

@export var valve_path: NodePath   # kept for the diegetic stream cue
@export var stream_path: NodePath

var _world: InteractionWorld
var _stream: Node3D
var _last_flowing := false


func _ready() -> void:
	_stream = get_node_or_null(stream_path) as Node3D
	_world = _find_world()
	if _world != null:
		# Register the stream region (this Area3D itself is the stream overlap test).
		_world.register(KIT_ID, self, { "stream": self })
	_refresh_stream()


func _process(_dt: float) -> void:
	if _world == null:
		return
	var flowing := bool(_world.get_state("valve", "flowing", false))
	if flowing != _last_flowing:
		_last_flowing = flowing
		_refresh_stream()


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _refresh_stream() -> void:
	if _stream:
		_stream.visible = bool(_world.get_state("valve", "flowing", false)) if _world != null else false
