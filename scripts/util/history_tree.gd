## HistoryTree — a generic, deterministic undo TREE (not a linear stack).
##
## State-agnostic: each node holds an opaque `state` Variant (here a BodyState
## Dictionary). The tree is the canonical edit-history structure for the character
## creator, but it has NO scene/render dependency — it is pure RefCounted GDScript
## so it unit-tests headlessly and round-trips deterministically.
##
## WHY A TREE, NOT A STACK: a linear undo stack DISCARDS the redo branch the moment
## you commit after undoing. A tree PRESERVES it as a sibling branch. After `undo()`
## then `commit()`, the previously-current child and its whole subtree stay reachable
## via `jump_to()` — that branching is the entire point (the "lived history" /
## variety power-fantasy: explore an edit, back up, explore another, keep both).
##
## DETERMINISM (a hard invariant of the seeded sim, CLAUDE.md): node ids are a
## monotonic int counter ONLY — never wall-clock, never RNG. The same commit
## sequence from a fresh tree yields byte-identical ids, structure, and current
## pointer every time, so the tree fits seed + action-log replay and diffs cleanly.
class_name HistoryTree
extends RefCounted

## All nodes by id. Each node is a Dictionary:
##   {
##     id: int,                # monotonic, deterministic
##     parent_id: int,         # -1 for the root
##     children_ids: Array[int],
##     state: Variant,         # opaque payload (a BodyState dict here)
##     label: String,          # human-readable cause, e.g. "age = 30"
##     preferred_child: int,   # last-taken child for redo to follow (-1 = none)
##   }
var _nodes: Dictionary = {}
var _current_id: int = -1
var _next_id: int = 0


## Construct a tree rooted at `initial_state` (label defaults to "initial").
func _init(initial_state: Variant = null, root_label: String = "initial") -> void:
	var rid := _alloc_id()
	_nodes[rid] = _make_node(rid, -1, initial_state, root_label)
	_current_id = rid


func _alloc_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


static func _make_node(id: int, parent_id: int, state: Variant, label: String) -> Dictionary:
	return {
		"id": id,
		"parent_id": parent_id,
		"children_ids": [],
		"state": state,
		"label": label,
		"preferred_child": -1,
	}


# ---------------------------------------------------------------------------
# Mutation
# ---------------------------------------------------------------------------

## Commit `state` as a NEW child of the current node and move current to it.
## If you previously undid (current is not a leaf), this adds a SIBLING branch —
## the existing children and their subtrees are PRESERVED, not discarded. Returns
## the new node id. The new node becomes its parent's preferred child (so redo,
## after an undo back across it, follows the most recently created path).
##
## HISTORY HYGIENE: a commit whose `state` equals the CURRENT node's state is a NO-OP —
## no node is created and current is unchanged; the existing current id is returned. This
## catches re-settling a slider to the same value and re-applying an identical state
## (repeating the same step must NOT accrete duplicate entries).
func commit(state: Variant, label: String = "") -> int:
	if _current_id >= 0 and states_equal((_nodes[_current_id] as Dictionary)["state"], state):
		return _current_id
	var parent_id := _current_id
	var nid := _alloc_id()
	_nodes[nid] = _make_node(nid, parent_id, state, label)
	var parent: Dictionary = _nodes[parent_id]
	(parent["children_ids"] as Array).append(nid)
	parent["preferred_child"] = nid
	_current_id = nid
	return nid


## Deep value-equality for opaque state payloads (Dictionaries / Arrays / scalars).
## Used by the no-op-commit hygiene guard and the idempotent reset. Order-insensitive
## for Dictionary keys; element-order-sensitive for Arrays. Pure + deterministic.
static func states_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	if ta != typeof(b):
		return false
	if ta == TYPE_DICTIONARY:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k in da:
			if not db.has(k) or not states_equal(da[k], db[k]):
				return false
		return true
	if ta == TYPE_ARRAY:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in aa.size():
			if not states_equal(aa[i], ab[i]):
				return false
		return true
	return a == b


