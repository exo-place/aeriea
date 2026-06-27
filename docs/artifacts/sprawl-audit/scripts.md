# Sprawl & Model-Amnesia Audit — `scripts/`

Scope: `scripts/body/tf/` (priority), `scripts/sim`, `scripts/body`, `scripts/interaction`,
`scripts/util`, `scripts/text`. `scripts/creator` noted shallowly (shelved). Severity:
**H**igh / **M**edium / **L**ow. Evidence is `file:line`.

---

## 1. Duplication

### 1a. splitmix64 PRNG duplicated — CONFIRMED (severity M)
`scripts/util/det_rng.gd` (`DetRng.next`/`below`/`range_inclusive`, lines 23-42) is a
byte-identical extraction of the inner `Rng` class in
`scripts/text/cxg_realizer.gd:47-82` (`next` 54-60, `below` 64-66). det_rng.gd's own
docstring says so: *"Extracted from the pattern proven in cxg_realizer.gd (Rng inner
class)"* (det_rng.gd:3). But the extraction was **never finished**: `DetRng` is referenced
only by `tf_applier.gd` (grep: the sole non-self importer). `cxg_realizer.gd` still carries
its private copy and was not migrated to the shared class. The same three magic constants
(`-0x61C8864680B583EB`, `-0x40A7B892E31B1A47`, `-0x6B2FB644ECCEEE15`) live in both files plus
a third copy inside `DetRng.seed_for`/`_mix` (det_rng.gd:49-61). This is the textbook
"finish migrations before building on top" failure: the substrate was extracted, one caller
moved, the origin left behind. Note: `cxg_realizer.Rng` also has a `pick()` weighted-draw
method (cxg_realizer.gd:70-82) that `DetRng` lacks, so a straight swap needs `pick` ported up
first. **Fix:** port `pick` into `DetRng`, replace `cxg_realizer.Rng` with `DetRng`, delete
the inner class. Quick-ish (one file, well-tested both sides).

### 1b. TF content registries — TWO parallel libraries (severity M, mostly justified)
`scripts/body/tf/tf_content.gd` (340 ln, `TfContent`) and `tf_library.gd` (826 ln,
`TfLibrary`) both define `biped()`-shaped subtree builders + a `registry()` of TF records.
They are **not pure copy-paste** — they serve different consumers:
- `TfContent` = the "MVP mechanism demo" set (~20 records, one per op-category); used by the
  test suites (`tf_system_test`, `tf_fluids_test`, `tf_size_test`) and `tools/tf_play.gd` /
  `tools/tf_playtest.gd` as the canonical base body (`TfContent.biped()` is THE base — even
  `tf_library_test.gd:47` builds its body from `TfContent.biped()`, not from `TfLibrary`).
- `TfLibrary` = the broad authored content set (~45 records across 8 categories); used only by
  `tools/tf_audit.gd` and `tf_library_test.gd`.

The overlap that IS redundant: the subtree builders are duplicated structurally —
`phallic_genital`/`vaginal_genital`/`breast_seg` (tf_content.gd:46-60) vs
`_penis`/`_vagina`/`_breast` (tf_library.gd:93-105) build the same segments with the same
tags/fluids; `quadruped_lower` (tf_content.gd:68-77) vs `_quad_barrel` (tf_library.gd:128-136)
are near-identical barrels. `_biped_pelvis` (tf_library.gd:533-538) re-hardcodes the base
body's pelvis subtree a third time (it also appears inline in `biped()` and is implied by
`TfContent.biped()`). **Fix (structural, needs a design call):** decide ownership — fold the
shared part-builders into one module (`body_graph` helpers or a `tf_parts.gd`) and let both
registries import them; OR retire `TfContent` to a `tests/fixtures`-style minimal body and make
`TfLibrary` the single shipped content source. Do NOT do this blind — the test suite is
pinned to `TfContent.biped()`'s exact ids, so a merge touches every TF test's assertions.

### 1c. describe paths — NOT duplicated (verified clear)
Checked: `tf_describe.gd` (body prose from the graph) vs `npc_realizer.gd` / `cxg_realizer.gd`
(NPC dialogue realization). Different domains, no shared describe logic. The plural/article
helpers in `tf_describe.gd` (`_plural`, `_article`, `_num_word`) are local and not duplicated
elsewhere. No action.

---

## 2. Dead / unused code & files

