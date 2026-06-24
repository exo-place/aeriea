# Defect Compendium — All User-Reported Defects Across Sessions

**Status:** REFERENCE / consolidated record. This is the durable, verbatim archive
of *everything the user reported as broken, garbage, slop, or wrong* about aeriea
across the Claude Code sessions — mined from the raw `.jsonl` transcripts so nothing
is lost. It complements `SESSION-RECORD.md`: that doc's "rage-list" captures only the
final-day creator state; **this doc is the complete cross-session set**, organized by
surface. Where it is easy to attribute, each batch is tagged with the session it came
from.

Sessions mined (aeriea project transcripts in
`~/.claude/projects/-home-me-git-exoplace-aeriea/`):

- **PREV** — `48dd9f90-0c5c-4644-857a-f051d87ac23c.jsonl` (2026-05-30 → 2026-06-13;
  movement + body + character-creator track). 137 human text turns.
- **CURR** — `f4ea89ef-c7d6-4045-be8c-08b748265aed.jsonl` (2026-06-14 → 2026-06-24;
  prose-gen pivot + BDCC2 mining + embodiment blitz + creator rebuild + shelving).
  174 human text turns. (Note: despite the handoff prompt labeling f4ea89ef the
  "previous" session, by content timestamps it is the most recent / current one.)
- `cd49ef9c-…jsonl` (2 real text turns) and `5eaf4e65-…jsonl` (2 real text turns)
  were also extracted and inspected: **no defect feedback** in either (handoff plan +
  two design questions). Not a source for this compendium.

