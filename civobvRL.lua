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
include("DiplomacyStatementSupport")
include("CitySupport")
include("TradeSupport")
--------------------------------------------------
-- OBSERVATION FUNCTIONS
--------------------------------------------------

function GetPossibleEnvoyTargets()
    local possibleTargets = {}
    
    -- Get local player
    local localPlayerID = Game.GetLocalPlayer()
    local localPlayer = Players[localPlayerID]
    
    -- Get influence info and check if we have envoys to give
    local playerInfluence = localPlayer:GetInfluence()
    if not playerInfluence or not playerInfluence:CanGiveInfluence() then
      return possibleTargets
    end
    
    local envoyTokens = playerInfluence:GetTokensToGive()
    if envoyTokens <= 0 then
      return possibleTargets
    end
  
    -- Check each minor civ/city state
    for _, pPlayer in ipairs(PlayerManager.GetAliveMinors()) do
      local cityStateID = pPlayer:GetID()
      
      -- Check if we can give envoys to this city state
      if playerInfluence:CanGiveTokensToPlayer(cityStateID) then
        table.insert(possibleTargets, {
          PlayerID = cityStateID,
          Name = PlayerConfigurations[cityStateID]:GetCivilizationShortDescription()
        })
      end
    end
  
    return possibleTargets
  end

-- Helper function to get diplomatic status with other players
function GetDiplomaticStatuses(player)
    local diplomaticStatuses = {}
    local playerDiplomacy = player:GetDiplomacy()
    local localPlayerID = player:GetID()

    -- Get all players
    for _, otherPlayer in ipairs(PlayerManager.GetAliveMajors()) do
        local otherPlayerID = otherPlayer:GetID()
        
        -- Skip if it's ourselves
        if otherPlayerID ~= localPlayerID then
            local pPlayerConfig = PlayerConfigurations[otherPlayerID]
            local hasMet = playerDiplomacy:HasMet(otherPlayerID)
            
            -- Get diplomatic state if we've met
            local diplomaticState = nil
            if hasMet then
                local stateID = player:GetDiplomaticAI():GetDiplomaticStateIndex(otherPlayerID)
                if stateID ~= -1 then
                    local stateEntry = GameInfo.DiplomaticStates[stateID]
                    diplomaticState = stateEntry.StateType
                end
            end

            -- Get player mood using function from DiplomacySupport
            local mood = DiplomacySupport_GetPlayerMood(otherPlayer, localPlayerID)

            -- Structure the diplomatic information
            diplomaticStatuses[otherPlayerID] = {
                PlayerName = pPlayerConfig:GetPlayerName(),
                LeaderType = pPlayerConfig:GetLeaderTypeName(),
                CivType = pPlayerConfig:GetCivilizationTypeName(),
                HasMet = hasMet,
                DiplomaticState = diplomaticState,
                Mood = mood,
                Team = pPlayerConfig:GetTeam(),
                Score = otherPlayer:GetDiplomaticAI():GetDiplomaticScore(localPlayerID),
                IsHuman = pPlayerConfig:IsHuman()
            }
        end
    end

    return diplomaticStatuses
end

-- Gets the current turn number.
function GetTurnNumber()
  --print("GetTurnNumber: Getting current turn number...")
  local turn = Game.GetCurrentGameTurn()
  --print("GetTurnNumber: Current turn number is: " .. tostring(turn))
  return turn;
end

-- Gets the current player's ID.
function GetPlayerID()
  --print("GetPlayerID: Getting local player ID...")
  local playerID = Game.GetLocalPlayer();
  --print("GetPlayerID: Local player ID is: " .. tostring(playerID))
  return playerID;
end

-- Gets information about the local player. AKA THE GAMETSTATE THIS RETURNS THE GAMESTATE
function GetPlayerData(playerID)
  print("GetPlayerData: Getting data for player: " .. tostring(playerID))

  local player = Players[playerID];
  if not player then 
    --print("GetPlayerData: Player not found.")
    return nil 
  end

  local data = {
    Gold = player:GetTreasury():GetGoldBalance(),
    Faith = player:GetReligion():GetFaithBalance(),
    FaithPerTurn = player:GetReligion():GetFaithYield(),
    IsInAnarchy = player:GetCulture():IsInAnarchy(),
    SciencePerTurn = player:GetTechs():GetScienceYield(),
    CulturePerTurn = player:GetCulture():GetCultureYield(),
    GoldPerTurn = player:GetTreasury():GetGoldYield(),
    maintenance = player:GetTreasury():GetTotalMaintenance(),
    DiplomaticStatuses = GetDiplomaticStatuses(player), -- Check if at war with any major civ
    CityStates = GetCityStatesInfo(playerID),
    VisibleTiles = GetVisibleTileData(playerID),
    Cities = {}, -- Add city data using GetCityData()
    Units = {},  -- Add unit data using GetUnitData()
    TechsResearched = {},
    CivicsResearched = {},
    CurrentGovernment = nil,
    CurrentPolicies = {},
    GreatPeoplePoints = {},
    GreatPeoplePointsPerTurn = {},
    TradeRoutes = {
        Active = 0,    -- Number of active trade routes
        Capacity = 0,  -- Maximum number of trade routes possible
        IdleTraders = 0  -- Number of idle trade units available
    }
  };
  print("GetPlayerData: Gathering trade route data...")
  
  local playerTrade = player:GetTrade();
  if playerTrade then
      data.TradeRoutes.Active = playerTrade:GetNumOutgoingRoutes();
      data.TradeRoutes.Capacity = playerTrade:GetOutgoingRouteCapacity();
      
      -- Count idle trade units
      local idleTraders = 0;
      for i, unit in player:GetUnits():Members() do
          local unitInfo = GameInfo.Units[unit:GetUnitType()];
          if unitInfo.MakeTradeRoute then
              -- Check if unit has active route
              local hasRoute = false;
              for _, city in player:GetCities():Members() do
                  local routes = city:GetTrade():GetOutgoingRoutes();
                  for _, route in ipairs(routes) do
                      if route.TraderUnitID == unit:GetID() then
                          hasRoute = true;
                          break;
                      end
                  end
                  if hasRoute then break end
              end
              if not hasRoute then
                  idleTraders = idleTraders + 1;
              end
          end
      end
      data.TradeRoutes.IdleTraders = idleTraders;
  end

  print("GetPlayerData: Gathering city data...")
  -- Add city data
  for i, city in player:GetCities():Members() do
      local cityData = GetCityData(city);
      if cityData then
        table.insert(data.Cities, cityData);
      end
  end

  print("GetPlayerData: Gathering unit data...")
  -- Add unit data
  for _, unit in player:GetUnits():Members() do
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
  local currentPolicies = GetCurrentPolicies(playerID, player)
  for slotIndex, policyData in pairs(currentPolicies) do
    --print(string.format("Slot %d: %s", slotIndex, policyData.PolicyType))
    data.CurrentPolicies[slotIndex] = {
        SlotIndex = slotIndex,
        PolicyType = policyData.PolicyType,
        PolicyHash = policyData.Hash,
        PolicyData = policyData
    }
  end

  -- Get Great People points
  print("GetPlayerData: Getting Great People points...")
  for class in GameInfo.GreatPersonClasses() do
    local classID = class.Index
    data.GreatPeoplePoints[class.GreatPersonClassType] = player:GetGreatPeoplePoints():GetPointsTotal(classID)
    data.GreatPeoplePointsPerTurn[class.GreatPersonClassType] = player:GetGreatPeoplePoints():GetPointsPerTurn(classID)
  end

  print("GetPlayerData: Player data collection complete.")
  return data;
end

