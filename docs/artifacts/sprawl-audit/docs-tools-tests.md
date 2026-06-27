# Sprawl & model-amnesia audit — docs / tools / tests

Date: 2026-06-28. Scope: `docs/`, `tools/`, `tests/`. Audit only — nothing deleted, nothing committed.

Method: read decision-doc headers/status lines, cross-referenced doc claims against actual `scripts/` implementation and `tests/run.sh` wiring, parse-checked every `tools/*.gd` one-off harness under Godot 4.6.

---

## 1. docs/decisions/ — supersession, contradiction, amnesia

### 1.1 SUPERSEDED text-gen docs (explicit, by their successor's own words) — severity: MEDIUM (cruft, low-risk but actively misleading)

`docs/decisions/text-generation-architecture.md` lines 25–28 state verbatim:

> This doc **SUPERSEDES the load-bearing foundations of** `docs/decisions/prose-generation.md`, `docs/decisions/npc-mind-and-language.md`, and `docs/decisions/semantic-layer.md` (they remain in the tree as historical record; new work is not built on their foundations), **and REPLACES the prior BDCC-based draft of this file.**

The three named docs (`prose-generation.md` 54.8 KB, `npc-mind-and-language.md`, `semantic-layer.md`) carry NO banner saying they are superseded. A reader opening `prose-generation.md` (still labelled "FOUNDATIONAL R&D DIRECTION") has no signal its foundation was discarded. This is classic model-amnesia surface: the supersession is recorded in the successor but not back-annotated onto the superseded docs.
- **Recommendation:** add a one-line "SUPERSEDED by text-generation-architecture.md (foundations discarded)" banner to the top of all three. Do not delete — text-generation-architecture.md relies on them as historical record. Archive-by-banner, not removal.

### 1.2 BDCC-port contradiction: doc condemns code that still exists — severity: HIGH (active contradiction doc↔code)

