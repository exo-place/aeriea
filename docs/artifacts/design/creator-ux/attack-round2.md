# Attack — Round 2: adversarial UX/taste review of creator-ux/SYNTHESIS.md (v2)

Status: **HOSTILE REVIEW. Findings only, no pass verdict, no blessing.** Each finding is
grounded in the v2 design text, the affordance model it cites, the round-1 attack it claims
to answer, and the actual aeriea code/decision-doc it must run against. Ranked
BLOCKER / MAJOR / MINOR. Where I attacked something and could not break it, that is stated
explicitly at the end with evidence — the discipline is "do not inflate, do not go soft."

What I read in full: SYNTHESIS.md (v2); attack-round1.md; affordance-surfaces /
affordance-types / interaction-graph (rhizone, all three full); editor-interaction /
projection-model (unshape, both full); region_sliders.gd (full), body_state.gd
(headline-axis + height sections), character_creator.gd (sculpt/orbit/drag input handler,
pick path), body_rig.gd (eye params), the archetype roster (7 files, masculinity values
read), modifier_registry.json (291 modifiers, per-family counts), and
docs/decisions/character-creator-and-body.md (cap model, breast-size §6.2, height §4).

---

## Round-1 fixes — verification verdict (did the BLOCKER/MAJOR fixes actually hold?)

| R1 finding | v2 treatment | Held? |
|---|---|---|
| B1 region tree fiction | §1.4 builds a real tree, every leaf mapped to an existing spec, in-scope build work | **Mostly held** — see MINOR m1 (count error) and MAJOR M-A (orphaned axes), one mislabeled node (m2) |
| B2 height contradicts uniform-scale decision | §6.6 keeps uniform scale, exposes cm value-node, flags morph as future revisit | **Held** — honest, feasible against `height_scale()` |
| M1 command-rail wall | §4 drops the rail; dock floats on-focus, thin top bar + thin strip | **Held** — no permanent side wall (see note in "could not break") |
| M2 "Realism" jargon | §6.4 deletes the global noun; per-value "Allow beyond-human proportions" | **Held on naming**, but the new string has its own problem (MINOR m3) |
| M3 radial flick | §3 cuts it | **Held** — gone |
| M4 compare-variants / promote-in-place / vary-per-feature | §3.1 cuts all three; keeps only mirror | **Held** — no dangling refs found (verified) |
| M5 randomize androgynous mush | §6.3 presentation-bucket, androgynous opt-in-off | **Mostly held** — see MINOR m4 (a residual coherence gap) |
| M6 focus-based orbit-vs-reshape | §3.2 explicit grab-handles, drag-handle=reshape else orbit | **Held** — feasible against `_pick_body`; one residual (m5) |
| M7 entry surface wall | §4.5 counts entry surface; strip 4 + top bar ≤6 + 1 hint | **Held** — but undercounted (see M-A: the strip is missing two axes it needs) |
| M8 fake cup-size slider | §6.2 cuts the relabel, commits cup-cube import, no fake interim | **Held** — honest; the fake is genuinely refused |

The v2 substantially repaired the round-1 catalogue. The remaining defects below are partly
**new** (introduced by v2's own moves) and partly **residual** (a round-1 fix that papered
one hole and opened an adjacent one).

---

## MAJOR

### M-A. Two of the six headline axes — **Muscle and Proportions — have no home in the UX.** Orphaned affordances.

The body's headline macro axes in the code are **six**: `age_years`, `masculinity`,
`muscle`, `weight`, `proportions`, `height_cm` (`body_state.gd:61–100`). The design renames
all of the user-relevant ones in §6.5 — including **`muscle` → "Muscle" (lean ⟷ muscular)**
(line 535) and **`proportions` → "Proportions" (natural ⟷ idealized)** (line 533). So both
are first-class, kept, user-facing axes.

But the UX never gives them a surface:

- The **pinned strip** (§2 whole-body grain, §4.4) holds exactly **four** items: "gender,
  age, height, build" (§4.4 line 376; the §4 ASCII line 338; §4.5 entry count "4 items:
  gender, age, height, build"). The design is emphatic the strip is **4** ("so the strip
  stays at **4 items**", line 381). Muscle and Proportions are not in it.
