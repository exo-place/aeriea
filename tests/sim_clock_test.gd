## SimClock test — aeriea's deterministic clock (ported from BDCC2 TimeManager,
## the frame-delta accrual cut to timeline-driven advance()).
##
## Asserts:
##   (a) ACCRUAL — advance() accumulates seconds-of-day; full_time tracks total.
##   (b) ROLLOVER — crossing midnight increments day and fires day_rolled_over
##       once per boundary (incl. multi-day jumps in a single advance).
##   (c) DETERMINISM — replaying the SAME advance() sequence reproduces day/
##       time_of_day/full_time exactly (the determinism cut: no frame delta).
##   (d) HELPERS — day_at / seconds_since_day_start / advance_full_time arithmetic.
##   (e) NO WALL-CLOCK — stepping process frames does NOT move the clock (only
##       advance() does); time is timeline-driven, not _physics_process-driven.
##
## Run: xvfb-run -a godot4 --path . res://tests/sim_clock_test.tscn --quit-after 2000
extends Node

const SimClock := preload("res://scripts/sim/sim_clock.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea sim-clock test ===\n")
	_test_accrual()
	_test_rollover()
	_test_multi_day_jump()
	_test_determinism()
	_test_helpers()
	_test_no_wallclock()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


func _test_accrual() -> void:
	var c := SimClock.new()
	c.advance(3600)        # 1h
	c.advance(1800)        # +30m
	_ok(c.time_of_day == 5400, "advance accumulates seconds-of-day (%d)" % c.time_of_day)
	_ok(c.day == 0, "no rollover before midnight")
	_ok(c.full_time() == 5400, "full_time tracks total (%d)" % c.full_time())
	# negative / zero advances are no-ops.
	c.advance(0)
	c.advance(-100)
	_ok(c.time_of_day == 5400, "zero/negative advance is a no-op")


func _test_rollover() -> void:
	var c := SimClock.new()
	var fired: Array[int] = []
	c.day_rolled_over.connect(func(nd): fired.append(nd))
	c.advance(SimClock.SECONDS_DAY - 10)   # near midnight
	_ok(c.day == 0 and fired.is_empty(), "no rollover just before midnight")
	c.advance(20)                          # cross midnight
	_ok(c.day == 1, "day increments on midnight crossing")
	_ok(c.time_of_day == 10, "time_of_day wraps to the remainder (%d)" % c.time_of_day)
	_ok(fired == [1], "day_rolled_over fired once with the new day")


func _test_multi_day_jump() -> void:
	var c := SimClock.new()
	var fired: Array[int] = []
	c.day_rolled_over.connect(func(nd): fired.append(nd))
	# One big advance crossing 3 day boundaries.
	c.advance(SimClock.SECONDS_DAY * 3 + 100)
	_ok(c.day == 3, "multi-day advance lands on the right day (%d)" % c.day)
	_ok(c.time_of_day == 100, "multi-day advance keeps the remainder")
	_ok(fired == [1, 2, 3], "rollover fires once per boundary crossed: %s" % str(fired))


func _test_determinism() -> void:
	# The determinism cut: same sequence of advance() calls -> identical state.
	# (BDCC2 ticked off frame delta; aeriea ticks off the timeline.)
	var seq := [3600, 7200, 50000, 90000, 1, SimClock.SECONDS_DAY * 2]
	var a := SimClock.new()
	var b := SimClock.new()
	for s in seq:
		a.advance(s)
	for s in seq:
		b.advance(s)
	_ok(a.day == b.day and a.time_of_day == b.time_of_day and a.full_time() == b.full_time(),
		"same advance() sequence -> identical clock state (deterministic replay)")
	# And summing the advances == one big advance to the same full_time.
	var total := 0
	for s in seq:
		total += s
	var c := SimClock.new()
	c.advance(total)
	_ok(c.full_time() == a.full_time(),
		"split advances == one advance of the sum (%d == %d)" % [c.full_time(), a.full_time()])


func _test_helpers() -> void:
	var ft := SimClock.SECONDS_DAY * 4 + 12345
	_ok(SimClock.day_at(ft) == 4, "day_at")
	_ok(SimClock.seconds_since_day_start(ft) == 12345, "seconds_since_day_start")
	_ok(SimClock.advance_full_time(1000, 500) == 1500, "advance_full_time")
	# from_dict / to_dict round-trips.
	var c := SimClock.new()
	c.advance(SimClock.SECONDS_DAY + 42)
	var c2 := SimClock.from_dict(c.to_dict())
	_ok(c2.day == c.day and c2.time_of_day == c.time_of_day, "to_dict/from_dict round-trips")


# Stepping render/physics frames must NOT move the clock — only advance() does.
func _test_no_wallclock() -> void:
	var c := SimClock.new()
	var before := c.full_time()
	# Simulate frames elapsing (the clock has no _process; nothing should change).
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	_ok(c.full_time() == before, "frames elapsing do NOT move the clock (timeline-driven)")
