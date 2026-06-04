## BodyState — the serializable body-morph parameter record (the single source of
## truth for body morphology), per docs/decisions/body-parameterization.md (the
## natural-unit overhaul) which supersedes body-and-locomotion-slice.md §2.1.
##
## SLICE A deliverable (body-parameterization.md §9, Phase A): the PUBLIC API is now
## in NATURAL UNITS (years, percentages) with two independent sex axes; the raw 0–1
## MakeHuman macro weights are demoted to an INTERNAL detail computed inside
## to_blend_weights(). The gate is re-expressed to `age_years >= 18.0`. Slice A uses
## ONLY the existing 9 blendshapes (no new target imports — those are Slices B/C), so
## the CPU-morph render path (apply_morph_cpu / apply_to / BodyRig.apply_body_state)
## is byte-for-byte unchanged in behavior; only the public field shape changed.
##
## BodyState is DATA (like MovementState and the interactable state maps) — part of
## the seeded sim, deterministic, serializable to/from a plain Dictionary so it fits
## seed + action-log replay.
##
## Two roles:
##   1. RENDER PROJECTION — BodyState -> blendshape weights on the base body ArrayMesh.
##      `apply_to` / `apply_morph_cpu` are PURE deterministic projections: the natural
##      -unit fields convert to the raw macro weights, which drive the `.target`-derived
##      blendshapes. The morph space stays CONTINUOUS (DESIGN.md, Age × NSFW: the morph
##      space must stay smooth; primitives are not crippled).
##   2. THE LAYER-1 NSFW GATE INPUT — `is_adult_body()` is the derived predicate the
##      affordance substrate's guard layer consults (body-parameterization.md §5). It
##      is a PURE function of `age_years` over the continuous axis. The age axis itself
##      is NOT crippled (baby / child / young / old all representable); the gate is a
##      predicate OVER it, reading the SELF-EVIDENT natural-unit `>= 18 years` line.
class_name BodyState
extends RefCounted

# ---------------------------------------------------------------------------
# The headline natural-unit macro axes (body-parameterization.md §2/§3). All
# continuous; all default to the neutral young adult base. The MakeHuman base mesh
# IS the caucasian-female-young-average neutral, so the defaults below project to
# weight 0 on every blendshape = the base = a neutral 25-year-old female.
# ---------------------------------------------------------------------------

## Real age in YEARS, 1.0 … 90.0 (default 25 = the young-adult neutral base).
## Converted to the MakeHuman age macro 0–1 internally via the verified §1.4
## piecewise map. This is the PUBLIC field the gate reads — `>= 18 years` is the
## self-evident legal line, unlike the opaque old `age >= 0.5`.
var age_years: float = 25.0
## Feminine-coded morph amount, 0 … 100 %.
##
## PROVISIONAL LIMITATION (Slice A): the base mesh is caucasian-FEMALE-young, and the
## only sex blendshape imported so far is `gender_male` (a masculinizing target). There
## is NO feminizing `.target` available yet (Slice C imports the full library). So this
## axis is represented HONESTLY in the API and serialization, but in Slice A it has no
## morph target to drive — the base mesh is already the feminine pole. We deliberately
## DO NOT fake a feminization morph (e.g. by abusing -gender_male, which would just
## masculinize-in-reverse / push past the base into nonsense). femininity is wired into
## to_blend_weights() only insofar as a feminizing target exists; today it is a no-op on
## the mesh while remaining a first-class, serialized public axis.
var femininity: float = 100.0
## Masculine-coded morph amount, 0 … 100 % (default 0). Drives the `gender_male`
## blendshape (masculinity/100). Independent of `femininity` — the two are NOT
## constrained to sum to 100 (androgynous-full, neutral, or any blend is representable),
## a deliberate widening of MakeHuman's single 0–1 gender macro (§2).
var masculinity: float = 0.0
## Muscle mass, 0 … 100 % (default 50 = average-for-build).
##
## PROVISIONAL (Slice A): only the `muscle_max` (above-average) target is imported.
## 50 % = average = the base (weight 0); 100 % = full max-muscle anchor. Below 50 %
## there is no min-muscle target yet (Slice C), so it clamps to the average base.
var muscle: float = 50.0
## Adiposity for the build, 50 … 150 % (default 100 = average-for-build).
##
## PROVISIONAL (Slice A): only the `weight_max` (above-average) target is imported.
## 100 % = average = the base (weight 0); 150 % = full max-weight anchor. Below 100 %
## there is no min-weight target yet (Slice C), so it clamps to the average base.
var weight: float = 100.0
## Within-form proportion envelope (dimensionless). BIDIRECTIONAL about the base:
## 0.0 = full "uncommon" proportions, 0.5 = the base mesh (regular/average), 1.0 = full
## "idealistic" proportions — the two MakeHuman proportions anchors. (body-
## parameterization.md §2 frames this as idealized↔uncommon; Slice A keeps the existing
## 0..1-about-0.5 encoding so the two imported proportions targets still drive — the
## natural-unit re-centering is a later slice once more targets land.)
var proportions: float = 0.5
## Stature in cm (PROVISIONAL Slice A): the height-cm = uniform-scale-⊥-proportions
## realization is decided in §4 but is a Slice C deliverable (it needs the full mesh
## scale path, not a blendshape). In Slice A `height_cm` is NOT yet a metric scale; it
## is carried as a normalized 0..1 macro-height amount driving the single `height_max`
## blendshape, exactly as the old `height` axis did, so the render path is unchanged.
## Renamed-but-same: see height_macro(). Default 0.0 = average-height base.
var height: float = 0.0

