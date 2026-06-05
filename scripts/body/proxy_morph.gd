## ProxyMorph — runtime morph + normal bake for the EYE/TEETH/TONGUE/GENITAL proxy
## pieces (built by tools/body_proxy_build.gd).
##
## The proxy mesh (base_body_proxies.res) carries ONE SURFACE per piece. The proxy
## delta library (base_body_proxies_detail.{bin,index.json}) carries, per macro/detail
## target, the per-proxy-render-vertex displacement keyed by a GLOBAL proxy-vertex index
## that spans all surfaces (surface i's verts occupy [vert_offset, vert_offset+vert_count)).
##
## This loader resolves a BodyState's per-target weights (the SAME to_blend_weights()
## projection the body uses) into morphed positions per surface, then recomputes OUTWARD
## normals (same convention as the body) and bakes BOTH into the per-instance proxy mesh.
## So the eyes/teeth/tongue/genitals follow EXACTLY the macro + detail morphs the body
## follows, through the SAME barycentric deltas — they stay seated and lit under morph.
##
## Determinism: deltas are applied in sorted-key order; normals are area-weighted over
## the surface triangles. Same BodyState -> same baked proxy mesh.
class_name ProxyMorph
extends RefCounted

const MESH_PATH := "res://assets/body/base_body_proxies.res"
const INDEX_PATH := "res://assets/body/base_body_proxies.index.json"
const DETAIL_INDEX_PATH := "res://assets/body/base_body_proxies_detail.index.json"
const DETAIL_BIN_PATH := "res://assets/body/base_body_proxies_detail.bin"
const RECORD_STRIDE := 16

# --- static cache (one parse per process; small artifacts) ------------------
static var _loaded := false
static var _surfaces := []          ## [{name, material, vert_offset, vert_count}]
static var _index := {}             ## target path -> {offset, count}
static var _bytes := PackedByteArray()


static func ensure_loaded() -> bool:
	if _loaded:
		return not _surfaces.is_empty()
	_loaded = true
	# surface table
	var sf := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if sf == null:
		return false
	var sdata = JSON.parse_string(sf.get_as_text())
	sf.close()
	if typeof(sdata) != TYPE_DICTIONARY or not sdata.has("surfaces"):
		return false
	for e in sdata["surfaces"]:
		_surfaces.append({
			"name": String(e["name"]), "material": String(e["material"]),
			"vert_offset": int(e["vert_offset"]), "vert_count": int(e["vert_count"]),
		})
	# delta index + blob (optional — absent => no morph, pieces still render at neutral)
	var jf := FileAccess.open(DETAIL_INDEX_PATH, FileAccess.READ)
	if jf != null:
		var jdata = JSON.parse_string(jf.get_as_text())
		jf.close()
		if typeof(jdata) == TYPE_DICTIONARY and jdata.has("targets"):
			for e in jdata["targets"]:
				_index[String(e["path"])] = {"offset": int(e["offset"]), "count": int(e["count"])}
			var bf := FileAccess.open(DETAIL_BIN_PATH, FileAccess.READ)
			if bf != null:
				_bytes = bf.get_buffer(bf.get_length())
				bf.close()
	return not _surfaces.is_empty()


## The surface table ({name, material, vert_offset, vert_count}). Empty if no artifact.
static func surfaces() -> Array:
	ensure_loaded()
	return _surfaces


## Bake `state`'s morph onto `mesh_instance` (whose mesh is a per-instance copy of the
## proxy ArrayMesh). For each surface: morphed = neutral_base + Σ wᵢ·Δᵢ (global indices
## restricted to that surface), then recompute outward normals; write both back.
## The neutral base positions per surface are captured once into instance metadata so
## repeated calls are stable (non-cumulative), mirroring BodyState.apply_morph_cpu.
static func apply(state: BodyState, mesh_instance: MeshInstance3D) -> void:
	if not ensure_loaded():
		return
	var mesh := mesh_instance.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var weights := state.to_blend_weights()   # { target_path: weight } — same as the body
	# capture neutral base positions per surface once
	var neutral: Array
	if mesh_instance.has_meta("proxy_neutral_pos"):
		neutral = mesh_instance.get_meta("proxy_neutral_pos")
	else:
		neutral = []
		for si in mesh.get_surface_count():
			neutral.append(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
		mesh_instance.set_meta("proxy_neutral_pos", neutral)

	var sorted_keys := weights.keys()
	sorted_keys.sort()

	# Compute every surface's morphed arrays FIRST, then rebuild the mesh ONCE (ArrayMesh
	# has no per-surface in-place replace that preserves the others, so we snapshot + clear
	# + re-add in index order — surfaces keep their index, deterministic).
	var snaps := []
	for si in mesh.get_surface_count():
		var surf: Dictionary = _surfaces[si] if si < _surfaces.size() else {"vert_offset": 0, "vert_count": 0}
		var voff: int = surf["vert_offset"]
		var vcount: int = surf["vert_count"]
		var arrays := mesh.surface_get_arrays(si)
		var base_pos: PackedVector3Array = neutral[si]
		var morphed := base_pos.duplicate()
		var n := morphed.size()
		for k in sorted_keys:
			var entry = _index.get(String(k), null)
			if entry == null:
				continue
			var count: int = entry["count"]
			if count == 0:
				continue
			var w := float(weights[k])
			if absf(w) < 1e-6:
				continue
			var pos: int = entry["offset"]
			for _i in count:
				var gri := _bytes.decode_u32(pos)
				var dx := _bytes.decode_float(pos + 4)
				var dy := _bytes.decode_float(pos + 8)
				var dz := _bytes.decode_float(pos + 12)
				pos += RECORD_STRIDE
				var li := gri - voff
				if li >= 0 and li < vcount and li < n:
					morphed[li] = morphed[li] + Vector3(dx, dy, dz) * w
		# outward area-weighted normals — SAME convention as the body ((c-a)×(b-a)).
		var tris: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normals := PackedVector3Array(); normals.resize(n)
		for i in n:
			normals[i] = Vector3.ZERO
		var t := 0
		while t < tris.size():
			var a := tris[t]; var b := tris[t + 1]; var c := tris[t + 2]
			var fn := (morphed[c] - morphed[a]).cross(morphed[b] - morphed[a])
			normals[a] += fn; normals[b] += fn; normals[c] += fn
			t += 3
		for i in n:
			var ln := normals[i]
			normals[i] = ln.normalized() if ln.length() > 1e-9 else Vector3.UP
		arrays[Mesh.ARRAY_VERTEX] = morphed
		arrays[Mesh.ARRAY_NORMAL] = normals
		snaps.append({"arrays": arrays, "name": mesh.surface_get_name(si), "fmt": mesh.surface_get_format(si)})

	mesh.clear_surfaces()
	for s in snaps:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s["arrays"], [], {}, s["fmt"])
		mesh.surface_set_name(mesh.get_surface_count() - 1, s["name"])
