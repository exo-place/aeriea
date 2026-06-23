# Decision: Character creator UX — a projection over a typed interaction graph

Status: **DESIGN PASS — governs the creator-UX rebuild; converged through 3 UX/taste-adversary rounds (2026-06-23).** This is a clean spec, not a green promotion. It decides the player-facing *interaction shape* of the character creator — what is on screen, how a value is edited, how the surface stays scannable, and how each feature (export/import/history/randomize/height/cup-size/limits) is surfaced. It carries an honest OPEN section; nothing here is signed off as built or good until playtested and the user grants green.

Scope: the player-facing interaction model for the creator — the interaction-graph model for body editing; the rule that decides what is on screen (replacing the manual detail-tier selector); a navigable region tree that makes that rule real; a body-foregrounded layout with no side-wall scatter; plural per-value modality; an unambiguous on-body reshape affordance; de-jargoned naming; a plain-language limits framing; coherent randomize; and per-feature handling (export / import / history / randomize / height / cup size / iris). **No feature code.** This doc covers the **UX / interaction / projection layer**; the body/cap **mechanics** it projects — the cap model, the capped-write choke, breast/belly/region semantics, fidelity, camera, persistence — are decided in `character-creator-and-body.md` and are the substrate this UX sits on. Out of scope, named as dependencies only: cross-set relevance ranking (unsolved, §10 OPEN); the cup-cube vendor feasibility; the height scale↔morph body-mechanics tradeoff; the round-iris render bug; the VR projection of the grab model.

