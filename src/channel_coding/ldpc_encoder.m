
function [codedBits,info] = ldpc_encoder(inputBits,K)
%LDPC_ENCODER Systematic rate-1/2 LDPC encoder.
%
% Input:
%       inputBits: binary vector, length multiple of K
%       K: information block length, default 64
%
% Output:
%       codedBits: encoded binary column vector
%       info: code parameters

    if nargin < 2 || isempty(K)
        K = 64;
    end

    validateattributes(inputBits,{'numeric','logical'}, ...
        {'vector','nonempty','real','finite'});

    if any(inputBits(:) ~= 0 & inputBits(:) ~= 1)
        error('Input must contain only binary values.');
    end

    validateattributes(K,{'numeric'}, ...
        {'scalar','integer','>=',8});

    bits = double(inputBits(:));

    if mod(numel(bits),K) ~= 0

        error('Input length must be divisible by K.');

    end

    [~,A,~] = ldpc_parity_check_matrix(K);

    %% Divide input into information blocks

    dataBlocks = reshape(bits,K,[]);

    numBlocks = size(dataBlocks,2);

    parityBlocks = zeros(K,numBlocks);

    %% Systematic encoding

    for blockIndex = 1:numBlocks

        u = dataBlocks(:,blockIndex);

        s = mod(A*u,2);

        p = zeros(K,1);

        % B is upper bidiagonal:
        % p(i) XOR p(i+1) = s(i)
        % p(K) = s(K)

        for i = K:-1:1

            if i == K

                p(i) = s(i);

            else

                p(i) = mod(s(i)+p(i+1),2);

            end

        end

        parityBlocks(:,blockIndex) = p;

    end

    %% Construct codewords

    codeBlocks = [dataBlocks;parityBlocks];

    codedBits = codeBlocks(:);

    %% Metadata

    info = struct();

    info.K = K;
    info.N = 2*K;
    info.CodeRate = 0.5;
    info.NumBlocks = numBlocks;
    info.Systematic = true;

end
