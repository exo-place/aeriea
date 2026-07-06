# TiTS Transformation Mine — concrete instances

Source: Terridan/Trials-in-Tainted-Space mirror (open-source AS3), `classes/Items/Transformatives/*.as` (65 files, full directory), cross-checked against class logic (`shift*/create*/mod*/add*Flag` mutation calls, threshold-gated `<b>…</b>` change announcements, and in-fiction tooltips). All descriptions below are re-worded; short quoted fragments (<= a phrase) only where the exact wording is itself the detail.

Shared engine facts that shape every entry:
- **Body model is slot/flag based.** A creature has typed slots (skinType, faceType, eyeType, earType, tongueType, armType, legType+legCount, tailType+tailCount+tailFlags, wingType+wingCount, hornType+hornLength+horns, hairType) plus scalar meters (femininity 0–100, tone/muscle, thickness/fat, hipRatingRaw, buttRatingRaw, lipMod, breast rows each with rating+nipple props, balls count + ballSizeRaw, cock array each with length/thickness/type/flags, elasticity, fertilityRaw, libidoRaw, cumType/milkType/girlCumType fluid enums). TFs mutate these directly. "Type" changes carry sub-flags: e.g. legs get DIGITIGRADE / PLANTIGRADE / PAWS / HOOVES / FURRED / PREHENSILE; tongues get LONG / PREHENSILE / NUBBY; skin gets SMOOTH / FLUFFY / THICK / LUBRICATED / APHRODISIAC_LACED.
- **Most full-species TFs are incremental + stochastic.** One dose = a bounded number of changes ("changeLimit"/"changes"), each selected from a weighted pool of not-yet-applied steps, so a single species (myr, fox, cat, cow, etc.) takes many doses to complete and the *order* of body-part changes is randomized per dose. Each step is gated by prerequisites and "unlocked" checks (some races/perks lock certain slots).
- **Pace** for the big ones is generally "immediate on use, described as a minutes-long localized morph" per dose; nothing here is a slow multi-day arc except the egg/pregnancy items and status-timer items (Cerespirin, Goblinola, Foxfire) which apply over game-time via a status effect.
- **Reversibility.** No TF here self-reverses. The universal counter is **Immuno-Booster** (a separate Recovery item, referenced by Foxfire) which strips symbiotic/parasitic TFs. Some TFs are explicitly one-way (GaloMax "MAY BE IRREVERSIBLE"). Species TFs are reversed only by taking a *different* species TF, and cross-TFs actively strip incompatible perks/genes (see Red/Gold pills stripping Honeypot; Cerespirin removing wings).
- **Mind coupling is weak/localized.** TiTS keeps personality mostly intact; "mind" changes are libido/lust spikes, aphrodisiac side effects, bimbo/androgyny perks, and arousal from the TF process — not identity rewrites. Noted per entry where present.

---

## FULL-SPECIES / MULTI-SLOT TRANSFORMATIVES

### Red Pill / Gold Pill / Orange Pill — myrmedion (ant-people of Myrellion)
Source: `RedPill.as`, `GoldPill.as`, `OrangePill.as`. Author: Savin. Type: PILL. Near-identical engines; differ by which myr caste and hair/venom package.
- **Trigger:** swallow the striped nanomachine pill (Xenogen Biotech). Red = red-myr (warrior caste), Gold = gold-myr (honey caste), Orange = designed red×gold hybrid (Dr. McAllister).
- **Sequence (randomized per dose, bounded):** skin → strips fur/scales to bare human-type skin, or recolors existing scales to caste color; legs revert to terran/human legs; face → "altogether human" myr face; **eyes turn solid black and featureless**; grows **two long fleshy sensitive antennae/feelers** on the head; small **transparent vestigial myr wings** (too small to fly) sprout on cocked/leg-qualified bodies; lactation converted to **honey-nectar milk** (and can *start* lactation); ejaculate converted to honey cum; grows a **second pair of breasts**; on gold/orange, hair recolors to brilliant gold/orange or jet black + matching brows/lashes.
- **Caste-specific:** Red grants **red-myr lust-inducing venom**; Gold grants the **Honeypot gene** (thickness gains redirect into curviness instead of fat) and full honey lactation; Orange can grant either (red venom *or* honey/honeypot) and an **insectile abdomen growing from the back**.
- **Cross-strip:** taking Red *removes* Honeypot genes from a prior gold TF ("not compatible"); taking Gold *removes* red-myr venom. So the castes are mutually exclusive and re-dosing the other color actively undoes the incompatible trait.
- **Mind:** none beyond arousal; antennae are an erogenous zone.
- **Pace:** per-dose incremental; many doses to fully convert. **Reversibility:** only via another species TF. **Side effects:** honey cum/milk fluid change persists.

