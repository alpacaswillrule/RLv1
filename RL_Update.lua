-- PPOTraining.lua
include("RL_Policy")
include("RL_Value")

PPOTraining = {
    -- PPO hyperparameters
    clip_epsilon = 0.2,
    gamma = 0.99,
    lambda = 0.95,  -- GAE parameter
    value_coef = 0.5,  -- Value loss coefficient
    entropy_coef = 0.01  -- Entropy bonus coefficient
}

-- Calculate GAE (Generalized Advantage Estimation)
function PPOTraining:ComputeGAE(transitions)
    local advantages = {}
    local returns = {}
    local lastGAE = 0
    
    -- Process transitions in reverse order
    for i = #transitions, 1, -1 do
        local transition = transitions[i]
        local reward = transition.reward
        local value = transition.value_estimate
        local next_value = transition.next_value_estimate
        local done = (i == #transitions)  -- True if last transition in episode
        
        -- Calculate TD error and GAE
        local delta = reward + (done and 0 or self.gamma * next_value) - value
        lastGAE = delta + self.gamma * self.lambda * (done and 0 or lastGAE)
        
        -- Store advantage and return
        advantages[i] = lastGAE
        returns[i] = lastGAE + value  -- Value plus advantage gives us the return
    end
    
    -- Normalize advantages
    local mean = 0
    local std = 0
    
    -- Calculate mean
    for _, adv in ipairs(advantages) do
        mean = mean + adv
    end
    mean = mean / #advantages
    
    -- Calculate standard deviation
    for _, adv in ipairs(advantages) do
        std = std + (adv - mean) * (adv - mean)
    end
    std = math.sqrt(std / #advantages)
    
    -- Normalize
    for i, adv in ipairs(advantages) do
        advantages[i] = (adv - mean) / (std + 1e-8)
    end
    
    return advantages, returns
end

-- Calculate PPO Policy Loss
function PPOTraining:ComputePolicyLoss(old_action_probs, new_action_probs, advantages)
    local ratio = new_action_probs / old_action_probs
    local surr1 = ratio * advantages
    local surr2 = torch.clamp(ratio, 1 - self.clip_epsilon, 1 + self.clip_epsilon) * advantages
    
    return -torch.min(surr1, surr2):mean()
end

-- Calculate Value Loss
function PPOTraining:ComputeValueLoss(values, returns)
    local diff = values - returns
    return 0.5 * (diff * diff):mean()
end

-- Calculate Entropy Bonus
function PPOTraining:ComputeEntropyBonus(action_probs)
    return -(action_probs * torch.log(action_probs + 1e-10)):sum()
end

-- Main PPO update function
function PPOTraining:Update(gameHistory)
    print("Starting PPO Update")
    
    -- Get transitions from game history
    local transitions = gameHistory.transitions
    if #transitions == 0 then
        print("No transitions to train on")
        return
    end
    
    -- Compute advantages and returns
    local advantages, returns = self:ComputeGAE(transitions)
    
    -- Collect states and process them in batches
    local states = {}
    local actions = {}
    local old_action_probs = {}
    
    for _, transition in ipairs(transitions) do
        table.insert(states, transition.state)
        table.insert(actions, transition.action)
        table.insert(old_action_probs, transition.action_encoding)  -- Saved during forward pass
    end
    
    -- PPO update loop (multiple epochs)
    local num_epochs = 4
    local batch_size = 64
    
    for epoch = 1, num_epochs do
        print("PPO Epoch:", epoch)
        
        -- Process in mini-batches
        for i = 1, #transitions, batch_size do
            local batch_end = math.min(i + batch_size - 1, #transitions)
            local batch_indices = {}
            for j = i, batch_end do
                table.insert(batch_indices, j)
            end
            
            -- Get batch data
            local state_batch = {}
            local action_batch = {}
            local old_probs_batch = {}
            local advantage_batch = {}
            local return_batch = {}
            
            for _, idx in ipairs(batch_indices) do
                table.insert(state_batch, states[idx])
                table.insert(action_batch, actions[idx])
                table.insert(old_probs_batch, old_action_probs[idx])
                table.insert(advantage_batch, advantages[idx])
                table.insert(return_batch, returns[idx])
            end
            
            -- Forward pass through both networks
            local new_action_results = {}
            local new_values = {}
            
            for _, state in ipairs(state_batch) do
                local state_processed = CivTransformerPolicy:ProcessGameState(state)
                local forward_result = CivTransformerPolicy:Forward(state_processed, GetPossibleActions())
                local value = ValueNetwork:GetValue(state)
                
                table.insert(new_action_results, forward_result)
                table.insert(new_values, value)
            end
            
            -- Calculate losses
            local policy_loss = self:ComputePolicyLoss(old_probs_batch, new_action_results, advantage_batch)
            local value_loss = self:ComputeValueLoss(new_values, return_batch)
            local entropy_bonus = self:ComputeEntropyBonus(new_action_results)
            
            -- Total loss
            local total_loss = policy_loss + 
                             self.value_coef * value_loss - 
                             self.entropy_coef * entropy_bonus
            
            -- Update networks (placeholder for now)
            -- We'll need to implement gradient calculation and weight updates
            -- This will depend on how we want to handle optimization
            
            print(string.format("Batch %d/%d - Policy Loss: %.4f, Value Loss: %.4f, Entropy: %.4f",
                math.floor(i/batch_size) + 1, 
                math.ceil(#transitions/batch_size),
                policy_loss,
                value_loss,
                entropy_bonus))
        end
    end
end

return PPOTraining