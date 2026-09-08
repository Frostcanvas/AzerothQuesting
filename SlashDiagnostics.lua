local ADDON_NAME, ZQG = ...

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function CurrentMapName(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then
        return "Unknown"
    end

    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or "Unknown"
end

local function PlayerFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player") or "Neutral"
    end
    return "Neutral"
end

local function MapQuestCount(mapID)
    local learning = ZoneQuestGuideDB and ZoneQuestGuideDB.mapQuestLearning
    local mapData = learning and learning.maps and learning.maps[mapID] or nil
    local factionData = mapData and mapData.factions and mapData.factions[PlayerFaction()] or nil
    local quests = factionData and factionData.quests or nil
    local count = 0

    for _ in pairs(quests or {}) do
        count = count + 1
    end

    return count
end

local function PhaseInfo(mapID)
    if not mapID or not ZQG.GetTimePhaseKey then
        return nil, nil
    end

    local phase, source = ZQG.GetTimePhaseKey(mapID)
    return phase and tostring(phase):upper() or nil, source
end

local function PrintMapID()
    local mapID = CurrentMapID()
    if not mapID then
        Print("Map ID is unavailable for the player right now.")
        return
    end

    Print(string.format("Map ID: %d / %s", mapID, CurrentMapName(mapID)))
end

local function PrintMaps()
    local mapID = CurrentMapID()
    if not mapID then
        Print("Current map is unavailable.")
        return
    end

    local count = MapQuestCount(mapID)
    Print(string.format(
        "Map learning: %d / %s - %d recorded %s quest%s.",
        mapID,
        CurrentMapName(mapID),
        count,
        PlayerFaction(),
        count == 1 and "" or "s"
    ))
end

local function PrintPhase()
    local mapID = CurrentMapID()
    if not mapID then
        Print("Current map is unavailable.")
        return
    end

    local phase, source = PhaseInfo(mapID)
    if phase then
        Print(string.format(
            "Current timeline: %s (%s) on map %d / %s.",
            phase,
            tostring(source or "unknown"),
            mapID,
            CurrentMapName(mapID)
        ))
    else
        Print(string.format(
            "Current timeline: UNKNOWN (%s) on map %d / %s.",
            tostring(source or "no reliable signal"),
            mapID,
            CurrentMapName(mapID)
        ))
    end
end

local function PrintCheck()
    local mapID = CurrentMapID()
    if not mapID then
        Print("Diagnostic check: current map is unavailable.")
        return
    end

    local phase, source = PhaseInfo(mapID)
    local phaseText = phase or "UNKNOWN"
    local sourceText = tostring(source or "no reliable signal")
    local count = MapQuestCount(mapID)

    local wagoText = "Wago unavailable"
    if ZQG.GetWagoTelemetryStatus then
        local status = ZQG.GetWagoTelemetryStatus()
        if status then
            if status.providerLoaded then
                wagoText = string.format(
                    "Wago loaded; session phase=%d map/quest=%d mapvisit=%d phasevisit=%d instancevisit=%d discoveries=%d",
                    tonumber(status.phaseSent) or 0,
                    tonumber(status.mapQuestSent) or 0,
                    tonumber(status.mapVisitSent) or 0,
                    tonumber(status.phaseVisitSent) or 0,
                    tonumber(status.instanceVisitSent) or 0,
                    tonumber(status.discoverySwitchSent) or 0
                )
            elseif status.registered then
                wagoText = "Wago registered; provider not loaded"
            else
                wagoText = "Wago not registered"
            end
        end
    end

    Print(string.format(
        "Check: map %d / %s | timeline %s (%s) | %d learned %s quest%s | %s.",
        mapID,
        CurrentMapName(mapID),
        phaseText,
        sourceText,
        count,
        PlayerFaction(),
        count == 1 and "" or "s",
        wagoText
    ))
end

-- Loaded last on purpose. Several older modules extend /zq by wrapping the
-- previous slash handler. This final diagnostic router guarantees the commands
-- used for timeline/map testing cannot fall through to Core.lua's default
-- show/hide toggle even if an earlier wrapper chain becomes fragile.
local previousSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "phase" then
        PrintPhase()
        return
    elseif command == "maps" or command == "maplearn" or command == "maplearning" then
        PrintMaps()
        return
    elseif command == "mapid" then
        PrintMapID()
        return
    elseif command == "check" or command == "debug" then
        PrintCheck()
        return
    elseif command == "inspect" or command == "instance" then
        if ZQG.PrintInstanceInspect then
            ZQG.PrintInstanceInspect()
        else
            Print("Instance diagnostics are unavailable on this build.")
        end
        return
    end

    if previousSlashHandler then
        previousSlashHandler(msg)
    end
end
