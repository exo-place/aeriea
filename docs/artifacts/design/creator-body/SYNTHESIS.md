# Character Creator + Body — unified design synthesis (v16)

Status: **SYNTHESIS (decided), revision v16** — the single coherent design across the four
design-it-twice candidates, hardened against fifteen rounds of adversarial attack
(`attack-round1.md`..`attack-round15.md`) and adjudicated by verified ground truth
(`facts-round1.md`, `facts-round2.md`, `facts-belly.md`, plus direct re-checks @ HEAD). Where attack and
facts disagree, **the facts govern.** Design artifact only — **no feature code.** Date: 2026-06-23.

**v15 is a TIGHTENING revision.** The core single-value cap formula (`hi=max(b,cur); lo=min(a,cur);
new=clamp(req,lo,hi)`) was re-derived by hand in rounds 9, 10 AND 11, rounds 12–14 attacked only the
held-interval WIRING (not the formula), and it remains **verified sound and UNCHANGED.** Both v15 changes are
contained fixes to the held-interval mechanism's LIFECYCLE and DISPLAY: ONE GENERALIZING FIX that states a
single gesture-lifecycle-interruption invariant (any state-replacing op mid-gesture MUST abort the active
gesture and clear the held-interval map before applying — covering undo/redo/reset/history-jump, archetype/
import load, and extremeness change with one rule, not a per-op list), plus one small DISPLAY rule that a
shared bilateral widget shows the conservative intersection of its two controls' cap intervals. Nothing in
the core model moved.

**v16 (doc-accuracy only):** round-15 doc-accuracy minors folded — design converged (0 blocker / 0 major at v15). mi15-1: the mid-gesture-abort wording now states the SAFETY property (no zombie gesture, no garbled commit; a fresh gesture begins only on the next press) instead of the inaccurate "next input starts a fresh gesture." mi15-2: the conservative bilateral-display rule now documents its resync consequence. Core model and the v15 fixes are otherwise unchanged.

**v15 changes vs v14 (round-14 attack resolutions — contained edits; core cap formula UNCHANGED & verified sound; everything else carried, TIGHTENED):**

- **MA14-1 — THE GESTURE-LIFECYCLE-INTERRUPTION INVARIANT: any STATE-REPLACING operation mid-gesture
  ABORTS the active gesture (clearing the held-interval map) BEFORE applying (the load-bearing generalizing
  fix).** v14 hardened the raw restore/load bypass so it never CAPTURES into `_drag_start_value` (correct:
  `set_value_no_signal` → no `value_changed` → no `apply_capped` → no first-touch capture). Round 14 found
  the SYMMETRIC gap: a raw restore reachable MID-gesture (Ctrl+Z/redo are keyboard events in
  `_unhandled_input`, `character_creator.gd:576-583`, while a left-mouse sculpt drag is held; `_restore_current`
  `:1315-1331` replaces `_body_state.modifiers` wholesale at `:1327`) neither ENDS the active gesture nor
  CLEARS the v14 held-interval map — so the gesture keeps clamping against a STALE `cur_start`, a ratchet the
  restore removed survives, and the drag commits a garbled node. This is a gesture-LIFECYCLE-interruption
  class, DISTINCT from the now-closed write-path (choke-capture) class. Rather than patch the restore trigger
  (a per-op fix the next state-replacing op would evade), v15 GENERALIZES to ONE invariant covering ALL such
  interruptions: **any state-replacing op that can occur mid-gesture — raw restore (undo/redo/reset/history-
  jump), archetype/import load, or an extremeness change — MUST FIRST abort the active edit gesture (clear
  `_drag_start_value`, the in-flight sculpt accumulators `_drag_accum`/`_drag_vertex`, and the gesture
  brackets `_dragging_morph`/`_drag_pending`) and cleanly end the gesture, THEN apply the operation.** After
  such an op there is NO active gesture (the SAFETY property: no zombie gesture, no garbled commit — with a
  button still held the next motion is dead hover, not a gesture); a FRESH gesture begins only on the next
  press, capturing first-touch against the NEW state — no stale `cur_start`, no surviving ratchet the restore
  removed. This
  SUBSUMES the MI12-1 extremeness-mid-gesture handling: extremeness change is one such state-replacing op, so
  v15 collapses the deferred-recompute special case into the single abort rule (one rule for every
  interruption, not a defer-vs-abort split — see §3.2 the lifecycle invariant for why the abort rule is
  consistent and simpler). Stated as a single LIFECYCLE invariant in §3.2 alongside the choke-capture
  invariant; gate #1a #1a-vi asserts a state-replacing op mid-gesture (undo during a held drag) leaves a
  correct, non-garbled node. (§3.2 the lifecycle invariant + the MI12-1/MI13-1 reconciliation; §1.3; §8 #1a
  vi; §10.1.)
- **MI14-1 — a shared bilateral widget DISPLAYS the CONSERVATIVE intersection of its two controls' cap
  intervals.** A bilateral region slider is ONE widget driving TWO controls (L+R; `region_sliders.gd:136-145`
  resolves both, `character_creator.gd:1168-1186` reads `full_names[0]` for display). Under the v14 step-4
  bounds protocol the displayed bounds became one side's (the last-processed resolved name's), so for a
  diverged asymmetric L/R (reachable via mirror-OFF sculpt or an asymmetric imported save) the thumb range
  could exceed the OTHER side's true cap — the exact thumb/value desync the protocol claims to kill, for this
  case. v15 fixes the DISPLAY rule: a shared bilateral widget shows the MORE CONSERVATIVE (tighter) of the
  two controls' current cap intervals — `[max(lo_L, lo_R), min(hi_L, hi_R)]` — so the thumb can't exceed
  either side's true cap. **Per-control held intervals + clamping remain individually correct and unchanged**
  (each of L and R is captured and clamped against its OWN `cur_start` in the choke); ONLY the shared
  widget's displayed `min_value`/`max_value` uses the conservative intersection. (§1.3 slider path; §3.2
  step 4.)
- **First-build (§10.1) re-scanned** for any item depending on a deferred one: none. The lifecycle invariant
  (MA14-1) reuses the SAME gesture brackets + `_drag_start_value` map already in first-build — it adds an
  abort-on-interrupt branch on the EXISTING restore/load/extremeness paths (a simpler mechanism than the
  MI12-1 deferred-recompute it replaces, no new asset); the conservative-display rule (MI14-1) is a one-line
  change to the existing step-4 bounds write on bilateral widgets. The only new harness is the round-14
  mid-gesture-restore assert folded into gate #1a (vi). No dependency on any deferred item. (§10.1.)

**v14 changes vs v13 (round-13 attack resolutions — contained edits; core cap formula UNCHANGED & verified sound; everything else carried, TIGHTENED):**

