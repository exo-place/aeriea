## GpuIdPicker — the GPU "pick what's rendered" `Picker` backend.
##
## Renders the SAME body mesh (skinned + morphed on the GPU, so the picked surface is the
## actually-displayed one) into an off-screen SubViewport with an unshaded ID material that
## writes each fragment's source RENDER-VERTEX INDEX as a color (from ARRAY_CUSTOM0, baked
## into base_body.res by tools/body_converter.gd). The single pixel under the cursor is read
## back and decoded → render-vertex index → MorphDrag candidates.
##
## ── Why this backend exists (generality, not perf) ───────────────────────────────
## A rest-space CPU grid (CpuAccelPicker) is the creator default — instant, deterministic,
## headlessly unit-testable. But it picks the REST mesh: for an ANIMATED / skinned in-world
## target the rest mesh is the wrong surface. The GPU backend picks whatever the GPU actually
## rasterised (skinning + morphs applied), so the identical technique generalises to picking
## skinned NPCs / animated interactables in-world. Cost: a GPU→CPU readback stall (v1 ships
## a synchronous 1-pixel get_image()+get_pixel, mirroring the creator's PNG-export readback).
##
## ── Encoding ─────────────────────────────────────────────────────────────────────
## CUSTOM0 is RGBA8_UNORM: per vertex, bytes [low, mid, high, 255] of the 24-bit index. The
## id_pick shader passes CUSTOM0 as a `flat` varying (provoking-vertex, no interpolation) and
## emits .rgb to ALBEDO. On readback each channel is a float 0..1; ×255, round → the byte;
## idx = R + G·256 + B·65536. The SubViewport is configured so no sRGB/tonemap mangles the
## bytes — see _make_viewport() and the SRGB note there.
##
## triangle_index / barycentric are NOT recoverable from a vertex-id buffer (it carries one id
## per fragment, not a triangle) → returned as -1 / ZERO. world_pos is supplied as
## world_xf * rest_positions[idx], consistent with how the creator glow converts.
##
## ── ONE-FRAME LATENCY (empirically required on Godot 4.6 / llvmpipe) ──────────────
## A SubViewport does NOT populate its texture within a single synchronous
## RenderingServer.force_draw() call on this build (verified empirically: a freshly-built
## off-screen viewport renders nothing under sync force_draw, but renders correctly with
## UPDATE_ALWAYS across a real frame). So the viewport runs UPDATE_ALWAYS and
## pick() reads whatever the GPU rendered LAST frame: the caller must aim_at() (mirror the
## camera/pose) and let ONE frame elapse before pick() returns a fresh result. This is the
## 1-frame readback latency the plan documents — imperceptible for hover-glow; for drag-start
## the pick lags one frame, then the vertex locks. The creator awaits a frame between
## aim_at() and pick(); the simpler all-in-one pick() returns last frame's view.
class_name GpuIdPicker
extends Picker

const IdShader := preload("res://assets/body/id_pick.gdshader")

## The off-screen render target. Sized to the main viewport; the ID camera mirrors the
## main camera each pick so the ID image is pixel-aligned with what the player sees.
var _viewport: SubViewport
var _id_cam: Camera3D
var _id_mi: MeshInstance3D
var _id_mat: ShaderMaterial
var _holder: Node3D            ## parents the ID skeleton/mesh inside the viewport scene
var _id_skel: Skeleton3D       ## a skinned ID mesh needs a skeleton sibling, as in-creator

## Inverse-sRGB-correct the read channel? EMPIRICALLY RESOLVED on Godot 4.6 / llvmpipe
## (verified empirically): the SubViewport applies an sRGB OETF to the unshaded ALBEDO
## bytes, so get_pixel returns sRGB-encoded floats; recovering the byte needs the sRGB→linear
## EOTF (verified: byte 132 read back as 0.745 → s2l → 131.3 ✓; raw 0.745×255=190 ✗). Default
## true. Settable to false to A/B the raw path on a build that does NOT apply sRGB.
var srgb_decode := true

var _built := false

