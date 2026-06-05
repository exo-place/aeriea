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
##      drag vector, and the camera basis + a vertex world position, project each
##      candidate modifier's world surface-motion direction into SCREEN SPACE, then
##      distribute the drag across candidates by PROJECTION — the component of the drag
##      along each modifier's screen-motion direction, scaled by sensitivity, becomes
##      that modifier's value-delta, CLAMPED to the modifier's range. Dragging along a
##      modifier's screen motion INCREASES it; opposite DECREASES; orthogonal ~= 0.
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

## A modifier whose +value target moves MORE than this fraction of all render vertices is a
## GROSS PLACEMENT axis (whole-torso / whole-head translate & scale, body measurements) — it
## technically "moves" the hit vertex too, but it is not what a sculptor reaches for when
## pulling a LOCAL surface feature, and (having the largest screen motion everywhere) it would
## dominate the decomposition and swamp the local detail axes. Such modifiers are EXCLUDED
## from per-vertex drag candidacy — they stay fully editable via their sliders. This keeps
## drag-to-modify a LOCAL sculpt; the gross axes remain on the panel. (Honest: this is a
## heuristic split, tuned so the body-global translate/scale/measure axes drop out while the
## per-feature detail axes — nose/eyes/mouth/cheek/breast/… — stay grabbable.)
const GROSS_FOOTPRINT_FRACTION := 0.20

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
## `render_vertex_count` (optional) is the total render-vertex count, used to drop GROSS
## placement axes (footprint > GROSS_FOOTPRINT_FRACTION of all verts) from drag candidacy.
## When <= 0 it is inferred as (max moved index + 1) across the editable targets; pass the
## library's true count when available for a stable threshold.
func build_accel(registry: Dictionary, lib, render_vertex_count: int = 0) -> void:
	_vert_candidates = {}
	_editable = {}
	_modifier_footprint = {}
	var entries: Array = registry.get("modifiers", [])
	# Sort modifiers by full_name so the build order is deterministic regardless of the
	# registry's array order.
	var sorted_entries := entries.duplicate()
	sorted_entries.sort_custom(func(a, b): return String(a["full_name"]) < String(b["full_name"]))

	# PASS 1 — for each non-macro modifier whose +value target is in the library, gather its
	# significant per-vertex deltas (its FOOTPRINT) and the candidate record list. We do not
	# yet write _vert_candidates: a modifier may be dropped as a gross axis in pass 2.
	var pending := []   # Array of { full_name, kind, range, recs:Array[{ri,dir,mag}] }
	var max_ri := -1
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
			max_ri = maxi(max_ri, ri)
		_modifier_footprint[full_name] = footprint
		pending.append({"full_name": full_name, "kind": kind,
			"range": [float(rng[0]), float(rng[1])], "recs": recs})

	# Decide the GROSS placement axes to exclude from per-vertex candidacy: any modifier whose
	# footprint exceeds GROSS_FOOTPRINT_FRACTION of the render-vertex total. They stay in
	# _editable (slider-editable) and keep their footprint (so the glow can still show them if
	# ever wanted), but are NOT offered as drag candidates — so local detail axes win the pull.
	var total_verts := render_vertex_count if render_vertex_count > 0 else (max_ri + 1)
	var gross_cap := int(float(maxi(1, total_verts)) * GROSS_FOOTPRINT_FRACTION)

	# PASS 2 — emit per-vertex candidates for the NON-gross modifiers.
	for p in pending:
		if (p["recs"] as Array).size() > gross_cap:
			continue  # gross placement axis — slider-only, not a drag candidate
		for r in p["recs"]:
			var ri := int(r["ri"])
			var cand := {
				"full_name": p["full_name"],
				"kind": p["kind"],
				"range": p["range"],
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

## Decompose a screen-space drag into per-modifier VALUE-DELTAS at a hit vertex.
##
## Inputs:
##   render_vertex : the picked render-vertex index (selects the candidate set).
##   drag_screen   : the mouse drag in SCREEN pixels (x right, y DOWN, Godot convention).
##   cam_basis     : the camera's world Basis (columns x=right, y=up, z=BACKWARD; the
##                   camera looks down -z). Used to project a world direction to screen.
##   current_vals  : map full_name -> current modifier value (absent => 0, the neutral our
##                   bidirectional/unipolar axes share).
##   px_per_unit   : pixels of drag (along a modifier's screen motion) per modifier unit.
##
## Method (per candidate), all in a viewport-free 2D screen frame so it unit-tests headless:
##   1. Project the candidate's WORLD surface-motion direction `dir` to screen space using
##      the camera basis: screen_dir = (dot(dir, right), -dot(dir, up)) — y is flipped
##      because screen-y points DOWN while camera-up points UP. (An orthographic projection
##      of the direction; right/up split is all the decomposition needs.) ŝ = screen_dir
##      normalized: the on-screen direction in which raising this modifier pushes the surface.
##   2. value_delta = clamp_to_range( current + (drag · ŝ) / px_per_unit ) - current,
##      i.e. the signed component of the drag ALONG ŝ (in pixels) divided by px_per_unit
##      (pixels-of-drag mapping to one modifier unit — the sensitivity). A drag ALONG ŝ
##      is positive (raise); opposite negative (lower); orthogonal ~0. Clamped to range.
##
## Returns: map full_name -> value_delta (only non-negligible entries). Deterministic.
func decompose_drag(render_vertex: int, drag_screen: Vector2, cam_basis: Basis,
		current_vals: Dictionary = {}, px_per_unit: float = DEFAULT_PX_PER_UNIT) -> Dictionary:
	var out := {}
	var cands := candidates_at(render_vertex)
	if cands.is_empty() or drag_screen.length() < 1e-6:
		return out
	var right := cam_basis.x
	var up := cam_basis.y
	for c in cands:
		var full_name := String(c["full_name"])
		var dir: Vector3 = c["dir"]
		# Project the world +value motion to screen (y flipped: screen-y is DOWN).
		var screen_dir := Vector2(dir.dot(right), -dir.dot(up))
		if screen_dir.length() < 1e-9:
			continue  # this modifier moves the surface straight toward/away from the
			          # camera here — no in-screen handle to grab; skip (≈0 contribution).
		var unit := screen_dir.normalized()
		# Signed component of the drag along this modifier's screen motion, in modifier units.
		var raw_delta := drag_screen.dot(unit) / px_per_unit
		if absf(raw_delta) < 1e-6:
			continue
		var rng: Array = c["range"]
		var cur := float(current_vals.get(full_name, 0.0))
		var clamped := clampf(cur + raw_delta, float(rng[0]), float(rng[1]))
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
