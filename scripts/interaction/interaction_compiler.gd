## InteractionCompiler — lowers a flattened InteractionKit to GDScript source that
## implements the SAME affordance semantics as InteractionInterpreter, but as
## direct branching code (docs/decisions/affordance-substrate.md §7b).
##
## This is the COMPILER half of projection-from-one-definition: the interpreter is
## the reference semantics; this tool emits a faithful lowering of the same kit.
## The two must produce bit-identical interactable-state trajectories on one
## runtime (enforced by the golden-trace harness, tests/interaction_golden_trace_test.gd).
##
## HOW IT LOWERS (the dispatch-removal win), mirroring MovementCompiler:
##   - Params     → consts (`const P_fill_rate := 1.5`), referenced by name.
##   - State init → an if/elif chain in reset_state()/_init_state_for() per
##                  definition, no per-tick `match slot.type` dispatch.
##   - Tick       → `_run_tick`: a straight-line, declared-order pass; each
##                  interactable's while-guarded tick effects are inlined as an
##                  `if <guard-expr>:` with straight-line effect statements. No
##                  per-tick `match op` over Dictionaries.
##   - Verb-fire  → `_process_verb_fire`: the interactor precedence is the SAME
##                  data-ordered resolution; verb SELECTION (`_find_verb`) is an
##                  if/elif over interactable id × kind with inlined guard
##                  expressions, then the chosen verb's effects run straight-line.
##   - Reactions  → `_propagate_events`: the bounded, declared-order, acyclic
##                  propagation pass is preserved; reaction matching is an if/elif
##                  over interactable id with inlined `on`/`when`/`do`.
##   - Guards     → inline boolean EXPRESSIONS. `all`/`any`/`not` become
##                  `and`/`or`/`not`; leaf ops become direct kernel calls /
##                  comparisons. No recursive _eval_guard dispatch at runtime.
##   - Effects    → direct kernel calls / straight-line statements, in listed
##                  order. The kernels (_k_*) are COPIED from the interpreter so
##                  arithmetic/logic is identical — only dispatch is removed.
##   - Prompts    → the SAME projection (render-side; excluded from the sim hash).
##
## The compiler is a pure function InteractionKit → String. Output is committed and
## regenerated; see regen command in the generated header. The generated class
## exposes the SAME host-facing surface (setup/reset_state/add_instance/step/
## project_prompt + the `state` dict) so it drives the same host and tests.
class_name InteractionCompiler
extends RefCounted

## Compile a kit to GDScript source for a class named `class_name_str`.
## `kit_path` is recorded in the header for the regen note.
static func compile(kit: InteractionKit, class_name_str: String, kit_path: String) -> String:
	var c := InteractionCompiler.new()
	return c._compile(kit, class_name_str, kit_path)

var _out: PackedStringArray = PackedStringArray()
var _kit: InteractionKit

func _line(s: String = "") -> void:
	_out.append(s)

func _compile(kit: InteractionKit, class_name_str: String, kit_path: String) -> String:
	_kit = kit
	_out = PackedStringArray()

	_emit_header(class_name_str, kit_path)
	_emit_fields()
	_emit_consts()
	_emit_setup_reset()
	_emit_step()
	_emit_run_tick()
	_emit_process_verb_fire()
	_emit_find_verb()
	_emit_propagate()
	_emit_guard_kernels()
	_emit_effect_kernels()
	_emit_value_kernels()
	_emit_prompt()

	return "\n".join(_out) + "\n"

# ---------------------------------------------------------------------------
# Header + fields + consts
# ---------------------------------------------------------------------------

func _emit_header(class_name_str: String, kit_path: String) -> void:
	_line("## GENERATED from %s — do not edit by hand." % kit_path)
	_line("## Regenerate with:")
	_line("##   nix develop --command bash -lc 'xvfb-run -a godot4 --path . res://tools/regen_compiled_interaction.tscn --quit-after 120'")
	_line("##")
	_line("## This is the COMPILED projection of the interaction kit (see")
	_line("## docs/decisions/affordance-substrate.md §7b and scripts/interaction/interaction_compiler.gd).")
	_line("## It is a faithful lowering of InteractionInterpreter's reference semantics to")
	_line("## direct branching code: tick effects, verb selection and reaction propagation")
	_line("## are inlined if/elif chains in declared order, guards are inline boolean")
	_line("## expressions, effects are straight-line kernel calls. The golden-trace harness")
	_line("## asserts interpreter == compiled.")
	_line("class_name %s" % class_name_str)
	_line("extends RefCounted")
	_line("")
	_line("# Mirrors InteractionInterpreter's public surface so the same host (InteractionWorld)")
	_line("# can drive either path and the same tests exercise both. The resolved frame is the")
	_line("# interpreter's ResolvedFrame verbatim (same shape; render-side prompt excluded from hash).")
	_line("const ResolvedFrame := preload(\"res://scripts/interaction/interaction_interpreter.gd\").ResolvedFrame")

