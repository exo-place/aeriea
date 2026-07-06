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
##     { "transition": <new transition record>,
##       "fields":     <record field -> value>,
##       "structural": <optional Array of structural-edit records> }
##
## The engine replaces the transition-list entry with `transition`, writes each
## `fields` entry into `part.fields` IN PLACE, and — the STRUCTURAL channel — applies
## each `structural` edit (add/remove/move a subtree) via TFPart's own add_child /
## detach. This is the discrete-TOPOLOGY half of the topology(discrete) ×
## magnitude(continuous) split (docs/decisions/dynamical-transformation.md): a part
## "grows in" as a discrete graft-at-zero-extent PLUS a continuous magnitude
## transition on the new part — never a half-existing part. Marinada stays PURE:
## it returns a plain-data DESCRIPTION of the edit; the engine (here) performs it.
## The common no-structural-op path is unchanged: absent `structural`, nothing runs.
##
## Structural edit records (each a plain dict; `part`/`at`/`to` are opaque TFPart
## handles from tree queries, defaulting to the transition's own host part):
##   { "op": "graft",    "node": <node-spec>, "at":   <TFPart?> }  — build node-spec, add as child of `at`
##   { "op": "detach",                         "part": <TFPart?> }  — structural remove
##   { "op": "reparent", "to":   <TFPart>,     "part": <TFPart?> }  — detach then re-add under `to`
## A node-spec is plain data describing a new subtree, materialized by `_materialize`:
##   { "fields": <field bag, may include a "transitions" Array>, "children": [ node-spec, ... ] }
## (merge / split from transformation-system.md §4.2 are DEFERRED — graft/detach/
## reparent prove the mechanism; merge/split compose from these plus field writes.)
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
			# LOUD GUARD: a transition whose `kind` is not a String, or names no
			# library definition, silently never fires — a whole authored
			# transition going dark with no signal (exactly the failure the old
			# str-concat/__lit literal-quote confusion produced). Report it by
			# name instead of swallowing it. Report-only: valid programs never
			# reach this branch, so replay results are unchanged.
			if not (kind is String) or not library.has(kind):
				push_error("TFEngine.tick: transition kind %s has no library definition (String naming a lib:tf-core def expected) — transition will NOT fire" % str(kind))
				continue
			# §D [OPEN] draw-stream identity bites HERE: `coord` keys off `pi`, the
			# part's index in THIS tick's pre-order. A structural edit (graft/detach/
			# reparent) that changes how many parts sort before this one shifts `pi`
			# next tick, so a stochastic transition's draw series reshuffles under
			# restructuring. Replay is still EXACT (same seed+log reproduces the same
			# pre-order, hence the same coords); only "this part's stream is stable
			# across a rearrange" is what §D does not yet guarantee. Not fixed here.
			var coord := TFRng.mix2(pi, ti)
			# Pure evaluation returns the new transition + field writes (+ optional
			# structural edits); the engine performs the in-place mutation, keeping
			# marinada pure.
			var result: Variant = TFMarinada.apply(library[kind], [part, root, tr, seed, coord, ti, n])
			if result is Dictionary:
				trans[ti] = result.get("transition", tr)
				var writes: Variant = result.get("fields", {})
				if writes is Dictionary:
					for f in writes:
						part.fields[f] = writes[f]
				# STRUCTURAL channel: apply described tree edits in eval order. New
				# parts grafted this tick are NOT in `order` (snapshotted above), so
				# they first tick NEXT tick — the same discipline as transitions
				# appended this tick. Applied in pre-order × list-order ⇒ replayable.
				var edits: Variant = result.get("structural")
				if edits is Array:
					_apply_structural(part, edits)


# ---------------------------------------------------------------------------
# Structural mutation — the discrete-TOPOLOGY channel (see class doc).
# Marinada returns plain-data edit DESCRIPTIONS; these apply them via TFPart's
# own add_child / detach. Used by both the tick's `structural` return channel and
# the `graft` / `detach` authoring actions below, so the two paths edit the tree
# through exactly one implementation.
# ---------------------------------------------------------------------------

## Build a live subtree from a plain-data node-spec:
##   { "fields": <field bag — may include a "transitions" Array>, "children": [ node-spec, ... ] }
## Fields are DEEP-COPIED so the new part never aliases the (possibly shared)
## authored description — each graft yields an independent part with its own
## progress. A grafted part carrying a magnitude transition in its "transitions"
## field is the continuous half of "grows in": it starts small and accrues up.
static func _materialize(spec: Dictionary) -> TFPart:
	var p := TFPart.new()
	p.fields = TFPart._deep_copy_value(spec.get("fields", {}))
	for cspec in spec.get("children", []):
		p.add_child(_materialize(cspec))
	return p


## Apply a list of structural-edit records to `host` (the transition's own part is
## the default target when an edit omits its part/at handle).
static func _apply_structural(host: TFPart, edits: Array) -> void:
	for e in edits:
		if not (e is Dictionary):
			continue
		match e.get("op"):
			"graft":
				var at: Variant = e.get("at")
				if at == null:
					at = host
				(at as TFPart).add_child(_materialize(e.get("node", {})))
			"detach":
				var tgt: Variant = e.get("part")
				if tgt == null:
					tgt = host
				(tgt as TFPart).detach()
			"reparent":
				var mv: Variant = e.get("part")
				if mv == null:
					mv = host
				var to: Variant = e.get("to")
				if to != null:
					(mv as TFPart).detach()
					(to as TFPart).add_child(mv)
			_:
				push_error("TFEngine._apply_structural: unknown structural op %s" % str(e.get("op")))


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
##   {"op": "graft", "where": …, "node": {…}}           — add a materialized subtree as a child
##   {"op": "detach","where": …}                        — structurally remove the matched parts
##
## graft/detach are the authoring-layer twins of the tick's `structural` return
## channel (they share `_materialize` / TFPart.detach). The RETURN channel is the
## primary path — "a transformation adds a part" means a transformation, mid-tick,
## returns a graft — while these actions let a plain log author the same edits
## directly. (reparent-as-action is deferred: a plain `where` clause can't name the
## new-parent target; the tick channel, which has opaque handles, covers reparent.)
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
		"graft":
			for p in _targets(root, action.get("where", {})):
				p.add_child(_materialize(action["node"]))
		"detach":
			# Collect first: detaching mutates the tree the query walked.
			for p in _targets(root, action.get("where", {})):
				p.detach()
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
