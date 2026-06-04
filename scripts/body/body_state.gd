## BodyState — the serializable body-morph parameter record (the single source of
## truth for body morphology), per docs/decisions/body-parameterization.md (the
## natural-unit overhaul) which supersedes body-and-locomotion-slice.md §2.1.
##
## SLICE A deliverable (body-parameterization.md §9, Phase A): the PUBLIC API is now
## in NATURAL UNITS (years, percentages) with a single `masculinity` macro sex axis;
## the raw 0–1 MakeHuman macro weights are demoted to an INTERNAL detail computed
## inside to_blend_weights(). The gate is re-expressed to `age_years >= 18.0`. Slice A
## uses ONLY the existing 9 blendshapes (no new target imports — those are Slices B/C),
## so the CPU-morph render path (apply_morph_cpu / apply_to / BodyRig.apply_body_state)
## is byte-for-byte unchanged in behavior; only the public field shape changed.
##
## Sex axis (body-parameterization.md §2, amended): the earlier two-axis model
## (femininity + masculinity) is collapsed to ONE macro axis `masculinity` (0–100,
## default 50 = androgynous). MakeHuman's gender macro is a SINGLE female↔male
## interpolation (one anchor pair, `gender_male`), so two independent axes
## corresponded to nothing in the data — `femininity` was a no-op fiction. The
## single `masculinity` axis maps directly: macro_gender = masculinity/100.0, driving
## the `gender_male` blendshape (0 = feminine base/anchor, 0.5 = androgynous, 1.0 =
## masculine anchor). Real sex-morphology richness emerges from Slice C detail-target
## modifiers, not a macro split.
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

## The data-driven modifier registry (Slice B, body-parameterization.md §6). Parsed from
## MakeHuman's own modifier JSON, it tells `to_blend_weights()` how each `modifiers` map
## entry projects to target blendshape(s) — its kind, sign convention, and target
## file(s) — without hand-listing them in code. Loaded lazily from the built manifest;
## the runtime never re-parses the MakeHuman source.
const ModifierRegistry := preload("res://scripts/body/modifier_registry.gd")
const REGISTRY_MANIFEST := "res://assets/body/modifier_registry.json"
const DetailLibrary := preload("res://scripts/body/detail_library.gd")

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
## Single macro sex axis, 0 … 100 (default 50 = androgynous).
## Maps directly to the MakeHuman gender macro: macro_gender = masculinity / 100.0,
## driving the `gender_male` blendshape.
##   0   = feminine body anchor (base mesh = the fully-feminine MakeHuman base)
##   50  = androgynous (halfway between the two anchors)
##   100 = masculine body anchor (full `gender_male` blendshape weight 1.0)
## The name `masculinity` is the chosen morphology scalar — NOT `sex` (sex is
## categorical) and NOT `gender` (gender identity is deliberately decoupled from
## body morphology). Real sex-morphology richness emerges from Slice C detail-target
## modifiers, not from a macro split.
var masculinity: float = 50.0
## Muscle mass, 0 … 100 % (default 50 = average-for-build). FULL RANGE (Slice C): the
## min-muscle anchors are now imported in the sparse macro factor-cube, so 0 % drives the
## full minmuscle anchor, 50 % = average (base), 100 % = full maxmuscle anchor — mapped to
## the MakeHuman muscle macro 0–1 (muscle% / 100) and split into {min,avg,max} anchor vals.
var muscle: float = 50.0
## Adiposity for the build, 50 … 150 % of average-for-build (default 100 = average). FULL
## RANGE (Slice C): the min-weight anchors are now imported, so 50 % drives the full
## minweight anchor, 100 % = average (base), 150 % = full maxweight anchor — mapped to the
## MakeHuman weight macro 0–1 ((weight%-50)/100) and split into {min,avg,max} anchor vals.
var weight: float = 100.0
## Within-form proportion envelope (dimensionless). BIDIRECTIONAL about the base:
## 0.0 = full "uncommon" proportions, 0.5 = the base mesh (regular/average), 1.0 = full
## "idealistic" proportions — the two MakeHuman proportions anchors. (body-
## parameterization.md §2 frames this as idealized↔uncommon; Slice A keeps the existing
## 0..1-about-0.5 encoding so the two imported proportions targets still drive — the
## natural-unit re-centering is a later slice once more targets land.)
var proportions: float = 0.5
## Stature in CM (Slice C, §4): a REAL metric axis realized as a UNIFORM mesh scale,
## ORTHOGONAL to proportions BY CONSTRUCTION. MakeHuman couples height into its morph cube
## (§1.5) so it is NOT a pure scale there; aeriea deliberately deviates — `height_cm` does
## NOT drive the MakeHuman height macro (that 144-target cube is dropped). Instead the
## fully-morphed mesh is scaled by `height_cm / base_height_cm` about the foot origin
## (see BodyRig). So proportions change shape at fixed stature; height changes stature at
## fixed shape — genuinely independent. base_height_cm is the neutral build's getHeightCm
## (≈166.6 cm), read from the detail-library index. Default = base_height_cm if the library
## is present, else DEFAULT_HEIGHT_CM. Clamped to [MIN_HEIGHT_CM, MAX_HEIGHT_CM].
var height_cm: float = 166.589

