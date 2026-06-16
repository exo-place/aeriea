# `existence` as partial prior art for the substrate crux

Status: **PRIOR-ART STUDY — evidence-cited; informs the substrate decision, decides nothing** (2026-06-17)

Scope: this studies the `existence` codebase (`~/git/paragarden/existence`,
cited in aeriea's `CLAUDE.md` as the "simulation-underneath-rendering pattern,
~67k LOC working code") as **partial** prior art for the open crux in
`docs/decisions/simulation-depth-and-materialization.md` — *deterministic,
bounded-cost generation under a growing global consistency constraint set* — and
for the realizer↔`G` interface in `docs/decisions/prose-generation.md`. It reads
`existence` against aeriea's decided target (**observer-indistinguishability**)
and architecture (**constrain-then-generate**, `G(seed, constraints, query)`),
and asks which of aeriea's two rejected forks `existence` actually built, what
its cost story is, and what transfers. Every claim is cited to a file and line in
`existence` as read on 2026-06-17; where the code does not settle a question, that
is said plainly. This contains no engine code and changes nothing in `existence`
(read-only). It is analysis, not advocacy: where `existence` is evidence
*against* an aeriea premise, that is stated.

---

## What `existence` is

A single-player text game in plain ES-module JavaScript. `README.md:1-8`: "A
text-based HTML5 game … The simulation runs underneath: neurochemistry, sleep
debt, financial anxiety … None of it surfaces as numbers. What you see is what
the character produces." It is the same "simulation underneath, rendering on top"
ethos aeriea cites, built out.

Size, verified: ~79k LOC of JS/TS outside `node_modules`/`vendor`/`.git`. The
bulk is **data, not engine** — `js/content.js` is 38,480 LOC (all prose +
interaction definitions) and `js/names.js` is ~588 KB of name corpora. The
*engine* is much smaller: `js/state.js` (10,740 LOC — the simulation),
`js/realization.js` (4,017 — the prose realizer), `js/world.js`, `js/game.js`,
`js/senses.js`, `js/timeline.js`. The "~67k LOC" figure in aeriea's `CLAUDE.md`
is the right order of magnitude for the whole tree; the load-bearing engine is a
fraction of it. This matters for the transfer question: the working part aeriea
cares about is a few thousand lines, not 67k.

**Entity model — verified single deep protagonist + a thin NPC ring.** There is
exactly one richly-simulated entity: the player-character, with **28
neurochemical systems** plus dozens of physiological state variables
(`STATUS.md:30`; the `defaults()` block in `state.js`). Around it sit **5-10
named NPCs** (1-3 family, 2 coworkers, 2-3 friends, a sponsor) carried at far
lower fidelity — three personality scalars (warmth/openness/stability), one
stress value, an active-events list (`docs/design/npc-simulation.md:93-122`).
`docs/design/npc-simulation.md:376` states the count directly: "likely 5-10 for
most characters." This is the single most important framing fact for the transfer
to aeriea: **`existence` proves out eager deep-sim for ONE entity, not for a
world of them.**

## Which fork: eager forward-sim, but event-paced (not wall-clock)

`existence` took the fork aeriea calls **eager forward-sim** — the fork aeriea's
substrate doc rejects as "infeasible" (`simulation-depth-and-materialization.md`
→ *Eager forward-sim is infeasible*). But it is eager in a specific, restricted
shape that is the whole reason it is affordable, and that shape is the
decision-relevant finding.

**The tick loop is `advanceTime(minutes)` in `state.js:1102`.** It is a genuine
forward integrator: each call advances `s.time` and walks every modelled system
forward over the elapsed interval — gastric emptying as exponential decay
(`state.js:1147`), hunger/thirst/bladder accumulation
(`state.js:1199,1234,1263`), cortisol/stress decay
(`state.js:1113,1302`), neurochemistry drift (`driftNeurochemistry`,
`state.js:3161`), and a **per-minute** momentary-affect injector that loops
`for (let m = 0; m < wholeMinutes; m++)` drawing one PRNG value per game-minute
(`state.js:3199-3252`). This is forward-sim in the literal sense: state at
`t+Δ` is computed forward from state at `t`.

**But it only advances when the player acts.** There is no autonomous world loop.
`advanceTime` is called from action handlers (`game.js:824,1391,1827`;
`world.js:313`; `items.js:516`), each action consuming a small block of minutes
(`advanceTime(randomInt(2,5))` is the idle default, `game.js:1827`). Confirmed
absence of a wall-clock simulation tick: the only `setInterval`/`setTimeout` in
the client (`ui.js:18,126,144`) drives an **idle-thought UI timer**, not the sim
— and it pauses when the tab is hidden (`ui.js:87`). **Game time is a function of
player action, not of real time.** This is `existence`'s answer to aeriea's "pay
per query, never per world-tick": it pays per *action*, and the unplayed future
costs nothing because it is never advanced.

So `existence` sits at: **eager forward integration of one deep entity, advanced
only on player action, over short spans.** It is *not* the persistent autonomous
world ("seconds per tick for a persistent world") that `simulation-depth-and-
materialization.md` argues is infeasible — it sidesteps that by never running the
world when the player isn't there.

## The cost story — the single most decision-relevant finding

This is direct evidence on aeriea's load-bearing premise that "eager is
infeasible," and the honest reading is **nuanced, not a clean confirmation**:

**Eager deep-sim of ONE entity is cheap and worked.** The protagonist's
28-system per-minute integration carries heavy, citation-grounded physiology
(scan `state.js` for "PMID"/"DOI"/"Approximation debt" — they are everywhere,
e.g. `state.js:1113,1147,1199`) and there is **no evidence anywhere of a
per-tick cost wall** for it. No "too slow," no frame-budget caps, no perf-driven
LOD on the protagonist's systems. The HHS+ "seconds per tick" problem
(`simulation-depth-and-materialization.md` → *Eager forward-sim is infeasible*)
**does not appear** in `existence`. The reason is structural, and `existence`
engineered for it explicitly: the per-minute loop is **call-size-independent** —
`advanceTime(120)` walks the same path as `120×advanceTime(1)` via a live
headroom soft-clip (`state.js:3191-3196`), so fast-forwarding a long idle span
is O(minutes) of cheap arithmetic with a *fixed* PRNG draw count
(`state.js:3174-3178`: "EXACTLY ONE Timeline.random() draw per whole
game-minute … advanceTime(m) always consumes the same number of rng values").
Deep, per-minute, eager — and never a cost problem, because there is one entity
and the span is bounded.

**The NPC ring is eager too, and explicitly "negligible."** NPC life-events roll
once per sleep cycle over the 5-10 named NPCs via `backgroundRng`
(`docs/design/npc-simulation.md:166,204-208`), and the design states the cost
outright: `npc-simulation.md:374-378` — "The event generation pass iterates over
all NPCs above low resolution (likely 5-10) … This is negligible. … No
performance concern." So eager-sim of a *small ring* of *coarse* entities is also
fine.

**Where it strains is exactly where aeriea's premise points: count and depth.**
`existence` never tries to simulate a *world* of deep entities. The NPC ring is
kept affordable by being (a) tiny in count and (b) shallow in fidelity — three
scalars and an event slot, not 28 systems. The design's own
"dynamic-resolution, never zero" ambition (`npc-simulation.md:38-86,268-296`) —
the part that would scale fidelity *up* per NPC — is **designed but not
implemented** (`npc-simulation.md:367`: "Dynamic resolution scaling … is designed
but not implemented"; `:368`: "Stranger simulation … is not yet designed"). The
honest verdict on the cost premise:

> **`existence` confirms that eager deep-sim is cheap at N=1 and eager
> coarse-sim is cheap at N≈10. It does NOT test eager deep-sim at large N — it
> avoids that regime by construction. So it neither proves nor refutes aeriea's
> "eager forward-sim is infeasible" claim at the scale that claim is about; it
> shows the wall is a product of depth×count, and that the wall can be dodged by
> capping both rather than by changing architecture.**

That is a genuine and slightly uncomfortable finding for aeriea: `existence` is
evidence that the *eager* fork is viable far longer than a flat reading of
"eager is infeasible" suggests — *if* you are willing to cap depth×count and run
only on player action. aeriea's premise survives, but with a sharpened scope: the
infeasibility is specifically about an **unboundedly deep, persistent,
autonomous** world, not about eager integration per se.

## The sim→render seam, mapped to aeriea's realizer↔`G`

This is where `existence` is strongest as prior art, because it is a **working
instance of aeriea's prose realizer pattern**, and the seam is precisely the
shape `prose-generation.md` specifies.

The interface is one function: **`realize(observations, hint, ntCtx, random) →
prose`** (`realization.js:3960`). Mapping each argument to aeriea's vocabulary:

- **`observations`** = typed propositions about state (each carries `sourceId`,
  `channels`, `acoustic`, etc. — `realization.js:3850,3899`). This is aeriea's
  *salient state* (`prose-generation.md` → *Content determination + salience*).
  They are produced upstream by the sensory compositor (`senses.sense()`,
  `game.js:822,1390,1811`) selecting what is *noticeable* given current state
  (`docs/design/senses.md` → *Noticeability, not intensity*) — i.e. `existence`'s
  salience stage.
- **`hint`** = an NT-derived register/affect tag (`calm`/`overwhelmed`/etc.;
  `realization.js:3861,3964`). This is aeriea's *communicative intent*'s
  stance/affect/register slot — affect drawn from the simulated brain, not
  invented.
- **`ntCtx`** = the neurochemical context that modulates lexical/architecture
  choice (`realization.js:3850` ff.) — aeriea's "lexical choice is
  body/fluid/arousal/register-aware" (`prose-generation.md` → *Semantic-grounded
  realization grammar*), here NT-aware.
- **`random`** = a *seeded* PRNG passed in, used to pick among **equivalent**
  realizations — aeriea's *Seeded variation / anti-repetition*
  (`prose-generation.md` stage 4). Determinism and freshness coexist exactly as
  aeriea designs.

The body of `realize`/`realizeOne` (`realization.js:3850-4017`) is aeriea's
"generalize, don't multiply" grammar in working form: a **modest set of
sentence architectures** (`short`/`body`/`bare`/`ambig`/`escape`/`reframe`/
`char_pred`/`flat_taut`/`inversion`, weighted by the affect `hint` —
`realization.js:3864-3876`) and **passage shapes**
(`appositive`/`terminal_list`/`arrival_seq`, `realization.js:3990-4003`) applied
to per-source authored lexical sets (`LEX[obs.sourceId]`,
`realization.js:3852`). It is rule-grammar over rich state — *not* template
mad-libs (the architecture is chosen by NT state, not by a 1:1 label) and *not* a
hot-loop LLM. This is a live demonstration that aeriea's "no template mad-libs /
no hot-loop LLM" realizer is buildable.

**The crucial mapping for aeriea's substrate doc: in `existence`, `realize`
queries a stored state object; in aeriea, the realizer queries `G`.** That is the
one real architectural difference at this seam. `existence`'s realizer reads from
`ctx.state` (a materialized snapshot advanced by `advanceTime`); aeriea's realizer
"is a consumer that QUERIES `G`" (`simulation-depth-and-materialization.md` →
*Relationship to the other pillars*; `prose-generation.md` → faithfulness note).
But the realizer-*side* contract is identical — *(salient typed observations +
affect + seed) → faithful, fresh, deterministic prose* — so everything
`existence` learned on the realizer side transfers regardless of whether the
state behind it is a snapshot or `G`. **`existence` de-risks the entire downstream
half of aeriea's pipeline.**

## Determinism — strong, and directly transferable

`existence` is deterministic in exactly aeriea's `seed + action log` sense, and
its implementation is a clean reference for several of aeriea's open sub-problems.

- **Seeded PRNG, replayable.** xoshiro128** seeded via splitmix32
  (`timeline.js:10,49`), one non-deterministic call only for the *initial* seed
  (`timeline.js:101-106`: "this is the ONE place we use non-deterministic
  randomness"). `README.md:25`: "Same seed + same action sequence = same world
  state."
- **Action log + replay, not state snapshots as truth.** The action log is the
  record (`timeline.js:277,323-342`); restore re-derives the same sub-seed chain
  (`timeline.js:328-339`). This is aeriea's "the constraint-set is itself a
  function of seed + action log" in working form — minus the entailment closure.
- **Stream separation = aeriea's "cosmetic vs mechanical" line, prebuilt.** Four
  independent sub-streams from one master seed: `charRng`, `rng`, `cosmeticRng`,
  `backgroundRng` (`timeline.js:81-97`), with a fixed derivation order so
  "inserting a new stream at the end never shifts existing ones"
  (`timeline.js:84`). Critically, **prose-only variation runs on `cosmeticRng`**
  so it "never [affects] mechanical outcomes" (`timeline.js:63,219`). This is a
  concrete, working answer to a hazard aeriea will hit: keeping the *freshness*
  draw from perturbing the *causal* timeline.
- **Fixed-draw-count discipline — the transferable trick.** The single most
  reusable determinism lesson: *never let the number of PRNG draws depend on an
  outcome*, or replay desyncs. `existence` enforces this everywhere — one draw
  per game-minute regardless of what happens (`state.js:3174-3178`), one draw per
  `recall()` even on the empty path (`memory.js:135-140`: "The fire roll is
  ALWAYS drawn — even on the empty path … never branch BEFORE the draw"), and
  chargen pads draws across branches (`chargen.js:113-115`). aeriea's `G` must
  obey the same rule under its purity requirement; `existence` shows the
  discipline in practice.
- **Same float caveat aeriea carries.** `existence`'s arithmetic is float
  arithmetic; it does not solve cross-platform float determinism — the identical
  caveat in `simulation-depth-and-materialization.md` → *Determinism*.

## Consistency — emergent, not maintained; and one place it is openly lossy

This is where `existence` is **weakest** as prior art for aeriea's crux, and the
gap is exactly aeriea's hard core.

`existence` has **no constraint-maintenance layer.** World consistency is purely
emergent from forward-sim over a single materialized state object: there is one
state, it is advanced forward, and it cannot contradict itself because there is
only ever one value per variable. There is **nothing resembling
constrain-then-generate, forward-checking, or satisfiability preservation** — the
sharp open problem in `simulation-depth-and-materialization.md` → *Painting into
a corner / satisfiability* simply does not arise, because `existence` never
generates a fact *late* that must be consistent with earlier free commitments. It
commits everything eagerly into one mutable store, so "no consistent completion"
is impossible by construction — and that is precisely the construction aeriea
*rejected* (a materialized forward store).

What `existence` *does* have, partially, near aeriea's idea:

- **On-demand generation exists, but only at the disposable leaves.** Ephemeral
  one-scene strangers are generated at encounter from a couple of `backgroundRng`
  draws and **not persisted** (`npc-simulation.md:79-85,74`: "Generated per day
  or per encounter via `backgroundRng`. Not stored long-term"). This is
  lazy-generation, but for state that *causes nothing downstream* — so it never
  has to be consistent with future commitments. It is the cheap-but-lossy leaf
  case, made safe by being causally inert. It does **not** demonstrate
  lazy-consistent generation of *load-bearing* state, which is aeriea's actual
  problem.
- **Memory is generated-from-log — but deliberately lossy.** `recall()` keys off
  the **event log** (`memory.js:148` — `ctx.events.all()[ref.idx]`) and
  reconstructs a fragment from the encoded affect, which is genuinely
  generate-from-the-record rather than read-from-a-store. But it then applies
  **reconsolidation drift** on every recall (`memory.js:171` "subsequent recalls
  drift it"; `:38` "Approximation debt (memory reconsolidation-drift)"). This is
  the opposite of aeriea's stance: aeriea forbids committing a drifted/approximate
  fact ("never committing a falsehood"; *Incomplete, never wrong*), whereas
  `existence` *embraces* lossy memory as a feature (faithful to how human memory
  actually works). Instructive contrast, not a transferable mechanism.

There is one consistency *tool* worth noting, though it operates at the **code**
level, not the runtime: `scripts/sim-audit.js` (1,706 LOC) statically extracts
the simulation's coupling graph and runs **pathology detection** — orphaned state
vars, feedback cycles, dead state (`sim-audit.js:3,841,1070,1340-1345`). It
rhymes faintly with aeriea's concern about a consistent constraint graph, but it
is a *build-time linter over hand-written couplings*, not a runtime constraint
solver. It does not touch the satisfiability-under-growth problem.

## What transfers to aeriea

Concrete and reusable, in rough order of value:

1. **The realizer is essentially solved, and `existence` is the reference.** The
   `realize(observations, hint, ntCtx, random) → prose` seam
   (`realization.js:3960`), the affect-weighted architecture/passage grammar
   (`realization.js:3864-4003`), per-source lexical sets, and seeded
   equivalent-realization selection are a working build of `prose-generation.md`'s
   generator architecture (stages 1, 2, 4). aeriea should treat `existence`'s
   `realization.js` + `senses.js` as a concrete prototype of its realizer, since
   the realizer-side contract is identical whether state comes from a snapshot or
   from `G`.
2. **The determinism kit transfers wholesale.** Seeded multi-stream PRNG with
   fixed derivation order (`timeline.js:81-97`), the cosmetic/mechanical stream
   split (`timeline.js:63`), action-log replay (`timeline.js:323-342`), and above
   all the **fixed-draw-count discipline** (`state.js:3174`; `memory.js:135`;
   `chargen.js:113`) are directly applicable to `G`'s purity requirement.
3. **Call-size-independent integration** (`state.js:3191-3196`) is a proven
   pattern for "fast-forward an idle span at bounded, replay-stable cost" — useful
   to aeriea for *any* span where state is genuinely advanced rather than
   generated.
4. **Salience-as-noticeability** (`docs/design/senses.md`; `senses.sense()`) is a
   working model of aeriea's content-determination stage: select what surfaces by
   *relational salience to current state*, not raw magnitude — and emit *less*
   prose when nothing salient changed.
5. **NPC depth via personality-params + life-facts + events** (the whole
   `npc-simulation.md` model) is a concrete pattern for low-cost NPC interiority
   that beats label/archetype dispatch — relevant to whatever `G`'s NPC-brain
   answers look like at the cheap end.

## Where `existence`'s trade differs from constrain-then-generate

`existence` made the **opposite** of three of aeriea's load-bearing choices —
deliberately and reasonably for its own goals, but the divergences are exactly
the ones aeriea's substrate doc reasoned through:

- **Materialized forward store vs. generative function.** `existence` advances one
  mutable state object (`ctx.state`) forward in time; aeriea makes ground truth a
  pure function `G(seed, constraints, query)` with no advancing store
  (`simulation-depth-and-materialization.md` → *The architecture*). `existence`
  is the "simulate then render" fork; aeriea is "constrain then generate."
- **Cap depth×count vs. pay-per-engagement at unbounded depth.** `existence`
  keeps cost down by *capping* what is simulated (one deep PC, ~10 shallow NPCs,
  no autonomous world); aeriea wants depth that is **unbounded under probing** but
  paid for **only when probed**. `existence`'s cap is a ceiling on depth; aeriea's
  goal has no such ceiling — which is precisely why it cannot use `existence`'s
  fork and must solve generation-under-constraints instead.
- **Lossy-by-design where aeriea is lossless-or-incomplete.** `existence` commits
  approximate/drifting state freely (memory drift, `state.js`'s pervasive
  "Approximation debt" tuned constants, ephemeral non-persisted NPCs); aeriea's
  hard line is *never commit a falsehood — incomplete, never wrong*
  (`simulation-depth-and-materialization.md` → *Why this is lossless*). aeriea
  chooses differently because its target is adversarial-probe-indistinguishability
  under replay, where a committed approximation is a detectable seam;
  `existence`'s target is felt texture, where drift *is* fidelity.

None of these are `existence` doing it wrong — they are `existence` optimizing a
different target. But they mean `existence` validates the *downstream* half of
aeriea's design (realizer, determinism, salience) while taking the *upstream*
substrate fork aeriea explicitly rejected.

## What `existence` does NOT answer

The honest gaps — `existence` is partial prior art, and the part it leaves open
**is aeriea's entire open crux**:

- **The central crux — bounded-cost generation under a growing global consistency
  constraint set — is untouched.** `existence` never generates load-bearing state
  late against prior free commitments, so it has nothing to say about CSP-under-
  determinism, forward-checking, or *painting into a corner*
  (`simulation-depth-and-materialization.md` → *The central open crux*). Its
  consistency is the trivial kind (one mutable value per variable); aeriea's is
  the hard kind (an arbitrary growing constraint set with a satisfiable
  completion required).
- **`G` itself does not exist in `existence`.** There is no generative
  ground-truth function — only a forward-advanced store. The realizer↔`G`
  interface transfers on the *realizer* side; the `G` side is entirely aeriea's to
  build.
- **The constraint language, stable query/fact identity, the commitment boundary,
  per-query cost bound** (the other OPEN sub-problems in the substrate doc) have
  no analogue in `existence`. Stream-separation and the cosmetic/mechanical split
  rhyme with the commitment-boundary question but do not answer it.
- **Multi-observer / multiplayer.** `existence` is strictly single-player, one run
  per playthrough (`README.md:27`). It says nothing about the shared-commit-log /
  canonical-ordering problem.
- **Large-N deep simulation.** As established under *The cost story*: `existence`
  avoids the regime aeriea's infeasibility premise is about, so it cannot
  empirically confirm or refute the wall at scale — only locate it at depth×count.

## Verdict

**`existence` makes aeriea's direction look MORE viable on the downstream half and
leaves the upstream crux exactly as open as before — with one sharpening of the
premise.**

What it de-risks, concretely: the **realizer** (`realize(...)` is a working build
of `prose-generation.md`'s generator, proving the no-mad-libs/no-hot-loop-LLM
prose engine is buildable) and the **determinism substrate** (seeded multi-stream
PRNG, action-log replay, and the fixed-draw-count discipline that `G`'s purity
will require). These are real, transferable, and not small — they are roughly the
entire bottom half of aeriea's pipeline, demonstrated in production code.

What it leaves open: **all of it that matters most.** The generative function `G`,
constraint maintenance, satisfiability-under-growth, the constraint language,
stable query identity, the commitment boundary, per-query cost bounds, and
multiplayer ordering have **no prior art in `existence`** — it took the
materialized-forward-store fork and so never met these problems.

The one sharpening: `existence` is mild evidence that the **eager fork is more
viable than a flat reading of aeriea's premise suggests** — eager deep-sim is
cheap at N=1, eager coarse-sim is cheap at N≈10, and the wall is a function of
depth×count dodged by capping both and running only on player action. This does
not refute aeriea's choice — aeriea's target (unbounded depth under probing,
persistent and lossless) genuinely cannot be served by capping depth×count, which
is why constrain-then-generate is the right fork *for aeriea's target*. But it
does mean the premise should be stated precisely: eager is infeasible for an
**unboundedly-deep, lossless, probe-resistant** world — not for deep simulation
in general. `existence` proves the latter is fine; aeriea's crux is the former.

---

## Cross-links

- `docs/decisions/simulation-depth-and-materialization.md` — the substrate
  decision this study informs: target (observer-indistinguishability),
  architecture (constrain-then-generate, `G(seed, constraints, query)`), and the
  open crux (CSP-under-determinism over a growing constraint set). `existence`
  validates the realizer/determinism downstream and leaves this doc's crux open.
- `docs/decisions/prose-generation.md` — the realizer design `existence`'s
  `realization.js` is a working instance of: `realize(observations, hint, ntCtx,
  random) → prose` maps onto *(salient state + communicative intent + seed) →
  prose*, with affect-weighted grammar and seeded equivalent-realization variation.
- `docs/decisions/npc-mind-and-language.md` — the brain-is-part-of-`G` and
  `seed + event log` determinism invariant; `existence`'s multi-stream seeded PRNG
  + action-log replay + fixed-draw-count discipline are a concrete reference for
  that invariant.
- `docs/decisions/reference-analysis.md` — the recombination / "generalize, don't
  multiply" precedent `existence`'s grammar also embodies.
