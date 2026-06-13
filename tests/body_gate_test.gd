## Slice-2 behavioral test (docs/decisions/body-and-locomotion-slice.md §4, Slice 2
## verify). Proves the THREE Slice-2 claims, windowed under xvfb:
##
##   (a) BodyState DRIVES the morphs — setting a BodyState param updates the
##       corresponding blendshape weight(s) on the real §1 base body mesh (the body
##       morphs as expected; age param -> age blendshape weight -> vertex change).
##   (b) is_adult_body is the correct pure predicate over the CONTINUOUS age axis —
##       true for adult-range age, false for child-range — and the age axis stays
##       continuous (the child morph still renders for ordinary use; not crippled).
##   (c) The Layer-1 NSFW gate HOLDS BY CONSTRUCTION at the affordance guard layer:
##       the test-placeholder NSFW verb is ABSENT/un-fireable at child-range
##       body-state and PRESENT/fireable at adult-range — for BOTH the interpreter
##       and the compiled driver (interpreter == compiled). The gate precedes any
##       real NSFW content; it gates the INTERSECTION, never the age primitive.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_gate_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const MESH_PATH := "res://assets/body/base_body.res"
const KIT_PATH := "res://interaction/sandbox.kit.json"
const NSFW_DEF := "intimacy_test_marker"
const NSFW_VERB := "intimacy_placeholder"

const InteractionKitScript := preload("res://scripts/interaction/interaction_kit.gd")
const InterpreterScript := preload("res://scripts/interaction/interaction_interpreter.gd")
const CompiledScript := preload("res://scripts/interaction/generated/compiled_sandbox_interaction.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea body SLICE 2 — BodyState + Layer-1 NSFW gate ===\n")
	_test_bodystate_drives_morphs()
	_test_stature_tracks_cited_growth_data()
	_test_is_adult_body_predicate()
	_test_gate_holds_at_guard_layer(false)  # interpreter
	_test_gate_holds_at_guard_layer(true)   # compiled
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# ---------------------------------------------------------------------------
# (a) BodyState drives the blendshape weights on the real mesh.
# ---------------------------------------------------------------------------

