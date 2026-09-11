local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
local originalGetTimePhaseKey = ZQG.GetTimePhaseKey
if not originalGetTimePhaseKey then
    return
end

-- TimePhases.lua can identify the timeline when Zidormi's gossip opens, but
-- some clients do not reliably fire UNIT_PHASE after the player chooses the
-- timeline-switch option. Keep a small public-facing synchronization layer that
-- watches the actual Zidormi option selection and immediately updates the
-- timeline source used by the rest of Azeroth Questing.
local selectedZidormiPhases = {}
local pendingZidormiSwitch
local timelineText
local updateScheduled = false

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

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function IsZidormiNPC()
    if not UnitName then
        return false
    end

    local name = UnitName("npc")
    return CanReadString(name) and string.lower(name) == "zidormi"
end

-- Preserve manual overrides as the strongest source. A Zidormi value learned by
-- this module only replaces automatic/session detection, including the stale
-- pre-switch Zidormi value that motivated this fix.
ZQG.GetTimePhaseKey = function(mapID)
    mapID = mapID or CurrentMapID()
    local phase, source = originalGetTimePhaseKey(mapID)

    if source == "manual" then
        return phase, source
    end

    local zidormiPhase = mapID and selectedZidormiPhases[mapID] or nil
    if zidormiPhase then
        return zidormiPhase, "zidormi"
    end

    return phase, source
end

local function ZoneHasTimeline(mapID)
    if not mapID then
        return false
    end

    if ZQG.TimePhaseZones and ZQG.TimePhaseZones[mapID] then
        return true
    end

    return ZQG.PhaseSwitchers and ZQG.PhaseSwitchers[mapID] ~= nil
end

