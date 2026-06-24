# Candidate B — INVERT THE DEPENDENCY: the scene IS the query, play IS deterministic retrieval

> Design-it-twice candidate. One of five. This is the **inverted** design: it argues
> against the rejected state→prose spine, not toward the other candidates. Where the
> rejected design *manufactures* prose from numeric state through a realizer, this design
> **retrieves authored prose** indexed by the *meaning of the interaction-so-far*. RAG
> without the G.

---

## 1. Thesis & core primitive

**Thesis (one sentence):** The runtime never *generates* a sentence — it **selects** the
next authored beat by deterministic nearest-neighbor over a frozen, build-time-embedded
corpus of real human-authored exchanges, where the query is a vector encoding *the scene
so far* (this NPC, this history, this world-state, the last few beats) and continuity comes
from **authoring and retrieving whole continuation-conditioned beats, not disjoint quotes**.

**Core primitive — the BEAT and the SCENE-VECTOR.**

- A **beat** is the atomic shippable unit: a short span of authored prose (1–4 sentences,
  one NPC turn + its embodied stage-direction) *plus* its **precondition signature** (the
  world/relationship/affect/topic conditions under which it is sayable) *plus* its
  **outgoing affordances** (what player moves it sets up / responds to) *plus* a **frozen
  embedding** of the situation it answers. A beat is data: prose string + structured tags +
  a fixed-point vector. Authored by humans (LLM-assisted at build time), curated, frozen.
- A **scene-vector** is the runtime query: a deterministic, fixed-point composition of (a)
  the embedding of the *last K beats actually played* (the literal conversational trajectory),
  (b) the embedding of the *salient world/relationship/affect facts right now*, and (c) the
  embedding of *the player's just-chosen affordance*. The runtime computes this vector with
  pure fixed-point vector math and finds the nearest sayable beat.

The index is **the meaning of the interaction-so-far**. Not the NPC's mood scalar (that's the
rejected lens); the *whole situated trajectory*. Retrieval is a function of where the
conversation has *been*, not just where a number sits.

---

## 2. Architecture

### 2.1 Build-time: authoring + embedding → the frozen corpus artifact

**The corpus is a graph of beats, not a bag of lines.** This is the single most important
build-time decision and the answer to "how does retrieval stay coherent." Beats are authored
**in continuation chains**: an author (human lead + LLM as drafting ingredient) writes a
*scene* — a real, 8–30-beat authored exchange with one NPC under specified conditions — and
the chain structure (beat → plausible next-beats) is captured as edges. The corpus ships as:

```
corpus.bin  (frozen, content-addressed, shipped read-only)
  beats: [
    {
      id:        u32
      npc:       interned NPC-archetype id (Maren, the bartender, ...)
      prose:     string           # the authored NPC turn + stage direction
      pre:       PreconditionSig   # bitset+ranges over world/rel/affect/topic facts
      sets:      EffectSig         # what playing this beat commits to the world-state
      affords:   [affordance_id]   # player moves this beat answers / invites
      emb:       i16[D]            # FROZEN quantized embedding (see 2.3); D≈256
      chain_next:[beat_id]         # authored plausible continuations (coherence edges)
      register:  enum              # tender/wry/clinical/crude/guarded... (for SFW/NSFW + affect gate)
    }, ...
  ]
  npc_index:  per-NPC sub-index (beats partitioned by NPC-archetype)
  emb_norms:  i32[N]               # precomputed fixed-point ||emb|| for cosine
```

**How beats are authored (the build-time LLM-as-ingredient loop, finite & shippable):**

1. **Scene seeding.** For each NPC archetype and each *situation cell* (a coarse cell in the
   product space `relationship-band × dominant-affect × topic × recent-event`), the lead
   writes or commissions a **real authored scene** at meet-or-exceed-Opus craft. Opus is used
   here exactly as the rejected design sanctions: best-of-N drafting + human curation +
   refinement. The output is *prose a human approved*, not prose a model emitted live.
2. **Decomposition into beats.** Each scene is cut into beats; chain edges recorded.
3. **Precondition lifting.** For each beat, the author (LLM-assisted, human-verified) tags the
   `pre` signature: what must be true for this line to be sayable. This is the work that makes
   retrieval *reactive* rather than generic.
