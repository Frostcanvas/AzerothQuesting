local ADDON_NAME, ZQG = ...

local PREFIX = "AZQUEST"
local CHANNEL_NAME = "AzerothQuesting"
local PROTOCOL_VERSION = 1
local SEND_INTERVAL = 1.05
local HELLO_INTERVAL = 30
local PEER_ACTIVE_WINDOW = 90
local MAX_PENDING = 100
local MAX_PEER_ROWS = 12
local INBOUND_DEDUP_WINDOW = 10

local VALID_NETWORK_CHANNELS = {
    CHANNEL = true,
    PARTY = true,
    RAID = true,
    INSTANCE_CHAT = true,
    GUILD = true,
}

local EVIDENCE_TO_CODE = {
    available = "V",
    offered = "O",
    active = "A",
    turnedIn = "T",
}

local CODE_TO_EVIDENCE = {
    V = "available",
    O = "offered",
    A = "active",
    T = "turnedIn",
}

local FACTION_TO_CODE = {
    Alliance = "A",
    Horde = "H",
    Neutral = "N",
}

local CODE_TO_FACTION = {
    A = "Alliance",
    H = "Horde",
    N = "Neutral",
}

local pending = {}
local pendingKeys = {}
local sessionPeers = {}
local prefixRegistered = false
local channelID = 0
local sentCount = 0
local receivedCount = 0
local lastSendResult = nil
local peerPanel = nil
local peerRows = {}
local recentInbound = {}
local lastInboundPrune = 0

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
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

local function SafeToken(value, fallback)
    if canaccessvalue and value ~= nil and not canaccessvalue(value) then
        return fallback
    end
    value = tostring(value or fallback or "")
    if value:find("|", 1, true) then
        return fallback
    end
    return value
end

local function PlayerFaction()
    if UnitFactionGroup then
        local ok, faction = pcall(UnitFactionGroup, "player")
        if ok and FACTION_TO_CODE[faction] then
            return faction
        end
    end
    return "Neutral"
end

local function PlayerClass()
    if ZQG.GetPlayerClassContext then
        return ZQG.GetPlayerClassContext()
    end
    if UnitClass then
        local ok, _, classFile, classID = pcall(UnitClass, "player")
        if ok and type(classFile) == "string" and type(classID) == "number" then
            return classID, classFile
        end
    end
    return 0, "UNKNOWN"
end

