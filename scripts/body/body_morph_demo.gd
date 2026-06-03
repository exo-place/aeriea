## Slice-1 body morph demo (docs/decisions/body-and-locomotion-slice.md §4,
## Slice 1 deliverable). Loads the nix-built base body ArrayMesh, shows it at
## 1u = 1m scale, and exposes a debug slider per macro blendshape axis driving
## the weights LIVE — so you can sweep age baby→old and watch the mesh morph.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://scenes/body_morph_demo.tscn
extends Node3D

const MESH_PATH := "res://assets/body/base_body.res"

var _mi: MeshInstance3D
var _sliders: Dictionary = {}


func _ready() -> void:
	var mesh: ArrayMesh = load(MESH_PATH)
	if mesh == null:
		push_error("body_morph_demo: failed to load %s" % MESH_PATH)
		return

	# light + camera
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -40, 0)
	add_child(light)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.15, 0.16, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.4, 0.45)
	env.environment = e
	add_child(env)

	_mi = MeshInstance3D.new()
	_mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.7, 0.62)
	_mi.material_override = mat
	add_child(_mi)

	# frame the body (eye-ish height, a couple metres back)
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.9, 3.0), Vector3(0, 0.9, 0), Vector3.UP)

	_build_ui(mesh)


func _build_ui(mesh: ArrayMesh) -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(320, 0)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(panel)

	var title := Label.new()
	title.text = "aeriea body — macro morph axes (Slice 1)"
	panel.add_child(title)

	for i in mesh.get_blend_shape_count():
		var axis := mesh.get_blend_shape_name(i)
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = str(axis)
		lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(180, 0)
		slider.value = 0.0
		var idx := i
		slider.value_changed.connect(func(v: float) -> void:
			_mi.set("blend_shapes/%s" % axis, v)
		)
		row.add_child(slider)
		panel.add_child(row)
		_sliders[axis] = slider