func _emit_fields() -> void:
	_line("var kit: InteractionKit")
	_line("var host")
	_line("var state: Dictionary = {}")
	_line("var _events: Array = []")
	_line("const MAX_PROPAGATION := 16")
	_line("")

func _emit_consts() -> void:
	_line("# --- Params lowered to consts (referenced by name in the kit) ---")
	var names := _kit.params.keys()
	names.sort()
	for n: String in names:
		var v: float = float(_kit.params[n])
		_line("const %s := %s" % [_const_name(n), _fmt_float(v)])
	_line("")

func _const_name(param: String) -> String:
	return "P_" + param.replace(".", "_")

# ---------------------------------------------------------------------------
# setup / reset / add_instance — mirror InteractionInterpreter exactly. State init
# is lowered per definition (no per-field `match slot.type` at runtime).
# ---------------------------------------------------------------------------

func _emit_setup_reset() -> void:
	_line("func setup(p_kit: InteractionKit, p_host) -> void:")
	_line("\tkit = p_kit")
	_line("\thost = p_host")
	_line("\treset_state()")
	_line("")
	_line("func reset_state() -> void:")
	_line("\tstate = {}")
	_line("\tfor id in kit.interactable_order:")
	_line("\t\t_init_state_for(id, _def_id_of(id))")
	_line("")
	# Track which instance ids map to which definition id; default: id == def.
	_line("var _def_of: Dictionary = {}")
	_line("")
	_line("func _def_id_of(instance_id: String) -> String:")
	_line("\treturn str(_def_of.get(instance_id, instance_id))")
	_line("")
	_line("func add_instance(instance_id: String, def_id: String) -> void:")
	_line("\tif not kit.interactables.has(def_id):")
	_line("\t\tpush_error(\"compiled: unknown definition '%s'\" % def_id)")
	_line("\t\treturn")
	_line("\tif instance_id == def_id or kit.interactables.has(instance_id):")
	_line("\t\tif not state.has(instance_id):")
	_line("\t\t\t_def_of[instance_id] = def_id")
	_line("\t\t\t_init_state_for(instance_id, def_id)")
	_line("\t\treturn")
	_line("\tkit.interactables[instance_id] = kit.interactables[def_id]")
	_line("\tkit.interactable_order.append(instance_id)")
	_line("\t_def_of[instance_id] = def_id")
	_line("\t_init_state_for(instance_id, def_id)")
	_line("")
	# Lowered per-definition state initialization.
	_line("func _init_state_for(instance_id: String, def_id: String) -> void:")
	_line("\tvar rec := {}")
	var first := true
	for did: String in _kit.interactable_order:
		var it: InteractionKit.Interactable = _kit.interactables[did]
		var kw := "if" if first else "elif"
		first = false
		_line("\t%s def_id == %s:" % [kw, _quote(did)])
		if it.state_order.is_empty():
			_line("\t\tpass")
		else:
			for field: String in it.state_order:
				var slot: InteractionKit.TypedSlot = it.state_schema[field]
				_line("\t\trec[%s] = %s" % [_quote(field), _init_literal(slot)])
	if first:
		# No interactables (degenerate); avoid an empty if.
		_line("\tpass")
	_line("\tstate[instance_id] = rec")
	_line("")

func _init_literal(slot: InteractionKit.TypedSlot) -> String:
	match slot.type:
		"number":
			return _fmt_float(float(slot.init))
		"bool":
			return "true" if bool(slot.init) else "false"
		"socket":
			return "null"
		_:
			# enum / ref: stored as their init value (string).
			if typeof(slot.init) == TYPE_STRING:
				return _quote(str(slot.init))
			return "null"

# ---------------------------------------------------------------------------
# step() — the tick, mirroring InteractionInterpreter.step (§5).
# ---------------------------------------------------------------------------

func _emit_step() -> void:
	_line("func step(dt: float) -> void:")
	_line("\tvar frame: ResolvedFrame = host.host_build_frame()")
	_line("\t_frame = frame")
	_line("\t_events.clear()")
	_line("\t_run_tick(frame, dt)")
	_line("\t_process_verb_fire(frame, dt)")
	_line("\t_propagate_events(frame, dt)")
	_line("")

# ---------------------------------------------------------------------------
# _run_tick — declared-order pass; each interactable's while-guarded tick effects
# inlined. `_self` is the iteration key (the INSTANCE id). owner refs/regions come
# from the shared definition, so cross-object reads use the runtime instance's
# def — but in the slice every interactable with a ref/region is a singleton, so
# the inlined guard reads owner refs by name via the kernels (def-resolved).
# ---------------------------------------------------------------------------