func _test_bodystate_drives_morphs() -> void:
	print("--- (a) BodyState -> sparse macro factor-cube weights (Slice C) ---")
	var mesh: ArrayMesh = load(MESH_PATH)
	_assert("base body mesh loads", mesh != null, MESH_PATH)
	if mesh == null:
		return

	# Slice C: the macro morph is the §1.3 factor-PRODUCT over the universal gender×age×
	# muscle×weight cube, keyed by target FILE PATH (the sparse-library names), NOT the
	# old 9 GPU-blendshape names. Assert the factor-product weights directly.

	# Neutral young-adult default: average everything -> the only nonzero universal-cube
	# weights are the (averagemuscle-averageweight) anchors, which are EMPTY targets (the
	# base), so the body is the neutral base. No non-average anchor gets weight.
	var neutral := BodyState.new()
	var nw := neutral.to_blend_weights()
	var any_nonavg := false
	for k in nw:
		var ks := String(k)
		if ks.contains("maxmuscle") or ks.contains("minmuscle") or ks.contains("maxweight") or ks.contains("minweight"):
			if float(nw[k]) > 1e-4:
				any_nonavg = true
	_assert("neutral default drives no non-average macro anchor (base = neutral young adult)",
		not any_nonavg, "no max/min muscle/weight anchor weighted at neutral")

	# Age toward OLD (90yr): macro 1.0 -> oldVal 1.0, youngVal 0. The universal '-old-'
	# anchors carry full weight (× the gender/build factors), the '-young-' anchors 0.
	var old_bs := BodyState.new()
	old_bs.age_years = 90.0
	var ow := old_bs.to_blend_weights()
	# female-old-averagemuscle-averageweight = femaleVal(0.5)*oldVal(1)*avg*avg = 0.5
	var old_anchor := "macrodetails/universal-female-old-averagemuscle-averageweight.target"
	var young_anchor := "macrodetails/universal-female-young-averagemuscle-averageweight.target"
	_assert("age_years=90 -> female-old anchor weight ~0.5 (femaleVal*oldVal), young anchor absent",
		absf(float(ow.get(old_anchor, 0.0)) - 0.5) < 1e-4 and float(ow.get(young_anchor, 0.0)) < 1e-4,
		"old=%.4f young=%.4f" % [float(ow.get(old_anchor, 0.0)), float(ow.get(young_anchor, 0.0))])

	# FACTOR-PRODUCT (the load-bearing Slice C correctness): old + muscular + heavy + male
	# composes as a PRODUCT, not a linear sum. masculinity 100 (maleVal 1), age 90
	# (oldVal 1), muscle 100 (maxmuscleVal 1), weight 150 (maxweightVal 1) -> the single
	# target male-old-maxmuscle-maxweight gets weight 1*1*1*1 = 1.0; a linear approximation
	# could never put full weight on that combined cross-term.
	var combo := BodyState.new()
	combo.masculinity = 100.0; combo.age_years = 90.0; combo.muscle = 100.0; combo.weight = 150.0
	var cw2 := combo.to_blend_weights()
	var cross := "macrodetails/universal-male-old-maxmuscle-maxweight.target"
	_assert("FACTOR-PRODUCT: male+old+maxmuscle+maxweight -> cross-term anchor weight = 1.0 (product, not linear)",
		absf(float(cw2.get(cross, 0.0)) - 1.0) < 1e-4, "cross weight = %.4f" % float(cw2.get(cross, 0.0)))
	# and a half-male / mid build splits the product correctly: masc 50 -> maleVal 0.5,
	# femaleVal 0.5; so male-old-maxmuscle-maxweight = 0.5 and female-old-... = 0.5.
	var half := BodyState.new()
	half.masculinity = 50.0; half.age_years = 90.0; half.muscle = 100.0; half.weight = 150.0
	var hw := half.to_blend_weights()
	_assert("FACTOR-PRODUCT: masc 50 splits the cross-term 0.5 male / 0.5 female",
		absf(float(hw.get(cross, 0.0)) - 0.5) < 1e-4
		and absf(float(hw.get("macrodetails/universal-female-old-maxmuscle-maxweight.target", 0.0)) - 0.5) < 1e-4,
		"male=%.4f female=%.4f" % [float(hw.get(cross, 0.0)), float(hw.get("macrodetails/universal-female-old-maxmuscle-maxweight.target", 0.0))])

	# The age_years<->macro map is the verified MakeHuman piecewise (§1.4).
	_assert("age_years 18 -> macro ~0.354 (the gate's macro position, verified)",
		absf(BodyState.age_years_to_macro(18.0) - 0.354166) < 1e-4,
		"macro(18yr) = %.6f" % BodyState.age_years_to_macro(18.0))
	_assert("age macro<->years round-trips (25yr<->0.5, 90yr<->1.0)",
		absf(BodyState.age_macro_to_years(0.5) - 25.0) < 1e-4
		and absf(BodyState.age_macro_to_years(1.0) - 90.0) < 1e-4,
		"yr(0.5)=%.2f yr(1.0)=%.2f" % [BodyState.age_macro_to_years(0.5), BodyState.age_macro_to_years(1.0)])

	# Prove the morph actually changes the rendered VERTICES through the CPU bake + sparse
	# library: bake the OLD morph onto a per-instance mesh and confirm vertices moved.
	var morph_mesh := (mesh.duplicate(true) as ArrayMesh)
	var mi := MeshInstance3D.new()
	mi.mesh = morph_mesh
	add_child(mi)
	var base_verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	old_bs.apply_morph_cpu(mi)
	var morphed: PackedVector3Array = morph_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_disp := 0.0
	for i in base_verts.size():
		max_disp = max(max_disp, (morphed[i] - base_verts[i]).length())
	_assert("age axis -> sparse macro cube -> nonzero vertex displacement (mesh actually morphs)",
		max_disp > 0.001, "max old-morph displacement = %.4f m" % max_disp)

	# Serialization round-trips (BodyState is seeded-sim data).
	var rt := BodyState.from_dict(old_bs.to_dict())
	_assert("BodyState round-trips through to_dict/from_dict (serializable sim data)",
		is_equal_approx(rt.age_years, old_bs.age_years) and is_equal_approx(rt.weight, old_bs.weight),
		"age_years=%.3f weight=%.3f" % [rt.age_years, rt.weight])

	mi.queue_free()


