## The AUTHORED TRANSFORMATION LIBRARY — transformations as marinada DATA.
##
## A transformation is no longer engine code (the old kind->Callable dispatch). It
## is a marinada expression authored as data and looked up by NAME through the
## module system. `tr["kind"]` names a transformation-definition exported by an
## authored marinada module; the engine resolves the module once and calls the
## resulting closure per transition. This content-reference to a shared authored
## definition is the blessed "reference to a shared something" — it is NOT a
## runtime-id/registry for simulation ENTITIES (the tree stays id-free).
##
## Every definition is a lambda over the fixed argument tuple the engine supplies:
##
##     (part, root, tr, seed, coord, idx, ntrans)
##
##   part   — opaque handle to the part this transition rides on
##   root   — opaque handle to the body root (for relational cross-part reads)
##   tr     — the transition record (a marinada record / plain dict)
##   seed   — the run seed (for seeded draws)
##   coord  — a deterministic base coordinate = mix2(part-index, transition-index)
##   idx    — this transition's index within the part's list (recency = idx)
##   ntrans — number of transitions on the part (so "most recent" = idx == ntrans-1)
##
## A definition RETURNS a result record — marinada stays pure, the engine owns
## mutation and order:
##
##     { "transition": <new transition record>, "fields": <record part-field -> new value> }
##
## The engine replaces the transition list entry with `transition` and writes each
## `fields` entry into the part in place, in the tick's deterministic total order.
##
## Two modules exercise the import system for real: `lib:tf-util` exports small
## helpers; `lib:tf-core` imports them and defines the transformations.
class_name TFLibrary
extends RefCounted


## `lib:tf-util` — shared helpers. `field-eq` builds a marinada predicate closure
## (identity-by-field), demonstrating a higher-order authored helper.
static func util_module() -> Dictionary:
	return {
		"exports": ["lerp", "field-eq"],
		"defs": {
			# Linear interpolate a..b by t.
			"lerp": ["fn", ["a", "b", "t"],
				["+", ["var", "a"], ["*", ["-", ["var", "b"], ["var", "a"]], ["var", "t"]]]],
			# A predicate closure: part -> (part.field[k] == v).
			"field-eq": ["fn", ["k", "v"],
				["fn", ["p"], ["==", ["part-field", ["var", "p"], ["var", "k"]], ["var", "v"]]]],
		},
	}


## `lib:tf-core` — the transformation definitions, importing lib:tf-util.
static func core_module() -> Dictionary:
	# Advance progress by rate (clamped to 1) and interpolate the named field.
	var advance := ["fn", ["tr"],
		["let", [["p2", ["min", 1.0, ["+", ["get", ["var", "tr"], "prog"], ["get", ["var", "tr"], "rate"]]]]],
			["record",
				"transition", ["record-set", ["var", "tr"], "prog", ["var", "p2"]],
				"fields", ["record",
					["get", ["var", "tr"], "field"],
					["call", ["var", "lerp"], ["get", ["var", "tr"], "from"], ["get", ["var", "tr"], "to"], ["var", "p2"]]]]]]

	# A frozen result: transition unchanged, no field writes.
	var frozen := ["record", "transition", ["var", "tr"], "fields", ["record"]]

	return {
		"imports": [{"from": "lib:tf-util", "import": ["lerp", "field-eq"]}],
		"defs": {
			"advance": advance,

			# CASE 1 & 2 — gradual / parallel accrual.
			"accrue": ["fn", ["part", "root", "tr", "seed", "coord", "idx", "ntrans"],
				["call", ["var", "advance"], ["var", "tr"]]],

			# CASE 3 — pausable: decline to advance while the part's `held` field holds.
			"accrue_pausable": ["fn", ["part", "root", "tr", "seed", "coord", "idx", "ntrans"],
				["if", ["part-field", ["var", "part"], "held", false],
					frozen,
					["call", ["var", "advance"], ["var", "tr"]]]],

			# CASE 4 — pause ONLY when most recent (recency = list position: idx==ntrans-1).
			# Advances prog only (no field write); freezes when held AND most recent.
			"accrue_recent": ["fn", ["part", "root", "tr", "seed", "coord", "idx", "ntrans"],
				["if", ["and", ["part-field", ["var", "part"], "held", false], ["==", ["var", "idx"], ["-", ["var", "ntrans"], 1]]],
					frozen,
					["record",
						"transition", ["record-set", ["var", "tr"], "prog",
							["min", 1.0, ["+", ["get", ["var", "tr"], "prog"], ["get", ["var", "tr"], "rate"]]]],
						"fields", ["record"]]]],

			# CASE 5 — cross-part by field: read a breast's size (kind-match) and write thickness.
			"track_breast": ["fn", ["part", "root", "tr", "seed", "coord", "idx", "ntrans"],
				["let", [["b", ["find-first", ["var", "root"], ["call", ["var", "field-eq"], "kind", "breast"]]]],
					["record",
						"transition", ["var", "tr"],
						"fields", ["if", ["==", ["var", "b"], null],
							["record"],
							["record",
								["get", ["var", "tr"], "field"],
								["*", ["part-field", ["var", "b"], "size", 0.0], ["get", ["var", "tr"], "factor"]]]]]]],

			# CASE 7 — probabilistic: with probability p, bump a counter. Draw keyed off
			# (seed, mix2(coord, draw-counter)); the counter persists in the transition so
			# successive ticks draw fresh, replay-exactly.
			"maybe_grow": ["fn", ["part", "root", "tr", "seed", "coord", "idx", "ntrans"],
				["let", [
						["d", ["get", ["var", "tr"], "_draws"]],
						["c2", ["mix2", ["var", "coord"], ["var", "d"]]],
						["hit", ["chance", ["var", "seed"], ["var", "c2"], ["get", ["var", "tr"], "p"]]]],
					["record",
						"transition", ["record-set",
							["record-set", ["var", "tr"], "_draws", ["+", ["var", "d"], 1]],
							"count",
							["if", ["var", "hit"], ["+", ["get", ["var", "tr"], "count"], 1], ["get", ["var", "tr"], "count"]]],
						"fields", ["record"]]]],

			# CASE 8 — STRUCTURAL MUTATION: grow a tail. This rides on a TORSO and,
			# once, GRAFTS a tail child through the engine's `structural` return
			# channel — the discrete-TOPOLOGY half of the discrete×continuous split.
			# The grafted tail carries a plain "size" field at 0.0 PLUS its own
			# `accrue` magnitude transition (the continuous half), so the tail
			# "grows in" 0→target over subsequent ticks rather than popping full.
			# Idempotent by structure: if a tail already hangs below the torso it
			# freezes (no further graft), so replaying more ticks adds no duplicate.
			# SEED is load-bearing: the tail's target `to` is a SEEDED DRAW off
			# (seed, coord) — different seeds grow the tail to a different size.
			# §D [OPEN] note: that draw uses coord = mix2(part-index, ti); grafting
			# elsewhere in the body would shift this torso's part-index and reshuffle
			# the draw. Replay stays exact (positions reproduce); stream-stability
			# under rearrange is the unresolved §D thread, deliberately not fixed.
			"grow_tail": ["fn", ["part", "root", "tr", "seed", "coord", "idx", "ntrans"],
				["let", [["existing",
						["find-first", ["var", "part"],
							["fn", ["p"], ["==", ["part-field", ["var", "p"], "kind"], "tail"]]]]],
					["if", ["!=", ["var", "existing"], null],
						frozen,
						["record",
							"transition", ["var", "tr"],
							"fields", ["record"],
							"structural", ["array",
								["record",
									"op", "graft",
									"node", ["record",
										"fields", ["record",
											"kind", "tail",
											"size", 0.0,
											"transitions", ["array",
												["record",
													# "accrue" is a bare string — STRING LITERAL under the
													# correct semantics (bare != var lookup). No __lit needed.
													"kind", "accrue",
													"field", "size",
													"from", 0.0,
													"to", ["+", 6.0, ["*", 6.0, ["draw-unit", ["var", "seed"], ["var", "coord"]]]],
													"rate", 0.15,
													"prog", 0.0]]]]]]]]]],
		},
	}


