local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
if not mainFrame then
    return
end

local function GetHint(questID)
    return questID and ZQG.LocationHints and ZQG.LocationHints[questID] or nil
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

local targetText
for _, region in ipairs({ mainFrame:GetRegions() }) do
    if region.GetObjectType and region:GetObjectType() == "FontString"
        and region:GetText() == "No quest selected" then
        targetText = region
        break
    end
end

local function GetStatusText(quest)
    if ZQG.GetQuestStatusText then
        return ZQG.GetQuestStatusText(quest)
    end

    return quest.accepted
        and "|cff66ff66IN PROGRESS|r"
        or "|cffffff66AVAILABLE|r"
end

local function FormatQuestRow(row)
    local quest = row.quest
    if not quest then
        return
    end

    local status = GetStatusText(quest)
    local badge = quest.isCampaign and " [Campaign]"
        or (quest.isLocalStory and " [Local Story]" or "")
    local hint = GetHint(quest.id)
    local locationBadge = hint and hint.short
        and ("  |cffffcc00[" .. hint.short .. "]|r")
        or ""

    row.text:SetText(string.format("%s  %s%s%s", status, quest.name, badge, locationBadge))
end

local function ShowQuestHintTooltip(row)
    local quest = row.quest
    local hint = quest and GetHint(quest.id) or nil
    if not hint then
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    GameTooltip:AddLine(quest.name)
    if hint.short then
        GameTooltip:AddLine(hint.short, 1, 0.82, 0)
    end
    if hint.text then
        GameTooltip:AddLine(hint.text, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local cachedRows = {}
local function ApplyLocationHints()
    cachedRows = GetQuestRows()

    for _, row in ipairs(cachedRows) do
        if row.quest then
            FormatQuestRow(row)

            if not row.ZQGLocationHintHooked then
                row.ZQGLocationHintHooked = true

                row:HookScript("OnEnter", function(self)
                    ShowQuestHintTooltip(self)
                end)

                row:HookScript("OnLeave", function(self)
                    if GameTooltip:IsOwned(self) then
                        GameTooltip:Hide()
                    end
                end)
            end
        end
    end
end

-- Core.lua refreshes the selected quest name frequently while updating the
-- direction arrow. Add the location badge after Core has written the name so a
-- vertical-level warning remains visible on the current target. Use the cached
-- row list and a short throttle so this does not rescan the UI every frame.
if targetText then
    local hintElapsed = 0
    mainFrame:HookScript("OnUpdate", function(_, elapsed)
        hintElapsed = hintElapsed + elapsed
        if hintElapsed < 0.12 then
            return
        end
        hintElapsed = 0

        local current = targetText:GetText()
        if not current or current == "" then
            return
        end

        for _, row in ipairs(cachedRows) do
            local quest = row.quest
            local hint = quest and GetHint(quest.id) or nil
            if hint and hint.short and current == quest.name then
                targetText:SetText(quest.name .. "  |cffffcc00[" .. hint.short .. "]|r")
                return
            end
        end
    end)
end

local scheduled = false
local function ScheduleLocationHintRefresh()
    if scheduled then
        return
    end

    scheduled = true
    C_Timer.After(0.35, function()
        scheduled = false
        ApplyLocationHints()
    end)
end

local hintEvents = CreateFrame("Frame")
hintEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
hintEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
hintEvents:RegisterEvent("ZONE_CHANGED")
hintEvents:RegisterEvent("QUEST_ACCEPTED")
hintEvents:RegisterEvent("QUEST_REMOVED")
hintEvents:RegisterEvent("QUEST_TURNED_IN")
hintEvents:RegisterEvent("QUEST_LOG_UPDATE")
hintEvents:RegisterEvent("QUESTLINE_UPDATE")
hintEvents:RegisterEvent("GOSSIP_SHOW")
hintEvents:RegisterEvent("QUEST_DETAIL")
hintEvents:SetScript("OnEvent", ScheduleLocationHintRefresh)

mainFrame:HookScript("OnShow", ScheduleLocationHintRefresh)
ScheduleLocationHintRefresh()
