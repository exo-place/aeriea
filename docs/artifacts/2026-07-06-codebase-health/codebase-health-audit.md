# Codebase-Health Audit — aeriea

Date: 2026-07-06. Repo: `/home/me/git/exoplace/aeriea` (Godot 4 + Rust/gdext + Nix).

This is a **factual record**, not marching orders. It consolidates six read-only
inventories run this session into one report, along the axes named in TODO thread 14. It
sizes the rot so a triage call is grounded; it does not prescribe fixes. Where fixes are
mentioned they are the assessment's *observations of highest leverage*, not directives.

**Provenance markers are preserved throughout:** `[MEASURED]` = grep/wc/ref-count actually
run; `[INFERRED]` = judgment read from headers/docs/naming, not exhaustively counted;
`[READ]` = quoted from a source file in this repo. **The external-contract confabulation
sites are marked EXPOSURE / unverified-assumption — they are NOT confirmed bugs.** Whether
those hardcoded external contracts are actually wrong is UNKNOWN without dumping the real
artifact; what is established is that they are unverified-in-repo and fail silently on a
miss.

---

## Overall verdict

**The codebase is largely clean and real; the rot is localized.** There is essentially no
garbage, no classic dead code, no half-built scaffolding. The logic/data/sim layers are
behavior-tested to an unusually high degree. The genuine problems cluster in a few named
places: an unverified visual layer, a handful of silent-on-miss external-contract
assumptions, and one unfinished substrate migration.

## Summary table (one row per axis)

| Axis | Severity | One-line verdict |
|---|---|---|
| Garbage / cruft / dead files | **LOW** | Zero classic garbage; only real waste is ~35 MB `.git` history bloat from re-committing regenerable binaries (a deliberate determinism tradeoff). |
| Dead / obsolete code | **LOW–MED** | No classic dead code; ~719 LOC of runtime-dead-but-retained experiment (cxg), plus superseded-kept-as-oracle and launcher-orphaned test scenes — all documented, all a user retire/keep call. |
| Migrations & duplication | **MED** | One flagship unfinished migration (TF substrates); one deliberate parity-oracle retention; one stale TODO status; ~5.3k LOC of deliberate parallel substrate machinery (consolidation opportunity, not a defect). |
| Features claimed-vs-real | **LOW–MED** | Code is largely real, not scaffolded. Gaps are stale ledger numbers, untested render seams, a couple of design-level semantic problems, and the live duplicate TF system. |
| Test quality | **MED–HIGH** | ~85% behavior/correctness on the logic layer — but **~0% of assertions inspect a rendered frame**; the entire visual layer is unverified by construction. |
| External-contract confabulation | **MED–HIGH (EXPOSURE)** | 11 sites assert external-artifact facts from priors; worst (`bdcc2_bone_map.gd`) silently drops on miss with NO correctness guard. Not confirmed wrong — confirmed unverified + silent. |

## The two headline problems

**HEADLINE 1 — the visual layer is unverified by construction.** [INFERRED, high
confidence] Essentially **0% of the 1,147 assertion sites inspect a rendered frame.** Every
"behavior" assertion is over data structures, math, bone/quaternion angles, UVs, node/property
state, or serialized bytes — never over pixels. `creator_phasee_test.gd:2` states it outright:
"aesthetics are USER-judged from the render harness." A body could ship with inverted normals,
z-fighting, a wrong material, or the doubled-head cross-seam defect and every suite stays
green. **This is how the animation-posture defects shipped** — the suite checked "root angle
< 25°" and that a bone moves, but never that the head wasn't folded to the chest. The
mandatory manual playtest is the ONLY line of defense for every visual defect class.

