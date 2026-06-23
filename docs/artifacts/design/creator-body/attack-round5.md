# Attack — creator+body SYNTHESIS v5 (round 5, hostile review)

Adversarial pass against `SYNTHESIS.md` (v5). Load-bearing claims re-checked against code/assets @ HEAD;
the design's own "verified/fixed/resolved" labels were NOT trusted. Acknowledged open risks with sound
plans (R2 baker, R5 belly cap, R6 budget constants, R3 per-eye sub-decision, R12 Quest) are NOT ranked as
flaws and are not relitigated except where their resolution plan is itself unsound.

Severity: **BLOCKER** = wrong/contradictory/infeasible, or a fix named without an executable method that
produces a bad result as-written. **MAJOR** = a real defect or a false load-bearing claim that forces
rework. **MINOR** = understated cost / imprecision / cleanup.

---

## BLOCKER

### B-A. The v5 B-1 mirror redesign breaks bilateral arm/leg sliders whenever the mirror toggle is OFF.

**Locus:** §1.3 (B-1 flow), §0 ("KEEP it for resolution, strip its mirror"), gate #10;
`region_sliders.gd:136-145`, `character_creator.gd:1142,1172,1209-1214,1235`,
`tests/body_region_sliders_test.gd:164-174`.

The design conflates two ORTHOGONAL concepts and routes both through one global toggle:

1. **Bilateral resolution** — one UI slider ↔ two anatomical modifiers (`armslegs/l-…` AND `armslegs/r-…`),
   driven *together, always*. This is a structural property of the control: there is no separate
   left-arm and right-arm slider in `GROUPS` (`region_sliders.gd:78-90` — only `l-upperarm-muscle` etc.),
   so the single slider MUST drive both arms to mean anything.
2. **Mirror toggle** — apply a *facial/regional* edit to the contralateral side, user-toggleable so a
   player can deliberately sculpt an asymmetric face.

These are independent. v5 collapses them: it strips the `r-` half from `resolve_full_names` (so a bilateral
stem now resolves to ONE full_name, `armslegs/l-…`) and routes the right arm SOLELY through the mirror twin
table. Consequence executed as written: **turn mirror OFF (to sculpt an asymmetric face) → every bilateral
arm/leg slider drives ONLY the left side.** The right arm silently diverges. The slider value label reads
`full_names[0]` only (`character_creator.gd:1172,1235`), so nothing in the UI signals the right arm fell
behind. There is no path to "symmetric arms + asymmetric face."

This directly violates the existing spec, which the project's own discipline says IS the spec
(`tests/body_region_sliders_test.gd:164-174`): test (4) asserts a bilateral stem resolves to **two**
full_names and "covers the LEFT and RIGHT upper-arm muscle modifiers" — UNCONDITIONALLY, with no mirror
concept anywhere. The design notes only that test :166 "is updated to expect one resolved full_name plus the
twin from the table," but does NOT acknowledge that this REDEFINES the bilateral-symmetry invariant to be
mirror-toggle-dependent. It also misses that the *other* resolution-consuming tests bind their behavior to
two-entry resolution: `_disp_field` builds the displacement field from ALL resolved names
(`:71-72`) and is used by the bipolar-sign test (`:140`) and the table-integrity binding count (`:92`);
under one-entry resolution those tests would silently drive only the left arm.

**Correct design (the rejected-but-better alternative the v5 reasoning skipped):** keep
`resolve_full_names` returning BOTH twins for a bilateral STEM (structural symmetry — independent of the
mirror toggle), AND route deliberate-asymmetry mirroring of *non-stem* edits (face/ear/cheek/sculpt) through
the twin table. Round-4's B-1 correctly found that retiring the function breaks resolution; v5 over-corrected
by stripping resolution's INHERENT bilateral expansion and folding it into the user toggle. The "exactly one
mirror path" goal is achievable without making bilateral anatomy controls hostage to the asymmetry toggle:
the bilateral STEM expansion is not a "mirror," it is the control's definition.

---

## MAJOR

### M-A. The §3 composed-field clamp does NOT share the normal-weld gather; the cost claim ("≈ the normal weld, marginal cost = per-base soft-clamp") is false. A NET-NEW per-base displacement gather is required on the per-drag hot path.

**Locus:** §3 (M-2 mechanism + cost), §3 "sharing the gather," R6 plan; `body_state.gd:649-676` (position
compose), `:690-715` (normal weld).

