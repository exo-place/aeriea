# Git dirty-state triage (read-only)

Branch `master`, ahead of `origin/master` by 1 commit. 2 modified tracked files,
24 untracked paths. Classification + per-path recommendation below. No changes made.

## 1. `docs/decisions/dynamical-transformation.md` — MODIFIED

A 342-line-changed rework that replaces the **structural-diff + correspondence-map**
model (matching a `from-structure` against a `to-structure`) with **authored,
per-part targeted-op bundles** (`transform` existing id / `graft` new id / `remove`
selector-resolved id, optionally sharing one progress driver). The change is applied
**consistently across the whole doc**: prose intro (§ identity), the special-cases
table, §8.2 worked example (biped→taur rewritten), two NEW worked examples (§8.3
breast-count, §8.4 nested-breast), §9.1, §9.3 replay argument, the implementation
checklist (item 7 rewritten), the Deferred section, and the open-questions list
(old Q6 "correspondence rule" deleted, Q6/Q7 renumbered).

Coherence check: every surviving "correspondence" mention (lines 22, 32, 607–608,
673, 742–743, 765, 916) is an **explicit negation/reframe** ("no correspondence
map", `"Correspondence" = authored targeting`), not a leftover of the old model. No
dangling `from-structure`/`to-structure` mechanism remains. Status header still reads
"Design pass — no code. Not green." The doc is internally coherent and complete — a
finished rework, not a stale intermediate.

**Recommendation: COMMIT as-is.** It is the current, self-consistent design-doc state.
Judgment call only in that it is design intent the user held intentionally — worth a
quick confirm, but nothing technical blocks committing.

## 2. `docs/FEATURES.md` — MODIFIED

One added bullet under **Not green**: "**TF library + audit sandbox**" describing
`scripts/body/tf/tf_library.gd` (55 named TFs), the `tools/tf_audit.tscn` sandbox,
and `tests/tf_library_test.gd`, plus describe-layer quality fixes (natural genital
nouns, `spine`→`body_core` retag, covering adjectives, naga/taur aliasing).

Accuracy verified: all three referenced paths are **tracked**, and `tf_library_test`
is registered in `tests/run.sh` SUITES (line 58). Lands correctly under Not green
(not Green) so the pre-commit green-gate is not triggered.

**Recommendation: COMMIT.** Accurate to what is built; correctly placed.

## 3. `docs/artifacts/diagnosis/*.png` (+ `.png.import`) — UNTRACKED (10 files)

`_body_with_hair`, `_face_3q_nohair`, `fp_view`, `tp_front`, `tp_walkdir` — render
artifacts from a past body/movement diagnosis session. The `diagnosis/` dir tracks
**only `.md` reports**, zero `.png` anywhere under `docs/artifacts/`. Filename grep
across tracked docs found **no reference** to any of these five basenames (the grep
hits are the `.md` reports, not the images). They are throwaway render captures whose
findings already live in the committed `body-render.md` / `movement.md` reports.

**Recommendation: DELETE** (safe — orphaned, superseded by committed reports). The
repo convention is markdown-only artifacts, so binary renders should not be tracked.
Optional: add `docs/artifacts/**/*.png` to `.gitignore` to stop future render
captures from showing as untracked noise (minor; the `.import` sidecars too).

## 4. `docs/artifacts/text-gen-design/ref-*.md` — UNTRACKED (2 files)

Note: the prompt named `ref-bdcc.md` / `ref-corpus.md`, but **those are already
tracked**. The actually-untracked pair is **`ref-bdcc-game.md`** and **`ref-coc.md`**.
Both are **cited by committed decision docs**: `ref-coc.md` by
`compound-parts-and-fluids.md`, `tf-depth-and-species.md`, `transformation-system.md`;
`ref-bdcc-game.md` by `tf-depth-and-species.md` and `transformation-system.md`
(as a "covered fully in" source). They are load-bearing references with dangling
links until committed.

**Recommendation: COMMIT both.** Committed docs link to them by path; leaving them
untracked leaves broken references.

## 5. `*.uid` sidecars — UNTRACKED (13 files)

`scripts/body/body_archetypes.gd.uid`, `scripts/text/cxg_realizer.gd.uid`,
`scripts/util/det_rng.gd.uid`, `tests/creator_{buildbfix,glow,phase3a,phase3b,phase5a,phasee,tree_nav}_test.gd.uid`,
`tests/cxg_realizer_test.gd.uid`, `tests/tf_figure_test.gd.uid`, `tools/cxg_playtest.gd.uid`.

Policy is unambiguous: the repo **tracks 134 `.uid` files** and every one of these 13
has a **tracked `.gd` sibling`. A `comm` of (every tracked `.gd` + ".uid") against
tracked `.uid` returns **exactly these 13 and nothing else** — i.e. there is no
counter-example of a tracked script whose `.uid` is deliberately ignored. `.uid` is
not in `.gitignore` (only `.godot/`, `.import/`). These are simply newly-added scripts
whose Godot UID sidecars were never staged.

**Recommendation: COMMIT all 13** to restore the repo's consistent "track every
`.gd`'s `.uid`" convention (the Godot 4.x norm — pins resource UIDs). Do NOT gitignore.

## 6. Anything else

No other dirty/untracked paths. The 2 modified + 24 untracked above account for the
entire `git status`. The branch is 1 commit ahead of origin (a normal unpushed
commit, not a dirty-state issue).

---

## Cleanup plan

**Safe / obvious (do without further input):**
- COMMIT `docs/FEATURES.md` (accurate, correctly under Not green).
- COMMIT `ref-bdcc-game.md` + `ref-coc.md` (cited by committed docs; broken links otherwise).
- COMMIT all 13 untracked `.uid` sidecars (restores the 134-strong tracked-uid convention).
- DELETE the 10 `diagnosis/*.png`/`.png.import` (orphaned renders; findings already in committed `.md`).
- Optional minor: gitignore `docs/artifacts/**/*.png` (+ `.png.import`) to suppress future render noise.

**Judgment call (confirm with user):**
- COMMIT `docs/decisions/dynamical-transformation.md`. Technically it is a complete,
  internally coherent rework (verified — no dangling old-model mechanism), and "commit
  as-is" is the right call. The only reason it is a judgment call is that it encodes
  design intent the user deliberately held; worth a one-line confirm that this
  targeted-ops model is the intended current direction before committing.
