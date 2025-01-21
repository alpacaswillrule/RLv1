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
    local rows, cols = mtx:size()
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
    -- Initialize weights for the state embedding layer
    self.state_embedding_weights = {}
    for i = 1, STATE_EMBED_SIZE do
        self.state_embedding_weights[i] = {}
        for j = 1, TRANSFORMER_DIM do
            self.state_embedding_weights[i][j] = math.random(0.1,2) -- Replace with random initialization
        end
    end
end

function CivTransformerPolicy:AddPositionalEncoding(state_embedding)
    local position_encoded_embedding = {}
    
    -- Assuming the state_embedding is a sequence of vectors
    for i = 1, #state_embedding do
        local embed_vector = state_embedding[i]
        local position_vector = {}

        -- For each dimension in the embedding vector
        for d = 1, #embed_vector do
            local positional_value
            
            -- Apply the positional encoding formula
            if d % 2 == 0 then
                -- Even dimensions: sin(pos / 10000^(2i/d_model))
                positional_value = math.sin(i / (10000 ^ (2 * (d / 2) / TRANSFORMER_DIM)))
            else
                -- Odd dimensions: cos(pos / 10000^(2i/d_model))
                positional_value = math.cos(i / (10000 ^ (2 * ((d - 1) / 2) / TRANSFORMER_DIM)))
            end

            -- Add the positional value to the original embedding value
            position_vector[d] = embed_vector[d] + positional_value
        end

        -- Add the position encoded vector to the new embedding
        position_encoded_embedding[i] = position_vector
    end

    return position_encoded_embedding
end


-- Scaled Dot-Product Attention
function CivTransformerPolicy:Attention(query, key, value, mask)
    -- 1. Calculate Attention Scores:
    
    -- Transpose the key matrix for multiplication
    local key_T = matrix.transpose(key)

    -- Perform matrix multiplication between query and transposed key
    local attention_scores = matrix.mul(query, key_T)

    -- Scale the attention scores by dividing by the square root of the key dimension (d_k)
    local d_k = key:size()[2] -- Get the number of columns in the key matrix
    attention_scores = matrix.divnum(attention_scores, math.sqrt(d_k))

    -- 2. Apply Mask (if provided):
    if mask then
        -- Add the mask to the attention scores (-Infinity or very large negative values at masked positions)
        -- Assuming the mask is a table with the same dimensions as attention_scores
        for i = 1, #attention_scores do
            for j = 1, #attention_scores[1] do
                if mask[i][j] then  -- Assuming 'true' in the mask means the position should be masked
                    attention_scores[i][j] = -1e9 -- Use a large negative number to represent -Infinity
                end
            end
        end
    end

    -- 3. Calculate Attention Probabilities (Softmax):
    local attention_probabilities = matrix.softmax(attention_scores)
    -- 4. Calculate Weighted Value:
    local weighted_value = matrix.mul(attention_probabilities, value)
    -- 5. Return the weighted value (convert back to Lua table for further processing)
    return weighted_value
end

-- Multi-Head Attention
function CivTransformerPolicy:MultiHeadAttention(query, key, value, mask, num_heads)
    local size = query:size()  -- Get the size table
    local d_k = size[2] / num_heads

    -- 1. Linearly project query, key, and value into 'num_heads' different representations.
    local query_projections = {}
    local key_projections = {}
    local value_projections = {}

    for i = 1, num_heads do
        -- Generate random projection matrices for each head
        -- These would normally be learned parameters, but for simplicity, we use random matrices
        local w_q = matrix.random(matrix:new(d_k, d_k))
        local w_k = matrix.random(matrix:new(d_k, d_k))
        local w_v = matrix.random(matrix:new(d_k, d_k))

        print("m1 size:", size[1],size[2])
        print("m2 size:", w_q:size()[1],w_q:size()[2])
        -- Apply linear projections
        table.insert(query_projections, matrix.mul(query, w_q))
        table.insert(key_projections, matrix.mul(key, w_k))
        table.insert(value_projections, matrix.mul(value, w_v))
    end

    -- 2. Apply Scaled Dot-Product Attention to each head.
    local attention_outputs = {}
    for head_index = 1, num_heads do
        local head_output = self:Attention(query_projections[head_index],
                                           key_projections[head_index],
                                           value_projections[head_index],
                                           mask)
        table.insert(attention_outputs, head_output)
    end

    -- 3. Concatenate the outputs of all heads.
    local concatenated_attention = attention_outputs[1]
    for head_index = 2, num_heads do
        concatenated_attention = matrix.concath(concatenated_attention, attention_outputs[head_index])
    end

    -- 4. Apply a final linear projection to the concatenated output.
    -- This would also be a learned parameter matrix in a full implementation
    local w_o = matrix.random(matrix:new(concatenated_attention:size()[2], TRANSFORMER_DIM)) 
    local final_output = matrix.mul(concatenated_attention, w_o)

    return final_output
end

