clc;
clear;
close all;

%% PROJECT SETUP

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

rng(42);

fprintf('\n============================================\n');
fprintf('SOFT-DECISION VITERBI TESTS\n');
fprintf('============================================\n');

%% TEST 1: ERROR-FREE DECODING

bits = randi([0 1],1,100);

codedBits = convolutional_encoder(bits);

amplitude = sqrt(0.5);

rxSamples = amplitude*(1-2*codedBits);

[decoded,pathMetric] = ...
    viterbi_decoder_soft(rxSamples,amplitude);

assert(isequal(bits,decoded));

assert(abs(pathMetric)<1e-10);

fprintf('Test 1 passed: Error-free soft decoding.\n');

%% TEST 2: DEFAULT AMPLITUDE

bits = [1 0 1 1 0 1 0];

codedBits = convolutional_encoder(bits);

rxSamples = 1-2*codedBits;

decoded = viterbi_decoder_soft(rxSamples);

assert(isequal(bits,decoded));

fprintf('Test 2 passed: Default symbol amplitude.\n');

%% TEST 3: COLUMN VECTOR

bits = randi([0 1],1,100);

codedBits = convolutional_encoder(bits);

rxSamples = (sqrt(0.5)*(1-2*codedBits)).';

decoded = viterbi_decoder_soft(rxSamples,sqrt(0.5));

assert(isequal(bits,decoded));

fprintf('Test 3 passed: Column vector support.\n');

%% TEST 4: ALL SINGLE-BIT ERROR POSITIONS

bits = randi([0 1],1,50);

codedBits = convolutional_encoder(bits);

amplitude = sqrt(0.5);

originalSamples = amplitude*(1-2*codedBits);

for k = 1:numel(codedBits)

    corruptedSamples = originalSamples;

    corruptedSamples(k) = -corruptedSamples(k);

    decoded = viterbi_decoder_soft( ...
        corruptedSamples,amplitude);

    assert(isequal(bits,decoded));

end

fprintf('Test 4 passed: All single-bit errors corrected.\n');

%% TEST 5: LOW-LEVEL GAUSSIAN NOISE

bits = randi([0 1],1,1000);

codedBits = convolutional_encoder(bits);

amplitude = sqrt(0.5);

rxSamples = amplitude*(1-2*codedBits) ...
    + 0.02*randn(size(codedBits));

decoded = viterbi_decoder_soft(rxSamples,amplitude);

assert(isequal(bits,decoded));

fprintf('Test 5 passed: Low-noise soft decoding.\n');

%% TEST 6: RANDOM DATA RECOVERY

bits = randi([0 1],1,10000);

codedBits = convolutional_encoder(bits);

amplitude = sqrt(0.5);

rxSamples = amplitude*(1-2*codedBits);

decoded = viterbi_decoder_soft(rxSamples,amplitude);

assert(isequal(bits,decoded));

fprintf('Test 6 passed: Random data recovery.\n');

%% TEST 7: NON-BINARY SAMPLES ARE ACCEPTED

bits = [1 0 1 0 1];

codedBits = convolutional_encoder(bits);

amplitude = sqrt(0.5);

rxSamples = amplitude*(1-2*codedBits);

rxSamples(3) = rxSamples(3)+0.1;

decoded = viterbi_decoder_soft(rxSamples,amplitude);

assert(isequal(bits,decoded));

fprintf('Test 7 passed: Analog sample input support.\n');

%% TEST 8: INVALID INPUT TYPE

invalidDetected = false;

try

    viterbi_decoder_soft({'0','1','0','1'});

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 8 passed: Invalid input type detection.\n');

%% TEST 9: NON-FINITE INPUT

invalidDetected = false;

try

    viterbi_decoder_soft([0 1 NaN 0 1 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 9 passed: Non-finite input detection.\n');

%% TEST 10: COMPLEX INPUT

invalidDetected = false;

try

    viterbi_decoder_soft([1+1i 0 1 0 1 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 10 passed: Complex input detection.\n');

%% TEST 11: INVALID AMPLITUDE

invalidDetected = false;

try

    viterbi_decoder_soft([1 0 1 0 1 0],0);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 11 passed: Invalid amplitude detection.\n');

%% TEST 12: ODD INPUT LENGTH

invalidDetected = false;

try

    viterbi_decoder_soft([1 0 1 0 1]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 12 passed: Odd input length detection.\n');

%% TEST 13: INSUFFICIENT INPUT LENGTH

invalidDetected = false;

try

    viterbi_decoder_soft([1 0 1 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 13 passed: Insufficient input detection.\n');

%% TEST 14: OUTPUT LENGTH

bits = randi([0 1],1,500);

codedBits = convolutional_encoder(bits);

rxSamples = sqrt(0.5)*(1-2*codedBits);

decoded = viterbi_decoder_soft(rxSamples,sqrt(0.5));

assert(numel(decoded)==numel(bits));

fprintf('Test 14 passed: Output length validation.\n');

%% FINAL RESULT

fprintf('\n============================================\n');
fprintf('ALL SOFT-DECISION VITERBI TESTS PASSED\n');
fprintf('============================================\n');