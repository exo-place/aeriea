## BodyGraph — aeriea's mutable compositional body graph (TF system §3).
##
## The body is a graph/tree of GENERIC segments joined at named attachment points.
## There is NO part-kind enum: a segment is just data — {id, material, covering,
## props, tags, children}. An "arm" / "lower_body" is an arrangement of segments plus
## conventional tags (§3.7), never an intrinsic type.
##
## A segment is a plain Dictionary so the whole graph is JSON-serializable (§3.4):
##   { "id": String,                  # unique within this body
##     "material": String,            # axis 2: "flesh"/"chitin"/"slime"/... (open)
##     "covering": String|null,       # axis 3: "skin"/"fur"/"scales"/... (null for non-flesh)
##     "props": { String: float },    # per-segment scalars (length_cm, ...)
##     "tags": [String],              # arbitrary convention tags; engine bakes in none
##     "children": [ {"at": String, "node": Segment} ] }   # attachment_point -> subtree
##
## A BodyState is { "root": Segment, "scalars": { String: float } }.
##
## This file is pure data helpers over those dicts: build, deep-copy, find by id,
## resolve targets (by id / tag / structural subtree), apply the per-axis edits, and
## serialize. No RNG, no clock, no policy — those live in the applier (tf_applier.gd).
class_name BodyGraph
extends RefCounted

# Material values whose surface IS the material itself (no separate covering).
# Open set — these are the few shipped values, not a closed enum (§3.2). A material
# not listed here is treated as flesh-type (takes a covering).
const NON_FLESH_MATERIALS := ["chitin", "slime", "stone", "energy", "keratin"]


## True if `material` carries a separate covering (flesh-type). Chitin/slime/etc. are
## their own surface and take covering=null.
static func material_takes_covering(material: String) -> bool:
	return not (material in NON_FLESH_MATERIALS)


# --- segment construction -------------------------------------------------------

## Build a generic segment dict. `covering` is nulled automatically if `material`
## takes none. `props`/`tags`/`children` default to empty. `fluids` is OPTIONAL
## (§5.1): an array of integer {type, amount, capacity} reservoir blocks. Absent ⇒ no
## fluids (the default; back-compatible with every existing segment) — the key is only
## added when fluids are supplied, so bodies without reservoirs are byte-unchanged.
static func segment(
		id: String, material: String, covering, props: Dictionary = {},
		tags: Array = [], children: Array = [], fluids: Array = []) -> Dictionary:
	var cov = covering
	if not material_takes_covering(material):
		cov = null
	var s := {
		"id": id, "material": material, "covering": cov,
		"props": props.duplicate(true), "tags": tags.duplicate(),
		"children": children.duplicate(true),
	}
	if not fluids.is_empty():
		s["fluids"] = fluids.duplicate(true)
	return s


## A fluid reservoir block (§5.1): integer {type, amount, capacity}. `type` is an open
## string (milk / seed / nectar / …); engine bakes in none.
static func fluid(type: String, amount: int, capacity: int) -> Dictionary:
	return {"type": type, "amount": int(amount), "capacity": int(capacity)}


## A child-edge entry: a subtree docked at attachment point `at`.
static func child(at: String, node: Dictionary) -> Dictionary:
	return {"at": at, "node": node}


# --- deep copy / equality (value semantics over the dict tree) ------------------

static func dup_segment(seg: Dictionary) -> Dictionary:
	return seg.duplicate(true)


static func dup_state(state: Dictionary) -> Dictionary:
	return state.duplicate(true)


# --- traversal ------------------------------------------------------------------

## Depth-first list of every segment dict in the graph, parent before children, and
## children visited in a STABLE order (sorted by child node id) so any iteration that
## feeds a draw is total-ordered (determinism, §5.1). Returns the live segment dicts
## (mutation in place is intended for the applier).
static func all_segments(root: Dictionary) -> Array:
	var out: Array = []
	_collect(root, out)
	return out


static func _collect(seg: Dictionary, out: Array) -> void:
	out.append(seg)
	var kids: Array = seg.get("children", [])
	# Total-order children by node id before recursing.
	var ordered := kids.duplicate()
	ordered.sort_custom(func(a, b): return str(a["node"]["id"]) < str(b["node"]["id"]))
	for edge in ordered:
		_collect(edge["node"], out)


