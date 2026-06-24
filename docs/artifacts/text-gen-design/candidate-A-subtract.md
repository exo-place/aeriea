# Candidate A — Subtract the generator: the world is a graph of authored BEATS

Status: design-it-twice candidate (one of five). Independent design; does not hedge toward the others.

---

## 1. The core primitive and the thesis

**The primitive is the BEAT: a single authored unit of real prose — a passage a
human (with Opus as co-writer) actually wrote — carrying its own preconditions,
its consequences, and a set of typed exits to other beats.** Nothing smaller is
ever generated or recombined at runtime. A beat is the atom; prose lives only
inside beats; the runtime never assembles a sentence.

> **Thesis:** There is no runtime sentence-generator at all. Depth-bearing prose
> is *real writing* authored at build time. The runtime is a deterministic
> **walk over a graph of beats** — it chooses *which authored passage fires
> next* given the world state and the player's action, and it never composes,
> infills, or recombines below the beat. "Generation" collapses entirely into
> **authoring-at-scale + deterministic graph navigation.** Quality is not a
> property the engine produces; it is a property the engine *preserves* by never
> touching the prose.

The radical subtraction: every other approach keeps *some* runtime machine that
turns state into words (a grammar, a trained realizer, a band-table, a slot
filler). This candidate deletes that machine outright. The only thing the
runtime does with language is **pick a pointer**. If the prose at a node is
good, the output is good — by construction, because the output *is* that prose,
verbatim. The hard problem is moved entirely to build time, where Opus-craft is
*permitted* and a human can exercise taste, which the SESSION-RECORD says is the
one thing a runtime net cannot add.

This directly refuses the three rejected foundations:
- **(a) prose-as-lens-over-scalars** — there is no scalar→prose rendering step.
  Scalars exist only as *guards* that decide which already-written beat is
  eligible. A character is not numbers a renderer paints; the character *is* the
  corpus of beats written for her, and the numbers only route between them.
- **(b) intent-tuple middle seam** — there is no modality-independent intent
  object that a realizer expands. The beat is already the surface. The seam is
  beat→beat, not meaning→words.
- **(c) RDF-triple semantic substrate** — knowledge is not stored as weighted
  triples a generator speaks from. What the NPC "knows" is whatever is written
  into her beats and the *facts* recorded by the navigation (below). No
  knowledge graph is queried to produce a sentence.

---

## 2. The architecture

### 2a. The data shape — what a beat is

A beat is authored data, not code. Concretely (illustrative schema):

```jsonc
{
  "id": "maren.kitchen.confide_compliment_returned",
  "speaker": "maren",
  "tags": ["confide", "tender", "kitchen", "evening"],

  // --- ELIGIBILITY (guards over world state; pure, deterministic) ---
  "when": {
    "rel.maren.trust": ">= 0.55",
    "flags.player_complimented_her_recently": true,
    "scene.place": "kitchen",
    "beat.last_speaker": "player"
  },
  // How strongly this beat WANTS to fire when eligible (authoring-time salience).
  // Not runtime-tuned; a number the AUTHOR sets to rank competing eligible beats.
  "pull": 0.8,
  // Anti-repeat: cannot refire until this many other beats separate it.
  "cooldown": 6,

  // --- THE PROSE (real authored writing; the ONLY language in the system) ---
  // Authored as a small set of pre-written VARIANTS (not slots): each variant is a
  // complete, independently-written passage for the SAME beat under finer conditions.
  "say": [
    {
      "if": { "rel.maren.intimacy": ">= 0.7" },
      "text": "Her hand stays on your forearm a beat longer than it needs to. “That thing you said earlier—” she starts, and doesn’t finish, color climbing her face."
    },
    {
      "if": { },  // default variant
      "text": "She turns the dish towel over in her hands, once, and doesn’t look up. “You didn’t have to say that.” A pause. “But thanks.”"
    }
  ],

  // --- CONSEQUENCES (what firing this beat commits to the world) ---
  "effects": {
    "rel.maren.intimacy": "+= 0.04",
    "flags.maren_confided_once": true,
    "memory.push": "maren_confided_in_kitchen"   // a durable, citable episode
  },

  // --- EXITS (typed edges to follow-on beats; the discourse seam) ---
  "exits": [
    { "to": "maren.kitchen.deflect_if_pushed", "on": "player.tease" },
    { "to": "maren.kitchen.open_further",      "on": "player.reassure" },
    { "to": "maren.kitchen.retreat",           "on": "player.silence|player.leave" }
  ]
}
```

