-- civ6obv.lua

-- Initialize context if not already done
if not ContextPtr then
    ContextPtr = {};
end

-- Base game includes
include("Civ6Common");
include("InstanceManager");
include( "SupportFunctions" );
-- Your mod includes
include("civactionsRL"); -- or whatever your actions file is named
--------------------------------------------------
-- OBSERVATION FUNCTIONS
--------------------------------------------------

-- Gets the current turn number.
function GetTurnNumber()
  print("GetTurnNumber: Getting current turn number...")
  local turn = Game.GetCurrentGameTurn()
  print("GetTurnNumber: Current turn number is: " .. tostring(turn))
  return turn;
end

-- Gets the current player's ID.
function GetPlayerID()
  print("GetPlayerID: Getting local player ID...")
  local playerID = Game.GetLocalPlayer();
  print("GetPlayerID: Local player ID is: " .. tostring(playerID))
  return playerID;
end

-- Gets information about the local player.
function GetPlayerData(playerID)
  print("GetPlayerData: Getting data for player: " .. tostring(playerID))

  local player = Players[playerID];
  if not player then 
    print("GetPlayerData: Player not found.")
    return nil 
  end

  local data = {
    Gold = player:GetTreasury():GetGold(),
    Faith = player:GetFaith():GetFaith(),
    SciencePerTurn = player:GetScienceYield(),
    CulturePerTurn = player:GetCultureYield(),
    GoldPerTurn = player:CalculateGoldPerTurn(),
    IsAtWar = player:IsAtWar(),  -- Check if at war with any major civ
    Cities = {}, -- Add city data using GetCityData()
    Units = {},  -- Add unit data using GetUnitData()
    TechsResearched = {},
    CivicsResearched = {},
    CurrentGovernment = nil,
    CurrentPolicies = {},
    GreatPeoplePoints = {}
  };

  print("GetPlayerData: Gathering city data...")
  -- Add city data
  for city in player:GetCities():Members() do
    table.insert(data.Cities, GetCityData(city:GetID()));
  end

  print("GetPlayerData: Gathering unit data...")
  -- Add unit data
  for unit in player:GetUnits():Members() do
    table.insert(data.Units, GetUnitData(unit));
  end

  -- Add researched techs
  print("GetPlayerData: Gathering researched techs...")
  local playerTechs = player:GetTechs()
  for tech in GameInfo.Technologies() do
    if playerTechs:HasTech(tech.Hash) then
      table.insert(data.TechsResearched, tech.TechnologyType)
    end
  end

  -- Add researched civics
  print("GetPlayerData: Gathering researched civics...")
  local playerCulture = player:GetCulture()
  for civic in GameInfo.Civics() do
    if playerCulture:HasCivic(civic.Hash) then
      table.insert(data.CivicsResearched, civic.CivicType)
    end
  end

  -- Get current government
  print("GetPlayerData: Getting current government...")
  local governmentIndex = playerCulture:GetCurrentGovernment()
  if governmentIndex then
    data.CurrentGovernment = GameInfo.Governments[governmentIndex].GovernmentType
  end

  -- Get current policies
  print("GetPlayerData: Getting current policies...")
  for slotIndex = 0, playerCulture:GetNumGovernmentSlots() - 1 do
    local policyIndex = playerCulture:GetGovernmentPolicyInSlot(slotIndex)
    if policyIndex then
      local policy = GameInfo.Policies[policyIndex]
      data.CurrentPolicies[slotIndex] = policy.PolicyType
    end
  end

  -- Get Great People points
  print("GetPlayerData: Getting Great People points...")
  for class in GameInfo.GreatPersonClasses() do
    data.GreatPeoplePoints[class.GreatPersonClassType] = player:GetGreatPeoplePoints():GetPointsTotal(class.Hash)
  end

  print("GetPlayerData: Player data collection complete.")
  return data;
end