## Find a segment by id anywhere in the graph, or null.
static func find_by_id(root: Dictionary, id: String):
	for seg in all_segments(root):
		if seg["id"] == id:
			return seg
	return null


## Find the parent edge-list and index of the child whose node id == `id`.
## Returns {"parent": Segment, "index": int} or null (root has no parent).
static func find_parent(root: Dictionary, id: String):
	return _find_parent(root, id)


static func _find_parent(seg: Dictionary, id: String):
	var kids: Array = seg.get("children", [])
	for i in kids.size():
		if kids[i]["node"]["id"] == id:
			return {"parent": seg, "index": i, "at": kids[i]["at"]}
		var deeper = _find_parent(kids[i]["node"], id)
		if deeper != null:
			return deeper
	return null


## Segments under a node (the node itself + all descendants), total-ordered.
static func subtree_segments(node: Dictionary) -> Array:
	var out: Array = []
	_collect(node, out)
	return out


# --- target resolution (§3.7: by id, by tag, by structural subtree) -------------

## Resolve the node(s) an op targets. Recognized op keys (checked in this order):
##   "target_node": id            -> [that segment] (or [] if absent)
##   "select": {...}              -> ordinal/compound selector (§3.2):
##       {"select":"all_tagged","tag":t[,"kind":k]}  -> every matching member
##       {"select":"nth_tagged","tag":t[,"kind":k],"index":n} -> zero or one,
##           by node-id order (no-op if fewer than n+1 — §3.7)
##   "tag": tagstr                -> every segment carrying that tag
##   "subtree_tag": tagstr        -> every segment in the subtree(s) rooted at a
##                                   tagged node (fan an op across a region)
##   "subtree_under": id          -> every segment under (and including) that node
## Results are total-ordered by id. A convention-target that matches nothing returns
## [] (the op no-ops — §3.7, correct behavior).
static func resolve_targets(root: Dictionary, op: Dictionary) -> Array:
	var out: Array = []
	if op.has("target_node"):
		var seg = find_by_id(root, op["target_node"])
		if seg != null:
			out.append(seg)
	elif op.has("select"):
		out = _resolve_select(root, op["select"])
	elif op.has("tag"):
		for seg in all_segments(root):
			if op["tag"] in seg.get("tags", []):
				out.append(seg)
	elif op.has("subtree_tag"):
		for seg in all_segments(root):
			if op["subtree_tag"] in seg.get("tags", []):
				for s in subtree_segments(seg):
					if not out.has(s):
						out.append(s)
	elif op.has("subtree_under"):
		var node = find_by_id(root, op["subtree_under"])
		if node != null:
			out = subtree_segments(node)
	out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return out


# Compound/ordinal selectors (§3.2). `all_tagged` returns the whole compound set
# (by node-id order); `nth_tagged` returns zero or one — the index-th member in that
# same order, or [] if the body has fewer than index+1 members (the §3.7 no-op).
# An optional `kind` further filters to members also carrying that tag (e.g. the
# phallic subset of the genital set). Both reduce to tag-resolution + node-id sort,
# so they are sugar, not a new targeting mechanism.
static func _resolve_select(root: Dictionary, sel: Dictionary) -> Array:
	var tag: String = str(sel.get("tag", ""))
	var kind = sel.get("kind", null)
	var matched: Array = []
	for seg in all_segments(root):
		var tags: Array = seg.get("tags", [])
		if tag != "" and not (tag in tags):
			continue
		if kind != null and not (kind in tags):
			continue
		matched.append(seg)
	# Node-id order so "the Nth" is deterministic and replay-safe (§3.2).
	matched.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var kind_kw: String = str(sel.get("select", ""))
	if kind_kw == "nth_tagged":
		var idx: int = int(sel.get("index", 0))
		if idx < 0 or idx >= matched.size():
			return []   # no-op past the end (§3.7)
		return [matched[idx]]
	# all_tagged (default): the whole compound set.
	return matched


