## SimClock — aeriea's deterministic seconds-of-day / day-rollover clock.
##
## PORTED (Path A) from BDCC2 `Game/Systems/MemorySystem/TimeManager.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
##
## What is ported (the reusable MODEL): the seconds-of-day + day-count split, the
## SECONDS_DAY rollover, the full-time helpers (getTimeFull / getDayAt /
## getSecondsSinceDayStart / advanceFullTime), and the day-rollover hook.
##
## Path-A cuts (the ONE real determinism cut the backlog flagged):
##   - DELETED `_physics_process(_delta)` frame-delta accrual. BDCC2 ticked the
##     clock off the render frame delta — NONDETERMINISTIC (frame rate varies). In
##     aeriea, time advances ONLY via `advance(seconds)`, called off aeriea's SEEDED
##     ACTION-LOG TIMELINE (each logged action carries the seconds it consumes). Same
##     seed + same action log -> identical clock. No frame delta, no wall-clock.
##   - DELETED `Network.isServer()` / `Network.isServerNotSingleplayer()` gates and
##     the whole `syncTime` / `Bins` / RPC networking path (BDCC2 client-server
##     coupling — not aeriea's model; aeriea is self-hosted + deterministic replay).
##   - DELETED the `SAVE.loadVar` / `Bins` serialization (aeriea persists as
##     seed+action-log, not an object-state dump — bdcc2-mining-backlog.md #10).
##     A plain to_dict/from_dict is kept for tests/debug only.
##
## ---- THE SEAM (aeriea owns the interface) ------------------------------------
##   advance(seconds: int) -> void        # the ONLY way time moves (timeline-driven)
##   full_time() -> int                   # absolute seconds since t0 (day*86400 + time)
##   day, time_of_day                     # current day count / seconds-into-today
##   day_rolled_over (signal)             # fired once per midnight crossing
##
## Determinism: `advance` is pure integer arithmetic. Replaying the same sequence of
## advance() calls from the same start reproduces day/time_of_day/full_time exactly.
class_name SimClock
extends RefCounted

const SECONDS_DAY := 86400

## Fired once for EACH day boundary crossed by an advance() (a single big advance can
## cross several). Carries the new day index. Listeners (e.g. memory GC) hook this.
signal day_rolled_over(new_day: int)

## Seconds elapsed since the current day started (0 .. SECONDS_DAY-1).
var time_of_day: int = 0
## How many whole days have elapsed since t0.
var day: int = 0


## Advance the clock by `seconds` (>= 0). The ONLY mutation path — driven by
## aeriea's seeded timeline, never by a frame delta. Crossing midnight rolls the day
## and emits `day_rolled_over` once per boundary crossed.
func advance(seconds: int) -> void:
	if seconds <= 0:
		return
	time_of_day += seconds
	while time_of_day >= SECONDS_DAY:
		time_of_day -= SECONDS_DAY
		day += 1
		day_rolled_over.emit(day)


## Absolute seconds since t0 (the value memories stamp themselves with).
func full_time() -> int:
	return day * SECONDS_DAY + time_of_day


## Set the clock to an absolute full-time directly (for tests / deterministic seeding /
## restore from a replayed log position). Does NOT emit rollover signals (it is a jump,
## not an accrual). Use advance() for normal forward motion.
func set_full_time(ft: int) -> void:
	ft = maxi(0, ft)
	@warning_ignore("integer_division")
	day = ft / SECONDS_DAY
	time_of_day = ft % SECONDS_DAY


# --- static full-time helpers (ported verbatim in spirit; pure arithmetic) -----

static func day_at(full_time_val: int) -> int:
	@warning_ignore("integer_division")
	return full_time_val / SECONDS_DAY


static func seconds_since_day_start(full_time_val: int) -> int:
	return full_time_val % SECONDS_DAY


static func advance_full_time(from: int, by: int) -> int:
	return from + by


# --- serializable form (tests/debug only; NOT the persistence model) -----------

func to_dict() -> Dictionary:
	return {"time_of_day": time_of_day, "day": day}


static func from_dict(d: Dictionary) -> SimClock:
	var c := SimClock.new()
	c.time_of_day = int(d.get("time_of_day", 0))
	c.day = int(d.get("day", 0))
	return c
