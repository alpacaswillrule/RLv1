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
include("RL_Policy");


-- Create ValueNetwork object
ValueNetwork = {
    initialized = false
}

function ValueNetwork:Init()
    if self.initialized then
        print("ValueNetwork already initialized")
        return
    end

    -- Create value network layers using same dimension as transformer output
    self.d_model = CivTransformerPolicy.d_model -- Access transformer dimensions
    
    -- Value network layers
    self.value_hidden = matrix:new(self.d_model, 256)  -- First value layer
    self.value_hidden2 = matrix:new(256, 64)          -- Second value layer
    self.value_out = matrix:new(64, 1)                -- Final value output
    
    -- Initialize value network weights with Xavier initialization
    local function xavier_init(mtx)
        local n = mtx:rows() + mtx:columns()
        local std = math.sqrt(2.0 / n)
        for i = 1, mtx:rows() do
            for j = 1, mtx:columns() do
                mtx:setelement(i, j, (math.random() * 2 - 1) * std)
            end
        end
        return mtx
    end

    self.value_hidden = xavier_init(self.value_hidden)
    self.value_hidden2 = xavier_init(self.value_hidden2)
    self.value_out = xavier_init(self.value_out)

    -- Add value network biases
    self.value_hidden_bias = matrix:new(1, 256, 0)
    self.value_hidden2_bias = matrix:new(1, 64, 0)
    self.value_out_bias = matrix:new(1, 1, 0)

    self.initialized = true
    print("Initialized Value Network")
end

function ValueNetwork:BackwardPass(grad)
    -- Backward through final layer
    local value_out_grad = grad
    self.value_out:backward(value_out_grad)
    
    -- Backward through hidden layers
    local hidden2_grad = matrix.mul_with_grad(value_out_grad, matrix.transpose(self.value_out))
    self.value_hidden2:backward(hidden2_grad)
    
    local hidden_grad = matrix.mul_with_grad(hidden2_grad, matrix.transpose(self.value_hidden2))
    self.value_hidden:backward(hidden_grad)
    
    return hidden_grad
end


-- Add these methods to ValueNetwork

function ValueNetwork:BatchForward(state_batch)
    print("\nValue Network Batch Forward:")
    print("Batch size:", state_batch:rows())
    
    -- First pass through transformer's state processing pipeline in batch
    local embedded_states = matrix.mul(state_batch, CivTransformerPolicy.state_embedding_weights)
    embedded_states = CivTransformerPolicy:AddPositionalEncoding(embedded_states)
    local encoded_states = CivTransformerPolicy:TransformerEncoder(embedded_states, nil)
    
    -- Process through first hidden layer
    local hidden1 = matrix.mul(encoded_states, self.value_hidden)
    -- Add bias to each sample in batch
    hidden1 = matrix.add(hidden1, matrix.repmat(self.value_hidden_bias, encoded_states:rows(), 1))
    -- Apply ReLU
    hidden1 = matrix.relu(hidden1)
    
    -- Process through second hidden layer
    local hidden2 = matrix.mul(hidden1, self.value_hidden2)
    hidden2 = matrix.add(hidden2, matrix.repmat(self.value_hidden2_bias, hidden1:rows(), 1))
    hidden2 = matrix.relu(hidden2)
    
    -- Final output layer
    local values = matrix.mul(hidden2, self.value_out)
    values = matrix.add(values, matrix.repmat(self.value_out_bias, hidden2:rows(), 1))
    
    -- Cache intermediate values for backward pass
    self.batch_cache = {
        embedded_states = embedded_states,
        encoded_states = encoded_states,
        hidden1 = hidden1,
        hidden2 = hidden2,
        values = values
    }
    
    -- Return matrix of values (one per state in batch)
    return values
end

