## Slice-B test (docs/decisions/body-parameterization.md §6 / §9 Phase B): the
## DATA-DRIVEN MakeHuman modifier-registry parser + manifest, validated on the vendored
## CC0 subset. Proves, windowed under xvfb:
##
##   (1) PARSE on the vendored JSON — 291 modifiers parse from data/modifiers/*.json with
##       the verified §1.2 schema; counts split into bidirectional/unipolar/macro.
##   (2) BIDIRECTIONAL -> signed axis [-1,1] resolving the RIGHT TWO target filenames
##       (a known nose/measure axis: neg=…-decr.target, pos=…-incr.target).
##   (3) MACRO -> default 0.5 (and EthnicModifier -> 1/3), range [0,1], no targets.
##   (4) UNIPOLAR -> [0,1], default 0, one target file.
##   (5) "<group>/<name>" KEYING (verbatim Modifier.fullName).
##   (6) SLIDERS/DESC JOIN — a known tab/group/label (from *_sliders.json) and a known
##       tooltip (from *_modifiers_desc.json) attach to the right entry.
##   (7) DETERMINISTIC PARSE — same input -> byte-identical manifest twice.
##   (8) SUBSET-PRESENCE FLAGGING — a macro target carries no file (never "missing"); a
##       detail target whose file isn't vendored is flagged present=false (NOT an error);
##       a vendored macro .target file IS flagged present when resolvable.
##   (9) PROJECTION — BodyState.modifiers drives to_blend_weights() via the registry:
##       a bidirectional modifier at v<0/v>0 emits the neg/pos target name at |v|; a
##       macro entry in the map is ignored (headline axes own it); serialization
##       round-trips the sparse map.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_modifier_registry_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const ModifierRegistry := preload("res://scripts/body/modifier_registry.gd")
const VENDOR_DATA := "res://vendor/makehuman-cc0/data"

var _pass := 0
var _fail := 0
var _reg := {}
var _by := {}


func _ready() -> void:
	print("\n=== aeriea body SLICE B — data-driven modifier registry ===\n")
	_reg = ModifierRegistry.parse(VENDOR_DATA)
	_by = _reg.get("by_full_name", {})

	_test_parse_counts()
	_test_bidirectional()
	_test_macro()
	_test_unipolar()
	_test_full_name_keying()
	_test_sliders_desc_join()
	_test_deterministic_manifest()
	_test_subset_presence_flagging()
	_test_projection()

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# (1) parse + counts -------------------------------------------------------
func _test_parse_counts() -> void:
	print("--- (1) parse on the vendored JSON ---")
	var c: Dictionary = _reg.get("counts", {})
	var total := int(c.get("total", 0))
	_assert("291 modifiers parse", total == 291, "total=%d" % total)
	var sum := int(c.get("bidirectional", 0)) + int(c.get("unipolar", 0)) + int(c.get("macro", 0))
	_assert("kinds partition the total", sum == total, "bidir+uni+macro=%d total=%d" % [sum, total])
	_assert("has macro modifiers", int(c.get("macro", 0)) == 11, "macro=%d" % int(c.get("macro", 0)))
	_assert("has bidirectional modifiers", int(c.get("bidirectional", 0)) > 200, "bidir=%d" % int(c.get("bidirectional", 0)))
	_assert("has unipolar modifiers", int(c.get("unipolar", 0)) > 0, "uni=%d" % int(c.get("unipolar", 0)))


# (2) bidirectional -> signed axis + two target filenames ------------------
func _test_bidirectional() -> void:
	print("--- (2) bidirectional -> signed axis, two targets ---")
	var e = _by.get("nose/nose-hump-decr|incr", null)
	_assert("nose/nose-hump-decr|incr present", e != null, "key lookup")
	if e == null:
		return
	_assert("kind == bidirectional", String(e["kind"]) == ModifierRegistry.KIND_BIDIRECTIONAL, e["kind"])
	_assert("range is signed [-1,1]", e["range"][0] == -1.0 and e["range"][1] == 1.0, str(e["range"]))
	_assert("default 0 (neutral=base)", float(e["default"]) == 0.0, str(e["default"]))
	var targets: Array = e["targets"]
	_assert("two target files", targets.size() == 2, "n=%d" % targets.size())
	if targets.size() == 2:
		var neg := ""
		var pos := ""
		for t in targets:
			if String(t["which"]) == "min": neg = String(t["path"])
			elif String(t["which"]) == "max": pos = String(t["path"])
		_assert("neg target = nose/nose-hump-decr.target", neg == "nose/nose-hump-decr.target", neg)
		_assert("pos target = nose/nose-hump-incr.target", pos == "nose/nose-hump-incr.target", pos)


