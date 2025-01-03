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

function DoPrint()
	print("DOPRINT JOHAN");
end

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
function GetPossibleActions()
  print("GetPossibleActions: Determining possible actions for player...")
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local playerCulture = player:GetCulture();
  local playerTechs = player:GetTechs();

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
    EstablishTradeRoute = {}
  };
  
  print("GetPossibleActions: Checking civics...")
  -- CIVICS
  -- Check if no civic is currently being researched
  if not playerCulture:GetProgressingCivic() then
    for civic in GameInfo.Civics() do
      -- Check if the civic can be researched
      if playerCulture:CanProgress(civic.Hash) and not playerCulture:HasCivic(civic.Hash) then
        print("GetPossibleActions: Adding possible civic: " .. tostring(civic.CivicType))
        table.insert(possibleActions.ChooseCivic, civic.CivicType)
      end
    end
  end

  print("GetPossibleActions: Checking technologies...")
  -- TECHNOLOGIES
  -- Check if no technology is currently being researched
  if not playerTechs:GetResearchingTech() then
    for tech in GameInfo.Technologies() do
      if playerTechs:CanResearch(tech.Hash) and not playerTechs:HasTech(tech.Hash) then
        print("GetPossibleActions: Adding possible tech: " .. tostring(tech.TechnologyType))
        table.insert(possibleActions.ChooseTech, tech.TechnologyType)
      end
    end
  end

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

  -- Iterate through all units
  for unit in player:GetUnits():Members() do
      -- unit is already the ID
      local unitID = unit
      print("GetPossibleActions: Processing unit ID: " .. tostring(unitID))
      local possibleActions = GetPossibleUnitActions(unitID, player)
      if possibleActions then
          -- Merge actions into the main actions table
          for actionType, actions in pairs(possibleActions) do
              if unitActions[actionType] then
                  for _, action in ipairs(actions) do
                      table.insert(unitActions[actionType], action)
                  end
              end
          end
      end
  end

  return unitActions
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
if CanChangePolicies() then
    local currentPolicies = {}
    for slotIndex = 0, playerCulture:GetNumGovernmentSlots() - 1 do
        local policyIndex = playerCulture:GetGovernmentPolicyInSlot(slotIndex)
        if policyIndex then
            local policy = GameInfo.Policies[policyIndex]
            currentPolicies[slotIndex] = policy.PolicyType
        end
    end
    for policy in GameInfo.Policies() do
        local policyHash = policy.Hash
        if playerCulture:IsPolicyUnlocked(policyHash) then
            -- For each policy slot, check if we can add this policy
            for slotIndex = 0, playerCulture:GetNumGovernmentSlots() - 1 do
                -- Check if the policy can be placed in this slot
                if playerCulture:CanSlotPolicy(policyHash, slotIndex) then
                    print("GetPossibleActions: Adding change policy action for slot " .. tostring(slotIndex) .. " with policy: " .. tostring(policy.PolicyType))
                    table.insert(possibleActions.ChangePolicies, {slotIndex, policy.PolicyType})
                end
            end
        end
    end
end

  print("GetPossibleActions: Action collection complete.")
  return possibleActions;
end -- Close GetPossibleActions function

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
end

--to indicate successful load
return True