function GetUnitData(unit)
    if unit == nil then return nil end
  
    local data = {
      Name = unit:GetName(),
      Combat = unit:GetCombat(),
      RangedCombat = unit:GetRangedCombat(),
      BombardCombat = unit:GetBombardCombat(),
      AntiAirCombat = unit:GetAntiAirCombat(),
      Range = unit:GetRange(),
      Damage = unit:GetDamage(),
      MaxDamage = unit:GetMaxDamage(),
      Moves = unit:GetMovesRemaining(),
      MaxMoves = unit:GetMaxMoves(),
      UnitType = unit:GetUnitType(),
      Formation = unit:GetMilitaryFormation(),
      ActionCharges = unit:GetActionCharges(),
      Buildcharges = unit:GetBuildCharges(),
      Experience = unit:GetExperience():GetExperiencePoints(),
      Level = unit:GetExperience():GetLevel(),
      Position = {
        X = unit:GetX(),
        Y = unit:GetY()
      }
    };
    return data;
  end


  function GetCurrentPolicies(playerID,Player)
    local pPlayer = Player
    local playerCulture = pPlayer:GetCulture()
    local currentPolicies = {}
  
    -- Get number of policy slots
    local numSlots = playerCulture:GetNumPolicySlots()
    
    -- For each slot
    for slotIndex = 0, numSlots-1 do
      local policyHash = playerCulture:GetSlotPolicy(slotIndex)
      if policyHash ~= -1 then -- -1 indicates empty slot
        -- Get policy info from hash
        local policy = GameInfo.Policies[policyHash]
        if policy then
          currentPolicies[slotIndex] = {
            SlotIndex = slotIndex,
            PolicyType = policy.PolicyType, 
            PolicyHash = policyHash,
            SlotType = playerCulture:GetSlotType(slotIndex)
          }
        end
      end
    end
  
    return currentPolicies
  end

function GetSuzerainBonusText( playerID:number )
	
	local leader	:string = PlayerConfigurations[playerID]:GetLeaderTypeName();
	local leaderInfo:table	= GameInfo.Leaders[leader];
	if leaderInfo == nil then
		UI.DataError("GetSuzerainBonusText, cannot determine the type of city state suzerain bonus for player #: "..tostring(playerID) );
		return "UNKNOWN";
	end

	local text		:string = "";
	
	-- Unique Bonus
	for leaderTraitPairInfo in GameInfo.LeaderTraits() do
		if (leader ~= nil and leader == leaderTraitPairInfo.LeaderType) then
			local traitInfo : table = GameInfo.Traits[leaderTraitPairInfo.TraitType];
			if (traitInfo ~= nil) then
				local name = PlayerConfigurations[playerID]:GetCivilizationShortDescription();
				text = text .. "[COLOR:SuzerainDark]" .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_UNIQUE_BONUS", name) .. "[ENDCOLOR] ";
				if traitInfo.Description ~= nil then
					text = text .. Locale.Lookup(traitInfo.Description);
				end
			end
		end
	end	

	-- Diplomatic Bonus
	text = text .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_DIPLOMATIC_BONUS");
	
	local comma_separator = Locale.Lookup("LOC_GRAMMAR_COMMA_SEPARATOR");

	-- Resources Available
	local resourceIcons	:string = "";
	local player = Players[playerID];
	if (player ~= nil) then
		for resourceInfo in GameInfo.Resources() do
			local resource = resourceInfo.Index;
			-- Include exports, so we see what another player is getting if suzerain
			if (player:GetResources():HasResource(resource) or player:GetResources():HasExportedResource(resource)) then
				local amount = player:GetResources():GetResourceAmount(resource) + player:GetResources():GetExportedResourceAmount(resource);
				if (resourceIcons ~= "") then
					resourceIcons = resourceIcons .. comma_separator;
				end
				resourceIcons = resourceIcons .. amount .. " [ICON_" .. resourceInfo.ResourceType .. "] " .. Locale.Lookup(resourceInfo.Name);
			end
		end
	end
	if (resourceIcons ~= "") then
		text = text .. " " .. resourceIcons;
	else
		text = text .. " " .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_NO_RESOURCES_AVAILABLE");
	end

	return text;
end

function GetQuests( playerID:number )
	local kQuests		:table  = {};
	local questsManager	:table = Game.GetQuestsManager();
	local localPlayerID :number = Game.GetLocalPlayer();
	if questsManager ~= nil then
		for questInfo in GameInfo.Quests() do
			if questsManager:HasActiveQuestFromPlayer( localPlayerID, playerID, questInfo.Index) then
				kQuests[questInfo.Index] = { 
					Description = questsManager:GetActiveQuestDescription( localPlayerID, playerID, questInfo.Index),
					Name		= questsManager:GetActiveQuestName( localPlayerID, playerID, questInfo.Index),
					Reward		= questsManager:GetActiveQuestReward( localPlayerID, playerID, questInfo.Index),
					Type		= questInfo.QuestType,
					Callout		= questInfo.IconString
				};
			end
		end
	else
		UI.DataError("City-States were unable to obtain the QuestManager.");
	end
	return kQuests;
end

-- New function to get city state information
-- Returns a table of information about all City States the player has met
-- Returns a table of information about all City States the player has met
function GetCityStatesInfo(playerID:number)
    local localPlayer = Players[playerID];
    if localPlayer == nil then return {}; end
    
    local cityStatesInfo = {};
    local localDiplomacy = localPlayer:GetDiplomacy();
    local localInfluence = localPlayer:GetInfluence();
    
    -- Constants for envoy thresholds
    local FIRST_BONUS = 1;
    local SECOND_BONUS = 3;
    local THIRD_BONUS = 6;

    -- Loop through all minor civs
    for _, pPlayer in ipairs(PlayerManager.GetAliveMinors()) do
        local cityStateID = pPlayer:GetID();
        
        -- Only include city states we've met
        if pPlayer:IsMinor() and localDiplomacy:HasMet(cityStateID) then
            local pPlayerConfig = PlayerConfigurations[cityStateID];
            local pInfluence = pPlayer:GetInfluence();
            local envoyTokens = pInfluence:GetTokensReceived(playerID);
            local suzerainID = pInfluence:GetSuzerain();
            local cityStateType = GetCityStateType(cityStateID);

            -- Get suzerain name
            local suzerainName = "None";
            if suzerainID ~= -1 then
                if suzerainID == playerID then
                    suzerainName = "You";
                elseif localDiplomacy:HasMet(suzerainID) then
                    suzerainName = Locale.Lookup(PlayerConfigurations[suzerainID]:GetPlayerName());
                else
                    suzerainName = "Unknown";
                end
            end

            -- Create kCityState table to get Suzerain bonus
            local kCityState = {
                Bonuses = {}
            };
            kCityState.Bonuses["Suzerain"] = { Details = GetSuzerainBonusText(cityStateID) };

            local cityState = {
                ID = cityStateID,
                Name = Locale.Lookup(pPlayerConfig:GetCivilizationShortDescription()),
                Type = cityStateType,
                Envoys = envoyTokens,
                SuzerainID = suzerainID,
                SuzerainName = suzerainName,
                IsAlive = pPlayer:IsAlive(),
                IsAtWar = localDiplomacy:IsAtWarWith(cityStateID),
                CanReceiveTokens = localInfluence:CanGiveTokensToPlayer(cityStateID),
                CanLevyMilitary = localInfluence:CanLevyMilitary(cityStateID),
                LevyMilitaryCost = localInfluence:GetLevyMilitaryCost(cityStateID),
                HasLevyActive = (pPlayer:GetInfluence():GetLevyTurnCounter() >= 0),
                HasFirstBonus = (envoyTokens >= FIRST_BONUS),
                HasSecondBonus = (envoyTokens >= SECOND_BONUS),
                HasThirdBonus = (envoyTokens >= THIRD_BONUS),
                HasSuzerainBonus = (suzerainID == playerID),
                SuzerainBonusDetails = kCityState.Bonuses["Suzerain"].Details,
                Quests = GetQuests(cityStateID)
            };
            
            table.insert(cityStatesInfo, cityState);
        end
    end

    return cityStatesInfo;
