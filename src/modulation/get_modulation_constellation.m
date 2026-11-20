
function [constellation, bitLabels] = ...
    get_modulation_constellation(modulation)
%GET_MODULATION_CONSTELLATION Return normalized Gray-coded constellation.
%
% Outputs:
%   constellation : M-by-1 complex constellation points
%   bitLabels     : M-by-k binary labels
%
% Positive LLR will represent bit 0.
%
% Mapping:
%   BPSK:  0 -> +1, 1 -> -1
%   QPSK:  I bit followed by Q bit
%   16QAM: I sign, I magnitude, Q sign, Q magnitude

    %% Validate modulation name

    if isstring(modulation)

        if ~isscalar(modulation)
            error('Modulation must be a scalar string.');
        end

        modulation = char(modulation);

    end

    if ~ischar(modulation) || isempty(modulation)
        error('Modulation must be a character vector or string.');
    end

    modulation = upper(strtrim(modulation));

    %% Determine modulation order

    switch modulation

        case 'BPSK'

            bitsPerSymbol = 1;

        case 'QPSK'

            bitsPerSymbol = 2;

        case {'16QAM', '16-QAM'}

            bitsPerSymbol = 4;

        otherwise

            error('Unsupported modulation type.');

    end

    M = 2^bitsPerSymbol;

    %% Generate binary labels in natural binary order

    bitLabels = zeros(M, bitsPerSymbol);

    for symbolIndex = 0:M-1

        for bitIndex = 1:bitsPerSymbol

            bitLabels(symbolIndex+1, bitIndex) = ...
                bitget(uint32(symbolIndex), ...
                bitsPerSymbol-bitIndex+1);

        end

    end

    %% Generate constellation

    switch modulation

        case 'BPSK'

            constellation = 1 - 2*bitLabels(:,1);

        case 'QPSK'

            inPhase = 1 - 2*bitLabels(:,1);

            quadrature = 1 - 2*bitLabels(:,2);

            constellation = ...
                (inPhase + 1i*quadrature) / sqrt(2);

        case {'16QAM', '16-QAM'}

            % Gray-coded 4-PAM mapping on each axis.
            %
            % 00 -> +3
            % 01 -> +1
            % 10 -> -3
            % 11 -> -1

            inPhase = ...
                (1 - 2*bitLabels(:,1)) .* ...
                (3 - 2*bitLabels(:,2));

            quadrature = ...
                (1 - 2*bitLabels(:,3)) .* ...
                (3 - 2*bitLabels(:,4));

            constellation = ...
                (inPhase + 1i*quadrature) / sqrt(10);

    end

    constellation = constellation(:);

end
