# Azeroth Questing Changelog


**VERSION 0.3.0 Beta 22 - September 12, 2026 - Available on GitHub Pre-release**

* **Fixed** available quest-line suggestions from other maps leaking into the current Azeroth Questing zone list. During Beta 21 testing in **Valley of Trials (UiMapID 461)**, Blizzard's quest-line query exposed **Club Foote** and **Find Baron Longshore** even though their starters belong outside the current starting-area map.

* **Improved** current-map filtering by using Blizzard's `QuestLineInfo.startMapID` when it is available. A quest-line starter whose known start map differs from the player's current UiMapID is no longer added as a current-zone available quest or selected by Guide Mode/hub routing.

* **Kept** live NPC-observed quests, accepted quests that WoW reports on the current map, curated current-map supplemental quests, map research/AQM2, Azeroth Questing Network, Companion synchronization, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only filtering fix.

*Beta 22 still requires in-game validation. In Valley of Trials on Map ID 461, verify **Club Foote** and **Find Baron Longshore** no longer appear as current-zone pickups, normal Valley of Trials quests still appear, entering the quests' actual map later can surface them normally, hub routing does not point outside the current map, and no Lua/taint errors occur. No successful Beta 22 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 21 - September 12, 2026 - Available on GitHub Pre-release**

* **Added** the current Blizzard **UiMapID** to the main Azeroth Questing window's zone line, so testers can see the live map identity beside the zone name without opening chat diagnostics.

* **Added** a compact **Map ID** readout to the floating navigation HUD while a guide target is active. This keeps the current UiMapID visible during normal guide play even when the main quest-list window is closed.

* **Changed** the navigation HUD status layout slightly to reserve space for the map-ID readout without replacing the existing quest status, objective, arrow, distance, or hub-progress information.

* **Kept** `/aq map`, AQM2 map research, Azeroth Questing Network, Companion synchronization, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only display change.

*Beta 21 still requires in-game validation. In Valley of Trials, verify the main panel and compact HUD show Map ID 461, verify the value follows real map transitions/reloads, confirm the quest-status text still fits cleanly beside the HUD readout, and confirm no Lua/taint errors occur. No successful Beta 21 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 20 - September 12, 2026 - Available on GitHub Pre-release**

* **Added** Zygor-style **quest hub steps**. When the current guide action is a pickup or a ready turn-in, Azeroth Questing can keep up to six safe nearby pickup/turn-in actions together instead of routing the player away after each individual quest.

* **Improved** hub ordering so ready turn-ins are handled before nearby pickups, allowing the guide to finish completed work at the NPC/hub and then continue through available quests before moving on to normal quest objectives.

* **Changed** the compact navigation HUD to use one hub-action count for its group status and progress. Pure pickup hubs can show **PICK UP N QUESTS**, pure turn-in hubs can show **TURN IN N QUESTS**, and mixed hubs can show **QUEST HUB - N ACTIONS**, with a separate **N of N hub actions** line and the next action when known.

* **Fixed** the inconsistent pickup display observed during Beta 19 testing where the HUD could show one group total at the top while a different pickup total appeared underneath. Beta 20 clears the old pickup-only guide annotations and derives the visible hub count from the same active hub state.

* **Protected** known breadcrumb, mutually exclusive, and blocked pickup relationships from unsafe batching. Turn-ins may share a hub with pickups, but two available quests with known lockout relationships remain separate guide steps.

* **Kept** the main Azeroth Questing quest-list window optional and closable. Guide selection, the compact arrow, `/aq guide next`, and `/aq guide back` continue to work without requiring the large quest list to stay open.

* **Kept** map research/AQM2, Azeroth Questing Network, Companion synchronization, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only guide-flow change.

*Beta 20 still requires in-game validation. Re-test the Orc starting-area example from Beta 19 and verify an all-pickup hub uses one consistent total, a mixed turn-in/pickup hub completes the turn-in before the pickup, the arrow retargets after each action, the guide proceeds to quest objectives after the hub is finished, the main quest-list window may remain closed, and no Lua/taint errors occur. No successful Beta 20 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 19 - September 12, 2026 - Available on GitHub Pre-release**

* **Added** richer Blizzard-backed map identity evidence for phased and scenario content. Map research can now capture parent-map name, map-art ID, scenario name and current scenario step, difficulty name, player map position, and the previous UiMapID seen during the current play session in addition to the existing UiMapID/instance/phase context.

* **Added** the backward-compatible `AQM2` research record. Beta 19 still writes the original `AQM1` record for older Companions, while `AQM2` appends the richer map-identity fields under the same observation key so updated Companions can prefer the more complete copy without creating duplicate observations.

* **Improved** `/aq map` and `/aq map record` to show the evidence a tester can use to identify a map copy: Blizzard map and parent names/IDs, map-art ID, scenario and step, instance and difficulty context, coordinates, previous UiMapID, and any known Azeroth Questing phase evidence.

* **Added** local map-identity confidence output to `/aq map`: **CONFIRMED** when Blizzard directly exposes a scenario name (or a named scenario instance), **LIKELY** when phase/instance context strongly distinguishes the copy, and **UNKNOWN** when the addon has only generic map metadata. The addon does not hard-code guesses for Battle for Darkshore, Battle for Stromgarde, or other phased zones.

* **Improved** automatic collection by recording again when scenario state or player difficulty changes, while keeping session deduplication so movement coordinates alone do not create a stream of duplicate observations.

* **Compatibility:** the original `AQM1` handoff remains available. Uploading the new `AQM2` evidence requires **Azeroth Questing Companion 0.1.9-beta.12 or newer** and **Azeroth Questing Server 0.2.12 / schema 5 or newer**. No Website build is required; the LAN Research Map IDs tab is provided by the Azeroth Questing Server.

*Beta 19 still requires in-game validation. Verify `/aq map` does not cause Lua/taint errors, scenario/map-art/parent/coordinate fields appear only when WoW safely exposes them, previous-UiMapID transitions are sensible, and Battle for Darkshore / Battle for Stromgarde observations gain enough evidence to move from UNKNOWN to LIKELY or CONFIRMED without hard-coded assumptions. End-to-end AQM2 synchronization also remains to be verified with Companion Beta 12 and Server 0.2.12. No successful Beta 19 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 18 - September 12, 2026 - Available on GitHub Pre-release**

* **Added** privacy-preserving **UiMapID research tracking** so Azeroth Questing can learn the different map copies used by phased and scenario content such as **Battle for Darkshore** and **Battle for Stromgarde** instead of treating every appearance of the zone as one map.

* **Added** automatic map-context observations on world entry, zone/map transitions, indoor map changes, and player phase changes. Each identity-free observation can include the current UiMapID, map name, parent UiMapID, UI map type, WoW instance name/type, difficulty ID, instance ID, faction, class, level, known Azeroth Questing timeline/phase label, observation time, and addon version.

* **Added** session deduplication for map research. The same exact map/instance/phase context is recorded once per login session, while a different UiMapID, instance, difficulty, or known timeline context becomes a separate research observation.

* **Added** `/aq map` (also `/aq map id` and `/aq mapid`) to show the current UiMapID and useful map/instance context in chat, plus `/aq map record` to deliberately record the current context again when testing a phased map.

* **Added** the `AQM1` SavedVariables handoff for map research. The record intentionally excludes character name, realm, GUID, BattleTag, account identity, peer sender identity, and local filesystem paths. Existing `AQO1`/`AQO2` quest research and P2P quest evidence are unchanged.

* **Compatibility:** automatic server upload of `AQM1` observations requires **Azeroth Questing Companion 0.1.9-beta.11 or newer** and **Azeroth Questing Server 0.2.9 or newer**. No Website build is required for this addon change; the LAN Azeroth Questing Research dashboard is provided by the server.

*Beta 18 still requires in-game validation. Verify `/aq map` reports the expected UiMapID, normal zone changes do not cause Lua/taint errors, and multiple Battle for Darkshore / Battle for Stromgarde variants are recorded as their actual UiMapIDs. End-to-end Companion/server synchronization also remains to be verified after Server 0.2.9 is deployed. No successful Beta 18 in-game or live-server test is claimed yet.*

---

**VERSION 0.3.0 Beta 17 - September 12, 2026 - Available on GitHub Pre-release**

* **Added** Zygor-style pickup batches to Guide Mode. When the current guide step is an available quest and other compatible available quests are in the same nearby quest hub, Azeroth Questing groups up to four of them into one pickup sequence instead of immediately leaving after the first acceptance.

* **Changed** the compact navigation HUD to show **PICK UP N QUESTS** for a pickup batch, point to the first quest giver, then immediately retarget the next remaining pickup after each quest is accepted. Once the batch is complete, Guide Mode returns to the accepted quest flow and routes toward objectives/turn-ins as before.

* **Added** pickup progress context under the arrow, such as **1 of 2 pickups** and the next quest name when another pickup remains, while keeping the full Azeroth Questing quest-list window optional and closable.

* **Protected** breadcrumb and mutually exclusive quest behavior by refusing to combine nearby quests into one pickup batch when known `skippedBy`, `exclusiveWith`, or `blockedBy` relationships indicate they should remain separate steps.

* **Kept** the Beta 16 lightweight Guide Mode approach: closing the main quest-list window does not disable guide selection or the compact navigation HUD. Quest-frequency tabs, research data, P2P networking, Companion handoff, Website behavior, and Azeroth Questing Server schema are unchanged, so no Companion, Website, or server build is required.

*Beta 17 still requires in-game validation. Test a hub with at least two nearby available compatible quests: confirm the HUD says **PICK UP 2 QUESTS**, points to the first pickup, changes to the second pickup immediately after accepting the first, then changes to an objective/turn-in step after both are accepted. Repeat with the main quest-list window closed and verify the guide continues without Lua/taint errors. No successful in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 16 - September 12, 2026 - Available on GitHub Pre-release**

* **Changed** Guide Mode to stop opening the large separate **Azeroth Questing Guide** window added in Beta 14. The guide now runs as a lightweight controller behind the compact navigation HUD instead of adding another boxed tracker to the game screen.

* **Kept** Zygor-style step behavior: Azeroth Questing still follows one selected quest, updates the waypoint as quest state changes, advances after completed/turned-in quests disappear from the current list, and supports manual **Back** / **Next** selection through `/aq guide back` and `/aq guide next`.

* **Kept** the compact Beta 15 navigation presentation as the visible guide surface: directional arrow, current objective/pickup/turn-in wording, quest context, and distance. The normal Azeroth Questing quest list remains available separately when the player wants the full list.

* **Changed** `/aq guide`, `/aq guide on`, and `/aq guide off` to control the automatic guide-selection behavior without showing or hiding a second large frame. Status feedback is written to chat instead.

* **Kept** quest-frequency tabs, quest research, P2P networking, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only Guide Mode UI change.

*Beta 16 still requires in-game validation. Confirm no large Azeroth Questing Guide window appears after login/reload, the compact navigation HUD still follows the selected quest and objective, `/aq guide next` and `/aq guide back` change the guide target, quest turn-in advances normally, and no Lua/taint errors occur. No successful Beta 16 in-game test is claimed yet.*

---
**VERSION 0.3.0 Beta 15 - September 11, 2026 - Available on GitHub Pre-release**

* **Redesigned** the floating navigation HUD to be much closer to the compact guide-arrow presentation shown in the in-game comparison: a large filled bright-green directional arrow, minimal translucent backing, centered objective text, and distance immediately underneath instead of a large boxed tracker dominating the screen.

* **Improved** the navigation label so accepted quests prefer the first unfinished WoW objective (for example, a collect/kill instruction) while available quests say **Pick up <quest>** and completed accepted quests say **Turn in <quest>**. The quest name remains visible beside the distance for context.

* **Improved** arrow readability with a dark shadow/outline and text shadows so the HUD stays readable against bright outdoor zones without restoring the heavy panel appearance.

* **Changed** direction rendering to use Blizzard's built-in minimap arrow texture and rotate it toward the existing Azeroth Questing target. If a safe direction cannot be calculated, the arrow hides rather than showing a stale or misleading heading.

* **Kept** movement-speed/ETA calculation out of the HUD because current Retail can expose movement speed as a protected/secret value. Distance remains map-position based, avoiding the taint issue while still providing the useful yard count.

* **Kept** Guide Mode progression, quest-frequency tabs, Azeroth Questing Network protocol, research payloads, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only visual/navigation change.

*Beta 15 still requires in-game validation. Verify the green arrow is visible and rotates toward a known quest destination, an active quest shows its current unfinished objective when WoW exposes one, available/turn-in wording is correct, distance remains sensible, Shift-drag positioning still works, and no Lua/taint errors occur. No successful Beta 15 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 14 - September 11, 2026 - Available on GitHub Pre-release**

* **Added** an optional Zygor-style **Guide Mode** that presents one quest step at a time instead of requiring the player to work from the full zone list. The compact guide shows the current quest, its live status, up to four objective lines when WoW exposes them, and a simple instruction to pick up, complete, or turn in the quest.

