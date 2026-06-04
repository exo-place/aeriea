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
	_test_is_adult_body_predicate()
	_test_gate_holds_at_guard_layer(false)  # interpreter
	_test_gate_holds_at_guard_layer(true)   # compiled
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# ---------------------------------------------------------------------------
# (a) BodyState drives the blendshape weights on the real mesh.
# ---------------------------------------------------------------------------

func _test_bodystate_drives_morphs() -> void:
	print("--- (a) BodyState -> blendshape weights ---")
	var mesh: ArrayMesh = load(MESH_PATH)
	_assert("base body mesh loads", mesh != null, MESH_PATH)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	await_nothing()

	# Neutral young-adult default: all age weights ~0 (base mesh = young, 25yr), and
	# every other axis at its neutral base value.
	var neutral := BodyState.new()  # defaults: age_years=25 (macro 0.5), masculinity=0, etc.
	neutral.apply_to(mi)
	var w_age_old := float(mi.get("blend_shapes/age_old"))
	var w_age_child := float(mi.get("blend_shapes/age_child"))
	var w_age_baby := float(mi.get("blend_shapes/age_baby"))
	_assert(
		"neutral young-adult default drives ALL age blendshapes to ~0 (base mesh = young)",
		absf(w_age_old) < 1e-4 and absf(w_age_child) < 1e-4 and absf(w_age_baby) < 1e-4,
		"old=%.4f child=%.4f baby=%.4f" % [w_age_old, w_age_child, w_age_baby])

	# Drive age toward OLD (90yr): age_old weight must rise to 1.0.
	var old_bs := BodyState.new()
	old_bs.age_years = 90.0
	old_bs.apply_to(mi)
	var old_w := float(mi.get("blend_shapes/age_old"))
	_assert("BodyState.age_years=90 drives age_old blendshape weight to 1.0",
		absf(old_w - 1.0) < 1e-4, "age_old weight = %.4f" % old_w)

	# Drive age to the CHILD anchor (10yr): age_child weight must be ~1.0.
	var child_bs := BodyState.new()
	child_bs.age_years = 10.0
	child_bs.apply_to(mi)
	var child_w := float(mi.get("blend_shapes/age_child"))
	_assert("BodyState.age_years=10 (child anchor) drives age_child blendshape weight to ~1.0",
		absf(child_w - 1.0) < 1e-4, "age_child weight = %.4f" % child_w)

	# Drive a SECOND axis (masculinity) independently — orthogonality.
	var masc := BodyState.new()
	masc.masculinity = 80.0
	masc.apply_to(mi)
	var gender_w := float(mi.get("blend_shapes/gender_male"))
	_assert("BodyState.masculinity=80%% drives gender_male blendshape weight to 0.8 (axes orthogonal)",
		absf(gender_w - 0.8) < 1e-4, "gender_male weight = %.4f" % gender_w)

	# Weight is 50..150% where 100 = average (base, weight 0); 150 = full max anchor.
	var heavy := BodyState.new()
	heavy.weight = 150.0
	heavy.apply_to(mi)
	var weight_w := float(mi.get("blend_shapes/weight_max"))
	_assert("BodyState.weight=150%% drives weight_max blendshape weight to 1.0",
		absf(weight_w - 1.0) < 1e-4, "weight_max weight = %.4f" % weight_w)

	# The age_years<->macro map is the verified MakeHuman piecewise (§1.4).
	_assert("age_years 18 -> macro ~0.354 (the gate's macro position, verified)",
		absf(BodyState.age_years_to_macro(18.0) - 0.354166) < 1e-4,
		"macro(18yr) = %.6f" % BodyState.age_years_to_macro(18.0))
	_assert("age macro<->years round-trips (25yr<->0.5, 90yr<->1.0)",
		absf(BodyState.age_macro_to_years(0.5) - 25.0) < 1e-4
		and absf(BodyState.age_macro_to_years(1.0) - 90.0) < 1e-4,
		"yr(0.5)=%.2f yr(1.0)=%.2f" % [BodyState.age_macro_to_years(0.5), BodyState.age_macro_to_years(1.0)])

	# And prove the morph weight actually changes the rendered VERTICES: read the
	# age_old morph array vs base and confirm a nonzero displacement (the weight we
	# set above would interpolate the mesh toward that displaced surface).
	var base_arrays := mesh.surface_get_arrays(0)
	var base_verts: PackedVector3Array = base_arrays[Mesh.ARRAY_VERTEX]
	var names := []
	for i in mesh.get_blend_shape_count():
		names.append(str(mesh.get_blend_shape_name(i)))
	var idx := names.find("age_old")
	var max_disp := 0.0
	if idx >= 0:
		var morphed: PackedVector3Array = mesh.surface_get_blend_shape_arrays(0)[idx][Mesh.ARRAY_VERTEX]
		for i in base_verts.size():
			max_disp = max(max_disp, (morphed[i] - base_verts[i]).length())
	_assert("age axis -> age_old blendshape -> nonzero vertex displacement (mesh actually morphs)",
		max_disp > 0.001, "max age_old displacement = %.4f m" % max_disp)

	# Serialization round-trips (BodyState is seeded-sim data).
	var rt := BodyState.from_dict(old_bs.to_dict())
	_assert("BodyState round-trips through to_dict/from_dict (serializable sim data)",
		is_equal_approx(rt.age_years, old_bs.age_years) and is_equal_approx(rt.weight, old_bs.weight),
		"age_years=%.3f weight=%.3f" % [rt.age_years, rt.weight])

	mi.queue_free()


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
	child.age_years = 10.0  # the child anchor (macro 0.1875)
	var cw := child.to_blend_weights()
	_assert("age axis stays continuous/complete: child morph still renders (age_child weight ~1.0)",
		absf(float(cw["age_child"]) - 1.0) < 1e-4 and not child.is_adult_body(),
		"age_child=%.3f is_adult=%s" % [float(cw["age_child"]), str(child.is_adult_body())])


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
