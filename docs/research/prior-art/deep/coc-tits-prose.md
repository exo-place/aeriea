# Deep Dive: CoC + TiTS — the two-layer prose engine (parser + descriptors)

Status: studied 2026-06-22 from full clones at `~/git/coc` (Fenoxo CoC, AS3/Flash) and `~/git/tits` (Trials in Tainted Space, AS3/Flash). This is a DEPTH pass on the prose-realizer thread specifically: the templating parser (Layer 1) and the state-keyed descriptor / synonym-pool layer (Layer 2). The recon docs (`../coc.md`, `../tits.md`) give the shallow map; this is the precise how — exact grammar, exact selection path, with line cites.

Scope: aeriea is building a prose realizer over a typed body/tag system. CoC+TiTS are the canonical prior art for "AST templating over state-keyed descriptors with synonym pools." TiTS is the evolved version; the headline finding is *exactly what TiTS changed and why*, because that delta is the cheap lesson.

The single most important structural fact, established up front: **both engines are two layers.**

- **Layer 1 — the templating parser.** Takes authored text with `[tag]` markup + inline conditionals, walks it, and substitutes. This is the AST/string-rewrite layer. CoC: `parseText()` in `engineCore.as:339`. TiTS: `ParseEngine.recursiveParser()` in `classes/Parser/ParseEngine.as:547`.
- **Layer 2 — the descriptors.** A tag like `[cock]` resolves to a *function* (`cockDescript()`) that reads body state and emits a randomized, state-appropriate noun phrase by pulling from per-type synonym pools. CoC: `descriptors.as` (3555 lines). TiTS: `Creature.getDescription()` (`classes/Creature.as:1448`) + the `*Descript()` family.

Layer 1 decides *where* prose varies; Layer 2 decides *what* the varying fragment is. They are coupled only by the tag-name → function dispatch table. Keep that seam clean and you can swap either layer. CoC and TiTS share Layer 2 almost verbatim; they differ sharply in Layer 1.

---

## 1. Layer 1 — CoC's parser (`engineCore.as:339-872`)

### 1.1 The grammar, as actually implemented

CoC's parser is **five regexes applied in a fixed most-complex-first order**, each in its own `while (exec != null)` loop, each loop doing one `String.replace` per iteration. There is no AST and no tokenizer — it is iterated regex rewriting over a flat string. The regexes (`engineCore.as:345-364`):

```
isExp      = /\(([A-Za-z0-9]+)\s(==|=|!=|<|>|<=|>=)\s([A-Za-z0-9]+)\)/   // one comparison
basicTag   = /\[([a-zA-Z0-9]+)\]/                                        // [name]
paramTag   = /\[([a-zA-Z0-9]+)\s(.*?)\]/                                 // [cock largest]
branchTag      = /\[if\s(.*?)\s\"(.*?)\"\]/                              // [if (cond) "text"]
branchTagElse  = /\[if\s(.*?)\s\"(.*?)\"\selse\s\"(.*?)\"\]/             // [if (cond) "a" else "b"]
```

Processing order (`parseText`): `branchTagElse` → `branchTag` → `paramTag` → `basicTag`. Order is load-bearing: `basicTag` is the greediest, so it runs last; `if` runs first so its branch bodies can themselves contain tags.

The four primitive constructs:

1. **Basic tag** `[name]` — zero-arg. Resolved by a hardcoded `switch (result[1])` over ~80 cases (`engineCore.as:629-796`). `[cock]`→`cockDescript(0)`, `[he]`→`player.mf("he","she")`, `[pg]`→`"\n\n"`. Unknown tag → inline error string `<b>!Unknown tag "x"!</b>` (`:794`).
2. **Param tag** `[name arg]` — one arg, space-separated. `switch` over a *different, smaller* set (`engineCore.as:515-611`): `[cock largest]`, `[cockFit 12]`. The arg is cast to Number if it matches `/[0-9]+/`, else kept as string (`:502-509`).
3. **`if` without else** `[if (cond) "body"]` — body shown iff cond true, else replaced with `""`.
4. **`if`+else** `[if (cond) "a" else "b"]`.

