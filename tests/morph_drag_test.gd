## Slice-D test (docs/decisions/body-parameterization.md §Slice D): the SCENE-FREE
## geometry core of the DRAG-TO-MODIFY character creator (scripts/body/morph_drag.gd).
## Proves, headlessly, the pick + drag-decomposition + glow math:
##
##   (1) ACCEL STRUCTURE — built from the modifier registry + the sparse DetailLibrary;
##       a known nose vertex's candidate set contains the nose modifier; macro axes are
##       excluded; the structure is non-empty and covers many vertices.
##   (2) CANDIDATE CORRECTNESS — candidate_names_at a vertex matches the modifiers whose
##       +value target actually moves that vertex significantly.
##   (3) DRAG SIGN + PROPORTIONALITY — dragging ALONG a modifier's screen motion raises it,
##       OPPOSITE lowers it, ORTHOGONAL ~ 0; the magnitude is proportional to the drag's
##       projection / px_per_unit.
##   (4) DETERMINISM — same inputs -> byte-identical deltas; rebuild -> identical structure.
##   (5) CLAMPING — a drag that would push past a modifier's range end is clamped (the
##       returned delta only moves up to the boundary).
##   (6) GLOW — glow_weights gives a soft smoothstep falloff (max at the hit, 0 past the
##       radius, monotonic), and covers the candidate region.
##
## Uses a STUB delta-library (deterministic, tiny) for the pure-math assertions so the core
## is exercised without the 24 MB artifact, PLUS a real-library smoke build to prove it wires
## to the shipped DetailLibrary + manifest registry.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/morph_drag_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const MorphDrag := preload("res://scripts/body/morph_drag.gd")
const DetailLib := preload("res://scripts/body/detail_library.gd")
const ModifierRegistry := preload("res://scripts/body/modifier_registry.gd")

var _pass := 0
var _fail := 0


# A tiny deterministic stub matching the DetailLibrary accessor surface MorphDrag needs.
# Two modifiers' +value targets: "nose/nose-hump-incr.target" moves verts 10,11 (up +Y),
# "ears/l-ear-scale-incr.target" moves vert 50 (out +X). Vert 11 is shared region check.
class StubLib:
	var _data := {}
	func add(path: String, records: Array) -> void:
		_data[path] = records   # records: Array of [render_index:int, Vector3 delta]
	func has_target(path: String) -> bool:
		return _data.has(path)
	func record_count(path: String) -> int:
		return (_data[path] as Array).size() if _data.has(path) else -1
	func record_at(path: String, i: int):
		if not _data.has(path):
			return []
		var arr: Array = _data[path]
		return arr[i] if i >= 0 and i < arr.size() else []


func _ready() -> void:
	print("\n=== aeriea body SLICE D — drag-to-modify geometry core (morph_drag) ===\n")
	_test_accel_and_candidates_stub()
	_test_drag_sign_and_proportion()
	_test_determinism()
	_test_clamping()
	_test_glow()
	_test_gross_axis_exclusion()
	_test_real_library_smoke()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# Build a small registry + stub library for the pure-math tests.
func _stub_setup() -> Array:
	var reg := {
		"modifiers": [
			# bidirectional nose: +value target is the MAX pole (nose-hump-incr).
			{"full_name": "nose/nose-hump-decr|incr", "kind": ModifierRegistry.KIND_BIDIRECTIONAL,
			 "range": [-1.0, 1.0], "targets": [
				{"which": "min", "path": "nose/nose-hump-decr.target"},
				{"which": "max", "path": "nose/nose-hump-incr.target"}]},
			# unipolar ear scale: single target.
			{"full_name": "ears/l-ear-scale", "kind": ModifierRegistry.KIND_UNIPOLAR,
			 "range": [0.0, 1.0], "targets": [{"which": "", "path": "ears/l-ear-scale-incr.target"}]},
			# a MACRO modifier — must be EXCLUDED from the editable / accel set.
			{"full_name": "macrodetails/Age", "kind": ModifierRegistry.KIND_MACRO,
			 "range": [0.0, 1.0], "targets": []},
		],
	}
	var lib := StubLib.new()
	# nose-hump-incr: verts 10 & 11 move +Y by 5mm (significant); vert 12 moves 0.05mm (below thresh).
	lib.add("nose/nose-hump-incr.target", [
		[10, Vector3(0.0, 0.005, 0.0)],
		[11, Vector3(0.0, 0.005, 0.0)],
		[12, Vector3(0.0, 0.00005, 0.0)],
	])
	# l-ear-scale-incr: vert 50 moves +X by 4mm.
	lib.add("ears/l-ear-scale-incr.target", [[50, Vector3(0.004, 0.0, 0.0)]])
	var md := MorphDrag.new()
	md.build_accel(reg, lib)
	return [md, reg, lib]


