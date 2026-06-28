# Reference: Corruption of Champions (CoC) — engineering map

Decompiled AS3 → TypeScript at `/home/me/reincarnate/flash/cc/out/frame1/`. ~860 `.ts` files (each class also has a `_traits.ts` metadata sidecar — ignore those). The real game lives in `classes/` (gameplay) and `coc/` (model + view). The single god-object is `classes/CoC.ts` (~37.5k lines) — the game controller; `kGAMECLASS` is the global singleton.

---

## 1. Core game loop & UI shape

**Screen layout** is fixed and dead simple (`coc/view/MainView.ts`):

- `mainText` — one big HTML `TextField` (the prose output) + a `scrollBar`. All story text is `htmlText` (supports `<b>`, `<i>`).
- **10 bottom buttons** in a 2×5 grid (`BOTTOM_BUTTON_COUNT = 10`, `BOTTOM_BUTTON_PER_ROW_COUNT = 5`). Each `CoCButton` carries `labelText`, `callback`, `toolTipText`. That's the entire interaction surface.
- **6 menu buttons** along the top: `newGame, data, stats, level, perks, appearance` (`MENU_*` constants).
- **Stats sidebar** (`coc/view/StatsView.ts` + the dozens of `*Num`/`*Bar`/`*Text` fields in MainView): HP, lust, str/tou/spe/inte/lib/sens, corruption, fatigue, XP, level, gems, time.

**The loop** is a callback trampoline, not a frame loop. Output text → set up buttons → wait for click → click invokes a callback → repeat. The three primitives (defined on `CoC`, proxied through `classes/BaseContent.ts` so every scene inherits them):

- `outputText(str, purgeText?)` — append/replace prose (`MainView.appendOutputText`/`setOutputText`).
- `addButton(pos, text, func, arg)` → `mainView.showBottomButton(...)`. `menu()` hides all 10.
- `choices(t1,f1, … t0,f0)` — convenience that calls `menu()` then `addButton` ×10.
- `doNext(fn)` — clears the menu and puts a single **"Next"** button bound to `fn` (the ubiquitous "continue" pattern). `doYesNo(yesFn, noFn)` similarly.

Play proceeds: **Camp** (`classes/Scenes/Camp/Camp.ts`, the hub — `playerMenu` is the return point) → **Explore** (`Scenes/Exploration.ts::doExplore` offers area buttons: Forest/Desert/Lake/Mountain/…) → random **encounter** (a scene or a monster fight) → resolve → time advances → back to camp. Time is `coc/model/TimeModel.ts` (`_days`, `_hours`, `totalTime = days*24+hours`); actions cost hours (e.g. `camp.returnToCampUseOneHour`).

---

## 2. Stats & body model — the heart

All on `classes/Creature.ts` (base for `Player` and `Monster`), instance fields ~line 300:

**Core stats** (plain numbers): `str, tou, spe, inte, lib, sens, cor` (corruption), `fatigue, HP, lust, XP, level, gems`.

**Body** is modeled two ways:

1. **Scalar/enum fields directly on Creature** — each transformable part is an **int "type" enum + scalar magnitude**. The enums are declared as a giant block of `static` constants at the top of Creature.ts (lines 29–290+). Examples:
   - Skin: `_skinType` (`SKIN_TYPE_PLAIN/FUR/SCALES/GOO/UNDEFINED`), `_skinTone` (string, e.g. `"albino"`), `skinDesc`, `skinAdj`.
   - Hair: `hairType` (`HAIR_NORMAL/FEATHER/GHOST/GOO/ANEMONE`), `hairColor` (string), `hairLength` (number).
   - Face/ears/eyes/tongue: `faceType` (19 `FACE_*` values), `earType` (14 `EARS_*`), `eyeType`, `tongueType`.
   - Horns: `hornType` + `horns` (count/length). Antennae, `armType`, `gills` (bool).
   - Tail: `tailType` (18 `TAIL_TYPE_*`), `tailVenom`, `tailRecharge`. Wings: `_wingType` (13 types) + `wingDesc`.
   - `lowerBody` (centaur/naga/etc.), `_tallness` (height in inches), `hipRating`, `buttRating`.
   - Piercings: per-site `*Pierced` + short/long desc strings.
   - Genital scalars: `balls`, `ballSize`, `cumMultiplier`, `fertility`, `clitLength`, `nippleLength`.

