## THROWAWAY PROTOTYPE runner — drives the PLAIN transformation model through the
## worked cases and prints a readable per-tick trace. Expected-wrong learning
## artifact. NOT a test suite; it prints traces and quits.
##
## Run headless:
##   xvfb-run -a godot4 --path . res://prototypes/tf-substrate/tf_proto.tscn --quit-after 2000
##
## THE PLAIN MODEL (see tf_substrate.gd):
##   - A part is a plain struct (named fields + children + parent). Just data.
##   - A transformation is a plain function that reads the tree and writes new
##     field values into parts. Here each transformation is a Callable that
##     captures the part(s) it acts on; the tick loop calls them in order.
##   - Each tick runs every active transformation in a fixed deterministic order,
##     mutating fields in place. Determinism = the order.
##   - A transition's progress is accumulated plain-field state it steps forward,
##     not a value read off a clock. Pause = the function declining to advance.
extends Node

const PartT := preload("res://prototypes/tf-substrate/tf_substrate.gd")


func _ready() -> void:
	print("\n############ TF SUBSTRATE — PLAIN STRUCT+FUNCTION PROTOTYPE ############")
	_case1_gradual()
	_case2_parallel()
	_case3_pause()
	_case4_pause_most_recent()
	print("\n############ END PROTOTYPE ############\n")
	get_tree().quit(0)


## Run an ordered list of transformations for `ticks` ticks. Each tick calls
## every transformation once, in list order, mutating fields in place. This is
## the whole execution model.
func _run(transformations: Array, ticks: int, trace_line: Callable) -> void:
	for t in ticks:
		trace_line.call(t)                 # observe BEFORE this tick advances
		for xf in transformations:
			xf.call()


# --------------------------------------------------------------------------
# CASE 1 — Gradual transformation: one field advancing over N ticks. The
# transformation reads the CURRENT field value and writes current+delta.
# --------------------------------------------------------------------------
func _case1_gradual() -> void:
	print("\n===== CASE 1: gradual (one field advancing over N ticks) =====")
	var tail := PartT.new()
	tail.fields["p"] = 0.0

	# A plain function: read current p, write next p. Progress is the field
	# itself; there is no clock involved.
	var advance := func() -> void:
		tail.fields["p"] = min(1.0, tail.fields["p"] + 0.2)

	_run([advance], 7, func(t):
		print("  tick %d:  p = %.2f" % [t, tail.fields["p"]]))


# --------------------------------------------------------------------------
# CASE 2 — Two transitions running in PARALLEL on the SAME part, out of step.
# Each has its OWN accumulated progress field and advances at its OWN rate,
# fully independently. Two separate transformation functions over one part.
# --------------------------------------------------------------------------
func _case2_parallel() -> void:
	print("\n===== CASE 2: two parallel transitions on one part, out of step =====")
	var part := PartT.new()
	part.fields["progA"] = 0.00   # transition A's accumulated progress
	part.fields["progB"] = 0.60   # transition B starts partway through
	# Two independent transformations, each stepping its own field by its own rate.
	var advA := func() -> void:
		part.fields["progA"] = min(1.0, part.fields["progA"] + 0.10)
	var advB := func() -> void:
		part.fields["progB"] = min(1.0, part.fields["progB"] + 0.25)

	_run([advA, advB], 6, func(t):
		print("  tick %d:  A.prog=%.2f  B.prog=%.2f" % [
			t, part.fields["progA"], part.fields["progB"]]))


# --------------------------------------------------------------------------
# CASE 3 — Pause. A transition reads a plain field as its pause condition and
# HOLDS (leaves its progress unchanged) while that field is set. Another action
# sets the field partway through, then clears it, and the transition resumes.
# Pause is "the function declines to advance" — NOT a substrate feature.
# --------------------------------------------------------------------------
func _case3_pause() -> void:
	print("\n===== CASE 3: pause (the transformation declines to advance) =====")
	var part := PartT.new()
	part.fields["p"] = 0.0
	part.fields["held"] = false   # plain field; some other action sets/clears it

	var advance := func() -> void:
		if part.fields["held"]:
			return                 # decline to advance — progress unchanged
		part.fields["p"] = min(1.0, part.fields["p"] + 0.25)

	# A separate "action" transformation drives the pause field: hold on ticks
	# 2..4, released otherwise. It only writes a plain field, like anything else.
	var hold_action := func(tick: int) -> void:
		part.fields["held"] = (tick >= 2 and tick <= 4)

	for t in 8:
		hold_action.call(t)        # the action runs first this tick
		print("  tick %d:  held=%s  p=%.2f" % [t, str(part.fields["held"]), part.fields["p"]])
		advance.call()


# --------------------------------------------------------------------------
# CASE 4 — Pause-the-MOST-RECENT of two parallel transitions. Each transition
# carries a plain author-stamped start marker (`start`). The pause signal targets
# whichever transition has the LATEST start marker. The start marker comes from a
# simple author-maintained counter in plain data.
#
# KNOWN-OPEN: where a legitimate monotonic start-stamp comes from is unresolved.
# This uses a hand-maintained counter; it does NOT invent a substrate clock and
# does NOT read any log/tick order. See the friction log.
# --------------------------------------------------------------------------
func _case4_pause_most_recent() -> void:
	print("\n===== CASE 4: pause-the-most-recent (latest start-marker holds) =====")
	var part := PartT.new()
	var author_counter := 0        # plain author-maintained monotonic stamp source

	# Transition A starts first (smaller stamp).
	part.fields["progA"] = 0.0
	part.fields["startA"] = author_counter
	author_counter += 1
	# Transition B starts later (larger stamp) => B is "most recent".
	part.fields["progB"] = 0.0
	part.fields["startB"] = author_counter
	author_counter += 1

	part.fields["held"] = false    # pause signal, set by the action below

	var advA := func() -> void:
		# A holds only if the pause signal is on AND A is the most-recent one.
		if part.fields["held"] and part.fields["startA"] > part.fields["startB"]:
			return
		part.fields["progA"] = min(1.0, part.fields["progA"] + 0.10)
	var advB := func() -> void:
		if part.fields["held"] and part.fields["startB"] > part.fields["startA"]:
			return
		part.fields["progB"] = min(1.0, part.fields["progB"] + 0.10)

	# Action: assert the pause signal on ticks 2..4. It targets the most-recent
	# transition purely by the start-marker comparison inside advA/advB.
	var pause_action := func(tick: int) -> void:
		part.fields["held"] = (tick >= 2 and tick <= 4)

	for t in 7:
		pause_action.call(t)
		var recent := "B" if part.fields["startB"] > part.fields["startA"] else "A"
		print("  tick %d:  held=%s (targets most-recent=%s)  A.prog=%.2f  B.prog=%.2f" % [
			t, str(part.fields["held"]), recent, part.fields["progA"], part.fields["progB"]])
		advA.call()
		advB.call()
