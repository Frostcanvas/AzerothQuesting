from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"{label} marker not found")
    return text.replace(old, new, 1)


guide_path = Path("GuideMode.lua")
guide = guide_path.read_text(encoding="utf-8")

guide = replace_once(
    guide,
    """local currentQuestID
local currentIndex = 1
local lastWaypointKey
local updateScheduled = false
local forceWaypointOnUpdate = false
""",
    """local currentQuestID
local currentIndex = 1
local lastWaypointKey
local updateScheduled = false
local forceWaypointOnUpdate = false
local activePickupBatch

local PICKUP_GROUP_RADIUS_YARDS = 120
local MAX_PICKUP_BATCH = 4
""",
    "GuideMode top",
)

find_marker = """local function FindQuestIndex(quests, questID)
    if not questID then
        return nil
    end
    for index, quest in ipairs(quests) do
        if quest.id == questID then
            return index
        end
    end
    return nil
end
"""
helpers = r'''

local function FindQuestByID(quests, questID)
    local index = FindQuestIndex(quests, questID)
    return index and quests[index] or nil
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

local function QuestWorldPoint(quest, mapID)
    if not quest or not quest.x or not quest.y or not mapID
        or not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then
        return nil, nil, nil
    end

    local ok, continent, worldPos = pcall(
        C_Map.GetWorldPosFromMapPos,
        mapID,
        CreateVector2D(quest.x, quest.y)
    )
    if not ok or not worldPos then
        return nil, nil, nil
    end

    local x, y = GetWorldXY(worldPos)
    if not x or not y then
        return nil, nil, nil
    end
    return continent, x, y
end

local function DistanceBetweenQuestsYards(a, b, mapID)
    local continentA, ax, ay = QuestWorldPoint(a, mapID)
    local continentB, bx, by = QuestWorldPoint(b, mapID)
    if not ax or not ay or not bx or not by then
        return nil
    end
    if continentA and continentB and continentA ~= continentB then
        return nil
    end

    local dx = bx - ax
    local dy = by - ay
    return math.sqrt((dx * dx) + (dy * dy))
end

local function QuestsAreNear(a, b, mapID)
    local yards = DistanceBetweenQuestsYards(a, b, mapID)
    if yards then
        return yards <= PICKUP_GROUP_RADIUS_YARDS
    end

    if type(a and a.x) == "number" and type(a and a.y) == "number"
        and type(b and b.x) == "number" and type(b and b.y) == "number" then
        local dx = a.x - b.x
        local dy = a.y - b.y
        return ((dx * dx) + (dy * dy)) <= (0.018 * 0.018)
    end

    return false
end

local function ListContains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

local function PickupRelationshipConflicts(a, b)
    if not a or not b then
        return true
    end

    local rulesA = ZQG.QuestAvailabilityRules and ZQG.QuestAvailabilityRules[a.id] or nil
    local rulesB = ZQG.QuestAvailabilityRules and ZQG.QuestAvailabilityRules[b.id] or nil

    local function HasRelation(quest, rules, field, otherID)
        return ListContains(quest and quest[field], otherID)
            or ListContains(rules and rules[field], otherID)
    end

    if HasRelation(a, rulesA, "exclusiveWith", b.id)
        or HasRelation(b, rulesB, "exclusiveWith", a.id) then
        return true
    end

    -- Breadcrumbs and the later quests that can skip them stay as separate
    -- steps so the guide does not encourage a lockout-producing pickup order.
    if HasRelation(a, rulesA, "skippedBy", b.id)
        or HasRelation(b, rulesB, "skippedBy", a.id) then
        return true
    end

    if HasRelation(a, rulesA, "blockedBy", b.id)
        or HasRelation(b, rulesB, "blockedBy", a.id) then
        return true
    end

    return false
end

local function BuildPickupBatch(quests, anchor)
    if not anchor or QuestStatusKey(anchor) ~= "available" or not anchor.x or not anchor.y then
        return nil
    end

    local mapID = CurrentMapID()
    if not mapID then
        return nil
    end

    local ids = { anchor.id }
    for _, quest in ipairs(quests) do
        if #ids >= MAX_PICKUP_BATCH then
            break
        end

        if quest.id ~= anchor.id
            and QuestStatusKey(quest) == "available"
            and quest.x and quest.y
            and not PickupRelationshipConflicts(anchor, quest)
            and QuestsAreNear(anchor, quest, mapID) then
            ids[#ids + 1] = quest.id
        end
    end

    if #ids < 2 then
        return nil
    end

    return {
        ids = ids,
        total = #ids,
        mapID = mapID,
    }
end

local function AnnotatePickupTarget(quest, batch, pending)
    if not quest or not batch then
        return
    end

    quest.guidePickupBatchTotal = batch.total
    quest.guidePickupBatchRemaining = #pending
    quest.guidePickupBatchIndex = math.max(1, batch.total - #pending + 1)
    quest.guidePickupNextName = pending[2] and pending[2].name or nil
end

local function ResolveActivePickupBatch(quests)
    local batch = activePickupBatch
    if not batch then
        return nil, nil
    end

    if batch.mapID and CurrentMapID() ~= batch.mapID then
        activePickupBatch = nil
        return nil, nil
    end

    local pending = {}
    local accepted = {}
    for _, questID in ipairs(batch.ids) do
        local quest = FindQuestByID(quests, questID)
        if quest then
            local status = QuestStatusKey(quest)
            if status == "available" then
                pending[#pending + 1] = quest
            elseif status == "progress" or status == "turnin" then
                accepted[#accepted + 1] = quest
            end
        end
    end

    if #pending > 0 then
        local target = pending[1]
        AnnotatePickupTarget(target, batch, pending)
        return target, nil
    end

    activePickupBatch = nil
    return nil, accepted[1]
end
'''
if find_marker not in guide:
    raise SystemExit("GuideMode FindQuestIndex marker not found")
