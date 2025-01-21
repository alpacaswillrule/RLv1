-- Save game history

-- Include serialization library
-- https://github.com/fab13n/metalua/blob/no-dll/src/lib/serialize.lua
include("serialize")

-- Create mod groups
function CreateGroups(str)
    local g = Modding.GetCurrentModGroup()
    local currentGroup = Modding.GetCurrentModGroup()
    Modding.CreateModGroup(str, currentGroup)
    Modding.SetCurrentModGroup(g)
end

function deserialize(str)
    if not str then return nil end
    local fn, err = loadstring(str)
    if not fn then
        error("Failed to deserialize: " .. (err or "unknown error"))
    end
    return fn()
end

-- Helper function to determine if a value is serializable
function IsSerializable(value)
    local valueType = type(value)
    return valueType == "number" or 
           valueType == "string" or 
           valueType == "boolean" or 
           valueType == "nil" or
           valueType == "table"
end

function CleanTableForSerialization(data, depth)
    if type(data) ~= "table" then return data end
    if depth > 100 then return nil end -- Prevent infinite recursion
    
    local cleanData = {}
    
    for key, value in pairs(data) do
        -- Skip if key is userdata
        if type(key) ~= "userdata" then
            local valueType = type(value)
            
            if valueType == "userdata" then
                -- Skip userdata values
                cleanData[key] = nil
            elseif valueType == "table" then
                -- Recursively clean nested tables
                cleanData[key] = CleanTableForSerialization(value, depth + 1)
            elseif IsSerializable(value) then
                -- Keep serializable values as-is
                cleanData[key] = value
            end
        end
    end
    
    return cleanData
end