-- Gets detailed information about a specific city.
-- @param cityID The ID of the city.
function GetCityData(cityID)
  print("GetCityData: Getting data for city ID: " .. tostring(cityID))
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local city = player:GetCities():FindID(cityID);

  if not city then 
    print("GetCityData: City not found.")
    return nil 
  end

  local data = {
    ID = cityID,
    Name = city:GetName(),
    Population = city:GetPopulation(),
    Position = { X = city:GetX(), Y = city:GetY() },
    Districts = {},
    Buildings = {},
    ProductionQueue = {},
    FoodYield = city:GetYield(YieldTypes.FOOD),
    ProductionYield = city:GetYield(YieldTypes.PRODUCTION),
    GoldYield = city:GetYield(YieldTypes.GOLD),
    ScienceYield = city:GetYield(YieldTypes.SCIENCE),
    CultureYield = city:GetYield(YieldTypes.CULTURE),
    FaithYield = city:GetYield(YieldTypes.FAITH),
    Housing = city:GetGrowth():GetHousing(),
    Amenities = city:GetGrowth():GetAmenities()
  };

  print("GetCityData: Gathering district information for city...")
    -- Add district information
  for district in city:GetDistricts():Members() do
    local districtInfo = GameInfo.Districts[district:GetType()];
    table.insert(data.Districts, {
      DistrictType = districtInfo.DistrictType,
      IsPillaged = city:GetDistricts():IsPillaged(district:GetType()),
      Position = { X = district:GetX(), Y = district:GetY() }
    });
  end

  print("GetCityData: Gathering building information for city...")
  -- Add building information
  local cityBuildings = city:GetBuildings();
  for buildingType in GameInfo.Buildings() do
    if cityBuildings:HasBuilding(buildingType.Hash) then
      table.insert(data.Buildings, {
        BuildingType = buildingType.BuildingType,
        IsPillaged = cityBuildings:IsPillaged(buildingType.Hash)
      });
    end
  end

  print("GetCityData: Gathering production queue information for city...")
  -- Add production queue information
  local queue = city:GetBuildQueue();
  local queueData = {};
  for i, item in ipairs(queue) do
    local itemData = {
      Name = item.Name,
      Turns = item.Turns,
      Cost = item.Cost
    };
    
    -- Determine the type of item (Unit, Building, District, Project)
    if GameInfo.Units[item.ID] then
        itemData.Type = "UNIT"
        itemData.SubType = GameInfo.Units[item.ID].UnitType
    elseif GameInfo.Buildings[item.ID] then
        itemData.Type = "BUILDING"
        itemData.SubType = GameInfo.Buildings[item.ID].BuildingType
    elseif GameInfo.Districts[item.ID] then
        itemData.Type = "DISTRICT"
        itemData.SubType = GameInfo.Districts[item.ID].DistrictType
    elseif GameInfo.Projects[item.ID] then
        itemData.Type = "PROJECT"
    end
  end
  print("GetCityData: City data collection complete for city ID: " .. tostring(cityID))
  return data
end

		-- Determines all possible actions for the player in the current state.
-- Helper function to get valid district plots
function GetValidDistrictPlots(city, districtHash)
    local validPlots = {}
    local cityX = city:GetX()
    local cityY = city:GetY()
    local cityRadius = 3 -- Standard city workable radius
    local cityOwnerID = city:GetOwner()
    local cityID = city:GetID()
    
    -- Helper to check if plot is owned by this city
    local function IsPlotOwnedByCity(plot)
        if plot:IsOwned() then
            return plot:GetOwner() == cityOwnerID
        end
        return false
    end
  
    -- Iterate through plots in city radius 
    for dx = -cityRadius, cityRadius do
        for dy = -cityRadius, cityRadius do
            local plotX = cityX + dx
            local plotY = cityY + dy
            local plot = Map.GetPlot(plotX, plotY)
            
            if plot and IsPlotOwnedByCity(plot) then
                -- Check if district can be placed here using the specific district check
                if plot:CanHaveDistrict(GameInfo.Districts[districtHash].Index, cityOwnerID, cityID) then
                    table.insert(validPlots, {
                        X = plotX,
                        Y = plotY,
                        Appeal = plot:GetAppeal(),
                        TerrainType = plot:GetTerrainType(),
                        DistrictHash = districtHash
                    })
                end
            end
        end
    end
  
    return validPlots
end

