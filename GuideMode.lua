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
local activePickupBatch

local PICKUP_GROUP_RADIUS_YARDS = 120
local MAX_PICKUP_BATCH = 4

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


local function FindQuestByID(quests, questID)
    local index = FindQuestIndex(quests, questID)
    return index and quests[index] or nil
end

local function GetWorldXY(worldPos)
    if not worldPos then
        return nil, nil
    end
    if worldPos.GetXY then
        return worldPos:GetXY()
    end
    return worldPos.x, worldPos.y
end

local function QuestWorldPoint(quest, mapID)
    if not quest or not quest.x or not quest.y or not mapID
        or not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then
        return nil, nil, nil
    end

    local ok, continent, worldPos = pcall(
        C_Map.GetWorldPosFromMapPos,
        mapID,
        CreateVector2D(quest.x, quest.y)
    )
    if not ok or not worldPos then
        return nil, nil, nil
    end

    local x, y = GetWorldXY(worldPos)
    if not x or not y then
        return nil, nil, nil
    end
    return continent, x, y
end

local function DistanceBetweenQuestsYards(a, b, mapID)
    local continentA, ax, ay = QuestWorldPoint(a, mapID)
    local continentB, bx, by = QuestWorldPoint(b, mapID)
    if not ax or not ay or not bx or not by then
        return nil
    end
    if continentA and continentB and continentA ~= continentB then
        return nil
    end

    local dx = bx - ax
    local dy = by - ay
    return math.sqrt((dx * dx) + (dy * dy))
end

local function QuestsAreNear(a, b, mapID)
    local yards = DistanceBetweenQuestsYards(a, b, mapID)
    if yards then
        return yards <= PICKUP_GROUP_RADIUS_YARDS
    end

    if type(a and a.x) == "number" and type(a and a.y) == "number"
        and type(b and b.x) == "number" and type(b and b.y) == "number" then
        local dx = a.x - b.x
        local dy = a.y - b.y
        return ((dx * dx) + (dy * dy)) <= (0.018 * 0.018)
    end

    return false
end

local function ListContains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

local function PickupRelationshipConflicts(a, b)
    if not a or not b then
        return true
    end

    local rulesA = ZQG.QuestAvailabilityRules and ZQG.QuestAvailabilityRules[a.id] or nil
    local rulesB = ZQG.QuestAvailabilityRules and ZQG.QuestAvailabilityRules[b.id] or nil

    local function HasRelation(quest, rules, field, otherID)
        return ListContains(quest and quest[field], otherID)
            or ListContains(rules and rules[field], otherID)
    end

    if HasRelation(a, rulesA, "exclusiveWith", b.id)
        or HasRelation(b, rulesB, "exclusiveWith", a.id) then
        return true
    end

    -- Breadcrumbs and the later quests that can skip them stay as separate
    -- steps so the guide does not encourage a lockout-producing pickup order.
    if HasRelation(a, rulesA, "skippedBy", b.id)
        or HasRelation(b, rulesB, "skippedBy", a.id) then
        return true
    end

    if HasRelation(a, rulesA, "blockedBy", b.id)
        or HasRelation(b, rulesB, "blockedBy", a.id) then
        return true
    end

    return false
end

local function BuildPickupBatch(quests, anchor)
    if not anchor or QuestStatusKey(anchor) ~= "available" or not anchor.x or not anchor.y then
        return nil
    end

    local mapID = CurrentMapID()
    if not mapID then
        return nil
    end

    local ids = { anchor.id }
    for _, quest in ipairs(quests) do
        if #ids >= MAX_PICKUP_BATCH then
            break
        end

        if quest.id ~= anchor.id
            and QuestStatusKey(quest) == "available"
            and quest.x and quest.y
            and not PickupRelationshipConflicts(anchor, quest)
            and QuestsAreNear(anchor, quest, mapID) then
            ids[#ids + 1] = quest.id
        end
    end

    if #ids < 2 then
        return nil
    end

    return {
        ids = ids,
        total = #ids,
        mapID = mapID,
    }
end

local function AnnotatePickupTarget(quest, batch, pending)
    if not quest or not batch then
        return
    end

    quest.guidePickupBatchTotal = batch.total
    quest.guidePickupBatchRemaining = #pending
    quest.guidePickupBatchIndex = math.max(1, batch.total - #pending + 1)
    quest.guidePickupNextName = pending[2] and pending[2].name or nil
end

local function ResolveActivePickupBatch(quests)
    local batch = activePickupBatch
    if not batch then
        return nil, nil
    end

    if batch.mapID and CurrentMapID() ~= batch.mapID then
        activePickupBatch = nil
        return nil, nil
    end

    local pending = {}
    local accepted = {}
    for _, questID in ipairs(batch.ids) do
        local quest = FindQuestByID(quests, questID)
        if quest then
            local status = QuestStatusKey(quest)
            if status == "available" then
                pending[#pending + 1] = quest
            elseif status == "progress" or status == "turnin" then
                accepted[#accepted + 1] = quest
            end
        end
    end

    if #pending > 0 then
        local target = pending[1]
        AnnotatePickupTarget(target, batch, pending)
        return target, nil
    end

    activePickupBatch = nil
    return nil, accepted[1]
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
        activePickupBatch = nil
        return
    end

    local quests = GetGuideQuests()
    if #quests == 0 then
        currentQuestID = nil
        currentIndex = 1
        lastWaypointKey = nil
        activePickupBatch = nil
        return
    end

    local quest
    local batchTarget, batchFinishedTarget = ResolveActivePickupBatch(quests)
    if batchTarget then
        quest = batchTarget
        currentQuestID = quest.id
        currentIndex = FindQuestIndex(quests, currentQuestID) or currentIndex
    else
        if batchFinishedTarget then
            currentQuestID = batchFinishedTarget.id
        end

        local index = FindQuestIndex(quests, currentQuestID)
        if not index then
            index = math.max(1, math.min(currentIndex or 1, #quests))
            SelectQuestAt(index, quests, true)
        else
            currentIndex = index
        end

        quest = quests[currentIndex]
        if not quest then
            return
        end
        currentQuestID = quest.id

        -- If the current step is a pickup, collect other compatible quests in
        -- the same nearby hub first. This keeps the guide from sending the
        -- player away after accepting only one of several adjacent quests.
        if QuestStatusKey(quest) == "available" then
            local batch = BuildPickupBatch(quests, quest)
            if batch then
                activePickupBatch = batch
                local pickupTarget = ResolveActivePickupBatch(quests)
                if pickupTarget then
                    quest = pickupTarget
                    currentQuestID = quest.id
                    currentIndex = FindQuestIndex(quests, currentQuestID) or currentIndex
                end
            end
        end
    end

    local waypointKey = table.concat({
        tostring(quest.id or 0),
        QuestStatusKey(quest),
        tostring(quest.guidePickupBatchIndex or 0),
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
                    activePickupBatch = nil
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
    activePickupBatch = nil
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
    activePickupBatch = nil
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) + 1, quests, true)
    UpdateGuide(true)
end

function ZQG.GuideBack()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    activePickupBatch = nil
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
