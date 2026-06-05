## Picker test (Phase 1 of the picking-abstraction plan): the CPU uniform-grid backend
## (scripts/util/cpu_accel_picker.gd) behind the Picker interface (scripts/util/picker.gd).
## Proves, headlessly:
##
##   (1) KNOWN RAY — a ray aimed at a known triangle returns the expected
##       render_vertex_index, triangle_index, and a barycentric summing to ~1.
##   (2) PARITY WITH BRUTE FORCE — over a battery of rays across a denser mesh, the grid
##       picks the SAME render_vertex_index as a reference brute-force Möller–Trumbore
##       scan (the grid must not change WHICH vertex is picked vs the old creator scan).
##   (3) DETERMINISM — same inputs -> byte-identical result; a rebuild -> identical grid
##       (identical pick over the battery).
##   (4) DIRTY-REBUILD — mark_dirty() after mutating the cached positions causes the next
##       pick() to rebuild from the new geometry and hit the moved surface.
##
## Uses a real Camera3D in a SubViewport so project_ray_origin/normal are exercised exactly
## as the creator drives them. No body artifact needed — small synthetic meshes.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/picker_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const CpuAccelPicker := preload("res://scripts/util/cpu_accel_picker.gd")

var _pass := 0
var _fail := 0

var _viewport: SubViewport
var _camera: Camera3D


func _ready() -> void:
	print("\n=== aeriea PICKER — CPU uniform-grid backend (picker.gd / cpu_accel_picker.gd) ===\n")
	_setup_camera()
	# Let the SubViewport lay out so the camera projection is valid before picking.
	await get_tree().process_frame
	await get_tree().process_frame
	_test_known_ray()
	_test_parity_with_brute_force()
	_test_determinism()
	_test_dirty_rebuild()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


## A fixed orthographic-ish perspective camera on +Z looking toward -Z at the origin, in
## its own SubViewport (so project_ray_* uses a known projection). The camera sits at
## +Z=3 so a ray through screen-centre travels -Z through the origin.
func _setup_camera() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 256)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.near = 0.05
	_viewport.add_child(_camera)
	# Transform must be set AFTER the camera is in the tree (look_at needs it in-tree).
	_camera.global_position = Vector3(0, 0, 3)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


# --- A small deterministic mesh: two big quads (4 tris) straddling the origin, +
# a battery-mesh helper that subdivides a plane into a grid of tris. -----------------

## One axis-aligned quad in the z=0 plane spanning [-S,S] in x and y, as 2 tris.
## Verts: 0=(-S,-S), 1=(S,-S), 2=(S,S), 3=(-S,S). Tris: (0,1,2),(0,2,3).
func _quad(s: float) -> Array:
	var pos := PackedVector3Array([
		Vector3(-s, -s, 0), Vector3(s, -s, 0), Vector3(s, s, 0), Vector3(-s, s, 0),
	])
	var tris := PackedInt32Array([0, 1, 2, 0, 2, 3])
	return [pos, tris]


## A subdivided plane in z=0, n x n cells over [-1,1]^2 → (n+1)^2 verts, 2 n^2 tris.
func _grid_plane(n: int) -> Array:
	var pos := PackedVector3Array()
	var side := n + 1
	for j in side:
		for i in side:
			var x := lerpf(-1.0, 1.0, float(i) / float(n))
			var y := lerpf(-1.0, 1.0, float(j) / float(n))
			pos.append(Vector3(x, y, 0.0))
	var tris := PackedInt32Array()
	for j in n:
		for i in n:
			var v0 := j * side + i
			var v1 := v0 + 1
			var v2 := v0 + side
			var v3 := v2 + 1
			tris.append_array(PackedInt32Array([v0, v1, v3, v0, v3, v2]))
	return [pos, tris]


# --- Reference brute-force pick (the OLD creator scan), for parity. -----------------

## Möller–Trumbore (same epsilons as CpuAccelPicker._ray_tri). t>=0 hit, -1 miss.
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


## Brute-force scan in WORLD space (matching the old _pick_body): returns the nearest-vertex
## render index, or -1 on a miss.
func _brute_pick(screen_pos: Vector2, world_xf: Transform3D, pos: PackedVector3Array, tris: PackedInt32Array) -> int:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var best_t := INF
	var best_tri := -1
	var i := 0
	while i < tris.size():
		var a := world_xf * pos[tris[i]]
		var b := world_xf * pos[tris[i + 1]]
		var c := world_xf * pos[tris[i + 2]]
		var t := _ray_tri(origin, dir, a, b, c)
		if t >= 0.0 and t < best_t:
			best_t = t
			best_tri = i
		i += 3
	if best_tri < 0:
		return -1
	var hit := origin + dir * best_t
	var verts := [tris[best_tri], tris[best_tri + 1], tris[best_tri + 2]]
	var best_v := int(verts[0])
	var best_d := INF
	for vi in verts:
		var wp := world_xf * pos[vi]
		var dd := wp.distance_squared_to(hit)
		if dd < best_d:
			best_d = dd
			best_v = int(vi)
	return best_v


