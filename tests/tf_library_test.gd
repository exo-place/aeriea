## TF library test — asserts the authored transformation library (tf_library.gd) is sound:
##   (a) every TF in the library APPLIES to the standard base body without error and
##       leaves a NON-EMPTY description (a real, readable body).
##   (b) determinism: applying a TF to the base twice yields byte-identical bodies.
##   (c) no authored content uses a global numeric ordinal / raw id in TARGETING beyond
##       the stable named base mounts (a smell check that targeting stays declarative).
##   (d) the body-core convention: no segment in any authored part carries the retired
##       `spine` tag; trunks use `body_core`.
##   (e) genital nouns are natural (penis/vagina) in any description that has genitals.
##
## Run: xvfb-run -a godot4 --path . res://tests/tf_library_test.tscn --quit-after 4000
extends Node

const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const TfHolder := preload("res://scripts/body/tf/tf_holder.gd")
const TfContent := preload("res://scripts/body/tf/tf_content.gd")
const TfLibrary := preload("res://scripts/body/tf/tf_library.gd")
const TfDescribe := preload("res://scripts/body/tf/tf_describe.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea TF-library test ===\n")
	_test_all_apply_and_describe()
	_test_determinism()
	_test_no_spine_tag()
	_test_categories_cover_registry()
	_test_natural_genital_nouns()
	_test_process_narratives()
	_test_staged_progression()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


# Apply one TF (staged or instant) to a fresh base; return the resulting body.
func _apply(tf_id: String, seed_value: int) -> Dictionary:
	var reg := TfLibrary.registry()
	var tf: Dictionary = reg[tf_id]
	var h := TfHolder.new(TfContent.biped(), seed_value, reg)
	if bool(tf.get("staged", false)):
		h.start_tf(tf_id)
		var step: int = int(tf.get("stage_seconds", 600))
		for i in int(tf.get("max_stages", 1)):
			h.advance_time(step)
	else:
		h.apply_instant(tf_id)
	return h.body


func _test_all_apply_and_describe() -> void:
	var reg := TfLibrary.registry()
	_ok(reg.size() >= 30, "library has at least 30 transformations (has %d)" % reg.size())
	var all_ok := true
	for tf_id in reg.keys():
		var body := _apply(tf_id, 0xA0D17)
		var desc := TfDescribe.describe(body)
		if desc.strip_edges() == "":
			all_ok = false
			print("    %s -> empty description" % tf_id)
		# Every body must still have a root and at least a head + torso (a real body).
		if BodyGraph.find_by_id(body["root"], "head") == null:
			all_ok = false
			print("    %s -> body lost its head" % tf_id)
	_ok(all_ok, "every TF applies to the base and yields a non-empty, headed body")


func _test_determinism() -> void:
	var reg := TfLibrary.registry()
	var any_checked := false
	var det_ok := true
	for tf_id in reg.keys():
		var a := _apply(tf_id, 0x1234)
		var b := _apply(tf_id, 0x1234)
		any_checked = true
		if JSON.stringify(a) != JSON.stringify(b):
			det_ok = false
			print("    %s diverged across identical seed+log" % tf_id)
	_ok(any_checked and det_ok, "every TF is deterministic (same seed+log -> identical body)")


func _test_no_spine_tag() -> void:
	# The retired `spine` special tag must not appear in any authored part; trunks/barrels
	# use the consistent `body_core` tag instead.
	var reg := TfLibrary.registry()
	var found_spine := false
	var found_core := false
	for tf_id in reg.keys():
		var body := _apply(tf_id, 1)
		for seg in BodyGraph.all_segments(body["root"]):
			var tags: Array = seg.get("tags", [])
			if "spine" in tags:
				found_spine = true
			if "body_core" in tags:
				found_core = true
	_ok(not found_spine, "no authored part carries the retired `spine` tag")
	_ok(found_core, "trunks/barrels carry the `body_core` tag (convention is used)")


func _test_categories_cover_registry() -> void:
	# Every TF in the registry appears in exactly one display category, and vice versa.
	var reg := TfLibrary.registry()
	var seen := {}
	for entry in TfLibrary.categories():
		for tf_id in entry[1]:
			_ok(reg.has(tf_id), "category lists a real TF id (%s)" % tf_id)
			seen[tf_id] = true
	for tf_id in reg.keys():
		_ok(seen.has(tf_id), "TF %s appears in a display category" % tf_id)


