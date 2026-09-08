local ADDON_NAME, ZQG = ...

local sessionSeen = {}

local function GetStore()
    ZoneQuestGuideDB = ZoneQuestGuideDB or {}
    ZoneQuestGuideDB.instanceLearning = ZoneQuestGuideDB.instanceLearning or {
        version = 1,
        observations = {},
    }

    local store = ZoneQuestGuideDB.instanceLearning
    store.version = 1
    store.observations = store.observations or {}
    return store
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function PlayerFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player") or "Neutral"
    end
    return "Neutral"
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function MapInfo(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then
        return nil
    end

    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    return ok and info or nil
end

local function ScenarioInfo()
    if not C_Scenario or not C_Scenario.GetInfo then
        return nil, nil, nil, nil
    end

    local ok, a, b, c, d, e, f, g, h, i, j = pcall(C_Scenario.GetInfo)
    if not ok then
        return nil, nil, nil, nil
    end

    if type(a) == "table" then
        return a.name, a.scenarioType, a.area, a.uiTextureKit
    end

    return a, h, i, j
end

local function TimelineInfo(mapID)
    if not mapID or not ZQG.GetTimePhaseKey then
        return nil, nil
    end

    local ok, phase, source = pcall(ZQG.GetTimePhaseKey, mapID)
    if not ok then
        return nil, nil
    end

    return phase, source
end

local function GetInstanceFingerprint()
    local mapID = CurrentMapID()
    local mapInfo = MapInfo(mapID)
    local parentMapID = mapInfo and mapInfo.parentMapID or nil
    local parentInfo = MapInfo(parentMapID)

    local inInstance = false
    local instanceType
    if IsInInstance then
        local ok, inside, reportedType = pcall(IsInInstance)
        if ok then
            inInstance = inside and true or false
            instanceType = reportedType
        end
    end

    local instanceName
    local difficultyID
    local difficultyName
    local maxPlayers
    local instanceID
    local instanceGroupSize
    local lfgDungeonID

    if GetInstanceInfo then
        local ok, name, apiType, diffID, diffName, maxCount, _, _, instID, groupSize, lfgID = pcall(GetInstanceInfo)
        if ok then
            instanceName = name
            instanceType = apiType or instanceType
            difficultyID = diffID
            difficultyName = diffName
            maxPlayers = maxCount
            instanceID = instID
            instanceGroupSize = groupSize
            lfgDungeonID = lfgID
        end
    end

    local scenarioName, scenarioType, scenarioArea, scenarioTextureKit = ScenarioInfo()
    local phase, phaseSource = TimelineInfo(mapID)

    return {
        mapID = mapID,
        mapName = mapInfo and mapInfo.name or nil,
        parentMapID = parentMapID,
        parentMapName = parentInfo and parentInfo.name or nil,
        inInstance = inInstance,
        instanceID = instanceID,
        instanceName = instanceName,
        instanceType = instanceType or "none",
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        maxPlayers = maxPlayers,
        instanceGroupSize = instanceGroupSize,
        lfgDungeonID = lfgDungeonID,
        scenarioName = scenarioName,
        scenarioType = scenarioType,
        scenarioArea = scenarioArea,
        scenarioTextureKit = scenarioTextureKit,
        faction = PlayerFaction(),
        phase = phase,
        phaseSource = phaseSource,
    }
end

local function NumericToken(value)
    value = tonumber(value)
    if not value then
        return 0
    end
    return math.floor(value)
end

local function ObservationKey(info)
    return table.concat({
        tostring(NumericToken(info.mapID)),
        tostring(NumericToken(info.instanceID)),
        tostring(NumericToken(info.difficultyID)),
        tostring(info.instanceType or "none"),
        tostring(info.faction or "Neutral"),
        tostring(NumericToken(info.lfgDungeonID)),
    }, ":")
end

local function RecordInstanceFingerprint(info)
    info = info or GetInstanceFingerprint()
    if not info or not info.inInstance then
        return false
    end

    if type(info.mapID) ~= "number" or info.mapID <= 0 then
        return false
    end

    local store = GetStore()
    local key = ObservationKey(info)
    local record = store.observations[key]

    if not record then
        record = {
            mapID = info.mapID,
            mapName = info.mapName,
            parentMapID = info.parentMapID,
            parentMapName = info.parentMapName,
            faction = info.faction,
            instanceID = info.instanceID,
            instanceName = info.instanceName,
            instanceType = info.instanceType,
            difficultyID = info.difficultyID,
            difficultyName = info.difficultyName,
            maxPlayers = info.maxPlayers,
            instanceGroupSize = info.instanceGroupSize,
            lfgDungeonID = info.lfgDungeonID,
            scenarioName = info.scenarioName,
            scenarioType = info.scenarioType,
            scenarioArea = info.scenarioArea,
            scenarioTextureKit = info.scenarioTextureKit,
            phase = info.phase,
            phaseSource = info.phaseSource,
            seen = 0,
        }
        store.observations[key] = record
    end

    -- Later scans can fill in names/scenario metadata that was unavailable on
    -- the first frame after zoning without creating a duplicate observation.
    for field, value in pairs(info) do
        if value ~= nil and field ~= "inInstance" then
            record[field] = value
        end
    end

    if not sessionSeen[key] then
        sessionSeen[key] = true
        record.seen = (record.seen or 0) + 1
    end

    if ZQG.ReportInstanceFingerprintToWago then
        ZQG.ReportInstanceFingerprintToWago(info)
    end

    return true
end

local scanScheduled = false
local function ScheduleScan(delay)
    if scanScheduled then
        return
    end

    scanScheduled = true
    C_Timer.After(delay or 0.5, function()
        scanScheduled = false
        RecordInstanceFingerprint()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pcall(events.RegisterEvent, events, "SCENARIO_UPDATE")
pcall(events.RegisterEvent, events, "SCENARIO_CRITERIA_UPDATE")

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        ScheduleScan(1.0)
        C_Timer.After(2.0, function()
            RecordInstanceFingerprint()
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        ScheduleScan(0.7)
    else
        ScheduleScan(0.3)
    end
end)

local function SortedObservationKeys(observations)
    local keys = {}
    for key in pairs(observations or {}) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(a, b)
        local aa = observations[a]
        local bb = observations[b]
        local amap = tonumber(aa and aa.mapID) or 0
        local bmap = tonumber(bb and bb.mapID) or 0
        if amap ~= bmap then
            return amap < bmap
        end

        local ainst = tonumber(aa and aa.instanceID) or 0
        local binst = tonumber(bb and bb.instanceID) or 0
        if ainst ~= binst then
            return ainst < binst
        end

        return tostring(a) < tostring(b)
    end)

    return keys
end

local function SafeField(value)
    value = tostring(value or "")
    value = value:gsub("[|\t\r\n]", " ")
    return value
end

local function BuildInstanceLearningExport()
    local store = GetStore()
    local lines = {
        "ZQGINSTANCEDATA|1",
        "# mapID\tmapName\tparentMapID\tparentMapName\tfaction\tinstanceID\tinstanceName\tinstanceType\tdifficultyID\tdifficultyName\tmaxPlayers\tinstanceGroupSize\tlfgDungeonID\tscenarioName\tscenarioType\tscenarioArea\tscenarioTextureKit\tphase\tphaseSource\tseen",
    }

    for _, key in ipairs(SortedObservationKeys(store.observations)) do
        local record = store.observations[key]
        lines[#lines + 1] = table.concat({
            SafeField(record.mapID),
            SafeField(record.mapName),
            SafeField(record.parentMapID),
            SafeField(record.parentMapName),
            SafeField(record.faction),
            SafeField(record.instanceID),
            SafeField(record.instanceName),
            SafeField(record.instanceType),
            SafeField(record.difficultyID),
            SafeField(record.difficultyName),
            SafeField(record.maxPlayers),
            SafeField(record.instanceGroupSize),
            SafeField(record.lfgDungeonID),
            SafeField(record.scenarioName),
            SafeField(record.scenarioType),
            SafeField(record.scenarioArea),
            SafeField(record.scenarioTextureKit),
            SafeField(record.phase),
            SafeField(record.phaseSource),
            tostring(record.seen or 0),
        }, "\t")
    end

    return table.concat(lines, "\n")