It cross-links:
- The affordance model that is the source of truth for this design (read in full, not paraphrased): rhizone [Affordance Surfaces](https://rhi.zone/affordance-surfaces), [Affordance Types](https://rhi.zone/affordance-types), [Affordance Opacity](https://rhi.zone/affordance-opacity), [Interaction Graph](https://rhi.zone/interaction-graph) — files at `~/git/rhizone/github-io/docs/affordance-surfaces.md`, `affordance-types.md`, `affordance-opacity.md`.
- unshape's editor model: `~/git/rhizone/unshape/docs/design/editor-interaction.md` (modality-is-plural, direct-manipulation-is-one-modality) and `projection-model.md` (manipulate generative parameters, not baked output).
- `character-creator-and-body.md` — the body/cap **mechanics** this UX projects (the cap model, the `apply_capped` choke, breast-size semantics, persistence, determinism gates). This doc edits *how those are surfaced*, not what they are.
- The aeriea creator code this projects: `scripts/body/character_creator.gd`, `region_sliders.gd`, `body_caps.gd`, `body_state.gd`, `body_rig.gd`, `assets/body/caps.v1.json`, `assets/body/archetypes/`.

**Provenance.** This spec is derived from the adversarially-converged design at `docs/artifacts/design/creator-ux/SYNTHESIS.md` (v4). That artifact, plus `attack-round1.md` / `attack-round2.md` / `attack-round3.md`, record the full hardening trail — three hostile UX/taste-adversary rounds that drove every BLOCKER and MAJOR to resolution against the live code (round 3 returned no BLOCKER / no MAJOR). The version changelog, the v1→v4 revision history, and the adversarial-round meta-commentary are stripped out here; this doc presents the converged result as the governing design.

---

## 1. What was wrong — the root error

The shipped creator was built as a set of control panels, not as a projection of an interaction graph. Concretely (each a verified observation, not a guess): a manual `T1/T2/T3` detail-tier selector (the player picks how much detail to see — performative); dev jargon on the player surface (`masculinity`, `extremeness`, "tier", "registry tree", history nodes reading `age_years = 25` / `sculpt: nose-hump +0.20`); five scattered, overlapping corner panels with an always-present empty "detail sliders" box, none foregrounding the body; export as a format dropdown + four buttons against a one-button import; history as a raw modifier-space edit log with no collapsing; lists faked as fixed-size button-grid panels; and modality treated as singular (a `Sculpt mode` toggle gating drag).

This design replaces the panels with a projection. **Every affordance is a typed edge in a graph; a frontend is a projection of that graph; the load-bearing metric is keeping the active slice scannable (glance-and-act, ≤~7), achieved by removal via locality plus chunking and stable pinning — never by a manual control and never by a magic count.**

---

## 2. The interaction-graph model for body editing

Two node kinds; the distinction is the spine of the layout (§7):

- **Region nodes** — body parts you can point at, organized as a navigable tree (§3). A region node's outgoing edges are its value-nodes plus its child regions.
- **Value nodes** — one per editable parameter (the 58 region sliders, the headline axes, eye color, the limits control). A value node has a stable identity, a human name, a current value, an allowed range (from the cap model), and a **set of co-present modalities** (§5). A value is **not** a slider — a slider is *one* of its rendered modalities.

Non-spatial value-nodes have no region locus. They split into two clusters, each with an explicit home: the **six whole-body dials** (the pinned strip, §6), and **the rest** — eye color (routed into the region tree at *Eyes & brow*), the limits control (surfaces at the value it gates, §8.4), presets/archetypes (the Create-menu gallery, §4.2).

### 2.1 Manipulate generative parameters, not baked vertices

The on-body grab decomposes the screen gesture into named **modifier** deltas (`MorphDrag.decompose_drag` → `{full_name: delta}`) and drives the same `BodyState.modifiers` the sliders drive — so the on-body grab and the slider are two modalities projecting the *same* node (`projection-model.md`: manipulate generative parameters, not baked output). Invariants (rig re-solve, UV preservation, normal/tangent rebake) are owned by the tool and never appear as user controls (mechanics in `character-creator-and-body.md` §6.1).

---

## 3. The region tree

The active-surface rule (§4) is hollow without a tree to navigate. The shipped `region_sliders.gd` has 10 flat groups, the face is one flat 12-item group, and there is no sub-region structure. **This design builds the tree** — a grouping/data change to the slider-definition table plus the headline axes; no morph-pipeline change, no new modifiers, no new archetype format. Every leaf is an existing `region_sliders.gd` spec or an existing headline axis; the tree only reorganizes them and adds intermediate navigation nodes.

Each level is ≤7 children (Miller-compliant at every level):

```
Body
├─ Face
│  ├─ Jaw & chin      ← chin/jaw-drop family
│  ├─ Nose            ← nose family
│  ├─ Mouth           ← (registry mouth family; reachable by on-body grab; named sliders land here)
│  ├─ Eyes & brow     ← eye color (value-node, §8.7) + brow family as it lands
│  ├─ Skull           ← face width/height/depth, fullness, age
│  ├─ Cheeks          ← cheek bones / fullness / height / depth (the cheek/* family, §3.1)
│  └─ Face shape      ← oval / round / square / rectangular / triangular (the 5 unipolars)
├─ Torso
│  ├─ Chest & breasts ← Breasts group (cup size §8.2, spacing, projection, position, nipple size,
│  │                     nipple out, fullness, underbust)
│  ├─ Belly           ← belly softness, belly forward + navel depth/height
│  ├─ Waist & hips    ← waist, hips circ, hip width, hip line, torso-to-hip + love-handle depth/out
│  ├─ Back & shoulders← V-taper, shoulder width, pectorals, back muscle, chest depth
│  └─ Glutes & pelvis ← butt size, pelvis tone, bulge
├─ Arms                ← Arms (7 sliders)
├─ Legs
│  ├─ Thighs          ← thigh size / muscle / fat / length
│  └─ Lower legs      ← calf size / muscle, shin length, knee, ankle
└─ Neck                ← neck thickness, neck length, double chin
```

Honest edges:
- **No junk-drawer.** The old "Fine detail" group is dissolved — its four power-detail sliders (navel depth/height, love-handle depth/out) live *under the body part they shape* (Belly, Waist & hips). Power-detail has a body locus.
- **Legs splits** into Thighs (4) + Lower legs (5) rather than one 9-item wall.
- **Empty/thin intermediate nodes are honest.** Mouth (no named flat-table sliders today) and Eyes & brow (color only) show exactly what they have and give the registry's raw mouth/brow families a *home* to populate as named sliders land — they are not asserted to exist as sliders now (flagged §10).
- Top level = 5 nodes; Face = 7 children; Torso = 5; every leaf set ≤8 and mostly ≤5 — counted at every level.

The build task: re-shape `RegionSliders.GROUPS` from a flat `[label, [specs]]` list into a tree (or a parent-pointer per group), and teach the dock to render one level at a time. Test: selecting a node shows exactly its children, count + identity asserted against the tree data.

### 3.1 The Cheeks node binding — a small prefix-generalization build task

The registry has a genuine **cheek family**: 4 bilateral stems (`cheek-bones`, `cheek-inner`, `cheek-trans` height, `cheek-volume`) × L/R = **8 modifiers** (verified `cheek/*` ×8 in `modifier_registry.json`). Pairing these into four midline-symmetric sliders is a **small build task, not free**: `resolve_full_names` (`region_sliders.gd:156–165`) only expands *bare* `l-` stems (`not spec_name.contains("/")`) under a hardcoded `BILATERAL_PREFIX := "armslegs/"`, so it cannot reach the `/`-prefixed `cheek/` family — referencing a cheek full_name directly yields a one-sided slider. Pairing the cheek family therefore requires **generalizing that hardcoded prefix** (a per-stem prefix, or teaching `resolve_full_names` to accept an already-`<group>/`-prefixed stem and pair `l-`↔`r-` within it). The capability is nearby: `twin()` (the mirror map, lines 180–196) already does generic `l-`↔`r-` flipping across any `<prefix>/` group. This is a grouping-table + one-constant code change — **no new morph targets** — listed among the build fixes to verify (§9).

---

## 4. The active-surface rule (what replaces the tier selector)

**The rule:** *the active contextual surface = the value-nodes and child-region-nodes of the currently-focused node, and nothing else.* Depth is reached by **navigating into a region**, never by raising a "tier." The tier selector is deleted.

This is removal-by-locality: irrelevant affordances are *absent*, not demoted. Three grains compose:

- **Coarse (region selection).** Select a body region → the dock shows only that node's children (§3 tree). The 58 sliders never appear at once.
- **Fine (value under the pointer).** Hovering the body names the single value under the cursor with its keybind inline (learnable-by-inspection); grabbing its handle edits it.
- **Whole-body (the pinned strip).** The six body-wide macro axes are pinned — always present, stable position, for muscle memory; not subject to the contextual rule (§6).

### 4.1 No mode toggle — focus, not modes

There is no `Sculpt mode`. The on-body reshape is disambiguated from camera-orbit by a **visible grab-handle on the focused region**, not by an invisible mode and not by where the pointer happens to be (§5.2).

### 4.2 The genuine-lists carve-out

A homogeneous list is **one affordance**, not N — Miller's ~7 is a scan heuristic for *heterogeneous* surfaces; a genuine list is fine to be long because it is scanned with scroll + filter + search. These open as **transient overlays/galleries**, never persistent panels: the archetype gallery (every first-party + user archetype, thumbnail + name, filter chips, search — not a fixed 2-column grid); hairstyle / clothing / preset pickers (the same gallery affordance, reused, as they land); saved characters. A gallery is a navigational edge, dismissed on pick or escape. A list is never the primary surface.

### 4.3 Pinning and the OPEN part (honesty)

Pinning (whole-body strip stable; recently-touched regions easy to return to) is shipped. **Cross-set relevance ranking — "what does the user most likely want to do next," computed across the whole graph — is genuinely unsolved and is NOT shipped** (gated on usage data we do not have at launch). Ordering *within* an already-locality-narrowed contextual set may use recency. A cold-start frecency ranker that reorders the whole surface on guesses is exactly the faked-relevance failure this design refuses. See §10.

---

## 5. Per-value plural modality

**Modality is plural per value, evoked not picked. Direct manipulation is one modality among many — NOT the thesis** (`editor-interaction.md`). Every value node carries, simultaneously, the modalities its type affords:

- **Grab on the body** (gestural, approximate) — reshape the region via its visible handle (§5.2).
- **Slider** (data-entry, approximate) — scrub by eye.
- **Numeric field** (data-entry, exact) — type `172 cm`, `cup D`, `age 24`. Drag and type are **co-equal on the same field** — same node, two precisions.
- **Nudge** (directional) — scroll / arrow on the focused value for a small step.
- **Keybind** — shown **inline on the value's visible affordance**, so you learn it through the modality you're already using and it graduates to eyes-free. No separate shortcut viewer, no tutorial.

All modalities write through the same **`apply_capped` choke** (`character-creator-and-body.md` §4), so a clamp shows identically whichever modality you used, and the write-back keeps the slider thumb, the numeric field, and the on-body shape reflecting the one clamped value (no desync).

### 5.1 What survives from unshape's vocabulary

Only **Mirror**. Editing one side and having the other follow is a real creator need and already ships (`_mirror`, default ON, with `RegionSliders.twin`). It stays as a **per-value link state**, not a global mode: a focused lateral value shows a mirror toggle inline; off = edit one side (mirror-off *is* the asymmetry affordance — no separate "vary-per-feature" concept). The radial/sibling-flick modality, `compare-variants`, and `promote-in-place` are **cut**: they assumed a sibling-direction map, a variants surface, or a per-value archetype-blend graph that the creator does not have. The genuine "audition and keep both" capability already exists as the branching history (§7) — we do not ship a second, redundant surface for it.

### 5.2 The on-body reshape affordance — explicit grab-handles

Disambiguating orbit-vs-reshape by focus + pointer-over-region mis-triggers (a drag is stolen as focus-nav; a drag over the focused head reshapes when you wanted to orbit). Replaced with a **visible, unambiguous handle**:

- **Focus a region** by clicking it (or selecting it in the dock / breadcrumb). The focused region gets a clear **focus outline** (ambient) and sprouts **a small set of explicit grab-handles** — directional nubs whose hover changes the cursor (`CURSOR_DRAG`).
- **Drag *on a handle* → reshape** (the gestural edit; same node the slider drives). **Drag anywhere else — empty space OR body surface away from a handle — → orbit.** Right-drag pans, scroll zooms, always. "Edit or camera move?" is answered by *what you grabbed*, visibly.
- **Defocus is obvious:** click empty space, press `Esc`, or use the breadcrumb back-edge — handles disappear and the whole body orbits freely.

**Handle hit tolerance.** Small face handles (nose, chin) on a rotatable body must be forgiving:
- **Screen-space pick radius** (~24 px, independent of drawn dot size and camera distance — a small visual nub with a large invisible hit disc). A press picks the nearest handle within that radius; only a press with no handle inside it starts an orbit. This is a 2D screen-pick, not a 3D surface raycast.
- **Grab-latch hysteresis.** The reshape/orbit decision is made **once, at press**, by the pick radius — never re-evaluated mid-drag. A latched reshape stays a reshape until release even if the cursor wanders; an orbit that began on empty space stays an orbit.
- **Cursor feedback.** Hovering inside a handle's pick radius switches the cursor to `CURSOR_DRAG` *before* the press, so the forgiving target is visible-by-feedback, not a guess.

---

## 6. The six pinned whole-body dials

The **six whole-body macro axes** — **gender presentation, age, height, build, muscle, proportions** (the headline axes of `body_state.gd:61–100`) — sit in a thin always-on bottom strip, **pinned** for muscle memory, editable in place with the same plural modality (height types `cm`; gender drags or types). They are the highest-frequency, no-region-locus edits — pinning is *earned by frequency* and these qualify by construction.

They are whole-body and non-spatial, so they cannot live in the anatomical region tree, and they cannot live in the top bar (commands only). Their home is here. The six are **a single coherent scannable group** (≤7, one chunk — a feminine-vs-muscular-vs-idealized whole-body decision is made in one place). The four physique-adjacent dials are genuinely orthogonal in the code and disambiguated on sight by their pole labels: **Build** (adiposity, light ⟷ heavy), **Muscle** (lean ⟷ muscular), **Proportions** (natural ⟷ idealized), plus Age and Height.

The limits control is NOT in the strip — it surfaces at the value (§8.4). The strip is **6 items**.

---

## 7. The screen — one coherent projection, body foregrounded

Per `affordance-types.md` (a canvas renders gestural / directional / ambient; commands appear as an overlay): the **body is the canvas** and the largest, central element. Global commands live in a **minimal top bar**; contextual affordances appear in **one compact dock beside the focused region** (only while a region is focused); lists open as **transient galleries** (§4.2). There are **no side walls** — no two opposing command slabs sandwiching the body.

```
┌──────────────────────────────────────────────────────────────┐
│ ☰ Create   ‹ Face › Jaw & chin ›        ⤺ History   Share  Open│  ← minimal TOP BAR (global)
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
│ gender ▮─○  age 24  height 172cm  build ▮─○  muscle ▮─○  prop ▮─○│  ← PINNED whole-body strip (6)
└──────────────────────────────────────────────────────────────┘
```

### 7.1 The body canvas (center)
The orbitable third-person body is the largest element and the primary editing canvas. Hover glows the value under the pointer and names it (keybind inline); the focused region shows grab-handles (§5.2); empty-space / non-handle drag orbits. Studio lighting + face-front default + centered pivot stand. Coarse + fine locality live here.

### 7.2 The top bar (global commands only)
A single thin bar, ≤6 items, all global, none contextual:
- **☰ Create** — the archetype gallery overlay (§4.2) + **Randomize** (§8.3) + **Open** (import) + **Save / Save-as-archetype**. The non-spatial start-from / save / load cluster is one menu, not a wall. Saved characters live here.
- **‹ breadcrumb ›** — the navigational back-edge through the region tree, always in the same place.
- **⤺ History** — opens the history overlay (§7.4 below references §7's history section, i.e. the History section).
- **Share** — export (§8.1), one click. **Open** — import (§8.1), one click (mirrors Share).

There are no "Looks" / "Realism" / "Saved" top-level junk-drawers. Eye color lives in the region tree; the limits control lives at the value; saved characters live in ☰ Create.

### 7.3 The contextual dock — appears only on focus
Renders **only** the focused node's children (the active-surface rule, §4): a region node shows its child regions + its value-nodes; a value gets its plural modalities (§5). It is a **small floating card beside the focused region**, not a full-height side wall, and **absent when nothing is focused** (no empty box, no persistent slab). The breadcrumb is the back-edge.

### 7.4 The entry / no-focus surface — itself scannable
At entry the user sees: the body, centered, in its default pose; the pinned strip (6 dials, §6); the top bar (≤6 global items); one ambient hint on the body ("click a part to shape it, or pick a starting body" + a **Start from a body** button opening the archetype gallery); and **no contextual dock** (nothing focused). Two distinct, spatially-separated groups, each ≤7; the 58-slider namespace never appears at entry.

### 7.5 Responsive + escape hatch
On a narrow window the dock and pinned strip collapse to edge-tabs overlaid on demand; the body stays foregrounded; the top bar stays. One **search/palette** (a single keybind) is the long-tail escape hatch — present, **rare**, never primary navigation. It indexes the human display names ("jaw drop", "face width") and global commands. Because the region tree makes normal face editing scannable by navigation, the palette is **not** load-bearing for ordinary editing — if a playtest shows users *living* in the palette to edit the face, that is a signal the tree failed.

---

## 8. History and per-feature handling

### 8.0 History — human labels, collapsed, branchable
History is a **branching tree** (DESIGN.md "lived history": explore an edit, back up, explore another, keep both). The UX fixes:
- **Human labels, never modifier-space.** A node reads "wider jaw," "taller (+6 cm)," "fuller chest," "leaner build," "started from Athletic" — the value's *display name* + a direction word, never `sculpt: nose-hump +0.20` or `age_years = 25`.
- **Collapse consecutive edits to the same value.** Ten grabs refining the jaw collapse to one node "shaped jaw" (net change). A new node opens only when the edited value changes or a non-edit op intervenes.
- **One home, one toggle.** History lives behind the single `⤺ History` affordance in the top bar (keybind inline), opening as an overlay. The branch nav is the linear spine + a `‹ i/n ›` junction selector, relabeled in human terms.

This is the creator's genuine "audition and keep both" capability (§5.1) — no second compare-variants surface on top of it.

### 8.1 Export / import — one Share, one Open
- **Share** (export) — **one** top-bar affordance. The format (JSON / image-with-embedded-history) is a *detail inside the one action*, defaulting to **image** (the thumbnail the gallery shows). The format choice is a save-time default in Settings + a single inline "also embed editable history" checkbox on the Share confirmation (default on where supported) — **not** a submenu or long-press. The shipped multi-format export path (`creator_io.gd`, PNG/JPG/WEBP) stays; the default is PNG-with-history.
- **Open** (import) — **one** top-bar affordance, accepting JSON or image, plus drag-a-file-onto-the-window. Applied raw (beyond-cap persists — `character-creator-and-body.md` §4.3).
- Symmetry: Share ↔ Open, side by side at the top-bar right.

### 8.2 Cup size — import the genuine cup-size axis (overturns the prior deferral)
The shipped "height / lift" axis is honestly *not* size (a render probe proved it is purely vertical redistribution — `region_sliders.gd:42–49` guard). This design **commits to the real axis**:
- **In scope:** import + vendor the **cup cube** (the 216-file macro factor-cube the mechanics doc confirmed un-vendored) and bind a single **Cup size** value-node in *Chest & breasts*, reading in plain small-to-large. A cup-letter readout is optional polish gated on mesh-measurement infra; the node ships with a plain scale either way.
- **This overturns two prior decisions, not just one deferral.** (1) The mechanics doc's "drive size via the volume axis" — `breast/breast-volume-vert-down|up` is no longer the size control. (2) The shipped `region_sliders.gd:42–50` guard already *contradicts* that claim (its render probe proved the volume axis does not change apparent size and labels it "height / lift"). This design **sides with the code** — once "volume = size" is retired, the cube is the **only** real size control. The "Lift" axis stays as its own correctly-labeled redistribution value-node.
- **Flagged as an architecture/build revisit** — cube vendor + factor-cube composition with gender/age/weight to be confirmed feasible before the node is final (§10). The value-node abstraction means once bound, no UX changes. If the import slips, the node is simply absent and "Lift" + "fullness" + "projection" remain as honest shape controls, none mislabeled as size.

### 8.3 Randomize — instant, coherent presentation
**One Randomize affordance** (in ☰ Create). It is **instant** (no heavy solver — the mechanics doc's bounded seeded walk). Coherence is guaranteed by both the seed *and* a bounded walk:
1. **Pick a presentation bucket** by weighted roll: *feminine* / *masculine* by default; *androgynous* only when the user has opted into it (a one-time preference, default off — androgynous-by-design is a deliberate, less-default choice, not mush to land on by accident).
2. **Seed from an archetype in that bucket** (feminine → `feminine-slim|curvy`; masculine → `masculine-lean|athletic|heavy`; androgynous → the two androgynous files only if opted in).
3. **Walk within the realistic range** around the seed through the choke (bounded, at extremeness 0 so it never goes extreme). The walk's **`masculinity` is clamped to the bucket band** — feminine stays ≤40, masculine stays ≥60, never crossing the 40–60 androgynous band (that band is reachable only by *picking* an androgynous archetype or opting it into random). All other axes walk freely within their realistic ranges.

Result: a plausible person of a *definite* presentation every roll — instant, one click; the result is a history node ("randomized"). Open tuning inputs (named, not hidden): bucket weighting (50/50 vs roster-proportional) and the exact band edges (40/60 vs tighter) — taste tuning, §10.

### 8.4 Limits — a plain-language opt-in at the value, not a "Realism" dev-noun
The single global cap-widening unlock (`extremeness` + an allow-extreme boolean — `character-creator-and-body.md` §4) is surfaced **at the value**, not as a global "Realism" rail group (an abstract dev-noun a player does not think in):
- **By default, every control's range *is* its human/tasteful range** — the slider stops at the default cap. No global control, nothing to "set"; the limit is the control's own visible extent.
- **When a user pushes a value to its human edge,** the value node shows an ambient tick and a small inline opt-in **at the value: "Allow beyond-human extremes"** (a toggle). Flipping it widens *that control's* range toward its hard limit (mechanically the global `extremeness`/allow-extreme unlock, but presented and reached at the value, framed as an act, not a global noun).
- **Naming.** The string is **"Allow beyond-human extremes"** — chosen so it shares no noun with the **Proportions** axis (§8.5); "Proportions" means exactly one thing on the surface. There is no user-visible word "Realism," "extremeness," or "Stylized" anywhere.
- Lowering it never snaps existing values (the non-destructive ratchet). The underlying mechanic is unchanged — only how it is surfaced and named.

### 8.5 Naming — de-jargoned, user-facing throughout

| Internal / old surface | User-facing name |
|---|---|
| `masculinity` (0–100, feminine↔masculine) | **Gender presentation** (a *feminine ⟷ masculine* range; gender *identity* is separate, not a body morph) |
| `extremeness` / "allow extreme proportions" | *(no global noun)* — the per-value opt-in **"Allow beyond-human extremes"** (§8.4) |
| `proportions` ("uncommon ↔ idealized") | **Proportions** ("natural ⟷ idealized") |
| `weight` (50–150 %) | **Build** (light ⟷ heavy) |
| `muscle` (0–100 %) | **Muscle** (lean ⟷ muscular) |
| `age_years` | **Age** (in years) |
| `height_cm` | **Height** (in cm) |
| `T1 / T2 / T3`, "headline", "registry tree", "detail tier" | *(deleted — there are no tiers)* |
| `sculpt: nose-hump +0.20` (history) | **"shaped nose"** / the value's display name + direction |
| `breast/breast-volume-vert-down\|up` "height/lift" | **Lift** (an honest redistribution axis) — distinct from **Cup size** (§8.2, the imported cube) |

Pole labels everywhere are plain language ("close ⟷ wide", "soft ⟷ toned"), which `region_sliders.gd` mostly already does. The work is the headline axes + history + the limits framing + deleting the tier vocabulary.

### 8.6 Height — a real cm value-node; uniform scale KEPT
Height is a **uniform mesh scale on purpose** (`body_state.gd:91–100, 262–271`), recorded with a rationale (proportions change shape at fixed stature; height changes stature at fixed shape — genuinely independent). This design keeps the uniform scale and **exposes a genuine cm value-node**: drag (approximate) + a numeric field reading **cm** (exact), co-equal, driving `height_cm` (which `height_scale()` turns into the mesh scale). The user sets a stature, not a "scale." A real height *morph* (reversing the deliberate scale decision) is **flagged as a possible future body-mechanics revisit, not assumed** — if a playtest shows uniform-scale height reads wrong, that revisit is recorded here; the value-node abstraction makes a later scale→morph swap invisible to this UX. (§10.)

### 8.7 Iris / eyes — color is a value-node; round-iris not claimed fixed
Eye color is a value-node (procedural `iris_color`) under *Face › Eyes & brow* — a color affordance + a small preset gallery (the list carve-out). The shader already ships a round iris/pupil (`body_rig.gd:44–52`, `pupil_aspect: 1.0`). The user **observed** a non-round iris — that is a **render discrepancy to VERIFY in build** (rendered eye not matching the round param — a shader/UV/geometry issue), not an assumed-present defect with an assumed fix, and no UX node depends on it. No `gaze_dir` wiring (would double-count).

---

## 9. The build fixes to verify

These are the net-new build tasks this UX commits to, each to be playtested/verified before the surface counts as done:
- **Region tree** — re-shape `RegionSliders.GROUPS` into a tree; render one level at a time; assert ≤7 children at every node (§3).
- **Cheek-prefix generalization** — generalize `BILATERAL_PREFIX` / `resolve_full_names` so the `/`-prefixed `cheek/` family pairs into 4 midline-symmetric sliders; no new morph targets (§3.1).
- **Round-iris render check** — render the eye; if non-round despite `pupil_aspect 1.0`, file the render bug (do not bake a "fix" into the UX spec) (§8.7).
- **Randomize freeze** — confirm randomize is instant (the bounded seeded walk, no heavy solver) and never freezes the UI (§8.3).
- **Cup-cube import feasibility** — confirm the cube vendors and composes in the factor-cube before the Cup size node is final (§8.2, §10).

---

## 10. Quality bar

A surface is not done on green tests alone (CLAUDE.md Playtesting). Both kinds gate.

**UX-sense (playtested — run it and look; user-judged where taste):**
- **Nothing performative.** No control whose only job is to control the UI's verbosity; the active surface is observed to *emerge* from where you point/focus; the cut affordances are absent, not hidden.
- **Nothing jargon.** Every user-visible string is plain English; no "masculinity," "extremeness," "Realism," "Stylized," "tier," "registry"; history reads in human words. Grep the built UI strings for the banned vocabulary as an objective companion.
- **Every surface scans, at every level.** At every focus the dock shows ≤~7 heterogeneous affordances; the region tree is ≤7 children at every node; the entry/no-focus surface is counted (strip 6 + top bar ≤6 + one hint; no dock). A long *homogeneous* gallery is allowed and filterable.
- **Body foregrounded; no walls.** Verified on a render at two window sizes.
- **On-body reshape is unambiguous.** Grab-handles on the focused region; handle-drag reshapes, anywhere-else-drag orbits; defocus obvious; near-miss on a small face handle still grabs (pick radius); a started reshape stays a reshape until release.
- **Modality is plural.** A chosen value is editable by grab-on-body AND slider AND typed number AND nudge, all writing the same node, all reflecting the same clamp.
- **The six whole-body dials are all reachable** — each with a visible, usable home in the pinned strip.
- **Randomize lands coherent** — repeated rolls produce definite-presentation bodies (androgynous-default-off), no roll's walk drifts masculinity into the 40–60 band.
- **The composed whole** — an orchestrator/playtest pass drives the creator as a player (pick → nudge → grab-reshape → randomize → share → open) and reports cross-seam defects.

**Objective (agent-verifiable):**
- The active-surface rule is a pure function of focus; selecting a node shows exactly that node's children (count + identity asserted against the §3 tree data).
- The region tree exists and is ≤7-children at every node.
- History coalesces consecutive same-value edits to one node; every node label is human (no `=` / `+0.` modifier-space strings).
- One Share, one Open, one Randomize (count = 1 each); no global limits control (the opt-in is found only at a value).
- A value's modalities (grab / slider / type) produce byte-identical `BodyState` for the same target value (the choke makes them converge).
- The substrate gates from `character-creator-and-body.md` (cap enforcement, persistence round-trip, determinism, no-monster-by-default) are unaffected and still pass.

---

## 11. OPEN (honest — not faked)

- **Cross-set relevance ranking is unsolved.** "What does the user most likely want to do next," across the whole graph, is gated on usage data we do not have at launch. We ship **locality + pinning + within-set recency only**, and do not build a cold-start frecency ranker — the one place the affordance model itself says is unsolved, and the design refuses to fake it. Revisit once real usage exists.
- **Cup-cube import feasibility (§8.2).** Vendoring the cube and composing cup size with gender/age/weight is in-scope but not yet build-verified; committing it overturns both the mechanics doc's "volume = size" claim and the shipped guard. Until confirmed, the honest fallback is no fake-size node.
- **Height scale vs morph (§8.6).** Uniform scale is kept; the morph option is a possible future body-mechanics revisit, not an assumed fix. Playtest decides if it is ever needed.
- **Round-iris render discrepancy (§8.7).** The user observed a non-round iris though the param is round; a build-time render bug to VERIFY and (if real) fix in the renderer — not a UX-spec dependency.
- **Randomize bucket weighting + band edges (§8.3).** The coherence *guarantee* is delivered by the bound. What remains is taste tuning: bucket weighting, exact band edges, androgynous-opt-in framing.
- **The non-spatial ↔ spatial boundary.** Which axes pin vs surface on a region is judgment (the six whole-body dials pin; everything anatomical is region tree). A tuning input, not a law.
- **Empty intermediate tree nodes (§3).** Mouth and Eyes & brow have homes in the tree but thin contents until more named sliders land. Acceptable (they reflect reality) but flagged.
- **VR projection.** The plural-modality + region-node + grab-handle model is controller/grab-native in principle, but the world-space drag decomposition is unfinished design (`character-creator-and-body.md` §9). Flagged, not claimed.
