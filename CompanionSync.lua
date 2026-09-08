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

local function GetStore()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    ZoneQuestGuideDB.companionSync = ZoneQuestGuideDB.companionSync or {
        version = 1,
        nextSequence = 1,
        observations = {},
    }

    local store = ZoneQuestGuideDB.companionSync
    store.version = 1
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

    store.observations[#store.observations + 1] = {
        key = string.format("%d-%d", observedAt, sequence),
        sequence = sequence,
        type = "quest",
        source = source,
        questID = questID,
        mapID = mapID,
        evidence = evidence,
        faction = faction,
        classID = classID,
        classFile = classFile,
        level = level,
        completed = completed and true or false,
        observedAt = observedAt,
        addonVersion = AddonVersion(),
    }

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
