local ADDON_NAME, ZQG = ...

ZoneQuestGuideDB = ZoneQuestGuideDB or {}
ZQG.TimePhaseZones = ZQG.TimePhaseZones or {}

-- Keep an untouched copy of supplemental quest records. The active
-- ZQG.StaticQuests table can then be rebuilt whenever the player's historical
-- phase changes without losing quests from the other phase.
local phaseMaster = {}
for mapID, quests in pairs(ZQG.StaticQuests or {}) do
    phaseMaster[mapID] = {}
    for index, quest in ipairs(quests) do
        phaseMaster[mapID][index] = quest
    end
end

-- Direct interaction with Zidormi can expose the active historical version of
-- a zone through her gossip option. Remember that strong signal for the current
-- session without permanently saving it, because the player can switch again.
local sessionDetectedPhases = {}
local pendingZidormiSwitch
local lastQuestPhaseEvidence = {}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function CurrentMapID()
    if not C_Map or not C_Map.GetBestMapForUnit then
        return nil
    end
    return C_Map.GetBestMapForUnit("player")
end

local function GetDB()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    ZoneQuestGuideDB.phaseOverrides = ZoneQuestGuideDB.phaseOverrides or {}
    return ZoneQuestGuideDB
end

-- WoW secret values still report their underlying Lua type, so type(value) by
-- itself does not guarantee that addon-tainted code may inspect or normalize
-- the value. Use the access predicates when available before any string/table
-- operations that would otherwise throw an immediate Lua error.
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

local function IsZidormiNPC()
    if not UnitName then
        return false
    end

    local name = UnitName("npc")
    return CanReadString(name) and string.lower(name) == "zidormi"
end

local function DetectZidormiGossipPhase()
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

    local currentPhase
    local targetPhase

    for _, info in ipairs(options) do
        if CanReadTable(info) then
            local text = info.name or info.text or info.optionText
            if CanReadString(text) then
                local lower = string.lower(text)

                -- Example confirmed in Blasted Lands during testing:
                -- "Take me back to the present." means the player is currently
                -- standing in the older/past version of the zone.
                if lower:find("present", 1, true)
                    and (lower:find("back", 1, true) or lower:find("return", 1, true)) then
                    currentPhase = "past"
                    targetPhase = "present"
                    break
                end

                -- Zidormi's opposite option commonly offers to show the player the
                -- zone before an invasion/event or otherwise sends them to the past.
                if lower:find("before", 1, true) or lower:find("past", 1, true) then
                    currentPhase = "present"
                    targetPhase = "past"
                    break
                end
            end
        end
    end

    if not currentPhase then
        return false
    end

    sessionDetectedPhases[mapID] = currentPhase

    local now = GetTime and GetTime() or 0
    pendingZidormiSwitch = {
        mapID = mapID,
        targetPhase = targetPhase,
        expires = now + 15,
    }

    return true
end

local function GetExclusiveQuestPhase(questID)
    local requirement = questID and ZQG.QuestPhaseRequirements
        and ZQG.QuestPhaseRequirements[questID] or nil

    if type(requirement) == "string" and requirement ~= "" then
        return requirement:lower()
    end

    -- A table can describe a quest valid in multiple phases. That is useful for
    -- filtering, but it is not exclusive enough to identify the current phase.
    if type(requirement) == "table" and #requirement == 1 then
        return tostring(requirement[1]):lower()
    end

    return nil
end

local function DetectQuestEvidencePhase(mapID)
    if not mapID or not ZQG.QuestPhaseRequirements then
        return nil
    end

    local detectedPhase
    local evidence
    local conflict = false

    local function ConsiderQuest(questID, name, evidenceType)
        local phase = GetExclusiveQuestPhase(questID)
        if not phase then
            return
        end

        if detectedPhase and detectedPhase ~= phase then
            conflict = true
            return
        end

        detectedPhase = phase
        if not evidence then
            evidence = {
                questID = questID,
                name = name,
                evidenceType = evidenceType,
                phase = phase,
            }
        end
    end

    -- Current-map quest data is useful because it is the same live source Core
    -- uses for accepted quest navigation. A curated phase-exclusive quest on the
    -- active map can therefore establish the timeline without requiring a new
    -- Zidormi conversation every login.
    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info and info.questID then
                    ConsiderQuest(info.questID, nil, "active")
                end
            end
        end
    end

    -- Available quest-line starters are another strong live phase signal when
    -- the quest ID has already been curated as phase-exclusive.
    if C_QuestLine and C_QuestLine.GetAvailableQuestLines then
        local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
        if ok and type(lines) == "table" then
            for _, info in ipairs(lines) do
                if info and info.questID then
                    ConsiderQuest(
                        info.questID,
                        info.questName or info.questLineName,
                        "available"
                    )
                end
            end
        end
    end

    if conflict or not detectedPhase then
        lastQuestPhaseEvidence[mapID] = nil
        return nil
    end

    if evidence and (not evidence.name or evidence.name == "")
        and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, evidence.questID)
        if ok and title and title ~= "" then
            evidence.name = title
        end
    end

    lastQuestPhaseEvidence[mapID] = evidence
    return detectedPhase
