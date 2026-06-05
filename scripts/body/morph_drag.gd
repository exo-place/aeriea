## MorphDrag — the SCENE-FREE geometry core of the drag-to-modify character creator
## (Slice D of docs/decisions/body-parameterization.md). Asian-MMO-style DIRECT
## MANIPULATION: grab the surface and pull; the verbs that move the surface that way
## engage. This is a pure RefCounted module so the pick + drag-decomposition math
## unit-tests HEADLESSLY — input/UI glue (raycast, glow shader, mouse events) lives in
## the creator script AROUND this core, never inside it.
##
## TWO RESPONSIBILITIES, both pure deterministic geometry:
##
##   1. ACCELERATION STRUCTURE (build_accel): a per-render-vertex -> significant-modifier
##      index. Built ONCE from the sparse DetailLibrary (which is render-vertex-keyed) +
##      the modifier registry. For each DETAIL modifier (bidirectional / unipolar — the
##      headline macro axes are NOT drag-editable here, they own their own sliders) we
##      scan its target file(s)' stored deltas; every render vertex the modifier moves
##      with magnitude >= SIGNIFICANT_DELTA_M is recorded as a CANDIDATE of that vertex,
##      together with the modifier's local surface-motion direction AT that vertex (the
##      +value motion: for bidirectional, the max/pos-pole delta). Deterministic: targets
##      iterated in sorted order, candidates sorted by fullName, so the same library +
##      registry always builds the same structure (cached/built once at load).
##
##   2. DRAG DECOMPOSITION (decompose_drag): given a hit render-vertex, a screen-space
##      drag vector, the camera basis, and the hit's world position + render-vertex
##      positions, project each candidate modifier's world surface-motion into SCREEN
##      PIXELS (zoom-adaptive: scaled by the world-metres-per-pixel at the hit depth, so a
##      pixel of drag maps to consistent on-screen surface motion at any zoom), then
##      distribute the drag across candidates by PROJECTION × a continuous LOCALITY weight
##      (how concentrated each modifier's deformation is around the hit) — so the most-LOCAL
##      axis dominates and broad/gross axes fall out at ~0 with no magic threshold. The
##      along-drag component, locality-shared and clamped to range, is the value-delta.
##      Dragging along a modifier's screen motion INCREASES it; opposite DECREASES; orthogonal
##      ~= 0.
##
## The body never enters this module: it takes plain arrays / Vector3s / a camera Basis,
## returns value-deltas keyed by modifier fullName. The creator applies those to the
## BodyState.modifiers map, re-bakes, and commits ONE undo node per completed drag.
class_name MorphDrag
extends RefCounted

const ModifierRegistry := preload("res://scripts/body/modifier_registry.gd")

## A render-vertex delta below this (metres, at full +1 modifier value) does not count as
## a "significant" move at that vertex — it keeps the candidate set crisp (a modifier that
## barely grazes a vertex is not what you grab when you pull there). ~0.2 mm.
const SIGNIFICANT_DELTA_M := 0.0002

## Hover-glow falloff radius (metres) around the hit point. A render vertex within this of
## the hit gets a glow weight smoothly falling 1 -> 0 (smoothstep). Soft, not a hard mask.
const GLOW_RADIUS_M := 0.045

## Default drag sensitivity: PIXELS of screen drag (projected onto a modifier's screen-motion
## direction) that map to one full unit of modifier value. Tuned so a comfortable drag sweeps
## a modifier across a useful fraction of its range. The creator may override per call.
const DEFAULT_PX_PER_UNIT := 220.0

