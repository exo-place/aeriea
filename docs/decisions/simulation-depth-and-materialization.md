# Deep worlds by constrain-then-generate (observer-indistinguishable simulation)

Status: **FOUNDATIONAL R&D DIRECTION — target & architecture decided; the generator crux is the open core** (2026-06-15)

Scope: this doc records the architecture *direction* for the substrate that holds
the depth the prose realizer renders — the deep, self-consistent simulated
character and world that `prose-generation.md` establishes the prose can never
exceed. It is the **substrate-architecture upstream of the prose realizer**: that
doc's *Depth is upstream* section names this substrate as the binding constraint
on "beats handwritten" and explicitly sites it outside its own scope; this doc
takes that sited problem up. It contains **no engine code** and touches no
entrypoint; it is a design direction, not an implementation and not a frozen
spec.

> **This doc's earlier "deterministic lazy materialization" framing is
> superseded.** An earlier version framed the substrate as *deterministic lazy
> materialization* over an implicit eager timeline, then corrected itself to show
> that lazy materialization does not resolve the depth-vs-causality-vs-cost
> tension (it is sound-but-not-cheap or cheap-but-lossy, never both). That
> correction was right, and it is now *itself* superseded by a confirmed
> resolution: the literal goal "simulate a deep causal world" was the wrong
> frame. The current position — **observer-indistinguishability** as the target
> and **constrain-then-generate** as the architecture — leads below. *(The
> filename retains "materialization" for link stability; do not read it as the
> current framing.)*

Several genuinely hard sub-problems remain open; each is marked open. The target
and the architecture are **decided**; the generator that realizes them is the
**open frontier**, not a solved thing. No mechanisms are invented beyond what was
decided; no names are coined.

---

## How we got here

The reasoning trail that produced the reframe, compactly. It is preserved because
it is load-bearing: each step rejects a frame that looks plausible, and the
rejections are *why* the final frame is what it is.

- **Depth is upstream.** `prose-generation.md` establishes its single most
  load-bearing scope boundary: **prose depth is upper-bounded by simulation
  depth.** The realizer is a lens — it can "render the depth the substrate holds,
  faithfully and at high quality; it **cannot create depth the substrate
  lacks**," because rendering depth the model does not hold is *invented*
  interiority — **confabulation**, which faithfulness flatly forbids. So "beats
  handwritten on quality" reduces, upstream, to an **unreasonably deep,
  self-consistent simulated character + world** ("memory, beliefs,
  contradictions, personal history, self-image, relationships with real texture,
  theory-of-mind, and a world of genuine semantic richness"). Building the
  substrate that *holds* that depth is the real moonshot, sited here.

- **The tension.** Pursuing that depth collides with the project's hardest
  invariant, and the collision has two horns. **Horn 1 — causality forbids naive
  post-hoc refinement:** NPC "brain state and communicative intent are
  **deterministic functions of `seed + event log`**" (`npc-mind-and-language.md`),
  so inventing character/world detail *after the fact* asserts something the
  seeded timeline never entailed — that is confabulation, and it **breaks
  replay**. **Horn 2 — eager full fidelity is impossible:** determining
  *everything* at full fidelity from `t=0` is prohibitively costly *and*
  ill-defined (depth is genuinely *unbounded* — you can always probe one level
  deeper). So depth cannot be invented late, and cannot be computed early.

- **Eager forward-sim is plausibly infeasible — but this premise is UNVERIFIED.**
  The argument: generating every NPC's complete interior life, every object's
  provenance, every relationship's texture, eagerly, on a per-tick budget for a
  persistent world, looks unaffordable — `DESIGN.md`'s own reference point (HHS+)
  already pays *seconds per tick* for a far shallower sim, so "simulate then
  render" *appears* unable to pay for the depth. **This is a plausible argument,
  not an established fact.** The 2026-06-19 prior-art pass
  (`docs/research/crux-prior-art-constraint-generation.md`) targeted exactly this
  premise — Dwarf Fortress, Caves of Qud history-gen, Talk of the Town, Versu,
  Bad News — and returned **zero adversarially-verified claims**; DF and Qud
  demonstrably ship at non-trivial scale, and the `existence` prior-art study
  shows eager-deep forward-sim is *cheap at N=1*. So treat eager-infeasibility as
  **plausible-but-unverified**, an open question (see *What the prior art says*
  below), not a settled rejection. The reframe below does not depend on it being
  proven: constrain-then-generate is chosen on the lossless/cost grounds that
  follow, and stands whether or not eager is later shown feasible.

- **Lazy materialization is not the resolution.** Deferring computation to first
  observation, over a referentially-transparent seeded timeline, is real and
  useful — but it does not dissolve the tension. Referential transparency buys
  *consistency*, never *causality*: a thunk read late equals a thunk read eagerly,
  but that says nothing about whether it *caused* anything committed in the
  meantime. So lazy is **sound-but-not-cheap** (every causally-live thunk forced
  at its causal moment = eager on the depth that drives behavior) **or
  cheap-but-lossy** (decisions run on coarse stand-ins, so the committed timeline
  is a function of the *lossy projection* and the fine detail caused nothing) —
  **never both.** The cheap-but-lossy branch is exactly the latent lossiness this
  project rejects for timeline generation, and it is **rejected.**

- **∴ "simulate the world" is the wrong frame.** Eager is infeasible; lazy is
  sound-but-not-cheap or cheap-but-lossy. The literal goal — run a deep causal
  *process* — admits no affordable, lossless realization. Reverse-engineering the
  project's hard lines (no hot-loop LLM, faithfulness, determinism, depth,
  causality, no lossy timeline, no eager sim) shows they are not seven constraints
  on a "simulate the world" process; they are seven facets of **one actual
  target** that a *process* was never the right shape for. That target, and the
  architecture that hits it, are the rest of this doc.

