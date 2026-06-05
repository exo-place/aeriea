## Sparse CPU delta-library builder — SLICE C of docs/decisions/body-parameterization.md
## (§1.3 macro factor-cube, §6 full registry-driven import, §8 converter changes).
##
## WHY a sparse library and NOT ~531+ GPU blendshapes: Godot stores each blendshape as a
## FULL-LENGTH per-vertex array (≈14.5k render verts × (vertex+normal)); ~531 detail
## blendshapes alone would be ~180 MB and is infeasible. The MakeHuman detail `.target`
## files are SPARSE (each moves only a small subset of verts), so we represent the entire
## library as a COMPACT SPARSE DELTA artifact: per target, only the MOVED render-vertex
## indices + their (dx,dy,dz) in METRES. It is applied through the EXISTING CPU morph path
## (BodyState.bake_morphed_normals / apply_morph_cpu), NOT as GPU blendshapes.
##
## The library carries TWO kinds of target:
##   1. DETAIL targets — every bidirectional/unipolar modifier the registry references
##      (the within-form envelope: nose/breast/genitals/jaw/limb/expression/…), keyed by
##      their `.target` file path (the same name BodyState._project_modifiers emits).
##   2. MACRO factor-cube targets:
##      - the CAUCASIAN race cube (`macrodetails/caucasian-*.target`, 8 files): the
##        race×gender×age SHAPE morph (baby/child/young/old, female/male). This is where
##        the actual age + sex body SHAPE lives in MakeHuman; race is pinned to caucasian
##        (caucasianVal=1) for the caucasian base, so it reduces to gender×age.
##      - the universal gender×age×muscle×weight cube (`macrodetails/universal-*.target`,
##        72 files): the muscle/weight VARIATION per gender×age.
##      Together these drive the §1.3 factor-PRODUCT macro projection (replacing the old
##      9-target linear shortcut) so COMBINED macro morphs compose correctly, not linearly.
##      - the FULL proportions cube (`macrodetails/proportions/`, 108 dense targets):
##        gender×age×muscle×weight×{ideal,uncommon}. These move most verts (DENSE), so they
##        grow the artifact by ~26 MB — ACCEPTED: correctness over artifact size. The prior
##        2-anchor approximation (one ideal + one uncommon target at the neutral build) is
##        RETIRED; proportions now composes by the SAME §1.3 factor-PRODUCT as the universal
##        cube, weighted by the {ideal,uncommon} proportions factor val (_setBodyProportionVals).
##      DELIBERATELY EXCLUDED:
##        - the HEIGHT macro cube (`height/`): §4 — height_cm is a UNIFORM SCALE,
##          orthogonal to proportions; MakeHuman's coupled height cube is dropped.
##        - the asian/african race cubes: caucasian-only base; race axis is out of scope.
##
## OUTPUTS (built by `nix build .#body-detail-library`; committed gzip-compressed):
##   res://assets/body/base_body_detail.bin       — the packed sparse delta blob
##   res://assets/body/base_body_detail.index.json — { path -> {offset, count, kind} } +
##                                                    base_height_cm + provenance
##
## BINARY FORMAT (little-endian, deterministic — same pinned input => identical bytes):
##   magic "ADLB" (4 bytes) | version u32 = 1 | target_count u32
##   then, per target IN INDEX ORDER, a packed run of `count` records:
##     render_vertex_index u32 | dx f32 | dy f32 | dz f32   (12+4 = 16 bytes/record)
##   Deltas are RENDER-vertex-keyed (already scattered across UV seams at build time, like
##   the GPU blendshapes), so runtime application is a trivial morphed[ri] += d*w with no
##   render_to_base map needed at runtime. Records within a target are ascending index.
##
## Run headless (pure text -> binary, no render):
##   MAKEHUMAN_SRC=/path/to/source godot4 --headless --path . \
##     res://tools/detail_library_build.tscn --quit-after 1200
## MAKEHUMAN_SRC unset falls back to the vendored CC0 subset (only the 9 macro targets are
## vendored, so the fetch-free build emits a TINY library — enough to exercise the path).
extends Node

const ModifierRegistry := preload("res://scripts/body/modifier_registry.gd")

## Same MH->m scale as tools/body_converter.gd (1u = 1m).
const MH_TO_METERS := 0.1

const OUT_DIR := "res://assets/body"
const OUT_BIN := "res://assets/body/base_body_detail.bin"
const OUT_INDEX := "res://assets/body/base_body_detail.index.json"

