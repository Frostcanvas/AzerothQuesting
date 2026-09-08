from pathlib import Path


def read(path):
    return Path(path).read_text(encoding="utf-8")


def write(path, text):
    Path(path).write_text(text, encoding="utf-8")


def replace_once(path, old, new):
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}: {old[:120]!r}")
    write(path, text.replace(old, new, 1))


path = "MapQuestLearning.lua"
text = read(path)
text = text.replace("version = 1,\n        maps = {},", "version = 2,\n        maps = {},", 1)
text = text.replace("store.version = 1", "store.version = 2", 1)
write(path, text)

replace_once(
    path,
    '''local function PlayerFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player") or "Neutral"
    end
    return "Neutral"
end
''',
    '''local function PlayerFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player") or "Neutral"
    end
    return "Neutral"
end

local function PlayerClass()
    if ZQG.GetPlayerClassContext then
        return ZQG.GetPlayerClassContext()
    end

    if UnitClass then
        local ok, _, classFile, classID = pcall(UnitClass, "player")
        if ok then
            if canaccessvalue then
                if classFile ~= nil and not canaccessvalue(classFile) then
                    classFile = nil
                end
                if classID ~= nil and not canaccessvalue(classID) then
                    classID = nil
                end
            end
            if type(classFile) == "string" and classFile ~= "" and type(classID) == "number" then
                return classID, classFile
            end
        end
    end

    return 0, "UNKNOWN"
end
''',
)

replace_once(
    path,
    '''        active = 0,
        turnedIn = 0,
    }
''',
    '''        active = 0,
        turnedIn = 0,
        classes = {},
    }
''',
)

replace_once(
    path,
    '''    return quest
end

local function RecordMapQuestEvidence''',
    '''    quest.classes = quest.classes or {}
    return quest
end

local function EnsureClassRecord(quest)
    local classID, classFile = PlayerClass()
    quest.classes = quest.classes or {}
    quest.classes[classFile] = quest.classes[classFile] or {
        classID = classID,
        completed = false,
        seen = 0,
        available = 0,
        offered = 0,
        accepted = 0,
        active = 0,
        turnedIn = 0,
    }

    local record = quest.classes[classFile]
    record.classID = classID
    if IsCompleted and quest.completed then
        record.completed = true
    end
    return record, classID, classFile
end

local function RecordMapQuestEvidence''',
)

replace_once(
    path,
    '''    local faction = PlayerFaction()
    local quest = EnsureQuestRecord(mapID, faction, questID, name)

    local seenKey = EvidenceKey(mapID, faction, questID, "seen")
    if not sessionEvidence[seenKey] then
        sessionEvidence[seenKey] = true
        quest.seen = (quest.seen or 0) + 1
    end

    evidence = evidence or "seen"
    if evidence ~= "seen" then
        local evidenceKey = EvidenceKey(mapID, faction, questID, evidence)
        if not sessionEvidence[evidenceKey] then
            sessionEvidence[evidenceKey] = true
            quest[evidence] = (quest[evidence] or 0) + 1
        end
    end
''',
    '''    local faction = PlayerFaction()
    local quest = EnsureQuestRecord(mapID, faction, questID, name)
    local classRecord, classID, classFile = EnsureClassRecord(quest)

    local seenKey = EvidenceKey(mapID, faction, questID, "seen")
    if not sessionEvidence[seenKey] then
        sessionEvidence[seenKey] = true
        quest.seen = (quest.seen or 0) + 1
        classRecord.seen = (classRecord.seen or 0) + 1
        if ZQG.QueueCompanionQuestObservation then
            ZQG.QueueCompanionQuestObservation(questID, "seen", mapID, {
                faction = faction,
                classID = classID,
                classFile = classFile,
                completed = quest.completed and true or false,
            })
        end
    end

    evidence = evidence or "seen"
    if evidence ~= "seen" then
        local evidenceKey = EvidenceKey(mapID, faction, questID, evidence)
        if not sessionEvidence[evidenceKey] then
            sessionEvidence[evidenceKey] = true
            quest[evidence] = (quest[evidence] or 0) + 1
            classRecord[evidence] = (classRecord[evidence] or 0) + 1
            if quest.completed then
                classRecord.completed = true
            end
            if ZQG.QueueCompanionQuestObservation then
                ZQG.QueueCompanionQuestObservation(questID, evidence, mapID, {
                    faction = faction,
                    classID = classID,
                    classFile = classFile,
                    completed = quest.completed and true or false,
                })
            end
            if ZQG.BroadcastMapQuestEvidence then
                ZQG.BroadcastMapQuestEvidence(questID, evidence, mapID)
            end
        end
    end
''',
)

