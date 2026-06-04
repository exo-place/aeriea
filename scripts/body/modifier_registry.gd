## ModifierRegistry — the DATA-DRIVEN MakeHuman modifier registry parser (Slice B of
## docs/decisions/body-parameterization.md §6).
##
## MakeHuman ships its body-morph axes as DATA: data/modifiers/*.json. Rather than
## hand-list a fraction of the targets in code (the Slice-1 `AXIS_TARGETS` shortcut in
## tools/body_converter.gd — "prefer data over code at every seam", "collapse N special
## cases to their primitive", CLAUDE.md), we PARSE that JSON into a registry. Each
## modifier becomes one registry entry keyed by its stable `fullName` "<group>/<name>".
##
## This is a PURE parser: text in -> registry Dictionary out. Deterministic (source
## order preserved within each group; groups in file order; files in a fixed order), so
## the emitted manifest is byte-identical on every rebuild — the project's "serializable
## over closures / artifacts cache, replay, diff" seam (CLAUDE.md). It is used by BOTH
## the build-time converter (tools/modifier_registry_build.gd, which writes the
## manifest) AND runtime/tests (which can re-parse the vendored JSON directly).
##
## SCHEMA (verified against the nix-pinned MakeHuman v1.3.0 source,
## apps/humanmodifier.py:loadModifiers / UniversalModifier / MacroModifier, and the
## body-parameterization.md §1.2 [V] schema):
##
## A modifier file is a JSON ARRAY of GROUPS. Each group is
##   {"group": "<name>", "modifiers": [<modifier-def>, ...]}.
## A modifier-def is exactly one of three shapes:
##
##   1. BIDIRECTIONAL  {"target": "<t>", "min": "<lo>", "max": "<hi>"}
##        UniversalModifier with both extensions. name = "<t>-<lo>|<hi>".
##        Two target files: <group>/<t>-<lo>.target and <group>/<t>-<hi>.target.
##        Value axis [-1, +1], default 0 (0 = base mesh). v<0 drives neg by -v;
##        v>0 drives pos by v (verbatim getFactors: factors[left]=-min(v,0),
##        factors[right]=max(0,v)).
##
##   2. UNIPOLAR  {"target": "<t>"}
##        UniversalModifier, no extensions. name = "<t>". One target file
##        <group>/<t>.target. Value axis [0, 1], default 0.
##
##   3. MACRO  {"macrovar": "<Var>"}  (optionally {"modifierType": "EthnicModifier"})
##        MacroModifier. name = "<Var>". Drives NO single target — it sets a macro
##        variable that recombines a whole factor-product target cube (§1.3), handled
##        by the converter's macro projection, NOT as a raw blendshape. Default 0.5
##        (EthnicModifier default 1/3). Value clamped [0, 1].
##
## A per-def `defaultValue` key overrides the class default (verbatim loadModifiers).
## There are NO numeric range keys in the data — the range is IMPLIED BY KIND.
##
## fullName = "<group>/<name>" (verbatim Modifier.fullName), the stable registry key.
##
## TARGET FILE RESOLUTION. The literal `.target` file for a modifier lives at
## "<group>/<target>[-<ext>].target" relative to data/targets/ — verified against the
## pinned tree (e.g. nose/nose-hump-decr.target, head/head-oval.target,
## measure/measure-neck-circ-decr.target, breast/breast-dist-incr.target). (The loader's
## internal `targetName = group + "-" + target` is the TOKEN-SET group key used by
## lib/targets.py's crawler for de-duplicated lookup; the on-disk path is the simple
## "<group>/<target>[-<ext>]" form, which is what we record.)
##
## SUBSET-PRESENCE FLAGGING (Slice B). The vendored CC0 subset (vendor/makehuman-cc0/)
## carries only a handful of macro targets, not the full 1,280-target detail set (that
## is Slice C). So most detail modifiers' target FILES are not present yet. The registry
## still PARSES and REGISTERS every modifier (the JSON is fully vendored), and flags each
## resolved target with `present`/`missing` against the target root it is given. A
## missing target is NOT an error — it is "Slice C supplies it later". Macro modifiers
## carry no single target to resolve, so they are never flagged missing.
class_name ModifierRegistry
extends RefCounted

## The three modifier-def kinds (string tags, stable in the emitted manifest).
const KIND_BIDIRECTIONAL := "bidirectional"
const KIND_UNIPOLAR := "unipolar"
const KIND_MACRO := "macro"

