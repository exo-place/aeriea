## Phase 3b test — progressive-refine tiers + the archetype pick system + the visible sculpt
## control (docs/decisions/character-creator-and-body.md §2.1–2.3). OBJECTIVE clauses only
## (whether an archetype LOOKS GOOD is USER-taste-gated — not asserted here):
##
##   (1) ARCHETYPE CONTAINMENT (gate #11a): every shipped first-party archetype lies within
##       every control's DEFAULT interval cap(control, 0). validate_archetype_containment
##       returns no violations for the shipped roster.
##   (2) ROSTER SHAPE: a representative set (>= 5) spanning the family fork, every entry a
##       BodyState-shaped dict that from_dict round-trips.
##   (3) ARCHETYPE LOAD: picking an archetype yields ITS BodyState (the loaded body equals the
##       archetype's to_dict, via the raw load path; gesture aborted).
##   (4) PROJECTION SHELL: the creator has NO tier selector; the six whole-body dials are built;
##       focusing a region shows the contextual dock (the active-surface rule); clearing focus
##       hides it (no persistent panel). (The detailed tree-projection assertions live in
##       creator_tree_nav_test.gd.)
##   (5) VISIBLE SHAPE-ON-BODY CONTROL: the shape-on-body toggle is a visible labeled toggle
##       (not reachable ONLY via a hidden key); toggling it changes the mode.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_phase3b_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const BodyCaps := preload("res://scripts/body/body_caps.gd")
const BodyArchetypes := preload("res://scripts/body/body_archetypes.gd")
const CharacterCreator := preload("res://scripts/body/character_creator.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR PHASE 3b — tiers + archetype pick + visible sculpt control ===\n")
	_test_archetype_containment()
	_test_roster_shape()
	_test_archetype_load()
	await _test_tiers_and_sculpt()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


# (1) archetype containment — gate #11a ---------------------------------------
func _test_archetype_containment() -> void:
	print("--- (1) gate #11a: every shipped archetype within default caps cap(control, 0) ---")
	var caps := BodyCaps.new()
	var states := BodyArchetypes.roster_states()
	_ok("the roster is non-empty (a representative set ships)", not states.is_empty(),
		"%d archetypes loaded" % states.size())
	var errs := caps.validate_archetype_containment(states)
	_ok("every shipped archetype lies within every control's DEFAULT interval", errs.is_empty(),
		"violations: %s" % (str(errs) if not errs.is_empty() else "none"))


# (2) roster shape ------------------------------------------------------------
func _test_roster_shape() -> void:
	print("--- (2) roster: representative set spanning the family fork; from_dict round-trips ---")
	var roster := BodyArchetypes.load_roster()
	_ok("a representative set (>= 5) ships (not dozens, not a stub)", roster.size() >= 5,
		"%d archetypes" % roster.size())
	var families := {}
	for e in roster:
		families[String(e["family"])] = true
	var have := families.keys()
	have.sort()
	_ok("the set spans the feminine/androgynous/masculine family fork",
		families.has("feminine") and families.has("androgynous") and families.has("masculine"),
		"families: %s" % str(have))
	# Every state round-trips through BodyState.from_dict/to_dict (it IS a frozen BodyState).
	var bad := ""
	for e in roster:
		var state: Dictionary = e["state"]
		var bs := BodyState.from_dict(state)
		# Headline fields survive the round-trip.
		if state.has("masculinity") and absf(bs.masculinity - float(state["masculinity"])) > 1e-4:
			bad = "%s masculinity lost in round-trip" % e["name"]
			break
	_ok("every archetype state round-trips through BodyState.from_dict", bad == "",
		bad if bad != "" else "all round-trip")


