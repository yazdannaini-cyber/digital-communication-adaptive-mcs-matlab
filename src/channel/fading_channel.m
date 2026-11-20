
function [rxSymbols, h, noise, noiseVariance] = ...
    fading_channel(txSymbols, EbN0_dB, ...
                   bitsPerSymbol, symbolEnergy, ...
                   channelType, K_dB)

    % =========================================
    % FLAT FADING CHANNEL
    %
    % Supported models:
    % 1. Rayleigh
    % 2. Rician
    %
    % Average channel power = 1
    % Perfect CSI is assumed at the receiver
    % =========================================

    %% 1. Default Parameters

    if nargin < 5 || isempty(channelType)
        channelType = 'Rayleigh';
    end

    if nargin < 6 || isempty(K_dB)
        K_dB = 6;
    end

    %% 2. Validate Transmitted Symbols

    if ~isnumeric(txSymbols) || ...
       isempty(txSymbols) || ...
       ~isvector(txSymbols)

        error('Transmit symbols must be a non-empty numeric vector.');

    end

    if any(~isfinite(real(txSymbols(:)))) || ...
       any(~isfinite(imag(txSymbols(:))))

        error('Transmit symbols must contain finite values.');

    end

    %% 3. Validate Channel Type

    if ~(ischar(channelType) || ...
         (isstring(channelType) && isscalar(channelType)))

        error('Channel type must be Rayleigh or Rician.');

    end

    channelType = lower(strtrim(char(channelType)));

    if ~strcmp(channelType,'rayleigh') && ...
       ~strcmp(channelType,'rician')

        error('Unsupported channel type.');

    end

    %% 4. Validate Eb/N0

    if ~isnumeric(EbN0_dB) || ...
       ~isreal(EbN0_dB) || ...
       ~isscalar(EbN0_dB) || ...
       ~isfinite(EbN0_dB)

        error('EbN0_dB must be a finite real scalar.');

    end

    %% 5. Validate Bits per Symbol

    if ~isnumeric(bitsPerSymbol) || ...
       ~isreal(bitsPerSymbol) || ...
       ~isscalar(bitsPerSymbol) || ...
       ~isfinite(bitsPerSymbol) || ...
       bitsPerSymbol < 1 || ...
       fix(bitsPerSymbol) ~= bitsPerSymbol

        error('bitsPerSymbol must be a positive integer.');

    end

    %% 6. Validate Symbol Energy

    if ~isnumeric(symbolEnergy) || ...
       ~isreal(symbolEnergy) || ...
       ~isscalar(symbolEnergy) || ...
       ~isfinite(symbolEnergy) || ...
       symbolEnergy <= 0

        error('symbolEnergy must be positive and finite.');

    end

    %% 7. Validate Rician K-factor

    if ~isnumeric(K_dB) || ...
       ~isreal(K_dB) || ...
       ~isscalar(K_dB) || ...
       ~isfinite(K_dB)

        error('K_dB must be a finite real scalar.');

    end

    %% 8. Generate Channel Coefficients

    switch channelType

        case 'rayleigh'

            % Zero-mean circularly symmetric
            % complex Gaussian channel

            h = (randn(size(txSymbols)) + ...
                 1i*randn(size(txSymbols))) / sqrt(2);

        case 'rician'

            K_linear = 10^(K_dB/10);

            % LOS component with zero phase

            hLOS = sqrt(K_linear/(K_linear+1));

            % Scattered component

            hScatter = (randn(size(txSymbols)) + ...
                        1i*randn(size(txSymbols))) / sqrt(2);

            h = hLOS + ...
                sqrt(1/(K_linear+1))*hScatter;

    end

    %% 9. Calculate Noise Variance per Dimension

    EbN0_linear = 10^(EbN0_dB/10);

    if ~isfinite(EbN0_linear) || EbN0_linear <= 0
        error('EbN0 is outside the supported numerical range.');
    end

    noiseVariance = ...
        symbolEnergy / ...
        (2*bitsPerSymbol*EbN0_linear);

    %% 10. Generate Complex AWGN

    noise = sqrt(noiseVariance) * ...
        (randn(size(txSymbols)) + ...
         1i*randn(size(txSymbols)));

    %% 11. Apply Fading and Noise

    rxSymbols = h .* txSymbols + noise;

end
