## TF size / measurement test — aeriea's canonical size + configurable measurement
## model (decisions/compound-parts-and-fluids.md §4.3). Asserts:
##   (a) WORKED EXAMPLE — (volume_ml=1200, band_cm=32) renders "13DD" under IMPERIAL
##       and "32G" under METRIC (the same body, two standards).
##   (b) isqrt is a correct integer floor sqrt; diff_mm matches the spec.
##   (c) cup is MONOTONIC: non-decreasing in volume, non-increasing in band.
##   (d) volume_ml / band_cm ROUND-TRIP save/load as INTEGERS.
##   (e) size TFs (grow_breasts, widen_band, grow_butt) change the derived label.
##   (f) unit conversions render inches / floz under IMPERIAL, cm / ml under METRIC.
##
## Run: xvfb-run -a godot4 --path . res://tests/tf_size_test.tscn --quit-after 2000
extends Node

const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const TfHolder := preload("res://scripts/body/tf/tf_holder.gd")
const TfContent := preload("res://scripts/body/tf/tf_content.gd")
const TfDescribe := preload("res://scripts/body/tf/tf_describe.gd")
const TfMeasure := preload("res://scripts/body/tf/tf_measure.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea TF-size / measurement test ===\n")
	_test_worked_example()
	_test_isqrt_and_diff()
	_test_monotonic_in_volume()
	_test_monotonic_in_band()
	_test_size_roundtrip_int()
	_test_size_tfs_change_label()
	_test_unit_conversions()
	_test_describe_uses_standard()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


# (a) The vetted worked example: same canonical body, two standards.
func _test_worked_example() -> void:
	var imp := TfMeasure.cup_label(1200, 32, TfMeasure.IMPERIAL)
	var met := TfMeasure.cup_label(1200, 32, TfMeasure.METRIC)
	_ok(imp == "13DD", "(1200,32) imperial cup is 13DD (got %s)" % imp)
	_ok(met == "32G", "(1200,32) metric cup is 32G (got %s)" % met)
	# intermediate values from the spec.
	_ok(TfMeasure.diff_mm(1200, 32) == 144, "diff_mm(1200,32)==144 (got %d)" % TfMeasure.diff_mm(1200, 32))
	_ok(TfMeasure.band_in_unit(32, TfMeasure.IMPERIAL) == 13, "32cm band -> 13in")
	_ok(TfMeasure.band_in_unit(32, TfMeasure.METRIC) == 32, "32cm band -> 32cm")


# (b) isqrt is floor-sqrt; diff_mm = max(0, 8*isqrt(v) - 4*b).
func _test_isqrt_and_diff() -> void:
	_ok(TfMeasure.isqrt(0) == 0, "isqrt(0)==0")
	_ok(TfMeasure.isqrt(1) == 1, "isqrt(1)==1")
	_ok(TfMeasure.isqrt(15) == 3, "isqrt(15)==3")
	_ok(TfMeasure.isqrt(16) == 4, "isqrt(16)==4")
	_ok(TfMeasure.isqrt(1200) == 34, "isqrt(1200)==34")
	_ok(TfMeasure.isqrt(1225) == 35, "isqrt(1225)==35 (35^2)")
	# diff floors at 0 (a huge band swamps the volume term).
	_ok(TfMeasure.diff_mm(100, 100) == 0, "diff floors at 0 for big band")
	_ok(TfMeasure.diff_mm(2500, 0) == 8 * 50, "diff_mm(2500,0)==400")


# (c) Cup is non-decreasing as volume rises (band fixed).
func _test_monotonic_in_volume() -> void:
	for std in [TfMeasure.IMPERIAL, TfMeasure.METRIC]:
		var prev := -1
		var ok := true
		for v in range(0, 4000, 50):
			var d := TfMeasure.diff_mm(v, 32)
			if d < prev:
				ok = false
			prev = d
		_ok(ok, "diff_mm non-decreasing in volume under %s" % std["id"])
		# letter index also non-decreasing.
		var pidx := -1
		var ok2 := true
		for v in range(0, 4000, 50):
			var idx := clampi(TfMeasure.diff_mm(v, 32) / int(std["step_mm"]), 0, std["letters"].size() - 1)
			if idx < pidx:
				ok2 = false
			pidx = idx
		_ok(ok2, "cup letter index non-decreasing in volume under %s" % std["id"])


