# BDCC2 port re-verification (2026-06-23)

VERIFY-ONLY. No code changed. Evidence below; both sides cited.

## Q1. Did we rip BDCC2's systems with no changes? — NUANCED, NOT verbatim.

The sim files acknowledge their BDCC2 origin in their own headers and the commits say
"ported". But comparing the actual bodies, this is an **adaptation with consistent,
load-bearing changes**, not a thin rename. The reusable *model* (arithmetic, the
decay+stack mood aggregation, the entry/holder split) is carried over near-identically;
the *coupling* (frame-delta ticking, networking, global registries, character
back-pointers, the reaction line-engine) is deleted.

### SimClock vs TimeManager
- `scripts/sim/sim_clock.gd:34` `SECONDS_DAY := 86400` == BDCC2 `TimeManager.gd:4`.
- `full_time()` (sim_clock.gd:60-61) `day*SECONDS_DAY + time_of_day` == BDCC2 `getTimeFull()` (TimeManager.gd:34-35) verbatim.
- Static helpers `day_at`/`seconds_since_day_start`/`advance_full_time` (sim_clock.gd:76-86) == BDCC2 `getDayAt`/`getSecondsSinceDayStart`/`advanceFullTime` (TimeManager.gd:37-45) — identical bodies, renamed.
- DELETED: BDCC2's `_physics_process` frame-delta accrual (TimeManager.gd:12-29), `Network.isServer()` gates, `syncTime`/`Bins` RPC (TimeManager.gd:47-67), `SAVE.loadVar` (TimeManager.gd:75-77). aeriea replaces frame-delta with an explicit `advance(seconds)` (sim_clock.gd:49-56) driven off the seeded action log, and adds a `day_rolled_over` signal. This is the real determinism cut, not cosmetic.

### Memory vs MemorySystem/MemoryHolder/MemoryEntry
- `MemoryHolder.mood_values()` (memory.gd:160-189) is a near-line-for-line port of BDCC2 `calculateMoodValues()` (MemoryHolder.gd:75-107): same reverse iteration ("newest first"), same `theCurrentTime > noEffectsAfter || !mood` skip, same `stackMax` cap, same `progress = remap(secondsPassed,0,totalDuration,0,1)`, same `mult=(1-progress)`, same per-type running `stackMult` multiplier, same `combineWith(mood, mult)`. This is the strongest "copied" finding — the aggregation math is BDCC2's.
- add/expire/count/has helpers (memory.gd:121-228) mirror BDCC2 addMemory/processRare/getMemoryAmount*/hasMemory* (MemoryHolder.gd:23-146).
- GENUINE DIVERGENCE: ranking. BDCC2 `calculateFinalPriority` = progress*priority (OLDER ranks higher, for its "ask about your day" recap). aeriea deliberately inverts to `freshness*priority` (memory.gd:97-102, with an explicit comment explaining the divergence) so a just-happened event outranks a stale one.
- DELETED: `charRef:WeakRef`/`getChar`/`getPawn` back-pointers (MemoryHolder.gd:4-21), `GM.main.timeManager` global (clock is injected per call), `GlobalRegistry.getMemory` (replaced by an owned def table), `Log.Print`, and the entire `getAskDayReactions` RNG/ReactionSystem line engine (MemoryHolder.gd:165-209) — that job moves to aeriea's realizer.

### MoodValues vs MoodValues
- Identical 4-scalar struct + combineWith. ONE rename with meaning: BDCC2 `horny` (MoodValues.gd:6) -> aeriea `lust` (mood_values.gd:26). Otherwise the same.

### Mood vs MoodHandler
- This is the *most* adapted. BDCC2 MoodHandler (MoodHandler.gd) is a stateful node with a decaying temporary bank, a mood-NAME registry (`GlobalRegistry.getMoods`, MoodBase/MoodStage), personality-weighted `affectValue`, and `Network.isServer()` gate. aeriea's `Mood.read()` (mood.gd:37-63) is a single **stateless pure function** that projects (memory MoodValues + affection + lust + annoyance) into aeriea's own continuous `ExprState` (valence/tension/attention/arousal) with hand-authored weights. The mood-name registry, temporary bank, personality math, and networking are all gone. This is genuinely aeriea's own bridge, only the *idea* (aggregate memory+short-term) is shared.

### Verdict Q1
Not "ripped verbatim." It is a faithful **model port with the BDCC2 coupling surgically removed** to satisfy aeriea's determinism/no-global/data-over-code constraints. The math kernels (time arithmetic, mood aggregation) ARE near-verbatim; the architecture around them is rebuilt. The commit messages and file headers are accurate ("ported ... frame-delta cut", "ported from BDCC2").

