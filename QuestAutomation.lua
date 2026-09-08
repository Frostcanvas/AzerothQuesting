local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
if not mainFrame then
    return
end

local function GetDB()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    return ZoneQuestGuideDB
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function AutomationBypassed()
    return IsShiftKeyDown and IsShiftKeyDown()
end

local breadcrumbLockoutsByLaterQuest = {}
for breadcrumbID, rules in pairs(ZQG.QuestAvailabilityRules or {}) do
    for _, laterQuestID in ipairs(rules.skippedBy or {}) do
        breadcrumbLockoutsByLaterQuest[laterQuestID] = breadcrumbLockoutsByLaterQuest[laterQuestID] or {}
        breadcrumbLockoutsByLaterQuest[laterQuestID][#breadcrumbLockoutsByLaterQuest[laterQuestID] + 1] = breadcrumbID
    end
end

local function QuestCompleted(questID)
    if not questID or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
        return false
    end

    local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and completed and true or false
end

local function QuestActive(questID)
    if not questID or not C_QuestLog or not C_QuestLog.IsOnQuest then
        return false
    end

    local ok, active = pcall(C_QuestLog.IsOnQuest, questID)
    return ok and active and true or false
end

local function FirstUnfinishedBreadcrumb(laterQuestID)
    for _, breadcrumbID in ipairs(breadcrumbLockoutsByLaterQuest[laterQuestID] or {}) do
        if not QuestCompleted(breadcrumbID) and not QuestActive(breadcrumbID) then
            return breadcrumbID
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Quest destination waypoint ownership / refresh
-- ---------------------------------------------------------------------------
-- Azeroth Questing uses Blizzard user waypoints for unaccepted quests. Keep
-- track of the waypoint we created so changing the selected AVAILABLE quest
-- replaces the old destination instead of leaving a stale minimap/world-map
-- marker behind.

local ownedWaypoint = {
    questID = nil,
    mapID = nil,
    x = nil,
    y = nil,
}

local function GetWaypointXY(point)
    if not point then
        return nil, nil
    end

    local position = point.position
    if position then
        if position.GetXY then
            return position:GetXY()
        end
        if position.x and position.y then
            return position.x, position.y
        end
    end

    if point.GetXY then
        return point:GetXY()
    end

    return point.x, point.y
end

local function CurrentWaypointMatchesOwned()
    if not ownedWaypoint.questID then
        return false
    end

    if not C_Map or not C_Map.GetUserWaypoint then
        return true
    end

    local ok, point = pcall(C_Map.GetUserWaypoint)
    if not ok or not point then
        return false
    end

    if point.uiMapID and ownedWaypoint.mapID
        and point.uiMapID ~= ownedWaypoint.mapID then
        return false
    end

    local x, y = GetWaypointXY(point)
    if not x or not y or not ownedWaypoint.x or not ownedWaypoint.y then
        return true
    end

    local dx = x - ownedWaypoint.x
    local dy = y - ownedWaypoint.y
    return (dx * dx + dy * dy) <= 0.00000625
end

local function ForgetOwnedWaypoint()
    ownedWaypoint.questID = nil
    ownedWaypoint.mapID = nil
    ownedWaypoint.x = nil
    ownedWaypoint.y = nil
end

local function ClearOwnedWaypoint()
    if not ownedWaypoint.questID then
        return
    end

    if CurrentWaypointMatchesOwned() then
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
        end

        if C_Map and C_Map.ClearUserWaypoint then
            pcall(C_Map.ClearUserWaypoint)
        end
    end

    ForgetOwnedWaypoint()
end

local function ManagedSetWaypointForQuest(quest)
    if not quest then
        return false
    end

    -- Accepted quests should use Blizzard quest super-tracking. Remove any
    -- Azeroth Questing starter waypoint first so the minimap does not keep
    -- pointing at the old quest giver.
    if quest.accepted then
        ClearOwnedWaypoint()

        if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
            local ok = pcall(C_SuperTrack.SetSuperTrackedQuestID, quest.id)
            return ok
        end

        return false
    end

    -- A new AVAILABLE target replaces the previous Azeroth Questing waypoint.
    -- If the new target has no coordinates, clearing the old marker is still
    -- preferable to leaving the minimap pointing at the wrong quest.
    ClearOwnedWaypoint()

    local mapID = C_Map and C_Map.GetBestMapForUnit
        and C_Map.GetBestMapForUnit("player") or nil

    if not quest.x or not quest.y or not mapID
        or not C_Map or not C_Map.SetUserWaypoint
        or not UiMapPoint or not UiMapPoint.CreateFromCoordinates then
        return false
    end

    local point = UiMapPoint.CreateFromCoordinates(mapID, quest.x, quest.y)
    local ok = pcall(C_Map.SetUserWaypoint, point)
    if not ok then
        return false
    end

    ownedWaypoint.questID = quest.id
    ownedWaypoint.mapID = mapID
    ownedWaypoint.x = quest.x
    ownedWaypoint.y = quest.y

    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end

    return true
end

-- QuestPriority.lua calls the exported function, so replace it with the managed
-- version. Core.lua's row buttons use their original local function, therefore
-- we also hook those buttons below and immediately re-apply the managed target.
ZQG.SetWaypointForQuest = ManagedSetWaypointForQuest

local function HookQuestRows()
    for _, child in ipairs({ mainFrame:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button"
            and not child.ZQGWaypointRefreshHooked then
            child.ZQGWaypointRefreshHooked = true
            child:HookScript("OnClick", function(self)
                if self.quest then
                    C_Timer.After(0, function()
                        ManagedSetWaypointForQuest(self.quest)
                    end)
                end
            end)
        end
    end
end

HookQuestRows()
mainFrame:HookScript("OnShow", HookQuestRows)

local waypointEvents = CreateFrame("Frame")
waypointEvents:RegisterEvent("QUEST_ACCEPTED")
waypointEvents:RegisterEvent("QUEST_TURNED_IN")
waypointEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
waypointEvents:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "QUEST_ACCEPTED" then
        local questID = arg2
        if type(questID) ~= "number" or questID <= 0 then
            if type(arg1) == "number" and C_QuestLog and C_QuestLog.GetInfo then
                local info = C_QuestLog.GetInfo(arg1)
                questID = info and info.questID or nil
            end
        end

        if questID and ownedWaypoint.questID == questID then
            ClearOwnedWaypoint()
        end
    elseif event == "QUEST_TURNED_IN" then
        if arg1 and ownedWaypoint.questID == arg1 then
            ClearOwnedWaypoint()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- A waypoint created for a previous zone should not survive as our
        -- active destination when the player changes maps.
        ClearOwnedWaypoint()
    end
end)

-- ---------------------------------------------------------------------------
-- Optional quest automation
-- ---------------------------------------------------------------------------
-- Both settings default OFF. Holding Shift while interacting with an NPC
-- temporarily bypasses automation so the player can read or handle a quest
-- manually without changing the saved settings.

local optionsFrame = CreateFrame("Frame", "ZoneQuestGuideAutomationFrame", UIParent, "BackdropTemplate")
optionsFrame:SetSize(330, 205)
optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
optionsFrame:SetFrameStrata("DIALOG")
optionsFrame:SetClampedToScreen(true)
optionsFrame:EnableMouse(true)
optionsFrame:SetMovable(true)
optionsFrame:RegisterForDrag("LeftButton")
optionsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
optionsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
optionsFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
optionsFrame:Hide()

local optionsTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
optionsTitle:SetPoint("TOPLEFT", 16, -14)
optionsTitle:SetText("Azeroth Questing Options")

local optionsClose = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
optionsClose:SetPoint("TOPRIGHT", -3, -3)

local autoAccept = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
autoAccept:SetPoint("TOPLEFT", 14, -48)
autoAccept.text = autoAccept:CreateFontString(nil, "OVERLAY", "GameFontNormal")
autoAccept.text:SetPoint("LEFT", autoAccept, "RIGHT", 2, 1)
autoAccept.text:SetText("Auto accept quests")
autoAccept:SetScript("OnClick", function(self)
    GetDB().autoAcceptQuests = self:GetChecked() and true or false
end)

local autoTurnIn = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
autoTurnIn:SetPoint("TOPLEFT", 14, -78)
autoTurnIn.text = autoTurnIn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
autoTurnIn.text:SetPoint("LEFT", autoTurnIn, "RIGHT", 2, 1)
autoTurnIn.text:SetText("Auto turn in completed quests")
autoTurnIn:SetScript("OnClick", function(self)
    GetDB().autoTurnInQuests = self:GetChecked() and true or false
end)

local automationNote = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
automationNote:SetPoint("TOPLEFT", 18, -116)
automationNote:SetWidth(294)
automationNote:SetJustifyH("LEFT")
automationNote:SetText(
    "Hold Shift while interacting with an NPC to temporarily bypass quest automation. "
    .. "Reward choices and quests that may skip an unfinished breadcrumb are left open for manual confirmation."
)

local function SyncOptions()
    local DB = GetDB()
    if DB.autoAcceptQuests == nil then
        DB.autoAcceptQuests = false
    end
    if DB.autoTurnInQuests == nil then
        DB.autoTurnInQuests = false
    end

    autoAccept:SetChecked(DB.autoAcceptQuests)
    autoTurnIn:SetChecked(DB.autoTurnInQuests)
end

local function ToggleOptions(forceShow)
    SyncOptions()

    if forceShow == true then
        optionsFrame:Show()
    elseif forceShow == false then
        optionsFrame:Hide()
    elseif optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        optionsFrame:Show()
    end
end

local optionsButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
optionsButton:SetSize(62, 18)
optionsButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -28, -34)
optionsButton:SetText("Options")
optionsButton:SetScript("OnClick", function()
    ToggleOptions()
end)

local function SelectNextGossipQuest()
    if AutomationBypassed() then
        return
    end

    local DB = GetDB()

    -- Turn-ins first, then pick up new quests from the same NPC.
    if DB.autoTurnInQuests and C_GossipInfo and C_GossipInfo.GetActiveQuests
        and C_GossipInfo.SelectActiveQuest then
        local ok, active = pcall(C_GossipInfo.GetActiveQuests)
        if ok and type(active) == "table" then
            for _, info in ipairs(active) do
                if info.questID and info.isComplete then
                    pcall(C_GossipInfo.SelectActiveQuest, info.questID)
                    return
                end
            end
        end
    end

    if DB.autoAcceptQuests and C_GossipInfo and C_GossipInfo.GetAvailableQuests
        and C_GossipInfo.SelectAvailableQuest then
        local ok, available = pcall(C_GossipInfo.GetAvailableQuests)
        if ok and type(available) == "table" then
            local availableByID = {}
            for _, info in ipairs(available) do
                if info.questID then
                    availableByID[info.questID] = info
                end
            end

            -- If this NPC currently offers both a breadcrumb and the later quest
            -- that can skip it, explicitly open the breadcrumb first.
            for _, info in ipairs(available) do
                local laterQuestID = info.questID
                for _, breadcrumbID in ipairs(breadcrumbLockoutsByLaterQuest[laterQuestID] or {}) do
                    local breadcrumb = availableByID[breadcrumbID]
                    if breadcrumb and not QuestCompleted(breadcrumbID) and not QuestActive(breadcrumbID) then
                        pcall(C_GossipInfo.SelectAvailableQuest, breadcrumbID)
                        return
                    end
                end
            end

            -- Otherwise prefer a quest that does not currently threaten an
            -- unfinished breadcrumb. Risky quests remain available manually.
            for _, info in ipairs(available) do
                if info.questID and not FirstUnfinishedBreadcrumb(info.questID) then
                    pcall(C_GossipInfo.SelectAvailableQuest, info.questID)
                    return
                end
            end

            -- If every option is a potential lockout, open the first one so the
            -- detail page and warning are visible, but QUEST_DETAIL below will
            -- deliberately refuse to auto-accept it.
            for _, info in ipairs(available) do
                if info.questID then
                    pcall(C_GossipInfo.SelectAvailableQuest, info.questID)
                    return
                end
            end
        end
    end
end

local automationEvents = CreateFrame("Frame")
automationEvents:RegisterEvent("ADDON_LOADED")
automationEvents:RegisterEvent("GOSSIP_SHOW")
automationEvents:RegisterEvent("QUEST_DETAIL")
automationEvents:RegisterEvent("QUEST_PROGRESS")
automationEvents:RegisterEvent("QUEST_COMPLETE")
automationEvents:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then
            return
        end
        SyncOptions()
        return
    end

    if AutomationBypassed() then
        return
    end

    local DB = GetDB()

    if event == "GOSSIP_SHOW" then
        C_Timer.After(0.05, SelectNextGossipQuest)
        return
    end

    if event == "QUEST_DETAIL" and DB.autoAcceptQuests then
        local questID = GetQuestID and GetQuestID() or nil
        local breadcrumbID = FirstUnfinishedBreadcrumb(questID)
        if breadcrumbID then
            Print("Auto accept paused: quest " .. tostring(questID)
                .. " may skip unfinished breadcrumb quest " .. tostring(breadcrumbID)
                .. ". Accept it manually only if you want to continue without that breadcrumb.")
            return
        end

        if AcceptQuest then
            C_Timer.After(0.05, function()
                if not AutomationBypassed() and GetDB().autoAcceptQuests then
                    pcall(AcceptQuest)
                end
            end)
        end
        return
    end

    if event == "QUEST_PROGRESS" and DB.autoTurnInQuests then
        if IsQuestCompletable and CompleteQuest and IsQuestCompletable() then
            C_Timer.After(0.05, function()
                if not AutomationBypassed() and GetDB().autoTurnInQuests then
                    pcall(CompleteQuest)
                end
            end)
        end
        return
    end

    if event == "QUEST_COMPLETE" and DB.autoTurnInQuests then
        local choices = GetNumQuestChoices and GetNumQuestChoices() or 0

        if choices and choices > 1 then
            Print("This quest has multiple reward choices. Choose a reward to finish the turn-in.")
            return
        end

        if GetQuestReward then
            C_Timer.After(0.05, function()
                if not AutomationBypassed() and GetDB().autoTurnInQuests then
                    pcall(GetQuestReward, 1)
                end
            end)
        end
    end
end)

-- Extend the current slash handler with automation settings without replacing
-- any existing Azeroth Questing commands.
local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")
    local DB = GetDB()

    if command == "options" then
        ToggleOptions()
        return
    elseif command == "autoaccept" then
        DB.autoAcceptQuests = not DB.autoAcceptQuests
        SyncOptions()
        Print("Auto accept is " .. (DB.autoAcceptQuests and "ON" or "OFF") .. ".")
        return
    elseif command == "autoturnin" or command == "autocomplete" then
        DB.autoTurnInQuests = not DB.autoTurnInQuests
        SyncOptions()
        Print("Auto turn-in is " .. (DB.autoTurnInQuests and "ON" or "OFF") .. ".")
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end
