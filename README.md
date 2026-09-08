# Azeroth Questing

**Version:** 0.2.29  
**WoW:** Retail 12.1 (`Interface: 120100`)

Azeroth Questing is a lightweight World of Warcraft addon that shows unfinished quests for the current zone, points the player toward the next useful target, and learns anonymous map/quest, timeline, and instance evidence while the player quests.

## Current features

- Detects the current Retail WoW zone/map and refreshes automatically.
- Shows **AVAILABLE**, **TURN IN**, and **IN PROGRESS** quest states.
- Keeps normal **ZONE QUESTS** separate from repeatable **DAILY QUESTS**.
- Prioritizes normal zone quests ahead of dailies, then AVAILABLE, TURN IN, and IN PROGRESS.
- Uses Blizzard super-tracking for accepted quests and temporary user waypoints for available quest starters.
- Adds a floating navigation HUD with a rotating arrow, target name, status, and distance when available.
- Supports optional Auto Accept and Auto Turn-in.
- Supports supplemental quest prerequisites, later-progression blockers, and mutually exclusive quest routes.
- Recognizes known Zidormi/Rhonormu historical timeline zones.
- Learns phase/quest evidence locally when a historical phase is known.
- Learns **map ID + map name + quest associations** even when no historical phase is known.
- Learns anonymous instance/scenario fingerprints such as map ID, instance ID, difficulty ID, LFG ID, instance type, and group-size metadata.
- Exports anonymous learning data with WoW-safe tab-separated fields.
- Can forward anonymous `seen`, `available`, `offered`, `accepted`, `active`, and `turnedIn` quest evidence plus completion support through Wago Analytics when the player has Wago Analytics sharing enabled.
- Mirrors privacy-safe map, reliable-phase, quest-evidence, and instance discoveries into Wago **Switches** so useful crowd observations remain visible while Wago's Counters dashboard is unavailable.
- Builds a clean versioned GitHub package named **AzerothQuesting-<version>.zip** through GitHub Actions.
- Includes stable `/aq phase`, `/aq maps`, `/aq mapid`, `/aq inspect`, and `/aq check` diagnostics.

## Map and quest learning

Azeroth Questing keeps an account-wide `ZoneQuestGuideDB.mapQuestLearning` store. When WoW exposes a quest through the current map, an available quest line, NPC gossip, a quest-detail screen, quest acceptance, or quest turn-in, the addon can record:

- live `UiMapID` and map name;
- faction;
- quest ID and quest name;
- whether the quest was seen as available, offered, accepted, active, or turned in;
- supporting completion state.

The evidence types intentionally mean different things. `available` is a Blizzard map/quest-line API hint and is not treated as proof that the quest can actually be started in the current timeline. `accepted` is also weak because a character can carry a quest after moving between maps or phases. NPC `offered`, NPC `active`, and `turnedIn` observations are stronger evidence that the quest genuinely exists in that world state.

The map collector does not require Zidormi or a known timeline. This is useful for discovering live Retail replacement/alias maps such as Midnight Quel'Thalas.

Map scans are skipped while the player is on a taxi flight path so transient parent/flyover maps are not learned simply because the flight crossed them.

Commands:

- `/aq maps` — show current map ID/name and locally learned quest count.
- `/aq mapid` — show only WoW's current live map ID/name.
- `/aq mapexport` — open only the map/quest learning export.
- `/aq export` — open the combined phase, map/quest, and instance-learning export.

### Export format

Current combined exports use tab-separated schemas:

- `ZQGPHASEDATA|2`
- `ZQGMAPQUESTDATA|2`
- `ZQGINSTANCEDATA|1`

Tabs avoid WoW interpreting normal pipe-delimited field boundaries as text-formatting escape sequences. Exports intentionally omit character names, realm names, GUIDs, guild names, account identifiers, chat, coordinates, and party/raid member names.

## Instance and scenario learning

Version 0.2.24 adds an account-wide `ZoneQuestGuideDB.instanceLearning` store for unusual instanced content such as Warfronts, scenarios, raids, dungeons, and other queueable maps. When the player actually loads into an instance, Azeroth Questing can record a coarse fingerprint containing:

- live `UiMapID` and map name;
- parent map ID/name when WoW provides one;
- instance ID/name and instance type;
- difficulty ID/name;
- maximum-player and instance-group-size values exposed by WoW;
- LFG dungeon ID when available;
- scenario name/type/area/texture-kit metadata when available;
- faction and the current Azeroth Questing timeline/source if one is known.