## Macro factor-cube target globs we import (relative to data/targets/). The universal
## cube = gender×age×muscle×weight (in macrodetails/). The FULL proportions cube =
## gender×age×muscle×weight×{ideal,uncommon} (108 dense targets in macrodetails/proportions/)
## is imported in full (§1.3 — correctness over artifact size; the prior 2-anchor approximation
## is retired). Height/race cubes stay excluded (see header / §4).
const MACRO_UNIVERSAL_DIR := "macrodetails"
const MACRO_PROPORTIONS_DIR := "macrodetails/proportions"


func _ready() -> void:
	get_tree().quit(_run())


func _src_data_root() -> String:
	var env := OS.get_environment("MAKEHUMAN_SRC")
	if env != "":
		return env.path_join("makehuman").path_join("data") if not env.ends_with("data") else env
	return ProjectSettings.globalize_path("res://vendor/makehuman-cc0/data")


func _run() -> int:
	var data_root := _src_data_root()
	print("detail_library_build: data root = %s" % data_root)

	# --- parse the base OBJ exactly as body_converter does (render verts + render_to_base
	# + the feet-to-origin min_y), so deltas are scattered onto the SAME render verts the
	# committed base_body.res carries. -------------------------------------------------
	var obj_path := data_root.path_join("3dobjs/base.obj")
	var parsed := _parse_obj(obj_path)
	if parsed.is_empty():
		push_error("detail_library_build: failed to parse %s" % obj_path)
		return 1
	var base_verts: PackedVector3Array = parsed["base_verts"]
	var render_pos: PackedVector3Array = parsed["render_pos"]
	var render_to_base: PackedInt32Array = parsed["render_to_base"]
	var body_vert_count: int = parsed["body_vert_count"]
	var rn := render_pos.size()
	print("detail_library_build: %d base verts, %d render verts" % [base_verts.size(), rn])

	# base height in cm (the SAME getHeightCm() computation MakeHuman uses: 10*bbox_y in
	# MH units == bbox_y_in_m * 100). Measured over BODY verts only (no helper proxies),
	# in the lifted+scaled render frame. This is the default height_cm anchor (§4).
	var min_y := INF
	var max_y := -INF
	for i in body_vert_count:
		var y := base_verts[i].y
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y)
	var base_height_cm := (max_y - min_y) * MH_TO_METERS * 100.0
	print("detail_library_build: base height = %.3f cm" % base_height_cm)

	# build render_to_base inverse: base vert -> list of render verts (for scatter).
	# NOTE: PackedInt32Array stored in a Dictionary is a VALUE — `dict[k].append()` mutates
	# a throwaway copy. Build plain Arrays, append, then store back per key.
	var base_to_render := {}
	for ri in rn:
		var b := render_to_base[ri]
		if not base_to_render.has(b):
			base_to_render[b] = []
		(base_to_render[b] as Array).append(ri)

	# --- collect the target file paths to import --------------------------------------
	# DETAIL targets: every bidirectional/unipolar modifier target the registry references.
	var registry := ModifierRegistry.parse(data_root)
	var detail_paths := {}   # rel path -> true (dedup; some targets shared)
	for e in registry["modifiers"]:
		if String(e["kind"]) == ModifierRegistry.KIND_MACRO:
			continue
		for t in e["targets"]:
			detail_paths[String(t["path"])] = true

	# MACRO cube targets: the universal + proportions cubes (NOT height/race).
	var macro_paths := _collect_macro_cube(data_root)

	# Deterministic INDEX ORDER: detail targets sorted, then macro targets sorted. Stable
	# across rebuilds => byte-identical artifact.
	var detail_sorted := detail_paths.keys()
	detail_sorted.sort()
	var macro_sorted := macro_paths
	macro_sorted.sort()

	# --- pack the binary blob ----------------------------------------------------------
	var blob := StreamPeerBuffer.new()
	blob.big_endian = false
	blob.put_u8(0x41); blob.put_u8(0x44); blob.put_u8(0x4C); blob.put_u8(0x42)  # "ADLB"
	blob.put_u32(1)  # version
	var total := detail_sorted.size() + macro_sorted.size()
	blob.put_u32(total)

	var index_entries := []   # {path, offset, count, kind}
	var data_start := blob.get_position()  # records begin after the header
	var imported := 0
	var skipped := 0

	for kind_list in [["detail", detail_sorted], ["macro", macro_sorted]]:
		var kind: String = kind_list[0]
		for rel in kind_list[1]:
			var tpath := data_root.path_join("targets").path_join(rel)
			var deltas := _parse_target(tpath)  # base index -> Vector3 (MH units)
			if deltas.is_empty():
				# Missing in the subset path (fetch-free dev): record with count 0 so the
				# index stays complete and deterministic; runtime treats it as a no-op.
				index_entries.append({"path": rel, "offset": blob.get_position(), "count": 0, "kind": kind})
				skipped += 1
				continue
			# scatter base-vert deltas onto render verts, ascending render index.
			var recs := []   # [ri, dx, dy, dz] in metres
			for b in deltas.keys():
				if not base_to_render.has(b):
					continue  # a helper/joint base vert not in the rendered body; skip
				var rlist: Array = base_to_render[b]
				var d: Vector3 = deltas[b]
				for ri in rlist:
					recs.append([ri, d.x * MH_TO_METERS, d.y * MH_TO_METERS, d.z * MH_TO_METERS])
			recs.sort_custom(func(a, b2): return a[0] < b2[0])
			var off := blob.get_position()
			for r in recs:
				blob.put_u32(int(r[0]))
				blob.put_float(float(r[1]))
				blob.put_float(float(r[2]))
				blob.put_float(float(r[3]))
			index_entries.append({"path": rel, "offset": off, "count": recs.size(), "kind": kind})
			imported += 1

	# `skipped` = targets with no body-render-vert deltas: either empty source targets (e.g.
	# the universal-*-averagemuscle-averageweight base anchors, which ARE the base, 0 deltas)
	# or targets that move only HELPER-proxy verts not in the rendered body group (e.g. the
	# genitals/ targets, which morph a separate genital proxy mesh MakeHuman's CC0 base does
	# not weld into the body group). Both are recorded with count 0 (no-op), not errors.
	print("detail_library_build: %d targets imported, %d empty/no-body-verts, blob %d bytes" % [imported, skipped, blob.get_size()])

	# --- write the blob ----------------------------------------------------------------
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var bf := FileAccess.open(OUT_BIN, FileAccess.WRITE)
	if bf == null:
		push_error("detail_library_build: cannot write %s" % OUT_BIN)
		return 1
	bf.store_buffer(blob.data_array)
	bf.flush()
	bf.close()
	print("detail_library_build: wrote %s" % OUT_BIN)

	# --- write the deterministic index JSON (hand-emitted, fixed key order) ------------
	var lines := PackedStringArray()
	lines.append("{")
	lines.append("\t\"_comment\": \"Generated by tools/detail_library_build.gd from MakeHuman CC0 targets. Sparse CPU delta library (NOT GPU blendshapes). DO NOT hand-edit; regenerate with `nix build .#body-detail-library`.\",")
	lines.append("\t\"license\": \"CC0-1.0 (MakeHuman core targets; LICENSE.ASSETS.md)\",")
	lines.append("\t\"source\": {\"owner\": \"makehumancommunity\", \"repo\": \"makehuman\", \"rev\": \"v1.3.0\", \"sha256\": \"sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=\"},")
	lines.append("\t\"format\": \"ADLB v1: LE; header magic+u32 version+u32 count; per target `count` records of (u32 render_vertex_index, f32 dx, f32 dy, f32 dz) in metres\",")
	lines.append("\t\"render_vertex_count\": %d," % rn)
	lines.append("\t\"base_height_cm\": %s," % ("%.6f" % base_height_cm))
	lines.append("\t\"data_offset\": %d," % data_start)
	lines.append("\t\"target_count\": %d," % total)
	lines.append("\t\"targets\": [")
	for i in index_entries.size():
		var e: Dictionary = index_entries[i]
		var row := "\t\t{\"path\": %s, \"kind\": %s, \"offset\": %d, \"count\": %d}" % [
			JSON.stringify(String(e["path"])), JSON.stringify(String(e["kind"])),
			int(e["offset"]), int(e["count"]),
		]
		if i < index_entries.size() - 1:
			row += ","
		lines.append(row)
	lines.append("\t]")
	lines.append("}")
	var text := "\n".join(lines) + "\n"
	var jf := FileAccess.open(OUT_INDEX, FileAccess.WRITE)
	if jf == null:
		push_error("detail_library_build: cannot write %s" % OUT_INDEX)
		return 1
	jf.store_string(text)
	jf.flush()
	jf.close()
	print("detail_library_build: wrote %s (%d targets)" % [OUT_INDEX, total])
	print("detail_library_build: DONE")
	return 0


