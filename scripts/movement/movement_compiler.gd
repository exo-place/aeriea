## MovementCompiler — lowers a flattened MovementKit to GDScript source that
## implements the SAME state machine as MovementInterpreter, but as direct
## branching code (docs/decisions/movement-substrate.md §4b).
##
## This is the COMPILER half of projection-from-one-definition: the interpreter
## is the reference semantics; this tool emits a faithful lowering of the same
## kit. The two must produce bit-identical MovementState trajectories on one
## runtime (enforced by the golden-trace harness, tests/golden_trace_test.gd).
##
## HOW IT LOWERS (the dispatch-removal win):
##   - Params     → consts  (`const P_walk_speed := 5.5`), referenced by name.
##   - States     → an if/elif chain in step(); the active state's transitions
##                  and tick effects are inlined straight-line, no per-tick
##                  `match op` tag dispatch over Dictionaries.
##   - Conditions → inline boolean EXPRESSIONS. `all`/`any`/`not` become
##                  `and`/`or`/`not`; leaf ops become direct calls/comparisons.
##                  No recursive _eval_condition dispatch at runtime.
##   - Effects    → direct kernel calls with constant-folded args, in listed
##                  order. The kernels (_k_*) are the SAME arithmetic as the
##                  interpreter's effect kernels — copied, not reinterpreted —
##                  so numerics match bit-for-bit.
##   - Transitions are emitted per state in PRIORITY-SORTED order (the kit
##                  loader already sorts them), as an if/elif chain; first match
##                  wins, exactly like the interpreter.
##   - reenter / pre_tick / input sampling / timer decrement all mirror the
##                  interpreter's tick structure (§3) line-for-line.
##
## The compiler is a pure function MovementKit → String. Output is committed and
## regenerated; see regen command in the generated header.
class_name MovementCompiler
extends RefCounted

const GUARD_LIMIT := 8

## Compile a kit to GDScript source for a class named `class_name_str`.
## `kit_path` is recorded in the header for the regen note.
static func compile(kit: MovementKit, class_name_str: String, kit_path: String) -> String:
	var c := MovementCompiler.new()
	return c._compile(kit, class_name_str, kit_path)

var _out: PackedStringArray = PackedStringArray()
var _kit: MovementKit

func _line(s: String = "") -> void:
	_out.append(s)

func _compile(kit: MovementKit, class_name_str: String, kit_path: String) -> String:
	_kit = kit
	_out = PackedStringArray()

	_emit_header(class_name_str, kit_path)
	_emit_fields()
	_emit_consts()
	_emit_setup()
	_emit_reset()
	_emit_step()
	_emit_input_sampling()
	_emit_transition_dispatch()
	_emit_tick_dispatch()
	_emit_kernels()

	return "\n".join(_out) + "\n"

# ---------------------------------------------------------------------------
# Header + fields + consts
# ---------------------------------------------------------------------------

func _emit_header(class_name_str: String, kit_path: String) -> void:
	_line("## GENERATED from %s — do not edit by hand." % kit_path)
	_line("## Regenerate with:")
	_line("##   nix develop --command bash -lc 'xvfb-run -a godot4 --path . res://tools/regen_compiled_movement.tscn --quit-after 120'")
	_line("##")
	_line("## This is the COMPILED projection of the movement kit (see")
	_line("## docs/decisions/movement-substrate.md §4b and scripts/movement/movement_compiler.gd).")
	_line("## It is a faithful lowering of MovementInterpreter's reference semantics to")
	_line("## direct branching code: transitions are inlined if/elif chains in priority")
	_line("## order, conditions are inline boolean expressions, effects are straight-line")
	_line("## kernel calls. The golden-trace harness asserts interpreter == compiled.")
	_line("class_name %s" % class_name_str)
	_line("extends RefCounted")
	_line("")
	_line("# Mirrors MovementInterpreter's public surface so the same host (InterpretedPlayer)")
	_line("# can drive either path and the same tests exercise both.")

