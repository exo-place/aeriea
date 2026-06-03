## InteractionKit — the typed, in-memory representation of a serializable
## interaction kit (see docs/decisions/affordance-substrate.md §1).
##
## A kit is one diffable/cacheable/transportable document. On disk it is JSON;
## in-engine it is this typed tree. The interpreter (InteractionInterpreter) is
## the reference semantics that consumes it. SLICE 1 implements the full Guard /
## Effect vocabulary the sandbox needs; the unions are closed and structured so a
## new leaf (the one sanctioned engine change) slots in cleanly.
##
## This file also contains the LOADER: parse JSON / Dictionary data into the typed
## structures, with load-time validation (unknown ops, dangling refs/events,
## cyclic reaction graphs, unknown params). Invalid kits fail loudly at load,
## never silently at runtime (§8.3).
##
## It mirrors MovementKit by construction: interactables<-states, verbs<-
## transitions, guards<-conditions, effects<-effects. Guards/Effects are kept as
## plain Dictionaries (already-serializable data) validated against the closed
## vocabulary at load; structure is typed for fast, stable iteration.
class_name InteractionKit
extends RefCounted

# ---------------------------------------------------------------------------
# Closed vocabularies (tags). New leaves are an engine change reviewed against
# "collapse asymmetries to primitives" — never a per-node hack.
# ---------------------------------------------------------------------------

## The closed Guard-op vocabulary (predicate primitives over self/held/focus/
## world scopes, composed with all/any/not). The leaf set is the irreducible set
## the worked example validated (affordance-substrate.md §1.4).
const GUARD_OPS := [
	"state_bool", "state_cmp", "state_enum", "socket_empty",
	"is_held", "held_is", "focus_is", "in_region", "reached_by_player",
	"body_is_adult",
	"all", "any", "not",
]

## The closed Effect-op vocabulary (state-transition primitives, §1.5). Effects
## are pure transforms over the explicit state record; physics is intent only.
const EFFECT_OPS := [
	"set_state", "toggle_state", "add_fill", "emit", "arm", "trigger",
	"consume_into_socket", "grab_body", "release", "apply_impulse",
]

const CMP_OPS := ["ge", "gt", "le", "lt", "eq"]

## Verb kinds map onto the interactor's dispatch (§1.3). Closed.
const VERB_KINDS := ["command", "grab", "place", "carry_release"]

## State-slot types (§1.2). Closed.
const SLOT_TYPES := ["bool", "number", "enum", "ref", "socket"]

## Guard scopes. A scope of the form "ref:<name>" reads a declared ref's state.
const SCOPES := ["self", "held", "focus", "world"]

# ---------------------------------------------------------------------------
# Typed node structures.
# ---------------------------------------------------------------------------

class TypedSlot:
	extends RefCounted
	var type: String = "bool"
	var init: Variant = false
	var lo: float = 0.0
	var hi: float = 1.0
	var has_bounds: bool = false

class Verb:
	extends RefCounted
	var name: String
	var kind: String = "command"
	var target: String = "self"        # self | focus | held
	var when_guard: Dictionary = {}     # {} = always available
	var prompt: Variant = ""            # String OR Array[{when?,text}] (closed grammar)
	var do_effects: Array = []          # Array[Dictionary]

class TickEffect:
	extends RefCounted
	var while_guard: Dictionary = {}
	var do_effects: Array = []          # Array[Dictionary]

class Reaction:
	extends RefCounted
	var on_from: String = "self"        # "self" | "ref:<name>"
	var on_event: String = ""
	var when_guard: Variant = null      # Dictionary or null
	var do_effects: Array = []          # Array[Dictionary]

class RegionDecl:
	extends RefCounted
	var name: String
	var kind: String = "area"

class Interactable:
	extends RefCounted
	var id: String
	var tags: Array = []                       # Array[String]
	var refs: Dictionary = {}                  # ref-name -> target interactable id (resolved id; "@" stripped)
	var state_schema: Dictionary = {}          # field -> TypedSlot
	var state_order: Array = []                # declared field order (stable iteration)
	var verbs: Array = []                      # Array[Verb]
	var tick: Array = []                       # Array[TickEffect]
	var reactions: Array = []                  # Array[Reaction]
	var regions: Dictionary = {}               # region-name -> RegionDecl
	var region_order: Array = []

