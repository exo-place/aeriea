## FacetingMetric — the INDEPENDENT dihedral / edge-angle faceting metric (gate #8a,
## docs/decisions/character-creator-and-body.md §4.6 / §8 #8a; SYNTHESIS.md §3.6).
##
## An OBJECTIVE geometric measure of how ANGULAR a morphed surface is, computed purely
## from the baked triangle mesh — it KNOWS NOTHING about the cap model, so it independently
## catches "this morph facets" regardless of which value caps produced it (the spec's
## "the metric knows no cap" property).
##
## METHOD. For every INTERIOR edge (an edge shared by exactly two triangles), compute the
## DIHEDRAL DEVIATION ANGLE between the two adjacent triangles' face normals:
##
##     deviation = acos(clamp(dot(n1, n2), -1, 1))     (degrees)
##
## This is the angle by which the surface BENDS across that edge — 0° = perfectly flat
## (coplanar triangles), large = a sharp crease. A smooth, well-tessellated surface has
## small per-edge deviations everywhere (each pair of adjacent triangles is nearly
## coplanar); FACETING shows up as a band of edges with LARGE deviation (the tessellation
## can no longer represent the displacement gradient smoothly, so the surface reads as flat
## facets meeting at hard creases).
##
## The metric reports DISTRIBUTION statistics rather than a single number, because faceting
## is a tail phenomenon — a handful of genuinely sharp anatomical edges (nostril rim, lip
## seam) always exist on a real body, so the MEAN stays low while the offending facets live
## in the upper tail. The acceptance gate keys on a HIGH PERCENTILE (default p99.5) — the
## broad faceting band — and the over-threshold edge FRACTION, not the raw max (which a
## single legitimate anatomical crease would trip).
##
## Pure, deterministic, headless (no scene/UI) — edges iterated in a fixed key order.
class_name FacetingMetric
extends RefCounted


## Compute the per-interior-edge dihedral deviation distribution for a baked triangle
## surface. `positions` = ARRAY_VERTEX (morphed), `indices` = ARRAY_INDEX (triangle list,
## 3 indices per triangle). Returns a Dictionary of distribution statistics:
##
##   max_deg          — the single sharpest interior-edge deviation (degrees)
##   mean_deg         — mean deviation over all interior edges
##   p99_deg          — 99th-percentile deviation (the faceting BAND, not a lone crease)
##   p995_deg         — 99.5th percentile (the gate's primary acceptance statistic)
##   p999_deg         — 99.9th percentile
##   edge_count       — number of interior (2-triangle) edges measured
##   frac_over_thresh — fraction of interior edges whose deviation exceeds `thresh_deg`
##   count_over_thresh— count of interior edges over `thresh_deg`
##
## A degenerate triangle (zero-area, no usable normal) is skipped (its edges contribute no
## deviation), so the metric never returns NaN.
## (`max_edge_y` is also returned: the world-Y of the midpoint of the single sharpest
## interior edge — a coarse region locator for monitoring whether a max spike sits in the
## face/head detail band vs the morph-driven torso/limb surfaces.)
static func dihedral_stats(positions: PackedVector3Array, indices: PackedInt32Array,
		thresh_deg: float = 60.0) -> Dictionary:
	# Build edge -> [face_normal, ...] (we only keep the two adjacent face normals; an edge
	# with !=2 incident triangles is a boundary/non-manifold edge and is not an interior
	# dihedral). The edge key is the sorted (min,max) vertex-index pair, packed into one int.
	var edge_faces := {}
	var t := 0
	while t < indices.size():
		var ia := indices[t]
		var ib := indices[t + 1]
		var ic := indices[t + 2]
		t += 3
		var a := positions[ia]
		var b := positions[ib]
		var c := positions[ic]
		var fn := (c - a).cross(b - a)
		var fl := fn.length()
		if fl <= 1e-12:
			continue   # degenerate triangle: no usable face normal
		fn = fn / fl
		_add_edge(edge_faces, ia, ib, fn)
		_add_edge(edge_faces, ib, ic, fn)
		_add_edge(edge_faces, ic, ia, fn)

	# Collect per-interior-edge deviation angles (degrees), in a deterministic key order.
	# Track the sharpest edge's key so its midpoint Y can be reported as a region locator.
	var keys := edge_faces.keys()
	keys.sort()
	var devs := PackedFloat32Array()
	var max_dev := -1.0
	var max_key := -1
	for k in keys:
		var fs: Array = edge_faces[k]
		if fs.size() != 2:
			continue   # boundary or non-manifold edge: not an interior dihedral
		var d := (fs[0] as Vector3).dot(fs[1] as Vector3)
		d = clampf(d, -1.0, 1.0)
		var ang := rad_to_deg(acos(d))
		devs.append(ang)
		if ang > max_dev:
			max_dev = ang
			max_key = k

	var stats := _summarize(devs, thresh_deg)
	var max_edge_y := 0.0
	if max_key >= 0:
		var lo := max_key & 0xFFFFFF
		var hi := (max_key >> 24) & 0xFFFFFF
		max_edge_y = (positions[lo].y + positions[hi].y) * 0.5
	stats["max_edge_y"] = max_edge_y
	return stats


static func _add_edge(edge_faces: Dictionary, i0: int, i1: int, fn: Vector3) -> void:
	var lo := mini(i0, i1)
	var hi := maxi(i0, i1)
	# Pack the (lo,hi) pair into one int key (24-bit lo | hi<<24 is ample for ~14.5k verts).
	var key := lo | (hi << 24)
	if edge_faces.has(key):
		(edge_faces[key] as Array).append(fn)
	else:
		edge_faces[key] = [fn]


## Summarize a deviation-angle sample into the gate statistics.
static func _summarize(devs: PackedFloat32Array, thresh_deg: float) -> Dictionary:
	var n := devs.size()
	if n == 0:
		return {
			"max_deg": 0.0, "mean_deg": 0.0, "p99_deg": 0.0, "p995_deg": 0.0,
			"p999_deg": 0.0, "edge_count": 0, "frac_over_thresh": 0.0,
			"count_over_thresh": 0,
		}
	var sorted := devs.duplicate()
	sorted.sort()
	var sum := 0.0
	var over := 0
	for v in sorted:
		sum += v
		if v > thresh_deg:
			over += 1
	return {
		"max_deg": float(sorted[n - 1]),
		"mean_deg": sum / float(n),
		"p99_deg": _percentile(sorted, 0.99),
		"p995_deg": _percentile(sorted, 0.995),
		"p999_deg": _percentile(sorted, 0.999),
		"edge_count": n,
		"frac_over_thresh": float(over) / float(n),
		"count_over_thresh": over,
	}


## The p-quantile of an ascending-sorted sample (nearest-rank).
static func _percentile(sorted_asc: PackedFloat32Array, p: float) -> float:
	var n := sorted_asc.size()
	if n == 0:
		return 0.0
	var idx := int(ceil(clampf(p, 0.0, 1.0) * float(n))) - 1
	idx = clampi(idx, 0, n - 1)
	return float(sorted_asc[idx])
