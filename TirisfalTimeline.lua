local ADDON_NAME, ZQG = ...

-- Tirisfal Glades uses separate live maps for the two Zidormi world states.
-- Player testing on Retail confirmed:
--   2070 / Tirisfal Glades = PRESENT / After Battle for Lordaeron
--   18   / Tirisfal Glades = PAST / Before Battle for Lordaeron
-- Keep 1247 registered as an alternate Tirisfal context, but do not assign it a
-- timeline until its live role is observed in-game.

local TIRISFAL_CONFIG = {
    phases = {
        past = "PAST / Before Battle for Lordaeron",
        present = "PRESENT / After Battle for Lordaeron",
    },
}

local TIRISFAL_SWITCHER = {
    name = "Zidormi",
    x = 0.694,
    y = 0.628,
}

local KNOWN_TIRISFAL_MAPS = {
    [18] = true,
    [1247] = true,
    [2070] = true,
}

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

for mapID in pairs(KNOWN_TIRISFAL_MAPS) do
    ZQG.TimePhaseZones = ZQG.TimePhaseZones or {}
    ZQG.PhaseSwitchers = ZQG.PhaseSwitchers or {}
    ZQG.TimePhaseZones[mapID] = TIRISFAL_CONFIG
    ZQG.PhaseSwitchers[mapID] = TIRISFAL_SWITCHER
end

local originalGetTimePhaseKey = ZQG.GetTimePhaseKey
if originalGetTimePhaseKey then
    ZQG.GetTimePhaseKey = function(mapID)
        mapID = mapID or CurrentMapID()
        local phase, source = originalGetTimePhaseKey(mapID)

        -- Explicit player overrides remain the strongest local choice.
        if source == "manual" then
            return phase, source
        end

        -- These two map identities were observed directly on opposite sides of
        -- the Zidormi transition, so they are stronger than cached gossip state.
        if mapID == 2070 then
            return "present", "detected"
        elseif mapID == 18 then
            return "past", "detected"
        end

        return phase, source
    end
end

ZQG.GetTirisfalTimelinePhase = function(mapID)
    mapID = mapID or CurrentMapID()
    if mapID == 2070 then
        return "present", "detected"
    elseif mapID == 18 then
        return "past", "detected"
    end
    return nil, nil
end