# (c') Cup is non-increasing as band rises (volume fixed) — band-dependence.
func _test_monotonic_in_band() -> void:
	var prev := 1 << 30
	var strictly_drops := false
	var ok := true
	for b in range(20, 60):
		var d := TfMeasure.diff_mm(1200, b)
		if d > prev:
			ok = false
		if d < prev:
			strictly_drops = true
		prev = d
	_ok(ok, "diff_mm non-increasing in band at fixed volume")
	_ok(strictly_drops, "diff_mm actually drops somewhere as band widens (real dependence)")
	# concrete: a wider band lowers the cup letter for (1200, *).
	var narrow := TfMeasure.cup_letter(1200, 28, TfMeasure.METRIC)
	var wide := TfMeasure.cup_letter(1200, 44, TfMeasure.METRIC)
	var li := TfMeasure.METRIC["letters"]
	_ok(li.find(wide) <= li.find(narrow), "wider band -> same-or-smaller cup letter (%s vs %s)" % [wide, narrow])


# (d) volume_ml / band_cm round-trip save/load as INTEGERS.
func _test_size_roundtrip_int() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 0xC0FFEE, reg)
	# grow breasts so the value is non-default, then save/load.
	h.start_tf("grow_breasts")
	h.advance_time(600 * 4)
	var before_v = BodyGraph.find_by_id(h.body["root"], "breast_l")["props"]["volume_ml"]
	_ok(typeof(before_v) == TYPE_INT, "live volume_ml is INT after grow (%s)" % typeof(before_v))
	var saved := JSON.stringify(h.to_dict())
	var h2 := TfHolder.from_dict(JSON.parse_string(saved), reg)
	var seg2 = BodyGraph.find_by_id(h2.body["root"], "breast_l")
	_ok(typeof(seg2["props"]["volume_ml"]) == TYPE_INT, "reloaded volume_ml is INT not float")
	_ok(typeof(seg2["props"]["band_cm"]) == TYPE_INT, "reloaded band_cm is INT not float")
	_ok(seg2["props"]["volume_ml"] == before_v, "volume_ml survives round-trip exactly")
	_ok(JSON.stringify(h.body) == JSON.stringify(h2.body), "whole body round-trips byte-identically")
	# butt segment exists with an integer volume.
	var butt = BodyGraph.find_by_id(h2.body["root"], "butt")
	_ok(butt != null, "starting body has a butt segment")
	_ok(butt != null and typeof(butt["props"]["volume_ml"]) == TYPE_INT, "butt volume_ml is INT")