## The DETAIL ENVELOPE (body-parameterization.md §3, Slice B): a SPARSE generic map,
## modifier `fullName` -> value. An absent key means NEUTRAL (the base mesh). Keys are the
## verified MakeHuman `fullName` strings ("breast/BreastSize", "nose/nose-hump-decr|incr",
## …); values are clamped by the registry-declared range (bidirectional [-1,1], unipolar
## [0,1]). Default BodyState carries an EMPTY map — a neutral young adult — so it
## serializes tiny, diffs cleanly, and fits the seed + action-log (CLAUDE.md "serializable
## over closures"). `to_blend_weights()` projects each non-neutral entry through the
## data-driven registry (§6). Slice B wires the projection; the detail TARGET FILES are
## imported in Slice C, so for now non-neutral detail entries project to blendshape names
## the base mesh does not yet declare — `apply_to` simply skips unknown blendshapes (a
## registered-but-not-yet-present modifier morphs nothing, by design, until Slice C).
var modifiers: Dictionary = {}

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

## Metric stature bounds (§4). The default is the neutral base build's natural height
## (getHeightCm ≈ 166.6 cm). The range spans well below a small child to above a tall adult,
## sex-neutral, so the uniform-scale axis is useful across the whole age range without
## claiming MakeHuman-style build-correlated stature realism (that is the deferred open
## question in §4). DEFAULT_HEIGHT_CM is used only when the detail library is absent.
const MIN_HEIGHT_CM := 50.0
const MAX_HEIGHT_CM := 230.0
const DEFAULT_HEIGHT_CM := 166.589

## The macro factor-cube anchor token sets (verified lib/targets.py `_cat_data`, §1.3).
## A universal cube target's filename decodes into one token per category; the target's
## weight is the PRODUCT of the anchor val for each of its decoded tokens.
const GENDER_TOKENS := {"male": true, "female": true}
const AGE_TOKENS := {"baby": true, "child": true, "young": true, "old": true}
const MUSCLE_TOKENS := {"maxmuscle": true, "averagemuscle": true, "minmuscle": true}
const WEIGHT_TOKENS := {"minweight": true, "averageweight": true, "maxweight": true}
## Race is pinned to caucasian (the base mesh ethnicity; race axis is out of scope), so the
## caucasian race-cube targets carry race factor val 1.0; asian/african cubes are not
## imported. The `universal-` cube targets carry NO race token (universal across race).
const RACE_TOKENS := {"caucasian": true, "asian": true, "african": true}
const CAUCASIAN_VAL := 1.0

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

## The §4 uniform stature SCALE = height_cm / base_height_cm. base_height_cm is the neutral
## build's getHeightCm (from the detail-library index; falls back to DEFAULT_HEIGHT_CM).
## BodyRig multiplies the morphed mesh by this scale about the foot origin, so stature is a
## pure scale orthogonal to the shape morphs. Clamped to a sane positive range.
func height_scale() -> float:
	var base := DetailLibrary.base_height_cm()
	if base <= 0.0:
		base = DEFAULT_HEIGHT_CM
	var h := clampf(height_cm, MIN_HEIGHT_CM, MAX_HEIGHT_CM)
	return h / base