**HEADLINE 2 — 11 external-contract confabulation landmines, silent-drop-on-miss.** [READ]
Code that asserts a fact about an external artifact (skeleton topology, BVH conventions,
units) that should have been read from the artifact but appears written from priors. The
signature of the precedent bug (a bone-map that silently dropped spine joints) recurs. The
**worst is `scripts/body/bdcc2_bone_map.gd`** (+ its consumer `tools/bdcc2_clip_ingest.gd`):
it has **NO resolved-count guard** — any mapped bone name that misses silently retargets to
identity, dropping that joint from the clip with zero signal. EXPOSURE, not a confirmed bug:
whether the names are wrong is UNKNOWN without a GLB skeleton dump.

**And a foregrounded hazard — the unfinished TF-substrate migration.** [MEASURED] A new
substrate (`scripts/sim/tf/`, 1,008 LOC) is consumed by **exactly one thing — its own test**.
The old substrate (`scripts/body/tf/`, 4,354 LOC — **4.3× the LOC**) carries **100% of live
consumers** (character creator, both launcher TF tools, 5 test suites). By count and by
consumer-share the old reads as canonical — precisely the CLAUDE.md "old patterns that
dominate by count get read as canonical" hazard. The migration is neither finished nor fenced.

---

## Axis 1 — Garbage / cruft / dead files — LOW

Source: `garbage-files.md`.

- [MEASURED] 716 tracked files, 76.2 MB tracked payload. **Classic garbage found: ZERO** —
  no `.bak/.tmp/.old/.orig/.swp/*~/.log/.DS_Store`, no editor junk, committed screenshots,
  zips, or stray build outputs. Orphaned assets: 0 (every `.import` has its source; every
  `.uid` its `.gd`). `.gitignore` is comprehensive.
- **The one real finding — `.git` history bloat from re-committed built binaries.** [MEASURED]
  The large tracked files are derived/generated artifacts committed on purpose (tool headers
  confirm regenerability). Because they are regenerable AND change over time, re-commits
  inflate history:
  - `assets/body/base_body_detail.bin`: 3 historical versions of 35.5 + 34.2 + 16.2 MB
    (~86 MB of history for one file; current on-disk 35.5 MB).
  - `assets/body/base_body.res`: ~10 historical versions (1.3–3.1 MB each); current 1.47 MB.
  - `assets/body/locomotion_mm.res`: 3 versions (2.9–3.6 MB); current 3.59 MB.
  - [INFERRED] These re-commits account for roughly the ~35 MB gap between the 76 MB working
    payload and the 111 MB `.git`.
