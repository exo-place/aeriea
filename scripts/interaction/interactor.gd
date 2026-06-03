## Interactor — first-person interaction system that rides alongside the
## InterpretedPlayer. This is the HAND-BUILT vertical-slice proof that a single
## spot in the world can be a DENSE, COMPOSABLE node: standing still, the player
## is offered several distinct command-type affordances that CHAIN into one
## another (and into MOVEMENT) to produce real state changes and unlocks.
##
## It is deliberately NOT a data-driven affordance substrate yet (that extraction
## comes later, the way the movement substrate was lifted out of the imperative
## controller). But every affordance here is kept as a DISCRETE, INSPECTABLE unit
## — a small set of named verbs (grab / drop / throw / use) dispatched against an
## `Interactable` that advertises which verbs it currently affords — so a later
## pass can read the same structure off data instead of code. Today the "graph"
## is: look-at → the Interactable under the reticle names its available edges →
## the player executes one → state changes → a NEW set of edges is available.
##
## Capability-style discipline (mirrors the ecosystem principle): the interactor
## only ever acts on the ONE interactable currently under the reticle (or the one
## currently held). It never reaches into arbitrary world state.
##
## Diegetic legibility (low opacity, Miller-compliant): looking at an interactable
## (a) tints the reticle and (b) surfaces only the minimal contextual verb prompt
## for what is possible RIGHT NOW (e.g. "[E] Grab", "[E] Turn valve", "[E] Place
## jug"). No standing HUD menu, no manual. The player perceives the edge set by
## looking. See docs/decisions/reference-analysis.md §6 (the positive inverse:
## dense composable command edges, ≤7, surfaced by removal not prioritization).
class_name Interactor
extends Node3D

## How far the look-ray reaches for interaction (metres).
@export var reach: float = 3.0
## Distance in front of the camera at which a held object is carried.
@export var hold_distance: float = 1.6
## Spring strength pulling a held body to the carry point.
@export var hold_stiffness: float = 18.0
## Impulse applied on throw (along the look direction).
@export var throw_impulse: float = 8.0

## The camera we raycast from — resolved from the player rig in _ready.
var _camera: Camera3D
## The player body (CharacterBody3D) we ride alongside; excluded from the ray.
var _player: CharacterBody3D

## The interactable currently under the reticle (or null). This is the node whose
## affordance edges are "live" — the only thing look-at interaction can act on.
var _focused: Node = null
## The body we are currently carrying (or null). Grab/drop/throw act on this.
var _held: RigidBody3D = null
## Saved physics properties of the held body, restored on release.
var _held_prev_gravity: float = 0.0

## Emitted whenever the focused interactable (or held state) changes, carrying the
## minimal contextual prompt text to show. The HUD listens; this keeps the
## interactor render-agnostic (the prompt is data, the label is a projection).
signal prompt_changed(text: String)
## Emitted with a 0..1 "focus strength" so the reticle can signal focus diegetically.
signal focus_changed(focused: bool)


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	# The InterpretedPlayer builds its camera rig in _ready and names the camera
	# "Camera3D" under a "CameraPivot". Resolve it after the player is ready.
	await get_tree().process_frame
	_camera = _resolve_camera()


## Find the player's first-person camera. The InterpretedPlayer creates
## CameraPivot/Camera3D in code; fall back to any Camera3D in the player subtree.
func _resolve_camera() -> Camera3D:
	if _player == null:
		return null
	var pivot := _player.get_node_or_null("CameraPivot")
	if pivot:
		var cam := pivot.get_node_or_null("Camera3D")
		if cam is Camera3D:
			return cam as Camera3D
	for child in _player.find_children("*", "Camera3D", true, false):
		return child as Camera3D
	return null


func _physics_process(delta: float) -> void:
	if _camera == null:
		_camera = _resolve_camera()
		if _camera == null:
			return

	_update_focus()
	_carry_held(delta)


## Cast the look-ray and update which interactable is focused. Drives the diegetic
## prompt + reticle. While carrying, focus is suppressed (the live edge set is
## drop/throw, surfaced from the held state, not from a look target).
func _update_focus() -> void:
	if _held != null:
		# While carrying, the live edges are drop/throw — UNLESS the reticle is on a
		# target that accepts the held object (e.g. a pedestal). Then surface that
		# target's contextual verb (e.g. "Place full jug"), because placing is the
		# composing edge the carry exists for. This keeps the held-mode edge set
		# contextual, not a fixed two-verb stub.
		var place_target := _placement_target_under_reticle()
		if place_target != null:
			_set_focus(place_target)
			emit_signal("prompt_changed", place_target.affordance_prompt(self))
		else:
			_set_focus(null)
			emit_signal("prompt_changed", "[E] Drop    [F] Throw")
		return

	var hit := _raycast()
	var target: Node = null
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		target = _interactable_of(collider as Node)
	_set_focus(target)


## Cast from the camera straight ahead `reach` metres. Returns the raw hit dict.
func _raycast() -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_transform.basis.z * reach
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [_player]
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return space.intersect_ray(params)


## Walk up from a collider to the nearest node that is (or has) an Interactable.
## Interactables are bodies with the `interactable` group or an `interactable`
## script method surface; we treat any node implementing `affordance_prompt` and
## `interact` as an interactable, so the contract is a duck-typed verb surface.
func _interactable_of(node: Node) -> Node:
	var n := node
	while n != null:
		if n.has_method("affordance_prompt") and n.has_method("interact"):
			return n
		n = n.get_parent()
	return null