local function IsCompleted(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        return ok and completed and true or false
    end
    return false
end

local function OutgoingRestricted()
    if not C_ChatInfo then
        return true
    end
    if C_ChatInfo.AreOutgoingAddonChatMessagesRestricted then
        local ok, restricted = pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
        if ok and restricted then
            return true
        end
    end
    if C_ChatInfo.InChatMessagingLockdown then
        local ok, restricted = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and restricted then
            return true
        end
    end
    return false
end

local function RefreshChannelID()
    if not GetChannelName then
        channelID = 0
        return 0
    end

    local ok, id = pcall(GetChannelName, CHANNEL_NAME)
    if ok and type(id) == "number" and id > 0 then
        channelID = id
    else
        channelID = 0
    end
    return channelID
end

local function RegisterPrefix()
    if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix then
        prefixRegistered = false
        return false
    end

    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    if not ok then
        prefixRegistered = false
        return false
    end

    -- Retail returns Success (0) or DuplicatePrefix (1). A duplicate here means
    -- this addon already registered the prefix during the current UI session.
    prefixRegistered = result == 0 or result == 1
    return prefixRegistered
end

local function JoinNetworkChannel()
    if RefreshChannelID() > 0 then
        return true
    end
    if not JoinTemporaryChannel then
        return false
    end

    -- No chat-frame ID is supplied. The custom channel is joined so it appears
    -- in the Channels UI, but addon protocol traffic is not added to normal chat.
    pcall(JoinTemporaryChannel, CHANNEL_NAME, nil, nil, false)
    C_Timer.After(1.0, RefreshChannelID)
    return true
end

local function InInstanceGroup()
    if not IsInGroup or not LE_PARTY_CATEGORY_INSTANCE then
        return false
    end
    local ok, grouped = pcall(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
    return ok and grouped and true or false
end

local function InRaid()
    if not IsInRaid then
        return false
    end
    local ok, grouped = pcall(IsInRaid)
    return ok and grouped and true or false
end

local function InGroup()
    if not IsInGroup then
        return false
    end
    local ok, grouped = pcall(IsInGroup)
    return ok and grouped and true or false
end

local function InGuild()
    if not IsInGuild then
        return false
    end
    local ok, guilded = pcall(IsInGuild)
    return ok and guilded and true or false
end

local function CurrentGroupTransport()
    if InInstanceGroup() then
        return "INSTANCE_CHAT"
    elseif InRaid() then
        return "RAID"
    elseif InGroup() then
        return "PARTY"
    end
    return nil
end

local function QueueTransport(key, message, chatType)
    local transportKey = key .. "@" .. chatType
    if pendingKeys[transportKey] then
        return false
    end
    if #pending >= MAX_PENDING then
        return false
    end
    pending[#pending + 1] = {
        key = transportKey,
        message = message,
        chatType = chatType,
        channelWaits = 0,
    }
    pendingKeys[transportKey] = true
    return true
end

local function QueueMessage(key, message)
    local queued = false
    local groupTransport = CurrentGroupTransport()

    -- Cross-faction-capable shared contexts are queued first so a
    -- throttled custom channel cannot delay party/raid/instance peers.
    if groupTransport then
        queued = QueueTransport(key, message, groupTransport) or queued
    end
    if InGuild() then
        queued = QueueTransport(key, message, "GUILD") or queued
    end

    -- Preserve the existing broad same-faction custom-channel path.
    queued = QueueTransport(key, message, "CHANNEL") or queued
    return queued
end

local function TransportAvailable(chatType)
    if chatType == "CHANNEL" then
        return RefreshChannelID() > 0
    elseif chatType == "INSTANCE_CHAT" then
        return InInstanceGroup()
    elseif chatType == "RAID" then
        return InRaid()
    elseif chatType == "PARTY" then
        return InGroup() and not InRaid() and not InInstanceGroup()
    elseif chatType == "GUILD" then
        return InGuild()
    end
    return false
end

local function SendRaw(message, chatType)
    if not prefixRegistered or OutgoingRestricted() then
        return false
    end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return false
    end

    local target = nil
    if chatType == "CHANNEL" then
        target = RefreshChannelID()
        if target <= 0 then
            JoinNetworkChannel()
            lastSendResult = 7
            return false
        end
    elseif not TransportAvailable(chatType) then
        lastSendResult = chatType == "GUILD" and 10 or 5
        return false
    end

    local ok, result
    if target then
        ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, chatType, target)
    else
        ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, chatType)
    end
    if not ok then
        lastSendResult = 9
        return false
    end

    lastSendResult = result
    if result == 0 then
        sentCount = sentCount + 1
        return true
    end
    return false
end

local function SendHello()
    QueueMessage("hello", table.concat({ "H", tostring(PROTOCOL_VERSION), SafeToken(AddonVersion(), "unknown") }, "|"))
end

local function BroadcastMapQuestEvidence(questID, evidence, mapID)
    local evidenceCode = EVIDENCE_TO_CODE[evidence]
    if not evidenceCode then
        return false
    end
    if type(questID) ~= "number" or questID <= 0 or type(mapID) ~= "number" or mapID <= 0 then
        return false
    end

    local faction = PlayerFaction()
    local classID, classFile = PlayerClass()
    local completed = IsCompleted(questID) and 1 or 0
    local key = table.concat({ questID, mapID, evidenceCode, faction, classID, classFile, completed }, ":")
    local message = table.concat({
        "Q",
        tostring(PROTOCOL_VERSION),
        tostring(questID),
        tostring(mapID),
        evidenceCode,
        FACTION_TO_CODE[faction] or "N",
        tostring(classID or 0),
        SafeToken(classFile, "UNKNOWN"),
        tostring(completed),
    }, "|")

    return QueueMessage(key, message)
end

local function DropPendingFront()
    local item = table.remove(pending, 1)
    if item then
        pendingKeys[item.key] = nil
    end
end

local function ProcessPending()
    if #pending == 0 then
        return
    end
    if OutgoingRestricted() then
        return
    end

    local item = pending[1]
    if item.chatType == "CHANNEL" and RefreshChannelID() <= 0 then
        item.channelWaits = (item.channelWaits or 0) + 1
        JoinNetworkChannel()
        if item.channelWaits >= 5 then
            DropPendingFront()
        end
        return
    end

    if not TransportAvailable(item.chatType) then
        DropPendingFront()
        return
    end

    if SendRaw(item.message, item.chatType) then
        DropPendingFront()
    elseif lastSendResult ~= 3 and lastSendResult ~= 8 and lastSendResult ~= 11 then
        -- Keep throttle/lockdown failures queued for retry. Membership,
        -- invalid-target, and other permanent failures are dropped so
        -- one stale transport cannot block later research traffic.
        DropPendingFront()
    end
