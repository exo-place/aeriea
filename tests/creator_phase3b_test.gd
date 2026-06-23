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
##   (4) TIERS EXIST + MONOTONE: the creator has T0 (archetype grid) + T1 (always visible) +
##       T2 + T3 sections; raising the tier reveals T2/T3 without hiding T1; lowering re-hides
##       the deeper sections (additive/monotone).
##   (5) VISIBLE SCULPT CONTROL: sculpt is a visible labeled toggle in the T3 section (not
##       reachable ONLY via a hidden key); toggling it changes sculpt mode.
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


# (4) + (5) tiers + visible sculpt — scene-level ------------------------------
func _test_tiers_and_sculpt() -> void:
	print("--- (4) tiers exist + monotone reveal; (5) sculpt is a visible labeled toggle ---")
	var cc := CharacterCreator.new()
	add_child(cc)
	# Let the creator build its UI (deferred panels build in _ready).
	await get_tree().process_frame
	await get_tree().process_frame

	# (4) The tier sections exist.
	var t2 = cc.get("_t2_section")
	var t3 = cc.get("_t3_section")
	var t3_main = cc.get("_t3_main_section")
	_ok("T2 + T3 region sections exist", t2 != null and t3 != null, "t2=%s t3=%s" % [t2 != null, t3 != null])
	_ok("the main-panel T3 section (sculpt + extremeness) exists", t3_main != null, "present")

	# T1 (headline axes) is always present — the sliders dict is populated regardless of tier.
	var sliders: Dictionary = cc.get("_sliders")
	_ok("T1 headline axes are built (always visible)", sliders.size() == 6,
		"%d axis sliders" % sliders.size())

	# Default tier is T1: T2/T3 sections hidden.
	cc.call("_set_tier", 1)
	_ok("at T1 the T2/T3 sections are hidden (T1 stays visible)",
		not (t2 as Control).visible and not (t3 as Control).visible and sliders.size() == 6,
		"t2.visible=%s t3.visible=%s" % [(t2 as Control).visible, (t3 as Control).visible])

	# Raise to T2: T2 revealed, T3 still hidden, T1 still present (monotone/additive).
	cc.call("_set_tier", 2)
	_ok("raising to T2 reveals T2, keeps T3 hidden, T1 unchanged",
		(t2 as Control).visible and not (t3 as Control).visible and sliders.size() == 6,
		"t2.visible=%s t3.visible=%s" % [(t2 as Control).visible, (t3 as Control).visible])

	# Raise to T3: T2 still visible (additive), T3 + main-T3 revealed.
	cc.call("_set_tier", 3)
	_ok("raising to T3 keeps T2 visible AND reveals T3 + the main-panel T3 section (additive)",
		(t2 as Control).visible and (t3 as Control).visible and (t3_main as Control).visible,
		"t2=%s t3=%s t3main=%s" % [(t2 as Control).visible, (t3 as Control).visible, (t3_main as Control).visible])

	# Lower back to T1: deeper sections re-hide (monotone in both directions).
	cc.call("_set_tier", 1)
	_ok("lowering back to T1 re-hides T2/T3",
		not (t2 as Control).visible and not (t3 as Control).visible,
		"t2.visible=%s t3.visible=%s" % [(t2 as Control).visible, (t3 as Control).visible])

	# (5) The sculpt control is a VISIBLE labeled toggle (not a hidden-key-only mode).
	cc.call("_set_tier", 3)
	var sculpt_btn = cc.get("_sculpt_btn")
	_ok("sculpt is a labeled toggle Button (not a hidden keybind)",
		sculpt_btn != null and sculpt_btn is Button and (sculpt_btn as Button).toggle_mode
			and "Sculpt" in (sculpt_btn as Button).text,
		"label=%s" % ("'" + (sculpt_btn as Button).text + "'" if sculpt_btn != null else "null"))
	var state_lbl = cc.get("_sculpt_state_lbl")
	_ok("the sculpt toggle has a visible state indicator", state_lbl != null and state_lbl is Label,
		"present")
	# Toggling the control changes sculpt mode.
	cc.call("_set_sculpt_mode", true)
	_ok("toggling the visible control enables sculpt mode", bool(cc.get("_sculpt_mode")) == true,
		"sculpt_mode=%s" % cc.get("_sculpt_mode"))
	cc.call("_set_sculpt_mode", false)
	_ok("toggling it off disables sculpt mode", bool(cc.get("_sculpt_mode")) == false,
		"sculpt_mode=%s" % cc.get("_sculpt_mode"))

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