Quotes are verbatim (the user's blunt/profane style preserved). Exact repeats are
de-duplicated; near-repeats with added content are kept. Light grouping only.

---

## Character creator & body

### Body mesh / geometry / shading (mostly PREV, continued in CURR)

- "why the fuck is it only showing backfaces / also the sliders kinda work but they
  also change size which is like, ???" (PREV)
- "proportions slider does nothing / backfaces still broken / mesh change is correct
  now / normals are fucked when blendshape is applied for some reason" (PREV)
- "btw the backface stuff is STILL not fixed." (PREV)
- "that image is what i see. HOWEVER. the ENTIRE FUCKING BODY is backfaces and it is
  EXTREMELY FUCKING OBVIOUS if you rotate the view AT ALL" (PREV)
- "are you SURE they're not MISREADING the fucking image. did they even write the
  screenshots anywhere." (PREV)
- "i have EXPLICITLY CONFIRMED that the agents' output is IDENTICAL to mine and that
  IS the wrong way around" (PREV)
- "why the fuck are there little dots of geometry all over the place on the model"
  (PREV)
- "uvs not fixed lmao. nothing changed" (PREV)
- "the running game / the running game / wrong coords" (where the broken UVs are
  visible — PREV)
- "look at the first one and tell me seriously it looks normal" (PREV)
- "i don't fucking know honestly. [Image] the fuck is this." (PREV)
- "it's possible that the normals are correct and it's the extra geometry/blendshapes
  that are completely fucked up / but are we even applying any blendshapes at all /
  the ear is in the wrong place / how does that happen / meshes don't just break like
  that / unless they do / also the resting pose is even more fucked up" (PREV)
- "camera ACTUALLY inside skull now :/" (PREV)
- "geometry's even more fucked now (or as fucked)" (PREV)
- "good news … that fixed all the geometry, including the face. bad news, lighting
  looked good before the fix, bad after the fix. seems like the lighting is inverted
  (?) … maybe the normals for the lighting specifically are broken" (PREV)
- "[idle-blend 'fix'] that just hides the problem :/ fixes absolutely nothing" (PREV)
- "facial additional meshes (eyes, tongue) are only correct at male height, not
  neutral or female height / also eyebrows and eyes look comically bad / also the
  entire body looks low poly because it is, but i think it might be a lack of normal
  maps/interpolation that's hurting the most / also breast size slider seems to be
  the wrong morph / also there are various shading seams visible in various places,
  e.g. back of the head in the middle, where the head joins to the neck, inner curve
  of the legs etc. is uv wrapping wrong again? coordinate space off?" (CURR)
- "are you 100% sure this is not a hack?" (re: "normals welded across UV islands" —
  CURR)
- "a) why's the mesh being cut apart  b) why would the normals change as a result of
  this" (CURR)
- "maybe fix it to be correc[t] by construction then…" (CURR)
- "the pupil/iris isnt even round, the fuck" (CURR)
- "body is too low poly, can we add a setting to control subdivision count" (CURR)

### Sliders / axes / morph semantics (PREV + CURR)

- "the sliders kinda work but they also change size which is like, ???" (PREV)
- "proportions slider does nothing" (PREV)
- "[Proportions kept as a 2-anchor approximation] the fuck. unacceptable" (PREV)
- "age being from 0 to 1 is so weird. also surely only genital detail targets should
  be nsfw gated, not the other two as well? ideally we should import the entire thing
  though i think. also gender being from 0 to 1… all of the numbers are so… weird…?"
  (PREV)
- "[femininity is a no-op axis] then why not a single sex axis…" (PREV)
- "i don't like the masculinity slider having a percentage but I SUPPOSE it's useful
  for sharing characters via screenshots…" (PREV)
- "why is 'hips circ.' cut off like that" (CURR) … later corrected: "it's not
  clipped. the text literally says 'hips circ.' the column is wider than that" (CURR)
- "more meaningful sliders" (CURR — embodiment wishlist)
- "why can't i reset/randomize each slider/all sliders" (CURR)
- "why can't i input numbers" (CURR)
- "breast size slider seems to be the wrong morph" / "somehow none of the breast
  sliders are an actual breast size slider" (CURR)
- "why is it called 'masculinity' not 'gender' or 'presentation'" (CURR)
- "why the fuck would it randomize masculinity to an intermediate value" (CURR)
- "and why the fuck is height just scaling now, ugh, i thought it used to be
  connected to a morph. the actual height value should be a different field imo"
  (CURR)
- "what is height scaling based on age based on? why do they only grow to full height
  by 25 years old? is that realistic?" (PREV) … "uhh no. the height was literally
  changing until 25. not sure why but i know what my eyes saw." (PREV)
- "the age slider only goes down to 18" (CURR — also in SESSION-RECORD rage-list)
- "you have to manually type in a decimal to see it round" — sliders round to coarse
  0.5 / 1% increments (CURR)

### Creator UI / UX / layout (CURR, the big lists)

The first app-ran bug list (CURR, 2026-06-22, ending "and before you dare to bandaid
fix this, this is by no means a comprehensive list of issues"):

- "what is this hair"
- "why is aeriea character creators present twice at the top"
- "why does history say 'history - branch nave (root -> current'"
- "why does body regions - detail sliders" [sic — malformed/garbled UI]
- "too noisy, the ends of the and the values are nice but maybe they shouldn't show
  all the time"
- "text sizing is all over the place, we need it to be consistent in a design system"
- "why is 'hips circ.' cut off like that"
- "why can't i reset/randomize each slider/all sliders"
- "why is this garbage head mesh applying on top of the makehuman head mesh"
- "why are is the hair these ugly hair cards"
- "body is too low poly, can we add a setting to control subdivision count"
- "why can't i input numbers"
- "history should collapse changing the same value muliple times to a single entry
  (visually, not in the history log)"
- "why are the back/forward history arrows in a different corner than the history
  pane itself"
- "why is everything in its own corner of the ui"
- "why do the history back/forward buttons overlap the top bar"
- "why does aeriea need to advertise its own name"

Earlier creator-UI nits (PREV, 2026-06-13):

- "ERROR: Error opening file 'res://icon.svg'. … ERROR: Cannot open file from path
  'res://result/eye_brown.png.import'. (although interestingly the eye texture *does*
  work, although … i'd rather have procedural eye textures for a) arbitrary
  resolution and b) much more flexible customization like exotic iris/pupil shapes
  and sizes etc, specular vs diffuse maps, optionally normal maps etc)"
- "history tree being always visible is clutter. same with undo/redo being inside the
  main panel rather than icons in another corner"
- "history tree items being indented is stupid as it leads to history being diagonal.
  you'd rather have chatgpt-style branching imo (pseudo-linear history with left/
  right arrows to navigate at junction points)"
