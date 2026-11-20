
function [ser, numSymbolErrors] = ...
    calculate_ser(txBits, rxBits, bitsPerSymbol)

    % =========================================
    % SYMBOL ERROR RATE CALCULATOR
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

        error('Input vectors must have equal lengths.');

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

    if mod(numel(txBits), bitsPerSymbol) ~= 0

        error('Number of bits must be divisible by bitsPerSymbol.');

    end

    %% Convert Inputs to Column Vectors

    txBits = double(txBits(:));

    rxBits = double(rxBits(:));

    %% Group Bits into Symbols

    txMatrix = reshape(txBits, bitsPerSymbol, []);

    rxMatrix = reshape(rxBits, bitsPerSymbol, []);

    %% Detect Symbol Errors

    symbolErrorVector = any(txMatrix ~= rxMatrix, 1);

    numSymbolErrors = sum(symbolErrorVector);

    %% Calculate SER

    numSymbols = size(txMatrix, 2);

    ser = numSymbolErrors / numSymbols;

end
