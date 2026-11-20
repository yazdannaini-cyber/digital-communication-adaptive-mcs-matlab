
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFolder);
addpath(genpath(projectRoot));

%% Test 1: Gray Mapping Verification

testBits = [0 0  0 1  1 0  1 1];

expectedSymbols = [ ...
     1+1i, ...
     1-1i, ...
    -1+1i, ...
    -1-1i] / sqrt(2);

actualSymbols = qpsk_modulator(testBits);

assert(max(abs(actualSymbols - expectedSymbols)) < 1e-12);

fprintf('Test 1 passed: Gray mapping verification.\n');

%% Test 2: Number of Symbols

assert(numel(actualSymbols) == numel(testBits)/2);

fprintf('Test 2 passed: Number of output symbols.\n');

%% Test 3: Unit Average Symbol Energy

symbolEnergy = mean(abs(actualSymbols).^2);

assert(abs(symbolEnergy - 1) < 1e-12);

fprintf('Test 3 passed: Unit symbol energy.\n');

%% Test 4: Perfect Modulation and Demodulation

recoveredBits = qpsk_demodulator(actualSymbols);

assert(isequal(recoveredBits, testBits));

fprintf('Test 4 passed: Perfect transmission.\n');

%% Test 5: Decision Regions

testSignals = [ ...
     1+1i, ...
     1-1i, ...
    -1+1i, ...
    -1-1i, ...
     0+0i];

expectedBits = [ ...
    0 0, ...
    0 1, ...
    1 0, ...
    1 1, ...
    0 0];

detectedBits = qpsk_demodulator(testSignals);

assert(isequal(detectedBits, expectedBits));

fprintf('Test 5 passed: I/Q decision regions.\n');

%% Test 6: Odd Number of Input Bits

invalidDetected = false;

try
    qpsk_modulator([0 1 1]);

catch
    invalidDetected = true;
end

assert(invalidDetected);

fprintf('Test 6 passed: Odd input length detection.\n');

%% Test 7: Invalid Binary Input

invalidDetected = false;

try
    qpsk_modulator([0 1 2 0]);

catch
    invalidDetected = true;
end

assert(invalidDetected);

fprintf('Test 7 passed: Invalid bit detection.\n');

%% Test 8: Invalid Receiver Input

invalidDetected = false;

try
    qpsk_demodulator([1 NaN+1i]);

catch
    invalidDetected = true;
end

assert(invalidDetected);

fprintf('Test 8 passed: Invalid receiver input detection.\n');

%% Final Result

fprintf('\nAll QPSK tests passed successfully.\n');
