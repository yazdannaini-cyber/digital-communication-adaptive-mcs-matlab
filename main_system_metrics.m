
clc;
clear;
close all;

%% =========================================
% SYSTEM PERFORMANCE METRICS
% BPSK / QPSK / 16-QAM over AWGN
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

%% 2. Simulation Configuration

cfg = simulation_config();

N = 1e6;

EbN0_dB = 0:2:8;

symbolRate = 1e6;

rolloff = 0.25;

rng(cfg.seed, 'twister');

%% 3. Generate Common Bits

txBits = generate_bits(N);

%% 4. Modulation

txBPSK = bpsk_modulator(txBits);

txQPSK = qpsk_modulator(txBits);

tx16QAM = qam16_modulator(txBits);

%% 5. Initialize Arrays

numSNR = numel(EbN0_dB);

ber = zeros(numSNR, 3);

ser = zeros(numSNR, 3);

theoreticalSER = zeros(numSNR, 3);

symbolErrors = zeros(numSNR, 3);

correctBitRate = zeros(numSNR, 3);

grossBitRate = zeros(1, 3);

spectralEfficiency = zeros(1, 3);

modulationNames = {'BPSK'; 'QPSK'; '16-QAM'};

bitsPerSymbol = [1 2 4];

%% 6. Calculate Fixed System Properties

for m = 1:3

    grossBitRate(m) = ...
        symbolRate * bitsPerSymbol(m);

    spectralEfficiency(m) = ...
        calculate_spectral_efficiency( ...
        bitsPerSymbol(m), rolloff);

end

%% 7. Simulation Loop

Q = @(x) 0.5*erfc(x/sqrt(2));

for k = 1:numSNR

    gamma = 10^(EbN0_dB(k)/10);

    fprintf('\n=================================\n');

    fprintf('Eb/N0 = %.1f dB\n', EbN0_dB(k));

    %% BPSK

    rxBPSK = awgn_channel(txBPSK,EbN0_dB(k),1,1);

    rxBitsBPSK = bpsk_demodulator(rxBPSK);

    [ber(k,1), ~] = calculate_ber( ...
        txBits,rxBitsBPSK);

    [ser(k,1),symbolErrors(k,1)] = calculate_ser( ...
        txBits,rxBitsBPSK,1);

    theoreticalSER(k,1) = ...
        0.5*erfc(sqrt(gamma));

    %% QPSK

    rxQPSK = awgn_channel(txQPSK,EbN0_dB(k),2,1);

    rxBitsQPSK = qpsk_demodulator(rxQPSK);

    [ber(k,2), ~] = calculate_ber( ...
        txBits,rxBitsQPSK);

    [ser(k,2),symbolErrors(k,2)] = calculate_ser( ...
        txBits,rxBitsQPSK,2);

    pBPSK = 0.5*erfc(sqrt(gamma));

    theoreticalSER(k,2) = ...
        2*pBPSK - pBPSK^2;

    %% 16-QAM

    rx16QAM = awgn_channel(tx16QAM,EbN0_dB(k),4,1);

    rxBits16QAM = qam16_demodulator(rx16QAM);

    [ber(k,3), ~] = calculate_ber( ...
        txBits,rxBits16QAM);

    [ser(k,3),symbolErrors(k,3)] = calculate_ser( ...
        txBits,rxBits16QAM,4);

    a = sqrt(0.8*gamma);

    axisErrorProbability = 1.5*Q(a);

    theoreticalSER(k,3) = ...
        1-(1-axisErrorProbability)^2;

    %% Throughput

    for m = 1:3

        [~,correctBitRate(k,m)] = ...
            calculate_throughput( ...
            symbolRate,bitsPerSymbol(m),ber(k,m));

    end

    %% Display Metrics

    for m = 1:3

        fprintf(['%s | BER = %.8e | SER = %.8e | ', ...
            'Symbol errors = %d | Correct bit rate = %.3f Mbps\n'], ...
            modulationNames{m}, ...
            ber(k,m), ...
            ser(k,m), ...
            symbolErrors(k,m), ...
            correctBitRate(k,m)/1e6);

    end

