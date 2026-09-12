local _, ZQG = ...

local hud = _G.ZoneQuestGuideNavigationHUD
if not hud then
    return
end

local currentQuest
local statusText

local function FindStatusText()
    for _, region in ipairs({ hud:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" and region.GetPoint then
            local point, relativeTo, relativePoint, _, y = region:GetPoint(1)
            if point == "TOP" and relativeTo == hud and relativePoint == "TOP"
                and math.abs((y or 0) + 2) <= 2 then
                return region
            end
        end
    end
    return nil
end

statusText = FindStatusText()

local progressText = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
progressText:SetPoint("BOTTOM", hud, "BOTTOM", 0, 2)
progressText:SetWidth(350)
progressText:SetJustifyH("CENTER")
progressText:SetShadowColor(0, 0, 0, 1)
progressText:SetShadowOffset(1, -1)
progressText:Hide()

local originalSetWaypointForQuest = ZQG.SetWaypointForQuest
if originalSetWaypointForQuest then
    ZQG.SetWaypointForQuest = function(quest, ...)
        currentQuest = quest
        return originalSetWaypointForQuest(quest, ...)
    end
end

local function HubStatus(quest)
    local total = tonumber(quest and quest.guideHubTotal) or 0
    local remaining = tonumber(quest and quest.guideHubRemaining) or 0
    local pickups = tonumber(quest and quest.guideHubPickupRemaining) or 0
    local turnins = tonumber(quest and quest.guideHubTurninRemaining) or 0

    if total < 2 or remaining < 1 then
        return nil
    end

    if pickups > 0 and turnins == 0 then
        if remaining == total then
            return string.format("|cffffff66PICK UP %d QUESTS|r", remaining)
        elseif remaining == 1 then
            return "|cffffff66PICK UP 1 MORE QUEST|r"
        end
        return string.format("|cffffff66PICK UP %d MORE QUESTS|r", remaining)
    end

    if turnins > 0 and pickups == 0 then
        if remaining == 1 then
            return "|cffffa500TURN IN 1 QUEST|r"
        end
        return string.format("|cffffa500TURN IN %d QUESTS|r", remaining)
    end

    if remaining == 1 then
        return "|cffffff66QUEST HUB - 1 ACTION LEFT|r"
    end
    return string.format("|cffffff66QUEST HUB - %d ACTIONS|r", remaining)
end

local function HubProgress(quest)
    local total = tonumber(quest and quest.guideHubTotal) or 0
    local remaining = tonumber(quest and quest.guideHubRemaining) or 0
    if total < 2 or remaining < 1 then
        return nil
    end

    local index = tonumber(quest.guideHubIndex) or math.max(1, total - remaining + 1)
    local text = string.format("%d of %d hub actions", index, total)
    local nextName = quest.guideHubNextName
    local nextAction = quest.guideHubNextAction
    if nextName and nextName ~= "" then
        text = text .. "  |cffb8b8b8- Next: " .. (nextAction or "Go to") .. " " .. nextName .. "|r"
    end
    return text
end

hud:HookScript("OnUpdate", function()
    local quest = currentQuest
    if ZQG.GuideHubActive == false or not quest then
        progressText:Hide()
        return
    end

    local status = HubStatus(quest)
    local progress = HubProgress(quest)

    if status and statusText then
        statusText:SetText(status)
    end

    if progress then
        progressText:SetText(progress)
        progressText:Show()
    else
        progressText:SetText("")
        progressText:Hide()
    end
end)