## While carrying, raycast and return a focused interactable that ACCEPTS the held
## object (it advertises `accepts_held(body)`), else null. This is the seam where a
## carried-object verb composes with a target: the pedestal accepts a jug.
func _placement_target_under_reticle() -> Node:
	var hit := _raycast()
	if hit.is_empty():
		return null
	var node := _interactable_of(hit.get("collider") as Node)
	if node != null and node.has_method("accepts_held") and node.accepts_held(_held):
		return node
	return null


func _set_focus(target: Node) -> void:
	if target == _focused:
		# Even if the node is unchanged, its prompt may have changed (state moved),
		# so refresh the prompt from the live node every tick it's focused.
		if _focused != null:
			emit_signal("prompt_changed", _focused.affordance_prompt(self))
		return
	_focused = target
	emit_signal("focus_changed", target != null)
	if target != null:
		emit_signal("prompt_changed", target.affordance_prompt(self))
	else:
		emit_signal("prompt_changed", "")


## Spring the held body to a point in front of the camera so it reads as "carried".
func _carry_held(_delta: float) -> void:
	if _held == null:
		return
	if not is_instance_valid(_held):
		_held = null
		return
	var target := _camera.global_position - _camera.global_transform.basis.z * hold_distance
	var to_target := target - _held.global_position
	# Critically-damped-ish velocity spring: snappy carry without orbiting.
	_held.linear_velocity = to_target * hold_stiffness
	_held.angular_velocity = _held.angular_velocity.lerp(Vector3.ZERO, 0.3)


# ---------------------------------------------------------------------------
# Verb surface — the discrete, inspectable affordance units. Each is a command
# edge in the interaction graph. A future data substrate would name these verbs
# + their guards as data; today they are methods, but they are SMALL and named.
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event.is_action_pressed("interact"):
		_do_primary()
	elif event.is_action_pressed("throw"):
		_do_throw()


## Primary verb (E): context-dependent — the crux of "the same spot affords
## several things". If carrying, DROP. Else if a focused interactable affords a
## grab and is a RigidBody3D, GRAB it. Else dispatch the focused interactable's
## own `interact` verb (use valve / fill jug / place jug / flip switch …).
func _do_primary() -> void:
	if _held != null:
		# If the reticle is on a target that accepts the held object, run its verb
		# (the placing/composing edge). Otherwise the primary verb is DROP.
		var place_target := _placement_target_under_reticle()
		if place_target != null:
			place_target.interact(self)
			return
		_drop()
		return
	if _focused == null:
		return
	# A grabbable interactable hands us the body to carry; everything else runs
	# its own interact() (state-changing command).
	if _focused.has_method("grab_body"):
		var body: RigidBody3D = _focused.grab_body(self)
		if body != null:
			_grab(body)
			return
	_focused.interact(self)
	# State may have changed — refresh the prompt immediately so the player sees
	# the new live edge set without moving the reticle (legibility).
	if _focused != null and is_instance_valid(_focused):
		emit_signal("prompt_changed", _focused.affordance_prompt(self))


## Grab: take ownership of a RigidBody3D, suppress its gravity, carry it.
func _grab(body: RigidBody3D) -> void:
	_held = body
	_held_prev_gravity = body.gravity_scale
	body.gravity_scale = 0.0
	body.linear_damp = 6.0
	body.angular_damp = 6.0
	_set_focus(null)
	emit_signal("prompt_changed", "[E] Drop    [F] Throw")


## Drop: release the held body where it is, restoring physics.
func _drop() -> void:
	_release(Vector3.ZERO)


## Throw: release with an impulse along the look direction.
func _do_throw() -> void:
	if _held == null:
		return
	var dir := -_camera.global_transform.basis.z
	_release(dir * throw_impulse)


func _release(impulse: Vector3) -> void:
	if _held == null or not is_instance_valid(_held):
		_held = null
		return
	var body := _held
	body.gravity_scale = _held_prev_gravity
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	if impulse != Vector3.ZERO:
		body.linear_velocity = impulse
	else:
		# Hand off carry momentum gently so a "drop" doesn't fling the body.
		body.linear_velocity = body.linear_velocity.limit_length(2.0)
	_held = null
	emit_signal("prompt_changed", "")


# ---------------------------------------------------------------------------
# Inspection accessors — read by the behavioral test to assert outcomes without
# reaching into private state. Keep the test driving the REAL interaction path.
# ---------------------------------------------------------------------------

func held_body() -> RigidBody3D:
	return _held if is_instance_valid(_held) else null


## Relinquish the held body WITHOUT applying drop/throw physics — used when another
## interactable (the pedestal) consumes the carried object. Clears carry state so
## the interactor stops springing it; the consumer owns the body afterward.
func force_release() -> void:
	_held = null
	emit_signal("prompt_changed", "")

func focused() -> Node:
	return _focused

func current_prompt() -> String:
	# When holding, _focused is the placement target (if the reticle is on one),
	# else null → drop/throw. Mirror _update_focus's held-branch logic.
	if _held != null:
		var place_target := _placement_target_under_reticle()
		if place_target != null:
			return place_target.affordance_prompt(self)
		return "[E] Drop    [F] Throw"
	if _focused != null and is_instance_valid(_focused):
		return _focused.affordance_prompt(self)
	return ""
