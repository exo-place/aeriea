# Sprawl audit — `.tscn` scene graph

Date: 2026-06-28. Scope: every `.tscn` in the repo (91 total). Read-only — nothing
deleted, nothing committed. Companion to `scripts.md` and `docs-tools-tests.md` in this
folder; this pass is the scene-graph-specific cut and reuses their tool/test verdicts
rather than re-deriving them.

Reachability roots used:
- **Main scene:** `project.godot` → `run/main_scene="res://scenes/launcher.tscn"`.
- **Launcher MODES** (`scripts/launcher.gd:24-30`, loaded via `load()` at runtime, NOT
  ext_resource): `scenes/character_creator.tscn`, `scenes/test_level.tscn`,
  `scenes/text_sandbox.tscn`, `tools/tf_play.tscn`, `tools/tf_audit.tscn`.
- **run.sh SUITES** (48 entries) — each names a `tests/<name>.tscn`.
- **ext_resource / load() from another scene or `.gd`.**

Total: **91 `.tscn`** = 14 in `scenes/` (incl. 5 `scenes/ui/`) + 48 in `tests/` + 29 in `tools/`.

---

## 1. Counts by category

| Category | Count | Verdict |
|---|---|---|
| LIVE entrypoints (main scene + launcher modes) | 6 | KEEP |
| LIVE shared UI components (`scenes/ui/`) | 5 | KEEP |
| TEST HARNESS (`tests/*.tscn`, all wired in SUITES) | 48 | KEEP (see fence note) |
| TEST FIXTURE scenes (in `scenes/`, instanced by a suite `.gd`) | 3 | KEEP |
| BUILD / PIPELINE tools (regen committed assets) | 8 | KEEP |
| ACTIVE dev sandbox (not in launcher, used manually) | 1 | KEEP |
| SUPERSEDED sandbox (subsumed by a live one) | 1 | RETIRE |
| DEAD orphan demo scenes (`scenes/`) | 2 | **DELETE** |
| DEAD one-off render/check tool scenes (`tools/`) | 17 | **DELETE** |

6+5+48+3+8+1+1+2+17 = 91. ✓

---

## 2. LIVE entrypoints — KEEP (reachable from main scene / launcher)

| Scene | Script | Purpose | Reached by |
|---|---|---|---|
| `scenes/launcher.tscn` | `scripts/launcher.gd` | App shell; persistent mode-tab bar, swaps one mode scene at a time | **main_scene** |
| `scenes/character_creator.tscn` | `scripts/body/character_creator.gd` | 3rd-person body viewer/editor (SHELVED feature, still a launcher tab) | launcher MODE |
| `scenes/test_level.tscn` | `scripts/movement/interpreted_player.gd` | Parkour sandbox (FP look, mouse capture) | launcher MODE + 3 suites |
| `scenes/text_sandbox.tscn` | `scripts/text_sandbox.gd` | Transcript + input scaffold | launcher MODE |
| `tools/tf_play.tscn` | `tools/tf_play.gd` | Live TF-system driver (TF Playground) | launcher MODE |
| `tools/tf_audit.tscn` | `tools/tf_audit.gd` | TF library audit sandbox | launcher MODE |

### LIVE shared UI components — KEEP (`scenes/ui/`, instanced by live scenes)
`pause_menu.tscn`, `controls_menu.tscn`, `options_menu.tscn`, `controls_overlay.tscn`,
`crosshair.tscn` — each has a `scripts/ui/*.gd`. `pause_menu` instances `controls_menu` +
`options_menu`; `test_level`/`test_level_compiled`/`test_level_imperative` and
`interaction_sandbox` instance `pause_menu`+`controls_overlay`+`crosshair`. All reachable. KEEP.

---

## 3. TEST HARNESS — KEEP (legitimate Godot test pattern)

All **48** `tests/*.tscn` are wired into `tests/run.sh` SUITES, and the SUITES list and the
on-disk `tests/*.tscn` set are an **exact 1:1 match** — zero missing-file orphans, zero
unwired test scenes. Not sprawl per se; they're the test harness.

**Fence note (not a scene defect; carried from `docs-tools-tests.md` §4.2):** 11 of the 48
back a SHELVED surface — the creator suites `creator_history/glow/phase3a/phase3b/
tree_nav/phase5a/persistence/buildbfix/phasec/phased/phasee_test`. Their `phase3a/3b/5a/c/d/e/
buildbfix` naming mirrors the dead render-tool family below (same ad-hoc phase scaffolding).
They pass and gate every `nix run .#test`. Recommendation unchanged: **consolidate the
phase-N creator suites into one `creator_test`, or fence/skip them while the creator is
shelved** — don't delete blind (creator may un-shelve; `character_creator.tscn` is still a
launcher tab). Picker trio (`morph_drag_test`+`picker_test`+`gpu_id_picker_test`) also backs
the shelved creator — flagged for a focused redundancy pass, not confirmed redundant.

### TEST FIXTURE scenes in `scenes/` — KEEP (instanced by a live suite, NOT launcher)
| Scene | Script | Instanced by |
|---|---|---|
| `scenes/test_level_compiled.tscn` | `scripts/movement/interpreted_player.gd` | `tests/movement_behavior_test.gd` |
| `scenes/test_level_imperative.tscn` | `scripts/player_controller.gd` (OLD imperative controller) | `tests/movement_behavior_test.gd` |
| `scenes/interaction_sandbox.tscn` | `scripts/movement/interpreted_player.gd` + interaction `.gd`s | `tests/interaction_behavior_test.gd` |

These three are not launcher-reachable but are live test fixtures. KEEP. See §6 for the
`test_level*` overlap flag (`_imperative` rides the legacy controller).

---

