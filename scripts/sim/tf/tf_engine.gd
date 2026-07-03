## The tick and the replay driver — the whole EXECUTION model.
##
## A transformation is now AUTHORED CONTENT, not engine code: a marinada expression
## (see tf_marinada.gd, tf_library.gd) referenced by a plain `kind` string. The
## mapping kind -> definition is `library`, a plain Dictionary kind -> marinada
## closure resolved once from an authored module (TFLibrary.build). This is the
## data/computation seam: the tree (plus each part's transition list) is DATA;
## `library` is the separate, authored COMPUTATION.
##
## The engine calls a definition closure with the fixed argument tuple
##
##     (part, root, tr, seed, coord, idx, ntrans)
##
## and the definition RETURNS a pure result record — marinada stays pure, the
## ENGINE owns mutation and eval order:
##
##     { "transition": <new transition record>, "fields": <record field -> value> }
##
## The engine replaces the transition-list entry with `transition` and writes each
## `fields` entry into `part.fields` IN PLACE.
##
## A TICK evaluates every active transition in one DETERMINISTIC TOTAL ORDER:
## parts in tree PRE-ORDER, and within a part its transition list in order. Fields
## are mutated IN PLACE — no snapshot, no previous-state buffer. A cross-part read
## therefore sees this-tick values from sources earlier in the order and last-tick
## values from sources later: the one-tick lag is EMERGENT from the order, not a
## stored buffer. There is no priority field and no authoring index — pre-order +
## list order IS the whole order.
##
## DETERMINISM is seed + action log. An ACTION is a plain-data record that mutates
## the tree / starts or stops transitions / writes fields. `run_log` folds a log of
## actions and `tick` markers over a freshly-built tree; re-running the same seed +
## same log reproduces identical final state with no stored world snapshot.
class_name TFEngine
extends RefCounted

## Advance the whole body one tick. `library` maps a transition's `kind` to its
## authored marinada definition closure. See the class doc for the ordering and the
## pure-return / engine-writes contract.
static func tick(root: TFPart, library: Dictionary, seed: int = 0) -> void:
	var order := TFTree.preorder(root)
	for pi in range(order.size()):
		var part: TFPart = order[pi]
		if not part.fields.has("transitions"):
			continue
		var trans: Array = part.fields["transitions"]
		# Snapshot the count so transitions appended THIS tick to THIS part do not
		# run until next tick (keeps the per-part order stable within a tick).
		var n := trans.size()
		for ti in range(n):
			var tr: Dictionary = trans[ti]
			var kind: Variant = tr.get("kind")
			if not library.has(kind):
				continue
			var coord := TFRng.mix2(pi, ti)
			# Pure evaluation returns the new transition + field writes; the engine
			# performs the in-place mutation, keeping marinada pure.
			var result: Variant = TFMarinada.apply(library[kind], [part, root, tr, seed, coord, ti, n])
			if result is Dictionary:
				trans[ti] = result.get("transition", tr)
				var writes: Variant = result.get("fields", {})
				if writes is Dictionary:
					for f in writes:
						part.fields[f] = writes[f]


# ---------------------------------------------------------------------------
# Actions (external inputs) and the replay driver.
# ---------------------------------------------------------------------------

## Build a field predicate from a plain `where` spec (so a log stays plain data):
##   {}                              -> matches the root only
##   {"all": true}                   -> matches every part
##   {"field": "kind", "eq": "tail"} -> field equality
static func _pred_from_where(root: TFPart, where: Dictionary) -> Callable:
	if where.get("all", false):
		return func(_p: TFPart) -> bool: return true
	if where.has("field"):
		var name: String = where["field"]
		var val: Variant = where["eq"]
		return func(p: TFPart) -> bool: return p.fields.get(name) == val
	# Default: the root part only.
	return func(p: TFPart) -> bool: return p == root


static func _targets(root: TFPart, where: Dictionary) -> Array:
	return TFTree.find_all(root, _pred_from_where(root, where))


## Apply one action record to the tree (or advance a tick). Ops:
##   {"op": "tick"}                                     — advance one tick
##   {"op": "set_field", "where": …, "field": …, "value": …}
##   {"op": "start", "where": …, "transition": {…}}     — append a transition
##   {"op": "stop",  "where": …, "kind": "…"}           — drop transitions of kind
static func apply_action(root: TFPart, action: Dictionary, library: Dictionary, seed: int) -> void:
	match action.get("op"):
		"tick":
			tick(root, library, seed)
		"set_field":
			for p in _targets(root, action.get("where", {})):
				p.fields[action["field"]] = action["value"]
		"start":
			for p in _targets(root, action.get("where", {})):
				# Deep-copy the transition so each target gets its own progress.
				p.transitions().append(TFPart._deep_copy_value(action["transition"]))
		"stop":
			var kind: Variant = action.get("kind")
			for p in _targets(root, action.get("where", {})):
				if p.fields.has("transitions"):
					var keep: Array = []
					for tr in p.fields["transitions"]:
						if tr.get("kind") != kind:
							keep.append(tr)
					p.fields["transitions"] = keep
		_:
			push_error("TFEngine.apply_action: unknown op %s" % str(action.get("op")))


## Replay a whole log from scratch: build a fresh tree with `builder`, then fold
## every log entry (actions + tick markers) over it. Pure in (seed, log): the same
## seed and the same log yield an identical final tree, with no stored snapshot.
static func run_log(seed: int, builder: Callable, log: Array, library: Dictionary) -> TFPart:
	var root: TFPart = builder.call()
	for entry in log:
		apply_action(root, entry, library, seed)
	return root
