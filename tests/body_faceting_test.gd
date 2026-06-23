## Gate #8a — the INDEPENDENT dihedral faceting metric
## (docs/decisions/character-creator-and-body.md §4.6 / §8 #8a; SYNTHESIS.md §3.6).
##
## Measures faceting via the per-interior-edge DIHEDRAL deviation angle between adjacent
## triangles on the MORPHED, baked mesh (FacetingMetric) — an OBJECTIVE geometric measure
## of surface angularity that is INDEPENDENT of the cap model ("the metric knows no cap").
##
## THE TWO MODES ARE TREATED DIFFERENTLY, per the design:
##
##   • DEFAULT mode (extremeness 0, conservative caps) — the no-monster-by-default visual
##     FLOOR. The test ASSERTS the morph-induced faceting stays within an acceptable
##     threshold across the default cap range. If this FAILS, the default caps facet and
##     need tightening (a real finding) — the threshold is NOT to be loosened to pass.
##
##   • EXTREME mode (extremeness 1, opt-in) — faceting at extremes is an ACCEPTED LIMIT
##     whose remedy (the subdivision setting) is DEFERRED. So here the metric is
##     MONITORING-ONLY: it is computed and RECORDED/logged, and the test DOES NOT FAIL on
##     it (an explicit, deliberate non-assertion, marked below).
##
## THE THRESHOLD IS GROUNDED IN THE SMOOTH REFERENCE, NOT INVENTED. The neutral base body
## already carries intrinsic anatomical creases (nostril rims, lip seam, fingers, ears) —
## measured at p99.5 ~= 71 deg, max ~= 137 deg — that are a property of the base mesh's
## tessellation, NOT of any morph. The morph-induced faceting we gate on is therefore the
## INCREASE (delta) of these statistics OVER the neutral smooth reference. Measured: a
## default-cap morph moves p99.5 by < 0.3 deg (the all-poles corner is even slightly
## NEGATIVE — morphs smooth the surface), while an extreme-cap morph moves max by ~41 deg.
##
## THE ASSERTED SIGNAL IS THE BAND (p99.5), per the design ("the broad faceting band, not
## the raw max, which a single legitimate anatomical crease would trip"). The single-edge
## max is MONITORED, not asserted, because a stacked face-shape COMBINATION can tip ONE
## pre-creased facial edge past the max ceiling while the band stays flat (the deferred
## combination-plausibility case — gate #1b surfaces this; see its header + the report).
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_faceting_test.tscn --quit-after 8000
## Calls quit(0) iff every (DEFAULT-mode) assertion passed, else quit(1).
extends Node

const FacetingMetric := preload("res://scripts/body/faceting_metric.gd")
const BodyCaps := preload("res://scripts/body/body_caps.gd")
const RegionSliders := preload("res://scripts/body/region_sliders.gd")
const MESH_PATH := "res://assets/body/base_body.res"

## Per-edge angle (deg) above which an edge counts toward `frac_over_thresh` (the broad
## faceting band, not a lone anatomical crease).
const THRESH_DEG := 60.0

## DEFAULT-mode acceptance: the morph-induced INCREASE of the BAND (p99.5) over the
## smooth-reference neutral must stay below this. Grounded from the smooth reference
## (measured default p99.5 delta is ~0.3 deg single-axis, <= 0 at the corner; conservative
## headroom). This is the ASSERTED faceting signal.
const MAX_DEFAULT_DP995_DEG := 5.0
## The single-edge max is MONITORED, not asserted (see header). Used as the extreme
## RESPONDS check's reference and reported for the default single-axis case.
const MONITOR_DMAX_DEG := 15.0

var _pass := 0
var _fail := 0
var _mi: MeshInstance3D
var _mesh: ArrayMesh
var _neutral: Dictionary


func _ready() -> void:
	print("\n=== aeriea GATE #8a — independent dihedral faceting metric (default-floor + extreme-monitor) ===\n")
	var base: ArrayMesh = load(MESH_PATH)
	_mesh = base.duplicate(true) as ArrayMesh
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	add_child(_mi)

	# The SMOOTH REFERENCE — the neutral base body. Its intrinsic creases set the floor we
	# measure morph-induced faceting RELATIVE TO.
	_neutral = _measure(BodyState.new())
	print("  smooth-reference NEUTRAL: max=%.1f p99=%.1f p99.5=%.1f p99.9=%.1f over%d=%.3f%% (edges=%d)" % [
		_neutral["max_deg"], _neutral["p99_deg"], _neutral["p995_deg"], _neutral["p999_deg"],
		int(THRESH_DEG), _neutral["frac_over_thresh"] * 100.0, _neutral["edge_count"]])

	_test_metric_responds_to_faceting()
	_test_default_single_axis_floor()
	_test_default_corner_floor()
	_monitor_extreme()

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s" % msg)
	else:
		_fail += 1
		print("  FAIL  %s" % msg)


## Bake a BodyState onto the shared mesh and return its dihedral stats.
func _measure(bs: BodyState) -> Dictionary:
	bs.apply_morph_cpu(_mi)
	var a := _mesh.surface_get_arrays(0)
	return FacetingMetric.dihedral_stats(a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_INDEX], THRESH_DEG)


