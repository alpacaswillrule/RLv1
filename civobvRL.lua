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
  if playerCulture:IsResearchComplete() then
    for civic in GameInfo.Civics() do
      if playerCulture:IsCivicUnlocked(civic.Hash) and not playerCulture:HasCivic(civic.Hash) then
		print("GetPossibleActions: Adding possible civic: " .. tostring(civic.CivicType))
        table.insert(possibleActions.ChooseCivic, civic.CivicType);
      end
    end
  end

  print("GetPossibleActions: Checking technologies...")
  -- TECHNOLOGIES
  if playerTechs:IsResearchComplete() then
    for tech in GameInfo.Technologies() do
      if playerTechs:CanResearch(tech.Hash) then
	    print("GetPossibleActions: Adding possible tech: " .. tostring(tech.TechnologyType))
        table.insert(possibleActions.ChooseTech, tech.TechnologyType);
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
    if district:IsEncampment() and CityManager.CanStartCommand(district, CityCommandTypes.RANGE_ATTACK) then
	  print("GetPossibleActions: Adding encampment ranged attack for district ID: " .. tostring(district:GetID()))
      table.insert(possibleActions.EncampmentRangedAttack, district:GetID());
    end
  end

  print("GetPossibleActions: Checking envoy actions...")
    -- SEND ENVOY
  local influence = player:GetInfluence();
  if influence:CanGiveInfluence() then
    for cityState in GameInfo.MinorCivs() do
      if influence:CanGiveTokensToPlayer(cityState.Index) then
	    print("GetPossibleActions: Adding send envoy action for city-state: " .. tostring(cityState.MinorCivType))
        table.insert(possibleActions.SendEnvoy, cityState.MinorCivType);
      end
    end
  end

  print("GetPossibleActions: Checking make peace actions...")
  -- MAKE PEACE WITH CITY-STATE
  for cityState in GameInfo.MinorCivs() do
    if player:GetDiplomacy():CanMakePeaceWith(cityState.Index) then
	  print("GetPossibleActions: Adding make peace action for city-state: " .. tostring(cityState.MinorCivType))
      table.insert(possibleActions.MakePeace, cityState.MinorCivType);
    end
  end

  print("GetPossibleActions: Checking levy military actions...")
  -- LEVY MILITARY
  for cityState in GameInfo.MinorCivs() do
    if player:GetInfluence():CanLevyMilitary(cityState.Index) then
	  print("GetPossibleActions: Adding levy military action for city-state: " .. tostring(cityState.MinorCivType))
      table.insert(possibleActions.LevyMilitary, cityState.MinorCivType);
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

    -- UNIT ACTIONS
  print("GetPossibleActions: Checking unit actions...")
  for unit in player:GetUnits():Members() do
      local unitID = unit:GetID()
      print("GetPossibleActions: Checking actions for unit ID: " .. tostring(unitID))
      -- Select Unit
      table.insert(possibleActions.SelectUnit, unitID)

    -- Movement (check for each valid plot around the unit)
    print("GetPossibleActions: Checking movement for unit ID: " .. tostring(unitID))
    if unit:IsReadyToMove() then
      local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY());
      local neighboringPlots = Map.GetPlotsWithinRange(unitPlot, unit:GetMovesRemaining(), true);
      for _, plot in ipairs(neighboringPlots) do
          if plot:GetZOC() == -1 or plot:GetZOC() == playerID then
		    print("GetPossibleActions: Adding move action for unit ID: " .. tostring(unitID) .. " to plot: " .. tostring(plot:GetX()) .. ", " .. tostring(plot:GetY()))
            table.insert(possibleActions.MoveUnit, {unitID, plot:GetX(), plot:GetY()});
          end
      end
    end

    -- Ranged Attack
    print("GetPossibleActions: Checking ranged attack for unit ID: " .. tostring(unitID))
    if unit:GetRangedCombat() > 0 then
      local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY());
      local attackablePlots = Map.GetPlotsWithinRange(unitPlot, unit:GetRange(), true);
      for _, plot in ipairs(attackablePlots) do
          if UnitRangeAttack(unit, plot:GetIndex()) then
		    print("GetPossibleActions: Adding ranged attack for unit ID: " .. tostring(unitID) .. " to plot: " .. tostring(plot:GetX()) .. ", " .. tostring(plot:GetY()))
            table.insert(possibleActions.UnitRangedAttack, {unitID, plot:GetX(), plot:GetY()});
          end
      end
    end

    -- Air Attack
    print("GetPossibleActions: Checking air attack for unit ID: " .. tostring(unitID))
    if unit:IsAir() then
        local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY());
        local attackablePlots = Map.GetPlotsWithinRange(unitPlot, unit:GetRange(), true);
        for _, plot in ipairs(attackablePlots) do
            if UnitAirAttack(unit, plot:GetIndex()) then
			  print("GetPossibleActions: Adding air attack for unit ID: " .. tostring(unitID) .. " to plot: " .. tostring(plot:GetX()) .. ", " .. tostring(plot:GetY()))
                table.insert(possibleActions.UnitAirAttack, {unitID, plot:GetX(), plot:GetY()});
            end
        end
    end

    -- Form Unit (Corps/Army)
    print("GetPossibleActions: Checking form unit for unit ID: " .. tostring(unitID))
    if unit:IsMilitary() then
      for otherUnit in player:GetUnits():Members() do
        if otherUnit:GetID() ~= unitID and otherUnit:IsMilitary() and otherUnit:GetDomain() == unit:GetDomain() and otherUnit:GetX() == unit:GetX() and otherUnit:GetY() == unit:GetY() then
		  print("GetPossibleActions: Adding form unit action for unit ID: " .. tostring(unitID) .. " with unit ID: " .. tostring(otherUnit:GetID()))
          table.insert(possibleActions.FormUnit, {unitID, otherUnit:GetID(), "CORPS"});
          table.insert(possibleActions.FormUnit, {unitID, otherUnit:GetID(), "ARMY"});
        end
      end
    end

    -- Rebase
    print("GetPossibleActions: Checking rebase for unit ID: " .. tostring(unitID))
    if unit:CanRebase() then
        local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY());
        local rebasePlots = Map.GetPlotsWithinRange(unitPlot, unit:GetRange(), false);
        for _, plot in ipairs(rebasePlots) do
            if UnitRebase(unit, plot:GetIndex()) then
			  print("GetPossibleActions: Adding rebase action for unit ID: " .. tostring(unitID) .. " to plot: " .. tostring(plot:GetX()) .. ", " .. tostring(plot:GetY()))
                table.insert(possibleActions.RebaseUnit, {unitID, plot:GetX(), plot:GetY()});
            end
        end
    end

    -- WMD Strike
    print("GetPossibleActions: Checking WMD strike for unit ID: " .. tostring(unitID))
    if unit:GetWMDStrikeRange() > 0 then
        local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY());
        local strikePlots = Map.GetPlotsWithinRange(unitPlot, unit:GetWMDStrikeRange(), true);
        for _, plot in ipairs(strikePlots) do
            for wmdType in GameInfo.UnitWmdTypes() do
                if UnitWMDStrike(unit, plot:GetIndex(), wmdType.Hash) then
				  print("GetPossibleActions: Adding WMD strike for unit ID: " .. tostring(unitID) .. " to plot: " .. tostring(plot:GetX()) .. ", " .. tostring(plot:GetY()) .. " with WMD type: " .. tostring(wmdType.Hash))
                    table.insert(possibleActions.WMDStrike, {unitID, plot:GetX(), plot:GetY(), wmdType.Hash});
                end
            end
        end
    end

    -- Queue Unit Path
    print("GetPossibleActions: Checking queue unit path for unit ID: " .. tostring(unitID))
    local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY());
    local pathPlots = Map.GetPlotsWithinRange(unitPlot, 5, true); -- Search within 5 tiles
    for _, plot in ipairs(pathPlots) do
        if QueueUnitPath(unit, plot:GetIndex()) then
		  print("GetPossibleActions: Adding queue unit path for unit ID: " .. tostring(unitID) .. " to plot: " .. tostring(plot:GetX()) .. ", " .. tostring(plot:GetY()))
            table.insert(possibleActions.QueueUnitPath, {unitID, plot:GetX(), plot:GetY()});
        end
    end

    -- Build Improvement
    print("GetPossibleActions: Checking build improvement for unit ID: " .. tostring(unitID))
    if unit:IsBuilder() then
      for improvement in GameInfo.Improvements() do
        if RequestBuildImprovement(unit, improvement.Hash) then
		  print("GetPossibleActions: Adding build improvement for unit ID: " .. tostring(unitID) .. " with improvement: " .. tostring(improvement.ImprovementType))
          table.insert(possibleActions.BuildImprovement, {unitID, improvement.ImprovementType});
        end
      end
    end

    -- Enter Formation
    print("GetPossibleActions: Checking enter formation for unit ID: " .. tostring(unitID))
    if unit:CanEnterFormation() then
      for otherUnit in player:GetUnits():Members() do
          if otherUnit:GetID() ~= unitID and otherUnit:CanBeEnteredBy(unit) and otherUnit:GetX() == unit:GetX() and otherUnit:GetY() == unit:GetY() then
		    print("GetPossibleActions: Adding enter formation for unit ID: " .. tostring(unitID) .. " with unit ID: " .. tostring(otherUnit:GetID()))
            table.insert(possibleActions.EnterFormation, {unitID, otherUnit:GetID()});
          end
      end
    end

    -- Found City
    print("GetPossibleActions: Checking found city for unit ID: " .. tostring(unitID))
    if unit:CanFoundCity(unit:GetX(), unit:GetY()) then
	  print("GetPossibleActions: Adding found city for unit ID: " .. tostring(unitID))
      table.insert(possibleActions.FoundCity, unitID);
    end

    -- Promote Unit
    print("GetPossibleActions: Checking promote unit for unit ID: " .. tostring(unitID))
    local promotions = GetAvailablePromotions(unit);
    if promotions then
      for _, promotion in ipairs(promotions) do
	    print("GetPossibleActions: Adding promote unit for unit ID: " .. tostring(unitID) .. " with promotion: " .. tostring(promotion.PromotionType))
        table.insert(possibleActions.PromoteUnit, {unitID, promotion.PromotionType});
      end
    end

    -- Delete Unit
    print("GetPossibleActions: Checking delete unit for unit ID: " .. tostring(unitID))
    if UnitManager.CanStartCommand(unit, UnitCommandTypes.DELETE, true) then
	  print("GetPossibleActions: Adding delete unit for unit ID: " .. tostring(unitID))
      table.insert(possibleActions.DeleteUnit, unitID);
    end

    -- Upgrade Unit
    print("GetPossibleActions: Checking upgrade unit for unit ID: " .. tostring(unitID))
    if UnitManager.CanStartCommand(unit, UnitCommandTypes.UPGRADE, true) then
	  print("GetPossibleActions: Adding upgrade unit for unit ID: " .. tostring(unitID))
      table.insert(possibleActions.UpgradeUnit, unitID);
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

--to indicate successful load
return True