`/aq inspect` (also `/aq instance`) prints the current fingerprint directly in chat. This is intended for tests such as comparing **Normal vs Heroic Battle for Stromgarde** or identifying which of Blizzard's alternate Arathi/Darkshore map IDs is actually used by a Warfront instance.

`/aq instanceexport` opens just the instance-learning block. `/aq export` includes the instance block after the existing phase and map/quest blocks.

The local export can contain Blizzard's localized map/instance/scenario names because the player explicitly chooses whether to copy it. Automatic Wago instance telemetry is stricter: it sends the stable/non-name context used for research — map ID, parent map ID, instance ID/type, difficulty ID, LFG ID, maximum/group-size values, scenario type/area/texture-kit fields when available, faction, and timeline/source — while leaving localized names, coordinates, timestamps, character/account identity, chat, and group-member information out of metric keys.

### Live-confirmed Heroic Battle for Stromgarde fingerprint

Retail testing on an Alliance character inside Heroic Battle for Stromgarde returned:

- `1044 / Arathi Highlands` as the live `UiMapID`;
- parent map `13 / Eastern Kingdoms`;
- instance `1943 / Warfronts Arathi - Alliance`;
- instance type `scenario`;
- difficulty `149 / Heroic`;
- `maxPlayers=30` and `groupSize=10`;
- `LFG=2007`;
- scenario `The Battle for Stromgarde`;
- faction `Alliance`;
- timeline `UNKNOWN (auto)` inside the Warfront.

The same in-game `/aq check` showed Wago loaded with `instancevisit=1`, confirming the v0.2.24 instance fingerprint was queued locally through WagoAnalytics. Normal Stromgarde still needs to be compared against this fingerprint.

## Supplemental quest availability

WoW does not expose every older unaccepted quest through the live map APIs, so Azeroth Questing can supplement missing quests in `QuestData.lua`. Version 0.2.22 expands those records with three availability rules:

```lua
prereqs = { 11111 }        -- every listed quest must be completed first
blockedBy = { 22222 }       -- hide this quest if any listed quest was completed
exclusiveWith = { 33333 }   -- hide if any listed quest is active or completed
```

`prereqs` models the normal quest-chain order. `blockedBy` is intended for breadcrumbs or older quests that become permanently unavailable after later progression. `exclusiveWith` is intended for route choices where accepting another quest commits the character to the other path; if that other quest is merely abandoned before completion, the supplemental quest can become eligible again on the next refresh.

These rules are applied to supplemental database records. Live quests supplied directly by Blizzard's APIs are still trusted as currently obtainable/active and are not hidden by supplemental-only rules. No guessed blocker/exclusive relationships are added automatically; quest IDs should be added only when the relationship is known or observed.

## Historical/time phases

Known timeline locations currently include Dustwallow Marsh/Theramore, Blasted Lands, Peak of Serenity, Silithus, Darkshore, Teldrassil/Darnassus where tied to Darkshore, Tirisfal Glades/Undercity, Arathi Highlands, Uldum, Vale of Eternal Blossoms, and Quel'Thalas/Eversong/Ghostlands/Silvermoon.

Most locations use a two-state old/current model. **Arathi Highlands is handled separately because current Retail exposes three useful Zidormi states: before the Fourth War, the Fourth War/Warfront era, and the current-present state.**

### Live-confirmed Midnight Quel'Thalas maps

Retail testing returned:

- `2537 / Quel'Thalas` in the current Midnight world.
- `95 / Ghostlands` in the old Burning Crusade version.

Azeroth Questing treats `2537` as **PRESENT / Midnight Quel'Thalas** and `95` as **PAST / Burning Crusade Quel'Thalas**.

### Live-confirmed Blasted Lands behavior

Retail testing confirmed both **PRESENT / Iron Horde** and **PAST / Before invasion** can return `17 / Blasted Lands`. Map ID alone therefore cannot classify the Blasted Lands timeline; Zidormi or reliable phase-exclusive quest evidence is still required.

### Live-confirmed Silithus behavior

Retail testing confirmed both **PAST / Before the Wound** and **PRESENT / The Wound** return `81 / Silithus`. Silithus therefore cannot be classified from the best-map ID alone. In the recorded switch, Zidormi's **return to the present** wording correctly identified the old state, and after switching her **before the Wound** option correctly identified the present state. The existing same-map Zidormi detection followed the switch in-game.

