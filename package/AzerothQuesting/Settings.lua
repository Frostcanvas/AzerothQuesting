local ADDON_NAME, ZQG = ...

local PREFIX = "AZQUEST"
local PROTOCOL_VERSION = 1
local PEER_ACTIVE_WINDOW = 90
local MAX_SETTINGS_PEER_ROWS = 14
local MAX_SETTINGS_REGISTRATION_RETRIES = 10

local VALID_NETWORK_CHANNELS = {
    CHANNEL = true,
    PARTY = true,
    RAID = true,
    INSTANCE_CHAT = true,
    GUILD = true,
}

local sessionPeers = {}
local settingsPanel = nil
local settingsRows = {}
local settingsRegistrationRetryCount = 0
local settingsRegistrationRetryScheduled = false

local EnsureSettingsRegistration

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

local function AddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, version = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
        if ok and version and version ~= "" then
            return version
        end
    elseif GetAddOnMetadata then
        local ok, version = pcall(GetAddOnMetadata, ADDON_NAME, "Version")
        if ok and version and version ~= "" then
            return version
        end
    end
    return "unknown"
end

local function SenderIsPlayer(sender)
    sender = AccessibleString(sender)
    if not sender or not UnitName then
        return false
    end

    local ok, playerName = pcall(UnitName, "player")
    playerName = ok and AccessibleString(playerName) or nil
    if not playerName then
        return false
    end

    local senderBase = sender:match("^([^-]+)") or sender
    return senderBase == playerName
end

local function ParseHelloVersion(text)
    local kind, protocol, version = text:match("^(H)|([^|]+)|([^|]+)$")
    if kind ~= "H" or tonumber(protocol) ~= PROTOCOL_VERSION then
        return nil
    end

    if #version > 40 then
        version = version:sub(1, 40)
    end
    return version
end

local function NotePeer(sender, addonVersion)
    local now = GetTime and GetTime() or 0
    local peer = sessionPeers[sender]
    if not peer then
        peer = {
            name = sender,
            lastSeen = now,
            addonVersion = "unknown",
        }
        sessionPeers[sender] = peer
    end

    peer.lastSeen = now
    if addonVersion and addonVersion ~= "" then
        peer.addonVersion = addonVersion
    end
end

