
clc;
clear;
close all;

rng(42);

%% PROJECT PATH

testDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testDir);

addpath(genpath(projectRoot));
rehash;

fprintf('Starting Cost-Aware Interleaver Tests...\n\n');

%% 1. Create deterministic cost profile for controller tests

testProfile = struct();

testProfile.Depths = [4 16];

testProfile.TotalProcessingTimeMs = [0.02 0.03];

testProfile.FirstColumnReadyMs = [1.572 1.965];

testProfile.StreamingBufferBits = [1572 1965];

testProfile.StreamingBufferBytes = [197 246];

testProfile.TotalCostScoreMs = ...
    testProfile.FirstColumnReadyMs + ...
    testProfile.TotalProcessingTimeMs;

%% Test 1: Both depths meet QoS
% Rician at 10 dB, target PER = 0.20.
% Depth 4 has lower combined cost.

[depth, decision] = ...
    select_interleaver_depth_cost_aware( ...
    'Rician', 10, 0.20, 2.0, testProfile);

assert(depth == 4);
assert(decision.targetMet);
assert(decision.delayMet);

fprintf('Test 1 passed: Lowest-cost QoS-feasible depth.\n');

%% Test 2: Neither depth meets QoS
% Select depth with the better PER confidence bound.

[depth, decision] = ...
    select_interleaver_depth_cost_aware( ...
    'Rayleigh', 10, 0.20, 2.0, testProfile);

assert(depth == 16);
assert(~decision.targetMet);
assert(decision.delayMet);

fprintf('Test 2 passed: Reliability-oriented fallback.\n');

%% Test 3: Depth 16 violates delay constraint
% Depth 4 still meets QoS and latency.

[depth, decision] = ...
    select_interleaver_depth_cost_aware( ...
    'Rician', 10, 0.20, 1.6, testProfile);

assert(depth == 4);
assert(decision.targetMet);
assert(decision.delayMet);

fprintf('Test 3 passed: Latency-constrained selection.\n');

%% Test 4: Neither depth meets delay constraint
% Choose the minimum-delay candidate and report violation.

[depth, decision] = ...
    select_interleaver_depth_cost_aware( ...
    'Rician', 10, 0.20, 1.0, testProfile);

assert(depth == 4);
assert(decision.targetMet);
assert(~decision.delayMet);

fprintf('Test 4 passed: Delay violation reporting.\n');

%% Test 5: Neither depth meets QoS at Rician 8 dB

[depth, decision] = ...
    select_interleaver_depth_cost_aware( ...
    'Rician', 8, 0.20, 2.0, testProfile);

assert(depth == 16);
assert(~decision.targetMet);

fprintf('Test 5 passed: Rician fallback selection.\n');

%% Test 6: Invalid delay detection

errorDetected = false;

try
    select_interleaver_depth_cost_aware( ...
        'Rician', 10, 0.20, 0, testProfile);
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 6 passed: Invalid delay detection.\n');

%% Test 7: Unsupported channel detection

errorDetected = false;

try
    select_interleaver_depth_cost_aware( ...
        'AWGN', 10, 0.20, 2.0, testProfile);
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 7 passed: Unsupported channel detection.\n');

%% Test 8: Invalid cost profile detection

errorDetected = false;

invalidProfile = rmfield(testProfile, 'TotalCostScoreMs');

try
    select_interleaver_depth_cost_aware( ...
        'Rician', 10, 0.20, 2.0, invalidProfile);
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 8 passed: Invalid cost profile detection.\n');

%% Test 9: Invalid SNR detection

errorDetected = false;

try
    select_interleaver_depth_cost_aware( ...
        'Rician', 7, 0.20, 2.0, testProfile);
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 9 passed: Unsupported SNR detection.\n');

%% 10. Benchmark actual interleaver implementation

fprintf('\nRunning actual MATLAB cost benchmark...\n');

numBits = 2096;
symbolRate = 1e6;

actualProfile = measure_interleaver_cost( ...
    numBits, symbolRate, [4 16]);

%% Validate structural model

assert(isequal(actualProfile.Depths, [4 16]));

assert(abs(actualProfile.FirstColumnReadyMs(1) - 1.573) < 1e-9);

assert(abs(actualProfile.FirstColumnReadyMs(2) - 1.966) < 1e-9);

assert(isequal(actualProfile.StreamingBufferBits, [1573 1966]));

assert(all(actualProfile.TotalProcessingTimeMs >= 0));

assert(all(actualProfile.FrameDurationMs == 2.096));

fprintf('Test 10 passed: Actual benchmark and structural model.\n');

%% Display measured cost profile

costTable = table( ...
    actualProfile.Depths(:), ...
    actualProfile.NumColumns(:), ...
    actualProfile.InterleaverTimeMs(:), ...
    actualProfile.DeinterleaverTimeMs(:), ...
    actualProfile.TotalProcessingTimeMs(:), ...
    actualProfile.FirstColumnReadyMs(:), ...
    actualProfile.StreamingBufferBits(:), ...
    actualProfile.StreamingBufferBytes(:), ...
    actualProfile.FrameDurationMs(:), ...
    actualProfile.TotalCostScoreMs(:), ...
    'VariableNames', { ...
    'Depth', ...
    'NumColumns', ...
    'InterleaverTime_ms', ...
    'DeinterleaverTime_ms', ...
    'TotalProcessingTime_ms', ...
    'FirstColumnReady_ms', ...
    'StreamingBuffer_bits', ...
    'StreamingBuffer_bytes', ...
    'FrameDuration_ms', ...
    'CostScore_ms'});

fprintf('\nACTUAL INTERLEAVER COST PROFILE\n');
fprintf('===============================\n');

disp(costTable);

%% Save benchmark profile

resultsDir = fullfile(projectRoot, 'results');

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

writetable(costTable, ...
    fullfile(resultsDir, 'interleaver_cost_profile.csv'));

save(fullfile(resultsDir, 'interleaver_cost_profile.mat'), ...
    'actualProfile');

fprintf('\nTest 10 passed: Benchmark files saved.\n');

fprintf('\nAll Cost-Aware Interleaver Tests Passed Successfully.\n');