* **Added** automatic step progression. Guide Mode stays on the same quest as it moves from **AVAILABLE** to **IN PROGRESS** to **TURN IN**, then advances to the next unfinished quest after the completed quest leaves the active list. Completed quests are skipped by the existing completion/prerequisite filtering.

* **Added** **Back**, **Next**, **Quest List**, and **Show Zone Quests / Show Daily / Weekly** controls so players can move through the guide manually, reopen the full quest list, or switch the Beta 13 frequency view without leaving Guide Mode. Manual quest-row selection also synchronizes the compact guide target.

* **Improved** navigation integration by routing Guide Mode targets through the existing Azeroth Questing waypoint/navigation HUD pipeline. Accepted quests use WoW quest super-tracking; known unaccepted quest coordinates continue to use the addon's waypoint arrow behavior.

* **Added** `/aq guide`, `/aq guide on`, `/aq guide off`, `/aq guide next`, and `/aq guide back` controls. Guide Mode is enabled by default for new/upgraded Beta 14 settings and remembers its screen position and whether the player closes it.

* **Kept** the Azeroth Questing Network protocol, research payloads, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only guide-view change.

*Beta 14 still requires in-game validation. Verify Guide Mode opens without Lua errors, follows an available quest through accept/objectives/turn-in, automatically advances after turn-in, Back/Next and the Zone vs Daily/Weekly switch work, the Quest List button remains usable, and the existing navigation HUD points to the selected guide step. No successful Beta 14 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 13 - September 11, 2026 - Available on GitHub Pre-release**

* **Added** two switchable quest views to the main Azeroth Questing panel: **Zone Quests** for normal frequency-1 quests and **Daily / Weekly** for repeatable frequency-2 and frequency-3 quests. The selected tab is remembered locally for the player.

* **Added** explicit weekly-quest classification alongside the existing daily handling. Azeroth Questing now normalizes quest-frequency information from gossip, quest-log, map, and quest-line APIs into one internal model: **1 normal**, **2 daily**, **3 weekly**.

* **Improved** repeatable quest readability by labeling rows with **[Daily]** or **[Weekly]** in the Daily / Weekly tab while keeping campaign/local-story badges intact.

* **Changed** filtering, quest counts, and auto-point behavior to follow the currently selected tab so switching to Daily / Weekly navigates within repeatable quests instead of continuing to point at a hidden normal zone quest.

* **Kept** the Azeroth Questing Network protocol, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only UI/classification change.

*Beta 13 still requires in-game validation. Verify the Zone Quests tab shows normal quests, the Daily / Weekly tab shows known blue daily/weekly quests with the correct badge, switching tabs updates the count and auto-point target, and no Lua errors occur. No successful Beta 13 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 12 - September 11, 2026 - Available on GitHub Pre-release**

* **Fixed** overlapping Azeroth Questing Network copies not being deduplicated reliably across multiple WoW transports. During the Beta 11 in-game overlap test, one peer's **Messages** count increased from **9 to 12** after the same logical AZQUEST hello was sent through **PARTY**, **GUILD**, and the custom **CHANNEL**, showing that all three copies were processed instead of one.

* **Improved** inbound duplicate matching by canonicalizing the sender identity before building the deduplication key. Short same-realm names and full `Name-Realm` forms now resolve to a consistent lowercase `name@realm` identity, with realm spaces, hyphens, and apostrophes normalized so transport-specific sender formatting cannot split one peer into separate deduplication keys.

* **Increased** the inbound overlap window from **10 seconds to 20 seconds** so delayed copies from separate WoW transports can still collapse into one logical message. This remains below the addon's normal 30-second hello cadence, so the next scheduled hello can still refresh peer activity normally.

* **Kept** the AZQUEST wire payload, privacy model, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only fix.

* **Verified in World of Warcraft** that Beta 12 fixes the overlapping-transport duplicate-processing failure found in Beta 11. In the same controlled two-account setup, with **PARTY**, **GUILD**, and custom **CHANNEL** all available, the unique AZQUEST overlap test was repeated and the receiving peer's **Messages** count increased from **2 to 3** instead of by three. This confirms the Beta 12 inbound deduplication change collapses the overlapping copies into one logical peer message in the tested live Retail session. No claim is made here about transports or directions not separately tested above.

---

**VERSION 0.3.0 Beta 11 - September 11, 2026 - Available on GitHub Pre-release**

* **Fixed** the Retail TOC interface metadata introduced in Beta 10. Beta 10 incorrectly changed the addon from live Retail interface `120100` to `120105`; as of September 11, 2026, live Retail Midnight 12.1.0 uses `120100`, while `120105` belongs to the 12.1.5 PTR/test client. That future interface value could cause the live Retail client to skip loading Azeroth Questing, making the addon and its Settings page disappear.

* **Restored** `AzerothQuesting.toc` to live Retail interface `120100` and advanced the addon version to `0.3.0-beta.11` because Beta 10 had already been published and consumed before the compatibility mistake was identified.

* **Kept** the Beta 10 Azeroth Questing Network fix unchanged: PARTY, RAID, INSTANCE_CHAT, GUILD, and custom-channel addon messages are still allowed to reach `C_ChatInfo.SendAddonMessage()` unless the real chat-messaging lockdown is active.

* **Kept** the `AZQUEST` protocol, privacy model, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon compatibility correction.

* **Verified in World of Warcraft** that Beta 11 loads again on live Retail and that the **GUILD** transport works bidirectionally across both faction and realm boundaries. After both clients were fully logged out and logged back in to clear the session-only peer list, the Alliance client started at **Connected now: 0 players**; when `Moralni-Bonechewer` came online in the same guild while the characters were not grouped, it updated to **1 player** and showed Moralni on `0.3.0-beta.11`. The reverse Horde-side test also started at **0 players** and then updated to **1 player**, showing `Frostlendian-BleedingHollow` after that Alliance character came online. This confirms fresh, bidirectional **cross-faction + cross-realm GUILD peer discovery** rather than a leftover PARTY/session-cache result. Remaining transport validation still includes the reverse cross-faction PARTY direction and final custom-channel/deduplication checks before Stable approval.*

* **Verified in World of Warcraft** that the **PARTY** transport also works across both faction and realm boundaries in the tested Alliance-to-Horde direction. With the Alliance client grouped with `Moralni-Bonechewer` on a different realm and running `0.3.0-beta.11`, **Connected Players** showed **1 player** with a fresh Last Seen value. This confirms live cross-faction + cross-realm PARTY peer discovery from the Alliance client. The reverse Horde-to-Alliance direction has not yet been separately evidenced, so bidirectional cross-faction PARTY is not claimed yet.

* **Verified in World of Warcraft** that the **INSTANCE_CHAT** transport is actually carrying `AZQUEST` addon traffic in a Follower Dungeon instance group. `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` returned `true`, and an independent `CHAT_MSG_ADDON` watcher captured live `AZQUEST RECEIVED: INSTANCE_CHAT` events, including `Moralni-Bonechewer`. The same watcher also saw overlapping `GUILD` and custom `CHANNEL` copies from another peer, proving that the instance transport itself was active rather than merely inferred from the Connected Players list. This verifies live **INSTANCE_CHAT** delivery; bidirectional INSTANCE_CHAT is not separately claimed from this single watcher capture.

* **Verified in World of Warcraft** that the **RAID** transport is carrying `AZQUEST` addon traffic in a manually converted raid group. After the party was converted to a raid, an independent `CHAT_MSG_ADDON` watcher captured repeated live `AZQUEST RECEIVED: RAID` events from the other Azeroth Questing client. The same watcher also showed overlapping `GUILD` and custom `CHANNEL` copies, confirming that the RAID transport itself was active rather than merely inferred from peer visibility. This verifies live **RAID** delivery in the tested direction; bidirectional RAID is not separately claimed from this single watcher capture.

---

**VERSION 0.3.0 Beta 10 - September 11, 2026 - Available on GitHub Pre-release**

* **Fixed** Azeroth Questing Network PARTY, RAID, INSTANCE_CHAT, GUILD, and custom-channel delivery being blocked on normal Retail realms before `C_ChatInfo.SendAddonMessage()` was called. Beta 9 incorrectly treated `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` as a blanket addon-protocol transport restriction.

* **Verified the Beta 9 failure mode in World of Warcraft** with two simultaneously logged-in accounts. The same-faction party test reported `IsInGroup() = true`, `InChatMessagingLockdown() = false`, and `AreOutgoingAddonChatMessagesRestricted() = true`, while a direct `C_ChatInfo.SendAddonMessage("AZQUEST", ..., "PARTY")` call returned result `0` (Success). This demonstrated that WoW accepted the PARTY addon message while Beta 9's own pre-send guard suppressed its queued hello/evidence traffic.

* **Changed** the network preflight to gate only on the actual `InChatMessagingLockdown()` state and otherwise call `SendAddonMessage`, allowing its result code and the existing throttle/retry handling to decide whether a transport send is accepted.

* **Updated** the Retail TOC interface metadata from `120100` to `120105` for the current 12.1.5 client and changed the addon version from `0.3.0-beta.9` to `0.3.0-beta.10` because Beta 9 had already been published and consumed before this live PARTY test found the blocker.

* **Kept** the `AZQUEST` wire protocol, privacy model, peer deduplication, Companion handoff, and Azeroth Questing Server schema unchanged. No Companion, Website, or Azeroth Questing Server build is required for this fix.

*Beta 10 has not yet been tested inside World of Warcraft. After updating both test clients, verify a same-faction PARTY peer appears on both clients, repeat across realms, then test Horde/Alliance in a supported cross-faction party. Confirm Connected Players and `/aq peers` show one peer rather than duplicates and that no Lua errors occur. No successful Beta 10 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 9 - September 11, 2026 - Available on GitHub Pre-release**

* **Added** multi-transport Azeroth Questing Network delivery. In addition to the existing `AzerothQuesting` custom channel, the addon now sends the same `AZQUEST` hello and anonymous quest-evidence protocol through the currently applicable **PARTY**, **RAID**, **INSTANCE_CHAT**, and **GUILD** addon-message transports. This allows Alliance and Horde Azeroth Questing clients to exchange research when WoW places them in a supported shared cross-faction group, instance group, raid, or guild.

* **Improved** transport scheduling so group/instance and guild deliveries are queued ahead of the same-faction custom-channel copy and only one addon transmission is attempted per existing send tick. This preserves the existing throttle-aware queue instead of multiplying several sends into one tick.

* **Added** a short session-only inbound deduplication window keyed by sender and protocol message. When overlapping transports deliver the same `AZQUEST` payload to one client, it is processed once so a party/guild/channel fan-out does not create duplicate Companion research observations. The deduplication cache is memory-only and is cleared on `/reload` or logout.

* **Improved** the **Connected Players** Settings page and `/aq peers` diagnostics to recognize peers heard through all supported Azeroth Questing transports rather than only the custom channel. Player names remain session-only and are not added to SavedVariables or uploaded to the Azeroth Questing Server.

* **Kept** the network payload protocol and Companion/server research schema unchanged. No Companion, Website, or Azeroth Questing Server build is required specifically for multi-transport peer delivery; existing anonymous `source = "peer"` observations continue through the same Companion queue.

* **Changed** the addon version from `0.3.0-beta.8` to `0.3.0-beta.9` because Beta 8 had already been published/consumed before cross-faction shared-context transport was approved.

*This v0.3.0 Beta 9 multi-transport behavior has not yet been tested inside World of Warcraft. Test an Alliance and Horde client running Beta 9 in a supported cross-faction party/raid/instance group and, separately if available, a cross-faction guild. Verify `/aq peers` and **Settings > AddOns > Azeroth Questing** can see the opposite-faction peer, a quest-evidence event is accepted once rather than once per overlapping transport, the existing same-faction custom-channel path still works, and leaving the shared WoW context removes that direct cross-faction path. Azeroth Questing still cannot directly discover arbitrary opposite-faction players who share no WoW-supported group/guild context; global aggregation continues through Azeroth Questing Companion and Azeroth Questing Server. No successful Beta 9 in-game or cross-faction test is claimed yet.*

---

**VERSION 0.3.0 Beta 8 - September 11, 2026 - Available on GitHub Pre-release**

* **Fixed** the Azeroth Questing entry failing to appear under **WoW Settings > AddOns** during the first in-game Settings test. The Connected Players page introduced in Beta 6 and still present in Beta 7 was not registered in the visible AddOns category in the reported live client session.

* **Improved** Settings registration to follow Blizzard's current addon Settings initialization pattern with `EventUtil.ContinueOnAddOnLoaded`, while also retrying at `PLAYER_LOGIN`, when Blizzard Settings components load, and briefly on a timer if the Settings API is not ready yet. One early unavailable-API check can no longer permanently skip the category for the rest of the UI session.

* **Kept** the Connected Players behavior and privacy model unchanged: active peers are still based on live `AZQUEST` traffic within the 90-second window, names remain session-only, and peer names are not saved to SavedVariables or uploaded to the Azeroth Questing Server.

* **Changed** the addon version from `0.3.0-beta.7` to `0.3.0-beta.8` because Beta 7 had already been published/consumed before the missing Settings category was reported.

