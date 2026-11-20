
function [decodedBits,decodedU] = ...
    polar_sc_decoder(channelLLR,frozenMask)
%POLAR_SC_DECODER Successive Cancellation Polar decoder.
%
% Input:
%       channelLLR: received channel LLR vector
%       frozenMask: true for frozen bit positions
%
% Convention:
%       Positive LLR favors bit zero.
%
% Output:
%       decodedBits: recovered information bits
%       decodedU: estimated Polar input vectors

    validateattributes(channelLLR,{'numeric'}, ...
        {'vector','nonempty','real','finite'});

    if ~islogical(frozenMask) && ...
            (~isnumeric(frozenMask) || ...
            any(frozenMask(:) ~= 0 & frozenMask(:) ~= 1))

        error('frozenMask must be a binary vector.');

    end

    frozenMask = logical(frozenMask(:));

    N = numel(frozenMask);

    if 2^round(log2(N)) ~= N

        error('Polar block length must be a power of two.');

    end

    K = sum(~frozenMask);

    if K == 0 || K == N
        error('Polar code must contain both frozen and information bits.');
    end

    llr = double(channelLLR(:));

    if mod(numel(llr),N) ~= 0

        error('LLR length must be divisible by N.');

    end

    %% Divide into codeword blocks

    llrBlocks = reshape(llr,N,[]);

    numBlocks = size(llrBlocks,2);

    decodedUBlocks = zeros(N,numBlocks);

    decodedInformationBlocks = zeros(K,numBlocks);

    informationIndices = find(~frozenMask);

    %% Successive Cancellation decoding

    for blockIndex = 1:numBlocks

        alpha = llrBlocks(:,blockIndex);

        [uHat,~] = local_sc_decode(alpha,frozenMask);

        decodedUBlocks(:,blockIndex) = uHat;

        decodedInformationBlocks(:,blockIndex) = ...
            uHat(informationIndices);

    end

    %% Serialize outputs

    decodedBits = decodedInformationBlocks(:);

    decodedU = decodedUBlocks(:);

end


%% =========================================================
% Recursive SC decoder
%% =========================================================

function [uHat,beta] = local_sc_decode(alpha,frozen)

    N = numel(alpha);

    if N == 1

        if frozen(1)

            uHat = 0;

        else

            uHat = double(alpha < 0);

        end

        beta = uHat;

        return;

    end

    half = N/2;

    alphaLeftInput = alpha(1:half);

    alphaRightInput = alpha(half+1:end);

    %% Decode left branch

    alphaLeft = local_f_function( ...
        alphaLeftInput,alphaRightInput);

    [uLeft,betaLeft] = local_sc_decode( ...
        alphaLeft,frozen(1:half));

    %% Decode right branch

    alphaRight = alphaRightInput + ...
        (1-2*double(betaLeft)).*alphaLeftInput;

    [uRight,betaRight] = local_sc_decode( ...
        alphaRight,frozen(half+1:end));

    %% Combine partial sums

    uHat = [uLeft;uRight];

    beta = [
        mod(betaLeft+betaRight,2)
        betaRight
    ];

end


%% =========================================================
% Min-Sum f function
%% =========================================================

function output = local_f_function(a,b)

    signA = ones(size(a));
    signB = ones(size(b));

    signA(a < 0) = -1;
    signB(b < 0) = -1;

    output = ...
        signA.*signB.*min(abs(a),abs(b));

end
