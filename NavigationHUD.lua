local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
if not mainFrame then
    return
end

local pi = math.pi
local atan2 = math.atan2
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

local function GetDB()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    return ZoneQuestGuideDB
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function IsOnTaxi()
    return UnitOnTaxi and UnitOnTaxi("player") and true or false
end

local selectedQuest
local selectedMapID
local currentAngle = 0
local lastAngleValid = false
local wasOnTaxi = IsOnTaxi()

-- ---------------------------------------------------------------------------
-- Floating navigation HUD
-- ---------------------------------------------------------------------------
-- This intentionally draws the arrow with Line regions instead of Unicode
-- glyphs or an external texture. That keeps the shape independent of the WoW
-- font and lets it rotate smoothly toward the selected destination.

local hud = CreateFrame("Frame", "ZoneQuestGuideNavigationHUD", UIParent)
hud:SetSize(360, 140)
hud:SetPoint("TOP", UIParent, "TOP", 0, -92)
hud:SetFrameStrata("HIGH")
hud:SetClampedToScreen(true)
hud:EnableMouse(true)
hud:SetMovable(true)
hud:RegisterForDrag("LeftButton")
hud:Hide()

-- Keep the HUD visually light like a guide arrow instead of a large panel.
-- A faint backing remains so white objective text stays readable over bright zones.
local background = hud:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetTexture("Interface\\Buttons\\WHITE8X8")
background:SetVertexColor(0, 0, 0, 0.10)

local statusText = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusText:SetPoint("TOP", hud, "TOP", -20, -2)
statusText:SetWidth(260)
statusText:SetJustifyH("CENTER")
statusText:SetShadowColor(0, 0, 0, 1)
statusText:SetShadowOffset(1, -1)

local mapText = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
mapText:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -8, -3)
mapText:SetWidth(80)
mapText:SetJustifyH("RIGHT")
mapText:SetShadowColor(0, 0, 0, 1)
mapText:SetShadowOffset(1, -1)

local function UpdateMapText()
    local mapID = CurrentMapID()
    if mapID then
        mapText:SetText("Map ID " .. tostring(mapID))
    else
        mapText:SetText("Map ID ?")
    end
end

-- Use Blizzard's minimap arrow texture as a filled, high-contrast navigation
-- arrow. This is much closer to the compact guide-arrow presentation players
-- expect than the previous large boxed tracker.
local arrowShadow = hud:CreateTexture(nil, "ARTWORK")
arrowShadow:SetSize(76, 76)
arrowShadow:SetPoint("CENTER", hud, "CENTER", 0, 15)
arrowShadow:SetTexture("Interface\\Minimap\\MinimapArrow")
arrowShadow:SetVertexColor(0, 0, 0, 0.90)

local arrowTexture = hud:CreateTexture(nil, "OVERLAY")
arrowTexture:SetSize(66, 66)
arrowTexture:SetPoint("CENTER", hud, "CENTER", 0, 15)
arrowTexture:SetTexture("Interface\\Minimap\\MinimapArrow")
arrowTexture:SetVertexColor(0.35, 1.00, 0.08, 1)

local targetText = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
targetText:SetPoint("TOP", hud, "CENTER", 0, -22)
targetText:SetWidth(350)
targetText:SetJustifyH("CENTER")
targetText:SetWordWrap(false)
targetText:SetShadowColor(0, 0, 0, 1)
targetText:SetShadowOffset(1, -1)

local detailText = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
detailText:SetPoint("TOP", targetText, "BOTTOM", 0, -3)
detailText:SetWidth(350)
detailText:SetJustifyH("CENTER")
detailText:SetShadowColor(0, 0, 0, 1)
detailText:SetShadowOffset(1, -1)

local function SetArrowVisible(visible)
    if visible then
        arrowShadow:Show()
        arrowTexture:Show()
    else
        arrowShadow:Hide()
        arrowTexture:Hide()
    end
end

local function DrawArrow(angle)
    if type(angle) ~= "number" then
        SetArrowVisible(false)
        return
    end

    -- Blizzard's MinimapArrow texture points opposite our zero-angle guide
    -- convention, so rotate it by 180 degrees while preserving left/right turn.
    local textureAngle = pi - angle
    arrowShadow:SetRotation(textureAngle)
    arrowTexture:SetRotation(textureAngle)
    SetArrowVisible(true)
end

