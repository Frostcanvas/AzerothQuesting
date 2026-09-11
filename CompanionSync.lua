local ADDON_NAME, ZQG = ...

local MAX_QUEUE = 5000
local VALID_EVIDENCE = {
    seen = true,
    available = true,
    offered = true,
    accepted = true,
    active = true,
    turnedIn = true,
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function AddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, version = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
        if ok and version and version ~= "" then
            return version
        end
    elseif GetAddOnMetadata then
        local ok, version = pcall(GetAddOnMetadata, ADDON_NAME, "Version")
        if ok and version and version ~= "" then
            return version
        end
    end
    return "unknown"
end

local function PlayerClass()
    if not UnitClass then
        return 0, "UNKNOWN"
    end

    local ok, _, classFile, classID = pcall(UnitClass, "player")
    if not ok then
        return 0, "UNKNOWN"
    end

    if canaccessvalue then
        if classFile ~= nil and not canaccessvalue(classFile) then
            classFile = nil
        end
        if classID ~= nil and not canaccessvalue(classID) then
            classID = nil
        end
    end

    if type(classFile) ~= "string" or classFile == "" then
        classFile = "UNKNOWN"
    end
    if type(classID) ~= "number" then
        classID = 0
    end

    return classID, classFile
end

local function PlayerFaction()
    if UnitFactionGroup then
        local ok, faction = pcall(UnitFactionGroup, "player")
        if ok and (faction == "Alliance" or faction == "Horde" or faction == "Neutral") then
            return faction
        end
    end
    return "Neutral"
end

local function PlayerLevel()
    if not UnitLevel then
        return 0
    end
    local ok, level = pcall(UnitLevel, "player")
    if ok and type(level) == "number" then
        return level
    end
    return 0
end

local function IsCompleted(questID)
    if not questID or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
        return false
    end
    local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and completed and true or false
end

local function CurrentTime()
    if GetServerTime then
        local ok, value = pcall(GetServerTime)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
    end
    return time and time() or 0
end

local function WireToken(value)
    value = tostring(value or "")
    value = value:gsub("[|\r\n]", "_")
    return value
end

local function SafeString(value)
    if value == nil then
        return nil
    end
    if canaccessvalue and not canaccessvalue(value) then
        return nil
    end
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function QuestTitle(questID, context)
    local title = SafeString(context and context.questName)
    if title then
        return title
    end

    if ZQG.GetQuestCatalogStore then
        local store = ZQG.GetQuestCatalogStore()
        local record = store and store.records and store.records[questID]
        title = record and SafeString(record.name) or nil
        if title then
            return title
        end
    end

    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, value = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok then
            title = SafeString(value)
            if title then
                return title
            end
        end
    end

    return nil
end

local function HexEncode(value)
    value = SafeString(value)
    if not value then
        return ""
    end

    local encoded = {}
    for index = 1, #value do
        encoded[index] = string.format("%02X", string.byte(value, index))
    end
    return table.concat(encoded)
end

local function GetStore()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    ZoneQuestGuideDB.companionSync = ZoneQuestGuideDB.companionSync or {
        version = 3,
        nextSequence = 1,
        observations = {},
    }

    local store = ZoneQuestGuideDB.companionSync
    store.version = 3
    store.nextSequence = tonumber(store.nextSequence) or 1
    store.observations = store.observations or {}
    return store
end

local function PruneQueue(store)
    local count = #store.observations
    if count <= MAX_QUEUE then
        return
    end

    local keepFrom = count - MAX_QUEUE + 1
    local compact = {}
    for index = keepFrom, count do
        compact[#compact + 1] = store.observations[index]
    end
    store.observations = compact
end

local function QueueQuestObservation(questID, evidence, mapID, context)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end
    if type(mapID) ~= "number" or mapID <= 0 then
        return false
    end
    if not VALID_EVIDENCE[evidence] then
        return false
    end

    context = context or {}
    local classID, classFile = PlayerClass()
    local faction = PlayerFaction()
    local level = PlayerLevel()

    if context.classID ~= nil then
        classID = tonumber(context.classID) or 0
    end
    if type(context.classFile) == "string" and context.classFile ~= "" then
        classFile = context.classFile
    end
    if context.faction == "Alliance" or context.faction == "Horde" or context.faction == "Neutral" then
        faction = context.faction
    end
    if context.level ~= nil then
        level = tonumber(context.level) or 0
    end

    local store = GetStore()
    local sequence = store.nextSequence
    store.nextSequence = sequence + 1
    local observedAt = tonumber(context.observedAt) or CurrentTime()
    local source = context.source == "peer" and "peer" or "local"
    local completed = context.completed
    if completed == nil and source == "local" then
        completed = IsCompleted(questID)
    else
        completed = completed and true or false
    end

    local addonVersion = AddonVersion()
    local questName = QuestTitle(questID, context)
    local key = string.format("%d-%d", observedAt, sequence)
    local observation = {
        key = key,
        sequence = sequence,
        type = "quest",
        source = source,
        questID = questID,
        questName = questName,
        mapID = mapID,
        evidence = evidence,
        faction = faction,
        classID = classID,
        classFile = classFile,
        level = level,
        completed = completed and true or false,
        observedAt = observedAt,
        addonVersion = addonVersion,
    }

    -- Keep the original AQO1 record so older Companions can still upload the
    -- observation. When a title is known, AQO2 adds the same observation key plus
    -- a hex-encoded UTF-8 quest title; updated Companions prefer AQO2 for that key.
    observation.wire = table.concat({
        "AQO1",
        WireToken(key),
        WireToken(source),
        tostring(questID),
        tostring(mapID),
        WireToken(evidence),
        WireToken(faction),
        tostring(classID),
        WireToken(classFile),
        tostring(level),
        completed and "1" or "0",
        tostring(observedAt),
        WireToken(addonVersion),
    }, "|")

    if questName then
        observation.wire2 = table.concat({
            "AQO2",
            WireToken(key),
            WireToken(source),
            tostring(questID),
            tostring(mapID),
            WireToken(evidence),
            WireToken(faction),
            tostring(classID),
            WireToken(classFile),
            tostring(level),
            completed and "1" or "0",
            tostring(observedAt),
            WireToken(addonVersion),
            HexEncode(questName),
        }, "|")
    end

    store.observations[#store.observations + 1] = observation
    PruneQueue(store)
    return true
end

local function SyncStatus()
    local store = GetStore()
    local count = #store.observations
    local newest = count > 0 and store.observations[count] or nil
    if newest then
        Print(string.format(
            "Companion sync queue: %d observation%s, newest key %s. The Companion can upload these after WoW writes AzerothQuesting.lua.",
            count,
            count == 1 and "" or "s",
            tostring(newest.key)
        ))
    else
        Print("Companion sync queue is empty. Quest observations will be queued automatically while you play.")
    end
end

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "sync" or command == "sync status" or command == "companion" then
        SyncStatus()
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.QueueCompanionQuestObservation = QueueQuestObservation
ZQG.GetCompanionSyncStore = GetStore
ZQG.GetPlayerClassContext = PlayerClass