Related Silithus map IDs `1321` and `2354` remain registered as alternate contexts but are not assumed to represent a specific timeline until their live role is observed.

### Live-confirmed Tirisfal Glades maps

Retail testing confirmed Tirisfal uses separate live maps across the Zidormi switch:

- `2070 / Tirisfal Glades` was observed in **PRESENT / After Battle for Lordaeron** while Zidormi offered to show the zone before the Battle for Lordaeron.
- After selecting that historical option, `/aq check` returned `18 / Tirisfal Glades` and the addon showed **PAST / Before Battle for Lordaeron**; Zidormi then offered to return the player to the present time.

Version 0.2.20 adds direct map-derived Tirisfal detection so map `2070` can identify PRESENT and map `18` can identify PAST without requiring a new Zidormi conversation first. Map `1247` remains registered as an alternate Tirisfal context but is not assigned a phase until its live role is observed.

### Live-confirmed Uldum maps

Retail testing confirmed Uldum also uses separate live maps across the Zidormi switch:

- `1527 / Uldum` was observed in **PRESENT / N'Zoth assaults** while Zidormi offered **"Can you show me what Uldum was like during the time of the Cataclysm?"**.
- After selecting that historical option, the live map changed to `249 / Uldum`. The main timeline line showed **PAST / Cataclysm Uldum** after Zidormi was reopened, and Zidormi offered **"Can you return me to the present time?"**.

The recording also caught a stale diagnostic moment where `/aq check` reported map `249` as PRESENT before the new map's gossip state had refreshed. Version 0.2.21 fixes that by treating `1527` as direct PRESENT evidence and `249` as direct PAST evidence. Uldum-related maps `1330` and `1571` remain registered but unclassified until their live role is observed.

### Live-confirmed Arathi Highlands behavior

Current Retail testing has now covered all three useful Arathi states:

- `2372 / Arathi Highlands` = **PRESENT / Current Arathi Highlands**.
- `14 / Arathi Highlands` can be the **FOURTH WAR / Warfront era** state when Zidormi offers both the before-war and present-time destinations.
- `14 / Arathi Highlands` is also reused for **PAST / Before Fourth War**; in that state Zidormi offers a return to the Highlands during the Fourth War.

The addon therefore does not treat map `14` alone as enough to distinguish the two older Arathi states. It uses Zidormi's available destinations and the selected destination to distinguish PAST from FOURTH WAR, while map `2372` is a direct current-present signal.

Arathi timeline labels are:

- `PAST / Before Fourth War`
- `FOURTH WAR / Warfront era`
- `PRESENT / Current Arathi Highlands`

## Zidormi/Rhonormu detection

For normal two-state locations, Azeroth Questing reads the offered timeline gossip option as a phase clue. A return/back-to-present option means the player is in the older state; wording such as before, past, show me, relive, during, or age of can indicate an older destination.

Arathi uses its dedicated three-state handler rather than forcing those options into a two-state present/past model.

Manual overrides remain available as a fallback:

- `/aq phase auto`
- `/aq phase past`
- `/aq phase present`

## Stable diagnostics

`SlashDiagnostics.lua` loads last so timeline/map testing commands cannot accidentally fall through to Core.lua's default show/hide behavior.

- `/aq phase` — current timeline, source, map ID, and map name.
- `/aq maps` — current map plus local learned quest count.
- `/aq mapid` — live map ID/name.
- `/aq inspect` — current map/parent map plus instance, difficulty, LFG, scenario, faction, and timeline context.
- `/aq check` — map ID/name, timeline/source, learned quest count, current-session Wago phase/map/visit/instance counts, and dashboard discovery-switch count.
- `/aq debug` — alias for `/aq check`.

## Phase learning

`ZoneQuestGuideDB.phaseLearning` stores quest evidence when Azeroth Questing has a reliable historical-phase signal. Available, offered, accepted, active, and turned-in observations can be stored locally; accepted-only evidence is considered weak because a quest can remain accepted after changing maps or timelines.

Learned observations are evidence only and are not automatically promoted into curated quest-phase requirements.

## Community reporting

### Manual Google Form

Current contribution form:

`https://forms.gle/Gnqf8kN44kDZxMs86`

The addon can remind the player when useful data exists, but the player chooses whether to copy and submit the manual export.

### Wago Analytics

Configured project ID: `EGPeM3N1`.

When WagoAnalytics is available, Azeroth Questing can contribute anonymous evidence while the player uses the addon normally:

