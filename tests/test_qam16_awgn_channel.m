
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

rng(42);

%% Simulation Parameters

Nsymbols = 200000;

EbN0_dB = 6;

%% Generate Bits and Modulate

bits = generate_bits(4*Nsymbols);

txSymbols = qam16_modulator(bits);

%% Pass Through Complex AWGN

[rxSymbols, noise, noiseVariance] = ...
    awgn_channel(txSymbols, EbN0_dB, 4, 1);

%% Theoretical Noise Statistics

EbN0_linear = 10^(EbN0_dB/10);

theoreticalVariance = 1/(8*EbN0_linear);

theoreticalComplexPower = 2*theoreticalVariance;

%% Test 1: Signal Length

assert(numel(txSymbols) == Nsymbols);

assert(numel(rxSymbols) == Nsymbols);

assert(numel(noise) == Nsymbols);

fprintf('Test 1 passed: Signal lengths.\n');

%% Test 2: Channel Equation

assert(max(abs(rxSymbols-txSymbols-noise)) < 1e-12);

fprintf('Test 2 passed: Channel equation.\n');

%% Test 3: Theoretical Variance

assert(abs(noiseVariance-theoreticalVariance) < 1e-12);

fprintf('Test 3 passed: Noise variance calculation.\n');

%% Test 4: I Noise Statistics

noiseI = real(noise);

varianceI = var(noiseI, 1);

meanI = mean(noiseI);

meanTolerance = 5*sqrt(theoreticalVariance/Nsymbols);

assert(abs(meanI) < meanTolerance);

assert(abs(varianceI-theoreticalVariance) / ...
    theoreticalVariance < 0.02);

fprintf('Test 4 passed: I component statistics.\n');

%% Test 5: Q Noise Statistics

noiseQ = imag(noise);

varianceQ = var(noiseQ, 1);

meanQ = mean(noiseQ);

assert(abs(meanQ) < meanTolerance);

assert(abs(varianceQ-theoreticalVariance) / ...
    theoreticalVariance < 0.02);

fprintf('Test 5 passed: Q component statistics.\n');

%% Test 6: Total Complex Noise Power

measuredComplexPower = mean(abs(noise).^2);

assert(abs(measuredComplexPower-theoreticalComplexPower) / ...
    theoreticalComplexPower < 0.02);

fprintf('Test 6 passed: Complex noise power.\n');

%% Display Results

fprintf('\n========== 16-QAM AWGN RESULTS ==========\n');

fprintf('Eb/N0: %.2f dB\n', EbN0_dB);

fprintf('Theoretical variance per dimension: %.8f\n', ...
    theoreticalVariance);

fprintf('Measured I variance: %.8f\n', varianceI);

fprintf('Measured Q variance: %.8f\n', varianceQ);

fprintf('Theoretical complex noise power: %.8f\n', ...
    theoreticalComplexPower);

fprintf('Measured complex noise power: %.8f\n', ...
    measuredComplexPower);

fprintf('\nAll 16-QAM AWGN tests passed successfully.\n');
