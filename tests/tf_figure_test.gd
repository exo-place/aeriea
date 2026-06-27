## TF figure / BWH measurement test — aeriea's figure-measurement layer (the size analog
## of the cup model, decisions/compound-parts-and-fluids.md §4.3). Asserts:
##   (a) BUST is DERIVED (band + concave volume term), never stored as a field.
##   (b) waist_mm / hip_mm are STORED integers (mm) on the body-core carrier and ROUND-TRIP
##       save/load as INTEGERS.
##   (c) figure adjectives derive from RATIOS/spread, are RATIO-dependent and
##       STANDARD-dependent (cut-points live in the standard, like cup letters).
##   (d) the measurement triple renders in the standard's unit (cm vs in).
##   (e) the figure-changing TFs (widen_hips, cinch_waist, hourglass_figure) change the
##       rendered figure line.
##
## Run: xvfb-run -a godot4 --path . res://tests/tf_figure_test.tscn --quit-after 2000
extends Node

const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const TfHolder := preload("res://scripts/body/tf/tf_holder.gd")
const TfContent := preload("res://scripts/body/tf/tf_content.gd")
const TfDescribe := preload("res://scripts/body/tf/tf_describe.gd")
const TfMeasure := preload("res://scripts/body/tf/tf_measure.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea TF-figure / BWH test ===\n")
	_test_bust_derived()
	_test_waist_hip_stored_and_roundtrip()
	_test_no_bust_field_stored()
	_test_shape_is_ratio_dependent()
	_test_scale_invariant()
	_test_build_and_descriptors()
	_test_standard_dependent()
	_test_triple_units()
	_test_figure_tfs_change_line()
	_test_base_figure_line_clean()
	_test_taur_carries_own_hip()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


# (a) Bust is DERIVED from band + a concave function of total breast volume. All in mm.
func _test_bust_derived() -> void:
	# ribcage only (flat) -> bust == ribcage.
	_ok(TfMeasure.bust_mm(810, 0) == 810, "flat bust == ribcage")
	# bigger volume -> bigger bust, but a small concave projection: +1300ml adds
	# isqrt(1300)*2 = 36*2 = 72 mm (a realistic chest-depth add-on, not a doubled band).
	_ok(TfMeasure.bust_mm(810, 1300) == 810 + 72, "bust adds concave projection (got %d)" % TfMeasure.bust_mm(810, 1300))
	# monotonic non-decreasing in volume.
	var prev := -1
	var mono := true
	for v in range(0, 5000, 50):
		var b := TfMeasure.bust_mm(810, v)
		if b < prev:
			mono = false
		prev = b
	_ok(mono, "bust non-decreasing in total breast volume")


# (b) waist_cm / hip_cm are stored ints on the carrier and round-trip as ints.
func _test_waist_hip_stored_and_roundtrip() -> void:
	var body := TfContent.biped()
	var torso = BodyGraph.find_by_id(body["root"], "torso_upper")
	_ok(torso["props"].has("waist_mm"), "carrier stores waist_mm")
	_ok(torso["props"].has("hip_mm"), "carrier stores hip_mm")
	_ok(typeof(torso["props"]["waist_mm"]) == TYPE_INT, "waist_mm is INT")
	_ok(typeof(torso["props"]["hip_mm"]) == TYPE_INT, "hip_mm is INT")
	# round-trip through JSON: ints survive.
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 0xF16, reg)
	h.start_tf("widen_hips")
	h.advance_time(600 * 4)
	var hip_before := int(BodyGraph.find_by_id(h.body["root"], "torso_upper")["props"]["hip_mm"])
	var saved := JSON.stringify(h.to_dict())
	var h2 := TfHolder.from_dict(JSON.parse_string(saved), reg)
	var t2 = BodyGraph.find_by_id(h2.body["root"], "torso_upper")
	_ok(typeof(t2["props"]["hip_mm"]) == TYPE_INT, "reloaded hip_mm is INT not float")
	_ok(typeof(t2["props"]["waist_mm"]) == TYPE_INT, "reloaded waist_mm is INT not float")
	_ok(int(t2["props"]["hip_mm"]) == hip_before, "hip_mm survives round-trip exactly")
	_ok(JSON.stringify(h.body) == JSON.stringify(h2.body), "whole body round-trips byte-identically")