# --- form edits -----------------------------------------------------------------

## Graft `subtree` (a segment dict) onto `target_id` at attachment point `at`.
## Returns true on success. Coherence is UNENFORCED (§3.8): any graft is legal.
static func graft(root: Dictionary, target_id: String, at: String, subtree: Dictionary) -> bool:
	var parent = find_by_id(root, target_id)
	if parent == null:
		return false
	var p: Dictionary = parent
	p["children"].append(child(at, dup_segment(subtree)))
	return true


## Remove the subtree rooted at `node_id`; return the detached subtree dict (so it can
## be re-grafted by undo, or kept as its own body for a SPLIT — §4.2), or null if the
## node is the root or not found.
static func remove(root: Dictionary, node_id: String):
	var loc = find_parent(root, node_id)
	if loc == null:
		return null
	var edge = loc["parent"]["children"][loc["index"]]
	loc["parent"]["children"].remove_at(loc["index"])
	return {"at": edge["at"], "node": edge["node"]}


## Re-graft a previously-removed edge (the {at, node} dict from remove()) back onto a
## parent. Used by undo to restore a removed subtree exactly.
static func graft_edge(root: Dictionary, target_id: String, edge: Dictionary) -> bool:
	var parent = find_by_id(root, target_id)
	if parent == null:
		return false
	var p: Dictionary = parent
	p["children"].append(child(edge["at"], edge["node"]))
	return true


## Re-graft a removed edge at a SPECIFIC child index (so undo can restore exact sibling
## order — §5.4). Clamps the index into range; appends if out of range or parent missing.
static func graft_edge_at(root: Dictionary, target_id: String, edge: Dictionary, index: int) -> bool:
	var parent = find_by_id(root, target_id)
	if parent == null:
		return false
	var p: Dictionary = parent
	var kids: Array = p["children"]
	var i := clampi(index, 0, kids.size())
	kids.insert(i, child(edge["at"], edge["node"]))
	return true


## Move `node_id` to dock at (`new_parent_id`, `at`). Returns true on success.
static func reparent(root: Dictionary, node_id: String, new_parent_id: String, at: String) -> bool:
	var edge = remove(root, node_id)
	if edge == null:
		return false
	var ok := graft_edge(root, new_parent_id, {"at": at, "node": edge["node"]})
	return ok


# --- serialization (§3.4) -------------------------------------------------------

## The body state IS plain dicts/arrays/strings/floats — JSON round-trips trivially.
static func to_json(state: Dictionary) -> String:
	return JSON.stringify(state)


static func from_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if parsed.has("root"):
		recast_fluid_ints(parsed["root"])
		recast_int_props(parsed["root"])
	return parsed


## Re-cast every segment's fluid `amount`/`capacity` back to INTEGER after a JSON
## reload (JSON erases the int/float distinction — every number reloads as a float).
## Fluids are integer-only (§5.1), so a reloaded body must restore exact ints for a
## byte-identical round-trip and drift-free determinism. Walks the whole graph.
static func recast_fluid_ints(seg: Dictionary) -> void:
	if seg.has("fluids"):
		for f in seg["fluids"]:
			if f.has("amount"):
				f["amount"] = int(round(float(f["amount"])))
			if f.has("capacity"):
				f["capacity"] = int(round(float(f["capacity"])))
	for edge in seg.get("children", []):
		recast_fluid_ints(edge["node"])


# Props that are CANONICAL INTEGERS (the size model — compound-parts-and-fluids.md §4.3).
# They are stored and round-tripped as ints; JSON reload turns them to float so they must
# be recast, exactly like fluid amounts.
const INT_PROPS := ["volume_ml", "band_cm", "waist_cm", "hip_cm"]


## Re-cast every segment's canonical integer size props (`volume_ml`, `band_cm`) back to
## INTEGER after a JSON reload. Walks the whole graph.
static func recast_int_props(seg: Dictionary) -> void:
	var props: Dictionary = seg.get("props", {})
	for k in INT_PROPS:
		if props.has(k):
			props[k] = int(round(float(props[k])))
	for edge in seg.get("children", []):
		recast_int_props(edge["node"])