- "'export all 4' is garbage ux. why is that the only export option. also why no jpg
  or webp options with metadata, for smaller file sizes."
- "the fuck is the 'exports -> user://creator_exports/' text doing in the character
  creator"
- "controls legend shouldn't have smaller font… maybe it should appear - in yet
  another corner - only when holding ctrl, toggleable on and off by tapping ctrl"
- "repeating the same step shouldn't add multiple history entries"
- "'reset to neutral' should make a new branch from the root imo. and clicking 'reset
  to neutral' multiple times shouldn't make multiple empty branches"

The post-rebuild creator critique (CURR, 2026-06-23 — "it's absurd THIS is what
survived 10 adversarial rounds holy fuck"):

- "a dropdown PLUS FOUR BUTTONS is wa[y] too excessive for export, as well as import"
- "why the FUCK are there still panels fucking EVERYWHERE, some even overlap"
- "in the history the same value changing multiple times isn't collapsed visually"
- "'T1 - headline (always visible)' - what is this STUPID FUCKING SLOP THAT READS
  LIKE A CODE COMMENT"
- "why the FUCK is there a detail tier option. this is so comically performative
  'well the feature is there' i dont even know what to say"
- "the pupil/iris isnt even round, the fuck"
- "'randomize (within extremeness)' - what the FUCK does extremeness mean to the end
  user holy fuck"
- "oh great, randomize fucking FREEZES THE ENTIRE APP FOR SEVERAL SECONDS for some
  reason, the fuck is wrong with this constraint solver"
- "why the fuck would it randomize masculinity to an intermediate value"

Other creator-UX complaints (CURR):

- "oh yeah i forgot about also 3,000 different font sizes, and also a very lame,
  default looking ui"
- "it really feels like there's no consistency put into this entire thing at all, no
  thought put into it"
- "character in creator faces backwards by default which is insane"
- "no hand mirror/paper doll option like vrchat in the parkour sandbox" / "oh also no
  mirrors which is sad" (also relevant to movement sandbox)
- "and man. how the fuck is the character creator's ux so fucking bad"
- "the character creator is objectively poor ux. full stop."
- "[direct-manipulation drag-on-body] it is a solution i want and we were SUPPOSED to
  have for ages now. but irregardless i strongly believe it is insufficient by
  itself."
- "character creator is… technically works *now* but was still broken due to broken
  mesh interop as of the last time i checked. overall evaluation: fucking sucks"
- "like that's the only issue with the UI" (sarcasm — the undesigned default-Godot
  grey was *not* the only issue)
- "[creator UI needs its own design pass] wrong" / "[character-creator layout is a
  long-solved problem] a mess of sliders and buttons? yeah right" / "wrong" (CURR)
- "like, realistically, i don't expect to be able to make a good character creator,
  like, at all. so it's more of a pipe dream … actually honestly it's not too bad in
  terms of getting the actual morphs to work, huh?" (PREV — resigned)

> NOTE: `SESSION-RECORD.md` "rage-list" carries the final shelving-day creator state
> verbatim (top-bar overlap stranding History/Share/Open; region-pick-to-shape lost;
> age floor 18; coarse rounding; floating "start from a body"/"restored character"
> text; app-name chrome; 348×3344 Advanced popup; history overlay overlapping pinned
> strip; redundant undo/redo pair). Not duplicated here — see that doc.

### Embodiment "juice" wishlist / defects (CURR)

The user's concrete "the surface we should have mined from BDCC2" list:

- "hair physics" / "jiggle physics" / "more meaningful sliders" / "swappable body
  parts" / "animations, especially having those bound to the player controller" /
  "headlook" / "ik/fk" / "it probably doesn't have it but if we add saccades,
  breathing, subtle animations like that, that'd be nice"
- "the hair physics is kinda hot" / "jiggle physics too i guess but it seems a little
  overtuned ingame" (re: BDCC2)
- "why even pull in the bdcc head and feet model if it clearly doesnt work with
  makehuman shit" (CURR)

---

## UI & layout (cross-surface / design-system)

- "text sizing is all over the place, we need it to be consistent in a design system"
  (CURR)
