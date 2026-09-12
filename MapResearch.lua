local ADDON_NAME, ZQG = ...

local MAX_QUEUE = 5000
local sessionContexts = {}
local pendingRecord = false

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

local function CurrentTime()
    if GetServerTime then
        local ok, value = pcall(GetServerTime)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
    end
    return time and time() or 0
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

local function WireToken(value)
    value = tostring(value or "")
    value = value:gsub("[|\r\n]", "_")
    return value
end

local function PlayerClass()
    if ZQG.GetPlayerClassContext then
        local classID, classFile = ZQG.GetPlayerClassContext()
        return tonumber(classID) or 0, SafeString(classFile) or "UNKNOWN"
    end

    if UnitClass then
        local ok, _, classFile, classID = pcall(UnitClass, "player")
        if ok then
            return tonumber(classID) or 0, SafeString(classFile) or "UNKNOWN"
        end
    end
    return 0, "UNKNOWN"
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
    if UnitLevel then
        local ok, level = pcall(UnitLevel, "player")
        if ok and type(level) == "number" then
            return level
        end
    end
    return 0
end

local function GetStore()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    ZoneQuestGuideDB.companionSync = ZoneQuestGuideDB.companionSync or {
        version = 3,
        nextSequence = 1,
        observations = {},
    }

    local store = ZoneQuestGuideDB.companionSync
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

local function CurrentMapContext()
    if not C_Map or not C_Map.GetBestMapForUnit then
        return nil
    end

    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or type(mapID) ~= "number" or mapID <= 0 then
        return nil
    end

    local mapName
    local parentMapID = 0
    local mapType = 0
    if C_Map.GetMapInfo then
        local infoOK, info = pcall(C_Map.GetMapInfo, mapID)
        if infoOK and type(info) == "table" then
            mapName = SafeString(info.name)
            parentMapID = tonumber(info.parentMapID) or 0
            mapType = tonumber(info.mapType) or 0
        end
    end

    local instanceName
    local instanceType = "none"
    local difficultyID = 0
    local instanceID = 0
    if GetInstanceInfo then
        local infoOK, name, kind, difficulty, _, _, _, instance = pcall(GetInstanceInfo)
        if infoOK then
            instanceName = SafeString(name)
            instanceType = SafeString(kind) or "none"
            difficultyID = tonumber(difficulty) or 0
            instanceID = tonumber(instance) or 0
        end
    end

    local phase
    if ZQG.GetTimePhaseKey then
        local phaseOK, value = pcall(ZQG.GetTimePhaseKey, mapID)
        if phaseOK then
            phase = SafeString(value)
        end
    end

    return {
        mapID = mapID,
        mapName = mapName,
        parentMapID = parentMapID,
        mapType = mapType,
        instanceName = instanceName,
        instanceType = instanceType,
        difficultyID = difficultyID,
        instanceID = instanceID,
        phase = phase,
    }
end

local function ContextKey(context)
    return table.concat({
        tostring(context.mapID or 0),
        tostring(context.parentMapID or 0),
        tostring(context.mapType or 0),
        tostring(context.instanceID or 0),
        tostring(context.difficultyID or 0),
        tostring(context.instanceType or "none"),
        tostring(context.phase or ""),
    }, ":")
end

local function QueueMapObservation(context, force)
    context = context or CurrentMapContext()
    if not context or not context.mapID then
        return false
    end

    local signature = ContextKey(context)
    if not force and sessionContexts[signature] then
        return false
    end
    sessionContexts[signature] = true

    local classID, classFile = PlayerClass()
    local faction = PlayerFaction()
    local level = PlayerLevel()
    local observedAt = CurrentTime()
    local addonVersion = AddonVersion()

    local store = GetStore()
    local sequence = store.nextSequence
    store.nextSequence = sequence + 1
    local key = string.format("m%d-%d", observedAt, sequence)

    local observation = {
        key = key,
        sequence = sequence,
        type = "map",
        source = "local",
        mapID = context.mapID,
        mapName = context.mapName,
        parentMapID = context.parentMapID,
        mapType = context.mapType,
        instanceName = context.instanceName,
        instanceType = context.instanceType,
        difficultyID = context.difficultyID,
        instanceID = context.instanceID,
        faction = faction,
        classID = classID,
        classFile = classFile,
        level = level,
        phase = context.phase,
        observedAt = observedAt,
        addonVersion = addonVersion,
    }

    observation.wire = table.concat({
        "AQM1",
        WireToken(key),
        tostring(context.mapID),
        HexEncode(context.mapName),
        tostring(context.parentMapID or 0),
        tostring(context.mapType or 0),
        HexEncode(context.instanceName),
        WireToken(context.instanceType or "none"),
        tostring(context.difficultyID or 0),
        tostring(context.instanceID or 0),
        WireToken(faction),
        tostring(classID),
        WireToken(classFile),
        tostring(level),
        HexEncode(context.phase),
        tostring(observedAt),
        WireToken(addonVersion),
    }, "|")

    store.observations[#store.observations + 1] = observation
    PruneQueue(store)
    return true
end

local function PrintCurrentMap(forceRecord)
    local context = CurrentMapContext()
    if not context then
        Print("Current UiMapID is unavailable.")
        return
    end

    if forceRecord then
        QueueMapObservation(context, true)
    end

    local details = {
        string.format("UiMapID %d", context.mapID),
        context.mapName or "Unknown map",
    }
    if context.parentMapID and context.parentMapID > 0 then
        details[#details + 1] = "parent " .. tostring(context.parentMapID)
    end
    if context.instanceID and context.instanceID > 0 then
        details[#details + 1] = "instance " .. tostring(context.instanceID)
    end
    if context.difficultyID and context.difficultyID > 0 then
        details[#details + 1] = "difficulty " .. tostring(context.difficultyID)
    end
    if context.phase then
        details[#details + 1] = "phase " .. context.phase
    end
    Print(table.concat(details, " | ") .. (forceRecord and " | recorded" or ""))
end

local function ScheduleRecord(delay)
    if pendingRecord then
        return
    end
    pendingRecord = true
    C_Timer.After(delay or 0.25, function()
        pendingRecord = false
        QueueMapObservation(CurrentMapContext(), false)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
pcall(events.RegisterEvent, events, "UNIT_PHASE")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PHASE" and unit and unit ~= "player" then
        return
    end
    ScheduleRecord(event == "PLAYER_ENTERING_WORLD" and 1.0 or 0.25)
end)

local previousSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")
    if command == "map" or command == "map id" or command == "mapid" then
        PrintCurrentMap(false)
        return
    elseif command == "map record" then
        PrintCurrentMap(true)
        return
    end

    if previousSlashHandler then
        previousSlashHandler(msg)
    end
end

ZQG.QueueMapObservation = QueueMapObservation
ZQG.GetCurrentMapResearchContext = CurrentMapContext
