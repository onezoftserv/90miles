# Don't Starve Together: reference notes

Don't Starve Together (DST) is Klei's co-op survival game. Players share a world, keep hunger, sanity and health up, craft at stations, sail boats, face seasonal giants, and die into ghosts that teammates can bring back. Of all the games we study it is the closest match to 90 Millas, so on 2026-11-14 the owner made it our fourth reference game, next to Shattered Pixel Dungeon, Brogue CE and DCSS.

DST is proprietary and closed source (Klei). The rules for using it:

- **Ideas and structure only.** Never its code, data, number tables, text, art or the names of its characters.
- **Own words.** Everything here was written by us from the community wiki, dontstarve.wiki.gg, read on 2026-11-14. Nothing is quoted beyond a few words.
- **Numbers are for scale, not targets.** A few figures appear in prose, marked "for comparison". Our numbers come from `docs/GAME_DESIGN.md` and the specs.
- **Character names stay out.** Some wiki page titles are names of DST characters. They appear only as page citations (in the **Wiki** lines or in inline source links) so a reader can find the source, and are never content for us.
- **Cite the page.** Each change's `design.md` names the wiki page for every DST idea it borrows or rejects.

Source caveats:

- Many wiki pages mix the single-player game, its expansions (Reign of Giants, Shipwrecked) and DST. Where a fact comes from the base game or Shipwrecked, the entry says so. Where pages disagree, the entry says that too.
- Some pages could not be read: `Game_Modes`, `PvP` and `Eyebone` returned 404, Klei's support FAQ returned 403, and the Fandom wiki fallback returned 402 and was not used. The wiki's `Multiplayer` and `Endless` pages redirect to the main "Don't Starve Together" page, which is cited instead. Long NPC pages were read only to their first 100k characters, so "the page does not say" does not mean DST lacks it.
- Anything not confirmed on a page we actually fetched is marked **[unverified]**. Keep the flag when you carry a claim into a design.

## How to use these notes

Before designing a mechanic, find its capability section below, read the DST entries and their "For 90 Millas" lines, and open the cited wiki page if you need more. The change's `design.md` then says, beside the three roguelike references, which DST ideas it borrows or rejects and why, citing the wiki page name (for example: "Spoilage page, borrowed: perish time and three freshness stages" or "Wetness/DST page, rejected: slipping tools, because our players are wet most of the time"). The "For 90 Millas" lines are suggestions, not decisions. Any idea that changes a spec or a number needs its own OpenSpec change, and every borrowed rule must still work, be winnable and be tested with exactly 1 player, offline. The names after a capability are its current spec requirements where one exists; a few (such as "chain variants") point at a design area instead.

## survival-meters