end

local previousBuildLearningExport = ZQG.BuildLearningExport
local function BuildCombinedExport()
    local baseText = previousBuildLearningExport and previousBuildLearningExport() or ""
    local instanceText = BuildInstanceLearningExport()

    if baseText ~= "" then
        return baseText .. "\n\n" .. instanceText
    end

    return instanceText
end

local exportFrame = CreateFrame("Frame", "ZoneQuestGuideInstanceExportFrame", UIParent, "BackdropTemplate")
exportFrame:SetSize(720, 470)
exportFrame:SetPoint("CENTER")
exportFrame:SetFrameStrata("DIALOG")
exportFrame:SetClampedToScreen(true)
exportFrame:EnableMouse(true)
exportFrame:SetMovable(true)
exportFrame:RegisterForDrag("LeftButton")
exportFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
exportFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
exportFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
exportFrame:Hide()

local exportTitle = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
exportTitle:SetPoint("TOPLEFT", 16, -14)
exportTitle:SetText("Azeroth Questing - Learning Export")

local exportNote = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportNote:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", 0, -6)
exportNote:SetWidth(665)
exportNote:SetJustifyH("LEFT")
exportNote:SetText("Includes phase, map/quest, and instance fingerprints. No character name, realm, GUID, guild, account identifier, coordinates, chat, or party/raid member names are included.")