# ---------------------------------------------------------------------------
# Age-macro anchors (the MakeHuman age macro 0–1 ships discrete anchors which we read
# as a CONTINUOUS parameter interpolating between them). The base mesh is the YOUNG
# anchor, so age_young has NO blendshape (weight 0 of the others = young). The natural
# -unit `age_years` field maps to this macro via the verified §1.4 piecewise formula.
# ---------------------------------------------------------------------------

## age macro == AGE_BABY  -> full age_baby blendshape (1 year).
const AGE_BABY := 0.0
## age macro == AGE_CHILD -> full age_child blendshape (MakeHuman child anchor, 10 years).
const AGE_CHILD := 0.1875
## age macro == AGE_YOUNG -> the neutral base mesh (young adult, 25 years); age weights 0.
const AGE_YOUNG := 0.5
## age macro == AGE_OLD   -> full age_old blendshape (90 years).
const AGE_OLD := 1.0

## Verified MakeHuman year anchors (body-parameterization.md §1.4, apps/human.py):
## age macro 0.0 = 1yr, 0.5 = 25yr, 1.0 = 90yr — a two-segment piecewise-linear map.
const MIN_AGE_YEARS := 1.0
const MID_AGE_YEARS := 25.0
const MAX_AGE_YEARS := 90.0

## The Layer-1 adult-body-state threshold in YEARS (body-parameterization.md §5).
## `is_adult_body()` is true iff `age_years >= ADULT_AGE_YEARS`. 18.0 is the exact,
## documented legal age of majority in the overwhelming majority of jurisdictions
## (the overdetermined legal/platform rationale, DESIGN.md). In macro terms this is
## ~0.354 (= (18-1)/((25-1)*2)) — past the child anchor (10yr @ 0.1875), well into the
## young band, so 18yr is UNAMBIGUOUSLY adult-proportioned. The child range (≪ 18yr)
## stays firmly excluded. The age axis is NOT notched here: this is a predicate read
## OVER the smooth axis, not a discontinuity carved into it (DESIGN.md, Age × NSFW —
## gate the configuration, not the primitive).
const ADULT_AGE_YEARS := 18.0

# ---------------------------------------------------------------------------
# Natural-unit <-> macro conversions (body-parameterization.md §1.4). PURE functions,
# verified against the verbatim MakeHuman formulas (apps/human.py getAgeYears/setAgeYears).
# ---------------------------------------------------------------------------

## Convert a real age in years to the MakeHuman age macro 0–1 (inverse of setAgeYears).
## Two-segment piecewise-linear: [1,25]yr -> [0,0.5] macro, [25,90]yr -> [0.5,1.0] macro.
static func age_years_to_macro(years: float) -> float:
	var y := clampf(years, MIN_AGE_YEARS, MAX_AGE_YEARS)
	if y < MID_AGE_YEARS:
		# years = 1 + ((25-1)*2)*macro  ->  macro = (years-1)/48
		return (y - MIN_AGE_YEARS) / ((MID_AGE_YEARS - MIN_AGE_YEARS) * 2.0)
	# years = 25 + ((90-25)*2)*(macro-0.5)  ->  macro = 0.5 + (years-25)/130
	return 0.5 + (y - MID_AGE_YEARS) / ((MAX_AGE_YEARS - MID_AGE_YEARS) * 2.0)

## Convert the MakeHuman age macro 0–1 to a real age in years (verbatim setAgeYears).
static func age_macro_to_years(macro: float) -> float:
	var m := clampf(macro, 0.0, 1.0)
	if m < 0.5:
		return MIN_AGE_YEARS + ((MID_AGE_YEARS - MIN_AGE_YEARS) * 2.0) * m
	return MID_AGE_YEARS + ((MAX_AGE_YEARS - MID_AGE_YEARS) * 2.0) * (m - 0.5)

## The internal age macro derived from the public natural-unit field.
func age_macro() -> float:
	return age_years_to_macro(age_years)

## The internal normalized macro-height amount (Slice A: same 0..1 as the old `height`).
func height_macro() -> float:
	return clampf(height, 0.0, 1.0)

