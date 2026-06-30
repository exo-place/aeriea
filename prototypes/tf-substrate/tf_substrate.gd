## THROWAWAY PROTOTYPE — body/transformation substrate kernel.
##
## Expected-wrong learning artifact. NOT wired into any game scene. The point is
## a runnable thing to react to, grounded in the certified floor
## (docs/decisions/body-transformation-substrate.md), deliberately avoiding the
## extra machinery of the prior synthesis (no run/instance/store/resolver/registry
## objects, no blessed id/uid, no recompute-discipline baked into the engine, no
## attachment-position metadata concept). See the friction log returned with this
## prototype for where the floor under-determined the build.
##
## THE KERNEL, in full:
##   - A Part is a parent + an ORDERED list of children + a metadata map. No id.
##     A part is just its position in the tree plus its metadata.
##   - Metadata values are opaque & arbitrary (scalars AND lists/maps). The
##     substrate never interprets them.
##   - Some metadata entries are EXPRESSIONS (Expr): a pure function of readable
##     context that returns the new value for the (part,key) it is bound to. It
##     READS its own current value, its part's metadata, 1-hop structure (parent /
##     direct children), and `select(pred)` over the tree. It WRITES ONLY its own
##     bound (part,key) — pull, not push.
##   - A TICK collects every (part,key) expression, evaluates them in the
##     deterministic total order (preorder-DFS index, then author priority, then
##     authoring index within the part), folding LEFT and mutating in place. A
##     later expression reading an already-evaluated value sees the new one; the
##     one-tick lag for not-yet-evaluated reads emerges from this — no buffer, no
##     snapshot.
##   - Determinism: no RNG outside the seed. Randomness = a seeded draw keyed off
##     (seed + a deterministic coordinate). Same seed => identical run.
##   - Pause & probabilistic transformation are NOT special: they are ordinary
##     expressions that early-return their current value unchanged.
class_name TF
extends RefCounted


## A node in the body tree. No blessed id/uid — a Part IS its position in the
## tree plus its metadata. `meta` insertion order is preserved (GDScript Dict),
## which is the authoring order the tick relies on.
class Part:
	extends RefCounted
	var parent: Part = null
	var children: Array = []  ## ordered Array[Part]
	var meta: Dictionary = {}

	func attach(child: Part) -> Part:
		child.parent = self
		children.append(child)
		return child


## A metadata entry that is an expression. `value` is its current materialized
## value (read by other expressions exactly like any opaque metadata value);
## `fn` recomputes it each tick from a context dict. `priority` is the author's
## within-part ordering lever; `aidx` is the global authoring index.
##
## JUDGMENT CALL (see friction log): the floor says "some metadata entries are
## expressions ... returning the new value for the key it is bound to", but does
## not say how an expression and the value it produces coexist at one key across
## ticks. Here the cell permanently holds the Expr object and the produced value
## lives inside it (`.value`). Readers go through `mget()` so they never see the
## Expr, only its opaque value.
class Expr:
	extends RefCounted
	var fn: Callable
	var value  ## current materialized value (Variant)
	var priority: int = 0
	var aidx: int = 0

	func _init(f: Callable, initial, prio: int = 0) -> void:
		fn = f
		value = initial
		priority = prio


var seed: int = 0
var _aidx_counter: int = 0


func _init(s: int = 0) -> void:
	seed = s


## Author helper: build an expression cell. Assigns the next global authoring
## index. Put the returned Expr into a part's meta under the key it computes.
func expr(fn: Callable, initial, priority: int = 0) -> Expr:
	var e := Expr.new(fn, initial, priority)
	e.aidx = _aidx_counter
	_aidx_counter += 1
	return e


## Read the materialized opaque value at (part, key): an Expr resolves to its
## current `.value`; anything else is returned as-is. This is the ONLY way the
## substrate or an expression reads metadata — Expr objects are never exposed.
static func mget(part: Part, key: String):
	if part == null:
		return null
	var v = part.meta.get(key)
	if v is Expr:
		return v.value
	return v


## Preorder DFS of the tree: visit a part, then its children in sibling order.
func _preorder(root: Part) -> Array:
	var out: Array = []
	_pre(root, out)
	return out


func _pre(p: Part, out: Array) -> void:
	out.append(p)
	for c in p.children:
		_pre(c, out)


## `select(pred)` over the whole tree, returned in preorder (intrinsic
## structural order). Topology-independent: predicate matches on content; the
## ORDER of results is the tree's own shape.
func _select(root: Part, pred: Callable) -> Array:
	var out: Array = []
	for p in _preorder(root):
		if pred.call(p):
			out.append(p)
	return out


## Deterministic seeded draw in [0,1) keyed off (seed + an author-supplied
## deterministic coordinate). No native RNG. Same (seed, coord) => same draw.
func draw(coord) -> float:
	var c: int = coord if coord is int else hash(coord)
	var z: int = seed * 2654435761 + c * 40503 + -7046029254386353131  # 0x9e3779b97f4a7c15 as signed
	z = (z ^ (z >> 30)) * -0x40a7b892e31b1a47  # 0xbf58476d1ce4e5b9 as signed
	z = (z ^ (z >> 27)) * -0x6b2fb644ecceee15  # 0x94d049bb133111eb as signed
	z = z ^ (z >> 31)
	return float(z & 0xFFFFFF) / float(0x1000000)


## ONE TICK: collect every (part,key) expression, sort by the deterministic
## total order, fold left mutating in place.
func tick(root: Part) -> void:
	var order := _preorder(root)
	# Collect expressions tagged with their preorder index.
	var items: Array = []  # each: {pidx, priority, aidx, part, key, expr}
	for pidx in order.size():
		var part: Part = order[pidx]
		for key in part.meta.keys():  # insertion (authoring) order
			var v = part.meta[key]
			if v is Expr:
				items.append({
					"pidx": pidx, "priority": v.priority, "aidx": v.aidx,
					"part": part, "key": key, "expr": v,
				})
	# Deterministic total order: (preorder index, priority, authoring index).
	items.sort_custom(func(a, b):
		if a.pidx != b.pidx: return a.pidx < b.pidx
		if a.priority != b.priority: return a.priority < b.priority
		return a.aidx < b.aidx)
	# Fold left, mutating in place. A later read of an already-evaluated cell
	# sees the new value; not-yet-evaluated reads see last tick's value.
	for it in items:
		var e: Expr = it.expr
		var part: Part = it.part
		var ctx := {
			"current": e.value,
			"host": part,
			"root": root,
			"seed": seed,
			"select": func(pred): return _select(root, pred),
			"draw": func(coord): return draw(coord),
			"mget": func(p, k): return mget(p, k),
		}
		e.value = e.fn.call(ctx)
