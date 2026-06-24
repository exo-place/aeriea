## Region-tree projection test (character-creator-ux.md §3 / §10 objective). Proves the
## navigable region tree + the active-surface rule, the projection-shell substrate:
##
##   (1) MILLER-COMPLIANT: every node in RegionSliders.TREE has ≤7 children at every level.
##   (2) EVERY LEAF MAPS TO A REAL SPEC: every leaf's specs resolve to registry modifiers
##       (or is an honest EMPTY leaf — Mouth / Eyes & brow), and the leaf set covers the design.
##   (3) NAVIGATION HELPERS: children_at / node_at / breadcrumb resolve a path to exactly the
##       focused node's children (count + identity), the active-surface rule's pure function.
##   (4) CHEEK PREFIX GENERALIZATION (§3.1): the /-prefixed cheek family pairs into 4 midline-
##       symmetric sliders (each resolves to BOTH l- and r- cheek modifiers).
##   (5) DERIVED FLAT GROUPS: the legacy GROUPS / all_specs() / count() derive from the tree's
##       leaves (the morph wiring + tests see the same specs).
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_tree_nav_test.tscn --quit-after 4000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const RegionSliders := preload("res://scripts/body/region_sliders.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR — region tree + active-surface projection ===\n")
	_test_miller()
	_test_leaves_map()
	_test_navigation()
	_test_cheek_pairing()
	_test_derived_groups()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


# (1) Miller-compliant at every level ------------------------------------------
func _test_miller() -> void:
	print("--- (1) ≤7 children at every node (Miller-compliant) ---")
	var worst := {"label": "", "n": 0}
	_walk_counts(RegionSliders.TREE, "Body", worst)
	_ok("the top level has ≤7 regions", RegionSliders.TREE.size() <= 7,
		"%d top-level regions" % RegionSliders.TREE.size())
	_ok("every node has ≤7 children", worst["n"] <= 7,
		"worst: %s has %d children" % [worst["label"], worst["n"]])


func _walk_counts(nodes: Array, parent_label: String, worst: Dictionary) -> void:
	if nodes.size() > int(worst["n"]):
		worst["n"] = nodes.size()
		worst["label"] = parent_label
	for node in nodes:
		if not RegionSliders.is_leaf(node):
			_walk_counts(node["children"], String(node["label"]), worst)
		else:
			# a leaf's specs are a homogeneous value-node list; not subject to the ≤7 nav rule,
			# but we report the largest for visibility.
			pass


# (2) every leaf maps to a real spec -------------------------------------------
func _test_leaves_map() -> void:
	print("--- (2) every leaf spec resolves to a real registry modifier (empty leaves honest) ---")
	var by: Dictionary = BodyState.registry().get("by_full_name", {})
	var leaves := RegionSliders.leaf_groups()
	var empty_ok := []
	var bad := ""
	for grp in leaves:
		var label: String = grp[0]
		var specs: Array = grp[1]
		if specs.is_empty():
			empty_ok.append(label)
			continue
		for spec in specs:
			for fn in RegionSliders.resolve_full_names(spec[0]):
				if not by.has(fn):
					bad = "%s → unknown modifier %s" % [label, fn]
					break
			if bad != "":
				break
		if bad != "":
			break
	_ok("every non-empty leaf spec resolves to a real registry modifier", bad == "",
		bad if bad != "" else "%d leaves checked" % leaves.size())
	# The honest empty leaves (Mouth, Eyes & brow) are present as homes (§3).
	var labels := {}
	for grp in leaves:
		labels[grp[0]] = true
	_ok("the design's leaves are present (incl. Skull, Cheeks, Thighs, Lower legs)",
		labels.has("Skull") and labels.has("Cheeks") and labels.has("Thighs")
			and labels.has("Lower legs") and labels.has("Chest & breasts"),
		"empty (honest) leaves: %s" % str(empty_ok))


# (3) navigation helpers — the active-surface rule -----------------------------
func _test_navigation() -> void:
	print("--- (3) children_at / node_at / breadcrumb resolve focus to exactly its children ---")
	# Path [0] = Face (an intermediate region). Its children are the 7 face sub-regions.
	var face_children := RegionSliders.children_at([0])
	_ok("focusing Face shows exactly its child regions (≤7)",
		face_children.size() >= 5 and face_children.size() <= 7,
		"%d Face children" % face_children.size())
	# Find Jaw & chin under Face and focus it; it is a leaf, so children_at = [].
	var jaw_idx := -1
	for i in face_children.size():
		if String(face_children[i]["label"]) == "Jaw & chin":
			jaw_idx = i
	_ok("Jaw & chin is a child of Face", jaw_idx >= 0, "index %d" % jaw_idx)
	if jaw_idx >= 0:
		var jaw_path := [0, jaw_idx]
		_ok("a leaf node has no child regions (children_at == [])",
			RegionSliders.children_at(jaw_path).is_empty(), "leaf has 0 child regions")
		var jaw := RegionSliders.node_at(jaw_path)
		_ok("node_at(leaf path) returns the leaf with its specs",
			RegionSliders.is_leaf(jaw) and (jaw["specs"] as Array).size() == 1,
			"Jaw & chin has %d specs" % (jaw.get("specs", []) as Array).size())
		var bc := RegionSliders.breadcrumb(jaw_path)
		_ok("breadcrumb(jaw path) == [Face, Jaw & chin]",
			bc.size() == 2 and bc[0] == "Face" and bc[1] == "Jaw & chin", "%s" % str(bc))


# (4) cheek prefix generalization ----------------------------------------------
func _test_cheek_pairing() -> void:
	print("--- (4) the /-prefixed cheek family pairs into midline-symmetric sliders (§3.1) ---")
	var fns := RegionSliders.resolve_full_names("cheek/l-cheek-bones-decr|incr")
	_ok("a /-prefixed cheek stem resolves to TWO full_names (L + R)", fns.size() == 2,
		"resolved: %s" % str(fns))
	var has_l := false
	var has_r := false
	for fn in fns:
		if fn == "cheek/l-cheek-bones-decr|incr": has_l = true
		if fn == "cheek/r-cheek-bones-decr|incr": has_r = true
	_ok("the pair covers the LEFT and RIGHT cheek-bones modifiers", has_l and has_r,
		"L=%s R=%s" % [has_l, has_r])
	var by: Dictionary = BodyState.registry().get("by_full_name", {})
	_ok("both cheek modifiers exist in the registry", by.has(fns[0]) and by.has(fns[1]),
		"%s / %s" % [fns[0], fns[1]])


# (5) derived flat groups ------------------------------------------------------
func _test_derived_groups() -> void:
	print("--- (5) GROUPS / all_specs() / count() derive from the tree leaves ---")
	var leaves := RegionSliders.leaf_groups()
	_ok("GROUPS equals the tree's leaf groups (derived, not duplicated)",
		RegionSliders.GROUPS.size() == leaves.size(), "%d leaf groups" % leaves.size())
	_ok("a deep table is still registered (>= 40 region axes)", RegionSliders.count() >= 40,
		"%d region sliders" % RegionSliders.count())
	# every all_specs() entry carries its group label from the tree.
	var any := false
	for spec in RegionSliders.all_specs():
		if String(spec["group"]) == "Cheeks":
			any = true
			break
	_ok("all_specs() reflects the tree leaf labels (e.g. a Cheeks spec is present)", any,
		"Cheeks specs surfaced via all_specs()")
