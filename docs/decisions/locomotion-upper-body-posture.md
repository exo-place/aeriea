# Locomotion upper-body posture — root cause + fix

Status: implemented (render-side). Not green (awaits user verification).
Scope: fixes TODO thread 9 (humanoid locomotion upper-body posture defect).

## Symptom

During locomotion (creator Walk/Run preview, sandbox walking) the character showed a
hunched/twisted torso, a craned neck+head that folded the skinned head into a visible
**"double head"**, and arms flung wide. Idle looked fine.

## What the diagnosis got right, and what it missed

The handoff diagnosis correctly located that during locomotion the clip-overlay and
arm-IK layers are inactive, so the upper body is stamped straight from the
Motion-Matching DB (`body_rig.gd _apply_motion_matching`). It attributed the bad poses to
**corrupt clip-OPENING frames** and prescribed an ingest-side lead-in trim.

Reading fresh from the live source (rendered single-frame stamps + a composed head/arm
world-orientation scan over every frame of the committed DB) showed the diagnosis was
**materially incomplete on two counts**:

1. **The DB corruption is systemic, not just clip openings.** Measuring the composed
   head-world crane per frame across all 24 clips: the back-walk/run, strafe, and
   StartStop clips are corrupt across a LARGE fraction of their frames (e.g. Neutral_BR
   252/360, StartStop_TR1 262/360, StartStop_ID 184/360), scattered throughout — not a
   leading run. A lead-in trim cannot fix scattered corruption. The corruption compounds
   down the whole upper chain (no single bone is egregious), and re-ingesting the
   vendored clips reproduces it, so it is a **live retarget defect**, not a stale
   artifact. Forward walk/run/idle clips are mostly clean *except* their openings.

2. **The "double head" has a SECOND, larger cause: the foot-lock crouch.** Even with a
   provably-clean idle pose on the head/neck, locomotion still split the head. Bisection
   (render with foot-lock off / crouch off) pinned it to `_apply_foot_lock` **translating
   the ROOT bone** down by `gait_crouch` (0.09 m). The root bone's translation is reserved
   for the sim ("sim owns root translation" — `_apply_motion_matching`); driving it from
   the render layer desynced the skinned body mesh and split the head. This was previously
   masked by the corrupt-frame double head, so it read as the same defect.

Two independent defects presenting as one. (Also confirmed: the double head is NOT the
eye/teeth proxy.)

## Fix (render-side, deterministic, no DB regeneration)

1. **Upper body from the clean idle frame during locomotion.** `_apply_motion_matching`
   now poses root + the whole upper body (spine/neck/head/clavicles/arms) from the cached
   clean idle frame (the deterministic zero-goal argmin, Neutral_ID mid-clip — verified
   upright, arms relaxed). Only the LEG bones take the matched locomotion frame, and they
   are in turn overridden by the distance-phased foot-lock. This guarantees an upright,
   double-head-free posture for EVERY goal, independent of the corrupt DB and of which
   (possibly wrong-direction) clip the search selects. A cadence-matched procedural arm
   counter-swing (phase = the foot-lock `_gait_phase`, amplitude scaling with speed) adds
   life over the clean idle arms.

2. **Foot-lock crouch disabled** (`gait_crouch` default 0.0). It desynced the mesh by
   translating the root bone. Legs still plant without skating — the world-anchored foot-IK
   targets are what kill the skate, not the pelvis drop (verified by rendered walk cycles).
   A proper lowered-COM crouch that offsets the skeleton NODE (feet re-anchored by IK)
   rather than the root bone is a future refinement.

3. **Matcher loop-safety** (`motion_matcher._clip_safe_start`). Looping a clip at its end
   now targets `clip_start + loop_lead_in` (interior), never the corrupt clip opening.

4. **Continuity trap fixed** (`motion_matcher.search`). The cross-clip continuity cost was
   adding the ABSOLUTE array-index distance between clips (meaningless — clips are
   concatenated in arbitrary order), imposing a penalty of hundreds on any distant clip,
   which trapped every locomotion goal in the idle clip. Cross-clip cost is now the flat
   switch penalty only, and `clip_switch_penalty` was lowered 40 → 3 so a walk/run goal
   actually escapes idle. A regression test (`body_motion_matching_test` §3b) drives
   `step()` with a continuity anchor and requires walk/run to escape idle — the previous
   `search()`-only tests missed the trap because a fresh matcher has continuity disabled.

## Known-open (documented, not fixed here)

- **Retarget upper-body corruption** in the committed DB is systemic. Because the fix no
  longer shows the DB upper body during locomotion, this is latent, but it must be fixed at
  source (`tools/motion_ingest.gd`) before the captured locomotion upper body / torso lean
  can be re-enabled. The full 100STYLE dataset is now cached in the nix store, so a fixed
  retarget can be verified against all 24 clips via `nix build .#motion-assets`.
- **Clip DIRECTION/SPEED selection** (`motion_matcher._query_feature`): a forward goal
  still matches wrong-direction clips (walk→walk_back/strafe) — the known facing-sign +
  feature-weight-balance item. It has no visual effect now (legs = foot-lock, upper body =
  idle), but blocks re-enabling captured locomotion.
