local ADDON_NAME, ZQG = ...

ZQG.TimePhaseZones = ZQG.TimePhaseZones or {}
ZQG.PhaseSwitchers = ZQG.PhaseSwitchers or {}

-- Central registry for Zidormi/Rhonormu timeline locations. WoW can expose
-- several UiMapIDs for the same named outdoor zone, so the registry supports
-- known map IDs plus live map/subzone name matching. Some timelines (notably
-- Midnight Quel'Thalas) use separate old/new maps, which also lets the map
-- itself become a reliable phase signal without requiring a Zidormi talk first.
local byMapID = {}
local byName = {}
local dynamicallyInjected = {}
local sessionPhaseByZoneKey = {}
local pendingSwitch

local function CanReadString(value)
    if type(value) ~= "string" then
        return false
    end

    if canaccessvalue and not canaccessvalue(value) then
        return false
    end

    return true
end

local function CanReadTable(value)
    if type(value) ~= "table" then
        return false
    end

    if canaccesstable and not canaccesstable(value) then
        return false
    end

    return true
end

local function Normalize(value)
    if not CanReadString(value) then
        return nil
    end

    local normalized = string.lower(value):gsub("^%s+", ""):gsub("%s+$", "")
    return normalized ~= "" and normalized or nil
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function CurrentMapName(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then
        return nil
    end

    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

local function CurrentSubzoneName()
    if GetSubZoneText then
        local text = GetSubZoneText()
        if text and text ~= "" then
            return text
        end
    end
    return nil
end

local function Register(definition)
    definition.config = definition.config or {
        phases = definition.phases,
    }

    for _, mapID in ipairs(definition.mapIDs or {}) do
        byMapID[mapID] = definition
        ZQG.TimePhaseZones[mapID] = definition.config
        if definition.switcher then
            ZQG.PhaseSwitchers[mapID] = definition.switcher
        end
    end

    for _, name in ipairs(definition.names or {}) do
        local key = Normalize(name)
        if key then
            byName[key] = definition
        end
    end

    return definition
end

-- Dustwallow Marsh / Theramore's Fall.
Register({
    key = "dustwallow",
    names = { "Dustwallow Marsh" },
    mapIDs = { 70, 1315 },
    phases = {
        past = "PAST / Before Theramore's Fall",
        present = "PRESENT / Ruins of Theramore",
    },
    switcher = {
        name = "Zidormi",
        x = 0.558,
        y = 0.496,
    },
})

-- Blasted Lands / Iron Horde incursion.
Register({
    key = "blastedlands",
    names = { "Blasted Lands" },
    mapIDs = { 17, 1246 },
    phases = {
        past = "PAST / Before invasion",
        present = "PRESENT / Iron Horde",
    },
    switcher = {
        name = "Zidormi",
        x = 0.482,
        y = 0.072,
    },
})

-- Peak of Serenity is only a subzone of Kun-Lai Summit. Name matching against
-- GetSubZoneText() keeps the timeline warning from appearing across all of
-- Kun-Lai when the player is nowhere near the phaseable monastery.
Register({
    key = "peakofserenity",
    names = { "Peak of Serenity" },
    phases = {
        past = "PAST / Peak before Legion",
        present = "PRESENT / After Legion attack",
    },
    switcher = {
        name = "Zidormi",
        x = 0.486,
        y = 0.428,
    },
})

-- Silithus / the Wound. Rhonormu can perform the same switch as Zidormi.
Register({
    key = "silithus",
    names = { "Silithus" },
    mapIDs = { 81, 1321, 2354 },
    npcNames = { "Zidormi", "Rhonormu" },
    phases = {
        past = "PAST / Before the Wound",
        present = "PRESENT / The Wound",
    },
    switcher = {
        name = "Zidormi or Rhonormu",
        x = 0.788,
        y = 0.220,
    },
})

-- Darkshore / War of the Thorns. Several Battle for Azeroth map variants have
-- existed for Darkshore, so include the known variants and also rely on live
-- name matching for any additional Retail alias that C_Map returns.
local darkshore = Register({
    key = "darkshore",
    names = { "Darkshore", "8.1 Darkshore Outdoor Final Phase" },
    mapIDs = { 62, 1203, 1309, 1332, 1333, 1338, 1343 },
    phases = {
        past = "PAST / Before War of the Thorns",
        present = "PRESENT / After War of the Thorns",
    },
    switcher = {
        name = "Zidormi",
        x = 0.484,
        y = 0.250,
    },
})

-- The Darkshore switch also restores old Teldrassil/Darnassus. Do not attach
-- Darkshore map coordinates to those maps; the label can follow the shared
-- phase state, while navigation should simply tell the player where Zidormi is.
Register({
    key = darkshore.key,
    names = { "Teldrassil", "Darnassus" },
    config = darkshore.config,
    switcher = {
        name = "Zidormi in Darkshore",
    },
})

-- Tirisfal Glades / Battle for Lordaeron.
local tirisfal = Register({
    key = "tirisfal",
    names = { "Tirisfal Glades" },
    mapIDs = { 18, 1247 },
    phases = {
        past = "PAST / Before Battle for Lordaeron",
        present = "PRESENT / After Battle for Lordaeron",
    },
    switcher = {
        name = "Zidormi",
        x = 0.694,
        y = 0.628,
    },
})

Register({
    key = tirisfal.key,
    names = { "Undercity" },
    config = tirisfal.config,
    switcher = {
        name = "Zidormi in Tirisfal Glades",
    },
})

-- Arathi Highlands / Battle for Stromgarde.
Register({
    key = "arathi",
    names = { "Arathi Highlands" },
    mapIDs = { 14, 906, 943, 1044, 1158, 1244 },
    phases = {
        past = "PAST / Before Battle for Stromgarde",
        present = "PRESENT / Warfront era",
    },
    switcher = {
        name = "Zidormi",
        x = 0.382,
        y = 0.900,
    },
})

-- Uldum / Visions of N'Zoth assaults.
Register({
    key = "uldum",
    names = { "Uldum" },
    mapIDs = { 249, 1330, 1527, 1571 },
    phases = {
        past = "PAST / Cataclysm Uldum",
        present = "PRESENT / N'Zoth assaults",
    },
    switcher = {
        name = "Zidormi",
        x = 0.560,
        y = 0.352,
    },
})

-- Vale of Eternal Blossoms / Visions of N'Zoth assaults.
Register({
    key = "vale",
    names = { "Vale of Eternal Blossoms" },
    mapIDs = { 390, 520, 521, 1530, 1570 },
    phases = {
        past = "PAST / Before N'Zoth assaults",
        present = "PRESENT / N'Zoth assaults",
    },
    switcher = {
        name = "Zidormi",
        x = 0.810,
        y = 0.296,
    },
})

-- Midnight rebuilt Eversong Woods as UiMapID 2395 and Silvermoon City as 2393.
-- The legacy Burning Crusade maps remain separate (Eversong/Ghostlands and old
-- Silvermoon map IDs below). The player confirmed in-game that the visible
-- Thalassian Pass portal can move directly into the legacy area and that the
-- Zidormi gossip option also teleports there. Because old/current are separate
-- maps, use the live map identity as stronger evidence than cached gossip state.
local quelthalas = Register({
    key = "quelthalas",
    names = {
        "Eversong Woods",
        "Silvermoon City",
        "Ghostlands",
        "Eversong Woods (Burning Crusade)",
        "Ghostlands (Burning Crusade)",
        "Silvermoon City (Burning Crusade)",
    },
    mapIDs = { 94, 95, 1267, 1268, 1269, 2393, 2395 },
    phaseByMapID = {
        [94] = "past",
        [95] = "past",
        [1267] = "past",
        [1268] = "past",
        [1269] = "past",
        [2393] = "present",
        [2395] = "present",
    },
    phaseByName = {
        ["eversong woods"] = "present",
        ["silvermoon city"] = "present",
        ["ghostlands"] = "past",
        ["eversong woods (burning crusade)"] = "past",
        ["ghostlands (burning crusade)"] = "past",
        ["silvermoon city (burning crusade)"] = "past",
    },
    phases = {
        past = "PAST / Burning Crusade Quel'Thalas",
        present = "PRESENT / Midnight Quel'Thalas",
    },
    switcher = {
        name = "Zidormi at Thalassian Pass",
    },
})

local function FindDefinition(mapID)
    if not mapID then
        return nil
    end

    local direct = byMapID[mapID]
    if direct then
        return direct, true
    end

    local subzone = Normalize(CurrentSubzoneName())
    if subzone and byName[subzone] then
        return byName[subzone], false
    end

    local mapName = Normalize(CurrentMapName(mapID))
    if mapName and byName[mapName] then
        return byName[mapName], false
    end

    return nil
end

local function DetectDefinitionPhase(definition, mapID)
    if not definition or not mapID then
        return nil
    end

    if definition.phaseByMapID then
        local phase = definition.phaseByMapID[mapID]
        if phase then
            return tostring(phase):lower()
        end
    end

    if definition.phaseByName then
        local mapName = Normalize(CurrentMapName(mapID))
        local phase = mapName and definition.phaseByName[mapName] or nil
        if phase then
            return tostring(phase):lower()
        end
    end

    if type(definition.detectPhase) == "function" then
        local ok, phase = pcall(definition.detectPhase, mapID)
        if ok and phase and phase ~= "" then
            return tostring(phase):lower()
        end
    end

    return nil
end

local function ApplyDefinitionToMap(mapID, definition, isStatic)
    local previous = dynamicallyInjected[mapID]
    if previous and previous ~= definition then
        if ZQG.TimePhaseZones[mapID] == previous.config then
            ZQG.TimePhaseZones[mapID] = nil
        end
        if ZQG.PhaseSwitchers[mapID] == previous.switcher then
            ZQG.PhaseSwitchers[mapID] = nil
        end
        dynamicallyInjected[mapID] = nil
    end

    if not definition then
        if previous then
            if ZQG.TimePhaseZones[mapID] == previous.config then
                ZQG.TimePhaseZones[mapID] = nil
            end
            if ZQG.PhaseSwitchers[mapID] == previous.switcher then
                ZQG.PhaseSwitchers[mapID] = nil
            end
            dynamicallyInjected[mapID] = nil
        end
        return
    end

    ZQG.TimePhaseZones[mapID] = definition.config
    if definition.switcher then
        ZQG.PhaseSwitchers[mapID] = definition.switcher
    end

    if not isStatic then
        dynamicallyInjected[mapID] = definition
    end
end

local function EnsureCurrentMapRegistration()
    local mapID = CurrentMapID()
    if not mapID then
        return nil
    end

    local definition, isStatic = FindDefinition(mapID)
    ApplyDefinitionToMap(mapID, definition, isStatic)
    return definition
end

local function NPCName()
    if not UnitName then
        return nil
    end
    local name = UnitName("npc")
    return CanReadString(name) and name or nil
end

local function NPCMatches(definition, npcName)
    local normalizedNPC = Normalize(npcName)
    if not definition or not normalizedNPC then
        return false
    end

    local names = definition.npcNames or { "Zidormi" }
    for _, name in ipairs(names) do
        if Normalize(name) == normalizedNPC then
            return true
        end
    end

    return false
end

local function DefinitionForCurrentNPC()
    local mapID = CurrentMapID()
    local npcName = NPCName()
    if not mapID or not npcName then
        return nil
    end

    local definition = EnsureCurrentMapRegistration()
    if definition and NPCMatches(definition, npcName) then
        return definition
    end

    -- The Midnight Quel'Thalas switch is physically in Eastern Plaguelands,
    -- while the affected old/current maps are Eversong/Ghostlands/Silvermoon.
    if Normalize(npcName) == "zidormi"
        and Normalize(CurrentMapName(mapID)) == "eastern plaguelands" then
        local subzone = Normalize(CurrentSubzoneName()) or ""
        if subzone:find("thalassian", 1, true) then
            return quelthalas
        end
    end

    return nil
end

local function ClassifyTimelineOption(text)
    local lower = Normalize(text)
    if not lower then
        return nil
    end

    -- Every known return option explicitly sends the player back/returns them
    -- to the present. That means the current world state is the older phase.
    if lower:find("present", 1, true)
        and (lower:find("back", 1, true) or lower:find("return", 1, true)) then
        return "past", "present"
    end

    -- The outbound wording varies by zone: "before...", "show me...",
    -- "during the time of the Cataclysm", or similar historical phrasing.
    -- Restrict this broad matching to known timeline NPCs/locations above.
    if lower:find("before", 1, true)
        or lower:find("past", 1, true)
        or lower:find("show me", 1, true)
        or lower:find("relive", 1, true)
        or lower:find("during", 1, true)
        or lower:find("age of", 1, true) then
        return "present", "past"
    end

    return nil
end

local originalGetTimePhaseKey = ZQG.GetTimePhaseKey
if originalGetTimePhaseKey then
    ZQG.GetTimePhaseKey = function(mapID)
        mapID = mapID or CurrentMapID()
        local phase, source = originalGetTimePhaseKey(mapID)

        -- Manual overrides remain the strongest local choice.
        if source == "manual" then
            return phase, source
        end

        local definition = mapID and FindDefinition(mapID) or nil

        -- When old/current are distinct maps, trust the current map over a
        -- session value that might have been set before a portal transition.
        local mapDetected = DetectDefinitionPhase(definition, mapID)
        if mapDetected then
            return mapDetected, "detected"
        end

        local sessionPhase = definition and sessionPhaseByZoneKey[definition.key] or nil
        if sessionPhase then
            return sessionPhase, "zidormi"
        end

        return phase, source
    end
end

local function RefreshTimelineState()
    EnsureCurrentMapRegistration()

    if ZQG.RefreshForTimePhase then
        ZQG.RefreshForTimePhase()
    elseif ZQG.Refresh then
        ZQG.Refresh()
    end

    if ZQG.RefreshTimelineStatus then
        C_Timer.After(0.05, ZQG.RefreshTimelineStatus)
    end
end

local function CaptureTimelineGossip()
    local definition = DefinitionForCurrentNPC()
    if not definition or not C_GossipInfo or not C_GossipInfo.GetOptions then
        return false
    end

    local ok, options = pcall(C_GossipInfo.GetOptions)
    if not ok or not CanReadTable(options) then
        return false
    end

    for index, info in ipairs(options) do
        if CanReadTable(info) then
            local text = info.name or info.text or info.optionText
            local currentPhase, targetPhase = ClassifyTimelineOption(text)
            if currentPhase then
                sessionPhaseByZoneKey[definition.key] = currentPhase
                pendingSwitch = {
                    zoneKey = definition.key,
                    targetPhase = targetPhase,
                    gossipOptionID = info.gossipOptionID,
                    orderIndex = info.orderIndex or index,
                    fallbackIndex = index,
                    expires = (GetTime and GetTime() or 0) + 30,
                }
                C_Timer.After(0.05, RefreshTimelineState)
                return true
            end
        end
    end

    return false
end

local function PendingIsValid()
    if not pendingSwitch then
        return false
    end

    local now = GetTime and GetTime() or 0
    if pendingSwitch.expires and now > pendingSwitch.expires then
        pendingSwitch = nil
        return false
    end

    return true
end

local function ConfirmSelectedSwitch(value, byIndex)
    if not PendingIsValid() then
        return
    end

    local matches
    if byIndex then
        matches = value == pendingSwitch.orderIndex or value == pendingSwitch.fallbackIndex
    else
        matches = pendingSwitch.gossipOptionID ~= nil and value == pendingSwitch.gossipOptionID
    end

    if not matches then
        return
    end

    sessionPhaseByZoneKey[pendingSwitch.zoneKey] = pendingSwitch.targetPhase
    pendingSwitch = nil

    C_Timer.After(0, RefreshTimelineState)
    C_Timer.After(0.75, RefreshTimelineState)
end

-- Observe the user's normal gossip click without selecting anything ourselves.
if hooksecurefunc and C_GossipInfo then
    if C_GossipInfo.SelectOption then
        hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
            ConfirmSelectedSwitch(optionID, false)
        end)
    end

    if C_GossipInfo.SelectOptionByIndex then
        hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(orderIndex)
            ConfirmSelectedSwitch(orderIndex, true)
        end)
    end
