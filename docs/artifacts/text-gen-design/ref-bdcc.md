# Reference: How BDCC produces dialogue/prose (ground truth)

Repo: `/home/me/git/BDCC` (Godot 3.x GDScript). All claims below are read from source, file:line cited.
Contrast repo: `/home/me/git/pterror/BDCC2` (Godot 4, a rewrite). Verdict up front: **BDCC is the substantial authored corpus; BDCC2 is the engine/grammar with almost no corpus** (37 `say()` calls and ~822 lines of reaction snippets total vs BDCC's 56,370 `say()` calls). The user's framing is correct.

---

## 1. Authoring mechanism — TWO distinct systems

BDCC runs **two parallel text systems**, and the distinction is the most important takeaway.

### (A) Hand-authored scene scripts — the bulk of the prose

Every scene is a GDScript class extending `SceneBase` (`Scenes/SceneBase.gd`). It is a **state machine**, not a dialogue tree:

- `_run()` (`SceneBase.gd:24`) emits text for the current `state` and registers buttons.
- `_react(action, args)` (`SceneBase.gd:114`) handles a button press, mutates game/world state, then calls `setState(newState)` which re-enters `_run()`.
- Text is emitted imperatively via `say()/sayn()/saynn()` (`SceneBase.gd:125-134`) → `GM.ui.say()` (`Game/UI/GameUI.gd:106`). Buttons via `addButton(text, tooltip, method, args)` (`SceneBase.gd:211`); `addButtonWithChecks` (`SceneBase.gd:231`) auto-disables + annotates a button when a requirement fails.

Canonical tiny example — `Scenes/RestingInCellScene.gd` (whole file, 88 lines): `_run()` branches on `state in {"", "rested", "slept"}`, each branch `saynn(...)`s prose and adds buttons; `_react()` advances time / starts a new day / fires triggers, then `setState(...)`.

A line is chosen at runtime purely by **which `if(state==...)` branch the imperative code walks**, gated by arbitrary GDScript `if`s over game state. There is no data format for scenes — they are code. This is the same "simulation-underneath, authored surface on top" pattern, but the surface is straight-line script.

**Inline markup** inside say-strings is resolved by `Util/SayParser.gd` (`processString`, `SayParser.gd:119`):
- `[say=alexrynard]...[/say]` → looks up the character, prefixes `[b]Name[/b]:` if speaker-names option on, wraps in the character's chat color, and runs `formatSay` (`Game/BaseCharacter.gd:499`). `[sayMale]/[sayFemale]/[sayAndro]/[sayOther]` for unnamed speakers (`SayParser.gd:155-178`).
- `formatSay` also runs registered **SpeechModifiers** (`BaseCharacter.gd:504`): state-driven text mutation. Only one ships — `GaggedSpeech` (`Game/SpeechModifiers/GaggedSpeech.gd`) muffles a gagged speaker's line (and appends the real line in parens if the PC has the `BDSMGagTalk` perk). This is a clean extension point that's barely used.

### (B) ModularDialogue — parametric, personality/state-driven barks

`Game/ModularDialogue/` (24 files) is a TiTS-style combinatorial generator used for **NPC barks** (fights, guards, prostitution, punishment, casual talk). `ModularDialogue.generate(formID, args)` (`Game/ModularDialogue/ModularDialogue.gd:57`) composes a line from three registries:

- **Forms** (`FormBanks/Default.gd`): ~100 slot IDs, each a default line + required arg roles + which role is `main`/`dirTo`, e.g. `"GuardFrisk": form("Don't move while I do this.", {inmate=CHAR, guard=CHAR}, "guard", "inmate")`.
- **Fillers** (`Fillers/Mean.gd`, `Dommy.gd`, `ShySubby.gd`, ...): personality-keyed line banks. A filler declares `getFormIDs()`, a `canBeUsed()` gate, a `priority`/`weight`, and returns an **array of candidate lines** per form. `Mean.gd:107` gates on `personality.getStat(PersonalityStat.Mean) >= 0.4`. Selection: `generate()` collects all usable fillers, keeps the highest `priority` tier, then `RNG.pickWeighted` (`ModularDialogue.gd:78-99`).
- **Adders** (`Adders/FightRememberAdder.gd`, `Pregnant.gd`, `Impregnated.gd`, ...): optional memory-triggered prefix/suffix injected with a chance and a **5-15-call cooldown** (`ModularDialogue.gd:104-134`) so a callback doesn't repeat every line.

The composed string is then run through `DialogueParser` (`Parser/DialogueParser.gd`) — a small lexer/parser for `[[...]]` tags supporting **synonym pools, alternation, and weighted random**: `[[SLUT]]`/`[[SLUTS]]`/`[[UGH]]` resolve to a random member of word lists (`ModularDialogue.gd:12-35`), `[[mean|kind]]`, `C_`-prefixed = capitalize first letter (`DialogueParser.gd:216`). Personality tags (`mean`/`dommy`/`subby`/`kind`) come from `getModularDialogueTags()` (`BaseCharacter.gd:3381`), which only exposes the personality axes whose magnitude clears a threshold, sorted strongest-first — so the same `[[mean=...;dommy=...]]` slot picks the branch matching that NPC's dominant trait. Pronoun grammar `{inmate.he}`, `{target.verb('want')}`, `{target.isAre}` resolves per-character via `formatSay`/pronoun helpers (`BaseCharacter.gd:510+`).

---

## 2. Volume & authoring style

- **414,551 lines of GDScript** total; **436 `*Scene.gd` files** (168k lines of scene scripts alone); biggest single scene `Modules/JackiModule/Ch2/jackiCh2s2GymScene.gd` = 4,506 lines.
- **56,370 `say()/sayn()/saynn()` calls** across the codebase — i.e. tens of thousands of authored prose/dialogue lines.
- ModularDialogue holds ~10k quoted strings across forms/fillers — and that's just the parametric bark layer.
- Style: overwhelmingly **deeply hand-authored per-scene prose** (system A), with system B providing parametric *filler* for generic repeatable NPC interactions. Not thin; not primarily combinatorial. The combinatorial layer exists but is the minority.

## 3. What makes it feel alive — state→text, concretely

Three real mechanisms, all in the bark layer (system A reads the same state ad-hoc via `if`s):

- **Relationship-conditioned branching.** `Mean.gd:162` `AttackReact` reads `RS.getAffection(attacker, reacter)` and `RS.getLust(...)` and returns *entirely different line banks*: `affection>0.1` → hurt/betrayed ("I thought we were something."); `affection<0 && lust>=0.9` → hate-attraction ("You piss me off, sweetheart, I hate you so much."); `affection<=-0.4` → pure hostility. Same form ID, same trigger, three readings as the relationship changes.
- **Episodic memory via a world-history event log.** `Game/WorldHistory/WorldHistory.gd` records timestamped events (`addEvent(eventID, whoID, byWhoID, args)` with auto day/time), queryable by `queryHappened(eventID, conditions)` with conditions `Who/Target/Today/Yesterday/MinDaysAgo/MaxDaysAgo/ArgTrue/Not` (`WorldHistory.gd:32-72`); history auto-purges after 7 days (`getKeepDaysOfHistory`). `Adders/FightRememberAdder.gd:18` queries `WonFight` where the NPC beat the PC 1-3 days ago and, if true, prepends "Wait, didn't I beat you up the other day? You want more?" to whatever the base line was. Pregnancy/impregnation adders work the same way.
- **State-driven speech mutation** (`SpeechModifierBase` → `GaggedSpeech`): the *delivery* of any line changes with the speaker's body state.

So the same `GuardCaughtOffLimits` form reads as a flat insult normally, but becomes a callback to a remembered beating if one happened this week, and is delivered muffled if the speaker is gagged — all without the author of the line knowing about those conditions.

## 4. Verbatim quality samples

Authored scene prose (`Modules/ArticaModule/c0Shy/articaS6CanteenTalkScene.gd`):
> "Not much has happened.. The fluff is still quite shy in your presence, avoiding eye contact and just staring at her tray."
> "She seems to be.. under the table? Well, her head is. Artica is still sitting on the bench, just bending very low, her hands seem to be doing something with her hind paws."

Scripted multi-character scene with `[say=]` markup (`Modules/AlexRynardModule/Ch2/AlexCh2s2BackstoryScene.gd`):
> "Alex leans back, a quiet metal clang can be heard when he rests against the stiff bench." → `[say=alexrynard]Well.. I was young. Very-very young.[/say]` → "He starts telling you his story.. and you can't help but to get immersed into it.."

Parametric bark, relationship-gated (`Fillers/Mean.gd`, `AttackReact`, affection<0 & high lust branch):
> "You piss me off, sweetheart, I hate you so much." / "Damn you. Go ahead and fuck me up, cutie."

Craft level: competent, voice-consistent, character-aware functional prose. Not literary, but it reads like a person wrote each line for a specific situation — which, for system A, they did.

## 5. Reusable structural ideas (for a deterministic, no-runtime-LLM authored-prose architecture)

Top picks, in priority order:

1. **Form / Filler / Adder three-layer composition (the strongest idea).** Separate (a) the *situation slot* (form ID + role signature) from (b) *interchangeable line banks gated by character/relationship state* (fillers, with priority tiers + weights so a more-specific filler shadows the generic one) from (c) *optional context injections* (adders, with chance + cooldown). This cleanly decouples "what beat is happening" from "who is speaking and how" from "what they happen to remember right now." It is fully deterministic given seeded RNG (`RNG.pickWeighted`), caches/replays, and the line corpus is pure data. This maps directly onto a seeded-sim, authored-selection design.

2. **A queryable, auto-decaying world-history event log as the memory substrate, decoupled from text.** `WorldHistory` is ~100 lines and the text layer reads it through a tiny condition DSL (`Who/Target/MinDaysAgo/Not/ArgTrue`). Authors write a callback line + a declarative query; they never touch sim internals. The 7-day auto-purge keeps "what's salient" bounded. This is the single highest-leverage "feel alive" primitive and it's almost free.

3. **Priority-tiered, weighted selection with cooldowns instead of flat random.** The selection rule — keep only the highest-priority applicable bank, weight within it, and put memory-callbacks on a per-callback cooldown — is what prevents both "always the generic line" and "the same clever callback every turn." Worth copying as the default selection policy, not just `pick_random`.

Secondary, also worth carrying:
- **Inline grammar layer separate from selection**: `[[synonym|alternation]]` pools + `{char.pronoun}`/`{char.verb('x')}` resolution as a post-pass (`DialogueParser`) means authored lines stay terse and reusable across genders/characters without per-line branching. Deterministic, data-pure.
- **SpeechModifier post-pass**: delivery-state transforms (gagged/drunk/etc.) applied to *any* line after selection — a registered, ordered transform chain — so body/affect state colors all text without touching the corpus.
- **`addButtonWithChecks`**: choices that auto-disable and self-explain *why* they're unavailable (showing the requirement) rather than hiding — good UX pattern for an authored-choice surface.

What NOT to copy: system A (per-scene imperative GDScript with `if(state==...)` ladders) is the bulk of BDCC's content but is exactly the "code, not data" seam to avoid — it doesn't cache/diff/replay/transport and couples prose to control flow. The *lesson* from it is volume + per-situation specificity; the *form* to adopt is system B's data-driven composition. The ideal target is "system B's data/selection model carrying system A's authored density."

---

## 6. BDCC2 contrast — confirms "BDCC2 barely has dialogue"

`/home/me/git/pterror/BDCC2` (Godot 4 rewrite, 1,029 `.gd` files) is an **engine/animation/movement/combat rewrite with the text corpus stripped out**:

- **37 total `say()` calls** in the entire repo (vs 56,370 in BDCC).
- It *did* port the ModularDialogue grammar — but externalized into a `.txt` DSL (`Reactions/Main/*.txt`) using `def`/`fill name simple`/`<...>` blocks. Example `Reactions/Main/Insults.txt`: `def Insult / fill Insult simple / < You are stupid, you know that? / I'd rather talk to a wall than you. >`. `Memories.txt` uses `{target.name}% MemoryRecently%` interpolation — same grammar family as system B.
- But the **entire reaction corpus is ~822 lines across 10 files** (`BasicReactions 239, Sex 217, Introduction 105, ...`). There are no authored scenes at all — no system-A equivalent.
- It has a `Game/PawnAI/Mood/` affect engine (`MoodHandler`, `MoodEffects`) — this is the "affect/mood engine" a prior effort imported. That engine is real, but it has almost nothing to *say*.

So: **BDCC2 = the grammar + an affect engine + a near-empty corpus. BDCC = a small parametric bark engine + a very large hand-authored corpus.** For text-generation *design inspiration*, BDCC's authored density and its Form/Filler/Adder + WorldHistory composition are the asset; BDCC2 contributes the externalized-data DSL idea and the mood engine, but is not a source of authored text.