function CivTransformerPolicy:Feedforward(input)
    -- Convert input table to matrix
    local input_mtx = tableToMatrix(input)

    -- Define dimensions
    local d_model = input_mtx:size()[2] -- Number of columns (embedding dimension)
    local d_ff = 2048  -- Hidden dimension of the feedforward network (can be a hyperparameter)

    -- Initialize weights and biases for the two linear layers (randomly for now)
    -- In a real implementation, these would be learned parameters
    local w1 = matrix.random(matrix:new(d_model, d_ff))
    local b1 = matrix.random(matrix:new(1, d_ff))
    local w2 = matrix.random(matrix:new(d_ff, d_model))
    local b2 = matrix.random(matrix:new(1, d_model))

    -- First linear layer + ReLU activation
    local layer1_output = matrix.add(matrix.mul(input_mtx, w1), matrix.repmat(b1, input_mtx:size()[1], 1)) -- Broadcasting b1
    layer1_output = matrix.relu(layer1_output)

    -- Second linear layer
    local layer2_output = matrix.add(matrix.mul(layer1_output, w2), matrix.repmat(b2, input_mtx:size()[1], 1)) -- Broadcasting b2
    
    -- Convert the output matrix back to a table
    local output_tbl = matrixToTable(layer2_output)

    return output_tbl
end
-- Helper function for layer normalization (simplified for now)
function CivTransformerPolicy:LayerNorm(input_mtx)
    local epsilon = 1e-6 -- Small constant for numerical stability

    -- Calculate the mean and variance for each row in the matrix
    local means = {}
    local variances = {}
    for i = 1, input_mtx:rows() do
        local sum = 0
        local sum_sq = 0
        for j = 1, input_mtx:columns() do
            local val = input_mtx:getelement(i, j)
            sum = sum + val
            sum_sq = sum_sq + val * val
        end
        table.insert(means, sum / input_mtx:columns())
        table.insert(variances, sum_sq / input_mtx:columns() - means[i] * means[i])
    end

    -- Normalize the matrix
    local normalized_mtx = matrix:new(input_mtx:rows(), input_mtx:columns())
    for i = 1, input_mtx:rows() do
        for j = 1, input_mtx:columns() do
            normalized_mtx:setelement(i, j, (input_mtx:getelement(i, j) - means[i]) / math.sqrt(variances[i] + epsilon))
        end
    end

    return normalized_mtx
end

-- 5. Transformer Layer (Complete with Feedforward, Residual Connections, and Layer Normalization)
function CivTransformerPolicy:TransformerLayer(input, mask)
    -- Convert input table to matrix
    local input_mtx = tableToMatrix(input)

    -- Multi-Head Self-Attention
    local attention_output = self:MultiHeadAttention(input_mtx, input_mtx, input_mtx, mask, TRANSFORMER_HEADS)

    -- Add & Norm (Residual Connection and Layer Normalization)
    local add_norm_output_1 = self:LayerNorm(matrix.add(input_mtx, attention_output))

    -- Feedforward Network
    local ff_output_tbl = self:Feedforward(matrixToTable(add_norm_output_1)) 
    local ff_output_mtx = tableToMatrix(ff_output_tbl)

    -- Add & Norm (Residual Connection and Layer Normalization)
    local add_norm_output_2 = self:LayerNorm(matrix.add(add_norm_output_1, ff_output_mtx))

    -- Convert the output matrix back to a table
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
    self:InitStateEmbedding()
    -- We don't initialize other components yet, as they are just placeholders for now
end

function CivTransformerPolicy:PadStateEmbed(state_embed)

    print("State Embedding Size:", #state_embed)
    return state_embed
end

-- Forward Pass (Placeholder)
function CivTransformerPolicy:Forward(state_embed, possible_actions)

    if matrix then
        print("Matrix functions:", table.concat(matrix, ", ")) -- Print available functions (if it's a table)
      else
        print("Error: Matrix module not loaded!")
      end
    -- 1. Embed the state
    state_embed = self:PadStateEmbed(state_embed)
    local embedded_state = {}
    for i = 1, #state_embed do
        local embed_vector = {}
        for j = 1, TRANSFORMER_DIM do
            local sum = 0
            for k = 1, STATE_EMBED_SIZE do
                sum = sum + state_embed[k] * self.state_embedding_weights[k][j] 
            end
            table.insert(embed_vector, sum)
        end
        table.insert(embedded_state, embed_vector)
    end
    print("Embedded State done, Size is :", #embedded_state)
    -- 2. Add positional encoding
    embedded_state = self:AddPositionalEncoding(embedded_state)
    print("Positional Encoding done, Size is :", #embedded_state)
    -- 3. Create a mask for invalid actions (simplified for now)
    local mask = {} -- This would be based on possible_actions

    -- 4. Pass through Transformer Encoder 
    local transformer_output = self:TransformerEncoder(embedded_state, mask)
    print("Transformer Encoder done, Size is :", #transformer_output)
    -- 5. Placeholder for Action Type Selection
    local action_type_probs = {}  -- This should be the output of ActionTypeHead

    -- 6. Placeholder for Parameter Selection
    local action_params_probs = {} -- This should be the output of ParameterHeads

    -- 7. Placeholder for Value Estimation
    local value = 0 -- This should be the output of ValueHead

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