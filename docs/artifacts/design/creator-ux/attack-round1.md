# Attack — Round 1: adversarial UX/taste review of creator-ux/SYNTHESIS.md

Status: **HOSTILE REVIEW. No pass verdict. Findings only.** Each is grounded in the
design text, the affordance model it cites, and the actual aeriea code it must run
against. Ranked BLOCKER / MAJOR / MINOR. I did not bless anything.

What I read in full: SYNTHESIS.md; affordance-surfaces / -opacity / -types /
interaction-graph (rhizone); editor-interaction / projection-model (unshape);
character_creator.gd (first ~1058 lines + targeted greps), region_sliders.gd (full),
body_caps.gd (full), body_state.gd (height/masculinity sections), the archetype roster,
the eye shader params.

---

## BLOCKER

### B1. The central worked example (`Face › Jaw › jaw width / jaw drop / chin`) does not exist in the data, and the design forbids itself from building it.

The whole "active-surface rule" is sold on a face sub-region tree:
- §1.1: "sub-regions under face (*jaw, nose, cheeks, brow, lips, eyes, …*)".
- §2 / §4.3: "Selecting 'face' shows its sub-regions (jaw, nose, cheeks, brow, lips,
  eyes) — each a navigational edge; selecting 'jaw' shows the jaw's ≤7 value-nodes."
- The ASCII screen (§4) and the breadcrumb (`‹ Face › Jaw`) are built around it.
- The history example "wider jaw" (§5) and the modality example (§3.1 `jaw → chin →
  cheek` radial flick) all depend on it.

In the actual code there is **no sub-region tree at all**. `region_sliders.gd` has
**10** flat groups (the design says "11"), and the face is a *single flat group*
"Head & face shape" with **12** sliders — face width, face height, face depth, face
fullness, face age, five head-shape unipolars (oval/round/square/rectangular/
triangular), jaw drop, nose size. There is no "Jaw" node, no "Nose" node, no
"Cheeks/Brow/Lips/Eyes" node. `grep` for `sub_region` / `child_region` in
`scripts/body/` returns nothing.

The registry *has* the raw modifiers (cheek/chin/jaw/brow/mouth/nose families, both
sides), but `RegionSliders.GROUPS` exposes essentially none of the face detail as a
navigable structure — and `RegionSliders.count()` is **56** flat axes with zero
hierarchy depth beyond the one group level.

And §0/§Scope explicitly says the design "does **not** redesign... the archetype data
format" and treats `region_sliders.gd`'s 11 (sic) groups as "already exist as
navigable graph nodes." They do not exist as navigable graph nodes — they exist as a
flat 2-level list. The design's load-bearing example is a fiction, and the design has
fenced off the very data work that would make it real. This is the #1 defect: the
prettiest part of the projection (drill Face → Jaw → ≤7 values) is undeliverable
against the substrate the design pins itself to.

**Why blocker, not major:** the "≤7 by removal-via-locality, Miller-compliant at every
level" claim (§2 coarse locality) is *entirely* carried by the face tree. Without it,
"Head & face shape" is a 12-item flat surface — over Miller, a wall to hunt through —
and the design has no mechanism to chunk it because it disclaimed building the tree.
The active-surface rule fails its headline case on contact with the code.

### B2. Height "morph + cm" leans on a build fix that the code deliberately rejects.

§6.6: "Height is a value-node... drag + a numeric field reading cm... The design
assumes the build fix that makes height a **real height morph plus a true cm field**
(not a uniform scale)."

`body_state.gd` (lines 93–100, 262–270) is explicit: aeriea **deliberately** makes
height a uniform scale. The comment literally says MakeHuman's height "is NOT a pure
scale there; aeriea deliberately deviates — `height_cm` does [scale]... the
fully-morphed mesh is scaled by `height_cm / base_height_cm` about the foot origin...
So proportions change shape at fixed stature; height changes stature at fixed shape."
`height_scale()` returns the scalar; `BodyRig` multiplies the mesh.