# (e) Size TFs change the derived cup/size label.
func _test_size_tfs_change_label() -> void:
	var reg := TfContent.registry()
	var std := TfMeasure.METRIC
	# grow_breasts raises the cup.
	var h := TfHolder.new(TfContent.biped(), 0x515E, reg)
	var v0 := int(BodyGraph.find_by_id(h.body["root"], "breast_l")["props"]["volume_ml"])
	var b0 := int(BodyGraph.find_by_id(h.body["root"], "breast_l")["props"]["band_cm"])
	var cup0 := TfMeasure.cup_label(v0, b0, std)
	h.start_tf("grow_breasts")
	h.advance_time(600 * 4)
	var v1 := int(BodyGraph.find_by_id(h.body["root"], "breast_l")["props"]["volume_ml"])
	var cup1 := TfMeasure.cup_label(v1, b0, std)
	_ok(v1 > v0, "grow_breasts raised volume (%d -> %d)" % [v0, v1])
	_ok(cup1 != cup0, "grow_breasts changed the cup label (%s -> %s)" % [cup0, cup1])
	# widen_band lowers the cup difference at fixed volume.
	var h2 := TfHolder.new(TfContent.biped(), 0x515E, reg)
	var diff_a := TfMeasure.diff_mm(v0, b0)
	h2.apply_instant("widen_band")
	var b2 := int(BodyGraph.find_by_id(h2.body["root"], "breast_l")["props"]["band_cm"])
	var diff_b := TfMeasure.diff_mm(v0, b2)
	_ok(b2 > b0, "widen_band raised band_cm (%d -> %d)" % [b0, b2])
	_ok(diff_b < diff_a, "widen_band lowered cup difference at fixed volume (%d -> %d)" % [diff_a, diff_b])
	# grow_butt raises butt volume.
	var h3 := TfHolder.new(TfContent.biped(), 0x515E, reg)
	var bv0 := int(BodyGraph.find_by_id(h3.body["root"], "butt")["props"]["volume_ml"])
	h3.start_tf("grow_butt")
	h3.advance_time(600 * 4)
	var bv1 := int(BodyGraph.find_by_id(h3.body["root"], "butt")["props"]["volume_ml"])
	_ok(bv1 > bv0, "grow_butt raised butt volume (%d -> %d)" % [bv0, bv1])
	# undo restores it.
	h3.undo_last()
	var bv2 := int(BodyGraph.find_by_id(h3.body["root"], "butt")["props"]["volume_ml"])
	_ok(bv2 < bv1, "undo reverted the last butt-grow stage (%d -> %d)" % [bv1, bv2])


# (f) Unit conversions render the right units per standard.
func _test_unit_conversions() -> void:
	# length: 15cm -> 15cm (metric), 6in (imperial, 15/2.54≈5.9 -> 6).
	_ok(TfMeasure.length_in_unit(15.0, TfMeasure.METRIC) == 15, "15cm metric -> 15")
	_ok(TfMeasure.length_in_unit(15.0, TfMeasure.IMPERIAL) == 6, "15cm imperial -> 6in")
	# volume: 650ml -> 650ml (metric), 22floz (imperial, 650/29.57≈21.98 -> 22).
	_ok(TfMeasure.volume_in_unit(650, TfMeasure.METRIC) == 650, "650ml metric -> 650")
	_ok(TfMeasure.volume_in_unit(650, TfMeasure.IMPERIAL) == 22, "650ml imperial -> 22floz")
	# next_standard cycles.
	_ok(TfMeasure.next_standard(TfMeasure.METRIC)["id"] == "imperial", "metric -> imperial")
	_ok(TfMeasure.next_standard(TfMeasure.IMPERIAL)["id"] == "metric", "imperial -> metric")


# (g) describe() threads the standard so the SAME body renders differently.
func _test_describe_uses_standard() -> void:
	var body := TfContent.biped()
	# pin a breast to the worked-example values for a deterministic rendering.
	var bl = BodyGraph.find_by_id(body["root"], "breast_l")
	bl["props"]["volume_ml"] = 1200
	bl["props"]["band_cm"] = 32
	var met := TfDescribe.describe(body, TfMeasure.METRIC)
	var imp := TfDescribe.describe(body, TfMeasure.IMPERIAL)
	_ok(met != imp, "describe renders differently under the two standards")
	# Clean player prose renders the cup as a spoken letter and length in the standard's
	# unit — the SAME body reads "a G cup" / "cm" under metric, "a DD cup" / "in" under
	# imperial. (The raw "32G"/"13DD" labels live only in debug_dump now.)
	_ok("a G cup" in met, "metric describe renders the worked breast as a G cup")
	_ok(" cm" in met, "metric describe renders length in cm")
	_ok("a DD cup" in imp, "imperial describe renders the worked breast as a DD cup")
	_ok(" in" in imp, "imperial describe renders length in inches")
	# default standard is metric (so the default rendering is the metric one).
	var dflt := TfDescribe.describe(body)
	_ok("a G cup" in dflt, "default describe uses the default (metric) standard")
	# The raw debug label still exists on the separate debug surface.
	_ok("32G" in TfDescribe.debug_dump(body, TfMeasure.METRIC), "debug_dump keeps the raw 32G label")