func _emit_fields() -> void:
	_line("class InputFrame:")
	_line("\textends RefCounted")
	_line("\tvar pressed: Dictionary = {}")
	_line("\tvar wish_dir: Vector3 = Vector3.ZERO")
	_line("\tfunc is_pressed(action: String) -> bool:")
	_line("\t\treturn bool(pressed.get(action, false))")
	_line("")
	_line("var kit: MovementKit")
	_line("var body: CharacterBody3D")
	_line("var active_state: String = \"\"")
	_line("var timers: Dictionary = {}")
	_line("var gravity: float = 9.8")
	_line("var wall_normal: Vector3 = Vector3.ZERO")
	_line("var wall_side: float = 0.0")
	_line("var _held_last: Dictionary = {}")
	_line("var yaw: float = 0.0")
	_line("var pitch: float = 0.0")
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
	return "P_" + param

# ---------------------------------------------------------------------------
# setup / reset — mirror MovementInterpreter exactly
# ---------------------------------------------------------------------------

func _emit_setup() -> void:
	_line("func setup(p_kit: MovementKit, p_body: CharacterBody3D) -> void:")
	_line("\tkit = p_kit")
	_line("\tbody = p_body")
	_line("\tgravity = ProjectSettings.get_setting(\"physics/3d/default_gravity\", 9.8)")
	_line("\tactive_state = %s" % _quote(_kit.initial))
	_line("\ttimers = {}")
	_line("\tfor action in kit.inputs:")
	_line("\t\ttimers[action] = 0.0")
	_line("\tfor t in [\"coyote\", \"jump_buffer\", \"jump_hold\", \"slide\", \"slide_steer\", \"wall_run\", \"wall_jump_grace\", \"vault\"]:")
	_line("\t\ttimers[t] = 0.0")
	_line("\tfor action in kit.inputs:")
	_line("\t\t_held_last[action] = false")
	_line("")

func _emit_reset() -> void:
	_line("func reset_state() -> void:")
	_line("\tactive_state = %s" % _quote(_kit.initial))
	_line("\twall_normal = Vector3.ZERO")
	_line("\twall_side = 0.0")
	_line("\tfor k in timers:")
	_line("\t\ttimers[k] = 0.0")
	_line("")

# ---------------------------------------------------------------------------
# step() — the tick, mirroring MovementInterpreter.step (§3)
# ---------------------------------------------------------------------------

func _emit_step() -> void:
	_line("func step(dt: float) -> void:")
	_line("\tvar frame := _sample_input(dt)")
	_line("")
	_line("\t# Pre-tick transitions (e.g. below_y → respawn). A firing pre_tick aborts the tick.")
	for tr: MovementKit.Transition in _kit.pre_tick:
		_line("\tif %s:" % _lower_condition(tr.when_cond))
		_emit_effects(tr.do_effects, "\t\t")
		_line("\t\tactive_state = %s" % _quote(tr.to_state))
		_line("\t\treturn")
	_line("")
	_line("\t# Decrement countdown timers (jump_hold / slide_steer excluded).")
	_line("\tfor tname in timers:")
	_line("\t\tif tname == \"jump_hold\" or tname == \"slide_steer\":")
	_line("\t\t\tcontinue")
	_line("\t\ttimers[tname] = maxf(0.0, float(timers[tname]) - dt)")
	_line("")
	_line("\t# Transition evaluation with bounded reenter loop, then tick.")
	_line("\tvar guard := 0")
	_line("\twhile guard < %d:" % GUARD_LIMIT)
	_line("\t\tguard += 1")
	_line("\t\tif not _eval_transitions(frame, dt):")
	_line("\t\t\tbreak")
	_line("\t_run_tick(frame, dt)")
	_line("")

# ---------------------------------------------------------------------------
# _sample_input — byte-identical to MovementInterpreter._sample_input
# ---------------------------------------------------------------------------

