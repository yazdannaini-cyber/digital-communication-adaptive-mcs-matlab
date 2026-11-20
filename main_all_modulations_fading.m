
clc;
clear;
close all;

%% =========================================
% ALL MODULATIONS / ALL FADING CHANNELS
%
% Modulations:
% BPSK, QPSK, 16-QAM
%
% Channels:
% AWGN, Rayleigh, Rician
%
% Perfect CSI for fading channels
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

cfg = simulation_config();

%% 2. Parameters

N = 1e6;

EbN0_dB = 0:2:8;

K_dB = 6;

bitsPerSymbol = [1 2 4];

modulationNames = {'BPSK','QPSK','16-QAM'};

channelNames = {'AWGN','Rayleigh','Rician'};

numMod = 3;

numChannels = 3;

numSNR = numel(EbN0_dB);

if mod(N,4) ~= 0
    error('Number of bits must be divisible by four.');
end

rng(cfg.seed,'twister');

%% 3. Generate Common Information Bits

txBits = generate_bits(N);

%% 4. Modulate

txSymbols = cell(1,numMod);

txSymbols{1} = bpsk_modulator(txBits);

txSymbols{2} = qpsk_modulator(txBits);

txSymbols{3} = qam16_modulator(txBits);

%% 5. Initialize Arrays

berSim = zeros(numSNR,numMod,numChannels);

berTheory = zeros(numSNR,numMod,numChannels);

numErrors = zeros(numSNR,numMod,numChannels);

%% 6. Calculate Theoretical BER

for c = 1:numChannels

    channelType = channelNames{c};

    if strcmpi(channelType,'AWGN')

        bpskTheory = ...
            0.5*erfc(sqrt(10.^(EbN0_dB/10)));

    elseif strcmpi(channelType,'Rayleigh')

        bpskTheory = ...
            theoretical_ber_rayleigh_bpsk(EbN0_dB);

    else

        bpskTheory = ...
            theoretical_ber_rician_bpsk(EbN0_dB,K_dB);

    end

    berTheory(:,1,c) = bpskTheory(:);

    % Gray-coded QPSK has the same BER per bit as BPSK

    berTheory(:,2,c) = bpskTheory(:);

    % 16-QAM theoretical BER

    qamTheory = theoretical_ber_16qam_fading( ...
        EbN0_dB,channelType,K_dB);

    berTheory(:,3,c) = qamTheory(:);

end

%% 7. Run Monte Carlo Simulations

for k = 1:numSNR

    currentSNR = EbN0_dB(k);

    fprintf('\n=================================\n');

    fprintf('Eb/N0 = %.1f dB\n',currentSNR);

    for c = 1:numChannels

        channelType = channelNames{c};

        for m = 1:numMod

            % Get Transmitted Symbols

            symbols = txSymbols{m};

            % Select Channel

            if strcmpi(channelType,'AWGN')

                rxSymbols = awgn_channel( ...
                    symbols,currentSNR, ...
                    bitsPerSymbol(m),1);

            else

                [fadedSymbols,h] = fading_channel( ...
                    symbols,currentSNR, ...
                    bitsPerSymbol(m),1, ...
                    channelType,K_dB);

                rxSymbols = coherent_equalizer( ...
                    fadedSymbols,h);

            end

            % Demodulation

            switch m

                case 1

                    rxBits = bpsk_demodulator(rxSymbols);

                case 2

                    rxBits = qpsk_demodulator(rxSymbols);

                case 3

                    rxBits = qam16_demodulator(rxSymbols);

            end

            % BER Calculation

            [berSim(k,m,c),numErrors(k,m,c)] = ...
                calculate_ber(txBits,rxBits);

            % Display Results

            fprintf('%s | %s | BER = %.8e | Theory = %.8e | Errors = %d\n', ...
                modulationNames{m}, ...
                channelType, ...
                berSim(k,m,c), ...
                berTheory(k,m,c), ...
                numErrors(k,m,c));

        end

    end

end

%% 8. Create Results Table

totalRows = numSNR*numMod*numChannels;

snrColumn = zeros(totalRows,1);

modulationColumn = strings(totalRows,1);

channelColumn = strings(totalRows,1);

simulatedBERColumn = zeros(totalRows,1);

theoreticalBERColumn = zeros(totalRows,1);

errorColumn = zeros(totalRows,1);

row = 0;

for k = 1:numSNR

    for c = 1:numChannels

        for m = 1:numMod

            row = row+1;

            snrColumn(row) = EbN0_dB(k);

            modulationColumn(row) = modulationNames{m};

            channelColumn(row) = channelNames{c};

            simulatedBERColumn(row) = berSim(k,m,c);

            theoreticalBERColumn(row) = berTheory(k,m,c);

            errorColumn(row) = numErrors(k,m,c);

        end

    end

end

resultsTable = table( ...
    snrColumn, ...
    modulationColumn, ...
    channelColumn, ...
    errorColumn, ...
    simulatedBERColumn, ...
    theoreticalBERColumn, ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'Modulation', ...
    'Channel', ...
    'BitErrors', ...
    'SimulatedBER', ...
    'TheoreticalBER'});

fprintf('\n========== FINAL RESULTS ==========\n');

disp(resultsTable);

%% 9. Plot BER Comparison

figure('Color','w');

lineStyles = {'o-','s-','d-'};

for m = 1:numMod

    subplot(1,3,m);

    hold on;

    for c = 1:numChannels

        semilogy(EbN0_dB, ...
            berSim(:,m,c), ...
            lineStyles{c}, ...
            'LineWidth',1.5, ...
            'MarkerSize',6);

        semilogy(EbN0_dB, ...
            berTheory(:,m,c), ...
            '--', ...
            'LineWidth',1.2);

    end

    grid on;

    xlabel('E_b/N_0 (dB)');

    ylabel('BER');

    title(modulationNames{m});

    if m == 1

        legend( ...
            'AWGN Sim','AWGN Theory', ...
            'Rayleigh Sim','Rayleigh Theory', ...
            'Rician Sim','Rician Theory', ...
            'Location','southwest');

    end

end

sgtitle('Modulation and Fading Channel Performance');

%% 10. Save Results

resultsFolder = fullfile(projectRoot,'results');

figuresFolder = fullfile(resultsFolder,'figures');

if ~exist(figuresFolder,'dir')
    mkdir(figuresFolder);
end

exportgraphics(gcf, ...
    fullfile(figuresFolder, ...
    'all_modulations_fading_comparison.png'), ...
    'Resolution',300);

writetable(resultsTable, ...
    fullfile(resultsFolder, ...
    'all_modulations_fading_results.csv'));

fprintf('\nAll modulation-fading results saved.\n');

fprintf('\nSimulation completed successfully.\n');
