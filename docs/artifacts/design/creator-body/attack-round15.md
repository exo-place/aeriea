# Attack — round 15 (hostile review of SYNTHESIS.md v15)

Hostile reviewer pass against the actual code/assets @ HEAD. Only findings that hold up against the real
code are recorded. Acknowledged open/deferred items with sound, named seams (default-interval `[a,b]`
shapes + global fraction `f`; combination-plausibility; Tier-B baker; subdivision cost; procedural-iris
taste; Quest costs; self-intersection known limit) are NOT ranked as flaws, per the review contract.

The v15 changes are exactly two, both confined to the held-interval mechanism's LIFECYCLE and DISPLAY:
MA14-1 (the gesture-lifecycle-interruption invariant — any state-replacing op mid-gesture aborts the active
gesture and clears the held-interval map before applying, retiring the v12/v13 `_extremeness_dirty`
deferred-recompute in favour of abort-then-recompute) and MI14-1 (a shared bilateral widget displays the
conservative intersection `[max(lo_L,lo_R), min(hi_L,hi_R)]` of its two controls' cap intervals). The core
single-value cap formula (`hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)`) is unchanged and was not
re-attacked beyond re-tracing the per-pole / sign-flip / beyond-cap-persist cases, which hold.

**Result: NO BLOCKER. NO MAJOR.** The round-14 MAJOR (MA14-1, the mid-gesture-restore stale-held-interval
hole) is genuinely resolved by the v15 abort invariant — the abort clears `_drag_start_value` + the sculpt
accumulators + the gesture brackets before any state-replacing write lands, so the trap round 14 traced
cannot occur. The two findings below are MINOR: one is a literal-wording / gate-assert inaccuracy in how
v15 describes the post-abort resumption (the *property* it wants holds, but via a different code path than
the text and gate #1a-vi assert), and one is an owned consequence of the conservative bilateral display
that the design states but does not fully spell out. Neither, executed as written, produces a wrong body or
a corrupt node.

---

## MINOR

### mi15-1 — The v15 claim "after a state-replacing op there is NO active gesture, so the NEXT INPUT starts a FRESH gesture" (and gate #1a-vi's assert (2)) is literally FALSE for the canonical scenario the invariant exists to fix: a mid-sculpt-drag Ctrl+Z with the left mouse button STILL PHYSICALLY HELD. The next *input* is mouse MOTION, which does not — and cannot — start a fresh sculpt gesture; only a subsequent release+re-press does. The SAFETY property (no zombie resume, no garbled node) still holds, but via a different path than the text/gate describe.

**Locus.** `SYNTHESIS.md:1140-1146` ("after a state-replacing op there is NO active gesture... the NEXT
input starts a FRESH gesture whose first-touch capture reads `cur_start` from the NEW state");
`SYNTHESIS.md:1783-1784` gate #1a-vi assert "(2) the next input starts a FRESH gesture capturing `cur_start`
against the NEW state (`0.0`)". Input code: `character_creator.gd:628-648` (a sculpt gesture starts ONLY on
a fresh `MOUSE_BUTTON_LEFT` press that hits the body, `:632-644`), `:660-676` (mouse-motion dispatch).

**The trace.** Pre-gesture, modifier `M` is ratcheted to `cur=0.9` (default `[-0.5,0.5]`). The user holds
left-mouse and sculpts; the choke captures `_drag_start_value[M]=0.9` (held interval `[-0.5,0.9]`).
Mid-drag the user presses Ctrl+Z. Under v15, `_do_undo` → `_restore_current` first ABORTS the gesture
(clears `_drag_start_value`, `_drag_accum`, `_drag_vertex`, `_dragging_morph`/`_drag_pending`), then does
the raw restore (`M=0.0`). After the abort, `_dragging_morph=false`. **The left mouse button is still
physically held.** The very next input is an `InputEventMouseMotion` with the button still down. At
`character_creator.gd:662` `if _dragging_morph:` is now false; `elif _dragging_orbit:` is false (the sculpt
press at `:632-644` returned before `_dragging_orbit=true` at `:645`); `elif _dragging_pan:` false;
`elif _sculpt_mode:` true → `_update_hover_glow` (`:674-676`). So the held-button motion becomes a no-op
hover. It does **not** start a fresh gesture and does **not** capture a new `cur_start`. A fresh sculpt
gesture requires the user to RELEASE the button (`:646-649`, which only calls `_end_morph_drag` — a no-op
now since `_dragging_morph` is already false and `_drag_accum` empty) and PRESS again (`:632-644`).

**Why this is the correct/safe outcome — and therefore only MINOR.** The actual behavior is exactly what
you want for safety: the aborted gesture does not resume as a zombie, no stale `cur_start` governs, and no
garbled node is committed (the abort emptied `_drag_accum`, so even the eventual `_end_morph_drag` on
release commits nothing). So the design's GOAL — "no stale `cur_start` survives, no ratchet the restore
removed survives, no garbled node" — genuinely holds. The defect is only that v15's stated MECHANISM for
how it holds ("the next input starts a fresh gesture") is wrong for the held-button case: the next input is
NOT a fresh gesture, it is a dead hover, and the NEXT gesture starts on the next press. Gate #1a-vi's
assert (2) as literally written ("the next input starts a FRESH gesture capturing `cur_start` against the
NEW state") would FAIL against the actual input wiring — the next motion input starts nothing; the harness
would have to model a release+re-press to observe the fresh capture. The assert's intent (3) ("the
committed node after release is correct (non-garbled)") holds and is the load-bearing one.

**Suspected, would verify by** writing the gate #1a-vi harness against `character_creator.gd`'s real input
path and confirming a single held-button motion after the abort produces no gesture (only a release+press
does) — i.e. that assert (2) must be reworded to "no active gesture survives, and the NEXT PRESS (not the
next motion) starts a fresh capture." This is a one-line correction to the invariant's prose and to gate
#1a-vi assert (2); the safety property and the abort mechanism are sound.

### mi15-2 — The conservative bilateral display (`min_value=max(lo_L,lo_R)`, `max_value=min(hi_L,hi_R)`) means that touching a bilateral slider on an asymmetrically-RATCHETED body silently collapses the ratcheted side DOWN to the tighter intersection bound — the bilateral slider cannot reach, or hold, the larger side's ratcheted reach. v15 states the conservative DISPLAY rule and asserts per-control clamping is "individually unchanged," but does not spell out this user-visible resync consequence.

**Locus.** `SYNTHESIS.md:1179-1183` (step-4 shared-widget intersection display);
`SYNTHESIS.md:651-657` (§1.3 slider path: the bilateral slider drives BOTH L and R with the SAME `req`);
`character_creator.gd:1172,1209-1214,1235` (the slider's displayed value reads `full_names[0]` only, but
`_set_modifier(full_names, v)` writes the SAME `v` to BOTH L and R).

**The trace.** R is ratcheted to `cur_R=0.9` (`[lo_R,hi_R]=[-0.5,0.9]`); L sits at `cur_L=0.3`
(`[lo_L,hi_L]=[-0.5,0.5]`). The conservative intersection is `[max(-0.5,-0.5), min(0.5,0.9)] = [-0.5,0.5]`.
The slider shows L=0.3 (its `full_names[0]` value), thumb bounded to `[-0.5,0.5]` — honest, the thumb
cannot exceed L's true cap. But the moment the user drags this bilateral slider, it writes the SAME value
to BOTH sides through `apply_capped`: dragging toward max requests at most `0.5`, and `apply_capped(R, 0.5)`
gives `clamp(0.5, -0.5, max(0.5,0.9))=0.5`, pulling R DOWN from its ratcheted 0.9 to 0.5. So a single
touch of the bilateral slider on a diverged body forcibly resyncs R toward the conservative bound and
DESTROYS R's ratchet — and there is no way to re-reach 0.9 through the bilateral slider, because its
displayed max is `min(hi_L,hi_R)=0.5`.

**Why MINOR / arguably intended.** This is the inherent, owned consequence of "one widget, two diverged
controls, conservative display": the bilateral slider is the SYMMETRIC control by definition (§1.3), so
re-synchronizing both sides toward the tighter bound when the user touches it is defensible (it is the
"reduce freely / inward is free" semantics applied symmetrically). The display is honest (thumb can't lie
about exceeding either cap), and per-control clamping IS individually unchanged exactly as v15 claims.
Divergence is only reachable via mirror-OFF sculpt or asymmetric import — states the bilateral slider was
never designed to represent (the round-14 MI14-1 scoping). So this is not a contradiction or a wrong
result; it is an unstated UX consequence. The design's own round-14 honest-fix menu even offered "hidden /
split when its two sides diverge" as an alternative — choosing the conservative-display option is a valid
call, but v15 should note that on a diverged body the bilateral slider is a RESYNC-toward-tighter control,
not a no-op-until-you-move-it control.

**Suspected, would verify by** the gate #10 / MI14-1 harness driving a mirror-OFF asymmetric sculpt to
`cur_R=0.9, cur_L=0.3`, then a single bilateral-slider `value_changed`, and asserting R lands at 0.5 (the
designed conservative resync) — confirming the behavior is the intended one and only the documentation of
its consequence is thin.

---

## Pressure-test of the v15 changes — the four prompt concerns, traced against code

**(1) Does "abort the gesture, then apply" create an inconsistency with an in-flight mouse button still
physically held — does the next mouse-move start a FRESH gesture or resume a ZOMBIE one?** Traced in full
(mi15-1 above). Answer: it resumes NEITHER. After the abort sets `_dragging_morph=false`
(`character_creator.gd:639` is the only setter; nothing in the motion path `:660-676` sets it), a
held-button motion falls through to `_update_hover_glow` (`:674`) — a dead hover, not a gesture. A fresh
sculpt gesture requires release+re-press (`:632-644`). So there is NO zombie resume (the safe outcome the
invariant wants) — but the v15 prose and gate #1a-vi assert (2) describe it as "the next input starts a
fresh gesture," which is literally inaccurate for the held-button case (ranked mi15-1, MINOR; the safety
property holds, the described mechanism does not). For the SLIDER-drag case the abort is even cleaner: a
slider gesture is bracketed by `drag_started`/`drag_ended` (`:1052-1056,1181-1183`); aborting clears
`_drag_pending`, and Godot's Range will fire its own `drag_ended` on the eventual release — no zombie.

**(2) Any state-replacing op the invariant's enumeration misses (randomize? archetype apply? programmatic
body set? branch-switch)?**
- **Branch-switch** — `_switch_branch` (`:1009-1012`) funnels to `_restore_current` (the wholesale
  `_body_state.modifiers` replacement), exactly like undo/redo/jump/reset. v15 names "history-jump" and
  "raw restore (undo/redo/reset/history-jump)" generically and the whole point of the v15 generalization is
  that it is stated as "any state-replacing op," not a per-op list — so branch-switch is SUBSUMED. Not a
  gap. (`_reset_all` `:1280-1283` likewise routes through `_restore_current`; covered.)