# (a') There is NO stored bust field anywhere — the bust is computed, never persisted.
func _test_no_bust_field_stored() -> void:
	var body := TfContent.biped()
	var any_bust := false
	for seg in BodyGraph.all_segments(body["root"]):
		if seg.get("props", {}).has("bust_cm"):
			any_bust = true
	_ok(not any_bust, "no segment stores a bust_cm field (bust is derived)")


# (c) Shape word follows the FULL bust-waist-hip figure, not the waist-to-hip ratio alone.
func _test_shape_is_ratio_dependent() -> void:
	var std := TfMeasure.METRIC
	# bust ≈ hips + defined waist -> hourglass; undefined waist -> straight; waist>=hip -> apple.
	_ok(TfMeasure.figure_shape(90, 60, 92, std) == "hourglass", "balanced + defined waist reads hourglass")
	_ok(TfMeasure.figure_shape(90, 88, 92, std) == "straight", "undefined waist reads straight")
	_ok(TfMeasure.figure_shape(90, 100, 90, std) == "apple", "waist>=hip reads apple")
	# pear: defined waist, hips meaningfully WIDER than the bust.
	_ok(TfMeasure.figure_shape(80, 62, 95, std) == "pear", "hips wider than bust reads pear")
	# top-heavy: defined waist, bust meaningfully WIDER than the hips.
	_ok(TfMeasure.figure_shape(98, 62, 86, std) == "top-heavy", "bust wider than hips reads top-heavy")
	# the SHAPE uses the bust, not the waist-to-hip ratio alone: same WHR, different bust,
	# different shape (this is exactly the bug being fixed).
	_ok(TfMeasure.figure_shape(80, 62, 95, std) != TfMeasure.figure_shape(110, 62, 95, std),
		"shape responds to the bust, not the waist-to-hip ratio alone")
	# the waist-definition gate is RATIO-based: with bust ≈ hips, scaling waist+hip together
	# (same WHR) keeps the same hourglass/straight verdict regardless of raw waist cm.
	_ok(TfMeasure.figure_shape(90, 60, 90, std) == TfMeasure.figure_shape(180, 120, 180, std),
		"the waist-definition gate uses the ratio, not the raw waist magnitude")


# (scale-invariance) The figure descriptor is a function of PROPORTIONS only: a body and a
# uniformly scaled copy (giant / fae) with the IDENTICAL B:W:H ratios must read the IDENTICAL
# shape, build and descriptors. This is the core defect being fixed — absolute-cm thresholds
# made a scaled-up body flip shape/build for free.
func _test_scale_invariant() -> void:
	var std := TfMeasure.METRIC
	# Base hourglass proportions bust:waist:hip = 880:620:900 mm (the realistic adult figure,
	# ~88-62-90 cm). Scales span SPRITE (0.1×) to GIANT (3×). The 0.1× case is the one that
	# used to break: stored in whole cm, a 62 cm waist truncated to 6 cm at sprite scale and
	# the proportions distorted; stored in mm, 620 mm scales cleanly to 62 mm and the ratios
	# hold, so the sprite reads the SAME figure as the base.
	var scales := [10, 30, 50, 100, 200, 300]  # × base / 100  (0.1× sprite .. 3× giant)
	var shape0 := ""
	var desc0: Array = []
	var consistent := true
	var label0 := ""
	for s_v in scales:
		var s: int = s_v
		var bust := 880 * s / 100
		var waist := 620 * s / 100
		var hip := 900 * s / 100
		var shape := TfMeasure.figure_shape(bust, waist, hip, std)
		var build := TfMeasure.figure_build(waist, hip, std)
		var desc := TfMeasure.figure_descriptors(bust, waist, hip, std)
		var label := "%s|%s|%s" % [shape, build, ",".join(desc)]
		if s == int(scales[0]):
			shape0 = shape; desc0 = desc; label0 = label
		elif label != label0:
			consistent = false
			print("    scale %d: %s  (base %s)" % [s, label, label0])
	_ok(consistent, "same B:W:H ratio at every scale (0.1×..3×) reads the IDENTICAL figure descriptor (%s)" % label0)
	_ok(shape0 == "hourglass", "scaled hourglass proportions read hourglass at every scale")
	_ok("slim-waisted" in desc0, "scaled slim-waisted proportions read slim-waisted at every scale")
	# A genuinely PEAR-proportioned body stays pear at every scale too (including sprite).
	var pear_ok := true
	for s_v in scales:
		var s: int = s_v
		if TfMeasure.figure_shape(800 * s / 100, 620 * s / 100, 1000 * s / 100, std) != "pear":
			pear_ok = false
	_ok(pear_ok, "pear proportions read pear at every scale")


