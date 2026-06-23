# Attack — round 11 (hostile review of SYNTHESIS.md v11)

Hostile reviewer pass. Only findings that hold up against the actual code/assets @ HEAD are
recorded. Acknowledged open/deferred items with sound plans/seams are NOT ranked as flaws (per the
review contract); they are noted only where a first-build item depends on them or the seam is unsound
— none such were found. The core single-value cap formula (`hi=max(b,cur); lo=min(a,cur);
new=clamp(req,lo,hi)`) was re-derived by hand and survives every pressure case I threw at it (B8-1
window, B8-3 sign-flip, inward-ratchet persistence) — verified sound, NOT attacked further.

Three findings hold up. Two are MAJOR; one is MINOR.

---

## MAJOR

### MA-1 — The capped-write choke has NO defined cap for the ~280 sculpt-reachable non-curated modifiers; the "ALL live write paths capped" + "~56 controls" authoring cost are mutually inconsistent.

**Locus:** §3.1 (authoring cost "~56 curated controls plus the 6 headline axes"), §3.2 path 1
(sculpt), §8 gate #1a ("ALL LIVE write paths"), §8 gate #11b ("for EVERY control"); vs
`scripts/body/morph_drag.gd:133-156` (`build_accel`).

`build_accel` iterates the **entire** registry — `var entries: Array = registry.get("modifiers", [])`
(`morph_drag.gd:138`), sorted, one candidate per detail modifier — so a sculpt drag (`decompose_drag`)
can write ANY of the registry's ~280 detail modifiers into `BodyState.modifiers`
(`character_creator.gd:465-471`), not only the ~56 curated `region_sliders.gd` controls.