The normal-weld pass at `:702-715` accumulates **face normals** per base vertex
(`base_n[render_to_base[a]] += fn`, `:705-707`), then normalizes and scatters normals (`:709-715`). The
quantity gathered is the *face-normal sum*, not displacement. To clamp per-base displacement you must gather
`δ[i] = morphed[i] − base_pos[i]` per base vertex — a **different accumulation** over the render verts. You
cannot derive base displacement from accumulated base normals; the two passes only share the *index map*
`render_to_base[]`, not "the gather." The design's repeated claim that the clamp "shares the gather … so the
scatter is already paid by the normal pass's own scatter; the marginal cost is the per-base soft-clamp"
(§3 cost para, R6) is therefore wrong: the added per-drag-frame work is a **full new render→base gather of
displacement (n=14517)** + the per-base clamp + a **new scatter that re-applies the clamp factor to
`morphed`** (the normal pass's scatter writes NORMALS, not positions, `:714-715`). On the hot path the design
itself flags as the bottleneck (facts-r1 #5, every mouse-motion frame), this is a second full-mesh gather +
scatter, not "comparable to the per-base soft-clamp." The honest cost is roughly the position-compose pass
again, on top of §5.0's deferred tangent work. The "cost ≈ the normal weld (one base-reduced pass)"
headline understates it by a gather and a scatter. (This is the SAME class of error v5 corrected for the
tangent pass in M5 — a "cheap" full-mesh pass that isn't — re-introduced for the clamp.)

### M-B. The composed-field clamp bounds displacement MAGNITUDE; the diagnosis it claims to fix (body-reverify §4 faceting) is a GRADIENT/tessellation defect a magnitude clamp cannot guarantee. The "budgets = renderable range" claim is asserted, not mechanized.

**Locus:** §3.1 ("the §3 budgets ARE the working range, set so the full labeled range … produces a
silhouette the 14.5k mesh represents smoothly"), §3 (`B[v]` "keyed to local rest edge length"), gate #1 vs
gate #8; `docs/artifacts/diagnosis/body-reverify.md:53-71`.

body-reverify §4 states the extreme-stack faceting is **"a downstream symptom of #2 [unbounded sum] PLUS the
base tessellation density"** (`:70`) — explicitly two causes — and that at weight-150 stacks the SHADING is
smooth (normals correct) but the SILHOUETTE shows angular lobes (`:59-62`). Faceting is a function of the
*inter-vertex displacement gradient* (dihedral angle between adjacent faces), NOT per-vertex displacement
magnitude: two adjacent verts can each sit within their own `B[v]` budget and still produce a faceted edge
if the gradient between them is steep. A per-base **magnitude** clamp (`|δ'[v]| ≤ B[v]`, §3 step 2) does not
bound the dihedral.

The design's own structure proves the gap: gate #8 must use an **INDEPENDENT dihedral metric "independent of
the clamp's own budget"** (§8 #8, m-4) precisely because the budget does not directly bound faceting — and
v5 correctly calls v4's self-referential version tautological. But then the 10k-seed sweep (gate #1) that
"tunes and DEFENDS `B[v]`" asserts only (a) `|δ'[v]| ≤ B[v]`, (b) no self-intersection, (c) AABB
(§8 #1, `SYNTHESIS.md:767-772`) — it does **not** assert the dihedral/no-faceting. So `B[v]` is tuned to
prevent magnitude-overrun and self-intersection, never to prevent faceting; the dihedral gate is a separate
manual render-review (§8 #8 part (b)), not wired into the sweep. The claim that the budgets are "set so the
full labeled range produces a smooth silhouette" (§3.1) and that §3 "addresses the angular belly/thigh"
defect (§3.1, R10) is thus a hope, not a mechanism: nothing in the tuning loop closes on the faceting
metric, and §3.1 even concedes the SECOND cause (tessellation density at hands/feet) "the displacement clamp
does not address." The "no-monster guarantee = §3" and "legal range = renderable range" framing oversells a
magnitude clamp as a smoothness guarantee.

### M-C. The eye plan's CORE deliverable ("drive `gaze_dir` — net-new wiring to make the eyes look around") mischaracterizes the existing, WORKING look-direction mechanism; driving `gaze_dir` from the eye-bone forward is at best redundant and at worst fights the existing eye-bone skinning.

**Locus:** §5.2 CORE / M-1, R3 ("`gaze_dir` is unwired → net-new wiring … set the `gaze_dir` uniform each
frame from the eye bone's model-space forward"); `eye.gdshader:6-13,22,55-72`,
`scripts/body/face/face_rig.gd:33,103-104,256-258,293-300`, `scripts/body/face/gaze_rig.gd:7-9`,
`scripts/body/body_rig.gd:783-797` (proxy skinned).

The design's grep (`gaze_dir` empty in `scripts/`) proves only that nobody sets the SHADER UNIFORM — it does
NOT prove the eyes can't look around. The actual look-direction mechanism already exists and works:
`FaceRig._set_eye_look` rotates the `eye.L`/`eye.R` bones via `set_bone_pose_rotation`
(`face_rig.gd:256-258,293-300`), driven by `val_look_dir`; `gaze_rig.gd:7-9` documents the division of labor
explicitly — "where the FaceRig drives the EYE bones (val_look_dir), this [GazeRig] drives the
HEAD/NECK/CHEST bones." The eye proxy mesh is SKINNED to the skeleton (`body_rig.gd:795`,
`proxy_instance.skin = skin`), and `ProxyMorph` re-emits full vertex arrays incl. bone/weight channels on
each bake (`proxy_morph.gd:142-148`), so eye geometry — and its model-space normals — rotate with the eye
bone. The shader keys the iris off the **model-space surface NORMAL** vs `gaze_dir` (`eye.gdshader:56,60-65`).

So:
- The eyes ALREADY visually track when `val_look_dir` is set — by bone rotation moving the skinned eyeball
  (iris painted on it via the model-space normal). This is not "net-new wiring needed for the eyes to look
  around"; it is existing, working behavior the design omits.
- `gaze_dir` is a SEPARATE knob that selects the iris cap *within* the eyeball's own model frame. If you
  ALSO drive `gaze_dir` from the eye-bone forward while the bone is ALSO rotating the eyeball (and thus its
  normals), you double-count the rotation: the iris cap shifts on a surface whose normals already moved,
  producing a doubled/garbled gaze. Driving `gaze_dir` is coherent ONLY for a STATIC (un-rotating) eyeball
  where the iris must move without geometry — which is NOT the current rig (the eye bones rotate). The
  design picked the wrong seam: the look mechanism is the eye bone, not the shader uniform. R3's "CORE =
  wire bone gaze into `gaze_dir`" is unsound as stated and would need to first decide whether eye-bone
  rotation is retired in favor of shader-only gaze (a real either/or the design never surfaces).

*Caveat:* I confirmed eye-bone rotation and proxy skinning from code; I did not render the eye under a live
`val_look_dir` sweep to confirm the eyeball geometry visibly rotates — **would verify by** an
`xvfb-run` render of the face at `val_look_dir = (±0.5, 0)` and diffing the iris position. But the
provenance error stands regardless: the design treats a shader uniform as THE look mechanism when the rig
drives look via bones.

### M-D. M-2's seam-weld correctness argument has an unhandled conflict: coincident UV-split render verts can carry DIFFERENT stored deltas, so "gather render→base displacement, coincident splits collapse to one value" is ill-defined — and resolving it can itself crack the seam the clamp is meant to protect.

**Locus:** §3 step 1 ("coincident splits collapse to one base value"); `detail_library.gd:97-104`
(per-render-vertex `ri` deltas), `body_state.gd:664-676` (per-render-vertex compose),
`facts-round1.md:45-49` (tangents per-corner because split corners legitimately differ).

The delta library stores displacement per RENDER vertex (`ri`, `detail_library.gd:98,103`). A UV-seam base
vertex splits into ≥2 render verts; the records may include different `ri` deltas for the two splits (or only
one of them). facts-r1 #6 confirms the converter treats split corners as legitimately distinct
(per-corner tangents). So after compose, the two render verts of a seam can have **different** `morphed[i]`,
hence different `δ[i]`. §3 step 1 says "gather render→base displacement … coincident splits collapse to one
base value" without specifying the reduction (sum? mean? max-magnitude?) or acknowledging the conflict. If
the two splits genuinely differ and you average to one base `δ[v]`, then scatter back the *same* clamp
factor (step 3), you change the two splits by different absolute amounts only if you scale — but the design
scales by a per-base FACTOR (`B[v]·tanh(|δ|/B[v]) / |δ|`), and if the base `δ` used to compute the factor is
a reduced value that differs from each split's true `δ`, the post-clamp split positions can drift relative to
each other → the very seam crack §3 invokes the base-reduction to avoid. The normal weld escapes this because
a normal is a direction that is *intended* to be shared at a seam; a *position/displacement* at a seam is
NOT necessarily shared (split corners have distinct UVs and may have distinct deltas). The design imports the
weld's correctness argument into a domain (positions) where its premise (the quantity is shared at the seam)
does not hold. At minimum step 1's reduction is unspecified; at worst it cracks seams.

*Would verify by* checking, in `base_body_detail.bin`/proxy bin, whether any target's records include both
render-vert IDs of a known seam pair with unequal deltas — if yes (likely, given per-corner treatment), the
ill-definition is real.

---

## MINOR

### m-A. Tongue re-seating (m-6) is an ASSET RE-BAKE, not a runtime data tweak; cost understated.

**Locus:** §5.6 (m-6), R13; `proxy_morph.gd:4-7,20` (single shared `base_body_proxies.res`),
`tools/body_proxy_build.gd`. The fix re-derives the tongue surface's REST attach offset from the
mouth-cavity centroid. The proxy is one vendored `.res` built offline by `tools/body_proxy_build.gd`; moving
the tongue's rest verts means regenerating that asset (and the proxy detail library keyed to the global
vertex numbering), not editing a runtime field. The design calls it "a data/seating fix (the rest offset)"
and never names the re-bake. The surface-table selector mechanism itself (name→`[vert_offset,vert_count)`,
`proxy_morph.gd:28,46-49,66`) is correctly grounded.

### m-B. The B2 sculpt fix re-reads positions from the same `surface_get_arrays(0)` the build already uses; the "frozen NEUTRAL vs morphed" distinction is timing, not source — and the picker still ignores skeletal POSE (only scale/global-xf are handled).

**Locus:** §1.3 / §5.5 (B2), R9; `character_creator.gd:240-242` (build reads
`surface_get_arrays(0)[ARRAY_VERTEX]`), `:382-383` (`world_xf = skeleton.global_transform`,
`rest_positions = _glow_base_pos`). The fix is sound for morph (re-fetch after a bake yields morphed verts,
since `apply_morph_cpu` bakes from a preserved neutral into the live surface). But the picker transforms
rest positions only by `skeleton.global_transform` (incl. height scale) — it does NOT account for skinned
bone POSE. In the creator the body is presumably at rest pose so this is benign, but the design asserts the
fix makes "picking and locality act on the body the user sees" without flagging that a posed/animated body
(or future in-world sculpt) would still mis-pick. Honest scope is "morphed rest-pose body," not "the body
the user sees" in general.

### m-C. The glow ε world-space scale-correction (m-7) assumes height_scale() is the ONLY skeleton scaling and is uniform; not stated/verified.

**Locus:** §5.5 (m-7); `body_rig.gd:729-731` (`skeleton.scale = Vector3(s,s,s)` from `height_scale()`). The
correction `ε_world / height_scale()` is right IF the skeleton's only scale is the uniform height scale and
the overlay is a direct child of the skeleton with no intermediate scaled node. Both hold today
(`character_creator.gd:284` adds overlay to `_rig.skeleton`; `:729-731` is uniform). Stated as a fact it is
fine; flagged only because it silently depends on "no other scale in the chain," which a future
per-bone/non-uniform scale would break with no guard.

### m-D. "The only 'BVH' in the repo is a doc comment in `cpu_accel_picker.gd`" is imprecise.

**Locus:** §8 #1, R7; the repo also references BVH as the 100STYLE *motion-capture file format*
(`motion_db.gd:5`, `motion_ingest.gd:6,22,32`, `body_rig.gd:1270-1271`). The substantive claim — no
self-intersection BVH/spatial-hash COLLISION code exists, the picker is a uniform GRID
(`cpu_accel_picker.gd:10-15`) — is correct, so R7's "feature work to build" stands. Minor wording.

---

## Attacked and could NOT break (with the evidence)

- **m-3 picker rebuild driver** — verified the picker caches `_positions` (`cpu_accel_picker.gd:71`) and
  `mark_dirty()` only flips `_dirty` (`:64-65`), rebuilding from the STALE cache; the existing
  `_apply_state` `mark_dirty()` (`character_creator.gd:1270-1271`) is genuinely insufficient, so the
  "OWNER must re-fetch `surface_get_arrays(0)` and re-`build`" diagnosis is correct.
- **Tongue surface selector (m-6 mechanism)** — surface table with `name/vert_offset/vert_count` exists
  (`proxy_morph.gd:28,46-49,66`); name→range selection is unambiguous as claimed.
- **`present` flags / dead-control signal** — confirmed `count` is the live/dead signal (`detail_library.gd:93`),
  consistent with §0.
- **Determinism of the delta sum** — `keys.sort()` fixed-order reduction confirmed
  (`body_state.gd:670-673`); the clamp adds no min-reduction (v3's hazard genuinely removed).
- **Import per-scalar already clamped (m-1)** — `to_blend_weights`/`_project_modifiers` clamps confirmed at
  the cited lines; the "only composed stacking is unbounded on import" claim holds. (But the §3 composed
  clamp it relies on inherits M-A's cost error and M-B's faceting gap.)
- **R7 self-clip, R2 baker, R5 belly cap, R3 per-eye sub-decision, R12 Quest** — acknowledged open risks with
  bounded/sound plans; not ranked.