### 2a. `scripts/body/body_morph_demo.gd` — orphan demo (severity L)
Zero references from `scripts`/`tools`/`tests`. Referenced ONLY by
`scenes/body_morph_demo.tscn`, which is not in `tests/run.sh` `SUITES`, not the main scene,
not in any test. A standalone manual demo scene that nothing automated touches. **Fix:** either
register it as a documented dev scene in README or delete both `.gd` + `.tscn`. Low stakes.

### 2b. Orphaned applier op-vocabulary — `reparent`, `tag_remove`, `set_fluid_type` (severity L, amnesia-flavored)
`tf_applier.gd` implements eight effects. Three are dead weight in the sense that **no shipped
content uses them**:
- `reparent` (tf_applier.gd:173-184): grep for `"effect": "reparent"` in content → none. No
  test either. Pure speculative vocabulary.
- `tag_remove` (tf_applier.gd:192-193): no content uses it (only `tag_add` is used, e.g.
  `make_digitigrade`). The undo path for it exists (tf_applier.gd:462-471) but is never exercised
  by content.
- `set_fluid_type` (tf_applier.gd:195-196, 309-335): no content record uses it; only
  `tf_fluids_test.gd` drives it directly. Carries a full undo path.

These aren't bugs — they round out the op algebra and have tests — but they're
**implemented-then-unused** surface. Recommendation: keep `set_fluid_type` (tested, plausibly
needed), but flag `reparent` as the weakest (no test, no content, no undo-coverage by content).
Severity L; document as "op vocabulary reserved for future content" or trim.

### 2c. No other dead modules
Every other module in `sim`/`util`/`text`/`body` (excl. creator) has live references.
`motion_matcher.gd` LOOKS unreferenced by filename but is live via its `MotionMatcher`
class_name (`body_rig.gd:263,406`) — NOT dead. `tf_validator.gd` is intentionally never
called by applier/holder (it's the opt-in checker, §3.8) — by-design, not dead.

---

## 3. Model amnesia / inconsistencies

### 3a. THE PELVIS — vestigial cruft contradicting the converged model (severity H) ★
**Verdict: the `pelvis` segment is amnesia cruft and should be retired — folded into a
groin/lower-body tag arrangement, not kept as a named node.**

What it is: in `TfContent.biped()` the lower body hangs off a node literally id'd `pelvis`
(tf_content.gd:29-40), tagged `["pelvis","groin","lower_body"]`, carrying legs, butt, and the
two genital mounts. `TfLibrary._biped_pelvis()` (tf_library.gd:533-538) re-builds the same node.

Why it's cruft / amnesia — three converging failures:

1. **It is the single global id the model forbids, used everywhere as one.** The converged
   model says *"targeting by tags/relations/sets, NOT global ids."* Yet `pelvis` is targeted as
   a literal node id `~30 times` across both content files — every taur/naga/harpy/genital/tail
   graft says `"target_node": "pelvis"` (tf_content.gd:96,175,206,279;
   tf_library.gd:348,356,364,469,491,502,522,558,576,594,604,626,655,690,706,717,732,767,785,797,819...).
   `pelvis` is functioning as exactly the stable global mount-id the design says not to author
   against. Worse, `tf_library.gd:347` ("base of the spine") still says *spine* in a blurb while
   grafting onto `pelvis`.

2. **It collides conceptually with `body_core`/`lower_body`.** The model + describe layer
   (`tf_describe._form_alias`, tf_describe.gd:33-38) treats "lower body" as a *tag arrangement*:
   a barrel/serpent carries `body_core`+`lower_body` and that's what makes a taur/naga. But the
   biped's lower body is a *named node* `pelvis` that is `lower_body` but NOT `body_core`
   (tf_content.gd:29-30). So there are two incompatible representations of "the lower body":
   tag-arrangement (quadruped/naga) vs named-node (biped). `tf_describe.gd:28-29` even hard-codes
   an apology for this: *"A plain biped never has such a segment (its lower body is the pelvis,
   which is not body_core)"* — the describe layer is bending around the pelvis's special status.
   This is decision-didn't-propagate: the graph-of-generic-segments model never reached the base
   biped's lower body.