local function GetStatusText(quest)
    local batchTotal = quest and tonumber(quest.guidePickupBatchTotal) or nil
    local batchRemaining = quest and tonumber(quest.guidePickupBatchRemaining) or nil
    if batchTotal and batchTotal > 1 then
        if batchRemaining and batchRemaining < batchTotal then
            if batchRemaining == 1 then
                return "|cffffff66PICK UP 1 MORE QUEST|r"
            end
            return string.format("|cffffff66PICK UP %d MORE QUESTS|r", batchRemaining)
        end
        return string.format("|cffffff66PICK UP %d QUESTS|r", batchTotal)
    end

    if ZQG.GetQuestStatusText then
        return ZQG.GetQuestStatusText(quest)
    end

    return quest and quest.accepted
        and "|cff66ff66IN PROGRESS|r"
        or "|cffffff66AVAILABLE|r"
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

local function FirstObjectiveText(questID)
    if not questID or not C_QuestLog or not C_QuestLog.GetQuestObjectives then
        return nil
    end

    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" then
        return nil
    end

    local first
    for _, objective in ipairs(objectives) do
        local text = AccessibleString(objective and objective.text)
        if text and text ~= "" then
            first = first or text
            if not objective.finished then
                return text
            end
        end
    end
    return first
end

local function GetTargetLabel(quest)
    if not quest then
        return ""
    end

    local questName = quest.name or ("Quest " .. tostring(quest.id or ""))
    local status = ZQG.GetQuestStatusKey and ZQG.GetQuestStatusKey(quest)
        or (quest.accepted and "progress" or "available")

    if status == "available" then
        return "Pick up " .. questName
    elseif status == "turnin" then
        return "Turn in " .. questName
    end

    local objective = FirstObjectiveText(quest.id)
    if objective then
        return objective
    end

    local hint = quest.id and ZQG.LocationHints and ZQG.LocationHints[quest.id] or nil
    if hint and hint.short then
        return questName .. "  |cffffcc00[" .. hint.short .. "]|r"
    end
    return questName
end

local function GetRelativeAngle(quest, mapID)
    if not quest or not quest.x or not quest.y or not mapID
        or not C_Map or not C_Map.GetPlayerMapPosition or not GetPlayerFacing then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    local facing = GetPlayerFacing()
    if not pos or not facing then
        return nil
    end

    local px, py = pos:GetXY()
    if not px or not py or (px == 0 and py == 0) then
        return nil
    end

    local dx = quest.x - px
    local dy = quest.y - py
    local targetAngle = atan2(dx, -dy)
    local relative = targetAngle - facing

    while relative > pi do
        relative = relative - (2 * pi)
    end
    while relative < -pi do
        relative = relative + (2 * pi)
    end

    return relative
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

local function GetDistanceYards(quest, mapID)
    if not quest or not quest.x or not quest.y or not mapID
        or not C_Map or not C_Map.GetPlayerMapPosition
        or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then
        return nil
    end

    local playerMapPos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not playerMapPos then
        return nil
    end

    local questMapPos = CreateVector2D(quest.x, quest.y)

    local playerOK, playerContinent, playerWorld = pcall(
        C_Map.GetWorldPosFromMapPos,
        mapID,
        playerMapPos
    )
    local questOK, questContinent, questWorld = pcall(
        C_Map.GetWorldPosFromMapPos,
        mapID,
        questMapPos
    )

    if not playerOK or not questOK or not playerWorld or not questWorld then
        return nil
    end
    if playerContinent and questContinent and playerContinent ~= questContinent then
        return nil
    end

    local px, py = GetWorldXY(playerWorld)
    local qx, qy = GetWorldXY(questWorld)
    if not px or not py or not qx or not qy then
        return nil
    end

    local dx = qx - px
    local dy = qy - py
    return sqrt((dx * dx) + (dy * dy))
end

local function FormatDistance(distance)
    if not distance then
        return nil
    end

    if distance >= 1000 then
        return string.format("%.1fk yd", distance / 1000)
    end

    return string.format("%d yd", math.floor(distance + 0.5))
end

