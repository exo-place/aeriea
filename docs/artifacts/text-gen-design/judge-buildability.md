# Judge — Buildability / Fig-Leaf Audit

Adversarial lens: **buildability**. Score = how well a candidate survives attack on
(1) finite vs. unbounded authoring, (2) hidden runtime-LLM / nondeterminism,
(3) the cache-miss / coverage tail, (4) first verifiable shippable increment.

Bar to clear: NPCs that feel alive at TiTS/CoC/LT/FS level, deterministic
bit-for-bit, no runtime LLM, build-time LLM only if it yields a finite shippable
artifact and not a fig leaf.

The governing prior, from `creator-saga/SESSION-RECORD.md`: a system passed ~25k
asserts, survived 15+3+10 adversarial rounds, and shipped *obviously broken*. The
documented failure mode is **a grand coverage thesis nobody can verify that burns a
session and ships nothing playable.** Every candidate is judged against that ghost.
Verified against the tree: `scripts/text/npc_realizer.gd` (272 LOC),
`scripts/text_sandbox.gd` (308 LOC), `scripts/text/maren_history.gd` (156 LOC) all
exist and run today — this is load-bearing for E and is real.

---

## Candidate A — Subtract the generator (beat-graph walk)

**Score: 6/10**

**Hardest attack — the authoring number is the whole product, and A's own number is
a session-killer at the slice.** A says a vertical slice of *one* character is
"150–400 authored beats (with variants, ~600–1500 passages)" and "weeks of
human-directed authoring for one deep character" (§7). That is not a first
increment; that is the entire moonshot budget spent before *anything* is playable.
The session-record failure mode is precisely "spend the whole session, ship nothing
the user can judge." A has no sub-slice that ships — there is no "10-beat Maren you
can play in an afternoon" milestone anywhere in the doc. The graph only feels alive
once the peer-beats-per-region density is high enough that the anti-repeat ledger
isn't cycling 2–3 lines; A admits this ("can feel on rails at fine grain if authors
write too few peer beats," §6) and the *only* lever it offers is "more authoring."
So the minimum viable demo is large and the doc never bounds it below "weeks."