3. **It is the `pelvis` tag's only reason to exist, and that tag drives a broken TF.**
   `widen_hips` (tf_library.gd:224-231) gates on `has_tag pelvis` and does
   `prop_delta width_cm` on `all_tagged pelvis`. But the base pelvis segment has only
   `length_cm` (tf_content.gd:29) — no `width_cm`. `_prop_delta_one` reads absent props as
   `before=0.0` (tf_applier.gd:265), so it grows `width_cm` 0→14, and **nothing in
   `tf_describe.gd` ever reads `width_cm`** — so the TF silently "succeeds" with zero visible
   effect (see 3d). The one TF that exists *because* the pelvis tag exists is a no-op.

**Recommendation (structural, design pass first):** Retire the named `pelvis` node. Options to
weigh in a design pass: (a) rename it `lower_body`/fold its mounts onto a generic groin region
identified by the `groin` tag, with grafts targeting by tag/relation instead of the `pelvis`
id; (b) keep a biped lower-body node but tag it `body_core`+`lower_body` like the barrel so the
ONE representation of "lower body" is uniform and `_form_alias`'s biped apology
(tf_describe.gd:28-29) disappears. Either way: kill the `pelvis` tag, kill `widen_hips` or give
it a real prop the describer reads, and change content from `target_node:"pelvis"` to
tag/relation targeting. This is the biggest single structural item in the audit.

### 3b. The doc model is µL fixed-point + drivers/transitions; the code is mL ints + static ops (severity H, by-design-noted, do-not-fix) ★
`docs/decisions/dynamical-transformation.md` and `tf-depth-and-species.md` describe a
DRIVER/TRANSITION dynamical model: per-body driver timelines, `progress∈[0,1]` evolving under
named drivers, closed-form interpolation (dynamical-transformation.md:92-173), and volume stored
as **microlitres (µL = volume_ml×1000)** fixed-point (dynamical-transformation.md:198,242,429,
446-449,515,522 — e.g. `650000 µL`). NONE of this is in the code:
- No `driver`, `transition`, `progress`, or timeline anywhere in `scripts/body/tf/` (grep: zero
  hits). The code is the earlier STATIC-OP model: staged `prop_delta`/`fluid_delta` staircases
  driven by `sim_clock` ticks in `tf_holder.gd`, not a closed-form driver law.
- Volume is stored as **plain mL ints**, not µL: base breasts are `volume_ml: 650`
  (tf_content.gd:25), `INT_PROPS := ["volume_ml","band_cm"]` recast to mL ints
  (body_graph.gd:283), `tf_measure.diff_mm` consumes `volume_ml` as mL (tf_measure.gd:35). The
  µL×1000 resolution the doc justifies (dynamical-transformation.md:446-449) was never adopted.

Per the audit brief this mismatch is **noted, not to be fixed** — but it is the largest
amnesia surface by line count: two design docs describe a system the code does not implement,
and a future session reading the docs as spec would build against a model the engine isn't on.
**Recommendation:** add a one-line "STATUS: design-only, code is on the static-op model" banner
to the top of `dynamical-transformation.md` and `tf-depth-and-species.md` so the doc/code gap is
explicit and can't be mistaken for the live contract. (Doc edit, not code — out of this audit's
write scope but worth a follow-up.)

### 3c. `spine` remnants in TF content — comments/blurbs only, but live (severity L)
The model says "no special `spine` tag." The code mostly honors this, but **stale `spine`
language survived in comments that describe live behavior**:
- `tf_content.gd:170` comment: *"would FALSE out … the moment the barrel's `spine` tag lands"* —
  but the barrel never gets a `spine` tag; it gets `barrel`/`body_core`. The comment describes a
  tag that doesn't exist; the actual guard is on `has_tag barrel` (tf_content.gd:179). Misleading
  amnesia comment.
- `tf_library.gd:345,353,361` player blurbs: *"at the base of the spine"* — harmless flavor, but
  these tails graft onto `pelvis`, and the converged vocabulary dropped `spine`. Minor.
(The `spine` hits in `body_rig.gd`/`bdcc2_bone_map.gd`/`part_library.gd` are the MakeHuman
skeleton bone names — a DIFFERENT, legitimate `spine`, not the TF tag. Not amnesia.)
**Fix:** quick comment/blurb cleanup.

### 3d. TFs that silently no-op (severity M)
- `widen_hips` (tf_library.gd:224-231): grows `width_cm`, which no describer reads → invisible.
  See 3a.3. Either delete or add a `width_cm` band to `tf_describe._size_band`.