end
  
  -- Helper function to get city state type
  function GetCityStateType(cityStateID)
    local leader = PlayerConfigurations[cityStateID]:GetLeaderTypeName()
    local leaderInfo = GameInfo.Leaders[leader]
    
    if leaderInfo.InheritFrom == "LEADER_MINOR_CIV_SCIENTIFIC" then
      return "SCIENTIFIC"
    elseif leaderInfo.InheritFrom == "LEADER_MINOR_CIV_RELIGIOUS" then
      return "RELIGIOUS" 
    elseif leaderInfo.InheritFrom == "LEADER_MINOR_CIV_TRADE" then
      return "TRADE"
    elseif leaderInfo.InheritFrom == "LEADER_MINOR_CIV_CULTURAL" then
      return "CULTURAL"
    elseif leaderInfo.InheritFrom == "LEADER_MINOR_CIV_MILITARISTIC" then
      return "MILITARISTIC"
    elseif leaderInfo.InheritFrom == "LEADER_MINOR_CIV_INDUSTRIAL" then
      return "INDUSTRIAL"
    end
    return "UNKNOWN"
  end
  
  -- Helper function to get city state quests
  function GetCityStateQuests(playerID, cityStateID)
    local quests = {}
    local questsManager = Game.GetQuestsManager()
    
    -- Loop through all quest types
    for questInfo in GameInfo.Quests() do
      if questsManager:HasActiveQuestFromPlayer(playerID, cityStateID, questInfo.Index) then
        local quest = {
          Type = questInfo.QuestType,
          Name = questsManager:GetActiveQuestName(playerID, cityStateID, questInfo.Index),
          Description = questsManager:GetActiveQuestDescription(playerID, cityStateID, questInfo.Index),
          Reward = questsManager:GetActiveQuestReward(playerID, cityStateID, questInfo.Index)
        }
        table.insert(quests, quest)
      end
    end
    
    return quests
  end
  