*The screenshot from the live WoW client confirms the Beta 7-era Settings registration did not produce an **Azeroth Questing** entry in the AddOns list. Beta 8 has not yet been tested in World of Warcraft. After updating, verify **Settings > AddOns > Azeroth Questing** is visible, opens without Lua errors, the Connected Players section appears, and live peer presence still follows the existing 90-second behavior. No successful Beta 8 in-game test is claimed yet.*

---

**VERSION 0.3.0 Beta 7 - September 11, 2026 - Available on GitHub Pre-release**

* **Added** quest-title enrichment to normal Companion research observations. When Azeroth Questing knows a quest name from the live quest API or its account-wide Quest Catalog, it now records that title beside the quest ID so the Website Quest Repository can show the readable quest name instead of only `Quest <ID>`.

* **Added** backward-compatible `AQO2` research records for named quests. The existing `AQO1` record is preserved for older Companions, while `AQO2` carries the same anonymous observation key plus a hex-encoded UTF-8 quest title that cannot break the SavedVariables delimiter format.

* **Improved** research synchronization schema metadata from version 2 to version 3 without adding character name, realm, account identity, or peer sender identity. Quest titles are public game data and remain attached only to the anonymous quest observation.

* **Changed** the addon version from `0.3.0-beta.6` to `0.3.0-beta.7` because Beta 6 had already been published/consumed before research quest-title transport was requested.

*This v0.3.0 Beta 7 quest-title transport has not yet been tested inside World of Warcraft. Azeroth Questing Companion `0.1.9-beta.8` or newer is required to prefer and upload `AQO2` titles, and Azeroth Questing Server API `0.2.6` or newer is required to accept/store them. The Website Quest Repository already supports displaying and searching `quest_name`, so no Website build is required for this change. Verify a known named quest produces both AQO1 and AQO2 records after WoW saves SavedVariables, that older AQO1 observations still synchronize, and that no character/realm identity is added. No successful in-game, Windows runtime, live server, or production website test is claimed yet.*

---
**VERSION 0.3.0 Beta 6 - September 11, 2026 - Available on GitHub Pre-release**

* **Added** an **Azeroth Questing** page under WoW's **Settings > AddOns** with a **Connected Players** section. It shows Azeroth Questing peers this client has heard from within the existing 90-second active window, including player name, addon version when learned from the `AZQUEST` hello, and last-seen age.

* **Improved** connection visibility by refreshing the Settings list automatically while it is open and showing only currently active peers there. The existing `/aq peers` panel remains available for the fuller session diagnostic, including peers that have gone Idle and message counts.

* **Kept** connection-name privacy session-only. The Settings list mirrors live `AZQUEST` traffic in memory and does not write peer names to SavedVariables or send them to Azeroth Questing Companion, Wago Analytics, or the Azeroth Questing Server.

* **Changed** the addon version from `0.3.0-beta.5` to `0.3.0-beta.6` because Beta 5 had already been published/consumed before the Settings connection list was requested.

*This v0.3.0 Beta 6 Settings connection list has not yet been tested inside World of Warcraft. Verify **Settings > AddOns > Azeroth Questing** opens without Lua errors, two clients on the same reachable Azeroth Questing channel appear under Connected Players with sensible version/last-seen values, a disconnected client disappears after roughly 90 seconds, `/aq peers` still shows the full session diagnostic, and `/reload` clears the session-only name list. No successful in-game test is claimed yet.*

---
**VERSION 0.3.0 Beta 5 - September 10, 2026 - Available on GitHub Pre-release**

* **Added** a private **Addon-to-Companion completed-quest handoff** for the currently logged-in toon. Azeroth Questing now stores a compact `AQC1` snapshot in a per-character SavedVariables table, separate from the existing account-wide research data.

* **Added** automatic per-character completion snapshots shortly after login, after a quest turn-in, after a level change, and during logout. `/aq completed client` (also `/aq completed companion`) can force a fresh snapshot before `/reload` or logout. Because WoW addons cannot directly write arbitrary files while the game is running, WoW writes the handoff file during its normal SavedVariables save on `/reload` or logout, after which the Companion can read it.

* **Improved** completed-quest handoff metadata with faction, class, level, capture time, addon version, quest ID, and the quest title when WoW has it cached. Quest titles are byte-encoded inside the local wire record so punctuation and localized UTF-8 text cannot break the record format.

* **Kept** character identity private to the local PC. The `AQC1` payload does not contain character name or realm; Azeroth Questing Companion derives those values from WoW's local per-character SavedVariables folder. The completed-quest handoff is not sent over Azeroth Questing Network or Wago Analytics and is not placed in the anonymous research synchronization queue.

* **Changed** the addon version from `0.3.0-beta.4` to `0.3.0-beta.5` because Beta 4 had already been published/consumed before the Companion handoff was requested. The new handoff requires Azeroth Questing Companion `0.1.9-beta.6` or newer to import it.

*This v0.3.0 Beta 5 handoff has not yet been tested inside World of Warcraft. After both compatible Betas are installed, keep the Companion running, log into a toon, run `/aq completed client`, then `/reload` or log out. Verify the Companion reports the toon and completed-quest count, its local completed-quest TSV contains the expected rows, and merely importing the completed-quest snapshot does not increase Pending Observations or upload character identity to Azeroth Questing Server. No successful in-game, Windows runtime, or live handoff test is claimed yet.*

---
**VERSION 0.3.0 Beta 4 - September 10, 2026 - Available on GitHub Pre-release**

* **Added** a dedicated **current-character completed quest report**. Azeroth Questing now reads `C_QuestLog.GetAllCompletedQuestIDs()` for the currently logged-in character and reports the number of completed quests WoW exposes for that toon without mixing in merely learned, supplemental, active, or peer-observed quests.

* **Added** `/aq completed` to show the current character's completed-quest count and `/aq completed export` to open a copyable tab-separated report for Google Sheets. Each row includes **Character, Realm, Faction, Class, Level, Quest ID, Quest Name, and Addon Version** so exports from multiple toons can be kept distinguishable in a private sheet.

* **Kept** this personal completion report separate from anonymous research collection. Character and realm values used by the report are displayed only in the player's local manual export and are not sent through Azeroth Questing Network, Wago Analytics, Companion research synchronization, or the Azeroth Questing Server by this feature.

* **Changed** the addon version from `0.3.0-beta.3` to `0.3.0-beta.4` because Beta 3 had already been published and handed off for testing before the per-toon completed-quest report was requested.

*This v0.3.0 Beta 4 report has not yet been tested in World of Warcraft. After updating, log into a character, run `/aq completed`, then `/aq completed export`; confirm the count is plausible, the export contains only quests WoW reports completed for that current character, character/realm/class metadata is correct, and the selected tab-separated rows paste into Google Sheets without column drift. If some quest titles initially appear as `Quest <ID>`, leave the client running while the existing throttled catalog title loader fills more names and export again. No successful in-game or Google-Sheets paste test is claimed yet.*

---
**VERSION 0.3.0 Beta 3 - September 10, 2026 - Available on GitHub Pre-release**

* **Added** an account-wide **Quest Catalog** collector that merges every quest ID the live WoW client can actually expose for the current account/character with Azeroth Questing's existing learned and supplemental data. The catalog scans `C_QuestLog.GetAllCompletedQuestIDs()` for completed quest history, current quest-log entries for active quests, `mapQuestLearning` for quests learned from maps/NPCs/turn-ins, and `StaticQuests` for curated supplemental records.

* **Added** background quest-title enrichment for catalog records whose names are not already cached. Azeroth Questing requests missing quest data gradually instead of firing every request at once, keeps resolved names in the account-wide SavedVariables catalog, and can continue filling names across later scans/sessions.

* **Added** `/aq catalog`, `/aq catalog scan`, and `/aq catalog export` (plus `quests` aliases). The export is tab-separated for direct paste into Google Sheets and includes **Quest ID, Quest Name, Completed, Active, Sources, Map IDs, Factions, First Seen, Last Seen, and Addon Version**.

* **Changed** the addon version from `0.3.0-beta.2` to `0.3.0-beta.3` because Beta 2 had already been published/consumed before the quest-catalog feature was requested.

* **Clarified** the catalog's completeness boundary. WoW does not provide an addon API that enumerates every quest shipped in the game, so this is a broad **game-exposed catalog**, not a fabricated master list. A never-completed, currently unavailable quest that has never been observed by Azeroth Questing will not appear unless it is later exposed by WoW, learned in play, received as anonymous quest evidence, or added to supplemental data.

*The new v0.3.0 Beta 3 quest-catalog behavior has not yet been tested inside World of Warcraft. The pre-release preparation workflow successfully passed Lua source validation and package construction before intentionally stopping at release-note preparation while this changelog entry was still missing. After updating in WoW, run `/aq catalog scan`, confirm the unique/completed/active counts are plausible, allow missing titles time to resolve, run `/aq catalog export`, and paste the selected tab-separated text into Google Sheets cell A1. Verify the exported columns stay aligned, a known completed quest is marked Completed, an active quest is marked Active, no Lua/secret-value errors occur, and the catalog persists after `/reload`. No successful in-game catalog or Google-Sheets paste test is claimed yet.*

---
**VERSION 0.3.0 Beta 2 - September 9, 2026 - Available on GitHub Pre-release**

* **Added** a temporary **P2P Connections** diagnostic panel for the Azeroth Questing Network. `/aq peers`, `/aq p2p`, or `/aq network peers` opens a live session view showing Azeroth Questing characters from which the client has actually received `AZQUEST` traffic, including the peer's addon version when learned from its hello message, last-seen state, and message count.

* **Improved** P2P presence testing with a periodic hello announcement about every 30 seconds. A peer heard from within the last 90 seconds is labeled **Active**; older peers remain visible as **Idle** for the rest of the current UI session so temporary disconnect/reconnect behavior can be observed without pretending WoW exposes a permanent connection roster.

* **Improved** network privacy and protected-value handling for the temporary peer view. Character names are kept only in the addon's in-memory `sessionPeers` table, are cleared by `/reload` or logout, are never written to `ZoneQuestGuideDB`, are never added to Companion `AQO1` records, and are never uploaded to the Azeroth Questing Server. Peer quest evidence continues through the existing anonymous `source = "peer"` path without sender identity. Inaccessible protected string values are skipped before the diagnostic code performs string operations on incoming addon-message fields.

* **Changed** the Beta number from `0.3.0-beta.1` to `0.3.0-beta.2` because Beta 1 had already been handed off for testing before the P2P diagnostic panel was added. Beta 2 is therefore the next testable addon build under the Beta test-build numbering rule.

*This v0.3.0 Beta 2 P2P panel and periodic-presence behavior have not yet been tested in World of Warcraft. Test with two Retail clients that can see the same `AzerothQuesting` custom-channel scope: run `/aq network`, open `/aq peers` on both clients, allow up to 30 seconds or click **Announce / Refresh**, confirm each client appears with a version and updating last-seen value, generate quest evidence and confirm message counts rise, then disconnect one client and verify it becomes Idle after roughly 90 seconds. Reload the receiving UI and confirm the peer-name list is gone, then separately verify peer observations still reach the Companion/server as `source = "peer"` without sender identity. The outstanding v0.2.32 AQO1 synchronization and level-90 campaign-skip reminder checks also still require World of Warcraft testing. No successful in-game test is claimed.*

---
**VERSION 0.3.0 Beta 1 - September 8, 2026 - Development**

* **Changed** the addon development version from Stable `0.2.32` to canonical prerelease `0.3.0-beta.1`, starting the new **0.3.0 Beta** train. Player-facing tools may display this as **0.3.0 Beta 1**, while GitHub tags, packages, and updater comparisons continue to use the canonical prerelease version.

* **Changed** the planned next addon release line from `0.2.33` to `0.3.0`. Beta 1 was handed off for testing before later P2P diagnostic changes were made, so those later changes continue in Beta 2 rather than changing the contents of the Beta 1 test build.

*This initial v0.3.0 Beta 1 build changed version/release metadata only and did not add new gameplay behavior by itself. No new in-game test result is claimed. The outstanding v0.2.32 AQO1 synchronization and level-90 campaign-skip reminder checks still require World of Warcraft testing.*

---
**VERSION 0.2.32 - September 8, 2026 - Available on GitHub**

* **Added** a Companion-safe `AQO1` wire record to each new queued quest observation. The record contains the addon-generated observation key plus quest/map/evidence context, faction, class, level, completion state, timestamp, source, and addon version so **Azeroth Questing Companion** can extract structured research observations from SavedVariables without executing or generally parsing Lua.

* **Added** a level-90 **Midnight campaign-skip reminder** for eligible alts. The reminder explains that a character whose account has already completed the Midnight leveling campaign can go to **Wayfarer's Rest in Silvermoon** and talk to **Soridormi** to use the remaining-campaign skip. The window includes **Got it** and **Don't show again** controls, with `/aq skipreminder` and `/aq campaignskip` available to manage or reopen it.