## The actual target: observer-indistinguishability

The hard lines reverse-engineer to one target, and it is now **decided**:

> **TARGET — observer-indistinguishability.** A world that, to its only observer
> (the player), is indistinguishable from a deep, living, fully-simulated one —
> under unbounded adversarial probing — at a cost proportional to engagement,
> deterministically, never committing a falsehood.

The seven hard lines are facets of this one target, not independent constraints:

- *No hot-loop LLM* and *determinism* → "deterministically" and replayable.
- *Faithfulness* and *no lossy timeline* → "never committing a falsehood."
- *Depth* and *causality* → "indistinguishable from a deep, living, fully-simulated
  one **under unbounded adversarial probing**" (probe arbitrarily deep, find no
  seam).
- *No eager sim* → "at a cost proportional to engagement" (you pay for what is
  probed, never for the unprobed whole).

**The player is the only observer.** This is the load-bearing move. "Real" can
only mean *real to the observer*: a world is exactly as deep as it is
indistinguishable-from-deep under everything the observer can do to it. This is
the chosen target **over "really real"** — a genuinely autonomous off-screen
world that lives whether or not anyone looks. What that gives up is set out under
*What this gives up*; the point here is that it is a *deliberate* choice of target,
not an accident of implementation.

## The architecture: constrain then generate

The decided architecture is **constrain then generate** — neither "simulate then
render" (eager, infeasible) nor "coarse-state then read" (lossy, rejected). The
ground truth underneath the world is a generative **FUNCTION**, not a running
process and not a store:

> `G(seed, constraints, query) → answer`

- **`G` is the ground truth.** There is no world-state being advanced and no
  world-store being read. When something about the world is needed, it is
  *generated* by `G` from the seed, the accumulated constraints, and the query.
- **Constraints** = the set of everything observed so far **plus its
  entailments.** Not a coarse projection of state — the *exact* facts that have
  been committed, and what they logically imply.
- **Commit-on-observation.** When an answer is *observed* — rendered to the
  player, reasoned over by an NPC, otherwise entering the event log — that answer
  **and its entailments** join the constraint set, permanently binding. Before
  that moment the answer constrains nothing; after it, it constrains every later
  generation.
- **Pay per query, never per world-tick.** Cost is proportional to **engagement** —
  what the observer actually probes — not to world size and not to world age. An
  unprobed century costs nothing; a deeply-probed conversation costs in proportion
  to its depth.

`G` is queried by the realizer and the brain; it is not a loop that runs on its
own. The world does not advance — it is *generated on demand, consistent with
everything already committed.*

## Why this is lossless

This is **not** the rejected back-fit (commit a coarse approximation, reconcile
the fine detail later). The difference is the direction causality runs:

> **Causality runs BACKWARD as a CONSTRAINT, never FORWARD as a COMPUTATION — and
> no approximation is ever committed.**

Worked example. An NPC **flinches at fire.** That is observed, so it commits:

