
function [ber, numErrors] = calculate_ber(txBits, rxBits)

    % =========================================
    % BIT ERROR RATE CALCULATOR
    % =========================================

    %% Validate Input Types

    if ~(isnumeric(txBits) || islogical(txBits)) || ...
       ~(isnumeric(rxBits) || islogical(rxBits))

        error('Inputs must be numeric or logical.');

    end

    %% Validate Dimensions

    if isempty(txBits) || isempty(rxBits) || ...
       ~isvector(txBits) || ~isvector(rxBits)

        error('Inputs must be non-empty vectors.');

    end

    %% Validate Finite Real Values

    if ~isreal(txBits) || ~isreal(rxBits) || ...
       any(isnan(txBits(:))) || any(isinf(txBits(:))) || ...
       any(isnan(rxBits(:))) || any(isinf(rxBits(:)))

        error('Inputs must contain finite real values.');

    end

    %% Validate Binary Values

    if any(txBits(:) ~= 0 & txBits(:) ~= 1) || ...
       any(rxBits(:) ~= 0 & rxBits(:) ~= 1)

        error('Inputs must contain binary values only.');

    end

    %% Validate Equal Length

    if numel(txBits) ~= numel(rxBits)

        error('Transmitted and received bit vectors must have equal lengths.');

    end

    %% Calculate Bit Errors

    txBits = double(txBits(:));
    rxBits = double(rxBits(:));

    errorVector = (txBits ~= rxBits);

    numErrors = sum(errorVector);

    %% Calculate BER

    ber = numErrors / numel(txBits);

end
