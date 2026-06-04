## DetailLibrary — the runtime loader for the SPARSE CPU DELTA LIBRARY (Slice C of
## docs/decisions/body-parameterization.md). It memory-maps the compact binary artifact
## built by tools/detail_library_build.gd and resolves a target file path -> its sparse
## per-render-vertex deltas, so BodyState.bake_morphed_normals can apply the full ~531-
## target detail envelope + the macro factor-cube through the EXISTING CPU morph path
## without ~531 GPU blendshapes (which would be ~180 MB; see the build tool header).
##
## ARTIFACT (assets/body/base_body_detail.{bin,index.json}):
##   - .index.json: { targets: [ {path, kind, offset, count}, ... ], render_vertex_count,
##                    base_height_cm, ... } — the deterministic table of contents.
##   - .bin: ADLB v1 blob; per target a run of `count` records (u32 render_vertex_index,
##           f32 dx, f32 dy, f32 dz) in METRES, at byte `offset`.
##
## Loaded ONCE per process (static cache). A target weight is applied as
## morphed[render_vertex_index] += delta * weight — pure, deterministic, additive.
class_name DetailLibrary
extends RefCounted

const INDEX_PATH := "res://assets/body/base_body_detail.index.json"
const BIN_PATH := "res://assets/body/base_body_detail.bin"

## Record stride in bytes: u32 index + 3×f32 = 16.
const RECORD_STRIDE := 16

static var _loaded := false
static var _index := {}          ## target path -> {offset:int, count:int, kind:String}
static var _bytes := PackedByteArray()
static var _base_height_cm := 0.0
static var _render_vertex_count := 0


## Load the library (idempotent). Returns true if a non-empty library is present. A
## missing artifact is NOT an error — detail morphs simply become no-ops (the macro
## headline axes still work through their own anchors).
static func ensure_loaded() -> bool:
	if _loaded:
		return not _index.is_empty()
	_loaded = true
	var jf := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if jf == null:
		return false
	var data = JSON.parse_string(jf.get_as_text())
	jf.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("targets"):
		return false
	_base_height_cm = float(data.get("base_height_cm", 0.0))
	_render_vertex_count = int(data.get("render_vertex_count", 0))
	for e in data["targets"]:
		_index[String(e["path"])] = {
			"offset": int(e["offset"]), "count": int(e["count"]), "kind": String(e["kind"]),
		}
	var bf := FileAccess.open(BIN_PATH, FileAccess.READ)
	if bf == null:
		_index = {}
		return false
	_bytes = bf.get_buffer(bf.get_length())
	bf.close()
	return not _index.is_empty()


## The base mesh height in cm (the natural getHeightCm of the neutral build). The default
## height_cm anchor and the divisor for the §4 uniform-scale factor. 0 if no library.
static func base_height_cm() -> float:
	ensure_loaded()
	return _base_height_cm


## True iff the library knows this target path (whether or not it has any deltas).
static func has_target(path: String) -> bool:
	ensure_loaded()
	return _index.has(path)


## Apply target `path` at `weight` onto `morphed` (a PackedVector3Array of render-vertex
## positions, mutated in place): morphed[ri] += delta_ri * weight, for each stored record.
## A near-zero weight or unknown/empty target is a no-op. Reads the packed records directly
## from the byte buffer (no per-call allocation of the full delta array).
static func apply(path: String, weight: float, morphed: PackedVector3Array) -> void:
	if absf(weight) < 1e-6:
		return
	ensure_loaded()
	var entry = _index.get(path, null)
	if entry == null:
		return
	var count: int = entry["count"]
	if count == 0:
		return
	var pos: int = entry["offset"]
	var n := morphed.size()
	for i in count:
		var ri := _bytes.decode_u32(pos)
		var dx := _bytes.decode_float(pos + 4)
		var dy := _bytes.decode_float(pos + 8)
		var dz := _bytes.decode_float(pos + 12)
		pos += RECORD_STRIDE
		if ri >= 0 and ri < n:
			morphed[ri] = morphed[ri] + Vector3(dx, dy, dz) * weight


## All target paths of a given kind ("macro" | "detail"), sorted (deterministic iteration).
static func paths_of_kind(kind: String) -> PackedStringArray:
	ensure_loaded()
	var out := PackedStringArray()
	var keys := _index.keys()
	keys.sort()
	for k in keys:
		if String(_index[k]["kind"]) == kind:
			out.append(String(k))
	return out


## Test/diagnostic: the moved-record count for a target path (-1 if unknown).
static func record_count(path: String) -> int:
	ensure_loaded()
	var entry = _index.get(path, null)
	return int(entry["count"]) if entry != null else -1


## Test/diagnostic: the i-th record of a target as [render_index, Vector3 delta], or
## [] if out of range. Lets tests assert a sample delta matches the source .target.
static func record_at(path: String, i: int) -> Array:
	ensure_loaded()
	var entry = _index.get(path, null)
	if entry == null or i < 0 or i >= int(entry["count"]):
		return []
	var pos: int = int(entry["offset"]) + i * RECORD_STRIDE
	return [
		_bytes.decode_u32(pos),
		Vector3(_bytes.decode_float(pos + 4), _bytes.decode_float(pos + 8), _bytes.decode_float(pos + 12)),
	]