There is no pending "real height morph" build fix — the uniform scale is the *chosen
design*, recorded with a rationale (orthogonality to proportions). The design's §6.6
asserts a fix that contradicts a decided architecture. Either the design is wrong about
the substrate, or it is silently proposing to reverse a deliberate body-mechanics
decision under the guise of "assumes the build fix" — which §0 says it does NOT do
("does not redesign... the morph pipeline"). Self-contradiction against the very
decision doc it claims to project. This must be resolved before the height node can be
specified at all: is height drag a *scale* drag or a *morph* drag? The two have
different feel, different cap semantics, and different history labels.

---

## MAJOR

### M1. The "command rail" is the old corner-scatter wall, renamed.

The design's own §0 indictment of the shipped creator is "Five panels in five corners."
The fix (§4.2) invents a **command rail** that holds, by its own enumeration:
Start-from (archetype gallery + Randomize), the pinned whole-body axes "when nothing is
focused," Looks (hair / eye color / clothing), Realism (the limits range), Saved
(presets / saved characters / Save / Share / Open). That is **5 top-level groups, each a
nested junk-drawer**, plus it *duplicates* the pinned strip's contents ("the pinned
whole-body axes also surface here when nothing is focused"). The doc even claims it is
"chunked into ≤7 visible groups" — but lists exactly the heterogeneous mix
(navigation + commands + data-entry + lists) that `affordance-types.md` says must NOT
share one uniform surface ("Menus full of gestural affordances are confusing";
"designing a single affordance surface that tries to present all types uniformly" is
"the mistake").

This is the ribbon failure mode the cited doc warns about: a permanent side panel that
shows "everything available" (start, looks, realism, saved, randomize) regardless of
what the user is doing. It is a left-hand wall facing a right-hand wall (the contextual
dock). "Body foregrounded" (§4.1) is contradicted by the screen diagram itself, which
sandwiches the body between two persistent full-height panels. The corner-scatter was
not removed; it was consolidated into two opposing slabs.

### M2. "Realism" as a user-facing label is itself jargon — the design bans dev-words then ships a new abstract one.

§6.4 / §6.5 rename `extremeness` to **Realism** ("Stay realistic ⟷ Allow anything").
"Realism" is not a thing a player *wants to set*; it is a developer's name for "how far
I let you push the caps." A player does not think "I want 40% realism." The pole labels
("Stay realistic" / "Allow anything") are better than the noun, but the design also
proposes "Realistic / Stylized / Anything" as a three-stop — "Stylized" is art-pipeline
jargon, and the noun **"Realism"** appears as the rail group label (§4.2 "Realism → the
limits range") and in the pinned strip (`[realism]` in the §4 diagram, and §4.4 "the
realism state"). The §7 quality bar even lists "Realism" as a *banned-vocabulary
companion grep target* in one breath and as the shipped control name in another. That
is an internal contradiction: the design bans abstract dev-nouns and then makes one its
flagship new control. A player-legible framing would attach the loosening to the act
("let me push past lifelike") at the value, not hoist a global noun onto the rail.

### M3. The radial / sibling-flick is a gimmick with no substrate and an unsolved mapping — performative.

§3 lists "Radial / sibling flick (directional) — from a focused value, flick to a
sibling value in the same region (jaw → chin → cheek)." §8 OPEN then admits "its exact
membership (which siblings, in which directions) wants playtesting... the mapping must
be stable and motivated, not arbitrary." So the design ships a modality whose entire
value (Fitts-optimal, direction-memorable) depends on a stable semantic direction map
that it has not designed and cannot, because (see B1) the sibling structure
(jaw/chin/cheek as distinct nodes) **does not exist in the data**. A radial over an
undesigned, nonexistent sibling set is exactly the "radial menu for arbitrary command
sets where direction carries no meaning" that `affordance-surfaces.md` calls "the wrong
surface." This is a new instance of the old performative-control failure: a clever
affordance present to be present. Cut it or design the sibling graph first; do not list
it as a co-present modality on "every value node" (§3) when most value nodes have no
motivated siblings.

### M4. "compare-variants" / "vary-per-feature" / "promote-in-place" are shipped as value-node affordances nobody in this creator asked for — the unshape principles imported wholesale.

§3.1 makes promote-in-place, compare-variants, and vary-per-feature "first-class
value-node affordances, surfaced *on the node*." These are unshape's editor principles
(a procedural node-graph DAW/3D tool). Their fit to a character creator is asserted, not
shown:
- **compare-variants** "audition N values of a node side by side, live, pick one" —
  for a single scalar like "jaw drop," N side-by-side live thumbnails of one slider is
  busywork; the live body already shows the value as you scrub. The design even
  conflates it with history branches ("the history *branches* are this made durable"),
  which means it is not actually a new affordance — it is re-describing undo branches as
  a feature, the performative-naming smell.
- **vary-per-feature** is defined as "asymmetry: edit one side without breaking the
  mirror" — i.e. it is literally the existing mirror-OFF behavior (`_mirror = false` in
  `character_creator.gd`) relabeled as a "local override." Shipping the existing toggle
  under a new unshape-borrowed name adds a concept, not a capability.