- **Phase quest evidence:** map ID, faction, reliable phase, quest ID, `seen`/`available`/`offered`/`accepted`/`active`/`turnedIn` evidence type, completion support, and phase source.
- **Map/quest evidence:** map ID, faction, quest ID, the same six evidence classes, and completion support even when no historical phase is known.
- **Map visits:** map ID + faction, once per map/faction during the UI session.
- **Phase visits:** map ID + faction + reliable Zidormi/detected phase/source.
- **Instance visits:** map ID, parent map ID, instance ID, difficulty ID, LFG ID, maximum/group-size values, scenario type/area/texture-kit context, instance type, faction, and timeline/source when available.
- **Dashboard discovery switches:** privacy-safe mirrors of map, reliable-phase, quest-evidence, and instance observations using `seen_map_...`, `seen_phase_...`, `seen_quest_...`, `seen_mapquest_...`, and `seen_instance_...` names.

Version 0.2.26 expands the Wago stream to carry the research evidence that previously existed only in the local export. `available` remains useful but is explicitly preserved as an API/map hint rather than being promoted to proof of quest existence. `accepted` remains explicitly weak because the quest can have been picked up elsewhere. NPC `offered`, NPC `active`, and `turnedIn` observations are the stronger evidence used when deciding whether a quest genuinely exists in a specific timeline.

Completion is reported as a numeric Wago counter associated with the quest/map context, allowing `0` and `1` support to be retained separately from the evidence counters. Every reported quest also produces a generic `seen` observation, matching the local export's structure more closely.

Wago's Analytics **Counters** page currently reports that its dashboard will be released later, while the **Switches** dashboard is already available. Counters remain the complete research stream. Quest discovery switches are a visibility layer and are limited to 150 per UI session inside the existing 200 total discovery-switch cap, leaving room for map/phase/instance fingerprints even during long questing sessions.

Reliable phase telemetry still requires a `zidormi` or `detected` source; manual phase overrides are not promoted into community telemetry. Taxi-flight map scans remain suppressed.

Character names, realms, guild names, GUIDs, account identifiers, quest names, map names, instance names, difficulty names, scenario names, coordinates, timestamps, chat, party/raid member names, and manual phase overrides are not included in Wago metric or discovery-switch names. Stable numeric IDs and non-name context are used instead wherever possible.

- `/aq wago` — show Wago bridge status and this UI session's queued counters/discovery switches.
- `/aq telemetry` — alias for `/aq wago`.

The Wago App was observed with **Support Addon Developers** enabled and its Developers page reporting a transmitted analytics timestamp. The Wago website then displayed AzerothQuesting's existing custom feature switches, confirming that switch data reached the Analytics dashboard. The v0.2.26 quest-evidence switches, completion counters, accepted/seen stream, and richer instance fingerprint still require post-update in-game testing.

Wago upload still depends on the player's Wago App Analytics-sharing setting. No downloadable Wago release has been published yet, so **GitHub remains the only listed distribution platform**.

## Navigation HUD

The floating navigation HUD stays visible independently of the main quest list. It shows the selected target/status, rotates toward the destination when WoW exposes usable position/facing data, and shows distance when usable map/world-position data is available.

- Shift-drag to move it.
- `/aq arrow` toggles it.
- `/aq arrow reset` restores the default position.

Azeroth Questing does not calculate movement-speed ETA because current Retail clients can expose movement speed as a protected/secret value.

## Quest automation

Quest automation defaults to OFF. Open `/aq options` to control:

- **Auto accept quests**
- **Auto turn in completed quests**

Quests with meaningful reward choices remain open for manual selection. Holding Shift while interacting with an NPC temporarily bypasses automation.

## Commands

- `/aq`, `/aq show`, `/aq hide`, `/aq refresh`, `/aq auto`
- `/aq minimap`
- `/aq arrow`, `/aq arrow reset`
- `/aq options`, `/aq autoaccept`, `/aq autoturnin`, `/aq autocomplete`
- `/aq phase`, `/aq phase auto`, `/aq phase past`, `/aq phase present`
- `/aq learn`, `/aq maps`, `/aq mapid`, `/aq inspect`, `/aq check`, `/aq debug`
- `/aq export`, `/aq mapexport`, `/aq instanceexport`, `/aq contribute`
- `/aq wago`, `/aq telemetry`

## GitHub ZIP packages