- **MA13-1 — THE HELD-INTERVAL CAPTURE IS A PROPERTY OF THE CHOKE ITSELF, PATH-AGNOSTIC — ONE INVARIANT
  REPLACES PER-PATH CAPTURE (the load-bearing generalizing fix).** v13 captured the held interval by
  ENUMERATING write sub-paths (the slider's bound control at `drag_started`; each sculpt modifier on its
  first `decompose_drag` touch). Round 13 found the THIRD instance of the same defect class — a
  live-through-the-choke write sub-path lacking a held interval — on the §1.3 MIRROR step: with mirror ON
  (the DEFAULT), the contralateral `twin(M)` is written per frame through the SAME live choke, but the twin
  is never a `decompose_drag` key and is not the slider's bound control, so v13's enumerated capture never
  reached it — a transient-dip drag collapsed a pre-ratcheted twin's ratchet. Rather than patch the mirror
  path (a fourth enumeration that the next cascaded/derived write would again evade), v14 GENERALIZES:
  **the FIRST time `apply_capped(control, …)` is called for a given control within an active edit gesture,
  the choke LAZILY captures that control's held interval `[min(a, cur), max(b, cur)]` from the value at that
  first touch and stores it in the gesture's held-interval map (`_drag_start_value`, guarded `if not
  has(control)`); every subsequent write to that control within the gesture clamps against the held interval;
  bounds recompute at gesture end.** Because capture happens INSIDE the choke on first touch, it
  AUTOMATICALLY covers EVERY control any write path routes through the choke — directly-touched sliders,
  sculpt-decomposed modifiers, the mirror-applied `twin(M)`, numeric, randomize, headline, and any future
  cascaded/derived write — with NO per-path enumeration. **The invariant: any control written through
  `apply_capped` during a gesture uses a held interval captured at its first touch within that gesture.** The
  former per-path capture descriptions (slider-bound-control capture, sculpt first-`decompose_drag` capture)
  are now INSTANCES of this one rule, not separate responsibilities, and the redundant per-path text is
  removed in their favor. Gesture boundaries still come from the active-edit-gesture lifecycle (slider
  `drag_started`/`drag_ended`; sculpt `_dragging_morph`→`_end_morph_drag`; single discrete writes = one-write
  gestures); the held-interval MAP is cleared at gesture end. Gate #1a's per-path dip asserts are replaced by
  ONE path-agnostic assert that holds for ANY control reached during a gesture — incl. a pre-ratcheted mirror
  twin (iv-d) and a sculpt-only modifier — proving the invariant, not an enumeration. (§3.2 step 3 + the
  choke note + path 1 + the slider-bounds paragraph; §1.3 mirror lines; §8 #1a iv/iv-a..iv-d; §10.1.)
- **MI13-1 — gesture-end recompute is the FULL all-controls bounds sweep, not only the touched controls.**
  An extremeness change is an ALL-CONTROLS bounds event, so the deferred (`_extremeness_dirty`) recompute at
  gesture-end runs the SAME full all-controls widget-bounds sweep an immediate extremeness change runs — not
  merely the settled-value recompute over the gesture's touched controls — so a non-touched control whose
  bounds depend on the changed extremeness (the deferred case) is refreshed too. There is NO interim
  correctness gap: the choke ALWAYS reads live `cap(control, extremeness)` at clamp time, so any edit between
  the deferred change and the sweep is already clamped against the new extremeness; only non-touched WIDGET
  bounds are one sweep behind, and the gesture-end full widget-bounds refresh brings them back in sync (a
  display refresh, not a clamp correction). (§3.2 after the slider-bounds paragraph.)
- **First-build (§10.1) re-scanned** for any item depending on a deferred one: none. The choke-capture
  invariant (MA13-1) reuses the SAME `_drag_start_value` dict + choke + slider-bounds write-back — it MOVES
  the capture from per-path write sites INTO the existing `apply_capped` choke (a simpler, fewer-site
  mechanism, no new asset); the gesture-end full sweep (MI13-1) is the same sweep an immediate extremeness
  change already runs. The only new harness is the round-13 mirror-twin transient-dip assert folded into gate
  #1a (iv-d), atop the now-path-agnostic (iv). No dependency on any deferred item. (§10.1.)

**v12 changes vs v11 (round-11 attack resolutions — contained edits; core cap formula UNCHANGED & verified sound; everything else carried, TIGHTENED):**

- **MA-1 — THE DEFAULT CAP RULE: every sculptable modifier is capped (authored-or-derived), so the choke
  covers ALL live write paths without hand-authoring ~280 intervals (the load-bearing fix).** v11 said the
  choke caps "ALL live write paths" AND that authoring is "~56 curated controls + 6 headline axes" — but
  `build_accel` (`morph_drag.gd:133-156`, `entries = registry.get("modifiers", [])` `:138`) proves a sculpt
  drag can write ANY of the ~280 non-macro registry detail modifiers, of which only ~56 had authored
  intervals; the other ~224 had NO defined `cap(·)` ⇒ uncapped sculpt ⇒ no-monster-by-DEFAULT FALSE on the
  T3 sculpt path (or, alternatively, the cost figure understated ~5×). v12 resolves it with a RULE:
  `cap(control, e)` is a TOTAL function — AUTHORED interval if one exists (the ~56 + headline, taste-tuned),
  else a DERIVED interval computed from the modifier's own registry range
  (`[neutral − f·R, neutral + f·R]` clamped to the hard range, `f` a single global default fraction,
  unipolar floor pinned to `a=0`), widened by extremeness exactly like the authored ones. So `apply_capped`
  ALWAYS has an interval (authored if present, else derived) and the choke genuinely caps ALL live write
  paths, including sculpt-reachable uncurated modifiers. Gate #11b (`neutral ∈ [a,b]`) holds for both —
  authored checked numerically, derived BY CONSTRUCTION (symmetric/range-anchored about neutral). The
  authoring cost stays ~56 + headline, NOT 280; §3.1 / §3.2 path 1 / gate #1a / gate #11b / the cost
  framing are corrected. (§3.1, §3.2 path 1, §8 #1a, §8 #11b.)
- **MA-2 — DRAG-AWARE bounds: HOLD slider bounds at the drag-START interval during an active drag;
  recompute only on drag-END / commit / extremeness-change / load (the load-bearing fix).** v11's M9-1
  "recompute slider `min/max` on EVERY edit" collapses a ratcheted slider on a transient mid-drag dip,
  because `value_changed` fires continuously during a drag (`character_creator.gd:1041-1046,1175`):
  recomputing `[lo,hi]=[min(a,new),max(b,new)]` from the live mid-drag `new` sets `max_value` below the
  ratcheted reach when the gesture momentarily dips below `b`, trapping the rest of the drag. v12 HOLDS the
  bounds fixed at `[min(a,cur_start), max(b,cur_start)]` (the value captured at `drag_started`, in a new
  `_drag_start_value` dict alongside the existing `_drag_pending` write) for the whole gesture, and the
  CHOKE clamps mid-drag against the SAME held interval (so a request back up toward the ratcheted reach is
  admitted, not trapped). Bounds recompute from the settled `new` only on `drag_ended` / commit (and on
  extremeness change / load) — the one place the ratchet collapses inward, once per gesture, on the
  committed value. Mid-drag value writes still go through the cap via `set_value_no_signal`. The B10-1
  no-re-fire ordering (bounds-first-then-`set_value_no_signal`) is unchanged. The drag-start-vs-commit
  timing is stated precisely in the §3.2 protocol. (§3.2 steps 3/4 + the bounds-recompute paragraph.)
- **MI-1 — belly recipe REFERENCES the existing waist slider, does NOT re-add `waist-circ`.** §2 v11 listed
  `measure/measure-waist-circ` under a net-new belly "fullness" control, but it ALREADY ships as the "waist"
  slider (`region_sliders.gd:63`) — a two-thumb-one-modifier duplicate (the defect v10 fixed for
  `stomach-tone`). v12 fixes the belly group to: KEEP/relabel the existing tone (`:58`) and reference the
  existing waist (`:63`) sliders, and ADD only the genuinely net-new `torso/torso-scale-depth`
  (belly-forward) plus the Weight/apple fat axes. **No modifier is driven by two controls.** The
  anti-duplicate rule is extended to `waist-circ`. (§2.)
- **First-build (§10.1) re-scanned** for any item depending on a deferred one: none. The DEFAULT CAP RULE
  (MA-1), the drag-aware bounds (MA-2), and the belly reference fix (MI-1) are refinements of already-first-
  build items (the choke + caps asset, the slider-bounds write-back, the §2 belly surfacing) — no new asset,
  no new harness beyond an uncurated-modifier sculpt assert + a transient-dip drag assert folded into gate
  #1a, no dependency on any deferred item. (§10.1.)

**v11 changes vs v10 (round-10 attack resolutions — INTEGRATION-BOUNDARY last-mile fixes only; core cap formula UNCHANGED & verified sound; everything else carried, TIGHTENED):**

- **B10-1 + M10-2 — THE COMPLETE LIVE-EDIT WIDGET WRITE-BACK PROTOCOL is now SPECIFIED as an exact
  ordered sequence (the load-bearing fix).** v10 said "recompute slider `min/max` on every edit" but never
  specified how the outward-CLAMPED `stored` value reaches the thumb/label — leaving either (a) a thumb/value
  DESYNC (thumb shows the pre-clamp request, model holds the clamped value) or (b) a re-entrant
  `value_changed` → re-bake FEEDBACK LOOP (setting `max_value < value` makes Godot `Range` clamp `value` and
  EMIT `value_changed`, re-entering the live callback → another 14,517-vert bake). v11 defines the **exact
  four-step ordered protocol** for every LIVE write path (sculpt drag, region slider, numeric entry,
  headline field, randomize — paths 1–5) (§3.2):
  1. `new = apply_capped(control, requested)`.
  2. Write `new` to the model via the real write site (`_set_modifier` for modifiers — honoring
     erase-at-neutral; `set(field, new)` for headline fields).
  3. Compute the widget interval `[lo, hi] = [min(a, new), max(b, new)]`.
  4. Apply to the widget WITHOUT re-firing: set `min_value = lo` and `max_value = hi` **FIRST** (widened to
     contain `new`, so the subsequent value write can never be out of range and Godot's `Range` cannot
     clamp-and-emit), **THEN** `set_value_no_signal(new)`; update the numeric label/field to display `new`
     (read `new`, NOT `slider.value` and NOT the pre-clamp request).
  Because the write-back uses `set_value_no_signal`, the `value_changed` callback does NOT re-enter ⇒ **no
  re-bake feedback loop** (B10-1 resolved). Because the thumb AND the label both show `new` (the clamped
  stored value), there is **no desync** and the "gating is VISIBLE at the slider, not a hidden lie"
  property (§1, §3.5) now has a REAL mechanism: the label reads the clamped `new`, not the pre-clamp
  request (M10-2 resolved). This protocol applies to EVERY live write path (1–5); restore/load (paths 6–7)
  already use the raw `set_value_no_signal` bypass and are unchanged. (§1.3, §3.2.)
- **M10-1 + m10-2 — DEFAULT-INTERVAL-CONTAINS-NEUTRAL invariant, asserted by gate #11 for EVERY control.**
  v10's M9-2 erase reconciliation rested on "every default interval contains the control's neutral," but
  §3.1's own unipolar shape menu offered `[min, b0]` with `min > 0` — a floor ABOVE the unipolar neutral 0.
  For such a control, the absent→neutral read (`cur = 0`) gives `lo = min(a, 0) = 0`, silently RATCHETING
  the floor open from `a` down to `0` with no beyond-interval value ever authored. v11 REQUIRES that **every
  control's default interval CONTAINS its neutral/absent value — `a ≤ neutral ≤ b` for all controls** (for
  unipolar modifiers neutral = 0, so `a ≤ 0 ≤ b`, typically `a = 0`; the `[min>0, b0]` shape is FORBIDDEN).
  The build-time gate (#11) is EXTENDED to assert `neutral ∈ [a,b]` for EVERY control (not just that
  archetypes lie within intervals) — closing the m10-2 gap that gate #11 could only iterate an archetype's
  present sparse keys, leaving absent-but-clamped-floor controls unchecked. `apply_capped` reads absent as
  neutral, and this invariant GUARANTEES absent values need no ratchet. (§3.1, §3.2, §8 #11.)
- **m10-1 — the "adds nothing to the bake hot path" claim is QUALIFIED with its dependency.** It holds
  BECAUSE the live write-back uses `set_value_no_signal` (no `value_changed` re-entry → no extra
  `_apply_state` bake). v11 states the dependency explicitly: the no-extra-bake property is a CONSEQUENCE of
  the B10-1 protocol's step 4, not free. (§0, §3, §5.0.)
- **m10-3 — the already-shipping navel rows (`region_sliders.gd:59,60`) placed explicitly in the tier split
  (T3 fine detail).** §2's concrete step list now states where `:59`/`:60` land in the T2-vs-T3 split (§2,
  §1.2 T3).
- **First-build (§10.1) re-scanned** for any item depending on a deferred one: none. The B10-1 protocol and
  the M10-1 invariant are refinements of already-first-build items (the choke, the slider bounds, gate #11),
  not new dependencies. (§10.1.)

Scope: the player-facing character creator and the body system it edits — editing model, gating,
**bounds (the finalized cap model: raw modifiers + one global extremeness, a derived NEUTRAL-AGNOSTIC
per-control allowed interval, one capped-write choke over ALL live write paths + a raw bypass for
restore/load + the TWO distinct load paths — within-default-interval archetypes vs raw-preserve user
saves, v10 B9-1)**, breast-size semantics, belly semantics, visual fidelity (skin / eyes / brows), camera +
persistence, the VR dependency, and a concrete testable quality bar. **§10 is the execution-scope split
(first build vs deferred) — the user is now prioritizing.** Out of scope (named as dependencies, not
designed here): the OpenXR/stereo/controller VR workstream; the offline normal/AO baker toolchain
(sub-decision flagged); authoring the ~15–18 archetype roster content; the pregnancy *simulation* (0%
built — §2 deliberately does not depend on it); the **combination-plausibility model (explicitly
DEFERRED, §3.4 — seam reserved, not built in the first build).**

**v10 changes vs v9 (round-9 attack resolutions — INTEGRATION-BOUNDARY fixes only; core cap formula UNCHANGED & verified sound; everything else carried; superseded where v11 tightens):**

- **B9-1 — ARCHETYPE LOAD AND USER SAVE/LOAD ARE TWO DISTINCT LOAD PATHS WITH DIFFERENT GUARANTEES (the load-bearing fix).**
  v9 routed BOTH first-party archetype picks and user saves through the SAME raw restore path (§3.2 path 7),
  so picking a `heavy`/`curvy` archetype at extremeness 0 — the single most common first action — could
  land the user beyond the default cap with the slider ranges silently ratcheted open, contradicting the
  central "no-monster-by-DEFAULT" guarantee. v10 SPLITS the path:
  - **ARCHETYPES (first-party T0 starting points) MUST be authored WITHIN every control's DEFAULT interval `[a,b]`.**
    A **BUILD-TIME validation (gate #11) asserts every shipped archetype's every value lies within that
    control's default interval `cap(control, 0)`** and FAILS THE BUILD otherwise. So picking ANY archetype
    at extremeness 0 can NEVER land beyond the default cap — the archetype IS within-cap data by construction,
    and routing it through the raw path is therefore equivalent to the capped path at extremeness 0 (no
    ratchet opens). Archetypes are still loaded RAW (one code path), but the build gate guarantees raw==capped
    for them at e=0.
  - **USER SAVE/LOAD (the user's OWN prior creation) preserves RAW and MAY be beyond cap** — if the user made
    it with extremeness raised. That is THEIR creation, not a default starting point; this is the legitimate
    beyond-cap-persists case (the inward ratchet is consistent across set/save/load). **Imported external
    user saves are treated like user saves (raw-preserve).**
  - **The "no-monster-by-DEFAULT" guarantee is made EXPLICIT in scope:** it covers (i) the DEFAULT new
    character and (ii) ARCHETYPE PICKS (both within default intervals, gate #11). It does NOT cover what a
    user DELIBERATELY made with extremeness raised and reloaded — that is their creation, by design.
  Updated §1.1, §3.2 path 7, §3.3, §6, §10 consistently.
- **M9-1 — SLIDER `min_value`/`max_value` RECOMPUTED FROM `[min(a,cur), max(b,cur)]` ON EVERY EDIT.** v9
  re-applied slider bounds on only two triggers (extremeness-change, beyond-cap-load), but the ratchet
  ceiling `hi=max(b,cur)`/`lo=min(a,cur)` moves with `cur` on EVERY inward edit, re-introducing the very
  thumb/value desync m8-1 claimed to fix (drag a ratcheted thumb down, then back up past the new `cur`-driven
  ceiling). v10 recomputes the slider's `min/max` from `[min(a,cur), max(b,cur)]` on EVERY edit (bind it
  dynamically each time the value changes), so the thumb range always matches the LIVE cap interval (§1.3, §3.2).
- **M9-2 — `apply_capped` RECONCILED WITH THE REAL WRITE SITE's erase-at-neutral optimization.**
  `_set_modifier` (`character_creator.gd:1209-1214`) erases any modifier at `|v| < 1e-6` rather than storing
  it. v10 specifies that `apply_capped` reads `cur` as **"the stored value, or the control's NEUTRAL if
  absent"** (modifier-space neutral = the registry default the read site already supplies via
  `modifiers.get(fn, 0.0)`; headline-field neutral = the field default), and that the erase-at-~neutral is
  CONSISTENT with the ratchet: a near-neutral value is within EVERY default interval, so erasing it loses no
  ratchet (the absent→neutral read reproduces the same `cur`). "Store the raw result" is reconciled with the
  erase optimization explicitly (§3.1, §3.2).
- **M9-3 — DEFAULT-INTERVAL AUTHORING COST stated honestly as net-new first-build work.** Authoring an
  `[a,b]` for each of the ~56 curated controls (plus the 6 headline axes) in non-uniform units is real
  first-build work — interval-SHAPE design (which axis is a window, which a one-sided band, where a unipolar
  floor sits), not a one-liner. The §8 #1b per-control sweep validates each interval is individually
  reasonable, but its acceptance boundary ("human + tasteful stylized range") is partly USER-TASTE-GATED
  (per the v3 visual-taste-is-user-gated principle), NOT fully objective — so default-interval sign-off is a
  USER call, consistent with green-is-user-granted. WHERE the intervals live is the caps asset (already named
  net-new); only the numeric values + final sign-off are deferred to the tuning/taste pass (§3.1, §8 #1b, §10.1, R6).
- **m9-1 — `set_value_no_signal` precedent path corrected to `scripts/ui/options_menu.gd:46`** (§0, §3.2).
- **m9-2 — belly: NO duplicate tone control.** `region_sliders.gd:58` ALREADY ships `stomach-tone` ("abs
  tone"). v10 RETIRES only the `:57` pregnant "belly" slider, KEEPS/relabels the existing `:58` tone axis,
  and ADDs waist-circ/torso-depth/Weight/apple as the fuller belly set — no duplicate tone control (§2).
- **m9-3 — resolved by B9-1:** archetypes within default intervals ⇒ a randomize-from-archetype-seed at
  extremeness 0 cannot be beyond cap (the seed `cur` is within `[a,b]`, so `hi=b`/`lo=a`) (§1.3, §3.3).
- **m9-4 — UX note: a one-pole-ratcheted slider shows an ASYMMETRIC range intentionally.** A small
  **cap-vs-ratcheted-extent marker** (a tick at the default `a`/`b` endpoint inside the widened track) makes
  the lopsided range legible (§3.2, named minor UX).
- **First-build (§10.1) re-scanned** for any item depending on a deferred one: none. The new gate #11
  (archetype within-default-interval) depends only on the caps asset (itself first-build) and the archetype
  roster (its acceptance criterion is the SAME default intervals the rest of the build authors). (§10.1).

**v9 changes vs v8 (round-8 attack resolutions — the cap model rebuilt complete & neutral-agnostic; everything else carried, TIGHTENED):**

- **B8-1 + B8-3 — CAP MODEL REPLACED WITH ONE NEUTRAL-AGNOSTIC, PER-POLE, RATCHETED CLAMP (the load-bearing fix).**
  v8's two formulas (the bidirectional `clamp(req, ±max(|cur|,c))` magnitude clamp and the unidirectional
  `min(req, max(cur,c))`) both **silently assumed neutral = 0** — so they produced nonsense on the six
  HEADLINE axes whose neutral is NOT 0 (masculinity 50, weight 100, proportions 0.5, height 166.6, age =
  a window, B8-1), and the single symmetric magnitude ceiling let a magnitude ratcheted on ONE pole
  re-admit the OPPOSITE pole beyond cap (free sign-flip across 0, B8-3). v9 DELETES both and replaces
  them with **ONE formula for every axis type** (§3.2). Each control has a **DEFAULT ALLOWED INTERVAL
  `[a, b]`** in its own units; the global extremeness gate WIDENS `[a,b]` toward the control's hard range;
  the clamp is per-pole-ratcheted: `hi = max(b, cur)`, `lo = min(a, cur)`, `new = clamp(req, lo, hi)`.
  Neutral is irrelevant — it is just the interval. Each pole ratchets INDEPENDENTLY (`hi` from `cur`'s
  excess above `b`, `lo` from `cur`'s excess below `a`), so a value ratcheted high CANNOT sign-flip to a
  beyond-floor low (fixes B8-3); neutral≠0 and no-neutral (age) axes work (fixes B8-1). Outward beyond
  `[a,b]` hard-clamps; inward toward the interior is free; beyond-interval stored values persist and
  reduce freely. (Resolves B8-1, B8-3; the emergent inward ratchet now holds across the whole range.)
- **B8-2 — RESTORE/LOAD PATHS WRITE RAW VIA `set_value_no_signal`; only LIVE EDITS go through the choke.**
  v8 claimed history-restore "DOES NOT clamp," but `_restore_current` / `_do_undo` / `_do_redo` /
  `_jump_to_node` / `_reset_all` set `slider.value = v` (`character_creator.gd:1315-1331,1324,1237`),
  which RE-FIRES the live capped `value_changed` callbacks (`:1046,1175`) and would re-clamp persisted
  beyond-cap values at extremeness 0 — contradicting §3.3 / gate #4. v9 specifies the LIVE-vs-RAW split
  precisely (§3.2): LIVE edits go through the `apply_capped` choke; ALL restore/load paths write the
  model RAW and update widgets via `set_value_no_signal` (the Godot setter that bypasses
  `value_changed`, already used at `options_menu.gd:46`), so the capped callback never fires and
  beyond-cap values PERSIST. Both path sets enumerated (§3.2).
- **m8-1 — SLIDER `min_value`/`max_value` TRACK THE LIVE CAP INTERVAL `[lo, hi]`.** v8 left slider bounds
  at the hard registry range, so the thumb could travel past the cap while the stored value clamped — a
  visible thumb/value desync. v9 specifies that each slider's `min_value`/`max_value` reflect the CURRENT
  cap interval `[lo, hi]` (including ratchet), re-applied when extremeness changes and when a beyond-cap
  value is loaded (§1.3, §3.2), so the thumb cannot travel past the cap.
- **m8-2 — §2 EXPLICITLY RETIRES the live `stomach-pregnant` "belly" slider** (`region_sliders.gd:57`)
  and replaces it with the real belly axes (stomach-tone / waist-circ / torso-depth) — flagged as a
  concrete step in executing "pregnancy out of base creation" (§2).
- **m8-3 — gate #1a re-stated against the §3.2 interval invariant** (`lo ≤ stored ≤ hi`), not v8's
  neutral-0 magnitude invariant which B8-1 showed wrong for headline axes (§8 #1a).
- **m8-4 — picker path corrected** to `scripts/util/cpu_accel_picker.gd` (§1.3, §5.5).
- **First-build (§10.1) re-scanned** for any item depending on a deferred one: none (§10.1).

**v8 changes vs v7 (round-7 attack resolutions — targeted, mostly-mechanical; everything else carried, TIGHTENED):**

- **B7-1 — CAP MODEL FIXED PER AXIS TYPE (the load-bearing fix).** v7's single-`min` clamp
  `new = min(req, max(cur, c))` only bounds ONE pole. ~46 of 56 curated controls are
  **bidirectional `|decr|incr|` axes** — one signed scalar in `[-1,1]` where BOTH directions
  away from 0 are "outward" (`region_sliders.gd:16-19`), incl. the flagship
  `breast/breast-volume-vert-down|up`. v8 makes the cap a per-axis-type rule (§3.2):
  - **Bidirectional axis:** the cap is a **MAGNITUDE** `c ≥ 0`; the value is two-sided-clamped
    to `[-max(|cur|,c), +max(|cur|,c)]`. "Outward" = increasing `|value|` (either pole);
    "inward" = toward 0. Outward input clamps at `±c`; inward (toward 0) is free; a stored
    `|value| > c` persists and reduces freely.
  - **Unidirectional axis:** the v7 one-sided clamp, unchanged.
  The one-way inward ratchet still EMERGES for both. (Resolves B7-1; also resolves m7-3 —
  randomize samples within `±c` for bidirectional.)
- **B7-2 — ONE CAPPED-WRITE CHOKE COVERS ALL WRITE PATHS.** v7's "two write sites" omitted the
  six HEADLINE axes, which write `BodyState` FIELDS via `set()`
  (`character_creator.gd:1047,1323` → `body_state.gd:787-792`), bypassing the modifiers-only
  clamp. v8 routes **EVERY** parameter write — sculpt deltas, region sliders, headline-axis
  fields, numeric entry, randomize, archetype/history live-edit — through **ONE capped-write
  choke** `apply_capped(control, requested) -> stored` that applies `cap(control, extremeness)`
  per axis type (§3.2). One clamp site, fed the live derived cap; write paths enumerated.
- **B7-3 — FIRST-BUILD GATE #1 NO LONGER ASSERTS NO-SELF-INTERSECTION.** Self-clip is
  DEFERRED/monitoring-only (§10.2); a first-build gate may not depend on it. Gate #1 is
  rewritten to what is buildable first (§8 #1): (a) OBJECTIVE cap-enforcement across all write
  paths; (b) default-mode plausibility = conservative default caps validated by the per-control
  sweep; (c) a default-mode combined-extreme RENDER that is USER-judged (taste-gated, not an
  automated self-intersection pass). Self-intersection moved to deferred monitoring. §10.1
  re-scanned for any other first-build→deferred dependency (none beyond this one).
- **m7-1 — NET-NEW first-build cost flagged.** The dihedral faceting metric (gate #8a) and the
  caps asset (`assets/body/caps*`, gate #5) are NET-NEW with zero existing code/asset; v8 marks
  them as build-from-scratch harnesses/assets, not near-existing (§8, §10.1, R6).
- **m7-2 — breast volume count citation FIXED.** It is **down=244 / up=369**
  (`base_body_detail.index.json:159-160`); v7 had it reversed. Corrected in §0 and §4.

**v7 changes vs v6 (round-6 attack resolutions + user prioritization decisions):**

- **A — BOUNDS MODEL FINALIZED (resolves round-6 B1, B3, M1, M2, M3).** The cap model is now stated as a
  concrete state model with a single integration point, dissolving v6's "clamp to the current cap" vagueness:
  - **State (resolves B1/B3):** store the RAW modifier values in `BodyState.modifiers` (unchanged bare
    `{full_name: float}` schema) plus **ONE global `extremeness` value** (a single scalar on the
    creator-settings layer — see §3.1 for which layer). There is **NO per-control cap state, NO
    per-control ratchet state, NO "was-this-authored-under-extremeness" flag.** The cap is **DERIVED**:
    a pure function `cap(control, extremeness)` over the versioned cap table — never stored per value.
  - **Scope DECIDED — GLOBAL, not per-control (resolves B3).** ONE creator-level extremeness control
    (a toggle "Allow extreme proportions" and/or a 0..1 slider). Per-control extremeness is rejected:
    the global flag is the single, visible, deliberate unlock, and a single recorded scalar round-trips
    cleanly (no per-control save schema, dissolving B3's round-trip contradiction).
  - **Behavior — input-layer clamp + raw storage; the inward ratchet EMERGES (resolves B1/M1/M2).** The
    clamp lives at exactly ONE place — the **input layer**, where new outward input is written to
    `modifiers` (§3.2). New OUTWARD input is clamped to `cap(control, extremeness)`; INWARD/reducing
    input is never clamped; a stored value already beyond the current cap is **NEVER snapped down**. The
    "one-way inward ratchet" is not extra state — it emerges from "clamp only new outward input + store
    raw + never re-clamp what's already stored." Stated precisely in §3.2.
  - **No versioned-cap retune migration of stored values (resolves M2).** Because caps are DERIVED, not
    stored per value, a cap retune does not snap any stored value. The cap version is still recorded for
    replay determinism (§3.3), but there is no "re-clamp old saves respecting per-control authored-flag"
    machinery — that machinery (and the M1/M2 contradiction it created) is **DELETED**.
- **B — COMBINATION-PLAUSIBILITY DEFERRED, seam reserved (resolves B2/B4/M4 honestly).** v6's "sum of
  caps bounds the stack" claim is **REMOVED** — it is a loose, often-meaningless bound and does NOT
  prevent grotesque combinations (B2 was right). The eventual guardrail against grotesque COMBINATIONS
  is a **combination-plausibility model** (a validity model over modifier combinations, toggleable OFF).
  Per user decision it is **DEFERRED / NOT in the first build (low priority to build)**. v7 **RESERVES
  the seam** (a post-composition validity check that can nudge/warn, toggleable) but builds nothing
  there. **In the interim (first build), grotesque combinations ARE possible — accepted (§3.4).** Default
  mode stays plausible ONLY via conservative per-control default caps (each individually reasonable), NOT
  via any combination guarantee. The §8 #1 sweep is repurposed to validate DEFAULT-mode per-control caps
  are individually reasonable — **not** a combination guarantee.
- **C — "Controls mean what they say" claim CORRECTED (resolves M3 + clarifies M3-the-cap-question).**
  Two parts: (1) v7 stops over-claiming the property — it **owns** that the default mode is
  bounded-by-default-with-a-visible-global-unlock; the numeric field clamps to the current cap and that
  is honest, gated behavior, not a hidden lie (§1, §3.5). (2) v7 states the distinction the prompt asks
  for: per-control caps are each control's OWN fixed (extremeness-derived) hard stop — a control's hard
  stop **never changes based on other controls**, only on the global extremeness. This is explicitly
  DIFFERENT from the rejected mechanism A ("shrink a slider's range because OTHER controls moved").
- **D — FACETING / Quest honesty (resolves M5).** Subdivision SETTING for faceting (verified via the
  independent dihedral metric, gate #8) is kept. **On Quest (subdivision off/low) extreme morphs MAY
  facet — a known platform fidelity limit; extreme mode is allowed but NOT guaranteed smooth on Quest.**
  v7 does NOT pretend gate #9 covers it (no XR/Mobile build exists). Self-intersection stays a KNOWN
  flagged limit, monitoring-only — reinforced now that grotesque combinations are allowed in the interim.
- **E — EXECUTION SCOPE section ADDED (§10).** The user is prioritizing; v7 splits FIRST BUILD vs
  DEFERRED explicitly, with justification.
- **F — CARRY (verified-held, survived round 6):** gaze left alone (eyes track via `eye.L`/`.R` bones);
  belly = surface existing morphs (no new asset, no pregnancy); mirror = resolution always + toggle
  governs contralateral application only; eye = procedural iris look (user-taste-gated) + eye-color
  uniform, cornea parallax optional/deferred; tangents rebaked on commit (drag-time approximate,
  user-judged); tongue rest-offset = asset re-bake (named cost); glow ε world-space; picker rebuild
  owner-driven. Round 6's "Areas attacked and NOT broken" list independently re-verified each of these.

Grounded in `facts-round1.md` + `facts-round2.md` + `facts-belly.md` and direct re-verification @ HEAD
of `scripts/body/body_state.gd`, `region_sliders.gd`, `morph_drag.gd`, `character_creator.gd`,
`detail_library.gd`, `tools/body_converter.gd`, `assets/body/modifier_registry.json`,
`assets/body/eye.gdshader`, `scripts/body/face/face_rig.gd`, `scripts/body/face/gaze_rig.gd`,
`assets/body/base_body_detail.index.json` (the **body** library, render_vertex_count 14517),
`assets/body/base_body_proxies_detail.index.json` (the **proxy** library, render_vertex_count 1219),
`assets/body/base_body_proxies.index.json` (the proxy geometry index — no targets).

---

## 0. Verified ground truth (what this design stands on)

Re-checked against the facts files and re-parsed @ HEAD; load-bearing.

- **Proxy morph-follow is VERIFIED FIXED (facts-r1 #1).** Eyes/teeth/tongue/brows follow the gender
  morph: isolated-masculinity sweep moves eyes **0.072 m** (0→50) / **0.145 m** (0→100), teeth
  0.069/0.138, all `identical0v100 = false`. `tests/body_proxy_test.gd` passes 46/0 incl. the
  eyes/brows-follow asserts. Kept as a render regression guard (gate #2), not as evidence of a defect.
  - **Scope:** the **proxy** detail library (`base_body_proxies_detail.index.json`,
    render_vertex_count 1219) carries 719 targets = 188 macro anchors + 531 detail; only **9 of 719**
    are full proxy-vert coverage, **400 of 719 are dead (`count==0`)**. The morph-follow conclusion
    holds for the gender-driving macro axes (the nonzero deltas on the proxy verts they touch).
- **`present` flags are NOT a live/dead signal; they live inside each modifier's `targets[]`.**
  `modifier_registry.json` has **291 modifiers** and zero modifier-level `present` keys; the 531
  `present:false` flags live inside `targets[]` (`{"which":"max","path":...,"present":false}`) — 531
  false / 0 true, an artifact of building against the vendored CC0 macro subset. The **real live/dead
  signal is the delta-library `count`**: `count==0` ⇒ dead (`detail_library.gd:76,93`;
  `proxy_morph.gd:113`). The dead-control guard (§4) keys on **delta-library `count`** and walks the
  `targets[]` shape, never a modifier-level `present`.
- **Body vs proxy detail index — two files:**
  - `base_body_detail.index.json` — the **BODY** library, render_vertex_count **14517**: 719 targets,
    188 macro + 531 detail; 14 dead; 8 at full-body coverage.
  - `base_body_proxies_detail.index.json` — the **PROXY** library, render_vertex_count **1219**: 719
    targets, 188 macro, 9 at `count==1219`, 400 dead.
  - `base_body_proxies.index.json` — the proxy **geometry** index, no targets.
  The dead-control guard (§4) runs against the index the control actually binds (eyes/teeth/tongue live
  in the proxy library).
- **Tangents are NOT rebaked under morph (facts-r1 #6).** `bake_morphed_normals`
  (`body_state.gd:634-725`) writes `ARRAY_VERTEX` + `ARRAY_NORMAL` only (`:719-720`); `ARRAY_TANGENT`
  is never recomputed. A tangent-space skin normal map shears under the large morphs the creator
  exists to make. **Hard prerequisite to all skin-map work (§5.0).** The converter computes tangents
  per-render-vertex via Lengyel and **deliberately does NOT weld across UV seams**
  (`body_converter.gd:222-224`), whereas the normal rebake **does** weld. The tangent rebake must
  follow the *converter's* seam-split path — mirroring the normal weld would re-introduce a seam.
- **`breast/BreastSize` is a dead macro** (`kind:"macro"`, `targets:[]`; `_project_modifiers` skips
  `KIND_MACRO` `body_state.gd:551-552`; `data/targets/breast/` empty). The live size control is the
  bidirectional `breast/breast-volume-vert-down|up` axis (body library `count` **down=244 / up=369**,
  `base_body_detail.index.json:159-160`).
- **Belly axes exist and are already imported (facts-belly.md).** The earlier "only the pregnancy morph
  isolates belly volume" claim is **FALSE**. The body library carries, all distinct from
  `stomach-pregnant` and all already vendored: `stomach/stomach-tone-decr|incr` (incr 175/decr 199 —
  abs definition ↔ soft slack), `measure/measure-waist-circ-decr|incr` (879 — belly girth),
  `torso/torso-scale-depth-decr|incr` (incr 1651 — belly forward depth), the `macrodetails-
  universal/Weight` macro (whole-body fat; `…maxweight` rounds the abdomen), `bodyshapes-elvs-fem-apple`
  / `-man-apple` (fem 2894 / man 1891 — central-fat pot belly), plus `stomach-navel-in|out`,
  `stomach-navel-down|up`, and `hip-scale-horiz|depth` / `hip-trans-out` (love-handles). The only gap
  is **semantic/UI surfacing** (upstream desc strings are empty) — a design task, **not** an import or
  asset-authoring task. Resolved in §2.
- **Deltas pure-SUM; there is NO apportionment, and NO per-vertex total bound (facts-r2 Q3).**
  Application is pure addition (`detail_library.gd:104` `morphed[ri] += Vector3(dx,dy,dz)*weight`; blend
  axes accumulate the same, `body_state.gd:664-665`). Per-modifier value is clamped to its OWN range
  only (`to_blend_weights`/`_project_modifiers`); no cumulative or per-vertex displacement bound exists
  anywhere. **v7's bounds model lives entirely on the per-control value (the cap clamp at the input
  layer) — it never adds a per-vertex composition-stage clamp.** Because composition is pure-sum,
  grotesque COMBINATIONS are reachable even when every control is individually capped — this is exactly
  why combination-plausibility is its own (deferred) concern (§3.4), NOT something the per-control caps
  solve. v7 states this honestly rather than claiming "sum of caps" prevents monstrosity.
- **Headline macro axes are NONLINEAR in their own weight (verified).** Per macro cube target,
  `to_blend_weights` emits `_universal_target_weight = Π anchor_val(token)`
  (`body_state.gd:423-432,471-491`); the anchor vals are nonlinear splits (`_age_vals` piecewise via the
  CDC `_stature_age_macro` remap; `_muscle_vals`/`_weight_vals` `max(0,2x−1)` hinges;
  `_proportions_vals` hinge). A vertex's displacement from a headline axis is a multilinear product of
  several axes. **In v7 this does not matter for the cap mechanism** — caps clamp the per-control
  *value*, never attempt to predict or clamp the composed vertex displacement, so macro nonlinearity is
  irrelevant to bounds. (It still matters for §3.6 faceting, which is why faceting is its own concern.)
- **The bake is the interactive hot path (facts-r1 #5).** A sculpt drag → `_apply_state` →
  `bake_morphed_normals` runs **every mouse-motion frame** over all 14,517 render verts (delta sum,
  triangle normal pass, scatter). **The cap adds NOTHING to this path** — the cap is enforced upstream at
  the input layer (modifier-space) where the value is written, so the hot path is exactly as it is today
  plus the §5.0 commit-time tangent rebake. **This no-extra-bake property DEPENDS on the v11 live-edit
  write-back protocol (§3.2, round-10 B10-1/m10-1): the clamped value is written back via
  `set_value_no_signal`, so the live `value_changed` callback does NOT re-enter and trigger a second
  `_apply_state` bake.** Were the write-back to set `max_value < value` and let Godot's `Range`
  clamp-and-emit `value_changed`, the live edit WOULD re-fire `_apply_state` — an extra hot-path bake per
  outward-clamped edit. The protocol's step-4 ordering (bounds widened to contain `new` FIRST, then
  `set_value_no_signal`) is what keeps the claim true; it is a consequence of the protocol, not free.
- **The sculpt drag path is MODIFIER-SPACE (facts-r2 Q2).** `decompose_drag`
  (`morph_drag.gd:319,361-372`) returns `{full_name: value_delta}` — registry full_names → scalar value
  deltas; the apply path (`character_creator.gd:460-471`) writes them as `cur + delta`. **There is NO
  per-vertex displacement in the drag path** — so a cap is a clamp on the scalar value, applied at the
  input layer where the value is written (§3.2), and the sculpt-mirror is modifier-space (§1.3). (The
  *spatial inputs to* the decomposition — pick + locality — DO read vertex positions, the stale-neutral
  defect, B2 / §5.5.)
  - **B1 RESOLUTION (round 6):** round 6 was right that `decompose_drag`'s internal clamp is against a
    BUILD-FROZEN `rangef` copied into per-vertex candidate dicts (`morph_drag.gd:156,173,178-179`) — that
    clamp **cannot learn the live cap**. v7 does NOT try to make it. The cap clamp is NOT inside
    `decompose_drag`; it is at the **single input-layer apply site** (`character_creator.gd:460-471` for
    sculpt, the slider/numeric write for sliders), where the per-control value lands in `modifiers`
    (§3.2). `decompose_drag` keeps clamping to the modifier's hard registry range (its job — keep deltas
    in-range); the *cap* is applied AFTER, when the resulting value is written. One cap site, fed the
    live derived `cap(control, extremeness)`. This is the concrete executable method round 6 found missing.
- **Sculpt spatial data is read from the FROZEN NEUTRAL mesh (verified).** `_glow_base_pos` is captured
  once at build from the neutral bind-pose arrays (`character_creator.gd:242-243`) and never re-read; it
  feeds the CPU picker (`:248,383`), the locality decomposition `positions` (`:461`), and the glow
  overlay (`:434`). On a heavy morph, picking + locality operate on stale neutral positions, so a drag
  grabs the wrong region. `_apply_state` calls `_cpu_picker.mark_dirty()` but a dirty rebuild re-reads
  the same neutral array. Resolved in §5.5 / §1.3.
- **Persistence read side EXISTS (facts-r1 #4).** `creator_io.gd` has `parse_payload`,
  `extract_history_from_png`, `extract_history_from_image`, round-trip tested. The only missing piece
  for raw import is scene wiring. `from_dict` (`body_state.gd:785-797`) copies modifier values
  verbatim — but headline axes AND per-modifier values are **already clamped at projection**
  (`to_blend_weights`/`_project_modifiers`; unknown keys dropped `:546`) to the modifier's HARD range.
  **In v7, load does NOT re-clamp to the cap** — a beyond-cap value (authored while extremeness was
  higher) persists (the inward-ratchet behavior is consistent across set/save/load, §3.3). There is no
  composed-field re-clamp on load — that machinery is gone (§6).
- **The face-obscuring default hair cap is ALREADY FIXED** (`9c737c6`, `PROXY_DEFAULT_HIDDEN`,
  `body_rig.gd:69`). Default body shows the FACE; a real hairstyle is opt-in. Camera face-front default
  + centered pivot also landed in `9c737c6`. (Opt-in hair drape is a separate deferred defect, §5.6.)
- **Bilateral modifiers are a complete l-/r- pair set (re-parsed @ HEAD).** 61 `l-` modifiers, every
  one has its `r-` twin, 0 unpaired. This pairing is the canonical mirror map (§1.3).
- **`resolve_full_names` does bare-stem→full_name RESOLUTION (re-verified @ HEAD).**
  `region_sliders.gd:136-145` (a) resolves a bare GROUPS spec stem (`l-upperarm-muscle`, stored as a
  bare token in GROUPS `:78-90`) into the full registry name by prepending `BILATERAL_PREFIX`
  (`armslegs/`, `:130`) and appending `-decr|incr` (`:141`), and (b) currently also L→R mirrors
  (`:142`). The CURRENT code already resolves both twins (round-6 m1 noted this — the genuine new work is
  separating the contralateral-application toggle from resolution, §1.3, not the resolution path itself).
- **Skin = bare `StandardMaterial3D`** (albedo+roughness, `body_rig.gd:359-361`); MakeHuman ships zero
  PBR skin maps. Every skin map must be generated or sourced CC0.
- **`eye.gdshader` is FULLY PROCEDURAL** (`:24-44`): zero `sampler2D`/`texture()`; iris/sclera/limbal/
  pupil are procedural uniforms driven by the model-space surface normal vs `gaze_dir` (`:55-72`). No
  view vector, no camera input, no refract, no parallax. The eye plan (§5.2) improves this procedural
  shader to approximate a reference iris look — NOT to sample a PNG, NOT to add parallax.
- **Eyes ALREADY look around via BONES — gaze must be LEFT ALONE (round-6 re-verified, round-5 M-C).**
  `FaceRig._set_eye_look` rotates the `BONE_EYE_L`/`BONE_EYE_R` (`eye.L`/`eye.R`) bones via
  `set_bone_pose_rotation` driven by `val_look_dir` (`face_rig.gd:256-258,293-300`); `gaze_rig.gd:7-9`
  documents the split explicitly ("the FaceRig drives the EYE bones (val_look_dir); this drives the
  HEAD/NECK/CHEST bones"). The eye proxy is **skinned** to the skeleton (`body_rig.gd:795`) and
  `ProxyMorph` re-emits bone/weight channels each bake, so the eyeball — and its model-space normals —
  rotates with the bone. The shader keys the iris off that model-space normal (`eye.gdshader:56,60-65`).
  So the eyes already track when `val_look_dir` is set; the empty `grep gaze_dir scripts/` proves only
  that nobody sets the SHADER UNIFORM, not that the eyes can't look around. **Driving `gaze_dir` from
  the eye-bone forward would double-count** the rotation. v7 therefore removes all "wire `gaze_dir` /
  net-new gaze" text and leaves the bone-driven look mechanism untouched. (Round 6 independently
  re-verified: `gaze_dir` defaults forward `(0,0,1)`; driving it from the bone WOULD double-count. No flaw.)
- **The 96-vert eye proxy geometry is KEPT as-is.** The eye look is procedural in-shader; proxy density
  is not a fidelity bottleneck. (Proxies share global vertex numbering in one ArrayMesh, total 1219,
  keyed to the proxy detail library; swapping the eyeball would force a full proxy + detail-library
  re-bake — dropped.)
- **No XR code** anywhere (grep clean). VR is 0% implemented (§7).
- **No pregnancy SIMULATION (facts-r2 Q4).** `grep -i pregnan scripts/` returns one file —
  `region_sliders.gd:57`, a slider label. No gestation/trimester/progression state, no second writer.

---

## 1. Editing model — archetype + progressive-refine, with the judge's grafts

**Decided (per `judge-editing-models.md`):** base model is **archetype + progressive refine** — pick a
valid archetype → nudge headline axes → reveal deep control on demand. The only model that reaches the
TiTS depth bar without the wall of 56 sliders as the front door, keeps the full registry tree and
sculpt as a relocated tier, and carries the lowest net infra risk (an archetype is a frozen
`BodyState` — data-over-code at a faithful seam).

**On "controls mean what they say" vs the rejected range-shrink (round-6 M3, OWNED in v7).** Input-space
range-shrink that shrinks a slider's range *because OTHER controls moved* (constrained mechanism A) is
**rejected** — it makes a control's hard stop depend on sibling state, which is opaque and breaks the
contract. v7's default cap is **NOT** that: a control's hard stop is a fixed function of the global
extremeness ONLY (`cap(control, extremeness)`), never of other controls (§3.5). But v7 also **owns the
honest consequence**: at extremeness 0 the numeric field and slider clamp to the default cap, so the
felt behavior in default mode IS "bounded by default, with a single visible global unlock." v7 does NOT
claim the slider's label is literally reachable at extremeness 0; it claims the default cap defines the
control's *normal* reach and the **global** extremeness gate is the honest, visible opt-in to go further.
That is a real, owned property — not the rhetorical dodge round 6 flagged. **The "visible" claim now has a
concrete MECHANISM (round-10 M10-2): the v11 live-edit write-back protocol (§3.2 step 4) writes the
clamped `new` back to BOTH the thumb (`set_value_no_signal`) and the numeric label (display `new`, not the
pre-clamp request), so a clamp is SEEN at the widget, not silently swallowed.** It is owned-and-visible by
construction, not by assertion.

### 1.1 Archetype = a frozen, serializable `BodyState` (data-over-code)

A named, frozen `BodyState` — the six headline axes (`age_years`, `height_cm`, `masculinity`,
`muscle`, `weight`, `proportions`) plus a curated sparse `modifiers` map — shipped as a small data file
(`assets/body/archetypes/*.json`, via `to_dict`/`from_dict`, `body_state.gd:765,785`). ~**15–18
first-party** archetypes as the *seed*: a `feminine|androgynous|masculine` family fork × a small named
build set (`slim/average/athletic/curvy/heavy/muscular`), shipping only the combinations that read
well. The authoring labor is roster content, out of this design's scope, de-risked by the **moddable**
loop: "Save as archetype" exports the current `BodyState` + thumbnail.

**Two DISTINCT load paths with DIFFERENT guarantees (round-9 B9-1).** A first-party ARCHETYPE and a user's
OWN save are NOT the same kind of artifact, even though both deserialize a `BodyState`:

- **First-party ARCHETYPES (T0 starting points) MUST be authored WITHIN every control's DEFAULT interval
  `cap(control, 0)`.** A **BUILD-TIME validation (gate #11) asserts every shipped archetype's every value
  lies within that control's default interval, and FAILS THE BUILD otherwise.** Consequence: picking ANY
  archetype at extremeness 0 — the single most common first action — can NEVER land beyond the default cap,
  so the slider ranges never silently ratchet open on a pick, and the §3 "no-monster-by-DEFAULT" guarantee
  holds for the pick-and-go majority. Because an archetype value is within `[a,b]` by construction, loading
  it RAW is IDENTICAL to loading it through the capped choke at extremeness 0 (`hi=b`, `lo=a`, the value is
  already inside) — so archetypes use the raw load path (§3.2 path 7a, the same mechanism as path 7) with no
  special clamp, and the build gate #11 is what makes raw==capped for them. A `heavy`/`curvy` archetype that "reads well" must therefore
  fit inside the default intervals; if it cannot, that is a signal the default interval for the relevant axis
  is too tight (a §8 #1b tuning input), NOT a license to ship a beyond-cap archetype.
- **User SAVE/LOAD (the user's own prior creation) preserves RAW and MAY be beyond cap** — when the user made
  it with extremeness raised. That is THEIR creation, not a default starting point; beyond-cap values persist
  (consistent with the inward ratchet — §3.3). **Imported external user saves are treated like user saves
  (raw-preserve).**
- **Scope of the no-monster-by-DEFAULT guarantee, made explicit:** it covers the DEFAULT new character and
  ARCHETYPE PICKS. It does NOT cover what a user deliberately made with extremeness raised and reloaded — by
  design (§3, §10).

### 1.2 Progressive-disclosure tiers (additive, monotone — opening a tier hides nothing)

| Tier | Surface | For |
|---|---|---|
| **T0 Pick** | archetype grid (family→build, thumbnails) + Randomize | the pick-and-go majority |
| **T1 Headline nudge** | the 6 natural-unit axes (slider + **mandatory numeric entry**), "Blend toward…" | the common case |
| **T2 Curated detail** | ~12–16 high-impact low-footgun sliders (breast size, face shape, jaw, nose, hip/waist, brow, lips, **belly group** §2) — each a projection of a registry entry | players who want their own face |
| **T3 Full control** | the complete registry tree (the 56 region sliders + every modifier, grouped by `tab`/`slider_group`) — including the fine-detail **navel rows** (`region_sliders.gd:59,60` — navel in/out, navel down/up) and love-handles (§2 m10-3) **+ grab-sculpt with a visible grab affordance** **+ the global extremeness gate (§3)** | power users / archetype authors |

### 1.3 Grafts onto the winner

- **Mirror = a USER ASYMMETRY toggle, ORTHOGONAL to bilateral resolution (fixes round-5 B-A).**
  Round-5 B-A was correct: v5 collapsed two independent concepts into one toggle, so turning mirror OFF
  (to sculpt an asymmetric face) silently drove only the LEFT arm. v6/v7+ separate them — and **resolution
  is always preserved regardless of the mirror choice:**
  - **Bilateral RESOLUTION (structural, ALWAYS on, independent of the mirror toggle).** A single UI
    slider for a bilateral region maps to TWO anatomical modifiers (`armslegs/l-…` AND `armslegs/r-…`)
    because there is no separate left/right slider in `GROUPS` (`region_sliders.gd:78-90`).
    `resolve_full_names` therefore **ALWAYS resolves a bare bilateral stem → BOTH full names**
    (prefix + side + `-decr|incr`, `region_sliders.gd:130,141`), so a bilateral slider drives BOTH
    sides at all times. A literal full_name passes through unchanged. This is the control's definition,
    **NOT a mirror**, and it is **never gated by the user toggle**. (round-6 m1: the resolution path
    already does this @ HEAD — the genuine new work is the contralateral-application split below + the
    twin table, NOT a change to resolution.) The existing spec/tests stay valid:
    `body_region_sliders_test.gd:164-174` test (4) holds unconditionally; `_disp_field` over all resolved
    names (`:71-72`) and the bipolar-sign / table-integrity tests (`:92,140`) keep their behavior (gate #10).
  - **The ASYMMETRY / MIRROR toggle controls ONLY contralateral application of an edit.** When a player
    edits ONE side of a bilateral or lateral region (e.g. drags the left cheek, or moves a left-side
    sculpt handle), the toggle decides whether that same delta is ALSO applied to the opposite twin:
    - **Mirror ON (default):** a committed value delta `d` to a resolved modifier `M` is also applied
      to `twin(M)` **only when `twin(M) != M`** (the midline guard, m3 — a midline modifier has no
      `l-`/`r-` form so `twin(M)==M` and would otherwise double-apply). Symmetric edit.
    - **Mirror OFF:** the edit applies **only to the touched side** — `M` is set, `twin(M)` is left
      alone. Asymmetric edit. **Resolution still happens correctly** — the edited side is still
      resolved to its full name; only the contralateral *application* is suppressed.
  - **Canonical l-/r- twin table, built once at load (the SOLE mirror-application map).** For every
    registry `full_name` containing `l-` (start or after `/`), substitute `l-`→`r-`; keep the pair iff
    the twin exists (all 61 pairs resolve @ HEAD). A **build-time assert fails if any `l-` has no `r-`
    twin** (m6) so a future asymmetric addition can't silently go unmirrored. (round-6 m2: substitution
    keys on `l-` at a side boundary — start-of-name or after `/` — not a mid-token `l-`; verified no
    coincidental mid-token mis-pair @ HEAD.)
  - **Precise flow — both paths in modifier space (`{full_name: scalar}`), every write through the
    `apply_capped` choke AND the v11 widget write-back protocol (§3.2):**
    - **Slider path:** stem → `resolve_full_names` → {one or two full_names}. For each resolved name, run
      the §3.2 live-edit protocol: `new = apply_capped(M, req)` (the one neutral-agnostic interval clamp);
      write `new` to the model; recompute that control's OWN held/settled `[lo, hi]`; then
      `set_value_no_signal(new)`, then write `new` to the label. **The per-control held interval and clamp
      are individually correct for EACH resolved name — unchanged.** When the stem resolves to TWO full_names
      (a bilateral resolution: ONE widget drives BOTH L and R), the SHARED widget's displayed
      `min_value`/`max_value` use the MORE CONSERVATIVE (tighter) intersection of the two controls' current
      cap intervals — **`min_value = max(lo_L, lo_R)`, `max_value = min(hi_L, hi_R)`** (each `[lo_S, hi_S]`
      the side's own held-or-settled interval) — set FIRST (before the value writes), so the single thumb can
      NEVER travel past EITHER side's true cap even when L and R have DIVERGED (asymmetric body, reachable via
      mirror-OFF sculpt or an asymmetric imported save), which the v14 last-write-wins display did not prevent
      (round-14 MI14-1). When the stem resolves to ONE name, `[lo, hi]` is just that control's interval as
      before. Then, **if the edit is one-sided AND mirror ON**, repeat the same protocol for
      `apply_capped(twin(M), req_twin)`. (A bilateral slider drives both sides via resolution; it is not
      "one-sided," so the mirror step is a no-op for it.) **Because the twin write goes through
      `apply_capped`, the choke captures `twin(M)`'s held interval on its FIRST touch within the gesture
      (§3.2 step 3, the choke-capture invariant) — so a pre-ratcheted twin is protected from a transient-dip
      collapse with no mirror-side capture code (round-13 MA13-1).**
    - **Sculpt path:** `decompose_drag` emits full_names (each delta already clamped to the modifier's
      hard range inside `decompose_drag`). For each, run the §3.2 protocol on `apply_capped(M, cur + delta)`
      — **the cap is applied here, at the apply site** (`character_creator.gd:460-471`, §3.2), NOT inside
      `decompose_drag` — and (since a sculpt drag moves a slider that is bound to the modifier) sync the
      bound slider's bounds + value via the same `set_value_no_signal` write-back so the T2/T3 slider for a
      sculpt-driven modifier tracks the clamped `new` without re-firing its own `value_changed` (the
      sculpt-driven slider sync case, B10-1). Then, **if mirror ON**, `apply_capped(twin(M), …)` via the
      twin table (guarded `twin(M) != M`), each through the same protocol — and, since the twin write routes
      through `apply_capped`, the choke captures the twin's held interval on its first touch (§3.2 step 3),
      closing the round-13 MA13-1 transient-dip-collapses-a-ratcheted-twin trap.
  - One mirror-application path (the twin table), resolution always preserved. Gate #10 asserts a
    bilateral slider drives BOTH arms regardless of the mirror toggle; mirror toggles only contralateral
    application of a one-sided edit; midline edits apply once.
- **Sculpt acts on the CURRENT MORPHED surface, not the frozen neutral (B2).** The picker geometry and
  the locality decomposition basis read the same stale `_glow_base_pos` (`:248,383,461`), so on a
  morphed body a drag picks/biases the wrong region. **Fix: ALL sculpt spatial data refreshes from the
  current morphed surface, rebuilt dirty-on-bake:**
  - **Rebuild trigger — the OWNER re-fetches and re-builds, NOT the picker (m-3).** The picker
    (`scripts/util/cpu_accel_picker.gd`, m8-4) caches `_positions` (`:71`) and on `_dirty` rebuilds **from that cache**
    (`pick` → `if _dirty: build(_positions, _tris)` `:162-163`) — it has **no mesh handle**. The owner
    (`character_creator`, which holds `_rig`) must, on the next pick after a bake, **re-fetch the live
    baked `ARRAY_VERTEX`** from `_rig.mesh_instance.mesh.surface_get_arrays(0)` and **call
    `_cpu_picker.build(morphed_verts, _glow_tris)`**, plus refresh the other two consumers. Replace
    `_glow_base_pos` as a one-time neutral snapshot with a `_morphed_surface_dirty` flag (set in
    `_apply_state` `:1262-1271`) + a lazy owner-side getter that re-fetches once on the next pick.
  - **What rebuilds:** (1) the CPU picker, (2) the locality basis (the `positions` array passed into
    `decompose_drag` `:461`), (3) the glow overlay (`_rebuild_glow_mesh` `:434`). Triangle topology
    (`_glow_tris`) is morph-invariant, so only positions refresh. Lazy — rebuilt only on the next pick
    after a bake, so it costs nothing on non-sculpt frames and at most one picker rebuild per sculpt pick.
  - **Honest scope (m-B):** the picker transforms rest positions by `skeleton.global_transform` (incl.
    height scale) but does NOT account for skinned bone POSE; fine for the rest-pose creator body, but a
    posed/animated body or future in-world sculpt would still mis-pick. Scope is "morphed rest-pose body."
- **Grab-sculpt as the Tier-3 verb — with an EXPLICIT, VISIBLE grab affordance, NOT always-on grab.**
  Always-on grab is worse: the picker has latency, so a press resolving to an empty-space miss can't
  start orbiting until the pick reports the miss. The real defect is the **hidden keybind**:
  - **Keep the explicit grab/sculpt mode**, surfaced as a **visible, labeled UI control** (a "Sculpt"
    toggle in the T3 toolbar + a visible state indicator + cursor change). `M` stays as an accelerator.
  - **Input scheme:** *Orbit mode (default)* — left-drag orbits (instant, no pick), right-drag pans,
    scroll/pinch zooms. *Sculpt mode (toggled, visible)* — left-press runs the picker (on the morphed
    surface, B2); a hit starts grab+pull (locality decomposition → modifier deltas → §1.3 mirror, cap at
    the write §3.2) and a miss is a no-op (does NOT fall through to orbit); right-drag pans, scroll zooms.
- **Named region handles as a single data table.** One table `[modifier_full_name, anchor_vertex/bone,
  drag_axis_hint, label]`, seeded from `region_sliders.gd` GROUPS, that projects to flat gizmos AND
  (future) VR grab-volumes. Honest status: zero rows today, flat-only near-term; the VR projection is a
  hypothesis (§7).
- **Mandatory numeric entry with a ±100 / 0–100 display remap.** Every axis has a typeable field bound
  to the slider value; internal `[-1,1]`/`[0,1]` shows as `-100..+100`/`0..100` (region detail) or
  natural units (age yr / height cm). **Committed through the `apply_capped` choke AND the v11 write-back
  protocol against the control's current interval `[a, b] = cap(control, extremeness)` (§3.2)** — for a
  bidirectional `±100` field BOTH poles clamp at the interval endpoints. At extremeness 0 a typed "+100"
  (or "−100") lands at the default interval endpoint, AND the field is re-displayed showing the clamped
  `new` (protocol step 4), so the user SEES the clamp — owned, visible behavior, not a hidden lie (§1, M3,
  round-10 M10-2). This is how T1 hits "172 cm".
- **Reset + bounded seeded randomize.** Per-control / per-region / global reset to registry defaults
  (reset is a RESTORE path — RAW write + `set_value_no_signal`, §3.2 path 6 via `_reset_all`).
  Randomize is a **bounded seeded walk from a seed archetype** that **samples within the live interval
  `[a, b]` through the choke (§3.2/§3.3)** — at
  extremeness 0 it samples within default intervals, so randomize NEVER produces an
  extreme body unless extremeness is explicitly raised; with the global extremeness on, the intervals
  widen and randomize CAN reach extreme values (owned consequence of the single global gate, §3.1).
  **The "never extreme at extremeness 0" claim is now AIRTIGHT (round-9 m9-3):** the seed is a first-party
  archetype, which gate #11 guarantees is WITHIN every default interval, so the seed `cur` is inside `[a,b]`
  ⇒ `hi=b`, `lo=a`, and the walk samples strictly within the default interval. (In v9 the seed could be a
  raw beyond-cap archetype, which would have let `hi=max(b,cur)=cur` admit beyond-cap samples — B9-1 closes
  that.) Action-logged so the roll is reproducible and shareable.
- **Per-archetype soft envelope (common-path guard).** Picking archetype A centers a soft envelope
  `A_value ± max_delta` (default ~0.35, per-archetype overridable) on detail modifiers, so refining
  stays near a variant of that archetype, with an explicit Tier-3 escape. This is a *taste* nudge; the
  no-monster-by-default behavior is the §3 conservative default caps.

---

## 2. Editable in base creation vs gated

**Rule (decided):** base creation edits a *persistent body identity* — the static shape at rest.
*Transient physiological states* belong to the simulation layer.

- **In base creation (ungated, NSFW-first):** the 6 headline axes; all stable shape/size morphs —
  breasts, glutes, hips, waist, torso, limbs, neck, full face/head, **genital shape** (SFW is a render
  toggle); muscle/fat distribution; skin tone, eye color, hair/brow part+color; **belly group**
  (below). Geometry is anatomy and is never gated (gate the verb×body intersection, never the morph
  primitive).
- **Belly — SURFACE the EXISTING belly axes as named creator controls. NO new asset, NO pregnancy-morph
  reuse (per facts-belly.md; survived round 6 — only the COMBINATION is attacked, M4, and that is folded
  into the deferred combination-plausibility concern §3.4).** The distinct non-pregnancy belly axes
  already exist and are already imported (§0). The mechanism is a **UI-surfacing** task:
  - **RETIRE ONLY the `:57` pregnancy "belly" slider; KEEP the `:58` tone axis — NO duplicate tone control
    (round-8 m8-2 + round-9 m9-2).** The shipped region-slider group `"Belly & stomach"` ALREADY contains
    BOTH: `region_sliders.gd:57` = `["stomach/stomach-pregnant-decr|incr", "belly", "flat", "round"]` (the
    gravid morph, must go) AND `:58` = `["stomach/stomach-tone-decr|incr", "abs tone", "soft", "defined"]`
    (the real non-pregnancy tone axis, ALREADY SHIPPING). So executing "pregnancy out of base creation" is:
    **(1) DELETE the `:57` pregnant row** — `stomach-pregnant` leaves the creator surface entirely (it moves
    to the future pregnancy *simulation*); **(2) KEEP `:58` `stomach-tone`** (optionally relabel "abs tone"
    → "Belly softness / tone"), do NOT add a second tone control; **(3) ADD only the genuinely net-new belly
    morph `torso/torso-scale-depth` (belly-forward) plus the Weight/apple fat axes** — and REFERENCE the
    already-shipping waist slider (`:63`, `waist-circ`) for belly girth rather than re-adding it (round-11
    MI-1: re-adding it would duplicate a modifier across two controls); **(4) MOVE the existing
    `:59`/`:60` navel rows to T3 fine detail** (round-10 m10-3 — they stay live, untouched morphs, just
    re-tiered out of the T2 curated belly group; see the tier-placement note below). A v9-style "replace
    `:57` with stomach-tone/waist-circ/torso-depth" would DUPLICATE the existing `:58` tone row — v10
    forbids that; **v12 extends the same anti-duplicate rule to `waist-circ` (round-11 MI-1): the belly
    group must NOT re-add `measure/measure-waist-circ` because it ALREADY ships as the `:63` "waist" slider
    — reference it, do not duplicate it. No modifier is driven by two controls.**
  - **The resulting "Belly" T2 group** (the EXISTING `:58` tone, relabeled, + the net-new additions),
    semantically-correct labels mapping to existing live morphs:
    - **"Belly softness / tone"** → the EXISTING `stomach/stomach-tone-decr|incr` (`:58`, currently "abs
      tone"; incr = toned/abs, decr = soft slack belly). The true stomach-local non-pregnancy axis —
      ALREADY shipping, RELABELED, not re-added.
    - **"Belly forward"** → `torso/torso-scale-depth-decr|incr` (pushes the belly forward) — the ONLY
      genuinely net-new belly morph here (`grep` confirms `torso-scale-depth` is NOT in `region_sliders.gd`
      today). **Belly girth is ALREADY the shipping "waist" slider** (`measure/measure-waist-circ-decr|incr`,
      `region_sliders.gd:63`, under "Waist & hips") — v12 REFERENCES that existing slider, it does NOT
      re-add `waist-circ` under the belly group. Re-adding it would be a two-thumb-one-modifier DUPLICATE
      (two `_modifier_sliders` entries writing the same `modifiers["measure/measure-waist-circ-…"]`, which
      desync live because the region callback updates only its OWN label `:1178,1218-1221` — round-11 MI-1),
      the same defect v10 fixed for `stomach-tone`. So the belly-forward set adds `torso-scale-depth` ONLY;
      belly girth stays driven by the single existing waist slider (`:63`). **No modifier is driven by two
      controls.** **(round-6 M4 owned):** the big-belly recipe is still a multi-axis stack
      (`torso-scale-depth` + the existing waist + `Weight`/`apple`) — exactly the COMBINATION case the
      per-control caps do NOT bound (§3.4). v7 does NOT pretend the caps bound this; in the first build a
      too-far stack CAN be grotesque (accepted interim), and the eventual guardrail is the deferred
      combination-plausibility model (§3.4). Conservative DEFAULT caps on each individual axis keep the
      *default-mode* belly plausible per control; the combination is where the deferred model will hook.
    - **"Body fat"** (T1/T2, whole-body) → the `macrodetails-universal/Weight` macro (already the weight
      headline axis) and, as a fat-DISTRIBUTION option, `bodyshapes-elvs-{fem,man}-apple` (central
      pot-belly distribution).
    - **Navel** (innie/outie, position) → `stomach-navel-in|out`, `stomach-navel-down|up`;
      **love-handles** → `hip-scale-horiz|depth` / `hip-trans-out` — exposed at T3.
  - **Tier placement of the ALREADY-SHIPPING stomach rows (round-10 m10-3).** The flat region panel today
    carries, in order: `:57` pregnant (RETIRED, step 1 below), `:58` tone (→ T2 "Belly softness / tone"),
    and `:59`/`:60` the navel rows. The navel rows `region_sliders.gd:59` (`stomach-navel-in|out`) and
    `:60` (`stomach-navel-down|up`) are **fine detail → T3** (the full registry tree, §1.2), NOT the T2
    curated belly group: T2 carries the high-impact belly axes (tone, fullness, body fat), while navel
    in/out + down/up are low-footgun fine adjustments that belong with the rest of the registry at T3. So
    the split is: T2 = {tone, belly-forward (`torso-scale-depth`, net-new), body fat}; the EXISTING waist
    slider (`:63`, `waist-circ`) stays in its "Waist & hips" group (NOT re-added to the belly group —
    round-11 MI-1); T3 = {navel in/out, navel down/up (`:59`/`:60`), love-handles}.
  - **Labels are the design work** (upstream desc strings are empty); the *art/perceptual* call of which
    exact combination reads as "paunch" vs "soft belly" vs "pot belly" is a USER-gated render check
    (§8 (b)) over EXISTING morphs — but it requires **no new asset and no bake**.
  - **Pregnancy (`stomach-pregnant`) stays OUT of base creation.** The gravid belly is a transient
    physiological state for a future pregnancy *simulation*, never a creator setting.
- **Also gated to the sim layer:** arousal / engorgement / expression-AU morphs, transient
  transformation-in-progress, controlled `asym/*` targets (post-creation advanced).
- **Age** stays a continuous primitive [1,90]; the creator's *player* age control is hard-clamped ≥18
  via the single `is_adult_body()` predicate (`body_state.gd:451`) on the verb side. Archetypes carry
  age as a plain field. (round-6: predicate exists, single chokepoint — no flaw.)

---

## 3. Bounds — the FINALIZED cap model (raw modifiers + ONE global extremeness; caps DERIVED)

**Decided (user direction; round-6 B1/B3/M1/M2/M3 + round-7 B7-1/B7-2 + round-8 B8-1/B8-2/B8-3/m8-1 + round-9 B9-1/M9-1/M9-2 resolved).** The
no-monster-by-DEFAULT behavior lives in **parameter space**: each control's reachable VALUE,
clamped through ONE capped-write choke to a DERIVED, NEUTRAL-AGNOSTIC per-control **allowed interval
`[a, b]`** by ONE clamp formula for every axis type — **PLUS the build-time guarantee that first-party
ARCHETYPES are authored within those default intervals (gate #11), so the most common entry point (an
archetype pick) is bounded too (round-9 B9-1).** There is **no per-vertex
displacement budget, no composed-field clamp, no gather/scatter, no composition-stage geometry pass**
anywhere (that entire v5 family is DELETED). v9 replaced v8's two neutral-0 clamp formulas with one
interval clamp + the raw restore/load bypass; **v11 leaves that core formula UNCHANGED (re-derived sound
in rounds 9 AND 10) and fixes its remaining INTEGRATION boundaries:** the complete live-edit widget
write-back protocol (round-10 B10-1/M10-2) and the default-interval-contains-neutral invariant (round-10
M10-1/m10-2), atop v10's archetype-vs-user-save load split (B9-1), every-edit slider rebind (M9-1), and
the `_set_modifier` erase the choke wraps (M9-2). The guarantee's
scope is explicit: it covers the DEFAULT new character and ARCHETYPE PICKS, NOT a deliberately-extreme
user creation reloaded (by design).

> **Honesty note (round-6 B2/B4, OWNED):** the per-control caps do NOT prevent grotesque COMBINATIONS.
> Because composition is pure-sum (§0), individually-capped controls can still sum into a deformed body.
> v7 does **not** claim "sum of caps" solves stacking — that claim is REMOVED. Combination-prevention is
> a SEPARATE, DEFERRED concern (§3.4). In the first build, grotesque combinations are possible (accepted);
> default mode stays plausible only via conservative per-control default caps.

### 3.1 State model — what is stored

- **`BodyState.modifiers` stores RAW values (unchanged schema), with the EXISTING near-neutral erase.** A
  bare `{full_name: float}` map (`body_state.gd:790-792`), each value the raw modifier-space scalar in the
  modifier's HARD registry range. **No per-control cap state. No per-control ratchet state. No per-control
  authored-flag.** The real write site `_set_modifier` (`character_creator.gd:1209-1214`) ERASES any
  modifier whose `|v| < 1e-6` rather than storing `0.0` (a housekeeping optimization so a neutral body is a
  tiny dict). v10 keeps this and reconciles it with the cap model (round-9 M9-2): the cap reads `cur` as
  **"the stored value, or the control's NEUTRAL if absent"** — for a modifier the read site already supplies
  this via `modifiers.get(fn, 0.0)` (modifier neutral = its registry default ≈ 0), for a headline field
  `cur` is the field's current value (no erase — fields are not in the map). **The erase loses NO ratchet —
  GUARANTEED by the default-interval-contains-neutral invariant (round-10 M10-1, below):** a near-neutral
  value is within EVERY default interval `[a,b]` *because every default interval contains the control's
  neutral by invariant*, so erasing it and later re-reading it as neutral reproduces the identical `cur`,
  hence identical `lo=min(a,cur)`/`hi=max(b,cur)`. The ratchet only ever widens from a value OUTSIDE
  `[a,b]`, and such a value (beyond `b`, or below `a` — and since `a ≤ neutral`, below `a` means below
  neutral, so `|v| > 1e-6`) is never erased. So "store the raw result" and the erase optimization are
  consistent: `apply_capped` WRAPS `_set_modifier` (it does not replace its erase), passing the capped raw
  result through the same erase-at-neutral write — and round-trip determinism (gate #4) holds because
  absent⇒neutral is the same value the erase removed.
- **INVARIANT — every control's default interval CONTAINS its neutral/absent value: `a ≤ neutral ≤ b`
  (round-10 M10-1, the load-bearing fix for the erase reconciliation).** `apply_capped` reads an absent
  modifier as its neutral (`modifiers.get(fn, 0.0)`); the erase removes near-neutral values. Both are sound
  ONLY IF the neutral lies inside the default interval — otherwise the absent→neutral read of `cur = neutral`
  with `neutral < a` yields `lo = min(a, neutral) = neutral`, silently ratcheting the floor open from `a`
  down to the neutral with NO beyond-interval value ever authored (the exact M10-1 break, on the
  `[min>0, b0]` unipolar shape v10 mistakenly permitted). v11 REQUIRES `a ≤ neutral ≤ b` for EVERY control:
  - **Bidirectional modifier** (neutral 0): `a ≤ 0 ≤ b` — satisfied by the symmetric `[-a0, +a0]` default.
  - **Unipolar modifier** (neutral 0): `a = 0` (the floor IS the neutral); the `[min>0, b0]` shape is
    FORBIDDEN.
  - **Headline axis** (neutral 50 / 100 / 0.5 / 166.6): the band must straddle the neutral
    (`[20,80] ∋ 50`, `[85,115] ∋ 100`, etc.) — satisfied by every default band in §3.1.
  - **Derived (un-authored) modifier** (round-11 MA-1, neutral 0): the derived interval is symmetric and
    range-anchored about the neutral by construction — `[a, b] = [neutral − f·R, neutral + f·R]` clamped to
    the hard range, with `neutral = 0` for the bidirectional/unipolar registry modifiers (and the unipolar
    floor pinned to `a = 0`). Because it is symmetric about the neutral, which is the registry default,
    `a ≤ neutral ≤ b` holds **by construction** — gate #11b passes for every derived interval with no
    per-modifier authoring (the DEFAULT CAP RULE, below).
  - **Age** (no neutral; the interval IS the cap): the absent/default value is the registry default 25,
    which must lie in the default band `[18, ~60]` — satisfied (`18 ≤ 25 ≤ 60`); treat 25 as the "neutral"
    the band must contain.
  **The build-time gate (#11) asserts `neutral ∈ [a,b]` for EVERY control** (not only that archetypes lie
  within intervals), so a violating default interval FAILS THE BUILD. This invariant is what GUARANTEES
  absent values need no ratchet: an absent control reads as its neutral, which is inside `[a,b]`, so
  `lo = a`, `hi = b`, no floor opens. (Closes round-10 M10-1 and m10-2 — gate #11 could previously only
  iterate an archetype's present sparse keys, leaving absent-but-clamped-floor controls unchecked; the
  neutral∈[a,b] assert checks them per-control regardless of any archetype.)
- **ONE global `extremeness` scalar.** A single `0..1` value (plus the boolean toggle "Allow extreme
  proportions"; the toggle is `extremeness > 0`, or the slider sets the magnitude). **Decision — it
  lives on the creator-settings layer, NOT in `BodyState.modifiers`** (it is a creator-session setting
  that governs the INPUT clamp, not a body morph). Concretely: a field on the creator settings object
  serialized alongside `BodyState` in the save payload (§6) — one scalar per save, which round-trips
  trivially (resolves B3's per-control-round-trip contradiction: there is nothing per-control to
  round-trip).
- **The cap is DERIVED, never stored per value — a per-control ALLOWED INTERVAL `[a, b]` (NEUTRAL-AGNOSTIC).**
  `cap(control, extremeness) -> (a, b)` is a pure function over the versioned cap table (§3.4) returning
  a control's allowed interval in the control's OWN units. `a` and `b` are **absolute values in the
  control's units**, NOT a magnitude measured from any neutral — so the SAME formula (§3.2) covers every
  axis type without a special case:
  - **Bidirectional modifier axis** (`[-1,1]` signed, conceptual neutral 0): default `[-a0, +a0]` (e.g.
    `[-0.5, +0.5]`), widening toward `[-1, +1]`.
  - **Unidirectional modifier axis** (`[0,1]` unipolar, neutral = 0): default `[0, b0]` — **the floor MUST
    be `a = 0` (the neutral); a `[min>0, b0]` floor ABOVE the neutral is FORBIDDEN (round-10 M10-1, see the
    invariant below).** Widening toward `[0, 1]`.
  - **Headline axis with neutral ≠ 0:** the interval is just centered on (or around) that axis's natural
    range — masculinity default e.g. `[20, 80]` (neutral 50, range 0–100); weight `[~85, ~115]` around
    100 (range 50–150); height a plausible band around 166.6 (range 50–230); proportions a band around
    0.5 (range 0–1). Widening lerps each endpoint toward the HARD range (0–100, 50–150, 50–230, 0–1).
  - **Age** (range 1–90, NO neutral concept): the interval is a default plausible band (e.g. the player
    range `[18, ~60]`), widening toward `[18, 90]` (the ≥18 player floor is the §2 hard predicate, not
    the cap). No neutral is needed — the interval *is* the cap.
  - **DERIVED default for any OTHER sculptable modifier (round-11 MA-1):** see the DEFAULT CAP RULE below —
    `cap(control, e)` falls back to a derived symmetric interval when no authored interval exists, so the
    function is TOTAL over every reachable control (never undefined).

  **THE DEFAULT CAP RULE — every sculptable modifier is capped (authored-or-derived); authoring stays
  ~56 + headline, NOT ~280 (round-11 MA-1, the load-bearing v12 fix).** `cap(control, extremeness)` is a
  TOTAL function: it returns an authored interval if one exists, else a DERIVED one. There is no third
  "undefined ⇒ hard range" fall-through, so EVERY live write path (incl. the sculpt path, which
  `morph_drag.gd:133-156` `build_accel` proves can write ANY of the ~280 non-macro registry detail
  modifiers — `entries = registry.get("modifiers", [])` `:138`, one candidate per non-macro detail
  modifier, written into `BodyState.modifiers` at `character_creator.gd:465-471`) is genuinely capped, and
  the choke's "ALL live write paths capped" property holds for the sculpt-reachable uncurated modifiers,
  not only the curated ~56.
  - **AUTHORED intervals — the ~56 curated controls + the 6 headline axes.** These get HAND-AUTHORED,
    taste-tuned `[default_a, default_b]` (the §3.1 interval-SHAPE design: which axis is a window, which a
    one-sided band, where a unipolar floor sits, where a headline band straddles its neutral). This is the
    only per-control interval authoring — the ~56 figure (R6/§3.1/M9-3) is CORRECT once read as the
    authoring cost; it never claimed to bound the choke's coverage.
  - **DERIVED intervals — EVERY OTHER sculptable modifier (the ~224 uncurated, by RULE not by hand).** For
    a modifier with no authored interval, `cap(·)` computes the default interval from the modifier's own
    registry range: let `R = hard_max − hard_min` (the modifier's hard span) and `neutral` its registry
    default (≈ 0 for the signed/unipolar detail modifiers). The DERIVED default is
    `[default_a, default_b] = [clamp(neutral − f·R, hard_min, hard_max), clamp(neutral + f·R, hard_min,
    hard_max)]` where `f` is a single GLOBAL DEFAULT FRACTION of the hard range (the one tuning constant for
    all derived modifiers, in the caps asset). For a unipolar modifier the floor is pinned to `a = 0`
    (= neutral). The SAME extremeness widening applies on top — each endpoint lerps toward its hard limit as
    `e → 1`, exactly like the authored intervals — so a derived control widens by the global extremeness
    just as an authored one does ("widened by extremeness like the authored ones").
  - **Gate #11b (`neutral ∈ [a,b]`) holds for BOTH (round-11 MA-1).** Authored intervals are checked
    numerically; derived intervals satisfy it BY CONSTRUCTION (symmetric/range-anchored about `neutral`,
    with the unipolar floor pinned to the neutral), so the build gate need not iterate 280 hand-authored
    rows — it asserts the ~56 + headline authored intervals numerically and trusts the derivation's
    construction proof for the rest (or, cheaply, re-derives + asserts each in a loop; either way the
    AUTHORING cost is ~56 + headline, not 280).
  This is a RULE (authored-or-derived), not 280 hand-authored entries. `apply_capped` therefore ALWAYS has
  an interval for any control — authored if present, else derived — so the choke genuinely caps ALL live
  write paths with the authoring cost unchanged at ~56 + headline.
  At `extremeness = 0` the function returns the conservative default interval; as `extremeness → 1` it
  interpolates each endpoint toward the control's HARD limit (e.g. `lerp(default_a, hard_min, e)`,
  `lerp(default_b, hard_max, e)`), one global scalar widening every control's interval. Caps are data + a
  function, not stored alongside each value. **No axis-type tag is needed in the choke** — the interval
  is self-describing; the cap table simply carries each control's `[default_a, default_b]` and its
  `[hard_min, hard_max]`. (The registry axis-type info — `region_sliders.gd:16-19`, registry `kind`:
  251 bidirectional / 29 unipolar / 11 macro — informs how the DEFAULT interval is *authored*, but the
  clamp at runtime reads only `[a, b]`, so the headline FIELDS, which are not registry modifiers, work
  identically without a registry `kind` — resolving B8-1's "no tag source for the six fields.")

**Honest authoring cost (round-9 M9-3, scoped by the round-11 MA-1 DEFAULT CAP RULE — net-new first-build
work, not a one-liner, but ~56 + headline, NOT ~280).** "Caps are data + a function" describes the
MECHANISM, not the LABOR. The authoring cost is the HAND-AUTHORED intervals ONLY: the default interval
`[a,b]` for each of the **~56 curated controls plus the 6 headline axes**. The ~224 other sculpt-reachable
modifiers are capped by the DERIVED default rule above (a single global fraction `f`, no per-modifier
labor), so the "~56" figure is the authoring cost AND is consistent with the choke covering all live write
paths (the apparent contradiction round-11 MA-1 flagged is dissolved by the authored-or-derived rule, not
by inflating the cost to 280). Authoring the ~56 + 6 is genuine first-build design work in NON-UNIFORM units
(age yr, height cm, masculinity 0–100 about 50, weight 50–150 about 100, proportions 0–1 about 0.5 —
`character_creator.gd:726-731`; the ~50 region intervals per registry kind: 251 bidirectional / 29 unipolar
/ 11 macro). The labor is the interval SHAPE per control — which axis gets a symmetric window, which a
one-sided band, where a unipolar floor sits, whether proportions widens symmetrically about 0.5 — for 56+
entries. WHERE these intervals live is the caps asset (already named net-new, R6); v10 is explicit that the
**numeric values and final sign-off** are deferred to the §8 #1b tuning/taste pass, but the shape authoring
is upfront work. The §8 #1b per-control sweep validates each interval is INDIVIDUALLY reasonable, but its
acceptance boundary — "human + tasteful stylized range" — is partly **USER-TASTE-GATED** (the v3
visual-taste-is-user-gated principle, §8 (c)), NOT fully objective: the sweep mechanically reports each
control's AABB, but the pass/fail call on that AABB is a USER sign-off. So default-interval approval is a
USER call (green is user-granted), and the "objective per-control sweep" is objective in its measurement,
user-gated at its acceptance boundary.

This is the concrete state model round 6 (B1) found missing, repaired neutral-agnostic at round 8. The
entire bounds mechanism is: **raw values + one global scalar + a pure cap-interval function + ONE
capped-write choke (one formula, every axis type).**

### 3.2 Behavior — ONE capped-write choke (one neutral-agnostic formula); the inward ratchet EMERGES (no extra state)

**One choke, not N clamp sites (resolves round-7 B7-2; the formula resolves round-8 B8-1/B8-3).** EVERY
LIVE parameter write — modifier-space AND headline-field — routes through a single helper

```
apply_capped(control, req) -> stored
```

that reads the live derived interval `(a, b) = cap(control, extremeness)`, reads `cur` as **the stored
value, or the control's NEUTRAL if absent** (round-9 M9-2 — modifiers use the existing
`modifiers.get(fn, 0.0)` read, headline fields read the live field), applies the ONE clamp below, and
stores the raw result THROUGH the real write site (`_set_modifier` for modifiers, which keeps its
erase-at-`|v|<1e-6` housekeeping; direct `set(field, …)` for headline fields). `apply_capped` WRAPS the
existing write site rather than replacing its erase — and because a near-neutral value is inside every
default interval (the `neutral ∈ [a,b]` invariant, §3.1, round-10 M10-1), the erase loses no ratchet.
**The choke is followed on every LIVE path by the v11 widget write-back protocol below**, which reflects
the clamped value to the thumb + label without re-firing the callback. v7's "two write sites" was incomplete: the six HEADLINE axes are
NOT in `modifiers` at all — they are direct `BodyState` FIELDS written via `_body_state.set(field, v)`
(`character_creator.gd:1047` slider callback → `body_state.gd:787-792`), a THIRD path with a different
storage location and value convention (natural units / 0–100, not `[-1,1]`). v8 put the cap in ONE choke
but with two formulas that assumed neutral 0 (B8-1). v9 keeps the one choke and gives it ONE
neutral-agnostic formula that the headline fields satisfy without any axis-type tag.

**The clamp — ONE formula, every axis type (resolves B8-1, B8-3; CORE FORMULA UNCHANGED in v10, verified
sound round-9).** Let `req` be the requested new value, `cur` the stored value **or the control's neutral
if absent (M9-2)**, and `(a, b) = cap(control, extremeness)` the control's allowed interval (`a ≤ b`, in
the control's own units, §3.1):

```
hi  = max(b, cur)          # cur raises the high ceiling ONLY if already beyond b
lo  = min(a, cur)          # cur lowers the low floor   ONLY if already beyond a
new = clamp(req, lo, hi)
```

- **Outward beyond `[a, b]` is hard-clamped.** If `cur` is inside `[a,b]`, then `lo = a`, `hi = b`, and
  `new = clamp(req, a, b)`: a request past either endpoint lands exactly on that endpoint. For a
  bidirectional axis with default `[-0.5, +0.5]`, `req = -1.0` lands at `-0.5` (NOT `-1.0`) — the B7-1
  property, now from the general formula. For masculinity with default `[20, 80]`, `req = 100` lands at
  `80`, `req = 0` lands at `20` — a correct WINDOW around neutral 50, which v8's magnitude clamp could
  not express (B8-1 fixed).
- **Inward (toward the interior) is free.** Any `req` already within `[lo, hi]` applies unchanged;
  reducing toward the interior is never blocked, from either side.
- **Each pole RATCHETS INDEPENDENTLY (fixes B8-3).** `hi` is raised by `cur` ONLY when `cur > b`; `lo` is
  lowered by `cur` ONLY when `cur < a`. A value ratcheted high (`cur = +0.9 > b = 0.5`) gives
  `lo = min(0.5, 0.9) = 0.5`, `hi = max(0.5, 0.9) = 0.9` → `clamp(req, 0.5, 0.9)`. A request of `-0.9`
  lands at `0.5`, NOT `-0.9`: the ratcheted high pole does NOT re-admit the opposite (low) pole beyond
  its floor. There is no shared symmetric ceiling and no free sign-flip across neutral — the exact B8-3
  break, now structurally impossible because `lo` and `hi` move from `cur` on different sides only.
- **Beyond-interval stored values PERSIST and reduce freely.** A `cur` beyond `b` (or below `a`), set
  while extremeness was higher, holds where it sits (`hi = cur` / `lo = cur`); outward-past-`cur` is
  blocked but the value is not pulled in. Reducing it back inside `[a,b]` is free, and once inside it is
  bounded by `[a,b]` going forward.
- **The "one-way inward ratchet" EMERGES — no extra state.** It falls out of "clamp only outward
  (beyond-interval) input + store raw + never re-clamp stored values," and now holds across the WHOLE
  range including a sign change, because the two poles ratchet from `cur` independently. NO ratchet
  state, NO per-control memory, NO authored-flag. (Resolves round-8 B8-1/B8-3; round-7 B7-1/B7-2 and
  round-6 B1/M1/M2 stay resolved.)

**LIVE EDIT vs RESTORE/LOAD — the precise split (resolves round-8 B8-2).** The choke is for LIVE edits
ONLY. Restore and load write the model RAW and update widgets WITHOUT re-firing the capped callback,
using `set_value_no_signal` (Godot's setter that suppresses `value_changed`; already used at
`scripts/ui/options_menu.gd:46` (m9-1) — there is no `set_value_no_signal` in the creator today, `grep` empty, so this is
named new work, not pretended-existing). This is required because every restore path today does
`slider.value = v` (`character_creator.gd:1324` headline, `:1237` region via `_restore_modifier_sliders`),
which EMITS `value_changed` and re-fires the live capped callbacks (`:1046` headline → `_body_state.set`,
`:1175` region → `_set_modifier`) — so without the bypass a persisted beyond-cap value would be
re-clamped at extremeness 0, breaking §3.3 / gate #4. (`_suspend_commit` already gates only the history
COMMIT, not the callback, so it does not prevent the re-clamp — verified `:1322`.)

**THE COMPLETE LIVE-EDIT WIDGET PROTOCOL — exact ordered steps (resolves round-10 B10-1 + M10-2, the
load-bearing v11 fix).** v10 specified "compute `req`, call `apply_capped`, recompute slider `min/max`"
but NEVER specified how the outward-CLAMPED `stored` value gets back to the thumb and the numeric label.
That gap is a real defect on the outward-clamp case — the case the cap exists for: either (a) the thumb
keeps showing the pre-clamp request while the model holds the clamped value (the thumb/value DESYNC m8-1
and M9-1 both claim to kill), or (b) recomputing `max_value` below the current `value` makes Godot's
`Range` clamp `value` down AND emit `value_changed`, re-entering the live callback → another `apply_capped`
+ a full 14,517-vert `_apply_state` bake (§0 hot path) → a re-bake FEEDBACK LOOP the design declared
impossible. v11 closes both with **one exact ordered protocol that EVERY live write path (1–5) follows**;
restore/load (6–7) already use the raw `set_value_no_signal` bypass and are unchanged.

For a live edit (`control`, requested value `req`, bound widget `w`):

1. **Clamp:** `new = apply_capped(control, req)` — the one neutral-agnostic interval clamp (§3.2 formula).
2. **Write the model:** store `new` THROUGH the real write site — `_set_modifier(full_names, new)` for a
   modifier (honoring its erase-at-`|v|<1e-6`), or `_body_state.set(field, new)` for a headline field.
3. **Compute the widget interval — HELD across the ACTIVE EDIT GESTURE, captured LAZILY INSIDE THE CHOKE
   (round-11 MA-2 + round-12 MA12-1 + round-13 MA13-1, the load-bearing v14 fix).** The interval `[lo, hi]`
   each touched widget is bounded to is computed from a HELD ratchet input captured at the control's FIRST
   TOUCH within the gesture, NOT the live mid-gesture `new`. **The phase signal is the GESTURE; the held
   interval is a property of the CHOKE itself, captured path-agnostically.** Rounds 12 and 13 traced the
   SAME defect class — a live-through-the-choke write sub-path lacking a held interval — twice (MA12-1: the
   sculpt path; MA13-1: the mirror-applied contralateral twin). v12/v13 patched each sub-path's capture
   by ENUMERATION (slider `drag_started`, then sculpt first-`decompose_drag`), which left every NOT-yet-
   enumerated sub-path — the mirror twin, and any future cascaded/derived write — exposed. **v14 collapses
   all of these to ONE invariant by moving the capture INTO the choke, where every write path already funnels:**

   > **THE CHOKE-CAPTURE INVARIANT — any control written through `apply_capped` during a gesture uses a held
   > interval captured at its FIRST touch within that gesture.** The FIRST time `apply_capped(control, …)` is
   > called for a given `control` within an active edit gesture, it LAZILY captures that control's held value
   > `cur_start` (the live stored `cur` read at that first touch, BEFORE this first write mutates it) into the
   > gesture's held-interval map `_drag_start_value[control] = cur`, guarded by `if not
   > _drag_start_value.has(control)`. Every subsequent `apply_capped` for that control within the gesture
   > clamps against the HELD interval `[min(a, cur_start), max(b, cur_start)]` — both the choke's clamp (step
   > 1, the choke note below) and the widget bounds (step 3). Bounds recompute from the settled value on
   > gesture END.

   - **Because capture happens INSIDE the choke on first touch, it AUTOMATICALLY covers EVERY control any
     write path routes through the choke** — a directly-touched slider's bound control, a sculpt-decomposed
     modifier, the mirror-applied `twin(M)` (§1.3), a numeric/headline field, a randomize sample, and any
     future cascaded or derived write — with NO per-path enumeration and no way for an enumerated-but-missed
     sub-path to exist. (The MA13-1 mirror twin is covered for free: the §1.3 mirror step calls
     `apply_capped(twin(M), …)`, so the twin is captured on its own first touch exactly like the touched
     control, with no special mirror-side capture code.)
   - **The former per-path capture descriptions are now INSTANCES of this one rule, not separate
     responsibilities.** The slider's `drag_started` capture (round-12) and the sculpt first-`decompose_drag`
     capture (round-12) are NO LONGER needed as distinct write-side captures — they happen automatically the
     first time each control flows through `apply_capped` during the gesture. The capture site is the choke,
     once; the gesture LIFECYCLE (start/end) still comes from the active-edit-gesture brackets (below), but
     WHICH controls get a held interval, and WHEN within the gesture, is decided entirely by first-touch-
     through-the-choke.
   - **DURING an active edit gesture**, the held value for each touched `control` is its `cur_start`; the
     ratchet input is `[lo, hi] = [min(a, cur_start), max(b, cur_start)]`, HELD FIXED for the gesture's
     duration (not recomputed from the live mid-gesture `new`).
   - **On GESTURE END** (slider `drag_ended` `:1055-1056,1182-1183` where `_drag_pending` clears; sculpt
     `_end_morph_drag` `:500`), and on **load**: recompute `[lo, hi] = [min(a, new), max(b, new)]` for each
     control from its SETTLED stored `new` — the normal ratchet update — and CLEAR the whole held-interval
     map `_drag_start_value` (so no entry leaks into the next gesture). This is the only place the ratchet
     collapses inward, once per gesture, on the committed value. The all-controls bounds sweep an extremeness
     change triggers is specified in MI13-1 below (so non-touched controls whose bounds depend on the changed
     extremeness are also refreshed). **A mid-gesture extremeness change (like any state-replacing op) ABORTS
     the gesture first per the gesture-lifecycle-interruption invariant above (MA14-1), then runs that
     all-controls sweep — it never overrides a held interval because the held map is cleared by the abort.**
   - **Gesture lifecycle (boundaries only).** Gesture START/END come from the active-edit-gesture lifecycle:
     a slider drag (`drag_started`/`drag_ended`, `character_creator.gd:1052-1056,1181-1183`); a sculpt drag
     (`_dragging_morph = true` at `:632-648` through `_end_morph_drag` at `:500`); and a single discrete
     write (numeric/keyboard step/click/randomize sample) is a degenerate ONE-WRITE gesture — start and end
     coincide in that single `apply_capped` call. A single boolean `_in_sculpt` (true between
     `_dragging_morph = true` and `_end_morph_drag`) plus the slider `_drag_pending` set mark whether a
     continuous gesture is active; the held-interval MAP is the choke's, and it is CLEARED at gesture end.
   - **For a non-gesture / one-write edit** (keyboard step, click, numeric entry, single randomize sample —
     no continuous stream): first-touch capture and gesture-end recompute coincide in the one call, so
     `cur_start == cur` and `[lo, hi]` is computed from `new` immediately — capturing/holding is a no-op, as
     before.

   > **THE GESTURE-LIFECYCLE-INTERRUPTION INVARIANT (round-14 MA14-1, the second lifecycle invariant
   > alongside the choke-capture one) — any STATE-REPLACING operation that can occur mid-gesture MUST FIRST
   > ABORT the active edit gesture, THEN apply the operation.** The held-interval map `_drag_start_value` is
   > gesture-scoped mutable state whose entire correctness rests on its `cur_start` references being faithful
   > to the model. An operation that REPLACES the model underneath an in-flight gesture — a raw restore
   > (undo / redo / reset / history-jump, `character_creator.gd:576-583,1315-1331`, reachable mid-drag because
   > the keyboard handler `_unhandled_input` fires while a mouse drag is held), an archetype/import load, or an
   > extremeness change — would otherwise leave each captured `cur_start` (and the sculpt accumulators
   > `_drag_accum`/`_drag_vertex`) stale, so the gesture keeps clamping against a held interval the operation
   > invalidated and commits a garbled node at release. The invariant: **before any such state-replacing op
   > applies, ABORT the active gesture — clear the held-interval map `_drag_start_value`, clear the in-flight
   > sculpt accumulators (`_drag_accum`, `_drag_vertex`) and the gesture brackets (`_dragging_morph`,
   > `_drag_pending`), and cleanly end the gesture — THEN do the raw write / load / extremeness recompute.**

   - **Consequence — after a state-replacing op there is NO active gesture; the guarantee is a SAFETY
     property, not "the next input resumes."** The abort sets `_dragging_morph=false`
     (`character_creator.gd:639`) and clears the held map and accumulators, so there is no zombie gesture to
     resume and no garbled node can commit. In the canonical held-button case (a mid-sculpt-drag Ctrl+Z with
     the left mouse button still PHYSICALLY HELD), the very next event is mouse MOTION, which starts no
     gesture — it falls through to dead hover (`_update_hover_glow`, `character_creator.gd:662,674`); a FRESH
     gesture begins only on the next release + re-press (`:632-644`). The slider-drag case is even cleaner:
     the eventual release fires Godot's own `drag_ended` against the cleared bracket — no zombie. When a fresh
     gesture does begin (on that next press), its first-touch capture reads `cur_start` from the NEW state
     (the restored / loaded / re-extremeness'd model), so there is no stale `cur_start` and no ratchet the
     restore removed can survive — the freshly captured first-touch interval IS the new state's interval. The
     no-capture-on-the-bypass property (v14 — `set_value_no_signal` never fires `apply_capped`) is unchanged;
     this invariant adds the symmetric guarantee that the bypass also INVALIDATES any held map by aborting the
     gesture, so the raw write lands on a clean, gesture-less slate.
   - **This SUBSUMES the MI12-1 extremeness-mid-gesture rule (v15 simplification).** Extremeness change is
     itself a state-replacing op, so it falls under this ONE abort rule: a mid-gesture extremeness change
     ABORTS the gesture, then runs the immediate all-controls bounds recompute against the new extremeness —
     the gesture-less path it would take anyway. v15 therefore RETIRES the v12/v13 deferred-recompute special
     case (`_extremeness_dirty` deferred to gesture-end): one lifecycle rule for EVERY interruption — restore,
     load, AND extremeness — not a defer-vs-abort split. The abort rule is preferred for simplicity (one
     invariant, one branch on every interrupting trigger) and is consistent because both old paths converge on
     the same end state: a gesture-less model with fresh first-touch capture on the next input. (The MI13-1
     full all-controls sweep for an extremeness change is unchanged — it is just now run immediately after the
     abort rather than deferred to a gesture-end that no longer exists; see the MI12-1/MI13-1 reconciliation
     below.)
   WHY: the mutating callback fires every mouse-motion frame during BOTH a slider drag
   (`value_changed`, `character_creator.gd:1041-1045`/`:1046`/`:1175`) AND a sculpt drag (`_apply_morph_drag`
   per motion frame, `:446-475`), and within a sculpt/slider frame the §1.3 mirror step issues a SECOND
   live `apply_capped(twin(M), …)`. v10/v11 — and v12/v13 on the directly-touched paths — recomputed
   `[lo,hi]` from the live mid-gesture `new` on EVERY such fire for any control WITHOUT a held entry, so a
   transient dip below the ratcheted `b` mid-gesture set `max_value` (or, for a control with no bound
   slider, the choke's own live `cur`) below the ratcheted reach and TRAPPED the rest of the gesture (the
   user could never travel back up past the lowest transient point — round-11 MA-2 on the slider path;
   round-12 MA12-1 on the sculpt path; round-13 MA13-1 on the mirror-twin path, which v12/v13's enumerated
   capture never reached). Capturing each control's held value at its FIRST touch THROUGH THE CHOKE — so
   the twin, captured on its own first `apply_capped(twin(M), …)`, is held exactly like the directly-touched
   control — means a transient dip cannot destroy the ratchet on ANY path the gesture routes through the
   choke; the inward-ratchet collapse still happens, but only on the COMMITTED value at gesture-end, which is
   the intended "reducing inward collapses the ratchet" semantics.
4. **Apply to the widget WITHOUT re-firing — strict order:**
   - **First** set `w.min_value = lo` and `w.max_value = hi` (the HELD gesture-start bounds during an active
     edit gesture — slider OR sculpt; the recomputed bounds at gesture-end / on a non-gesture edit, per
     step 3). Setting bounds FIRST, widened to
     contain `new` (during a gesture `lo = min(a, cur_start) ≤ new ≤ max(b, cur_start) = hi` because the
     clamp in step 1 already bounded `new` to `[min(a, cur_start), max(b, cur_start)]` — the SAME held
     interval the choke must use mid-gesture; see the choke note below), guarantees the value write is IN
     RANGE, so Godot's `Range` cannot clamp-and-emit `value_changed`. **For a SHARED bilateral widget driving
     two controls (one widget, L+R; §1.3), the displayed `[lo, hi]` is the CONSERVATIVE intersection of the
     two sides' intervals — `lo = max(lo_L, lo_R)`, `hi = min(hi_L, hi_R)` — so the single thumb cannot pass
     either side's true cap when L/R diverge (round-14 MI14-1); each side's own held interval + clamp (step 1)
     is unchanged, only this shared DISPLAY uses the intersection.**
     - **Documented consequence (round-15 mi15-2) — on a diverged/ratcheted body, touching the shared
       bilateral slider RESYNCS the more-ratcheted side DOWN to the conservative intersection bound.** If L and
       R have diverged so one side ratcheted farther, that side's extra reach lies outside `min(hi_L,hi_R)` (or
       inside `max(lo_L,lo_R)`), so the shared thumb cannot reach OR hold it: writing through the bilateral
       slider pulls the more-ratcheted side back to the intersection bound. This is INTENDED and acceptable, not
       a silent surprise — a single shared widget cannot represent two different reaches, so the symmetric
       control honestly shows (and writes) only the common range. Everything else is preserved: per-control
       values touched only through their own controls are unaffected, and the ratcheted reach remains reachable
       via per-side SCULPT or by raising extremeness (which lifts the cap). A user who wants to keep the
       asymmetry simply does not drive that axis through the shared bilateral slider.
   - **Then** `w.set_value_no_signal(new)` — the no-signal setter (precedent `scripts/ui/options_menu.gd:46`)
     suppresses `value_changed`, so the live callback does NOT re-enter.
   - **Then** update the numeric label/field to display `new` — read the stored `new`, NOT `slider.value`
     and NOT the pre-clamp `req`. (Today `_update_modifier_value_label` `:1218-1221` reads `slider.value`;
     after step 4 that equals `new` anyway, but the protocol mandates displaying `new` so the dependency is
     explicit and the headline/numeric fields behave identically.)

**The CHOKE itself uses the HELD interval mid-gesture, AND it is the choke that CAPTURES it (round-11 MA-2 +
round-12 MA12-1 + round-13 MA13-1 — closes the trap at its root, path-agnostically, by the choke-capture
invariant).** Step 1's `apply_capped(control, req)` reads `(a, b) = cap(control, extremeness)`, then — on
the FIRST touch of `control` within the gesture — lazily captures `cur_start` (guarded by `if not
_drag_start_value.has(control)`) and clamps to the SAME held gesture-start interval as step 3, NOT one
recomputed from the live `new`: `cur` for the clamp is the control's `cur_start` (the held value from
`_drag_start_value[control]`), giving `hi = max(b, cur_start)`, `lo = min(a, cur_start)`, so a mid-gesture
request back UP toward the ratcheted reach is admitted (clamped to the held `hi`), not trapped at a collapsed
live ceiling. Because the capture is the first thing the choke does, it covers EVERY control reaching the
choke — directly-touched, sculpt-decomposed, the mirror twin (§1.3), numeric, randomize — uniformly.
**This protects controls with no bound slider (the common case for the ~224 uncurated sculpt-reachable
modifiers, round-11 MA-1, AND a sculpt-only or mirror-twin modifier whose only widget, if any, is the bound
side's): even with no widget, the choke's clamp uses the held `cur_start`, so a per-frame dip cannot ratchet
the value's own floor/ceiling shut.** On gesture-end the clamp resumes reading the settled stored value as
`cur` (the normal per-pole ratchet). This makes the held bounds (step 3) and the clamp (step 1) consistent
for the whole gesture, on EVERY path that routes a write through the choke — the value can travel anywhere
within `[min(a,cur_start), max(b,cur_start)]` mid-gesture, and only the COMMITTED gesture-end value collapses
the ratchet. A transient mid-gesture dip therefore cannot destroy a ratchet on any sub-path, enumerated or
not.

**Why this resolves both round-10 breaks:**
- **No re-bake feedback loop (B10-1):** every widget write on a live path uses `set_value_no_signal`, so
  `value_changed` never re-fires; the callback does not re-enter; no extra `apply_capped` / `_apply_state`
  runs. The step-4 ordering (bounds-first, widened to contain `new`) ALSO means the value write is never
  out of range, so even the `set_value` path could not clamp-and-emit — the protocol is robust to Godot's
  emit-on-clamp behavior either way.
- **No desync, and the honesty property has a REAL mechanism (M10-2):** the thumb (step 4b) AND the label
  (step 4c) both show `new`, the clamped stored value. The "gating is VISIBLE at the slider, not a hidden
  lie" property (§1, §3.5) is now delivered by a named mechanism: the label reads the clamped `new`, not
  the pre-clamp request, so a typed/dragged "+100" at extremeness 0 visibly snaps back to the cap endpoint.

This is also why the "adds nothing to the bake hot path" claim holds (§0, m10-1): it is a CONSEQUENCE of
step 4's `set_value_no_signal` write-back (no `value_changed` re-entry), not free.

**LIVE-EDIT paths (each follows the 4-step protocol above; `apply_capped` is step 1):**

1. **Sculpt deltas** — `decompose_drag` emits `{full_name: value_delta}`; the apply site
   (`character_creator.gd:460-471`, inside the `_dragging_morph` gesture bracket `:632-648`) computes
   `req = cur + delta` and runs the protocol on `apply_capped(M, req)`. The cap is applied HERE, NOT inside
   `decompose_drag` (which keeps its own hard-range clamp against the build-frozen `rangef` — round-6 B1).
   **The sculpt drag IS an active edit gesture (round-12 MA12-1, generalized round-13 MA13-1):** every
   modifier `M` that `decompose_drag` returns is written through `apply_capped(M, req)`, so by the
   choke-capture invariant (step 3) `M`'s held `cur_start` is captured the FIRST time it flows through the
   choke within the gesture and held until `_end_morph_drag` recomputes from the settled value and clears the
   map. So a sculpt gesture that touches MANY modifiers gives EACH of them a held interval — none falls onto
   the "non-gesture" live-recompute branch (the round-12 MA12-1 hole, closed) — and the mirror twin written
   by the §1.3 mirror step is captured on its own first `apply_capped(twin(M), …)` exactly the same way (the
   round-13 MA13-1 hole, closed), with no sculpt-side or mirror-side capture code: the choke does it. **Sculpt reaches ANY non-macro
   modifier (round-11 MA-1):** `build_accel` (`morph_drag.gd:133-156`) emits a candidate for every
   non-macro detail modifier, so the modifier `M` here may be uncurated; `apply_capped(M, req)` still has
   an interval for it — authored if curated, else DERIVED (the §3.1 DEFAULT CAP RULE) — so the sculpt path
   is genuinely capped, ratchet-stable across a transient mid-gesture dip, and "no-monster-by-DEFAULT" holds
   on the T3 sculpt path, not only for the curated ~56. **Sculpt-driven slider SYNC (B10-1):**
   the modifier a sculpt drag moves is also bound to a T2/T3 slider; step 4 of the protocol writes that
   slider's bounds + value via `set_value_no_signal(new)`, so the slider tracks the clamped `new` WITHOUT
   re-firing its own `value_changed` callback (no re-entry into path 2, no extra bake).
2. **Region sliders** (T2/T3) — the live `value_changed` callback (`:1175-1180`) and the numeric entry
   compute `req` and run the protocol on `apply_capped(full_name, req)` for each resolved name (§1.3). Step 4
   writes the slider's own bounds + value via `set_value_no_signal` — note this is the SAME callback being
   re-entered if it fired, so `set_value_no_signal` is what prevents the self-re-entrant loop B10-1 traced.
3. **Headline-axis fields** (the six T1 axes) — the live slider callback (`:1046-1051`) and live numeric
   entry run the protocol on `apply_capped(field, req)`, writing `set(field, new)` (step 2) and
   `set_value_no_signal(new)` to the slider (step 4) instead of `set(field, v)` directly. The
   neutral-agnostic interval handles their neutral≠0 / no-neutral nature with no special case.
4. **Numeric entry** — for any axis (headline or modifier), the typed value is `req`; the field runs the
   protocol on `apply_capped(control, req)`. "+100" at extremeness 0 lands at the default interval endpoint,
   and step 4c re-displays the clamped `new` in the field so the user SEES the clamp (§1, M3, M10-2).
5. **Randomize** — each sampled value runs the protocol on `apply_capped` (equivalently, sampled within the
   live interval `[a, b]`; §3.3); step 4 syncs each affected slider via `set_value_no_signal`.

**RESTORE/LOAD paths (write the model RAW + `set_value_no_signal` — NOT capped, by design):**

6. **History restore** — `_restore_current` (`:1315-1331`), the funnel for **undo** (`_do_undo` `:1300`),
   **redo** (`_do_redo` `:1305`), **history jump** (`_jump_to_node` `:1310`), and **reset** (`_reset_all`
   via `_restore_current`). Set the headline fields directly (`_body_state.set(field, v)`) and replace
   `_body_state.modifiers` whole (`:1322`), then update EVERY widget via `set_value_no_signal(v)` at
   `:1324` (headline) and in `_restore_modifier_sliders` `:1237` (region), so the capped callback never
   fires and beyond-cap values persist.
7. **User SAVE/LOAD and external IMPORT** — `from_dict` whole-field/whole-map replacement
   (`body_state.gd:787-797`); after loading, the creator updates all widgets via `set_value_no_signal`
   (same bypass). Values preserved RAW; a beyond-cap value (made with extremeness raised) PERSISTS. Import
   safety is the existing hard-range projection clamp + dropped unknown keys (§3.3, §6), NOT a cap re-clamp.
   This is the legitimate beyond-cap-persists case (B9-1) — the user's own creation, not a default start.
7a. **First-party ARCHETYPE pick (T0)** — same RAW `from_dict` + `set_value_no_signal` mechanism as path 7
    (one code path), BUT every archetype value is GUARANTEED WITHIN its control's default interval by the
    build-time gate #11 (§1.1, §10). So at extremeness 0 the loaded value is already inside `[a,b]`
    (`lo=a`, `hi=b`) and no slider bound ratchets open — raw load is identical to capped load for archetypes
    at e=0. This is what keeps "no-monster-by-DEFAULT" true for the pick-and-go majority (B9-1).

**Slider widget bounds — HELD across the active edit gesture (held interval captured at the control's first
touch through the choke, step 3), RECOMPUTED on gesture-END / commit / extremeness-change / load (round-11
MA-2 + round-12 MA12-1 + round-13 MA13-1 supersede the round-9 M9-1 "every-edit recompute"; the EXACT ORDER
is the protocol step 3/4 above; the no-re-fire mechanism is round-10 B10-1).** Each slider's
`min_value`/`max_value` are set to the cap interval `[lo, hi]` — NOT the hard registry range — but the
RATCHET INPUT differs by phase (step 3): **during an active edit gesture** the bounds are HELD at
`[min(a, cur_start), max(b, cur_start)]` (the control's first-touch value, captured by the choke-capture
invariant — this covers a slider whose bound control is directly touched, sculpt-decomposed, OR written as a
mirror twin alike); **at gesture-end / on a non-gesture commit / on load** they are recomputed from the
settled stored `new` (`[min(a, new), max(b, new)]`).
(Extremeness-change is also a recompute trigger; a mid-gesture extremeness change ABORTS the gesture first —
the gesture-lifecycle-interruption invariant, MA14-1 — so it never overrides a held interval.) This is the
v14 correction to the round-9 M9-1 rule and the v12/v13 enumerated-capture gaps (MA12-1 sculpt, MA13-1 mirror twin). M9-1 said "recompute on EVERY edit," but `value_changed` fires every motion frame during
a drag (`character_creator.gd:1041-1045`), so recomputing `max_value` from the live mid-drag `new` collapsed
a ratcheted slider the instant the gesture dipped below the ratcheted `b` and trapped the rest of the drag
(round-11 MA-2). Holding the bounds at the drag-start values for the gesture's duration fixes that while
KEEPING the desync M9-1 was meant to kill: at drag-END the bounds DO recompute from the settled value, so
after an INWARD-and-committed drag the thumb range tracks the new live ceiling (no stale-ceiling desync —
load `cur=0.9` → held `[…,0.9]` for the drag; commit at `0.6` → bounds recompute to `[…,0.6]`; a SUBSEQUENT
drag is then correctly bounded). The within-drag travel is governed by the held bounds + the held-interval
choke (above), so a transient dip never traps the gesture, and the inward collapse happens once, on commit.
**The v11 no-re-fire mechanism is unchanged (B10-1):** the protocol's step-4 ORDER (set bounds FIRST,
widened to contain `new`, THEN `set_value_no_signal(new)`) means a value write is never out of range, so
Godot's `Range` cannot clamp-and-emit `value_changed` and the callback never re-enters — true for both the
held mid-drag bounds and the recomputed drag-end bounds. The thumb range therefore matches the cap interval
(held mid-drag, recomputed at settle), the thumb cannot travel past the cap, and — because step 4 writes the
clamped `new` back to thumb AND label — the gating is VISIBLE at the slider (closing the §1/§3.5 honesty
gap, round-10 M10-2).

**Extremeness-change vs the held interval — RECONCILED via the lifecycle invariant (round-12 MI12-1,
SUBSUMED by round-14 MA14-1).** The bounds-recompute trigger list includes extremeness-change, which
recomputes `[lo,hi]` from `cap(control, new_extremeness)` and would override a control's held gesture
interval mid-gesture, re-introducing a collapse. v12/v13 resolved this with a DEFERRED-RECOMPUTE special
case (`_extremeness_dirty`, deferred to gesture-end). **v15 RETIRES that special case in favor of the single
gesture-lifecycle-interruption invariant above (MA14-1): an extremeness change is a STATE-REPLACING op, so a
mid-gesture extremeness change ABORTS the active gesture — clears the held-interval map and ends the gesture
— THEN applies the new extremeness and runs the immediate all-controls bounds recompute.** This is the same
end state the deferral converged on (a gesture-less model with fresh first-touch capture on the next input),
reached by ONE rule shared with restore/load rather than an extremeness-only deferral path. So
extremeness-change NEVER overrides a held interval: there is no held interval to override once the gesture is
aborted. (In practice the extremeness control is a SEPARATE T3 widget and gestures are mutually exclusive
under a single pointer, so concurrent manipulation is hard to reach — but the abort rule makes the two
triggers non-conflicting by construction even via keyboard/second-device input, rather than relying on the
inputs being unreachable concurrently.) Because the gesture is aborted (not continued), there is no
mid-gesture "held vs new extremeness" tension at all — the next gesture captures `cur_start` against the
post-change state.

**The recompute after an extremeness change is the FULL all-controls bounds sweep, NOT only the touched
controls (round-13 MI13-1).** An extremeness change is an ALL-CONTROLS bounds event — it widens/narrows
EVERY control's interval, including controls no gesture ever touched. So an extremeness change runs the full
all-controls widget-bounds sweep — recomputing `[lo, hi]` for every widget from `cap(control,
new_extremeness)` and each control's settled stored value — whether or not a gesture was active when it
fired. **With the v15 abort rule there is no deferral to a gesture-end:** if a gesture was active, the
extremeness change first ABORTS it (MA14-1) and then runs the immediate full all-controls sweep — the same
sweep an extremeness change with no gesture active runs. There is no correctness gap and no interim
deferral: the choke (step 1) always reads the live `cap(control, extremeness)` at clamp time, and after the
abort+sweep every widget's displayed bounds already reflect the new extremeness. (The ordinary gesture-end
recompute on a NORMALLY-completed gesture — drag released, no interruption — still recomputes only the
touched controls + clears the held map; an extremeness change is the all-controls event, now handled by
abort+immediate-sweep rather than a deferred dirty flag.)

- **Asymmetric range is INTENTIONAL — a legibility marker (round-9 m9-4, minor UX).** When ONE pole is
  ratcheted (e.g. `cur=+0.9`, `b=0.5`, `a=-0.5` → bounds `[-0.5, +0.9]`), the slider track is deliberately
  lopsided with neutral off-center: the high reach is the ratcheted `0.9`, the low reach is still the
  default `-0.5` (the far pole is NOT re-admitted beyond its floor — B8-3). To keep that legible, render a
  small **cap-vs-ratcheted-extent marker** — a tick at the default endpoint (`a` and/or `b`) inside the
  widened track — so the user can see "this end is at the default cap; that end was ratcheted open." Named
  minor UX; not load-bearing.
(`character_creator.gd:1035-1036` headline, `:1169-1170` region set these bounds today to the hard
range; v13 drives them from `cap(control, extremeness)` and re-applies them — HELD at the gesture-start
interval during an active edit gesture (slider OR sculpt), recomputed at gesture-end / commit / load (and via
the immediate all-controls sweep after a mid-gesture extremeness change ABORTS the gesture, MA14-1) — in the
protocol's step-4 order,
bounds-first-then-`set_value_no_signal`, never in a way that can re-fire `value_changed` — round-11 MA-2 +
round-12 MA12-1 + round-10 B10-1, superseding round-9 M9-1's every-edit recompute.)

### 3.3 Save / load / randomize (resolves round-6 M1)

- **Save = the RAW modifier values + the single global `extremeness`.** Nothing per-control beyond the
  raw values; one global scalar. (No per-control authored-flag to record — there is none.)
- **Load does NOT re-clamp (and the UI restore path no longer re-clamps either — round-8 B8-2).** Loaded
  raw values are stored verbatim into `modifiers` / fields; a value beyond the current interval PERSISTS
  (consistent with the inward ratchet — load is just "set these stored values," and stored values are
  never re-clamped, §3.2). v9 makes this hold THROUGH the real UI restore flow by writing widgets via
  `set_value_no_signal` (§3.2 paths 6–7, 7a), so the capped callback never re-clamps a persisted beyond-cap
  value. This dissolves M1's contradiction: there is no "snap legitimate extremes vs preserve" dilemma
  because load NEVER snaps. Import safety is not a cap-re-clamp; it is the existing hard-range projection
  clamp (`to_blend_weights`/`_project_modifiers` drops unknown keys and holds the hard `[-1,1]`/`[0,1]`
  range) — the cap is an INPUT-time guard on new edits, not a load-time gate. (§6 states the import-wiring slice.)
- **The beyond-cap-persists case is USER SAVES/IMPORTS, NOT archetype picks (round-9 B9-1).** The
  raw-preserve behavior above is for the user's OWN prior creation (path 7) — legitimately beyond cap if
  made with extremeness raised. First-party ARCHETYPES (path 7a) are GUARANTEED within default intervals by
  the build-time gate #11, so an archetype pick at extremeness 0 never persists a beyond-cap value and never
  ratchets a slider bound open. The snap-vs-preserve dilemma round 9 found "moved to archetype-pick" is
  resolved by making archetypes within-cap DATA by construction, not by snapping them on load (§1.1, §10).
- **Randomize samples within the live interval `[a, b]` (resolves round-7 m7-3).** Each sampled value
  passes through the §3.2 choke (`apply_capped`), so a value is sampled within `[a, b]` (e.g. a
  bidirectional axis within `[-a0, +a0]`, NOT down to the hard `-1.0`; a headline axis within its band
  around neutral). At extremeness 0, within default intervals (no extreme bodies); with extremeness
  raised, the interval widens and randomize can reach extreme values (the owned global-gate consequence).
  Seeded + action-logged → reproducible.
- **No versioned-cap retune migration of stored values (resolves M2).** Because caps are DERIVED (not
  stored per value), a cap retune changes the cap FUNCTION, not any stored value — so there is no
  "re-clamp old saves respecting an authored-flag" step. The M1/M2 contradiction (snap vs persist under
  a per-control flag) is GONE because no value is ever snapped on load/migration and no authored-flag
  exists. The cap version is recorded only for replay determinism (§3.4): a replay re-derives caps from
  the recorded version so the INPUT-clamp sequence reproduces identically.

### 3.4 Combination-plausibility — DEFERRED; seam reserved (resolves round-6 B2/B4/M4)

The eventual guardrail against grotesque COMBINATIONS (multiple individually-reasonable axes summing into
a deformed body — the actual user complaint that "sum of caps" does NOT address) is a
**combination-plausibility model**: a validity model over modifier COMBINATIONS that can PREVENT
grotesque stacking, **toggleable OFF** when the user really wants the extreme.

- **DEFERRED — NOT in the first build (user decision: low priority to build).** v7 builds nothing here.
- **The seam IS reserved.** Where it would hook: a **post-composition validity check** that reads the
  resolved modifier-value vector (and optionally the composed AABB / region measurements) and can
  **nudge or warn** (and, if ever made enforcing, attenuate) — **toggleable**, defaulting on for
  no-monster-by-default once it exists, off when the user wants the extreme. It is a value-vector-level
  check (consistent with the parameter-space model), NOT a per-vertex pass on the bake hot path.
- **Interim (first build): grotesque combinations ARE possible — accepted.** Default mode stays plausible
  ONLY via **conservative per-control default caps** (each individually reasonable), NOT via any
  combination guarantee. v7 makes no claim that the first build prevents monstrous stacking.
- **The §8 #1 sweep is repurposed to validate DEFAULT-mode per-control caps are individually
  reasonable** — that each control's default cap, alone, reads as human-plus-stylized. It is explicitly
  NOT a combination guarantee (round-6 m5: it tunes the per-control constants; it does not certify
  combinations).

### 3.5 Per-control caps are control-OWN, never sibling-dependent (clarifies round-6 M3)

Each control's cap is that control's OWN fixed hard stop, a function of the GLOBAL extremeness ONLY:
`cap(control, extremeness)`. **A control's hard stop NEVER changes because other controls moved** — only
because the single global extremeness changed. This is explicitly DIFFERENT from the rejected mechanism A
("shrink a slider's range because OTHER controls moved"), which made a control's reach depend on sibling
state. v7's caps are sibling-independent; the only thing that widens or narrows any cap is the one global
extremeness scalar.

### 3.6 Faceting & mesh validity at extremes — a SEPARATE concern (the subdivision setting; resolves M5)

Because extreme is reachable (opt-in via the global gate), high morphs **may facet** — the 14.5k base
mesh's inter-vertex displacement *gradient* can exceed what the tessellation represents smoothly. **This
is a curvature/tessellation issue, NOT a magnitude one** (round-5 M-B). v7 does **not** pretend the value
caps bound faceting.

- **Handled via a SUBDIVISION SETTING (the user explicitly wanted one).** A quality option that
  subdivides the affected surfaces so extreme morphs stay smooth. Two concrete forms, decided by cost
  (§9 R6):
  - **Bake-time subdivision** of the affected surfaces baked into geometry (a real one-time geometry
    cost) — the safe default for shipped extreme archetypes.
  - **A runtime quality setting** that selects a higher-tessellation body mesh variant when extremeness
    is engaged — heavier, platform-gated.
  It is **not** runtime Catmull-Clark on the per-drag bake (unaffordable; rejected).
- **Faceting is VERIFIED by an INDEPENDENT dihedral/edge-angle metric (gate #8).** The per-edge dihedral
  angle on the posed mesh, flagged where it exceeds an absolute threshold set from *smooth-reference*
  renders. The metric knows no cap, so it independently catches "this extreme facets."
- **Quest honesty (round-6 M5 RESOLVED).** On Quest, the subdivision setting is off/low (§5.1), so
  **extreme morphs MAY facet on Quest — a known platform fidelity limit. Extreme mode is ALLOWED on
  Quest but NOT guaranteed smooth there.** v7 does NOT pretend gate #9 (Quest budget) covers this — gate
  #9 is itself gated on an XR/Mobile build existing (none does), so the Quest-faceting case is simply a
  stated, accepted platform limit, not a verified-clean gate. A desktop-authored extreme body replayed
  on Quest will facet; that is documented, not hidden.
- **Self-intersection at extreme / opt-in settings is a KNOWN, FLAGGED limitation — NOT a hard
  guarantee.** With extreme caps reachable AND grotesque combinations allowed in the interim (§3.4), the
  surface can fold through itself. v7 does **not** claim to prevent this. The self-clip check (§8 #1) is
  a **monitoring check, not a blocker** — it runs nightly to *surface* self-intersection regions
  (informing where subdivision / cap tuning / art attention is needed), but a self-intersection at an
  opt-in extreme or an allowed grotesque combination does NOT fail the build. At *default* caps the
  monitoring check is expected to stay clean; a regression there is worth attention but is still
  reported, not gated.
- Hands/feet (genuinely sparse MH density) remain where geometry shows; the subdivision setting is the
  lever there too.

### 3.7 Caps & extremeness as a VERSIONED asset (replay determinism)

The cap table (default caps + the extremeness→cap mapping) is frozen as a **versioned part of the
asset** (`assets/body/caps.v<N>.json` or equivalent).

- **Replay/randomize determinism holds against a fixed caps version.** A save / action log records the
  caps **version** plus the single global **extremeness**. Same archetype + nudge sequence + randomize
  seed + caps version + extremeness → byte-identical `BodyState` and baked mesh (gate #5). The `apply_capped`
  choke is a deterministic per-value `clamp(req, lo, hi)` over the derived interval — no cross-vertex
  reduction, no float-order hazard.
- **A retune bumps the version; stored values are NOT migrated.** Changing any cap produces `caps.v(N+1)`.
  Old saves **replay against their stored version** (deterministic) — and because caps are derived and
  load never re-clamps (§3.3), there is no value-snap migration at all. (round-6 m6 noted the broader
  "byte-identical baked mesh across PLATFORMS" claim rides on the bake's float accumulation, unverified
  with no XR/Mobile build — v7 narrows the cross-platform determinism claim to "within a platform" until
  a Quest build can be diffed; same-platform replay determinism holds.)

---

## 4. Breast-size semantics — drive size via the real volume axis (cup readout = separate future work)

The dead macro and the un-vendored 216-file cup cube are confirmed (§0). Two real options:

- **(a) Import the cup cube + factor tokens.** Vendor 216 `*cup*` targets, add token consts +
  val-splitters + product factors, re-bake the whole detail library. Large recurring data/vendor/bake
  cost for a coarse 3-anchor macro.
- **(b) Retire the dead macro; drive size via the live bidirectional volume axis.** Remove
  `breast/BreastSize`/`BreastFirmness` from the creator surface. Bind "Breast size" to the live
  `breast/breast-volume-vert-down|up` axis (body library `count` **down=244 / up=369**,
  `base_body_detail.index.json:159-160`). Label it honestly as a bidirectional volume axis.

**Decision: (b).** The volume axis already gives finer, direct, correctly-labeled control than a
3-anchor macro, at zero re-bake.

- **The "derived cup-letter readout" is DROPPED** (net-new mesh-measurement infra). The control is
  labeled by its honest axis (volume).
- **Authority resolved by facts-r1 #2:** the library `count` is authoritative; the `targets[]` `present`
  flag is meaningless. The volume axis is `count>0` ⇒ live.
- **Tradeoff (owned):** (b) loses factor-cube composition of cup size with gender/age/weight. (a) is the
  upgrade path if anatomically-correlated cup-vs-body composition ever becomes a hard requirement.
- **Guard (keyed on `count`, walking the `targets[]` shape):** a build-time assert (extend
  `body_region_sliders_test.gd`) fails if any exposed control binds a modifier whose delta-library
  `count == 0` in the index that control actually binds (body vs proxy, §0). A dead control like
  `BreastSize` can never silently ship. Dead macro entries are **retired**, not left as no-op aliases.

---

## 5. Visual fidelity — honest tiers, named prerequisites

The "plastic/broken" look is **shading and seating, not mesh density** (the flat-ambient test). No
runtime LLM, no per-config baking — every map is build-time generated from a cited source or authored
once and vendored CC0; maps are static and morph-invariant in UV space.

### 5.0 PREREQUISITE — tangent rebake under morph, seam-split; refresh on COMMIT

Verified (§0, facts-r1 #6): `bake_morphed_normals` recomputes positions + normals but never rebakes
`ARRAY_TANGENT`, so a tangent-space skin normal map shears under the large morphs the creator is for.
**Fix:** recompute per-corner (per-render-vertex) tangents on the baked positions **WITHOUT welding** —
follow the converter's seam-split Lengyel path (`body_converter.gd:222-224`), **not** the normal
rebake's per-base-vertex weld (mirroring the weld would re-introduce the very seam the converter split).

**Drag-time handling — REFRESH TANGENTS ON COMMIT, not during drag.** A during-drag tangent pass is a
second full per-render-vertex Lengyel pass over 14,517 verts on the per-motion bake the design flags as
the bottleneck (§0 facts-r1 #5) — too expensive. (With the deleted composed-field clamp, the per-drag
bake is exactly today's bake — the tangent rebake is the *only* added cost, paid on commit, not per frame.)

- **Tangents are recomputed on COMMIT** (drag release / committed slider change), via the seam-split
  Lengyel pass. During an active drag the skin detail-normal uses the pre-drag tangents, which drift as
  positions move, so normal-mapped detail is slightly off mid-drag and snaps correct on release.
- **Whether the drag-time approximation is acceptable is a USER-judged visual call** (§8 (b)). (round-6
  m4: drift is worst during exactly the large drags the creator exists for, and the #7b user gate can
  only be evaluated after Tier-A skin normals ship — a sequencing coupling, flagged.)
- **Quality gate (split, gate #7):** committed-state normal-map validity is **objective (a)** — no
  sheared/swimming detail, no re-introduced UV seam, specular-variation in band, via pixel-diff under
  flat light. The drag-time look is a **(b) user-gated** check.

### 5.1 Skin — Tier A ships first (generic), Tier B reaches reference (needs a baker decision)

- **Tier A (ships first, reaches *generic*):** a tiling generated/CC0 **detail normal** (pores) via
  `detail_normal`, a **roughness map** (kills the flat 0.7 sheen), subtle **albedo break-up**, low
  **SSS**. Engine-native, tangents present (post-5.0), UVs present. The bulk of the perceived fix.
  **Ceiling:** a tiling pore normal has no meso structure — it plateaus at *generic*.
- **Tier B (reaches reference):** a baked **meso normal + AO** from an offline subdivided high-poly of
  the CC0 base, baked against the 14.5k low-poly UVs. Godot has no offline baker → **baker toolchain
  DECISION** (below). Tier A ships regardless.
- **Skin albedo stays a tunable tone** (creator skin-tone + subtle baked AO/redness).
- **Quest:** SSS is a Forward+ screen-space effect; **gate it OFF on Quest Mobile** (normal/roughness
  only). The **subdivision setting (§3.6) is also Quest-gated** — extreme-morph subdivision is a
  desktop/quality-tier feature, low/off on Quest, so **extreme morphs may facet on Quest (known limit,
  §3.6)**. Honest cross-platform split, unvalidated until an XR/Mobile build exists (§9).

**Sub-decision (flagged):** the Tier-B baker — Blender-headless `bpy` (proven, heavy new dep) vs
in-Godot GPU bake (lighter dep, more to write). **Unresolved** — prototype both against the
plastic-look gate. Tier A unblocks the product.

### 5.2 Eyes — procedurally approximate the reference iris look; GAZE LEFT ALONE; cornea OPTIONAL

**Decided (user pivot; survived round 6):** keep the fully-procedural `eye.gdshader` AND the existing
96-vert proxy geometry; **improve the shader to procedurally approximate the desired iris look**
(stylized acceptable). **No iris PNG sampling, no iris re-vendor, no denser-proxy re-bake, and no
`gaze_dir` wiring.**

- **CORE — improve the procedural iris in `eye.gdshader`.** Procedurally model iris striations/fibers,
  the limbal ring, pupil, and iris/sclera specular so the eye reads like the reference texture without
  any `sampler2D`/`texture()`. The shader is already procedural (`:24-44`) and driven by the model-space
  normal vs `gaze_dir` (`:55-72`); this is shader-tuning of existing procedural code. **User taste-gated**
  (gate #6a).
- **GAZE — LEAVE IT ALONE (round-6 re-verified).** The eyes ALREADY look around via the `eye.L`/`eye.R`
  bones rotated by `val_look_dir` (`face_rig.gd:256-258`), with the skinned eyeball carrying its
  model-space normals (which the shader keys the iris off) — `gaze_rig.gd:7-9` documents this. **Driving
  the shader's `gaze_dir` uniform from the eye-bone forward would DOUBLE-COUNT** the rotation. No
  `gaze_dir` write is added; the bone-driven look mechanism is untouched. (The shader's `gaze_dir`
  uniform stays at its constant forward default — correct for a forward iris cap on an eyeball whose
  *geometry* is what rotates.)
- **CORE — eye color is a procedural parameter.** `iris_color` is a `body_rig.gd:45` uniform default;
  expose it (and any palette/variation uniforms) to a UI slider — the *only* eye-color control needed,
  no texture tinting.
- **OPTIONAL / DEFERRED — cornea parallax/refraction is NET-NEW shader infra.** No `VIEW`/camera/refract/
  parallax exists in the shader (§0). Making the iris sit *under* a convex cornea and shift with view
  angle requires adding a view vector and offsetting the iris under a cornea depth — new shader logic.
  Marked OPTIONAL/deferred; the CORE items deliver the iris look without it. If taken on later, gate
  #6a's "parallax under ±15°" companion applies only then.
- **The eye fidelity gate (#6a) is USER/reference-anchored taste** (§8 (b)). Objective companions
  (seating; specular-variation in band) remain agent-verifiable; the parallax companion is conditional
  on the optional cornea work.
- Proxy morph-follow is **verified fixed** (§0) — kept as a render regression assert (gate #2).

### 5.3 Brows / lashes — alpha-textured cards (author the alpha)

Keep the authored morph-following card geometry. Replace solid dark cards with **alpha-textured hair
cards** + `cull_disabled` + alpha-scissor (VR-safe). No CC0 brow/lash alpha source exists → author the
alpha in-repo (a small CC0-by-authorship hair-strand strip). Layered strips kill the brow-peak notch;
brow color ties to the hair-color param.

### 5.4 Camera / preview

- **Default view = the FACE, front, eye-level, head-and-shoulders.** The face-front default + centered
  pivot landed in `9c737c6` — reference it, do not re-guess `_yaw`. Gate #2/#6 renders confirm it stays
  correct.
- **Studio 3-point lighting rig** (key + fill + warm rim) + neutral IBL + a **lighting-rotate** control.
  **Always preview at the top quality tier**, with a "preview as Quest" toggle to show the degraded tier
  honestly (incl. the Quest extreme-faceting limit, §3.6).

### 5.5 Sculpt-mode spatial data + glow overlay — the full B2 fix + the two glow defects

- **ALL sculpt spatial data tracks the morphed surface (B2 — see §1.3 for trigger/mechanism).**
  `_glow_base_pos` (`:242-243`) feeds the picker (`:248,383`), the locality `positions` (`:461`), and
  the glow overlay (`:434`); all three refresh from the live baked `ARRAY_VERTEX` on the next pick after
  a bake, via a `_morphed_surface_dirty` flag set in `_apply_state` (`:1262-1271`). **The OWNER drives
  the rebuild (m-3):** the picker has no mesh handle (`scripts/util/cpu_accel_picker.gd:71,162-163`, m8-4), so
  `character_creator` re-fetches `surface_get_arrays(0)[ARRAY_VERTEX]` and calls
  `_cpu_picker.build(morphed_verts, _glow_tris)`, and refreshes `rest_positions` (`:383`) and the
  `decompose_drag` `positions` arg (`:461`).
- **Glow stuck at neutral pose — subsumed by the above** (the overlay re-reads the morphed verts in the
  same refresh).
- **Glow clips through the body.** `_rebuild_glow_mesh` stamps the overlay at exact body vertex
  positions (`:434`) with no outward offset, and the material has `no_depth_test = false` (`:281`) →
  z-fight. **Fix (m4):** offset overlay verts outward along the morphed per-base-vertex normals. The
  overlay mesh builds only ARRAY_VERTEX/INDEX/COLOR (`:432-438`) with no normals, so **thread the baked
  `ARRAY_NORMAL` from the same `surface_get_arrays(0)` read** into `_rebuild_glow_mesh` and offset each
  vert `v + n*ε`. These are the welded per-base normals (`body_state.gd:709-715`) so seam verts share a
  normal. Pair with depth handling (`no_depth_test` for the overlay, or `render_priority`/depth bias).
  - **ε must be WORLD-space, scale-corrected (m-7).** The overlay is a child of the **scaled skeleton**
    (`character_creator.gd:284`; `skeleton.scale = height_scale()`, `body_rig.gd:729-731`), so a fixed
    rest-space ε reads differently across the height range. Specify ε as a world-space distance and
    divide by `height_scale()` before applying: `v + n · (ε_world / height_scale())`. (m-C / round-6 m3:
    assumes the height scale is the only, uniform, skeleton scaling and the overlay is a direct skeleton
    child — both hold today (`body_rig.gd:729-731` sets uniform `skeleton.scale`); a future per-bone /
    non-uniform scale would break it with no guard. **Add a build/run assert that `skeleton.scale` is
    uniform** so the cleanup can't re-break invisibly.)

### 5.6 Minor scoped render/UX cleanups + deferred items (folded in, not dropped)

- **Tongue positioning off — NAMED fix; ASSET RE-BAKE cost (m-6 / m-A).** The tongue is part of the
  EYE/TEETH/TONGUE/GENITAL proxy mesh, not a facial expression target (`body_rig.gd` `_build_proxy`
  ~`:367-370,775-802`; `face_rig.gd:41-44` notes no expression target). It morph-follows via
  `proxy_morph.gd` but its **base rest offset is off**. The piece selector is concrete: the proxy mesh
  carries **one SURFACE per named piece** with a surface table `[{name, vert_offset, vert_count}, …]`
  (`proxy_morph.gd:4-7,28,46,66`); surface *i*'s verts occupy `[vert_offset, vert_offset+vert_count)`.
  **Named method:** look up the teeth (and jaw) piece surfaces by name, take their rest `ARRAY_VERTEX`
  over their ranges, compute the mouth-cavity centroid/AABB, then re-seat the **tongue** piece's rest
  attach offset to that cavity. **Cost (m-A — named honestly):** the proxy is one vendored
  `base_body_proxies.res` built offline by `tools/body_proxy_build.gd`; re-seating the tongue's rest
  verts means **regenerating that asset** (and the proxy detail library keyed to the global vertex
  numbering) — an **asset re-bake of `base_body_proxies`**, not a runtime field edit. Tested by
  extending gate #2 (tongue-surface centroid within the mouth-cavity AABB across morphs).
- **Opt-in hairstyle drape over the face — DEFERRED (`hair-parts.md` 1-4).** The default hair cap hide
  is fixed (`9c737c6`, §0), but opting into a visible BDCC2 hairstyle re-triggers unfixed seat defects.
  Explicitly deferred (hair-geometry seating is a standalone slice).
- **Dead `base_index` / `neutral_base_index` masking machinery (retire-don't-deprecate):** §5.0 touches
  `bake_morphed_normals`; while there, remove the dead region-masking index round-trip and its lying
  comments. Scoped minor.
- **Stale `_apply_state` cost comment (cleanup).** `character_creator.gd:1261` still says the bake
  *"Only runs on slider changes, so it's cheap,"* which is **wrong for the drag path**: a sculpt drag
  runs `_apply_state` → `bake_morphed_normals` **every mouse-motion frame** (`:663,472`, facts-r1 #5).
  Correct/remove this comment so an executor reading the code first isn't misled.
- **UX nits:** expand abbreviated slider labels to full words; introduce a shared `Theme` (replace the
  4 ad-hoc font sizes); consolidate the export buttons into one Export action with a format choice;
  remove the `P` dev picker-toggle from the *player* input map.

---

## 6. Persistence

- **Autosave `BodyState` + `HistoryTree` + the single global `extremeness` to `user://`** on every
  committed change and on `_exit_tree` / `WM_CLOSE_REQUEST`; restore on `_ready`. Record the **caps
  version (§3.7) AND the one global extremeness scalar** in the save (one scalar — round-trips trivially).
- **Sequencing — TWO slices, explicit dependency:**
  1. **Raw save/load/import ships FIRST (read side EXISTS, only wiring left — facts-r1 #4).**
     `creator_io.gd` already has `parse_payload` / `extract_history_from_png` /
     `extract_history_from_image`, round-trip tested. The near-term work is **wiring**: an Import button
     + FileDialog + drag-and-drop handler in `character_creator.gd` calling the existing parse
     functions. **Import safety = the existing hard-range projection clamp + dropping unknown keys**
     (`to_blend_weights`/`_project_modifiers`, `body_state.gd:244,270,282,376,384,393,554,563`; unknown
     keys dropped `:546`). **Load does NOT re-clamp to the cap** — beyond-cap values persist (the cap is
     an INPUT-time guard on new edits, not a load gate, §3.3). There is NO composed-field re-clamp on
     import — that machinery is deleted (§3).
  2. **Caps-version recording ships AFTER the §3 cap table exists.** Recording the caps version + global
     extremeness into the save is for replay determinism (§3.7); there is no value-snap migration (caps
     are derived, load never re-clamps).
- **"Save as archetype"** writes the current `BodyState` + thumbnail + extremeness to the USER archetype
  library. **These are USER artifacts (treated like user saves, path 7), loaded RAW — they may be beyond
  cap and persist (round-9 B9-1).** They are distinct from the FIRST-PARTY archetype roster (path 7a),
  which is the only set subject to the within-default-interval build gate #11 — a user "Save as archetype"
  is not gated to default intervals, by design (it is the user's creation). The first build's
  no-monster-by-DEFAULT guarantee covers first-party archetype PICKS, not user-saved archetypes (§1.1, §10).
- **Async load:** show the archetype grid first (cheap thumbnails over data), build the live
  rig/accel/picker deferred/threaded.

---

## 7. VR — a named dependency, NOT folded into this feature

Zero XR code exists (verified). VR delivery is a **separate large workstream** — OpenXR enablement + XR
camera/origin rig + per-eye stereo + controller input + comfort/locomotion — gating the cross-platform
parity commitment (DESIGN.md). **Out of this design's execution scope.**

This design only ensures the editing model **degrades gracefully**: the common path (pick archetype →
natural-unit nudge → mirror) is controller-native with no pointer assumption; the named region-handle
table (§1.3) projects from one definition to flat gizmos *and* future VR grab-volumes (honest status:
zero rows + flat-only today). T3 sculpt is honestly flat-primary; the world-space drag decomposition is
flagged as unfinished design work. Grab "feel," world-space sculpt port, and the Quest render +
subdivision tiers (§3.6, §5.1) — including the accepted Quest extreme-faceting limit — are **hypotheses
unvalidated until an XR build exists.**

---

## 8. Quality bar (concrete, testable)

Each is pass/fail under `nix run .#test` / `xvfb-run` renders. A change ships only if it doesn't
regress a green gate.

**Process principle — visual taste is USER-gated, never LLM-self-certified.** An agent may NOT
self-certify a subjective visual-quality verdict. Gates split:

- **(a) MEASURABLE/OBJECTIVE — an agent/LLM MAY verify.** No UV seam via pixel-diff under flat light,
  proxies follow morph via vertex deltas, monotone size sweep, determinism/round-trip byte-equality,
  specular-variation std-dev vs a baseline, silhouette faceting via an edge-angle metric, AABB bounds,
  self-intersection via BVH/SDF (as a *monitoring* report, §3.6).
- **(b) SUBJECTIVE/TASTE — must be USER-judged (or reference-anchored).** "Does the skin look like
  skin," "does the iris look right," "is the face non-uncanny," the belly-group "reads as paunch" call,
  the drag-time tangent-drift look. Process: **render → present → user verdict.** Agents NEVER promote a
  gate on a (b) judgment.

1. **First-build no-monster check — three clauses, NONE depending on a deferred item (rewritten,
   resolves round-7 B7-3).** v7's clause asserting "no self-intersection" depended on a BVH self-clip
   the SAME design defers (§10.2) — a first-build→deferred dependency. v8 splits gate #1 into what is
   actually buildable first; the self-intersection pass is REMOVED from it and moved to deferred
   monitoring (§3.6, R8):
   - **(a) OBJECTIVE — cap-enforcement across ALL LIVE write paths (the choke is correct; round-8
     B8-1/B8-3 regression guard).** Drive each LIVE write path (sculpt apply, region slider,
     headline-field set, numeric entry, randomize) with adversarial requests including the EXTREME poles,
     and assert every stored value respects the §3.2 INTERVAL invariant `lo ≤ stored ≤ hi` where
     `(a,b)=cap(control,extremeness)`, `lo=min(a,cur)`, `hi=max(b,cur)` (round-8 m8-3 — the interval
     invariant, NOT v8's neutral-0 magnitude invariant which was wrong for headline axes). **Include the
     SCULPT path against an UNCURATED modifier (round-11 MA-1): drive `decompose_drag`/`apply_capped` on a
     non-macro modifier with no authored interval and assert it is clamped to its DERIVED interval (§3.1
     DEFAULT CAP RULE), not the hard range — the choke covers all ~280 sculpt-reachable modifiers, not just
     the curated ~56.** Specific
     regression asserts: (i) **B8-1** — `masculinity` (neutral 50, default `[20,80]`) with `req=100`
     lands at `80` and `req=0` lands at `20` (a WINDOW, not a `±c` band around 0); a bidirectional
     modifier with default `[-0.5,+0.5]` and `req=-1.0` lands at `-0.5`; (ii) **B8-3** — with `cur=+0.9`
     (ratcheted, `b=0.5`), `req=-0.9` lands at `+0.5` (the floor), NOT `-0.9` — the high-pole ratchet
     does NOT re-admit the low pole; no free sign-flip across neutral. Also assert restore/load paths
     (undo/redo/reset/jump/import) do NOT clamp — a persisted beyond-cap value survives a restore via
     `set_value_no_signal` (B8-2). **(iii) Round-10 B10-1/M10-2 — the LIVE-EDIT WRITE-BACK PROTOCOL: after
     an OUTWARD-clamped live edit (`req > b`), assert (1) the slider's `value` and its numeric label both
     read the clamped `new` (NO desync — M10-2), and (2) the live `value_changed` callback fires EXACTLY
     ONCE for the user action — no re-entrant second fire and no second `_apply_state` bake (instrument with
     a callback/bake counter — the B10-1 feedback-loop guard).** **(iv) ONE PATH-AGNOSTIC TRANSIENT-DIP
     ASSERT — the choke-capture invariant (round-11 MA-2 + round-12 MA12-1 + round-13 MA13-1, generalized in
     v14).** Rather than one assert per write sub-path (the v12/v13 per-path enumeration that always left the
     next unenumerated sub-path — the mirror twin — exposed), assert the INVARIANT directly: **for ANY control
     reached through `apply_capped` during a gesture, a transient mid-gesture dip never collapses that
     control's ratchet.** Concretely, pre-load `cur=0.9` on a control with default `[-0.5,0.5]` (held interval
     `[-0.5,0.9]`); within a single active gesture drive that control's value to `0.6` then back to `0.85`,
     then end the gesture; assert the value CAN reach `0.85` mid-gesture (the held `cur_start=0.9` interval was
     NOT collapsed — neither the choke's clamp nor, where a widget is bound, its `max_value`), and that only on
     gesture-end at a committed `0.6` does the interval recompute to `[-0.5,0.6]`. Run this parameterized over
     EACH way a control can reach the choke, so the invariant — not an enumerated list — is what the gate
     checks:
     - **(iv-a) directly-touched** — a slider drag (`drag_started` → `value_changed` stream → `drag_ended`)
       on the bound control (round-11 MA-2);
     - **(iv-b) sculpt-decomposed** — a continuous sculpt gesture (`_dragging_morph=true` →
       `_apply_morph_drag` delta stream → `_end_morph_drag`) driving the modifier, run BOTH for a modifier
       WITH a bound T2/T3 slider (assert `max_value` not collapsed) AND a SCULPT-ONLY modifier with NO bound
       slider (assert the choke's stored value not floor/ceiling-trapped) (round-12 MA12-1);
     - **(iv-c) multi-modifier** — a single sculpt gesture whose `decompose_drag` returns SEVERAL modifiers
       (each pre-ratcheted `cur=0.9`); assert EACH gets its own held `cur_start` (captured on its first touch
       through the choke) and none falls onto the live-recompute "non-gesture" branch (round-12 MA12-1);
     - **(iv-d) MIRROR TWIN (round-13 MA13-1, the v14 coverage proof)** — mirror ON (default), a PRE-RATCHETED
       contralateral twin `T=twin(M)` (`cur_T=0.9`, default `[-0.5,0.5]`), and a CONTINUOUS one-sided gesture
       on `M` (slider OR sculpt) that dips inward then back out. The §1.3 mirror step writes `T` per frame via
       `apply_capped(T, …)`. Assert `T` reaches `0.85` mid-gesture (its held `cur_start=0.9` was captured on
       `T`'s first touch through the choke, NOT recomputed from the live mid-gesture `cur_T`), and that `T`'s
       ratchet collapses only on the committed gesture-end value — the exact MA13-1 trap, now closed by the
       choke-capture invariant, with NO mirror-side capture code. (This is the assert the v13 gate could not
       express: the twin is never a `decompose_drag` key, so an enumeration-based gate never reached it.)
     Because the harness drives the SAME pre-ratcheted-then-dip scenario through every reach-the-choke path
     (iv-a..iv-d), it tests the invariant "any control written through `apply_capped` during a gesture uses a
     held interval captured at its first touch," which is what makes a NEW write sub-path (future cascaded /
     derived write) covered without a new assert. **(v) Round-11 MA-1 — UNCURATED SCULPT MODIFIER: drive the
     sculpt apply on a non-macro modifier with NO authored interval and assert it clamps to its DERIVED
     interval (§3.1 DEFAULT CAP RULE), not the hard range.** **(vi) Round-14 MA14-1 — STATE-REPLACING OP
     MID-GESTURE leaves a correct, non-garbled node (the gesture-lifecycle-interruption invariant).** Pre-load
     `cur=0.9` on a control with default `[-0.5,0.5]`; begin a continuous gesture (held slider/sculpt drag) on
     that control so the choke captures held `cur_start=0.9`; mid-gesture fire a STATE-REPLACING op — a raw
     restore (undo: replace `_body_state.modifiers` with a prior node where the control = `0.0`,
     un-ratcheted), exercised also for an archetype/import load and an extremeness change. Assert the SAFETY
     property: (1) the op ABORTS the gesture — `_drag_start_value` is cleared, the sculpt accumulators/brackets
     reset, `_dragging_morph=false` — so no active gesture survives and (held-button case) a subsequent mouse
     MOTION with the button still held starts NO gesture (dead hover), i.e. no zombie resume; (2) a FRESH
     gesture begins only on the next release+re-press, and when it does its first-touch capture reads
     `cur_start` against the NEW state (`0.0`), so the restored un-ratcheted interval `[-0.5,0.5]` governs, NOT
     the stale `0.9` ratchet; (3) no garbled node commits — the value at any release after the abort is the
     correct (non-garbled) value, not one computed against a base the restore changed. This is the exact MA14-1 trap — the symmetric direction of the v14 no-capture-on-
     bypass property — now closed by the lifecycle invariant. A small harness on a single bound slider + a
     multi-modifier sculpt drag + a mirror-ON one-sided drag + a mid-gesture undo/load/extremeness-change
     covers (i)–(vi). Runnable first-build — needs only
     the choke + the caps asset (NET-NEW, §10.1/m7-1).
   - **(b) DEFAULT-mode per-control plausibility (the per-control sweep — objective AABB MEASUREMENT,
     USER-gated acceptance, NOT a combination guarantee):** N=10,000 seeded random axis vectors **at
     DEFAULT caps** (extremeness 0); **per-control, each axis alone** produces a body AABB that is then
     judged **within "human + tasteful stylized" bounds**. This is the **cap-plausibility /
     per-control-cap-tuning harness** at the parameter level — explicitly **NOT a combination guarantee**
     (combination-plausibility is deferred, §3.4; in the interim grotesque combinations are possible and
     accepted). No self-intersection clause here. **Acceptance boundary is partly USER-TASTE-GATED
     (round-9 M9-3):** the sweep mechanically MEASURES each control's AABB (objective), but the pass/fail
     call on "human + tasteful stylized range" is a USER sign-off (the v3 visual-taste-is-user-gated
     principle, §8 (c)) — so the default-interval constants this sweep tunes are USER-approved, not
     agent-self-certified. This is the validating pass for the net-new default-interval authoring (§3.1, M9-3).
   - **(c) USER-judged default-mode combined-extreme RENDER (taste-gated, §8 (b)).** Render a body with
     several default-capped controls pushed to their default poles together and **present it for a USER
     verdict** ("reads as a person, not a monster, at default caps"). This is the taste gate that
     replaces the removed automated self-intersection clause — an agent may NOT self-certify it.
   - **Self-intersection is DEFERRED MONITORING, not a first-build gate (§3.6, R8).** A
     BVH/spatial-hash broadphase + narrow-phase near-pairs, run as a nightly report — NET-NEW feature
     work, no self-clip code exists today (verified, round-7 B7-3). It NEVER fails the build. (round-6
     M6: monitoring-only, so the "reduce N if slow" concern guts no guarantee; v8 makes no combination
     no-monsters guarantee to gut.)
2. **(a)** **Eyes (+ tongue) seated at ALL genders/ages (regression guard):** render face at masc
   0/50/100 and age 18/40/70; assert eye proxy centroid within the eye-socket AABB and teeth/**tongue**
   within the mouth-cavity AABB at every point (tongue per §5.6); assert masc0 ≠ masc100 displaced
   (proxy follow alive — facts-r1 #1).
3. **(a)** **Monotone breast-size sweep:** sweeping the volume axis 0→100 monotonically increases
   chest-region volume at constant build; no exposed control binds a `count==0` target in the index it
   binds (build-time assert, §0). (No cup-letter assert — readout dropped, §4.)
4. **(a)** **Persistence round-trip:** set non-default → autosave → new state → restore → byte-identical
   `to_blend_weights()`; quit→relaunch restores; **import via the wired button/drop handler round-trips
   a JSON and a PNG-embedded state; a beyond-cap loaded value PERSISTS through the real UI restore path
   (undo / redo / reset / jump exercised at extremeness 0 do NOT re-clamp it — round-8 B8-2; verified via
   the `set_value_no_signal` bypass, §3.2 path 6); the recorded global extremeness round-trips** (slice 1).
   Caps-version recording is slice 2.
5. **(a)** **Determinism (against a fixed caps version + the single global extremeness, §3.7):** same
   archetype + nudge sequence + randomize seed + caps version + extremeness → byte-identical `BodyState`
   and baked mesh **within a platform** (cross-platform byte-identity NOT claimed until a Quest build can
   be diffed, round-6 m6). The choke clamp is a per-value `min`/`max`/`clamp` (no float-order hazard).
   A caps retune bumps the version; old logs replay against their stored version (no value-snap migration).
   **NET-NEW dependency (m7-1):** this gate needs the caps ASSET (`assets/body/caps.v<N>.json`), which
   does NOT exist yet (`assets/body/caps*` is absent) — building it is first-build work, not a near-existing gate.
6. **Fidelity floor vs reference renders (SPLIT):** a front 3/4 face at top tier under the 3-point rig.
   - **(a) objective:** eyes seated; no face/cranium two-tone or back-of-head/inner-leg seam (incl. no
     tangent seam, §5.0) via pixel-diff under flat light; skin detail survives flat-ambient.
     **Conditional:** forward eyes that parallax under ±15° — ONLY if the optional cornea work (§5.2) is
     taken on; until then N/A (gaze is bone-driven, not a `gaze_dir` claim).
   - **(b) USER-gated taste (#6a):** the procedural iris approximates the reference look; brows read as
     feathered hair; skin reads as skin; non-uncanny.
7. **Tangent rebake validity (§5.0, SPLIT):**
   - **(a) committed state:** render a normal-mapped surface **after commit** at a large morph; assert
     no sheared/swimming detail and **no re-introduced UV seam** (seam-split rebake, pixel-diff under
     flat light); specular-variation in band. Fails until §5.0 ships.
   - **(b) drag-time look — USER-gated:** render mid-drag (pre-commit tangents); the user judges drift.
8. **(a)** **Edge-of-range faceting check (§3.6) — INDEPENDENT metric. NET-NEW harness (m7-1):** no
   dihedral/edge-angle metric code exists today — this is a build-from-scratch metric, not a
   near-existing gate. Render an allowed-extreme
   morph and measure faceting via the **per-edge dihedral angle**, flagging where it exceeds an absolute
   threshold set from *smooth-reference* renders — a metric that knows no cap. Remedy: the subdivision
   setting (bake-time or runtime quality tier), named cost (§9 R6). **(b)** The user-visible max is
   rendered for USER review. **On Quest (subdivision off/low) extreme morphs MAY facet — accepted known
   limit (§3.6), NOT a gate failure.**
9. **(a)** **Quest budget:** Quest tier (normal+roughness, SSS off, subdivision off/low §3.6) renders
   within the Mobile-backend frame budget. **Gated on an XR/Mobile build existing (§9) — currently
   UNRUNNABLE; does NOT cover the Quest extreme-faceting limit (which is an accepted limit, not a gated
   guarantee, round-6 M5).**
10. **(a)** **Sculpt mode + mirror-vs-resolution + acts on morphed surface (corrects round-5 B-A):** the
    Sculpt toggle is a **visible UI control**; orbit (left-drag) works with no pick latency outside
    sculpt mode; in sculpt mode an up-drag at the breast handle increases volume **picking against the
    morphed surface (B2)**. **Resolution: a bilateral arm/leg slider RESOLVES to BOTH `armslegs/l-…` AND
    `armslegs/r-…` and drives BOTH arms — REGARDLESS of the mirror toggle** (assert with mirror BOTH ON
    and OFF). **Mirror toggle: a ONE-SIDED edit** applies to the twin when mirror ON, and ONLY to the
    touched side when mirror OFF (still resolving the touched side); midline edits apply once (m3 guard).
11. **(a)** **Archetype within-default-interval + default-interval-contains-neutral BUILD GATE (round-9
    B9-1 + round-10 M10-1/m10-2, NET-NEW first-build assert).** A build-time test asserts TWO things:
    - **(11a) Archetype containment:** load EVERY shipped first-party archetype
      (`assets/body/archetypes/*.json`) and assert EVERY value of EVERY control lies within that control's
      DEFAULT interval `cap(control, 0)` (the headline fields and each curated modifier). **FAILS THE
      BUILD** if any archetype carries a beyond-default-cap value. This makes the §3 no-monster-by-DEFAULT
      guarantee true for archetype PICKS (the raw load path 7a is safe only because this holds — §1.1, §3.3).
    - **(11b) Neutral-in-interval invariant (round-10 M10-1/m10-2; scoped by the round-11 MA-1 rule):** for
      EVERY control (NOT only the keys present in some archetype — an archetype's `modifiers` map is SPARSE,
      so containment alone leaves absent controls unchecked, m10-2), assert `a ≤ neutral ≤ b` where
      `(a,b) = cap(control, 0)` and neutral = the control's absent/default value (modifier neutral 0;
      headline field default; age 25). **FAILS THE BUILD** on a `[min>0, b0]` unipolar floor or any band
      that does not straddle its neutral. **Scope (round-11 MA-1):** "every control" = the ~56 + headline
      AUTHORED intervals (checked numerically) plus every DERIVED interval — but a derived interval is
      symmetric/range-anchored about its neutral BY CONSTRUCTION, so it satisfies the invariant inherently;
      the gate either trusts that construction proof or cheaply re-derives + asserts each in a loop. Either
      way the gate adds NO ~280-row hand-authoring burden — the authoring stays ~56 + headline (§3.1).
      This is what makes the absent→neutral read safe (no manufactured beyond-floor `cur`, no silent floor
      ratchet — §3.1/§3.2) and is the gate the erase reconciliation (M9-2) depends on.
    Objective (a): both are numeric containment checks against the caps asset. Depends only on the caps
    asset (itself first-build) + the archetype roster; its acceptance criterion is the SAME default
    intervals gate #1b tunes — so it adds no new tuning input, only enforcement. (USER taste enters via
    #1b's interval sign-off, not via these containment asserts, which are fully objective.)

---

## 9. PREREQUISITES & RISKS (named, honest, updated this revision)

**Most v6 bounds risks are now RESOLVED** (the cap state model is finalized — §3). Remaining genuinely
open items are the DEFERRED concerns plus the honest execution risks (default-cap tuning, subdivision
cost, Tier-B baker, procedural-iris look user-judged, Quest costs, self-intersection-at-extremes known
limit).

| # | Item | Status | Plan |
|---|---|---|---|
| R1 | **Tangent rebake under morph** | **Verified BROKEN; refresh on COMMIT, seam-split (facts-r1 #6).** The ONLY added cost on the bake path. | Recompute per-render-vertex Lengyel tangents on baked positions without welding, on commit. Mid-drag normal is approximate (USER-judged, §8 #7b). |
| R2 | **Offline baker (Tier-B meso normal/AO)** | **Sub-decision UNRESOLVED** (`bpy` vs in-Godot GPU bake). **GENUINELY OPEN — DEFERRED.** | Prototype both vs fidelity gate #6; Tier A ships without it. |
| R3 | **Procedural iris look; GAZE LEFT ALONE** | **Eye plan held; gaze correct — DO NOT wire `gaze_dir`** (would double-count; round-6 re-verified). Cornea parallax OPTIONAL net-new infra. **Procedural-iris LOOK is GENUINELY OPEN (user taste).** | Improve procedural iris (striations/limbal/pupil/specular); expose `iris_color`/palette. NO `gaze_dir` write. Cornea parallax deferred/optional. Look verdict user-gated (gate #6a). |
| R4 | **Breast size** | **Decided (b)** — drive via the live volume axis; cup readout DROPPED. Guard on library `count`. | Honest volume-axis label; (a) is the upgrade path if cup×body composition is ever required. |
| R5 | **Belly group** | **SURFACE the EXISTING belly axes; NO new asset, NO pregnancy reuse** (facts-belly.md; survived round 6). **v12 (round-11 MI-1):** the belly group REFERENCES the existing `:63` "waist" slider (`waist-circ`) and does NOT re-add it; adds only the net-new `torso-scale-depth` (belly-forward) + Weight/apple — NO modifier driven by two controls. The COMBINATION (M4) is the deferred combination-plausibility concern, NOT solved by per-control caps. Pregnancy stays OUT. | UI: label & group existing morphs; reference `:63` waist, do not duplicate it. Combination plausibility deferred (§3.4); interim grotesque combos accepted; default caps keep each axis plausible. |
| R6 | **Bounds — FINALIZED (resolves round-6 B1/B3/M1/M2/M3 + round-7 B7-1/B7-2 + round-8 B8-1/B8-2/B8-3/m8-1 + round-9 B9-1/M9-1/M9-2 + round-10 B10-1/M10-1/M10-2 + round-11 MA-1/MA-2 + round-12 MA12-1/MI12-1 + round-13 MA13-1/MI13-1 + round-14 MA14-1/MI14-1)** | **RESOLVED; core formula VERIFIED SOUND & UNCHANGED in v15 (re-derived rounds 9 + 10 + 11; rounds 12–14 attacked only the held-interval WIRING — capture, lifecycle, display — not the formula).** Bounds = raw `modifiers` + ONE GLOBAL `extremeness` (creator-settings layer) + DERIVED `cap(control, extremeness) -> (a,b)` a **per-control ALLOWED INTERVAL** (neutral-agnostic, absolute units) widening toward the hard range as extremeness 0→1 + the **single `apply_capped` choke covering ALL LIVE write paths** incl. the headline-field `set()` path (B7-2). **ONE neutral-agnostic clamp:** `hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)` — works for bidirectional/unidirectional/headline-neutral≠0/age-no-neutral with NO axis-type tag (B8-1); each pole ratchets INDEPENDENTLY so no beyond-cap sign-flip (B8-3). `cur` read = stored-OR-neutral-if-absent; `apply_capped` WRAPS the existing `_set_modifier` erase-at-`|v|<1e-6` (loses no ratchet, GUARANTEED by the **`neutral ∈ [a,b]` invariant** — round-10 M10-1; the `[min>0,b0]` unipolar floor is FORBIDDEN; gate #11b asserts it for EVERY control, not just archetype keys — round-10 m10-2). **COMPLETE v11 LIVE-EDIT WRITE-BACK PROTOCOL (round-10 B10-1/M10-2):** (1) `new=apply_capped`; (2) write `new` to model (erase-at-neutral honored); (3) `[lo,hi]=[min(a,new),max(b,new)]`; (4) set bounds `[lo,hi]` FIRST then `set_value_no_signal(new)` then display `new` in the label — so the callback never re-enters (no re-bake loop, B10-1) AND the thumb+label show the clamped `new` (no desync, the honesty property delivered, M10-2). RESTORE/LOAD write RAW + `set_value_no_signal` so beyond-cap persists (B8-2). **TWO load paths (round-9 B9-1):** first-party ARCHETYPES build-gated WITHIN default intervals (gate #11a) ⇒ archetype picks never exceed default cap (no-monster-by-DEFAULT holds for pick-and-go); USER saves/imports raw-preserve (may exceed cap, by design). Slider/sculpt bounds are GESTURE-AWARE via the CHOKE-CAPTURE INVARIANT (round-11 MA-2 + round-12 MA12-1 + round-13 MA13-1, superseding M9-1's every-edit recompute): the held interval is a property of the `apply_capped` choke itself — the FIRST time any control flows through the choke within an active gesture, the choke lazily captures its `cur_start` into the SAME `_drag_start_value` map (no per-path capture code), so EVERY write path through the choke is covered — directly-touched, sculpt-decomposed, AND the §1.3 mirror twin (the round-13 MA13-1 hole, closed) — with NO enumeration to miss; bounds + the choke's clamp are HELD at `[min(a,cur_start),max(b,cur_start)]` for the whole gesture and recomputed from the settled `new` only on gesture-end/commit/load (an extremeness change runs the FULL all-controls sweep — round-13 MI13-1), in the protocol's bounds-first order (round-10 B10-1) — so a transient mid-gesture dip cannot collapse a ratchet on ANY sub-path, the thumb still can't pass the live cap, and `value_changed` can't re-fire. **GESTURE-LIFECYCLE-INTERRUPTION INVARIANT (round-14 MA14-1):** any STATE-REPLACING op mid-gesture — raw restore (undo/redo/reset/jump), archetype/import load, OR an extremeness change — ABORTS the active gesture (clears `_drag_start_value` + sculpt accumulators/brackets, ends the gesture) BEFORE applying, so no zombie gesture survives (a fresh first-touch capture against the new state begins only on the next press) and no stale `cur_start` survives; this ONE rule SUBSUMES the v12/v13 MI12-1 deferred-extremeness special case (extremeness change now aborts-then-recomputes immediately, not defers). The choke always reads live `cap(·)` so there is no interim clamp gap. **SHARED-WIDGET DISPLAY (round-14 MI14-1):** a bilateral slider (one widget, L+R) displays the CONSERVATIVE intersection `[max(lo_L,lo_R), min(hi_L,hi_R)]` of its two controls' cap intervals so the thumb can't exceed either side's true cap when L/R diverge; per-control held intervals + clamping are individually unchanged. A one-pole-ratcheted slider shows an intentional asymmetric range with a cap-extent marker (m9-4). **DEFAULT CAP RULE (round-11 MA-1):** `cap(·)` is TOTAL — authored interval for the ~56 + headline, else a DERIVED symmetric range-anchored interval (single global fraction `f`) for the ~224 uncurated sculpt-reachable modifiers — so the choke caps ALL live write paths (incl. sculpt's `build_accel`-reachable non-curated modifiers) with authoring still ~56 + headline, not 280. Inward ratchet EMERGES (no per-control state). Load never re-clamps; caps derived ⇒ no value-snap migration. Caps a **versioned asset, NET-NEW (`assets/body/caps*` absent today, m7-1)**. **GENUINELY OPEN: subdivision-setting implementation + cost; the conservative DEFAULT-interval constants — net-new authoring of ~56+ interval SHAPES in non-uniform units (round-9 M9-3), with USER-gated acceptance — until the §8 #1b per-control plausibility sweep runs.** | Cap table (per-control `[default_a,default_b]` + `[hard_min,hard_max]`, every interval containing its neutral) as versioned data + the pure `cap(·)` fn; the one `apply_capped` choke (wrapping `_set_modifier`'s erase) + the 4-step write-back protocol at every LIVE write path + the `set_value_no_signal` raw path at every restore/load; build gate #11a archetypes within intervals + #11b neutral∈[a,b] for every control; global extremeness toggle/slider (T3). Subdivision: decide bake-time vs runtime quality tier (cost). |
| R7 | **Combination plausibility** | **DEFERRED — NOT in the first build (user: low prio). Seam reserved (§3.4).** "Sum of caps prevents monstrosity" is REMOVED (round-6 B2). Interim: grotesque combinations possible (accepted); default mode plausible only via conservative per-control caps. | Reserve the post-composition validity-check seam (toggleable nudge/warn over the value vector). Build later. |
| R8 | **Self-intersection check** | **MONITORING, not a blocker (§3.6).** Feature work (no self-clip code today). Reinforced KNOWN limit now that grotesque combos are allowed. At default caps a clean-expected report; at extremes/combos it surfaces the known limit, never fails the build. **GENUINELY OPEN (monitoring infra).** | Build BVH/spatial-hash self-clip as a nightly monitoring report; per-PR seeded smoke over adversarial combos as a report. |
| R9 | **Faceting at extremes + Quest (resolves round-6 M5)** | **Subdivision SETTING (verified by independent dihedral metric, gate #8).** **On Quest (subdivision off/low) extreme morphs MAY facet — ACCEPTED known platform limit; extreme allowed but NOT guaranteed smooth on Quest. Gate #9 does NOT cover it (no XR/Mobile build).** **GENUINELY OPEN: subdivision cost; Quest extreme-faceting is a stated limit, not a fix.** | Gate #8 flags faceting; subdivision smooths on desktop; Quest faceting documented as a limit; user reviews the visible max. |
| R10 | **Sculpt input scheme** | **Decided** — KEEP the explicit mode; make it a **visible** control; NOT always-on grab. | Visible Sculpt toggle + indicator; pick latency only inside sculpt mode. Gate #10. |
| R11 | **Sculpt acts on morphed surface** | **Decided (B2); OWNER-driven rebuild (m-3).** Scope = morphed REST-pose body (no skinned-pose handling, m-B). | OWNER refreshes ALL sculpt spatial data (picker, locality, glow) from the live baked morphed `ARRAY_VERTEX`, dirty-on-bake. §1.3/§5.5. Gate #10. |
| R12 | **Persistence sequencing + import (SIMPLIFIED v7)** | **Import safety = existing hard-range projection clamp + drop unknown keys; load does NOT re-clamp to the cap (beyond-cap persists, §3.3); NO composed-field re-clamp (deleted).** Raw save/load/import is wiring (facts-r1 #4). One global extremeness scalar round-trips trivially. | Ship import (wiring) in slice 1. Caps-version recording (replay determinism) after §3. |
| R13 | **VR workstream** | **0% implemented**, large separate prerequisite, out of scope. **Quest tier costs GENUINELY OPEN** (skin tier + subdivision tier + extreme-faceting limit), unvalidatable until an XR/Mobile build exists. | Editing model degrades gracefully; one handle table → flat + future VR. Quest render + subdivision tiers = hypotheses until an XR build exists. |
| R14 | **Tongue proxy re-seat + glow overlay** | **NAMED; tongue is an ASSET RE-BAKE (m-A).** Re-deriving the tongue rest offset means regenerating `base_body_proxies.res` (+ proxy detail library), an offline asset re-bake, NOT a runtime field. Glow ε world-space scale-corrected (m-7) `v + n·(ε_world/height_scale())` **+ a uniform-scale assert (round-6 m3)**. | Glow: outward offset along threaded morphed normals, world-space ε + depth handling + uniform-scale assert. Tongue: select piece surfaces by name→range, re-derive rest offset from mouth-cavity centroid, **re-bake the proxy asset**; gate #2 asserts tongue-in-mouth. |
| R15 | **Opt-in hair drape** | **Deferred** (separate from the fixed default cap; `hair-parts.md` 1-4). | Hair-geometry seating is a standalone slice. |

**Resolved this revision (round-13 attack — ONE generalizing fix + one clarification; core formula untouched & verified sound):**
- **CHOKE-CAPTURE INVARIANT — the held interval is captured by the choke on first touch, path-agnostically
  (round-13 MA13-1, the generalizing fix):** round 13 found the THIRD instance of the held-interval defect
  class — the §1.3 MIRROR step writes `twin(M)` per frame through the live choke (mirror ON = default), but
  the twin is never a `decompose_drag` key nor the slider's bound control, so v13's enumerated capture
  missed it, collapsing a pre-ratcheted twin on a transient-dip drag. v14 makes the held-interval capture a
  property of the `apply_capped` choke: the FIRST time a control flows through the choke within a gesture, it
  lazily captures `cur_start` (guarded `if not has`) into `_drag_start_value`; every later write clamps
  against the held interval; bounds recompute at gesture end (the map cleared). This covers EVERY write path
  through the choke — directly-touched, sculpt-decomposed, mirror twin, numeric, randomize, headline, future
  cascaded/derived — with NO per-path enumeration, collapsing the enumeration defect class to one invariant.
  Gate #1a's per-path dip asserts become one path-agnostic assert over every reach-the-choke path incl. a
  pre-ratcheted twin (iv-d) (§3.2 step 3 + choke note + path 1 + slider-bounds; §1.3; §8 #1a).
- **Gesture-end recompute = FULL all-controls bounds sweep (round-13 MI13-1):** the deferred
  (`_extremeness_dirty`) recompute at gesture-end runs the same all-controls widget-bounds sweep an immediate
  extremeness change runs, refreshing non-touched controls' bounds too. No interim correctness gap — the
  choke always reads live `cap(·)` at clamp time; only widget DISPLAY is one sweep behind, brought back in
  sync by the gesture-end full refresh (§3.2 after the slider-bounds paragraph).

**Resolved earlier (round-11 attack — contained choke-edge fixes; core formula untouched & verified sound):**
- **DEFAULT CAP RULE — every sculptable modifier capped, authored-or-derived (round-11 MA-1):**
  `cap(control, e)` is a TOTAL function — AUTHORED interval for the ~56 curated + 6 headline, else a DERIVED
  interval from the modifier's own registry range (`[neutral−f·R, neutral+f·R]` clamped, unipolar floor
  pinned to `a=0`, widened by extremeness like the authored ones). `build_accel` (`morph_drag.gd:133-156`)
  proves sculpt reaches all ~280 non-macro modifiers; the rule gives each an interval so `apply_capped`
  always has one and the choke genuinely caps the sculpt path — no-monster-by-DEFAULT holds on T3 sculpt.
  Gate #11b holds for both (derived BY CONSTRUCTION). Authoring stays ~56 + headline, NOT 280 (§3.1, §3.2
  path 1, §8 #1a/#11b).
- **DRAG-AWARE slider bounds — no ratchet collapse from a transient mid-drag dip (round-11 MA-2):** because
  `value_changed` fires continuously during a drag (`character_creator.gd:1041-1046,1175`), recomputing
  `[lo,hi]` from the live mid-drag `new` (v11 M9-1) trapped the gesture on a dip below the ratcheted `b`.
  v12 HOLDS the bounds at the drag-START interval `[min(a,cur_start),max(b,cur_start)]` for the whole drag
  (and clamps mid-drag against that held interval), recomputing from the settled `new` only on
  drag-end/commit/extremeness-change/load. The B10-1 bounds-first-then-`set_value_no_signal` order is
  unchanged; the desync M9-1 fixed is still fixed (bounds DO recompute at settle) (§3.2 steps 3/4).
- **Belly references the existing waist slider (round-11 MI-1):** §2 no longer re-adds
  `measure/measure-waist-circ` (already the `:63` "waist" slider); the belly group adds only the net-new
  `torso-scale-depth` + Weight/apple and references `:63` for girth. No modifier driven by two controls;
  the anti-duplicate rule extended to `waist-circ` (§2).

**Resolved earlier (round-10 attack — LAST-MILE INTEGRATION-BOUNDARY fixes; core formula untouched & verified sound):**
- **Complete live-edit widget write-back protocol (round-10 B10-1 + M10-2):** the exact 4-step ordered
  sequence — `new=apply_capped` → write model → `[lo,hi]=[min(a,new),max(b,new)]` → set bounds FIRST then
  `set_value_no_signal(new)` then display `new`. Because the write-back uses `set_value_no_signal`, the live
  `value_changed` does NOT re-enter (no re-bake feedback loop, B10-1); because thumb + label both show the
  clamped `new`, there is no desync and "gating visible at the slider, not a hidden lie" has a real mechanism
  (M10-2). Applies to every live write path (1–5: slider, numeric, sculpt-driven slider sync, headline,
  randomize); restore/load already use the raw bypass (§1.3, §3.2, gate #1a-iii).
- **Default-interval-contains-neutral invariant (round-10 M10-1 + m10-2):** REQUIRE `a ≤ neutral ≤ b` for
  EVERY control; the `[min>0, b0]` unipolar floor is FORBIDDEN. Gate #11 EXTENDED (#11b) to assert
  `neutral ∈ [a,b]` for every control (not just archetype-present keys, closing the sparse-map gap m10-2),
  so the absent→neutral read never manufactures a beyond-floor `cur` and never silently ratchets the floor
  (§3.1, §3.2, §8 #11). `apply_capped` reads absent as neutral and this invariant makes that safe.
- **"Adds nothing to the hot path" qualified (round-10 m10-1):** stated to hold BECAUSE the write-back uses
  `set_value_no_signal` (no `value_changed` re-entry → no extra `_apply_state` bake) — a consequence of the
  protocol's step 4, not free (§0, §3, §5.0).
- **Navel rows tier placement (round-10 m10-3):** `region_sliders.gd:59`/`:60` (navel in/out, down/up) are
  fine detail → T3, out of the T2 curated belly group; §2's step list now states it (§2, §1.2 T3).

**Resolved earlier (round-9 attack — INTEGRATION-BOUNDARY fixes; core formula untouched & verified sound):**
- **Archetype vs user-save load paths (round-9 B9-1):** SPLIT. First-party archetypes are build-gated
  (gate #11) WITHIN every control's default interval, so an archetype pick at extremeness 0 never lands
  beyond the default cap and never ratchets a slider open — no-monster-by-DEFAULT holds for the pick-and-go
  majority. User saves/imports preserve RAW (legitimately beyond cap if made with extremeness raised). The
  guarantee's scope is now explicit: covers the default new character + archetype picks, NOT a deliberately
  extreme user creation reloaded (§1.1, §3.2 path 7/7a, §3.3, §6, §10).
- **Slider min/max desync on inward edits (round-9 M9-1; SUPERSEDED by round-11 MA-2):** M9-1 recomputed
  `min_value`/`max_value` from `[min(a,cur), max(b,cur)]` on EVERY edit (not the v9 two triggers), fixing the
  inward-drag stale-ceiling desync — but the every-edit recompute trapped a drag on a transient dip
  (round-11 MA-2). v12 makes the recompute DRAG-AWARE (held at the drag-start interval during a drag,
  recomputed at settle), which keeps the M9-1 desync fix AND removes the trap (§3.2).
- **`_set_modifier` erase reconciliation (round-9 M9-2):** `apply_capped` reads `cur` as stored-or-neutral
  and WRAPS the existing erase-at-`|v|<1e-6` write; a near-neutral value is inside every default interval so
  the erase loses no ratchet, and round-trip determinism (gate #4) holds (§3.1, §3.2).
- **Default-interval authoring cost (round-9 M9-3):** stated honestly — net-new authoring of ~56+ interval
  SHAPES in non-uniform units; the §8 #1b validating sweep MEASURES objectively but its acceptance boundary
  is USER-taste-gated, so default-interval sign-off is a user call (§3.1, §8 #1b, §10.1).
- **Minors (round-9):** `set_value_no_signal` path → `scripts/ui/options_menu.gd:46` (m9-1); belly keeps
  the existing `:58` tone axis (no duplicate), retires only `:57` pregnant, adds waist-circ/torso-depth/
  Weight/apple (m9-2); randomize-never-extreme-at-e0 is airtight given gate #11 (m9-3); asymmetric ratcheted
  slider gets a cap-extent marker (m9-4).

**Resolved earlier (round-8 attack — no longer open):**
- **Cap formula neutral-agnostic (round-8 B8-1):** the two v8 formulas (both assuming neutral 0) are
  DELETED and replaced by ONE clamp over a per-control allowed INTERVAL `[a,b]` in absolute units —
  `hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)` — correct for the six headline axes (masculinity
  50, weight 100, proportions 0.5, height 166.6, age window) with no axis-type tag (§3.1/§3.2).
- **Per-pole independent ratchet (round-8 B8-3):** the single symmetric magnitude ceiling is gone; `lo`
  and `hi` move from `cur` on opposite sides ONLY, so a magnitude ratcheted on one pole cannot re-admit
  the opposite pole beyond cap, and no free sign-flip across neutral exists (§3.2).
- **Restore/load no longer re-clamps (round-8 B8-2):** undo/redo/reset/jump/import write RAW and update
  widgets via `set_value_no_signal`, bypassing the capped `value_changed` callback, so beyond-cap values
  persist through the real UI restore flow (§3.2 paths 6–7, gate #4). LIVE-vs-RAW split enumerated.
- **Slider bounds track the live cap (round-8 m8-1):** `min_value`/`max_value` = the live interval
  `[lo,hi]`, re-applied on extremeness change and beyond-cap load, so the thumb can't pass the cap (§3.2).
- **Belly pregnancy-slider retirement made explicit (round-8 m8-2):** §2 now flags removing the live
  `stomach-pregnant` "belly" slider (`region_sliders.gd:57`) as the concrete first step.
- **Gate #1a re-stated against the interval invariant (round-8 m8-3)** and the **picker path corrected**
  to `scripts/util/cpu_accel_picker.gd` (round-8 m8-4).

**Resolved earlier (round-7 attack — no longer open):**
- **Bidirectional cap (round-7 B7-1):** the cap is now per axis type — a MAGNITUDE for bidirectional
  axes, two-sided-clamped to `[-max(|cur|,c), +max(|cur|,c)]`, so BOTH poles of the ~46 `|decr|incr|`
  axes (incl. breast volume) are bounded at extremeness 0. v7's single-`min` formula is kept only for
  unidirectional axes (§3.2).
- **Capped-write choke covers ALL write paths (round-7 B7-2):** the headline-axis `set(field)` path
  (`character_creator.gd:1047,1323`) is now routed through the same `apply_capped` choke; one clamp
  site, write paths enumerated (sculpt, region slider, headline field, numeric entry, randomize;
  archetype/history load excepted by design). v7's "two write sites" was incomplete.
- **First-build gate #1 no longer depends on a deferred item (round-7 B7-3):** the no-self-intersection
  clause is REMOVED from first-build gate #1 (which now asserts cap-enforcement + per-control AABB
  plausibility + a USER-judged combined-extreme render); self-intersection is deferred monitoring.
- **Citation + cost honesty (round-7 m7-1/m7-2):** breast volume counts corrected to down=244/up=369;
  the dihedral metric, the N=10,000 sweep, and the caps asset flagged as NET-NEW first-build work.

**Resolved earlier (round-6 attack — still closed):**
- **Cap state model (round-6 B1):** the mechanism is named at its real site — raw `modifiers` + one
  global `extremeness` + a derived `cap(·)` fn + the single `apply_capped` choke (NOT inside
  `decompose_drag`'s build-frozen `rangef`). The inward ratchet EMERGES from the clamp + raw storage;
  no per-control ratchet state exists. (v8 generalized the clamp per axis type — round-7 B7-1.)
- **Extremeness scope (round-6 B3):** DECIDED GLOBAL. One creator-settings scalar; nothing per-control to
  store or round-trip; B3's per-control round-trip contradiction is dissolved.
- **Save/load/randomize beyond-cap (round-6 M1):** save = raw values + global extremeness; **load NEVER
  re-clamps** (beyond-cap persists, consistent with the inward ratchet); randomize samples within
  `cap(·, current extremeness)`. No "snap-vs-preserve under a per-control authored-flag" dilemma — there
  is no authored-flag.
- **Ratchet vs retune (round-6 M2):** caps are DERIVED, so a retune changes the function, not stored
  values — no value-snap migration, no contradiction.
- **"Controls mean what they say" (round-6 M3):** OWNED. Default mode is honestly
  bounded-by-default-with-a-visible-GLOBAL-unlock; the numeric field clamps to the cap (visible, gated).
  Per-control caps are sibling-INDEPENDENT (only the global extremeness changes them) — explicitly unlike
  the rejected mechanism A.
- **Belly combination (round-6 M4):** folded into the DEFERRED combination-plausibility concern; the
  per-control caps do NOT bound the belly-group sum (owned), and the first build accepts that.
- **Quest faceting (round-6 M5):** stated as an ACCEPTED platform limit (extreme allowed, not guaranteed
  smooth on Quest); gate #9 explicitly does not cover it.
- **Self-intersection guarantee (round-6 M6):** v7 makes NO combination no-monsters guarantee, so the
  "reduce N" concern guts nothing; self-clip is monitoring-only.

**Resolved earlier (still closed):** the v5 composed-field clamp family (DELETED); faceting separated
from bounds (round-5 M-B); mirror resolution vs toggle (round-5 B-A); gaze left alone (round-5 M-C);
tongue cost = asset re-bake (m-A); sculpt pick scope = morphed rest-pose (m-B); glow ε scale assumption
(m-C); BVH wording (m-D); proxy morph-follow (VERIFIED FIXED, facts-r1 #1); default hair cap + camera
face-front (`9c737c6`); persistence read side (EXISTS, facts-r1 #4); breast-size via the live volume
axis (cup readout dropped); the sculpt-on-morphed-body B2 fix; `present`-flag location + dead-control
file identity; during-drag tangent pass moved to commit; sculpt grab-vs-toggle (kept, made visible); the
eye plan pivot to a procedural iris approximation.

**Genuinely open (carry forward):**
- **R6 — the subdivision-setting implementation + cost** (bake-time geometry vs runtime quality tier),
  and the **conservative default-cap constants** until the §8 #1 per-control plausibility sweep runs.
- **R7 — combination-plausibility model** (DEFERRED, low prio; seam reserved, §3.4).
- **R8 / R9 / §3.6 — self-intersection at extreme/combo settings** (monitoring, not guaranteed) and
  **Quest extreme-faceting** (accepted limit).
- **R3 — the procedural-iris look** (USER-gated taste verdict) and the OPTIONAL cornea-parallax net-new
  work if ever wanted.
- **R2 — the Tier-B baker sub-decision** (`bpy` vs in-Godot GPU bake).
- **R13 — Quest tier costs** (skin tier + subdivision tier + extreme-faceting), unvalidatable until an
  XR/Mobile build exists.

---

## 10. Execution scope — FIRST BUILD vs DEFERRED (the user is prioritizing)

The split below is explicit and justified. The guiding cut: ship the **editing model + the finalized
bounds behavior + correct semantics + the read-side persistence wiring + the objective quality gates +
the honest-fidelity Tier-A work**, and DEFER everything whose value is conditional, whose cost is a
sub-decision, or whose verification can't run yet.

### 10.1 FIRST BUILD

- **The editing model:** archetype + progressive-refine tiers (T0–T3), the visible sculpt control
  (toggle + indicator, pick latency only in sculpt mode), mirror (resolution-always + contralateral
  toggle), mandatory numeric entry, reset, bounded seeded randomize. *(Core product; lowest infra risk;
  archetype = data.)*
- **Bounds — the finalized cap model (§3):** raw `modifiers` + ONE global `extremeness` + derived
  `cap(·) -> (a,b)` a **per-control allowed interval** (neutral-agnostic, §3.1/§3.2) + the **single
  `apply_capped` choke (ONE clamp `clamp(req, min(a,cur), max(b,cur))`) covering ALL LIVE write paths**
  (sculpt — incl. uncurated modifiers via the DEFAULT CAP RULE, round-11 MA-1 — region slider,
  headline-field set, numeric entry, randomize) + the **`set_value_no_signal` RAW path at every
  restore/load** (undo/redo/reset/jump/import — bypasses the capped callback so beyond-cap persists); the
  emergent per-pole inward ratchet; **the complete 4-step LIVE-EDIT WRITE-BACK PROTOCOL (round-10 B10-1/M10-2)
  on every live path — `apply_capped` → write model → compute `[lo,hi]` (DRAG-AWARE, round-11 MA-2: held at
  `[min(a,cur_start),max(b,cur_start)]` during a drag, recomputed from `new` on drag-end/commit) → set bounds
  FIRST then `set_value_no_signal(new)` then display `new`** (in the order that prevents `value_changed`
  re-entry); `apply_capped` reading `cur` as stored-or-neutral and WRAPPING the existing `_set_modifier`
  erase-at-neutral write (round-9 M9-2), sound under the **`neutral ∈ [a,b]` invariant (round-10 M10-1)**;
  the **versioned cap table — a NET-NEW asset (`assets/body/caps*`, does not exist yet, m7-1)** whose every
  AUTHORED interval must contain its control's neutral (derived intervals satisfy it by construction);
  conservative DEFAULT intervals (**net-new authoring of ~56 + headline interval shapes in non-uniform units
  — real first-build work, round-9 M9-3; the ~224 uncurated sculpt-reachable modifiers are DERIVED by rule,
  no per-modifier labor, round-11 MA-1**). *(The state model is concrete and adds nothing to the bake hot
  path — a consequence of the write-back's `set_value_no_signal` (no re-entrant bake), round-10 m10-1; it is
  the no-monster-by-default behavior.)*
- **Two distinct load paths (round-9 B9-1):** first-party ARCHETYPE picks (within-default-interval,
  enforced by build gate #11a) keep no-monster-by-DEFAULT for the pick-and-go majority; user saves/imports
  preserve RAW (may be beyond cap, by design). The **build gate #11 is net-new first-build work**: #11a a
  numeric containment assert over `assets/body/archetypes/*.json` vs the caps asset, PLUS #11b the
  `neutral ∈ [a,b]` assert for EVERY control (round-10 M10-1/m10-2).
- **Belly / breast / region controls surfaced with correct semantics + labels (§2, §4):** the belly
  group over existing morphs (no asset), breast size via the live volume axis, the region sliders. *(UI +
  labeling over already-imported morphs; zero bake.)*
- **Persistence wiring — slice 1 (read side EXISTS, §6):** Import button + FileDialog + drag-drop calling
  the existing parse functions; autosave/restore; the global extremeness in the save. *(Only wiring left.)*
- **Camera (DONE, `9c737c6`):** face-front default + centered pivot + studio rig + Quest-preview toggle.
- **The objective quality gates (§8 (a)):** the rewritten no-monster check (#1: cap-enforcement across
  ALL write paths — incl. the round-11 MA-1 uncurated-sculpt-modifier-clamps-to-derived-interval assert and
  the ONE PATH-AGNOSTIC transient-dip assert proving the choke-capture invariant across every reach-the-choke
  path: slider (round-11 MA-2), sculpt + sculpt-only (round-12 MA12-1), multi-modifier (round-12 MA12-1), and
  the pre-ratcheted MIRROR TWIN (round-13 MA13-1), PLUS the round-14 MA14-1 mid-gesture-state-replacing-op
  abort assert (gate #1a iv/iv-a..iv-d/v/vi) — per-control default-cap
  AABB plausibility + a USER-judged combined-extreme render — NO automated self-intersection clause, B7-3),
  proxy-follow (#2), monotone breast
  sweep + dead-control assert (#3), persistence round-trip (#4), within-platform determinism (#5),
  committed-tangent validity (#7a), dihedral faceting metric (#8a), sculpt+mirror+morphed-surface (#10),
  **archetype within-default-interval build assert (#11, round-9 B9-1)**.
  **NET-NEW harnesses/assets among these (m7-1), not near-existing: the dihedral metric (#8a), the
  N=10,000 sweep (#1b), the caps asset that #5/#1/#11 run against (`assets/body/caps*`), and the #11
  archetype-containment assert.**
  (#2 has a passing test, #4 has the existing read-side — those ARE near-existing; the cut does not
  pretend the net-new ones are.)
- **Default-cap conservative tuning (§3.4, §8 #1):** set + validate each per-control default cap reads as
  human-plus-stylized alone.
- **Glow / tongue / sculpt-on-morphed-mesh fixes (§5.5, §1.3):** glow outward offset (world-space ε +
  uniform-scale assert), sculpt picks/locality/glow refresh from the morphed surface (owner-driven). *(The
  tongue **fix** is first-build; note its cost is an asset re-bake, R14.)*
- **Skin Tier-A (§5.1):** detail-normal (pores) + roughness + albedo break-up + low SSS, **+ the §5.0
  tangent-on-commit prerequisite** (hard dependency for any skin normal map). *(The bulk of the perceived
  fix; engine-native.)*
- **Procedural iris look (§5.2):** improve the procedural `eye.gdshader` (striations/limbal/pupil/spec) +
  expose `iris_color`. **NO `gaze_dir` wiring** (would double-count). *(User-taste-gated, but the work is
  shader-tuning of existing procedural code.)*
- **Brows/lashes alpha cards (§5.3)** and the **scoped render/UX cleanups (§5.6)** — small, unblock the
  fidelity floor.

**First-build → deferred dependency re-scan (round-10, CONFIRMED NONE).** Each first-build item was
re-checked against the deferred list (§10.2): the editing model, the cap model (its only new asset
`assets/body/caps*` is itself first-build, not deferred), belly/breast/region surfacing (existing
morphs), persistence slice 1 (read side exists; slice 2 caps-version is sequenced after the cap table but
slice 1 does not depend on it), camera (done), the objective gates, default-cap tuning, glow/tongue/
sculpt fixes, skin Tier-A (depends only on the §5.0 tangent rebake, which is itself first-build — NOT on
Tier-B), procedural iris, brows/lashes. Specifically: gate #1 no longer asserts self-intersection (B7-3,
deferred §10.2) and asserts only the interval invariant + per-control AABB + a user-judged render; gate
#8 SHIPS the dihedral faceting metric and FLAGS faceting without depending on the deferred subdivision
remedy; Tier-A does not depend on the deferred Tier-B baker. The archetype within-interval **build gate
#11** (round-9 B9-1) depends only on the caps asset (first-build) and the first-party archetype roster — its
acceptance criterion is the SAME default intervals gate #1b tunes (no new deferred input). **NEW in v11:**
the complete live-edit write-back protocol (round-10 B10-1/M10-2), the `neutral ∈ [a,b]` invariant + gate
#11b (round-10 M10-1/m10-2), the hot-path cost qualification (m10-1), and the navel-row T3 placement
(m10-3) are ALL refinements of already-first-build items. **NEW in v12 (round-11):** the DEFAULT CAP RULE
(MA-1 — authored-or-derived intervals, so the choke + caps asset already in first-build now cover the
uncurated sculpt-reachable modifiers via a single derivation rule, no new asset), the drag-aware
bounds-recompute (MA-2 — a refinement of the slider-bounds write-back, one new `_drag_start_value` dict),
and the belly reference fix (MI-1 — a §2 UI-surfacing correction over existing morphs). All are refinements
of already-first-build items (the choke, the caps asset, the slider-bounds write-back, the §2 belly
surfacing) — they add NO new asset, NO new harness beyond a sculpt-uncurated-modifier assert and a
transient-dip drag assert folded into gate #1a, and NO dependency on any deferred item. **NEW in v13
(round-12):** the GENERALIZED HELD-INTERVAL mechanism (MA12-1 — the held-interval phase signal is the
ACTIVE EDIT GESTURE, covering BOTH the slider drag AND the sculpt gesture bracket
`_dragging_morph`/`_apply_morph_drag`; closes the v12 sculpt-path transient-dip hole) and the
extremeness-defer reconciliation (MI12-1 — extremeness-change recompute is DEFERRED to gesture-end so it
never overrides a held interval). **NEW in v14 (round-13):** the CHOKE-CAPTURE INVARIANT (MA13-1 — the
held-interval capture is now a property of the `apply_capped` choke itself, captured LAZILY on each control's
FIRST touch within the gesture, so it covers EVERY write path through the choke — directly-touched,
sculpt-decomposed, the §1.3 MIRROR TWIN, numeric, randomize, headline, and any future cascaded write — with
NO per-path enumeration; closes the round-13 mirror-twin transient-dip hole and the whole enumeration defect
class) and the full all-controls gesture-end sweep (MI13-1). Both are refinements of already-first-build
items (the same `_drag_start_value` dict + the choke + the slider-bounds write-back — v14 MOVES the capture
from per-path write sites INTO the existing choke, a fewer-site mechanism, no new asset); the only new harness
is the round-13 mirror-twin transient-dip assert folded into gate #1a (iv-d) atop the now-path-agnostic (iv).
NO new asset, NO dependency on any deferred item. **NEW in v15 (round-14):** the GESTURE-LIFECYCLE-
INTERRUPTION INVARIANT (MA14-1 — any state-replacing op mid-gesture — raw restore/undo/redo/reset/jump,
archetype/import load, OR an extremeness change — ABORTS the active gesture and clears `_drag_start_value`
before applying, so no zombie gesture survives and a fresh first-touch capture against the new state begins
only on the next press; closes the round-14 mid-gesture-restore hole and SUBSUMES the v12/v13 MI12-1 deferred-extremeness special case into one
abort rule) and the SHARED-WIDGET CONSERVATIVE-DISPLAY rule (MI14-1 — a bilateral slider displays
`[max(lo_L,lo_R), min(hi_L,hi_R)]` so its single thumb can't exceed either diverged side's true cap). Both
are refinements of already-first-build items: MA14-1 adds an abort branch on the EXISTING restore/load/
extremeness paths reusing the EXISTING gesture brackets + `_drag_start_value` map (a simpler mechanism than
the MI12-1 deferral it RETIRES — fewer branches, no new state, no new asset); MI14-1 is a one-line change to
the step-4 bounds write on bilateral widgets. The only new harness is the round-14 mid-gesture-restore abort
assert folded into gate #1a (vi). NO new asset, NO dependency on any deferred item. **No first-build item
depends on a deferred one.**

### 10.2 DEFERRED (named, with why)

- **Combination-plausibility model (§3.4, R7)** — *user decision: low priority to build.* Seam reserved
  (post-composition toggleable validity check); interim grotesque combinations accepted. The per-control
  caps do NOT bound combinations, and the first build owns that.
- **Skin Tier-B baked meso normal/AO (§5.1, R2)** — *blocked on a baker sub-decision* (`bpy` vs in-Godot
  GPU bake); Tier A ships the bulk of the fix without it.
- **Subdivision setting implementation (§3.6, R6/R9)** — *DEFERRED past the first build:* the cost form
  (bake-time geometry vs runtime quality tier) is a genuine sub-decision, and the independent dihedral
  metric (#8) can SHIP and FLAG faceting before the remedy exists. Extreme is reachable in the first build
  but may facet (and on Quest will, accepted limit) until subdivision lands. *(Decision: gate-and-flag in
  first build; remedy deferred.)*
- **Cornea parallax / refraction (§5.2, R3)** — *net-new shader infra (view vector + iris-under-cornea
  offset);* the core procedural iris delivers the look without it.
- **Per-eye gaze convergence / any `gaze_dir` work (§5.2)** — *DEFERRED and currently UNNEEDED:* eyes
  already track via the `eye.L`/`eye.R` bones; wiring `gaze_dir` would double-count. Only reconsidered if
  a future need for shader-space convergence arises.
- **VR / OpenXR workstream (§7, R13)** — *separate large prerequisite, 0% built;* the editing model is
  designed to degrade gracefully and project the handle table to future grab-volumes, but no XR code ships
  here. Quest render + subdivision tiers (and the extreme-faceting limit) are hypotheses until an XR build
  exists.
- **Self-intersection CHECK (any form — §3.6, R8)** — *DEFERRED, monitoring-only* (the BVH/spatial-hash
  self-clip is NET-NEW feature work, no code today — round-7 B7-3; built later as a nightly report).
  Enforcement/attenuation is NOT a first-build gate, AND no first-build gate asserts it: gate #1's old
  no-self-intersection clause was REMOVED (B7-3) precisely so no first-build item depends on this
  deferred one. At extremes and allowed grotesque combinations self-intersection is a KNOWN flagged limit.
- **Caps-version revalidation slice (§6 slice 2)** — recording the caps version for replay determinism is
  first-build-light; any retune handling is trivial because caps are derived (no value-snap migration), so
  there is little to defer — but it is sequenced AFTER the §3 cap table exists.
- **Opt-in hairstyle drape (§5.6, R15)** — *standalone hair-geometry seating slice;* the default-cap hide
  is already fixed.

**Justification for the cut:** the first build delivers a complete, playable, no-monster-by-DEFAULT
creator with correct semantics, honest fidelity (Tier A), and runnable objective gates — where
"no-monster-by-DEFAULT" is precise (round-9 B9-1): the default new character AND every first-party
archetype pick are bounded (the latter by build gate #11), while a user's own deliberately-extreme creation
reloads raw (by design). It defers
(a) everything gated on an unmade decision (Tier-B baker, subdivision cost form), (b) everything gated on
an unbuilt platform (VR/Quest verification), and (c) the combination-plausibility model the user
explicitly down-prioritized. The deferred items are each named with their hook/seam so none is silently
dropped.