- The **region tree** (§1.4) is anatomical regions only — Muscle and Proportions are
  whole-body, non-spatial, no region locus. They cannot live there.
- The **top bar** (§4.2) is five global *commands/navigation* (Create / breadcrumb /
  History / Share / Open) — explicitly "≤6 items, all global, none contextual," no value
  nodes. They cannot live there.
- §1.1's own enumeration of non-spatial value-nodes that "have no region locus" and get a
  home in §4.4 reads: "gender presentation, age, height, build, eye color, the limits
  control, presets" — **Muscle and Proportions are conspicuously missing from the list.**
  Eye color is routed to the region tree (Eyes & brow); the limits control surfaces at a
  value; presets live in the Create menu. There is **no clause anywhere** that places Muscle
  or Proportions.

This is the `interaction-graph.md` **"Orphaned affordances — features that exist but connect
to nothing; dead ends in the graph"** failure, applied to two of the most basic body dials a
character creator has (muscularity and idealization). A user who wants to make the body more
muscular cannot, in the UX as written, find the control: it is renamed in a table and placed
nowhere. Either the strip is actually **6** (and §4.4/§4.5's "4" and the Miller count are
wrong, and the entry-surface recount M7 claimed to fix is undercounted), or these two axes
need an explicit home the design forgot to give them. As written it is an internal
contradiction (renamed-but-unplaced) and a genuine usability hole. This is the one finding
that rises to MAJOR: it is not cosmetic, it breaks reachability of core controls and it
falsifies the §4.5 entry-surface scannability recount that was the M7 fix.

**Why major, not blocker:** the fix is small (decide the strip is 6, or add a "Build &
proportions" pinned sub-cluster, or route them into a Create-menu "whole-body" group) and it
does not invalidate the architecture — but as the document stands the controls are
unreachable and a counted surface is miscounted, so it cannot ship as written.

---

## MINOR

### m1. Region-slider count is wrong again — **58, not 56.** Same staleness class round-1 flagged.

Round-1's m1 caught "11 groups vs 10". v2 fixed the group count (correctly says 10 now,
§1.4 line 122). But it now asserts the **slider count as 56** twice — §1.1 line 84 "the 56
region sliders," §2 line 192 "The 56 sliders never appear at once." The actual table is
**58**: per-group 8+3+2+5+5+7+9+3+12+4 = 58 (`region_sliders.gd` GROUPS;
`RegionSliders.count()` sums these). Minor as a number, but it is the *same* category of
defect round-1 named — a count written from a remembered/assumed structure, not the current
file — and it appears in the load-bearing "the N sliders never appear at once" claim. Read
the file and use the real count (or `count()`).

### m2. The "Skull & cheeks" node contains **zero cheek parameters** — a mislabeled node.

§1.4 line 142: `Skull & cheeks ← head-scale-horiz/vert/depth, head-fat, head-age`. Every
one of those is a `head/*` modifier (`region_sliders.gd:114–118`). The registry has a
genuine, separate **`cheek` family of 8 modifiers** (verified: `cheek/*` ×8 in
modifier_registry.json) — **none** of which is in this node, and none is a named slider
anywhere. So a node titled "Skull & cheeks" offers face width/height/depth/fullness/age and
no cheek control at all. A user opening "Skull & cheeks" to adjust cheekbones finds nothing
about cheeks. The §1.4 "empty intermediate nodes are honest" carve-out covers Mouth and
Eyes — it does **not** cover a node whose *name advertises a body part it has no control
for*. Either drop "& cheeks" from the label (it is really "Skull / head proportions") or
populate it with cheek sliders (the registry has them). As written it is a small
name-vs-content lie of exactly the kind §0 set out to kill.

### m3. The one surviving limits string — **"Allow beyond-human proportions"** — collides with the **"Proportions"** axis name and is mildly clinical.

