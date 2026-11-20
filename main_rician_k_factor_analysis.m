
clc;
clear;
close all;

%% =========================================
% RICIAN K-FACTOR SENSITIVITY ANALYSIS
% BPSK - Fixed Eb/N0
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

%% 2. Simulation Parameters

N = 1e6;

EbN0_dB = 6;

K_dB_list = [-20 -10 0 3 6 10 20 30];

rng(42,'twister');

fprintf('Rician K-Factor Analysis\n');

fprintf('Number of bits: %d\n',N);

fprintf('Eb/N0: %.2f dB\n',EbN0_dB);

%% 3. Generate Information Bits

txBits = generate_bits(N);

%% 4. BPSK Modulation

txSymbols = bpsk_modulator(txBits);

%% 5. Initialize Results

numK = numel(K_dB_list);

simulatedBER = zeros(1,numK);

theoreticalBER = zeros(1,numK);

numErrors = zeros(1,numK);

%% 6. Rician Simulation

for k = 1:numK

    currentK = K_dB_list(k);

    fprintf('\n==============================\n');

    fprintf('K-factor = %.1f dB\n',currentK);

    %% Channel

    [rxSymbols,h] = fading_channel( ...
        txSymbols, ...
        EbN0_dB, ...
        1, ...
        1, ...
        'Rician', ...
        currentK);

    %% Coherent Equalization

    equalizedSymbols = ...
        coherent_equalizer(rxSymbols,h);

    %% Demodulation

    rxBits = bpsk_demodulator(equalizedSymbols);

    %% BER

    [simulatedBER(k),numErrors(k)] = ...
        calculate_ber(txBits,rxBits);

    %% Theoretical BER

    theoreticalBER(k) = ...
        theoretical_ber_rician_bpsk( ...
        EbN0_dB,currentK);

    %% Display

    fprintf('Linear K: %.6f\n',10^(currentK/10));

    fprintf('Errors: %d\n',numErrors(k));

    fprintf('Simulated BER: %.8e\n',simulatedBER(k));

    fprintf('Theoretical BER: %.8e\n',theoreticalBER(k));

end

%% 7. AWGN and Rayleigh References

awgnBER = 0.5*erfc(sqrt(10^(EbN0_dB/10)));

rayleighBER = theoretical_ber_rayleigh_bpsk(EbN0_dB);

%% 8. Results Table

resultsTable = table( ...
    K_dB_list(:), ...
    10.^(K_dB_list(:)/10), ...
    numErrors(:), ...
    simulatedBER(:), ...
    theoreticalBER(:), ...
    'VariableNames',{ ...
    'K_dB', ...
    'K_linear', ...
    'Errors', ...
    'SimulatedBER', ...
    'TheoreticalBER'});

fprintf('\n========== RICIAN K-FACTOR RESULTS ==========\n');

disp(resultsTable);

%% 9. Plot BER versus K-Factor

figure('Color','w');

semilogy(K_dB_list,simulatedBER,'o-', ...
    'LineWidth',1.8,'MarkerSize',7);

hold on;

semilogy(K_dB_list,theoreticalBER,'--', ...
    'LineWidth',1.8);

yline(rayleighBER,':', ...
    'Rayleigh Reference');

yline(awgnBER,'-.', ...
    'AWGN Reference');

grid on;

xlabel('Rician K-factor (dB)');

ylabel('Bit Error Rate (BER)');

title('Effect of Rician K-Factor on BPSK Performance');

legend( ...
    'Simulation', ...
    'Theory', ...
    'Rayleigh Limit', ...
    'AWGN Limit', ...
    'Location','southwest');

%% 10. Save Results

resultsFolder = fullfile(projectRoot,'results');

figuresFolder = fullfile(resultsFolder,'figures');

if ~exist(figuresFolder,'dir')
    mkdir(figuresFolder);
end

exportgraphics(gcf, ...
    fullfile(figuresFolder, ...
    'rician_k_factor_analysis.png'), ...
    'Resolution',300);

writetable(resultsTable, ...
    fullfile(resultsFolder, ...
    'rician_k_factor_results.csv'));

fprintf('\nK-factor figure saved.\n');

fprintf('K-factor results saved.\n');

fprintf('\nRician K-factor analysis completed.\n');