- the **true fact** "this NPC flinches at fire," and
- its **entailment** "a fire-consistent history *exists*" — some causally-prior
  history that would produce a fire-flinch.

What is **not** committed is a *guessed history*. No childhood, no specific burn,
no approximation of the cause enters the record. The constraint set now carries a
true effect and the *existence* of a consistent cause — nothing more.

Later, the childhood is **queried** (the player asks; an NPC reminisces). `G`
generates it now, **consistent with** the committed entailment "a fire-consistent
history exists" — and consistent with every other constraint it touches. The
history is generated *backward from the committed effect*, faithfully, at query
time. Nothing approximate ever entered the record; the cause is generated to fit
the effect, not the effect computed from a guessed cause.

> **Incomplete, never wrong.** A world that has not yet generated an NPC's
> childhood is **incomplete** — it has not committed that detail. It is **not
> lossy.** It would be lossy only if it committed a *wrong* childhood, or one that
> *contradicted* the already-implied "a fire-consistent history exists."
> Incompleteness is not lossiness: the unprobed is unwritten, not falsified.

This is the whole reason the architecture clears the bar the lazy framing could
not. Lazy-cheap was lossy because a coarse stand-in *caused* a committed event.
Constrain-then-generate commits no causes — it commits effects plus the
*existence* of a consistent cause, and generates the cause faithfully on demand.
Cheap *and* lossless, because nothing approximate is ever on the record.

## Determinism

The architecture is `seed + event log` determinism, unchanged in contract:

- **`G` is pure** over `(seed, constraint-set, query)` — same inputs, same answer,
  every time and on every path. It depends on nothing about *when* or *via which
  access path* a query arrives.
- **The constraint-set is itself a function of `seed + action log`.** It is the
  accumulation of commit-on-observation events, and observations enter the same
  **event log** that all simulation state is a function of
  (`npc-mind-and-language.md` → *Determinism & the LLM line*). There is no second
  source of truth: a committed fact is a recorded event, and replay reconstructs
  the constraint-set exactly as it reconstructs everything else.
