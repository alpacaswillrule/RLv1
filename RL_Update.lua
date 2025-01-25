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
function PPOTraining:ComputePolicyLoss(old_probs, new_probs, advantages)
    print("\nComputing Policy Loss:")
    print("Input validation:")
    print("old_probs:", type(old_probs), old_probs and #old_probs or "nil")
    print("new_probs:", type(new_probs), new_probs and #new_probs or "nil")
    print("advantages:", type(advantages), advantages and #advantages or "nil")
    
    -- Convert to matrices
    print("\nConverting to matrices...")
    local old_probs_mtx = self:ProbsToMatrix(old_probs)
    print("old_probs_mtx dimensions:", old_probs_mtx:size()[1], "x", old_probs_mtx:size()[2])
    
    local new_probs_mtx = self:ProbsToMatrix(new_probs)
    print("new_probs_mtx dimensions:", new_probs_mtx:size()[1], "x", new_probs_mtx:size()[2])
    
    local advantages_mtx = self:ProbsToMatrix(advantages)
    print("advantages_mtx dimensions:", advantages_mtx:size()[1], "x", advantages_mtx:size()[2])
    
    -- Calculate ratio
    print("\nCalculating probability ratio...")
    local ratio = matrix.elementwise_div(new_probs_mtx, old_probs_mtx)
    print("ratio dimensions:", ratio:size()[1], "x", ratio:size()[2])
    
    -- Calculate surrogate objectives
    print("\nCalculating surrogate objectives...")
    local surr1 = matrix.elementwise_mul(ratio, advantages_mtx)
    print("surr1 dimensions:", surr1:size()[1], "x", surr1:size()[2])
    
    print("Applying clipping...")
    local surr2 = matrix.elementwise_mul(
        matrix.replace(ratio, function(x) 
            return clamp(x, 1 - self.clip_epsilon, 1 + self.clip_epsilon) 
        end),
        advantages_mtx
    )
    print("surr2 dimensions:", surr2:size()[1], "x", surr2:size()[2])
    
    print("\nCalculating final loss...")
    local min_surr = matrix.min(surr1, surr2)
    print("min_surr dimensions:", min_surr:size()[1], "x", min_surr:size()[2])
    
    local loss = -matrix.mean(min_surr)
    print("Final loss value:", loss)
    
    return loss
end

-- Helper function to convert probability array to matrix format
function PPOTraining:ProbsToMatrix(probs)
    -- Check if input is nil
    if not probs then
        print("WARNING: Received nil probabilities")
        return matrix:new(1, 1, 0)
    end
    
    -- Convert single array of probabilities to 2D table
    local mtx_data = {{}}
    for i = 1, #probs do
        table.insert(mtx_data[1], probs[i])
    end
    
    return tableToMatrix(mtx_data)
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
    -- Check if states is empty
    if #states == 0 then
        print("WARNING: Empty states batch")
        return nil
    end

    -- Get dimensions from first state
    local state_rows = states[1]:rows()
    local state_cols = states[1]:columns()
    
    -- Create batch matrix with dimensions [batch_size x state_dimension]
    local batch_matrix = matrix:new(#states, state_cols)
    
    -- Fill batch matrix with states
    for i = 1, #states do
        local state = states[i]
        -- Verify state dimensions match
        if state:rows() ~= state_rows or state:columns() ~= state_cols then
            print(string.format("WARNING: State %d dimensions mismatch. Expected %dx%d, got %dx%d", 
                i, state_rows, state_cols, state:rows(), state:columns()))
            return nil
        end
        
        -- Copy state into batch matrix
        for j = 1, state_cols do
            batch_matrix:setelement(i, j, state:getelement(1, j))
        end
    end
    
    return batch_matrix
end


-- Main PPO update function
function PPOTraining:Update(gameHistory)
    print("Starting PPO Update")
    
    if #gameHistory.transitions == 0 then
        print("No transitions to train on")
        return
    end
    
    
    local advantages, returns = self:ComputeGAE(gameHistory.transitions)
    local num_epochs = 4
    local batch_size = 64
    local learning_rate = 0.0003
    
    for epoch = 1, num_epochs do
        print("\nEpoch " .. epoch .. "/" .. num_epochs)
        
        for i = 1, #gameHistory.transitions, batch_size do
            local batch_end = math.min(i + batch_size - 1, #gameHistory.transitions)
            print("\nProcessing batch from index", i, "to", batch_end)
            print("Total transitions:", #gameHistory.transitions)
            
            -- Prepare batch data
            local states = {}
            local old_probs = {
                action_type_probs = {},
                option_probs = {}
            }
            local batch_advantages = {}
            local batch_returns = {}
            
            -- Collect batch data
            for j = i, batch_end do
                local transition = gameHistory.transitions[j]
                table.insert(states, CivTransformerPolicy:ProcessGameState(transition.state))
                table.insert(old_probs.action_type_probs, transition.action_probabilities)
                if transition.selected_probability then  -- For option selection
                    table.insert(old_probs.option_probs, transition.selected_probability)
                end
                table.insert(batch_advantages, advantages[j])
                table.insert(batch_returns, returns[j])
            end

            print("\nCollected batch data:")
            print("Number of states:", #states)
            print("Number of action_type_probs:", #old_probs.action_type_probs)
            print("Number of option_probs:", #old_probs.option_probs)
            print("Number of advantages:", #batch_advantages)
            
            -- Convert batch data to matrices
            local batch_states = self:PrepareBatchStates(states)
            
            -- Forward passes through both networks
            local policy_output = CivTransformerPolicy:Forward(batch_states, GetPossibleActions())
            local value_output = ValueNetwork:Forward(batch_states)
            print("\nForward pass output:")
            print("policy_output.action_probs:", policy_output.action_probs and #policy_output.action_probs or "nil")
            print("policy_output.option_probs:", policy_output.option_probs and #policy_output.option_probs or "nil")
            print("value_output:", value_output)
            print("\nInputs to ComputePolicyLoss:")
            print("old_probs structure:", type(old_probs))
            if type(old_probs) == "table" then
                print("  action_type_probs:", #old_probs.action_type_probs)
                print("  option_probs:", #old_probs.option_probs)
            end
                        -- Calculate losses
            local policy_loss = self:ComputePolicyLoss(
                old_probs,
                {
                    action_type_probs = policy_output.action_probs,
                    option_probs = policy_output.option_probs
                },
                batch_advantages
            )

            
            
            local value_loss = self:ComputeValueLoss(value_output, batch_returns)
            local entropy_loss = self:ComputeEntropyBonus(policy_output)
            
            -- Compute gradients and update networks
            local total_loss = policy_loss + 
                             self.value_coef * value_loss - 
                             self.entropy_coef * entropy_loss
            
            -- Zero gradients
            CivTransformerPolicy:zero_grad()
            ValueNetwork:zero_grad()
            
            -- Backward passes with appropriate gradients
            local policy_grad = {
                action_type_grad = matrix:new(policy_output.action_probs:size()[1], 
                                            policy_output.action_probs:size()[2], 1.0),
                option_grad = policy_output.option_probs and 
                             matrix:new(policy_output.option_probs:size()[1],
                                      policy_output.option_probs:size()[2], 1.0) or nil
            }
            
            local value_grad = matrix:new(value_output:size()[1], 
                                        value_output:size()[2], 1.0)
            
            -- Backward passes
            CivTransformerPolicy:BackwardPass(policy_grad, value_grad)
            ValueNetwork:BackwardPass(value_grad)
            
            -- Update parameters
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
end



return PPOTraining