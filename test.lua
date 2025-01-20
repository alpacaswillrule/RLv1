-- ... (Previous code: Encoding functions, Attention, MultiHeadAttention, etc.)

-- 4. Feedforward Neural Network
function CivTransformerPolicy:Feedforward(input)
    -- Convert input table to matrix
    local input_mtx = tableToMatrix(input)

    -- Define dimensions
    local d_model = input_mtx:size()[2] -- Number of columns (embedding dimension)
    local d_ff = 2048  -- Hidden dimension of the feedforward network (can be a hyperparameter)

    -- Initialize weights and biases for the two linear layers (randomly for now)
    -- In a real implementation, these would be learned parameters
    local w1 = matrix.random(matrix:new(d_model, d_ff))
    local b1 = matrix.random(matrix:new(1, d_ff))
    local w2 = matrix.random(matrix:new(d_ff, d_model))
    local b2 = matrix.random(matrix:new(1, d_model))

    -- First linear layer + ReLU activation
    local layer1_output = matrix.add(matrix.mul(input_mtx, w1), matrix.repmat(b1, input_mtx:size()[1], 1)) -- Broadcasting b1
    layer1_output = matrix.relu(layer1_output)

    -- Second linear layer
    local layer2_output = matrix.add(matrix.mul(layer1_output, w2), matrix.repmat(b2, input_mtx:size()[1], 1)) -- Broadcasting b2
    
    -- Convert the output matrix back to a table
    local output_tbl = matrixToTable(layer2_output)

    return output_tbl
end

-- Helper function for layer normalization (simplified for now)
function CivTransformerPolicy:LayerNorm(input_mtx)
    local epsilon = 1e-6 -- Small constant for numerical stability

    -- Calculate the mean and variance for each row in the matrix
    local means = {}
    local variances = {}
    for i = 1, input_mtx:rows() do
        local sum = 0
        local sum_sq = 0
        for j = 1, input_mtx:columns() do
            local val = input_mtx:getelement(i, j)
            sum = sum + val
            sum_sq = sum_sq + val * val
        end
        table.insert(means, sum / input_mtx:columns())
        table.insert(variances, sum_sq / input_mtx:columns() - means[i] * means[i])
    end

    -- Normalize the matrix
    local normalized_mtx = matrix:new(input_mtx:rows(), input_mtx:columns())
    for i = 1, input_mtx:rows() do
        for j = 1, input_mtx:columns() do
            normalized_mtx:setelement(i, j, (input_mtx:getelement(i, j) - means[i]) / math.sqrt(variances[i] + epsilon))
        end
    end

    return normalized_mtx
end

-- 5. Transformer Layer (Complete with Feedforward, Residual Connections, and Layer Normalization)
function CivTransformerPolicy:TransformerLayer(input, mask)
    -- Convert input table to matrix
    local input_mtx = tableToMatrix(input)

    -- Multi-Head Self-Attention
    local attention_output = self:MultiHeadAttention(input_mtx, input_mtx, input_mtx, mask, TRANSFORMER_HEADS)

    -- Add & Norm (Residual Connection and Layer Normalization)
    local add_norm_output_1 = self:LayerNorm(matrix.add(input_mtx, attention_output))

    -- Feedforward Network
    local ff_output_tbl = self:Feedforward(matrixToTable(add_norm_output_1)) 
    local ff_output_mtx = tableToMatrix(ff_output_tbl)

    -- Add & Norm (Residual Connection and Layer Normalization)
    local add_norm_output_2 = self:LayerNorm(matrix.add(add_norm_output_1, ff_output_mtx))

    -- Convert the output matrix back to a table
    local output_tbl = matrixToTable(add_norm_output_2)

    return output_tbl
end

-- 6. Transformer Encoder (Updated to use the complete TransformerLayer)
function CivTransformerPolicy:TransformerEncoder(input, mask)
    local encoder_output = input
    for i = 1, TRANSFORMER_LAYERS do
        encoder_output = self:TransformerLayer(encoder_output, mask)
    end
    return encoder_output
end