# Attack — round 13 (hostile review of SYNTHESIS.md v13)

Hostile reviewer pass against the actual code/assets @ HEAD. Only findings that hold up are recorded.
Acknowledged open/deferred items with sound seams (default-interval constants + `f`; combination-
plausibility; Tier-B baker; subdivision cost; procedural-iris taste; Quest costs; self-intersection
known limit) are NOT ranked as flaws, per the review contract.

The core single-value cap formula (`hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)`) was re-derived
and is not attacked further — sound. The v13 changes are MA12-1 (the held-interval mechanism generalized
to "active edit gesture" covering slider+sculpt, with sculpt-side per-modifier first-touch capture into
`_drag_start_value`), MI12-1 (`_extremeness_dirty` deferred recompute), and the gate #1a iv-b/iv-c
asserts. MA12-1's *direct-touch* coverage (the round-12 hole) is genuinely closed. MI12-1 holds.

**One finding holds at MAJOR.** It is the SAME defect class as MA12-1 (the very thing v13 was built to
close), surviving on the one live-through-the-choke sub-path the v13 capture rule does not reach: the
**mirror-applied contralateral twin**.

---

## MAJOR

### MA13-1 — The v13 held-interval capture fires ONLY on a directly-touched control (slider's bound control / a `decompose_drag`-returned modifier). The §1.3 mirror step writes a SECOND control — the contralateral `twin(M)` — through the SAME live choke per frame, but `twin(M)` is never in a `decompose_drag` result (sculpt) and is not the slider's bound control (slider), so it gets NO `_drag_start_value` entry. During a transient-dip drag with mirror ON (the DEFAULT), the twin's ratchet collapses — the exact MA12-1 trap, on the mirror-twin path.

**Locus.** The v13 capture rule, §3.2 step 3 (`SYNTHESIS.md:1019-1029`) and path 1
(`:1101-1102`): the held interval `_drag_start_value[M]` is populated **(a) SLIDER drag:** on
`drag_started`, "one control per gesture" (the bound control) (`:1020-1021`,
`character_creator.gd:1052-1053,1181`); **(b) SCULPT drag:** "each modifier's `cur_start` the FIRST time
it appears in a `decompose_drag` result within the gesture" (`:1022-1025`, `:1101-1102`). Neither rule
captures the contralateral twin.

The mirror step that writes the twin: §1.3 slider path (`SYNTHESIS.md:601-602`) — "if the edit is
one-sided AND mirror ON, repeat the same protocol for `apply_capped(twin(M), req_twin)`"; §1.3 sculpt
path (`:609-610`) — "if mirror ON, `apply_capped(twin(M), …)` via the twin table (guarded
`twin(M) != M`), each through the same protocol." Mirror ON is the DEFAULT (§1.3, `:583`
"Mirror ON (default)").

**Why the twin is never directly touched (so never captured).**

- **Sculpt.** `decompose_drag` (`morph_drag.gd:320-372`) returns only the candidates whose footprint
  covers the *picked* render vertex (`candidates_at(render_vertex)`, `:325`). A pick on the LEFT cheek
  returns the LEFT-side modifiers; the right-cheek twin's footprint is on the opposite side of the body,
  far from the picked vertex, so `r-…` is NOT in the result. The twin is applied *purely* by the §1.3
  mirror step, which is not a `decompose_drag` result — so the v13 sculpt capture
  (`if not _drag_start_value.has(M)` on `decompose_drag` keys, `:1024-1025`) never fires for it.
- **Slider.** A *one-sided* lateral edit resolves to one full_name (the touched side); the slider's
  `drag_started` captures that one control (`:1020-1021`). The twin is written only by the post-step
  mirror call (`:601-602`). `drag_started` captured the touched control, not the twin.

