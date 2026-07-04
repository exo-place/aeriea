## A GDScript evaluator of marinada's PURE CORE SUBSET (see docs authority:
## /home/me/git/rhizone/dusklight/docs/marinada.md). Marinada expressions are the
## JSON-array s-expression form: an Atom is a JSON primitive; a Call is
## `[op, arg1, ...]` where `op` is a string. A bare string in ARG position is a
## VARIABLE REFERENCE if it is bound in the current environment, otherwise a STRING
## LITERAL (the pragmatic Lisp reading that reconciles the spec's "bare string is a
## string literal" with its fn/let/match bodies that reference bound names as bare
## strings — `["+", "x", "y"]` in a fn body means the params, `["get", r, "key"]`
## means the literal "key"). Op names in HEAD position are never variables.
##
## This is a TREE-WALKING INTERPRETER of the pure value/expression subset a
## transformation needs. It is intentionally NOT the whole language — no reactive
## signals, no algebraic effects (perform/handle), no capabilities/call.method, no
## linear/affine types, no gradual type checker, no optimizer/JIT/TCO. See the
## substrate README for the implemented-vs-skipped op ledger.
##
## AERIEA ADDITIONS marinada lacks: a seeded deterministic-draw family (mix2 /
## draw-int / draw-unit / chance, wrapping TFRng) and a tree-navigation family
## (part-field / find-first / nearest-ancestor / ... wrapping TFTree). Parts flow
## through the evaluator as OPAQUE host values (TFPart objects) — the tree is NOT
## reified into marinada records; navigation is done by host ops taking marinada
## lambda predicates. This preserves the topology-independent by-field/relational
## reference model. A `record` constructor is also added (the spec lists record-set
## / record-merge but no literal record constructor; the substrate needs one to
## build its result record).
class_name TFMarinada
extends RefCounted


## Lexical environment: a frame of name->value plus a parent link. Closures capture
## an Env; let/letrec/fn/match introduce child frames.
class Env extends RefCounted:
	var vars: Dictionary = {}
	var parent = null  # Env or null

	func _init(p = null) -> void:
		parent = p

	## The nearest frame that binds `name`, or null.
	func find(name: String):
		var e = self
		while e != null:
			if e.vars.has(name):
				return e
			e = e.parent
		return null

	func lookup(name: String) -> Variant:
		var e = find(name)
		return e.vars[name] if e != null else null

	func has(name: String) -> bool:
		return find(name) != null

	func define(name: String, val: Variant) -> void:
		vars[name] = val

	func child() -> Env:
		return Env.new(self)


# ---------------------------------------------------------------------------
# Public entry points.
# ---------------------------------------------------------------------------

## Evaluate an expression in a fresh empty environment.
static func eval_top(expr: Variant) -> Variant:
	return eval(expr, Env.new())


## Evaluate an expression with a set of pre-bound names (a plain dict name->value).
## Handy for host-driven evaluation (bind `part`, `root`, `tr`, `seed`, ...).
static func eval_with(expr: Variant, bindings: Dictionary) -> Variant:
	var env := Env.new()
	for k in bindings:
		env.define(k, bindings[k])
	return eval(expr, env)


## Apply a closure value (produced by `fn`) to a list of already-evaluated args.
## Exposed so the engine can invoke a transformation-definition closure and so host
## ops can invoke marinada lambda predicates.
static func apply(fn: Variant, args: Array) -> Variant:
	if not (fn is Dictionary and fn.get("__fn", false)):
		push_error("TFMarinada.apply: not a function: %s" % str(fn))
		return null
	var fenv: Env = (fn["env"] as Env).child()
	var params: Array = fn["params"]
	for i in range(params.size()):
		var pn: Variant = params[i]
		if pn is Array:   # typed param [name, type] — type ignored (no checker)
			pn = pn[0]
		fenv.define(pn, args[i] if i < args.size() else null)
	return eval(fn["body"], fenv)


# ---------------------------------------------------------------------------
# Core evaluator.
# ---------------------------------------------------------------------------

static func eval(expr: Variant, env: Env) -> Variant:
	if expr is Array:
		return _eval_list(expr, env)
	if expr is String:
		var e = env.find(expr)
		if e != null:
			return e.vars[expr]
		return expr                       # unbound string => string literal
	return expr                           # atom / opaque host value


