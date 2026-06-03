## GoalBeacon — the convergence point of BOTH composition chains and the slice's
## "meaningful state change / unlock" payoff.
##
## It sits on a high ledge that is unreachable by movement alone. To "win" the
## slice the player must satisfy two composed chains that CONVERGE here:
##
##   1. interaction × interaction: open valve → fill jug at spout → carry →
##      place full jug in pedestal → pedestal ARMS the beacon.
##   2. movement × interaction: grab boxes → stack them under the ledge →
##      parkour (jump/vault) off the stack to REACH the ledge and touch the beacon.
##
## Neither chain alone completes it: an armed beacon you can't reach is inert; a
## reached beacon that isn't armed does nothing. The reach (Area3D overlap with the
## player) only counts the beacon as TRIGGERED when it is already armed. That AND
## across two independently-composed chains is the densest demonstration the slice
## offers — the opposite of a barren node.
class_name GoalBeacon
extends Area3D

signal armed
signal triggered

@export var pedestal_path: NodePath
@export var mesh_path: NodePath

var is_armed: bool = false
var is_triggered: bool = false

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	var pedestal := get_node_or_null(pedestal_path)
	if pedestal and pedestal.has_signal("activated"):
		pedestal.activated.connect(_on_pedestal_activated)
	_mesh = get_node_or_null(mesh_path) as MeshInstance3D
	if _mesh:
		_mat = StandardMaterial3D.new()
		_mat.emission_enabled = true
		_mesh.material_override = _mat
	body_entered.connect(_on_body_entered)
	_refresh_visual()


func _on_pedestal_activated() -> void:
	is_armed = true
	_refresh_visual()
	emit_signal("armed")


func _on_body_entered(body: Node) -> void:
	# Only a CharacterBody3D (the player) reaching the ledge counts, and only once
	# armed. An unarmed reach is a no-op (the chains must converge).
	if is_triggered:
		return
	if not is_armed:
		return
	if body is CharacterBody3D:
		is_triggered = true
		_refresh_visual()
		emit_signal("triggered")


func _refresh_visual() -> void:
	if _mat == null:
		return
	if is_triggered:
		_mat.emission = Color(1.0, 0.95, 0.3)       # gold: win
		_mat.emission_energy_multiplier = 5.0
	elif is_armed:
		_mat.emission = Color(0.2, 1.0, 0.4)         # green: armed, go reach it
		_mat.emission_energy_multiplier = 4.0
	else:
		_mat.emission = Color(0.5, 0.1, 0.1)         # dim red: locked
		_mat.emission_energy_multiplier = 0.6