## LOCALITY metric — the PRINCIPLED replacement for the old 20%-footprint hard cut.
##
## When you grab the surface and pull, the verb you reach for is the one whose deformation is
## CONCENTRATED right where you grabbed — a nose-tip axis, not a whole-torso translate. We
## measure that concentration directly, per candidate, at the hit point, with NO magic
## threshold:
##
##   locality(modifier, hit) = Σ_v ( |Δ_v| · gauss(dist(v, hit)) )  /  Σ_v |Δ_v|
##
## i.e. the FRACTION of the modifier's total +value displacement (over its whole footprint)
## that lands NEAR the hit point, weighted by a Gaussian falloff of footprint-vertex distance
## from the hit. (`Δ_v` = the modifier's per-+1 delta at footprint vertex v; `dist` in metres.)
##   - A tightly-local axis (nose-tip: all its displacement sits within a couple cm of the hit)
##     -> nearly all its displacement is "near" -> locality ≈ 1.
##   - A broad / gross axis (whole-torso translate: displacement spread across the whole body,
##     only a sliver near any one hit point) -> locality ≈ 0.
## It is in [0,1], scale-free (normalized by the modifier's own total), needs no per-modifier
## tuning, and is a CONTINUOUS measure — gross axes fall out by scoring ~0, with no 20% cliff.
##
## REFERENCE_WORLD_PER_PX is the world-metres-per-screen-pixel at which DEFAULT_PX_PER_UNIT is
## CALIBRATED — the zoom/depth where a drag feels "right" out of the box (~0.5 mm/px, a face
## filling a ~1080-px viewport at a typical inspection distance). The drag sensitivity scales
## LINEARLY with the actual world-per-px at the hit depth (factor = world_per_px / REFERENCE):
## zoomed IN (fewer mm/px) the surface moves more pixels per unit, so the same pixel of drag
## moves the VALUE less; zoomed OUT (more mm/px) it moves the value more. The net effect is that
## a pixel of drag maps to a CONSISTENT amount of on-screen surface motion at any zoom/distance.
const REFERENCE_WORLD_PER_PX := 0.0005

## LOCALITY_SIGMA_M is the Gaussian's std-dev (metres): the radius over which "near the hit"
## decays. ~3 cm — a touch wider than the glow radius, so the weight tracks the visibly-glowing
## feature. The decomposition multiplies each candidate's drag contribution by its locality so
## the most-local axis (or axes) DOMINATES the pull instead of all overlapping axes engaging
## equally; LOCALITY_POWER sharpens that dominance (the weight is raised to this power before
## use, so a clearly-more-local axis pulls away from its broader neighbours).
const LOCALITY_SIGMA_M := 0.03
const LOCALITY_POWER := 2.0

## A candidate whose locality weight (after the power sharpening, relative to the strongest
## local candidate at the hit) falls below this is treated as ~0 share — the continuous,
## principled successor to the old gross-axis cut: a whole-body axis scores so far below the
## local detail axes that it contributes nothing to the pull, yet stays available to sliders.
const LOCALITY_FLOOR := 0.02

# ---------------------------------------------------------------------------
# State: the built acceleration structure. Built once; pure function of (library, registry).
# ---------------------------------------------------------------------------

## render-vertex index -> Array of candidate Dictionaries:
##   { full_name:String, kind:String, range:[lo,hi], dir:Vector3 (world +value motion,
##     UNNORMALIZED — the actual per-+1 delta at this vertex, in metres) }
## Candidates are sorted by full_name for determinism.
var _vert_candidates: Dictionary = {}

## full_name -> registry entry (kind, range, targets), for the modifiers we made editable.
var _editable: Dictionary = {}

## full_name -> Dictionary{render_vertex -> delta_magnitude_m}: the moved-vertex footprint of
## each editable modifier (its +value target's significant records). Drives the glow's
## "this edit touches this region" component without re-scanning the library.
var _modifier_footprint: Dictionary = {}

var _built := false


