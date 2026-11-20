
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

rng(42);

%% Parameters

Nbits = 400000;

EbN0_dB = 10;

%% Transmitter

txBits = generate_bits(Nbits);

txSymbols = qam16_modulator(txBits);

%% Channel

[rxSymbols, noise, noiseVariance] = ...
    awgn_channel(txSymbols, EbN0_dB, 4, 1);

%% Receiver

rxBits = qam16_demodulator(rxSymbols);

%% BER

[ber, numErrors] = calculate_ber(txBits, rxBits);

%% Display

fprintf('\n========== 16-QAM RECEIVER TEST ==========\n');

fprintf('Number of bits: %d\n', Nbits);

fprintf('Eb/N0: %.2f dB\n', EbN0_dB);

fprintf('Noise variance per dimension: %.8f\n', ...
    noiseVariance);

fprintf('Number of bit errors: %d\n', numErrors);

fprintf('Simulated BER: %.8e\n', ber);

%% Display Received Constellation

figure('Color', 'w');

numPlotSymbols = min(2000, numel(rxSymbols));

scatter(real(rxSymbols(1:numPlotSymbols)), ...
        imag(rxSymbols(1:numPlotSymbols)), ...
        8, 'filled');

grid on;

axis equal;

xlabel('In-phase (I)');

ylabel('Quadrature (Q)');

title('Received 16-QAM Constellation');

%% Save Figure

figuresFolder = fullfile(projectRoot, ...
                         'results', ...
                         'figures');

if ~exist(figuresFolder, 'dir')

    mkdir(figuresFolder);

end

exportgraphics(gcf, ...
    fullfile(figuresFolder, ...
    'qam16_received_constellation.png'), ...
    'Resolution', 300);

fprintf('Received constellation figure saved.\n');