local function UpdateDetailText()
    if not selectedQuest then
        detailText:SetText("")
        return
    end

    if IsOnTaxi() and selectedMapID and CurrentMapID() ~= selectedMapID then
        detailText:SetText("|cffffcc00Flight path - holding quest target|r")
        return
    end

    -- Do not derive an ETA from GetUnitSpeed(). Retail can expose movement
    -- speed as a secret value, so the HUD intentionally shows safe map-based
    -- distance only rather than risking taint for a timer.
    local distance = GetDistanceYards(selectedQuest, selectedMapID)
    local distanceText = FormatDistance(distance)
    local questName = selectedQuest.name or ("Quest " .. tostring(selectedQuest.id or ""))

    local batchTotal = tonumber(selectedQuest.guidePickupBatchTotal)
    if batchTotal and batchTotal > 1 then
        local batchIndex = tonumber(selectedQuest.guidePickupBatchIndex) or 1
        local pickupText = string.format("%d of %d pickups", batchIndex, batchTotal)
        local nextName = selectedQuest.guidePickupNextName
        local nextText = nextName and (" • Next: " .. nextName) or ""
        if distanceText then
            detailText:SetText(distanceText .. "  |cffb8b8b8• " .. pickupText .. nextText .. "|r")
        else
            detailText:SetText("|cffb8b8b8" .. pickupText .. nextText .. "|r")
        end
        return
    end

    if distanceText then
        detailText:SetText(distanceText .. "  |cffb8b8b8• " .. questName .. "|r")
    elseif selectedQuest.accepted then
        detailText:SetText("|cffb8b8b8" .. questName .. " • Tracked by WoW|r")
    else
        detailText:SetText("|cffb8b8b8" .. questName .. "|r")
    end
end

local function ApplyHUDVisibility()
    local DB = GetDB()
    if DB.showNavigationHUD == false or not selectedQuest then
        hud:Hide()
    else
        hud:Show()
    end
end

local function SelectHUDTarget(quest, mapID)
    if not quest then
        selectedQuest = nil
        selectedMapID = nil
        lastAngleValid = false
        ApplyHUDVisibility()
        return
    end

    selectedQuest = quest
    selectedMapID = mapID or CurrentMapID()
    statusText:SetText(GetStatusText(quest))
    targetText:SetText(GetTargetLabel(quest))
    UpdateMapText()
    UpdateDetailText()
    ApplyHUDVisibility()
end

-- ---------------------------------------------------------------------------
-- Flight-path target hold
-- ---------------------------------------------------------------------------
-- WoW fires zone changes while a taxi crosses intermediate maps. Core.lua may
-- briefly rebuild its zone list during those flyovers. Keep the navigation HUD
-- and the addon-owned destination on the last stable quest until the taxi ends,
-- so crossing a zone such as Deadwind Pass does not steal the go-to marker.

local function RestoreStableWaypoint()
    local quest = selectedQuest
    local mapID = selectedMapID
    if not quest or not mapID then
        return
    end

    if quest.accepted then
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
            pcall(C_SuperTrack.SetSuperTrackedQuestID, quest.id)
        end
        return
    end

    if not quest.x or not quest.y or not C_Map or not C_Map.SetUserWaypoint
        or not UiMapPoint or not UiMapPoint.CreateFromCoordinates then
        return
    end

    local point = UiMapPoint.CreateFromCoordinates(mapID, quest.x, quest.y)
    local ok = pcall(C_Map.SetUserWaypoint, point)
    if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
end

local function HoldingTaxiTarget()
    return IsOnTaxi()
        and selectedQuest ~= nil
        and selectedMapID ~= nil
        and CurrentMapID() ~= selectedMapID
end

local originalSetWaypointForQuest = ZQG.SetWaypointForQuest
if originalSetWaypointForQuest then
    ZQG.SetWaypointForQuest = function(quest, ...)
        if HoldingTaxiTarget() then
            C_Timer.After(0, RestoreStableWaypoint)
            return true
        end

        local result = originalSetWaypointForQuest(quest, ...)
        if quest then
            SelectHUDTarget(quest, CurrentMapID())
        end
        return result
    end
end

