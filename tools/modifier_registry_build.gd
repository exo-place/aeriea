## Modifier-registry manifest builder (Slice B of docs/decisions/body-parameterization.md
## §6). Parses the MakeHuman CC0 modifier JSON (data/modifiers/*.json) into the data-driven
## modifier registry (scripts/body/modifier_registry.gd) and emits the DETERMINISTIC
## manifest artifact assets/body/modifier_registry.json — the byte-stable resource the rest
## of the body system consumes to resolve a modifier fullName -> target file(s) without
## re-parsing the MakeHuman source.
##
## Like tools/body_converter.gd this reads from MAKEHUMAN_SRC when set (the nix-pinned
## fetchFromGitHub store path) and otherwise falls back to the vendored CC0 subset
## (vendor/makehuman-cc0/data) — both carry the SAME v1.3.0 modifier JSON, so the parsed
## registry is identical. (The modifier JSON is fully vendored even though the full
## 1,280-target set is not, so Slice B's registry is complete from the subset; only the
## per-target PRESENCE flags differ between the subset and the full pinned tree.)
##
## Run headless (no rendering; pure text -> JSON):
##   MAKEHUMAN_SRC=/path/to/source godot4 --headless --path . res://tools/modifier_registry_build.tscn --quit-after 600
## or fetch-free via the vendored subset (MAKEHUMAN_SRC unset).
##
## This tool does NOT touch base_body.res / base_body.manifest.json / base_body_rig.json —
## those are body_converter.gd's outputs and remain byte-unchanged in Slice B.
extends Node

const ModifierRegistry := preload("res://scripts/body/modifier_registry.gd")

const OUT_DIR := "res://assets/body"
const OUT_MANIFEST := "res://assets/body/modifier_registry.json"


func _ready() -> void:
	get_tree().quit(_run())


func _src_data_root() -> String:
	var env := OS.get_environment("MAKEHUMAN_SRC")
	if env != "":
		return env.path_join("makehuman").path_join("data") if not env.ends_with("data") else env
	return ProjectSettings.globalize_path("res://vendor/makehuman-cc0/data")


func _run() -> int:
	var data_root := _src_data_root()
	print("modifier_registry_build: data root = %s" % data_root)

	var registry := ModifierRegistry.parse(data_root)
	var counts: Dictionary = registry["counts"]
	print("modifier_registry_build: parsed %d modifiers (%d bidirectional, %d unipolar, %d macro); targets %d present / %d missing" % [
		counts["total"], counts["bidirectional"], counts["unipolar"], counts["macro"],
		counts["targets_present"], counts["targets_missing"],
	])
	if int(counts["total"]) == 0:
		push_error("modifier_registry_build: parsed zero modifiers (no modifier JSON found under %s/modifiers)" % data_root)
		return 1

	var text := ModifierRegistry.to_manifest_string(registry)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(OUT_MANIFEST, FileAccess.WRITE)
	if f == null:
		push_error("modifier_registry_build: cannot write %s" % OUT_MANIFEST)
		return 1
	f.store_string(text)
	f.flush()
	f.close()
	print("modifier_registry_build: wrote %s (%d bytes)" % [OUT_MANIFEST, text.length()])
	print("modifier_registry_build: DONE")
	return 0