## RESET-TO-NEUTRAL: branch a `neutral_state` node directly off the ROOT, then make it
## current. IDEMPOTENT — if the root already has a child whose state equals `neutral_state`,
## that existing child is REUSED (current jumps to it) rather than creating a duplicate
## empty branch. So clicking reset repeatedly yields exactly ONE neutral branch from root.
## Returns the neutral node's id. Honors the no-op hygiene guard too: if current is already
## the matching neutral child, nothing changes.
func reset_to(neutral_state: Variant, label: String = "reset to neutral") -> int:
	var rid := root_id()
	if rid < 0:
		return _current_id
	# Reuse an existing neutral child of the root if present (idempotent).
	for cid in (_nodes[rid] as Dictionary)["children_ids"]:
		if states_equal((_nodes[int(cid)] as Dictionary)["state"], neutral_state):
			jump_to(int(cid))
			return int(cid)
	# None yet: branch from the root, then commit the neutral state as its child.
	_current_id = rid
	return commit(neutral_state, label)


## Move current -> parent. No-op at the root.
func undo() -> bool:
	var node: Dictionary = _nodes[_current_id]
	var pid: int = node["parent_id"]
	if pid < 0:
		return false
	_current_id = pid
	return true


## Move current -> its preferred child (the most recently created/visited branch).
## No-op at a leaf. Follows `preferred_child`, falling back to the last child.
func redo() -> bool:
	var node: Dictionary = _nodes[_current_id]
	var kids: Array = node["children_ids"]
	if kids.is_empty():
		return false
	var pref: int = node["preferred_child"]
	if pref < 0 or not _nodes.has(pref) or not kids.has(pref):
		pref = kids[kids.size() - 1]
	_current_id = pref
	return true


## Set current to any existing node. Updates the preferred-child pointers along the
## path from the target up to the root, so a subsequent redo from an ancestor follows
## the branch you jumped INTO (jumping is a "visit"). Returns false if id is unknown.
func jump_to(id: int) -> bool:
	if not _nodes.has(id):
		return false
	_current_id = id
	# Mark the visited path: each node prefers the child we descended through.
	var cur: int = id
	while true:
		var node: Dictionary = _nodes[cur]
		var pid: int = node["parent_id"]
		if pid < 0:
			break
		(_nodes[pid] as Dictionary)["preferred_child"] = cur
		cur = pid
	return true


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func current_state() -> Variant:
	return (_nodes[_current_id] as Dictionary)["state"]


func current_id() -> int:
	return _current_id


func root_id() -> int:
	# The root is the only node with parent_id == -1; it always has id 0 in a
	# fresh tree, but resolve it honestly in case of a deserialized tree.
	for id in _nodes:
		if (_nodes[id] as Dictionary)["parent_id"] < 0:
			return int(id)
	return -1


func node_count() -> int:
	return _nodes.size()


func has_node(id: int) -> bool:
	return _nodes.has(id)


func state_of(id: int) -> Variant:
	return (_nodes[id] as Dictionary)["state"] if _nodes.has(id) else null


func label_of(id: int) -> String:
	return str((_nodes[id] as Dictionary)["label"]) if _nodes.has(id) else ""


func children_of(id: int) -> Array:
	return ((_nodes[id] as Dictionary)["children_ids"] as Array).duplicate() if _nodes.has(id) else []


func parent_of(id: int) -> int:
	return int((_nodes[id] as Dictionary)["parent_id"]) if _nodes.has(id) else -1


func can_undo() -> bool:
	return _current_id >= 0 and int((_nodes[_current_id] as Dictionary)["parent_id"]) >= 0


func can_redo() -> bool:
	return _current_id >= 0 and not ((_nodes[_current_id] as Dictionary)["children_ids"] as Array).is_empty()


## The linear path of node ids from the ROOT down to the current node (inclusive),
## ordered root-first. This is the spine the ChatGPT-style branch nav renders top to
## bottom — no indentation, no diagonal. Empty if there is no root.
func path_to_current() -> Array:
	var out: Array = []
	var cur: int = _current_id
	while cur >= 0 and _nodes.has(cur):
		out.append(cur)
		cur = int((_nodes[cur] as Dictionary)["parent_id"])
	out.reverse()
	return out


## The child-branch index of `id` among its parent's children, and the sibling count,
## as { index, count }. Children are ordered ASCENDING by id (the deterministic display
## order). The root (no parent) reports { index: 0, count: 1 }. Unknown id -> { index: -1, count: 0 }.
func sibling_index(id: int) -> Dictionary:
	if not _nodes.has(id):
		return {"index": -1, "count": 0}
	var pid: int = int((_nodes[id] as Dictionary)["parent_id"])
	if pid < 0:
		return {"index": 0, "count": 1}
	var kids: Array = (_nodes[pid] as Dictionary)["children_ids"]
	var sorted := kids.duplicate()
	sorted.sort()
	return {"index": sorted.find(id), "count": sorted.size()}


