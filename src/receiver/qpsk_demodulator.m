
function rxBits = qpsk_demodulator(rxSymbols)

    % =========================================
    % QPSK HARD-DECISION DEMODULATOR
    % Gray-Mapped QPSK
    % =========================================

    %% 1. Validate Input Type

    if ~isnumeric(rxSymbols)

        error('Input must be numeric.');

    end

    %% 2. Validate Input Dimensions

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

    %% 5. Make Decisions on I and Q Components

    detectedI = double(real(rxSymbols) < 0);

    detectedQ = double(imag(rxSymbols) < 0);

    %% 6. Reconstruct Original Bit Order

    rxBits = zeros(1, 2*numel(rxSymbols));

    rxBits(1:2:end) = detectedI;

    rxBits(2:2:end) = detectedQ;

end