* **Improved** the Companion synchronization store to schema version 2 so new structured observations can be handed to the Companion individually while older v0.2.31 queue entries remain readable as historical SavedVariables data.

* **Changed** the Companion/server handoff so individual observations can be deduplicated by their stable observation key instead of treating the entire SavedVariables file as one research record. `CampaignSkip.lua` was also added to the addon load list so the new reminder is part of the v0.2.32 package.

*The v0.2.32 changes were not confirmed through World of Warcraft testing. After updating, `/reload`, interact with quests, run `/aq sync`, and allow WoW to write `AzerothQuesting.lua`; verify new `companionSync.observations` entries contain an `AQO1|...` wire field and that the Companion can extract the records. On an eligible level-90 alt, also verify the campaign-skip reminder appears correctly, **Don't show again** persists, and `/aq skipreminder` or `/aq campaignskip` can re-enable/reopen it. GitHub remains the listed distribution platform; no CurseForge, Wago, or WowUp availability is claimed here.*

---
**VERSION 0.2.31 - September 8, 2026 - Available on GitHub**

* **Added** the first **Azeroth Questing Network** client layer. Retail clients register the `AZQUEST` addon-message prefix and automatically join the temporary custom channel `AzerothQuesting`. The channel is joined without adding protocol traffic to normal chat, while `/aq network` reports whether the prefix and custom channel are active.

* **Added** anonymous peer quest-evidence exchange for `available`, `offered`, `active`, and `turnedIn` observations. Messages carry only protocol version, quest ID, map ID, faction, class ID/token, completion state, and evidence type; sender names are not written to SavedVariables or the Companion queue.

* **Added** a bounded Companion synchronization queue in SavedVariables. Local and accepted peer quest observations are queued with a stable observation key, timestamp, addon version, quest/map/evidence context, faction, class ID/token, level, completion state so the future **Azeroth Questing Companion** can upload structured records to the Service01 API after WoW writes `AzerothQuesting.lua`.

* **Added** per-class quest learning. New observations now preserve WoW class ID/token counts (for example `MAGE`, `SHAMAN`, or `DRUID`) under each learned quest so server-side research can compare which classes actually observed a quest instead of mixing every class into one total.

* **Changed** the map-learning store to schema version 2 and the tab-separated map/quest export to `ZQGMAPQUESTDATA|3`, adding `classID` and `classFile` columns. Historical observations created before v0.2.31 remain labeled `UNKNOWN` rather than being incorrectly assigned to the class that first logs in after the update.

* **Improved** Retail Midnight chat-lockdown handling by checking Blizzard's outgoing addon-message restriction APIs before network sends and queueing transient throttle/lockdown failures for retry. The in-game custom channel supplements the Companion/Service01 path; it is not a replacement for global server synchronization and is limited by WoW's custom-channel reach.

*This v0.2.31 network, class-learning, and Companion-queue update has not been tested in World of Warcraft. After updating, `/reload` and verify there are no Lua errors; open the Chat Channels pane and look for `AzerothQuesting` under custom channels; run `/aq network` and confirm `AZQUEST` is registered and the channel is joined; run `/aq sync` before and after interacting with quests to verify the queue count rises; use `/aq mapexport` and confirm new rows include the logged-in class ID/token. If a second Retail client with v0.2.31 is available on the same connected-realm custom-channel scope, verify `received`/`peers` can increase without protocol text appearing in normal chat. Also retest the still-outstanding v0.2.29 rename and v0.2.28 breadcrumb behavior. GitHub remains the only listed distribution platform because no downloadable Wago release has been published.*

---
**VERSION 0.2.30 - September 8, 2026 - Available on GitHub**

* **Improved** GitHub packaging with a stable player-facing `AzerothQuesting.zip` download that contains a top-level `AzerothQuesting/` addon folder, so players do not have to rename the `AzerothQuesting-main` folder created by GitHub's built-in source ZIP.

* **Changed** GitHub Release packaging to provide both `AzerothQuesting.zip` for normal installs and `AzerothQuesting-0.2.30.zip` as the versioned archive.

*This v0.2.30 packaging change has not been tested in World of Warcraft. After installing the packaged ZIP, verify the folder is `Interface/AddOns/AzerothQuesting`, the addon appears as **Azeroth Questing**, `/aq` works, and existing v0.2.29 functionality still loads without Lua errors. GitHub packaging success is a build check only and must not be treated as an in-game test. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---
**VERSION 0.2.29 - September 8, 2026 - Available on GitHub**

* **Changed** the public addon name from **Zone Quest Guide** to **Azeroth Questing** and moved active development to the new `Frostcanvas/AzerothQuesting` GitHub repository. The renamed package now uses `AzerothQuesting.toc` and a top-level `AzerothQuesting/` addon folder.

* **Changed** player-facing addon labels, chat prefixes, options/export titles, comments, README installation guidance, and the GitHub packaging workflow to use the Azeroth Questing name. Internal frame/handler identifiers remain unchanged where they are not player-facing to reduce unnecessary regression risk.

* **Added** `/aq` and `/azerothquesting` as the primary slash commands while retaining `/zq` and `/zonequest` as legacy aliases.

* **Changed** the GitHub Actions package name to `AzerothQuesting-<version>.zip` and the development artifact/folder name to `AzerothQuesting`.

* **Changed** the rename to keep the existing `ZoneQuestGuideDB` SavedVariables table name for compatibility. Because WoW stores SavedVariables in a file named after the addon folder, existing `ZoneQuestGuide.lua` data still needs to be copied to `AzerothQuesting.lua` while WoW is closed if a player wants to carry old local settings/learning data into the renamed addon.

*This v0.2.29 rename/migration has not yet been tested in World of Warcraft. After updating, do not load the old ZoneQuestGuide folder and AzerothQuesting at the same time. Verify the AddOn List name, `/aq` and legacy `/zq` commands, main panel, minimap button, navigation HUD, options/export windows, quest automation, timeline detection, `/aq check`, Wago registration if enabled, and the still-outstanding v0.2.28 breadcrumb lockout behavior. GitHub packaging is a build check only and must not be treated as an in-game test. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.28 - August 29, 2026 - Available on GitHub**

* **Added** Retail breadcrumb lockout data covering 881 breadcrumb quests and 1,161 breadcrumb-to-later-quest relationships extracted as quest-ID facts from the user-provided All The Things Retail/Standard metadata snapshot. Zone Quest Guide stores these relationships in its own `skippedBy` availability format rather than copying ATT quest records or code.

* **Added** a lockout warning when the quest-detail window opens for a quest known to skip unfinished breadcrumb quests. The warning names the unfinished breadcrumb quest IDs so a player can complete them before accepting the later quest if desired. The warning is shown once per later quest during the current login session.

* **Improved** automatic quest priority when both sides of a known breadcrumb lockout are still available. Zone Quest Guide now places the breadcrumb ahead of the later quest that can skip it, even when the later quest is geographically closer, reducing the chance that automatic navigation leads the player into an avoidable lockout.

* **Improved** Auto Accept safety around known breadcrumb lockouts. If the same NPC offers both the breadcrumb and the later quest that can skip it, Zone Quest Guide now opens the breadcrumb first. If a quest detail page is opened for a later quest while a known breadcrumb is still unfinished, automatic acceptance pauses and leaves the quest open for manual confirmation instead of immediately accepting the potentially locking quest.

* **Changed** quest availability filtering with the dedicated `skippedBy` rule. An unaccepted breadcrumb is hidden once any known skip-ahead quest is active or completed, including stale session-observed or supplemental records, while an already accepted breadcrumb remains visible so the addon does not hide a quest the character still has in the quest log.

*The uploaded ATT data confirmed the screenshot relationship `29863 -> 29861`: **Stormherald Eljrrin** is a breadcrumb that can be skipped by **Whatever it Takes!**. The new v0.2.28 data loader, warning, ordering, filtering, and Auto Accept safeguards have not yet been tested in World of Warcraft. After updating, `/reload` and use a character/test case where a known breadcrumb pair is still obtainable. For the 29863/29861 example, verify the breadcrumb is preferred when both are visible and opening quest 29861 produces the lockout warning before acceptance. With Auto Accept enabled, verify 29861 is not automatically accepted while 29863 remains unfinished; after the breadcrumb has been accepted or completed, verify normal quest acceptance can continue. Avoid intentionally locking out an unfinished quest on a character you care about solely for testing. Also confirm normal quest ordering, accepted quests, quest automation, and `/zq check` continue to work without Lua errors. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.27 - August 29, 2026 - Available on GitHub**

* **Fixed** a repeated `TimePhases.lua` Lua error when Retail WoW returned `UnitName("npc")` as a secret string during `GOSSIP_SHOW`. Secret strings still report `type(...) == "string"`, so the old guard allowed the value through and `name:lower()` attempted indexed access on a protected value.

* **Improved** Zidormi phase detection to check `canaccessvalue()` before normalizing NPC or gossip text and `canaccesstable()` before reading gossip option tables. When Blizzard restricts those values, Zone Quest Guide now skips that automatic gossip sample instead of throwing an error; normal detection can resume once the values are accessible.

*The v0.2.26 failure was reported from World of Warcraft and occurred 13 times in the supplied error log. The v0.2.27 fix has not yet been tested in World of Warcraft. After updating, `/reload`, reproduce the same NPC/gossip situation and verify the `TimePhases.lua` secret-string error no longer appears. Then talk to Zidormi in a normal unrestricted context and confirm timeline detection still identifies and switches the timeline correctly. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.26 - August 16, 2026 - Available on GitHub**

* **Added** fuller anonymous Wago research telemetry so the automatic crowd dataset can preserve the same quest-evidence classes used by the local export: `seen`, `available`, `offered`, `accepted`, `active`, and `turnedIn`. Each evidence type remains separately labeled so map/API hints and carried accepted quests can be analyzed differently from stronger NPC-offer, active-NPC, and turn-in observations.

* **Added** Wago completion-state counters for phase-aware and general map/quest observations. The addon now records a `0` or `1` completion state alongside the quest's map/faction context, allowing the crowd dataset to retain the export's completion-support signal without putting character identity into metric names.

* **Added** dashboard-visible `seen_quest_...` and `seen_mapquest_...` discovery switches for quest observations. Quest discovery mirrors share the existing 200-switch session ceiling but are limited to 150 of those slots so long questing sessions leave room for map, phase, and instance fingerprints; the complete evidence stream continues through counters even if the switch mirror reaches its cap.

* **Improved** automatic accepted-quest coverage. Zone Quest Guide now scans quests actually present in the player's quest log for the current map and sends them as explicitly weak `accepted` evidence instead of dropping them from Wago entirely. It also emits a generic `seen` observation for every reported quest record, matching the structure of the local learning export more closely.

* **Improved** instance telemetry so the Wago fingerprint now carries the export's non-name context where available: parent map ID, scenario type/area/texture-kit values, instance type, faction, and current phase/source in addition to map, instance, difficulty, LFG, maximum-player, and group-size IDs. Localized map, quest, difficulty, instance, and scenario names remain local rather than becoming Wago metric keys.

* **Changed** `available` evidence to remain in Wago as a useful map/API hint instead of being treated as proof that the quest exists in the current timeline. The evidence label is preserved so later analysis can require `offered`, `active`, or `turnedIn` when confirming that a quest genuinely exists in a specific world state.

*The v0.2.26 telemetry expansion has not yet been tested in World of Warcraft. After updating, `/reload`, run `/zq check`, interact with an NPC that offers a quest, accept a quest, and if practical turn one in. Verify the phase/map-quest session counts rise, verify `discoveries` rises while under the switch cap, and after the Wago App uploads check Analytics -> Switches for new `seen_quest_...` or `seen_mapquest_...` entries. Also re-enter the live-tested Heroic Battle for Stromgarde if convenient and confirm the richer instance fingerprint does not exceed Wago's metric-name limit or suppress `instancevisit`. Wago's Counters dashboard is still unavailable for direct inspection, so counter receipt cannot yet be verified there. This release has not been tested successfully in WoW yet, and Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.25 - August 16, 2026 - Available on GitHub**

* **Added** dashboard-visible Wago discovery switches for the crowdsourced observations that are most useful while Wago's Counters dashboard is not yet available. A real map visit can now mirror to `seen_map_m<map>_<faction>`, a reliable timeline visit can mirror to `seen_phase_m<map>_<faction>_<phase>_src_<source>`, and an instance fingerprint can mirror to `seen_instance_m<map>_i<instance>_d<difficulty>_lfg<id>_max<players>_grp<size>_<type>_<faction>`.

* **Added** a `discovery_switch_mirroring_enabled` Wago feature switch so the Analytics Switches page can show that a client is running the new mirror path even before it encounters a new map or instance.

* **Improved** discovery-switch data quality by reusing the same taxi suppression and reliable-phase rules as the underlying visit telemetry, deduplicating each discovery switch for the current UI session, and capping dynamic discovery switches at 200 per session so unusually long exploration sessions do not crowd out normal Wago feature switches.

* **Improved** `/zq wago` and `/zq check` diagnostics with a `discoveries` count showing how many dashboard-visible discovery switches were queued during the current UI session.

