## Creator glow-overlay test (scripts/body/character_creator.gd, §2.3 / §6.6).
## Objective verification of the Phase-2b glow fixes (visual quality stays USER-gated):
##
##   (1) FOLLOWS-MORPH — the glow geometry is re-read from the CURRENT morphed surface, not
##       a once-at-build neutral capture. After a strong morph + bake, the refreshed glow
##       base positions differ from the neutral capture (the glow tracks the body).
##   (2) OUTWARD OFFSET — the built glow overlay's vertices sit a NONZERO distance OFF the
##       skin along the morphed normal (so the additive shell floats above the surface
##       instead of z-fighting), and that distance is ~the world-space ε scaled by the
##       inverse stature scale (constant WORLD thickness across the height range).
##   (3) SCALE-CORRECTION — at a taller stature (larger height_scale) the rest-space offset
##       SHRINKS (ε/height_scale), so the WORLD offset stays ~constant.
##
## Runs the real creator scene (its _ready builds the rig + glow overlay), so this exercises
## the live owner-driven refresh path, not a stub.
##
##   (4) PICKER RAYCASTS THE MORPHED SURFACE (B2 correctness) — after a heavy morph + bake, a
##       screen ray aimed at a known MORPHED vertex returns a hit ON the morphed surface (within
##       a tight tolerance of the morphed vertex), NOT on the stale neutral geometry. Pre-fix the
##       picker re-gridded its build-time NEUTRAL source on mark_dirty(), so the hit landed
##       ~0.0157 m off (scaling with morph magnitude). Asserts hit≈morphed and hit≪neutral.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_glow_test.tscn --quit-after 8000
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR glow overlay — follows-morph + outward offset (Phase 2b) ===\n")
	await _run()
	await _run_picker_morphed_surface()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _run() -> void:
	var creator = CreatorScene.instantiate()
	add_child(creator)
	# Let _ready build the rig, the morph-drag accel, and the glow overlay.
	await get_tree().process_frame
	await get_tree().process_frame

	if creator._rig == null or creator._rig.mesh_instance == null:
		_assert("creator built a rig with a mesh", false, "rig/mesh null")
		creator.queue_free()
		return

	# --- (1) FOLLOWS-MORPH ---------------------------------------------------------
	# Force a clean neutral glow geometry capture.
	creator._glow_geom_dirty = true
	creator._refresh_glow_geometry()
	var neutral_pos: PackedVector3Array = creator._glow_base_pos.duplicate()
	_assert("glow base positions captured (non-empty)", neutral_pos.size() > 1000,
		"n=%d" % neutral_pos.size())

	# Apply a strong shape morph (weight + masculinity move the torso/face a lot) and re-bake.
	creator._body_state.weight = 100.0
	creator._body_state.masculinity = 100.0
	creator._body_state.age_years = 60.0
	creator._apply_state()   # bakes the morphed surface AND marks the glow geometry dirty
	_assert("a bake marks the glow geometry dirty (so the next rebuild re-reads it)",
		creator._glow_geom_dirty, "dirty=%s" % creator._glow_geom_dirty)
	creator._refresh_glow_geometry()
	var morphed_pos: PackedVector3Array = creator._glow_base_pos

	var moved := 0
	var max_disp := 0.0
	var n := mini(neutral_pos.size(), morphed_pos.size())
	for i in n:
		var d := neutral_pos[i].distance_to(morphed_pos[i])
		if d > 1e-4:
			moved += 1
		max_disp = maxf(max_disp, d)
	_assert("glow base positions CHANGE when the body morphs (follows-morph, not stale)",
		moved > 100 and max_disp > 0.005,
		"moved=%d/%d max_disp=%.4f m" % [moved, n, max_disp])

	# --- (2) OUTWARD OFFSET --------------------------------------------------------
	# Build the glow overlay with a synthetic weight on a fixed vertex and read the overlay
	# mesh back. The overlay vertex must be offset OUTWARD along that vertex's normal.
	var vi := 100
	var weights := {vi: 1.0}
	creator._rebuild_glow_mesh(weights)
	var overlay_mesh := creator._glow_overlay.mesh as ArrayMesh
	_assert("glow overlay built a mesh", overlay_mesh != null and overlay_mesh.get_surface_count() > 0,
		"surfaces=%d" % (overlay_mesh.get_surface_count() if overlay_mesh != null else -1))

	if overlay_mesh != null and overlay_mesh.get_surface_count() > 0:
		var ov: PackedVector3Array = overlay_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var base: PackedVector3Array = creator._glow_base_pos
		var nrm: PackedVector3Array = creator._glow_base_nrm
		var off_vec: Vector3 = ov[vi] - base[vi]
		var off_len: float = off_vec.length()
		var hscale: float = creator._body_state.height_scale()
		var expected: float = creator.GLOW_WORLD_OFFSET / maxf(hscale, 1e-4)
		_assert("glow overlay vertex is offset OUTWARD off the skin (nonzero)",
			off_len > 1e-5, "off_len=%.6f m (rest space)" % off_len)
		# direction: along the vertex normal.
		var dotn := 0.0
		if nrm.size() > vi and nrm[vi].length() > 1e-6:
			dotn = off_vec.normalized().dot(nrm[vi].normalized())
		_assert("glow offset is along the vertex NORMAL (outward, not sideways)",
			dotn > 0.99, "dot(offset, normal)=%.4f" % dotn)
		_assert("glow offset magnitude ~ ε/height_scale (world-space, scale-corrected)",
			absf(off_len - expected) < 1e-5,
			"off_len=%.6f expected=%.6f (ε=%.4f hscale=%.4f)" % [off_len, expected, creator.GLOW_WORLD_OFFSET, hscale])

		# --- (3) SCALE-CORRECTION: a TALLER body shrinks the rest-space offset ------
		creator._body_state.height_cm = 200.0
		creator._apply_state()
		creator._refresh_glow_geometry()
		creator._rebuild_glow_mesh(weights)
		var tall_mesh := creator._glow_overlay.mesh as ArrayMesh
		var ov2: PackedVector3Array = tall_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var base2: PackedVector3Array = creator._glow_base_pos
		var off2: float = (ov2[vi] - base2[vi]).length()
		var hscale2: float = creator._body_state.height_scale()
		var world1: float = off_len * hscale
		var world2: float = off2 * hscale2
		_assert("rest-space glow offset is scale-corrected (world thickness ~constant across stature)",
			absf(world1 - world2) < 1e-4 and hscale2 > hscale,
			"world1=%.5f world2=%.5f hscale %.3f->%.3f rest %.6f->%.6f" % [world1, world2, hscale, hscale2, off_len, off2])

	creator.queue_free()


