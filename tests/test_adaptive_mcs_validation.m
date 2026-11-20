
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(projectRoot));
rehash;

validationPath = fullfile( ...
    projectRoot, 'results', 'adaptive_mcs_validation.mat');

assert(exist(validationPath,'file') == 2, ...
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

%% Test 1: Independent seed

assert(cfg.RandomSeed == 20261121, ...
    'Unexpected validation seed.');

fprintf('Test 1 passed: Independent validation seed.\n');

%% Test 2: Six profiles at ten operating points

assert(height(V) == 60, ...
    'Expected 60 validation records.');

fprintf('Test 2 passed: 60 profile measurements.\n');

%% Test 3: Ten adaptive decisions

assert(height(A) == 10, ...
    'Expected ten adaptive operating points.');

fprintf('Test 3 passed: Ten adaptive decisions.\n');

%% Test 4: Valid PER range

assert(all(V.PER >= 0 & V.PER <= 1), ...
    'Invalid PER value.');

assert(all(V.PER_Upper95 >= V.PER_Lower95), ...
    'Invalid confidence interval.');

fprintf('Test 4 passed: PER and confidence intervals.\n');

%% Test 5: Validation QoS flag

assert(all(A.QoS_Met_Validation == ...
    (A.PER_Upper95 <= cfg.TargetPER)), ...
    'Validation QoS flags are inconsistent.');

fprintf('Test 5 passed: Validation QoS flags.\n');

%% Test 6: Calibration-to-validation mapping

assert(all(A.InterleaverDepth > 0), ...
    'Invalid selected interleaver depth.');

assert(all(ismember(A.Modulation, ["BPSK","QPSK","16QAM"])), ...
    'Unsupported selected modulation.');

fprintf('Test 6 passed: Adaptive profile mapping.\n');

%% Test 7: Fixed baseline comparison

assert(height(M) == 4, ...
    'Expected four comparison methods.');

assert(all(M.TotalOperatingPoints == 10), ...
    'Every method must include ten operating points.');

fprintf('Test 7 passed: Fixed baseline comparison.\n');

%% Test 8: Effective spectral efficiency

assert(all(V.EffectiveSpectralEfficiency > 0), ...
    'Invalid spectral efficiency.');

fprintf('Test 8 passed: Effective spectral efficiency.\n');

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ALL VALIDATION TESTS PASSED\n');
fprintf('=============================================\n');