- **promote-in-place** "vary this / drive this from the archetype / link to mirror twin"
  — "drive this from the archetype" and "blend-toward-archetype on a value" describe
  per-value archetype blending that does not exist in the code (archetypes are
  whole-body picks via raw restore — `_build_archetype_grid`, `_apply_imported`) and is
  a substantial new system, surfaced here as one breezy "in-place gesture."

The design imported a sister-tool's vocabulary as if it were settled creator
requirements. That is the same category error as the old tier-selector: features that
exist because the model has a slot for them, not because a creator user needs them.
At minimum these need a design pass of their own with a concrete creator use; as written
they are option-dumping.

### M5. Randomize "never an androgynous mush" is falsified by the shipped roster.

§6.3: randomize "lands on a coherent gender presentation... samples a first-party
archetype as the seed and walks within the realistic range, so the result is a plausible
person of a definite presentation, **never an intermediate androgynous mush.**"

The first-party roster (`assets/body/archetypes/`) is 7 files, and **two are explicitly
androgynous**: `androgynous-athletic.json` (`masculinity: 50.0`) and
`androgynous-average.json` (`masculinity: 52.0`). If randomize samples a first-party
archetype as the seed, ~2/7 of the time it seeds on a deliberately androgynous body and
walks from there — i.e. it *will* produce the "intermediate androgynous" result the
design promises it never will. The design's stated behavior contradicts the data it
says it samples. (Separately: the user's actual ask was "sensible-gender randomize"; the
design has not decided whether androgynous-by-design archetypes are in or out of the
randomize seed pool — a real, unresolved gender-naming/behavior question dressed up as
settled.)

### M6. The focus-based orbit-vs-reshape disambiguation will mis-trigger constantly.

§2.1 replaces the sculpt-mode toggle with: "Drag on empty space → orbit. Drag on a
region you have focused → reshape. Drag on an unfocused region → focus it (navigational),
then subsequent drags reshape."

This is *less* usable than the toggle it replaces, not more:
1. **The first drag on any region you want to edit is silently stolen as a "focus"
   navigation** — the user pulls to reshape the belly, the belly doesn't reshape (it
   just focuses), the user pulls again. Every region switch eats a gesture. That is the
   "actions do unexpected things because you're in the wrong state" failure
   (`interaction-graph.md` Modal confusion) — except now the "mode" is per-region focus
   the user can't see at a glance.
2. **A drag that starts on the focused region but the user wanted to orbit** (very
   common — you reshape the jaw, then want to rotate to check the profile, and your
   cursor is still over the head) now reshapes instead of orbiting. The old scheme had a
   clean rule (hit body = morph, miss = orbit) gated by an explicit visible mode. The new
   scheme makes "is this drag an edit or a camera move?" depend on invisible focus state
   AND pointer-over-which-region, with no single readable indicator. The design claims
   this removes a mode "the user must remember they are in" — but it replaces one
   visible global mode with N invisible per-region modes. That is strictly worse for
   modal clarity.
