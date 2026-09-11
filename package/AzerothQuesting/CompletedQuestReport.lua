local ADDON_NAME, ZQG = ...

-- Personal, current-character completed-quest report.
--
-- This report intentionally stays separate from anonymous research telemetry.
-- It may include the current character name and realm so the player can tell
-- which toon produced the rows when pasting them into a private Google Sheet.
-- The data is shown only in the local copy/export window; this module does not
-- send it through Azeroth Questing Network, Wago, the Companion, or the server.

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
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
    if not Accessible(value) or type(value) ~= "string" or value == "" then
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

local function SafeField(value)
    value = tostring(value or "")
    value = value:gsub("[\t\r\n]", " ")
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

local function CharacterInfo()
    local character = "Current Character"
    local realm = "Unknown Realm"
    local faction = "Unknown"
    local className = "Unknown"
    local level = 0

    if UnitName then
        local ok, value = pcall(UnitName, "player")
        if ok then
            character = SafeString(value) or character
        end
    end

    if GetRealmName then
        local ok, value = pcall(GetRealmName)
        if ok then
            realm = SafeString(value) or realm
        end
    end

    if UnitFactionGroup then
        local ok, value = pcall(UnitFactionGroup, "player")
        if ok then
            faction = SafeString(value) or faction
        end
    end

    if UnitClass then
        local ok, value = pcall(UnitClass, "player")
        if ok then
            className = SafeString(value) or className
        end
    end

    if UnitLevel then
        local ok, value = pcall(UnitLevel, "player")
        if ok then
            level = SafeNumber(value) or level
        end
    end

    return {
        character = character,
        realm = realm,
        faction = faction,
        className = className,
        level = level,
    }
end

local function GetCompletedQuestIDs()
    if not C_QuestLog or not C_QuestLog.GetAllCompletedQuestIDs then
        return {}
    end

    local ok, values = pcall(C_QuestLog.GetAllCompletedQuestIDs)
    values = ok and SafeTable(values) or nil
    if not values then
        return {}
    end

    local ids = {}
    local seen = {}
    for _, rawQuestID in ipairs(values) do
        local questID = SafeNumber(rawQuestID)
        if questID and questID > 0 and not seen[questID] then
            seen[questID] = true
            ids[#ids + 1] = questID
        end
    end

    table.sort(ids)
    return ids
end

local function QuestTitle(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok then
            title = SafeString(title)
            if title then
                return title
            end
        end
    end

    if ZQG.GetQuestCatalogStore then
        local ok, store = pcall(ZQG.GetQuestCatalogStore)
        store = ok and SafeTable(store) or nil
        local records = store and SafeTable(store.records) or nil
        local record = records and SafeTable(records[questID]) or nil
        local title = record and SafeString(record.name) or nil
        if title then
            return title
        end
    end

    return nil
end

local function RefreshCatalogForTitles()
    if not ZQG.RefreshQuestCatalog then
        return
    end
    pcall(ZQG.RefreshQuestCatalog)
end

local function BuildCompletedQuestExport()
    -- The catalog owns the throttled title-request queue. Refreshing it here
    -- lets unresolved completed quest names continue filling in without this
    -- report firing thousands of direct load requests at once.
    RefreshCatalogForTitles()

    local info = CharacterInfo()
    local ids = GetCompletedQuestIDs()
    local missingTitles = 0
    local lines = {
        "Character\tRealm\tFaction\tClass\tLevel\tQuest ID\tQuest Name\tAddon Version",
    }

    for _, questID in ipairs(ids) do
        local title = QuestTitle(questID)
        if not title then
            missingTitles = missingTitles + 1
            title = "Quest " .. tostring(questID)
        end

        lines[#lines + 1] = table.concat({
            SafeField(info.character),
            SafeField(info.realm),
            SafeField(info.faction),
            SafeField(info.className),
            SafeField(info.level),
            SafeField(questID),
            SafeField(title),
            SafeField(AddonVersion()),
        }, "\t")
    end

    return table.concat(lines, "\n"), #ids, missingTitles, info
end

local exportFrame = CreateFrame("Frame", "AzerothQuestingCompletedQuestExportFrame", UIParent, "BackdropTemplate")
exportFrame:SetSize(780, 520)
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
exportTitle:SetText("Azeroth Questing - Completed Quests")

local exportNote = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportNote:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", 0, -6)
exportNote:SetWidth(720)
exportNote:SetJustifyH("LEFT")
exportNote:SetText("Current-character report for personal use. Tab-separated for Google Sheets. Character/realm data shown here is not sent through Azeroth Questing research, P2P, Wago, Companion sync, or the server.")

local exportClose = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
exportClose:SetPoint("TOPRIGHT", -3, -3)

local scroll = CreateFrame("ScrollFrame", "AzerothQuestingCompletedQuestExportScrollFrame", exportFrame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 18, -94)
scroll:SetPoint("BOTTOMRIGHT", -38, 18)

local exportBox = CreateFrame("EditBox", nil, scroll)
exportBox:SetMultiLine(true)
exportBox:SetAutoFocus(false)
exportBox:SetFontObject(ChatFontNormal)
exportBox:SetWidth(705)
exportBox:SetHeight(12000)
exportBox:SetTextInsets(4, 4, 4, 4)
exportBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
scroll:SetScrollChild(exportBox)

local function ShowCompletedExport()
    local text, count, missingTitles, info = BuildCompletedQuestExport()
    exportBox:SetText(text)
    exportBox:SetCursorPosition(0)
    exportFrame:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()

    local suffix = ""
    if missingTitles > 0 then
        suffix = string.format(" %d quest names are still loading; export again later to fill more names.", missingTitles)
    end

    Print(string.format(
        "%s-%s: %d completed quests selected for copy. Press Ctrl+C and paste into Google Sheets.%s",
        info.character,
        info.realm,
        count,
        suffix
    ))
end

local function ShowCompletedSummary()
    RefreshCatalogForTitles()
    local ids = GetCompletedQuestIDs()
    local info = CharacterInfo()
    Print(string.format(
        "%s-%s has %d completed quests reported by WoW. Use /aq completed export to copy the current character's completed quest list.",
        info.character,
        info.realm,
        #ids
    ))
end

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "completed" or command == "completed quests" or command == "toon completed" then
        ShowCompletedSummary()
        return
    elseif command == "completed export" or command == "completed quests export"
        or command == "toon completed export" then
        ShowCompletedExport()
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.GetCurrentCharacterCompletedQuestIDs = GetCompletedQuestIDs
ZQG.BuildCurrentCharacterCompletedQuestExport = BuildCompletedQuestExport
