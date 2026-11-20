
clc;
clear;

%% =========================================================
% LDPC AND POLAR CODING TEST SUITE
%% =========================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf(' LDPC AND POLAR CODING TEST SUITE\n');
fprintf('=============================================\n\n');

projectRoot = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(projectRoot));
rehash;

rng(20261124,'twister');

K = 64;
N = 128;

numBlocks = 4;

%% Generate common information bits

informationBits = randi([0 1],K*numBlocks,1);

%% =========================================================
% TEST 1: LDPC parity-check matrix
%% =========================================================

[H,A,B] = ldpc_parity_check_matrix(K);

assert(isequal(size(H),[K N]));
assert(isequal(size(A),[K K]));
assert(isequal(size(B),[K K]));

fprintf('Test 1 passed: LDPC matrix dimensions.\n');

%% =========================================================
% TEST 2: LDPC parity matrix invertibility
%% =========================================================

assert(rank(B) == K);

fprintf('Test 2 passed: LDPC parity matrix invertibility.\n');

%% =========================================================
% TEST 3: LDPC encoding
%% =========================================================

[ldpcCode,ldpcInfo] = ...
    ldpc_encoder(informationBits,K);

assert(numel(ldpcCode) == N*numBlocks);

assert(ldpcInfo.CodeRate == 0.5);

fprintf('Test 3 passed: LDPC encoding and code rate.\n');

%% =========================================================
% TEST 4: LDPC syndrome validation
%% =========================================================

ldpcBlocks = reshape(ldpcCode,N,[]);

for b = 1:numBlocks

    syndrome = mod(H*ldpcBlocks(:,b),2);

    assert(all(syndrome == 0), ...
        'LDPC codeword has nonzero syndrome.');

end

fprintf('Test 4 passed: All LDPC codewords satisfy parity checks.\n');

%% =========================================================
% TEST 5: LDPC noiseless decoding
%% =========================================================

ldpcLLR = 40*(1-2*ldpcCode);

[ldpcDecoded,~,ldpcDiagnostics] = ...
    ldpc_min_sum_decoder(ldpcLLR,20,0.8,K);

assert(isequal(ldpcDecoded,informationBits), ...
    'LDPC noiseless decoding failed.');

assert(ldpcDiagnostics.ConvergenceRate == 1, ...
    'LDPC decoder did not converge on noiseless blocks.');

fprintf('Test 5 passed: LDPC noiseless decoding.\n');

%% =========================================================
% TEST 6: LDPC output length
%% =========================================================

assert(numel(ldpcDecoded) == numel(informationBits));

fprintf('Test 6 passed: LDPC decoded output length.\n');

%% =========================================================
% TEST 7: Polar reliability sequence
%% =========================================================

[infoIndices,frozenMask,reliability] = ...
    polar_reliability_sequence(N,K,2);

assert(numel(infoIndices) == K);
assert(numel(frozenMask) == N);
assert(numel(reliability) == N);

assert(sum(~frozenMask) == K);

fprintf('Test 7 passed: Polar reliability construction.\n');

%% =========================================================
% TEST 8: Polar information/frozen partition
%% =========================================================

assert(all(~frozenMask(infoIndices)));

assert(all(unique(infoIndices) == infoIndices));

assert(numel(unique(infoIndices)) == K);

fprintf('Test 8 passed: Polar information-set consistency.\n');

%% =========================================================
% TEST 9: Polar encoding
%% =========================================================

[polarCode,polarInfo] = ...
    polar_encoder(informationBits,infoIndices,N);

assert(numel(polarCode) == N*numBlocks);

assert(polarInfo.CodeRate == 0.5);

fprintf('Test 9 passed: Polar encoding and code rate.\n');

%% =========================================================
% TEST 10: Polar noiseless decoding
%% =========================================================

polarLLR = 40*(1-2*polarCode);

[polarDecoded,polarU] = ...
    polar_sc_decoder(polarLLR,frozenMask);

assert(isequal(polarDecoded,informationBits), ...
    'Polar noiseless decoding failed.');

assert(numel(polarU) == N*numBlocks);

fprintf('Test 10 passed: Polar noiseless SC decoding.\n');

%% =========================================================
% TEST 11: Polar frozen-bit constraints
%% =========================================================

decodedUMatrix = reshape(polarU,N,[]);

for b = 1:numBlocks

    u = decodedUMatrix(:,b);

    assert(all(u(frozenMask) == 0), ...
        'Frozen-bit decision is incorrect.');

end

fprintf('Test 11 passed: Frozen-bit constraints.\n');

%% =========================================================
% TEST 12: Equal code rates
%% =========================================================

assert(ldpcInfo.CodeRate == polarInfo.CodeRate);

assert(ldpcInfo.CodeRate == 0.5);

fprintf('Test 12 passed: Equal LDPC and Polar code rates.\n');

%% =========================================================
% TEST 13: Invalid LDPC input length
%% =========================================================

errorCaught = false;

try

    ldpc_encoder(ones(K+1,1),K);

catch

    errorCaught = true;

end

assert(errorCaught);

fprintf('Test 13 passed: Invalid LDPC input rejection.\n');

%% =========================================================
% TEST 14: Invalid Polar input length
%% =========================================================

errorCaught = false;

try

    polar_encoder(ones(K+1,1),infoIndices,N);

catch

    errorCaught = true;

end

assert(errorCaught);

fprintf('Test 14 passed: Invalid Polar input rejection.\n');

%% =========================================================
% TEST 15: Invalid LLR length
%% =========================================================

errorCaught = false;

try

    ldpc_min_sum_decoder(ones(N+1,1),20,0.8,K);

catch

    errorCaught = true;

end

assert(errorCaught);

fprintf('Test 15 passed: Invalid LDPC LLR length rejection.\n');

%% =========================================================
% TEST 16: Invalid Polar block length
%% =========================================================

errorCaught = false;

try

    polar_reliability_sequence(100,50,2);

catch

    errorCaught = true;

end

assert(errorCaught);

fprintf('Test 16 passed: Invalid Polar block length rejection.\n');

%% =========================================================
% TEST 17: Binary output verification
%% =========================================================

assert(all(ismember(ldpcCode,[0 1])));
assert(all(ismember(polarCode,[0 1])));

fprintf('Test 17 passed: Binary codeword verification.\n');

%% =========================================================
% FINAL REPORT
%% =========================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ALL 17 LDPC AND POLAR TESTS PASSED\n');
fprintf('=============================================\n');

fprintf('\nLDPC: N=%d, K=%d, Rate=%.2f\n', ...
    ldpcInfo.N,ldpcInfo.K,ldpcInfo.CodeRate);

fprintf('Polar: N=%d, K=%d, Rate=%.2f\n', ...
    polarInfo.N,polarInfo.K,polarInfo.CodeRate);

fprintf('LDPC convergence rate: %.2f\n', ...
    ldpcDiagnostics.ConvergenceRate);

fprintf('\nCoding module validation completed.\n');
