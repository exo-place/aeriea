# Reference: BDCC game structure & body/TF systems (ground truth)

Repo: `/home/me/git/BDCC` (Godot **3.x** GDScript, ~414k LOC). Companion to `ref-bdcc.md` (dialogue). This doc covers everything *except* dialogue: game loop, body model, transformation, content architecture, and Godot lessons. All claims read from source, file:line cited.

Orientation: BDCC is a furry **prison-setting TF game**. Despite the NSFW framing, structurally it is a *clean, conventional* exploration-RPG: a tiled room map you walk turn-by-turn, NPCs that simulate on a clock, an inventory, stats, and a transformation system layered on a granular body model. The patterns transfer directly to a "regular TF game" in Godot.

---

## 1. The game loop & top-level structure

**Boot & singletons.** `Game/GM.gd` is a global service-locator autoload holding `ui` (GameUI), `main` (MainScene), `pc` (Player), `world` (GameWorld), plus systems `ES` (events), `QS` (quests), `CS` (children). `Game/MainScene.gd` is the root orchestrator: it owns the **scene stack** (`sceneStack`, `MainScene.gd:8`), game clock (`currentDay`, `timeOfDay` = seconds-since-midnight, `MainScene.gd:11-12`), all characters, and global `flags`. `GlobalRegistry.gd` (85k!) is a giant content registry that, at boot (`registerEverything()`, `GlobalRegistry.gd:518`), scans folders and registers every bodypart / item / scene / event / stat / perk / species class by ID. **ID-keyed registry + factory** (`createScene(id)`, `createItem(id)`, `createTransformation(id)`) is the core indirection — content is referenced by string ID everywhere, never by direct class reference.

**The world is a graph of room scenes.** A `GameRoom` (`Game/World/GameRoom.gd`) is a Godot node with exported props: `roomID`, `roomName`, `roomDescription`, directional gates `canNorth/canWest/...` (`GameRoom.gd:10-13`), location tags (`loctag_Offlimits`, `loctag_GuardsEncounter`, …), a `population` bitmask, and loot fields. Rooms are authored as `.tscn` scenes grouped into **Floors** (`Game/World/Floors/*.tscn`, ~20 floors: Cellblock, CommandDeck, etc.). `GameWorld` (`Game/World/World.gd`, 753 lines) builds an **AStar2D** graph from the rooms (`World.gd:39 calculatePath`, `:310 astar.add_point`) so movement and NPC pathing run on a real navmesh of rooms.

**Movement = a SceneBase that draws compass buttons.** The exploration "screen" is itself a scene: `Scenes/WorldScene.gd`. Its `_run()` adds directional buttons (`addButtonAt(6,"North",..., "go", [Direction.NORTH])`, `WorldScene.gd:22-37`) plus Look around / Me / Inventory / Tasks. Pressing **Go** (`_react`, `WorldScene.gd:100`): plays a walk animation, `GM.pc.setLocation(applyDirectionID(...))`, **advances the clock** `processTime(30)` (60 if legs bound), re-aims the map camera, fires `Trigger.EnteringRoom` through the event system, then `checkTFs()`. So **time only advances on action** — a turn-ish clock, not real-time. `processTime(seconds)` (`MainScene.gd:710`) ticks the PC and every active character's `processTime`, chunked into 1-hour slices for sleep, and fires `hoursPassed` hooks (buffs, relationships, slavery).

**Rooms expose actions two ways.** (a) `RoomAction` nodes (`Game/World/RoomAction.gd`) — declarative children of a room with `ActionName`/`ActionScene` and `_canRun()`/`_shouldShow()` gates; WorldScene turns them into buttons that `runScene(ActionScene)`. (b) **Scripted rooms** override `_onButton(keyid)` for bespoke logic (`WorldScene.gd:94 "roomCallback"`). NPCs in the room are surfaced via the **InteractionSystem** (`GM.main.IS`): pawns walk the same AStar graph, and `WorldScene.runInteraction()` (`:240`) renders contextual NPC-action buttons.

