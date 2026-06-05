## CpuAccelPicker — the CPU spatial-grid `Picker` backend.
##
## Picks against a target's REST-SPACE baked triangles (rest_positions + tris) via a
## uniform spatial grid: voxelize the mesh AABB, bucket each triangle into the cells
## its AABB overlaps, and on a pick walk only the cells the ray crosses (3D-DDA),
## running Möller–Trumbore on the few triangles in those cells. This is the creator
## default — instant, deterministic, headlessly unit-testable, no GPU stall. It
## REPLACES the old brute-force-over-every-triangle scan in character_creator.
##
## ── Grid vs BVH ──────────────────────────────────────────────────────────────────
## A uniform grid (not a BVH): the target is a bounded humanoid with reasonably uniform
## triangle density and a stable AABB — the pathological wildly-varying-density case a
## BVH guards against does not occur. The grid is simpler and trivially deterministic
## (pure integer/float bucketing + DDA, no tree-build ordering or split-heuristic
## nondeterminism). Reserve a BVH only if profiling ever shows the grid insufficient.
##
## ── Determinism ──────────────────────────────────────────────────────────────────
## build() is a pure function of (rest_positions, tris): same inputs → byte-identical
## grid → identical picks. Picking touches no RNG and no wall clock.
##
## ── Lazy rebuild ─────────────────────────────────────────────────────────────────
## The grid is built from rest-space baked positions, which change on every morph bake.
## Rather than rebuild per drag-frame (wasteful; the hit vertex is locked for a drag's
## duration anyway), the owner calls mark_dirty() on bake; pick() checks/clears the
## dirty flag at its top and rebuilds once on the next pick if needed. No timer, no race.
class_name CpuAccelPicker
extends Picker

## Target average triangles per occupied cell — drives the grid resolution heuristic.
const TARGET_TRIS_PER_CELL := 8.0
## Resolution clamp so a degenerate (tiny / huge) mesh can't blow up the grid.
const MIN_RES := 1
const MAX_RES := 96
## Epsilon padding so triangles exactly on a cell boundary still bucket in.
const AABB_PAD := 1e-4

var _built := false
var _dirty := false

# Cached source geometry (rest space). Held so a lazy rebuild needs no re-fetch.
var _positions: PackedVector3Array
var _tris: PackedInt32Array

# Grid state.
var _origin: Vector3            ## grid AABB minimum corner (rest space)
var _cell: Vector3              ## per-axis cell size
var _res := Vector3i.ONE        ## grid resolution per axis
# Buckets: a flat cell array of PackedInt32Array, each holding TRIANGLE START INDICES
# (the i where the tri is tris[i], tris[i+1], tris[i+2]). Built deterministically.
var _cells: Array = []


## True once build() has produced a usable grid.
func is_built() -> bool:
	return _built


## True if a rebuild is pending (geometry changed since the last build).
func is_dirty() -> bool:
	return _dirty


## Mark the grid stale. The owner calls this on a morph bake; the next pick() rebuilds.
func mark_dirty() -> void:
	_dirty = true