## Build the acceleration structure from a parsed registry + a delta-library accessor.
## `registry` is the parse()-shaped Dictionary ({modifiers, by_full_name, ...}). `lib` is
## any object exposing `has_target(path)->bool`, `record_count(path)->int`, and
## `record_at(path,i)->[render_index, Vector3 delta]` (DetailLibrary satisfies this; tests
## may pass a stub). PURE & DETERMINISTIC: targets scanned in sorted order; candidate lists
## sorted by full_name. Idempotent — a second call rebuilds from scratch.
##
## EVERY non-macro modifier whose +value target is in the library becomes a per-vertex
## candidate at each vertex it moves significantly — INCLUDING gross placement axes (whole-
## torso/head translate & scale, measurements). There is no footprint-size cut here anymore:
## the continuous LOCALITY metric (see decompose_drag) is what keeps gross axes from swamping
## the pull — they score ~0 locality at any local hit and fall out naturally, so the formerly-
## magic 20% threshold is gone. `render_vertex_count` is accepted for API compatibility (the
## creator passes the library count) but no longer gates candidacy.
func build_accel(registry: Dictionary, lib, render_vertex_count: int = 0) -> void:
	var _unused := render_vertex_count   # retained for call-site compatibility; no longer used
	_vert_candidates = {}
	_editable = {}
	_modifier_footprint = {}
	var entries: Array = registry.get("modifiers", [])
	# Sort modifiers by full_name so the build order is deterministic regardless of the
	# registry's array order.
	var sorted_entries := entries.duplicate()
	sorted_entries.sort_custom(func(a, b): return String(a["full_name"]) < String(b["full_name"]))

	# For each non-macro modifier whose +value target is in the library, gather its significant
	# per-vertex deltas (its FOOTPRINT) and emit a candidate record at each moved vertex.
	for e in sorted_entries:
		var kind := String(e["kind"])
		if kind == ModifierRegistry.KIND_MACRO:
			continue  # headline axes own their sliders; not drag-editable
		var full_name := String(e["full_name"])
		# The +value surface-motion target: for bidirectional the MAX/pos pole; unipolar the
		# single target. Dragging "with" the modifier raises its value toward that pole's shape.
		var pos_path := _pos_target_path(e)
		if pos_path == "" or not lib.has_target(pos_path):
			continue  # target not in the library (e.g. not imported) -> not editable
		_editable[full_name] = e
		var rng: Array = e["range"]
		var footprint := {}
		var recs := []
		var n: int = lib.record_count(pos_path)
		for i in n:
			var rec: Array = lib.record_at(pos_path, i)
			if rec.is_empty():
				continue
			var ri := int(rec[0])
			var d: Vector3 = rec[1]
			var mag := d.length()
			if mag < SIGNIFICANT_DELTA_M:
				continue
			recs.append({"ri": ri, "dir": d})
			footprint[ri] = mag
		_modifier_footprint[full_name] = footprint
		var rangef := [float(rng[0]), float(rng[1])]
		for r in recs:
			var ri := int(r["ri"])
			var cand := {
				"full_name": full_name,
				"kind": kind,
				"range": rangef,
				"dir": r["dir"],
			}
			if not _vert_candidates.has(ri):
				_vert_candidates[ri] = []
			(_vert_candidates[ri] as Array).append(cand)
	# Deterministic candidate order per vertex.
	for ri in _vert_candidates:
		(_vert_candidates[ri] as Array).sort_custom(func(a, b): return String(a["full_name"]) < String(b["full_name"]))
	_built = true


## The +value (raise) target file path for a modifier entry: the MAX pole for bidirectional,
## the single target for unipolar. "" if none.
static func _pos_target_path(entry: Dictionary) -> String:
	var targets: Array = entry.get("targets", [])
	if String(entry["kind"]) == ModifierRegistry.KIND_BIDIRECTIONAL:
		for t in targets:
			if String(t["which"]) == "max":
				return String(t["path"])
		return ""
	# unipolar
	return String(targets[0]["path"]) if targets.size() > 0 else ""


func is_built() -> bool:
	return _built


## The candidate modifiers at a render vertex (the set the hover-glow lights and the drag
## decomposes across). Returns the stored Array of candidate Dictionaries (do not mutate);
## empty Array if the vertex moves no editable modifier. Pure lookup.
func candidates_at(render_vertex: int) -> Array:
	return _vert_candidates.get(render_vertex, [])


