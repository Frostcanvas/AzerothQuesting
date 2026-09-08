local ADDON_NAME, ZQG = ...

local function GetDB()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    ZoneQuestGuideDB.phaseLearning = ZoneQuestGuideDB.phaseLearning or {
        version = 1,
        zones = {},
    }
    ZoneQuestGuideDB.phaseLearning.version = 1
    ZoneQuestGuideDB.phaseLearning.zones = ZoneQuestGuideDB.phaseLearning.zones or {}
    return ZoneQuestGuideDB
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function PlayerFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player") or "Neutral"
    end
    return "Neutral"
end

local function GetQuestName(questID, fallback)
    if fallback and fallback ~= "" then
        return fallback
    end

    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and title and title ~= "" then
            return title
        end
    end

    return "Quest " .. tostring(questID)
end

local function IsCompleted(questID)
    if not questID or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
        return false
    end

    local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and completed and true or false
end

local function GetKnownPhase(mapID)
    if not mapID or not ZQG.GetTimePhaseKey then
        return nil, nil
    end

    local phase, source = ZQG.GetTimePhaseKey(mapID)
    if not phase then
        return nil, source
    end

    source = source or "unknown"
    if source ~= "zidormi" and source ~= "manual" and source ~= "detected" then
        return nil, source
    end

    return tostring(phase):lower(), source
end

local sessionEvidence = {}

local function EvidenceKey(mapID, faction, phase, questID, evidence)
    return table.concat({
        tostring(mapID),
        tostring(faction),
        tostring(phase),
        tostring(questID),
        tostring(evidence),
    }, ":")
end

local function EnsureQuestRecord(mapID, faction, questID, name)
    local learning = GetDB().phaseLearning

    learning.zones[mapID] = learning.zones[mapID] or { factions = {} }
    local zone = learning.zones[mapID]
    zone.factions = zone.factions or {}
    zone.factions[faction] = zone.factions[faction] or { quests = {} }

    local factionData = zone.factions[faction]
    factionData.quests = factionData.quests or {}
    factionData.quests[questID] = factionData.quests[questID] or {
        name = GetQuestName(questID, name),
        completed = false,
        phases = {},
    }

    local quest = factionData.quests[questID]
    quest.name = GetQuestName(questID, name or quest.name)
    quest.phases = quest.phases or {}
    if IsCompleted(questID) then
        quest.completed = true
    end

    return quest
end

