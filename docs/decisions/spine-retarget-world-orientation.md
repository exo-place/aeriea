# Spine retarget by world-space segment orientation

Status: IMPLEMENTED + re-ingested + verified (see "As-built resolution" below). Was:
design pass. Supersedes the local-rotation copy in `tools/motion_ingest.gd` for the
spine + neck + head chain.
Scope: fixes the "double head"/over-folded-neck retarget defect at its source
(the ingest), replacing the local-rotation `BONE_MAP` primitive for the axial chain.
Related: `docs/decisions/locomotion-upper-body-posture.md` (the render-side workaround
this makes unnecessary), `docs/decisions/body-and-locomotion-slice.md` (Slice 4).

## Decided principle (given — not re-litigated here)

Preserve the WORLD-SPACE orientation of each anatomical segment (chest, neck, head),
not parent-relative local rotations. Local rotations are proportion/segmentation
dependent and copying them across skeletons of different segment counts is lossy.
Sample the SOURCE chain's world orientation along its arc length and solve the TARGET
chain's per-segment locals so each target joint reproduces the world orientation at its
corresponding arc position. Head ends up pointing where the source head points regardless
of segment count; sagittal bend distributes across the target spine instead of dumping on
one joint.

## Ground truth: the two skeletons (measured from live source)

### Source — 100STYLE BVH axial chain (read from vendored `Neutral_FW.bvh`)
Offsets are each child's OFFSET from its parent, in cm, essentially +Y with tiny Z:

| segment            | offset (cm)            | length | cum. arc (cm) | norm (Hips=0,Neck=1) |
|--------------------|------------------------|--------|---------------|----------------------|
| Hips               | (root)                 | -      | 0.00          | 0.000                |
| Hips→Chest         | (0, 12.953, -0.028)    | 12.95  | 12.95         | 0.235                |
| Chest→Chest2       | (0, 10.280,  0.052)    | 10.28  | 23.23         | 0.422                |
| Chest2→Chest3      | (0,  9.287,  0.000)    |  9.29  | 32.52         | 0.590                |
| Chest3→Chest4      | (0,  9.287,  0.000)    |  9.29  | 41.81         | 0.759                |
| Chest4→Neck        | (0, 13.296,  0.000)    | 13.30  | 55.10         | 1.000                |
| Neck→Head          | (0,  8.959,  0.099)    |  8.96  | 64.06         | (neck 0→1)           |
| Head→End Site tip  | (0, 17.121,  0.039)    | 17.12  | 81.18         | -                    |

Source spine (Hips→Neck) = 55.10 cm across 5 segments; neck (Neck→Head) = 8.96 cm, one
segment; then Head. Channels are Y,X,Z-rotation Euler per joint (twist-carrying).

### Target — MakeHuman rig (`assets/body/base_body_rig.json`)
CRITICAL, read-from-code + measured: the naming is INVERTED from a naive reading. The
real parent chain (by parent index, and confirmed by monotone-ascending head Y) is:

```
root → spine05 → spine04 → spine03 → spine02 → spine01 → neck01 → neck02 → neck03 → head
```

spine05 is the LOWEST (lumbar, attached to root); spine01 is the HIGHEST (thoracic, just
below neck01). Every bone's `basis` is the identity 3x3 — rest bases are world-identity,
bind segment directions are ≈ +Y (small Z). Bone HEAD pivots (m) and pivot-to-pivot arc:

| joint   | head (m)              | seg len (m) | cum. arc (m) | norm (root=0,neck01=1) |
|---------|-----------------------|-------------|--------------|------------------------|
| root    | (0, 0.873, -0.076)    | -           | 0.000        | 0.000                  |
| spine05 | (0, 0.889,  0.014)    | 0.091       | 0.091        | 0.146                  |
| spine04 | (0, 0.935, -0.010)    | 0.052       | 0.143        | 0.230                  |
| spine03 | (0, 1.003,  0.015)    | 0.072       | 0.215        | 0.345                  |
| spine02 | (0, 1.096,  0.026)    | 0.094       | 0.309        | 0.496                  |
| spine01 | (0, 1.250, -0.007)    | 0.157       | 0.466        | 0.748                  |
| neck01  | (0, 1.406,  0.007)    | 0.157       | 0.623        | 1.000                  |
| neck02  | (0, 1.444,  0.022)    | 0.041       | 0.664        | (neck 0→1)             |
| neck03  | (0, 1.479,  0.034)    | 0.037       | 0.701        |                        |
| head    | (0, 1.514,  0.016)    | 0.039       | 0.740        |                        |