### Hunger
- **DST:** Most characters have a 150-point hunger bar that drains about half a bar per in-game day, so a full bar lasts about two days (for comparison, about 9.4 points per real minute). An empty bar drains health until the player eats; the Hunger page gives 1.25 health/s and the Health page about 60/min, so the pages disagree. Some gear multiplies the drain (one belt cuts it to 60%), and sleeping in a tent costs hunger while it restores other stats.
- **Wiki:** [Hunger](https://dontstarve.wiki.gg/wiki/Hunger), [Health](https://dontstarve.wiki.gg/wiki/Health)
- **For 90 Millas** (`survival-meters` Hunger): Keep our split, where thirst is the clock and hunger only caps energy. DST shows that one killing meter is enough when the others feed it. Borrow "an item multiplies a drain" as a data field on items, not as special cases in code.

### Sanity
- **DST:** A 200-point bar. It drains slowly at dusk, at night and in caves (for comparison, about 5/min) and ten times faster in total darkness. Rain and wetness take a little more, and nearby monsters' auras cause big spikes. It comes back from sleep, certain hats, standing near certain structures and eating most pot dishes (a small instant bonus); raw or spoiled food costs a little.
- **Wiki:** [Sanity](https://dontstarve.wiki.gg/wiki/Sanity), [Day-Night Cycle](https://dontstarve.wiki.gg/wiki/Day-Night_Cycle)
- **For 90 Millas** (`survival-meters` Morale; `crafting-inventory` Item resource): Morale already has this shape: a slow drain on lonely nights and big spikes from an ally's death or a squall. Borrow a small instant morale bonus for a cooked or shared meal and a small cost for raw or spoiled food, both as item data.

### Insanity tiers and hysteresis
- **DST:** Effects stack in tiers as sanity falls, so trouble is visible long before it hurts. First the screen loses colour and shakes, then it warps; eyes appear in the dark, whispers and ambient sound start, and harmless critters turn hostile. Only near the bottom do shadow creatures become solid and attack, and that tier uses hysteresis: on at 15%, off again only at 17.5% (for comparison).
- **Wiki:** [Sanity](https://dontstarve.wiki.gg/wiki/Sanity)
- **For 90 Millas** (`survival-meters` Morale): Borrow warning tiers above our hallucination line (for example desaturation near 40, whispers near 30) and a small hysteresis band. The band changes the "fire ends the hallucinations" scenario (15 to 20), so it needs a spec change. Reject the critters-turn-hostile tier: our hallucinations never fake resources or cause harm.

### Shadow creatures
- **DST:** A low-sanity player gets shadow creatures that only they see, faint at first and more solid as sanity falls. Below 15% they turn aggressive, drain sanity hard while near and drop a crafting resource when killed. Killing the basic kind gives some sanity back (+15 per the Crawling Horror page), and a teammate can hit one to draw it off. The pages disagree on when they first appear: below 82.5% on Shadow Creatures, 50% or lower on Sanity. Whether they leave when sanity recovers, and what other players see, is [unverified].
- **Wiki:** [Shadow Creatures](https://dontstarve.wiki.gg/wiki/Shadow_Creatures), [Crawling Horror](https://dontstarve.wiki.gg/wiki/Crawling_Horror)
- **For 90 Millas** (`survival-meters` Cause ids, Morale): Reject hallucinations that attack, since morale may never take health. Borrow "facing the phantom pays": reaching a fake island or answering a fake voice dispels it for a little morale. Showing it only to the affected player fits our model, where the host owns the state and each client draws it.

### Health, healing and sleep
- **DST:** Most characters have 150 health, lost to attacks, bad food, fire, starvation and extreme temperature. Ordinary food heals a little, cooked dishes and healing items more, and sleeping in a tent or lean-to heals fast but drains hunger (for comparison, tent sleep heals about 120 health/min, the best dishes about 60 each).
- **Wiki:** [Health](https://dontstarve.wiki.gg/wiki/Health)
- **For 90 Millas** (`survival-meters` Health and downed state, Hunger): Borrow "sleep heals but costs hunger", so a night in shelter turns hunger into health. That gives hunger a second job without letting it kill. The spec has no health regeneration yet (GAME_DESIGN §4 names rest, aloe and noni), so this is a survival-meters change.

### Pace: how fast the meters drain
- **DST:** For comparison, a DST day is 8 real minutes, sixteen 30 s segments (from the base-game Day-Night Cycle page; the Hunger page's rates agree). A full hunger bar empties in about 16 real minutes, and starvation then takes all 150 health in about 2 minutes. Sanity's slow night drain matters less than darkness, monsters and wetness. The DST day/dusk/night split and how seasons change it are [unverified].
- **Wiki:** [Day-Night Cycle](https://dontstarve.wiki.gg/wiki/Day-Night_Cycle), [Hunger](https://dontstarve.wiki.gg/wiki/Hunger)
- **For 90 Millas** (`survival-meters` Thirst, Hunger, Morale; GAME_DESIGN §4–5): Our thirst empties in about 14 real minutes working in the sun (hunger in about 33, and morale's lonely-night drain takes more than three nights to reach 20), so thirst runs on about DST's hunger clock and the pace looks reasonable. But an empty thirst bar kills in 50 s (2 health/s) with no warning step, against about 2 minutes in DST. Consider a low-thirst warning, a longer window or both, and playtest solo.

### Wetness
- **DST:** A 0–100 wetness gauge, shown only while wet. Rain fills it by intensity (tree cover cuts the gain by about a third), and waves and a leaking boat add more. From 35 up (for comparison), held tools can slip out of the hand, soaked clothes and slippery tools drain sanity, and the player feels colder in proportion (up to 30° colder at full, per the general Wetness page). Wet food spoils 30% faster, wet fuel burns 75% as long, items in containers stay dry, and wet targets take more electric damage. A fire dries the player faster, and rain gear resists by a percentage that stacks up to 100%. The base drying rate is not on the page [unverified].
- **Wiki:** [Wetness/DST](https://dontstarve.wiki.gg/wiki/Wetness/DST), [Wetness](https://dontstarve.wiki.gg/wiki/Wetness), [Rain/DST](https://dontstarve.wiki.gg/wiki/Rain/DST)
- **For 90 Millas** (`survival-meters` Statuses are synced, Heat; `crafting-inventory` Fire, Stashes; `weather-daynight` Effects): Make wetness a synced "soaked" status, not a seventh bar. A swim or a squall sets it; it keeps cooling heat for a while after the player leaves the water (the tropical inversion of DST's chill); and it soaks carried tinder and driftwood, so fires light slower or burn shorter unless the fuel was kept in a sealed jug or cooler. It could also speed spoilage of open food. Reject slipping tools and the wet-clothes morale drain: our players are wet most of the time, so these would fire constantly.

### Temperature: overheating and freezing
- **DST:** Body temperature runs from -20° to 90° and drifts toward the world temperature. Damage starts above 70° or below 0° (for comparison, about 1.25 health/s either way), after a screen-edge warning with a sound near 65° and 5°. Clothing insulation divides the drift rate rather than blocking it, so a good hat buys time, not immunity. Shade helps but is not enough at the height of summer; cooling fires, fans, cold food and wetness push the other way. World temperatures by season are not on the fetched pages [unverified]. The Temperature page is only a disambiguation stub, and the Overheating revision we read is older and marked incomplete for DST.
- **Wiki:** [Overheating](https://dontstarve.wiki.gg/wiki/Overheating), [Freezing](https://dontstarve.wiki.gg/wiki/Freezing)
- **For 90 Millas** (`survival-meters` Heat; `crafting-inventory` Item resource): Borrow a warning (orange screen edge and a sound) near heat 85, before sunstroke. Give hats and tarp shade an insulation value on the item that divides the heat-rise rate instead of zeroing it. Reject a cold side: heat already resets at night, and a second temperature threat does not fit the tropics.

### Thermal Stone: a carried charge
- **DST:** A stone crafted at the advanced station soaks up heat beside a fire, or cold in an ice box or by a cooling fire, then pulls the carrier's temperature toward its own (weighted about two to one over the air; one to one when it lies on the ground). It loses about 1° every 5 s, and its colour shows five charge stages. In DST the stone wears out after about eight full hot-or-cold cycles, losing an eighth each time it returns to neutral, and a sewing kit or tape restores it; the single-player page's never-wears-out does not apply.
- **Wiki:** [Thermal Stone/DST](https://dontstarve.wiki.gg/wiki/Thermal_Stone/DST)
- **For 90 Millas** (`survival-meters` Heat; `crafting-inventory` Item resource): Borrow a carried cooling charge, such as a wet rag or a clay jug dipped in the sea, that slows the heat rise and shows its charge in stages as it dries in the sun. Items cannot hold a charge that decays over time yet, so this needs a new item field.

### Revival by a teammate
- **DST:** A living player crafts a cheap heart that costs them health to make (for comparison, 40) and uses it on a ghost; a ghost cannot use it alone. The reviver gets a large sanity reward. The revived player loses a quarter of max health until a later item restores it, and the main page says these penalties stack to at most 75%.
- **Wiki:** [Telltale Heart](https://dontstarve.wiki.gg/wiki/Telltale_Heart), [Health](https://dontstarve.wiki.gg/wiki/Health), [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together)
- **For 90 Millas** (`survival-meters` Health and downed state; `crafting-inventory` Fresh-water revives): Our fresh-water revive of a downed player already fills this role. Borrow a small morale reward for the reviver, a co-op bonus that solo does not need. Note the stacking max-meter penalty as an alternative to our flat "stand at 30 health", but reject it for normal play, where it clashes with permadeath per run.

### Self-revival: Touch Stone
- **DST:** Stones stand in the world, and a ghost haunts one to come back to life there. Each stone revives each player once and cannot be renewed, and world settings decide how many exist. Revival sets health, hunger and sanity to partial values, and items stay where the player died.
- **Wiki:** [Touch Stone/DST](https://dontstarve.wiki.gg/wiki/Touch_Stone/DST)
- **For 90 Millas** (`survival-meters` Solo last stand, Free revive; `island-generation` POI placement; `content-data`): A rare one-use roadside shrine (an *ermita*) on some islands, usable by a downed player in reach or during a solo last stand, is the most solo-friendly borrow, built as data, not code. Keep it rare so first runs stay brutal.

### Self-revival: Meat Effigy and Life Giving Amulet
- **DST:** The effigy costs health and materials, and it is attuned to one player. After death that player's ghost presses an on-screen button to return at it; it does not fire on its own, works once, and the attunement belongs to one shard. The amulet slowly heals while worn, at a hunger cost, and wears down. It sinks uselessly at sea and has no max-health penalty. The automatic revive at 50 health described on the Health page is the single-player behaviour; in DST a ghost must haunt a dropped amulet.
- **Wiki:** [Meat Effigy/DST](https://dontstarve.wiki.gg/wiki/Meat_Effigy/DST), [Life Giving Amulet/DST](https://dontstarve.wiki.gg/wiki/Life_Giving_Amulet/DST), [Health](https://dontstarve.wiki.gg/wiki/Health)
- **For 90 Millas** (`survival-meters` Free revive; `crafting-inventory`; `crossing`): The Medalla de la Caridad already is a pre-paid, personal, one-use revive. Borrow "pay now in a meter to buy a revive later" only if a craftable one is wanted, and reject the manual button, since ours fires at 0 health. The "sinks at sea" rule is thematic: a revive charm could fail on a crossing and work only on land, raising the stakes at sea without touching solo winnability on islands.

### Portal revival and the max-health penalty
- **DST:** When the server allows it (standard in Endless and Relaxed), ghosts can revive at the spawn portal as often as they like, at the cost of a quarter of max health each time, capped at 75%; a medical item restores it. The pages disagree on Relaxed: one says it costs max health, the other says it is free.
- **Wiki:** [Florid Postern](https://dontstarve.wiki.gg/wiki/Florid_Postern), [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together)
- **For 90 Millas** (`endings-progression` Challenges, Difficulty baseline): Reject unlimited revives, since permadeath per run is core. A capped, stacking max-meter penalty is the right tool if a lenient "challenge off" option is ever added.

Also see: ghosts and the all-dead countdown (coop-networking), falling overboard (crossing), spoilage and cooking (crafting-inventory).

## weather-daynight

### Day, dusk and night clock
- **DST:** A day is a ring of 16 equal segments of 30 real seconds, 8 minutes in all (for comparison). The HUD clock colours the segments by phase, so players see at a glance how much light is left. Dusk dims the world but needs no light; night is fully dark. Seasons move the phase boundaries but keep the day length, and DST caves run on the surface clock. No fetched page gives DST's per-season segment counts [unverified]; the Day-Night Cycle page says it lacks DST details.
- **Wiki:** [Day-Night Cycle](https://dontstarve.wiki.gg/wiki/Day-Night_Cycle), [Time](https://dontstarve.wiki.gg/wiki/Time)
- **For 90 Millas** (`weather-daynight` Day cycle; `inventory-hud`; `ui-shell` HUD layout): Borrow the segmented clock face as the HUD readout of `WeatherManager`'s clock: phase wedges plus "time until dark". Our fixed 12-minute day, split 1/5/1/5, already follows the fixed-total idea.

### Darkness and the night attacker
- **DST:** Standing in complete darkness starts a hidden timer. The character speaks an alarmed line and a loud whoosh plays, then an unseen attacker hits hard and keeps hitting until the player dies or finds light (for comparison: about 100 health and 20 sanity per hit, the first 5–10 s after the light goes, then one every 5–11 s). Any light resets it: fires, carried lights, glowing creatures, a full moon; night vision gives immunity. In total darkness most actions are blocked except placing a fire, and sanity drains fast (the base-game section gives about 50/min in the dark against 5/min near light; the DST figure is [unverified]).
- **Wiki:** [Charlie/Darkness](https://dontstarve.wiki.gg/wiki/Charlie/Darkness), [Charlie](https://dontstarve.wiki.gg/wiki/Charlie), [Darkness](https://dontstarve.wiki.gg/wiki/Darkness), [Night](https://dontstarve.wiki.gg/wiki/Night)
- **For 90 Millas** (`weather-daynight` Day cycle; `survival-meters` Morale; `guardacostas-stealth` Searchlight, Triggers): Borrow the rule's shape (no light at night, then a warning, then an escalating penalty), not the monster: a night without fire blocks crafting and foraging, drains morale and draws crabs and crocodiles. Keep our twist that fire and smoke show to patrols, so light is a trade-off rather than pure safety. Reject heavy instant health hits; they are too harsh for solo.

### Seasons
- **DST:** A 70-day year has four seasons: two mild ones of 20 days and two harsh ones of 15 (for comparison). Autumn is the default, gentlest start; each later season brings one dominant hazard (cold, soaking rain, or heat with wildfires) plus a giant. Season length is a world setting from very short (5 days) to very long. Warnings are soft: a crafted thermometer drifts as a season nears. Winter has long dusks and nights, so sanity cannot fully recover in its short day. Whether the split shifts gradually through a season is [unverified].
- **Wiki:** [Seasons/DST](https://dontstarve.wiki.gg/wiki/Seasons/DST), [Seasons](https://dontstarve.wiki.gg/wiki/Seasons), [Autumn](https://dontstarve.wiki.gg/wiki/Autumn), [Winter](https://dontstarve.wiki.gg/wiki/Winter), [Thermal Measurer](https://dontstarve.wiki.gg/wiki/Thermal_Measurer)
- **For 90 Millas** (`weather-daynight` Weather states, Calm and squall data): Reject full seasons; a run lasts days, not a 70-day year. Borrow the ramp from a mild opening to harsh stages with one dominant hazard each, through the per-chain roll weights in `WeatherData` (early islands lean calm or trade wind, later stages squall or fog). Optionally lengthen dusk and night per stage in `day_cycle.tres`.

### Rain as a moisture accumulator
- **DST:** Rain is not rolled each hour. A hidden world moisture value climbs each second at a season-dependent rate until it reaches a rolled ceiling; it then rains at a rolled peak intensity until moisture drains to a rolled floor, which spaces rain out naturally. Moisture starts at zero with a low first ceiling, so a fresh world stays dry for a day or two. By season: spring rains are long and come often, winter brings brief showers often, and summer rain is rare but always a downpour. A crafted gauge showing moisture between floor and ceiling works as a forecast. Rain burns fire fuel much faster (for comparison, up to about 3.5× for a campfire in a downpour) and speeds crops. A world setting scales the rate, turns rain off or makes it permanent.
- **Wiki:** [Rain/DST](https://dontstarve.wiki.gg/wiki/Rain/DST), [Rain](https://dontstarve.wiki.gg/wiki/Rain)
- **For 90 Millas** (`weather-daynight` Weather states, Effects, Weather sync; `crafting-inventory` Water structures): Borrow the accumulator: a host-side "pressure" value that rises each phase and triggers a squall at a rolled threshold. Squalls then never come back to back, one is guaranteed eventually, and it syncs as one number with rate and thresholds from data. Also borrow a dry first day (no squall in a run's first phases, which helps solo), rain filling the rain catcher, faster fuel drain in light rain as a step before the squall's put-out-the-fire rule, and an optional barometer item.

### Lightning
- **DST:** Lightning comes only with heavy rain (intensity above about 0.75), so it is common in stormy seasons and rare in mild ones. A strike check runs every 30–80 s; a rod within about 10 tiles draws the strike, otherwise it lands near the player and can ignite flammables close by. A bolt that hits a player deals 10, and a soaked player can take up to twice that (for comparison); insulated clothing blocks it. A world setting makes it rarer or much more frequent.
- **Wiki:** [Rain/DST](https://dontstarve.wiki.gg/wiki/Rain/DST), [Lightning](https://dontstarve.wiki.gg/wiki/Lightning) (a base-game article; the DST figures come from Rain/DST)
- **For 90 Millas** (`weather-daynight` Effects, Hurricane boss; `crossing`; `crafting-inventory`): Borrow lightning only at the peak of a squall or the hurricane, telegraphed by a flash before the strike, and rare in solo. Our own idea, not DST's: strikes favour the raft's mast, so lowering the sail or rigging a grounding wire becomes a choice.

### Moon phases
- **DST:** A 20-day moon cycle shows as an icon beside the clock (the base-game page gives 16 days). The full moon lights the night enough to move without fire, transforms some creatures, changes certain plants and structures and regrows special resources; the new moon lasts one day and opens a few rare interactions. Late-game events can hold the moon at full until resolved. In Shipwrecked the full moon makes waves bigger and the new moon removes beach tides.
- **Wiki:** [Moon Cycle/DST](https://dontstarve.wiki.gg/wiki/Moon_Cycle/DST), [Moon Cycle](https://dontstarve.wiki.gg/wiki/Moon_Cycle), [Waves](https://dontstarve.wiki.gg/wiki/Waves)
- **For 90 Millas** (`weather-daynight` Day cycle, Tides; `guardacostas-stealth` Searchlight): Borrow a moon icon and a short cycle (a few days, so a run sees one full moon) tied to tides, with full and new moon exposing more reef. Full-moon nights need less fire but let patrols see you more easily. Reject the supernatural transformations.

### Storms at sea (from Shipwrecked)
- **DST:** On the fetched pages the DST ocean has no weather-driven sea storms: waves come only from certain sea creatures, push floating items and soak a player a little (9 wetness, for comparison). Whether DST has any sea storm at all is [unverified]. The real reference is Shipwrecked, Klei's single-player sea expansion. Its 16-day hurricane season has storms that build through stages (dimming sky, rising wind, rain and hail, lightning closing in to a peak) and then fade. Wind changes movement speed, blows out ordinary fires and uproots plants, and big waves replace small ones as the season goes on. Waves share one heading that changes each night: hitting one side-on soaks you and damages the boat, riding along one gives a speed boost. Wind-proof fire pits exist.
- **Wiki:** [Waves](https://dontstarve.wiki.gg/wiki/Waves), [Hurricane Season](https://dontstarve.wiki.gg/wiki/Hurricane_Season), [Seasons](https://dontstarve.wiki.gg/wiki/Seasons)
- **For 90 Millas** (`weather-daynight` Weather states, Hurricane boss; `crossing`; `crafting-inventory` Fire): Borrow the staged storm (build-up, peak, ease-off) inside the squall's 120 s and the hurricane night; waves with a heading that riders steer into to avoid raft damage or ride for speed; and a craftable wind-proof brazier as the one exception to "a squall puts out fires".

### Regional storms
- **DST:** Some storms cover one area. A summer sandstorm in one desert shrinks vision to a small circle and slows walking by 60% (for comparison); rain stops it until the ground dries, and goggles cancel both penalties. A late-game storm sits over a random area for 5–6 days, cutting vision and speed, blocking the inventory and bringing frequent lightning until a quest ends it, with map icons marking where it is.
- **Wiki:** [Sandstorm](https://dontstarve.wiki.gg/wiki/Sandstorm), [Moonstorm](https://dontstarve.wiki.gg/wiki/Moonstorm)
- **For 90 Millas** (`weather-daynight` Weather states (fog); `guardacostas-stealth`; `crossing`): Borrow weather that has a place: fog banks or squall cells on part of the sea map that players can sail around, or hide in from patrols, with a gear counter such as a diving mask.

Also see: wetness (survival-meters), wildfires (crafting-inventory), timed attack waves and their shrinking warnings (creatures-ai).

## coop-networking (and net-platform)

`net-platform` is not a spec capability in this repo yet. Platform, relay and account ideas below map to `coop-networking` and to the v2 task "Steam/relay joining" in `TASKS.md`.

### Client-hosted and dedicated servers
- **DST:** Players host from inside the game or run a headless dedicated server; both use the same networking, and a standalone server keeps the world running with nobody online. If a direct connection fails, the game tries NAT traversal and then a relay. Online servers need a cluster token tied to the owner's Klei account, which becomes the default admin; offline and LAN-only servers skip the token. The tick rate can be set from 15 to 60, and the guide recommends the default of 15 (for comparison).
- **Wiki:** [Dedicated Server](https://dontstarve.wiki.gg/wiki/Dedicated_Server) (the guide "Guides/Don't Starve Together Dedicated Servers"), [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together)
- **For 90 Millas** (`coop-networking` Host and join; v2 "Steam/relay joining"): Borrow the shape: one transport behind the factory, with a relay used only when direct ENet fails, not as a replacement for it. Reject a headless dedicated server: runs are short and there is no persistent world. Solo keeps the offline peer with no port.

### Server browser, visibility and passwords
- **DST:** A "Friends Only" option limits joining to the host's Steam friends (verified on the main page). A "Browse Games" list with search, filters and passwords for locked servers is described only in hosting guides [unverified]. So is a server-intention tag (cooperative, social and so on), which one guide says was later removed [unverified].
- **Wiki:** [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together) (Friends Only only)
- **For 90 Millas** (`ui-shell` Join screen, Lobby; v2 "Steam/relay joining"): v1 joins by IP, which is fine. For v2, a friends-only invite through the platform beats a public browser for a 4-player co-op game. Skip intention tags. Solo never sees any of this.

### Max players
- **DST:** The dedicated-server player setting accepts 1 to 64 (for comparison). The default cap and the in-game host's limit could not be confirmed [unverified].
- **Wiki:** [Dedicated Server](https://dontstarve.wiki.gg/wiki/Dedicated_Server)
- **For 90 Millas** (`coop-networking` Host and join, Difficulty scaling): Keep our hard cap of 4. DST's big lobbies only work because its world is persistent and sprawling; our scaling and seat rules assume 1 to 4.

### Arrival portal and character select
- **DST:** Every world has one spawn portal on the surface and one in the caves. Everyone starts there, the surface portal always sits on grass, and players who join later step out of the same portal with a short glow. A character is picked when a player first enters a world [unverified as a stated rule; the select screen is confirmed by the commands and portal pages]. An upgraded portal lets a player go back to character select by offering an idol: their inventory drops, while day count, map and learned recipes are kept and their Touch Stone uses reset.
- **Wiki:** [Florid Postern](https://dontstarve.wiki.gg/wiki/Florid_Postern), [Celestial Portal](https://dontstarve.wiki.gg/wiki/Celestial_Portal), [Spawn Biome](https://dontstarve.wiki.gg/wiki/Spawn_Biome)
- **For 90 Millas** (`coop-networking` Spawning, Join request; `ui-shell` Screen flow): Borrow a fixed, readable arrival point for joiners with a small client-side flourish, for example landing at the island's beach spawn point with a splash. Reject mid-run character swaps: we have no classes and runs are short. Scattered landing at run start stays (see island-generation).

### When a player disconnects
- **DST:** The intended behaviour seems to be that the server saves a leaving player's character, inventory included, takes it out of the world and puts it back on rejoin [unverified]. Klei bug-tracker threads, seen in search only, treat losing a character on rejoin as a bug, which suggests that design [unverified]. Verified: the admin despawn command sends a player back to character select and deletes their items, so the docs advise dropping or killing first.
- **Wiki:** [Console/Don't Starve Together Commands](https://dontstarve.wiki.gg/wiki/Console/Don%27t_Starve_Together_Commands)
- **For 90 Millas** (`coop-networking` Disconnect handling, Reclaiming a player): Our rule (a downed body for 90 s, then removal with the inventory dropped at the last position) is harsher but fits permadeath runs; keep it. The DST lesson is never to delete a leaver's items, and we already drop them. Solo has no client to drop.

### Caves as a second shard
- **DST:** Caves are a separate world layer that runs as its own server process (shard) beside the surface "master" shard in the same cluster, switched on when the server is created; before a later update only dedicated servers could run them. Some state is per shard: an effigy attuned on the surface cannot revive someone who died in the caves until their ghost walks back up.
- **Wiki:** [Dedicated Server](https://dontstarve.wiki.gg/wiki/Dedicated_Server), [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together), [Caves](https://dontstarve.wiki.gg/wiki/Caves), [Meat Effigy/DST](https://dontstarve.wiki.gg/wiki/Meat_Effigy/DST)
- **For 90 Millas** (`coop-networking`; `crossing`): Reject shards: one host simulates one island or crossing at a time. Keep the lesson: no per-area state that strands a revive or an item when players split up.

### PvP toggle
- **DST:** PvP is an optional server setting. With it on, some tools affect other players too, such as a flute that puts them to sleep. Off by default [unverified]; the PvP page returned 404.
- **Wiki:** [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together)
- **For 90 Millas** (`coop-networking`; `creatures-ai`): Reject PvP. It works against the "nobody gets left behind" tone and our ending flags.

### Server settings, admin and votes
- **DST:** Operators set the playstyle, PvP, Friends Only, chat scope (global or local whisper) and world generation options; admin, whitelist and blocklist files sit at cluster level. Admins can kick or ban from the scoreboard or the console and post announcements before restarts. Non-admins can call votes to kick, roll back or regenerate the world, and a cluster setting turns votes off [unverified]. Forum threads complain that regenerate votes get used for griefing [unverified].
- **Wiki:** [Dedicated Server](https://dontstarve.wiki.gg/wiki/Dedicated_Server), [Console/Don't Starve Together Commands](https://dontstarve.wiki.gg/wiki/Console/Don%27t_Starve_Together_Commands), [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together)
- **For 90 Millas** (`ui-shell` Lobby; `coop-networking` Host authority): Borrow a host-only kick in the lobby and during the run, so a bad joiner cannot hold a seat. Reject votes: four friends need no voting. Solo shows none of this.

### Crossplay and platform accounts
- **DST:** The game ships on Windows, Mac, Linux, PlayStation 4/5, Xbox One/Series, Switch, Android and iOS (verified), and a Klei account carries server tokens and admin ids (verified). Whether players on different platforms can share a world is unclear: guides disagree, and most say consoles stay on their own platform [unverified]. Unlocks can be shared across platforms by linking accounts to a Klei account [unverified; the Klei FAQ was blocked].
- **Wiki:** [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together), [Dedicated Server](https://dontstarve.wiki.gg/wiki/Dedicated_Server)
- **For 90 Millas** (`coop-networking` Player identity; `endings-progression` Keepsakes; v2 "Steam/relay joining"): Our per-install id and secret is the right v1 stand-in for an account. Keep profile progress (keepsakes, Experiencia) local, decide only in v2 whether a platform id replaces the install id, and reject a custom account service, since v1 has no backend.

### Rollback and autosave
- **DST:** Servers autosave when night ends, so about once per in-game day. Admin commands roll the world back a given number of saves, force a save, reload without saving, or shut down with or without saving. How many saves are kept is configurable, with a default near 6 [unverified].
- **Wiki:** [Console/Don't Starve Together Commands](https://dontstarve.wiki.gg/wiki/Console/Don%27t_Starve_Together_Commands)
- **For 90 Millas** (`endings-progression`; `coop-networking` Pause): Reject player-facing rollback; it breaks permadeath stakes. A save at each island arrival, used only to resume after a host crash, could be a later save-and-quit change; today save-and-quit is out of scope.

### Host pause
- **DST:** Admins and local hosts can pause the shared game with a hotkey, and opening menus, the map or the console can pause it automatically. Whether auto-pause applies only when playing alone is [unverified].
- **Wiki:** [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together)
- **For 90 Millas** (`coop-networking` Pause): We chose no pause in co-op. DST shows that a host-only pause with a clear on-screen banner works in real-time co-op survival; reconsider it if playtests show real-life interruptions hurt runs. Solo pause stays as specced.

### Ghost form and haunting
- **DST:** A dead player becomes a ghost that can fly anywhere, gives off a little light and can haunt things. Haunting has mixed effects (some help, some backfire, many creatures panic), with a short cooldown per target. Ghost speech comes out garbled and ghosts do not reveal the map. Each ghost slowly drains the living players' sanity (for comparison, about 3.3 per minute each, capped at 10 per minute in total), which pushes the team to revive. The dead player's inventory drops where they died, marked by a skeleton.
- **Wiki:** [Ghost Characters](https://dontstarve.wiki.gg/wiki/Ghost_Characters), [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together), [Death/DST](https://dontstarve.wiki.gg/wiki/Death/DST)
- **For 90 Millas** (`coop-networking` Quick chat; `ui-shell` Screen flow; `survival-meters` Morale): No spec says what a dead co-op player sees or does while the others play on. Borrow at least a spectate camera that follows a living teammate and keeps quick chat, a morale drain on the living per dead teammate, and optionally a light *ánima* with one or two harmless nudges (pointing, a bubble). Reject full haunting as too much scope. A dead player's items left as a marked pile teammates can recover would need its own change. Solo: not applicable, because the run ends.

### When everyone is dead
- **DST:** In Survival mode, when the last living player dies, a 120 s grace timer runs (for comparison); a revive in time saves the world, otherwise it is discarded and a fresh one is made. A server restart puts the timer back to full, and Endless mode never wipes the world.
- **Wiki:** [Ghost Characters](https://dontstarve.wiki.gg/wiki/Ghost_Characters), [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together), [Death/DST](https://dontstarve.wiki.gg/wiki/Death/DST)
- **For 90 Millas** (`endings-progression` Run summary, Restart from the summary; `ui-shell` Screen flow; `survival-meters` Solo last stand): Our "all dead, then run summary, then a new run" matches. DST's grace window exists only because ghosts can still self-revive; ours is the downed timer or the last stand, so add nothing.

Also see: playstyles (npcs-dialogue and endings-progression), threats scaled per player with a grouping discount (creatures-ai, hound waves).

## crossing and escape-routes

### Boat building
- **DST:** A flat-pack kit crafted from boards is dropped on the water and becomes a round deck that holds several players and structures and can bridge short gaps between land. Masts, a wheel, an anchor and other parts are separate kits placed on the deck. Variants change the rules: a cheap grass raft has half a boat's durability and sinks slowly all the time, and an ice boat sinks fast.
- **Wiki:** [Boat](https://dontstarve.wiki.gg/wiki/Boat), [Floating Platform](https://dontstarve.wiki.gg/wiki/Floating_Platform)
- **For 90 Millas** (`escape-routes` Shared crafting, Raft build site; `crossing` Vessel integrity): The deck-as-build-site idea is already covered. Borrow the grass raft's constant slow sinking as a vessel data flag (`sink_per_s`) for a cheap emergency raft that can be crossed solo but leaves no margin for error. Reject placing parts piece by piece: a route `.tres` keeps naming a finished vessel.

### Boat health and leaks
- **DST:** A boat has one health meter (for comparison, 200 for the standard boat). Collisions and attacks take a chunk and can also open a leak, which keeps draining the meter until it is plugged (for comparison, 0.5/s for a small leak, 1/s for a large one). At zero the boat sinks, everything built on it is lost, and everyone aboard drowns. Edge bumpers reduce collision damage. A creature from the salt shoals jumps aboard and drills a hole in about 3 s, unless it is killed or distracted first.
- **Wiki:** [Leak](https://dontstarve.wiki.gg/wiki/Leak), [Cookie Cutter](https://dontstarve.wiki.gg/wiki/Cookie_Cutter)
- **For 90 Millas** (`crossing` Raft integrity on the crossing, Threat plan; `creatures-ai` Behavior state machines): Our raft takes discrete hits only (-30 squall, -20 shark, -40 rock). Borrow a leak state: some hits (rock, shark) also start a per-second drain that any rider stops with a short hold. That gives a lone rider a job and makes patching compete with the squall's tie-down while staying solo-winnable. Borrow the "stop it before it finishes" window for a crossing threat.

### Patches
- **DST:** Patching is separate from repair. A patch closes a leak and adds back a little health (for comparison, 25). The Leak page lists boards and logs only as hull repair; whether they can close a leak is [unverified]. A patch made from seaweed fronds plugs a leak only for a few minutes, and a collision can knock it out early.
- **Wiki:** [Boat Patch](https://dontstarve.wiki.gg/wiki/Boat_Patch), [Kelp Patch](https://dontstarve.wiki.gg/wiki/Kelp_Patch), [Leak](https://dontstarve.wiki.gg/wiki/Leak)
- **For 90 Millas** (`crossing` Tying down; `crafting-inventory` Recipes): Two recipe `.tres` items: a proper patch (tar or resin with a rag) that stops a leak for good, and a cheap plug (sargassum, a shirt) that holds for a set number of seconds. Holding the patch must take less than the 60 s squall warning, so a lone rider can patch and still tie down.

### Masts and sails
- **DST:** An open mast pushes the boat steadily the way it faces, and each extra mast adds less than the one before. Raising and lowering the sail is a timed two-step click, and badly timed clicks make it slower; a lighter sail opens slowly but closes fast, which makes stopping easier. The mast page describes no wind system [unverified that DST sailing has no wind at all]. A flying boss can break masts.
- **Wiki:** [Mast](https://dontstarve.wiki.gg/wiki/Mast)
- **For 90 Millas** (`escape-routes` Weather gating; `crossing` Threat scripts): Our tarp sail tied to the trade wind suits us better than windless thrust; keep it. Borrow the timed furl for cutting the sail to go dark under the searchlight: a short rhythm action one player can do alone, where fumbling costs time. Reject mast stacking.

### Oars
- **DST:** Rowing pushes the boat a little in the direction the player chooses, slower than a sail (for comparison, an oar's top speed of 2 against a mast's added 2.5). Each stroke has a cooldown; rowing again too early splashes the rower and costs extra oar durability. Whether an oar can be dropped by mistake is [unverified].
- **Wiki:** [Oar](https://dontstarve.wiki.gg/wiki/Oar)
- **For 90 Millas** (`crossing` Steering and current): Drift is cut just by being aboard, with no held station, and that should stay because it keeps solo viable. An optional rhythm row could cut drift a little more, with off-beat rowing costing energy rather than durability. Oars are already a repair-wreck route input (GAME_DESIGN §7).

### Anchor
- **DST:** Lowering the anchor stops drift, though an open sail still creeps the boat along. Lowering is quick; raising takes longer the deeper the water (for comparison, about 2 s near the coast up to about 10 s in the deepest ocean). Removing a placed anchor leaves a leak. How many players can work it is [unverified].
- **Wiki:** [Anchor](https://dontstarve.wiki.gg/wiki/Anchor)
- **For 90 Millas** (`crossing` Crossing length): Reject. A crossing has a fixed length, drift never makes it longer, and nothing on it needs a held position.

### Steering wheel
- **DST:** A deck wheel turns every mast together, so it only matters with a mast up; a pirate bandana makes boat actions and wheel turns faster. Whether using the wheel locks the player in place is [unverified]: the wheel's own page is thin, and the masts-turn-together detail comes from the Mast and Floating Platform pages.
- **Wiki:** [Steering Wheel](https://dontstarve.wiki.gg/wiki/Steering_Wheel), [Floating Platform](https://dontstarve.wiki.gg/wiki/Floating_Platform)
- **For 90 Millas** (`crossing` Steering and current): Reject a manned wheel that pins one player in place, since a lone rider must also tie down, patch and climb back aboard. Navigation skill, a Maestro or a compass with charts can stay passive drift cancels, the way the bandana is a passive speed-up.

### Falling overboard
- **DST:** Players do not swim. Falling in (the platform sinks or breaks, or a player walks the plank to abandon ship) counts as drowning: the player is moved to the nearest coast with health, hunger and sanity each cut (for comparison, 25 each, never below 30), full wetness, the held item and about a fifth of the inventory dropped, and the backpack kept. In shallow water the stat and wetness penalties are about a third as large and fewer items drop (about a seventh of the inventory), and a float item prevents the stat loss but not the item loss. That free swimming is impossible in every case is [unverified]: the pages read say only that the ocean is reached by boat.
- **Wiki:** [Drowning](https://dontstarve.wiki.gg/wiki/Drowning), [Ocean/DST](https://dontstarve.wiki.gg/wiki/Ocean/DST)
- **For 90 Millas** (`crossing` Falling in, Rescue timing on the crossing; `survival-meters` Cause ids): DST's version is a soft, non-lethal setback, much gentler than our `drowning` at 0 energy. Reject the teleport to shore: swimming alongside and climbing back in within 3 s is our tension, and it already works solo. A crossing should stay deadly. Worth weighing: the softer rule for shallows and reef paths only, losing the held item when thrown in, and a float item (an inner tube) that cancels the 10-energy fall-in cost.

### Waves and rogue waves
- **DST:** No ambient rogue-wave hazard was found for DST [unverified]. The Waves page lists DST waves as made only by creatures (a flying boss, a sea mammal and its horn, a swamp gator, the crab boss), and the code name `rogue_wave` appears there unexplained. A DST wave wets a player it hits and pushes floating items, and boss wave rings push whole boats. Wave damage to DST boats is not stated; the damage figures on that page are for Shipwrecked.
- **Wiki:** [Waves](https://dontstarve.wiki.gg/wiki/Waves), [Malbatross](https://dontstarve.wiki.gg/wiki/Malbatross)
- **For 90 Millas** (`crossing` Threat plan, Squall line on the crossing): The warned squall already does this job. If a wave event is added, borrow "push, not damage": a visible swell, warned a few seconds ahead, that adds lateral drift and wets riders, with no hidden integrity loss.

### Sea stacks
- **DST:** Stationary rock pillars, packed more densely in deeper water until boats can barely pass. A boat that hits one loses health, and a fast boat breaks things it rams. Stacks can be mined for rock (some of it sinks), and bumpers and a captain's hat soften collisions.
- **Wiki:** [Sea Stack](https://dontstarve.wiki.gg/wiki/Sea_Stack), [Leak](https://dontstarve.wiki.gg/wiki/Leak)
- **For 90 Millas** (`crossing` Threat plan, Raft integrity on the crossing): Show the rock (-40) as an obstacle the scrolling sea brings in, warned a moment ahead, that riders can steer around (weakly when solo) instead of a pure roll. A lashed-tire bumper upgrade, as data, that lowers rock damage fits the raft build site.

### Sea weed and bull kelp
- **DST:** Sea weed is a plant-like creature growing in clusters in the roughest water. Its pollen draws fish or spawns a spitting fish, its projectiles hurt players, and missed shots can hole the boat. Hitting one wakes its neighbours, though they stay asleep at night, and its barnacles regrow for repeat harvests. Bull kelp grows near the coast, can be picked from a boat, regrows in about three days and gives the fronds for the temporary patch.
- **Wiki:** [Sea Weed](https://dontstarve.wiki.gg/wiki/Sea_Weed), [Bull Kelp](https://dontstarve.wiki.gg/wiki/Bull_Kelp)
- **For 90 Millas** (`crossing` Threat plan; `creatures-ai` Behavior state machines `static_hazard`, `drift_trap`): A sargassum mat event that slows the raft or hides a man o' war, and can be picked for the temporary plug. Borrow "a cluster wakes when one is hit" for reef hazards. Reject a plant with a ranged attack.

### Messages in bottles and sunken treasure
- **DST:** Bottles appear in the sea about 10 tiles from players every day or two. Until a player has met the hermit, they point to her island or hold a plain note; after that a bottle usually marks a sunken chest on the map (for comparison, 60% of the time, up to 10 active markers), and after a related quest every bottle does, up to the same cap. The hermit's page says the empty bottle is her shop's currency. The chest is raised with a winch built on a boat and hammered open, and its loot is fixed when it spawns. How lifting the chest feels to the carrier is [unverified].
- **Wiki:** [Message in a Bottle/DST](https://dontstarve.wiki.gg/wiki/Message_in_a_Bottle/DST), [Sunken Chest](https://dontstarve.wiki.gg/wiki/Sunken_Chest), [Pinchin' Winch](https://dontstarve.wiki.gg/wiki/Pinchin'_Winch), [Crabby Hermit](https://dontstarve.wiki.gg/wiki/Crabby_Hermit)
- **For 90 Millas** (`escape-routes` Route discovery, Sandbar route discovery; `npcs-dialogue` Found texts): Let some bottle notes also reveal a route, a POI or a wreck to salvage on the island map, with the reveal sequence fixed by the run seed so the host decides it. Borrow the empty bottle as a trade good, and loot fixed at spawn, which suits host authority.

Also see: the hermit's favours and the crab boss (npcs-dialogue), the sea-bird boss, pirate raids and fishing (creatures-ai), the sea graded by distance and islands found from the coast (island-generation).

## creatures-ai

### Passive, neutral and hostile
- **DST:** Mobs fall into three groups. Hostile ones attack whatever is near, neutral ones leave you alone until provoked (usually by an attack), and passive ones never fight back and tend to flee. Disposition is a property of the creature, and its behaviour (flee, defend, chase) follows from it. The Mobs page has no separate boss category and does not cover aggro range or retargeting.
- **Wiki:** [Mobs](https://dontstarve.wiki.gg/wiki/Mobs)
- **For 90 Millas** (`creatures-ai` Creature resource): Borrow a `disposition` field (passive, neutral, hostile, conditional) on the creature `.tres`, next to the behavior id. Gulls are passive thieves, crabs neutral (they pinch only when you stay next to them), and the reef shark conditional (it strikes only a target that is bleeding or below 20 energy).

### Birds landing and scattering
- **DST:** Birds fly in, peck the ground for a moment and leave, only during day and dusk. The ground decides which species land, seeds draw them in, and they avoid spider webbing. A bird flees when a player or most mobs come close and will not land within melee range; killing one sends the birds near it up. An ocean-only bird follows the same rules and never lands on boats or steals fish, and a worn feather item makes birds come more often. No per-player count or maximum is given [unverified].
- **Wiki:** [Birds](https://dontstarve.wiki.gg/wiki/Birds), [Crow/DST](https://dontstarve.wiki.gg/wiki/Crow/DST), [Puffin](https://dontstarve.wiki.gg/wiki/Puffin)
- **For 90 Millas** (`creatures-ai` Seagull swoop and steal; `guardacostas-stealth` Triggers): Borrow the group scatter (shoo one gull and the rest of its nest flee too, a stronger shoo for a lone player) and "no swoop within N tiles of a player facing it" as another way to guard food solo. Our own idea, not DST's: a flock taking off fires a small `noise` event near nest palms. That needs a spec change and a 1-player test.

### Thieves
- **DST:** Monkeys take items from the ground and from containers and harvest crops. When a player kills one, every monkey nearby drops its loot and runs home (a kill by a follower or another mob does not count), and at night they turn hostile. A punishing visitor comes from a hidden per-player "naughtiness" score raised by killing harmless animals, warned by a hiss near the limit; it smashes ordinary chests and grabs loose items, never takes from the carried inventory, and some containers (the ice box) resist it. Frogs knock one item out of the first inventory slot per tongue hit. A food-hunting giant smells food even inside chests, growls the first two times a player picks up food it was going for and attacks on the third; dropping food calms it.
- **Wiki:** [Splumonkey/DST](https://dontstarve.wiki.gg/wiki/Splumonkey/DST), [Krampus/DST](https://dontstarve.wiki.gg/wiki/Krampus/DST), [Frog/DST](https://dontstarve.wiki.gg/wiki/Frog/DST), [Bearger/DST](https://dontstarve.wiki.gg/wiki/Bearger/DST)
- **For 90 Millas** (`creatures-ai` Land crab night theft, Seagull swoop and steal; `crafting-inventory` Stashes): Borrow theft-proof containers (a lidded cooler or closed crate crabs cannot open), "hit one and the rest drop their loot and flee" for the `night_thief` group, and two growls before an attack as the tell before a crab pinch. Reject the hidden naughtiness score: its punishment is invisible and it does not fit our tone.

### Hound waves: timed attacks with a warning
- **DST:** Every several days a wave of hounds spawns a short way from each player. Growls that grow louder announce it, together with character comments, and the warning usually sounds more than once. The warning shrinks and the pack grows as the world ages (for comparison, 120 s and 2 hounds early, 30 s and 7–10 late). In multiplayer, timing follows the server's mean player age, each player's own survival time sets how many come for them, and a tight group draws a smaller total than a spread-out one. Late waves add fire and ice variants, hounds can swim, and the caves use a different wave creature. How a wave splits between players is not described [unverified]; the survival guide mostly covers leading hounds into other mobs, trap fields and walls.
- **Wiki:** [Hound/DST](https://dontstarve.wiki.gg/wiki/Hound/DST), [Guides/Hound Wave Survival Guide](https://dontstarve.wiki.gg/wiki/Guides/Hound_Wave_Survival_Guide)
- **For 90 Millas** (`guardacostas-stealth` Patrol route; `creatures-ai` Land crab night theft; `coop-networking` Difficulty scaling; `weather-daynight` Hurricane boss): Borrow the rising audio warning with a lead time that shrinks across the run: the patrol's 20 s horizon warning from coast to mid chains, a motor sound that swells before the boat appears, and the same for the hurricane. Borrow threat counts scaled per player with a discount for grouping. Solo gets the base amount, since one player is always grouped.

### Spider dens
- **DST:** A den grows through three tiers over several days each (for comparison, 3, 6 and then 9 spiders, tougher from tier two), and a full den can become a queen who plants new dens nearby. Spiders come out at dusk and go home at dawn. Attacking the den releases them, and a dead spider is replaced after about 90 s. Webbing slows everyone except spiders, and stepping on it sends a few out to investigate; they go home if they find nothing.
- **Wiki:** [Spider Den/DST](https://dontstarve.wiki.gg/wiki/Spider_Den/DST)
- **For 90 Millas** (`creatures-ai` Creature resource, Land crab night theft): Borrow "a home with capacity, a per-creature respawn timer and a trigger zone": crab burrows as spawn points, burrow sand walked at night drawing crabs out early, and fire and light as the counter, as now. Reject growth over days and spreading dens: an island is a short stop, not a base kept for weeks.

### Herds
- **DST:** Wild beefalo belong to an invisible herd that drifts toward its centre (for comparison, up to 12, and small herds merge). They are neutral: hitting one turns up to five adults near it on the attacker, and they forget after a few seconds without new hits. In mating season they attack anything close. Taming works by feeding and later riding, a bell bonds one animal to a player, how it was treated sets its personality, and neglect erodes obedience.
- **Wiki:** [Beefalo/DST](https://dontstarve.wiki.gg/wiki/Beefalo/DST)
- **For 90 Millas** (`creatures-ai` Behavior state machines `pack_swarm`): Borrow group retaliation with a short memory for barracuda (hit one, the nearby members turn on you, then forget), and the herd centre for fish schools or flocks. Reject mounts and domestication for v1; if a companion is ever specced, "feeding builds trust, neglect erodes it" is the idea to revisit.

### Seasonal giants
- **DST:** Each season has a giant. The winter one arrives after a deep warning sound, prefers players who have built a lot nearby, heads for the closest structure before the player, and walks off after wrecking a handful. The autumn one hunts food. The summer one sits in one spot and takes tribute items to hold off sinkholes near players; if nobody pays, it targets up to two random players. The spring one comes only to clustered structures and lays a nest (from the base-game page [unverified for DST]). Giants not killed leave when their season ends and come back later with the health they had left.
- **Wiki:** [Deerclops/DST](https://dontstarve.wiki.gg/wiki/Deerclops/DST), [Bearger/DST](https://dontstarve.wiki.gg/wiki/Bearger/DST), [Antlion](https://dontstarve.wiki.gg/wiki/Antlion), [Moose/Goose](https://dontstarve.wiki.gg/wiki/Moose/Goose)
- **For 90 Millas** (`creatures-ai` Bosses; `guardacostas-stealth` Triggers): Borrow bosses that leave instead of dying, which supports our rule that bosses are set pieces, not kill targets. Borrow a tribute as a possible trick for the old crocodile (pay it in fish to keep its dusk window shut), and targeting by the camp you built: the cutter or patrol homes in on the most built-up, lit camp. Reject the seasonal calendar.

### Spawners and respawn
- **DST:** Homes respawn their residents on timers (for comparison, a rabbit hole replaces a killed rabbit after about 2.5 days; a pig house takes about 4, from the base-game page [unverified for DST]). A rabbit that only fled into its hole does not start the timer, and rabbits go home at dusk or when startled. World regrowth waits while a player is close and retries later, so nothing pops into view.
- **Wiki:** [Regrowth](https://dontstarve.wiki.gg/wiki/Regrowth), [Rabbit Hole/DST](https://dontstarve.wiki.gg/wiki/Rabbit_Hole/DST), [Pig House](https://dontstarve.wiki.gg/wiki/Pig_House)
- **For 90 Millas** (`creatures-ai` Host-run creatures, Creature resource): Borrow "never spawn or respawn inside any player's view", which in co-op means outside every peer's view, checked on the host. Borrow "a creature that escaped home is not a loss". Reject slow multi-day respawns: islands are short stays.

### Leashing and aggro
- **DST:** Most hostile mobs are territorial: they chase a short way and then go home. Hounds from a mound bark and turn back once you are far from it, while bosses and some big mobs chase much farther or without limit, and pigs head home at dusk unless already fighting. Aggro can be passed to other mobs, so players lead hounds into pigs or beefalo. The mound detail is base-game and Reign of Giants; no DST-specific chase distance was found [unverified for DST].
- **Wiki:** [Guides/Mob Killing Guide](https://dontstarve.wiki.gg/wiki/Guides/Mob_Killing_Guide), [Hound Mound](https://dontstarve.wiki.gg/wiki/Hound_Mound)
- **For 90 Millas** (`creatures-ai` Creature resource, Noise and smell; `guardacostas-stealth` Chase and shore squad): Borrow data fields `leash_tiles` (distance from home or patrol line) and `forget_after_s` on each creature. The reef shark's 20 s "ignore that swimmer" and the shore squad's 180 s search are already leashes, so make them data and give the give-up a tell (soldiers shout and walk back). Aggro transfer already exists as the raw-fish decoy.

### Kiting
- **DST:** Most melee mobs wind up before a hit and pause after it. Defensive kiting steps away during the windup; offensive kiting hits during the pause and backs off before the next swing. Ranged attackers cannot be outrun and need zig-zags, and some mobs kite their target back. Exact hit counts and frame windows come from community guides, not the wiki [unverified]; the Kite glossary page was seen only as a search result, not fetched.
- **Wiki:** [Guides/Mob Killing Guide](https://dontstarve.wiki.gg/wiki/Guides/Mob_Killing_Guide), [Kite](https://dontstarve.wiki.gg/wiki/Kite)
- **For 90 Millas** (`creatures-ai` Behavior state machines `patrol_circle_strike`, `hidden_ambush`): Borrow a readable windup and a recovery window on every strike, such as the shark's circle, strike and 4 s retreat. Keep windups generous: clients see remote creatures through interpolation, so frame-tight timing would feel unfair over the network.

### At sea: fish schools and a biting rock fish
- **DST:** A sea rod takes an optional bait and float. The player reels while the line is slack and stops when it strains: reeling under strain snaps the line and loses the tackle, and stopping too long lets the fish go. Schools surface near players every so often (for comparison, every 15–60 s); deeper water holds bigger, harder fish that need a boat and better tackle, and some species are seasonal. A deep-water school can bring a shark-like rock fish (for comparison, a 7.5% chance) that bites creatures in the water, leaps aboard to bite, jumps back off and gives up after a few leaps that hit nobody.
- **Wiki:** [Sea Fishing Rod](https://dontstarve.wiki.gg/wiki/Sea_Fishing_Rod), [Ocean Fishes](https://dontstarve.wiki.gg/wiki/Ocean_Fishes), [Rockjaw](https://dontstarve.wiki.gg/wiki/Rockjaw)
- **For 90 Millas** (`creatures-ai` Shark targeting, Noise and smell; `survival-meters` Hunger): Fishing from the raft (a Pescador strength) could raise a `blood` event that draws the shark pass, so food comes with a cost. The give-up-after-misses rule matches our circle-and-leave. A two-state tension reel is a possible light fishing skill check.

### At sea: the sea-bird boss
- **DST:** A large seabird boss appears at certain deep-fish shoals and comes back after some days. It stays neutral until players fish its shoal or attack it, and its dives make wave rings that shove boats and soak players. It changes behaviour at health thresholds: below about two-thirds it flees, below one-third it swoops and destroys masts in its path. It drops feathers for the better sail.
- **Wiki:** [Malbatross](https://dontstarve.wiki.gg/wiki/Malbatross)
- **For 90 Millas** (`creatures-ai` Bosses): Borrow "neutral until you take its food" as the tiger shark's trigger, and threshold-driven breaks (rips the sail, flees). Reject the long damage race: it needs a group and does not fit a 60–120 s crossing.

### At sea: pirate raids
- **DST:** While a player is at sea within range of the monkey island, raids can trigger, with odds that rise with the server's average days survived (for comparison, at most about 20% per 6 minutes). A sloop brings 2–5 monkeys and a mate, who board, knock items out of players' inventories, loot the deck, wreck masts and sail off. They do not fight unless struck, and a banana bribe sends them away at once. Killing the monkey that took an item gets it back (otherwise it can end up in a pirate stash); sinking the sloop throws the crew into the water, and whether stolen items drop then is [unverified]. The Powder Monkey page's tip is to fill the leftmost slots with junk stacks to shield valuables. A cursed trinket is listed as a drop, but its curse is [unverified].
- **Wiki:** [Pirate Raid](https://dontstarve.wiki.gg/wiki/Pirate_Raid), [Powder Monkey](https://dontstarve.wiki.gg/wiki/Powder_Monkey), [Moon Quay](https://dontstarve.wiki.gg/wiki/Moon_Quay)
- **For 90 Millas** (`creatures-ai` Seagull swoop and steal; `crossing` Threat plan): Our gulls already steal from a predictable slot. Borrow bribe-to-leave (toss food) and "chase the thief to get it back", both solo-friendly, and raid odds that scale with run progress by distance band. Reject a boarding fight on the raft.

### A parrot that fetches
- **DST:** A crafted hat summons a parrot that follows the wearer and moves nearby ground items into their inventory, farthest first (for comparison, within about 3.75 tiles). It cannot take traps or live creatures. Monsters can kill it, and it returns after a day; taking the hat off stores the parrot with its current health.
- **Wiki:** [Polly Roger's Hat](https://dontstarve.wiki.gg/wiki/Polly_Roger's_Hat)
- **For 90 Millas** (`creatures-ai` Shark targeting; `npcs-dialogue` Companions): A tame bird that fetches small items could help a solo player, and as a living companion within 5 tiles it would count toward breaking ALONE. Make it fragile, data-driven and slow to respawn. A maybe: it must not make scavenging trivial.

## crafting-inventory and inventory-hud

### Tech tiers via stations
- **DST:** Two built stations unlock recipes. The first-tier station is cheap (gold, logs, rocks); the second costs refined parts and also covers first-tier recipes, so the cheap one can be torn down. Both burn and can be hammered apart. The wiki says only that you stand "near" a station [range unverified].
- **Wiki:** [Science Machine/DST](https://dontstarve.wiki.gg/wiki/Science_Machine/DST), [Alchemy Engine](https://dontstarve.wiki.gg/wiki/Alchemy_Engine), [Crafting/DST](https://dontstarve.wiki.gg/wiki/Crafting/DST)
- **For 90 Millas** (`crafting-inventory` Workbench, Recipes): Reject player-built tier stations: each island is left behind, so a bench tree is wasted investment. Keep the level-placed workbench. If a tier is wanted, make a rarer level-placed bench on later chains (a wreck table) that offers more recipes through the recipe's `station` data, with no new mechanic.

### Prototype once, craft anywhere
- **DST:** The first craft of a recipe near a station prototypes it; from then on the player can make it anywhere with the materials. Each first unlock gives a small sanity boost (15, for comparison). "Crafting stations" are a separate class that never teach the recipe, so you come back every time. A scrapbook note suggests knowledge belongs to each survivor; per-player versus shared knowledge in multiplayer, and whether crafting beside the station counts as the prototype, are [unverified].
- **Wiki:** [Crafting](https://dontstarve.wiki.gg/wiki/Crafting), [Prototyping](https://dontstarve.wiki.gg/wiki/Prototyping)
- **For 90 Millas** (`crafting-inventory` Recipes, Workbench; `endings-progression` Experiencia carry-over; `survival-meters` Morale): Borrow the split as a data model: "known" (learned from NPCs, kept across runs) is separate from "where it is made" (the `station` field: none, workbench, fire). Keep knowledge party-wide, as identification already is, so solo and co-op behave the same; optionally give a small morale bump on each recipe's first craft per run. Reject craft-anywhere for structures; build sites stay bench-placed.

### Crafting menu
- **DST:** Filters replaced the single-player tabs, and one recipe can sit in several of them, with a station filter and an "everything" filter. Quick-craft pages hold up to 9 recipes each, with keys to page through, and scrolling over a recipe cycles its skin. Search and pinning were not shown in the fetched text [unverified].
- **Wiki:** [Filter](https://dontstarve.wiki.gg/wiki/Filter)
- **For 90 Millas** (`inventory-hud` Workbench crafting list, Crafting list contents): Our name-sorted list with dimmed rows is enough while a bench offers about 10 recipes. Add a station or tag filter only if lists grow; a later "pin this recipe" line showing missing inputs near the strip could help gathering runs. Reject skins.

### Inventory slots
- **DST:** Every DST character carries 15 slots (the 12-slot row on the page is a single-player expansion character). A hidden cursor "hand" holds a picked-up item but is not storage. There is no weight: capacity is limited only by slots and stack sizes.
- **Wiki:** [Inventory](https://dontstarve.wiki.gg/wiki/Inventory)
- **For 90 Millas** (`crafting-inventory` Inventory; `inventory-hud` Inventory strip): Our 12 slots plus a weight limit of 30 sit a little under DST's 15, and weight is our version of its capacity trade-offs; no change needed. Reject the cursor slot: it breaks gamepad parity and the host-authoritative slot model.

### Equipment slots
- **DST:** Three worn slots: hand (tools, weapons), body (armour, vests or a backpack) and head (hats, helmets). The body slot is contested: a backpack means no body armour. The Inventory page lists a DST-only extra slot without explaining it [unverified], and amulets sharing the body slot is [unverified].
- **Wiki:** [Inventory](https://dontstarve.wiki.gg/wiki/Inventory), [Backpack/DST](https://dontstarve.wiki.gg/wiki/Backpack/DST)
- **For 90 Millas** (`inventory-hud` Selection is not holding; `survival-meters` Heat): Keep "carried counts": a tool works from any slot, which is simpler, solo-friendly and needs no swap UI. Reject a hand slot. If hats arrive for sun and heat, borrow a single worn slot with a real trade-off.

### Backpacks
- **DST:** The basic pack (grass and twigs) adds 8 slots in the body slot; it cannot go inside other storage, and only one can be worn. Dropped on the ground it works as a box you can fill without wearing it. It burns, and its contents spill out unharmed. A bigger pack has 12 slots but slows walking (for comparison, 10% in DLC/DST) and keeps its contents dry; other packs trade slots for cooling or a filter on what they hold.
- **Wiki:** [Backpack/DST](https://dontstarve.wiki.gg/wiki/Backpack/DST), [Piggyback](https://dontstarve.wiki.gg/wiki/Piggyback)
- **For 90 Millas** (`crafting-inventory` Inventory, Stashes; `inventory-hud` Inventory strip): Borrow capacity with a cost: a craftable *saco* adds a few strip slots but counts as heavy, so swimming with it drains energy faster. Borrow "a dropped pack is a stash": an open sack on the ground is fair game for crabs and gulls, a tied or buried one is safe. Each player carries their own, so no rule needs a teammate.

### Stacking
- **DST:** Stacks come in three size classes set by item kind (for comparison, 40, 20 and 10); most wearables and tools do not stack. When food stacks merge, freshness is said to become a weighted mix of the two [unverified, forum only]. Containers change spoil speed: a cold box halves it, and the ground is faster than the inventory.
- **Wiki:** [Inventory](https://dontstarve.wiki.gg/wiki/Inventory), [Spoilage](https://dontstarve.wiki.gg/wiki/Spoilage)
- **For 90 Millas** (`crafting-inventory` Item resource; `content-data`): Our rule already matches (per-item stack size; items with more than 1 durability do not stack). Borrow a few size classes as a convention for content authors. If spoilage arrives, borrow the weighted merge and make the cooler a half-rate container on top of being theft-proof.

### Durability
- **DST:** Wear comes in four forms: uses per action (tools, weapons), time while worn (clothing), damage soaked (armour, walls) and fixed charges (staffs, books), shown as a percentage. At 0 the item breaks. Almost nothing can be repaired except clothing (with a sewing kit) and walls. Hammering a structure returns about half its inputs, scaled down by uses spent.
- **Wiki:** [Durability](https://dontstarve.wiki.gg/wiki/Durability), [Hammer](https://dontstarve.wiki.gg/wiki/Hammer)
- **For 90 Millas** (`crafting-inventory` Durability; `inventory-hud` Slot contents): Borrow the wear types as one data field: uses (what we have now), time worn (a sun hat), damage soaked (how raft integrity already works). Keep the integer uses count on the strip; with small numbers (lighter 20) it reads better than a percent. Keep hand tools unrepairable so scavenging stays tense; only the raft gets repair recipes.

### Building placement
- **DST:** The player places a structure where they choose. Each structure claims a radius that nothing new may be built inside; walls may sit tight against walls but keep a gap from everything else, and small plantables need less room (for comparison, 2 against 3.2 units). A hammer takes a structure down for part of its cost. The coloured placement preview is [unverified].
- **Wiki:** [Structures](https://dontstarve.wiki.gg/wiki/Structures), [Hammer](https://dontstarve.wiki.gg/wiki/Hammer)
- **For 90 Millas** (`crafting-inventory` Placing a build site): Keep host-picked placement (the free cell nearest the player, no position in the request): it is safer against forged requests and easier on a gamepad than a free cursor. Borrow per-recipe clearance as data if structures start crowding a bench. "Take apart for half the inputs" is cheap but matters little on islands we leave.

### Burning, fire spread and wildfires
- **DST:** Most wooden structures, plants and packs burn, and burning creatures or over-fuelled open fires light their neighbours. In DST a neighbour first smoulders before it catches, which slows chains. In hot summer the game regularly picks a flammable object near a player to ignite (for comparison, a try every 45 s, never at dusk or night), and it smokes visibly before it catches, so players can douse it in time. Smouldering can be stamped out by hand for a little health (3 in DST, for comparison) or put out with water, ice or a sprinkler machine. Burnt structures leave a husk worth a quarter of their cost, and standing in flames hurts fast (about 8–12 health/s, for comparison).
- **Wiki:** [Fire](https://dontstarve.wiki.gg/wiki/Fire), [Wildfires](https://dontstarve.wiki.gg/wiki/Wildfires)
- **For 90 Millas** (`crafting-inventory` Fire; `weather-daynight` Effects; `guardacostas-stealth` Triggers): Reject spreading fire for v1: it is a co-op griefing risk, a sync cost and a balance blow-up in short runs. Keep our fire contained. If brush fires come later, borrow smoulder-then-flame as a scorching-calm hazard for dry thatch, stoppable by any one player at a small health cost, so solo can always stop it. Burning brush could remove hiding tiles and make smoke the patrol sees.

### Campfire and fire pit fuel
- **DST:** The cheap fire burns about 2 minutes at first (for comparison), can be fed up to about double, cannot be relit and leaves ash or charcoal. The stone-ringed pit costs rocks, gets more burn time from each fuel item, is contained, persists and relights. Fuel is counted in seconds per item, and rain burns fuel faster, up to about 3.5× for the cheap fire and 3× for the pit in a downpour (for comparison; the fuel pages and Rain/DST agree). Light and heat grow in four steps with the fuel level.
- **Wiki:** [Campfire/DST](https://dontstarve.wiki.gg/wiki/Campfire/DST), [Fire Pit](https://dontstarve.wiki.gg/wiki/Fire_Pit), [Fuel](https://dontstarve.wiki.gg/wiki/Fuel), [Rain/DST](https://dontstarve.wiki.gg/wiki/Rain/DST)
- **For 90 Millas** (`crafting-inventory` Fire; `weather-daynight` Effects; `survival-meters` Morale): Borrow refuelling: a fuel value per item in data (driftwood, dry grass, coconut husk) added to a lit fire to extend its burn, instead of a fixed 360 s, with squalls burning it faster. Optionally shrink the comfort reach (morale and company radius, now 5 tiles) as fuel runs low, and add a stone-ring fire on rocky keys as a cheap second tier. Refuelling is a one-player action, so it is solo-safe.

### Resource regrowth
- **DST:** Picked plants respawn on per-spot timers near where they were taken, and spawns wait while a player is close (for comparison, about 19 tiles). Trees seed saplings up to a local cap, burnt forests slowly replant, and an optional setting refills basic supplies around spawn when nobody is near. Bushes regrow after a few days and go barren after several harvests until fertilised. A world multiplier scales it all.
- **Wiki:** [Regrowth](https://dontstarve.wiki.gg/wiki/Regrowth), [Berry Bush](https://dontstarve.wiki.gg/wiki/Berry_Bush)
- **For 90 Millas** (`crafting-inventory` Item resource; `island-generation` Resource spawns, Flotsam refresh; `weather-daynight` Effects): Borrow small regrowth gated on absence: a palm refills one coconut per in-game day, a squall washes a little driftwood ashore, and nothing appears in a player's view. Reject fertiliser, barren states and forest spread: runs are too short to pay them off, and islands should stay mostly finite so pressure pushes players to leave.

### Food spoilage and freshness
- **DST:** Every perishable has a freshness value that counts down through three stages: fresh, then stale (less hunger and health, no sanity), then spoiled near the end (half the hunger value, no health, a sanity cost), and finally rot. Where food sits changes the speed: a cold box halves it, a salt box quarters it, cold weather slows it, and heat, wetness and the sea all speed it up. Cooking halves the spoilage built up, a drying rack makes jerky that keeps much longer (rain pauses it), and salt mined from sea rocks restores up to half the freshness of raw food. For comparison, raw meat keeps about 6 DST days. Whether merged stacks average their freshness is [unverified], and the Drying Rack page contradicts itself on whether food spoils while on the rack.
- **Wiki:** [Spoilage](https://dontstarve.wiki.gg/wiki/Spoilage), [Salt Box](https://dontstarve.wiki.gg/wiki/Salt_Box), [Salt Crystals](https://dontstarve.wiki.gg/wiki/Salt_Crystals), [Drying Rack](https://dontstarve.wiki.gg/wiki/Drying_Rack)
- **For 90 Millas** (`crafting-inventory` Item resource, Stashes; `survival-meters` Hunger): Borrow a perish time in real seconds on food items, three freshness stages, and multipliers as data (sun faster, sealed cooler slower), with salted or sun-dried fish as the form that keeps, which suits the Cuban coast. Spoiled food should raise our existing poison chance rather than add a new penalty, and freshness needs a rule for merging stacks.

### Cooking on a fire
- **DST:** Any lit fire cooks one item at a time in about a second. Cooked food usually heals more and sometimes fills less, and cooking halves the spoilage built up. Meat keeps longer cooked; vegetables keep longer raw.
- **Wiki:** [Cooking](https://dontstarve.wiki.gg/wiki/Cooking)
- **For 90 Millas** (`crafting-inventory` Recipes, station `fire`; `survival-meters` Hunger): Borrow quick per-item cooking at a lit fire that removes the raw crab and fish poison chance and halves spoilage. It works solo and gives the fire a use beyond morale at night.

### Crock Pot
- **DST:** A built pot with four slots cooks only when all four are filled. Each food counts toward food categories, and bigger items count for more (one large meat equals two small ones). A recipe asks for minimum totals in some categories, sometimes a specific item, and some exclude items. When several recipes match, a priority weight picks one; when none match, the pot makes a goop, so any four foods give something. Cooking takes about 10–20 s, and dishes can give less than the parts eaten separately, but most add a small sanity bonus. Whether DST dishes spoil in the pot is disputed: the Spoilage page says no, the Crock Pot page says they do under the DLC rules.
- **Wiki:** [Crock Pot](https://dontstarve.wiki.gg/wiki/Crock_Pot)
- **For 90 Millas** (`crafting-inventory` Recipes): For a later pot station, borrow tag-value matching with priorities and a guaranteed fallback dish. Ingredients carry values in their `.tres` and recipes ask for totals, so a new crab joins existing dishes with no script change. The fallback dish gets a handwritten Cuban name, and any one player can fill the pot alone.

## island-generation

### Generation pipeline
- **DST:** A preset names the tasks a world must have, and each task is a cluster of linked rooms on one background ground type. A normal surface world takes every mandatory task plus a few random optional ones (for comparison, four). Then set pieces are assigned, rooms get physical shapes (Voronoi cells), things are placed, and roads are drawn last.
- **Wiki:** [World Generation](https://dontstarve.wiki.gg/wiki/World_Generation)
- **For 90 Millas** (`island-generation` Landmass, POI placement, Validation): Borrow the strict stage order as named, separately testable steps in `IslandGenerator`: shape, bands, POIs, set piece, resources, nav grid, validate. A chain template is our preset, and its POI table reads as "mandatory plus N optional".

### Rooms: exact counts plus odds
- **DST:** A room is a small biome variant: a ground type, tags, some things with exact counts and others with a spawn chance at each spot. Rooms get evenly spaced nodes, each node may add 0–2 filler background rooms, and things are placed only after rooms have real positions.
- **Wiki:** [World Generation](https://dontstarve.wiki.gg/wiki/World_Generation)
- **For 90 Millas** (`island-generation` POI placement, Resource spawns; `content-data`): Give the POI and resource rows in the chain `.tres` the same two-part shape, guaranteed counts (the binoculars cairn) plus weighted odds, so a new crab or POI stays a data change.

### Locks and keys
- **DST:** Tasks carry locks and grant keys, and a new task is attached only where the keys already available open its locks, so tougher areas drift toward the edges. The wiki's example is a pass blocked by boulders whose key is the materials for a pickaxe. If nothing fits, a task is attached at random.
- **Wiki:** [World Generation](https://dontstarve.wiki.gg/wiki/World_Generation)
- **For 90 Millas** (`island-generation` POI placement, Validation): Use it at island scale: a POI that needs an item sits farther from the landing than the place that item can be found, and Validation checks that order along with reachability. Between islands, chain branching already does this.

### Branches, loops and blockers
- **DST:** The task graph is a tree that may close one loop (for comparison, 50% by default), closed with an impassable blank task, which tends to make horseshoe-shaped land. The entrance task is fenced by 1–2 blank blocker rooms of water or void, and players can tune branching and loops.
- **Wiki:** [World Generation](https://dontstarve.wiki.gg/wiki/World_Generation), [World Customization/Don't Starve Together](https://dontstarve.wiki.gg/wiki/World_Customization/Don't_Starve_Together)
- **For 90 Millas** (`island-generation` Landmass, Biome rules): A bay closed by an impassable gap is our lagoon with one channel and our open-crescent sandbar; an "open versus closed bay" knob per chain variant is cheap variety. Reject branch and loop sliders for players in v1.

### Retry versus skip on failure
- **DST:** The physical layout is tried up to five times. If rooms are too small for their contents, the whole generation restarts. A set piece that finds no home is simply dropped.
- **Wiki:** [World Generation](https://dontstarve.wiki.gg/wiki/World_Generation)
- **For 90 Millas** (`island-generation` Validation, Seeded generation): Keep the same split. Hard rules (POI reachability, a reachable escape route, the solo no-skill route) reject and regenerate the island; soft extras (the one set piece) are skipped and never block. Cap the retries and bump the seed in a fixed way, so host and client retry identically and the hash still matches.

### Biomes: a core plus extras
- **DST:** A biome is mostly one ground type with its own resources and creatures, any size or shape. The wiki splits surface biomes into basic ones and random extras, which fit together into continents or islands joined by land bridges or only by wormholes.
- **Wiki:** [Biomes](https://dontstarve.wiki.gg/wiki/Biomes)
- **For 90 Millas** (`island-generation` Landmass, Biome rules): Our bands (deep water, shallows, beach, interior) are a simpler coast-first version that suits small cays. Borrow "core plus optional extra" for interiors: a rocky key always has rock and sometimes gets a scrub pocket.

### Spawn biome and a guaranteed landing
- **DST:** Players always start in a dedicated spawn biome around the arrival portal. It mixes forest, plain and clearing sections with basic resources, though the wiki marks several as only "sometimes" there.
- **Wiki:** [Spawn Biome](https://dontstarve.wiki.gg/wiki/Spawn_Biome), [Florid Postern](https://dontstarve.wiki.gg/wiki/Florid_Postern)
- **For 90 Millas** (`island-generation` Coast cay landing, Scattered landing, Validation): Our handmade sandbar and coast cay already do this. Give every generated island a guaranteed landing room (beach cells with driftwood or water a short walk away), so a solo arrival is never stuck. Reject one shared arrival point on the sandbar, since scattered landing is our design; joiners are covered under coop-networking.

### Set pieces
- **DST:** Small premade scenes dropped into fitting biomes. Traps turn hostile when the bait is taken; "failed survivor" skeletons lie with their gear and are never traps; a few pieces, such as a marble statue group, appear in every world. Sea pieces include treasure monuments and booby-trapped chests, some capped at two per world, and some amounts are world settings.
- **Wiki:** [Set Piece/DST](https://dontstarve.wiki.gg/wiki/Set_Piece/DST), [Set Pieces](https://dontstarve.wiki.gg/wiki/Set_Pieces)
- **For 90 Millas** (`island-generation` POI placement; `npcs-dialogue` Found texts): The failed survivor fits our story: an earlier raft's abandoned camp with a bottle note and half-usable gear, never a trap. Tag each set piece as trap or boon so a chain can balance them, and keep our cap of one per island.

### Roads and trails
- **DST:** Roads are drawn last, skip rooms tagged to keep them out, and often but not always lead to a village. Faint trails are more common and often go nowhere. Walking on either is faster (for comparison, 30%), and roads can be turned off.
- **Wiki:** [Road](https://dontstarve.wiki.gg/wiki/Road), [World Generation](https://dontstarve.wiki.gg/wiki/World_Generation)
- **For 90 Millas** (`island-generation` Navigation data): A 96×64 cay is too small for roads. On bigger chains (lighthouse, rocky key) a worn footpath from the landing toward the main POI could hint at direction, with path cost below dune. Reject a speed bonus as a goal in itself.

### Generation settings and world size
- **DST:** World customization is split in two: generation options (biomes, size, branching, loops, roads and the amount of each resource, from none to very high) and runtime settings (regrowth, respawns, events). A larger world makes each biome bigger instead of adding biomes, and a few named presets bundle the options.
- **Wiki:** [World Customization/Don't Starve Together](https://dontstarve.wiki.gg/wiki/World_Customization/Don't_Starve_Together)
- **For 90 Millas** (`island-generation` Landmass; `endings-progression` Challenges; `content-data`): Mirror the split: the chain `.tres` holds generation knobs, challenge or difficulty flags hold runtime ones. Take the size lesson as a warning: more area without more POIs adds walking, not play, so tie land share to POI count per chain.

### The sea graded by distance from land
- **DST:** The sea gets harder going out: calm coastal water with kelp and easy fish, then swell with sea stacks, then rough water packed so tightly with stacks that boats barely pass, with hazardous patches beyond. Darker water is deeper, raising the anchor takes longer there, and salt shoals sit as set pieces in the middle zones.
- **Wiki:** [Ocean/DST](https://dontstarve.wiki.gg/wiki/Ocean/DST)
- **For 90 Millas** (`island-generation` Landmass; `crossing` Threat plan): Our shallows-to-deep bands and coast, mid and far chains already follow this. Borrow "darker means deeper means riskier" as a pure-art readability cue, and reef or rock obstacles that thicken with crossing distance.

### An island found from the coast
- **DST:** A separate landmass with five sub-biomes and its own rule (there, the sanity meter is replaced by a different meter). Players find it by looking for a C-shaped bay of explored coast, since the island sits to close the C into an O; the shortest boat routes avoid sea stacks and deep water. Whether it generates in every world is [unverified].
- **Wiki:** [Lunar Island](https://dontstarve.wiki.gg/wiki/Lunar_Island)
- **For 90 Millas** (`crossing`; `island-generation` chain variants): Borrow "readable from the coast": the next island's direction should be guessable from coastline, flotsam or current before anyone has charts. Borrow a rule-change zone (one meter behaving differently on one chain) for the storm key or the shipwreck reef.

### Small remote islands built around one resident
- **DST:** The hermit's island and the monkey island are small, remote and reached only by boat. Each has its own ground type and is built around one resident or faction, and the monkey island signals its approach with painted sea stacks that grow denser as you get close. The wiki does not say whether their base layouts are handmade [unverified], though the monkey docks form a deliberate shape.
- **Wiki:** [Hermit Island](https://dontstarve.wiki.gg/wiki/Hermit_Island), [Moon Quay](https://dontstarve.wiki.gg/wiki/Moon_Quay)
- **For 90 Millas** (`island-generation` Any handmade layout builds the island; `crossing`; `npcs-dialogue`): This supports our split of handmade layouts for set islands (sandbar, coast cay, secret cay) and generated filler. Borrow breadcrumbs: more buoys and flotsam as a crossing nears an NPC island.

### Adventure Mode and wormholes
- **DST:** Paired wormholes always link the same two distant spots, at a sanity cost per trip. In the single-player game's Adventure Mode, the Archipelago level is six islands linked only by wormholes, each keeping the same two biomes. Adventure Mode draws its levels from a pool, uses each world type at most once, keeps the last chapter fixed and generates a new map on every visit.
- **Wiki:** [Wormhole](https://dontstarve.wiki.gg/wiki/Wormhole), [Adventure Mode](https://dontstarve.wiki.gg/wiki/Adventure_Mode)
- **For 90 Millas** (`island-generation`; `endings-progression` Run structure; `docs/ISLANDS.md`): A pool with no repeats, a fixed finale and fresh layouts is our run (sandbar first, chains between, final approach last); it confirms the structure. Reject teleport links: the crossing is our link.

### Shipwrecked's world of islands
- **DST:** (Klei's single-player expansion, not DST.) Every island has a ring of shallow water, and medium or deep water never touches land. Wrecks sit only in "ship graveyard" patches in deep water, and there is exactly one volcano, usually near a map edge. One island meant for every world sometimes fails to generate because of a bug. Magma fields and mangroves rarely form whole islands and usually share land with other biomes.
- **Wiki:** [Ocean](https://dontstarve.wiki.gg/wiki/Ocean), [Volcano](https://dontstarve.wiki.gg/wiki/Volcano), [Magma Field](https://dontstarve.wiki.gg/wiki/Magma_Field), [Set Pieces](https://dontstarve.wiki.gg/wiki/Set_Pieces)
- **For 90 Millas** (`island-generation` Landmass, Biome rules, Validation): The closest match to our game. Keep and test the "shallow ring on every island" invariant (1–2 tiles in our spec), and consider mangrove as a band inside other chains. Take the missing island as a warning: Validation must assert each guaranteed POI, not assume it.

### Handmade versus random, overall
- **DST:** Random results within handmade rules. Presets, task lists, room recipes, set pieces and the named sea islands are authored; which optional tasks appear, the layout, room contents and exact placement are rolled. A few things exist in every world (the spawn portal, the statue set piece, a hot spring on the lunar island). The wiki gives no handmade-to-random ratio.
- **Wiki:** [World Generation](https://dontstarve.wiki.gg/wiki/World_Generation), [Set Piece/DST](https://dontstarve.wiki.gg/wiki/Set_Piece/DST)
- **For 90 Millas** (`island-generation`): Same philosophy. Our two fully handmade opening islands give a stronger first-hour guarantee than DST does, which suits teaching and solo play.

### Seeds
- **DST:** None of the fetched wiki pages mention a seed. Forum posts say a world comes from a numeric seed that can be printed from the console, that rebuilding the same world needs a mod, and that mods can change the result for the same seed [unverified: forums, not wiki].
- **Wiki:** none found (search results only: Klei forums and Steam discussions)
- **For 90 Millas** (`island-generation` Seeded generation; `coop-networking`): Our design already goes further: (run seed, island index, chain id) builds the island, the host sends the seed and clients verify a hash. Keep it, and add the retry-bump rule to the same determinism.

### Map and fog of war
- **DST:** Each player's map starts black and fills in with whatever comes on screen; maps appear to be per player (implied, not stated). A crafted map scroll copies its maker's map at that moment, and another player who reads it gains those areas. A few structures reveal an area, or their icon, to everyone, holding a compass shows that player on everyone's map, and surface and cave maps are separate.
- **Wiki:** [Map](https://dontstarve.wiki.gg/wiki/Map), [Map/DST](https://dontstarve.wiki.gg/wiki/Map/DST), [Map Scroll](https://dontstarve.wiki.gg/wiki/Map_Scroll)
- **For 90 Millas** (`escape-routes` Route discovery; `endings-progression` Experiencia carry-over; `inventory-hud`): Reject per-player maps (sync cost for little gain on small cays) in favour of one host-owned party map that clears as anyone sees terrain, identical in solo. Borrow "the compass shows you to friends" to regroup after the scattered landing, and the scroll idea for our *Pedazo de mapa*.

## npcs-dialogue and endings-progression

### A barter NPC in a village
- **DST:** A large NPC who cannot be harmed sits in a pig village. He takes food, meat and trinkets and pays in gold, more for rarer items. He trades only by day and sleeps at night, trades even with characters his pigs are hostile to, and holds no grudge if you kill his pigs. A rare belt starts a short contest in which AI fighters spawn and lucky nuggets are thrown over several brief rounds, paid out by each player's share; it starts only if the area is clear and night is not close. Seasonal events add festive goods.
- **Wiki:** [Pig King](https://dontstarve.wiki.gg/wiki/Pig_King), [Pig King/DST](https://dontstarve.wiki.gg/wiki/Pig_King/DST)
- **For 90 Millas** (`npcs-dialogue` NPC resource; `weather-daynight` Day cycle): Borrow a minor NPC barter post as data: a `.tres` list that swaps found junk for useful goods, open only at certain hours and resolved on the host, playable by 1 player offline. Reject a gold currency (we have no money economy; direct barter is clearer) and the contest minigame for v1.

### Favours and friendship (the hermit crab)
- **DST:** A hermit NPC lives alone on a remote island and cannot be harmed. Each kind of favour raises friendship one step, but only the first time; repeats earn small gifts. The favours (about ten) are tidying the island, repairing and upgrading her house in stages, bringing things she needs and catching big fish, and each tier unlocks more stock in her shop, paid in empty bottles. The bond shows in behaviour: she flees players until the first favour, then turns to face them; her speech colour shifts at higher tiers; near the top she takes a new name, her home is renamed and she dances with players who emote; finishing every favour hands over a unique keepsake. Whether friendship is shared by the server or tracked per player is [unverified], as is whether her tone softens [unverified] (the page mentions only the colour). The Crab King and Hermit Island pages say the finished favours give a key item that changes what the crab boss gives, but her own page did not confirm a link to a later sea boss [unverified].
- **Wiki:** [Pearl](https://dontstarve.wiki.gg/wiki/Pearl), [Crabby Hermit](https://dontstarve.wiki.gg/wiki/Crabby_Hermit), [Hermit Island](https://dontstarve.wiki.gg/wiki/Hermit_Island)
- **For 90 Millas** (`npcs-dialogue` Quests; `endings-progression` NPC memory; `escape-routes` Route resource; `crossing` Threat scripts): Borrow trust as a count of distinct first-time favours, so it cannot be grinded, shown through behaviour rather than numbers: an NPC stops avoiding you, greets you differently by trust tier, or their home visibly improves. It suits La Vieja Caridad and the lighthouse hermit, compressed to 2–4 favours each, every one doable by 1 player; the hermit's ladder could end with the lighthouse lit, so its beam helps on the final crossing.

### The crab boss
- **DST:** The crab boss sleeps in a ring of sea stacks in open water. Players wake it by socketing nine gems, and the gem colours choose its extra powers, so the players set the difficulty. Cannon towers shoot boats and open leaks, ramming a tower at speed hurts it, and in a healing phase the boss hides behind ice until a spike is broken.
- **Wiki:** [Crab King](https://dontstarve.wiki.gg/wiki/Crab_King), [Hermit Island](https://dontstarve.wiki.gg/wiki/Hermit_Island)
- **For 90 Millas** (`creatures-ai` Bosses): Reject the gem-socket boss. "What you bring sets the difficulty" is a maybe for a later set piece.

### Followers fed with food
- **DST:** Feeding a pig meat makes it follow you for a time scaled by the food's value (for comparison, about 19 s per hunger point, up to 2.5 days), and feeding again adds time. A pig close to leaving shows a hungry pout; one with plenty of time looks happy. Followers fight for you and join in when you chop (not in the dark), each friendly pig nearby slowly restores sanity, and loyalty ends when time runs out, the leader dies or you hit it. Pigs left outdoors under a full moon turn hostile. A cap on followers per player is [unverified], and so is what happens when the leader disconnects [unverified].
- **Wiki:** [Pig/DST](https://dontstarve.wiki.gg/wiki/Pig/DST)
- **For 90 Millas** (`npcs-dialogue` Companions): Reject loyalty rented with food for story companions: our rescued balseros are people with needs and ending flags, not hirelings. Borrow a readable tell before a companion's need turns critical (like the pout), and a companion joining the action the player is already doing (gathering, chopping, rowing) as how its skill shows. Both work solo, since companions follow the nearest player.

### A group you build up
- **DST:** Only one playable character can recruit merms, or any player wearing a craftable disguise. Loyalty is bought with vegetarian food or live fish (for comparison, capped at 3 days, or 5 while a king lives). Players raise a king by building a royal tapestry and feeding a merm on it; he must keep being fed or he starves in about two days. While he lives all merms are stronger and stay neutral to everyone, and gear brought to him through small quests upgrades loyal merms further. Whether loyal merms also chop or mine for you is [unverified].
- **Wiki:** [Merm/DST](https://dontstarve.wiki.gg/wiki/Merm/DST), [King of the Merms](https://dontstarve.wiki.gg/wiki/King_of_the_Merms)
- **For 90 Millas** (`npcs-dialogue` Ending flags, Companions): Borrow the disguise: any interaction locked to one background needs an item-based way round it, which keeps every background able to finish a solo run (GAME_DESIGN §10). "Keep it fed and everyone benefits" fits Caridad's lamp: oil keeps it lit, a lit lamp gives the party a small buff and sets the `caridad_lamp` ending flag. Reject a long upkeep economy; runs are 6–8 islands.

### Character perks and drawbacks
- **DST:** Every character pairs at least one unique perk (a companion, unique crafts, a resistance) with drawbacks (a restricted diet, sanity rules such as fear of the dark, a weakness to cold or water). Most are free; some are sold or woven with the cosmetic currency. Offering a rare idol at the portal swaps character in the same world: the inventory drops, while day count, explored map and learned recipes stay.
- **Wiki:** [Characters/DST](https://dontstarve.wiki.gg/wiki/Characters/DST), [Celestial Portal](https://dontstarve.wiki.gg/wiki/Celestial_Portal)
- **For 90 Millas** (`endings-progression` Experiencia carry-over; backgrounds in GAME_DESIGN §10, which have no spec yet): A small drawback per background could add flavour, but only as a cost, never something that blocks an escape route, so solo stays winnable with any background. Reject mid-run swaps (runs are short) and paid unlocks.

### Skill trees
- **DST:** Each character earns skill points by surviving days as that character, and ghost time does not count (for comparison, 15 points in all by about day 68). Points and learned skills belong to the account and carry across worlds and servers. There are more skills than points; trees have themed branches with tiers, and many have two opposing affinities, each unlocked by beating a particular boss, of which you can take only one. The tree can be reset at character select, or in a world at the portal with an idol.
- **Wiki:** [Skill Tree](https://dontstarve.wiki.gg/wiki/Skill_Tree)
- **For 90 Millas** (`endings-progression` Experiencia points): Borrow "more choices than points" for the boost list, perhaps with one pair of boosts that exclude each other, free re-spending between runs, and boss- or event-gated unlocks, as keepsakes already unlock. Reject a many-day grind per character; we grant points per island reached.

### What carries between worlds
- **DST:** The account keeps cosmetic skins (five clothing slots, changed at a wardrobe, with no gameplay effect), unlocked characters and skill-tree progress, so DST carries more than cosmetics. The world holds inventory, structures, followers and NPC friendships, which are lost when it resets, and in Wilderness mode death also wipes the map, learned recipes and day counter. That skins follow the account to every server is [unverified], and spool income rates came from a search summary only [unverified].
- **Wiki:** [Skins](https://dontstarve.wiki.gg/wiki/Skins), [Skill Tree](https://dontstarve.wiki.gg/wiki/Skill_Tree), [Death/DST](https://dontstarve.wiki.gg/wiki/Death/DST)
- **For 90 Millas** (`endings-progression` Experiencia carry-over, Keepsakes): We already carry more than DST does (50% skill XP, trust, recipes, keepsakes), so DST is a reminder to keep the world itself unforgiving. A cosmetic unlock channel (outfits, raft paint) is a possible later no-power reward, drawn client-side only, as the art rule requires.

### Playstyles
- **DST:** Survival is the default: ghosts, and a reset when all are dead. Endless never resets, with portal revives at a max-health cost. Wilderness has no ghosts: a dead player goes back to character select and drops in somewhere random, losing map and recipes. Relaxed removes death from hunger, cold, heat and darkness and softens damage, and Lights Out is Survival with endless night. Per hosting guides, the playstyle can be changed later in world settings [unverified].
- **Wiki:** [Don't Starve Together](https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together)
- **For 90 Millas** (`endings-progression` Challenges, Difficulty baseline): Our design is Survival plus Experiencia easing, right for v1. Endless and Wilderness suit a persistent world, not a run, so reject them. Lights Out is a good template for a v2 challenge modifier as data (always night, always squall), and it must stay solo-winnable.

### Lore in fragments
- **DST:** Five murals near a gate tell an ancient people's history. Each mural examined gives the character's next line in a five-step sequence that then loops, so the order follows how many murals you have read, not which one. One panel is worn past reading, and only a single character's line hints at what it showed. The ancient lore boss's lines during the fight and on death carry the rest, shifting from defiance to weary warnings that events repeat, and a later harmless form wanders the caves commenting on places, with one line on a first visit and another on later ones. A wiki split of that history into named eras came from a search summary only [unverified].
- **Wiki:** [Ancient Mural](https://dontstarve.wiki.gg/wiki/Ancient_Mural), [Ancient Fuelweaver](https://dontstarve.wiki.gg/wiki/Ancient_Fuelweaver), [Ancient Fuelweaver/NPC](https://dontstarve.wiki.gg/wiki/Ancient_Fuelweaver/NPC)
- **For 90 Millas** (`npcs-dialogue` Found texts, Handwritten lines; `endings-progression` NPC memory): Order by discovery: the n-th fragment of a series shows the n-th entry, whichever object it is found on, which suits procedural islands. Include a deliberately damaged piece (a wet letter one background can partly read), and lines that change on repeat meetings (for example Rodríguez in `la_captura` on a second capture). Satire stays aimed at the system, never at invented quotes from real politicians.

### Examine lines
- **DST:** Alt-click, or a controller button, on any object makes the character say a short line overhead. Each character has their own line per object, plus extra lines by state: burning, burnt, spoiled, empty or full, occupied, weather, moon phase, growth stage, and actions not allowed. The humour is dry and character-specific and carries much of the game's tone at little cost. Not verified: how long a line stays up [unverified] (the wiki flags its own figure), whether other players see it [unverified], that each voice is an instrument sound rather than speech [unverified], and special lines for examining other players by state, such as ghost or attacker [unverified].
- **Wiki:** [Quotes](https://dontstarve.wiki.gg/wiki/Quotes), [Wilson/Quotes/Don't Starve Together](https://dontstarve.wiki.gg/wiki/Wilson/Quotes/Don't_Starve_Together) (read only for how lines are structured)
- **For 90 Millas** (`player-movement` Interaction; `npcs-dialogue` Handwritten lines; `endings-progression` Death one-liners): Our Interaction requirement has a single button and no examine verb, so this needs a new change: an "Inspect" verb (a second button or a hold) showing a short Cuban one-liner keyed by object id, state and background, with one generic line per object as the fallback, stored like Death one-liners (dialogue `.tres`, es/en, a soft variant where a line swears, picked by the run seed). The handwritten cost multiplies (backgrounds × objects × states × 2 languages), so start generic and add background overrides sparingly. It works offline; in co-op every peer sees the bubble.

## guardacostas-stealth

### Hiding as a bush
- **DST:** A craftable hat lets the player crouch down as a bush. While disguised, enemies that were not already targeting them ignore them, and any movement ends it. A few creatures see through it (the darkness attacker, and a berry-eating bird that will not come near), and the hat never wears out. Whether attacking ends the disguise, and how bosses react, is [unverified].
- **Wiki:** [Bush Hat/DST](https://dontstarve.wiki.gg/wiki/Bush_Hat/DST)
- **For 90 Millas** (`guardacostas-stealth` Hidden states, Chase and shore squad; `player-movement` Walk, run, crouch): State explicitly that hiding never shakes an active pursuer: already spotted means already hunted, and the squad searches the last known position. Make exceptions data (a shore-squad dog sniffs out brush), and consider a craftable frond or sargassum cover, as a Resource item, that hides a still player on open sand or in shallows. Open question: should hiding need standing still, since our crouch stays hidden while moving at 2 tiles/s? All of this works for 1 player.

### Stealth ideas gathered from other sections
- **Light gives you away** ([Darkness](https://dontstarve.wiki.gg/wiki/Darkness); see weather-daynight): invert the darkness attacker, since fire and smoke draw the patrol. Borrow its grace window and spoken warning: the character mutters a line or a sound plays as the searchlight cone starts sweeping toward them, before the 2 s spot timer runs out (Searchlight, Triggers).
- **Warnings that shrink** ([Hound/DST](https://dontstarve.wiki.gg/wiki/Hound/DST)): the patrol's horizon warning, or a swelling motor sound, gets shorter on later chains (Patrol route).
- **Target the brightest camp** ([Deerclops/DST](https://dontstarve.wiki.gg/wiki/Deerclops/DST)): the cutter or patrol homes in on the most built-up, lit camp (Triggers).
- **A visible give-up** ([Guides/Mob Killing Guide](https://dontstarve.wiki.gg/wiki/Guides/Mob_Killing_Guide)): leash and forget timers as data, with soldiers who shout and walk back (Chase and shore squad).
- **Noisy flocks** ([Birds](https://dontstarve.wiki.gg/wiki/Birds)): gulls taking off near nest palms fire a small `noise` event (Triggers); needs a spec change and a 1-player test.
- **Weather with a place** ([Sandstorm](https://dontstarve.wiki.gg/wiki/Sandstorm)): fog banks on part of the sea to hide in from patrols.
- **Bright moons** ([Moon Cycle/DST](https://dontstarve.wiki.gg/wiki/Moon_Cycle/DST)): full-moon nights need less fire but let patrols see further (Searchlight).
- **Smoke** ([Wildfires](https://dontstarve.wiki.gg/wiki/Wildfires)): burning brush removes hiding tiles and makes smoke the patrol sees, if brush fires ever come.

## ui-shell

### Loading-screen lines
- **DST:** While the world builds, the screen shows mock-grand progress messages, a technical-sounding verb plus an absurd object, with variants for each world type. DST adds tips and lore snippets that players can turn off.
- **Wiki:** [World Generation Screen](https://dontstarve.wiki.gg/wiki/World_Generation_Screen)
- **For 90 Millas** (`ui-shell` Screen flow): A natural place for satire: formal, bureaucratic "progress" lines while the island generates, in the official voice (so standard Spanish, no contractions), all handwritten.

### UI ideas gathered from other sections
- **Joining** (see coop-networking, server browser): v1 joins by IP; in v2 prefer a friends-only platform invite over a public browser (Join screen). Solo never sees it.
- **Lobby kick** (see coop-networking, server settings): a host-only kick in the lobby and during the run (Lobby).
- **A view for the dead** ([Ghost Characters](https://dontstarve.wiki.gg/wiki/Ghost_Characters)): a spectate camera that follows a living teammate and keeps quick chat, optionally with a light *ánima* nudge (Screen flow, HUD layout). Not applicable in solo, where death ends the run.
- **Pause banner** (see coop-networking, host pause): if a host-only co-op pause is ever adopted, show a clear banner to every peer.
- **Clock face** ([Day-Night Cycle](https://dontstarve.wiki.gg/wiki/Day-Night_Cycle)): phase wedges and "time until dark" in the HUD (HUD layout; `inventory-hud`).

## Biggest lessons

- **Warn before you hurt.** Every DST danger is telegraphed in tiers: screen cues before insanity bites (with hysteresis on the worst tier), a spoken line before the dark strikes, growls that grow louder, smoke before fire, a gauge before rain. Give sunstroke, hallucinations, thirst death, night, lightning, patrols and the hurricane the same treatment as our 60 s squall horizon line, and let warnings shrink as the run goes on.
- **Check the death window.** DST allows about 2 minutes from an empty bar to death; our thirst kills in 50 s with no warning step. Test it with 1 player, offline, before locking the numbers.
- **Modifiers, not immunities, stored as data.** Insulation divides a rate, containers and weather multiply spoilage, rain gear resists wetness by a percentage, fuel has a value per item, durability has a few wear types, and creatures carry disposition, leash range and memory time. Put all of it in `.tres` fields so adding a crab, a hat or a fuel never edits a script.
- **One meter kills; the others shape it.** Keep our rule that only thirst, attacks and poison take health. Wetness and any new effect become statuses that modify existing meters, not new bars on a 640×360 HUD.
- **Food and fire are loops, not numbers.** Raw, then cooked, then dried or salted, with perish times and a cooler, gives a daily choice that fits the Cuban coast. Cooking removes our raw-food poison risk, and per-item fuel turns the fixed 360 s fire into a small loop one player can run.
- **Weather that builds up paces better than independent rolls.** A pressure value rising to a rolled threshold, a dry first day, and storms with stages and a wave heading make squalls readable and steerable. Keep the day length fixed and vary phase split and hazard weights per chain stage, not by season.
- **Every co-op rule has a solo path.** Split revives into "needs a teammate" (our water revive) and "self, one-use, placed or pre-paid" (the Medalla, a rare *ermita* shrine). Scale threats per player with a discount for grouping, so solo gets the base amount, not a reduced copy of co-op.
- **Give the dead co-op player something to do, and never delete a leaver's things.** A spectate camera with quick chat and a morale drain on the living keep revival a team goal; dropping a leaver's inventory at their last position is already right.
- **Threats commit, then quit.** A leak that rides on as its own drain, a driller stopped before it finishes, a jumper that gives up after misses, bosses that leave at a health threshold or for a tribute, thieves that drop their loot and flee when one is struck. All of it fits our set-piece bosses and circle-and-leave sharks, and all of it works solo.
- **Generation is a pipeline with guarantees.** Run fixed stages, reject and regenerate on hard failures, skip soft extras, keep retries deterministic so host and client hashes match, and assert every guaranteed thing in Validation. Tie land share to POI count, guarantee a landing room, and make the next island readable from the coast.
- **Voice and trust come from small, repeatable systems.** Trust counted from first-time favours and shown through behaviour, lore fragments ordered by discovery, lines that change on repeat meetings, and an Inspect verb with state lines would carry our Cuban voice and satire far beyond NPC scenes.
- **Reject DST's long-world systems.** Seasonal calendars, den growth, domestication, slow regrowth, spreading fire, per-player maps, shards, PvP, votes, rollback, unlimited revives, mast stacking and teleport-to-shore drowning all assume a persistent world or a sandbox. Our run keeps moving across short island stays and fixed-length crossings.
