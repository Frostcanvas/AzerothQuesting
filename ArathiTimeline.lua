local ADDON_NAME, ZQG = ...

-- Arathi Highlands now exposes more than the original two-state Zidormi model.
-- Live testing in Retail showed a current-world map (2372) and the familiar
-- Arathi map (14), while Zidormi can offer separate destinations for the
-- present, the Fourth War, and the older pre-Fourth-War version. Keep this
-- targeted override separate from the generic two-state timeline registry.

local ARATHI_MAP_IDS = {
    [14] = true,
    [906] = true,
    [943] = true,
    [1044] = true,
    [1158] = true,
    [1244] = true,
    [2372] = true,
}

local ARATHI_CONFIG = {
    phases = {
        past = "PAST / Before Fourth War",
        fourthwar = "FOURTH WAR / Warfront era",
        present = "PRESENT / Current Arathi Highlands",
    },
}

local ARATHI_SWITCHER = {
    name = "Zidormi",
    x = 0.382,
    y = 0.900,
}

local sessionPhase
local optionTargetByID = {}
local optionTargetByIndex = {}

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

    local text = string.lower(value):gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text or nil
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function MapName(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then
        return nil
    end

    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

local function IsArathiMap(mapID)
    if not mapID then
        return false
    end

    if ARATHI_MAP_IDS[mapID] then
        return true
    end

    return Normalize(MapName(mapID)) == "arathi highlands"
end

local function ApplyArathiConfig(mapID)
    mapID = mapID or CurrentMapID()
    if not IsArathiMap(mapID) then
        return false
    end

    ZQG.TimePhaseZones = ZQG.TimePhaseZones or {}
    ZQG.PhaseSwitchers = ZQG.PhaseSwitchers or {}
    ZQG.TimePhaseZones[mapID] = ARATHI_CONFIG
    ZQG.PhaseSwitchers[mapID] = ARATHI_SWITCHER
    return true
end

for mapID in pairs(ARATHI_MAP_IDS) do
    ZQG.TimePhaseZones = ZQG.TimePhaseZones or {}
    ZQG.PhaseSwitchers = ZQG.PhaseSwitchers or {}
    ZQG.TimePhaseZones[mapID] = ARATHI_CONFIG
    ZQG.PhaseSwitchers[mapID] = ARATHI_SWITCHER
end

local originalGetTimePhaseKey = ZQG.GetTimePhaseKey
if originalGetTimePhaseKey then
    ZQG.GetTimePhaseKey = function(mapID)
        mapID = mapID or CurrentMapID()
        local phase, source = originalGetTimePhaseKey(mapID)

        -- Explicit player overrides must remain stronger than automatic Arathi
        -- handling, just as they are for the generic timeline system.
        if source == "manual" then
            return phase, source
        end

        if not IsArathiMap(mapID) then
            return phase, source
        end

        ApplyArathiConfig(mapID)

        -- Player-confirmed live Retail value: map 2372 is the current/present
        -- Arathi Highlands. This map identity is stronger than stale gossip.
        if mapID == 2372 then
            return "present", "detected"
        end

        -- On the other Arathi maps, the same UiMapID can participate in more
        -- than one Zidormi state. Use the three-way gossip/session result rather
        -- than the older generic two-state session classification.
        if sessionPhase then
            return sessionPhase, "zidormi"
        end

        -- Preserve a genuinely curated quest-based detector if one is added.
        if source == "detected" and phase then
            return phase, source
        end

        return nil, "auto"
    end
end

local function TargetPhaseForOption(text)
    local lower = Normalize(text)
    if not lower then
        return nil
    end

    if lower:find("present", 1, true) then
        return "present"
    end

    if lower:find("fourth war", 1, true) then
        return "fourthwar"
    end

    if lower:find("before", 1, true) and lower:find("war", 1, true) then
        return "past"
    end

    return nil
end

local function InferCurrentPhase(targets)
    local count = 0
    for _ in pairs(targets) do
        count = count + 1
    end

    -- When Zidormi exposes two of the three destinations, the missing one is
    -- the state the player is currently standing in.
    if count >= 2 then
        if not targets.past then
            return "past"
        elseif not targets.fourthwar then
            return "fourthwar"
        elseif not targets.present then
            return "present"
        end
    end

    return nil
end

local function RefreshArathi()
    local mapID = CurrentMapID()
    if not ApplyArathiConfig(mapID) then
        return
    end

    if ZQG.RefreshForTimePhase then
        ZQG.RefreshForTimePhase()
    elseif ZQG.Refresh then
        ZQG.Refresh()
    end

    if ZQG.RefreshTimelineStatus then
        C_Timer.After(0.05, ZQG.RefreshTimelineStatus)
    end
end

local function CaptureArathiGossip()
    local mapID = CurrentMapID()
    if not IsArathiMap(mapID) or Normalize(UnitName and UnitName("npc")) ~= "zidormi" then
        return
    end

    ApplyArathiConfig(mapID)
    optionTargetByID = {}
    optionTargetByIndex = {}

    if not C_GossipInfo or not C_GossipInfo.GetOptions then
        return
    end

    local ok, options = pcall(C_GossipInfo.GetOptions)
    if not ok or not CanReadTable(options) then
        return
    end

    local targets = {}
    for index, info in ipairs(options) do
        if CanReadTable(info) then
            local text = info.name or info.text or info.optionText
            local target = TargetPhaseForOption(text)
            if target then
                targets[target] = true
                optionTargetByIndex[info.orderIndex or index] = target
                optionTargetByIndex[index] = target
                if info.gossipOptionID ~= nil then
                    optionTargetByID[info.gossipOptionID] = target
                end
            end
        end
    end

    if mapID == 2372 then
        sessionPhase = "present"
    else
        local inferred = InferCurrentPhase(targets)
        if inferred then
            sessionPhase = inferred
        end
    end

    C_Timer.After(0.08, RefreshArathi)
end

local function SelectedTarget(value, byIndex)
    if byIndex then
        return optionTargetByIndex[value]
    end
    return optionTargetByID[value]
end

local function ConfirmArathiSelection(value, byIndex)
    local target = SelectedTarget(value, byIndex)
    if not target then
        return
    end

    sessionPhase = target
    optionTargetByID = {}
    optionTargetByIndex = {}

    C_Timer.After(0, RefreshArathi)
    C_Timer.After(0.75, RefreshArathi)
end

if hooksecurefunc and C_GossipInfo then
    if C_GossipInfo.SelectOption then
        hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
            ConfirmArathiSelection(optionID, false)
        end)
    end

    if C_GossipInfo.SelectOptionByIndex then
        hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(orderIndex)
            ConfirmArathiSelection(orderIndex, true)
        end)
    end
end

if hooksecurefunc and type(SelectGossipOption) == "function" then
    hooksecurefunc("SelectGossipOption", function(index)
        ConfirmArathiSelection(index, true)
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
        CaptureArathiGossip()
        return
    end

    if event == "GOSSIP_CLOSED" then
        optionTargetByID = {}
        optionTargetByIndex = {}
        return
    end

    local mapID = CurrentMapID()
    if IsArathiMap(mapID) then
        ApplyArathiConfig(mapID)
        if mapID == 2372 then
            sessionPhase = "present"
        end
        C_Timer.After(0.15, RefreshArathi)
    end
end)

ApplyArathiConfig(CurrentMapID())

ZQG.GetArathiTimelinePhase = function()
    local mapID = CurrentMapID()
    if mapID == 2372 then
        return "present", "detected"
    end
    if IsArathiMap(mapID) then
        return sessionPhase, sessionPhase and "zidormi" or "auto"
    end
    return nil, nil
end