Target spine (root→neck01) = 0.623 m across 6 segments; neck (neck01→head) = 0.117 m
across 3 segments.

### Why the current map fails (root cause, now precisely located)
`tools/motion_ingest.gd` `MH_PARENT` declares `spine01←root`, `spine03←spine01`,
`neck01←spine03`. That is TOPOLOGICALLY BACKWARDS: spine01 is actually the top of the
spine (child of spine02, parent of neck01), and only 3 of the 9 axial joints are driven
(spine02/04/05, neck02/03 held at rest). So (a) the de-yawed BVH global that should land
on the lower spine is applied to the upper spine, and (b) the entire Chest3/Chest4 bend
(source norm-arc 0.59 and 0.76) has NO target joint mapped near it — the local-conversion
collapses that bend onto neck01, over-folding the head ~70-90°. This matches the systemic
upper-body corruption measured in `locomotion-upper-body-posture.md`.

## Algorithm (step by step)

All steps run per SAMPLED frame, inside the existing `_retarget_clip` loop, replacing the
`tgt_global`/`pose` construction for the axial bones only (arms/legs/root unchanged).

1. **Source world orientations.** FK the source BVH as today (`_fk_frame` gives `grot[k]`
   = each joint's world rotation quaternion). De-yaw by `yaw_inv = _yaw_only(root_g)^-1`
   (facing is sim-owned) exactly as the existing code does: `Gd[k] = yaw_inv * grot[k]`.
   Take the de-yawed world orientations at Hips, Chest, Chest2, Chest3, Chest4, Neck, Head.

2. **Build the arc-parameterized source orientation curve.** Attach each source
   orientation to its normalized arc position: spine samples at s ∈ {0.000 (Hips),
   0.235, 0.422, 0.590, 0.759, 1.000 (Neck)}; neck samples at u ∈ {0 (Neck), 1 (Head)}.
   This is the orientation profile the target chain must reproduce.

3. **Correspondence by normalized arc length.** For each target axial joint, take its
   normalized arc position (spine table col 5; neck joints along neck u): spine05 .146,
   spine04 .230, spine03 .345, spine02 .496, spine01 .748, neck01 1.0; neck02/neck03/head
   along the neck segment. Find the two bracketing source samples and get the desired
   world orientation by SLERP at the interpolation parameter. Spine maps over its own
   [0,1] and neck over its own [0,1], so the 5-source-segment vs 6-target-segment mismatch
   dissolves — no joint is left unmapped, none invents an out-of-profile pose.

4. **Constrained solve = orientation-driven spline-IK with swing/twist DOF locks.** The
   desired world orientation per target joint is decomposed (swing-twist about the bone's
   bind axis ≈ +Y) into: sagittal swing (fore-aft bend, about the lateral X axis),
   coronal swing (lateral bend, about the fore-aft Z axis), and axial twist (about +Y).
   Apply the anatomical constraints AS joint limits:
   - **Coronal swing → locked to 0** (lateral flat) unless the source sample's coronal
     component exceeds a threshold `LAT_EPS` (see fork/unknown below).
   - **Axial twist → not synthesized** (vertical straight): the solve never invents twist;
     source-evidenced twist is passed through per the fork decision below, never amplified
     or redistributed across joints.
   - **Sagittal swing → free**, driven ONLY by the sampled orientations. Because it comes
     from arc-slerp of the sparse source samples, it is the minimal-curvature interpolation
     — the aggregate S-curve emerges from the source profile plus the fixed target joint
     offsets, and is NEVER imposed per-segment.

5. **World → local, over the CORRECTED chain.** With target rest bases identity, the local
   pose of a joint = `(parent_world_desired)^-1 * (this_world_desired)`, walking the REAL
   chain root→spine05→…→head. Store xyzw into `pose[]` exactly as today.

Because the desired world orientations are directly assignable (positions are fixed — the
sim owns translation, bones keep rest offsets), the spline-IK reduces to a CLOSED-FORM
orientation assignment; no iteration, preserving the ingest's byte-determinism.

## Sub-approach fork (weighed; one recommended)

This is the standard "reproduce an orientation profile across a chain that has more joints
than control targets" problem. Established machinery, three candidates:

- **(A) Orientation-driven spline-IK, closed form (RECOMMENDED).** Equivalent to Blender's
  *Spline IK* constraint / Maya's `ikSplineHandle` specialized to orientation with the
  chain's stretch fixed: fit the arc-parameterized slerp of source world orientations and
  sample it at each target joint's arc position, with swing/twist limits as the DOF locks
  (Blender Spline IK's "XZ" / twist controls map 1:1 to our coronal-lock / twist-pass).
  Fidelity: exact at every source sample (chest, chest2/3/4, neck, head), minimal-curvature
  between. Robustness: closed-form, deterministic, no convergence risk — required for the
  committed-DB determinism contract. Shape-humility: conservative BY CONSTRUCTION (slerp is
  the minimal-curvature interpolant; locks prevent invented lateral/axial shape).
- **(B) Constrained numerical optimization** (minimize orientation error + curvature
  regularizer subject to DOF locks). Strictly more general, but heavier, needs solver
  tuning, risks non-determinism, and buys nothing here: our targets are per-joint
  orientations, not a global cost. Overkill. Reject.
- **(C) FABRIK / CCD end-orientation IK** (Aristidou & Lasenby 2011, FABRIK; classic CCD).
  These solve for an END-EFFECTOR and let the chain fall out. But we have orientation
  samples ALL ALONG the chain (chest2/3/4), not just the tip — matching only the head
  orientation would DISCARD exactly the mid-chain information whose loss causes the current
  defect. Extending FABRIK/CCD to honor every intermediate orientation converges back to
  (A) with iteration and non-determinism added. Reject as primary; not needed because
  positions are fixed.

Recommendation: **(A)**. It is the canonical, well-understood tool for this exact
underdetermined-distribution case; the closed-form specialization is warranted because we
solve orientation only with fixed bone positions.

## Correspondence + resampling (concrete)

- 5 source spine samples + Hips(identity at 0) → 6 target spine joints, ALL driven from the
  arc-slerped curve (none left at rest). spine01 (norm .748) lands between source Chest3
  (.590) and Chest4 (.759); neck01 (norm 1.0) lands exactly on source Neck — so the
  Chest3/Chest4 bend is reproduced on spine01/spine02 instead of collapsing onto neck01.
- Neck segment (source Neck→Head, u 0→1) → target neck01, neck02, neck03, head slerped
  Neck-orientation → Head-orientation. head (u=1) lands EXACTLY on source Head world
  orientation — this is what fixes the crane / double-head.

## Output compatibility (checked against the runtime, not assumed)

- Stored format is unchanged: `poses[]` is `frame_count * bone_count * 4` xyzw per-bone
  LOCAL quats; `MotionDB.pose_quat` and `body_rig.gd:1534` compose `rest_q * pose_quat`.
  With identity rest bases this is exactly what step 5 produces. No schema change.
- CHANGES REQUIRED (flagged, not silent):
  1. **bone_count grows 17 → 22.** To distribute across the full chain we must now drive
     spine02, spine04, spine05, neck02, neck03 (currently unmapped/held at rest). MotionDB
     is bone_count-parameterized, so the runtime loop is fine — but the test asserts
     `bone_count == 17` (see below) and must be updated to 22.
  2. **`BONE_MAP` / `MH_PARENT` / `MH_TAIL` / `BVH_TAIL` must be corrected for the real
     inverted topology** (root→spine05→…→spine01→neck01→…→head). The current entries are
     topologically wrong for the axial chain.
  3. **`body_rig.gd _apply_motion_matching` upper-body override.** Today it deliberately
     drives spine/neck/head from the CLEAN idle frame and ignores the matched upper body
     (the `locomotion-upper-body-posture.md` workaround). Once this retarget is trustworthy
     that override must be removed/relaxed or the fix is invisible at runtime. This is the
     real runtime-consumer coupling — the ingest fix alone does not change on-screen posture
     until the override is lifted.
- Arms/legs/root retarget paths (de-yaw, `_shortest_arc` A-pose direction transfer) are
  orthogonal and preserved.

## Validation plan (proves correctness at ingest; guards regression)

Add to `tests/body_motion_matching_test.gd` (which already FKs poses and measures pose
angles). All checks FK the target chain from the STORED poses (identity rest bases → head
world orientation = product of local quats along the real chain) and compare to the source
de-yawed world orientation recomputed for the same frame:

1. **Head world-orientation fidelity, ALL clips.** For every sampled frame of every clip
   (incl. BW/BR/SW/SR/StartStop), |angle(target_head_world, source_head_world)| < 10°
   (target ~8°). Current defect is ~70-90°. THIS is the anti-double-head guard.
2. **Lateral (coronal) bend ≈ 0.** For each target spine joint, the coronal-swing
   component of its local < ~4° across all frames (flat; no invented sideways bend).
3. **Axial straightness.** Per-spine-joint synthesized twist ≈ 0 (only pass-through source
   twist allowed); assert no joint's twist exceeds its corresponding source sample + margin.
4. **No per-segment curvature blowup + aggregate-S preserved.** No single target spine
   joint's sagittal bend exceeds the max source segment delta + margin; AND the SUM of
   target spine sagittal bends ≈ the source Hips→Neck total (the S lives in the aggregate,
   distributed conservatively).
5. **Determinism.** Existing byte-stable-DB assertion still holds (closed-form solve).

Regression assertion to add (so it can't silently regress): a per-clip loop asserting
check (1) < threshold AND check (2) < threshold for EVERY clip's sampled frames — this pins
the exact defect (head crane + lateral fabrication) at ingest.

## Honest risks / unknowns / user decisions needed

- **[USER DECISION — axial twist pass-through vs hard lock].** The principle says "vertical:
  straight, no invented axial lean/twist." Source turn/strafe clips carry REAL axial spine
  twist in their Y-rotation channels. "Don't invent" ≠ "erase evidenced twist." Design
  recommends passing through source-sampled twist (evidenced, not fabricated) without
  amplifying or redistributing it — but hard-locking twist to 0 is a defensible stricter
  reading that would flatten turning posture. Genuine fork; needs the user's call, plus the
  numeric `LAT_EPS`/twist thresholds.
- **[USER DECISION — coronal threshold].** "essentially flat unless the samples clearly
  evidence it" requires a concrete `LAT_EPS` (recommend ~5-8°: below it, lock to 0; above,
  pass through). The exact number is a judgment the principle does not fix.
- **Inferred, not measured:** the per-frame magnitudes of source Chest3/Chest4 bend (only
  offsets were read from the vendored BVH header, not a per-frame scan). The "bend dumps on
  neck01" claim is derived from the topology + `MH_PARENT` inversion and is consistent with
  the sibling doc's measured corruption; a per-frame source-bend scan would confirm the
  distribution quantitatively.
- **Under-determined by what was read:** whether any target spine joint has a non-identity
  bind twist that a future rig revision could introduce — current JSON has all-identity
  bases, so the closed-form local conversion is exact today; a future non-identity basis
  would require folding the rest quat in (the runtime already composes `rest_q *`, so the
  ingest would need the same).
- **Runtime coupling risk:** if the `body_rig.gd` upper-body override is lifted, arm swing +
  clavicle interaction with the newly-driven upper spine must be re-checked; the arms are
  retargeted independently and were tuned against the current (idle-clamped) spine.

## As-built resolution (implemented + re-ingested + verified)

Status upgraded from design-pass to IMPLEMENTED. Approach (A) built in
`tools/motion_ingest.gd`; DB re-ingested via `nix build .#motion-assets` over the full
24-clip 100STYLE locomotion set (8640 frames) and committed to
`assets/body/locomotion_mm.res`; render-side override lifted in `body_rig.gd`.

### Topology + solve, as built
- `MH_PARENT` / `BONE_MAP` corrected to the real chain `root → spine05 → spine04 →
  spine03 → spine02 → spine01 → neck01 → neck02 → neck03 → head`; clavicles re-parented
  from the (wrong) spine03 to spine01. All 9 axial joints are now driven. `bone_count`
  17 → 22.
- Per frame: FK source BVH → de-yaw each joint (`yaw_inv`) → arc-slerp the de-yawed
  source world orientations (`AXIAL_ARC` positions) → convert to local over the corrected
  chain → constrain (Euler-YXZ swing/twist) → re-accumulate constrained world. Closed
  form, byte-deterministic. `_solve_axial` / `_arc_slerp` / `_constrain_axial_local`.

### Fork decisions (resolved with the user + by measurement)
- **`LAT_EPS_DEG = 6.0`** (deadband below which coronal is zeroed as noise, on every joint).
- **Axial twist = PASS-THROUGH, not amplified, per-joint CAPPED at
  `MAX_JOINT_TWIST_DEG = 25.0`.** Measured: the arc-slerp already distributes source twist
  smoothly — spine joints ≤4°, twist concentrates naturally in the neck (≤17° on neck01 in
  a turn, declining down the neck: anatomically correct, not a dump). The 25° ceiling is a
  guard that never bites the natural distribution (max measured 17.3° over all 24 clips) yet
  caps a pathological single-joint dump. So both requirements hold: evidenced twist is not
  erased, and each subsegment stays constrained.
- **Coronal — MEASURED DISCOVERY that refined the "locked ~flat" fork.** The 100STYLE
  source carries a pervasive, REAL lateral component (~15-23°/segment, present even in
  idle) that is LOAD-BEARING for head orientation: hard-locking ALL of it flat reintroduces
  a 27-40° head world-orientation error (a head-mis-orientation defect akin to the one this
  fix removes). Resolution — a SPLIT policy (`NECK_CORONAL_PASSTHROUGH`): the SPINE (torso)
  is locked flat above the deadband (spine coronal → 0.0° across all clips — the true "no
  hunch / upright torso" intent, and the design's per-spine-joint <4° test), while the NECK
  passes source-evidenced coronal through so the head still lands on the source orientation
  (head world-orientation error stays ~6°). This is fidelity, not fabrication: neck coronal
  never exceeds the source's own.

### Verified numbers (measured, at ingest, all 24 clips incl. BW/BR/SW/SR/StartStop)
- Head world-orientation error vs source: **≤6.0° every clip** (was ~70-90°, the double head).
- Spine (torso) coronal: **0.0° every clip** (flat/upright).
- Neck coronal (source-driven head tilt): ≤30.2° (Neutral_BR peak; fidelity-preserving).
- Per-joint axial twist: ≤17.3° (cap 25° never binds → natural slerp distribution).
- Aggregate spine sagittal error vs source Hips→Neck total: ≤2.2° (S in aggregate).
The ingest fails the build if any clip's head error exceeds 12° or spine coronal exceeds 4°
(at-source regression guards). Test-side: `tests/body_motion_matching_test.gd` adds a
source-fidelity re-solve on the 4 vendored clips (<10°) plus DB-derived per-clip guards
(flat spine / no collapse / capped twist / bounded aggregate sagittal) and `bone_count==22`.

### Runtime coupling lifted
`body_rig.gd _apply_motion_matching` no longer overrides the upper body with the clean idle
frame; the full body is driven from the matched frame (restoring real mocap arm swing). The
distance-phased foot-lock still overrides the legs (feet planted, no skate; regression-
guarded by the existing suite). Dead `_idle_mm_frame` / `LEG_MM_BONES` removed. This
supersedes the render-side workaround in `docs/decisions/locomotion-upper-body-posture.md`.

## Recommended decision

Adopt approach (A): closed-form orientation-driven spline-IK, source world orientations
arc-slerped onto the corrected target chain, with coronal-bend and axial-twist DOF locks as
the joint limits and sagittal bend free-but-data-driven. Correct the inverted axial
topology, drive all 9 axial joints (bone_count → 22), keep the stored-quat format, add the
head-world + lateral-flat regression assertions, and lift the render-side upper-body
override once green. Resolve the two flagged thresholds/twist-policy forks with the user.
