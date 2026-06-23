## Gate #1b — the NO-MONSTER-BY-DEFAULT sweep
## (docs/decisions/character-creator-and-body.md §8 #1b; SYNTHESIS.md §8).
##
## A property test that samples many random WITHIN-DEFAULT-CAP bodies (extremeness 0) and
## asserts the no-monster-by-default invariants on each sampled body:
##
##   (1) CAP RESPECT — every sampled value lies within its control's default interval
##       cap(control, 0). (The sampler draws within the interval through the SAME BodyCaps
##       choke the live creator uses, so this is a real end-to-end check, not a tautology:
##       the choke must not admit a value past the default cap at extremeness 0.)
##   (2) FACETING FLOOR (#8a) — the dihedral faceting metric stays within the default-mode
##       threshold. THE GATED SIGNAL IS THE BAND (p99.5), the design's stated faceting
##       measure ("the broad faceting band, not the raw max"). The morph-induced rise of
##       p99.5 over the smooth-reference neutral is bounded.
##
## THE RAW SINGLE-EDGE MAX IS MONITORING-ONLY (recorded, NOT asserted) — and a FINDING.
## The sweep surfaces that stacked FACE-SHAPE combinations (head-scale + head-oval +
## head-square + head-rectangular together) can tip a SINGLE pre-existing facial-detail
## edge (already ~137 deg at NEUTRAL, in the y~=1.6 face region) up to ~176 deg, while the
## broad band (p99.5) stays within the floor everywhere. This is the DEFERRED
## combination-plausibility case (decision §4.4 — per-control caps do NOT bound grotesque
## COMBINATIONS), surfacing on a single anatomical crease, NOT broad default-cap faceting.
## Hard-asserting the raw max would gate on exactly the single-legitimate-crease case gate
## #8a says to avoid; whether to additionally tighten the face-shape caps to suppress the
## combination spike is a USER-TASTE-GATED tuning call (see the report), so the max is
## recorded and flagged, not failed.
##
## SELF-INTERSECTION is DEFERRED monitoring per the design — it is NOT hard-asserted here.
## We log the worst single-edge max region so a regression in gross deformation is visible.
##
## TEST-COST SPLIT (per the design's REGULAR vs NIGHTLY split):
##   • REGULAR (per-PR) suite: a SEEDED SMOKE-N (deterministic). It is NOT pure uniform
##     random — it INCLUDES the known extreme-within-default COMBOS (the corners: every
##     control at +pole, every control at -pole, the headline poles, and per-group pole
##     stacks) so the monster-producing regions are deliberately covered, THEN fills the
##     remainder with seeded uniform-random within-default samples.
##   • FULL (nightly / opt-in): set AERIEA_FACETING_FULL_N=1 (or =<N>) to run the full
##     N=10,000 seeded sweep instead, without bloating the per-PR suite.
##   Both log exactly what they covered (corners + random count) — no silent truncation.
##
## Run windowed under xvfb (regular smoke-N):
##   xvfb-run -a godot4 --path . res://tests/body_no_monster_test.tscn --quit-after 20000
## Full nightly:
##   AERIEA_FACETING_FULL_N=1 xvfb-run -a godot4 --path . res://tests/body_no_monster_test.tscn --quit-after 120000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const FacetingMetric := preload("res://scripts/body/faceting_metric.gd")
const BodyCaps := preload("res://scripts/body/body_caps.gd")
const RegionSliders := preload("res://scripts/body/region_sliders.gd")
const MESH_PATH := "res://assets/body/base_body.res"

const THRESH_DEG := 60.0
## DEFAULT-mode faceting acceptance (identical grounding to gate #8a): the morph-induced
## rise of the faceting BAND (p99.5) over the smooth-reference neutral must stay below this.
## Measured worst over the full N=10000 default sweep is ~+3.4 deg; this ceiling is headroom.
const MAX_DEFAULT_DP995_DEG := 5.0
## The single-edge max is MONITORING-ONLY (not asserted). This is the recorded reference
## ceiling the report flags against (the stacked-face-shape combination spikes past it).
const MONITOR_DMAX_DEG := 15.0

