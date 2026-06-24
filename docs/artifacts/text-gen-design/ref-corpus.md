# Reference corpus: SillyTavern RP chat logs

Ground-truth inspection of `/mnt/ssd/ai/SillyTavern/data/default-user/chats/` (1.3 GB).
Method: full structural enumeration + statistics over a random 400-file sample
(+ targeted SFW-filtered prose sampling). Numbers below are measured, not guessed;
corpus-wide figures are extrapolated from the sample (×33.6) and labelled as such.

## 1. Structure & format

- **5,461 character folders**, **13,433 `.jsonl` files** total. No other file types.
  One folder per character/card; each `.jsonl` is one chat session (or a branch).
- One folder dominates: **`The Scenario/` = 3,046 files (23% of all files), 518 MB (40% of all bytes)** —
  a single recurring scenario with thousands of chats/branches. The corpus is heavily
  skewed toward a handful of characters; the long tail is mostly tiny stub chats.
- **Line schema** (SillyTavern standard):
  - Line 1 = header: `{user_name, character_name, create_date, chat_metadata}`.
  - Lines 2..N = messages: `{name, is_user, is_system, send_date, mes, extra, ...}`.
    Assistant turns additionally carry `gen_started`, `gen_finished`, `swipe_id`,
    **`swipes`** (array of alternate regenerations), `swipe_info`, and
    `extra.{api, model, reasoning, reasoning_duration}`.
  - `mes` holds the actual prose. `is_user` distinguishes human vs model. System lines are negligible.

**Metadata vs prose / duplication.** The "most of it is metadata/duplicated" caveat is
**confirmed and the dominant factor is `swipes`**: alternate regenerations of the same
turn are stored in full. Measured, **alt-swipe text = ~60% of all generated prose bytes** —
i.e. only ~40% of the stored model text is the *chosen* canonical line; the rest is
discarded re-rolls. Add timestamps, model strings, avatar paths, swipe_info, and `.import`-style
bookkeeping and the "real unique canonical prose" is a minority of the 1.3 GB.

## 2. Volume of real prose (extrapolated, chosen-swipe only)

- **~0.5M messages** total (~235k human / ~252k model).
- **~54M model words** (canonical swipe only; counting all swipes would roughly double it).
- **~2.4M human words** — a **~22:1 asst:human word ratio**. The human steers in short
  directives; the model carries essentially all the prose. This shapes usability (below).
- After de-duplicating swipes and the `The Scenario` mega-character skew, the genuinely
  *distinct* high-quality prose is realistically **single-digit millions of words**, not 54M.

## 3. Models recorded (`extra.model`, by asst-msg frequency in sample)

Mostly mid/small models, consistent with the user's "small model" framing:

```
gemini-3-flash-preview, gemini-2.5-flash(-preview/-lite) family   <- bulk
Meta-Llama-3.3-70B-Instruct
gemma-4-26B-A4B-it-...gguf  /  gemma-4-26B_q4_0-it.gguf   <- the "~26B/3.8B-active gemma"
gemini-2.5-pro, gemini-3-pro-preview, grok-3-mini-beta   <- minority
older: microsoft/WizardLM-2-8x22B (togetherai)
```

The dominant `The Scenario` folder is largely **gemma-4-26B** and `gemini-3-flash` — so the
single best-represented prose voice is in fact a small local gemma, matching the brief.

## 4. Quality sample (verbatim) & the aliveness bar

A strong gemma-4-26B passage (`The Scenario`) — note concrete sensory grounding, restraint,
and subtext rather than narration-of-feelings:

> The scent of red wine and seared beef hangs thick. The warmth from the candles flickers
> across the table, casting long shadows against the white linen. Every scrape of a fork
> against ceramic sounds unnaturally loud in the brief pauses of your conversation.
> Maya stays tucked against your side. ... Christine rests her back against the velvet chair.
> Her wine glass sits empty, though she stares at it with intent. She watches the movement of
> your jaw and the way Maya's eyes track every bite. "The service here is slow tonight," Christine
> says, her voice a smooth, low rasp. ... "But I think the wait is worth it."

