
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

%% Test 1: Known Number of Errors

txBits = [0 1 1 0 1];

rxBits = [0 1 0 0 1];

[ber, numErrors] = calculate_ber(txBits, rxBits);

assert(numErrors == 1);

assert(abs(ber - 0.2) < 1e-12);

fprintf('Test 1 passed: BER calculation.\n');

%% Test 2: Zero Errors

txBits = [0 1 1 0 1];

rxBits = [0 1 1 0 1];

[ber, numErrors] = calculate_ber(txBits, rxBits);

assert(numErrors == 0);

assert(ber == 0);

fprintf('Test 2 passed: Zero-error condition.\n');

%% Test 3: All Bits Incorrect

txBits = [0 1 1 0];

rxBits = [1 0 0 1];

[ber, numErrors] = calculate_ber(txBits, rxBits);

assert(numErrors == 4);

assert(ber == 1);

fprintf('Test 3 passed: Maximum BER.\n');

%% Test 4: Column Vector

txBits = [0; 1; 0; 1];

rxBits = [0; 1; 1; 1];

[ber, numErrors] = calculate_ber(txBits, rxBits);

assert(numErrors == 1);

assert(abs(ber - 0.25) < 1e-12);

fprintf('Test 4 passed: Column vector support.\n');

%% Test 5: Invalid Input

invalidDetected = false;

try

    calculate_ber([0 1 2], [0 1 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 5 passed: Invalid binary input.\n');

%% Test 6: Unequal Vector Lengths

invalidDetected = false;

try

    calculate_ber([0 1 1], [0 1]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 6 passed: Unequal vector length detection.\n');

%% Final Result

fprintf('\nAll BER calculator tests passed successfully.\n');