func _emit_run_tick() -> void:
	_line("func _run_tick(frame: ResolvedFrame, dt: float) -> void:")
	_line("\tfor _self in kit.interactable_order:")
	_line("\t\tvar _def := _def_id_of(_self)")
	var first := true
	var any_tick := false
	for did: String in _kit.interactable_order:
		var it: InteractionKit.Interactable = _kit.interactables[did]
		if it.tick.is_empty():
			continue
		any_tick = true
		var kw := "if" if first else "elif"
		first = false
		_line("\t\t%s _def == %s:" % [kw, _quote(did)])
		_emit_def_owner(did, "\t\t\t")
		for te: InteractionKit.TickEffect in it.tick:
			_line("\t\t\tif %s:" % _lower_guard(te.while_guard, did, "_self"))
			_emit_effects(te.do_effects, did, "_self", "\t\t\t\t")
	if not any_tick:
		_line("\t\tpass")
	_line("")

## Emit a local `_owner` bound to the interactable's DEFINITION (the shared object
## carrying refs/regions/tags). Effects/guards close over `_owner` and `_self`.
func _emit_def_owner(did: String, indent: String) -> void:
	_line("%svar _owner: InteractionKit.Interactable = kit.interactables[%s]" % [indent, _quote(did)])

# ---------------------------------------------------------------------------
# _process_verb_fire — mirrors InteractionInterpreter._process_verb_fire precedence
# exactly, as DATA-ordered resolution. The chosen verb's effects run straight-line.
# ---------------------------------------------------------------------------

func _emit_process_verb_fire() -> void:
	_line("func _process_verb_fire(frame: ResolvedFrame, dt: float) -> void:")
	_line("\tvar interact_edge := frame.is_edge(\"interact\")")
	_line("\tvar throw_edge := frame.is_edge(\"throw\")")
	_line("\tif not interact_edge and not throw_edge:")
	_line("\t\treturn")
	_line("\t# THROW edge: a carry_release(throw) on the held body, if holding.")
	_line("\tif throw_edge and frame.held_id != \"\":")
	_line("\t\tif kit.interactables.has(frame.held_id):")
	_line("\t\t\t_fire_verb(frame.held_id, frame.held_id, frame, dt, \"carry_release\", \"throw\")")
	_line("\t\treturn")
	_line("\tif not interact_edge:")
	_line("\t\treturn")
	_line("\t# INTERACT edge precedence: place(focus) > drop(held) > grab(focus) > command(focus).")
	_line("\tif frame.held_id != \"\":")
	_line("\t\tif frame.focus_id != \"\" and kit.interactables.has(frame.focus_id):")
	_line("\t\t\tif _fire_verb(frame.focus_id, frame.focus_id, frame, dt, \"place\", \"\"):")
	_line("\t\t\t\treturn")
	_line("\t\tif kit.interactables.has(frame.held_id):")
	_line("\t\t\tif not _fire_verb(frame.held_id, frame.held_id, frame, dt, \"carry_release\", \"drop\"):")
	_line("\t\t\t\thost.host_release(\"drop\", 0.0)")
	_line("\t\telse:")
	_line("\t\t\thost.host_release(\"drop\", 0.0)")
	_line("\t\treturn")
	_line("\tif frame.focus_id == \"\" or not kit.interactables.has(frame.focus_id):")
	_line("\t\treturn")
	_line("\tif _fire_verb(frame.focus_id, frame.focus_id, frame, dt, \"grab\", \"\"):")
	_line("\t\treturn")
	_line("\t_fire_verb(frame.focus_id, frame.focus_id, frame, dt, \"command\", \"\")")
	_line("")

# ---------------------------------------------------------------------------
# _fire_verb / _find_verb — find the first verb of the given kind (and optional
# name) on `def_id` whose guard holds, and run its effects. Inlined per definition.
# Returns true if a verb fired. self_id is the acting instance.
# ---------------------------------------------------------------------------

func _emit_find_verb() -> void:
	_line("func _fire_verb(def_id_inst: String, self_id: String, frame: ResolvedFrame, dt: float, kind: String, name_hint: String) -> bool:")
	_line("\tvar _def := _def_id_of(def_id_inst)")
	_line("\tvar _self := self_id")
	var first := true
	for did: String in _kit.interactable_order:
		var it: InteractionKit.Interactable = _kit.interactables[did]
		# Only emit a branch if the def has at least one verb.
		if it.verbs.is_empty():
			continue
		var kw := "if" if first else "elif"
		first = false
		_line("\t%s _def == %s:" % [kw, _quote(did)])
		_emit_def_owner(did, "\t\t")
		# Group verbs by their guard chain; preserve declared order, first match wins.
		var emitted := false
		for v: InteractionKit.Verb in it.verbs:
			emitted = true
			# kind must match; name_hint must match when non-"".
			var cond := "kind == %s" % _quote(v.kind)
			cond += " and (name_hint == \"\" or name_hint == %s)" % _quote(v.name)
			var guard_expr := _lower_guard(v.when_guard, did, "_self")
			_line("\t\tif %s and (%s):" % [cond, guard_expr])
			_emit_effects(v.do_effects, did, "_self", "\t\t\t")
			_line("\t\t\treturn true")
		if not emitted:
			_line("\t\tpass")
	if first:
		_line("\tpass")
	_line("\treturn false")
	_line("")

