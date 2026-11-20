
function [informationIndices,frozenMask,reliability] = ...
    polar_reliability_sequence(N,K,designEbN0dB)
%POLAR_RELIABILITY_SEQUENCE Construct a Polar information set.
%
% Uses Bhattacharyya-parameter recursion.
%
% Input:
%       N: codeword length, power of two
%       K: information bits
%       designEbN0dB: design SNR, default 2 dB
%
% Output:
%       informationIndices: selected information bit positions
%       frozenMask: true for frozen bits
%       reliability: Bhattacharyya estimates
%
% Smaller Bhattacharyya values indicate more reliable channels.

    if nargin < 3 || isempty(designEbN0dB)
        designEbN0dB = 2;
    end

    validateattributes(N,{'numeric'}, ...
        {'scalar','integer','positive'});

    validateattributes(K,{'numeric'}, ...
        {'scalar','integer','positive','<=',N});

    validateattributes(designEbN0dB,{'numeric'}, ...
        {'scalar','real','finite'});

    if 2^round(log2(N)) ~= N

        error('Polar code length N must be a power of two.');

    end

    %% Initial BPSK AWGN Bhattacharyya parameter

    ebn0 = 10^(designEbN0dB/10);

    z = exp(-ebn0);

    z = min(max(z,1e-12),1-1e-12);

    %% Polarization recursion

    while numel(z) < N

        zMinus = 2*z-z.^2;

        zPlus = z.^2;

        % Keep natural SC input-bit ordering:
        % [minus(z1), plus(z1), minus(z2), plus(z2), ...]

        z = reshape([zMinus.';zPlus.'],[],1);

        z = min(max(z,0),1);

    end

    reliability = z(:);

    %% Select K most reliable bit channels

    [~,order] = sort(reliability,'ascend');

    informationIndices = sort(order(1:K));

    frozenMask = true(N,1);

    frozenMask(informationIndices) = false;

end
