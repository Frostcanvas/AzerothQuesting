local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
if not mainFrame then
    return
end

local currentQuestID
local currentIndex = 1
local lastWaypointKey
local updateScheduled = false
local forceWaypointOnUpdate = false

local function GetDB()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    return ZoneQuestGuideDB
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then
            return mapID
        end
    end
    return nil
end

local function QuestStatusKey(quest)
    if ZQG.GetQuestStatusKey then
        local ok, status = pcall(ZQG.GetQuestStatusKey, quest)
        if ok and status then
            return status
        end
    end
    return quest and quest.accepted and "progress" or "available"
end

local function GetQuestRows()
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
    return rows
end

local function GetGuideQuests()
    local quests = {}
    for _, row in ipairs(GetQuestRows()) do
        if row.quest then
            quests[#quests + 1] = row.quest
        end
    end
    return quests
end

local function FindQuestIndex(quests, questID)
    if not questID then
        return nil
    end
    for index, quest in ipairs(quests) do
        if quest.id == questID then
            return index
        end
    end
    return nil
end

local function SelectQuestAt(index, quests, forceWaypoint)
    quests = quests or GetGuideQuests()
    if #quests == 0 then
        currentQuestID = nil
        currentIndex = 1
        lastWaypointKey = nil
        return
    end

    index = math.max(1, math.min(index or 1, #quests))
    currentIndex = index
    currentQuestID = quests[index].id
    if forceWaypoint then
        lastWaypointKey = nil
    end
end

local function UpdateGuide(forceWaypoint)
    if GetDB().guideModeEnabled == false then
        return
    end

    local quests = GetGuideQuests()
    if #quests == 0 then
        currentQuestID = nil
        currentIndex = 1
        lastWaypointKey = nil
        return
    end

    local index = FindQuestIndex(quests, currentQuestID)
    if not index then
        index = math.max(1, math.min(currentIndex or 1, #quests))
        SelectQuestAt(index, quests, true)
    else
        currentIndex = index
    end

    local quest = quests[currentIndex]
    if not quest then
        return
    end
    currentQuestID = quest.id

    local waypointKey = table.concat({
        tostring(quest.id or 0),
        QuestStatusKey(quest),
        tostring(CurrentMapID() or 0),
    }, ":")

    if forceWaypoint or waypointKey ~= lastWaypointKey then
        lastWaypointKey = waypointKey
        if ZQG.SetWaypointForQuest then
            pcall(ZQG.SetWaypointForQuest, quest)
        end
    end
end

local function ScheduleGuideUpdate(forceWaypoint)
    forceWaypointOnUpdate = forceWaypointOnUpdate or forceWaypoint
    if updateScheduled then
        return
    end

    updateScheduled = true
    C_Timer.After(0.4, function()
        updateScheduled = false
        local force = forceWaypointOnUpdate
        forceWaypointOnUpdate = false
        UpdateGuide(force)
    end)
end

local function HookQuestRows()
    for _, row in ipairs(GetQuestRows()) do
        if not row.ZQGGuideModeHooked then
            row.ZQGGuideModeHooked = true
            row:HookScript("OnClick", function(self)
                if self.quest then
                    currentQuestID = self.quest.id
                    local quests = GetGuideQuests()
                    currentIndex = FindQuestIndex(quests, currentQuestID) or 1
                    lastWaypointKey = nil
                    ScheduleGuideUpdate(true)
                end
            end)
        end
    end
end

local originalRefresh = ZQG.Refresh
if originalRefresh then
    ZQG.Refresh = function(...)
        local result = originalRefresh(...)
        HookQuestRows()
        ScheduleGuideUpdate(false)
        return result
    end
end

mainFrame:HookScript("OnShow", function()
    HookQuestRows()
    ScheduleGuideUpdate(false)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
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
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then
            return
        end
        local DB = GetDB()
        if DB.guideModeEnabled == nil then
            DB.guideModeEnabled = true
        end
        HookQuestRows()
        ScheduleGuideUpdate(true)
        return
    end

    ScheduleGuideUpdate(event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN")
end)

function ZQG.ShowGuideMode()
    GetDB().guideModeEnabled = true
    HookQuestRows()
    ScheduleGuideUpdate(true)
end

function ZQG.HideGuideMode()
    GetDB().guideModeEnabled = false
end

function ZQG.ToggleGuideMode()
    local DB = GetDB()
    DB.guideModeEnabled = DB.guideModeEnabled == false
    if DB.guideModeEnabled then
        HookQuestRows()
        ScheduleGuideUpdate(true)
    end
end

function ZQG.GuideNext()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) + 1, quests, true)
    UpdateGuide(true)
end

function ZQG.GuideBack()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) - 1, quests, true)
    UpdateGuide(true)
end

local previousSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "guide" then
        ZQG.ToggleGuideMode()
        Print("Guide Mode is " .. (GetDB().guideModeEnabled == false and "OFF" or "ON") .. ".")
        return
    elseif command == "guide on" then
        ZQG.ShowGuideMode()
        Print("Guide Mode is ON.")
        return
    elseif command == "guide off" then
        ZQG.HideGuideMode()
        Print("Guide Mode is OFF.")
        return
    elseif command == "guide next" then
        ZQG.GuideNext()
        return
    elseif command == "guide back" then
        ZQG.GuideBack()
        return
    end

    if previousSlashHandler then
        previousSlashHandler(msg)
    end
end