The **seam is `exits` + `when`** — and it is *discourse-level*, never lexical.
An edge means "after this authored passage, under this player move, that other
authored passage is the natural next thing said." It is the unit a human
screenwriter thinks in (beat → beat), not a unit a mad-libs filler thinks in
(noun-slot → noun). There is no point anywhere in the pipeline where a word is
chosen to fill a hole. The finest grain of authoring is the **variant** — and a
variant is still a *whole written passage*, selected by guard, never assembled.

### 2b. Build-time pipeline (what Opus + humans produce)

The shippable artifact is a **compiled beat-graph**: a finite, content-addressed
bundle of beats (the JSON above, with prose) plus a compiled guard/exit index for
fast deterministic lookup. It is data. It ships in the game. There is no model in
it.

Authoring is a **human-directed, Opus-assisted pipeline**, in four stages:

1. **Beat-skeleton design (human).** A human authors the *graph shape* for a
   character/scene: which beats exist, their tags, their `when` guards, their
   exits. This is dramaturgy — deciding the arcs an NPC can move through. It is
   small: a rich character is dozens-to-low-hundreds of *beat nodes*, not
   millions, because beats are reused across states (see §5).

2. **Prose authoring (human + Opus as co-writer).** For each beat (and each
   variant), Opus drafts candidate passages *for the specific committed
   condition* — given the exact guard context as a prompt — and a human curates,
   edits, and signs off. This is exactly the sanctioned build-time use: Opus is
   an ingredient; the human supplies taste. The output is *frozen prose*. Because
   it is written against an exact condition (not a generic situation), it can be
   as specific and deep as Opus-freeform-RP — *and then curated past a single
   pass*, which is the floor the prose-generation doc already argues for.

3. **Coverage compilation + lint (tooling, with Opus as critic at the leaves).**
   A build-time pass walks the graph and flags: dead beats (unreachable),
   starvation (a reachable state with no eligible beat → would force silence),
   exit dangling, guard contradictions, and **repetition risk** (two beats that
   fire under near-identical conditions and read too similarly — a freshness lint).
   Opus may *flag* candidates for human review; it never *writes the shipped
   line* unattended.

4. **Golden-trace freeze.** Every authored play-path is captured as a golden
   trace `(seed, action-log) → exact bytes`. The test suite replays them. This is
   the determinism gate and the regression net.

**Nothing in stages 1–4 ships a model or requires runtime inference.** The
artifact is the frozen graph.

### 2c. Runtime — the deterministic selection mechanism

At runtime the engine holds: the **world state** (scalars, flags, memory episodes —
all already deterministic functions of seed + action-log), a **cursor** (the set
of currently-active beats / the conversational "where we are"), and an
**anti-repeat ledger** (cooldowns, recently-fired beat ids).

One player action → one deterministic step:

1. **Resolve the action** against the current cursor's `exits` (the player's move
   matches an `on:` edge) *and* against the global pool of beats whose `when`
   guard now passes (ambient/volunteered beats the NPC initiates). This yields a
   **candidate set** of eligible beats.
2. **Rank** candidates by `(pull, recency-penalty, specificity)` — a *total
   order*, fully determined by state. Ties broken by `hash(seed, action-log,
   beat.id)` — the *only* place "randomness" enters, and it is a pure seeded
   function, so replay is bit-identical.
3. **Pick the top beat.** Within it, select the **variant** whose `if` guard
   passes (first match in authored order; the default last). This is selection,
   not assembly.
4. **Emit the variant's `text` verbatim.** No edit, no infill, no concatenation
   below the passage. (Multiple beats may fire in one turn only if the author
   explicitly chained them via a `then:` exit — still whole passages in sequence.)
5. **Apply `effects`** to world state; **push** any memory episode; update cursor
   to the fired beat's exits; bump the anti-repeat ledger.

The whole step is `(world-state, action, seed, ledger) → (beat-id, variant-id,
bytes)`, a pure deterministic function. **There is no generator.** Quality is
whatever the human-curated `text` already is.

