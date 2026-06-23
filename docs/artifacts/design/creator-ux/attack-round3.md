# Attack — Round 3: adversarial UX/taste review of creator-ux/SYNTHESIS.md (v3)

Status: **HOSTILE REVIEW. Findings only, no pass verdict, no blessing.** v3 is a
thrice-revised, heavily-hardened design (round-2 returned 0 blocker / 1 major / 6 minor,
all folded). The discipline for this round was explicit: do **not** manufacture, inflate,
or reach for speculative findings to hit a quota; "no blocker, no major" is the honest
expected-possible outcome and is to be stated plainly if true. Every finding below is
grounded in the v3 text, the affordance model it cites, the prior attacks it claims to
answer, and the actual aeriea code/decision-doc it must run against. Where I attacked
something hard and could not break it, that is stated at the end with evidence.

What I read in full: SYNTHESIS.md (v3); attack-round1.md; attack-round2.md;
affordance-surfaces.md (rhizone, full); region_sliders.gd (full); body_state.gd
(headline-axis + height sections); body_rig.gd (eye params); character_creator.gd
(sculpt/orbit/pick/mirror paths, greps); modifier_registry.json (cheek family enumerated +
counted); the archetype roster (7 files, masculinity values read); and
docs/decisions/character-creator-and-body.md (§26 / §187 / §189 / §190 breast-size, §4
height/caps).

---

## Round-2 fix verification (did the one MAJOR and six MINORs actually hold?)