# ---------------------------------------------------------------------------
# Kit fields
# ---------------------------------------------------------------------------

var params: Dictionary = {}                    # name -> float
var interactables: Dictionary = {}             # id -> Interactable
var interactable_order: Array = []             # declared order (THE stable iteration order)
var load_errors: Array = []                    # Array[String]; non-empty => invalid kit

func is_valid() -> bool:
	return load_errors.is_empty()

# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

static func load_from_file(path: String) -> InteractionKit:
	var kit := InteractionKit.new()
	if not FileAccess.file_exists(path):
		kit.load_errors.append("kit file not found: %s" % path)
		return kit
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		kit.load_errors.append("kit JSON did not parse to an object: %s" % path)
		return kit
	kit._load_from_dict(parsed)
	return kit

static func load_from_dict(data: Dictionary) -> InteractionKit:
	var kit := InteractionKit.new()
	kit._load_from_dict(data)
	return kit

func _err(msg: String) -> void:
	load_errors.append(msg)

func _load_from_dict(data: Dictionary) -> void:
	# Params
	var raw_params: Variant = data.get("params", {})
	if typeof(raw_params) == TYPE_DICTIONARY:
		for k in raw_params:
			params[k] = float(raw_params[k])
	else:
		_err("params must be an object")

	# Interactables
	var raw_list: Variant = data.get("interactables", [])
	if typeof(raw_list) != TYPE_ARRAY:
		_err("interactables must be an array")
		return
	for raw: Variant in raw_list:
		if typeof(raw) != TYPE_DICTIONARY:
			_err("each interactable must be an object")
			continue
		var it := _load_interactable(raw)
		if it == null:
			continue
		if interactables.has(it.id):
			_err("duplicate interactable id '%s'" % it.id)
			continue
		interactables[it.id] = it
		interactable_order.append(it.id)

	# Cross-checks (refs, events, guards, effects, prompts) + acyclic reactions.
	_validate_cross_references()