**The trap, reproduced on the twin.** Take a bidirectional twin `T = twin(M)` with default `[-0.5,+0.5]`
and a ratcheted pre-gesture value `cur_T = +0.9` (a legitimate state: set under raised extremeness, or a
prior mirror-OFF asymmetric edit, then loaded — §1.3 mirror-OFF, §3.3 beyond-cap persists). Mirror ON,
the user does a continuous one-sided drag of `M` that dips inward then back out. Each frame the mirror
step calls `apply_capped(T, req_T)`. Because `T` has no `_drag_start_value` entry, step 1's choke and step
3's bounds fall back to the LIVE stored `cur_T` (§3.2 step 3 third bullet: a control with no held entry is
the "non-gesture … compute `[lo,hi]` from `new` immediately" branch, `:1036-1038`):

- Dip frame: `req_T` mirrors `M`'s inward move, `T` is written to, say, `0.6`. Live `cur_T` is now `0.6`.
- Back-up frame: choke reads live `cur_T = 0.6` ⇒ `hi = max(0.5, 0.6) = 0.6`; a `req_T = 0.85` clamps to
  `0.6`. The held reach to `0.9` is destroyed — the rest of the gesture is trapped on `T`. If `T` is bound
  to a T2/T3 slider, step 4 sets that slider's `max_value = 0.6`, collapsing its range too.

This is byte-for-byte the round-12 MA12-1 / round-11 MA-2 transient-dip ratchet collapse, on the
mirror-twin sub-path. v13 closed it on the *directly-touched* control on both the slider and sculpt
paths; the contralateral twin — written live through the same choke, per frame, by default — was not
brought into the capture rule.

**It is not an edge case.** Mirror ON is the default and a one-sided edit with mirror ON is a primary
intended gesture (§1.3: "When a player edits ONE side of a bilateral or lateral region … the toggle
decides whether that same delta is ALSO applied to the opposite twin"). A ratcheted twin is exactly the
state the held-interval mechanism exists to protect. The twin write is per-frame live (§1.3 says "each
through the same protocol," i.e. the live 4-step protocol, not a commit-only application), so it is
subject to the per-frame transient-dip collapse the rest of v13 was engineered to prevent.

**The gate has the same blind spot.** Gate #1a iv-b/iv-c (`SYNTHESIS.md:1595-1608`) drive the
transient-dip + multi-modifier SCULPT asserts, but only over `decompose_drag`-returned modifiers; none
exercises a mirror-ON one-sided drag whose **twin** is pre-ratcheted and dipped. So the gate as written
cannot detect this — precisely because the twin is not a `decompose_drag` key, the iv-c "each touched
modifier gets its own held `cur_start`" assert never enumerates it.

**Concrete method to confirm.** `morph_drag.gd:325` (`candidates_at(render_vertex)`) returns only the
picked vertex's footprint candidates; the twin's footprint is on the contralateral side, so a one-sided
pick's `decompose_drag` result excludes the twin (verify: `_modifier_footprint[full_name]` keys, built at
`morph_drag.gd:158-172`, are the +pole target's significant render verts — disjoint l-/r- vertex sets for
a lateral modifier). The §1.3 mirror step (`SYNTHESIS.md:601-602,609-610`) writes the twin via the twin
table, not via `decompose_drag`. The v13 capture (`:1019-1025,1101-1102`) keys exclusively on the slider
bound control and `decompose_drag` keys. Therefore `_drag_start_value[twin(M)]` is never written, and the
twin's choke/bounds use the live mid-gesture `cur` — the trap.

**Honest fix direction (not specified by v13).** The held-interval phase signal must follow EVERY write
the gesture makes through the choke, including the mirror-derived twin: when the mirror step is about to
run `apply_capped(twin(M), …)` within an active gesture, first capture `_drag_start_value[twin(M)] = cur`
(guarded `if not has`), exactly as for a directly-touched modifier, and clear it at gesture-end alongside
`M`. (Equivalently: route the twin through the same first-touch capture by treating the mirror application
as "touching" the twin.) v13 names none of this — its capture rule enumerates only directly-touched
controls.

---

## MINOR

### MI13-1 — The deferred extremeness recompute (`_extremeness_dirty`) is specified per the gesture-end handler "that does the settled-value recompute" (i.e. over the gesture's TOUCHED controls), but an extremeness change is an ALL-controls bounds event; the text leaves it ambiguous whether the deferred recompute re-applies bounds to the NON-touched controls at gesture-end.

**Locus:** `SYNTHESIS.md:1177-1188` (the MI12-1 deferred-recompute rule) + the all-controls bounds
re-apply site framing (`:1197-1202`).

The deferred rule says set `_extremeness_dirty` and "run the recompute in the same gesture-end handler
(`drag_ended` / `_end_morph_drag`) that does the settled-value recompute, using the new extremeness …
a single recompute folds in BOTH the settled value AND the new extremeness." The settled-value recompute
operates on the gesture's touched control(s). An extremeness change, however, widens/narrows EVERY
control's interval; the non-touched controls' bounds become stale until *something* re-applies them. This
is NOT a correctness break — non-touched controls have no held interval, so their stale bounds are merely
visually behind by one gesture (they re-apply on their own next edit / on the next extremeness change),
and the choke clamp for any later edit reads the live `cap(control, extremeness)` anyway. So no value is
mis-clamped. It is an underspecification: "run the recompute in the gesture-end handler" should state
whether it re-sweeps all controls (the natural meaning of an extremeness recompute) or only the touched
set. **Suspected harmless; would verify by** confirming the gesture-end handler runs the full
all-controls bounds sweep (the same sweep an immediate, no-gesture extremeness change runs) rather than
only the touched-control settled-value recompute — if it runs the full sweep, this is a non-issue and
should be stated as such.

---

## Load-bearing v13 areas attacked and NOT broken (re-verified against code/assets @ HEAD)

- **MA12-1's DIRECT-TOUCH closure is genuinely sound (the round-12 hole is closed for directly-touched
  controls).** Traced a continuous sculpt drag on a ratcheted modifier `M` (`cur=0.9`, default
  `[-0.5,0.5]`) with a transient dip to `0.6` then back to `0.85`: the v13 sculpt capture writes
  `_drag_start_value[M]=0.9` on first `decompose_drag` touch (`_apply_morph_drag`, `character_creator.gd:
  446-475`, where `_body_state.modifiers` is passed live to `decompose_drag` at `:460-462`), the choke
  then reads held `cur_start=0.9` ⇒ `hi=max(0.5,0.9)=0.9`, so the back-up to `0.85` is admitted, not
  trapped. `decompose_drag`'s own internal clamp (`morph_drag.gd:368`) is to the build-frozen HARD range
  `[rng[0],rng[1]]` (`:173,179`), never the limiting factor here — confirming the cap is correctly applied
  AFTER, at the apply site, exactly as the design states. The direct-touch sculpt path is fixed.

