# Prior Art: Corruption of Champions (CoC)

Status: studied 2026-06-22 from full clone at `~/git/coc` (Fenoxo/Source, commit `cde26cd`). ActionScript 3 / Flash. ~154 `.as` files, ~31 MB.

Scope: The OG Fenoxo deep-body transformation/NSFW text game — direct ancestor of TiTS and the whole Fenoxo lineage, and a cousin to Lilith's Throne. Studied as PRIOR ART for aeriea's body/transformation/tag model and prose-generation thread. Goal is to LEARN patterns, NOT adopt code. AS3/Flash is a dead platform; treat every implementation detail as a cautionary or instructive artifact, never a template.

---

## 1. Character creation / customization

`charCreation.as` (2330 lines). Creation is a linear interview, not a stat-allocation UI: name → gender/genitalia choice → **history/background perk** (Alchemist / Fighter / Healer / Religious / Scholar / Slacker / Smith / Slut / Whore) → starting stats. Each history is a one-paragraph authored vignette ending in "Is this your history?" and grants a named perk (`charCreation.as:602-674`): e.g. "History: Whore" → +15% tease damage, "History: Slut" → higher penetration tolerance.

- The depth at creation is shallow; the *real* customization happens through play via transformation items. Creation just sets a seed personality + a perk.
- Stats are a flat 6-axis block on `creature`: `str tou spe inte lib sens cor` (corruption is the moral/transformation axis), plus `lust`, `fatigue`, `XP/level`, `perkPoints` (`creature.as:78-96`).

Learn: history-as-authored-vignette giving a mechanical perk is a clean, low-friction way to fuse narrative identity with a gameplay modifier. Avoid: there's no structured creation data model — it's event-number dispatch (`doCreation(eventNo)` for `10000..10999`), so the "creator" is unre-usable control flow, not data.

## 2. Body / transformation / tag system — the core relevance

The body lives entirely on one fat class, `classes/creature.as` (3839 lines), shared by player and every NPC/monster. The model is the standout takeaway and the standout warning at once.

**Data model = numeric stats + integer-coded "type" enums + sub-part arrays.** Examples:
- Scalar dimensions: `femininity:Number=50`, `tallness`, `hairLength`, `clitLength`, `ballSize`, `hipRating`, `buttRating`.
- Discriminated part types are *bare integers with a comment legend*, e.g. `cockClass.cockType` 0=human 1=horse 2=dog 3=demon … 10=displacer (`classes/cockClass.as:14-27`); `breastRowClass` cup size 0=manchest…13=beachball (`classes/breastRowClass.as:18-33`); `vaginalLooseness` 0=virgin…5=monstrous (`classes/vaginaClass.as:12-19`).
- **Multi-instance parts as arrays**: `cocks:Array`, `vaginas:Array`, `breastRows:Array` (`creature.as:294-306`). You can have N cocks, N breast rows with `breasts` and `nipplesPerBreast` per row. This is genuinely expressive — the combinatorial body space is huge.

**Behavior lives on the part classes.** `cockClass.growCock()`/`thickenCock()` (`classes/cockClass.as:40-144`) encode growth with diminishing-returns curves and per-type caps (horses grow/shrink slower, huge dicks grow slower). `vaginaClass.capacity()`/`wetnessFactor()` map looseness→numeric capacity (`classes/vaginaClass.as:36-53`). So the part is both data and the rules for mutating itself.

**Transformation = item that calls part mutators + emits prose.** `transform.as` (594 lines) holds the cross-cutting transforms (`cuntChange`, `buttChange`) that auto-stretch and emit graded flavor text per resulting looseness (`transform.as:1-58`). TF *items* in `items.as` just call `player.cocks[0].growCock(4)`, set `cockType`, etc. (`items.as:1886-3130`), interleaved with `outputText`. There is no "transformation" object — a TF is imperative code that mutates the body and narrates.

