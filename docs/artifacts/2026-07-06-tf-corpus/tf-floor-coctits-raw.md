# TF PROCGEN FLOOR — RAW EXCERPTS (CoC / TiTS)

Provenance: excerpts pulled live from GitHub-hosted AS3 source (community mirrors of
Fenoxo's open code) + one CoC wiki page. CoC = `Ormael7/Corruption-of-Champions` (Xianxia
fork of Fenoxo original; descriptor engine is upstream-faithful). TiTS =
`Terridan/Trials-in-Tainted-Space`. Reached directly via curl of raw.githubusercontent.com
and the GitHub tree API. Line numbers are from the fetched files (2026-07-06).
Wiki page (miraheze CoC /hgg/) returned prose examples via WebFetch summarizer, NOT verbatim
quotes — flagged inline as [WIKI-PARAPHRASE].

===============================================================================
1. CoC — TIERED SIZE→ADJECTIVE ENGINE  (Appearance.as)
===============================================================================

## cockDescriptShort (Creature.as ~L3858) — length tiers, hard thresholds, rand-gated
```as3
if (rand(3) == 0) {
    if (cocks[i].cockLength >= 30)      description = "towering ";
    else if (cocks[i].cockLength >= 18) description = "enormous ";
    else if (cocks[i].cockLength >= 13) description = "massive ";
    else if (cocks[i].cockLength >= 10) description = "huge ";
    else if (cocks[i].cockLength >= 7)  description = "long ";
    else if (cocks[i].cockLength >= 5)  description = "average ";
    else                                description = "short ";
}
else if (rand(2) == 0) { // girth
    if (cockThickness <= .75) description = "narrow ";
    if (cockThickness > 1 && <= 1.4) description = "ample ";
    if (cockThickness > 1.4 && <= 2)  description = "broad ";
    if (cockThickness > 2 && <= 3.5)  description = "fat ";
    if (cockThickness > 3.5)          description = "distended ";
}
description += Appearance.cockNoun(cockType);
```

## cockAdjectives (Appearance.as L748) — the fuller tier ladder
```as3
if (rand(4) == 0) {               // ~25% of the time we mention length at all
    if (len < 3)  {little|toy-sized|tiny}
    else if (<5)  {short|small}
    else if (<7)  {fair-sized|nice}
    else if (<9)  {long|lengthy|sizable}
    else if (<13) {huge|foot-long}
    else if (<18) {massive|forearm-length}
    else if (<30) {enormous|monster-length}
    else          {towering|freakish|massive}
}
else if (rand(4)==0) {            // thickness ladder
    <=.75 narrow; <=1.1 nice; <=1.4 {ample|big}; <=2 {broad|girthy};
    <=3.5 {fat|distended}; else {inhumanly distended|monstrously thick}
}
// FINAL FALLBACKS keyed on lust, not size:
else if (lust > 90) { cumQ 50-200 -> "pre-slickened"; cumQ>=200 -> "cum-drooling";
                      else {throbbing|pulsating} }
else if (lust > 75) { ... "rock-hard" ... }
```
Note the explicit dev comment preserving Fenoxo's original weighting:
`// there is no other easy way to preserve the weighting fenoxo did`

## cockNoun (Appearance.as L411) — taxonomy = per-species randomChoice bag
```as3
HUMAN: randomChoice("cock","cock","cock","cock","cock","prick","prick",
                    "pecker","shaft","shaft","shaft");   // weighting via repetition
DOG:   randomChoice("dog-shaped dong","canine shaft","pointed prick",
                    "knotty dog-shaft","bestial cock","animalistic puppy-pecker",
                    "pointed dog-dick","pointed shaft","canine member",
                    "canine cock","knotted dog-cock");
FOX:   ("fox-shaped dong","vulpine shaft","pointed prick","knotty fox-shaft",
        "bestial cock","animalistic vixen-pricker","pointed fox-dick", ...);
```

## breastCup (Appearance.as L1911/1938) — integer index into a flat name array
```as3
BREAST_CUP_NAMES = ["flat", "A-cup","B-cup","C-cup","D-cup","DD-cup",
  "big DD-cup","E-cup","big E-cup","EE-cup","big EE-cup","F-cup","big F-cup",
  "FF-cup", ... "JJ-cup","big JJ-cup","K-cup", ...];   // index up to ZZZ+
breastCup(size) = BREAST_CUP_NAMES[min(floor(size), len-1)];
```
Breast "description" is literally `array[floor(rating)]`. No prose variance at all.

## multiCockDescript (Appearance.as L2472) — count handled as string-assembly branch
```as3
if (currCock == 2 && same) descript += randomChoice("a pair of ","two ",
    "a brace of ","matching ","twin ") + cockAdjectives(avgLen,avgThk,...) + "s";
if (currCock == 3 && same) descript += randomChoice("three ","a group of ",
    "a <i>menage a trois</i> of ","a triad of ","a triumvirate of ") + ...;
// nonidentical -> randomChoice("mutated cocks","mutated dicks","mixed cocks",
//                              "mismatched dicks")
```

