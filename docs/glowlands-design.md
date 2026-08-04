# The Glowlands — YGTeeV world expansion design bible

*Revised edition — 2026-08-04 (founder revision pass). All numeric values are tuning placeholders unless marked LOCKED.*

---

## Executive summary

**What this is.** The Glowlands is the world expansion of the existing YGTeeV Backyard — the cozy low-poly three.js web game inside the YGTeeV teen Bible-reading app. It turns the Backyard from a destination into a doorstep: the player steps through a new garden gate into a ring of ten zones creeping with the Gloom, a darkness that feeds on lies, fear, and forgetting. Every system the player already runs — daily Bible-plan reading, XP, fruit-for-gold farming, Ember the dragon, the Garden League — becomes the power system of a journey to Everlight City, the source of all light. The expansion economy runs on exactly two currencies, **XP and gold**; fruit is a tradable good, and reading awards XP directly.

**The three load-bearing ideas.**

1. **Truth & Light combat.** Gloomlings attack with written lies ("You're alone"); the player answers with a **Truth Serum** — a Scripture card from their Verse Satchel. The battle reads like a Pokémon encounter: lie families vs verse families are a type chart, so the right family is super effective (Lightburst — the darkness flees) and the wrong family fizzles or barely glows. Each Truth Serum carries **5 charges** and recharges free at any library. No HP, no death, no gore — darkness always flees light. Truth Serums are earned only by memory-verse challenges: in town-book study and in real Bible-plan reading. (Ch. 2)
2. **The Lantern.** Real daily reading in the app lights the player's lantern; brightness (Spark → Flame → Beacon → Radiant) gates frontier access — dark zones and dark missions — and never anything the player already holds. Skip days mean safe zones only, never punishment. The Lantern itself is earned in Meadow Town, granted by an emissary of Everlight for passing a test of compassion. (Ch. 3, Ch. 7)
3. **Towns stay saved.** Six towns, six Lantern Seals, each earned by a library-study Bible Quest and a staged trivia battle vs the town champion, alongside a restoration meter filled by service quests. Every seal town's library also hosts a **Town Book** — one book of the Bible as an in-game, audio-narrated reading plan that pays XP, fruit, and Truth Serums. A saved town permanently transforms — color, lanterns, music, shops — and opens the road onward. Trials (Murkmire, Whisper Gorge, Hollowkeep) are survived, not saved. (Chs. 3, 7–16)

**Multiplayer** is exactly one thing: instanced Mission Trips — typed service minigames (soccer with local kids, hosting a VBS, rebuilding a broken house, flood help) whose 2–8 slots fill with any mix of live players and bots, entered through a lobby from boards in saved towns, communicating only through a quick-phrase/emote wheel. Bots backfill so a mission always starts. Missions grant player XP and earn group renown that feeds the Garden League. (Ch. 4)

**Scope.** One hub (Home Garden + Community Garden), six seal towns, three trial zones, one finale city, a named road network whose routes carry their own traveler-aid and Gloomling challenges, four Pokémon-style late-to-early shortcuts plus a ferry loop and endgame Ember flight, one combat system with 11 bestiary entries and 5 bosses, 4 launch co-op missions, and a full economy that shares the Backyard's existing wallets. Every town has its own theme motif, its own store that buys fruit and sells seeds, and open public garden plots for growing while traveling. Everything is specified for low-poly three.js r128 in a mobile WKWebView: ≤120 draw calls, ≤150 k triangles, 30 fps floor on an iPhone 8-class device. Audience 11–18, church youth groups, COPPA-safe; parents and pastors see everything.

**Build plan.** Part III derives four phases: **Phase 1** is the smallest playable pilgrimage — the Home Garden update, Meadow Town in full, and the East Road connecting toward Riverbend — proving the read → lantern → save-a-town loop. **Phase 2** ships Riverbend, Murkmire (Ember and the Dragon Whistle), combat depth, and the first Mission Trip with its lobby. **Phase 3** builds the dark middle (Lantern Hollow through Hollowkeep) and the full mission suite. **Phase 4** ships the summit, the harbor, Everlight City, and the endgame.

**Non-negotiables.** Light is earned, never bought — no purchase touches brightness, Truth Serums, or seals. Scripture is quoted accurately with references or not quoted at all. Glimmer (counterfeit shine) is always distinguishable from glow (true light). Nothing a player owns is ever taken away.

---

## How to use this document

- **Canon block wins.** The locked decisions in the project canon (names, map order, entitlement of the six pillars above) are never contradicted here. Where an earlier draft conflicted, this edition resolves it and says so inline.
- **"Tunable" convention.** Every number followed by "(tunable)" — and, per the header, every number not marked LOCKED — is a starting value for balancing, chosen to be concrete enough to implement today. Change values in tuning data, not by re-editing prose; the two worked ledgers (Ch. 3) must be re-run after any economy change.
- **Single-source rules.** Some tables are the *only* authority for their subject, and other chapters point at them rather than restating: the **milestone-reward table (the Wayfarer's Kit)** (Ch. 2) for reward effects; the **brightness-tier table and algorithm** (Ch. 3) for the Lantern; the **lie taxonomy and type chart** (Ch. 2) for families, counter-verses, and effectiveness; the **Town Book spec** (Ch. 3.10) for the library reading system; the **five-beat mission spine** (Ch. 4). If a town entry and a systems chapter ever disagree, the systems chapter wins and the town entry is wrong.
- **The pillar test.** Every feature proposal must cite one of the five pillars in Ch. 1.3 and violate none of their "forbids" clauses. Pillar 3 (grace-shaped retention) is the one most often violated by well-meaning proposals; its mechanical test is printed there.
- **Reading paths.** Engineers: Ch. 5 (systems & feel), then Ch. 2, then Part III. Designers: Part I in order, then the atlas. Artists/audio: each atlas entry's §2 and §8, plus Ch. 5. Writers/theology: Ch. 2 (lie taxonomy, writers' rules), then each atlas entry's §4–5. Producers: this summary, Ch. 1, Part III.
- **Atlas anatomy.** Every world entry uses the same nine sections — 1 Fantasy & role, 2 Visual direction, 3 Layout, 4 Characters, 5 Quests, 6 Unique mechanic, 7 Secrets, 8 Audio, 9 Gating — and opens with a **Seam** callout stating the gating chain into and out of the zone. The named roads between zones are covered in the **Roads of the Glowlands** interlude at the top of Part II; town entries reference roads by name.

**Terminology (enforced throughout — do not invent synonyms):**

| Term | Meaning |
|---|---|
| The Gloom / Gloomlings | The antagonist darkness / its lie-whispering creatures |
| Truth & Light | The combat system; encounters are "encounters," never "fights to the death" |
| Truth Serum | A battle verse — one earned Scripture card with **5 charges**, recharged free at any library; earned only via memory-verse challenges |
| Lightburst | The correct-verse VFX/SFX moment (never "verse-burst" or "light burst") |
| Fade | The soft failure state — waking at the last lit lantern; there is no death |
| Verse Satchel | The container: the Truth Serum loadout/collection; cards, families, mastery |
| Town Book | A seal town library's book of the Bible as an in-game, audio-narrated reading plan (Ch. 3.10) — distinct from the app's plans |
| Dragon Whistle | Inventory item (earned in Murkmire) that summons Ember from home as the traveling buddy; blow again to send him home |
| Lightfound fanfare | The universal win jingle — plays whenever the player receives or earns anything (Ch. 5.7) |
| Lantern tiers | **Spark, Flame, Beacon, Radiant** — the only brightness tier names (numeric aliases 1–4) |
| Lantern Seal | One of six town badges; "seal," never "badge" |
| Saved / Survived | Towns are saved (seal + restoration); trials are survived |
| Standing | Per-town reputation: Stranger → Neighbor → Friend → Guardian |
| Renown | Youth-group-level score (lifetime + weekly tracks) |
| Ember-sparks | Cosmetic-only combat drop currency |
| Burden Weight | Murkmire's carry-weight trial stat (Traveler's Rule thereafter) |
| Glimmer vs glow | Counterfeit shine vs true light — never used interchangeably |

---

## Table of contents

**Front matter** — Executive summary · How to use this document

**Part I — Gameplay**
1. Overview, pillars & core loop
2. Combat — the Truth & Light system
3. Progression, economy & retention
4. Multiplayer — Mission Trips
5. Systems & feel