# --- the metric is SOUND: it actually rises under genuine faceting (extreme) --------------
func _test_metric_responds_to_faceting() -> void:
	# An extreme combined morph DOES drive the surface past the tessellation it can represent
	# smoothly, so the metric's max-deviation MUST rise meaningfully over neutral. This proves
	# the metric is not a constant — if it never moved, the default-floor assert would be vacuous.
	var caps := BodyCaps.new()
	caps.extremeness = 1.0
	var bs := BodyState.new()
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			var di := caps.cap(fn, 1.0)
			bs.modifiers[fn] = di[1] if absf(di[1]) >= absf(di[0]) else di[0]
	var s := _measure(bs)
	var dmax: float = s["max_deg"] - _neutral["max_deg"]
	var dp995: float = s["p995_deg"] - _neutral["p995_deg"]
	# The metric MUST move at extreme — proving it is a live, cap-independent signal (else the
	# default-floor asserts would be vacuous). The max-deviation is the unambiguous responder
	# (the band also rises with the full headline+modifier extreme corner; reported alongside).
	_ok(dmax > MONITOR_DMAX_DEG,
		"metric RESPONDS: extreme-cap morph raises max dihedral by %.1f deg (> %.0f, the default monitor reference), so it is a live, cap-independent signal (band p99.5 rise %+.1f deg)" % [dmax, MONITOR_DMAX_DEG, dp995])


# --- DEFAULT FLOOR: every curated control at its default pole, individually ---------------
func _test_default_single_axis_floor() -> void:
	# DEFAULT mode (extremeness 0): drive each curated control alone to its default-cap pole.
	# Each must keep morph-induced faceting within the floor. The WORST is reported.
	var caps := BodyCaps.new()   # extremeness 0
	var worst_dp995 := -INF
	var worst_dmax := -INF
	var worst_name := ""
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			var di := caps.cap(fn, 0.0)
			var pole: float = di[1] if absf(di[1]) >= absf(di[0]) else di[0]
			var bs := BodyState.new()
			bs.modifiers[fn] = pole
			var s := _measure(bs)
			var dp995: float = s["p995_deg"] - _neutral["p995_deg"]
			var dmax: float = s["max_deg"] - _neutral["max_deg"]
			if dp995 > worst_dp995:
				worst_dp995 = dp995
				worst_name = "%s@%.2f" % [fn, pole]
			worst_dmax = maxf(worst_dmax, dmax)
	# ASSERT the band; report the single-edge max as monitoring.
	_ok(worst_dp995 <= MAX_DEFAULT_DP995_DEG,
		"DEFAULT single-axis floor (band): worst p99.5 rise %.3f deg <= %.1f (%s)" % [worst_dp995, MAX_DEFAULT_DP995_DEG, worst_name])
	print("  [MONITOR-ONLY] DEFAULT single-axis worst single-edge max rise = %+.3f deg (reference %.0f)" % [worst_dmax, MONITOR_DMAX_DEG])


# --- DEFAULT FLOOR: all curated controls at their default poles TOGETHER (the corner) -----
func _test_default_corner_floor() -> void:
	# The default-cap CORNER (every curated control at its default pole simultaneously) is the
	# most-deformed reachable DEFAULT body. It too must stay within the faceting floor.
	var caps := BodyCaps.new()   # extremeness 0
	var bs := BodyState.new()
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			var di := caps.cap(fn, 0.0)
			bs.modifiers[fn] = di[1] if absf(di[1]) >= absf(di[0]) else di[0]
	# Headline axes at their default-band poles too.
	var mc := caps.cap("masculinity", 0.0); bs.masculinity = mc[1]
	var muc := caps.cap("muscle", 0.0); bs.muscle = muc[1]
	var wc := caps.cap("weight", 0.0); bs.weight = wc[1]
	var s := _measure(bs)
	var dp995: float = s["p995_deg"] - _neutral["p995_deg"]
	var dmax: float = s["max_deg"] - _neutral["max_deg"]
	print("  DEFAULT corner: max=%.1f p99.5=%.1f over%d=%.3f%% (dp99.5=%+.3f dmax=%+.3f)" % [
		s["max_deg"], s["p995_deg"], int(THRESH_DEG), s["frac_over_thresh"] * 100.0, dp995, dmax])
	_ok(dp995 <= MAX_DEFAULT_DP995_DEG,
		"DEFAULT corner floor (band): p99.5 rise %+.3f deg <= %.1f" % [dp995, MAX_DEFAULT_DP995_DEG])
	print("  [MONITOR-ONLY] DEFAULT corner single-edge max rise = %+.3f deg (reference %.0f)" % [dmax, MONITOR_DMAX_DEG])


# --- EXTREME MONITORING (NO ASSERT) -------------------------------------------------------
func _monitor_extreme() -> void:
	# EXTREME mode (extremeness 1, opt-in): faceting here is an ACCEPTED LIMIT; the remedy
	# (the subdivision setting) is DEFERRED. So this is MONITORING-ONLY: compute + LOG the
	# metric; DO NOT call _ok(), DO NOT fail. This is the explicit default-vs-extreme split
	# the spec requires (gate #8b is the user-reviewed render, not an automated fail).
	var caps := BodyCaps.new()
	caps.extremeness = 1.0
	var bs := BodyState.new()
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			var di := caps.cap(fn, 1.0)
			bs.modifiers[fn] = di[1] if absf(di[1]) >= absf(di[0]) else di[0]
	var mc := caps.cap("masculinity", 1.0); bs.masculinity = mc[1]
	var muc := caps.cap("muscle", 1.0); bs.muscle = muc[1]
	var wc := caps.cap("weight", 1.0); bs.weight = wc[1]
	var s := _measure(bs)
	print("  [MONITOR-ONLY, NOT ASSERTED] EXTREME hard-pole corner: max=%.1f p99=%.1f p99.5=%.1f p99.9=%.1f over%d=%.3f%% (dp99.5=%+.3f dmax=%+.3f vs smooth reference) — faceting at extremes is the accepted limit; subdivision is the deferred remedy" % [
		s["max_deg"], s["p99_deg"], s["p995_deg"], s["p999_deg"], int(THRESH_DEG),
		s["frac_over_thresh"] * 100.0, s["p995_deg"] - _neutral["p995_deg"], s["max_deg"] - _neutral["max_deg"]])
