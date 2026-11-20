clc;
clear;
close all;

% Find project root and add folders to MATLAB path
testFolder = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFolder);
addpath(genpath(projectRoot));

% Reproducibility
rng(42);

%% Test 1: Bit Generation

N = 10000;

bits = generate_bits(N);

assert(numel(bits) == N, ...
    'Incorrect number of generated bits.');

assert(all(bits == 0 | bits == 1), ...
    'Generated bits must be binary.');

fprintf('Test 1 passed: Bit generation.\n');

%% Test 2: BPSK Modulation

symbols = bpsk_modulator(bits);

assert(numel(symbols) == N, ...
    'Number of symbols does not match number of bits.');

assert(all(symbols == -1 | symbols == 1), ...
    'BPSK symbols must be either -1 or +1.');

fprintf('Test 2 passed: BPSK output values.\n');

%% Test 3: Mapping Verification

assert(all(symbols(bits == 0) == 1), ...
    'Bit 0 must map to +1.');

assert(all(symbols(bits == 1) == -1), ...
    'Bit 1 must map to -1.');

fprintf('Test 3 passed: Mapping verification.\n');

%% Test 4: Explicit Mapping Example

testBits = [0 1 1 0];

expectedSymbols = [1 -1 -1 1];

actualSymbols = bpsk_modulator(testBits);

assert(isequal(actualSymbols, expectedSymbols), ...
    'Explicit mapping test failed.');

fprintf('Test 4 passed: Example sequence.\n');

%% Test 5: Symbol Energy

symbolEnergy = mean(abs(symbols).^2);

assert(abs(symbolEnergy - 1) < 1e-12, ...
    'Average symbol energy must equal 1.');

fprintf('Test 5 passed: Unit energy.\n');

%% Display Results

fprintf('\nAll transmitter tests passed successfully.\n');

fprintf('Number of bits: %d\n', N);

fprintf('Average symbol energy: %.4f\n', symbolEnergy);

fprintf('First 20 bits:\n');

disp(bits(1:20));

fprintf('First 20 BPSK symbols:\n');

disp(symbols(1:20));