end

local function ZoneHasPhaseData(mapID)
    if not mapID then
        return false
    end

    local DB = GetDB()
    if DB.phaseOverrides[mapID] then
        return true
    end

    if sessionDetectedPhases[mapID] then
        return true
    end

    if ZQG.TimePhaseZones[mapID] then
        return true
    end

    if ZQG.PhaseSwitchers and ZQG.PhaseSwitchers[mapID] then
        return true
    end

    local quests = phaseMaster[mapID]
    if not quests then
        return false
    end

    for _, quest in ipairs(quests) do
        if quest.phase then
            return true
        end
    end

    return false
end

local function DetectConfiguredPhase(mapID)
    local config = mapID and ZQG.TimePhaseZones[mapID] or nil
    if not config or type(config.detect) ~= "function" then
        return nil
    end

    local ok, phaseKey = pcall(config.detect)
    if ok and phaseKey and phaseKey ~= "" then
        return tostring(phaseKey):lower()
    end

    return nil
end

function ZQG.GetTimePhaseKey(mapID)
    mapID = mapID or CurrentMapID()
    if not mapID then
        return nil, "unknown"
    end

    local DB = GetDB()
    local override = DB.phaseOverrides[mapID]
    if override and override ~= "auto" then
        return tostring(override):lower(), "manual"
    end

    local zidormiPhase = sessionDetectedPhases[mapID]
    if zidormiPhase then
        return zidormiPhase, "zidormi"
    end

    local detected = DetectConfiguredPhase(mapID)
    if detected then
        lastQuestPhaseEvidence[mapID] = nil
        return detected, "detected"
    end

    local questDetected = DetectQuestEvidencePhase(mapID)
    if questDetected then
        return questDetected, "detected"
    end

    return nil, "auto"
end

local function PhaseMatches(questPhase, activePhase)
    if not questPhase then
        return true
    end

    -- Phase-tagged supplemental quests are intentionally hidden when the phase
    -- cannot be identified. Showing no static record is safer than pointing the
    -- player toward an NPC that only exists in another historical version.
    if not activePhase then
        return false
    end

    if type(questPhase) == "table" then
        for _, phaseKey in ipairs(questPhase) do
            if tostring(phaseKey):lower() == activePhase then
                return true
            end
        end
        return false
    end

    return tostring(questPhase):lower() == activePhase
end

