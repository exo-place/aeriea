# Candidate D — Coarse-grain combinatorics over Opus-authored prose beats

Status: design-it-twice candidate (one of five, independent). 2026-06-24.

## 1. Thesis + the atomic unit

**Thesis.** Aliveness is a property of *discourse*, not of *sentences*: author a finite library of whole, self-contained prose **beats** — each a paragraph-grade unit of real Opus-grade craft, written human+Opus at build time and frozen — and generate at runtime by deterministically **selecting and sequencing** beats against rich world+history state, never by assembling words; coherence is guaranteed not by a runtime stitcher but by a build-time-verified **connective contract** that every beat carries and every adjacency must satisfy.

The grain inversion is the whole bet. The rejected realizer (`prose-generation.md`, and the live `npc_realizer.gd` floor) composes *below* the clause — it reads four scalars and picks a `_present_tell` phrase, an `_echo` phrase, a `_reaction_for` phrase, and string-joins them. That is mad-libs at the discourse level: the *facts* vary but the *prose* is a Cartesian product of hand-typed fragments, and the seams (the ` `.join()`) are exactly where it reads stitched. Candidate D never selects a sentence. It selects a **beat** — a paragraph an author would be proud to ship whole — and the only runtime freedom is *which beats* and *in what order*.

### The beat (data shape)

A beat is an immutable record. Three faces: **conditions** (when it may fire), **content** (the frozen prose, plus pronoun/tense/render-time slots that are *resolved*, never *generated*), **connective metadata** (what it promises to the beats around it).

```jsonc
{
  "id": "maren.confide.half_said.bashful",
  "kind": "beat",
  // ---- CONDITIONS: a typed predicate over world+history state (NOT scalar bands) ----
  "fires_when": {
    "speech_act": "confide",
    "affect_in":  ["tender", "bashful"],
    "rel.trust":  { ">=": 0.6 },          // coarse gate, not the prose driver
    "history.has_beat_kind": "compliment_received",   // a DISCOURSE-history predicate
    "history.lacks_recent":  "confide.*",   // anti-repetition: not confided this way lately
    "scene.contact":  "hand_on_self"
  },
  // ---- CONTENT: frozen Opus-authored prose. Slots are render-resolved, not generated ----
  "prose": "{She} keeps {her} hand on {your} forearm a beat longer than it needs to. \"That thing you said earlier—\" {she} starts, and doesn't finish, color climbing {her} face.",
  "slots": ["subject_pronoun", "object_pronoun", "addressee_pronoun"],  // pure substitution, finite, agreement-checked at build
  "asserts": ["contact(self,addressee,forearm)", "references(memory:compliment)", "affect(self,bashful)", "arousal_rising(self)"],  // provenance: every claim ties to a state proposition
  // ---- CONNECTIVE METADATA: the coherence contract ----
  "opens": {                  // the state this beat LEAVES the discourse in
    "subject_in_focus": "self",          // who the next beat may pronoun-default to
    "tense": "present",
    "floor_is_action": true,             // ended on a physical beat, not interiority
    "unresolved": ["half_said_disclosure"], // a discourse OBLIGATION the next beat can pay off
    "topic": "the_compliment",
    "affect_left": "bashful"
  },
  "needs": {                  // what must already hold for this beat to be a legal SUCCESSOR
    "topic_in": ["the_compliment", "<fresh>"],
    "subject_known": true,               // a name/pronoun referent must be established upstream
    "affect_continuous_with": ["tender","bashful","warm"]  // no affect whiplash
  },
  "role": "turn",   // beat taxonomy: establish | turn | escalate | resolve | aside | transition
  "cost": 1,        // discourse "length" budget weight
  "variants": ["maren.confide.half_said.bashful#a", "...#b"]  // seed picks among TRUE equivalents (same opens/needs/asserts)
}
```

The load-bearing column is **`opens`/`needs`**. It is a tiny typed handshake — a discourse *type system*. A sequence of beats is legal iff each beat's `needs` is satisfied by the accumulated `opens` of everything before it. That is what replaces a runtime generator stitching prose: the stitching was *pre-proven legal at build time* and re-checked cheaply at runtime as a type check, not synthesized.

## 2. Architecture

### Build time

1. **Authoring as prose, not data.** A human + Opus write beats *as paragraphs*, in voice, for a target situation. The unit of authoring is the unit of craft: you write the whole confide-half-said beat the way Opus writes it in freeform RP — subtext, restraint, the telling detail — and you ship *that*, frozen. Opus is the ingredient exactly as `prose-generation.md` sanctions (best-of-N, curate, refine), but the curated artifact is a **finite beat**, not a grammar or a trained net. This is the cleanest possible use of the "Opus as build-time ingredient, our floor not our ceiling" claim: the floor is literally Opus's own paragraph, preserved.

2. **Connective annotation (semi-automated).** For each authored beat, an offline pass (Opus + human audit) fills `opens`/`needs`/`asserts`/`role` from the prose: what pronoun referents it establishes, what tense it ends in, what topic it leaves live, what discourse obligation it opens or closes, what it asserts about state (provenance). This is *labeling existing prose*, a far more reliable LLM task than *generating* prose — the recurring confabulation failure (SESSION-RECORD meta-learning #4) is structurally smaller because the model annotates a fixed string rather than inventing one.

3. **The adjacency closure (the key build artifact).** Compute, offline, the **legal-successor relation**: for every ordered pair `(A, B)`, does `B.needs ⊑ accumulate(A.opens)`? This yields a directed graph `succ ⊆ beats × beats`. Then run a **build-time coherence judge** (Opus, at the leaves) over a sample of *actual rendered adjacencies* — not abstract pairs but `prose(A) ⧺ prose(B)` — scoring for: pronoun/tense continuity, no contradiction, no jarring affect jump, no repetition, transition-reads-natural. Any pair the type-check passed but the judge fails is a **contract bug**: either tighten the `needs`/`opens` annotation, or author a **transition beat** that bridges them. The closure is iterated until *every type-legal adjacency is also judge-legal*. **This is the invariant that makes runtime safe without a generator: type-legal ⟹ judge-legal, proven at build time, so the runtime only has to maintain type-legality.**

4. **Transition beats** are first-class beats with `role: transition`, short, whose job is to carry the discourse from one `opens`-state to a `needs`-state nothing else bridges (a tense shift, a topic pivot, a beat of silence that resets affect). They are how seams are paved over *with authored prose* rather than synthesized glue.

5. **Coverage instrumentation.** The build emits, per `(speech_act × affect × relationship-stage × salient-history-shape)` cell, how many legal beats exist and the worst-case shortest legal discourse. Empty/thin cells are the authoring backlog (see §7).

### Runtime (no LLM, deterministic)

Per interaction, the engine has: the brain's **communicative intent** (the spine's tuple — `prose-generation.md`'s interface), the **salient state delta** (§1 of the rejected doc's salience engine is *reused* — it is good; it decides *what is worth saying*), the **discourse history** (the ordered list of beats already fired this and prior scenes, with their `opens`), and the **seed**.

```
render(intent, salient, history, seed):
  budget   = discourse_budget(intent)            # how many beats this turn (often 1; sometimes 3)
  ctx      = accumulate(history.opens)            # current discourse state
  chosen   = []
  while len(chosen) < budget:
    cand   = { b in beats : b.fires_when ⊨ (intent, salient, world)   # CONDITION match
                          and b.needs ⊑ ctx                            # TYPE-LEGAL successor
                          and b.id ∉ history.recent(window)            # anti-repetition
                          and salience_covered(b, salient) }           # says something still unsaid
    if cand empty:
        cand = transition_beats_legal_from(ctx)    # need a bridge; never synthesize one
    b      = argmin/seed-pick over cand by (salience_priority, -recency, variant)  # DETERMINISTIC
    chosen.append(b);  ctx = accumulate(ctx, b.opens);  mark salience(b) consumed
  return "".join(resolve_slots(b, ctx) for b in chosen)   # slot resolution = pronoun/tense/name agreement ONLY
```

Determinism: `argmin` ties broken by `seed + state_hash` (exactly the `prose-generation.md` §4 mechanism, but branching at the **beat-selection** layer — variety of *which beat and which order*, i.e. variety of conception, not lexicon). `resolve_slots` is pure substitution over a finite agreement table (he/she/they/you, present/past), build-checked, no generation. Same `(intent, salient, history, seed)` ⟹ same beat ids ⟹ same bytes.

**There is no runtime stitcher.** The "stitch" is (a) the `needs ⊑ ctx` filter, which only ever admits beats whose openings were build-proven coherent after the current context, plus (b) slot resolution against `ctx` (pronoun referent, tense). Both are total functions; neither generates language.

## 3. Worked example

One NPC, Maren. Trust 0.81, the player has just complimented her (recorded as a `compliment_received` history beat two ticks ago), arousal rising, her hand is on the player's forearm. A 4-action trajectory.

**Action 1 — player `compliment`s her.** Intent: `(assert, praises(self), affect: warm, register: casual)`. Salient: the praise is novel.
Condition-match + type-legal candidates include the warm-receive beats; `ctx` is empty (scene open) so any beat whose `needs.subject_known=false`-tolerant establish-role fires. Seed picks:

> *She glances down, then back up, and the line of her shoulders eases — like she'd been braced for something and it didn't come. "Yeah?" she says. "You mean that."*

`role: establish`. `opens: {subject_in_focus: self, tense: present, topic: the_compliment, affect_left: warm-guarded, unresolved: [praise_unanswered]}`.

**Action 2 — player `confide`s ("I've been wanting to tell you—").** Intent: `(confide, wants_closeness(self,player), affect: tender)`. Salient: contact (hand on forearm) now novel + the rising arousal.
Candidates filtered by `needs.topic_in: [the_compliment, <fresh>]` (satisfied — topic is live) and `needs.affect_continuous_with` includes `warm` (satisfied — affect_left was warm-guarded). The half-said beat (§1) fires:

> *She keeps her hand on your forearm a beat longer than it needs to. "That thing you said earlier—" she starts, and doesn't finish, color climbing her face.*

Transition note: no transition beat was needed because beat-2's `needs` was already satisfied by beat-1's `opens` (topic continuous, affect continuous, subject in focus = self so "She" resolves with no ambiguity). The pronoun "your" resolves against `ctx.addressee = player`. `opens` now carries `unresolved: [half_said_disclosure]`.

**Action 3 — player waits / says nothing (a `hold` affordance).** Intent: `(yield_turn, _, affect: attentive)`. Salient: nothing changed materially — and crucially, there is an **open discourse obligation** (`half_said_disclosure`). The selector prefers a beat whose `fires_when.pays_off: half_said_disclosure`:

> *The quiet stretches. She lets it, watching your face, and then her thumb moves once against your sleeve. "I don't do this," she says, almost to herself. "Say things. But—" A breath. "—you make it feel like I could."*

`role: resolve` (pays off the obligation; `opens.unresolved` now empty). Affect escalates tender→intimate within the continuity band, so no whiplash.

**Action 4 — player `pull_away` (cooling).** Intent: `(withdraw, _, affect: guarded)`. This is an **affect discontinuity**: `affect_left` was `intimate`, the withdraw beats `need affect_continuous_with: [intimate, warm]` for the *recoil* read but the player's act is cold. No condition+type-legal beat bridges intimate→cold-recoil directly (build closure proved that adjacency jarring). The selector falls to `transition_beats_legal_from(ctx)`:

> *Something in her face closes by degrees, like a door that doesn't slam.*

`role: transition`, `opens: {affect_left: hurt-guarded}`. *Then* the withdraw beat is now type-legal:

> *She takes her hand back, slow, and folds it into the other one. "Right," she says. "Of course." The warmth is gone out of her voice like it was never the point.*

**Assembled transcript (actions 1–4, as the player reads it):**

> She glances down, then back up, and the line of her shoulders eases — like she'd been braced for something and it didn't come. "Yeah?" she says. "You mean that."
>
> She keeps her hand on your forearm a beat longer than it needs to. "That thing you said earlier—" she starts, and doesn't finish, color climbing her face.
>
> The quiet stretches. She lets it, watching your face, and then her thumb moves once against your sleeve. "I don't do this," she says, almost to herself. "Say things. But—" A breath. "—you make it feel like I could."
>
> Something in her face closes by degrees, like a door that doesn't slam. She takes her hand back, slow, and folds it into the other one. "Right," she says. "Of course." The warmth is gone out of her voice like it was never the point.

Read it straight through: pronouns track, tense holds, the half-said line in beat 2 is *paid off* in beat 3 (a discourse arc, not three independent observations), and the cooling in beat 4 is cushioned by an authored transition so it doesn't whiplash. It does not read like stitched fragments because **each unit is already a paragraph an author wrote whole**, and the only joins are at paragraph boundaries the author *designed to be joinable* (the `opens`/`needs` contract). The mad-libs realizer's seam is mid-paragraph (phrase + phrase + phrase); D's only seam is between paragraphs, which is where prose *naturally* breaks.

## 4. How it achieves "alive"

- **Continuity** is the `opens`/`needs` contract: the discourse literally remembers what it left open (a half-said line, an unanswered praise, a topic) and prefers beats that *pay it off*. Arcs emerge — setup → tension → payoff — because obligations are tracked and preferentially resolved, not because anyone generated an arc.
- **Memory** is `history.has_beat_kind` / `history.lacks_recent` conditions reading the *discourse* history, not just scalars. Maren's beat in action 2 fired *because* `compliment_received` is in her history; a callback beat ("you keep saying that") fires only with ≥3 prior compliments. Memory is shown by *which beat is eligible*, and it persists across sessions (the brain's between-sessions life adds history beats; she can open with a beat conditioned on something that happened while you were gone).
- **Reactivity** is the richness of `fires_when` predicates over the brain+world+semantic state. Beats gate on contact, posture, arousal trajectory, relationship stage, what-she-knows, theory-of-mind mismatches — the same rich state the spine holds. A different state lights a different eligible set, so she *reacts to the specific situation*, not a band of a scalar.
- **Presence** is the seed-driven choice among true-equivalent variants *and* among different legal orderings: the same situation twice yields a different beat or a different sequence, deterministically (replayable), so she never reads identically twice (`prose-generation.md` freshness, branched at conception not lexicon).

The aliveness is combinatorial: `eligible(state) × legal-orderings × seed-variants` is a vast space, and every point in it is whole authored craft.

## 5. Coherence mechanism (exactly how adjacent beats never jar)

Three layers, all build-time-decided, runtime-cheap:

1. **The type check (`needs ⊑ accumulate(opens)`).** A beat can only fire after a context that satisfies its preconditions: subject established, tense compatible, topic live-or-fresh, affect within a continuity band, no contradiction of asserted state. This is a total, deterministic filter — it *cannot* admit an illegal successor.

2. **The build closure invariant (type-legal ⟹ judge-legal).** The build iterates the adjacency closure until *every* type-legal rendered adjacency also passes the Opus coherence judge (continuity, no contradiction, natural transition). Where the type-check is too permissive (admits a jarring pair the judge flags), the fix is to *tighten the annotation* (add a `needs`/`opens` distinction that excludes it) or *author a transition beat*. So at runtime, satisfying the cheap type-check is sufficient for coherence, because the expensive judge already certified that implication offline. The runtime never needs the judge.

3. **Slot resolution against `ctx`.** Pronouns, tense, and names are not baked into beat prose; they are slots resolved against the accumulated discourse context (who is in focus, what tense the discourse is in, the addressee). This guarantees pronoun/tense agreement *mechanically*, the one cross-beat surface property that frozen prose alone can't promise. The agreement table is finite and build-checked.

4. **Transition beats as the escape valve.** When no content beat is type-legal from the current `ctx` (a real discontinuity — affect whiplash, topic jump), the engine inserts an authored `role: transition` beat that *moves* `ctx` to a state from which content beats are legal. Seams are bridged with prose a human wrote for exactly that bridge, never with synthesized glue.

Contradiction specifically is caught by `asserts` provenance: a beat may not fire if its `asserts` conflict with state already asserted live in `ctx` (she can't "take her hand back" in beat 4 unless `contact(hand_on)` is currently asserted — and once she does, `ctx` drops it, so a later beat can't reference the hand still being there).

## 6. What it hides/assumes + trade-offs + why this is NOT mad-libs

**Why NOT mad-libs.** Mad-libs (the rejected realizer, the live `npc_realizer.gd`) substitutes *words/phrases into a sentence frame*: the unit of authoring is a fragment, the unit of variation is lexical, the seam is mid-sentence, and craft is destroyed because no fragment carries subtext that survives recombination. Candidate D's unit of authoring is a *whole paragraph of finished Opus-grade prose*; the unit of variation is *which paragraph and in what order* (conception, not lexicon); the only substitution is pronoun/tense/name agreement (which is grammar, not content); and the seam is at paragraph boundaries the author designed to join. Subtext is preserved because it lives *inside* a frozen beat that is never decomposed. The combinatorics are at the **discourse** grain (Caves-of-Qud legend-assembly, but the atoms are Opus paragraphs), which is the brief's exact target.

**What it hides / assumes.**
- It assumes the *discourse-level* contract (`opens`/`needs`, role taxonomy, continuity bands) is expressive enough to make all-pairs coherence decidable by a cheap type-check. If two beats are coherent only due to a *semantic* nuance the contract doesn't capture, either the closure judge forces an annotation refinement (good) or you over-fragment the topic space (cost).
- It assumes salience/intent (reused from the spine) reliably says *what is worth saying*; D owns *how it's said*, not *what*.
- It hides the long tail in **coverage**: aliveness within authored cells is excellent; a state cell with few beats reads thin or repetitive (the TiTS/FS failure mode the brief names — content-deep then thin at the edges).

**Honest trade-offs.**
- *Granularity tension.* Coarse beats (great craft, fewer of them) cover less specific state; fine beats (more reactive) approach mad-libs and lose whole-paragraph craft. The beat must stay *paragraph-grade* — that's the discipline, and it caps how finely D can react to micro-state. D answers "specificity vs depth" (`prose-generation.md`) by siding with **depth**: it will say *less but better*, choosing the one telling beat over enumerating every fact.
- *Authoring is real labor.* Beats are written, not generated at runtime. This is a feature (craft is preserved) and a cost (see §7).
- *No novel-state extrapolation.* On a genuinely uncovered state cell, D has no beat and must fall to a `role: aside`/transition generic — its non-trash floor — exactly the coverage concession `prose-generation.md` already owns. D does not pretend to generalize craft to unbaked states; it makes the *baked* states excellent and the boundary graceful.

## 7. Buildability — finite, shippable, not a fig leaf

**It is finite and shippable.** The artifact is: a beat library (frozen JSON + prose), the `succ` adjacency relation (precomputed), the slot-agreement table, the salience reuse. Zero runtime inference. This is the most obviously-buildable of the candidate frames *because the runtime is a graph walk over frozen strings* — there is no trained net to converge, no grammar to de-stiffen, no extraction pipeline to trust. The hard part is moved entirely to authoring, which is bounded labor, not open research.

**How many beats for viability?** Estimate from the structure. Coverage cell = `speech_act (~15) × affect-band (~6) × relationship-stage (~5) × salient-history-shape (~6)` ≈ 2,700 cells. Not every cell is reachable or needs depth; the *focal* cells (the speech-acts and stages players actually live in) are maybe ~400. At ~4 variant beats/cell for freshness + ~1 transition per discontinuous cell-pair that occurs, a **viable first NPC archetype is ~1,500–2,500 beats**; a rich one ~5,000. Beats are *shared across NPCs* with voice-slotting (a confide-half-said beat's structure is reusable; voice is a slot/variant axis), so the second NPC is a fraction of the first. This is the *same order of magnitude as TiTS/LT/CoC actually shipped* (those games are tens of thousands of authored prose chunks) — and the brief's own reference set proves authored combinatorial prose at this scale *ships and feels alive*. So: **finite, comparable-to-proven-corpora, and the runtime is trivial.** Not a fig leaf — the build-time LLM yields a concrete frozen library, and the game runs with no model in the loop.

**The honest risk that bites:** the **adjacency closure** (§2.3) is `O(beats²)` pairs to certify, and the iterate-until-type-legal⟹judge-legal loop is the real cost — for 2,000 beats that's ~4M ordered pairs, most pruned by type-incompatibility before the judge ever runs, but the residual is a large build-time judge bill and a real annotation-refinement effort. This is bounded and parallelizable (it's the buildable shippable artifact the constraint demands), but it is where the project-months go. The bet is that *paving seams once, offline, exhaustively* is more tractable — and far more taste-controllable — than asking any runtime mechanism to stitch coherent prose on the fly.

## Cross-links
- Reuses `prose-generation.md` §1 salience (what to say) and §4 seeded-variation (branched at beat-selection); designs *against* its §2–3 sub-clause grammar/realizer-surrogate by inverting the grain.
- Consumes `npc-mind-and-language.md`'s communicative-intent tuple unchanged.
- `fires_when` predicates query `semantic-layer.md` for affect/relationship/world state; D adds discourse-history predicates the rejected design lacked.
- Replaces the internals (not the seam) of `scripts/text/npc_realizer.gd`: `describe_*` become beat-selection over the library; callers unchanged.
</content>
</invoke>
