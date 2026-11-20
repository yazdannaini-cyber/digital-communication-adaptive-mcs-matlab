
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

%% Test 1: BPSK Throughput

[gross, correct] = ...
    calculate_throughput(1e6, 1, 0.01);

assert(gross == 1e6);

assert(abs(correct - 990000) < 1e-9);

fprintf('Test 1 passed: BPSK throughput.\n');

%% Test 2: QPSK Throughput

[gross, correct] = ...
    calculate_throughput(1e6, 2, 0.01);

assert(gross == 2e6);

assert(abs(correct - 1980000) < 1e-9);

fprintf('Test 2 passed: QPSK throughput.\n');

%% Test 3: 16-QAM Throughput

[gross, correct] = ...
    calculate_throughput(1e6, 4, 0.01);

assert(gross == 4e6);

assert(abs(correct - 3960000) < 1e-9);

fprintf('Test 3 passed: 16-QAM throughput.\n');

%% Test 4: Zero BER

[gross, correct] = ...
    calculate_throughput(1e6, 4, 0);

assert(gross == correct);

fprintf('Test 4 passed: Zero BER condition.\n');

%% Test 5: Spectral Efficiency - BPSK

eta = calculate_spectral_efficiency(1, 0.25);

assert(abs(eta - 0.8) < 1e-12);

fprintf('Test 5 passed: BPSK spectral efficiency.\n');

%% Test 6: Spectral Efficiency - QPSK

eta = calculate_spectral_efficiency(2, 0.25);

assert(abs(eta - 1.6) < 1e-12);

fprintf('Test 6 passed: QPSK spectral efficiency.\n');

%% Test 7: Spectral Efficiency - 16-QAM

eta = calculate_spectral_efficiency(4, 0.25);

assert(abs(eta - 3.2) < 1e-12);

fprintf('Test 7 passed: 16-QAM spectral efficiency.\n');

%% Test 8: Ideal Roll-off

eta = calculate_spectral_efficiency(4, 0);

assert(eta == 4);

fprintf('Test 8 passed: Ideal Nyquist condition.\n');

%% Test 9: Invalid Roll-off

invalidDetected = false;

try

    calculate_spectral_efficiency(4, 1.5);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 9 passed: Invalid roll-off detection.\n');

%% Test 10: Invalid BER

invalidDetected = false;

try

    calculate_throughput(1e6, 4, 1.2);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 10 passed: Invalid BER detection.\n');

%% Final Result

fprintf('\nAll system metric tests passed successfully.\n');