function ZQG.ApplyTimePhaseFilter(mapID)
    mapID = mapID or CurrentMapID()
    if not mapID then
        return
    end

    local master = phaseMaster[mapID]
    if not master then
        return
    end

    local activePhase = ZQG.GetTimePhaseKey(mapID)
    local filtered = {}

    for _, quest in ipairs(master) do
        if PhaseMatches(quest.phase, activePhase) then
            filtered[#filtered + 1] = quest
        end
    end

    ZQG.StaticQuests[mapID] = filtered
end

local function GetPhaseDisplay(mapID)
    if not ZoneHasPhaseData(mapID) then
        return nil
    end

    local phaseKey, source = ZQG.GetTimePhaseKey(mapID)
    local config = ZQG.TimePhaseZones[mapID]
    local label

    if phaseKey and config and config.phases and config.phases[phaseKey] then
        label = config.phases[phaseKey]
    elseif phaseKey then
        label = phaseKey:upper()
    else
        label = "UNKNOWN"
    end

    if source == "manual" then
        return label .. " (manual)"
    elseif source == "zidormi" then
        return label .. " (Zidormi)"
    elseif source == "detected" then
        if lastQuestPhaseEvidence[mapID] then
            return label .. " (quest detected)"
        end
        return label .. " (detected)"
    elseif source == "auto" then
        return label .. " (auto)"
    end

    return label
end

-- Add a dedicated timeline line directly below the current zone name in the
-- main Azeroth Questing panel. The old compact arrow is moved down slightly so
-- the additional line does not overlap it. UIExtras.lua later anchors its arrow
-- texture to that same FontString, so the visual direction indicator follows.
local mainFrame = _G.ZoneQuestGuideFrame
local phaseText
if mainFrame then
    phaseText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    phaseText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -45)
    phaseText:SetWidth(325)
    phaseText:SetJustifyH("LEFT")
    phaseText:Hide()

    for _, region in ipairs({ mainFrame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString"
            and region:GetText() == "↑" then
            region:ClearAllPoints()
            region:SetPoint("TOP", mainFrame, "TOP", 0, -64)
            break
        end
    end
end

local function UpdateZonePhaseBadge()
    local mapID = CurrentMapID()
    local display = GetPhaseDisplay(mapID)

    if not phaseText then
        return
    end

    if not display then
        phaseText:SetText("")
        phaseText:Hide()
        return
    end

    phaseText:SetText("|cff66ccffTimeline:|r " .. display)
    phaseText:Show()
end

local function RefreshForPhaseChange()
    local mapID = CurrentMapID()
    if not mapID then
        return
    end

    ZQG.ApplyTimePhaseFilter(mapID)

    if ZQG.Refresh then
        ZQG.Refresh()
    end

    C_Timer.After(0.05, UpdateZonePhaseBadge)
end

local phaseRefreshScheduled = false
local function SchedulePhaseRefresh(delay)
    if phaseRefreshScheduled then
        return
    end

    phaseRefreshScheduled = true
    C_Timer.After(delay or 0.15, function()
        phaseRefreshScheduled = false
        RefreshForPhaseChange()
    end)
end

local function ApplyPendingZidormiSwitch()
    if not pendingZidormiSwitch then
        return false
    end

    local mapID = CurrentMapID()
    local now = GetTime and GetTime() or 0

    if pendingZidormiSwitch.expires and now > pendingZidormiSwitch.expires then
        pendingZidormiSwitch = nil
        return false
    end

    if mapID ~= pendingZidormiSwitch.mapID then
        pendingZidormiSwitch = nil
        return false
    end

    sessionDetectedPhases[mapID] = pendingZidormiSwitch.targetPhase
    pendingZidormiSwitch = nil
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUESTLINE_UPDATE")
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("GOSSIP_CLOSED")

-- UNIT_PHASE has existed across many WoW clients, but keep its registration
-- optional so a future client change cannot prevent the addon from loading.
pcall(events.RegisterEvent, events, "UNIT_PHASE")

events:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
        DetectZidormiGossipPhase()
        SchedulePhaseRefresh(0.05)
        return
    end

    -- If the player had Zidormi open and WoW then reports a phase transition,
    -- treat that event as confirmation that the offered switch occurred. Merely
    -- closing the gossip window does not change our detected phase.
    if event == "UNIT_PHASE" then
        ApplyPendingZidormiSwitch()
    end

    -- Quest-log and quest-line changes can now establish a timeline directly
    -- when they include a curated phase-exclusive quest. Other events remain
    -- refresh hints for Zidormi, configured detectors, or manual overrides.
    SchedulePhaseRefresh(0.15)
end)

-- Keep the phase line in sync with normal manual/minimap refreshes.
local originalRefresh = ZQG.Refresh
if originalRefresh then
    ZQG.Refresh = function(...)
        local results = { originalRefresh(...) }
        C_Timer.After(0.05, UpdateZonePhaseBadge)
        return unpack(results)
    end
end

-- Extend the slash command chain. "auto" clears the per-zone override. Past
-- and present are provided as common historical-phase names, while registered
-- zones can use any additional phase key through the same command.
local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")
    local phaseArg = command:match("^phase%s+(.+)$")

    if command == "phase" then
        local mapID = CurrentMapID()
        local phaseKey, source = ZQG.GetTimePhaseKey(mapID)
        local shown = phaseKey and phaseKey:upper() or "UNKNOWN"
        local evidence = mapID and lastQuestPhaseEvidence[mapID] or nil
        local evidenceText = ""
        if source == "detected" and evidence then
            evidenceText = " using " .. (evidence.name or ("quest " .. tostring(evidence.questID)))
        end
        Print("Current timeline: " .. shown .. " (" .. source .. ")" .. evidenceText .. ". Use /zq phase auto, /zq phase past, or /zq phase present.")
        return
    elseif phaseArg then
        local mapID = CurrentMapID()
        if not mapID then
            Print("Current zone is unavailable.")
            return
        end

        local DB = GetDB()
        phaseArg = phaseArg:lower()

        if phaseArg == "auto" then
            DB.phaseOverrides[mapID] = nil
            Print("Time phase for this zone is now AUTO.")
        else
            DB.phaseOverrides[mapID] = phaseArg
            Print("Time phase for this zone is now " .. phaseArg:upper() .. " (manual).")
        end

        RefreshForPhaseChange()
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.RefreshForTimePhase = RefreshForPhaseChange
ZQG.GetTimePhaseEvidence = function(mapID)
    mapID = mapID or CurrentMapID()
    return mapID and lastQuestPhaseEvidence[mapID] or nil
end