# ---------------------------------------------------------------------------
# The macro factor-PRODUCT anchor vals (§1.3, verbatim apps/human.py setters). Each macro
# axis splits into anchor sub-weights; a macro target's weight is the PRODUCT of the anchor
# vals for the factor tokens its filename decodes to. PURE functions of the headline axes.
# ---------------------------------------------------------------------------

## Gender anchor vals: maleVal = gender, femaleVal = 1 - gender  (_setGenderVals).
## gender macro = masculinity / 100.
func _gender_vals() -> Dictionary:
	var g := clampf(masculinity / 100.0, 0.0, 1.0)
	return {"male": g, "female": 1.0 - g}

## Age anchor vals: the verbatim _setAgeVals piecewise map over baby/child/young/old.
func _age_vals() -> Dictionary:
	var a := age_macro()
	var baby := 0.0; var child := 0.0; var young := 0.0; var old := 0.0
	if a < 0.5:
		old = 0.0
		baby = maxf(0.0, 1.0 - a * 5.333)            # 1/0.1875
		young = maxf(0.0, (a - 0.1875) * 3.2)        # 1/(0.5-0.1875)
		child = maxf(0.0, minf(1.0, 5.333 * a) - young)
	else:
		child = 0.0; baby = 0.0
		old = maxf(0.0, a * 2.0 - 1.0)
		young = 1.0 - old
	return {"baby": baby, "child": child, "young": young, "old": old}

## Muscle anchor vals: {min,avg,max} from the 2× split about the midpoint (_setMuscleVals).
## muscle macro = muscle% / 100.
func _muscle_vals() -> Dictionary:
	var m := clampf(muscle / 100.0, 0.0, 1.0)
	var mx := maxf(0.0, m * 2.0 - 1.0)
	var mn := maxf(0.0, 1.0 - m * 2.0)
	return {"maxmuscle": mx, "minmuscle": mn, "averagemuscle": 1.0 - (mx + mn)}

## Weight anchor vals: {min,avg,max} (_setWeightVals). weight macro = (weight%-50)/100, so
## 50%→0 (full min), 100%→0.5 (full average), 150%→1 (full max).
func _weight_vals() -> Dictionary:
	var w := clampf((weight - 50.0) / 100.0, 0.0, 1.0)
	var mx := maxf(0.0, w * 2.0 - 1.0)
	var mn := maxf(0.0, 1.0 - w * 2.0)
	return {"maxweight": mx, "minweight": mn, "averageweight": 1.0 - (mx + mn)}

## Decode a macro-cube target filename (universal muscle/weight cube OR caucasian race
## cube), e.g. "macrodetails/universal-male-old-maxmuscle-maxweight.target" or
## "macrodetails/caucasian-female-child.target", into its factor tokens — one per
## category in {race,gender,age,muscle,weight}. Returns a Dictionary category->token.
static func _decode_macro_factors(rel_path: String) -> Dictionary:
	var base := rel_path.get_file().trim_suffix(".target")
	var out := {}
	for tok in base.split("-", false):
		if RACE_TOKENS.has(tok): out["race"] = tok
		elif GENDER_TOKENS.has(tok): out["gender"] = tok
		elif AGE_TOKENS.has(tok): out["age"] = tok
		elif MUSCLE_TOKENS.has(tok): out["muscle"] = tok
		elif WEIGHT_TOKENS.has(tok): out["weight"] = tok
	return out

## The factor-PRODUCT weight for one macro-cube target, given the anchor-val maps. weight =
## Π over the target's decoded factor tokens of the matching anchor val (§1.3
## getTargetWeights: reduce(mul, [factors[f] for f in tfactors])). The race factor is pinned
## (caucasian=1, asian/african=0) — a non-caucasian race target gets weight 0 (not imported
## anyway). A category absent from the filename contributes 1 (e.g. the caucasian race cube
## omits muscle/weight; the universal cube omits race).
func _universal_target_weight(rel_path: String, gv: Dictionary, av: Dictionary, mv: Dictionary, wv: Dictionary) -> float:
	var f := _decode_macro_factors(rel_path)
	var prod := 1.0
	if f.has("race"): prod *= (CAUCASIAN_VAL if f["race"] == "caucasian" else 0.0)
	if f.has("gender"): prod *= float(gv[f["gender"]])
	if f.has("age"): prod *= float(av[f["age"]])
	if f.has("muscle"): prod *= float(mv[f["muscle"]])
	if f.has("weight"): prod *= float(wv[f["weight"]])
	return prod

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