# (c') Build word follows the hip-to-waist FLARE ratio (a proportion); descriptors follow
# the targeted RATIO cut-points. Build/descriptors take (waist, hip) / (bust, waist, hip).
func _test_build_and_descriptors() -> void:
	var std := TfMeasure.METRIC
	# build = hip/waist flare ratio: slim < 130, thick >= 160, else curvy.
	_ok(TfMeasure.figure_build(70, 80, std) == "slim", "low flare (80/70=114) reads slim")
	_ok(TfMeasure.figure_build(65, 95, std) == "curvy", "mid flare (95/65=146) reads curvy")
	_ok(TfMeasure.figure_build(62, 110, std) == "thick", "high flare (110/62=177) reads thick")
	_ok("wide-hipped" in TfMeasure.figure_descriptors(90, 62, 110, std), "strong flare -> wide-hipped")
	_ok("slim-waisted" in TfMeasure.figure_descriptors(90, 60, 90, std), "narrow waist -> slim-waisted")
	_ok(TfMeasure.figure_descriptors(90, 84, 90, std).is_empty(), "average figure has no targeted descriptor")


# (c''/standard) Figure words are now PROPORTION-based, so they are UNIT-FREE: a ratio reads
# the same in cm or inches. The figure thresholds are therefore identical across standards,
# and the SAME body reads the SAME figure word under metric and imperial (only the rendered
# triple differs by unit). This is correct: a proportion has no unit.
func _test_standard_dependent() -> void:
	# The figure block is the shared unit-free ratio table — same thresholds both standards.
	_ok(TfMeasure.METRIC["figure"] == TfMeasure.IMPERIAL["figure"],
		"figure thresholds are unit-free ratios, identical across standards")
	# the SAME physical figure reads the SAME build/shape under either standard (a proportion
	# is unit-independent — that is the whole point of the ratio model).
	_ok(TfMeasure.figure_build(62, 110, TfMeasure.METRIC)
		== TfMeasure.figure_build(62, 110, TfMeasure.IMPERIAL), "build word unit-independent")
	_ok(TfMeasure.figure_shape(88, 62, 90, TfMeasure.METRIC)
		== TfMeasure.figure_shape(88, 62, 90, TfMeasure.IMPERIAL), "shape word unit-independent")
	# but the rendered TRIPLE still differs by unit (cm vs inches). Inputs are mm.
	_ok(TfMeasure.figure_triple(880, 620, 900, TfMeasure.METRIC)
		!= TfMeasure.figure_triple(880, 620, 900, TfMeasure.IMPERIAL), "triple still renders per unit")