# --- Tests --------------------------------------------------------------------------

func _test_known_ray() -> void:
	print("--- (1) known ray -> expected vertex / triangle / barycentric ---")
	var q := _quad(1.0)
	var pos: PackedVector3Array = q[0]
	var tris: PackedInt32Array = q[1]
	var picker := CpuAccelPicker.new()
	picker.build(pos, tris)
	_assert("grid built", picker.is_built(), "")

	var target := {"world_xf": Transform3D.IDENTITY, "rest_positions": pos, "tris": tris}
	# Centre-screen ray -> origin, on the shared edge of both tris. Aim slightly toward
	# vert 1 (S,-S) so the lower-right triangle (0,1,2) is unambiguously hit.
	var hit := picker.pick(Vector2(160, 160), _camera, target)
	_assert("centre-ish ray hits the quad", not hit.is_empty(), "hit=%s" % str(hit))
	if hit.is_empty():
		return
	_assert("hit flag set", bool(hit.get("hit", false)), "")
	# world_pos near the z=0 plane and near the origin.
	var wp: Vector3 = hit["world_pos"]
	_assert("hit point on the z=0 plane", absf(wp.z) < 1e-3, "z=%.5f" % wp.z)
	# barycentric sums to ~1 and is non-negative.
	var b: Vector3 = hit["barycentric"]
	_assert("barycentric sums to ~1", absf(b.x + b.y + b.z - 1.0) < 1e-4, "b=%s" % str(b))
	_assert("barycentric non-negative", b.x >= -1e-4 and b.y >= -1e-4 and b.z >= -1e-4, "b=%s" % str(b))
	# triangle_index is a valid tri start (multiple of 3, in range).
	var ti: int = hit["triangle_index"]
	_assert("triangle_index is a valid tri start", ti >= 0 and ti % 3 == 0 and ti < tris.size(), "ti=%d" % ti)
	# render_vertex_index is one of the hit triangle's verts.
	var rv: int = hit["render_vertex_index"]
	var ok := rv == tris[ti] or rv == tris[ti + 1] or rv == tris[ti + 2]
	_assert("render_vertex_index is a vert of the hit triangle", ok, "rv=%d ti=%d" % [rv, ti])
	# Parity: same vertex the brute-force scan picks for this exact ray.
	var bv := _brute_pick(Vector2(160, 160), Transform3D.IDENTITY, pos, tris)
	_assert("known-ray vertex == brute-force vertex", rv == bv, "grid=%d brute=%d" % [rv, bv])


func _test_parity_with_brute_force() -> void:
	print("--- (2) parity: grid pick == brute-force pick over a ray battery ---")
	var g := _grid_plane(8)   # 81 verts, 128 tris
	var pos: PackedVector3Array = g[0]
	var tris: PackedInt32Array = g[1]
	# A non-trivial world transform (the stature scale the creator applies): scale + offset.
	var world_xf := Transform3D(Basis().scaled(Vector3(1.3, 0.9, 1.0)), Vector3(0.05, -0.1, 0.0))
	var picker := CpuAccelPicker.new()
	picker.build(pos, tris)
	var target := {"world_xf": world_xf, "rest_positions": pos, "tris": tris}

	var checked := 0
	var hits := 0
	var mismatches := 0
	# Sweep a grid of screen positions across the viewport.
	for sy in range(20, 240, 17):
		for sx in range(20, 240, 17):
			var sp := Vector2(sx, sy)
			var grid_hit := picker.pick(sp, _camera, target)
			var brute := _brute_pick(sp, world_xf, pos, tris)
			checked += 1
			if brute < 0:
				# Brute missed -> grid must also miss (allow grid to also report empty).
				if not grid_hit.is_empty():
					mismatches += 1
				continue
			hits += 1
			if grid_hit.is_empty() or int(grid_hit["render_vertex_index"]) != brute:
				mismatches += 1
	_assert("battery exercised real hits (>20)", hits > 20, "hits=%d/%d" % [hits, checked])
	_assert("grid pick == brute-force pick for EVERY ray (0 mismatches)",
		mismatches == 0, "mismatches=%d over %d rays (%d hits)" % [mismatches, checked, hits])


