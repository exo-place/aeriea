## Phase E test — cross-seam UI de-defecting of the rebuilt creator (character-creator-ux.md
## §5.1 / §7.2 / §8.4 + the composed-whole critic's findings). OBJECTIVE clauses only (aesthetics
## are USER-judged from the render harness):
##
##   ADVANCED POPUP DISSOLVED (fix 1):
##   (1) there is NO Popup taller than the window anywhere in the tree (the 348×3344 bug is gone).
##   (2) there is NO "Advanced" affordance (button or menu item) and no PopupPanel left over.
##
##   MIRROR — a plain always-reachable toggle (fix 1 / §5.1):
##   (3) a plainly-labeled "Mirror" toggle exists OUTSIDE any popup, and toggling it flips _mirror.
##
##   BEYOND-HUMAN OPT-IN — inline at the value, not a global popup checkbox (fix 1 / §8.4):
##   (4) at entry (no value at its edge) NO inline opt-in is visible (it is contextual, not global).
##   (5) pushing a value to its human edge makes an inline opt-in VISIBLE on that control.
##   (6) flipping that inline opt-in widens caps (the global unlock); lowering it never snaps the
##       value (non-destructive ratchet).
##
##   HISTORY — de-overlapped + single surface (fix 2 / fix 3):
##   (7) the history overlay rect does NOT intersect the bottom pinned-strip rect.
##   (8) exactly ONE history affordance ("⤺ History"); NO standalone undo/redo icon buttons.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_phasee_test.tscn --quit-after 8000
extends Node

const CharacterCreator := preload("res://scripts/body/character_creator.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR PHASE E — dissolve Advanced popup, inline limit, de-overlap history ===\n")
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


## Collect every node of a given class under `n`.
func _collect(n: Node, klass: String, out: Array) -> void:
	if n.is_class(klass):
		out.append(n)
	for c in n.get_children():
		_collect(c, klass, out)


## Collect the visible TEXT of every Button/Label/CheckBox/CheckButton under `n`.
func _texts(n: Node, out: Array) -> void:
	if n is Button or n is Label:
		out.append(String((n as Control).text))
	if n is PopupMenu:
		var pm := n as PopupMenu
		for i in pm.item_count:
			out.append(pm.get_item_text(i))
	for c in n.get_children():
		_texts(c, out)