GitHub's built-in **Code -> Download ZIP** is a source archive and uses a branch suffix such as `AzerothQuesting-main.zip`. The repository's GitHub Actions packaging workflow produces a versioned package such as **AzerothQuesting-0.2.29.zip** containing a top-level `AzerothQuesting/` addon folder.

## Rename from Zone Quest Guide

Version 0.2.29 changes the public addon, repository, package, and AddOn List name to **Azeroth Questing**. The internal account-wide SavedVariables table intentionally remains `ZoneQuestGuideDB` in this release to make the rename less disruptive.

WoW names the SavedVariables file after the addon folder, so an existing `WTF/Account/<ACCOUNT>/SavedVariables/ZoneQuestGuide.lua` file is not automatically loaded by the new `AzerothQuesting` folder. To keep existing settings and learned data, exit WoW and copy that file to `AzerothQuesting.lua` before the first launch of the renamed addon. Do not enable the old ZoneQuestGuide addon folder and AzerothQuesting at the same time.

## Install

1. Exit World of Warcraft.
2. Download the packaged `AzerothQuesting-<version>.zip` or a GitHub Release ZIP.
3. Place the top-level `AzerothQuesting` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
4. Start WoW and enable **Azeroth Questing**.
5. Use `/aq` if the panel is hidden. Legacy `/zq` commands remain supported.
## Important limitations

WoW's live addon APIs do not reliably expose every historical unaccepted side quest. Map/quest and instance learning record evidence, not automatic proof that a quest or instance belongs exclusively to one map/timeline/difficulty. In particular, `C_QuestLine.GetAvailableQuestLines()` can expose a quest in more than one timeline, so `available` observations are treated as hints rather than phase-existence proof. Wago counters and discovery switches are aggregated evidence and still require confidence-aware review before being promoted into curated quest requirements.

Supplemental `blockedBy` and `exclusiveWith` rules are curated relationships, not relationships inferred automatically from completion history. Incorrect quest IDs could hide a valid supplemental quest, so they should be added only from reliable evidence.

## In-game/test plan for v0.2.29

1. Remove or disable the old `ZoneQuestGuide` addon folder so both copies cannot load together. If existing local settings/learning data matter, copy `ZoneQuestGuide.lua` to `AzerothQuesting.lua` while WoW is closed before launching the renamed addon.
2. Start Retail WoW, confirm **Azeroth Questing** appears in the AddOn List, then `/reload` and verify there are no Lua errors.
3. Confirm `/aq` opens/hides the main window and `/aq refresh` works. Also confirm the legacy `/zq` alias still reaches the same command handler.
4. Verify the minimap button, navigation HUD, options window, export windows, quest ordering, Auto Accept/Auto Turn-in, and `/aq check` still work under the new addon folder/TOC name.
5. Continue the outstanding v0.2.28 breadcrumb test: when a known breadcrumb/later-quest pair is obtainable, confirm the breadcrumb is preferred and the later quest warns/pauses Auto Accept until the breadcrumb is accepted or completed.
6. If Wago Analytics is enabled, run `/aq wago` and confirm the bundled shim still registers project `EGPeM3N1` after the addon rename.

Version 0.2.29 has not yet been tested in World of Warcraft. GitHub packaging success is not an in-game test.
## Roadmap

- Use crowd evidence to distinguish quests genuinely offered in PAST/PRESENT/Fourth-War states from quests that Blizzard only exposes as map/API hints.
- Use dashboard-visible discovery switches and collected instance fingerprints to identify Warfront/scenario map IDs and Normal/Heroic differences without requiring one developer character to visit every variant.
- Use collected map/quest associations to discover more Retail map aliases automatically.
- Validate remaining Zidormi/Rhonormu timeline zones in-game, especially Darkshore, Dustwallow Marsh, Vale of Eternal Blossoms, and Peak of Serenity.
- Identify the live role of alternate timeline-related map IDs such as Tirisfal `1247`, Uldum `1330`/`1571`, and Silithus `1321`/`2354`.
- Add curated `blockedBy` and `exclusiveWith` relationships as real breadcrumb and mutually exclusive quest cases are identified.
- Review Wago map/quest, visit, instance, and discovery-switch telemetry volume/cardinality before the first public Wago release.
- Automate review/import of trusted Google Form submissions.
- Expand curated phase-exclusive quest mappings and supplemental quest-chain coverage.

## Release notes

See [`CHANGELOG.md`](CHANGELOG.md).