# (d) Triple renders integer mm measurements in the standard's BWH unit.
func _test_triple_units() -> void:
	# 880-620-900 mm -> 88-62-90 cm (mm/10); in inches each mm/25.4 rounded -> 35-24-35.
	_ok(TfMeasure.figure_triple(880, 620, 900, TfMeasure.METRIC) == "88-62-90",
		"metric triple (got %s)" % TfMeasure.figure_triple(880, 620, 900, TfMeasure.METRIC))
	_ok(TfMeasure.figure_triple(880, 620, 900, TfMeasure.IMPERIAL) == "35-24-35",
		"imperial triple (got %s)" % TfMeasure.figure_triple(880, 620, 900, TfMeasure.IMPERIAL))


# (e) The figure-changing TFs visibly change the rendered figure line.
func _test_figure_tfs_change_line() -> void:
	var reg := TfContent.registry()
	var base_line := _figure_line(TfContent.biped())
	for tf_id in ["widen_hips", "cinch_waist", "hourglass_figure"]:
		var h := TfHolder.new(TfContent.biped(), 0xA0D17, reg)
		h.start_tf(tf_id)
		h.advance_time(600 * 4)
		var after := _figure_line(h.body)
		_ok(after != base_line, "%s changed the figure line (%s)" % [tf_id, after])
	# widen_hips raises hip_mm; cinch_waist lowers waist_mm — directional, integer.
	var hw := TfHolder.new(TfContent.biped(), 0xA0D17, reg)
	var hip0 := int(BodyGraph.find_by_id(hw.body["root"], "torso_upper")["props"]["hip_mm"])
	hw.start_tf("widen_hips"); hw.advance_time(600 * 4)
	var hip1 := int(BodyGraph.find_by_id(hw.body["root"], "torso_upper")["props"]["hip_mm"])
	_ok(hip1 > hip0, "widen_hips raised hip_mm (%d -> %d)" % [hip0, hip1])
	var cw := TfHolder.new(TfContent.biped(), 0xA0D17, reg)
	var w0 := int(BodyGraph.find_by_id(cw.body["root"], "torso_upper")["props"]["waist_mm"])
	cw.start_tf("cinch_waist"); cw.advance_time(600 * 4)
	var w1 := int(BodyGraph.find_by_id(cw.body["root"], "torso_upper")["props"]["waist_mm"])
	_ok(w1 < w0, "cinch_waist lowered waist_mm (%d -> %d)" % [w0, w1])


# (clean prose) The base figure line reads like prose, with a proper article and triple,
# and there is NO "hips"/"pelvis" PART bullet (BWH is a measurement, not a part).
func _test_base_figure_line_clean() -> void:
	var desc := TfDescribe.describe(TfContent.biped())
	_ok("An hourglass figure" in desc, "base reads as an hourglass figure")
	_ok("—" in _figure_line(TfContent.biped()), "figure line carries the measurement triple")
	# no part bullet for hips/pelvis (a measurement must never become an inventory line).
	_ok(not ("- A bare-skinned hips" in desc), "no 'hips' part bullet")
	_ok(not ("pelvis" in desc.to_lower()), "no 'pelvis' anywhere in the description")


# (taur) A taur's barrel carries its OWN hip measure — the figure reads off the lower body
# once a distinct lower body exists, not the upright torso.
func _test_taur_carries_own_hip() -> void:
	var TfLibrary := preload("res://scripts/body/tf/tf_library.gd")
	var lreg := TfLibrary.registry()
	var h := TfHolder.new(TfContent.biped(), 0xA0D17, lreg)
	h.apply_instant("biped_to_taur")
	var barrel = BodyGraph.find_by_id(h.body["root"], "barrel")
	_ok(barrel != null and barrel["props"].has("hip_mm"), "taur barrel carries its own hip_mm")
	var line := _figure_line(h.body)
	# the barrel's hips (110) read in the triple, not the torso's (90).
	_ok("-110" in line, "taur figure triple reads the barrel's hips (got %s)" % line)


# Pull just the figure line out of a body's description.
func _figure_line(body: Dictionary, std: Dictionary = {}) -> String:
	var desc: String = TfDescribe.describe(body, std) if not std.is_empty() else TfDescribe.describe(body)
	for line in desc.split("\n"):
		if "figure" in line:
			return line.strip_edges()
	return ""