4. **Variant authoring.** The same situation cell gets **3–6 genuinely distinct authored
   takes** (different conception, not synonyms) so retrieval has fresh alternatives and replay
   variation has somewhere to branch (§4).
5. **Embedding.** Every beat's *situation* (a canonical serialization of `npc + pre + topic +
   incoming-affordance + register`, NOT the prose itself) is embedded by a **frozen,
   build-time, versioned embedding model**, then **quantized to i16 and stored**. The model is
   never shipped or called at runtime — only its frozen outputs ship. (Embedding the
   *situation* not the *prose* is deliberate: we retrieve by "what situation does this answer,"
   so the query — which is a situation — lives in the same space.)

**The frozen artifact is the embeddings + prose + signatures + chain graph.** No model, no
generation code. It is a finite, content-addressed binary. See §7 for honest scale.

### 2.2 Runtime: deterministic retrieval + binding

Per player action, the runtime does **zero model inference**. It:

1. **Filters by hard preconditions.** From the per-NPC sub-index, take the candidate set
   `C = { beat : beat.pre matches current world/rel/affect state AND register ∈ allowed AND
   beat.affords ∋ player_affordance }`. This is a deterministic bitset/range intersection. It
   guarantees **faithfulness by construction**: a beat can only be retrieved if its authored
   preconditions are literally true of the sim state. No beat asserts what isn't true.
2. **Prefers chain-continuous candidates.** Intersect `C` with `chain_next(last_beat)` to get
   `C_cont`. If non-empty, retrieve within `C_cont` (the authored coherent continuation).
   Otherwise fall back to `C` (a *re-entry* into a new authored chain — see §5). This is the
   coherence mechanism: we walk authored chains and only jump chains when forced.
3. **Computes the scene-vector** `q` (fixed-point composition of last-K-beat embeddings +
   salient-state embedding + affordance embedding; weights are frozen integers).
4. **Deterministic nearest-neighbor.** Pick `argmax_{b ∈ candidates} cosine_fp(q, b.emb)`.
   - Distance metric: **integer cosine** computed as `dot(q,b.emb)` (i64 accumulator over i16
     lanes) compared via the cross-multiplication `dot_a · norm_b² ⋛ dot_b · norm_a²` so **no
     float division or sqrt** enters the comparison — pure integer ordering.
   - **Tie-break (total order, fully specified):** `(score_fp DESC, chain_continuity DESC,
     freshness_rank DESC, beat_id ASC)`. `freshness_rank` is a deterministic function of
     `seed + scene-hash + recently-played-beat-ids` (§4). `beat_id ASC` is the final
     deterministic backstop so the order is total. **No floats anywhere in the ordering.**
5. **Binds the chosen beat** (§4.3): slot-fills the small set of *grounded literals* the beat
   declares (the player's name, the drink she's holding right now, the hour) from live state.
   This is the *only* mutation of authored text and it is constrained to typed, enumerable
   slots — never free generation.
6. **Commits effects.** Apply `beat.sets` to the world/relationship state (this is what makes
   the *next* query reflect that this beat happened), append `beat.id` to the played-log.

**Determinism holds because:** embeddings are frozen i16 constants in the artifact; the query
is a fixed-point function of `(played-beat-ids, salient-state, affordance, seed)`; the metric
is integer cosine via cross-multiplication (no float div/sqrt); the tie-break is a total order
ending in `beat_id`. Same seed + same action-log ⟹ same scene-vector ⟹ same argmax ⟹ same
bound prose, bit-for-bit. The action-log replays the retrieval exactly.

### 2.3 Why frozen embeddings are deterministic (the exploit)

The prompt is explicit: precomputed/frozen embeddings + canonically-ordered NN **is**
deterministic and is **not** a runtime LLM. We lean on this fully. The embedding model runs
**once, at build time**, on situation-serializations, and we ship the quantized i16 vectors.
Runtime cosine is integer arithmetic. There is no per-query inference; "retrieval" is array
math over constants. This is the same sanctioned shape as the semantic-layer's frozen graph —
the hard, nondeterministic work is paid offline; a deterministic artifact ships.

---

## 3. Worked example (real trajectory, real prose, real mechanics)

NPC: **Maren**, the bar's closer. Player has talked to her across three prior sessions;
relationship-band = `familiar-not-yet-close`, she's mid-shift, low-grade tired, the player
once left without saying goodbye (an authored *event* tag carried in state: `left_abruptly:1`).

**State at scene open (salient facts the scene-vector encodes):**
`npc=maren, rel_band=familiar, affect=tired_wry, topic=none, recent_event=left_abruptly(stale),
hour=late, holding=bar_rag`.

---

**Action 1 — player chooses affordance `greet`.**

- Hard-filter: candidates are Maren-beats afford­ing `greet`, `pre` matching `familiar +
  tired_wry + late`. `left_abruptly` is stale (decayed) so beats gated on a *fresh* abrupt-leave
  don't qualify — but a beat tagged "carries a faint old slight" does.
- No prior beat ⟹ `C_cont` empty ⟹ retrieve within `C`. Scene-vector ≈ embedding of
  `[familiar, tired_wry, late, greet, faint-old-slight]`. Argmax beat:

> Maren clocks you in the bar mirror before she turns around. "Look who remembered the
> address." She doesn't quite smile, but the rag stops moving on the glass.

- Mechanics: retrieved because its authored situation-embedding sits nearest the query; the
  *"remembered the address"* dryness is the authored encoding of `familiar + faint-old-slight +
  wry`. **Bound literal:** none needed. `sets`: `topic=reconnect`, `last_beat=this`.

**Action 2 — player chooses `acknowledge` (own the abrupt leave).**

- `C_cont = chain_next(beat1) ∩ {affords acknowledge} ∩ {pre matches}` — the authored scene
  this beat came from *has* an acknowledge-continuation. Non-empty ⟹ stay in-chain (coherence):

> That earns a real look, finally. "You don't have to do that." A beat. She sets the glass
> down rim-up, the way she does when she's deciding to put something down with it.

- Mechanics: in-chain retrieval keeps the *glass* motif the author planted in beat 1 alive —
  this is why continuity isn't disjoint: the **author** wrote the glass-then-set-it-down arc;
  retrieval just walked the edge. `sets`: `rel_band += warmth`, `old_slight=cleared`.

**Action 3 — player chooses `ask_about_her` (turn it toward Maren).**

- In-chain continuation exists and matches the *now-cleared* slight + new warmth:

> "Me?" She huffs, wiping her hands slow. "I close. I lock up. I go home to a cat who's
> furious about the hours." She glances over. "Riveting, I know." But she's leaning on the
> bar now, not standing behind it.

- Mechanics: the `leaning on the bar now, not standing behind it` proxemic shift is authored
  to fire only in the `warmth-rising` band — retrievable *only because* action 2 committed the
  warmth. Reactivity is the precondition gate doing its job. **Bound literal:** the cat detail
  is authored-fixed for Maren (part of her authored interiority), not slotted.

**Action 4 — player chooses `leave` (again).**

- Hard-filter surfaces the beats gated on `about_to_leave + warmth_present + history(left_abruptly)`.
  The author wrote *exactly this callback* because the leave-again situation is dramatically
  loaded:

> She catches it this time — your hand already half-turned toward the door. "Hey." Not
> sharp. Just enough to land. "Say it this time. Whatever it is. You can owe me later."

- Mechanics: this beat exists **because a human author anticipated the resonance of leaving a
  second time after the first leave became a sore point** — depth the corpus *holds*, surfaced
  by a precondition that fuses `leave-affordance + warmth + prior-leave-history`. The runtime
  did no reasoning; it matched a richly-conditioned authored beat. `sets`: callback-debt flag,
  remembered for next session.

**Why the prose is good:** every line above is *authored at meet-or-exceed-Opus craft and
human-approved at build time*. The runtime contributes **selection and binding**, never
phrasing. The craft ceiling is the author's, and the author had unlimited time, revision, and
taste — which is exactly the meta-learning's demand: **quality lives in the thing producing the
work**, and here the producer is a human-curated corpus, not a live generator.

---

## 4. How it achieves "alive"

The meta-learning is unforgiving: detection can't add taste, and quality must live in
generation. This design's answer is that **all the taste is paid for at authoring time by
humans**, and the runtime's only job is to keep it *coherent, continuous, and bound to this
world* so it doesn't read as a canned line.

- **Continuity (not disjoint quotes).** The corpus is a *graph of authored chains*, and
  retrieval **prefers in-chain continuation** (step 2.2.2). Coherence is authored, not
  synthesized: the glass motif, the proxemic arc, the callback all came from one human-written
  scene. The runtime walks authored throughlines and only re-enters a new chain when the player
  goes somewhere the current chain didn't anticipate — and re-entry is itself into another
  authored chain, not into a void.
- **Memory.** State carries event tags (`left_abruptly`, `cleared`, callback-debt) that persist
  across sessions and **gate preconditions**. Maren's second-leave callback is memory made
  mechanical: a beat that is *only sayable because the first leave is on the record*. Memory
  isn't narrated ("she remembers") — it's the *reason a particular authored line becomes
  retrievable*.
- **Reactivity.** The hard-precondition filter means a beat surfaces **only** when its authored
  conditions are literally true now. Warmth-band beats can't fire until warmth is committed;
  the leaning-on-the-bar beat is unreachable from the guarded band. The same affordance
  (`greet`, `leave`) retrieves different authored beats as state moves — reactivity is the
  filter + scene-vector, not a relabeled template.
- **Presence / her own life.** Authored beats carry *her* interiority (the furious cat, the
  lock-up ritual) as fixed authored detail — depth the corpus holds that no scalar lens could
  manufacture without confabulating. Between sessions, the sim advances state (decay, events);
  on return, the *changed* state retrieves *different* authored re-entry beats, so she reads as
  someone who was somewhere being someone.
- **Why it doesn't feel canned — three mechanisms:**
  1. **Variant pools + seeded freshness.** 3–6 distinct authored takes per situation cell;
     `freshness_rank` (a function of `seed + scene-hash + recently-played-beat-ids`) rotates
     among near-tied candidates and **down-weights recently-played beats**, so the same
     situation doesn't return the same words twice within a playthrough, yet replays
     bit-identically on the same seed+log. Variation is of *conception* (different authored
     takes), not lexicon.
  2. **Binding to live literals.** The small typed slots (player name, the drink in her hand
     *right now*, the hour) ground each beat in *this* moment, so an authored line reads as
     spoken-to-you, not pulled from a script.
  3. **The chain graph dissolves the "quote" feel.** Because beats arrive as *continuations of
     what was just said*, with authored motifs carried across them, the player experiences an
     unfolding scene, not a jukebox.

---

## 5. Coverage + cold-query handling

This is where the design must be honest. Retrieval can only return what's authored.

- **Warm query (the common case in authored territory):** `C_cont` non-empty, a near beat
  exists, score high — the system is in its sweet spot.
- **Lukewarm (in `C` but out of chain):** player went off the current authored throughline but
  into a *covered situation cell*. We re-enter a new authored chain. There's a small seam
  (a scene transition), softened by **bridge beats** — short authored connective turns tagged to
  cover chain-to-chain re-entry for each NPC ("She lets the subject drop. '...Anyway.'").
- **Cold query (nothing matches well):** best `cosine_fp` falls below a frozen integer
  threshold, or `C` is empty after filtering. The design's honest answer is a **tiered graceful
  floor, never live generation:**
  1. **Generalize the precondition.** Relax the least-load-bearing precondition dimension
     (deterministic, ordered) and re-query — many "cold" queries are just over-specified.
  2. **Archetype-generic beat.** Each NPC has a small pool of *low-specificity but in-voice*
     authored beats (deflections, "I'm not sure what to tell you," topic-neutral business)
     tagged to match almost anything — authored to be *good-but-general*, the non-trash floor.
  3. **Beat-gap is a build signal, not a runtime patch.** Every cold query is logged at build/
     playtest time as a **coverage hole**, fed back to authoring. The corpus grows toward
     observed play; cold queries shrink over time. This is the corpus-as-living-spec discipline.

**Where it breaks (named plainly):** truly novel situations the authors never imagined fall to
the archetype-generic floor and read *general* (in-voice, not broken, but not bespoke). The
combinatorial tail is real — same coverage problem the rejected design has, but here it
degrades to *authored-general* rather than to *manufactured-flat*, which is a better failure.

---

## 6. What it hides / assumes & honest trade-offs

**Hidden assumptions:**

- **That a human-authored corpus can cover enough of the situation space to feel alive most of
  the time.** This is the central bet. It's the TiTS/CoC/LT bet — those games *are* large
  authored corpora and they do feel alive in their covered territory — but they pay for it with
  enormous authoring.
- **That situation-embedding similarity tracks "this beat fits here."** A frozen embedding model
  has to put *dramatically-appropriate* situations near each other. If the embedding geometry is
  bad, retrieval picks tonally-wrong beats. Mitigated by the hard precondition filter (embedding
  only *ranks within* an already-valid candidate set), but the ranking quality still rides on
  the embedding.
- **That preconditions can be authored richly enough to make retrieval reactive.** The
  precondition signature is doing the reactivity work; thin preconditions ⟹ generic-feeling
  retrieval. This is real authoring labor.

**Trade-offs:**

- **(+)** Quality lives in human authorship — directly answers the meta-learning. No live
  generator to lack taste. Determinism is *easy* (array math over constants), not a fight.
  Faithfulness is by construction (precondition gate). Cross-session memory is mechanical.
- **(−)** Coverage is bounded by authoring effort; the tail degrades to general. Authoring +
  precondition-tagging is the dominant cost. Embedding geometry is a single point of ranking
  failure. Slot-binding must stay disciplined or it slides toward mad-libs (guard: slots are
  typed, enumerable literals only — never sentence-level generation).
- **(vs. the rejected lens):** the rejected design manufactures from numbers and *can* in
  principle cover any state — but only as *shallow manufactured prose* whose depth is capped by
  the realizer and which confabulates at the edges. This design *can't* cover the whole space,
  but everything it covers is *real authored depth a human approved*. It trades coverage-breadth
  for guaranteed-craft-where-covered. Given the meta-learning (manufactured taste is the
  unsolved problem), trading toward authored craft is the defensible bet.

---

## 7. Buildability — finite & shippable, or fig leaf? (honest)

**It is finite and shippable, and the scale is real, not a fig leaf — but the authoring cost is
the honest catch.**

- **Unit:** a beat ≈ 1–4 sentences + signatures + one 256-dim i16 vector (≈512 bytes vector +
  ~200 bytes prose/tags ≈ <1 KB/beat). **One million beats ≈ <1 GB** — trivially shippable as a
  read-only artifact. Storage is a non-issue; we are *vector-storage-bound by nothing*.
- **Authoring is the real cost.** A credible first-NPC corpus: ~8–12 situation cells × 3–6
  variants × ~12-beat scenes ≈ **300–800 authored beats per NPC** for a genuinely alive single
  NPC in its covered territory. That is a TiTS-companion's worth of writing per major NPC —
  large but *known-finite and known-achievable* (TiTS/CoC/LT shipped exactly this scale by hand).
- **LLM-as-build-ingredient makes it tractable without making it a fig leaf:** Opus drafts
  best-of-N, humans curate and approve, the lead writes the load-bearing beats. The shipped
  artifact is *human-approved prose + frozen vectors*, with **no model and no generation at
  runtime** — which is precisely the sanctioned build-time-inference shape, not a smuggled
  runtime LLM.
- **The embedding model** runs once at build over situation-serializations; only quantized i16
  outputs ship. Re-embedding on corpus version bump is a build step, content-addressed.

**Verdict on the fig-leaf test:** the artifact is a concrete, finite, shippable binary that runs
with zero runtime inference; it is buildable *today* at single-NPC scale by the same labor that
built the reference games. The honest catch is **authoring throughput**, not feasibility — the
corpus is real work, and the combinatorial tail is never fully closed (it degrades to authored-
general, logged as coverage holes for the corpus to grow into). That is a true limitation owned
plainly, not relaxed.
