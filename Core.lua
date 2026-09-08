local ADDON_NAME, ZQG = ...

local floor = math.floor
local atan2 = math.atan2
local pi = math.pi

ZoneQuestGuideDB = ZoneQuestGuideDB or {}
local DB

local state = {
    mapID = nil,
    quests = {},
    selected = nil,
    lastRefresh = 0,
    requestedQuestLinesFor = nil,
    observedQuests = {},
    lockoutWarningsShown = {},
}

local breadcrumbsSkippedBy = {}
for breadcrumbID, rules in pairs(ZQG.QuestAvailabilityRules or {}) do
    for _, laterQuestID in ipairs(rules.skippedBy or {}) do
        breadcrumbsSkippedBy[laterQuestID] = breadcrumbsSkippedBy[laterQuestID] or {}
        breadcrumbsSkippedBy[laterQuestID][#breadcrumbsSkippedBy[laterQuestID] + 1] = breadcrumbID
    end
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function IsCompleted(questID)
    return questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
        and C_QuestLog.IsQuestFlaggedCompleted(questID)
end

local function IsOnQuest(questID)
    return questID and C_QuestLog and C_QuestLog.IsOnQuest
        and C_QuestLog.IsOnQuest(questID)
end

local function PlayerFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player")
    end
    return nil
end

local function FactionAllowed(faction)
    return not faction or faction == PlayerFaction()
end

local function PrereqsMet(prereqs)
    if not prereqs or #prereqs == 0 then
        return true
    end
    for _, questID in ipairs(prereqs) do
        if not IsCompleted(questID) then
            return false
        end
    end
    return true
end

local function AnyQuestCompleted(questIDs)
    if not questIDs or #questIDs == 0 then
        return false
    end

    for _, questID in ipairs(questIDs) do
        if IsCompleted(questID) then
            return true
        end
    end

    return false
end

local function AnyQuestActiveOrCompleted(questIDs)
    if not questIDs or #questIDs == 0 then
        return false
    end

    for _, questID in ipairs(questIDs) do
        if IsOnQuest(questID) or IsCompleted(questID) then
            return true
        end
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

local function CurrentMapID()
    if not C_Map or not C_Map.GetBestMapForUnit then
        return nil
    end
    return C_Map.GetBestMapForUnit("player")
end

local function PlayerPosition(mapID)
    if not mapID or not C_Map or not C_Map.GetPlayerMapPosition then
        return nil, nil
    end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        return nil, nil
    end
    local x, y = pos:GetXY()
    if not x or not y or (x == 0 and y == 0) then
        return nil, nil
    end
    return x, y
end

local function DistanceSquared(px, py, x, y)
    if not px or not py or not x or not y then
        return math.huge
    end
    local dx, dy = x - px, y - py
    return dx * dx + dy * dy
end

local function AddQuest(result, seen, quest)
    if not quest or not quest.id or seen[quest.id] or IsCompleted(quest.id) then
        return
    end
    if not FactionAllowed(quest.faction) then
        return
    end

    local rules = ZQG.QuestAvailabilityRules and ZQG.QuestAvailabilityRules[quest.id] or nil
    local questIsActive = IsOnQuest(quest.id) and true or false

    if not PrereqsMet(quest.prereqs) or (rules and not PrereqsMet(rules.prereqs)) then
        return
    end
    if AnyQuestCompleted(quest.blockedBy) or AnyQuestCompleted(rules and rules.blockedBy) then
        return
    end
    if AnyQuestActiveOrCompleted(quest.exclusiveWith)
        or AnyQuestActiveOrCompleted(rules and rules.exclusiveWith) then
        return
    end

    -- skippedBy is specifically for breadcrumb quests. If the breadcrumb itself
    -- is already active, keep showing it; otherwise a later active/completed
    -- quest means the opportunity has been skipped and should no longer appear.
    if not questIsActive and (AnyQuestActiveOrCompleted(quest.skippedBy)
        or AnyQuestActiveOrCompleted(rules and rules.skippedBy)) then
        return
    end

    seen[quest.id] = true
    quest.accepted = questIsActive
    result[#result + 1] = quest
end

local function GetQuestName(questID, fallback)
    if fallback and fallback ~= "" then
        return fallback
    end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title and title ~= "" then
            return title
        end
    end
    return "Quest " .. tostring(questID)
end

local function WarnAboutBreadcrumbLockout(laterQuestID)
    if not laterQuestID or state.lockoutWarningsShown[laterQuestID] then
        return
    end

    local breadcrumbs = breadcrumbsSkippedBy[laterQuestID]
    if not breadcrumbs then
        return
    end

    local unfinished = {}
    for _, breadcrumbID in ipairs(breadcrumbs) do
        if not IsCompleted(breadcrumbID) and not IsOnQuest(breadcrumbID) then
            unfinished[#unfinished + 1] = GetQuestName(breadcrumbID)
                .. " [" .. tostring(breadcrumbID) .. "]"
        end
    end

    if #unfinished == 0 then
        return
    end

    state.lockoutWarningsShown[laterQuestID] = true
    local laterName = GetQuestName(laterQuestID)
    Print("Lockout warning: accepting " .. laterName .. " [" .. tostring(laterQuestID)
        .. "] may make " .. table.concat(unfinished, ", ")
        .. " unavailable. Complete the breadcrumb quest first if you want it.")
end

local function RequestQuestLines(mapID, force)
    if not mapID or not C_QuestLine or not C_QuestLine.RequestQuestLinesForMap then
        return
    end
    if not force and state.requestedQuestLinesFor == mapID then
        return
    end

    state.requestedQuestLinesFor = mapID
    pcall(C_QuestLine.RequestQuestLinesForMap, mapID)
end

local function RememberObservedQuest(questID, name)
    if not questID or questID == 0 or IsCompleted(questID) then
        return
    end

    local mapID = CurrentMapID()
    if not mapID then
        return
    end

    local x, y = PlayerPosition(mapID)
    state.observedQuests[mapID] = state.observedQuests[mapID] or {}
    state.observedQuests[mapID][questID] = {
        id = questID,
        name = GetQuestName(questID, name),
        x = x,
        y = y,
        source = "observed",
        faction = PlayerFaction(),
    }
end

local function CaptureGossipQuests()
    if not C_GossipInfo or not C_GossipInfo.GetAvailableQuests then
        return
    end

    local ok, quests = pcall(C_GossipInfo.GetAvailableQuests)
    if not ok or type(quests) ~= "table" then
        return
    end

    for _, info in ipairs(quests) do
        RememberObservedQuest(info.questID, info.title)
    end
end

local function CaptureQuestDetail()
    if not GetQuestID then
        return
    end

    local questID = GetQuestID()
    if questID and questID > 0 then
        local title = GetTitleText and GetTitleText() or nil
        RememberObservedQuest(questID, title)
        WarnAboutBreadcrumbLockout(questID)
    end
end

local function CollectAcceptedQuests(mapID, result, seen)
    if not C_QuestLog or not C_QuestLog.GetQuestsOnMap then
        return
    end

    local onMap = C_QuestLog.GetQuestsOnMap(mapID)
    if not onMap then
        return
    end

    for _, info in ipairs(onMap) do
        local questID = info.questID
        if questID then
            AddQuest(result, seen, {
                id = questID,
                name = GetQuestName(questID),
                x = info.x,
                y = info.y,
                source = "questlog",
            })
        end
    end
end

local function CollectAvailableQuestLines(mapID, result, seen)
    if not C_QuestLine or not C_QuestLine.GetAvailableQuestLines then
        return
    end

    local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
    if not ok or type(lines) ~= "table" then
        return
    end

    for _, info in ipairs(lines) do
        local questID = info.questID
        if questID then
            local x, y = info.x, info.y
            local name = info.questName or info.questLineName

            if (not x or not y) and C_QuestLine.GetQuestLineInfo then
                local detailOK, detail = pcall(C_QuestLine.GetQuestLineInfo, questID, mapID)
                if detailOK and type(detail) == "table" then
                    x = x or detail.x
                    y = y or detail.y
                    name = name or detail.questName or detail.questLineName
                end
            end

            AddQuest(result, seen, {
                id = questID,
                name = GetQuestName(questID, name),
                x = x,
                y = y,
                source = "questline",
                isCampaign = info.isCampaign,
                isLocalStory = info.isLocalStory,
            })
        end
    end
end

local function CollectObservedQuests(mapID, result, seen)
    local quests = state.observedQuests[mapID]
    if not quests then
        return
    end

    for _, info in pairs(quests) do
        AddQuest(result, seen, {
            id = info.id,
            name = info.name,
            x = info.x,
            y = info.y,
            source = info.source,
            faction = info.faction,
        })
    end
end

local function CollectStaticQuests(mapID, result, seen)
    local list = ZQG.StaticQuests and ZQG.StaticQuests[mapID]
    if not list then
        return
    end

    for _, info in ipairs(list) do
        AddQuest(result, seen, {
            id = info.id,
            name = GetQuestName(info.id, info.name),
            x = info.x,
            y = info.y,
            prereqs = info.prereqs,
            blockedBy = info.blockedBy,
            exclusiveWith = info.exclusiveWith,
            skippedBy = info.skippedBy,
            faction = info.faction,
            source = "database",
        })
    end
end

local function CollectQuests(mapID)
    local result, seen = {}, {}
    local px, py = PlayerPosition(mapID)

    CollectAcceptedQuests(mapID, result, seen)
    CollectAvailableQuestLines(mapID, result, seen)
    CollectObservedQuests(mapID, result, seen)
    CollectStaticQuests(mapID, result, seen)

    for _, quest in ipairs(result) do
        quest.distance2 = DistanceSquared(px, py, quest.x, quest.y)
    end

    table.sort(result, function(a, b)
        if a.accepted ~= b.accepted then
            return a.accepted
        end

        -- When two unaccepted quests have a known breadcrumb relationship,
        -- prefer the breadcrumb before the later quest that can skip it.
        if not a.accepted and not b.accepted then
            if ListContains(breadcrumbsSkippedBy[b.id], a.id) then
                return true
            elseif ListContains(breadcrumbsSkippedBy[a.id], b.id) then
                return false
            end
        end

        if a.distance2 ~= b.distance2 then
            return a.distance2 < b.distance2
        end
        return a.id < b.id
    end)

    return result
end

local function SetWaypointForQuest(quest)
    if not quest then
        return false
    end

    state.selected = quest

    if quest.accepted and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(quest.id)
        return true
    end

    if quest.x and quest.y and state.mapID and C_Map and C_Map.SetUserWaypoint
        and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local point = UiMapPoint.CreateFromCoordinates(state.mapID, quest.x, quest.y)
        C_Map.SetUserWaypoint(point)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        return true
    end

    return false
end

-- -------------------------- UI --------------------------

local frame = CreateFrame("Frame", "ZoneQuestGuideFrame", UIParent, "BackdropTemplate")
frame:SetSize(360, 430)
frame:SetPoint("CENTER", UIParent, "CENTER", 420, 0)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    DB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -14)
title:SetText("Azeroth Questing")

local zoneText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
zoneText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
zoneText:SetWidth(285)
zoneText:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -3, -3)

local arrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
arrow:SetPoint("TOP", frame, "TOP", 0, -54)
arrow:SetText("↑")

local targetText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
targetText:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
targetText:SetWidth(320)
targetText:SetJustifyH("CENTER")
targetText:SetText("No quest selected")

local autoButton = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
autoButton:SetPoint("TOPLEFT", 12, -112)
autoButton.text = autoButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
autoButton.text:SetPoint("LEFT", autoButton, "RIGHT", 2, 1)
autoButton.text:SetText("Auto-point to nearest unfinished quest")
autoButton:SetScript("OnClick", function(self)
    DB.autoTrack = self:GetChecked() and true or false
    if DB.autoTrack and state.quests[1] then
        SetWaypointForQuest(state.quests[1])
    end
end)

local separator = frame:CreateTexture(nil, "ARTWORK")
separator:SetColorTexture(1, 1, 1, 0.12)
separator:SetPoint("TOPLEFT", 12, -143)
separator:SetPoint("TOPRIGHT", -12, -143)
separator:SetHeight(1)

local rows = {}
local MAX_ROWS = 10
for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, frame, "BackdropTemplate")
    row:SetSize(330, 25)
    row:SetPoint("TOPLEFT", 14, -151 - ((i - 1) * 27))
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    row:SetBackdropColor(0, 0, 0, 0)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 6, 0)
    row.text:SetPoint("RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 1, 1, 0.08) end)
    row:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
    row:SetScript("OnClick", function(self)
        if self.quest then
            if not SetWaypointForQuest(self.quest) then
                Print("I found that quest, but this client did not provide a usable waypoint for it.")
            end
        end
    end)

    rows[i] = row
end

local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetPoint("BOTTOMLEFT", 14, 12)
footer:SetWidth(330)
footer:SetJustifyH("LEFT")
footer:SetText("/aq  show/hide    /aq refresh    /aq auto")

local function UpdateRows()
    for i, row in ipairs(rows) do
        local quest = state.quests[i]
        row.quest = quest
        if quest then
            local status = quest.accepted and "|cff66ff66IN PROGRESS|r" or "|cffffff66AVAILABLE|r"
            local badge = quest.isCampaign and " [Campaign]" or (quest.isLocalStory and " [Local Story]" or "")
            row.text:SetText(string.format("%s  %s%s", status, quest.name, badge))
            row:Show()
        else
            row:Hide()
        end
    end
end

local function Refresh()
    local previousMapID = state.mapID
    state.mapID = CurrentMapID()
    state.selected = nil

    if state.mapID ~= previousMapID then
        state.requestedQuestLinesFor = nil
    end

    if not state.mapID then
        zoneText:SetText("Current zone unavailable")
        state.quests = {}
        UpdateRows()
        return
    end

    RequestQuestLines(state.mapID)

    local mapInfo = C_Map.GetMapInfo(state.mapID)
    zoneText:SetText((mapInfo and mapInfo.name or "Unknown Zone") .. "  •  unfinished quests")

    state.quests = CollectQuests(state.mapID)
    UpdateRows()

    if #state.quests == 0 then
        targetText:SetText("No unfinished quests found yet; older quests may need database coverage")
        arrow:SetText("•")
    elseif DB.autoTrack then
        SetWaypointForQuest(state.quests[1])
    else
        targetText:SetText(string.format("%d unfinished quest%s found", #state.quests, #state.quests == 1 and "" or "s"))
        arrow:SetText("↑")
    end
end

local arrows = { "↑", "↗", "→", "↘", "↓", "↙", "←", "↖" }
local function UpdateArrow()
    local quest = state.selected
    if not quest then
        return
    end

    targetText:SetText(quest.name)

    if quest.accepted or not quest.x or not quest.y or not state.mapID then
        arrow:SetText("↑")
        return
    end

    local px, py = PlayerPosition(state.mapID)
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not px or not py or not facing then
        arrow:SetText("↑")
        return
    end

    local dx = quest.x - px
    local dy = quest.y - py
    local targetAngle = atan2(dx, -dy)
    local relative = targetAngle - facing
    while relative < 0 do relative = relative + (2 * pi) end
    while relative >= (2 * pi) do relative = relative - (2 * pi) end

    local sector = floor((relative + (pi / 8)) / (pi / 4)) % 8
    arrow:SetText(arrows[sector + 1])
end

local elapsedSinceArrow = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceArrow = elapsedSinceArrow + elapsed
    if elapsedSinceArrow >= 0.12 then
        elapsedSinceArrow = 0
        UpdateArrow()
    end
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
        DB = ZoneQuestGuideDB
        if DB.autoTrack == nil then
            DB.autoTrack = true
        end
        autoButton:SetChecked(DB.autoTrack)
        if DB.position then
            frame:ClearAllPoints()
            frame:SetPoint(DB.position.point or "CENTER", UIParent, DB.position.relativePoint or "CENTER", DB.position.x or 0, DB.position.y or 0)
        end
        if DB.hidden then
            frame:Hide()
        end
        return
    end

    if event == "GOSSIP_SHOW" then
        CaptureGossipQuests()
        C_Timer.After(0.05, Refresh)
        return
    end

    if event == "QUEST_DETAIL" then
        CaptureQuestDetail()
        C_Timer.After(0.05, Refresh)
        return
    end

    if event == "QUESTLINE_UPDATE" and arg1 == true and state.mapID then
        RequestQuestLines(state.mapID, true)
    end

    if event == "QUEST_LOG_UPDATE" then
        local now = GetTime()
        if now - state.lastRefresh < 0.5 then
            return
        end
        state.lastRefresh = now
    end

    C_Timer.After(0.15, Refresh)
end)

SLASH_ZONEQUESTGUIDE1 = "/aq"
SLASH_ZONEQUESTGUIDE2 = "/azerothquesting"
SLASH_ZONEQUESTGUIDE3 = "/zq"
SLASH_ZONEQUESTGUIDE4 = "/zonequest"
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "refresh" then
        state.requestedQuestLinesFor = nil
        Refresh()
        Print("Refreshed.")
    elseif msg == "auto" then
        DB.autoTrack = not DB.autoTrack
        autoButton:SetChecked(DB.autoTrack)
        Print("Auto-point is " .. (DB.autoTrack and "ON" or "OFF") .. ".")
        Refresh()
    elseif msg == "show" then
        frame:Show()
        DB.hidden = false
        Refresh()
    elseif msg == "hide" then
        frame:Hide()
        DB.hidden = true
    else
        if frame:IsShown() then
            frame:Hide()
            DB.hidden = true
        else
            frame:Show()
            DB.hidden = false
            Refresh()
        end
    end
end

ZQG.Refresh = Refresh
ZQG.SetWaypointForQuest = SetWaypointForQuest