# ---------------------------------------------------------------------------
# (a2) AGE → STATURE tracks CITED median height-for-age (body-parameterization.md
# §4.1, 2026-06-14 rebuild). The body's overall SIZE must follow the CDC median
# stature-for-age FRACTION at each age (children correctly small for their age),
# plateau at the realistic SEX-AWARE age (females ~15-16, males ~18), and 18 ≈ 25.
# We measure morph-only vertical extent (bbox height) at FIXED height_cm and assert
# the measured fraction-of-adult-extent matches the cited CDC fractions per sex.
# This FAILS under the old hand-picked linear remap (which inflated child stature:
# a 12yr read ~teen size — ~1.55 m / ~92% of adult — instead of ~88% combined).
# ---------------------------------------------------------------------------

## Morph-only vertical extent (metres) at `age`/`masculinity`, height_cm held at the
## neutral base so we isolate what the AGE MORPH does to overall stature.
func _morph_extent(mesh: ArrayMesh, age: float, masc: float) -> float:
	var mi := MeshInstance3D.new()
	mi.mesh = (mesh.duplicate(true) as ArrayMesh)
	add_child(mi)
	var bs := BodyState.new()
	bs.age_years = age
	bs.masculinity = masc
	bs.height_cm = BodyState.DEFAULT_HEIGHT_CM
	bs.apply_morph_cpu(mi)
	var verts: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mn := INF; var mx := -INF
	for v in verts:
		mn = minf(mn, v.y); mx = maxf(mx, v.y)
	mi.queue_free()
	return mx - mn

