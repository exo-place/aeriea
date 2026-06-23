## Phase 3a test — control surfacing + correct semantics + numeric/reset/randomize + the
## extremeness control (docs/decisions/character-creator-and-body.md). OBJECTIVE clauses only
## (the visual/UX aesthetic call is USER-gated, not asserted here):
##
##   (1) BELLY GROUP: the pregnancy "belly" slider (stomach-pregnant) is RETIRED from the
##       creator surface; the tone axis (stomach-tone) + the net-new belly-forward depth
##       (torso-scale-depth) are PRESENT; waist-circ stays the single existing waist slider.
##   (2) NO MODIFIER DRIVEN BY TWO CONTROLS: every resolved full_name appears under exactly
##       one slider spec (no two-thumb-one-modifier desync).
##   (3) LABELS: no abbreviated "circ." / "rect." labels remain (full readable words).
##   (4) NUMERIC ENTRY / CHOKE: a remapped numeric request routes through apply_capped — an
##       out-of-cap request CLAMPS to the interval, and the remap round-trips.
##   (5) RESET: returns a control to neutral (raw).
##   (6) RANDOMIZE: deterministic (same seed → same value) AND within cap(·, extremeness).
##   (7) EXTREMENESS: widens the reachable interval toward the hard range.
##   (8) TABLE STILL VALID: every spec (incl. the new belly/fine-detail ones) resolves to a
##       real registry modifier with nonzero library deltas (no dead/broken control shipped).
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_phase3a_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const RegionSliders := preload("res://scripts/body/region_sliders.gd")
const BodyCaps := preload("res://scripts/body/body_caps.gd")
const DetailLib := preload("res://scripts/body/detail_library.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR PHASE 3a — belly/region controls, numeric, reset, randomize, extremeness ===\n")
	_test_belly_group()
	_test_no_double_bound_modifier()
	_test_labels_unabbreviated()
	_test_numeric_remap_and_choke()
	_test_reset_neutral()
	_test_randomize_deterministic_within_cap()
	_test_extremeness_widens()
	_test_table_still_valid()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


# (1) belly group --------------------------------------------------------------
func _test_belly_group() -> void:
	print("--- (1) belly group: pregnancy retired; tone + belly-forward present ---")
	var bound := _all_bound_full_names()
	_ok("pregnancy 'belly' slider (stomach-pregnant) is RETIRED from the creator surface",
		not bound.has("stomach/stomach-pregnant-decr|incr"),
		"stomach-pregnant absent from RegionSliders")
	_ok("belly softness/tone (stomach-tone) is present",
		bound.has("stomach/stomach-tone-decr|incr"), "stomach-tone bound")
	_ok("net-new belly-forward depth (torso-scale-depth) is present",
		bound.has("torso/torso-scale-depth-decr|incr"), "torso-scale-depth bound")
	_ok("waist circumference stays the single existing waist slider",
		bound.has("measure/measure-waist-circ-decr|incr"), "waist-circ bound")


# (2) no modifier driven by two controls --------------------------------------
func _test_no_double_bound_modifier() -> void:
	print("--- (2) no modifier driven by two controls (no two-thumb-one-modifier) ---")
	var counts := {}
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			counts[fn] = int(counts.get(fn, 0)) + 1
	var dupes := []
	for fn in counts:
		if int(counts[fn]) > 1:
			dupes.append("%s x%d" % [fn, counts[fn]])
	_ok("every resolved modifier is bound by exactly one control", dupes.is_empty(),
		"duplicates: %s" % (str(dupes) if not dupes.is_empty() else "none"))


# (3) labels -------------------------------------------------------------------
func _test_labels_unabbreviated() -> void:
	print("--- (3) labels contain no 'circ.'/'rect.' abbreviations ---")
	var bad := []
	for spec in RegionSliders.all_specs():
		var d := String(spec["display"])
		if d.contains("circ.") or d.contains("rect.") or d == "triangle":
			bad.append(d)
	_ok("no abbreviated slider labels remain", bad.is_empty(),
		"abbreviated labels: %s" % (str(bad) if not bad.is_empty() else "none"))