### 1.2 The conditional sub-grammar — the genuinely interesting part

A branch's condition string (`result[1]`) is itself parsed by repeatedly applying `isExp` and reducing left-to-right (`engineCore.as:383-415`). Mechanism:

- Pull the first `(a op b)` triple, evaluate it via `checkCondition(a, op, b)` (`engineCore.as:97`).
- Strip that triple from the condition string, `trim`.
- Look at the *leading two chars* of what remains: if `||` → OR the running result with the next clause; if `&&` → AND it (`:395-407`). Slice off the operator and continue.

So `(corruption > 50) && (hasCock = true)` is supported, and so is mixed `&& / ||` — but **with no precedence and no parens-grouping**: it is a strict left-fold. `a && b || c` means `((a && b) || c)`. There is no way to express `a && (b || c)`.

`checkCondition` (`engineCore.as:97-336`) is the **typed variable resolver** — the heart of how state enters Layer 1. It branches on the *type of the RHS literal*:

- RHS matches `/[0-9]+/` → numeric branch (`:109`). `switch(variable)` maps a whitelisted name to a player stat: `"corruption"→player.cor`, `"vagCapacity"→player.vaginalCapacity()`, `"biggestTitSize"→player.biggestTitSize()` (~25 cases, `:115-192`). Then applies the op.
- RHS matches `/[true|false]/` → boolean branch (`:224`). `switch(variable)` maps to predicates: `"hasVagina"→player.hasVagina()`, `"isHerm"→(player.gender==3)`, `"cumHigh"→(cumQ()>350 && <=1000)` (~25 cases, `:237-302`). The cum-volume *buckets* are precomputed here as named booleans — a nice trick: discretize a continuous stat into named bands at the resolver, so authors write `[if (cumHigh = true) ...]` not magic numbers.
- Else → string branch, which is a stub (`default → ""`, `:317-322`). String comparison is effectively unimplemented.

The variable whitelist is the API surface. An author can only test what `checkCondition` knows about; adding a testable property means editing the engine.

### 1.3 Nesting, recursion, and the hard limits

- **`if` bodies recurse**: each branch body is `parseText(result[2])` before insertion (`:375, 440`), so `[name]` inside an `if` body resolves. Tags nest inside branch text fine.
- **`if` cannot nest in `if`**: the comment at `:359` is explicit — *"You can't nest if's, and they MUST end with a space to make recursive parsing work."* The `(.*?)\s\"(.*?)\"` regex is non-greedy and would mis-bracket a nested `if`. This is a real authoring constraint, not a style note.
- **No escape mechanism**: a literal `[` in output is impossible; everything `[...]` is a tag.
- **Cost**: O(tags × string length) — every successful match does a full-string `String.replace` and re-`exec` from the top. Fine for paragraph-scale Flash text; quadratic and not something to copy at scale.

### 1.4 Dead-code archaeology (instructive)

`engineCore.as:805-869` is a large commented-out block of the *previous* parser: pure `output.split("[cock]").join(cockDescript(0))` chains, with `[cock2]…[cock10]` and `[cockHead]…[cockHead]10` enumerated by hand. This is the literal "before" of CoC's own first refactor — from hand-enumerated string-replace to the regex-switch engine. The lesson is visible in the diff: the indexed variants (`[cock2]`) collapsed into one param tag `[cock 2]`. (TiTS then collapses the param-tag *switch* into a data table; see §3.)

---

## 2. Layer 2 — the descriptors + synonym pools + the discriminant (CoC `descriptors.as`)

This is the layer aeriea most directly needs. A descriptor is a **state→fragment function**: read body state, optionally prepend an adjective, pick a noun from a weighted synonym pool, return a string.

### 2.1 The shape of a descriptor

`cockDescript(cockNum)` (`descriptors.as:2750`) is the archetype. Path:

