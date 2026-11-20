
function rxBits = bpsk_demodulator(rxSymbols)

    % =========================================
    % BPSK HARD-DECISION DEMODULATOR
    % Supports real and complex input samples
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

    if any(~isfinite(real(rxSymbols(:)))) || ...
       any(~isfinite(imag(rxSymbols(:))))

        error('Input must contain finite samples.');

    end

    %% 4. Hard Decision on Real Component

    rxBits = double(real(rxSymbols) < 0);

end