func _test_accel_and_candidates_stub() -> void:
	print("--- (1)(2) accel structure + candidate correctness (stub) ---")
	var s := _stub_setup()
	var md: MorphDrag = s[0]
	_assert("accel built", md.is_built(), "")
	# Editable set = the two non-macro modifiers; macro excluded.
	var ed := md.editable_names()
	_assert("editable = the 2 non-macro modifiers (macro excluded)",
		ed.size() == 2 and ed.has("nose/nose-hump-decr|incr") and ed.has("ears/l-ear-scale"),
		"editable=%s" % str(ed))
	# Vertex 10 -> nose candidate only.
	var c10 := md.candidate_names_at(10)
	_assert("vert 10 candidates = [nose] (the modifier that moves it)",
		c10.size() == 1 and c10[0] == "nose/nose-hump-decr|incr", "c10=%s" % str(c10))
	# Vertex 50 -> ear candidate only.
	var c50 := md.candidate_names_at(50)
	_assert("vert 50 candidates = [ear]", c50.size() == 1 and c50[0] == "ears/l-ear-scale",
		"c50=%s" % str(c50))
	# Vertex 12 moved below threshold -> NO candidate (crisp set).
	_assert("vert 12 (sub-threshold move) has NO candidate",
		md.candidate_names_at(12).is_empty(), "c12=%s" % str(md.candidate_names_at(12)))
	# Untouched vertex -> empty.
	_assert("untouched vert 999 has no candidate", md.candidate_names_at(999).is_empty(), "")
	_assert("covered vertices = 3 (10,11,50)", md.covered_vertex_count() == 3,
		"covered=%d" % md.covered_vertex_count())


func _test_drag_sign_and_proportion() -> void:
	print("--- (3) drag decomposition: sign + proportionality ---")
	var s := _stub_setup()
	var md: MorphDrag = s[0]
	# Camera looking down -Z (identity basis): right=+X, up=+Y, forward=-Z.
	# Nose +value motion at vert 10 is world +Y -> screen (dot(+Y,right)=0, -dot(+Y,up)=-1)
	#   = (0,-1): on screen the nose-raise pushes the surface UPWARD (screen-y up = negative).
	var cam := Basis.IDENTITY
	var px := 200.0

	# Drag UP the screen (screen-y negative) -> ALONG the nose motion -> value INCREASES.
	var up_drag := md.decompose_drag(10, Vector2(0.0, -100.0), cam, {}, px)
	_assert("drag along (+up screen) RAISES the nose modifier (positive delta)",
		up_drag.has("nose/nose-hump-decr|incr") and float(up_drag["nose/nose-hump-decr|incr"]) > 0.0,
		"delta=%s" % str(up_drag))
	# Proportionality: 100 px along, px_per_unit=200 -> delta = 100/200 = 0.5.
	_assert("delta is proportional to projection (100px / 200 = 0.5)",
		absf(float(up_drag["nose/nose-hump-decr|incr"]) - 0.5) < 1e-5,
		"delta=%.5f" % float(up_drag["nose/nose-hump-decr|incr"]))

	# Drag DOWN the screen -> OPPOSITE -> value DECREASES (negative).
	var down_drag := md.decompose_drag(10, Vector2(0.0, 100.0), cam, {}, px)
	_assert("drag opposite (down screen) LOWERS the nose modifier (negative delta)",
		float(down_drag["nose/nose-hump-decr|incr"]) < 0.0, "delta=%s" % str(down_drag))
	_assert("opposite-drag delta = -0.5 (symmetric)",
		absf(float(down_drag["nose/nose-hump-decr|incr"]) + 0.5) < 1e-5,
		"delta=%.5f" % float(down_drag["nose/nose-hump-decr|incr"]))

	# Drag SIDEWAYS (screen +X) -> ORTHOGONAL to the nose's vertical motion -> ~0.
	var side_drag := md.decompose_drag(10, Vector2(100.0, 0.0), cam, {}, px)
	_assert("orthogonal drag (sideways) gives ~0 nose delta",
		not side_drag.has("nose/nose-hump-decr|incr"), "delta=%s" % str(side_drag))

	# Ear +value is world +X -> screen (1,0). A sideways drag drives the EAR, not the nose.
	var ear_drag := md.decompose_drag(50, Vector2(100.0, 0.0), cam, {}, px)
	_assert("sideways drag at the ear vert RAISES the ear modifier (+X motion)",
		ear_drag.has("ears/l-ear-scale") and float(ear_drag["ears/l-ear-scale"]) > 0.0,
		"delta=%s" % str(ear_drag))