-- Store table data
function Storage_table(t, title)
    if not title or title == "" then
        return
    end

    local Title = "[size_0][" .. tostring(title) .. "]["
    local groups = Modding.GetModGroups()
    
    -- Delete existing groups with same title prefix
    for i, v in ipairs(groups) do
        if Title == string.sub(v.Name, 1, #Title) then
            Modding.DeleteModGroup(v.Handle)
        end
    end

    local Para = 1
    local InfoStr = serialize(t)
    
    -- Split data into chunks of 2000 characters
    for i = 1, #InfoStr, 2000 do
        local iStr = Title .. tostring(Para) .. "]" .. string.sub(InfoStr, i, i + 1999)
        Para = Para + 1
        CreateGroups(iStr)
    end
end

function Read_tableString(title)
    if not title or title == "" then
        return
    end

    local Title = "[size_0][" .. tostring(title) .. "]["
    local Tstrings = {}
    local tableString = ""
    local groups = Modding.GetModGroups()
    
    -- Collect all chunks with matching title prefix
    for i, v in ipairs(groups) do
        if Title == string.sub(v.Name, 1, #Title) then
            local Str = string.sub(v.Name, #Title + 1)
            local sp = string.find(Str, "]")
            local Para = tonumber(string.sub(Str, 1, sp - 1))
            Tstrings[Para] = string.sub(Str, sp + 1)
        end
    end
    
    -- Combine chunks in order
    for i, v in ipairs(Tstrings) do
        tableString = tableString .. v
    end
    
    return deserialize(tableString)
end
-- Save game history with identifier
function SaveGameHistory(gameHistory, gameId)
    local prefix = "rl_history_" .. gameId .. "_"
    
    -- Convert gameHistory into separate chunks
    local chunks = {
        main = {
            episode_number = gameHistory.episode_number,
            victory_type = gameHistory.victory_type,
            total_turns = gameHistory.total_turns,
            game_id = gameId  -- Store the ID with the data
        },
        transitions = gameHistory.transitions
    }

    -- Save main info
    Storage_table(chunks.main, prefix .. "main")
    
    -- Save transitions in batches of 50
    local transitionBatches = {}
    for i = 1, #chunks.transitions, 50 do
        local batch = {}
        for j = i, math.min(i + 49, #chunks.transitions) do
            table.insert(batch, chunks.transitions[j])
        end
        transitionBatches[math.ceil(i/50)] = batch
    end
    
    -- Save number of batches
    Storage_table({count = #transitionBatches}, prefix .. "batch_count")
    
    -- Save each batch
    for i, batch in ipairs(transitionBatches) do
        Storage_table(batch, prefix .. "transitions_" .. i)
    end

    -- Update game index
    local gameIndex = Read_tableString("rl_history_index") or {games = {}}
    gameIndex.games[gameId] = {
        savedAt = os.time(),
        episodeNumber = gameHistory.episode_number,
        victoryType = gameHistory.victory_type,
        totalTurns = gameHistory.total_turns
    }
    Storage_table(gameIndex, "rl_history_index")
end

-- Load specific game history
function LoadGameHistory(gameId)
    local prefix = "rl_history_" .. gameId .. "_"
    
    local gameHistory = {
        transitions = {},
        episode_number = 0,
        victory_type = nil,
        total_turns = 0
    }
    
    -- Load main info
    local mainInfo = Read_tableString(prefix .. "main")
    if mainInfo then
        gameHistory.episode_number = mainInfo.episode_number
        gameHistory.victory_type = mainInfo.victory_type
        gameHistory.total_turns = mainInfo.total_turns
    end
    
    -- Load transitions
    local batchCount = Read_tableString(prefix .. "batch_count")
    if batchCount then
        for i = 1, batchCount.count do
            local batch = Read_tableString(prefix .. "transitions_" .. i)
            if batch then
                for _, transition in ipairs(batch) do
                    table.insert(gameHistory.transitions, transition)
                end
            end
        end
    end
    
    return gameHistory
end

-- Get list of all saved games
function GetSavedGamesList()
    local gameIndex = Read_tableString("rl_history_index")
    return gameIndex and gameIndex.games or {}
end

-- Clear specific game history
function ClearGameHistory(gameId)
    local prefix = "rl_history_" .. gameId .. "_"
    
    -- Clear all saved data for this game
    Storage_table({}, prefix .. "main")
    Storage_table({}, prefix .. "batch_count")
    
    -- Clear transition batches
    for i = 1, 100 do  -- Reasonable maximum number of batches
        Storage_table({}, prefix .. "transitions_" .. i)
    end

    -- Update game index
    local gameIndex = Read_tableString("rl_history_index") or {games = {}}
    gameIndex.games[gameId] = nil
    Storage_table(gameIndex, "rl_history_index")
end

-- Clear all saved games
function ClearAllGameHistories()
    local gameIndex = Read_tableString("rl_history_index")
    if gameIndex then
        for gameId, _ in pairs(gameIndex.games) do
            ClearGameHistory(gameId)
        end
    end
    Storage_table({games = {}}, "rl_history_index")
end

-- Generate unique game ID (you can modify this based on your needs)
function GenerateGameID()
    return string.format("%d_%d", os.time(), math.random(1000, 9999))
end


-- Helper function to clean/convert gamestate data for serialization
function CleanStateForSerialization(state)
    if not state then return nil end
    
    -- Create base structure with known serializable data
    local cleanState = {
        -- Base values
        Gold = state.Gold,
        Faith = state.Faith,
        FaithPerTurn = state.FaithPerTurn,
        IsInAnarchy = state.IsInAnarchy,
        SciencePerTurn = state.SciencePerTurn,
        CulturePerTurn = state.CulturePerTurn,
        GoldPerTurn = state.GoldPerTurn,
        maintenance = state.maintenance,
        
        -- Complex structures
        VictoryProgress = state.VictoryProgress,
        Cities = {},
        Units = {},
        TechsResearched = state.TechsResearched,
        CivicsResearched = state.CivicsResearched,
        CurrentPolicies = state.CurrentPolicies,
        TradeRoutes = state.TradeRoutes,
        GreatPeoplePoints = state.GreatPeoplePoints,
        GreatPeoplePointsPerTurn = state.GreatPeoplePointsPerTurn,
        VisibleTiles = {},
        RevealedTiles = {},
    }

    -- Clean Cities data
    for _, city in ipairs(state.Cities) do
        local cleanCity = {
            -- Basic info
            CityName = city.CityName,
            Population = city.Population,
            IsCapital = city.IsCapital,
            Owner = city.Owner,
            
            -- Districts and Buildings
            DistrictsNum = city.DistrictsNum,
            DistrictsPossibleNum = city.DistrictsPossibleNum,
            BuildingsNum = city.BuildingsNum,
            BuildingsAndDistricts = CleanTableForSerialization(city.BuildingsAndDistricts, 1),
            
            -- Resources and Production
            GoldPerTurn = city.GoldPerTurn,
            FoodPerTurn = city.FoodPerTurn,
            ProductionPerTurn = city.ProductionPerTurn,
            SciencePerTurn = city.SciencePerTurn,
            FaithPerTurn = city.FaithPerTurn,
            CulturePerTurn = city.CulturePerTurn,
            
            -- Growth and Housing
            Housing = city.Housing,
            FoodSurplus = city.FoodSurplus,
            GrowthPercent = city.GrowthPercent,
            GrowthThreshold = city.GrowthThreshold,
            TurnsUntilGrowth = city.TurnsUntilGrowth,
            
            -- Amenities
            AmenitiesNetAmount = city.AmenitiesNetAmount,
            AmenitiesNum = city.AmenitiesNum,
            AmenitiesFromLuxuries = city.AmenitiesFromLuxuries,
            AmenitiesFromEntertainment = city.AmenitiesFromEntertainment,
            AmenitiesFromCivics = city.AmenitiesFromCivics,
            AmenitiesRequiredNum = city.AmenitiesRequiredNum,
            
            -- Combat and Defense
            Defense = city.Defense,
            CityWallTotalHP = city.CityWallTotalHP,
            CityWallHPPercent = city.CityWallHPPercent,
            IsUnderSiege = city.IsUnderSiege,
            
            -- Production
            CurrentProductionName = city.CurrentProductionName,
            CurrentProductionDescription = city.CurrentProductionDescription,
            CurrentTurnsLeft = city.CurrentTurnsLeft,
            
            -- Religion
            ReligionFollowers = city.ReligionFollowers,
            Religions = CleanTableForSerialization(city.Religions, 1),
            
            -- Other
            TradingPosts = CleanTableForSerialization(city.TradingPosts, 1),
            Wonders = CleanTableForSerialization(city.Wonders, 1),
            X = city.X,
            Y = city.Y
        }
        table.insert(cleanState.Cities, cleanCity)
    end

    -- Clean Units data
    for _, unit in ipairs(state.Units) do
        local cleanUnit = {
            Name = unit.Name,
            UnitType = unit.UnitType,
            Level = unit.Level,
            Experience = unit.Experience,
            
            -- Combat stats
            Combat = unit.Combat,
            RangedCombat = unit.RangedCombat,
            BombardCombat = unit.BombardCombat,
            AntiAirCombat = unit.AntiAirCombat,
            Range = unit.Range,
            
            -- Status
            Damage = unit.Damage,
            MaxDamage = unit.MaxDamage,
            Moves = unit.Moves,
            MaxMoves = unit.MaxMoves,
            Formation = unit.Formation,
            
            -- Charges
            ActionCharges = unit.ActionCharges,
            Buildcharges = unit.Buildcharges,
            
            -- Position
            Position = unit.Position
        }
        table.insert(cleanState.Units, cleanUnit)
    end

    -- Clean any other complex structures
    if state.CurrentGovernment then
        cleanState.CurrentGovernment = {
            Type = state.CurrentGovernment.Type,
            Name = state.CurrentGovernment.Name,
            Index = state.CurrentGovernment.Index
        }
    end

    -- Clean Diplomatic Statuses (removing any userdata)
    if state.DiplomaticStatuses then
        cleanState.DiplomaticStatuses = CleanTableForSerialization(state.DiplomaticStatuses, 1)
    end

    -- Clean City States info
    if state.CityStates then
        cleanState.CityStates = CleanTableForSerialization(state.CityStates, 1)
    end
    if state.VisibleTiles then
        for _, tile in ipairs(state.VisibleTiles) do
            local cleanTile = {
                X = tile.X,
                Y = tile.Y,
                TerrainType = tile.TerrainType,
                FeatureType = tile.FeatureType,
                ResourceType = tile.ResourceType,
                ImprovementType = tile.ImprovementType,
                DistrictType = tile.DistrictType,
                IsVisible = tile.IsVisible,
                IsRevealed = tile.IsRevealed,
                OwnerID = tile.OwnerID,
                Appeal = tile.Appeal,
                IsWater = tile.IsWater,
                IsImpassable = tile.IsImpassable,
                MovementCost = tile.MovementCost,
                IsCity = tile.IsCity,
                IsPillaged = tile.IsPillaged,
                HasRemovableFeature = tile.HasRemovableFeature,
                IsWorked = tile.IsWorked,
                Yields = {
                    Food = tile.Yields.Food,
                    Production = tile.Yields.Production,
                    Gold = tile.Yields.Gold,
                    Science = tile.Yields.Science,
                    Culture = tile.Yields.Culture,
                    Faith = tile.Yields.Faith
                }
            }
            table.insert(cleanState.VisibleTiles, cleanTile)
        end
    end

    -- Clean revealed tiles
    if state.RevealedTiles then
        for _, tile in ipairs(state.RevealedTiles) do
            local cleanTile = {
                X = tile.X,
                Y = tile.Y,
                TerrainType = tile.TerrainType,
                FeatureType = tile.FeatureType,
                ResourceType = tile.ResourceType,
                ImprovementType = tile.ImprovementType,
                DistrictType = tile.DistrictType,
                IsVisible = tile.IsVisible,
                IsRevealed = tile.IsRevealed,
                OwnerID = tile.OwnerID,
                Appeal = tile.Appeal,
                IsWater = tile.IsWater,
                IsImpassable = tile.IsImpassable,
                MovementCost = tile.MovementCost,
                IsCity = tile.IsCity,
                IsPillaged = tile.IsPillaged,
                HasRemovableFeature = tile.HasRemovableFeature,
                IsWorked = tile.IsWorked,
                Yields = {
                    Food = tile.Yields.Food,
                    Production = tile.Yields.Production,
                    Gold = tile.Yields.Gold,
                    Science = tile.Yields.Science,
                    Culture = tile.Yields.Culture,
                    Faith = tile.Yields.Faith
                }
            }
            table.insert(cleanState.RevealedTiles, cleanTile)
        end
    end




    return cleanState
end

-- Modified OnResearchChanged to use cleaned data
-- -- When ending a game
-- function OnGameEnd()
--     SaveGameHistory(m_gameHistory, m_gameHistory.game_id)
-- end

-- To list all saved games
function PrintSavedGames()
    local savedGames = GetSavedGamesList()
    for gameId, gameInfo in pairs(savedGames) do
        print(string.format("Game %s: Episode %d, Victory: %s, Turns: %d, Saved: %s",
            gameId,
            gameInfo.episodeNumber,
            gameInfo.victoryType or "None",
            gameInfo.totalTurns,
            os.date("%Y-%m-%d %H:%M:%S", gameInfo.savedAt)
        ))
    end
end