**Does it survive?** Partially. The runtime is genuinely trivial and genuinely
model-free (guard eval + rank + variant pick + exit-follow — "a few hundred lines
over the existing interpreter," and that interpreter exists). Determinism is clean:
`hash(seed, action-log, beat.id)` total order, no floats, no learned weights. There
is no hidden runtime LLM and no hidden nondeterminism — Opus is build-time drafting +
lint only, and the doc passes its own fig-leaf test honestly ("if you deleted Opus
the system still ships"). The coverage tail is real and buildable: the starvation
lint forces a regional default beat so there are *no silent gaps*, and the tail
degrades to real authored prose, not mad-libs. **It survives the fig-leaf attack but
fails the first-increment attack:** the smallest thing A can ship is too big to ship
soon. The build-time **repetition-lint** ("two beats that read too similarly") also
quietly smuggles a taste-judgment back into an Opus critic — the exact "detection ≠
taste" copout the session-record flagged as meta-learning #2 — though A correctly
keeps it advisory (human signs every line), so it dents but doesn't sink it.

---

## Candidate B — Invert the dependency (frozen-embedding retrieval)

**Score: 4/10**

**Hardest attack — the frozen-embedding retrieval is the one place a hidden model
quietly does load-bearing taste work, and B leans its whole "alive" claim on it.**
B's determinism is airtight *mechanically* (i16 embeddings, integer cosine via
cross-multiplication, no float div/sqrt, `beat_id ASC` backstop — §2.2/2.3). Grant
all of that. The attack is upstream: the *ranking quality* — which beat actually
gets picked among the precondition-valid set — rides entirely on the build-time
embedding model's geometry, and B admits it ("if the embedding geometry is bad,
retrieval picks tonally-wrong beats," §6). The hard-precondition filter narrows to a
valid set, but B's own worked example shows the **embedding doing the dramatic
selection** ("scene-vector ≈ embedding of `[familiar, tired_wry, late, greet,
faint-old-slight]`, argmax beat"). That means an opaque frozen model is the arbiter
of "which authored line is dramatically right here" — and the session-record's
meta-learning #3 is that *taste cannot be added by a net the generator lacks.* B
moves the taste decision into a frozen embedding and *calls it deterministic*, which
is true but irrelevant: frozen-wrong is still wrong, deterministically. You cannot
edit a bad ranking the way you edit a bad line; you re-embed and pray the geometry
moved the right way.

Second blade: if the embedding only ever ranks *within* a precondition-and-chain-
valid candidate set (as §2.2 steps 1–2 enforce), then the embedding is doing almost
no work — the preconditions + `chain_next` already determine coherence, and you
could replace argmax-cosine with a plain authored `pull` scalar (i.e. you'd have
Candidate A). So B is impaled either way: either the embedding is load-bearing (and
it's a hidden opaque taste-oracle that can't be hand-corrected) **or** it's
decorative (and B is a more complex A). The 256-dim i16 vector per beat is the
*tell* — it's machinery that earns its complexity only if it's making the call, and
if it's making the call it's the failure mode.

**Does it survive?** No, not at buildability. It is the most over-engineered
candidate relative to what ships, and the first increment is *worse* than A's: you
must author the corpus **and** stand up a build-time embedding pipeline **and**
quantize **and** validate the geometry produces non-jarring rankings — before you
can play one scene. The coverage tail is hand-waved harder than the others: the
"relax the least-load-bearing precondition dimension and re-query" tier (§5) needs a
*declared ordering of precondition load-bearingness* that the doc never specifies and
that is itself a taste judgment. Lowest first-ship velocity of the five.

---

## Candidate C — The Bible Compiler (Opus compiles the bible into tens of thousands)

**Score: 3/10**

**Hardest attack — "Opus compiles the bible into 10k–60k situated passages" is the
fig leaf the prompt named, dressed as a compiler.** This is the candidate the
fig-leaf audit exists for. C's central claim (§2.2, §7) is that a human writes a
"tens of pages" bible and Opus *expands* it into "~2k–8k passages × 3–6 variants =
tens of thousands of frozen strings" per NPC, in "hours-to-days of offline GPU/$."
Pressure-test every word of that:

1. **Quality at scale is asserted, never shown.** The session-record's hardest-won
   lesson (#1, #4) is that automated generation that passed every gate still shipped
   slop, because *nobody with taste read the output.* C's compiler generates tens of
   thousands of passages and proposes a *second Opus pass to curate* (§2.2 step 2) —
   i.e. an LLM-judge curating LLM output, which is meta-learning #2's "detection is a
   copout" verbatim. A human reading and approving 30k–60k passages per NPC is not
   "hours-to-days"; it is the same author-everything labor as A/D/E, except now the
   human is *proofreading machine output* (the worst, most-fatiguing, most-rubber-
   stamp-prone form of the task) instead of writing with intent. The doc says "the
   human writes the bible, the compiler expands it" — but an unread 60k-passage
   expansion is exactly the 25k-green-asserts-still-broken trap.

2. **The bible→passage expansion is an unbounded-quality regress, not a finite
   build.** "Opus expands the authored voice across the declared signature space"
   assumes Opus holds one consistent deep voice across tens of thousands of generated
   passages without drift, repetition, or confabulation — the precise failure modes
   the session-record names as recurring and unsolved. C waves this with "conditioned
   on the voice portrait," but conditioning is not preservation; 60k generations from
   a prompt drift. The artifact is *finite in byte count* (single-digit MB,
   trivially shippable — granted) but **the quality of the artifact is unbounded
   labor in disguise**: either Opus's unread output ships (slop) or a human reads it
   all (no cheaper than authoring).

3. **The signature cross-product is hand-waved finite.** §7: "naive cross-product is
   large (8⁵≈33k) but the author prunes to reachable combos." *Who prunes 33k tuples,
   and by what?* That pruning is itself a large authoring/taste task the doc assigns
   to no one and budgets at zero.

**Does it survive?** No. C is the clearest fig leaf in the set: it relocates the
moonshot from runtime to "the compiler" and asserts the compiler is finite because
its *output bytes* are finite, while the *quality* of those bytes is either unverified
(slop) or human-verified-at-full-cost (no savings). The runtime is fine (indexer +
finite stitch-table, deterministically content-addressed — that part is real and
clean). The fallback lattice (§5) is the best-specified coverage tail of any
candidate (ordered axis-coarsening, provenance re-checked, authored floor). But
buildability is gated by the build step, and the build step is the fig leaf. First
increment is also a moonshot — nothing ships until the compiler exists and a bible is
written *and* its expansion is validated.

---

## Candidate D — Coarse-grain combinatorics (beats + opens/needs type-system)

**Score: 5/10**

**Hardest attack — the `O(beats²)` adjacency closure with a per-pair Opus judge is a
build-time bill D itself admits is "where the project-months go," and it's the same
LLM-judge-as-taste copout the session-record killed.** D's coherence guarantee is its
crown jewel and its anchor: "iterate the adjacency closure until *every type-legal
rendered adjacency is also judge-legal*" (§2.3, §5). For a viable first NPC at D's own
estimate of **1,500–2,500 beats** (§7), that is ~4M ordered pairs; D says most are
pruned by type-incompatibility but "the residual is a large build-time judge bill and
a real annotation-refinement effort." Two problems:

1. **The judge IS the taste oracle the session-record proved doesn't work.** The whole
   coherence invariant rests on "Opus coherence judge scores continuity / no
   contradiction / natural transition." Meta-learning #1–2: an adversary/judge only
   catches its rubric's failure classes; novel badness is invisible until a human
   hits it. D's "type-legal ⟹ judge-legal" invariant is exactly "passed all the
   automated gates" — and the saga's verdict is that passing all automated gates is
   not good. The closure can certify 4M pairs as judge-legal and still produce
   adjacencies a human finds jarring, because the judge's rubric is finite and the
   badness isn't.

2. **The iterate-until-converged loop has no proven fixpoint.** Each judge failure is
   fixed by "tighten the `needs`/`opens` annotation OR author a transition beat."
   Tightening annotations changes the type relation, which changes the closure, which
   surfaces new pairs to judge — a loop with no convergence argument and no bound on
   how many transition beats it spawns. This is a research-shaped build step
   masquerading as a finite compile.

**Does it survive?** Mostly, on a technicality D earns honestly: it *names* this as
"the honest risk that bites" (§7) rather than hiding it, and crucially **the
`opens`/`needs` type-check is the real deterministic runtime mechanism and it does not
need the judge at runtime** — runtime is a pure graph-walk + total-function slot
resolution (pronoun/tense agreement only, build-checked). No runtime LLM, clean
determinism (`seed + state_hash` tiebreak at the *beat* layer). The coverage tail
degrades to `role: transition`/`aside` authored generics — real, buildable. So D's
*runtime* survives cleanly; D's *build* is where it bleeds, and it bleeds the same
LLM-judge blood the saga warned about. The 1,500–5,000-beat first NPC is also a
moonshot-sized first increment with no sub-slice that ships earlier — same first-
increment failure as A and worse than E. D is more buildable than B/C (the closure is
at least *bounded and parallelizable*, and the runtime type-system is genuinely
elegant), but the judge-as-taste dependency caps it.

---

## Candidate E — Scope-to-what-ships (skeptic-realist)

**Score: 9/10**

**Hardest attack — the degradation/coverage story is the same authored-tail
concession everyone makes, and the "amplifier" is the same build-time Opus everyone
leans on, so what makes E better isn't the architecture — it's just a smaller
promise, and a smaller promise might mean a less-alive result.** Fair attack, and
the only one that lands: E *gives up the generative dream* explicitly (§7). If a deep
authored Maren slice still doesn't feel alive enough to the user, E has no answer but
"more/better authoring." E's ceiling is authoring-craft-bound, identical to A/D's
ceiling, and E doesn't pretend otherwise.

**Does it survive?** Yes — decisively, and it's the only candidate that survives the
*first-increment* attack, which is the attack the session-record says actually
matters. Concretely:

- **The first increment is verified-real, not asserted.** I checked the tree:
  `npc_realizer.gd` (272 LOC), `text_sandbox.gd` (308 LOC), `maren_history.gd` (156
  LOC) exist and run. E's Increment 1 (§8) is a **refactor + deepen** of running
  code — externalize the hardcoded prose to `maren.fragments.json`, reuse the
  *already-built-and-tested* affordance guard grammar (`sandbox.kit.json`
  interpreter), add the `memory.*` ref/callback channel, author *one* deep band
  (the compliment arc), golden-trace it, playtest it, hand to user. That is an
  afternoon-to-days increment that *ends in a playable, user-judgable slice* — the
  exact opposite of the session-killer.
- **No hidden model, no hidden nondeterminism.** The amplifier (§3.3) is an offline
  dev script the human drives, and E goes out of its way to say it "need not exist
  for increment 1 to ship — it can be authored by hand first." So E's first ship has
  *zero* LLM dependency anywhere, build-time or runtime. Determinism is structural
  (`hash(seed, fragment.id, state_hash)` variant pick over a few-hundred-line pure
  function).
- **The coverage tail is the most honestly buildable.** The `present_tell` grid is
  authored to be **total over the few primary axes** (mood × rapport), which already
  exists in `npc_realizer.gd`, so the uncovered-state floor is *good-and-brief by
  construction, never silent, never fabricated.* "Surface less, not fake more" is the
  one degradation rule in the set that is verifiable today.
- **It is the direct embodiment of the saga's own meta-learnings.** Human-as-author
  not human-as-gate (#5); taste lives in the human producer not an LLM-judge (#3);
  per-increment user-green on the running slice, no big autonomous rebuild (the thing
  that killed the creator).

The single risk E owns (authoring-bound ceiling) is **a known, bounded, fundable
risk** — the opposite of the moonshots' unbounded research risk. E loses a point only
because its honest ceiling means it *could* underdeliver on "alive" and need more
writing — but that's a content problem you discover cheaply in an afternoon, not a
session you burn to discover the architecture can't ship.

---

## Scoreboard

| Candidate | Score | Survives hardest attack? | One-line killer attack |
|---|---|---|---|
| **A** — beat-graph walk | 6/10 | Partially | Runtime is trivially buildable & model-free, but the *smallest* shippable slice is "150–400 beats / weeks" — no sub-slice ships soon; same session-killer risk. |
| **B** — frozen-embedding retrieval | 4/10 | No | The frozen embedding is either a hidden opaque taste-oracle you can't hand-correct (load-bearing) or decorative (then it's a more complex A) — impaled both ways; lowest first-ship velocity. |
| **C** — bible compiler | 3/10 | No | "Opus compiles the bible into 10k–60k passages in hours-to-days" is the named fig leaf: finite in *bytes*, unbounded in *quality-labor* — either unread slop ships or a human proofreads 60k at full cost. |
| **D** — beats + opens/needs | 5/10 | Mostly (runtime yes, build no) | The `O(beats²)` closure certified by a per-pair Opus judge is the exact "passed-all-gates-still-broken" / detection-as-taste copout the saga killed, with no proven fixpoint. |
| **E** — scope-to-what-ships | 9/10 | Yes | Only candidate whose first increment is a *verified-existing* refactor that ends in a playable, user-judgable slice with zero LLM dependency — and its only real weakness (authoring-bound ceiling) is cheap to discover. |

## Ranking (most → least buildable)

1. **E** (9) — clearly finite, mostly already built, ships verifiable aliveness soonest.
2. **A** (6) — genuinely buildable and model-free; loses to E only on first-increment size and an advisory repetition-lint that flirts with judge-as-taste.
3. **D** (5) — elegant deterministic runtime, but the build leans on an unbounded LLM-judge closure the saga warned against.
4. **B** (4) — over-engineered relative to what ships; frozen-embedding is a hidden taste-oracle dressed as determinism.
5. **C** (3) — the clearest fig leaf: relocates the moonshot into "the compiler" and calls finite-bytes a finite build.

## Most likely to ship verifiable aliveness this year

**Candidate E**, and it isn't close on the buildability axis. It is the only
candidate that (a) has a first increment built on code I verified exists and runs,
(b) ends each increment in a *playable slice a human can green*, (c) carries zero
LLM dependency on its ship path, and (d) is the structural antidote to the documented
session-killer — additive, per-increment-verifiable, never half-rebuilt-and-broken.
The honest caveat for the user: E's *ceiling* (authoring-bound, may feel less "alive"
than a generative dream) is real — but E lets you discover that ceiling in an
afternoon for the cost of one authored arc, whereas A/B/C/D all ask you to spend
weeks-to-months building the apparatus *before* you can judge whether it's alive.
If the goal is to ship something the user can actually play and verify this year,
E is the only candidate that clears the bar; A is the credible fallback if the user
wants the beat-graph's stronger continuity model and is willing to fund the larger
first slice.
