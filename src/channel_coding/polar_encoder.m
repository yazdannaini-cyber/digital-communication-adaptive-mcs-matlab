
function [codedBits,info] = ...
    polar_encoder(inputBits,informationIndices,N)
%POLAR_ENCODER Systematic-position Polar encoder.
%
% Input:
%       inputBits: binary information vector
%       informationIndices: selected information positions
%       N: polar block length
%
% Output:
%       codedBits: encoded binary vector
%       info: code parameters

    validateattributes(inputBits,{'numeric','logical'}, ...
        {'vector','nonempty','real','finite'});

    validateattributes(informationIndices,{'numeric'}, ...
        {'vector','nonempty','integer','positive'});

    validateattributes(N,{'numeric'}, ...
        {'scalar','integer','positive'});

    bits = double(inputBits(:));

    if any(bits ~= 0 & bits ~= 1)
        error('Input must contain binary values.');
    end

    if 2^round(log2(N)) ~= N
        error('N must be a power of two.');
    end

    informationIndices = informationIndices(:);

    K = numel(informationIndices);

    if numel(unique(informationIndices)) ~= K
        error('Information indices must be unique.');
    end

    if any(informationIndices > N)
        error('Information index exceeds N.');
    end

    if mod(numel(bits),K) ~= 0
        error('Input length must be divisible by K.');
    end

    %% Generate Polar transform matrix

    F = [1 0; 1 1];

    G = 1;

    stages = round(log2(N));

    for stage = 1:stages

        G = kron(G,F);

    end

    %% Encode information blocks

    dataBlocks = reshape(bits,K,[]);

    numBlocks = size(dataBlocks,2);

    codedBlocks = zeros(N,numBlocks);

    for blockIndex = 1:numBlocks

        u = zeros(N,1);

        u(informationIndices) = dataBlocks(:,blockIndex);

        % Column-vector representation of x = u*G
        x = mod(G.'*u,2);

        codedBlocks(:,blockIndex) = x;

    end

    codedBits = codedBlocks(:);

    %% Metadata

    info = struct();

    info.N = N;

    info.K = K;

    info.CodeRate = K/N;

    info.NumBlocks = numBlocks;

    info.InformationIndices = informationIndices;

    info.FrozenMask = true(N,1);

    info.FrozenMask(informationIndices) = false;

    info.DesignMatrix = G;

end