func _emit_input_sampling() -> void:
	_line("func _sample_input(dt: float) -> InputFrame:")
	_line("\tvar frame := InputFrame.new()")
	_line("\tvar actions := [\"move_forward\", \"move_backward\", \"move_left\", \"move_right\", \"sprint\", \"crouch\"]")
	_line("\tfor a in kit.inputs:")
	_line("\t\tif not actions.has(a):")
	_line("\t\t\tactions.append(a)")
	_line("\tfor a in actions:")
	_line("\t\tframe.pressed[a] = InputMap.has_action(a) and Input.is_action_pressed(a)")
	_line("\tfor action in kit.inputs:")
	_line("\t\tvar spec: MovementKit.InputSpec = kit.inputs[action]")
	_line("\t\tvar held_now: bool = frame.is_pressed(action)")
	_line("\t\tvar held_prev: bool = bool(_held_last.get(action, false))")
	_line("\t\tif spec.buffer_param != \"\" and held_now and not held_prev:")
	_line("\t\t\ttimers[action] = kit.params.get(spec.buffer_param, 0.0)")
	_line("\t\tif spec.track_hold:")
	_line("\t\t\tif held_now:")
	_line("\t\t\t\ttimers[\"jump_hold\"] = float(timers.get(\"jump_hold\", 0.0)) + dt")
	_line("\t\t\telse:")
	_line("\t\t\t\ttimers[\"jump_hold\"] = 0.0")
	_line("\t\t_held_last[action] = held_now")
	_line("\tvar input := Vector2.ZERO")
	_line("\tif frame.is_pressed(\"move_forward\"):")
	_line("\t\tinput.y -= 1.0")
	_line("\tif frame.is_pressed(\"move_backward\"):")
	_line("\t\tinput.y += 1.0")
	_line("\tif frame.is_pressed(\"move_left\"):")
	_line("\t\tinput.x -= 1.0")
	_line("\tif frame.is_pressed(\"move_right\"):")
	_line("\t\tinput.x += 1.0")
	_line("\tif input.length_squared() >= 0.001:")
	_line("\t\tinput = input.normalized()")
	_line("\t\tvar basis_y := Basis(Vector3.UP, yaw)")
	_line("\t\tframe.wish_dir = basis_y * Vector3(input.x, 0.0, input.y)")
	_line("\treturn frame")
	_line("")

# ---------------------------------------------------------------------------
# _eval_transitions — per-state if/elif chain over priority-sorted transitions.
# Returns true if a reenter transition fired (loop again), false otherwise.
# Mirrors the interpreter's transition loop body (on_exit → do → on_enter).
# ---------------------------------------------------------------------------

func _emit_transition_dispatch() -> void:
	_line("func _eval_transitions(frame: InputFrame, dt: float) -> bool:")
	var first := true
	for sname: String in _kit.state_order:
		var st: MovementKit.MovementState = _kit.states[sname]
		var kw := "if" if first else "elif"
		first = false
		_line("\t%s active_state == %s:" % [kw, _quote(sname)])
		if st.transitions.is_empty():
			_line("\t\treturn false")
			continue
		var tfirst := true
		for tr: MovementKit.Transition in st.transitions:
			var tkw := "if" if tfirst else "elif"
			tfirst = false
			_line("\t\t%s %s:" % [tkw, _lower_condition(tr.when_cond)])
			# on_exit (old state) -> do -> on_enter (new state)
			_emit_effects(st.on_exit, "\t\t\t")
			_emit_effects(tr.do_effects, "\t\t\t")
			_line("\t\t\tactive_state = %s" % _quote(tr.to_state))
			var new_state: MovementKit.MovementState = _kit.states[tr.to_state]
			_emit_effects(new_state.on_enter, "\t\t\t")
			_line("\t\t\treturn %s" % ("true" if tr.reenter else "false"))
		_line("\t\treturn false")
	_line("\treturn false")
	_line("")