# ---------------------------------------------------------------------------
# _propagate_events — bounded, declared-order, load-acyclic pass (§5 step 4),
# preserved verbatim in structure; reaction matching inlined per definition.
# ---------------------------------------------------------------------------

func _emit_propagate() -> void:
	_line("func _propagate_events(frame: ResolvedFrame, dt: float) -> void:")
	_line("\tvar depth := 0")
	_line("\twhile not _events.is_empty() and depth < MAX_PROPAGATION:")
	_line("\t\tdepth += 1")
	_line("\t\tvar batch := _events.duplicate()")
	_line("\t\t_events.clear()")
	_line("\t\tfor ev: Dictionary in batch:")
	_line("\t\t\tfor _self in kit.interactable_order:")
	_line("\t\t\t\t_react(_self, ev, frame, dt)")
	_line("")
	# Per-definition reaction dispatch.
	_line("func _react(self_id: String, ev: Dictionary, frame: ResolvedFrame, dt: float) -> void:")
	_line("\tvar _def := _def_id_of(self_id)")
	_line("\tvar _self := self_id")
	var first := true
	var any_react := false
	for did: String in _kit.interactable_order:
		var it: InteractionKit.Interactable = _kit.interactables[did]
		if it.reactions.is_empty():
			continue
		any_react = true
		var kw := "if" if first else "elif"
		first = false
		_line("\t%s _def == %s:" % [kw, _quote(did)])
		_emit_def_owner(did, "\t\t")
		for rx: InteractionKit.Reaction in it.reactions:
			# Resolve the source id: self -> self_id; ref:<name> -> owner.refs[name].
			var src_expr := ""
			if rx.on_from.begins_with("ref:"):
				var rn := rx.on_from.substr(4)
				src_expr = "str(_owner.refs.get(%s, \"\"))" % _quote(rn)
			else:
				src_expr = "_self"
			_line("\t\tif ev[\"event\"] == %s and ev[\"from\"] == %s:" % [_quote(rx.on_event), src_expr])
			var indent := "\t\t\t"
			if rx.when_guard != null and typeof(rx.when_guard) == TYPE_DICTIONARY:
				_line("\t\t\tif %s:" % _lower_guard(rx.when_guard, did, "_self"))
				indent = "\t\t\t\t"
			_emit_effects(rx.do_effects, did, "_self", indent)
	if not any_react:
		_line("\tpass")
	_line("")

# ---------------------------------------------------------------------------
# Guard lowering → inline boolean EXPRESSION (no runtime _eval_guard dispatch).
# Leaf ops call _g_* kernels copied from the interpreter; composition is
# and/or/not. `did` is the static definition; `self_var` names the runtime self id.
# ---------------------------------------------------------------------------

func _lower_guard(g: Dictionary, did: String, self_var: String) -> String:
	if g.is_empty():
		return "true"
	var op := str(g.get("op", ""))
	match op:
		"all":
			var parts: Array = []
			for sub: Variant in g.get("of", []):
				parts.append(_lower_guard(sub, did, self_var))
			if parts.is_empty():
				return "true"
			return "(" + " and ".join(parts) + ")"
		"any":
			var parts2: Array = []
			for sub2: Variant in g.get("of", []):
				parts2.append(_lower_guard(sub2, did, self_var))
			if parts2.is_empty():
				return "false"
			return "(" + " or ".join(parts2) + ")"
		"not":
			var of: Array = g.get("of", [])
			if of.size() > 0:
				return "(not %s)" % _lower_guard(of[0], did, self_var)
			return "true"
		"is_held":
			return "(frame.held_id != \"\")"
		"held_is":
			return "frame.held_tags.has(%s)" % _quote(str(g.get("tag", "")))
		"focus_is":
			return "_g_focus_is(frame, %s)" % _quote(str(g.get("tag", "")))
		"in_region":
			return "_g_in_region(frame, %s, %s, %s)" % [
				self_var, _quote(str(g.get("region", ""))), _quote(str(g.get("tag", "")))]
		"reached_by_player":
			return "frame.player_reached(%s, %s)" % [self_var, _quote(str(g.get("region", "")))]
		"state_bool":
			return "_g_state_bool(%s, %s, %s, %s, %s)" % [
				_quote(did), self_var, _quote(str(g.get("scope", "self"))), _quote(str(g.get("field", ""))),
				("true" if bool(g.get("value", true)) else "false")]
		"state_cmp":
			return "_g_state_cmp(%s, %s, %s, %s, %s, %s)" % [
				_quote(did), self_var, _quote(str(g.get("scope", "self"))), _quote(str(g.get("field", ""))),
				_quote(str(g.get("cmp", ""))), _lower_value(g.get("value"))]
		"state_enum":
			return "_g_state_enum(%s, %s, %s, %s, %s)" % [
				_quote(did), self_var, _quote(str(g.get("scope", "self"))), _quote(str(g.get("field", ""))),
				_quote(str(g.get("eq", "")))]
		"socket_empty":
			return "_g_socket_empty(%s, %s, %s, %s)" % [
				_quote(did), self_var, _quote(str(g.get("scope", "self"))), _quote(str(g.get("field", "")))]
	push_error("InteractionCompiler: unhandled guard op '%s'" % op)
	return "false"