## Collect the macro factor-cube target rel-paths: the universal cube (gender×age×muscle×
## weight) + the CAUCASIAN race (age/gender shape) cube + the FULL proportions cube
## (gender×age×muscle×weight×{ideal,uncommon}, 108 dense targets). Height/race(asian/african)
## excluded.
func _collect_macro_cube(data_root: String) -> Array:
	var out := []
	var udir := data_root.path_join("targets").path_join(MACRO_UNIVERSAL_DIR)
	var ud := DirAccess.open(udir)
	if ud != null:
		ud.list_dir_begin()
		var name := ud.get_next()
		while name != "":
			# the universal muscle/weight cube + the CAUCASIAN race (age/gender shape) cube.
			if not ud.current_is_dir() and (name.begins_with("universal-") or name.begins_with("caucasian-")) and name.ends_with(".target"):
				out.append("%s/%s" % [MACRO_UNIVERSAL_DIR, name])
			name = ud.get_next()
		ud.list_dir_end()
	# the FULL proportions factor-cube (every gender×age×muscle×weight×{ideal,uncommon}).
	var pdir := data_root.path_join("targets").path_join(MACRO_PROPORTIONS_DIR)
	var pd := DirAccess.open(pdir)
	if pd != null:
		pd.list_dir_begin()
		var pname := pd.get_next()
		while pname != "":
			if not pd.current_is_dir() and pname.ends_with(".target"):
				out.append("%s/%s" % [MACRO_PROPORTIONS_DIR, pname])
			pname = pd.get_next()
		pd.list_dir_end()
	return out