## Debug: the last raw read pixel + full ID image (set each pick; used by the render check).
var last_color: Color
var last_image: Image

## A SubViewport must be in the scene tree to render. The owner provides a host node the
## picker parents the off-screen viewport under (RefCounted can't add itself to the tree).
var _host: Node


func is_built() -> bool:
	return _built


## Provide the scene-tree node under which the off-screen ID SubViewport lives. Call once,
## before the first pick(), from the owner (e.g. the character creator's _ready).
func set_host(host: Node) -> void:
	_host = host


## Build the off-screen ID render graph for a given target. Idempotent per target mesh:
## rebuilds if the mesh instance / skeleton changed. The ID mesh SHARES the target mesh
## (same skinning, same morph bake) under a skeleton mirroring the target's pose, so the ID
## pass rasterises exactly the displayed surface.
func build(target: Dictionary) -> void:
	var src_mi: MeshInstance3D = target.get("mesh_instance", null)
	if src_mi == null or src_mi.mesh == null:
		return
	_teardown()
	_viewport = _make_viewport()
	if _host != null and is_instance_valid(_host):
		_host.add_child(_viewport)

	_holder = Node3D.new()
	_viewport.add_child(_holder)

	# Mirror the source skeleton so the ID mesh skins identically. We reuse the SAME
	# Skeleton3D node is not possible (it lives under the real scene), so we add a sibling
	# MeshInstance3D under a copy skeleton built from the source's bone poses each pick.
	var src_skel: Skeleton3D = target.get("skeleton", null)
	_id_mi = MeshInstance3D.new()
	_id_mi.mesh = src_mi.mesh
	_id_mat = ShaderMaterial.new()
	_id_mat.shader = IdShader
	_id_mi.material_override = _id_mat

	if src_skel != null:
		_id_skel = Skeleton3D.new()
		# Clone bone tree + rests so the Skin resolves the same indices.
		for i in src_skel.get_bone_count():
			_id_skel.add_bone(src_skel.get_bone_name(i))
		for i in src_skel.get_bone_count():
			_id_skel.set_bone_parent(i, src_skel.get_bone_parent(i))
			_id_skel.set_bone_rest(i, src_skel.get_bone_rest(i))
		_holder.add_child(_id_skel)
		_id_skel.add_child(_id_mi)
		if src_mi.skin != null:
			_id_mi.skin = src_mi.skin
	else:
		_holder.add_child(_id_mi)

	_id_cam = Camera3D.new()
	_viewport.add_child(_id_cam)
	_built = true


func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	# UPDATE_ALWAYS: a SubViewport does not populate within a single sync force_draw on this
	# build (see class doc), so it renders every frame and pick() reads last frame's texture.
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	# No HDR / no tonemap / no glow — the ID bytes must reach readback unmodified. A fresh
	# Environment with a flat clear and tonemap DISABLED keeps the unshaded ALBEDO bytes raw.
	vp.msaa_3d = Viewport.MSAA_DISABLED   # MSAA would blend edge fragments → bad ids
	vp.use_hdr_2d = false
	vp.positional_shadow_atlas_size = 0
	vp.own_world_3d = true
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)   # id 0's R=0 too; the miss check uses ALPHA/black
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	we.environment = env
	vp.add_child(we)
	return vp


