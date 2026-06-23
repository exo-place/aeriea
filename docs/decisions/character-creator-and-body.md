# Decision: Character creator + body — editing model, derived caps, fidelity tiers, execution split

Status: **DESIGN PASS — approved for first-build execution (2026-06-23); deferred items marked.** This is a clean spec, not a green promotion: the bounds-mechanism gates and the user-taste-gated quality bar are designed but not yet built or signed off.

Scope: the player-facing character creator and the body system it edits — the editing model (archetype + progressive-refine), the finalized cap model (raw modifiers + one global extremeness → a derived per-control allowed interval, one capped-write choke over all live write paths + a raw bypass for restore/load), breast-size semantics, belly semantics, region semantics, visual fidelity (skin / eyes / brows), camera + persistence, the VR dependency named (not designed) here, and a concrete testable quality bar split into objective and user-taste-gated clauses. **No feature code.** Out of scope, named as dependencies only: the OpenXR/stereo/controller VR workstream; the offline normal/AO baker toolchain (an unresolved sub-decision); authoring the ~15–18 archetype roster content; the pregnancy *simulation*; and the **combination-plausibility model (explicitly deferred — seam reserved, not built)**.

This doc derives from the adversarially-converged design at `docs/artifacts/design/creator-body/SYNTHESIS.md` (v16). It presents the design as a spec — decisions, rationale, the first-build/deferred split, and the quality bar — with the version changelog, the v1→v16 revision history, and the adversarial-round meta-commentary stripped out. The hardening trail is recorded under Provenance below.

It cross-links:
- `body-parameterization.md` — the underlying `BodyState` schema, natural-unit public API, single `masculinity` macro axis, the data-driven modifier registry over the full CC0 library, and the `body_age_years >= 18` gate predicate. This doc edits and bounds what that doc parameterizes.
- `procedural-body-and-animation.md` and `body-and-locomotion-slice.md` — the body pipeline and slice discipline this creator sits on.
- `npc-mind-and-language.md` — the same body system renders NPC embodiment; creator morphs are the substrate that performance layer drives.
- The diagnosis trail under `docs/artifacts/diagnosis/` — `creator-ux.md`, `body-render.md`, `body-visual-reverify.md`, `body-reverify.md`, `hair-parts.md`, `text-npc.md`, and the reference render PNGs — which grounded the verified-broken / verified-fixed claims this spec stands on.

---

## 1. The grounding — verified ground truth this design stands on

The whole design is built on facts re-checked against the live code at HEAD (not aspirational specs). The load-bearing ones:

- **The bake is the interactive hot path.** A sculpt drag re-bakes positions + normals over all 14,517 render verts every mouse-motion frame. The cap mechanism adds nothing to this path — it clamps upstream at the input layer (modifier-space), where the value is written.
- **Sculpt and slider edits are both modifier-space**, not per-vertex. `decompose_drag` returns `{full_name: value_delta}`; the apply site writes `cur + delta`. So a cap is a scalar clamp on the value, applied where the value lands.
- **Deltas pure-sum; there is no per-vertex displacement bound anywhere.** Application is pure addition. **Consequence: individually-capped controls can still sum into a deformed body** — which is exactly why combination-plausibility is its own (deferred) concern, not something per-control caps solve. The spec owns this honestly rather than claiming "sum of caps" prevents monstrosity.
- **Tangents are NOT rebaked under morph** (`bake_morphed_normals` writes positions + normals only). A tangent-space skin normal map shears under the large morphs the creator exists to make — a hard prerequisite to all skin-map work (§7).
- **Sculpt spatial data is read from the frozen neutral mesh**, so on a heavy morph a drag picks the wrong region — fixed in §2.4.
- **`breast/BreastSize` is a dead macro** (empty targets). The live size control is the bidirectional `breast/breast-volume-vert-down|up` axis (library `count` down=244 / up=369).
- **Belly axes already exist and are already imported** (tone, waist-circ, torso-depth, Weight, apple, navel, love-handles), all distinct from the pregnancy morph. The only gap is UI surfacing — a design task, not an import or asset-authoring task.
- **The eyes already look around via the `eye.L`/`eye.R` bones** driven by `val_look_dir`; the procedural eye shader keys the iris off the rotated eyeball's model-space normal. Driving the shader's `gaze_dir` uniform would **double-count** the rotation, so gaze is left alone.
- **Skin is a bare `StandardMaterial3D`** (no PBR maps); every skin map must be generated or sourced CC0.
- **The persistence read side already exists** (`creator_io.gd` parse/extract functions, round-trip tested); only scene wiring is missing.
- **No XR code anywhere; no pregnancy simulation anywhere.** Both are named dependencies, 0% built.

---

## 2. Editing model — archetype + progressive refine

**Decision:** the base model is **archetype + progressive refine** — pick a valid archetype → nudge headline axes → reveal deep control on demand. Rationale: it is the only candidate that reaches the deep-customization (TiTS-class) depth bar without a wall of 56 sliders as the front door, keeps the full registry tree and grab-sculpt as a relocated tier, and carries the lowest net infra risk — an archetype is a frozen `BodyState`, i.e. data over code at a faithful seam.

**On "controls mean what they say."** A control's hard stop is a fixed function of the global extremeness ONLY — never of other controls. This is explicitly NOT the rejected "shrink a slider's range because other controls moved" mechanism (opaque, sibling-dependent). The owned honest consequence: at extremeness 0 the numeric field and slider clamp to the default cap, so default mode IS "bounded by default, with a single visible global unlock." The clamp is **visible by construction** — the live write-back protocol (§4) writes the clamped value back to both the thumb and the numeric label, so a clamp is seen at the widget, not silently swallowed.

### 2.1 Archetype = a frozen, serializable `BodyState` (data over code)

A named, frozen `BodyState` — the six headline axes (`age_years`, `height_cm`, `masculinity`, `muscle`, `weight`, `proportions`) plus a curated sparse `modifiers` map — shipped as a small data file (`assets/body/archetypes/*.json` via `to_dict`/`from_dict`). ~**15–18 first-party** archetypes seed it: a `feminine | androgynous | masculine` family fork × a small build set (`slim / average / athletic / curvy / heavy / muscular`), shipping only combinations that read well. The roster content is out of this design's scope, de-risked by the moddable loop ("Save as archetype" exports the current `BodyState` + thumbnail).

**Two distinct load paths with different guarantees** — a first-party archetype and a user's own save are not the same kind of artifact even though both deserialize a `BodyState`:

