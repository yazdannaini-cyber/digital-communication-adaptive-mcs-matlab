
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFolder);
addpath(genpath(projectRoot));

%% Test 1: Known Number of Block Errors

flags = [0 1 0 0 1 1 0 0];

[bler,numErrors] = calculate_bler(flags);

assert(numErrors == 3);

assert(bler == 3/8);

fprintf('Test 1 passed: BLER calculation.\n');

%% Test 2: Zero Block Errors

flags = [0 0 0 0 0];

[bler,numErrors] = calculate_bler(flags);

assert(numErrors == 0);

assert(bler == 0);

fprintf('Test 2 passed: Zero-error condition.\n');

%% Test 3: All Blocks Incorrect

flags = [1 1 1 1];

[bler,numErrors] = calculate_bler(flags);

assert(numErrors == 4);

assert(bler == 1);

fprintf('Test 3 passed: Maximum BLER.\n');

%% Test 4: Column Vector Support

flags = [0;1;0;1;0];

[bler,numErrors] = calculate_bler(flags);

assert(numErrors == 2);

assert(abs(bler-0.4)<1e-12);

fprintf('Test 4 passed: Column vector support.\n');

%% Test 5: Logical Input

flags = logical([0 1 0 1]);

[bler,numErrors] = calculate_bler(flags);

assert(numErrors == 2);

assert(bler == 0.5);

fprintf('Test 5 passed: Logical input support.\n');

%% Test 6: Invalid Input

invalidDetected = false;

try

    calculate_bler([0 1 2 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 6 passed: Invalid flag detection.\n');

%% Test 7: Empty Input

invalidDetected = false;

try

    calculate_bler([]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 7 passed: Empty input detection.\n');

%% Final Result

fprintf('\nAll BLER calculator tests passed successfully.\n');
