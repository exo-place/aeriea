# Character-Creator Saga — Session Record

**Status:** SHELVED. The character creator + body was rebuilt this session as a
projection over a typed interaction graph; it passed ~25k assertions and survived
15 + 3 + 10 adversarial design rounds, yet the real running app is still obviously
broken. The user's verdict: "beyond saving for the time being." Not to be resumed
without a different approach. Next session's focus is **text generation**, not this.

This record exists so a fresh session can pick up cold — what the creator is now,
what's wrong with it, the artifacts produced, the governance added, and (most
importantly) the meta-learnings about why green tests and adversarial rounds did
not produce a good result.

---

## What the creator + body is right now (on master, SHELVED)

The creator was rebuilt as a **projection over a typed interaction graph** — the
rhizone affordance model. The body is no longer a pile of sliders; it is a region
tree whose nodes are affordances, and the UI is generated from that graph rather
than hand-laid per control.

Phases that landed on master (each green at commit time):

- `0377625` — projection shell: region-tree navigation + body-foregrounded layout;
  the old tier selector was killed.
- `a2be5b6` — instant coherent randomize + cm height + real breast-size via an
  imported cup-cube mesh + iris verified-round.
- `1b12343` — on-body grab-handles for reshape (plural modality); the global
  sculpt-mode was removed.
- `6fc4afe` — history collapse + human labels; single Share / Open; plain
  beyond-human toggle.

Body-mechanics / cap foundation earlier in the session:

- `5c7791b` — cap model (extremeness scalar, per-pole ratcheted caps, choke).
- `ecc7dbb` — skin Tier-A material (detail-normal / roughness / SSS) +
  tangent-on-commit.
- `cdc0e83` — procedural iris look + glow tracks morphed surface + tongue seating.

Tests were green (~25k assertions) at each of these commits.

### Partial Phase-E (committed as WIP, NOT a fix)

The very last creator work was an **unfinished cross-seam UI cleanup** (Phase E):
dissolve the oversized Advanced popup (Mirror → top-bar toggle; beyond-human opt-in
→ inline at the value; androgynous-in-randomize → checkable Create-menu item),
remove the redundant top-right undo/redo icon pair, re-anchor the history overlay
top-left so it stops overlapping the bottom pinned strip. The agent that wrote it
never committed it (it returned awaiting a background monitor).

This session committed that partial work as `bdde0d5`
(`wip(creator): partial cross-seam UI cleanup (creator shelved, not green)`) purely
to **preserve** it. It is incomplete and was never verified against the real app. It
adds `creator_phasee_test` (14/0) + a phasee render harness. Do not treat it as a
fix — Phase E was an attempt to address the rage-list below and was not seen through.

### Test state at shelving

