## Face-expression test — the ported FaceRig behind aeriea's apply_expression seam.
##
## Asserts:
##   (a) DETERMINISM — same seed + same dt sequence + same pushed ExprState gives
##       the identical resolved face (the seeded-RNG / no-wall-clock invariant);
##   (b) AFFECT MAPPING sanity — positive valence -> smile not sad; negative ->
##       sad not smile; high tension -> angry brows; low attention -> lidded eyes;
##       do_talk drives the talk channel then decays;
##   (c) MAREN CHAIN — npc_maren state -> ExprState reacts correctly across a
##       guarded -> warming -> at-ease sequence (valence rises, tension falls);
##   (d) COVERAGE — the channel-coverage report is honest (driven-by-bone vs gap).
##
## Run: xvfb-run -a godot4 --path . res://tests/face_expression_test.tscn --quit-after 2000
extends Node

const FaceRig := preload("res://scripts/body/face/face_rig.gd")
const MarenAffect := preload("res://scripts/body/face/maren_affect.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea face-expression test ===\n")
	_test_determinism()
	_test_affect_mapping()
	_test_talk_pulse()
	_test_maren_chain()
	_test_coverage()
	_test_blendshape_sink()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


func _approx(a: float, b: float, eps := 1e-5) -> bool:
	return absf(a - b) <= eps


# Run a rig (no skeleton — pure channel resolve) for `steps` of `dt` with a fixed
# ExprState pushed, returning the final resolved dict.
func _run(seed: int, e: ExprState, steps: int, dt: float) -> Dictionary:
	var rig := FaceRig.new()
	add_child(rig)
	rig.set_process(false)   # drive manually for deterministic dt
	rig.setup(seed, null)
	rig.apply_expression(e)
	for i in steps:
		rig.step(dt)
	var out: Dictionary = rig.resolved()
	rig.queue_free()
	return out


func _test_determinism() -> void:
	var e := ExprState.new(0.6, 0.3, 0.1, 0.9, 0.0, "")
	var a := _run(42, e, 120, 1.0 / 60.0)
	var b := _run(42, e, 120, 1.0 / 60.0)
	var same := true
	for k in a:
		if a[k] is Vector2:
			same = same and a[k].is_equal_approx(b[k])
		else:
			same = same and _approx(a[k], b[k])
	_ok(same, "same seed+dt+ExprState -> identical resolved face")
	# A different seed perturbs the autonomous gestures (blink/look), so SOME
	# channel should differ -> confirms the seed actually drives randomness.
	var c := _run(99, e, 120, 1.0 / 60.0)
	var differs: bool = not (a["look_dir"] as Vector2).is_equal_approx(c["look_dir"]) \
		or not _approx(a["eyes_closed"], c["eyes_closed"])
	_ok(differs, "different seed perturbs autonomous gestures (seed is live)")


func _test_affect_mapping() -> void:
	var happy := _run(7, ExprState.new(0.9, 0.4, 0.0, 1.0), 30, 1.0 / 60.0)
	_ok(happy["mouth_smile"] > 0.3, "positive valence -> smile")
	_ok(happy["mouth_sad"] < 0.05, "positive valence -> not sad")

	var sad := _run(7, ExprState.new(-0.9, 0.1, 0.0, 1.0), 30, 1.0 / 60.0)
	_ok(sad["mouth_sad"] > 0.3, "negative valence -> sad")
	_ok(sad["mouth_smile"] < 0.05, "negative valence -> not smiling")

	var tense := _run(7, ExprState.new(0.0, 0.3, 0.95, 1.0), 30, 1.0 / 60.0)
	_ok(tense["brows_angry"] > 0.5, "high tension -> angry brows")

	var withdrawn := _run(7, ExprState.new(0.0, 0.0, 0.0, 0.0), 30, 1.0 / 60.0)
	var engaged := _run(7, ExprState.new(0.0, 0.0, 0.0, 1.0), 30, 1.0 / 60.0)
	# Low attention should bias eyes more closed than full attention (modulo blink).
	_ok(withdrawn["eyes_closed"] >= engaged["eyes_closed"],
		"low attention -> more lidded eyes than high attention")


func _test_talk_pulse() -> void:
	var rig := FaceRig.new()
	add_child(rig)
	rig.set_process(false)
	rig.setup(3, null)
	rig.apply_expression(ExprState.new(0.0, 0.0, 0.0, 1.0))
	rig.do_talk(1.0)
	# Mid-pulse the talk channel is up.
	for i in 24:   # ~0.4s
		rig.step(1.0 / 60.0)
	var mid: float = rig.resolved()["talking"]
	_ok(mid > 0.3, "do_talk drives the talk channel")
	# After the pulse it decays back to ~0.
	for i in 90:   # +1.5s
		rig.step(1.0 / 60.0)
	var late: float = rig.resolved()["talking"]
	_ok(late < 0.05, "talk channel decays after the pulse")
	rig.queue_free()


