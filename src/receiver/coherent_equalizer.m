
function equalizedSymbols = ...
    coherent_equalizer(rxSymbols,channelCoefficients)

    % =========================================
    % COHERENT EQUALIZER
    % Supports:
    % - One scalar channel coefficient
    % - One channel coefficient per sample
    % =========================================

    %% Validate Numeric Inputs

    if ~isnumeric(rxSymbols) || ...
       ~isnumeric(channelCoefficients)

        error('Inputs must be numeric.');

    end

    %% Validate Received Signal

    if isempty(rxSymbols) || ~isvector(rxSymbols)

        error('Received signal must be a non-empty vector.');

    end

    if any(~isfinite(real(rxSymbols(:)))) || ...
       any(~isfinite(imag(rxSymbols(:))))

        error('Received signal must be finite.');

    end

    %% Validate Channel Coefficients

    if isempty(channelCoefficients) || ...
       ~(isscalar(channelCoefficients) || ...
         numel(channelCoefficients)==numel(rxSymbols))

        error('Channel coefficient size is invalid.');

    end

    if any(~isfinite(real(channelCoefficients(:)))) || ...
       any(~isfinite(imag(channelCoefficients(:))))

        error('Channel coefficients must be finite.');

    end

    %% Reject Zero Channel Coefficients

    if any(channelCoefficients(:)==0)

        error('Channel coefficient cannot be zero.');

    end

    %% Equalization

    if isscalar(channelCoefficients)

        equalizedSymbols = rxSymbols./channelCoefficients;

    else

        channelCoefficients = ...
            reshape(channelCoefficients,size(rxSymbols));

        equalizedSymbols = ...
            rxSymbols./channelCoefficients;

    end

end
