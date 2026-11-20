
function [txSymbols, bitsPerSymbol] = ...
    digital_modulator(inputBits, modulation, symbolAmplitude)
%DIGITAL_MODULATOR Generic BPSK, QPSK and 16-QAM modulator.
%
% Inputs:
%   inputBits      : Binary input vector.
%   modulation     : BPSK, QPSK or 16QAM.
%   symbolAmplitude: Positive real scaling factor.
%
% Outputs:
%   txSymbols      : Complex modulated column vector.
%   bitsPerSymbol  : Number of bits per modulation symbol.
%
% Bit order:
%   The first input bit is the most significant bit of each
%   constellation label.

    %% Validate input bits

    if ~isnumeric(inputBits) || ...
            ~isvector(inputBits) || isempty(inputBits)

        error('inputBits must be a non-empty numeric vector.');

    end

    bits = double(inputBits(:));

    if any(~isfinite(bits)) || any(bits ~= 0 & bits ~= 1)

        error('inputBits must contain only binary values.');

    end

    %% Validate amplitude

    if ~isscalar(symbolAmplitude) || ...
            ~isreal(symbolAmplitude) || ...
            ~isfinite(symbolAmplitude) || ...
            symbolAmplitude <= 0

        error('symbolAmplitude must be positive and finite.');

    end

    %% Obtain constellation and labels

    [constellation, bitLabels] = ...
        get_modulation_constellation(modulation);

    constellation = constellation(:);

    bitsPerSymbol = size(bitLabels, 2);

    %% Group input bits

    if mod(numel(bits), bitsPerSymbol) ~= 0

        error(['Input bit length must be divisible by ', ...
               'bits per symbol.']);

    end

    bitGroups = reshape(bits, bitsPerSymbol, []).';

    %% Convert each binary label to constellation index

    weights = 2.^(bitsPerSymbol-1:-1:0).';

    symbolIndices = bitGroups * weights + 1;

    %% Modulation

    txSymbols = symbolAmplitude .* constellation(symbolIndices);

    txSymbols = txSymbols(:);

end