1. Guard for "no part present" / out-of-bounds → inline error (`:2751-2752`).
2. **Dispatch on the part's type enum** to a per-type descriptor: `cockType==1→horseDescript`, `2→dogDescript`, `4→tentacleDescript`, … `10→displacerDescript` (`:2754-2774`). Type 99 is a sentinel for "boring/generic."
3. Each per-type descriptor (e.g. `horseDescript`, `:2791`) does: **50% of the time** prepend `cockAdjective(cockNum)`, then append `cockNoun(type)`.

### 2.2 The synonym pool — `cockNoun(type)` (`descriptors.as:2227`)

This is the per-type pool: a flat `switch` on type, each case rolling `rand(N)` and indexing into an inline list of phrasings. Type 0 (generic): `cock / prick / pecker / shaft` weighted 5/2/1/2 across `rand(10)` (`:2230-2235`). Type 1 (horse): 8 phrasings `flared horse-cock / equine prick / …` (`:2267-2277`). The pools are **hand-written string literals weighted by which `rand` buckets map to them** — there is no data structure; the weighting is encoded in the `if (rando == ...)` bucketing.

### 2.3 The discriminant — `dogScore` vs `foxScore` (THE pattern)

The most-cited mechanism. Some part types are ambiguous: cock type 2 ("canine") could read as dog *or* fox depending on the rest of the body. `cockNoun` resolves this with a **comparative species score** (`descriptors.as:2237-2265`):

```
if (player.dogScore() >= player.foxScore()) { ...dog synonym pool... }
else                                        { ...fox synonym pool... }
```

`dogScore()` / `foxScore()` live on the body class (`classes/creature.as:2902, 2943`) and are **additive feature counters over the whole body**:

```
dogScore(): faceType==2 +1; earType==2 +1; tailType==2 +1; lowerBody==2 +1;
            dogCocks()>0 +1; breastRows>1 +1; ==3 +1; >3 -1;
            skinType==1 (fur) +1  ONLY IF dogCounter>0   // gating clause
```

`foxScore()` is the same template with fox-valued enums (faceType==11, earType==9, …) and the *fur* and *multi-breast* bonuses gated on `dogCounter>0` so unrelated traits don't leak in (`:2943-2955`). The discriminant is `argmax`-by-threshold over these counters.

**This is the load-bearing idea for aeriea.** The body is a bag of independent typed traits; "what species is this" is not stored — it is *derived on demand* by scoring the trait bag against each species template and taking the max. Prose word-choice then keys off the winning score. Decoupling "stored traits" from "derived identity" is exactly right for a deep-customization sandbox where the body is mutated piecemeal and no single field can say "you are now a fox."

### 2.4 Randomness — the determinism red flag

Every descriptor uses raw `Math.random()` / `rand()` (`:2779-2785`, `:2864-2887`). The same `[cock]` re-renders differently each call. CoC also varies *whether* a clause appears at all (the `if(int(Math.random()*100) > 60)` "40% display rate" on tightness, `:2866`). This is deliberate prose texture — but it is **nondeterministic at the realizer**, which directly violates aeriea's hard determinism invariant. See §5.

---

## 3. Layer 1 — TiTS's evolved parser (`ParseEngine.as`) and what it fixed

TiTS rebuilt Layer 1 as a real class (`classes.Parser.ParseEngine`, 706 lines) with a documented grammar block (`:26-63`). The deltas from CoC are the whole point of this doc.

### 3.1 Structural recursion with bracket-matching, not greedy regex

CoC matched tags with greedy regex (hence "no nested if"). TiTS's `recParser` (`:415-540`) does **manual bracket-depth scanning**:

- Find the first *unescaped* `[` (`:436-449` — checks `charAt(i-1) != "\\"`, so `\[` is a literal — **CoC had no escape; TiTS added one**, cleaned up at `:581-582`).
- Walk forward counting `[`/`]` depth (`:454-471`) until depth returns to 0 → that is the matching close, even with nested brackets inside.
- Split into prefix / bracket-contents / postfix. **Recurse into the bracket contents first** (`recParser(tmpStr, depth)`), *then* interpret the resolved inner string as a tag (`parseNonIfStatement(...)`, `:493`). Postfix is recursed only if it still contains `[` (`:507-510`).

