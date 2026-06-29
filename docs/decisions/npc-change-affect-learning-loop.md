# NPC change over time — the affect → learning loop

This records a design conversation on how aeriea's NPCs **change over time** in
a way that reads as character depth, not merely moment-to-moment aliveness. It
is for user review; nothing is built until approved. It lands as **Not green**.

Each claim is tagged for both its standing and its provenance:

- **[SETTLED]** — the user explicitly decided this.
- **[REASONED]** — the design conversation converged on it, but the user has
  not signed off; pending check.
- **[OPEN]** — genuinely unresolved; the user's call.

Prior-art claims about the `existence` project are marked **[DIGEST]** — they
are **sourced from an exploration subagent's attenuated digest (file:line refs
available)**, not from direct reading in this session. The design reasoning is
from a live design conversation.

## The question

How do NPCs change over time in a way that reads as **character depth** — an
arc the player can feel — rather than just the second-to-second legibility of a
mind that is currently alive?

## Aliveness vs depth — [SETTLED]

These are two different properties and only one of them is about change over
time.

- **Aliveness** is the moment-to-moment legibility of motive: you watch an NPC
  want something, fail, and change course. It is a property of a single scene.
- **Depth** is change across an arc, and an arc is a **diff**. It only reads if
  the player is holding a "before" to subtract the "after" from. Depth without a
  remembered prior state is invisible — the change happened but nothing renders
  it.

## The baseline problem — [SETTLED] / [REASONED]

Because depth is a diff, subtle change only registers if a prior state was
encoded in the player. Real people get this for free: human social hardware
encodes baselines for the people around us involuntarily and at no cost, so we
notice when someone is "off" without ever deciding to track them. An NPC has no
such free encoder in the player's head; the baseline must be laid down by one of
two routes. **[SETTLED]**

- **(a) Presence over time** — repeated low-stakes exposure. If the NPC is
  simply around enough, the player encodes the baseline for free, the same way
  we do for real acquaintances.
- **(b) A witnessed significant event** — a single high-salience moment that
  burns in a reference frame the later change is measured against.

**Decided leaning [REASONED]:** presence-over-time is sufficient on its own. The
game does **not** need to manufacture a dramatic baseline-setting event for
every NPC who will later change; ambient exposure does the encoding.

## The mechanism — affect-driven online learning

### The take — [REASONED]

NPCs change via **runtime learning** where the loss/reward signal is the agent's
**own experienced valence** — whether it liked what happened or not. The
biochemical framing ("dopamine vs cortisol") is treated as **flavor laid over a
real computational skeleton**, not as the mechanism itself.

### Why this is character and not just skill — [REASONED]

The conversation worked through a critique and conceded an update, which is worth
recording because the first instinct was wrong:

- **The critique (too strong, withdrawn):** gradient descent toward a *fixed
  designer objective* yields competence, not character — it is a progress bar
  crawling through weight-space, and the NPC just gets better at a task we
  picked.
- **The resolution:** when the objective is the agent's **intrinsic affect**
  rather than a designer's task, the thing that gets learned is a
  **policy-over-the-world** — approach this, avoid that, brace around this
  person — and that learned policy *is* most of what we mean by character. So
  intrinsic-affect online learning produces real character change, not merely
  skill acquisition. The "wrong shape, it's skill not character" objection was
  conceded as too strong.

### Legibility rescue — [REASONED]

Weights are the **least legible** representation of change imaginable, which
would normally fail aeriea's standing principle that *interiority only buys
aliveness if it has a surface channel*. Opaque change that never surfaces is
worth nothing to the player.

The affective framing buys the legibility back: the **valence signal itself is a
channel**. "She found that painful" is readable and renderable even when the
policy weights driving her future behavior are completely opaque. The surface
channel is the affect, not the weights.

## The two load-bearing knobs

These are the real design decisions — the choices that determine what kind of
character drift the system actually produces.

### Knob 1 — raw valence vs prediction error (RPE) — [OPEN]

- **Raw valence + fixed reward** drives adaptation of *coping* that
  **converges** in a static world: the agent gets better and better at obtaining
  what it already wants. The shape this produces is addict-like — efficient
  pursuit of a settled preference.
- **Reward-prediction-error (RPE)** — dopamine as *surprise*, reward minus
  expectation — gives **habituation for free**: once the world stops beating
  expectations, the signal fades, producing boredom, novelty-seeking, and
  restlessness. That is the engine of roughly half of all character drift.