**"Tags" = the perk + statusAffect + flags triad, all schemaless.**
- `perkClass` / `statusAffectClass` are just `{name:String, value1..value4:Number}` — four untyped numeric slots (`classes/statusAffectClass.as`). Queried by string: `hasPerk("Flexibility")`, `statusAffectv2("Exgartuan")` (`creature.as:1028-1200`).
- A global `var flags = new Array()` (`variables.as:25`) is a giant integer-indexed grab-bag of world/quest state (`flags[273]`, `flags[67]`, …) with magic-number indices.

Learn for aeriea: (a) **parts-as-arrays + per-part type + scalar dimensions** is the right shape for a deep customizable body — aeriea should keep this but make the "type" a named enum/tagset, not a magic int. (b) Putting growth curves *on the part* keeps mutation logic co-located. Avoid: (a) the comment-legend integer enums are a maintenance hazard — meaning lives in a comment, not the type, so any miswrite is silent. (b) The 4-untyped-slot perk/status bag and the magic-index `flags` array are the antithesis of aeriea's data-over-code principle — they're a leaky lowest-common-denominator schema. aeriea should use a typed, named, serializable tag/component model (cf. playmate's `frond`).

## 3. NSFW content engine

Almost entirely **hand-authored branching scenes**, gated by body predicates — NOT a combinatorial act×target×position grammar (that combinatorial approach is more Lilith's Throne's territory). Each scene is a function with dense `if` guards on body state:
- `masturbation.as` (1276 `outputText` calls): the menu offers options conditional on anatomy — `player.hasCock()`, `player.hasVagina()`, `player.tentacleCocks()>0`, `player.canOvipositBee() && lust>=33 && biggestCockArea()>100` (`masturbation.as:5-38`). The *menu* is procedural over body state; the *scene bodies* are authored prose.
- Per-NPC files are enormous authored scene trees: `amily.as` (707 KB, 2588 `outputText` calls), `combat.as` (627 KB), `urta.as`/`urtaQuest.as` quest lines. Content scale comes from sheer authored volume, not generation.

Consent/flow: there is no formal consent model. "Flow" is the event-number state machine — scenes call `doNext()`/`simpleChoices()` to wire the next button. Corruption (`cor`) gates which scenes/options appear, acting as a soft content-intensity dial.

Learn: gating menus by body predicates (`hasCock()`, capacity checks) is exactly how aeriea can make activity surfaces respond to an arbitrary body without authoring every combination. Avoid: monolithic per-NPC authored scene files don't scale to a sandbox and aren't replayable/diffable; and the absence of any structured consent/intensity model is a gap aeriea (NSFW-first with SFW toggle) must fill deliberately.

## 4. Prose / text generation — directly relevant to aeriea's prose thread

Two layers, both worth studying.

**(a) A real templating parser.** `parseText()` in `engineCore.as:339-878`. Tag grammar:
- `[tag]` basic substitution (pronouns, body nouns): `[cock]`, `[he]`, `[His]`, `[butt]`, `[nipples]` — a switch resolves each to a descriptor call (`engineCore.as:700+`).
- `[tag param]` parametrized: `[cockFit 8]` picks the cock that fits a given size and describes it (`engineCore.as:517-538`).
- `[if (a == b) "text"]` and `[if (a == b) "text" else "text"]` conditionals, with `&&`/`||` chaining, parsed recursively (`engineCore.as:362-491`). Note: comments warn "You can't nest if's, and they MUST end with a space" — the regex-based parser is fragile.

**(b) Procedural synonym recombination under the tags.** `descriptors.as` (3555 lines) is the gem. `cockNoun(type)` holds a per-type **synonym pool** and `rand()`-selects one each call: horse-cock → {"flared horse-cock","equine prick","bestial horse-shaft",…} (8 variants); demon → 11 variants; fox vs dog chosen by `dogScore() >= foxScore()` (`descriptors.as:2227-2392`). `cockAdjectives(length,thickness,type)` layers size/texture adjectives. So a single `[cock]` renders differently each time, varied by anatomy, drawn from authored fragment pools. Dozens of these: `vaginaDescript`, `breastDescript`, `assDescript`, `hairDescript`, `nippleDescript`, `cockHead`, per-type `dogDescript`/`dragonDescript`/`anemoneDescript`, etc.

Learn for aeriea's prose thread: this is the canonical **"procedural recombination of authored fragments keyed on body state"** pattern. The two-layer split — a templating parser over a library of state→fragment descriptor functions — is exactly the shape aeriea wants for prose-from-state. The per-type synonym pool keyed on a body discriminant is a clean, scalable variety mechanism.

Avoid: (a) the variant selection uses unseeded `Math.random()` (see §7) — so prose is non-reproducible; aeriea must draw from its seeded timeline so the same state yields the same (or deterministically-varied) prose. (b) Regex-string parsing of the tag grammar is brittle (the no-nesting / trailing-space caveats); aeriea should parse to / store an AST (data-over-code) rather than re-regex source text each render. (c) Synonym pools are inline `if(rando==N)` ladders — data, but expressed as code; lift them to actual data tables.

## 5. Animation / visual

Essentially none relevant. CoC is text-first. Visuals are static per-scene `.png` sprites swapped via `spriteSelect()` (`eventParser.as:9`), authored in `CoC.fla` (Flash). No paperdoll, no procedural character rendering, no hair/cloth physics — the "appearance" is the generated prose block (`creature.long`, `appearance.as`, 836 lines, assembles a full-body description by concatenating descriptor calls). For aeriea's CharacterViewer this offers nothing on rendering; the relevant analogue is that CoC's "character view" *is* the assembled prose, which reinforces that prose-from-state is the load-bearing surface.

## 6. Content / world structure

- **Authoring = ActionScript functions dispatched by integer event codes.** `eventParser(eventNo)` routes ranges: `<1000` system, `1000-1999` items, `2000-4999` events, `5000-6999` combat, `10000-10999` creation, `>=11000` dungeon (`eventParser.as:28-33`). Buttons store an int; pressing one calls `eventParser(int)`.
- Scale comes from volume: ~150 content files, the largest being `items.as` (738 KB), per-NPC files in the hundreds of KB. World is zones (forest/desert/mountain/lake) with weighted random encounters.

Learn: the range-partitioned dispatcher is a poor man's content registry. Avoid: magic event numbers couple every button/scene to a global integer namespace — opaque, collision-prone, undiscoverable. aeriea's content should be a typed, named registry (library-first / projection-from-one-definition), not numeric dispatch.

## 7. Determinism / save — the sharp contrast with aeriea

- **No seed, no event log, no replay.** `rand(max)` is literally `int(Math.random()*max)` (`engineCore.as:4877-4880`); `range()` likewise (`engineCore.as:4881+`). RNG is pulled live everywhere — combat, TF outcomes, prose variant selection.
- **Save = full mutable-state snapshot.** `saves.as` uses Flash `SharedObject.getLocal(slot,"/")` (`saves.as:14`) to serialize the entire `creature` plus the global `flags` array — a memory dump, not a derivable state.

This is the direct inverse of aeriea's hard invariant (seeded RNG + event-log replay; all state derivable from seed + action log). CoC is the textbook example of what aeriea explicitly rejects: non-reproducible simulation, snapshot saves, prose that can't be regenerated. Worth keeping as the named counter-example.

---

## Summary: what aeriea takes, what it leaves

Take: (1) parts-as-arrays + per-part scalar dimensions + per-part mutation logic with diminishing-returns curves; (2) the two-layer prose engine — a templating parser over a library of state→fragment descriptors with per-type synonym pools; (3) gating activity/menu options by body predicates so content adapts to an arbitrary body without enumerating combinations; (4) history-as-vignette-granting-a-perk for low-friction narrative identity.

Leave: (1) comment-legend integer enums and 4-untyped-slot perk/status bags + magic-index `flags` — replace with typed named tags/components; (2) unseeded `Math.random()` and snapshot saves — aeriea is seeded + event-log; (3) regex-over-source-text parsing and inline synonym `if`-ladders — store prose tags/pools as data/AST; (4) monolithic per-NPC authored scene files and magic-number event dispatch — use a typed content registry.
