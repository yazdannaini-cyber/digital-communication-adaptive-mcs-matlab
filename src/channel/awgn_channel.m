
function [rxSymbols, noise, noiseVariance] = ...
    awgn_channel(txSymbols, EbN0_dB, bitsPerSymbol, symbolEnergy)

    % =========================================
    % GENERAL AWGN CHANNEL
    %
    % Supports:
    % - Real-valued BPSK
    % - Complex-valued QPSK
    % - Unit-average-energy constellations
    %
    % noiseVariance = variance per real dimension
    % =========================================

    %% 1. Default Parameters

    if nargin < 3 || isempty(bitsPerSymbol)

        bitsPerSymbol = 1;

    end

    if nargin < 4 || isempty(symbolEnergy)

        symbolEnergy = 1;

    end

    %% 2. Validate Transmitted Symbols

    if ~isnumeric(txSymbols) || ...
       isempty(txSymbols) || ...
       ~isvector(txSymbols)

        error('Transmit symbols must be a non-empty numeric vector.');

    end

    if any(isnan(real(txSymbols(:)))) || ...
       any(isinf(real(txSymbols(:)))) || ...
       any(isnan(imag(txSymbols(:)))) || ...
       any(isinf(imag(txSymbols(:))))

        error('Transmit symbols must contain finite values.');

    end

    %% 3. Validate Eb/N0

    if ~isnumeric(EbN0_dB) || ...
       ~isreal(EbN0_dB) || ...
       ~isscalar(EbN0_dB) || ...
       isnan(EbN0_dB) || ...
       isinf(EbN0_dB)

        error('EbN0_dB must be a finite real scalar.');

    end

    %% 4. Validate Bits per Symbol

    if ~isnumeric(bitsPerSymbol) || ...
       ~isreal(bitsPerSymbol) || ...
       ~isscalar(bitsPerSymbol) || ...
       isnan(bitsPerSymbol) || ...
       isinf(bitsPerSymbol) || ...
       bitsPerSymbol < 1 || ...
       fix(bitsPerSymbol) ~= bitsPerSymbol

        error('bitsPerSymbol must be a positive integer.');

    end

    %% 5. Validate Symbol Energy

    if ~isnumeric(symbolEnergy) || ...
       ~isreal(symbolEnergy) || ...
       ~isscalar(symbolEnergy) || ...
       isnan(symbolEnergy) || ...
       isinf(symbolEnergy) || ...
       symbolEnergy <= 0

        error('symbolEnergy must be a positive finite scalar.');

    end

    %% 6. Convert Eb/N0 from dB to Linear

    EbN0_linear = 10^(EbN0_dB / 10);

    if isinf(EbN0_linear) || EbN0_linear <= 0

        error('EbN0 value is outside the supported numerical range.');

    end

    %% 7. Calculate Noise Variance per Dimension

    noiseVariance = ...
        symbolEnergy / (2 * bitsPerSymbol * EbN0_linear);

    %% 8. Generate Noise

    if isreal(txSymbols)

        % Real-valued AWGN

        noise = sqrt(noiseVariance) * ...
            randn(size(txSymbols));

    else

        % Complex-valued AWGN

        noise = sqrt(noiseVariance) * ...
            (randn(size(txSymbols)) + ...
             1i*randn(size(txSymbols)));

    end

    %% 9. Add Noise to Signal

    rxSymbols = txSymbols + noise;

end
