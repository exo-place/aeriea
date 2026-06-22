## SpringBone — a single secondary-motion spring-bone (verlet-style critically-ish
## damped spring) used for HAIR and SOFT-REGION JIGGLE.
##
## TECHNIQUE, not assets. Spring-bone secondary motion is a generic, decades-old
## technique (verlet hair, "dynamic bones"); this is aeriea's OWN small implementation
## — no BDCC2 code or art. Each instance tracks one skeleton bone: it remembers the
## bone's world-space tip from last frame, integrates a damped spring toward where the
## tip "wants" to be (the rest tip rigidly carried by the parent's motion), and converts
## the lag between the two into a LOCAL rotation offset layered on the bone's animated
## pose. Body motion therefore "throws" the tip and the spring chases it back.
##
## RENDER-SIDE / COSMETIC. Frame-driven (uses real delta) and never reads or writes the
## sim — its state is private and is reset on demand. The physics-y integration is
## explicitly allowed to be frame-rate-driven (it is rendering juice, not sim state);
## it is kept OUT of the sim/event-log determinism path by construction (BodyRig only
## ever calls it AFTER the deterministic pose is computed, and never reads it back).
class_name SpringBone
extends RefCounted

var bone_idx: int = -1
var rest_local: Transform3D = Transform3D.IDENTITY
## Bone-local offset to the "tip" we track (the bone's own length down its axis). The
## further the tracked point, the more visible the swing.
var tip_local: Vector3 = Vector3(0.0, 0.1, 0.0)
## The local axis a positive deflection rotates about is derived per-frame from the
## lag direction, so no fixed swing axis is needed.

## Spring state, all in the SKELETON's local space (stable under the body root moving).
var _tip_pos: Vector3 = Vector3.INF      # current simulated tip (skeleton-local)
var _tip_vel: Vector3 = Vector3.ZERO     # tip velocity (skeleton-local)
var _initialised: bool = false


## Reset the spring to rest (used by tests / teardown so the layer is reproducible).
func reset() -> void:
	_initialised = false
	_tip_pos = Vector3.INF
	_tip_vel = Vector3.ZERO


## Integrate one step and return the LOCAL rotation offset (Quaternion) to layer on
## the bone's current animated pose. `skel` must already hold the bone's animated
## (pre-secondary) pose for this frame.
##
## stiffness: restoring rate (per second). damping: velocity bleed (per second).
## gain: how strongly the lag becomes deflection. max_angle: clamp (radians).
func step(skel: Skeleton3D, delta: float, stiffness: float, damping: float,
		gain: float, max_angle: float) -> Quaternion:
	if bone_idx < 0 or delta <= 0.0:
		return Quaternion.IDENTITY

	# The rest tip = where the tip would be if the bone held its ANIMATED pose with no
	# secondary motion (rigidly carried by the parent + the base animation). Computed in
	# WORLD space (skeleton.global_transform * bone global pose) so the spring feels the
	# BODY moving through the world (walking, jolts), not just the in-skeleton animation —
	# moving the body throws the tip and the spring chases it back.
	var world := skel.global_transform
	var bone_pose := world * skel.get_bone_global_pose(bone_idx)
	var rest_tip := bone_pose * tip_local

	if not _initialised:
		_tip_pos = rest_tip
		_tip_vel = Vector3.ZERO
		_initialised = true
		return Quaternion.IDENTITY

	# Damped spring toward the rest tip. The lag between _tip_pos and rest_tip is what
	# body motion produces (the rest tip jumps when the body moves; the sim tip chases).
	var to_rest := rest_tip - _tip_pos
	var accel := to_rest * stiffness - _tip_vel * damping
	_tip_vel += accel * delta
	_tip_pos += _tip_vel * delta

	# Deflection = the angle/axis between the rest tip direction and the simulated tip
	# direction, as seen from the bone's origin. Scaled by gain, clamped.
	var origin := bone_pose.origin
	var v_rest := (rest_tip - origin)
	var v_sim := (_tip_pos - origin)
	if v_rest.length_squared() < 1e-10 or v_sim.length_squared() < 1e-10:
		return Quaternion.IDENTITY
	v_rest = v_rest.normalized()
	v_sim = v_sim.normalized()
	var axis := v_rest.cross(v_sim)
	if axis.length_squared() < 1e-12:
		return Quaternion.IDENTITY
	axis = axis.normalized()
	var angle := clampf(v_rest.angle_to(v_sim) * gain, 0.0, max_angle)
	if angle < 1e-6:
		return Quaternion.IDENTITY
	# The deflection is in skeleton-local space; convert the axis into the bone's LOCAL
	# frame so the returned quaternion composes onto the bone's local pose rotation.
	var local_axis := (bone_pose.basis.inverse() * axis).normalized()
	return Quaternion(local_axis, angle)