# ---------------------------------------------------------------------------
# _run_tick — per-state tick effect list, straight-line.
# ---------------------------------------------------------------------------

func _emit_tick_dispatch() -> void:
	_line("func _run_tick(frame: InputFrame, dt: float) -> void:")
	var first := true
	for sname: String in _kit.state_order:
		var st: MovementKit.MovementState = _kit.states[sname]
		var kw := "if" if first else "elif"
		first = false
		_line("\t%s active_state == %s:" % [kw, _quote(sname)])
		if st.tick.is_empty():
			_line("\t\tpass")
		else:
			_emit_effects(st.tick, "\t\t")
	_line("")

# ---------------------------------------------------------------------------
# Condition lowering → inline boolean EXPRESSION (no runtime dispatch).
# ---------------------------------------------------------------------------

func _lower_condition(cond: Dictionary) -> String:
	var op: String = str(cond.get("op", ""))
	match op:
		"on_ground":
			return "body.is_on_floor()"
		"airborne":
			return "(not body.is_on_floor())"
		"speed_h":
			return _lower_cmp("_speed_h()", str(cond.get("cmp", "")), cond.get("value"))
		"speed_v":
			return _lower_cmp("body.velocity.y", str(cond.get("cmp", "")), cond.get("value"))
		"timer":
			var tn := _quote(str(cond.get("name", "")))
			return _lower_cmp("float(timers.get(%s, 0.0))" % tn, str(cond.get("cmp", "")), cond.get("value"))
		"input_pressed":
			return "frame.is_pressed(%s)" % _quote(str(cond.get("action", "")))
		"input_buffered":
			return "(float(timers.get(%s, 0.0)) > 0.0)" % _quote(str(cond.get("action", "")))
		"wish_input":
			if bool(cond.get("aligned_with_velocity", false)):
				return "_wish_aligned(frame, %s, %s)" % [
					_quote(str(cond.get("cmp", "gt"))), _lower_value(cond.get("value"))]
			return "(frame.wish_dir.length_squared() >= 0.001)"
		"wall_detected":
			return "_probe_walls(%s)" % _quote(str(cond.get("side", "any")))
		"wall_still_near":
			return "_wall_still_near()"
		"ledge_vaultable":
			return "body.host_check_vault()"
		"headroom":
			return "body.host_can_stand()"
		"slope_angle":
			return _lower_cmp("_slope_angle()", str(cond.get("cmp", "")), cond.get("value"))
		"below_y":
			return "(body.global_position.y < %s)" % _lower_value(cond.get("value"))
		"all":
			var parts: Array = []
			for sub: Variant in cond.get("of", []):
				parts.append(_lower_condition(sub))
			if parts.is_empty():
				return "true"
			return "(" + " and ".join(parts) + ")"
		"any":
			var parts2: Array = []
			for sub2: Variant in cond.get("of", []):
				parts2.append(_lower_condition(sub2))
			if parts2.is_empty():
				return "false"
			return "(" + " or ".join(parts2) + ")"
		"not":
			var of: Array = cond.get("of", [])
			if of.size() > 0:
				return "(not %s)" % _lower_condition(of[0])
			return "true"
	push_error("MovementCompiler: unhandled condition op '%s'" % op)
	return "false"

func _lower_cmp(lhs: String, op: String, value: Variant) -> String:
	var rhs := _lower_value(value)
	match op:
		"ge": return "(%s >= %s)" % [lhs, rhs]
		"gt": return "(%s > %s)" % [lhs, rhs]
		"le": return "(%s <= %s)" % [lhs, rhs]
		"lt": return "(%s < %s)" % [lhs, rhs]
		"eq": return "is_equal_approx(%s, %s)" % [lhs, rhs]
	push_error("MovementCompiler: bad cmp '%s'" % op)
	return "false"