- `feminize` (tf_content.gd:273-288) grafts a 3rd breast **unconditionally** (no `when` guard,
  unlike its `tf_library.gd:709-723` sibling `feminize_parts` which is also unguarded on the
  breast graft) — applying `feminize` twice stacks `breast_c` id collisions / extra rows. The
  applier doesn't dedupe ids on graft (`body_graph.graft` just appends, body_graph.gd:207-213),
  so re-application produces duplicate-id bodies that `tf_validator` would flag
  (tf_validator.gd:19-21). Re-applicability of the part-op TFs is inconsistent: some guard with
  `when` (masculinize/feminize_parts), some don't (feminize). Amnesia across the two registries.

### 3e. Ordinal targeting in content — contradicts the model's "NOT ordinals in content" (severity M)
The model: *"targeting by tags/relations/sets (NOT global ids or ordinals in content)."* Yet
`tf_content.gd` ships three TFs targeting by ordinal index:
`remove_first_phallic` and `grow_first_phallic` use
`{"select":"nth_tagged","tag":"genital","kind":"phallic","index":0}` (tf_content.gd:219,231,235).
The comment even celebrates it: *"Proves nth_tagged ordinal targeting"* (tf_content.gd:212). The
mechanism (`_resolve_select` nth, body_graph.gd:194-198) is a legitimate engine capability, but
authoring CONTENT against `index:0` is exactly what the converged model says to avoid. Tension
between "the engine supports ordinals" and "content shouldn't author them." `tf_library.gd`'s
equivalent `remove_penis` correctly uses `all_tagged` (tf_library.gd:698-699) instead — so the
two registries disagree on whether ordinal targeting is acceptable in content. **Fix:** decide
the policy; if ordinals are demo-only, mark `tf_content`'s nth_tagged TFs as mechanism-proof
fixtures and keep content (`tf_library`) ordinal-free.

### 3f. Mount-id naming is positional/ad-hoc, not relational (severity L)
Genital mounts are named `genital_mount_a/_b/_c/_v` (tf_content.gd:34,37,206,279;
tf_library.gd:690,706,717,732). `_a`/`_b` are the base mounts, `_c` = "add a phallic", `_v` =
"add a vaginal" — an alphabetic-soup convention that encodes intent inconsistently (`_c` is
positional, `_v` is type-coded). The model favors RELATION tags (front/hind/left/right). Minor,
but it's the kind of un-propagated naming the brief asks about. Low priority.

---

## 4. Quick wins vs structural

### Quick wins (trivial, low-risk)
- **Q1** Finish the splitmix64 extraction (1a): port `pick` into `DetRng`, swap
  `cxg_realizer.Rng` → `DetRng`, delete the inner class. (M-value, S-effort.)
- **Q2** Strip stale `spine` comments/blurbs (3c): `tf_content.gd:170`, `tf_library.gd:345,353,361`.
- **Q3** Decide `body_morph_demo.gd`+`.tscn` (2b): register as dev scene or delete.
- **Q4** Add a `when` guard to `feminize`'s breast graft (3d) to match `feminize_parts`, OR
  document that `feminize` is single-shot.
- **Q5** Doc banner: mark `dynamical-transformation.md` / `tf-depth-and-species.md` design-only
  (3b). (Doc-only; out of code scope but cheap.)

### Structural (needs a design pass first — do NOT single-shot)
- **S1 ★ Retire the `pelvis` node + tag (3a).** The biggest item. Unify "lower body" on one
  tag-arrangement representation; convert ~30 `target_node:"pelvis"` grafts to tag/relation
  targeting; remove/fix `widen_hips`; delete `tf_describe.gd`'s biped-pelvis apology
  (tf_describe.gd:28-29). Touches both registries and every TF test pinned to `pelvis`. Design
  pass required.
- **S2 Consolidate the two TF registries' shared part-builders (1b).** Decide ownership
  (shared `tf_parts.gd` vs retire `TfContent` to a fixture); the test suite is pinned to
  `TfContent.biped()` ids, so this is a coordinated refactor, not a delete.
- **S3 Settle the ordinal-in-content policy (3e)** and the orphaned-op policy (2b) — small
  design calls that resolve the registry-to-registry disagreements.

### Out of scope (noted only)
- `scripts/creator` (shelved): obvious cruft is the parallel describe/IO surfaces and the
  `.uid` churn in git status, but per brief no rework proposed.
- The driver/transition dynamical model (3b): design-only by acknowledged intent; not a defect
  to fix, only a banner to add.
