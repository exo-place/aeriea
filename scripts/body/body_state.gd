## BodyState — the serializable body-morph parameter record (the single source of
## truth for body morphology), per docs/decisions/body-and-locomotion-slice.md §2.1.
##
## SLICE 2 deliverable. The morph axes are not just art knobs: they project to a
## small, serializable record that the simulation and the affordance layer read,
## exactly in the spirit of "simulation underneath, rendering on top" (DESIGN.md).
## BodyState is DATA (like MovementState and the interactable state maps) — part of
## the seeded sim, deterministic, serializable to/from a plain Dictionary so it fits
## seed + action-log replay.
##
## Two roles:
##   1. RENDER PROJECTION — BodyState -> blendshape weights on the §1 base body
##      ArrayMesh. `apply_to(mesh_instance, mesh)` is a PURE deterministic projection:
##      each macro axis drives the corresponding `.target`-derived blendshape(s).
##      The morph space stays CONTINUOUS and orthogonal (DESIGN.md, Age × NSFW: the
##      morph space must stay smooth; primitives are not crippled).
##   2. THE LAYER-1 NSFW GATE INPUT — `is_adult_body()` is the derived predicate the
##      affordance substrate's guard layer consults (§2.2). It is a PURE function of
##      `age` over the continuous axis. The age axis itself is NOT crippled (baby /
##      child / young / old all representable); the gate is a predicate OVER it.
##
## This is the SAME parametric morph vector the design notes the animation
## controller will later be conditioned on (§2.1 / §3.5 the morphology-
## parameterization interlock) — one parameterization, body + (future) controller.
class_name BodyState
extends RefCounted

# ---------------------------------------------------------------------------
# The macro morph axes (§2.1). All continuous; all default to the neutral young
# adult base (the MakeHuman base mesh IS the young-adult neutral, so weight 0 on
# every blendshape = the base = a neutral young adult). age defaults to ADULT.
# ---------------------------------------------------------------------------

## 0..1 female<->male macro blend. 0 = the base mesh (caucasian-female-young).
var gender: float = 0.0
## CONTINUOUS age axis (§2.2). 0 = baby, AGE_CHILD = child, AGE_YOUNG = young adult
## (the neutral base), 1 = old. Smooth interpolation between the anchored age morphs.
## Defaults to the young-adult anchor (adult).
var age: float = 0.5
## 0..1 muscle (0 = base/average, 1 = max muscle).
var muscle: float = 0.0
## 0..1 weight/BMI (0 = base/average, 1 = max weight).
var weight: float = 0.0
## 0..1 height (0 = base/average, 1 = max height; maps to real metres per
## units-and-scale.md as the height blendshape's range).
var height: float = 0.0
## 0..1 proportions axis (within-form proportion envelope). Reserved as a first-class
## macro axis (§2.1); no dedicated blendshape in the Slice-1 starter set yet, so it is
## carried in the record (serialized, gated, future-driving) without a weight mapping.
var proportions: float = 0.5

# ---------------------------------------------------------------------------
# Age-axis anchors (§2.2). The MakeHuman age macro ships discrete anchors which we
# read as a CONTINUOUS parameter interpolating between them. The base mesh is the
# YOUNG anchor, so age_young has NO blendshape (weight 0 of the others = young).
# ---------------------------------------------------------------------------

## age == AGE_BABY  -> full age_baby blendshape.
const AGE_BABY := 0.0
## age == AGE_CHILD -> full age_child blendshape (MakeHuman child anchor ~0.1875).
const AGE_CHILD := 0.1875
## age == AGE_YOUNG -> the neutral base mesh (young adult ~25yo); all age weights 0.
const AGE_YOUNG := 0.5
## age == AGE_OLD   -> full age_old blendshape.
const AGE_OLD := 1.0

## The Layer-1 adult-body-state threshold (§2.2). `is_adult_body()` is true iff
## `age >= ADULT_AGE_THRESHOLD`. Pinned CONSERVATIVELY to the young-adult anchor
## (AGE_YOUNG): the gate requires reaching the unambiguously-adult young anchor, so
## the entire child->young transition (which passes through adolescent morphs) is
## EXCLUDED from the adult-body-state. This is the safe direction for a hard legal
## gate — gate MORE rather than risk admitting a non-adult body. The age axis is NOT
## notched here: this is a predicate read OVER the smooth axis, not a discontinuity
## carved into it (DESIGN.md, Age × NSFW — gate the configuration, not the primitive).
const ADULT_AGE_THRESHOLD := AGE_YOUNG

