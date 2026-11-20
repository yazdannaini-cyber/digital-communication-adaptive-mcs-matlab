
function spectralEfficiency = ...
    calculate_spectral_efficiency(bitsPerSymbol, rolloff)

    % =========================================
    % SPECTRAL EFFICIENCY CALCULATOR
    % Raised-Cosine Bandwidth Assumption
    % =========================================

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

    %% Validate Roll-off Factor

    if ~isnumeric(rolloff) || ...
       ~isreal(rolloff) || ...
       ~isscalar(rolloff) || ...
       isnan(rolloff) || ...
       isinf(rolloff) || ...
       rolloff < 0 || rolloff > 1

        error('Roll-off factor must be between 0 and 1.');

    end

    %% Calculate Spectral Efficiency

    spectralEfficiency = bitsPerSymbol / (1 + rolloff);

end
