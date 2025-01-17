-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");
include("PopupDialog");

-- Then our mod files
include("civobvRL");
include("civactionsRL");


-- Function to select which action to take based on priorities
function SelectPrioritizedAction(possibleActions)
    
        -- Priority 0: Builder Actions (Improvements and Harvests)
        if possibleActions.BuildImprovement and #possibleActions.BuildImprovement > 0 then
            -- Look for builders that can make improvements
            for _, builderAction in ipairs(possibleActions.BuildImprovement) do
                if builderAction.ValidImprovements and #builderAction.ValidImprovements > 0 then
                    -- Randomly select one of the possible improvements
                    local randomImprovement = builderAction.ValidImprovements[math.random(#builderAction.ValidImprovements)]
                    print("Builder can construct improvement - selecting random improvement")
                    return "BuildImprovement", {
                        UnitID = builderAction.UnitID,
                        ImprovementHash = randomImprovement
                    }
                end
            end
        end
    
        -- Check for harvest actions
        if possibleActions.HarvestResource and #possibleActions.HarvestResource > 0 then
            -- Randomly select one of the possible harvest actions
            local randomHarvest = possibleActions.HarvestResource[math.random(#possibleActions.HarvestResource)]
            print("Builder can harvest resource - selecting random harvest")
            return "HarvestResource", randomHarvest
        end
    
    -- First check for available governor titles
    if possibleActions.AssignGovernorTitle and #possibleActions.AssignGovernorTitle > 0 then
        print("\n=== AVAILABLE GOVERNOR ACTIONS ===")
        
        -- First look for initial appointments
        for _, govAction in ipairs(possibleActions.AssignGovernorTitle) do
            if govAction.IsInitialAppointment then
                print("Can appoint new governor: " .. govAction.GovernorName)
                return "AssignGovernorTitle", govAction
            end
        end

        -- Then look for promotions
        for _, govAction in ipairs(possibleActions.AssignGovernorTitle) do
            if not govAction.IsInitialAppointment then
                print(string.format("Can promote %s with: %s (%s)", 
                    govAction.GovernorName,
                    govAction.PromotionName,
                    govAction.Description))
                return "AssignGovernorTitle", govAction
            end
        end
    end

    -- Then check for available city assignments
    if possibleActions.AssignGovernorToCity and #possibleActions.AssignGovernorToCity > 0 then
        print("\n=== AVAILABLE GOVERNOR ASSIGNMENTS ===")
        for _, assignment in ipairs(possibleActions.AssignGovernorToCity) do
            print(string.format("Can assign %s to city: %s", 
                assignment.GovernorName,
                assignment.CityName))
            -- Only take unassigned governors
            if not assignment.CurrentlyAssigned then
                return "AssignGovernorToCity", assignment
            end
        end
    end
    -- Check for highest priority actions first
        -- Priority 1: Establish highest-yield trade route if available
        if possibleActions.EstablishTradeRoute and #possibleActions.EstablishTradeRoute > 0 then
            -- Find trade route with highest total yield
            local bestRoute = possibleActions.EstablishTradeRoute[1]
            local bestYieldValue = 0
            
            -- Calculate initial best yield
            bestYieldValue = bestRoute.Yields.Food + bestRoute.Yields.Production + 
                            bestRoute.Yields.Gold + bestRoute.Yields.Science + 
                            bestRoute.Yields.Culture + bestRoute.Yields.Faith
            
            -- Compare with other routes
            for _, route in ipairs(possibleActions.EstablishTradeRoute) do
                local totalYield = route.Yields.Food + route.Yields.Production + 
                                 route.Yields.Gold + route.Yields.Science + 
                                 route.Yields.Culture + route.Yields.Faith
                
                -- Prefer routes with trading posts (20% yield bonus)
                if route.HasTradingPost then
                    totalYield = totalYield * 1.2
                end
                
                
                if totalYield > bestYieldValue then
                    bestYieldValue = totalYield
                    bestRoute = route
                end
            end
            
            print("Found optimal trade route to " .. bestRoute.DestinationCityName .. 
                  " with total yield value: " .. bestYieldValue)
            return "EstablishTradeRoute", bestRoute
        end

        -- Priority 2: Send Envoys to City States
        if possibleActions.SendEnvoy and #possibleActions.SendEnvoy > 0 then
            -- First look for city states where we're close to becoming suzerain
            for _, cityStateID in ipairs(possibleActions.SendEnvoy) do
                local cityState = Players[cityStateID]
                local envoyCount = cityState:GetInfluence():GetTokensReceived(Game.GetLocalPlayer())
                -- If we're one envoy away from becoming suzerain (6 envoys needed)
                if envoyCount == 5 then
                    print("Prioritizing envoy to city-state near suzerain status")
                    return "SendEnvoy", cityStateID
                end
            end
            
            -- Otherwise, just pick a random city state to send envoy to
            local randomCityState = possibleActions.SendEnvoy[math.random(#possibleActions.SendEnvoy)]
            print("Sending envoy to random city-state")
            return "SendEnvoy", randomCityState
        end


    -- Priority 1: Found Religion if possible
    -- if possibleActions.FoundReligion and #possibleActions.FoundReligion > 0 then
    --     print("Found religion action available - selecting it")
    --     return "FoundReligion", possibleActions.FoundReligion[1]
    -- end

    -- -- Priority 2: District Construction
    -- if possibleActions.CityProduction then
    --     for _, production in ipairs(possibleActions.CityProduction) do
    --         if production.ProductionType == "Districts" then
    --             print("District construction available - selecting it")
    --             -- Pick a random valid plot from the ValidPlots list
    --             local plotIndex = math.random(#production.ValidPlots)
    --             local plot = production.ValidPlots[plotIndex]
    --             return "CityProduction", {
    --                 CityID = production.CityID,
    --                 ProductionType = "Districts",
    --                 ProductionHash = production.ProductionHash,
    --                 PlotX = plot.X or plot.x,  -- Handle different possible key names
    --                 PlotY = plot.Y or plot.y
    --             }
    --         end
    --     end
    -- end

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

    -- -- Priority 4: Found Cities
    -- if possibleActions.FoundCity and #possibleActions.FoundCity > 0 then
    --     return "FoundCity", possibleActions.FoundCity[1]
    -- end

    -- -- Priority 5: Building Construction
    -- if possibleActions.CityProduction then
    --     local buildingProductions = {}
    --     for _, production in ipairs(possibleActions.CityProduction) do
    --         if production.ProductionType == "Buildings" then
    --             table.insert(buildingProductions, production)
    --         end
    --     end
    --     if #buildingProductions > 0 then
    --         return "CityProduction", buildingProductions[math.random(#buildingProductions)]
    --     end
    -- end

    -- -- Priority 6: Unit Production
    -- if possibleActions.CityProduction then
    --     local unitProductions = {}
    --     for _, production in ipairs(possibleActions.CityProduction) do
    --         if production.ProductionType == "Units" then
    --             table.insert(unitProductions, production)
    --         end
    --     end
    --     if #unitProductions > 0 then
    --         return "CityProduction", unitProductions[math.random(#unitProductions)]
    --     end
    -- end

    -- -- Priority 7: Move Units if available
    -- if possibleActions.MoveUnit and #possibleActions.MoveUnit > 0 then
    --     return "MoveUnit", possibleActions.MoveUnit[math.random(#possibleActions.MoveUnit)]
    -- end

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

end

-- Example usage:
-- local gameState = GetGameState()
-- PrintGameStateSummary(gameState)