## Build (or rebuild) the grid from rest-space positions + a triangle index list.
## Pure function of the inputs → deterministic. Caches the geometry for lazy rebuilds.
func build(rest_positions: PackedVector3Array, tris: PackedInt32Array) -> void:
	_positions = rest_positions
	_tris = tris
	_built = false
	_dirty = false
	_cells = []
	var nt := tris.size()
	if rest_positions.is_empty() or nt < 3:
		return

	# Mesh AABB over the referenced vertices.
	var mn := rest_positions[tris[0]]
	var mx := mn
	var i := 0
	while i < nt:
		for k in 3:
			var p := rest_positions[tris[i + k]]
			mn = mn.min(p)
			mx = mx.max(p)
		i += 3
	# Pad so surface verts sit strictly inside the grid.
	mn -= Vector3.ONE * AABB_PAD
	mx += Vector3.ONE * AABB_PAD
	_origin = mn
	var extent := mx - mn

	# Resolution from a target average tris/cell: total cells ~= tri_count / target,
	# distributed across axes proportional to extent. Clamped to [MIN_RES, MAX_RES].
	var tri_count := nt / 3
	var target_cells := maxf(1.0, float(tri_count) / TARGET_TRIS_PER_CELL)
	var vol := maxf(extent.x, 1e-6) * maxf(extent.y, 1e-6) * maxf(extent.z, 1e-6)
	var cube := pow(target_cells / vol, 1.0 / 3.0)   # cells per metre
	_res = Vector3i(
		clampi(int(round(maxf(extent.x, 1e-6) * cube)), MIN_RES, MAX_RES),
		clampi(int(round(maxf(extent.y, 1e-6) * cube)), MIN_RES, MAX_RES),
		clampi(int(round(maxf(extent.z, 1e-6) * cube)), MIN_RES, MAX_RES),
	)
	_cell = Vector3(
		extent.x / float(_res.x),
		extent.y / float(_res.y),
		extent.z / float(_res.z),
	)

	var total := _res.x * _res.y * _res.z
	_cells.resize(total)
	for c in total:
		_cells[c] = PackedInt32Array()

	# Bucket each triangle into every cell its AABB overlaps (conservative; correct).
	i = 0
	while i < nt:
		var a := rest_positions[tris[i]]
		var b := rest_positions[tris[i + 1]]
		var c := rest_positions[tris[i + 2]]
		var tmn := a.min(b).min(c)
		var tmx := a.max(b).max(c)
		var lo := _cell_coord(tmn)
		var hi := _cell_coord(tmx)
		for cz in range(lo.z, hi.z + 1):
			for cy in range(lo.y, hi.y + 1):
				for cx in range(lo.x, hi.x + 1):
					var idx := _cell_index(cx, cy, cz)
					# Mutate-in-place then write back: indexing a Variant Array yields a
					# COPY for Packed arrays, so append() alone would not persist.
					var bucket: PackedInt32Array = _cells[idx]
					bucket.append(i)
					_cells[idx] = bucket
		i += 3

	_built = true


## Clamp a rest-space point to a grid cell coordinate.
func _cell_coord(p: Vector3) -> Vector3i:
	return Vector3i(
		clampi(int(floor((p.x - _origin.x) / _cell.x)), 0, _res.x - 1),
		clampi(int(floor((p.y - _origin.y) / _cell.y)), 0, _res.y - 1),
		clampi(int(floor((p.z - _origin.z) / _cell.z)), 0, _res.z - 1),
	)


func _cell_index(cx: int, cy: int, cz: int) -> int:
	return (cz * _res.y + cy) * _res.x + cx


## Picker override. Transforms the screen ray into rest space (one inverse, vs a
## per-triangle world transform), DDA-walks the grid cells the ray crosses, and runs
## Möller–Trumbore on those cells' triangles. Returns the nearest hit (see Picker doc).
func pick(screen_pos: Vector2, camera: Camera3D, target: Dictionary) -> Dictionary:
	if camera == null:
		return {}
	# Lazy rebuild: a pick arriving the same frame as a bake must see fresh geometry.
	if _dirty:
		build(_positions, _tris)
	if not _built:
		# Allow a first pick to build from the target if the owner didn't pre-build.
		var rp: PackedVector3Array = target.get("rest_positions", PackedVector3Array())
		var tt: PackedInt32Array = target.get("tris", PackedInt32Array())
		if not rp.is_empty() and tt.size() >= 3:
			build(rp, tt)
		if not _built:
			return {}

	var world_xf: Transform3D = target.get("world_xf", Transform3D.IDENTITY)
	var inv := world_xf.affine_inverse()
	# Ray into rest space.
	var o := inv * camera.project_ray_origin(screen_pos)
	var d := (inv.basis * camera.project_ray_normal(screen_pos)).normalized()

	var best_t := INF
	var best_tri := -1
	# DDA over the grid; track which triangles we've already M–T'd (a tri may span cells).
	var seen := {}
	for cell_idx in _ray_cells(o, d):
		for tstart in (_cells[cell_idx] as PackedInt32Array):
			if seen.has(tstart):
				continue
			seen[tstart] = true
			var a := _positions[_tris[tstart]]
			var b := _positions[_tris[tstart + 1]]
			var c := _positions[_tris[tstart + 2]]
			var t := _ray_tri(o, d, a, b, c)
			if t >= 0.0 and t < best_t:
				best_t = t
				best_tri = tstart
	if best_tri < 0:
		return {}

	var hit_rest := o + d * best_t
	var i0 := _tris[best_tri]
	var i1 := _tris[best_tri + 1]
	var i2 := _tris[best_tri + 2]
	# Barycentric of the hit point over the hit triangle.
	var bary := _barycentric(hit_rest, _positions[i0], _positions[i1], _positions[i2])
	# render_vertex_index = nearest of the 3 verts to the hit point (matches the
	# creator's historical refinement, so the picked vertex is unchanged).
	var verts := [i0, i1, i2]
	var best_v := i0
	var best_d := INF
	for vi in verts:
		var dd := _positions[vi].distance_squared_to(hit_rest)
		if dd < best_d:
			best_d = dd
			best_v = vi
	return {
		"hit": true,
		"render_vertex_index": int(best_v),
		"triangle_index": best_tri,
		"barycentric": bary,
		"world_pos": world_xf * hit_rest,
	}


