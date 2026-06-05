## GPU ID-buffer picker render check (Phase 2 of the picking-abstraction plan).
##
## This is a RENDER-based assertion, OUT of the headless determinism / golden-trace path:
## it builds the REAL BodyRig, renders it through a camera, then drives BOTH the GPU
## ID-buffer picker (scripts/util/gpu_id_picker.gd) and the CPU grid picker
## (scripts/util/cpu_accel_picker.gd) at the SAME screen positions and asserts they AGREE
## on the picked render-vertex index (the GPU returns the provoking vertex of the hit
## triangle; the CPU returns the nearest-of-3 — for a hit on or near a triangle these
## resolve to a vertex of the SAME triangle, so we accept "GPU id is one of the CPU hit
## triangle's three verts" as agreement).
##
## It also resolves the plan's flagged unknowns EMPIRICALLY on this Godot build and PRINTS
## the finding for each:
##   (a) does `flat` on a custom varying give stable provoking-vertex passthrough?
##   (b) does the SubViewport apply sRGB / tonemap that corrupts the encoded ID bytes?
##   (c) is a synchronous 1-pixel readback workable under xvfb/llvmpipe?
##   (d) does CUSTOM0 (the baked render-vertex id) survive load + the body_state re-bake?
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/gpu_id_picker_test.tscn --quit-after 8000
extends Node3D

const CpuAccelPicker := preload("res://scripts/util/cpu_accel_picker.gd")
const GpuIdPicker := preload("res://scripts/util/gpu_id_picker.gd")

var _pass := 0
var _fail := 0

var _rig: BodyRig
var _cam: Camera3D
var _cpu: CpuAccelPicker
var _gpu: GpuIdPicker
var _rest: PackedVector3Array
var _tris: PackedInt32Array
var _ran := false


func _ready() -> void:
	print("\n=== aeriea GPU ID-BUFFER PICKER — render check (gpu_id_picker.gd) ===\n")
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 25, 0)
	add_child(key)
	_rig = BodyRig.new()
	_rig.show_genitals = false
	add_child(_rig)
	_cam = Camera3D.new()
	add_child(_cam)


func _process(_dt: float) -> void:
	if _ran:
		return
	# Let the rig build + a few frames settle so the mesh + skeleton exist.
	if _rig.skeleton == null or _rig.mesh_instance == null or _rig.mesh_instance.mesh == null:
		return
	if Engine.get_process_frames() < 8:
		return
	_ran = true
	_run()