## Host module resolver: maps a scheme+path to a module dict. Only `lib:` is used
## here; delegated exactly as marinada specifies (host owns resolution strategy).
static func resolve(scheme: String, path: String) -> Dictionary:
	if scheme == "lib":
		match path:
			"tf-util": return util_module()
			"tf-core": return core_module()
	push_error("TFLibrary.resolve: no module %s:%s" % [scheme, path])
	return {}


## Resolve a marinada module's imports and definitions into an Env whose frame binds
## every imported name and every own def. Own defs are two-passed (pre-bound then
## evaluated) so they may mutually reference each other and the imports (letrec at
## module scope).
static func resolve_module(module: Dictionary, resolver: Callable) -> TFMarinada.Env:
	var env := TFMarinada.Env.new()
	for imp in module.get("imports", []):
		var from: String = imp["from"]
		var sep := from.find(":")
		var scheme := from.substr(0, sep)
		var path := from.substr(sep + 1)
		var mod: Dictionary = resolver.call(scheme, path)
		var mod_env := resolve_module(mod, resolver)
		# Keep the imported module's frame alive for this frame's lifetime (its
		# exported closures capture it weakly once sealed below). Held off to the
		# side of `vars`, so no cycle back to this frame.
		env.keepalive.append(mod_env)
		for name in imp.get("import", []):
			env.define(name, mod_env.lookup(name))
	var defs: Dictionary = module.get("defs", {})
	for name in defs:
		env.define(name, null)
	for name in defs:
		env.vars[name] = TFMarinada.eval(defs[name], env)
	# Module defs are closures bound into the very frame they capture (letrec at
	# module scope) — a refcount self-cycle that would leak the frame at exit. Seal
	# it: each such closure holds this frame WEAKLY. The frame is then kept alive by
	# its external owner (build() anchors the top module env; nested import frames
	# are held by the importer's `keepalive` above), so lookups still resolve and
	# the frame collects once that owner drops. Lifetime only — no eval change.
	TFMarinada._seal_recursive(env)
	return env


## Build the transformation library the engine consumes: a plain Dictionary
## kind -> closure, resolved from the authored `lib:tf-core` module. The engine
## treats this exactly like the old dispatch table, but every entry is now an
## authored marinada definition rather than GDScript.
static func build() -> Dictionary:
	var resolver := func(s: String, p: String) -> Dictionary: return TFLibrary.resolve(s, p)
	var env := resolve_module(core_module(), resolver)
	var out: Dictionary = {}
	for name in core_module()["defs"]:
		out[name] = env.lookup(name)
	# The module def closures capture `env` weakly (sealed in resolve_module), so the
	# returned lib must keep the module frame alive for its own lifetime. Anchor it
	# under a reserved non-kind key: the engine only ever indexes the lib by a
	# transition `kind`, never iterates it, so this entry is inert to consumers.
	out["__module_env"] = env
	return out