# ---------------------------------------------------------------------------
# OBJ + target parsers — DUPLICATED from tools/body_converter.gd (kept in lockstep so the
# render-vertex layout is IDENTICAL to the committed base_body.res). Only the body-group
# corner-expansion + render_to_base are needed here (no normals/skin/rig).
# ---------------------------------------------------------------------------
const BODY_GROUP := "body"

func _parse_obj(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("detail_library_build: cannot open OBJ %s (err %d)" % [path, FileAccess.get_open_error()])
		return {}
	var base_verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var render_pos := PackedVector3Array()
	var render_to_base := PackedInt32Array()
	var tris := PackedInt32Array()
	var corner_to_render := {}
	var in_body := false
	var body_faces := 0

	var corner := func(tok: String) -> int:
		var parts := tok.split("/")
		var vi := int(parts[0].to_int() - 1)
		var ti := -1
		if parts.size() >= 2 and parts[1] != "":
			ti = int(parts[1].to_int() - 1)
		var key := vi * 2000000 + (ti + 1)
		var existing = corner_to_render.get(key, -1)
		if existing != -1:
			return existing
		var ri := render_pos.size()
		render_pos.append(base_verts[vi])
		render_to_base.append(vi)
		corner_to_render[key] = ri
		return ri

	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("v "):
			var p := line.split(" ", false)
			base_verts.append(Vector3(p[1].to_float(), p[2].to_float(), p[3].to_float()))
		elif line.begins_with("vt "):
			var p := line.split(" ", false)
			uvs.append(Vector2(p[1].to_float(), p[2].to_float()))
		elif line.begins_with("g "):
			var p := line.split(" ", false)
			in_body = p.size() >= 2 and p[1] == BODY_GROUP
		elif line.begins_with("f "):
			if not in_body:
				continue
			var p := line.split(" ", false)
			var c := PackedInt32Array()
			for i in range(1, p.size()):
				c.append(corner.call(p[i]))
			if c.size() == 4:
				tris.append(c[0]); tris.append(c[2]); tris.append(c[1])
				tris.append(c[0]); tris.append(c[3]); tris.append(c[2])
				body_faces += 1
			elif c.size() == 3:
				tris.append(c[0]); tris.append(c[2]); tris.append(c[1])
				body_faces += 1
	f.close()
	if base_verts.is_empty() or body_faces == 0:
		push_error("detail_library_build: no `g %s` faces in %s" % [BODY_GROUP, path])
		return {}
	var body_base_vmax := -1
	for b in render_to_base:
		body_base_vmax = maxi(body_base_vmax, b)
	return {
		"base_verts": base_verts,
		"render_pos": render_pos,
		"render_to_base": render_to_base,
		"body_vert_count": body_base_vmax + 1,
	}


func _parse_target(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var out := {}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var p := line.split(" ", false)
		if p.size() < 4:
			continue
		out[p[0].to_int()] = Vector3(p[1].to_float(), p[2].to_float(), p[3].to_float())
	f.close()
	return out