guide = guide.replace(find_marker, find_marker + helpers, 1)

old_update = '''local function UpdateGuide(forceWaypoint)
    if GetDB().guideModeEnabled == false then
        return
    end

    local quests = GetGuideQuests()
    if #quests == 0 then
        currentQuestID = nil
        currentIndex = 1
        lastWaypointKey = nil
        return
    end

    local index = FindQuestIndex(quests, currentQuestID)
    if not index then
        index = math.max(1, math.min(currentIndex or 1, #quests))
        SelectQuestAt(index, quests, true)
    else
        currentIndex = index
    end

    local quest = quests[currentIndex]
    if not quest then
        return
    end
    currentQuestID = quest.id

    local waypointKey = table.concat({
        tostring(quest.id or 0),
        QuestStatusKey(quest),
        tostring(CurrentMapID() or 0),
    }, ":")

    if forceWaypoint or waypointKey ~= lastWaypointKey then
        lastWaypointKey = waypointKey
        if ZQG.SetWaypointForQuest then
            pcall(ZQG.SetWaypointForQuest, quest)
        end
    end
end
'''
new_update = '''local function UpdateGuide(forceWaypoint)
    if GetDB().guideModeEnabled == false then
        activePickupBatch = nil
        return
    end

    local quests = GetGuideQuests()
    if #quests == 0 then
        currentQuestID = nil
        currentIndex = 1
        lastWaypointKey = nil
        activePickupBatch = nil
        return
    end

    local quest
    local batchTarget, batchFinishedTarget = ResolveActivePickupBatch(quests)
    if batchTarget then
        quest = batchTarget
        currentQuestID = quest.id
        currentIndex = FindQuestIndex(quests, currentQuestID) or currentIndex
    else
        if batchFinishedTarget then
            currentQuestID = batchFinishedTarget.id
        end

        local index = FindQuestIndex(quests, currentQuestID)
        if not index then
            index = math.max(1, math.min(currentIndex or 1, #quests))
            SelectQuestAt(index, quests, true)
        else
            currentIndex = index
        end

        quest = quests[currentIndex]
        if not quest then
            return
        end
        currentQuestID = quest.id

        -- If the current step is a pickup, collect other compatible quests in
        -- the same nearby hub first. This keeps the guide from sending the
        -- player away after accepting only one of several adjacent quests.
        if QuestStatusKey(quest) == "available" then
            local batch = BuildPickupBatch(quests, quest)
            if batch then
                activePickupBatch = batch
                local pickupTarget = ResolveActivePickupBatch(quests)
                if pickupTarget then
                    quest = pickupTarget
                    currentQuestID = quest.id
                    currentIndex = FindQuestIndex(quests, currentQuestID) or currentIndex
                end
            end
        end
    end

    local waypointKey = table.concat({
        tostring(quest.id or 0),
        QuestStatusKey(quest),
        tostring(quest.guidePickupBatchIndex or 0),
        tostring(CurrentMapID() or 0),
    }, ":")

    if forceWaypoint or waypointKey ~= lastWaypointKey then
        lastWaypointKey = waypointKey
        if ZQG.SetWaypointForQuest then
            pcall(ZQG.SetWaypointForQuest, quest)
        end
    end
end
'''
guide = replace_once(guide, old_update, new_update, "GuideMode UpdateGuide")

guide = replace_once(
    guide,
    '''                if self.quest then
                    currentQuestID = self.quest.id
                    local quests = GetGuideQuests()
''',
    '''                if self.quest then
                    activePickupBatch = nil
                    currentQuestID = self.quest.id
                    local quests = GetGuideQuests()
''',
    "GuideMode row selection",
)

