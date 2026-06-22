# Diagnosis — Text Sandbox + NPC Sim ("text sandbox + NPC sim")

Scope: `scripts/text_sandbox.gd`, `scenes/text_sandbox.tscn`, `scripts/sim/*`
(SimClock/Memory/Relationship/Mood/MoodValues/MemoryDefs), `scripts/text/npc_realizer.gd`,
`scripts/text/maren_history.gd`, kit `interaction/sandbox.kit.json`.

Method: read all source; ran the realizer + history headlessly (`xvfb-run godot4 --headless
--script`, seed `0xA371EA`) to capture **actual** output and **actual** face-channel numbers.
Every claim below cites `file:line` or names the run.

Tags: **redesign** = the *model* is wrong (fix the design); **fix** = local defect, model OK;
**want** = missing capability, not a defect.

---

## A. Interaction shape — CONFIRMED: numbered "type a number" menu + a "wait" advance-time option

- **Numbered menu.** `_present_menu()` prints `"  [b]%d[/b]) %s"` per available verb
  (`text_sandbox.gd:181`) plus a literal `"  [b]wait[/b]) Step away and come back later
  (advance time)"` line (`:182`). Placeholder text: *"Type the number (or name) of an action
  and press Enter…"* (`:113`).
- **Input handling.** `_on_text_submitted` → `_submit` (`:213`). `_resolve_choice` parses a
  1-based menu index via `line.is_valid_int()` → `_menu[idx]` (`:240-245`), else matches a
  lowercased verb name (`:246-250`). So the interaction *is* "type a number (or verb name)."
- **Wait / advance-time.** `_submit` special-cases `line.to_lower() == "wait" or "leave"`
  → `_leave_and_return()` (`:225-228`), which calls `_history.advance(LEAVE_SECONDS)` with
  `LEAVE_SECONDS = 9*3600` (`:46, :190`) — one workday of decay.

> **redesign** — A numbered verb menu over a fixed 5-verb table (greet/compliment/tease/
> push_away/offer_gift) is a *choose-from-a-list* affordance, not the "text-based systemic
> gameplay" the project pivoted to (per the recent `docs(todo)` handoff commit). It is fine as
> a driver harness for the realizer/sim, but as *gameplay* it is the wrong model: the verbs are
> a closed enum, not a generative/parseable surface, and the only systemic lever ("wait")
> advances a clock the player can't otherwise act within. Good requires: an open verb surface
> (parse or compose verbs) and world-state the verbs operate on beyond one NPC's 4 scalars.

---

## B. THE CANONICAL CASE — "greeting increases arousal" — CONFIRMED, with the literal wiring

This is real. Greeting Maren **measurably raises the `arousal` face channel** that the sandbox
prints to the player. The full path:

1. **Kit:** `greet` verb does `add_fill mood +0.05` on the NPC record + `set_state
   last_social_act=greeted` (`sandbox.kit.json`, greet verb). dt=1 so this is a flat +0.05 to the
   substrate `mood` field (`text_sandbox.gd:29, :263`).
2. **History record:** `_fire` → `_history.record_event("greet", after)` (`text_sandbox.gd:270`).
   `record_event` adds a `greeted` **memory** and `rel.add_affection(PLAYER, MAREN, 0.05)`
   (`maren_history.gd:63-73`; `EVENT_AFFECTION["greet"] = 0.05` at `:45`).
3. **The `greeted` memory carries a mood vector** `MoodValues(0.10, -0.02, 0.0, 0.0)` —
   i.e. **mood = +0.10**, anger −0.02 (`memory_defs.gd:30`; field order mood/anger/lust/dominance
   per `mood_values.gd:24-27`).
4. **The Mood projection feeds that mood (and affection) straight into AROUSAL:**
   `arousal_raw := maxf(0.0, mv.mood) * 0.6 + lust * 0.5 + maxf(0.0, affection) * 0.15 +
   mv.lust * 0.4` (`mood.gd:59`). With mv.mood≈+0.10 and affection=+0.05 →
   `0.10*0.6 + 0.05*0.15 ≈ 0.068`.
5. **The sandbox surfaces that number to the player labeled "arousal":**
   `"(face: valence %+.2f, tension %.2f, attention %.2f, arousal %.2f%s)"` (`text_sandbox.gd:293`),
   fed by `_history.current_expr()` → `Mood.read(...)` (`maren_history.gd:92-98`).

