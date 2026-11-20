
clc;
clear;

%% =========================================================
%  INDEPENDENT ADAPTIVE MCS VALIDATION TESTS
%  Dynamic operating-point count.
%% =========================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf(' INDEPENDENT MCS VALIDATION TEST SUITE\n');
fprintf('=============================================\n\n');

%% 1. Project setup

projectRoot = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(projectRoot));
rehash;

%% 2. Load validation results

validationPath = fullfile( ...
    projectRoot, 'results', 'adaptive_mcs_validation.mat');

assert(exist(validationPath, 'file') == 2, ...
    'Independent validation file is missing.');

S = load(validationPath, ...
    'ValidationResults', ...
    'AdaptiveValidation', ...
    'ValidationSummary', ...
    'validationConfig');

V = S.ValidationResults;
A = S.AdaptiveValidation;
M = S.ValidationSummary;
cfg = S.validationConfig;

%% 3. Expected dimensions

expectedProfiles = ...
    numel(cfg.ChannelTypes) * ...
    numel(cfg.EbN0dBList) * ...
    numel(cfg.ModulationTypes) * ...
    numel(cfg.InterleaverDepths);

expectedOperatingPoints = ...
    numel(cfg.ChannelTypes) * numel(cfg.EbN0dBList);

%% TEST 1: Independent validation seed

assert(cfg.RandomSeed == 20261121, ...
    'Unexpected validation seed.');

fprintf('Test 1 passed: Independent validation seed.\n');

%% TEST 2: All profiles were measured

assert(height(V) == expectedProfiles, ...
    'Incorrect number of profile measurements.');

fprintf('Test 2 passed: Profile measurement count.\n');

%% TEST 3: Adaptive decisions were evaluated

assert(height(A) == expectedOperatingPoints, ...
    'Incorrect number of adaptive operating points.');

fprintf('Test 3 passed: Adaptive operating-point count.\n');

%% TEST 4: Valid BER and PER ranges

assert(all(isfinite(V.BER)) && ...
    all(V.BER >= 0 & V.BER <= 1), ...
    'Invalid BER values.');

assert(all(isfinite(V.PER)) && ...
    all(V.PER >= 0 & V.PER <= 1), ...
    'Invalid PER values.');

fprintf('Test 4 passed: BER and PER ranges.\n');

%% TEST 5: Confidence intervals

assert(all(V.PER_Lower95 >= 0 & V.PER_Upper95 <= 1), ...
    'Confidence interval exceeds valid range.');

assert(all(V.PER_Lower95 <= V.PER), ...
    'Lower confidence bound exceeds measured PER.');

assert(all(V.PER_Upper95 >= V.PER), ...
    'Upper confidence bound is below measured PER.');

fprintf('Test 5 passed: PER confidence intervals.\n');

%% TEST 6: QoS flag consistency

expectedQoS = A.PER_Upper95 <= cfg.TargetPER;

assert(all(A.QoS_Met_Validation == expectedQoS), ...
    'Validation QoS flags are inconsistent.');

fprintf('Test 6 passed: Validation QoS flags.\n');

%% TEST 7: Calibration-to-validation status comparison

expectedChanged = ...
    A.CalibrationQoS_Met ~= A.QoS_Met_Validation;

assert(all(A.QoS_Status_Changed == expectedChanged), ...
    'QoS status change flags are inconsistent.');

fprintf('Test 7 passed: Calibration versus validation QoS.\n');

%% TEST 8: Selected adaptive profiles exist in validation data

for k = 1:height(A)

    hit = ...
        V.Channel == A.Channel(k) & ...
        V.EbN0_dB == A.EbN0_dB(k) & ...
        V.Modulation == A.Modulation(k) & ...
        V.InterleaverDepth == A.InterleaverDepth(k);

    assert(nnz(hit) == 1, ...
        'Adaptive profile does not map to exactly one validation row.');

    assert(abs(V.PER(hit) - A.PER(k)) < 1e-12, ...
        'Adaptive validation PER mapping mismatch.');

end

fprintf('Test 8 passed: Adaptive profile mapping.\n');

%% TEST 9: Supported modulation and interleaver depths

assert(all(ismember( ...
    V.Modulation, ["BPSK","QPSK","16QAM"])), ...
    'Unsupported modulation found.');

assert(all(ismember(V.InterleaverDepth, [4 16])), ...
    'Unsupported interleaver depth found.');

fprintf('Test 9 passed: Supported profiles.\n');

%% TEST 10: Fixed baseline comparison dimensions

assert(height(M) == 4, ...
    'Expected four comparison methods.');

assert(all(M.TotalOperatingPoints == expectedOperatingPoints), ...
    'Baseline operating-point counts are inconsistent.');

fprintf('Test 10 passed: Fixed baseline dimensions.\n');

%% TEST 11: Baseline metric validity

assert(all(isfinite(M.MeanBER)), ...
    'Invalid baseline BER.');

assert(all(isfinite(M.MeanPER)), ...
    'Invalid baseline PER.');

assert(all(M.MeanEffectiveSpectralEfficiency > 0), ...
    'Invalid baseline spectral efficiency.');

fprintf('Test 11 passed: Baseline metric validity.\n');

%% TEST 12: All operating points have six profiles

uniqueKeys = unique(table( ...
    V.Channel, ...
    V.EbN0_dB, ...
    'VariableNames', {'Channel','EbN0_dB'}));

assert(height(uniqueKeys) == expectedOperatingPoints, ...
    'Missing or duplicate operating points.');

for k = 1:height(uniqueKeys)

    hit = ...
        V.Channel == uniqueKeys.Channel(k) & ...
        V.EbN0_dB == uniqueKeys.EbN0_dB(k);

    assert(nnz(hit) == 6, ...
        'Each operating point must contain six profiles.');

end

fprintf('Test 12 passed: Six profiles per operating point.\n');

%% FINAL REPORT

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ALL 12 INDEPENDENT VALIDATION TESTS PASSED\n');
fprintf('=============================================\n');
