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
    if type(probs) ~= "table" then
        print("WARNING: Expected table of probabilities, got", type(probs))
        return 0
    end
    
    local entropy = 0
    for _, prob in ipairs(probs) do
        -- Add small epsilon to avoid log(0)
        if prob > 0 then
            entropy = entropy - prob * math.log(prob + 1e-10)
        end
    end
    return entropy
end

-- Calculate Entropy Bonus
function PPOTraining:ComputeEntropyBonus(probs)
    -- Check if we have action probabilities
    if not probs.action_probs then
        print("WARNING: No action probabilities found")
        return 0
    end
    
    local total_entropy = 0
    
    -- Process each set of probabilities in the batch
    for _, batch_probs in ipairs(probs.action_probs) do
        -- Add action type entropy
        total_entropy = total_entropy + self:ComputeDistributionEntropy(batch_probs)
        
        -- If there are option probabilities for this batch item, add those too
        if probs.option_probs and #probs.option_probs > 0 then
            for _, option_probs in ipairs(probs.option_probs) do
                total_entropy = total_entropy + self:ComputeDistributionEntropy(option_probs)
            end
        end
    end
    
    -- Return average entropy across batch
    return total_entropy / #probs.action_probs
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

-- PPO Update with proper batch handling
function PPOTraining:PrepareBatch(transitions, start_idx, batch_size)
    -- Calculate valid batch size based on remaining transitions
    local valid_size = math.min(batch_size, #transitions - start_idx + 1)
    
    -- Initialize batch containers
    local batch = {
        -- Create state matrix for batch forward pass
        states = matrix:new(valid_size, STATE_EMBED_SIZE),
        next_states = matrix:new(valid_size, STATE_EMBED_SIZE),
        
        -- Store metadata needed for loss computation
        advantages = matrix:new(valid_size, 1),
        returns = matrix:new(valid_size, 1),
        
        -- Store original probabilities for importance sampling
        old_action_probs = matrix:new(valid_size, #ACTION_TYPES),
        old_option_probs = {},  -- Will store if available
        
        -- Store original actions for loss computation
        actions = {},
        value_estimates = matrix:new(valid_size, 1)
    }
    
    -- Fill batch with transition data
    for i = 1, valid_size do
        local trans_idx = start_idx + i - 1
        local transition = transitions[trans_idx]
        
        -- Process state into matrix row
        local state_encoding = CivTransformerPolicy:ProcessGameState(transition.state)
        local next_state_encoding = CivTransformerPolicy:ProcessGameState(transition.next_state)
        
        -- Set state and next_state rows
        for j = 1, STATE_EMBED_SIZE do
            batch.states:setelement(i, j, state_encoding:getelement(1, j))
            batch.next_states:setelement(i, j, next_state_encoding:getelement(1, j))
        end
        
        -- Store action probabilities
        for j = 1, #ACTION_TYPES do
            batch.old_action_probs:setelement(i, j, transition.action_probs[j] or 1e-8)
        end
        
        -- Store option probabilities if available
        if transition.option_probs then
            if not batch.old_option_probs[i] then
                batch.old_option_probs[i] = {}
            end
            for j = 1, #transition.option_probs do
                table.insert(batch.old_option_probs[i], transition.option_probs[j])
            end
        end
        
        -- Store other data
        batch.advantages:setelement(i, 1, transition.advantage or 0)
        batch.returns:setelement(i, 1, transition.returns or 0)
        batch.value_estimates:setelement(i, 1, transition.value_estimate or 0)
        
        -- Store action
        table.insert(batch.actions, {
            type = transition.action.type,
            params = transition.action.params
        })
    end
    
    return batch
end

function ValidateBatchAndOutputs(batch, policy_outputs, batch_size, valid_size)
    print("\n=== BATCH VALIDATION ===")

    -- Validate batch structure
    print("\nBatch Structure:")
    if not batch then
        print("ERROR: Batch is nil")
        return false
    end

    -- Check states matrix
    print("\nStates Matrix:")
    if not batch.states or not batch.states.size then
        print("ERROR: Invalid states matrix")
        return false
    end
    local state_rows, state_cols = batch.states:size()[1], batch.states:size()[2]
    print(string.format("- Dimensions: %d x %d", state_rows, state_cols))
    print(string.format("- Expected size: %d x %d", valid_size, STATE_EMBED_SIZE))
    if state_cols ~= STATE_EMBED_SIZE then
        print("ERROR: State embedding size mismatch")
        return false
    end

    -- Check advantages matrix
    print("\nAdvantages Matrix:")
    if not batch.advantages or not batch.advantages.size then
        print("ERROR: Invalid advantages matrix")
        return false
    end
    local adv_rows, adv_cols = batch.advantages:size()[1], batch.advantages:size()[2]
    print(string.format("- Dimensions: %d x %d", adv_rows, adv_cols))
    print(string.format("- Expected size: %d x 1", valid_size))

    -- Check returns matrix
    print("\nReturns Matrix:")
    if not batch.returns or not batch.returns.size then
        print("ERROR: Invalid returns matrix")
        return false
    end
    local ret_rows, ret_cols = batch.returns:size()[1], batch.returns:size()[2]
    print(string.format("- Dimensions: %d x %d", ret_rows, ret_cols))
    print(string.format("- Expected size: %d x 1", valid_size))

    -- Check old action probabilities matrix
    print("\nOld Action Probabilities Matrix:")
    if not batch.old_action_probs or not batch.old_action_probs.size then
        print("ERROR: Invalid old action probabilities matrix")
        return false
    end
    local old_probs_rows, old_probs_cols = batch.old_action_probs:size()[1], batch.old_action_probs:size()[2]
    print(string.format("- Dimensions: %d x %d", old_probs_rows, old_probs_cols))
    print(string.format("- Expected size: %d x %d", valid_size, #ACTION_TYPES))

    -- Sample values from old action probabilities
    print("\nSample Old Action Probabilities (first row):")
    for i = 1, math.min(5, old_probs_cols) do
        print(string.format("- Action %d: %.4f", i, batch.old_action_probs:getelement(1, i)))
    end

    -- Validate policy outputs structure
    print("\nPolicy Outputs Validation:")
    if not policy_outputs then
        print("ERROR: Policy outputs is nil")
        return false
    end

    -- Check action probabilities
    print("\nNew Action Probabilities:")
    if not policy_outputs.action_probs then
        print("ERROR: Missing action probabilities in policy outputs")
        return false
    end
    print(string.format("- Number of samples: %d", #policy_outputs.action_probs))
    if #policy_outputs.action_probs ~= valid_size then
        print(string.format("ERROR: Expected %d samples, got %d", valid_size, #policy_outputs.action_probs))
        return false
    end

    -- Check first sample of action probabilities
    if #policy_outputs.action_probs > 0 then
        local first_probs = policy_outputs.action_probs[1]
        print("\nFirst Sample Action Probabilities:")
        print(string.format("- Number of probabilities: %d", #first_probs))
        print(string.format("- Expected: %d", #ACTION_TYPES))
        
        -- Print first few probabilities
        print("Sample values:")
        for i = 1, math.min(5, #first_probs) do
            print(string.format("- Action %d: %.4f", i, first_probs[i]))
        end

        -- Validate probability sum
        local sum = 0
        for _, prob in ipairs(first_probs) do
            sum = sum + prob
        end
        print(string.format("- Probability sum: %.4f (should be close to 1.0)", sum))
        if math.abs(sum - 1.0) > 0.01 then
            print("WARNING: Probabilities do not sum to 1.0")
        end
    end

    -- Check option probabilities if present
    if policy_outputs.option_probs then
        print("\nOption Probabilities:")
        print(string.format("- Number of samples: %d", #policy_outputs.option_probs))
        if #policy_outputs.option_probs > 0 then
            local first_option_probs = policy_outputs.option_probs[1]
            print(string.format("- First sample size: %d", #first_option_probs))
        end
    else
        print("\nNo option probabilities present")
    end

    -- Validate transformer outputs if present
    if policy_outputs.transformer_outputs then
        print("\nTransformer Outputs:")
        if type(policy_outputs.transformer_outputs.size) == "function" then
            local t_rows, t_cols = policy_outputs.transformer_outputs:size()[1], policy_outputs.transformer_outputs:size()[2]
            print(string.format("- Dimensions: %d x %d", t_rows, t_cols))
            print(string.format("- Expected size: %d x %d", valid_size, TRANSFORMER_DIM))
        else
            print("WARNING: Transformer outputs not in matrix format")
        end
    end

    print("\nValidation Complete!")
    return true
end

-- Function to validate probability distributions
function ValidateProbabilityDistribution(probs, name)
    print(string.format("\nValidating %s distribution:", name))
    
    if type(probs) ~= "table" then
        print("ERROR: Probabilities must be a table")
        return false
    end
    
    local sum = 0
    local min_prob = 1
    local max_prob = 0
    local num_zero = 0
    
    for i, prob in ipairs(probs) do
        -- Check for valid probability values
        if prob < 0 or prob > 1 then
            print(string.format("ERROR: Invalid probability at index %d: %.4f", i, prob))
            return false
        end
        
        -- Update statistics
        sum = sum + prob
        min_prob = math.min(min_prob, prob)
        max_prob = math.max(max_prob, prob)
        if prob == 0 then
            num_zero = num_zero + 1
        end
    end
    
    -- Print distribution statistics
    print(string.format("- Size: %d", #probs))
    print(string.format("- Sum: %.4f", sum))
    print(string.format("- Min: %.4f", min_prob))
    print(string.format("- Max: %.4f", max_prob))
    print(string.format("- Zero probabilities: %d", num_zero))
    
    -- Check if distribution sums to approximately 1
    if math.abs(sum - 1.0) > 0.01 then
        print("WARNING: Distribution does not sum to 1.0")
        return false
    end
    
    return true
end




function PPOTraining:Update(gameHistory)
    if #gameHistory.transitions == 0 then
        print("No transitions to train on")
        return
    end
    
    -- Compute advantages and returns for all transitions
    local advantages, returns = self:ComputeGAE(gameHistory.transitions)
    
    -- Add advantages and returns to transitions
    for i, transition in ipairs(gameHistory.transitions) do
        transition.advantage = advantages[i]  -- Fixed typo
        transition.returns = returns[i]
    end
    
    -- Training hyperparameters
    local num_epochs = 4
    local batch_size = 64
    local base_learning_rate = 0.0003
    
    -- Tracking metrics across all epochs
    local training_stats = {
        policy_losses = {},
        value_losses = {},
        entropies = {},
        ratios = {}
    }
    
    for epoch = 1, num_epochs do
        -- Update learning rate with schedule
        local current_lr = base_learning_rate * (1 - epoch/num_epochs)
        print(string.format("\nEpoch %d/%d (lr: %.6f)", epoch, num_epochs, current_lr))
        
        -- Shuffle transitions
        local shuffled_indices = {}
        for i = 1, #gameHistory.transitions do
            shuffled_indices[i] = i
        end
        for i = #shuffled_indices, 2, -1 do
            local j = math.random(i)
            shuffled_indices[i], shuffled_indices[j] = shuffled_indices[j], shuffled_indices[i]
        end
        
        -- Track epoch metrics
        local epoch_metrics = {
            policy_loss = 0,
            value_loss = 0,
            entropy = 0,
            avg_ratio = 0,
            batch_count = 0
        }
        
        -- Process in batches
        for i = 1, #gameHistory.transitions, batch_size do
            -- Prepare batch
            local batch = self:PrepareBatch(gameHistory.transitions, i, batch_size)
            
            -- Forward passes
            local policy_outputs = CivTransformerPolicy:BatchForward(batch.states, batch.actions)
            local value_outputs = ValueNetwork:BatchForward(batch.states)
            
            -- Compute entropy bonus
            local entropy = self:ComputeEntropyBonus(policy_outputs)
            
            -- Initialize policy gradients
            local policy_grads = {
                action_type_grad = matrix:new(batch_size, #ACTION_TYPES),
                option_grad = matrix:new(batch_size, TRANSFORMER_DIM)
            }
            
            -- Track ratios for this batch
            local all_ratios = matrix:new(batch_size, #ACTION_TYPES)
            
            -- Compute advantage-weighted probability ratios for actions
            local valid_size = math.min(batch_size, #gameHistory.transitions - i + 1)
            for j = 1, valid_size do
                
                print("\nProcessing batch item:", j)
                print("policy_outputs.action_probs[j] type:", type(policy_outputs.action_probs[j]))
                if type(policy_outputs.action_probs[j]) == "table" then
                    print("action_probs length:", #policy_outputs.action_probs[j])
                    print("First few values:", table.concat({unpack(policy_outputs.action_probs[j], 1, math.min(5, #policy_outputs.action_probs[j]))}, ", "))
                end
                print("\nbatch.old_action_probs row type:", type(batch.old_action_probs:row(j)))
                print("old_action_probs dimensions:", batch.old_action_probs:rows(), "x", batch.old_action_probs:columns())   
                    -- Print first few values of the row
                local row_values = {}
                for k = 1, math.min(5, batch.old_action_probs:columns()) do
                    table.insert(row_values, batch.old_action_probs:getelement(j, k))
                end
                print("First few old probs:", table.concat(row_values, ", "))

                -- convert to matrix
                local policyv1 = tableToMatrix(policy_outputs.action_probs[j])
                local policyv2 = tableToMatrix(batch.old_action_probs:row(j))

                local ratio = matrix.elementwise_div(
                    policyv1,
                    policyv2
                )

                -- local ratio = matrix.elementwise_div(
                --     policy_outputs.action_probs[j],
                --     batch.old_action_probs:row(j)
                -- )
                
                -- Store ratios for metrics
                for k = 1, #ACTION_TYPES do
                    all_ratios:setelement(j, k, ratio:getelement(1, k))
                end
                
                -- Clip ratio
                local clipped_ratio = matrix.replace(ratio, function(x)
                    return math.min(math.max(x, 1 - self.clip_epsilon), 1 + self.clip_epsilon)
                end)
                
                -- Get advantage for this sample
                local advantage = batch.advantages:getelement(j, 1)
                
                -- Compute policy gradient
                for k = 1, #ACTION_TYPES do
                    -- Compute surrogate objectives
                    local surrogate1 = ratio:getelement(1, k) * advantage
                    local surrogate2 = clipped_ratio:getelement(1, k) * advantage
                    
                    -- Take minimum of surrogates
                    local policy_grad = -math.min(surrogate1, surrogate2)
                    
                    -- Add entropy gradient
                    local entropy_grad = -self.entropy_coef * 
                        (1.0 + math.log(policy_outputs.action_probs[j][k] + 1e-8))
                    
                    -- Combine gradients
                    policy_grads.action_type_grad:setelement(j, k, policy_grad + entropy_grad)
                end
            end

            local is_valid = ValidateBatchAndOutputs(batch, policy_outputs, batch_size, valid_size)
            if not is_valid then
                print("ERROR: Invalid batch or policy outputs, skipping batch")
            end

            -- Optional: Validate specific probability distributions
            for j = 1, valid_size do
                if not ValidateProbabilityDistribution(policy_outputs.action_probs[j], "Action probabilities batch " .. j) then
                    print("WARNING: Invalid action probability distribution in batch " .. j)
                end
            end
                        
            -- -- Handle option probabilities if present
            -- if policy_outputs.option_probs and batch.old_option_probs then
            --     local option_ratio = matrix.elementwise_div(
            --         policy_outputs.option_probs,
            --         batch.old_option_probs
            --     )
                
            --     -- Clip option ratios and compute gradients similarly to action gradients
            --     local clipped_option_ratio = matrix.replace(option_ratio, function(x)
            --         return math.min(math.max(x, 1 - self.clip_epsilon), 1 + self.clip_epsilon)
            --     end)
                
            --     -- Compute and store option gradients
            --     for j = 1, batch_size do
            --         local advantage = batch.advantages:getelement(j, 1)
            --         for k = 1, TRANSFORMER_DIM do
            --             local surrogate1 = option_ratio:getelement(j, k) * advantage
            --             local surrogate2 = clipped_option_ratio:getelement(j, k) * advantage
            --             policy_grads.option_grad:setelement(j, k, -math.min(surrogate1, surrogate2))
            --         end
            --     end
            -- end
            
            -- -- Compute value loss gradient
            -- local value_loss = matrix.sub(value_outputs, batch.returns)
            -- local value_grad = matrix.mulnum(value_loss, 2.0) -- Derivative of MSE
            
            -- -- Scale gradients by learning rate
            -- policy_grads.action_type_grad = matrix.mulnum(policy_grads.action_type_grad, current_lr)
            -- policy_grads.option_grad = matrix.mulnum(policy_grads.option_grad, current_lr)
            -- value_grad = matrix.mulnum(value_grad, current_lr)
            
            -- -- Backward passes
            -- CivTransformerPolicy:BatchBackward(policy_grads)
            -- ValueNetwork:BatchBackward(value_grad)
            
            -- -- Update epoch metrics
            -- epoch_metrics.policy_loss = epoch_metrics.policy_loss + matrix.mean(policy_grads.action_type_grad)
            -- epoch_metrics.value_loss = epoch_metrics.value_loss + matrix.mean(value_loss)
            -- epoch_metrics.entropy = epoch_metrics.entropy + entropy
            -- epoch_metrics.avg_ratio = epoch_metrics.avg_ratio + matrix.mean(all_ratios)
            -- epoch_metrics.batch_count = epoch_metrics.batch_count + 1
            
            -- -- Print batch progress
            -- print(string.format(
            --     "Batch %d/%d - Policy Loss: %.4f, Value Loss: %.4f, Entropy: %.4f",
            --     math.floor(i/batch_size) + 1,
            --     math.ceil(#gameHistory.transitions/batch_size),
            --     matrix.mean(policy_grads.action_type_grad),
            --     matrix.mean(value_loss),
            --     entropy
            -- ))
            
            -- -- Check for early stopping
            -- if math.abs(matrix.mean(policy_grads.action_type_grad)) < 1e-5 and 
            --    math.abs(matrix.mean(value_loss)) < 1e-5 then
            --     print("Converged - stopping early")
            --     return training_stats
            -- end
        end
        
        -- -- Average epoch metrics
        -- local num_batches = epoch_metrics.batch_count
        -- epoch_metrics.policy_loss = epoch_metrics.policy_loss / num_batches
        -- epoch_metrics.value_loss = epoch_metrics.value_loss / num_batches
        -- epoch_metrics.entropy = epoch_metrics.entropy / num_batches
        -- epoch_metrics.avg_ratio = epoch_metrics.avg_ratio / num_batches
        
        -- -- Store epoch metrics
        -- table.insert(training_stats.policy_losses, epoch_metrics.policy_loss)
        -- table.insert(training_stats.value_losses, epoch_metrics.value_loss)
        -- table.insert(training_stats.entropies, epoch_metrics.entropy)
        -- table.insert(training_stats.ratios, epoch_metrics.avg_ratio)
        
        -- -- Print epoch summary
        -- print(string.format(
        --     "\nEpoch Summary - Policy Loss: %.4f, Value Loss: %.4f, Entropy: %.4f, Avg Ratio: %.4f",
        --     epoch_metrics.policy_loss,
        --     epoch_metrics.value_loss,
        --     epoch_metrics.entropy,
        --     epoch_metrics.avg_ratio
        -- ))
    end
    
    return training_stats
end



return PPOTraining