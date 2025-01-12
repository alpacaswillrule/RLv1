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


-- Function to select which action to take based on priorities
function SelectPrioritizedAction(possibleActions)
    -- Check for highest priority actions first
    
    -- Priority 1: Found Religion if possible
    if possibleActions.FoundReligion and #possibleActions.FoundReligion > 0 then
        print("Found religion action available - selecting it")
        return "FoundReligion", possibleActions.FoundReligion[1]
    end

    -- Priority 2: District Construction
    if possibleActions.CityProduction then
        for _, production in ipairs(possibleActions.CityProduction) do
            if production.ProductionType == "Districts" then
                print("District construction available - selecting it")
                -- Pick a random valid plot from the ValidPlots list
                local plotIndex = math.random(#production.ValidPlots)
                local plot = production.ValidPlots[plotIndex]
                return "CityProduction", {
                    CityID = production.CityID,
                    ProductionType = "Districts",
                    ProductionHash = production.ProductionHash,
                    PlotX = plot.X or plot.x,  -- Handle different possible key names
                    PlotY = plot.Y or plot.y
                }
            end
        end
    end

    -- Priority 3: Activate Great People
    if possibleActions.ActivateGreatPerson and #possibleActions.ActivateGreatPerson > 0 then
        local greatPerson = possibleActions.ActivateGreatPerson[1]
        if greatPerson.ValidPlots and #greatPerson.ValidPlots > 0 then
            -- Pick a random valid plot if needed
            local plotIndex = greatPerson.ValidPlots[math.random(#greatPerson.ValidPlots)]
            greatPerson.PlotIndex = plotIndex
        end
        return "ActivateGreatPerson", greatPerson
    end

    -- Priority 4: Found Cities
    if possibleActions.FoundCity and #possibleActions.FoundCity > 0 then
        return "FoundCity", possibleActions.FoundCity[1]
    end

    -- Priority 5: Building Construction
    if possibleActions.CityProduction then
        local buildingProductions = {}
        for _, production in ipairs(possibleActions.CityProduction) do
            if production.ProductionType == "Buildings" then
                table.insert(buildingProductions, production)
            end
        end
        if #buildingProductions > 0 then
            return "CityProduction", buildingProductions[math.random(#buildingProductions)]
        end
    end

    -- Priority 6: Unit Production
    if possibleActions.CityProduction then
        local unitProductions = {}
        for _, production in ipairs(possibleActions.CityProduction) do
            if production.ProductionType == "Units" then
                table.insert(unitProductions, production)
            end
        end
        if #unitProductions > 0 then
            return "CityProduction", unitProductions[math.random(#unitProductions)]
        end
    end

    -- Priority 7: Move Units if available
    if possibleActions.MoveUnit and #possibleActions.MoveUnit > 0 then
        return "MoveUnit", possibleActions.MoveUnit[math.random(#possibleActions.MoveUnit)]
    end

    -- Priority 8: Any remaining action (random selection)
    local availableActions = {}
    for actionType, actions in pairs(possibleActions) do
        if type(actions) == "table" and #actions > 0 then
            table.insert(availableActions, {type = actionType, action = actions[math.random(#actions)]})
        end
    end

    if #availableActions > 0 then
        local randomAction = availableActions[math.random(#availableActions)]
        return randomAction.type, randomAction.action
    end

    -- No actions available
    return nil, nil
end


-- Example usage:
-- local gameState = GetGameState()
-- PrintGameStateSummary(gameState)