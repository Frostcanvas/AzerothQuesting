local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
local hud = _G.ZoneQuestGuideNavigationHUD
if not mainFrame or not hud then
    return
end

local FREQUENCY_NORMAL = 1

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function PlayerFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player") or "Neutral"
    end
    return "Neutral"
end

local function IsOnQuest(questID)
    if not questID or not C_QuestLog or not C_QuestLog.IsOnQuest then
        return false
    end
    local ok, active = pcall(C_QuestLog.IsOnQuest, questID)
    return ok and active and true or false
end

local function IsCompleted(questID)
    if not questID or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
        return false
    end
    local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and completed and true or false
end

local function IsFactionAllowed(faction)
    return not faction or faction == PlayerFaction()
end

local function AddKnownQuest(known, questID, hints)
    questID = tonumber(questID)
    if not questID or questID <= 0 or known[questID] then
        return
    end

    hints = hints or {}
    local quest = {
        id = questID,
        accepted = IsOnQuest(questID),
        isDaily = hints.isDaily and true or false,
        isWeekly = hints.isWeekly and true or false,
        questFrequency = hints.questFrequency,
    }

    -- Zone progress is intended to behave like guide progress, so known
    -- daily/weekly repeatables are not included in the denominator.
    if ZQG.GetQuestFrequency and ZQG.GetQuestFrequency(quest) ~= FREQUENCY_NORMAL then
        return
    end

    known[questID] = true
end

local function AddLearnedQuests(known, mapID)
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    local store = ZoneQuestGuideDB.mapQuestLearning
    local mapData = store and store.maps and store.maps[mapID]
    if not mapData or not mapData.factions then
        return
    end

    local faction = PlayerFaction()
    local function AddFactionQuests(factionData)
        for questID in pairs(factionData and factionData.quests or {}) do
            AddKnownQuest(known, questID)
        end
    end

    AddFactionQuests(mapData.factions[faction])
    if faction ~= "Neutral" then
        AddFactionQuests(mapData.factions.Neutral)
    end
end

local function AddStaticQuests(known, mapID)
    for _, info in ipairs(ZQG.StaticQuests and ZQG.StaticQuests[mapID] or {}) do
        if info and info.id and IsFactionAllowed(info.faction) then
            AddKnownQuest(known, info.id, info)
        end
    end
end

local function AddCurrentQuestLogQuests(known, mapID)
    if not C_QuestLog or not C_QuestLog.GetQuestsOnMap then
        return
    end

    local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
    if not ok or type(quests) ~= "table" then
        return
    end

    for _, info in ipairs(quests) do
        if info and info.questID then
            AddKnownQuest(known, info.questID, info)
        end
    end
end

local function AddAvailableQuestLines(known, mapID)
    if not C_QuestLine or not C_QuestLine.GetAvailableQuestLines then
        return
    end

    local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
    if not ok or type(lines) ~= "table" then
        return
    end

    for _, info in ipairs(lines) do
        if info and info.questID then
            local startMapID = info.startMapID
            if (not startMapID or startMapID == 0 or startMapID == mapID) then
                AddKnownQuest(known, info.questID, info)
            end
        end
    end
end

function ZQG.GetZoneQuestProgress(mapID)
    mapID = mapID or CurrentMapID()
    if not mapID then
        return 0, 0
    end

    local known = {}
    AddLearnedQuests(known, mapID)
    AddStaticQuests(known, mapID)
    AddCurrentQuestLogQuests(known, mapID)
    AddAvailableQuestLines(known, mapID)

    local completed, total = 0, 0
    for questID in pairs(known) do
        total = total + 1
        if IsCompleted(questID) then
            completed = completed + 1
        end
    end

    return completed, total
end

-- ---------------------------------------------------------------------------
-- Zygor-inspired presentation using only Blizzard/Azeroth Questing assets.
-- This does not copy Zygor textures or code; it mirrors the lightweight
-- floating-arrow layout visible during the user's side-by-side test.
-- ---------------------------------------------------------------------------

local background
local statusText
local mapText
local arrowShadow
local arrowTexture
local targetText
local detailText