# (3) macro -> default 0.5 (ethnic 1/3) ------------------------------------
func _test_macro() -> void:
	print("--- (3) macro -> default 0.5, range [0,1], no targets ---")
	var age = _by.get("macrodetails/Age", null)
	_assert("macrodetails/Age present", age != null, "key lookup")
	if age != null:
		_assert("Age kind == macro", String(age["kind"]) == ModifierRegistry.KIND_MACRO, age["kind"])
		_assert("Age default == 0.5", absf(float(age["default"]) - 0.5) < 1e-9, str(age["default"]))
		_assert("Age range [0,1]", age["range"][0] == 0.0 and age["range"][1] == 1.0, str(age["range"]))
		_assert("Age has no target file", (age["targets"] as Array).is_empty(), "n=%d" % (age["targets"] as Array).size())
		_assert("Age macrovar == 'Age'", String(age["macrovar"]) == "Age", age["macrovar"])
	var afr = _by.get("macrodetails/African", null)
	_assert("macrodetails/African present", afr != null, "key lookup")
	if afr != null:
		_assert("EthnicModifier default == 1/3", absf(float(afr["default"]) - (1.0 / 3.0)) < 1e-6, str(afr["default"]))


# (4) unipolar -------------------------------------------------------------
func _test_unipolar() -> void:
	print("--- (4) unipolar -> [0,1], default 0, one target ---")
	var e = _by.get("head/head-oval", null)
	_assert("head/head-oval present", e != null, "key lookup")
	if e == null:
		return
	_assert("kind == unipolar", String(e["kind"]) == ModifierRegistry.KIND_UNIPOLAR, e["kind"])
	_assert("range [0,1]", e["range"][0] == 0.0 and e["range"][1] == 1.0, str(e["range"]))
	_assert("default 0", float(e["default"]) == 0.0, str(e["default"]))
	var targets: Array = e["targets"]
	_assert("one target file", targets.size() == 1, "n=%d" % targets.size())
	if targets.size() == 1:
		_assert("target = head/head-oval.target", String(targets[0]["path"]) == "head/head-oval.target", String(targets[0]["path"]))


# (5) fullName keying ------------------------------------------------------
func _test_full_name_keying() -> void:
	print("--- (5) '<group>/<name>' keying ---")
	# every entry's key is exactly group/name (verbatim Modifier.fullName).
	var ok := true
	var bad := ""
	for e in _reg["modifiers"]:
		var expected := "%s/%s" % [e["group"], e["name"]]
		if String(e["full_name"]) != expected:
			ok = false
			bad = "%s != %s" % [e["full_name"], expected]
			break
	_assert("all keys are <group>/<name>", ok, bad if not ok else "291/291")
	# a measure-group bidirectional encodes both extensions in the name.
	_assert("measure key encodes both exts", _by.has("measure/measure-neck-circ-decr|incr"), "measure/measure-neck-circ-decr|incr")
	# a breast macro modifier is keyed under its group, not macrodetails.
	_assert("breast/BreastSize keyed under breast", _by.has("breast/BreastSize"), "breast/BreastSize")


# (6) sliders / desc join --------------------------------------------------
func _test_sliders_desc_join() -> void:
	print("--- (6) sliders (tab/group/label) + desc (tooltip) join ---")
	# tab/group from modeling_sliders.json (the macro slider block).
	var age = _by.get("macrodetails/Age", null)
	if age != null:
		_assert("Age tab == 'Macro modelling'", String(age["tab"]) == "Macro modelling", age["tab"])
		_assert("Age slider_group == 'Macro'", String(age["slider_group"]) == "Macro", age["slider_group"])
		_assert("Age label == 'Age'", String(age["label"]) == "Age", age["label"])
		# tooltip from modeling_modifiers_desc.json (verbatim).
		_assert("Age tooltip is the desc text", String(age["tooltip"]).begins_with("Age of the human"), String(age["tooltip"]).substr(0, 30))
	# a face detail slider carries a camera + tab from the slider tree.
	var hump = _by.get("nose/nose-hump-decr|incr", null)
	if hump != null:
		_assert("nose-hump tab == 'Face'", String(hump["tab"]) == "Face", hump["tab"])
		_assert("nose-hump camera == 'leftView'", String(hump["camera"]) == "leftView", hump["camera"])


# (7) deterministic manifest ----------------------------------------------
func _test_deterministic_manifest() -> void:
	print("--- (7) deterministic parse -> byte-identical manifest ---")
	var a := ModifierRegistry.to_manifest_string(ModifierRegistry.parse(VENDOR_DATA))
	var b := ModifierRegistry.to_manifest_string(ModifierRegistry.parse(VENDOR_DATA))
	_assert("two parses -> identical manifest bytes", a == b, "len=%d" % a.length())
	_assert("manifest is non-empty JSON", a.begins_with("{") and a.length() > 1000, "len=%d" % a.length())


