clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

%% Test 1: Perfect Transmission

originalBits = [0 1 1 0 1 0 0 1];

txSymbols = bpsk_modulator(originalBits);

detectedBits = bpsk_demodulator(txSymbols);

assert(isequal(originalBits, detectedBits), ...
    'Perfect transmission test failed.');

fprintf('Test 1 passed: Perfect transmission.\n');

%% Test 2: Decision Rule

testSignals = [-2 -0.5 -0.001 0 0.001 0.5 2];

expectedBits = [1 1 1 0 0 0 0];

detectedBits = bpsk_demodulator(testSignals);

assert(isequal(detectedBits, expectedBits), ...
    'Decision threshold test failed.');

fprintf('Test 2 passed: Decision threshold.\n');

%% Test 3: Output Length

rxSymbols = [-0.8 0.3 1.2 -0.4 0.1];

rxBits = bpsk_demodulator(rxSymbols);

assert(numel(rxBits) == numel(rxSymbols), ...
    'Output length test failed.');

fprintf('Test 3 passed: Output length.\n');

%% Test 4: Output Values

assert(all(rxBits == 0 | rxBits == 1), ...
    'Receiver output must be binary.');

fprintf('Test 4 passed: Binary output.\n');
%% Test 5: Valid Noisy Received Samples

testSignals = [1 0 -1];

expectedBits = [0 0 1];

detectedBits = bpsk_demodulator(testSignals);

assert(isequal(detectedBits, expectedBits), ...
    'Valid noisy samples test failed.');

fprintf('Test 5 passed: Valid received samples.\n');

%% Test 6: Invalid Input Detection

invalidInputs = {
    []
    [1 NaN -1]
    [1 1i -1]
    [1 0; -1 1]
    'abc'
};

for k = 1:length(invalidInputs)

    invalidDetected = false;

    try

        bpsk_demodulator(invalidInputs{k});

    catch

        invalidDetected = true;

    end

    assert(invalidDetected, ...
        'Invalid input was not detected.');

end

fprintf('Test 6 passed: Invalid input detection.\n');



%% Test: Complex Received Samples

complexSignals = [ ...
     0.5+0.7i, ...
    -0.2+0.9i, ...
     0.0-1.0i, ...
    -0.8-0.1i];

expectedBits = [0 1 0 1];

detectedBits = bpsk_demodulator(complexSignals);

assert(isequal(detectedBits, expectedBits));

fprintf('Test passed: Complex BPSK samples.\n');

%% Final Result

fprintf('\nAll BPSK receiver tests passed successfully.\n');

%% Final Result

fprintf('\nAll BPSK receiver tests passed successfully.\n');