## 3D-DDA: the ordered list of cell indices the ray (rest space) traverses, from the
## point it enters the grid AABB until it exits. Empty if the ray misses the AABB.
func _ray_cells(o: Vector3, d: Vector3) -> PackedInt32Array:
	var out := PackedInt32Array()
	var gmin := _origin
	var gmax := _origin + _cell * Vector3(_res)

	# Slab-clip the ray to the grid AABB → [t_enter, t_exit].
	var t_enter := 0.0
	var t_exit := INF
	for axis in 3:
		var oi := o[axis]
		var di := d[axis]
		var lo := gmin[axis]
		var hi := gmax[axis]
		if absf(di) < 1e-12:
			if oi < lo or oi > hi:
				return out   # parallel & outside this slab → miss
		else:
			var inv := 1.0 / di
			var t1 := (lo - oi) * inv
			var t2 := (hi - oi) * inv
			if t1 > t2:
				var tmp := t1; t1 = t2; t2 = tmp
			t_enter = maxf(t_enter, t1)
			t_exit = minf(t_exit, t2)
			if t_enter > t_exit:
				return out
	if t_exit < 0.0:
		return out

	# Entry point → starting cell.
	var p := o + d * maxf(t_enter, 0.0)
	var cx := clampi(int(floor((p.x - _origin.x) / _cell.x)), 0, _res.x - 1)
	var cy := clampi(int(floor((p.y - _origin.y) / _cell.y)), 0, _res.y - 1)
	var cz := clampi(int(floor((p.z - _origin.z) / _cell.z)), 0, _res.z - 1)

	var step := Vector3i(
		1 if d.x >= 0.0 else -1,
		1 if d.y >= 0.0 else -1,
		1 if d.z >= 0.0 else -1,
	)
	# Per-axis: distance (in t) to the next cell boundary, and the t-delta per full cell.
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	var cur := Vector3i(cx, cy, cz)
	for axis in 3:
		var di := d[axis]
		if absf(di) < 1e-12:
			continue
		var inv := 1.0 / di
		var cell_size := _cell[axis]
		t_delta[axis] = absf(cell_size * inv)
		var boundary: float
		if di >= 0.0:
			boundary = _origin[axis] + float(cur[axis] + 1) * cell_size
		else:
			boundary = _origin[axis] + float(cur[axis]) * cell_size
		t_max[axis] = maxf(t_enter, 0.0) + (boundary - p[axis]) * inv

	while cur.x >= 0 and cur.x < _res.x and cur.y >= 0 and cur.y < _res.y and cur.z >= 0 and cur.z < _res.z:
		out.append(_cell_index(cur.x, cur.y, cur.z))
		# Advance along the axis with the nearest boundary.
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			cur.x += step.x
			t_max.x += t_delta.x
		elif t_max.y <= t_max.z:
			cur.y += step.y
			t_max.y += t_delta.y
		else:
			cur.z += step.z
			t_max.z += t_delta.z
	return out


## Möller–Trumbore ray/triangle intersection (moved verbatim-in-behaviour from
## character_creator._ray_tri). Returns the ray t (>=0) at the hit, or -1.0 on a miss.
## Two-sided (winding-independent) — picking should not depend on triangle winding.
func _ray_tri(o: Vector3, d: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var e1 := b - a
	var e2 := c - a
	var p := d.cross(e2)
	var det := e1.dot(p)
	if absf(det) < 1e-9:
		return -1.0
	var inv := 1.0 / det
	var tvec := o - a
	var u := tvec.dot(p) * inv
	if u < -1e-5 or u > 1.0 + 1e-5:
		return -1.0
	var q := tvec.cross(e1)
	var v := d.dot(q) * inv
	if v < -1e-5 or u + v > 1.0 + 1e-5:
		return -1.0
	var t := e2.dot(q) * inv
	return t if t > 1e-5 else -1.0


## Barycentric coordinates (1-u-v, u, v) of point p over triangle (a,b,c).
func _barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 1e-12:
		return Vector3(1.0, 0.0, 0.0)
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	return Vector3(1.0 - v - w, v, w)