## 4. BUILD / PIPELINE + ACTIVE SANDBOX tools — KEEP

**Pipeline (8), regenerate committed assets — keep even though creator is shelved**
(`docs-tools-tests.md` §3.3): `bdcc2_clip_ingest`, `body_converter`, `body_proxy_build`,
`detail_library_build`, `modifier_registry_build`, `motion_ingest`,
`regen_compiled_interaction`, `regen_compiled_movement`.

**Active manual sandbox (1):** `tools/cxg_playtest.tscn` (`cxg_playtest.gd`) — CxG realizer
playtest; cited by FEATURES.md, still the live manual CxG sandbox. KEEP.

**Superseded sandbox (1) — RETIRE:** `tools/tf_playtest.tscn` (+`.gd`). Older 5 KB headless
TF sequence; subsumed by the live `tf_play` (launcher TF Playground). Reachable from neither
launcher nor run.sh — only self + a stale FEATURES.md reference (`docs-tools-tests.md`
§1.4/3.4). Retire `tf_playtest.tscn`/`.gd`/`.uid` and update the FEATURES.md pointer to
`tf_play`. Judgment call (one stale doc ref to fix), not a blind delete.

---

## 5. DEAD / ABANDONED — DELETE (orphans; reachable by nothing)

### 5a. Orphan demo scenes in `scenes/` (2) — safe delete
| Scene + script | Evidence |
|---|---|
| `scenes/face_demo.tscn` + `scripts/body/face/face_demo.gd` | Only reference is its own script. Not main, not a launcher MODE, not in SUITES, not instanced. Standalone face demo nothing touches. |
| `scenes/body_morph_demo.tscn` + `scripts/body/body_morph_demo.gd` | Same: only self-ref. Already flagged dead in `scripts.md` §2a. |

### 5b. One-off render/check tool scenes in `tools/` (17) — safe delete wholesale
Each is a spent single-use manual frame-generator / pixel-check for the SHELVED creator/body,
named by ad-hoc "phase" letters with no through-line. Each has a paired `.tscn` + `.gd`
(+ several untracked `.uid`). Already condemned in `docs-tools-tests.md` §3.1–3.2 (one,
`phased_render.gd`, additionally has a **confirmed parse error** — duplicate `bs` decl at
line 82 — so it fails to even load):

`age_sweep_render`, `breast_size_render`, `buildA_shell_render`, `eval_render`,
`eye_iris_render`, `hair_render`, `normal_seam_render`, `phase2a_skin_render`,
`phase2b_render`, `phase3b_render`, `phase5a_render`, `phaseC_handles_render`,
`phased_render` (broken), `phasee_render`, `proxy_render_check`, `creator_gpu_pick_check`,
`creator_caps_playtest`.

Reachability: none from launcher, none from run.sh, none instanced by a live scene. The only
inbound references are these tools loading `character_creator.tscn` (one-directional — they
consume the creator, nothing consumes them). Pure orphans.

---

## 6. REDUNDANT / OVERLAPPING

- **`tf_play` vs `tf_playtest`** — the live launcher TF Playground vs the older headless TF
  sequence. Redundant; `tf_playtest` is the loser → RETIRE (§4).
- **`test_level` / `test_level_compiled` / `test_level_imperative`** — three parkour-level
  variants. NOT pure duplicates: `movement_behavior_test` instances all three to assert the
  interpreted, compiled, and imperative movement paths agree, so the trio is a deliberate
  equivalence fixture. BUT `test_level_imperative` is the **only** live consumer of the legacy
  `scripts/player_controller.gd` (every other level uses `interpreted_player.gd`). If/when the
  imperative controller is retired, this scene + its arm of the test go with it. Flag, not a
  delete — keep while the equivalence test is the spec.
- The creator picker trio of suites (§3) — possible test-side redundancy, not scene-side.

---

## 7. Concrete recommendation

**Safe-obvious DELETE — 19 scenes (with paired `.gd`/`.uid`):**
- 2 orphan demo scenes: `scenes/face_demo.tscn`(+`scripts/body/face/face_demo.gd`),
  `scenes/body_morph_demo.tscn`(+`scripts/body/body_morph_demo.gd`).
- 17 dead render/check tool scenes (§5b), each with its `.gd` and any `.uid`.

These 19 are reachable by nothing live and safe to remove in one pass. Note `phased_render`
is additionally broken (won't load), so it cannot regress anything.

**Judgment calls (retire/consolidate, touch one stale ref each):**
- RETIRE `tools/tf_playtest.tscn`+`.gd`+`.uid` (superseded by `tf_play`); update FEATURES.md.
- CONSOLIDATE the 11 `creator_phase*/buildbfix/glow/history/tree_nav/persistence` suites into
  one `creator_test`, OR fence/skip them while the creator is shelved (keeps `nix run .#test`
  focused on TF/text-gen). Don't delete — `character_creator.tscn` is still a launcher tab.
- KEEP but watch `test_level_imperative.tscn` — drops out when `player_controller.gd` retires.

**Top structural recommendation:** `tools/` currently conflates **three** scene kinds —
live launcher modes (`tf_play`, `tf_audit`), the asset-regen pipeline (8 build tools), and the
dead one-off render generators (17). The render family is what makes `tools/` look like sprawl.
Delete that family wholesale, and `tools/` collapses to a coherent two-kind directory
(pipeline + live/active sandboxes). If a convention is wanted beyond that, the cleanest split
is: launcher-reachable mode scenes belong in `scenes/` like the other modes, leaving `tools/`
for non-shipped pipeline + sandbox harnesses only — but that's optional polish; the
high-value move is the wholesale render-family delete, which removes ~19 scenes (with scripts)
and the matching untracked `.uid` churn in one stroke without touching any live or test path.