### Bovinium — cow-girl (New Texas bovine), feminizing
Source: `Bovinium.as`. Type: PILL. Tooltip: strongly feminizing, "capable of complete gender transitions," dramatic breast/lactation/fertility gains.
- **Trigger:** swallow the small bottle.
- **Sequence:** strips fur/scales/**goo** to plain human skin; face → human; **shrinks and removes cocks** one at a time (each shrinks, then the smallest "vanishes completely into the groin"); balls recede into the taint then vanish (**"Your balls are gone!"**); **grows a vagina** (clitLength 0.5) + femininity +5; **feminizes face**; **breasts swell + start/boost milk lactation** (milkType MILK); grows small **bovine horns** (length 3, count 2); grows a **cow tail** (multiple tails merge into one, LONG+FLUFFY); **bovine ears**; **thickness/fat +2 steps** (chubby, "delightfully thick and curvy"); **quad nipples** (nipplesPerBreast 4); **bipedal cow legs** with DIGITIGRADE + HOOVES + FURRED and curly fur to the upper thigh (genitalSpot reset); teat/nipple length +; **fertility +**; **libido +3–5** ("your cunt will be much wetter").
- **Mind:** libido raise; otherwise none.
- **Pace:** incremental. **Reversibility:** none native. **Side effects:** permanent milk/fertility uptick.

### Mino Charge — minotaur/bovine, MASCULINIZING (male counterpart to Bovinium)
Source: `MinoCharge.as`. Author: Couch. Type: PILL. Tooltip: heavy muscle/masculinity/potency, "capable of complete gender transitions" toward male.
- **Sequence:** strips fur/scales/goo → human skin; **removes vaginas** (smallest first), lowers elasticity; **grows an equine-shaped minotaur cock + sheath + a pair of balls** (ballSizeRaw ≈ 1.68·π, i.e. large) if none; if male already, balls grow +1–2 (Bulgy perk doubles); **stops lactation**; femininity −5 (down to min); **tone/muscle +2 steps**; **tallness +**; thickness +2; **butt shrinks** in graduated steps, hips pulled toward 4; lips shrink (lipMod−−); grows small **bovine horns** (grow with doses); **cow tail**, **bovine ears**; nipples de-multiplied to 1, nipple length−; **bovine legs** DIGITIGRADE+FURRED+HOOVES; **bovine muzzled face** (MUZZLED+LONG); thick fur skin (black/brown/white patterns); potency: cumMultiplier+, ballEfficiency+, refractoryRate+10, cumQuality+; **libido +3–5**.
- **Mind:** libido raise. **Pace:** incremental. **Reversibility:** none native.

### Catnip — feline (kaithrit-style), sleek/flexible/androgynous
Source: `Catnip.as`. Author: Etis. Type: PILL (medipen). "No known side effects." Very large, menu-driven ("Status report / Route available" — it presents which changes are pending).
- **Sequence (routes):** weight loss / less curvy / smaller butt; gender traits softened → **Androgyny perk** (face always androgynous); lips−; **elasticity + up to a cap** → **Flexibility perk** ("bend and stretch more than most creatures"); breast weight drop; **inverted nipples**; clit/cock length can shrink *or grow* to feline norms; **feline cock** (barbed spike type) and/or **pretty pink feline pussy** created; **genital slit** (genitals hidden) when ball-less; balls shrink + **Uniball** tight pouch to the back of the thighs; **feline tail** (tails merge; can carry a tail-cock or tail-cunt genital with a large flag set: TAILCOCK/TAILCUNT/PREHENSILE/SHEATHED/NUBBY/TAPERED); **feline ears**; **paw arms** (retractable claws, padded palms, FURRED); **digitigrade feline legs** with paw pads + claws — and a **taur route**: legCount can go 2→4→6, body "shortens up behind them, becoming more traditionally tauric"; **slitted cat-eyes**; fur skin (chance of FLUFFY); **feline muzzle** (whiskers, moist nose); beard replaced with **lynx-like sideburns** (beardStyle 11); **bristly feline tongue** (NUBBY), then LONG+PREHENSILE.
- **Mind:** Androgyny + Flexibility perks are behavioral/cosmetic. **Pace:** incremental, player-legible pending-list. **Reversibility:** none native.

### Nepeta — feline (kaithrit), FEMININE (lighter feline than Catnip)
Source: `Nepeta.as`. Type: PILL (baggie of treats). Tooltip: rework into "pleasingly feminine, feline form."
- **Sequence:** **feline ears** ("Meow!"); **slitted cat-eyes**; fur/scales/**goo** → human skin; **cat tail** (1, can grow a 2nd; scaled/furry tails molt/shed on the way); **human biped legs** (smooth, plantigrade) if taur — i.e. Nepeta pushes toward humanoid biped, not taur; **human face**; femininity +5 (cap 75); nipples → 1 per breast, "perfectly normal pink human nipples," sensitive; tallness ±6 (nudges toward a target height); breasts pump up to a pillowy size; **feline cock nubs** (shiftCock feline) + slight length loss; arms de-furred to human-like but with **retractable feline claws** on sharp nails.
- **Mind:** none. **Pace:** incremental. **Reversibility:** none native.

### Foxfire — red fox (vulpine), symbiotic fungus, permanent
Source: `Foxfire.as`. Type: POTION (applied to head/hair as "dye"). Author credit: Etis & DEM & Val. Notable framing: it's a *living symbiotic fungus*, not microsurgeons; **applies over game-time via a "Foxfire" status effect** (≈60–120 min timer) that fires the change log passively.
- **Product warnings (in-fiction, verbatim-structured):** head-only, no hair required; unpredictable on metamorphic species (rahn/galotian) or heavily-altered skin; re-dose while active does nothing; **permanent but cancelable with Immuno-Booster** (one dose enclosed); **conflicts with other symbiotes/parasites**; **documented side effect: bioluminescence**.
- **Sequence (passive, staged):** hair normalized (feathers/quills/tentacles/goo/transparent hair → regular), recolored to a fire color, can grow LONG; **pointy fox ears**; **slitted vulpine eyes**; **fox tail(s)** — grows one, then up to **nine tails** one at a time (kitsune scaling), FURRED/FLUFFY/LONG, can bear a knotted vulpine tail-cock or tail-cunt; cock → **canine sheath, then knot, then knot growth, then tapered** ("fox pecker"); **fox-cunt** vaginas; extra breast row + extra nipples, **black nipples**; balls shrink; skin → **fur** (fire color, FLUFFY); **fox legs** (biped or 4-leg taur, DIGITIGRADE+PAWS+FURRED) with pads, thick fur; **fox arms** (FURRED+PAWS); **vulpine muzzle face** (femininity pinned to 50, black lips); beard removed on furred muzzle (or restyled to sideburns); **vulpine tongue**; mimbrane (parasite) removed.
- **Frostfire** (`Frostfire.as`) = arctic variant of the same fungus: identical vulpine path but tuned for cold — adds **FLUFFY** flags throughout and grants **Icy Veins perk** ("body adapted to extreme winter cold"), heterothermic. Shares Foxfire's code (`frost` flag).
- **Mind:** none; process is arousing. **Pace:** over-time via status. **Reversibility:** Immuno-Booster (its selling point).

### Amber Seed — avian / griffin (FluidShift, "quick and painless")
Source: `AmberSeed.as`. Type: PILL. Fine print: "may cancel lactation in mammalian species." Griffin/feline/equine hybrid awareness baked in.
- **Sequence:** skin → **feathers** (avian skin tones; keeps FLUFFY as fluff); tail → **avian feathered tail** (prior tail goes limp/gooey and is reabsorbed); wings removed then **large avian wings** grown; **bird legs** (DIGITIGRADE+PREHENSILE+PAWS+FEATHERED, scale-like skin) — if one leg (naga) it "melts into a lifeless pool" then reforms as two; **avian arms**; head hair → **feathery plume**; ears → avian (or feline/equine if legs are cat/horse — griffin logic); **beak muzzle face** (lipMod −10, femininity 50); **avian eyes with functional nictitating membranes** (secondary eyelids); **avian tongue**; **genital slit**; balls pulled fully internal ("internal testicles") or shrunk; cocks shifted to avian (or equine/feline/snake to match leg type — chimera consistency); vaginas shifted to avian/feline/equine/snake with **elasticity bump**; nipples reduced/recolored, breast rows collapsed to one, **chest flattened**; **cancels lactation** (removes Mega Milk / Milk Fountain / Honeypot perks, milk zeroed); thickness/tone set toward lean; butt/hip caps depend on leg type. **Two perks at completion:** **Hollow Bones** (weighs less; gated on lean+toned+winged+avian arms+avian score) and **Oviposition** (regularly lays eggs when not pregnant) — "eggs have begun to form inside you."
- **Mind:** none. **Pace:** incremental, chimera-aware. **Reversibility:** none native.

### DracoGuard — gryvain (winged dragon-folk)
Source: `DracoGuard.as`. Author: Savin. Type: PILL (golden, from Gryvain Heartland Republic). Feminizing lean.
- **Sequence:** femininity + ("more feminine"); wings → **draconic wings** (scaly, talon-tipped), can build to **four wings** (a second pair) for flight; skin → **fine draconic scales** (lower body first, then whole body); grows a **draconic tail** (multiple tails merge to one); **human-looking dragon face**; **dark yellow slitted eyes with black tendrils** radiating from the iris (gryvain look); **majestic draconic horns**; **frilled reptilian ears**; breasts to C-cup / reshaped teats; **gryvain vagina** — a distinctive novelty: a ring of **six hyper-sensitive nub-clits just inside the lips, then ring after ring of clitorises deep into the canal** (count grows with doses); **gryvain cock** (~8", tapered, knotted/bulbous base, leaking tip), and mutates an existing cock to that shape; **knot grows to fist-thick**; junk-in-trunk (butt +); biped; **Hypermilky perk** (lactation never decreases from disuse/overfill).
- **Mind:** none. **Pace:** incremental. **Notable specific:** the stacking-clitoris-ring gryvain cunt is the signature novel anatomy. **Reversibility:** none native.

### Cerespirin — plant-nymph / dryad (bark-man or flower-girl fork)
Source: `Cerespirin.as`. Author: Nonesuch. Applies **over game-time via a "Cerespirin" status effect**; **environment-gated** — some steps only progress on a planet surface (not in ship interior), reflecting photosynthesis.
- **Sequence:** skin → **plant skin** (SMOOTH), then can harden to **BARK** (THICK); hair → **plant hair** or **tentacle hair** (green/plant colors); beard → plant/leafy; **dryad horns** — many antler-like horns (6 + rand, growing longer, up to 12–37"+); a **hair-flower** status; **flower arms**; vaginas shifted to **flower-type**; wings dropped then **cockvine wings** (vines tipped with cocks); cum → **fruit cum**, girlcum → **fruit girlcum**; **cunt-tails capped with orchid-like flowers** (petals open, dewy aphrodisiac aroma, APHRODISIAC_LACED). **Two forked perks:** **Resin** (masculine bark path — heavy bark skin: big protection, big slow, produces resin that makes needy species want to stick to you) and **Flower Power** (feminine flower path — pollen-producing nymph, arousing, an aura effect on foes).
- **Mind:** Flower Power adds an arousing aura/tease effect; aphrodisiac secretions. **Pace:** slow, over-time, place-dependent. **Reversibility:** none native.

### GaloMax — galotian goo-person (full liquefaction)
Source: `GaloMax.as`. Author: Fenoxo. Type: PILL (gelcap). **Explicitly "MAY BE IRREVERSIBLE."** Delayed: dissolves over **30–60 min** before working ("wait for that lump in your belly to dissolve"); can't stack while pending ("not going to risk turning into a puddle").
- **Sequence:** reorganizes biology into **hyper-efficient, highly-morphic goo** (galotian, like companion Celise) — goo skin/body, high morphic elasticity. (Effect resolves on the timer.)
- **Mind:** none stated. **Pace:** ~30–60 min delayed. **Reversibility:** flagged as possibly one-way (goo→normal is "harder"). **Notable:** one of the few TFs with an explicit irreversibility warning and a real time delay.

### BigGreenPotion — hradian (purple insectoid)
Source: `BigGreenPotion.as`. Author: Foxxling. Type: potion (crystal bottle, glowing green).
- **Sequence:** skin → bare human skin (recolored); hair → **vibrant purple, from the roots out**, grows past the shoulders; **human face**; **hradian antennae**; eyes turn bright purple; **fuckable nipples**; tits **leak yogurt** (novelty milk fluid); cock made "heavier/more solid," reshaped to a **bullet-shaped cock**; cum → **syrupy hradian cum**; girlcum → **syrupy hradian girl cum**; butt heavier; taur/extra legs **disintegrate into nothingness** leaving two human legs.
- **Mind:** none. **Pace:** incremental. **Notable:** yogurt lactation; bullet cock. **Reversibility:** none native.

### Goblinola — gabilani (goblin-like tech race)
Source: `Goblinola.as`. Author: Nonesuch. Type: bar/food; applies **over game-time via "Goblinola Bar" status**.
- **Sequence:** skin recolored/normalized to gabilani human skin; **long pointy gabilani ears** (2–5"); hair recolored; **irises fully black** (iris/pupil indistinguishable); **shrinks in height** over the hour; reverts non-human legs/arms to human and **removes tails** (gabilani are humanoid); **angular gabilani face** (via a delayed "Gabilani Face Change" sub-status); **gabilani cock** (removes genital slit); **gabilani vagina**; cum → gabilani cum; girlcum → gabilani girlcum; cumQuality/fertility small upticks. **Two perks:** **Fecund Figure** (hips/ass permanently enlarge during each pregnancy) and **Cybernetic Synchronization** ("body and mind become one with machine" — each cybernetic implant grants extra intelligence).
- **Mind:** Cybernetic Synchronization is framed as a mind-machine merge but mechanically an INT bonus scaling with implants. **Pace:** over-time. **Reversibility:** none native.

### KerokorasVenom — kerokoras (poison frog-people), feminizing
Source: `KerokorasVenom.as`. Author: Gardeford.
- **Sequence:** fur/scales/goo → smooth skin (SMOOTH flag); **frog eyes** (novelty: on black-eyed users, "blocky, almost digital-looking iridescent plus-signs" for pupils); **creates a vagina** + femininity +; nipples flatten/invert then normalize; **frog ears** (earLength 0); **frog tail** (SMOOTH+STICKY); **sticky webbed frog hands/arms** (SMOOTH+STICKY); **frog legs** (DIGITIGRADE+SMOOTH+STICKY) or revert to human; **long sticky smooth frog tongue**; skin recolored to kerokoras patterning; **lust-venom sweat** (skin gains APHRODISIAC_LACED) + **lubricated skin** (LUBRICATED); **frog face**; hips/butt +; fertility +; removes horns.
- **Mind:** lust-venom is an outward aphrodisiac (affects others). **Pace:** incremental. **Notable:** sticky/webbed limbs, lubricated aphrodisiac skin, plus-sign frog pupils.

### NyreanCandy — nyrea (ant-like egg-layers), hermaphroditic
Source: `NyreanCandy.as`. Author: JohanLitvisk.
- **Sequence:** **human face/legs**, removes tail and wings (nyrea are humanoid-chitin); femininity toward feminine; **black featureless eyes** ("like a nyrea"); **eight-inch elven/sylvan ears**; **black spiny hair** (QUILLS type — "feels pretty spiny"); **pale-white skin**; **black chitin** on arms/legs giving the look of "wearing a black corset / boots / gloves"; grows a **14-inch nyrean cock AND a nyrean pussy** (true herm — masturbates both on completion), or swaps existing single genital to the other so you end up dual; cum → **nyrea aphrodisiac lube**; girlcum → nyrea girlcum; **cum laced with nyrea eggs** — "as long as you stay fertile and keep gene-count high you'll produce nyrean eggs daily" (ovipositor cock flag + Nyrea Eggs status); **libido +**; can grant **Sterility perk** (and can undo sterility — bidirectional).
- **Mind:** libido raise, "should relieve this tension quickly." **Pace:** incremental. **Notable:** oviposition via cum; true-herm endpoint; sterility toggle.

### Lucifier — demon/succubus (candy), applies over time
Source: `Lucifier.as`. Author: Nonesuch. Type: candy; **"Lucifier Candy" status** delivers changes over game-time.
- **Sequence:** removes furry tail(s) and antennae; skin → smooth demonic skin (recolored to demon tones); **demonic horns** (2 → 4 → 6, lengthening 2→4→8"); **great curving demon rack** (horn set); a **demon cock-tail** (prehensile, long, knotted, nubby, with a tail-cock) OR plain demon tail; **demonic arms** — armored/chitinous or spiked variants; reverts exotic legs to human OR grows **succubus legs** (plantigrade, smooth, built-in **heels**); **mostly-human demon face** (smooth if not male); **demonic eyes**; **small demonic wings → full demonic wings**; **long prehensile tapered demonic tongue**; **demonic pointed ears**.
- **Mind:** none explicit. **Pace:** over-time. **Notable:** succubus legs come with permanent "heels"; cock-tail.

### Sylvanol — fantasy elf / fairy (dial-selectable flavor)
Source: `Sylvanol.as`. Author: Couch. Type: PILL (medipen with a color dial; each color = a different "fantasy creature" setting per an included pamphlet). Core is a **targeted ear TF**; flavor dial widens it.
- **Sequence (elf default):** **pointed elf ears**, then **lengthen with repeated doses** (1" and up); long ears become an **erogenous zone**. **Fairy setting:** smooth flawless skin; **fairy wings** (and a "shadowy fairy wings" dark variant); **ethereal hair**. (elf and fairy are the two dominant coded flavors.)
- **Mind:** none. **Pace:** incremental, targeted. **Notable:** the only user-configurable-target TF (dial picks the endpoint); erogenous ears.

### Ruskvel — raskvel (rabbit-reptile), from their staple food
Source: `Ruskvel.as`. Author: Nonesuch. Type: PILL (dumpling). Speed-themed lore.
- **Sequence:** sheds skin over "within the hour" → bare, then **scaled**; **raskvel ears**; **long blunt scaly raskvel tail** (flops, constant shifting sound); **feather hair**; **three-ball scrotum** in a tight **pouch to the back of the thighs** (Uniball/pouch); **purple smooth reptilian cock** — human-shaped but smoother, more sensitive, sheathed in a **warm genital slit**; **a second clit at the bottom of the vaginal opening**.
- **Mind:** none. **Pace:** incremental. **Notable:** three testicles; second (lower) clit; purple sheathed reptile cock.

### OvirAce / OvirPositive — ovir (reptile people)
Source: `OvirAce.as` (PILL), `OvirPositive.as` (medipen, injected). Both push toward ovir; Ace framed as "revert too-many non-native TFs back to ovir," Positive as the no-fuss injector.
- **Sequence:** cock length ±2" toward ovir norm; balls shrink; **cloaca** (genital slit); **human/ovir face** (muzzle recedes, beard removed, ANGULAR flag removed); **ovir ears**; scaled skin (recolored, ovir arm/leg SCALED+SMOOTH); femininity nudged toward a midpoint (~60, both directions); hips/butt nudged to caps; **snake eyes**; **long ovir tongue**; **ovir tail** (SCALED); ovir plantigrade scaled legs; breast rows trimmed. Potency tweaks (refractory/cum for the ball-less).
- **Mind:** none. **Pace:** incremental, homeostatic (pushes values toward ovir targets from either side).

### Taurico Venidae ("Deerium") — deer-taur
Source: `TauricoVenidae.as`. Authors: Wsan; Fenoxo & Wsan. Type: PILL (medipen). Cosmetic, "antlers for males."
- **Sequence:** **lightly-furred deer ears**; **short fluffy deer tail**; brown (or **white-spotted/dappled brown**) fur on the lower body; **deer legs** → **four-legged deer taur** ("splitting in half" into a pair, then tauric, DIGITIGRADE+HOOVES+FURRED, genitalSpot 2); "altogether human" upper face; **thick flared equine cock** (for males); feminine sex option; tallness −3–13 (deer are lithe); **antlers** (males) growing with doses.
- **Mind:** none. **Pace:** incremental. **Notable:** dappled-fawn coat; explicit body-split-into-taur description.

### Huskar Treats — huskar (arctic ausar/husky), from Ausar Treats
Source: `HuskarTreats.as`. Type: PILL (bone-shaped treat). Uvetan-cold adapted ausar; females curvy, males muscled.
- **Sequence:** **A-cup → up to DD-cup breasts** ("as big as an ausar would get"); **two ausar (dog) legs**; **ausar dog-tail** (tails merge); **ausar wolf-ears**, canine ears → **floppy dog ears**; **thickness +5** (cap 75); butt/hip +; fur gains **FLUFFY**; **Regal Mane perk** — a **fluffy fur collar/mane around the neck** (accompanies a chest fluff-ball).
- **Mind:** none. **Pace:** incremental. **Notable:** cold-adapted fluff everywhere; mane.

### RubberMade — living latex/rubber (goo-latex)
Source: `RubberMade.as`. Author: Adjatha.
- **Sequence:** **latex hair** (black); **rubber/latex skin** (black, SMOOTH); black lips (lipMod raised to 7 if lower); **Black Latex perk** — "hyper-sensitive latex skin keeping you constantly at least a little aroused."
- **Mind:** permanent low-level arousal from the skin. **Pace:** applied in steps. **Notable:** the perk couples the material to a persistent lust baseline — the closest thing to mind-coupling in the catalog (a body-driven constant arousal).

---

## SINGLE-AXIS / TARGETED TRANSFORMATIVES

### ManUp — facial masculinization + selective de-feminization
Source: `ManUp.as`. Author: Lashcharge. Type: PILL (JoyCo injector, blue fluid). Banned/lobbied-around lore; a patched variant refuses to transform feminine genders.
- **Guaranteed per dose:** **femininity drops** (−1 to −20 in weighted tiers, each with its own facial-morph prose — bones "whir into motion," an **adam's apple forms**, jaw squares, nose bigger); threshold announcements at fem 90/80/72/65/55/45/35/28/20/10 mark the visible masculinization.
- **Plus one random secondary** (weighted pool): **grow a first cock** (4"×1", then morphed to your race's cock type from a huge per-race switch — equine flare, canine knot, feline barbs, avian, naga, bee foreskin, kui-tan triple-knot, gryvain ribbed scales, demon nodules, etc.; then it grows a urethra/prostate/cum-vein in stages and "cums thrice"); **grow a first pair of balls** (empty sack forms, then testicles descend); lips−; hips− (straighter); butt− (firmer/tighter); **tone +3–5**; **grow/lengthen a beard** (staged: stubble → five-o'clock shadow → half-inch → 1" → longer, may need re-styling); **shrink breasts** by a cup (→ flat, or "impressive pecs" if toned).
- **Mind:** none. **Pace:** one facial step + one body step per dose. **Notable:** the race-keyed cock-shape switch is the most elaborate single mechanic; masculine-gender lock.

### Gush — breast/lactation/libido inflator
Source: `Gush.as`. Type: PILL (spraypen). "Illegal on almost every civilized planet"; raises libido "to uncontrollable levels."
- **Sequence:** starts/boosts **lactation**; **bust size up in tiers** (decent rack → larger → "more boob than one person can handle" → traffic-stopping); **libido climbs in tiers** ("higher" → "more libidinous" → "getting really libidinous" → "going to turn you into a slut" → lay-off warning); mammary storage/elasticity up ("milk-squirting machine"); **nipples split into multiple teats connected by enlarged areolae** ("twice the milkspouts, twice the pleasure").
- **Mind:** escalating libido is the whole point — the drug is written as compulsion-forming ("better lay off this stuff"). **Pace:** incremental. **Reversibility:** none native.

### JunkTrunk — butt enlargement
Source: `JunkTrunk.as`. Author: JohanLitvisk. Type: PILL. "For those with an affection for callipygean derrieres."
- **Sequence:** **buttRatingRaw +** (cap 20), tingling/expanding cheeks, "massively expanded ass."
- **Mind:** none. **Pace:** per dose. Single axis.

### DendroGro — cock GIRTH only (not length)
Source: `DendroGro.as`. Type: PILL (medipen). "Girth over length" — fattens tissue, widens veins.
- **Sequence:** injected cock **thickens** (cThicknessRatioRaw += 0.1 per step, staged base-to-tip); explicit warning that overuse makes it un-fittable for most partners.
- **Mind:** none. Single axis (thickness). **Reversibility:** none native.

### Virection ("CockUp / Penismightier / BigD") — cock length/thickness/virility, can add cocks
Source: `Virection.as`. Author: Lashcharge. Type: DRUG (blue pill, Tamani Corp). Lore: a "glitch" that grew disfigured penises, later stabilized.
- **Sequence:** **grows a cock if you lack one**; so potent it can cause a **supernumerary penis** — an existing cock can **split lengthwise into two identical cocks**; otherwise increases **length (up to double)**, **thickness** (stacking tiers, "even thicker than before"), or **virility** (cumQuality +1); re-derives cock values.
- **Mind:** none. **Pace:** per dose, random among the axes. **Notable:** cock-splitting into two.

### Circumscriber — REMOVES sheath/foreskin, minor cock shrink
Source: `Circumscriber.as`. Author: Lashcharge. Type: cream (Blue Crab). Inverse of Turtleneck.
- **Sequence:** erases a **sheath** or **foreskin** (per-skin-type prose: fur hairs fall off, feathers off, scales flake, chitin cracks to dust, bark cracks, goo loses translucence), and/or negligibly **decreases cock length or thickness**.
- **Mind:** none. Single axis.

### Turtleneck — ADDS a sheath/foreskin matching your skin
Source: `Turtleneck.as`. Author: Lashcharge. Type: cream. Inverse of Circumscriber.
- **Sequence:** grows a **sheath over the cock, textured to the user's skin type** — furred mat, feather pillow, smooth scales, chitinous guard, ridged bark, jello (goo, "fails to hide your dick"), stretchy latex, or hairless plant sheath.
- **Mind:** none. Single axis. **Notable:** the material of the new sheath is keyed to current skin type.

### BumpyRoad — nubs/texture on cock and/or vagina
Source: `BumpyRoad.as`. Author: Lashcharge.
- **Sequence:** **cock becomes covered in nubs** and/or **vagina becomes covered in nubs** (added stimulating texture).
- **Mind:** none. Single axis (texture).

### Equilicum / Equilibricum — balances ball size vs. cum volume, can grow extra balls
Source: `Equilicum.as`. Author: Altair Hayes. Type: DRUG (needle, ~250mL, milky blue). Warning: big size/volume imbalance may **grow extra testicles**.
- **Sequence:** adjusts **ballSizeRaw and ballEfficiency toward balance** with cum output; if imbalanced, **grows +2 balls** (new nuts grow into a freshly-developed scrotum, stretching the sack).
- **Mind:** none. Single axis (testicular economy). **Notable:** homeostatic — pushes two coupled values into equilibrium.

### Furball — extra/fluffier balls (candy)
Source: `Furball.as`. Author: WorldOfDrakan.
- **Sequence:** grows a **second pair of balls (→4)** or another testicle; loosens a tight package into a normal pair; makes balls **soft/fluffy** ("Special Scrotum: FURRED", tooltip colored to hair); ball size +; can grow a first pair (which without a cock "are kind of just there"); "Fuzzball Candy" status.
- **Mind:** none. Single axis (balls). **Notable:** furred-scrotum status.

### SaltyJawBreaker — tops up cum reserves (candy)
Source: `SaltyJawBreaker.as`. Author: Lashcharge.
- **Sequence:** **fills ballFullness to 75** (loads you up with cum); no effect if you have no cock/balls or are already full ("more useful to someone who isn't so full of cum already").
- **Mind:** none. Single axis (cum reserve).

### NukiNutbutter — 'Nuki Nuts (swelling cum-storage gonads)
Source: `NukiNutbutter.as`. Author: Savin. Type: paste rubbed onto the sack.
- **Sequence:** **cumMultiplier up** (big jumps toward a 9000 cap), **ballEfficiency up**, **ballFullness +100** (loads up); grants **'Nuki Nuts perk** — gonads swell with excess semen for "excessively large orgasms," with an **immobilization** risk when overfull; balls feel putty-soft/malleable.
- **Mind:** anticipation/arousal prose; wanting to be visibly, "explosively pent up." **Pace:** per use. **Notable:** the swelling can immobilize you.

### SumaCream / SumaCreamBlack / SumaCreamWhite — testicle enlargement (color variants, same effect)
Source: `SumaCream.as` (+`SumaCreamBlack.as`/`SumaCreamWhite.as` delegate to `SumaCream.sumaEffects` with a color param). J'ejune product, rubbed onto the sack.
- **Sequence:** **ballSizeRaw +1 per use** (Bulgy perk doubles it), up to caps; needs both a cock and ≥2 balls for full effect (otherwise grows a missing 2nd ball first, or only tingles); a **kui-tan** genetic quirk path: instead of steady growth, triggers **rapid-fire dry not-orgasms** that inflate the balls to maximum fullness in waves ("What the Void is going on?!"); very large taur bodies can't reach their own balls (partial effect).
- **Mind:** none. **Pace:** per use. **Notable:** kui-tan-specific inflation-by-orgasm-wave branch; the three colors are cosmetically distinct but mechanically identical.

### OrangePill see myr section. (listed there)

### Hornitol — horns (rhino / unicorn-narwhal)
Source: `Hornitol.as`. Author: Couch. Type: injector.
- **Sequence:** grows a **3" rhinoceros horn** or **4" unicorn/narwhal horn** (microsurgeons "adapt your head to hold the new weight"); re-dosing lengthens (6"/8"), **adds more horns** (1→2→3, up to multi-horn), can **convert rhino↔narwhal type**, and keeps lengthening (rhino to 48", narwhal to 60").
- **Mind:** none. Single axis (horns). **Notable:** two horn archetypes, count and length both scale, type is switchable.

### DoveBalm — dove wings (2 / 4 / 6)
Source: `DoveBalm.as`. Author: Couch.
- **Sequence:** grows **feathered dove wings** matching fur color; wing count cycles **2 → 4 → 6** (extra pairs), and can settle back to a "standard single pair" when they cool off.
- **Mind:** none. Single axis (wings/count).

### RainbowGaze — eye color
Source: `RainbowGaze.as`. Author: Couch.
- **Sequence:** sets **eye color** ("Your eyes are now [color]").
- **Mind:** none. Purely cosmetic, single axis.

### ClearYu — femme-fatale cosmetic bundle (lollipop)
Source: `ClearYu.as`. Author: Adjatha. Type: candy lollipop, "heavier than it should be."
- **Sequence:** **ruby-red lips** (lipMod +2, color ruby); **raven-black hair** grown very long (toward full-body length); **tallness +** (to at least 102"/8.5ft target); grants **Sweet Tooth status** ("sucking seductively on a lollipop," ~12h).
- **Mind:** the Sweet Tooth status is a flavor/tease pose. **Pace:** per use, converges toward fixed targets. **Notable:** pins to specific values (ruby lips, raven hair, min height) rather than incrementing freely.

### LipTease — lip / nipple size + color applicator
Source: `LipTease.as`. Author: MistyBirb. Type: dual-ended applicator (one end enlarges, one shrinks).
- **Sequence:** **lip size ±** and **lip color** change; separately, **nipple width ±** and **nipple color** change (same tool applied to nipples).
- **Mind:** none. Single axis (lips/nipples). **Notable:** directional (which end you use decides grow vs. shrink).

### Clippex — nipple length (gel, over time)
Source: `Clippex.as`. Author: Nonesuch. Type: gel; **"Clippex Gel" status** works over game-time.
- **Sequence:** adjusts **nippleLengthRatio** — grows or shrinks nipple length in steps (down to a 0.25 floor).
- **Mind:** none. Single axis (nipple length). **Pace:** over-time.

### Peckermint — peppermint-striped cum + candy-cane cock stripe (holiday)
Source: `Peckermint.as`. Author: Altair Hayes.
- **Sequence:** cum → **peppermint flavor**; cock gets **red-and-white candy-cane stripes** "from head to base."
- **Mind:** none. Cosmetic/fluid, single axis.

### Nutnog — eggnog cum (holiday)
Source: `Nutnog.as`. Author: Altair Hayes.
- **Sequence:** cum → **eggnog flavor** ("tastes just like eggnog"); no-op if already eggnog.
- **Mind:** none. Fluid change only.

### SemensFriend — chocolate cum + testicle boost (holiday)
Source: `SemensFriend.as`. Author: Nonesuch. Type: candy; **"Semen's Candy" status**.
- **Sequence:** grows a **first pair of balls** (or up to 4 in stages: solo Uniball → hanging pair → "second pair of balls"); ball size +; ballFullness loaded; refractoryRate +; cumQuality +; cum → **chocolate** ("you now ejaculate chocolate").
- **Mind:** none. **Notable:** chocolate ejaculate + staged ball-count growth.

### Honeyizer — honey lactation
Source: `Honeyizer.as`. Type: PILL (Xenogen; box shows a bee-girl). 
- **Sequence:** milk → **honey** fluid; milk storage multiplier + (cap 3); can **start lactation** (milkMultiplier 70); no-op if already honey.
- **Mind:** none. Single axis (milk fluid/volume).

### SweetSweat — pheromone sweat
Source: `SweetSweat.as`. Author: Altair Hayes. "Effects are permanent."
- **Sequence:** grants **Pheromone Sweat perk** — pheromones boost tease-attack and arousal while sweating.
- **Mind:** the sweat is an outward social/combat tool (affects others' arousal). Single axis, **permanent**.

---

## BREEDING / EGG ITEMS (transform reproductive state, not body slots)

### Ovilium Eggs — blue / pink / white × small / large (6 items)
Source: `EggBlue/Pink/White` × `Small/Large.as`. Type: FOOD; combat-usable, self-target. Each delegates to `kGAMECLASS.eatOviliumEgg(size, color)` (logic lives in the game class / `OviliumEggPregnancy.as` handler, not the item file).
- **Trigger:** eat an Ovilium egg (Ovilium = the white fluid, item `Ovilium.as`, that seeds egg-laying capacity via `oviliumEffects()`). Color and size are the two parameters (small vs large = clutch scale; color = variety).
- **Effect:** installs a temporary **egg-pregnancy** — the eater gestates and later **lays eggs** of the matching type; a breeding/oviposition mechanic rather than an anatomical morph. (Full per-color payload is in the pregnancy handler, not captured from the item files.)
- **Mind:** none. **Pace:** gestation over game-time. **Reversibility:** resolves by laying.

---

## NON-TF ITEMS FILED UNDER Transformatives (flagged for completeness)

### GooBall (Blue/Green/Orange/Pink/Purple/Red/Yellow) — 7 items
Source: `GooBall*.as`. Author: Gardeford/Zeikfried. Type: PILL by enum but **not a transformative** — "leftover ganrael gloop" used as a **light hair-fixative/styling gel** ("could hold something light in place, like hair"). No body mutation. Color = cosmetic only. (Present in the folder; included so the count is honest.)

### DongDesigner — a ship gadget, not a consumable TF
Source: `DongDesigner.as`. Type: GADGET (TamaniCorp Hora Series). Installed into the ship; **lets you reshape your penis's appearance to any race** on demand via a menu ("found on a junkyard, so maybe something's strange about it"). Cosmetic cock-type reshaper, repeatable, non-consumed. Functionally a free race-swap for cock type.

---

## COVERAGE / LIMITS / GAPS

- **Captured:** all 65 files in `classes/Items/Transformatives/`. Of these: ~30 substantive species/targeted TFs fully detailed; 7 GooBalls (non-TF hair gel); 6 Ovilium eggs (breeding, payload lives in a pregnancy handler not the item file); DongDesigner (ship gadget); 3 Suma variants collapsed (identical effect).
- **Fidelity:** entries are built from (a) in-fiction tooltips = designer intent, (b) the `<b>…</b>` change-announcements = the concrete stated body deltas, and (c) the actual mutation calls (`shiftCock`, `createVagina`, `add*Flag`, `*Raw +=`, perk grants) = the mechanical truth. Randomized selection order, per-dose bounds, unlock-gates, and race/perk branches are reflected. I did **not** transcribe the long templated prose bodies; templates use `[pc.xxx]` interpolation and I recorded what they vary, not the prose.
- **Gaps / not fully resolved:**
  - **Ovilium egg per-color payloads** (blue vs pink vs white differences) are not in the item files — they live in `classes/GameData/Pregnancy/Handlers/OviliumEggPregnancy.as` + `eatOviliumEgg` (an includes file I did not open). Only the delegation and the size/color parameters are captured.
  - **GaloMax's** actual goo-conversion body writes resolve on a 30–60 min timer; the item file sets up the delay but the resolved slot changes are applied elsewhere (status resolver) — captured intent (full galotian goo, irreversible), not the exact resolved slot list.
  - **Sylvanol's** full dial/pamphlet flavor list beyond elf + fairy is not enumerated in a clean list; those two are the dominant coded paths.
  - A handful of small items (`OvirPositive` vs `OvirAce` share most logic; `SumaCreamBlack/White` share `SumaCream`) were collapsed by shared code rather than re-derived line-by-line.
  - This is only the dedicated `Transformatives/` folder. Some transformative-adjacent consumables may exist under `Items/Drinks/`, `Items/Miscellaneous/` (e.g. `Ovilium.as`), or as NPC-encounter TFs (milk/cum sources, parasites like the cockvine/mimbrane, the Treatment/bimbo arcs) — **not** swept here; the prompt scoped "TF items/serums" and this folder is the canonical serum catalog.
- **No taxonomy / thesis added** per instruction — this is instance-level only. The shared-engine preamble states mechanical facts (slot model, per-dose stochasticity) needed to read the instances, not conclusions about design.
