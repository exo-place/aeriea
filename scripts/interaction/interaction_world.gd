## InteractionWorld — the host that binds the data-driven InteractionInterpreter
## to the live Godot scene (docs/decisions/affordance-substrate.md §5, §7a). It is
## the seam where the affordance graph (data) meets the physics that realizes it
## (engine): it loads the kit, owns the interpreter + the explicit state record,
## resolves the once-per-tick frame from the scene (focus raycast, held identity,
## Area3D region overlaps), and executes physics intents (grab/release/impulse/
## socket) the interpreter emits.
##
## Interactable scene-nodes register themselves here by their kit id (the binding
## from scene node <-> data interactable). The interactor reads focus + drives verb
## fire through this host; the per-object scripts are now thin shims that read their
## state out of the interpreter (kept as a parity oracle / render layer, not logic).
##
## The interpreter is the reference semantics; this host supplies ONLY the
## irreducible world primitives (the §5 physics seam). No guard/effect logic lives
## here — only frame resolution and physics intents.
class_name InteractionWorld
extends Node

const InteractionKitScript := preload("res://scripts/interaction/interaction_kit.gd")
const InteractionInterpreterScript := preload("res://scripts/interaction/interaction_interpreter.gd")

## Path to the kit JSON describing this world's interactables.
@export var kit_path: String = "res://interaction/sandbox.kit.json"

var kit: InteractionKit
var interp: InteractionInterpreter

## kit id -> scene node (the registered interactable body/area).
var _nodes: Dictionary = {}
## scene node instance id -> kit id (reverse map for collider resolution).
var _id_of_node: Dictionary = {}
## kit id -> Area3D region name -> Area3D node (regions are scene Area3Ds).
var _regions: Dictionary = {}

## The carried body's kit id ("" if none), set by host_grab/host_release. The
## interactor owns the carry SPRING (physics); the world owns the identity.
var _held_id: String = ""
var _held_body: RigidBody3D = null
var _held_prev_gravity: float = 0.0

## The interactor (set on register) — needed for the look-ray + carry direction.
var _interactor = null
## The player body (excluded from the focus ray; the reach-region overlap subject).
var _player: CharacterBody3D = null


## Find the InteractionWorld belonging to `node`'s OWN scene (scene-local). A test
## that spawns a fresh level keeps the previous level briefly alive, so a tree-wide
## group query could return the wrong scene's world; we resolve within the node's
## scene root instead. The world is a direct child of the scene root.
static func find_in_scene(node: Node) -> InteractionWorld:
	# Walk up to the scene root (the outermost owner), then find the world child.
	var root := node
	while root.get_owner() != null:
		root = root.get_owner()
	for child in root.get_children():
		if child is InteractionWorld:
			return child as InteractionWorld
	# Fallback: tree-wide (single-world case).
	var nodes := node.get_tree().get_nodes_in_group("interaction_world")
	return nodes[0] as InteractionWorld if nodes.size() > 0 else null


func _enter_tree() -> void:
	# Load + set up in _enter_tree (fires top-down, parent before children) so the
	# interpreter exists before any interactable's _ready registers against it.
	add_to_group("interaction_world")
	kit = InteractionKitScript.load_from_file(kit_path)
	if not kit.is_valid():
		for e in kit.load_errors:
			push_error("InteractionWorld: kit load error: %s" % e)
		return
	interp = InteractionInterpreterScript.new()
	interp.setup(kit, self)


## Register an interactable scene node under its kit id. Called by each
## interactable in its _ready. `regions` maps region-name -> Area3D node.
func register(kit_id: String, node: Node, regions: Dictionary = {}) -> void:
	_nodes[kit_id] = node
	_id_of_node[node.get_instance_id()] = kit_id
	if not regions.is_empty():
		_regions[kit_id] = regions


## Register a runtime INSTANCE of a definition (e.g. one box of the `box` def)
## under a unique instance id. Creates the interpreter state slot + iteration entry.
func register_instance(instance_id: String, def_id: String, node: Node, regions: Dictionary = {}) -> void:
	if interp != null:
		interp.add_instance(instance_id, def_id)
	register(instance_id, node, regions)


func register_interactor(interactor, player: CharacterBody3D) -> void:
	_interactor = interactor
	_player = player


func node_for(kit_id: String):
	return _nodes.get(kit_id)


# ---------------------------------------------------------------------------
# State accessors (read by the thin interactable shims + the test). The shims
# expose is_flowing/fill/is_active/is_armed/is_triggered as reads of THIS record.
# ---------------------------------------------------------------------------

func get_state(kit_id: String, field: String, default_value = null):
	if interp == null:
		return default_value
	return interp.state.get(kit_id, {}).get(field, default_value)


func held_kit_id() -> String:
	return _held_id


func held_body() -> RigidBody3D:
	return _held_body if is_instance_valid(_held_body) else null


# ---------------------------------------------------------------------------
# §5 step 1 — frame resolution. Sampled ONCE per tick by the interactor before it
# calls interp.step(). The interactor passes the focus id + input edges; this host
# fills the held identity + region overlaps from the live physics state.
# ---------------------------------------------------------------------------

