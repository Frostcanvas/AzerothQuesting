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
local activeHub
local manualQuestID
local lastGuideMapID

local HUB_RADIUS_YARDS = 120
local LOCAL_ACTION_RADIUS_YARDS = 350
local MAX_HUB_ACTIONS = 6

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

local function IsOnTaxi()
    return UnitOnTaxi and UnitOnTaxi("player") and true or false
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

local function IsHubAction(quest)
    local status = QuestStatusKey(quest)
    return status == "available" or status == "turnin"
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

local function ClearGuideAnnotations(quests)
    for _, quest in ipairs(quests) do
        quest.guidePickupBatchTotal = nil
        quest.guidePickupBatchRemaining = nil
        quest.guidePickupBatchIndex = nil
        quest.guidePickupNextName = nil
        quest.guideHubTotal = nil
        quest.guideHubRemaining = nil
        quest.guideHubIndex = nil
        quest.guideHubPickupRemaining = nil
        quest.guideHubTurninRemaining = nil
        quest.guideHubNextName = nil
        quest.guideHubNextAction = nil
    end
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

local function PlayerWorldPoint(mapID)
    if not mapID or not C_Map or not C_Map.GetPlayerMapPosition
        or not C_Map.GetWorldPosFromMapPos then
        return nil, nil, nil
    end

    local posOK, mapPos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not posOK or not mapPos then
        return nil, nil, nil
    end

    local x, y = mapPos:GetXY()
    if not x or not y or (x == 0 and y == 0) then
        return nil, nil, nil
    end

    local worldOK, continent, worldPos = pcall(C_Map.GetWorldPosFromMapPos, mapID, mapPos)
    if not worldOK or not worldPos then
        return nil, nil, nil
    end

    local worldX, worldY = GetWorldXY(worldPos)
    if not worldX or not worldY then
        return nil, nil, nil
    end
    return continent, worldX, worldY
end

local function DistanceFromPlayerYards(quest, mapID)
    local playerContinent, px, py = PlayerWorldPoint(mapID)
    local questContinent, qx, qy = QuestWorldPoint(quest, mapID)
    if not px or not py or not qx or not qy then
        return nil
    end
    if playerContinent and questContinent and playerContinent ~= questContinent then
        return nil
    end

    local dx = qx - px
    local dy = qy - py
    return math.sqrt((dx * dx) + (dy * dy))
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
        return yards <= HUB_RADIUS_YARDS
    end

    if type(a and a.x) == "number" and type(a and a.y) == "number"
        and type(b and b.x) == "number" and type(b and b.y) == "number" then
        local dx = a.x - b.x
        local dy = a.y - b.y
        return ((dx * dx) + (dy * dy)) <= (0.018 * 0.018)
    end

    return false
end

local function BetterDistance(currentDistance, candidateDistance)
    if candidateDistance == nil then
        return currentDistance == nil
    end
    if currentDistance == nil then
        return true
    end
    return candidateDistance < currentDistance
end

local function BestAutomaticQuestIndex(quests)
    if #quests == 0 then
        return nil
    end

    local mapID = CurrentMapID()
    local current = FindQuestIndex(quests, currentQuestID)

    -- A deliberate row click or guide next/back remains authoritative until
    -- that quest disappears or the player changes maps.
    if manualQuestID and currentQuestID == manualQuestID and current then
        return current
    end

    local localTurninIndex, localTurninDistance
    local localAvailableIndex, localAvailableDistance
    local progressIndex, progressDistance
    local turninIndex, turninDistance
    local availableIndex, availableDistance

    for index, quest in ipairs(quests) do
        local status = QuestStatusKey(quest)
        local distance = DistanceFromPlayerYards(quest, mapID)

        if status == "turnin" then
            if distance and distance <= LOCAL_ACTION_RADIUS_YARDS
                and BetterDistance(localTurninDistance, distance) then
                localTurninIndex = index
                localTurninDistance = distance
            end
            if not turninIndex or BetterDistance(turninDistance, distance) then
                turninIndex = index
                turninDistance = distance
            end
        elseif status == "available" then
            if distance and distance <= LOCAL_ACTION_RADIUS_YARDS
                and BetterDistance(localAvailableDistance, distance) then
                localAvailableIndex = index
                localAvailableDistance = distance
            end
            if not availableIndex or BetterDistance(availableDistance, distance) then
                availableIndex = index
                availableDistance = distance
            end
        elseif status == "progress" then
            if not progressIndex or BetterDistance(progressDistance, distance) then
                progressIndex = index
                progressDistance = distance
            end
        end
    end

    -- Keep the original "pick up nearby work before leaving" behavior, but do
    -- not let a quest hundreds of yards away steal the guide while the player
    -- already has active objectives in the current area.
    if localTurninIndex then
        return localTurninIndex
    end
    if localAvailableIndex then
        return localAvailableIndex
    end

    -- Once an in-progress quest has been chosen, keep it stable instead of
    -- bouncing between objectives just because two map POIs trade places by a
    -- few yards while the player moves.
    if current and QuestStatusKey(quests[current]) == "progress" then
        return current
    end
    if progressIndex then
        return progressIndex
    end
    if turninIndex then
        return turninIndex
    end
    if availableIndex then
        return availableIndex
    end

    return current or 1
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

    -- Turn-ins can safely share a hub step with pickups. Relationship rules are
    -- only used to keep two available pickups from being combined in an order
    -- that can skip a breadcrumb or select a mutually-exclusive branch.
    if QuestStatusKey(a) ~= "available" or QuestStatusKey(b) ~= "available" then
        return false
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

