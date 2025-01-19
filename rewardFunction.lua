-- rewardFunction.lua
-- Reward function for evaluating game state

-- Yield weights based on game turn
local function GetYieldWeights(turn)
    if turn < 12 then
        return {
            faith = 2,
            culture = 1.5,
            science = 1,
            production = 1,
            gold = 0.5
        }
    else
        return {
            faith = 0.5,
            culture = 2,
            science = 1.5,
            production = 2,
            gold = 0.5
        }
    end
end

-- Calculate city quality score
local function GetCityQualityScore(city, weights)
    if not city or not weights then return 0 end
    
    local score = 0
    
    -- Base yields with nil checks
    score = score + ((city.GoldPerTurn or 0) * weights.gold)
    score = score + ((city.ProductionPerTurn or 0) * weights.production)
    score = score + ((city.SciencePerTurn or 0) * weights.science)
    score = score + ((city.CulturePerTurn or 0) * weights.culture)
    
    -- Faith special case with nil check
    local faithPerTurn = city.FaithPerTurn or 0
    if faithPerTurn >= 1 then
        score = score + (faithPerTurn * weights.faith)
    else
        score = score - ((1 - faithPerTurn) * weights.faith)
    end
    
    -- Other city metrics with nil checks
    score = score + ((city.AmenitiesNetAmount or 0) * 2)
    score = score + ((city.BuildingsNum or 0) * 1.5)
    score = score + ((city.FoodSurplus or 0) * 1.5)
    score = score + ((city.HousingMultiplier or 0) * 1.5)
    
    return score
end

-- Calculate wonder score
local function GetWonderScore(wonders)
    local score = 0
    for _, wonder in ipairs(wonders) do
        -- Small bonus for each wonder
        score = score + 5
        
        -- Additional small bonus based on yields
        if wonder.YieldChange then
            score = score + wonder.YieldChange * 0.5
        end
    end
    return score
end

-- Calculate unit score
local function GetUnitScore(units)
    local score = 0
    local builderCount = 0
    local settlerCount = 0
    
    for _, unit in ipairs(units) do
        -- Check unit type
        if unit.UnitType == "UNIT_BUILDER" then
            builderCount = builderCount + 1
            -- Add bonus for remaining build charges
            if unit.Buildcharges then
                score = score + (unit.Buildcharges * 2)
            end
        elseif unit.UnitType == "UNIT_SETTLER" then
            settlerCount = settlerCount + 1
        end
    end
    
    -- Add base scores for civilian units
    score = score + (builderCount * 10)
    score = score + (settlerCount * 15)
    
    return score
end

-- Calculate tile improvement score
local function GetTileImprovementScore(visibleTiles)
    local score = 0
    local improvedTiles = 0
    local workedImprovedTiles = 0
    
    for _, tile in ipairs(visibleTiles) do
        if tile.ImprovementType then
            improvedTiles = improvedTiles + 1
            if tile.IsWorked then
                workedImprovedTiles = workedImprovedTiles + 1
            end
        end
    end
    
    -- Score regular improvements and worked improvements
    score = score + (improvedTiles * 2)
    score = score + (workedImprovedTiles * 4)
    
    return score
end

-- Calculate district score
local function GetDistrictScore(visibleTiles)
    local score = 0
    for _, tile in ipairs(visibleTiles) do
        if tile.DistrictType then
            score = score + 10  -- Base score for each district
        end
    end
    return score
end

-- Main reward function
-- Main reward function with nil value handling
function CalculateReward(gameState)
    if not gameState then return 0 end
    
    local score = 0
    local weights = GetYieldWeights(GetTurnNumber())
    
    -- Victory progress (science and culture) with nil checks
    local scienceProgress = 0
    local cultureProgress = 0
    if gameState.VictoryProgress then
        scienceProgress = (gameState.VictoryProgress.Science or 0)
        cultureProgress = (gameState.VictoryProgress.Culture or 0)
    end
    score = score + (scienceProgress * 50)
    score = score + (cultureProgress * 50)
    
    -- Cities with nil checks
    local cityScore = 0
    if gameState.Cities then
        for _, city in ipairs(gameState.Cities) do
            if city then
                cityScore = cityScore + GetCityQualityScore(city, weights)
            end
        end
        score = score + cityScore
        score = score + (#gameState.Cities * 50)  -- Base score per city
    end
    
    -- Wonders with nil checks
    local wonderScore = 0
    if gameState.Cities then
        for _, city in ipairs(gameState.Cities) do
            if city and city.Wonders then
                wonderScore = wonderScore + GetWonderScore(city.Wonders)
            end
        end
    end
    score = score + wonderScore
    
    -- Units and improvements with nil checks
    if gameState.Units then
        score = score + GetUnitScore(gameState.Units)
    end
    if gameState.VisibleTiles then
        score = score + GetTileImprovementScore(gameState.VisibleTiles)
        score = score + GetDistrictScore(gameState.VisibleTiles)
        score = score + (#gameState.VisibleTiles * 0.1)    -- Small bonus for revealed tiles
    end
    
    -- Research progress with nil checks
    if gameState.TechsResearched then
        score = score + (#gameState.TechsResearched * 20)
    end
    if gameState.CivicsResearched then
        score = score + (#gameState.CivicsResearched * 20)
    end
    
    -- Policies with nil check
    if gameState.CurrentPolicies then
        score = score + (#gameState.CurrentPolicies * 15)
    end
    
    -- Trade routes with nil checks
    if gameState.TradeRoutes and gameState.TradeRoutes.Active then
        score = score + (gameState.TradeRoutes.Active * 25)
    end
    
    -- Great People Points with nil checks
    if gameState.GreatPeoplePointsPerTurn then
        for _, points in pairs(gameState.GreatPeoplePointsPerTurn) do
            if points then
                score = score + (points * 2)
            end
        end
    end
    
    return score
end