---

## 3. Worked example (actual prose + mechanical trace)

One NPC, Maren. Seed fixed. Player has spoken with her before; current state:
`rel.maren.trust = 0.58`, `rel.maren.intimacy = 0.66`, `scene.place = kitchen`,
evening, memory holds `maren_complimented_player_cooking` from earlier.

**Action 1 — player: `compliment` ("That was the best meal I've had in months.")**

Candidate set: beats tagged `receive_compliment` whose `when` passes. Two are
eligible: `maren.generic.deflect_compliment` (pull 0.5) and
`maren.kitchen.compliment_lands_warm` (pull 0.8, requires `trust >= 0.55` — passes).
Rank picks the higher-pull, more-specific kitchen beat. Its variant guard checks
`intimacy >= 0.7` → false (0.66), so the **default variant** fires:

> She turns the dish towel over in her hands, once, and doesn't look up. *"You
> didn't have to say that."* A pause. *"But thanks."*

*Mechanics:* selected because trust cleared the guard and `pull` outranked the
generic deflect; the default variant fired because intimacy fell just short of
the intimate variant. Effects: `intimacy += 0.04` → 0.70; push memory
`maren_warmed_to_second_compliment`. Cursor now sits on this beat's exits.

**Action 2 — player: `reassure` ("I mean it. You don't have to brush it off.")**

The cursor's exit `{to: open_further, on: player.reassure}` matches directly —
no global search needed; the discourse edge is followed.
`maren.kitchen.open_further` fires. Its intimate variant now passes
(`intimacy >= 0.7` → 0.70):

> That stops her. She sets the towel down, finally, and the look she gives you is
> unguarded in a way she usually isn't. *"Okay."* The word comes out smaller than
> she meant it to. *"Okay — I've been wanting to tell you something."*

*Mechanics:* pure edge-follow from the prior beat; variant chosen by the now-true
intimacy guard. Effects: `flags.maren_about_to_confide = true`; push
`maren_opened_up_in_kitchen`. This is **continuity as graph position**: the line
reads as a *consequence* of the last one because the author wired the edge, not
because a generator inferred it.

**Action 3 — player: `tease` ("Wanting to tell me you're secretly a worse cook than me?")**

The cursor exit `{to: deflect_if_pushed, on: player.tease}` matches.
`maren.kitchen.deflect_if_pushed` fires — authored as the *cost* of teasing at a
vulnerable beat:

> Something closes, quietly. She picks the towel back up. *"Yeah. Something like
> that."* The moment you had a second ago is gone, folded away with the cloth,
> and she's smiling but it doesn't reach.

*Mechanics:* the author anticipated the discourse failure — teasing someone
mid-confession — and wrote the retreat *as a beat with consequences*. Effects:
`intimacy -= 0.06`, `flags.maren_about_to_confide = false`, push
`player_deflected_marens_opening`. The reactivity is real and *authored*, not
band-table'd.

**Action 4 — player: `wait` (leave, return next evening)**

Time advances; state decays deterministically. On return, the engine looks for
beats tagged `reentry` whose `when` passes. `maren.reentry.after_deflected_opening`
is eligible *because the memory episode `player_deflected_marens_opening` is in
the ledger and recent*:

> She's at the counter again when you come back, like she never left it. *"Hey."*
> She doesn't look up right away. Whatever she was going to tell you yesterday
> stays where she put it.

*Mechanics:* memory drives selection. The reentry beat's guard reads the durable
episode, so she greets you *as someone who remembers exactly what happened* —
the single most-wanted "alive" quality — and the prose was written knowing that
context. No generator reconstructed it; the author wrote the beat that the memory
unlocks.

Every line above is real, curated writing. Nothing was assembled at runtime. The
trajectory replays bit-for-bit from `(seed, [compliment, reassure, tease, wait])`.

---

## 4. How it achieves "alive"

