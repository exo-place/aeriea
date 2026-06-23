# Character Creator UX — a projection over a typed interaction graph (v4)

Status: **DESIGN PASS — design artifact only, no code, not a green promotion.** v4 folds the one
MINOR (m3) from `attack-round3.md` (a hostile review of v3 that returned no BLOCKER / no MAJOR): the
Cheeks-node binding sentence in §1.4 is corrected to state that pairing the `cheek/*` family needs a
small prefix-generalization build task (not "no new code via `resolve_full_names`"), and the
"Build / Body softness" naming-table entry is resolved to one user-facing label (**Build**). v3
folded every finding in `attack-round2.md`; v2 hardened v1 against `attack-round1.md`. Every BLOCKER
and MAJOR across all rounds is addressed by *changing the design to fit the substrate* (and, where
the fix needs net-new build work, saying so plainly and putting it in scope), not by hand-waving. The
honest OPEN section is kept; the one thing v1 got right (refusing a cold-start relevance ranker) is
kept. Everything here is reopenable. It governs the *UX / interaction shape* of the creator; the
body/cap **mechanics** are decided in `docs/decisions/character-creator-and-body.md` and are the
substrate this UX projects.

**v3 → v4 changes (round-3 fix):**
- **m3 (MINOR):** §1.4's Cheeks node claimed the `cheek/*` family binds "via the existing
  `resolve_full_names` … no new modifiers." That function (`region_sliders.gd:156–165`) only pairs
  *bare* `l-` stems under a hardcoded `BILATERAL_PREFIX := "armslegs/"` and cannot reach the
  `/`-prefixed `cheek/` family. Corrected: pairing the cheeks requires generalizing that hardcoded
  prefix — a small grouping-table + one-constant code change (no new morph targets); `twin()` already
  does generic `l-`↔`r-` flipping, so the capability is nearby.
- **string cleanup:** the §6.5 naming-table entry for `weight` is resolved from two labels
  ("Build (macro) / Body softness") to one user-facing label, **Build** (light ⟷ heavy).

**v2 → v3 changes (round-2 fixes):**
- **M-A (MAJOR):** Muscle and Proportions were renamed in §6.5 but placed nowhere. The pinned
  whole-body cluster is now the **full set of 6 body-wide dials** — gender, age, height,
  build/weight, **muscle**, **proportions** — a coherent scannable whole-body group. §1.1, §2,
  §4.4, §4.5 updated so nothing is orphaned and the recount holds.
- **m1:** slider count corrected to **58** (the GROUPS table sums to 58), everywhere it appeared.
- **m2:** "Skull & cheeks" now actually maps the registry's `cheek/*` family, so name ↔ content
  is honest.
- **m3:** the limits opt-in is renamed **"Allow beyond-human extremes"** to clear the collision
  with the "Proportions" axis name.
- **m4:** the randomize within-bucket walk is now **bounded away from the androgynous midline**
  (the masculinity excursion is clamped inside the bucket); the bound is stated.
- **m5:** grab-handle **hit tolerance is specified** (screen-space pick radius + grab-latches-to-
  reshape-until-release hysteresis).
- **m6:** the cup-size commitment now states plainly that it **overturns BOTH** decision §187
  ("drive size via volume axis") **AND** the shipped `region_sliders.gd:42–50` guard — not merely
  "revisits a deferral."

Scope: the player-facing interaction model for the creator — the interaction-graph model for body
editing; the rule that decides what is on screen (replacing the manual detail-tier selector); a
**navigable region tree** that makes that rule real (net-new grouping work, §1.4, in scope); a
**body-foregrounded layout** with no side-wall scatter (§4); the plural per-value modality; an
**unambiguous on-body reshape affordance** (§3.2); de-jargoned naming (§6.5); a plain-language
limits framing (§6.4); coherent randomize (§6.3); and per-feature handling (export / import /
history / randomize / height / breast size / iris).

**In scope as build work this design now commits to (was fenced off in v1):**
- The **region tree** (§1.4) — re-grouping the existing flat `region_sliders.gd` groups + headline
  axes into a navigable ≤7-per-level tree. This is a data/grouping change, not a morph-pipeline
  change.
- The **cup-size axis import** (§6.2) — importing + binding the genuine cup cube, replacing the
  honest-but-not-size volume axis the decision doc currently ships. This **revisits a deferral** in
  the decision doc and is flagged as such.

**Explicitly out of scope / flagged-not-claimed (v1 over-claimed these):**
- Reversing the deliberate **uniform-scale height** decision is NOT silently assumed; §6.6 picks
  option (b) and flags the architecture revisit if (a) is ever wanted.
- An **iris-round "fix"** is NOT claimed — the shader already ships `pupil_aspect 1.0` (round). §6.7
  records the user's *observation* of a non-round iris as a render discrepancy to VERIFY in build.
- No cap-model / morph-pipeline / archetype-data-format redesign; no VR workstream.

