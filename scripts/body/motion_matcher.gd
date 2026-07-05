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

## Continuity / inertia term (the standard motion-matching "favor the current clip"
## cost). Each search candidate is penalized by its frame-distance from the EXPECTED
## CONTINUATION of the current clip (current_frame + 1 in the same clip_id). Without
## it, a steady goal deterministically re-locks the SAME global-argmin frame every
## search_interval — the clip only ever advances a few frames then snaps back, so the
## gait freezes mid-stride and skates. With it, an unchanged goal plays the clip
## through (the continuation frame wins over a distant equally-good match), while a
## MATERIALLY changed goal still overcomes the penalty and jumps clips. The units are
## cost-per-frame-of-distance, comparable to the weighted squared feature distance;
## tuned so a steady locomotion goal visibly cycles. Deterministic (no wall-clock/RNG).
var continuity_weight: float = 0.15
## Flat continuity penalty (in frame-distance units) charged to a candidate that lives
## in a DIFFERENT clip than the current frame — the "cost of switching clips". Keeps
## within-clip advance preferred while still letting a real goal change pay it. LOWERED
## from 40 to 3: at 40 the switch cost (continuity_weight·40 = 6.0) exceeded a walk-speed
## goal's feature advantage over the current idle frame, so Walk/Run stayed trapped in
## the idle clip even after the cross-clip index-distance bug was fixed (see search()).
## 3 lets a real locomotion goal escape idle while a steady goal still plays its clip
## through. (Note: with the foot-lock owning the legs and the upper body posed from the
## idle frame, the matched locomotion frame is not currently shown, so this only governs
## the matcher's clip-selection behaviour — but it is kept correct for when the captured
## locomotion pose is re-enabled.)
var clip_switch_penalty: float = 3.0
## Goal speed (m/s) below which the continuity term is disabled: a standing goal
## holds its argmin idle frame (breathing/fidget layers keep it alive) instead of
## drifting through the idle clip. Above it, continuity carries the locomotion gait.
var continuity_min_speed: float = 0.5
## While moving, the matcher plays the current clip through and only RE-SEARCHES when
## the goal shifts by more than these thresholds since the last search (planar-velocity
## metres/s, and yaw rate rad/s). Small drifts keep the gait playing; a real turn or a
## walk↔run change re-plans. Deterministic float compares (seeded-sim safe).
var goal_change_speed_eps: float = 1.0
var goal_change_turn_eps: float = 0.5

var current_frame: int = 0
var _since_search: int = 999
## The goal (planar velocity + turn rate) at the last search, to detect a material
## goal change while moving.
var _last_vel: Vector2 = Vector2.ZERO
var _last_turn: float = 0.0
## Set once the matcher has produced at least one real match, so the very first search
## is a pure goal-only pick (no spurious continuity anchor on the initial frame 0).
var _has_match: bool = false


func setup(p_db: MotionDB) -> void:
	db = p_db
	_build_weights()
	current_frame = 0
	_since_search = 999
	_has_match = false
	_last_vel = Vector2.ZERO
	_last_turn = 0.0


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
	# Decide whether to re-search (global argmin) or continue the current clip.
	#   - Not yet matched: search (bootstrap).
	#   - Standing (goal below continuity_min_speed): re-lock periodically to the argmin
	#     idle frame — a HELD stand kept alive by the breathing/fidget layers.
	#   - Moving with a STEADY goal: do NOT re-search on the timer — that is exactly what
	#     snapped the clip back to the best-phase frame every few frames and froze the
	#     gait. Instead advance the clip (and loop at its end), so the gait plays through
	#     and cycles.
	#   - Moving with a MATERIALLY CHANGED goal: re-search so a new direction/speed
	#     re-plans (the continuity term in search() lets a small change keep the clip and
	#     a large one jump clips).
	var moving := local_vel.length() >= continuity_min_speed
	var need_search := false
	if not _has_match:
		need_search = true
	elif not moving:
		need_search = _since_search >= search_interval
	else:
		need_search = local_vel.distance_to(_last_vel) >= goal_change_speed_eps \
			or absf(turn_rate - _last_turn) >= goal_change_turn_eps
	if need_search:
		current_frame = search(local_vel, turn_rate)
		_since_search = 0
		_last_vel = local_vel
		_last_turn = turn_rate
	else:
		# Advance along the clip. At the clip end, LOOP back to a SAFE interior frame of
		# the clip — NOT its literal first frame. Every 100STYLE clip opens with several
		# settling/reference frames whose retarget is corrupt (a craned head + flung arms),
		# so looping to frame 0 landed straight on the worst pose each cycle. Looping to
		# clip_start + loop_lead_in skips that settling window (belt-and-suspenders with the
		# ingest-side CLIP_TRIM). Deterministic.
		var nxt := current_frame + 1
		if nxt >= db.frame_count or db.clip_id[nxt] != db.clip_id[current_frame]:
			current_frame = _clip_safe_start(current_frame)
		else:
			current_frame = nxt
	_has_match = true
	return current_frame