end

local function ParseHello(text)
    local kind, protocol, version = text:match("^(H)|([^|]+)|([^|]+)$")
    if kind ~= "H" or tonumber(protocol) ~= PROTOCOL_VERSION then
        return nil
    end
    version = SafeToken(version, "unknown")
    if #version > 40 then
        version = version:sub(1, 40)
    end
    return version
end

local function ParseQuestMessage(text)
    local kind, protocol, questID, mapID, evidenceCode, factionCode, classID, classFile, completed =
        text:match("^(Q)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")

    if kind ~= "Q" or tonumber(protocol) ~= PROTOCOL_VERSION then
        return nil
    end

    questID = tonumber(questID)
    mapID = tonumber(mapID)
    classID = tonumber(classID)
    completed = tonumber(completed)
    local evidence = CODE_TO_EVIDENCE[evidenceCode]
    local faction = CODE_TO_FACTION[factionCode]

    if not questID or questID <= 0 or not mapID or mapID <= 0 then
        return nil
    end
    if not evidence or not faction then
        return nil
    end
    if not classID or classID < 0 or classID > 30 then
        return nil
    end
    if type(classFile) ~= "string" or classFile == "" or #classFile > 24 or not classFile:match("^[A-Z]+$") then
        return nil
    end
    if completed ~= 0 and completed ~= 1 then
        return nil
    end

    return {
        questID = questID,
        mapID = mapID,
        evidence = evidence,
        faction = faction,
        classID = classID,
        classFile = classFile,
        completed = completed == 1,
    }
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

local function NotePeer(sender, addonVersion)
    sender = AccessibleString(sender)
    if not sender or sender == "" then
        return
    end

    local now = GetTime and GetTime() or 0
    local peer = sessionPeers[sender]
    if not peer then
        peer = {
            name = sender,
            firstSeen = now,
            lastSeen = now,
            messages = 0,
            addonVersion = "unknown",
        }
        sessionPeers[sender] = peer
    end

    peer.lastSeen = now
    peer.messages = (peer.messages or 0) + 1
    if addonVersion and addonVersion ~= "" then
        peer.addonVersion = addonVersion
    end
end

local function SessionPeerCount()
    local count = 0
    for _ in pairs(sessionPeers) do
        count = count + 1
    end
    return count
end

local function ActivePeerCount(now)
    now = now or (GetTime and GetTime() or 0)
    local count = 0
    for _, peer in pairs(sessionPeers) do
        if peer.lastSeen and now - peer.lastSeen <= PEER_ACTIVE_WINDOW then
            count = count + 1
        end
    end
    return count
end

