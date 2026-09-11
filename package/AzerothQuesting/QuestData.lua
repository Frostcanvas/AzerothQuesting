local ADDON_NAME, ZQG = ...

-- Supplemental quest database.
--
-- The live WoW APIs can expose accepted quests on the current map and many
-- available quest-line starters, but they do not reliably expose every older
-- unaccepted side/story quest. Records here fill those gaps.
--
-- Format:
-- ZQG.StaticQuests[uiMapID] = {
--   {
--     id = 12345,
--     name = "Example Quest",
--     x = 0.5123, -- normalized map coordinate (0.0 to 1.0)
--     y = 0.4388,
--     prereqs = { 12344 },       -- optional; ALL listed quests must be completed
--     blockedBy = { 12346 },      -- optional; hide if ANY listed quest is completed
--     exclusiveWith = { 12347 }, -- optional; hide if ANY listed quest is active or completed
--     skippedBy = { 12348 },      -- optional breadcrumb; hide if a later quest is active/completed
--     faction = "Horde",         -- optional: "Horde" or "Alliance"
--     phase = "past",            -- optional historical/time-phase key
--   },
-- }
--
-- blockedBy is for permanent completion-based lockouts. exclusiveWith is for
-- alternate route choices where accepting or completing another quest removes
-- this option. skippedBy is specifically for breadcrumbs that become unavailable
-- after the player starts or completes a later quest; an already accepted
-- breadcrumb remains visible so Azeroth Questing does not hide a quest that is
-- still in the player's log. These rules can be stored directly on supplemental
-- records or in the global ZQG.QuestAvailabilityRules table used by
-- QuestLockouts.lua.
--
-- Phase-tagged supplemental quests are filtered by TimePhases.lua so quests
-- from an older/present version of the same zone are not mixed together. Live
-- Blizzard quest sources already reflect the character's active world phase.
-- If a phased zone needs reliable automatic identification, it can register a
-- detector and player-facing labels in ZQG.TimePhaseZones[uiMapID].

ZQG.StaticQuests = ZQG.StaticQuests or {}
ZQG.LocationHints = ZQG.LocationHints or {}
ZQG.TimePhaseZones = ZQG.TimePhaseZones or {}
ZQG.QuestPhaseRequirements = ZQG.QuestPhaseRequirements or {}
ZQG.PhaseSwitchers = ZQG.PhaseSwitchers or {}

-- Thousand Needles (UiMapID 64)
-- Initial coverage for the Splithoof Heights -> Speedbarge -> Freewind Post
-- section that exposed the first missing-quest reports during testing.
ZQG.StaticQuests[64] = {
    -- Horde
    {
        id = 25814,
        name = "Go Blow that Horn",
        x = 0.8861,
        y = 0.5492,
        prereqs = { 25797, 25799 },
        faction = "Horde",
    },
    {
        id = 25826,
        name = "Deliver the Goods",
        x = 0.8858,
        y = 0.5494,
        prereqs = { 25814 },
        faction = "Horde",
    },
    {
        id = 25836,
        name = "Free Freewind Post",
        x = 0.7594,
        y = 0.7469,
        prereqs = { 25826 },
        faction = "Horde",
    },
    {
        id = 25874,
        name = "Horn of the Traitor",
        x = 0.4459,
        y = 0.4995,
        prereqs = { 25836 },
        faction = "Horde",
    },

    -- Alliance
    {
        id = 25813,
        name = "Go Blow that Horn",
        x = 0.9135,
        y = 0.5770,
        prereqs = { 25796, 25798 },
        faction = "Alliance",
    },
    {
        id = 25825,
        name = "Deliver the Goods",
        x = 0.9136,
        y = 0.5777,
        prereqs = { 25813 },
        faction = "Alliance",
    },
    {
        id = 25835,
        name = "Free Freewind Post",
        x = 0.7597,
        y = 0.7465,
        prereqs = { 25825 },
        faction = "Alliance",
    },
    {
        id = 25873,
        name = "Horn of the Traitor",
        x = 0.4458,
        y = 0.4996,
        prereqs = { 25835 },
        faction = "Alliance",
    },
}

