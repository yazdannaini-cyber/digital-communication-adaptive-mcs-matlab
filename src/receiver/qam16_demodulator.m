
function rxBits = qam16_demodulator(rxSymbols)

    % =========================================
    % 16-QAM HARD-DECISION DEMODULATOR
    % Gray Mapping
    % =========================================

    %% 1. Validate Input Type

    if ~isnumeric(rxSymbols)

        error('Input must be numeric.');

    end

    %% 2. Validate Dimensions

    if isempty(rxSymbols) || ~isvector(rxSymbols)

        error('Input must be a non-empty vector.');

    end

    %% 3. Validate Finite Values

    if any(isnan(real(rxSymbols(:)))) || ...
       any(isinf(real(rxSymbols(:)))) || ...
       any(isnan(imag(rxSymbols(:)))) || ...
       any(isinf(imag(rxSymbols(:))))

        error('Input must contain finite complex samples.');

    end

    %% 4. Convert to Row Vector

    rxSymbols = rxSymbols(:).';

    %% 5. Recover Unnormalized I and Q Coordinates

    I = sqrt(10) * real(rxSymbols);

    Q = sqrt(10) * imag(rxSymbols);

    %% 6. I-Axis Decisions

    bI1 = double(I < 0);

    bI2 = double(abs(I) < 2);

    %% 7. Q-Axis Decisions

    bQ1 = double(Q < 0);

    bQ2 = double(abs(Q) < 2);

    %% 8. Reconstruct Original Bit Order

    rxBits = zeros(1, 4*numel(rxSymbols));

    rxBits(1:4:end) = bI1;

    rxBits(2:4:end) = bI2;

    rxBits(3:4:end) = bQ1;

    rxBits(4:4:end) = bQ2;

end
