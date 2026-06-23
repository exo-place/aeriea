# Attack — round 8 (hostile review of SYNTHESIS.md v8)

Hostile reviewer pass. Sole job: break the design. No strengths listed; no approve/ready
verdict. Every factual attack is grounded in a citation against actual code/assets @ HEAD —
NOT against the design's own "verified/resolved/fixed/finalized" claims. Suspicions are
labeled "suspected." Acknowledged open/deferred items WITH sound plans are NOT ranked as
flaws unless they break a first-build item or the plan/seam is unsound.

Focus per the prompt: the v8 revisions — the bidirectional two-sided clamp
`clamp(req,-ceiling,+ceiling)` with `ceiling=max(|cur|,c)`; the single `apply_capped` choke
and its enumerated write paths (incl. the headline-field path and the load-path exception);
the rescoped first-build gate #1.

---

## BLOCKER

### B8-1 — The v8 `apply_capped` choke has NO correct clamp formula for the six headline axes it explicitly routes through it (path 3). The two §3.2 formulas both assume neutral = 0; every headline axis has a neutral ≠ 0. v8's "B7-2 RESOLVED" claim re-breaks B7-2 in a new way.

This is the load-bearing v8 fix (§3.2, "ONE CAPPED-WRITE CHOKE COVERS ALL WRITE PATHS",
declared RESOLVED at R6 and in the round-7-resolved list line 1013-1016). Executed as
written it produces wrong caps on the entire T1 surface.

**The facts (re-verified @ HEAD):**
- v8 enumerates exactly TWO clamp formulas (§3.2 lines 517-546): UNIDIRECTIONAL
  (`[0,1]` unipolar, **neutral 0**, `stored = min(req, max(cur,c))`) and BIDIRECTIONAL
  (`[-1,1]` signed, **neutral 0**, `ceiling=max(abs(cur),c); stored=clamp(req,-ceiling,+ceiling)`).
  Both are defined ONLY relative to a neutral of 0 (unidirectional measures outward as larger
  value from 0; bidirectional measures outward as larger `|value|` from 0).
- The six headline axes are `BodyState` FIELDS with these defaults/neutrals
  (`body_state.gd:61,72,77,82,90,100`; UI ranges `character_creator.gd:726-733`):
  - `age_years` default 25.0, range **1–90** — no neutral/outward concept at all (pure scalar).
  - `masculinity` default **50.0**, range **0–100** — neutral (androgynous) = 50
    (`body_state.gd:14`, `character_creator.gd:717-718`). Always non-negative.
  - `muscle` default **50.0**, range 0–100.
  - `weight` default **100.0**, range **50–150** — neutral (average) = 100.
  - `proportions` default **0.5**, range 0–1 — "0.5 = the base mesh" (`body_state.gd:84-90`).
  - `height_cm` default **166.589**, range 50–230 — neutral ≈ median stature.
- v8 path 3 (§3.2 lines 501-503) routes ALL SIX through `apply_capped(field, req)` and says
  only "Headline caps are in the axis's own natural-unit / 0–100 convention." **No third
  clamp formula is given anywhere in §3.2 for an axis whose neutral is not 0.**

**The break:** apply either formula to `masculinity` (neutral 50). It is always in `[0,100]`,
so `|value| = value`. The bidirectional formula `clamp(req, -max(|cur|,c), +max(|cur|,c))`
clamps to `[-c, +c]` — a symmetric band around **0**, not around the neutral 50. With any
plausible default magnitude `c`, the formula either (a) forbids the entire feminine half
(everything below 0 is impossible anyway and the +pole clamps at `+c` ≪ 50, so you can't even
reach androgynous), or (b) if `c` is set ≥ 100 to make the axis usable, the cap does NOTHING.
There is no value of a single magnitude `c` measured from 0 that yields "bounded ± around the
neutral 50." The same failure hits `weight` (neutral 100), `proportions` (neutral 0.5),
`height_cm` (neutral 166.6). For `age_years` the very concept of "outward = larger |value|"
is meaningless — capping age is a `[min,max]` window, not a magnitude.

The honest cap for a neutral-`n` axis is a TWO-sided window
`clamp(req, n - c_lo, n + c_hi)` (or `clamp(req, lo, hi)`), which is a THIRD axis type the
design's state model (§3.1: "the axis type per control is KNOWN data... a bidirectional axis
is a registry `<a>-decr|incr`... a unidirectional axis is a `[0,1]` unipolar") does not
admit. Worse, headline axes are NOT registry modifiers at all (they are `BodyState` fields,
`from_dict` `body_state.gd:787-792`), so the §3.1 "axis-type tag carried in the cap table
alongside each control" has no registry kind to read for them — the tag source the design
names (the registry `kind`: 251 bidirectional / 29 unipolar / 11 macro, verified) does not
cover the six fields.

