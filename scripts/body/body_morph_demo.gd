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
## Raw per-blendshape weights driven by the top section's sliders. Baked through the
## correct-normals CPU path (apply_morph_cpu) just like BodyState, so the demo is lit
## correctly under morph from EITHER section.
var _raw_weights: Dictionary = {}
## SLICE 2 — the BodyState record is the single source of truth for body morph
## params (body_state.gd; body-and-locomotion-slice.md §2.1). The BodyState section
## of the panel drives the blendshape weights through BodyState.apply_to(), and shows
## the derived Layer-1 is_adult_body() predicate live as the continuous age sweeps.
var _body_state: BodyState = BodyState.new()
var _adult_label: Label


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
	# PER-INSTANCE copy: the BodyState section morphs through the correct-normals CPU
	# bake (apply_morph_cpu), which mutates the surface — keep it private to this demo
	# so the shared cached asset is never corrupted.
	mesh = (mesh as ArrayMesh).duplicate(true)
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
		var axis_name := str(axis)
		_raw_weights[axis_name] = 0.0
		slider.value_changed.connect(func(v: float) -> void:
			# Correct-normals path: accumulate the raw weight then CPU-bake (positions +
			# recomputed normals). A GPU-only set("blend_shapes/...") would leave stale,
			# octahedral-compressed normals -> mis-lit morphed surface (BodyState).
			_raw_weights[axis_name] = v
			_body_state.apply_morph_cpu(_mi, _raw_weights)
		)
		row.add_child(slider)
		panel.add_child(row)
		_sliders[axis] = slider

	_build_body_state_section(panel)


## SLICE 2 — a BodyState-driven section: continuous macro-axis sliders that update
## the BodyState record (the single source of truth), then BodyState.apply_to() drives
## the blendshape weights. The age slider is CONTINUOUS (baby->child->young->old) and a
## live label shows the derived is_adult_body() Layer-1 predicate over it.
func _build_body_state_section(panel: VBoxContainer) -> void:
	var sep := HSeparator.new()
	panel.add_child(sep)
	var heading := Label.new()
	heading.text = "BodyState (Slice 2 — record drives morphs)"
	panel.add_child(heading)

	_adult_label = Label.new()
	panel.add_child(_adult_label)

	# [field, min, max, init] for the natural-unit headline axes BodyState carries
	# (body-parameterization.md §2). age in YEARS; masculinity 0–100 (0=feminine,
	# 50=androgynous, 100=masculine); muscle/weight in %; height in metric CM (Slice C,
	# §4 — a uniform stature scale orthogonal to proportions).
	var axes := [
		["age_years", 1.0, 90.0, _body_state.age_years],
		["masculinity", 0.0, 100.0, _body_state.masculinity],
		["muscle", 0.0, 100.0, _body_state.muscle],
		["weight", 50.0, 150.0, _body_state.weight],
		["height_cm", 50.0, 230.0, _body_state.height_cm],
	]
	for spec in axes:
		var field: String = spec[0]
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "BodyState.%s" % field
		lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = float(spec[1])
		slider.max_value = float(spec[2])
		slider.step = 0.01
		slider.value = float(spec[3])
		slider.custom_minimum_size = Vector2(180, 0)
		slider.value_changed.connect(func(v: float) -> void:
			_body_state.set(field, v)
			_body_state.apply_morph_cpu(_mi)
			_refresh_adult_label()
		)
		row.add_child(slider)
		panel.add_child(row)

	_body_state.apply_morph_cpu(_mi)
	_refresh_adult_label()


func _refresh_adult_label() -> void:
	if _adult_label == null:
		return
	_adult_label.text = "age=%.0f yr -> is_adult_body() = %s  (NSFW gate input, >= 18yr)" % [
		_body_state.age_years, str(_body_state.is_adult_body())]
