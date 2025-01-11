-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");
include("PopupDialog");

-- Then our mod files
include("civobvRL");
include("civactionsRL");


-- GameState.lua
-- This implementation collects all relevant game state information using the provided observation functions

function GetGameState()
    print("GetGameState: Beginning game state collection...")
    
    local gameState = {
        turn = nil,
        player = nil,
        playerData = nil,
        timestamp = os.time() -- Add timestamp for tracking when state was collected
    }

    -- Get current turn
    gameState.turn = GetTurnNumber()
    if not gameState.turn then
        print("GetGameState: Failed to get turn number")
        return nil
    end

    -- Get player ID
    gameState.player = GetPlayerID()
    if not gameState.player or gameState.player == -1 then
        print("GetGameState: Failed to get valid player ID")
        return nil
    end

    -- Get comprehensive player data
    gameState.playerData = GetPlayerData(gameState.player)
    if not gameState.playerData then
        print("GetGameState: Failed to get player data")
        return nil
    end

    -- Add some computed statistics
    gameState.statistics = {
        totalCities = #gameState.playerData.Cities,
        totalUnits = #gameState.playerData.Units,
        totalTechsResearched = #gameState.playerData.TechsResearched,
        totalCivicsResearched = #gameState.playerData.CivicsResearched,
        netGoldPerTurn = gameState.playerData.GoldPerTurn - gameState.playerData.maintenance
    }

    -- Create summary of diplomatic state
    gameState.diplomacySummary = {
        atWarWith = {},
        friendsWith = {},
        alliedWith = {},
        metCivs = 0
    }

    for playerID, status in pairs(gameState.playerData.DiplomaticStatuses) do
        if status.HasMet then
            gameState.diplomacySummary.metCivs = gameState.diplomacySummary.metCivs + 1
            if status.DiplomaticState == "DIPLO_STATE_WAR" then
                table.insert(gameState.diplomacySummary.atWarWith, status.CivType)
            elseif status.DiplomaticState == "DIPLO_STATE_ALLIED" then
                table.insert(gameState.diplomacySummary.alliedWith, status.CivType)
            elseif status.DiplomaticState == "DIPLO_STATE_DECLARED_FRIEND" then
                table.insert(gameState.diplomacySummary.friendsWith, status.CivType)
            end
        end
    end

    -- Create summary of city states
    gameState.cityStateSummary = {
        totalSuzerainOf = 0,
        totalEnvoysSent = 0,
        totalQuests = 0
    }

    for _, cityState in ipairs(gameState.playerData.Cities.CityStates or {}) do
        if cityState.IsSuzerain then
            gameState.cityStateSummary.totalSuzerainOf = gameState.cityStateSummary.totalSuzerainOf + 1
        end
        gameState.cityStateSummary.totalEnvoysSent = gameState.cityStateSummary.totalEnvoysSent + cityState.EnvoysSent
        gameState.cityStateSummary.totalQuests = gameState.cityStateSummary.totalQuests + #(cityState.Quests or {})
    end

    -- Create summary of visible map data
    gameState.mapSummary = {
        totalVisibleTiles = #(gameState.playerData.Cities.VisibleTiles or {}),
        visibleResources = {},
        workableTiles = 0,
        strategicResources = 0
    }

    for _, tile in ipairs(gameState.playerData.Cities.VisibleTiles or {}) do
        if tile.ResourceType then
            gameState.mapSummary.visibleResources[tile.ResourceType] = 
                (gameState.mapSummary.visibleResources[tile.ResourceType] or 0) + 1
        end
        if tile.IsWorked then
            gameState.mapSummary.workableTiles = gameState.mapSummary.workableTiles + 1
        end
    end

    print("GetGameState: Game state collection complete")
    return gameState
end

-- Function to print a summary of the game state
function PrintGameStateSummary(gameState)
    if not gameState then
        print("Invalid game state")
        return
    end

    print("=== Game State Summary ===")
    print(string.format("Turn: %d", gameState.turn))
    print(string.format("Player ID: %d", gameState.player))
    print("\nResources:")
    print(string.format("Gold: %d (Net per turn: %d)", 
        gameState.playerData.Gold, 
        gameState.statistics.netGoldPerTurn))
    print(string.format("Science per turn: %d", gameState.playerData.SciencePerTurn))
    print(string.format("Culture per turn: %d", gameState.playerData.CulturePerTurn))
    print(string.format("Faith: %d", gameState.playerData.Faith))
    
    print("\nCities and Units:")
    print(string.format("Total Cities: %d", gameState.statistics.totalCities))
    print(string.format("Total Units: %d", gameState.statistics.totalUnits))
    
    print("\nDiplomacy:")
    print(string.format("Met Civilizations: %d", gameState.diplomacySummary.metCivs))
    print(string.format("At War With: %d civs", #gameState.diplomacySummary.atWarWith))
    print(string.format("Allied With: %d civs", #gameState.diplomacySummary.alliedWith))
    
    print("\nCity States:")
    print(string.format("Suzerain of: %d", gameState.cityStateSummary.totalSuzerainOf))
    print(string.format("Total Envoys: %d", gameState.cityStateSummary.totalEnvoysSent))
    print(string.format("Active Quests: %d", gameState.cityStateSummary.totalQuests))
    
    print("\nProgress:")
    print(string.format("Technologies Researched: %d", gameState.statistics.totalTechsResearched))
    print(string.format("Civics Researched: %d", gameState.statistics.totalCivicsResearched))
    print("=======================")

    for commandRow in GameInfo.UnitCommands() do
        print(commandRow)
    end
end

-- Example usage:
-- local gameState = GetGameState()
-- PrintGameStateSummary(gameState)