**Everything is a scene on a stack.** `runScene(id, args, parent)` (`MainScene.gd:286`) instantiates a registered scene, pushes it on `sceneStack`, calls `initScene`. `removeScene` pops and calls the parent's `react_scene_end` (`:301`). The visible game is always "the top scene draws text + buttons into GameUI." Combat, sex, the inventory, a conversation, walking around — all are scenes on one stack. (Scene authoring detail is in `ref-bdcc.md`.)

---

## 2. Stats & the body/character model

**Character base.** `Game/BaseCharacter.gd` (huge, ~3400+ lines) is the shared base for the PC (`Player/Player.gd`) and NPCs (`Characters/Character.gd` → static, `Characters/Dynamic` → generated). Combat/vital stats are plain ints: `pain`, `lust`, `stamina` (`BaseCharacter.gd:16-18`), with derived `getPainLevel()`/`getLustLevel()`/`getArousal()`. RPG stats are a tiny registry-driven set — only **four**: Strength, Agility, Vitality, Sexiness (`Skills/Stat/*.gd`, registered `GlobalRegistry.gd:578-581`), accessed via `getStat(id)`. Plus skills, perks (`Skills/`), reputation (`Game/Reputation`), status effects (`StatusEffect/`), and **LustInterests** (a fetish-preference map, e.g. `AlexRynard.gd:30+ npcLustInterests = {InterestTopic.Gags: Interest.Loves, ...}`) that drives NPC reactions.

**The body is a slotted bag of bodypart objects — this is the key model.** `BaseCharacter.bodyparts` is a `Dictionary` keyed by `BodypartSlot` (Head, Body, Arms, Legs, Ears, Hair, Horns, Tail, Breasts, Penis, Vagina, Anus). Each slot holds a **Bodypart object** (`Player/Bodyparts/Bodypart.gd` base; per-slot subclasses `BodypartPenis.gd`, `BodypartVagina.gd`, …). API: `giveBodypart(part)` / `getBodypart(slot)` / `removeBodypart(slot)` (`BaseCharacter.gd:933-985`). Each concrete part is itself an ID-registered class with **species variants**: `Player/Bodyparts/Penis/{Canine,Equine,Feline,Dragon,Human}Penis.gd`. A part carries:
- typed numeric/string attributes (`BodypartPenis`: `lengthCM:float`, `ballsScale`, `fluidType` — `BodypartPenis.gd:4-6`; `BodypartVagina`: `fluidType`, menstrual cycle hooks);
- attached sub-objects: an `Orifice`, a `FluidProduction`, a `SensitiveZone` (`Bodypart.gd:9-11`) — penetration/fluid/erogenous simulation hangs off the part;
- **color/skin** picks (`pickedSkin`, `pickedRColor/G/B`) for the 3D doll;
- `getCompatibleSpecies()` / `getSpeciesScores()` (`Bodypart.gd:52-83`) and `getHybridPriority()` — parts declare which species they fit, enabling **hybrids**.

**Species is multi-valued.** `getSpecies()` returns an **Array** (`BaseCharacter.gd:703`), so a character is a *set* of species (Canine+Demon = hybrid), with `getCrossSpeciesCompatibility()` and per-part species scoring deciding what a hybrid's parts look like. Species classes (`Species/{Canine,Feline,Equine,Dragon,Demon,Human}.gd`) carry skin-color generators and naming.

**Comparison to CoC's body model.** Same *philosophy*, different *encoding*. CoC models the body as a flat list of granular **descriptor fields on the Creature** (cockArray, balls, vaginas, breastRows, hipRating, buttRating, tone, hair…) — loosely-typed numbers/enums sprawled across one object, with prose derived by reading those fields. BDCC instead makes each body region a **first-class polymorphic object in a slot**, with typed attributes, species variants, and behavior (orifice/fluid/sensitivity) co-located on the part. BDCC is **more granular and more object-oriented** than CoC: where CoC has `cockArray[i].cockLength`, BDCC has a `CaninePenis` *instance* that knows its own length, fluid, sensitive zone, transform messages, and 3D mesh. Net: CoC = wide data record read by prose functions; BDCC = composable typed part-objects with attached simulation, rendered by both prose *and* a 3D doll.