function ValueNetwork:BatchBackward(value_grads)
    print("\nValue Network Batch Backward:")
    
    if not self.batch_cache then
        print("ERROR: No batch cache found. Run BatchForward first.")
        return
    end
    
    local batch_size = value_grads:rows()
    print("Batch size:", batch_size)
    
    -- 1. Backward through output layer
    local d_hidden2 = matrix.mul_with_grad(value_grads, matrix.transpose(self.value_out))
    -- Compute output layer gradients
    local out_weight_grad = matrix.mul_with_grad(
        matrix.transpose(self.batch_cache.hidden2),
        value_grads
    )
    local out_bias_grad = matrix.sum(value_grads, 1)
    
    -- Update output layer weights and bias
    for i = 1, self.value_out:rows() do
        for j = 1, self.value_out:columns() do
            local current_weight = self.value_out:getelement(i, j)
            local grad = out_weight_grad:getelement(i, j)
            self.value_out:setelement(i, j, 
                current_weight - self.learning_rate * grad)
        end
    end
    
    -- Update output bias
    for j = 1, self.value_out_bias:columns() do
        local current_bias = self.value_out_bias:getelement(1, j)
        local grad = out_bias_grad:getelement(1, j)
        self.value_out_bias:setelement(1, j, 
            current_bias - self.learning_rate * grad)
    end
    
    -- 2. Backward through second hidden layer
    -- Apply ReLU gradient
    d_hidden2 = matrix.replace(d_hidden2, function(x, i, j)
        return self.batch_cache.hidden2:getelement(i, j) > 0 and x or 0
    end)
    -- Compute gradients for first hidden layer
    local d_hidden1 = matrix.mul_with_grad(d_hidden2, matrix.transpose(self.value_hidden2))
    -- Compute second hidden layer weight gradients
    local hidden2_weight_grad = matrix.mul_with_grad(
        matrix.transpose(self.batch_cache.hidden1),
        d_hidden2
    )
    local hidden2_bias_grad = matrix.sum(d_hidden2, 1)
    
    -- Update second hidden layer weights
    for i = 1, self.value_hidden2:rows() do
        for j = 1, self.value_hidden2:columns() do
            local current_weight = self.value_hidden2:getelement(i, j)
            local grad = hidden2_weight_grad:getelement(i, j)
            self.value_hidden2:setelement(i, j, 
                current_weight - self.learning_rate * grad)
        end
    end
    
    -- Update second hidden layer bias
    for j = 1, self.value_hidden2_bias:columns() do
        local current_bias = self.value_hidden2_bias:getelement(1, j)
        local grad = hidden2_bias_grad:getelement(1, j)
        self.value_hidden2_bias:setelement(1, j, 
            current_bias - self.learning_rate * grad)
    end
    
    -- 3. Backward through first hidden layer
    -- Apply ReLU gradient
    d_hidden1 = matrix.replace(d_hidden1, function(x, i, j)
        return self.batch_cache.hidden1:getelement(i, j) > 0 and x or 0
    end)
    -- Compute gradient for encoded states
    local d_encoded = matrix.mul_with_grad(d_hidden1, matrix.transpose(self.value_hidden))
    -- Compute first hidden layer weight gradients
    local hidden1_weight_grad = matrix.mul_with_grad(
        matrix.transpose(self.batch_cache.encoded_states),
        d_hidden1
    )
    local hidden1_bias_grad = matrix.sum(d_hidden1, 1)
    
    -- Update first hidden layer weights
    for i = 1, self.value_hidden:rows() do
        for j = 1, self.value_hidden:columns() do
            local current_weight = self.value_hidden:getelement(i, j)
            local grad = hidden1_weight_grad:getelement(i, j)
            self.value_hidden:setelement(i, j, 
                current_weight - self.learning_rate * grad)
        end
    end
    
    -- Update first hidden layer bias
    for j = 1, self.value_hidden_bias:columns() do
        local current_bias = self.value_hidden_bias:getelement(1, j)
        local grad = hidden1_bias_grad:getelement(1, j)
        self.value_hidden_bias:setelement(1, j, 
            current_bias - self.learning_rate * grad)
    end
    
    -- Clear cache
    self.batch_cache = nil
    
    -- Return gradient for encoded states (needed for transformer backward pass)
    return d_encoded
end