**Part II — World atlas (journey order)**
Roads of the Glowlands (routes interlude)
6. Home Garden & Community Garden (hub)
7. Meadow Town (Seal 1 — gateway)
8. Riverbend (Seal 2 — flood)
9. Murkmire (trial — burden)
10. Lantern Hollow (Seal 3 — the lantern's town)
11. Glimmerton (Seal 4 — glimmer vs glow)
12. Whisper Gorge (trial — the long dark mile)
13. Hollowkeep (dungeon — the Dawnkey escape)
14. Starcrest (Seal 5 — the shepherd's summit)
15. Brightharbor (Seal 6 — the sending harbor)
16. Everlight City (finale — the Vigil and the commissioning)

**Part III — Build phasing**
17. Phase 1 — the gateway slice
18. Phase 2 — the river, the mire, and the first trip
19. Phase 3 — the dark middle
20. Phase 4 — summit, harbor, source

---

# Part I — Gameplay

## 1. Overview, pillars & core loop

### 1.1 One-page summary

Glowlands turns the Backyard from a destination into a doorstep. The player who has spent months farming glowberries and reading daily plans steps through their garden gate into a world where those same habits are the power system: real Bible reading lights the Lantern, verses memorized become Truth Serums — combat ammunition with real charges — and the fruit economy players already understand funds the journey.

The pitch in one sentence: **a cozy pilgrimage RPG where the light you carry is the light you actually read for, and every town you save stays saved.**

- **Genre.** Third-person low-poly adventure: town restoration, verse-based Truth & Light encounters, light survival trials, instanced co-op service missions.
- **Structure.** A one-way ring of ten zones from Home Garden to Everlight City, gated by six Lantern Seals and folded back on itself by earned shortcuts. No town can be skipped; every saved town permanently transforms and becomes a fast-travel-adjacent home base.
- **Session shape.** 8–20 minute sessions (tunable) built around one clear next step: a quest marker, a restoration meter at 60%, a champion battle you're two verses short of winning.
- **The hook that isn't in any other game.** Progress is bound to real-world Scripture reading, and the binding is generous: reading opens frontiers, skipping never closes homes. The Gloom whispers lies in text; the player answers with verses they genuinely studied. The game cannot be beaten by grinding — only by reading, remembering, and serving.
- **Audience and platform.** 11–18, church youth groups, COPPA-safe, mobile-first three.js r128 inside a WKWebView. Everything specified in this bible is buildable at that scope.

### 1.2 Player fantasy

**"I am the lantern-bearer my town has been waiting for."**

The fantasy has three layers, and each maps to a system:

1. **I carry real light.** My lantern is bright because *I* read this morning — not an avatar stat, my actual streak. Walking into Whisper Gorge with a Radiant lantern feels earned in a way no loot drop can fake. (System: Lantern brightness tiers.)
2. **I know the truth when I hear the lie.** When a Gloomling whispers "You're alone," I don't press an attack button — I *recognize the lie* and answer it from my Verse Satchel. Winning feels like being wise, not strong. (System: Truth & Light encounters.)
3. **I leave places better than I found them.** Towns I save turn their lanterns on for good. NPCs I fed remember me by name. My Standing climbs from Stranger to Guardian because I showed up, repeatedly, for people. (Systems: restoration meters, Standing track, Mission Trips.)

The fantasy is deliberately *not* power fantasy. The player is never the strongest thing in the room — the light is. They are its carrier.

### 1.3 Design pillars

Five pillars. Every feature proposal in later chapters must cite the pillar it serves; if it violates a "forbids" clause, it dies in review.

| # | Pillar | What it demands | What it forbids |
|---|---|---|---|
| 1 | **Light is earned, never bought** | Frontier access, encounter strength, and endgame gates run through real reading and study. Gold buys tools, seeds, cosmetics — never brightness, Truth Serums, or seals. | Any IAP, gold sink, or shortcut that substitutes for reading. Any "watch ad / pay to relight lantern" mechanic. Truth Serum purchases or paid recharges. |
| 2 | **Darkness flees; it is never fought** | Encounters resolve by truth spoken into lies. Victory VFX is always light expanding, Gloom receding. Fear is atmosphere and stakes, not damage numbers. | Health bars on Gloomlings, hit-point combat, weapons, death states, gore, killing anything. "Wrong verse" outcomes that humiliate rather than tighten tension. |
| 3 | **Grace-shaped retention** | Missing days narrows where you can *go next*, never what you *have*. Saved towns, gear, gold, garden, Standing, and seals are permanent. Re-lighting is always one reading session away. | Streak loss animations, decay of owned progress, guilt copy ("your town missed you..."), notifications that shame. Any state the player can permanently ruin. |
| 4 | **Towns stay saved** | Restoration is visible, permanent, and communal: color returns, music changes, shops reopen, NPCs remember. The world accumulates the player's faithfulness. | Towns relapsing into Gloom, repeatable "re-save" loops, resetting restoration meters, timed decay of any saved state. |
| 5 | **Phone-honest AAA feel** | Every feel target (animation, VFX, physics, crowd scenes) specified so it ships in three.js r128 at 30+ fps on a 2021 mid-tier phone. Juice comes from timing, light, and sound — not polycount. | Ragdolls, real-time shadows on more than one light (tunable), photoreal aspirations, particle counts above budget (Ch. 5), features that only demo well on desktop. |

Pillar 3 is the one most likely to be violated by well-meaning retention proposals. The test is mechanical: *does the design ever take away something the player already holds?* If yes, reject it.

### 1.4 Core loops

Written as text diagrams; arrows are causal, not merely sequential.

**Minute-to-minute (in the Glowlands, ~90-second beat, tunable):**

```
Move through zone → spot point of interest (NPC in need / Gloom patch /
resource node / quest marker)
  → INTERACT:
     • service task (30–90 s: deliver, repair, harvest-and-give)
     • Truth & Light encounter (20–60 s: read the lie → pick verse → Lightburst)
     • gather (glow seeds, materials, red bags)
  → immediate feedback: light spreads, restoration meter ticks, Standing points,
    gold/XP into the SAME wallets the Backyard uses — earns land with the
    Lightfound fanfare (Ch. 5.7)
  → next point of interest is already visible ≤ 15 s away (tunable)
```

**Session loop (8–20 min, one sitting):**

```
Open app → daily Bible plan (existing) → XP paid directly; lantern lights /
    brightness tier set
  → Home Garden: tend crops, harvest, sell (existing loop, 2–4 min)
  → step through the gate with today's brightness
  → pursue ONE headline goal: quest chain step, library study session,
    champion battle attempt, trial run, or a co-op Mission Trip
  → bank progress (meters, Standing, verses mastered)
  → session-end card: "Tomorrow your lantern can reach ___" (forward pull,
    never a warning)
```

The daily reading sits at the top of the funnel by design: it is the first thing that pays out, and everything downstream is denominated in it.

**Weekly loop:**

```
Mon–Sun daily readings → brightness tier sustained → frontier zones stay open
  → weekend co-op window: Mission Trips with youth group (renown)
  → renown + garden output → Garden League standing vs other youth groups
  → league resolution Sunday night → group goal set for next week
  → new town's Bible Quest becomes the medium-term arc (seal every 1–2 weeks
    of normal play, tunable)
```

### 1.5 Wrapping the Backyard without breaking it

The Backyard is live, loved, and load-bearing. Glowlands is an *annex*, not a renovation. Integration rules:

| Existing system | Glowlands relationship | Hard rule |
|---|---|---|
| Home garden farming | Unchanged; becomes the hub's economic engine. Glowlands adds *demand* (service quests consume fruit, Toolworks gear needs materials) without touching supply mechanics. | No Glowlands feature may alter grow times or plot rules. |
| XP from reading | The same earn event now also feeds the Lantern. One reading session → XP + brightness, one action, two payouts. | Reading is never double-charged: no separate "Glowlands reading" requirement. The expansion adds no water resource — XP and gold are the only currencies. |
| Gold / Berry Market | Single shared wallet. Town stores in every town buy fruit and sell seeds in the same gold. | No second currency for the overworld. Renown (group) and Standing (per-town) are reputations, not spendable. |
| Ember | Stays home minding the Backyard until Murkmire, where the Dragon Whistle (Ch. 9) makes him the summonable traveling buddy; comic relief in towns, silent in Gloom territory (tone-zone rule), endgame mount. | Ember never fights and never speaks lies or verses on the player's behalf. No Ember mention may put him on the road before Murkmire. |
| Eli | Gives the prologue call-to-adventure at the garden gate, sees the player off at Meadow Town's East Gate ("I'll mind the backyard — come home anytime"), and later connects to the orchard-tunnel shears (via his sister Brama, Ch. 10). | Eli stays home; he is the reason the Backyard still feels tended. |
| Community Garden | Remains the group hangout, geometrically off the critical path. | Never a thoroughfare; no quest may route through it. |
| Garden League | Extended, not replaced: Mission Trip renown scores alongside garden output in the weekly tally (weighting tunable, start 50/50). | A group with zero Glowlands players must still be able to compete on farming alone through at least season 3. |
| Red-bag daily questions | Red bags now also spawn along Glowlands roads; same question format, same rewards. | Backyard spawn rate untouched. |

The invariant behind all eight rows: **a player who never steps through the gate loses nothing they have today.** Glowlands must recruit by pull — visible lantern-light past the fence, a friend's saved town, a league that starts crediting mission renown — never by making the Backyard feel smaller.

---

## 2. Combat — the Truth & Light system

Combat in Glowlands is an argument you win, not a body you break. Gloomlings attack with written lies; the player answers with a **Truth Serum** — an earned Scripture card — from the Verse Satchel. The whole encounter reads like a Pokémon battle in shape: lie families vs verse families form a **type chart**, the right family is super effective (a Lightburst, and the darkness flees — James 4:7, "Resist the devil, and he will flee from you"), and the wrong family simply doesn't work or works weakly. Each Truth Serum carries **5 charges** (the PP analog) and recharges free at any library. The wrong answer never hurts the player's body — it lets fear close in. Nothing in this system deals damage, bleeds, or dies. Darkness always flees light.

### 2.1 Encounter flow

1. **Approach.** A Gloomling notices the player inside its aggro radius (8 m, tunable). Ambient audio ducks −6 dB; a low whisper loop fades in. Movement stays free — combat never roots the player.
2. **The lie.** The Gloomling projects its lie as drifting smoke-text above itself: *"You're alone."* The lie's family icon pulses beside it (see taxonomy). A soft radial vignette begins tightening at ~2%/s (tunable) — fear pressure, not a hard timer in towns.
3. **Satchel open.** Player taps the Gloomling or the satchel button. Time dilates to 0.25× world speed (single-player maps; see co-op modifiers for Missions). The Verse Satchel wheel opens.
4. **Answer.** Player selects a Truth Serum card; every cast spends **one charge**, hit or miss. Effectiveness runs on the type chart (2.2): the right family is **super effective** — a **Lightburst**: the verse text flares on screen for 1.2 s with its reference, the Gloomling recoils, dissolves upward into fireflies, and drops Ember-sparks (see combat economy) plus occasional verse fragments. The wrong family is **not effective** — the serum fizzles in a weak grey shimmer, the lie re-forms louder, **fear closes in** (vignette snaps 15% tighter), and that card greys out for this encounter (no spam-guessing). At precision tiers that demand the exact verse (2.4), the right family with the wrong verse **glances**: the lie staggers and re-forms dimmer — a readable "close, keep looking" signal — at the same vignette cost.
5. **Resolve.** Multi-lie Gloomlings repeat steps 2–4 per lie. On clear, vignette releases over 0.8 s, whispers cut, birdsong returns. Standing points are granted in the local town's region.

**No-soft-lock rule (server-side).** The encounter generator only deals lies that have at least one valid counter among the player's *currently equipped, charged* cards. If grey-outs or empty charges exhaust a family mid-encounter, the next miss resolves as a timer-expiry (Fade path, below) — an unanswerable state can never exist. A serum at zero charges shows an unlit wick icon and cannot be cast until recharged at a library.

**Combat economy — Ember-sparks.** Combat drops are Ember-sparks, a cosmetic-only currency deliberately separate from gold so combat grinding can never inflate the fruit-selling economy or the Garden League. Ember eats them (he is the wallet — a satchel-side counter with his face on it) and trades them at Home Garden or any saved town's chapel steeple for satchel dyes, lantern skins, Lightburst color variants, and Ember accessories. No exchange to gold or XP in either direction; nothing gameplay-affecting is spark-purchasable. Trash drops 3–5 sparks, elites 12–20, bosses 60 (all tunable).

Average encounter length target: 8–15 s trash, 25–40 s elites, 3–4 min bosses.

### 2.2 Lie taxonomy — six families

Every lie belongs to exactly one family, color- and icon-coded everywhere (satchel, lie text, bestiary, library). Verses are tagged to one family at earn time. **This is the game's type chart, Pokémon-shaped and one-to-one:** each lie family is countered by exactly one verse family — matching family is super effective (Lightburst), any other family is not effective (fizzle). There are no resistances, immunities, or dual types; the depth is in *reading the lie*, not memorizing a matchup grid.

| Family | Icon / color | Sample lies | Counter-verse family (examples) |
|---|---|---|---|
| **Isolation** | Broken circle / slate blue | "You're alone." "No one would notice if you disappeared." | Presence — Deut. 31:6; Matt. 28:20; Josh. 1:9 |
| **Condemnation** | Chain / ash grey | "One mistake and you're done." "You can't be forgiven again." | Grace — Rom. 8:1; 1 John 1:9; Ps. 103:12 |
| **Fear** | Jagged eye / cold violet | "Something bad is coming." "You're not safe here." | Courage — Ps. 56:3; Isa. 41:10; 2 Tim. 1:7 |
| **Worthlessness** | Cracked mirror / dull bronze | "You don't matter." "You're a mistake." | Identity — Ps. 139:14; Eph. 2:10; 1 John 3:1 |
| **Despair** | Falling leaf / faded green | "Nothing will ever change." "Why even try." | Hope — Jer. 29:11; Lam. 3:22-23; Rom. 15:13 |
| **Doubt** | Fogged lantern / murk yellow | "God isn't listening." "Did He really say that?" | Trust — Prov. 3:5-6; 1 Pet. 5:7; Ps. 34:17 |

Writers' rule: lies are second-person, present-tense, ≤8 words, and never reference real-world self-harm, abuse, or specific sins. They attack identity and hope, not biography. Every lie string ships with its family tag and at least three valid counter-verses in the game-wide pool (the server no-soft-lock rule above handles thin satchels at runtime).

### 2.3 Truth Serums & the Verse Satchel — earning, charges, loadout & UI

- **Earning.** A Truth Serum is earned one way only: by completing a **memory-verse challenge** — a short recall exercise (arrange-the-words, fill-the-word, then recite-by-tap) over a single verse. Memory-verse challenges are dealt from two sources: **library study** — Town Book memory-verse checks (Ch. 3.10) and historian-led seal-study sessions alike end in one — and **real Bible-plan reading in the app** (each completed plan day offers one memory-verse challenge drawn from that day's passage pool). Wherever an atlas entry says a study session "earns" or "mints" a serum, the memory-verse challenge is the mechanism. Passing the challenge mints the verse as a Truth Serum, with the Lightfound fanfare (Ch. 5.7). No serum is purchasable — truth is learned, never bought.
- **Charges (the PP analog).** Every Truth Serum carries **5 charges** (tunable ceiling via the Deepwell Vials, Ch. 2.7). Each cast in an encounter spends one charge, hit or miss. A spent serum sits in the satchel with an unlit wick icon until **recharged — free, at any library** (all six town libraries, the Mirelight Outpost in Murkmire, Wickett's reading shelf in Whisper Gorge, and Hollowkeep's Archive of Echoes all count). Recharge is diegetic and instant: the librarian re-reads the verse with you, the card's wick relights. Charges create the Pokémon rhythm — venture out, spend truth, return to the light to refill — without ever gating what a player *knows*, only what they've packed.
- **The passage pool (content pipeline).** Every plan day ships with a curated pool of **≥3 combat-tagged verses**, hand-picked from that day's passage where viable. When the day's passage has no viable candidate (genealogies, census lists, itineraries), the challenge draws from the plan's **authored fallback pool** — a per-plan reserve of ≥5 verses per family (30 minimum), written into the CMS at plan authoring time. Tagging is a writers'-room job, never automated: each tag assigns exactly one family, and each serum card carries its reference plus a verbatim excerpt of ≤12 words from the plan's translation (full text on long-press). A plan cannot publish with an empty day pool — the CMS blocks it. Net effect: every plan day in the app, in any book, yields a usable Truth Serum. Town Book memory-verse checks (Ch. 3.10) are authored on the same pipeline, tagged per town book.
- **Loadout.** 6 family slots × up to 3 serum cards (max 18 equipped; collection unlimited). Editable at any lantern or in Home Garden; locked during encounters. Each card shows its remaining charges as 5 wick pips.
- **UI.** Radial wheel, bottom-center, thumb-reach. Outer ring = 6 family wedges; tapping a wedge fans out its 3 cards showing reference + first four words + charge pips. Long-press a card to read in full (pauses the timer in single-player). One-handed portrait play is the design target.
- **Mastery.** Correct use of the same serum 5 / 15 / 40 times upgrades it Bronze/Silver/Gold: Gold cards Lightburst 30% larger and grant +10% Ember-sparks (tunable). Memorization through repetition, not grind gates. Mastery never changes charge count — depth of knowing and fullness of pack are separate meters.

### 2.4 Timing & difficulty model

Difficulty scales along two independent axes — **pressure** (time) and **precision** (answer exactness). Trials spike pressure only, per the tone rules; precision advances strictly in journey order. Precision rides on the type chart: at tier 1, any charged serum in the correct family is super effective; at tier 2+, the correct family with the wrong verse *glances* (2.1) instead of bursting — the wrong family is never effective at any tier.

| Tier | Where | Pressure | Precision |
|---|---|---|---|
| 1 | Meadow Town, Riverbend | No hard timer; vignette only | Correct **family** (any equipped card in it works) |
| Trial | Murkmire | 8 s timer; weight modifier adds +1 s per carried stack slot over 10 | Tier-1 precision: family only. Murkmire tests nerve, not recall |
| 2 | Lantern Hollow, Glimmerton | 12 s soft timer (tunable) | Correct **verse** within the family |
| 3 | Whisper Gorge, Hollowkeep, Starcrest, Brightharbor | 8 s timer | Correct verse; some elites present a **fill-the-word** card (one missing word, 3 choices) |
| Boss | Gloom bosses | Phase-scripted | Mixed; see boss designs |

Timers pause whenever a card is held open to read (single-player). Timer expiry = same result as a wrong answer, never worse.

**Lantern & combat — explicit decoupling.** The Lantern's streak-brightness tiers gate **where** you fight, never **how hard** the fight is. No combat variable — vignette tighten rate, timers, whisper mix ceiling, drop rates, lie selection, boss pacing — ever reads the player's streak tier. There is no stat coupling, ever; a day-1 player and a 90-day-streak player who stand in the same encounter face the identical fight. The two bestiary mechanics that reference "lantern radius" (Lanterneater drain, Fogmaw legibility) operate on the **in-world lantern's zone-constant radius** (Whisper Gorge base 9 m, Brightharbor base 7 m, tunable), which is fixed per zone and restored at any lit lantern — it is spatial gameplay, not a streak stat. Rationale: the Lantern is a promise ("reading opens the frontier"), and promises stop working the moment they double as difficulty knobs; skipping days must never make a fight the player can already reach harder.

**Co-op modifiers (Mission Trips).** Time dilation and read-in-full pause are disabled in instanced co-op — the world stays real-time for 2–8 slots. To compensate, Mission lies are always family-precision regardless of tier, on a shared 20 s timer (tunable) visible to all players, and any teammate's correct answer clears the lie for the group (the Lightburst originates from the answerer). Wrong answers grey the card only for that player. **Bots** (Ch. 4.1) carry a standard six-family serum kit that always counts toward coverage, and a bot casts a correct family counter if the shared timer reaches its final third with no live answer — bots keep missions moving, never outshine players. In Missions, the no-soft-lock generator deals only lies counterable by the **union of all present players' and bots' equipped, charged families**; if per-player grey-outs exhaust that union mid-encounter, timer expiry resolves via the Fade path as in single-player — the group wakes together at the mission's last checkpoint lantern. The emote wheel auto-suggests the family icon a teammate just identified — coordination without free chat.

### 2.5 Gloomling bestiary

All Gloomlings are matte-black low-poly silhouettes (≤800 tris, single 256px gradient texture, 3-bone spline sway, no rigs beyond that) with one glowing feature. Death is a shader dissolve (alpha noise scroll) into 20–30 additive firefly sprites — no ragdolls.

| Creature | Zone debut | Behavior |
|---|---|---|
| **Whisperling** | Meadow Town prologue | Tutorial trash. One tier-1 lie, flees on any correct family. Backs away as the player's lantern nears. |
| **Murmur Pack** | Riverbend | 3–4 units; each speaks a lie from a *different* family in sequence. Teaches family recognition under variety. |
| **Heavyback** | Murkmire | Slow stalker; latches a grey tendril adding phantom pack weight (movement −20%) until its Despair lie is answered. Embodies Murkmire's carry-more-sink-more rule. |
| **Glimmermoth** | Glimmerton | Flutters between camera and lie text, scattering sparkle glare that visually corrupts two of the six wedge icons. Counterfeit shine literally makes truth harder to read. |
| **Echo Shade** | Whisper Gorge | Speaks only lies the *player previously failed* (from their miss history). Spaced repetition disguised as a haunting. |
| **Lanterneater** | Whisper Gorge | Silent. Never spawns alone — always escorted by 1–2 Whisperlings speaking Fear-family lies (spawn table `whisper_gorge_escort`). Orbits at 12 m draining lantern radius 0.5 m/s. Each Lightburst on an escort knocks it back 6 m; clearing all escorts drives it off. Forces target prioritization. |
| **Dreadroot** | Hollowkeep | Stationary; 10 m fear fog (vignette pre-tightened 25% inside). Two simultaneous lies: either dispels the fog 20 s, both destroys it. |
| **The Hollow Chorus** | Hollowkeep elite | Five mouths, one body. One tier-3 fill-the-word lie per mouth, 8 s each, escalating whisper mix. The dungeon's skill check. |
| **Fleecewraith** | Starcrest | Mimics a stray sheep's silhouette bleating in mountain mist; reveals itself at 5 m with Isolation lies. Answering frees a real lamb that trots back to the fold (+Standing with the shepherds). Tell, taught by the town shepherd: real sheep's eyes catch lantern light; a wraith's never do. |
| **Fogmaw** | Brightharbor | Rides rolling harbor fog banks; its lie text is only legible inside the player's lantern radius, so positioning *is* the read. Doubt and Fear families; retreats seaward when burst. |

### 2.6 Boss designs

Gloom bosses are the climax of each town's *story arc*; the Lantern Seal itself is always conferred by the town's Bible Quest — library study with the historian, then the staged trivia battle vs the town champion before a crowd. The boss gates access to that trivia battle (or follows it, per town script); it never grants the seal. Trivia battles reuse this system's satchel UI and fill-the-word cards; the per-town rulesets live in the atlas entries (the Meadow Town ruleset in Ch. 7 is the template).

**Calm Mode rule for all bosses:** every timed answer window becomes an untimed **answer-complete check** (the phase advances on answer count only), and every pursuit or encroachment source holds at a fixed distance while the satchel is open. Precision tiers, lie content, and phase structure are unchanged — Calm Mode removes clocks, never teaching. Per-boss variants are specified in each design below and summarized here:

| Boss | Calm Mode variant |
|---|---|
| First Shadow | P2's 15 s windows removed; relight the three lanterns in any order, untimed |
| Glimmer King | P2's 10 s lies untimed; counterfeit cards remain (discernment is the point, not speed) |
| Warden | P1 doors close only on wrong answers, never on time; footstep audio loops at fixed distance; P2's 14 s window becomes "answer both, then the key rises" |
| Cragmother | P3's shared windows become answer-both checks; mist density fixed at P2 entry value |
| Undertow | The drown clock pauses whenever the satchel is open; phases advance on lantern count only |

**1. The First Shadow — Meadow Town prologue (Meadow Town arc).**
- *P1 (teach):* Three tier-1 lies, one per family taught so far, Eli coaching via banner text. No timer.
- *P2 (test):* Extinguishes the square's lanterns; screen darkens except the player's lantern radius. Three more lies, 15 s each. Correct answers relight one town lantern apiece.
- *P3 (triumph):* All lies at once as swirling smoke-text; answer any three in any order. Finale: town lanterns cascade-ignite outward from the player; the First Shadow dissolves fleeing the light. Sets the covenant of the whole game: light wins, always.

**2. The Glimmer King — Glimmerton arc.**
- *P1 (the show):* Carnival stage. Every lie appears beside a **counterfeit comfort** — a glittering fake card ("You just need more applause") in satchel style, gold-flashing. Choosing real Scripture dims the stage lights one bank at a time.
- *P2 (the mask slips):* Stage dark; his neon shell flickers off revealing a small grey Gloomling on stilts. Tier-3 Worthlessness/Despair lies, 10 s each. His glimmer-puppet crowd deflates per Lightburst.
- *P3 (the trade):* He offers the player the mask (narrative refuses; generosity framing — give it away). Final lie: "Without the shine, you're nothing." Countered by Identity, e.g. Psalm 139:14. He shrinks to lantern-height and slinks out the stage door; fake neon dies, true lantern-glow rises — the game's clearest glimmer-vs-glow statement.

**3. The Warden of Hollowkeep (Dawnkey escape).**
- *P1 (the cells):* Corridor pursuit; the Warden seals doors with Dreadroot fogs. Each door = one tier-3 lie, 8 s, his footsteps growing in the mix. Fail = door shut 10 s, he closes distance (fear pressure; no catch animation beyond the standard Fade).
- *P2 (the keyring):* Central hall; the Dawnkey hangs above a mirror-floor showing the player's lantern reflection going out. Doubt and Fear lies in pairs — answer both within a shared 14 s window to raise the key one notch (three notches).
- *P3 (the threshold):* At the exit gate his only quiet line: "It's darker out there than in here." One Trust-family answer (e.g. Prov. 3:5-6) shatters the hall's darkness; the player *walks out*. He is never destroyed — Hollowkeep is survived, not saved.

**4. The Cragmother — Starcrest arc.** A mist-wolf the size of a barn, more absence than animal; she never approaches — her entire design is distance. Payoff of the Fleecewraith setup.
- *P1 (the scattering) — lower terrace:* Her howl scatters the fold; **4 lambs** pinned at the terrace edges, each behind one Isolation lie ("The flock forgot you already"), 12 s each (tunable). Every Lightburst frees a lamb that falls in line behind the player. She circles the terrace rim at 20 m, howling between answers.
- *P2 (the mist) — middle terrace:* Mist rolls in; **6 sheep silhouettes, 2 of them Fleecewraiths**, using the taught tell (real eyes catch lantern light). Wraiths speak Doubt lies ("The shepherd isn't coming"), 10 s each; checking a real sheep costs nothing — verification is never punished. Freed wraith-lambs join the train.
- *P3 (the fold) — summit ridge:* She blocks the fold gate with Isolation/Doubt lie pairs, both required within a shared 12 s window, three rounds. Finale — the shepherd callback: every lamb freed across the whole Starcrest arc (Fleecewraith rescues carry a persistent counter) pours past the player into the fold as the town shepherd's night-call — heard in Starcrest ambience since arrival — rings from below. The bell-chorus staggers her; one final Isolation lie, "You climbed alone," is answered with Presence (e.g. Ps. 23:4, "you are with me"), and she thins into ridge mist. The shepherd lights the fold lantern.

**5. The Undertow — Brightharbor arc.** Not a creature but a Gloom fog-tide that swallows the pier lights dock by dock. Fought along the harborfront; win condition is relighting the lighthouse.
- *P1 (the tide comes in):* Six pier lanterns line the harbor. The tide drowns one every **45 s** (tunable), far dock first. Each drowned lantern surfaces a wave of **2 Fogmaws** speaking Fear lies; bursting a Fogmaw while standing on its dock relights that dock's lantern. Fogmaw legibility rules apply — the player's lantern radius is the reading light.
- *P2 (the harbor dark):* Triggers when 3 lanterns are down. Drown rate accelerates to **30 s**; waves become **2 Fogmaws + 1 Murmur-Pack unit** mixing Despair into the Fear. Advance to P3 when the player holds 4 lanterns lit — or when all 6 drown (the fight continues; the tide simply reaches the lighthouse steps first).
- *P3 (the lighthouse):* The player climbs the lighthouse stair; fog tendrils bar three landings with alternating Fear/Despair lies, 10 s each — "The storm is bigger than you" (countered by e.g. Ps. 46:1-2), "The light already went out for good" (Hope, e.g. Lam. 3:22-23), and at the lamp room, "No light reaches this far out" (e.g. Isa. 43:2). The relit beacon sweeps the harbor in one shader wipe; the tide recedes seaward, pier lanterns cascade-relight in reverse drown order, and the ferry horn sounds — the first note of the Meadow Town loop opening.

### 2.7 Milestone rewards — the Wayfarer's Kit

Story-milestone rewards, never dropped, never sold. One legible effect each; every grant plays the Lightfound fanfare (Ch. 5.7). **This table is the single spec for milestone-reward effects; atlas entries state the grant and point here.** (The Dragon Whistle is the seventh story item, granted mid-Murkmire by conversation rather than at a milestone — spec in Ch. 9.)

| Reward | Milestone | Effect (tunable) |
|---|---|---|
| The Lie-Lens | Seal 1 (Meadow Town) | A librarian's reading glass: the lie's key word underlines in family color — permanent type-chart hint |
| The Quickstrap | Seal 2 (Riverbend) | Satchel harness: satchel opens 40% faster; full move speed while open |
| Deepwell Vials | Murkmire trial | Serum capacity: every Truth Serum carries 6 charges instead of 5 |
| The Keeper's Hood | Seal 3 (Lantern Hollow) | Lantern upgrade: once per encounter, tap-raise the lantern to snuff a lie before it lands (skips it) |
| Morningstar Oil | Seal 5 (Starcrest) | Lantern upgrade: vignette decays 2× faster post-encounter; immune to Dreadroot pre-tighten |
| The Beacon Prism | Seal 6 (Brightharbor) | Lantern upgrade: Gold-mastery Lightbursts chain to one identical-family lie within 6 m |

### 2.8 Failure states — fear, never death

No HP, no death. The vignette is the only health bar. If fear fully closes (repeated misses / expiries), the player **Fades**: soft black, a heartbeat, then the lantern re-flaring — the player wakes at the nearest lit lantern or safe zone, items and progress intact, solved lies staying solved. Cost is position plus a 10 s regroup beat (once Ember travels with you — post-Murkmire — the wake-up sound is his snort and the beat is his pep line). Missed lies enter the Echo list, resurfacing via Echo Shades and library review prompts — failure literally becomes curriculum.

### 2.9 Accessibility

- **Calm Mode** (settings, no penalty, parent-visible): removes all timers game-wide — encounters, Missions, and bosses per the Calm Mode boss table above; precision tiers unchanged.
- **Read-aloud:** every lie and serum card has recorded VO (reuses the app's ElevenLabs verse-narration pipeline, same as Town Books, Ch. 3.10); lies whispered, verses spoken warm.
- **Dyslexia-friendly font toggle** and 1.3× text scale; lie smoke-text always duplicated in a static plate below the creature.
- **Reduced-flash:** Lightburst becomes a 0.6 s radial glow ramp, no white frame; vignette becomes desaturation instead of darkening.
- **Colorblind-safe:** families are never color-only — icon and wheel position are fixed.
- **Scare ceiling:** whisper VO volume and vignette maximum globally capped in towns; full intensity exists only in named Gloom territory the player chose to enter.

---

## 3. Progression, economy & retention

The Glowlands runs on exactly **two currencies** plus one bound meter, with hard-separated purposes: **gold** (trade — earned in-world, spent in-world), **XP** (the whole-journey measure — reading, lessons, battles, and missions all pay it, and it gates level-locked gear and level-gated pockets), and **lantern brightness** (bound exclusively to real reading in the app; no quest, purchase, or grind can raise it). **Fruit is a tradable good, not a currency** — grown, sold, and given, never spent as money. Real Bible reading awards XP directly. Every system below routes back to one of these so the player always knows which loop they are advancing.

### 3.1 XP and levels

XP is a single account-wide track shared with the existing garden (planting, harvesting, reading rewards all feed it). Glowlands adds new XP sources but no second track.

| Source | XP (tunable) | Cap |
|---|---|---|
| Daily reading session (existing) | 100 | 1/day |
| Town Book section completed (in-library lesson, Ch. 3.10) | 40 (+2 fruit) | 3 sections/day/town |
| Town Book memory-verse challenge passed | 60 (+ the verse as a Truth Serum) | per-check |
| Truth & Light battle won | 25–60 by Gloomling tier | none |
| Service quest completed | 40 | none |
| Town Bible Quest (library study step) | 75 per chapter studied | per-quest |
| Champion trivia battle won | 300 | once per town |
| Town saved (seal + restoration full) | 1,000 | once per town |
| Road challenge (traveler aid / Gloom patrol repelled) | 20–40 | 5/day |
| Mission Trip completed | 150 + 50 per teammate revive/assist | 3/week |

Mission Trips are a first-class leveling source by design — a group that serves together levels together.

The curve: **total XP to reach level *n* = `150 * n^1.6`** (tunable) — cumulative, not per-level. Target: level 30 at full six-seal completion for a daily reader over ~10 weeks. The check: level 30 requires ≈34,600 total XP. A daily reader's ten-week ledger: 70 reading days × 100 = 7,000; ~220 battles at ~40 avg = 8,800; 60 service quests = 2,400; library study across six quests ≈ 2,250; six champion wins = 1,800; six towns saved = 6,000; ~30 Mission Trips at ~200 avg = 6,000. Total ≈ 34,250 — level 30 within one evening's battles, tuned by Gloomling density per region.

Levels gate two things: **gear equip requirements** and **level-gated pockets** — named optional content throughout the world signposted in warm voice ("Come back at level 12 — the ridge will wait"). Level gates never touch main-path map access (that is the Lantern's job) and never touch Truth Serums (that is study's job); they exist to give XP a horizon and to make every reading session and battle visibly pull a locked pocket closer. Three worked examples live in the atlas: Old Cobb's deep-channel salvage in Riverbend (level 8), the Marvelo Matinee in Glimmerton (level 15), and the High Fold in Starcrest (level 20). Level-up grants: +1 Verse Satchel slot every 5 levels (base 6, max 12), a gold purse bump, and a light-burst cosmetic moment at the player's feet (ring of grass-glow decals, 1.2 s, ≤40 sprites for phone budget).

### 3.2 Gold: sources and sinks

Gold's center of gravity stays in the garden — selling fruit at the Berry Market remains the best gold-per-minute in the game, deliberately, so the home loop never becomes obsolete. World gold is supplemental income; world sinks are where gold leaves.

| | Item | Gold (tunable) | Notes |
|---|---|---|---|
| **Source** | Fruit sales (Berry Market + every town's store, Ch. 3.3) | 8–120 per fruit by seed tier | Primary income, all game |
| **Source** | Gloomling clears | 3–10 drop | Small on purpose; combat is not a farm |
| **Source** | Service quest stipends | 15–30 | Paid by the town, flavor: gratitude |
| **Source** | Mission Trip payout | 60 + renown | Weekly-capped |
| **Source** | Standing rank-up gift | 100 / 250 / 500 | Neighbor / Friend / Guardian, per town |
| **Sink** | Rosie's Seeds — higher-tier seeds | 40–800 | Existing; Gloryberry seeds stay premium |
| **Sink** | Toolworks — tool upgrades | 150–1,200 | Existing |
| **Sink** | Town restoration donations | 25 per meter tick | Optional accelerant, capped at 30% of any town's meter |
| **Sink** | Wayfarer kit (per-region consumables) | 10–50 | Murkmire waders, Whisper Gorge lantern oil, ferry fare pre-seal-6 |
| **Sink** | Chapel offering box (any saved town) | any amount | Pure generosity sink; feeds group renown, returns nothing personal |
| **Sink** | Cosmetics (outfits, garden decor, Ember accessories) | 200–2,000 | Largest late-game sink |

Two rules with mechanical teeth. First, **generosity is rewarded but not transactional**: restoration donations and offering-box gold convert to group renown at 1 renown per 10 gold (tunable), never to personal stat gain. Second, **no gold purchase ever touches combat power** — Truth Serums and Wayfarer's Kit rewards are unbuyable, and serum recharges are free at any library, never sold. The single sanctioned exception is logged in the gear table (lantern housing) so nobody adds a second.

Target economy health metric: a daily player ends each week within ±15% of gold-neutral until seal 4, then runs a mild surplus that cosmetics absorb. Proof by worked example — **week-3 daily reader, Starberry tier, all values tunable**:

| Week-3 ledger line | Gold |
|---|---|
| Fruit sales (10 fruit/day × 35 avg × 7 days) | +2,450 |
| Quest stipends + Gloomling drops + one Neighbor rank-up gift | +520 |
| Starberry seed repurchase (14 seeds × 70) | −980 |
| Wayfarer kits + restoration donations | −830 |
| Toolworks upgrade installment + one cosmetic | −1,000 |

Net: **+160 on ~2,970 income (+5%)** — inside the ±15% band. Any tuning pass that moves a table value must re-run this ledger.

### 3.3 Fruit, town stores, and public plots

Fruit is the Glowlands' tradable good — never a currency, always a thing you grew. Three rules give it reach across the whole map:

- **Every town has a store.** Each of the six seal towns (and Everlight's outbound-shaped variant, Ch. 16) runs its own store that **buys fruit at Berry Market-tier rates and sells seeds** — Meadow Town's Berry Market and Rosie's Seeds are the originals; every later town carries a stall, cart, annex, or rack of its own (specced per atlas entry). A traveling player can always turn a harvest into gold and gold into the next crop without walking home.
- **Every town has open public garden plots.** A small bed of free, first-come plots (3–5 beds, tunable) sits in every town — the player plants seeds there and the crop grows in real time while they travel, exactly like home plots. Public plots are per-player instanced (nobody can touch your row), and tending any town's public plot ticks +1 Standing in that town (capped 1/day/town). The journey never takes the player away from growing things; it multiplies the places they grow.
- **Fruit is the generosity medium.** Restoration donations, Feast Tables (3.8), relief crates, and needy-NPC feeding all consume fruit. Selling fruit makes gold; giving fruit makes light — the player feels the difference every time they open the satchel.

There is no water resource anywhere in the expansion economy — growth runs on time and tending, reading pays XP directly, and the only meters on the HUD are gold, XP, and the Lantern.

### 3.4 The Lantern: brightness tiers

**The algorithm (single source of truth):** brightness is a stored stepwise value, not a streak lookup — each completed plan day raises it one tier (max Radiant); each 48 h gap without a completed plan day lowers it one tier (min Spark). A Radiant player who misses one day is still Radiant; at 48 h they drop to Beacon, and re-climb one tier per reading day. The streak column below is illustrative only — the pace of a never-missing reader climbing from zero.

| Tier | Alias | Illustrative streak | Light radius (m, tunable) | Access |
|---|---|---|---|---|
| Spark | 1 | 0 (lapsed) | 4 | Saved towns, Home Garden, roads between them |
| Flame | 2 | 1–2 days | 7 | + trial zones (Murkmire, Whisper Gorge — and Hollowkeep beyond the gorge), dark-flagged Mission Trips |
| Beacon | 3 | 3–6 days | 11 | + unsaved-town Gloom districts |
| Radiant | 4 | 7+ days | 15 + warm bloom on nearby NPCs | + frontier missions, night events, seasonal surge zones |

These four names are the only brightness vocabulary in the game; every "tier 2+" gate in this document means Flame or higher. Daytime Mission Trips carry no lantern requirement at all (Ch. 4).

**Onboarding rule (closes the day-1 gate):** Meadow Town's core district is always accessible pre-seal-1 regardless of tier — it is the world's sole gateway and can never be dark to a newcomer. The Lantern itself enters the game diegetically: it is granted mid-prologue by **Zohar, Emissary of Everlight**, after the player passes a small test of compassion at the fountain (Ch. 7). The prologue's next beat *is* the first plan day: completing it lights the new lantern to Flame on the spot, so every player exits the prologue with a lit lantern and the Gloom already driven from the square.

**Pressure valve (keeps gates from becoming punishment):** every mandatory main-path zone sits at Beacon or below; Radiant gates only optional content. Additionally, completing any 7 plan days within a rolling 10 counts as Radiant for gate purposes — a committed 5-day-a-week reader is never locked out of anything, only late to extras.

Radius is literal: a point light plus a ground decal ring, and Gloomlings cannot cross its edge. At Spark, the world is not punished — it is simply safe; dark zones show a gentle gate line ("Your lantern isn't bright enough yet — Eli can help you relight it") that deep-links to today's plan. Named Gloom territory additionally uses **zone-constant** in-world radii for spatial gameplay (Ch. 2 decoupling rule) — streak tier decides entry, never the fight.

### 3.5 Lantern Seals and per-town Standing

The six seals are the spine and are covered structurally in the atlas; economically, each seal adds +5% to **one global fruit-sale multiplier** applied wherever fruit is sold — Berry Market included (stacking to +30% at six seals, tunable). Because the bonus is global, the endgame ceiling reinforces the Berry Market's gold-per-minute crown rather than competing with it: saving the world literally enriches the garden.

Standing (Stranger → Neighbor → Friend → Guardian) is earned per town. The **default** economy is rank thresholds of 10 / 30 / 60 Standing points (tunable) from sources like these:

| Standing source | Points (tunable) | Cap |
|---|---|---|
| Service quest completed in that town | 4 | none |
| Restoration meter tick contributed (labor or donation) | 1 | none |
| Feast Table fruit donation | 3 | 1/week/town |
| Public-plot tending (plant or harvest, Ch. 3.3) | 1 | 1/day/town |

Towns may override the point values and thresholds with their own economies (each atlas entry lists its own sources); the **pacing target is the invariant, not the numbers**: an engaged player (roughly two service quests plus public-plot tending per day) reaches **Guardian in ≈7–8 days of engaged play**, about the span they naturally spend earning that town's seal. Guardians get one town-specific privilege with real utility, specced in each atlas entry (e.g. Riverbend: free flood-season crop storage at the granary; Glimmerton: backstage pass — the temptation minigames replay for cosmetics).

### 3.6 Group renown

Renown is the youth-group-level score, extending the Garden League. Sources: Mission Trips, offering-box gold, and each member's weekly seal/standing progress. It runs on two tracks: **lifetime renown** (never decays; drives the renown ladder in Ch. 4) and **weekly renown** (decays 20%/week, tunable, so standings stay contestable). Monuments are permanent once earned — lifetime-milestone unlocks that never revoke: Meadow Town square banner at 2,000 lifetime renown, a stained-glass chapel pane at 750 lifetime per town, chapel-bell peal on group login at 5,000 (all tunable). Decay touches only the weekly competitive score that seeds the Garden League. Renown buys nothing personal.

### 3.7 Gear and items

| Slot | Items | Acquisition | Effect |
|---|---|---|---|
| Wayfarer's Kit (6 story milestones) | Lie-Lens, Quickstrap, Deepwell Vials, Keeper's Hood, Morningstar Oil, Beacon Prism | Story milestones only, one per major arc | Mechanical, one legible effect each — single spec in the milestone-reward table (Ch. 2.7) |
| Dragon Whistle | One inventory item | Murkmire, by conversation (Ch. 9) | Summons/dismisses Ember as traveling buddy; required at the two Ember obstacles (Ch. 9, Ch. 10) |
| Lantern | 1 lantern, upgradeable housing (3 tiers) | Toolworks gold | +1 m radius per tier **in trial zones only** (Murkmire, Whisper Gorge), capped +3 m; inert in Gloom districts, Hollowkeep, and frontier zones. This is the sole sanctioned gold-to-safety purchase in the game — logged here so nobody adds a second. Never substitutes for streak tier |
| Satchel | Verse Satchel | Level-gated slots | Loadout choice is the build system |
| Consumables | Lantern oil, waders, trail bread | Gold | Region utility, trial timers; oil extends burn duration, never radius |
| Cosmetics | Outfits, Ember accessories, garden decor | Gold / Guardian rewards / Ember-sparks | No stats |

### 3.8 Late-game relevance of seeds and the Garden League

Gloryberry-tier crops are the only accepted input for two endgame sinks: chapel offering conversion at double renown rate, and **Feast Tables** — a weekly per-town service event where donated high-tier fruit feeds NPCs. In a saved town (the only place Feast Tables run), the output is defined as: +3 Standing (per the Standing table) and **ticks on that region's surge-defense meter** — the seasonal-surge system's shield. A filled defense meter shortens the next seasonal Gloom surge on that region's edges by up to 50% and upgrades its reward cosmetic (tunable). This makes the best seeds a late-game production goal rather than a solved checkbox, keeps Rosie's Seeds and Toolworks meaningful past seal 6, and gives every feast a visible defensive purpose. The Garden League gains a Glowlands division: weekly league score = garden output + weekly group renown, so a group strong in missions but weak in farming (or vice versa) still competes.

### 3.9 Retention architecture

| Cadence | Loop | Time cost |
|---|---|---|
| Daily | Read plan day → lantern rises a tier → XP paid → tend garden (home + any public plots) → one red-bag question → optional 1 frontier push or Town Book section | 8–15 min |
| Weekly | Garden League scoring, 3 Mission Trip charges, Feast Table event (feeds surge defense), weekly-renown decay tick, Standing progress | 2–3 sessions |
| Seasonal (6–8 wk) | Named Gloom surge on one region's edges (visual dimming, bonus battles, unique cosmetic set), mitigated by that region's surge-defense meter; League season reset with monument rewards; new mission variants | opt-in |

The daily loop's spine is the reading session itself; everything in-world is a consequence of it, never a substitute. Weekly cadence is group-facing so lapsed players get pulled back by teammates, not by fear of loss — nothing a player owns is ever taken. Seasonal surges re-darken *edges* of saved regions (never the town cores, which stay saved permanently) to give veterans fresh frontier without violating the promise that saving a town sticks.

### 3.10 Town Books — the library reading system

Every seal town's library hosts one book of the Bible as an **in-game reading plan** — distinct from the app's existing plans, living entirely inside the town, read at the library's reading desk. **This section is the single spec; atlas entries state each town's book and point here.**

**The books (journey order, each chosen for its town's theme):**

| Town | Book | Why |
|---|---|---|
| Meadow Town | **The Gospel of John** | Mirrors the app's free Plan 1 — the gateway town carries the gateway book |
| Riverbend | **Philippians** | The flood town's lie is worry; "do not be anxious about anything" is its cure |
| Lantern Hollow | **1 John** | "God is light; in him there is no darkness at all" — the lantern town's charter |
| Glimmerton | **Ecclesiastes** | Chasing glimmer, and what's left when the wheel stops spinning |
| Starcrest | **1 Peter** | The Chief Shepherd, the flock, and hope kept through the night watch |
| Brightharbor | **Acts** | The sending harbor reads the sending church |

(Everlight City's Great Library hosts **Revelation** as the postgame book — the city of light reads the city of light; Ch. 16.)

**How a Town Book plays.**

- **The text is ESV, served — never bundled.** All displayed verse text is fetched at runtime through the platform's `get-bible-passage` edge function (ESV via the Crossway API, cached server-side in `bible_cache` with a 30-day TTL, `ESV_API_KEY` secret). No client ever ships verse text in its bundle; retellings and questions are original prose. If the translation is momentarily unavailable, the reader degrades gracefully to reference + retelling. LOCKED.
- **Open the book, hear the Word.** The player sits at the library desk and opens the book; **recorded audio narration plays** — built on the app's existing **ElevenLabs verse-narration pipeline** (the same recorded-audio system that replaced device TTS in the daily plans), so every chapter ships fully voiced, warm and unhurried, text highlighting line by line.
- **Chapter structure.** Each chapter is split into **3 sections**. A section ends with **one comprehension question** (4 choices, warm retry on a miss — a giggle-adjacent "look again," never a penalty). Completing a section pays **XP and fruit** (Ch. 3.1 table) — in-town Bible lessons feed the same wallets as everything else.
- **Memory-verse checks.** Occasional sections (authored, roughly one per 2–3 chapters, tunable) end instead with a **memory-verse challenge** on that passage's key verse. Passing it mints the verse as a **Truth Serum** (Ch. 2.3) — with the Lightfound fanfare. Town Books are therefore the in-world serum mine, exactly parallel to the app's plan-day challenges.
- **Progress is per-town and permanent.** A book's bookmark never regresses; finished books stay on the shelf with the player's name on the spine (a library flex the historian will mention). Finishing a Town Book cover to cover grants a town-themed cosmetic and +25 Standing (tunable).
- **Recharge lives here too.** The reading desk doubles as the serum recharge point (Ch. 2.3) — one trip to the library refills the satchel and advances the book, so the Pokémon-center rhythm and the reading habit are the same habit.

**Boundary rules (hard).** Town Books never touch the Lantern — brightness binds exclusively to real app reading (pillar 1 stays clean: the game cannot substitute for the app's plans). Town Book sections are capped at 3/day/town (Ch. 3.1) so they season sessions rather than replacing the daily plan. Scripture in Town Books is quoted accurately, full text, reference always shown — same LOCKED rule as everywhere.

---

## 4. Multiplayer — Mission Trips

Mission Trips are the only multiplayer play in the Glowlands: instanced, drop-in co-op service missions — **typed minigames** (soccer with local kids, hosting a VBS, rebuilding a broken house, flood help) — whose **2–8 slots fill with any combination of live players and bots**, entered through a **lobby** and launched from mission boards in saved towns — the game's answer to the real-world church mission trip. Missions grant **player XP** (Ch. 3.1) — trips level you up. Main-map exploration stays single-player; Mission Trips are where people show up.

### 4.1 Matchmaking and lobbies

Every trip starts in a lobby, and every lobby fills. The slot-fill order is: (1) the player's own youth group (the Garden League roster) gets first call via banners and pushes; (2) open slots then accept any live player whose lobby search matches the mission — cross-group play is safe by construction, because all communication is the authored quick-phrase wheel (4.3, Ch. 5.9); (3) at launch, **bots backfill every remaining slot**, so a mission always starts on time with a full-feeling crew. Bots are visibly bots — townsfolk-styled helpers with a small lantern-badge tag, never fake friends — and each player's renown still credits their own youth group.

**The mission board.** Each saved town's square holds a mission board with 1–3 posted missions (rotation below), showing: mission name, player range, expected length, lantern requirement, and portraits of groupmates currently in a lobby or in-mission. Boards exist only in saved towns — starting a trip always means standing in a place your group helped save. The Community Garden carries a companion **Trip Tracker** (see renown ladder): read-only for hosting — it lists groupmates' open lobbies and lets you *join* one, but new lobbies open only at a town board.

**Lobby flow.**

1. Player taps **Start a Trip** at a town board → creates a lobby; or **Join** on an open lobby (a groupmate's, from any board or the Trip Tracker; or an open-slot lobby surfaced by the board).
2. Lobby is broadcast to the youth group as an in-game banner ("Maya is gathering a trip to Riverbend — 2/8") and, for group members not currently in-game, an app push. Push cap: 1 mission push per user per day (tunable; raised by renown, see ladder).
3. Host sets a **launch window**: Go Now, or a 2-minute gather timer (tunable). Either way the mission launches full: at launch, every unfilled slot is taken by a bot — a lobby of one live player plus seven bots is a valid, fun trip, and no host ever waits on a quorum.
4. Ready-check → 3-second countdown → the lobby loads the multiplayer session (instance load).

**Drop-in, drop-out, and reconnect.** Missions accept fresh joiners until the halfway objective marker; a joining live player takes over a bot's slot mid-stride (the bot waves and jogs off — tasks hand over cleanly), and late joiners spawn at the staging area with a "runner" escort arrow to the group. No drop-out penalty ever — a leaver's tasks return to the shared pool, or a bot steps in to hold the slot. A **disconnected player is not a leaver**: their slot holds for 3 minutes (tunable), their claimed tasks pause rather than release, and they rejoin in place at any point regardless of the halfway marker — only never-before-seen joiners are halfway-gated. On phones over WKWebView, a 20-second signal drop is the common case, not the edge case.

**Lantern gate.**

> **Canon amendment — DECIDED (this revision):** the Lantern gates *dark-flagged* missions only (Flame and above); daytime missions carry no lantern requirement. Rationale: canon's retention pillar also says skipped days mean "safe zones only, never punishment" — benching a kid from serving alongside their group on group night is punishment, so daytime service missions are classed with safe zones, and darkness remains the thing reading unlocks.

Dark missions additionally support the **Torchbearer rule** (see Midnight Rescue) so an under-tier groupmate is escorted in, not left outside.

### 4.2 Session flow

Every trip uses the same five-beat spine so players always know where they are:

| Beat | Duration (tunable) | What happens |
|---|---|---|
| Send-off | 20 s | NPC host states the need in one line; role picks; camera flyover of the site |
| Work | 6–10 min | Core objectives; the shared meter fills |
| Turn | scripted moment | Mid-mission complication (flood surge, lost kid, blackout wave) |
| Push | 2–3 min | Compressed finale, all hands on one objective |
| Campfire | 45 s | Rewards, per-player highlight cards ("Most crates carried: Maya R."), group photo pose, renown tally |

Campfire is unskippable by the host (players may individually leave). It is the social payoff: everyone's contribution is named, nobody's is ranked as "worst." Bots appear on the campfire roster with their lantern-badge tag; highlight cards go to live players first, and the renown tally lands with the Lightfound fanfare (Ch. 5.7).

**Networking scope.** Instances run on the existing position relay: server-authoritative objective state (meters, task claims, timers), client-simulated movement at 10 Hz quantized transforms with interpolation. No synced physics, no player collision; carried objects parent to the carrier's hand bone locally. The 8-player cap is the tested phone budget for interpolated skinned characters plus mission props.

### 4.3 The quick-phrase wheel

No free text anywhere in multiplayer. Hold the chat button to open an 8-slot radial wheel; release on a slot to emit a chat-bubble phrase plus matching emote animation. Two contextual slots swap per mission phase.

| Slot | Phrase | Emote |
|---|---|---|
| 1 | "Over here!" | wave + map ping at speaker |
| 2 | "Nice work!" | double thumbs-up |
| 3 | "Need help!" | hand raise; outlines speaker for 5 s |
| 4 | "Follow me" | beckon; leaves 8 s footprint trail |
| 5 | "Thank You, God!" | small jump, small Lightburst flare |
| 6 | "On it" | salute; auto-claims nearest task |
| 7 | *contextual* (e.g. "Sandbags here!") | mission-specific |
| 8 | *contextual* (e.g. "Kids incoming!") | mission-specific |

Phrases are authored strings, never composable — nothing to moderate, nothing to misuse. Cooldown 2 s per player (tunable). Slots 1, 3, 4, 6 also fire a ping on the minimap, so the wheel doubles as the coordination layer.

### 4.4 Difficulty scaling, 2–8 players

Scaling is **workload, not danger**. Missions never add tougher enemies at higher counts; they add more need. Scaling counts **live players at full weight and bots at half weight** (tunable), so a lone player with seven bots gets a gentler task load than a full live eight — bots fill the scene, players carry the mission.

| Dial | Rule (tunable) |
|---|---|
| Task volume | base × (0.6 + 0.4 × weighted-players⁰·⁹) — sublinear, so small crews aren't crushed; bots weigh 0.5 |
| Timer | fixed regardless of count; pressure comes from volume |
| Multi-carry objects | objects tagged 2-person at ≥4 slots (beam carry, stretcher); a bot always pairs up for a 2-person carry if no live partner is near |
| Turn intensity | complication spawns scale 1 per 2 weighted players |
| Bot ceiling | bots complete tasks ~20% slower than an average live player and never claim the last objective — the finishing beat belongs to people |

Fail is soft everywhere: timers expiring downgrade the outcome tier, never eject the group. The worst possible result of a Mission Trip is "the town thanks you and asks you to come back."

### 4.5 Launch missions

The four launch missions implement the four locked archetypes: disaster rebuild (Flood Rebuild), VBS hosting (VBS Host), soccer with kids (Kickabout), and city rescue (Midnight Rescue, dusk-town implementation — see its entry).

#### 1. Flood Rebuild — Riverbend (2–8, ~10 min, daytime)

The river has breached the east levee; the Miller farmstead is knee-deep. Riverbend's signature mission, the flood-help archetype, and Phase 2's co-op proof (Ch. 18).

- **Objectives.** Phase 1: stack sandbag wall to 100% (carry loop from the supply cart; bags are 1-person, wall segments claimable). Phase 2 (Turn): surge alarm — 60 s to plug 3 breach points with 2-person timber braces. Phase 3: bail and sweep water out of the farmhouse (rhythmic tap minigame per room), replant the washed-out Glowberry rows — including the shared two-crank Flow Routing puzzle from Riverbend's Locks (Ch. 8) as the water-drain step.
- **Roles (soft, picked at Send-off).** *Hauler* (+25% carry speed), *Builder* (places braces 40% faster), *Planter* (replants two rows at once). Roles are buffs, not locks — anyone can do anything.
- **Success tiers.** Gold: levee 100% and every row replanted before timer. Silver: levee holds, some rows lost. Bronze: timer out — town NPCs finish the wall while thanking players.
- **Rewards.** Renown 120/90/60 by tier; per-player 40 gold, 1 Starberry seed; Gold adds the **Riverbend Work Gloves** cosmetic.

#### 2. VBS Host — Meadow Town (2–8, ~8 min, daytime)

Pastor-analog NPC Miriam is running Vacation Bible School on the green; 12–24 kid NPCs (scales with players) need stations run simultaneously.

- **Objectives.** Keep 3 station meters (Crafts, Songs, Story Circle) above 50% "delight" by staffing them; escort arriving kids from the gate; Turn: sudden rain — 90 s to move every station under the pavilion (2-person table carries). Finale: Story Circle question — each player answers one red-bag-style Bible question in front of the kids (wrong answers get a giggle and a retry, never a penalty).
- **Roles.** *Craft Leader*, *Song Leader* (rhythm minigame), *Storyteller* (question slot priority), *Greeter* (kid escort speed).
- **Success tiers.** By average delight at closing bell: Gold ≥85%, Silver ≥60%, Bronze below — kids still hug everyone goodbye.
- **Rewards.** Renown 100/75/50; 30 gold; Gold adds the **Paper Crown** cosmetic (a kid makes it for you at Campfire).

#### 3. Kickabout — Brightharbor (2–8, ~8 min, daytime)

Dockside kids challenge the group to street soccer between crate stacks; the deeper hook is the dockworkers watching. Home board: Brightharbor — but see rotation below; Kickabout is in the visiting pool from week one.

- **Objectives.** Two halves of 3 min vs kid NPC team (arcade ball: tap-pass to teammates, hold-shoot; NPC keeper). Between halves, a service interleave: 60 s to help a struggling dockhand restack spilled crates — done or not, the second half starts. Turn: the kids ask to mix teams, half the players swap sides; final score becomes combined goals, converting the mission from versus to together.
- **Roles.** None — positions emerge. The ball carrier gets a subtle glow so spectators on phones can track play.
- **Success tiers.** Gold: crates done + 8 combined goals. Silver: either. Bronze: neither — the kids demand a rematch anyway.
- **Rewards.** Renown 100/75/50; 30 gold; Gold adds **Harbor Cleats** (+3% run speed in missions only, tunable).

#### 4. Midnight Rescue — Lantern Hollow (2–8, ~10 min, dark, Flame+)

A Gloom pocket has crept back into the mill district after dark; four townsfolk are stranded in it. The only combat-flavored launch mission, and the launch implementation of the **city-rescue archetype** — the mill district stands in for a city until the full urban version, **Glimmerton Blackout** (first post-launch mission), ships. Minimum is 1 live player: bots cover the verse duet and escort work, so no floor above the global one is needed.

- **Objectives.** Players' lantern radii are their safety; overlapping radii merge into a larger pool (simple additive light volume, cheap on r128). Locate 4 stranded NPCs (audio whimpers + faint glow through fog), escort each back to the chapel — escorted NPCs walk only inside someone's radius. Gloomlings intercept escorts and whisper lies at the *NPC* ("They came for the reward, not for you"); any player in range counters via standard Verse Satchel play — a right verse Lightbursts and extends every nearby radius +30% for 10 s (tunable). Turn: chapel lantern gutters; 2 players must relight it (verse duet: both answer within 8 s) while others hold the courtyard bright.
- **Torchbearer rule.** A groupmate below Flame may still join as a *Torchbearer*: the chapel lends them a fixed-radius lantern (no radius buffs, no Beacon/Hoodbearer roles), and they earn full mission rewards. The gate motivates reading; it never benches anyone on group night.
- **Roles.** *Beacon* (+20% radius), *Seeker* (rescue pings at 2× range), *Hoodbearer* (requires the Keeper's Hood, Ch. 2.7; snuffs one lie before it lands for the group per rescue).
- **Success tiers.** Gold: all 4 rescued, chapel never fully dark. Silver: all 4 rescued. Bronze: timer out — Eli arrives with a floodlantern and walks the rest home; players escort him.
- **Rewards.** Renown 150/110/70; 50 gold; 1 guaranteed new Truth Serum (via a campfire memory-verse challenge); Gold adds the **Hollow Lamplighter's Hood**.

**Board rotation.** Each saved town posts its signature mission permanently, plus one visiting slot rotating weekly aligned to the Garden League reset. The visiting slot draws from **any launch mission regardless of its home town** (plus, post-launch, any mission the group has unlocked) — so Kickabout is playable from the Meadow Town board in week one, and no mission waits for seal 6 to be touched.

### 4.6 Group renown ladder

Renown's lifetime track (Ch. 3.6) drives a youth-group-wide ladder, parallel to (not part of) weekly Garden League scoring. It never decays; every member's missions feed it, so small groups climb by faithfulness, not size.

| Tier | Renown | Group unlock (visible in Community Garden) |
|---|---|---|
| Gathered | 0 | **Trip Tracker** notice-post: read-only board listing groupmates' open lobbies (joinable from here; hosting still requires a town board) |
| Sent | 500 | Campfire ring set piece; group banner on all mission Send-offs |
| Known | 1,500 | Trip Wagon prop; each member's daily mission-push cap rises from 1 to 2 |
| Trusted | 4,000 | NPC letters: saved-town NPCs visit the Community Garden |
| Beloved | 9,000 | Group statue plinth ("The Helpers of ___") + golden lantern strings |

Garden-hosting is deliberately absent from this ladder: mission boards live in saved towns, and the ladder must not erode that. A Trusted+ garden-hosting perk would require an explicit canon amendment, not a table edit. Renown milestones fire a pastor-visible summary in the CMS — the ladder gives real youth leaders something to celebrate on Wednesday night. All numbers are tuning placeholders pending economy balancing.

---

## 5. Systems & feel

This chapter defines how Glowlands feels in the hand: input, camera, movement, interface language, persistence, atmosphere, audio, performance, safety, and accessibility. Everything here targets low-poly three.js r128 inside a WKWebView on a three-year-old iPhone. All numbers are tuning placeholders unless marked LOCKED.

### 5.1 Controls: touch-first, one thumb by default

The whole game is playable with one thumb in portrait. Two-thumb play (landscape) is supported but never required.

| Input | Behavior |
|---|---|
| Tap ground | Move-to-point with path preview ribbon (fades in 120 ms, gone on arrival). Primary locomotion. |
| Tap interactable | Walk-then-interact. Interactables show a soft glow pulse within 4 m (tunable). |
| Hold anywhere 150 ms+ | Floating virtual stick spawns under the thumb, dead zone 12 px, max throw 56 px. Direct steering for players who prefer it. |
| Swipe (quick, <150 ms) | Camera nudge, ±30° yaw, spring-return off. |
| Pinch | Camera zoom between two fixed framings (see camera). No free zoom. |
| Contextual hop (no button) | Auto-vault over knee-high obstacles and small ledges when the path crosses one; also fires on one-way drops (Starcrest ledge) and hopping off Ember. Drives the stretch/squash pair below. |
| Double-tap Ember button | Ember hop-to-shoulder / dismount (button appears once the Dragon Whistle is earned in Murkmire; endgame flight uses the same button, context-sensitive; see camera: flight). |

Truth & Light encounters replace the stick entirely: the screen becomes the Verse Satchel — 3–5 verse cards docked at the bottom, each a fixed 88 pt collapsed row showing reference plus first phrase ("John 8:12 — 'I am the light…'"). Tap-and-hold, or the chevron on the card's right edge, expands one card at a time to full reflowed Scripture (never truncated); expanding one collapses the last. Five-card encounters scroll within the docked tray, with a soft edge-fade at top and bottom as the affordance that more cards exist. On SE-class screens (<2nd-gen-SE viewport height) encounters cap at 4 simultaneous cards. Tap to answer; no timing-based dexterity in combat, ever. Speed can raise style score in trials; it never gates success.

Rules: no gestures with more than two fingers; no drag-and-drop under time pressure; every interaction reachable by tap alone. All UI hit targets ≥ 44 pt.

### 5.2 Camera

One camera rig, four states, all interpolated with critically damped springs (no lerp snaps).

| State | Framing | Where |
|---|---|---|
| Roam | 3/4 overhead, pitch 52°, distance 11 m, FOV 45 | Towns, garden, overworld |
| Close | Pitch 38°, distance 6.5 m | Interiors, conversations, shops |
| Encounter | Locked over-shoulder of the player facing the Gloomling, verse cards docked bottom | Truth & Light |
| Flight | Chase cam behind Ember, pitch 30°, distance 16 m, FOV 55 | Endgame steeple-to-steeple flights |

Flight is not free flight. Each trip is a canned spline between chapel steeples: takeoff arc, one banking pass over the destination town, landing flare (18–30 s per route, tunable). During the pass the town below is an LOD-swapped far-shell — merged silhouette geometry, baked palette textures, no props, no NPCs — so the aerial view stays inside the same triangle and draw-call budget as ground play. The full-detail town streams in during the landing flare, masked by Ember's wing-fold animation.

Yaw is player-nudged (swipe) but auto-recenters behind the walk direction after 2.5 s idle. Collision: camera spheretraces and shortens boom, never clips geometry; walls between camera and player dither-fade (alphaTest dissolve, cheap on mobile). In Whisper Gorge and Hollowkeep the Roam distance tightens to 8.5 m and pitch drops to 44° — the world crowds in without any new tech.

### 5.3 Movement feel and juice

Base walk 3.2 m/s, sprint 5.0 m/s (auto-sprint after 1.5 s of continuous travel in safe zones; disabled in Murkmire, where carried-weight drag is the trial). Turn is snappy: 540°/s yaw with 80 ms of ease-in so direction changes read as eager, not robotic.

Juice budget — cheap tricks, no ragdolls, no cloth sim:

- **Squash-and-stretch on the character root**: 3% stretch at the apex of a contextual hop or ledge drop, 4% vertical squash on landing (including hopping off Ember). Scale-only, zero skeleton cost.
- **Footstep puffs**: 3-particle billboard poofs, color-matched to surface (dust, grass, mud, snow at Starcrest).
- **Lean into turns**: root tilts up to 8° toward velocity delta.
- **Lantern physics**: the lantern hangs from a 2-bone pendulum, swings with acceleration. It is the single most-watched object in the game; its swing sells all movement.
- **Interaction bloop**: every confirmed tap gets a 90 ms scale-pop (1.0 → 1.12 → 1.0) plus a two-note chime. Same curve everywhere. This is the game's "click".
- **Lightbursts** (right verse): radial shader ring + 20 additive sparks + 250 ms exposure lift. Wrong verse: vignette closes 15%, desaturate 200 ms, Gloomling leans in. No screen shake stronger than 4 px, ever (motion-sensitivity, small screens).

**Haptics** — routed over the existing JS→native bridge to UIImpactFeedbackGenerator; the third channel of every key beat alongside its visual and audio pair:

| Moment | Pattern |
|---|---|
| Confirmed tap (with the bloop) | Light tick |
| Right verse | Soft double-pulse, 120 ms apart |
| Wrong verse | Single dull thud |
| Gloom territory ambient | Gentle heartbeat ramp, period 1.4 s → 0.9 s with proximity to Gloomlings |
| Ember takeoff / landing | Medium impact on wing-snap and touchdown |

All haptics disabled by reduce-motion and by Gentle mode.

### 5.4 HUD and UI language

The HUD speaks lantern, not menu. Persistent elements: lantern brightness meter (top left, drawn as the actual lantern), gold/XP pill (top right, collapses to icons after 3 s), context button (bottom right), Ember button (bottom left, present only once the Dragon Whistle is earned). Nothing else lives on screen while roaming.

Written UI voice: warm, second person, verbs first ("Light the lantern", "Help Rosie carry seeds"). Gloom text is the only italic serif in the game — lies look different from truth at a glance. Scripture is always set in the reader typeface used by the parent app's Bible plans, with reference line under every quote (LOCKED — brand/theology rule).

Standing, seals, and restoration meters live one tap deep on the town board, not on the HUD. Toasts (verse earned, Standing up) slide from the top, 2.5 s, max one queued.

### 5.5 Save and sync

The client is never the source of truth for anything that touches entitlements, currency, or League standing.

| Data | Where | When |
|---|---|---|
| Position, camera, cosmetic state | Local (localStorage/IndexedDB) | Continuous, 5 s debounce |
| Currency, seals, Standing, restoration progress | Server (existing backend RPCs) | On the event; currency/cosmetic deltas are optimistic with rollback |
| Truth Serums earned + charge counts | Server | Never shown as earned until server-acked — serums gate combat, so an unconfirmed serum must not enter the Satchel; charge spends/recharges are server-authoritative with optimistic display |
| Lantern brightness | Server-derived from real reading data | Read on session start and app foreground; never writable by the game client |

Rollback is player-facing, not silent. If the server rejects an optimistic currency or cosmetic gain, within 2 s the gain animation replays in reverse (coins arc back out of the pouch) with a toast in the established warm voice: "That didn't stick — try again by the lantern." Nothing ever vanishes without the reversal animation and the toast; a 13-year-old should never wonder whether the game stole from them.

Sessions resume in place inside a saved town or the garden; inside trials and Gloom territory, quitting returns you to the last safe entrance (checkpointing keeps dark zones tense without punishing a dropped connection). Offline: garden and saved towns fully playable from cache; frontier and missions require connection and say so gently ("The road needs a signal"). Conflict rule for local-only state: server wins.

### 5.6 Day-night and weather

The world clock follows the player's real local time, softened: dawn 6:00–8:00, day, dusk 17:00–19:00, night. Night is warmer, not darker — safe zones at night are candlelit-cozy, never scary. Named Gloom territory ignores the clock and holds its own oppressive palette (LOCKED tone rule: scary lives only where the player chooses to enter).

Implementation is palette-driven, not light-driven: one directional light + hemisphere light whose colors lerp through a 6-key gradient LUT; fog color follows. Zero extra draw cost. Weather is per-zone set dressing — Riverbend rain (GPU-billboard streaks + ripple decals, one material), Starcrest snow, Murkmire ground fog (two scrolling alpha planes). Weather never affects mechanics except where a quest says it does (the Riverbend flood mission).

### 5.7 Audio direction by tone zone

One adaptive layer system: base bed + up to 2 overlay stems, crossfaded on zone triggers. All loops OGG, mono where possible, ~8 MB resident budget.

| Zone type | Direction |
|---|---|
| Saved towns / garden | Acoustic folk — guitar, hand percussion, whistling. **Every town owns a unique named motif** (stated in each atlas entry's §8) so the map is navigable by ear; saving a town adds its melody stem, and unsaved towns play the same bed hollowed out (no melody, detuned 15 cents). Players hear salvation. |
| Trials (Murkmire, missions) | Pulse layer, 92–108 BPM ramp with time pressure. Tension from rhythm, not dissonance. |
| Gloom territory | Near-silence design: low pad, sparse creaks, whisper SFX for Gloomling lies (a breathy synth wash — never intelligible spoken words in audio; the lies are read, on screen, LOCKED). Lantern hum swells with brightness. |
| Everlight City | Full ensemble + choir pad. The only place the choir exists. |

Truth & Light stingers: right verse = rising major-third bell flourish; wrong = a single muffled low thud and the bed ducks 6 dB for 1 s.

**The Lightfound fanfare (global rule).** Whenever the player *receives or earns anything* — a Truth Serum, a seal, a Wayfarer's Kit reward, a seed, a secret, a Standing rank, a Town Book completion, a mission reward tally — a Pokémon-style win jingle plays: a bright 1.5 s ascending figure on bells and plucked strings resolving to the lantern leitmotif's first interval, with the item presented center-screen on a soft light bloom. One jingle, everywhere, always the same — the game's "you got a thing!" sound. Variants exist only in weight (a short 0.8 s form for small pickups, the full form for milestones); the melody never changes. No earn event may ship without it, and it never plays for anything the player did not actually gain.

### 5.8 Performance budget (three.js r128, mid-tier phone)

| Budget item | Target |
|---|---|
| Frame rate | 60 fps target, 30 fps floor on iPhone 8-class; auto-degrade order: particles → shadows → fog steps → pixel ratio (min 0.75) |
| Draw calls | ≤ 120 per frame; towns built from merged static geometry + InstancedMesh for props, lanterns, crowd NPCs |
| Triangles | ≤ 150 k on screen |
| Lights | 1 directional + 1 hemisphere + max 4 point lights (lantern always owns one) |
| Shadows | Single 1024 shadow map on the player's immediate area; baked vertex AO everywhere else |
| Textures | Gradient/palette atlases; ≤ 48 MB GPU resident |
| Load | Zone-streamed via gate transitions (gates are loading screens in costume); ≤ 4 s per zone on LTE |

Gateless shortcuts follow a preload rule: each shortcut has an approach volume (the ledge lip above the Starcrest→Glimmerton drop, the wicket antechamber behind Hollowkeep) that starts streaming the destination zone the moment the player enters it. The drop or door animation is the masking window; if the preload hasn't finished, the fall holds on a looping cloud-rush (ledge) or the corridor stays dark one beat longer (wicket) until it has. The player never sees a spinner on a shortcut.

Every VFX in this chapter is billboard particles, scale/opacity tweens, or shader tricks — nothing in this document requires post-processing beyond a single fullscreen tint quad.

### 5.9 Safety and moderation surface

Multiplayer is quick-phrase/emote only (LOCKED); the phrase list ships server-side so it can be curated without an app release. No text entry exists anywhere in Glowlands — names come from the parent app's existing moderated profiles. Mission rosters may mix youth groups and bots (Ch. 4.1), and that stays safe by construction: with no free text, no free voice, and authored phrases as the only channel, a stranger in a lobby can say nothing a curriculum team didn't write. Bots are always visibly tagged as bots. Parents and pastors can view play history, verses earned, and mission participation through the existing oversight surfaces; nothing in Glowlands is hidden from them (LOCKED). Report flow: long-press a player in a mission → "Tell a leader" → routes through the app's existing moderation queue. All screenshots/shares go through the parent app's controls; the game itself has no external share.

### 5.10 Accessibility

- **Text**: dyslexia-friendly alternate font toggle; text size respects OS setting (3 steps); expanded verse cards reflow to full height, never truncate Scripture (collapsed rows always show the reference, so nothing sacred is hidden — only folded).
- **Motion**: reduce-motion setting kills camera nudge inertia, screen tints, squash-stretch, and all haptics; lantern swing damps 70%.
- **Fear**: "Gentle mode" (findable, unshamed, in settings): raises ambient floor in Gloom territory ~20%, mutes whisper SFX and the heartbeat haptic, keeps all content and rewards identical. A scared 11-year-old finishes the same game.
- **Color**: brightness/glow states double-coded with shape (lantern flame size + icon), never color alone; glimmer vs glow distinguishable by animation (glimmer flickers, glow breathes).
- **Timing**: every trial timer has a +50% assist toggle; Truth & Light has no timer by design.
- **Audio**: all Gloomling lies and NPC dialog are text-first; no meaning is carried by audio alone.

---

# Part II — World atlas (journey order)

Eleven entries in journey order. Every entry opens with a **Seam** callout — the gating chain into and out of the zone — and uses the same nine numbered sections. The full chain, end to end, with each leg's named road in brackets:

```
Home Garden ─(Eastgate, opens in prologue)→ [Garden Path] → Meadow Town
  ─(East Gate: Seal 1 + restoration)→ [the East Road] → Riverbend
  ─(Locks gate: Seal 2 + restoration; Flame lantern beyond)→ [the Levee
    Trace] → Murkmire
  ─(Willow Arch: ≤2 Burden, Mire-Mother outlasted)→ [the Fen Boardwalk]
    → Lantern Hollow
  ─(East Palings: Seal 3 + restoration)→ [the Palings Road] → Glimmerton
  ─(Gorge Gate: Seal 4 + restoration; Flame lantern beyond)→ Whisper Gorge
    (the gorge IS the road)
  ─(Hollowkeep Doors: one-way on first entry)→ Hollowkeep
  ─(Sun Gate: Dawnkey)→ [the Dawnroad] → Starcrest
  ─(North Saddle: Seal 5 + restoration)→ [the Shepherd's Descent]
    → Brightharbor
  ─(ferry: downstream-only from arrival; two-way at Seal 6 + restoration)
    → Meadow Town
  ─(Pilgrim Stair + Six-Seal Gate: all six seals)→ Everlight City
  ─(Wicket of the Morning, post-finale)→ Home Garden

Shortcuts (late-to-early folds): orchard tunnel Meadow Town↔Lantern Hollow
(shears, post-seal-3) · Dawnkey wicket-gate Hollowkeep→Glimmerton · one-way
ledge drop Starcrest→Glimmerton (arms on save) · ferry Brightharbor↔Meadow
Town (two-way post-seal-6) · endgame Ember flight to any saved town's chapel
steeple.
```

## Roads of the Glowlands (routes interlude)

Towns are connected — and kept apart — by **named roads**. A road is not a loading corridor; it is a place with its own weather, its own regulars, and its own work. Two challenge types run on every road (both feed the Ch. 3.1 road-challenge XP row, capped 5/day):

- **Traveler aid** — rotating micro-quests (60–120 s, tunable) with a small authored cast per road: a tinker's cart with a thrown wheel, a lost delivery, a pilgrim who needs walking to the next waymarker. Helping pays XP, occasional fruit, and Standing in the nearest town.
- **Gloom patrols** — 1–3 Gloomling spawns at authored ambush points, denser at dusk and in the leg's darker half. Standard Truth & Light; repelling a patrol relights that stretch's waymarker for the rest of the session.

Red bags spawn on all roads (Ch. 1.5), and each road carries one wayside public micro-plot (1 bed; Ch. 3.3 rules).

**The East Road (Meadow Town → Riverbend) — the model road, specified in full.** ~3 minutes end to end at walk speed, opened by Meadow Town's save. It descends from the East Gate through orchard shoulders into river bottomland, and the palette makes the journey legible: Meadow Town's cream-and-terracotta warmth drains mile by mile into Riverbend's wet slate. Named beats, in walk order: (a) the **Milepost Oak**, a lightning-split oak with a red-bag hollow and the road's noticeboard — traveler-aid quests post here; (b) **Wren's Crossing**, a plank bridge over a creek where the road's recurring cast camps (Odd Tobbin's tinker cart most days — his wheel is *always* newly wrong in a new way, the road's running joke); (c) the **Low Stones**, a half-sunk shrine row where Gloom patrols cluster after dusk — three waymarker lanterns to relight; (d) the **Rise**, a final crest where Riverbend's flooded valley opens below in one reveal shot — the player hears the rain bed fade in before they see the water. The East Road is also Phase 1's frontier edge (Ch. 17): until Riverbend ships, the Rise ends at a friendly road-warden's camp ("River's high past here — come back soon") rather than a wall.

**The other legs, briefly.** The **Garden Path** (Home Garden → Meadow Town) stays a 20 s safe, Gloomless walk — never a challenge road. The **Levee Trace** (Riverbend → Murkmire) runs the drowned levee top: aid beats favor flood salvage; patrols whisper Worry-family lies. The **Fen Boardwalk** (Murkmire → Lantern Hollow) is planked and lantern-hooked; its aid beats are lamp-oil deliveries, and Burden Weight (Ch. 9) stays live on it. The **Palings Road** (Lantern Hollow → Glimmerton) is a short ridge lane where Glimmerton's neon glow slowly outshines the stars — one authored aid beat: a moth-drunk traveler walking the wrong way toward the lights. **Whisper Gorge is itself the road** to Hollowkeep and is specced as a full trial zone (Ch. 12). The **Dawnroad** (Hollowkeep → Starcrest) is a blessedly empty switchback climb — no patrols by design; the exhale starts here. The **Shepherd's Descent** (Starcrest → Brightharbor) winds down through cloud into gull-sound; aid beats are flock escorts using the Crook Call. The **Pilgrim Stair** (Meadow Town → Everlight City) is specced in Ch. 16.

Roads keep towns separated on purpose: no two towns are ever visible from each other at ground level (the Rise reveal and the Palings glow are framed exceptions), so each arrival lands as an arrival.

## 6. Home Garden & Community Garden (hub)

> **Seam.** Home Garden → Meadow Town: the **Eastgate** arch opens in the prologue and never closes; the Garden Path is a 20 s safe, Gloomless walk to Meadow Town's West Gate. The Community Garden's only gate is the south gate to Home Garden — it has no exit to the world and no quest ever routes through it. Post-finale, Everlight City's Wicket of the Morning drops back into the Home Garden. Nothing here is ever at risk or gated.

The world opens outward, never inward. When the Glowlands campaign lands, the two gardens the player already loves must feel exactly as safe, exactly as theirs, on day one — the only visible change is a single new archway in the east hedge and one retired footpath. Everything the expansion adds at home is diegetic furniture, not menus: the Lantern hangs on a post, the map lies on a table, the Verse Satchel sits on a hook. The Home Garden is the player's dashboard disguised as a backyard; the Community Garden is the group's trophy room disguised as a hangout. Neither ever becomes a thoroughfare, a combat space, or a place where a broken streak can be seen.

### Home Garden

**1. Fantasy & role.** Your own patch of the Glowlands, unchanged and unthreatened. It exists in the journey as the place you leave from and return to — the fixed point that proves the world can be dark without home ever being dark. Every session that touches the frontier starts and ends here by design.

**2. Visual direction.** Existing backyard palette holds: warm greens (#7CB86A base grass), honey-hour key light, soft vertex-color gradients on the low-poly hedges. New elements adopt "worn brass and oiled wood" — the Lantern Post, Wayfarer's Table, and Eastgate arch share one 256px trim texture. Weather stays fair; the only scripted change is a 12 s (tunable) dusk pass during the prologue when Eli first points east. Signature moments: (a) the Lantern Post flaring to full brightness the instant a daily reading completes — 0.4 s bloom pulse, 20 drifting light motes; (b) the overgrown east hedge shivering and shedding leaf billboards as Eli shears the Eastgate open; (c) Ember asleep on the shed roof, tail ticking like a metronome; (d) at Radiant, fireflies (30 instanced quads, tunable) orbiting the post in a slow helix.

**3. Layout.** Unchanged core: plots center-south, shed northwest, sell-crate and red-bag mailbox at the south fence. **The south path market walk is retired at campaign launch:** the old footpath south of the fence is overgrown with a hedge wall on day one; the sell-crate and mailbox stay exactly where they were and keep working, but travel to Meadow Town now routes only through the Eastgate. Eli lampshades it in the prologue's opening line ("South path's gone to bramble overnight. Odd, that. Come see the east hedge."), which doubles as the hook that walks legacy players to the new arch. A returning player's first session therefore looks like: familiar garden, bramble where the shortcut was, Eli waving from the east hedge — nothing else moved. New east edge, walkable in one 8-second line from the plots: **Lantern Post** (streak/brightness state, always visible from any plot), then **Wayfarer's Table**, then **Satchel Hook** on the shed wall (opens Verse Satchel inventory), then the **Eastgate** arch — entry/exit to the Garden Path. The Eastgate is the sole world exit; the Community Garden gate on the north fence is unchanged.

The **Wayfarer's Table** stands from day one, but it arrives damaged: the glass over the map is spider-cracked, the map beneath reads as a blurred parchment silhouette (frosted-glass shader, no labels), and the six carved seal sockets sit empty but visible — the player can count them and infer the journey's length before they can read the map. Pre-repair, the world map is not viewable at home; earned seals still slot into the sockets on return (seal 1 can land before the repair). Pip perches on the Lantern Post until the glass is fixed.

**4. Characters.** **Eli** — the gardener; steady, understating everything ("East road's clear. Mostly."); tutorialist and prologue dispatcher. **Ember** — dragon companion; comic relief; naps aggressively, follows to the Eastgate but never crosses it — he stays home minding the garden (and the fruit tally) until the Dragon Whistle calls him to the road in Murkmire (Ch. 9); when summoned he sprints from home in one comedic cross-map dash. **Pip** — a postal finch who delivers letters from saved towns; perches on the Lantern Post until the Wayfarer's Table is repaired, then relocates to the table's brass corner permanently; delivery system and soft re-engagement hook. **The Scarecrow** — never moves, but players swear its head turns; pure ambient joke, no function.

**5. Quests.** Main beat (prologue hook, pre–Meadow Town): (1) Eli notices the sell-crate fruit has dulled — a 10% desaturation shader on that day's harvest; (2) he walks the player past the bramble-choked south path to the east hedge and shears the Eastgate open; (3) he hands over one starter verse card (John 8:12, quoted on its card — the player's first Truth Serum) and nods at the empty Lantern Post: "Lanterns aren't handed over a fence. They're earned on the road. You'll see."; (4) player walks the Garden Path to Meadow Town, where the Lantern is earned from Zohar (Ch. 7) and the prologue proper begins. Side quests: **"Table Setting"** (available after first Meadow Town visit) — bring Eli three planks and six nails from Toolworks to re-glaze the Wayfarer's Table; on completion the cracked glass lifts off in a 1.5 s repair cutscene, the map resolves to full labels, the home map view activates, and Pip relocates to the table — this quest teaches the town-shopping loop. **"Pip's First Route"** — read one red-bag question to "give Pip something worth carrying." Running joke: Ember steals exactly one fruit from every harvest — **the stolen fruit is a cosmetic clone; the player's sellable inventory is never reduced** — and Eli logs each theft on a shed-wall tally. At tally 50, Ember sheepishly nudges open a hoard behind the shed worth 55 gold (tunable; ~110% of the depicted haul), and the tally restarts.

**6. Unique mechanic.** **Hearthlight.** The Home Garden is permanently at full ambient brightness regardless of lantern tier. The Lantern Post displays streak state honestly — dim post, bright garden — so the player reads their standing without ever standing in the dark at home. All frontier gating is felt only at frontier gates.

**7. Secrets.** (a) Greeting the Scarecrow 7 days running grows a sunflower that drops 5 gold daily (tunable). (b) A journal page sits under the repaired Wayfarer's Table glass, written in glow-ink: at lower brightness tiers it renders as a faint animated shimmer across blank parchment (the breadcrumb that brightness matters here); when a Radiant player holds their lantern flame over the glass, the ink blooms legible over 0.6 s (tunable) and hints at the orchard tunnel. This is the one Hearthlight exception — the reveal keys off the player's carried lantern tier, not scene lighting, so the permanently bright garden never contradicts it. (c) Ember's shed-roof nap spot hides a scratched arrow pointing at Meadow Town's chapel — payoff lands with endgame flight.

**8. Audio.** Existing garden theme retained; add a fourth stem (solo cello, +2 warmth) that fades in per lantern tier. Signature sounds: the Lantern Post ignition — flint strike into a low choral swell, 1.2 s; Pip's arrival — paper flutter plus a two-note whistle.

**9. Gating.** Nothing saves this area; it is never at risk. It unlocks the campaign: Eastgate opens in the prologue and never closes. Wayfarer's Table seal sockets are the persistent progress display; each slotted seal adds one string layer to the garden theme.

### Community Garden

**1. Fantasy & role.** The youth group's shared plot — porch-swing energy, everyone's harvest in one place. In the journey it is the harbor for group identity: League standings, mission renown, and shared celebration live here. Canon holds: it is a hangout, never a thoroughfare — it has no exit to the world, and the campaign never routes through it.

**2. Visual direction.** Existing group-garden palette, plus bunting and banner cloth in the group's League colors. Lighting mirrors Hearthlight — always bright. Signature moments: (a) the **Renown Arbor**, a trellis over the central path that grows one carved lantern per completed Mission Trip; (b) League-week banner drop, 0.8 s cloth unfurl (vertex-animated, 4-bone max); (c) a communal glow over the whole garden whose warmth tracks the group's aggregate reading — a single blended value, never per-member.

**3. Layout.** Unchanged: shared plots center, League board at the north fence, gate back to Home Garden south. New, along the west fence in walkable order: Renown Arbor (mission history), **Trip Wall** (framed low-poly "photos" auto-composed from completed missions), and the **Sending Bench** — where a group's next Mission Trip party is shown assembling. The bench displays parties; joining still happens only at mission boards in saved towns (or via the Trip Tracker, Ch. 4.6). Entry/exit: the south gate to Home Garden is the only gate.

**4. Characters.** **Eli** visits on League reset day with commentary. **Naomi** — a retired missionary NPC who tends the Arbor; warm, zero hurry; narrates each new mission lantern's story. **Ember**, banned from the shared plots after "the incident," sulks theatrically at the gate — running joke continues from home.

**5. Quests.** Main beat: none — deliberately. Side quests: **"Raise the Arbor"** — the group's first collective goal: a shared fruit pool with a target of **10 fruit × active members** (active = opened the game that League week), **capped at 200 fruit total** (tunable); any member may contribute any amount, over-contribution welcome, and the trellis's build state renders the pool percentage live. The quest **auto-completes when 60% of the target lands within a single League week**, so three enthusiastic kids in a 40-member group can finish it and no group stalls on absentees; the pool resets if the week ends short, with contributed fruit refunded. **"Naomi's Album"** — revisit three Trip Wall frames with Naomi for renown bonuses. Running joke: the Trip Wall auto-composes group photos and Ember photobombs every single one.

**6. Unique mechanic.** **Aggregate glow.** Every group signal here — garden warmth, Arbor light, League banner shine — is computed from group totals only. Individual streaks, brightness tiers, and skip days are never rendered in shared space. Encouragement is collective; accountability stays private between player, parent, and pastor dashboards.

**7. Secrets.** (a) Sitting on the Sending Bench alone for 60 s triggers Naomi's quiet story about her first trip; (b) a loose fence plank shows the neighboring group's garden glow far off — rivalry tease, no interaction; (c) the tenth Arbor lantern is gold and hums one bar of the Everlight theme.

**8. Audio.** Home theme rearranged for two guitars trading phrases — same melody, played together. Signature sounds: the Arbor lantern-carving chime when a mission completes; the crowd-murmur swell (8 voice loops) when three or more groupmates are present.

**9. Gating.** Never at risk, nothing to save. Unlocks: Renown Arbor construction opens after the group's first Mission Trip; Trip Wall after its second. Feeds group renown display for the Garden League seasonal reward, and nothing here ever gates an individual player's progress.

---

## 7. Meadow Town (Seal 1 — gateway)

> **Seam.** In: the Garden Path from Home Garden — always open, and the core district is accessible at any brightness (onboarding rule, Ch. 3.4). Out: the **East Gate** to Riverbend opens only when the town is saved (Seal 1 + restoration 100) — never by any other means. Later re-openings: orchard tunnel to Lantern Hollow (shears, post-seal-3), ferry departures to Brightharbor's loop (post-seal-6; downstream *arrivals* from day one of Brightharbor), Ember steeple landing (endgame), and the Pilgrim Stair to Everlight City rising above the town (six seals).

**1. Fantasy & role.** Meadow Town is the first place the player belongs to that isn't theirs. Home Garden teaches "tend what's yours"; Meadow Town teaches "tend what's shared." It is a small farming-market town of cream plaster, terracotta roofs, and string lanterns — friendly, slightly sleepy, and just Gloom-touched enough that the player's arrival matters. Every core loop premieres here in its gentlest form: the first whispered lie, the first verse counter, the first library study, the first service quest, the first Bible Quest and Lantern Seal. As the sole gateway to the world and the ferry's eventual terminus, it is the town players re-enter more than any other, so it must read instantly and feel better every time they return.

**2. Visual direction.** Pre-save: desaturated spring greens, dove grey, faded terracotta; a violet-grey Gloom stain hangs over the east fields and creeps **2 m/day (tunable) along the ~40 m field run** toward the square. At cap, the stain laps the fountain's bottom step and stops: square-wide NPC barks shift ("It's at the fountain now, did you see?"), the fountain water desaturates, but the stain never enters an interior or blocks a doorway — pressure without punishment, same contract as the Lantern. Flat-shaded low-poly, single directional light, vertex-color grading per district. Weather: soft overcast that never rains. Signature moments: (a) prologue dawn — Gloom fog pours over the east wall as a moving vertex-alpha plane; (b) the first Lightburst clearing a 12 m sphere of fog in one shader pop; (c) save-transformation — 40 string lanterns ignite in a wave from chapel to gate over 6 s (tunable); (d) the chapel steeple beacon, a slow-pulsing gold point light visible from every district; (e) ferry arrival at golden hour, water as two scrolling UV planes.

**3. Layout.** Walkable loop, ~90 s end to end. **West Gate** (entry, from the Home Garden path) → **Market Row**: Berry Market, Rosie's Seeds, Toolworks in one arcade → **Town Square**: fountain, notice board, raised speaking stage (trivia battle venue); the co-op mission board materializes here post-save → **Library** (north edge, ivy-covered, tallest interior) → **Chapel Hill** (northeast; steeple is Ember's endgame landing pad) → **East Fields**: Gloom-stained farms, prologue combat space, the needy NPCs' homes, five scarred plots → **East Gate** (exit to Riverbend, sealed until saved). South of Market Row: the weed-choked **old ferry dock** — no departures until seal 6, but it opens as a downstream **arrival** point the first time the player rides from Brightharbor; before that it's explorable on foot. Behind the chapel orchard, a bramble stone door marks the future Lantern Hollow tunnel (gardener's shears, post-seal-3).

**4. Characters.**

| NPC | Role | One line |
|---|---|---|
| Maribel Quill | Historian / librarian | Precise, kind, dust-allergic; runs library study, hands out the Verse Satchel. |
| Bram Oakes | Town champion | Big-hearted farm kid, your trivia rival; mangles every Bible name he quotes. |
| Rosie | Rosie's Seeds owner | Motherly optimist; prologue guide once Eli sends you through the gate. |
| Grint | Toolworks smith | Gruff, secretly soft; insists every problem has "a right hammer." |
| Old Tam | Needy NPC | Widowed farmer, roof caved in by Gloom-rot; won't ask for help, needs it. |
| The Finch twins | Needy NPCs | Hungry, fearless kids who narrate your deeds to the whole square. |
| Zohar, Emissary of Everlight | The lantern-giver | First met as a ragged stranger at the fountain; tests every traveler's compassion before the road can have them. |

**5. Quests.** **Prologue (12–15 min, tunable):** Eli walks you to the West Gate at dawn → **the Lantern origin — "The Stranger at the Fountain":** a poor, ragged stranger by the fountain quietly struggles with a spilled handcart and asks nothing; the quest marker offers help (regather the bundles, share fruit from your satchel, walk the cart to shelter — 90 s, tunable, no reward shown). The moment the last bundle lands, the stranger straightens, the rags resolve to travel-worn white and brass, and he is revealed as **Zohar, Emissary of Everlight**, who has tested travelers at this fountain since the roads were young. He grants the **Lantern** — "Light belongs to those who stoop" — with the Lightfound fanfare; the compassion test, not a purchase or a menu, is how the game's central object enters the story. → fog rolls over the east fields → first Gloomling whispers "You're too small to matter"; combat tutorial with the two starter Truth Serums (John 8:12 from Eli's card; Philippians 4:13 granted on the spot), guaranteed win → you find Bram frozen mid-field by "One mistake and you're done," but your satchel has no Grace-family serum → Maribel's first study session earns 3 serums → free Bram with the right one → clear 4 Gloomlings, fog recedes. The prologue also lights the new lantern to Flame (its reading beat is the first plan day, Ch. 3.4), and **its combat begins the global miss-log** — every failed counter from here on is recorded for Echo Shades and Hollowkeep (Ch. 13 data contract).

**Town Book — the Gospel of John (single spec: Ch. 3.10).** Maribel keeps the town's book at the library reading desk: John, fully voiced on the app's ElevenLabs narration pipeline, chapters in 3 sections with comprehension questions, memory-verse checks minting Truth Serums, sections paying XP and fruit. It mirrors the app's free Plan 1 on purpose — a kid who has only ever read the free plan walks into their first library already knowing the book on the desk. The reading desk is also the town's serum recharge point.

**Seal arc:** Complete Maribel's three study sessions (John themes, mirroring free Plan 1) — these three sessions **define the trivia question pool**, so study is preparation, never trivia-out-of-nowhere. Then Bram challenges you from the stage. Per canon, no service prerequisite: seal and restoration are parallel tracks, both required to save.

**Trivia battle ruleset (template for all six seals):** 5 rounds, 20-NPC crowd, no real-time timer at seal 1 (later towns add one). Round anatomy: Maribel reads a question drawn from the study pool; the player picks 1 of 4 answers (mix of verse-to-reference matching, "who said it," and fill-the-word). Correct: crowd cheers, a lantern above the stage lights, round to you. Wrong: crowd murmurs, Bram answers correctly and takes the round — no other penalty. **Round 4 is Bram's Recital:** he quotes a verse but mangles the name ("Neb-uh-kud… the furnace guy"); the player wins the round by tapping the mangled word and correcting it — the running joke made mechanical. Win 3 of 5 → **Lantern Seal I** and the **Lie-Lens** (milestone-reward table, Ch. 2.7), both landing on the Lightfound fanfare. Lose 3 of 5 → warm defeat (Bram: "Best two of three more?"), immediate rematch with a reshuffled pool; no lockout, no cost.

**Side quests:** *Raise the Roof* (fetch Grint's cedar shingles, rebuild Old Tam's roof, 3-beat hammer minigame; +30 restoration); *Loaves for the Finches* (donate 5 home-grown fruit via Berry Market; +25); *The Right Hammer* (Grint fixes the chapel bell with successively wrong hammers — running joke — until the fix is oiling the hinge; +20).

**6. Unique mechanic — shops as service organs.** The three existing shops become the restoration interface, a pattern every later town reuses. **Berry Market:** produce donations = **2 restoration pts/fruit, capped at 10 pts/day** (tunable) — generosity mechanically rewarded, capped so gold-farming can't trivialize it. **Toolworks:** issues rebuild kits for repair quests. **Rosie's Seeds:** sells the Meadow Replanting Pack; each of the **5 scarred plots replanted = 5 pts** (25 total), each permanently re-greened. The home-garden economy literally becomes the town's recovery.

**7. Secrets.** (a) A torn **Gloomling lie-ledger page** under the dock boards — first evidence the Gloom keeps records of what each person fears; if the player's first dock visit is by ferry, the page is instead caught on the mooring post, unmissable on disembark. (b) The bramble stone door behind the chapel orchard, shears icon carved above (Lantern Hollow shortcut hint). (c) A loose library brick hides a Starberry seed and Maribel's note: "Light was always meant to be shared."

**8. Audio.** Theme motif: **"The Open Door"** — a four-bar rising ukulele figure that answers itself on whistle; Meadow Town's calling card, and the melody the ferry horn quotes at Brightharbor's finale. Acoustic folk — ukulele, whistle, brushed hand drum; pre-save mix drops the whistle and detunes 15 cents (tunable), post-save adds a second voice and children's laughter ambience. Signature sounds: the **Lightburst** (whisper hiss reversed into a warm chime) and the **lantern-string chime**, a rising pentatonic glissando as the save-wave lights each strand.

**9. Gating.** Saved when Lantern Seal I is earned **and** restoration hits **100 pts**. Sources: three side quests = 75; donations = 10/day; replanting = 25. Intended minimum path (a pacing decision, not an accident): all three quests + one day of donations + three plots — roughly two play sessions. Save-transformation: saturated spring palette, Gloom stain burns off the field run over 10 s, all 40 lanterns lit, market stalls double, music gains its second voice, mission board (signature mission: VBS Host, Ch. 4.5) and East Gate open, and the five replanted scarred plots convert to the town's **open public garden plots** (Ch. 3.3) — the fields the player healed become the beds they grow in. The East Gate never opens by any other means.

**The farewell at the East Gate (scripted, first exit only).** The first time the player walks through the open East Gate toward the wider world, Eli comes jogging up the Garden Path, out of breath, and catches them at the arch: he'll take care of the backyard while they're gone — the plots, the post, "the dragon-shaped lawn ornament" — and they can come back anytime; nothing at home will ever need saving. One handshake, no menu, and the East Road begins. It is the game's quiet promise that leaving costs nothing: the door behind you stays open, and someone you trust is holding it.

**Standing (post-save):** Neighbor on save. **Friend at 150 Standing pts, Guardian at 400** (tunable — a town override of the Ch. 3.5 defaults) from: donation days (+10 each), Mission Trips launched from this board (+25), each secret found (+15), each plot replanted (+10), full replant bonus (+25). Guardian payoff: the Finch twins spot you at the West Gate and announce you by name to the square, and Rosie stocks one free Dawnberry seed per week.

---

## 8. Riverbend (Seal 2 — flood)

> **Seam.** In: the East Road's covered bridge on the west bank — reachable only because Meadow Town's East Gate opened on its save; crossed on a temporary rope walk while the flood holds. Out: the **Locks' south channel gate** toward Murkmire, chained until Seal 2 + full restoration; the Murkmire entrance beyond it is the game's **first brightness-gated threshold** (Flame). All of Riverbend itself is safe-zone — the lantern is not yet formally introduced, and no space here is brightness-gated.

**1. Fantasy & role.** Riverbend is the first town the player saves without training wheels — a working farm town split by the Silverrun River, where terraced fields, waterwheels, and a plank-and-rope footbridge culture make the river both livelihood and threat. The Gloom here does not lurk in shadows; it lives in the weather. A slow, unnatural flood has been rising for weeks, and the town's lie is worry: *what if the water takes everything?* Riverbend runs the campaign's core rhythm (study → field encounters → trivia battle → service → transformation) at full difficulty, introduces water as a traversal and puzzle material, and — because its board debuts the group's first co-op rebuild — is where a solo journey becomes a youth-group one.

**2. Visual direction.** Palette: wet slate blue-greys, mud brown, and rice-paddy green under a pale overcast sky; saved-state palette swaps to golden-hour amber with teal water. Persistent light rain (a single scrolling streak-texture plane, ~200 quads, tunable) until the seal arc resolves; puddle decals are flat discs with a 0.5 Hz emissive shimmer. Signature moments: (a) first sight of the half-drowned lower district, rooftops poking from grey water like stepping stones; (b) the great waterwheel of Toller's Mill, stopped mid-turn, restarting with a groan at restoration 50%; (c) sandbag lines glowing faintly where players have stacked them; (d) the flood receding in a single scripted 8-second tide-out when the town is saved, revealing streets of wet, reflective planes; (e) lantern rafts released downstream at the save ceremony (10–20 instanced meshes on a spline, tunable).

**3. Layout.** Entry gate: the East Road's covered bridge on the west bank, half-submerged, crossed on a temporary rope walk. Walkable order: **West Terraces** (dry farms; market square with satellite stalls of the Meadow Town shops, run by kin — a Berry Market stall and Rosie's cousin's seed cart) → **Millrow** (Toller's Mill, Toolworks annex, the chapel on the highest knoll — visibly above the waterline, deliberately) → the **Footbridge** (town spine; trivia arena is the bridge's wide midspan platform, crowd lining both railings) → **East Shallows** (flooded district, needy NPCs on rooftops, service quests) → **The Locks**, a stone sluice complex at the town's north end. Library: a stilt-house archive in Millrow run by the historian. Mission board: bolted to the mill's outer wall, dark until the town is saved. Exit gate: the Locks' south channel gate toward Murkmire, chained until seal 2 + full restoration.

**4. Characters.**
- **Historian Neda Wren** — precise, kind, keeps the flood ledger; runs the library study for seal 2.
- **Champion Tomas Ferrow** — the ferryman's son, town trivia champion; anxious perfectionist who quotes verses fast but half-believes the Gloom's worry-lies. Beating him helps free him.
- **Old Cobb** — comic-relief lockkeeper; narrates everything like a sea captain despite the river being 15 meters wide.
- **Marla Toller** — miller; needy NPC line 1 (grain stores soaked; feed quest chain).
- **The Prews** — rooftop family in East Shallows; needy NPC line 2 (clothe/heal/rescue-by-raft).
- **Sim** — a kid who has heard about the player's dragon back home and insists he could power the mill "if you'd just go fetch him." (On post-Murkmire return visits, with Ember actually in tow, Ember refuses with escalating theatrical dignity.)

**5. Quests.**

*Field encounters (Worry-wisps).* Riverbend's Gloomlings are Worry-wisps: pale, dripping wisp-forms (single billboarded sprite-sheet, 8 frames; the zone's Murmur Pack skin, Ch. 2.5) that cling to structures and whisper flood-lies as standard Truth & Light encounters from the Verse Satchel. Three specified encounters: (1) **Rope-walk handshake** at the entry bridge — one wisp whispering "You'll never make it across" — countered with a Meadow Town prologue verse (John 8:12), calibrating difficulty up from the prologue before any new verses are earned; (2) **Rooftop wisps** during the Prews rescue — three wisps, one per rooftop, whispering "The water always wins" (counter: Isaiah 43:2), "No one is coming for you" (counter: Philippians 4:6–7), "Tomorrow will be worse" (counter: Matthew 6:34) — each must be dispelled before that family member boards the raft; (3) **The Locks cluster** — two wisps coiled around the sluice cranks blocking the grain-drying puzzle, drawing from the same three lies at random. Right verse = Lightburst, wisp flees upward and dissolves; wrong verse = screen edges darken 15% and rain intensifies for 4 s (tunable), retry immediately.

*Seal arc.* (1) Neda's library study — three sessions pairing worry-lies with counter-verses (Isaiah 43:2; Matthew 6:34; Philippians 4:6–7), each session gated by one real Bible-plan reading day; (2) the **Footbridge trivia battle** vs Tomas: 3 rounds × 3 lie-prompts, 12 s timer each (tunable), four answer cards per prompt of which one per round is a Gloomling-whispered counterfeit — a near-verse in a subtly gloom-tinted card (desaturated border, faint drip particle). Correct answer: Lightburst, crowd cheers, one bridge lantern relights. Wrong answer or timeout: fear closes in — two bridge lanterns dim, crowd murmur swells, and the current round is lost at 2 wrongs. Best-of-3 rounds wins the match. Losing costs nothing: Tomas offers an instant free rematch ("Again. I need you to beat me.") — the seal is never locked behind a cooldown. (3) Win → **Seal of Riverbend (Seal 2)** granted at the chapel, and with it the **Quickstrap** (spec in the milestone-reward table, Ch. 2.7 — satchel opens 40% faster, full move speed while open), both on the Lightfound fanfare. In Riverbend the Quickstrap also reads as sure footing: stumble animations disappear on rope walks, rafts, and wet planks — pure presentation, no second stat.

*Town Book — Philippians (single spec: Ch. 3.10).* Neda's stilt-house archive keeps the town's book at its reading desk: Philippians, voiced on the ElevenLabs pipeline — the worry town reads "do not be anxious about anything" in its own library. Chapters in 3 sections, comprehension questions, memory-verse checks minting Truth Serums; the desk doubles as the serum recharge point.

*Restoration (service).* Sandbag the West Terraces (stack 12); raft-ferry the Prews to the chapel knoll; dry Marla's grain via a Locks water-routing puzzle; repair the footbridge's broken planks (5 fetch-and-place).

*Side quests.* **"Cobb's Log"** — recover the lockkeeper's waterlogged journal pages from three rooftops. **"Seeds Above Water"** — Rosie's cousin pays a flood premium for Glowberries grown back home: 12 gold each vs Berry Market's 8 (tunable, always ≥130% of Meadow Town price so the first cross-map farming loop pays). **"The Deep Channel" (level-gated pocket, Ch. 3.1)** — Old Cobb keeps a salvage raft chained at the Locks' deepest pool; he won't hand over the pole until **level 8** ("Current's no joke down there. Come back at level 8 — the river'll keep."). Inside: a 3-dive salvage run for gold, a Gloryberry seed, and one page of the flood ledger. Running joke: every NPC has a different, mutually contradictory story about what Old Cobb did "in the Great Flood of aught-nine"; Cobb confirms all of them.

*Reward table (all tunable).*

| Quest | XP | Gold | Other |
|---|---|---|---|
| Rope-walk / Locks / rooftop encounters | 50 each | — | — |
| Library study (×3 sessions) | 150 each | — | 1 Truth Serum each |
| Town Book sections (Philippians, Ch. 3.10) | 40 each (+2 fruit) | — | memory-verse checks mint Truth Serums |
| Trivia battle win | 500 | 25 | Seal 2, the Quickstrap |
| Sandbags (per bag ×12) | 10 | 2 | — |
| Prews rescue | 200 | 15 | — |
| Grain / Locks puzzle | 200 | 15 | — |
| Footbridge planks | 100 | 10 | — |
| Cobb's Log | 120 | 20 | — |
| Flood Rebuild mission (first clear) | 300 | 30 | Renown 120/90/60 by tier (Ch. 4.5; a Gold clear ≈ 40% of a solid Garden League week; repeat clears 50) |

**6. Unique mechanic — Flow Routing.** The Locks introduce 3-gate water-routing puzzles: open/close sluices to raise or drain pools, floating raft platforms to new heights (rafts are kinematic platforms on eased vertical tweens — no fluid sim; water level is a translating plane per pool). Riverbend ships **4 puzzles total: 3 solo** (grain-drying restoration, Drowned Grove secret configuration, one optional East Shallows chest pool) **+ 1 co-op** inside Flood Rebuild. Failure-proofing: every Locks puzzle has a one-tap **reset-pool lever** restoring the authored start state; rafts auto-return to their dock when their pool drains; no configuration can strand the player (chapel knoll path is always dry). Co-op variant requires two players on separate gate cranks; a crank **holds its last state for 10 s** (tunable) after release, so one distracted teammate cannot soft-lock the group. The saved-town mission board then opens with **Flood Rebuild** (full spec Ch. 4.5): cooperative sandbag chains (pass-to-teammate emote prompt), raft rescues, and the shared two-crank Flow Routing puzzle. First completion tutorializes group renown.

**7. Secrets.** (a) **The Drowned Grove** — drain the east pool fully in an optional Locks configuration to expose steps down to a glowing underwater orchard with a free Starberry seed; (b) journal page from Eli's old walking tour wedged in the mill's brake lever housing, hinting he once lived in Lantern Hollow; (c) a scratched arrow under the covered bridge pointing downstream with "the ferry remembers the way home" — foreshadowing the Brightharbor ferry loop.

**8. Audio.** Theme motif: **"Two Banks"** — a hammered-dulcimer phrase that crosses the beat like the footbridge crosses the river, answered by low strings from "the far bank." Music: mid-tempo folk with hammered dulcimer and low strings over a constant rain-hush bed; saved state swaps to bright fiddle over the same chord progression so the transformation is audible. Signature sounds: the waterwheel's wooden *thunk-creak* cycle (town heartbeat, silent until 50% restoration), and the deep stone *shhh-boom* of a sluice gate seating home.

**9. Gating.** Restoration meter weights (tunable): sandbags 20% — ticking **per bag** (1.67%/bag, visible motion every stack); Prews rescue 30% — per family member ferried (10% each); grain/Locks puzzle 30% — on puzzle completion, single tick; footbridge planks 20% — per plank (4% each). The mill-restart moment in §2 fires the first time the meter crosses 50%, reachable by any quest order. Save condition: Seal of Riverbend + meter 100%. Saving triggers the tide-out, palette/music swap, mill restart, lantern-raft ceremony, market stalls reopening at full stock (the Berry Market stall and the seed cart are the town store — fruit bought, seeds sold, all game), the West Terrace **public garden plots** drying out and opening (Ch. 3.3), mission board lighting up (Flood Rebuild available immediately), Standing track opening toward Guardian (Guardian privilege: free flood-season crop storage at the granary), and the Locks' south gate unchaining onto the Levee Trace toward Murkmire — where the tone drops and the swamp trial begins.

---

## 9. Murkmire (trial — burden)

> **Seam.** In: the Riverbend levee stile, open once Riverbend is saved; entry requires a lit lantern — **Flame or higher** (read today). Skip-day players can reach Marta's stile, but the Shallows fog holds until they've read. Out: the **Willow Arch** opens only to a player at ≤2 Burden Weight (quest items exempt; a final prayer stump stands in sight of it) after outlasting the Mire-Mother's three whisper waves — onto the Fen Boardwalk to Lantern Hollow. Murkmire is survived, not saved: no seal, no restoration, no transformation; the Gloom here always remains.

**1. Fantasy & role.** Murkmire is the first place the world stops being kind. After Riverbend's rescued warmth, the road drops into a drowned cypress flat where the Gloom has soaked into the ground itself. There is no town here, no seal, no restoration meter — Murkmire is the game's first trial, and it teaches the lesson every later dark zone builds on: the mire does not grab you, it *weighs* you. Everything you insist on carrying — loot, hoarded fruit, the grudge-shaped Burden Stones — makes the mud pull harder. The design intent is a playable sermon on Hebrews 12:1 ("let us throw off everything that hinders") and Matthew 11:28–30: you cross Murkmire light, or you don't cross it.

**2. Visual direction.** Palette: bruise-green water (#3A4A3F), wet charcoal bark, desaturated moss, with the only warm notes being the player's lantern and rare amber "willow lights." Fog plane at 18 m (tunable) with vertex-animated low-poly reeds. Weather: permanent overcast, intermittent slow rain (particle sheet, ~200 particles max). Signature moments: (a) the Sinking Causeway — a plank road that visibly bows under the player, sink depth driven by carry weight; (b) Burden Stones on the player's back rendered as stacked grey cubes that grow with load; (c) the Cart Rescue — an ox cart tilting into black water, lantern swinging on its post; (d) the Far Bank Reveal — fog parts to show Lantern Hollow's dusk lamps in the distance; (e) drowned mailboxes and a half-sunk chapel steeple hinting this was once farmland the Gloom took.

**3. Layout (trial stages, linear with pockets).** Entry gate: the Riverbend levee stile, where Eli's cousin **Marta** runs the Last Dry Table (free storage chest — the game *begs* you to leave things). Stage 1 — **The Shallows**: tutorializes weight; three optional loot piles that are traps for hoarders. Stage 2 — **The Sinking Causeway**: plank path with two breakaway spans; first Gloomling ambush ("You carry too much to make it," countered by Isaiah 41:10). Stage 3 — **Peddler's Bog**: the Cart Rescue set piece (see quests). Off the causeway between stages 3 and 4, on a dry hummock, stands the **Mirelight Outpost** — a stilt reading room the Lantern Hollow lamplighters built generations back: one desk, one shelf, one stubborn lamp. It is the mire's only library-class site (Truth Serum recharges, Ch. 2.3, plus the Psalm 55:22 study — see secrets), and its door is blocked by the **Bogbellow**, a wagon-sized mire toad sprawled across the porch (wildlife, not a Gloomling — it whispers nothing, it simply will not move). Approaching alone triggers the player's thought bubble: *"I'm not going anywhere near that thing alone…"* — the line that makes the Dragon Whistle's purpose land before the whistle exists. Stage 4 — **The Deep Mire**: darkest zone, kept atmospheric rather than mechanical — fog tightens, the vignette closes, whispers get louder, and the amber willow lights are the only wayfinding; there is no lantern-radius gameplay here. The dark makes you wish you understood your lantern — that lesson belongs to Lantern Hollow, one zone ahead. Exit gate: the Willow Arch, a natural root gate that only opens its gap wide enough for a player at ≤2 Burden Weight (tunable), with a final prayer stump standing in plain sight of it — you physically cannot squeeze through heavy, and you are never stranded heavy.

**4. Characters.**
- **Marta** — Eli's blunt cousin; runs the storage chest and the trial's framing ("The mire keeps what you won't put down"). Keeper of the **Dragon Whistle** — Eli carved it years ago and sent it ahead with her ("He said you'd know when to blow it"); she hands it over through conversation, not a quest chain (see quests, beat 2½).
- **Peddler Fenwick** — anxious traveling merchant whose cart is sinking; comic in relief, tragic in cause: he's sinking *because* he won't dump stock.
- **Old Croon** — a heron-watching hermit on a dry hummock; sells nothing; he asks travelers to recite Scripture from memory and pays them back in stories. Secret-keeper.
- **Clover** — Fenwick's ox, deadpan animal comic relief; Ember is terrified of him (running joke fuel).
- **The Bogbellow** — a wagon-sized mire toad camped across the Mirelight Outpost porch; harmless, immovable, and exactly the size of the player's nerve. Scared off by one thing in the world (see quests).
- **The Mire-Mother** — the zone's alpha Gloomling, a lie-whispering willow silhouette wrapped around the Willow Arch itself. She is not fought; she is outlasted through three escalating whisper waves (specced in quests, beat 5).

**5. Quests.** Main beat (trial arc): (1) Marta's briefing + free storage; (2) cross the Shallows, learn the weight meter; (2½) **The Dragon Whistle — Ember joins the road.** Back at the stile, or on her supply walk to the Causeway, conversation with Marta turns to the sealed reading room and the thing sleeping on its porch; she produces a small carved whistle: Eli made it, she's carried it three seasons, and "he said you'd know when to blow it." The **Dragon Whistle** lands in inventory (Lightfound fanfare). Blowing it anywhere summons **Ember** — a distant happy shriek, then a cross-map sprint from home, mud flying, arriving as the new **traveling buddy**; blowing it again sends him trotting home (he keeps the garden fruit tally either way). Walking past the Bogbellow *with Ember at heel* is the whole solution: Ember puffs one proud smoke ring, the toad's eyes go wide, and it oozes off the porch into the water — the **Mirelight Outpost** opens (recharges, study desk, storage). This is the game's first Ember obstacle; the second is the shade-ivy passage in Lantern Hollow (Ch. 10). (3) Causeway ambush teaches verse-counter under sway; (4) **The Cart Rescue** — Fenwick's cart sinks on a 4-minute timer (tunable): convince Fenwick to jettison cargo (dialogue checks quoting Matthew 6:19–20), carry crates to dry ground (each trip slower as weight stacks), free Clover's harness. Full rescue with Fenwick's heart changed = gold; cart lost but Fenwick and Clover saved = silver; the cart *can* be lost and the story continues — the mire teaches, it never fails you out. (5) **The Willow Arch** — the Mire-Mother's outlasting. Three whisper waves, ~20 s apart (tunable), each a written lie the player counters from the Verse Satchel. Wave 1 is generic ("No one crosses"); wave 2 is situational ("You left the cart to drown," reflecting the Rescue outcome); wave 3 is personal — she quotes back the exact items the player refused to drop, by name, pulled from inventory history ("You chose the 4 Starberries. Carry them forever."). The Arch gap is a morphing root mesh: each correct verse widens it one step with a Lightburst; each wrong answer narrows it one step, tightens the fear vignette, and replays the whisper — at the Arch, wrong answers never add Burden Stones, so the trial can always be finished from where you stand. Fail loop: three consecutive wrong answers reset to wave 1 after a 5 s beat of silence; no other cost. The final counter is 2 Corinthians 5:17, and the Arch opens fully on it. Side quests: **Letters from the Drowned Farms** — recover 5 waterproof mail tubes from sunken mailboxes, deliverable later in Lantern Hollow for Standing there; tubes and all quest items are weightless and never count toward Burden. **Croon's Three Stories** — recite three memorized verses to Old Croon; he pays each in a story of the mire-before-the-Gloom, and the third story ends with him sketching a torn map corner labeled "roots that remember the orchard" — the physical foreshadow of the Meadow Town–Lantern Hollow orchard tunnel. Running joke: Ember vs. Clover — Ember postures at the ox, Clover blinks once, Ember hides behind the player; escalates each visit.

**6. Unique mechanic — Burden Weight.** A 0–10 meter (tunable). Sources: inventory slots over 6, Burden Stones (gained from wrong verse counters outside the Arch, capped at 3), and hoarded cargo; quest items are always weightless. Effects: move speed −6% per point, sink depth on soft ground scales with weight, and at 8+ the screen edges darken and Gloomling whispers get louder. Shedding: prayer stumps (kneel interact, 3 s) clear Stones — including the final stump in sight of the Willow Arch — and helping any needy NPC sheds one Stone on the spot with a visible stone-splash-and-silence moment; refusing to help costs nothing but that shed. Generosity is the reward path, never the penalty dodge. Loot must be dropped or stored. Implementation: one float on the player state driving a speed multiplier, a shader vignette, and the causeway plank sink offset — no physics beyond raycast ground height.

**7. Secrets.** (a) **The Dry Chapel** — the half-sunk steeple hides an air-pocket room reachable only at Burden 0, containing a waterlogged Satchel page: every word is ruined except the reference, *Psalm 55:22*. Finding it unlocks a "Psalm 55:22" study assignment at the Mirelight Outpost's desk (or, if the outpost is still Bogbellow-blocked, at the Lantern Hollow library); completing that study mints the verse as a Truth Serum. Discovery is the magic, the library is the source. (b) **Fenwick's manifest** — a journal page under the cart seat revealing he's carrying Glimmerton trade goods, foreshadowing the carnival's counterfeit economy. (c) **Clover's bell** — half-buried in Peddler's Bog; return it and Clover follows you to the Arch, and Ember, mortified, rides on your shoulder the whole way.

**8. Audio.** Music: sparse waterlogged piano over a low drone, one motif that resolves only at the Far Bank Reveal; percussion is diegetic (rain, plank creaks). Signature sounds: the *gulp* of mud releasing a boot (pitch drops as weight rises), and the Burden Stone shed — a stone splash followed by two seconds of pure silence before the mix returns.

**9. Gating.** Murkmire is survived, not saved: no seal, no restoration; it never transforms, and the Gloom here always remains. Passing requires reaching the Willow Arch at ≤2 Burden (quest items exempt; final stump adjacent) with Fenwick's outcome resolved at any tier, then outlasting the Mire-Mother's three waves. Surviving the trial grants the **Deepwell Vials** (milestone-reward table, Ch. 2.7 — every Truth Serum carries 6 charges instead of 5; the mire teaches you to carry less, then rewards you by letting each thing you *do* carry hold more). Unlocks: the Fen Boardwalk to Lantern Hollow, the Letters delivery hook, the Psalm 55:22 study assignment if the Dry Chapel was found, the Dragon Whistle and Ember-as-traveling-buddy (from beat 2½, carried for the rest of the game), and the permanent **Traveler's Rule** — Burden Weight stays active in all later dark zones, making Murkmire the tutorial for every trial after it.

---

## 10. Lantern Hollow (Seal 3 — the lantern's town)

> **Seam.** In: the **Fen Door**, a low timber gate where the Murkmire boardwalk ends — open to anyone who survived the Willow Arch. Out: the **East Palings** below the chapel open toward Glimmerton when the town is saved (Seal 3 + restoration 20). Post-save, Brama's **gardener's shears** open the orchard tunnel — the permanent Lantern Hollow ↔ Meadow Town shortcut.

**1. Fantasy & role.** Lantern Hollow is the town that stopped lighting its lamps. It sits in a wooded bowl where the sun never fully rises or sets — permanent violet dusk — and every street is lined with cold iron lampposts nobody tends anymore. The Gloom didn't conquer this town; it convinced it. "Dark is safer. Light attracts attention." Arriving straight out of the Murkmire trial, the player walks in exhausted, lantern glowing, and discovers they are the brightest thing in town. This is where the game promotes the lantern from a status readout to the central verb: your real-world daily reading is no longer just *your* streak — it is light other people need. Lantern Hollow teaches Matthew 5:14–16 mechanically before it ever quotes it. It is the lantern-mechanics town: the brightness tiers the player has been living under (Ch. 3.4) are surfaced, named, and made social here.

**2. Visual direction.**
- Palette: deep indigo and slate base, desaturated plum shadows, warm amber/gold only where light exists. Saved-state adds honey, cream, and copper.
- Lighting: single dim hemisphere light plus fog (`FogExp2`, tunable density 0.018) tinted violet. Max 4 dynamic point lights near the player; all other lit lamps are emissive sprite billboards with fake bloom quads — cheap on phones, reads as hundreds of flames.
- Weather: still air, drifting ash-like petals (200-particle sprite system, tunable).
- Signature moments: (1) first sight of Lamplighter's Row — 40 dead lampposts in perfect perspective; (2) the player's lantern radius rendered as a soft ground decal that visibly grows with streak tier; (3) moths spiraling into the player's light in town squares; (4) the Great Hollow Lantern — a house-sized dark lantern on the amphitheater hill; (5) the save-cascade: lamps igniting one by one down the Row in a 12-second wave.

**3. Layout.** Walkable loop, west to east. **Entry gate:** the Fen Door, a low timber gate at the west end where the Murkmire boardwalk ends. → Lamplighter's Row (main street, dead lamps, shuttered homes — needy NPCs live here) → the Wickworks (market; shuttered until restoration passes 50%) → Library of Lamps (historian; every study desk has its own tiny lamp) → the Amphitheater Hill (quest arena, crowd seating around the unlit Great Hollow Lantern) → chapel on the east knoll with a beacon housing. Mission board stands in the amphitheater square, dark until the town is saved. **Exit gate:** the East Palings, a tall fence-gate below the chapel; through its slats the player sees Glimmerton's carnival glow — deliberate glimmer-vs-glow foreshadowing. North of town, an orchard ridge holds a bricked tunnel door wrapped in overgrown branches (see gating).

Wickworks stock (gold prices tunable):

| Item | Cost | Effect |
|---|---|---|
| Copper Handlamp | 40g | Cosmetic lantern skin |
| Slow-Wick | 60g | Lantern ground decal +1m for one session |
| Sorrel's Oil | 15g | Quest consumable (oil deliveries) |
| Moth Charm | 25g | Giftable to Milo Fennel; +5 Standing |
| Tobbin's Striker | 80g | Lamp ignition VFX upgrade (spark burst) |
| Wick Trimmer | 30g | Lights lamps from 3m instead of touch range |
| Seed rack (Glowberry → Starberry tiers) | Berry-standard | The Hollow's seed stock — the Wickworks is also the town store |
| Fruit counter | sells at Berry Market rates | Buys any fruit; post-save, pays +5% for fruit grown in the Hollow's own public plots |

**4. Characters.**
- **Maren Wick** — historian-librarian; keeps the Ledger of Lamps, a record of every lamp ever lit in town. Runs the seal study.
- **Old Tobbin** — retired head lamplighter and town champion; gruff, genuinely believes the dark keeps the Gloom's attention away. His trivia battle is an argument he wants to lose.
- **Milo Fennel** — moth-obsessed kid, comic relief; names every moth and blames the player for "moth traffic."
- **Widow Sorrel** — lives in the coldest house on the Row; needy NPC anchor for restoration.
- **Brama** — Eli's sister, orchardist on the north ridge; practical, secateurs on her belt, refuses to prune "until there's light worth growing toward."

**5. Quests.**

Seal arc — the third seal, the Keeper's Seal:
1. Maren assigns study of light passages (John 8:12; Matthew 5:14–16; Psalm 119:105) — three library sessions, each gated behind a real plan-day read.
2. Field task: relight 5 lamps on the Row using the Lamplighting mechanic; Gloomlings whisper "Light attracts attention" and "Hide it, keep it safe" — countered from the Verse Satchel.
3. **Trivia battle vs Old Tobbin**, amphitheater, crowd assembled. Ruleset: 5 rounds; each round Tobbin voices one lie of the dark and the player picks from 3 verse choices drawn from the three studied passages plus their Verse Satchel. Correct: one crowd lantern ignites (5 total) and Tobbin's coat brightens one step. Wrong: the amphitheater dims one step and a fear-vignette closes in; 3 misses ends the battle — retry opens next day at the dusk bell (no other penalty). Round 5 is personal, not scriptural: "Why risk being seen?" — any of the three studied verses is accepted, each with unique Tobbin dialogue (John 8:12 gets "…then I've been following the wrong dark"; Matthew 5 gets the coat re-donned mid-line; Psalm 119 gets him staring at his own unlit route map). Win = the **Keeper's Seal (Seal 3)** and the **Keeper's Hood** (milestone-reward table, Ch. 2.7 — Tobbin's own storm-hood, fitted to the player's lantern), granted on the Lightfound fanfare; all 5 crowd lanterns flare, the Great Hollow Lantern remains dark until the save.

**Town Book — 1 John (single spec: Ch. 3.10).** Maren's Library of Lamps keeps the town's book at a desk with the brightest lamp in the room: 1 John, voiced on the ElevenLabs pipeline — "God is light; in him there is no darkness at all" read aloud in the town that stopped believing it. Chapters in 3 sections, comprehension questions, memory-verse checks minting Truth Serums; the desk doubles as the serum recharge point.

Side quests: **Sorrel's Hearth** (deliver oil, firewood, and a lamp); **Tobbin's Old Route** (his hand-drawn map, relight 8 forgotten lamps in walk order); **Moth Census** (Milo: stand still near 6 lit lamps for 10 s each and count arrivals). Running joke: every lamp lit near Milo spawns more moths and new names ("That's Gerald. Gerald has a family now. This is on you.").

**Standing (Stranger → Neighbor → Friend → Guardian).** Sources: each lamp lit +2, each Sorrel delivery +5, Moth Census +10, seal battle win +15, post-save daily greetings from Row residents +1 each (max 5/day). Thresholds (tunable, a town override of the Ch. 3.5 defaults): Neighbor 25, Friend 60, Guardian 120. Guardian payoff: the player may ignite any remaining unlit lamp town-wide from the lamp map instantly, and Maren enters their name in the Ledger of Lamps — a readable library page listing every Guardian in the youth group.

**6. Unique mechanic — Lamplighting.** Lampposts are interactable. Lighting one costs nothing but requires **Flame or higher**; a lit lamp becomes a permanent warm zone (spawn-safe, Standing-gain aura), and each lit lamp within 10 m extends the player's lantern ground decal by +0.5 m, stacking to a cap of 3 (+1.5 m max) — light shared is light multiplied. If the streak lapses, lit lamps stay lit — light given away is never taken back; skip days only pause *new* lighting.

This is where the global brightness tiers (single spec: Ch. 3.4) are surfaced diegetically. Hollow-specific tier perks (all tunable):

| Tier | Perk in the Hollow |
|---|---|
| Flame | Can light lamps |
| Beacon | Each lighting ignites a 2-lamp chain |
| Radiant | Moth trail follows the player |

**7. Secrets.**
- **The Firefly Grove** — behind a curtain-fall spring east of the chapel, its narrow passage choked floor-to-lintel with **shade-ivy**, a dark-loving creeper no shears will cut. This is the game's **second Ember obstacle** (the first is Murkmire's Bogbellow, Ch. 9): blow the Dragon Whistle and Ember burns the ivy clear in one delighted, slightly-too-long breath — his first official job as a traveling buddy, and the moment the whistle graduates from "toad repellent" to "key." Inside, fireflies orbit a wild Glowberry bush; one-time Starberry cross seed.
- **The Last Lamplighter's Page** — journal page inside dead lamp #13 (only findable before it is relit): Tobbin's resignation letter, unsent.
- **Apple blossom draft** — near the bricked orchard door, a faint petal stream ("You smell Meadow Town apples?") hints at the tunnel long before the shears exist.

**8. Audio.** Theme motif: **"One Wick"** — a single celesta line that begins alone and is joined, note by note, as lamps light; the town's thesis in melody. Music: dusk lullaby — celesta, nylon guitar, low strings, sparse; each lamp lit adds a sustained note to a background pad (cap 8 layers, tunable). Saved-state adds handbells and soft choir. Signature sounds: (1) lamp ignition "thoomp" with a decaying chime pitched by lamp count; (2) dry moth-wing flutter that thickens near light.

**9. Gating.** Passing requires the Keeper's Seal **and** a full restoration meter: 20 points (tunable), ledger: Sorrel's Hearth 6 pts; Tobbin's Old Route 6 pts fixed on completion (its 8 lamps do **not** also earn per-lamp points); oil deliveries 1 pt each (max 4); each other Row lamp lit 1 pt — the 5 seal-arc lamps count. Overflow beyond 20 converts to Standing progress toward Friend at 1 pt = +3 Standing. Save transformation: 12-second lamp cascade down the Row, the Great Hollow Lantern ignites, fog density halves, palette warms to honey/copper, Wickworks and mission board open (signature mission: Midnight Rescue, Ch. 4.5), lamplit planter boxes along the Row open as the town's **public garden plots** (Ch. 3.3 — crops here grow under lamplight, a cosmetic glow on the sprites), chapel beacon lights (endgame Ember landing point). Brama then prunes the orchard door and hands over the **gardener's shears**, opening the orchard tunnel — the permanent Lantern Hollow ↔ Meadow Town shortcut. The East Palings open toward Glimmerton, whose fake light now reads sickly against the town's earned warm glow.

---

## 11. Glimmerton (Seal 4 — glimmer vs glow)

> **Seam.** In: the **Ticket Arch** from Lantern Hollow's East Palings (requires Lantern Hollow saved). Out: the **Gorge Gate** at the far north end, chained until Seal 4 + restoration; the road beyond obeys standard brightness gating — Whisper Gorge is named Gloom territory and requires **Flame or higher** at its own entry. Inbound folds arrive later: the Starcrest ledge drop lands behind the carnival gate (post-Starcrest-save), and the Dawnkey wicket-gate from Hollowkeep surfaces in the Dark Chapel's crypt wall.

**1. Fantasy & role.** Glimmerton is the carnival city that never went dark — and that is the problem. While every other town dimmed under the Gloom, Glimmerton got brighter: neon marquees, spinning prize wheels, a ferris wheel crowned in strobing bulbs. None of it is real light. The Gloom learned here that it doesn't need shadow to make people forget; it just needs a shinier distraction. Coming off Lantern Hollow, where the player learned what a true lantern is worth, Glimmerton is the test: can you tell glow from glimmer when the glimmer is louder, faster, and handing out tickets? This is the journey's temptation chapter, and the only town where the danger smiles at you.

**2. Visual direction.** Palette: hot magenta, electric cyan, and sodium orange against near-black purples — deliberately clashing with the game's warm amber glow language. True light (lantern, chapel, saved NPCs) always renders warm gold; everything Glimmerton-native renders cold saturated neon. Weather: permanent overcast dusk with a haze plane (single scrolling alpha texture) so the neon blooms. **Lantern rule (city-wide):** inside the player's lantern radius, neon desaturates toward gray while warm-gold assets brighten — one shader uniform (`uLanternRadius`) on the shared neon material, radius scaling with brightness tier: Spark 3 m / Flame 5 m / Beacon 8 m / Radiant 10 m (tunable). Glimmerton is the only town where the lantern visibly edits the world, and it teaches the glimmer lesson without a word. Signature moments, all cheap in three.js r128: (a) the Ferris Wheel of Fortune — 16 emissive-box cars on one rotating parent, visible from the entry gate; (b) marquee chase-lights as UV-scrolling emissive strips; (c) the Hall of Mirrors alley, 3 mirrored player clones mimicking you a half-second late; (d) post-restoration, every neon tube flickers once and re-lights warm gold — one material-swap pass, the cheapest save transformation in the game and the most dramatic; (e) the Midway at night from the Starcrest ledge-drop arrival point above.

**3. Layout.** Players enter from the Lantern Hollow side through the Ticket Arch, a garish gate where admission is "free" (running joke: nothing else is). Walkable order: Ticket Arch → the Midway (main drag, all five Glimmer Games booths, mission board disguised as a "JOBS!" kiosk at center) → Prize Plaza (ticket fountain; a Berry Market franchise stall and Toolworks cart squeezed between prize counters — the stall buys fruit at standard rates and keeps a small consignment seed rack "on loan from Riverbend's cart," so even the carnival has a working town store; pointedly, no Rosie's: Rosie refused to franchise into a carnival, and a peeling "RESERVED: ROSIE'S SEEDS" lot sits empty with her rejection letter nailed to the post) → the Old Library, boarded up behind the Fun House, reopened during the seal arc — historian inside → Mirror Maze Arena (seal battle venue) → the Dark Chapel at the city's highest point behind the ferris wheel, the only building with no bulbs at all. Exit gate: the Gorge Gate at the far north end, chained until seal + restoration. The Dawnkey wicket-gate (Hollowkeep backpath) surfaces in the chapel's crypt wall — locked and unexplained until much later.

**4. Characters.**
- **Marlow the Barker** — top-hatted showman who never stops selling; secretly exhausted; town champion, seal battle opponent.
- **Prudence Wick** — historian; former lighthouse keeper who boarded herself into the library when the neon came; squints at anything brighter than a candle.
- **Tick & Tock** — twin ticket-takers, comic relief; finish each other's sentences wrong.
- **Old Gaffer Boon** — fixed every bulb in town for forty years, now sits blind-tired outside the Fun House; restoration target.
- **June** — a kid who has spent 3,000 tickets and can't remember why she wanted the prize; the player's mirror.
- **Ember** — gets two scripted beats: at the Ticket Arch he locks onto the Ferris Wheel of Fortune, eyes going spiral-glint (emissive eye-texture swap), and trots after it until the player's raised lantern radius touches him — he sneezes a smoke ring and shakes it off, foreshadowing the glimmer lesson wordlessly. Later, Tick & Tock rope him off and charge 2 tickets to "SEE THE DRAGON"; Ember stares back until they pay each other to stop.

**5. Quests.** Seal arc: (1) Pry open the library's boarded windows — a 90-second (tunable) light-the-lamps intro. (2) Three library study sessions on counterfeit light, each adding its serums to the Verse Satchel: Matthew 6:22-23 (the eye is the lamp), 2 Corinthians 11:14 ("Satan himself masquerades as an angel of light"), John 8:12 (the light of life). (3) The Mirror Maze seal battle vs Marlow — full spec below. Beat him and his hat falls off; a Gloomling has been whispering in his ear the whole time. It flees his Lightburst; Marlow, freed, awards **Seal 4** (Lightfound fanfare; Glimmerton is the one seal with no Wayfarer's Kit reward — in the counterfeit town, the seal itself is the only prize, and it is enough).

**Town Book — Ecclesiastes (single spec: Ch. 3.10).** Prudence keeps the town's book behind the boarded windows: Ecclesiastes, voiced on the ElevenLabs pipeline — "meaningless, a chasing after the wind" read aloud two doors down from the ticket fountain. The driest wit in the canon, in the town that needs it most. Chapters in 3 sections, comprehension questions, memory-verse checks minting Truth Serums; the reopened reading porch is the serum recharge point.

**Seal battle spec — "The Big Sell."** 3 rounds × 3 lies; each round's lies counter with verses from one library passage. Verse picker offers 3 options per lie. A wrong answer spawns a mirror clone that holds that lie and re-asks it at round's end with 4 options (the added decoy is a real verse that doesn't answer the lie — never an invented one). Three total wrong answers: fear closes in, mirrors go dark, restart the current round only — never the arc. No timer; the pressure is the crowd leaning in (camera push, tunable).

| Round | Passage | Marlow's lies |
|---|---|---|
| 1 | Matt 6:22-23 | "Feast your eyes — looking never hurt anyone." / "If it shines this bright, it can't be bad." / "You can look away whenever you want. So don't." |
| 2 | 2 Cor 11:14 | "Would a liar wear a smile this big?" / "The Gloom is out there. In here it's all light — see?" / "Everyone's watching. Don't be boring." |
| 3 | John 8:12 | "You deserve a shortcut." / "That little lantern? The wheel out-shines it ten to one." / "Stay. Out there it's dark, and you'll walk it alone." |

Side quests: **June's Tickets** — every prize counter offers June junk until she gives her 3,000 tickets to the Chapel box to relight Gaffer Boon's street (+gold, +Standing; the generosity loop made visible). **Boon's Bulbs** — collect 8 (tunable) dead warm-gold bulbs across rooftops; each installed bulb converts one neon prop permanently. **"The Marvelo Matinee" (level-gated pocket, Ch. 3.1)** — a stage door behind the Fun House posts a bill: "PRIVATE ENGAGEMENT — PATRONS OF STANDING (LEVEL 15) ONLY," Tick & Tock enforcing with unusual solemnity. At **level 15** the door opens on a one-show minigame: assist the (returned, post-Hollowkeep) Tobin Marvelo's honest magic act — three sleight-of-hand timing beats — for gold, a rare satchel dye, and Marvelo's journal page. Below level, the twins just say "come back when you've read a few more mornings." Running joke: Tick & Tock charge admission to increasingly absurd things — a bench, a puddle, the player's own lantern, Ember — baffled every time the player walks past.

**6. Unique mechanic — Glimmer Games.** Five midway skill games, 5 gold per play, paying **Tickets** (Glimmerton-only currency). These must be the most polished minigames in the game — the temptation has to be real.

| Game | Input & skill test | three.js note | Payout (tunable) |
|---|---|---|---|
| Ring Toss | Drag-release arc throw, 3 rings; bottle rows slide on a single sine | Parabola lerp, no physics | 10/25/60 for 1/2/3 landed |
| Wheel Spin | One tap to stop a 12-slot wheel under fixed friction; 80ms window on the jackpot slot | Rotation tween with ease-out | 5/15/50 |
| Mirror Shuffle | Shell game played via the mirror's reflection (fake pass visible only in glass); 3 accelerating rounds | Second camera renders to mirror texture | 0/20/45 by stage reached |
| Claw Drop | Tap-stop X, tap-stop Z; jackpot prizes wobble (telegraphed 20% slip) — skill is picking stable ones | Bone-less 3-joint claw, scripted close | 0, 30, or 75 |
| Strength Bell | 3-tap rhythm meter (wind-up, strike, follow-through) | Puck is a translate tween + shader flash | 5/20/40/90 by height quarter |

Economy math: a decent player averages ~35 tickets per ~25-second play ≈ **80 tickets/minute** ≈ 16 gold/minute spent. Prize counters sell only junk cosmetics that desaturate to gray over 60 real-time seconds (tunable) and grant nothing. The only good use of tickets is giving them away — the game never lectures; the counters do.

**7. Secrets.** (a) Behind the strength bell, a maintenance door opens into the Understage — Marlow's dressing room and his journal page: he came to Glimmerton as a kid with 3,000 tickets. (b) A single warm-gold bulb burns in the Hall of Mirrors; hold lantern-light on it 5 seconds to reveal a mirror that doesn't reflect neon — walk through to a rooftop grove with a Dawnberry seed. (c) Scratch-marks by the chapel crypt wall hint at the Dawnkey wicket-gate before Hollowkeep names it.

**8. Audio.** Theme motif: **"The Sideshow Waltz"** — a grand, slightly-wrong calliope melody that is secretly the lantern leitmotif played sharp and backwards; post-save it rights itself, and attentive players hear that the true tune was under the fake one all along. Music: the waltz over a detuned music box, every instrument a few cents sharp — the ear feels the fake before the eye does. Post-restoration the same melody returns in tune on real strings. Signature sounds: the ticket-spit (papery ratchet burst on payout) and the glimmer-fade (soft descending shimmer as a prize desaturates).

**9. Gating.** Seal 4 requires the three library sessions plus the Mirror Maze victory. Restoration meter fills via Boon's Bulbs, June's Tickets, feeding/clothing three midway workers Marlow underpaid, and the **Chapel donation box** — mid-arc it converts tickets to restoration progress at 100:1 (its 25% meter slice ≈ 2,500 tickets ≈ ~31 minutes of skilled play ≈ ~72 plays / 360 gold, all tunable); **after the save it stops feeding the meter and instead converts tickets to gold at 20:1 plus group renown**, so leftover tickets never rot. Save transformation: all neon swaps warm gold, the calliope retunes, the Dark Chapel ignites as the city's crown light, the library becomes a public reading porch, and prize counters restock with real goods — tools and produce, plus one crate of free starter seeds on Rosie's empty lot, note attached: "Not for sale. Grow something real. — R." (Rosie still refuses the franchise.) The empty lot itself is tilled into the town's **open public garden plots** (Ch. 3.3) — the carnival's one un-sellable square becomes the only place in Glimmerton where something real grows. Unlocks: the **Gorge Gate opens with seal + restoration, but the road beyond obeys standard brightness gating** — Whisper Gorge is named Gloom territory, and a dim lantern turns you back at the first waymarker, never punished, just unready. Also unlocked: Glimmerton's mission board (city-rescue co-op; home of the post-launch Glimmerton Blackout mission, Ch. 4.5), and — arriving later from above — the Starcrest ledge drop and Hollowkeep wicket-gate both feed back into a town worth returning to. Standing runs the canonical track; Guardian privilege: backstage pass — the Glimmer Games replay post-save for cosmetics only.

## 12. Whisper Gorge (trial — the long dark mile)

> **Seam.** In: **Gatelight Landing** behind Glimmerton's rear arch — requires Seal 4 (the Gorge Gate) and a lantern at **Flame or higher**; below tier, Harrow waves you back ("The dark out-argues a dim wick"). Out: the **Hollowkeep Doors** — one-way on first entry; they seal behind the player, committing them to the dungeon and the Dawnkey escape. No seal, no restoration — the gorge is survived, not saved.

**1. Fantasy & role.** Whisper Gorge is the moment the player stops being a tourist in the Gloom and walks into its throat on purpose. It is a mile-deep canyon pass between Glimmerton's back gate and Hollowkeep's doors — no town, no seal, nothing to save. You survive it. After Glimmerton taught that fake light lies loudly, the gorge teaches that darkness lies quietly: here the Gloomlings never show themselves, only their words do. The player's lantern is the only geometry that matters. Everything inside its radius is safe, warm, and legible; everything outside is ink. The gorge exists in the journey to make the lantern emotionally real before Hollowkeep takes it away.

**2. Visual direction.** Palette: near-black indigo (#0d0f1e) walls, desaturated slate rock, the lantern's warm amber (#ffb347) pool, and rare cold cyan glimmer-motes left over from Glimmerton drifting down like ash. Weather: still air, thin falling dust, no sky — the canyon rim closes overhead into darkness. Rendering: dense exponential fog + one player point light + a handful of static waystone lights; whispers are billboarded text sprites; all cheap on r128 mobile.

Signature moments (all low-poly implementable):

1. **The Turnback View** — ten steps in, the player looks back and Glimmerton's carnival glow is a tiny cold smear framed by black canyon walls; it never looked smaller or faker.
2. **The First Whisper** — a line of pale text ("You came alone. You'll stay alone.") slides along a wall just outside lantern radius, letters flaking off like moths.
3. **Wickett's Perch** — a single hut on a rock spur, forty hanging lanterns, the only warm wide shot in the level.
4. **The Choir Stair** — a descending switchback where dozens of whisper-lines orbit one shaft of dark; countering them detonates a chain of light up the whole stair.
5. **Hollowkeep Reveal** — the exit gate: two colossal doors already open a crack, exhaling cold fog uphill.

**3. Layout.** Linear pass with three light checkpoints, ~12 min first clear (tunable).

| Stage | Function |
|---|---|
| **Gatelight Landing** | Entry gate from Glimmerton's rear arch. Harrow's cart, last market access (limited stock), lantern-brightness check post. |
| **The Narrows** | Whisper tutorial corridor; first waystone at its end. |
| **Wickett's Perch** | Midpoint rest, hut, second waystone, side-quest hub. |
| **The Echo Flats** | Wide dark floor; whispers now quote NPCs the player knows. Third waystone. |
| **The Choir Stair** | Finale descent vs. the Choir. |
| **Hollowkeep Doors** | Exit gate. One-way on first entry — doors seal behind the player, opening the Hollowkeep dungeon. |

No library, arena, mission board, or chapel — those are town organs, and the gorge is not a town. Harrow's cart is the only vendor.

**4. Characters.**
- **Old Wickett** — lamplighter hermit, midpoint. Deaf in one ear and glad of it ("Can't lie to half of me"). His hut keeps a single-plank **reading shelf** — a library-class recharge point for Truth Serums (Ch. 2.3), the only one between Glimmerton and Hollowkeep's Archive. Function: trial guide, waystone teacher, comic relief.
- **Harrow** — peddler camped at Gatelight Landing for "three seasons, briefly." Sells oil, wicks, trail bread — never serums, which cannot be sold (Ch. 2.3). Function: vendor, running joke.
- **Mara** — Glimmerton runaway found huddled at a dead waystone in the Narrows; followed a glimmer-mote in, believed the first whisper she heard. Function: escortable rescue, emotional core.
- **The Choir** — the gorge's resident Gloomling cluster; never rendered as bodies, only as overlapping whisper-text speaking in unison. Function: finale opponent.

Ember rides the player's shoulder the whole pass, uncharacteristically quiet — his one line at the Perch ("I don't like it when I can't think of a joke") lands the tone.

**5. Quests.**

**Trial arc — "The Long Dark Mile":**

1. Brightness check at Gatelight Landing (Flame minimum, tunable). Harrow tries to leave with you, doesn't.
2. Narrows: whispers spawn at radius edge, drift inward at 0.6 m/s (tunable). Counter with the right Verse Satchel truth → whisper bursts to light-moths; wrong verse → fog contracts radius 15% for 10 s. Whispers never touch you — fear shrinks light, it never deals damage.
3. Relight waystone 1 by answering its inscribed lie ("No one is coming for you") — teaches the waystone verb.
4. Perch: Wickett teaches that standing still invites whispers (spawn rate doubles after 8 s idle, tunable) — "Keep walking, keep answering."
5. Echo Flats: whispers now misquote known NPCs — "Eli said you'd quit," "Rosie laughed when you left." Countering these requires the relationship truth, not just any verse.
6. Choir Stair: 9 whispers (tunable) speak one layered lie in rounds; counter the root lie ("You are alone in the dark") — e.g. Psalm 139:11–12 — and the chain-detonation clears the stair.
7. Doors open. Autosave. No seal — the reward is the Dawnlit Wick (lantern trim: +10% base radius, permanent, tunable).

**Side quests:** *Mara's Way Home* — walk Mara from the Narrows back to Gatelight Landing keeping her inside your radius (she panics outside it); she reappears in Glimmerton restored. *Forty Lanterns* — relight 8 of Wickett's dead outrider lanterns scattered off-path; each relit lantern persists across visits. *Harrow's Inventory* — deliver Wickett's oil order; Harrow insists it counts as him "technically crossing."

**Running joke:** Harrow declares "Tomorrow, first light, I cross" every single visit, across the whole game — including postgame, when the player can Ember-fly and he's still at the gate.

**6. Unique mechanic — radius-as-resource.** In-gorge lantern radius is health bar, vision cone, and escort tether in one. It is **zone-constant** (base 9 m, tunable) per the Ch. 2 decoupling rule — brightness tier gates entry to the gorge, never the size of the light inside it. Wrong answers, idling, and Gloom pockets shrink it; right verses, waystones, and movement restore it (any lit waystone restores full radius). It cannot reach zero — at 25% the nearest waystone pulses a guide-glow and whispers stop spawning (floor, not fail state). Nothing in the gorge deals damage; the only stakes are light and nerve. The Lanterneater and its Whisperling escorts (Ch. 2.5) hunt against this same radius.

**7. Secrets.**
- **The Still Grove** — an unmarked crack in the Echo Flats wall opens into a pocket of self-luminous pale moss where no whisper can spawn; contains a bench and one Gloryberry seed.
- **Eli's journal page** — wedged under waystone 2: Eli crossed the gorge young, and the lie that nearly kept him there is one the player has already heard verbatim.
- **Scratched arrows** on the Choir Stair wall point at a bricked wicket in Hollowkeep's flank — foreshadowing the Dawnkey backpath to Glimmerton.

**8. Audio.** Music: almost none — a single held low drone (root of the Glowlands theme, detuned) that thins as radius shrinks and warms to solo cello at waystones; full silence in the Still Grove. Whispers are panned dry voice-adjacent synth, never intelligible as audio (the lie is only readable as text — parents hear nothing spoken). Signature sounds: (1) the **hush** — a soft intake-of-breath filter sweep when radius contracts; (2) **paper-flutter** — dry page-riffle when a whisper materializes, resolving to wind-chime moths when countered.

**9. Gating.** Entry requires Glimmerton's seal (Seal 4) and Flame+. No restoration meter — trials are survived, not saved. Clearing the Choir Stair grants the Dawnlit Wick, marks the pass **Survived** (relit waystones and outrider lanterns persist, whisper density halves on return crossings), and unseals the Hollowkeep Doors — which close behind first entry, committing the player to the dungeon and the Dawnkey escape.

---

## 13. Hollowkeep (dungeon — the Dawnkey escape)

> **Seam.** In: the **Gorge Door** portcullis at the end of Whisper Gorge — requires surviving the gorge with a lit lantern (any tier); it seals behind the player, no backtrack until escape. Out: the **Sun Gate**, opened only by the Dawnkey, releasing onto the Dawnroad to Starcrest. The Dawnkey also permanently unlocks the **wicket-gate backpath to Glimmerton**, folding the map's scariest zone against its brightest. Survived, not saved.

**1. Fantasy & role.** Hollowkeep is where the Gloom keeps what it steals: extinguished lanterns, forgotten promises, and the player's own worst words. It is the only interior zone in the Glowlands — a black castle at the far end of Whisper Gorge that the road runs *through*, not around. Where every prior zone whispered lies at the player, Hollowkeep whispers the player's lies back *as if the player said them*: echoed lies render in the player's own dialogue-bubble style — their font, their name plate, their chosen avatar color — instead of Gloomling script, with a whisper SFX layer pitched down 4 semitones (tunable) from the UI "player action" sound. It is survived, not saved: the goal is escape, carrying the Dawnkey out into the Starcrest morning. Structurally it is the mid-point trough — the darkest hour before the summit — and the payoff for every verse the player has actually memorized rather than merely collected.

**2. Visual direction.** Palette: near-black basalt (#14121c), oxidized bronze (#3d4a3e), one warm accent — the ember-orange of the suppressed lantern (#e8863a). No sky; ceilings vanish into fog planes. Weather is interior: falling dust motes (30-particle GPU sprite pool, tunable) and cold drafts that bend candle billboards. Signature moments: (a) the Gallery of Lanterns — hundreds of dark lanterns on hooks, instanced meshes, each flickering faintly as the player passes; (b) the Echo Hall duplicate — the player's model walking 0.7 s behind at 40% opacity, mouthing their own logged lies; (c) the Keeper unfolding from what looked like a coat rack; (d) Dawnkey ignition — every Gallery lantern lighting in a radial wave (emissive lerp, no dynamic lights); (e) the Sun Gate cracking open onto blinding white fog.

**3. Layout.** Linear with one loop. Entry gate: the Gorge Door, a portcullis at the end of Whisper Gorge that seals behind the player (no backtrack until escape). Order: Gatehouse (echo tutorial, below) → Gallery of Lanterns (hub; prisoners held here) → Archive of Echoes (library analog — study cells where lie/verse pairs are researched; counts as a library for Truth Serum recharges, Ch. 2.3 — the Gloom's own archive grudgingly refills the light) → the Vault Stair (three verse-locks: each lock is a lie carved in stone with three satchel serums offered; a wrong cast snuffs the ember for 5 s, tunable, spends a charge, and reshuffles the options; a serum used on any lock is locked out for the remainder of the Stair regardless of charges, forcing deep cuts instead of John 8:12 three times) → Keeper's Rotunda (duel arena, ringed by hung lanterns instead of a crowd) → Sun Gate (exit; opens only to the Dawnkey, releases onto the Dawnroad to Starcrest). The wicket gate — a person-sized door in the Gallery's south wall — is findable early but locked; it opens outward to a Glimmerton alley once the Dawnkey is held. No market, mission board, or chapel — but see secrets.

**4. Characters.**
- **The Keeper** — the castle's warden, a tall lanternless figure of stacked black robes; never speaks an original word, only replays echoes. Duel champion analog.
- **Sera Wick** — Lantern Hollow's missing lamplighter; brisk, unbroken, re-lights her cell candle nightly. Historian analog: she has mapped which lies the Keeper hoards.
- **Tobin Marvelo** — Glimmerton stage magician who followed applause into the dark; needy NPC; insists he's "between venues."
- **Old Mote** — mole stonemason who dug the wicket gate decades ago and cannot remember which wall. Comic relief.
- **Ember** — refuses to pass the Gatehouse; waits there sneezing sparks, the zone's warm-glow checkpoint.

**5. Quests.** Main arc: (1) Gorge Door seals; lantern suppressed to a 2 m ember radius (tunable) regardless of streak tier. (2) Gatehouse tutorial: the delayed duplicate mouths one of the player's logged lies as a speech bubble; countering it with the right verse opens the inner door — one safe rep of the full loop. (3) Free Sera by winning an **echo bout** — a 3-round mini-duel on the Keeper-fight ruleset below; she reveals the Dawnkey hangs from the Keeper's belt — the first lantern it ever stole. (4) Archive: study three of the player's own missed lies and pair each with its counter-verse. (5) Vault Stair verse-locks (see layout). (6) **Keeper duel, 7 rounds (tunable), escalating:** rounds 1–2 stock lies, rounds 3–5 the player's logged misses, rounds 6–7 the Keeper's own three journal-page lies (see secrets) — all rendered in the player's bubble style. Each wrong answer suppresses lantern radius by 0.5 m (tunable); at 0 m fear closes in and the fight resets to round 1 at Ember's checkpoint — never a death — but every Gallery lantern lit by a correct counter stays lit and its lie leaves the pool, so retries get shorter. (7) Dawnkey taken; Gallery ignites; 90-second (tunable) escape as corridors dim behind the player — falling behind fades to Ember's checkpoint. Side quests: recover Tobin's five scattered trick-doves so he'll perform for the prisoners; carry Sera's lit candle to three dark cells — drafts telegraph via bending candle billboards 1.5 s ahead, and the player shelters by standing still facing the draft (body as windbreak) or ducking into alcoves; a snuffed candle relights at Sera's cell, keeping already-delivered cells lit. Running joke: Old Mote taps a wall, listens, says "this one — no," at escalating confidence, every visit.

**6. Unique mechanic — Echoes.** Hollowkeep is the only zone where attacks are lies the player personally failed to counter earlier (stock pool of 12, tunable, for perfect players). Data contract: the Truth & Light system logs every failed counter globally from the prologue onward — entry: `lie_id, counter_verse_ref, zone, timestamp` — **a hard dependency on the Meadow Town prologue shipping this logging (Phase 1 feature list, Ch. 17).** Countering an echoed lie correctly removes it from the log permanently, visualized as a Gallery lantern lighting and staying lit. Parent/pastor dashboards show lanterns lit — counts and progress — never the lie text; a child's believed lies are between them and the game. The dungeon literally converts past failures into light.

**7. Secrets.** (a) A hidden chapel cell behind the Archive where a prisoner scratched Psalm 139:12 — "even the darkness is not dark to you" — reading it aloud restores full lantern radius for 60 s (tunable). (b) Three journal pages from the Keeper's life before the Gloom — it was once a lamplighter; each page carries one lie it believed, which become duel rounds 6–7. (c) Old Mote's chalk arrow, visible only in lantern light, marking the true wicket-gate wall before the plot reveals it.

**8. Audio.** Music: sparse bowed-metal drones; a music box playing the Meadow Town theme a half-step flat and 0.7 s delayed. Signature sounds: the dry clink of empty lantern hooks swaying; the Dawnkey's chime — a rising three-note bell the Starcrest soundtrack later resolves.

**9. Gating.** Entry requires surviving Whisper Gorge with a lit lantern (any tier). No seal, no restoration meter; the "transformation" is the Gallery — every lantern the player lit stays lit forever on return visits. The Sun Gate opens the road to Starcrest; the Dawnkey permanently unlocks the wicket-gate backpath to Glimmerton. Freed prisoners reappear home: Sera on Lantern Hollow's lamp rounds, Tobin busking (honestly, mostly) in Glimmerton.

---

## 14. Starcrest (Seal 5 — the shepherd's summit)

> **Seam.** In: the **Gorge Stair** in the south cliff — requires only the Dawnkey escape from Hollowkeep; Starcrest itself is a full safe zone, enterable and walkable at any brightness (fear-zone lamb behavior, Flame+, is the only brightness-sensitive system inside it). Out: the **North Saddle** gate behind the chapel, sealed until the town is saved (Seal 5 + restoration), opening the Shepherd's Descent to Brightharbor. Shortcut: the one-way **Ledge drop** to Glimmerton — the jump prompt arms only when Starcrest is saved.

**1. Fantasy & role.** Starcrest is the exhale. The player arrives having survived Whisper Gorge and escaped Hollowkeep with the Dawnkey — two zones of pressure and darkness — and steps out of a cliff stair onto a summit meadow *above the cloud layer*, into permanent starlight and open sky. Starcrest is a shepherd town: terraced pastures, bell-carrying sheep, one great chapel whose steeple is the highest built point in the Glowlands. Its narrative job is clarity after darkness — the Good Shepherd chapter (Psalm 23, John 10:11). Mechanically it slows the game down: no time stress, long sightlines, and a seal arc about *knowing the voice you follow*. The Gloom here doesn't loom; it scatters — its residue is confusion, lost lambs, and shepherds who stopped calling.

**2. Visual direction.** Palette: deep indigo sky (#1B2140), star-white and pale gold light, cloud floor in blue-white (#DCE4F2), grass in cool sage (#8FAE8B), wool cream, chapel stone in warm slate. Lighting: single directional "starfield" key at low intensity plus emissive lantern and bell props; no sun — Starcrest is perpetual clear night that reads bright, not scary (fog density near zero, the inverse of Whisper Gorge). Weather: still air; occasional slow star-streaks (billboard sprite, ~1 per 40 s, tunable). Signature moments: (a) the cloud floor — a flat animated plane with scrolling vertex noise the player looks *down* onto from the entry stair; (b) the Bellfield, 60+ low-poly sheep, bells glinting; (c) the chapel steeple lamp visible from anywhere on the map; (d) the Ledge — a grass lip where the clouds part and Glimmerton's carnival glow flickers far below, glimmer seen from above for the first time; (e) restoration finale: every sheep bell rings once in a wave across the terraces. **Perf budget:** zone ceiling ~120 draw calls / 150k on-screen tris; the flock is one `InstancedMesh` (head-bob via per-instance phase offset in the vertex shader), bells merged into it; cloud plane ≤ 64×64 verts; star-streaks and bell glints are sprite billboards, no point lights beyond the steeple lamp and 6 terrace lanterns.

**3. Layout.** Map footprint ~180×220 m; entry gate to North Saddle exit ≈ 90 s at walk speed along the main loop, ≈ 45 s to the chapel. Walkable loop, entry to exit: **Entry gate** — the Gorge Stair, a switchback cut in the south cliff (door from Whisper Gorge/Hollowkeep exit). It opens onto **Cloudrim Walk** (~60 m overlook path along the cloud floor) → **Bellfield** (three pasture terraces of ~40 m each, needy-NPC shepherd camps, side quests) → **Town Terrace** (market row: wool-and-broth stalls, a Berry Market fruit stall, a Rosie's Seeds satellite cart — the town store pair, fruit bought and seeds sold — plus terrace-edge **public garden plots** (Ch. 3.3) where crops grow under starlight, and the **mission board** by the well) → **The Star Library** (observatory-library hybrid, historian, dome with a low-poly orrery) → **Chapel Green** (chapel + steeple; the quest arena is the open green in front, crowd seating on the terrace steps) → **Exit gate**: the North Saddle gate behind the chapel, sealed until the town is saved, opening the Shepherd's Descent toward Brightharbor. **The Ledge** (one-way drop to Glimmerton) sits west of Cloudrim Walk, deliberately off the main loop.

**4. Characters.**
- **Isla Fold** — historian and retired shepherdess; talks in flock metaphors; runs the Star Library and the seal study track.
- **Cald** — town champion, a young head-shepherd who memorized Scripture on night watches; humble, and the fastest hand on the buzzer in the Glowlands.
- **Petra & Puff** — a widowed weaver and her lamb Puff, who follows the *player* everywhere once met; running joke and needy NPC (needs wool orders to restart her loom).
- **Old Cray** — shepherd who stopped calling his flock after the Gloom mist took three lambs; the emotional spine of the restoration arc.
- **Bramble** — Ember's foil: a bell-wether ram who headbutts Ember on sight. Comic relief pair for the whole zone.

**5. Quests.** **Seal arc ("The Voice You Know"):** (1) Isla's library study — three sessions (John 10:1–15, Psalm 23, John 10:27–28), each unlocking 3 Verse Satchel entries; these **9 entries are the entire question pool** for the battle — nothing outside them is asked. (2) Field practicum — use the Crook Call to return 5 of Cray's scattered lambs (tunable). (3) A Gloomling ambush in the Bellfield whispering "No one is coming for you" — countered by John 10:11. (4) **Trivia battle vs. Cald**, Chapel Green, crowd of ~20 NPCs. Three themed rounds of 3 questions each: *The Shepherd's Voice* (John 10:1–15), *The Ninety-Nine* (Psalm 23 + lost-sheep material), *Laying Down His Life* (John 10:11–28). Format per question: the lie/prompt appears, then a shared buzzer window opens; **Cald auto-buzzes at 3.0 s (round 1) / 2.5 s (round 2) / 2.0 s (round 3), all tunable** — buzz before him to answer from a 4-verse choice (8 s answer timer). Correct = 2 pts and a Lightburst; wrong = Cald steals for 1; letting Cald buzz first = he scores 1 (he never misses). First to 8 pts wins; Cald deliberately throws his first buzz ("Now you're awake"). **Loss state:** no penalty — Cald offers a re-challenge next in-game day, and Isla opens a free review session that replays any of the three studies. Victory grants **Seal 5** and **Morningstar Oil** (milestone-reward table, Ch. 2.7 — vignette decays 2× faster post-encounter; immune to Dreadroot pre-tighten, which pays off on every Hollowkeep return and in New Journey+), both on the Lightfound fanfare.

**Town Book — 1 Peter (single spec: Ch. 3.10).** Isla shelves the town's book under the orrery dome: 1 Peter, voiced on the ElevenLabs pipeline — the Chief Shepherd, the scattered flock, and hope kept through the night watch, read in the town that watches all night. Chapters in 3 sections, comprehension questions, memory-verse checks minting Truth Serums; the Star Library desk doubles as the serum recharge point.

**Side quests:** *Wool for the Widow* — shear 8 sheep (3-tap rhythm minigame) for Petra's loom; *The Ninety and Nine* — census the Bellfield, discover one lamb missing, find it on a fenced sub-ledge below the Ledge lip (reached by a side ramp; the drop itself cannot fire here — see secrets); *Bell Tuning* — collect 4 cracked bells for the Toolworks traveling smith; *The High Fold* **(level-gated pocket, Ch. 3.1)** — Old Cray's abandoned upper pasture, a switchback above the chapel with a Gloryberry-grade public plot and the best view of Everlight's skyline glow in the game. Cray bars the stile below **level 20**: "Those switchbacks are no place for green legs. Come back at level 20 — the view'll keep." Restoring the High Fold (3 fence repairs, 1 lamb escort) is worth +10 Standing and a permanent starlit growing bed. **Running joke:** Bramble ambush-headbutts Ember at every terrace transition; escalating dodges until the finale, where Bramble headbutts a Gloomling instead.

**6. Unique mechanic — the Crook Call.** Starcrest grants the Shepherd's Crook, a held tool with a radial call pulse (ring VFX, 8 m radius, tunable). Lambs inside the ring path-follow the player single-file (max 5, boid-lite follow, no physics). Fear zones (Gloom residue patches) make lambs bolt unless lantern brightness is **Flame or higher** — the first mechanic that pays streaks forward into *protecting others*, not just self-access. Persists into Brightharbor escorts and Mission Trips.

**7. Secrets.** (1) **The Ledge drop** — a scripted cloud-dive slide landing behind Glimmerton's carnival gate. It is a deliberate two-step: walk to the lip → "Jump?" prompt. **The prompt is disabled until Starcrest is saved** (and always disabled while *The Ninety and Nine* is active); before then the sign just reads "Long way down. Short way back." — a promise, not a trap. This matches gating: the shortcut arms only on save. (2) **Isla's journal page** hidden in the orrery — she once chased glimmer in Glimmerton as a girl. (3) **The Quiet Fold** — a hidden grove behind the chapel where all audio ducks to a single soft pad and a stone bench offers the day's red-bag question early.

**8. Audio.** Theme motif: **"The Night Call"** — a two-phrase nylon-guitar melody shaped like the shepherd's call-and-return, hum-choir answering; the Dawnkey's three-note bell chime (Ch. 13) resolves into its opening interval, so arriving from Hollowkeep literally completes the tune. Music: sparse nylon guitar and hum-choir over a held low drone, wide reverb, ~64 BPM; layers add (bells, high strings) as restoration fills. Signature sounds: the **bell-wave** (pitched sheep bells cascading terrace to terrace) and the **Crook Call** (a warm two-note wooden whistle with a shimmer tail). The Cragmother boss arc (Ch. 2.6) is scored by subtraction — her howl is the only sound that ducks the bells.

**9. Gating.** Requires: Dawnkey escape from Hollowkeep complete — nothing else. The lantern-brightness gate belongs to Whisper Gorge's own entry; **Starcrest itself is a full safe zone, enterable and fully walkable at any brightness**, with fear-zone lamb behavior (Flame+) the only brightness-sensitive system inside it. Saved when Seal 5 is earned and the restoration meter is filled (~12 service contributions, tunable). Transformation: cloud floor brightens to dawn-silver, steeple lamp becomes a beacon visible from Glimmerton and Whisper Gorge, terrace lanterns light, sheep density +50%, market stalls reopen with Starberry-tier seed stock, chapel bells join the town theme. Unlocks: North Saddle gate onto the Shepherd's Descent to Brightharbor, the Ledge shortcut (drop prompt arms), Starcrest mission board (co-op "Night Watch" escort).

**Standing ("Flockhand" track — a town override of the Ch. 3.5 defaults):**

| Rank | Advanced by | Perk |
|---|---|---|
| Stranger → Neighbor | first shearing + 3 lamb returns | broth stall opens: +10% walk speed buff, 5 min (tunable) |
| Neighbor → Friend | Bell Tuning complete + 6 restoration contributions | Puff follows the player into other zones as a cosmetic companion |
| Friend → Guardian | all side quests + restoration meter full | 15% vendor discount in Starcrest + a bell engraved with the player's name hung on the chapel wall |

---

## 15. Brightharbor (Seal 6 — the sending harbor)

> **Seam.** In: **Cliffgate**, switchback stairs at the foot of the Shepherd's Descent (requires Starcrest saved). Out: the **Ferry Pier** — open on arrival for downstream-only "evacuation runs" to Meadow Town; the RETURN berth sits chained until the town is saved (Seal 6 + restoration), when the ferry becomes two-way and closes the world loop. The fog-lane row-out is the town's one brightness gate (**Flame or higher**); every quay-side activity is safe-zone at any brightness.

**1. Fantasy & role.** Brightharbor is the journey's exhale: after the summit cold of Starcrest, the player descends switchbacks into salt air, gull noise, and the smell of tar and fried fish. It is the last town, the sixth seal, and the place where the game's theme pivots from *receiving* light to *sending* it — every restored dock exists to load ships bound for the towns the player already saved. When the return ferry finally casts off for Meadow Town, the world map folds shut into a loop and the player feels the size of everything they've done.

**2. Visual direction.** Palette: weathered teal and barnacle white on the hulls, rope-brown piers, mustard oilskins on NPCs; the Gloom here is a grey fog bank squatting offshore, flattening the horizon to a single value. Lighting: perpetual golden-hour key light from the landward side; fog kills all specular on the water until restoration. Weather: light drizzle cycles (~90 s on / 180 s off, tunable) that bead on low-poly awnings via a simple shader scroll. Signature moments: (a) first cliff-top reveal — 40 masts as flat triangle sprites in a dead-calm grey bay; (b) the dark lighthouse, its lamp room visibly empty; (c) low tide draining the harbor plane 2 m to expose glistening flats; (d) restoration night — 200 instanced paper lanterns released over the water on one animated spline sheet; (e) the ferry's departure wake catching the first sun the bay has seen.

**3. Layout.** One descending arc, walkable in order: **Cliffgate** (entry gate; switchback stairs where the Shepherd's Descent ends, guarded shelter hut) → **Netter's Row** (market street: Berry Market stall, chandlery — whose counter carries a salt-hardy seed rack, making the Row the town store for both fruit and seeds — and sailmaker; behind the Row, a terrace of crate-built **public garden plots** (Ch. 3.3) catches the landward sun) → **Fish Market Steps** (a tiered stone amphitheater over the fish auction floor — the quest arena) → **The Lighthouse** (harbor mouth; the Harbormaster's Log archive in its base is the library) → **Breakwater Chapel** (a hull-roofed chapel at the end of the stone breakwater) → **Main Quay** (mission board bolted to a crane leg; quay-side soccer pitch chalked between two warehouses) → **Ferry Pier** (exit gate, open on arrival — Cato permits outbound "evacuation runs" through the marked fog lane, so the ferry sails downstream-only to Meadow Town from day one; the RETURN berth beside it sits chained and dark until seal 6).

**4. Characters.**
- **Old Pell** — retired keeper of the Harbormaster's Log; historian. Reads every entry aloud in shipping-forecast cadence.
- **Captain Sela "the Knot" Brindle** — town champion; young trawler captain who quizzes her crew on verses the way other captains drill knots. Fights fair, hates losing.
- **Harbormaster Cato** — anxious ledger-keeper who rations everything "until the fog lifts"; restoration slowly unclenches him.
- **The Tarrow family** — needy NPCs: a fisher household (mother Tansy, three kids) living in an upturned hull since their boat was fog-lost.
- **Deacon** — a pelican who steals quest-irrelevant props mid-cutscene. Comic relief; Ember's nemesis.

**5. Quests.** *Seal arc:* (1) Cato refuses full harbor access — the fog has "eaten" three boats; only the evacuation lane out stays open. (2) Old Pell opens the Log: study sessions teach the sea-verses (Isaiah 43:2; Psalm 107:29; Hebrews 6:19 — "an anchor for the soul") and reveal the fog is a Gloomling raft-colony whispering *"No one is coming back."* (3) Row out at low tide with your lantern mounted on the rowboat bow — the fog bank is named Gloom territory, so launching requires **Flame or higher**; the boat lantern's zone-constant radius (base 7 m, Ch. 2 decoupling rule) physically pushes the fog wall back and is the reading light for Fogmaw lies, while a dim lantern leaves the lane reading "too dark to row." Counter three lie-volleys with the studied verses; the colony scatters. (4) Trivia battle vs Sela on the Fish Market Steps, full auction crowd, 3 rounds of 5 questions (tunable) drawn from the Harbormaster's Log study set plus the player's earned Verse Satchel, weighted 60/40 toward the sea-verses (tunable). A crowd meter swells with each answer streak — fishmongers ring bells at each meter step, and a full meter pays a +15% XP bonus on the win. Lose, and Sela buys you chowder and grants a re-challenge at the next low tide — the Tide Clock doubles as the retry timer. After any loss she takes, Sela copies your satchel order into her crew drills, muttering that she "fights fair, steals smarter." Win = the **Seal of the Anchor (Seal 6)** and the **Beacon Prism** (milestone-reward table, Ch. 2.7 — cut from the old lighthouse lamp's glass), both on the Lightfound fanfare.

*Town Book — Acts (single spec: Ch. 3.10).* Old Pell shelves the town's book beside the Harbormaster's Log: Acts, voiced on the ElevenLabs pipeline — the sending church read in the sending harbor, ships in the harbor loading as the chapters count the journeys out. Chapters in 3 sections, comprehension questions, memory-verse checks minting Truth Serums; the lighthouse-base archive desk doubles as the serum recharge point. *Side quests:* refit the Tarrows' hull-house into a real boat (service, feeds restoration meter); recover Cato's ledger pages that Deacon scattered across five rooftops; deliver hot chowder to the breakwater watch before the drizzle cycle ends (soft 90 s timer, repeatable). *Running joke:* every sailor assumes Ember is a "sea dragon" and asks him to breathe on wet firewood; he cannot, and gets progressively more theatrical about pretending he simply chooses not to.

**6. Unique mechanic — the Tide Clock.** A visible dial on the quay runs a 6-minute tide loop (tunable): low tide lowers the water plane, opening mudflat paths, salvage spawns, and the rowing route to the fog colony; high tide closes flats but opens ship boardings, port missions, and ferry departures. One water-plane Y-lerp plus swapped navmesh regions — cheap, legible, and it teaches patience as a mechanic before the endgame. The fog-lane row-out is the only tide window that also checks the lantern; every quay-side activity is safe-zone and open at any brightness.

**7. Secrets.** (a) A tide-pool grove behind the breakwater, reachable only in the last 30 s of low tide, holding a Gloryberry seed. (b) Journal page in the lighthouse lamp room: the last keeper's entry, hinting Everlight's light once fed every lighthouse in the Glowlands. (c) A barnacled wicket door on the ferry's cargo deck — the Dawnkey fits the lock and turns, but the door is welded shut from the far side and opens nowhere; Old Pell just mutters "keep doors end up in the strangest places," a pure callback for Hollowkeep veterans.

**8. Audio.** Theme motif: **"Out and Back"** — a concertina phrase in 6/8 that sails away from the tonic and returns home a third higher each repeat; at the save, the ferry horn states its final return as Meadow Town's "Open Door" motif — the two towns share one melody across the water. Music: concertina and low strings over a slow 6/8 sway; restoration adds hammered dulcimer and gull-cry ornaments. Signature sounds: the fog's sub-bass *hush* that ducks all other audio near the waterline; the Tide Clock's brass *clunk* at each tide turn, audible town-wide. The Undertow boss arc (Ch. 2.6) plays over this bed — the drowned-lantern stingers are its percussion.

**9. Gating.** Saved when the Seal of the Anchor is earned AND the restoration meter fills. Meter = 100 units: Tarrow boat refit = 40; ledger-page recovery = 15; chowder runs = 5 each (repeatable ×3); relief crates = 10 each, where 1 crate = 20 fruit or 5 goods and crate requests rotate per saved town on each tide turn (Riverbend wants grain goods, Lantern Hollow wants lamp oil, etc.) — generosity rewarded with Standing and renown. Transformation: fog bank burns off over 20 s, water gains sun-glint specular, lighthouse lamp relights, lantern release plays, sea shanty layer enters, the chandlery and sailmaker reopen, and the chain drops off the RETURN berth — the **Brightharbor ↔ Meadow Town ferry** becomes two-way and closes the world loop (outbound sailings were never gated). Also unlocks the port mission board: disaster resupply runs, plus **Kickabout** on the quay pitch as the town's signature soccer mission (full spec Ch. 4.5). Standing: **Neighbor** = fishmongers' discount at Netter's Row (−10%, tunable); **Friend** = Sela lets you helm the trawler for salvage runs at low tide; **Guardian** = your own cot in the lighthouse lamp room, and Deacon stops stealing from you — and starts stealing FOR you (one random prop delivery per visit). Dim-lantern players retain every quay-side quest, shop, and Standing activity; only the fog lane and dark-flagged missions wait on brightness. With all six seals aboard, the first two-way ferry ride home is the game's victory-lap cutscene — the whole coastline lit town by town.

---

## 16. Everlight City (finale — the Vigil and the commissioning)

> **Seam.** In: the **Pilgrim Stair** above Meadow Town (reached via the ferry loop home) ending at the **Six-Seal Gate** — all six Lantern Seals, no exceptions and no partial access; brightness is *not* checked at the gate, and the city inside is a safe zone at any tier. The **Vigil** itself requires a lit lantern (Flame — one real day of reading), delivered diegetically by Selah. Out: the **Wicket of the Morning** behind the Chapel drops directly into the Home Garden, unlocked post-finale — the last map fold: the source of light opens onto your own backyard.

**1. Fantasy & role.** Everlight City is the source of the glow — the place every chapel steeple in the Glowlands has been pointing at since hour one. Its skyline glow is baked into the distant skybox of every town; the player has been walking toward this light the whole game without being told. The city sits on highlands above Meadow Town, reached by the Pilgrim Stair after the Brightharbor ferry loop — the final gate turns out to have been near home all along. The reversal that defines the area: Everlight City does not need saving. It has never fallen. The player arrives expecting a final battle for the city and instead learns the city's whole purpose is to send light out. You don't defend Everlight. Everlight commissions you.

**2. Visual direction.** Palette: warm ivory stone, brass, deep evening-blue sky held permanently at civil dusk so the light reads maximally, banners in Gloryberry gold. No fog inside the walls — the only zone in the game with fog density 0. Lighting is entirely diegetic: thousands of instanced emissive lantern billboards with additive glow sprites, one hemisphere light, zero dynamic shadows (r128 phone budget). Signature moments: (a) cresting the Pilgrim Stair and seeing the city fill the screen while every lantern flares in a radial wave from the Chapel outward (staggered emissive-intensity tween, ~2.5 s, tunable); (b) the Six-Seal Gate — six dark pylons that ignite one per seal as the player approaches, each in its town's accent color; (c) the Everlight itself, a column of layered scrolling additive planes in the Chapel of the Dawn, the single brightest object in the game; (d) during the finale, the city going dark section by section as the Hush arrives — emissive lerp to 5%, tunable — so the player's lantern is briefly the only light in the source of light.

**3. Layout.** Walkable order: Pilgrim Stair (entry, switchback climb, ~90 s walk, tunable) → Six-Seal Gate plaza (entry gate; pylons + Warden's booth) → Lantern Row (market analog, inverted: no stall sells — every stall gives) → Great Library of Light (library; every Truth Serum the player has ever earned browsable as physical shelved books; serum recharge at the great desk; postgame it opens **Revelation** as the city's Town Book, Ch. 3.10 — the city of light reads the city of light, unlocked at the commissioning) → the Terrace Gardens (the city's **public garden plots**, Ch. 3.3 — raised ivory beds where pilgrims' crops grow side by side, every bed lamplit) → Crown Terrace (quest arena analog; open amphitheater where the Vigil finale plays out, crowd bowl of instanced NPCs on three concentric terrace rings) → Chapel of the Dawn (the Everlight; chapel + Ember-flight anchor) → Sending Quay (mission board hub; all endgame Mission Trips post here). Exit gate: the Wicket of the Morning behind the Chapel — a small door that drops directly into the Home Garden, unlocked post-finale.

**Lantern Row economy.** Gifts are scoped to endgame consumables only — none are sellable, none accept or pay gold, so the Meadow Town fruit/gold/Toolworks economy is untouched. The city's one exchange is the **Provisioner's Stall** at the Sending Quay, and it is outbound-shaped like everything here: it buys fruit at fair Berry Market rates for the relief shipments and *gives* pilgrim seed packets freely — Everlight's variant of the every-town store rule (Ch. 3.3), selling nothing.

| Stall | Gives | Qty / refresh | Consumed by |
|---|---|---|---|
| Stairwright's Bench | Guide-lantern kit | 2 / day | Lanterns for the Stair side quest only |
| The Wickery | Mission flare (pings objectives 10 s, tunable) | 3 / day | Sending Quay Mission Trips |
| Loaves & Portion | Sending loaf (relights a teammate's dimmed lantern in co-op) | 2 / day | Mission Trips |
| Oil & Honey | Lamp-oil flask (+20% lantern radius, one mission, tunable) | 1 / day | Mission Trips, Whisper Gorge remnant runs |
| Selah's Cart | Verse bookmark (marks one studied verse in Vigil practice drills) | 1 / day | Library practice only — inert in the real Vigil |

**4. Characters.**

| Name | Personality | Function |
|---|---|---|
| Keeper Selah | Ancient, gentle, remembers every pilgrim by their lantern | Historian; runs Library study for the finale |
| Warden Boaz | Deadpan gate bureaucrat; inspects visibly-blazing seals "for irregularities" | Gatekeeper; running joke |
| Mira | Lamplighter kid who has never seen the dark and asks the player what it's like | Emotional anchor; finale assist |
| Eli (returning) | Arrives quietly by the Stair; revealed as a former pilgrim | Payoff of the whole-game mentor thread |
| Ember (returning) | Trying desperately to look solemn in the holy city; failing | Comic relief; earns rider-flight here |
| The Hush | Final Gloom entity; a silence that quotes | Finale antagonist |

The Hush has no lies of its own. It replays, verbatim, lies the player has already defeated — drawn exclusively from the beaten-lie log, the authored Gloomling lines the player answered correctly across all six towns. Nothing player-authored is ever stored, quoted, or voiced back; every line the Hush speaks shipped on our content sheet and passed theological review. (This is a hard data rule, not just tone: parents and pastors see everything.)

**5. Quests.** Main beat — the Vigil of the Long Night:
1. Present six seals at the Gate (Boaz stamps each anyway).
2. Library study with Selah — a review across all six towns' verse sets, no new verses, deliberately a remembering. Format: 3 recall prompts per town, 18 total, drawn from verse-set IDs `VS-MEA`, `VS-RIV`, `VS-HOL`, `VS-GLM`, `VS-STA`, `VS-BRI` (content sheets owned by the narrative/theology track; locked before implementation). Pass at 15/18 (tunable); misses re-drill immediately. Selah then stamps the Vigil Writ — but only into a lit lantern (see gating).
3. The Hush masses the Gloom on the Stair; the city dims district by district.
4. Finale on Crown Terrace: 12 waves (tunable) of Truth & Light. The Hush replays beaten lies, escalating to compound lies needing two-verse sequences.
5. Each correct answer ignites the crowd via Kindling (below); a fully lit crowd repels the Hush — darkness flees, never dies on screen.
6. Commissioning at the Everlight: Eli's story, Ember's flight, the Wicket opens.

**Vigil combat spec.**

| Waves | Lie type | Answer timer | Satchel choices shown | Crowd target |
|---|---|---|---|---|
| 1–4 | Single, one town's log each | 20 s (tunable) | 3 | Light 2 wedges/wave |
| 5–8 | Single, mixed towns | 15 s | 4 | Light 3 wedges/wave |
| 9–12 | Compound (two-verse sequence) | 25 s total | 5 | Light 4 wedges/wave |

- **Charges:** the Vigil is charge-exempt — Selah's Writ seals every equipped Truth Serum at full charge for the night. The finale tests recall, never packing; nobody loses the Long Night to an empty vial.
- **Wrong answer or timer expiry:** one lit crowd wedge goes dark ("fear closes in" — a visible cold ripple, no scare sting). Dark wedges must be re-lit by later cascades before crowd fill counts.
- **Soft-fail:** ending any wave with dark wedges advances the Hush one terrace ring inward. At ring 3 the current wave restarts with the Hush pushed back to ring 2. Never a full-battle restart; wedges lit in prior waves always stay lit. Quitting out resumes at the current wave.
- **Wayfarer's Kit modifiers (Vigil-specific overrides of the Ch. 2.7 table):** the Lie-Lens greys out one wrong satchel option on compound lies; the Keeper's Hood absorbs the first wrong answer per wave (no wedge darkens); Morningstar Oil +5 s per timer; the Quickstrap +50% Kindling reticle speed; the Deepwell Vials retreat the Hush one ring on any 3-correct streak (a full pack steadies the night); the Beacon Prism makes correct answers ignite 2 seats at the chosen origin instead of 1.

Side quests: **Lanterns for the Stair** — install 10 guide-lanterns down the Pilgrim Stair (consumes Stairwright kits; generosity mechanically rewarded: permanent +1 lantern radius, tunable). **Mira's First Night** — walk Mira to the Gate to see real darkness; she asks three questions, each answered by choosing a verse from the satchel:
1. "Is the dark stronger than the light?" — accepted answer: John 1:5.
2. "If I got lost out there, would anyone see me?" — accepted answers: Psalm 139:11–12 (primary) or Deuteronomy 31:6.
3. "How do you keep from getting lost?" — accepted answer: John 8:12 (the anchor; Mira repeats it back softly, then lights her own lamp from the player's).

Running joke: Boaz's inspection paperwork grows each visit; his final stamp on the sixth seal is a single tiny "ok."

**6. Unique mechanic — Kindling.** Light chains: any lit lantern auto-lights neighbors within 4 m (tunable) after 1 s, cascading. Introduced as a toy in Lantern Row, it becomes the Vigil's spatial layer — the only spatial input in Truth & Light, layered *after* the canonical verse choice, never replacing it. Input spec: on a correct answer, a 3 s free-aim reticle (drag on touch, snaps to seats) appears over the crowd bowl; the player picks the ignition seat and the cascade spreads seat-to-seat from there. The crowd is built as wedges with aisles between them, and the Hush extinguishes "gap seats" between waves — cascades cannot jump a gap or an aisle, so ignition placement is a small routing puzzle: light behind a gap and the cascade strands; light at a wedge's hinge seat and it floods two wedges. If the reticle times out, the cascade starts at the nearest dark seat (never wasted). Diagram note for the encounter doc: top-down Crown Terrace plate showing 12 wedges × 3 rings, aisle lines, and a worked example of a gap-strand vs. a hinge ignition. Second twist: compound lies require two verses picked in sequence — the only place the Verse Satchel asks for combinations.

**7. Secrets.** (a) A mural crypt under the Library showing a young Eli failing his first Vigil — he never earned all six seals; the player finishes what he couldn't. (b) The first Lightkeeper's journal, six pages hidden one per district, assembling the city's founding. (c) A dark, unlit seventh pylon at the Gate with no inscription — deliberate expansion hook, never explained.

**8. Audio.** Theme motif: **"The Everlight"** — the lantern leitmotif itself, the melody that has scored every streak-up moment (and hides inside every town motif, including Glimmerton's sharped inversion and the Lightfound fanfare's resolving interval), finally stated in full. Music: warm choir pads and bells over the traveling theme; during the Hush's dimming, the mix strips to a solo humming the same melody. Signature sounds: the Seal Chord (six stacked chimes, one per pylon, resolving as a major chord on the sixth); the Hush's arrival, which is subtraction — a hard duck of all ambience to near-silence rather than any added sound.

**9. Gating.** Entry: all six Lantern Seals, no exceptions and no partial access — the pylons physically bar the gate; lantern brightness is *not* checked at the gate. Inside the walls the city is a safe zone at any brightness — a dim-lantern player can explore, meet everyone, and receive Lantern Row gifts. The Vigil itself requires a lit lantern: Flame, i.e. one real day of Bible reading. This is delivered diegetically, not as a menu wall — Selah will not stamp the Vigil Writ into a dark lantern; she says to come back after today's reading, and her 18-prompt review doubles as that same session's on-ramp. The retention loop *is* the finale's front door, never a punishment (skip-day players lose nothing they had).

**Standing.** Everlight runs the canonical Stranger → Neighbor → Friend → Guardian track, compressed: the player arrives at **Neighbor** (six seals precede them — Boaz grudgingly concedes this), reaches **Friend** by completing either side quest, and is named **Guardian of Everlight** at the commissioning. Guardian here is the account-level prerequisite for the Sending Quay board and Ember flight, so systems can gate endgame on one Standing check.

Everlight has no restoration meter; its analog is the Vigil crowd fill. Completing the Vigil unlocks: Ember flight, the Wicket of the Morning shortcut to Home Garden, the Sending Quay endgame mission board, and New Journey+.

### 16.10 Endgame, finale payoff, and post-game

**Ember flight.** From any saved town's chapel or the Chapel of the Dawn, mount Ember for map travel: a canned spline between chapel steeples, 18–30 s per route (tunable; camera and LOD far-shell spec in Ch. 5.2), landing on the target steeple. No free flight — steeple-to-steeple only, keeping the world's walkable design intact.

**Sending Quay.** Post-game Mission Trips (2–8 slots, any mix of live players and bots via the standard lobby, quick-phrase wheel only) escalate: Gloom-remnant cleanups in Whisper Gorge, rebuild contracts in Riverbend and Brightharbor, VBS hosting in Glimmerton. Lantern Row consumables (flares, loaves, oil) are balanced for these. Renown from Quay missions feeds the Garden League weekly.

**New Journey+.** Optional restart of the town arc with: Standing tracks and Verse Satchel carried over, Gloomlings drawing from the full-game lie pool with compound lies from town two onward, remixed champion battles, and one new journal page per town. Lantern rules unchanged — real daily reading still gates the frontier, because the retention loop is the point, not the difficulty.

**The Gloom after the finale.** The Gloom is repelled, not eradicated — it persists as remnants in its named territories (Murkmire, Whisper Gorge, Hollowkeep) so trials, Quay missions, and NJ+ keep their teeth. Saved towns never re-fall. The world's promise holds: darkness always flees light, and there is always somewhere new to carry it.

---

# Part III — Build phasing

The phasing rule: **every phase ends with something a real youth group can play end-to-end.** Phase 1 proves the reading thesis on the smallest possible map; Phases 2 through 4 extend the proven loop rather than betting on new ones. Content within a phase is ordered so systems land before the zones that consume them, and so the Hollowkeep data dependency (the global miss-log, Ch. 13.6) is satisfied from the first shipped encounter.

## 17. Phase 1 — the gateway slice

**Scope.** The Home Garden update + Meadow Town (full) + the East Road connecting toward Riverbend. Nothing else. One town, one road, the whole thesis: real reading lights a lantern, a lantern saves a town, and a saved town stays saved. Deliberately small — small enough to ship fast, complete enough that a real youth group can play it end-to-end and want the next gate open.

**Why this slice proves the game.** It exercises every pillar once at minimum viable size: reading lights the lantern and the prologue converts a plan day into Flame on the spot (pillar 1); the prologue through the First Shadow runs the non-violent combat covenant, type chart and Truth Serum charges included (pillar 2); a lapsed player still has the garden and, once earned, a saved Meadow Town (pillar 3); Meadow Town's save transformation is the retention promise made visible (pillar 4); and one town + one road + the hub stress the perf budget honestly (pillar 5). It also contains the game's first boss (the First Shadow), first champion trivia battle, first Town Book (John), the Lantern origin scene (Zohar), the first Wayfarer's Kit reward (the Lie-Lens), and the first road with living challenges. What it deliberately does *not* contain: any second town, any trial, any multiplayer — those are Phase 2's bets, made after this one pays.

**Ordered feature list (build order; each row assumes the rows above it).**

| # | Feature | Contents / notes |
|---|---|---|
| 1 | Engine frame | Zone streaming via gate transitions (≤4 s LTE), camera rig (Roam/Close/Encounter states), touch controls (tap-move, floating stick, contextual hop), movement feel + juice baseline (squash/stretch, footstep puffs, lantern pendulum, interaction bloop, haptics bridge, **the Lightfound fanfare** wired as the universal earn event, Ch. 5.7). Perf harness asserting ≤120 draw calls / ≤150 k tris / 30 fps floor on the target device from week one. (Ch. 5) |
| 2 | Home Garden update | Eastgate arch, Lantern Post, damaged Wayfarer's Table (six empty sockets), Satchel Hook, south-path retirement + bramble, Hearthlight rule, Eli/Pip prologue staging (Ember stays home — his whistle is Phase 2). Community Garden untouched except data hooks for later. (Ch. 6) |
| 3 | Lantern service | Server-derived brightness on the stepwise algorithm (full Spark/Flame/Beacon/Radiant data model; only Spark/Flame gates are *used* in the slice), read-only on the client, session-start + foreground refresh, gate lines deep-linking to today's plan, 7-of-rolling-10 Radiant rule, session-end forward-pull card. (Chs. 3.4, 5.5) |
| 4 | Truth Serum pipeline + Satchel | CMS plan-day pool authoring (≥3 tagged verses/day) + per-plan fallback pools (30 min) + publish blocker; **memory-verse challenge flow** minting serums on plan-day completion, server-acked earns; **charge model** (5 charges, spend-per-cast, library recharge); Satchel radial UI, 6 families × 3 cards, charge pips, long-press full text, mastery counters. **The global miss-log ships here** (`lie_id, counter_verse_ref, zone, timestamp`) — Hollowkeep's Phase 3 echo system reads it retroactively. (Chs. 2.3, 13.6) |
| 5 | Truth & Light core | Encounter flow (aggro → lie → satchel → super-effective Lightburst / fizzle / glance → resolve), the family type chart, tier-1 family precision, vignette system, Fade path, no-soft-lock generator (server, charge-aware), Ember-sparks wallet + steeple/garden spark store (small launch catalog). Bestiary: Whisperling. Boss framework + the First Shadow. Calm Mode + reduced-flash + read-aloud hooks. (Ch. 2) |
| 6 | Town Book system | The Ch. 3.10 reading-desk flow end to end on the ElevenLabs narration pipeline: chaptered audio, 3 sections per chapter, comprehension questions, memory-verse checks minting serums, XP + fruit payouts, per-town bookmark persistence, recharge-at-the-desk. Ships with one book: **John** at Meadow Town. (Ch. 3.10) |
| 7 | Meadow Town | Full zone: prologue (12–15 min — **the Zohar compassion test and Lantern grant**, first plan day lights it to Flame, starts miss-log), library study, trivia-battle template, Seal 1 + the Lie-Lens, restoration meter + shops-as-service-organs (Berry Market/Rosie's as the model town store), Gloom-stain creep, save transformation (public plots open), **the Eli farewell at the East Gate**, Standing track, secrets. Seal socket + fruit-multiplier (+5%/seal) live. (Ch. 7) |
| 8 | The East Road | The model road in full (Ch. Roads interlude): Milepost Oak, Wren's Crossing, the Low Stones, the Rise; the road-challenge framework (traveler-aid micro-quests, Gloom patrols, waymarker relights, road XP caps), red-bag road spawns, the wayside micro-plot, and the road-warden's frontier camp at the Rise ("River's high past here — come back soon") as Phase 1's graceful edge. (Chs. 3.1, Roads) |
| 9 | Economy pass | XP curve + level-ups (satchel slots), gold sources/sinks live (donation caps, offering box → renown), fruit-as-good rules + public-plot service (Ch. 3.3), level-gate signpost framework (gates themselves populate with their zones), week-3 ledger and ten-week XP ledger re-run against real tuning data. (Ch. 3) |
| 10 | Persistence + trust | Save/sync split (local vs server), optimistic-with-visible-rollback currency, checkpoint resume rules, offline saved-town play, day-night LUT. (Ch. 5.5–5.6) |
| 11 | Safety + oversight | Parent/pastor visibility (play history, serums earned — counts not lie text), report flow, Gentle mode, accessibility baseline (text scale, reduce-motion, colorblind double-coding), analytics events for the funnel (reading → gate → seal). (Chs. 5.9–5.10, 13.6) |

**Exit criteria.** A new player earns the Lantern from Zohar, saves Meadow Town, and walks the East Road to the Rise from a cold start with no designer hand-holding; a lapsed player at Spark still has the garden and (once saved) Meadow Town with zero locked-out owned content; the reading → lantern → Flame gate loop is verified against production reading data; the Town Book flow (audio, questions, memory-verse mint, recharge) round-trips on device; the charge economy holds (a normal session never strands a player serum-less mid-road); both economy ledgers land within their bands; 30 fps floor holds across hub, town, and road on an iPhone 8-class device.

## 18. Phase 2 — the river, the mire, and the first trip

Theme: the world grows teeth, Ember joins the road, and serving together becomes real. Ships Riverbend, Murkmire, combat depth, and the first co-op mission with its lobby.

**Zones.** Riverbend (full: Worry-wisp encounters, Flow Routing — 3 solo puzzles + reset levers, seal arc vs Tomas — first timed trivia, Seal 2 + the Quickstrap, Town Book: Philippians, the Deep Channel level-8 pocket, restoration weights, save transformation + tide-out, Locks gate) → the Levee Trace (road, brief spec) → Murkmire (full trial: Burden Weight + Traveler's Rule flag, Last Dry Table storage, Sinking Causeway, Cart Rescue, prayer stumps, **the Dragon Whistle + Ember-as-traveling-buddy system** — summon/dismiss, the Bogbellow obstacle, the Mirelight Outpost recharge point — Willow Arch / Mire-Mother waves, the Deepwell Vials, Flame entry gate: the game's first brightness gate).

**Systems.**
- Combat depth: bestiary rows two and three (Murmur Pack in its Worry-wisp skin, Heavyback), trial pressure (the 8 s Murkmire timer + weight modifier), glance feedback polish, mastery Bronze/Silver ramps live at scale.
- Ember companion tech: follow AI, shoulder ride, tone-zone silence rule, the two-obstacle interaction verb (scare/burn), Ember button + HUD slot.
- **Mission Trips core:** relay-backed instancing (10 Hz transforms, server-authoritative objectives), **the lobby** (board + join + push flow, launch window, **bot backfill so every trip starts full**), quick-phrase wheel, five-beat spine, drop-in/reconnect + bot-swap rules, weighted workload scaling, mission XP payouts (Ch. 3.1), **Flood Rebuild** (with the co-op two-crank Flow Routing step). Boards live in saved Meadow Town + Riverbend; the visiting-slot rotation ships pointing both boards at Flood Rebuild variants until Phase 3 widens the pool. Renown: lifetime + weekly tracks, Garden League weekly scoring hook (50/50 start), renown-ladder tier 1 (Trip Tracker).
- Wayfarer kits (region consumables), Riverbend rain, second town store + public plots proving the every-town rules.

**Exit criteria.** A new player reaches the Willow Arch from a cold start; the reading → lantern → Murkmire gate loop is verified against production reading data; the Dragon Whistle round-trips (summon, obstacle, dismiss) with Ember's home/away state consistent across sessions; a Flood Rebuild launched by one live player fills with bots and completes; a 4-live-player Flood Rebuild holds 30 fps on an iPhone 8-class device over the live relay; a lapsed player at Spark still has the garden and two saved towns with zero locked-out owned content.

## 19. Phase 3 — the dark middle

Theme: the lantern becomes the central verb, and the group becomes a team. Ships as one arc (Lantern Hollow → Hollowkeep) with the full mission suite.

**Zones.** Lantern Hollow (Lamplighting, brightness tiers surfaced diegetically, Seal 3 + the Keeper's Hood, Town Book: 1 John, the Firefly Grove shade-ivy — the second Ember obstacle, orchard-tunnel shortcut) → Glimmerton (neon `uLanternRadius` shader, Glimmer Games + Tickets, Seal 4 + the Big Sell, Town Book: Ecclesiastes, the Marvelo Matinee level-15 pocket, Glimmer King) → Whisper Gorge (radius-as-resource, waystones, Wickett's reading-shelf recharge, the Choir, Dawnlit Wick) → Hollowkeep (lantern suppression, Echoes consuming the Phase-1 miss-log, Archive recharge, Vault Stair, Keeper duel, Dawnkey + wicket-gate shortcut).

**Systems.**
- Tier 2–3 precision (correct verse; fill-the-word cards) and remaining pressure model.
- Bestiary back half: Glimmermoth, Echo Shade, Lanterneater + escorts, Dreadroot, Hollow Chorus. Bosses: Glimmer King, Warden (+ Calm Mode variants).
- Beacon/Radiant gates go live (unsaved-town Gloom districts; frontier flags staged for Phase 4).
- Missions: VBS Host, Midnight Rescue (dark-flag gate + Torchbearer rule), Kickabout (playable via visiting-slot rotation ahead of its Brightharbor home board); full board rotation; open-slot cross-group lobbies at scale; renown ladder tiers 2–4; Community Garden group content (Renown Arbor, Trip Wall, Raise the Arbor, Naomi).
- Roads: the Fen Boardwalk and Palings Road challenge sets.
- Shortcut preload framework (approach volumes) for the orchard tunnel and wicket-gate.
- Ember-spark cosmetics catalog expansion; Wickworks + Glimmerton shop inventories.

**Exit criteria.** Seals 1–4 completable in sequence; the miss-log round-trips into Hollowkeep echoes; both shortcuts fold the map with no visible spinner; a group can run all four launch-mission archetypes in one week; scare ceiling and Gentle mode audited across the three new dark zones.

## 20. Phase 4 — summit, harbor, source

Theme: receiving light becomes sending it. Closes the loop, ships the finale, and turns on the long-tail systems.

**Zones.** Starcrest (Crook Call, Cald buzzer battle, Seal 5 + Morningstar Oil, Town Book: 1 Peter, the High Fold level-20 pocket, Cragmother, Ledge drop) → Brightharbor (Tide Clock, fog-lane row-out, Sela battle, Seal 6 + the Beacon Prism, Town Book: Acts, Undertow, two-way ferry loop) → Everlight City (Six-Seal Gate, Lantern Row gift economy + Provisioner's Stall, Selah's 18-prompt review, Kindling, the Vigil, commissioning, postgame Town Book: Revelation).

**Systems.**
- Compound two-verse lies and the Kindling spatial layer (Vigil only).
- Ember flight (steeple-to-steeple splines + far-shell LOD), Wicket of the Morning.
- Roads: the Dawnroad and Shepherd's Descent.
- Endgame: Sending Quay mission board + escalated missions (Glimmerton Blackout, Night Watch, Whisper Gorge remnant runs), New Journey+.
- Seasonal architecture: Gloom surges on region edges, Feast Tables + surge-defense meters, Gloryberry endgame sinks, League season resets with monuments.
- Garden League Glowlands division scoring final (garden output + weekly renown), lifetime-renown monuments, pastor CMS celebration summaries.
- Radiant-only optional content (frontier missions, night events) — the only Radiant gates in the game, per the pressure valve.

**Exit criteria.** All six seals + Vigil completable by a daily reader in ~10 weeks at level ~30 (Ch. 3.1 ledger holds); the ferry victory lap renders every saved town lit; a Vigil-complete account can fly, host Sending Quay trips, and start NJ+; all seven Town Books playable end to end with narration; one full seasonal surge cycle rehearsed on staging before the first live season.

---

*End of design bible. Contradictions found in implementation are bugs in this document — fix the document, then the build.*