---

## 3. Transformation mechanics — a core loop, not incidental

TF is a **first-class staged system**, the game's marquee mechanic. Lives in `Game/Transformation/`.

**Shape.** Each TF is a class extending `TFBase` (`Game/Transformation/TFBase.gd`), ID-registered like everything else. It declares: pill name + flavor (`getPillName`, `getPillDatabaseDesc`), required fluids to craft (`getPillFluidsRequired`), a feasibility gate `isPossibleFor(char)`, conflict tags `getTFCheckTags()`, and a **multi-stage timer loop**: `getTimerForStage(n)`, `canTransformFurther()`, `doProgress(ctx)`, `reactProgress(ctx, result)`.

**A `TFHolder` per character runs the loop** (`Game/Transformation/TFHolder.gd`): it holds active `transformations`, a list of applied `effects`, and stored `originalParts`/`originalCharData` for undo. `processTime` (`TFHolder.gd:214`) ticks every TF's timer (scaled by a `TransformationSpeed` buff); when a stage is due, `doFirstPendingTransformation` (`:157`) runs.

**Concrete trace — `GrowPenisTF` (DiRecto pill), `Game/Transformation/TFs/GrowPenisTF.gd`:**
1. **Reads state.** `isPossibleFor`: refuse if `char.hasPenis()` (`:41`). `canTransformFurther`: continue while no penis, or penis exists but `getPenisSize() < 15` (`:49-57`).
2. **Emits change as *data*.** `doProgress` (`:64`) returns a dict of **effect descriptors**, not direct mutation: stage 0 returns `{}` (just warmth flavor). Once active, if penis-less it picks a species-appropriate part — `Bodypart.findPossibleBodypartIDsDict(BodypartSlot.Penis, char, char.getSpecies(), Male)` → `RNG.pickWeightedDict` → returns `partEffect("newpart", Penis, "SwitchPart", [newPartID, {lengthCM=10}])`. If a penis already exists but is short, returns `partEffect("penLen", Penis, "PenisLengthChange", [randi_range(3,6)])`.
3. **Effects apply, reversibly.** `TFHolder.doFirstPendingTransformation` instantiates each effect (`TFEffect` subclass, `Game/Transformation/Effects/`) and calls `applyAllTransformationEffects`. `PenisLengthChange.applyEffect(data)` (`Effects/PenisLengthChange.gd`) mutates the part's serialized data dict (`data["lengthCM"] += howMuch`, clamped ≥4) and **returns `{origLen, newLen, success}`** — the original is captured so `undoTransformation` (`TFHolder.gd:117`) can roll it back. `makeAllTransformationsPermanent()` (`:143`) bakes effects in and clears the undo log. Effects also **coalesce**: repeated length changes merge via `onReplace` (`PenisLengthChange.gd:onReplace` adds the deltas).
4. **Reflects in description/stats/visuals.** Effects carry their own `generateTransformText(result)` ("Your cock is growing longer!"), and the TF's `reactProgress` (`GrowPenisTF.gd:92`) emits prose + plays a `StageScene.TFLook` animation on the 3D doll. So one progress step mutates the typed part, regenerates prose, and re-renders the model.

**Delivery to the player.** After any room action, `WorldScene` calls `GM.main.checkTFs()` (`MainScene.gd:1156`); if a stage is pending it `runScene("PlayerTFScene")` to narrate it. So TF resolves **on the world clock**, between actions — exactly a "drink pill, walk around, transformation unfolds over in-game minutes" loop.

**Catalogue** (`Game/Transformation/TFs/`): Feminization, Masculinization, Sissification, Demonification, HuCow, SpeciesTF, Skin/Thickness/Breast/Penis/Vagina size & add/remove. The set spans gender, species, and granular part edits — TF is the spine, not a side feature.

---

## 4. Content & data architecture — mostly **code**, with a data-driven escape hatch