- **Continuity** = graph position. A line follows from the last because an author
  wired the exit. The conversation *has a shape* (it's literally a walk), so it
  never reads as disconnected responses to isolated stimuli — the failure mode of
  band-table realizers that re-describe state every tick.
- **Memory** = durable episodes in the ledger that *gate* beats. "She remembers"
  is never narrated; it is *enacted* by which beats become eligible. The reentry
  beat in Action 4 only exists because the episode is there. Memory is citable and
  faithful: a beat that references an episode is only eligible when that episode
  is real.
- **Reactivity** = the cost/payoff structure of exits. Teasing a confession has an
  authored retreat beat; reassuring has an authored opening. The world *answers*
  the move, deterministically, with consequence.
- **Presence / a life of her own** = ambient beats (`when` over scene/time, not
  triggered by the player) plus the autonomous-sim layer (already in the spine:
  her scalars/flags/place evolve between sessions). She is *somewhere being
  someone* because her state advances off-screen and a different set of beats
  becomes eligible when you return. The graph naturally encodes "she's mid-arc."

---

## 5. Coverage — finite authoring over a combinatorial world

The combinatorial-explosion confrontation is the crux, so here it is head-on.

**The explosion is in STATE, not in BEATS.** State is combinatorial (every scalar
× flag × memory combination). Beats are not, because a beat's `when` guard
**quantifies over a region of state**, not a point. One beat covers an entire
*band* of trust/intimacy/scene combinations. You never author "the beat for
trust=0.581"; you author "the beat for trust ≥ 0.55 in the kitchen after a
compliment," which is one passage covering an uncountable region. This is the
"generalize, don't multiply" move the reference-analysis doc credits to LT —
applied at the **discourse** grain (beat covers a region) rather than the lexical
grain (slot covers a noun).

Three mechanisms keep it finite *without feeling sparse or repetitive*:

1. **Variants under one beat** give graceful specificity: the default variant
   covers the whole region; a few `if`-guarded variants light up for the
   high-value corners (the intimate read, the first-time read). 1 beat + 3
   variants covers a region richly with 4 authored passages — and degrades to
   *still-good* (the default) at the edges, never to garbage, because the default
   is itself real writing.

2. **Freshness via the anti-repeat ledger + multiple peer beats.** A region can
   hold several peer beats (same `when`, different `pull`/`tags`); cooldowns force
   rotation, so the same state visited twice plays *different authored passages*.
   This is genuine variety of *conception* (different authored takes), not lexical
   shuffling — exactly the distinction the prose doc demands.

3. **Salience-as-subtraction.** When several beats are eligible, the engine fires
   *one*, and when nothing salient is eligible it fires *less* (a short ambient
   beat or nothing), rather than re-narrating static state. Restraint is built into
   selection, not bolted on.

**What stays finite:** the number of *beats* and *variants*. A character is a few
hundred passages; a scene's worth of arcs is a graph a single author holds in
their head. The combinatorial state space is covered by *guards over regions*, so
authoring scales with **dramatic situations** (bounded — how many meaningfully
different moments a character has), not with **state points** (unbounded).

**The honest coverage limit:** the *uncovered tail* is a state region for which no
author wrote a beat. The lint catches *starvation* (a reachable region with no
eligible beat) at build time and forces the author to add at least a default beat,
so the shipped artifact has **no silent gaps** — but "has a beat" is not "has the
*perfect* beat." The tail degrades to a *general* authored beat for that region
(good, by construction, since it's real writing), not to the bespoke one a denser
author would have written. That is the same coverage concession the prose doc
names — but here it degrades to *real prose a human approved*, never to mad-libs,
because there is no sub-beat machinery that could produce mad-libs.

---

## 6. What it hides / assumes, and honest trade-offs

**Where it's strong:**
- **Quality is structurally guaranteed** to equal authored quality, because the
  runtime never touches the prose. The SESSION-RECORD's core finding — "the real
  gap is generation-with-taste; a net can't add judgment the generator lacks" — is
  *dissolved*, not solved: there is no runtime generator to lack taste. Taste lives
  at build time where a human exercises it. This is the candidate's whole reason to
  exist.
- **Determinism is trivial and total** — selection is a pure function; no float
  drift in language, no learned weights to replay, nothing to desync.
- **Continuity/reactivity/memory are first-class**, because the graph *is* the
  conversational structure, not an afterthought layered over a stateless renderer.
- **Debuggable and auditable** — every shipped line is a human-signed passage with
  an id; a bad line is a content edit, not a model retrain. No confabulation is
  possible (the runtime can only emit pre-approved text), which kills the recurring
  process failure.

**Where it's thin or might break (no hedging — the real risks):**
- **Authoring is the entire cost, and it is large.** Depth = many beats. A world of
  many characters, each with rich arcs, is *thousands* of authored passages. This is
  the TiTS/CoC/LT reality (those games are enormous hand-authored corpora) — the
  candidate doesn't escape it, it *embraces* it, with Opus as a force-multiplier on
  drafting. If the project wants depth without large authoring, this candidate
  refuses that wish honestly rather than faking it with a generator.
- **The graph can feel "on rails" at fine grain** if authors write too few peer
  beats per region — the anti-repeat ledger then cycles a small set and players
  notice the loop. Mitigation is *more authoring* (more peers/variants), which is
  the same cost lever. There's no algorithmic escape; density is bought, not
  generated.
- **Cross-beat prose cohesion is the author's burden.** Because beats are written
  somewhat independently, two beats fired in sequence can read with a slight seam
  (a repeated image, a tonal jump). The exits structure mitigates this (authors
  write follow-on beats *knowing* their predecessor), and the repetition-lint
  flags the worst cases — but there is no runtime smoother, so polishing seams is
  manual.
- **It assumes the "alive" qualities reduce to dramatic situations a human can
  enumerate.** For deeply systemic emergent states (a body/transformation combo no
  author anticipated), there may be no bespoke beat — only a regional default. The
  candidate bets that *regional defaults written well* carry those edges
  acceptably; if a project needs bespoke prose for genuinely novel systemic states,
  this candidate is weakest exactly there (and would lean on denser variant
  authoring for the systemic axes that matter most — body, arousal, scene).
- **Memory granularity is bounded by authored episode types.** "She remembers"
  works for episodes the author defined as gate-able (`player_deflected_marens_
  opening`); a memory of something *no beat keys on* is inert. Richer memory =
  more episode types + more beats keyed on them = more authoring.

**What it hides:** it hides the depth problem inside *human labor*, not inside an
unbuildable model. That is the honest version of the trade — it's not a
free-lunch generator; it's a content pipeline whose ceiling is how much good
writing you fund.

---

## 7. Buildability — finite and shippable, or fig leaf?

**This is genuinely buildable, and that is its main claim — the runtime is trivial
and the artifact is plainly finite.** No part of the system requires a model at
play time, and there is no hidden unbuildable step masquerading as a build artifact:
the "build" is *writing prose and wiring a graph*, which is a known, bounded,
shippable activity (it is literally how the reference games were made).

**Real scale estimate (honest):**
- *Runtime engine:* small. Guard evaluation, ranking, variant selection,
  anti-repeat ledger, exit-following, effects application. On the order of a few
  hundred lines over the existing interpreter — most of it already resembles the
  affordance interpreter aeriea has.
- *Build tooling:* moderate. The coverage/starvation/repetition lint and the
  golden-trace harness. Hundreds of lines plus Opus-as-leaf-critic prompts.
- *Content:* the dominant cost, and unbounded-by-ambition. A *vertical slice* —
  one character (Maren) with genuinely alive arcs across a handful of scenes — is
  perhaps **150–400 authored beats** (with variants, ~600–1500 passages). That is
  weeks of human-directed, Opus-assisted authoring for *one* deep character — and
  it is a real, completable number, not a fig leaf. A *full game* is that times the
  cast, i.e. the TiTS/CoC scale of authoring: large, but finite, fundable, and
  shippable, with Opus cutting the per-passage drafting cost substantially.

**Is the Opus use a fig leaf?** No. Opus is used at build time to *draft passages
against exact conditions* and to *critique/lint*, with a human curator signing
every shipped line. The shipped artifact contains zero model weights and makes
zero inference calls. If you deleted Opus entirely, the system still ships — it
would just cost more human authoring. That is the test of a non-fig-leaf
build-time use: **the runtime is complete without the model.** Here it is.

**The bet, stated plainly:** depth is achievable *only* by funding authoring at
the scale the reference games prove is necessary, and this candidate's value is
that it converts the unsolved "generate taste at runtime" problem into the *solved
but expensive* "author taste at build time" problem — trading an open research risk
for a known labor cost. Whether that trade is right is the user's call; the
candidate's job is to make it honestly.
