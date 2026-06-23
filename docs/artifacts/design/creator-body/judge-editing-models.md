# Adversarial judge — creator/body EDITING MODEL (design-it-twice)

Date: 2026-06-23. Judging the EDITING MODEL only (the four candidates converge on
fidelity/bounds/semantics/persistence — those are settled and shared; do not re-litigate).
Verdict is about *how the user shapes the body*.

---

## The four editing models, attacked

### 1. Direct-manipulation-first (grab the body; sliders demoted)

- **Kill-shot input:** "I want my left forearm 8% thinner than my right, and an exact 172 cm
  height." Direct-manip is *worst* at precise, asymmetric, numeric targets — the two things a
  grab gesture cannot express. The candidate knows this and bolts on numeric fields + a Mirror
  toggle + named region handles + a full slider tree as fallback — i.e. it re-imports the
  *entire* parametric model as a "secondary surface." Once you do that, the headline claim
  ("grab is the verb") is half the system, not the system.
- **Hidden cost:** the region-handle layer is a whole second authored UI ontology (anchor verts,
  drag-axis hints, labels, billboards-vs-grab-volumes projection) on top of the slider table —
  *plus* you still keep the slider tree. Two surfaces to maintain, two to keep in sync with the
  registry. And the locality-decomposition math is the single most fragile part of the existing
  pipeline being promoted to the front door.
- **Structurally cannot do:** exact numeric depth and clean asymmetry without becoming the
  parametric model. Free drag-sculpt has *no labels* — it violates "controls mean what they say"
  by construction (you pull and hope the locality metric guessed the axis you meant). The TiTS
  long tail (291 modifiers) is unreachable by grab; it can only be reached through the
  fallback slider tree, so grab does not actually deliver depth — the demoted surface does.
- **VR note (its claimed strength):** genuinely strongest VR *gesture* story (reach-and-grab a
  handle is native). But it rests on ZERO existing XR code and the candidate's own §6.3/§9
  flag the controller-delta→value mapping as fully unvalidated. The strength is aspirational.

### 2. Constrained-parametric ("editing that just works")

- **Kill-shot input:** "Give me the heavy, very-curvy body" where waist + hips + belly + bust are
  all near max. The validity-envelope (mechanism A) makes each slider's *effective max shrink as
  siblings rise* — so the player drags the hips slider and **it stops moving with no obvious
  reason**. The candidate calls this "legible" (the track visibly shrinks), but a control whose
  range silently retracts because of *another* control is precisely the "controls don't mean what
  they say" defect it set out to kill, re-introduced as a feature. The envelope is the right idea
  for *bounds* (output clamp) but wrong as an *input-space* shrink.
- **Hidden cost:** the offline-derived region-budget constraint table (overlap sets from vertex
  footprints, per-region L1 budgets) is real tuning + derived-data infrastructure, and the
  numbers are admittedly placeholders. The frame also deliberately *caps depth* — "NO third tier
  in base creation," the 291-modifier long tail is post-creation only. That is a deliberate
  retreat from the TiTS bar.
- **Structurally cannot do:** TiTS-grade depth *in the creator*. Its thesis is curation =
  trust, and curation = a bounded set. It explicitly refuses the long tail up front. It can
  reach depth only by reopening the door it closed.
- **VR note:** strongest *parity* story — bounded sliders + wrist panel + a mirror degrade
  cleanly to VR with no precision-pointer assumption, and grab-as-bounded-nudge is VR-safe. No
  hidden mouse assumption. This is its real edge.

### 3. Fidelity-first (rendering-driven; editing serves the pipeline)

- **Kill-shot:** this isn't actually an editing model — it's a *rendering* design wearing an
  editing section (§3 is two paragraphs; the doc's own frame says "the controls serve" the
  pipeline). Asked "what is the entry gesture, how do I reach 291 modifiers, what's the panel
  taxonomy?" it answers with sliders+drag-sculpt+symmetry-on as a given and moves on. It cannot
  *win the editing-model contest* because it isn't competing in it.
