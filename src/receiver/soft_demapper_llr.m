
function llr = soft_demapper_llr(rxSymbols, modulation, noiseVariance)
%SOFT_DEMAPPER_LLR Soft demapper for BPSK, QPSK and 16-QAM.
%
% Inputs:
%   rxSymbols     : Equalized complex received symbols.
%   modulation    : BPSK, QPSK or 16QAM.
%   noiseVariance : Complex noise variance E[|n|^2].
%                   Can be a positive scalar or one value per symbol.
%
% Output:
%   llr : Column vector of bit LLRs in transmitted bit order.
%
% Convention:
%   LLR > 0 favors bit 0.
%   LLR < 0 favors bit 1.
%
% Assumption:
%   rxSymbols are already equalized.
%   noiseVariance describes the complex noise variance after
%   equalization, not the variance before the fading channel.

    %% Validate received symbols

    if ~isnumeric(rxSymbols) || ...
            ~isvector(rxSymbols) || isempty(rxSymbols)

        error('rxSymbols must be a non-empty numeric vector.');

    end

    if any(~isfinite(real(rxSymbols(:)))) || ...
            any(~isfinite(imag(rxSymbols(:))))

        error('rxSymbols must contain finite values.');

    end

    rx = double(rxSymbols(:));

    %% Obtain constellation

    [constellation, bitLabels] = ...
        get_modulation_constellation(modulation);

    constellation = constellation(:);

    M = numel(constellation);

    bitsPerSymbol = size(bitLabels, 2);

    numSymbols = numel(rx);

    %% Validate noise variance

    if ~isnumeric(noiseVariance) || ...
            ~isreal(noiseVariance) || isempty(noiseVariance)

        error('noiseVariance must be a positive real scalar or vector.');

    end

    noiseVariance = double(noiseVariance(:));

    if any(~isfinite(noiseVariance)) || ...
            any(noiseVariance <= 0)

        error('All noise variance values must be positive and finite.');

    end

    if isscalar(noiseVariance)

        noiseVariance = repmat(noiseVariance, numSymbols, 1);

    elseif numel(noiseVariance) ~= numSymbols

        error('Noise variance vector must have one value per symbol.');

    end

    %% Calculate squared Euclidean distances

    % Each row corresponds to one received symbol.
    % Each column corresponds to one constellation point.

    distanceSquared = abs( ...
        bsxfun(@minus, rx, constellation.')).^2;

    %% Log-likelihood calculation

    % For complex AWGN with variance N0:
    %
    % P(y|s) is proportional to exp(-|y-s|^2/N0).

    logLikelihood = -bsxfun( ...
        @rdivide, distanceSquared, noiseVariance);

    %% Calculate bit LLRs

    llrMatrix = zeros(numSymbols, bitsPerSymbol);

    for bitIndex = 1:bitsPerSymbol

        zeroMask = bitLabels(:, bitIndex) == 0;

        oneMask = bitLabels(:, bitIndex) == 1;

        logProbabilityZero = local_logsumexp( ...
            logLikelihood(:, zeroMask));

        logProbabilityOne = local_logsumexp( ...
            logLikelihood(:, oneMask));

        llrMatrix(:, bitIndex) = ...
            logProbabilityZero - logProbabilityOne;

    end

    %% Restore serial bit order

    % Each row contains the LLRs belonging to one symbol.
    % Transpose and reshape to recover:
    % [b1(symbol1), b2(symbol1), ..., b1(symbol2), ...]

    llr = reshape(llrMatrix.', [], 1);

    if any(~isfinite(llr))
        error('Non-finite LLR values produced.');
    end

end

%% LOCAL FUNCTION

function result = local_logsumexp(values)

    if isempty(values)
        error('Log-sum-exp input cannot be empty.');
    end

    maximumValue = max(values, [], 2);

    result = maximumValue + ...
        log(sum(exp(bsxfun(@minus, values, maximumValue)), 2));

end
