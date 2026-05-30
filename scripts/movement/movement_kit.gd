## MovementKit — the typed, in-memory representation of a serializable movement
## kit (see docs/decisions/movement-substrate.md §1).
##
## A kit is one diffable/cacheable/transportable document. On disk it is JSON;
## in-engine it is this typed tree. The interpreter (MovementInterpreter) is the
## reference semantics that consumes it. SLICE 1 implements the subset of the
## Condition/Effect vocabulary that ground-move + jump require; the unions are
## structured so the remaining primitives (Slice 2) slot in cleanly.
##
## This file also contains the LOADER: parse JSON / Dictionary data into the
## typed structures, with load-time validation (unknown ops, dangling targets,
## ambiguous (state, priority) collisions, unknown params).
class_name MovementKit
extends RefCounted

# ---------------------------------------------------------------------------
# Closed vocabularies (tags). New leaves are an engine change reviewed against
# "collapse asymmetries to primitives" — never a per-verb hack.
# ---------------------------------------------------------------------------

## Condition ops implemented this slice. (Slice 2 adds speed_v, wall_detected,
## wall_still_near, ledge_vaultable, headroom, slope_angle, below_y, wish_input
## variants.)
const COND_OPS_SLICE1 := [
	"on_ground", "airborne", "speed_h", "timer",
	"input_pressed", "input_buffered", "wish_input",
	"all", "any", "not",
]

## Effect ops implemented this slice. (Slice 2 adds add_velocity, carve,
## slope_accelerate, clamp_speed_h, set_collider_height, lerp_* , tween_position,
## respawn.)
const EFFECT_OPS_SLICE1 := [
	"accelerate_toward", "air_strafe", "apply_friction", "apply_gravity",
	"set_velocity_y", "set_timer", "move_and_slide",
]

const CMP_OPS := ["ge", "gt", "le", "lt", "eq"]

# ---------------------------------------------------------------------------
# Typed node structures. Conditions/Effects are kept as plain Dictionaries
# (already serializable data) but validated against the closed vocabulary at
# load. Params and structure are typed for fast access.
# ---------------------------------------------------------------------------

class Transition:
	extends RefCounted
	var when_cond: Dictionary
	var to_state: String
	var priority: int = 0
	var reenter: bool = false
	var do_effects: Array = []  # Array[Dictionary]

class MovementState:
	extends RefCounted
	var name: String
	var on_enter: Array = []      # Array[Dictionary] effects
	var tick: Array = []          # Array[Dictionary] effects
	var on_exit: Array = []       # Array[Dictionary] effects
	var transitions: Array = []   # Array[Transition], sorted desc priority

class InputSpec:
	extends RefCounted
	var action: String
	var buffer_param: String = ""   # name of a param giving the buffer window, or "" for none
	var track_hold: bool = false    # whether to track held state (for floaty apex etc.)

# ---------------------------------------------------------------------------
# Kit fields
# ---------------------------------------------------------------------------

var params: Dictionary = {}             # name -> float (Vec3 support is a later leaf)
var inputs: Dictionary = {}             # action -> InputSpec
var initial: String = ""
var states: Dictionary = {}             # name -> MovementState
var state_order: Array = []             # insertion order of state names
var load_errors: Array = []             # Array[String]; non-empty => invalid kit

func is_valid() -> bool:
	return load_errors.is_empty()

# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

## Load a kit from a JSON file path (res:// or absolute). Returns a MovementKit;
## check is_valid() / load_errors.
static func load_from_file(path: String) -> MovementKit:
	var kit := MovementKit.new()
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