| R2 finding | v3 treatment | Held? (verified against substrate) |
|---|---|---|
| **M-A** Muscle & Proportions orphaned (renamed, placed nowhere) | Pinned strip is now the **full 6 body-wide dials** (gender, age, height, build, muscle, proportions); §1.1, §2, §4.4, §4.5, §7 all updated | **HELD — genuinely.** All six map to `body_state.gd:61–100` real axes (`age_years`, `masculinity`, `muscle`, `weight`, `proportions`, `height_cm`, verified). No orphan; both controls reachable; the entry-surface recount (§4.5) is consistent at 6. See "could not break" for the residual scan-pressure probe (it passes). |
| **m1** slider count 56 → should be 58 | "58" everywhere (§1.1, §2, §4.5) | **HELD.** `region_sliders.gd` GROUPS sum = 8+3+2+5+5+7+9+3+12+4 = **58** (verified, matches `count()`). |
| **m2** "Skull & cheeks" had zero cheek params | Splits into **Skull** (head/*) + **Cheeks** (cheek/* family); §1.4 | **HELD on intent / content** — the registry genuinely has a `cheek` family (verified 8 axes: 4 stems × L/R). But the *binding-mechanism* claim is inaccurate against the code — see **m3 (new/residual)** below. The name↔content lie is fixed; one feasibility sentence overstates the substrate. |
| **m3** "Allow beyond-human proportions" collided with the Proportions axis | Renamed **"Allow beyond-human extremes"**; §6.4, §6.5; collision called out explicitly | **HELD.** No shared noun with any axis; "Proportions" now means exactly one thing. Banned-word grep in §7 covers Realism/extremeness/Stylized/tier/registry. Clean. |
| **m4** randomize within-bucket walk could cross the androgynous midline | Walk's `masculinity` **clamped to the bucket band** (feminine ≤40, masculine ≥60, never the 40–60 band); §6.3 | **HELD.** Roster seeds (feminine 22/24, masculine 72/74/76 — verified) sit inside their bands with room; the bound is stated and the open items (§8) are honestly demoted to taste tuning (weighting / band edges), not coherence. |
| **m5** grab-handle hit tolerance unspecified | §3.2 specifies **~24 px screen-space pick radius** (2D, camera-distance-independent), **grab-latch hysteresis** (decision once at press, never mid-drag flip), cursor feedback before press | **HELD.** Feasible against `_pick_body` (which already raycasts the morphed surface, `character_creator.gd:535`); the screen-space radius is a reasonable, concrete spec, not a hand-wave. |
| **m6** cup-size overturns a shipped code decision, not just a deferral | §6.2 states plainly it overturns **BOTH** decision §187 ("volume axis = size") **AND** the shipped `region_sliders.gd:42–50` guard | **HELD — and verified true.** Decision §26/§187 literally say `breast/breast-volume-vert-down|up` is "the live size control"; the shipped guard (`region_sliders.gd:42–49`) says a render probe proved that exact axis does NOT change size and labels it "height / lift". The two artifacts genuinely contradict; v3 names it correctly and sides with the code. |

**Eleven prior R1/R2 BLOCKER/MAJOR items (B1, B2, M1–M8, M-A) all remain resolved in v3**
(re-checked, not assumed; see "could not break"). The substrate-facing claims are mostly
honest. The residue below is one new/residual MINOR and a short list of confirmed-clean
load-bearing items.

---

## BLOCKER

**None.** I attacked the headline interaction (region-tree locality), the layout (no-wall
claim), the modality plurality, the randomize coherence guarantee, the cup-size honesty,
the height decision, and the entry-surface scan count against the actual code, the
decision doc, the roster, and the affordance model. Every one held. There is no defect
that makes the creator un-buildable or that contradicts the architecture.

## MAJOR

**None.** The one MAJOR carried from round 2 (M-A, the orphaned Muscle/Proportions dials)
is genuinely resolved: both are now first-class members of the pinned 6-dial strip, each
mapping to a real `body_state.gd` axis, with §1.1/§2/§4.4/§4.5/§7 all made consistent and
the entry-surface count honestly re-tallied. A user wanting a more muscular or more
idealized body now has a visible, stable home for the dial. I probed the new 6-dial strip
hard for a fresh scan failure and could not produce one (see "could not break" — the
"4 distinct build-ish dials confusing?" attack does not rise to MAJOR; it is the MINOR
below at most, and even there it is weak).

## MINOR

### m3 (residual under R2-m2). The Cheeks split is the right call, but the stated binding mechanism is inaccurate against the code — `resolve_full_names` cannot pair the `cheek/*` family as written.

§1.4 (lines ~196–198) justifies the new **Cheeks** node thus: the cheek family's
"4 bilateral stems … each an L/R pair = 8 modifiers … bind as named sliders here **via the
existing bilateral-stem expansion** (`region_sliders.gd` `resolve_full_names` **already
pairs** `l-`/`r-` under one slider) … this is a *grouping/data* addition, **no new
modifiers**."

The first half is true and verified: the registry has exactly **8 cheek axes** — 4 stems
(`cheek-bones`, `cheek-inner`, `cheek-trans` [down|up], `cheek-volume`) × L/R, i.e.
`cheek/l-cheek-bones-decr|incr` … `cheek/r-cheek-volume-decr|incr` (enumerated and counted
against `modifier_registry.json`). So a Cheeks node of 4 midline-symmetric sliders is real
content, and the m2 name↔content lie is genuinely fixed.

But the *mechanism* sentence is wrong about the substrate. `resolve_full_names`
(`region_sliders.gd:156–165`) only expands a spec when:

```gdscript
if spec_name.begins_with("l-") and not spec_name.contains("/"):
    var stem := spec_name.substr(2)
    out.append("%sl-%s-decr|incr" % [BILATERAL_PREFIX, stem])   # BILATERAL_PREFIX := "armslegs/"
    out.append("%sr-%s-decr|incr" % [BILATERAL_PREFIX, stem])
```

Two facts make the design's claim false as written:

1. **The cheek modifiers contain a `/`.** They are `cheek/l-cheek-bones-decr|incr`, not a
   bare `l-cheek-bones`. The guard `not spec_name.contains("/")` means a literal cheek
   full_name is **never** expanded — it falls through to the single-literal branch (one
   slider drives one side only). So referencing the registry name directly gives you a
   *one-sided* cheek slider, not the promised midline-symmetric pair.
2. **The expansion prefix is hardcoded to `armslegs/`.** Even if you fed the bare stem
   `l-cheek-bones` (to satisfy the `not contains("/")` guard), `resolve_full_names` would
   expand it to **`armslegs/l-cheek-bones-decr|incr`** — a modifier that does not exist
   (cheeks live under `cheek/`). `BILATERAL_PREFIX` is a single constant, not a per-stem
   lookup; it cannot reach the `cheek/` group.

So pairing the cheek family into 4 symmetric sliders is **not** "no new modifiers via the
existing expansion." It requires a small code change: generalize `BILATERAL_PREFIX` from
one hardcoded `"armslegs/"` constant into a per-stem prefix (or teach `resolve_full_names`
to accept an already-`<group>/`-prefixed stem and pair `l-`↔`r-` within it). That is cheap
— and note `twin()` (the *mirror* map, lines 180–196) **already** does generic `l-`↔`r-`
flipping across any `<prefix>/` group, so the capability exists in the file, just not in
the structural-pairing function the design pointed at.

**Why only MINOR, not MAJOR:** the *design conclusion* is sound — the Cheeks node is real,
its content exists, and the build cost is a few lines to generalize one prefix constant.
The defect is a single inaccurate feasibility sentence ("via the existing `resolve_full_names`
… no new modifiers") that overstates what the shipped function does — the same
write-from-memory-not-from-the-file class the prior rounds flagged on counts (m1×2). Fix:
in §1.4, change the Cheeks justification to state honestly that the cheek family binds by
**generalizing the bilateral-stem prefix** (today hardcoded to `armslegs/`) to cover
`cheek/` — a small grouping-table + one-constant code change, still no new *morph targets* —
rather than claiming `resolve_full_names` already pairs them. (It pairs `armslegs/` stems
only.)

---

## Fresh hard-taste pass (new v3 surface area) — attacked, did not break

The brief asked specifically about the new v3 moves. I attacked each and could not produce
a blocker or major; recorded here with evidence so the "no major" verdict is auditable.

### The 6-dial pinned strip — does 6 still scan? Is build/weight/muscle/proportions confusing as 4 distinct dials?

Probed hard; it holds.
- **Six scans.** Six is inside Miller's bound, and `affordance-surfaces.md` ("stability
  earned per-item" + "what a good surface looks like") explicitly permits a *coherent
  pinned group* of ≤7. The six are one semantic chunk — "the whole-body decision made in
  one place" (§4.4) — not six unrelated commands. The §4 ASCII renders them as one strip,
  spatially distinct from the top bar (a second group). This is the "grammar of groups"
  the source endorses, not the ribbon's "6 groups × 8 commands" wall.
- **The four build-ish dials are NOT confusable in practice.** I specifically tried to
  break "build vs weight vs muscle vs proportions read as four overlapping things":
  - **Build/Body softness** = adiposity (`weight` 50–150%, "light ⟷ heavy"), `body_state.gd:78–82`.
  - **Muscle** = muscle mass (`muscle` 0–100, "lean ⟷ muscular"), `body_state.gd:73–77`.
  - **Proportions** = within-form envelope (`proportions`, "natural ⟷ idealized"),
    `body_state.gd:83–90`.
  These are three *genuinely orthogonal* morph axes in the code (fat vs muscle vs
  proportion-envelope — each a distinct factor-cube contribution), and the user-facing pole
  labels (soft⟷heavy / lean⟷muscular / natural⟷idealized) disambiguate them on sight.
  "Build" and "Muscle" being adjacent is *correct* — a player thinking about physique wants
  both side by side. The §6.5 naming table keeps each to one plain meaning. There is a mild
  taste note that "Build (macro) / Body softness" carries a parenthetical that should
  resolve to ONE shipped label before build (the table lists two), but that is a string
  cleanup, not a confusion that breaks the strip — flagged here, not escalated.

### The Skull/Cheeks split — does Face still scan at ≤7?

Holds (modulo m3's binding-mechanism wording). Face after the split = **7 children**
(Jaw & chin, Nose, Mouth, Eyes & brow, Skull, Cheeks, Face shape) — counted, ≤7. Skull = 5
(width/height/depth/fullness/age), Cheeks = 4 (bones/fullness/height/depth) — both well
under. The split is the right move (a 9-leaf node would be over Miller); it is justified by
real content. The only crack is the m3 binding sentence, not the tree shape.

### The renamed limit toggle ("Allow beyond-human extremes")

Holds. No noun shared with any axis (the m3-collision is gone — "Proportions" is now
singular on the surface); surfaced at the value, not as a global rail noun; the underlying
mechanic (one global `extremeness` unlock, decision §4) is honestly disclosed as unchanged.
The §7 banned-word grep enforces it objectively. I could not find a re-leak of "Realism,"
"extremeness," or "Stylized" anywhere in the spec.

---

## Re-attacked from scratch and could NOT break (load-bearing, with evidence)

These are the things the verdict rests on; each was probed adversarially and held.

- **Region-tree locality (the old B1).** Every level ≤7 children: top = 5 (Face, Torso,
  Arms, Legs, Neck); Face = 7 after the Skull/Cheeks split; Torso = 5; Legs split to
  Thighs(4) + Lower legs(5); leaf sets ≤8 (Breasts 8, at the ceiling). Every leaf maps to a
  real `region_sliders.gd` spec or a real headline axis (verified against GROUPS, 58 total).
  The "Fine detail" junk-drawer is genuinely dissolved into Belly / Waist & hips — no orphan
  group. The empty Mouth / color-only Eyes nodes are flagged honestly (§1.4, §8) and the
  registry does carry the raw mouth/brow families reachable by on-body grab. The headline
  case ("drill Face → … → ≤7 values") is now real, as a grouping/data change — the one
  exception being the cheek-binding mechanism overstatement (m3).

- **The no-wall layout (old M1).** No renamed wall. The contextual dock is "absent when
  nothing is focused" (§4.3) and "a small floating card beside the focused region, not a
  full-height side wall." Top bar = one thin ≤6-item bar; pinned strip = one thin bottom
  strip of 6. Body is the largest element and the canvas. Consistent with `affordance-types.md`
  ("a canvas renders gestural/directional/ambient; commands appear as an overlay"). The §4
  ASCII does not sandwich the body between two slabs.

- **Plural modality, single choke (old singular-modality defect).** Grab / slider / numeric
  / nudge / keybind all write the same node through `apply_capped` (decision §4), so a clamp
  shows identically and there is no desync. The radial-flick gimmick stays cut; only mirror
  survives from unshape's vocabulary, grounded in shipped `_mirror` (default ON,
  `character_creator.gd:94`) + `RegionSliders.twin`. compare-variants / vary-per-feature /
  promote-in-place remain cut with no dangling first-class references (grepped).

- **Randomize coherence (old M5 / m4).** Seed in-bucket AND walk clamped to the bucket band
  (feminine ≤40 / masculine ≥60, 40–60 reachable only by deliberate pick). Roster seeds
  verified (feminine 22/24, masculine 72/74/76, androgynous 50/52). The androgynous
  archetypes are opt-in-off for random, not deleted. Open items honestly demoted to taste
  tuning (weighting, exact band edges) — the coherence *guarantee* is delivered by the bound,
  not left open.

- **Cup-size honesty (old M8 / m6).** v3 refuses a fake-size node; commits the real cube;
  states plainly it overturns BOTH decision §187 and the shipped guard. Verified: decision
  §26/§187 call `breast/breast-volume-vert-down|up` "the live size control," while the
  shipped `region_sliders.gd:42–49` guard says a render probe proved it does NOT change size
  and labels it "height / lift." The contradiction is real and v3 sides correctly with the
  code. The fallback (no node if the cube import slips) is honest.

- **Height (old B2).** Uniform scale kept on purpose (`body_state.gd:91–100`,
  `height_scale()` turns `height_cm` into a uniform mesh scale); a cm value-node is a thin
  binding over existing code, no morph asserted; the morph option flagged as a *future*
  body-mechanics revisit, not a claimed fix. No contradiction with the decision doc.

- **Round iris (old m2).** `body_rig.gd:44–52` ships `pupil_aspect: 1.0` ("round (human)").
  v3 correctly *withdraws* the "fix" claim and records the user's observation as a render
  discrepancy to VERIFY, depending on no UX node. Honest.

- **Faked-relevance / openness (the one thing every round praised).** §2.3 + §8 still refuse
  the cold-start frecency ranker, scope to "locality + pinning + within-set recency only,"
  and cite the model's own OPEN flag (`affordance-surfaces.md` "Filtering vs prioritization":
  *the gain is removal, not prioritization*; and the relevant-right-now framing). I checked
  for a smuggled ranker (dock order = region order; top bar = authored; strip = pinned/fixed)
  — none. Not regressed.

- **Entry-surface scan (old M7).** Counted: body (1 canvas) + pinned strip (6, one coherent
  chunk) + top bar (≤6) + one hint/button + no dock (nothing focused). Two distinct,
  spatially-separated groups each ≤7. The 58-slider namespace never appears at entry. The
  6-dial recount is internally consistent now (was the M-A falsification; resolved).

---

## Verdict

**No BLOCKER. No MAJOR.** This is the honest, expected-possible outcome, stated plainly and
not softened into invented work: v3 is a genuinely hardened design. The single MAJOR carried
from round 2 (orphaned Muscle/Proportions) is really resolved against the code, and all
eleven prior R1/R2 blocker/major items remain resolved on re-check.

**One MINOR (m3):** the Cheeks node is the right call and its content exists (8 cheek axes
verified), but the §1.4 sentence claiming it binds "via the existing `resolve_full_names` …
no new modifiers" is inaccurate — that function only pairs bare `l-` stems under the
hardcoded `armslegs/` prefix and cannot reach the `/`-prefixed `cheek/` family; pairing the
cheeks needs a small one-constant generalization (the `twin()` mirror map already does
generic `l-`↔`r-` flipping, so the capability is nearby). Cheap to fix; it is a feasibility
*wording* overstatement, not an architectural flaw.

Two sub-MINOR taste notes worth a string pass but not escalated: the "Build (macro) / Body
softness" naming-table entry should resolve to ONE shipped label before build; and the
empty Mouth / thin Eyes&brow nodes (already flagged in §8) will read as hollow until named
sliders land — acceptable, honestly disclosed.

The design is buildable as written once m3's one sentence is corrected to describe the
actual (small) binding work. Nothing here is a redesign.