# ---------------------------------------------------------------------------
# Value lowering. Number / param-name → const; structured (select/curve) →
# inline expression matching the interpreter's resolvers exactly.
# ---------------------------------------------------------------------------

func _lower_value(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return _fmt_float(float(v))
		TYPE_STRING:
			if _kit.params.has(v):
				return _const_name(str(v))
			# Unknown param name resolves to 0.0 in the interpreter.
			return "0.0"
		TYPE_DICTIONARY:
			return _lower_structured(v)
	return "0.0"

func _lower_structured(d: Dictionary) -> String:
	if d.has("curve"):
		return _lower_curve(d)
	var kind: String = str(d.get("select", ""))
	match kind:
		"sprint":
			var held := "frame.is_pressed(%s)" % _quote(str(d.get("if_held", "sprint")))
			return "(%s if %s else %s)" % [
				_lower_value(d.get("then")), held, _lower_value(d.get("else"))]
		"jump_floaty":
			var action := _quote(str(d.get("if_held", "jump")))
			var held := "frame.is_pressed(%s)" % action
			var gate: Dictionary = d.get("and_timer_lt", {})
			var timer_ok := "true"
			if not gate.is_empty():
				timer_ok = "(float(timers.get(%s, 0.0)) < %s)" % [
					_quote(str(gate.get("name", ""))), _lower_value(gate.get("value"))]
			var rising_ok := "true"
			if bool(d.get("and_rising", false)):
				rising_ok = "(body.velocity.y > 0.0)"
			var floaty := "(%s and %s and %s)" % [held, timer_ok, rising_ok]
			return "(%s if %s else %s)" % [
				_lower_value(d.get("then")), floaty, _lower_value(d.get("else"))]
	push_error("MovementCompiler: unknown structured value 'select=%s'" % kind)
	return "0.0"

func _lower_curve(d: Dictionary) -> String:
	var kind: String = str(d.get("curve", "const"))
	match kind:
		"const":
			return _lower_value(d.get("value"))
		"ramp":
			return "_curve_ramp(%s, %s, %s, %s, %s)" % [
				_quote(str(d.get("over_timer", ""))),
				_lower_value(d.get("max")), _lower_value(d.get("from")),
				_lower_value(d.get("to")), _lower_value(d.get("power"))]
		"lerp":
			return "_curve_lerp(%s, %s, %s, %s)" % [
				_quote(str(d.get("over_timer", ""))),
				_lower_value(d.get("max")), _lower_value(d.get("from")),
				_lower_value(d.get("to"))]
	push_error("MovementCompiler: unknown curve '%s'" % kind)
	return "0.0"

# ---------------------------------------------------------------------------
# Effect lowering → straight-line statements / kernel calls.
# ---------------------------------------------------------------------------

func _emit_effects(effects: Array, indent: String) -> void:
	for e: Variant in effects:
		_emit_effect(e, indent)

func _emit_effect(e: Dictionary, indent: String) -> void:
	var op: String = str(e.get("do", ""))
	match op:
		"set_velocity_y":
			_line("%sbody.velocity.y = %s" % [indent, _lower_value(e.get("value"))])
		"set_velocity_y_max":
			_line("%sbody.velocity.y = maxf(body.velocity.y, %s)" % [indent, _lower_value(e.get("value"))])
		"set_timer":
			_line("%stimers[%s] = %s" % [indent, _quote(str(e.get("name", ""))), _lower_value(e.get("value"))])
		"add_timer":
			_emit_add_timer(e, indent)
		"add_velocity":
			_line("%s_k_add_velocity(frame, %s, %s, %s, %s, %s)" % [
				indent, _lower_value(e.get("vector")), _quote(str(e.get("space", "world"))),
				_quote(str(e.get("guard_not_in", ""))), str(bool(e.get("replace", false))).to_lower(),
				str(bool(e.get("include_y", false))).to_lower()])
		"accelerate_toward":
			_line("%s_k_accelerate_toward(frame, dt, %s, %s, %s)" % [
				indent, _quote(str(e.get("space", "wish"))),
				_lower_value(e.get("speed")), _lower_value(e.get("rate"))])
		"air_strafe":
			_line("%s_k_air_strafe(frame, dt, %s, %s, %s)" % [
				indent, _quote(str(e.get("space", "wish"))),
				_lower_value(e.get("cap")), _lower_value(e.get("rate"))])
		"apply_friction":
			_line("%s_k_apply_friction(frame, dt, %s, %s)" % [
				indent, _lower_value(e.get("rate")), str(bool(e.get("only_when_no_wish", false))).to_lower()])
		"apply_gravity":
			var min_vy := "INF" if not e.has("min_vy") else _lower_value(e.get("min_vy"))
			var has_min := str(e.has("min_vy")).to_lower()
			_line("%s_k_apply_gravity(dt, %s, %s, %s)" % [
				indent, _lower_value(e.get("scale")), has_min, min_vy])
		"carve":
			_line("%s_k_carve(frame, dt, %s)" % [indent, _lower_value(e.get("rate"))])
		"slope_accelerate":
			_line("%s_k_slope_accelerate(dt, %s, %s)" % [
				indent, _lower_value(e.get("rate")), _lower_value(e.get("ref_angle"))])
		"clamp_speed_h":
			_line("%s_k_clamp_speed_h(%s)" % [indent, _lower_value(e.get("max"))])
		"set_collider_height":
			_line("%sbody.host_set_collider_height(%s, %s)" % [
				indent, _lower_value(e.get("value")), str(bool(e.get("require_headroom", false))).to_lower()])
		"lerp_camera_height":
			_line("%sbody.host_lerp_camera_height(%s, %s, dt)" % [
				indent, _lower_value(e.get("target")), _lower_value(e.get("rate"))])
		"lerp_fov":
			_line("%sbody.host_lerp_fov(%s, %s, dt)" % [
				indent, _lower_value(e.get("target")), _lower_value(e.get("rate"))])
		"lerp_camera_roll":
			_line("%sbody.host_lerp_camera_roll(%s, %s, dt)" % [
				indent, _lower_value(e.get("target")), _lower_value(e.get("rate"))])
		"tween_position":
			_line("%s_k_tween_position(%s, %s)" % [
				indent, _quote(str(e.get("duration_timer", "vault"))), _lower_value(e.get("duration"))])
		"respawn":
			_line("%sbody.host_respawn()" % indent)
		"move_and_slide":
			_line("%sbody.move_and_slide()" % indent)
		_:
			push_error("MovementCompiler: unhandled effect op '%s'" % op)

func _emit_add_timer(e: Dictionary, indent: String) -> void:
	# Lower add_timer with its optional gate condition inline.
	var name := _quote(str(e.get("name", "")))
	var by := _lower_value(e.get("by"))
	var else_by := _lower_value(e.get("else_by", e.get("by")))
	var gate: Variant = e.get("when", null)
	var gate_expr := "true"
	if typeof(gate) == TYPE_DICTIONARY:
		gate_expr = _lower_condition(gate)
	_line("%sif %s:" % [indent, gate_expr])
	_line("%s\ttimers[%s] = float(timers.get(%s, 0.0)) + %s * dt" % [indent, name, name, by])
	_line("%selse:" % indent)
	_line("%s\ttimers[%s] = maxf(0.0, float(timers.get(%s, 0.0)) - %s * dt)" % [indent, name, name, else_by])

# ---------------------------------------------------------------------------
# Kernels — copied from MovementInterpreter so numerics are bit-identical.
# These are the irreducible arithmetic; the dispatch around them is what the
# compiler removes.
# ---------------------------------------------------------------------------

func _emit_kernels() -> void:
	var k := """
func _speed_h() -> float:
	return Vector3(body.velocity.x, 0.0, body.velocity.z).length()

func _slope_angle() -> float:
	if not body.is_on_floor():
		return 0.0
	var n := body.get_floor_normal()
	return rad_to_deg(acos(clampf(n.dot(Vector3.UP), -1.0, 1.0)))

func _wish_aligned(frame: InputFrame, cmp: String, value: float) -> bool:
	if frame.wish_dir.length_squared() < 0.001:
		return false
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if horiz.length_squared() < 0.000001:
		return false
	var dot := frame.wish_dir.dot(horiz.normalized())
	match cmp:
		"ge": return dot >= value
		"gt": return dot > value
		"le": return dot <= value
		"lt": return dot < value
		"eq": return is_equal_approx(dot, value)
	return false

func _resolve_space(space: String, frame: InputFrame) -> Vector3:
	match space:
		"wish":
			return frame.wish_dir
		"forward":
			return -body.transform.basis.z
		"aim":
			var aim := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
			return aim.normalized()
		"wall_tangent":
			if wall_normal.length_squared() < 0.001:
				return Vector3.ZERO
			var along := wall_normal.cross(Vector3.UP).normalized()
			if along.dot(-body.transform.basis.z) < 0.0:
				along = -along
			return along
		"wall_normal":
			return wall_normal
	push_error("compiled: unknown space '%s'" % space)
	return Vector3.ZERO

func _curve_ramp(over_timer: String, tmax: float, from: float, to: float, power: float) -> float:
	var t := float(timers.get(over_timer, 0.0))
	if tmax <= 0.0:
		tmax = 1.0
	var fraction := clampf(1.0 - t / tmax, 0.0, 1.0)
	if power <= 0.0:
		power = 1.0
	return from + (to - from) * pow(fraction, power)

func _curve_lerp(over_timer: String, tmax: float, from: float, to: float) -> float:
	var t2 := float(timers.get(over_timer, 0.0))
	if tmax <= 0.0:
		tmax = 1.0
	var f := clampf(1.0 - t2 / tmax, 0.0, 1.0)
	return lerpf(from, to, f)

func _probe_walls(side: String) -> bool:
	var sides: Array = []
	match side:
		"right": sides = [1.0]
		"left": sides = [-1.0]
		_: sides = [1.0, -1.0]
	for s: float in sides:
		var dist := float(kit.params.get("wall_detect_distance", 0.65))
		var hit: Dictionary = body.host_wall_ray(s, dist)
		if not hit.is_empty():
			var normal: Vector3 = hit["normal"]
			if absf(normal.y) < 0.3:
				wall_normal = normal
				wall_side = s
				return true
	return false

func _wall_still_near() -> bool:
	var dist := float(kit.params.get("wall_detect_distance", 0.65)) + 0.15
	var hit: Dictionary = body.host_wall_ray(wall_side, dist)
	if not hit.is_empty():
		var normal: Vector3 = hit["normal"]
		wall_normal = normal
		return absf(normal.y) < 0.3
	return false

func _k_add_velocity(frame: InputFrame, mag: float, space: String, guard_not_in: String, replace: bool, include_y: bool) -> void:
	if guard_not_in != "" and active_state == guard_not_in:
		return
	if space == "velocity":
		var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if horiz.length_squared() < 0.001:
			return
		var dir := horiz.normalized()
		body.velocity.x += dir.x * mag
		body.velocity.z += dir.z * mag
		return
	var v := _resolve_space(space, frame) * mag
	if replace:
		body.velocity.x = v.x
		body.velocity.z = v.z
		if include_y:
			body.velocity.y = v.y
	else:
		body.velocity.x += v.x
		body.velocity.z += v.z
		if include_y:
			body.velocity.y += v.y

func _k_accelerate_toward(frame: InputFrame, dt: float, space: String, top_speed: float, rate: float) -> void:
	if space == "wall_tangent":
		_k_accelerate_along_wall(frame, dt, top_speed, rate)
		return
	if frame.wish_dir.length_squared() < 0.001:
		return
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var target := _resolve_space(space, frame) * top_speed
	horiz = horiz.move_toward(target, rate * dt)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _k_accelerate_along_wall(frame: InputFrame, dt: float, run_speed: float, rate: float) -> void:
	var tangent := _resolve_space("wall_tangent", frame)
	if tangent.length_squared() < 0.001:
		return
	var fwd_input := 0.0
	if frame.is_pressed("move_forward"):
		fwd_input += 1.0
	if frame.is_pressed("move_backward"):
		fwd_input -= 1.0
	var current_along := Vector3(body.velocity.x, 0.0, body.velocity.z).dot(tangent)
	var target_along: float
	if fwd_input > 0.0:
		target_along = run_speed
	elif fwd_input < 0.0:
		target_along = 0.0
	else:
		target_along = current_along
	var new_along := move_toward(current_along, target_along, rate * dt)
	body.velocity.x = tangent.x * new_along
	body.velocity.z = tangent.z * new_along

func _k_air_strafe(frame: InputFrame, dt: float, space: String, cap: float, rate: float) -> void:
	if frame.wish_dir.length_squared() < 0.001:
		return
	var wish := _resolve_space(space, frame)
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var current_in_wish := horiz.dot(wish)
	var add_speed := minf(cap - current_in_wish, rate * dt)
	if add_speed > 0.0:
		horiz += wish * add_speed
		body.velocity.x = horiz.x
		body.velocity.z = horiz.z

func _k_apply_friction(frame: InputFrame, dt: float, rate: float, only_when_no_wish: bool) -> void:
	if only_when_no_wish and frame.wish_dir.length_squared() >= 0.001:
		return
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	horiz = horiz.move_toward(Vector3.ZERO, rate * dt)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _k_apply_gravity(dt: float, scale: float, has_min: bool, min_vy: float) -> void:
	body.velocity.y -= gravity * scale * dt
	if has_min:
		body.velocity.y = maxf(body.velocity.y, min_vy)

func _k_carve(frame: InputFrame, dt: float, rate: float) -> void:
	if frame.wish_dir.length_squared() < 0.001:
		return
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed_now := horiz.length()
	var steered := horiz + frame.wish_dir * rate * dt
	if steered.length() > 0.001:
		steered = steered.normalized() * speed_now
		body.velocity.x = steered.x
		body.velocity.z = steered.z

func _k_slope_accelerate(dt: float, rate: float, ref_angle: float) -> void:
	if not body.is_on_floor():
		return
	var floor_normal := body.get_floor_normal()
	var ang := rad_to_deg(acos(clampf(floor_normal.dot(Vector3.UP), -1.0, 1.0)))
	if ang <= 2.0:
		return
	if ref_angle <= 0.0:
		ref_angle = 45.0
	var down_slope := Vector3(floor_normal.x, 0.0, floor_normal.z).normalized()
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	horiz += down_slope * rate * (ang / ref_angle) * dt
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _k_clamp_speed_h(max_speed: float) -> void:
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z).limit_length(max_speed)
	body.velocity.x = horiz.x
	body.velocity.z = horiz.z

func _k_tween_position(timer_name: String, duration: float) -> void:
	var remaining := float(timers.get(timer_name, 0.0))
	body.host_tween_position(remaining, duration)
"""
	for ln in k.split("\n"):
		_line(ln)

# ---------------------------------------------------------------------------
# Emit helpers
# ---------------------------------------------------------------------------

func _quote(s: String) -> String:
	return "\"%s\"" % s.replace("\\", "\\\\").replace("\"", "\\\"")

func _fmt_float(v: float) -> String:
	# Deterministic, round-trippable float literal. Force a decimal point so the
	# generated source is unambiguously a float, matching the interpreter's
	# float(param) coercion.
	if v == floor(v) and absf(v) < 1e15:
		return "%.1f" % v
	return str(v)
