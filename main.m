
clc;
clear;
close all;

%% =========================================
%  BPSK over AWGN - Complete System Simulation
%  =========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

%% 2. Load Configuration

cfg = simulation_config();

% For the first reliable BER comparison,
% use the 0 to 8 dB range.

cfg.EbN0_dB = 0:2:8;

N = cfg.numBits;

rng(cfg.seed, 'twister');

fprintf('BPSK AWGN Simulation Started\n');

fprintf('Number of bits: %d\n', N);

%% 3. Generate Information Bits

txBits = generate_bits(N);

%% 4. BPSK Modulation

txSymbols = bpsk_modulator(txBits);

%% 5. Initialize Result Arrays

numSNR = numel(cfg.EbN0_dB);

simulatedBER = zeros(1, numSNR);

theoreticalBER = zeros(1, numSNR);

numErrors = zeros(1, numSNR);

noiseVariances = zeros(1, numSNR);

%% 6. Run Simulation for Each Eb/N0

for k = 1:numSNR

    EbN0_dB = cfg.EbN0_dB(k);

    fprintf('\nSimulating Eb/N0 = %.1f dB...\n', EbN0_dB);

    % Pass the signal through AWGN channel

    [rxSymbols, noise, noiseVariance] = ...
        awgn_channel(txSymbols, EbN0_dB);

    % BPSK Demodulation

    rxBits = bpsk_demodulator(rxSymbols);

    % BER Calculation

    [simulatedBER(k), numErrors(k)] = ...
        calculate_ber(txBits, rxBits);

    % Store noise variance

    noiseVariances(k) = noiseVariance;

    % Theoretical BER Calculation

    EbN0_linear = 10^(EbN0_dB / 10);

    theoreticalBER(k) = ...
        0.5 * erfc(sqrt(EbN0_linear));

    % Print Results

    fprintf('Number of errors: %d\n', numErrors(k));

    fprintf('Simulated BER: %.8e\n', simulatedBER(k));

    fprintf('Theoretical BER: %.8e\n', theoreticalBER(k));

end

%% 7. Calculate Expected Number of Errors

expectedErrors = N .* theoreticalBER;

%% 8. Display Results Table

resultsTable = table( ...
    cfg.EbN0_dB(:), ...
    numErrors(:), ...
    expectedErrors(:), ...
    simulatedBER(:), ...
    theoreticalBER(:), ...
    noiseVariances(:), ...
    'VariableNames', { ...
    'EbN0_dB', ...
    'MeasuredErrors', ...
    'ExpectedErrors', ...
    'SimulatedBER', ...
    'TheoreticalBER', ...
    'NoiseVariance'});

fprintf('\n========== FINAL RESULTS ==========\n');

disp(resultsTable);

%% 9. Plot BER Performance

figure('Color', 'w');

semilogy(cfg.EbN0_dB, simulatedBER, ...
    'o-', 'LineWidth', 1.7, 'MarkerSize', 7);

hold on;

semilogy(cfg.EbN0_dB, theoreticalBER, ...
    '--', 'LineWidth', 1.8);

grid on;

xlabel('E_b/N_0 (dB)');

ylabel('Bit Error Rate (BER)');

title('BPSK Performance over AWGN Channel');

legend('Monte Carlo Simulation', ...
       'Theoretical BER', ...
       'Location', 'southwest');

xlim([min(cfg.EbN0_dB) max(cfg.EbN0_dB)]);

ylim([1e-5 1]);

%% 10. Save Results

figuresFolder = fullfile(projectRoot, ...
                         'results', ...
                         'figures');

if ~exist(figuresFolder, 'dir')

    mkdir(figuresFolder);

end

exportgraphics(gcf, ...
    fullfile(figuresFolder, 'ber_bpsk_awgn.png'), ...
    'Resolution', 300);

writetable(resultsTable, ...
    fullfile(projectRoot, 'results', 'ber_results.csv'));

fprintf('\nBER figure saved successfully.\n');

fprintf('Results table saved successfully.\n');

fprintf('\nSimulation completed successfully.\n');
