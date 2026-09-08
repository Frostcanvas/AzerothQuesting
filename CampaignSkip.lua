local ADDON_NAME, ZQG = ...

local MIN_LEVEL = 90
local shownThisSession = false

local function GetDB()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    return ZoneQuestGuideDB
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function PlayerLevel()
    if not UnitLevel then
        return 0
    end

    local ok, level = pcall(UnitLevel, "player")
    if ok and type(level) == "number" then
        return level
    end
    return 0
end

local frame = CreateFrame("Frame", "AzerothQuestingCampaignSkipReminder", UIParent, "BackdropTemplate")
frame:SetSize(500, 220)
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
title:SetText("Level 90 campaign skip")

local message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
message:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
message:SetWidth(462)
message:SetJustifyH("LEFT")
message:SetText(
    "If this is an alt and you already completed the Midnight leveling campaign on another character, "
    .. "you can skip the remaining campaign at level 90.\n\n"
    .. "Go to Wayfarer's Rest in Silvermoon and talk to Soridormi. The skip is offered through her dialogue; "
    .. "it may not have a quest marker."
)

local gotIt = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
gotIt:SetSize(110, 26)
gotIt:SetPoint("BOTTOMLEFT", 18, 18)
gotIt:SetText("Got it")
gotIt:SetScript("OnClick", function()
    frame:Hide()
end)

local neverAgain = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
neverAgain:SetSize(150, 26)
neverAgain:SetPoint("LEFT", gotIt, "RIGHT", 10, 0)
neverAgain:SetText("Don't show again")
neverAgain:SetScript("OnClick", function()
    GetDB().campaignSkipReminderDisabled = true
    frame:Hide()
    Print("Level 90 campaign-skip reminder disabled. Use /aq skipreminder to enable it again.")
end)

local function ShowReminder(force)
    local DB = GetDB()
    if not force and DB.campaignSkipReminderDisabled then
        return false
    end
    if not force and shownThisSession then
        return false
    end
    if PlayerLevel() < MIN_LEVEL then
        return false
    end

    shownThisSession = true
    frame:Show()
    return true
end

local function MaybeShowReminder()
    if PlayerLevel() < MIN_LEVEL then
        return
    end

    C_Timer.After(2.5, function()
        ShowReminder(false)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, level)
    if event == "PLAYER_LEVEL_UP" and type(level) == "number" and level < MIN_LEVEL then
        return
    end
    MaybeShowReminder()
end)

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "skipreminder" or command == "campaignskip" then
        local DB = GetDB()
        DB.campaignSkipReminderDisabled = not DB.campaignSkipReminderDisabled
        if DB.campaignSkipReminderDisabled then
            frame:Hide()
            Print("Level 90 campaign-skip reminder is OFF.")
        else
            shownThisSession = false
            Print("Level 90 campaign-skip reminder is ON.")
            ShowReminder(true)
        end
        return
    elseif command == "skipreminder show" or command == "campaignskip show" then
        ShowReminder(true)
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.ShowCampaignSkipReminder = function()
    return ShowReminder(true)
end
