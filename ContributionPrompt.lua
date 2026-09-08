local ADDON_NAME, ZQG = ...

-- This is intentionally a normal web page rather than an automatic uploader.
-- WoW addon Lua cannot submit the learning export to the web itself, so the
-- player is given a copyable destination after useful phase data is learned.
local DEFAULT_CONTRIBUTION_URL = "https://forms.gle/Gnqf8kN44kDZxMs86"
ZQG.ContributionURL = ZQG.ContributionURL or DEFAULT_CONTRIBUTION_URL

local promptedThisSession = {}

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

local function GetReliablePhase(mapID)
    if not mapID or not ZQG.GetTimePhaseKey then
        return nil
    end

    local phase, source = ZQG.GetTimePhaseKey(mapID)
    if not phase then
        return nil
    end

    if source ~= "zidormi" and source ~= "manual" and source ~= "detected" then
        return nil
    end

    return tostring(phase):lower()
end

local function LearnedQuestCount(mapID, faction, phase)
    local learning = ZoneQuestGuideDB and ZoneQuestGuideDB.phaseLearning
    local zone = learning and learning.zones and learning.zones[mapID] or nil
    local factionData = zone and zone.factions and zone.factions[faction] or nil
    local quests = factionData and factionData.quests or nil
    if not quests then
        return 0
    end

    local count = 0
    for _, quest in pairs(quests) do
        local phaseData = quest.phases and quest.phases[phase] or nil
        if phaseData and (phaseData.seen or 0) > 0 then
            count = count + 1
        end
    end

    return count
end

-- ---------------------------------------------------------------------------
-- Contribution window
-- ---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "ZoneQuestGuideContributionFrame", UIParent, "BackdropTemplate")
frame:SetSize(570, 260)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:Hide()

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -3, -3)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 18, -18)
title:SetText("Help improve Azeroth Questing")

local message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
message:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
message:SetWidth(530)
message:SetJustifyH("LEFT")
message:SetText(
    "Azeroth Questing has collected useful timeline/map/quest data.\n\n" ..
    "1. Run /zq export (or click Open Export below).\n" ..
    "2. Copy the anonymous learning report.\n" ..
    "3. Open the Google Form below, paste the report, and submit it."
)

local urlLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
urlLabel:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -14)
urlLabel:SetText("Google Form URL")

local urlBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
urlBox:SetSize(510, 26)
urlBox:SetPoint("TOPLEFT", urlLabel, "BOTTOMLEFT", 4, -5)
urlBox:SetAutoFocus(false)
urlBox:SetFontObject(ChatFontNormal)
urlBox:SetText(ZQG.ContributionURL)
urlBox:SetCursorPosition(0)
urlBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
urlBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)

local openExport = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
openExport:SetSize(120, 24)
openExport:SetPoint("BOTTOMLEFT", 18, 18)
openExport:SetText("Open Export")
openExport:SetScript("OnClick", function()
    frame:Hide()
    if SlashCmdList and SlashCmdList.ZONEQUESTGUIDE then
        SlashCmdList.ZONEQUESTGUIDE("export")
    end
end)

local selectURL = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
selectURL:SetSize(120, 24)
selectURL:SetPoint("LEFT", openExport, "RIGHT", 10, 0)
selectURL:SetText("Select URL")
selectURL:SetScript("OnClick", function()
    urlBox:SetFocus()
    urlBox:HighlightText()
end)

local later = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
later:SetSize(90, 24)
later:SetPoint("BOTTOMRIGHT", -18, 18)
later:SetText("Later")
later:SetScript("OnClick", function()
    frame:Hide()
end)

local function ShowContributionPrompt()
    urlBox:SetText(ZQG.ContributionURL or DEFAULT_CONTRIBUTION_URL)
    urlBox:SetCursorPosition(0)
    frame:Show()
end

local function MaybePromptAfterLearning(minimumQuestCount)
    local mapID = CurrentMapID()
    local phase = GetReliablePhase(mapID)
    if not mapID or not phase then
        return
    end

    local faction = PlayerFaction()
    local count = LearnedQuestCount(mapID, faction, phase)
    if count < (minimumQuestCount or 1) then
        return
    end

    local key = table.concat({ tostring(mapID), faction, phase }, ":")
    if promptedThisSession[key] then
        return
    end

    promptedThisSession[key] = true
    ShowContributionPrompt()
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function(_, event)
    -- PhaseLearning.lua is loaded before this file and listens to the same quest
    -- events. Wait briefly so its SavedVariables record is present before we
    -- decide whether there is anything useful to contribute.
    if event == "QUEST_TURNED_IN" then
        C_Timer.After(0.75, function()
            MaybePromptAfterLearning(1)
        end)
    elseif event == "QUEST_ACCEPTED" then
        C_Timer.After(0.75, function()
            -- Avoid prompting immediately on the very first pickup. If the player
            -- has already accumulated several phase observations, acceptance is
            -- enough to offer the contribution reminder before they leave.
            MaybePromptAfterLearning(3)
        end)
    end
end)

-- Allow the player to reopen the same contribution instructions at any time.
local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "contribute" or command == "contribution" then
        ShowContributionPrompt()
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.ShowContributionPrompt = ShowContributionPrompt