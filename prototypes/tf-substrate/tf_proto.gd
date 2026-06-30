## THROWAWAY PROTOTYPE runner — drives the TF kernel through the four worked
## cases and prints a readable per-tick trace. Expected-wrong learning artifact.
## NOT a test suite; it just prints traces and quits.
##
## Run headless:
##   xvfb-run -a godot4 --path . res://prototypes/tf-substrate/tf_proto.tscn --quit-after 2000
extends Node

const TFKernel := preload("res://prototypes/tf-substrate/tf_substrate.gd")


func _ready() -> void:
	print("\n############ TF SUBSTRATE — THROWAWAY PROTOTYPE ############")
	_case1_gradual()
	_case2_two_runs()
	_case3_pause()
	_case4_stochastic()
	print("\n############ END PROTOTYPE ############\n")
	get_tree().quit(0)


# --------------------------------------------------------------------------
# CASE 1 — Gradual transformation: one property progressing over N ticks.
# --------------------------------------------------------------------------
func _case1_gradual() -> void:
	print("\n===== CASE 1: gradual (one property over N ticks) =====")
	var eng := TFKernel.new(1)
	var tail := TFKernel.Part.new()
	# `p` is an expression bound to (tail, "p"): add 0.2/tick, cap at 1.0.
	tail.meta["p"] = eng.expr(func(ctx):
		return min(1.0, ctx.current + 0.2), 0.0)

	for t in 7:
		print("  tick %d:  p = %.2f" % [t, TFKernel.mget(tail, "p")])
		eng.tick(tail)


# --------------------------------------------------------------------------
# CASE 2 — Two out-of-step runs on ONE target, with NO "run" noun: the two
# progressions are TWO ELEMENTS of ONE collection-valued metadata entry,
# advanced by ONE expression that maps its logic over each element.
# --------------------------------------------------------------------------
func _case2_two_runs() -> void:
	print("\n===== CASE 2: two out-of-step runs (one collection, one expression) =====")
	var eng := TFKernel.new(1)
	var body := TFKernel.Part.new()
	# ONE metadata entry, a LIST of two records. ONE expression maps over the
	# list, advancing each record's `p` by its own `rate`. The two "runs" are
	# just two elements; they share the advance rule but carry different state.
	body.meta["morph"] = eng.expr(func(ctx):
		var out: Array = []
		for rec in ctx.current:
			out.append({"p": min(1.0, rec.p + rec.rate), "rate": rec.rate})
		return out,
		[{"p": 0.0, "rate": 0.10}, {"p": 0.60, "rate": 0.25}])

	for t in 6:
		var m = TFKernel.mget(body, "morph")
		print("  tick %d:  runA.p=%.2f  runB.p=%.2f" % [t, m[0].p, m[1].p])
		eng.tick(body)


# --------------------------------------------------------------------------
# CASE 3 — Pause: an expression early-returns its current value unchanged while
# a predicate holds, then resumes. Pause is NOT a mechanism — just an early
# return inside the ordinary advance expression.
# --------------------------------------------------------------------------
func _case3_pause() -> void:
	print("\n===== CASE 3: pause (authored early-return) =====")
	var eng := TFKernel.new(1)
	var part := TFKernel.Part.new()
	part.meta["paused"] = false  # plain opaque metadata, flipped by the author
	part.meta["p"] = eng.expr(func(ctx):
		if ctx.mget.call(ctx.host, "paused"):
			return ctx.current  # early-return: no progress while paused
		return min(1.0, ctx.current + 0.25), 0.0)

	for t in 8:
		# Author flips the pause predicate between ticks 2 and 5 (inclusive).
		part.meta["paused"] = (t >= 2 and t <= 4)
		print("  tick %d:  paused=%s  p=%.2f" % [t, str(part.meta["paused"]), TFKernel.mget(part, "p")])
		eng.tick(part)


# --------------------------------------------------------------------------
# CASE 4 — Stochastic: a seeded-draw transformation. Run TWICE with the SAME
# seed; the traces must be identical. The draw is keyed off (seed + a
# deterministic coordinate); here the coordinate is an author-maintained
# monotonic `tries` counter (always advances, so draws never repeat).
# --------------------------------------------------------------------------
func _case4_stochastic() -> void:
	print("\n===== CASE 4: stochastic (seeded draw, same seed => identical) =====")
	var traceA := _run_stochastic(42)
	var traceB := _run_stochastic(42)
	print("  run 1 (seed 42): ", traceA)
	print("  run 2 (seed 42): ", traceB)
	print("  identical: ", traceA == traceB)
	# A different seed should generally differ — shown for contrast.
	var traceC := _run_stochastic(7)
	print("  run 3 (seed  7): ", traceC, "   (differs from seed 42: %s)" % str(traceC != traceA))


func _run_stochastic(s: int) -> Array:
	var eng := TFKernel.new(s)
	var part := TFKernel.Part.new()
	# Record carries its own monotonic coordinate (`tries`) and accumulated
	# `hits`. Each tick: tries+1 always; a hit (prob 0.4) advances `hits`.
	part.meta["morph"] = eng.expr(func(ctx):
		var rec = ctx.current
		var hit: bool = ctx.draw.call(rec.tries) < 0.4
		return {"tries": rec.tries + 1, "hits": rec.hits + (1 if hit else 0)},
		{"tries": 0, "hits": 0})

	var trace: Array = []
	for t in 8:
		trace.append(int(TFKernel.mget(part, "morph").hits))
		eng.tick(part)
	return trace