The design states two things that cannot both be true:
- The choke `apply_capped(control, req)` covers **ALL** live write paths including sculpt (§3.2 path 1,
  gate #1a "(sculpt apply, region slider, …)"), reading the live interval `cap(control, extremeness)`.
- The cap table authors a default interval `[a,b]` for "**~56 curated controls plus the 6 headline
  axes**" (§3.1 honest-authoring-cost paragraph; R6).

For a sculpt-produced **non-curated** modifier (one of the ~224 outside the curated 56), `cap(control,
0)` is **undefined** — no interval was authored. So either:
- (a) non-curated modifiers fall through to the hard registry range ⇒ sculpt is effectively **uncapped**
  at extremeness 0, and "no-monster-by-DEFAULT" is FALSE on the sculpt path (a T3 first-build feature,
  §10.1); or
- (b) the cap table must author + neutral-check (`gate #11b` "for EVERY control") all ~280 modifiers ⇒
  the "~56 controls" authoring-cost figure (R6/§3.1/M9-3) is understated by ~5×, and gate #11b's "for
  EVERY control" is the honest reading but contradicts the §3.1 enumeration.

The design never resolves which. This is a genuine coverage hole in the load-bearing choke + an internal
contradiction between the choke's coverage claim and its stated authoring scope. Note gate #11b
("`a ≤ neutral ≤ b` for EVERY control") only deepens it: if "every control" = every reachable modifier,
the build gate must iterate ~280 intervals that §3.1 says are not authored.

Concrete method to confirm/dissolve: `morph_drag.gd:133-156` proves sculpt reaches all detail
modifiers; the design must either (i) state that the cap table covers ALL registry detail modifiers
(and correct the cost figure + gate #11b scope), or (ii) state a default interval for un-authored
modifiers (e.g. a symmetric `[-a0,+a0]` default-by-kind), and route sculpt through it. As written, the
"capped at every live path" property is unmet for the sculpt path.

### MA-2 — v11's "recompute slider min/max on EVERY edit" (M9-1) irrecoverably collapses a ratcheted slider's reach from a *transient mid-drag dip*, because `value_changed` fires continuously during a drag.

**Locus:** §3.2 protocol steps 3–4 + the M9-1 every-edit-recompute paragraph (§3.2,
"recomputes the slider's `min/max` on EVERY edit"); vs `character_creator.gd:1041-1046,1175`
(`value_changed` fires continuously during a drag).

The live region/headline callbacks fire `value_changed` **every mouse-motion frame during a drag**
(confirmed by the design's own comment, `character_creator.gd:1041-1045`: "value_changed fires
continuously during a drag"; the headline callback `:1046` and region callback `:1175` both run on each
fire). v11 mandates that EVERY such live edit runs protocol step 3/4: recompute
`[lo,hi]=[min(a,new),max(b,new)]` from the just-written `new` and set `w.max_value=hi` /
`w.min_value=lo`.

Failure case (the exact M9-1 ratchet, run mid-drag):
- Load a user save with `cur = +0.9` on a bidirectional axis whose default is `[-0.5,+0.5]`. Slider
  bounds widen to `[-0.5, +0.9]` (ratchet preserved). Good.
- The user grabs the thumb and, **within one continuous drag gesture**, dips it to `0.6` then intends
  to return to `0.85`.
- At the `0.6` sample: step 1 `new=clamp(0.6, -0.5, 0.9)=0.6`; step 2 writes `0.6` to the model (the
  model no longer holds `0.9`); step 3 `[lo,hi]=[min(-0.5,0.6),max(0.5,0.6)]=[-0.5,0.6]`; step 4 sets
  `max_value=0.6`.
- The mouse is still pressed and moving right, but the thumb is now physically clamped at `max_value=0.6`.
  The user **cannot** drag back to `0.85`/`0.9` within this gesture. The ratchet to `0.9` is permanently
  destroyed by a transient dip the user never intended to commit.

The design's "reducing inward collapses the ratchet, once inside it is bounded by `[a,b]` going forward"
is a deliberate property for *committed* inward edits — but applying it **per-frame during a continuous
drag** means any momentary dip below `b` collapses the ratchet irrecoverably mid-gesture, and the thumb
becomes "sticky" (you can never drag a value back UP past the lowest point you transiently passed
through within one drag). v9's two-trigger rule (recompute only on extremeness-change / load) did NOT
have this defect; M9-1's every-edit recompute introduced it, and v11 carries it forward (the v11
write-back protocol changes only the ORDER and the no-signal write — it does not move the recompute off
the per-frame live path). The design's debounce (`_drag_pending`, `:1049,1179`) gates only the history
COMMIT, not the bounds recompute, so it does not save this.

Concrete method to confirm: the live callbacks at `character_creator.gd:1046`/`:1175` run on every
`value_changed`; under v11 each runs step 3/4; Godot `HSlider` clamps the thumb to the live `max_value`.
A drag that passes through a value below the ratcheted `b` therefore traps the remainder of the gesture.
The honest fix (recompute bounds only on drag-END / settle, not on every live `value_changed`) is not
specified and would itself need reconciling with the desync M9-1 claimed to fix.

---

## MINOR

### MI-1 — The §2 belly recipe re-surfaces `measure/measure-waist-circ-decr|incr` under a new "Belly fullness" group, but that modifier is ALREADY a shipping slider ("waist", `region_sliders.gd:63`) — the same two-thumb-one-modifier duplicate the v10 anti-duplicate rule (m9-2) was meant to forbid, applied only to `stomach-tone` and missed here.

**Locus:** §2 "Belly fullness / forward → `torso/torso-scale-depth…` + `measure/measure-waist-circ…`
as one combined fullness control"; vs `region_sliders.gd:63`
(`["measure/measure-waist-circ-decr|incr", "waist", "narrow", "wide"]`).

`measure/measure-waist-circ-decr|incr` already ships as the "waist" slider under "Waist & hips"
(`region_sliders.gd:63`). The §2 belly recipe lists it as part of a net-new T2 "Belly fullness / forward"
control. If followed literally, two distinct sliders (two entries in `_modifier_sliders`, keyed by
spec_name) drive the **same** `modifiers["measure/measure-waist-circ-…"]`. The live region callback
writes `_set_modifier(full_names, v)` (`character_creator.gd:1176,1209-1214`) to the shared map but only
updates its OWN label (`_update_modifier_value_label(spec_name)`, `:1178,1218-1221`); the sibling slider's
thumb/label do NOT update until a history restore (`_restore_modifier_sliders`, `:1232-1238`). So the two
sliders **desync** during live editing — exactly the duplicate-control class v10 explicitly forbade
("a v9-style replace … would DUPLICATE the existing `:58` tone row — v10 forbids that", §2). The rule was
applied to `stomach-tone` (`:58`) but the same hazard for `waist-circ` (`:63`) is unguarded.

(`torso-scale-depth` is genuinely net-new — `grep` confirms it is NOT in `region_sliders.gd` today — so
adding it is fine; the defect is only the `waist-circ` half.) Ranked MINOR because it is a content/UI
authoring slip the build gate would not catch and is trivially fixed by referencing the existing `:63`
slider rather than re-adding it — but it is the design's own named anti-pattern, surfaced a second time.

---

## Load-bearing areas attacked and NOT broken (re-verified against code/assets @ HEAD)

- **Core cap formula `hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)`** — re-derived by hand for the
  B8-1 window (`masculinity [20,80]`, `req=100→80`, `req=0→20`), B8-3 sign-flip (`cur=0.9,b=0.5`,
  `req=-0.9→+0.5`, no opposite-pole re-admit), and beyond-cap persistence (`hi=cur` holds). Sound; per-pole
  independence holds; neutral-agnostic across all six headline axes. Not broken.
- **B8-2 restore re-fires the capped callback today** — verified: `_restore_current` sets
  `slider.value = v` (`character_creator.gd:1324`) and `_restore_modifier_sliders` sets `.value = v`
  (`:1237`), both EMIT `value_changed` → `:1046`/`:1175` callbacks; `_suspend_commit` gates only the commit
  (`:1320,1049,1179`), NOT the callback. So the `set_value_no_signal` raw-restore fix is genuinely
  required and correctly motivated. The Godot clamp-and-emit hazard the v11 step-4 order guards against is
  confirmed real by the repo's own `options_menu.gd:27-34` comment ("assigning a min_value above the
  current value silently clamps the value and emits value_changed"). The B10-1 feedback-loop concern and
  its fix are real and sound.
- **`set_value_no_signal` precedent** — present at `scripts/ui/options_menu.gd:46`; absent from the creator
  (`grep` empty) → correctly flagged as net-new. Accurate.
- **Erase-at-neutral reconciliation (M9-2) + neutral∈[a,b] invariant (M10-1)** — `_set_modifier` erases
  `|v|<1e-6` (`character_creator.gd:1209-1214`); the absent→neutral read
  (`modifiers.get(fn,0.0)`, `:1172,1236`) reproduces the same `cur` iff neutral∈[a,b]. The invariant is the
  correct closure; gate #11b's per-control assert closes the sparse-map gap. Sound (for the *curated*
  controls — its scope-vs-cost tension with sculpt-reachable modifiers is MA-1, not this).
