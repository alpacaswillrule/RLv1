-- PPOTraining.lua
include("RL_Policy")
include("RL_Value")

PPOTraining = {
    clip_epsilon = 0.2,
    gamma = 0.99,
    lambda = 0.95,
    value_coef = 0.5,
    entropy_coef = 0.01
}
STATE_EMBED_SIZE = 4863
local TRANSFORMER_DIM = 512
function clamp(value, min_val, max_val)
    return math.min(math.max(value, min_val), max_val)
end

-- Calculate GAE (Generalized Advantage Estimation)
function PPOTraining:ComputeGAE(transitions)
    --print("\nComputing GAE:")
    --print("Number of transitions:", #transitions)
    
    local advantages = {}
    local returns = {}
    local lastGAE = 0
    
    -- Process transitions in reverse order
    for i = #transitions, 1, -1 do
        local transition = transitions[i]
        --print(string.format("\nTransition %d:", i))
        --print("  Reward:", transition.reward)
        --print("  Value estimate:", transition.value_estimate)
        --print("  Next value estimate:", transition.next_value_estimate)
        
        local reward = transition.reward
        local value = transition.value_estimate
        local next_value = transition.next_value_estimate
        local done = (i == #transitions)
        
        -- Calculate TD error and GAE
        local delta = reward + (done and 0 or self.gamma * next_value) - value
        lastGAE = delta + self.gamma * self.lambda * (done and 0 or lastGAE)
        
        -- Store advantage and return
        advantages[i] = lastGAE
        returns[i] = lastGAE + value
    end
    
    -- --print final results
    --print("\nComputed advantages:", #advantages)
    --print("Computed returns:", #returns)
    
    return advantages, returns
end
function PPOTraining:ComputePolicyLoss(old_probs, new_probs, advantages)
    --print("\nComputing Policy Loss:")
    --print("Input validation:")
    --print("old_probs:", type(old_probs), old_probs and #old_probs.action_type_probs or "nil")
    --print("new_probs:", type(new_probs), new_probs and #new_probs.action_type_probs or "nil")
    --print("advantages:", type(advantages), advantages and #advantages or "nil")

    -- Check if probabilities are empty
    if not old_probs or #old_probs.action_type_probs == 0 or
       not new_probs or #new_probs.action_type_probs == 0 then
        --print("WARNING: Empty probabilities detected. Returning zero policy loss.")
        return 0
    end

    
    -- Convert to matrices
    --print("\nConverting to matrices...")
    local old_probs_mtx = self:ProbsToMatrix(old_probs)
    --print("old_probs_mtx dimensions:", old_probs_mtx:size()[1], "x", old_probs_mtx:size()[2])
    
    local new_probs_mtx = self:ProbsToMatrix(new_probs)
    --print("new_probs_mtx dimensions:", new_probs_mtx:size()[1], "x", new_probs_mtx:size()[2])
    
    local advantages_mtx = self:ProbsToMatrix(advantages)
    --print("advantages_mtx dimensions:", advantages_mtx:size()[1], "x", advantages_mtx:size()[2])
    
    -- Calculate ratio
    --print("\nCalculating probability ratio...")
    local ratio = matrix.elementwise_div(new_probs_mtx, old_probs_mtx)
    --print("ratio dimensions:", ratio:size()[1], "x", ratio:size()[2])
    
    -- Calculate surrogate objectives
    --print("\nCalculating surrogate objectives...")
    local surr1 = matrix.elementwise_mul(ratio, advantages_mtx)
    --print("surr1 dimensions:", surr1:size()[1], "x", surr1:size()[2])
    
    --print("Applying clipping...")
    local surr2 = matrix.elementwise_mul(
        matrix.replace(ratio, function(x) 
            return clamp(x, 1 - self.clip_epsilon, 1 + self.clip_epsilon) 
        end),
        advantages_mtx
    )
    --print("surr2 dimensions:", surr2:size()[1], "x", surr2:size()[2])
    
    --print("\nCalculating final loss...")
    local min_surr = matrix.min(surr1, surr2)
    --print("min_surr dimensions:", min_surr:size()[1], "x", min_surr:size()[2])
    
    local loss = -matrix.mean(min_surr)
    print("Final loss value:", loss)
    
    return loss
end

-- Helper function to convert probability array to matrix format
function PPOTraining:ProbsToMatrix(probs)
    --print("ProbsToMatrix input type:", type(probs))
    if type(probs) == "table" then
        for k,v in pairs(probs) do
            --print(string.format("Key: %s, Value type: %s, Value: %s", 
                --tostring(k), type(v), tostring(v)))
        end
    end
    -- Check if probs is nil or empty
    if not probs then
        --print("WARNING: Nil probabilities in ProbsToMatrix")
        return matrix:new(1, 1, 0)
    end

    -- Convert single array of probabilities to 2D table
    local mtx_data = {{}}
    
    -- Handle case where probs is a table with action_type_probs
    if type(probs) == "table" and probs.action_type_probs then
        if #probs.action_type_probs > 0 then
            for i = 1, #probs.action_type_probs do
                local val = tonumber(probs.action_type_probs[i])
                if not val then
                    --print("WARNING: Non-numeric value found in action_type_probs at index " .. i)
                    val = 0
                end
                table.insert(mtx_data[1], val)
            end
        else
            return matrix:new(1, 1, 0)
        end
    -- Handle case where probs is a simple array
    elseif type(probs) == "table" and #probs > 0 then
        for i = 1, #probs do
            local val = tonumber(probs[i])
            if not val then
                --print("WARNING: Non-numeric value found in probs at index " .. i)
                val = 0
            end
            table.insert(mtx_data[1], val)
        end
    else
        return matrix:new(1, 1, 0)
    end
    
    --print("Matrix data created:", #mtx_data, "x", #mtx_data[1])
    for i, row in ipairs(mtx_data) do
        for j, val in ipairs(row) do
            --print(string.format("Element (%d,%d): %s (type: %s)", i, j, tostring(val), type(val)))
        end
    end
    
    local result = tableToMatrix(mtx_data)
    --print("Matrix created with dimensions:", result:size()[1], "x", result:size()[2])
    
    return result
end

-- Update ComputeActionTypeLoss and ComputeOptionLoss similarly
function PPOTraining:ComputeActionTypeLoss(old_probs, new_probs, advantages)
    local old_probs_mtx = self:ProbsToMatrix(old_probs)
    local new_probs_mtx = self:ProbsToMatrix(new_probs)
    local advantages_mtx = self:ProbsToMatrix(advantages)
    
    -- Calculate ratio and objectives
    local ratio = matrix.elementwise_div(new_probs_mtx, old_probs_mtx)
    
    local surr1 = matrix.elementwise_mul(ratio, advantages_mtx)
    local surr2 = matrix.elementwise_mul(
        matrix.replace(ratio, function(x) 
            return clamp(x, 1 - self.clip_epsilon, 1 + self.clip_epsilon) 
        end),
        advantages_mtx
    )
    
    return -matrix.mean(matrix.min(surr1, surr2))
end

function PPOTraining:ComputeOptionLoss(old_probs, new_probs, advantages)
    local old_probs_mtx = self:ProbsToMatrix(old_probs)
    local new_probs_mtx = self:ProbsToMatrix(new_probs)
    local advantages_mtx = self:ProbsToMatrix(advantages)
    
    -- Same clipped objective as action type loss
    local ratio = matrix.elementwise_div(new_probs_mtx, old_probs_mtx)
    
    local surr1 = matrix.elementwise_mul(ratio, advantages_mtx)
    local surr2 = matrix.elementwise_mul(
        matrix.replace(ratio, function(x) 
            return clamp(x, 1 - self.clip_epsilon, 1 + self.clip_epsilon) 
        end),
        advantages_mtx
    )
    
    return -matrix.mean(matrix.min(surr1, surr2))
end
-- Calculate Value Loss
function PPOTraining:ComputeValueLoss(values, returns)
    local values_mtx = type(values.getelement) == "function" and values or tableToMatrix(values)
    local returns_mtx = type(returns.getelement) == "function" and returns or tableToMatrix(returns)
    
    local diff = matrix.sub(values_mtx, returns_mtx)
    return 0.5 * matrix.mean(matrix.elementwise_mul(diff, diff))
end

function PPOTraining:ComputeDistributionEntropy(probs)
    local probs_mtx = tableToMatrix(probs)
    return -matrix.sum(matrix.elementwise_mul(
        probs_mtx,
        matrix.log(matrix.add_scalar(probs_mtx, 1e-10))
    ))
end

-- Calculate Entropy Bonus
function PPOTraining:ComputeEntropyBonus(probs)
    local action_type_entropy = self:ComputeDistributionEntropy(probs.action_type_probs)
    local option_entropy = 0
    
    if probs.option_probs then
        option_entropy = self:ComputeDistributionEntropy(probs.option_probs)
    end
    
    return action_type_entropy + option_entropy
end

function PPOTraining:PrepareBatchStates(states)
    --print("\nPreparing Batch States:")
    --print("Number of states:", #states)
    
    if #states == 0 then
        --print("WARNING: Empty states batch")
        return nil
    end

    -- Debug first state
    local first_state = states[1]
    --print("First state type:", type(first_state))
    if type(first_state.size) == "function" then
        --print("First state dimensions:", first_state:size()[1], "x", first_state:size()[2])
    end

    -- Get dimensions from first state
    local state_rows = first_state:rows()
    local state_cols = first_state:columns()
    --print("Expected dimensions:", state_rows, "x", state_cols)
    
    -- Validate dimensions match STATE_EMBED_SIZE
    if state_cols ~= STATE_EMBED_SIZE then
        --print(string.format("WARNING: State dimension mismatch. Expected %d columns, got %d", 
            --STATE_EMBED_SIZE, state_cols))
        return nil
    end

    -- Create batch matrix
    local batch_matrix = matrix:new(#states, state_cols)
    --print("Created batch matrix:", batch_matrix:rows(), "x", batch_matrix:columns())

    -- Fill batch matrix
    for i = 1, #states do
        local state = states[i]
        if state:rows() ~= state_rows or state:columns() ~= state_cols then
            --print(string.format("WARNING: State %d dimensions mismatch", i))
            return nil
        end
        
        for j = 1, state_cols do
            local val = state:getelement(1, j)
            -- Check for NaN
            if val ~= val then
                --print(string.format("WARNING: NaN found in state %d, column %d", i, j))
                return nil
            end
            batch_matrix:setelement(i, j, val)
        end
    end
    
    return batch_matrix
end

-- Main PPO update function
function PPOTraining:Update(gameHistory)
    --print("Starting PPO Update")
    
    if #gameHistory.transitions == 0 then
        --print("No transitions to train on")
        return
    end
    
    -- Check if networks are initialized
    if not CivTransformerPolicy.initialized then
        --print("WARNING: CivTransformerPolicy not initialized, initializing now...")
        CivTransformerPolicy:Init()
    end
    if not ValueNetwork.initialized then
        --print("WARNING: ValueNetwork not initialized, initializing now...")
        ValueNetwork:Init()
    end
    
    local advantages, returns = self:ComputeGAE(gameHistory.transitions)
    local num_epochs = 4
    local batch_size = 64
    local learning_rate = 0.0003
    
    for epoch = 1, num_epochs do
        --print("\nEpoch " .. epoch .. "/" .. num_epochs)
        
        for i = 1, #gameHistory.transitions, batch_size do
            local batch_end = math.min(i + batch_size - 1, #gameHistory.transitions)
            --print("\nProcessing batch from index", i, "to", batch_end)
            
            -- Prepare batch data
            local states = {}
            local old_probs = {
                action_type_probs = {},
                option_probs = {}
            }
            local batch_advantages = {}
            local batch_returns = {}
            
                for j = i, batch_end do
                local transition = gameHistory.transitions[j]
                if transition.state then
                    local processed_state = CivTransformerPolicy:ProcessGameState(transition.state)
                    table.insert(states, processed_state)
                    table.insert(batch_advantages, advantages[j])
                    table.insert(batch_returns, returns[j])
                    
                    -- Add validation and conversion of probabilities
                    if transition.action_probs then
                        local probs = {}
                        for _, p in ipairs(transition.action_probs) do
                            -- Convert to number and validate
                            local prob = tonumber(p)
                            if not prob then
                                --print("WARNING: Invalid probability value:", p)
                                prob = 1e-8  -- Small non-zero value
                            end
                            table.insert(probs, prob)
                        end
                        table.insert(old_probs.action_type_probs, probs)
                    end
            -- After processing batch data
            --print("Probability validation:")
            --print("Number of action probability sets:", #old_probs.action_type_probs)
            if #old_probs.action_type_probs > 0 then
                --print("Sample action probabilities:", table.concat(old_probs.action_type_probs[1], ", "))
            end
                                
        -- Same validation for option probs
        if transition.option_probs then
            local probs = {}
            for _, p in ipairs(transition.option_probs) do
                local prob = tonumber(p)
                if not prob then prob = 1e-8 end
                table.insert(probs, prob)
            end
            table.insert(old_probs.option_probs, probs)
        end
    else
        --print("WARNING: Missing state data for transition", j)
    end
end

            -- Process each state individually
            local all_policy_outputs = {}
            local all_value_outputs = {}
            
            for _, state in ipairs(states) do
                -- Forward pass through policy network
                local policy_output = CivTransformerPolicy:Forward(state, GetPossibleActions())
                table.insert(all_policy_outputs, policy_output)
                
                -- Forward pass through value network
                local value_output = ValueNetwork:Forward(state)
                table.insert(all_value_outputs, value_output)
            end
            
            -- Combine policy outputs
            local combined_action_probs = {}
            local combined_option_probs = {}
            for _, output in ipairs(all_policy_outputs) do
                if output.action_probs then
                    table.insert(combined_action_probs, output.action_probs)
                end
                if output.option_probs then
                    table.insert(combined_option_probs, output.option_probs)
                end
            end
            
            -- Calculate losses
            local policy_loss = self:ComputePolicyLoss(
                old_probs,
                {
                    action_type_probs = combined_action_probs,
                    option_probs = combined_option_probs
                },
                batch_advantages
            )
            
            -- Convert value outputs to matrix
            local value_matrix = matrix:new(#all_value_outputs, 1)
            for k, v in ipairs(all_value_outputs) do
                value_matrix:setelement(k, 1, v)
            end
            
            local returns_matrix = matrix:new(#batch_returns, 1)
            for k, v in ipairs(batch_returns) do
                returns_matrix:setelement(k, 1, v)
            end
            
            local value_loss = self:ComputeValueLoss(value_matrix, returns_matrix)
            local entropy_loss = self:ComputeEntropyBonus({
                action_type_probs = combined_action_probs,
                option_probs = combined_option_probs
            })
            
            -- Compute total loss
            local total_loss = policy_loss + 
                             self.value_coef * value_loss - 
                             self.entropy_coef * entropy_loss
            
            -- Zero gradients
            CivTransformerPolicy:zero_grad()
            ValueNetwork:zero_grad()
            
            -- Create gradient matrices
            local policy_grad = {
                action_type_grad = matrix:new(#combined_action_probs, #ACTION_TYPES, 1.0),
                option_grad = #combined_option_probs > 0 and 
                             matrix:new(#combined_option_probs, combined_option_probs[1]:columns(), 1.0) or nil
            }
            
            local value_grad = matrix:new(value_matrix:size()[1], 1, 1.0)
            
            -- Backward passes
            CivTransformerPolicy:BackwardPass(policy_grad, value_grad)
            ValueNetwork:BackwardPass(value_grad)
            
            -- Update parameters
            CivTransformerPolicy:UpdateParams(learning_rate)
            ValueNetwork:UpdateParams(learning_rate)
            
            -- --print progress
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
    
    --print("PPO Update completed")
end



return PPOTraining