## First frame index of the clip that `frame` belongs to (scans back over the
## contiguous same-clip_id block). Deterministic.
func _clip_start_of(frame: int) -> int:
	if db == null or frame < 0 or frame >= db.frame_count:
		return 0
	var cid := db.clip_id[frame]
	var s := frame
	while s > 0 and db.clip_id[s - 1] == cid:
		s -= 1
	return s


## Frames to skip past a clip's corrupt settling opening when looping. Deterministic.
var loop_lead_in: int = 12

## A SAFE interior loop target for the clip `frame` belongs to: clip_start + loop_lead_in,
## clamped to stay inside the clip (so a short clip still loops in-bounds). Avoids the
## corrupt clip-opening frames every loop. Deterministic.
func _clip_safe_start(frame: int) -> int:
	var s := _clip_start_of(frame)
	# clip length (contiguous same-clip_id run from s)
	var cid := db.clip_id[s]
	var e := s
	while e + 1 < db.frame_count and db.clip_id[e + 1] == cid:
		e += 1
	var lead := mini(loop_lead_in, (e - s) / 2)
	return s + maxi(lead, 0)


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
	# Continuity anchor: the frame the current clip is expected to continue to. Only
	# active once we've matched at least once (the initial search is pure goal-only)
	# AND only for a locomotion goal — below continuity_min_speed the body is standing,
	# where a held argmin idle frame (plus layered breathing/fidgets) is the intended
	# alive stand, so continuity there would wrongly drift the idle instead of holding.
	var use_cont := _has_match and continuity_weight > 0.0 and local_vel.length() >= continuity_min_speed
	var cur := current_frame
	var cur_clip := db.clip_id[cur] if (use_cont and cur >= 0 and cur < fc) else -1
	var expected := cur + 1
	for f in fc:
		# Seed the cost with the continuity penalty so the monotonic early-out below
		# stays valid (feature terms are non-negative and only add to it).
		var cost := 0.0
		if use_cont:
			if db.clip_id[f] == cur_clip:
				# Within the current clip, favor the expected continuation frame by its
				# frame-distance (a genuine motion-continuity signal).
				var d_frame := absf(float(f - expected))
				cost = continuity_weight * d_frame
			else:
				# A DIFFERENT clip: charge ONLY the flat switch penalty. The clips are
				# concatenated in an arbitrary order, so the array-index distance between
				# two clips is meaningless — yet the old cost added it (clip_switch_penalty
				# + d_frame), imposing a penalty of HUNDREDS on any clip far away in the
				# buffer. That trapped every locomotion goal in whichever clip the matcher
				# started in (the idle clip), so Walk/Run never left idle. The flat switch
				# penalty alone is the intended, bounded cost of changing clips.
				cost = continuity_weight * clip_switch_penalty
		var base := f * fd
		for d in fd:
			var diff := feats[base + d] - qn[d]
			cost += _weights[d] * diff * diff
			if cost >= best_cost:
				break   # early-out keeps it deterministic (cost monotonic increasing)
		if cost < best_cost:
			best_cost = cost
			best = f
	return best
