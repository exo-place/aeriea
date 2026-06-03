## Pedestal — a PLACEABLE socket that completes the interaction×interaction chain.
##
## It accepts the jug. If the jug placed is FULL, the pedestal "activates": it
## drops/extends a counterweight platform AND arms the goal beacon. If the jug is
## empty it is accepted but the pedestal stays inert (and says so), so the player
## reads that filling matters. This is the chain's payoff edge: it only fires when
## the upstream edges (open valve → fill jug → carry → place) all happened.
##
## Placing is a command verb: the interactor, while carrying a jug and looking at
## the pedestal, runs interact() which CONSUMES the held jug (snaps it into the
## socket) — a state change that depends on the carried-object state. The pedestal
## reads `is_full()` off the jug it receives; that cross-object state check is the
## composition seam a future data substrate must model (a verb whose guard reads
## another object's state).
class_name Pedestal
extends StaticBody3D

## Emitted once when a FULL jug is socketed. Listeners (ramp, beacon) react.
signal activated

@export var socket_path: NodePath
@export var indicator_path: NodePath

var is_active: bool = false
var _socketed_jug: Node = null
var _socket: Node3D
var _indicator: MeshInstance3D
var _indicator_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pedestal")
	_socket = get_node_or_null(socket_path) as Node3D
	_indicator = get_node_or_null(indicator_path) as MeshInstance3D
	if _indicator:
		_indicator_mat = StandardMaterial3D.new()
		_indicator_mat.emission_enabled = true
		_indicator.material_override = _indicator_mat
	_refresh_visual()


## The pedestal accepts a carried jug (any jug — full or not; fullness gates the
## activation, not the placement). Lets the interactor route the place verb here
## while carrying instead of dropping.
func accepts_held(body) -> bool:
	return not is_active and body != null and body.is_in_group("jug")


func affordance_prompt(interactor) -> String:
	if is_active:
		return "Pedestal active"
	# Only meaningful while carrying a jug — surface the contextual verb then.
	if interactor != null and interactor.has_method("held_body"):
		var held = interactor.held_body()
		if held != null and held.is_in_group("jug"):
			if held.is_full():
				return "[E] Place full jug    (activates)"
			return "[E] Place jug    (jug is not full)"
	return "Needs a full jug"


## Place verb: consume the carried jug into the socket. If it's full, activate.
func interact(interactor) -> void:
	if is_active:
		return
	if interactor == null or not interactor.has_method("held_body"):
		return
	var held = interactor.held_body()
	if held == null or not held.is_in_group("jug"):
		return
	# Consume the jug: take it out of the carry, freeze it into the socket.
	if interactor.has_method("force_release"):
		interactor.force_release()
	_socket_jug(held)
	if held.is_full():
		is_active = true
		_refresh_visual()
		emit_signal("activated")
	else:
		_refresh_visual()


## Snap a jug into the socket and freeze it (becomes static decoration).
func _socket_jug(jug: Node) -> void:
	_socketed_jug = jug
	if jug is RigidBody3D:
		var rb := jug as RigidBody3D
		rb.freeze = true
		rb.gravity_scale = 0.0
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	if _socket and jug is Node3D:
		(jug as Node3D).global_transform = _socket.global_transform


func _refresh_visual() -> void:
	if _indicator_mat:
		_indicator_mat.emission = Color(0.1, 0.7, 1.0) if is_active else Color(0.3, 0.3, 0.35)
		_indicator_mat.emission_energy_multiplier = 3.0 if is_active else 0.3
