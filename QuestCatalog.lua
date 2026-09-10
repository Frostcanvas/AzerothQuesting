local ADDON_NAME, ZQG = ...

-- Broad quest catalog for research/export.
--
-- WoW does not expose one API that enumerates every quest shipped in the game.
-- This catalog therefore merges every quest the client can actually expose for
-- the current account/character with Azeroth Questing's own learned/static data:
-- completed quests, active quest-log entries, map/gossip learning records, and
-- supplemental quest records. The result is intentionally described as a
-- game-exposed catalog rather than a complete Blizzard master quest database.

local CATALOG_VERSION = 1
local TITLE_REQUEST_INTERVAL = 0.10
local MAX_TITLE_REQUESTS_PER_SESSION = 5000

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
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

local function Accessible(value)
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, value)
        if ok then
            return allowed and true or false
        end
    end
    return value ~= nil
end

local function SafeString(value)
    if not Accessible(value) or type(value) ~= "string" then
        return nil
    end
    if value == "" then
        return nil
    end
    return value
end

local function SafeNumber(value)
    if not Accessible(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

local function SafeTable(value)
    if type(value) ~= "table" then
        return nil
    end
    if canaccesstable then
        local ok, allowed = pcall(canaccesstable, value)
        if ok and not allowed then
            return nil
        end
    end
    return value
end

local function AddonVersion()
    local version
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
        if ok then
            version = SafeString(value)
        end
    elseif GetAddOnMetadata then
        local ok, value = pcall(GetAddOnMetadata, ADDON_NAME, "Version")
        if ok then
            version = SafeString(value)
        end
    end
    return version or "unknown"
end

local function GetStore()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    ZoneQuestGuideDB.questCatalog = ZoneQuestGuideDB.questCatalog or {
        version = CATALOG_VERSION,
        records = {},
        lastScanAt = 0,
    }

    local store = ZoneQuestGuideDB.questCatalog
    store.version = CATALOG_VERSION
    store.records = store.records or {}
    store.lastScanAt = tonumber(store.lastScanAt) or 0
    return store
end

local function EnsureRecord(questID)
    questID = SafeNumber(questID)
    if not questID or questID <= 0 then
        return nil
    end

    local store = GetStore()
    local record = store.records[questID]
    local now = CurrentTime()
    if not record then
        record = {
            questID = questID,
            completed = false,
            active = false,
            sources = {},
            maps = {},
            factions = {},
            firstSeen = now,
            lastSeen = now,
        }
        store.records[questID] = record
    end

    record.questID = questID
    record.sources = record.sources or {}
    record.maps = record.maps or {}
    record.factions = record.factions or {}
    record.firstSeen = tonumber(record.firstSeen) or now
    record.lastSeen = now
    return record
end

local function RememberQuest(questID, source, details)
    local record = EnsureRecord(questID)
    if not record then
        return nil
    end

    details = details or {}
    if source and source ~= "" then
        record.sources[source] = true
    end

    local name = SafeString(details.name)
    if name then
        record.name = name
    end

    if details.completed ~= nil then
        record.completed = details.completed and true or false
    end
    if details.active ~= nil then
        record.active = details.active and true or false
    end

    local mapID = SafeNumber(details.mapID)
    if mapID and mapID > 0 then
        record.maps[mapID] = true
    end

    local faction = SafeString(details.faction)
    if faction == "Alliance" or faction == "Horde" or faction == "Neutral" then
        record.factions[faction] = true
    end

    return record
end

local function CachedQuestTitle(questID)
    if not C_QuestLog or not C_QuestLog.GetTitleForQuestID then
        return nil
    end

    local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
    if not ok then
        return nil
    end
    return SafeString(title)
end

local function RefreshCachedTitle(record)
    if not record or SafeString(record.name) then
        return
    end
    local title = CachedQuestTitle(record.questID)
    if title then
        record.name = title
    end
end

local titleQueue = {}
local titleQueued = {}
local titleQueueHead = 1
local titleRequestsThisSession = 0
local titleTicker

local function StopTitleTickerIfDone()
    if titleQueueHead <= #titleQueue then
        return
    end
    if titleTicker then
        titleTicker:Cancel()
        titleTicker = nil
    end
    titleQueue = {}
    titleQueued = {}
    titleQueueHead = 1
end

local function QueueTitle(questID)
    if not C_QuestLog or not C_QuestLog.RequestLoadQuestByID then
        return
    end
    if titleRequestsThisSession >= MAX_TITLE_REQUESTS_PER_SESSION then
        return
    end
    if titleQueued[questID] then
        return
    end

    local record = GetStore().records[questID]
    if not record or SafeString(record.name) then
        return
    end

    titleQueued[questID] = true
    titleQueue[#titleQueue + 1] = questID

    if not titleTicker and C_Timer and C_Timer.NewTicker then
        titleTicker = C_Timer.NewTicker(TITLE_REQUEST_INTERVAL, function()
            local nextQuestID = titleQueue[titleQueueHead]
            if not nextQuestID then
                StopTitleTickerIfDone()
                return
            end

            titleQueueHead = titleQueueHead + 1
            titleRequestsThisSession = titleRequestsThisSession + 1
            pcall(C_QuestLog.RequestLoadQuestByID, nextQuestID)
            StopTitleTickerIfDone()
        end)
    end
end

local function QueueMissingTitles()
    local store = GetStore()
    local queued = 0
    for questID, record in pairs(store.records) do
        RefreshCachedTitle(record)
        if not SafeString(record.name) and not titleQueued[questID]
            and titleRequestsThisSession + queued < MAX_TITLE_REQUESTS_PER_SESSION then
            QueueTitle(questID)
            queued = queued + 1
        end
    end
    return queued
end

local function ScanCompleted()
    if not C_QuestLog or not C_QuestLog.GetAllCompletedQuestIDs then
        return 0
    end

    local ok, questIDs = pcall(C_QuestLog.GetAllCompletedQuestIDs)
    questIDs = ok and SafeTable(questIDs) or nil
    if not questIDs then
        return 0
    end

    local count = 0
    for _, rawQuestID in ipairs(questIDs) do
        local questID = SafeNumber(rawQuestID)
        if questID and questID > 0 then
            local record = RememberQuest(questID, "completed", { completed = true })
            if record then
                RefreshCachedTitle(record)
                count = count + 1
            end
        end
    end
    return count
end

local function ScanActive()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        return 0
    end

    local store = GetStore()
    for _, record in pairs(store.records) do
        record.active = false
    end

    local ok, numEntries = pcall(C_QuestLog.GetNumQuestLogEntries)
    if not ok or type(numEntries) ~= "number" then
        return 0
    end

    local count = 0
    for index = 1, numEntries do
        local infoOK, info = pcall(C_QuestLog.GetInfo, index)
        info = infoOK and SafeTable(info) or nil
        if info then
            local questID = SafeNumber(info.questID)
            local headerValue = info.isHeader
            local isHeader = Accessible(headerValue) and headerValue and true or false
            if questID and questID > 0 and not isHeader then
                local completed = false
                if C_QuestLog.IsQuestFlaggedCompleted then
                    local completedOK, value = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
                    completed = completedOK and Accessible(value) and value and true or false
                end
                RememberQuest(questID, "active", {
                    name = SafeString(info.title),
                    completed = completed,
                    active = true,
                })
                count = count + 1
            end
        end
    end
    return count
end

local function ScanLearned()
    local learned = ZoneQuestGuideDB and ZoneQuestGuideDB.mapQuestLearning
    local maps = learned and SafeTable(learned.maps) or nil
    if not maps then
        return 0
    end

    local count = 0
    for rawMapID, mapData in pairs(maps) do
        local mapID = tonumber(rawMapID)
        mapData = SafeTable(mapData)
        local factions = mapData and SafeTable(mapData.factions) or nil
        if mapID and mapID > 0 and factions then
            for faction, factionData in pairs(factions) do
                factionData = SafeTable(factionData)
                local quests = factionData and SafeTable(factionData.quests) or nil
                if quests then
                    for rawQuestID, quest in pairs(quests) do
                        local questID = tonumber(rawQuestID)
                        quest = SafeTable(quest)
                        if questID and questID > 0 and quest then
                            RememberQuest(questID, "learned", {
                                name = SafeString(quest.name),
                                completed = quest.completed and true or nil,
                                mapID = mapID,
                                faction = SafeString(faction),
                            })
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return count
end

local function ScanStatic()
    local staticQuests = SafeTable(ZQG.StaticQuests)
    if not staticQuests then
        return 0
    end

    local count = 0
    for rawMapID, list in pairs(staticQuests) do
        local mapID = tonumber(rawMapID)
        list = SafeTable(list)
        if mapID and mapID > 0 and list then
            for _, quest in ipairs(list) do
                quest = SafeTable(quest)
                if quest then
                    local questID = SafeNumber(quest.id)
                    if questID and questID > 0 then
                        RememberQuest(questID, "supplemental", {
                            name = SafeString(quest.name),
                            mapID = mapID,
                            faction = SafeString(quest.faction),
                        })
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

local function ScanCatalog(includeCompleted)
    local completed = includeCompleted and ScanCompleted() or 0
    local active = ScanActive()
    local learned = ScanLearned()
    local supplemental = ScanStatic()
    local queued = QueueMissingTitles()

    local store = GetStore()
    store.lastScanAt = CurrentTime()

    local unique = 0
    local named = 0
    for _, record in pairs(store.records) do
        unique = unique + 1
        if SafeString(record.name) then
            named = named + 1
        end
    end

    return {
        unique = unique,
        named = named,
        completed = completed,
        active = active,
        learned = learned,
        supplemental = supplemental,
        queuedTitles = queued,
    }
end

local function SortedKeys(tbl, numeric)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if numeric then
            return (tonumber(a) or 0) < (tonumber(b) or 0)
        end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function JoinKeys(tbl, numeric)
    local values = {}
    for _, key in ipairs(SortedKeys(tbl, numeric)) do
        values[#values + 1] = tostring(key)
    end
    return table.concat(values, ",")
end

local function SafeField(value)
    value = tostring(value or "")
    value = value:gsub("[\t\r\n]", " ")
    return value
end

local function BuildQuestCatalogExport()
    ScanCatalog(true)

    local lines = {
        "Quest ID\tQuest Name\tCompleted\tActive\tSources\tMap IDs\tFactions\tFirst Seen\tLast Seen\tAddon Version",
    }
    local store = GetStore()
    for _, questID in ipairs(SortedKeys(store.records, true)) do
        local record = store.records[questID]
        RefreshCachedTitle(record)
        lines[#lines + 1] = table.concat({
            SafeField(questID),
            SafeField(record.name or ("Quest " .. tostring(questID))),
            record.completed and "Yes" or "No",
            record.active and "Yes" or "No",
            SafeField(JoinKeys(record.sources)),
            SafeField(JoinKeys(record.maps, true)),
            SafeField(JoinKeys(record.factions)),
            SafeField(record.firstSeen),
            SafeField(record.lastSeen),
            SafeField(AddonVersion()),
        }, "\t")
    end
    return table.concat(lines, "\n")
end

local exportFrame = CreateFrame("Frame", "AzerothQuestingQuestCatalogExportFrame", UIParent, "BackdropTemplate")
exportFrame:SetSize(760, 500)
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
exportTitle:SetText("Azeroth Questing - Quest Catalog")

local exportNote = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportNote:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", 0, -6)
exportNote:SetWidth(705)
exportNote:SetJustifyH("LEFT")
exportNote:SetText("Tab-separated for Google Sheets. Includes quests this WoW client/account exposes plus Azeroth Questing learned/supplemental records; it is not a complete list of every quest shipped in WoW.")

local exportClose = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
exportClose:SetPoint("TOPRIGHT", -3, -3)

local scroll = CreateFrame("ScrollFrame", "AzerothQuestingQuestCatalogExportScrollFrame", exportFrame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 18, -82)
scroll:SetPoint("BOTTOMRIGHT", -38, 18)

local exportBox = CreateFrame("EditBox", nil, scroll)
exportBox:SetMultiLine(true)
exportBox:SetAutoFocus(false)
exportBox:SetFontObject(ChatFontNormal)
exportBox:SetWidth(685)
exportBox:SetTextInsets(4, 4, 4, 4)
exportBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
scroll:SetScrollChild(exportBox)

local function ShowCatalogExport()
    local text = BuildQuestCatalogExport()
    exportBox:SetText(text)
    exportBox:SetCursorPosition(0)
    exportFrame:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
    Print("Quest catalog export is selected. Press Ctrl+C, then paste into Google Sheets cell A1.")
end

local function CatalogSummary(scanFirst)
    local result = scanFirst and ScanCatalog(true) or nil
    local store = GetStore()
    local unique = 0
    local named = 0
    for _, record in pairs(store.records) do
        unique = unique + 1
        if SafeString(record.name) then
            named = named + 1
        end
    end

    if result then
        Print(string.format(
            "Quest catalog refreshed: %d unique quests (%d named). Completed API rows %d; active %d; learned %d; supplemental %d; title requests queued %d.",
            unique,
            named,
            result.completed,
            result.active,
            result.learned,
            result.supplemental,
            result.queuedTitles
        ))
    else
        Print(string.format(
            "Quest catalog: %d unique quests (%d named). Use /aq catalog scan to refresh or /aq catalog export to copy it into Google Sheets.",
            unique,
            named
        ))
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")

local activeScanScheduled = false
local lastCompletedScan = 0
local function ScheduleScan(includeCompleted, delay)
    if includeCompleted then
        local now = CurrentTime()
        if now > 0 and now - lastCompletedScan < 5 then
            includeCompleted = false
        else
            lastCompletedScan = now
        end
    end

    if activeScanScheduled and not includeCompleted then
        return
    end
    activeScanScheduled = true
    C_Timer.After(delay or 0.5, function()
        activeScanScheduled = false
        ScanCatalog(includeCompleted)
    end)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        ScheduleScan(true, 3)
    elseif event == "QUEST_TURNED_IN" then
        ScheduleScan(true, 0.5)
    elseif event == "QUEST_ACCEPTED" or event == "QUEST_LOG_UPDATE" then
        ScheduleScan(false, 0.5)
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        local questID = SafeNumber(arg1)
        local success = Accessible(arg2) and arg2 and true or false
        if questID and success then
            local record = GetStore().records[questID]
            if record then
                local title = CachedQuestTitle(questID)
                if title then
                    record.name = title
                    record.lastSeen = CurrentTime()
                end
            end
        end
    end
end)

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "catalog" or command == "quest catalog" or command == "quests catalog" then
        CatalogSummary(false)
        return
    elseif command == "catalog scan" or command == "quest catalog scan" or command == "quests scan" then
        CatalogSummary(true)
        return
    elseif command == "catalog export" or command == "quest catalog export" or command == "quests export" then
        ShowCatalogExport()
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.GetQuestCatalogStore = GetStore
ZQG.RefreshQuestCatalog = function() return ScanCatalog(true) end
ZQG.BuildQuestCatalogExport = BuildQuestCatalogExport