**Default authoring is GDScript classes, registered by folder scan.** Confirming `ref-bdcc.md`'s finding for the whole game, not just dialogue:
- **Items** = GDScript subclasses of `ItemBase` (`Inventory/ItemBase.gd`); e.g. `AnaphrodisiacPill.gd` overrides `getVisibleName`, `getDescription`, `useInCombat`, `getPossibleActions` (returns action dicts), `getPrice`. Registered by scanning `Inventory/Items/**` (`GlobalRegistry.gd:559`).
- **Static characters** = GDScript subclasses of `Character` setting fields in `_init()` (`Characters/AlexRynard.gd`: `npcLevel`, `npcBasePain`, skin colors, `npcLustInterests`, personality). Dynamic NPCs are procedurally generated (`Characters/Dynamic`, `InmateGenerator`).
- **Bodyparts / TFs / effects / species / stats / perks / skills / events / scenes** — all the same pattern: a base class, a folder, a registry scan, ID-keyed factory.
- **Locations** = `.tscn` scenes (exported props) grouped into Floor `.tscn`s — the *one* place content is data-ish (Godot scene files), edited in the Godot editor, not pure code.

There is a recurring **"code that emits data" idiom**: methods return Dictionaries/Arrays of descriptors (`getPossibleActions()` → action dicts, `doProgress()` → effect dicts, ModularDialogue forms). The control flow is code; the *payloads it returns* are data. This is the seam where data and code meet.