function GetPossibleActions()
  print("GetPossibleActions: Determining possible actions for player...")
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local playerCulture = player:GetCulture();
  local playerTechs = player:GetTechs();
  local actionTypes = {}
  local possibleProductions = {
    Units = {},
    Buildings = {},
    Districts = {},
    Projects = {}
};

  local possibleActions = {
    EndTurn = true, -- Always possible (unless blocked for some reason)
    ChooseCivic = {},
    ChooseTech = {},
    CityRangedAttack = {},
    EncampmentRangedAttack = {},
    SendEnvoy = {},
    MakePeace = {},
    LevyMilitary = {},
    RecruitGreatPerson = {},
    RejectGreatPerson = {},
    PatronizeGreatPersonGold = {},
    PatronizeGreatPersonFaith = {},
    MoveUnit = {},
    SelectUnit = {},
    UnitRangedAttack = {},
    UnitAirAttack = {},
    FormUnit = {},
    RebaseUnit = {},
    WMDStrike = {},
    QueueUnitPath = {},
    BuildImprovement = {},
    EnterFormation = {},
    FoundCity = {},
    PromoteUnit = {},
    DeleteUnit = {},
    UpgradeUnit = {},
    ChangeGovernment = {},
    ChangePolicies = {},
    EstablishTradeRoute = {},
    CityProduction = {},
    PlaceDistrict = {}
  };
  


-- In GetPossibleActions()
print("GetPossibleActions: Checking civics...")
-- CIVICS
local playerID = Game.GetLocalPlayer()
local player = Players[playerID]
local playerCulture = player:GetCulture()
local currentCivicID = playerCulture:GetProgressingCivic()