v8 declared B7-2 RESOLVED on the strength of "route the headline `set()` path through the
same choke." Routing them through a choke whose only two formulas are mathematically wrong
for those axes does not resolve B7-2 — it converts "headline axes uncapped" (the v7 break)
into "headline axes capped by a nonsensical formula" (the v8 break). The fix is named
(`apply_capped`) but the concrete method it names is incorrect for the system's T1 surface.
This is a genuine DESIGN FLAW, not an acknowledged open risk: §3 header says FINALIZED, R6
says RESOLVED, and gate #1a (line 911-915) asserts the choke is "correct" across "headline-field
set." Executed literally, the first-build choke caps the entire headline tier wrong.

---

## MAJOR

### B8-2 — The "ONE choke covers ALL write paths, enumerated; archetype/history-restore is the one excepted load path" claim rests on a misreading of the restore flow. Undo / redo / reset / history-jump actually re-drive the live (capped) slider callbacks, so a beyond-cap value is RE-CLAMPED on restore — directly contradicting §3.3 / gate #4's "beyond-cap loaded value PERSISTS."

§3.2 path 6 (lines 508-512) and §3.3 (lines 558-561) state history-restore "DOES NOT clamp
(by design)... beyond-cap loaded values PERSIST," citing the whole-field/whole-map writes
`character_creator.gd:1322-1327` / `body_state.gd:787-797` as the bypass. Gate #4 (line 940)
and gate #1a (line 914) assert this persistence as a testable property.

**The facts (re-verified @ HEAD):** `_restore_current` (`character_creator.gd:1315-1331`) —
the single funnel for `_do_undo` (`:1300`), `_do_redo` (`:1305`), `_jump_to_node` (`:1310`),
AND `_reset_all` (via `_restore_current`, `:1283`) — does NOT just do the direct writes the
design cites. It also, for every headline slider, executes `(_sliders[field]).value = v`
(`:1324`), and `_restore_modifier_sliders` (`:1232-1238`) executes
`(e["slider"]).value = v` (`:1237`) for every region slider. There is **no
`set_value_no_signal` anywhere** (verified: `grep set_value_no_signal` empty), so each
`slider.value = v` EMITS `value_changed`, firing the headline callback `:1046-1047`
(`_body_state.set(field, v)`) and the region callback `:1175-1176` (`_set_modifier`). Under
v8 those callbacks ARE the capped paths (path 2 and path 3). So the operative restore write
is the live capped callback, which immediately overwrites the direct `set()`/
`modifiers=…duplicate()` writes the design names as the "uncapped load."

**The break:** a beyond-cap value reached while extremeness was high, saved, then reloaded
and viewed via undo/redo/reset, gets driven through `apply_capped` at extremeness 0 and is
clamped — the exact opposite of §3.3's guarantee. Gate #4's "a beyond-cap loaded value
PERSISTS (load does NOT re-clamp)" would FAIL when exercised through the real UI restore path.
The v8 enumeration is therefore both incomplete (it never accounts for restore re-driving the
sliders) and wrong about which write is operative. The design cannot have it both ways: either
restore must use `set_value_no_signal` / bypass the callbacks (un-designed, not in the
enumeration), or restore re-clamps (contradicting the stated load exception). The "write paths
enumerated" claim that anchors the B7-2 resolution does not match the code's restore flow.

(Note: the IMPORT slice-1 path is wiring-only and could be built to bypass callbacks; but
undo/redo/reset are EXISTING code that already routes through the slider callbacks, so the
contradiction is live in the first build, not hypothetical.)

### B8-3 — The bidirectional `ceiling = max(|cur|, c)` model uses a SINGLE symmetric ceiling, so a beyond-cap magnitude earned on ONE pole silently re-admits the OPPOSITE pole to the same beyond-cap magnitude — including a free sign-flip across 0. This contradicts §3.2's own "each pole independently bounded at c (or at |cur| if already beyond)" claim and is exactly the load-path re-admission hazard the prompt flags.

§3.2 (lines 543-546): "a player can freely retract from one pole and push into the other,
**each pole independently bounded at `c`** (or at `|cur|` if already beyond)." The formula
(lines 532-534) is `ceiling = max(abs(cur), c); stored = clamp(req, -ceiling, +ceiling)`.

