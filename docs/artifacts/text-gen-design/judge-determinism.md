# Judge: Determinism & Coherence Breaker

Adversarial review of the five text-gen candidates against the hard constraint:
**bit-for-bit reproducible from seed + action log, cross-platform (flat / PCVR /
Quest), no runtime LLM.** Lens: hostile engineer trying to produce a
non-reproducible run, a cross-platform desync, a contradiction, or an incoherent
output. Attack, not praise.

## Repo fact that grounds every attack

The live precedent — `scripts/text/npc_realizer.gd` — takes a `RandomNumberGenerator`
parameter (`_rng`) and **never uses it**: variant selection today is fully fixed,
no `hash()`, no `randi()`, no modulo. So **every candidate's `hash(seed, state, id) % len`
variant-pick is brand-new machinery with no stable-hash precedent in this codebase.**
There is no `hash_djb2`/`rand_from_seed` helper anywhere under `scripts/`, `tools/`,
`tests/`. This matters because the candidates all *assert* "seeded, replayable" and
*none* of them pin which hash. That is the shared determinism hole below, and it is
not hypothetical — it is the first thing each design has to fix before it ships.

---

## The shared hash hole (hits A, B, C, D, E — all of them)

Every candidate breaks ties / picks variants / computes freshness with an unspecified
`hash(...)`. In Godot the obvious candidates are all **non-portable as written**:

- **`String.hash()`** — GDScript's built-in is a 32-bit DJB2-ish hash. It is stable
  across platforms *for the same engine build*, but it is **not contractually frozen
  across Godot versions**, and it operates on the engine's internal string repr. An
  engine upgrade can silently change goldens. Worse, several candidates feed it a
  *Dictionary* (`state_hash`, `scene-hash`) — and **`Dictionary`/`Variant.hash()` and
  iteration order are insertion-ordered, not canonical**: build the same logical state
  via two different code paths (load-from-save vs. live-accumulate) and you get a
  different insertion order → different hash → different variant. That is a replay
  desync produced entirely inside "deterministic" code.
- **Floats in the hashed key.** A, D, E hash a `state_hash` that includes scalars
  (`mood 0.62`, `arousal 0.0`, `rel.trust`). If any scalar is the product of
  cross-platform float math (decay curves, `lerp`, `pow`), the *bits* differ Quest vs.
  PC before the hash even runs, so the hash differs, so the variant differs. The hash
  doesn't cause the desync but it **amplifies a 1-ULP float difference into a
  whole-different-passage difference** — the worst possible failure shape (jarring, not
  subtle).

**Verdict on the shared hole:** survivable, but only if the design *names* a frozen
construction — a fixed integer mix (e.g. splitmix64/xorshift over `(seed, turn_index,
interned_beat_id, interned_variant_id)` where every input is an **integer id**, never a
float and never a Dictionary). No candidate does this; B comes closest by interning ids
but still routes `scene-hash` and `state` through the freshness function. Each
candidate's score below is docked for leaving this unpinned, and docked *more* the more
its key derivation touches floats or dict-order.

---

## Candidate A — Subtract (beat-graph walk)

**Determinism holes.**
- Tie-break is `hash(seed, action-log, beat.id)` (§2c step 2). `action-log` is a
  *list of actions* — if hashed as a serialized string this is fine, but the spec
  doesn't say, and "action-log" almost certainly contains scalars/floats from the
  resolved actions. Shared hash hole applies, float-amplified.