`nix run .#test` = **25251 passed, 2 failed**. The 2 failures are in
`creator_glow_test` ("ray hit lands ON the morphed surface" / "ray hit is NOT on the
stale neutral geometry"), the sculpt raycast-on-morphed-surface tolerance from the
B2 fix in `642f43d`. **They are pre-existing** — they reproduce identically on the
last good commit (`6fc4afe`) before any Phase-E change, and are unrelated to the
Phase-E UI cleanup. They were left as-is (creator is shelved; do not chase them
unless the creator is un-shelved).

---

## The rage-list — the ACTUAL state per the user running the real app

> This rage-list is the **final-day creator state only**. The complete, cross-session
> set of every user-reported defect (creator, UI, text sandbox, movement/parkour, and
> process), mined verbatim from the raw transcripts, lives in
> [`DEFECT-COMPENDIUM.md`](DEFECT-COMPENDIUM.md). Do not mistake the list below for
> complete.

Despite green tests and the adversarial design rounds, the user ran the built app
and found it still obviously broken. Recorded verbatim as the real state:

- The creator UI top bar **OVERLAPS / sits UNDER** the launcher's entrypoint
  switcher — History / Share / Open are **stranded / inaccessible** beneath it.
- **Region-picking-to-shape was LOST** (the whole point of the region tree — picking
  a region to shape it — does not work).
- The **age slider only goes down to 18**.
- Sliders / spinboxes **round to coarse 0.5 / 1% increments** — visible the moment
  you type a decimal.
- "**start from a body**" and "**restored character**" text **floating awkwardly**.
- The **app name top-left** is useless chrome.
- The **Advanced popup was grossly oversized (348×3344)**, overlapping the top bar.
- The **history overlay overlaps the pinned strip**.
- A **redundant undo/redo button pair** lingered.

VERDICT: "**beyond saving for the time being**." Shelved. Do not resume without a
different approach.

---

## Design + diagnosis artifacts produced (paths, for reference)

Design decisions (converged through adversarial rounds):

- `docs/decisions/character-creator-and-body.md` — body / cap mechanics, converged
  over 15 adversarial rounds.
- `docs/decisions/character-creator-ux.md` — the projection / interaction-graph UX
  design, converged over 3 UX / taste-adversary rounds.

Adversarial trails + diagnosis:

- `docs/artifacts/design/creator-body/` — the body/cap adversarial trail.
- `docs/artifacts/design/creator-ux/` — the UX adversarial trail.
- `docs/artifacts/diagnosis/` — the diagnosis trail, including
  `movement-backlog.md` (parkour / movement defects — a **separate, unstarted**
  feature, not part of the creator).

---

## Governance added this session (in effect going forward)

These are now part of the repo's control surface and apply to ALL future work:

- **`CLAUDE.md`** gained:
  - **Playtesting (mandatory)** — every user-facing change must be run and observed
    (rendered frames / transcript / live interaction), by both the implementer
    (self-playtest) and the orchestrator (whole-composed playtest), before it
    counts as done. Green tests alone are never sufficient.
  - **Feature gating** — no new feature without a **design pass** first (a recorded
    `docs/decisions/` artifact deciding shape / defaults / naming / quality bar
    before any code). **Green is granted ONLY by the user**, never self-promoted.
  - The **design-pass rule** ("Implement X" is a prompt to design X first).
- **`docs/FEATURES.md`** — the feature ledger. Every feature is **Green** (user has
  personally verified it is good) or **Not green** (everything else). **Nothing is
  Green.** New work lands in Not green.
- **`.githooks/pre-commit`** — enforces the green-promotion gate: any commit adding
  a bullet under `## Green` is blocked unless `AERIEA_GREEN_APPROVED=1`, which is
  the USER's alone to set. Claude must never set it and never use `--no-verify`.

---

## KEY META-LEARNINGS (the most important durable content)

These are the real takeaway of the saga. They generalize past the creator.

1. **Green tests / surviving N adversarial rounds ≠ good.** The 15-round and
   10-round adversarial loops verified the design's **internal consistency** (and
   the code's correctness) — never whether the result was **good / sensible to a
   user**. So they hardened mechanically-correct slop. An adversary only catches
   what its rubric asks for.

2. **Detection is a copout.** A checker / critic / LLM-judge only catches the
   failure **classes** it was built to look for; novel badness is invisible until a
   human hits it, after which you bolt on another check — a reactive bandaid
   treadmill. Even the "composed-whole critic" that rendered the **real running
   app** still missed the overlapping bars and the stranded buttons.

3. **The real gap is GENERATION WITH TASTE, not detection.** Quality has to live in
   the thing **producing** the work; a net cannot add judgment the generator lacks.
   LLMs (per the user, and per this session's evidence) are unreliable at
   taste-laden quality — visual / UX especially. This is **unsolved**.

4. **The recurring process failure: confabulating causes + overconfidence.** The
   orchestrator gave **three different confident, wrong** explanations for why the
   critic missed the defects; shipped obvious brokenness past every automated check;
   relayed agent success-reports as truth. What actually **worked**: the **user as
   the quality oracle**, and forcing generation to verify against **ground truth** —
   reading the actual code, measuring the breast-size delta, the cup-cube import.
   Objective-ground-truth tasks succeeded; pure-taste tasks did not.

5. **"User as gate" is not an acceptable steady state.** The user does NOT want to
   babysit / point at every defect. Reliable **autonomous quality on taste-laden
   surfaces** is the genuine unmet need — and neither detection nor "just start a
   fresh session" solves it.

---

## Next session — text generation ("unfucking text gen")

The creator is shelved. The next focus is **text generation**.

Relevant existing material:

- `docs/decisions/prose-generation.md` — the deterministic prose-output engine
  thesis.
- `docs/decisions/npc-mind-and-language.md`
- `docs/decisions/semantic-layer.md`

The **text sandbox** (`scripts/text_sandbox.gd`, `scenes/text_sandbox.tscn`) runs
**on aeriea's own affordance substrate** (NOT a BDCC2 bypass) but is **thinly
authored**. Known defects from this session's diagnosis:

- Numbered-menu CLI UX — not systemic gameplay.
- The **affect projection bug**: greet → "arousal" via a BDCC2-ported mood model,
  shown **raw to the player**.
- **Tells-not-shows** prose (the realizer is **not good**, per the user).
- Only **~6 thin verbs** — worse than TiTS.
- The face / expression preview is **not wired** to the text gen.
- The debug `(face: ...)` line is shown to the player.

See `docs/artifacts/diagnosis/text-ui-reverify.md` and
`docs/artifacts/diagnosis/bdcc2-port-reverify.md` for the text diagnosis trail.