-- If no civic is being researched (currentCivicID is -1) or if we can switch civics
if currentCivicID == -1 then
    print("No civic currently in progress, checking available civics...")
    for civic in GameInfo.Civics() do
        local civicIndex = civic.Index
        -- Debug print civic info
        --print("Checking civic: " .. civic.CivicType .. " Index: " .. tostring(civicIndex))
        
        -- Check if the civic can be researched
        if playerCulture:CanProgress(civicIndex) then
            print("Can progress civic: " .. civic.CivicType)
            if not playerCulture:HasCivic(civicIndex) then
                print("Don't have civic yet, adding as possible choice: " .. civic.CivicType)
                table.insert(possibleActions.ChooseCivic, {
                    CivicType = civic.CivicType,
                    Hash = civicIndex  -- Use Index instead of Hash for proper lookup
                })
                print("Added civic: " .. civic.CivicType .. " with index: " .. tostring(civicIndex))
            end
        end
    end
    -- Debug print total available civics
    print("Total available civics: " .. #possibleActions.ChooseCivic)
end

  print("GetPossibleActions: Checking technologies...")

  -- TECHNOLOGIES
-- Check if no technology is currently being researched
-- In GetPossibleActions(), replace/modify the tech checking section:
-- TECHNOLOGIES 
local playerID = Game.GetLocalPlayer()
local player = Players[playerID]
local playerTechs = player:GetTechs()
local currentTechID = playerTechs:GetResearchingTech()

print("GetPossibleActions: Checking available techs...")
print("Current research tech ID: " .. tostring(currentTechID))

-- If no tech is being researched (currentTechID is -1) or if we can switch techs
if currentTechID == -1 then
    print("No tech currently being researched")
    -- Check each available tech
    for tech in GameInfo.Technologies() do
        local techIndex = tech.Index
        if playerTechs:CanResearch(techIndex) then
            print("GetPossibleActions: Adding possible tech: " .. tostring(tech.TechnologyType))
            table.insert(possibleActions.ChooseTech, {
                TechType = tech.TechnologyType,
                Hash = GameInfo.Technologies[tech.TechnologyType].Hash
            })
        end
    end
end
-- Inside GetPossibleActions()
print("GetPossibleActions: Checking city production options...")

local player = Players[Game.GetLocalPlayer()];

print("\n=== BEGINNING CITY PRODUCTION ANALYSIS ===")
-- Inside GetPossibleActions() where we process city productions
for _, city in player:GetCities():Members() do
    local cityID = city:GetID()
    print("\nProcessing City ID: " .. tostring(cityID))
    local buildQueue = city:GetBuildQueue()
    
    -- Check Units
    print("\nChecking Available Units:")
    for row in GameInfo.Units() do
        if row and row.Hash and buildQueue:CanProduce(row.Hash, false, true) then
            print("- Can produce unit: " .. tostring(row.UnitType))
            print("  Hash: " .. tostring(row.Hash))
            print("  Cost: " .. tostring(buildQueue:GetUnitCost(row.Index)))
            
            -- Insert into possibleActions (not possibleProductions)
            table.insert(possibleActions.CityProduction, {
                CityID = cityID,
                ProductionHash = row.Hash,
                ProductionType = "Units",
                Name = row.UnitType,
                Cost = buildQueue:GetUnitCost(row.Index),
                Turns = buildQueue:GetTurnsLeft(row.UnitType)
            })
        end
    end

    -- Check Buildings
    print("\nChecking Available Buildings:")
    for row in GameInfo.Buildings() do
        if row and row.Hash and buildQueue:CanProduce(row.Hash, true) then
            local cost = row.Index and buildQueue:GetBuildingCost(row.Index) or 0
            local turns = row.Index and buildQueue:GetTurnsLeft(row.BuildingType) or 0
            print("- Can produce building: " .. tostring(row.BuildingType))
            print("  Hash: " .. tostring(row.Hash))
            print("  Cost: " .. tostring(buildQueue:GetBuildingCost(row.Index)))
            -- Insert into possibleActions
            table.insert(possibleActions.CityProduction, {
                CityID = cityID,
                ProductionHash = row.Hash,
                ProductionType = "Buildings",
                Name = row.BuildingType,
                Cost = cost,
                Turns = turns
            })
        end
    end

    -- Check Projects
    print("\nChecking Available Projects:")
    for row in GameInfo.Projects() do
        if row and row.Hash and buildQueue:CanProduce(row.Hash, true) then
            local cost = row.Index and buildQueue:GetProjectCost(row.Index) or 0
            local turns = row.Index and buildQueue:GetTurnsLeft(row.ProjectType) or 0
            
            -- Insert into possibleActions
            table.insert(possibleActions.CityProduction, {
                CityID = cityID,
                ProductionHash = row.Hash,
                ProductionType = "Projects",
                Name = row.ProjectType,
                Cost = cost,
                Turns = turns
            })
        end
    end

    -- Check Districts 
    print("\nChecking Available Districts:")
    for row in GameInfo.Districts() do
        if row and row.Hash and buildQueue:CanProduce(row.Hash, true) then
            print("- Checking district: " .. tostring(row.DistrictType))
            local validPlots = GetValidDistrictPlots(city, row.Hash)
            print("  Number of valid plots: " .. #validPlots)
            
            if #validPlots > 0 then
                print("  Adding district to possibilities")
                -- Insert into possibleActions
                table.insert(possibleActions.CityProduction, {
                    CityID = cityID,
                    ProductionHash = row.Hash,
                    ProductionType = "Districts",
                    Name = row.DistrictType,
                    Cost = buildQueue:GetDistrictCost(row.Index),
                    Turns = buildQueue:GetTurnsLeft(row.DistrictType),
                    ValidPlots = validPlots
                })
            end
        end
    end
end
print("\n=== END OF CITY PRODUCTION ANALYSIS ===")

  print("GetPossibleActions: Checking city ranged attacks...")
    -- CITY RANGED ATTACK
  for city in player:GetCities():Members() do
    if CityManager.CanStartCommand(city, CityCommandTypes.RANGE_ATTACK) then
	  print("GetPossibleActions: Adding city ranged attack for city ID: " .. tostring(city:GetID()))
      table.insert(possibleActions.CityRangedAttack, city:GetID());
    end
  end


  print("GetPossibleActions: Checking encampment ranged attacks...")
-- ENCAMPMENT RANGED ATTACK
for district in player:GetDistricts():Members() do
    -- Get the actual district object using the ID
    local districtObj = player:GetDistricts():FindID(district)
    
    if districtObj then
        local districtTypeId = districtObj:GetType()
        local districtInfo = GameInfo.Districts[districtTypeId]
        
        -- Check if we got valid district info and it's an encampment
        if districtInfo and districtInfo.DistrictType == "DISTRICT_ENCAMPMENT" then
            if CityManager.CanStartCommand(districtObj, CityCommandTypes.RANGE_ATTACK) then
                print("GetPossibleActions: Adding encampment ranged attack for district ID: " .. tostring(district))
                table.insert(possibleActions.EncampmentRangedAttack, district)
            end
        end
    end
end

  print("Finished checking districts")

  print("GetPossibleActions: Checking envoy actions...")
  -- SEND ENVOY
  local influence = player:GetInfluence()
  if influence:CanGiveInfluence() then
      -- Get all players and filter for minor civs (city states)
      for _, cityState in ipairs(PlayerManager.GetAlive()) do
          local cityStatePlayer = Players[cityState]
          -- Check if this is a city state
          if cityStatePlayer and cityStatePlayer:IsCityState() then
              if influence:CanGiveTokensToPlayer(cityState) then
                  print("GetPossibleActions: Adding send envoy action for city-state ID: " .. tostring(cityState))
                  table.insert(possibleActions.SendEnvoy, cityState)
              end
          end
      end
  end

  print("GetPossibleActions: Checking make peace actions...")
  -- MAKE PEACE WITH CITY-STATE
  for _, cityState in ipairs(PlayerManager.GetAlive()) do
      local cityStatePlayer = Players[cityState]
      -- Check if this is a city state
      if cityStatePlayer and cityStatePlayer:IsCityState() then
          if player:GetDiplomacy():CanMakePeaceWith(cityState) then
              print("GetPossibleActions: Adding make peace action for city-state ID: " .. tostring(cityState))
              table.insert(possibleActions.MakePeace, cityState)
          end
      end
  end
  
  print("GetPossibleActions: Checking levy military actions...")
  -- LEVY MILITARY
  for _, cityState in ipairs(PlayerManager.GetAlive()) do
      local cityStatePlayer = Players[cityState]
      -- Check if this is a city state
      if cityStatePlayer and cityStatePlayer:IsCityState() then
          if player:GetInfluence():CanLevyMilitary(cityState) then
              print("GetPossibleActions: Adding levy military action for city-state ID: " .. tostring(cityState))
              table.insert(possibleActions.LevyMilitary, cityState)
          end
      end
  end

  print("GetPossibleActions: Checking Great People actions...")
    -- GREAT PEOPLE
  local greatPeople = Game.GetGreatPeople();
  for individual in GameInfo.GreatPersonIndividuals() do
    if greatPeople:CanRecruitPerson(playerID, individual.Hash) then
	  print("GetPossibleActions: Adding recruit Great Person action for: " .. tostring(individual.Name))
      table.insert(possibleActions.RecruitGreatPerson, individual.Name);
    end
    if greatPeople:CanRejectPerson(playerID, individual.Hash) then
	  print("GetPossibleActions: Adding reject Great Person action for: " .. tostring(individual.Name))
      table.insert(possibleActions.RejectGreatPerson, individual.Name);
    end
    if greatPeople:CanPatronizePerson(playerID, individual.Hash, YieldTypes.GOLD) then
	  print("GetPossibleActions: Adding patronize with Gold action for: " .. tostring(individual.Name))
      table.insert(possibleActions.PatronizeGreatPersonGold, individual.Name);
    end
    if greatPeople:CanPatronizePerson(playerID, individual.Hash, YieldTypes.FAITH) then
	  print("GetPossibleActions: Adding patronize with Faith action for: " .. tostring(individual.Name))
      table.insert(possibleActions.PatronizeGreatPersonFaith, individual.Name);
    end
  end

 -- Helper function to get all possible actions for a single unit
-- Helper function to get all possible actions for a single unit
function GetPossibleUnitActions(unitID, player)
  local unit = player:GetUnits():FindID(unitID)
  if not unit then return nil end
  
  local actions = {}
  local plotX = unit:GetX()
  local plotY = unit:GetY()
  
  -- Check movement possibilities
  if unit:IsReadyToMove() then
      local movementRange = {}
      local range = unit:GetMovesRemaining()
      
      -- Get plots within range manually
      for dx = -range, range do
          for dy = -range, range do
              local newX = plotX + dx
              local newY = plotY + dy
              if Map.IsPlot(newX, newY) then
                  local targetPlot = Map.GetPlot(newX, newY)
                  if targetPlot then
                      -- Check if unit can move to this plot
                      local tParameters = {}
                      tParameters[UnitOperationTypes.PARAM_X] = newX
                      tParameters[UnitOperationTypes.PARAM_Y] = newY
                      if UnitManager.CanStartOperation(unit, UnitOperationTypes.MOVE_TO, nil, tParameters) then
                          table.insert(movementRange, {
                              UnitID = unitID,
                              X = newX,
                              Y = newY
                          })
                      end
                  end
              end
          end
      end
      if #movementRange > 0 then
          actions.MoveUnit = movementRange
      end
  end

  -- Check ranged attack capability
  local rangedCombat = unit:GetRangedCombat()
  if rangedCombat > 0 then
      local rangeTargets = {}
      local range = unit:GetRange()
      for dx = -range, range do
          for dy = -range, range do
              local newX = plotX + dx
              local newY = plotY + dy
              if Map.IsPlot(newX, newY) then
                  local tParameters = {}
                  tParameters[UnitOperationTypes.PARAM_X] = newX
                  tParameters[UnitOperationTypes.PARAM_Y] = newY
                  if UnitManager.CanStartOperation(unit, UnitOperationTypes.RANGE_ATTACK, nil, tParameters) then
                      table.insert(rangeTargets, {
                          UnitID = unitID,
                          X = newX,
                          Y = newY
                      })
                  end
              end
          end
      end
      if #rangeTargets > 0 then
          actions.UnitRangedAttack = rangeTargets
      end
  end

  -- Always add the SelectUnit action
  actions.SelectUnit = { { UnitID = unitID } }

  -- Check if unit can found a city
  if unit:GetUnitType() == GameInfo.Units["UNIT_SETTLER"].Index then
      if UnitManager.CanStartOperation(unit, UnitOperationTypes.FOUND_CITY, nil) then
          actions.FoundCity = { { UnitID = unitID } }
      end
  end

-- Check if unit can be promoted
if unit:GetExperience() and unit:GetExperience():GetLevel() > 0 then
  local availablePromotions = {}
  -- Only need 4 arguments: unit, actionHash, testOnly(true), isFirstCheck(true)
  local bCanStart, tResults = UnitManager.CanStartCommand(
      unit,
      UnitCommandTypes.PROMOTE,
      true,
      true
  );

  if bCanStart and tResults and tResults[UnitCommandResults.PROMOTIONS] then
      for _, promotion in ipairs(tResults[UnitCommandResults.PROMOTIONS]) do
          table.insert(availablePromotions, {
              UnitID = unitID,
              PromotionType = promotion.Hash
          })
      end
  end
  if #availablePromotions > 0 then
      actions.PromoteUnit = availablePromotions
  end
end

  -- Check if unit can be upgraded
  if UnitManager.CanStartCommand(unit, UnitCommandTypes.UPGRADE) then
      actions.UpgradeUnit = { { UnitID = unitID } }
  end

  -- Unit can always be deleted
  actions.DeleteUnit = { { UnitID = unitID } }

  return actions
end

-- Main function to integrate with the observation system
function GetAllUnitActions(player)
  local unitActions = {
      MoveUnit = {},
      SelectUnit = {},
      UnitRangedAttack = {},
      FoundCity = {},
      PromoteUnit = {},
      DeleteUnit = {},
      UpgradeUnit = {}
  }

  print("=== BEGIN UNIT DISCOVERY ===")
  
  local pPlayerUnits:table = player:GetUnits();
  local militaryUnits:table = {};
  local civilianUnits:table = {};
  
  -- First sort units into categories
  for i, pUnit in pPlayerUnits:Members() do
      print("Found unit: " .. tostring(i))
      local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
      print("Unit type: " .. unitInfo.UnitType)
      
      if pUnit:GetCombat() == 0 and pUnit:GetRangedCombat() == 0 then
          -- if we have no attack strength we must be civilian
          print("Adding to civilian units")
          table.insert(civilianUnits, pUnit);
      else
          print("Adding to military units")
          table.insert(militaryUnits, pUnit);
      end
  end

  -- Process military units
  for _, pUnit in ipairs(militaryUnits) do
      print("Processing military unit")
      local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
      
      -- Check movement
      local movesRemaining = pUnit:GetMovesRemaining()
      if movesRemaining > 0 then
          local moves = GetValidMoveLocations(pUnit)
          for _, move in ipairs(moves) do
              table.insert(unitActions.MoveUnit, {
                  UnitID = pUnit:GetID(),
                  X = move.x,
                  Y = move.y
              })
          end
      end
      
      -- Add delete action
      table.insert(unitActions.DeleteUnit, { UnitID = pUnit:GetID() })
  end

  -- Process civilian units
  for _, pUnit in ipairs(civilianUnits) do
      print("Processing civilian unit")
      local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
      
      -- Check if unit is a settler
      if unitInfo.FoundCity then
          print("Found settler!")
          if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.FOUND_CITY, nil) then
              print("Settler can found city")
              table.insert(unitActions.FoundCity, { UnitID = pUnit:GetID() })
          end
      end

      -- Check movement
      local movesRemaining = pUnit:GetMovesRemaining()
      if movesRemaining > 0 then
          local moves = GetValidMoveLocations(pUnit)
          for _, move in ipairs(moves) do
              table.insert(unitActions.MoveUnit, {
                  UnitID = pUnit:GetID(),
                  X = move.x,
                  Y = move.y
              })
          end
      end

      -- Add delete action
      table.insert(unitActions.DeleteUnit, { UnitID = pUnit:GetID() })
  end

  return unitActions
end

-- Helper function to get valid move locations for a unit
function GetValidMoveLocations(unit)
  local validMoves = {}
  local range = math.floor(unit:GetMovesRemaining())
  local startX = unit:GetX()
  local startY = unit:GetY()
  
  print(string.format("Checking moves from position %d,%d with range %d", startX, startY, range))
  
  for dx = -range, range do
      for dy = -range, range do
          local newX = startX + dx
          local newY = startY + dy
          if Map.IsPlot(newX, newY) then
              local targetPlot = Map.GetPlot(newX, newY)
              if targetPlot then
                  local tParameters = {}
                  tParameters[UnitOperationTypes.PARAM_X] = newX
                  tParameters[UnitOperationTypes.PARAM_Y] = newY
                  if UnitManager.CanStartOperation(unit, UnitOperationTypes.MOVE_TO, nil, tParameters) then
                      table.insert(validMoves, {x = newX, y = newY})
                  end
              end
          end
      end
  end
  
  print("Found " .. #validMoves .. " valid move locations")
  return validMoves
end

--CHECKING ALL ACTIONS THAT ARE POSSIBLE
print("GetPossibleActions: Checking unit actions...")
local unitActions = GetAllUnitActions(player)
for actionType, actions in pairs(unitActions) do
    if #actions > 0 then
        possibleActions[actionType] = actions
        print("GetPossibleActions: Found " .. #actions .. " possible " .. actionType .. " actions")
    end
end

  -- CHANGE GOVERNMENT
  print("GetPossibleActions: Checking change government...")
  if CanChangeGovernment() then
    for government in GameInfo.Governments() do
      if playerCulture:IsGovernmentUnlocked(government.Hash) then
	    print("GetPossibleActions: Adding change government to: " .. tostring(government.GovernmentType))
        table.insert(possibleActions.ChangeGovernment, government.GovernmentType);
      end
    end
  end


-- CHANGE POLICIES
print("GetPossibleActions: Checking change policies...")
if playerCulture and CanChangePolicies() then
  -- Get all policy slots
  local numPolicySlots = playerCulture:GetNumPolicySlots()
  local currentPolicies = {}  -- Keep track of currently slotted policies
  
  -- Build a list of currently slotted policies for efficient checking
  for i = 0, numPolicySlots - 1 do
    -- Changed this line from GetGovernmentPolicyInSlot to GetSlotPolicy
    local policyIndex = playerCulture:GetSlotPolicy(i)
    if policyIndex then
      currentPolicies[policyIndex] = true
    end
  end
  
  -- For each slot
  for slotIndex = 0, numPolicySlots-1 do
      local slotType = playerCulture:GetSlotType(slotIndex)
      
      -- For each policy
      for policy in GameInfo.Policies() do
          -- Check if the policy is not already slotted AND can be slotted in this slot
          if not currentPolicies[policy.Hash] and playerCulture:CanSlotPolicy(policy.Hash, slotIndex) then
            -- Add as possible action with properly structured data
            table.insert(possibleActions.ChangePolicies, {
                SlotIndex = slotIndex,
                PolicyType = policy.PolicyType,
                PolicyHash = policy.Hash
            })
          end
      end
  end
end

-- Helper functions for unit actions
function GetAvailablePromotions(unit)
    if not unit then return nil end
    local promotions = {}
    for row in GameInfo.UnitPromotions() do
        if unit:CanPromote() and UnitManager.CanPromoteUnit(unit, row.Index) then
            table.insert(promotions, {
                PromotionType = row.UnitPromotionType,
                Name = row.Name
            })
        end
    end
    return #promotions > 0 and promotions or nil
end

function UnitRangeAttack(unit, plotIndex)
    if not unit or not plotIndex then return false end
    return UnitManager.CanStartCommand(unit, UnitCommandTypes.RANGE_ATTACK, nil, {
        [UnitOperationTypes.PARAM_X] = Map.GetPlotByIndex(plotIndex):GetX(),
        [UnitOperationTypes.PARAM_Y] = Map.GetPlotByIndex(plotIndex):GetY()
    })
end

function UnitAirAttack(unit, plotIndex)
    if not unit or not plotIndex then return false end
    return UnitManager.CanStartCommand(unit, UnitCommandTypes.AIR_ATTACK, nil, {
        [UnitOperationTypes.PARAM_X] = Map.GetPlotByIndex(plotIndex):GetX(),
        [UnitOperationTypes.PARAM_Y] = Map.GetPlotByIndex(plotIndex):GetY()
    })
end

function UnitRebase(unit, plotIndex)
    if not unit or not plotIndex then return false end
    return UnitManager.CanStartCommand(unit, UnitCommandTypes.REBASE, nil, {
        [UnitOperationTypes.PARAM_X] = Map.GetPlotByIndex(plotIndex):GetX(),
        [UnitOperationTypes.PARAM_Y] = Map.GetPlotByIndex(plotIndex):GetY()
    })
end

function UnitWMDStrike(unit, plotIndex, wmdType)
    if not unit or not plotIndex or not wmdType then return false end
    return UnitManager.CanStartCommand(unit, UnitCommandTypes.WMD_STRIKE, nil, {
        [UnitOperationTypes.PARAM_WMD_TYPE] = wmdType,
        [UnitOperationTypes.PARAM_X] = Map.GetPlotByIndex(plotIndex):GetX(),
        [UnitOperationTypes.PARAM_Y] = Map.GetPlotByIndex(plotIndex):GetY()
    })
end

function QueueUnitPath(unit, plotIndex)
    if not unit or not plotIndex then return false end
    local plot = Map.GetPlotByIndex(plotIndex)
    return UnitManager.CanStartOperation(unit, UnitOperationTypes.MOVE_TO, nil, {
        [UnitOperationTypes.PARAM_X] = plot:GetX(),
        [UnitOperationTypes.PARAM_Y] = plot:GetY()
    })
end

function RequestBuildImprovement(unit, improvementHash)
    if not unit or not improvementHash then return false end
    local plot = Map.GetPlot(unit:GetX(), unit:GetY())
    if not plot then return false end
    return UnitManager.CanStartOperation(unit, UnitOperationTypes.BUILD_IMPROVEMENT, nil, {
        [UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash
    })
end  -- Only one end needed for the function block

  -- Return the table of possible actions
  return possibleActions;

  -- End of GetPossibleActions()
end