## The verified class defaults (apps/humanmodifier.py). Unipolar/bidirectional 0;
## macro 0.5; EthnicModifier 1/3.
const DEFAULT_UNIVERSAL := 0.0
const DEFAULT_MACRO := 0.5
const DEFAULT_ETHNIC := 1.0 / 3.0

## The modifier-definition files we parse, in a FIXED order (determinism). Each entry is
## [modifiers_json, sliders_json, desc_json] — basenames under a modifiers/ dir. The
## sliders/desc companions are optional joins (UI tab/label tree, tooltips).
const MODIFIER_FILES := [
	["modeling_modifiers.json", "modeling_sliders.json", "modeling_modifiers_desc.json"],
	["measurement_modifiers.json", "measurement_sliders.json", "measurement_modifiers_desc.json"],
	["bodyshapes_modifiers.json", "bodyshapes_sliders.json", "bodyshapes_modifiers_desc.json"],
]


## Parse the full registry from a MakeHuman data root (the dir holding modifiers/ and
## targets/). Returns a Dictionary:
##   {
##     "modifiers": [ <entry>, ... ],          # in deterministic parse order
##     "by_full_name": { "<group>/<name>": <entry> },
##     "counts": { "total":N, "bidirectional":N, "unipolar":N, "macro":N,
##                 "targets_present":N, "targets_missing":N },
##   }
## where each <entry> is (see _build_entry):
##   {
##     full_name, group, name, kind,
##     targets: [ {ext, path, present}, ... ],   # [] for macro
##     macrovar: "<Var>"|"",                       # "" for non-macro
##     default, range: [lo, hi],
##     tab, slider_group, label, camera, tooltip,
##   }
## `data_root` is e.g. res://vendor/makehuman-cc0/data — modifiers under
## <data_root>/modifiers, targets under <data_root>/targets.
static func parse(data_root: String) -> Dictionary:
	var modifiers_dir := data_root.path_join("modifiers")
	var targets_dir := data_root.path_join("targets")
	return parse_dirs(modifiers_dir, targets_dir)


## Parse from explicit modifiers/ and targets/ dirs (the path-flexible core). `targets_dir`
## is used only for presence-flagging; pass "" to skip flagging (all `present` = false).
static func parse_dirs(modifiers_dir: String, targets_dir: String) -> Dictionary:
	var entries := []
	var by_full_name := {}
	for triple in MODIFIER_FILES:
		var mod_path := modifiers_dir.path_join(triple[0])
		if not FileAccess.file_exists(mod_path):
			continue  # a file may be absent in a minimal subset; skip, do not error
		var groups := _read_json_array(mod_path)
		var sliders := _read_sliders(modifiers_dir.path_join(triple[1]))
		var descs := _read_json_dict(modifiers_dir.path_join(triple[2]))
		for group_def in groups:
			if typeof(group_def) != TYPE_DICTIONARY:
				continue
			var group_name := String(group_def.get("group", ""))
			var mods = group_def.get("modifiers", [])
			if typeof(mods) != TYPE_ARRAY:
				continue
			for m_def in mods:
				if typeof(m_def) != TYPE_DICTIONARY:
					continue
				var entry := _build_entry(group_name, m_def, targets_dir, sliders, descs)
				entries.append(entry)
				by_full_name[entry["full_name"]] = entry

	var counts := {
		"total": entries.size(),
		"bidirectional": 0, "unipolar": 0, "macro": 0,
		"targets_present": 0, "targets_missing": 0,
	}
	for e in entries:
		counts[e["kind"]] += 1
		for t in e["targets"]:
			if t["present"]:
				counts["targets_present"] += 1
			else:
				counts["targets_missing"] += 1
	return {"modifiers": entries, "by_full_name": by_full_name, "counts": counts}


