
function symbols = qpsk_modulator(bits)

    % =========================================
    % QPSK MODULATOR - GRAY MAPPING
    %
    % 00 -> (+1 + j)/sqrt(2)
    % 01 -> (+1 - j)/sqrt(2)
    % 10 -> (-1 + j)/sqrt(2)
    % 11 -> (-1 - j)/sqrt(2)
    % =========================================

    %% 1. Validate Input Type

    if ~(isnumeric(bits) || islogical(bits))

        error('Input must be numeric or logical.');

    end

    %% 2. Validate Input Dimensions

    if isempty(bits) || ~isvector(bits)

        error('Input must be a non-empty vector.');

    end

    %% 3. Convert to Row Vector

    bits = double(bits(:).');

    %% 4. Validate Binary Values

    if any(isnan(bits) | isinf(bits)) || ...
       any(bits ~= 0 & bits ~= 1)

        error('Input must contain binary values only.');

    end

    %% 5. Validate Even Number of Bits

    if mod(numel(bits), 2) ~= 0

        error('QPSK requires an even number of input bits.');

    end

    %% 6. Separate I and Q Bits

    bI = bits(1:2:end);

    bQ = bits(2:2:end);

    %% 7. Gray-Mapped QPSK Modulation

    I = 1 - 2*bI;

    Q = 1 - 2*bQ;

    symbols = (I + 1i*Q) / sqrt(2);

end