local function ActivePeers(now)
    now = now or (GetTime and GetTime() or 0)
    local peers = {}

    for _, peer in pairs(sessionPeers) do
        if peer.lastSeen and now - peer.lastSeen <= PEER_ACTIVE_WINDOW then
            peers[#peers + 1] = peer
        end
    end

    table.sort(peers, function(a, b)
        if a.lastSeen ~= b.lastSeen then
            return (a.lastSeen or 0) > (b.lastSeen or 0)
        end
        return (a.name or "") < (b.name or "")
    end)

    return peers
end

local function FormatAge(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds < 5 then
        return "now"
    elseif seconds < 60 then
        return tostring(seconds) .. "s ago"
    end
    return tostring(math.floor(seconds / 60)) .. "m ago"
end

local function RefreshSettingsPanel()
    if not settingsPanel or not settingsPanel:IsShown() then
        return
    end

    local now = GetTime and GetTime() or 0
    local peers = ActivePeers(now)
    local count = #peers

    settingsPanel.connectedCount:SetText(string.format(
        "Connected now: %d player%s",
        count,
        count == 1 and "" or "s"
    ))

    for index = 1, MAX_SETTINGS_PEER_ROWS do
        local row = settingsRows[index]
        local peer = peers[index]
        if peer then
            row.player:SetText(peer.name or "unknown")
            row.version:SetText(peer.addonVersion or "unknown")
            row.lastSeen:SetText(FormatAge(now - (peer.lastSeen or now)))
            row.frame:Show()
        elseif index == 1 and count == 0 then
            row.player:SetText("|cff888888No connected Azeroth Questing players detected yet.|r")
            row.version:SetText("")
            row.lastSeen:SetText("")
            row.frame:Show()
        else
            row.frame:Hide()
        end
    end

    if count > MAX_SETTINGS_PEER_ROWS then
        settingsPanel.listNote:SetText(
            "Showing the " .. tostring(MAX_SETTINGS_PEER_ROWS) .. " most recently heard connected players."
        )
    else
        settingsPanel.listNote:SetText("")
    end
end

local function SettingsAPIReady()
    return Settings
        and Settings.RegisterCanvasLayoutCategory
        and Settings.RegisterAddOnCategory
end

local function CreateSettingsPanel()
    if settingsPanel then
        return settingsPanel
    end

    if not SettingsAPIReady() then
        return nil
    end

    local panel = CreateFrame("Frame", "AzerothQuestingSettingsPanel")
    panel.name = "Azeroth Questing"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Azeroth Questing")

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 10, 0)
    version:SetText("v" .. AddonVersion())

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetPoint("TOPRIGHT", -24, -8)
    description:SetJustifyH("LEFT")
    description:SetText("Live Azeroth Questing Network status for this WoW session.")

    local section = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    section:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -24)
    section:SetText("Connected Players")

    panel.connectedCount = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.connectedCount:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 0, -6)
    panel.connectedCount:SetText("Connected now: 0 players")

    local explanation = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    explanation:SetPoint("TOPLEFT", panel.connectedCount, "BOTTOMLEFT", 0, -4)
    explanation:SetPoint("TOPRIGHT", -24, -4)
    explanation:SetJustifyH("LEFT")
    explanation:SetText("A player is considered connected after this client hears AZQUEST traffic from them within the last 90 seconds through the custom channel or a shared party, raid, instance, or guild transport.")

    local headers = {
        { text = "Player", x = 16, width = 250 },
        { text = "Addon Version", x = 278, width = 150 },
        { text = "Last Seen", x = 440, width = 120 },
    }
    for _, header in ipairs(headers) do
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", header.x, -134)
        label:SetWidth(header.width)
        label:SetJustifyH("LEFT")
        label:SetText(header.text)
    end

    for index = 1, MAX_SETTINGS_PEER_ROWS do
        local rowFrame = CreateFrame("Frame", nil, panel)
        rowFrame:SetSize(560, 20)
        rowFrame:SetPoint("TOPLEFT", 16, -154 - ((index - 1) * 21))

        local player = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        player:SetPoint("LEFT", 0, 0)
        player:SetWidth(250)
        player:SetJustifyH("LEFT")

        local addonVersion = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        addonVersion:SetPoint("LEFT", 262, 0)
        addonVersion:SetWidth(150)
        addonVersion:SetJustifyH("LEFT")

        local lastSeen = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lastSeen:SetPoint("LEFT", 424, 0)
        lastSeen:SetWidth(120)
        lastSeen:SetJustifyH("LEFT")

        settingsRows[index] = {
            frame = rowFrame,
            player = player,
            version = addonVersion,
            lastSeen = lastSeen,
        }
    end

    panel.listNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    panel.listNote:SetPoint("TOPLEFT", 16, -458)
    panel.listNote:SetPoint("TOPRIGHT", -24, -458)
    panel.listNote:SetJustifyH("LEFT")

    local privacy = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    privacy:SetPoint("TOPLEFT", panel.listNote, "BOTTOMLEFT", 0, -8)
    privacy:SetPoint("TOPRIGHT", -24, -8)
    privacy:SetJustifyH("LEFT")
    privacy:SetText("Player names in this list are session-only. They are not saved to SavedVariables or uploaded to the Azeroth Questing Server.")

    local detailsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    detailsButton:SetSize(150, 24)
    detailsButton:SetPoint("TOPLEFT", privacy, "BOTTOMLEFT", 0, -16)
    detailsButton:SetText("P2P Details")
    detailsButton:SetScript("OnClick", function()
        if ZQG.ShowAzerothNetworkPeers then
            ZQG.ShowAzerothNetworkPeers()
        end
    end)

    panel:SetScript("OnShow", function(self)
        self.refreshElapsed = 0
        RefreshSettingsPanel()
    end)
    panel:SetScript("OnUpdate", function(self, elapsed)
        self.refreshElapsed = (self.refreshElapsed or 0) + elapsed
        if self.refreshElapsed >= 1 then
            self.refreshElapsed = 0
            RefreshSettingsPanel()
        end
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)

    settingsPanel = panel
    settingsRegistrationRetryScheduled = false
    ZQG.AzerothQuestingSettingsCategory = category

    return panel
end

local function ScheduleSettingsRegistrationRetry()
    if settingsPanel
        or settingsRegistrationRetryScheduled
        or settingsRegistrationRetryCount >= MAX_SETTINGS_REGISTRATION_RETRIES
        or not C_Timer
        or not C_Timer.After
    then
        return
    end

    settingsRegistrationRetryScheduled = true
    settingsRegistrationRetryCount = settingsRegistrationRetryCount + 1
    C_Timer.After(1, function()
        settingsRegistrationRetryScheduled = false
        EnsureSettingsRegistration()
    end)
end

EnsureSettingsRegistration = function()
    if settingsPanel then
        return settingsPanel
    end

    local panel = CreateSettingsPanel()
    if not panel then
        ScheduleSettingsRegistrationRetry()
    end
    return panel
end

local function OnAddonMessage(prefix, text, channel, sender)
    prefix = AccessibleString(prefix)
    text = AccessibleString(text)
    channel = AccessibleString(channel)
    sender = AccessibleString(sender)

    if prefix ~= PREFIX or not VALID_NETWORK_CHANNELS[channel] or not text or not sender then
        return
    end
    if SenderIsPlayer(sender) then
        return
    end

    NotePeer(sender, ParseHelloVersion(text))
    RefreshSettingsPanel()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME
            or addonName == "Blizzard_Settings"
            or addonName == "Blizzard_Settings_Shared"
        then
            EnsureSettingsRegistration()
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureSettingsRegistration()
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    end
end)

-- Blizzard's current Settings implementation guide recommends registering addon
-- settings from ContinueOnAddOnLoaded. Keep the event/login retries above as a
-- fallback so one early unavailable Settings API check cannot permanently hide
-- the category for the rest of the session.
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded(ADDON_NAME, EnsureSettingsRegistration)
end

if C_Timer and C_Timer.After then
    C_Timer.After(0, EnsureSettingsRegistration)
else
    EnsureSettingsRegistration()
end