- "3,000 different font sizes, and also a very lame, default looking ui" (CURR)
- "why is everything in its own corner of the ui" (CURR)
- "controls legend shouldn't have smaller font" (PREV)
- "[UI is undesigned default-Godot grey] like that's the only issue with the UI"
  (CURR — sarcasm; the grey is one of many)
- "no consistency put into this entire thing at all, no thought put into it … partly
  it's because of lack of communication between agents and lack of a concrete design"
  (CURR)
- "why does aeriea need to advertise its own name" / "why does aeriea need to
  advertise its own name" — the app-name chrome (CURR)
- "also no way to switch tabs from parkour sandbox???" — missing entrypoint switcher
  between modes (CURR; the user had asked for multiple entrypoints back in PREV:
  "ideally could we please have *multiple* 'entrypoints'… switch between character
  creator, parkour sandbox … and … text sandbox")

---

## Text sandbox

All CURR (2026-06-22 onward):

- "why the FUCK does the text sandbox take fucking NUMBERS holy FUCK"
- "what the FUCK is this, a CLI?"
- "actually gonna fucking DIE"
- "why is there an option whose number is 'wait'"
- "why does it explicitly say it advances time"
- "dont you DARE run it"
- "why the fuck does greeting increase arousal"
- "the text sandbox is also borderline unusable (only performatively usable)"
- "text sandbox is. well it also doesn't work."
- "that's so lame. telling not showing be like… also fixed options is questionable"
  (re: generated prose)
- "ugh. i don't wanna be annoying but wasting time explaining her reaction is
  extremely low quality. still telling not showing"
- "fundamentally, existence's prose is very very boilerplate" (prior-art prose)
- "what about nuance? variety is useless without the ability for sentences to have
  depth"
- "what i'm looking for is basically extremely - arguably unreasonably - high depth.
  how you make writing feel real is by … fleshing out the characters and world so
  that they're not two dimensional caricatures with zero nuance beyond three
  personality traits and some numbers"
- "your bar to beat is roleplay with opus 4.8. full stop. … that's not an excuse to
  accept complete and utter trash as the implementation"
- "i don't want LLM in the loop at all. but anything less than opus quality is
  unacceptable"

---

## Movement / parkour

PREV (the movement-prototype track):

- "what are the controls T_T / also the controls should be fully rebindable"
- "no teleport volume / mouse sensitivity defaults to 0??? / NONE of the issues i
  brought up were fixed????? / wallrun is CTRL?!"
- "no crosshair (eventually, configurable crosshair style would be cool) / jump and
  crouch STILL do not work"
- "it's… not v in warframe…" (bullet-jump binding)
- "bullet jump should jump in the look direction…"
- "collider seems misaligned with camera? when i stand under that highest platform
  and jump, i can see through it at the top of the jump"
- (from the PREV compaction summary, condensed-verbatim themes) "crouch jitters";
  "space for jump doesn't work??"; "default jump height seems pitiful"; "camera tilt
  in wallrun seems to be gone"; "wallrun is some kind of weird garbage automatic
  going forward"
- "this violates the composability rule/paradigm of our movement system. if our
  movement system is 'just' a state machine yet these still have to be hardcoded i
  feel like we're fucking something up here." (hardcoded AUTOMATIC_VERBS — PREV)

CURR (player rendering inside the movement sandbox):

- "movemennt animations don't work in the parkour sim"
- "character model is backwards in parkour sim"
- "camera clips into model in first person. how do normal first person games show
  chest without showing head? e.g. the final fantasy mod"
- "animations snap back to netural which is what the fuck"
- "idle anims work in parkour sim which is cool. breathing too" (a rare positive)
- "no hand mirror/paper doll option like vrchat in the parkour sandbox"
- "our movement sandbox is fine but the player character rendering in it is… it
  doesn't work"
- "also can't use wasd + space ctrl to fly camera" (creator camera, CURR)

> A dedicated `movement-backlog.md` (parkour/movement defects) is referenced by
> SESSION-RECORD.md as a separate, unstarted track.

---

## Cross-cutting & process (the "how did this happen" thread)

Quality / slop / copout (mostly CURR, with PREV roots):

- "it's not bad but holy crap is this kinda fucking garbage." (header of the big CURR
  bug list)
- "and before you dare to bandaid fix this, this is by no means a comprehensive list
  of issues"
- "performative 'implementing systems' be like"
- "features would be fine if they were implemented with any amount of competence.
  which i would expect from opus 4.8 :/"
- "useless. fucking. defensive. post-hoc. near-sighted. bandaids."
- "maybe just all the fucking systems working instead of working performatively???"
- "none of the systems are good enough, honestly. … overall evaluation: fucking
  sucks"
- "diagnosing posthoc is USELESS" / "diagnosing posthoc is USELESS"
- "i've not once gotten anything constructive here"
- "why rushing into poor quality reactive fixes again :/"
- "why. the. fuck. are. we. still. not. designing."
- "don't you dare rush to execution"
- "quality is independent of velocity" / "the commits could have been good." /
  "irrelevant. quality is independent of velocity"
- "the agent is opus 4.8. blaming things on the agent is clearly avoiding blame"
- "but HOW. OPUS implemented those." / "but HOW. OPUS implemented those." / "weren't
  the agents also opus :/ how did they find the bright idea to implement slop" /
  "why… did you even give them the wrong prompts…"
- "how did this happen at all" / "how did this happen in the first place"
- "this is exactly why i said not to execute or even design. this is fucking useless"
- "do you not understand that i don't want to have to babysit and point at every
  little thing"
- "[detection / rendering-analysis] even that sounds like a copout imo. it only
  catches classes of errors we think to catch, meaning for most novel things it has
  to be a post-hoc bandaid"
- "yeah it's beyond saving for the time being." (the shelving verdict)
- "somehow i doubt next session will be any better"

Copout-callouts during the prose/foundation design (CURR):

- "sounds like a copout to me." / "still a copout :/" / "still a copout" / "how. dare.
  you. cop. out." / "i. don't. fucking. care."
- "are you fucking retarded. 'let's just force users to use the most expensive model
  in the world'"
- "are you implying that neural nets are the only known path to intelligence"
- "2d spritesheets kinda suck ngl. hello it's not the 1960s anymore"
- "rather ship nothing than be proud of shipping *slop* or perpetually patch runaway
  tech debt"
- "i said not as visual channel base you fucking idiot" (misread correction)

Process corrections / repeated "wrong" (PREV + CURR) — the user repeatedly rejected
confident-but-unverified assistant claims:

- PREV: a long run of bare "wrong" / "still wrong" / "i. gave. you. the. fucking.
  tools. to. evaluate. them." / "you. have. all. the fucking. info. the fuck are you
  doing." / "why are you always so fucking hasty" / "you fucking DO [need to write
  things down] just. don't write anything WRONG down" / "NO. COPOUTS. ALLOWED." /
  "are you ACTUALLY FUCKING RETARDED" (×3, during the backface misdiagnoses).
- CURR: "wrong" / "still wrong imo" / "irrelevant" (many) / "not the issue" / "also
  no" / "all of the above is irrelevant lmfao" / "did we not mine the fucking
  surface" / "i. don't. mean. the. prose." / "you're being incredibly overconfident"
  / "frankly, disappointing responses still."

Governance the user demanded as a result (CURR):

- "we need to adjust CLAUDE.md to make 'playtesting' mandatory. sometimes by the
  orchestrator spawning a new subagent, sometimes by the implementing subagent
  itself"
- "new features need to be gated behind a design pass, full stop. we need to maintain
  a list of known green features (and a list of not green features below that) where
  features do not get promoted without my express permission"
- "supplying judgement every time is not only infeasible at scale, but it also
  actively poisons your own context by drowning out signal with tool call syntax"
- "not convinced we haven't been missing many design passes" / "why haven't we been
  doing design passes"
- "ideally i would like autonomous execution" (the standing want behind the
  no-babysitting complaint)

---

## Cross-references

- `SESSION-RECORD.md` — the creator-saga narrative + the final-day rage-list +
  meta-learnings + governance. This compendium is its complete-set companion.
- `docs/artifacts/diagnosis/` — per-defect diagnosis artifacts (text-ui-reverify,
  bdcc2-port-reverify, etc.).
- `docs/decisions/character-creator-and-body.md`, `prose-generation.md`,
  `npc-mind-and-language.md`, `semantic-layer.md` — design context the complaints
  push against.