* **Changed** the new switches to mirror rather than replace the existing Wago counters. Zone Quest Guide continues to send `mapvisit`, `phasevisit`, `instancevisit`, and their total counters so that richer aggregate counts remain available when Wago exposes the Counters dashboard.

*The existing v0.2.24 path was observed in World of Warcraft before this release: Alliance Heroic Battle for Stromgarde returned `1044 / Arathi Highlands`, instance `1943 / Warfronts Arathi - Alliance`, type `scenario`, difficulty `149 / Heroic`, `maxPlayers=30`, `groupSize=10`, `LFG=2007`, scenario `The Battle for Stromgarde`, and `/zq check` showed `instancevisit=1`. The Wago website also displayed ZoneQuestGuide's existing feature switches, confirming that switch data reached the Analytics dashboard. The new v0.2.25 dynamic `seen_map`, `seen_phase`, and `seen_instance` switches have not yet been tested in World of Warcraft. After updating and `/reload`, verify `/zq check` shows `discoveries` increasing, verify the corresponding `seen_...` names appear under Wago Analytics -> Switches after the Wago App uploads, verify repeated movement in the same map/instance does not repeatedly increment the discovery count, and confirm taxi-flight suppression and the existing privacy exclusions remain intact. Wago's Counters page currently says the dashboard will be released later, so counter receipt still cannot be inspected there. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.24 - August 16, 2026 - Available on GitHub**

* **Added** account-wide instance/scenario fingerprint learning for instanced content such as Warfronts, scenarios, raids, and dungeons. When the player actually enters an instance, Zone Quest Guide can record the live `UiMapID`, parent map when available, instance ID/type, difficulty ID/name, maximum/group-size values, LFG dungeon ID, scenario metadata, faction, and current timeline/source without storing character or group-member identity.

* **Added** `/zq inspect` (also `/zq instance`) to print a compact live diagnostic for the current map and instance, including parent map, instance ID/name/type, difficulty, LFG ID, scenario, faction, and timeline. `/zq instanceexport` opens the new `ZQGINSTANCEDATA|1` block, while `/zq export` now includes phase, map/quest, and instance-learning data together.

* **Added** anonymous Wago instance-visit telemetry. Each distinct in-instance fingerprint can increment an `instancevisit_m<map>_i<instance>_d<difficulty>_lfg<id>_max<players>_grp<size>_<type>_<faction>` counter once per UI session plus `instance_visit_total`. Localized instance/scenario names are intentionally not sent in Wago metric keys.

* **Improved** `/zq wago` and `/zq check` so the current session also reports an `instancevisit` count. This should make it much easier to verify whether Normal and Heroic Warfronts use the same map/instance context or different difficulty/LFG fingerprints.

* **Improved** privacy for community map research. Automatic instance telemetry does not include character names, realms, GUIDs, guilds, account identifiers, party/raid member names, chat, coordinates, timestamps, instance names, or scenario names. The more descriptive names remain only in the local/manual export that the player explicitly chooses whether to copy.

*The new v0.2.24 instance learning, `/zq inspect`, combined export, and Wago instance counters have not yet been tested in World of Warcraft. After updating, `/zq inspect` works outdoors, then enter Heroic Battle for Stromgarde and run `/zq inspect` plus `/zq check` immediately after loading and again once the Warfront starts. Confirm `instancevisit` increases only once for the fingerprint, compare Normal Stromgarde if available, verify `ZQGINSTANCEDATA|1` exports cleanly, and separately confirm `instancevisit_m...` plus `instance_visit_total` reach the Wago development dashboard. Existing v0.2.23 map/phase-visit and taxi-suppression checks are still outstanding. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.23 - August 16, 2026 - Available on GitHub**

* **Added** anonymous Wago map-visit telemetry so Zone Quest Guide can record that a player actually entered a live `UiMapID` even when no quest is available there. Each `mapvisit_m<map>_<faction>` observation is deduplicated to once per map/faction during the current UI session.

* **Added** anonymous phase-visit telemetry for maps where the timeline is known from a reliable `zidormi` or `detected` source. These `phasevisit_m<map>_<faction>_<phase>_src_<source>` observations make it possible to distinguish real visits to historical/current world states without requiring a quest to be present.

* **Improved** telemetry privacy and data quality. Map/phase visits do not include coordinates, subzone names, timestamps, character names, realms, GUIDs, guilds, or account identifiers; taxi-flight observations remain suppressed, and repeated movement inside the same map does not create additional visit counters during the session.

* **Improved** `/zq wago` and `/zq check` diagnostics so the current session now shows separate map-visit and phase-visit counts alongside the existing phase-quest and map/quest counters.

*The new v0.2.23 visit telemetry has not yet been tested in World of Warcraft. After updating, verify `/zq check` shows `mapvisit` increasing when entering a new map, verify `phasevisit` increases only after a reliable Zidormi/detected timeline is known, verify moving among subzones on the same UiMapID does not repeatedly increment it, and verify taxi flights do not create flyover visits. Wago dashboard/server receipt of the new counters also still needs separate verification. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.22 - August 16, 2026 - Available on GitHub**

* **Added** supplemental quest availability rules for cases where WoW progression makes an older quest impossible to obtain. Database records can now use `blockedBy = { ... }` to hide a quest after any listed blocker quest has been completed.

* **Added** `exclusiveWith = { ... }` for mutually exclusive quest routes. A supplemental quest using this rule is hidden while any listed alternate quest is active and remains hidden once that alternate quest has been completed. If an alternate route is abandoned before completion and the game allows the original route again, the supplemental quest can become eligible again on a later refresh.

* **Improved** the existing `prereqs = { ... }` framework by documenting the three availability rules together: every prerequisite must be completed, any completed `blockedBy` quest suppresses the record, and any active/completed `exclusiveWith` quest suppresses the record. These restrictions apply to supplemental database records only; live Blizzard-provided quests remain trusted as currently obtainable or active.

* **Confirmed** from live Silithus testing that both **PAST / Before the Wound** and **PRESENT / The Wound** returned `81 / Silithus`. The existing same-map Zidormi detection correctly changed the displayed timeline from PAST to PRESENT after the switch, so Silithus map ID alone is intentionally not used as a phase classifier.

*The Silithus timeline behavior above was observed in World of Warcraft. The new `blockedBy` and `exclusiveWith` filtering framework has not yet been tested in-game because no guessed quest relationships were added just to exercise the code. When a real breadcrumb or mutually exclusive pair is identified, verify the supplemental quest disappears at the correct acceptance/completion point and that normal Blizzard-provided quests remain unaffected. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.21 - August 16, 2026 - Available on GitHub**

* **Added** direct Uldum timeline detection from live Retail map IDs. The player's recording showed `1527 / Uldum` in **PRESENT / N'Zoth assaults** and `249 / Uldum` in **PAST / Cataclysm Uldum**, so Zone Quest Guide can now use those map identities as stronger evidence than cached Zidormi session state.

* **Fixed** `/zq check` briefly reporting map `249` as PRESENT after the Zidormi transition even though the main timeline line had already corrected itself to **PAST / Cataclysm Uldum** once Zidormi was reopened. The new map-derived override makes `249` directly PAST and `1527` directly PRESENT instead of waiting for another gossip refresh.

* **Changed** Uldum-related maps `1330` and `1571` to remain unclassified by direct map identity until their live role is actually observed. They remain part of the broader Uldum registry but are not assumed to be one side of the Zidormi switch.

* **Confirmed** in-game that the Wago bridge is loaded and the new session counters are increasing while normal play generates evidence. During this recording `/zq check` increased from `phase=3 map/quest=29` to `phase=9 map/quest=32`. This confirms the addon is queuing observations through the loaded Wago Analytics client; it does not by itself confirm that the new counters have reached the Wago website/dashboard.

*The Uldum map IDs, Zidormi wording, and Wago session-counter increases were observed in World of Warcraft. The new v0.2.21 map-derived Uldum detection itself still needs an in-game check after updating: before talking to Zidormi, verify `/zq check` reports `1527` as PRESENT `(detected)`, switch to Cataclysm Uldum and verify `249` reports PAST `(detected)` before reopening Zidormi, then return to `1527`. Wago server/dashboard receipt of the new map/quest counters still needs separate verification. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.20 - August 16, 2026 - Available on GitHub**

* **Added** direct Tirisfal Glades map detection from live Retail testing. The player's recording showed `2070 / Tirisfal Glades` in **PRESENT / After Battle for Lordaeron** and `18 / Tirisfal Glades` after switching to **PAST / Before Battle for Lordaeron**.

* **Improved** Tirisfal timeline handling so those two live map identities can classify the timeline without requiring a fresh Zidormi conversation. Map `2070` now provides direct PRESENT evidence and map `18` provides direct PAST evidence; manual phase overrides remain stronger.

* **Changed** alternate Tirisfal map `1247` to remain registered but unclassified until its live role is observed in-game instead of assuming that every related Tirisfal UiMapID corresponds to one of the two Zidormi states.

* **Confirmed** from the player's recording that the existing timeline UI and `/zq check` followed the Zidormi transition in both directions: Zidormi offered the pre-Lordaeron destination while on map `2070`, and after switching the addon displayed PAST while `/zq check` reported map `18`; Zidormi then offered a return to the present.

*The map IDs and Zidormi behavior above were observed in World of Warcraft, but the new v0.2.20 automatic map-derived detection itself has not yet been tested after updating. Verify `/zq check` reports `2070` as PRESENT before talking to Zidormi, reports `18` as PAST before reopening Zidormi, and returns to PRESENT cleanly after switching back. Also continue checking Arathi's three-state handler and Wago map/quest telemetry. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.19 - August 16, 2026 - Available on GitHub**

* **Fixed** Arathi Highlands timeline display staying on the old two-state **PRESENT / Warfront era** label even after Retail moved the player between different Arathi world states. Live testing showed that current Arathi can report `2372 / Arathi Highlands`, while the Fourth War state can report `14 / Arathi Highlands`; the older generic Zidormi classifier was not designed for this newer three-way setup.

* **Added** a dedicated three-state Arathi timeline handler with separate player-facing states for **PAST / Before Fourth War**, **FOURTH WAR / Warfront era**, and **PRESENT / Current Arathi Highlands**. Map `2372` is treated as a direct current-present signal based on the player's live `/zq check` result.

* **Improved** Arathi Zidormi detection by reading all of her available destinations instead of forcing the first historical-looking option into a simple past/present pair. When the player is in the Fourth War state and Zidormi offers both a **before the war** destination and a **present time** destination, Zone Quest Guide can infer that the missing current state is the Fourth War. Selecting a destination updates the session state immediately and refreshes again after the world transition.

* **Changed** Arathi map `14` to remain context-sensitive rather than being hard-coded as every historical state. This lets the addon keep following Zidormi when Retail reuses an Arathi UiMapID for more than one older state, while still using `2372` as strong evidence for the current-present version.

*The player's screenshots confirmed that `/zq check` now prints correctly in-game, that current Arathi returned map `2372`, and that another Arathi state returned map `14`. The screenshots also showed Zidormi offering **during the Fourth War** from the `2372` state and both **before the war** and **present time** destinations from the `14` state. The new v0.2.19 three-state detection itself still needs in-game testing after updating. Verify `2372` displays PRESENT, the `14` state with the two opposite destinations displays FOURTH WAR, then choose the before-war option and send another `/zq check` so the older state's live map behavior can be recorded. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.18 - August 16, 2026 - Available on GitHub**

* **Fixed** the diagnostic `/zq phase` and `/zq maps` commands falling through to the core addon's default show/hide action on clients where the older chain of slash-command wrappers did not reach the intended handler. A final diagnostic router now loads after the other modules and intercepts the testing commands before they can toggle the main panel.

* **Added** `/zq mapid` as a short replacement for the long Blizzard `/run C_Map.GetBestMapForUnit(...)` test command. It prints the live UiMapID and map name directly in chat.

* **Added** `/zq check` (and `/zq debug`) to print the current map ID/name, timeline and detection source, local learned quest count, and current-session Wago phase/map-quest counts in one line. This makes timeline testing much easier when comparing the two sides of a Zidormi switch.

* **Improved** diagnostic safety by handling an unknown timeline/source without trying to concatenate a missing value, while leaving phase-changing commands such as `/zq phase auto`, `/zq phase past`, and `/zq phase present` on the existing phase handler.

*The player observed in-game that the previous `/zq phase` and `/zq maps` diagnostics could simply open/close the Zone Quest Guide window instead of printing their status. The new v0.2.18 final diagnostic router and `/zq check` command have not yet been tested in World of Warcraft. After updating and `/reload`, verify `/zq check`, `/zq phase`, `/zq maps`, and `/zq mapid` print chat output without toggling the panel, and verify normal commands such as `/zq show`, `/zq hide`, `/zq arrow`, and `/zq options` still pass through correctly. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.17 - August 16, 2026 - Available on GitHub**

