
clc;
clear;

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ADAPTIVE FEC POLICY TESTS\n');
fprintf('=============================================\n\n');

projectRoot = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(projectRoot));
rehash;

%% Load results

resultPath = fullfile(projectRoot, ...
    'results','fec_awgn_comparison.mat');

assert(exist(resultPath,'file') == 2);

S = load(resultPath,'FECResults');

T = S.FECResults;

targetPER = 0.10;

%% Build policy

[P,selectedRows] = ...
    build_adaptive_fec_policy(T,targetPER);

%% Test 1

assert(height(P) == numel(unique(T.EbN0_dB)));

fprintf('Test 1 passed: Operating-point count.\n');

%% Test 2

for k = 1:numel(unique(T.EbN0_dB))

    snrValues = unique(T.EbN0_dB);

    hit = T.EbN0_dB == snrValues(k);

    assert(nnz(hit) == 4);

end

fprintf('Test 2 passed: Four candidates per SNR.\n');

%% Test 3

assert(height(selectedRows) == height(P));

assert(all(string(selectedRows.System) == P.SelectedSystem));

assert(all(selectedRows.EbN0_dB == P.EbN0_dB));

fprintf('Test 3 passed: Selected profile mapping.\n');

%% Test 4

assert(all(P.QoS_Met == (P.PER_Upper95 <= targetPER)));

fprintf('Test 4 passed: QoS consistency.\n');

%% Test 5: QoS candidate selection

for k = 1:height(P)

    group = find(T.EbN0_dB == P.EbN0_dB(k));

    candidates = group(T.PER_Upper95(group) <= targetPER);

    if ~isempty(candidates)

        maximumRate = max( ...
            T.EffectivePayloadSpectralEfficiency(candidates));

        assert(abs(P.EffectivePayloadRate(k)-maximumRate) < 1e-12);

    end

end

fprintf('Test 5 passed: Effective-rate optimization.\n');

%% Test 6: Best-effort fallback

fallback = ~P.QoS_Met;

for k = find(fallback).'

    group = find(T.EbN0_dB == P.EbN0_dB(k));

    minimumUpper = min(T.PER_Upper95(group));

    assert(abs(P.PER_Upper95(k)-minimumUpper) < 1e-12);

end

fprintf('Test 6 passed: Best-effort fallback.\n');

%% Test 7

assert(all(P.FEC_Enabled == ...
    (P.SelectedSystem ~= "Uncoded-BPSK")));

fprintf('Test 7 passed: FEC activation state.\n');

%% Test 8

validSystems = [
    "Uncoded-BPSK"
    "Convolutional-Viterbi"
    "LDPC-Normalized-MinSum"
    "Polar-SC"
];

assert(all(ismember(P.SelectedSystem,validSystems)));

fprintf('Test 8 passed: Supported FEC systems.\n');

%% Test 9

assert(all(P.EffectivePayloadRate > 0));

fprintf('Test 9 passed: Effective payload rate.\n');

%% Test 10

assert(numel(unique(P.EbN0_dB)) == height(P));

fprintf('Test 10 passed: Unique operating points.\n');

%% Test 11

assert(targetPER == 0.10);

fprintf('Test 11 passed: QoS configuration.\n');

%% Test 12: Expected policy for current measured dataset

expectedSystems = [
    "Convolutional-Viterbi"
    "Polar-SC"
    "Polar-SC"
    "Polar-SC"
    "Uncoded-BPSK"
    "Uncoded-BPSK"
];

assert(isequal(P.SelectedSystem,expectedSystems), ...
    'Unexpected FEC selection for current measured dataset.');

fprintf('Test 12 passed: Adaptive FEC decisions.\n');

%% Final report

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ALL 12 ADAPTIVE FEC TESTS PASSED\n');
fprintf('=============================================\n');

disp(P);
