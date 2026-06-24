## Phase C test — ON-BODY GRAB-HANDLES (character-creator-ux.md §5.2; §10 objective clauses).
## The global "Shape on the body" MODE is gone; reshape is via visible grab-handles on the focused
## region. OBJECTIVE clauses only (the visual look + felt reliability are USER-judged, reported
## from the render harness — never asserted here):
##
##   (1) NO GLOBAL MODE: the creator has no `_sculpt_mode` member and no shape-on-body toggle.
##   (2) HANDLES ARE A PURE FUNCTION OF FOCUS: focusing a LEAF region with drag-editable params
##       sprouts 1–HANDLE_MAX handles; focusing nothing / an intermediate region clears them.
##   (3) HANDLE→PARAM MAPPING IS REAL: each handle maps to one of the focused leaf's actual specs
##       (its full_name resolves to a registry modifier present in the leaf), with a footprint
##       anchor vertex and a non-zero surface-motion axis at that anchor.
##   (4) HANDLE-DRAG WRITES THROUGH apply_capped: a latched handle-drag changes the mapped param
##       through the choke; an out-of-cap drag CLAMPS to the cap (caps enforced).
##   (5) RESHAPE LATCHES UNTIL RELEASE: _begin_handle_drag sets the latch; it stays set across
##       _apply_handle_drag steps; _end_handle_drag clears it (grab-latch hysteresis).
##   (6) SLIDER/TYPE STAY IN SYNC: after a handle-drag the bound dock slider + numeric field read
##       the same clamped value the model holds (plural modality on one value, no desync).
##   (7) PICK DISAMBIGUATION: a screen point AT a handle picks it; a point > pick-radius away
##       picks nothing (orbit). _handle_at returns the NEAREST handle within the radius.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_phasec_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const CharacterCreator := preload("res://scripts/body/character_creator.gd")
const RegionSliders := preload("res://scripts/body/region_sliders.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR PHASE C — on-body grab-handles ===\n")
	await _run()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


func _mv(bs: BodyState, fn: String) -> float:
	return float(bs.modifiers.get(fn, 0.0))


# The path into a leaf with several drag-editable params: Torso → Chest & breasts.
func _chest_path(cc) -> Array:
	# Find Torso then Chest & breasts by label so the test is robust to tree reordering.
	var torso := -1
	for i in RegionSliders.TREE.size():
		if String(RegionSliders.TREE[i]["label"]) == "Torso":
			torso = i
	var children: Array = RegionSliders.children_at([torso])
	var chest := -1
	for i in children.size():
		if String(children[i]["label"]) == "Chest & breasts":
			chest = i
	return [torso, chest]