## Regular per-PR smoke-N (deterministic). The corners are added ON TOP of this random fill.
const SMOKE_N := 300
## The deterministic seed for the regular run (replay-stable).
const SWEEP_SEED := 0xA371EA

var _pass := 0
var _fail := 0
var _mi: MeshInstance3D
var _mesh: ArrayMesh
var _neutral: Dictionary
var _caps: BodyCaps
## The curated control set the sweep samples (headline axes + every region-slider modifier).
var _controls: Array = []


func _ready() -> void:
	print("\n=== aeriea GATE #1b — no-monster-by-default sweep (cap-respect + faceting floor) ===\n")
	var base: ArrayMesh = load(MESH_PATH)
	_mesh = base.duplicate(true) as ArrayMesh
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	add_child(_mi)

	_caps = BodyCaps.new()   # extremeness 0 (DEFAULT mode)
	_build_control_set()

	_neutral = _measure(BodyState.new())
	print("  smooth-reference NEUTRAL: max=%.1f p99.5=%.1f (edges=%d); controls sampled=%d" % [
		_neutral["max_deg"], _neutral["p995_deg"], _neutral["edge_count"], _controls.size()])

	# Decide regular smoke-N vs full nightly N from the env flag.
	var full_env := OS.get_environment("AERIEA_FACETING_FULL_N")
	var full_n := 0
	if full_env != "":
		full_n = full_env.to_int()
		if full_n <= 1:
			full_n = 10000   # =1 means "the full sweep"; a number overrides N
	var random_n := full_n if full_n > 0 else SMOKE_N
	var mode := ("FULL (nightly, N=%d)" % random_n) if full_n > 0 else ("SMOKE (per-PR, N=%d)" % random_n)

	# 1) The CORNERS — known extreme-within-default combos (always run, both modes).
	var corners := _build_corners()
	print("  COVERAGE: %s + %d deterministic corners (extreme-within-default combos)" % [mode, corners.size()])
	var worst := {"dp995": -INF, "dp995_label": "", "dmax": -INF, "dmax_label": "", "dmax_y": 0.0}
	for c in corners:
		_check_body(c["state"], c["label"], worst)

	# 2) The seeded random within-default fill.
	var rng := RandomNumberGenerator.new()
	rng.seed = SWEEP_SEED
	for i in random_n:
		var bs := _random_within_default(rng)
		_check_body(bs, "random#%d" % i, worst)

	# The ASSERTED signal — the broad faceting band — over the whole sweep.
	print("  WORST BAND (asserted, p99.5 rise): %+.3f deg (%s)  [ceiling %.1f]" % [
		worst["dp995"], worst["dp995_label"], MAX_DEFAULT_DP995_DEG])
	# The MONITORED single-edge max (NOT asserted) — the combination-spike finding.
	var region := "FACE/HEAD" if worst["dmax_y"] > 1.45 else ("torso" if worst["dmax_y"] > 0.8 else "lower-body")
	print("  WORST SINGLE-EDGE MAX (monitor-only, NOT asserted): %+.3f deg over neutral (%s) — worst edge in the %s region (y=%.3f). %s" % [
		worst["dmax"], worst["dmax_label"], region, worst["dmax_y"],
		("FLAG: exceeds the %.0f-deg monitor reference — a stacked face-shape COMBINATION spike on a single pre-creased facial edge (deferred combination-plausibility, decision §4.4); the band stays within floor." % MONITOR_DMAX_DEG) if worst["dmax"] > MONITOR_DMAX_DEG else "within the monitor reference."])

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL  %s" % msg)


# --- the control set: headline axes + every region-slider modifier (resolved) -------------
func _build_control_set() -> void:
	for field in ["masculinity", "muscle", "weight"]:
		_controls.append({"kind": "headline", "name": field})
	# proportions/height/age affect global shape but are bounded scale/age axes; the
	# region-slider modifiers are the deformation-prone set the faceting floor cares about.
	var seen := {}
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			if seen.has(fn):
				continue
			seen[fn] = true
			_controls.append({"kind": "modifier", "name": fn})