**The break — symmetric ceiling, not per-pole:** take `cur = +0.9` (a stored beyond-cap value
on the + pole, legitimately set when extremeness was high; default `c = 0.5`). Now at
extremeness 0 the player requests `req = -0.9` (the FAR, − pole). `ceiling = max(0.9, 0.5) =
0.9`; `clamp(-0.9, -0.9, +0.9) = -0.9` → ALLOWED. The − pole, which was supposed to be bounded
at `c = 0.5`, just got admitted to `-0.9` — a beyond-cap value on a pole the player never had
authority for, purely because the OTHER pole carried a ratcheted magnitude. The poles are NOT
independently bounded; they share one symmetric ceiling. The design's own sentence ("each pole
independently bounded at `c`") is false for its own formula.

**This is the load-path re-admission the prompt asks about, and it is worse than the load case
alone:** a save with `cur=+0.9` loaded at extremeness 0 (even ignoring B8-2) lets the next
single edit flip to `-0.9` and then, since `cur` is now `-0.9`, ratchet the + pole back to
`+0.9` — the value oscillates between both beyond-cap poles forever, at extremeness 0, with no
way for the cap to ever pull it in. The intended "inward ratchet" (magnitude only ever
decreases unless extremeness is raised) does NOT hold across a sign flip: crossing 0 lets a
ratcheted magnitude migrate to the opposite pole at full strength. To deliver the stated
property the model needs TWO independent per-pole ceilings
(`ceiling_pos = max(cur if cur>0 else 0, c)`, `ceiling_neg = max(-cur if cur<0 else 0, c)`),
which the single-`max(|cur|,c)` formula is not. As written, "the one-way inward ratchet
EMERGES" (line 548) is false for the sign-flip case.

---

## MINOR

### m8-1 — Slider widget `min_value`/`max_value` are the HARD registry range, not the cap; under the v8 capped callbacks the thumb and the stored value silently desync, and there is no design text for it.

`character_creator.gd:1035-1036` (headline) and `:1169-1170` (region) set `slider.min_value`/
`max_value` to the hard range (`BIDIR_MIN/MAX` = ±1, or the natural-unit range). Under v8 the
`value_changed` callback clamps the STORED value to `c` via `apply_capped`, but the HSlider
thumb is free to travel to the hard range. So at extremeness 0 a user drags the breast-volume
thumb to +1.0, the stored value caps at `+c`, and the thumb sits at +1.0 while the body shows
`+c` — a visible thumb/value desync the design's §1.3 "mandatory numeric entry… clamps to the
cap (visible, gated)" never addresses for the SLIDER. The honest fix (set slider max to the
live cap, or snap the thumb back) is un-designed. MINOR (UX/consistency, not a correctness
break of the stored value), but it undercuts the §1/§3.5 "honest, visible gated behavior"
claim — the gating is invisible at the slider.

### m8-2 — The region-slider table currently surfaces the PREGNANCY morph as the "belly" control; the design says pregnancy stays OUT but never flags that the live control to be REPLACED is the pregnancy axis.

`region_sliders.gd:57`: `["stomach/stomach-pregnant-decr|incr", "belly", "flat", "round"]` —
the shipped "belly" slider IS `stomach-pregnant`. §2 insists "Pregnancy (`stomach-pregnant`)
stays OUT of base creation" and proposes surfacing the non-pregnancy belly axes, but never
notes that executing §2 requires REMOVING an already-exposed pregnant-axis slider. An executor
reading §2 as "add the belly group" without "and retire the existing pregnant slider" leaves
the pregnancy morph live in the creator — the exact thing §2 forbids. MINOR (the right morphs
exist per facts-belly.md; this is an un-stated retirement step).

### m8-3 — Gate #1a is self-referential: it asserts "the B7-2 choke is correct" while §10.1 lists the choke + caps asset as NET-NEW first-build work; the gate cannot certify correctness of a formula that B8-1 shows is wrong for headline axes.

