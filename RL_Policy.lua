-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");
include("PopupDialog");

-- Then our mod files
include("civobvRL");
include("civactionsRL");
include("rewardFunction");
include("storage");
include("matrix");

-- Constants for embedding sizes and transformer config
local STATE_EMBED_SIZE = 256 -- This needs to be calculated based on your encoding
local CITY_EMBED_SIZE = 64 
local UNIT_EMBED_SIZE = 32
local TILE_EMBED_SIZE = 16
local MAX_CITIES = 20
local MAX_UNITS = 40
local MAX_TILES = 100
local TRANSFORMER_DIM = 512 -- Dimension of the transformer model
local TRANSFORMER_HEADS = 8 -- Number of attention heads
local TRANSFORMER_LAYERS = 4 -- Number of transformer layers



function tableToMatrix(tbl)
    local rows = #tbl
    local cols = #tbl[1]  -- Assumes all rows have the same number of columns
    local mtx = matrix:new(rows, cols)
    for i = 1, rows do
        for j = 1, cols do
            mtx:setelement(i, j, tbl[i][j])
        end
    end
    return mtx
end

function matrixToTable(mtx)
    local size = mtx:size()  -- Returns table {rows, cols}
    local rows = size[1]
    local cols = size[2]
    local tbl = {}
    for i = 1, rows do
        tbl[i] = {}
        for j = 1, cols do
            tbl[i][j] = mtx:getelement(i, j)
        end
    end
    return tbl
end
-- Helper function to normalize values to [0,1] range
function Normalize(value, maxValue)
    if maxValue == 0 then return 0 end
    return value / maxValue
end

-- Create embedding for a single unit
function EncodeUnitState(unit)
    local unitEmbed = {}
    
    -- Basic stats normalized to [0,1]
    table.insert(unitEmbed, Normalize(unit.Combat or 0, 100))
    table.insert(unitEmbed, Normalize(unit.RangedCombat or 0, 100))
    table.insert(unitEmbed, Normalize(unit.BombardCombat or 0, 100))
    table.insert(unitEmbed, Normalize(unit.Damage or 0, unit.MaxDamage or 100))
    table.insert(unitEmbed, Normalize(unit.Moves, unit.MaxMoves))
    table.insert(unitEmbed, Normalize(unit.Level, 10))
    table.insert(unitEmbed, Normalize(unit.Experience, 100))
    table.insert(unitEmbed, Normalize(unit.ActionCharges or 0, 5))
    table.insert(unitEmbed, Normalize(unit.Position.X, 100)) -- Need to normalize based on map size
    table.insert(unitEmbed, Normalize(unit.Position.Y, 100))

    -- Pad to fixed size
    while #unitEmbed < UNIT_EMBED_SIZE do
        table.insert(unitEmbed, 0)
    end
    
    return unitEmbed
end

function EncodeTileState(tile)
    local tileEmbed = {}
    
    -- Basic tile info
    table.insert(tileEmbed, tile.IsVisible and 1 or 0)
    table.insert(tileEmbed, tile.IsWater and 1 or 0)
    table.insert(tileEmbed, tile.IsImpassable and 1 or 0)
    table.insert(tileEmbed, tile.IsCity and 1 or 0)
    table.insert(tileEmbed, tile.IsPillaged and 1 or 0)
    table.insert(tileEmbed, tile.IsWorked and 1 or 0)
    table.insert(tileEmbed, Normalize(tile.Appeal, 10))
    
    -- Yields
    table.insert(tileEmbed, Normalize(tile.Yields.Food, 10))
    table.insert(tileEmbed, Normalize(tile.Yields.Production, 10))
    table.insert(tileEmbed, Normalize(tile.Yields.Gold, 10))
    table.insert(tileEmbed, Normalize(tile.Yields.Science, 5))
    table.insert(tileEmbed, Normalize(tile.Yields.Culture, 5))
    table.insert(tileEmbed, Normalize(tile.Yields.Faith, 5))
    
    -- Pad to fixed size
    while #tileEmbed < TILE_EMBED_SIZE do
        table.insert(tileEmbed, 0)
    end
    
    return tileEmbed