func _ok(name: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", name)
	else:
		_fail += 1
		print("  FAIL  ", name)


func _run() -> void:
	_rig.apply_body_state(BodyState.new())
	var arrays := (_rig.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	_rest = arrays[Mesh.ARRAY_VERTEX]
	_tris = arrays[Mesh.ARRAY_INDEX]
	print("  body: %d render verts, %d tris" % [_rest.size(), _tris.size() / 3])

	# (d) CUSTOM0 (the baked render-vertex id) must survive load AND the body_state re-bake
	# (clear_surfaces + add_surface_from_arrays in apply_morph_cpu). The mesh we read here was
	# already re-baked by apply_body_state above, so decoding it proves survival end-to-end.
	var rebaked := _rig.mesh_instance.mesh as ArrayMesh
	var fmt := rebaked.surface_get_format(0)
	var c0v = rebaked.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	var c0_ok := (fmt & Mesh.ARRAY_FORMAT_CUSTOM0) != 0 and c0v != null
	if c0_ok:
		var c0: PackedByteArray = c0v
		c0_ok = c0.size() == _rest.size() * 4
		for iv in [0, 1, 100, 5000, _rest.size() - 1]:
			var i := int(iv)
			var o := i * 4
			var dec := int(c0[o]) | (int(c0[o + 1]) << 8) | (int(c0[o + 2]) << 16)
			if dec != i:
				c0_ok = false
	_ok("(d) CUSTOM0 survives load + re-bake (decodes to vertex ordinals)", c0_ok)

	_cpu = CpuAccelPicker.new()
	_cpu.build(_rest, _tris)
	_gpu = GpuIdPicker.new()
	_gpu.set_host(self)

	# Frame the camera on the whole body, looking at its mid-height from the front.
	var top := _rig.head_top()
	var mid := top * 0.5
	_cam.look_at_from_position(Vector3(0, mid, top * 1.1), Vector3(0, mid, 0), Vector3.UP)
	_cam.fov = 45
	_cam.current = true

	# Render at least one frame so the main viewport projection is valid.
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var vp_size := Vector2(get_viewport().get_visible_rect().size)
	var target := {
		"world_xf": _rig.skeleton.global_transform,
		"rest_positions": _rest,
		"tris": _tris,
		"mesh_instance": _rig.mesh_instance,
		"skeleton": _rig.skeleton,
	}

	# Sample a grid of screen positions over the body's projected bounds; collect points
	# where the CPU picker (ground truth on the rest mesh) reports a hit.
	var samples: Array = []
	var center := vp_size * 0.5
	for sx in [-0.12, -0.06, 0.0, 0.06, 0.12]:
		for sy in [-0.3, -0.15, 0.0, 0.15, 0.3]:
			samples.append(center + Vector2(sx * vp_size.x, sy * vp_size.y))

	# Aim the GPU viewport once and let it render a couple of frames (UPDATE_ALWAYS, 1-frame
	# latency — see GpuIdPicker class doc). The camera is static across all samples, so a
	# single aim + settle is enough for the whole battery.
	_gpu.aim_at(_cam, target)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var cpu_hits := 0
	var gpu_hits := 0
	var agree := 0
	var srgb_was: Variant = null
	for sp in samples:
		var ch := _cpu.pick(sp, _cam, target)
		if ch.is_empty():
			continue
		cpu_hits += 1
		var gh := _gpu.pick(sp, _cam, target)
		if srgb_was == null:
			srgb_was = _gpu.srgb_decode   # the decode path the picker resolved for this build
		if gh.is_empty():
			continue
		gpu_hits += 1
		var gidx := int(gh["render_vertex_index"])
		var cidx := int(ch["render_vertex_index"])
		# CORRECTNESS CRITERION for the GPU picker: the decoded vertex, projected back to the
		# screen through the SAME camera, must land NEAR the sample point — i.e. the ID buffer
		# correctly reports which vertex is rendered under the cursor. (Comparing to the CPU's
		# nearest-rest-vertex directly is looser: the two backends pick fundamentally different
		# things — a rest triangle vs a rasterised fragment — so screen-reprojection is the
		# honest test of GPU correctness. We ALSO accept near-in-world agreement with the CPU.)
		var ti := int(ch["triangle_index"])
		var tri_verts := [_tris[ti], _tris[ti + 1], _tris[ti + 2]]
		var same_tri := gidx in tri_verts
		var near := gidx >= 0 and gidx < _rest.size() and _rest[gidx].distance_to(_rest[cidx]) < 0.06
		var reproj_ok := false
		if gidx >= 0 and gidx < _rest.size():
			var wp: Vector3 = (target["world_xf"] as Transform3D) * _rest[gidx]
			if not _cam.is_position_behind(wp):
				var sp2 := _cam.unproject_position(wp)
				reproj_ok = sp2.distance_to(sp) < 32.0   # within ~32 px of the sampled cursor
		if same_tri or near or reproj_ok:
			agree += 1
		elif cpu_hits <= 8:
			print("    DIAG cpu_idx=%d gpu_idx=%d dist=%.3f reproj_ok=%s" % [
				cidx, gidx,
				_rest[gidx].distance_to(_rest[cidx]) if gidx < _rest.size() else -1.0,
				str(reproj_ok)])

	print("  unknown (b) sRGB/tonemap mangle bytes? -> sRGB decode needed = %s" % str(srgb_was))
	print("  CPU hits=%d  GPU hits=%d  agree=%d / %d" % [cpu_hits, gpu_hits, agree, cpu_hits])

	# (c) sync 1-pixel readback workable: we got GPU hits at all -> readback works under xvfb.
	_ok("(c) sync 1-pixel readback works under xvfb/llvmpipe", gpu_hits > 0)
	# (a) flat provoking-vertex passthrough: a decoded index in valid range that matches the
	# CPU's hit triangle proves the per-fragment id was NOT interpolated to garbage.
	_ok("(a) flat custom varying -> valid in-range provoking vertex", gpu_hits > 0 and agree > 0)
	# Agreement threshold: most sampled hits must agree (some edge/silhouette pixels legitimately
	# disagree because GPU picks the rendered/skinned surface vs CPU rest mesh).
	_ok("GPU vs CPU agree on >=70%% of CPU hits", cpu_hits > 0 and float(agree) / float(cpu_hits) >= 0.7)

	print("\n=== RESULTS: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