Because matching is depth-counted rather than regex-greedy, **tags genuinely nest** — `[obj [otherTag] aspect]` works. This is the headline fix: CoC's flat-regex "can't nest ifs" limitation is gone by construction.

The authors flag the cost themselves (`:511-515`): one recursion per tag → ~29 recursions for 30 tags. They note it should be flattened or made tail-recursive "if this does become an issue." It didn't, at Flash scale.

### 3.2 Tag dispatch became *introspection over a data table* — then nearly all data

CoC's tag → function mapping was a giant hardcoded `switch`. TiTS replaced it with:

1. **A lookup-table layer** — `singleArgConverters` (`singleArgLookups.as`), `twoWordTagsLookup` / `twoWordNumericTagsLookup` (`doubleArgLookups.as`): `Object` maps from tag-name → anonymous function. `convertSingleArg` (`:82`) lowercases the tag, looks it up in the dict, calls `fn(ownerClass)`, and **auto-capitalizes the result if the original tag's first letter was uppercase** (`:85, 96-97`). So `[he]`/`[He]` is one table entry, not two switch cases — CoC needed both `case "he"` and `case "He"` (`engineCore.as:772-777`). That's the synonym/case explosion collapsed to a rule.
2. **THE crucial finding: those tables are now entirely commented out.** Every entry in `singleArgLookups.as` (`:15-65`), `cockLookups`/`cockHeadLookups`/`twoWordNumericTagsLookup`/`twoWordTagsLookup` (`doubleArgLookups.as:14-130`) is inside `/* ... */`. The live path is the "UGLY hack to patch legacy functionality … This needs to go eventually" (`ParseEngine.as:104-123, 219-242`).

That "hack" is the actual mature mechanism: `getObjectFromString(ownerClass, tagName)` (`:299-339`) does **dotted-path introspection** — `[pc.cockDescript]` resolves `ownerClass.pc.cockDescript` by recursively splitting on `.` and walking the object graph (`:307-327`). If the resolved member is a `Function`, call it; else stringify it (`:131-141`). For two-word tags, if the subject object has a `getDescription` method, dispatch `obj.getDescription(aspect, arg)` (`:118-121, 232-240`).

So TiTS's trajectory across its own history is: **hardcoded switch (CoC) → name→closure data table → object-graph introspection + per-object `getDescription` dispatch.** Each step removes engine edits as the cost of adding a tag. The endpoint pushed the dispatch table *onto the data objects themselves* (each `Creature`/NPC owns its `getDescription`), which is why the central tables went dead.

### 3.3 What TiTS did NOT (yet) have here

In *this* clone, `ParseEngine` has **no conditional / if-statement evaluation**. The grammar doc block advertises `[if (condition) X | Y]` (`:32-37`) and a `[screen]`/`[button]` scene-control syntax (`:57-61`), and `parseNonIfStatement` is *named* as if an if-handler is its sibling — but `recParser` never branches on `if`, and the comment at `:498-499` says "in case they're an if-statement … I haven't implemented yet." `parseSceneTag` (`:352`) exists (splits `[name | content]` into `parserState`) but isn't wired into the main loop either.

Reading: this clone is a **mid-migration snapshot** — structural recursion + introspection dispatch landed and the old tables were retired, but the conditional layer was not yet re-ported onto the new recursive core. (Later public TiTS builds do have conditionals.) This is itself a lesson: TiTS shipped the parser *rewrite* before re-implementing a feature CoC already had, leaving a window where the new engine was strictly less capable on conditionals. The migration was not finished before building on top — the exact anti-pattern aeriea's CLAUDE.md calls out ("Finish migrations before building on top").

### 3.4 Output polish TiTS added

`recursiveParser` (`:547-622`) wraps the recursion with: `\\n`→newline normalization (`:560`), smart-quotes via regex (`makeQuotesPrettah`, `:630-639` — straight→curly, `--`→em-dash), optional markdown `</p>` newline handling, escaped-bracket cleanup, and **repeated-space collapse `/  +/g → " "`** (`:585`) — which papers over the "clause didn't appear, leaving a double space" artifact that CoC's random-display-rate clauses produce. Worth stealing regardless of engine.