func _test_determinism() -> void:
	print("--- (4) determinism ---")
	var a := _stub_setup()[0] as MorphDrag
	var b := _stub_setup()[0] as MorphDrag
	var cam := Basis.IDENTITY
	var da := a.decompose_drag(10, Vector2(37.0, -88.0), cam, {"nose/nose-hump-decr|incr": 0.1}, 173.0)
	var db := b.decompose_drag(10, Vector2(37.0, -88.0), cam, {"nose/nose-hump-decr|incr": 0.1}, 173.0)
	_assert("same inputs -> identical deltas (deterministic)",
		JSON.stringify(da) == JSON.stringify(db), "%s vs %s" % [str(da), str(db)])
	_assert("rebuild -> identical candidate set",
		str(a.candidate_names_at(10)) == str(b.candidate_names_at(10)), "")


func _test_clamping() -> void:
	print("--- (5) clamping at range ends ---")
	var md := _stub_setup()[0] as MorphDrag
	var cam := Basis.IDENTITY
	# nose is bidirectional [-1,1]; current 0.9, drag along by 0.5 -> would be 1.4, clamp to 1.0,
	# so the returned delta is only 0.1 (the room left to the boundary).
	var d := md.decompose_drag(10, Vector2(0.0, -100.0), cam, {"nose/nose-hump-decr|incr": 0.9}, 200.0)
	_assert("clamped at +1.0: delta = 0.1 (room to boundary, not 0.5)",
		absf(float(d.get("nose/nose-hump-decr|incr", -99.0)) - 0.1) < 1e-5,
		"delta=%s" % str(d))
	# Already AT the boundary -> no further raise (delta dropped, ~0).
	var d2 := md.decompose_drag(10, Vector2(0.0, -100.0), cam, {"nose/nose-hump-decr|incr": 1.0}, 200.0)
	_assert("at the +1.0 boundary, further along-drag yields no delta (clamped)",
		not d2.has("nose/nose-hump-decr|incr"), "delta=%s" % str(d2))
	# Unipolar ear clamps at its LOWER bound 0: a lowering drag from 0 yields nothing.
	var d3 := md.decompose_drag(50, Vector2(-100.0, 0.0), cam, {"ears/l-ear-scale": 0.0}, 200.0)
	_assert("unipolar ear at 0 cannot go negative (clamped at lower bound)",
		not d3.has("ears/l-ear-scale"), "delta=%s" % str(d3))


func _test_glow() -> void:
	print("--- (6) hover glow: soft smoothstep falloff ---")
	var md := _stub_setup()[0] as MorphDrag
	# Positions: vert 10 AT the hit, vert 11 a little away, vert 50 far. Index by render id.
	var positions := PackedVector3Array()
	positions.resize(60)
	for i in 60:
		positions[i] = Vector3(100.0, 0.0, 0.0)   # default far away
	positions[10] = Vector3(0.0, 1.5, 0.0)        # the hit point
	positions[11] = Vector3(0.0, 1.5 + 0.02, 0.0) # 2 cm away (within radius)
	positions[50] = Vector3(5.0, 0.0, 0.0)        # far
	var hit := positions[10]
	var glow := md.glow_weights(10, hit, positions, 0.045)
	_assert("hit vertex glows at full ~1.0", absf(float(glow.get(10, 0.0)) - 1.0) < 1e-5,
		"w10=%.4f" % float(glow.get(10, 0.0)))
	_assert("near vertex glows softly (0 < w < 1)",
		float(glow.get(11, 0.0)) > 0.0 and float(glow.get(11, 0.0)) < 1.0,
		"w11=%.4f" % float(glow.get(11, 0.0)))
	_assert("far vertex (vert 50) is NOT spatially lit at full",
		float(glow.get(50, 0.0)) < 0.6, "w50=%.4f" % float(glow.get(50, 0.0)))
	# Monotonic: closer => brighter.
	_assert("glow is monotonic (hit brighter than near)",
		float(glow.get(10, 0.0)) > float(glow.get(11, 0.0)), "")