func _test_maren_chain() -> void:
	var guarded := MarenAffect.to_expr({"mood": 0.5, "rapport": 0.15, "last_social_act": "greeted"})
	var warming := MarenAffect.to_expr({"mood": 0.7, "rapport": 0.5, "last_social_act": "complimented"})
	var at_ease := MarenAffect.to_expr({"mood": 0.92, "rapport": 0.85, "last_social_act": "chatted"})
	_ok(at_ease.valence > warming.valence and warming.valence > guarded.valence,
		"valence rises as Maren's mood improves")
	_ok(guarded.tension > warming.tension and warming.tension > at_ease.tension,
		"tension falls as rapport grows")
	_ok(at_ease.attention > guarded.attention,
		"attention grows with rapport")
	# Pure function of state.
	var again := MarenAffect.to_expr({"mood": 0.92, "rapport": 0.85, "last_social_act": "chatted"})
	_ok(_approx(again.valence, at_ease.valence) and _approx(again.tension, at_ease.tension),
		"Maren affect projection is a pure function of state")


func _test_coverage() -> void:
	var cov := FaceRig.channel_coverage()
	_ok(cov["driven_by_bone"].has("mouth_open") and cov["driven_by_bone"].has("look_dir")
		and cov["driven_by_bone"].has("eyes_closed"),
		"bone-driven channels reported (jaw/eyes/lids)")
	# The expression-import closed the smile/sad/brow gap: these now have geometry.
	_ok(cov["driven_by_blendshape"].has("mouth_smile") and cov["driven_by_blendshape"].has("brows_angry")
		and cov["driven_by_blendshape"].has("mouth_sad"),
		"affect channels now driven by imported CC0 expression blendshapes")
	# Honest about what is still uncovered (no faithful CC0 AU) and approximated.
	_ok(cov["gap_no_geometry"].has("mouth_panting") and cov["gap_no_geometry"].has("talking"),
		"still-uncovered channels reported honestly (no panting/viseme AU)")
	_ok(cov["approximated"].has("eyes_sexy") and cov["approximated"].has("mouth_blep"),
		"approximated channels flagged honestly (near-miss CC0 AU)")


# The MESH actually carries the channel-named expression blendshapes, and the sink
# drives them: pushing a happy vs sad affect produces DIFFERENT blendshape weights.
func _test_blendshape_sink() -> void:
	var mesh: ArrayMesh = load("res://assets/body/base_body.res")
	_ok(mesh != null, "base_body.res loads")
	if mesh == null:
		return
	var have := {}
	for i in mesh.get_blend_shape_count():
		have[str(mesh.get_blend_shape_name(i))] = true
	for n in ["MouthSmile", "MouthSad", "BrowsAngry", "EyesClosed", "MouthSnarl", "BrowsShy"]:
		_ok(have.has(n), "mesh declares expression blendshape '%s'" % n)
	# Drive a real MeshInstance and confirm the sink writes distinct weights per affect.
	var mi := MeshInstance3D.new()
	mi.mesh = mesh.duplicate(true)
	add_child(mi)
	var happy_w := _drive_weight(mi, ExprState.new(0.9, 0.4, 0.0, 1.0), "MouthSmile")
	var sad_w := _drive_weight(mi, ExprState.new(-0.9, 0.1, 0.0, 1.0), "MouthSmile")
	_ok(happy_w > 0.3 and sad_w < 0.05, "happy drives MouthSmile blendshape; sad does not")
	var sad_frown := _drive_weight(mi, ExprState.new(-0.9, 0.1, 0.0, 1.0), "MouthSad")
	_ok(sad_frown > 0.3, "sad drives the MouthSad blendshape")
	var angry := _drive_weight(mi, ExprState.new(0.0, 0.3, 0.95, 1.0), "BrowsAngry")
	_ok(angry > 0.5, "high tension drives the BrowsAngry blendshape")
	mi.queue_free()


func _drive_weight(mi: MeshInstance3D, e: ExprState, shape: String) -> float:
	var rig := FaceRig.new()
	add_child(rig)
	rig.set_process(false)
	rig.setup(7, null, mi)
	rig.apply_expression(e)
	for i in 30:
		rig.step(1.0 / 60.0)
	var w := float(mi.get("blend_shapes/%s" % shape))
	rig.queue_free()
	return w
