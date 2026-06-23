# Attack — round 10 (hostile review of SYNTHESIS.md v10)

Hostile review. Sole job: break the design. I did NOT trust the doc's own
"verified/fixed/resolved/sound" claims; load-bearing ones were re-checked against
code/assets @ HEAD. Acknowledged-open/deferred items with sound seams are NOT ranked
BLOCKER/MAJOR — I attack them only where a deferral leaves a first-build item broken or
the seam is unsound. Findings are ranked; each factual claim is grounded with a citation,
suspicions are labelled.

The v10 change-set was the priority target (B9-1 gate #11, M9-1 per-edit slider rebind,
M9-2 apply_capped-wraps-erase, the belly `:57`/`:58` decision). Two of the v10 changes
introduce NEW defects that the prior nine rounds could not have caught because the
mechanisms are new.

---

## BLOCKER

### B10-1 — M9-1's "recompute slider `min/max` on EVERY edit" creates a re-entrant `value_changed` feedback during the SAME callback, and the design never specifies how the outward-clamped value gets back to the thumb.

This is a NEW defect introduced by the v10 M9-1 fix; round 9's M9-1 was about *trigger
completeness* and could not have surfaced it.

The live region-slider write is a `value_changed` closure
(`character_creator.gd:1175-1180`): `_set_modifier(full_names, v); _apply_state(); …`.
The headline path is the analogous `value_changed` closure (`:1046-1051`:
`_body_state.set(field, v); _apply_state(); …`). v10 inserts two things into this
callback: (1) `stored = apply_capped(M, req)`, and (2) per M9-1, "re-apply [the slider's
`min/max`] immediately after each `apply_capped` write returns" from
`[min(a,cur), max(b,cur)]` (§3.2, §10.1).

Trace the **outward-clamp** case — the case the whole cap exists for. Default `b = 0.5`,
`cur = 0.3`. The user drags the thumb to `req = 0.8`. Godot sets `slider.value = 0.8`
FIRST, then fires `value_changed(0.8)`. Inside the callback:

