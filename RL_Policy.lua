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

-- Get map dimensions
local mapWidth, mapHeight = Map.GetGridSize()
local MAP_DIMENSION = math.max(mapWidth, mapHeight)
-- Update action types to include all possibilities
ACTION_TYPES = {
    "EndTurn",
    "ChooseCivic",
    "ChooseTech", 
    "CityRangedAttack",
    "EncampmentRangedAttack",
    "SendEnvoy",
    "MakePeace",
    "LevyMilitary",
    "RecruitGreatPerson",
    "RejectGreatPerson",
    "PatronizeGreatPersonGold",
    "PatronizeGreatPersonFaith",
    "MoveUnit",
    "UnitRangedAttack",
    "UnitAirAttack",
    "FormUnit",
    "RebaseUnit",
    "WMDStrike",
    "QueueUnitPath",
    "BuildImprovement",
    "EnterFormation",
    "FoundCity",
    "PromoteUnit",
    "UpgradeUnit",
    "ChangeGovernment",
    "ChangePolicies",
    "EstablishTradeRoute",
    "CityProduction",
    "PlaceDistrict",
    "FoundPantheon",
    "FoundReligion",
    "SelectBeliefs",
    "SpreadReligion",
    "EvangelizeBelief",
    "PurchaseWithGold",
    "PurchaseWithFaith",
    "ActivateGreatPerson",
    "AssignGovernorTitle",
    "AssignGovernorToCity",
    "HarvestResource",
    "Fortify",
    "FormCorps",
    "FormArmy",
    "Wake",
    "Repair",
    "RemoveFeature"
}

-- Update parameter names to include all possible parameters
local ACTION_PARAM_ORDER = {
    "CityID",
    "UnitID", 
    "PlotX",
    "PlotY",
    "TargetPlayerID",
    "ProductionHash",
    "ImprovementHash",
    "PromotionType",
    "PurchaseType",
    "BeliefType",
    "ReligionHash",
    "GovernorType",
    "PolicyHash",
    "TechHash",
    "CivicHash",
    "TradeRouteIndex",
    "DistrictHash",
    "TypeHash"
}
-- Hash function for action parameters
function Hash(value)
    if type(value) == "string" then
        local hash = 0
        for i = 1, #value do
            -- Use multiplication instead of bit shift
            hash = (hash * 32 + hash) + string.byte(value, i)
            -- Use modulo to keep within 32 bits
            hash = hash % 0x100000000
        end
        return math.abs(hash)
    elseif type(value) == "number" then
        return math.abs(value)
    end
    return 0
end

-- Constants for embedding sizes and transformer config
local CITY_EMBED_SIZE = 64 
local UNIT_EMBED_SIZE = 32
local TILE_EMBED_SIZE = 16
local MAX_CITIES = 20
local MAX_UNITS = 40
local MAX_TILES = 100
local TRANSFORMER_DIM = 512 -- Dimension of the transformer model
local TRANSFORMER_HEADS = 8 -- Number of attention heads
local TRANSFORMER_LAYERS = 4 -- Number of transformer layers
-- Add these constants at the top with other MAX_* definitions
local MAX_TECHS = 70        -- Total techs in Civ6
local MAX_CIVICS = 50       -- Total civics in Civ6
local MAX_DIPLO_CIVS = 20   -- Max other civilizations

PARAM_ENCODING_SIZE = 18

-- Calculate the actual state embedding size based on your encoding functions and constants
-- Replace the existing calculation with:
STATE_EMBED_SIZE = 7
    + (MAX_CITIES * CITY_EMBED_SIZE)
    + (MAX_UNITS * UNIT_EMBED_SIZE)
    + (MAX_TILES * TILE_EMBED_SIZE)
    + (MAX_TECHS * 3)          -- 3 values per tech
    + (MAX_CIVICS * 3)         -- 3 values per civic
    + 2                        -- Victory progress
    + (MAX_DIPLO_CIVS * 3)     -- 3 values per diplo status
    + 10                       -- Government
    + 4                        -- Policies
    + (5 * MAX_CITIES)         -- Spatial cities
    + (4 * MAX_UNITS)          -- Spatial units


function argmax(t)
    local max_val = t[1]
    local max_idx = 1
    for i = 2, #t do
        if t[i] > max_val then
            max_val = t[i]
            max_idx = i
        end
    end
    return max_idx
end

-- Add slice function for tables
function slice_table(tbl, first, last)
    local sliced = {}
    for i = first or 1, last or #tbl do
        table.insert(sliced, tbl[i])
    end
    return sliced