`text-generation-architecture.md` §2 ("Corrected failure diagnosis") condemns the BDCC2 affect ports as the root process-sin: `scripts/sim/mood.gd`, `scripts/sim/memory.gd`, `scripts/sim/relationship.gd` ("mood.gd:59 turns a greet into a rising arousal scalar … which prose-generation.md had already forbidden"). **All three files still exist on master** (`scripts/sim/mood.gd`, `memory.gd`, `relationship.gd`, plus `mood_values.gd`, `memory_defs.gd`) and are still exercised by live, run.sh-wired suites `memory_test`, `relationship_mood_test`, `maren_history_test`. So the canonical decision doc says "this was the mistake, ignore aeriea's design" while the mistake code remains wired into the green test path. The migration the doc implies was never finished (fence-what-you-can't-finish violation).
- **Recommendation:** either (a) explicitly fence the three sim ports as legacy with a header comment pointing at text-generation-architecture.md §2, or (b) if the text-gen rebuild has not started, leave code but add a TODO/note so the next session doesn't read the ported scalar-affect model as canonical and copy it forward. Severity HIGH because it is exactly the "old pattern read as canonical" trap CLAUDE.md warns about.

### 1.3 TF docs describe an UNIMPLEMENTED model as design-only while it is in fact BUILT — severity: HIGH (model amnesia, both directions)

Three TF design docs and the implementation disagree about what exists:

- `transformation-system.md` — status "Design pass — no code." But the MVP IS built (`scripts/body/tf/` — body_graph, tf_applier, tf_holder, tf_describe, tf_validator, tf_content) and FEATURES.md lists it as "built". The doc was never updated post-build. (It does correctly self-describe as superseding "the prior flat-parts version of this doc" — good internal hygiene there.)
- `compound-parts-and-fluids.md` — status line 4: "**Design pass — no code yet.**" But fluids ARE implemented: `tf_fluids_test` is wired into run.sh, and `fluid` handling is present across `body_graph.gd`, `tf_applier.gd`, `tf_describe.gd`, `tf_content.gd`, `tf_holder.gd`, `tf_library.gd`. The doc's central deliverable shipped; the status was never flipped.
- `dynamical-transformation.md` — status "Design pass — no code yet" (lines 3, 61). Yet `tf_measure.gd` exists and `tf_size_test` (magnitude/size transitions, the doc's core "driven TRANSITION / magnitude continuous" idea) is wired and passing. Partially built, status says zero.

These three are the worst model-amnesia cluster: docs labelled "no code yet, awaits user approval" describing systems that are already on master with passing suites. A future session reading these will either rebuild what exists or treat built behavior as un-approved.
- **Recommendation:** update each status line to reflect what shipped vs. what is still deferred (the docs do contain honest "deferred per design" lists — those parts are fine). Reconcile the "awaits user express approval" language against the fact that code landed. Do NOT delete; these are the live design of an active system. Highest-priority cleanup.

### 1.4 tf_play vs tf_playtest harness reference drift — severity: LOW

`transformation-system.md` and FEATURES.md cite the self-playtest harness as `tools/tf_playtest.tscn`. But `compound-parts-and-fluids.md:265` and `dynamical-transformation.md:963` cite `tools/tf_play.gd`. Both tools exist; `tf_play.gd` (31 KB, interactive live driver, dated Jun 28) is the current sandbox, `tf_playtest.gd` (5 KB headless sequence, Jun 27) is the older one. FEATURES.md points at the stale one.
- **Recommendation:** decide which is canonical (tf_play is newer/active), update FEATURES.md + transformation-system.md to match, retire tf_playtest if subsumed.

### 1.5 Creator/body doc proliferation — severity: MEDIUM (overlap, not contradiction)

Body/creator design is spread across at least 5 large docs with overlapping scope: `body-parameterization.md` (61 KB), `character-creator-and-body.md` (61 KB), `character-creator-ux.md` (37 KB), `body-and-locomotion-slice.md` (42 KB), `procedural-body-and-animation.md`. `body-parameterization.md` says it "supersedes" an earlier overhaul; `character-creator-and-body.md` re-decides the editing model and cap model. They don't flatly contradict but there is no index of which is authoritative for which sub-decision, and the creator is now SHELVED (per creator-saga). A reader cannot tell which doc is live.
- **Recommendation:** add a short "creator docs map / which-is-authoritative" note (could live atop character-creator-and-body.md), and flag the whole cluster as governing a SHELVED surface. Merge candidates: body-and-locomotion-slice.md + procedural-body-and-animation.md (early Jun-3 R&D, largely realized or superseded). Not urgent given the shelve.

### 1.6 Unbuilt-but-fine substrate/bdcc2 docs — severity: NONE (correctly labelled)

`substrate-foundations.md`, `substrate-core-design.md`, `bdcc2-integration-plan.md`, `bdcc2-mining-backlog.md` are all honestly status-flagged "not frozen / pending validation / not yet implemented", and indeed no `scripts/substrate*` exists. These are clean design-only docs — not amnesia. Leave as-is.

---

## 2. docs/artifacts/ — scratch vs keep

- **creator-saga/** (SESSION-RECORD.md, DEFECT-COMPENDIUM.md) — KEEP. Durable handoff records; SESSION-RECORD explicitly documents the creator shelve and meta-learnings. High value as the "why" for §1.5.
- **text-gen-design/** (~22 files: candidates A–E, grammar candidates A–D, judges, judge2s, refs) — KEEP. These are the design-it-twice evidence base that text-generation-architecture.md cites as load-bearing. Deleting them would break that doc's "every claim grounded in those artifacts" promise.
- **substrate-design/** (5 candidate files) — KEEP; cited by substrate-core-design.md.
- **design/creator-body/** — **attack-round1 … attack-round15** (15 rounds) + facts/redteam/SYNTHESIS. SYNTHESIS is the keeper; the 15 intermediate attack/facts rounds are spent scaffolding for a now-SHELVED surface. STALE CRUFT. **design/creator-ux/** similarly: attack-round1..3 + SYNTHESIS — keep SYNTHESIS, rounds are spent.
  - **Recommendation:** keep SYNTHESIS.md from each; the per-round attack/facts files can be archived or deleted (low value, shelved surface). Severity LOW.
- **diagnosis/** — playtest diagnoses + `*-reverify.md` files, all dated Jun 23, all for the now-SHELVED creator/body/launcher. Untracked PNGs present (see below). These are point-in-time playtest evidence for a shelved surface — STALE.
  - **Recommendation:** archive the diagnosis/ set; it pertains to shelved work. Keep movement-backlog.md if movement is still live. Severity LOW.
- **Untracked artifact files (git status):** the diagnosis PNGs `_body_with_hair.png(.import)`, `_face_3q_nohair.png(.import)`, `fp_view.png(.import)`, `tp_front.png(.import)`, `tp_walkdir.png(.import)` are untracked scratch render output sitting in the tracked tree. Per CLAUDE.md relay discipline, ephemeral relay scratch should stay OUT of the tracked tree.
  - **Recommendation:** gitignore or delete these PNGs; they are throwaway diagnosis renders for shelved work. Severity LOW.

---

## 3. tools/ — dead/broken one-offs

### 3.1 BROKEN: tools/phased_render.gd — severity: HIGH (confirmed parse error, fails to load)

CONFIRMED. `var bs: BodyState` declared at line 38, then `var bs = _creator.get("_body_state")` re-declared at line 82 in the same function (`_run`). Godot 4.6 parse output:
```
SCRIPT ERROR: Parse Error: There is already a variable named "bs" declared in this scope.
  at: GDScript::reload (res://tools/phased_render.gd:82)
ERROR: Failed to load script "res://tools/phased_render.gd" with error "Parse error".
```
The line-82 `bs` is redundant — line 38's `bs` is still in scope and usable. This is a one-off manual Phase-D render harness for the SHELVED creator.
- **Recommendation:** since it targets shelved work, DELETE the tool (phased_render.gd + .tscn + .uid). If kept, the one-line fix is to delete line 82 and use the existing `bs`. Severity HIGH only as a "broken file in tree" flag; impact low because nothing depends on it.

### 3.2 Dead one-off *_render.gd harnesses (creator/body, SHELVED surface) — severity: MEDIUM (sprawl)

All parse OK but are spent single-use manual render harnesses for the shelved creator/body, named by ad-hoc "phase" letters with no through-line. DEAD:
`age_sweep_render`, `breast_size_render`, `buildA_shell_render`, `eval_render`, `eye_iris_render`, `hair_render`, `normal_seam_render`, `phase2a_skin_render`, `phase2b_render`, `phase3b_render`, `phase5a_render`, `phaseC_handles_render`, `phased_render` (broken, §3.1), `phasee_render`, `proxy_render_check`, `creator_gpu_pick_check`, `creator_caps_playtest`.
Each has a paired `.tscn` + `.uid`. Several `.uid` files are untracked (git status: breast_size_render, buildA_shell_render, eval_render, eye_iris_render, normal_seam_render, phase2a_skin_render, phase2b_render, phase3b_render, phase5a_render).
- **Recommendation:** delete the `*_render` / `phase*` family wholesale (with their .tscn/.uid) — they are throwaway frame-generators for a shelved surface, not maintained tools. Severity MEDIUM (volume of cruft).

### 3.3 Build/ingest tools — KEEP (asset pipeline, nix-reproducible regen)

`body_converter.gd`, `body_proxy_build.gd`, `detail_library_build.gd`, `modifier_registry_build.gd`, `motion_ingest.gd`, `bdcc2_clip_ingest.gd`, `regen_compiled_*` are the data-regen pipeline referenced by body-parameterization.md. Keep even though creator is shelved — they regenerate committed assets.

### 3.4 Active sandboxes — KEEP

`tf_play.gd` (live TF driver, current), `tf_audit.gd` (TF audit sandbox, Jun 28, matches FEATURES "TF library + audit sandbox"), `cxg_playtest.gd` (CxG realizer playtest). `tf_playtest.gd` is the older TF harness possibly superseded by tf_play (see §1.4) — review for retirement.

---

## 4. tests/ — orphans, shelved-feature suites

### 4.1 All run.sh suites exist; no missing-file orphans

Cross-checked the 46-entry `SUITES=(...)` in run.sh against tests/ — every referenced `.tscn` is present. No dangling wiring.

### 4.2 Creator suites for a SHELVED feature still wired & gating — severity: MEDIUM

11 creator suites are wired into run.sh for the SHELVED creator: `creator_history_test`, `creator_glow_test`, `creator_phase3a_test`, `creator_phase3b_test`, `creator_tree_nav_test`, `creator_phase5a_test`, `creator_persistence_test`, `creator_buildbfix_test`, `creator_phasec_test`, `creator_phased_test`, `creator_phasee_test`. The "phase3a/3b/5a/c/d/e/buildbfix" naming mirrors the dead phase render tools — ad-hoc phase scaffolding, several testing narrow one-shot fixes (`creator_buildbfix_test`, `creator_phased_test`). Many `.uid`s are untracked (git status). They pass, but they pin a shelved surface and run on every `nix run .#test`.
- **Recommendation:** these are not broken, but they are scaffolding for shelved work. Either consolidate the phase-N suites into one `creator_test` or fence/skip them while the creator is shelved to keep the suite focused on live systems (TF, text-gen). Don't delete blindly — creator may un-shelve. Severity MEDIUM.

### 4.3 Possible redundant golden/interaction pairs — severity: LOW (review)

`golden_trace_test` + `interaction_golden_trace_test`, `interaction_behavior_test` + `interpreter_slice1_test`, `morph_drag_test`+`picker_test`+`gpu_id_picker_test` (three picker-adjacent suites for the shelved creator). Not confirmed redundant — flagged for a focused pass. The picker trio backs the shelved creator's drag-to-modify.

---

## 5. Prioritized cleanup list

| # | Item | Action | Severity |
|---|------|--------|----------|
| 1 | TF docs (`transformation-system`, `compound-parts-and-fluids`, `dynamical-transformation`) say "no code yet" but are BUILT & tested | **FIX status lines** to reflect shipped vs deferred; reconcile "awaits approval" | HIGH |
| 2 | BDCC2 sim ports (`mood/memory/relationship.gd`) condemned by text-gen doc but still on master + in green tests | **FENCE as legacy** w/ header pointing to text-generation-architecture.md §2 | HIGH |
| 3 | `tools/phased_render.gd` parse error (`bs` redeclared L82) | **DELETE** (shelved-surface one-off) or remove line 82 | HIGH |
| 4 | prose-generation / npc-mind-and-language / semantic-layer not back-annotated as superseded | **ADD superseded banner** (keep as history) | MEDIUM |
| 5 | Dead `*_render` / `phase*` tool family (~17 tools + tscn/uid) | **DELETE** | MEDIUM |
| 6 | Creator phase-N test suites for shelved feature | **CONSOLIDATE or fence/skip** | MEDIUM |
| 7 | Creator/body doc cluster (5 docs) — no authority map, governs shelved surface | **ADD doc-map note**; merge early R&D docs | MEDIUM |
| 8 | `design/creator-body` 15 attack-rounds + creator-ux rounds (keep SYNTHESIS) | **ARCHIVE/DELETE rounds** | LOW |
| 9 | `diagnosis/` reverify artifacts + untracked PNGs (shelved surface) | **ARCHIVE; gitignore/delete PNGs** | LOW |
| 10 | tf_play vs tf_playtest reference drift in FEATURES/docs | **PICK canonical, update refs** | LOW |

Delete-vs-archive principle applied: delete throwaway generators/scratch with no downstream reference (phased_render, *_render tools, diagnosis PNGs, spent attack-rounds); archive/banner anything a live doc still cites as evidence or history (superseded text-gen docs, text-gen-design/ & substrate-design/ candidates, creator-saga). Fix-in-place anything that is the live design of a shipped system (the three TF docs, the BDCC-port fence).