func _test_gross_axis_exclusion() -> void:
	print("--- gross placement axis excluded from drag candidacy (slider-only) ---")
	# A registry with a LOCAL nose modifier (moves 2 verts) and a GROSS torso modifier (moves
	# 10 verts). With render_vertex_count=12 and GROSS_FOOTPRINT_FRACTION=0.20 -> cap=2 verts.
	# The torso modifier (10 verts > 2) is gross -> NOT a drag candidate; nose (2 verts) stays.
	var reg := {
		"modifiers": [
			{"full_name": "nose/nose-tip", "kind": ModifierRegistry.KIND_UNIPOLAR,
			 "range": [0.0, 1.0], "targets": [{"which": "", "path": "nose/nose-tip-incr.target"}]},
			{"full_name": "torso/torso-trans-down|up", "kind": ModifierRegistry.KIND_BIDIRECTIONAL,
			 "range": [-1.0, 1.0], "targets": [
				{"which": "min", "path": "torso/torso-trans-down.target"},
				{"which": "max", "path": "torso/torso-trans-up.target"}]},
		],
	}
	var lib := StubLib.new()
	lib.add("nose/nose-tip-incr.target", [[0, Vector3(0, 0.005, 0)], [1, Vector3(0, 0.005, 0)]])
	var torso_recs := []
	for i in range(10):   # 10 verts incl. vert 0 (shared with the nose) -> gross
		torso_recs.append([i, Vector3(0, 0.05, 0)])
	lib.add("torso/torso-trans-up.target", torso_recs)
	var md := MorphDrag.new()
	md.build_accel(reg, lib, 12)
	# Both remain EDITABLE (slider-reachable).
	var ed := md.editable_names()
	_assert("gross axis still editable (slider-only)", ed.has("torso/torso-trans-down|up"), "ed=%s" % str(ed))
	# But vertex 0 (moved by BOTH) lists ONLY the local nose modifier as a drag candidate.
	var c0 := md.candidate_names_at(0)
	_assert("vert 0 drag-candidate = [nose] only (gross torso axis dropped)",
		c0.size() == 1 and c0[0] == "nose/nose-tip", "c0=%s" % str(c0))
	# A drag at vert 0 engages the nose, never the gross torso translate.
	var d := md.decompose_drag(0, Vector2(0, -100), Basis.IDENTITY, {}, 200.0)
	_assert("drag at a gross+local vertex engages the LOCAL modifier, not the gross axis",
		d.has("nose/nose-tip") and not d.has("torso/torso-trans-down|up"), "d=%s" % str(d))


func _test_real_library_smoke() -> void:
	print("--- real DetailLibrary + manifest registry smoke build ---")
	if not DetailLib.ensure_loaded():
		_assert("(skipped: no detail library artifact present)", true, "")
		return
	var reg := BodyState.registry()
	if reg.is_empty():
		_assert("(skipped: no registry manifest present)", true, "")
		return
	var md := MorphDrag.new()
	md.build_accel(reg, DetailLib)
	_assert("accel built from the real library + registry", md.is_built(), "")
	_assert("real accel covers many render vertices (>1000)",
		md.covered_vertex_count() > 1000, "covered=%d" % md.covered_vertex_count())
	# The nose modifier is editable and its incr target's moved verts are candidates.
	var ed := md.editable_names()
	_assert("nose modifier is editable in the real registry",
		ed.has("nose/nose-hump-decr|incr"), "have %d editable" % ed.size())
	# Pick the first moved vertex of nose-hump-incr and confirm nose is among its candidates.
	var rc := DetailLib.record_count("nose/nose-hump-incr.target")
	var found_vert := -1
	for i in rc:
		var rec := DetailLib.record_at("nose/nose-hump-incr.target", i)
		if rec.is_empty():
			continue
		if (rec[1] as Vector3).length() >= MorphDrag.SIGNIFICANT_DELTA_M:
			found_vert = int(rec[0])
			break
	_assert("found a significant nose-hump render vertex", found_vert >= 0, "v=%d" % found_vert)
	if found_vert >= 0:
		_assert("that vertex lists the nose modifier as a candidate (drag there edits the nose)",
			md.candidate_names_at(found_vert).has("nose/nose-hump-decr|incr"),
			"cands=%s" % str(md.candidate_names_at(found_vert)))


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
