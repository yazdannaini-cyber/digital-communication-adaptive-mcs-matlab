
function symbols = qam16_modulator(bits)

    % =========================================
    % 16-QAM MODULATOR
    % Gray Mapping
    % Unit Average Symbol Energy
    %
    % I-axis:
    % 00 -> +3
    % 01 -> +1
    % 11 -> -1
    % 10 -> -3
    %
    % Q-axis: Same mapping
    % =========================================

    %% 1. Validate Input Type

    if ~(isnumeric(bits) || islogical(bits))

        error('Input must be numeric or logical.');

    end

    %% 2. Validate Dimensions

    if isempty(bits) || ~isvector(bits)

        error('Input must be a non-empty vector.');

    end

    %% 3. Validate Real and Finite Input

    if ~isreal(bits) || ...
       any(isnan(bits(:))) || ...
       any(isinf(bits(:)))

        error('Input bits must be finite real values.');

    end

    %% 4. Convert to Row Vector

    bits = double(bits(:).');

    %% 5. Validate Binary Values

    if any(bits ~= 0 & bits ~= 1)

        error('Input must contain binary values only.');

    end

    %% 6. Validate Number of Bits

    if mod(numel(bits), 4) ~= 0

        error('16-QAM requires a multiple of four input bits.');

    end

    %% 7. Separate I and Q Bit Pairs

    bI1 = bits(1:4:end);

    bI2 = bits(2:4:end);

    bQ1 = bits(3:4:end);

    bQ2 = bits(4:4:end);

    %% 8. Gray Mapping

    I = (1 - 2*bI1) .* (3 - 2*bI2);

    Q = (1 - 2*bQ1) .* (3 - 2*bQ2);

    %% 9. Unit Energy Normalization

    symbols = (I + 1i*Q) / sqrt(10);

end