- **Randomize / archetype apply / numeric entry / programmatic body set** — these do NOT exist in the code
  yet (`grep` for `randomize`, `archetype`, `LineEdit`, `text_submitted` is empty; confirmed). They are
  honestly named as NET-NEW first-build work. The invariant's generic phrasing ("any state-replacing op
  that can occur mid-gesture") covers them by construction when built, and archetype/import load is named
  explicitly (`SYNTHESIS.md:1132`). Not a false-against-code claim, not a gap.
- **Sculpt-mode toggle (M key) mid-drag** — `_set_sculpt_mode(false)` (`:538-545`) does NOT replace
  `_body_state` (it only flips a bool + hides glow), so it is NOT a state-replacing op and correctly needs
  no abort. The drag continues (`:662` doesn't gate on `_sculpt_mode`) until release. No held-interval
  desync because the model isn't replaced. Correct.
- **Extremeness change** — named explicitly as a state-replacing op (`SYNTHESIS.md:1147-1157`); the v15
  retirement of the `_extremeness_dirty` deferral in favour of abort-then-recompute is internally
  consistent: both old paths (defer-to-gesture-end vs abort-now) converge on a gesture-less model with
  fresh first-touch capture on the next gesture. No interim clamp gap (the choke always reads live
  `cap(control, extremeness)` at clamp time). Sound.

**(3) Does the conservative bilateral display interact correctly with a one-pole ratchet on only ONE
side?** Traced in full (mi15-2 above). The DISPLAY is correct and honest — the thumb cannot exceed either
side's true cap (`min(hi_L,hi_R)`). The only consequence is that touching the bilateral slider on a
diverged body resyncs the ratcheted side DOWN to the tighter bound (the ratcheted reach is unreachable via
the bilateral slider). This is an owned, defensible property (the bilateral slider is the symmetric
control), not a contradiction — ranked mi15-2 MINOR for the unstated consequence only. Per-control held
intervals + clamping are genuinely individually unchanged (`apply_capped` runs per resolved name against
each side's own `cur_start`), exactly as v15 claims.

**(4) Any remaining first-build claim false against the code, or any verified diagnosis defect (incl.
new-defects.md) not addressed or deferred?**
- **First-build → deferred dependency re-scan (§10.1 vs §10.2).** The v15 changes add only: an abort branch
  on the EXISTING restore/load/extremeness paths (MA14-1 — reuses the same `_drag_start_value` map + sculpt
  accumulators + gesture brackets already in first-build, `character_creator.gd:642,500,1327,576-583`), and
  a one-line conservative-intersection write on the existing step-4 bilateral bounds (MI14-1). Neither adds
  a new asset or depends on any deferred item. The only new harness is gate #1a-vi (the mid-gesture-abort
  assert), runnable first-build (needs only the choke + the NET-NEW caps asset, itself first-build). No
  first-build item depends on a deferred one. Verified — no new first-build→deferred dependency from v15.
- **Code citations spot-checked @ HEAD.** `_restore_current:1315-1331` (sets `slider.value=v` `:1324`,
  replaces `_body_state.modifiers` `:1327`), `_do_undo/_do_redo/_jump_to_node:1299-1311`, the Ctrl+Z
  keyboard handler in `_unhandled_input:576-583`, the sculpt bracket `_dragging_morph` set `:639` / end
  `:647-648,500-516`, `_apply_morph_drag:446-475`, the region `value_changed:1175-1185` and
  `_set_modifier:1209-1214`, `resolve_full_names:136-145`, the bilateral slider reading `full_names[0]`
  `:1172,1235` — ALL match the design's citations. No false-against-code citation found among the v15 text.
- **new-defects.md (1 tongue, 2 glow-stuck-at-neutral, 3 glow-clips-through-body)** — re-confirmed each is
  addressed: glow-stuck-at-neutral and glow-clip in §5.5 (refresh sculpt spatial data from the morphed
  surface; world-space ε outward offset + uniform-scale assert); tongue re-seat as an asset re-bake in
  §5.6. None silently dropped. (Unchanged from round 14's cross-check; v15 touched none of these.)
- **diagnosis/*.md** — the creator-relevant items (sculpt-on-neutral-mesh B2, default-hair face cap,
  camera face-front) are folded into §5.5 / §0 / §5.4; the others (movement, text-npc, hair-parts,
  launcher) are out of this design's scope (not creator+body bounds). No creator+body verified requirement
  dropped.
- **Breast-volume count** re-verified @ HEAD: `base_body_detail.index.json:159-160` down=244 / up=369 —
  matches §0. Correct.

---

## Load-bearing v15 areas attacked and NOT broken (re-verified against code/assets @ HEAD)

- **MA14-1 (the v15 abort invariant) genuinely closes the round-14 mid-gesture-restore hole.** The abort
  clears `_drag_start_value` + `_drag_accum`/`_drag_vertex` + `_dragging_morph`/`_drag_pending` BEFORE the
  raw restore writes the model, so the stale-`cur_start` trap round 14 traced cannot occur: there is no
  held interval left to clamp against, and no accumulator left to commit a garbled node. The
  release-after-abort path (`_end_morph_drag` with empty `_drag_accum`, `:502-504`) commits nothing.
  Verified the abort can be inserted on the EXISTING restore funnel (`_restore_current:1315-1331`) ahead of
  the wholesale `_body_state.modifiers` replacement at `:1327` — the brackets and accumulators it must
  clear all already exist as fields (`:85,93,134,501,640,642`). Sound.
- **Retirement of `_extremeness_dirty` in favour of abort-then-recompute is consistent.** Both the v12/v13
  defer-to-gesture-end path and the v15 abort-now path land on the same end state (gesture-less model, next
  gesture captures `cur_start` post-change). The MI13-1 full all-controls sweep is unchanged — now run
  immediately after the abort instead of at a deferred gesture-end. No interim clamp gap (the choke reads
  live `cap(·)`). Sound — and genuinely SIMPLER (one lifecycle branch on every interrupting trigger,
  versus a defer-vs-abort split).
- **Conservative bilateral display closes the round-14 MI14-1 thumb-can-exceed-the-other-side desync** for
  the case it targets (the thumb is bounded to `[max(lo_L,lo_R), min(hi_L,hi_R)]`, so it cannot exceed
  either side's true cap). The only residual is the unstated resync consequence (mi15-2), not the desync
  the rule was built to kill.
- **Core cap formula** — per-pole independence, window axes (masculinity `[20,80]`), beyond-cap
  persistence + free reduction, no sign-flip across neutral — re-traced; unchanged and sound. Not a v15
  surface.
- **Choke-capture invariant (v14 MA13-1)** — re-confirmed every live model mutator routes through
  `apply_capped` by design (sculpt `:466-470`, headline `:1047`, region `:1212-1214`); the restore path is
  the raw bypass `:1323,1327`. No live write skips the choke; the v15 abort sits on the restore/load/
  extremeness triggers, orthogonal to the capture invariant. Sound.
- **First-build → deferred dependency** — re-scanned §10.1 vs §10.2 for the v15 additions specifically:
  none introduced. The acknowledged-open items (default-interval `[a,b]` shapes + `f`,
  combination-plausibility, Tier-B baker, subdivision cost, procedural-iris taste, Quest costs,
  self-intersection limit) each have a sound named seam and none breaks a first-build item — not flaws per
  the contract.

---

## Summary

- **NO BLOCKER, NO MAJOR.** The round-14 MAJOR (mid-gesture-restore stale-held-interval) is genuinely
  resolved by the v15 abort invariant; the v15 changes are contained and the core cap formula is untouched
  and sound.
- **mi15-1 (MINOR):** v15's prose and gate #1a-vi assert (2) claim that after a mid-gesture abort "the next
  input starts a FRESH gesture," but for the canonical held-button Ctrl+Z case the next input is mouse
  motion, which starts NO gesture (it routes to dead hover, `character_creator.gd:662,674`); a fresh
  gesture needs release+re-press. The safety property (no zombie, no garbled node) holds via that path; only
  the stated mechanism and the gate assert wording are inaccurate (`SYNTHESIS.md:1140-1146,1783-1784`).
- **mi15-2 (MINOR):** the conservative bilateral display is honest, but on a diverged/ratcheted body
  touching the bilateral slider silently resyncs the ratcheted side DOWN to the tighter intersection bound
  (the ratcheted reach is unreachable via that slider); v15 states the display rule and "per-control
  clamping unchanged" but does not spell out this resync consequence (`SYNTHESIS.md:1179-1183`,
  `character_creator.gd:1172,1209-1214`).
- Concerns (1)–(4) traced against the actual code: the abort produces no zombie resume; no state-replacing
  op is genuinely un-covered (branch-switch/reset subsumed by the generic rule; randomize/archetype/numeric
  are honest net-new); the conservative bilateral display interacts correctly with a one-side ratchet
  (modulo the mi15-2 unstated consequence); no first-build claim is false against the code and no verified
  diagnosis/new-defects requirement is silently dropped.