1. `stored = apply_capped(M, 0.8) = clamp(0.8, 0.3-side lo, max(0.5,0.3)=0.5) = 0.5`. The
   model stores `0.5`. **But `slider.value` is still `0.8`** — the design never specifies a
   write-back of `stored` to the widget on a LIVE path. `set_value_no_signal` is specced
   ONLY for restore/load paths 6/7/7a (§3.2); the live paths (1–5) say only "compute `req`
   and call `apply_capped`". So either:
   - **(a) no write-back:** thumb shows `0.8`, model is `0.5` — the exact thumb/value
     desync m8-1 and M9-1 both claim to KILL, now re-introduced on every outward edit; or
   - **(b) M9-1's recompute clamps it:** `max_value := max(b, cur) = max(0.5, 0.5) = 0.5`.
     Setting `Range.max_value = 0.5` while `value = 0.8` makes Godot's `Range` **clamp
     `value` down to `0.5` and EMIT `value_changed(0.5)`** — re-entering this very closure,
     which re-runs `apply_capped`, `_apply_state` (a full 14,517-vert normal bake,
     `:1262-1267`, the flagged hot path §0 facts-r1 #5), and recomputes the bounds again.

The design asserts the thumb "cannot travel past the cap" and the gating is "VISIBLE at the
slider" (§3.2) — but the mechanism it names to achieve that (recompute `min/max` after every
write) is precisely the mechanism that, on the outward case, re-fires the callback. The
design contains no guard for callback re-entrancy (no `_suspend` flag is mentioned for the
live path; `_suspend_commit` gates only the history commit, not the callback, verified
`:1049,1179` and design's own note `:736`). At minimum this is an unspecified extra bake per
outward edit; at worst it is a feedback path the design declares impossible.

The fix is not a one-liner the doc hand-waves: it requires either (i) writing `stored` back
via `set_value_no_signal` on live paths too (currently unspecified, and would also need the
bounds set before/after in an order that doesn't clamp), or (ii) an explicit re-entrancy
guard around the whole callback. Neither is named. **The named method ("re-apply min/max
after every edit") is not a working method for the outward-clamp case** — the case it exists
to handle.

*Suspected on the exact emit-on-clamp behavior of Godot 4 `Range.set_max`; would verify by
a 5-line GDScript test (`min_value`/`max_value`/`value` + a `value_changed` counter). The
desync-vs-recursion dilemma holds regardless of which branch Godot takes, because the design
specifies no write-back of `stored` to the widget on a live path.*

---

## MAJOR

### M10-1 — M9-2's load-bearing claim "every default interval contains the control's neutral, so the erase loses no ratchet" is FALSE for a unipolar interval the design itself explicitly permits (`[min, b0]` with `min > 0`).

M9-2 reconciles `apply_capped` with `_set_modifier`'s erase-at-`|v|<1e-6`
(`character_creator.gd:1209-1214`, verified) by reading absent ⇒ neutral. Its entire
soundness rests on one asserted invariant (§3.1, §3.2):

> "a near-neutral value is within EVERY default interval `[a,b]` (every default interval
> contains the control's neutral), so erasing it and later re-reading it as neutral
> reproduces the identical `cur` … The ratchet only ever widens from a value OUTSIDE
> `[a,b]`."

But §3.1 itself authors the unipolar default interval as **"`[0, b0]` (or `[min, b0]`)"** —
explicitly allowing a unipolar floor `a = min > 0`. For ANY control given a `[min, b0]`
interval with `min > 0`, the control's neutral (registry default ≈ 0,
`modifiers.get(fn, 0.0)`, §3.1) is **below `a`**, i.e. NOT in `[a, b]`. Then on the
absent→neutral read, `cur = 0` with `a = min > 0` gives `lo = min(a, cur) = min(min, 0) =
0` — the floor silently ratchets open from `a` down to `0` even though no value beyond the
interval was ever authored. That is exactly the "ratchet widens only from a value OUTSIDE
`[a,b]`" guarantee, violated: the erase has *manufactured* a beyond-floor `cur` from
nothing, and `apply_capped` will now happily accept any `req ∈ [0, b]` forever after.

So M9-2's reconciliation is sound only under the unstated extra constraint **"no curated
unipolar control may have a default-interval floor above its neutral"** — a constraint the
default-interval authoring pass (§3.1, the 29 unipolar axes) is free to violate, and which
§3.1 does not impose; it offers `[min, b0]` as a legitimate shape. This is an internal
contradiction between the M9-2 invariant and the §3.1 interval-shape menu, on the exact seam
v10 claims to have closed. It also infects gate #11 (an archetype omitting a unipolar
modifier = neutral = below such a floor would pass containment while a live neutral edit
ratchets the floor).

Fix is real design work, not a one-liner: either forbid unipolar `min > 0` floors in the
caps asset (and assert it in gate #5/#11), or change the erase threshold / `cur`-read to use
the interval floor rather than registry neutral for clamped-floor unipolar axes. Neither is
specified.

### M10-2 — The live-edit write paths never specify how an outward-CLAMPED `stored` is reflected to the slider thumb OR the numeric field, so the §3.2/§1/§3.5 "visible at the slider, not a hidden lie" property is unachieved as written.

Independent of B10-1's recursion: §1 / §3.5 stake the honesty argument on the clamp being
*visible* — "the numeric field clamps to the current cap and that is honest" (§3.5), "the
gating is VISIBLE at the slider, not just at the numeric field" (§3.2 M9-1). For that to be
true, after `stored = apply_capped(req)` with `stored ≠ req`, the widget showing `req` must
be corrected to `stored`. The design specifies the *read* of `req` and the *write* of
`stored` into the model, and the recompute of bounds — but **no step that writes `stored`
back into the HSlider value or the numeric LineEdit on any live path (1–5).** The numeric
entry (path 4) is described as "the field commits `apply_capped(control, req)`" with no
read-back; the slider callbacks (`:1046`, `:1175`) currently echo the raw `v` into the value
label (`:1178 _update_modifier_value_label` reads `slider.value`, not the stored value —
verified `:1218-1221`). So a typed "+100" at extremeness 0 stores the cap endpoint but the
field/label can keep displaying the typed value — the "owned, visible behavior, not a hidden
lie" (§1, M3) is asserted, not delivered by any named mechanism. This is the honesty property
the design repeatedly leans on, with no executable method behind it.

(B10-1 is the failure of the bounds-recompute *mechanism*; M10-2 is the separate, broader gap
that no live path writes the clamped value back to ANY widget. Both must be fixed; fixing one
does not fix the other.)

---

## MINOR

### m10-1 — `_apply_state`'s own comment is cited as a cleanup (§5.6) but the SAME stale comment is what the design's "adds nothing to the hot path" reasoning silently relies on; the cost framing is slightly self-serving.

`character_creator.gd:1261` says the bake "Only runs on slider changes, so it's cheap" —
verified present, and §5.6 correctly flags it as wrong-for-the-drag-path. Fine. But note the
sculpt drag apply (`:460-472`) calls `_apply_state()` every motion frame AND now (B10-1) the
slider path may re-enter `_apply_state` per outward edit. The design's repeated claim "v10
adds NOTHING to the bake hot path" (§0, §3, §5.0) is true for the *core formula* but not
obviously true once M9-1's per-edit bounds recompute can trigger a clamp→`value_changed`→
`_apply_state` cycle (B10-1). The "nothing added to the hot path" framing should be qualified
by the M9-1 interaction. Minor because it is a framing/cost-honesty issue, not a broken gate.

### m10-2 — Gate #11 is specified as "every value of EVERY control," but an archetype is a SPARSE `modifiers` map; the gate can only iterate present keys, leaving absent-but-clamped-floor controls (M10-1) unchecked.

`to_dict`/`from_dict` (`body_state.gd:765,785-797`, verified) store/load only the modifiers
present in the sparse map; absent = neutral. Gate #11 (§8 #11) says it "asserts EVERY value
of EVERY control lies within that control's DEFAULT interval." For absent modifiers there is
no stored value to check, and the implicit neutral is assumed in-interval — which M10-1 shows
is false for a `[min>0, b0]` unipolar control. So gate #11 as worded would pass an archetype
that, the moment a user nudges that absent control, ratchets a floor open. The gate needs to
also assert "neutral ∈ `[a,b]` for every control" (or forbid `min>0` floors), which folds
back into M10-1. Minor on its own (it is a strengthening of an assert), load-bearing only via
M10-1.

### m10-3 — The belly `:57`/`:58` decision is correct, but §2 retires ONLY `:57` and leaves the other shipped stomach rows (`:59` navel-depth, `:60` navel-height …) unaddressed re: T-tier placement.

Verified: `region_sliders.gd:57` = `stomach-pregnant` ("belly"), `:58` = `stomach-tone`
("abs tone") — exactly as v10 states (m9-2 resolution is accurate). The navel rows
(`:59-60`, verified present) are mentioned in §2 ("Navel … exposed at T3") so this is
near-complete; the gap is only that §2's concrete "(1) DELETE `:57` … (2) KEEP `:58` …
(3) ADD the fuller set" step list does not say what happens to the already-shipping
`:59`/`:60` navel rows in the T2-vs-T3 split (they currently live in the same flat region
panel). Cosmetic/scoping, not a contradiction.

---

## Load-bearing areas attacked and could NOT break (with the evidence checked)

- **Core cap formula `hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)`** — re-derived the
  pressure cases by hand: outward-past-`b` clamps to `b`; ratcheted `cur=0.9,b=0.5` gives
  `clamp(req,0.5,0.9)` so `req=-0.9`→`0.5` (no sign-flip, B8-3 holds); masculinity `[20,80]`
  `req=100`→`80`, `req=0`→`20` (window, B8-1 holds); neutral-agnostic across all axis types.
  The *formula* is sound. (The breaks above are at its integration boundaries — the slider
  rebind B10-1, the erase invariant M10-1 — not the formula.)
- **`_set_modifier` erase exists exactly as described** — `character_creator.gd:1209-1214`,
  erases `|v|<1e-6`, verified. M9-2's *modifier-space* reconciliation is sound EXCEPT the
  unipolar-floor case (M10-1).
- **`set_value_no_signal` precedent** — `scripts/ui/options_menu.gd:46`
  (`_mouse_sens_slider.set_value_no_signal`), verified; m9-1 path correction is right; design
  correctly says it is NOT yet in the creator (`grep` clean in `scripts/body/`).
- **Restore/load re-fires capped callbacks today** — `_restore_current` sets
  `slider.value = v` (`:1324`) and `_restore_modifier_sliders` sets `(slider).value = v`
  (`:1237`), both of which emit `value_changed` → the live callbacks (`:1046,1175`). The
  B8-2 split (restore must use `set_value_no_signal`) is a real, correctly-identified need.
- **Picker has no mesh handle; rebuilds from `_positions` cache on `_dirty`** —
  `cpu_accel_picker.gd:64-65,70-72,162-163`, verified. The owner-driven rebuild (m-3) is the
  correct mechanism; pick is rest-space (`:173-177`), and the §1.3 m-B honest-scope note
  ("morphed rest-pose body, not skinned pose") correctly fences the limit. Not broken.
- **Glow overlay frozen at neutral + builds no normals** — `_rebuild_glow_mesh` uses
  `_glow_base_pos` (captured once, `:242`) and emits only VERTEX/INDEX/COLOR (`:430-438`),
  no normals; `_apply_state` marks the picker dirty but the overlay re-reads the frozen
  array. Defects 2/3 of `new-defects.md` confirmed real; §5.5's fix (thread ARRAY_NORMAL,
  refresh from morphed surface, world-space ε / `height_scale()`) is sound and addresses them.
- **Sculpt drag apply is modifier-space with its own erase** — `:460-471`, verified; path-1
  (apply_capped at the apply site, not inside `decompose_drag`) is the right seam.
- **Breast volume counts** — `base_body_detail.index.json:159-160`: down=244, up=369,
  exactly as v10 states (m7-2 correction is right). `breast/BreastSize` macro dead.
- **Registry kind counts** — re-parsed `modifier_registry.json`: 291 modifiers,
  251 bidirectional / 29 unipolar / 11 macro — matches §3.1 exactly.
- **Bilateral pairing** — re-parsed: 61 `l-` modifiers, 0 unpaired (every `l-` has its
  `r-` twin), matching §0; the mirror twin-table claim holds.
- **Headline field defaults** — `body_state.gd:61,72,77,82,90,100`: age 25, masc 50,
  muscle 50, weight 100, proportions 0.5, height 166.589 — match the design's stated
  neutrals; `from_dict` (`:785-797`) copies fields + modifiers verbatim.
- **`is_adult_body` single chokepoint** — `body_state.gd:451`, verified; age cap floor as
  §2 predicate (not the cap) is consistent.
- **Acknowledged-open/deferred items** (combination-plausibility §3.4; default-interval
  numeric constants + taste-gated sign-off §8 #1b; Tier-B baker §5.1; subdivision cost §3.6;
  procedural-iris look §5.2; Quest costs §7; self-intersection monitoring §3.6/R8) — each is
  flagged with a reserved seam or a where-it-lives, and the §10.1 first-build→deferred
  re-scan holds: no first-build item I could find depends on a deferred one. NOT ranked.

---

## Summary of breaks

The v10 *core formula* survives, as the doc claims. The breaks are all at the **new v10
integration boundaries**, which is precisely where the doc said it changed things — and two
of the three changes introduce defects:

- **B10-1 (BLOCKER):** M9-1's "recompute `min/max` on every edit" + no live-path write-back
  of the clamped value ⇒ either the desync M9-1 claims to fix, or a re-entrant
  `value_changed`→bake cycle the design declares impossible. The named method is not a working
  method for the outward-clamp case.
- **M10-1 (MAJOR):** M9-2's load-bearing "every default interval contains neutral" invariant
  is false for the `[min>0, b0]` unipolar interval shape §3.1 itself permits ⇒ the erase
  manufactures a beyond-floor `cur` and ratchets the floor open from nothing.
- **M10-2 (MAJOR):** no live path writes the clamped `stored` back to the slider OR numeric
  field, so the repeatedly-leaned-on "visible, not a hidden lie" honesty property has no
  executable mechanism.
