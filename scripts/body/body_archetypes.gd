## BodyArchetypes — the first-party archetype roster + loader (Phase 3b, SYNTHESIS §2.1).
##
## An ARCHETYPE = a frozen, serializable BodyState (data over code at a faithful seam):
## the six headline axes + a curated sparse `modifiers` map, shipped as a small JSON file
## under `assets/body/archetypes/*.json` and (de)serialized through BodyState.to_dict /
## from_dict. T0 of the progressive-refine model is a PICK GRID over this roster; picking
## one loads its BodyState via the RAW restore path (Phase-1 raw/restore semantics).
##
## TWO DISTINCT LOAD PATHS (§2.1): a first-party archetype MUST be authored within every
## control's DEFAULT cap interval cap(control, 0) — build gate #11a (validate_archetype_
## containment in BodyCaps) FAILS THE BUILD if any shipped archetype is out of default
## intervals. Because an archetype is within [a,b] by construction, loading it raw at
## extremeness 0 is identical to loading it through the capped choke — so it uses the raw
## load path with no special clamp, and the build gate is what makes raw == capped.
##
## "Save as archetype" (user artifact) is a SEPARATE path (raw-preserve, may be beyond
## cap) and is NOT subject to gate #11a — only the shipped roster is.
class_name BodyArchetypes
extends RefCounted

## The directory the first-party roster lives in (scanned at load).
const ROSTER_DIR := "res://assets/body/archetypes"

## Family ordering for the pick grid (display order). Unknown families sort last.
const FAMILY_ORDER := ["feminine", "androgynous", "masculine"]


## Load every first-party archetype JSON under ROSTER_DIR. Returns a list of dicts:
##   { name, family, build, state: <BodyState dict>, path }
## `state` is the BodyState-shaped dict (to_dict / from_dict compatible) — i.e. the headline
## fields + the optional `modifiers` map, WITHOUT the descriptive name/family/build/_comment
## keys (those are roster metadata, not body state). Sorted by (family order, build, name).
static func load_roster() -> Array:
	var out := []
	var dir := DirAccess.open(ROSTER_DIR)
	if dir == null:
		push_error("BodyArchetypes: cannot open roster dir %s" % ROSTER_DIR)
		return out
	var files := dir.get_files()
	# Sort filenames first for a deterministic base order (the roster sort re-orders below).
	var names := []
	for f in files:
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f in names:
		var entry := _load_one("%s/%s" % [ROSTER_DIR, f])
		if not entry.is_empty():
			out.append(entry)
	out.sort_custom(_compare_entries)
	return out


## The BodyState-shaped dicts only (gate #11a feeds these to validate_archetype_containment).
static func roster_states() -> Array:
	var out := []
	for e in load_roster():
		out.append(e["state"])
	return out


static func _load_one(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("BodyArchetypes: cannot open %s" % path)
		return {}
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("BodyArchetypes: %s did not parse to a dict" % path)
		return {}
	var d: Dictionary = data
	# Strip the roster-metadata keys; what remains is the BodyState dict (to_dict shape).
	var state := {}
	for k in d:
		if k == "name" or k == "family" or k == "build" or k.begins_with("_"):
			continue
		state[k] = d[k]
	return {
		"name": String(d.get("name", path.get_file().get_basename())),
		"family": String(d.get("family", "")),
		"build": String(d.get("build", "")),
		"state": state,
		"path": path,
	}


static func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var fa := FAMILY_ORDER.find(String(a["family"]))
	var fb := FAMILY_ORDER.find(String(b["family"]))
	if fa < 0:
		fa = FAMILY_ORDER.size()
	if fb < 0:
		fb = FAMILY_ORDER.size()
	if fa != fb:
		return fa < fb
	if String(a["build"]) != String(b["build"]):
		return String(a["build"]) < String(b["build"])
	return String(a["name"]) < String(b["name"])
