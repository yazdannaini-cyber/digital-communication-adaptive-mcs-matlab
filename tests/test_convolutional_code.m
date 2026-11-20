clc;
clear;
close all;

%% PROJECT SETUP

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

fprintf('\n============================================\n');
fprintf('CONVOLUTIONAL CODE TESTS\n');
fprintf('============================================\n');

%% TEST 1: KNOWN ENCODER OUTPUT

inputBits = [1 0 1 1];

expectedBits = [ ...
    1 1 1 0 0 0 0 1 0 1 1 1];

codedBits = convolutional_encoder(inputBits);

assert(isequal(codedBits,expectedBits));

fprintf('Test 1 passed: Known encoder output.\n');

%% TEST 2: CODED LENGTH

assert(numel(codedBits)==2*(numel(inputBits)+2));

fprintf('Test 2 passed: Encoded output length.\n');

%% TEST 3: BINARY OUTPUT

assert(all(codedBits==0 | codedBits==1));

fprintf('Test 3 passed: Binary encoded output.\n');

%% TEST 4: ERROR-FREE DECODING

[decodedBits,pathMetric] = ...
    viterbi_decoder_hard(codedBits);

assert(isequal(decodedBits,inputBits));

assert(pathMetric==0);

fprintf('Test 4 passed: Error-free Viterbi decoding.\n');

%% TEST 5: RANDOM DATA

rng(42);

randomBits = randi([0 1],1,10000);

randomCoded = convolutional_encoder(randomBits);

randomDecoded = viterbi_decoder_hard(randomCoded);

assert(isequal(randomBits,randomDecoded));

fprintf('Test 5 passed: Random data recovery.\n');

%% TEST 6: SINGLE CODED BIT ERROR

testBits = randi([0 1],1,100);

testCoded = convolutional_encoder(testBits);

corrupted = testCoded;

corrupted(5) = 1-corrupted(5);

recovered = viterbi_decoder_hard(corrupted);

assert(isequal(testBits,recovered));

fprintf('Test 6 passed: Single-bit error correction.\n');

%% TEST 7: ALL SINGLE-BIT ERROR POSITIONS

for k = 1:numel(testCoded)

    corrupted = testCoded;

    corrupted(k) = 1-corrupted(k);

    recovered = viterbi_decoder_hard(corrupted);

    assert(isequal(testBits,recovered));

end

fprintf('Test 7 passed: All single-bit error positions.\n');

%% TEST 8: MULTIPLE INPUT BLOCKS

multiBits = randi([0 1],1,400);

multiCoded = convolutional_encoder(multiBits);

multiDecoded = viterbi_decoder_hard(multiCoded);

assert(isequal(multiBits,multiDecoded));

fprintf('Test 8 passed: Multiple data blocks.\n');

%% TEST 9: COLUMN VECTOR SUPPORT

columnBits = testBits.';

columnCoded = convolutional_encoder(columnBits);

columnDecoded = viterbi_decoder_hard(columnCoded.');

assert(isequal(testBits,columnDecoded));

fprintf('Test 9 passed: Column vector support.\n');

%% TEST 10: INVALID ENCODER INPUT

invalidDetected = false;

try

    convolutional_encoder([0 1 2 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 10 passed: Invalid encoder input detection.\n');

%% TEST 11: INVALID DECODER INPUT

invalidDetected = false;

try

    viterbi_decoder_hard([0 1 0 2]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 11 passed: Invalid decoder input detection.\n');

%% TEST 12: NON-FINITE INPUT

invalidDetected = false;

try

    convolutional_encoder([0 1 NaN 1]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 12 passed: Non-finite input detection.\n');

%% TEST 13: ODD RECEIVED LENGTH

invalidDetected = false;

try

    viterbi_decoder_hard([0 1 1 0 1]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 13 passed: Odd length detection.\n');

%% TEST 14: INSUFFICIENT INPUT LENGTH

invalidDetected = false;

try

    viterbi_decoder_hard([0 1 1 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 14 passed: Insufficient input detection.\n');

%% FINAL RESULT

fprintf('\n============================================\n');
fprintf('ALL CONVOLUTIONAL CODE TESTS PASSED\n');
fprintf('============================================\n');