Cross-links (the source-of-truth model — read in full, not paraphrased):
- rhizone: [Affordance Surfaces](https://rhi.zone/affordance-surfaces), [Affordance Types](https://rhi.zone/affordance-types), [Affordance Opacity](https://rhi.zone/affordance-opacity), [Interaction Graph](https://rhi.zone/interaction-graph) (`~/git/rhizone/github-io/docs/`)
- unshape: `editor-interaction.md`, `projection-model.md` (`~/git/rhizone/unshape/docs/design/`)
- aeriea: `docs/decisions/character-creator-and-body.md` (the body/cap mechanics this projects), `scripts/body/character_creator.gd`, `region_sliders.gd`, `body_caps.gd`, `body_state.gd`, `assets/body/caps.v1.json`, `assets/body/archetypes/`

---

## 0. What was wrong, named plainly

The shipped creator violated the affordance model wholesale. The defects this design fixes (each a
verified observation, not a guess):

- **A manual `T1 / T2 / T3` detail-tier selector.** The user *picks how much detail to see* —
  performative; "tier" is dev jargon for "amount of stuff." The active surface must **emerge from
  locality**, never from a toggle.
- **Dev jargon on the player surface.** `masculinity`, `extremeness`, `T1 — headline`, "registry
  tree", `proportions: uncommon↔idealized`, history nodes reading `age_years = 25` and
  `sculpt: nose-hump +0.20`. Code labels leaked into the UI.
- **Scattered, overlapping corner panels.** Main slider panel top-left, region sliders top-right,
  undo/redo top-right (colliding), history bottom-left, legend bottom-right, plus an always-present
  empty "detail sliders" box. Five panels in five corners; none foregrounding the body.
- **Export = a format dropdown + four buttons; import = one button.** Asymmetric, overweight.
- **History as a raw edit log** — one node per settled change, no collapsing, modifier-space labels.
- **Lists faked as panels** — the archetype roster as a 2-column button grid capped by screen space.
- **Modality treated as singular** — `Sculpt mode` as a *mode toggle* gating drag.

The root error: **the creator was built as a set of control panels, not as a projection of an
interaction graph.** This design replaces the panels with a projection.

---

## 1. The interaction-graph model for body editing

Per the source model: *every affordance is a typed edge in a graph; a frontend is a projection of
that graph; the load-bearing metric is keeping the active slice scannable (glance-and-act, ≤~7),
achieved by **removal via locality**, plus chunking and stable pinning — never by a manual control
and never by a magic count.* (`interaction-graph.md`, `affordance-surfaces.md`.)

### 1.1 Nodes

Two node kinds; the distinction is the spine of the layout (§4):

- **Region nodes** — body parts you can point at, *organized as a navigable tree* (§1.4): Body →
  Face → {Jaw & chin, Mouth, Nose, Eyes & brow, Skull, Cheeks, Face shape}; Body → Torso → {Chest &
  breasts, Belly, Waist & hips, Back & shoulders}; Arms; Legs; Neck. A region node's outgoing edges
  are its value-nodes + its child regions. **This tree does not exist in the code today** (the file
  has 10 flat groups, the face is one flat 12-item group); building it is in-scope work, §1.4.
- **Value nodes** — one per editable parameter (the 58 region sliders, the headline axes, eye color,
  the limits control). A value node has a stable identity, a human name, a current value, an allowed
  range (from the cap model), and a **set of co-present modalities** (§3).

Non-spatial value-nodes have **no region locus**. They split into two clusters, each with an
explicit home (§4.4), not a side wall:
- **The six whole-body dials** — gender presentation, age, height, build/weight, **muscle**,
  **proportions** — the body-wide macro axes from `body_state.gd:61–100`. These are the pinned
  whole-body strip (§4.4). (The M-A fix: v2 renamed muscle and proportions in §6.5 but pinned only
  four dials and placed these two nowhere — they are now first-class members of the pinned cluster.)
- **The rest** — eye color (routed to the region tree, *Eyes & brow*, §6.7), the limits control
  (surfaces at the value it gates, §6.4), presets/archetypes (the Create-menu gallery, §4.2).

### 1.2 Edges, typed (the affordance taxonomy applied)

Per `affordance-types.md`, edges are typed, and the type decides *how it renders and is discovered*:

| Edge type | In the creator | Rendered as |
|---|---|---|
| **Gestural** | grab a region's handle on the body to reshape it | a visible grab-handle on the *focused* region (§3.2) + cursor change |
| **Data-entry** | set a value (a two-way binding) | inline slider + numeric field on the value node, co-equal |
| **Directional** | nudge a value up/down | scroll / arrow on a focused value |
| **Navigational** | enter a region / child region; open a gallery; toggle history | selecting a region; a gallery overlay; breadcrumb back |
| **Command** | randomize, reset, mirror, share, open, save-as-preset | labeled buttons in the top bar / contextual dock, keybind inline |
| **Ambient** | current value readout, cap marker, the focus outline, the "beyond-human" tick | always-visible indicators; no action, just signal |

A value is **not** a slider — a value is a node, and a slider is *one* of its rendered modalities,
alongside the on-body grab, the directional nudge, and the numeric field that touch the same node.
The old code conflated "value" with "HSlider," which is why modality looked singular.

Per `affordance-types.md` §"Different surfaces render different types": **a canvas renders gestural,
directional, and ambient affordances; commands appear as an overlay, not inline.** The body *is* the
canvas — this is the direct mandate for §4's body-foregrounded layout and the rejection of two
command-bearing side walls.

### 1.3 Manipulate generative parameters, not baked vertices

The on-body grab decomposes the screen gesture into named **modifier** deltas
(`MorphDrag.decompose_drag` → `{full_name: delta}`) — *manipulate generative parameters, not baked
output* (`projection-model.md`). It drives the same `BodyState.modifiers` the sliders drive, so the
on-body grab and the slider are two modalities **projecting the same node**. Invariants (rig
re-solve, UV preservation, normal/tangent rebake) are owned by the tool and never appear as user
controls (mechanics in decision §6.1).

### 1.4 The region tree (NET-NEW BUILD WORK — this is the B1 fix)

v1's headline example (`Face › Jaw › jaw width / jaw drop / chin`) was a fiction: `region_sliders.gd`
has **10** flat groups, the face is a *single* flat group "Head & face shape" with **12** sliders,
and there is no sub-region structure (`grep sub_region scripts/body/` → nothing). The active-surface
rule (§2) is hollow without a tree to navigate, and "Head & face shape" at 12 items is over Miller —
a wall to hunt. **So this design builds the tree.** It is a *grouping/data* change to the
slider-definition table (and the headline axes) — no morph-pipeline change, no new modifiers, no new
archetype format. Every leaf below is an existing `region_sliders.gd` spec or an existing headline
axis; the tree only reorganizes them and adds intermediate navigation nodes.

**The tree (each level ≤7 children, Miller-compliant at every level):**

```
Body
├─ Face
│  ├─ Jaw & chin      ← chin/chin-jaw-drop ("jaw drop")  [+ future chin/jaw modifiers from registry]
│  ├─ Nose            ← nose/nose-scale-vert ("nose size")  [+ future nose family]
│  ├─ Mouth           ← (registry mouth family; none in flat table today — added as the tree lands)
│  ├─ Eyes & brow     ← eye color (value-node, §6.7)  [+ future eye/brow family]
│  ├─ Skull          ← head-scale-horiz/vert/depth ("face width/height/depth"),
│  │                     head-fat ("face fullness"), head-age ("face age")
│  ├─ Cheeks         ← cheek bones / cheek fullness / cheek height / cheek depth
│  │                     (the registry cheek/* family, §m2 — name now matches content)
│  └─ Face shape      ← head-oval / -round / -square / -rectangular / -triangular (the 5 unipolars)
├─ Torso
│  ├─ Chest & breasts ← Breasts group (8 sliders: cup size §6.2, spacing, projection, position,
│  │                     nipple size, nipple out, fullness, underbust) — already ≤8, one nav level
│  ├─ Belly           ← Belly & stomach (belly softness, belly forward) + navel depth/height (from
│  │                     "Fine detail", §m1) — power-detail lives WITH its body part, not a junk group
│  ├─ Waist & hips     ← Waist & hips (waist, hips circ, hip width, hip line, torso-to-hip)
│  │                     + love-handle depth / out (from "Fine detail", §m1)
│  ├─ Back & shoulders ← Torso & shoulders (V-taper, shoulder width, pectorals, back muscle,
│  │                     chest depth)
│  └─ Glutes & pelvis  ← Glutes & pelvis (butt size, pelvis tone, bulge)
├─ Arms                ← Arms (7 sliders)
├─ Legs                ← Legs (9 sliders → see note)
└─ Neck                ← Neck (neck thickness, neck length, double chin)
```

Notes / honest edges:
- **"Fine detail" is dissolved (§m1).** Its four power-detail sliders (navel depth/height,
  love-handle depth/out) move to live *under the body part they shape* (Belly, Waist & hips). There
  is no orphan junk-drawer with no body locus.
- **Legs has 9 leaves** — over Miller for one screen. It splits into **Thighs** {thigh size, thigh
  muscle, thigh fat, thigh length} and **Lower legs** {calf size, calf muscle, shin length, knee,
  ankle}. (Two ≤5 children rather than one 9-item wall.)
- **Skull & cheeks now carries cheek sliders (the m2 fix).** v2's node mapped only `head/*` and so
  advertised "& cheeks" with no cheek control. The registry has a genuine **`cheek` family** —
  4 bilateral stems (`cheek-bones`, `cheek-inner`, `cheek-trans` height, `cheek-volume`), each an
  L/R pair = **8 modifiers** (verified `cheek/*` ×8 in modifier_registry.json). Pairing these into
  four midline-symmetric sliders needs a **small build task**, not "no new code": the existing
  `resolve_full_names` (`region_sliders.gd:156–165`) only expands *bare* stems (`not
  spec_name.contains("/")`) under a hardcoded `BILATERAL_PREFIX := "armslegs/"`, so it cannot reach
  the `/`-prefixed `cheek/` family — referencing a cheek full_name directly yields a one-sided
  slider. So pairing the cheek family requires **generalizing that hardcoded prefix** (a per-stem
  prefix, or teaching `resolve_full_names` to accept an already-`<group>/`-prefixed stem and pair
  `l-`↔`r-` within it). The capability is nearby: `twin()` (the mirror map, lines 180–196) already
  does generic `l-`↔`r-` flipping across any `<prefix>/` group. This is a small grouping-table +
  one-constant code change — still **no new morph targets** — so "cheek bones / fullness / height /
  depth" become four midline-symmetric sliders once the prefix is generalized. The node's name now
  matches its content. (Adding 4 brings Face's *Skull & cheeks* leaf set to 9 head/cheek
  sliders — over Miller for one node, so it splits into **Skull** {face width/height/depth/fullness/
  age} + **Cheeks** {bones/fullness/height/depth}, keeping Face at 7 children: Jaw & chin, Nose,
  Mouth, Eyes & brow, Skull, Cheeks, Face shape — still ≤7.)
- **Empty intermediate nodes** (Mouth today has no flat-table sliders; Eyes & brow has only color)
  are honest: they show what they have (color for Eyes), and the registry already contains the raw
  mouth/brow/chin families reachable by on-body grab (§3.2) — the tree gives them a *home* to
  populate as named sliders land, rather than asserting they exist as sliders now.
- **Top level = 5 nodes** (Face, Torso, Arms, Legs, Neck) — well under Miller. **Face = 7 children
  after the Skull/Cheeks split (Jaw & chin, Nose, Mouth, Eyes & brow, Skull, Cheeks, Face shape);
  Torso = 5; every leaf set ≤8 and mostly ≤5.** Counted, at every level.

This tree is the chunking. With it, the active-surface rule scans at every level. The build task is:
re-shape `RegionSliders.GROUPS` from a flat `[label, [specs]]` list into a `[label, children]` tree
(or a parent-pointer on each group), and teach the dock to render one level at a time. Test:
selecting a node shows exactly its children, count + identity asserted against the tree data.

---

## 2. The active-surface rule (what replaces the tier selector)

**The rule:** *the active contextual surface = the value-nodes and child-region-nodes of the
currently-focused node, and nothing else.* Depth is reached by **navigating into a region**, never
by raising a "tier." The tier selector is **deleted**.

This is removal-by-locality (`affordance-surfaces.md` §"Filtering vs prioritization"): irrelevant
affordances are *absent*, not demoted. Three grains compose:

- **Coarse (region selection).** Point at / select a body region → the dock shows only that node's
  children (§1.4 tree). The 58 sliders never appear at once; you see one node's ≤7 at a time. The
  region tree *is* the chunking — Miller-compliant by construction, at every level.
- **Fine (value under the pointer).** Hovering the body names the single value under the cursor with
  its keybind inline (learnable-by-inspection — `affordance-opacity.md`); grabbing its handle edits
  it. The finest locality: "what's under my attention right now."
- **Whole-body (the pinned strip).** The six body-wide macro axes — gender presentation, age,
  height, build/weight, muscle, proportions (`body_state.gd:61–100`) — are **pinned** — always
  present in a thin strip, stable position, for muscle memory. They are a single coherent
  whole-body chunk (≤7, one scan). Pinned items do not move and are not subject to the contextual
  rule.

### 2.1 No mode toggle — focus, not modes

There is no `Sculpt mode`. The on-body reshape is disambiguated from camera-orbit by **a visible
grab-handle on the focused region, not by an invisible mode and not by where the pointer happens to
be** — see §3.2 (this is the M6 fix; v1's focus-based orbit-vs-reshape is dropped).

### 2.2 The genuine-lists carve-out

A homogeneous list is **one affordance**, not N — Miller's ~7 is a scan heuristic for *heterogeneous*
surfaces; a genuine list is fine to be long because it is scanned with scroll + filter + search
(`affordance-surfaces.md`). These open as **transient overlays/galleries** (not persistent panels):

- **Archetype gallery** — every first-party + user archetype, thumbnail + name, filter chips
  (presentation / build), search. Not a fixed 2-column grid.
- **Hairstyle / clothing / preset pickers** (as they land) — the same gallery affordance, reused.
- **Saved characters** — the user's own list.

A gallery is opened as a navigational edge (from the top bar or the entry screen) and dismissed on
pick or escape; it is never a wall the body sits beside. **A list is not the primary surface.**

### 2.3 Pinning and the OPEN part (honesty)

Pinning (whole-body strip stable; recently-touched regions easy to return to) is shipped.
**Cross-set relevance ranking — "what does the user most likely want to do next" computed across the
whole graph — is genuinely unsolved and is NOT shipped.** The source flags it as gated on usage data
(`interaction-graph.md`; `affordance-surfaces.md` §"Filtering vs prioritization"). Ordering *within*
an already-locality-narrowed contextual set may use recency (cheap, from a short history). Building a
frecency ranker that reorders the whole surface on cold-start guesses is exactly the faked-relevance
failure this design refuses. See §8 OPEN.

---

## 3. Per-value plural modality (grab-on-body / slider / type / nudge / keybind)

**Modality is plural per value, evoked not picked. Direct-manipulation is one modality among many —
NOT the thesis.** (`editor-interaction.md` §"Modality is plural, not chosen" and §"Direct
manipulation is one modality, and often insufficient.") The v1 radial/sibling-flick modality is
**cut** (M3): it required a stable, motivated sibling-direction map over a sibling set that did not
exist; a radial over an undesigned set is the "radial for arbitrary commands where direction carries
no meaning" the source calls the wrong surface. The directional edge survives as a plain
scroll/arrow nudge on the focused value — no circle, no membership question.

Every value node carries, simultaneously, the modalities its type affords:

- **Grab on the body** (gestural, approximate) — reshape the region via its visible handle (§3.2);
  precision where you don't need exactness.
- **Slider** (data-entry, approximate) — scrub by eye.
- **Numeric field** (data-entry, exact) — type `172 cm`, `cup D`, `age 24`. **Drag and type are
  co-equal on the same field** — same node, two precisions. Precision is a real axis the modalities
  span, not a separate widget.
- **Nudge** (directional) — scroll / arrow on the focused value for a small step.
- **Keybind** — shown **inline on the value's visible affordance** so you learn it through the
  modality you're already using and it graduates to eyes-free (`affordance-opacity.md`). No separate
  shortcut viewer, no tutorial.

All modalities write through the same `apply_capped` choke (decision §4), so a clamp shows
identically whichever modality you used, and the write-back keeps the slider thumb, the numeric
field, and the on-body shape reflecting the one clamped value (no desync).

### 3.1 What survives from unshape's vocabulary — and what is cut (the M4 fix)

v1 imported `compare-variants`, `vary-per-feature`, and `promote-in-place` as first-class value-node
affordances. They are unshape's editor principles; their fit to a *character creator* was asserted,
not shown. The honest accounting:

- **Mirror — KEPT** (a real creator need). Editing one side and having the other follow is something
  players actually want, and it already ships (`_mirror`, default ON, with `RegionSliders.twin`).
  It stays as a **per-value link state**, not a separate global mode: a focused lateral value shows a
  mirror toggle inline; off = edit one side. (This subsumes what v1 called "vary-per-feature" —
  there is no second name; mirror-off *is* the asymmetry affordance.)
- **compare-variants — CUT as a shipped affordance.** For a single scalar the live body already
  shows the value as you scrub; N side-by-side live thumbnails of one slider is busywork, and v1
  itself conflated it with history branches. The genuine "audition and keep both" capability already
  exists as the **branching history** (§5) — that is the creator's real form of it, and we do not
  ship a second, redundant "variants" surface. (If a future, named creator use appears — e.g.
  "audition 4 face shapes at once" — it gets its own design pass then. Not now.)
- **vary-per-feature — CUT as a distinct concept.** It was the existing mirror-off behavior under a
  borrowed name; folding it into Mirror (above) removes the duplicate concept.
- **promote-in-place — CUT.** "Drive this value from the archetype" / "link to mirror twin from the
  node" assumed a node/graph view to open into and a per-value archetype-blend system that **does not
  exist** (archetypes are whole-body picks via raw restore — `_build_archetype_grid`,
  `_apply_imported`). The creator has no graph to "form behind you." Cut; if per-value
  archetype-blend ever becomes a real ask it is a substantial new system with its own design pass.

Net: the only sister-tool concept that survives is **mirror**, because it is the only one with a
concrete creator use a player wants. No graph-view, no variants surface, no promote gesture.

### 3.2 The on-body reshape affordance — explicit grab-handles (the M6 fix)

v1 disambiguated orbit-vs-reshape by *focus + pointer-over-region* — which mis-triggers (the first
drag on a region you want to edit is stolen as a focus-nav; a drag over the focused head when you
wanted to orbit reshapes instead; there is no defocus). That is N invisible per-region modes — worse
than the visible `Sculpt mode` toggle it replaced. **Replaced with a visible, unambiguous handle:**

- **Focus a region** by *clicking* it (or selecting it in the dock / breadcrumb). The focused region
  gets a clear **focus outline** (ambient) and sprouts **a small set of explicit grab-handles** on
  the body at that region — directional nubs whose hover changes the cursor (`CURSOR_DRAG`).
- **Drag *on a handle* → reshape** (the gestural edit; same node the slider drives). **Drag anywhere
  else — empty space OR the body surface away from a handle — → orbit.** Right-drag pans, scroll
  zooms, always. So "is this an edit or a camera move?" is answered by *what you grabbed*, visibly,
  never by an invisible mode or by which region the pointer is merely over.
- **Defocus is obvious:** click empty space, press `Esc`, or use the breadcrumb back-edge. On
  defocus the handles disappear and the whole body orbits freely again.
- A click that *misses* every region is just an orbit-start (no accidental focus). A click *on* an
  unfocused region focuses it (and shows its handles) — one deliberate click, not a stolen drag.

**Handle hit tolerance (the m5 fix — small face handles must be forgiving).** "Drag anything
not-a-handle orbits" is unforgiving on a face where handles (nose, chin) are small screen targets
sitting *on* a rotatable body. So the hit test is specified, not left implicit:
- **Screen-space pick radius.** A press resolves to the nearest handle whose *screen-space* distance
  to the cursor is within a generous pick radius (target ~**24 px**, independent of the handle's
  drawn dot size and of camera distance — the small visual nub has a much larger invisible hit
  disc). The press picks the nearest handle within that radius; only a press with **no** handle
  inside the radius starts an orbit. This is a 2D screen-pick (cursor-to-handle-projection distance),
  not a 3D surface raycast, so a near-miss on a small nub still grabs the handle the user obviously
  meant.
- **Grab-latch hysteresis.** Once a press latches onto a handle, the drag **stays a reshape until
  release** — it never silently converts to an orbit mid-drag if the cursor wanders off the surface
  or past another handle. The reshape/orbit decision is made **once, at press**, by the pick radius;
  it is not re-evaluated per-frame. (Symmetrically, an orbit that began on empty/no-handle space
  stays an orbit until release.)
- **Cursor feedback.** Hovering inside a handle's pick radius switches the cursor to `CURSOR_DRAG`
  *before* the press, so the user sees the forgiving target light up and knows a press will reshape,
  not orbit. The radius is visible-by-feedback, not a guess.

This keeps modality plural (slider / type / nudge / grab all write the same node) while making the
on-body drag unambiguous: handles are visible affordances (`affordance-types.md` — gestural
affordances are discovered through hover/cursor; making them *visible on focus* is the fix for their
fragility), and there is exactly one rule — *press within a handle's pick radius* reshapes (and
latches until release), a press anywhere else orbits.

---

## 4. The screen — one coherent projection, body foregrounded (the M1 fix)

v1's "command rail" was the corner-scatter wall renamed: a permanent left panel holding Start /
Looks / Realism / Saved / Randomize facing a permanent right contextual dock — two opposing slabs
sandwiching the body, exactly the ribbon failure the source names. **v2 has no side walls.** The
body is the largest, central thing. Per `affordance-types.md` §"a canvas renders gestural/
directional/ambient; commands appear as an overlay," global commands live in a **minimal top bar**,
contextual affordances appear in **one compact dock beside the focused region** (only while a region
is focused), and lists open as **transient galleries** (§2.2).

```
┌──────────────────────────────────────────────────────────────┐
│ ☰ Create   ‹ Face › Jaw & chin ›        ⤺ History   Share  Open│  ← minimal TOP BAR (global)
│                                                                │
│                                                                │
│                  ╭───────────────────────╮                     │
│                  │                        │  ┌───────────────┐ │
│                  │                        │  │ Jaw & chin     │ │ ← CONTEXTUAL DOCK
│                  │       THE  BODY        │  │ jaw drop  ▮─○  │ │   (appears only when a
│                  │   (foregrounded, the   │  │ chin      ○─▮  │ │    region is focused;
│                  │   largest element; the │  │ …≤7 values…    │ │    floats beside the
│                  │   editing canvas)      │  └───────────────┘ │    focused region, not a
│                  │   ◌ grab-handles on    │                     │    full-height wall)
│                  │     the focused region │                     │
│                  ╰───────────────────────╯                     │
│                                                                │
│ gender ▮─○  age 24  height 172cm  build ▮─○  muscle ▮─○  prop ▮─○│  ← PINNED whole-body strip (6)
└──────────────────────────────────────────────────────────────┘
```

### 4.1 The body canvas (center, foregrounded)

The orbitable third-person body is the largest element and the primary editing canvas. Hover glows
the value under the pointer and names it (keybind inline); the focused region shows grab-handles
(§3.2); empty-space / non-handle drag orbits. Studio lighting + face-front default + centered pivot
(decision §6.5) stand. Coarse + fine locality live here.

### 4.2 The top bar (global commands only — minimal)

A single thin bar, left-to-right, ≤6 items, all global, none contextual:
- **☰ Create** — opens the **archetype gallery** overlay (§2.2) + **Randomize** (§6.3) + **Open**
  (import) + **Save / Save-as-archetype**. The non-spatial "start from / save / load" cluster is one
  menu, not a wall. (Share and Open are also surfaced directly at the right for one-click reach.)
- **‹ breadcrumb ›** — the navigational back-edge through the region tree (`‹ Face › Jaw & chin ›`),
  always in the same place (spatial consistency — `affordance-types.md`).
- **⤺ History** — one affordance, opens the history overlay (§5).
- **Share** — export (§6.1), one click.
- **Open** — import (§6.1), one click (mirrors Share).

No "Looks" / "Realism" / "Saved" top-level junk-drawers. **Looks** (hair / eye color / clothing)
live where they belong in the region tree (Eyes & brow → eye color; hair/clothing as galleries under
their body region as they land). **The limits control** lives at the value, not as a global rail
group (§6.4). **Saved characters** is in the ☰ Create menu's gallery.

### 4.3 The contextual dock (the focused node's edges) — appears only on focus

Renders **only** the focused node's children (the active-surface rule, §2): a region node shows its
child regions (each a navigational edge) + its value-nodes; a value gets its plural modalities (§3).
It is a **small floating card beside the focused region**, not a full-height side wall, and **it is
absent when nothing is focused** (no empty box, no persistent slab). The breadcrumb in the top bar
is the back-edge.

### 4.4 The pinned strip (whole-body, always present) — the six body-wide dials (the M-A fix)

The **six whole-body macro axes** — **gender presentation, age, height, build/weight, muscle,
proportions** (the headline axes of `body_state.gd:61–100`) — sit in a thin always-on bottom strip,
pinned for muscle memory, editable in place with the same plural modality (height types `cm`; gender
drags or types). They are the highest-frequency, no-region-locus edits and the ones a user returns
to; pinning is *earned by frequency* and these qualify by construction (`affordance-surfaces.md`
§"stability earned per-item").

This is the M-A fix: v2 renamed **Muscle** (lean ⟷ muscular) and **Proportions** (natural ⟷
idealized) in §6.5 but pinned only four dials and gave these two no home anywhere — they were
orphaned, renamed-but-unplaced controls (a user wanting a more muscular body could not reach the
dial). They are whole-body and non-spatial, so they cannot live in the anatomical region tree and
cannot live in the top bar (commands only). Their home is here, with the other body-wide dials. The
six are **a single coherent scannable group** (≤7, one chunk — a feminine-vs-muscular-vs-idealized
whole-body decision is made in one place).

**The limits control is NOT in the strip** — it surfaces at the value when you push past human range
(§6.4). So the strip is **6 items** (the six body-wide dials), one coherent whole-body cluster.

### 4.5 The entry / no-focus surface — itself scannable (the M7 fix)

v1 let the entry screen degrade to rail (5 groups) + pinned strip (5) + dock hint = a wall before the
user focuses anything. v3's entry surface, counted:
- **The body**, centered, in its default pose (1 canvas).
- **The pinned strip** (6 items: gender, age, height, build, muscle, proportions — the six
  body-wide dials, §4.4).
- **The top bar** (≤6 global items, §4.2).
- **One ambient hint** on the body: "click a part to shape it, or pick a starting body" — with a
  single **Start from a body** button that opens the archetype gallery overlay.
- **No contextual dock** (nothing is focused → the dock is absent, §4.3).

Total simultaneous heterogeneous affordances at entry: pinned strip **6** + top bar ≤6 + one
hint/button. The strip's six are one coherent whole-body chunk (≤7, scanned as a single group); the
top bar is a second distinct group; they are *distinct, stable, spatially-separated groups* (a
grammar of groups — `affordance-surfaces.md` §"spatial semantics"), each ≤7, and the entry screen
never shows the 58-slider namespace. The first thing a new user sees is the **body + six pinned
whole-body dials + "pick a starting body."** That scans — six body-wide dials is exactly the kind of
coherent chunk Miller's bound permits.

### 4.6 Responsive + escape hatch

On a narrow window the dock and the pinned strip collapse to edge-tabs that overlay on demand; the
body stays foregrounded; the top bar stays. One **search/palette** (a single keybind) is the
long-tail escape hatch — present, **rare**, never primary navigation (`affordance-surfaces.md`
§"command palette as escape hatch"). It indexes the **human display names** ("jaw drop", "face
width") and global commands. Because the region tree (§1.4) now makes normal face editing scannable
by navigation, the palette is **not** load-bearing for ordinary editing (the v1 risk, §m5): it is
the rare reach-for-the-obscure, not the front door for the face. If a playtest shows users *living*
in the palette to edit the face, that is a signal the tree failed — a regression to catch, not a
design we lean on.

---

## 5. History — human labels, collapsed, branchable

History is a **branching tree** (already — DESIGN.md "lived history": explore an edit, back up,
explore another, keep both). The UX fixes:

- **Human labels, never modifier-space.** A node reads **"wider jaw," "taller (+6 cm)," "fuller
  chest," "leaner build," "started from Athletic"** — derived from the value's *display name* + a
  direction word, not `sculpt: nose-hump +0.20` or `age_years = 25`. The display names already exist
  in `region_sliders.gd` ("jaw drop", "face width"); the headline labels in user terms (§6.5).
- **Collapse consecutive edits to the same value.** Ten grabs refining the jaw in one sitting
  collapse to one node "shaped jaw" (net change), not ten nodes. A new node opens only when the
  *edited value changes* or a non-edit op intervenes.
- **One home, one toggle.** History lives behind the single `⤺ History` affordance in the top bar
  (keybind inline), opening as an overlay. The branch nav is the existing linear spine with a
  `‹ i/n ›` junction selector — kept, relabeled in human terms.

This is the creator's genuine "audition and keep both" capability (§3.1) — we do not ship a second
"compare-variants" surface on top of it.

---

## 6. Per-feature handling (per the model)

### 6.1 Export / import — one Share, one Open

- **Share** (export) — **one** top-bar affordance. It saves the character; the format (JSON /
  image-with-embedded-history) is a *detail inside the one action*, **defaulting to image** (the
  thumbnail the gallery shows). The format choice is decided here as **a save-time default in
  Settings + a small inline toggle on the Share confirmation, NOT a submenu or long-press** (the m3
  fix — the nested-chooser is resolved): clicking Share saves an image immediately; a single inline
  "also embed editable history" checkbox (default on for formats that support it) and a one-line
  format hint are the only choices, shown on the same confirmation, never a separate menu. The
  shipped multi-format export path (`creator_io.gd`, PNG/JPG/WEBP) stays; the default is PNG-with-
  history, and JPG/WEBP are reachable via the Settings default only.
- **Open** (import) — **one** top-bar affordance, accepting JSON or image, plus drag-a-file-onto-the-
  window. Applied raw (beyond-cap persists — decision §4.3 path 7).
- Symmetry: Share ↔ Open, two affordances, side by side at the top-bar right.

### 6.2 Breast size — import the genuine cup-size axis (NET-NEW BUILD WORK; revisits a deferral)

The shipped "height / lift" axis is honestly *not* size (a render probe proved it is purely vertical
redistribution — `region_sliders.gd:42–49` guard). v1 proposed binding a single "Cup size" node to
*fullness + projection* as an interim — but those already ship as **separate** sliders, and a
cup-letter readout over two axes with no defined mapping is the "size slider that doesn't change
size" the code's own guard refused. **v2 cuts the relabel and commits to the real axis.**

- **In scope:** import + vendor the **cup cube** (the 216-file macro factor-cube the decision doc
  confirmed as un-vendored) and bind a single **Cup size** value-node in the *Chest & breasts*
  region to it, reading in plain small-to-large (a cup-letter readout is optional polish, gated on
  the mesh-measurement infra the decision doc dropped — the node ships with a plain scale either way).
- **This overturns two prior decisions, not just one deferral (the m6 fix).** v2 framed this only as
  "revisiting a deferral." It is more than that — the decision doc and the shipped code already
  *disagree*, and committing the cube overturns **both**:
  1. **Decision §187 ("drive size via the volume axis").** The decision doc states size *is* driven
     by `breast/breast-volume-vert-down|up` (the "live size control"). Committing the cube **retires
     that claim** — the volume axis is no longer the size control.
  2. **The shipped `region_sliders.gd:42–50` guard.** After a render probe proved that exact axis is
     a *purely vertical redistribution* (net displacement ±y, projection ≈ 0 at both poles — it does
     **not** change apparent size), the shipped code relabels it **"height / lift"** and its guard
     explicitly states it is not size. So decision §187 is **already falsified by the shipped
     guard** — the two prior artifacts contradict each other. This design sides with the code (it is
     correct), which means the cube is not merely "the upgrade path" (decision §190's softer
     framing): once §187's "volume = size" claim is retired, the cube is the **only** real size
     control. The "Lift" axis stays as its own distinct, correctly-labeled redistribution value-node.
  **Flagged as an architecture/build revisit** — to be confirmed feasible (cube vendor + factor-cube
  composition with gender/age/weight) before the node is final.
- The value-node abstraction means once the cube is bound, **no UX changes** — Cup size is just a
  value with the plural modality. We do **not** ship a cup readout over a redistribution proxy in the
  meantime; if the cube import slips, the node is simply absent and "Lift" + "fullness" + "projection"
  remain as the honest shape controls, none of them mislabeled as size.

### 6.3 Randomize — instant, coherent presentation (the M5 fix)

**One Randomize affordance** (in the ☰ Create menu). It is **instant** (no heavy solver — the
decision's bounded seeded walk, §2.3 of the decision). The v1 plan ("sample a first-party archetype
as the seed") was falsified by the roster: of the **7** archetypes, **2 are androgynous**
(`androgynous-athletic` masc 52, `androgynous-average` masc 50), so ~2/7 of the time it would seed
on a deliberately androgynous body — the very "intermediate androgynous mush" v1 promised it never
produces. **v2 samples gender presentation as a coherent choice, then varies within it:**

1. **Pick a presentation bucket** by weighted roll: *feminine* / *masculine* (the coherent, definite
   presentations) by default; *androgynous* is included **only when the user has opted into it**
   (a one-time "include androgynous in random" preference, default off — because the user's ask was
   "sensible-gender randomize," and androgynous-by-design is a deliberate, less-default choice, not
   mush to land on by accident).
2. **Seed from an archetype in that bucket** (feminine → `feminine-slim|curvy`; masculine →
   `masculine-lean|athletic|heavy`; androgynous → the two androgynous files only if opted in).
3. **Walk within the realistic range** around that seed through the choke (bounded, at extremeness 0
   so it never goes extreme).

**The walk is bounded away from the androgynous midline (the m4 fix).** v2 fixed the *seed* (always
in-bucket) but did not bound the *walk's* `masculinity` excursion — so a feminine seed (masculinity
22/24 in the roster) walking "within the realistic range" toward 40–50 could land in the very
androgynous zone the bucket is meant to avoid. v3 clamps the excursion so gender presentation stays
inside its bucket:
- **The walk's `masculinity` is clamped to the bucket's presentation band**, not just to a ±range
  around the seed. Concretely: **feminine stays `masculinity ≤ 40`, masculine stays `≥ 60`**, never
  crossing the **40–60 androgynous band** (the band is reachable only by *picking* an androgynous
  archetype or opting androgynous into random, never by an unlucky walk). The feminine seeds (22/24)
  and masculine seeds (72/74/76) sit comfortably inside their bands, so the realistic walk has room
  without approaching the choke.
- All other axes (age, build, muscle, proportions, region detail) walk freely within their realistic
  ranges; only `masculinity` carries the presentation clamp, because presentation is the axis whose
  midline reads as "mush."

Result: a plausible person of a *definite* presentation every roll — guaranteed by both the seed
*and* the bounded walk — instant, one click; the result is a history node ("randomized"). The
androgynous archetypes are not deleted — they remain pickable in the gallery and seedable when the
user opts in; they are simply not the default random target.
**Open sub-questions (named, not hidden):** the feminine/masculine bucket weighting (50/50 vs
roster-proportional) and the exact masculinity band edges (40/60 vs tighter) are taste tuning
inputs, §8.

### 6.4 Limits — a plain-language opt-in at the value, not a "Realism" dev-noun (the M2 fix)

The single global cap-widening scalar (`extremeness` 0..1 + a boolean "Allow extreme proportions"
toggle — decision §4) was presented in v1 as a flagship **"Realism"** rail group — itself an abstract
dev-noun (a player does not think "I want 40% realism"), and "Stylized" is art-pipeline jargon. **v2
removes the global noun and the rail group.** The limit is expressed as **the control's own range
plus a plain opt-in:**

- **By default, every control's range *is* its human/tasteful range** — the slider simply stops at
  the default cap (decision §4: at extremeness 0 the field clamps to the default interval). No global
  control, no percentage, nothing to "set." The limit is the control's own visible extent.
- **When a user pushes a value to its human edge,** the value node shows an ambient tick at that edge
  and a small inline, plain-language opt-in **at the value**: **"Allow beyond-human extremes"**
  (a simple toggle). Flipping it widens *that control's* range toward its hard limit (mechanically:
  it is the global `extremeness`/allow-extreme unlock — decision §4 — but it is *presented and
  reached at the value the user is editing*, framed as an act ("let me push past lifelike"), not as a
  global abstract noun on a rail).
- **Naming, and the m3 collision fix.** v2's string was "Allow beyond-human **proportions**," which
  collided with the **Proportions** axis (a *distinct* whole-body dial, §6.5 — natural ⟷ idealized):
  the same noun would mean two different things on one surface (the macro proportion-envelope dial,
  and the cap-unlock act), and a user toggling it might think it acts on the Proportions dial. v3
  renames the toggle to **"Allow beyond-human extremes"** — plain English, the act of pushing past
  the lifelike cap, with no noun shared with any axis. ("Proportions" now means exactly one thing on
  the surface — the dial.)
- Lowering it never snaps existing values (the non-destructive ratchet — decision §4.2).
- There is **no** user-visible word "Realism," "extremeness," or "Stylized" anywhere; the only
  string is the act, "Allow beyond-human extremes." The §7 quality bar greps the built UI for all
  three banned words.

Honest note: the underlying mechanic is still *one* global unlock (decision §4 — a control's stop is
a function of global extremeness only, never of sibling controls); the design choice here is purely
how it is *surfaced* (at the value, as a plain opt-in) and *named* (an act, not a noun). It does not
change the cap mechanics.

### 6.5 Naming — de-jargoned, user-facing throughout

| Internal / old surface | User-facing name |
|---|---|
| `masculinity` (0–100, feminine↔masculine) | **Gender presentation** (a *feminine ⟷ masculine* range; gender *identity* is separate and not a body morph) |
| `extremeness` / "allow extreme proportions" | *(no global noun)* — surfaced as the per-value opt-in **"Allow beyond-human extremes"** (§6.4; renamed off "proportions" to avoid colliding with the Proportions axis below, §m3) |
| `proportions` ("uncommon ↔ idealized") | **Proportions** ("natural ⟷ idealized") |
| `weight` (50–150 %) | **Build** (light ⟷ heavy) |
| `muscle` (0–100 %) | **Muscle** (lean ⟷ muscular) |
| `age_years` | **Age** (in years) |
| `height_cm` | **Height** (in cm) |
| `T1 / T2 / T3`, "headline", "registry tree", "detail tier" | *(deleted — there are no tiers)* |
| `sculpt: nose-hump +0.20` (history) | **"shaped nose"** / the value's display name + direction |
| `breast/breast-volume-vert-down\|up` "height/lift" | **Lift** (a real, honest redistribution axis) — distinct from **Cup size** (§6.2, the imported cube) |

Pole labels everywhere are plain language ("close ⟷ wide", "soft ⟷ toned"), which
`region_sliders.gd` mostly already does. The work is the headline axes + history + the limits framing
+ deleting the tier vocabulary.

### 6.6 Height — a real cm value-node; uniform scale KEPT, revisit flagged not assumed (the B2 fix)

v1 asserted "the build fix that makes height a real height morph plus a true cm field (not a uniform
scale)." That **contradicts a deliberate decision**: `body_state.gd:91–100, 262–271` makes height a
**uniform mesh scale**, on purpose, recorded with a rationale — *proportions change shape at fixed
stature; height changes stature at fixed shape; genuinely independent.* There is no pending "real
height morph" fix to assume. **v2 picks honestly:**

- **Decision: keep the deliberate uniform scale; expose a genuine cm value-node** (option (b)).
  Height is a value-node in the pinned strip: drag (approximate) + a numeric field reading **cm**
  (exact), co-equal, driving `height_cm` (which `height_scale()` turns into the mesh scale). The
  field reads **"height" in cm** to the user — the user sets a stature, not a "scale."
- **Why (b), not (a):** option (a) — a real height *morph* preserving proportion-orthogonality —
  would *reverse* a recorded body-mechanics decision (drop the uniform scale, re-introduce a height
  morph cube that the decision deliberately dropped, then re-prove orthogonality). That is a
  body-mechanics change out of this UX design's scope, and the decision's rationale (clean
  orthogonality, no MakeHuman height-cube coupling) is sound. The UX does not need a morph: a cm
  value that scales stature reads correctly as "height" to the player.
- **Flagged, not claimed:** *if* a future playtest shows uniform-scale height reads wrong (e.g. a
  very tall body looks like a scaled-up average rather than a tall person with adjusted proportion),
  that is a **build-feasibility revisit of the decision's scale tradeoff** (option (a)) — recorded
  here as a possible future architecture change, **not** asserted as an existing fix. The value-node
  abstraction means swapping scale→morph later would be invisible to this UX.

### 6.7 Iris / eyes — color is a value-node; round-iris is NOT claimed fixed (the m2 correction)

Eye color is a value-node (procedural `iris_color`, decision §6.3) under *Face › Eyes & brow* — a
color affordance + a small preset gallery (the list carve-out). **The shader already ships a round
iris/pupil:** `body_rig.gd:44–52` `EYE_PARAMS_DEFAULT` has `pupil_aspect: 1.0` ("1.0 round
(human)"). So v1's "assumes the build fix that makes the iris round" is **withdrawn** — there is no
roundness fix to assume; the iris is parameterized round by default.

- **The user OBSERVED a non-round iris.** That is a **render discrepancy to VERIFY in build** (the
  rendered eye not matching the `pupil_aspect 1.0` param — a shader/UV/geometry issue), *not* an
  assumed-present defect with an assumed fix. The honest action is: render the eye, look, and if it
  is non-round despite `pupil_aspect 1.0`, file the render bug — do not bake a "round fix" into the
  UX spec. No UX node depends on it.
- No `gaze_dir` wiring (would double-count — decision §6.3). The CORE eye work (procedural iris
  striations / limbal ring quality, decision §6.3 #6a) is a render-quality item, user-taste-gated,
  unrelated to this UX.

---

## 7. Quality bar (UX-sense checks AND objective checks)

A surface is not done on green tests alone (CLAUDE.md Playtesting). Both kinds gate:

**UX-sense (playtested — run it and look; user-judged where taste):**
- **Nothing performative.** No control whose only job is to control the UI's verbosity. Tier selector
  gone; the active surface is observed to *emerge* from where you point/focus; the cut affordances
  (radial flick, compare-variants, promote-in-place) are absent, not hidden.
- **Nothing jargon.** Every user-visible string is read by someone who has never seen the code and is
  plain English. No "masculinity," "extremeness," "Realism," "Stylized," "tier," "registry"; history
  reads in human words. Grep the built UI strings for the banned vocabulary as an objective companion.
- **Every surface scans, at every level.** At every focus, the dock shows ≤~7 heterogeneous
  affordances; the region tree (§1.4) is verified ≤7 children at every node; the **entry/no-focus
  surface** is counted too (§4.5 — strip 6 + top bar ≤6 + one hint; no dock). A long *homogeneous*
  gallery is allowed and filterable.
- **Body foregrounded; no walls.** The body is the largest element and the editing canvas; there is
  no side panel, no five-corner scatter, no empty detail box; the dock appears only on focus and is a
  compact card, not a full-height wall. Verified on a render at two window sizes (responsive).
- **On-body reshape is unambiguous.** Grab-handles appear on the focused region; dragging a handle
  reshapes, dragging anywhere else orbits; defocus (click-away / Esc / breadcrumb) is obvious.
  Observed: no drag mis-triggers reshape-vs-orbit.
- **Modality is plural.** A chosen value (height, jaw, cup size) is editable by grab-on-body AND
  slider AND typed number AND nudge, all writing the same node, all reflecting the same clamp.
- **The six whole-body dials are all reachable.** Gender, age, height, build, muscle, and
  proportions each have a visible, usable home in the pinned strip — none renamed-but-unplaced
  (the M-A check). Observed: a user wanting a more muscular or more idealized body finds the dial.
- **Small face handles are forgiving.** A near-miss press on a small handle (nose, chin) on the
  rotated body still grabs the handle and reshapes (pick radius), and a started reshape stays a
  reshape until release (no mid-drag flip to orbit). Observed at two camera distances.
- **Randomize lands coherent.** Repeated random rolls produce definite-presentation bodies (not
  androgynous mush) with androgynous-default-off, *and* no roll's walk drifts masculinity into the
  40–60 band; observed over many rolls.
- **The composed whole.** An orchestrator/playtest pass drives the creator as a player (pick → nudge
  → grab-reshape a region → randomize → share → open) and reports cross-seam defects.

**Objective (agent-verifiable):**
- The active-surface rule is a pure function of focus; selecting a node shows exactly that node's
  children (count + identity asserted against the §1.4 tree data).
- The region tree exists and is ≤7-children at every node (asserted against the tree data).
- History coalesces consecutive same-value edits to one node; every node label is human (no `=`/`+0.`
  modifier-space strings).
- One Share, one Open, one Randomize (count top-level affordances of each kind = 1); no global limits
  control exists (the limits opt-in is found only at a value).
- A value's modalities (grab / slider / type) produce byte-identical `BodyState` for the same target
  value (the choke makes them converge).
- The substrate gates from the decision doc (cap enforcement, persistence round-trip, determinism,
  no-monster-by-default) are unaffected by this UX and still pass.

---

## 8. OPEN (honest — not faked)

- **Cross-set relevance ranking is unsolved.** "What does the user most likely want to do next,"
  computed across the whole graph, is gated on usage data we do not have at launch
  (`interaction-graph.md`; `affordance-surfaces.md`). We ship **locality + pinning + within-set
  recency only**, and do not build a cold-start frecency ranker. This is the one place the model
  itself says is unsolved; the design refuses to fake it. Revisit once real usage exists.
- **Cup-cube import feasibility (§6.2).** Vendoring the cube and composing cup size with
  gender/age/weight in the factor-cube is named as in-scope but **not yet build-verified**; committing
  it overturns **both** decision §187 ("volume axis = size") and the shipped `region_sliders.gd:42–50`
  guard (§6.2, m6). Until confirmed feasible, the honest fallback is no fake-size node.
- **Height scale vs morph (§6.6).** Uniform scale is kept; the morph option is flagged as a possible
  future body-mechanics revisit, not an assumed fix. Playtest decides if it is ever needed.
- **Round-iris render discrepancy (§6.7).** The user observed a non-round iris though the shader
  param is round; this is a build-time render bug to VERIFY and (if real) fix in the renderer — not a
  UX-spec dependency.
- **Randomize bucket weighting + walk-band edges (§6.3).** The within-bucket walk is now *bounded*
  away from the androgynous midline (masculinity clamped to the bucket band — the m4 fix is settled).
  What remains a taste tuning input: feminine/masculine **bucket weighting** (50/50 vs
  roster-proportional), the exact **band edges** (40/60 vs tighter), and the androgynous opt-in
  framing. (The coherence *guarantee* — every roll a definite presentation — is no longer open; the
  bound delivers it.)
- **The non-spatial ↔ spatial boundary.** Which axes pin vs surface on a region is judgment here
  (the six whole-body macro dials — gender/age/height/build/muscle/proportions — = pinned, §4.4;
  everything anatomical = region tree). A tuning input, not a law.
- **Empty intermediate tree nodes (§1.4).** Mouth (no named sliders yet) and Eyes & brow (color only)
  have homes in the tree but thin contents until more named sliders land. Acceptable (they reflect
  reality) but flagged.
- **VR projection.** The plural-modality + region-node + grab-handle model is controller/grab-native
  in principle (grab a handle = the gestural edit), but the world-space drag decomposition is
  unfinished design (decision §9). Flagged, not claimed.
