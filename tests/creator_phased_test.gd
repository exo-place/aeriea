## Phase D test — UI-interaction polish (character-creator-ux.md §8.0 / §8.1 / §8.4).
## OBJECTIVE clauses only (aesthetics + felt quality are USER-judged from the render harness):
##
##   HISTORY — human labels + collapse:
##   (1) re-editing the SAME value does NOT create N history nodes (collapse to one).
##   (2) history labels read in HUMAN terms (display name + direction word), NEVER modifier-space:
##       no node label contains "=" or a raw "+0." / "field_name = " modifier string.
##   (3) editing a DIFFERENT value opens a new node (collapse is per-value, not global).
##
##   SHARE / OPEN — single affordances:
##   (4) exactly ONE "Share" top-bar button and exactly ONE "Open" top-bar button (no 4-button
##       export stack, no separate import button); a Share→Open round-trip works underneath.
##
##   LIMITS — plain "Allow beyond-human extremes":
##   (5) NO "extremeness" / "%" / "Realism" / "Stylized" jargon string anywhere in the built UI.
##   (6) the opt-in WIDENS caps when on (a control can then exceed its normal range), and lowering
##       it never SNAPS an existing beyond-cap value (the non-destructive ratchet, §8.4).
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_phased_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const CharacterCreator := preload("res://scripts/body/character_creator.gd")
const CreatorIOScript := preload("res://scripts/body/creator_io.gd")
const HistoryTreeScript := preload("res://scripts/util/history_tree.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR PHASE D — history collapse + human labels, Share/Open, plain limit ===\n")
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


## Every node-label currently in the history tree, root→all.
func _all_labels(hist) -> Array:
	var out: Array = []
	for entry in hist.structure():
		out.append(String(entry["label"]))
	return out


## Recursively collect the visible TEXT of every Control under `n` (Button/Label/CheckBox text,
## tooltip excluded — the surface a player reads). Pops up the advanced popup contents too.
func _collect_ui_text(n: Node, out: Array) -> void:
	if n is Button or n is Label or n is CheckBox:
		out.append(String((n as Control).text))
	if n is PopupMenu:
		var pm := n as PopupMenu
		for i in pm.item_count:
			out.append(pm.get_item_text(i))
	for c in n.get_children():
		_collect_ui_text(c, out)