guide = replace_once(
    guide,
    '''function ZQG.HideGuideMode()
    GetDB().guideModeEnabled = false
end
''',
    '''function ZQG.HideGuideMode()
    GetDB().guideModeEnabled = false
    activePickupBatch = nil
end
''',
    "GuideMode HideGuideMode",
)

guide = replace_once(
    guide,
    '''function ZQG.GuideNext()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) + 1, quests, true)
    UpdateGuide(true)
end

function ZQG.GuideBack()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) - 1, quests, true)
    UpdateGuide(true)
end
''',
    '''function ZQG.GuideNext()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    activePickupBatch = nil
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) + 1, quests, true)
    UpdateGuide(true)
end

function ZQG.GuideBack()
    local quests = GetGuideQuests()
    if #quests == 0 then
        return
    end
    activePickupBatch = nil
    SelectQuestAt((FindQuestIndex(quests, currentQuestID) or currentIndex or 1) - 1, quests, true)
    UpdateGuide(true)
end
''',
    "GuideMode next/back",
)

guide_path.write_text(guide, encoding="utf-8")

nav_path = Path("NavigationHUD.lua")
nav = nav_path.read_text(encoding="utf-8")
nav = replace_once(
    nav,
    '''local function GetStatusText(quest)
    if ZQG.GetQuestStatusText then
        return ZQG.GetQuestStatusText(quest)
    end

    return quest and quest.accepted
        and "|cff66ff66IN PROGRESS|r"
        or "|cffffff66AVAILABLE|r"
end
''',
    '''local function GetStatusText(quest)
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
''',
    "NavigationHUD GetStatusText",
)

nav = replace_once(
    nav,
    '''    if distanceText then
        detailText:SetText(distanceText .. "  |cffb8b8b8• " .. questName .. "|r")
    elseif selectedQuest.accepted then
        detailText:SetText("|cffb8b8b8" .. questName .. " • Tracked by WoW|r")
    else
        detailText:SetText("|cffb8b8b8" .. questName .. "|r")
    end
''',
    '''    local batchTotal = tonumber(selectedQuest.guidePickupBatchTotal)
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
''',
    "NavigationHUD detail",
)
nav_path.write_text(nav, encoding="utf-8")

toc = Path("AzerothQuesting.toc")
toc_text = toc.read_text(encoding="utf-8")
if "## Version: 0.3.0-beta.16" not in toc_text:
    raise SystemExit("Expected Beta 16 TOC version not found")
toc.write_text(toc_text.replace("## Version: 0.3.0-beta.16", "## Version: 0.3.0-beta.17", 1), encoding="utf-8")

changelog = Path("CHANGELOG.md")
text = changelog.read_text(encoding="utf-8")
header = "# Azeroth Questing Changelog\n\n"
if not text.startswith(header):
    raise SystemExit("Unexpected changelog header")
entry = '''**VERSION 0.3.0 Beta 17 - September 12, 2026 - Available on GitHub Pre-release**

* **Added** Zygor-style pickup batches to Guide Mode. When the current guide step is an available quest and other compatible available quests are in the same nearby quest hub, Azeroth Questing groups up to four of them into one pickup sequence instead of immediately leaving after the first acceptance.

* **Changed** the compact navigation HUD to show **PICK UP N QUESTS** for a pickup batch, point to the first quest giver, then immediately retarget the next remaining pickup after each quest is accepted. Once the batch is complete, Guide Mode returns to the accepted quest flow and routes toward objectives/turn-ins as before.

* **Added** pickup progress context under the arrow, such as **1 of 2 pickups** and the next quest name when another pickup remains, while keeping the full Azeroth Questing quest-list window optional and closable.

* **Protected** breadcrumb and mutually exclusive quest behavior by refusing to combine nearby quests into one pickup batch when known `skippedBy`, `exclusiveWith`, or `blockedBy` relationships indicate they should remain separate steps.

* **Kept** the Beta 16 lightweight Guide Mode approach: closing the main quest-list window does not disable guide selection or the compact navigation HUD. Quest-frequency tabs, research data, P2P networking, Companion handoff, Website behavior, and Azeroth Questing Server schema are unchanged, so no Companion, Website, or server build is required.

*Beta 17 still requires in-game validation. Test a hub with at least two nearby available compatible quests: confirm the HUD says **PICK UP 2 QUESTS**, points to the first pickup, changes to the second pickup immediately after accepting the first, then changes to an objective/turn-in step after both are accepted. Repeat with the main quest-list window closed and verify the guide continues without Lua/taint errors. No successful Beta 17 in-game test is claimed yet.*

---

'''
changelog.write_text(header + entry + text[len(header):], encoding="utf-8")
