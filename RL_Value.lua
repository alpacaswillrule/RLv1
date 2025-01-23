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
    
    -- Apply value network layers with ReLU activations
    local hidden = matrix.relu(matrix.add(
        matrix.mul(state_mtx, self.value_hidden),
        matrix.repmat(self.value_hidden_bias, state_mtx:rows(), 1)
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
    -- Get transformer encoding (without action decoding)
    local embedded_state = matrix.mul(state_encoding, CivTransformerPolicy.state_embedding_weights)
    local encoded_state = CivTransformerPolicy:TransformerEncoder(embedded_state, nil)
    
    return self:Forward(encoded_state)
end

-- Batch processing for multiple states (useful during training)
function ValueNetwork:GetValueBatch(states)
    local values = {}
    for _, state in ipairs(states) do
        table.insert(values, self:GetValue(state))
    end
    return values
end

return ValueNetwork