local ADDON_NAME, ZQG = ...

local function GetStore()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    ZoneQuestGuideDB.mapQuestLearning = ZoneQuestGuideDB.mapQuestLearning or {
        version = 1,
        maps = {},
    }

    local store = ZoneQuestGuideDB.mapQuestLearning
    store.version = 1
    store.maps = store.maps or {}
    return store
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

local function MapName(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then
        return nil
    end

    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

local function PlayerFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player") or "Neutral"
    end
    return "Neutral"
end

local function IsOnTaxi()
    return UnitOnTaxi and UnitOnTaxi("player") and true or false
end

local function QuestName(questID, fallback)
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

local sessionEvidence = {}

local function EvidenceKey(mapID, faction, questID, evidence)
    return table.concat({
        tostring(mapID),
        tostring(faction),
        tostring(questID),
        tostring(evidence),
    }, ":")
end

local function EnsureQuestRecord(mapID, faction, questID, name)
    local store = GetStore()
    store.maps[mapID] = store.maps[mapID] or {
        name = MapName(mapID) or ("Map " .. tostring(mapID)),
        factions = {},
    }

    local mapData = store.maps[mapID]
    mapData.name = MapName(mapID) or mapData.name or ("Map " .. tostring(mapID))
    mapData.factions = mapData.factions or {}
    mapData.factions[faction] = mapData.factions[faction] or { quests = {} }

    local factionData = mapData.factions[faction]
    factionData.quests = factionData.quests or {}
    factionData.quests[questID] = factionData.quests[questID] or {
        name = QuestName(questID, name),
        completed = false,
        seen = 0,
        available = 0,
        offered = 0,
        accepted = 0,
        active = 0,
        turnedIn = 0,
    }

    local quest = factionData.quests[questID]
    quest.name = QuestName(questID, name or quest.name)
    if IsCompleted(questID) then
        quest.completed = true
    end

    return quest
end

local function RecordMapQuestEvidence(questID, name, evidence, mapID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    mapID = mapID or CurrentMapID()
    if type(mapID) ~= "number" or mapID <= 0 then
        return false
    end

    local faction = PlayerFaction()
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

    -- WagoTelemetry.lua is loaded after this module. By the time gameplay
    -- events fire its reporter is available and can forward only the strong,
    -- anonymous evidence types it accepts. Accepted/seen evidence remains local.
    if ZQG.ReportMapQuestEvidenceToWago then
        ZQG.ReportMapQuestEvidenceToWago(questID, evidence, mapID)
    end

    return true
end

local function ScanMapQuestEvidence()
    -- WoW can report parent/flyover maps while the player is on a flight path.
    -- Avoid teaching the local database that quests belong to maps merely crossed
    -- in transit; strong NPC/turn-in evidence can still be recorded after landing.
    if IsOnTaxi() then
        return
    end

    local mapID = CurrentMapID()
    if not mapID then
        return
    end

    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info and info.questID then
                    RecordMapQuestEvidence(info.questID, nil, "accepted", mapID)
                end
            end
        end
    end

    if C_QuestLine and C_QuestLine.GetAvailableQuestLines then
        local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
        if ok and type(lines) == "table" then
            for _, info in ipairs(lines) do
                if info and info.questID then
                    RecordMapQuestEvidence(
                        info.questID,
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
    if not mapID or not C_GossipInfo then
        return
    end

    if C_GossipInfo.GetAvailableQuests then
        local ok, quests = pcall(C_GossipInfo.GetAvailableQuests)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info and info.questID then
                    RecordMapQuestEvidence(info.questID, info.title, "offered", mapID)
                end
            end
        end
    end

    if C_GossipInfo.GetActiveQuests then
        local ok, quests = pcall(C_GossipInfo.GetActiveQuests)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info and info.questID then
                    RecordMapQuestEvidence(info.questID, info.title, "active", mapID)
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
        RecordMapQuestEvidence(questID, title, "offered")
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

local function BuildMapQuestExport()
    local store = GetStore()
    local lines = {
        "ZQGMAPQUESTDATA|2",
        "# mapID\tmapName\tfaction\tquestID\tname\tcompleted\tseen\tavailable\toffered\taccepted\tactive\tturnedIn",
    }

    for _, mapID in ipairs(SortedKeys(store.maps, true)) do
        local mapData = store.maps[mapID]
        for _, faction in ipairs(SortedKeys(mapData.factions or {})) do
            local factionData = mapData.factions[faction]
            for _, questID in ipairs(SortedKeys(factionData.quests or {}, true)) do
                local quest = factionData.quests[questID]
                lines[#lines + 1] = table.concat({
                    SafeField(mapID),
                    SafeField(mapData.name),
                    SafeField(faction),
                    SafeField(questID),
                    SafeField(quest.name),
                    quest.completed and "1" or "0",
                    tostring(quest.seen or 0),
                    tostring(quest.available or 0),
                    tostring(quest.offered or 0),
                    tostring(quest.accepted or 0),
                    tostring(quest.active or 0),
                    tostring(quest.turnedIn or 0),
                }, "\t")
            end
        end
    end

    return table.concat(lines, "\n")
end

local function BuildCombinedExport()
    local phaseText = ZQG.BuildPhaseLearningExport and ZQG.BuildPhaseLearningExport() or nil
    local mapText = BuildMapQuestExport()

    if phaseText and phaseText ~= "" then
        return phaseText .. "\n\n" .. mapText
    end

    return mapText
end

local exportFrame = CreateFrame("Frame", "ZoneQuestGuideMapQuestExportFrame", UIParent, "BackdropTemplate")
exportFrame:SetSize(680, 450)
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
exportTitle:SetText("Azeroth Questing - Learning Export")

local exportNote = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportNote:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", 0, -6)
exportNote:SetWidth(630)
exportNote:SetJustifyH("LEFT")
exportNote:SetText("Includes tab-separated phase evidence plus map ID + quest associations. No character name, realm, GUID, guild, or account identifier is included.")

local exportClose = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
exportClose:SetPoint("TOPRIGHT", -3, -3)

local scroll = CreateFrame("ScrollFrame", "ZoneQuestGuideMapQuestExportScrollFrame", exportFrame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 18, -76)
scroll:SetPoint("BOTTOMRIGHT", -38, 18)

local exportBox = CreateFrame("EditBox", nil, scroll)
exportBox:SetMultiLine(true)
exportBox:SetAutoFocus(false)
exportBox:SetFontObject(ChatFontNormal)
exportBox:SetWidth(605)
exportBox:SetTextInsets(4, 4, 4, 4)
exportBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
scroll:SetScrollChild(exportBox)

local function ShowExport(mapOnly)
    local text = mapOnly and BuildMapQuestExport() or BuildCombinedExport()
    exportBox:SetText(text)
    exportBox:SetCursorPosition(0)
    exportFrame:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

local function MapSummary()
    local mapID = CurrentMapID()
    if not mapID then
        Print("Current map is unavailable.")
        return
    end

    local faction = PlayerFaction()
    local store = GetStore()
    local mapData = store.maps[mapID]
    local factionData = mapData and mapData.factions and mapData.factions[faction] or nil
    local total = 0

    if factionData and factionData.quests then
        for _ in pairs(factionData.quests) do
            total = total + 1
        end
    end

    Print(string.format(
        "Map learning: %d / %s - %d recorded %s quest%s.",
        mapID,
        MapName(mapID) or (mapData and mapData.name) or "Unknown",
        total,
        faction,
        total == 1 and "" or "s"
    ))
end

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
            RecordMapQuestEvidence(questID, nil, "accepted")
        end
        ScheduleScan(0.2)
        return
    end

    if event == "QUEST_TURNED_IN" then
        if type(arg1) == "number" and arg1 > 0 then
            RecordMapQuestEvidence(arg1, nil, "turnedIn")
        end
        ScheduleScan(0.2)
        return
    end

    if event == "QUEST_DETAIL" then
        C_Timer.After(0.05, CaptureQuestDetail)
        return
    end

    if event == "GOSSIP_SHOW" then
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

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "maps" or command == "maplearn" or command == "maplearning" then
        MapSummary()
        return
    elseif command == "mapexport" or command == "maps export" then
        ShowExport(true)
        return
    elseif command == "export" or command == "learn export" or command == "learning export" then
        ShowExport(false)
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.RecordMapQuestEvidence = RecordMapQuestEvidence
ZQG.BuildMapQuestExport = BuildMapQuestExport
ZQG.BuildLearningExport = BuildCombinedExport
