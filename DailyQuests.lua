local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
if not mainFrame then
    return
end

-- Quest IDs are stable, so once WoW identifies a quest as daily during this
-- session we can safely remember that classification even after the NPC gossip
-- window closes or the player moves around the zone.
local dailyQuestIDs = {}

local function CurrentMapID()
    if not C_Map or not C_Map.GetBestMapForUnit then
        return nil
    end
    return C_Map.GetBestMapForUnit("player")
end

local function MarkDaily(questID)
    if questID and questID > 0 then
        dailyQuestIDs[questID] = true
    end
end

local function RefreshMapDailyCache()
    local mapID = CurrentMapID()
    if not mapID then
        return
    end

    -- Accepted/current-map quests expose an isDaily flag through the map quest
    -- information returned by C_QuestLog.GetQuestsOnMap().
    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info.questID and info.isDaily then
                    MarkDaily(info.questID)
                end
            end
        end
    end

    -- Available quest-line starters also expose isDaily.
    if C_QuestLine and C_QuestLine.GetAvailableQuestLines then
        local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
        if ok and type(lines) == "table" then
            for _, info in ipairs(lines) do
                if info.questID and info.isDaily then
                    MarkDaily(info.questID)
                end
            end
        end
    end
end

local function CaptureGossipDailyQuests()
    if not C_GossipInfo then
        return
    end

    local getters = {
        C_GossipInfo.GetAvailableQuests,
        C_GossipInfo.GetActiveQuests,
    }

    for _, getter in ipairs(getters) do
        if getter then
            local ok, quests = pcall(getter)
            if ok and type(quests) == "table" then
                for _, info in ipairs(quests) do
                    -- GossipQuestUIInfo uses the legacy quest-frequency values:
                    -- 1 normal, 2 daily, 3 weekly.
                    if info.questID and info.frequency == 2 then
                        MarkDaily(info.questID)
                    end
                end
            end
        end
    end
end

local function IsDailyFromQuestLog(questID)
    if not questID or not C_QuestLog or not C_QuestLog.GetLogIndexForQuestID
        or not C_QuestLog.GetInfo then
        return false
    end

    local indexOK, logIndex = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    if not indexOK or not logIndex or logIndex <= 0 then
        return false
    end

    local infoOK, info = pcall(C_QuestLog.GetInfo, logIndex)
    if not infoOK or not info or info.frequency == nil then
        return false
    end

    if Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily ~= nil then
        return info.frequency == Enum.QuestFrequency.Daily
    end

    -- Current C_QuestLog.GetInfo() enum value for Daily is 1.
    return info.frequency == 1
end

function ZQG.IsDailyQuest(quest)
    if not quest or not quest.id then
        return false
    end

    if quest.isDaily or dailyQuestIDs[quest.id] then
        quest.isDaily = true
        return true
    end

    if quest.accepted and IsDailyFromQuestLog(quest.id) then
        quest.isDaily = true
        MarkDaily(quest.id)
        return true
    end

    return false
end

-- Regular zone-completion quests should remain the main guide path. Dailies are
-- still visible and navigable, but they come after normal zone quests.
function ZQG.GetQuestCategoryPriority(quest)
    return ZQG.IsDailyQuest(quest) and 2 or 1
end

-- Capture only Core.lua's ten quest-row buttons. Other buttons such as Options
-- can also have text regions, so size checking prevents them from being moved
-- into the quest sections.
local rows = {}
for _, child in ipairs({ mainFrame:GetChildren() }) do
    if child.GetObjectType and child:GetObjectType() == "Button"
        and child.text and child.text.SetText then
        local width, height = child:GetSize()
        if math.abs((width or 0) - 330) < 1 and math.abs((height or 0) - 25) < 1 then
            rows[#rows + 1] = child
        end
    end
end

table.sort(rows, function(a, b)
    local _, _, _, _, ay = a:GetPoint(1)
    local _, _, _, _, by = b:GetPoint(1)
    return (ay or 0) > (by or 0)
end)

local zoneHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
zoneHeader:SetText("ZONE QUESTS")
zoneHeader:SetJustifyH("LEFT")

local dailyHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
dailyHeader:SetText("DAILY QUESTS")
dailyHeader:SetJustifyH("LEFT")

-- The original panel was sized for ten rows without section headings. Give the
-- two-section layout enough room for all ten quest rows plus the footer.
mainFrame:SetHeight(520)

local function PositionGroup(header, group, y)
    if #group == 0 then
        header:Hide()
        return y
    end

    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, y)
    header:Show()
    y = y - 18

    for _, row in ipairs(group) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, y)
        y = y - 27
    end

    return y - 7
end

local function ApplyDailySections()
    RefreshMapDailyCache()
    CaptureGossipDailyQuests()

    local zoneRows = {}
    local dailyRows = {}

    for _, row in ipairs(rows) do
        if row.quest and row:IsShown() then
            if ZQG.IsDailyQuest(row.quest) then
                dailyRows[#dailyRows + 1] = row
            else
                zoneRows[#zoneRows + 1] = row
            end
        end
    end

    local y = -146
    y = PositionGroup(zoneHeader, zoneRows, y)
    PositionGroup(dailyHeader, dailyRows, y)
end

local scheduled = false
local function ScheduleDailyRefresh()
    if scheduled then
        return
    end

    scheduled = true
    C_Timer.After(0.45, function()
        scheduled = false
        ApplyDailySections()
    end)
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
events:RegisterEvent("QUEST_DETAIL")
events:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
        CaptureGossipDailyQuests()
    end
    ScheduleDailyRefresh()
end)

mainFrame:HookScript("OnShow", ScheduleDailyRefresh)
ScheduleDailyRefresh()