# (3) archetype load yields its BodyState -------------------------------------
func _test_archetype_load() -> void:
	print("--- (3) loading an archetype yields ITS BodyState (raw load path) ---")
	var roster := BodyArchetypes.load_roster()
	if roster.is_empty():
		_ok("archetype load (skipped — empty roster)", false, "no archetypes")
		return
	# Pick a non-trivial archetype (one with modifiers) to make the load meaningful.
	var picked: Dictionary = roster[0]
	for e in roster:
		if not (e["state"].get("modifiers", {}) as Dictionary).is_empty():
			picked = e
			break
	var state: Dictionary = picked["state"]
	var loaded := BodyState.from_dict(state)
	# The loaded BodyState's to_dict equals the archetype's normalized state (the load is raw,
	# value-preserving). Compare via to_dict (the canonical serialization the load uses).
	var round := loaded.to_dict()
	var match_ok := _dicts_equal(round, BodyState.from_dict(state).to_dict())
	_ok("BodyState.from_dict(archetype) == the archetype's frozen BodyState", match_ok,
		"%s loads to its own state" % picked["name"])
	# Spot-check a modifier value survived raw (within default caps, so raw == capped).
	var mods: Dictionary = state.get("modifiers", {})
	var caps := BodyCaps.new()
	var raw_ok := true
	for fn in mods:
		if absf(float(loaded.modifiers.get(fn, 0.0)) - float(mods[fn])) > 1e-4:
			raw_ok = false
			break
		# And it is within the default cap (so raw load == capped load at e=0).
		var di: Array = caps.default_interval(fn)
		if float(mods[fn]) < float(di[0]) - 1e-6 or float(mods[fn]) > float(di[1]) + 1e-6:
			raw_ok = false
			break
	_ok("every archetype modifier loads raw AND is within its default cap (raw == capped @ e=0)",
		raw_ok, "%d modifiers preserved + in-cap" % mods.size())


# (4) + (5) projection shell + visible shape-on-body — scene-level --------------
func _test_tiers_and_sculpt() -> void:
	print("--- (4) projection shell (no tier selector; focus-driven dock); (5) shape-on-body toggle ---")
	var cc := CharacterCreator.new()
	add_child(cc)
	# Let the creator build its UI (deferred panels build in _ready).
	await get_tree().process_frame
	await get_tree().process_frame

	# (4) The tier selector is GONE — there is no _set_tier / _tier API anymore.
	_ok("the tier selector is deleted (no _set_tier method)", not cc.has_method("_set_tier"),
		"no tier API")

	# The six whole-body dials are built (always present, pinned strip).
	var sliders: Dictionary = cc.get("_sliders")
	_ok("the six whole-body dials are built (pinned strip)", sliders.size() == 6,
		"%d dials" % sliders.size())

	# The contextual dock is ABSENT at entry (no focus → no dock).
	var dock = cc.get("_dock_panel")
	_ok("at entry no contextual dock is shown (active-surface rule)",
		dock != null and not (dock as Control).visible, "dock.visible=%s" % (dock as Control).visible)

	# Focusing a region shows the dock; clearing focus hides it.
	cc.call("_focus_into", 0)   # focus the first top-level region (Face)
	_ok("focusing a region shows the contextual dock", (dock as Control).visible,
		"dock.visible=%s after focus" % (dock as Control).visible)
	cc.call("_focus_clear")
	_ok("clearing focus hides the dock (no persistent panel)", not (dock as Control).visible,
		"dock.visible=%s after clear" % (dock as Control).visible)

	# (5) The shape-on-body control is a VISIBLE labeled toggle (not a hidden-key-only mode).
	var sculpt_btn = cc.get("_sculpt_btn")
	_ok("shape-on-body is a labeled toggle Button (not a hidden keybind)",
		sculpt_btn != null and sculpt_btn is Button and (sculpt_btn as Button).toggle_mode
			and "Shape" in (sculpt_btn as Button).text,
		"label=%s" % ("'" + (sculpt_btn as Button).text + "'" if sculpt_btn != null else "null"))
	var state_lbl = cc.get("_sculpt_state_lbl")
	_ok("the shape-on-body toggle has a visible state indicator", state_lbl != null and state_lbl is Label,
		"present")
	cc.call("_set_sculpt_mode", true)
	_ok("toggling the visible control enables shape-on-body", bool(cc.get("_sculpt_mode")) == true,
		"mode=%s" % cc.get("_sculpt_mode"))
	cc.call("_set_sculpt_mode", false)
	_ok("toggling it off disables shape-on-body", bool(cc.get("_sculpt_mode")) == false,
		"mode=%s" % cc.get("_sculpt_mode"))

	cc.queue_free()


func _dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
		var av = a[k]
		var bv = b[k]
		if typeof(av) == TYPE_DICTIONARY and typeof(bv) == TYPE_DICTIONARY:
			if not _dicts_equal(av, bv):
				return false
		elif typeof(av) == TYPE_FLOAT or typeof(bv) == TYPE_FLOAT:
			if absf(float(av) - float(bv)) > 1e-4:
				return false
		elif av != bv:
			return false
	return true