func _test_stature_tracks_cited_growth_data() -> void:
	print("--- (a2) age → stature tracks CITED CDC median height-for-age (§4.1) ---")
	var mesh: ArrayMesh = load(MESH_PATH)
	if mesh == null:
		return

	# --- FEMALE curve (masculinity 0): adult ref = the female 25yr extent. The measured
	# fraction-of-adult at each age must match the CITED CDC female median fraction
	# (MEDIAN_CM_FEMALE[age]/ADULT_REF_CM_FEMALE) within tolerance. The morph reproduces
	# the real growth fractions, so children are correctly small for their age. ----------
	var fa := _morph_extent(mesh, 25.0, 0.0)   # female adult reference extent
	# [age, cited fraction] from MEDIAN_CM_FEMALE / 163.25 (CDC, §4.1).
	var f_cases := [
		[6.0, BodyState.MEDIAN_CM_FEMALE[6] / BodyState.ADULT_REF_CM_FEMALE],
		[10.0, BodyState.MEDIAN_CM_FEMALE[10] / BodyState.ADULT_REF_CM_FEMALE],
		[12.0, BodyState.MEDIAN_CM_FEMALE[12] / BodyState.ADULT_REF_CM_FEMALE],
		[14.0, BodyState.MEDIAN_CM_FEMALE[14] / BodyState.ADULT_REF_CM_FEMALE],
		[16.0, BodyState.MEDIAN_CM_FEMALE[16] / BodyState.ADULT_REF_CM_FEMALE],
	]
	for c in f_cases:
		var age := float(c[0])
		var want := float(c[1])
		var got := _morph_extent(mesh, age, 0.0) / fa
		# 2% tolerance: the morph→stature inversion is piecewise-linear over 3 anchor nodes,
		# so it tracks the cited fraction closely but not to the last digit.
		_assert("FEMALE %2.0fyr stature = cited CDC median fraction (%.1f%% of adult)" % [age, 100.0 * want],
			absf(got - want) < 0.02,
			"measured=%.4f (%.1f%%)  cited=%.4f (%.1f%%)  Δ=%.4f" % [got, 100.0 * got, want, 100.0 * want, absf(got - want)])

	# --- MALE curve (masculinity 100): males grow LATER — at 12yr a male is markedly
	# SHORTER (fraction-wise) than a female, and reaches full stature ~18. Assert the
	# male 12yr fraction matches the cited male median (≈0.843) AND is below the female. -
	var ma := _morph_extent(mesh, 25.0, 100.0)   # male adult reference extent
	var m12_want := BodyState.MEDIAN_CM_MALE[12] / BodyState.ADULT_REF_CM_MALE
	var m12_got := _morph_extent(mesh, 12.0, 100.0) / ma
	var f12_frac := BodyState.MEDIAN_CM_FEMALE[12] / BodyState.ADULT_REF_CM_FEMALE
	_assert("SEX-AWARE: MALE 12yr = cited male median fraction (%.1f%%), below female 12yr (%.1f%%)" % [100.0 * m12_want, 100.0 * f12_frac],
		absf(m12_got - m12_want) < 0.02 and m12_want < f12_frac,
		"male12 measured=%.3f cited=%.3f  female12 cited=%.3f" % [m12_got, m12_want, f12_frac])

	# --- 12yr REGRESSION GUARD (the artifact this rebuild fixes). The OLD linear remap
	# mapped 12yr→morph 17.5yr→macro≈0.344, rendering a 12yr at ~92% of adult extent (a
	# near-teen). The data-grounded curve puts a 12yr at the CITED ~88% combined fraction.
	# Assert the COMBINED (androgynous) 12yr is at/below ~90% — FAILS under the old remap.
	var aa := _morph_extent(mesh, 25.0, 50.0)
	var h12 := _morph_extent(mesh, 12.0, 50.0) / aa
	_assert("12yr is child-sized per CITED data (≤90% of adult extent — was ~92% under old linear remap)",
		h12 <= 0.90 and h12 > 0.80,
		"androgynous 12yr extent = %.1f%% of adult (cited M/F avg ≈ 88%%)" % [100.0 * h12])

	# --- PLATEAU (sex-aware) + 18≈25. Females flatten by ~16; both sexes reach the young
	# anchor by ~18-19 and stay there to 25. 18 ≈ 25 within tolerance, no discontinuity. -
	var f16 := _morph_extent(mesh, 16.0, 0.0)
	var f25 := _morph_extent(mesh, 25.0, 0.0)
	_assert("FEMALE plateau: 16yr ≈ 25yr (females reach full stature by ~15-16)",
		absf(f16 - f25) < 0.015, "f16=%.4f f25=%.4f (Δ=%.4f)" % [f16, f25, absf(f16 - f25)])
	var a18 := _morph_extent(mesh, 18.0, 50.0)
	var a25 := _morph_extent(mesh, 25.0, 50.0)
	_assert("stature plateaus: 18yr ≈ 25yr (full adult by ~18, no growth into adulthood)",
		absf(a18 - a25) < 0.01, "h18=%.4f h25=%.4f (Δ=%.4f)" % [a18, a25, absf(a18 - a25)])
	# 10yr stays clearly child-sized (regression guard the other way: fix must not flatten
	# the whole curve into adults).
	var h10 := _morph_extent(mesh, 10.0, 50.0) / aa
	_assert("10yr stays clearly child-sized (< 85% of adult extent — child range preserved)",
		h10 < 0.85 and h10 > 0.5, "androgynous 10yr extent = %.1f%% of adult" % [100.0 * h10])


# ---------------------------------------------------------------------------
# (b) is_adult_body predicate over the continuous age axis.
# ---------------------------------------------------------------------------

