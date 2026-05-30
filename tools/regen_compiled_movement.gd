## Regenerate the compiled movement projection from movement/base.kit.json.
##
## Run (windowed under xvfb per the substrate spec's verification posture):
##   nix develop --command bash -lc \
##     'xvfb-run -a godot4 --path . res://tools/regen_compiled_movement.tscn --quit-after 120'
##
## It loads the kit, validates it, lowers it via MovementCompiler, and writes the
## generated GDScript to scripts/movement/generated/compiled_base_movement.gd.
## The generated file is committed (so the repo is runnable without a regen step);
## its header carries this same command. The golden-trace harness then asserts the
## generated code is behaviorally identical to the interpreter.
extends Node

## The COMPOSED playable kit (base ⊕ verb overlays) is the source of truth the
## compiled projection must mirror — so the compiled path gains new verbs (e.g.
## bullet jump) the instant the manifest enables them, with NO compiler edit.
const KIT_PATH := "res://movement/default.manifest.json"
const OUT_PATH := "res://scripts/movement/generated/compiled_base_movement.gd"
const OUT_CLASS := "CompiledBaseMovement"

func _ready() -> void:
	var kit := MovementKit.load_from_manifest(KIT_PATH) if KIT_PATH.ends_with(".manifest.json") else MovementKit.load_from_file(KIT_PATH)
	if not kit.is_valid():
		push_error("regen: invalid kit: %s" % str(kit.load_errors))
		get_tree().quit(1)
		return

	var src := MovementCompiler.compile(kit, OUT_CLASS, KIT_PATH)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scripts/movement/generated"))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("regen: cannot open %s for write (err %d)" % [OUT_PATH, FileAccess.get_open_error()])
		get_tree().quit(1)
		return
	f.store_string(src)
	f.flush()
	f.close()

	print("regen: wrote %d lines to %s" % [src.split("\n").size(), OUT_PATH])
	get_tree().quit(0)