-- Core's original row click uses its private waypoint function, so also capture
-- row clicks here to keep the floating HUD synchronized with manual selection.
local function HookQuestRows()
    for _, child in ipairs({ mainFrame:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button"
            and child.text and child.text.SetText
            and not child.ZQGNavigationHUDHooked then
            local width, height = child:GetSize()
            if math.abs((width or 0) - 330) < 1 and math.abs((height or 0) - 25) < 1 then
                child.ZQGNavigationHUDHooked = true
                child:HookScript("OnClick", function(self)
                    if not self.quest or HoldingTaxiTarget() then
                        if HoldingTaxiTarget() then
                            C_Timer.After(0, RestoreStableWaypoint)
                        end
                        return
                    end
                    SelectHUDTarget(self.quest, CurrentMapID())
                end)
            end
        end
    end
end

HookQuestRows()
mainFrame:HookScript("OnShow", HookQuestRows)

local navEvents = CreateFrame("Frame")
navEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
navEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
navEvents:RegisterEvent("ZONE_CHANGED")
navEvents:RegisterEvent("QUEST_ACCEPTED")
navEvents:RegisterEvent("QUEST_TURNED_IN")
navEvents:SetScript("OnEvent", function(_, event)
    if (event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED") and HoldingTaxiTarget() then
        C_Timer.After(0.25, RestoreStableWaypoint)
        return
    end

    if event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" then
        C_Timer.After(0.35, function()
            if ZQG.Refresh and not IsOnTaxi() then
                ZQG.Refresh()
            end
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- HUD movement / updates / commands
-- ---------------------------------------------------------------------------

local function SaveHUDPosition()
    local point, _, relativePoint, x, y = hud:GetPoint(1)
    GetDB().navigationHUDPosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function ResetHUDPosition()
    hud:ClearAllPoints()
    hud:SetPoint("TOP", UIParent, "TOP", 0, -92)
    GetDB().navigationHUDPosition = nil
end

hud:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown and IsShiftKeyDown() then
        self:StartMoving()
    end
end)

hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveHUDPosition()
end)

hud:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Azeroth Questing Navigation")
    GameTooltip:AddLine("Shift-drag: Move arrow", 1, 1, 1)
    GameTooltip:AddLine("/zq arrow: Show or hide", 1, 1, 1)
    GameTooltip:Show()
end)

hud:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local updateElapsed = 0
hud:SetScript("OnUpdate", function(_, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < 0.04 then
        return
    end

    local dt = updateElapsed
    updateElapsed = 0

    local taxi = IsOnTaxi()
    if wasOnTaxi and not taxi then
        -- Once the flight ends, let all of the existing zone/quest modules
        -- rebuild for the zone where the player actually landed.
        C_Timer.After(0.25, function()
            if ZQG.Refresh then
                ZQG.Refresh()
            end
        end)
    end
    wasOnTaxi = taxi

    UpdateMapText()

    if not selectedQuest then
        return
    end

    statusText:SetText(GetStatusText(selectedQuest))
    targetText:SetText(GetTargetLabel(selectedQuest))
    UpdateDetailText()

    if HoldingTaxiTarget() then
        if lastAngleValid then
            DrawArrow(currentAngle)
        end
        return
    end

    local targetAngle = GetRelativeAngle(selectedQuest, selectedMapID)
    if targetAngle == nil then
        lastAngleValid = false
        DrawArrow(nil)
        return
    end

    if not lastAngleValid then
        currentAngle = targetAngle
        lastAngleValid = true
    else
        local diff = targetAngle - currentAngle
        while diff > pi do diff = diff - (2 * pi) end
        while diff < -pi do diff = diff + (2 * pi) end

        local smoothing = math.min(1, dt * 9)
        currentAngle = currentAngle + (diff * smoothing)
    end

    DrawArrow(currentAngle)
end)

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    local DB = GetDB()
    if DB.showNavigationHUD == nil then
        DB.showNavigationHUD = true
    end

    if DB.navigationHUDPosition then
        local p = DB.navigationHUDPosition
        hud:ClearAllPoints()
        hud:SetPoint(
            p.point or "TOP",
            UIParent,
            p.relativePoint or "TOP",
            p.x or 0,
            p.y or -92
        )
    end

    UpdateMapText()
    ApplyHUDVisibility()
    self:UnregisterEvent("ADDON_LOADED")
end)

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")
    local DB = GetDB()

    if command == "arrow" then
        DB.showNavigationHUD = not (DB.showNavigationHUD ~= false)
        ApplyHUDVisibility()
        Print("Navigation arrow is " .. (DB.showNavigationHUD and "ON" or "OFF") .. ".")
        return
    elseif command == "arrow reset" then
        ResetHUDPosition()
        DB.showNavigationHUD = true
        ApplyHUDVisibility()
        Print("Navigation arrow position reset.")
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end