-- New function to get visible tile data
function GetVisibleTileData(playerID)
    --print("GetVisibleTileData: Getting visible tiles for player: " .. tostring(playerID))
    
    local visibleTiles = {}
    local player = Players[playerID]
    local playerVisibility = PlayersVisibility[playerID]
    
    -- Loop through all plots on map
    local mapWidth, mapHeight = Map.GetGridSize()
    for i = 0, (mapWidth * mapHeight) - 1, 1 do
      local plot = Map.GetPlotByIndex(i)
      
      -- Check if plot is visible or revealed
      if playerVisibility:IsRevealed(plot:GetX(), plot:GetY()) then
        -- Get yields
        local yields = {
          Food = plot:GetYield(YieldTypes.FOOD),
          Production = plot:GetYield(YieldTypes.PRODUCTION),
          Gold = plot:GetYield(YieldTypes.GOLD),
          Science = plot:GetYield(YieldTypes.SCIENCE),
          Culture = plot:GetYield(YieldTypes.CULTURE),
          Faith = plot:GetYield(YieldTypes.FAITH)
        }
  
        local tileData = {
          X = plot:GetX(),
          Y = plot:GetY(),
          TerrainType = GameInfo.Terrains[plot:GetTerrainType()].TerrainType,
          FeatureType = plot:GetFeatureType() >= 0 and GameInfo.Features[plot:GetFeatureType()].FeatureType or nil,
          ResourceType = plot:GetResourceType() >= 0 and GameInfo.Resources[plot:GetResourceType()].ResourceType or nil,
          ImprovementType = plot:GetImprovementType() >= 0 and GameInfo.Improvements[plot:GetImprovementType()].ImprovementType or nil,
          DistrictType = plot:GetDistrictType() >= 0 and GameInfo.Districts[plot:GetDistrictType()].DistrictType or nil,
          IsVisible = playerVisibility:IsVisible(plot:GetX(), plot:GetY()),
          IsRevealed = true,
          OwnerID = plot:GetOwner(),
          Appeal = plot:GetAppeal(),
          IsWater = plot:IsWater(),
          IsImpassable = plot:IsImpassable(),
          MovementCost = plot:GetMovementCost(),
          -- Add yields
          Yields = yields,
          -- Additional useful yield-related info
          IsCity = plot:IsCity(),
          IsPillaged = plot:IsImprovementPillaged(),
          HasRemovableFeature = plot:GetFeatureType() >= 0 and GameInfo.Features[plot:GetFeatureType()].Removable,
          IsWorked = false -- Will be set below
        }
  
        -- Check if tile is being worked by a city
        if plot:GetWorkerCount() > 0 then
          tileData.IsWorked = true
          -- Get the city working this tile if owned
          if plot:GetOwner() == playerID then
            local city = Cities.GetPlotWorkingCity(plot:GetIndex())
            if city then
              tileData.WorkingCityID = city:GetID()
            end
          end
        end
  
        -- If it's a district, get additional district info
        if tileData.DistrictType then
          local district = CityManager.GetDistrictAt(plot)
          if district then
            tileData.DistrictInfo = {
              IsPillaged = district:IsPillaged(),
              IsComplete = district:IsComplete(),
              -- Add any district-specific yields
              DistrictYields = {
                Food = district:GetYield(YieldTypes.FOOD),
                Production = district:GetYield(YieldTypes.PRODUCTION),
                Gold = district:GetYield(YieldTypes.GOLD),
                Science = district:GetYield(YieldTypes.SCIENCE),
                Culture = district:GetYield(YieldTypes.CULTURE),
                Faith = district:GetYield(YieldTypes.FAITH)
              }
            }
          end
        end
  
        table.insert(visibleTiles, tileData)
      end
    end
    
    --print("GetVisibleTileData: Found " .. #visibleTiles .. " visible/revealed tiles")
    return visibleTiles
  end


  function PrintPlayerSummary(data)
    if not data then
        print("No player data available")
        return
    end

    -- Print basic yields
    print("\n=== YIELDS ===")
    print(string.format("Gold: %d (%.1f per turn)", data.Gold, data.GoldPerTurn))
    print(string.format("Faith: %d (%.1f per turn)", data.Faith, data.FaithPerTurn))
    print(string.format("Science: %.1f per turn", data.SciencePerTurn))
    print(string.format("Culture: %.1f per turn", data.CulturePerTurn))

    -- Print diplomatic statuses
    if data.DiplomaticStatuses then
        print("\n=== DIPLOMATIC STATUSES ===")
        for civID, status in pairs(data.DiplomaticStatuses) do
            print(string.format("With Civ %d: %s", civID, status))
        end
    end

    -- Print city state relationships
    if data.CityStates then
        print("\n=== CITY STATE RELATIONSHIPS ===")
        for _, cityState in pairs(data.CityStates) do
            if cityState.Type and cityState.Relationship then
                print(string.format("%s: %s", cityState.Type, cityState.Relationship))
            end
        end
    end

    -- Print Great People points
    print("\n=== GREAT PEOPLE POINTS ===")
    for class, points in pairs(data.GreatPeoplePoints) do
        local pointsPerTurn = data.GreatPeoplePointsPerTurn[class] or 0
        print(string.format("%s: %d (%.1f per turn)", class, points, pointsPerTurn))
    end

    -- Print some key technologies researched (up to 5)
    if #data.TechsResearched > 0 then
        print("\n=== RECENT TECHNOLOGIES ===")
        local count = 0
        for i = #data.TechsResearched, math.max(1, #data.TechsResearched - 4), -1 do
            print(data.TechsResearched[i])
            count = count + 1
            if count >= 5 then break end
        end
    end

    -- Print government and policy info if available
    if data.CurrentGovernment then
        print("\n=== GOVERNMENT ===")
        print("Current Government:", data.CurrentGovernment)
        print("Active Policies:", #data.CurrentPolicies)
    end
end



--EVERYTHING BELOW THIS MARKER IS FOR FINDING ACTIONS, ALL POSSIBLE ACTIONS

function GetReligionFoundingOptions(player)
    -- First check if player has already founded a religion
    local playerReligion = player:GetReligion()
    local foundedReligionType = playerReligion:GetReligionTypeCreated()
    
    -- If player has already founded a religion (foundedReligionType >= 0), return nil
    if foundedReligionType >= 0 then
        return nil
    end

    local options = nil
    
    -- Look for Great Prophet at Holy Site
    for i, unit in player:GetUnits():Members() do
        local unitType = GameInfo.Units[unit:GetUnitType()]
        if unitType.UnitType == "UNIT_GREAT_PROPHET" then
            local plot = Map.GetPlot(unit:GetX(), unit:GetY())
            local district = CityManager.GetDistrictAt(plot)
            
            if district and GameInfo.Districts[district:GetType()].DistrictType == "DISTRICT_HOLY_SITE" then
                -- Found valid prophet - gather religion/belief options
                options = {
                    UnitID = unit:GetID(),
                    AvailableReligions = {},
                    RequiredBeliefs = {},
                    OptionalBeliefs = {}
                }
                
                -- Get available religions
                for religion in GameInfo.Religions() do
                    if not religion.Pantheon and not Game.GetReligion():HasBeenFounded(religion.Index) then
                        table.insert(options.AvailableReligions, {
                            Type = religion.ReligionType,
                            Name = Locale.Lookup(religion.Name),
                            Hash = religion.Hash,
                            Color = religion.Color
                        })
                    end
                end

                -- Get available beliefs by type
                local pGameReligion = Game.GetReligion()
                for belief in GameInfo.Beliefs() do
                    -- Skip pantheon beliefs and already taken beliefs
                    if belief.BeliefClassType ~= "BELIEF_CLASS_PANTHEON" and
                       not pGameReligion:IsInSomePantheon(belief.Index) and  
                       not pGameReligion:IsInSomeReligion(belief.Index) and
                       not pGameReligion:IsTooManyForReligion(belief.Index, foundedReligionType) then -- Add this check
                        
                        local beliefData = {
                            Type = belief.BeliefType,
                            Name = Locale.Lookup(belief.Name),
                            Description = Locale.Lookup(belief.Description), 
                            Hash = belief.Hash
                        }
                        
                        -- Organize beliefs by required vs optional
                        if belief.BeliefClassType == "BELIEF_CLASS_FOUNDER" or
                           belief.BeliefClassType == "BELIEF_CLASS_FOLLOWER" then
                            options.RequiredBeliefs[belief.BeliefClassType] = options.RequiredBeliefs[belief.BeliefClassType] or {}
                            table.insert(options.RequiredBeliefs[belief.BeliefClassType], beliefData)
                        else
                            options.OptionalBeliefs[belief.BeliefClassType] = options.OptionalBeliefs[belief.BeliefClassType] or {}
                            table.insert(options.OptionalBeliefs[belief.BeliefClassType], beliefData)
                        end
                    end
                end
                
                break -- Found our prophet, no need to keep looking
            end
        end
    end

    return options
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
    --EndTurn = true, -- Always possible (unless blocked for some reason)
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
    --DeleteUnit = {},
    UpgradeUnit = {},
    ChangeGovernment = {},
    ChangePolicies = {},
    EstablishTradeRoute = {},
    CityProduction = {},
    PlaceDistrict = {},
    FoundPantheon = {},
    FoundReligion = {},
    SelectBeliefs = {},
    SpreadReligion = {},
    EvangelizeBelief = {},
    PurchaseWithGold = {},
    PurchaseWithFaith = {},
    ActivateGreatPerson = {},
    AssignGovernorTitle = {},
    AssignGovernorToCity = {}
  };  

-- Add this section where we check city production options:
--print("GetPossibleActions: Checking purchase options...")

local player = Players[Game.GetLocalPlayer()]
local playerTreasury = player:GetTreasury()
local playerReligion = player:GetReligion()

for _, city in player:GetCities():Members() do
    local cityID = city:GetID()
    --print("\nChecking purchase options for City ID: " .. tostring(cityID))
    
    -- Check unit purchases
    for row in GameInfo.Units() do
        if row and row.Hash then
            local tParameters = {}
            tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = row.Hash
            tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.STANDARD_MILITARY_FORMATION

            -- Check gold purchase
            tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index
            if CityManager.CanStartCommand(city, CityCommandTypes.PURCHASE, tParameters) then
                local goldCost = city:GetGold():GetPurchaseCost( "YIELD_GOLD", row.Hash )
                if playerTreasury:GetGoldBalance() >= goldCost then
                    table.insert(possibleActions.PurchaseWithGold, {
                        CityID = cityID,
                        PurchaseType = "UNIT",
                        TypeHash = row.Hash,
                        Cost = goldCost,
                        Name = row.UnitType
                    })
                end
            end

            -- Check faith purchase
            tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index
            if CityManager.CanStartCommand(city, CityCommandTypes.PURCHASE, tParameters) then
                local faithCost = city:GetGold():GetPurchaseCost( "YIELD_FAITH", row.Hash )
                if playerReligion:GetFaithBalance() >= faithCost then
                    table.insert(possibleActions.PurchaseWithFaith, {
                        CityID = cityID,
                        PurchaseType = "UNIT",
                        TypeHash = row.Hash,
                        Cost = faithCost,
                        Name = row.UnitType
                    })
                end
            end
        end
    end

    -- Check building purchases
    for row in GameInfo.Buildings() do
        if row and row.Hash then
            local tParameters = {}
            tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = row.Hash

            -- Check gold purchase
            tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index
            if CityManager.CanStartCommand(city, CityCommandTypes.PURCHASE, tParameters) then
                local goldCost = city:GetGold():GetPurchaseCost( "YIELD_GOLD", row.Hash )
                if playerTreasury:GetGoldBalance() >= goldCost then
                    table.insert(possibleActions.PurchaseWithGold, {
                        CityID = cityID,
                        PurchaseType = "BUILDING",
                        TypeHash = row.Hash,
                        Cost = goldCost,
                        Name = row.BuildingType
                    })
                end
            end

            -- Check faith purchase
            tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index
            if CityManager.CanStartCommand(city, CityCommandTypes.PURCHASE, tParameters) then
                local faithCost = city:GetGold():GetPurchaseCost( "YIELD_FAITH", row.Hash )
                if playerReligion:GetFaithBalance() >= faithCost then
                    table.insert(possibleActions.PurchaseWithFaith, {
                        CityID = cityID,
                        PurchaseType = "BUILDING",
                        TypeHash = row.Hash,
                        Cost = faithCost,
                        Name = row.BuildingType
                    })
                end
            end
        end
    end

-- Check district purchases
local pCityDistricts = city:GetDistricts()
local currentDistrictCount = pCityDistricts:GetNumZonedDistrictsRequiringPopulation()
local maxAllowedDistricts = pCityDistricts:GetNumAllowedDistrictsRequiringPopulation()

-- Only proceed if we haven't hit the district limit
if currentDistrictCount < maxAllowedDistricts then
    for row in GameInfo.Districts() do
        -- Skip districts that don't require population or aren't valid
        if row and row.Hash and row.RequiresPopulation then
            local tParameters = {}
            tParameters[CityCommandTypes.PARAM_DISTRICT_TYPE] = row.Hash

            -- Check gold purchase
            tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index
            if CityManager.CanStartCommand(city, CityCommandTypes.PURCHASE, tParameters) then
                local goldCost = city:GetGold():GetPurchaseCost("YIELD_GOLD", row.Hash)
                -- Get valid plots for this district
                local validPlots = GetValidDistrictPlots(city, row.Hash)
                if playerTreasury:GetGoldBalance() >= goldCost and #validPlots > 0 then
                    table.insert(possibleActions.PurchaseWithGold, {
                        CityID = cityID,
                        PurchaseType = "DISTRICT",
                        TypeHash = row.Hash,
                        Cost = goldCost,
                        Name = row.DistrictType,
                        ValidPlots = validPlots
                    })
                end
            end

            -- Check faith purchase
            tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index
            if CityManager.CanStartCommand(city, CityCommandTypes.PURCHASE, tParameters) then
                local faithCost = city:GetGold():GetPurchaseCost("YIELD_FAITH", row.Hash)
                -- Get valid plots for this district
                local validPlots = GetValidDistrictPlots(city, row.Hash)
                if playerReligion:GetFaithBalance() >= faithCost and #validPlots > 0 then
                    table.insert(possibleActions.PurchaseWithFaith, {
                        CityID = cityID,
                        PurchaseType = "DISTRICT",
                        TypeHash = row.Hash,
                        Cost = faithCost,
                        Name = row.DistrictType,
                        ValidPlots = validPlots
                    })
                end
            end
        end
    end
end
end
  --print("GetPossibleActions: Checking pantheon options...")
  local playerReligion = player:GetReligion()
  if playerReligion:CanCreatePantheon() then
      -- Get available pantheon beliefs
      --print("Can create pantheon, checking available beliefs...")
      local pGameReligion = Game.GetReligion()
      
      for row in GameInfo.Beliefs() do
          -- Check that it's a pantheon belief and not already taken
          if row.BeliefClassType == "BELIEF_CLASS_PANTHEON" and 
             not pGameReligion:IsInSomePantheon(row.Index) then
              
              -- Add as possible pantheon belief choice
              table.insert(possibleActions.FoundPantheon, {
                  BeliefType = row.BeliefType,
                  Hash = row.Hash,
                  Name = Locale.Lookup(row.Name),
                  Description = Locale.Lookup(row.Description)
              })
              --print("Added available pantheon belief: " .. row.BeliefType)
          end
      end
  end


----print("GetPossibleActions: Checking civics...")

local playerID = Game.GetLocalPlayer()
local player = Players[playerID]
local playerCulture = player:GetCulture()
local currentCivicID = playerCulture:GetProgressingCivic()

-- If no civic is being researched (currentCivicID is -1) or if we can switch civics
if currentCivicID == -1 then
    --print("No civic currently in progress, checking available civics...")
    for civic in GameInfo.Civics() do
        local civicIndex = civic.Index
        -- Debug --print civic info
        ----print("Checking civic: " .. civic.CivicType .. " Index: " .. tostring(civicIndex))
        
        -- Check if the civic can be researched
        if playerCulture:CanProgress(civicIndex) then
            --print("Can progress civic: " .. civic.CivicType)
            if not playerCulture:HasCivic(civicIndex) then
                --print("Don't have civic yet, adding as possible choice: " .. civic.CivicType)
                table.insert(possibleActions.ChooseCivic, {
                    CivicType = civic.CivicType,
                    Hash = civicIndex  -- Use Index instead of Hash for proper lookup
                })
                --print("Added civic: " .. civic.CivicType .. " with index: " .. tostring(civicIndex))
            end
        end
    end
    -- Debug --print total available civics
    --print("Total available civics: " .. #possibleActions.ChooseCivic)
end

----print("GetPossibleActions: Checking technologies...")

  -- TECHNOLOGIES
-- Check if no technology is currently being researched
-- In GetPossibleActions(), replace/modify the tech checking section:
-- TECHNOLOGIES 
local playerID = Game.GetLocalPlayer()
local player = Players[playerID]
local playerTechs = player:GetTechs()
local currentTechID = playerTechs:GetResearchingTech()

----print("GetPossibleActions: Checking available techs...")
----print("Current research tech ID: " .. tostring(currentTechID))

-- If no tech is being researched (currentTechID is -1) or if we can switch techs
if currentTechID == -1 then
    ----print("No tech currently being researched")
    -- Check each available tech
    for tech in GameInfo.Technologies() do
        local techIndex = tech.Index
        if playerTechs:CanResearch(techIndex) then
            ----print("GetPossibleActions: Adding possible tech: " .. tostring(tech.TechnologyType))
            table.insert(possibleActions.ChooseTech, {
                TechType = tech.TechnologyType,
                Hash = GameInfo.Technologies[tech.TechnologyType].Hash
            })
        end
    end
end
-- Inside GetPossibleActions()
----print("GetPossibleActions: Checking city production options...")

local player = Players[Game.GetLocalPlayer()];

--print("\n=== BEGINNING CITY PRODUCTION ANALYSIS ===")
-- Inside GetPossibleActions() where we process city productions
for _, city in player:GetCities():Members() do
    local cityID = city:GetID()
    --print("\nProcessing City ID: " .. tostring(cityID))
    local buildQueue = city:GetBuildQueue()
    
    -- Check Units
    --print("\nChecking Available Units:")
    for row in GameInfo.Units() do
        if row and row.Hash and buildQueue:CanProduce(row.Hash, false, true) then
            -- --print("- Can produce unit: " .. tostring(row.UnitType))
            -- --print("  Hash: " .. tostring(row.Hash))
            -- --print("  Cost: " .. tostring(buildQueue:GetUnitCost(row.Index)))
            
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
    --print("\nChecking Available Buildings:")
    for row in GameInfo.Buildings() do
        if row and row.Hash and buildQueue:CanProduce(row.Hash, true) then
            local cost = row.Index and buildQueue:GetBuildingCost(row.Index) or 0
            local turns = row.Index and buildQueue:GetTurnsLeft(row.BuildingType) or 0
            -- --print("- Can produce building: " .. tostring(row.BuildingType))
            -- --print("  Hash: " .. tostring(row.Hash))
            -- --print("  Cost: " .. tostring(buildQueue:GetBuildingCost(row.Index)))
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
    --print("\nChecking Available Projects:")
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
local pCityDistricts = city:GetDistricts()
local currentDistrictCount = pCityDistricts:GetNumZonedDistrictsRequiringPopulation()
local maxAllowedDistricts = pCityDistricts:GetNumAllowedDistrictsRequiringPopulation()

-- Only proceed if we haven't hit the district limit
if currentDistrictCount < maxAllowedDistricts then
    for row in GameInfo.Districts() do
        if row and row.Hash and buildQueue:CanProduce(row.Hash, true) then
            -- Skip districts that don't require population (like City Center)
            if row.RequiresPopulation then
                local validPlots = GetValidDistrictPlots(city, row.Hash)
                
                if #validPlots > 0 then
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
end
end
--print("\n=== END OF CITY PRODUCTION ANALYSIS ===")

  --print("GetPossibleActions: Checking city ranged attacks...")
    -- CITY RANGED ATTACK
  for _, city in player:GetCities():Members() do
    if CityManager.CanStartCommand(city, CityCommandTypes.RANGE_ATTACK) then
	  --print("GetPossibleActions: Adding city ranged attack for city ID: " .. tostring(city:GetID()))
      table.insert(possibleActions.CityRangedAttack, city:GetID());
    end
  end


  --print("GetPossibleActions: Checking encampment ranged attacks...")
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
                --print("GetPossibleActions: Adding encampment ranged attack for district ID: " .. tostring(district))
                table.insert(possibleActions.EncampmentRangedAttack, district)
            end
        end
    end
end

  --print("Finished checking districts")

  --print("GetPossibleActions: Checking envoy actions...")
-- Getting possible actions
    local envoyTargets = GetPossibleEnvoyTargets() 
    if envoyTargets and #envoyTargets > 0 then
    for _, target in ipairs(envoyTargets) do
        table.insert(possibleActions.SendEnvoy, target.PlayerID)
    end
    end

  --print("GetPossibleActions: Checking make peace actions...")
  -- MAKE PEACE WITH CITY-STATE
  for _, cityState in ipairs(PlayerManager.GetAlive()) do
      local cityStatePlayer = Players[cityState]
      -- Check if this is a city state
      if cityStatePlayer and cityStatePlayer:IsCityState() then
          if player:GetDiplomacy():CanMakePeaceWith(cityState) then
              --print("GetPossibleActions: Adding make peace action for city-state ID: " .. tostring(cityState))
              table.insert(possibleActions.MakePeace, cityState)
          end
      end
  end
  
  --print("GetPossibleActions: Checking levy military actions...")
  -- LEVY MILITARY
  for _, cityState in ipairs(PlayerManager.GetAlive()) do
      local cityStatePlayer = Players[cityState]
      -- Check if this is a city state
      if cityStatePlayer and cityStatePlayer:IsCityState() then
          if player:GetInfluence():CanLevyMilitary(cityState) then
              --print("GetPossibleActions: Adding levy military action for city-state ID: " .. tostring(cityState))
              table.insert(possibleActions.LevyMilitary, cityState)
          end
      end
  end

  --print("GetPossibleActions: Checking Great People actions...")
    -- GREAT PEOPLE
  local greatPeople = Game.GetGreatPeople();
  for individual in GameInfo.GreatPersonIndividuals() do
    if greatPeople:CanRecruitPerson(playerID, individual.Hash) then
	  --print("GetPossibleActions: Adding recruit Great Person action for: " .. tostring(individual.Name))
      table.insert(possibleActions.RecruitGreatPerson, individual.Name);
    end
    if greatPeople:CanRejectPerson(playerID, individual.Hash) then
	  --print("GetPossibleActions: Adding reject Great Person action for: " .. tostring(individual.Name))
      table.insert(possibleActions.RejectGreatPerson, individual.Name);
    end
    if greatPeople:CanPatronizePerson(playerID, individual.Hash, YieldTypes.GOLD) then
	  --print("GetPossibleActions: Adding patronize with Gold action for: " .. tostring(individual.Name))
      table.insert(possibleActions.PatronizeGreatPersonGold, individual.Name);
    end
    if greatPeople:CanPatronizePerson(playerID, individual.Hash, YieldTypes.FAITH) then
	  --print("GetPossibleActions: Adding patronize with Faith action for: " .. tostring(individual.Name))
      table.insert(possibleActions.PatronizeGreatPersonFaith, individual.Name);
    end
  end

  --print("GetPossibleActions: Checking great person activations...")
-- Check each unit for great person activation capabilities
for i, unit in player:GetUnits():Members() do
    local unitGreatPerson = unit:GetGreatPerson()
    if unitGreatPerson and unitGreatPerson:IsGreatPerson() and unitGreatPerson:GetActionCharges() > 0 then
        -- Get the individual info
        local greatPersonInfo = GameInfo.GreatPersonIndividuals[unitGreatPerson:GetIndividual()]
        
        if greatPersonInfo and greatPersonInfo.ActionEffectTileHighlighting then
            -- Get valid activation plots
            local activationPlots = unitGreatPerson:GetActivationHighlightPlots()
            
            -- Check if unit's current plot is in activation plots
            local unitPlotIndex = Map.GetPlot(unit:GetX(), unit:GetY()):GetIndex()
            local canActivateHere = false
            
            for _, plotIndex in ipairs(activationPlots) do
                if plotIndex == unitPlotIndex then
                    canActivateHere = true
                    break
                end
            end
            
            if canActivateHere then
                -- Unit is on valid plot, add as possible action
                table.insert(possibleActions.ActivateGreatPerson, {
                    UnitID = unit:GetID(),
                    IndividualID = unitGreatPerson:GetIndividual(),
                    IndividualType = greatPersonInfo.GreatPersonIndividualType,
                    ValidPlots = {unitPlotIndex}, -- Only include current plot
                    Name = Locale.Lookup(greatPersonInfo.Name)
                })
            end
        else
            -- For great people that don't require plot selection, 
            -- still check if they can activate where they are
            local pUnit = Players[player:GetID()]:GetUnits():FindID(unit:GetID())
            if pUnit and UnitManager.CanStartCommand(pUnit, UnitCommandTypes.ACTIVATE_GREAT_PERSON, true) then
                table.insert(possibleActions.ActivateGreatPerson, {
                    UnitID = unit:GetID(),
                    IndividualID = unitGreatPerson:GetIndividual(),
                    IndividualType = greatPersonInfo.GreatPersonIndividualType,
                    ValidPlots = nil,
                    Name = Locale.Lookup(greatPersonInfo.Name)
                })
            end
        end
    end
end

  --print("GetPossibleActions: Checking for Great Prophet and Religion actions...")
  -- In your GetPossibleActions() function:
    local foundingOptions = GetReligionFoundingOptions(player)
    if foundingOptions then
        -- Convert the options into discrete possible actions
        possibleActions.FoundReligion = {}
        
        -- Create one complete action for each possible religion/belief combination
        for _, religion in ipairs(foundingOptions.AvailableReligions) do
            -- For each valid combination of beliefs...
            if foundingOptions.RequiredBeliefs["BELIEF_CLASS_FOUNDER"] and 
               foundingOptions.RequiredBeliefs["BELIEF_CLASS_FOLLOWER"] then
                
                for _, founderBelief in ipairs(foundingOptions.RequiredBeliefs["BELIEF_CLASS_FOUNDER"]) do
                    for _, followerBelief in ipairs(foundingOptions.RequiredBeliefs["BELIEF_CLASS_FOLLOWER"]) do
                        local worshipBeliefs = foundingOptions.OptionalBeliefs["BELIEF_CLASS_WORSHIP"] or {{Hash = nil}}
                        
                        for _, worshipBelief in ipairs(worshipBeliefs) do
                            -- Create a complete action
                            table.insert(possibleActions.FoundReligion, {
                                UnitID = foundingOptions.UnitID,
                                ReligionHash = religion.Hash,
                                BeliefHashes = {
                                    founderBelief.Hash,
                                    followerBelief.Hash,
                                    worshipBelief.Hash
                                }
                            })
                        end
                    end
                end
            end
        end
    end


-- Add this section after the Great Prophet checks:
--print("GetPossibleActions: Checking for religious unit actions...")

-- Check each unit for religious spread capabilities
for i, unit in player:GetUnits():Members() do
    local unitType = GameInfo.Units[unit:GetUnitType()]
    
    -- Check for religious units
    if unitType.ReligiousStrength > 0 then
        -- Check for spread religion capability
        local validSpreadTargets = {}
        local range = unit:GetRange()
        
        for dx = -range, range do
            for dy = -range, range do
                local targetX = unit:GetX() + dx
                local targetY = unit:GetY() + dy
                
                if Map.IsPlot(targetX, targetY) then
                    local tParameters = {}
                    tParameters[UnitOperationTypes.PARAM_X] = targetX
                    tParameters[UnitOperationTypes.PARAM_Y] = targetY
                    
                    -- Check if we can spread religion to this location
                    local bCanStart, tResults = UnitManager.CanStartOperation(
                        unit, 
                        UnitOperationTypes.SPREAD_RELIGION,
                        nil,
                        tParameters,
                        true -- Get additional info
                    )
                    
                    if bCanStart then
                        local targetCity = Cities.GetCityInPlot(targetX, targetY)
                        if targetCity then
                            table.insert(validSpreadTargets, {
                                UnitID = unit:GetID(),
                                CityID = targetCity:GetID(),
                                OwnerID = targetCity:GetOwner(),
                                X = targetX,
                                Y = targetY
                            })
                        end
                    end
                end
            end
        end
        
        -- If we found valid spread targets, add them
        if #validSpreadTargets > 0 then
            table.insert(possibleActions.SpreadReligion, {
                UnitID = unit:GetID(),
                Targets = validSpreadTargets
            })
        end
        
        -- Check evangelize belief capability
        -- No need to check for specific unit type or ability - let CanStartOperation handle it
        local bCanEvangelize, tResults = UnitManager.CanStartOperation(
            unit,
            UnitOperationTypes.EVANGELIZE_BELIEF,
            nil,
            nil,
            true -- Get additional info
        )
        
        if bCanEvangelize then
            -- Get available beliefs
            local availableBeliefs = {}
            
            -- Get beliefs from operation results
            if tResults and tResults[UnitOperationResults.BELIEFS] then
                for _, belief in ipairs(tResults[UnitOperationResults.BELIEFS]) do
                    table.insert(availableBeliefs, {
                        BeliefType = belief.Type,
                        Hash = belief.Hash,
                        Name = Locale.Lookup(belief.Name),
                        Description = Locale.Lookup(belief.Description)
                    })
                end
            end
            
            if #availableBeliefs > 0 then
                table.insert(possibleActions.EvangelizeBelief, {
                    UnitID = unit:GetID(),
                    AvailableBeliefs = availableBeliefs
                })
            end
        end
    end
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
        UpgradeUnit = {},
        -- Add new action categories
        HarvestResource = {},
        Fortify = {},
        BuildImprovement = {},
        AirAttack = {},
        FormCorps = {},
        FormArmy = {},
        Wake = {},
        Repair = {},
        RemoveFeature = {},
    }
  
    print("=== BEGIN UNIT DISCOVERY ===")
    
    local pPlayerUnits:table = player:GetUnits();
    local militaryUnits:table = {};
    local civilianUnits:table = {};
    
    -- First sort units into categories (keeping original logic)
    for i, pUnit in pPlayerUnits:Members() do
        local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
        
        if pUnit:GetCombat() == 0 and pUnit:GetRangedCombat() == 0 then
            -- if we have no attack strength we must be civilian
            table.insert(civilianUnits, pUnit);
        else
            table.insert(militaryUnits, pUnit);
        end
    end
  
    -- Process military units (keeping original logic)
    for _, pUnit in ipairs(militaryUnits) do
        local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
        local unitID = pUnit:GetID()
        
        -- Check movement (original logic)
        local movesRemaining = pUnit:GetMovesRemaining()
        if movesRemaining > 0 then
            local moves = GetValidMoveLocations(pUnit)
            for _, move in ipairs(moves) do
                table.insert(unitActions.MoveUnit, {
                    UnitID = unitID,
                    X = move.x,
                    Y = move.y
                })
            end
        end
  
        -- Add base actions (original logic)
        table.insert(unitActions.SelectUnit, { UnitID = unitID })
        table.insert(unitActions.DeleteUnit, { UnitID = unitID })
  
        -- NEW CHECKS for military units
        -- Check for FORTIFY
        if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.FORTIFY, nil) then
            table.insert(unitActions.Fortify, {
                UnitID = unitID
            })
        end
  
        -- Check for AIR_ATTACK
        if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.AIR_ATTACK, nil) then
            local validTargets = {}
            local range = pUnit:GetRange()
            local unitX = pUnit:GetX()
            local unitY = pUnit:GetY()
            
            for dx = -range, range do
                for dy = -range, range do
                    local targetX = unitX + dx
                    local targetY = unitY + dy
                    if Map.IsPlot(targetX, targetY) then
                        local tParameters = {
                            [UnitOperationTypes.PARAM_X] = targetX,
                            [UnitOperationTypes.PARAM_Y] = targetY
                        }
                        if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.AIR_ATTACK, nil, tParameters) then
                            table.insert(validTargets, {X = targetX, Y = targetY})
                        end
                    end
                end
            end
            
            if #validTargets > 0 then
                table.insert(unitActions.AirAttack, {
                    UnitID = unitID,
                    ValidTargets = validTargets
                })
            end
        end
  
        -- Check for FORM_CORPS and FORM_ARMY
        if UnitManager.CanStartCommand(pUnit, UnitCommandTypes.FORM_CORPS) then
            table.insert(unitActions.FormCorps, {
                UnitID = unitID
            })
        end
  
        if UnitManager.CanStartCommand(pUnit, UnitCommandTypes.FORM_ARMY) then
            table.insert(unitActions.FormArmy, {
                UnitID = unitID
            })
        end
  
        -- Check for WAKE
        if UnitManager.CanStartCommand(pUnit, UnitCommandTypes.WAKE) then
            table.insert(unitActions.Wake, {
                UnitID = unitID
            })
        end
    end
  
    -- Process civilian units (keeping original logic)
    for _, pUnit in ipairs(civilianUnits) do
        local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
        local unitID = pUnit:GetID()
        
        -- Check if unit is a settler (original logic)
        if unitInfo.FoundCity then
            if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.FOUND_CITY, nil) then
                table.insert(unitActions.FoundCity, { UnitID = unitID })
            end
        end
  
        -- Check movement (original logic)
        local movesRemaining = pUnit:GetMovesRemaining()
        if movesRemaining > 0 then
            local moves = GetValidMoveLocations(pUnit)
            for _, move in ipairs(moves) do
                table.insert(unitActions.MoveUnit, {
                    UnitID = unitID,
                    X = move.x,
                    Y = move.y
                })
            end
        end
  
        -- Add base actions (original logic)
        table.insert(unitActions.SelectUnit, { UnitID = unitID })
  
        -- NEW CHECKS for civilian units
        -- Check for HARVEST_RESOURCE
        if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.HARVEST_RESOURCE, nil) then
            table.insert(unitActions.HarvestResource, {
                UnitID = unitID,
                PlotX = pUnit:GetX(),
                PlotY = pUnit:GetY()
            })
        end
  
    -- Check for BUILD_IMPROVEMENT
        local validImprovements = {}
        for improvement in GameInfo.Improvements() do
            local tParameters = {
                [UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvement.Hash,
                [UnitOperationTypes.PARAM_X] = pUnit:GetX(),
                [UnitOperationTypes.PARAM_Y] = pUnit:GetY()
            }
            if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.BUILD_IMPROVEMENT, nil, tParameters) then
                table.insert(validImprovements, improvement.Hash)
            end
        end
        
        if #validImprovements > 0 then
            table.insert(unitActions.BuildImprovement, {
                UnitID = unitID,
                ValidImprovements = validImprovements
            })
        end
        -- Check for REMOVE_FEATURE
        if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.REMOVE_FEATURE, nil) then
            local validFeatureRemovals = {};
            local plot = Map.GetPlot(pUnit:GetX(), pUnit:GetY());
            
            -- Check if the current plot has a removable feature
            if plot and plot:GetFeatureType() >= 0 then
                local featureInfo = GameInfo.Features[plot:GetFeatureType()];
                -- Check if feature can be removed
                if featureInfo and featureInfo.Removable then
                    local tParameters = {};
                    tParameters[UnitOperationTypes.PARAM_X] = pUnit:GetX();
                    tParameters[UnitOperationTypes.PARAM_Y] = pUnit:GetY();
                    
                    if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.REMOVE_FEATURE, nil, tParameters) then
                        table.insert(validFeatureRemovals, {
                            PlotX = pUnit:GetX(),
                            PlotY = pUnit:GetY(),
                            FeatureType = featureInfo.FeatureType,
                            FeatureHash = featureInfo.Hash
                        });
                    end
                end
            end
    
    if #validFeatureRemovals > 0 then
        table.insert(unitActions.RemoveFeature, {
            UnitID = pUnit:GetID(),
            ValidRemovals = validFeatureRemovals
        });
    end