## True if `id` is a JUNCTION — a node with more than one child, where the linear nav
## must offer a `‹ i/n ›` branch selector to choose which child to follow.
func is_junction(id: int) -> bool:
	return _nodes.has(id) and ((_nodes[id] as Dictionary)["children_ids"] as Array).size() > 1


## The child of `id` at sibling display-index `child_index` (ascending-id order), or -1
## if out of range / unknown. Used by the branch selector arrows.
func child_at(id: int, child_index: int) -> int:
	if not _nodes.has(id):
		return -1
	var kids: Array = (_nodes[id] as Dictionary)["children_ids"]
	if child_index < 0 or child_index >= kids.size():
		return -1
	var sorted := kids.duplicate()
	sorted.sort()
	return int(sorted[child_index])


## Follow the preferred-child chain from `id` down to a leaf, returning the leaf id.
## (preferred_child, falling back to the last child.) Used so SWITCHING a junction's
## branch lands current on a concrete descendant, not the junction itself.
func leaf_following_preferred(id: int) -> int:
	if not _nodes.has(id):
		return id
	var cur: int = id
	var node: Dictionary = _nodes[cur]
	var kids: Array = node["children_ids"]
	while not kids.is_empty():
		var pref: int = int(node["preferred_child"])
		if pref < 0 or not _nodes.has(pref) or not (kids as Array).has(pref):
			pref = int(kids[kids.size() - 1])
		cur = pref
		node = _nodes[cur]
		kids = node["children_ids"]
	return cur


## Switch the branch followed FROM junction `junction_id` to its child at display-index
## `child_index`, then jump current onto that child's preferred-child leaf. This is the
## branch-nav arrow action: pick a sibling branch and follow it to its tip. Returns the
## new current id, or -1 on a bad index / unknown node.
func switch_branch(junction_id: int, child_index: int) -> int:
	var child := child_at(junction_id, child_index)
	if child < 0:
		return -1
	var leaf := leaf_following_preferred(child)
	jump_to(leaf)
	return _current_id


## A flat structure snapshot for the UI: an ordered list of
## { id, parent_id, depth, label, is_current, child_count } produced by a
## deterministic depth-first pre-order walk from the root, descending children in
## ascending id order (so the displayed tree is stable across runs).
func structure() -> Array:
	var out: Array = []
	var rid := root_id()
	if rid < 0:
		return out
	_walk(rid, 0, out)
	return out


func _walk(id: int, depth: int, out: Array) -> void:
	var node: Dictionary = _nodes[id]
	out.append({
		"id": id,
		"parent_id": node["parent_id"],
		"depth": depth,
		"label": node["label"],
		"is_current": id == _current_id,
		"child_count": (node["children_ids"] as Array).size(),
	})
	var kids: Array = (node["children_ids"] as Array).duplicate()
	kids.sort()  # ascending id -> deterministic display order
	for k in kids:
		_walk(int(k), depth + 1, out)


# ---------------------------------------------------------------------------
# Serialization — round-trips the WHOLE tree + current pointer + id counter.
# Deterministic: nodes are emitted in ascending id order.
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var node_list: Array = []
	var ids: Array = _nodes.keys()
	ids.sort()
	for id in ids:
		var n: Dictionary = _nodes[id]
		node_list.append({
			"id": n["id"],
			"parent_id": n["parent_id"],
			"children_ids": (n["children_ids"] as Array).duplicate(),
			"state": n["state"],
			"label": n["label"],
			"preferred_child": n["preferred_child"],
		})
	return {
		"version": 1,
		"next_id": _next_id,
		"current_id": _current_id,
		"nodes": node_list,
	}


static func from_dict(d: Dictionary) -> HistoryTree:
	var t := HistoryTree.new(null)
	t._nodes = {}
	t._next_id = int(d.get("next_id", 0))
	t._current_id = int(d.get("current_id", -1))
	for raw in d.get("nodes", []):
		var n: Dictionary = raw
		var id := int(n["id"])
		# JSON parses numbers as floats; coerce child ids back to ints so a
		# round-tripped tree's to_dict() is byte-identical to the original's.
		var kids: Array = []
		for k in n.get("children_ids", []):
			kids.append(int(k))
		t._nodes[id] = {
			"id": id,
			"parent_id": int(n["parent_id"]),
			"children_ids": kids,
			"label": str(n.get("label", "")),
			"state": n.get("state", null),
			"preferred_child": int(n.get("preferred_child", -1)),
		}
	return t