text = read(path)
start = text.index("local function BuildMapQuestExport()")
end = text.index("local function BuildCombinedExport()", start)
new_export = '''local function BuildMapQuestExport()
    local store = GetStore()
    local lines = {
        "ZQGMAPQUESTDATA|3",
        "# mapID\\tmapName\\tfaction\\tclassID\\tclassFile\\tquestID\\tname\\tcompleted\\tseen\\tavailable\\toffered\\taccepted\\tactive\\tturnedIn",
    }

    local function AppendLine(mapID, mapData, faction, questID, quest, classID, classFile, record)
        lines[#lines + 1] = table.concat({
            SafeField(mapID),
            SafeField(mapData.name),
            SafeField(faction),
            SafeField(classID or 0),
            SafeField(classFile or "UNKNOWN"),
            SafeField(questID),
            SafeField(quest.name),
            record.completed and "1" or "0",
            tostring(record.seen or 0),
            tostring(record.available or 0),
            tostring(record.offered or 0),
            tostring(record.accepted or 0),
            tostring(record.active or 0),
            tostring(record.turnedIn or 0),
        }, "\\t")
    end

    for _, mapID in ipairs(SortedKeys(store.maps, true)) do
        local mapData = store.maps[mapID]
        for _, faction in ipairs(SortedKeys(mapData.factions or {})) do
            local factionData = mapData.factions[faction]
            for _, questID in ipairs(SortedKeys(factionData.quests or {}, true)) do
                local quest = factionData.quests[questID]
                local classKeys = SortedKeys(quest.classes or {})
                if #classKeys == 0 then
                    -- Older v1 learning data did not record class context. Keep it
                    -- visible without assigning those historical observations to
                    -- whichever class happens to be logged in after the upgrade.
                    AppendLine(mapID, mapData, faction, questID, quest, 0, "UNKNOWN", quest)
                else
                    for _, classFile in ipairs(classKeys) do
                        local classRecord = quest.classes[classFile]
                        AppendLine(
                            mapID,
                            mapData,
                            faction,
                            questID,
                            quest,
                            classRecord.classID or 0,
                            classFile,
                            classRecord
                        )
                    end
                end
            end
        end
    end

    return table.concat(lines, "\\n")
end

'''
write(path, text[:start] + new_export + text[end:])

replace_once(
    path,
    'exportNote:SetText("Includes tab-separated phase evidence plus map ID + quest associations. No character name, realm, GUID, guild, or account identifier is included.")',
    'exportNote:SetText("Includes tab-separated phase evidence plus map, quest, faction, and class ID/token observations. No character name, realm, GUID, guild, or account identifier is included.")',
)

# TOC/version/load order.
toc = "AzerothQuesting.toc"
text = read(toc)
if "## Version: 0.2.30" not in text:
    raise SystemExit("Unexpected addon version in TOC")
text = text.replace("## Version: 0.2.30", "## Version: 0.2.31", 1)
text = text.replace("PhaseLearning.lua\nMapQuestLearning.lua", "PhaseLearning.lua\nCompanionSync.lua\nMapQuestLearning.lua\nAzerothNetwork.lua", 1)
write(toc, text)

# Changelog: prepend the release-worthy entry while preserving all history.
changelog = "CHANGELOG.md"
text = read(changelog)
header = "# Azeroth Questing Changelog\n\n"
if not text.startswith(header):
    raise SystemExit("Unexpected changelog header")
entry = '''**VERSION 0.2.31 - September 8, 2026 - Available on GitHub**

* **Added** the first **Azeroth Questing Network** client layer. Retail clients register the `AZQUEST` addon-message prefix and automatically join the temporary custom channel `AzerothQuesting`. The channel is joined without adding protocol traffic to normal chat, while `/aq network` reports whether the prefix and custom channel are active.

* **Added** anonymous peer quest-evidence exchange for `available`, `offered`, `active`, and `turnedIn` observations. Messages carry only protocol version, quest ID, map ID, faction, class ID/token, completion state, and evidence type; sender names are not written to SavedVariables or the Companion queue.

* **Added** a bounded Companion synchronization queue in SavedVariables. Local and accepted peer quest observations are queued with a stable observation key, timestamp, addon version, quest/map/evidence context, faction, class ID/token, level, and completion state so the future **Azeroth Questing Companion** can upload structured records to the Service01 API after WoW writes `AzerothQuesting.lua`.

* **Added** per-class quest learning. New observations now preserve WoW class ID/token counts (for example `MAGE`, `SHAMAN`, or `DRUID`) under each learned quest so server-side research can compare which classes actually observed a quest instead of mixing every class into one total.

* **Changed** the map-learning store to schema version 2 and the tab-separated map/quest export to `ZQGMAPQUESTDATA|3`, adding `classID` and `classFile` columns. Historical observations created before v0.2.31 remain labeled `UNKNOWN` rather than being incorrectly assigned to the class that first logs in after the update.

* **Improved** Retail Midnight chat-lockdown handling by checking Blizzard's outgoing addon-message restriction APIs before network sends and queueing transient throttle/lockdown failures for retry. The in-game custom channel supplements the Companion/Service01 path; it is not a replacement for global server synchronization and is limited by WoW's custom-channel reach.

*This v0.2.31 network, class-learning, and Companion-queue update has not been tested in World of Warcraft. After updating, `/reload` and verify there are no Lua errors; open the Chat Channels pane and look for `AzerothQuesting` under custom channels; run `/aq network` and confirm `AZQUEST` is registered and the channel is joined; run `/aq sync` before and after interacting with quests to verify the queue count rises; use `/aq mapexport` and confirm new rows include the logged-in class ID/token. If a second Retail client with v0.2.31 is available on the same connected-realm custom-channel scope, verify `received`/`peers` can increase without protocol text appearing in normal chat. Also retest the still-outstanding v0.2.29 rename and v0.2.28 breadcrumb behavior. GitHub remains the only listed distribution platform because no downloadable Wago release has been published.*

---
'''
write(changelog, header + entry + text[len(header):])