func _load_interactable(raw: Dictionary) -> Interactable:
	var it := Interactable.new()
	it.id = str(raw.get("id", ""))
	if it.id == "":
		_err("an interactable has no id")
		return null
	var ctx := "interactable '%s'" % it.id

	var raw_tags: Variant = raw.get("tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for t: Variant in raw_tags:
			it.tags.append(str(t))

	# refs: name -> "@target" (or bare "target")
	var raw_refs: Variant = raw.get("refs", {})
	if typeof(raw_refs) == TYPE_DICTIONARY:
		for rn in raw_refs:
			var tgt := str(raw_refs[rn])
			if tgt.begins_with("@"):
				tgt = tgt.substr(1)
			it.refs[str(rn)] = tgt

	# regions
	var raw_regions: Variant = raw.get("regions", [])
	if typeof(raw_regions) == TYPE_ARRAY:
		for rr: Variant in raw_regions:
			if typeof(rr) != TYPE_DICTIONARY:
				_err("%s: region must be an object" % ctx)
				continue
			var rd := RegionDecl.new()
			rd.name = str(rr.get("name", ""))
			rd.kind = str(rr.get("kind", "area"))
			if rd.name == "":
				_err("%s: a region has no name" % ctx)
				continue
			it.regions[rd.name] = rd
			it.region_order.append(rd.name)

	# state schema
	var raw_state: Variant = raw.get("state", {})
	if typeof(raw_state) == TYPE_DICTIONARY:
		for field in raw_state:
			var sd: Variant = raw_state[field]
			if typeof(sd) != TYPE_DICTIONARY:
				_err("%s: state field '%s' must be an object" % [ctx, field])
				continue
			var slot := TypedSlot.new()
			slot.type = str(sd.get("type", "bool"))
			if not SLOT_TYPES.has(slot.type):
				_err("%s: state field '%s' has unknown type '%s'" % [ctx, field, slot.type])
			slot.init = sd.get("init", false)
			if sd.has("lo") or sd.has("hi"):
				slot.has_bounds = true
				slot.lo = float(sd.get("lo", 0.0))
				slot.hi = float(sd.get("hi", 1.0))
			it.state_schema[str(field)] = slot
			it.state_order.append(str(field))

	# verbs
	var raw_verbs: Variant = raw.get("verbs", [])
	if typeof(raw_verbs) == TYPE_ARRAY:
		for rv: Variant in raw_verbs:
			var v := _load_verb(rv, ctx)
			if v != null:
				it.verbs.append(v)

	# tick effects
	var raw_tick: Variant = raw.get("tick", [])
	if typeof(raw_tick) == TYPE_ARRAY:
		for rt: Variant in raw_tick:
			if typeof(rt) != TYPE_DICTIONARY:
				_err("%s: tick entry must be an object" % ctx)
				continue
			var te := TickEffect.new()
			var w: Variant = rt.get("while", {})
			te.while_guard = w if typeof(w) == TYPE_DICTIONARY else {}
			te.do_effects = _load_effects(rt.get("do", []), "%s.tick" % ctx)
			it.tick.append(te)

	# reactions
	var raw_react: Variant = raw.get("reactions", [])
	if typeof(raw_react) == TYPE_ARRAY:
		for rr: Variant in raw_react:
			var rx := _load_reaction(rr, ctx)
			if rx != null:
				it.reactions.append(rx)

	return it

func _load_verb(raw: Variant, ctx: String) -> Verb:
	if typeof(raw) != TYPE_DICTIONARY:
		_err("%s: a verb is not an object" % ctx)
		return null
	var v := Verb.new()
	v.name = str(raw.get("name", ""))
	if v.name == "":
		_err("%s: a verb has no name" % ctx)
	v.kind = str(raw.get("kind", "command"))
	if not VERB_KINDS.has(v.kind):
		_err("%s verb '%s': unknown kind '%s'" % [ctx, v.name, v.kind])
	v.target = str(raw.get("target", "self"))
	if not ["self", "focus", "held"].has(v.target):
		_err("%s verb '%s': unknown target '%s'" % [ctx, v.name, v.target])
	var w: Variant = raw.get("when", {})
	v.when_guard = w if typeof(w) == TYPE_DICTIONARY else {}
	v.prompt = raw.get("prompt", "")
	_validate_prompt(v.prompt, "%s verb '%s'.prompt" % [ctx, v.name])
	v.do_effects = _load_effects(raw.get("do", []), "%s verb '%s'.do" % [ctx, v.name])
	return v

func _load_reaction(raw: Variant, ctx: String) -> Reaction:
	if typeof(raw) != TYPE_DICTIONARY:
		_err("%s: a reaction is not an object" % ctx)
		return null
	var rx := Reaction.new()
	var on: Variant = raw.get("on", {})
	if typeof(on) != TYPE_DICTIONARY:
		_err("%s: reaction 'on' must be an object {from,event}" % ctx)
		return null
	rx.on_from = str(on.get("from", "self"))
	rx.on_event = str(on.get("event", ""))
	if rx.on_event == "":
		_err("%s: reaction 'on' has no event" % ctx)
	var w: Variant = raw.get("when", null)
	rx.when_guard = w if typeof(w) == TYPE_DICTIONARY else null
	rx.do_effects = _load_effects(raw.get("do", []), "%s reaction.do" % ctx)
	return rx

func _load_effects(raw: Variant, ctx: String) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		if raw != null:
			_err("%s must be an array of effects" % ctx)
		return out
	for e: Variant in raw:
		if typeof(e) != TYPE_DICTIONARY:
			_err("%s contains a non-object effect" % ctx)
			continue
		var op: String = str(e.get("do", ""))
		if not EFFECT_OPS.has(op):
			_err("%s: unknown effect op '%s' (one of %s)" % [ctx, op, str(EFFECT_OPS)])
		# A guarded effect carries its own `when` (§ worked example: consume always,
		# activate only if full). Validate it as a guard.
		if e.has("when") and typeof(e["when"]) == TYPE_DICTIONARY:
			_validate_guard(e["when"], "%s effect '%s'.when" % [ctx, op])
		out.append(e)
	return out

# ---------------------------------------------------------------------------
# Prompt grammar validation (closed, §1.3 / §3).
# A prompt is EITHER a String (literal with {field}/{pct field} interpolation)
# OR an Array of guarded variants [{when?, text}] resolved first-match. NO inline
# ternaries — the design's `{flowing ? .. : ..}` shorthand is replaced by variants.
# ---------------------------------------------------------------------------

func _validate_prompt(p: Variant, ctx: String) -> void:
	match typeof(p):
		TYPE_STRING:
			return
		TYPE_ARRAY:
			for variant: Variant in p:
				if typeof(variant) != TYPE_DICTIONARY:
					_err("%s: prompt variant must be an object {when?,text}" % ctx)
					continue
				if not variant.has("text") or typeof(variant["text"]) != TYPE_STRING:
					_err("%s: prompt variant needs a string 'text'" % ctx)
				if variant.has("when") and typeof(variant["when"]) == TYPE_DICTIONARY:
					_validate_guard(variant["when"], "%s variant.when" % ctx)
		_:
			_err("%s: prompt must be a string or an array of variants" % ctx)

# ---------------------------------------------------------------------------
# Cross-reference + guard/effect validation.
# ---------------------------------------------------------------------------

func _validate_cross_references() -> void:
	for id in interactable_order:
		var it: Interactable = interactables[id]
		var ctx := "interactable '%s'" % id
		# refs target existing interactables.
		for rn in it.refs:
			if not interactables.has(it.refs[rn]):
				_err("%s: ref '%s' targets undefined interactable '%s'" % [ctx, rn, it.refs[rn]])
		# verb guards + effects resolve.
		for v: Verb in it.verbs:
			_validate_guard(v.when_guard, "%s verb '%s'.when" % [ctx, v.name])
			for e: Variant in v.do_effects:
				_validate_effect_scope(e, it, "%s verb '%s'.do" % [ctx, v.name])
		# tick guards + effects.
		for te: TickEffect in it.tick:
			_validate_guard(te.while_guard, "%s tick.while" % ctx)
			for e: Variant in te.do_effects:
				_validate_effect_scope(e, it, "%s tick.do" % ctx)
		# reactions: 'from' ref resolves, guard + effects resolve.
		for rx: Reaction in it.reactions:
			if rx.on_from.begins_with("ref:"):
				var rn := rx.on_from.substr(4)
				if not it.refs.has(rn):
					_err("%s: reaction on undeclared ref '%s'" % [ctx, rn])
			if typeof(rx.when_guard) == TYPE_DICTIONARY:
				_validate_guard(rx.when_guard, "%s reaction.when" % ctx)
			for e: Variant in rx.do_effects:
				_validate_effect_scope(e, it, "%s reaction.do" % ctx)

	# Reaction graph must be acyclic (propagation must terminate, §8.3 / Risks).
	_validate_acyclic_reactions()

## A scope is one of self/held/focus/world, or "ref:<name>" (must be a declared
## ref), or "region:<region>:<tag>" (must be a declared region).
func _validate_scope(scope: String, it: Interactable, ctx: String) -> void:
	if SCOPES.has(scope):
		return
	if scope.begins_with("ref:"):
		var rn := scope.substr(4)
		if not it.refs.has(rn):
			_err("%s: scope references undeclared ref '%s'" % [ctx, rn])
		return
	if scope.begins_with("region:"):
		var parts := scope.split(":")
		if parts.size() >= 2 and not it.regions.has(parts[1]):
			_err("%s: scope references undeclared region '%s'" % [ctx, parts[1]])
		return
	_err("%s: unknown scope '%s'" % [ctx, scope])

func _validate_value(v: Variant, ctx: String) -> void:
	# Number, or a param name (cross-scope state paths like "held.full_threshold"
	# are resolved by the interpreter at tick time; only bare param names are
	# checked here — a string with a dot is a state path, left to the interpreter).
	if typeof(v) == TYPE_STRING:
		if not (v as String).contains(".") and not params.has(v):
			_err("%s: references unknown param '%s'" % [ctx, str(v)])

func _validate_guard(g: Dictionary, ctx: String) -> void:
	if g.is_empty():
		return  # absent guard = always true
	var op := str(g.get("op", ""))
	if not GUARD_OPS.has(op):
		_err("%s: unknown guard op '%s' (one of %s)" % [ctx, op, str(GUARD_OPS)])
		return
	match op:
		"all", "any", "not":
			var of: Variant = g.get("of", [])
			if typeof(of) != TYPE_ARRAY:
				_err("%s: '%s' requires an 'of' array" % [ctx, op])
				return
			for sub: Variant in of:
				if typeof(sub) == TYPE_DICTIONARY:
					_validate_guard(sub, ctx)
				else:
					_err("%s: '%s'.of contains a non-guard" % [ctx, op])
		"state_cmp":
			var cmp := str(g.get("cmp", ""))
			if not CMP_OPS.has(cmp):
				_err("%s: state_cmp invalid cmp '%s'" % [ctx, cmp])
			_validate_value(g.get("value"), ctx)
		"in_region", "reached_by_player":
			if str(g.get("region", "")) == "":
				_err("%s: %s needs a 'region'" % [ctx, op])

## Validate an effect's referenced scope/region against the interactable's decls.
func _validate_effect_scope(e: Dictionary, it: Interactable, ctx: String) -> void:
	var scope: Variant = e.get("scope", null)
	if typeof(scope) == TYPE_STRING:
		_validate_scope(scope, it, ctx)
	# rate/magnitude as param names get value-checked.
	if e.has("rate"):
		_validate_value(e.get("rate"), ctx)
	if e.has("magnitude"):
		_validate_value(e.get("magnitude"), ctx)

## Build the reaction event-dependency graph and reject cycles (DFS). An edge
## A->B means "an event emitted on A can fire a reaction on B". Effects that emit
## are the producers; reactions that listen are the consumers. We over-approximate
## conservatively: any emit on X is an edge to every interactable reacting to X.
func _validate_acyclic_reactions() -> void:
	# producers: interactable id -> set of event names it can emit (self events).
	var emits: Dictionary = {}
	for id in interactable_order:
		var it: Interactable = interactables[id]
		var ev := {}
		for v: Verb in it.verbs:
			for e: Variant in v.do_effects:
				_collect_emit(e, ev)
		for te: TickEffect in it.tick:
			for e: Variant in te.do_effects:
				_collect_emit(e, ev)
		for rx: Reaction in it.reactions:
			for e: Variant in rx.do_effects:
				_collect_emit(e, ev)
		emits[id] = ev
	# adjacency: producer-id -> set(consumer-id) where consumer reacts to a producer event.
	var adj: Dictionary = {}
	for id in interactable_order:
		adj[id] = {}
	for cid in interactable_order:
		var it: Interactable = interactables[cid]
		for rx: Reaction in it.reactions:
			var src_id: String = str(cid)
			if rx.on_from.begins_with("ref:"):
				var rn := rx.on_from.substr(4)
				src_id = str(it.refs.get(rn, ""))
			if src_id != "" and emits.has(src_id) and emits[src_id].has(rx.on_event):
				adj[src_id][cid] = true
	# DFS cycle detection (white/gray/black).
	var color: Dictionary = {}
	for id in interactable_order:
		color[id] = 0
	for id in interactable_order:
		if color[id] == 0 and _react_dfs(id, adj, color):
			_err("reaction graph has a cycle through '%s' (propagation must be acyclic)" % id)
			return

func _collect_emit(e: Dictionary, into: Dictionary) -> void:
	if str(e.get("do", "")) == "emit":
		into[str(e.get("signal", ""))] = true

func _react_dfs(node: String, adj: Dictionary, color: Dictionary) -> bool:
	color[node] = 1  # gray
	for nxt in adj.get(node, {}):
		if color[nxt] == 1:
			return true
		if color[nxt] == 0 and _react_dfs(nxt, adj, color):
			return true
	color[node] = 2  # black
	return false

# ---------------------------------------------------------------------------
# Value resolution helper (number | param name) — used by the interpreter.
# ---------------------------------------------------------------------------

func resolve_param(v: Variant) -> float:
	if typeof(v) == TYPE_STRING:
		return float(params.get(v, 0.0))
	return float(v)