func _test_is_adult_body_predicate() -> void:
	print("--- (b) is_adult_body predicate (>= 18 years, over the continuous age axis) ---")
	var cases := [
		# [age_years, expected_is_adult, label]
		[1.0, false, "baby (1yr)"],
		[10.0, false, "child anchor (10yr)"],
		[15.0, false, "adolescent (15yr)"],
		# --- THE GATE BOUNDARY (body-parameterization.md §5.4) ---
		[17.9, false, "BOUNDARY just below 18 (17.9yr) — DENIED"],
		[18.0, true, "BOUNDARY exactly 18 (18.0yr) — PERMITTED"],
		[18.1, true, "BOUNDARY just above 18 (18.1yr) — PERMITTED"],
		[25.0, true, "young adult (25yr, default base)"],
		[90.0, true, "old (90yr)"],
	]
	for c in cases:
		var bs := BodyState.new()
		bs.age_years = float(c[0])
		var got := bs.is_adult_body()
		_assert("age %s -> is_adult_body=%s" % [c[2], str(c[1])], got == bool(c[1]),
			"age_years=%.2f is_adult_body=%s (threshold=%.1fyr)" % [bs.age_years, str(got), BodyState.ADULT_AGE_YEARS])

	# Fail-closed on a non-finite age (robustness requirement §5.1).
	var nan_bs := BodyState.new()
	nan_bs.age_years = NAN
	_assert("fail-closed: non-finite age_years -> is_adult_body=false",
		not nan_bs.is_adult_body(), "age_years=NaN is_adult=%s" % str(nan_bs.is_adult_body()))

	# The age axis is NOT crippled: the child morph still produces a valid (nonzero,
	# distinct) blendshape projection for ordinary NPC use — the gate is a predicate
	# OVER the axis, not a notch cut into it.
	var child := BodyState.new()
	child.age_years = 10.0  # a 10yr — clearly child-range body-state
	var cw := child.to_blend_weights()
	# The morph is uncrippled and renders: the '-child-' average-build anchor carries the
	# DOMINANT weight (× femaleVal 0.5) and no adult anchor does. After the §4.1 data-grounded
	# age→stature rebuild the child anchor is no longer pinned to exactly 0.5 at 10yr: the
	# morph is driven to the CITED CDC median height-for-age fraction at each age, so a 10yr
	# blends toward the young anchor by exactly the real growth fraction (a 10yr is ~80% of
	# adult stature per CDC), staying clearly child-dominant and well below adult. Assert
	# child DOMINATES and stays uncrippled, not a pin.
	var child_anchor := "macrodetails/universal-female-child-averagemuscle-averageweight.target"
	var young_anchor10 := "macrodetails/universal-female-young-averagemuscle-averageweight.target"
	_assert("age axis stays continuous/complete: child morph still renders, child anchor dominant (not crippled)",
		float(cw.get(child_anchor, 0.0)) > 0.25
		and float(cw.get(child_anchor, 0.0)) > float(cw.get(young_anchor10, 0.0))
		and not child.is_adult_body(),
		"child_anchor=%.3f young_anchor=%.3f is_adult=%s" % [
			float(cw.get(child_anchor, 0.0)), float(cw.get(young_anchor10, 0.0)), str(child.is_adult_body())])


# ---------------------------------------------------------------------------
# (c) The gate holds at the affordance guard layer — for BOTH drivers.
# A test host stands in for InteractionWorld: it supplies the body-state hook
# (host_is_adult_body) and the minimal host protocol the interpreter needs to
# resolve a frame. We focus the NSFW marker and check whether the verb is in the
# live verb set (fireable) at child- vs adult-range body-state.
# ---------------------------------------------------------------------------