-- Add batch processing for value estimation
function ValueNetwork:GetValueBatch(states)
    -- Process all states into a single batch matrix
    local batch_mtx = matrix:new(#states, CivTransformerPolicy.d_model)
    for i, state in ipairs(states) do
        local state_encoding = CivTransformerPolicy:ProcessGameState(state)
        for j = 1, CivTransformerPolicy.d_model do
            batch_mtx:setelement(i, j, state_encoding:getelement(1, j))
        end
    end
    
    -- Forward pass through batch
    local value_batch = self:BatchForward(batch_mtx)
    
    -- Extract individual values
    local values = {}
    for i = 1, value_batch:rows() do
        table.insert(values, value_batch:getelement(i, 1))
    end
    
    return values
end

-- Helper function to check states in batch
function ValueNetwork:ValidateStateBatch(states)
    if #states == 0 then
        print("ERROR: Empty state batch")
        return false
    end
    
    -- Check first state dimensions
    local first_state = states[1]
    if not first_state or not first_state.size then
        print("ERROR: Invalid state format")
        return false
    end
    
    local expected_dims = {1, CivTransformerPolicy.d_model}
    local state_dims = first_state:size()
    
    if state_dims[1] ~= expected_dims[1] or state_dims[2] ~= expected_dims[2] then
        print(string.format("ERROR: State dimension mismatch. Expected %dx%d, got %dx%d",
            expected_dims[1], expected_dims[2], state_dims[1], state_dims[2]))
        return false
    end
    
    -- Check remaining states
    for i = 2, #states do
        local dims = states[i]:size()
        if dims[1] ~= expected_dims[1] or dims[2] ~= expected_dims[2] then
            print(string.format("ERROR: State %d dimension mismatch", i))
            return false
        end
    end
    
    return true
end



function ValueNetwork:zero_grad()
    -- Check if network is initialized
    if not self.initialized then
        print("WARNING: Attempting to zero gradients on uninitialized network")
        return
    end
    
    -- Zero gradients for main network weights with null checks
    if self.value_hidden then
        self.value_hidden:zero_grad()
    end
    if self.value_hidden2 then
        self.value_hidden2:zero_grad()
    end
    if self.value_out then
        self.value_out:zero_grad()
    end
    
    -- Zero gradients for biases with null checks
    if self.value_hidden_bias then
        self.value_hidden_bias:zero_grad()
    end
    if self.value_hidden2_bias then
        self.value_hidden2_bias:zero_grad()
    end
    if self.value_out_bias then
        self.value_out_bias:zero_grad()
    end
end

-- Helper method to check if matrix requires gradient
function matrix:requires_gradient()
    return self.requires_grad == true
end

function ValueNetwork:UpdateParams(learning_rate)
    self.value_out:update_weights(learning_rate)
    self.value_hidden2:update_weights(learning_rate)
    self.value_hidden:update_weights(learning_rate)
end

function ValueNetwork:Forward(state_encoding)
    -- Ensure we have a matrix
    local state_mtx = type(state_encoding.getelement) == "function" and 
                     state_encoding or 
                     tableToMatrix({state_encoding})
    
    -- First pass through transformer's state processing pipeline
    local embedded_state = matrix.mul(state_mtx, CivTransformerPolicy.state_embedding_weights)
    embedded_state = CivTransformerPolicy:AddPositionalEncoding(embedded_state)
    local encoded_state = CivTransformerPolicy:TransformerEncoder(embedded_state, nil)
    
    -- Now process through value network layers with ReLU activations
    local hidden = matrix.relu(matrix.add(
        matrix.mul(encoded_state, self.value_hidden),
        matrix.repmat(self.value_hidden_bias, encoded_state:rows(), 1)
    ))
    
    local hidden2 = matrix.relu(matrix.add(
        matrix.mul(hidden, self.value_hidden2),
        matrix.repmat(self.value_hidden2_bias, hidden:rows(), 1)
    ))
    
    -- Final value output
    local value = matrix.add(
        matrix.mul(hidden2, self.value_out),
        matrix.repmat(self.value_out_bias, hidden2:rows(), 1)
    )
    
    return value:getelement(1, 1)  -- Return scalar value
end

-- Get value estimate for a game state
function ValueNetwork:GetValue(state)
    -- Use CivTransformerPolicy's state processing 
    local state_encoding = CivTransformerPolicy:ProcessGameState(state)
    return self:Forward(state_encoding)
end

-- -- Batch processing for multiple states (useful during training)
-- function ValueNetwork:GetValueBatch(states)
--     local values = {}
--     for _, state in ipairs(states) do
--         table.insert(values, self:GetValue(state))
--     end
--     return values
-- end


function ValueNetwork:LoadWeights(identifier)
    local weights = Read_tableString("value_weights_" .. identifier)
    if not weights then return false end
    
    self.value_hidden = tableToMatrix(weights.value_hidden)
    self.value_hidden2 = tableToMatrix(weights.value_hidden2)
    self.value_out = tableToMatrix(weights.value_out)
    self.value_hidden_bias = tableToMatrix(weights.value_hidden_bias)
    self.value_hidden2_bias = tableToMatrix(weights.value_hidden2_bias)
    self.value_out_bias = tableToMatrix(weights.value_out_bias)
    
    return true
end


function ValueNetwork:SaveWeights(identifier)
    local weights = {
        value_hidden = matrixToTable(self.value_hidden),
        value_hidden2 = matrixToTable(self.value_hidden2),
        value_out = matrixToTable(self.value_out),
        value_hidden_bias = matrixToTable(self.value_hidden_bias),
        value_hidden2_bias = matrixToTable(self.value_hidden2_bias),
        value_out_bias = matrixToTable(self.value_out_bias)
    }
    
    Storage_table(weights, "value_weights_" .. identifier)
end




return ValueNetwork
