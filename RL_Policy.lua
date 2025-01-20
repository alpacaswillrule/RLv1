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
include("matrix")

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

-- Helper function to normalize values to [0,1] range
function Normalize(value, maxValue)
    if maxValue == 0 then return 0 end
    return value / maxValue
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

-- Placeholder for the Transformer Policy Network
CivTransformerPolicy = {}

-- 1. State Embedding Layer (Initialization)
function CivTransformerPolicy:InitStateEmbedding()
    -- Initialize weights for the state embedding layer
    -- This is a placeholder. In a real implementation, you'd initialize with random values.
    self.state_embedding_weights = {}
    for i = 1, STATE_EMBED_SIZE do
        self.state_embedding_weights[i] = {}
        for j = 1, TRANSFORMER_DIM do
            self.state_embedding_weights[i][j] = math.random(0.1,2) -- Replace with random initialization
        end
    end
end

-- 2. Positional Encoding (Placeholder)
function CivTransformerPolicy:AddPositionalEncoding(state_embedding)
    -- Placeholder function for adding positional information
    -- This would typically involve adding sine/cosine values based on position
    return state_embedding
end

-- 3. Attention Mechanism (Placeholder)
function CivTransformerPolicy:Attention(query, key, value, mask)
    -- Placeholder for the attention mechanism
    -- This is where you'd calculate attention scores and apply the mask
    return value -- Placeholder: just returning the value for now
end

-- 4. Feedforward Neural Network (Placeholder)
function CivTransformerPolicy:Feedforward(input)
    -- Placeholder for a feedforward network
    -- This would involve a couple of linear layers with an activation function
    return input -- Placeholder: just returning the input
end

-- 5. Transformer Layer (Placeholder)
function CivTransformerPolicy:TransformerLayer(input, mask)
    -- Applying attention
    attention_output = self:Attention(input, input, input, mask)
    
    -- Add & Norm (simplified, no residual connection or normalization for now)
    add_norm_output_1 = attention_output -- In reality, you'd add input to attention_output and normalize
    
    -- Applying feedforward network
    ff_output = self:Feedforward(add_norm_output_1)
    
    -- Add & Norm (again, simplified)
    add_norm_output_2 = ff_output -- In reality, you'd add add_norm_output_1 to ff_output and normalize

    return add_norm_output_2
end

-- 6. Transformer Encoder (Placeholder)
function CivTransformerPolicy:TransformerEncoder(input, mask)
    local encoder_output = input
    for i = 1, TRANSFORMER_LAYERS do
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

-- Forward Pass (Placeholder)
function CivTransformerPolicy:Forward(state_embed, possible_actions)
    -- 1. Embed the state
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

    -- 2. Add positional encoding
    embedded_state = self:AddPositionalEncoding(embedded_state)

    -- 3. Create a mask for invalid actions (simplified for now)
    local mask = {} -- This would be based on possible_actions

    -- 4. Pass through Transformer Encoder
    local transformer_output = self:TransformerEncoder(embedded_state, mask)

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