A mediocre/generic Llama-3.3-70B passage — competent but clichéd, "aroused-NPC boilerplate,"
list-of-body-parts with weak specificity and the stock asterisk-action style:

> *She shakes her head, her dark brown hair rustling against your chest* "No, ... I want to...
> I need to..." *Her voice is barely above a whisper...* "My body is aching for your touch...
> I want you to take me, to make me feel like I'm alive..." ... "Make me feel something... please..."

A gemini-2.5-flash multi-character beat — decent voice differentiation (Francine = competitive,
Muffy = bubbly/childish), tracks the user's prior compliment:

> Francine: ... "Hottest, huh? And you think we're the hottest? Out of everyone?!" ...
> Muffy: ... "Hottest?! Oh my goodness, Francine, did you hear that?! We're the *hottest*!" ...
> "But you know, talking about our... our anatomy like that was still uncalled for!"

Human turns are terse directives (interaction shape):

> "I take off my jacket and position it." · "Huh? Unwillingness? Where?" · "*A couple months pass.*"

**What makes them feel alive (or not).** The good turns (top-quartile gemma, gemini-pro):
concrete physical detail tied to *this* scene, characters react to the specific prior line,
distinct per-character voice and subtext, ambient sensory framing, restraint (imply, don't
state). The weak turns (a lot of the Llama/flash-lite mass): generic arousal/emotion
boilerplate, body-part inventories, asterisk-action tics, weak history-tracking, interchangeable
voice. **The bar this corpus sets is therefore not uniform** — the honest target is
*"at least as good as a strong gemma-4-26B turn: sensory-grounded, voice-distinct, reactive to
the immediate beat,"* not the median line, much of which is filler we should beat easily.

## 5. Usability: benchmark vs build-time source material

**As a BENCHMARK: high value, use it.** It gives a concrete, achievable prose bar from a small
model — "do at least this well" — and a clear failure taxonomy (boilerplate, body-part lists,
asterisk tics, no history tracking) to test our authored output against. Recommended primary use.

**As BUILD-TIME SOURCE MATERIAL: usable but heavily caveated — curate, don't bulk-mine.**
Obstacles, in priority order:

1. **Content/ethics is the blocker, not a footnote.** Folder/file names and at least one sampled
   passage involve **minors in sexual/abusive scenarios** (e.g. `KiddyHole...`, `A Child's Time`,
   the distressed-child `The Scenario` beat). This material must be **hard-excluded** from any
   mined library; any curation pass needs an explicit, conservative content gate up front, and the
   human-signs-every-line rule must be enforced without exception.
2. **Privacy.** These are the user's personal chats. Curated output should be *transformed* beats
   (paraphrased/abstracted craft patterns), never verbatim lifts, and never leave the user's control.
3. **Quality variance is large.** Only a top slice (strong gemma/gemini-pro turns) clears the bar;
   most lines are filler. Mining requires a quality filter, not bulk ingestion.
4. **Scenario/character coupling.** Prose is bound to specific cards/scenarios unrelated to aeriea.
   What transfers is *technique* (sensory grounding, voice, reactive beats), not content — so the
   useful product is an **abstracted craft/pattern corpus**, not transplantable passages.
5. **Dedup needed.** ~60% of stored model text is alt-swipes; `The Scenario` is 40% of bytes from
   one character. De-swipe and de-skew before any pass.

**Verdict.** Primarily a **benchmark** — that use is clean, high-signal, and immediately actionable.
Secondarily, Opus *could* at build time mine the top-quality, content-safe slice into
**abstracted authored beats / craft patterns** for a hand-verified library — but only with a strict
upfront content gate (excluding the minor/abuse material), transformation-not-extraction, a quality
filter, and the human-signs-every-line invariant. It is **more valuable as a benchmark than as a
source corpus**, and the source-material path is conditional on the safety/curation discipline above.