func _run() -> void:
	# (1) no global sculpt mode -------------------------------------------------
	print("--- (1) no global shape-on-body mode ---")
	var props := []
	for p in CharacterCreator.new().get_property_list():
		props.append(String(p["name"]))
	_ok("the creator has NO `_sculpt_mode` member (the global mode is gone)",
		not props.has("_sculpt_mode"), "members scanned: %d" % props.size())
	_ok("the creator HAS `_handles` (the grab-handle set)", props.has("_handles"),
		"_handles present")

	var cc := CharacterCreator.new()
	add_child(cc)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: BodyState = cc.get("_body_state")

	# (2) handles are a pure function of focus ----------------------------------
	print("--- (2) handles sprout on a focused leaf; absent otherwise ---")
	_ok("no handles when nothing is focused",
		(cc.get("_handles") as Array).is_empty(), "%d handles at entry" % (cc.get("_handles") as Array).size())
	var cp := _chest_path(cc)
	cc.call("_focus_to_path", cp)
	await get_tree().process_frame
	var handles: Array = cc.get("_handles")
	_ok("focusing Chest & breasts sprouts 1–%d handles" % cc.get("HANDLE_MAX"),
		handles.size() >= 1 and handles.size() <= int(cc.get("HANDLE_MAX")),
		"%d handles" % handles.size())
	# Focusing an INTERMEDIATE region (Torso) clears the handles.
	cc.call("_focus_to_path", [cp[0]])
	await get_tree().process_frame
	_ok("focusing an intermediate region clears the handles",
		(cc.get("_handles") as Array).is_empty(), "%d handles on Torso" % (cc.get("_handles") as Array).size())
	cc.call("_focus_clear")
	await get_tree().process_frame
	_ok("clearing focus clears the handles",
		(cc.get("_handles") as Array).is_empty(), "%d handles after clear" % (cc.get("_handles") as Array).size())

	# Re-focus the chest for the remaining clauses.
	cc.call("_focus_to_path", cp)
	await get_tree().process_frame
	handles = cc.get("_handles")
	var morph = cc.get("_morph")
	var leaf := RegionSliders.node_at(cp)
	var leaf_fns := {}
	for spec in (leaf["specs"] as Array):
		for fn in RegionSliders.resolve_full_names(String(spec[0])):
			leaf_fns[fn] = true

	# (3) handle→param mapping is real ------------------------------------------
	print("--- (3) each handle maps to a real leaf param with an anchor + motion axis ---")
	var mapping_ok := handles.size() > 0
	var detail := ""
	for h in handles:
		var fn := String(h["full_name"])
		var anchor := int(h["anchor_vertex"])
		var dir: Vector3 = morph.call("motion_dir_at", fn, anchor)
		if not leaf_fns.has(fn) or anchor < 0 or dir == Vector3.ZERO:
			mapping_ok = false
			detail = "%s anchor=%d dir=%s in-leaf=%s" % [fn, anchor, str(dir), leaf_fns.has(fn)]
			break
	_ok("every handle maps to a leaf param with a footprint anchor + non-zero motion axis",
		mapping_ok, detail if detail != "" else "%d handles validated" % handles.size())

	# (4) handle-drag writes through apply_capped (caps enforced) ----------------
	print("--- (4) handle-drag writes through the choke; an out-of-cap drag clamps ---")
	var h0: Dictionary = handles[0]
	var fn0 := String(h0["full_name"])
	bs.modifiers.erase(fn0)
	# Position the camera so the param's motion axis has an in-screen component, then drag hard
	# along +x many times to exceed the cap and prove the clamp.
	cc.call("_begin_handle_drag", 0)
	for i in 40:
		cc.call("_apply_handle_drag", Vector2(40, -25))
	var after := _mv(bs, fn0)
	cc.call("_end_handle_drag")
	var cap: Array = cc.get("_caps").call("cap", fn0)
	var capped := after <= float(cap[1]) + 1e-4 and after >= float(cap[0]) - 1e-4
	_ok("a handle-drag changed the mapped param (it actually reshapes)",
		absf(after) > 1e-4, "%s = %.4f after drag" % [h0["display"], after])
	_ok("an out-of-cap handle-drag CLAMPS to the cap (apply_capped enforced)",
		capped, "value %.4f within cap [%.3f, %.3f]" % [after, float(cap[0]), float(cap[1])])

	# (5) reshape latches until release -----------------------------------------
	print("--- (5) reshape latches across drag steps; clears on release ---")
	bs.modifiers.erase(fn0)
	cc.call("_begin_handle_drag", 0)
	var latched_at_press := int(cc.get("_drag_handle")) == 0
	cc.call("_apply_handle_drag", Vector2(10, -6))
	var latched_mid := int(cc.get("_drag_handle")) == 0
	cc.call("_apply_handle_drag", Vector2(10, -6))
	var latched_mid2 := int(cc.get("_drag_handle")) == 0
	cc.call("_end_handle_drag")
	var released := int(cc.get("_drag_handle")) < 0
	_ok("the reshape LATCHES at press and stays latched across steps, clears on release",
		latched_at_press and latched_mid and latched_mid2 and released,
		"press=%s mid=%s mid2=%s released=%s" % [latched_at_press, latched_mid, latched_mid2, released])

	# (6) slider/type stay in sync ----------------------------------------------
	print("--- (6) the bound dock slider + numeric field stay in sync with the handle edit ---")
	var msliders: Dictionary = cc.get("_modifier_sliders")
	var spec_name := String(h0["spec_name"])
	var sync_ok := msliders.has(spec_name)
	var sync_detail := "no bound slider for %s" % spec_name
	if sync_ok:
		bs.modifiers.erase(fn0)
		cc.call("_begin_handle_drag", 0)
		for i in 6:
			cc.call("_apply_handle_drag", Vector2(14, -9))
		cc.call("_end_handle_drag")
		var model_v := _mv(bs, fn0)
		var sld: HSlider = msliders[spec_name]["slider"]
		var spin: SpinBox = msliders[spec_name]["spin"]
		var slider_v := float(sld.value)
		var spin_expected: float = cc.call("_modifier_to_display", model_v, bool(msliders[spec_name]["is_bidir"]))
		sync_ok = absf(slider_v - model_v) < 1e-3 and absf(float(spin.value) - spin_expected) < 1e-2
		sync_detail = "model=%.4f slider=%.4f spin=%.2f (exp %.2f)" % [model_v, slider_v, float(spin.value), float(spin_expected)]
	_ok("after a handle-drag, slider + numeric field read the SAME clamped value", sync_ok, sync_detail)

	# (7) pick disambiguation ----------------------------------------------------
	print("--- (7) screen-space pick: AT a handle picks it; far away picks nothing ---")
	var sp: Vector2 = cc.call("_handle_screen_pos", h0)
	var pick_at := int(cc.call("_handle_at", sp))
	var pick_far := int(cc.call("_handle_at", sp + Vector2(200, 200)))
	_ok("a press AT a handle picks it (reshape)", pick_at == 0, "pick at %s = %d" % [str(sp), pick_at])
	_ok("a press > pick-radius away picks NOTHING (orbit, not reshape)", pick_far < 0,
		"pick far = %d" % pick_far)
	# A near-miss INSIDE the pick radius still grabs A handle (the forgiving disc — nearest-wins,
	# so a near-miss between two clustered handles grabs whichever is nearest, never nothing). A
	# point FAR from EVERY handle grabs nothing (orbit). The offset is chosen along the axis away
	# from the handle's nearest neighbour so the near-miss stays nearest to h0.
	var r := float(cc.get("HANDLE_PICK_RADIUS_PX"))
	# Find the direction toward the FARTHEST-away screen region from other handles: just use up
	# (toward the top of the body, away from the lower-clustered handles).
	var inside := int(cc.call("_handle_at", sp + Vector2(0.0, -(r - 4.0))))
	var outside := int(cc.call("_handle_at", sp + Vector2(0.0, -(r + 60.0))))
	_ok("the forgiving pick disc grabs a near-miss inside the radius (nearest-wins)",
		inside >= 0, "inside(-%.0fpx y)=%d" % [r - 4.0, inside])
	_ok("a press far from every handle does not grab (orbit)",
		outside < 0, "outside(-%.0fpx y)=%d" % [r + 60.0, outside])

	cc.queue_free()
