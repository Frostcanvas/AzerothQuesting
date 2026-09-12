from pathlib import Path

path = Path('CHANGELOG.md')
current = path.read_text(encoding='utf-8')
entry = '''# Azeroth Questing Changelog

**VERSION 0.3.0 Beta 18 - September 12, 2026 - Available on GitHub Pre-release**

* **Added** privacy-preserving **UiMapID research tracking** so Azeroth Questing can learn the different map copies used by phased and scenario content such as **Battle for Darkshore** and **Battle for Stromgarde** instead of treating every appearance of the zone as one map.

* **Added** automatic map-context observations on world entry, zone/map transitions, indoor map changes, and player phase changes. Each identity-free observation can include the current UiMapID, map name, parent UiMapID, UI map type, WoW instance name/type, difficulty ID, instance ID, faction, class, level, known Azeroth Questing timeline/phase label, observation time, and addon version.

* **Added** session deduplication for map research. The same exact map/instance/phase context is recorded once per login session, while a different UiMapID, instance, difficulty, or known timeline context becomes a separate research observation.

* **Added** `/aq map` (also `/aq map id` and `/aq mapid`) to show the current UiMapID and useful map/instance context in chat, plus `/aq map record` to deliberately record the current context again when testing a phased map.

* **Added** the `AQM1` SavedVariables handoff for map research. The record intentionally excludes character name, realm, GUID, BattleTag, account identity, peer sender identity, and local filesystem paths. Existing `AQO1`/`AQO2` quest research and P2P quest evidence are unchanged.

* **Compatibility:** automatic server upload of `AQM1` observations requires **Azeroth Questing Companion 0.1.9-beta.11 or newer** and **Azeroth Questing Server 0.2.9 or newer**. No Website build is required for this addon change; the LAN Azeroth Questing Research dashboard is provided by the server.

*Beta 18 still requires in-game validation. Verify `/aq map` reports the expected UiMapID, normal zone changes do not cause Lua/taint errors, and multiple Battle for Darkshore / Battle for Stromgarde variants are recorded as their actual UiMapIDs. End-to-end Companion/server synchronization also remains to be verified after Server 0.2.9 is deployed. No successful Beta 18 in-game or live-server test is claimed yet.*

---

'''
if not current.startswith('# Azeroth Questing Changelog\n\n'):
    raise SystemExit('Unexpected changelog header')
path.write_text(entry + current[len('# Azeroth Questing Changelog\n\n'):], encoding='utf-8')
