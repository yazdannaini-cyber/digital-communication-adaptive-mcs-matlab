
clc;
clear;
close all;

%% =========================================
% BPSK vs QPSK Performance Comparison
% AWGN Channel - Monte Carlo Simulation
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

%% 2. Load Configuration

cfg = simulation_config();

cfg.numBits = 1e6;

cfg.EbN0_dB = 0:2:8;

N = cfg.numBits;

if mod(N, 2) ~= 0
    error('Number of bits must be even for QPSK.');
end

rng(cfg.seed, 'twister');

%% 3. Generate Common Information Bits

txBits = generate_bits(N);

fprintf('BPSK vs QPSK Simulation Started\n');

fprintf('Number of information bits: %d\n', N);

%% 4. Modulation

txSymbolsBPSK = bpsk_modulator(txBits);

txSymbolsQPSK = qpsk_modulator(txBits);

fprintf('BPSK symbol count: %d\n', numel(txSymbolsBPSK));

fprintf('QPSK symbol count: %d\n', numel(txSymbolsQPSK));

%% 5. Initialize Result Arrays

numSNR = numel(cfg.EbN0_dB);

berBPSK = zeros(1, numSNR);

berQPSK = zeros(1, numSNR);

berTheory = zeros(1, numSNR);

errorsBPSK = zeros(1, numSNR);

errorsQPSK = zeros(1, numSNR);

varianceBPSK = zeros(1, numSNR);

varianceQPSK = zeros(1, numSNR);

%% 6. Monte Carlo Simulation

for k = 1:numSNR

    EbN0_dB = cfg.EbN0_dB(k);

    fprintf('\n=================================\n');

    fprintf('Eb/N0 = %.1f dB\n', EbN0_dB);

    %% BPSK Transmission

    [rxBPSK, noiseBPSK, varianceBPSK(k)] = ...
        awgn_channel(txSymbolsBPSK, EbN0_dB, 1, 1);

    rxBitsBPSK = bpsk_demodulator(rxBPSK);

    [berBPSK(k), errorsBPSK(k)] = ...
        calculate_ber(txBits, rxBitsBPSK);

    %% QPSK Transmission

    [rxQPSK, noiseQPSK, varianceQPSK(k)] = ...
        awgn_channel(txSymbolsQPSK, EbN0_dB, 2, 1);

    rxBitsQPSK = qpsk_demodulator(rxQPSK);

    [berQPSK(k), errorsQPSK(k)] = ...
        calculate_ber(txBits, rxBitsQPSK);

    %% Theoretical BER

    EbN0_linear = 10^(EbN0_dB / 10);

    berTheory(k) = ...
        0.5 * erfc(sqrt(EbN0_linear));

    %% Display Results

    fprintf('BPSK errors: %d\n', errorsBPSK(k));

    fprintf('BPSK BER: %.8e\n', berBPSK(k));

    fprintf('QPSK errors: %d\n', errorsQPSK(k));

    fprintf('QPSK BER: %.8e\n', berQPSK(k));

    fprintf('Theoretical BER: %.8e\n', berTheory(k));

end

%% 7. Calculate Expected Errors

expectedErrors = N .* berTheory;

%% 8. Create Results Table

resultsTable = table( ...
    cfg.EbN0_dB(:), ...
    errorsBPSK(:), ...
    errorsQPSK(:), ...
    expectedErrors(:), ...
    berBPSK(:), ...
    berQPSK(:), ...
    berTheory(:), ...
    varianceBPSK(:), ...
    varianceQPSK(:), ...
    'VariableNames', { ...
    'EbN0_dB', ...
    'BPSK_Errors', ...
    'QPSK_Errors', ...
    'ExpectedErrors', ...
    'BPSK_BER', ...
    'QPSK_BER', ...
    'Theoretical_BER', ...
    'BPSK_NoiseVariance', ...
    'QPSK_NoiseVariancePerDimension'});

%% 9. Display Final Results

fprintf('\n========== FINAL COMPARISON ==========\n');

disp(resultsTable);

%% 10. Plot BER Comparison

figure('Color', 'w');

semilogy(cfg.EbN0_dB, berBPSK, ...
    'o-', 'LineWidth', 1.7, 'MarkerSize', 7);

hold on;

semilogy(cfg.EbN0_dB, berQPSK, ...
    's-', 'LineWidth', 1.7, 'MarkerSize', 7);

semilogy(cfg.EbN0_dB, berTheory, ...
    '--', 'LineWidth', 1.8);

grid on;

xlabel('E_b/N_0 (dB)');

ylabel('Bit Error Rate (BER)');

title('BPSK vs QPSK Performance over AWGN');

legend('BPSK Simulation', ...
       'QPSK Simulation', ...
       'Theoretical BER', ...
       'Location', 'southwest');

xlim([min(cfg.EbN0_dB) max(cfg.EbN0_dB)]);

ylim([1e-5 1]);

%% 11. Save Results

figuresFolder = fullfile(projectRoot, ...
                         'results', ...
                         'figures');

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end

exportgraphics(gcf, ...
    fullfile(figuresFolder, ...
    'bpsk_vs_qpsk_ber.png'), ...
    'Resolution', 300);

writetable(resultsTable, ...
    fullfile(projectRoot, ...
    'results', ...
    'bpsk_vs_qpsk_results.csv'));

fprintf('\nComparison figure saved successfully.\n');

fprintf('Comparison table saved successfully.\n');

fprintf('\nBPSK vs QPSK simulation completed.\n');