---

## 4. Layer 2 in TiTS — the descriptor switch and the scaled discriminant

### 4.1 `getDescription` — synonym folding at the dispatch (`Creature.as:1448-1567+`)

TiTS keeps CoC's `*Descript()` functions but routes them through one big method, `getDescription(arg, arg2)`, a `switch(desc)` (desc = lowercased aspect). The notable move vs CoC: **massive synonym key-folding**. One body function is reachable under many aspect spellings:

```
case "raceType": case "raceShort": case "raceSimple": case "simpleRace":
case "raceStrip": case "stripRace":   buffer = raceShort();   break;
```
(`:1479-1486`) — six author-facing spellings → one function. Similarly `weaponMelee/meleeWeapon`, `fullName/fullname`, etc. This is the synonym-pool idea applied to *the tag vocabulary itself* (author ergonomics), distinct from the synonym pool applied to *output words* (Layer 2.2). `getDescription` is explicitly marked legacy ("Please access object members directly!", `:1449`) — i.e. the introspection path of §3.2 is meant to supersede even this.

### 4.2 The discriminant scaled to ~40 species — and its known flaw

CoC's two-way `dogScore vs foxScore` became, in TiTS, a `race()` selector (`Creature.as:9617-9701`) over **~40+ `*Score()` feature-counters** (`canineScore` `:9966`, `felineScore` `:10015`, `kitsuneScore` `:10151`, `myrScore` `:10175`, …). Each score is the same additive template, now using flag/collection helpers instead of bare ints: e.g. `canineScore` (`:9966-9976`) counts `InCollection(earType, TYPE_CANINE, TYPE_DOGGIE)`, furred canine tail, digitigrade canine legs, canine face, and gates the genital bonus on `counter>1 && cockTotal(TYPE_CANINE)==cockTotal() && totalKnots()==cockTotal()`. Same "gate the soft signals behind ≥1 hard signal" discipline as CoC's `dogCounter>0` clause.

**But the selection is NOT argmax.** `race()` is a long *sequential* `if (xScore() >= threshold) race = "x"` waterfall (`:9636-9698`), where later assignments overwrite earlier ones and ad-hoc `&& race == "human"` / `&& race != "ausar"` guards patch the ordering by hand. The result is order-dependent: "whatever lands last with a passing threshold wins, modulo special-case guards."

The authors **document this as a known defect** in a comment block (`:9624-9632`): the *intended* design is "execute ALL scores, **scale** them by each species' natural max, pick the HIGHEST, tie-break by highest natural max." That is a normalized argmax — and it is the design aeriea should adopt directly, because TiTS wrote down the right answer and then shipped the wrong one. The CoC two-way `>=` compare (§2.3) is actually *closer* to the intended argmax than TiTS's grown waterfall; TiTS scaled the feature-scoring up but regressed the *selection* into a fragile ordered cascade.

---

## 5. Concrete implications for aeriea's prose realizer

The two-layer split is correct prior art; the implementation specifics are mostly cautionary. Mapping each finding to an aeriea decision:

1. **Adopt the two-layer split, but make Layer 2 the typed seam.** Author markup (Layer 1) over state-keyed descriptor functions (Layer 2), coupled only by a dispatch table. This is validated by two independent generations of the same lineage. aeriea's typed body/tag system is exactly the `checkCondition` whitelist / `getDescription` switch — except aeriea can make it a *typed* dispatch (tag enum → descriptor) instead of a stringly-typed `switch`, eliminating the "unknown tag" error class at compile time.

