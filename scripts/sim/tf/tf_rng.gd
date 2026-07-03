## Seeded, coordinate-keyed deterministic draws.
##
## Any randomness in the substrate is a PURE FUNCTION of (seed + a deterministic
## coordinate). Never wall-clock, never a native/global RNG stream whose result
## depends on how many times it was called elsewhere. Given the same seed and the
## same coordinate you always get the same draw, so replay from (seed + action
## log) reproduces every draw exactly.
##
## A "coordinate" is just an integer the caller derives from deterministic state
## — e.g. the evaluation position in the tick's total order mixed with a
## per-transition draw counter that lives in a plain field. It is NOT a clock.
class_name TFRng
extends RefCounted

const MASK := 0x7FFFFFFFFFFFFFFF   # keep results non-negative


## A 64-bit avalanche mix (splitmix64 finalizer). Pure, deterministic, wrapping.
static func _mix(x: int) -> int:
	x = x ^ (x >> 30)
	x = x * -49064778989728563       # 0x... wrapping multiply
	x = x ^ (x >> 27)
	x = x * -4265267296055464877
	x = x ^ (x >> 31)
	return x


## Combine two integers into one coordinate, order-sensitively.
static func mix2(a: int, b: int) -> int:
	return _mix(_mix(a) ^ (b * -7046029254386353131))


## A non-negative 63-bit integer draw from (seed, coord).
static func draw_int(seed: int, coord: int) -> int:
	return _mix(seed ^ mix2(coord, -7046029254386353131)) & MASK   # 0x9E37…C15 as signed


## A deterministic float in [0, 1) from (seed, coord).
static func draw_unit(seed: int, coord: int) -> float:
	# 53 bits of mantissa precision.
	return float(draw_int(seed, coord) & ((1 << 53) - 1)) / float(1 << 53)


## True with probability `p` (0..1), deterministically from (seed, coord).
static func chance(seed: int, coord: int, p: float) -> bool:
	return draw_unit(seed, coord) < p
