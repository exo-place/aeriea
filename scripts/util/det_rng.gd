## DetRng — aeriea's shared deterministic integer-only PRNG (splitmix64).
##
## Extracted from the pattern proven in `scripts/text/cxg_realizer.gd` (Rng inner
## class). Integer-only, no float in the draw path, no string hashing at runtime, no
## global mutable state. GDScript ints are 64-bit signed; bit ops wrap as
## two's-complement, the same bit pattern splitmix64 wants. Every draw masks off the
## sign bit before mod, so the sign of the raw word never reaches a decision.
##
## Determinism contract: a DetRng seeded with the same integer reproduces the exact
## same sequence. For the TF applier, the seed is a pure function of
## (world_seed, action_id, stage_index, op_index) — so replaying an action log
## reproduces every roll bit-for-bit. See `seed_for()`.
class_name DetRng
extends RefCounted

var s: int


func _init(seed_value: int) -> void:
	s = seed_value


func next() -> int:
	s = s + -0x61C8864680B583EB           # 0x9E3779B97F4A7C15 as signed; wraps mod 2^64
	var z: int = s
	z = (z ^ (z >> 30)) * -0x40A7B892E31B1A47   # 0xBF58476D1CE4E5B9 as signed
	z = (z ^ (z >> 27)) * -0x6B2FB644ECCEEE15   # 0x94D049BB133111EB as signed
	z = z ^ (z >> 31)
	return z


## Non-negative draw in [0, n). `n` must be > 0.
func below(n: int) -> int:
	var raw: int = next() & 0x7FFFFFFFFFFFFFFF   # drop sign bit -> non-negative
	return raw % n


## Inclusive integer draw in [lo, hi]. Integer-only.
func range_inclusive(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + below(hi - lo + 1)


## Derive a stable per-op seed from the action-log coordinate. A pure integer mix of
## (world_seed, action_id, stage_index, op_index) so the same coordinate always yields
## the same seed. Each term is folded through a splitmix64 step so adjacent coordinates
## decorrelate (no float, no string hashing).
static func seed_for(world_seed: int, action_id: int, stage_index: int, op_index: int) -> int:
	var x: int = world_seed
	x = _mix(x ^ (action_id * -0x61C8864680B583EB))
	x = _mix(x ^ (stage_index * -0x40A7B892E31B1A47))
	x = _mix(x ^ (op_index * -0x6B2FB644ECCEEE15))
	return x


static func _mix(v: int) -> int:
	var z: int = v + -0x61C8864680B583EB
	z = (z ^ (z >> 30)) * -0x40A7B892E31B1A47
	z = (z ^ (z >> 27)) * -0x6B2FB644ECCEEE15
	return z ^ (z >> 31)