# --- corner construction: deliberate monster-region coverage ------------------------------
func _build_corners() -> Array:
	var out := []
	# Every modifier at its default +pole (b) together; and the -pole (a) together.
	var hi := BodyState.new()
	var lo := BodyState.new()
	for ctl in _controls:
		var di := _caps.cap(ctl["name"], 0.0)
		if ctl["kind"] == "headline":
			hi.set(ctl["name"], di[1]); lo.set(ctl["name"], di[0])
		else:
			hi.modifiers[ctl["name"]] = di[1]; lo.modifiers[ctl["name"]] = di[0]
	out.append({"state": hi, "label": "all-+pole corner"})
	out.append({"state": lo, "label": "all--pole corner"})

	# Per-group pole stacks (the belly/waist/torso stacks the spec calls out as the
	# combination case): each region GROUP's modifiers driven to their larger-magnitude pole.
	for grp in RegionSliders.GROUPS:
		var bs := BodyState.new()
		for spec in grp[1]:
			for fn in RegionSliders.resolve_full_names(spec[0]):
				var di := _caps.cap(fn, 0.0)
				bs.modifiers[fn] = di[1] if absf(di[1]) >= absf(di[0]) else di[0]
		out.append({"state": bs, "label": "group-pole:%s" % grp[0]})
	return out


# --- one seeded random within-default body ------------------------------------------------
func _random_within_default(rng: RandomNumberGenerator) -> BodyState:
	var bs := BodyState.new()
	for ctl in _controls:
		var di := _caps.cap(ctl["name"], 0.0)
		var a := float(di[0])
		var b := float(di[1])
		var req := rng.randf_range(a, b)
		# Route through the SAME choke the live creator uses (cur = neutral, no gesture):
		# at extremeness 0 the choke must keep a within-interval request unchanged and must
		# clamp any out-of-interval request to the default cap.
		var cur := _caps.neutral_of(ctl["name"])
		var stored := _caps.apply_capped(ctl["name"], req, cur)
		if ctl["kind"] == "headline":
			bs.set(ctl["name"], stored)
		else:
			bs.modifiers[ctl["name"]] = stored
	return bs


# --- per-body invariant checks ------------------------------------------------------------
func _check_body(bs: BodyState, label: String, worst: Dictionary) -> void:
	# (1) CAP RESPECT — every value within its control's default interval cap(control, 0).
	for ctl in _controls:
		var di := _caps.cap(ctl["name"], 0.0)
		var v: float
		if ctl["kind"] == "headline":
			v = float(bs.get(ctl["name"]))
		else:
			v = float(bs.modifiers.get(ctl["name"], _caps.neutral_of(ctl["name"])))
		_ok(v >= float(di[0]) - 1e-5 and v <= float(di[1]) + 1e-5,
			"%s: %s=%f outside default [%f,%f]" % [label, ctl["name"], v, di[0], di[1]])

	# (2) FACETING FLOOR (#8a) — morph-induced dihedral rise over the smooth reference bounded.
	# ASSERT the BAND (p99.5, the design's stated faceting signal); MONITOR the single-edge max.
	var s := _measure(bs)
	var dp995: float = s["p995_deg"] - _neutral["p995_deg"]
	var dmax: float = s["max_deg"] - _neutral["max_deg"]
	if dp995 > worst["dp995"]:
		worst["dp995"] = dp995
		worst["dp995_label"] = label
	if dmax > worst["dmax"]:
		worst["dmax"] = dmax
		worst["dmax_label"] = label
		worst["dmax_y"] = float(s["max_edge_y"])
	_ok(dp995 <= MAX_DEFAULT_DP995_DEG,
		"%s: p99.5 faceting BAND rise %+.3f deg > %.1f (DEFAULT caps facet broadly — TIGHTEN caps, do not loosen threshold)" % [label, dp995, MAX_DEFAULT_DP995_DEG])

	# SELF-INTERSECTION + the single-edge max spike are DEFERRED monitoring only — NOT
	# asserted (the max is recorded into `worst` and reported at the end as the finding).


func _measure(bs: BodyState) -> Dictionary:
	bs.apply_morph_cpu(_mi)
	var a := _mesh.surface_get_arrays(0)
	return FacetingMetric.dihedral_stats(a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_INDEX], THRESH_DEG)