**The data-driven layer: Datapacks (`Game/Datapacks/`).** BDCC ships an **in-game visual editor** for user mods. A `Datapack` (`Datapack.gd`) bundles `DatapackScene`, `DatapackCharacter`, `DatapackQuest`, `DatapackSkin`, `DatapackResource`. A `DatapackScene` (`DatapackScene.gd`) is **fully data**: `states:Dictionary`, `vars`, `chars`, `triggers:Array`, `images` — a serialized state-machine (the same SceneBase shape as code scenes, but as data) with a small embedded code/expression context (`DatapackScene/SlotCalls.gd`, `DatapackSceneCodeContext.gd`). It has `saveData()/loadData()` and a full editor UI (`Datapacks/UI/DatapackEditor.tscn`, `DatapackBrowser`). So the *core* game is imperative GDScript scenes, but the *modding/UGC* path is a **data serialization of the very same scene-state-machine model** — proof the authored-scene pattern *can* be reduced to data when they needed it to (for user content that can't ship code).

**Save system** (`Game/SaveManager.gd`): the entire game state is a nested Dictionary serialized to **JSON** (`saveGame` → `JSON`, versioned `currentSavefileVersion=2`, with `SaveConversion.gd` migrations and rolling quicksave backups). Every object implements `saveData()`/`loadData(data)` returning/consuming a dict — including bodyparts and TF effects. The save format *is* the canonical data model; the class tree is a runtime projection over a serializable dict tree.

---

## 5. What BDCC does that CoC doesn't (and vice versa)

**BDCC adds, structurally, over CoC:**
- **A real spatial world.** CoC is pure nested menus ("Explore → event"). BDCC has a **tiled room graph with AStar pathing**, compass movement, a live minimap (`MapAndTimePanel`), and location tags driving encounters. Place is a first-class structure.
- **A persistent NPC/agent layer.** CoC NPCs are mostly menu destinations. BDCC has the **InteractionSystem**: pawns that occupy rooms, path around, get spawned/despawned by population rules (`WorldPopulation`), carry relationships (`RelationshipSystem` affection/lust), memory (`WorldHistory`), personality, and slavery/quest state — they simulate on the clock whether or not you're looking.
- **A unified scene stack + interaction system** instead of ad-hoc menu functions — combat, sex, dialogue, shops all share one push/pop substrate.
- **Object-oriented composable body + reversible staged TF** (vs CoC's flat fields + mostly-instant TF items).
- **A 3D doll render** of the body (`Player/Player3D`, `StageScene3D`) driven by the same part objects — body state has a visual, not just prose.
- **A shipped UGC editor** (Datapacks) — data-driven content authoring for non-coders.

**CoC does better / BDCC's costs:**
- **Authoring velocity & prose density per LOC.** CoC's flat menu-event model is dramatically lower-ceremony; BDCC pays a heavy class/registry/scene-stack tax per piece of content (414k LOC).
- **Granular *prose* from body state.** CoC's whole design centers descriptor-driven prose generation; BDCC's prose is more hand-authored-per-scene and less systematically derived from the body record.

**Worth borrowing for a Godot TF game:** the **room-graph-as-scenes + AStar**, the **on-action world clock** (`processTime` ticking all agents), the **slotted typed-bodypart model with species variants**, the **reversible staged-TF holder with data-descriptor effects**, the **ID-registry + factory** indirection, and the **JSON `saveData()/loadData()` discipline on every object**.

---

## 6. Godot-specific lessons (for building a Godot TF game)

**Gets right (copy these):**
1. **Service-locator autoload (`GM`) + ID-registry/factory (`GlobalRegistry`).** Reference all content by string ID, resolve via a registry populated by folder scan at boot. Decouples content from call sites, enables modding, and makes saves portable. Single highest-leverage structural choice.
2. **One scene-stack substrate for *all* interactive surfaces.** Movement, combat, sex, shops, dialogue are all "a thing that draws text+buttons and pushes/pops." Uniform, debuggable, save-friendly (`sceneStack`). Avoids per-surface bespoke UI plumbing.
3. **`saveData()/loadData(dict)` on every stateful object → JSON tree, versioned with explicit migrations** (`SaveConversion.gd`). The dict tree is the real model. Makes the body/TF state trivially serializable and the format the source of truth.
4. **Body as slotted polymorphic part-objects**, each owning its attributes, attached simulation (orifice/fluid/sensitivity), species variants, prose hooks, and mesh — instead of a flat field bag. Scales to hybrids and per-part TF cleanly.
5. **TF as data-descriptor *effects* applied through a holder that records originals** → free undo, free coalescing, free "make permanent." Don't mutate the body inline; emit effects and let a holder apply/reverse them.
6. **On-action clock that ticks all agents** (`processTime`), chunked for long sleeps, with `hoursPassed` hooks. Deterministic, simple, no real-time loop needed — fits a seeded-sim design.
7. **Rooms as `.tscn` with exported props + AStar.** Designers lay out the world in the Godot editor; pathing is engine-native. Location tags on rooms drive systemic encounters without hard-coding.

**Gets wrong / cautions (Aeriea should avoid):**
1. **Godot 3.x, ~414k LOC, near-zero data/code separation in the core.** The folder-scan-of-GDScript-classes pattern means *adding a pill is writing a class*; content can't cache/diff/transport/replay as data, and the codebase is enormous for what it delivers. They **belatedly** built the Datapack data-serialization of the scene model for UGC — evidence the imperative-scene seam *should* have been data from the start. **Lesson: design the content seam as data first** (BDCC proves the same state-machine model serializes fine), reserving code for the irreducible glue. This is exactly the project's "prefer data over code at a seam" principle, validated against a real corpus.
2. **`GlobalRegistry.gd` at 85k lines and `BaseCharacter.gd` at ~3400** — god-objects accreted because everything funnels through the locator/base. The registry/factory idea is right; the *monolithic single file* is the failure. Split by domain.
3. **Prose coupled to control flow** (the `ref-bdcc.md` finding) — body state is read ad-hoc via `if`s inside scene scripts rather than a body→description projection. For a TF game where the body *is* the content, derive description from the body record systematically (CoC's strength), don't re-hand-author per scene.
4. **Mutable-class state as truth, dict as afterthought.** They serialize *out* of live objects; a cleaner design makes the serializable dict the truth and the objects a typed view over it (the project's data-over-code stance) — avoids `saveData`/`loadData` drift bugs that `SaveConversion.gd` exists to paper over.

**One-line takeaway:** BDCC is an excellent *structural* reference for a Godot TF game — room-graph world, on-action clock, slotted typed-body + reversible staged TF, ID-registry, JSON saves — but a cautionary one on *content architecture*: its imperative-GDScript-per-content-piece core is the "code at a seam that should be data" anti-pattern, and its own late-added Datapack data-format is the proof.
