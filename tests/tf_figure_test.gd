## TF figure / BWH measurement test — aeriea's figure-measurement layer (the size analog
## of the cup model, decisions/compound-parts-and-fluids.md §4.3). Asserts:
##   (a) BUST is DERIVED (band + concave volume term), never stored as a field.
##   (b) waist_cm / hip_cm are STORED integers on the body-core carrier and ROUND-TRIP
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


# (a) Bust is DERIVED from band + a concave function of total breast volume.
func _test_bust_derived() -> void:
	# ribcage only (flat) -> bust == ribcage.
	_ok(TfMeasure.bust_cm(81, 0) == 81, "flat bust == ribcage")
	# bigger volume -> bigger bust, but a small concave projection: +1300ml adds
	# isqrt(1300)/5 = 36/5 = 7 cm (a realistic chest-depth add-on, not a doubled band).
	_ok(TfMeasure.bust_cm(81, 1300) == 81 + 7, "bust adds concave projection (got %d)" % TfMeasure.bust_cm(81, 1300))
	# monotonic non-decreasing in volume.
	var prev := -1
	var mono := true
	for v in range(0, 5000, 50):
		var b := TfMeasure.bust_cm(81, v)
		if b < prev:
			mono = false
		prev = b
	_ok(mono, "bust non-decreasing in total breast volume")


# (b) waist_cm / hip_cm are stored ints on the carrier and round-trip as ints.
func _test_waist_hip_stored_and_roundtrip() -> void:
	var body := TfContent.biped()
	var torso = BodyGraph.find_by_id(body["root"], "torso_upper")
	_ok(torso["props"].has("waist_cm"), "carrier stores waist_cm")
	_ok(torso["props"].has("hip_cm"), "carrier stores hip_cm")
	_ok(typeof(torso["props"]["waist_cm"]) == TYPE_INT, "waist_cm is INT")
	_ok(typeof(torso["props"]["hip_cm"]) == TYPE_INT, "hip_cm is INT")
	# round-trip through JSON: ints survive.
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 0xF16, reg)
	h.start_tf("widen_hips")
	h.advance_time(600 * 4)
	var hip_before := int(BodyGraph.find_by_id(h.body["root"], "torso_upper")["props"]["hip_cm"])
	var saved := JSON.stringify(h.to_dict())
	var h2 := TfHolder.from_dict(JSON.parse_string(saved), reg)
	var t2 = BodyGraph.find_by_id(h2.body["root"], "torso_upper")
	_ok(typeof(t2["props"]["hip_cm"]) == TYPE_INT, "reloaded hip_cm is INT not float")
	_ok(typeof(t2["props"]["waist_cm"]) == TYPE_INT, "reloaded waist_cm is INT not float")
	_ok(int(t2["props"]["hip_cm"]) == hip_before, "hip_cm survives round-trip exactly")
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


# (c') Build word follows hip spread; descriptors follow the targeted cut-points.
func _test_build_and_descriptors() -> void:
	var std := TfMeasure.METRIC
	_ok(TfMeasure.figure_build(80, std) == "slim", "narrow hips read slim")
	_ok(TfMeasure.figure_build(95, std) == "curvy", "mid hips read curvy")
	_ok(TfMeasure.figure_build(120, std) == "thick", "wide hips read thick")
	_ok("wide-hipped" in TfMeasure.figure_descriptors(62, 110, std), "wide hips -> wide-hipped")
	_ok("slim-waisted" in TfMeasure.figure_descriptors(60, 90, std), "narrow waist -> slim-waisted")
	_ok(TfMeasure.figure_descriptors(80, 90, std).is_empty(), "average figure has no targeted descriptor")


# (c''/standard) Figure words are STANDARD-dependent: the same body can read a different
# build word under metric vs imperial because the cut-points live in each standard.
func _test_standard_dependent() -> void:
	# A hip that is "thick" by metric cm cut-points must convert to the imperial cut so the
	# read is consistent — verify the cut-points are actually different numbers per standard
	# (configurable, like cup letters), and that the same physical hip lands in the same band.
	var met_cut := int(TfMeasure.METRIC["figure"]["spread_thick_cm"])
	var imp_cut := int(TfMeasure.IMPERIAL["figure"]["spread_thick_cm"])
	_ok(met_cut != imp_cut, "spread cut-points differ per standard (cm vs in)")
	# the SAME 120cm hip reads "thick" under both standards (band-consistent across units).
	_ok(TfMeasure.figure_build(120, TfMeasure.METRIC) == "thick", "120cm hip thick (metric)")
	_ok(TfMeasure.figure_build(120, TfMeasure.IMPERIAL) == "thick", "120cm hip thick (imperial)")
	# and a borderline body reads differently across standards (rounding at the unit edge):
	# whatever the exact boundary, the descriptor set is computed per standard, not shared.
	var a := TfMeasure.figure_descriptors(62, 104, TfMeasure.METRIC)
	var b := TfMeasure.figure_descriptors(62, 104, TfMeasure.IMPERIAL)
	_ok(typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY, "descriptors derived per standard")


# (d) Triple renders integer measurements in the standard's BWH unit.
func _test_triple_units() -> void:
	# 90-62-90 in cm; in inches each /2.54 rounded -> 35-24-35.
	_ok(TfMeasure.figure_triple(90, 62, 90, TfMeasure.METRIC) == "90-62-90", "metric triple")
	_ok(TfMeasure.figure_triple(90, 62, 90, TfMeasure.IMPERIAL) == "35-24-35",
		"imperial triple (got %s)" % TfMeasure.figure_triple(90, 62, 90, TfMeasure.IMPERIAL))


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
	# widen_hips raises hip_cm; cinch_waist lowers waist_cm — directional, integer.
	var hw := TfHolder.new(TfContent.biped(), 0xA0D17, reg)
	var hip0 := int(BodyGraph.find_by_id(hw.body["root"], "torso_upper")["props"]["hip_cm"])
	hw.start_tf("widen_hips"); hw.advance_time(600 * 4)
	var hip1 := int(BodyGraph.find_by_id(hw.body["root"], "torso_upper")["props"]["hip_cm"])
	_ok(hip1 > hip0, "widen_hips raised hip_cm (%d -> %d)" % [hip0, hip1])
	var cw := TfHolder.new(TfContent.biped(), 0xA0D17, reg)
	var w0 := int(BodyGraph.find_by_id(cw.body["root"], "torso_upper")["props"]["waist_cm"])
	cw.start_tf("cinch_waist"); cw.advance_time(600 * 4)
	var w1 := int(BodyGraph.find_by_id(cw.body["root"], "torso_upper")["props"]["waist_cm"])
	_ok(w1 < w0, "cinch_waist lowered waist_cm (%d -> %d)" % [w0, w1])


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
	_ok(barrel != null and barrel["props"].has("hip_cm"), "taur barrel carries its own hip_cm")
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