end
  
        -- Check for REPAIR
        if UnitManager.CanStartOperation(pUnit, UnitOperationTypes.REPAIR, nil) then
            table.insert(unitActions.Repair, {
                UnitID = unitID,
                PlotX = pUnit:GetX(),
                PlotY = pUnit:GetY()
            })
        end
    end
  
    return unitActions
  end

-- Helper function to get valid move locations for a unit
function GetValidMoveLocations(unit)
  local validMoves = {}
  local range = math.floor(unit:GetMovesRemaining())
  local startX = unit:GetX()
  local startY = unit:GetY()
  
  --print(string.format("Checking moves from position %d,%d with range %d", startX, startY, range))
  
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
  
  --print("Found " .. #validMoves .. " valid move locations")
  return validMoves
end

--CHECKING ALL ACTIONS THAT ARE POSSIBLE
--print("GetPossibleActions: Checking unit actions...")
local unitActions = GetAllUnitActions(player)
for actionType, actions in pairs(unitActions) do
    if #actions > 0 then
        possibleActions[actionType] = actions
        -- --print("GetPossibleActions: Found " .. #actions .. " possible " .. actionType .. " actions")
    end
end

-- CHANGE GOVERNMENT
--print("GetPossibleActions: Checking change government...")
if CanChangeGovernment() then
  for government in GameInfo.Governments() do
    if government and government.Hash and playerCulture:IsGovernmentUnlocked(government.Hash) then
      -- Make sure the table exists before inserting
      table.insert(possibleActions.ChangeGovernment, government.hash)
    end
  end
end


-- CHANGE POLICIES
--print("GetPossibleActions: Checking change policies...")
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

function CanUnitRangeAttack(unit, plotIndex)
    if not unit or not plotIndex then return false end
    return UnitManager.CanStartCommand(unit, UnitCommandTypes.RANGE_ATTACK, nil, {
        [UnitOperationTypes.PARAM_X] = Map.GetPlotByIndex(plotIndex):GetX(),
        [UnitOperationTypes.PARAM_Y] = Map.GetPlotByIndex(plotIndex):GetY()
    })
end

function CanUnitAirAttack(unit, plotIndex)
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

function CanUnitWMDStrike(unit, plotIndex, wmdType)
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

function CheckTradeRoute(unit:table, city:table)
	if city and unit then
		local operationParams = {};
		operationParams[UnitOperationTypes.PARAM_X0] = city:GetX();
		operationParams[UnitOperationTypes.PARAM_Y0] = city:GetY();
		operationParams[UnitOperationTypes.PARAM_X1] = unit:GetX();
		operationParams[UnitOperationTypes.PARAM_Y1] = unit:GetY();
		if (UnitManager.CanStartOperation(unit, UnitOperationTypes.MAKE_TRADE_ROUTE, nil, operationParams)) then
			return true;
		end
	end

	return false;
end


local player = Players[Game.GetLocalPlayer()]
local playerTrade = player:GetTrade()

-- Only check for trade routes if we have idle traders and available capacity
if playerTrade:GetNumOutgoingRoutes() < playerTrade:GetOutgoingRouteCapacity() then
    local idleTraders = GetIdleTradeUnits(Game.GetLocalPlayer())
    
    if #idleTraders > 0 then
        possibleActions.EstablishTradeRoute = {}
        
        -- For each idle trader, find all possible trade routes
        for _, traderUnit in ipairs(idleTraders) do
            -- Get origin city
            local originCity = Cities.GetCityInPlot(traderUnit:GetX(), traderUnit:GetY())
            if originCity then
                -- Check all players for possible destination cities
                for _, otherPlayer in ipairs(PlayerManager.GetAlive()) do
                    local otherCities = otherPlayer:GetCities()
                    for _, destCity in otherCities:Members() do
                        -- Check if we can make a trade route
                        if CheckTradeRoute(traderUnit, destCity) then
                            -- Calculate yields for this route
                            local kRouteInfo = GetYieldsForRoute(originCity, destCity)
                            
                            -- Format yields into a readable structure
                            local yields = {
                                Food = kRouteInfo.kYieldValues[YieldTypes.FOOD + 1] or 0,
                                Production = kRouteInfo.kYieldValues[YieldTypes.PRODUCTION + 1] or 0,
                                Gold = kRouteInfo.kYieldValues[YieldTypes.GOLD + 1] or 0,
                                Science = kRouteInfo.kYieldValues[YieldTypes.SCIENCE + 1] or 0,
                                Culture = kRouteInfo.kYieldValues[YieldTypes.CULTURE + 1] or 0,
                                Faith = kRouteInfo.kYieldValues[YieldTypes.FAITH + 1] or 0
                            }

                            -- Add route to possible actions
                            table.insert(possibleActions.EstablishTradeRoute, {
                                TraderUnitID = traderUnit:GetID(),
                                OriginCityID = originCity:GetID(),
                                OriginCityName = originCity:GetName(),
                                DestinationCityID = destCity:GetID(),
                                DestinationCityName = destCity:GetName(),
                                DestinationPlayerID = destCity:GetOwner(),
                                Yields = yields,
                                HasTradingPost = destCity:GetTrade():HasActiveTradingPost(Game.GetLocalPlayer()),
                                Distance = Map.GetPlotDistance(originCity:GetX(), originCity:GetY(), destCity:GetX(), destCity:GetY()),
                            })
                        end
                    end
                end
            end
        end

        -- Sort trade routes by total yield value (optional)
        if #possibleActions.EstablishTradeRoute > 0 then
            table.sort(possibleActions.EstablishTradeRoute, function(a, b)
                local totalYieldA = a.Yields.Food + a.Yields.Production + a.Yields.Gold + 
                                  a.Yields.Science + a.Yields.Culture + a.Yields.Faith
                local totalYieldB = b.Yields.Food + b.Yields.Production + b.Yields.Gold + 
                                  b.Yields.Science + b.Yields.Culture + b.Yields.Faith
                return totalYieldA > totalYieldB
            end)
        end
    end
end

-- Then add this section where we check governor actions:
print("GetPossibleActions: Checking governor actions...")
local playerGovernors = player:GetGovernors()
-- Get number of available/unspent titles
local titlesAvailable = playerGovernors:GetGovernorPoints() - playerGovernors:GetGovernorPointsSpent()

if titlesAvailable > 0 then
    local hasGovernors, governorList = playerGovernors:GetGovernorList()
    
    -- Check each governor
    if hasGovernors then
        for _, governor in ipairs(governorList) do
            local governorDef = GameInfo.Governors[governor:GetType()]
            
            -- Check available promotions for this governor
            for promo in GameInfo.GovernorPromotionSets() do
                if promo.GovernorType == governorDef.GovernorType then
                    local promoInfo = GameInfo.GovernorPromotions[promo.GovernorPromotion]
                    -- Check if promotion can be assigned
                    if not governor:HasPromotion(promoInfo.Index) then
                        table.insert(possibleActions.AssignGovernorTitle, {
                            GovernorType = governorDef.Index,
                            GovernorName = Locale.Lookup(governorDef.Name),
                            PromotionHash = promoInfo.Hash,
                            PromotionType = promoInfo.GovernorPromotionType,
                            PromotionName = Locale.Lookup(promoInfo.Name),
                            Description = Locale.Lookup(promoInfo.Description)
                        })
                    end
                end
            end
        end
    end

    -- Check for unassigned governors that could be initially appointed
    for governor in GameInfo.Governors() do
        if playerGovernors:CanEverAppointGovernor(governor.Index) then
            -- Check if governor is already appointed
            local isAppointed = false
            if hasGovernors then
                for _, existingGovernor in ipairs(governorList) do
                    if existingGovernor:GetType() == governor.Index then
                        isAppointed = true
                        break
                    end
                end
            end
            
            -- If not appointed and can be appointed, add to possibilities
            if not isAppointed and playerGovernors:CanAppointGovernor(governor.Index) then
                table.insert(possibleActions.AssignGovernorTitle, {
                    GovernorType = governor.Index,
                    GovernorName = Locale.Lookup(governor.Name),
                    IsInitialAppointment = true
                })
            end
        end
    end
end

-- Check for possible city assignments (separate from title assignments)
local hasGovernors, governorList = playerGovernors:GetGovernorList()
if hasGovernors then
    for _, city in player:GetCities():Members() do
        local assignedGovernor = city:GetAssignedGovernor()
        local cityID = city:GetID()
        local cityOwner = city:GetOwner()
        
        for _, governor in ipairs(governorList) do
            local governorDef = GameInfo.Governors[governor:GetType()]
            
            -- Only suggest reassignment if:
            -- 1. City has no governor OR
            -- 2. City has a different governor AND governor isn't assigned elsewhere
            local canAssign = false
            
            if not assignedGovernor then
                -- City has no governor
                canAssign = true
            else
                -- Check if this governor is already assigned somewhere
                local isAssignedElsewhere = false
                for _, otherCity in player:GetCities():Members() do
                    local otherCityGovernor = otherCity:GetAssignedGovernor()
                    if otherCityGovernor and 
                       otherCityGovernor:GetType() == governor:GetType() and
                       otherCity:GetID() ~= cityID then
                        isAssignedElsewhere = true
                        break
                    end
                end
                
                if not isAssignedElsewhere and 
                   assignedGovernor:GetType() ~= governor:GetType() then
                    canAssign = true
                end
            end

            if canAssign then
                table.insert(possibleActions.AssignGovernorToCity, {
                    GovernorType = governorDef.Index,
                    GovernorName = Locale.Lookup(governorDef.Name),
                    CityID = cityID,
                    CityName = city:GetName(),
                    CityOwner = cityOwner,
                    X = city:GetX(),
                    Y = city:GetY(),
                    CurrentlyAssigned = (assignedGovernor ~= nil)
                })
            end
        end
    end
end


-- Return the table of possible actions
  print("got possible actions")
  return possibleActions;

  -- End of GetPossibleActions()
end
