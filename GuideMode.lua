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

local function AccessibleString(value)
    if value == nil then
        return nil
    end
    if canaccessvalue and not canaccessvalue(value) then
        return nil
    end
    if type(value) ~= "string" then
        return nil
    end
    return value
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

local function ViewName()
    return GetDB().questFrequencyView == "repeatable" and "Daily / Weekly" or "Zone Quests"
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

local function QuestStatusText(quest)
    if ZQG.GetQuestStatusText then
        local ok, text = pcall(ZQG.GetQuestStatusText, quest)
        if ok and text then
            return text
        end
    end
    return quest and quest.accepted
        and "|cff66ff66IN PROGRESS|r"
        or "|cffffff66AVAILABLE|r"
end

local function QuestFrequencyBadge(quest)
    if ZQG.GetQuestFrequencyBadge then
        local ok, text = pcall(ZQG.GetQuestFrequencyBadge, quest)
        if ok and text then
            return text
        end
    end
    return ""
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

local function ObjectiveLines(questID)
    if not C_QuestLog or not C_QuestLog.GetQuestObjectives then
        return nil
    end

    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" then
        return nil
    end

    local lines = {}
    for _, objective in ipairs(objectives) do
        local text = AccessibleString(objective and objective.text)
        if text and text ~= "" then
            lines[#lines + 1] = (objective.finished and "|cff66ff66✓|r " or "• ") .. text
            if #lines >= 4 then
                break
            end
        end
    end

    return #lines > 0 and lines or nil
end

local function BuildInstruction(quest)
    local status = QuestStatusKey(quest)
    if status == "available" then
        return "Pick up this quest."
    elseif status == "turnin" then
        return "|cffffcc00Quest complete.|r Return to the quest giver and turn it in."
    end

    local lines = ObjectiveLines(quest.id)
    if lines then
        return table.concat(lines, "\n")
    end
    return "Complete this quest's objectives."
end

local frame = CreateFrame("Frame", "AzerothQuestingGuideModeFrame", UIParent, "BackdropTemplate")
frame:SetSize(410, 260)
frame:SetPoint("RIGHT", UIParent, "RIGHT", -42, 70)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -14)
title:SetText("Azeroth Questing Guide")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -3, -3)
close:SetScript("OnClick", function()
    GetDB().guideModeEnabled = false
    frame:Hide()
end)

local stepText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stepText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
stepText:SetWidth(250)
stepText:SetJustifyH("LEFT")

local viewButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
viewButton:SetSize(132, 23)
viewButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -40)

local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("TOPLEFT", stepText, "BOTTOMLEFT", 0, -16)
statusText:SetWidth(360)
statusText:SetJustifyH("LEFT")

local questText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
questText:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -6)
questText:SetWidth(376)
questText:SetJustifyH("LEFT")
questText:SetWordWrap(true)

local instructionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
instructionText:SetPoint("TOPLEFT", questText, "BOTTOMLEFT", 0, -10)
instructionText:SetWidth(376)
instructionText:SetHeight(86)
instructionText:SetJustifyH("LEFT")
instructionText:SetJustifyV("TOP")
instructionText:SetWordWrap(true)

local backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
backButton:SetSize(78, 24)
backButton:SetPoint("BOTTOMLEFT", 16, 18)
backButton:SetText("< Back")

local nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
nextButton:SetSize(78, 24)
nextButton:SetPoint("LEFT", backButton, "RIGHT", 8, 0)
nextButton:SetText("Next >")

local listButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
listButton:SetSize(96, 24)
listButton:SetPoint("LEFT", nextButton, "RIGHT", 8, 0)
listButton:SetText("Quest List")

local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
note:SetPoint("BOTTOMRIGHT", -14, 23)
note:SetWidth(110)
note:SetJustifyH("RIGHT")
note:SetText("/aq guide")

frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    GetDB().guideModePosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end)

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
    local DB = GetDB()
    if DB.guideModeEnabled == false then
        frame:Hide()
        return
    end

    frame:Show()

    local quests = GetGuideQuests()
    local view = ViewName()
    viewButton:SetText(DB.questFrequencyView == "repeatable" and "Show Zone Quests" or "Show Daily / Weekly")

    if #quests == 0 then
        currentQuestID = nil
        currentIndex = 1
        lastWaypointKey = nil
        stepText:SetText(view .. "  •  no steps")
        statusText:SetText("|cffaaaaaaNO UNFINISHED QUESTS|r")
        questText:SetText("You're caught up in this tab")
        instructionText:SetText("Switch tabs or move to another questing area to continue.")
        backButton:Disable()
        nextButton:Disable()
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
    currentQuestID = quest.id
    stepText:SetText(string.format("%s  •  Step %d of %d", view, currentIndex, #quests))
    statusText:SetText(QuestStatusText(quest))

    local badge = QuestFrequencyBadge(quest)
    if quest.isCampaign then
        badge = badge .. " [Campaign]"
    elseif quest.isLocalStory then
        badge = badge .. " [Local Story]"
    end
    questText:SetText((quest.name or ("Quest " .. tostring(quest.id or ""))) .. badge)
    instructionText:SetText(BuildInstruction(quest))

    if currentIndex > 1 then backButton:Enable() else backButton:Disable() end
    if currentIndex < #quests then nextButton:Enable() else nextButton:Disable() end

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

backButton:SetScript("OnClick", function()
    local quests = GetGuideQuests()
    if #quests > 0 then
        SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) - 1, quests, true)
        UpdateGuide(true)
    end
end)

nextButton:SetScript("OnClick", function()
    local quests = GetGuideQuests()
    if #quests > 0 then
        SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) + 1, quests, true)
        UpdateGuide(true)
    end
end)

listButton:SetScript("OnClick", function()
    local DB = GetDB()
    if mainFrame:IsShown() then
        mainFrame:Hide()
        DB.hidden = true
    else
        mainFrame:Show()
        DB.hidden = false
        if ZQG.Refresh then
            ZQG.Refresh()
        end
    end
end)

viewButton:SetScript("OnClick", function()
    local DB = GetDB()
    DB.questFrequencyView = DB.questFrequencyView == "repeatable" and "zone" or "repeatable"
    currentQuestID = nil
    currentIndex = 1
    lastWaypointKey = nil
    if ZQG.Refresh then
        ZQG.Refresh()
    end
    ScheduleGuideUpdate(true)
end)

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
        if DB.guideModePosition then
            frame:ClearAllPoints()
            frame:SetPoint(
                DB.guideModePosition.point or "RIGHT",
                UIParent,
                DB.guideModePosition.relativePoint or "RIGHT",
                DB.guideModePosition.x or -42,
                DB.guideModePosition.y or 70
            )
        end
        HookQuestRows()
        ScheduleGuideUpdate(true)
        return
    end

    ScheduleGuideUpdate(event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN")
end)

function ZQG.ShowGuideMode()
    GetDB().guideModeEnabled = true
    frame:Show()
    HookQuestRows()
    ScheduleGuideUpdate(true)
end

function ZQG.HideGuideMode()
    GetDB().guideModeEnabled = false
    frame:Hide()
end

function ZQG.ToggleGuideMode()
    if frame:IsShown() then
        ZQG.HideGuideMode()
    else
        ZQG.ShowGuideMode()
    end
end

function ZQG.GuideNext()
    nextButton:Click()
end

function ZQG.GuideBack()
    backButton:Click()
end

local previousSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "guide" then
        ZQG.ToggleGuideMode()
        return
    elseif command == "guide on" or command == "guide show" then
        ZQG.ShowGuideMode()
        return
    elseif command == "guide off" or command == "guide hide" then
        ZQG.HideGuideMode()
        return
    elseif command == "guide next" then
        ZQG.GuideNext()
        return
    elseif command == "guide back" or command == "guide previous" then
        ZQG.GuideBack()
        return
    end

    if previousSlashHandler then
        previousSlashHandler(msg)
    end
end

HookQuestRows()
ScheduleGuideUpdate(false)
