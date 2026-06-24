## Manual render + MEASURE harness (NOT a committed test): verify the imported breast cup-size
## cube (character-creator-ux.md §8.2) produces a REAL, measurable size change — not just lift.
## Bakes a feminine body at breast_size 0.0 / 0.5 / 1.0, measures the chest-region forward (+Z)
## protrusion of the morphed mesh, and renders a side profile at each so the size delta is visible.
##
##   BREAST_OUT=/tmp/buildBfix xvfb-run -a godot4 --path . res://tools/breast_size_render.tscn --quit-after 800
extends Node

const BodyRigScript := preload("res://scripts/body/body_rig.gd")

var _out_dir := ""


func _ready() -> void:
	_out_dir = OS.get_environment("BREAST_OUT")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_measure()


## Build a feminine BodyState and measure the chest-region forward protrusion at three cup sizes.
## The cube is female-only, so we use a feminine (masculinity 20) body. We measure the MAX +Z of
## verts in the chest band (y in the upper-torso range), as a proxy for apparent breast size.
func _measure() -> void:
	await get_tree().process_frame
	var rig = BodyRigScript.new()
	add_child(rig)
	rig.build()
	var sizes := [0.0, 0.5, 1.0]
	var results := []
	for s in sizes:
		var bs := BodyState.new()
		bs.masculinity = 20.0   # feminine — the cup cube is female-weighted
		bs.weight = 100.0
		bs.breast_size = s
		rig.apply_body_state(bs)
		var z := _chest_max_z(rig)
		results.append(z)
		print("breast_size_render: breast_size=%.2f -> chest max +Z = %.5f m" % [s, z])
	if results.size() == 3:
		print("breast_size_render: DELTA min->max = %.5f m (%.1f mm); monotone = %s"
			% [results[2] - results[0], (results[2] - results[0]) * 1000.0,
			   results[0] < results[1] and results[1] < results[2]])
	# Side-profile renders at small / large so the size change is visible to the USER.
	await _render_profiles(rig)
	get_tree().quit(0)


func _render_profiles(rig) -> void:
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.global_position = Vector3(1.7, 1.30, 1.5)   # front-3/4, chest height (chest faces +Z)
	cam.look_at(Vector3(0.0, 1.22, 0.0), Vector3.UP)
	cam.current = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.15, 0.15, 0.18)
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-20, 200, 0)   # key from front-right, lighting the chest
	add_child(light)
	for s in [0.0, 1.0]:
		var bs := BodyState.new()
		bs.masculinity = 20.0
		bs.breast_size = float(s)
		rig.apply_body_state(bs)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var label := "breast_profile_%s" % ("small" if s == 0.0 else "large")
		img.save_png(_out_dir.path_join("%s.png" % label))
		print("breast_size_render: wrote %s.png" % label)


## Max forward (+Z) vertex position in the chest band of the morphed body mesh (rest pose).
func _chest_max_z(rig) -> float:
	var mi: MeshInstance3D = rig.mesh_instance
	if mi == null or mi.mesh == null:
		return 0.0
	var arrays = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Chest band: empirically the breasts sit ~1.25–1.45 m on the neutral-height feminine body.
	var ylo := 1.15
	var yhi := 1.45
	var maxz := -INF
	for v in verts:
		if v.y >= ylo and v.y <= yhi:
			maxz = maxf(maxz, v.z)
	return maxz
