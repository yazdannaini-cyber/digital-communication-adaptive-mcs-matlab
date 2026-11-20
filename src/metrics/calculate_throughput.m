
function [grossBitRate, estimatedCorrectBitRate] = ...
    calculate_throughput(symbolRate, bitsPerSymbol, ber)

    % =========================================
    % THROUGHPUT CALCULATOR
    % Uncoded Digital Communication System
    % =========================================

    %% Validate Symbol Rate

    if ~isnumeric(symbolRate) || ...
       ~isreal(symbolRate) || ...
       ~isscalar(symbolRate) || ...
       isnan(symbolRate) || ...
       isinf(symbolRate) || ...
       symbolRate <= 0

        error('Symbol rate must be a positive finite scalar.');

    end

    %% Validate Bits per Symbol

    if ~isnumeric(bitsPerSymbol) || ...
       ~isreal(bitsPerSymbol) || ...
       ~isscalar(bitsPerSymbol) || ...
       isnan(bitsPerSymbol) || ...
       isinf(bitsPerSymbol) || ...
       bitsPerSymbol < 1 || ...
       fix(bitsPerSymbol) ~= bitsPerSymbol

        error('bitsPerSymbol must be a positive integer.');

    end

    %% Validate BER

    if ~isnumeric(ber) || ...
       ~isreal(ber) || ...
       ~isscalar(ber) || ...
       isnan(ber) || ...
       isinf(ber) || ...
       ber < 0 || ber > 1

        error('BER must be between 0 and 1.');

    end

    %% Calculate Gross Bit Rate

    grossBitRate = symbolRate * bitsPerSymbol;

    %% Calculate Expected Correct Bit Rate

    estimatedCorrectBitRate = grossBitRate * (1 - ber);

end