### Knob 2 — fixed vs plastic critic — [OPEN]

- **Fixed reward function:** coping changes but **values do not**. The agent
  learns better routes to the same wants.
- **Plastic reward function** (the critic itself learns): enables genuine
  **value change** — "came to love what they once feared" — but introduces
  **wireheading** risk, the drift toward concluding that everything is wonderful.
  The homeostatic / predictive structure of the critic is exactly what prevents
  wirehead collapse.

### Resolution leaning — [REASONED]

The two knobs are **not either/or**. There appear to be two different clocks:

- a **chronic / allostatic** clock — slow, setpoint drift over weeks
  (habituation at the level of what counts as normal), and
- a **phasic / RPE** clock — fast, per-event surprise.

These are different timescales, and the likely answer is to want **both**. This
is a leaning, not a final position.

## Constraints

### Determinism — [SETTLED constraint, north-star]

Learned weights become **simulation state**. Under the north-star rule that all
state is "derivable from seed + action log," this implies that reconstructing any
moment means **replaying the gradient steps** up to it. That is expensive, and it
is fragile: a kernel, architecture, or framework change can silently invalidate
existing saves. It is recoverable with **deterministic kernels** and disciplined,
**fixed RNG-draw counts**, but the cost is real and must be designed for, not
assumed away.

### Multi-agent coupling — [REASONED]

If every NPC trains on its own affect, then each NPC is a **non-stationary
environment** for every other NPC. The agents become **coupled learners**, and
that cuts two ways:

- the good case: emergent grudges, alliances, and mimicry — social dynamics that
  no one authored;
- the bad case: degenerate collapse into a dead equilibrium.

Seeded determinism is what turns this from unshippable chaos into something
tractable: **you can search seeds for a world whose social dynamics came out
alive.** Here determinism is the **enabler, not the tax** — it is the only reason
the coupled-learner regime is shippable at all.

## Prior art — `existence` — [DIGEST]

The following is **sourced from an exploration subagent's digest; file:line refs
are available but were not read first-hand this session.**

`existence` is a single-player text game whose PC is modeled as roughly 28
neurochemical state variables. It is notable because it already contains **both
halves of the take above** — but **never wires them together**.

- A rich **valence substrate**: baseline-relative raw valence measured against a
  ~3-week allostatic EMA (habituation — "the tenth shower comforts less"), plus a
  sentiment system and mood tones.
- A live **online learner** (`habits.js`): hand-rolled CART decision trees
  retrained every 10 examples — but it is **reward-blind**. It does *supervised
  imitation of the player's own past actions*; valence never enters it.
- **The affect → learning wire is never run.** The two systems are orthogonal. A
  habit can entrench a self-destructive routine purely because the player did it
  before, and valence gets no vote on whether that routine was good.

### Lessons for aeriea — [DIGEST → REASONED]

- The **valence substrate transfers and is de-risked.** It also supplies the
  proof we need on determinism: a runtime online learner *can* preserve seeded
  replay — the learner consumes **zero RNG**, and recall uses **fixed draw
  counts**. existence already solved "online updates without breaking
  determinism."
- existence's habituation is **chronic / allostatic, not phasic / RPE.** This
  proves the **slow clock** is tractable and deterministic. The **fast clock**
  (RPE) is still **unbuilt anywhere examined**.
- existence cites Schultz 1997 on reward-prediction-error but does **not**
  implement it — it models a tonic, baseline-relative level and labels the gap
  "prediction error" only in prose. Vocabulary outran mechanism; do not mistake
  the citation for a working RPE loop.
- The **reward → policy loop** and the **multi-agent coupling** are **greenfield
  everywhere examined.** These are aeriea's to build.

## Open questions — [OPEN]

These are explicitly undecided and are the user's call.

- **Headline contribution.** Build the **reward → learning loop** first (with the
  valence substrate borrowed from existence), or target the **multi-agent
  coupling** frontier (which neither project has touched)?
- **Final position on the two knobs** — raw-vs-RPE and fixed-vs-plastic critic.
  The leaning is toward running *both timescales*, but this is not decided.

## Status

This consolidates one design conversation. The **[REASONED]** items await the
user's sign-off; the **[OPEN]** items are the user's to decide; the **[DIGEST]**
prior-art claims should be confirmed against the `existence` source (refs
available) before any of them is load-bearing in implementation.
