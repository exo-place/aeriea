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
## 0..1 proportions axis (within-form proportion envelope, §2.1). BIDIRECTIONAL,
## anchored on the base mesh at the midpoint: 0 = full "uncommon" proportions,
## 0.5 = the base mesh (average proportions, no weight), 1 = full "ideal" proportions
## — the two MakeHuman proportions anchors (uncommon/ideal). Maps to the
## proportions_uncommon / proportions_ideal blendshapes (see to_blend_weights()).
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
		"proportions_ideal": 0.0,
		"proportions_uncommon": 0.0,
	}
	# Proportions is bidirectional about the base (0.5). Below 0.5 fades in the
	# "uncommon" anchor; above 0.5 fades in the "ideal" anchor; exactly 0.5 = base
	# (both weights 0). Continuous and orthogonal to the other axes.
	var pr := clampf(proportions, 0.0, 1.0)
	if pr < 0.5:
		w["proportions_uncommon"] = (0.5 - pr) / 0.5
	elif pr > 0.5:
		w["proportions_ideal"] = (pr - 0.5) / 0.5
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

## Bake the FULL current morph (positions AND recomputed normals) onto the mesh's
## base surface on the CPU, and return the per-axis GPU blend weights that must be
## ZEROED so the GPU does not double-apply the morph.
##
## Why CPU, not GPU blendshapes: Godot 4 stores all surface/blendshape normals
## OCTAHEDRAL-COMPRESSED (unit-direction only), so a blendshape normal array cannot
## carry a normal DELTA (see tools/body_converter.gd) — the GPU morph leaves normals
## wrong (blotchy / blown-out / inside-out) no matter what delta is stored. The
## accurate data is in the VERTEX deltas (positions aren't unit-constrained), so we
## reconstruct morphed_pos = base + Σ wᵢ·Δvᵢ on the CPU, recompute exact area-weighted
## normals, and write BOTH back into the base surface. The caller then sets every GPU
## blend weight to 0 (apply_morph_cpu does this), so the GPU contributes nothing and
## the lit surface is exactly the CPU-correct morphed body at all weights.
##
## Call on each morph change (cheap on a slider move; do NOT call per frame). The
## ArrayMesh MUST be a per-instance copy — it is rebuilt in place. The mesh's STORED
## base arrays must be the NEUTRAL base (this reads them fresh each call and re-applies
## the full current morph from neutral, so repeated calls are stable and not cumulative
## only if the stored base is neutral — apply_morph_cpu keeps that invariant by always
## baking from a preserved neutral copy held on the MeshInstance via metadata).
func bake_morphed_normals(mesh: ArrayMesh, base_pos: PackedVector3Array,
		weights_override: Dictionary = {}) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var tris: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n := base_pos.size()
	# Reconstruct the morphed positions on the CPU from the NEUTRAL base + vertex deltas.
	# Callers may supply an explicit { blendshape_name: weight } map (the demo's raw
	# per-blendshape sliders); default is the BodyState macro-axis projection.
	var weights := weights_override if not weights_override.is_empty() else to_blend_weights()
	var morphed := base_pos.duplicate()
	var bs_arrays := mesh.surface_get_blend_shape_arrays(0)
	for i in mesh.get_blend_shape_count():
		var axis := str(mesh.get_blend_shape_name(i))
		var w := float(weights.get(axis, 0.0))
		if absf(w) < 1e-6:
			continue
		var dv: PackedVector3Array = bs_arrays[i][Mesh.ARRAY_VERTEX]
		if dv.size() != n:
			continue
		for vi in n:
			morphed[vi] = morphed[vi] + dv[vi] * w
	# Area-weighted smooth normals over the triangle list (same accumulation as the
	# converter's _compute_normals, so the neutral case reproduces the baked normals).
	var normals := PackedVector3Array()
	normals.resize(n)
	for i in n:
		normals[i] = Vector3.ZERO
	var t := 0
	while t < tris.size():
		var a := tris[t]; var b := tris[t + 1]; var c := tris[t + 2]
		var fn := (morphed[b] - morphed[a]).cross(morphed[c] - morphed[a])
		normals[a] += fn; normals[b] += fn; normals[c] += fn
		t += 3
	for i in n:
		var ln := normals[i]
		normals[i] = ln.normalized() if ln.length() > 1e-9 else Vector3.UP
	# Write morphed POSITIONS and NORMALS into the base surface; keep the blendshapes
	# attached (their weights are zeroed by the caller so they add nothing) so the
	# surface still declares them and the skin/format are unchanged.
	arrays[Mesh.ARRAY_VERTEX] = morphed
	arrays[Mesh.ARRAY_NORMAL] = normals
	var blends := mesh.surface_get_blend_shape_arrays(0)
	var fmt := mesh.surface_get_format(0)
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends, {}, fmt)
	mesh.surface_set_name(0, "body")

## CPU-morph driver for static viewers (the character creator): bake the full morph
## onto a per-instance mesh and zero the GPU blend weights so nothing is double-applied.
## `mesh_instance.mesh` must be a per-instance ArrayMesh copy. The neutral base
## positions are captured once into instance metadata so every call bakes from neutral
## (stable, non-cumulative). Use this INSTEAD of apply_to for a correctly-lit morph.
func apply_morph_cpu(mesh_instance: MeshInstance3D, weights_override: Dictionary = {}) -> void:
	var mesh := mesh_instance.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0:
		return
	# Capture the neutral base positions once (before any bake mutates the surface).
	var base_pos: PackedVector3Array
	if mesh_instance.has_meta("neutral_base_pos"):
		base_pos = mesh_instance.get_meta("neutral_base_pos")
	else:
		base_pos = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		mesh_instance.set_meta("neutral_base_pos", base_pos)
	bake_morphed_normals(mesh, base_pos, weights_override)
	# Zero every GPU blend weight: the morph is fully baked on the CPU now.
	for i in mesh.get_blend_shape_count():
		mesh_instance.set("blend_shapes/%s" % mesh.get_blend_shape_name(i), 0.0)

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