func build_frame_with(focus_id: String, edges: Dictionary) -> InteractionInterpreter.ResolvedFrame:
	var frame := InteractionInterpreter.ResolvedFrame.new()
	frame.focus_id = focus_id
	frame.edges = edges
	frame.held_id = _held_id
	if _held_id != "":
		var hit: Node = _nodes.get(_held_id)
		if hit != null:
			frame.held_tags = _tags_of(_held_id)
	# Region overlaps: for every interactable with regions, sample Area3D overlaps
	# once and record which registered interactable ids (and whether the player) are
	# inside. The interpreter reads ONLY this — no mid-tick re-query.
	for owner_id in _regions:
		var region_map: Dictionary = _regions[owner_id]
		for region_name in region_map:
			var area: Area3D = region_map[region_name]
			if area == null or not is_instance_valid(area):
				continue
			var key := "%s:%s" % [owner_id, region_name]
			var members: Array = []
			var player_in := false
			for body in area.get_overlapping_bodies():
				var bid := _resolve_id(body)
				if bid != "":
					members.append(bid)
				if _player != null and body == _player:
					player_in = true
			frame.region_members[key] = members
			frame.player_in_region[key] = player_in
	return frame


## host_build_frame is the interpreter's protocol entry; the interactor primes the
## focus + edges via _pending_frame before stepping. (Kept separate so the
## interpreter stays host-agnostic.)
var _pending_frame: InteractionInterpreter.ResolvedFrame = null

func host_build_frame() -> InteractionInterpreter.ResolvedFrame:
	if _pending_frame != null:
		return _pending_frame
	return InteractionInterpreter.ResolvedFrame.new()


## Step the interpreter once with an explicit frame (focus + edges resolved by the
## interactor). The single deterministic tick entry.
func step_with(focus_id: String, edges: Dictionary, dt: float) -> void:
	if interp == null:
		return
	_pending_frame = build_frame_with(focus_id, edges)
	interp.step(dt)
	_pending_frame = null


## Project the contextual prompt for the interactor's HUD (render-side).
func project_prompt(focus_id: String) -> String:
	if interp == null:
		return ""
	var frame := build_frame_with(focus_id, {})
	return interp.project_prompt(frame)


# ---------------------------------------------------------------------------
# Physics intents (§5). The interpreter calls these; here is the only place the
# carry spring / freeze / impulse touch the physics world.
# ---------------------------------------------------------------------------

func host_grab(kit_id: String) -> bool:
	var node = _nodes.get(kit_id)
	if node == null or not (node is RigidBody3D):
		return false
	var body := node as RigidBody3D
	_held_id = kit_id
	_held_body = body
	_held_prev_gravity = body.gravity_scale
	body.gravity_scale = 0.0
	body.linear_damp = 6.0
	body.angular_damp = 6.0
	if _interactor != null:
		_interactor._on_world_grabbed()
	return true


func host_release(mode: String, _impulse_magnitude: float) -> void:
	if _held_body == null or not is_instance_valid(_held_body):
		_held_id = ""
		_held_body = null
		return
	var body := _held_body
	_last_released_body = body
	body.gravity_scale = _held_prev_gravity
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	if mode == "drop":
		# Hand off carry momentum gently so a "drop" doesn't fling the body.
		body.linear_velocity = body.linear_velocity.limit_length(2.0)
	# mode "throw": the apply_impulse effect (run next in the verb's do-list) sets
	# the launch velocity along the look direction.
	_held_id = ""
	_held_body = null
	if _interactor != null:
		_interactor._on_world_released()


func host_apply_impulse(magnitude: float) -> void:
	# Throw kick along the interactor's look direction. The body was just released
	# (host_release ran first in the throw verb's do-list); re-find it is moot, so we
	# kick the last-held body if still valid.
	if _last_released_body != null and is_instance_valid(_last_released_body) and _interactor != null:
		var dir: Vector3 = _interactor.look_direction()
		_last_released_body.linear_velocity = dir * magnitude


var _last_released_body: RigidBody3D = null


func host_socket(owner_id: String, body_id: String) -> void:
	# Consume the carried body into a static socket on the owner. Frees the carry
	# (the interpreter already recorded the socket field); freeze + snap to socket.
	var body: Node = _nodes.get(body_id)
	if body is RigidBody3D:
		var rb := body as RigidBody3D
		rb.freeze = true
		rb.gravity_scale = 0.0
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		var owner_node = _nodes.get(owner_id)
		if owner_node != null and owner_node.has_method("socket_transform"):
			rb.global_transform = owner_node.socket_transform()
	# Clear carry without applying drop/throw physics.
	if _held_id == body_id:
		_held_id = ""
		_held_body = null
		if _interactor != null:
			_interactor._on_world_released()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Walk up from a collider to a registered interactable id (or "").
func _resolve_id(node: Node) -> String:
	var n := node
	while n != null:
		if _id_of_node.has(n.get_instance_id()):
			return _id_of_node[n.get_instance_id()]
		n = n.get_parent()
	return ""


func resolve_id(node: Node) -> String:
	return _resolve_id(node)


func _tags_of(kit_id: String) -> Array:
	var it: InteractionKit.Interactable = kit.interactables.get(kit_id)
	return it.tags if it != null else []