## The set of candidate modifier full_names at a vertex (sorted, deterministic) — the crisp
## answer the unit test asserts.
func candidate_names_at(render_vertex: int) -> PackedStringArray:
	var out := PackedStringArray()
	for c in candidates_at(render_vertex):
		out.append(String(c["full_name"]))
	return out


## Number of render vertices that have at least one candidate (diagnostic / test).
func covered_vertex_count() -> int:
	return _vert_candidates.size()


## The editable modifier full_names (diagnostic / test).
func editable_names() -> PackedStringArray:
	var out := PackedStringArray()
	var keys := _editable.keys()
	keys.sort()
	for k in keys:
		out.append(String(k))
	return out


# ---------------------------------------------------------------------------
# DRAG DECOMPOSITION (the testable core math).
# ---------------------------------------------------------------------------

## The LOCALITY weight of a candidate modifier at a hit point — the fraction of the
## modifier's total +value displacement (over its whole footprint) that lands NEAR the hit,
## Gaussian-weighted by footprint-vertex distance from the hit. See LOCALITY_SIGMA_M above
## for the formula and rationale. Pure: needs the modifier's footprint (built) + the current
## render-vertex world positions + the hit world position. Returns [0,1]; 1 = perfectly
## concentrated at the hit, 0 = displacement entirely elsewhere (a gross/broad axis). When no
## positions are supplied (headless callers that don't model geometry) it returns 1.0 — the
## decomposition then degrades to the old equal-projection behaviour, so existing call sites
## without positions keep working.
func locality_weight(full_name: String, hit_pos: Vector3, positions: PackedVector3Array,
		sigma: float = LOCALITY_SIGMA_M) -> float:
	if positions.is_empty():
		return 1.0
	var fp: Dictionary = _modifier_footprint.get(full_name, {})
	if fp.is_empty():
		return 0.0
	var inv_two_sig2 := 1.0 / (2.0 * sigma * sigma)
	var near := 0.0
	var total := 0.0
	for ri in fp:
		if not (ri < positions.size()):
			continue
		var mag := float(fp[ri])
		total += mag
		var d2 := hit_pos.distance_squared_to(positions[ri])
		near += mag * exp(-d2 * inv_two_sig2)
	if total <= 0.0:
		return 0.0
	return near / total