§6.4 lands the limits opt-in as the single string **"Allow beyond-human proportions."** This
is a real improvement over "Realism." But two small taste snags:
- The word **"proportions"** is *already* a distinct, renamed user-facing axis ("Proportions:
  natural ⟷ idealized," §6.5 line 533). The same noun now means two different things on the
  same surface — the macro proportion-envelope dial, and the cap-unlock act. A user toggling
  "Allow beyond-human proportions" may reasonably think it is about the Proportions dial. The
  collision is avoidable ("Allow beyond-human extremes" / "Let me push past lifelike" — the
  design's own §6.4 parenthetical phrasing is actually clearer than the chosen string).
- "beyond-human proportions" is faintly clinical. Defensible, but the design's own quality
  bar (§7) says "read by someone who has never seen the code and is plain English" — worth a
  taste pass against the bar it sets itself. Minor, not blocking.

### m4. Randomize bucket is more coherent but the **within-bucket walk can still cross presentations**, and the design does not bound it.

§6.3 is a real fix to round-1's M5: pick feminine/masculine bucket → seed an in-bucket
archetype → bounded walk. The androgynous archetypes are correctly demoted to opt-in. But
the coherence claim ("a plausible person of a *definite* presentation every roll") is only as
strong as the walk's bound on `masculinity`. The feminine seeds are at masculinity 22/24 and
the masculine seeds at 72/74/76 (verified in the roster); the walk is "within the realistic
range around that seed through the choke (bounded, at extremeness 0)." Nothing in §6.3 states
the walk is bounded *away from the androgynous midline* — a feminine seed at 22 walking
"within the realistic range" toward 40–50 lands exactly in the androgynous zone the design
says it avoids. The bucket fixes the *seed*; it does not state a constraint on the *walk's*
masculinity excursion. This is one tightening short of the coherence guarantee it asserts.
The §8 open item names "bucket weighting 50/50 vs roster-proportional" but **not** "does the
walk stay in-presentation" — which is the actual remaining coherence risk. Name and bound it.

### m5. Grab-handle scheme is feasible and the right call, but the **"handle vs body-surface" hit test is unspecified at the exact place it matters** (small handles on a rotatable body).

§3.2 is a genuine improvement over round-1's M6 (explicit visible handles; drag-handle =
reshape, drag-else = orbit; obvious defocus). It is feasible: `_pick_body` already raycasts
the morphed surface (`character_creator.gd:920`, and the B2-correctness commit a995f15 made
the picker raycast the morphed mesh). The residual: the disambiguation rule is "drag *on a
handle* → reshape; drag the body surface away from a handle → orbit." On a small region
(nose, chin) the handles are small screen targets sitting *on* the body; a near-miss drag
that the user intends as a reshape becomes an orbit, and there is no stated hysteresis,
hit-padding, or snap-to-nearest-handle. The old `_sculpt_mode` had a coarse "hit body =
morph" rule with a large target; the handle rule trades that for precise small targets with
no specified tolerance. Likely fine with generous hit-padding — but the design should say so,
because "drag anything not-a-handle orbits" is unforgiving on a face. Spell out the handle
hit tolerance / cursor-feedback radius. (Minor: the architecture is right; the ergonomic
detail is unstated.)

### m6. The cup-size commitment is honest, but it **silently overrides a shipped code decision**, not just the decision-doc deferral it flags.

§6.2 correctly flags that committing the cup cube "revisits a deferral" in decision §6.2.
That much is honest. But the situation in the substrate is one layer deeper than §6.2
acknowledges: the **decision doc and the shipped code already disagree.** Decision §26/§187
says size *is* driven by `breast/breast-volume-vert-down|up` ("the live size control"),
whereas `region_sliders.gd:42–50` — after a render probe — relabels that exact axis
"height / lift" and its guard states it does **not** change size. The synthesis sides with
the code (calls it "Lift," correctly), which is the right call — but it presents this only as
"revisiting a deferral," when it is also *resolving a live contradiction between the decision
doc and the shipped slider table.* The design should name that the decision doc's §187
"drive size via volume axis" line is **already falsified by the shipped guard**, so the cup
cube is not merely an "upgrade path" (decision §190's framing) but the *only* real size
control once §187's claim is retired. Minor because the design's *conclusion* is correct and
honest; the flag just understates which prior decision it is overturning.

---

## Re-attacked and could NOT break (stated for completeness, with evidence)

These were probed hard and held; not blessed, just not broken.

- **B2 / height (§6.6).** The cm value-node is feasible: `height_scale()` already turns
  `height_cm` into a uniform mesh scale (`body_state.gd:266–271`); a cm field that reads/writes
  `height_cm` is a thin binding over existing code, no morph needed. The design honestly keeps
  the uniform scale and flags morph as a *future* revisit rather than asserting a nonexistent
  fix — the exact round-1 B2 complaint, now resolved. No contradiction with the decision doc.
- **M1 / layout (§4).** I tried to find a renamed wall. There isn't one. The contextual dock
  is "absent when nothing is focused" (§4.3) and "a small floating card beside the focused
  region, not a full-height side wall." The top bar is one thin ≤6-item bar; the pinned strip
  is one thin bottom strip. The body is the largest element. A thin top bar + thin bottom
  strip is not the "two opposing slabs sandwiching the body" of round-1's M1 — those were two
  *full-height* command panels. This is a genuine fix, consistent with `affordance-types.md`
  ("a canvas renders gestural/directional/ambient; commands appear as an overlay"). (The only
  layout-adjacent defect is M-A: the strip is undersized, not that it is a wall.)
- **M3 / M4 / cut affordances.** Radial-flick, compare-variants, vary-per-feature,
  promote-in-place are all cut (§3, §3.1) and I grepped the document for dangling first-class
  references to them — there are none; they appear only in the "what is cut and why" accounting.
  The mirror retention is grounded in shipped code (`_mirror` default ON, `RegionSliders.twin`).
  This is a clean removal, not a rename.
- **M8 / cup fake.** The design explicitly refuses to ship a cup-letter readout over a
  redistribution proxy ("We do **not** ship a cup readout over a redistribution proxy in the
  meantime; if the cube import slips, the node is simply absent"). The round-1 footgun is
  genuinely disarmed. (See m6 for the one understated nuance.)
- **Faked-relevance / openness.** §2.3 + §8 still refuse the cold-start frecency ranker, scope
  to "locality + pinning + within-set recency only," and cite the model's own OPEN flag
  (`affordance-surfaces.md` "Filtering vs prioritization"; `interaction-graph.md` "What does
  the user most likely want to do next"). I checked for a smuggled ranker elsewhere (dock
  order = region order, top-bar = authored, strip = pinned/fixed) — none. This remains the
  cleanest part of the design, and v2 did not regress it.
- **Region-tree Miller compliance (§1.4), modulo the count error.** Every level is ≤7
  *children*: top = 5, Face = 6, Torso = 5, Legs split to 4 + 5, leaf sets ≤8 (Breasts 8,
  the one at the ceiling). Every leaf maps to a real `region_sliders.gd` spec or a real
  headline axis (verified against GROUPS). The empty Mouth / color-only Eyes nodes are flagged
  honestly and the registry genuinely has the raw mouth (22) / cheek (8) / chin (7) / nose
  (21) / eyes (34) families reachable by on-body grab (verified). The tree is grounded; the
  one mislabeled node (m2) and the count slip (m1) are the only cracks.
- **Eye / round-iris (§6.7).** `body_rig.gd:44–52` ships `pupil_aspect: 1.0` ("round
  (human)"). The design correctly *withdraws* the round-iris "fix" claim and records the
  user's observation as a render discrepancy to VERIFY, depending on no UX node. Honest.

---

## Verdict

v2 is a large, mostly-honest repair of round-1: both blockers are genuinely resolved, the
worst majors (the corner-scatter wall, the imported sister-tool vocabulary, the fake
cup-slider, the radial gimmick) are cut or grounded, and the one thing round-1 praised
(refusing a cold-start ranker) is preserved intact.

**One MAJOR remains:** Muscle and Proportions are renamed as user-facing axes but given no
surface anywhere (M-A) — they are orphaned controls, and their omission also falsifies the
§4.5 entry-surface count that was the M7 fix. That must be resolved before the design is
buildable as written.

The remaining six findings are MINOR: a stale slider count (m1), a mislabeled "& cheeks" node
(m2), a "proportions" name collision in the limits string (m3), an unbounded
within-bucket randomize walk (m4), an unspecified grab-handle hit tolerance (m5), and an
understated decision-doc override on cup size (m6). None blocks; all are cheap to fix.

No additional BLOCKER found. The design is close — close enough that the gap between it and
"buildable" is M-A plus six small tightenings, not a redesign.