local function AddKnownHubQuest(hub, questID)
    if not hub or not questID or hub.known[questID] then
        return false
    end
    if #hub.order >= MAX_HUB_ACTIONS then
        return false
    end
    hub.known[questID] = true
    hub.order[#hub.order + 1] = questID
    hub.total = #hub.order
    return true
end

local function HubAnchorQuest(hub)
    return hub and { x = hub.x, y = hub.y } or nil
end

local function ConflictsWithHubPickups(hub, quests, candidate)
    for _, questID in ipairs(hub.order) do
        local existing = FindQuestByID(quests, questID)
        if existing and PickupRelationshipConflicts(existing, candidate) then
            return true
        end
    end
    return false
end

local function ExpandHub(hub, quests)
    if not hub or hub.mapID ~= CurrentMapID() then
        return
    end

    local anchor = HubAnchorQuest(hub)
    for _, quest in ipairs(quests) do
        if #hub.order >= MAX_HUB_ACTIONS then
            break
        end

        if not hub.known[quest.id]
            and IsHubAction(quest)
            and quest.x and quest.y
            and QuestsAreNear(anchor, quest, hub.mapID)
            and not ConflictsWithHubPickups(hub, quests, quest) then
            AddKnownHubQuest(hub, quest.id)
        end
    end
end

local function BuildHub(quests, anchor)
    if not anchor or not IsHubAction(anchor) or not anchor.x or not anchor.y then
        return nil
    end

    local mapID = CurrentMapID()
    if not mapID then
        return nil
    end

    local hub = {
        mapID = mapID,
        x = anchor.x,
        y = anchor.y,
        known = {},
        order = {},
        completed = {},
        total = 0,
        lastActionAt = nil,
    }
    AddKnownHubQuest(hub, anchor.id)
    ExpandHub(hub, quests)

    if hub.total < 2 then
        return nil
    end
    return hub
end

local function ActionLabel(quest)
    local status = QuestStatusKey(quest)
    if status == "turnin" then
        return "Turn in"
    end
    return "Pick up"
end

local function SortHubActions(actions)
    table.sort(actions, function(a, b)
        local statusA = QuestStatusKey(a)
        local statusB = QuestStatusKey(b)
        if statusA ~= statusB then
            -- Finish completed quests before collecting more work at the same
            -- hub. This also lets newly unlocked follow-ups appear immediately.
            return statusA == "turnin"
        end
        local da = tonumber(a.distance2) or math.huge
        local db = tonumber(b.distance2) or math.huge
        if da ~= db then
            return da < db
        end
        return (a.id or 0) < (b.id or 0)
    end)
end

local function AnnotateHubTarget(target, hub, actions)
    if not target or not hub then
        return
    end

    local pickups = 0
    local turnins = 0
    for _, action in ipairs(actions) do
        if QuestStatusKey(action) == "turnin" then
            turnins = turnins + 1
        else
            pickups = pickups + 1
        end
    end

    target.guideHubTotal = hub.total
    target.guideHubRemaining = #actions
    target.guideHubIndex = math.max(1, hub.total - #actions + 1)
    target.guideHubPickupRemaining = pickups
    target.guideHubTurninRemaining = turnins

    local nextQuest = actions[2]
    target.guideHubNextName = nextQuest and nextQuest.name or nil
    target.guideHubNextAction = nextQuest and ActionLabel(nextQuest) or nil
end

local function ResolveActiveHub(quests)
    local hub = activeHub
    if not hub then
        return nil, nil
    end

    if hub.mapID and CurrentMapID() ~= hub.mapID then
        activeHub = nil
        return nil, nil
    end

    ExpandHub(hub, quests)

    local actions = {}
    local progress = {}
    for _, questID in ipairs(hub.order) do
        local quest = FindQuestByID(quests, questID)
        if quest then
            local status = QuestStatusKey(quest)
            if status == "available" or status == "turnin" then
                if not hub.completed[questID] then
                    actions[#actions + 1] = quest
                end
            elseif status == "progress" then
                hub.completed[questID] = true
                progress[#progress + 1] = quest
            end
        end
    end

    if #actions > 0 then
        SortHubActions(actions)
        local target = actions[1]
        AnnotateHubTarget(target, hub, actions)
        return target, nil
    end

    activeHub = nil
    return nil, progress[1]
end

local function MarkHubActionComplete(questID)
    local hub = activeHub
    if not hub or not questID or not hub.known[questID] then
        return
    end
    hub.completed[questID] = true
    hub.lastActionAt = GetTime and GetTime() or nil
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
        ZQG.GuideHubActive = false
        activeHub = nil
        return
    end

    ZQG.GuideHubActive = true

    local mapID = CurrentMapID()
    if not IsOnTaxi() then
        if lastGuideMapID and mapID and mapID ~= lastGuideMapID then
            activeHub = nil
            manualQuestID = nil
            currentQuestID = nil
            currentIndex = 1
            lastWaypointKey = nil
        end
        if mapID then
            lastGuideMapID = mapID
        end
    elseif not lastGuideMapID and mapID then
        lastGuideMapID = mapID
    end

    local quests = GetGuideQuests()
    ClearGuideAnnotations(quests)

    if #quests == 0 then
        currentQuestID = nil
        currentIndex = 1
        lastWaypointKey = nil
        activeHub = nil
        manualQuestID = nil
        return
    end

    if manualQuestID and not FindQuestIndex(quests, manualQuestID) then
        manualQuestID = nil
    end

    local quest
    local hubTarget, hubFinishedTarget = ResolveActiveHub(quests)
    if hubTarget then
        quest = hubTarget
        currentQuestID = quest.id
        currentIndex = FindQuestIndex(quests, currentQuestID) or currentIndex
    else
        if hubFinishedTarget then
            currentQuestID = hubFinishedTarget.id
        end

        local index = BestAutomaticQuestIndex(quests)
        if not index then
            return
        end
        if currentQuestID ~= quests[index].id then
            lastWaypointKey = nil
        end
        SelectQuestAt(index, quests, false)

        quest = quests[currentIndex]
        if not quest then
            return
        end
        currentQuestID = quest.id

        -- Zygor-style hub step: if the current action is a pickup or turn-in,
        -- keep every safe nearby pickup/turn-in together before routing the
        -- player away toward quest objectives.
        if IsHubAction(quest) then
            local hub = BuildHub(quests, quest)
            if hub then
                activeHub = hub
                local nextHubTarget = ResolveActiveHub(quests)
                if nextHubTarget then
                    quest = nextHubTarget
                    currentQuestID = quest.id
                    currentIndex = FindQuestIndex(quests, currentQuestID) or currentIndex
                end
            end
        end
    end

    local waypointKey = table.concat({
        tostring(quest.id or 0),
        QuestStatusKey(quest),
        tostring(quest.guideHubIndex or 0),
        tostring(quest.guideHubRemaining or 0),
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
                    activeHub = nil
                    manualQuestID = self.quest.id
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
events:SetScript("OnEvent", function(_, event, ...)
    local arg1, arg2 = ...
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

    if event == "QUEST_ACCEPTED" then
        MarkHubActionComplete(arg2 or arg1)
        if manualQuestID == (arg2 or arg1) then
            manualQuestID = nil
        end
    elseif event == "QUEST_TURNED_IN" then
        MarkHubActionComplete(arg1)
        if manualQuestID == arg1 then
            manualQuestID = nil
        end
    end

    ScheduleGuideUpdate(event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN")
end)

function ZQG.ShowGuideMode()
    GetDB().guideModeEnabled = true
    ZQG.GuideHubActive = true
    HookQuestRows()
    ScheduleGuideUpdate(true)
end

function ZQG.HideGuideMode()
    GetDB().guideModeEnabled = false
    ZQG.GuideHubActive = false
    activeHub = nil
    manualQuestID = nil
    ClearGuideAnnotations(GetGuideQuests())
end

function ZQG.ToggleGuideMode()
    local DB = GetDB()
    DB.guideModeEnabled = DB.guideModeEnabled == false
    if DB.guideModeEnabled then
        ZQG.GuideHubActive = true
        HookQuestRows()
        ScheduleGuideUpdate(true)
    else
        ZQG.GuideHubActive = false
        activeHub = nil
        manualQuestID = nil
        ClearGuideAnnotations(GetGuideQuests())
    end
end

function ZQG.GuideNext()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    activeHub = nil
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) + 1, quests, true)
    manualQuestID = currentQuestID
    UpdateGuide(true)
end

function ZQG.GuideBack()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    activeHub = nil
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) - 1, quests, true)
    manualQuestID = currentQuestID
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