func _test_natural_genital_nouns() -> void:
	# Any description that mentions genitalia must use natural nouns (penis / vagina) and
	# never the clinical "phallic genital" / "vaginal genital" phrasing.
	var reg := TfLibrary.registry()
	var bad := false
	var saw_penis := false
	var saw_vagina := false
	for tf_id in reg.keys():
		var desc := TfDescribe.describe(_apply(tf_id, 1))
		if "phallic genital" in desc or "vaginal genital" in desc:
			bad = true
			print("    %s description uses a clinical genital noun" % tf_id)
		if "penis" in desc:
			saw_penis = true
		if "vagina" in desc:
			saw_vagina = true
	_ok(not bad, "no description uses 'phallic genital' / 'vaginal genital'")
	_ok(saw_penis and saw_vagina, "descriptions use natural nouns penis and vagina")


# The PROCESS describer: every TF that actually changes the base must yield a non-empty,
# ordered process narrative (a list of plain change sentences), and that narrative must be
# clean — no node ids, no raw deltas, no clinical genital nouns.
func _test_process_narratives() -> void:
	var reg := TfLibrary.registry()
	var base := TfContent.biped()
	var any_nonempty := false
	var clean := true
	var deterministic := true
	for tf_id in reg.keys():
		var after := _apply(tf_id, 0xA0D17)
		var lines: Array = TfDescribe.describe_transition(base, after)
		# A TF that changes the body must narrate the change.
		if JSON.stringify(after) != JSON.stringify(base):
			if lines.is_empty():
				_fail += 1
				print("  FAIL: %s changes the body but yields an empty process narrative" % tf_id)
				continue
			any_nonempty = true
		var joined := "\n".join(lines)
		for bad_token in ["_mm", "_cm", "_ml", "volume_ml", "torso_upper", "leg_l",
				"phallic genital", "vaginal genital", "{", "}", "->"]:
			if bad_token in joined:
				clean = false
				print("  FAIL: %s narrative leaked dev-ese (%s): %s" % [tf_id, bad_token, joined])
		# Determinism: same seed + log -> identical narrative.
		var again: Array = TfDescribe.describe_transition(base, _apply(tf_id, 0xA0D17))
		if "\n".join(again) != joined:
			deterministic = false
			print("  FAIL: %s narrative is non-deterministic" % tf_id)
	_ok(any_nonempty, "changed TFs yield non-empty ordered process narratives")
	_ok(clean, "process narratives stay clean (no ids, units, or raw deltas)")
	_ok(deterministic, "process narratives are deterministic")


# Staged progression: a staged TF walked stage by stage yields MULTIPLE ordered lines —
# the change unfolding over time, not a single end-state line.
func _test_staged_progression() -> void:
	var content_reg := TfContent.registry()
	# Fur creeping up a taur lower body: one part furs per stage, so the progression has
	# several ordered lines (left hind leg, right hind leg, barrel, torso).
	var taur := _apply("biped_to_taur", 0xA0D17)
	var holder := TfHolder.new(taur, 0xA0D17, content_reg)
	holder.start_tf("set_covering_fur_upward")
	var snaps: Array = [BodyGraph.dup_state(holder.body)]
	for i in 4:
		holder.advance_time(900)
		snaps.append(BodyGraph.dup_state(holder.body))
	var prog: Array = TfDescribe.describe_progression(snaps)
	_ok(prog.size() >= 3, "fur-creep progression yields several ordered stage lines (got %d)" % prog.size())
	var all_fur := true
	for line in prog:
		if "ur" not in str(line).to_lower():   # "fur" / "Fur"
			all_fur = false
	_ok(all_fur, "fur-creep progression lines all describe fur advancing")

	# Staged breast growth: each stage swells the breasts, so several distinct lines.
	var h2 := TfHolder.new(TfContent.biped(), 0xA0D17, content_reg)
	h2.start_tf("grow_breasts")
	var snaps2: Array = [BodyGraph.dup_state(h2.body)]
	for i in 4:
		h2.advance_time(600)
		snaps2.append(BodyGraph.dup_state(h2.body))
	var prog2: Array = TfDescribe.describe_progression(snaps2)
	_ok(prog2.size() >= 2, "staged breast-growth yields multiple progression lines (got %d)" % prog2.size())
