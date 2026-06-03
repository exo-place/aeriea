## GrabbableBox — a portable physics prop (the stack-and-parkour primitive).
##
## This is the simplest interactable: a RigidBody3D the player can GRAB, carry,
## DROP, STACK, and THROW. Its whole point in the slice is the MOVEMENT × INTERACTION
## composition: grab boxes → stack them under the high ledge → parkour off the
## stack to reach an otherwise-unreachable ledge. Movement and interaction compose
## into a reach the player could not achieve with either alone — the strongest
## anti-barren-node demonstration (reference-analysis.md §6).
##
## Affordance surface (the duck-typed interactable contract): affordance_prompt +
## interact + grab_body. It is grabbable, so the interactor's primary verb takes
## the body rather than calling interact().
class_name GrabbableBox
extends RigidBody3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("grabbable_box")
	# Boxes should rest stably when stacked: moderate mass, some damping so a
	# placed box settles instead of sliding off the stack.
	mass = 1.5
	can_sleep = true


## Diegetic prompt shown when the reticle is on this box. Minimal, contextual.
func affordance_prompt(_interactor) -> String:
	return "[E] Pick up    (stack boxes to climb)"


## Grabbable: hand the interactor THIS body to carry.
func grab_body(_interactor) -> RigidBody3D:
	return self


## interact() is the fallback verb; for a box, primary already routes through
## grab_body, so interact is a no-op. Present so it satisfies the interactable
## contract uniformly.
func interact(_interactor) -> void:
	pass