# ---------------------------------------------------------------------------
# The derived Layer-1 gate predicate (§2.2). PURE function of body-state.
# ---------------------------------------------------------------------------

## is_adult_body — the checkable body-state the affordance substrate's guard layer
## reads for the Layer-1 NSFW gate (DESIGN.md Layer 1; §2.2). True iff the continuous
## age axis is at/above the adult threshold. Deterministic; part of the sim.
##
## Gate the INTERSECTION (child-range body-state × NSFW verb), NOT the age primitive:
## this returns a boolean OVER the continuous axis; the axis stays complete so
## ordinary NPCs of every age remain representable.
func is_adult_body() -> bool:
	return age >= ADULT_AGE_THRESHOLD

# ---------------------------------------------------------------------------
# The render projection (§2.1). BodyState -> blendshape weights. PURE & deterministic.
# ---------------------------------------------------------------------------

## Project this BodyState to the per-blendshape weight map for the Slice-1 starter
## axis set. Returns { blendshape_name: weight } — a pure function of the record.
## The age axis fans out to the three age anchor-blendshapes (baby/child/old; young is
## the base = weight 0) by piecewise-linear interpolation over the continuous `age`.
## Continuity is preserved: every weight is a continuous function of the inputs, so
## sweeping any axis morphs the mesh smoothly with no discontinuity (the morph space
## stays smooth — DESIGN.md).
func to_blend_weights() -> Dictionary:
	var w := {
		"gender_male": clampf(gender, 0.0, 1.0),
		"muscle_max": clampf(muscle, 0.0, 1.0),
		"weight_max": clampf(weight, 0.0, 1.0),
		"height_max": clampf(height, 0.0, 1.0),
		"age_baby": 0.0,
		"age_child": 0.0,
		"age_old": 0.0,
	}
	var a := clampf(age, 0.0, 1.0)
	# Piecewise-linear over the anchors: baby(0) -> child(0.1875) -> young(0.5,base) -> old(1).
	if a <= AGE_CHILD:
		# baby..child: baby weight falls 1->0, child weight rises 0->1.
		var t := a / AGE_CHILD if AGE_CHILD > 0.0 else 0.0
		w["age_baby"] = 1.0 - t
		w["age_child"] = t
	elif a <= AGE_YOUNG:
		# child..young(base): child weight falls 1->0, age weights -> 0 at young.
		var t := (a - AGE_CHILD) / (AGE_YOUNG - AGE_CHILD)
		w["age_child"] = 1.0 - t
	else:
		# young(base)..old: old weight rises 0->1.
		var t := (a - AGE_YOUNG) / (AGE_OLD - AGE_YOUNG)
		w["age_old"] = t
	return w

## Drive the blendshape weights on a MeshInstance3D whose mesh is the §1 base body.
## Sets only the blendshapes the mesh actually declares (by name) — unknown axes in
## the projection are ignored, so a mesh with a subset of the starter axes still works.
## This is the BodyState -> render seam: setting BodyState fields then calling this
## morphs the body. Pure w.r.t. BodyState (the same BodyState -> the same weights).
func apply_to(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh as ArrayMesh
	if mesh == null:
		return
	var weights := to_blend_weights()
	var available := {}
	for i in mesh.get_blend_shape_count():
		available[str(mesh.get_blend_shape_name(i))] = true
	for axis in weights:
		if available.has(axis):
			mesh_instance.set("blend_shapes/%s" % axis, float(weights[axis]))

# ---------------------------------------------------------------------------
# Serialization (§2.1 — BodyState is data, part of the seeded sim). Round-trips
# through a plain Dictionary (the JSON wire form) for replay / transport / diff.
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"gender": gender,
		"age": age,
		"muscle": muscle,
		"weight": weight,
		"height": height,
		"proportions": proportions,
	}

static func from_dict(d: Dictionary) -> BodyState:
	var bs := BodyState.new()
	bs.gender = float(d.get("gender", 0.0))
	bs.age = float(d.get("age", 0.5))
	bs.muscle = float(d.get("muscle", 0.0))
	bs.weight = float(d.get("weight", 0.0))
	bs.height = float(d.get("height", 0.0))
	bs.proportions = float(d.get("proportions", 0.5))
	return bs

func duplicate_state() -> BodyState:
	return BodyState.from_dict(to_dict())
