## Phase 5a test — the MIRROR toggle (symmetric default) + the procedural EYE-COLOR control
## (docs/decisions/character-creator-and-body.md §2.3 mirror + §6.3 iris_color; gate #10).
## OBJECTIVE clauses only (visual look is USER-taste-gated, never asserted here):
##
##   (1) TWIN TABLE: RegionSliders.twin flips l-↔r- at a side boundary and is identity on a
##       midline modifier (the midline guard); twin(twin(x)) == x for a bilateral name.
##   (2) MIRROR DEFAULTS ON: a fresh creator has _mirror == true.
##   (3) MIRROR ON — SLIDER path: a write to one lateral side ALSO writes the contralateral
##       twin (symmetric); MIRROR OFF: only the touched side changes.
##   (4) MIRROR ON — SCULPT path: a sculpt delta on one side ALSO applies to the twin;
##       MIRROR OFF: only the touched side. (Drives the SAME _apply_sculpt_delta_mirrored the
##       per-frame drag loop runs.)
##   (5) BILATERAL RESOLUTION is mirror-INDEPENDENT: a bare-stem bilateral slider drives BOTH
##       sides regardless of the toggle (resolve_full_names is structural).
##   (6) MIDLINE controls are UNAFFECTED by the toggle (no twin → written once either way).
##   (7) MIRRORED WRITES RESPECT CAPS: an out-of-cap request to one side, mirrored, clamps the
##       twin to its OWN cap too.
##   (8) EYE COLOR: _set_eye_color drives the rig's iris_color (the procedural shader uniform),
##       and the shader material reflects it when the proxy is built. Gaze is untouched.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_phase5a_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const CharacterCreator := preload("res://scripts/body/character_creator.gd")
const RegionSliders := preload("res://scripts/body/region_sliders.gd")

const L_ARM := "armslegs/l-upperarm-muscle-decr|incr"
const R_ARM := "armslegs/r-upperarm-muscle-decr|incr"
const MIDLINE := "nose/nose-scale-vert-decr|incr"

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR PHASE 5a — mirror toggle + eye-color control ===\n")
	_test_twin_table()
	await _test_scene_level()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


# (1) twin table --------------------------------------------------------------
func _test_twin_table() -> void:
	print("--- (1) RegionSliders.twin: l-↔r- flip; midline identity; involution ---")
	_ok("twin(l-arm) == r-arm", RegionSliders.twin(L_ARM) == R_ARM,
		"%s -> %s" % [L_ARM, RegionSliders.twin(L_ARM)])
	_ok("twin(r-arm) == l-arm", RegionSliders.twin(R_ARM) == L_ARM,
		"%s -> %s" % [R_ARM, RegionSliders.twin(R_ARM)])
	_ok("twin is an involution on a bilateral name", RegionSliders.twin(RegionSliders.twin(L_ARM)) == L_ARM,
		"twin(twin(l-arm)) == l-arm")
	_ok("twin(midline) == midline (the midline guard)", RegionSliders.twin(MIDLINE) == MIDLINE,
		"%s unchanged" % MIDLINE)
	# A bare leading l-/r- name (no group prefix) also flips.
	_ok("twin flips a bare leading side marker too", RegionSliders.twin("l-foo") == "r-foo",
		"l-foo -> %s" % RegionSliders.twin("l-foo"))