func _test_gate_holds_at_guard_layer(compiled: bool) -> void:
	var tag := "compiled" if compiled else "interpreter"
	print("--- (c) Layer-1 NSFW gate at the guard layer [%s driver] ---" % tag)

	var kit := InteractionKitScript.load_from_file(KIT_PATH)
	_assert("(%s) kit loads valid (body_is_adult is a known guard op)" % tag,
		kit.is_valid(), str(kit.load_errors))
	if not kit.is_valid():
		return
	_assert("(%s) kit declares the test-placeholder NSFW verb gated on body_is_adult" % tag,
		kit.interactables.has(NSFW_DEF), "interactables: %s" % str(kit.interactable_order))

	# Each case: [age_years, expect_verb_live, label]. The boundary cases (17.9 / 18.0)
	# assert the gate at the AFFORDANCE GUARD LAYER, not just the predicate — the NSFW
	# verb must be absent/un-fireable below 18 and present/fireable at/above 18.
	var gate_cases := [
		[10.0, false, "child-range (10yr)"],
		[17.9, false, "BOUNDARY just below 18 (17.9yr)"],
		[18.0, true, "BOUNDARY exactly 18 (18.0yr)"],
		[18.1, true, "BOUNDARY just above 18 (18.1yr)"],
		[25.0, true, "young adult (25yr)"],
	]
	for gc in gate_cases:
		var age_yr := float(gc[0])
		var expect_live := bool(gc[1])
		var host := GateTestHost.new()
		host.body_state.age_years = age_yr
		var drv = (CompiledScript.new() if compiled else InterpreterScript.new())
		drv.setup(kit, host)
		var present := _verb_in_live_set(drv, host, compiled)
		var fired := _try_fire_and_check_fired(drv, host, compiled)
		var ok := (present == expect_live) and (fired == expect_live)
		var verdict := "PRESENT + fires" if expect_live else "ABSENT + cannot fire"
		_assert(
			"(%s) %s, is_adult=%s: NSFW verb %s" % [tag, gc[2], str(host.host_is_adult_body()), verdict],
			ok,
			"age_years=%.2f is_adult=%s verb_present=%s verb_fired=%s (expect_live=%s)" % [
				age_yr, str(host.host_is_adult_body()), str(present), str(fired), str(expect_live)])


## Is the NSFW command verb in the LIVE verb set on the focused marker? We resolve
## this the same way the substrate does: the verb's guard must hold under a frame
## that focuses the marker. We reuse the interpreter's guard eval (the reference
## semantics) by stepping the driver with the marker focused and an interact edge,
## and checking the prompt projection surfaces it (present) — but the load-bearing
## check is whether firing actually sets `fired` (below). Here we check PRESENCE via
## the prompt projection, which only surfaces verbs whose guard holds.
func _verb_in_live_set(drv, host, _compiled: bool) -> bool:
	var frame := InterpreterScript.ResolvedFrame.new()
	frame.focus_id = NSFW_DEF
	host.pending_frame = frame
	var prompt: String = drv.project_prompt(frame)
	return prompt.contains("intimate placeholder")


## Fire the NSFW verb via the real verb-fire path (an interact edge with the marker
## focused) and report whether its effect ran (state `fired` flipped true). At
## child-range the guard is false so the verb is not selected and `fired` stays false.
func _try_fire_and_check_fired(drv, host, _compiled: bool) -> bool:
	var frame := InterpreterScript.ResolvedFrame.new()
	frame.focus_id = NSFW_DEF
	frame.edges = { "interact": true }
	host.pending_frame = frame
	drv.step(1.0 / 60.0)
	return bool(drv.state.get(NSFW_DEF, {}).get("fired", false))


# ---------------------------------------------------------------------------

func await_nothing() -> void:
	await get_tree().process_frame


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


## Minimal host implementing the interpreter/compiled host protocol for the gate
## proof. It supplies the body-state hook (host_is_adult_body) — the seam under test —
## plus the no-op physics intents and the pending-frame the driver reads.
class GateTestHost:
	extends RefCounted
	var body_state: BodyState = BodyState.new()
	var pending_frame = null

	func host_is_adult_body() -> bool:
		return body_state != null and body_state.is_adult_body()

	func host_build_frame():
		if pending_frame != null:
			return pending_frame
		return InteractionInterpreter.ResolvedFrame.new()

	# Physics intents — no-ops; the NSFW placeholder verb only sets state + emits.
	func host_grab(_id: String) -> bool: return false
	func host_release(_mode: String, _mag: float) -> void: pass
	func host_apply_impulse(_mag: float) -> void: pass
	func host_socket(_owner_id: String, _body_id: String) -> void: pass