local exportClose = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
exportClose:SetPoint("TOPRIGHT", -3, -3)

local scroll = CreateFrame("ScrollFrame", "ZoneQuestGuideInstanceExportScrollFrame", exportFrame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 18, -82)
scroll:SetPoint("BOTTOMRIGHT", -38, 18)

local exportBox = CreateFrame("EditBox", nil, scroll)
exportBox:SetMultiLine(true)
exportBox:SetAutoFocus(false)
exportBox:SetFontObject(ChatFontNormal)
exportBox:SetWidth(645)
exportBox:SetTextInsets(4, 4, 4, 4)
exportBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
scroll:SetScrollChild(exportBox)

local function ShowExport(instanceOnly)
    local text = instanceOnly and BuildInstanceLearningExport() or BuildCombinedExport()
    exportBox:SetText(text)
    exportBox:SetCursorPosition(0)
    exportFrame:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

local function TextOr(value, fallback)
    if value == nil or value == "" then
        return fallback
    end
    return tostring(value)
end

local function PrintInspect()
    local info = GetInstanceFingerprint()
    if not info then
        Print("Inspect: current map/instance information is unavailable.")
        return
    end

    local parentText = "none"
    if info.parentMapID then
        parentText = string.format("%s / %s", tostring(info.parentMapID), TextOr(info.parentMapName, "Unknown"))
    end

    Print(string.format(
        "Inspect: map %s / %s | parent %s | instance %s / %s | type %s | difficulty %s / %s.",
        TextOr(info.mapID, "?"),
        TextOr(info.mapName, "Unknown"),
        parentText,
        TextOr(info.instanceID, "?"),
        TextOr(info.instanceName, "Unknown"),
        TextOr(info.instanceType, "none"),
        TextOr(info.difficultyID, "?"),
        TextOr(info.difficultyName, "Unknown")
    ))

    local phaseText = info.phase and tostring(info.phase):upper() or "UNKNOWN"
    Print(string.format(
        "Inspect: inInstance=%s | maxPlayers=%s | groupSize=%s | LFG=%s | scenario=%s | scenarioType=%s | faction=%s | timeline=%s (%s).",
        info.inInstance and "yes" or "no",
        TextOr(info.maxPlayers, "?"),
        TextOr(info.instanceGroupSize, "?"),
        TextOr(info.lfgDungeonID, "?"),
        TextOr(info.scenarioName, "none"),
        TextOr(info.scenarioType, "?"),
        TextOr(info.faction, "Neutral"),
        phaseText,
        TextOr(info.phaseSource, "no reliable signal")
    ))
end

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "inspect" or command == "instance" then
        PrintInspect()
        return
    elseif command == "instanceexport" or command == "instances export" then
        ShowExport(true)
        return
    elseif command == "export" or command == "learn export" or command == "learning export" then
        ShowExport(false)
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.GetInstanceFingerprint = GetInstanceFingerprint
ZQG.RecordInstanceFingerprint = RecordInstanceFingerprint
ZQG.BuildInstanceLearningExport = BuildInstanceLearningExport
ZQG.BuildLearningExport = BuildCombinedExport
ZQG.PrintInstanceInspect = PrintInspect
