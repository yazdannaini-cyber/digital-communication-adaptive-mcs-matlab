
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

%% Test 1: All 16 Gray-Mapped Symbols

bitWords = dec2bin(0:15, 4);

allBits = reshape(bitWords.' - '0', 1, []);

actualSymbols = qam16_modulator(allBits);

expectedSymbols = [ ...
     3+3i,  3+1i,  3-3i,  3-1i, ...
     1+3i,  1+1i,  1-3i,  1-1i, ...
    -3+3i, -3+1i, -3-3i, -3-1i, ...
    -1+3i, -1+1i, -1-3i, -1-1i] / sqrt(10);

assert(max(abs(actualSymbols - expectedSymbols)) < 1e-12);

fprintf('Test 1 passed: All 16 constellation mappings.\n');

%% Test 2: Number of Output Symbols

assert(numel(actualSymbols) == 16);

fprintf('Test 2 passed: Number of symbols.\n');

%% Test 3: Unique Constellation Points

assert(numel(unique(actualSymbols)) == 16);

fprintf('Test 3 passed: 16 unique constellation points.\n');

%% Test 4: Average Symbol Energy

symbolEnergy = mean(abs(actualSymbols).^2);

assert(abs(symbolEnergy - 1) < 1e-12);

fprintf('Test 4 passed: Unit average symbol energy.\n');

%% Test 5: Constellation Levels

Ilevels = sort(unique(round(real(actualSymbols(:))*sqrt(10))));

Qlevels = sort(unique(round(imag(actualSymbols(:))*sqrt(10))));

expectedLevels = [-3; -1; 1; 3];

assert(isequal(Ilevels, expectedLevels), ...
    'Incorrect I-axis constellation levels.');

assert(isequal(Qlevels, expectedLevels), ...
    'Incorrect Q-axis constellation levels.');

fprintf('Test 5 passed: I/Q constellation levels.\n');

%% Test 6: Perfect Modulation and Demodulation

recoveredBits = qam16_demodulator(actualSymbols);

assert(isequal(recoveredBits, allBits));

fprintf('Test 6 passed: Perfect transmission.\n');

%% Test 7: Column Vector Support

columnBits = allBits.';

columnSymbols = qam16_modulator(columnBits);

columnRecoveredBits = qam16_demodulator(columnSymbols);

assert(isequal(columnRecoveredBits, allBits));

fprintf('Test 7 passed: Column vector support.\n');

%% Test 8: Invalid Bit Count

invalidDetected = false;

try

    qam16_modulator([0 1 1 0 1]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 8 passed: Invalid bit count detection.\n');

%% Test 9: Invalid Binary Input

invalidDetected = false;

try

    qam16_modulator([0 1 2 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 9 passed: Invalid bit detection.\n');

%% Test 10: Invalid Receiver Input

invalidDetected = false;

try

    qam16_demodulator([1 NaN+1i]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 10 passed: Invalid receiver input detection.\n');

%% Final Result

fprintf('\nAll 16-QAM tests passed successfully.\n');

fprintf('Number of constellation points: %d\n', ...
    numel(actualSymbols));

fprintf('Average symbol energy: %.4f\n', symbolEnergy);