## Q2. Did we not have an existing text sim system? — We HAD the substrate, and the sandbox USES it.

(a) text_sandbox.gd ROUTES THROUGH the affordance substrate. It does NOT bypass it.
- Loads the affordance kit: `InteractionKit.load_from_file(KIT_PATH)` where KIT_PATH = `res://interaction/sandbox.kit.json` (text_sandbox.gd:21,128).
- Drives the real interpreter: `_interp = InterpScript.new(); _interp.setup(_kit,_host); _interp.step(STEP_DT)` (text_sandbox.gd:133-135, 263). InterpScript = `res://scripts/interaction/interaction_interpreter.gd` (line 22).
- Verb availability + firing go through the substrate's guard layer: `_interp._eval_guard(v.when_guard,...)` (text_sandbox.gd:159) and data-dispatch via `rec["selected"]=verb_name` (line 261), with each verb guarding on `state_enum selected == <name>` (kit lines 250, 288). The host is a headless `ResolvedFrame` shim (text_sandbox.gd:57-77) exactly like tests/interaction_golden_trace_test.gd; it does not hardcode a separate verb engine.
- The verbs, guards, prompts, and effects all live in DATA (sandbox.kit.json), not in the .gd.

(b) Order in git history — the substrate predates the sandbox AND the sim layer:
- Affordance substrate first added: `7343480 feat(interaction): affordance substrate slice 1` — 2026-06-03.
- text_sandbox.gd first appears: 7559478 — 2026-06-14.
- sim layer (sim_clock.gd) first added: `eb0549d` — 2026-06-22.
So aeriea's own richer substrate existed ~3 weeks before the BDCC2 sim port, and the sandbox was built on the substrate first; the BDCC2 sim was layered UNDER it later (memory/mood/relationship history feeding the realizer), not as a replacement for it.

### Verdict Q2
The premise "we bypassed our own substrate" is FALSE. The sandbox runs entirely on the
aeriea interaction substrate (kit JSON + interpreter + guards/effects). The BDCC2-derived
sim (memory/mood/relationship) is wired alongside as the *history/affect* layer
(`MarenHistory`, text_sandbox.gd:24,137,270,275) that the realizer reads — it is not the
interaction engine.

## Q3. Are the actions strictly worse than TiTS / ported from BDCC2? — Verb SET is aeriea-authored data; it is small but NOT a BDCC2 port, and NOT bypassing the substrate.

The actual command verbs in sandbox.kit.json (the NPC, npc_maren):
- greet (kit:249), compliment (kit:258), tease (kit:272), push_away (kit:287),
  offer_gift (kit:297), intimacy_placeholder (kit:319) — 6 NPC command verbs (8 command
  verbs kit-wide incl. valve/lever toggles). `wait`/`leave` is a sandbox-host timeline
  control (text_sandbox.gd:225), not a kit verb.
- These are guarded, data-defined verbs (guards reference rapport, body_is_adult, etc. —
  kit:280-282, 320), expressed in the SAME substrate language as the physical-object
  verbs (grab/drop/throw/place/toggle). So the substrate is demonstrably capable of
  richer expression (state_cmp on `rapport`, `fill`, dynamic prompts, multi-clause
  `all`/`not` guards); the menu is small because only ~6 NPC verbs have been *authored*,
  not because the substrate is limited or a hardcoded menu is in use.

BDCC2 comparison: BDCC2's social action set (Game/PawnAI/SubInteractions/) is
Chat, Compliment, Hug, Insult, AskDay, OfferSex. aeriea's set (greet/compliment/tease/
push_away/offer_gift/intimacy_placeholder) OVERLAPS conceptually (compliment; insult≈tease/
push_away; OfferSex≈intimacy_placeholder) but is NOT a port: BDCC2 SubInteractions are
imperative .gd classes; aeriea verbs are JSON data with guards+effects. No BDCC2
SubInteraction code is reused for the verbs.

### Verdict Q3
The action *count* is small (≈5-6 authored verbs) — fair to call it thin versus TiTS's
breadth. But it is NOT a BDCC2 port, and NOT a hardcoded menu bypassing the substrate:
the verbs are authored as affordance data and fire through the interpreter's guard/effect
path. The limitation is "few verbs authored so far," not "wrong/copied architecture."

## Bottom line
- Q1: Model ported (math kernels near-verbatim, esp. mood aggregation), coupling removed; honest adaptation, not a verbatim rip. Mood bridge is genuinely aeriea's own.
- Q2: False premise — the substrate predates and powers the sandbox; the BDCC2 sim is the history/affect layer beneath it, not a replacement.
- Q3: Verb set is small and aeriea-authored data (not BDCC2 code), running through the substrate; "strictly worse than TiTS" is fair on breadth only.