- **Late-entering directly-touched modifier captures its PRE-GESTURE value correctly.** Within a sculpt
  gesture only `decompose_drag`-returned modifiers are written (`character_creator.gd:465-471`), so a
  modifier `M` that first appears partway through a drag has an unchanged `_body_state.modifiers[M]` up to
  that point; capturing `_drag_start_value[M]=cur` on first touch therefore IS its pre-gesture stored
  value, as the design claims (`SYNTHESIS.md:1024-1027`). No stale-capture defect for directly-touched
  late entrants.

- **Sculpt gesture bracket matches the cited code exactly.** `_dragging_morph`/`_drag_vertex`/
  `_drag_hit_pos`/`_drag_accum` set on left-press-with-hit (`character_creator.gd:636-644`); per-motion
  `_apply_morph_drag` (`:660-663`); end via `_end_morph_drag` on release (`:646-648` → `:500-516`). The
  bracket never sets `_drag_pending`, confirming the round-12 premise and the v13 need to key on the
  gesture, not `_drag_pending`. The design's `:632-648` / `:446-475` / `:500` citations are accurate.

- **Slider gesture bracket matches.** `drag_started`/`drag_ended`/`_drag_pending` at
  `character_creator.gd:1052-1059` (headline) and the region equivalent; the design's
  `:1052-1053,1181` capture-site citations are accurate, and the slider held-interval path is sound for
  the bound control.

- **Non-gesture single writes (numeric, headline keyboard step, randomize sample, click step) are
  correctly covered as degenerate one-write "gestures."** A single discrete write has no stream to dip
  through, so reading live `cur` and computing `[lo,hi]` from `new` immediately is correct
  (`SYNTHESIS.md:1036-1038`). The region/headline `value_changed` with `_drag_pending` false is exactly
  this case (`character_creator.gd:1049`). No gap.

