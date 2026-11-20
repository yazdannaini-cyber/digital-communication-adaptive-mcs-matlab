
clc;
clear;
close all;

%% =========================================
% BPSK PERFORMANCE COMPARISON
% AWGN vs RAYLEIGH vs RICIAN
%
% Perfect CSI at Receiver
% Coherent Detection
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

cfg = simulation_config();

%% 2. Simulation Parameters

N = 1e6;

EbN0_dB = 0:2:8;

K_dB = 6;

rng(cfg.seed,'twister');

fprintf('BPSK Fading Channel Comparison\n');

fprintf('Number of information bits: %d\n',N);

fprintf('Rician K-factor: %.2f dB\n',K_dB);

%% 3. Generate Information Bits

txBits = generate_bits(N);

%% 4. BPSK Modulation

txSymbols = bpsk_modulator(txBits);

%% 5. Initialize Result Arrays

numSNR = numel(EbN0_dB);

berAWGN = zeros(1,numSNR);

berRayleigh = zeros(1,numSNR);

berRician = zeros(1,numSNR);

theoryAWGN = zeros(1,numSNR);

theoryRayleigh = zeros(1,numSNR);

theoryRician = zeros(1,numSNR);

errorsAWGN = zeros(1,numSNR);

errorsRayleigh = zeros(1,numSNR);

errorsRician = zeros(1,numSNR);

%% 6. Calculate Theoretical BER

theoryAWGN = ...
    0.5*erfc(sqrt(10.^(EbN0_dB/10)));

theoryRayleigh = ...
    theoretical_ber_rayleigh_bpsk(EbN0_dB);

theoryRician = ...
    theoretical_ber_rician_bpsk(EbN0_dB,K_dB);

%% 7. Monte Carlo Simulation

for k = 1:numSNR

    currentSNR = EbN0_dB(k);

    fprintf('\n=================================\n');

    fprintf('Eb/N0 = %.1f dB\n',currentSNR);

    %% AWGN Channel

    rxAWGN = awgn_channel( ...
        txSymbols,currentSNR,1,1);

    rxBitsAWGN = ...
        bpsk_demodulator(rxAWGN);

    [berAWGN(k),errorsAWGN(k)] = ...
        calculate_ber(txBits,rxBitsAWGN);

    %% Rayleigh Channel

    [rxRayleigh,hRayleigh] = ...
        fading_channel( ...
        txSymbols,currentSNR,1,1,'Rayleigh');

    equalizedRayleigh = ...
        coherent_equalizer(rxRayleigh,hRayleigh);

    rxBitsRayleigh = ...
        bpsk_demodulator(equalizedRayleigh);

    [berRayleigh(k),errorsRayleigh(k)] = ...
        calculate_ber(txBits,rxBitsRayleigh);

    %% Rician Channel

    [rxRician,hRician] = ...
        fading_channel( ...
        txSymbols,currentSNR,1,1,'Rician',K_dB);

    equalizedRician = ...
        coherent_equalizer(rxRician,hRician);

    rxBitsRician = ...
        bpsk_demodulator(equalizedRician);

    [berRician(k),errorsRician(k)] = ...
        calculate_ber(txBits,rxBitsRician);

    %% Display Results

    fprintf('AWGN BER: %.8e | Errors: %d\n', ...
        berAWGN(k),errorsAWGN(k));

    fprintf('Rayleigh BER: %.8e | Errors: %d\n', ...
        berRayleigh(k),errorsRayleigh(k));

    fprintf('Rician BER: %.8e | Errors: %d\n', ...
        berRician(k),errorsRician(k));

    fprintf('AWGN Theory: %.8e\n',theoryAWGN(k));

    fprintf('Rayleigh Theory: %.8e\n',theoryRayleigh(k));

    fprintf('Rician Theory: %.8e\n',theoryRician(k));

end

%% 8. Create Results Table

resultsTable = table( ...
    EbN0_dB(:), ...
    errorsAWGN(:), ...
    errorsRayleigh(:), ...
    errorsRician(:), ...
    berAWGN(:), ...
    berRayleigh(:), ...
    berRician(:), ...
    theoryAWGN(:), ...
    theoryRayleigh(:), ...
    theoryRician(:), ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'AWGN_Errors', ...
    'Rayleigh_Errors', ...
    'Rician_Errors', ...
    'AWGN_BER', ...
    'Rayleigh_BER', ...
    'Rician_BER', ...
    'AWGN_Theory', ...
    'Rayleigh_Theory', ...
    'Rician_Theory'});

fprintf('\n========== FINAL RESULTS ==========\n');

disp(resultsTable);

%% 9. Plot BER Comparison

figure('Color','w');

semilogy(EbN0_dB,berAWGN,'o-', ...
    'LineWidth',1.7,'MarkerSize',7);

hold on;

semilogy(EbN0_dB,berRayleigh,'s-', ...
    'LineWidth',1.7,'MarkerSize',7);

semilogy(EbN0_dB,berRician,'d-', ...
    'LineWidth',1.7,'MarkerSize',7);

semilogy(EbN0_dB,theoryAWGN,'--', ...
    'LineWidth',1.5);

semilogy(EbN0_dB,theoryRayleigh,':', ...
    'LineWidth',1.8);

semilogy(EbN0_dB,theoryRician,'-.', ...
    'LineWidth',1.8);

grid on;

xlabel('E_b/N_0 (dB)');

ylabel('Bit Error Rate (BER)');

title('BPSK Performance over Fading Channels');

legend( ...
    'AWGN Simulation', ...
    'Rayleigh Simulation', ...
    'Rician Simulation', ...
    'AWGN Theory', ...
    'Rayleigh Theory', ...
    'Rician Theory', ...
    'Location','southwest');

xlim([min(EbN0_dB) max(EbN0_dB)]);

ylim([1e-5 1]);

%% 10. Save Results

resultsFolder = fullfile(projectRoot,'results');

figuresFolder = fullfile(resultsFolder,'figures');

if ~exist(figuresFolder,'dir')
    mkdir(figuresFolder);
end

exportgraphics(gcf, ...
    fullfile(figuresFolder, ...
    'bpsk_fading_comparison.png'), ...
    'Resolution',300);

writetable(resultsTable, ...
    fullfile(resultsFolder, ...
    'bpsk_fading_results.csv'));

fprintf('\nFading comparison figure saved.\n');

fprintf('Fading results table saved.\n');

fprintf('\nBPSK fading simulation completed successfully.\n');