## The two neutral proportions anchor target paths (uncommon / ideal). Proportions stays a
## 2-anchor bidirectional axis at the neutral build (the full proportions factor-cube is
## intentionally not imported — see tools/detail_library_build.gd header).
const PROPORTIONS_IDEAL_TARGET := "macrodetails/proportions/female-young-averagemuscle-averageweight-idealproportions.target"
const PROPORTIONS_UNCOMMON_TARGET := "macrodetails/proportions/female-young-averagemuscle-averageweight-uncommonproportions.target"

## Project this BodyState to the per-target weight map. Returns { target_path: weight } —
## a pure, deterministic function of the record. Keys are SPARSE-LIBRARY target file paths
## (the names DetailLibrary resolves), NOT GPU blendshape names: the whole morph (macro
## factor-cube + proportions anchors + detail envelope) flows through the CPU sparse-delta
## path (Slice C). The macro cube is the §1.3 factor-PRODUCT over gender×age×muscle×weight,
## so COMBINED macro morphs compose correctly (NOT the old linear single-anchor sum). Every
## weight is a continuous function of the inputs, so sweeping any axis morphs smoothly.
## height_cm is NOT in this map — it is a UNIFORM SCALE applied by BodyRig (§4), orthogonal.
func to_blend_weights() -> Dictionary:
	var w := {}
	# --- MACRO factor-product cube (§1.3): for each universal cube target the library
	# knows, emit Π of its decoded factor anchor vals. Empty/zero weights are still emitted
	# as 0 by omission (absent key = neutral). ----------------------------------------
	var gv := _gender_vals()
	var av := _age_vals()
	var mv := _muscle_vals()
	var wv := _weight_vals()
	for rel in DetailLibrary.paths_of_kind("macro"):
		if rel == PROPORTIONS_IDEAL_TARGET or rel == PROPORTIONS_UNCOMMON_TARGET:
			continue  # proportions handled below, not as a universal factor-product target
		var tw := _universal_target_weight(rel, gv, av, mv, wv)
		if tw > 1e-6:
			w[rel] = tw

	# --- Proportions: bidirectional about the base (0.5). Below 0.5 fades in the uncommon
	# anchor; above 0.5 the ideal anchor; exactly 0.5 = base. Orthogonal to the cube. ----
	var pr := clampf(proportions, 0.0, 1.0)
	if pr < 0.5:
		w[PROPORTIONS_UNCOMMON_TARGET] = (0.5 - pr) / 0.5
	elif pr > 0.5:
		w[PROPORTIONS_IDEAL_TARGET] = (pr - 0.5) / 0.5

	# --- the DETAIL ENVELOPE (Slice B, §6): project the sparse `modifiers` map through
	# the data-driven registry. Each non-neutral entry resolves via its registered kind
	# to target blendshape weight(s) keyed by the target FILE PATH (the name Slice C
	# imports them under). Deterministic: keys iterated in SORTED order for byte-stable
	# output. The macro modifiers (kind=="macro") are NOT projected here — they flow
	# through the headline factor-product path above; an entry that names a macro
	# modifier is ignored (the headline axes own those).
	_project_modifiers(w)
	return w


# Cached parsed registry (one parse per process; the manifest is small). Static so all
# BodyState instances share it. `{}` until first loaded; `_registry_loaded` guards a
# successful-or-attempted load so a missing manifest does not retry every frame.
static var _registry: Dictionary = {}
static var _registry_loaded := false


## The modifier registry (Slice B, §6), loaded lazily from the built manifest. Returns the
## parse()-shaped Dictionary ({modifiers, by_full_name, counts}); empty if the manifest is
## absent (then detail projection is a no-op — the headline axes still work).
static func registry() -> Dictionary:
	if not _registry_loaded:
		_registry_loaded = true
		var f := FileAccess.open(REGISTRY_MANIFEST, FileAccess.READ)
		if f != null:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY and data.has("modifiers"):
				var by := {}
				for e in data["modifiers"]:
					by[String(e["full_name"])] = e
				_registry = {"modifiers": data["modifiers"], "by_full_name": by, "counts": data.get("counts", {})}
	return _registry