## Decompose a screen-space drag into per-modifier VALUE-DELTAS at a hit vertex, biased so the
## most-LOCAL candidate(s) dominate the pull and the sensitivity is consistent at any zoom.
##
## Inputs:
##   render_vertex : the picked render-vertex index (selects the candidate set).
##   drag_screen   : the mouse drag in SCREEN pixels (x right, y DOWN, Godot convention).
##   cam_basis     : the camera's world Basis (columns x=right, y=up, z=BACKWARD; the
##                   camera looks down -z). Used to project a world direction to screen.
##   current_vals  : map full_name -> current modifier value (absent => 0, the neutral our
##                   bidirectional/unipolar axes share).
##   px_per_unit   : pixels of on-screen surface motion (along a modifier's screen direction)
##                   per modifier unit — the sensitivity, now in CONSISTENT screen pixels (see
##                   world_per_px) rather than raw world metres, so it feels the same zoomed in
##                   or out.
##   hit_pos       : the hit point in the SAME world frame as `positions` (for the locality
##                   weight). Pass Vector3.ZERO with empty `positions` to disable locality.
##   positions     : current render-vertex world positions (for the locality weight). Empty =>
##                   locality disabled (equal-projection fallback).
##   world_per_px  : WORLD METRES that one screen pixel spans at the hit point's depth — the
##                   ZOOM/DEPTH-ADAPTIVE scale. The creator derives it from the camera
##                   projection at the hit's view-space depth (perspective:
##                   world_per_px = 2·z·tan(fov_y/2) / viewport_height). The effective
##                   sensitivity scales by (world_per_px / REFERENCE_WORLD_PER_PX) so a pixel of
##                   drag moves the SURFACE a consistent number of pixels at any zoom. When <= 0
##                   the scale factor is 1.0 (calibrated/non-adaptive — the headless default,
##                   under which the legacy proportionality tests hold exactly).
##
## Method (per candidate), all in a viewport-free 2D screen frame so it unit-tests headless:
##   1. Project the candidate's WORLD +value surface-motion `dir` (metres/unit) to a screen
##      DIRECTION via the camera basis: screen_dir = (dir·right, −dir·up) (y flipped: screen-y
##      is DOWN). ŝ = screen_dir normalized — the on-screen direction in which raising this
##      modifier pushes the surface. (|screen_dir|≈0 ⇒ motion is straight toward/away from the
##      camera, no in-screen handle ⇒ skip.)
##   2. ZOOM-ADAPTIVE SENSITIVITY: zoom_factor = world_per_px / REFERENCE_WORLD_PER_PX (1.0 when
##      world_per_px ≤ 0). raw_value = (drag·ŝ) · zoom_factor / px_per_unit. Zoomed out
##      (world_per_px large) ⇒ a pixel of drag changes the value MORE, exactly offsetting the
##      surface's smaller on-screen motion per unit — so the felt sensitivity is zoom-invariant.
##   3. LOCALITY-WEIGHTED SHARE: weight w = (locality_weight ^ LOCALITY_POWER). The drag is
##      distributed across candidates IN PROPORTION to these weights (normalized to the
##      strongest local candidate, with anything below LOCALITY_FLOOR zeroed). A tightly-local
##      axis takes nearly the whole pull; a broad/gross axis (locality ~0) takes ~none — this
##      replaces the old equal-by-projection split and the 20% gross cut in one move.
##   4. value_delta = clamp_to_range( current + share · raw_value ) − current. Drag ALONG ŝ
##      raises (positive); opposite lowers; orthogonal ~0; clamped to range.
##
## Returns: map full_name -> value_delta (only non-negligible entries). Deterministic.
func decompose_drag(render_vertex: int, drag_screen: Vector2, cam_basis: Basis,
		current_vals: Dictionary = {}, px_per_unit: float = DEFAULT_PX_PER_UNIT,
		hit_pos: Vector3 = Vector3.ZERO, positions: PackedVector3Array = PackedVector3Array(),
		world_per_px: float = 0.0) -> Dictionary:
	var out := {}
	var cands := candidates_at(render_vertex)
	if cands.is_empty() or drag_screen.length() < 1e-6:
		return out
	var right := cam_basis.x
	var up := cam_basis.y
	# Zoom/depth-adaptive scale: how the actual world-per-pixel at the hit compares to the
	# calibrated reference. 1.0 when not supplied (headless / legacy non-adaptive default).
	var zoom_factor := (world_per_px / REFERENCE_WORLD_PER_PX) if world_per_px > 0.0 else 1.0

	# Pass 1: per candidate, the raw along-drag value (no locality) + its locality weight.
	# We collect, then normalize the locality weights so the most-local candidate(s) dominate.
	var raws := []   # { full_name, range, raw_value, w }
	var max_w := 0.0
	for c in cands:
		var full_name := String(c["full_name"])
		var dir: Vector3 = c["dir"]
		# Project the world +value motion to a screen DIRECTION (y flipped: screen-y is DOWN).
		var screen_dir := Vector2(dir.dot(right), -dir.dot(up))
		if screen_dir.length() < 1e-9:
			continue  # this modifier moves the surface straight toward/away from the
			          # camera here — no in-screen handle to grab; skip (≈0 contribution).
		var unit := screen_dir.normalized()
		# Signed along-drag component (px), zoom-scaled, mapped px->units by px_per_unit.
		var raw_value := drag_screen.dot(unit) * zoom_factor / px_per_unit
		if absf(raw_value) < 1e-9:
			continue
		var w := pow(locality_weight(full_name, hit_pos, positions), LOCALITY_POWER)
		max_w = maxf(max_w, w)
		raws.append({"full_name": full_name, "range": c["range"], "raw": raw_value, "w": w})

	if raws.is_empty() or max_w <= 0.0:
		return out

	# Pass 2: locality SHARE = w / max_w (the strongest local candidate gets full pull; a
	# broad/gross axis with w << max_w gets ~0). Anything below LOCALITY_FLOOR is zeroed — the
	# continuous successor to the gross-axis cut.
	for r in raws:
		var share := float(r["w"]) / max_w
		if share < LOCALITY_FLOOR:
			continue
		var rng: Array = r["range"]
		var full_name := String(r["full_name"])
		var cur := float(current_vals.get(full_name, 0.0))
		var clamped := clampf(cur + share * float(r["raw"]), float(rng[0]), float(rng[1]))
		var vd := clamped - cur
		if absf(vd) > 1e-6:
			out[full_name] = vd
	return out


