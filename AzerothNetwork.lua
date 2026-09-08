local ADDON_NAME, ZQG = ...

local PREFIX = "AZQUEST"
local CHANNEL_NAME = "AzerothQuesting"
local PROTOCOL_VERSION = 1
local SEND_INTERVAL = 1.05
local MAX_PENDING = 100

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

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
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

local function QueueMessage(key, message)
    if pendingKeys[key] then
        return false
    end
    if #pending >= MAX_PENDING then
        return false
    end
    pending[#pending + 1] = { key = key, message = message }
    pendingKeys[key] = true
    return true
end

local function SendRaw(message)
    if not prefixRegistered or OutgoingRestricted() then
        return false
    end
    local id = RefreshChannelID()
    if id <= 0 or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return false
    end

    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, "CHANNEL", id)
    if not ok then
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

local function ProcessPending()
    if #pending == 0 then
        return
    end
    if OutgoingRestricted() then
        return
    end
    if RefreshChannelID() <= 0 then
        JoinNetworkChannel()
        return
    end

    local item = pending[1]
    if SendRaw(item.message) then
        table.remove(pending, 1)
        pendingKeys[item.key] = nil
    elseif lastSendResult ~= 3 and lastSendResult ~= 8 and lastSendResult ~= 11 then
        -- Keep throttle/lockdown failures queued for retry. Other permanent
        -- errors are dropped so one bad message cannot block the network queue.
        table.remove(pending, 1)
        pendingKeys[item.key] = nil
    end
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
    if type(sender) ~= "string" or not UnitName then
        return false
    end
    local ok, playerName = pcall(UnitName, "player")
    if not ok or type(playerName) ~= "string" then
        return false
    end
    local senderBase = sender:match("^([^-]+)") or sender
    return senderBase == playerName
end

local function OnAddonMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "CHANNEL" or type(text) ~= "string" then
        return
    end
    if SenderIsPlayer(sender) then
        return
    end

    receivedCount = receivedCount + 1
    if type(sender) == "string" then
        sessionPeers[sender] = true
    end

    if text:match("^H|1|") then
        return
    end

    local observation = ParseQuestMessage(text)
    if not observation or not ZQG.QueueCompanionQuestObservation then
        return
    end

    -- The sender name is deliberately not persisted. Only anonymous quest,
    -- map, faction, class, completion, and evidence context enters the queue.
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

local function PeerCount()
    local count = 0
    for _ in pairs(sessionPeers) do
        count = count + 1
    end
    return count
end

local function NetworkStatus()
    local id = RefreshChannelID()
    local restricted = OutgoingRestricted()
    Print(string.format(
        "Network: prefix %s %s; channel %s %s%s; queued %d; sent %d; received %d; peers this session %d; outgoing %s.",
        PREFIX,
        prefixRegistered and "registered" or "not registered",
        CHANNEL_NAME,
        id > 0 and ("joined as /" .. tostring(id)) or "not joined",
        id > 0 and " (protocol traffic stays out of normal chat)" or "",
        #pending,
        sentCount,
        receivedCount,
        PeerCount(),
        restricted and "currently restricted by WoW" or "available"
    ))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHANNEL_UI_UPDATE")
events:RegisterEvent("CHAT_MSG_ADDON")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        RegisterPrefix()
        C_Timer.After(1.0, function()
            JoinNetworkChannel()
            C_Timer.After(1.0, SendHello)
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, JoinNetworkChannel)
    elseif event == "CHANNEL_UI_UPDATE" then
        RefreshChannelID()
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    end
end)

C_Timer.NewTicker(SEND_INTERVAL, ProcessPending)

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
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.BroadcastMapQuestEvidence = BroadcastMapQuestEvidence
ZQG.GetAzerothNetworkStatus = NetworkStatus