- **The whole thing replays bit-for-bit** on one runtime: `constraint-set ⟵ seed +
  action log`, then `answer ⟵ G(seed, constraint-set, query)`, every step pure and
  recorded. This is the same invariant `npc-mind-and-language.md` sets ("brain
  state and communicative intent are deterministic functions of `seed + event
  log` … the entire chain replays bit-for-bit on one runtime").
- **The cross-platform-float caveat** that the movement, affordance, prose, and
  NPC-mind substrates all carry applies here too (`npc-mind-and-language.md`;
  `movement-substrate.md` §3 — replay validity bounded by runtime, fixed-point
  door kept open). `G`'s arithmetic is float arithmetic; this substrate does not
  solve cross-platform float determinism any more than its peers, and stays shaped
  so a later fixed-point swap is a leaf change.
- **The build-time-only inference line holds.** Nothing here calls a model in the
  hot loop. `G` is deterministic generation; any learned component (a
  build-time-trained generator) is the already-sanctioned offline-trained,
  deterministic-eval shape, never per-query online inference.

Purity over `(seed, constraint-set, query)` is what forbids order-dependence:
what the observer probes *first* must not change the answer. If access order
leaked into `G`'s output, replay would diverge and multiplayer would fork — and,
worse, the act of looking would *author* the answer, which is Horn 1's post-hoc
confabulation wearing a query. Order-independence is therefore not a nicety; it is
the precondition for the whole scheme.

## The central open crux

The target and the architecture are decided. What is **open** — the hard core,
owned and not designed away — is the generator itself:

> **THE CRUX (OPEN): deterministic, bounded-cost generation that satisfies an
> unboundedly-growing global consistency constraint set.** `G` must produce an
> answer that is consistent with *every* commitment it touches, drawn purely and
> at bounded cost, while the constraint set only ever grows.

The sub-problems, with the sharp one first:

- **Painting into a corner / satisfiability — the sharp one (OPEN).** As
  constraints accumulate, `G` can reach a query for which there is **no consistent
  completion** — a contradiction it created earlier by drawing **greedily**
  (committing the easy local answer, foreclosing a later global one). So `G`
  **cannot draw greedily.** It needs forward-checking-style draws that preserve
  *future* satisfiability — committing now only in ways that keep some consistent
  completion reachable for every query that could still come. This is **constraint
  satisfaction under a determinism requirement** (CSP-under-determinism), over an
  *arbitrary, growing* constraint set rather than a fixed one, and it is the hard
  technical core of the whole scheme. (It rhymes with the soft-body surrogate's
  *predict-then-project* shape in `TODO.md` — a draw followed by projection onto a
  constraint manifold — but here the manifold is the arbitrary, growing set of
  commitments, which is strictly harder.)

- **The constraint language (OPEN).** What entailments an observation commits, and
  at what abstraction level. Commit too little and facts that *should* bind stay
  free and can drift; commit too much (e.g. a guessed history rather than "a
  consistent history exists") and you are back-fitting. The flinch example commits
  an effect plus an existence claim — formalizing *which* entailments, and how, is
  open.

- **Stable query / fact identity (OPEN).** Purity requires every query to have a
  **canonical key independent of the access path** — "NPC#7's affective memory of
  parent#2's cooking" must denote *the same query* however it is reached (through
  NPC#7, through parent#2, through a conversation about food). Without a stable
  key, "the same fact" reached two ways could diverge — the order-dependence
  failure. Designing this canonical namespace over an unbounded, lazily-growing
  query space is nontrivial and unsolved.

- **The commitment boundary (OPEN).** What *exactly* counts as "observed" and
  crystallizes into the constraint set — direct observation by the player, an NPC
  *inferring* a fact, a passing *mention*? The boundary defines how fast the
  constraint set grows and how much later generation is fenced. Undecided.

- **Multi-observer / multiplayer (OPEN).** Multiple observers ⇒ a **shared commit
  log** and a single well-defined **constraint ordering** across clients. If two
  clients commit in different orders, the constraint set forks and the world
  diverges. What the canonical commit order even *is* when observations are
  concurrent, over a distributed self-hosted set of observers, is unresolved.

- **Per-query cost bound (OPEN).** "Cost proportional to engagement" must be a
  real, enforced bound: a single query (especially one that triggers
  forward-checking against a large constraint set) must resolve within an
  affordable budget. How `G`'s per-query cost is bounded as the constraint set
  grows is open.

### What the prior art says (2026-06-19 research pass)

An adversarially-verified deep-research pass mapped the prior art for exactly this
crux — *deterministic, bounded-cost, on-demand generation that stays consistent
with an unboundedly-growing fact set without painting into a corner*. The full
cited map is `docs/research/crux-prior-art-constraint-generation.md`; this is what
it concluded, used here only to the extent it actually supports.

- **Verdict: known-hard-with-workarounds** — not solved, but not freshly open
  either. People have attacked precisely this shape (Wave Function Collapse,
  ASP/SAT-for-PCG, truth-maintenance systems, belief revision, dynamic
  backtracking); what is *new* is assembling this specific trade — seeded
  determinism + lazy per-query materialization + correct-by-design global
  consistency under unbounded facts — which the surveyed literature does not cover.
  The theoretical floor: **detecting whether a consistent completion exists is
  NP-hard in general** (stated by WFC's own author).

- **The locality lever — the actionable principle.** Corner-risk scales with
  **GLOBAL (non-local) constraints, not local ones.** Empirically: local-adjacency
  problems almost never corner (an ASP surrogate hit *zero* conflicts on real
  scenarios even with heuristics disabled), while a single global constraint
  produced *hundreds* of conflicts and broke WFC's global-restart recovery on
  cases that local backtracking solved instantly. **Design implication:** structure
  the world so its constraints are mostly **local**, and treat global constraints
  as the expensive case to **bound and minimize**. This makes the crux's
  tractability substantially a *design choice*, not a fixed property of the problem.

- **"Incomplete, never wrong" is achievable today — in principle.** SAT/ASP-based
  generation is **correct-by-design**: it detects unsatisfiability, reports yes/no,
  and never emits an approximation (shipped in Tanagra, Refraction). So the half of
  the crux this doc names *Incomplete, never wrong* is solved in principle. **Cost
  catch:** it is done via whole-artifact **global** solves (exponential worst case),
  not lazy per-query, and is viable only at **constant-bounded scale** — not yet the
  unbounded, incremental regime `G` needs.

- **Candidate technique stack for `G` (recommended start, not a decided
  implementation).** A solver-based (SAT/ASP) formulation + **Ginsberg's dynamic
  backtracking** — complete, polynomial-*space*, and able to recover from a corner
  **without discarding committed work**. That last property is the direct match to
  this crux's "back out of the corner without throwing away the world." Caveats from
  the research: dynamic backtracking is a search technique over a *fixed* CSP, so its
  applicability to online constraint-*addition* is an inference beyond the sources;
  and completeness bounds *memory*, not *time* (worst-case runtime stays
  exponential). Recommended as the starting point to investigate, nothing more.

- **The genuinely open wall — the residue.** The **unbounded-incremental regime**
  is the part no surveyed system clears at scale, and it is the formal twin of this
  crux. Iterated belief revision proves the committed-history state needed to
  guarantee consistency under *future* additions grows **exponentially** and cannot
  in general be folded into a single current state — you must carry history, or find
  a principled criterion for when history can be committed (bounded). This stays the
  **primary open problem**; the prior art sharpens it, it does not dissolve it.

In sum: the research *sharpens* the crux with evidence — it does not move the
target or the architecture (constrain-then-generate / observer-indistinguishability
stay decided), and it does **not** report the crux as solved. The
satisfiability/painting-into-a-corner sub-problem above is exactly the
NP-hard-in-general floor, made tractable mostly by keeping constraints local; the
residue above is its unsolved core.

## What this gives up

Stated honestly, because the target is a *choice*:

Constrain-then-generate gives up **genuine off-screen autonomy** — a world that
evolves and surprises *for its own sake*, alive whether or not anyone is looking.
This is the `existence` "simulation-underneath-rendering" ethos the project cites,
taken to its metaphysical end ("lives that proceed in your absence,"
`npc-mind-and-language.md` → *autonomous inner life*; `DESIGN.md` → *World
agency*). Constrain-then-generate does **not** run an autonomous world you peek
at; it **reconstructs** consistent history and consequence on encounter, backward
from what has been observed.

Because the target is *observer*-indistinguishability, there is **no
player-facing loss**: under unbounded probing the reconstructed world is
indistinguishable from an autonomous one. The only casualty is the metaphysical
"alive even when unobserved" — a property the only observer can, by construction,
never detect.

> **PARKED (deferred, out of scope).** Two directions are deliberately set aside:
> (1) the **"really real" autonomous-world** direction — a genuinely
> off-screen-evolving world rather than reconstruction-on-encounter; and (2) a
> related but separable idea, in-game state **escaping onto the real desktop**
> (e.g. real OS push notifications fired from in-fiction events). The second is
> about the **sim↔reality membrane**, not about how the sim generates itself, and
> is orthogonal to this doc's concern; both are parked as deferred, out-of-scope
> directions the lead may revisit.

## Relationship to the other pillars

- **`prose-generation.md` — the downstream consumer.** The prose realizer is a
  **consumer that QUERIES `G`** to render: rendering the foveal slice *is* a query
  to `G`, which generates (and thereby commits-on-observation) exactly that slice.
  **Faithfulness** re-grounds here: "true of state" means **consistent with all
  commitments / entailed by `G`** — not "true of a pre-stored state snapshot,"
  because there *is* no stored snapshot, only `G` and the constraint set. The
  realizer's "assert only what is true of the model's state" rule becomes "assert
  only what `G` entails under the current constraints." **Depth is upstream still
  holds**: prose depth = the richness of `G`'s answers; the realizer renders that
  depth and can never exceed it.

- **`semantic-layer.md` — `G`'s generative prior.** The **prevalence-weighted
  knowledge graph** is `G`'s **prior**: what is *typical* in the world (apple→red
  typical, green common, yellow less so) is *how `G` draws* — the typicality
  weights shape which consistent completion `G` produces when more than one would
  satisfy the constraints. The **faithful-coarsening / "mipmaps for meaning"** LOD
  spine remains valid, in its corrected scope: it governs **describing / observing
  already-committed state** (a glance vs. an inspection of something already on the
  record — the cheap answer a true prefix of the expensive one, no popping). It is
  **not** how the *timeline* is generated — that is `G` under the constraint set,
  not a coarse projection driving commitments.

- **`npc-mind-and-language.md` — the brain is part of `G`.** The real
  cognitive/personality brain (its *first* demand — memory, beliefs, drives,
  emotion, relationships, theory-of-mind, personality, autonomous inner life) is
  **the part of `G` that generates an agent's intent and behavior under
  constraints**: an NPC's response is `G` answering "what does this agent do/mean,
  given the seed, everything committed, and this situation," consistent with all
  prior commitments about that agent. Its `seed + event log` **determinism
  invariant is the root** of this whole substrate — the constraint set *is* the
  event log's entailment-closure, and `G`'s purity is that invariant applied to
  generation.

## Open threads

The crux sub-problems, restated as the open work (all OPEN). The 2026-06-19
prior-art pass (*What the prior art says*, above;
`docs/research/crux-prior-art-constraint-generation.md`) reframes several of
these — verdict **known-hard-with-workarounds**, not freshly open.

- **Painting into a corner / satisfiability** — CSP-under-determinism: draws that
  preserve future satisfiability against an arbitrary, growing constraint set.
  *The sharp one.* **Prior art:** completion-existence is NP-hard *in general*, but
  corner-risk scales with **global** constraints — so the **locality lever** below
  makes most of this tractable by design.
- **The locality lever** — corner-risk is empirically driven by **global
  (non-local)** constraints; local-adjacency constraints almost never corner.
  *Structure the world so constraints are mostly local; bound and minimize global
  ones.* This turns the crux's tractability substantially into a **design choice**
  (and is itself an open piece of world design: deciding which constraints can be
  kept local).
- **The candidate technique stack** — recommended **starting point** (not a
  decided implementation): solver-based **SAT/ASP** formulation +
  **Ginsberg's dynamic backtracking** (complete, polynomial-space, recovers from a
  corner without discarding committed work). Open: its fit to *online
  constraint-addition* rather than a fixed CSP.
- **The unbounded-incremental regime — the residue (primary open problem)** — no
  surveyed system clears bounded per-query cost *and* unbounded incremental fact
  accumulation at scale. Iterated belief revision shows the committed-history state
  needed for future consistency grows **exponentially** and cannot in general be
  folded into one current state; `G` needs a principled policy for when history can
  be committed (bounded representation). This is the formal twin of the crux.
- **The constraint language** — what entailments an observation commits, and at
  what abstraction level.
- **Stable query / fact identity** — a canonical key namespace independent of
  access path, over an unbounded query space.
- **The commitment boundary** — what exactly counts as "observed" and
  crystallizes.
- **Multi-observer / multiplayer** — shared commit log and a single canonical
  constraint ordering across concurrent observers.
- **Per-query cost bound** — enforcing "cost proportional to engagement" as the
  constraint set grows.
- **Is eager forward-sim actually infeasible? (UNVERIFIED premise)** — the
  rejection of "simulate then render" rests on eager being unaffordable, which the
  prior-art pass did **not** confirm (zero verified claims; DF/Qud ship at scale;
  `existence` shows eager-deep cheap at N=1). Constrain-then-generate does not
  depend on this being proven, but the premise is open.

These are unsolved. The **target** (observer-indistinguishability) and the
**architecture** (constrain-then-generate) are decided; the **generator that
satisfies a growing global consistency constraint set deterministically and at
bounded cost** is the open frontier — **known-hard-with-workarounds**, with the
unbounded-incremental regime as the unsolved core.

---

## Cross-links

- `docs/research/crux-prior-art-constraint-generation.md` — **the cited prior-art
  map for this crux.** Adversarially-verified deep-research pass (2026-06-19);
  verdict **known-hard-with-workarounds**. Source for *What the prior art says*:
  completion-existence NP-hard in general, the locality lever, correct-by-design
  "incomplete-never-wrong" at constant-bounded scale, the SAT/ASP + Ginsberg
  dynamic-backtracking candidate stack, and the belief-revision residue. Respect
  its marked confidence levels and refuted/open caveats.
- `docs/decisions/prose-generation.md` — **the downstream consumer.** Its *Depth
  is upstream* framing sites this substrate as the binding constraint it depends
  on but does not solve; the realizer is a consumer that **queries `G`** to render,
  and its faithfulness is consistency-with-commitments / what `G` entails.
- `docs/decisions/semantic-layer.md` — **`G`'s generative prior.** Its
  prevalence-weighted graph is what `G` draws *from* (typical → how to complete);
  its faithful-coarsening / "mipmaps for meaning" LOD spine remains valid for
  *describing / observing* already-committed state, not for *generating* the
  timeline.
- `docs/decisions/npc-mind-and-language.md` — **the brain is part of `G`, and the
  determinism invariant is the root.** Its *first* demand (the real
  cognitive/personality brain) is the part of `G` that generates an agent's
  intent/behavior under constraints; its `seed + event log` determinism invariant
  is exactly what `G`'s purity over `(seed, constraint-set, query)` refines.