# `_lower_value` of a state path / param name resolves at runtime via _resolve_value
# kernel (cross-scope state paths must read live records). Plain numbers fold.
func _lower_value(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return _fmt_float(float(v))
		TYPE_STRING:
			var s := v as String
			if s.contains("."):
				# Cross-scope state path: resolved at runtime (reads live state/params).
				return "_resolve_value_path(%s, frame)" % _quote(s)
			if _kit.params.has(s):
				return _const_name(s)
			# Unknown param resolves to 0.0 in the interpreter.
			return "0.0"
	return "0.0"

# ---------------------------------------------------------------------------
# Effect lowering → straight-line statements / kernel calls, in listed order.
# A guarded effect carries its own `when`; lowered as an `if <guard>:` wrapper.
# `did` is the static def; effects close over local `_owner` (the def) + self_var.
# ---------------------------------------------------------------------------

func _emit_effects(effects: Array, did: String, self_var: String, indent: String) -> void:
	for e: Variant in effects:
		_emit_effect(e, did, self_var, indent)

func _emit_effect(e: Dictionary, did: String, self_var: String, indent: String) -> void:
	# Guarded effect: wrap in an if when present.
	var eff_indent := indent
	if e.has("when") and typeof(e["when"]) == TYPE_DICTIONARY:
		_line("%sif %s:" % [indent, _lower_guard(e["when"], did, self_var)])
		eff_indent = indent + "\t"
	var op := str(e.get("do", ""))
	var scope := _quote(str(e.get("scope", "self")))
	var field := _quote(str(e.get("field", "")))
	match op:
		"set_state":
			_line("%s_e_set_state(%s, %s, %s, %s, frame, %s)" % [
				eff_indent, _quote(did), self_var, scope, field, _lower_literal(e.get("value"))])
		"toggle_state":
			_line("%s_e_toggle_state(%s, %s, %s, %s, frame)" % [
				eff_indent, _quote(did), self_var, scope, field])
		"add_fill":
			_line("%s_e_add_fill(%s, %s, %s, %s, frame, %s, dt)" % [
				eff_indent, _quote(did), self_var, scope, field, _lower_value(e.get("rate"))])
		"emit":
			_line("%s_events.append({ \"from\": %s, \"event\": %s })" % [
				eff_indent, self_var, _quote(str(e.get("signal", "")))])
		"arm", "trigger":
			# Both set the target field true (trigger is idempotent: true again is true).
			_line("%s_e_set_true(%s, %s, %s, %s, frame)" % [
				eff_indent, _quote(did), self_var, scope, field])
		"consume_into_socket":
			_line("%s_e_consume_into_socket(%s, %s, %s, %s, frame)" % [
				eff_indent, _quote(did), self_var, scope, field])
		"grab_body":
			_line("%shost.host_grab(%s)" % [eff_indent, self_var])
		"release":
			_line("%shost.host_release(%s, 0.0)" % [eff_indent, _quote(str(e.get("mode", "drop")))])
		"apply_impulse":
			_line("%shost.host_apply_impulse(%s)" % [eff_indent, _lower_value(e.get("magnitude"))])
		_:
			push_error("InteractionCompiler: unhandled effect op '%s'" % op)

## A literal value for set_state (bool / number / string). Numbers/bools fold;
## strings are quoted; param names are NOT special here (set_state values in the
## slice are literal booleans).
func _lower_literal(v: Variant) -> String:
	match typeof(v):
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_FLOAT, TYPE_INT:
			return _fmt_float(float(v))
		TYPE_STRING:
			return _quote(str(v))
		TYPE_NIL:
			return "null"
	return "null"

# ---------------------------------------------------------------------------
# Guard kernels — copied from InteractionInterpreter so logic is identical. These
# resolve a scope to its state record and apply the leaf predicate. The dispatch
# (match op) is what the compiler removed; the arithmetic is verbatim.
# ---------------------------------------------------------------------------

func _emit_guard_kernels() -> void:
	var k := """
func _g_focus_is(frame: ResolvedFrame, tag: String) -> bool:
	if frame.focus_id == "":
		return false
	var fit: InteractionKit.Interactable = kit.interactables.get(frame.focus_id)
	return fit != null and fit.tags.has(tag)

func _g_in_region(frame: ResolvedFrame, self_id: String, region: String, tag: String) -> bool:
	var members := frame.members(self_id, region)
	if tag == "":
		return not members.is_empty()
	for mid: String in members:
		var mit: InteractionKit.Interactable = kit.interactables.get(mid)
		if mit != null and mit.tags.has(tag):
			return true
	return false

func _g_state_bool(def_id: String, self_id: String, scope: String, field: String, value: bool) -> bool:
	var rec := _scope_record(def_id, scope, self_id, _frame)
	return bool(rec.get(field, false)) == value

func _g_state_cmp(def_id: String, self_id: String, scope: String, field: String, cmp: String, rhs: float) -> bool:
	var rec := _scope_record(def_id, scope, self_id, _frame)
	var lhs := float(rec.get(field, 0.0))
	return _cmp(lhs, cmp, rhs)

func _g_state_enum(def_id: String, self_id: String, scope: String, field: String, eq: String) -> bool:
	var rec := _scope_record(def_id, scope, self_id, _frame)
	return str(rec.get(field, "")) == eq

func _g_socket_empty(def_id: String, self_id: String, scope: String, field: String) -> bool:
	var rec := _scope_record(def_id, scope, self_id, _frame)
	return rec.get(field, null) == null

func _cmp(lhs: float, op: String, rhs: float) -> bool:
	match op:
		"ge": return lhs >= rhs
		"gt": return lhs > rhs
		"le": return lhs <= rhs
		"lt": return lhs < rhs
		"eq": return is_equal_approx(lhs, rhs)
	return false

## Resolve a scope to its state record. self -> the acting INSTANCE id; held/focus
## -> the frame's held/focus; ref:<name> -> the def's declared ref record.
func _scope_record(def_id: String, scope: String, self_id: String, frame: ResolvedFrame) -> Dictionary:
	if scope == "self":
		return state.get(self_id, {})
	if scope == "held":
		return state.get(frame.held_id, {})
	if scope == "focus":
		return state.get(frame.focus_id, {})
	if scope.begins_with("ref:"):
		var owner: InteractionKit.Interactable = kit.interactables.get(def_id)
		var tgt := str(owner.refs.get(scope.substr(4), "")) if owner != null else ""
		return state.get(tgt, {})
	return {}
"""
	for ln in k.split("\n"):
		_line(ln)

# ---------------------------------------------------------------------------
# Effect kernels — copied from InteractionInterpreter so logic is identical.
# Guard kernels read a frame; since the inlined guard expressions can't easily pass
# `frame` through deeply, the kernels read `_frame`, set per-tick scope. To keep
# bit-parity we also pass the frame explicitly to effect kernels (no hidden state).
# ---------------------------------------------------------------------------

func _emit_effect_kernels() -> void:
	var k := """
## The current resolved frame, set at the top of each kernel-using pass. Used only
## by guard kernels invoked from inline boolean expressions (they cannot thread the
## frame argument). step() sets it once per tick; identical to the interpreter's
## per-tick frame, so guard evaluation is bit-identical.
var _frame: ResolvedFrame = null

func _e_set_state(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame, value) -> void:
	var rec := _scope_record(def_id, scope, self_id, frame)
	rec[field] = value

func _e_set_true(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame) -> void:
	var rec := _scope_record(def_id, scope, self_id, frame)
	rec[field] = true

func _e_toggle_state(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame) -> void:
	var rec := _scope_record(def_id, scope, self_id, frame)
	rec[field] = not bool(rec.get(field, false))

func _e_consume_into_socket(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame) -> void:
	var rec := _scope_record(def_id, scope, self_id, frame)
	rec[field] = frame.held_id
	host.host_socket(self_id, frame.held_id)

func _e_add_fill(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame, rate: float, dt: float) -> void:
	if scope.begins_with("region:"):
		var parts := scope.split(":")
		var region := parts[1] if parts.size() > 1 else ""
		var tag := parts[2] if parts.size() > 2 else ""
		for mid: String in frame.members(self_id, region):
			var mit: InteractionKit.Interactable = kit.interactables.get(mid)
			if mit == null:
				continue
			if tag != "" and not mit.tags.has(tag):
				continue
			_apply_fill(mid, field, rate * dt)
		return
	var rec := _scope_record(def_id, scope, self_id, frame)
	var target_id := _scope_owner_id(def_id, scope, self_id, frame)
	if target_id != "":
		_apply_fill(target_id, field, rate * dt)
	elif rec.has(field):
		rec[field] = float(rec[field]) + rate * dt

func _apply_fill(id: String, field: String, amount: float) -> void:
	var rec: Dictionary = state.get(id, {})
	if not rec.has(field):
		return
	var slot := _slot_for(id, field)
	var v := float(rec[field]) + amount
	if slot != null and slot.has_bounds:
		v = clampf(v, slot.lo, slot.hi)
	rec[field] = v

func _slot_for(id: String, field: String) -> InteractionKit.TypedSlot:
	var it: InteractionKit.Interactable = kit.interactables.get(id)
	if it == null:
		return null
	return it.state_schema.get(field)

func _scope_owner_id(def_id: String, scope: String, self_id: String, frame: ResolvedFrame) -> String:
	if scope == "self":
		return self_id
	if scope == "held":
		return frame.held_id
	if scope == "focus":
		return frame.focus_id
	if scope.begins_with("ref:"):
		var owner: InteractionKit.Interactable = kit.interactables.get(def_id)
		return str(owner.refs.get(scope.substr(4), "")) if owner != null else ""
	return ""
"""
	for ln in k.split("\n"):
		_line(ln)

# ---------------------------------------------------------------------------
# Value path kernel — cross-scope state path / param resolution, copied verbatim.
# Inline guards thread `frame` directly; this resolves "<scope>.<field>".
# ---------------------------------------------------------------------------

func _emit_value_kernels() -> void:
	var k := """
## Resolve a cross-scope state path "<scope>.<field>" against the live record, with
## a param-table fallback (e.g. "held.full_threshold" is the full_threshold PARAM).
## Self-scope context for the path's <scope> uses the frame's held/focus; "ref:"
## paths are not used as guard VALUES in the slice, so the def is the current frame
## focus def when needed — but in practice slice values are held.<param>.
func _resolve_value_path(s: String, frame: ResolvedFrame) -> float:
	if not s.contains("."):
		return float(kit.params.get(s, 0.0))
	var parts := s.split(".")
	var scope := parts[0]
	var field := parts[1]
	var rec := _scope_record_for_value(scope, frame)
	if rec.has(field):
		return float(rec[field])
	return float(kit.params.get(field, 0.0))

## A reduced scope_record for value paths: scope is self/held/focus (no def-ref
## needed — value paths in the slice read held.<x>). self maps to focus (the acting
## target) for value context; the interpreter resolves the same way via its owner.
func _scope_record_for_value(scope: String, frame: ResolvedFrame) -> Dictionary:
	if scope == "held":
		return state.get(frame.held_id, {})
	if scope == "focus":
		return state.get(frame.focus_id, {})
	return {}
"""
	for ln in k.split("\n"):
		_line(ln)

# ---------------------------------------------------------------------------
# Prompt projection — render-side, excluded from the sim hash, but provided so the
# compiled path exposes the SAME host-facing surface. Reuses the interpreter's
# projection logic (it is render-only and not part of equivalence). For parity of
# interface we delegate to a small inline copy mirroring InteractionInterpreter.
# ---------------------------------------------------------------------------

func _emit_prompt() -> void:
	var k := """
## Project the contextual prompt this tick (render-side; not part of equivalence).
## Mirrors InteractionInterpreter.project_prompt: place(focus) > drop line > first
## available focus verb. Verb availability uses the same inlined guard kernels.
func project_prompt(frame: ResolvedFrame) -> String:
	_frame = frame
	if frame.held_id != "":
		if frame.focus_id != "" and kit.interactables.has(frame.focus_id):
			var fdef := _def_id_of(frame.focus_id)
			var fit: InteractionKit.Interactable = kit.interactables[frame.focus_id]
			for v: InteractionKit.Verb in fit.verbs:
				if v.kind == "place" and _eval_guard_dyn(v.when_guard, fdef, frame.focus_id, frame):
					return _render_prompt(v, fit, frame.focus_id, frame)
		return "[E] Drop    [F] Throw"
	if frame.focus_id == "" or not kit.interactables.has(frame.focus_id):
		return ""
	var def := _def_id_of(frame.focus_id)
	var it: InteractionKit.Interactable = kit.interactables[frame.focus_id]
	for v: InteractionKit.Verb in it.verbs:
		if v.kind == "carry_release":
			continue
		if _eval_guard_dyn(v.when_guard, def, frame.focus_id, frame):
			var text := _render_prompt(v, it, frame.focus_id, frame)
			if text != "":
				return text
	return ""

## A small dynamic guard evaluator used ONLY by the render-side prompt projection
## (not the sim hash path). Mirrors InteractionInterpreter._eval_guard. The hot tick
## path uses the inlined guard EXPRESSIONS; prompts are recomputed off the sim loop.
func _eval_guard_dyn(g: Dictionary, def_id: String, self_id: String, frame: ResolvedFrame) -> bool:
	if g.is_empty():
		return true
	var op := str(g.get("op", ""))
	match op:
		"all":
			for sub: Variant in g.get("of", []):
				if not _eval_guard_dyn(sub, def_id, self_id, frame):
					return false
			return true
		"any":
			for sub: Variant in g.get("of", []):
				if _eval_guard_dyn(sub, def_id, self_id, frame):
					return true
			return false
		"not":
			var of: Array = g.get("of", [])
			return not _eval_guard_dyn(of[0], def_id, self_id, frame) if of.size() > 0 else true
		"is_held":
			return frame.held_id != ""
		"held_is":
			return frame.held_tags.has(str(g.get("tag", "")))
		"focus_is":
			return _g_focus_is(frame, str(g.get("tag", "")))
		"in_region":
			return _g_in_region(frame, self_id, str(g.get("region", "")), str(g.get("tag", "")))
		"reached_by_player":
			return frame.player_reached(self_id, str(g.get("region", "")))
		"state_bool":
			var rec := _scope_record(def_id, str(g.get("scope", "self")), self_id, frame)
			return bool(rec.get(str(g.get("field", "")), false)) == bool(g.get("value", true))
		"state_cmp":
			var rec2 := _scope_record(def_id, str(g.get("scope", "self")), self_id, frame)
			return _cmp(float(rec2.get(str(g.get("field", "")), 0.0)), str(g.get("cmp", "")), _resolve_value_dyn(g.get("value"), def_id, self_id, frame))
		"state_enum":
			var rec3 := _scope_record(def_id, str(g.get("scope", "self")), self_id, frame)
			return str(rec3.get(str(g.get("field", "")), "")) == str(g.get("eq", ""))
		"socket_empty":
			var rec4 := _scope_record(def_id, str(g.get("scope", "self")), self_id, frame)
			return rec4.get(str(g.get("field", "")), null) == null
	return false

func _resolve_value_dyn(v: Variant, def_id: String, self_id: String, frame: ResolvedFrame) -> float:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return float(v)
		TYPE_STRING:
			var s := v as String
			if s.contains("."):
				var parts := s.split(".")
				var rec := _scope_record(def_id, parts[0], self_id, frame)
				if rec.has(parts[1]):
					return float(rec[parts[1]])
				return float(kit.params.get(parts[1], 0.0))
			return float(kit.params.get(s, 0.0))
	return 0.0

func _render_prompt(v: InteractionKit.Verb, it: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> String:
	var def := _def_id_of(self_id)
	var template := ""
	match typeof(v.prompt):
		TYPE_STRING:
			template = v.prompt
		TYPE_ARRAY:
			for variant: Variant in v.prompt:
				if typeof(variant) != TYPE_DICTIONARY:
					continue
				var w: Variant = variant.get("when", null)
				if w == null or (typeof(w) == TYPE_DICTIONARY and _eval_guard_dyn(w, def, self_id, frame)):
					template = str(variant.get("text", ""))
					break
	return _interpolate(template, v, it, self_id, frame)

func _interpolate(template: String, v: InteractionKit.Verb, it: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> String:
	if not template.contains("{"):
		return template
	var out := template
	var def := _def_id_of(self_id)
	var default_scope := "held" if v.kind == "place" else "self"
	var rx := RegEx.new()
	rx.compile("\\\\{([^}]*)\\\\}")
	for m in rx.search_all(template):
		var inner := m.get_string(1).strip_edges()
		var as_pct := false
		if inner.begins_with("pct "):
			as_pct = true
			inner = inner.substr(4).strip_edges()
		var scope := default_scope
		var field := inner
		if inner.contains("."):
			var parts := inner.split(".")
			scope = parts[0]
			field = parts[1]
		var rec := _scope_record(def, scope, self_id, frame)
		var value: Variant = rec.get(field, 0.0)
		var rendered := ""
		if as_pct:
			rendered = "%d" % int(round(float(value) * 100.0))
		else:
			rendered = str(value)
		out = out.replace(m.get_string(0), rendered)
	return out
"""
	for ln in k.split("\n"):
		_line(ln)

# ---------------------------------------------------------------------------
# Emit helpers
# ---------------------------------------------------------------------------

func _quote(s: String) -> String:
	return "\"%s\"" % s.replace("\\", "\\\\").replace("\"", "\\\"")

func _fmt_float(v: float) -> String:
	if v == floor(v) and absf(v) < 1e15:
		return "%.1f" % v
	return str(v)
