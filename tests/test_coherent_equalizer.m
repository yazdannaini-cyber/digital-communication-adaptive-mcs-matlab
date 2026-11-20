
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFolder);
addpath(genpath(projectRoot));

rng(42);

%% Generate QPSK Symbols

N = 10000;

bits = generate_bits(2*N);

txSymbols = qpsk_modulator(bits);

%% Test 1: Perfect Channel Equalization

h = (randn(size(txSymbols)) + ...
     1i*randn(size(txSymbols))) / sqrt(2);

rxSymbols = h .* txSymbols;

equalizedSymbols = coherent_equalizer(rxSymbols,h);

assert(max(abs(equalizedSymbols-txSymbols)) < 1e-12);

fprintf('Test 1 passed: Perfect channel equalization.\n');

%% Test 2: Recovery of Original Bits

rxBits = qpsk_demodulator(equalizedSymbols);

assert(isequal(rxBits,bits));

fprintf('Test 2 passed: Bit recovery after equalization.\n');

%% Test 3: Channel Phase Compensation

h = 0.7 * exp(1i*pi/3) * ones(size(txSymbols));

rxSymbols = h .* txSymbols;

equalizedSymbols = coherent_equalizer(rxSymbols,h);

assert(max(abs(equalizedSymbols-txSymbols)) < 1e-12);

fprintf('Test 3 passed: Channel phase compensation.\n');

%% Test 4: Channel Amplitude Compensation

h = 0.35 * ones(size(txSymbols));

rxSymbols = h .* txSymbols;

equalizedSymbols = coherent_equalizer(rxSymbols,h);

assert(max(abs(equalizedSymbols-txSymbols)) < 1e-12);

fprintf('Test 4 passed: Channel amplitude compensation.\n');

%% Test 5: Column Vector Support

txColumn = txSymbols(:);

hColumn = h(:);

rxColumn = hColumn .* txColumn;

equalizedColumn = coherent_equalizer(rxColumn,hColumn);

assert(max(abs(equalizedColumn-txColumn)) < 1e-12);

fprintf('Test 5 passed: Column vector support.\n');

%% Test 6: Zero Channel Coefficient Detection

invalidDetected = false;

try

    coherent_equalizer([1+1i 2+2i],[1 0]);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 6 passed: Zero channel detection.\n');

%% Final Result

fprintf('\nAll coherent equalizer tests passed successfully.\n');
