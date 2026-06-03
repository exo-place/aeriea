## GrabbableBox — a thin scene shim over the data-driven `box` interactable
## DEFINITION in interaction/sandbox.kit.json. SLICE 1: the grab verb lives in
## DATA + the InteractionInterpreter. There are several box INSTANCES in the
## sandbox (the stack-and-parkour primitive) all sharing the one `box` definition,
## so each registers under a UNIQUE instance id (its node name) bound to the `box`
## definition — the interpreter holds a per-instance state record (empty here) and
## a shared verb set. This node carries no verb/guard/effect logic.
##
## Composition role unchanged: grab boxes -> stack under the high ledge -> parkour
## off the stack to reach an otherwise-unreachable ledge (movement × interaction).
class_name GrabbableBox
extends RigidBody3D

const DEF_ID := "box"

var _world: InteractionWorld


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("grabbable_box")
	mass = 1.5
	can_sleep = true
	_world = _find_world()
	if _world != null:
		# Unique instance id (node name) bound to the shared `box` definition.
		_world.register_instance(name, DEF_ID, self)


func _find_world() -> InteractionWorld:
	return InteractionWorld.find_in_scene(self)