static func _eval_list(arr: Array, env: Env) -> Variant:
	if arr.is_empty():
		push_error("TFMarinada: empty expression")
		return null
	var op: Variant = arr[0]
	if not (op is String):
		push_error("TFMarinada: op must be a string, got %s" % str(op))
		return null

	# A capitalized head is a discriminated-union CONSTRUCTOR (Circle, Some, Ok, ...).
	# DU value = {"__du": tag, "fields": [evaluated args]}.
	if _is_ctor(op):
		var fields: Array = []
		for i in range(1, arr.size()):
			fields.append(eval(arr[i], env))
		return {"__du": op, "fields": fields}

	# Special forms that must NOT eagerly evaluate all arguments.
	match op:
		"if":
			return eval(arr[2], env) if _truthy(eval(arr[1], env)) else eval(arr[3], env)
		"cond":
			for i in range(1, arr.size()):
				var clause: Array = arr[i]
				if clause[0] == "else":
					return eval(clause[1], env)
				if _truthy(eval(clause[0], env)):
					return eval(clause[1], env)
			return null
		"and":
			return _truthy(eval(arr[1], env)) and _truthy(eval(arr[2], env))
		"or":
			return _truthy(eval(arr[1], env)) or _truthy(eval(arr[2], env))
		"not":
			return not _truthy(eval(arr[1], env))
		"do":
			var r: Variant = null
			for i in range(1, arr.size()):
				r = eval(arr[i], env)
			return r
		"let":
			var ce := env.child()          # sequential (let*) — later bindings see earlier
			for b in arr[1]:
				ce.define(b[0], eval(b[1], ce))
			return eval(arr[2], ce)
		"letrec":
			var ce2 := env.child()
			for b in arr[1]:
				ce2.define(b[0], null)     # pre-bind for mutual recursion
			for b in arr[1]:
				ce2.vars[b[0]] = eval(b[1], ce2)
			return eval(arr[2], ce2)
		"fn":
			return {"__fn": true, "params": arr[1], "body": arr[2], "env": env}
		"call":
			var f: Variant = eval(arr[1], env)
			var cargs: Array = []
			for i in range(2, arr.size()):
				cargs.append(eval(arr[i], env))
			return apply(f, cargs)
		"match":
			return _eval_match(arr, env)
		"untyped", "as":
			# Type escape hatch / runtime assert — no checker here, so identity.
			return eval(arr[arr.size() - 1], env)

	# Everything else is a strict primitive: evaluate args left-to-right, then apply.
	var a: Array = []
	for i in range(1, arr.size()):
		a.append(eval(arr[i], env))
	return _prim(op, a)


static func _eval_match(arr: Array, env: Env) -> Variant:
	var subject: Variant = eval(arr[1], env)
	for i in range(2, arr.size()):
		var clause: Array = arr[i]
		var pat: Array = clause[0]
		var tag: Variant = pat[0]
		if subject is Dictionary and subject.get("__du") == tag:
			var ce := env.child()
			var vals: Array = subject["fields"]
			for j in range(1, pat.size()):
				ce.define(pat[j], vals[j - 1])
			return eval(clause[1], ce)
	push_error("TFMarinada: non-exhaustive match, no clause for %s" % str(subject))
	return null


# ---------------------------------------------------------------------------
# Strict primitive operations.
# ---------------------------------------------------------------------------

