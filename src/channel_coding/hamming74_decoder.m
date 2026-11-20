function [decodedBits, correctedCodeBits, errorPositions, syndromes] = hamming74_decoder(rxCodeBits)
%HAMMING74_DECODER Syndrome-based single-bit decoder for Hamming (7,4).
% Input:  a non-empty binary vector whose length is a multiple of 7.
% Outputs:
%   decodedBits       - recovered 4-bit messages, serialized as a row vector
%   correctedCodeBits - corrected 7-bit codewords, serialized as a row vector
%   errorPositions   - one value per codeword: 0=no error, 1..7=corrected bit
%   syndromes        - 3-by-N matrix; each column is the pre-correction syndrome
%
% IMPORTANT: This is a single-error-correcting decoder. If a codeword has
% two or more bit errors, the syndrome may point to a different bit and the
% decoder can miscorrect it. Use an extended Hamming code (SECDED) when
% reliable detection of double-bit errors is required.

    %% Validate input type
    if ~(isnumeric(rxCodeBits) || islogical(rxCodeBits))
        error('Input must be numeric or logical.');
    end

    %% Validate input shape
    if isempty(rxCodeBits) || ~isvector(rxCodeBits)
        error('Input must be a non-empty vector.');
    end

    %% Validate input values
    if ~isreal(rxCodeBits) || any(~isfinite(double(rxCodeBits(:))))
        error('Input must contain finite real binary values.');
    end

    if any(rxCodeBits(:) ~= 0 & rxCodeBits(:) ~= 1)
        error('Input must contain binary values only.');
    end

    rxCodeBits = double(rxCodeBits(:).');

    if mod(numel(rxCodeBits),7) ~= 0
        error('Hamming (7,4) requires a multiple of 7 received bits.');
    end

    %% Arrange received words as columns
    receivedMatrix = reshape(rxCodeBits,7,[]);
    correctedMatrix = receivedMatrix;
    numWords = size(receivedMatrix,2);

    H = hamming74_parity_check_matrix();

    errorPositions = zeros(1,numWords);
    syndromes = mod(H * receivedMatrix,2);

    %% Syndrome decoding and single-bit correction
    for wordIndex = 1:numWords
        currentSyndrome = syndromes(:,wordIndex);

        if any(currentSyndrome)
            % Each column of H identifies the syndrome for one bit position.
            matchingPosition = find( ...
                all(bsxfun(@eq,H,currentSyndrome),1),1,'first');

            if isempty(matchingPosition)
                error('Non-zero syndrome does not match a codeword position.');
            end

            correctedMatrix(matchingPosition,wordIndex) = ...
                1 - correctedMatrix(matchingPosition,wordIndex);

            errorPositions(wordIndex) = matchingPosition;
        end
    end

    %% Extract the systematic information bits
    decodedBits = reshape(correctedMatrix(1:4,:),1,[]);
    correctedCodeBits = reshape(correctedMatrix,1,[]);
end