- **Restore/load/archetype paths bypass the choke entirely (raw `set_value_no_signal`), so they need no
  held interval.** Paths 6/7/7a (`SYNTHESIS.md:1128-1145`) write RAW; verified every restore path today
  sets `slider.value = v` (`character_creator.gd:1324,1237`) which would re-fire the capped callback,
  making the `set_value_no_signal` raw-bypass genuinely required and correctly motivated. Not a
  held-interval path; no gap.

- **`_extremeness_dirty` deferral has no gap when NO gesture is active.** With no gesture, the
  extremeness change is the normal immediate all-controls recompute (the deferral only triggers under
  `_in_sculpt` or `_drag_pending`, `SYNTHESIS.md:1177-1179`); deferral is purely a conflict-avoidance
  path. No control with a held interval can exist when no gesture is active (`_drag_start_value` is
  cleared at gesture-end), so the choke reads live `cur` and live `cap(control, extremeness)` — correct.
  (The only residual is MI13-1's all-vs-touched ambiguity, which is non-breaking.)

- **DEFAULT CAP RULE (MA-1), derived-interval soundness, gate #11b-by-construction.** Re-confirmed the
  registry shape via round-12's verified parse: no odd ranges / nonzero non-macro defaults, so derived
  `[-f,+f]` (bidirectional) / `[0,f]` (unipolar) contain neutral by construction. `build_accel`
  (`morph_drag.gd:133-156`) reaches every non-macro modifier (`entries = registry.get("modifiers", [])`
  `:138`, KIND_MACRO skip `:148`), so the total `cap(·)` covers the sculpt-reachable set. Unchanged from
  v12; not broken.

- **Core cap formula** — per-pole independence, window axes, beyond-cap persistence, sign-flip block —
  re-derived; unchanged and sound.

- **Belly MI-1, breast-via-volume-axis (b), tangent-on-commit (§5.0), glow ε world-space, eye/gaze
  left-alone, tongue asset-rebake** — re-checked citations; unchanged from prior rounds, no new v13
  interaction. Not attacked further (no v13 change touches them).

- **First-build vs deferred (§10.1).** The deferred items are honestly flagged with seams; none leaves a
  first-build item broken. MA13-1 is NOT a deferral — it is a specified-but-incomplete mechanism (the
  mirror twin is a first-build live write path, §10.1, written through the choke per §1.3, but omitted
  from the v13 capture rule), exactly as MA12-1 was for the sculpt path. The `f` constant / interval
  shapes remain an acknowledged-open authoring item with a sound seam — not a flaw.

---

## Summary

- **MA13-1 (MAJOR):** v13's held-interval capture is keyed on directly-touched controls only (slider
  bound control / `decompose_drag` keys). The §1.3 mirror step writes the contralateral `twin(M)` through
  the SAME live per-frame choke (mirror ON = default) but the twin is never a `decompose_drag` key and is
  not the slider's bound control, so it gets NO `_drag_start_value` held interval. A transient-dip drag
  with mirror ON collapses a pre-ratcheted twin's ratchet — the identical MA12-1 trap, on the mirror-twin
  sub-path. Gate #1a iv-b/iv-c share the blind spot (they enumerate only `decompose_drag`-returned
  modifiers, never a pre-ratcheted twin).
- **MI13-1 (MINOR):** the deferred-extremeness recompute is described via the gesture-end settled-value
  handler (touched controls); the text is ambiguous about whether non-touched controls' bounds are
  re-swept at gesture-end. Non-breaking (the choke always reads live `cap`); underspecified. Suspected
  harmless; would verify by confirming the gesture-end handler runs the full all-controls bounds sweep.
- MA12-1's direct-touch closure (slider + sculpt), late-entering direct-touch capture, the non-gesture
  single-write coverage, the raw restore bypass, the `_extremeness_dirty` no-gesture path, the DEFAULT CAP
  RULE, and the core formula are re-verified sound against the actual code/assets.
