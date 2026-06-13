## Controls-legend projection test. Asserts the parkour controls legend is
## DERIVED from the movement kit (projection-from-one-definition), not from a
## hardcoded array. The kit's optional `legend` transition metadata is the single
## source of truth; adding a verb with a legend block surfaces it automatically.
##
## Covers:
##   - loading the default manifest yields the expected legend verbs/triggers
##   - the projection is data-driven (legend entries come from kit transitions)
##   - input-bound vs automatic is derived from the legend metadata (`input`)
##   - legend metadata is validated (closed shape; unknown keys / drift rejected)
##   - the legacy hardcoded AUTOMATIC_VERBS array no longer exists in code
##
## Run headless (windowed under xvfb per the spec):
##   godot4 --headless tests/legend_projection_test.tscn --quit-after 600
extends Node

var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	print("\n=== aeriea controls-legend projection test ===\n")

	_test_kit_loads_clean()
	_test_expected_verbs_from_kit()
	_test_triggers_from_kit()
	_test_all_automatic_by_default()
	_test_input_bound_derivation()
	_test_legend_validation_closed_shape()
	_test_legend_input_must_match_guard()
	_test_no_hardcoded_array_in_overlay()

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _assert(test_name: String, condition: bool, evidence: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  %s  [%s]" % [test_name, evidence])
	else:
		_fail_count += 1
		print("  FAIL  %s  [%s]" % [test_name, evidence])


func _load_default_kit() -> MovementKit:
	return MovementKit.load_from_manifest("res://movement/default.manifest.json")


func _labels(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		out.append(str(e.get("label", "")))
	return out


func _entry_for(entries: Array, label: String) -> Dictionary:
	for e in entries:
		if str(e.get("label", "")) == label:
			return e
	return {}


func _test_kit_loads_clean() -> void:
	var kit := _load_default_kit()
	_assert("default manifest loads clean", kit.is_valid(), str(kit.load_errors))


func _test_expected_verbs_from_kit() -> void:
	var kit := _load_default_kit()
	var labels := _labels(kit.legend_entries())
	for expected in ["Wall-run", "Wall-jump", "Vault / Mantle", "Slide"]:
		_assert("legend projects '%s' from kit" % expected, labels.has(expected),
			"labels=%s" % str(labels))


func _test_triggers_from_kit() -> void:
	var kit := _load_default_kit()
	var entries := kit.legend_entries()
	var expected_triggers := {
		"Wall-run": "run fast alongside a wall",
		"Wall-jump": "Jump while wall-running",
		"Vault / Mantle": "approach a ledge with speed",
		"Slide": "Crouch while moving fast",
	}
	for label in expected_triggers:
		var e := _entry_for(entries, label)
		_assert("trigger for '%s' comes from kit" % label,
			str(e.get("trigger", "")) == expected_triggers[label],
			"got='%s'" % str(e.get("trigger", "")))


func _test_all_automatic_by_default() -> void:
	# Today's four verbs are all automatic/contextual (no `input` in their legend).
	var kit := _load_default_kit()
	for e in kit.legend_entries():
		_assert("'%s' is automatic (no binding)" % str(e.get("label")),
			not bool(e.get("input_bound", false)) and not e.has("action"),
			"input_bound=%s" % str(e.get("input_bound", false)))


func _test_input_bound_derivation() -> void:
	# A verb whose legend declares `input` (matching its guard action) projects as
	# input-bound with the action name surfaced for the renderer's binding lookup.
	var data := {
		"params": {}, "initial": "A",
		"states": [
			{ "name": "A", "transitions": [
				{ "when": { "op": "input_pressed", "action": "jump" }, "to": "A", "reenter": true,
				  "legend": { "label": "Test-jump", "trigger": "press Jump", "input": "jump" } },
			] },
		],
	}
	var kit := MovementKit.load_from_dict(data)
	_assert("kit with input-bound legend loads clean", kit.is_valid(), str(kit.load_errors))
	var entries := kit.legend_entries()
	var e := _entry_for(entries, "Test-jump")
	_assert("input-bound entry marked input_bound", bool(e.get("input_bound", false)), str(e))
	_assert("input-bound entry surfaces action", str(e.get("action", "")) == "jump", str(e))


func _test_legend_validation_closed_shape() -> void:
	# An unknown key in the legend block is a load-time error (closed shape).
	var data := {
		"params": {}, "initial": "A",
		"states": [
			{ "name": "A", "transitions": [
				{ "when": { "op": "airborne" }, "to": "A", "reenter": true,
				  "legend": { "label": "X", "trigger": "y", "bogus": 1 } },
			] },
		],
	}
	var kit := MovementKit.load_from_dict(data)
	_assert("unknown legend key rejected", not kit.is_valid(), str(kit.load_errors))

	# A legend missing a label/trigger is also rejected.
	var data2 := {
		"params": {}, "initial": "A",
		"states": [
			{ "name": "A", "transitions": [
				{ "when": { "op": "airborne" }, "to": "A", "reenter": true,
				  "legend": { "label": "X" } },
			] },
		],
	}
	var kit2 := MovementKit.load_from_dict(data2)
	_assert("legend missing trigger rejected", not kit2.is_valid(), str(kit2.load_errors))


func _test_legend_input_must_match_guard() -> void:
	# Anti-drift: legend.input must name an action the guard actually fires on.
	var data := {
		"params": {}, "initial": "A",
		"states": [
			{ "name": "A", "transitions": [
				{ "when": { "op": "input_pressed", "action": "jump" }, "to": "A", "reenter": true,
				  "legend": { "label": "X", "trigger": "y", "input": "crouch" } },
			] },
		],
	}
	var kit := MovementKit.load_from_dict(data)
	_assert("legend input not in guard rejected", not kit.is_valid(), str(kit.load_errors))


func _test_no_hardcoded_array_in_overlay() -> void:
	# Retire, don't deprecate: the old AUTOMATIC_VERBS hardcoded array is gone.
	var src := FileAccess.get_file_as_string("res://scripts/ui/controls_overlay.gd")
	_assert("AUTOMATIC_VERBS array removed from overlay", not src.contains("AUTOMATIC_VERBS"),
		"controls_overlay.gd still references AUTOMATIC_VERBS" if src.contains("AUTOMATIC_VERBS") else "absent")
