function codeBits = hamming74_encoder(infoBits)
%HAMMING74_ENCODER Encode information bits using systematic Hamming (7,4).
% Input:  a non-empty binary vector whose length is a multiple of 4.
% Output: a row vector with 7 coded bits for each 4 information bits.
% Codeword order: [d1 d2 d3 d4 p1 p2 p3].

    %% Validate input type
    if ~(isnumeric(infoBits) || islogical(infoBits))
        error('Input must be numeric or logical.');
    end

    %% Validate input shape
    if isempty(infoBits) || ~isvector(infoBits)
        error('Input must be a non-empty vector.');
    end

    %% Validate input values
    if ~isreal(infoBits) || any(~isfinite(double(infoBits(:))))
        error('Input must contain finite real binary values.');
    end

    if any(infoBits(:) ~= 0 & infoBits(:) ~= 1)
        error('Input must contain binary values only.');
    end

    infoBits = double(infoBits(:).');

    if mod(numel(infoBits),4) ~= 0
        error('Hamming (7,4) requires a multiple of 4 information bits.');
    end

    %% Split input into 4-bit message columns
    messageMatrix = reshape(infoBits,4,[]);

    %% Encode over GF(2)
    G = hamming74_generator_matrix();
    codewordMatrix = mod(G.' * messageMatrix,2);

    %% Serialize codewords in transmission order
    codeBits = reshape(codewordMatrix,1,[]);
end