* **Added** automatic anonymous Wago Analytics reporting for strong map/quest observations while players use Zone Quest Guide normally. When WagoAnalytics is available, observations that a quest is **available**, **offered**, **active**, or **turned in** can now increment a map/quest counter containing the live map ID, faction, quest ID, and evidence type even when no Zidormi timeline is known.

* **Improved** Wago privacy and data quality by keeping accepted-only and generic seen observations local. Those weaker observations can remain valid in a quest log while the player moves between maps or phases, so they are not automatically transmitted as proof that the quest belongs to the current map. Character names, realms, guild names, GUIDs, account identifiers, and quest names are not included in the Wago map/quest metric keys.

* **Improved** flight-path handling for learning and telemetry. Map scans are now skipped while `UnitOnTaxi("player")` reports an active taxi flight, reducing false quest/map associations caused by transient continent or flyover maps while traveling. Strong NPC and turn-in evidence resumes normally after landing.

* **Improved** `/zq wago` so it reports how many phase observations and map/quest observations have been queued during the current UI session. Wago also receives a `map_quest_learning_enabled` switch and a `map_quest_evidence_total` counter to make the new stream easier to verify on the Analytics dashboard.

*The existing Wago Analytics registration/upload path was already observed producing dashboard data, but the new v0.2.17 map/quest counters and taxi suppression have not yet been tested in World of Warcraft. Verify `/zq wago` increases its map/quest count after an offered/available/active/turned-in quest, confirm `mapquest_m..._q...` and `map_quest_evidence_total` appear on the Wago development dashboard, and confirm taxi flights do not create new flyover-map associations. Wago App Analytics sharing is still required for upload. Zone Quest Guide still has no published Wago download, so GitHub remains the only listed distribution platform.*

---

**VERSION 0.2.16 - August 16, 2026 - Available on GitHub**

* **Fixed** learning-export text becoming corrupted inside WoW's copy box. The previous pipe-delimited format could accidentally form WoW text-markup sequences at normal field boundaries, causing headers such as `questID|name` to split and quest names beginning with certain letters to lose characters when displayed or copied.

* **Changed** both learning exports to tab-separated schema version 2: `ZQGPHASEDATA|2` and `ZQGMAPQUESTDATA|2`. The same map, faction, phase, quest, completion, evidence-count, and phase-source data is preserved without relying on pipe characters between fields.

* **Improved** export field sanitizing so tabs, line breaks, and pipe characters inside individual values cannot break the tab-separated row structure.

*The corrupted v1 export was reproduced in-game from the player's copied map/quest report, including a split `questID/name` header and the first letter missing from `Ritual Problems`. The v0.2.16 tab-separated fix has not yet been tested in World of Warcraft. Verify `/zq mapexport` and `/zq export` copy complete headers and quest names, and verify the Google Form preserves the v2 report correctly. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.15 - August 16, 2026 - Available on GitHub**

* **Added** automatic GitHub addon packaging. Pushes to `main` now build a GitHub Actions artifact named **ZoneQuestGuide**, providing a clean download instead of relying on GitHub's automatic `ZoneQuestGuide-main.zip` source archive.

* **Improved** the package layout so the generated artifact contains a top-level `ZoneQuestGuide/` folder and excludes repository-only `.git` and `.github` metadata.

* **Added** GitHub Release packaging support. When a GitHub Release is published, the workflow builds and attaches a versioned package such as `ZoneQuestGuide-0.2.15.zip`.

* **Changed** installation documentation to explain that GitHub's built-in **Code -> Download ZIP** filename cannot be customized; players should use the packaged Actions artifact or a versioned GitHub Release ZIP for the clean addon folder/name.

*The GitHub Actions packaging job completed and its generated ZIP structure was inspected: it contains a top-level `ZoneQuestGuide/` folder with the addon files and bundled libraries. The packaged download has not yet been launched in World of Warcraft, so in-game package verification is still required. Wago is still not listed as an available distribution platform because no downloadable Wago release has been published.*

---

**VERSION 0.2.14 - August 16, 2026 - Available on GitHub**

* **Added** account-wide map/quest learning that records the live `UiMapID`, WoW map name, faction, quest ID/name, completion support, and how the quest was observed (available, offered, accepted, active, or turned in). Unlike phase learning, this collector does not require a known Zidormi timeline, so it can discover map aliases while the player quests normally.

* **Added** `/zq maps` to show the current map ID/name and recorded quest count, plus `/zq mapexport` for a copyable `ZQGMAPQUESTDATA|1` report. `/zq export` now combines the existing phase-learning report with the new map/quest block so community submissions can include both kinds of evidence without collecting character names, realms, GUIDs, guild names, or account identifiers.

* **Fixed** current Midnight Quel'Thalas detection using live Retail values observed in-game. `C_Map.GetBestMapForUnit("player")` returned **2537 / Quel'Thalas** in the current Midnight world and **95 / Ghostlands** in the old Burning Crusade version. Map 2537 is now a reliable **PRESENT / Midnight Quel'Thalas** signal; map 95 remains the old **PAST / Burning Crusade Quel'Thalas** state.

* **Improved** future timeline research by keeping map/quest evidence separate from curated phase requirements. A quest seen on a map is stored as evidence and is not automatically treated as map-exclusive or phase-exclusive.