===============================================================================
2. CoC — TRANSFORMATION ITEM AS A SCRIPT  (GroPlus.as, canonical)
===============================================================================
GroPlus = the archetypal "grow the injection site" item. Full mechanism visible:
static per-branch blurb + rand() big/small split + stated measurement + lust bump.

```as3
// COCK branch:
outputText("You sink the needle into the base of your "
   + multiCockDescriptLight() + ".  It hurts like hell, but as you depress the
   plunger, the pain vanishes, replaced by a tingling pleasure...\n\n");
if (cocks.length == 1) {
   outputText("Your " + cockDescript(0) + " twitches and thickens, pouring more
      than an inch of thick new length from your ");
   increaseCock(0, 4); cocks[0].cockLength += 1; cocks[0].cockThickness += 0.5;
}
if (hasSheath()) outputText("sheath."); else outputText("crotch.");
dynStats("lus", 10); player.addCurse("sen", 2, 1);

// BALLS branch — the entire "1 in 4 BIG growth" pattern:
if (Utils.rand(4) == 0) {
   outputText("You feel a trembling in your " + ballsDescriptLight() + " ... You
      can tell they're going to be VERY effective.\n");
   game.player.ballSize += Utils.rand(4) + 2;
   outputText("They shift, stretching your " + sackDescript() + " tight as they
      gain inches of size. ...");
} else {
   game.player.ballSize += Utils.rand(2) + 1;
   outputText("You feel your testicles shift, pulling the skin of your "
      + sackDescript() + " a little bit as they grow to " + ballsDescriptLight());
}
if (ballSize > 10) outputText("Walking gets even tougher with the swollen masses
   between your legs.  Maybe this was a bad idea.");   // one hard-coded threshold gag

// CLIT branch — stated measurement, canned:
outputText("Your " + clitDescript() + " stops growing after an inch of new flesh
   surges free of your netherlips.  It twitches, feeling incredibly sensitive.");
clitLength++;

// NIPPLES branch — stated fractional measurement:
outputText("Your nipples engorge... Abruptly you realize they've grown more than
   an additional quarter-inch.\n\n");
nippleLength += (Utils.rand(2) + 3) / 10;
```
Every branch: fixed opening blurb -> descriptor-function noun -> numeric mutation ->
"grew more than an inch/quarter-inch" -> `dynStats("lus", N)`. Psychology = a lust stat
increment. No interior reaction, no persistent character consequence.

===============================================================================
3. CoC — Mutations.as (demon/multi-cock TF) [WIKI/FETCH-SUMMARIZED code]
===============================================================================
Fetched via WebFetch summarizer over Mutations.as (paraphrase of real branching):
```as3
if (selectedCock < .5)  outputText("It stops almost as soon as it starts, growing
   only a tiny bit longer.");
if (selectedCock >= .5 && < 1) outputText("It grows slowly, stopping after roughly
   half an inch of growth.");
if (selectedCock >= 1 && <= 2) outputText("The sensation is incredible as more than
   an inch of lengthened dick-flesh grows in.");
if (selectedCock > 2) outputText("You smile and idly stroke your lengthening [cock]
   as a few more inches sprout.");
```
Same shape as GroPlus: delta bucketed into 3-4 hand-written sentences by magnitude.

===============================================================================
4. TiTS — SAME ENGINE, WRAPPED IN A BRACKET-TAG PARSER
===============================================================================
TiTS is a cleaner refactor: the tiered descriptor functions are identical in spirit
(cockDescript, multiCockDescriptLight, breast cup array in includes/appearance.as),
but text is authored with inline [tags] resolved at runtime by ParseEngine.as.

## singleArgLookups.as — the [noun] table maps tag -> descriptor function
```as3
"balls" : function(t){ return t.ballsDescriptLight(); },
"cock"  : function(t){ return t.cockDescript(0); },
"cocks" : function(t){ return t.multiCockDescriptLight(); },
"nipple": function(t){ return t.nippleDescript(0); },
"vagina": function(t){ return t.vaginaDescript(); },
```

## ParseEngine.as — documented syntax (verbatim from header comment)
```
[noun]                                  // simple PC stat noun
[if (condition) OUTPUT_IF_TRUE]         // conditional
[if (condition) TRUE | FALSE]           // if/else via "|"
[object aspect]                         // description of aspect of NPC/PC
// PRONOUNS: Elverson/Spivak (ey/em/eir) so NPCs can be written gender-neutral
//   and the parser fills he/she/ey at print time.
[screen (NAME) | text]  [button (NAME)| text]
```
So a TiTS TF line is authored as e.g. "Your [cock] twitches..." and the parser
substitutes the tiered descriptor. Same floor, better interpolation ergonomics +
gender-agnostic pronoun engine. The generative core (thresholds + randomChoice bags)
is unchanged from CoC.

===============================================================================
5. [WIKI-PARAPHRASE] miraheze CoC /hgg/ Transformative_Items
===============================================================================
WebFetch of the wiki was HTTP-403 on the item page in one attempt; the general page
confirmed items are documented as "consumable -> calls growTits/increaseCock/etc with
a rand() delta and prints a canned blurb." No additional verbatim prose captured beyond
the source excerpts above. Treat wiki as corroborating structure, not a quote source.