local function DiscoverHUDRegions()
    local regions = { hud:GetRegions() }
    for _, region in ipairs(regions) do
        if region.GetObjectType then
            local objectType = region:GetObjectType()
            if objectType == "Texture" then
                local width = region:GetWidth() or 0
                local height = region:GetHeight() or 0
                if math.abs(width - 76) < 2 and math.abs(height - 76) < 2 then
                    arrowShadow = region
                elseif math.abs(width - 66) < 2 and math.abs(height - 66) < 2 then
                    arrowTexture = region
                elseif not background then
                    background = region
                end
            elseif objectType == "FontString" then
                local width = region:GetWidth() or 0
                if math.abs(width - 260) < 2 then
                    statusText = region
                elseif math.abs(width - 80) < 2 then
                    mapText = region
                elseif math.abs(width - 350) < 2 then
                    local fontObject = region.GetFontObject and region:GetFontObject() or nil
                    if fontObject == GameFontNormalLarge then
                        targetText = region
                    elseif fontObject == GameFontHighlightSmall then
                        detailText = region
                    elseif not targetText then
                        targetText = region
                    else
                        detailText = detailText or region
                    end
                end
            end
        end
    end
end

DiscoverHUDRegions()

hud:SetSize(380, 164)

if background then
    background:SetVertexColor(0, 0, 0, 0.03)
end

local textBacking = hud:CreateTexture(nil, "BACKGROUND", nil, 1)
textBacking:SetTexture("Interface\\Buttons\\WHITE8X8")
textBacking:SetVertexColor(0, 0, 0, 0.34)
textBacking:SetPoint("TOPLEFT", hud, "TOPLEFT", 24, -96)
textBacking:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -24, 4)

local aqLabel = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
aqLabel:SetPoint("TOPLEFT", hud, "TOPLEFT", 8, -3)
aqLabel:SetText("|cff66ccffAQ|r")
aqLabel:SetShadowColor(0, 0, 0, 1)
aqLabel:SetShadowOffset(1, -1)

if statusText then
    statusText:ClearAllPoints()
    statusText:SetPoint("TOP", hud, "TOP", 0, -2)
    statusText:SetWidth(250)
end

if mapText then
    mapText:ClearAllPoints()
    mapText:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -8, -3)
    mapText:SetWidth(92)
end

if arrowShadow then
    arrowShadow:ClearAllPoints()
    arrowShadow:SetSize(96, 96)
    arrowShadow:SetPoint("TOP", hud, "TOP", 0, -12)
    arrowShadow:SetVertexColor(0, 0, 0, 0.92)
end

if arrowTexture then
    arrowTexture:ClearAllPoints()
    arrowTexture:SetSize(84, 84)
    arrowTexture:SetPoint("TOP", hud, "TOP", 0, -18)
    arrowTexture:SetVertexColor(0.28, 1.00, 0.05, 1)
end

if targetText then
    targetText:ClearAllPoints()
    targetText:SetPoint("TOP", hud, "TOP", 0, -101)
    targetText:SetWidth(350)
    targetText:SetFontObject(GameFontNormal)
    targetText:SetShadowColor(0, 0, 0, 1)
    targetText:SetShadowOffset(1, -1)
end

if detailText then
    detailText:ClearAllPoints()
    detailText:SetPoint("TOP", hud, "TOP", 0, -121)
    detailText:SetWidth(350)
end

local progressText = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
progressText:SetPoint("TOP", hud, "TOP", 0, -140)
progressText:SetWidth(350)
progressText:SetJustifyH("CENTER")
progressText:SetShadowColor(0, 0, 0, 1)
progressText:SetShadowOffset(1, -1)

local mainProgressText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
mainProgressText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -132)
mainProgressText:SetWidth(330)
mainProgressText:SetJustifyH("LEFT")
mainProgressText:SetShadowColor(0, 0, 0, 1)
mainProgressText:SetShadowOffset(1, -1)

local function RefreshProgress()
    local mapID = CurrentMapID()
    local completed, total = ZQG.GetZoneQuestProgress(mapID)
    if total > 0 then
        local text = string.format("%d / %d known zone quests done", completed, total)
        progressText:SetText(text)
        mainProgressText:SetText("Zone progress: " .. text)
    else
        progressText:SetText("Zone quest total still being learned")
        mainProgressText:SetText("Zone progress: total still being learned")
    end
end

local refreshPending = false
local function ScheduleRefresh()
    if refreshPending then
        return
    end
    refreshPending = true
    C_Timer.After(0.20, function()
        refreshPending = false
        RefreshProgress()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUESTLINE_UPDATE")
events:RegisterEvent("GOSSIP_SHOW")
events:SetScript("OnEvent", ScheduleRefresh)

hud:HookScript("OnShow", ScheduleRefresh)
mainFrame:HookScript("OnShow", ScheduleRefresh)

ScheduleRefresh()