func _test_determinism() -> void:
	print("--- (3) determinism: same inputs -> identical result; rebuild -> identical grid ---")
	var g := _grid_plane(6)
	var pos: PackedVector3Array = g[0]
	var tris: PackedInt32Array = g[1]
	var target := {"world_xf": Transform3D.IDENTITY, "rest_positions": pos, "tris": tris}

	var a := CpuAccelPicker.new()
	a.build(pos, tris)
	var b := CpuAccelPicker.new()
	b.build(pos, tris)

	var all_match := true
	var sample := 0
	for sy in range(30, 230, 23):
		for sx in range(30, 230, 23):
			var sp := Vector2(sx, sy)
			var ha := a.pick(sp, _camera, target)
			var hb := b.pick(sp, _camera, target)
			sample += 1
			if JSON.stringify(_pick_to_comparable(ha)) != JSON.stringify(_pick_to_comparable(hb)):
				all_match = false
	_assert("two fresh grids give byte-identical picks over the battery", all_match, "n=%d" % sample)

	# Rebuild the SAME picker from the same inputs -> identical to its earlier self.
	var c := CpuAccelPicker.new()
	c.build(pos, tris)
	var sp := Vector2(160, 160)
	var first := c.pick(sp, _camera, target)
	c.build(pos, tris)   # rebuild
	var second := c.pick(sp, _camera, target)
	_assert("rebuild -> identical pick (deterministic grid)",
		JSON.stringify(_pick_to_comparable(first)) == JSON.stringify(_pick_to_comparable(second)),
		"%s vs %s" % [str(first), str(second)])


func _test_dirty_rebuild() -> void:
	print("--- (4) dirty-rebuild after mutating positions ---")
	# Start with the quad far behind the camera's near hit plane at z=0; pick hits it.
	var q := _quad(1.0)
	var pos: PackedVector3Array = q[0]
	var tris: PackedInt32Array = q[1]
	var picker := CpuAccelPicker.new()
	picker.build(pos, tris)
	var target := {"world_xf": Transform3D.IDENTITY, "rest_positions": pos, "tris": tris}
	var hit0 := picker.pick(Vector2(160, 160), _camera, target)
	_assert("pre-mutation: centre ray hits the quad", not hit0.is_empty(), "")

	# Shrink the quad to a tiny patch off-axis so the centre ray now MISSES it — but the
	# stale grid still references the old (large) geometry until a rebuild.
	var small := PackedVector3Array([
		Vector3(0.8, 0.8, 0), Vector3(0.82, 0.8, 0), Vector3(0.82, 0.82, 0), Vector3(0.8, 0.82, 0),
	])
	# Mutate the picker's CACHED geometry the way the owner does (it holds the same arrays):
	# rebuild needs the new positions, so update the cache via a direct build-input swap.
	picker._positions = small   # cached source; mark_dirty triggers a rebuild from it
	picker.mark_dirty()
	_assert("picker reports dirty after mark_dirty()", picker.is_dirty(), "")
	var hit1 := picker.pick(Vector2(160, 160), _camera, {"world_xf": Transform3D.IDENTITY})
	_assert("post-mutation rebuild: centre ray now MISSES the shrunk off-axis patch",
		hit1.is_empty(), "hit=%s" % str(hit1))
	_assert("dirty flag cleared after the rebuilding pick", not picker.is_dirty(), "")

	# And a ray aimed AT the new patch hits it (proves the rebuild used the new geometry).
	# Project the patch centre to screen and pick there.
	var patch_centre := Vector3(0.81, 0.81, 0.0)
	var screen := _camera.unproject_position(patch_centre)
	var hit2 := picker.pick(screen, _camera, {"world_xf": Transform3D.IDENTITY})
	_assert("ray at the new patch centre hits the rebuilt geometry", not hit2.is_empty(),
		"screen=%s hit=%s" % [str(screen), str(hit2)])


## Strip floats to a stable rounded form so JSON compare is robust to formatting only
## (the values must still be bit-equal between deterministic runs, which they are).
func _pick_to_comparable(h: Dictionary) -> Dictionary:
	if h.is_empty():
		return {}
	return {
		"v": int(h["render_vertex_index"]),
		"t": int(h["triangle_index"]),
		"b": [h["barycentric"].x, h["barycentric"].y, h["barycentric"].z],
		"w": [h["world_pos"].x, h["world_pos"].y, h["world_pos"].z],
	}


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