# ---------------------------------------------------------------------------
# The derived Layer-1 gate predicate (body-parameterization.md §5). PURE function of
# body-state, single source of truth for the `>= 18 years` line.
# ---------------------------------------------------------------------------

## is_adult_body — the checkable body-state the affordance substrate's guard layer
## reads for the Layer-1 NSFW gate (DESIGN.md Layer 1; body-parameterization.md §5).
## True iff the natural-unit age is at/above the 18-year legal line.
##
## Robustness (carried as HARD, §5): FAIL-CLOSED on a non-finite age (NaN/inf -> not
## adult); reads the PUBLIC natural-unit field (never the lossy internal macro), so the
## gate is self-evidently the legal line; this is the SINGLE place the `>= 18` predicate
## lives — every consumer routes through here via host_is_adult_body().
##
## Gate the INTERSECTION (child-range body-state × NSFW verb), NOT the age primitive:
## this returns a boolean OVER the continuous axis; the axis stays complete so ordinary
## NPCs of every age remain representable.
func is_adult_body() -> bool:
	if not is_finite(age_years):
		return false  # fail-closed on missing/NaN age
	return age_years >= ADULT_AGE_YEARS

# ---------------------------------------------------------------------------
# The render projection (body-parameterization.md §3). BodyState -> blendshape weights.
# PURE & deterministic. Slice A keeps the EXISTING 9-target macro projection underneath:
# the natural-unit public fields are converted to the raw macro values here, internally.
# ---------------------------------------------------------------------------

## Project this BodyState to the per-blendshape weight map for the existing 9-axis set.
## Returns { blendshape_name: weight } — a pure function of the record. The natural-unit
## headline fields are converted to the raw MakeHuman macro values INSIDE this function
## (they are no longer public). The age macro fans out to the three age anchor-
## blendshapes (baby/child/old; young is the base = weight 0) by piecewise-linear
## interpolation. Continuity is preserved: every weight is a continuous function of the
## inputs, so sweeping any axis morphs the mesh smoothly with no discontinuity.
func to_blend_weights() -> Dictionary:
	# femininity: PROVISIONAL — no feminizing target exists yet (base mesh is the
	# feminine pole). We do NOT fake it. masculinity drives the one imported sex target.
	var w := {
		"gender_male": clampf(masculinity / 100.0, 0.0, 1.0),
		# muscle 0..100% where 50 = average (base, weight 0). Only the max anchor exists,
		# so map [50,100]% -> [0,1] on muscle_max; below 50% has no min target (clamps to base).
		"muscle_max": clampf((muscle - 50.0) / 50.0, 0.0, 1.0),
		# weight 50..150% where 100 = average (base, weight 0). Only the max anchor exists,
		# so map [100,150]% -> [0,1] on weight_max; below 100% has no min target (clamps to base).
		"weight_max": clampf((weight - 100.0) / 50.0, 0.0, 1.0),
		"height_max": height_macro(),
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
	# Age: natural-unit years -> macro -> the three anchor blendshapes.
	var a := age_macro()
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

## Drive the blendshape weights on a MeshInstance3D whose mesh is the base body.
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
	# Operands SWAPPED — (c-a)×(b-a) — so the normal points OUTWARD over the reversed
	# winding, IDENTICAL to _compute_normals. (The naive (b-a)×(c-a) over the reversed
	# winding points inward and inverts lighting; winding/ARRAY_INDEX is untouched —
	# culling keys off winding, lighting off these normals, and they are independent.)
	var normals := PackedVector3Array()
	normals.resize(n)
	for i in n:
		normals[i] = Vector3.ZERO
	var t := 0
	while t < tris.size():
		var a := tris[t]; var b := tris[t + 1]; var c := tris[t + 2]
		var fn := (morphed[c] - morphed[a]).cross(morphed[b] - morphed[a])
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
# Serialization (body-parameterization.md §3 — BodyState is data, part of the seeded
# sim). Round-trips through a plain Dictionary (the JSON wire form) for replay /
# transport / diff. Per "retire, don't deprecate" (CLAUDE.md) this is a CLEAN BREAK to
# the natural-unit shape — the old 0–1 `gender`/`age` keys are not read back.
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"age_years": age_years,
		"femininity": femininity,
		"masculinity": masculinity,
		"muscle": muscle,
		"weight": weight,
		"proportions": proportions,
		"height": height,
	}

static func from_dict(d: Dictionary) -> BodyState:
	var bs := BodyState.new()
	bs.age_years = float(d.get("age_years", 25.0))
	bs.femininity = float(d.get("femininity", 100.0))
	bs.masculinity = float(d.get("masculinity", 0.0))
	bs.muscle = float(d.get("muscle", 50.0))
	bs.weight = float(d.get("weight", 100.0))
	bs.proportions = float(d.get("proportions", 0.5))
	bs.height = float(d.get("height", 0.0))
	return bs

func duplicate_state() -> BodyState:
	return BodyState.from_dict(to_dict())