3. There is no answer for **drag on the focused region when you wanted to focus a
   different region** — you must first click empty space or another region to defocus,
   then re-aim. The design gives no defocus affordance.

The old `_sculpt_mode` toggle (a visible button + cursor change to CURSOR_CROSS +
live state label, per `character_creator.gd:745`) is actually a *legible* disambiguation.
The replacement trades a clear, learnable mode for clever-but-confusing implicit state.
This is "an interaction that sounds clever but would frustrate."

### M7. "Locality silently degrades to show-everything" at the top level and the no-focus state.

The active-surface rule (§2) is "the focused node's value-nodes + child-region-nodes,
and nothing else." But:
- **At the root / no-focus state**, §4.3 says the dock shows a one-line hint, and §4.2
  says the pinned whole-body axes "also surface here when nothing is focused" — *on the
  command rail*. So before you focus anything, the user faces: the command rail (5
  groups), the pinned strip (gender/age/height/build/realism = 5), and a hint. The
  "≤7 emerges from locality" promise does not cover the entry screen, which is where a
  new user *starts* and where scannability matters most. The design never counts the
  entry-screen surface against Miller.
- **The whole-body strip is 5 items that are never subject to the contextual rule**
  (§2.4) AND they are duplicated on the rail (§4.2). Persistent 5 + a 5-group rail +
  whatever the dock shows means the *total simultaneous* affordance count routinely
  exceeds 7 even when each sub-surface is individually ≤7 — exactly the ribbon failure
  `affordance-surfaces.md` names: "You see 6 groups × 8 commands... The chunking is
  structural but not perceptual." The design's §7 quality bar only checks "the
  contextual dock shows ≤~7" — it carefully scopes the count to one sub-surface and
  never to the composed screen, which is where the wall actually is.

### M8. Breast "Cup size" is specified as a control that will not change size until an undelivered import lands.

§6.2 admits the shipped "height/lift" axis is not size, then says "this UX assumes the
build fix lands" and "until the cube is imported the node binds the genuine size axes
already present (fullness / bust circumference, projection)." But `region_sliders.gd`
already exposes "fullness" (bust circ) and "projection" as *separate* sliders. So §6.2's
interim plan is to relabel two existing axes as a single "Cup size" node reading in
cup terms ("A...D...DD"). Binding a single cup-letter scale to two underlying axes
(circumference + point) with no defined mapping is hand-wavy: what is "cup D" in terms
of fullness+projection? The decision doc *defers* the cube; the design says "stop
deferring it" (§6.2) — i.e. the design's own honest position is that without the
deferred work, "Cup size" is a fake. Shipping a cup-letter readout over a redistribution
proxy is precisely the "size slider that doesn't change size" the code's own Phase-3a
guard (`region_sliders.gd:42–49`) refused. The design re-opens that exact footgun under
a friendlier label.

---

## MINOR

### m1. Region-group count is wrong (11 vs 10) — and the discrepancy hides a real gap.

§1.1 and §2 both say "11 groups in `region_sliders.gd`." There are **10**
(Breasts, Glutes & pelvis, Belly & stomach, Waist & hips, Torso & shoulders, Arms, Legs,
Neck, Head & face shape, Fine detail). Minor as a number, but it signals the design was
written against a remembered/assumed structure rather than the current file — which is
the root of B1. "Fine detail" is also a power-user catch-all group the design never
addresses (where does it live in the region tree? it has no body locus name).

### m2. Iris-round "build fix" describes a defect that may not exist.

§6.7 "assumes the build fix that makes the iris/pupil round." `body_rig.gd:44–52` ships
`EYE_PARAMS_DEFAULT` with `pupil_aspect: 1.0` ("1.0 round (human)") and an analytic
procedural eye shader. The iris/pupil are parameterised round by default. If there is a
real "iris not round" rendering defect it is not in these params, and the design cites
no verified observation of it (unlike its §0 defects, which it calls "verified"). This
is an unearned-confidence assertion: a "build fix assumed" for a defect not shown to be
present. Verify the actual render before specifying a fix-dependent node.

### m3. "Share/Open symmetry" understates the asymmetry the code actually has.

