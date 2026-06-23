## Creator persistence test (Phase 4 / SYNTHESIS §6, decision §7). OBJECTIVE clauses only:
##
##   (1) ROUND-TRIP (gate #4): a non-default BodyState + a beyond-cap modifier (set with
##       extremeness raised) + the global extremeness, saved through CharacterAutosave and
##       restored, is byte-identical (to_dict equality) AND the extremeness round-trips. The
##       beyond-cap value PERSISTS (raw restore, no re-clamp).
##   (2) IMPORT WIRING: writing an exported character (a current-only JSON, a with-history JSON,
##       and a PNG carrying embedded history) and importing it via the creator's _import_file
##       applies it — the live body equals the saved body, and a with-history import rebuilds the
##       tree. Uses the EXISTING creator_io.gd read side; this asserts the SCENE WIRING.
##   (3) CROSS-SCENE: a creator sets a body + autosaves, is freed (the launcher frees the mode
##       on a tab switch), and a fresh creator instance restores that body on _ready — so
##       creator → other → creator keeps the body.
##   (4) RESTART: the same payload survives the in-memory store being dropped (a fresh process):
##       reloading CharacterAutosave from user:// restores the body + extremeness.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_persistence_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const CharacterCreator := preload("res://scripts/body/character_creator.gd")
const CharacterAutosaveScript := preload("res://scripts/character_autosave.gd")
const CreatorIO := preload("res://scripts/body/creator_io.gd")
const HistoryTree := preload("res://scripts/util/history_tree.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR PERSISTENCE — round-trip + import + cross-scene + restart ===\n")
	# Start from a clean autosave so prior runs don't leak into the assertions.
	_store().clear()
	_test_round_trip()
	await _test_import()
	await _test_cross_scene()
	_test_restart()
	# Leave the autosave clean for the next suite / a real run.
	_store().clear()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


func _store() -> Node:
	return get_node("/root/CharacterAutosave")


func _dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify(_sorted(a)) == JSON.stringify(_sorted(b))


## Deep sort-of-canonicalize for stable comparison (Godot dicts preserve insertion order; to_dict
## already sorts modifier keys, so a plain stringify equality is sufficient — this is belt-and-braces).
func _sorted(d: Dictionary) -> Dictionary:
	var keys := d.keys()
	keys.sort()
	var out := {}
	for k in keys:
		var v = d[k]
		out[k] = _sorted(v) if typeof(v) == TYPE_DICTIONARY else v
	return out


## A representative non-default character carrying a BEYOND-CAP modifier (the |v| would exceed
## the default cap, persisting because it was made with extremeness raised) + a few in-cap values.
func _make_body() -> BodyState:
	var bs := BodyState.new()
	bs.age_years = 33.0
	bs.masculinity = 70.0
	bs.muscle = 64.0
	bs.weight = 118.0
	bs.proportions = 0.42
	bs.height_cm = 181.0
	# A deliberately large modifier value (the beyond-cap persistence case).
	bs.modifiers["breast/breast-volume-vert-down|up"] = 0.95
	bs.modifiers["nose/nose-hump-decr|incr"] = -0.30
	return bs


# (1) ROUND-TRIP -------------------------------------------------------------
func _test_round_trip() -> void:
	print("--- (1) save → restore round-trip (BodyState + extremeness; beyond-cap persists) ---")
	var body := _make_body()
	var tree := HistoryTree.new(body.to_dict(), "test")
	var extremeness := 0.8
	var store := _store()
	store.save(body, tree, extremeness)
	var res: Dictionary = store.restore()
	_ok("restore reports ok", bool(res.get("ok", false)), "ok=%s" % res.get("ok", false))
	var restored: BodyState = res.get("body", null)
	_ok("restore yields a BodyState", restored != null, "body present" if restored != null else "null")
	if restored != null:
		_ok("BodyState round-trips byte-identical (to_dict equality)",
			_dicts_equal(restored.to_dict(), body.to_dict()),
			"restored == original")
		_ok("the beyond-cap modifier persisted raw (no re-clamp)",
			absf(float(restored.modifiers.get("breast/breast-volume-vert-down|up", 0.0)) - 0.95) < 1e-6,
			"breast vol = %.3f" % float(restored.modifiers.get("breast/breast-volume-vert-down|up", 0.0)))
	_ok("the global extremeness round-trips",
		absf(float(res.get("extremeness", -1.0)) - extremeness) < 1e-6,
		"extremeness = %.3f" % float(res.get("extremeness", -1.0)))
	var rtree = res.get("tree", null)
	_ok("the with-history save rebuilds the HistoryTree", rtree != null,
		"tree present" if rtree != null else "null")