2. **Derive identity by scoring the trait bag; never store "species."** The `dogScore/foxScore` → argmax pattern is the keystone takeaway. Store independent typed traits (ears, tail, legs, face, genitals, skin); compute species/identity on demand as `argmax(normalize(score_i(traits)))`. This survives piecemeal transformation, which a stored species field cannot. (Cross-ref: aeriea's body/tag model — this is where the `frond` tag system from `playmate` and this scoring approach meet.)

3. **Use TiTS's *intended* selector, not its shipped one.** Implement the normalized-argmax with natural-max tie-break that TiTS's `race()` comment (`Creature.as:9624-9632`) describes but never built. The shipped ordered-`if` waterfall is the anti-pattern: order-dependent, patched with ad-hoc guards, unmaintainable past ~40 species. Build the data-driven version: each species = a struct of `{trait_weights, natural_max, threshold}`; the selector is generic.

4. **Make the synonym pools DATA, with seeded selection.** CoC's pools are string literals weighted by `rand` bucketing (`cockNoun`, `:2227`); aeriea should make a pool a `{phrasings: [...], weights: [...]}` value and select with the **seeded deterministic RNG**, not `Math.random()`. This satisfies "data over code at a seam" *and* "deterministic seeded simulation" simultaneously — two aeriea principles that CoC's design violates on both counts.

5. **Determinism: the realizer must be a pure function of (state, seed).** CoC's per-call `Math.random()` (variant phrasing, 40%-display-rate clauses) means the same description re-renders differently — fine for Flash, fatal for aeriea's event-log replay invariant. Derive the realizer's RNG from the seed + a stable per-render key (e.g. hash of node id + state version) so a re-render of the same state yields identical prose. This is the single hardest non-negotiable delta from the prior art.

6. **Borrow the discretize-at-resolver trick.** CoC's `cumHigh/cumMedium/...` named bands in `checkCondition` (`:266-280`) let authors test semantic bands, not magic numbers. aeriea should expose body state to authors as named predicates/bands over the typed body, not raw scalars — keeps authored prose readable and decouples it from numeric tuning.

7. **Steal the output-polish pass.** TiTS's smart-quotes + `--`→em-dash + double-space collapse (`ParseEngine.as:585, 630-639`) is cheap and directly handles the "a clause didn't fire, leaving a gap" artifact that *any* optional-fragment realizer produces.

8. **Plan for a visual channel from the same state.** Both engines bind the *same* trait scores to prose only. aeriea's realizer + visual channel should both consume the trait bag and the derived species score — the discriminant becomes shared infrastructure (prose word-choice AND paperdoll/layer selection key off the same `argmax`), not two parallel implementations.

---

## 6. Gotchas / anti-patterns to NOT carry over

- **Stringly-typed everything.** Both engines dispatch on string tag names and integer-coded enums with comment legends (CoC `cockType` 0–10). Errors are runtime inline strings (`!Unknown tag!`), never caught at author time. aeriea has a type system; use it for the tag vocabulary and the body enums.
- **Engine edits to add a testable property.** CoC's `checkCondition` whitelist means a new conditionable stat = an engine edit. TiTS's introspection (`getObjectFromString`) fixes this by exposing the object graph directly — adopt the *introspection-or-typed-reflection* approach so the author vocabulary grows with the data model, not with engine commits.
- **Greedy-regex parsing** (CoC) caps you at non-nesting `if`. If you write a string-rewrite parser, do depth-counted bracket matching (TiTS `recParser`) or a real tokenizer from day one.
- **Shipping a parser rewrite before re-porting an existing feature** (TiTS's missing conditionals in this snapshot). Finish the migration — conditionals + scene controls — before authoring content on the new core, or the new engine is silently a regression.
- **The ordered-`if` species waterfall** (TiTS `race()`). It does not scale and is unmaintainable; the authors knew and wrote the fix in a comment. Build the data-driven normalized-argmax from the start.
- **`Math.random()` in the realizer.** Nondeterministic; breaks replay. Seed everything.
- **No literal-bracket escape** (CoC). Trivial to add (TiTS's `\[`), painful to retrofit into authored content. Decide the escape syntax before any prose is authored.
- **O(tags × len) full-string rewrite per tag** (CoC). Acceptable at paragraph scale; do not build the realizer this way if descriptions get long or render hot.