2. **Sub-object arrays for the "compound" parts** — `cocks: Cock[]`, `vaginas: VaginaClass[]`, `breastRows: BreastRowClass[]`, plus a single `ass: AssClass`. This is what gives CoC its signature granularity (multiple cocks/breast-rows). A part object is a small struct:

   ```ts
   // classes/Cock.ts
   export class Cock {
     _cockLength = 5.5; _cockThickness = 1; _cockType = CockTypesEnum.HUMAN;
     _knotMultiplier = 1; _isPierced = false; _pShortDesc; _pLongDesc; _sock;
   }
   ```

   `BreastRowClass` ≈ `{ breastRating (cup, 0–99 enum BREAST_CUP_*), nipplesPerBreast, lactationMultiplier, fuckable }`. `VaginaClass`, `AssClass` (`analLooseness`, `analWetness`) follow the same pattern.

So the data shape of a body part = **enum type + a few numeric magnitudes + optional descriptor strings/flags**. Cup sizes alone are a 100-value enum (`BREAST_CUP_FLAT`=0 … `BREAST_CUP_ZZZ_LARGE`=99) — content bulk, not structural complexity.

---

## 3. Transformation mechanics

A TF item is a class extending `classes/Items/Consumables/Consumable.ts` (→ `ItemType`). Two overrides matter: `canUse()` (gate) and `useItem()` (effect). The mechanic, traced through **`classes/Items/Consumables/GroPlus.ts`** (a targeted grower) and **`BeeHoney.ts`** (a random "becomes bee-type" TF):

1. `useItem()` calls `clearOutput()`, then either applies directly or presents sub-`choices` (GroPlus asks *which* part — Balls/Breasts/Clit/Cock/Nipples — disabling options whose part-count is 0: `(player.balls <= 0) ? null : cachedBind(this, this.growPlusBalls)`).
2. The chosen handler **reads current body state**, **rolls seeded RNG** (`Utils.rand(n)`), **mutates the field**, and **emits body-aware prose** interleaved with the change:

   ```ts
   // GroPlus.growPlusBalls()
   this.outputText("You sink the needle deep into your " + player.sackDescript() + ". …");
   if (Utils.rand(4) !== 0) {
     player.ballSize += Utils.rand(2) + 1;
     this.outputText("…they grow to " + player.ballsDescriptLight() + ".  ");
   } else { player.ballSize += Utils.rand(4) + 2; /* "VERY effective" branch */ }
   if (player.ballSize > 10) this.outputText("Walking gets even tougher…");
   this.game.dynStats("lus", 10);              // side-effect on stats
   this.game.inventory.itemGoNext();           // hand control back to inventory loop
   ```

   Type-changing items (BeeHoney) accumulate a `changeLimit` budget (more changes if pure/perked), then walk a priority list of conditions — *if not bee-cock, convert one cock to `CockTypesEnum.BEE`; else if antennae missing, add; else…* — decrementing the budget per change and printing a paragraph each. This "**spend a change-budget down a prioritized if-ladder**" is the canonical CoC TF pattern.

Helpers like `player.growTits(...)`, `increaseCock(i, amt)` encapsulate clamping + cup recalculation. `dynStats("str",2,"lus",10,…)` is the universal stat-delta API (paired name/value varargs; applies bonuses/caps).

---

## 4. Content/scene structure

Scenes are **plain methods on a class extending `BaseContent`** (which provides `outputText/choices/doNext/player/flags/game`). A scene = output prose + branch on flags/stats + wire up buttons. Representative: **`classes/Scenes/Explore/Lumi.ts`** — `lumiEncounter()` checks `flags[kFLAGS.LUMI_MET]`, prints discovery vs. return text, then `doYesNo(this.lumiLabChoices, camp.returnToCampUseOneHour)`; `lumiLabChoices()` calls `spriteSelect(37)` and sets up menu options. Persistent state is the **global `flags` array** (`classes/GlobalFlags/kFLAGS.ts` — named integer indices), saved/loaded wholesale.

**Body-aware prose** is two layers:

- **Descriptor functions** — every part has a `xDescript()` on Creature that delegates to `static` builders in **`classes/Appearance.ts`**. They assemble randomized noun+adjective phrases from the body state: `Appearance.cockNoun(cockType)` returns `Utils.randomChoice("flared horse-cock","equine prick",…)` for a horse cock vs. `("cock","prick","pecker","shaft")` for human; `cockDescription()` sometimes prepends an adjective driven by length/girth/lust/piercing. So the *same* call yields varied prose and reflects current TF state.
- **Parser tag system** — `classes/Parser/Parser.ts` rewrites bracket tags in text. `singleArgConverters` maps `[cock]→cockDescript()`, `[balls]→ballsDescriptLight()`, `[armor]`, `[boyfriend]→mf("boyfriend","girlfriend")`, etc.; plus conditional/two-word tags and `[if …]` blocks. This is the `[pc.cock]`-style templating, here flat-namespaced (`[cock]`).

---

## 5. Systems inventory

- **Combat** — `Monster.ts`/`classes/Scenes/Monsters/*`; combat menu (attack/spell/item/flee) driven from CoC; loss often triggers a TF/sex bad-end.
- **Inventory/items** — `classes/Items/` with `*Lib.ts` registries (`ConsumableLib.ts` ≈116 consumables, plus `ArmorLib`, `WeaponLib`, `MiscItemLib`); `Scenes/Inventory.ts` runs the use/equip loop (`itemGoNext`).
- **Areas/exploration** — `Scenes/Areas/{Forest,Desert,Lake,Mountain,Bog,Swamp,Plains,HighMountains}/` + `Dungeons/`, `Places/`; `Exploration.ts` is the dispatcher.
- **NPCs/followers** — `Scenes/NPCs/`, `FollowerInteractions.ts`; relationship state in flags.
- **Camp** — hub (sleep, masturbate, followers, stores).
- **Time/clock** — `TimeModel.ts` (days/hours).
- **Sex scenes** — `Masturbation.ts` + per-NPC scene methods; heavy descriptor/parser use.
- **Save/load** — `classes/Saves.ts` + `SaveAwareInterface`; serializes Creature + flags.
- **Progression** — perks (`PerkLib.ts`, `PerkClass`), status affects (`StatusAffects.ts`), corruption gating.

---

## 6. Minimal-viable subset

The **structure** is tiny; everything else is content volume. Smallest coherent "real TF game":

**Build (the spine):**
- **One-screen UI**: prose text area + ~6–10 labeled buttons + a stats sidebar. This *is* the engine (MainView). In Godot: a `RichTextLabel` + a `GridContainer` of `Button`s + a stats panel.
- **Callback trampoline**: `output(text)`, `button(pos,label,fn)`, `choices(...)`, `next(fn)`. ~50 lines.
- **Stat block**: ~6 core stats + HP/lust/corruption. Plain numbers, `dynStats`-style delta API.
- **Body model**: the enum-type + scalar pattern for a handful of parts — skin (type+tone), hair (length+color), face, ears, tail, height, and **one** compound part as an array (genitals OR breasts) to capture the multi-part idea. ~8 parts total, not 40.
- **Descriptor layer**: one `descript()` per part pulling randomized phrasing from current state (the Appearance.ts pattern) + a small bracket-tag parser (`[cock]`, `[skin]`). This is what makes prose *feel* responsive to TF — non-negotiable for the genre.
- **3–5 TF items**: 1–2 targeted growers (GroPlus pattern: pick part, roll, mutate scalar, narrate) + 1–2 type-changers (BeeHoney pattern: change-budget down an if-ladder) + a "revert" item. Each is ~one method.
- **2–3 explorable areas**, each with 2–3 encounters (a scene-method each), reachable from a camp hub, with a day/hour clock.

**Defer (bulk content, not structure):** the 100-value cup enum and 19-face/18-tail catalogs (start with ~4 each), the ~116-item library, full combat depth, followers/quests/dungeons, pregnancy/lactation sub-systems, save/load polish, NPC relationship webs. None change the architecture — they're more rows in the same tables and more scene-methods of the same shape.

**Key takeaway for Godot**: CoC is *not* a simulation; it's a **prose+button state machine over a flat mutable body struct, with a descriptor/parser layer that re-derives prose from state on every read.** The transformable-body data model (enum type + scalar magnitudes + sub-object arrays) and the descriptor-function pattern are the two load-bearing ideas worth porting faithfully; the control flow (callback trampoline) is trivial to reproduce and the content is incremental.