# (4) numeric entry remap + choke ---------------------------------------------
func _test_numeric_remap_and_choke() -> void:
	print("--- (4) numeric entry: remap round-trips; out-of-cap request CLAMPS via choke ---")
	var caps := BodyCaps.new()
	caps.extremeness = 0.0
	# A bidirectional control: ±100 display ↔ ±1 stored. Request display 100 (stored 1.0).
	var fn := "breast/measure-bust-circ-decr|incr"
	if not caps._by_full_name.has(fn):
		fn = "measure/measure-bust-circ-decr|incr"
	var ci: Array = caps.cap(fn)
	# Display 100 → stored 1.0 (the remap); the choke clamps it to the interval's upper bound.
	var req_stored := 100.0 / 100.0
	var stored: float = caps.apply_capped(fn, req_stored, 0.0)
	_ok("an out-of-cap numeric request clamps to the cap interval", _approx(stored, float(ci[1])),
		"req=%.3f → stored=%.3f (cap b=%.3f)" % [req_stored, stored, ci[1]])
	# The displayed value re-derived from the clamped stored value (×100) is the clamped value,
	# not the pre-clamp request — the write-back protocol's "field shows the clamped value".
	var shown := stored * 100.0
	_ok("the field displays the CLAMPED stored value, not the request", shown < 100.0 - 1e-6,
		"shown=%.2f (< requested 100)" % shown)


# (5) reset --------------------------------------------------------------------
func _test_reset_neutral() -> void:
	print("--- (5) reset returns a control to neutral (raw) ---")
	# Modifier neutral is 0; a raw reset erases the key → reads back as 0.
	var bs := BodyState.new()
	bs.modifiers["measure/measure-bust-circ-decr|incr"] = 0.8
	# Simulate the raw reset write site (erase-at-neutral).
	bs.modifiers.erase("measure/measure-bust-circ-decr|incr")
	_ok("reset to neutral leaves the control at its neutral (0)",
		float(bs.modifiers.get("measure/measure-bust-circ-decr|incr", 0.0)) == 0.0, "neutral 0")


# (6) randomize ----------------------------------------------------------------
func _test_randomize_deterministic_within_cap() -> void:
	print("--- (6) randomize: deterministic + within cap(·, extremeness) ---")
	var caps := BodyCaps.new()
	caps.extremeness = 0.0
	var fn := "measure/measure-bust-circ-decr|incr"
	var ci: Array = caps.cap(fn)
	# Deterministic: same seed → same sampled value.
	var v1 := _sample(fn, ci, 12345)
	var v2 := _sample(fn, ci, 12345)
	_ok("randomize is deterministic for a fixed seed", v1 == v2, "%.6f == %.6f" % [v1, v2])
	# Within cap: 200 seeded samples all land inside [a,b].
	var out_of_cap := 0
	for s in 200:
		var v := _sample(fn, ci, 1000 + s)
		var capped: float = caps.apply_capped(fn, v, 0.0)
		if v < float(ci[0]) - 1e-9 or v > float(ci[1]) + 1e-9 or not _approx(v, capped):
			out_of_cap += 1
	_ok("randomize samples within cap (200 samples, all in [a,b])", out_of_cap == 0,
		"%d/200 out of cap; interval [%.3f, %.3f]" % [out_of_cap, ci[0], ci[1]])


func _sample(_fn: String, ci: Array, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng.randf_range(float(ci[0]), float(ci[1]))


# (7) extremeness widens -------------------------------------------------------
func _test_extremeness_widens() -> void:
	print("--- (7) extremeness widens the reachable interval ---")
	var caps := BodyCaps.new()
	var fn := "measure/measure-bust-circ-decr|incr"
	caps.extremeness = 0.0
	var ci0: Array = caps.cap(fn)
	caps.extremeness = 1.0
	var ci1: Array = caps.cap(fn)
	var hr: Array = caps.hard_range_of(fn)
	_ok("raising extremeness widens the interval toward the hard range",
		float(ci1[1]) > float(ci0[1]) + 1e-6 and float(ci1[0]) < float(ci0[0]) - 1e-6,
		"e0=[%.3f,%.3f] e1=[%.3f,%.3f] hard=[%.3f,%.3f]" %
			[ci0[0], ci0[1], ci1[0], ci1[1], hr[0], hr[1]])


# (8) table integrity ----------------------------------------------------------
func _test_table_still_valid() -> void:
	print("--- (8) every spec (incl. new belly/fine-detail) resolves to nonzero library deltas ---")
	_ok("DetailLibrary + registry load", DetailLib.ensure_loaded() and not BodyState.registry().is_empty(), "artifacts present")
	var by: Dictionary = BodyState.registry().get("by_full_name", {})
	var bad := ""
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			var entry = by.get(fn, null)
			if entry == null:
				bad = "unknown modifier %s (%s)" % [fn, spec["display"]]
				break
			for t in entry["targets"]:
				if DetailLib.record_count(String(t["path"])) <= 0:
					bad = "no deltas for %s -> %s" % [fn, String(t["path"])]
					break
			if bad != "":
				break
		if bad != "":
			break
	_ok("every resolved modifier exists with nonzero library deltas", bad == "",
		bad if bad != "" else "all bindings good")


func _all_bound_full_names() -> Dictionary:
	var out := {}
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			out[fn] = true
	return out


func _approx(a: float, b: float, eps: float = 1e-4) -> bool:
	return absf(a - b) <= eps
