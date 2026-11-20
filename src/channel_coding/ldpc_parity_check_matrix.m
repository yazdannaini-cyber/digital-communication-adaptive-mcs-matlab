
function [H,A,B] = ldpc_parity_check_matrix(K)
%LDPC_PARITY_CHECK_MATRIX Construct a systematic sparse LDPC matrix.
%
% Default code:
%       N = 128
%       K = 64
%       Rate = 1/2
%
% H = [A B]
%
% A: sparse K-by-K binary matrix with column weight 3.
% B: invertible upper-bidiagonal binary matrix.
%
% The systematic codeword is:
%       c = [u; p]
%
% with:
%       A*u + B*p = 0 (mod 2)

    if nargin < 1 || isempty(K)
        K = 64;
    end

    validateattributes(K,{'numeric'}, ...
        {'scalar','integer','>=',8});

    %% Build sparse information submatrix

    A = zeros(K,K);

    shifts = [0 1 4];

    for col = 1:K

        rows = mod((col-1)+shifts,K)+1;

        A(rows,col) = 1;

    end

    %% Build invertible parity submatrix

    B = eye(K);

    for col = 2:K

        B(col-1,col) = 1;

    end

    %% Construct parity-check matrix

    H = [A B];

    assert(rank(B) == K, ...
        'Parity submatrix must be invertible.');

    assert(all(mod(H,2) == H,'all'), ...
        'Parity-check matrix must be binary.');

end