- **First-party ARCHETYPES (the T0 starting points) MUST be authored within every control's default interval `cap(control, 0)`.** A build-time validation (gate #11) asserts this and fails the build otherwise. Consequence: picking any archetype at extremeness 0 — the single most common first action — can never land beyond the default cap, so slider ranges never silently ratchet open on a pick. Because an archetype value is within `[a,b]` by construction, loading it raw is identical to loading it through the capped choke at extremeness 0 — so archetypes use the raw load path with no special clamp, and the build gate is what makes raw == capped for them. A `heavy`/`curvy` archetype that "reads well" must fit inside the default intervals; if it cannot, that signals the default interval is too tight (a tuning input), not a license to ship a beyond-cap archetype.
- **User SAVE/LOAD (the user's own prior creation) preserves RAW and may be beyond cap** — when the user made it with extremeness raised. That is their creation, not a default starting point; beyond-cap values persist (consistent with the inward ratchet, §4). Imported external user saves are treated like user saves (raw-preserve).
- **Scope of the no-monster-by-DEFAULT guarantee, made explicit:** it covers the default new character and archetype picks. It does NOT cover what a user deliberately made with extremeness raised and reloaded — by design.

### 2.2 Progressive-disclosure tiers (additive, monotone — opening a tier hides nothing)

| Tier | Surface | For |
|---|---|---|
| **T0 Pick** | archetype grid (family → build, thumbnails) + Randomize | the pick-and-go majority |
| **T1 Headline nudge** | the 6 natural-unit axes (slider + mandatory numeric entry), "Blend toward…" | the common case |
| **T2 Curated detail** | ~12–16 high-impact low-footgun sliders (breast size, face shape, jaw, nose, hip/waist, brow, lips, **belly group** §3) — each a projection of a registry entry | players who want their own face |
| **T3 Full control** | the complete registry tree (the 56 region sliders + every modifier, grouped) — including the fine-detail navel rows and love-handles, **+ grab-sculpt with a visible grab affordance**, **+ the global extremeness gate (§4)** | power users / archetype authors |

### 2.3 Grafts onto the model

- **Mirror = a user-asymmetry toggle, orthogonal to bilateral resolution.**
  - **Bilateral RESOLUTION is structural, always on, independent of the mirror toggle.** A single UI slider for a bilateral region maps to TWO anatomical modifiers (`armslegs/l-…` AND `armslegs/r-…`) because there is no separate left/right slider. `resolve_full_names` always resolves a bare bilateral stem → both full names, so a bilateral slider drives both sides at all times. This is the control's definition, never gated by the user toggle.
  - **The MIRROR toggle controls ONLY contralateral application of a one-sided edit.** When a player edits one side of a bilateral/lateral region, the toggle decides whether the same delta is also applied to the opposite twin. **Mirror ON (default):** the delta is also applied to `twin(M)`, only when `twin(M) != M` (the midline guard — a midline modifier has no l-/r- form and would otherwise double-apply). **Mirror OFF:** the edit applies only to the touched side; resolution still happens correctly, only the contralateral application is suppressed.
  - **Canonical l-/r- twin table, built once at load** (the sole mirror-application map). For every registry `full_name` with `l-` at a side boundary, substitute `l-`→`r-`; keep the pair iff the twin exists (all 61 pairs resolve). A build-time assert fails if any `l-` has no `r-` twin, so a future asymmetric addition can't silently go unmirrored.
  - Both paths run in modifier space, every write through the `apply_capped` choke and the §4 write-back protocol.
- **Sculpt acts on the CURRENT MORPHED surface, not the frozen neutral.** The picker geometry, the locality decomposition basis, and the glow overlay all read a stale neutral snapshot, so on a morphed body a drag picks/biases the wrong region. **Fix: all sculpt spatial data refreshes from the current morphed surface, rebuilt lazily on the next pick after a bake.** The OWNER (`character_creator`, which holds the rig) re-fetches the live baked `ARRAY_VERTEX` and rebuilds the picker, the locality basis, and the glow overlay — the picker itself has no mesh handle. Honest scope: this handles the morphed REST-pose body; a posed/animated or future in-world sculpt would still mis-pick (a flagged limit, not handled here).
- **Grab-sculpt is the Tier-3 verb — with an explicit, visible grab affordance, not always-on grab.** Always-on grab is worse (picker latency means an empty-space miss can't start orbiting promptly); the real defect is the hidden keybind. Keep an explicit Sculpt mode, surfaced as a visible labeled toggle + state indicator + cursor change (`M` stays as an accelerator). Input scheme: *Orbit (default)* — left-drag orbits instantly (no pick), right-drag pans, scroll/pinch zooms. *Sculpt (toggled, visible)* — left-press runs the picker on the morphed surface; a hit starts grab+pull, a miss is a no-op (does not fall through to orbit).
- **Named region handles as a single data table** `[modifier_full_name, anchor, drag_axis_hint, label]`, seeded from the slider GROUPS, projecting to flat gizmos AND (future) VR grab-volumes. Honest status: zero rows today, flat-only near-term; the VR projection is a hypothesis (§9).
- **Mandatory numeric entry with a ±100 / 0–100 display remap.** Every axis has a typeable field bound to the slider; internal `[-1,1]`/`[0,1]` shows as `-100..+100`/`0..100`, or natural units (age yr / height cm). Committed through the choke + write-back against the control's current interval, and re-displayed showing the clamped value so the user sees the clamp. This is how T1 hits "172 cm".
- **Reset + bounded seeded randomize.** Reset (per-control / per-region / global) is a RESTORE path (raw write, no re-clamp). Randomize is a bounded seeded walk from a seed archetype that samples within the live interval through the choke — at extremeness 0 it samples within default intervals, so it never produces an extreme body unless extremeness is explicitly raised. This is airtight because the seed is a first-party archetype, which gate #11 guarantees is within every default interval. Action-logged → reproducible and shareable.
- **Per-archetype soft envelope (common-path guard).** Picking archetype A centers a soft envelope `A_value ± max_delta` (default ~0.35) on detail modifiers, keeping refinement near a variant of that archetype, with an explicit T3 escape. A *taste* nudge; the no-monster-by-default behavior is the §4 conservative default caps.

---

## 3. Editable in base creation vs gated

**Rule:** base creation edits a *persistent body identity* — the static shape at rest. *Transient physiological states* belong to the simulation layer.

- **In base creation (ungated, NSFW-first):** the 6 headline axes; all stable shape/size morphs — breasts, glutes, hips, waist, torso, limbs, neck, full face/head, **genital shape** (SFW is a render toggle); muscle/fat distribution; skin tone, eye color, hair/brow part + color; the **belly group** (below). Geometry is anatomy and is never gated — gate the verb × body intersection, never the morph primitive.
- **Belly — surface the EXISTING belly axes as named creator controls. No new asset, no pregnancy-morph reuse.** The distinct non-pregnancy belly axes already exist and are imported; this is a UI-surfacing task. Concretely:
  - **Retire only the pregnancy "belly" slider** (the gravid `stomach-pregnant` morph leaves the creator surface entirely — it moves to the future pregnancy *simulation*).
  - **Keep the existing tone axis** (`stomach-tone`, optionally relabel "abs tone" → "Belly softness / tone"); do NOT add a second tone control.
  - **Add only the genuinely net-new `torso/torso-scale-depth`** (belly-forward), plus the Weight/apple fat axes.
  - **Reference the already-shipping waist slider** (`waist-circ`) for belly girth rather than re-adding it. **No modifier is driven by two controls** — re-adding waist-circ under the belly group would be a two-thumb-one-modifier duplicate that desyncs live.
  - **Move the existing navel rows (in/out, down/up) to T3 fine detail**; love-handles (`hip-scale-horiz|depth` / `hip-trans-out`) at T3.
  - The resulting **T2 "Belly" group** = {Belly softness/tone, Belly forward, Body fat}; girth stays the single existing waist slider; T3 = {navel in/out, navel down/up, love-handles}.
  - **Owned consequence:** the big-belly recipe is a multi-axis stack (torso-depth + waist + Weight/apple) — exactly the COMBINATION case the per-control caps do NOT bound (§4.4). In the first build a too-far stack can be grotesque (accepted interim); the eventual guardrail is the deferred combination-plausibility model. Conservative default caps keep each *individual* axis plausible.
  - Labels are the design work (upstream desc strings are empty); the perceptual call of which combination reads as "paunch" vs "soft belly" vs "pot belly" is a USER-gated render check over existing morphs — no new asset, no bake.
- **Also gated to the sim layer:** arousal / engorgement / expression-AU morphs, transient transformation-in-progress, controlled `asym/*` targets (post-creation advanced).
- **Age** stays a continuous primitive; the creator's *player* age control is hard-clamped ≥18 via the single `is_adult_body()` predicate on the verb side. Archetypes carry age as a plain field.

---

## 4. Bounds — the finalized cap model

**Decision:** the no-monster-by-DEFAULT behavior lives in **parameter space**. Each control's reachable VALUE is clamped through ONE capped-write choke to a DERIVED, NEUTRAL-AGNOSTIC per-control **allowed interval `[a, b]`**, by ONE clamp formula for every axis type — plus the build-time guarantee that first-party archetypes are authored within those default intervals (gate #11), so the most common entry point (an archetype pick) is bounded too. There is **no per-vertex displacement budget, no composed-field clamp, no composition-stage geometry pass** anywhere.

> **Honesty note:** the per-control caps do NOT prevent grotesque COMBINATIONS. Because composition is pure-sum, individually-capped controls can still sum into a deformed body. Combination-prevention is a separate, deferred concern (§4.4). In the first build, grotesque combinations are possible (accepted); default mode stays plausible only via conservative per-control default caps.

### 4.1 State model — what is stored

- **`BodyState.modifiers` stores RAW values** (unchanged bare `{full_name: float}` schema), each in the modifier's hard registry range. No per-control cap state, no per-control ratchet state, no per-control authored-flag. The cap is **derived** — a pure function over the versioned cap table, never stored per value.
- **The near-neutral erase is kept and reconciled.** The real write site erases any modifier whose `|v| < 1e-6` rather than storing it (so a neutral body is a tiny dict). The cap reads `cur` as **"the stored value, or the control's neutral if absent."** The erase loses no ratchet — guaranteed by the invariant below — because a near-neutral value is inside every default interval, so erasing and re-reading it as neutral reproduces the identical `cur`. `apply_capped` WRAPS the existing erase, it does not replace it.
- **INVARIANT — every control's default interval contains its neutral/absent value: `a ≤ neutral ≤ b`.** Otherwise the absent→neutral read would silently ratchet the floor open with no beyond-interval value ever authored. Per axis type: bidirectional modifier (neutral 0) → `a ≤ 0 ≤ b`; unipolar modifier → `a = 0` (the `[min>0, b0]` floor-above-neutral shape is FORBIDDEN); headline axis → the band straddles its neutral (`[20,80] ∋ 50`, etc.); derived modifier → symmetric/range-anchored about its neutral by construction; age → the absent/default value lies in the default band. **The build gate (#11b) asserts `neutral ∈ [a,b]` for every control**, so a violating default interval fails the build.
- **ONE global `extremeness` scalar** — a single `0..1` value (plus a boolean "Allow extreme proportions" toggle). It lives on the creator-settings layer, NOT in `BodyState.modifiers` (it governs the input clamp, not a body morph). One scalar per save, round-trips trivially.
- **The cap is a per-control ALLOWED INTERVAL `[a, b]` in the control's own (absolute) units.** `cap(control, extremeness)` returns the interval; the same formula (§4.2) covers every axis type without a special case. At extremeness 0 it returns the conservative default interval; as `extremeness → 1` each endpoint lerps toward the control's HARD limit. No axis-type tag is needed at runtime — the interval is self-describing.
- **THE DEFAULT CAP RULE — every sculptable modifier is capped (authored-or-derived).** `cap(·)` is a TOTAL function: it returns an AUTHORED interval if one exists (the ~56 curated controls + 6 headline axes, hand-authored and taste-tuned), else a DERIVED interval computed from the modifier's own registry range — `[neutral − f·R, neutral + f·R]` clamped to the hard range, where `R` is the hard span and `f` is a single global default fraction (the one tuning constant), with the unipolar floor pinned to `a = 0`. The derived interval widens by extremeness exactly like the authored ones. This matters because a sculpt drag can write ANY of the ~280 non-macro registry modifiers — so the choke genuinely caps ALL live write paths, including the ~224 uncurated sculpt-reachable modifiers, **with the authoring cost still ~56 + headline, not ~280**.

**Honest authoring cost.** Authoring the `[a,b]` shape for each of the ~56 curated controls + 6 headline axes — in non-uniform units (age yr, height cm, masculinity about 50, weight about 100, proportions about 0.5; the ~50 region intervals per registry kind) — is genuine net-new first-build work: which axis gets a symmetric window, which a one-sided band, where a unipolar floor sits. The ~224 other modifiers are capped by the derived rule with no per-modifier labor. The numeric values and final sign-off are deferred to the tuning/taste pass; the shape authoring is upfront. The validating sweep (§8 #1b) MEASURES each control's AABB objectively, but its acceptance boundary — "human + tasteful stylized range" — is **USER-taste-gated**, so default-interval sign-off is a user call.

### 4.2 Behavior — one capped-write choke, one neutral-agnostic formula; the inward ratchet emerges

EVERY live parameter write — modifier-space AND headline-field — routes through a single helper `apply_capped(control, req) -> stored` that reads the live derived interval, reads `cur` (stored-or-neutral-if-absent), applies the clamp below, and stores the raw result through the real write site (keeping its erase-at-neutral). The six headline axes are direct `BodyState` fields (not in `modifiers`), in natural units — the neutral-agnostic interval handles them with no axis-type tag.

**The clamp — one formula, every axis type.** Let `req` be the request, `cur` the stored-or-neutral value, `(a, b) = cap(control, extremeness)`:

```
hi  = max(b, cur)          # cur raises the high ceiling ONLY if already beyond b
lo  = min(a, cur)          # cur lowers the low floor   ONLY if already beyond a
new = clamp(req, lo, hi)
```

- **Outward beyond `[a,b]` is hard-clamped.** With `cur` inside `[a,b]`: `req` past either endpoint lands exactly on it. (`masculinity` default `[20,80]`: `req=100`→`80`, `req=0`→`20` — a correct window around neutral 50, which a magnitude clamp could not express.)
- **Inward (toward the interior) is free**, from either side.
- **Each pole ratchets INDEPENDENTLY.** `hi` is raised by `cur` only when `cur > b`; `lo` lowered only when `cur < a`. A value ratcheted high (`cur=+0.9 > b=0.5`) gives `clamp(req, 0.5, 0.9)` — a `req` of `-0.9` lands at `0.5`, NOT `-0.9`. No shared symmetric ceiling, no free sign-flip across neutral.
- **Beyond-interval stored values persist and reduce freely.** A `cur` beyond cap (set while extremeness was higher) holds where it sits; reducing it back inside `[a,b]` is free, and once inside it is bounded going forward.
- **The one-way inward ratchet EMERGES — no extra state.** It falls out of "clamp only outward input + store raw + never re-clamp stored values," and holds across the whole range including a sign change because the two poles ratchet from `cur` independently.

**Live edit vs restore/load — the precise split.** The choke is for LIVE edits only. Restore and load write the model RAW and update widgets WITHOUT re-firing the capped callback, via `set_value_no_signal` (Godot's setter that suppresses `value_changed`). This is required because every restore path today does `slider.value = v`, which re-fires the live capped callbacks and would re-clamp a persisted beyond-cap value at extremeness 0. Without the bypass, beyond-cap persistence breaks.

### 4.3 The live-edit widget write-back protocol (exact ordered steps)

For a live edit (`control`, requested `req`, bound widget `w`), every live write path follows:

1. **Clamp:** `new = apply_capped(control, req)`.
2. **Write the model:** store `new` through the real write site (`_set_modifier`, honoring erase-at-neutral; or `set(field, new)` for a headline field).
3. **Compute the widget interval — HELD across the active edit gesture, captured lazily inside the choke.** The interval `[lo, hi]` a widget is bounded to is computed from a held ratchet input captured at the control's FIRST touch within the gesture, NOT the live mid-gesture value.
4. **Apply to the widget without re-firing — strict order:** set `w.min_value = lo` and `w.max_value = hi` FIRST (widened to contain `new`, so Godot's `Range` cannot clamp-and-emit), THEN `set_value_no_signal(new)`, THEN display `new` in the numeric label (read `new`, not the pre-clamp request).

Why this matters: it closes two real defects on the outward-clamp case the cap exists for — (a) a thumb/value DESYNC (thumb shows the request, model holds the clamped value), and (b) a re-bake FEEDBACK LOOP (setting `max_value < value` makes Godot clamp-and-emit `value_changed`, re-entering the live callback → another full 14,517-vert bake). The `set_value_no_signal` write-back kills the loop; thumb + label both showing the clamped `new` kills the desync and gives the "gating is visible at the slider, not a hidden lie" property a real mechanism. This is also why the cap "adds nothing to the bake hot path" — a consequence of step 4, not free.

**Three invariants govern the held-interval / gesture machinery:**

- **The CHOKE-CAPTURE INVARIANT.** The first time `apply_capped(control, …)` is called for a control within an active gesture, the choke lazily captures that control's held value `cur_start` into a gesture-scoped held-interval map. Every subsequent write for that control within the gesture clamps against the HELD interval `[min(a, cur_start), max(b, cur_start)]` — both the clamp (step 1) and the widget bounds (step 3). Bounds recompute from the settled value on gesture END (the map cleared). Because capture happens INSIDE the choke on first touch, it automatically covers EVERY control any write path routes through the choke — directly-touched, sculpt-decomposed, the mirror-applied `twin(M)`, numeric, randomize, headline, and any future cascaded write — with NO per-path enumeration. This is what makes a transient mid-gesture dip unable to collapse a ratchet on any path: the value can travel anywhere within the held interval mid-gesture, and only the COMMITTED gesture-end value collapses the ratchet (the intended "reducing inward collapses the ratchet" semantics). It also protects controls with NO bound slider (the common case for the ~224 uncurated sculpt-reachable modifiers).
- **The GESTURE-LIFECYCLE-INTERRUPTION INVARIANT.** Any STATE-REPLACING operation that can occur mid-gesture — a raw restore (undo/redo/reset/history-jump, reachable mid-drag via the keyboard handler while a mouse drag is held), an archetype/import load, or an extremeness change — MUST FIRST abort the active gesture (clear the held-interval map, clear the in-flight sculpt accumulators and gesture brackets, cleanly end the gesture) BEFORE applying the operation. After such an op there is NO active gesture: this is a SAFETY property (no zombie gesture, no garbled commit). With a button still physically held, the next motion is dead hover, not a gesture; a fresh gesture begins only on the next press, capturing first-touch against the NEW state — so no stale `cur_start` and no surviving ratchet the restore removed. This ONE rule subsumes the extremeness-mid-gesture case: an extremeness change is a state-replacing op, so it aborts the gesture then runs an immediate full all-controls bounds sweep (every control's interval widens/narrows with extremeness, not just the touched ones).
- **The SHARED-WIDGET CONSERVATIVE-DISPLAY rule.** A bilateral slider is ONE widget driving TWO controls (L+R). Its displayed bounds use the CONSERVATIVE intersection of the two sides' cap intervals — `min_value = max(lo_L, lo_R)`, `max_value = min(hi_L, hi_R)` — so the single thumb cannot exceed either side's true cap when L and R have diverged (reachable via mirror-OFF sculpt or an asymmetric imported save). Per-control held intervals and clamping remain individually correct and unchanged; only the shared display uses the intersection. **Documented consequence:** on a diverged body, touching the shared bilateral slider resyncs the more-ratcheted side DOWN to the intersection bound — intended and acceptable (a single shared widget cannot represent two reaches). The ratcheted reach remains reachable via per-side SCULPT or by raising extremeness; a user who wants to keep the asymmetry simply does not drive that axis through the shared slider.

**Asymmetric range is intentional.** When one pole is ratcheted, the slider track is deliberately lopsided. A small cap-vs-ratcheted-extent marker (a tick at the default endpoint inside the widened track) makes the lopsided range legible. Named minor UX, not load-bearing.

**Live-edit paths** (each follows the 4-step protocol; `apply_capped` is step 1): (1) sculpt deltas — the cap is applied at the apply site, NOT inside `decompose_drag`, which keeps its own hard-range clamp; the sculpt drag is an active gesture, and a sculpt-driven modifier's bound slider is synced via `set_value_no_signal`; (2) region sliders (T2/T3); (3) headline-axis fields (the six T1 axes); (4) numeric entry, for any axis; (5) randomize, each sampled value through the choke.

**Restore/load paths** (write the model RAW + `set_value_no_signal` — not capped, by design): (6) history restore — the funnel for undo/redo/history-jump/reset; (7) user save/load and external import — `from_dict` whole-map replacement, values preserved raw, a beyond-cap value persists (import safety is the existing hard-range projection clamp + dropped unknown keys, NOT a cap re-clamp); (7a) first-party archetype pick — same raw mechanism as path 7, BUT every archetype value is guaranteed within its control's default interval by gate #11, so at extremeness 0 the loaded value is already inside `[a,b]` and no slider bound ratchets open — raw load is identical to capped load.

### 4.4 Combination-plausibility — DEFERRED; seam reserved

The eventual guardrail against grotesque COMBINATIONS (multiple individually-reasonable axes summing into a deformed body) is a **combination-plausibility model**: a validity model over modifier combinations that can prevent grotesque stacking, **toggleable OFF**.

- **DEFERRED — not in the first build** (user decision: low priority). Nothing is built here.
- **The seam IS reserved.** It would hook as a post-composition validity check that reads the resolved modifier-value vector (and optionally the composed AABB / region measurements) and can nudge or warn (and, if ever made enforcing, attenuate) — toggleable, defaulting on once it exists. A value-vector-level check, NOT a per-vertex pass on the bake hot path.
- **Interim (first build): grotesque combinations are possible — accepted.** Default mode stays plausible only via conservative per-control default caps. No claim is made that the first build prevents monstrous stacking.

### 4.5 Per-control caps are control-OWN, never sibling-dependent

Each control's cap is its OWN fixed hard stop, a function of the GLOBAL extremeness ONLY. A control's hard stop never changes because other controls moved — only because the single global extremeness changed. This is explicitly different from the rejected "shrink a slider's range because other controls moved" mechanism.

### 4.6 Faceting & mesh validity at extremes — a separate concern (the subdivision setting)

Because extreme is reachable (opt-in via the global gate), high morphs may FACET — the base mesh's inter-vertex displacement *gradient* can exceed what the tessellation represents smoothly. **This is a curvature/tessellation issue, NOT a magnitude one** — the value caps do not bound it.

- **Handled via a SUBDIVISION SETTING.** Two forms, decided by cost: bake-time subdivision of affected surfaces (a one-time geometry cost, the safe default for shipped extreme archetypes), or a runtime quality setting selecting a higher-tessellation mesh variant. NOT runtime Catmull-Clark on the per-drag bake (unaffordable, rejected).
- **Verified by an independent dihedral/edge-angle metric (gate #8)** — the per-edge dihedral angle, flagged where it exceeds an absolute threshold set from smooth-reference renders. The metric knows no cap, so it independently catches "this extreme facets."
- **Quest honesty.** On Quest the subdivision setting is off/low, so **extreme morphs MAY facet on Quest — a known platform fidelity limit; extreme mode is allowed but not guaranteed smooth there.** The Quest budget gate does not cover it (no XR/Mobile build exists). A stated, accepted limit, not a hidden one.
- **Self-intersection at extreme / opt-in settings is a KNOWN, FLAGGED limitation — not a hard guarantee.** With extreme caps reachable and grotesque combinations allowed in the interim, the surface can fold through itself. The self-clip check (§8) is MONITORING, not a blocker — it runs nightly to surface self-intersection regions, but does not fail the build. At default caps it is expected to stay clean.

### 4.7 Caps & extremeness as a versioned asset (replay determinism)

The cap table (default caps + the extremeness→cap mapping) is a **versioned part of the asset** (`assets/body/caps.v<N>.json` or equivalent).

- **Replay/randomize determinism holds against a fixed caps version.** A save / action log records the caps version + the single global extremeness. Same archetype + nudge sequence + randomize seed + caps version + extremeness → byte-identical `BodyState` and baked mesh. The choke clamp is a per-value `clamp` over the derived interval — no cross-vertex reduction, no float-order hazard.
- **A retune bumps the version; stored values are NOT migrated.** Because caps are derived (not stored per value), a retune changes the FUNCTION, not any stored value — old saves replay against their stored version. (Cross-platform byte-identity is narrowed to "within a platform" until a Quest build can be diffed.)

---

## 5. Breast-size semantics

The dead `breast/BreastSize` macro and the un-vendored 216-file cup cube are confirmed. **Decision: drive size via the live bidirectional volume axis** (`breast/breast-volume-vert-down|up`, library `count` down=244 / up=369), labeled honestly as a bidirectional volume axis. It gives finer, direct, correctly-labeled control than a 3-anchor macro, at zero re-bake.

- **The derived cup-letter readout is DROPPED** (net-new mesh-measurement infra); the control is labeled by its honest axis.
- **Tradeoff (owned):** this loses factor-cube composition of cup size with gender/age/weight. Importing the cup cube is the upgrade path if anatomically-correlated cup-vs-body composition ever becomes a hard requirement.
- **Guard (keyed on library `count`):** a build-time assert fails if any exposed control binds a modifier whose delta-library `count == 0` in the index it actually binds. A dead control like `BreastSize` can never silently ship. Dead macros are retired, not left as no-op aliases.

---

## 6. Visual fidelity — honest tiers, named prerequisites

The "plastic/broken" look is shading and seating, not mesh density. No runtime LLM, no per-config baking — every map is build-time generated from a cited source or authored once and vendored CC0; maps are static and morph-invariant in UV space.

### 6.1 PREREQUISITE — tangent rebake under morph, seam-split; refresh on COMMIT

`bake_morphed_normals` recomputes positions + normals but never rebakes `ARRAY_TANGENT`, so a tangent-space skin normal map shears under large morphs. **Fix:** recompute per-render-vertex tangents on the baked positions WITHOUT welding — follow the converter's seam-split Lengyel path, NOT the normal rebake's per-base-vertex weld (mirroring the weld would re-introduce the very seam the converter split).

- **Tangents are recomputed on COMMIT** (drag release / committed slider change), not during drag — a during-drag pass over 14,517 verts on the per-motion bake is too expensive. During a drag the skin detail-normal uses pre-drag tangents (slightly off mid-drag, snaps correct on release). Whether the drag-time approximation is acceptable is a USER-judged visual call.
- **Quality gate (split, #7):** committed-state normal-map validity is OBJECTIVE (no sheared/swimming detail, no re-introduced UV seam, specular-variation in band, via pixel-diff under flat light); the drag-time look is USER-gated.

### 6.2 Skin — Tier A ships first (generic), Tier B reaches reference (needs a baker decision)

- **Tier A (ships first, reaches generic):** a tiling generated/CC0 detail normal (pores) via `detail_normal`, a roughness map (kills the flat sheen), subtle albedo break-up, low SSS. Engine-native; the bulk of the perceived fix. Ceiling: a tiling pore normal has no meso structure — plateaus at generic.
- **Tier B (reaches reference):** a baked meso normal + AO from an offline subdivided high-poly of the CC0 base, against the 14.5k low-poly UVs. Godot has no offline baker → a **baker toolchain sub-decision** (below). Tier A ships regardless.
- **Quest:** SSS is a Forward+ screen-space effect — gate it OFF on Quest Mobile (normal/roughness only). The subdivision setting is also Quest-gated, so extreme morphs may facet on Quest (known limit).
- **Sub-decision (flagged, unresolved):** the Tier-B baker — Blender-headless `bpy` (proven, heavy new dep) vs in-Godot GPU bake (lighter dep, more to write). Prototype both against the plastic-look gate; Tier A unblocks the product.

### 6.3 Eyes — procedurally approximate the reference iris look; gaze left alone; cornea optional

Keep the fully-procedural `eye.gdshader` AND the existing 96-vert proxy geometry; improve the shader to procedurally approximate the desired iris look (stylized acceptable). **No iris PNG sampling, no iris re-vendor, no denser-proxy re-bake, and no `gaze_dir` wiring.**

- **CORE — improve the procedural iris:** model striations/fibers, the limbal ring, pupil, and iris/sclera specular so the eye reads like the reference without any texture sampling. User taste-gated (#6a).
- **GAZE — leave it alone.** The eyes already look around via the `eye.L`/`eye.R` bones driven by `val_look_dir`, with the skinned eyeball carrying its model-space normals (which the shader keys the iris off). Driving the shader's `gaze_dir` uniform from the eye-bone forward would DOUBLE-COUNT the rotation. The uniform stays at its constant forward default.
- **CORE — eye color is a procedural parameter:** expose `iris_color` (and any palette/variation uniforms) to a UI slider — the only eye-color control needed, no texture tinting.
- **OPTIONAL / DEFERRED — cornea parallax/refraction is net-new shader infra** (view vector + iris-under-cornea offset). The core items deliver the iris look without it.
- The eye fidelity gate (#6a) is USER/reference-anchored taste; objective companions (seating; specular-variation in band) remain agent-verifiable.

### 6.4 Brows / lashes — alpha-textured cards

Keep the authored morph-following card geometry. Replace solid dark cards with alpha-textured hair cards + `cull_disabled` + alpha-scissor (VR-safe). No CC0 brow/lash alpha source exists → author the alpha in-repo (a small CC0-by-authorship hair-strand strip). Layered strips kill the brow-peak notch; brow color ties to the hair-color param.

### 6.5 Camera / preview

- **Default view = the FACE, front, eye-level, head-and-shoulders** (the face-front default + centered pivot already landed; reference it, do not re-guess).
- **Studio 3-point lighting rig** (key + fill + warm rim) + neutral IBL + a lighting-rotate control. Always preview at the top quality tier, with a "preview as Quest" toggle to show the degraded tier honestly (including the Quest extreme-faceting limit).

### 6.6 Sculpt-mode spatial data + glow overlay

- **All sculpt spatial data tracks the morphed surface** (§2.3): the picker, the locality basis, and the glow overlay refresh from the live baked `ARRAY_VERTEX` on the next pick after a bake, owner-driven.
- **Glow clips through the body** (overlay stamped at exact body vertex positions with no outward offset → z-fight). Fix: offset overlay verts outward along the morphed per-base-vertex normals (thread the baked `ARRAY_NORMAL` into the rebuild), paired with depth handling. **ε must be WORLD-space, scale-corrected:** the overlay is a child of the scaled skeleton, so apply `v + n · (ε_world / height_scale())`. Add a build/run assert that `skeleton.scale` is uniform so this can't re-break invisibly.

### 6.7 Minor scoped render/UX cleanups + deferred items

- **Tongue positioning off — named fix; ASSET RE-BAKE cost.** The tongue's base rest offset is off. Method: look up the teeth/jaw piece surfaces by name → range, compute the mouth-cavity centroid/AABB, re-seat the tongue's rest attach offset. Cost: this means regenerating the vendored proxy asset (+ the proxy detail library keyed to the global vertex numbering) — an offline asset re-bake, not a runtime field edit. Tested by gate #2 (tongue centroid within mouth-cavity AABB across morphs).
- **Opt-in hairstyle drape over the face — DEFERRED** (the default hair cap hide is fixed; opting into a visible hairstyle re-triggers unfixed seat defects — a standalone slice).
- **Dead `base_index` / `neutral_base_index` masking machinery** — retire it (and its lying comments) while touching `bake_morphed_normals`.
- **Stale `_apply_state` cost comment** — correct/remove the comment claiming the bake is cheap; a sculpt drag runs it every motion frame.
- **UX nits:** expand abbreviated slider labels; introduce a shared `Theme`; consolidate export buttons into one Export action with a format choice; remove the dev picker-toggle from the player input map.

---

## 7. Persistence

- **Autosave `BodyState` + `HistoryTree` + the single global `extremeness` to `user://`** on every committed change and on exit/close; restore on ready. Record the caps version + the one global extremeness scalar (round-trips trivially).
- **Sequencing — two slices, explicit dependency:**
  1. **Raw save/load/import ships FIRST** (the read side EXISTS — only wiring left). The near-term work is an Import button + FileDialog + drag-and-drop handler calling the existing parse functions. Import safety = the existing hard-range projection clamp + dropping unknown keys. Load does NOT re-clamp to the cap (beyond-cap persists); there is NO composed-field re-clamp on import (that machinery is deleted).
  2. **Caps-version recording ships AFTER the §4 cap table exists** — for replay determinism; there is no value-snap migration (caps are derived, load never re-clamps).
- **"Save as archetype"** writes the current `BodyState` + thumbnail + extremeness to the USER archetype library. These are USER artifacts (treated like user saves), loaded RAW — may be beyond cap and persist. Distinct from the first-party roster, which is the only set subject to the within-default-interval build gate #11.
- **Async load:** show the archetype grid first (cheap thumbnails over data), build the live rig/accel/picker deferred/threaded.

---

## 8. Quality bar (concrete, testable)

Each is pass/fail under `nix run .#test` / `xvfb-run` renders. A change ships only if it doesn't regress a green gate.

**Process principle — visual taste is USER-gated, never LLM-self-certified.** Gates split:

- **(a) MEASURABLE/OBJECTIVE — an agent may verify.** No UV seam via pixel-diff under flat light, proxies follow morph via vertex deltas, monotone size sweep, determinism/round-trip byte-equality, specular-variation std-dev vs a baseline, silhouette faceting via an edge-angle metric, AABB bounds, self-intersection via BVH/SDF (as a *monitoring* report only).
- **(b) SUBJECTIVE/TASTE — must be USER-judged (or reference-anchored).** "Does the skin look like skin," "does the iris look right," "is the face non-uncanny," the belly-group "reads as paunch" call, the drag-time tangent-drift look. Process: render → present → user verdict. Agents NEVER promote a gate on a (b) judgment.

The gates:

1. **First-build no-monster check — three clauses, none depending on a deferred item:**
   - **(a) OBJECTIVE — cap-enforcement across ALL live write paths.** Drive each live path with adversarial requests including the extreme poles; assert every stored value respects `lo ≤ stored ≤ hi`. Include the SCULPT path against an UNCURATED modifier (asserting it clamps to its DERIVED interval, not the hard range). Specific regression asserts: the masculinity-window and bidirectional-clamp cases (no neutral-0 magnitude assumption); the ratcheted-high-pole-does-not-re-admit-the-low-pole case (no free sign-flip); restore/load paths do NOT clamp (a persisted beyond-cap value survives a restore via `set_value_no_signal`); the LIVE-EDIT WRITE-BACK PROTOCOL (after an outward-clamped edit the slider value and label both read the clamped value — no desync; the callback fires exactly once — no re-entrant second bake); and ONE PATH-AGNOSTIC TRANSIENT-DIP ASSERT proving the choke-capture invariant across every reach-the-choke path (directly-touched slider, sculpt-decomposed, sculpt-only-no-bound-slider, multi-modifier, and the pre-ratcheted MIRROR TWIN), plus the mid-gesture STATE-REPLACING-OP abort assert (a mid-gesture undo/load/extremeness-change aborts the gesture and leaves a correct, non-garbled node).
   - **(b) DEFAULT-mode per-control plausibility** (objective AABB measurement, USER-gated acceptance, NOT a combination guarantee): N=10,000 seeded random axis vectors at DEFAULT caps, per-control / each axis alone, producing a body AABB judged within "human + tasteful stylized" bounds. The sweep MEASURES objectively; the pass/fail call is a USER sign-off. This is the validating pass for the net-new default-interval authoring.
   - **(c) USER-judged default-mode combined-extreme RENDER** (taste-gated): render a body with several default-capped controls pushed to their default poles together; present for a USER verdict ("reads as a person, not a monster, at default caps"). Replaces the removed automated self-intersection clause.
   - **Self-intersection is DEFERRED MONITORING, not a first-build gate** — a nightly report, never failing the build.
2. **(a) Eyes (+ tongue) seated at all genders/ages** (regression guard): eye proxy centroid within the eye-socket AABB and teeth/tongue within the mouth-cavity AABB across masc 0/50/100 and age 18/40/70; proxy-follow alive.
3. **(a) Monotone breast-size sweep:** sweeping the volume axis 0→100 monotonically increases chest-region volume; no exposed control binds a `count==0` target. (No cup-letter assert — readout dropped.)
4. **(a) Persistence round-trip:** set non-default → autosave → restore → byte-identical `to_blend_weights()`; quit→relaunch restores; import via the wired button/drop handler round-trips a JSON and a PNG-embedded state; a beyond-cap loaded value PERSISTS through the real UI restore path (undo/redo/reset/jump at extremeness 0 do NOT re-clamp it); the recorded global extremeness round-trips. (Caps-version recording is slice 2.)
5. **(a) Determinism** (against a fixed caps version + the global extremeness): same archetype + nudge sequence + randomize seed + caps version + extremeness → byte-identical `BodyState` and baked mesh *within a platform*. NET-NEW dependency: the caps asset (does not exist yet).
6. **Fidelity floor vs reference renders (SPLIT):** **(a) objective** — eyes seated; no face/cranium two-tone or back-of-head/inner-leg seam (incl. no tangent seam) via pixel-diff under flat light; skin detail survives flat-ambient. (Forward eyes parallaxing under ±15° applies ONLY if the optional cornea work is taken on.) **(b) USER-gated taste (#6a)** — the procedural iris approximates the reference look; brows read as feathered hair; skin reads as skin; non-uncanny.
7. **Tangent rebake validity (SPLIT):** **(a) committed state** — a normal-mapped surface after commit at a large morph shows no sheared/swimming detail and no re-introduced UV seam; specular-variation in band. **(b) drag-time look — USER-gated.**
8. **(a) Edge-of-range faceting check — INDEPENDENT dihedral metric.** NET-NEW harness (no metric code today). Measure faceting via the per-edge dihedral angle, flagging where it exceeds an absolute threshold from smooth-reference renders. Remedy: the subdivision setting. **(b)** the user-visible max is rendered for USER review. On Quest extreme morphs MAY facet — accepted known limit, not a gate failure.
9. **(a) Quest budget:** Quest tier (normal+roughness, SSS off, subdivision off/low) within the Mobile frame budget. **Gated on an XR/Mobile build existing — currently UNRUNNABLE; does not cover the Quest extreme-faceting limit.**
10. **(a) Sculpt mode + mirror-vs-resolution + acts on morphed surface:** the Sculpt toggle is a visible UI control; orbit works with no pick latency outside sculpt mode; in sculpt mode an up-drag at the breast handle increases volume picking against the morphed surface. Resolution: a bilateral arm/leg slider drives BOTH sides REGARDLESS of the mirror toggle (assert mirror ON and OFF). Mirror toggle: a one-sided edit applies to the twin when ON, only to the touched side when OFF; midline edits apply once.
11. **(a) Archetype within-default-interval + default-interval-contains-neutral BUILD GATE** (NET-NEW): **(11a)** load every shipped first-party archetype and assert every value lies within that control's default interval `cap(control, 0)` — fails the build otherwise (makes no-monster-by-DEFAULT true for archetype picks); **(11b)** assert `a ≤ neutral ≤ b` for EVERY control (not only archetype-present keys) — fails on a forbidden `[min>0, b0]` floor or a band that does not straddle its neutral (derived intervals satisfy it by construction). Both are objective numeric containment checks; USER taste enters only via #1b's interval sign-off.

---

## 9. VR — a named dependency, not folded into this feature

Zero XR code exists. VR delivery is a separate large workstream — OpenXR enablement + XR camera/origin rig + per-eye stereo + controller input + comfort/locomotion — gating the cross-platform parity commitment. **Out of this design's execution scope.**

This design only ensures the editing model degrades gracefully: the common path (pick → natural-unit nudge → mirror) is controller-native with no pointer assumption; the named region-handle table projects from one definition to flat gizmos AND future VR grab-volumes (honest status: zero rows + flat-only today). T3 sculpt is honestly flat-primary; the world-space drag decomposition is flagged as unfinished design work. Grab "feel," the world-space sculpt port, and the Quest render + subdivision tiers (including the accepted Quest extreme-faceting limit) are **hypotheses unvalidated until an XR build exists.**

---

## 10. Execution scope — FIRST BUILD vs DEFERRED

The guiding cut: ship the **editing model + the finalized bounds behavior + correct semantics + the read-side persistence wiring + the objective quality gates + the honest-fidelity Tier-A work**, and DEFER everything whose value is conditional, whose cost is a sub-decision, or whose verification can't run yet.

### 10.1 FIRST BUILD

- **The editing model:** archetype + progressive-refine tiers (T0–T3), the visible sculpt control (toggle + indicator, pick latency only in sculpt mode), mirror (resolution-always + contralateral toggle), mandatory numeric entry, reset, bounded seeded randomize.
- **Bounds — the finalized cap model (§4):** raw `modifiers` + one global `extremeness` + derived `cap(·) -> (a,b)` per-control allowed interval + the single `apply_capped` choke (one clamp) covering ALL live write paths (sculpt incl. uncurated modifiers via the DEFAULT CAP RULE, region slider, headline-field set, numeric, randomize) + the `set_value_no_signal` raw path at every restore/load; the emergent per-pole inward ratchet; the complete 4-step live-edit write-back protocol with the choke-capture, gesture-lifecycle-interruption, and shared-widget-display invariants; `apply_capped` reading `cur` as stored-or-neutral and WRAPPING the existing erase-at-neutral write, sound under the `neutral ∈ [a,b]` invariant; the versioned cap table (a NET-NEW asset, does not exist yet); conservative DEFAULT intervals (net-new authoring of ~56 + headline interval shapes in non-uniform units; the ~224 uncurated modifiers derived by rule, no per-modifier labor).
- **Two distinct load paths:** first-party archetype picks (within-default-interval, enforced by gate #11a) keep no-monster-by-DEFAULT for the pick-and-go majority; user saves/imports preserve RAW. The build gate #11 is net-new first-build work.
- **Belly / breast / region controls surfaced with correct semantics + labels (§3, §5):** the belly group over existing morphs (no asset), breast size via the live volume axis, the region sliders. UI + labeling over already-imported morphs; zero bake.
- **Persistence wiring — slice 1 (read side EXISTS):** Import button + FileDialog + drag-drop calling the existing parse functions; autosave/restore; the global extremeness in the save.
- **Camera (already landed):** face-front default + centered pivot + studio rig + Quest-preview toggle.
- **The objective quality gates (§8 (a)):** the rewritten no-monster check (#1, incl. the uncurated-sculpt-clamp assert and the path-agnostic transient-dip + mid-gesture-abort asserts), proxy-follow (#2), monotone breast sweep + dead-control assert (#3), persistence round-trip (#4), within-platform determinism (#5), committed-tangent validity (#7a), dihedral faceting metric (#8a), sculpt+mirror+morphed-surface (#10), archetype within-default-interval build assert (#11). **NET-NEW among these (not near-existing):** the dihedral metric (#8a), the N=10,000 sweep (#1b), the caps asset (#5/#1/#11 run against it), and the #11 archetype-containment assert. (#2 has a passing test, #4 has the existing read side.)
- **Default-cap conservative tuning (§4.4, §8 #1):** set + validate each per-control default cap reads as human-plus-stylized alone.
- **Glow / tongue / sculpt-on-morphed-mesh fixes (§6.6, §2.3):** glow outward offset (world-space ε + uniform-scale assert), sculpt picks/locality/glow refresh from the morphed surface (owner-driven). (The tongue fix is first-build; its cost is an asset re-bake.)
- **Skin Tier-A (§6.2):** detail-normal + roughness + albedo break-up + low SSS, + the §6.1 tangent-on-commit prerequisite (a hard dependency for any skin normal map).
- **Procedural iris look (§6.3):** improve the procedural shader + expose `iris_color`. NO `gaze_dir` wiring.
- **Brows/lashes alpha cards (§6.4)** and the **scoped render/UX cleanups (§6.7)** — small, unblock the fidelity floor.

**First-build → deferred dependency re-scan: CONFIRMED NONE.** Each first-build item was re-checked against the deferred list. The cap model's only new asset (`assets/body/caps*`) is itself first-build. Gate #1 no longer asserts self-intersection; gate #8 SHIPS the faceting metric and FLAGS faceting without depending on the deferred subdivision remedy; Tier-A does not depend on the deferred Tier-B baker. The build gate #11 depends only on the caps asset (first-build) and the first-party archetype roster. No first-build item depends on a deferred one.

### 10.2 DEFERRED (named, with why)

- **Combination-plausibility model (§4.4)** — *user decision: low priority.* Seam reserved (post-composition toggleable validity check); interim grotesque combinations accepted; the per-control caps do not bound combinations, and the first build owns that.
- **Skin Tier-B baked meso normal/AO (§6.2)** — *blocked on a baker sub-decision* (`bpy` vs in-Godot GPU bake); Tier A ships the bulk of the fix without it.
- **Subdivision setting implementation (§4.6)** — *deferred past the first build:* the cost form (bake-time geometry vs runtime quality tier) is a genuine sub-decision, and the independent dihedral metric can SHIP and FLAG faceting before the remedy exists. Extreme is reachable in the first build but may facet (and on Quest will, accepted limit) until subdivision lands.
- **Cornea parallax / refraction (§6.3)** — *net-new shader infra;* the core procedural iris delivers the look without it.
- **Per-eye gaze convergence / any `gaze_dir` work (§6.3)** — *deferred and currently UNNEEDED:* eyes already track via the bones; wiring `gaze_dir` would double-count.
- **VR / OpenXR workstream (§9)** — *separate large prerequisite, 0% built;* the editing model degrades gracefully and projects the handle table to future grab-volumes, but no XR code ships here.
- **Self-intersection CHECK, any form (§4.6)** — *deferred, monitoring-only* (NET-NEW feature work, no code today; built later as a nightly report). No first-build gate asserts it.
- **Caps-version revalidation slice (§7 slice 2)** — recording the caps version for replay determinism, sequenced AFTER the §4 cap table exists; little to defer (caps derived → no value-snap migration).
- **Opt-in hairstyle drape (§6.7)** — *standalone hair-geometry seating slice;* the default-cap hide is already fixed.

**Justification for the cut:** the first build delivers a complete, playable, no-monster-by-DEFAULT creator with correct semantics, honest fidelity (Tier A), and runnable objective gates — where "no-monster-by-DEFAULT" is precise: the default new character AND every first-party archetype pick are bounded (the latter by build gate #11), while a user's own deliberately-extreme creation reloads raw (by design). It defers (a) everything gated on an unmade decision (Tier-B baker, subdivision cost form), (b) everything gated on an unbuilt platform (VR/Quest verification), and (c) the combination-plausibility model the user explicitly down-prioritized. Each deferred item is named with its hook/seam so none is silently dropped.

---

## Provenance

This spec is the clean, changelog-free distillation of `docs/artifacts/design/creator-body/SYNTHESIS.md` (v16) — the single converged design across four parallel design-it-twice candidates, hardened against **fifteen rounds of adversarial attack** and adjudicated against verified ground truth (where attack and facts disagreed, the facts governed). The full hardening trail lives under `docs/artifacts/design/creator-body/`:

- **`SYNTHESIS.md`** — the converged design with its complete v1→v16 revision history and per-round attack-resolution commentary (stripped from this spec).
- **`attack-round1.md` … `attack-round15.md`** — the fifteen adversarial rounds. The core single-value cap formula (`hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)`) was re-derived by hand and held sound from round 9 onward; the later rounds attacked the held-interval WIRING (capture, lifecycle, display), producing the choke-capture / gesture-lifecycle-interruption / conservative-display invariants in §4.3, not a change to the formula.
- **`candidate-archetype-refine.md`, `candidate-constrained-parametric.md`, `candidate-direct-manipulation.md`, `candidate-fidelity-first.md`** — the four independent starting candidates.
- **`judge-editing-models.md`, `redteam-fidelity.md`, `new-defects.md`** — the adversarial judging.
- **`facts-round1.md`, `facts-round2.md`, `facts-belly.md`** — the verified ground truth (re-checked against live code at HEAD) that adjudicated disputed claims.

The verified-broken / verified-fixed claims this spec rests on (§1) trace to the diagnosis trail at **`docs/artifacts/diagnosis/`** — notably `creator-ux.md`, `body-render.md`, `body-visual-reverify.md`, `body-reverify.md`, `bdcc2-port-reverify.md`, and `hair-parts.md`, plus the reference render PNGs (`fp_view.png`, `tp_front.png`, `_face_3q_nohair.png`, `_body_with_hair.png`).

This is a DESIGN PASS governing first-build execution. It is **not a green promotion**: the bounds-mechanism gates are designed but unbuilt, and the user-taste-gated quality clauses (the iris look, skin-reads-as-skin, the per-control default-interval acceptance boundary, the belly "reads as paunch" call, drag-time tangent drift) await user sign-off. Green is user-granted, never agent-self-certified.