**Measured (run, seed 0xA371EA):** baseline face arousal `0.000`; **after a single greet →
arousal `0.068`** ("FACE after greet -> … AROUSAL 0.068"). Greeting an NPC you just met
raises her arousal. Confirmed end-to-end, not inferred.

Why it's the "wrong model of a person":
- The arousal channel **conflates three different things** through one additive sum
  (`mood.gd:59`): general positive *mood* (mv.mood), long-term *affection*, AND **NSFW lust**
  (`lust * 0.5 + mv.lust * 0.4`). ExprState itself documents this channel as *"general emotional
  arousal, **NOT the NSFW arousal axis**"* (`expr_state.gd:20`) — yet `Mood.read` pours lust into
  it. So "arousal" simultaneously means "animation/intensity of the face" and "horniness," and a
  bare greeting nudges the same dial that lust does.
- The player-facing label is the bare word **"arousal"** (`text_sandbox.gd:293`). Even granting
  the "emotional-intensity" reading, surfacing a person's "arousal" rising when you say hello
  reads as modeling a person as a hydraulic stimulus-response bank.

> **redesign** — the affect model collapses mood, affection, and NSFW lust onto a single
> "arousal" output, against ExprState's own stated channel semantics. Splitting "emotional
> intensity/animation" from a separate, explicitly-gated NSFW lust axis is a *model* change, not
> a constant tweak. The throughline is right ("Mood output IS an ExprState"), but THIS mapping
> models a person as a stimulus→arousal pump. Good requires: arousal-as-animation decoupled from
> lust; lust on its own axis behind the SFW/NSFW toggle; and a player-facing read that doesn't
> announce "arousal +" for saying hi.
> **fix** (cheaper, partial) — at minimum drop `lust`/`mv.lust` out of `mood.gd:59` and rename
> the surfaced channel from "arousal" to "intensity"/"animation" in `text_sandbox.gd:293`; this
> removes the literal greet→(NSFW-reading) wiring without the full model split.

---

## C. Realizer prose quality — GOOD (show-not-tell, not mad-libs), with a real repetition ceiling

Assessed from **actual output** (run above), not the docstring.

- **It is genuinely show-not-tell.** Output renders behaviour, never labels:
  - initial: *"She stands a step back, hands clasped in front of her, offering you a level,
    measured look."*
  - greet outcome: *"You greet her. Something at the corner of her mouth lifts; she doesn't quite
    hide it."*
  - warm state: *"She leans in a little, a quick smile breaking before she can school it, fingers
    worrying the hem of her sleeve. Color is still high on her cheeks…"*
  The taboo on naming interior state ("mood"/"rapport"/"trust") is actually honored across all
  helpers (`npc_realizer.gd:126-246`). Banded on **combinations** (mood × rapport), not 1:1
  per-verb templates (`_present_tell` `:126-157`, `_reaction_for` `:209-237`). This is a real cut
  above slot mad-libs.