- **Hidden cost:** as an editing model, none new — it inherits whatever you pick. Its costs
  (Blender-headless baker, Quest SSS split, tangent-rebake-under-morph) are fidelity costs and
  belong to the *separate* fidelity decision, not this one.
- **Structurally cannot do:** be the editing-model answer. BUT it owns the one thing the others
  underweight and is *correct* about: the **studio 3-point lighting rig + lighting-rotate +
  always-preview-top-tier + open-on-the-face**. Editing quality is unjudgeable under one raking
  directional light. This is a graft, not a winner.
- **VR note:** explicit, honest tier split (SSS off on Quest) — the only candidate that costs
  the cross-platform render budget out loud.

### 4. Archetype + progressive-refine (pick → nudge; sliders+sculpt = Tier 3)

- **Kill-shot input:** "I want a body unlike any of your ~18 archetypes" — a unique face, or a
  proportion combo no archetype seeds. The per-archetype envelope (§3.1: detail modifiers clamped
  to `A_value ± 0.35`) *traps you near the seed you picked*. The candidate's escape is an explicit
  "expand range" gesture in Tier 3 — so the power user is back to the unbounded slider/sculpt
  surface anyway. The envelope is a soft default, not a wall (good), but it means the depth path
  and the safety guarantee are **decoupled**: depth lives in T3 where §3.1 is off, and the real
  no-monster guarantee rests entirely on §3.2 (the cumulative-displacement bake guard).
- **Hidden cost:** the archetype content itself (~15–18 hand-authored, individually-good
  BodyStates + thumbnails) is *authoring* labor, recurring, not one-time code. And the "save as
  archetype / open library" loop is a second persistence surface. But these are cheap relative to
  the others' infra (no second UI ontology, no constraint-derivation pipeline, no baker).
- **Structurally cannot do:** *nothing* it claims — it explicitly keeps the full slider tree AND
  drag-sculpt as Tier 3, so it has full TiTS depth and the grab gesture *both*, behind doors.
  The only thing it sacrifices is "the long tail is the front door" — which is exactly the
  verified defect (wall of 56 sliders) it is trying to avoid. The sacrifice is the point.
- **VR note:** T0/T1 (pick archetype + nudge 6 natural-unit axes + mirror) is genuinely
  VR-first-class with no pointer assumption; it honestly relegates T3 sculpt to flat-primary and
  flags the world-space drag decomposition as real unfinished work. No secret mouse dependency in
  the *common* path.

---

## Root disagreement (the real decision)

The frames disagree at the root on **where the no-monster guarantee lives and who pays for it**:

- **Constrained-parametric:** at the **input**, visible — shrink the controls so a bad state is
  unreachable. Cost: controls stop meaning what they say (sibling-coupled ranges); depth capped.
- **Direct-manip / archetype / fidelity:** at the **output**, invisible — let the controls move
  freely, clamp the *composed displacement* in the bake (the per-region / per-vertex cumulative
  cap that *all four* actually specify). Cost: a control near the cap "does less" silently — but
  only at the extreme, not across the normal range.

That is THE call: **input-space legible shrink vs output-space bake clamp.** The output-space
clamp wins — it is the only one of the two that satisfies BOTH hard requirements at once
("no monsters" AND "controls mean what they say across their working range"), and notably
*every* candidate already specifies it as the backstop. The input-space shrink is a net-negative
addition on top of a clamp that already does the job.

A secondary root split — **entry gesture: grab-the-body vs pick-an-archetype** — resolves to:
both are *additive front doors over the same BodyState/registry substrate*, so they are not
mutually exclusive. You can have archetype-pick as the opener AND grab-sculpt as a tier. They
only conflict if forced to be *the* verb. Don't force it.

---

## Verdict: ARCHETYPE + PROGRESSIVE-REFINE survives best

Why it survives the attack where the others don't:

