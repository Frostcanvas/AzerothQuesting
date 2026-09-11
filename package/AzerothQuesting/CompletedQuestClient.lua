local ADDON_NAME, ZQG = ...

-- Private per-character handoff for Azeroth Questing Companion.
--
-- WoW addons cannot write arbitrary files or talk directly to a Windows process.
-- The addon therefore prepares a compact per-character SavedVariables snapshot.
-- WoW writes it during the normal SavedVariables save on /reload or logout, and
-- Companion 0.1.9-beta.6+ reads that per-character file locally.
--
-- Character name and realm are intentionally NOT included in the wire payload.
-- The Companion derives those values locally from WoW's per-character folder.
-- This handoff is separate from account-wide AQO1 research observations and is
-- not sent through Azeroth Questing Network, Wago Analytics, or server sync.

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(message))
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

local function AddonVersion()
    local value
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, result = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
        if ok then
            value = SafeString(result)
        end
    elseif GetAddOnMetadata then
        local ok, result = pcall(GetAddOnMetadata, ADDON_NAME, "Version")
        if ok then
            value = SafeString(result)
        end
    end

    value = value or "unknown"
    value = value:gsub("[^A-Za-z0-9._%-]", "")
    return value ~= "" and value or "unknown"
end

local function CurrentUnixTime()
    if GetServerTime then
        local ok, value = pcall(GetServerTime)
        if ok then
            value = SafeNumber(value)
            if value and value > 0 then
                return math.floor(value)
            end
        end
    end

    if time then
        local ok, value = pcall(time)
        if ok then
            value = SafeNumber(value)
            if value and value > 0 then
                return math.floor(value)
            end
        end
    end

    return 0
end

local function GetCompletedQuestIDs()
    if ZQG.GetCurrentCharacterCompletedQuestIDs then
        local ok, values = pcall(ZQG.GetCurrentCharacterCompletedQuestIDs)
        values = ok and SafeTable(values) or nil
        if values then
            return values
        end
    end

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
        local ok, value = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok then
            value = SafeString(value)
            if value then
                return value
            end
        end
    end

    if ZQG.GetQuestCatalogStore then
        local ok, store = pcall(ZQG.GetQuestCatalogStore)
        store = ok and SafeTable(store) or nil
        local records = store and SafeTable(store.records) or nil
        local record = records and SafeTable(records[questID]) or nil
        local value = record and SafeString(record.name) or nil
        if value then
            return value
        end
    end

    return nil
end

local function HexEncode(value)
    value = SafeString(value)
    if not value then
        return ""
    end

    local encoded = {}
    for index = 1, #value do
        encoded[#encoded + 1] = string.format("%02X", string.byte(value, index))
    end
    return table.concat(encoded)
end

local function CharacterMetadata()
    local faction = "Unknown"
    local classFile = "UNKNOWN"
    local level = 0

    if UnitFactionGroup then
        local ok, value = pcall(UnitFactionGroup, "player")
        if ok then
            value = SafeString(value)
            if value == "Alliance" or value == "Horde" or value == "Neutral" then
                faction = value
            end
        end
    end

    if UnitClass then
        local ok, _, value = pcall(UnitClass, "player")
        if ok then
            value = SafeString(value)
            if value and value:match("^[A-Z]+$") then
                classFile = value
            end
        end
    end

    if UnitLevel then
        local ok, value = pcall(UnitLevel, "player")
        if ok then
            level = SafeNumber(value) or level
        end
    end

    return faction, classFile, math.floor(level or 0)
end

local function BuildWire()
    if ZQG.RefreshQuestCatalog then
        -- Reuse the catalog's throttled title loader so missing quest names can
        -- fill in over time without issuing thousands of requests at once.
        pcall(ZQG.RefreshQuestCatalog)
    end

    local ids = GetCompletedQuestIDs()
    local faction, classFile, level = CharacterMetadata()
    local capturedAt = CurrentUnixTime()
    local entries = {}

    for _, questID in ipairs(ids) do
        entries[#entries + 1] = tostring(questID) .. "~" .. HexEncode(QuestTitle(questID))
    end

    local wire = table.concat({
        "AQC1",
        "1",
        faction,
        classFile,
        tostring(level),
        tostring(capturedAt),
        AddonVersion(),
        table.concat(entries, ","),
    }, "|")

    return wire, #ids, capturedAt
end

local function CaptureSnapshot()
    local wire, count, capturedAt = BuildWire()

    AzerothQuestingCharacterDB = AzerothQuestingCharacterDB or {}
    AzerothQuestingCharacterDB.completedQuestHandoff = {
        schema = 1,
        capturedAt = capturedAt,
        questCount = count,
        wire = wire,
    }

    return count
end

local snapshotScheduled = false
local function ScheduleSnapshot(delay)
    if snapshotScheduled or not C_Timer or not C_Timer.After then
        return
    end

    snapshotScheduled = true
    C_Timer.After(delay or 0.5, function()
        snapshotScheduled = false
        CaptureSnapshot()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        CaptureSnapshot()
    elseif event == "PLAYER_LOGIN" then
        ScheduleSnapshot(3)
    else
        ScheduleSnapshot(0.75)
    end
end)

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "completed client" or command == "completed companion"
        or command == "toon completed client" then
        local count = CaptureSnapshot()
        Print(string.format(
            "Prepared %d completed quests for Azeroth Questing Companion. Use /reload or log out so WoW writes the per-character data file for the Companion to read.",
            count
        ))
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.CaptureCurrentCharacterCompletedQuestClientSnapshot = CaptureSnapshot
