
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

bits = generate_bits(2*N);

txSymbols = qpsk_modulator(bits);

%% Pass Signal Through Complex AWGN

[rxSymbols, noise, noiseVariance] = ...
    awgn_channel(txSymbols, EbN0_dB, 2, 1);

%% Calculate Theoretical Noise Statistics

EbN0_linear = 10^(EbN0_dB/10);

theoreticalVariance = 1/(4*EbN0_linear);

theoreticalComplexPower = 2*theoreticalVariance;

%% Test 1: Output Length

assert(numel(rxSymbols) == N);

assert(numel(noise) == N);

fprintf('Test 1 passed: Output length.\n');

%% Test 2: Channel Equation

assert(max(abs(rxSymbols - txSymbols - noise)) < 1e-12);

fprintf('Test 2 passed: Channel equation.\n');

%% Test 3: Noise Variance Parameter

assert(abs(noiseVariance - theoreticalVariance) < 1e-12);

fprintf('Test 3 passed: Theoretical noise variance.\n');

%% Test 4: I Component Mean and Variance

noiseI = real(noise);

meanI = mean(noiseI);

varianceI = var(noiseI, 1);

meanTolerance = 5*sqrt(theoreticalVariance/N);

assert(abs(meanI) < meanTolerance);

assert(abs(varianceI-theoreticalVariance) / ...
       theoreticalVariance < 0.02);

fprintf('Test 4 passed: I component statistics.\n');

%% Test 5: Q Component Mean and Variance

noiseQ = imag(noise);

meanQ = mean(noiseQ);

varianceQ = var(noiseQ, 1);

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

fprintf('\n========== QPSK AWGN RESULTS ==========\n');

fprintf('Eb/N0: %.2f dB\n', EbN0_dB);

fprintf('Theoretical variance per dimension: %.8f\n', ...
    theoreticalVariance);

fprintf('Measured I variance: %.8f\n', varianceI);

fprintf('Measured Q variance: %.8f\n', varianceQ);

fprintf('Theoretical complex noise power: %.8f\n', ...
    theoreticalComplexPower);

fprintf('Measured complex noise power: %.8f\n', ...
    measuredComplexPower);

fprintf('\nAll QPSK AWGN tests passed successfully.\n');

%% Plot I and Q Noise Distributions

figure('Color', 'w');

subplot(1,2,1);

histogram(noiseI, 100, 'Normalization', 'pdf');

grid on;

title('In-phase Noise');

xlabel('Noise Amplitude');

ylabel('Probability Density');

subplot(1,2,2);

histogram(noiseQ, 100, 'Normalization', 'pdf');

grid on;

title('Quadrature Noise');

xlabel('Noise Amplitude');

ylabel('Probability Density');

sgtitle('Complex AWGN - QPSK - 6 dB');

%% Save Figure

figuresFolder = fullfile(projectRoot, ...
                         'results', ...
                         'figures');

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end

exportgraphics(gcf, ...
    fullfile(figuresFolder, 'qpsk_awgn_noise.png'), ...
    'Resolution', 300);

fprintf('\nQPSK noise figure saved successfully.\n');