## A node anchored under any Popup ancestor.
func _under_popup(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is Popup:
			return true
		p = p.get_parent()
	return false


func _run() -> void:
	var cc := CharacterCreator.new()
	add_child(cc)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: BodyState = cc.get("_body_state")
	var caps = cc.get("_caps")

	var win_h := float(cc.get_viewport().get_visible_rect().size.y)

	# (1) no popup taller than the window -----------------------------------------
	print("--- (1) no popup taller than the window ---")
	var popups: Array = []
	_collect(cc, "Popup", popups)
	var tall := []
	for p in popups:
		var h := float((p as Control).size.y)
		if h > win_h:
			tall.append("%s h=%.0f" % [(p as Node).name, h])
	_ok("no Popup is taller than the window", tall.is_empty(),
		"win_h=%.0f tall=%s popups=%d" % [win_h, str(tall), popups.size()])

	# (2) Advanced popup + affordance gone ----------------------------------------
	print("--- (2) the Advanced popup and its button/menu-item are gone ---")
	var ui: Array = []
	_texts(cc, ui)
	var adv_hits := []
	for t in ui:
		if String(t).to_lower().contains("advanced"):
			adv_hits.append(t)
	_ok("no 'Advanced' button or menu item present", adv_hits.is_empty(), "hits=%s" % str(adv_hits))
	_ok("the _advanced_popup member is gone (property absent)",
		not cc.get_property_list().any(func(p): return String(p.name) == "_advanced_popup"),
		"property absent")

	# (3) Mirror is a plain toggle outside any popup -------------------------------
	print("--- (3) Mirror is a plain, always-reachable toggle (not in a popup) ---")
	var checks: Array = []
	_collect(cc, "CheckButton", checks)
	var mirror_toggle: CheckButton = null
	for c in checks:
		if String((c as CheckButton).text) == "Mirror" and not _under_popup(c):
			mirror_toggle = c
			break
	_ok("a plain 'Mirror' toggle exists outside any popup", mirror_toggle != null,
		"found=%s" % str(mirror_toggle != null))
	if mirror_toggle != null:
		var before := bool(cc.get("_mirror"))
		mirror_toggle.button_pressed = not before   # emits toggled → _set_mirror
		await get_tree().process_frame
		_ok("toggling the Mirror control flips _mirror", bool(cc.get("_mirror")) == (not before),
			"%s -> %s" % [str(before), str(cc.get("_mirror"))])
		mirror_toggle.button_pressed = before
		await get_tree().process_frame

	# (4)/(5) inline beyond-human opt-in: absent at entry, appears at the value's edge ---
	print("--- (4)(5) the beyond-human opt-in is INLINE at the value, not a global popup ---")
	var optin_dials: Dictionary = cc.get("_edge_optin_dials")
	# At a neutral entry body, no axis is at its human edge → no inline opt-in visible.
	var visible_at_entry := 0
	for f in optin_dials:
		if (optin_dials[f] as CheckButton).visible:
			visible_at_entry += 1
	_ok("at entry NO inline opt-in is visible (contextual, not global)", visible_at_entry == 0,
		"visible=%d of %d dials" % [visible_at_entry, optin_dials.size()])
	# Push masculinity to its human (extremeness-0) high edge → its inline opt-in must appear.
	var human_hi := float(caps.cap("masculinity", 0.0)[1])
	bs.masculinity = human_hi
	cc.call("_apply_state")
	await get_tree().process_frame
	var masc_optin := optin_dials.get("masculinity", null) as CheckButton
	_ok("pushing a value to its human edge reveals the inline opt-in on that control",
		masc_optin != null and masc_optin.visible, "visible=%s" % str(masc_optin != null and masc_optin.visible))
	# The opt-in label is the plain beyond-human string (no 'extremeness' jargon).
	_ok("the inline opt-in reads 'Allow beyond-human extremes'",
		masc_optin != null and String(masc_optin.text) == "Allow beyond-human extremes",
		"text=%s" % (String(masc_optin.text) if masc_optin != null else "<null>"))

	# (6) flipping the inline opt-in widens caps; lowering never snaps ----------------
	print("--- (6) the inline opt-in drives the global widening; lowering is non-destructive ---")
	var cap_off: Array = caps.cap("masculinity")
	masc_optin.button_pressed = true   # emits toggled → _set_extremeness(1.0)
	await get_tree().process_frame
	var cap_on: Array = caps.cap("masculinity")
	_ok("the inline opt-in WIDENS the range past its human edge",
		float(cap_on[1]) > float(cap_off[1]) or float(cap_on[0]) < float(cap_off[0]),
		"off=%s on=%s" % [str(cap_off), str(cap_on)])
	var beyond := float(cap_on[1])
	bs.masculinity = beyond
	masc_optin.button_pressed = false  # _set_extremeness(0.0)
	await get_tree().process_frame
	_ok("lowering the inline opt-in does NOT snap the beyond-human value",
		is_equal_approx(bs.masculinity, beyond), "value=%.3f beyond=%.3f" % [bs.masculinity, beyond])

	# (7) history overlay does NOT overlap the pinned strip ------------------------
	print("--- (7) the history overlay rect does not intersect the pinned strip rect ---")
	var hist_panel := cc.get("_history_panel") as Control
	# Open it so it has a laid-out rect.
	cc.call("_toggle_history_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	var strip: Control = null
	var panels: Array = []
	_collect(cc, "PanelContainer", panels)
	for p in panels:
		if String((p as Node).name) == "PinnedStrip":
			strip = p
			break
	var hist_rect := hist_panel.get_global_rect()
	var strip_rect := strip.get_global_rect()
	_ok("history overlay rect does NOT intersect the pinned-strip rect",
		not hist_rect.intersects(strip_rect),
		"hist=%s strip=%s" % [str(hist_rect), str(strip_rect)])

	# (8) exactly one history affordance; no standalone undo/redo icons -----------
	print("--- (8) a single history affordance; no redundant undo/redo icon buttons ---")
	ui = []
	_texts(cc, ui)
	var hist_n := 0
	for t in ui:
		if String(t).contains("History"):
			hist_n += 1
	_ok("exactly ONE history affordance", hist_n == 1, "count=%d" % hist_n)
	# The old top-right icon buttons used the ↶ / ↷ glyphs — they must be gone.
	var glyph_btns := 0
	for t in ui:
		if String(t) == "↶" or String(t) == "↷":
			glyph_btns += 1
	_ok("no standalone undo/redo glyph icon buttons remain", glyph_btns == 0, "glyphs=%d" % glyph_btns)
	_ok("the _undo_btn / _redo_btn members are gone",
		not cc.get_property_list().any(func(p): return String(p.name) in ["_undo_btn", "_redo_btn"]),
		"properties absent")

	cc.queue_free()