# ---------------------------------------------------------------------------
# HOVER GLOW weights. The creator feeds these to the body material/overlay so the region the
# candidate modifiers move lights up SOFTLY (smoothstep falloff, not a hard mask).
# ---------------------------------------------------------------------------

## Compute a per-render-vertex glow weight in [0,1] for a hit at `hit_pos` (world) given the
## positions of the candidate-moved vertices. The glow is the UNION of:
##   (a) a spatial falloff around the hit point (smoothstep over GLOW_RADIUS_M), AND
##   (b) the set of vertices the candidate modifiers ACTUALLY move (so the glow traces the
##       editable region, not just a sphere) — each such vertex gets at least a soft floor.
## Returns a Dictionary render_vertex -> weight (only non-zero entries), so the caller can
## clear+set a sparse highlight. Pure geometry; `positions` is the current render-vertex
## world positions (PackedVector3Array). Deterministic.
func glow_weights(render_vertex: int, hit_pos: Vector3, positions: PackedVector3Array,
		radius: float = GLOW_RADIUS_M) -> Dictionary:
	var out := {}
	var r2 := radius * radius
	# (a) spatial smoothstep falloff around the hit point.
	for i in positions.size():
		var d2 := hit_pos.distance_squared_to(positions[i])
		if d2 <= r2:
			var t := sqrt(d2) / radius
			# smoothstep(1->0): bright at the hit, soft at the rim.
			var w := 1.0 - (t * t * (3.0 - 2.0 * t))
			if w > 0.0:
				out[i] = w
	# (b) light the candidate modifiers' moved-vertex FOOTPRINT, so the glow reads as "the
	# region this edit touches", not merely a sphere. A footprint vertex within an extended
	# radius (2× the spatial radius) gets a soft floor scaled by how strongly the modifier
	# moves it (relative to its peak), max-combined with the spatial weight. Keeps the glow
	# soft (continuous), region-shaped, and clearly the editable set.
	var ext := radius * 2.0
	var ext2 := ext * ext
	for c in candidates_at(render_vertex):
		var fp: Dictionary = _modifier_footprint.get(String(c["full_name"]), {})
		# Peak magnitude for normalization (so a faint modifier still reads as its own region).
		var peak := 1e-9
		for ri in fp:
			peak = maxf(peak, float(fp[ri]))
		for ri in fp:
			if not (ri < positions.size()):
				continue
			var d2 := hit_pos.distance_squared_to(positions[ri])
			if d2 > ext2:
				continue
			var t := sqrt(d2) / ext
			var spatial := 1.0 - (t * t * (3.0 - 2.0 * t))
			var floor_w := 0.55 * spatial * (float(fp[ri]) / peak)
			var prev := float(out.get(ri, 0.0))
			if floor_w > prev:
				out[ri] = floor_w
	return out
