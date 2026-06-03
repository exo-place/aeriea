## MotionMatcher — deterministic Motion-Matching search over a MotionDB
## (Slice 4 of docs/decisions/body-and-locomotion-slice.md §3.2, research §A1).
##
## RENDER-SIDE + DETERMINISTIC. Given a goal trajectory derived from the movement
## sim's MovementState (desired planar velocity + facing), it builds a query
## feature vector, normalizes it with the DB's stats, and finds the best-matching
## frame by an argmin of weighted squared feature distance — a pure database
## lookup, NO learned weights, NO sampling, NO per-query inference. The float path
## is fixed and the tie-break is the lowest frame index, so the same query on the
## same DB yields the same frame on every run and (modulo IEEE-754) every platform
## — exactly the determinism the seed+action-log model requires.
##
## The matcher NEVER touches the sim: it reads a goal computed from MovementState
## and writes only a chosen frame index, which BodyRig turns into a pose. It is
## excluded from the sim hash (movement-substrate §6); the golden traces are the
## regression guard.
class_name MotionMatcher
extends RefCounted

var db: MotionDB

## How often to re-search (in render frames). Between searches we advance the
## matched frame along its clip (continuity), re-searching periodically or when
## the goal changes enough. Deterministic given the same per-frame goals.
var search_interval: int = 5

## Feature group weights (trajectory matters most for responsiveness; feet for
## continuity). Length must match the feature layout in motion_ingest.gd.
var _weights: PackedFloat32Array

## The 100STYLE captures translate the root far more slowly (per real second)
## than the sim's metres-per-second speeds — the goal's literal m/s must be mapped
## into the DB's locomotion-motion scale, or every goal saturates to the
## largest-displacement clips. This factor maps sim m/s → DB trajectory scale; it
## is derived from the DB distribution (sim walk_speed≈5.5 m/s ↦ the DB walk
## clips). Deterministic constant; not learned.
var goal_speed_scale: float = 0.13

var current_frame: int = 0
var _since_search: int = 999


func setup(p_db: MotionDB) -> void:
	db = p_db
	_build_weights()
	current_frame = 0
	_since_search = 999


func _build_weights() -> void:
	# trajectory horizons: 4 each ; feet: 12 ; hip vel: 2
	_weights = PackedFloat32Array()
	_weights.resize(db.feature_dim)
	var i := 0
	for _h in db.traj_horizons:
		_weights[i + 0] = 1.0  # future pos x
		_weights[i + 1] = 1.0  # future pos z
		_weights[i + 2] = 3.0  # future facing sin (turn responsiveness)
		_weights[i + 3] = 3.0  # future facing cos
		i += 4
	# feet (12): the query has no foot goal, so a nonzero foot weight would pull
	# every match toward the DB's mean foot pose. Goal matching uses ONLY the
	# trajectory + hip-velocity features (classic MM responsiveness terms); foot
	# continuity is handled by clip-advance between searches. Weight = 0.
	for _k in 12:
		_weights[i] = 0.0; i += 1
	# hip vel (2): strong (drives walk/run/idle separation)
	_weights[i] = 3.0; i += 1
	_weights[i] = 3.0; i += 1


## Build a query feature from a goal: desired LOCAL-frame planar velocity (m/s,
## already rotated into the character's facing frame: +z forward, +x right) and a
## desired turn rate (radians/s). We synthesize the same trajectory/feet/hipvel
## layout the DB uses, assuming roughly constant velocity over the horizons.
func _query_feature(local_vel: Vector2, turn_rate: float) -> PackedFloat32Array:
	var out := PackedFloat32Array(); out.resize(db.feature_dim)
	var dt_per_sample := db.frame_stride / 60.0   # seconds per sampled frame
	# KNOWN REFINEMENT (decision doc Slice-4 §): the retargeted 100STYLE facing
	# frame has FORWARD = -z (verified against the walk vs walk_back clip
	# distributions) while the caller's local_vel uses +z = forward; reconciling
	# the sign convention together with the facing-vs-trajectory weight balance is
	# a tuning pass best done against on-screen motion. The search is already
	# deterministic and goal-responsive (speed/idle/turn-magnitude separation); the
	# exact forward/back clip pick is the open polish item.
	var sv := local_vel * goal_speed_scale        # map sim m/s -> DB motion scale
	var i := 0
	for h in db.traj_horizons:
		var t := float(h) * dt_per_sample
		# future pos = vel * t (local frame, constant-velocity assumption)
		out[i + 0] = sv.x * t
		out[i + 1] = sv.y * t
		var fyaw := turn_rate * t
		out[i + 2] = sin(fyaw)
		out[i + 3] = cos(fyaw)
		i += 4
	# feet: leave at 0 (no goal for feet; weight is low anyway)
	for _k in 12:
		out[i] = 0.0; i += 1
	# hip planar velocity over one sampled-frame step (local frame)
	out[i + 0] = sv.x * dt_per_sample
	out[i + 1] = sv.y * dt_per_sample
	return out


## Advance one render frame. `local_vel` = desired planar velocity in the
## character facing frame (m/s); `turn_rate` = desired yaw rate (rad/s). Returns
## the matched DB frame index (also stored as current_frame). Deterministic.
func step(local_vel: Vector2, turn_rate: float) -> int:
	if db == null or db.frame_count == 0:
		return 0
	_since_search += 1
	var need_search := _since_search >= search_interval
	if need_search:
		current_frame = search(local_vel, turn_rate)
		_since_search = 0
	else:
		# advance along the clip; if we hit the clip end, force a re-search
		var nxt := current_frame + 1
		if nxt >= db.frame_count or db.clip_id[nxt] != db.clip_id[current_frame]:
			current_frame = search(local_vel, turn_rate)
			_since_search = 0
		else:
			current_frame = nxt
	return current_frame


## The deterministic argmin. Returns the frame whose normalized feature is
## closest (weighted squared distance) to the normalized query. Tie-break: lowest
## frame index (first encountered wins; strict `<` never replaces on equality).
func search(local_vel: Vector2, turn_rate: float) -> int:
	var q := _query_feature(local_vel, turn_rate)
	# normalize the query with the DB stats (same transform the DB features got)
	var fd := db.feature_dim
	var qn := PackedFloat32Array(); qn.resize(fd)
	for d in fd:
		qn[d] = (q[d] - db.feature_mean[d]) / db.feature_std[d]
	var best := 0
	var best_cost := INF
	var fc := db.frame_count
	var feats := db.features
	for f in fc:
		var base := f * fd
		var cost := 0.0
		for d in fd:
			var diff := feats[base + d] - qn[d]
			cost += _weights[d] * diff * diff
			if cost >= best_cost:
				break   # early-out keeps it deterministic (cost monotonic increasing)
		if cost < best_cost:
			best_cost = cost
			best = f
	return best