-- Some quest locations are misleading on WoW's flat 2D map because the NPC or
-- objective is on a different vertical level. These notes let the UI warn the
-- player instead of making a nearby map pin look like it is on the same level.
ZQG.LocationHints[25874] = {
    short = "UPPER LEVEL",
    text = "Upper level of Freewind Post - Montarr is on top of the mountain. Follow the path uphill.",
}

ZQG.LocationHints[25873] = {
    short = "UPPER LEVEL",
    text = "Upper level of Freewind Post - Montarr is on top of the mountain. Follow the path uphill.",
}

-- Blasted Lands (UiMapID 17; 1246 is an alternate Blasted Lands UI map used
-- by some modern map contexts). Zidormi stands near the northern border and
-- switches the zone between the pre-Iron-Horde version (past) and the Iron
-- Horde incursion version (present).
local blastedLandsPhaseConfig = {
    phases = {
        past = "PAST / Before invasion",
        present = "PRESENT / Iron Horde",
    },
}
ZQG.TimePhaseZones[17] = blastedLandsPhaseConfig
ZQG.TimePhaseZones[1246] = blastedLandsPhaseConfig

local blastedLandsZidormi = {
    name = "Zidormi",
    x = 0.482,
    y = 0.072,
}
ZQG.PhaseSwitchers[17] = blastedLandsZidormi
ZQG.PhaseSwitchers[1246] = blastedLandsZidormi

-- Horde Iron Horde incursion quests confirmed while testing Blasted Lands.
-- These quests require the present/Iron Horde version of the zone. TimePhases
-- can use a currently visible/active curated phase-exclusive quest as automatic
-- evidence for the player's timeline, and PhaseGuidance can point to Zidormi if
-- the player is known to be in the opposite timeline.
ZQG.QuestPhaseRequirements[35745] = "present" -- Attack of the Iron Horde
ZQG.QuestPhaseRequirements[35746] = "present" -- Under Siege

-- Darkshore (UiMapID 62). Retail Darkshore has a Zidormi-controlled historical
-- split around the War of the Thorns/Burning of Teldrassil. Registering the
-- zone here makes the main panel show the timeline line and, until a reliable
-- phase is known, the explicit instruction to talk to Zidormi before questing.
--
-- Zidormi's normal "show me what Darkshore was like before..." wording is
-- already handled by TimePhases.lua/TimelineSync.lua, as is the opposite
-- return-to-present wording after the player has switched to the old phase.
local darkshorePhaseConfig = {
    phases = {
        past = "PAST / Before War of the Thorns",
        present = "PRESENT / After War of the Thorns",
    },
}
ZQG.TimePhaseZones[62] = darkshorePhaseConfig

ZQG.PhaseSwitchers[62] = {
    name = "Zidormi",
    x = 0.484,
    y = 0.250,
}

-- Midnight Quel'Thalas live-map confirmation. On the current Retail client,
-- C_Map.GetBestMapForUnit("player") returned UiMapID 2537 / "Quel'Thalas" in
-- the rebuilt Midnight world. The old Burning Crusade Ghostlands returned
-- UiMapID 95. TimelineZones.lua already classifies 95 as the old/Past map; this
-- explicit current-world detector makes 2537 a reliable PRESENT signal too.
local midnightQuelThalasPhaseConfig = {
    phases = {
        past = "PAST / Burning Crusade Quel'Thalas",
        present = "PRESENT / Midnight Quel'Thalas",
    },
    detect = function()
        return "present"
    end,
}
ZQG.TimePhaseZones[2537] = midnightQuelThalasPhaseConfig
ZQG.PhaseSwitchers[2537] = {
    name = "Zidormi at Thalassian Pass",
}