*The live map IDs 2537 (current Midnight Quel'Thalas) and 95 (old Ghostlands) were observed in-game. The new v0.2.14 automatic map/quest collection, `/zq maps`, `/zq mapexport`, combined `/zq export`, and automatic PRESENT/PAST display using those values still need in-game testing after updating. Verify quests are stored under the correct map when moving through the Thalassian Pass portal, and confirm existing phase learning, navigation, contribution prompts, and Wago telemetry continue to behave normally. Zone Quest Guide still has no published Wago release, so Wago is not yet listed as an available distribution platform.*

---

**VERSION 0.2.13 - August 16, 2026 - Available on GitHub**

* **Added** direct old/current map detection for Midnight Quel'Thalas. Zone Quest Guide now treats Midnight **Silvermoon City** (`2393`) and **Eversong Woods** (`2395`) as the PRESENT timeline, while the legacy Burning Crusade Eversong/Ghostlands/Silvermoon map IDs are treated as the PAST timeline. Name fallbacks also recognize `Ghostlands`, `Ghostlands (Burning Crusade)`, `Eversong Woods (Burning Crusade)`, and the corresponding Silvermoon naming if WoW exposes them.

* **Fixed** Quel'Thalas timeline state becoming dependent on a Zidormi conversation. The live game behavior observed by the player shows that the Thalassian Pass portal itself can move the character into the old Burning Crusade area, while Zidormi's historical option also teleports the character there. Because a portal transition can happen without a gossip click, Zone Quest Guide now trusts the actual old/current map identity over a cached Zidormi session value.

* **Improved** automatic timeline display in the rebuilt Midnight zones. A character standing in current Midnight Eversong Woods or Silvermoon City can now be identified as **PRESENT / Midnight Quel'Thalas** from the map alone, while entering the legacy Ghostlands/Eversong maps can identify **PAST / Burning Crusade Quel'Thalas** without requiring another Zidormi conversation.

* **Improved** portal-driven phase refreshing. Player/world/zone transitions now re-run the full timeline refresh so quest filtering, phase learning, the Timeline line, and Wago phase telemetry can all see a map-derived timeline change even when no gossip option was selected.

*The player confirmed in-game that current Midnight Silvermoon City leads into the rebuilt Eversong Woods and that the Thalassian Pass portal can enter the old Burning Crusade area; talking to Zidormi there can also transport the character into the old zone. The new v0.2.13 automatic PRESENT/PAST detection across those portal transitions still needs in-game verification after updating. Confirm the label changes correctly in both directions, `/zq learn` follows the detected map timeline, and no stale Zidormi state remains after using the portal. Zone Quest Guide still has no published Wago release, so Wago is not yet listed as an available distribution platform.*

---

**VERSION 0.2.12 - August 16, 2026 - Available on GitHub**

* **Added** a central Retail timeline-zone registry covering the known Zidormi/Rhonormu world-state switches: Dustwallow Marsh/Theramore, Blasted Lands, Peak of Serenity, Silithus, Darkshore, Tirisfal Glades/Undercity, Arathi Highlands, Uldum, Vale of Eternal Blossoms, and the newer Quel'Thalas switch for Eversong Woods/Ghostlands at Thalassian Pass. Silithus also recognizes Rhonormu as a valid timeline NPC.

* **Fixed** phased zones that could look like ordinary zones until the player first spoke to Zidormi. Darkshore in particular can use several Retail map IDs; Zone Quest Guide now recognizes known alternate map IDs and can also match the live map/subzone name, so the **Timeline: UNKNOWN - talk to Zidormi before questing.** warning can appear before questing starts.

* **Improved** timeline switching across alternate map IDs by keeping the detected PAST/PRESENT state under the logical zone timeline instead of tying the session state to only one UiMapID. Related areas such as Teldrassil/Darnassus and Undercity can share the appropriate Darkshore or Tirisfal timeline state without receiving a misleading same-map Zidormi waypoint.

* **Improved** Zidormi gossip detection for historical options whose wording does not literally contain "before" or "past". Known timeline NPC interactions can now also recognize phrases such as **show me**, **relive**, **during**, and **age of**, which is needed for locations such as Uldum and the Burning Crusade-era Eversong Woods/Ghostlands switch.

* **Changed** Peak of Serenity detection to use the actual Peak of Serenity subzone rather than marking all of Kun-Lai Summit as a timeline zone. The new Quel'Thalas switch likewise warns players to visit Zidormi at Thalassian Pass instead of creating a false local waypoint inside Eversong Woods or Ghostlands.

*Darkshore switching was observed in-game in the player's recording: the label changed between PAST and PRESENT after the Zidormi selection, and WoW displayed its normal fade/phase-transition effect. The new v0.2.12 registry, pre-conversation warning on alternate map IDs, additional zones, broader gossip wording, Rhonormu handling, and cross-map timeline state still require in-game testing. Zone Quest Guide still has no published Wago release, so Wago is not yet listed as an available distribution platform.*

---

**VERSION 0.2.11 - August 16, 2026 - Available on GitHub**

* **Added** Darkshore (UiMapID 62) to Zone Quest Guide's historical-timeline zone list so the main window now recognizes Darkshore as a Zidormi-controlled phased zone instead of treating it like an ordinary single-timeline zone.

* **Added** Darkshore player-facing timeline labels for **PAST / Before War of the Thorns** and **PRESENT / After War of the Thorns**, plus the configured Zidormi location near 48.4, 25.0 for timeline guidance.

* **Improved** phase-learning safety in Darkshore. Until Zone Quest Guide has a reliable timeline signal, the main panel can now show **Timeline: UNKNOWN - talk to Zidormi before questing.** Once Zidormi offers the before-the-battle or return-to-present option, the existing generic Zidormi detector can classify the timeline and allow phase learning to record under the correct phase.

* **Changed** Darkshore support to track the old-versus-current Zidormi timeline only. This does not yet attempt to distinguish every Battle for Darkshore warfront ownership/state variant inside the present-era version.

*In-game testing is still required in Darkshore. After updating, enter Darkshore and verify the timeline warning appears before talking to Zidormi, then talk to Zidormi near 48.4, 25.0 and confirm the label changes to the correct PAST or PRESENT value. Switch timelines once and verify the label updates without a second conversation, `/zq learn` records under the new phase, and Wago telemetry continues to use only strong phase evidence.*

---

**VERSION 0.2.10 - August 16, 2026 - Available on GitHub**

* **Fixed** the initial Wago Analytics integration to follow Wago's documented shim-based setup instead of talking directly to the optional global analytics provider. Zone Quest Guide now bundles Wago's official `WagoAnalytics` shim and registers project `EGPeM3N1` through `LibStub("WagoAnalytics"):Register(...)` when the addon loads.

* **Added** bundled `LibStub` support so the Wago shim can load safely even when the player does not have another addon that already provides LibStub. The official Wago shim and its MIT license are included under `libs/WagoAnalytics/`.

* **Improved** `/zq wago` status reporting so it distinguishes between the configured/shim-ready state and the real `WagoAnalytics` addon actually being loaded. The command no longer claims that the player's Wago App data-sharing setting can be verified from WoW Lua; it explicitly notes that uploading still depends on the Wago App setting.

* **Changed** Wago registration timing to happen during addon loading, matching Wago's guidance that registration should occur at the beginning of the game session rather than waiting for a later gameplay event.

*In-game testing is still required. After Analytics is activated for the Wago project and the Wago App has Analytics data sharing enabled, verify `/zq wago` reports project `EGPeM3N1` with the WagoAnalytics addon loaded, then generate a strong phased quest observation and confirm it reaches the Wago Analytics development dashboard. Zone Quest Guide still has no published Wago release, so Wago is not yet listed as an available distribution platform.*

---

**VERSION 0.2.9 - August 16, 2026 - Available on GitHub**

* **Added** the assigned Wago project ID (`EGPeM3N1`) to `ZoneQuestGuide.toc` as `X-Wago-ID`, allowing the existing Wago telemetry bridge to register observations against the correct Zone Quest Guide project.

* **Changed** Wago setup from a placeholder/no-project state to a real configured project. `/zq wago` can now distinguish between a configured project whose Wago Analytics client is available and a configured project where the Wago App/Analytics data sharing is still unavailable.

* **Improved** the Wago rollout path by keeping `WagoAnalytics` optional. Players who do not use the Wago App can continue using Zone Quest Guide normally, while players who opt in to Wago Analytics can contribute the stronger anonymous phase evidence already defined in v0.2.7.

*The Wago project now exists and the project ID is configured in the addon, but Wago Analytics still needs to be activated on the project's Analytics tab and the developer/client Wago App needs Analytics data sharing enabled before telemetry can be verified. In-game testing is still required for `/zq wago` and actual evidence delivery. Zone Quest Guide has not yet published a Wago release, so Wago is not yet listed as an available distribution platform.*

---

**VERSION 0.2.8 - August 16, 2026 - Available on GitHub**

* **Changed** the phase-data contribution destination from the temporary GitHub issue page to the dedicated ZoneQuestGuide Google Form supplied for community submissions.

* **Improved** the contribution popup wording so players are told to open the Google Form, paste the anonymous `/zq export` report, and submit it. The URL field is now labeled **Google Form URL** while keeping the existing **Open Export**, **Select URL**, and **Later** controls.

* **Changed** `/zq contribute` and automatic contribution reminders to show `https://forms.gle/Gnqf8kN44kDZxMs86` as the current manual submission destination.

*The Google Form link has been wired into the addon but the full in-game contribution flow has not yet been tested. Verify `/zq contribute` shows the correct form URL, **Select URL** highlights it for copying, **Open Export** still opens the phase report, and a test submission can be pasted into the form successfully. The Wago telemetry bridge from v0.2.7 is still awaiting a Wago project ID and in-game testing; Wago is not yet listed as an available distribution platform.*

---

**VERSION 0.2.7 - August 16, 2026 - Available on GitHub**

* **Added** a Wago Analytics telemetry bridge for anonymous community phase evidence. When Zone Quest Guide is later assigned a Wago project ID and the player's Wago App has Analytics data sharing enabled, the addon can report phase-aware quest observations through the optional WagoAnalytics addon.

* **Added** `/zq wago` (also `/zq telemetry`) to show whether the Wago project ID is configured and whether the WagoAnalytics bridge is active on the current client.

* **Changed** automatic Wago reporting to use only stronger timeline evidence: quests WoW reports as available in the current phase, quests actually offered by an NPC, active quests shown by an NPC, and quests turned in in that phase. Accepted-quest map scans are deliberately excluded because an accepted quest can remain in the quest log after the player changes timelines and therefore is not reliable proof that the quest exists in both versions.

* **Improved** community-data privacy by limiting Wago metric keys to map ID, faction, phase, quest ID, evidence type, and whether the phase came from Zidormi or curated automatic detection. Character names, realm names, guild names, GUIDs, and manual phase overrides are not sent by this bridge.

* **Changed** the addon metadata to treat WagoAnalytics as an optional dependency. Zone Quest Guide continues to work normally without the Wago App or WagoAnalytics installed.

*The Wago telemetry bridge is prepared but is not active yet because Zone Quest Guide has not been published on Wago and therefore does not yet have an `X-Wago-ID`. In-game testing is still required after a Wago project is created, Analytics is enabled for that project, the project ID is added to the TOC, and the Wago App is configured for Analytics data sharing. Wago is not yet listed as an available distribution platform.*

---

**VERSION 0.2.6 - August 16, 2026 - Available on GitHub**

* **Added** a contribution reminder for phase-learning data. After Zone Quest Guide has collected useful quest observations in a known historical timeline, it can now show a small **Help improve Zone Quest Guide** window reminding the player to run `/zq export`, copy the anonymous phase report, and submit it through the listed contribution page.

* **Added** `/zq contribute` so the contribution instructions can be reopened at any time without waiting for the automatic reminder.

* **Added** a copyable contribution URL field and **Open Export** button. The initial contribution page points to the ZoneQuestGuide GitHub issue form/page, and the URL is kept in one configurable addon value so it can be changed later to a Google Form/Drive-backed submission page or another community endpoint.

* **Improved** reminder behavior so it does not pop up after every quest. The reminder is limited to once per map/faction/timeline during a login session, appears after a turn-in once phase data exists, and can also appear after several quest pickups have already created a useful observation set.

* **Changed** community contribution prompting to remain manual and privacy-conscious. The addon still does not upload anything automatically; the player chooses whether to export and submit the already-anonymous phase-learning report.

*In-game testing is still required to confirm the contribution window appears after useful phased quest data is recorded, does not repeatedly interrupt the player, `/zq contribute` reopens it, **Open Export** opens the phase export correctly, and the copyable URL field behaves normally in the WoW UI.*

---

**VERSION 0.2.5 - August 16, 2026 - Available on GitHub**

* **Fixed** timeline switching that could remain on the previous Blasted Lands phase until the player talked to Zidormi again. The earlier implementation primarily waited for WoW to report a phase-transition event after the Zidormi interaction; the player's in-game screenshots and recordings showed that this was not reliably updating the addon immediately after the switch.

* **Added** an explicit phased-zone warning directly below the current zone name when Zone Quest Guide knows the zone has historical versions but cannot yet identify the active one: **Timeline: UNKNOWN - talk to Zidormi before questing.** This is intended to make the phase-learning requirement clear before the player starts collecting quest observations in that zone.

* **Improved** Zidormi synchronization by watching the actual timeline gossip option selected by the player. When the configured Zidormi switch option is chosen, Zone Quest Guide now updates its session timeline to the destination phase and refreshes the timeline label, phase filters, learning state, and navigation again after the world state has had a short moment to settle.

* **Changed** closing Zidormi without selecting the timeline-switch option to remain non-destructive. A plain gossip close does not flip the recorded timeline; only the recognized switch selection does.

* **Improved** compatibility with the existing v0.2.4 Timeline line by reusing that line directly below the zone name rather than adding a second phase label.

*The behavior that motivated this release was observed in-game: the timeline label appeared after talking to Zidormi, and after changing phases the addon could require another Zidormi conversation before its displayed timeline caught up. v0.2.5 still needs in-game testing to confirm both switch directions update immediately, the UNKNOWN warning appears before phase confirmation, closing Zidormi without switching does not change phase, and phase-learning data begins recording under the new phase after a switch.*

---

**VERSION 0.2.4 - August 16, 2026 - Available on GitHub**

* **Added** automatic timeline detection from curated phase-exclusive quests. When WoW reports a known phase-specific quest as active on the current map or as an available quest-line starter, Zone Quest Guide can use that live quest evidence to identify the historical version without requiring a new Zidormi conversation every session.

* **Improved** Blasted Lands detection for the currently mapped Iron Horde quests. **Under Siege** and **Attack of the Iron Horde** are known PRESENT/Iron-Horde quests, so either quest can now establish the Blasted Lands timeline as PRESENT when WoW exposes it on the current map.

* **Added** a dedicated **Timeline** line directly below the current zone name in the main Zone Quest Guide window. Supported zones can now show player-facing text such as **PRESENT / Iron Horde (quest detected)**, **PAST / Before invasion (Zidormi)**, or **UNKNOWN (auto)** instead of hiding the phase state inside the zone subtitle.

* **Improved** phase learning so a curated quest-based detector can provide the reliable phase signal needed to record other live quest evidence. This lets the account-wide Horde/Alliance learning database continue gathering useful data even when the player has not spoken to Zidormi during the current login session.

* **Changed** quest-based timeline inference to stay conservative. Manual overrides and Zidormi remain stronger signals, and if curated live quest evidence points to conflicting phases at the same time, Zone QuestGuide does not guess from that quest evidence.

*In-game testing is still required for the new automatic quest-based detector and Timeline line. In PRESENT Blasted Lands, reload with **Under Siege** or **Attack of the Iron Horde** active without first talking to Zidormi and verify the panel reports **PRESENT / Iron Horde (quest detected)**, `/zq phase` identifies the evidence quest, phase learning records under PRESENT, and the existing navigation UI remains positioned correctly.*

---

**VERSION 0.2.3 - August 16, 2026 - Available on GitHub**

* **Added** account-wide local phase learning. When Zone Quest Guide already knows the current historical version of a map from Zidormi, a configured detector, or a manual phase override, it now records live WoW quest evidence for that map and phase.

* **Added** Horde/Alliance-separated learning data so multiple unquested alts can help map the same phased zone without mixing faction-specific quest observations together. The data is stored in the existing account-wide `ZoneQuestGuideDB` SavedVariable.

* **Added** evidence tracking for quests reported as available, offered by an NPC, accepted on the map, active at an NPC, accepted while the phase is known, and turned in while the phase is known. Completion is stored as supporting information but is not treated as proof that the quest belongs to the phase currently being viewed.

* **Added** `/zq learn` to show the current map's phase-learning status and `/zq export` to open a copyable phase-data report for testing/community contributions.

* **Improved** privacy of community data collection. The export intentionally contains zone IDs, faction, phase, quest IDs/names, observation counts, and phase-source information without character names, realm names, or character GUIDs.

* **Changed** phase learning to be evidence-only rather than automatically rewriting the official quest-phase database. A quest seen in one phase may still be available in another phase under different prerequisites, so learned data should be reviewed before it becomes a curated `QuestPhaseRequirements` entry.

* **Changed** community reporting to an explicit export workflow. The WoW addon itself does not silently upload data to GitHub or another server; automatic reporting would require a separate optional companion uploader outside the addon.

*In-game testing is still required to confirm phase observations accumulate correctly across Horde and Alliance alts, `/zq export` produces copyable data, quest acceptance/turn-in evidence is recorded under the correct timeline, and no character-identifying information appears in the export.*

---

**VERSION 0.2.2 - August 16, 2026 - Available on GitHub**

* **Fixed** a repeated Lua error from the floating navigation HUD when Retail WoW returned `GetUnitSpeed("player")` as a secret number. The HUD was comparing that protected value to a normal number while calculating ETA, which tainted execution and produced `attempt to compare local 'speed' (a secret number value...)` from `NavigationHUD.lua`.

* **Changed** the navigation HUD to stop reading player movement speed for ETA calculations. The HUD continues to show the selected quest, quest status, rotating direction arrow, and distance in yards when usable map/world-position data is available.

* **Improved** compatibility with Retail's protected/secret-value behavior by avoiding arithmetic and comparisons involving the movement-speed return value instead of trying to work around a protected value.

* **Confirmed** from the player's in-game Zidormi dialog that **"Show me the Blasted Lands before the invasion."** corresponds to the character currently being in the **PRESENT / Iron Horde** version of Blasted Lands. The player also reported visible objectives for **Under Siege** in that phase, matching the phase requirement currently assigned to that quest.

*In-game testing is still required after updating to confirm the secret-number error no longer occurs, the distance display continues updating normally, and the timeline-switch arrow still behaves correctly after switching between Blasted Lands phases.*

---

**VERSION 0.2.1 - August 16, 2026 - Available on GitHub**

* **Added** timeline-switch navigation guidance. When Zone Quest Guide knows the selected quest belongs to a different historical version of the current zone, the existing floating navigation HUD can now switch from the quest objective to the zone's timeline-switch NPC and display **SWITCH TIMELINE** instead of directing the player toward an unavailable objective.

* **Added** initial Blasted Lands Horde phase requirements for **Attack of the Iron Horde** and **Under Siege**. These quests are marked as requiring the present/Iron-Horde-incursion version of Blasted Lands. If Zidormi detection says the character is in the past version, the navigation HUD points to Zidormi and tells the player to switch to **PRESENT**.

* **Added** Blasted Lands Zidormi navigation data at the northern border so the timeline warning can be an actual directional arrow rather than only a text message.

* **Improved** phase-aware navigation so, after the player changes to the required timeline and Zone Quest Guide refreshes, the same HUD can return to the real quest target automatically.

*In-game testing is still required to confirm the HUD changes to **SWITCH TIMELINE**, points accurately to Zidormi in Blasted Lands, and returns to the quest target after changing phases. The Zidormi location and the Horde quest phase requirements are based on known game data, but the new v0.2.1 behavior has not yet been verified in-game.*

---

**VERSION 0.2.0 - August 16, 2026 - Available on GitHub**

* **Added** a new floating navigation HUD inspired by the large directional arrows used by full quest-guide addons. The HUD stays on screen independently of the main Zone Quest Guide window and shows the selected quest, its current status, and a large directional arrow.

* **Improved** directional navigation with a smoothly rotating drawn arrow instead of relying on Unicode arrow characters. The new HUD builds the arrow from WoW line regions, so it should avoid the missing-glyph/square problem seen with the original font-based indicator while also giving the player a much easier direction to follow at a glance.

* **Added** distance and travel-time information to the floating navigation HUD. When WoW exposes enough map/world-position information for the selected quest, Zone Quest Guide estimates the remaining distance in yards. While the character is moving, it also estimates travel time from the current movement speed. Quests without usable world-position data continue to show normal tracking information instead.

* **Added** **Shift-drag** positioning for the floating arrow. Its position is saved between sessions. `/zq arrow` toggles it and `/zq arrow reset` restores the default position.

* **Improved** navigation while using flight paths. WoW can report intermediate zone changes while a taxi flies across several maps, which could make a quest guide briefly replace the go-to destination with a quest from a zone the player was only passing over. Zone Quest Guide now keeps its floating HUD and addon-owned destination on the last stable quest while a taxi crosses into another map, then refreshes for the zone where the character actually lands.

  The main quest list still uses the older Core zone-refresh behavior and may visibly change while flying. This release specifically stabilizes the navigation target and go-to waypoint so a short flyover does not steal the destination marker.

*In-game testing is still required for the new floating arrow, smooth rotation, yard-distance conversion, ETA display, saved HUD position, and flight-path target hold. The existing automatic zone refresh was observed working in-game, but the new v0.2.0 navigation behavior has not yet been verified in-game.*

---

**VERSION 0.1.10 - August 16, 2026 - Available on GitHub**

* **Added** automatic Zidormi phase detection for historical-version zones. When the player talks to Zidormi, Zone Quest Guide now reads the gossip option she is offering and uses that as a strong clue for which version of the zone the character is currently standing in.

* **Improved** Blasted Lands phase handling based on the in-game Zidormi wording observed during testing. If Zidormi offers **"Take me back to the present."**, Zone Quest Guide treats the current version as **PAST**. If Zidormi instead offers to show the zone **before** an invasion/event or otherwise travel to the past, the character is currently in the **PRESENT** version.

  Previously, the phase framework could refresh when WoW reported a phase-related change, but it still needed a zone-specific detector or manual override to know which phase was actually active. Zidormi's own gossip option gives a much stronger clue because the destination she offers is the opposite of the current timeline.

* **Improved** phase switching after a Zidormi interaction. Zone Quest Guide remembers the phase Zidormi is offering to switch to for a short period. If WoW then reports a phase transition, the addon updates its session's detected phase to that destination. Merely closing Zidormi's gossip window does not change the detected phase.

* **Added** a **(Zidormi)** source label to the phase badge so the player can tell when the current **PAST** or **PRESENT** phase was identified from a Zidormi conversation rather than a manual override.

*In-game testing is still required to confirm the addon receives the expected Zidormi gossip text through WoW's gossip API and that the phase badge flips correctly after selecting the phase-switch option. The visible Blasted Lands Zidormi wording was confirmed in-game, but the new addon detection code has not yet been verified in-game.*

---

**VERSION 0.1.9 - August 16, 2026 - Available on GitHub**

* **Added** time-phase awareness for zones that can exist in more than one historical version.

  Zone Quest Guide now treats historical phases as a quest filter rather than another quest category. Live quests supplied by WoW continue to come from the character's active world state, while supplemental database records can be tagged with a phase such as `past` or `present`. Phase-tagged supplemental quests that do not match the selected phase are excluded so the addon does not direct the player toward an NPC that only exists in another version of the zone.

* **Added** per-zone phase overrides with `/zq phase`, `/zq phase auto`, `/zq phase past`, and `/zq phase present`. These overrides are intended as a fallback for phased zones where the client does not expose enough information for Zone Quest Guide to identify the historical version reliably on its own.

* **Improved** phase-sensitive refreshing. Zone Quest Guide now treats zone changes, quest-log changes, gossip closing, and WoW phase-change events as signals to rebuild phase-sensitive supplemental quest data and refresh the guide.

* **Changed** unknown phase handling to be conservative. If a supplemental quest is explicitly tagged for a historical phase and Zone Quest Guide cannot determine which phase is active, that static quest is hidden instead of risking a waypoint into the wrong version of the zone.

*In-game testing is still required in zones with historical/time phases. Zone-specific automatic phase detectors and phase-tagged quest data still need to be added as those zones are mapped.*

---

**VERSION 0.1.8 - August 16, 2026 - Available on GitHub**

* **Added** a separate **DAILY QUESTS** section so repeatable daily quests no longer appear mixed together with normal one-time zone progression quests.

  WoW exposes daily information through several quest sources, including current-map quest data, available quest-line information, the quest log, and NPC gossip quest data. Zone Quest Guide now combines those signals to identify daily quests and place them in their own section. This should make it much clearer which quests advance permanent zone completion and which quests are repeatable daily content.

* **Changed** automatic quest priority so normal **ZONE QUESTS** remain ahead of **DAILY QUESTS**. Within each section, the existing order is preserved: **AVAILABLE** first, then **TURN IN**, then **IN PROGRESS**. This prevents a nearby repeatable daily from pulling the navigation target away from unfinished one-time zone quests.

* **Improved** the main Zone Quest Guide window with visible **ZONE QUESTS** and **DAILY QUESTS** section headings and additional vertical space for the separated layout.

* **Improved** daily completion handling by relying on WoW's reset-aware completion state. A daily completed during the current reset can disappear from the unfinished list and become eligible to appear again after a later daily reset when WoW reports it as available again.

*In-game testing is still required to confirm daily quests are classified into the correct section across accepted, available, completed, and NPC-gossip states, and that normal zone quests remain the preferred automatic navigation target.*

---

**VERSION 0.1.7 - August 16, 2026 - Available on GitHub**

* **Added** a new **TURN IN** quest status. Accepted quests whose objectives are complete now change from **IN PROGRESS** to **TURN IN**, making it much easier to see which quests are ready to hand back to an NPC.

* **Improved** quest-status priority. **AVAILABLE** quests remain first as requested, completed **TURN IN** quests are shown next, and normal **IN PROGRESS** quests follow after them. If there are no available quests, automatic quest selection can therefore fall back to a completed quest before choosing one that still has unfinished objectives.

* **Improved** status consistency across the quest-priority and location-hint systems so a completed quest does not get changed back to **IN PROGRESS** when another part of the Zone Quest Guide window refreshes.

*In-game testing is still required to confirm quests switch to **TURN IN** immediately when their objectives become complete and return to the normal list flow after being handed in.*

---

**VERSION 0.1.6 - August 16, 2026 - Available on GitHub**

* **Fixed** the minimap/world-map destination not always changing cleanly when Zone Quest Guide switched from one available quest to another.

  Zone Quest Guide uses Blizzard user waypoints for quests that have not been accepted yet. The addon could select a new quest internally while the previous user waypoint was still the active destination, which made the minimap appear to keep pointing at the old quest giver. Zone Quest Guide now tracks the waypoint it created, removes that old destination when the selected available quest changes, and creates a fresh waypoint for the new target. If the next target does not have usable coordinates, the old marker is removed instead of being left behind and pointing to the wrong place.

* **Added** optional **Auto Accept** quest handling. When enabled, Zone Quest Guide can select available quests from an NPC and accept them automatically when the quest-detail page opens.

* **Added** optional **Auto Turn-in** handling for completed quests. When enabled, Zone Quest Guide can select completed quests from an NPC, advance the completion screen, and claim the reward automatically when there is no meaningful reward choice.

* **Added** a Zone Quest Guide options window with separate checkboxes for **Auto accept quests** and **Auto turn in completed quests**. Both options are disabled by default.

* **Added** `/zq options`, `/zq autoaccept`, and `/zq autoturnin`. `/zq autocomplete` is also accepted as an alias for auto turn-in.

* **Improved** quest automation safety. Holding **Shift** while interacting with an NPC temporarily bypasses automatic acceptance and turn-in without changing the saved settings. Quests with multiple reward choices are left open so the player can choose the reward manually.

*In-game testing is still required for waypoint switching, automatic quest acceptance, automatic turn-in, reward-choice handling, and special quest interactions in this release.*

---

**VERSION 0.1.5 - August 16, 2026 - Available on GitHub**

* **Added** location and elevation hints for quests where WoW's flat 2D map can make an NPC look like it is on the same level as nearby quests even when it is actually above, below, inside a cave, or on another floor.

* **Improved** **Horn of the Traitor** navigation at Freewind Post. The quest is now marked **[UPPER LEVEL]** in the Zone Quest Guide list and on the current target, and hovering the quest explains that Montarr is on top of Freewind Post and that the player should follow the path uphill.

  The normal WoW map waypoint only gives Zone Quest Guide a 2D map position, so it cannot reliably communicate terrain height by itself. This could make the Horn of the Traitor marker look like it belonged with the quest givers on the lower level even though Montarr is farther up the mountain. The new location-hint framework lets the addon add player-facing terrain guidance for known vertical or otherwise confusing locations without changing Blizzard's waypoint behavior.

* **Added** supplemental Horde and Alliance data for **Horn of the Traitor** at Freewind Post, including the quest-giver coordinates and prerequisite from the preceding Free Freewind Post quest.

*In-game testing is still required to confirm the new location badge and tooltip remain visible correctly while quest priority and auto-pointing refresh the list.*

---

**VERSION 0.1.4 - August 16, 2026 - Available on GitHub**

* **Changed** quest priority so **AVAILABLE** quests are shown before **IN PROGRESS** quests in the Zone Quest Guide window.

* **Improved** automatic navigation. Previously, accepted quests were sorted first, so the addon could keep pointing at an in-progress quest even when there was another quest nearby that the player had not picked up yet. Zone Quest Guide now prefers the nearest **AVAILABLE** quest and only falls back to an **IN PROGRESS** quest when there are no available quests in the displayed list.

* **Improved** the auto-track label to better describe the new behavior: the addon now focuses on the next available quest rather than simply the nearest unfinished quest.

*In-game testing is still required to confirm available-quest priority behaves correctly when several available and in-progress quests are present at the same time.*

---

**VERSION 0.1.3 - August 16, 2026 - Available on GitHub**

* **Fixed** the temporary quest-starter map waypoint remaining on the world map after the player accepts that quest.

  Zone Quest Guide uses a normal Blizzard user waypoint to mark the NPC for an available, unaccepted quest. Once that quest is accepted, Blizzard's normal quest tracking becomes the better source for objectives, but the old starter waypoint could remain behind and make the map look like the player still needed to return to the quest giver. Zone Quest Guide now listens for the quest acceptance event and removes the matching temporary waypoint when the accepted quest is the one the addon had pointed to. When the client exposes the waypoint coordinates, the addon also compares them before clearing so it is less likely to remove an unrelated waypoint the player placed manually.

* **Improved** the transition from **AVAILABLE** to **IN PROGRESS**. After accepting a quest, the quest-starter marker should disappear while the quest remains available to Blizzard's normal quest super-tracking.

*In-game testing is still required to confirm the temporary waypoint is removed immediately after quest acceptance without affecting unrelated player waypoints.*

---

**VERSION 0.1.2 - August 16, 2026 - Available on GitHub**

* **Fixed** the navigation arrow rendering as a small square or missing-glyph box on some WoW clients. The first version used Unicode arrow characters, but the game font being used by the addon does not reliably contain those glyphs. Zone Quest Guide now keeps the directional calculation but draws the result with a normal WoW texture instead, so the navigation indicator should display consistently.

* **Added** a minimap button for faster access to Zone Quest Guide. Left-clicking the button shows or hides the main window, right-clicking refreshes the current zone's quest list, and Shift-dragging moves the button around the minimap. Its position is saved between sessions.

* **Added** `/zq minimap` to hide or show the minimap button.

* **Added** an addon-list icon so Zone Quest Guide uses a normal map icon instead of WoW's red question-mark placeholder in the AddOn List.

*In-game testing is still required for the new arrow texture, minimap positioning, and minimap controls in this release.*

---

**VERSION 0.1.1 - August 16, 2026 - Available on GitHub**

* **Fixed** an issue where available quests could be missing from the Zone Quest Guide window even though the character could accept them from an NPC.

  Zone Quest Guide was reading `C_QuestLine.GetAvailableQuestLines()` immediately, but it was not first asking WoW to download the current map's quest-line information. Blizzard provides `C_QuestLine.RequestQuestLinesForMap()` for that purpose and reports updated information through `QUESTLINE_UPDATE`. The addon now requests the current zone's quest-line data and refreshes when WoW reports that updated information is available. Players should see more available quest starters without having to manually refresh the addon.

* **Added** live quest-offer detection. When you open an NPC's gossip window or quest-detail page, Zone Quest Guide now records quests WoW says are currently available and adds them to the current session's zone list. This helps with older quests that Blizzard does not expose through the normal map quest-line API.

* **Added** initial supplemental quest-chain coverage for both Horde and Alliance in Thousand Needles, including **Go Blow that Horn**, **Deliver the Goods**, and **Free Freewind Post**, with faction and prerequisite checks so the addon does not point the wrong faction toward those quests or show later quests before their prerequisites are complete.

* **Improved** `/zq refresh` so it also forces a new quest-line data request for the current map.

*In-game testing is still required for this release.*

---

**VERSION 0.1.0 - August 16, 2026 - Available on GitHub**

* **Added** the first public version of Zone Quest Guide with automatic zone detection, unfinished accepted-quest tracking, available quest-line discovery, Blizzard super-tracking, user waypoints, a lightweight directional arrow, and a supplemental quest database framework.

*In-game testing was required for this release.*