end

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
    -- Add error checking
    if value == nil then
        print("WARNING: Normalize received nil value")
        return 0
    end
    if maxValue == nil then
        print("WARNING: Normalize received nil maxValue")
        return 0
    end
    if maxValue == 0 then 
        return 0 
    end
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
    -- Encode up to MAX_TECHS
    for i = 1, math.min(#techs, MAX_TECHS) do
        local tech = techs[i]
        table.insert(techEmbed, tech.IsUnlocked and 1 or 0)
        table.insert(techEmbed, tech.Progress or 0)
        table.insert(techEmbed, tech.IsBoosted and 1 or 0)
    end
    -- Pad remaining tech slots
    for i = #techs + 1, MAX_TECHS do
        table.insert(techEmbed, 0)
        table.insert(techEmbed, 0)
        table.insert(techEmbed, 0)
    end
    return techEmbed
end

function EncodeCivicState(civics)
    local civicEmbed = {}
    for i = 1, math.min(#civics, MAX_CIVICS) do
        local civic = civics[i]
        table.insert(civicEmbed, civic.IsUnlocked and 1 or 0)
        table.insert(civicEmbed, civic.Progress or 0)
        table.insert(civicEmbed, civic.IsBoosted and 1 or 0)
    end
    -- Pad remaining civic slots
    for i = #civics + 1, MAX_CIVICS do
        table.insert(civicEmbed, 0)
        table.insert(civicEmbed, 0)
        table.insert(civicEmbed, 0)
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
    local count = 0
    -- Only process first MAX_DIPLO_CIVS entries
    for civID, status in pairs(diplomaticStatuses) do
        if count >= MAX_DIPLO_CIVS then break end
        -- ... existing encoding code ...
        count = count + 1
    end
    -- Pad remaining slots (3 values per civ)
    for i = count + 1, MAX_DIPLO_CIVS do
        table.insert(diplomaticEmbed, 0)
        table.insert(diplomaticEmbed, 0)
        table.insert(diplomaticEmbed, 0)
    end
    return diplomaticEmbed
end

-- Updated main encoding function
function EncodeGameState(state)
    local stateEmbed = {}
    
    print("Encoding state values:")
    print("Gold:", state.Gold)
    print("Faith:", state.Faith)
    -- print("GoldPerTurn:", state.GoldPerTurn)
    -- print("FaithPerTurn:", state.FaithPerTurn)
    -- print("SciencePerTurn:", state.SciencePerTurn)
    -- print("CulturePerTurn:", state.CulturePerTurn)
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
    if state.Cities == nil then
        print("WARNING: No cities found in state")
        state.Cities = {}
    end

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
    
    if state.Units == nil then
        print("WARNING: No units found in state")
        state.Units = {}
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
    
    if allTiles == nil then
        print("WARNING: No tiles found in state")
        allTiles = {}
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

    if #stateEmbed > STATE_EMBED_SIZE then
        print("WARNING State embedding size exceeds limit:", #stateEmbed)
    end

    if #stateEmbed < STATE_EMBED_SIZE then
        print("WARNING State embedding size below limit:", #stateEmbed)
    end
    -- Final truncation/padding to ensure exact size
    while #stateEmbed > STATE_EMBED_SIZE do
        table.remove(stateEmbed)
    end
    while #stateEmbed < STATE_EMBED_SIZE do
        table.insert(stateEmbed, 0)
    end
    
    return stateEmbed
end

function DecodeHash(encoded_values)
    local hash = 0
    for i, value in ipairs(encoded_values) do
        hash = hash + math.floor(value * 31) * (32 ^ (i-1))
    end
    return hash
end

function DecodeCoordinate(encoded_value)
    return math.floor(encoded_value * MAP_DIMENSION)
end

function DecodeID(encoded_values)
    return math.floor(encoded_values[1] * 1000000)
end
function DecodeSpecialParameters(action_type, encoded_values, offset)
    local params = {}
    
    if action_type == "BuildImprovement" then
        params.ImprovementHash = DecodeHash(slice_table(encoded_values, offset, offset + 5))
        params.PlotX = DecodeCoordinate(encoded_values[offset + 6])
        params.PlotY = DecodeCoordinate(encoded_values[offset + 7])
        
    elseif action_type == "SpreadReligion" then
        params.TargetCityID = DecodeID(slice_table(encoded_values, offset, offset + 5))
        params.ReligionHash = DecodeHash(slice_table(encoded_values, offset + 6, offset + 11))
        
    elseif action_type == "EstablishTradeRoute" then
        params.Yields = {}
        local yield_types = {"Food", "Production", "Gold", "Science", "Culture", "Faith"}
        for i, yield_type in ipairs(yield_types) do
            params.Yields[yield_type] = encoded_values[offset + i] * 100 -- Denormalize
        end
        
    elseif action_type == "FoundReligion" then
        params.BeliefHashes = {}
        for i = 1, 3 do  -- Assume 3 belief choices
            local belief_hash = DecodeHash(slice_table(encoded_values, offset + (i-1)*6, offset + i*6 - 1))
            table.insert(params.BeliefHashes, belief_hash)
        end
    end
    
    return params
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

-- Action Encoding
-- In EncodeAction:
function EncodeAction(action_type, action_params)
    local encoded = {}
    
    -- Action type one-hot encoding
    for _, atype in ipairs(ACTION_TYPES) do
        table.insert(encoded, atype == action_type and 1 or 0)
    end

    -- Parameters encoding
    for _, param_name in ipairs(ACTION_PARAM_ORDER) do
        local value = action_params[param_name] or 0
        encoded = EncodeActionParam(param_name, value, encoded)
    end

    -- Add special handling for specific action types
    if action_type == "EstablishTradeRoute" then
        -- Encode yields
        local yields = action_params.Yields or {}
        for _, yield_type in ipairs({"Food", "Production", "Gold", "Science", "Culture", "Faith"}) do
            table.insert(encoded, Normalize(yields[yield_type] or 0, 100))
        end
    elseif action_type == "FoundReligion" then
        -- Encode belief choices
        if action_params.BeliefHashes then
            for _, hash in ipairs(action_params.BeliefHashes) do
                table.insert(encoded, Normalize(hash or 0, 1000000))
            end
        end
    end

    return encoded
end

function EncodeActionParam(param_name, value, encoded)
    local elements = {}
    
    if param_name:match("ID$") or param_name:match("Hash$") then
        -- Split hash into 6 parts (5 bits each) using Lua 5.1 compatible operations
        local hash = Hash(value)
        for i = 1, 6 do
            local shift = (i-1) * 5  -- 5 bits per element
            -- Replace bit shifts with division/modulo
            local part = math.floor(hash / (2^shift)) % 32  -- 32 = 2^5 (5 bits)
            table.insert(elements, part / 31.0)  -- Normalize to 0-1
        end
    elseif param_name:match("X$") or param_name:match("Y$") then
        -- Positional encoding with sine/cosine
        local norm = Normalize(value, MAP_DIMENSION)
        for i = 1, 6 do
            local freq = 10000.0 ^ (2 * (i-1)/6)
            if i % 2 == 0 then
                table.insert(elements, math.cos(norm * freq))
            else
                table.insert(elements, math.sin(norm * freq))
            end
        end
    elseif param_name == "ProductionType" then
        -- One-hot encoding with padding
        local types = {"UNIT", "BUILDING", "DISTRICT", "PROJECT"}
        for _, t in ipairs(types) do
            table.insert(elements, t == value and 1 or 0)
        end
        -- Pad with zeros
        while #elements < 6 do
            table.insert(elements, 0)
        end
    else
        -- Repeat normalized value 6 times
        local norm = Normalize(value or 0, 100)
        for i = 1, 6 do
            table.insert(elements, norm)
        end
    end
    
    for _, e in ipairs(elements) do
        table.insert(encoded, e)
    end
    return encoded
end

function DecodeActionParam(param_name, encoded_values)
    -- Handle potential missing values
    if #encoded_values < 6 then
        print("WARNING: Insufficient encoded values for", param_name)
        return 0
    end
    
    if param_name:match("ID$") or param_name:match("Hash$") then
        local hash = 0
        for i = 1, PARAM_ENCODING_SIZE do
            local part = math.floor(encoded_values[i] * 31 + 0.5)  -- Reconstruct 5-bit chunks
            hash = hash + part * (32 ^ (i-1))  -- 32 = 2^5
        end
        return hash % 0x100000000  -- Keep within 32-bit range
    elseif param_name:match("X$") or param_name:match("Y$") then
        -- Decode using first element (simplified)
        return math.floor(encoded_values[1] * MAP_DIMENSION)
    elseif param_name == "ProductionType" then
        -- One-hot decoding
        local types = {"UNIT", "BUILDING", "DISTRICT", "PROJECT"}
        local max_idx = 1
        for i = 1, 4 do
            if encoded_values[i] > encoded_values[max_idx] then
                max_idx = i
            end
        end
        return types[max_idx] or "UNIT"
    else
        -- Average all elements
        local sum = 0
        for i = 1, 6 do
            sum = sum + (encoded_values[i] or 0)
        end
        return math.floor((sum / 6) * 100)
    end
end
-- Action Decoding
function DecodeAction(encoded, possible_actions, masked_logits)
    print("\nDecoding Action:")
    
    -- Convert logits to probabilities using softmax
    local sum_exp = 0
    local probs = {}
    for _, logit in ipairs(masked_logits) do
        local exp_val = math.exp(logit)
        sum_exp = sum_exp + exp_val
        table.insert(probs, exp_val)
    end
    
    -- Normalize probabilities
    for i = 1, #probs do
        probs[i] = probs[i] / sum_exp
    end
    
    -- Sample action type using probabilities
    local rand = math.random()
    local cumsum = 0
    local selected_idx = 1
    
    for i, prob in ipairs(probs) do
        cumsum = cumsum + prob
        if rand <= cumsum then
            selected_idx = i
            break
        end
    end
    
    local action_type = ACTION_TYPES[selected_idx]
    print("Sampled action type:", action_type, "with probability:", probs[selected_idx])
    
    -- Validate selected action is possible
    if not possible_actions[action_type] or 
       (action_type ~= "EndTurn" and #possible_actions[action_type] == 0) then
        print("Selected action not possible, defaulting to EndTurn")
        return {
            ActionType = "EndTurn",
            Parameters = {}
        }
    end
    
    -- Decode parameters for valid action
    local params = {}
    local offset = #ACTION_TYPES
    
    for _, param_name in ipairs(ACTION_PARAM_ORDER) do
        local param_values = slice_table(encoded, offset + 1, offset + PARAM_ENCODING_SIZE)
        offset = offset + PARAM_ENCODING_SIZE
        
        if #param_values == PARAM_ENCODING_SIZE then
            params[param_name] = DecodeActionParam(param_name, param_values)
            print(string.format("Decoded %s = %s", param_name, tostring(params[param_name])))
        end
    end
    
    -- Match decoded action to valid action and include probabilities
    local action = MatchToValidAction(action_type, params, possible_actions)
    action.Probabilities = probs
    action.SelectedProbability = probs[selected_idx]
    
    return action
end


function MatchToValidAction(action_type, params, possible_actions)
    print("\nMatching to valid action:")
    print("Action type:", action_type)
    
    -- Handle EndTurn specially
    if action_type == "EndTurn" then
        return {ActionType = "EndTurn", Parameters = {}}
    end
    
    -- Validate possible actions exist
    if not possible_actions[action_type] then
        print("No actions available for type", action_type)
        return {ActionType = "EndTurn", Parameters = {}}
    end
    
    local valid_actions = possible_actions[action_type]
    print("Available actions:", #valid_actions)
    
    if #valid_actions == 0 then
        print("No valid actions for type", action_type)
        return {ActionType = "EndTurn", Parameters = {}}
    end
    
    -- Find best matching action
    local best_match = nil
    local best_score = -math.huge
    
    for _, valid_action in ipairs(valid_actions) do
        local score = 0
        local param_count = 0
        
        for param, value in pairs(params) do
            if valid_action[param] then
                -- Convert both values to numbers if possible
                local val1 = tonumber(value)
                local val2 = tonumber(valid_action[param])
                
                -- Only compare if both values are numbers
                if val1 and val2 then
                    score = score + (1 - math.abs((val1 - val2) / 
                        (math.max(math.abs(val1), math.abs(val2)) + 1e-6)))
                    param_count = param_count + 1
                -- If values are strings, check for exact match
                elseif value == valid_action[param] then
                    score = score + 1
                    param_count = param_count + 1
                end
            end
        end
        
        -- Normalize score by number of matched parameters
        if param_count > 0 then
            score = score / param_count
            if score > best_score then
                best_score = score
                best_match = valid_action
            end
        end
    end
    
    if best_match then
        print("Found matching action with score:", best_score)
        return {
            ActionType = action_type,
            Parameters = best_match
        }
    end
    
    return {ActionType = "EndTurn", Parameters = {}}
end


-- Define parameter order and max parameters
local ACTION_PARAM_ORDER = {
    "CityID", "UnitID", "PlotX", "PlotY", "ProductionHash", 
    "ImprovementHash", "PromotionType", "PurchaseType", "TypeHash"
}
local MAX_ACTION_PARAMS = #ACTION_PARAM_ORDER


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


CivTransformerPolicy = {
        initialized = false
    }

-- 1. State Embedding Layer (Initialization)
function CivTransformerPolicy:InitStateEmbedding()
    -- Create matrix using :new
    self.state_embedding_weights = matrix:new(STATE_EMBED_SIZE, TRANSFORMER_DIM)
    -- Apply random initialization
    matrix.random(self.state_embedding_weights)
    
    -- Scale values between 0.1 and 2
    for i = 1, STATE_EMBED_SIZE do
        for j = 1, TRANSFORMER_DIM do
            local val = self.state_embedding_weights:getelement(i, j)
            self.state_embedding_weights:setelement(i, j, val * 1.9 + 0.1)
        end
    end
end

function CivTransformerPolicy:BackwardPass(action_grad, value_grad)
    -- action_grad should contain:
    -- .action_type_grad - gradient for action type selection
    -- .option_grad - gradient for option selection
    
    -- Backward through value head
    local transformer_grad_from_value = ValueNetwork:BackwardPass(value_grad)
    
    -- Backward through option selection head (if applicable)
    local option_grad = nil
    if action_grad.option_grad then
        option_grad = self:OptionHeadBackward(action_grad.option_grad)
    end
    
    -- Backward through action type head
    local action_type_grad = self:ActionTypeHeadBackward(action_grad.action_type_grad)
    
    -- Combine all gradients
    local total_transformer_grad = transformer_grad_from_value
    if option_grad then
        total_transformer_grad = matrix.add(total_transformer_grad, option_grad)
    end
    total_transformer_grad = matrix.add(total_transformer_grad, action_type_grad)
    
    -- Backward through transformer layers
    self:TransformerBackward(total_transformer_grad)
end

function CivTransformerPolicy:ActionTypeHeadBackward(grad_output)
    -- Backward through action type projection
    local grad_input = matrix.mul_with_grad(grad_output, matrix.transpose(self.action_type_projection))
    self.action_type_projection:backward(matrix.mul_with_grad(
        matrix.transpose(self.transformer_cache.output), 
        grad_output
    ))
    return grad_input
end

function CivTransformerPolicy:OptionHeadBackward(grad_output)
    -- Backward through option attention
    -- grad_output should be [batch_size x num_options]
    
    -- Get cached values
    local option_embeddings = self.option_cache.embeddings
    local projected_state = self.option_cache.projected_state
    
    -- Backward through attention scores
    local grad_projected = matrix.mul_with_grad(grad_output, option_embeddings)
    local grad_embeddings = matrix.mul_with_grad(matrix.transpose(grad_output), projected_state)
    
    -- Backward through state projection
    local grad_state = matrix.mul_with_grad(grad_projected, matrix.transpose(self.option_projection))
    self.option_projection:backward(matrix.mul_with_grad(
        matrix.transpose(self.transformer_cache.output),
        grad_projected
    ))
    
    return grad_state
end

function CivTransformerPolicy:TransformerLayerBackward(grad_output, layer_index)
    -- Cache needs to store intermediate values during forward pass
    local layer_cache = self.layer_caches[layer_index]
    
    -- Backward through second Add & Norm
    local ff_grad = self:LayerNormBackward(grad_output, layer_cache.norm2_stats)
    
    -- Backward through Feedforward
    local ff_input_grad = self:FeedforwardBackward(ff_grad, layer_index)
    
    -- Backward through first Add & Norm
    local attention_grad = self:LayerNormBackward(ff_input_grad, layer_cache.norm1_stats)
    
    -- Backward through Multi-Head Attention
    return self:MultiHeadAttentionBackward(attention_grad, layer_index)
end

function CivTransformerPolicy:LayerNormBackward(grad_output, norm_stats)
    local epsilon = 1e-6
    local rows, cols = grad_output:size()[1], grad_output:size()[2]
    local grad_input = matrix:new(rows, cols)
    
    for i = 1, rows do
        local mean = norm_stats.means[i]
        local var = norm_stats.vars[i]
        local std = math.sqrt(var + epsilon)
        
        for j = 1, cols do
            local x_norm = (grad_output:getelement(i, j) - mean) / std
            local grad_in = grad_output:getelement(i, j) / std
            grad_in = grad_in - mean / (cols * std)
            grad_in = grad_in - x_norm * var / (2 * cols * (var + epsilon))
            
            grad_input:setelement(i, j, grad_in)
        end
    end
    
    return grad_input
end

function CivTransformerPolicy:FeedforwardBackward(grad_output, layer_index)
    -- Unpack saved tensors for this layer
    local layer_cache = self.layer_caches[layer_index]
    local ff1_output = layer_cache.ff1_output
    local ff1_input = layer_cache.ff1_input
    
    -- Backward through second linear layer
    local grad_ff2 = matrix.mul_with_grad(grad_output, matrix.transpose(self.ff2_weights[layer_index]))
    self.ff2_weights[layer_index]:backward(matrix.mul_with_grad(matrix.transpose(ff1_output), grad_output))
    self.ff2_bias[layer_index]:backward(grad_output)
    
    -- Backward through ReLU
    local grad_relu = matrix.replace(grad_ff2, function(val, i, j)
        return ff1_output:getelement(i, j) > 0 and val or 0
    end)
    
    -- Backward through first linear layer
    local grad_input = matrix.mul_with_grad(grad_relu, matrix.transpose(self.ff1_weights[layer_index]))
    self.ff1_weights[layer_index]:backward(matrix.mul_with_grad(matrix.transpose(ff1_input), grad_relu))
    self.ff1_bias[layer_index]:backward(grad_relu)
    
    return grad_input
end

function CivTransformerPolicy:MultiHeadAttentionBackward(grad_output, layer_index)
    local total_grad_input = matrix:new(grad_output:rows(), self.d_model, 0)
    
    -- Backward through each attention head
    for h = 1, self.num_heads do
        local head_grad = self:SingleHeadAttentionBackward(
            grad_output, 
            layer_index,
            h
        )
        total_grad_input = matrix.add(total_grad_input, head_grad)
    end
    
    -- Backward through output projection
    local grad_input = matrix.mul_with_grad(grad_output, matrix.transpose(self.w_o))
    self.w_o:backward(matrix.mul_with_grad(
        matrix.transpose(total_grad_input), 
        grad_output
    ))
    
    return grad_input
end

function CivTransformerPolicy:SingleHeadAttentionBackward(grad_output, layer_index, head_index)
    -- Unpack saved tensors for this head
    local head_cache = self.attention_caches[layer_index][head_index]
    local Q = head_cache.Q
    local K = head_cache.K
    local V = head_cache.V
    local attention_weights = head_cache.attention_weights
    
    -- Scale factor for attention
    local d_k_sqrt = math.sqrt(self.d_k)
    
    -- Backward through attention mechanism
    -- 1. Gradient to V
    local grad_v = matrix.mul_with_grad(matrix.transpose(attention_weights), grad_output)
    
    -- 2. Gradient to attention weights
    local grad_weights = matrix.mul_with_grad(grad_output, matrix.transpose(V))
    
    -- 3. Gradient to scaled dot product
    local grad_dot = matrix.mul(grad_weights, 1/d_k_sqrt)
    
    -- 4. Gradients to Q and K
    local grad_q = matrix.mul_with_grad(grad_dot, K)
    local grad_k = matrix.mul_with_grad(matrix.transpose(grad_dot), Q)
    
    -- Backward through projection matrices
    self.head_projections.w_v[head_index]:backward(matrix.mul_with_grad(
        matrix.transpose(V), 
        grad_v
    ))
    
    self.head_projections.w_q[head_index]:backward(matrix.mul_with_grad(
        matrix.transpose(Q), 
        grad_q
    ))
    
    self.head_projections.w_k[head_index]:backward(matrix.mul_with_grad(
        matrix.transpose(K), 
        grad_k
    ))
    
    -- Combine gradients
    return matrix.add(matrix.add(grad_q, grad_k), grad_v)
end

-- function CivTransformerPolicy:InitializeCache()
--     print("Initializing cache...")
--     self.layer_caches = {}
--     self.attention_caches = {}
    
--     for i = 1, TRANSFORMER_LAYERS do
--         print("Creating cache for layer " .. i)
--         self.layer_caches[i] = {}
--         self.attention_caches[i] = {}
        
--         for h = 1, self.num_heads do
--             print("Creating cache for head " .. h .. " in layer " .. i)
--             self.attention_caches[i][h] = {}
--         end
--     end
--     print("Cache initialization complete")
-- end


function CivTransformerPolicy:InitializeCache()
    print("Initializing cache...")
    self.layer_caches = {}
    self.attention_caches = {}
    
    for i = 1, TRANSFORMER_LAYERS do
        print("Creating cache for layer " .. i)
        -- Initialize layer cache
        self.layer_caches[i] = {
            norm1_stats = {means = {}, vars = {}},
            norm2_stats = {means = {}, vars = {}},
            feedforward = {
                ff1_input = nil,
                ff1_output = nil
            }
        }
        
        -- Initialize attention cache with sub-tables for each head
        self.attention_caches[i] = {}
        for h = 1, self.num_heads do
            print("Creating cache for head " .. h .. " in layer " .. i)
            self.attention_caches[i][h] = {
                Q = nil,
                K = nil,
                V = nil,
                attention_weights = nil
            }
        end
    end
    print("Cache initialization complete")
end

function CivTransformerPolicy:SaveToCache(layer_index, head_index, key, value)
    if head_index then
        -- Verify the structure exists
        if not self.attention_caches[layer_index] then
            self.attention_caches[layer_index] = {}
        end
        if not self.attention_caches[layer_index][head_index] then
            self.attention_caches[layer_index][head_index] = {}
        end
        self.attention_caches[layer_index][head_index][key] = value
    else
        if not self.layer_caches[layer_index] then
            self.layer_caches[layer_index] = {}
        end
        self.layer_caches[layer_index][key] = value
    end
end

function CivTransformerPolicy:ClearCache()
    self:InitializeCache()
end


function CivTransformerPolicy:TransformerBackward(grad)
    -- Backward through each transformer layer
    local layer_grad = grad
    for i = TRANSFORMER_LAYERS, 1, -1 do
        layer_grad = self:TransformerLayerBackward(layer_grad, i)
    end
    
    -- Backward through initial embedding
    self.state_embedding_weights:backward(layer_grad)
end

function CivTransformerPolicy:UpdateParams(learning_rate)
    -- Update all network parameters
    self.state_embedding_weights:update_weights(learning_rate)
    
    -- Update transformer layer weights
    for i = 1, TRANSFORMER_LAYERS do
        -- Update attention weights
        for h = 1, self.num_heads do
            self.head_projections.w_q[h]:update_weights(learning_rate)
            self.head_projections.w_k[h]:update_weights(learning_rate)
            self.head_projections.w_v[h]:update_weights(learning_rate)
        end
        self.w_o:update_weights(learning_rate)
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

-- function CivTransformerPolicy:CreateAttentionMask(possible_actions)
--     local action_types = {"CityProduction", "MoveUnit", "CityManagement",  -- Changed UnitMove to MoveUnit
--                          "Diplomacy", "Research", "Civic", "EndTurn"}
--     local mask = matrix:new(#action_types, #ACTION_PARAM_ORDER, 1)

--     for action_idx, action_type in ipairs(action_types) do
--         -- Special handling for EndTurn
--         if action_type == "EndTurn" then
--             for param_idx = 1, #ACTION_PARAM_ORDER do
--                 mask:setelement(action_idx, param_idx, 0) -- Mask all params
--             end
--         else
--             -- Existing logic for other actions
--             if not possible_actions[action_type] or #possible_actions[action_type] == 0 then
--                 for param_idx = 1, #ACTION_PARAM_ORDER do
--                     mask:setelement(action_idx, param_idx, 0)
--                 end
--             else
--             -- Check valid parameters for this action type
--             for param_idx, param_name in ipairs(ACTION_PARAM_ORDER) do
--                 local valid = false
--                 for _, action in ipairs(possible_actions[action_type]) do
--                     if action[param_name] ~= nil then
--                         valid = true
--                         break
--                     end
--                 end
--                 mask:setelement(action_idx, param_idx, valid and 1 or 0)
--             end
--         end
--     end
--     return mask
-- end
-- end

function CivTransformerPolicy:CreateAttentionMask(possible_actions)
    -- Create mask for all possible action types 
    local action_mask = matrix:new(#ACTION_TYPES, 1, 0) -- Initialize to 0 (masked)
    
    -- Set 1 for valid actions only
    for action_type, actions in pairs(possible_actions) do
        local idx = nil
        -- Find index of this action type
        for i, atype in ipairs(ACTION_TYPES) do
            if atype == action_type then
                idx = i
                break
            end
        end
        
        -- Set mask to 1 if action type is valid and has possible actions
        if idx and (action_type == "EndTurn" or (type(actions) == "table" and #actions > 0)) then
            action_mask:setelement(idx, 1, 1)
        end
    end
    
    -- Debug print
    print("\nAction Mask:")
    for i = 1, #ACTION_TYPES do
        print(string.format("%s: %d", ACTION_TYPES[i], action_mask:getelement(i, 1)))
    end
    
    return action_mask
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
function CivTransformerPolicy:MultiHeadAttention(query, key, value, mask, layer_index)
    print("\nMultiHeadAttention:")
    -- Verify input shapes
    local q_size = query:size()
    local k_size = key:size()
    local v_size = value:size()
    
    -- print("Query shape:", q_size[1], "x", q_size[2])
    -- print("Key shape:", k_size[1], "x", k_size[2])
    -- print("Value shape:", v_size[1], "x", v_size[2])
    
    assert(q_size[2] == self.d_model, "Query dimension mismatch")
    assert(k_size[2] == self.d_model, "Key dimension mismatch")
    assert(v_size[2] == self.d_model, "Value dimension mismatch")

    local batch_size = q_size[1]
    -- print("Batch size:", batch_size)
    -- print("Number of heads:", self.num_heads)
    -- print("Head dimension:", self.d_k)

    local attention_outputs = {}

    -- Process each attention head
    for h = 1, self.num_heads do
        -- Project queries, keys, and values
        local q_proj = matrix.mul(query, self.head_projections.w_q[h])
        local k_proj = matrix.mul(key, self.head_projections.w_k[h])
        local v_proj = matrix.mul(value, self.head_projections.w_v[h])
        
        -- Save projections to cache
        self:SaveToCache(layer_index, h, "Q", q_proj)
        self:SaveToCache(layer_index, h, "K", k_proj)
        self:SaveToCache(layer_index, h, "V", v_proj)
        
        -- Calculate attention scores
        local attention_scores = matrix.mul(q_proj, matrix.transpose(k_proj))
        local attention_weights = matrix.softmax(attention_scores)
        
        -- Save attention weights to cache
        self:SaveToCache(layer_index, h, "attention_weights", attention_weights)
        -- Apply mask if provided
        if mask then
            attention_scores = matrix.replace(attention_scores, function(score, i, j)
                return mask:getelement(i, j) == 1 and score or -1e9
            end)
        end
        
        -- Compute attention weights
        local attention_weights = matrix.softmax(attention_scores)
        
        -- Compute head output
        local head_output = matrix.mul(attention_weights, v_proj)
        table.insert(attention_outputs, head_output)
        
        -- Debug prints
        local q_proj_size = q_proj:size()
        local head_output_size = head_output:size()
        -- print("Head", h, "projected Q shape:", q_proj_size[1], "x", q_proj_size[2])
        -- print("Head", h, "output shape:", head_output_size[1], "x", head_output_size[2])
    end

    -- Concatenate all head outputs
    local concatenated = attention_outputs[1]
    for h = 2, #attention_outputs do
        concatenated = matrix.concath(concatenated, attention_outputs[h])
    end
    
    -- Final projection
    local output = matrix.mul(concatenated, self.w_o)
    local output_size = output:size()
    -- print("Final MultiHeadAttention output shape:", output_size[1], "x", output_size[2])
    
    return output
end

-- Helper function to concatenate and project
function CivTransformerPolicy:ConcatenateAndProject(attention_outputs)
    -- Concatenate all head outputs along the feature dimension
    local concatenated = attention_outputs[1]
    for h = 2, #attention_outputs do
        concatenated = matrix.concath(concatenated, attention_outputs[h])
    end
    
    -- Apply final projection matrix
    return matrix.mul(concatenated, self.w_o)
end

-- function CivTransformerPolicy:Feedforward(input_mtx)
--     -- Define dimensions
--     local d_model = input_mtx:columns()
--     local d_ff = 2048

--     -- Initialize weights and biases as matrices
--     local w1 = matrix.random(matrix:new(d_model, d_ff))
--     local b1 = matrix.random(matrix:new(1, d_ff))
--     local w2 = matrix.random(matrix:new(d_ff, d_model))
--     local b2 = matrix.random(matrix:new(1, d_model))

--     -- First linear layer + ReLU activation
--     local layer1_output = matrix.add(matrix.mul(input_mtx, w1), matrix.repmat(b1, input_mtx:rows(), 1))
--     layer1_output = matrix.relu(layer1_output)

--     -- Second linear layer
--     return matrix.add(matrix.mul(layer1_output, w2), matrix.repmat(b2, input_mtx:rows(), 1))
-- end

function CivTransformerPolicy:Feedforward(input, layer_index)
    -- Debug prints and error checking
    --print("Feedforward layer:", layer_index)
    --print("Input dimensions:", input:size()[1], "x", input:size()[2])
    
    -- Check if weights/biases exist for this layer
    if not self.ff1_weights[layer_index] then
        print("ERROR: ff1_weights missing for layer", layer_index)
        return nil
    end
    if not self.ff2_weights[layer_index] then
        print("ERROR: ff2_weights missing for layer", layer_index)
        return nil
    end
    if not self.ff1_bias[layer_index] then
        print("ERROR: ff1_bias missing for layer", layer_index)
        return nil
    end
    if not self.ff2_bias[layer_index] then
        print("ERROR: ff2_bias missing for layer", layer_index)
        return nil
    end

    -- Print weight dimensions
    -- print("FF1 weights dimensions:", self.ff1_weights[layer_index]:size()[1], "x", self.ff1_weights[layer_index]:size()[2])
    -- print("FF1 bias dimensions:", self.ff1_bias[layer_index]:size()[1], "x", self.ff1_bias[layer_index]:size()[2])
    
    -- Save input to cache
    self:SaveToCache(layer_index, nil, "ff1_input", input)
    
    -- First linear layer
    local ff1_mul = matrix.mul(input, self.ff1_weights[layer_index])
    --print("FF1 multiplication result dimensions:", ff1_mul:size()[1], "x", ff1_mul:size()[2])
    
    -- Reshape bias if needed
    local batch_size = input:size()[1]
    local bias1 = matrix.repmat(self.ff1_bias[layer_index], batch_size, 1)
    
    -- First layer with ReLU
    local ff1_output = matrix.relu(matrix.add(ff1_mul, bias1))
    
    -- Save intermediate output
    self:SaveToCache(layer_index, nil, "ff1_output", ff1_output)
    
    -- Second linear layer
    local ff2_mul = matrix.mul(ff1_output, self.ff2_weights[layer_index])
    local bias2 = matrix.repmat(self.ff2_bias[layer_index], batch_size, 1)
    
    -- Return final output
    return matrix.add(ff2_mul, bias2)
end
-- Helper function for layer normalization (simplified for now)
function CivTransformerPolicy:LayerNorm(input_mtx)
    local epsilon = 1e-6
    local rows, cols = input_mtx:size()[1], input_mtx:size()[2]
    
    -- Create matrices of correct dimensions
    local mean_mtx = matrix:new(rows, 1, 0)
    local var_mtx = matrix:new(rows, 1, 0)
    
    -- Calculate mean for each row
    for i = 1, rows do
        local sum = 0
        for j = 1, cols do
            sum = sum + input_mtx:getelement(i, j)
        end
        mean_mtx:setelement(i, 1, sum / cols)
    end
    
    -- Calculate variance for each row
    for i = 1, rows do
        local sum_sq = 0
        local mean = mean_mtx:getelement(i, 1)
        for j = 1, cols do
            local diff = input_mtx:getelement(i, j) - mean
            sum_sq = sum_sq + (diff * diff)
        end
        var_mtx:setelement(i, 1, sum_sq / cols)
    end
    
    -- Normalize
    local output = matrix:new(rows, cols, 0)
    for i = 1, rows do
        local mean = mean_mtx:getelement(i, 1)
        local std = math.sqrt(var_mtx:getelement(i, 1) + epsilon)
        for j = 1, cols do
            local normalized = (input_mtx:getelement(i, j) - mean) / std
            output:setelement(i, j, normalized)
        end
    end
    
    return output
end

-- 5. Transformer Layer (Complete with Feedforward, Residual Connections, and Layer Normalization)
function CivTransformerPolicy:TransformerLayer(input, mask, layer_index)
    print("\nTransformerLayer:", layer_index)
    -- Convert input to matrix if needed
    local input_mtx = type(input.size) == "function" and input or tableToMatrix(input)
    local input_size = input_mtx:size()
    -- print("Input matrix shape:", input_size[1], "x", input_size[2])

    -- Multi-Head Attention with layer index
    --print("Calling MultiHeadAttention...")
    local attention_output = self:MultiHeadAttention(input_mtx, input_mtx, input_mtx, mask, layer_index)
    local attention_size = attention_output:size()
    -- print("Attention output shape:", attention_size[1], "x", attention_size[2])
    assert(attention_size[1] == input_size[1] and attention_size[2] == input_size[2],
           "Attention output shape mismatch")

    -- First Add & Norm
    local add_norm_output_1 = self:LayerNorm(matrix.add(input_mtx, attention_output))
    local norm1_size = add_norm_output_1:size()
    --print("First LayerNorm output shape:", norm1_size[1], "x", norm1_size[2])
    
    -- Feedforward with layer index
    --print("Calling Feedforward...")
    local ff_output = self:Feedforward(add_norm_output_1, layer_index)
    local ff_size = ff_output:size()
    -- print("Feedforward output shape:", ff_size[1], "x", ff_size[2])
    
    -- Second Add & Norm
    local final_output = self:LayerNorm(matrix.add(add_norm_output_1, ff_output))
    local final_size = final_output:size()
    --print("Final output shape:", final_size[1], "x", final_size[2])
    
    return final_output
end
-- 6. Transformer Encoder 
function CivTransformerPolicy:TransformerEncoder(input, mask)
    -- Verify input shape
    --print("\nTransformerEncoder:")
    local input_size = type(input.size) == "function" and input:size() or {#input, #input[1]}
    --print("TransformerEncoder Input Shape:", input_size[1], "x", input_size[2])
    assert(input_size[2] == TRANSFORMER_DIM, 
           "Input dimension mismatch. Expected " .. TRANSFORMER_DIM .. 
           ", got " .. input_size[2])

    local encoder_output = input
    for i = 1, TRANSFORMER_LAYERS do
        --print("\nTransformer Layer", i)
        -- print("Encoder input shape:", 
        --       type(encoder_output.size) == "function" and 
        --       table.concat(encoder_output:size(), "x") or 
        --       #encoder_output .. "x" .. #encoder_output[1])
        
        encoder_output = self:TransformerLayer(encoder_output, mask, i)
        
        -- Verify output shape hasn't changed
        local output_size = type(encoder_output.size) == "function" and 
                           encoder_output:size() or 
                           {#encoder_output, #encoder_output[1]}
        -- print("Encoder output shape:", output_size[1], "x", output_size[2])
        assert(output_size[1] == input_size[1] and output_size[2] == input_size[2],
               "Encoder output shape changed from " .. input_size[1] .. "x" .. input_size[2] ..
               " to " .. output_size[1] .. "x" .. output_size[2])
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

-- Initialization of the Policy Network
function CivTransformerPolicy:Init()

    if self.initialized then
        print("CivTransformerPolicy already initialized")
        return
    end
    -- Multi-head attention parameters
    self.num_heads = TRANSFORMER_HEADS
    self.d_model = TRANSFORMER_DIM
    self.d_k = self.d_model / self.num_heads
    self:InitializeCache()
    -- Existing embedding initialization
    self:InitStateEmbedding()
    
    -- Initialize projection matrices for each head
    self.head_projections = {
        w_q = {},  -- (d_model, d_k) per head
        w_k = {},
        w_v = {}
    }
        -- Initialize feedforward networks for each transformer layer
    self.ff1_weights = {}
    self.ff2_weights = {}
    self.ff1_bias = {}
    self.ff2_bias = {}

    local d_ff = 2048  -- Feedforward dimension
    for i = 1, TRANSFORMER_LAYERS do
        -- First linear layer (d_model -> d_ff)
        self.ff1_weights[i] = xavier_init(self.d_model, d_ff)
        self.ff1_bias[i] = matrix:new(1, d_ff, 0)  -- Zero-initialized bias
        
        -- Second linear layer (d_ff -> d_model)
        self.ff2_weights[i] = xavier_init(d_ff, self.d_model)
        self.ff2_bias[i] = matrix:new(1, self.d_model, 0)  -- Zero-initialized bias
    end
    
    for i = 1, self.num_heads do
        self.head_projections.w_q[i] = xavier_init(self.d_model, self.d_k)
        self.head_projections.w_k[i] = xavier_init(self.d_model, self.d_k)
        self.head_projections.w_v[i] = xavier_init(self.d_model, self.d_k)
    end

    -- Final projection matrix
    -- Initialize action type head
    self.action_type_projection = xavier_init(self.d_model, #ACTION_TYPES)
    
    -- Initialize option selection head
    self.option_projection = xavier_init(self.d_model, self.d_model)

    self.w_o = xavier_init(self.d_model, self.d_model)
    self.initialized = true
    print("Initialized Transformer Policy Network")
end

function CivTransformerPolicy:PadStateEmbed(state_embed)

    --print("State Embedding Size:", #state_embed)
    return state_embed
end

function CivTransformerPolicy:ProcessGameState(state)
    local state_embed = EncodeGameState(state)
    -- Convert state_embed to matrix if needed
    local state_mtx = type(state_embed.getelement) == "function" and 
        state_embed or 
        tableToMatrix({state_embed})
    
    --state_mtx = matrix.transpose(state_mtx)
    return state_mtx
end

function CivTransformerPolicy:Softmax(logits)
    -- Extract the actual logits from logits[1]
    local values = logits[1]
    
    -- Get max for numerical stability
    local max_val = -math.huge
    for i = 1, #values do
        max_val = math.max(max_val, values[i])
    end
    
    -- Calculate exp(x - max) and sum
    local exp_values = {}
    local sum_exp = 0
    
    for i = 1, #values do
        local exp_val = math.exp(values[i] - max_val)
        exp_values[i] = exp_val
        sum_exp = sum_exp + exp_val
    end
    
    -- Normalize to get probabilities
    local probs = {}
    for i = 1, #exp_values do
        probs[i] = exp_values[i] / sum_exp
    end
    
    return probs
end
-- Updated Forward function with action masking
-- Modify Forward function to use two-stage selection
function CivTransformerPolicy:Forward(state_mtx, possible_actions)
    print("\nTransformer Forward Pass:")
    
    -- Process state through transformer as before
    local embedded_state = matrix.mul(state_mtx, self.state_embedding_weights)
    embedded_state = self:AddPositionalEncoding(embedded_state)
    local transformer_output = self:TransformerEncoder(embedded_state, nil)
    
    -- Stage 1: Select action type
    local action_logits = self:ActionTypeHead(transformer_output)
    local action_mask = self:CreateAttentionMask(possible_actions)
    
    -- Apply mask and convert to probabilities
    local masked_logits = {}
    for i = 1, #ACTION_TYPES do
        masked_logits[i] = action_mask:getelement(i, 1) == 0 and -1e9 or action_logits[i]
    end
    local action_probs = self:Softmax(masked_logits)
    
    -- Sample action type
    local action_type = self:SampleFromProbs(ACTION_TYPES, action_probs)
    --print "Action Type:", action_type
    print("selected Action Type:", action_type)
    -- Stage 2: Select from available options for this action type
    if action_type == "EndTurn" then
        print("Selected EndTurn action, skipping for now")
        -- return {
        --     ActionType = "EndTurn",
        --     Parameters = {},
        --     action_probs = action_probs
        -- }
    end
    
    local available_options = possible_actions[action_type]
    print("Available options for", action_type, ":", available_options and #available_options or "nil")
    if not available_options or #available_options == 0 then
        return {
            ActionType = "EndTurn",
            Parameters = {},
            action_probs = action_probs
        }
    end

    -- Get option selection logits
    local option_logits = self:OptionSelectionHead(transformer_output, action_type, available_options)
    local option_probs = self:Softmax(option_logits)
    local selected_option = self:SampleFromProbs(available_options, option_probs)
    print("Option logits dimensions:", option_logits:size()[1], "x", option_logits:size()[2])
    print("Number of option probabilities:", #option_probs)
    print("Selected option:", type(selected_option))
    return {
        ActionType = action_type,
        Parameters = selected_option,
        action_probs = action_probs,
        option_probs = option_probs
    }
end

-- New action type head
function CivTransformerPolicy:ActionTypeHead(transformer_output)
    -- Project transformer output to action type logits
    if not self.action_type_projection then
        self.action_type_projection = self:XavierInit(self.d_model, #ACTION_TYPES)
    end
    
    return matrix.mul(transformer_output, self.action_type_projection)
end

-- New option selection head
function CivTransformerPolicy:OptionSelectionHead(transformer_output, action_type, available_options)
    -- Create option embeddings based on action type
    local option_embeddings = self:EmbedOptions(action_type, available_options)
    
    -- Project transformer output to option space
    if not self.option_projection then
        self.option_projection = self:XavierInit(self.d_model, self.d_model)
    end
    local projected_state = matrix.mul(transformer_output, self.option_projection)
    
    -- Compute attention scores between state and options
    local attention_scores = matrix.mul(projected_state, matrix.transpose(option_embeddings))
    return attention_scores
end

-- Helper function to embed options based on their parameters
function CivTransformerPolicy:EmbedOptions(action_type, options)
    local embeddings = matrix:new(#options, self.d_model)
    
    for i, option in ipairs(options) do
        local embedding = self:CreateOptionEmbedding(action_type, option)
        -- Copy embedding to row i of embeddings matrix
        for j = 1, self.d_model do
            embeddings:setelement(i, j, embedding[j])
        end
    end
    
    return embeddings
end



-- Create embeddings for different types of options
function CivTransformerPolicy:CreateOptionEmbedding(action_type, option)
    local embedding = {}
    
    -- Different embedding logic based on action type
    if action_type == "CityProduction" then
        -- Embed production info
        table.insert(embedding, Normalize(option.Cost or 0, 2000))  -- Production cost
        table.insert(embedding, Normalize(option.Turns or 0, 100))  -- Turns to complete
        local prodType = {
            Units = 1,
            Buildings = 2,
            Districts = 3,
            Projects = 4
        }
        table.insert(embedding, Normalize(prodType[option.ProductionType] or 0, 4))

    elseif action_type == "MoveUnit" or action_type == "PlaceDistrict" then
        -- Embed position info
        table.insert(embedding, Normalize(option.X or 0, MAP_DIMENSION))
        table.insert(embedding, Normalize(option.Y or 0, MAP_DIMENSION))

    elseif action_type == "PurchaseWithGold" or action_type == "PurchaseWithFaith" then
        -- Embed purchase info
        table.insert(embedding, Normalize(option.Cost or 0, 5000))
        local purchaseType = {
            UNIT = 1,
            BUILDING = 2,
            DISTRICT = 3
        }
        table.insert(embedding, Normalize(purchaseType[option.PurchaseType] or 0, 3))
        table.insert(embedding, Normalize(option.CityID or 0, 100))

    elseif action_type == "FoundReligion" then
        -- Embed religion info
        table.insert(embedding, Normalize(option.UnitID or 0, 1000))
        for _, beliefHash in ipairs(option.BeliefHashes or {}) do
            table.insert(embedding, Normalize(beliefHash or 0, 1000000))
        end

    elseif action_type == "SpreadReligion" then
        -- Embed religious spread info
        table.insert(embedding, Normalize(option.UnitID or 0, 1000))
        table.insert(embedding, Normalize(option.CityID or 0, 100))

    elseif action_type == "BuildImprovement" then
        -- Embed builder info
        table.insert(embedding, Normalize(option.UnitID or 0, 1000))
        for _, improvement in ipairs(option.ValidImprovements or {}) do
            table.insert(embedding, Normalize(improvement or 0, 1000000))
        end

    elseif action_type == "EstablishTradeRoute" then
        -- Embed trade route info
        table.insert(embedding, Normalize(option.TraderUnitID or 0, 1000))
        table.insert(embedding, Normalize(option.OriginCityID or 0, 100))
        table.insert(embedding, Normalize(option.DestinationCityID or 0, 100))
        table.insert(embedding, Normalize(option.Distance or 0, 50))
        -- Embed yields
        if option.Yields then
            table.insert(embedding, Normalize(option.Yields.Food or 0, 20))
            table.insert(embedding, Normalize(option.Yields.Production or 0, 20))
            table.insert(embedding, Normalize(option.Yields.Gold or 0, 50))
            table.insert(embedding, Normalize(option.Yields.Science or 0, 20))
            table.insert(embedding, Normalize(option.Yields.Culture or 0, 20))
            table.insert(embedding, Normalize(option.Yields.Faith or 0, 20))
        end

    elseif action_type == "ChooseTech" then
        -- Embed tech choice
        table.insert(embedding, Normalize(option.Hash or 0, 1000000))

    elseif action_type == "ChooseCivic" then
        -- Embed civic choice
        table.insert(embedding, Normalize(option.Hash or 0, 1000000))

    elseif action_type == "AssignGovernorTitle" then
        -- Embed governor title info
        table.insert(embedding, Normalize(option.GovernorType or 0, 100))
        table.insert(embedding, option.IsInitialAppointment and 1 or 0)
        if option.PromotionHash then
            table.insert(embedding, Normalize(option.PromotionHash or 0, 1000000))
        end

    elseif action_type == "AssignGovernorToCity" then
        -- Embed governor assignment info
        table.insert(embedding, Normalize(option.GovernorType or 0, 100))
        table.insert(embedding, Normalize(option.CityID or 0, 100))
        table.insert(embedding, Normalize(option.X or 0, MAP_DIMENSION))
        table.insert(embedding, Normalize(option.Y or 0, MAP_DIMENSION))
        table.insert(embedding, option.CurrentlyAssigned and 1 or 0)

    elseif action_type == "ActivateGreatPerson" then
        -- Embed great person info
        table.insert(embedding, Normalize(option.UnitID or 0, 1000))
        table.insert(embedding, Normalize(option.IndividualID or 0, 1000))
        if option.ValidPlots then
            for _, plot in ipairs(option.ValidPlots) do
                table.insert(embedding, Normalize(plot or 0, 10000))
            end
        end

    elseif action_type == "SendEnvoy" or action_type == "MakePeace" or action_type == "LevyMilitary" then
        -- Embed player target info
        table.insert(embedding, Normalize(option or 0, 100)) -- PlayerID is passed directly

    elseif action_type == "CityRangedAttack" or action_type == "EncampmentRangedAttack" then
        -- Embed target info
        table.insert(embedding, Normalize(option or 0, 1000)) -- ID is passed directly

    elseif action_type == "ChangePolicies" then
        -- Embed policy info
        table.insert(embedding, Normalize(option.SlotIndex or 0, 20))
        table.insert(embedding, Normalize(option.PolicyHash or 0, 1000000))
    end

    -- Pad embedding to fixed dimension
    while #embedding < self.d_model do
        table.insert(embedding, 0)
    end

    return embedding
end

-- Helper function for sampling
function CivTransformerPolicy:SampleFromProbs(options, probs)
    local rand = math.random()
    local cumsum = 0
    
    for i, prob in ipairs(probs) do
        cumsum = cumsum + prob
        if rand <= cumsum then
            return options[i]
        end
    end
    
    return options[#options]  -- Fallback to last option
end


function CivTransformerPolicy:SaveWeights(identifier)
    -- Convert network weights to serializable tables
    local weights = {
        state_embedding = matrixToTable(self.state_embedding_weights),
        head_projections = {
            w_q = {},
            w_k = {},
            w_v = {}
        },
        w_o = matrixToTable(self.w_o),
        ff1_weights = {},
        ff2_weights = {},
        ff1_bias = {},
        ff2_bias = {}
    }

    -- Convert head projections
    for i = 1, self.num_heads do
        weights.head_projections.w_q[i] = matrixToTable(self.head_projections.w_q[i])
        weights.head_projections.w_k[i] = matrixToTable(self.head_projections.w_k[i])
        weights.head_projections.w_v[i] = matrixToTable(self.head_projections.w_v[i])
    end

    -- Convert feedforward weights
    for i = 1, TRANSFORMER_LAYERS do
        weights.ff1_weights[i] = matrixToTable(self.ff1_weights[i])
        weights.ff2_weights[i] = matrixToTable(self.ff2_weights[i])
        weights.ff1_bias[i] = matrixToTable(self.ff1_bias[i])
        weights.ff2_bias[i] = matrixToTable(self.ff2_bias[i])
    end

    -- Save using storage utility
    Storage_table(weights, "policy_weights_" .. identifier)
end

function CivTransformerPolicy:LoadWeights(identifier)
    local weights = Read_tableString("policy_weights_" .. identifier)
    if not weights then return false end
    
    -- Convert tables back to matrices
    self.state_embedding_weights = tableToMatrix(weights.state_embedding)
    self.w_o = tableToMatrix(weights.w_o)
    
    -- Initialize head projections
    self.head_projections = {
        w_q = {},
        w_k = {},
        w_v = {}
    }
    
    for i = 1, self.num_heads do
        self.head_projections.w_q[i] = tableToMatrix(weights.head_projections.w_q[i])
        self.head_projections.w_k[i] = tableToMatrix(weights.head_projections.w_k[i])
        self.head_projections.w_v[i] = tableToMatrix(weights.head_projections.w_v[i])
    end
    
    -- Initialize feedforward weights
    self.ff1_weights = {}
    self.ff2_weights = {}
    self.ff1_bias = {}
    self.ff2_bias = {}
    
    for i = 1, TRANSFORMER_LAYERS do
        self.ff1_weights[i] = tableToMatrix(weights.ff1_weights[i])
        self.ff2_weights[i] = tableToMatrix(weights.ff2_weights[i])
        self.ff1_bias[i] = tableToMatrix(weights.ff1_bias[i])
        self.ff2_bias[i] = tableToMatrix(weights.ff2_bias[i])
    end
    
    return true
end