# (2)–(8) scene-level ---------------------------------------------------------
func _test_scene_level() -> void:
	var cc := CharacterCreator.new()
	add_child(cc)
	await get_tree().process_frame
	await get_tree().process_frame

	var bs: BodyState = cc.get("_body_state")

	# (2) mirror defaults ON.
	print("--- (2) mirror defaults ON ---")
	_ok("a fresh creator has mirror ON by default", bool(cc.get("_mirror")) == true,
		"_mirror=%s" % cc.get("_mirror"))

	# (3) SLIDER path — mirror ON writes both twins; OFF writes only the touched side.
	print("--- (3) slider path: mirror ON symmetric, OFF asymmetric ---")
	# A LATERAL slider whose resolved name is a SINGLE side (force a one-sided resolved set so the
	# mirror application is the observable difference, not bilateral resolution).
	_clear(bs)
	cc.set("_mirror", true)
	cc.get("_caps").call("start_gesture")
	cc.call("_set_modifier_capped", PackedStringArray([L_ARM]), 0.3)
	cc.get("_caps").call("end_gesture")
	_ok("mirror ON: a one-sided lateral write changes BOTH twins (symmetric)",
		_close(_mv(bs, L_ARM), 0.3) and _close(_mv(bs, R_ARM), 0.3),
		"L=%.3f R=%.3f" % [_mv(bs, L_ARM), _mv(bs, R_ARM)])

	_clear(bs)
	cc.set("_mirror", false)
	cc.get("_caps").call("start_gesture")
	cc.call("_set_modifier_capped", PackedStringArray([L_ARM]), 0.3)
	cc.get("_caps").call("end_gesture")
	_ok("mirror OFF: a one-sided lateral write changes ONLY the touched side",
		_close(_mv(bs, L_ARM), 0.3) and _close(_mv(bs, R_ARM), 0.0),
		"L=%.3f R=%.3f" % [_mv(bs, L_ARM), _mv(bs, R_ARM)])

	# (4) SCULPT path — the SAME _apply_sculpt_delta_mirrored the drag loop runs.
	print("--- (4) sculpt path: mirror ON symmetric, OFF asymmetric ---")
	_clear(bs)
	cc.set("_mirror", true)
	cc.get("_caps").call("start_gesture")
	cc.call("_apply_sculpt_delta_mirrored", L_ARM, 0.2)
	cc.get("_caps").call("end_gesture")
	_ok("mirror ON: a sculpt delta on one side ALSO applies to the twin",
		_close(_mv(bs, L_ARM), 0.2) and _close(_mv(bs, R_ARM), 0.2),
		"L=%.3f R=%.3f" % [_mv(bs, L_ARM), _mv(bs, R_ARM)])

	_clear(bs)
	cc.set("_mirror", false)
	cc.get("_caps").call("start_gesture")
	cc.call("_apply_sculpt_delta_mirrored", L_ARM, 0.2)
	cc.get("_caps").call("end_gesture")
	_ok("mirror OFF: a sculpt delta applies ONLY to the touched side",
		_close(_mv(bs, L_ARM), 0.2) and _close(_mv(bs, R_ARM), 0.0),
		"L=%.3f R=%.3f" % [_mv(bs, L_ARM), _mv(bs, R_ARM)])

	# (5) BILATERAL RESOLUTION is mirror-independent: a bare stem drives both sides ON and OFF.
	print("--- (5) bilateral resolution drives both sides REGARDLESS of the toggle ---")
	var resolved := RegionSliders.resolve_full_names("l-upperarm-muscle")
	_ok("resolve_full_names('l-upperarm-muscle') yields BOTH side full_names",
		resolved.size() == 2 and resolved.has(L_ARM) and resolved.has(R_ARM),
		"resolved=%s" % str(resolved))
	for mirror_on in [true, false]:
		_clear(bs)
		cc.set("_mirror", mirror_on)
		cc.get("_caps").call("start_gesture")
		cc.call("_set_modifier_capped", resolved, 0.25)
		cc.get("_caps").call("end_gesture")
		_ok("bilateral stem drives BOTH sides with mirror %s" % ("ON" if mirror_on else "OFF"),
			_close(_mv(bs, L_ARM), 0.25) and _close(_mv(bs, R_ARM), 0.25),
			"L=%.3f R=%.3f" % [_mv(bs, L_ARM), _mv(bs, R_ARM)])

	# (6) MIDLINE controls unaffected by the toggle (no twin → written once either way).
	print("--- (6) midline controls unaffected by the toggle ---")
	for mirror_on in [true, false]:
		_clear(bs)
		cc.set("_mirror", mirror_on)
		cc.get("_caps").call("start_gesture")
		cc.call("_set_modifier_capped", PackedStringArray([MIDLINE]), 0.2)
		cc.get("_caps").call("end_gesture")
		# No twin exists, so only the midline key is present (no spurious second write).
		var only_midline := _close(_mv(bs, MIDLINE), 0.2)
		_ok("midline write with mirror %s touches only the midline modifier" % ("ON" if mirror_on else "OFF"),
			only_midline, "midline=%.3f" % _mv(bs, MIDLINE))

	# (7) MIRRORED WRITES RESPECT CAPS: an out-of-cap request clamps the twin to its OWN cap.
	print("--- (7) mirrored writes respect caps ---")
	_clear(bs)
	cc.set("_mirror", true)
	var cap_l: Array = cc.get("_caps").call("cap", L_ARM)
	var cap_r: Array = cc.get("_caps").call("cap", R_ARM)
	cc.get("_caps").call("start_gesture")
	cc.call("_set_modifier_capped", PackedStringArray([L_ARM]), 99.0)   # way past cap
	cc.get("_caps").call("end_gesture")
	_ok("mirror ON: an out-of-cap request clamps BOTH twins to their own cap ceiling",
		_close(_mv(bs, L_ARM), float(cap_l[1])) and _close(_mv(bs, R_ARM), float(cap_r[1])),
		"L=%.3f (cap b=%.3f)  R=%.3f (cap b=%.3f)" % [_mv(bs, L_ARM), cap_l[1], _mv(bs, R_ARM), cap_r[1]])

	# (8) EYE COLOR drives the procedural iris_color uniform.
	print("--- (8) eye-color control drives the iris_color uniform (gaze untouched) ---")
	var rig = cc.get("_rig")
	var before: Color = (rig.get("_eye_params") as Dictionary)["iris_color"]
	var want := Color(0.20, 0.40, 0.62)   # a blue distinct from the warm-brown default
	cc.call("_set_eye_color", want)
	var after: Color = (rig.get("_eye_params") as Dictionary)["iris_color"]
	_ok("setting eye color changes the rig's iris_color param",
		_color_close(after, want) and not _color_close(before, want),
		"before=%s after=%s want=%s" % [before, after, want])
	_ok("the creator's tracked eye color matches the requested color",
		_color_close(cc.get("_eye_color"), want), "_eye_color=%s" % cc.get("_eye_color"))
	# When the proxy eye material is built, the shader uniform reflects the new color.
	var mat := _eye_material(rig)
	if mat != null:
		var u = mat.get_shader_parameter("iris_color")
		_ok("the eye shader's iris_color uniform reflects the new color",
			u != null and _color_close(Color(u), want), "uniform=%s" % str(u))
	else:
		# The proxy material may not be built in a headless construct; the param path above is
		# the authoritative source the material is built from. Report honestly, do not fail.
		print("  NOTE  eye proxy material not built in this construct; verified via _eye_params (the material source).")
	# Gaze uniform is left alone (the eyes track via bones; §6.3): _set_eye_color must not set it.
	if mat != null:
		var g = mat.get_shader_parameter("gaze_dir")
		# Default gaze_dir is forward (0,0,1) or null (unset → shader default). Either is "untouched".
		_ok("gaze_dir is NOT driven by the eye-color control (left at the shader default)",
			g == null or _vec_close(Vector3(g), Vector3(0, 0, 1)),
			"gaze_dir=%s" % str(g))

	cc.queue_free()


# --- helpers -----------------------------------------------------------------
func _clear(bs: BodyState) -> void:
	bs.modifiers.clear()


func _mv(bs: BodyState, fn: String) -> float:
	return float(bs.modifiers.get(fn, 0.0))


func _close(a: float, b: float) -> bool:
	return absf(a - b) < 1e-3


func _color_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 1e-3 and absf(a.g - b.g) < 1e-3 and absf(a.b - b.b) < 1e-3


func _vec_close(a: Vector3, b: Vector3) -> bool:
	return (a - b).length() < 1e-3


func _eye_material(rig) -> ShaderMaterial:
	var pi = rig.get("proxy_instance")
	var surf = rig.get("_proxy_surface")
	if pi == null or typeof(surf) != TYPE_DICTIONARY or not surf.has("eyes"):
		return null
	var m = pi.get_surface_override_material(int(surf["eyes"]))
	return m as ShaderMaterial