func _run() -> void:
	var cc := CharacterCreator.new()
	add_child(cc)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: BodyState = cc.get("_body_state")
	# A persisted autosave (the dev's saved character) may seed the tree with OLD pre-Phase-D nodes.
	# Replace it with a fresh single-node tree from the CURRENT body so this test is deterministic
	# and isolated — it asserts the labels Phase-D code produces, not stale persisted ones.
	var hist = HistoryTreeScript.new(bs.to_dict(), "initial")
	cc.set("_history", hist)

	# (1) collapse: re-editing the SAME axis many times -> ONE node ----------------
	print("--- (1) re-editing the same value collapses to one history node ---")
	var n0: int = hist.node_count()
	for v in [40.0, 55.0, 62.0, 70.0]:
		bs.masculinity = v
		cc.call("_commit_axis", "masculinity", v)
	var added := int(hist.node_count()) - n0
	_ok("four consecutive edits to masculinity add exactly ONE node (collapse)", added == 1,
		"added=%d" % added)
	_ok("the collapsed node carries the NET latest value", is_equal_approx(float(hist.current_state()["masculinity"]), 70.0),
		"masc=%s" % str(hist.current_state()["masculinity"]))

	# (3) a different value opens a new node --------------------------------------
	print("--- (3) editing a different value opens a new node ---")
	var n1: int = hist.node_count()
	bs.age_years = 30.0
	cc.call("_commit_axis", "age_years", 30.0)
	_ok("editing a different axis (age) opens a NEW node", hist.node_count() == n1 + 1,
		"%d -> %d" % [n1, hist.node_count()])
	# Re-editing masculinity AGAIN now opens a fresh node (it is no longer current).
	var n2: int = hist.node_count()
	bs.masculinity = 75.0
	cc.call("_commit_axis", "masculinity", 75.0)
	_ok("re-editing the first value after another edit opens a new node",
		hist.node_count() == n2 + 1, "%d -> %d" % [n2, hist.node_count()])

	# (2) labels are human, never modifier-space ----------------------------------
	print("--- (2) every history label reads in human terms (no '=' / '+0.' modifier-space) ---")
	var labels := _all_labels(hist)
	var bad := []
	for lbl in labels:
		if lbl == "initial":
			continue
		if lbl.contains("=") or lbl.contains("+0.") or lbl.contains("-0.") or lbl.contains("age_years") \
				or lbl.contains("masculinity") or lbl.contains("sculpt:"):
			bad.append(lbl)
	_ok("no history label contains modifier-space text", bad.is_empty(),
		"labels=%s bad=%s" % [str(labels), str(bad)])
	_ok("the masculinity edits read as a Gender direction word",
		labels.any(func(l): return l.begins_with("Gender")), "labels=%s" % str(labels))

	# (4) exactly one Share + one Open --------------------------------------------
	print("--- (4) exactly one Share affordance and one Open affordance ---")
	var ui: Array = []
	_collect_ui_text(cc, ui)
	var share_n := ui.count("Share")
	var open_n := ui.count("Open")
	_ok("exactly ONE 'Share' button", share_n == 1, "count=%d" % share_n)
	_ok("exactly ONE 'Open' button", open_n == 1, "count=%d" % open_n)
	# No 4-button export stack: the banned legacy labels must be absent.
	var stack := 0
	for t in ui:
		if t in ["Export JSON", "Export image", "Export JSON+history", "Export image+history", "Import"]:
			stack += 1
	_ok("no legacy multi-button export/import stack present", stack == 0, "stack=%d" % stack)

	# Share→Open round-trip underneath (the creator_io read/write still works).
	bs.masculinity = 66.0
	bs.age_years = 41.0
	var json := CreatorIOScript.history_to_json(bs, hist, float(cc.get("_caps").extremeness))
	var parsed := CreatorIOScript.parse_payload(json)
	var rb: BodyState = parsed["body"]
	_ok("Share→Open round-trips the body (creator_io intact)",
		bool(parsed["ok"]) and is_equal_approx(rb.masculinity, 66.0) and is_equal_approx(rb.age_years, 41.0),
		"masc=%.1f age=%.1f" % [rb.masculinity, rb.age_years])

	# (5) no jargon string in the UI ----------------------------------------------
	print("--- (5) no 'extremeness' / 'Realism' / 'Stylized' jargon string in the UI ---")
	var joined := " | ".join(PackedStringArray(ui)).to_lower()
	var banned := ["extremeness", "realism", "stylized", "registry", "tier"]
	var hits := []
	for b in banned:
		if joined.contains(b):
			hits.append(b)
	_ok("no banned-jargon noun appears in any UI string", hits.is_empty(),
		"hits=%s" % str(hits))
	_ok("the plain opt-in 'Allow beyond-human extremes' IS present",
		ui.any(func(t): return t == "Allow beyond-human extremes"), "ui has the opt-in")
	# No standalone '%' amount readout for the limit (the extremeness % readout was removed): the
	# limit opt-in is a single toggle, not a dial. (Value labels like '70%' for muscle are fine —
	# we only assert the limit control itself carries no % amount.)
	_ok("the limit control has no amount slider member", cc.get("_extreme_slider") == null,
		"_extreme_slider=%s" % str(cc.get("_extreme_slider")))

	# (6) the opt-in widens caps; lowering it is non-destructive -------------------
	print("--- (6) beyond-human opt-in widens caps; lowering never snaps existing values ---")
	var caps = cc.get("_caps")
	var field := "masculinity"
	var cap_off: Array = caps.cap(field)            # extremeness 0 (default human range)
	cc.call("_set_extremeness", 1.0)
	var cap_on: Array = caps.cap(field)             # opt-in: widened toward the hard limit
	_ok("opt-in WIDENS the masculinity range past its human edge",
		float(cap_on[1]) > float(cap_off[1]) or float(cap_on[0]) < float(cap_off[0]),
		"off=%s on=%s" % [str(cap_off), str(cap_on)])
	# Push a value into the widened (beyond-human) zone, then lower the opt-in: must NOT snap it.
	var beyond := float(cap_on[1])                  # the widened high edge
	bs.masculinity = beyond
	cc.call("_set_extremeness", 0.0)
	_ok("lowering the opt-in does NOT snap an existing beyond-human value (non-destructive)",
		is_equal_approx(bs.masculinity, beyond), "value=%.3f beyond=%.3f" % [bs.masculinity, beyond])

	cc.queue_free()
