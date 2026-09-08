local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame

if not mainFrame then
    return
end

local function GetDB()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    return ZoneQuestGuideDB
end

-- ---------------------------------------------------------------------------
-- Reliable navigation arrow
-- ---------------------------------------------------------------------------
-- Core.lua keeps the current direction in a FontString. Some WoW fonts do not
-- contain the Unicode arrow glyphs, which makes them render as a square box.
-- Keep that FontString as the direction source, hide its glyph, and draw the
-- direction with a normal WoW texture instead.

local directionText
for _, region in ipairs({ mainFrame:GetRegions() }) do
    if region.GetObjectType and region:GetObjectType() == "FontString" then
        local text = region:GetText()
        if text == "↑" then
            directionText = region
            break
        end
    end
end

if directionText then
    local directionTexture = mainFrame:CreateTexture(nil, "OVERLAY")
    directionTexture:SetSize(34, 34)
    directionTexture:SetPoint("CENTER", directionText, "CENTER", 0, 0)
    directionTexture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")

    -- The source texture points to the right. Rotate it to match Core.lua's
    -- eight direction states.
    local rotations = {
        ["↑"] = -math.pi / 2,
        ["↗"] = -math.pi / 4,
        ["→"] = 0,
        ["↘"] = math.pi / 4,
        ["↓"] = math.pi / 2,
        ["↙"] = 3 * math.pi / 4,
        ["←"] = math.pi,
        ["↖"] = -3 * math.pi / 4,
    }

    directionText:SetAlpha(0)

    local function UpdateDirectionTexture()
        local text = directionText:GetText()
        local rotation = rotations[text]

        if rotation then
            directionTexture:SetRotation(rotation)
            directionTexture:Show()
        else
            directionTexture:Hide()
        end
    end

    UpdateDirectionTexture()
    mainFrame:HookScript("OnUpdate", UpdateDirectionTexture)
end

-- ---------------------------------------------------------------------------
-- Quest-starter waypoint cleanup
-- ---------------------------------------------------------------------------
-- Available quests use a normal Blizzard user waypoint so the player can see
-- the quest giver on the map. Once that quest is accepted, Blizzard's quest
-- tracking should take over and the temporary starter waypoint is no longer
-- useful. Only clear the waypoint when it still matches the accepted quest's
-- displayed coordinates, so an unrelated waypoint placed by the player is
-- left alone whenever the client exposes enough waypoint information to check.

local function FindDisplayedQuest(questID)
    if not questID then
        return nil
    end

    for _, child in ipairs({ mainFrame:GetChildren() }) do
        local quest = child.quest
        if quest and quest.id == questID then
            return quest
        end
    end

    return nil
end

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

local function WaypointMatchesQuest(quest)
    if not quest or not quest.x or not quest.y then
        return true
    end

    if not C_Map or not C_Map.GetUserWaypoint then
        return true
    end

    local ok, point = pcall(C_Map.GetUserWaypoint)
    if not ok or not point then
        return false
    end

    local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    if point.uiMapID and mapID and point.uiMapID ~= mapID then
        return false
    end

    local x, y = GetWaypointXY(point)
    if not x or not y then
        return true
    end

    local dx = x - quest.x
    local dy = y - quest.y
    return (dx * dx + dy * dy) <= 0.00000625
end

local function ClearAcceptedQuestStarterWaypoint(questID)
    local quest = FindDisplayedQuest(questID)
    if not quest or quest.accepted or not WaypointMatchesQuest(quest) then
        return
    end

    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
    end

    if C_Map and C_Map.ClearUserWaypoint then
        pcall(C_Map.ClearUserWaypoint)
    end
end

local waypointEvents = CreateFrame("Frame")
waypointEvents:RegisterEvent("QUEST_ACCEPTED")
waypointEvents:SetScript("OnEvent", function(_, _, questLogIndex, questID)
    if type(questID) ~= "number" or questID <= 0 then
        if type(questLogIndex) == "number" and C_QuestLog and C_QuestLog.GetInfo then
            local info = C_QuestLog.GetInfo(questLogIndex)
            questID = info and info.questID or nil
        end
    end

    if questID then
        ClearAcceptedQuestStarterWaypoint(questID)
    end
end)

-- ---------------------------------------------------------------------------
-- Minimap button
-- ---------------------------------------------------------------------------

local minimapButton = CreateFrame("Button", "ZoneQuestGuideMinimapButton", Minimap)
minimapButton:SetSize(31, 31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:Hide()

local background = minimapButton:CreateTexture(nil, "BACKGROUND")
background:SetSize(20, 20)
background:SetPoint("CENTER", 0, 1)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetVertexColor(0.1, 0.1, 0.1, 0.65)

local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")

local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapPosition()
    if not Minimap then
        return
    end

    local DB = GetDB()
    local radius = (math.max(Minimap:GetWidth(), Minimap:GetHeight()) / 2) + 8
    local angle = math.rad(DB.minimapAngle or 225)

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angle) * radius,
        math.sin(angle) * radius
    )
end

local function UpdateMinimapVisibility()
    local DB = GetDB()

    if DB.showMinimapIcon == false then
        minimapButton:Hide()
    else
        UpdateMinimapPosition()
        minimapButton:Show()
    end
end

local function InitializeMinimapButton()
    local DB = GetDB()

    if DB.showMinimapIcon == nil then
        DB.showMinimapIcon = true
    end
    if DB.minimapAngle == nil then
        DB.minimapAngle = 225
    end

    UpdateMinimapVisibility()
end

minimapButton:SetScript("OnClick", function(_, button)
    local DB = GetDB()

    if button == "RightButton" then
        if ZQG.Refresh then
            ZQG.Refresh()
        end
        return
    end

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

minimapButton:SetScript("OnDragStart", function(self)
    if not IsShiftKeyDown() then
        return
    end

    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        if not mx or not my then
            return
        end

        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cursorX = cursorX / scale
        cursorY = cursorY / scale

        local DB = GetDB()
        DB.minimapAngle = math.deg(math.atan2(cursorY - my, cursorX - mx))
        UpdateMinimapPosition()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Azeroth Questing")
    GameTooltip:AddLine("Left-click: Show or hide", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Refresh quests", 1, 1, 1)
    GameTooltip:AddLine("Shift-drag: Move around the minimap", 1, 1, 1)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local initEvents = CreateFrame("Frame")
initEvents:RegisterEvent("ADDON_LOADED")
initEvents:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    InitializeMinimapButton()
    self:UnregisterEvent("ADDON_LOADED")
end)

-- Extend the existing /zq command without replacing any of Core.lua's normal
-- commands.
local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "minimap" then
        local DB = GetDB()
        DB.showMinimapIcon = not DB.showMinimapIcon
        UpdateMinimapVisibility()
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff66ccffAzeroth Questing:|r Minimap icon is "
                .. (DB.showMinimapIcon and "ON" or "OFF")
                .. "."
        )
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end