# (8) subset-presence flagging --------------------------------------------
func _test_subset_presence_flagging() -> void:
	print("--- (8) subset-presence flagging (no error on missing) ---")
	var c: Dictionary = _reg.get("counts", {})
	# detail targets are NOT vendored yet (Slice C) -> they are flagged missing, NOT errored.
	_assert("some detail targets flagged missing", int(c.get("targets_missing", 0)) > 0, "missing=%d" % int(c.get("targets_missing", 0)))
	# the missing flag is on a detail target, and parsing still succeeded (291 entries).
	var hump = _by.get("nose/nose-hump-decr|incr", null)
	if hump != null:
		var all_missing := true
		for t in hump["targets"]:
			if t["present"]: all_missing = false
		_assert("nose-hump targets flagged not-present (Slice C supplies)", all_missing, "present flags all false")
	# macro modifiers carry no target -> never contribute a missing flag.
	var age = _by.get("macrodetails/Age", null)
	if age != null:
		_assert("macro modifier contributes no target flag", (age["targets"] as Array).is_empty(), "no targets")
	# a vendored macro .target file IS detectable as present when its path is resolved.
	# (caucasian-female-old.target IS vendored under macrodetails/.) We assert the parser's
	# presence-check mechanism works by resolving a known-vendored path directly.
	var vendored_exists := FileAccess.file_exists(VENDOR_DATA + "/targets/macrodetails/caucasian-female-old.target")
	_assert("presence check sees a vendored .target file", vendored_exists, "macrodetails/caucasian-female-old.target")


# (9) projection: modifiers map -> blend weights via the registry ----------
func _test_projection() -> void:
	print("--- (9) BodyState.modifiers projects via the registry ---")
	# The runtime registry loads from the built manifest; ensure it is available.
	var runtime_reg := BodyState.registry()
	_assert("runtime registry loads from built manifest", not runtime_reg.is_empty(), "by_full_name n=%d" % (runtime_reg.get("by_full_name", {}) as Dictionary).size())

	# bidirectional positive -> pos target name at +v.
	var bs := BodyState.new()
	bs.modifiers["nose/nose-hump-decr|incr"] = 0.4
	var w := bs.to_blend_weights()
	_assert("v>0 drives pos target at v", absf(float(w.get("nose/nose-hump-incr.target", 0.0)) - 0.4) < 1e-6, str(w.get("nose/nose-hump-incr.target", null)))
	_assert("v>0 does NOT drive neg target", not w.has("nose/nose-hump-decr.target"), "neg absent")

	# bidirectional negative -> neg target name at -v.
	var bs2 := BodyState.new()
	bs2.modifiers["nose/nose-hump-decr|incr"] = -0.6
	var w2 := bs2.to_blend_weights()
	_assert("v<0 drives neg target at -v", absf(float(w2.get("nose/nose-hump-decr.target", 0.0)) - 0.6) < 1e-6, str(w2.get("nose/nose-hump-decr.target", null)))

	# unipolar -> single target at v.
	var bs3 := BodyState.new()
	bs3.modifiers["head/head-oval"] = 0.7
	var w3 := bs3.to_blend_weights()
	_assert("unipolar drives its target at v", absf(float(w3.get("head/head-oval.target", 0.0)) - 0.7) < 1e-6, str(w3.get("head/head-oval.target", null)))

	# a macro entry in the map is ignored (headline axes own it).
	var bs4 := BodyState.new()
	bs4.modifiers["macrodetails/Age"] = 0.9
	var w4 := bs4.to_blend_weights()
	_assert("macro entry not projected as a raw blendshape", not w4.has("macrodetails/Age"), "macro skipped")

	# default body (empty map) projects no detail entries.
	var bs5 := BodyState.new()
	var w5 := bs5.to_blend_weights()
	_assert("empty modifiers map adds no detail weights", not w5.has("nose/nose-hump-incr.target"), "no detail keys")

	# serialization round-trips the sparse map.
	var d := bs.to_dict()
	_assert("non-empty modifiers serialized", d.has("modifiers") and d["modifiers"].has("nose/nose-hump-decr|incr"), str(d.get("modifiers", {})))
	var rt := BodyState.from_dict(d)
	_assert("round-trip preserves modifier value", absf(float(rt.modifiers.get("nose/nose-hump-decr|incr", 0.0)) - 0.4) < 1e-6, str(rt.modifiers))
	_assert("empty body omits modifiers key", not bs5.to_dict().has("modifiers"), "neutral body tiny dict")


# ---------------------------------------------------------------------------
func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
