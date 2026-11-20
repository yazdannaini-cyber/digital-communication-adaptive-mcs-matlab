
clc;
clear;
close all;

%% =========================================
% BPSK vs QPSK vs 16-QAM
% AWGN Channel Performance Comparison
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

cfg = simulation_config();

%% 2. Simulation Parameters

N = 1000000;

EbN0_dB = 0:2:8;

if mod(N,4) ~= 0
    error('Number of bits must be divisible by four.');
end

rng(cfg.seed, 'twister');

%% 3. Generate Common Information Bits

txBits = generate_bits(N);

fprintf('Three Modulation Schemes Comparison\n');

fprintf('Number of information bits: %d\n',N);

%% 4. Generate Modulated Signals

txBPSK = bpsk_modulator(txBits);

txQPSK = qpsk_modulator(txBits);

tx16QAM = qam16_modulator(txBits);

fprintf('\nSymbol Counts:\n');

fprintf('BPSK: %d\n',numel(txBPSK));

fprintf('QPSK: %d\n',numel(txQPSK));

fprintf('16-QAM: %d\n',numel(tx16QAM));

%% 5. Initialize Result Arrays

numSNR = numel(EbN0_dB);

berBPSK = zeros(1,numSNR);

berQPSK = zeros(1,numSNR);

ber16QAM = zeros(1,numSNR);

errorsBPSK = zeros(1,numSNR);

errorsQPSK = zeros(1,numSNR);

errors16QAM = zeros(1,numSNR);

theoryBPSK = zeros(1,numSNR);

theoryQPSK = zeros(1,numSNR);

theory16QAM = zeros(1,numSNR);

%% 6. Monte Carlo Simulation

for k = 1:numSNR

    currentSNR = EbN0_dB(k);

    gamma = 10^(currentSNR/10);

    fprintf('\n=================================\n');

    fprintf('Eb/N0 = %.1f dB\n',currentSNR);

    %% BPSK

    rxBPSK = awgn_channel(txBPSK,currentSNR,1,1);

    rxBitsBPSK = bpsk_demodulator(rxBPSK);

    [berBPSK(k),errorsBPSK(k)] = ...
        calculate_ber(txBits,rxBitsBPSK);

    %% QPSK

    rxQPSK = awgn_channel(txQPSK,currentSNR,2,1);

    rxBitsQPSK = qpsk_demodulator(rxQPSK);

    [berQPSK(k),errorsQPSK(k)] = ...
        calculate_ber(txBits,rxBitsQPSK);

    %% 16-QAM

    rx16QAM = awgn_channel(tx16QAM,currentSNR,4,1);

    rxBits16QAM = qam16_demodulator(rx16QAM);

    [ber16QAM(k),errors16QAM(k)] = ...
        calculate_ber(txBits,rxBits16QAM);

    %% Theoretical BER: BPSK and QPSK

    theoryBPSK(k) = 0.5*erfc(sqrt(gamma));

    theoryQPSK(k) = theoryBPSK(k);

    %% Theoretical BER: Gray-Coded 16-QAM

    a = sqrt(0.8*gamma);

    Q = @(x) 0.5*erfc(x/sqrt(2));

    theory16QAM(k) = ...
        (3/4)*Q(a) + ...
        (1/2)*Q(3*a) - ...
        (1/4)*Q(5*a);

    %% Display Results

    fprintf('BPSK BER: %.8e | Errors: %d\n', ...
        berBPSK(k),errorsBPSK(k));

    fprintf('QPSK BER: %.8e | Errors: %d\n', ...
        berQPSK(k),errorsQPSK(k));

    fprintf('16-QAM BER: %.8e | Errors: %d\n', ...
        ber16QAM(k),errors16QAM(k));

    fprintf('BPSK/QPSK Theory: %.8e\n',theoryBPSK(k));

    fprintf('16-QAM Theory: %.8e\n',theory16QAM(k));

end

%% 7. Create Results Table

resultsTable = table( ...
    EbN0_dB(:), ...
    errorsBPSK(:), ...
    errorsQPSK(:), ...
    errors16QAM(:), ...
    berBPSK(:), ...
    berQPSK(:), ...
    ber16QAM(:), ...
    theoryBPSK(:), ...
    theory16QAM(:), ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'BPSK_Errors', ...
    'QPSK_Errors', ...
    'QAM16_Errors', ...
    'BPSK_BER', ...
    'QPSK_BER', ...
    'QAM16_BER', ...
    'BPSK_QPSK_Theory', ...
    'QAM16_Theory'});

fprintf('\n========== FINAL RESULTS ==========\n');

disp(resultsTable);

%% 8. Plot BER Comparison

figure('Color','w');

semilogy(EbN0_dB,berBPSK,'o-', ...
    'LineWidth',1.7,'MarkerSize',7);

hold on;

semilogy(EbN0_dB,berQPSK,'s-', ...
    'LineWidth',1.7,'MarkerSize',7);

semilogy(EbN0_dB,ber16QAM,'d-', ...
    'LineWidth',1.7,'MarkerSize',7);

semilogy(EbN0_dB,theoryBPSK,'--', ...
    'LineWidth',1.8);

semilogy(EbN0_dB,theory16QAM,':', ...
    'LineWidth',1.8);

grid on;

xlabel('E_b/N_0 (dB)');

ylabel('Bit Error Rate (BER)');

title('BPSK vs QPSK vs 16-QAM over AWGN');

legend( ...
    'BPSK Simulation', ...
    'QPSK Simulation', ...
    '16-QAM Simulation', ...
    'BPSK/QPSK Theory', ...
    '16-QAM Theory', ...
    'Location','southwest');

xlim([min(EbN0_dB),max(EbN0_dB)]);

ylim([1e-5,1]);

%% 9. Plot Constellation Comparison

figure('Color','w');

subplot(1,3,1);

scatter(real(txBPSK(1:2000)), ...
        imag(txBPSK(1:2000)),12,'filled');

grid on;

axis equal;

title('BPSK');

xlabel('I');

ylabel('Q');

subplot(1,3,2);

scatter(real(txQPSK(1:2000)), ...
        imag(txQPSK(1:2000)),12,'filled');

grid on;

axis equal;

title('QPSK');

xlabel('I');

ylabel('Q');

subplot(1,3,3);

scatter(real(tx16QAM(1:2000)), ...
        imag(tx16QAM(1:2000)),12,'filled');

grid on;

axis equal;

title('16-QAM');

xlabel('I');

ylabel('Q');

%% 10. Save Results

figuresFolder = fullfile(projectRoot, ...
                         'results','figures');

if ~exist(figuresFolder,'dir')
    mkdir(figuresFolder);
end

exportgraphics(figure(1), ...
    fullfile(figuresFolder, ...
    'three_modulations_ber.png'), ...
    'Resolution',300);

exportgraphics(figure(2), ...
    fullfile(figuresFolder, ...
    'three_modulations_constellations.png'), ...
    'Resolution',300);

writetable(resultsTable, ...
    fullfile(projectRoot,'results', ...
    'three_modulations_results.csv'));

fprintf('\nAll results saved successfully.\n');

fprintf('\nComparison completed.\n');