§6.1 promises one Share / one Open, format as a detail inside Share. Fine as intent, but
the shipped `_image_format` state + the multi-format export path (`creator_io.gd`,
ImageMetadata FORMAT_* keys) means "the format is a detail inside the one action,
defaulting to image" still requires a format chooser *somewhere* inside Share — the
design says "a small choice within Share" without deciding whether that's a submenu, a
long-press, or a settings default. For a save action that should be one click, an
undecided nested chooser is a latent re-scatter. Decide it.

### m4. "Promote-in-place... openable but never the primary surface" imports a graph view that does not exist here.

§3.1 / projection-model's promote-in-place assumes there is a node/graph view to
"open into" behind the projection. The creator has no node graph — it has BodyState +
modifiers + a history tree. "The relationship forms behind you, openable" has nothing to
open into. The phrase is copied from unshape without grounding in the creator's actual
state model.

### m5. The palette/search escape hatch (§4.5) reaches "any value or command by name" — but value *names* are the thing the design is trying to keep out of the user's face.

If history must read "wider jaw" (not modifier-space) and the dock shows human pole
labels, then a by-name search must index... what? The human display names
("jaw drop", "face width") are fine, but the search promise "reach any value by name"
re-exposes the full 56-axis flat namespace as a searchable list — i.e. the wall, one
keystroke away. That is acceptable as an escape hatch *if* it is genuinely rare, but the
design simultaneously leans on it to cover the cases locality can't (the no-tree face,
B1). A palette that is load-bearing for normal face editing is "command palette as
primary navigation" — the pathological case `affordance-surfaces.md` names.

---

## Faked-openness check (the one thing the design got right — stated for completeness)

§2.3 and §8 honestly refuse to ship a cold-start frecency ranker, scope it to
"locality + pinning + within-set recency only," and cite the model's own OPEN flag. This
is the *one* place the design does not fake relevance. I tried to break it and could
not: it does not sneak a ranker in elsewhere (the rail order is authored, the dock order
is region order, recency is scoped to "within an already-narrowed set"). Credit where
due — but this does not redeem the rest.

---

## Summary of unresolved user defects (design treatment: real vs hand-wavy)

| User defect | Design treatment | Verdict |
|---|---|---|
| Kill tier-toggle, no hidden replacement | Active-surface rule via locality | **Hand-wavy** — relies on a face tree that doesn't exist (B1); degrades to show-everything at root (M7) |
| De-jargon | Renames table (§6.5) | **Partial** — introduces "Realism"/"Stylized" (M2) |
| Panels not overlapping / body foregrounded | Two stable regions + rail | **Failed** — rail is two-wall re-scatter (M1, M7) |
| History collapse + human labels | §5 coalesce + display names | **Real** (the one clean win besides openness) |
| Gender naming | "Gender presentation", identity separate | **Real naming**, but randomize gender behavior contradicts roster (M5) |
| Breast SIZE real | §6.2 cup node | **Hand-wavy** — fake until deferred cube lands (M8) |
| Height morph + cm | §6.6 | **Infeasible** — contradicts deliberate uniform-scale decision (B2) |
| Randomize instant + sensible gender | §6.3 | **Partly false** — androgynous archetypes in seed pool (M5) |
| Round iris | §6.7 | **Unverified** — assumes a defect not shown present (m2) |
| Export/import simple | §6.1 | **Mostly real**, nested-chooser undecided (m3) |

---

## Verdict

Do **not** proceed on this design as written. The headline interaction (drill into a
region tree to keep every surface ≤7) is built on a face sub-region tree that does not
exist and that the design has fenced itself off from building (B1); the height node
contradicts a deliberate body-mechanics decision (B2); the "command rail" reintroduces
the corner-scatter wall it claims to kill (M1); and several first-class affordances
(radial flick, compare-variants/vary-per-feature/promote-in-place) are sister-tool
vocabulary imported without a creator use, i.e. the same performative-slop pattern as
the tier selector the design set out to remove (M3, M4). The model is cited faithfully
in prose but applied unfaithfully where the substrate resists it.