- **The candidate *set* is built by "the global pool of beats whose `when` guard now
  passes" (step 1).** Iterating "the global pool" — if that pool is a Dictionary or a
  Godot `Set`-like — leaks **iteration order into the ranking** when two beats have
  equal `(pull, recency, specificity)` *before* the hash tie-break. The spec claims a
  "total order" but `specificity` is undefined as a number; if two peer beats in a
  region have identical pull and specificity (the §5.2 "several peer beats, same
  `when`" case is *explicitly designed in*), the only separator is the hash — and if
  the hash isn't reached because an earlier comparator returns equal via NaN-ish float
  specificity, sort stability over an unordered pool decides output. **Concrete break
  below exploits exactly the peer-beat case the design brags about.**

**Coherence / contradiction.** A's coherence is "the author wired the exit." But §2c
step 1 *also* fires **ambient/volunteered beats from the global pool** that did NOT come
through the cursor's exits. Construct: cursor sits on `maren.kitchen.open_further`
(she's mid-confession, `flags.maren_about_to_confide = true`). Simultaneously an ambient
beat `maren.ambient.checks_the_clock` (`when: scene.time == late`, pull 0.9) becomes
eligible and *outranks* the confession continuation. It fires verbatim:
> "Is that the time? I should start closing up."
…stepping on the half-said confession with no authored transition, because ambient
beats bypass the exit graph entirely. The `opens`/transition machinery that D has, A
lacks — A's only coherence is the exit edge, and ambient beats don't traverse it.
**A's coherence mechanism protects only the cursor-followed path, not the ambient
path it explicitly keeps.**

**State→key.** A's guards are *thresholds* (`trust >= 0.55`, variant `intimacy >= 0.7`).
The §3 worked example *itself* shows the boundary bug: intimacy 0.66 fires the default
variant; +0.04 → 0.70 flips to the intimate variant. Two states 0.699 vs 0.700 — a
single decayed ULP apart cross-platform — emit **different authored passages**. The
threshold *is* the rejected scalar-lens banding sneaking back in at the variant seam.

**Replay/save-load.** Memory episodes live in "the ledger" + "anti-repeat ledger
(cooldowns, recently-fired beat ids)". Cooldowns are *count-since-last-fire* — that's
side state that MUST be in the seeded log. The spec says state is "already deterministic
functions of seed + action-log" but the **anti-repeat ledger is not derived from the
action log, it's accumulated at runtime** — if a save/load rebuilds the ledger from a
snapshot rather than replaying, cooldown phase desyncs and a different peer beat rotates
in. Not proven to live in the log.

**Hardest break:** State: two peer beats `maren.kitchen.warm_a` and `..._b`, same `when`,
same `pull=0.8`, same specificity, both off cooldown. Action log replays identically on
PC. On Quest, `rel.maren.intimacy` decayed to `0.7000001` vs PC's `0.6999999` (one `pow`
ULP). The variant guard `intimacy >= 0.7` flips → different variant → different prose
bytes → **golden-trace fails cross-platform**, and even on one platform the peer tie
falls to the unpinned hash over an order-dependent pool.

**Survives?** No — the threshold-flip + ambient-stomp are both real and both in its own
worked example's mechanics.

**Score: 4/10.**

---

## Candidate B — Invert (frozen-embedding nearest-neighbor retrieval)

**Determinism holes.** B is the *only* candidate that took determinism seriously at the
metric: integer cosine via cross-multiplication `dot_a·norm_b² ⋛ dot_b·norm_a²` — **no
float div/sqrt, i64 accumulator over i16 lanes.** That genuinely holds cross-platform:
integer multiply/add/compare are bit-exact on all targets. Real credit.

But the holes are around the metric, not in it:
- **The scene-vector `q` is "fixed-point composition of last-K-beat embeddings + salient-
  state embedding + affordance embedding; weights are frozen integers" (§2.2.3).** Frozen
  integer weights × i16 lanes is fine — *if the composition is pure integer*. But
  "salient-state embedding" must come from *current scalar state*. How does a float
  `mood=0.62` become an i16 lane deterministically? That quantization step (`float →
  i16`) is **rounding of a cross-platform float**, and `int(round(x*32767))` on a value
  that differs by 1 ULP across platforms can round to two different integers at the
  half-way point. B's integer cosine is airtight; **B's float→i16 *input* quantization is
  the hole**, and the spec hand-waves it ("deterministic function of salient-state").
- **`emb_norms` precomputed at build** — good, those are constants.
- **`freshness_rank` = "function of seed + scene-hash + recently-played-beat-ids"** —
  shared hash hole. `scene-hash` over live state re-imports the float-rounding problem
  into the tie-break. But note: freshness is only the *third* tie-break key, reached only
  on exact integer-cosine ties — much rarer than A/C/D where the hash is primary.
- **`beat_id ASC` final backstop** — this is the one genuinely total, float-free,
  order-independent terminal comparator in *any* candidate. Correct and load-bearing.

**Coherence / contradiction.** B's coherence is "prefer `chain_next(last_beat)`, fall
back to `C` (re-enter a new chain)." The fallback is the contradiction surface.
Construct: chain X established "she set the glass down rim-up" (Action 2 in §3). Player
takes an off-chain affordance; `C_cont` empties; we re-enter chain Y via a bridge beat.
Chain Y was authored from a *different* scene where **she is still holding the rag**. The
bridge beat ("She lets the subject drop. '...Anyway.'") does NOT reset the glass/rag
physical state, and Y's first beat says "she wipes the bar down with the rag in her hand."
**Contradiction: she set the glass down rim-up and put the rag away one beat ago, now
she's holding the rag again.** B has no `asserts`/provenance-vs-current-physical-state
check like C/D — its precondition filter gates on `rel/affect/topic`, not on *physical
continuity props the previous beat established*. The chain graph prevents contradiction
**only within an authored chain**; cross-chain re-entry is exactly where physical-fact
contradiction leaks, and bridge beats are too generic to repair it.

**State→key.** B mostly *avoids* the banding problem (it ranks by continuous-ish
embedding distance, not a hard band) — but it reintroduces it at the **cold-query integer
threshold** (§5: "best `cosine_fp` falls below a frozen integer threshold"). A query whose
best score sits at threshold±1 flips between "retrieve the near beat" and "drop to
archetype-generic floor" — a jarring jump from a bespoke line to a generic deflection, on
a 1-unit integer-cosine difference that a float-quantization ULP can produce. Same band-
edge defect, moved to the coverage floor.

**Replay/save-load.** "Played-log" (`append beat.id`) and event tags (`left_abruptly`,
callback-debt) — these are explicitly persisted and explicitly drive preconditions across
sessions. This is the **best-specified replay story** of the five: selection state is the
played-log (an append-only id list, trivially in the action log) plus committed effect
tags (in world state). No underived side-ledger. Credit.

**Hardest break:** Cross-chain re-entry physical contradiction (the glass/rag above) — it
needs no float, no platform difference, just a player who steps off the authored chain
into a covered-but-different cell, which §5 says is the *common* "lukewarm" case. The
prose contradicts itself in two adjacent beats and B's coherence mechanism structurally
cannot see it.

**Survives?** Partially. Determinism survives *if* the float→i16 quantization is pinned
(fixable, named here). Coherence does **not** survive cross-chain re-entry — that's an
architectural gap, not a tuning fix.

**Score: 6/10** (highest determinism floor; real cross-chain coherence hole).

---

## Candidate C — Compile (bible → situation-keyed passage store)

**Determinism holes.**
- Variant pick: `variants[hash(seed, state_hash, sig) % len]` (§2.4 step 3). `state_hash`
  is a hash of live sim state including scalars → **full shared hash hole, float-amplified,
  dict-order-amplified.** This is the primary selector, reached every single turn (unlike
  B where the hash is a rare tertiary tie-break). So C's output is hash-fragile on *every*
  emission.
- `signature_index` is a **perfect hash** over `SituationSignature`. Perfect hashing is
  deterministic *by construction once built* — fine. But the signature itself is
  `hash(station, player_act, memory_bucket, scene_bucket, affect_shade)`. If those are
  interned integer bucket-ids, good; if `affect_shade` is derived by bucketing a float
  (`arousal 0.72 → rising-bashful`), then the **bucketing boundary is the float-band edge
  (below).**

**Coherence / contradiction.** C's stitch table does pronoun/tense agreement and memory-
callback insertion — better than A/B for *grammatical* continuity. But construct a
**callback-misfire**: §3 Action 1 inserts callback C₁₂ ("Whatever you said last time is
still doing its quiet work") gated on `mem=compliments-landed`. Now suppose the player's
*last actual act* before returning was `push_away` (a wound), but the memory bucket
`compliments-landed` is *also* still true (3 compliments happened earlier, never
withdrawn). Two memory facts hold simultaneously; the signature only carries **one
`memory_bucket` axis**. The bucketing collapses `{compliments-landed, recently-wounded}`
to whichever bucket the author-declared priority picks — say `compliments-landed` — and
fires the *warm* callback C₁₂ on a return that should be cold. **The NPC warmly references
a compliment one beat after being pushed away, because the single `memory_bucket` axis
can't represent "warm history AND fresh wound."** This is the §3 "collide to same key"
defect: two meaningfully-different memory states map to one bucket and emit the wrong
warmth.

**State→key.** §2.3 explicitly says `arousal: 0.72` is bucketed to `rising-bashful` "so
two close numeric states map to the same signature." That is **deliberate banding** —
and C even argues (§6) it is *not* the rejected scalar-lens because numbers only derive a
*key*, not phrasing. But the band edge is still a band edge: `arousal 0.69` → `bashful`
bucket, `0.71` → `rising-bashful` bucket → **different passage row → different prose**,
on a 0.02 difference that a decay-ULP can straddle. C's own defense ("it's a filing
system, not a generator") doesn't rescue determinism: a *filing system keyed on a
float-derived band* desyncs cross-platform exactly where the band edge lands on a
platform-divergent float. The quantization is the scalar lens, re-admitted as a key.

**Replay/save-load.** "History" feeds `state_hash` and memory buckets. Memory-events are
world-state effects (`compliments-landed-x3`) — derivable from the action log if effects
are logged. **But the fallback-lattice descent depends on a "miss," and a miss depends on
whether `signature_index[sig]` has a row — which is a property of the *shipped artifact***,
so that part is replay-stable. The replay risk is purely the `state_hash` variant-pick.

**Hardest break:** The two-memory-fact collision (warm callback after a wound) — no float
needed, fires from ordinary play where a player both complimented (earlier) and pushed
away (recently). The single `memory_bucket` axis cannot hold both, so the wrong-affect
authored callback is emitted as a *faithful* (provenance-passing!) contradiction —
provenance checks `{memory.compliment.repeated}` which IS entailed, so the provenance
guard waves it through. Provenance verifies the claim is *true*, not that it's
*appropriate*. **C's faithfulness guard cannot catch tonal contradiction.**

**Survives?** No on determinism (hash-on-every-turn over float state_hash, primary
selector). No on coherence (single-axis memory bucket collides warm+wounded).

**Score: 3/10.**

---

## Candidate D — Coarse (beat type-system: `opens`/`needs`)

**Determinism holes.**
- Tie-break `seed + state_hash` (§2 runtime, "argmin ties broken by seed + state_hash") —
  shared hash hole; `state_hash` over scalar state → float/dict amplification. Primary-ish
  (reached on salience ties, and the design *wants* multiple equal-salience variants).
- `b.fires_when ⊨ (intent, salient, world)` includes `rel.trust { >=: 0.6 }` — a **float
  threshold gate**, so the band edge is in the *condition* (eligibility flips
  cross-platform at 0.6), compounding the variant-pick hash. D admits this ("coarse gate")
  but a coarse gate is still a hard threshold: 0.5999 vs 0.6001 changes the eligible set.
- The candidate set `cand = { b in beats : ... }` — iteration over `beats`. If `beats` is
  an Array, order is stable; if a Dict keyed by id, GDScript preserves insertion order so
  it's stable *as built* but desyncs if rebuilt in a different order on load. Same
  dict-order caveat as A.

**Coherence / contradiction.** D has the **strongest authored coherence mechanism** of the
five: the `opens`/`needs` type check + the build closure invariant (*type-legal ⟹
judge-legal*, certified offline over rendered adjacencies) + `asserts`-provenance
contradiction guard ("she can't take her hand back unless `contact(hand_on)` is asserted").
This is genuinely the only candidate that proves cross-beat coherence at build time rather
than hoping. **The attack has to go at the invariant's *gaps*:**
- The closure is certified over **ordered pairs** `(A,B)` — "for 2,000 beats that's ~4M
  ordered pairs." But coherence is not pairwise. Construct a **3-beat contradiction that
  is pairwise-legal**: Beat A establishes `unresolved: [half_said_disclosure]`. Beat B is a
  `role: aside` that is type-legal after A (doesn't consume the obligation, `needs` met) and
  type-legal before C. Beat C `pays_off: half_said_disclosure`. Pair (A,B) judge-legal,
  pair (B,C) judge-legal — but the *rendered triple* A→B→C reads as: she half-says
  something, makes an unrelated aside about the weather, then pays off the disclosure as if
  the aside never happened — the payoff's "as I was saying—" beat reads as a non-sequitur
  because B changed the subject. **Pairwise closure cannot certify triples; the
  obligation-payoff arc spans a gap the pairwise judge never rendered.** D's own §7 admits
  the closure is `O(beats²)` — it is *only* pairwise, by its own cost analysis. The
  coherence guarantee has a 3-beat hole.
- `affect_continuous_with` bands: §3 Action 4 *needs* a transition beat for intimate→cold.
  Good. But "continuity band" is author-declared; an affect pair the author didn't think to
  exclude (e.g. `playful → grief`) can be type-legal-and-unjudged if no rendered pair
  happened to be sampled — the closure judges "a sample of actual rendered adjacencies"
  (§2.3 step 3), **not all of them**. A sampled certification is not a proof; the
  unsampled jarring pair ships.

**State→key.** The `>= 0.6` trust gate is the band edge (above). D's defense is that the
gate is "coarse, not the prose driver" — but coarse-or-not, a hard threshold over a
cross-platform float is a determinism edge. The prose *driver* is the discourse type, but
*eligibility* still flips on the float.

**Replay/save-load.** Discourse history (ordered fired-beat list + their `opens`) and
`history.recent(window)` anti-repeat — this is the selection-critical state. It's an
ordered id-list (replay-friendly, like B's played-log) **if** persisted in the log; the
`ctx = accumulate(history.opens)` is a pure fold over that list, so it's derived, good.
Better than A's separate cooldown ledger. The risk is whether `salience(b) consumed`
marking persists — it's per-turn so it's fine.

**Hardest break:** The pairwise-closure triple hole: `A (opens half_said) → B (aside,
pairwise-legal both sides) → C (pays off half_said)`. Renders as a disclosure interrupted
by an irrelevant aside and then resumed with no acknowledgment of the interruption — a
coherence break the build closure *by its own O(beats²) pairwise construction* never
checks. No float, no platform difference; pure ordinary play.

**Survives?** Determinism: survivable with the hash pinned and the trust-gate accepted as
a coarse risk (mid-tier). Coherence: the pairwise-closure guarantee is *real but bounded*;
the triple hole is genuine but narrower than A's ambient-stomp or C's memory-collision —
and D at least *has* a transition-beat escape valve and an `asserts` contradiction guard
no other candidate has. Strongest coherence machinery, with a provable gap at length ≥ 3.

**Score: 6/10** (best coherence machinery; pairwise-only closure + float gate dock it).

---

## Candidate E — Scope (thin engine over hand-authored fragments; the realist)

**Determinism holes.**
- Variant pick: `hash(seed, fragment.id, state_hash)` (§3.2 step 5) — shared hash hole,
  `state_hash` float-amplified, every turn. Same as C/D in fragility, primary selector.
- Salience-rank "boosted by novelty: a just-changed axis outranks a static one" (step 2) —
  novelty is a *delta* computation over floats; "just-changed" is a float comparison
  (`delta != 0`?). If decay produces `delta = 1e-9` on one platform and `0.0` on another
  (float math divergence), the novelty boost flips, reordering salience → different
  fragment. **The novelty sort is a hidden float-equality test**, the most fragile
  comparison there is.
- `when` guards use `cmp: ge/lt value` over scalars (`dmood ≥ 0.04`, `rapport < 0.45`) —
  **float threshold gates everywhere**, band edges throughout the eligibility test.

**Coherence / contradiction.** E is the *weakest* coherence story by its own admission: it
has **no cross-fragment coherence mechanism at all** — no `opens`/`needs` (D), no chain
graph (B), no stitch table (C), no exit edges (A). It "joins in channel order with authored
connective rules" (§3.2 step 7) and budgets one-per-channel. Construct the trivial break:
`present_tell` channel fires "She keeps a careful handspan of distance" (cold, from the
`wound` state) and in the *same turn* the `reaction` channel fires a warm fragment authored
for a different sub-condition that also passes its guard (`verb=greet` warm variant, guard
didn't exclude the wound because the author keyed it on rapport, not the wound tag). Output:
> She keeps a careful handspan of distance she didn't keep before. She lights up to see you.
**Two channels, two contradicting affects, same turn, no mechanism to detect it** — because
channels are budgeted *independently* and joined, with nothing checking affect-consistency
across them. E's §5 lists "voice consistency lint" but that's build-time advisory over single
fragments, not cross-fragment affect coherence at runtime. The only thing preventing this is
the author remembering to put the wound condition in *every* channel's guards — i.e. the
cases the author imagined, which is exactly the failure the prompt names.

**State→key.** E *is* the band approach, undisguised: `mood × rapport × arc × last_act` is a
"finite authored grid" (§3.3) and guards are float thresholds. E doesn't even claim to escape
the band-edge — it's the honest scalar-band candidate. Boundary jumps (0.449 → 0.451 rapport
flips the `rapport < 0.45` reaction guard) are inherent and unhidden.

**Replay/save-load.** This is E's **strength**: memory/cooldown state lives in the NPC state
record which is declared "deterministic fn of seed + action log," and the live `maren_history.gd`
*already* accrues memory off a seeded clock with no RNG (verified: `_init(seed_value)` with the
comment that history is "deterministic without RNG"). Cooldowns are "tracked in the deterministic
state." E reuses existing, already-deterministic machinery — the least *new* determinism surface.
The hash variant-pick is the only genuinely new risk and it's the shared one.

**Hardest break:** Cross-channel affect contradiction (cold present_tell + warm reaction same
turn) — needs no float, no platform difference; just two fragments in different channels whose
guards both pass because the author didn't replicate the wound condition across channels. E has
*zero* runtime defense; it relies entirely on authoring discipline, which the prompt explicitly
says protects "only the cases the author imagined."

**Survives?** Determinism: survivable, *and* it's the candidate whose replay state most clearly
already lives in the seeded log (real credit) — but the novelty-boost float-equality test is a
nasty hidden hole and the band-edge gates are everywhere and unhidden. Coherence: does **not**
survive — no cross-fragment mechanism at all; cross-channel contradiction is one guard-omission
away and undetectable at runtime.

**Score: 4/10** (best replay-state grounding; worst runtime coherence — none).

---

## Ranking (determinism + coherence robustness, most → least robust)

1. **B — Invert (6/10).** Only candidate with a genuinely cross-platform-safe *metric*
   (integer cosine via cross-multiplication, no div/sqrt) and the cleanest replay story
   (append-only played-log + effect tags). Determinism survivable once float→i16 input
   quantization is pinned. Loses points for the **cross-chain re-entry physical
   contradiction** (glass/rag) its filter can't see, and the cold-query integer-threshold
   band edge.
2. **D — Coarse (6/10).** Best *coherence machinery* by far — `opens`/`needs` type check,
   build closure invariant, `asserts` contradiction guard, transition-beat escape valve —
   and replay state is a derivable id-list fold. Docked for the **pairwise-only (`O(beats²)`)
   closure that can't certify 3-beat arcs** (the aside-interrupts-payoff hole) and the
   `>= 0.6` float gate. (B and D tie; B edges ahead on the *metric* being provably
   float-free, D on having the only real contradiction guard. Call it B ≥ D.)
3. **A — Subtract (4/10).** Trivial-determinism claim is overstated: threshold-flip variant
   guards (its own worked example shows 0.66→0.70 flipping passages) and **ambient beats
   that bypass the exit graph and stomp mid-confession** with no transition mechanism.
   Separate underived anti-repeat/cooldown ledger is a replay risk.
4. **E — Scope (4/10).** Most-grounded replay state (reuses already-deterministic
   `maren_history`), but **no runtime cross-fragment coherence whatsoever** — cross-channel
   affect contradiction is one guard-omission away — plus a hidden float-equality novelty
   test and band-edge gates throughout. Honest about being the band approach; that honesty
   doesn't fix the band edge.
5. **C — Compile (3/10).** Hash-over-float `state_hash` is the **primary per-turn selector**
   (most fragile placement of the shared hole), the deliberate float→band bucketing *is* the
   rejected scalar-lens re-admitted as a key, and the **single `memory_bucket` axis collides
   warm-history + fresh-wound** into one bucket and fires the wrong-affect callback — which
   its provenance guard waves through because provenance checks *truth, not appropriateness*.

### One-line summary table

| Cand | Score | Survives? | Hardest concrete break |
|------|-------|-----------|------------------------|
| A | 4 | No | Ambient beat (`checks_the_clock`, pull 0.9) outranks the cursor's confession continuation and fires verbatim, stomping the half-said confession — ambient beats bypass the exit graph, no transition. Plus variant guard `intimacy>=0.7` flips passage on a decay-ULP. |
| B | 6 | Determinism yes (pin float→i16); coherence no | Cross-chain re-entry: chain X set the glass down / put rag away; bridge beat to chain Y (authored with rag in hand) reintroduces the rag — adjacent beats physically contradict; filter gates rel/affect/topic, not physical props. |
| C | 3 | No | Player both complimented (earlier) and pushed-away (recent); single `memory_bucket` axis collapses to `compliments-landed`, fires warm callback C₁₂ one beat after the wound. Provenance passes (claim is true), tone is wrong. |
| D | 6 | Determinism yes (pin hash, accept gate); coherence mostly | `A (opens half_said) → B (aside, pairwise-legal both sides) → C (pays off half_said)`: disclosure interrupted by irrelevant aside then resumed unacknowledged. Pairwise `O(beats²)` closure never renders the triple. |
| E | 4 | Determinism yes (best replay grounding); coherence no | Same turn: cold `present_tell` ("careful handspan of distance", wound state) + warm `reaction` ("she lights up") — two channels, contradicting affects, joined with no cross-channel coherence check. |

### Cross-cutting mandate for whatever wins

No candidate ships without **pinning the hash**: replace every `hash(seed, state_hash/scene-hash, id)`
with a fixed integer mix (splitmix64/xorshift) over **interned integer ids and an integer
turn-index only — never a float, never a Dictionary**, and frozen against Godot-version drift via a
golden-trace test. And every **float-threshold guard / band bucket** must either be removed in favor
of integer-id state, or its band edges must be quantized to integers *before* any cross-platform
float math touches them — otherwise A/C/D/E all desync at the band edge on Quest-vs-PC float
divergence regardless of how good the hash is. B's integer-cosine metric is the model to copy; B's
float→i16 input quantization is the one place B still has to apply this rule.
