
function [decodedBits,decodedCodewords,decoderInfo] = ...
    ldpc_min_sum_decoder(channelLLR,maxIterations,normalizationFactor,K)
%LDPC_MIN_SUM_DECODER Normalized Min-Sum LDPC decoder.
%
% LLR convention:
%       Positive LLR favors bit 0.
%       Negative LLR favors bit 1.
%
% Default parameters:
%       K = 64
%       N = 128
%       maxIterations = 20
%       normalizationFactor = 0.8

    if nargin < 2 || isempty(maxIterations)
        maxIterations = 20;
    end

    if nargin < 3 || isempty(normalizationFactor)
        normalizationFactor = 0.8;
    end

    if nargin < 4 || isempty(K)
        K = 64;
    end

    validateattributes(channelLLR,{'numeric'}, ...
        {'vector','nonempty','real','finite'});

    validateattributes(maxIterations,{'numeric'}, ...
        {'scalar','integer','positive'});

    validateattributes(normalizationFactor,{'numeric'}, ...
        {'scalar','real','finite','>',0,'<=',1});

    validateattributes(K,{'numeric'}, ...
        {'scalar','integer','>=',8});

    [H,~,~] = ldpc_parity_check_matrix(K);

    [M,N] = size(H);

    llr = double(channelLLR(:));

    if mod(numel(llr),N) ~= 0

        error('LLR length must be divisible by LDPC codeword length.');

    end

    numBlocks = numel(llr)/N;

    receivedBlocks = reshape(llr,N,[]);

    decodedInformation = zeros(K,numBlocks);

    decodedCodewordBlocks = zeros(N,numBlocks);

    iterationCount = zeros(numBlocks,1);

    converged = false(numBlocks,1);

    %% Decode each code block

    for blockIndex = 1:numBlocks

        Lch = receivedBlocks(:,blockIndex);

        %% Initialize variable-to-check messages

        q = zeros(M,N);

        r = zeros(M,N);

        for checkIndex = 1:M

            neighbors = find(H(checkIndex,:));

            q(checkIndex,neighbors) = Lch(neighbors).';

        end

        hardBits = zeros(N,1);

        %% Iterative normalized min-sum decoding

        for iteration = 1:maxIterations

            %% Check-node update

            for checkIndex = 1:M

                neighbors = find(H(checkIndex,:));

                values = q(checkIndex,neighbors);

                signs = ones(size(values));

                signs(values < 0) = -1;

                magnitudes = abs(values);

                for edgeIndex = 1:numel(neighbors)

                    otherMask = true(size(neighbors));

                    otherMask(edgeIndex) = false;

                    otherSigns = signs(otherMask);

                    otherMagnitudes = magnitudes(otherMask);

                    signProduct = prod(otherSigns);

                    minimumMagnitude = min(otherMagnitudes);

                    outgoingMessage = ...
                        normalizationFactor * ...
                        signProduct * ...
                        minimumMagnitude;

                    variableIndex = neighbors(edgeIndex);

                    r(checkIndex,variableIndex) = outgoingMessage;

                end

            end

            %% Variable-node update

            posteriorLLR = Lch + sum(r,1).';

            hardBits = double(posteriorLLR < 0);

            %% Syndrome check

            syndrome = mod(H*hardBits,2);

            if all(syndrome == 0)

                converged(blockIndex) = true;

                iterationCount(blockIndex) = iteration;

                break;

            end

            %% Update variable-to-check messages

            for variableIndex = 1:N

                connectedChecks = find(H(:,variableIndex));

                for k = 1:numel(connectedChecks)

                    checkIndex = connectedChecks(k);

                    q(checkIndex,variableIndex) = ...
                        posteriorLLR(variableIndex) - ...
                        r(checkIndex,variableIndex);

                end

            end

            iterationCount(blockIndex) = iteration;

        end

        %% Final hard decisions

        posteriorLLR = Lch + sum(r,1).';

        hardBits = double(posteriorLLR < 0);

        decodedCodewordBlocks(:,blockIndex) = hardBits;

        % Systematic information bits are the first K bits.
        decodedInformation(:,blockIndex) = hardBits(1:K);

    end

    %% Serialize output

    decodedBits = decodedInformation(:);

    decodedCodewords = decodedCodewordBlocks(:);

    %% Decoder diagnostics

    decoderInfo = struct();

    decoderInfo.Iterations = iterationCount;

    decoderInfo.Converged = converged;

    decoderInfo.ConvergenceRate = mean(converged);

    decoderInfo.MaxIterations = maxIterations;

    decoderInfo.NormalizationFactor = normalizationFactor;

    decoderInfo.K = K;

    decoderInfo.N = N;

end