1. **It is the only model that hits the TiTS depth bar without the wall.** It *keeps* the 291-
   modifier registry tree and drag-sculpt verbatim as Tier 3 — full depth — but relocates them
   behind a door so the common path is pick + nudge. Constrained-parametric *refuses* the long
   tail; direct-manip can only reach it via a fallback that contradicts its thesis. Archetype
   keeps everything and just reorders the disclosure. Nothing is thrown away (its strongest
   property: additive, monotone tiers — opening T3 hides nothing).
2. **Its no-monster guarantee is at the honest layer.** §3.2 (cumulative-displacement bake guard)
   protects *every* path — sliders, sculpt, archetype, randomize, blend, future runtime overlays
   — which is exactly where the guarantee belongs (it's a substrate invariant, not a UI clamp).
   And §3.1 (per-archetype soft envelope) gives the *common-path* "stay near a good body"
   default without lying about control ranges, because it's a soft default with an explicit
   escape, not a permanent silent shrink.
3. **It directly kills the verified UX defects** rather than working around them: the wall of 56
   sliders becomes Tier 3 (not the entry); randomize-within-validity replaces a chaos button;
   archetype-first turns the 1s load freeze into "browse the grid while the body builds."
4. **VR degrades gracefully without a secret pointer dependency** in the common path (pick +
   natural-unit nudge + mirror is controller-native); it is honest that T3 sculpt is
   flat-primary and the VR world-space decomposition is unfinished — rather than overpromising.
5. **Lowest net infra risk on the existing pipeline:** an archetype is just a frozen BodyState
   (data-over-code at a faithful seam, per CLAUDE.md); no second UI ontology (vs direct-manip's
   handle layer), no constraint-derivation pipeline as a hard dependency (vs parametric's
   budget table), no baker (that's the fidelity decision). The recurring cost is *content
   authoring*, which is cheaper and lower-risk than recurring *infrastructure*.

The honest weakness it must own: the ~18 archetypes are recurring authoring labor, and the
quality of the whole common path is hostage to that set being individually good. Mitigated by
the open "save as archetype" library (first-party set is just the seed).

---

## Grafts to steal onto the winner (the synthesis)

The winner is a hybrid. Take:

- **From direct-manip:** keep **always-on grab as the Tier-3 sculpt verb** (no mode toggle, hit-
  test disambiguation) — its single best idea, and it kills the "hidden mode keybind" defect
  outright. Also steal the **named region handles as the VR grab affordance** (one data table →
  flat gizmos + VR grab volumes): this is the cleanest VR-native precision gesture and it is the
  *bridge* the archetype frame is missing between "grab" and "labeled control." And steal
  **mirror-default-ON via the registry `l-/r-` pairs** for the sculpt path (archetype frame
  underspecifies sculpt symmetry).
- **From constrained-parametric:** steal the **per-region cumulative cap as the bake backstop**
  (its mechanism B), and steal **mandatory numeric entry + display remap to ±100/0–100 on every
  axis** (the archetype frame's nudge sliders need exact entry to hit "172 cm"; this fixes the
  verified no-numeric-entry defect). Do NOT steal mechanism A (input-space range shrink) — that's
  the part that breaks "controls mean what they say." Also steal **content-hashing the bounds
  table into the save** so an old save is re-validated/snapped on load, never silently broken.
- **From fidelity-first:** steal the **studio 3-point lighting rig + lighting-rotate +
  always-preview-at-top-tier + open-on-the-face** — editing is unjudgeable under bad light, and
  the archetype grid in particular is judged on thumbnail quality. Also adopt its **honest
  explicit Quest tier split** as the cross-platform posture.

Net synthesis: **archetype-pick → natural-unit nudge (with numeric entry) → curated detail →
full registry tree + always-on grab-sculpt**, all over one BodyState; bounds enforced by an
output-space cumulative bake clamp (never input-space shrink); region handles as the shared
flat-gizmo/VR-grab affordance; studio lighting + face-first preview as the quality frame.