## Load from an already-parsed Dictionary (in-memory / overlay use).
static func load_from_dict(data: Dictionary) -> MovementKit:
	var kit := MovementKit.new()
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

	# Inputs
	var raw_inputs: Variant = data.get("inputs", {})
	if typeof(raw_inputs) == TYPE_DICTIONARY:
		for action in raw_inputs:
			var spec := InputSpec.new()
			spec.action = action
			var idef: Dictionary = raw_inputs[action]
			if idef.has("buffer"):
				spec.buffer_param = str(idef["buffer"])
				if not params.has(spec.buffer_param):
					_err("input '%s' buffer references unknown param '%s'" % [action, spec.buffer_param])
			spec.track_hold = bool(idef.get("hold", false))
			inputs[action] = spec

	# Initial
	initial = str(data.get("initial", ""))
	if initial == "":
		_err("kit has no 'initial' state")

	# States
	var raw_states: Variant = data.get("states", [])
	if typeof(raw_states) != TYPE_ARRAY:
		_err("states must be an array")
		return
	for raw_state: Variant in raw_states:
		if typeof(raw_state) != TYPE_DICTIONARY:
			_err("each state must be an object")
			continue
		var st := MovementState.new()
		st.name = str(raw_state.get("name", ""))
		if st.name == "":
			_err("a state has no name")
			continue
		st.on_enter = _load_effects(raw_state.get("on_enter", []), "state '%s'.on_enter" % st.name)
		st.tick = _load_effects(raw_state.get("tick", []), "state '%s'.tick" % st.name)
		st.on_exit = _load_effects(raw_state.get("on_exit", []), "state '%s'.on_exit" % st.name)

		var raw_trans: Variant = raw_state.get("transitions", [])
		var seen_priorities := {}
		if typeof(raw_trans) == TYPE_ARRAY:
			var insertion := 0
			for raw_t: Variant in raw_trans:
				var tr := _load_transition(raw_t, st.name)
				if tr == null:
					continue
				# Ambiguous (state, priority) is a load-time error (no silent nondeterminism).
				if seen_priorities.has(tr.priority):
					_err("state '%s' has two transitions at priority %d (ambiguous ordering)" % [st.name, tr.priority])
				seen_priorities[tr.priority] = true
				# Stash insertion order for stable sort tie-break (defensive; collisions are errors).
				tr.set_meta("_ins", insertion)
				insertion += 1
				st.transitions.append(tr)
		# Sort transitions by priority DESC, then insertion order ASC (deterministic).
		st.transitions.sort_custom(func(a: Transition, b: Transition) -> bool:
			if a.priority != b.priority:
				return a.priority > b.priority
			return int(a.get_meta("_ins")) < int(b.get_meta("_ins")))

		states[st.name] = st
		state_order.append(st.name)

	# Cross-checks: initial exists, transition targets exist.
	if initial != "" and not states.has(initial):
		_err("initial state '%s' is not defined" % initial)
	for sname in states:
		var st: MovementState = states[sname]
		for tr: Transition in st.transitions:
			if not states.has(tr.to_state):
				_err("state '%s' transition targets undefined state '%s'" % [sname, tr.to_state])
			_validate_condition(tr.when_cond, "state '%s' transition guard" % sname)

func _load_transition(raw: Variant, state_name: String) -> Transition:
	if typeof(raw) != TYPE_DICTIONARY:
		_err("state '%s' has a non-object transition" % state_name)
		return null
	var tr := Transition.new()
	var w: Variant = raw.get("when", null)
	if typeof(w) != TYPE_DICTIONARY:
		_err("state '%s' transition has no 'when' condition object" % state_name)
		return null
	tr.when_cond = w
	tr.to_state = str(raw.get("to", ""))
	if tr.to_state == "":
		_err("state '%s' transition has no 'to' target" % state_name)
	tr.priority = int(raw.get("priority", 0))
	tr.reenter = bool(raw.get("reenter", false))
	tr.do_effects = _load_effects(raw.get("do", []), "state '%s' transition.do" % state_name)
	return tr

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
		if not EFFECT_OPS_SLICE1.has(op):
			_err("%s: unknown/unsupported effect op '%s' (Slice 1 implements %s)" % [ctx, op, str(EFFECT_OPS_SLICE1)])
		out.append(e)
	return out

func _validate_condition(cond: Dictionary, ctx: String) -> void:
	var op: String = str(cond.get("op", ""))
	if not COND_OPS_SLICE1.has(op):
		_err("%s: unknown/unsupported condition op '%s'" % [ctx, op])
		return
	match op:
		"all", "any", "not":
			var of: Variant = cond.get("of", [])
			if typeof(of) != TYPE_ARRAY:
				_err("%s: '%s' requires an 'of' array" % [ctx, op])
				return
			for sub: Variant in of:
				if typeof(sub) == TYPE_DICTIONARY:
					_validate_condition(sub, ctx)
				else:
					_err("%s: '%s'.of contains a non-condition" % [ctx, op])
		"speed_h":
			_validate_cmp(cond, ctx)
			_validate_value(cond.get("value"), ctx)
		"timer":
			if str(cond.get("name", "")) == "":
				_err("%s: timer condition needs a 'name'" % ctx)
			_validate_cmp(cond, ctx)
			_validate_value(cond.get("value"), ctx)
		"input_pressed", "input_buffered":
			if str(cond.get("action", "")) == "":
				_err("%s: %s needs an 'action'" % [ctx, op])

func _validate_cmp(cond: Dictionary, ctx: String) -> void:
	var cmp: String = str(cond.get("cmp", ""))
	if not CMP_OPS.has(cmp):
		_err("%s: invalid cmp '%s' (one of %s)" % [ctx, cmp, str(CMP_OPS)])

## A value is a number OR a known param name. (Curves are a Slice 2 leaf.)
func _validate_value(v: Variant, ctx: String) -> void:
	if typeof(v) == TYPE_STRING:
		if not params.has(v):
			_err("%s: references unknown param '%s'" % [ctx, str(v)])
	elif typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		# Structured value-resolvers (select/curve) validated by the interpreter; skip here.
		pass

# ---------------------------------------------------------------------------
# Value resolution helper (number | param name) — used by the interpreter too.
# ---------------------------------------------------------------------------

## Resolve a plain Value (number or param name) to a float. Structured resolvers
## (select / curve) are handled by the interpreter, which has tick context.
func resolve_scalar(v: Variant) -> float:
	if typeof(v) == TYPE_STRING:
		return float(params.get(v, 0.0))
	return float(v)