## Project the sparse `modifiers` map onto the blendshape-weight map `w`, per the registry
## (§6). Bidirectional: v<0 drives the min/neg target by -v, v>0 drives the max/pos target
## by v (verbatim UniversalModifier.getFactors). Unipolar: v drives the single target by v.
## Blendshape name = the target file path (Slice C imports detail targets under that name).
## Sorted-key iteration -> byte-stable. Macro entries are skipped (headline axes own them);
## unknown fullNames are skipped (the map stays forgiving for forward/back-compat data).
func _project_modifiers(w: Dictionary) -> void:
	if modifiers.is_empty():
		return
	var reg := registry()
	var by_full_name: Dictionary = reg.get("by_full_name", {})
	if by_full_name.is_empty():
		return
	var keys := modifiers.keys()
	keys.sort()
	for full_name in keys:
		var entry = by_full_name.get(full_name, null)
		if entry == null:
			continue
		var v := float(modifiers[full_name])
		var kind := String(entry["kind"])
		var targets: Array = entry["targets"]
		if kind == ModifierRegistry.KIND_MACRO:
			continue  # macro axes flow through the headline factor-product path
		elif kind == ModifierRegistry.KIND_BIDIRECTIONAL:
			v = clampf(v, -1.0, 1.0)
			for t in targets:
				var pole := String(t["which"])
				var bs_name := String(t["path"])
				if pole == "min" and v < 0.0:
					w[bs_name] = -v
				elif pole == "max" and v > 0.0:
					w[bs_name] = v
		else:  # unipolar
			v = clampf(v, 0.0, 1.0)
			if v > 0.0 and targets.size() > 0:
				w[String(targets[0]["path"])] = v

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
	# (1) Legacy GPU blendshapes by NAME — still applied so an explicit weights_override
	# that names the 9 starter axes (the demo's raw per-blendshape sliders) keeps working.
	# BodyState.to_blend_weights() no longer emits those names (Slice C routes the macro +
	# detail morph through the sparse library below), so this pass is a no-op for the
	# default projection and only fires for raw-blendshape overrides.
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
	# (2) SPARSE DELTA LIBRARY (Slice C): every weight whose key is a target FILE PATH the
	# library knows is applied as morphed[ri] += delta_ri * weight. This carries the macro
	# factor-cube + the proportions anchors + the full detail envelope, all on the CPU, so
	# we avoid ~531 GPU blendshapes (≈180 MB). Iterated in SORTED key order for determinism.
	if DetailLibrary.ensure_loaded():
		var keys := weights.keys()
		keys.sort()
		for k in keys:
			var ks := String(k)
			if DetailLibrary.has_target(ks):
				DetailLibrary.apply(ks, float(weights[k]), morphed)
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
	var d := {
		"age_years": age_years,
		"masculinity": masculinity,
		"muscle": muscle,
		"weight": weight,
		"proportions": proportions,
		"height_cm": height_cm,
	}
	# The detail envelope (Slice B): only serialized when NON-EMPTY, so a neutral body
	# stays a tiny dict. Sorted-key copy for byte-stable diffs / replay.
	if not modifiers.is_empty():
		var m := {}
		var keys := modifiers.keys()
		keys.sort()
		for k in keys:
			m[k] = float(modifiers[k])
		d["modifiers"] = m
	return d

static func from_dict(d: Dictionary) -> BodyState:
	var bs := BodyState.new()
	bs.age_years = float(d.get("age_years", 25.0))
	bs.masculinity = float(d.get("masculinity", 50.0))
	bs.muscle = float(d.get("muscle", 50.0))
	bs.weight = float(d.get("weight", 100.0))
	bs.proportions = float(d.get("proportions", 0.5))
	bs.height_cm = float(d.get("height_cm", DEFAULT_HEIGHT_CM))
	var m = d.get("modifiers", {})
	if typeof(m) == TYPE_DICTIONARY:
		for k in m:
			bs.modifiers[String(k)] = float(m[k])
	return bs

func duplicate_state() -> BodyState:
	return BodyState.from_dict(to_dict())