local function FindTimelineText()
    if timelineText or not mainFrame then
        return timelineText
    end

    for _, region in ipairs({ mainFrame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text and text:find("Timeline:", 1, true) then
                timelineText = region
                return timelineText
            end

            -- TimePhases.lua creates its dedicated line at this exact anchor but
            -- initially hides it with no text. Reuse that region instead of
            -- creating a duplicate line.
            local point, relativeTo, _, x, y = region:GetPoint(1)
            local width = region:GetWidth()
            if point == "TOPLEFT" and relativeTo == mainFrame
                and math.abs((x or 0) - 16) < 1
                and math.abs((y or 0) + 45) < 1
                and math.abs((width or 0) - 325) < 2 then
                timelineText = region
                return timelineText
            end
        end
    end

    timelineText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timelineText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -45)
    timelineText:SetWidth(325)
    timelineText:SetJustifyH("LEFT")

    -- Keep the compact legacy arrow below the new line if an older TimePhases
    -- build did not already move it.
    for _, region in ipairs({ mainFrame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString"
            and region:GetText() == "↑" then
            region:ClearAllPoints()
            region:SetPoint("TOP", mainFrame, "TOP", 0, -64)
            break
        end
    end

    return timelineText
end

local function BuildTimelineText(mapID)
    if not ZoneHasTimeline(mapID) then
        return nil
    end

    local phase, source = ZQG.GetTimePhaseKey(mapID)
    if not phase then
        local switcher = ZQG.PhaseSwitchers and ZQG.PhaseSwitchers[mapID] or nil
        local name = switcher and switcher.name or "the timeline NPC"
        return "|cffffcc00Timeline: UNKNOWN - talk to " .. name .. " before questing.|r"
    end

    local config = ZQG.TimePhaseZones and ZQG.TimePhaseZones[mapID] or nil
    local label = config and config.phases and config.phases[phase]
        or tostring(phase):upper()
    local suffix

    if source == "manual" then
        suffix = " (manual)"
    elseif source == "zidormi" then
        suffix = " (Zidormi)"
    elseif source == "detected" then
        local evidence = ZQG.GetTimePhaseEvidence and ZQG.GetTimePhaseEvidence(mapID) or nil
        suffix = evidence and " (quest detected)" or " (detected)"
    elseif source == "auto" then
        suffix = " (auto)"
    else
        suffix = source and (" (" .. tostring(source) .. ")") or ""
    end

    return "|cff66ccffTimeline:|r " .. label .. suffix
end

local function UpdateTimelineText()
    local textRegion = FindTimelineText()
    if not textRegion then
        return
    end

    local text = BuildTimelineText(CurrentMapID())
    if not text then
        textRegion:SetText("")
        textRegion:Hide()
        return
    end

    textRegion:SetText(text)
    textRegion:Show()
end

local function ScheduleTimelineUpdate(delay)
    if updateScheduled then
        return
    end

    updateScheduled = true
    C_Timer.After(delay or 0.10, function()
        updateScheduled = false
        UpdateTimelineText()
    end)
end

local function RefreshAfterTimelineChange()
    if ZQG.RefreshForTimePhase then
        ZQG.RefreshForTimePhase()
    elseif ZQG.Refresh then
        ZQG.Refresh()
    end

    -- WoW can apply the world phase a fraction of a second after the gossip
    -- click. Refresh now for the visible label, then once more after the world
    -- state has had time to settle.
    ScheduleTimelineUpdate(0.05)
    C_Timer.After(0.75, function()
        if ZQG.RefreshForTimePhase then
            ZQG.RefreshForTimePhase()
        elseif ZQG.Refresh then
            ZQG.Refresh()
        end
        ScheduleTimelineUpdate(0.05)
    end)
end

local function DetectZidormiSwitchOption()
    if not IsZidormiNPC() or not C_GossipInfo or not C_GossipInfo.GetOptions then
        return false
    end

    local mapID = CurrentMapID()
    if not mapID then
        return false
    end

    local ok, options = pcall(C_GossipInfo.GetOptions)
    if not ok or not CanReadTable(options) then
        return false
    end

    for index, info in ipairs(options) do
        if CanReadTable(info) then
            local text = info.name or info.text or info.optionText
            if CanReadString(text) then
                local lower = string.lower(text)
                local currentPhase
                local targetPhase

                if lower:find("present", 1, true)
                    and (lower:find("back", 1, true) or lower:find("return", 1, true)) then
                    currentPhase = "past"
                    targetPhase = "present"
                elseif lower:find("before", 1, true) or lower:find("past", 1, true) then
                    currentPhase = "present"
                    targetPhase = "past"
                end

                if currentPhase then
                    selectedZidormiPhases[mapID] = currentPhase
                    pendingZidormiSwitch = {
                        mapID = mapID,
                        targetPhase = targetPhase,
                        gossipOptionID = info.gossipOptionID,
                        orderIndex = info.orderIndex or index,
                        fallbackIndex = index,
                        expires = (GetTime and GetTime() or 0) + 30,
                    }
                    ScheduleTimelineUpdate(0.05)
                    return true
                end
            end
        end
    end

    return false
end

local function PendingSwitchIsValid(pending)
    if not pending then
        return false
    end

    local now = GetTime and GetTime() or 0
    if pending.expires and now > pending.expires then
        pendingZidormiSwitch = nil
        return false
    end

    if CurrentMapID() ~= pending.mapID then
        pendingZidormiSwitch = nil
        return false
    end

    return true
end

local function ConfirmSelectedSwitch(value, byIndex)
    local pending = pendingZidormiSwitch
    if not PendingSwitchIsValid(pending) then
        return
    end

    local matches
    if byIndex then
        matches = value == pending.orderIndex or value == pending.fallbackIndex
    else
        matches = pending.gossipOptionID ~= nil and value == pending.gossipOptionID
    end

    if not matches then
        return
    end

    selectedZidormiPhases[pending.mapID] = pending.targetPhase
    pendingZidormiSwitch = nil
    C_Timer.After(0, RefreshAfterTimelineChange)
end

-- Observe the option the default UI actually selects. This is deliberately a
-- post-hook: Azeroth Questing never clicks Zidormi for the player and does not
-- interfere with Blizzard's normal gossip handling.
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
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUESTLINE_UPDATE")
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("GOSSIP_CLOSED")
pcall(events.RegisterEvent, events, "UNIT_PHASE")

events:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
        DetectZidormiSwitchOption()
        ScheduleTimelineUpdate(0.08)
        return
    end

    if event == "GOSSIP_CLOSED" then
        -- Closing Zidormi without choosing the switch must not flip phases.
        -- A real selection is captured by the secure hooks above before this.
        pendingZidormiSwitch = nil
    end

    ScheduleTimelineUpdate(0.15)
end)

-- TimePhases.lua also updates the timeline line after normal refreshes. Run our
-- wording shortly afterward so phased zones with an unknown timeline always
-- show the explicit Zidormi-before-questing instruction requested for learning.
local previousRefresh = ZQG.Refresh
if previousRefresh then
    ZQG.Refresh = function(...)
        local results = { previousRefresh(...) }
        ScheduleTimelineUpdate(0.10)
        return unpack(results)
    end
end

if mainFrame then
    mainFrame:HookScript("OnShow", function()
        ScheduleTimelineUpdate(0.05)
    end)
end

C_Timer.After(0.10, UpdateTimelineText)

ZQG.RefreshTimelineStatus = UpdateTimelineText