- **Repetition defect (measured).** compliment #2 and #3 produced **byte-identical** prose
  (*"Her eyes come up to yours and hold there a beat longer than before; one shoulder drops out of
  its guard."*) because both land in the same `rapport_after >= 0.45` band of `_reaction_for`
  (`:227-228`) and the seeded `_rng` is **never used** to vary phrasing — `_join`/`_terminate`
  ignore it (`:254-272`), and the public fns take `_rng` only to discard it (`:63, :95`). So
  repeated same-band acts read as copy-paste.

> **fix** — wire the already-threaded seeded `_rng` into phrasing selection so same-band repeats
> vary; and/or band on a *count*/novelty signal so the 2nd compliment differs from the 1st. The
> seam is correct; the floor just doesn't use its own variation knob.
> **want** — the file's own header is honest (`:42-49`): four scalars cap the depth ("Depth is
> upstream"). Richer prose needs richer *state* (interiority/history-with-texture), per
> `docs/decisions/prose-generation.md`. Not a defect; a known ceiling.

---

## D. Mood / relationship model — SALVAGEABLE (sound mechanics) but mis-projected (see B)

The **mechanics** are well-built and tested:
- SimClock + decay-on-advance is deterministic and time-driven, not frame-driven
  (`relationship.gd:171-179`, `memory.gd:140-154`); decay tuning is data (`relationship.gd:36-46`).
- Memory aggregation is decay-weighted + stack-weighted with diminishing returns
  (`memory.gd:160-189`); aeriea correctly diverges from BDCC2 to rank by *freshness* not age
  (`memory.gd:93-102`).
- Affection saturates (asymmetric diminishing returns, `relationship.gd:110-117`); memory defs
  are data with sensible durations (`memory_defs.gd:27-47`).
- Memory callbacks surface as dialogue, not narration ("You keep saying that," confirmed in run)
  (`maren_history.gd:104-126`).

So the model is **salvageable, not wrong-by-design** — EXCEPT the projection in §B. The defect is
concentrated in the single `Mood.read` arousal line and its bare-"arousal" surfacing, not in the
memory/relationship substrate.

Secondary model notes:
- **`lust` is dead input today.** `Mood.read` reads `lust`/`mv.lust` (`mood.gd:59`) but nothing in
  the Maren path ever calls `add_lust` and no memory def sets a nonzero `lust` vector
  (`memory_defs.gd:30-46` all have lust 0.0 except complimented/teased_warm/given_gift carry small
  +lust, e.g. complimented `MoodValues(0.35,-0.10,0.05,0.0)` at `:33`). So **complimenting also
  feeds `mv.lust` → arousal** — same class of defect as greet, slightly larger. (fix: same as B.)
- **`emphasis` mismatch (fix, latent).** `maren_history._emphasis_for` matches
  `"complimented"/"teased"/"pushed_away"/"rebuffed"` (`maren_history.gd:148-156`), but the
  sandbox passes `last_social_act` from the NPC record where the kit sets it to the **same**
  tokens (`greeted/complimented/teased/pushed_away/given_gift`) — `given_gift` and `greeted` have
  **no** emphasis branch, and `"rebuffed"` is dead (never produced). Minor; emphasis just stays "".

---

## Summary table

| # | Tag | Defect | Evidence locus |
|---|-----|--------|----------------|
| A | redesign | Numbered fixed-5-verb menu is choose-from-list, not systemic text gameplay | `text_sandbox.gd:181-182, 240-250` |
| B | **redesign** | **greet → arousal**: greet's memory mood(+0.10)+affection(+0.05) feed the arousal face channel; conflates mood/affection/**NSFW lust** in one sum, against ExprState's own "NOT the NSFW arousal axis" | `mood.gd:59` · `memory_defs.gd:30` · `maren_history.gd:63-73` · surfaced `text_sandbox.gd:293`; **measured 0.000→0.068** |
| B' | fix | Cheap mitigation: drop lust from `mood.gd:59`, rename surfaced "arousal"→"intensity" | `mood.gd:59`, `text_sandbox.gd:293` |
| C | fix | Same-band repeats produce byte-identical prose; seeded `_rng` accepted but never used | `npc_realizer.gd:63,95,227-228,254-272`; measured compliment#2==#3 |
| C' | want | Prose depth capped at 4 scalars (the file admits it) — needs richer state, not richer lens | `npc_realizer.gd:42-49`; `docs/decisions/prose-generation.md` |
| D | (assess) | Mood/relationship substrate is sound + deterministic + tested — SALVAGEABLE; the wrongness is the projection (B), not the model | `relationship.gd`, `memory.gd`, `sim_clock.gd` |
| D1 | fix | `lust` axis fed into arousal but only ever set by memory defs; compliment also bumps arousal via mv.lust | `memory_defs.gd:33,36,45` · `mood.gd:59` |
| D2 | fix | `_emphasis_for` has dead `"rebuffed"` branch + no branch for `given_gift`/`greeted` tokens the kit emits | `maren_history.gd:148-156` vs kit `set_state last_social_act` |

**Bottom line:** the substrate (memory/relationship/clock) and the realizer floor are both
genuinely good and well-tested. The one **wrong-model** defect is the affect *projection*
(`Mood.read`): it routes a greeting (and a compliment) into an "arousal" channel that also carries
NSFW lust and is shown to the player as bare "arousal." That is **redesign** (split the axes,
re-label), with a cheap **fix** fallback. Everything else is local **fix**/**want**.
