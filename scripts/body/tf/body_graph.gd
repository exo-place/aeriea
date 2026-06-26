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
const NON_FLESH_MATERIALS := ["chitin", "slime", "stone", "energy"]


## True if `material` carries a separate covering (flesh-type). Chitin/slime/etc. are
## their own surface and take covering=null.
static func material_takes_covering(material: String) -> bool:
	return not (material in NON_FLESH_MATERIALS)


# --- segment construction -------------------------------------------------------

## Build a generic segment dict. `covering` is nulled automatically if `material`
## takes none. `props`/`tags`/`children` default to empty.
static func segment(
		id: String, material: String, covering, props: Dictionary = {},
		tags: Array = [], children: Array = []) -> Dictionary:
	var cov = covering
	if not material_takes_covering(material):
		cov = null
	return {
		"id": id, "material": material, "covering": cov,
		"props": props.duplicate(true), "tags": tags.duplicate(),
		"children": children.duplicate(true),
	}


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
	return parsed
