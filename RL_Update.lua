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



function clamp(value, min_val, max_val)
    return math.min(math.max(value, min_val), max_val)
end

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
    -- Convert inputs to matrices if they aren't already
    local old_probs_mtx = type(old_action_probs.getelement) == "function" and 
                         old_action_probs or 
                         tableToMatrix(old_action_probs)
    local new_probs_mtx = type(new_action_probs.getelement) == "function" and 
                         new_action_probs or 
                         tableToMatrix(new_action_probs)
    local advantages_mtx = type(advantages.getelement) == "function" and 
                         advantages or 
                         tableToMatrix(advantages)

    -- Calculate ratio
    local ratio = matrix.elementwise_div(new_probs_mtx, old_probs_mtx)
    
    -- Calculate surrogate objectives
    local surr1 = matrix.elementwise_mul(ratio, advantages_mtx)
    local surr2 = matrix.elementwise_mul(
        matrix.replace(ratio, function(x) return clamp(x, 1 - self.clip_epsilon, 1 + self.clip_epsilon) end),
        advantages_mtx
    )
    
    -- Take minimum and mean
    local loss = -matrix.mean(matrix.min(surr1, surr2))
    return loss
end
-- Calculate Value Loss
function PPOTraining:ComputeValueLoss(values, returns)
    local values_mtx = type(values.getelement) == "function" and values or tableToMatrix(values)
    local returns_mtx = type(returns.getelement) == "function" and returns or tableToMatrix(returns)
    
    local diff = matrix.sub(values_mtx, returns_mtx)
    return 0.5 * matrix.mean(matrix.elementwise_mul(diff, diff))
end

-- Calculate Entropy Bonus
function PPOTraining:ComputeEntropyBonus(action_probs)
    local probs_mtx = type(action_probs.getelement) == "function" and 
                      action_probs or 
                      tableToMatrix(action_probs)
    
    return -matrix.sum(matrix.elementwise_mul(
        probs_mtx,
        matrix.log(matrix.add_scalar(probs_mtx, 1e-10))
    ))
end

-- Add network update implementation
function PPOTraining:UpdateNetworks(policy_loss, value_loss, entropy_loss)
    -- Calculate total loss and propagate gradients
    local total_loss = policy_loss + 
                      self.value_coef * value_loss - 
                      self.entropy_coef * entropy_loss
    
    -- Zero gradients before backward pass
    CivTransformerPolicy:zero_grad()
    ValueNetwork:zero_grad()
    
    -- Backward pass through both networks
    -- Start backward from total loss
    local initial_grad = matrix:new(1, 1, 1.0)  -- Initial gradient is 1.0
    
    -- Backward through policy network
    CivTransformerPolicy:BackwardPass(
        initial_grad:elementwise_mul(matrix:new(1, 1, 1.0)),  -- Policy gradient
        initial_grad:elementwise_mul(matrix:new(1, 1, self.value_coef))  -- Value gradient
    )
    
    -- Update network weights using calculated gradients
    CivTransformerPolicy:UpdateParams(self.learning_rate)
    ValueNetwork:UpdateParams(self.learning_rate)
end





-- Main PPO update function
function PPOTraining:Update(gameHistory)
    print("Starting PPO Update")
    
    if #gameHistory.transitions == 0 then
        print("No transitions to train on")
        return
    end
    
    -- Compute advantages and returns
    local advantages, returns = self:ComputeGAE(gameHistory.transitions)
    
    -- PPO hyperparameters
    local num_epochs = 4
    local batch_size = 64
    local learning_rate = 0.0003
    
    print("Processing " .. #gameHistory.transitions .. " transitions")
    for epoch = 1, num_epochs do
        print("\nEpoch " .. epoch .. "/" .. num_epochs)
        
        -- Process in mini-batches
        for i = 1, #gameHistory.transitions, batch_size do
            local batch_end = math.min(i + batch_size - 1, #gameHistory.transitions)
            print("\nProcessing batch " .. math.floor(i/batch_size) + 1)
            
            -- Prepare batch data
            local states = {}
            local actions = {}
            local old_action_probs = {}
            local batch_advantages = {}
            local batch_returns = {}
            
            -- Collect batch data
            for j = i, batch_end do
                -- Process state before adding to batch
                local state = gameHistory.transitions[j].state
                local processed_state = CivTransformerPolicy:ProcessGameState(state)
                table.insert(states, processed_state)
                table.insert(actions, gameHistory.transitions[j].action)
                table.insert(old_action_probs, gameHistory.transitions[j].action_encoding)
                table.insert(batch_advantages, advantages[j])
                table.insert(batch_returns, returns[j])
            end
            
            -- Convert batch states to proper matrix
            local batch_states
            if #states > 0 then
                -- Create matrix with proper dimensions
                batch_states = matrix:new(#states, STATE_EMBED_SIZE)
                for row = 1, #states do
                    for col = 1, STATE_EMBED_SIZE do
                        batch_states:setelement(row, col, states[row]:getelement(1, col))
                    end
                end
            else
                print("Warning: Empty batch of states")
                batch_states = matrix:new(1, STATE_EMBED_SIZE)
            end
            
            print("Batch states dimensions:", batch_states:size()[1], "x", batch_states:size()[2])
            
            -- Forward passes
            local policy_output = CivTransformerPolicy:Forward(batch_states, GetPossibleActions())
            local value_output = ValueNetwork:Forward(batch_states)
            
            -- Convert advantages and returns to matrices
            local advantages_mtx = matrix:new(#batch_advantages, 1)
            local returns_mtx = matrix:new(#batch_returns, 1)
            for k = 1, #batch_advantages do
                advantages_mtx:setelement(k, 1, batch_advantages[k])
                returns_mtx:setelement(k, 1, batch_returns[k])
            end
            
            -- Convert old action probabilities to matrix
            local old_probs_mtx = matrix:new(#old_action_probs, #old_action_probs[1])
            for k = 1, #old_action_probs do
                for l = 1, #old_action_probs[k] do
                    old_probs_mtx:setelement(k, l, old_action_probs[k][l])
                end
            end
            
            -- Calculate losses
            local policy_loss = self:ComputePolicyLoss(
                old_probs_mtx,
                policy_output.action_logits,
                advantages_mtx
            )
            
            local value_loss = self:ComputeValueLoss(value_output, returns_mtx)
            local entropy_loss = self:ComputeEntropyBonus(policy_output.action_probabilities)
            
            -- Compute gradients and update networks
            CivTransformerPolicy:zero_grad()
            ValueNetwork:zero_grad()
            
            -- Backward passes
            local policy_grad = matrix:new(policy_output.action_logits:size()[1], 
                                         policy_output.action_logits:size()[2], 1.0)
            local value_grad = matrix:new(value_output:size()[1], 
                                        value_output:size()[2], 1.0)
            
            CivTransformerPolicy:BackwardPass(policy_grad, value_grad)
            ValueNetwork:BackwardPass(value_grad)
            
            -- Update network parameters
            CivTransformerPolicy:UpdateParams(learning_rate)
            ValueNetwork:UpdateParams(learning_rate)
            
            -- Print progress
            print(string.format(
                "Batch %d/%d - Policy Loss: %.4f, Value Loss: %.4f, Entropy: %.4f",
                math.floor(i/batch_size) + 1,
                math.ceil(#gameHistory.transitions/batch_size),
                policy_loss,
                value_loss,
                entropy_loss
            ))
        end
    end
    
    print("PPO Update completed")
end



return PPOTraining