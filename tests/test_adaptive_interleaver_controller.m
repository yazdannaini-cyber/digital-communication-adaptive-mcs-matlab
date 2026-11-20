clc;
clear;
close all;

%% Add project folders to MATLAB path

testDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testDir);

addpath(genpath(projectRoot));
rehash;

%% Verify controller availability

assert(exist('select_interleaver_depth', 'file') == 2, ...
    ['Controller not found. Save it as: ', ...
     'src/control/select_interleaver_depth.m']);

fprintf('Controller successfully located.\n\n');
fprintf('Starting Adaptive Interleaver Controller Tests...\n\n');

%% Test 1: Rayleigh at 4 dB
% Neither depth satisfies targetPER = 0.20.
% The controller should select Depth 16 as fallback.

[depth, decision] = ...
    select_interleaver_depth('Rayleigh', 4, 0.20);

assert(depth == 16);
assert(~decision.targetMet);

fprintf('Test 1 passed: Rayleigh fallback selection.\n');

%% Test 2: Rician at 10 dB
% Depth 4 satisfies the target and should be selected.

[depth, decision] = ...
    select_interleaver_depth('Rician', 10, 0.20);

assert(depth == 4);
assert(decision.targetMet);

fprintf('Test 2 passed: Minimum depth satisfying QoS.\n');

%% Test 3: Rician at 8 dB
% Neither depth satisfies the target.

[depth, decision] = ...
    select_interleaver_depth('Rician', 8, 0.20);

assert(depth == 16);
assert(~decision.targetMet);

fprintf('Test 3 passed: Unsatisfied QoS fallback.\n');

%% Test 4: Depth 16 satisfies target while Depth 4 does not.

[depth, decision] = ...
    select_interleaver_depth('Rician', 10, 0.17);

assert(depth == 16);
assert(decision.targetMet);

fprintf('Test 4 passed: Depth 16 selected when only it meets QoS.\n');

%% Test 5: Case-insensitive channel name

[depth, decision] = ...
    select_interleaver_depth('rIcIaN', 12, 0.10);

assert(depth == 4);
assert(decision.targetMet);

fprintf('Test 5 passed: Case-insensitive channel handling.\n');

%% Test 6: Unsupported SNR detection

errorDetected = false;

try
    select_interleaver_depth('Rayleigh', 7, 0.20);
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 6 passed: Unsupported SNR detection.\n');

%% Test 7: Unsupported channel detection

errorDetected = false;

try
    select_interleaver_depth('AWGN', 8, 0.20);
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 7 passed: Unsupported channel detection.\n');

%% Test 8: Invalid target PER detection

errorDetected = false;

try
    select_interleaver_depth('Rayleigh', 8, 1.0);
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 8 passed: Invalid target PER detection.\n');

%% Test 9: Decision report fields

[depth, decision] = ...
    select_interleaver_depth('Rician', 10, 0.20);

assert(isfield(decision, 'depth4Upper95'));
assert(isfield(decision, 'depth16Upper95'));
assert(isfield(decision, 'selectedDepth'));
assert(isfield(decision, 'targetMet'));
assert(isfield(decision, 'reason'));

fprintf('Test 9 passed: Decision report validation.\n');

fprintf('\nAll Adaptive Interleaver Controller Tests Passed.\n');