## Build one registry entry from a group name + a single modifier-def Dictionary.
## Pure; the §1.2 schema is applied verbatim. `sliders` is the joined slider tree
## (fullName -> {tab, group, label, camera}); `descs` is fullName -> tooltip string.
static func _build_entry(group_name: String, m_def: Dictionary, targets_dir: String, sliders: Dictionary, descs: Dictionary) -> Dictionary:
	var kind := ""
	var name := ""
	var macrovar := ""
	var targets := []
	var default_val := 0.0
	var rng := [0.0, 1.0]

	if m_def.has("macrovar"):
		# --- MACRO modifier ---
		kind = KIND_MACRO
		macrovar = String(m_def["macrovar"])
		name = macrovar
		var is_ethnic := String(m_def.get("modifierType", "")) == "EthnicModifier"
		default_val = DEFAULT_ETHNIC if is_ethnic else DEFAULT_MACRO
		rng = [0.0, 1.0]
		# Macro modifiers drive a factor-product target cube, not a single file — no
		# target path to resolve or flag (§1.3 / §6).
	else:
		var target := String(m_def.get("target", ""))
		var has_min := m_def.has("min")
		var has_max := m_def.has("max")
		if has_min and has_max:
			# --- BIDIRECTIONAL ---
			kind = KIND_BIDIRECTIONAL
			var lo := String(m_def["min"])
			var hi := String(m_def["max"])
			name = "%s-%s|%s" % [target, lo, hi]
			default_val = DEFAULT_UNIVERSAL
			rng = [-1.0, 1.0]
			targets.append(_resolve_target(group_name, target, lo, "min", targets_dir))
			targets.append(_resolve_target(group_name, target, hi, "max", targets_dir))
		else:
			# --- UNIPOLAR ---
			kind = KIND_UNIPOLAR
			name = target
			default_val = DEFAULT_UNIVERSAL
			rng = [0.0, 1.0]
			targets.append(_resolve_target(group_name, target, "", "", targets_dir))

	# Per-def defaultValue override (verbatim loadModifiers).
	if m_def.has("defaultValue"):
		default_val = float(m_def["defaultValue"])

	var full_name := "%s/%s" % [group_name, name]
	var ui: Dictionary = sliders.get(full_name, {})
	return {
		"full_name": full_name,
		"group": group_name,
		"name": name,
		"kind": kind,
		"macrovar": macrovar,
		"targets": targets,
		"default": default_val,
		"range": rng,
		"tab": String(ui.get("tab", "")),
		"slider_group": String(ui.get("group", "")),
		"label": String(ui.get("label", "")),
		"camera": String(ui.get("camera", "")),
		"tooltip": String(descs.get(full_name, "")),
	}


## Resolve a modifier target to its on-disk .target file path + presence flag. `ext` is
## the min/max extension suffix ("" for unipolar); `which` is "min"/"max"/"" (recorded so
## the caller knows which pole this file is). The path is relative to the targets root:
## "<group>/<target>[-<ext>].target".
static func _resolve_target(group: String, target: String, ext: String, which: String, targets_dir: String) -> Dictionary:
	var rel := "%s/%s.target" % [group, target] if ext == "" else "%s/%s-%s.target" % [group, target, ext]
	var present := false
	if targets_dir != "":
		present = FileAccess.file_exists(targets_dir.path_join(rel))
	return {"which": which, "ext": ext, "path": rel, "present": present}


# ---------------------------------------------------------------------------
# Companion-file readers. The *_sliders.json UI tree and *_modifiers_desc.json tooltip
# map are flattened to fullName-keyed Dictionaries for a cheap join in _build_entry.
# ---------------------------------------------------------------------------

## Flatten a *_sliders.json UI tree to { "<fullName>": {tab, group, label, camera} }.
## The tree is { "<Tab>": { ...meta, "modifiers": { "<sub-group>": [ {"mod":fn, "label",
## "cam"}, ... ] } } } (verified). `mod` is the fullName; `label`/`cam` are optional.
static func _read_sliders(path: String) -> Dictionary:
	var out := {}
	var root := _read_json_dict(path)
	for tab_name in root:
		var tab = root[tab_name]
		if typeof(tab) != TYPE_DICTIONARY:
			continue
		var groups = tab.get("modifiers", {})
		if typeof(groups) != TYPE_DICTIONARY:
			continue
		for group_label in groups:
			var sliders = groups[group_label]
			if typeof(sliders) != TYPE_ARRAY:
				continue
			for s in sliders:
				if typeof(s) != TYPE_DICTIONARY or not s.has("mod"):
					continue
				var fn := String(s["mod"])
				out[fn] = {
					"tab": String(tab_name),
					"group": String(group_label),
					"label": String(s.get("label", "")),
					"camera": String(s.get("cam", "")),
				}
	return out


