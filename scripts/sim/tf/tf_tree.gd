## Tree queries — how a transformation REFERENCES another part.
##
## A transformation never holds a pointer, an id, or a brittle index path to
## another part. It finds the part it means by READING THE TREE and matching on
## the part's OWN FIELDS (what the part IS), and by RELATIONAL traversal over the
## attachment structure (where the part is). Two axes, one principle:
##
##   IDENTITY lives in FIELDS  — kind / form: true wherever the part is attached.
##   LOCATION lives in STRUCTURE — attachment is the single source of truth.
##
## So "my nearest torso" is a structural walk; "a breast" is a field predicate;
## "the front torso" (of two identical torsos) is the field predicate PLUS a
## structural discriminator. No location field, no id, ever.
##
## Every helper here is a pure static function over plain TFPart data.
class_name TFTree
extends RefCounted

# A predicate is a Callable (part: TFPart) -> bool. Build one with `field_is`
# for the common "field == value" case, or hand-write any Callable.


## Predicate: the part's field `name` equals `value`. The bread-and-butter
## field match — `field_is("kind", "breast")`.
static func field_is(name: String, value: Variant) -> Callable:
	return func(p: TFPart) -> bool:
		return p.fields.get(name) == value


## Deterministic PRE-ORDER flattening of a subtree (root, then each child's
## subtree left-to-right). This order is the backbone of the tick's total order.
static func preorder(root: TFPart) -> Array:
	var out: Array = []
	_preorder_into(root, out)
	return out


static func _preorder_into(p: TFPart, out: Array) -> void:
	if p == null:
		return
	out.append(p)
	for c in p.children:
		_preorder_into(c, out)


## All parts in the subtree (pre-order) for which `pred` holds. Field-predicate
## search — the "find every breast" primitive.
static func find_all(root: TFPart, pred: Callable) -> Array:
	var out: Array = []
	for p in preorder(root):
		if pred.call(p):
			out.append(p)
	return out


## The first part (pre-order) for which `pred` holds, or null.
static func find_first(root: TFPart, pred: Callable) -> TFPart:
	for p in preorder(root):
		if pred.call(p):
			return p
	return null


## The nearest ANCESTOR of `part` (walking up parents, NOT including `part`) for
## which `pred` holds, or null. "My nearest torso" for a part below it.
static func nearest_ancestor(part: TFPart, pred: Callable) -> TFPart:
	var cur: TFPart = part.parent if part != null else null
	while cur != null:
		if pred.call(cur):
			return cur
		cur = cur.parent
	return null


## Like nearest_ancestor, but also skips any ancestor equal to `exclude`.
## "The nearest torso that isn't me" when `part` itself matches the predicate.
static func nearest_ancestor_excluding(part: TFPart, pred: Callable, exclude: TFPart) -> TFPart:
	var cur: TFPart = part.parent if part != null else null
	while cur != null:
		if cur != exclude and pred.call(cur):
			return cur
		cur = cur.parent
	return null


## The TOPMOST matching part in the chain that runs DOWNWARD from `part` through
## matching parts: starting at the nearest matching part at-or-below the search
## root, follow matching descendants as far as they chain. Concretely for the
## torso spine: from the pelvis, the chain torso_rear -> torso_front, and the
## topmost (deepest) torso in that chain is torso_front. Returns null if `from`
## has no matching descendant.
##
## "Chain" = a single matching part continued by exactly the matching parts among
## its descendants; we descend into the first matching descendant each step,
## which for a spine (one torso stacked on another) walks to the far end.
static func topmost_in_chain(from: TFPart, pred: Callable) -> TFPart:
	# Find where the chain starts: the nearest matching part in `from`'s subtree.
	var start := find_first(from, pred)
	if start == null:
		return null
	var cur := start
	var nxt := _first_matching_child(cur, pred)
	while nxt != null:
		cur = nxt
		nxt = _first_matching_child(cur, pred)
	return cur


static func _first_matching_child(p: TFPart, pred: Callable) -> TFPart:
	for c in p.children:
		if pred.call(c):
			return c
	return null


## Does `part` have ANY ancestor matching `pred`? A structural discriminator:
## of two identical torsos, the chained-above one has a torso ancestor and the
## base one does not — distinguishing them with no id and no location field.
static func has_ancestor(part: TFPart, pred: Callable) -> bool:
	return nearest_ancestor(part, pred) != null
