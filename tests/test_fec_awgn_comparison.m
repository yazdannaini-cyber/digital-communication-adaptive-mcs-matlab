
clc;
clear;

fprintf('\n');
fprintf('=============================================\n');
fprintf(' FEC AWGN COMPARISON TEST SUITE\n');
fprintf('=============================================\n\n');

projectRoot = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(projectRoot));
rehash;

%% Load simulation results

resultPath = fullfile( ...
    projectRoot,'results','fec_awgn_comparison.mat');

assert(exist(resultPath,'file') == 2, ...
    'FEC comparison results are missing.');

S = load(resultPath,'FECResults','fecConfig');

T = S.FECResults;
cfg = S.fecConfig;

%% Test 1: Expected number of records

expectedRows = 4*numel(cfg.EbN0dBList);

assert(height(T) == expectedRows);

fprintf('Test 1 passed: Result table dimensions.\n');

%% Test 2: Four coding systems

assert(numel(unique(T.System)) == 4);

fprintf('Test 2 passed: Four coding systems.\n');

%% Test 3: Six SNR points per system

for k = 1:numel(unique(T.System))

    systemName = unique(T.System);
    hit = T.System == systemName(k);

    assert(nnz(hit) == numel(cfg.EbN0dBList));

end

fprintf('Test 3 passed: SNR coverage.\n');

%% Test 4: BER and PER ranges

assert(all(isfinite(T.BER)));
assert(all(T.BER >= 0 & T.BER <= 1));

assert(all(isfinite(T.PER)));
assert(all(T.PER >= 0 & T.PER <= 1));

fprintf('Test 4 passed: BER and PER ranges.\n');

%% Test 5: Confidence intervals

tol = 1e-12;

assert(all(T.PER_Lower95 <= T.PER + tol), ...
    'Lower confidence bound exceeds PER.');

assert(all(T.PER_Upper95 >= T.PER - tol), ...
    'Upper confidence bound is below PER.');

assert(all(T.PER_Lower95 >= 0 & ...
    T.PER_Upper95 <= 1), ...
    'Confidence interval outside valid range.');

fprintf('Test 5 passed: Wilson confidence intervals.\n');

%% Test 6: Correct coding lengths

uncoded = T.System == "Uncoded-BPSK";
conv = T.System == "Convolutional-Viterbi";
ldpc = T.System == "LDPC-Normalized-MinSum";
polar = T.System == "Polar-SC";

assert(all(T.CodedBitsPerPacket(uncoded) == 64));
assert(all(T.CodedBitsPerPacket(conv) == 132));
assert(all(T.CodedBitsPerPacket(ldpc) == 128));
assert(all(T.CodedBitsPerPacket(polar) == 128));

fprintf('Test 6 passed: Codeword lengths.\n');

%% Test 7: Effective code rates

assert(all(abs(T.NominalCodeRate(uncoded)-1) < 1e-12));

assert(all(abs(T.NominalCodeRate(conv)-64/132) < 1e-12));

assert(all(abs(T.NominalCodeRate(ldpc)-0.5) < 1e-12));

assert(all(abs(T.NominalCodeRate(polar)-0.5) < 1e-12));

fprintf('Test 7 passed: Code-rate calculations.\n');

%% Test 8: Effective payload rate

expectedRate = cfg.PayloadLength ./ T.CodedBitsPerPacket;

assert(all(abs( ...
    T.EffectivePayloadRate-expectedRate) < 1e-12));

fprintf('Test 8 passed: Payload-rate normalization.\n');

%% Test 9: CRC statistics consistency

assert(all(T.CRCOnlyFailureRate <= T.CRCFailureRate+1e-12));

assert(all(T.UndetectedPER <= T.PER+1e-12));

assert(all(T.CRCFailures <= T.NumPackets));

fprintf('Test 9 passed: CRC metrics.\n');

%% Test 10: Correct payload spectral efficiency

expectedGoodputEfficiency = ...
    T.EffectivePayloadRate.*(1-T.PER);

assert(all(abs( ...
    T.CorrectPayloadSpectralEfficiency- ...
    expectedGoodputEfficiency) < 1e-12));

fprintf('Test 10 passed: Correct-payload spectral efficiency.\n');

%% Test 11: LDPC decoder diagnostics

assert(all(isfinite(T.AverageLDPCIterations(ldpc))));

assert(all(T.AverageLDPCIterations(ldpc) >= 1));

assert(all(T.AverageLDPCIterations(ldpc) <= ...
    cfg.LDPCMaxIterations));

assert(all(T.LDPCConvergenceRate(ldpc) >= 0 & ...
    T.LDPCConvergenceRate(ldpc) <= 1));

fprintf('Test 11 passed: LDPC convergence diagnostics.\n');

%% Test 12: Polar and convolutional metrics

assert(all(isnan(T.AverageLDPCIterations(~ldpc))), ...
    'Non-LDPC systems must not have LDPC iteration metrics.');

assert(all(isnan(T.LDPCConvergenceRate(~ldpc))), ...
    'Non-LDPC systems must not have LDPC convergence metrics.');

fprintf('Test 12 passed: Decoder-specific metrics.\n');

%% Test 13: All packet counts

assert(all(T.NumPackets == cfg.NumPackets));

fprintf('Test 13 passed: Packet counts.\n');

%% Test 14: SNR configuration

assert(isequal( ...
    unique(T.EbN0_dB).',cfg.EbN0dBList));

fprintf('Test 14 passed: SNR configuration.\n');

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ALL 14 FEC COMPARISON TESTS PASSED\n');
fprintf('=============================================\n');
