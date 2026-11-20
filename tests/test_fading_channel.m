
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFolder);
addpath(genpath(projectRoot));

rng(42);

%% Simulation Parameters

N = 200000;
EbN0_dB = 6;
K_dB = 6;

bits = generate_bits(2*N);
txSymbols = qpsk_modulator(bits);

gamma = 10^(EbN0_dB/10);

expectedNoiseVariance = 1/(4*gamma);

%% =========================================
% Test 1: Rayleigh Channel
% ==========================================

[rxRayleigh,hRayleigh,noiseRayleigh,varRayleigh] = ...
    fading_channel(txSymbols,EbN0_dB,2,1,'Rayleigh');

assert(numel(rxRayleigh) == N);
assert(numel(hRayleigh) == N);
assert(numel(noiseRayleigh) == N);

fprintf('Test 1 passed: Rayleigh output lengths.\n');

%% Test 2: Rayleigh Channel Equation

assert(max(abs(rxRayleigh - ...
    hRayleigh.*txSymbols - noiseRayleigh)) < 1e-12);

fprintf('Test 2 passed: Rayleigh channel equation.\n');

%% Test 3: Rayleigh Average Channel Power

rayleighPower = mean(abs(hRayleigh).^2);

assert(abs(rayleighPower-1) < 0.02);

fprintf('Test 3 passed: Rayleigh average power.\n');

%% Test 4: Rayleigh Noise Variance

assert(abs(varRayleigh-expectedNoiseVariance) < 1e-12);

assert(abs(var(real(noiseRayleigh),1)- ...
    expectedNoiseVariance)/expectedNoiseVariance < 0.02);

assert(abs(var(imag(noiseRayleigh),1)- ...
    expectedNoiseVariance)/expectedNoiseVariance < 0.02);

fprintf('Test 4 passed: Rayleigh noise statistics.\n');

%% =========================================
% Test 5: Rician Channel
% ==========================================

[rxRician,hRician,noiseRician,varRician] = ...
    fading_channel(txSymbols,EbN0_dB,2,1,'Rician',K_dB);

assert(numel(rxRician) == N);
assert(numel(hRician) == N);
assert(numel(noiseRician) == N);

fprintf('Test 5 passed: Rician output lengths.\n');

%% Test 6: Rician Channel Equation

assert(max(abs(rxRician - ...
    hRician.*txSymbols - noiseRician)) < 1e-12);

fprintf('Test 6 passed: Rician channel equation.\n');

%% Test 7: Rician Average Channel Power

ricianPower = mean(abs(hRician).^2);

assert(abs(ricianPower-1) < 0.02);

fprintf('Test 7 passed: Rician average power.\n');

%% Test 8: Rician LOS Component

K_linear = 10^(K_dB/10);

expectedLOS = sqrt(K_linear/(K_linear+1));

measuredMean = mean(hRician);

meanTolerance = 5*sqrt(1/(2*(K_linear+1)*N));

assert(abs(real(measuredMean)-expectedLOS) < meanTolerance);

assert(abs(imag(measuredMean)) < meanTolerance);

fprintf('Test 8 passed: Rician LOS component.\n');

%% Test 9: Rician Noise Statistics

assert(abs(varRician-expectedNoiseVariance) < 1e-12);

assert(abs(var(real(noiseRician),1)- ...
    expectedNoiseVariance)/expectedNoiseVariance < 0.02);

assert(abs(var(imag(noiseRician),1)- ...
    expectedNoiseVariance)/expectedNoiseVariance < 0.02);

fprintf('Test 9 passed: Rician noise statistics.\n');

%% Test 10: Invalid Channel Type

invalidDetected = false;

try

    fading_channel(txSymbols,EbN0_dB,2,1,'AWGN');

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 10 passed: Invalid channel detection.\n');

%% Display Results

fprintf('\n========== FADING CHANNEL RESULTS ==========\n');

fprintf('Eb/N0: %.2f dB\n',EbN0_dB);

fprintf('Rician K-factor: %.2f dB\n',K_dB);

fprintf('Rayleigh average power: %.6f\n',rayleighPower);

fprintf('Rician average power: %.6f\n',ricianPower);

fprintf('Rayleigh theoretical noise variance: %.8f\n', ...
    expectedNoiseVariance);

fprintf('Rayleigh measured I noise variance: %.8f\n', ...
    var(real(noiseRayleigh),1));

fprintf('Rician measured I noise variance: %.8f\n', ...
    var(real(noiseRician),1));

fprintf('\nAll fading channel tests passed successfully.\n');