## Mirror the main camera + source skeleton pose into the ID viewport so the NEXT rendered
## frame matches what the player sees. Call this, let one frame elapse (UPDATE_ALWAYS draws
## it), then pick(). The all-in-one pick() also calls aim_at() first, so a steady-state caller
## (hover) that picks every frame reads last frame's correctly-aimed view.
func aim_at(camera: Camera3D, target: Dictionary) -> void:
	if camera == null:
		return
	if not _built or _id_mi == null or _id_mi.mesh != target.get("mesh_instance", _make_dummy()).mesh:
		build(target)
	if not _built:
		return

	var main_vp := camera.get_viewport()
	var size := Vector2i(main_vp.get_visible_rect().size)
	if size.x <= 0 or size.y <= 0:
		size = Vector2i(512, 512)
	_viewport.size = size

	# Mirror camera transform + intrinsics (perspective: fov/near/far suffice).
	_id_cam.global_transform = camera.global_transform
	_id_cam.projection = camera.projection
	_id_cam.fov = camera.fov
	_id_cam.near = camera.near
	_id_cam.far = camera.far
	_id_cam.size = camera.size
	_id_cam.keep_aspect = camera.keep_aspect
	_id_cam.current = true

	# Mirror the source skeleton pose (global stature scale + any bone poses) so the ID
	# surface matches the displayed one frame-exactly.
	var src_mi: MeshInstance3D = target.get("mesh_instance", null)
	var src_skel: Skeleton3D = target.get("skeleton", null)
	if _id_skel != null and src_skel != null:
		_id_skel.global_transform = src_skel.global_transform
		for i in src_skel.get_bone_count():
			_id_skel.set_bone_pose_position(i, src_skel.get_bone_pose_position(i))
			_id_skel.set_bone_pose_rotation(i, src_skel.get_bone_pose_rotation(i))
			_id_skel.set_bone_pose_scale(i, src_skel.get_bone_pose_scale(i))
	elif src_mi != null:
		_id_mi.global_transform = src_mi.global_transform


## Picker override. aim_at() + read the single pixel under the cursor from the LAST rendered
## frame, decode → render-vertex index. world_pos = world_xf * rest_positions[idx] (the
## vertex-id buffer carries no triangle/bary). NOTE the 1-frame latency (see class doc): for a
## correct same-instant pick, aim_at() then await a frame before calling pick().
func pick(screen_pos: Vector2, camera: Camera3D, target: Dictionary) -> Dictionary:
	if camera == null:
		return {}
	aim_at(camera, target)
	if not _built:
		return {}
	var world_xf: Transform3D = target.get("world_xf", Transform3D.IDENTITY)
	var img := _viewport.get_texture().get_image()
	if img == null:
		return {}
	var px := int(round(screen_pos.x))
	var py := int(round(screen_pos.y))
	if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
		return {}
	var col := img.get_pixel(px, py)
	last_color = col
	last_image = img

	var idx := _decode(col)
	if idx < 0:
		return {}
	var rest: PackedVector3Array = target.get("rest_positions", PackedVector3Array())
	var world_pos := world_xf.origin
	if idx < rest.size():
		world_pos = world_xf * rest[idx]
	return {
		"hit": true,
		"render_vertex_index": idx,
		"triangle_index": -1,
		"barycentric": Vector3.ZERO,
		"world_pos": world_pos,
	}


## Decode an RGBA8-encoded id color → render-vertex index, or -1 for the background.
## The per-channel byte recovery (incl. the sRGB EOTF this build needs) is in _byte_from;
## the 24-bit index is reassembled low/mid/high from R/G/B.
func _decode(col: Color) -> int:
	# Background (clear) → miss. The shader writes ALPHA=1.0; the clear color is black-alpha,
	# so a < 0.5 is the background. (A real id 0 has black RGB but alpha 1 → still decodes 0.)
	if col.a < 0.5:
		return -1
	return _byte_from(col.r) + _byte_from(col.g) * 256 + _byte_from(col.b) * 65536


## One read channel float (0..1) → the stored byte (0..255). On this build the SubViewport
## sRGB-encodes the albedo, so we apply the sRGB→linear EOTF to recover the byte (see
## srgb_decode). Set srgb_decode=false for a raw build.
func _byte_from(c: float) -> int:
	var v := c
	if srgb_decode:
		v = (pow((c + 0.055) / 1.055, 2.4)) if c > 0.04045 else (c / 12.92)
	return int(round(clampf(v, 0.0, 1.0) * 255.0))


func _make_dummy() -> MeshInstance3D:
	return _id_mi if _id_mi != null else MeshInstance3D.new()


func _teardown() -> void:
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_id_cam = null
	_id_mi = null
	_id_mat = null
	_id_skel = null
	_holder = null
	_built = false