end

function EncodeCityState(city)
    local cityEmbed = {}
    
    -- Basic stats normalized to [0,1]
    table.insert(cityEmbed, Normalize(city.Population, 20))
    table.insert(cityEmbed, city.IsCapital and 1 or 0)
    table.insert(cityEmbed, Normalize(city.DistrictsNum, city.DistrictsPossibleNum))
    table.insert(cityEmbed, Normalize(city.GoldPerTurn, 100))
    table.insert(cityEmbed, Normalize(city.FoodPerTurn, 50))
    table.insert(cityEmbed, Normalize(city.ProductionPerTurn, 100))
    table.insert(cityEmbed, Normalize(city.SciencePerTurn, 50))
    table.insert(cityEmbed, Normalize(city.CulturePerTurn, 50))
    table.insert(cityEmbed, Normalize(city.FaithPerTurn, 50))
    table.insert(cityEmbed, Normalize(city.Housing, 20))
    table.insert(cityEmbed, Normalize(city.Defense, 100))
    table.insert(cityEmbed, city.IsUnderSiege and 1 or 0)
    table.insert(cityEmbed, Normalize(city.AmenitiesNetAmount, 10))

    -- Pad to fixed size
    while #cityEmbed < CITY_EMBED_SIZE do
        table.insert(cityEmbed, 0)
    end
    
    return cityEmbed
end

function EncodeTechState(techs)
    local techEmbed = {}
    
    -- For each tech, encode both if it's researched and its progress if in progress
    for _, tech in ipairs(techs) do
        table.insert(techEmbed, tech.IsUnlocked and 1 or 0)
        table.insert(techEmbed, tech.Progress or 0) 
        table.insert(techEmbed, tech.IsBoosted and 1 or 0)
    end
    
    return techEmbed
end

function EncodeCivicState(civics)
    local civicEmbed = {}
    
    for _, civic in ipairs(civics) do
        table.insert(civicEmbed, civic.IsUnlocked and 1 or 0)
        table.insert(civicEmbed, civic.Progress or 0)
        table.insert(civicEmbed, civic.IsBoosted and 1 or 0)
    end
    
    return civicEmbed
end

-- Encode victory progress
function EncodeVictoryProgress(victoryProgress)
    local victoryEmbed = {}
    
    -- Normalize progress values for each victory type
    table.insert(victoryEmbed, Normalize(victoryProgress.Science or 0, 100))
    table.insert(victoryEmbed, Normalize(victoryProgress.Culture or 0, 100))
    
    return victoryEmbed
end

-- Add diplomatic status encoding
function EncodeDiplomaticStatus(diplomaticStatuses)
    local diplomaticEmbed = {}
    
    for _, status in pairs(diplomaticStatuses) do
        -- Convert diplomatic state to numeric value
        local stateValue = 0
        if status.DiplomaticState == "DIPLO_STATE_ALLIED" then stateValue = 1
        elseif status.DiplomaticState == "DIPLO_STATE_DECLARED_FRIEND" then stateValue = 0.75
        elseif status.DiplomaticState == "DIPLO_STATE_FRIENDLY" then stateValue = 0.5
        elseif status.DiplomaticState == "DIPLO_STATE_NEUTRAL" then stateValue = 0.25
        elseif status.DiplomaticState == "DIPLO_STATE_UNFRIENDLY" then stateValue = -0.25
        elseif status.DiplomaticState == "DIPLO_STATE_DENOUNCED" then stateValue = -0.75
        elseif status.DiplomaticState == "DIPLO_STATE_WAR" then stateValue = -1
        end
        
        table.insert(diplomaticEmbed, stateValue)
        table.insert(diplomaticEmbed, status.HasMet and 1 or 0)
        table.insert(diplomaticEmbed, Normalize(status.Score, 100))
    end
    
    return diplomaticEmbed
