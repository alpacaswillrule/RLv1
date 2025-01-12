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
local m_localPlayerID = -1;
function GetGameState()
    print("GetGameState: Beginning game state collection...")

    return GetPlayerData(m_localPlayerID)
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