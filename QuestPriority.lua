local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
if not mainFrame then
    return
end

local function GetDB()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    return ZoneQuestGuideDB
end

local function GetQuestRows()
    local rows = {}

    for _, child in ipairs({ mainFrame:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button"
            and child.text and child.text.SetText then
            rows[#rows + 1] = child
        end
    end

    table.sort(rows, function(a, b)
        local _, _, _, _, ay = a:GetPoint(1)
        local _, _, _, _, by = b:GetPoint(1)
        return (ay or 0) > (by or 0)
    end)

    return rows
end

local function UpdateAutoTrackLabel()
    for _, child in ipairs({ mainFrame:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "CheckButton"
            and child.text and child.text.SetText then
            child.text:SetText("Auto-point to next quest (zone first)")
            return
        end
    end
end

local function GetCategoryPriority(quest)
    if ZQG.GetQuestCategoryPriority then
        return ZQG.GetQuestCategoryPriority(quest)
    end

    return 1
end

local function GetStatusPriority(quest)
    if ZQG.GetQuestStatusPriority then
        return ZQG.GetQuestStatusPriority(quest)
    end

    return quest.accepted and 2 or 1
end

local function GetStatusText(quest)
    if ZQG.GetQuestStatusText then
        return ZQG.GetQuestStatusText(quest)
    end

    return quest.accepted
        and "|cff66ff66IN PROGRESS|r"
        or "|cffffff66AVAILABLE|r"
end

local function BreadcrumbComesBefore(breadcrumbQuest, laterQuest)
    if not breadcrumbQuest or not laterQuest then
        return false
    end

    local rules = ZQG.QuestAvailabilityRules
        and ZQG.QuestAvailabilityRules[breadcrumbQuest.id] or nil
    for _, laterQuestID in ipairs(rules and rules.skippedBy or {}) do
        if laterQuestID == laterQuest.id then
            return true
        end
    end

    return false
end

local function ApplyAvailableFirstPriority()
    local rows = GetQuestRows()
    if #rows == 0 then
        return
    end

    local quests = {}
    for _, row in ipairs(rows) do
        if row.quest then
            quests[#quests + 1] = row.quest
        end
    end

    if #quests == 0 then
        return
    end

    table.sort(quests, function(a, b)
        -- Normal zone quests stay ahead of repeatable daily quests so automatic
        -- navigation remains focused on permanent zone completion first.
        local ac = GetCategoryPriority(a)
        local bc = GetCategoryPriority(b)
        if ac ~= bc then
            return ac < bc
        end

        -- Within each section: AVAILABLE, TURN IN, then IN PROGRESS.
        local ap = GetStatusPriority(a)
        local bp = GetStatusPriority(b)
        if ap ~= bp then
            return ap < bp
        end

        -- If two otherwise comparable quests have a known breadcrumb lockout,
        -- put the breadcrumb first even when the later quest is closer.
        if not a.accepted and not b.accepted then
            if BreadcrumbComesBefore(a, b) then
                return true
            elseif BreadcrumbComesBefore(b, a) then
                return false
            end
        end

        local ad = a.distance2 or math.huge
        local bd = b.distance2 or math.huge
        if ad ~= bd then
            return ad < bd
        end

        return (a.id or 0) < (b.id or 0)
    end)

    for index, row in ipairs(rows) do
        local quest = quests[index]
        row.quest = quest

        if quest then
            local status = GetStatusText(quest)
            local badge = quest.isCampaign and " [Campaign]"
                or (quest.isLocalStory and " [Local Story]" or "")

            row.text:SetText(string.format("%s  %s%s", status, quest.name, badge))
            row:Show()
        else
            row:Hide()
        end
    end

    local DB = GetDB()
    if DB.autoTrack and quests[1] and ZQG.SetWaypointForQuest then
        ZQG.SetWaypointForQuest(quests[1])
    end
end

local scheduled = false
local function SchedulePriorityRefresh()
    if scheduled then
        return
    end

    scheduled = true
    C_Timer.After(0.25, function()
        scheduled = false
        UpdateAutoTrackLabel()
        ApplyAvailableFirstPriority()
    end)
end

local priorityEvents = CreateFrame("Frame")
priorityEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
priorityEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
priorityEvents:RegisterEvent("ZONE_CHANGED")
priorityEvents:RegisterEvent("QUEST_ACCEPTED")
priorityEvents:RegisterEvent("QUEST_REMOVED")
priorityEvents:RegisterEvent("QUEST_TURNED_IN")
priorityEvents:RegisterEvent("QUEST_LOG_UPDATE")
priorityEvents:RegisterEvent("QUESTLINE_UPDATE")
priorityEvents:RegisterEvent("GOSSIP_SHOW")
priorityEvents:RegisterEvent("QUEST_DETAIL")
priorityEvents:SetScript("OnEvent", SchedulePriorityRefresh)

mainFrame:HookScript("OnShow", SchedulePriorityRefresh)

-- Also cover manual refreshes triggered through the minimap button or /zq.
local originalRefresh = ZQG.Refresh
if originalRefresh then
    ZQG.Refresh = function(...)
        originalRefresh(...)
        SchedulePriorityRefresh()
    end
end

SchedulePriorityRefresh()