end

-- Updated main encoding function
function EncodeGameState(state)
    local stateEmbed = {}
    
    -- Global stats (from previous implementation)
    table.insert(stateEmbed, Normalize(state.Gold, 1000))
    table.insert(stateEmbed, Normalize(state.Faith, 1000))
    table.insert(stateEmbed, Normalize(state.GoldPerTurn, 200))
    table.insert(stateEmbed, Normalize(state.FaithPerTurn, 100))
    table.insert(stateEmbed, Normalize(state.SciencePerTurn, 200))
    table.insert(stateEmbed, Normalize(state.CulturePerTurn, 200))
    table.insert(stateEmbed, state.IsInAnarchy and 1 or 0)
    
    -- Encode cities
    local cityEmbeds = {}
    for i = 1, math.min(#state.Cities, MAX_CITIES) do
        local cityEmbed = EncodeCityState(state.Cities[i])
        for _, value in ipairs(cityEmbed) do
            table.insert(stateEmbed, value)
        end
    end
    
    -- Pad remaining city slots
    local remainingCities = MAX_CITIES - #state.Cities
    if remainingCities > 0 then
        for i = 1, remainingCities * CITY_EMBED_SIZE do
            table.insert(stateEmbed, 0)
        end
    end
    
    -- Encode units
    for i = 1, math.min(#state.Units, MAX_UNITS) do
        local unitEmbed = EncodeUnitState(state.Units[i])
        for _, value in ipairs(unitEmbed) do
            table.insert(stateEmbed, value)
        end
    end
    
    -- Pad remaining unit slots
    local remainingUnits = MAX_UNITS - #state.Units
    if remainingUnits > 0 then
        for i = 1, remainingUnits * UNIT_EMBED_SIZE do
            table.insert(stateEmbed, 0)
        end
    end
    
    -- Encode visible and revealed tiles
    local allTiles = {}
    -- Combine visible and revealed tiles, prioritizing visible ones
    local seenTiles = {}
    
    for _, tile in ipairs(state.VisibleTiles) do
        local key = tile.X .. "," .. tile.Y
        seenTiles[key] = tile
        table.insert(allTiles, tile)
    end
    
    for _, tile in ipairs(state.RevealedTiles) do
        local key = tile.X .. "," .. tile.Y
        if not seenTiles[key] then
            table.insert(allTiles, tile)
        end
    end
    
    -- Take first MAX_TILES tiles
    for i = 1, math.min(#allTiles, MAX_TILES) do
        local tileEmbed = EncodeTileState(allTiles[i])
        for _, value in ipairs(tileEmbed) do
            table.insert(stateEmbed, value)
        end
    end
    
    -- Pad remaining tile slots
    local remainingTiles = MAX_TILES - #allTiles
    if remainingTiles > 0 then
        for i = 1, remainingTiles * TILE_EMBED_SIZE do
            table.insert(stateEmbed, 0)
        end
    end
    
    -- Add other state components
    local techEmbed = EncodeTechState(state.TechsResearched)
    local civicEmbed = EncodeCivicState(state.CivicsResearched)
    local victoryEmbed = EncodeVictoryProgress(state.VictoryProgress)
    local diplomaticEmbed = EncodeDiplomaticStatus(state.DiplomaticStatuses)
    
    -- Add all embeddings to final state
    for _, embed in ipairs({techEmbed, civicEmbed, victoryEmbed, diplomaticEmbed}) do
        for _, value in ipairs(embed) do
            table.insert(stateEmbed, value)
        end
    end
    -- Add government encoding
    local governmentEmbed = EncodeGovernment(state.CurrentGovernment)
    for _, value in ipairs(governmentEmbed) do
        table.insert(stateEmbed, value)
    end
    
    -- Add policy encoding
    local policyEmbed = EncodePolicies(state.CurrentPolicies)
    for _, value in ipairs(policyEmbed) do
        table.insert(stateEmbed, value)
    end
    
    -- Add spatial relations
    local mapWidth, mapHeight = Map.GetGridSize() -- Make sure this function exists in your environment
    local spatialEmbed = EncodeSpatialRelations(state.Cities, state.Units, mapWidth, mapHeight)
    for _, value in ipairs(spatialEmbed) do
        table.insert(stateEmbed, value)
    end
    while #stateEmbed < STATE_EMBED_SIZE do
        table.insert(stateEmbed, 0)
    end
    
    return stateEmbed
end

-- Add government type encoding
function EncodeGovernment(government)
    local governmentEmbed = {}
    
    -- If no government, return zero vector
    if not government then
        for i = 1, 10 do -- Fixed size for government embedding
            table.insert(governmentEmbed, 0)
        end
        return governmentEmbed
    end

    -- Encode government type as one-hot vector
    -- Common government types
    local govTypes = {
        "GOVERNMENT_AUTOCRACY",
        "GOVERNMENT_OLIGARCHY",
        "GOVERNMENT_CLASSICAL_REPUBLIC",
        "GOVERNMENT_MERCHANT_REPUBLIC",
        "GOVERNMENT_MONARCHY",
        "GOVERNMENT_THEOCRACY",
        "GOVERNMENT_DEMOCRACY",
        "GOVERNMENT_FASCISM",
        "GOVERNMENT_COMMUNISM"
    }
    
    for _, govType in ipairs(govTypes) do
        table.insert(governmentEmbed, government.Type == govType and 1 or 0)
    end

    -- Add a flag for any other government type
    table.insert(governmentEmbed, 1)
    
    return governmentEmbed
end

-- Add policy slot encoding
function EncodePolicies(currentPolicies)
    local policyEmbed = {}
    
    -- Define policy slot types
    local slotTypes = {
        "SLOT_MILITARY",
        "SLOT_ECONOMIC",
        "SLOT_DIPLOMATIC",
        "SLOT_WILDCARD"
    }
    
    -- Count number of each slot type being used
    local slotCounts = {}
    for _, slotType in ipairs(slotTypes) do
        slotCounts[slotType] = 0
    end
    
    -- Count used slots
    if currentPolicies then
        for _, policy in ipairs(currentPolicies) do
            if slotCounts[policy.SlotType] then
                slotCounts[policy.SlotType] = slotCounts[policy.SlotType] + 1
            end
        end
    end
    
    -- Add normalized slot counts to embedding
    for _, slotType in ipairs(slotTypes) do
        table.insert(policyEmbed, Normalize(slotCounts[slotType], 4)) -- Most governments have max 4 slots of any type
    end
    
    return policyEmbed
end

-- Add spatial encoding using relative positions
function EncodeSpatialRelations(cities, units, mapWidth, mapHeight)
    local spatialEmbed = {}
    
    -- Function to calculate normalized distance between two points
    local function getNormalizedDistance(x1, y1, x2, y2)
        local dx = math.min(math.abs(x1 - x2), mapWidth - math.abs(x1 - x2))
        local dy = math.min(math.abs(y1 - y2), mapHeight - math.abs(y1 - y2))
        local maxDistance = math.sqrt(mapWidth * mapWidth + mapHeight * mapHeight)
        return math.sqrt(dx * dx + dy * dy) / maxDistance
    end
    
    -- Function to get normalized position
    local function getNormalizedPosition(x, y)
        return x / mapWidth, y / mapHeight
    end

    -- For each city, encode:
    -- 1. Normalized position
    -- 2. Distance to capital
    -- 3. Average distance to other cities
    -- 4. Number of nearby units
    local capitalX, capitalY
    for i, city in ipairs(cities) do
        if city.IsCapital then
            capitalX, capitalY = city.X, city.Y
            break
        end
    end
    
    if capitalX then
        for _, city in ipairs(cities) do
            -- Normalized position
            local normX, normY = getNormalizedPosition(city.X, city.Y)
            table.insert(spatialEmbed, normX)
            table.insert(spatialEmbed, normY)
            
            -- Distance to capital
            if not city.IsCapital then
                local distToCapital = getNormalizedDistance(city.X, city.Y, capitalX, capitalY)
                table.insert(spatialEmbed, distToCapital)
            else
                table.insert(spatialEmbed, 0)
            end
            
            -- Average distance to other cities
            local totalDist = 0
            local cityCount = 0
            for _, otherCity in ipairs(cities) do
                if otherCity ~= city then
                    totalDist = totalDist + getNormalizedDistance(city.X, city.Y, otherCity.X, otherCity.Y)
                    cityCount = cityCount + 1
                end
            end
            table.insert(spatialEmbed, cityCount > 0 and totalDist/cityCount or 0)
            
            -- Count nearby units (within 3 tiles)
            local nearbyUnits = 0
            for _, unit in ipairs(units) do
                local dist = getNormalizedDistance(city.X, city.Y, unit.Position.X, unit.Position.Y)
                if dist < 0.1 then -- Adjust this threshold based on map size
                    nearbyUnits = nearbyUnits + 1
                end
            end
            table.insert(spatialEmbed, Normalize(nearbyUnits, 10))
        end
    end
    
    -- For each unit, encode:
    -- 1. Normalized position
    -- 2. Distance to nearest city
    -- 3. Distance to nearest friendly unit
    for _, unit in ipairs(units) do
        -- Normalized position
        local normX, normY = getNormalizedPosition(unit.Position.X, unit.Position.Y)
        table.insert(spatialEmbed, normX)
        table.insert(spatialEmbed, normY)
        
        -- Distance to nearest city
        local minCityDist = 1.0
        for _, city in ipairs(cities) do
            --we seem to be passing something wrong here, print
            local dist = getNormalizedDistance(unit.Position.X, unit.Position.Y, city.X, city.Y)
            minCityDist = math.min(minCityDist, dist)
        end
        table.insert(spatialEmbed, minCityDist)
        
        -- Distance to nearest friendly unit
        local minUnitDist = 1.0
        for _, otherUnit in ipairs(units) do
            if otherUnit ~= unit then
                local dist = getNormalizedDistance(
                    unit.Position.X, unit.Position.Y,
                    otherUnit.Position.X, otherUnit.Position.Y
                )
                minUnitDist = math.min(minUnitDist, dist)
            end
        end
        table.insert(spatialEmbed, minUnitDist)
    end
    
    return spatialEmbed
end

function SelectRandomAction(possibleActions)
    -- Get list of action types that have available actions
    local availableActionTypes = {}
    for actionType, actions in pairs(possibleActions) do
        if type(actions) == "table" and #actions > 0 then
            table.insert(availableActionTypes, actionType) 
        end
    end

    -- If no actions, return EndTurn
    if #availableActionTypes == 0 then
        return "EndTurn", {}
    end

    -- Pick random action type and random action from that type
    local actionType = availableActionTypes[math.random(#availableActionTypes)]
    local actionParams = possibleActions[actionType][math.random(#possibleActions[actionType])]
    
    return actionType, actionParams
end

-- Calculate the actual state embedding size based on your encoding functions and constants
STATE_EMBED_SIZE = 7 -- Global stats
                   + (MAX_CITIES * CITY_EMBED_SIZE)
                   + (MAX_UNITS * UNIT_EMBED_SIZE)
                   + (MAX_TILES * TILE_EMBED_SIZE)
                   + 3 -- Tech embed (assuming each tech has 3 values: IsUnlocked, Progress, IsBoosted)
                   + 3 -- Civic embed (similar assumption as tech)
                   + 2 -- Victory progress (assuming 2 values: Science, Culture)
                   + 3 -- Diplomatic status (assuming each status has 3 values: stateValue, HasMet, Score)
                   + 10 -- Government embedding size (as defined in EncodeGovernment)
                   + 4  -- Policy embedding size (as defined in EncodePolicies)
                   + 5 * MAX_CITIES -- Spatial relations for cities (assuming 5 values per city)
                   + 4 * MAX_UNITS; -- Spatial relations for units (assuming 4 values per unit)

CivTransformerPolicy = {}

-- 1. State Embedding Layer (Initialization)
function CivTransformerPolicy:InitStateEmbedding()
    -- Use matrix directly
    self.state_embedding_weights = matrix.random(matrix:new(STATE_EMBED_SIZE, TRANSFORMER_DIM))
    -- Scale the random values to be between 0.1 and 2
    for i = 1, STATE_EMBED_SIZE do
        for j = 1, TRANSFORMER_DIM do
            local val = self.state_embedding_weights:getelement(i,j)
            self.state_embedding_weights:setelement(i, j, val * 1.9 + 0.1)
        end
    end
end

function CivTransformerPolicy:AddPositionalEncoding(state_embedding)
    -- Convert input to matrix if it isn't already
    local input_mtx = type(state_embedding.getelement) == "function" and 
                     state_embedding or 
                     tableToMatrix(state_embedding)
    
    local rows, cols = input_mtx:size()[1], input_mtx:size()[2]
    local pos_encoding = matrix:new(rows, cols)
    
    for i = 1, rows do
        for j = 1, cols do
            local positional_value
            if j % 2 == 0 then
                positional_value = math.sin(i / (10000 ^ (2 * (j / 2) / cols)))
            else
                positional_value = math.cos(i / (10000 ^ (2 * ((j - 1) / 2) / cols)))
            end
            pos_encoding:setelement(i, j, input_mtx:getelement(i, j) + positional_value)
        end
    end
    return pos_encoding
end


function CivTransformerPolicy:Attention(query, key, value, mask)
    -- Calculate attention scores using matrix operations
    local d_k = key:columns()
    local attention_scores = matrix.mul(query, matrix.transpose(key))
    attention_scores = matrix.divnum(attention_scores, math.sqrt(d_k))
    
    -- Apply mask if provided
    if mask then
        attention_scores = matrix.replace(attention_scores, function(x, i, j)
            return mask:getelement(i, j) == 0 and x or -1e9
        end)
    end
    
    -- Apply softmax
    local attention_weights = matrix.softmax(attention_scores)
    
    -- Calculate attention output
    return matrix.mul(attention_weights, value)
end

-- Multi-Head Attention
function CivTransformerPolicy:MultiHeadAttention(query, key, value, mask)
    local d_k = self.d_k
    local num_heads = self.num_heads
    local batch_size = query:size()[1]
    
    -- Linear projections for all heads at once
    local q_projected = matrix:new(batch_size * num_heads, d_k)
    local k_projected = matrix:new(batch_size * num_heads, d_k)
    local v_projected = matrix:new(batch_size * num_heads, d_k)
    
    -- Project queries, keys, and values for all heads simultaneously
    for h = 1, num_heads do
        local offset = (h-1) * batch_size
        local q_head = matrix.mul(query, self.head_projections.w_q[h])
        local k_head = matrix.mul(key, self.head_projections.w_k[h])
        local v_head = matrix.mul(value, self.head_projections.w_v[h])
        
        -- Copy into the combined matrices
        for i = 1, batch_size do
            for j = 1, d_k do
                q_projected:setelement(offset + i, j, q_head:getelement(i, j))
                k_projected:setelement(offset + i, j, k_head:getelement(i, j))
                v_projected:setelement(offset + i, j, v_head:getelement(i, j))
            end
        end
    end
    
    -- Compute attention for all heads simultaneously
    local attention_output = self:Attention(q_projected, k_projected, v_projected, mask)
    
    -- Reshape and concatenate heads
    local output = matrix:new(batch_size, self.d_model)
    for h = 1, num_heads do
        local offset = (h-1) * batch_size
        local head_output = matrix.subm(attention_output, 
                                      offset + 1, 1, 
                                      offset + batch_size, d_k)
        
        -- Copy head output to appropriate columns
        local col_offset = (h-1) * d_k
        for i = 1, batch_size do
            for j = 1, d_k do
                output:setelement(i, col_offset + j, head_output:getelement(i, j))
            end
        end
    end
    
    -- Final projection
    return matrix.mul(output, self.w_o)
end

function CivTransformerPolicy:Feedforward(input_mtx)
    -- Define dimensions
    local d_model = input_mtx:columns()
    local d_ff = 2048

    -- Initialize weights and biases as matrices
    local w1 = matrix.random(matrix:new(d_model, d_ff))
    local b1 = matrix.random(matrix:new(1, d_ff))
    local w2 = matrix.random(matrix:new(d_ff, d_model))
    local b2 = matrix.random(matrix:new(1, d_model))

    -- First linear layer + ReLU activation
    local layer1_output = matrix.add(matrix.mul(input_mtx, w1), matrix.repmat(b1, input_mtx:rows(), 1))
    layer1_output = matrix.relu(layer1_output)

    -- Second linear layer
    return matrix.add(matrix.mul(layer1_output, w2), matrix.repmat(b2, input_mtx:rows(), 1))
end

-- Helper function for layer normalization (simplified for now)
function CivTransformerPolicy:LayerNorm(input_mtx)
    -- Current implementation calculates means and variances using loops
    -- Let's use matrix operations instead:
    
    local epsilon = 1e-6
    local rows, cols = input_mtx:size()[1], input_mtx:size()[2]
    
    -- Calculate mean for each row using matrix operations
    local ones_col = matrix:new(cols, 1, 1)  -- Column vector of ones
    local means = matrix.mul(input_mtx, ones_col)
    means = matrix.divnum(means, cols)  -- Now a rows x 1 matrix
    
    -- Broadcast mean for subtraction
    local means_broadcast = matrix.mul(means, matrix:new(1, cols, 1))
    
    -- Calculate variance using matrix operations
    local centered = matrix.sub(input_mtx, means_broadcast)
    local squared = matrix.replace(centered, function(x) return x * x end)
    local variances = matrix.mul(squared, ones_col)
    variances = matrix.divnum(variances, cols)
    
    -- Broadcast variance for division
    local std_broadcast = matrix.mul(
        matrix.replace(variances, function(x) return math.sqrt(x + epsilon) end),
        matrix:new(1, cols, 1)
    )
    
    -- Normalize
    return matrix.divnum(centered, std_broadcast)
end

-- 5. Transformer Layer (Complete with Feedforward, Residual Connections, and Layer Normalization)
function CivTransformerPolicy:TransformerLayer(input, mask)
    -- Convert to matrix
    local input_mtx = tableToMatrix(input)
    
    local attention_output = self:MultiHeadAttention(input_mtx, input_mtx, input_mtx, mask)
    
    -- Still in matrix form, good!
    local add_norm_output_1 = self:LayerNorm(matrix.add(input_mtx, attention_output))
    
    -- Unnecessarily converts to table and back to matrix
    local ff_output_tbl = self:Feedforward(matrixToTable(add_norm_output_1)) 
    local ff_output_mtx = tableToMatrix(ff_output_tbl)
    
    -- More matrix operations
    local add_norm_output_2 = self:LayerNorm(matrix.add(add_norm_output_1, ff_output_mtx))
    
    -- Final conversion back to table
    local output_tbl = matrixToTable(add_norm_output_2)
    return output_tbl
end

-- 6. Transformer Encoder 
function CivTransformerPolicy:TransformerEncoder(input, mask)
    local encoder_output = input
    for i = 1, TRANSFORMER_LAYERS do
        --print length of encoder_output
        print("Encoder Output Length before transformer layer:", #encoder_output)
        encoder_output = self:TransformerLayer(encoder_output, mask)
    end
    return encoder_output
end

--[[
-- 7. Output Layers (Placeholders)
-- Action Type Head
function CivTransformerPolicy:ActionTypeHead(input)
    -- Placeholder for the action type output layer
    return {} -- Placeholder: should return a table of action type probabilities
end

-- Parameter Heads
function CivTransformerPolicy:ParameterHeads(input)
    -- Placeholder for the parameter output layers
    return {} -- Placeholder: should return a table of parameter probabilities for each action type
end

-- Value Head
function CivTransformerPolicy:ValueHead(input)
    -- Placeholder for the value output layer
    return 0 -- Placeholder: should return a single value
end
--]]

-- Initialization of the Policy Network
function CivTransformerPolicy:Init()
    -- Existing embedding initialization
    self:InitStateEmbedding()
    
    -- Multi-head attention parameters
    self.num_heads = TRANSFORMER_HEADS
    self.d_model = TRANSFORMER_DIM
    self.d_k = self.d_model / self.num_heads

    -- Initialize projection matrices for each head
    self.head_projections = {
        w_q = {},  -- (d_model, d_k) per head
        w_k = {},
        w_v = {}
    }
    
    -- Xavier initialization helper
    local function xavier_init(rows, cols)
        local std = math.sqrt(2.0 / (rows + cols))
        local mtx = matrix:new(rows, cols, 0)  -- Create matrix filled with 0s
        
        -- Manually set each element with random values
        for i = 1, mtx:rows() do
            for j = 1, mtx:columns() do
                -- Generate random value in [-std, std] range
                local val = math.random() * 2 * std - std
                mtx:setelement(i, j, val)
            end
        end
        
        return mtx
    end
    for i = 1, self.num_heads do
        self.head_projections.w_q[i] = xavier_init(self.d_model, self.d_k)
        self.head_projections.w_k[i] = xavier_init(self.d_model, self.d_k)
        self.head_projections.w_v[i] = xavier_init(self.d_model, self.d_k)
    end

    -- Final projection matrix
    self.w_o = xavier_init(self.d_model, self.d_model)
end

function CivTransformerPolicy:PadStateEmbed(state_embed)

    print("State Embedding Size:", #state_embed)
    return state_embed
end

-- Forward Pass (Placeholder)
function CivTransformerPolicy:Forward(state_embed, possible_actions)
    -- Convert state_embed to matrix if needed
    local state_mtx = type(state_embed.getelement) == "function" and 
                     state_embed or 
                     tableToMatrix({state_embed})
    
    -- Embed state using matrix multiplication
    local embedded_state = matrix.mul(state_mtx, self.state_embedding_weights)
    
    -- Add positional encoding (already matrix-based)
    embedded_state = self:AddPositionalEncoding(embedded_state)
    
    -- Create attention mask
    local mask = self:CreateAttentionMask(possible_actions)
    
    -- Pass through transformer (now all matrix-based)
    local transformer_output = self:TransformerEncoder(embedded_state, mask)
    
    -- Output heads (need to be implemented as matrix operations)
    local action_type_probs = self:ActionTypeHead(transformer_output)
    local action_params_probs = self:ParameterHeads(transformer_output)
    local value = self:ValueHead(transformer_output)
    
    return action_type_probs, action_params_probs, value
end

--[[
-- Example usage (for now, without actual actions or parameters)
local state = GetPlayerData(Game.GetLocalPlayer())
local encoded_state = EncodeGameState(state)
local possible_actions = GetPossibleActions()

CivTransformerPolicy:Init()
local action_type_probs, action_params_probs, value = CivTransformerPolicy:Forward(encoded_state, possible_actions)

-- Print the outputs (for demonstration purposes)
print("Action Type Probabilities:", action_type_probs)
print("Action Parameter Probabilities:", action_params_probs)
print("Value:", value)
--]]

-- Main state encoding function
-- Add encoding for tech/civic progress