local function SortedPeers(now)
    now = now or (GetTime and GetTime() or 0)
    local peers = {}
    for _, peer in pairs(sessionPeers) do
        peers[#peers + 1] = peer
    end
    table.sort(peers, function(a, b)
        local aActive = a.lastSeen and now - a.lastSeen <= PEER_ACTIVE_WINDOW
        local bActive = b.lastSeen and now - b.lastSeen <= PEER_ACTIVE_WINDOW
        if aActive ~= bActive then
            return aActive
        end
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
    elseif seconds < 3600 then
        return tostring(math.floor(seconds / 60)) .. "m ago"
    end
    return tostring(math.floor(seconds / 3600)) .. "h ago"
end

local function ActiveTransportSummary()
    local transports = {}
    local groupTransport = CurrentGroupTransport()
    local id = RefreshChannelID()

    if groupTransport then
        transports[#transports + 1] = groupTransport
    end
    if InGuild() then
        transports[#transports + 1] = "GUILD"
    end
    if id > 0 then
        transports[#transports + 1] = "CHANNEL /" .. tostring(id)
    else
        transports[#transports + 1] = "CHANNEL pending"
    end

    return table.concat(transports, ", ")
end

local function RefreshPeerPanel()
    if not peerPanel or not peerPanel:IsShown() then
        return
    end

    local now = GetTime and GetTime() or 0
    local peers = SortedPeers(now)
    local active = ActivePeerCount(now)
    local total = #peers

    peerPanel.status:SetText(string.format(
        "AZQUEST: %s   |   Transports: %s   |   Active peers: %d   |   Seen this session: %d",
        prefixRegistered and "registered" or "not registered",
        ActiveTransportSummary(),
        active,
        total
    ))

    for index = 1, MAX_PEER_ROWS do
        local row = peerRows[index]
        local peer = peers[index]
        if peer then
            local age = math.max(0, now - (peer.lastSeen or now))
            local activeNow = age <= PEER_ACTIVE_WINDOW
            row.name:SetText(peer.name or "unknown")
            row.version:SetText(peer.addonVersion or "unknown")
            row.lastSeen:SetText((activeNow and "|cff33ff66Active|r - " or "|cffffcc33Idle|r - ") .. FormatAge(age))
            row.messages:SetText(tostring(peer.messages or 0))
            row.frame:Show()
        elseif index == 1 and total == 0 then
            row.name:SetText("|cff888888No Azeroth Questing peers detected yet.|r")
            row.version:SetText("")
            row.lastSeen:SetText("")
            row.messages:SetText("")
            row.frame:Show()
        else
            row.frame:Hide()
        end
    end

    local footer = "Session-only diagnostic: character names are kept in memory only and are never saved or uploaded."
    if total > MAX_PEER_ROWS then
        footer = footer .. " Showing the " .. tostring(MAX_PEER_ROWS) .. " most recent peers."
    end
    peerPanel.footer:SetText(footer)
end

local function CreatePeerPanel()
    if peerPanel then
        return peerPanel
    end

    local panel = CreateFrame("Frame", "AzerothQuestingPeerPanel", UIParent, "BackdropTemplate")
    panel:SetSize(620, 410)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetText("Azeroth Questing P2P Connections")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("Live AZQUEST peers heard through the custom channel or shared party, raid, instance, and guild transports.")

    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.status:SetPoint("TOPLEFT", 24, -69)
    panel.status:SetPoint("TOPRIGHT", -24, -69)
    panel.status:SetJustifyH("LEFT")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -7, -7)

    local headers = {
        { text = "Player", x = 24, width = 225 },
        { text = "Addon", x = 255, width = 120 },
        { text = "Last Seen", x = 382, width = 145 },
        { text = "Messages", x = 535, width = 65 },
    }
    for _, header in ipairs(headers) do
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", header.x, -96)
        label:SetWidth(header.width)
        label:SetJustifyH("LEFT")
        label:SetText(header.text)
    end

    for index = 1, MAX_PEER_ROWS do
        local rowFrame = CreateFrame("Frame", nil, panel)
        rowFrame:SetSize(572, 20)
        rowFrame:SetPoint("TOPLEFT", 24, -116 - ((index - 1) * 21))

        local name = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("LEFT", 0, 0)
        name:SetWidth(225)
        name:SetJustifyH("LEFT")

        local version = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        version:SetPoint("LEFT", 231, 0)
        version:SetWidth(120)
        version:SetJustifyH("LEFT")

        local lastSeen = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lastSeen:SetPoint("LEFT", 358, 0)
        lastSeen:SetWidth(145)
        lastSeen:SetJustifyH("LEFT")

        local messages = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        messages:SetPoint("LEFT", 511, 0)
        messages:SetWidth(61)
        messages:SetJustifyH("LEFT")

        peerRows[index] = {
            frame = rowFrame,
            name = name,
            version = version,
            lastSeen = lastSeen,
            messages = messages,
        }
    end

    panel.footer = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.footer:SetPoint("BOTTOMLEFT", 24, 20)
    panel.footer:SetPoint("BOTTOMRIGHT", -185, 20)
    panel.footer:SetJustifyH("LEFT")
    panel.footer:SetJustifyV("BOTTOM")

    local refreshButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshButton:SetSize(145, 24)
    refreshButton:SetPoint("BOTTOMRIGHT", -24, 18)
    refreshButton:SetText("Announce / Refresh")
    refreshButton:SetScript("OnClick", function()
        RegisterPrefix()
        JoinNetworkChannel()
        SendHello()
        RefreshPeerPanel()
    end)

    panel:SetScript("OnShow", function(self)
        self.refreshElapsed = 0
        RegisterPrefix()
        JoinNetworkChannel()
        SendHello()
        RefreshPeerPanel()
    end)
    panel:SetScript("OnUpdate", function(self, elapsed)
        self.refreshElapsed = (self.refreshElapsed or 0) + elapsed
        if self.refreshElapsed >= 1 then
            self.refreshElapsed = 0
            RefreshPeerPanel()
        end
    end)

    peerPanel = panel
    return panel
end

local function ShowPeerPanel()
    local panel = CreatePeerPanel()
    panel:Show()
    panel:Raise()
end

local function IsDuplicateInbound(sender, text)
    if not sender then
        return false
    end

    local now = GetTime and GetTime() or 0
    if now - lastInboundPrune >= 30 then
        for key, seenAt in pairs(recentInbound) do
            if now - seenAt > INBOUND_DEDUP_WINDOW then
                recentInbound[key] = nil
            end
        end
        lastInboundPrune = now
    end

    local key = sender .. "\031" .. text
    local seenAt = recentInbound[key]
    recentInbound[key] = now
    return seenAt ~= nil and now - seenAt <= INBOUND_DEDUP_WINDOW
end

local function OnAddonMessage(prefix, text, channel, sender)
    prefix = AccessibleString(prefix)
    text = AccessibleString(text)
    channel = AccessibleString(channel)
    sender = AccessibleString(sender)

    if prefix ~= PREFIX or not VALID_NETWORK_CHANNELS[channel] or not text then
        return
    end
    if sender and SenderIsPlayer(sender) then
        return
    end
    if sender and IsDuplicateInbound(sender, text) then
        return
    end

    receivedCount = receivedCount + 1
    local helloVersion = ParseHello(text)
    if sender then
        NotePeer(sender, helloVersion)
    end

    if helloVersion then
        return
    end

    local observation = ParseQuestMessage(text)
    if not observation or not ZQG.QueueCompanionQuestObservation then
        return
    end

    -- The sender name exists only in the temporary in-memory peer panel. It is
    -- deliberately not persisted. Only anonymous quest/map/faction/class/
    -- completion/evidence context enters the Companion queue.
    ZQG.QueueCompanionQuestObservation(
        observation.questID,
        observation.evidence,
        observation.mapID,
        {
            source = "peer",
            faction = observation.faction,
            classID = observation.classID,
            classFile = observation.classFile,
            completed = observation.completed,
            level = 0,
        }
    )
end

local function NetworkStatus()
    local restricted = OutgoingRestricted()
    local now = GetTime and GetTime() or 0
    Print(string.format(
        "Network: prefix %s %s; transports %s; queued transmissions %d; sent transmissions %d; received logical messages %d; active peers %d; peers this session %d; outgoing %s. Use /aq peers for the temporary P2P panel.",
        PREFIX,
        prefixRegistered and "registered" or "not registered",
        ActiveTransportSummary(),
        #pending,
        sentCount,
        receivedCount,
        ActivePeerCount(now),
        SessionPeerCount(),
        restricted and "currently restricted by WoW" or "available"
    ))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHANNEL_UI_UPDATE")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("CHAT_MSG_ADDON")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        RegisterPrefix()
        C_Timer.After(1.0, function()
            JoinNetworkChannel()
            C_Timer.After(1.0, SendHello)
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, function()
            JoinNetworkChannel()
            C_Timer.After(1.0, SendHello)
        end)
    elseif event == "CHANNEL_UI_UPDATE" then
        RefreshChannelID()
    elseif event == "GROUP_ROSTER_UPDATE" then
        C_Timer.After(0.5, SendHello)
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    end
end)

C_Timer.NewTicker(SEND_INTERVAL, ProcessPending)
C_Timer.NewTicker(HELLO_INTERVAL, function()
    if not prefixRegistered then
        RegisterPrefix()
    end
    if RefreshChannelID() <= 0 then
        JoinNetworkChannel()
    end
    SendHello()
end)

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "network" or command == "network status" then
        NetworkStatus()
        return
    elseif command == "network retry" or command == "network join" then
        RegisterPrefix()
        JoinNetworkChannel()
        C_Timer.After(1.1, function()
            SendHello()
            NetworkStatus()
        end)
        return
    elseif command == "peers" or command == "p2p" or command == "network peers" then
        ShowPeerPanel()
        return
    elseif command == "peers refresh" or command == "p2p refresh" then
        RegisterPrefix()
        JoinNetworkChannel()
        SendHello()
        ShowPeerPanel()
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.BroadcastMapQuestEvidence = BroadcastMapQuestEvidence
ZQG.GetAzerothNetworkStatus = NetworkStatus
ZQG.ShowAzerothNetworkPeers = ShowPeerPanel