- [INFERRED] Judgment: a deliberate determinism tradeoff (byte-identical rebuild, runtime
  avoids the pipeline). As tracked files, arguably fine; as history, the only meaningful
  bloat. Options (owner's call): Git LFS for `*.bin`/`*.res`, or stop committing regenerable
  artifacts. Not auto-fixable in a read-only pass and not clearly "junk."
- Minor cruft: 4 `.gitkeep` files, 3 of which are vestigial (dirs now populated). ~0 bytes,
  harmless.
- Explicitly NOT junk (checked): `experiments/`, `vendor/` (licensed CC0/CC-BY, referenced),
  `docs/artifacts/`, project tooling, root docs.

## Axis 2 — Dead / obsolete code — LOW–MED

Source: `dead-code.md`. Repo GDScript total ~28,309 LOC. Method: reference-counting via grep
(class_name refs + `res://…gd` path refs + scene ExtResource paths); comment-only mentions
excluded.

- **No classic dead code.** [MEASURED] Zero `if false`/disabled branches; no orphaned classes
  with zero references anywhere; the large `#` blocks in `body_rig.gd` (~1490–1500, ~1710) are
  design-rationale prose, not commented-out code. The obsolescence here is **superseded
  implementations coexisting with replacements**, not litter.
- **CxG prose realizer — runtime-dead superseded experiment (CONFIDENT).** [MEASURED]
  `scripts/text/cxg_realizer.gd` (488 LOC, `CxgRealizer`) is referenced only by
  `tests/cxg_realizer_test.gd` (144) + `tools/cxg_playtest.gd` (87, not in launcher). No
  runtime/scene/launcher references it. Superseded at runtime by `scripts/text/npc_realizer.gd`
  (`NpcRealizer`, wired into the "Text Sandbox" launcher mode). Total dead surface if retired:
  **~719 LOC.** Intentionally kept as a documented experiment — user's call to retire.
- **PlayerController — superseded baseline kept as a test oracle (PROBABLY-keep).** [MEASURED]
  `scripts/player_controller.gd` (1,042 LOC, largest single script) is instantiated only by
  `scenes/test_level_imperative.tscn`, loaded only by `tests/movement_behavior_test.gd`. The
  live path is `InterpretedPlayer`. It is the imperative leg of a deliberate 3-way equivalence
  triad (imperative / interpreted / compiled) that `movement_behavior_test` asserts stay
  identical. Not dead while the oracle is valued. Companion fixtures
  `test_level_imperative.tscn` + `test_level_compiled.tscn` are intentional.
- **interaction_sandbox.tscn — launcher-orphaned test-only 3D scene.** [MEASURED]
  `scenes/interaction_sandbox.tscn` (404 LOC) + its 9 interactable scripts (Jug/Lever/Valve/
  Spout/Pedestal/Gate/GoalBeacon/GrabbableBox/PressurePlate, ~533 LOC) are reachable only via
  `tests/interaction_behavior_test.gd` — NOT in `launcher.gd` MODES. ~937 LOC reachable only
  via test. The affordance *substrate* itself is NOT dead (driven headlessly by
  `text_sandbox.gd`); only the 3D demo scene + physical interactables are orphaned.
  Probably-intentional; worth a user decision.
- Cross-checks came back clean: all 70+ `class_name` declarations reference-counted; no
  `if false`/`if 0`; no `func _unused`/`const OLD_` markers.

## Axis 3 — Migrations & duplication — MED

Source: `migrations-dup.md`. `[MEASURED]` = grep/wc/ref-count; `[INFERRED]` = read from
headers/TODO/docs.

| # | Item | Old / A side | New / B side | Dominance | Type |
|---|---|---|---|---|---|
| A1 | TF substrates | `body/tf` 4,354 LOC, all live consumers + 5 tests | `sim/tf` 1,008 LOC, 1 test only | old 4.3× LOC, ~100% consumers | **migration, barely begun** |
| A2 | Player controller | `player_controller` 1,042 LOC, 1 scene | `interpreted_player` 490 LOC, 3 scenes + settings | new is live | migration done, old kept as parity oracle |
| A3 | Interaction lift | (TODO says hand-wired only) | full kit+interp+compiler present | code ahead of status | stale TODO, no code work |
| B1 | Parallel substrate engines | movement ~2,845 LOC | interaction ~2,485 LOC | mirror, 0 shared code | genuine dup, deliberate |
| B2 | Deterministic RNGs | `DetRng` 61 (body/tf) | `TFRng` 46 (sim/tf) | one each | dup tied to A1 |

- **A1 — the flagship half-migration.** [MEASURED] Old `scripts/body/tf/`: 8 files, 4,354 LOC
  (tf_describe 1509, tf_library 909, tf_applier 592, tf_content 414, tf_measure 355,
  body_graph 307, tf_holder 222, tf_validator 46); all real game/tool consumers live here
  (character_creator chain, `tools/tf_audit.gd`, `tools/tf_play.gd` — both launcher-registered
  — and 5 test files). New `scripts/sim/tf/`: 6 files, 1,008 LOC; consumers = exactly ONE,
  `tests/tf_substrate_test.gd`; zero game surfaces, zero tools. [INFERRED, TODO thread 7]
  sim/tf "eventually supersedes" the body/tf interim MVP; design in
  `docs/decisions/body-transformation-substrate.md`. Both touched recently (body/tf 2026-06-28,
  sim/tf 2026-07-04) so neither is abandoned. **Needs finishing (migrate consumers) or explicit
  legacy-fencing of body/tf.** Naming collision worsens it: both dirs have a `tf_library.gd`
  (only sim/tf's has `class_name TFLibrary`; body/tf's is preload-only — conceptually confusing,
  no hard collision). [INFERRED] Doc-layer echo: 8 transformation/substrate decision docs
  coexist; `dynamical-transformation.md` is an older unreconciled model (flagged, out of code
  lane).
- **A2 — deliberate parity-oracle retention, not accidental.** [INFERRED] valve.gd's comment:
  the old imperative controller is "kept as parity oracle." A 1,042-LOC baseline that could
  read as canonical to a fresh reader; worth an explicit legacy/parity-oracle header marker if
  not already prominent. Low-risk.
- **A3 — stale status, not stale code.** [MEASURED] Full data-driven interaction apparatus
  exists (kit 506 + interpreter 574 + compiler 852 + compiled 553 + host 319 + interactor 252);
  prop scripts are pure render/parity shims. TODO thread 2 says "not lifted to data yet — only
  the hand-wired prototype exists," which contradicts the code (`interactor.gd` header: "no
  longer a hand-wired verb dispatcher… all verb/guard/effect logic lives in sandbox.kit.json +
  interpreter"). **The fix is updating TODO thread 2, not code.**
- **B1 — genuine structural duplication, currently deliberate.** [MEASURED] Two independent
  implementations of the identical "kit + deterministic interpreter + GDScript compiler +
  golden-trace equivalence" pattern (movement ~2,845 LOC, interaction ~2,485 LOC), sharing ZERO
  code (`interaction_compiler` references `MovementCompiler` only in a comment). ~5.3k LOC of
  parallel machinery — the biggest consolidation opportunity if a third substrate arrives. Not
  urgent (each works, both golden-trace-verified).
- **B2 — two deterministic RNGs**, one per TF substrate; resolves naturally when A1 finishes.
- Non-findings ruled out: pickers (abstract base + 2 Strategy backends), compiled movement/
  interaction paths (golden-trace dual paths, not dead), prop shims (no logic dup).

## Axis 4 — Features claimed-vs-real — LOW–MED

Source: `unverified-features.md`. 21 features assessed (20 "Not green" in `docs/FEATURES.md`
+ 1 implied-by-code: the `sim/tf` substrate).

- **Headline:** the gap is smaller than a raw "all unverified" ledger implies — **the code is
  largely real, not scaffolded.** Runtime artifacts are present and substantial (35 MB
  morph-delta bin, 3.5 MB motion DB, 1.4 MB base mesh, 291-entry modifier registry). No
  `pass`-only stubs, no "not implemented" returns anywhere audited. "Not green" mostly means
  **"built and behavior-tested but not user-certified and not runtime-playtested,"** NOT
  "half-built."
- **Biggest claimed-vs-real gaps (ranked):**
  1. **Duplicate TF system (feat 20/21).** The A1 split, restated: shipped MVP drives all
     game/tool scenes; `sim/tf` unwired. Intentional dual-track, NOT a botched migration — but
     a live duplicate with near-identical names, both "green in tests," the exact context-poison
     smell the rules warn about. Neither finished nor fenced.
  2. **Retargeted clips ledger misdescription (feat 4, verdict c).** Ledger blames "snapping in
     the parkour sandbox," but there IS no parkour clip system — clips are idles/gestures/sit.
     Real defect: corrupt clip-opening-frame retarget, mitigated by trimming not fixed. Ledger
     points at the wrong place.
  3. **Movement "known-broken" is stale (feat 6).** All four listed broken subparts (player
     render, orientation PI-flip, FP-camera clipping, can't-leave-scene) have explicit
     documented code now. The true remaining unknown is purely whether it LOOKS right at runtime
     (untested render seam) — a playtest question, not a code gap.
  4. **Text/NPC dual affect model (feat 8).** TWO independent, unreconciled affect computations
     feed prose vs the face line; they can contradict, and the seam is untested. Plus the
     baked-in "greeting→arousal" semantic conflation (confirmed read-from-code: arousal channel
     blends memory-mood + lust, so a plain greeting raises "arousal").
  5. **CxG realizer not integrated (feat 18).** A genuinely substantial CxG engine exercising
     exactly one authored scene beat; not called by the shipping sandbox. Impressive machinery,
     near-zero product surface.
  6. **Stale numeric claims (feats 13/19/20).** Sliders 56→actually 62; TF-MVP assertions
     34→actually 42; TF library 55→actually 58. All understatements (code grew past docs);
     harmless, but they show the ledger is not being reconciled to code.
- **Untested / runtime-only seams (need a playtest):** movement player-body render + FP camera;
  hair geometry appearance; locomotion forward-vs-back clip selection (facing-sign, see Axis 6
  RANK 7); GPU picker precision (test tolerance ≥70% only); the text/face-vs-prose affect
  divergence.

## Axis 5 — Test quality — MED–HIGH

Source: `test-quality.md`. 49 suites in `tests/run.sh`, ~14,200 lines, **1,147 assertion
sites** [MEASURED, `grep -cP '\b(_ok|_assert)\('`].

- **Existence-vs-behavior proportion** [MEASURED, automated bucket of 1,106 classified sites]:
  behavior/quality/threshold/ordering/determinism 688 (62%); equality/state-transition
  (round-trip correctness) 253 (23%); pure existence-only 165 (15%). Folding the correctness
  bucket in: **~85% behavior/correctness, ~15% pure existence** — an unusually behavior-heavy
  suite for the LOGIC / DATA / SIM layers.
- **THE dominating caveat (see HEADLINE 1):** [INFERRED, high confidence] **~0% of assertions
  inspect a rendered frame.** The 85% figure describes the logic layer; the render layer is ~0%
  covered. The visual/aesthetic surface is delegated to manual playtest by construction.
- Strong behavior/regression suites (for balance): `body_locomotion_test` (CPU linear-blend-skin
  reference proves a bone deforms the mesh; anatomical-landmark UV check; idle-is-NOT-bind-pose —
  the fold-to-chest lesson encoded), `body_no_monster_test` (300 seeded bodies, p99.5 faceting
  band <5°), `golden_trace_test` / `interaction_golden_trace_test` (tick-by-tick interp-vs-
  compiled-vs-repeat), `movement_behavior_test` (1,473 lines, real input pipeline),
  `cxg_realizer_test` (500-seed byte-identity + content-gate semantics), `creator_history_test`
  (undo/redo/branch DAG). No suite is a pure node-exists smoke test.
- Anti-truncation guard in `run.sh` (~line 120) is meaningful and correctly reasoned: a missing
  `=== RESULTS: N passed, M failed ===` line is treated as TRUNCATED/FAIL.
- **Suites giving the falsest sense of security (ranked):**
  1. **The whole VISUAL layer (structural, by construction)** — largest false-security zone;
     spans the most user-facing surface; honest (headers say so), mitigated ONLY by manual
     playtest.
  2. **`text_slice_test.gd`** — asserts describe_npc is non-empty, varies, is deterministic —
     but NEVER that the prose reads correctly (grammar, no placeholder, no dev-note/em-dash
     aside). A broken or placeholder-leaking string passes. Highest-risk non-visual gap.
  3. **`launcher_test.gd`** — pure mechanism/existence; does not exercise mouse-capture or
     rendered content. Shallowest, low stakes.
  4. **`body_proxy_test.gd`** — "seven pieces present" + exact tri counts; nothing about
     positioning/orientation/attachment (render-visible).
  5. **`body_modifier_registry_test.gd`** — 291 parse + partition invariants; nothing about
     whether a modifier produces a sensible deformation.
- **Biggest coverage gaps:** rendered-frame assertions (none anywhere); UI on-screen layout
  (only `creator_phasee` does a rect-intersection check); generated-text well-formedness (never
  asserted); SFW/NSFW rendering toggle (no suite named for it — a north-star system);
  `launcher` mouse-capture path.

## Axis 6 — External-contract confabulation — MED–HIGH (EXPOSURE, not confirmed bugs)

Source: `confabulation.md`. Lens: code that asserts a fact about an external artifact (dataset
layout, skeleton topology, coord/unit/euler conventions) that should have been READ from the
artifact but appears written from priors or is self-admitted-unverified. **These are marked
EXPOSURE / unverified-assumption. Whether the assumptions are actually wrong is UNKNOWN without
dumping the real artifact.** What is established: they are unverified-in-repo and most fail
silently on a miss. Suspect sites: 8 ranked + 3 lower-noted = **11**.

- **RANK 1 — `scripts/body/bdcc2_bone_map.gd:32-83` + consumer `tools/bdcc2_clip_ingest.gd:176-184`
  — HIGHEST.** [READ] `MAP` hardcodes BDCC2 anim-rig bone names (`hips, waist, chest, upper_chest,
  neck, shoulder.L, upper_arm.L, …`). Header records the author was already burned once (the
  DEF-* prior was wrong; this is the correction) — a SECOND-generation guess with no in-repo
  evidence the corrected names were verified against the actual GLB. SPINE MAP is the exact
  precedent pattern (3 BDCC2 torso joints onto MH spine04/spine02/spine01, skipping
  spine05/spine03). The consumer **SILENTLY DROPS on any name miss** (`if bi < 0:
  g_rel[tb] = Quaternion.IDENTITY; continue`) — **no resolved-vs-expected count, no push_error,
  no build failure.** Unlike the motion_ingest path, THIS path has NO correctness guard at all.
  Load-bearing: the entire BDCC2 gesture/idle clip library. Mechanism-unverified-and-silent:
  HIGH [READ]. Names actually wrong: UNKNOWN [INFER] — needs a GLB skeleton dump.
- **RANK 2 — `tools/bdcc2_clip_ingest.gd:196-204` — MED-HIGH.** [READ] Root forced to identity
  on the asserted claim "BDCC2 binds facing -Z." If BDCC2 actually binds +Z (or is Z-up
  pre-import-fixup), children expressed relative to the de-yawed root inherit a tilted frame.
  No in-repo verification.
- **RANK 3 — `tools/motion_ingest.gd:77-103` (`BONE_MAP`), resolve `522-543` — MED.** [READ]
  Hardcoded 100STYLE/BVH joint-name candidates; resolve loop silently leaves a bone unmapped if
  none match — same silent-partial mechanism. BUT this path has a real end-to-end guard: `_run()`
  fails the build if `head_err_max > 12°` or `spine_cor_max > 4°` (lines 318-325). Axial chain
  effectively verified-by-guard; **arms/legs/feet are NOT under the guard** and could silently
  degrade.
- **RANK 4 — `tools/motion_ingest.gd:197-213` — MED.** [READ] `AXIAL_ARC` / `SRC_SPINE_SAMPLES`
  "measured from both rigs (see the decision doc's arc tables)." Cannot confirm from code whether
  "measured" means measured-from-artifact or estimated. head_err guard constrains the endpoint;
  interior spine joints looser.
- **RANK 5 — `tools/motion_ingest.gd:855-862` (`_local_pose_frame`) — MED.** [READ] Three
  external conventions asserted at once: BVH axis mapping X→RIGHT/Y→UP/Z→BACK (the Z-sign is a
  handedness call), rotation composition order (right-multiply intrinsic assumed to match the
  100STYLE exporter), no per-joint non-standard channel handling. Gross inversion would trip the
  guard; subtle limb sign/order errors may not.
- **RANK 6 — `tools/motion_ingest.gd:590,596,52-53,488` + `scripts/body/motion_matcher.gd:122,37`
  — MED.** [READ] Asserts BVH translations are in cm (`* 0.01`). Hardcodes source at 60 fps
  (`FRAME_STRIDE := 4`) while `_parse_bvh` DOES read the real `Frame Time:` (line 494) but the
  retarget/feature path IGNORES it. Papered over by `goal_speed_scale := 0.13`, a fudge
  "derived from the DB distribution" — a smell that the units contract is not cleanly pinned.
  Features are relative + z-normalized, which absorbs a global scale error.
- **RANK 7 — `scripts/body/motion_matcher.gd:123-129` — MED (self-flagged open).** [READ] An
  EXPLICITLY LOGGED unresolved convention mismatch: the retargeted 100STYLE facing frame has
  FORWARD = -z ("verified against walk vs walk_back clip distributions") while the caller's
  local_vel uses +z = forward; "reconciling the sign convention … is a tuning pass." Author-
  acknowledged; forward/back clip selection is knowingly unreliable. (Also tracked as TODO
  threads 9-residual and 12-adjacent.)
- **RANK 8 — `tools/motion_ingest.gd:682,819` — LOW-MED.** [READ] `get_euler(EULER_ORDER_YXZ)`
  asserted to cleanly separate anatomical sagittal/twist/coronal for this rig's bone-local axes.
  Consistent-by-guard; assumed axis-semantics onto the external rig.
- **Lower / noted:** `scripts/body/part_library.gd:76-120+` (hardcoded BDCC2 GLB filenames +
  `attach_bone` + magic offsets; missing GLBs skip at runtime — softer than silent-identity;
  cosmetic-layer LOW). Contrast — the GOOD pattern: `tools/body_converter.gd:37-38`
  (`MH_TO_METERS := 0.1` justified by measuring the actual OBJ span) and
  `scripts/body/body_rig.gd:411-415` (LBS bind derived from the converter's real parse) are
  read-from-artifact derivations, not confabulation.
- **Summary:** the precedent bug's exact signature (hardcoded external map + silent drop, no
  validation) recurs most dangerously at RANK 1, which has NO guard. RANK 3-6 sit behind a
  partial head-error build guard that catches gross errors but not subtle limb/units drift.
  RANK 7 is author-acknowledged and open.

---

## What the assessment surfaces as highest-leverage (observation, not directive)

These are the fixes the assessment repeatedly points at; the call on whether/when to do them
is the user's.

1. **Render-truthful test gates.** The single largest structural gap: nothing in the suite
   asserts on a rendered frame, which is how the posture defects shipped. A gate that asserts
   composed/rendered posture (or captures a viewport golden) would let the codebase report its
   own visual regressions.
2. **Loud guards on silent-drop external-contract maps.** A resolved-vs-expected count +
   `push_error`/build-failure on `bdcc2_bone_map.gd` (RANK 1, which has none) would convert the
   worst EXPOSURE into a loud failure. Validating the hardcoded names against a dumped real
   skeleton would close the underlying question.
3. **Finish or fence the TF migration (A1).** Either migrate consumers onto `sim/tf` or mark
   `scripts/body/tf/` explicitly legacy, so the 4.3×-dominant old substrate stops reading as
   canonical.

## Provenance & confidence

- Garbage, dead-code, migration, and confabulation site counts: [MEASURED] / [READ] from the
  actual files — high confidence.
- Assertion counts and the 62/23/15 bucket: [MEASURED] (grep/sed over all 49 suites), high.
- The ~85% behavioral and ~0% render-frame figures: [INFERRED] from deep-reading ~15 suites +
  scanning all headers — high confidence on direction, ±5% on the behavioral number.
- The confabulation sites are **EXPOSURE / unverified-assumption**: the *mechanism* (unverified
  + silent) is [READ] and high-confidence; whether any specific hardcoded contract is actually
  wrong is [INFER] and UNKNOWN without dumping the external artifact.
