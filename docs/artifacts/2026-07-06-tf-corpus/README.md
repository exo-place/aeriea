# Transformation Corpus — 2026-07-06

Mined during the TF substrate design session. Purpose: ground-truth reference for what the
genre actually does, used to adversarially test whether the aeriea TF substrate is
expressive enough to author the range of transformations the genre contains.

---

## File index

### Primary — transformation corpus

These are the load-bearing files: concrete transformation instances, one per story or
item, covering the range of the genre.

**CoC catalog (`part-coc-source-pointer.md`)**

Corruption of Champions consumable items (~62 items, A–Z across the open-source AS3
codebase). The verbatim game strings and AS3 source are **not committed here** — they are
third-party open-source game text we prefer not to carry in the pushed tree. Instead,
`part-coc-source-pointer.md` records the exact source location so the material is
re-fetchable:
- Repo: [Ormael7/Corruption-of-Champions](https://github.com/Ormael7/Corruption-of-Champions)
  (original game by Fenoxo)
- Directory: `classes/classes/Items/Consumables/` (one `.as` file per item)
- Supporting files: `ConsumableLib.as`, `Mutations.as`, `Appearance.as`, `Creature.as`
- Wiki: https://coc.miraheze.org/

The pointer file also records what was there: breadth (~62 consumables), per-item coverage
(change pools, stat mods, body-part mutations, outputText strings, bad-end branches), and
the five alphabetical bands originally captured (A: A–B, B: C–E, C: F–I, D: J–P, E: Q–Z).

**`tf-mine-tits.md` — Trials in Tainted Space instances**

65-file transformatives directory from the open-source TiTS AS3 codebase
([Terranon/Trials-in-Tainted-Space](https://github.com/Terranon/Trials-in-Tainted-Space),
by Fenoxo / Savin / team). Descriptions are re-worded from the code logic; short quoted
phrases (≤ one phrase) only where the exact wording is itself the detail. Covers
full-species TFs (myr/ant, feline, canine, bovine, vulpine, draconic, goblin, cow, fox),
single-slot items, and status-timer TFs. Leads with a shared engine-facts block (body model
= slot/flag based; stochastic change pools; reversibility; mind coupling).

**`tf-mine-shifti.md` — Shifti.org instances**

28 transformation instances re-described in the mining agent's own words from
summarizer-mediated fetches of Shifti.org story pages. No verbatim prose reproduced; rare
short quoted phrases (≤ 1 sentence) only where the exact wording is the notable detail.
Attribution: title + author-from-URL + URL per entry. Coverage skews toward inanimate,
pool-toy, species (feline/canine/equine/ursine), and slow-onset-mental arcs; some
TG/gender-variant entries.

**`tf-mine-giantessworld.md` — Giantess World instances**

13 transformation instances re-described from fetched chapter content of
giantessworld.net stories. Own words; short quoted fragments (≤ one sentence) marked where
specific wording is notable. Covers size growth (macro/giantess), some shrink, one species
blend, one inanimate. Skews toward gradual growth with food/magic triggers.

**`tf-mine-fictionmania-tg.md` — Fictionmania TG instances**

~10 transformation instances from Fictionmania (fictionmania.tv), covering the TG/gender
transformation genre specifically. Re-described in own words; no verbatim prose. Broadest
FtM representation in the corpus (though still under-sampled — see Coverage Limits).

---

### Analysis

**`tf-substrate-expressiveness.md`**

Adversarial expressiveness test: the mining agent read the aeriea TF substrate source
directly (`scripts/sim/tf/*.gd`, `tests/tf_substrate_test.gd`) and ran 31 sampled corpus
cases against it, one by one, asking whether the substrate as built can express each. Not
a summary — a per-case verdict with cited code paths. See Headline Finding below.

---

### Secondary — craft-lens material

These files were produced during an earlier direction of the session (how TF prose *reads*
as prose — somatic rendering, psychological arc, structural shape). That direction was
deprioritized in favor of the corpus/expressiveness track above. Persisted as background
context; not load-bearing for substrate design.

**`tf-craft-somatic-raw.md`** (127 lines) — Raw excerpts and a meta-essay ("The Tail Tale",
Bryan, Shifti) on craft of somatic/sensory rendering of body change. Passages surfaced via
summarizer-mediated WebFetch; noted as representative, not hand-transcribed.

**`tf-craft-psych-raw.md`** (46 lines) — Raw excerpts focused on psychological arc: identity
dissolution, horror, acceptance, dissociation during TF. Same provenance note.

**`tf-craft-structure-raw.md`** (100 lines) — Notes on structural/narrative patterns: pacing,
onset types, reversibility framing, before/after contrast, the "slow bleed" vs. "sudden
snap" distinction.

**`tf-floor-coctits-raw.md`** (192 lines) — Earlier floor-pass through CoC/TiTS mechanical
content with a craft-lens framing (how the game text renders the TF moment). Overlaps with
but predates the cleaner per-item analysis in `part-A.md` through `part-E.md` and
`tf-mine-tits.md`; treat those as superseding this for mechanical reference.

---

## Provenance

**Prose corpus files (`tf-mine-shifti.md`, `tf-mine-giantessworld.md`,
`tf-mine-fictionmania-tg.md`, `tf-mine-tits.md`):** The mining agent's own-words
descriptive summaries of transformations — not reproductions of the source prose. Short
quoted fragments (≤ 1 sentence) are marked as such inline. No verbatim story prose is
reproduced.

**CoC catalog (`part-coc-source-pointer.md`):** The verbatim game strings and AS3 source
that were originally captured across part-A..E are not committed — third-party open-source
game text we prefer not to carry in the pushed tree. The pointer file records the exact
repo, directory, and supporting files so the material is re-fetchable. See that file for
full details.

**Craft-lens files (`tf-craft-*.md`, `tf-floor-coctits-raw.md`):** Notes and short
excerpts surfaced via summarizer-mediated WebFetch. The provenance header in each file
notes that quoted sentences were selected and relayed by the summarizer model, not
hand-transcribed from a full read — treated as representative, not exhaustive.

---

## Coverage limits

These limits were recorded during the mining session and hold for the corpus as filed:

- **Walled sources not reached:** AO3 (Archive of Our Own), Eka's Portal, BigCloset Top
  Shelf, FurAffinity. All behind login or access-controlled in ways that blocked the mining
  agent's fetches. None of their content appears in this corpus.
- **FtM under-sampled.** The Fictionmania mine has the broadest FtM representation but it
  is thin. The genre overall skews heavily MtF; FtM is a minority in every source reached.
- **Amateur-to-midlist tier only.** No published novels or professionally edited prose
  represented. All sources are amateur/hobbyist fiction platforms.
- **Inanimate/substance genre partially covered.** Shifti provides the best inanimate
  coverage (pool toys, mannequins, objects); giantessworld and Fictionmania have little.
  The "become coffee / glitter / toaster / hollow suit" space is sampled but not deep.

---

## Headline finding (from `tf-substrate-expressiveness.md`)

The substrate expresses the scalar/reflavor core cleanly: single-attribute changes and
part-type swaps are clean field writes via the `advance`/lerp pattern; relational
prerequisite gating (require lion-arms before lion-face) is a genuine strength. But the
corpus's center of gravity is **adding and removing parts** — growing a tail, wings, horns,
a second breast row, extra legs; removing balls, cocks, a row; splitting or fusing. That is
the literal definition of most TG and most species TF.

The substrate as built could not author any of it: the tick return protocol writes fields
only (`tf_engine.gd` lines 59–64) and the action set had no graft/detach op. Roughly 2/3
of the 31-case sample was blocked on this one missing capability.

**Resolution:** structural mutation was implemented; see commit `04b075e`. The one real gap
in the substrate is now closed. The secondary wall (inanimate/substance TFs that need a
non-body body model, and cross-body coupling) remains open but is correctly out of scope
for the current system.
