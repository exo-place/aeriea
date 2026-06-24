# Candidate E — Scope-to-What-Ships (the skeptic-realist's candidate)

*One of five independent design-it-twice candidates for aeriea text generation. This
one is the designated skeptic-realist: it attacks the premise of the rejected
`prose-generation.md` design and proposes the honest, buildable alternative.*

---

## 1. Thesis

**Aeriea's text feels alive the way TiTS/CoC/LT do — by deep human authoring keyed
to true systemic state, surfaced by a thin deterministic engine — and build-time
LLM is an *authoring power tool* that helps one human write more keyed fragments,
faster and more consistently, never a generator that fabricates prose at ship or
run time.**

The unit we ship and verify is not "Opus-quality prose across the combinatorial
state space" (an unverifiable moonshot). It is **one NPC, authored to actual
reference-game depth, that a human can play and judge in an afternoon** — and a
growth *process* that adds the next NPC, the next situation, the next reaction the
same way, each increment independently verifiable.

---

## 2. The boundary — what ships vs what is research

The single most important thing this candidate does is **draw the line and refuse
to blur it.** The rejected `prose-generation.md` collapses three different problems
into one moonshot ("faithful × Opus-craft × deterministic × fresh across the
combinatorial space") and then marks every load-bearing piece OPEN. That is the
documented failure mode from the creator saga: a grand coverage thesis nobody can
verify, that passes 25k asserts and ships broken. We split it.

### IN SCOPE — we ship this, and a human verifies it by playing

- **A deterministic *surfacing* engine.** Given (true state, a small set of
  authored fragments with conditions, seed), it selects, orders, and renders
  fragments into prose. Pure function. No LLM at runtime, ever. This is a modest,
  finite, fully-testable program — an evolution of the `npc_realizer.gd` that
  already exists and already works.
- **An *authoring system*: the data shapes** authors write — fragments, their
  firing conditions over state, salience priority, anti-repeat cooldowns,
  variant pools, and **continuity hooks** (memory references, callbacks). This is
  the bulk of the product. It is where aliveness lives.
- **Deep authoring of one bounded vertical slice** to reference-game quality: one
  NPC (Maren), a bounded set of situations and player verbs (~8–12 verbs, a
  handful of relationship arcs, a dozen remembered events), authored densely
  enough that playing it for an hour reads as *alive* — she remembers, reacts,
  has moods that color everything, and references shared history unprompted. This
  is exactly what TiTS does for one companion, by hand, and it is *known to work.*
- **Build-time LLM as an authoring amplifier** (§3.3): drafts candidate fragments
  for state-conditions a human specifies, flags coverage gaps, checks consistency
  of voice across hundreds of fragments — with a **human author accepting every
  line into a committed, finite, diffable corpus.** The shipped artifact contains
  zero model calls; it contains text a human approved.

### OUT OF SCOPE — this is research, fenced off, not on the ship path

- **Generative coverage of the combinatorial state space.** Holding Opus-craft as
  state "drifts from baked" — `prose-generation.md`'s own named moonshot. We do
  not attempt it. Where state has no authored fragment, we **degrade by design**
  (§3.2) — never to mad-libs, but to *honest brevity*: surface less, not fake more.
- **A build-time-trained deterministic realizer surrogate** (`prose-generation.md`
  §3). A learned text model lowered to a deterministic eval is a genuine research
  bet with an unbuilt corpus, unbuilt training, unbuilt eval. It may pay off later;
  it is not how the first ship happens, and nothing in the ship path depends on it.
- **The prevalence-weighted RDF semantic graph** as a *prose substrate*. (Already
  rejected as a foundation; we also don't need it to ship the slice. Maren's world
  knowledge is authored.)
- **The brain→intent→realizer spine** as the mandatory architecture. (Rejected.)
  We keep a *thin* intent notion (§3.1) but the brain is "enough state to author
  good reactions against," not a full cognitive simulation gating the first ship.

**The honest aliveness we deliver:** continuity (she remembers what you did and
references it), reactivity (the same act reads differently by mood × relationship ×
history), presence (her state colors description even when nothing happens), and a
voice consistent across a large hand-authored surface. That is *exactly the
aliveness the reference games achieve*, and they achieve it with **zero
generation.** We can verify it the same way they're verified: a human plays it.

**What we explicitly do NOT promise:** that an arbitrary never-anticipated state
produces Opus-grade prose. That promise is the moonshot, and chasing it is the
trap.

---

## 3. Architecture

Three parts: the authoring data model, the deterministic surfacing engine, and the
build-time amplifier. Parts 1–2 are the shippable artifact; part 3 is a dev tool
that runs offline and outputs into part 1.

### 3.1 The authoring system — data shapes

The product is a **content corpus**, authored as data (per the ecosystem
"data over code at a seam" principle), consumed by the engine. The shapes:

**State** (the substrate the engine reads, the brain authors react against). Not a
full cognitive sim — a deliberately modest, *authorable* record per NPC. For Maren,
concretely what already exists plus continuity fields:

```jsonc
// npc state record (deterministic fn of seed + action log)
{
  "mood":      0.62,        // affect scalar(s) — drives register
  "rapport":   0.55,        // relationship closeness — drives proxemics/diction
  "arousal":   0.0,         // NSFW-capable axis, same treatment
  "last_act":  "complimented",
  "memory": [               // episodic — the seat of continuity
    { "event": "complimented", "n": 3, "last_t": 1402, "salient": true },
    { "event": "pushed_away",  "n": 1, "last_t": 980,  "salient": true,
      "tag": "wound" }      // tagged events carry weight authors key on
  ],
  "flags": { "knows_player_name": true, "shared_a_drink": false }
}
```

**Fragment** — the authored unit. A fragment is a piece of prose *plus the
conditions under which it is true and salient*:

```jsonc
{
  "id": "maren.compliment.react.warm_guarded",
  "channel": "reaction",            // reaction | present_tell | callback | ambient
  "when": {                          // a guard over state — same expr language
    "all": [                         // as the affordance kit's when-guards
      { "verb": "compliment" },
      { "delta": "mood", "cmp": "ge", "value": 0.04 },
      { "state": "rapport", "cmp": "lt", "value": 0.45 }
    ]
  },
  "salience": 6,                     // priority when several fragments fire
  "cooldown": 3,                     // don't re-fire within N interactions (anti-repeat)
  "refs": ["memory.complimented"],   // continuity: may interpolate a remembered fact
  "variants": [                      // seeded pick among equivalent realizations
    "She blinks, caught off guard, and a flush climbs her neck before she can look away.",
    "It lands before she's braced for it — her eyes drop, color rising."
  ]
}
```

Key properties, each chosen *against* the rejected design:

- **`when` reuses the affordance kit's guard expression language** (the `op/all/
  state_cmp/...` grammar already in `sandbox.kit.json` and the interpreter). One
  guard evaluator, already built and tested — not a new formalism.
- **Variants are authored, not generated at runtime.** Freshness = seeded pick
  among *human-written* equivalents. This is `npc_realizer.gd`'s existing pattern,
  made data. It is honestly bounded: N variants, not infinite — exactly TiTS.
- **`refs` are the continuity mechanism.** A fragment can pull a *fact* from memory
  (the count of compliments, the tag of a wound) and the engine interpolates it
  faithfully. This is *not* mad-libs: the prose around the ref is fully authored
  for that state band; the ref injects one true fact, the way a human author writes
  "the third time you've said that" by reading the count.
- **Channels** separate concerns the way the working sandbox already does:
  `present_tell` (resting body-language read off mood × rapport), `reaction` (the
  delta one act produced), `callback` (surfaced memory), `ambient` (world/scene).

**Arc** — optional authored structure over time: a small state machine of beats
(stranger → familiar → close; or a wound opened → tested → mended) that gates which
fragment pools are live. This is how authors give a relationship *shape* rather than
a scalar — and it's how LT/TiTS companions feel like they're "going somewhere."

### 3.2 The deterministic surfacing engine (no runtime LLM)

A pure function `render(state, before, after, verb, seed) -> String`. The pipeline,
all finite and testable:

1. **Gather** every fragment whose `when` guard passes the current/delta state.
2. **Salience-rank** them (authored `salience`, boosted by novelty: a just-changed
   axis outranks a static one — the anti-repetition discipline the rejected doc
   wanted, here implemented as a simple sort, not a moonshot).
3. **Budget**: take the top-k per channel (e.g. one present_tell, one reaction, at
   most one callback) so output is a paragraph, not a catalogue. Restraint by
   construction.
4. **Cooldown filter**: drop fragments fired within their `cooldown` window
   (tracked in the deterministic state). This is the anti-grind mechanism.
5. **Variant pick**: seeded selection (`hash(seed, fragment.id, state_hash)`) among
   the fragment's authored variants — bit-for-bit replayable.
6. **Interpolate `refs`** with true facts from state, faithfully.
7. **Compose**: join in channel order with authored connective rules.

**The honest degradation rule (this is the crux).** If *no* fragment fires for a
state — the uncovered tail — the engine does **not** fabricate. It surfaces the
**always-true low-resolution fallback**: a `present_tell` (which is authored across
the *full* mood×rapport grid, so it always exists — see the working
`_present_tell` in `npc_realizer.gd`) and nothing more. Less prose, not fake prose.
This is the faithful-coarsening idea from `semantic-layer.md`, but *implemented
honestly*: the coarse level is **authored to be total** over the few primary axes,
so coverage of the *base* read is guaranteed by construction, and richness is what
authoring *adds on top*. We never claim Opus-craft on the tail; we claim *good and
true and brief* on the tail, which is verifiable and which the reference games also
do.

This engine is **a few hundred lines of GDScript**, a direct descendant of the
existing realizer, fully golden-trace testable for determinism, and its quality is
exactly the quality of the human-authored fragments it surfaces.

### 3.3 Build-time LLM as authoring amplifier (not a generator, not a crutch)

The LLM never produces shipped prose autonomously and never runs at game time. It
is a **dev-time tool an author drives**, and every output passes through human
acceptance into the committed corpus. Concretely, four amplifier modes:

- **Draft-against-spec.** The author specifies a state-condition and intent in
  words ("compliment, low rapport, she warms but is caught off guard, guarded
  voice, ~1 sentence, her physical tell not a named feeling"). The LLM drafts 3–5
  candidate variants. The author **edits and accepts** the ones with taste, rejects
  the rest. Result: a human-curated `variants` array. This is the *only* honest use
  of the "Opus as build-time ingredient" idea from `prose-generation.md` — but with
  a **human author as the irreducible taste gate**, which the rejected doc tried to
  replace with an LLM-judge (the creator saga proved detection/judge ≠ taste).
- **Coverage-gap report.** Offline, enumerate reachable state bands (mood×rapport×
  arc×last_act — a *finite* authored grid, not the combinatorial space) and report
  which have no fragment. The author decides which gaps matter and authors them.
  This makes coverage *visible and finite* instead of a moonshot.
- **Voice-consistency lint.** Given the whole corpus, flag fragments that drift
  from Maren's established voice/register. Advisory; the author adjudicates.
- **Continuity-suggestion.** Propose `callback` fragments that reference memory
  events authors haven't surfaced yet ("you have a `wound` tag never referenced —
  here are 3 drafted callbacks"). Author accepts/edits.

**Why this is not the rejected generator and not a runtime crutch:**
- *Not the runtime generator:* zero model calls in the shipped game; the artifact is
  a finite JSON corpus + the engine. Determinism is structural, not promised.
- *Not the build-time generator-in-disguise:* the LLM does not autonomously produce
  the shipped corpus. A human accepts every line. This is the **direct lesson of
  the creator saga** — autonomous generation that passed every automated gate still
  shipped slop; *quality lives in generation-with-taste, and the taste here is a
  human author's*, with the LLM as a typing-speed multiplier, not a taste source.
- *Finite & buildable:* the output is a bounded artifact you can `wc -l`, diff,
  review, and ship — the "buildable finite shippable artifact, not a fig leaf" bar.

---

## 4. Worked example — Maren, a 4-action trajectory, real output

True state evolves via the deterministic engine; prose is surfaced from authored
fragments. (Prose below is the *authoring target quality* — written here by hand to
the same bar an author + amplifier would commit.)

**Opening read** (state: `mood 0.50, rapport 0.30, memory empty, arc: stranger`):
present_tell fires off the mood×rapport grid (authored total):

> She stands a step back, hands clasped in front of her, offering you a level,
> measured look.

**Action 1 — `compliment`.** Effects: `mood +0.06, rapport +0.05,
memory.complimented n=1`. Reaction fires (`when: verb=compliment, dmood≥0.04,
rapport<0.45`), seeded variant pick:

> You offer her a compliment. It lands before she's braced for it — her eyes drop,
> color rising. She doesn't say thank you, but she doesn't look away as fast as she
> might have.

**Action 2 — `compliment` again.** `mood +0.04, rapport +0.04,
memory.complimented n=2`. Now a `callback` fragment becomes live (`refs:
memory.complimented`, `when: complimented.n ge 2`), outranking the bare reaction by
salience because the *repetition* is the salient fact:

> You offer her another. This time the corner of her mouth gives before her guard
> does — "You're going to run out of nice things to say," she says, but she's
> closer than she was, and she doesn't mean it.

(The "another" and the teasing line are authored for the n≥2 low-rapport-warming
band; the engine *chose* this over the first-compliment fragment because n changed
and the callback's salience is higher. Continuity, surfaced — not narrated as "she
remembers.")

**Action 3 — `push_away`.** `mood -0.18, rapport -0.10,
memory.pushed_away n=1 tag=wound, arc unaffected but flag set`. Cooling dominates
(`when: dmood le -0.12, rapport_after ge 0.45`):

> You push her away. She rocks back half a step, and the warmth goes out of her
> face all at once — it costs more, now that there was some.

The `wound` tag is recorded. No fragment over-claims; the drop is shown physically.

**Action 4 — `wait` (leave, return hours later), then `greet`.** History decays
(mood drifts toward baseline, the wound stays tagged). On return, the present_tell
reads the decayed-but-remembered state, and a `wound`-keyed callback fires on the
greet because the tag is unreferenced and salient:

> She's here when you come back, and she clocks you the moment you step in. "Oh," she
> says. "It's you." She keeps a careful handspan of distance she didn't keep before —
> she hasn't forgotten the last thing you did, and she's waiting to see if you'll do
> it again.

Every clause traces to a true state fact (decayed mood, reduced rapport, the
`wound`-tagged memory). It reads *alive* — she remembers, the history has weight,
the relationship has a shape — and **every line was authored by a human** for that
state band, seeded-picked among variants, surfaced by a finite engine. This is
TiTS-grade companion writing, and it is *built the way TiTS built it.*

---

## 5. How it achieves "alive"

The reference games prove aliveness ≠ generation. Aliveness = **continuity +
reactivity + presence + consistent voice**, and each maps to a concrete mechanism
here:

- **Continuity** ← `memory` + `refs` + `callback` channel + cooldowns. She
  references what you did, by surfacing true memory facts inside authored prose.
- **Reactivity** ← `when` guards over `delta` and state bands: the same verb yields
  different fragments by mood × rapport × arc × history. (Already working in
  `_reaction_for`.)
- **Presence** ← the always-total `present_tell` grid: her state colors the scene
  even on a no-op turn, so she's never inert furniture.
- **Voice** ← all prose authored by one human (amplified), linted for consistency.
  Voice is the thing LLMs-in-the-loop most visibly break; authoring fixes it by
  construction.
- **A relationship that goes somewhere** ← `arc` state machines gating fragment
  pools.

This is real aliveness, verifiable by *playing*, within an honest scope.

---

## 6. Incremental growth path (no big-rebuild gamble)

The creator died from a big autonomous rebuild. This candidate is built to make
that impossible by construction: **growth is additive and per-increment
verifiable.**

The unit of growth is **one fragment** (or one arc, one verb, one memory hook).
Each is:
1. Authored (human + amplifier), 2. committed to the corpus, 3. covered by a
   golden-trace determinism test, 4. **playtested** (the author drives the slice to
   the state that fires it and reads the actual output).

Coverage grows along a *finite, visible* frontier (the mood×rapport×arc×last_act
grid + the memory-event set), with the amplifier's coverage-gap report showing
exactly what's unwritten. You can ship at *any* point — the degradation rule
guarantees uncovered bands still render good-and-brief. There is **no state where
the system is half-rebuilt and broken**: adding a fragment can't break existing
ones (they're independent guarded units; worst case two fragments both fire and the
salience sort picks one — testable).

Order of growth: **deepen Maren first** (one NPC to undeniable reference quality and
get the user's verdict) → then *widen* (NPC #2, reusing the engine and authoring
patterns) → then *new situation types*. Each is a small, judged increment, never a
coverage moonshot. The user gates green per increment, on the running slice.

---

## 7. What it gives up (the honest ceiling) + trade-offs

- **It gives up the generative dream.** Truly novel, never-anticipated states get
  *good-and-brief*, not *Opus-grade*. The combinatorial tail is authored-coverage-
  limited, exactly like TiTS/LT. This is the central concession — and it's the same
  concession the reference games make and still feel alive through. We pay it openly
  instead of promising past it.
- **It is authoring-labor-bound.** Aliveness scales with human authoring hours
  (amplified, not replaced). Depth costs writing. The amplifier raises throughput
  and consistency but does not remove the human-taste bottleneck — and per the
  creator saga, *that bottleneck is load-bearing, not a bug.* The user has flagged
  "user as gate is unsustainable" — note this design moves the human from *defect-
  gate* (reactive, unbounded) to *author* (proactive, productive): the human's
  effort produces content instead of catching slop.
- **Repetition is visible at the edges** of small variant pools — the honest TiTS
  failure mode (the "samey/grindy" complaint). Mitigated by cooldowns + variant
  count, never eliminated. We don't pretend infinite freshness.
- **Depth is still upstream-bounded** — richer reactions need richer authored state
  (more memory axes, more arc structure). True, and we embrace it: we grow state
  *as authoring demands it*, incrementally, rather than positing a full cognitive
  brain up front.

Trade vs. the rejected design: we trade an *unverifiable maybe-infinite* ceiling for
a *verifiable, shippable, human-judged* one. Given the creator saga, that trade is
the whole point.

---

## 8. Buildability — the first shippable increment, concretely

This candidate is the most clearly shippable because **most of it already exists and
runs.** `scripts/text/npc_realizer.gd` is already a deterministic, faithful,
show-don't-tell surfacing engine over Maren's state; `text_sandbox.gd` already
drives her headlessly through the affordance interpreter; `maren_history.gd` already
accrues memory off a seeded clock. The first increment is a *refactor + deepen*, not
a rebuild:

**Increment 1 (shippable on its own):**
1. **Externalize fragments to data.** Move the hardcoded prose in
   `npc_realizer.gd`'s `_present_tell/_reaction_for/_last_act_echo` into a
   `maren.fragments.json` with the `when`/`salience`/`cooldown`/`variants`/`refs`
   shape (§3.1), reusing the kit guard grammar. The engine becomes the generic
   gather→rank→budget→cooldown→variant→interpolate→compose loop (§3.2).
2. **Add the `memory.*` ref + callback channel** so continuity surfaces inside
   authored prose (already half-present via `maren_history`).
3. **Author the first deep band to reference quality** with the amplifier:
   the compliment arc (stranger→warming→the wound→return) — the §4 trajectory —
   with 2–3 variants per fragment and cooldowns.
4. **Fix the known sandbox defects** from the saga that block playtesting the prose:
   drop the raw `(face: ...)` debug line and the raw "arousal" affect leak to the
   player (author them as shown body-language instead).
5. **Golden-trace test** the full §4 trajectory for bit-for-bit determinism; add the
   suite to `tests/run.sh`.
6. **Playtest**: drive the slice, read the actual transcript, judge it against the
   §4 target. Hand to the user for the green verdict on the running slice.

Every piece is a known quantity (the guard evaluator, the interpreter driver, the
realizer pattern, the test harness all exist). No research dependency sits on the
ship path. The amplifier (§3.3) is a separate offline dev script that need not exist
for increment 1 to ship — it can be authored by hand first and amplified later,
which is the ultimate proof the LLM is not a crutch.

**Risk to this candidate, stated plainly:** the ceiling is real — if a deep authored
slice *still* doesn't feel alive enough to the user, the limit is authoring craft +
state richness, not the architecture, and the answer is *more/better authoring*, not
a generator. That's a known, bounded, fundable risk — the opposite of the moonshot's
unbounded one.
