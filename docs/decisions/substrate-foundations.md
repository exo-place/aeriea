# Substrate foundations (the candidate thesis)

Status: **FOUNDATIONAL R&D DIRECTION — candidate thesis to be adversarially
de-poisoned, NOT frozen** (2026-06-22)

Scope: the single foundational thesis a long design session converged on —
what aeriea's *substrate* is at its core, the discipline that keeps that core
durable, the hard constraints it must clear, the two communicative channels it
projects to, and the prior art it is refracted from. This is the minimal
foundation deliberately: a bloated foundation is a self-refuting one. It is
written to be the SPEC a subsequent adversarial design pass attacks. Every
primitive and law below is a *candidate*, held until red-teamed and validated.

---

## The substrate law (candidate)

The substrate provides **universal genuineness under attention-bounded
materialization**, across **space AND time**.

- **Event-driven, never tick-driven.** State advances on events, not on a
  global clock sweep.
- **Never store the world.** Store the seed plus a sparse log of what was
  *created* or *observed*; derive everything else on demand.
- **No facades.** Every entity is genuinely deepenable and consistent under
  inspection. Fabrication is forbidden; only *deterministic revelation* of what
  the seed + log already imply.
- **Deterministic.** `state = f(seed, event log)`. No nondeterministic RNG
  outside the seeded timeline.

Eager and lazy are the **two ends of one continuum** any entity slides along by
attention and causal load — **not tiers, not a global mode choice**. An entity
under heavy attention/causation materializes eagerly; an unobserved one stays a
stub. The slide is continuous and per-entity.

## Foundation discipline

- The foundation is a **minimal, assumption-free core algebra** — *the game's
  lambda calculus*, not a feature-API. Durability comes from **smallness +
  zero baked assumptions**, not from coverage.
- **Poison = premature commitment** — to a representation, an ordering, a
  use-case, or a scale — encoded in an interface. De-poisoning is **empirical**:
  baked assumptions are invisible from inside the interface; only a *real
  consumer* exercising the interface reveals them. ("Validate against reality;
  tests are the spec.")
- **The consumer is a purity tool, not a purity compromise.** The cathedral
  trap is real, but it is caused by *poison*, not by caring about the core. A
  consumer is a poison-detector. Refuse to ship slop **and** refuse to polish
  in a vacuum.
- Supporting principles (already ecosystem DNA): data-over-code at seams;
  collapse N special-cases to their irreducible primitives; library-first /
  projection-from-one-definition; capability security; retire-don't-deprecate
  as an anti-sprawl ratchet.

## Hard constraints

- **Quality bar.** Meet or exceed **Opus-4.8 freeform-RP craft** on the cases
  the substrate *covers*, with a hard **non-trash floor** (no mad-libs, no slop,
  ever). The bar is **not** claimed generally — the moonshot is
  *coverage-at-quality*, not universal quality.
- **No hot-loop LLM.** Build-time / leaf inference only; deterministic-eval
  surrogates permitted. Per-query LLM in the control loop is a defect.
- **Inspectable, owned, no opaque black boxes.** Integrity-under-inspection:
  open source means the observer *includes the source-reader*, so depth must be
  genuine rather than a curtain ("trust from verifiable evidence, not
  authority").
- **100-year longevity** is the literal bar for the foundation.

## Channels (simulation underneath, rendering on top)

Both channels are **deterministic projections of one channel-agnostic
communicative intent**.

- **Showing → embodied/visual channel.** CC0 3D (e.g. MakeHuman, already
  vendored), with systems mined from prior art (BDCC2 etc., MIT) placed *behind
  aeriea's own seams* as a **replaceable surface — never the base**. Fidelity is
  a continuum by attention, not tiers. The visual channel's job is to *show what
  prose shouldn't tell* — expression, reaction.
- **Text → dialogue + interiority + the unsaid.** Text is for what is said,
  thought, and left unsaid — **not** for narrating reactions, which is
  "telling".

## One vision / prior art (facets of the same substrate)

These are **one vision refracted**, not four projects. The substrate is their
shared core; the open task is to *find and validate* that core.

- **`existence`** — eager-deep sim; the always-attended pole of the continuum.
  Proves genuine depth with small-N eager materialization is cheap; its lesson
  is that integrity means the depth must *genuinely be there*.
- **`defocus`** (`~/git/rhizone/defocus`, MIT, ~10k LOC, Rust+TS) — the lazy
  pole: objects are stubs until observed; rules-as-JSON-AST (data-over-code);
  deterministic event-log replay + forking; capability-attenuated refs;
  LLM-output-logged-for-replay; text-as-rendering-layer. The closest existing
  substrate — and it **died UNVALIDATED**, with no consumer.
- **`semantic-layer`** — prevalence-weighted knowledge graph; mipmaps-for-meaning
  / faithful coarsening. The LOD spine, now generalized as the substrate's
  universal law.
- **`noncanon`** — local-first canon, the decentralized half of the
  semantic-web dream; design stub.

## This doc's status

This is a **candidate THESIS for adversarial de-poisoning**, not a frozen spec.
Every primitive and every law above is to be red-teamed for hidden assumptions
(poison), then validated or falsified **empirically via a minimal consumer**.
Nothing here is frozen. Hold what survives; cut what poisons.

## Cross-links

`docs/decisions/simulation-depth-and-materialization.md`,
`docs/decisions/prose-generation.md`,
`docs/decisions/semantic-layer.md`,
`docs/decisions/npc-mind-and-language.md`,
`docs/research/existence-prior-art.md`,
`docs/research/bdcc2-evaluation.md`,
`docs/research/visual-channel-licensing.md`,
`docs/research/paperdoll-asset-packs.md`,
`docs/research/diffusion-to-paperdoll-pipeline.md`,
`docs/research/crux-prior-art-constraint-generation.md`.