end

%% 8. Create Performance Results Table

resultsTable = table( ...
    repelem(EbN0_dB(:),3), ...
    repmat(string(modulationNames),numSNR,1), ...
    reshape(ber.',[],1), ...
    reshape(ser.',[],1), ...
    reshape(theoreticalSER.',[],1), ...
    reshape(symbolErrors.',[],1), ...
    reshape(correctBitRate.',[],1), ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'Modulation', ...
    'BER', ...
    'SER', ...
    'Theoretical_SER', ...
    'SymbolErrors', ...
    'EstimatedCorrectBitRate_bps'});

fprintf('\n========== PERFORMANCE RESULTS ==========\n');

disp(resultsTable);

%% 9. Create Modulation Summary Table

summaryTable = table( ...
    string(modulationNames), ...
    bitsPerSymbol(:), ...
    repmat(symbolRate,3,1), ...
    grossBitRate(:), ...
    repmat(rolloff,3,1), ...
    spectralEfficiency(:), ...
    'VariableNames',{ ...
    'Modulation', ...
    'BitsPerSymbol', ...
    'SymbolRate', ...
    'GrossBitRate', ...
    'RollOff', ...
    'SpectralEfficiency'});

fprintf('\n========== MODULATION SUMMARY ==========\n');

disp(summaryTable);

%% 10. Plot SER

figure('Color','w');

semilogy(EbN0_dB,ser(:,1),'o-','LineWidth',1.7);

hold on;

semilogy(EbN0_dB,ser(:,2),'s-','LineWidth',1.7);

semilogy(EbN0_dB,ser(:,3),'d-','LineWidth',1.7);

semilogy(EbN0_dB,theoreticalSER(:,1),'--');

semilogy(EbN0_dB,theoreticalSER(:,2),':');

semilogy(EbN0_dB,theoreticalSER(:,3),'-.');

grid on;

xlabel('E_b/N_0 (dB)');

ylabel('Symbol Error Rate (SER)');

title('SER Comparison of Digital Modulations');

legend('BPSK Simulation', ...
       'QPSK Simulation', ...
       '16-QAM Simulation', ...
       'BPSK Theory', ...
       'QPSK Theory', ...
       '16-QAM Theory', ...
       'Location','southwest');

%% 11. Plot Correctly Received Bit Rate

figure('Color','w');

plot(EbN0_dB,correctBitRate(:,1)/1e6,'o-','LineWidth',1.7);

hold on;

plot(EbN0_dB,correctBitRate(:,2)/1e6,'s-','LineWidth',1.7);

plot(EbN0_dB,correctBitRate(:,3)/1e6,'d-','LineWidth',1.7);

grid on;

xlabel('E_b/N_0 (dB)');

ylabel('Estimated Correct Bit Rate (Mbps)');

title('Estimated Correct Bit Rate vs Eb/N0');

legend('BPSK','QPSK','16-QAM','Location','best');

%% 12. Save Figures and Tables

resultsFolder = fullfile(projectRoot,'results');

figuresFolder = fullfile(resultsFolder,'figures');

if ~exist(figuresFolder,'dir')
    mkdir(figuresFolder);
end

exportgraphics(figure(1), ...
    fullfile(figuresFolder,'ser_comparison.png'), ...
    'Resolution',300);

exportgraphics(figure(2), ...
    fullfile(figuresFolder,'correct_bit_rate.png'), ...
    'Resolution',300);

writetable(resultsTable, ...
    fullfile(resultsFolder,'system_metrics_results.csv'));

writetable(summaryTable, ...
    fullfile(resultsFolder,'modulation_summary.csv'));

fprintf('\nAll system performance results saved successfully.\n');