## (4) The B2 regression: the CPU picker must raycast the MORPHED surface, not the stale
## neutral geometry it cached at build. We morph the body heavily, pick a front-facing vertex
## that the orbit camera can see, project ITS MORPHED position to screen, raycast there, and
## assert the hit lands on the morphed surface (≈ the morphed vertex) and is FAR from where
## that vertex sat at neutral (which is what a stale-neutral picker would hit).
func _run_picker_morphed_surface() -> void:
	print("\n--- (4) picker raycasts the MORPHED surface (B2 correctness) ---")
	var creator = CreatorScene.instantiate()
	add_child(creator)
	await get_tree().process_frame
	await get_tree().process_frame

	if creator._rig == null or creator._rig.mesh_instance == null or creator._camera == null:
		_assert("creator built rig + camera for the picker test", false, "rig/camera null")
		creator.queue_free()
		return

	# Capture the NEUTRAL baked surface (what a stale picker would keep gridding).
	var neutral_arrays := (creator._rig.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	var neutral_pos: PackedVector3Array = (neutral_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()

	# Heavy morph: weight high + a gender shift (the critic's repro), so the surface moves a lot.
	creator._body_state.weight = 100.0
	creator._body_state.masculinity = 100.0
	creator._apply_state()   # bakes the morphed surface AND feeds the picker the morphed positions
	await get_tree().process_frame

	var morphed_arrays := (creator._rig.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	var morphed_pos: PackedVector3Array = morphed_arrays[Mesh.ARRAY_VERTEX]
	var morphed_nrm: PackedVector3Array = morphed_arrays[Mesh.ARRAY_NORMAL]

	# World transform the picker uses: the skeleton's global transform (stature scale).
	var world_xf: Transform3D = creator._rig.skeleton.global_transform
	var cam: Camera3D = creator._camera

	# Find a front-facing, well-displaced vertex the camera can see: its MORPHED world pos must
	# project on-screen and its normal must face the camera (so a ray actually hits its triangle
	# first). Prefer a vertex whose neutral→morphed displacement is large (so stale vs morphed is
	# unambiguous) and front-facing (+z, toward the +Z orbit camera looking at -Z).
	var vp_size := creator.get_viewport().get_visible_rect().size
	var best_vi := -1
	var best_disp := 0.0
	var n := mini(neutral_pos.size(), morphed_pos.size())
	for i in n:
		var nrm_world := (world_xf.basis * morphed_nrm[i]).normalized()
		var to_cam := (cam.global_position - world_xf * morphed_pos[i]).normalized()
		if nrm_world.dot(to_cam) < 0.6:
			continue   # back-facing / grazing — its triangle won't be the first hit
		var wp_m: Vector3 = world_xf * morphed_pos[i]
		if cam.is_position_behind(wp_m):
			continue
		var sp := cam.unproject_position(wp_m)
		if sp.x < 4 or sp.y < 4 or sp.x > vp_size.x - 4 or sp.y > vp_size.y - 4:
			continue
		var disp := neutral_pos[i].distance_to(morphed_pos[i])
		if disp > best_disp:
			best_disp = disp
			best_vi = i
	_assert("found a front-facing, displaced morphed vertex to aim at", best_vi >= 0 and best_disp > 0.005,
		"vi=%d disp=%.4f m" % [best_vi, best_disp])
	if best_vi < 0:
		creator.queue_free()
		return

	# Aim the ray at the MORPHED vertex's screen position and pick.
	var wp_morphed: Vector3 = world_xf * morphed_pos[best_vi]
	var wp_neutral: Vector3 = world_xf * neutral_pos[best_vi]
	var screen := cam.unproject_position(wp_morphed)
	var hit: Dictionary = creator._pick_body(screen)
	_assert("pick on the morphed body returns a hit", not hit.is_empty(), "screen=%s hit=%s" % [str(screen), str(hit)])
	if hit.is_empty():
		creator.queue_free()
		return

	var hit_pos: Vector3 = hit["pos"]
	# Distance from the ray hit to the TRUE morphed surface point we aimed at, vs to the NEUTRAL
	# position the stale picker would have raycast. The morphed distance must be tight (~0); the
	# neutral distance is the pre-fix error (the critic measured ~0.0157 m on a modest morph; a
	# heavy morph here is larger). The fix is proven when hit≈morphed AND hit≪neutral.
	var d_morphed := hit_pos.distance_to(wp_morphed)
	var d_neutral := hit_pos.distance_to(wp_neutral)
	print("  [B2] hit→morphed = %.5f m   hit→neutral(stale-picker would land near here) = %.5f m   morph displacement = %.5f m"
		% [d_morphed, d_neutral, wp_morphed.distance_to(wp_neutral)])
	_assert("ray hit lands ON the morphed surface (tight tolerance of the morphed vertex)",
		d_morphed < 0.01, "hit→morphed=%.5f m" % d_morphed)
	_assert("ray hit is NOT on the stale neutral geometry (hit≪neutral; B2 defect fixed)",
		d_morphed < d_neutral * 0.5 and d_neutral > 0.01,
		"hit→morphed=%.5f m hit→neutral=%.5f m" % [d_morphed, d_neutral])

	creator.queue_free()


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