static func _prim(op: String, a: Array) -> Variant:
	match op:
		# Arithmetic
		"+": return a[0] + a[1]
		"-": return a[0] - a[1]
		"*": return a[0] * a[1]
		"/": return a[0] / a[1]
		"%": return (fmod(a[0], a[1]) if (a[0] is float or a[1] is float) else a[0] % a[1])
		# Comparison
		"==": return _eq(a[0], a[1])
		"!=": return not _eq(a[0], a[1])
		"<": return a[0] < a[1]
		">": return a[0] > a[1]
		"<=": return a[0] <= a[1]
		">=": return a[0] >= a[1]
		# Math
		"min": return min(a[0], a[1])
		"max": return max(a[0], a[1])
		"abs": return abs(a[0])
		"floor": return floor(a[0])
		"ceil": return ceil(a[0])
		"round": return round(a[0])
		"sqrt": return sqrt(a[0])
		"pow": return pow(a[0], a[1])
		"int->float": return float(a[0])
		"float->int": return int(a[0])
		# Record / data access
		"get", "record-get": return _coll_get(a[0], a[1])
		"get-in":
			var cur: Variant = a[0]
			for k in a[1]:
				cur = _coll_get(cur, k)
			return cur
		"set", "record-set": return _rset(a[0], a[1], a[2])
		"set-in": return _set_in(a[0], a[1], a[2])
		"record": return _record(a)
		"record-del":
			var d: Dictionary = (a[0] as Dictionary).duplicate(true)
			d.erase(a[1])
			return d
		"record-keys": return (a[0] as Dictionary).keys()
		"record-vals": return (a[0] as Dictionary).values()
		"record-merge":
			var m: Dictionary = (a[0] as Dictionary).duplicate(true)
			for k in a[1]:
				m[k] = a[1][k]
			return m
		# Arrays
		"array": return a.duplicate()
		"count": return a[0].size()
		"array-get": return a[0][a[1]]
		"array-push":
			var out: Array = (a[0] as Array).duplicate()
			out.append(a[1])
			return out
		"array-slice": return (a[0] as Array).slice(a[1], a[2])
		# Strings
		"to-string": return str(a[0])
		"str-concat": return str(a[0]) + str(a[1])
		# --- AERIEA: seeded deterministic draws (wrap TFRng) ---
		"mix2": return TFRng.mix2(a[0], a[1])
		"draw-int": return TFRng.draw_int(a[0], a[1])
		"draw-unit": return TFRng.draw_unit(a[0], a[1])
		"chance": return TFRng.chance(a[0], a[1], a[2])
		# --- AERIEA: tree navigation (wrap TFTree); parts are opaque TFPart values ---
		"part-field": return _part_field(a)
		"part-parent": return (a[0] as TFPart).parent() if a[0] != null else null
		"part-children": return (a[0] as TFPart).children if a[0] != null else []
		"find-first": return TFTree.find_first(a[0], _pred(a[1]))
		"find-all": return TFTree.find_all(a[0], _pred(a[1]))
		"nearest-ancestor": return TFTree.nearest_ancestor(a[0], _pred(a[1]))
		"nearest-ancestor-excluding": return TFTree.nearest_ancestor_excluding(a[0], _pred(a[1]), a[2])
		"topmost-in-chain": return TFTree.topmost_in_chain(a[0], _pred(a[1]))
		"has-ancestor": return TFTree.has_ancestor(a[0], _pred(a[1]))
		_:
			push_error("TFMarinada: unknown op '%s'" % op)
			return null


# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------

static func _is_ctor(op: String) -> bool:
	if op.is_empty():
		return false
	var c := op.substr(0, 1)
	return c != c.to_lower() and c == c.to_upper()


static func _truthy(v: Variant) -> bool:
	return v == true


static func _eq(x: Variant, y: Variant) -> bool:
	# Godot compares Array/Dictionary by content and Objects by identity — exactly
	# the semantics we want (records structural, opaque parts by identity).
	return x == y


static func _coll_get(coll: Variant, key: Variant) -> Variant:
	if coll is Dictionary:
		return coll.get(key)
	if coll is Array:
		return coll[key]
	return null


static func _record(a: Array) -> Dictionary:
	var d: Dictionary = {}
	var i := 0
	while i + 1 < a.size():
		d[a[i]] = a[i + 1]
		i += 2
	return d


static func _rset(rec: Variant, key: Variant, val: Variant) -> Dictionary:
	var d: Dictionary = (rec as Dictionary).duplicate(true) if rec is Dictionary else {}
	d[key] = val
	return d


static func _set_in(rec: Variant, path: Array, val: Variant) -> Variant:
	if path.is_empty():
		return val
	var d: Dictionary = (rec as Dictionary).duplicate(true) if rec is Dictionary else {}
	var key: Variant = path[0]
	d[key] = _set_in(_coll_get(rec, key), path.slice(1), val)
	return d


static func _part_field(a: Array) -> Variant:
	var part: TFPart = a[0]
	var has_default := a.size() > 2
	if part == null:
		return a[2] if has_default else null
	var key: Variant = a[1]
	if part.fields.has(key):
		return part.fields[key]
	return a[2] if has_default else null


## Wrap a marinada lambda-predicate value into a GDScript Callable so it can drive
## the TFTree helpers unchanged. The predicate receives one opaque part, returns bool.
static func _pred(closure: Variant) -> Callable:
	return func(p: TFPart) -> bool:
		return _truthy(TFMarinada.apply(closure, [p]))
