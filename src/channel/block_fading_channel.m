
function [rxSymbols,noise,noiseVariance] = ...
    block_fading_channel(txSymbols,h,EsN0_dB,symbolEnergy)

    % =========================================
    % BLOCK FADING CHANNEL
    % Constant channel coefficient over one block
    % Complex AWGN
    % =========================================

    %% Default Symbol Energy

    if nargin < 4 || isempty(symbolEnergy)

        symbolEnergy = 1;

    end

    %% Validate Signal

    if ~isnumeric(txSymbols) || ...
       isempty(txSymbols) || ...
       ~isvector(txSymbols) || ...
       any(~isfinite(real(txSymbols(:)))) || ...
       any(~isfinite(imag(txSymbols(:))))

        error('Invalid transmit symbols.');

    end

    %% Validate Channel Coefficient

    if ~isnumeric(h) || ...
       ~isscalar(h) || ...
       ~isfinite(real(h)) || ...
       ~isfinite(imag(h))

        error('Channel coefficient must be finite scalar.');

    end

    %% Validate Symbol SNR

    if ~isnumeric(EsN0_dB) || ...
       ~isreal(EsN0_dB) || ...
       ~isscalar(EsN0_dB) || ...
       ~isfinite(EsN0_dB)

        error('EsN0_dB must be a finite real scalar.');

    end

    %% Validate Symbol Energy

    if ~isnumeric(symbolEnergy) || ...
       ~isreal(symbolEnergy) || ...
       ~isscalar(symbolEnergy) || ...
       ~isfinite(symbolEnergy) || ...
       symbolEnergy <= 0

        error('Symbol energy must be positive and finite.');

    end

    %% Convert Es/N0 to Linear Scale

    gammaEs = 10^(EsN0_dB/10);

    if ~isfinite(gammaEs) || gammaEs <= 0

        error('EsN0 outside supported numerical range.');

    end

    %% Noise Variance per Real Dimension

    noiseVariance = symbolEnergy/(2*gammaEs);

    %% Generate Complex AWGN

    noise = sqrt(noiseVariance) * ...
        (randn(size(txSymbols)) + ...
         1i*randn(size(txSymbols)));

    %% Apply Block Fading and Noise

    rxSymbols = h.*txSymbols + noise;

end