# (2) IMPORT WIRING ----------------------------------------------------------
func _test_import() -> void:
	print("--- (2) import wiring: JSON (current + history) and PNG-embedded history apply ---")
	var body := _make_body()
	# A NON-trivial tree: a distinct root state then the body (a different state, so commit is not
	# a no-op — HistoryTree dedupes an identical re-commit). The body is the CURRENT node.
	var tree := HistoryTree.new(BodyState.new().to_dict(), "root")
	tree.commit(body.to_dict(), "edit")
	var extremeness := 0.5

	# Write the three exported artifacts to a scratch dir.
	var dir := "user://test_import"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var cur_path := "%s/current.json" % dir
	var hist_path := "%s/withhistory.json" % dir
	var png_path := "%s/withhistory.png" % dir
	_write_text(cur_path, CreatorIO.body_to_json(body, extremeness))
	_write_text(hist_path, CreatorIO.history_to_json(body, tree, extremeness))
	# A minimal valid PNG carrying the embedded history (the read path only needs the tEXt chunk).
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var png_bytes := img.save_png_to_buffer()
	var png_with_hist := CreatorIO.embed_history_in_png(png_bytes, CreatorIO.history_to_json(body, tree, extremeness))
	_write_bytes(png_path, png_with_hist)

	var cc := CharacterCreator.new()
	add_child(cc)
	await get_tree().process_frame
	await get_tree().process_frame

	# (2a) current-only JSON.
	cc._import_file(ProjectSettings.globalize_path(cur_path))
	await get_tree().process_frame
	var live: BodyState = cc.get("_body_state")
	_ok("import current-only JSON applies the body",
		_dicts_equal(live.to_dict(), body.to_dict()), "live == imported body")
	_ok("import current-only JSON restores extremeness",
		absf(float(cc._caps.extremeness) - extremeness) < 1e-6,
		"extremeness = %.3f" % float(cc._caps.extremeness))

	# (2b) with-history JSON — rebuilds the tree (more than one node).
	cc._import_file(ProjectSettings.globalize_path(hist_path))
	await get_tree().process_frame
	live = cc.get("_body_state")
	_ok("import with-history JSON applies the body",
		_dicts_equal(live.to_dict(), body.to_dict()), "live == imported body")
	var hist = cc.get("_history")
	_ok("import with-history JSON rebuilds the multi-node tree", hist != null and hist.node_count() >= 2,
		"node_count = %d" % (hist.node_count() if hist != null else 0))

	# (2c) PNG carrying embedded history.
	cc._import_file(ProjectSettings.globalize_path(png_path))
	await get_tree().process_frame
	live = cc.get("_body_state")
	_ok("import PNG-embedded history applies the body",
		_dicts_equal(live.to_dict(), body.to_dict()), "live == imported body")

	cc.queue_free()
	await get_tree().process_frame


# (3) CROSS-SCENE ------------------------------------------------------------
func _test_cross_scene() -> void:
	print("--- (3) cross-scene: a freed creator's body is restored by a fresh creator instance ---")
	_store().clear()
	var body := _make_body()

	# Creator A: set a non-default body + extremeness, autosave, then free (simulating a launcher
	# tab switch that frees the mode scene).
	var a := CharacterCreator.new()
	add_child(a)
	await get_tree().process_frame
	await get_tree().process_frame
	# Apply the body through the creator's own raw load path (the real edit/restore funnel), then
	# raise extremeness so the autosave records it. Use the import funnel as the apply mechanism.
	a._caps.extremeness = 0.6
	a.get("_body_state").age_years = body.age_years
	a.get("_body_state").masculinity = body.masculinity
	a.get("_body_state").muscle = body.muscle
	a.get("_body_state").weight = body.weight
	a.get("_body_state").proportions = body.proportions
	a.get("_body_state").height_cm = body.height_cm
	a.get("_body_state").modifiers = body.modifiers.duplicate()
	# Commit the edit into history (the real funnel a settled edit uses) so the tree's current
	# node matches the live body, then it autosaves via _refresh_history_panel.
	a._history.commit(a.get("_body_state").to_dict(), "test edit")
	a._refresh_history_panel()   # autosaves the committed state (armed after _ready)
	# Free A — _exit_tree autosaves once more; either way the store holds A's body.
	a.queue_free()
	await get_tree().process_frame

	# Creator B: a fresh instance restores A's body on _ready.
	var b := CharacterCreator.new()
	add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	var live: BodyState = b.get("_body_state")
	_ok("a fresh creator restores the previous creator's body (cross-scene)",
		_dicts_equal(live.to_dict(), body.to_dict()), "B's body == A's body")
	_ok("a fresh creator restores the previous extremeness (cross-scene)",
		absf(float(b._caps.extremeness) - 0.6) < 1e-6,
		"extremeness = %.3f" % float(b._caps.extremeness))
	b.queue_free()
	await get_tree().process_frame


# (4) RESTART ----------------------------------------------------------------
func _test_restart() -> void:
	print("--- (4) restart: the on-disk autosave restores in a fresh process ---")
	var body := _make_body()
	var tree := HistoryTree.new(body.to_dict(), "test")
	var extremeness := 0.7
	# Save through the live autoload (writes memory + disk).
	_store().save(body, tree, extremeness)
	# Simulate a fresh process: a NEW CharacterAutosave instance with an EMPTY in-memory store
	# that loads ONLY from user:// in its own _ready.
	var fresh := CharacterAutosaveScript.new()
	add_child(fresh)   # runs _ready → _load_from_disk
	var res: Dictionary = fresh.restore()
	_ok("a fresh process loads the autosave from disk", bool(res.get("ok", false)),
		"ok=%s" % res.get("ok", false))
	var restored: BodyState = res.get("body", null)
	_ok("the disk-restored body is byte-identical",
		restored != null and _dicts_equal(restored.to_dict(), body.to_dict()),
		"disk body == original")
	_ok("the disk-restored extremeness round-trips",
		absf(float(res.get("extremeness", -1.0)) - extremeness) < 1e-6,
		"extremeness = %.3f" % float(res.get("extremeness", -1.0)))
	fresh.queue_free()


# ---------------------------------------------------------------------------
func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