static func _read_json_array(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if typeof(data) == TYPE_ARRAY else []


static func _read_json_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if typeof(data) == TYPE_DICTIONARY else {}


# ---------------------------------------------------------------------------
# Manifest serialization. The registry is emitted as a DETERMINISTIC JSON artifact
# (assets/body/modifier_registry.json) so runtime BodyState can resolve fullName ->
# target(s) without re-parsing the MakeHuman source. Byte-stable: entries in parse
# order, object keys hand-emitted in a fixed order, floats fixed-format (the same
# discipline tools/body_converter.gd uses for the rig JSON).
# ---------------------------------------------------------------------------

## Serialize a parsed registry (the parse() result) to the canonical manifest JSON STRING.
## Deterministic & byte-stable: same registry -> identical bytes.
static func to_manifest_string(registry: Dictionary, provenance: Dictionary = {}) -> String:
	var entries: Array = registry.get("modifiers", [])
	var counts: Dictionary = registry.get("counts", {})
	var lines := PackedStringArray()
	lines.append("{")
	lines.append("\t\"_comment\": \"Generated by tools/modifier_registry_build.gd via scripts/body/modifier_registry.gd from the MakeHuman CC0 modifier JSON. DO NOT hand-edit; regenerate with `nix build .#modifier-registry`.\",")
	lines.append("\t\"license\": \"CC0-1.0 (MakeHuman targets & modifiers; LICENSE.md §C / LICENSE.ASSETS.md)\",")
	lines.append("\t\"source\": {")
	lines.append("\t\t\"owner\": %s," % JSON.stringify(String(provenance.get("owner", "makehumancommunity"))))
	lines.append("\t\t\"repo\": %s," % JSON.stringify(String(provenance.get("repo", "makehuman"))))
	lines.append("\t\t\"rev\": %s," % JSON.stringify(String(provenance.get("rev", "v1.3.0"))))
	lines.append("\t\t\"sha256\": %s" % JSON.stringify(String(provenance.get("sha256", "sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4="))))
	lines.append("\t},")
	lines.append("\t\"counts\": {")
	lines.append("\t\t\"total\": %d," % int(counts.get("total", 0)))
	lines.append("\t\t\"bidirectional\": %d," % int(counts.get("bidirectional", 0)))
	lines.append("\t\t\"unipolar\": %d," % int(counts.get("unipolar", 0)))
	lines.append("\t\t\"macro\": %d," % int(counts.get("macro", 0)))
	lines.append("\t\t\"targets_present\": %d," % int(counts.get("targets_present", 0)))
	lines.append("\t\t\"targets_missing\": %d" % int(counts.get("targets_missing", 0)))
	lines.append("\t},")
	lines.append("\t\"modifiers\": [")
	for i in entries.size():
		lines.append(_entry_to_json_line(entries[i], i < entries.size() - 1))
	lines.append("\t]")
	lines.append("}")
	return "\n".join(lines) + "\n"


## Emit one modifier entry as a single deterministic JSON line (fixed key order, fixed
## float format). `comma` appends a trailing comma for all but the last entry.
static func _entry_to_json_line(e: Dictionary, comma: bool) -> String:
	var tparts := PackedStringArray()
	for t in e["targets"]:
		tparts.append("{\"which\": %s, \"path\": %s, \"present\": %s}" % [
			JSON.stringify(String(t["which"])), JSON.stringify(String(t["path"])),
			"true" if t["present"] else "false",
		])
	var targets_json := "[%s]" % ", ".join(tparts)
	var rng: Array = e["range"]
	var row := "\t\t{\"full_name\": %s, \"group\": %s, \"name\": %s, \"kind\": %s, \"macrovar\": %s, \"default\": %s, \"range\": [%s, %s], \"targets\": %s, \"tab\": %s, \"slider_group\": %s, \"label\": %s, \"camera\": %s, \"tooltip\": %s}" % [
		JSON.stringify(String(e["full_name"])), JSON.stringify(String(e["group"])),
		JSON.stringify(String(e["name"])), JSON.stringify(String(e["kind"])),
		JSON.stringify(String(e["macrovar"])),
		_fmt(float(e["default"])), _fmt(float(rng[0])), _fmt(float(rng[1])),
		targets_json,
		JSON.stringify(String(e["tab"])), JSON.stringify(String(e["slider_group"])),
		JSON.stringify(String(e["label"])), JSON.stringify(String(e["camera"])),
		JSON.stringify(String(e["tooltip"])),
	]
	return row + ("," if comma else "")


## Fixed 6-decimal float format for byte-stable output (matches the rig-JSON discipline).
static func _fmt(x: float) -> String:
	return "%.6f" % x