- **B2 sculpt-on-morphed-surface fix** — `_glow_base_pos` is the one frozen-neutral basis feeding the
  picker, `decompose_drag` `positions` (`:461`), and the glow (`:434`); the owner-driven dirty-rebuild
  with the picker having no mesh handle (`cpu_accel_picker.gd:71,162-163`) is the correct mechanism.
  Scope honestly limited to morphed rest-pose. Not broken.
- **Breast-size decision (b) + counts** — `breast/breast-volume-vert-down|up` down=244/up=369 verified at
  `base_body_detail.index.json:159-160`; `BreastSize` dead-macro claim consistent. Monotone sweep gate #3
  is valid. Not broken.
- **Belly axes exist / waist-circ=879 / navel sparse(19)** — verified at
  `base_body_detail.index.json:404-405,516-519,522-523`; `region_sliders.gd:57-60` line citations exact.
  The navel→T3 placement and pregnancy-retirement plan are sound (the only belly slip is MI-1).
- **New-defects coverage** — all three of `new-defects.md` (tongue off, glow-at-neutral, glow-clips) are
  picked up in §5.5/§5.6/R14 with named methods + honest asset-re-bake cost. None silently dropped.
- **Net-new honesty** — `assets/body/archetypes/` and `assets/body/caps*` confirmed ABSENT; no numeric
  LineEdit in the creator today. The design flags each as net-new accurately; no first-build item was
  found depending on a deferred one (the §10.1 re-scan holds for the items I checked).
- **Deferred items with sound seams** — combination-plausibility (§3.4), Tier-B baker (R2), subdivision
  cost (R6/R9), self-intersection monitoring (R8/§3.6), Quest faceting limit (R9), cornea parallax (R3),
  procedural-iris taste verdict (R3): each is an honestly-flagged open/deferred item with a stated
  seam/plan; none leaves a first-build item broken. Not attacked (per contract).