end

if hooksecurefunc and type(SelectGossipOption) == "function" then
    hooksecurefunc("SelectGossipOption", function(index)
        ConfirmSelectedSwitch(index, true)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("GOSSIP_CLOSED")
pcall(events.RegisterEvent, events, "UNIT_PHASE")

events:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
        CaptureTimelineGossip()
        return
    end

    if event == "GOSSIP_CLOSED" then
        -- A successful selection is captured by the secure hooks before close.
        pendingSwitch = nil
    end

    -- Portal-driven timelines can change maps without any gossip selection.
    -- Re-run the full phase refresh on world/zone changes so filtering, learning,
    -- the Timeline line, and telemetry all see the new map-derived phase.
    if event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "UNIT_PHASE" then
        C_Timer.After(0.10, RefreshTimelineState)
        return
    end

    EnsureCurrentMapRegistration()
    if ZQG.RefreshTimelineStatus then
        C_Timer.After(0.10, ZQG.RefreshTimelineStatus)
    end
end)

EnsureCurrentMapRegistration()

ZQG.GetTimelineZoneDefinition = function(mapID)
    mapID = mapID or CurrentMapID()
    return mapID and FindDefinition(mapID) or nil
end

ZQG.GetRegisteredTimelinePhase = function(mapID)
    mapID = mapID or CurrentMapID()
    local definition = mapID and FindDefinition(mapID) or nil
    local mapDetected = DetectDefinitionPhase(definition, mapID)
    if mapDetected then
        return mapDetected
    end
    return definition and sessionPhaseByZoneKey[definition.key] or nil
end
