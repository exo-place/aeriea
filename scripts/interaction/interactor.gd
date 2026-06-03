## Interactor — first-person interaction driver that rides alongside the
## InterpretedPlayer. SLICE 1 of the affordance substrate: this is no longer a
## hand-wired verb dispatcher. It is now the HOST-SIDE FRAME RESOLVER for the
## data-driven InteractionInterpreter (docs/decisions/affordance-substrate.md §5):
## once per physics tick it resolves the focus (one look-ray), samples the
## interact/throw input EDGES, and asks the InteractionWorld to step the
## interpreter with that immutable frame. All verb/guard/effect/prompt logic lives
## in interaction/sandbox.kit.json + the interpreter; this script owns ONLY the
## irreducible engine seam: the look-ray, the carry SPRING, and the input edges.
##
## Determinism crux (§5): focus + input are sampled ONCE per tick into the frame.
## No guard/effect re-raycasts or reads Input.* mid-tick — the interpreter reads
## the resolved frame. _do_primary/_do_throw/_drop synthesize a single edge and run
## one interpreter step (the same path a key press takes), so the behavioral test
## drives the REAL data-driven affordance path end to end.
##
## Capability discipline is preserved structurally: a verb's target resolves to the
## ONE focused interactable (or the held body), never arbitrary world state.
class_name Interactor
extends Node3D

## How far the look-ray reaches for interaction (metres).
@export var reach: float = 3.0
## Distance in front of the camera at which a held object is carried.
@export var hold_distance: float = 1.6
## Spring strength pulling a held body to the carry point.
@export var hold_stiffness: float = 18.0
## Impulse applied on throw (along the look direction). Mirrors the kit param.
@export var throw_impulse: float = 8.0

var _camera: Camera3D
var _player: CharacterBody3D
var _world: InteractionWorld

## The interactable kit id currently under the reticle (or ""). Resolved once/tick.
var _focus_id: String = ""

## Emitted whenever the prompt changes (HUD listens; prompt is data, label is a
## projection). focus_changed drives the reticle.
signal prompt_changed(text: String)
signal focus_changed(focused: bool)

var _last_prompt: String = ""
var _last_focused: bool = false


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	await get_tree().process_frame
	_camera = _resolve_camera()
	_world = _resolve_world()
	if _world != null and _player != null:
		_world.register_interactor(self, _player)


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


func _resolve_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)


func _physics_process(delta: float) -> void:
	if _camera == null:
		_camera = _resolve_camera()
		if _camera == null:
			return
	if _world == null:
		_world = _resolve_world()
		if _world != null and _player != null:
			_world.register_interactor(self, _player)
		if _world == null:
			return

	# 1. Resolve focus once (one look-ray). While carrying, focus is the placement
	#    target under the reticle (else none -> drop/throw line).
	_focus_id = _resolve_focus()

	# 2. Sample input edges once and step the interpreter (real input path).
	var edges := {
		"interact": Input.is_action_just_pressed("interact"),
		"throw": Input.is_action_just_pressed("throw"),
	}
	_world.step_with(_focus_id, edges, delta)

	# 3. Carry spring (physics, in-engine).
	_carry_held(delta)

	# 4. Project the prompt (render-side).
	_refresh_prompt()


## Resolve the focused interactable kit id from the look-ray. While carrying, only
## a target that accepts the held body (a `place` verb) counts as focus (so the
## place edge surfaces); otherwise focus is "" and the prompt is the drop/throw line.
func _resolve_focus() -> String:
	var hit := _raycast()
	if hit.is_empty():
		return ""
	var id := _world.resolve_id(hit.get("collider") as Node)
	return id


func _raycast() -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_transform.basis.z * reach
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [_player]
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return space.intersect_ray(params)


func _carry_held(_delta: float) -> void:
	var held := _world.held_body()
	if held == null:
		return
	var target := _camera.global_position - _camera.global_transform.basis.z * hold_distance
	var to_target := target - held.global_position
	held.linear_velocity = to_target * hold_stiffness
	held.angular_velocity = held.angular_velocity.lerp(Vector3.ZERO, 0.3)


# ---------------------------------------------------------------------------
# Input -> single-edge interpreter steps. The same path a key press takes; the
# behavioral test calls these directly to drive the real data-driven path.
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null or _world == null:
		return
	if event.is_action_pressed("interact"):
		_do_primary()
	elif event.is_action_pressed("throw"):
		_do_throw()


## Fire the primary (interact) verb: resolve focus, then run ONE interpreter step
## with the interact edge set. The interpreter picks the verb by kind/guard
## precedence (place > drop > grab > command) — all data-ordered.
func _do_primary() -> void:
	if _world == null:
		return
	_focus_id = _resolve_focus()
	_world.step_with(_focus_id, { "interact": true, "throw": false }, _phys_dt())
	_refresh_prompt()


func _do_throw() -> void:
	if _world == null:
		return
	_focus_id = _resolve_focus()
	_world.step_with(_focus_id, { "interact": false, "throw": true }, _phys_dt())
	_refresh_prompt()


## Drop without throw — used by the test to place a box on the stack. Runs the
## drop edge (interact while held with no place target).
func _drop() -> void:
	if _world == null:
		return
	# Force a non-place focus so the interact edge resolves to drop.
	_world.step_with("", { "interact": true, "throw": false }, _phys_dt())
	_refresh_prompt()


func _phys_dt() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


# ---------------------------------------------------------------------------
# World callbacks (the host notifies us of carry state changes for the HUD).
# ---------------------------------------------------------------------------

func _on_world_grabbed() -> void:
	_emit_prompt("[E] Drop    [F] Throw")
	_set_focused(false)


func _on_world_released() -> void:
	_emit_prompt("")


func look_direction() -> Vector3:
	if _camera == null:
		return Vector3.FORWARD
	return -_camera.global_transform.basis.z


# ---------------------------------------------------------------------------
# Prompt projection (render-side; the interpreter computes the text).
# ---------------------------------------------------------------------------

func _refresh_prompt() -> void:
	var text := current_prompt()
	_emit_prompt(text)
	_set_focused(_world != null and (_focus_id != "" or _world.held_kit_id() != ""))


func _emit_prompt(text: String) -> void:
	if text != _last_prompt:
		_last_prompt = text
		emit_signal("prompt_changed", text)


func _set_focused(focused: bool) -> void:
	if focused != _last_focused:
		_last_focused = focused
		emit_signal("focus_changed", focused)


# ---------------------------------------------------------------------------
# Inspection accessors (read by the behavioral test). Keep the test driving the
# REAL interaction path; these only read interpreter/host state.
# ---------------------------------------------------------------------------

func held_body() -> RigidBody3D:
	return _world.held_body() if _world != null else null


## Relinquish the held body without drop/throw physics (legacy compat — the
## pedestal's consume_into_socket now drives this through the host).
func force_release() -> void:
	if _world != null:
		_world.host_socket("", _world.held_kit_id())


func focused() -> Node:
	if _world == null or _focus_id == "":
		return null
	return _world.node_for(_focus_id)


func current_prompt() -> String:
	if _world == null:
		return ""
	if _world.held_kit_id() != "":
		var pid := _resolve_focus()
		var prompt := _world.project_prompt(pid)
		return prompt
	return _world.project_prompt(_focus_id)