Gate #1a (lines 909-915) drives "headline-field set" with extreme requests and asserts
`|stored| ≤ max(|cur|, c)` "BOTH poles." But for a neutral-50 axis like `masculinity` that
assertion is the WRONG invariant (the correct invariant is a window around 50, not a magnitude
around 0) — so a gate written to assert `|stored| ≤ max(|cur|,c)` would either pass a
nonsensical clamp or fail a correct one. The gate inherits B8-1's wrong axis model. MINOR as a
standalone item (it's a consequence of B8-1), but it means the first-build "objective
cap-enforcement" gate is not a sound oracle for the headline tier.

### m8-4 — Picker file path mis-cited (`scripts/body/cpu_accel_picker.gd` in §5.5/§1.3) — the file is `scripts/util/cpu_accel_picker.gd`.

§1.3 / §5.5 cite "`cpu_accel_picker.gd:71,162-163`" without the `scripts/util/` path; the
picker lives at `scripts/util/cpu_accel_picker.gd` (verified). The cited lines themselves are
correct (`:71` caches `_positions` in `build`; `:162-163` lazy-rebuilds from cache in `pick`),
and the m-3 owner-driven-rebuild design is structurally sound — so this is a cosmetic
mis-location only. MINOR.

---

## Areas attacked and could NOT break (with what was verified)

- **Sculpt apply site is a real single funnel, cap-able (§1.3 path 1, §3.2).** Verified
  `character_creator.gd:460-471` computes `cur + delta` and writes raw with no clamp today;
  inserting `apply_capped` there is structurally viable. The flaw is the FORMULA (B8-1 for
  headline, B8-3 for bidirectional sign-flip), not the existence of this site.
- **Picker owner-rebuild (m-3, §5.5).** Verified the picker has no mesh handle and rebuilds
  from cached `_positions` on `_dirty` (`scripts/util/cpu_accel_picker.gd:64-65,162-163`); the
  owner-refetch-and-`build` plan is sound. `_apply_state` (`:1262-1271`) only calls
  `_cpu_picker.mark_dirty()` today — the `_morphed_surface_dirty` flag for glow/locality is
  named as the fix site, not pretended to exist. Could not break.
- **Load safety = hard-range projection clamp (§3.3, §6 slice 1).** Verified `from_dict`
  copies headline fields + modifiers verbatim (`body_state.gd:787-797`); projection clamps
  masculinity/100, age, height to hard range (`:244,270,282`). The projection clamp is
  independent of the cap and does not interfere — the design's separation holds. (But see B8-2:
  the UI RESTORE path re-clamps via slider callbacks, which is a different, broken, claim.)
- **Bidirectional liveness of breast volume + corrected counts (m7-2 fix).** Verified
  `base_body_detail.index.json:159-160` down=244 / up=369; §0/§4 now cite them correctly.
  Could not break the corrected citation.
- **Registry axis-type counts (§3.1).** Verified 251 bidirectional / 29 unipolar / 11 macro
  in `modifier_registry.json` — both clamp formulas have real registry customers (the
  unidirectional formula is not dead). The flaw is only that headline FIELDS match neither
  (B8-1), not that unipolar is absent.
- **Gaze left alone (§5.2, R3).** Re-verified consistent with round-7: eyes track via
  `eye.L/eye.R` bones (`face_rig.gd:256-258`), shader keys iris off model-space normal vs a
  constant forward `gaze_dir`; wiring `gaze_dir` would double-count. Decision holds.
- **Honestly-deferred items (NOT ranked as flaws per prompt):** combination-plausibility
  (§3.4, seam reserved, pure-sum composition verified `detail_library.gd:104`); Tier-B baker
  sub-decision (§5.1, R2); subdivision cost form (§3.6, R6/R9); procedural-iris user-judged
  (§5.2); self-intersection monitoring-only (§3.6, R8); Quest costs/limits (R13);
  self-intersection at extreme a stated known limit. Each has a sound seam/plan and none leaves
  a first-build item broken — not attacked as flaws. (B8-1/B8-2/B8-3 are attacked because they
  ARE first-build items asserted RESOLVED, not deferred.)

---

## Severity summary

- **BLOCKER** — B8-1: no correct `apply_capped` formula for the six headline axes (neutral ≠ 0);
  v8's only two formulas assume neutral 0; "B7-2 RESOLVED" is re-broken on the entire T1 surface.
- **MAJOR** — B8-2: undo/redo/reset re-drive the live capped slider callbacks, so beyond-cap
  values are RE-CLAMPED on restore, contradicting §3.3 / gate #4 "beyond-cap persists"; the
  "ALL write paths enumerated" claim misreads the restore flow.
- **MAJOR** — B8-3: bidirectional `ceiling=max(|cur|,c)` is a single SYMMETRIC ceiling, so a
  ratcheted magnitude on one pole re-admits the opposite pole (free sign-flip beyond cap at
  extremeness 0); contradicts §3.2's own "each pole independently bounded" and breaks the
  inward-ratchet across 0. (The load-path re-admission the prompt flags, generalized to live edits.)
- **MINOR** — m8-1 slider thumb/value desync (cap invisible at the slider); m8-2 unstated
  retirement of the live `stomach-pregnant` "belly" slider; m8-3 gate #1a inherits B8-1's wrong
  invariant; m8-4 picker path mis-cite.
