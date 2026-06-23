# Attack — round 9 (hostile review of SYNTHESIS.md v9)

Hostile reviewer. Only job: break it. I did NOT trust the design's own
verified/fixed/resolved claims; I re-checked the load-bearing ones at HEAD. Acknowledged
open/deferred items with a sound seam are NOT ranked — they are called out only where a
deferral leaves a FIRST-BUILD item broken or the seam is unsound.

Grounding: `scripts/body/character_creator.gd`, `scripts/body/region_sliders.gd`,
`scripts/body/body_state.gd`, `assets/body/modifier_registry.json`,
`scripts/ui/options_menu.gd`, all re-read @ HEAD.

---

## BLOCKER

### B9-1 — Archetype/import load writes RAW (path 7), so "no-monster-by-DEFAULT" is FALSE for any archetype authored beyond the default interval. Self-contradiction with the central guarantee.

The design routes **archetype load** through the RESTORE/RAW path (§3.2 path 7;
§1.1 "Archetype loads store the raw saved values (no re-clamp; beyond-cap values persist)";
§6 "archetype loads store the raw saved values"). It separately makes the load-bearing
claim that default mode is "bounded by default" and that the first build "delivers a
complete, playable, no-monster-by-DEFAULT creator" (§10, §3, §1).

These two cannot both hold. The roster is "~15–18 first-party archetypes … a small named
build set (`slim/average/athletic/curvy/heavy/muscular`)" (§1.1). An `athletic`/`heavy`/
`curvy` archetype that "reads well" will, by construction, carry headline/detail values
**beyond the conservative DEFAULT interval** (that is what makes it athletic/heavy rather
than average) — otherwise the default interval is too wide and §8 #1b fails. Because
archetype load is RAW + the slider bounds then *ratchet open to admit the loaded value*
(§3.2 "After any restore/load, the slider bounds are refreshed to the loaded value's live
interval … so a beyond-cap loaded value's thumb sits AT the value"), a user who is at
extremeness 0 and simply **picks the `heavy` archetype from the T0 grid** — the single most
common first action in the whole creator — is immediately sitting beyond the default cap on
multiple axes, with the slider ranges silently widened to match. The "single, visible,
deliberate global unlock" (§3.1) was never touched. The no-monster-by-default property is
not gated by the global extremeness at all for the pick-and-go majority; it is gated by
whatever the archetype author happened to do.

The design never resolves whether picking an archetype is a LIVE edit (capped — but then a
faithful `heavy` archetype is impossible at extremeness 0) or a RESTORE (raw — but then
default mode is not bounded). It picks RAW and then asserts the bounded property anyway.
This is the exact "snap-vs-preserve" dilemma §3.3 claims was *dissolved* ("there is no
snap-vs-preserve dilemma because load NEVER snaps") — it was not dissolved, it was moved
from save/load to archetype-pick and left unaddressed. Locus: §1.1, §3.2 path 7, §3.3, §6,
§10 vs the §3/§10 no-monster-by-default claim.

---

## MAJOR

### M9-1 — Slider-bound re-application triggers are INCOMPLETE, so the v9 ratchet re-introduces the very thumb/value desync m8-1 claims to fix.

§3.2 (m8-1) specifies slider `min_value`/`max_value` track the live interval `[lo,hi]` and
are re-applied on exactly TWO triggers: "(a) when the global extremeness changes and (b)
when a beyond-cap value is loaded." But the ratchet `hi=max(b,cur)` is a function of `cur`,
and `cur` changes on **every inward live edit** — neither of the two triggers.

Concrete break (extremeness 0, bidirectional axis, default `[-0.5, 0.5]`):
1. Load an archetype with `cur = 0.9` (B9-1). Bounds re-applied on load → slider
   `max_value = hi = max(0.5, 0.9) = 0.9`. Thumb at 0.9. Correct so far.
2. User drags the slider DOWN to `0.6` (inward, free; `apply_capped` stores 0.6). No
   extremeness change, no load → **bounds are NOT re-applied.** `max_value` stays 0.9.
3. Now `cur = 0.6`, so the live ratchet is `hi = max(0.5, 0.6) = 0.6`. But the slider thumb
   range is still `[…, 0.9]`. The user drags the thumb to 0.8. The slider emits
   `value_changed(0.8)`; `apply_capped` clamps to `hi = max(0.5, cur=0.6) = 0.6`. **Stored
   = 0.6, thumb shows 0.8.**

That is precisely the "visible thumb/value desync" m8-1 says it eliminated
(`character_creator.gd:1035-1036,1169-1170` set bounds today). The fix is under-specified:
bounds must be re-applied after every capped live write whose result moved `cur` across the
ratchet boundary, not only on the two named triggers. As written, executed verbatim, the
desync recurs. Locus: §3.2 (m8-1), §1, §3.5 honesty claim.

### M9-2 — `_set_modifier` ERASES any modifier at `|v| < 1e-6`; the cap/ratchet model never accounts for the erase, and it silently mutates the "stored raw value" the whole ratchet is built on.

`_set_modifier` (`character_creator.gd:1209-1214`) does `if absf(v) < 1e-6: modifiers.erase(fn)`
— a value that reduces to ~0 is **removed from the map**, not stored as 0.0. The entire v9
cap mechanism is defined over "the stored raw value `cur`" (§3.1, §3.2) and the ratchet
`lo=min(a,cur); hi=max(b,cur)` reads `cur`. After an erase, `cur` is absent;
`modifiers.get(fn, 0.0)` (the read site, e.g. `:1170` slider init, `:1237` restore) returns
0.0. For a bidirectional axis with neutral 0 that is harmless. **But for a UNIPOLAR axis
whose default interval is `[0, b0]` with `a=0`, and for any axis whose conceptual neutral is
NOT where `get(...,0.0)` lands, the erase is a silent reset to 0.0 that the cap model treats
as a deliberate stored value.** More importantly, the design's `apply_capped(control, req) ->
stored` is specified to "store the raw result" — but the real write site it must wrap
(`_set_modifier`) does not store the raw result; it conditionally erases. The design never
mentions `_set_modifier`'s erase behavior, never says whether `apply_capped` replaces or
wraps it, and the round-trip determinism gate (#4, §3.3) depends on the stored map being
exactly the value set. Suspected interaction with `from_dict`/`to_blend_weights` round-trip;
would verify by driving a unipolar slider to ~0 then `to_dict()`/`from_dict()` and diffing.
Locus: `character_creator.gd:1209-1214` vs §3.1/§3.2 "store the raw result," gate #4.

### M9-3 — The default interval `[a,b]` per control is NET-NEW authoring of 56+ intervals with a NEUTRAL the design itself shows is non-obvious, presented as "data + a function" as if trivial.

§3.1 frames the cap as "data + a function, not stored alongside each value" and §10.1 lists
"conservative DEFAULT intervals" as a one-line first-build item. But pressure-testing this:
no `[a,b]` per-control data exists anywhere (`assets/body/caps*` absent, confirmed; no
`extremeness`/`cap(` in `scripts/`). The six headline intervals must be hand-authored in
non-uniform units (age yr, height cm, masculinity 0–100 about 50, weight 50–150 about 100,
proportions 0–1 about 0.5 — verified `character_creator.gd:726-731`), and the ~50 region
intervals must each be authored per the registry kind (251 bidirectional / 29 unipolar / 11
macro, verified). The design admits the *numeric values* are deferred to the §8 #1 sweep —
which is the legitimately-deferrable part — but it understates that authoring the **shape**
(which axis gets a window, which a one-sided band, where the unipolar floor sits, whether
proportions widens symmetrically about 0.5) is itself net-new design work for 56+ entries,
and that the sweep that is supposed to *validate* the values (#1b: N=10,000, per-control AABB
"within human-plus-stylized bounds") has no harness today (flagged net-new in m7-1) AND no
defined "human-plus-stylized bound" — the pass/fail criterion of the validating sweep is
itself a USER taste call (§8 (c) is user-judged), so the "objective per-control sweep" that
sets the default constants is not actually objective at its acceptance boundary. The MECHANISM
is specified (the values live in the versioned cap table) — so per the prompt's rule this is
not a BLOCKER on the where-they-live question — but the cost framing ("conservative DEFAULT
intervals", one line) hides 56+ entries of interval-shape authoring + a not-yet-existing,
taste-bounded validation harness on the first-build critical path. MAJOR as understated cost,
not as missing seam. Locus: §3.1, §8 #1b, §10.1, R6.

---

## MINOR

### m9-1 — Picker/`set_value_no_signal` citation paths are wrong; "already used at `options_menu.gd:46`" is `scripts/ui/options_menu.gd:46`.

§3.2 / §0 cite `options_menu.gd:46` for the existing `set_value_no_signal` precedent; the
file is `scripts/ui/options_menu.gd:46` (verified — the only `set_value_no_signal` in
`scripts/`). A bare `options_menu.gd` is ambiguous and does not resolve from repo root. Same
class of imprecision the design elsewhere polices (m8-4 corrected the picker path). Cosmetic
but it is a "verified citation."

### m9-2 — `region_sliders.gd:57` is correctly the pregnancy "belly" row, but §2's retire-FIRST step does not address the OTHER stomach rows or the abs-tone duplication.

Verified `region_sliders.gd:57` = `["stomach/stomach-pregnant-decr|incr", "belly", "flat",
"round"]` (the m8-2 claim holds). But the SAME group already ships `:58`
`stomach/stomach-tone-decr|incr` labeled "abs tone" — which §2 *also* proposes to surface as
"Belly softness / tone." So the §2 belly work is partly already present, and "replace
`:57` with the real belly axes" would *duplicate* the existing `:58` row unless the executor
notices. §2 presents the belly group as net-new surfacing; `:58` shows it is partly extant.
Minor sequencing/dup hazard, not a flaw in the decision.

### m9-3 — Randomize is classed LIVE (path 5, capped) but is also "a bounded seeded walk from a seed archetype"; the seed-archetype's beyond-cap values (loaded RAW, B9-1) make "randomize NEVER produces an extreme body at extremeness 0" false.

§1.3/§3.3 claim randomize at extremeness 0 "NEVER produces an extreme body" because it
samples within `[a,b]` via the choke. But randomize walks **from a seed archetype**
(§1.3), and that archetype is loaded RAW with beyond-cap `cur` values (B9-1, path 7). The
choke at `cur > b` gives `hi = max(b, cur) = cur`, so a "bounded seeded walk" starting from a
beyond-cap `cur` can sample up to `cur`, not down to `b`. The "never extreme at extremeness 0"
claim holds only if the seed archetype is itself within default caps — which B9-1 shows the
interesting archetypes are not. Locus: §1.3, §3.3 vs §3.2 path 7.

### m9-4 — "Each pole ratchets independently" is correct for a single value, but combined with `min/max` slider bounds spanning `[lo,hi]` it produces a slider whose *travel* crosses neutral freely while the choke blocks the far pole — a confusing-but-not-wrong UX, undocumented.

With `cur = +0.9` (`b=0.5`): `lo=min(-0.5,0.9)=-0.5`, `hi=max(0.5,0.9)=0.9`, slider bounds
`[-0.5, 0.9]`. The thumb can be dragged to `-0.5` (the low pole at its cap) and back, but NOT
to `-0.9`. That is correct per B8-3. However the slider visually spans an asymmetric
`[-0.5, 0.9]` with neutral 0 off-center, and a user who ratcheted the high pole now sees a
lopsided slider whose low reach silently shrank to the default `-0.5` while the high reach
stayed 0.9. Functionally correct, but the design's "the gating is VISIBLE at the slider"
(§3.2) oversells it — what is visible is an unexplained asymmetric range. Suspected UX
confusion; would verify by user test. Not a correctness flaw.

---

## Load-bearing areas attacked and NOT broken (with evidence)

- **B8-3 cross-pole sign-flip.** Re-derived the v9 clamp by hand for `cur=+0.9, b=0.5,
  a=-0.5, req=-0.9`: `lo=min(-0.5,0.9)=-0.5`, `hi=max(0.5,0.9)=0.9`, `clamp(-0.9,-0.5,0.9)=
  -0.5`. The ratcheted high pole does NOT re-admit the low pole beyond its floor. The
  per-pole-independent ratchet is structurally sound for a SINGLE value. (The slider-bound
  and archetype-load interactions are the real defects — M9-1, B9-1 — not the core formula.)
- **B8-1 neutral≠0.** masculinity default `[20,80]`, neutral 50 (default field 50.0 verified
  `body_state.gd:72`): `req=100 → clamp(100, min(20,cur), max(80,cur))`; with `cur` interior,
  `=80`; `req=0 → 20`. A correct window, no neutral-0 assumption. The formula is genuinely
  neutral-agnostic.
- **Headline fields have no registry `kind`.** Confirmed the six axes are direct `BodyState`
  fields (`body_state.gd:61,72,77,82,90,100`) written via `set()`
  (`character_creator.gd:1038`), not registry modifiers. The v9 claim that the interval is
  self-describing and needs no axis-type tag holds for them — the clamp reads only `[a,b]`.
- **Unidirectional/unipolar one-pole-never-opens.** For a unipolar axis the floor `a=0` and
  `lerp(0, hard_min=0, e)=0` for all `e`, so `lo=min(0,cur)=0` (cur≥0) — the low pole never
  opens regardless of extremeness. The asymmetric-hard-range case (e.g. weight 50–150 about
  100) is expressed as an asymmetric interval lerping each endpoint independently toward its
  own hard limit; the formula handles it. The clamp formula itself survives both pressure
  cases. (29 unipolar / 251 bidirectional verified in the registry.)
- **Restore re-fires callbacks (B8-2 premise).** Confirmed `_restore_current` does
  `(_sliders[field]).value = v` (`:1322-ish`) and `_restore_modifier_sliders` does
  `(e["slider"]).value = v` — both EMIT `value_changed`, so the design's diagnosis is correct
  and the `set_value_no_signal` raw path is genuinely required new work (no
  `set_value_no_signal` exists in the creator today; only `scripts/ui/options_menu.gd:46`).
  The split is *necessary*; the residual flaw is the archetype side of it (B9-1), not the
  undo/redo/reset side.
- **Bilateral pair completeness.** 61 `l-` full_names / 61 `r-` (verified by grep over
  `modifier_registry.json`), consistent with the §0/§1.3 "61 pairs, 0 unpaired" claim and
  the build-time twin-assert plan.
- **Belly axes exist & pregnancy row located.** `stomach-tone`, `stomach-navel-in|out`,
  `stomach-navel-down|up` present (`region_sliders.gd:58-60`); pregnancy row at `:57`. The
  "surface existing morphs, no new asset" belly plan is grounded.
- **Caps asset / `apply_capped` / `extremeness` are net-new.** Confirmed absent from
  `assets/body/` and `scripts/` — the design's m7-1 "NET-NEW" honesty holds; not hidden.

No attack landed on the core v9 single-value clamp formula. The breaks are at its
INTEGRATION boundaries: archetype-load classification (B9-1), slider-bound re-application
completeness (M9-1), the `_set_modifier` erase the choke must wrap (M9-2), and the
under-framed cost of authoring + objectively-validating 56+ default intervals (M9-3).