local function RecordQuestEvidence(questID, name, evidence, mapID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    mapID = mapID or CurrentMapID()
    local phase, phaseSource = GetKnownPhase(mapID)
    if not mapID or not phase then
        return false
    end

    local faction = PlayerFaction()
    local quest = EnsureQuestRecord(mapID, faction, questID, name)
    quest.phases[phase] = quest.phases[phase] or {
        seen = 0,
        available = 0,
        offered = 0,
        accepted = 0,
        active = 0,
        turnedIn = 0,
        sourceCounts = {},
    }

    local phaseData = quest.phases[phase]
    phaseData.sourceCounts = phaseData.sourceCounts or {}

    local seenKey = EvidenceKey(mapID, faction, phase, questID, "seen")
    if not sessionEvidence[seenKey] then
        sessionEvidence[seenKey] = true
        phaseData.seen = (phaseData.seen or 0) + 1
        phaseData.sourceCounts[phaseSource] = (phaseData.sourceCounts[phaseSource] or 0) + 1
    end

    evidence = evidence or "seen"
    if evidence ~= "seen" then
        local evidenceKey = EvidenceKey(mapID, faction, phase, questID, evidence)
        if not sessionEvidence[evidenceKey] then
            sessionEvidence[evidenceKey] = true
            phaseData[evidence] = (phaseData[evidence] or 0) + 1
        end
    end

    return true
end

local function ScanMapQuestEvidence()
    local mapID = CurrentMapID()
    local phase = GetKnownPhase(mapID)
    if not mapID or not phase then
        return
    end

    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                local questID = info and info.questID
                if questID then
                    RecordQuestEvidence(questID, nil, "accepted", mapID)
                end
            end
        end
    end

    if C_QuestLine and C_QuestLine.GetAvailableQuestLines then
        local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
        if ok and type(lines) == "table" then
            for _, info in ipairs(lines) do
                local questID = info and info.questID
                if questID then
                    RecordQuestEvidence(
                        questID,
                        info.questName or info.questLineName,
                        "available",
                        mapID
                    )
                end
            end
        end
    end
end

local function ScanGossipEvidence()
    local mapID = CurrentMapID()
    local phase = GetKnownPhase(mapID)
    if not mapID or not phase or not C_GossipInfo then
        return
    end

    if C_GossipInfo.GetAvailableQuests then
        local ok, quests = pcall(C_GossipInfo.GetAvailableQuests)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info and info.questID then
                    RecordQuestEvidence(info.questID, info.title, "offered", mapID)
                end
            end
        end
    end

    if C_GossipInfo.GetActiveQuests then
        local ok, quests = pcall(C_GossipInfo.GetActiveQuests)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info and info.questID then
                    RecordQuestEvidence(info.questID, info.title, "active", mapID)
                end
            end
        end
    end
end

local function CaptureQuestDetail()
    if not GetQuestID then
        return
    end

    local questID = GetQuestID()
    if questID and questID > 0 then
        local title = GetTitleText and GetTitleText() or nil
        RecordQuestEvidence(questID, title, "offered")
    end
end

local scanScheduled = false
local function ScheduleScan(delay)
    if scanScheduled then
        return
    end

    scanScheduled = true
    C_Timer.After(delay or 0.2, function()
        scanScheduled = false
        ScanMapQuestEvidence()
    end)
end

-- ---------------------------------------------------------------------------
-- Export window
-- ---------------------------------------------------------------------------

local exportFrame = CreateFrame("Frame", "ZoneQuestGuidePhaseExportFrame", UIParent, "BackdropTemplate")
exportFrame:SetSize(650, 430)
exportFrame:SetPoint("CENTER")
exportFrame:SetFrameStrata("DIALOG")
exportFrame:SetClampedToScreen(true)
exportFrame:EnableMouse(true)
exportFrame:SetMovable(true)
exportFrame:RegisterForDrag("LeftButton")
exportFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
exportFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
exportFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
exportFrame:Hide()

local exportTitle = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
exportTitle:SetPoint("TOPLEFT", 16, -14)
exportTitle:SetText("Azeroth Questing - Phase Learning Export")

local exportNote = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportNote:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", 0, -6)
exportNote:SetWidth(600)
exportNote:SetJustifyH("LEFT")
exportNote:SetText("Copy this tab-separated text and send it with a bug report or phase-data contribution. It contains zone IDs, faction, quest IDs/names, phase, and observation counts - no character name, realm, or GUID.")

local exportClose = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
exportClose:SetPoint("TOPRIGHT", -3, -3)

local scroll = CreateFrame("ScrollFrame", "ZoneQuestGuidePhaseExportScrollFrame", exportFrame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 18, -76)
scroll:SetPoint("BOTTOMRIGHT", -38, 18)

local exportBox = CreateFrame("EditBox", nil, scroll)
exportBox:SetMultiLine(true)
exportBox:SetAutoFocus(false)
exportBox:SetFontObject(ChatFontNormal)
exportBox:SetWidth(575)
exportBox:SetTextInsets(4, 4, 4, 4)
exportBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
scroll:SetScrollChild(exportBox)

local function SortedKeys(tbl, numeric)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if numeric then
            return tonumber(a) < tonumber(b)
        end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function SafeField(value)
    value = tostring(value or "")
    value = value:gsub("[|\t\r\n]", " ")
    return value
end

local function BuildExportText()
    local learning = GetDB().phaseLearning
    local lines = {
        "ZQGPHASEDATA|2",
        "# mapID\tfaction\tphase\tquestID\tname\tcompleted\tseen\tavailable\toffered\taccepted\tactive\tturnedIn\tphaseSources",
    }

    for _, mapID in ipairs(SortedKeys(learning.zones, true)) do
        local zone = learning.zones[mapID]
        for _, faction in ipairs(SortedKeys(zone.factions or {})) do
            local factionData = zone.factions[faction]
            for _, questID in ipairs(SortedKeys(factionData.quests or {}, true)) do
                local quest = factionData.quests[questID]
                for _, phase in ipairs(SortedKeys(quest.phases or {})) do
                    local phaseData = quest.phases[phase]
                    local sources = {}
                    for _, source in ipairs(SortedKeys(phaseData.sourceCounts or {})) do
                        sources[#sources + 1] = source .. ":" .. tostring(phaseData.sourceCounts[source] or 0)
                    end

                    lines[#lines + 1] = table.concat({
                        SafeField(mapID),
                        SafeField(faction),
                        SafeField(phase),
                        SafeField(questID),
                        SafeField(quest.name),
                        quest.completed and "1" or "0",
                        tostring(phaseData.seen or 0),
                        tostring(phaseData.available or 0),
                        tostring(phaseData.offered or 0),
                        tostring(phaseData.accepted or 0),
                        tostring(phaseData.active or 0),
                        tostring(phaseData.turnedIn or 0),
                        SafeField(table.concat(sources, ",")),
                    }, "\t")
                end
            end
        end
    end

    return table.concat(lines, "\n")
end

local function ShowExport()
    local text = BuildExportText()
    exportBox:SetText(text)
    exportBox:SetCursorPosition(0)
    exportFrame:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

local function LearningSummary()
    local mapID = CurrentMapID()
    local phase, source = GetKnownPhase(mapID)
    local learning = GetDB().phaseLearning
    local faction = PlayerFaction()

    if not mapID then
        Print("Current map is unavailable.")
        return
    end

    local zone = learning.zones[mapID]
    local factionData = zone and zone.factions and zone.factions[faction] or nil
    local total = 0
    if factionData and factionData.quests then
        for _ in pairs(factionData.quests) do
            total = total + 1
        end
    end

    if phase then
        Print(string.format(
            "Phase learning: %s (%s), %d recorded %s quest%s in this map.",
            phase:upper(),
            source or "unknown",
            total,
            faction,
            total == 1 and "" or "s"
        ))
    else
        Print(string.format(
            "Phase learning is waiting for a reliable timeline signal in this map. %d recorded %s quest%s are stored here already.",
            total,
            faction,
            total == 1 and "" or "s"
        ))
    end
end

-- ---------------------------------------------------------------------------
-- Event capture
-- ---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUESTLINE_UPDATE")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("GOSSIP_SHOW")
pcall(events.RegisterEvent, events, "UNIT_PHASE")

events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "QUEST_ACCEPTED" then
        local questID = arg2
        if type(questID) ~= "number" or questID <= 0 then
            if type(arg1) == "number" and C_QuestLog and C_QuestLog.GetInfo then
                local info = C_QuestLog.GetInfo(arg1)
                questID = info and info.questID or nil
            end
        end
        if questID then
            RecordQuestEvidence(questID, nil, "accepted")
        end
        ScheduleScan(0.2)
        return
    end

    if event == "QUEST_TURNED_IN" then
        if type(arg1) == "number" and arg1 > 0 then
            RecordQuestEvidence(arg1, nil, "turnedIn")
        end
        ScheduleScan(0.2)
        return
    end

    if event == "QUEST_DETAIL" then
        C_Timer.After(0.05, CaptureQuestDetail)
        return
    end

    if event == "GOSSIP_SHOW" then
        -- TimePhases.lua also listens for GOSSIP_SHOW. Wait briefly so Zidormi
        -- detection can establish the current phase before recording NPC quests.
        C_Timer.After(0.10, function()
            ScanGossipEvidence()
            ScanMapQuestEvidence()
        end)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        ScheduleScan(1.0)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "UNIT_PHASE" then
        ScheduleScan(0.5)
    else
        ScheduleScan(0.2)
    end
end)

-- Extend the slash-command chain without replacing existing commands.
local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "learn" or command == "learning" then
        LearningSummary()
        return
    elseif command == "export" or command == "learn export" or command == "learning export" then
        ShowExport()
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.RecordPhaseQuestEvidence = RecordQuestEvidence
ZQG.BuildPhaseLearningExport = BuildExportText
