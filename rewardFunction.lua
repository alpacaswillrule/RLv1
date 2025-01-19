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
    local score = 0
    
    -- Base yields
    score = score + (city.GoldPerTurn * weights.gold)
    score = score + (city.ProductionPerTurn * weights.production)
    score = score + (city.SciencePerTurn * weights.science)
    score = score + (city.CulturePerTurn * weights.culture)
    
    -- Faith special case - reward if >= 1, penalize if < 1
    if city.FaithPerTurn >= 1 then
        score = score + (city.FaithPerTurn * weights.faith)
    else
        score = score - ((1 - city.FaithPerTurn) * weights.faith)
    end
    
    -- Other city metrics
    score = score + city.AmenitiesNetAmount * 2  -- Happiness bonus
    score = score + city.BuildingsNum * 1.5      -- Building bonus
    score = score + city.FoodSurplus * 1.5       -- Growth potential
    score = score + city.HousingMultiplier * 1.5 -- Room for growth
    
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
function CalculateReward(gameState)
    local score = 0
    local weights = GetYieldWeights(GetTurnNumber())
    
    -- Victory progress (science and culture)
    if gameState.VictoryProgress then
        score = score + (gameState.VictoryProgress.Science * 50)
        score = score + (gameState.VictoryProgress.Culture * 50)
    end
    
    -- Cities
    local cityScore = 0
    for _, city in ipairs(gameState.Cities) do
        cityScore = cityScore + GetCityQualityScore(city, weights)
    end
    score = score + cityScore
    score = score + (#gameState.Cities * 50)  -- Base score per city
    
    -- Wonders
    local wonderScore = 0
    for _, city in ipairs(gameState.Cities) do
        wonderScore = wonderScore + GetWonderScore(city.Wonders)
    end
    score = score + wonderScore
    
    -- Units and improvements
    score = score + GetUnitScore(gameState.Units)
    score = score + GetTileImprovementScore(gameState.VisibleTiles)
    
    -- Districts
    score = score + GetDistrictScore(gameState.VisibleTiles)
    
    -- Research progress
    score = score + (#gameState.TechsResearched * 20)  -- Points per completed tech
    score = score + (#gameState.CivicsResearched * 20) -- Points per completed civic
    
    -- Map exploration
    score = score + (#gameState.VisibleTiles * 0.1)    -- Small bonus for revealed tiles
    
    -- Policies
    if gameState.CurrentPolicies then
        score = score + (#gameState.CurrentPolicies * 15) -- Points per active policy
    end
    
    -- Trade routes
    if gameState.TradeRoutes then
        score = score + (gameState.TradeRoutes.Active * 25) -- Points per active trade route
    end
    
    -- Great People Points
    if gameState.GreatPeoplePointsPerTurn then
        for _, points in pairs(gameState.GreatPeoplePointsPerTurn) do
            score = score + (points * 2)  -- Points for GPP generation
        end
    end
    
    return score
end
