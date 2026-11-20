
clc;
clear;
close all;

%% =========================================
% ADAPTIVE MODULATION:
% PERFECT CSI vs IMPERFECT CSI
%
% Rayleigh / Rician Block Fading
% BPSK / QPSK / 16-QAM
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

%% 2. System Parameters

targetBER = 1e-3;

averageEsN0_dB = 20;

NMSE_dB = -20;

K_dB = 6;

numBlocks = 5000;

symbolsPerBlock = 200;

symbolRate = 1e6;

rolloff = 0.25;

channelNames = {'Rayleigh','Rician'};

numChannels = numel(channelNames);

%% 3. Calculate Thresholds

thresholds = calculate_amc_thresholds(targetBER);

modulationNames = thresholds.modulationNames;

bitsPerSymbol = thresholds.bitsPerSymbol;

numModes = numel(modulationNames);

rng(1401,'twister');

%% 4. Initialize Results

% Dimension 1: Channel
% Dimension 2: CSI condition
% Dimension 3: Modulation

modeBlockCount = zeros(numChannels,2,numModes);

modeBits = zeros(numChannels,2,numModes);

modeErrors = zeros(numChannels,2,numModes);

totalBitErrors = zeros(numChannels,2);

totalBits = zeros(numChannels,2);

outageBlocks = zeros(numChannels,2);

overallBER = zeros(numChannels,2);

overallThroughput = zeros(numChannels,2);

correctThroughput = zeros(numChannels,2);

averageBitsPerSymbol = zeros(numChannels,2);

spectralEfficiency = zeros(numChannels,2);

conditionNames = {'Perfect CSI','Imperfect CSI'};

%% 5. Run Simulation

for c = 1:numChannels

    channelType = channelNames{c};

    fprintf('\n=================================\n');

    fprintf('CHANNEL: %s\n',channelType);

    %% Generate Common Actual Channel Blocks

    hBlocks = generate_block_fading_coefficients( ...
        numBlocks,channelType,K_dB);

    %% Process Both CSI Conditions

    for condition = 1:2

        fprintf('\nCondition: %s\n',conditionNames{condition});

        for b = 1:numBlocks

            hTrue = hBlocks(b);

            %% Channel Estimate

            if condition == 1

                % Perfect CSI

                hUsed = hTrue;

            else

                % Imperfect CSI

                hUsed = estimate_channel( ...
                    hTrue,NMSE_dB);

            end

            %% Estimate Instantaneous Es/N0

            estimatedChannelPower = abs(hUsed)^2;

            if estimatedChannelPower <= 0

                instantaneousEsN0_dB = -Inf;

            else

                instantaneousEsN0_dB = ...
                    averageEsN0_dB + ...
                    10*log10(estimatedChannelPower);

            end

            %% Select Modulation

            [mode,~] = select_adaptive_modulation( ...
                instantaneousEsN0_dB,thresholds);

            %% Outage

            if mode==0

                outageBlocks(c,condition) = ...
                    outageBlocks(c,condition)+1;

                continue;

            end

            %% Determine Payload Length

            currentBitsPerSymbol = bitsPerSymbol(mode);

            currentNumberOfBits = ...
                symbolsPerBlock*currentBitsPerSymbol;

            %% Generate Bits

            txBits = randi([0 1],1,currentNumberOfBits);

            %% Modulation

            switch mode

                case 1

                    txSymbols = bpsk_modulator(txBits);

                case 2

                    txSymbols = qpsk_modulator(txBits);

                case 3

                    txSymbols = qam16_modulator(txBits);

            end

            %% Actual Block Fading Channel

            [rxSymbols,noise] = block_fading_channel( ...
                txSymbols,hTrue,averageEsN0_dB,1);

            %% Equalization with Available CSI

            rxEqualized = coherent_equalizer( ...
                rxSymbols,hUsed);

            %% Demodulation

            switch mode

                case 1

                    rxBits = bpsk_demodulator(rxEqualized);

                case 2

                    rxBits = qpsk_demodulator(rxEqualized);

                case 3

                    rxBits = qam16_demodulator(rxEqualized);

            end

            %% Calculate Errors

            [~,bitErrors] = calculate_ber(txBits,rxBits);

            %% Accumulate Statistics

            modeBlockCount(c,condition,mode) = ...
                modeBlockCount(c,condition,mode)+1;

            modeBits(c,condition,mode) = ...
                modeBits(c,condition,mode)+currentNumberOfBits;

            modeErrors(c,condition,mode) = ...
                modeErrors(c,condition,mode)+bitErrors;

            totalBitErrors(c,condition) = ...
                totalBitErrors(c,condition)+bitErrors;

            totalBits(c,condition) = ...
                totalBits(c,condition)+currentNumberOfBits;

        end

        %% Overall Performance

        if totalBits(c,condition)>0

            overallBER(c,condition) = ...
                totalBitErrors(c,condition)/ ...
                totalBits(c,condition);

        else

            overallBER(c,condition) = NaN;

        end

        %% Calculate Throughput

        totalAvailableSymbols = ...
            numBlocks*symbolsPerBlock;

        averageBitsPerSymbol(c,condition) = ...
            totalBits(c,condition)/totalAvailableSymbols;

        overallThroughput(c,condition) = ...
            symbolRate*averageBitsPerSymbol(c,condition);

        correctThroughput(c,condition) = ...
            symbolRate*(totalBits(c,condition)- ...
            totalBitErrors(c,condition))/ ...
            totalAvailableSymbols;

        spectralEfficiency(c,condition) = ...
            averageBitsPerSymbol(c,condition)/(1+rolloff);

        %% Display Results

        fprintf('Outage probability: %.6f\n', ...
            outageBlocks(c,condition)/numBlocks);

        fprintf('Overall BER: %.8e\n', ...
            overallBER(c,condition));

        fprintf('Average bits/symbol: %.6f\n', ...
            averageBitsPerSymbol(c,condition));

        fprintf('Spectral efficiency: %.6f bit/s/Hz\n', ...
            spectralEfficiency(c,condition));

        fprintf('Average throughput: %.6f Mbps\n', ...
            overallThroughput(c,condition)/1e6);

        fprintf('Estimated correct throughput: %.6f Mbps\n', ...
            correctThroughput(c,condition)/1e6);

        fprintf('\nMode selection:\n');

        for m = 1:numModes

            if modeBits(c,condition,m)>0

                conditionalBER = ...
                    modeErrors(c,condition,m)/ ...
                    modeBits(c,condition,m);

            else

                conditionalBER = NaN;

            end

            fprintf('%s: %d blocks | BER = %.8e\n', ...
                modulationNames{m}, ...
                modeBlockCount(c,condition,m), ...
                conditionalBER);

        end

    end

end

%% 6. Create Summary Table

summaryRows = numChannels*2;

channelColumn = strings(summaryRows,1);

conditionColumn = strings(summaryRows,1);

outageProbabilityColumn = zeros(summaryRows,1);

berColumn = zeros(summaryRows,1);

avgBitsColumn = zeros(summaryRows,1);

spectralEfficiencyColumn = zeros(summaryRows,1);

throughputColumn = zeros(summaryRows,1);

correctThroughputColumn = zeros(summaryRows,1);

row = 0;

for c = 1:numChannels

    for condition = 1:2

        row = row+1;

        channelColumn(row) = channelNames{c};

        conditionColumn(row) = conditionNames{condition};

        outageProbabilityColumn(row) = ...
            outageBlocks(c,condition)/numBlocks;

        berColumn(row) = overallBER(c,condition);

        avgBitsColumn(row) = ...
            averageBitsPerSymbol(c,condition);

        spectralEfficiencyColumn(row) = ...
            spectralEfficiency(c,condition);

        throughputColumn(row) = ...
            overallThroughput(c,condition);

        correctThroughputColumn(row) = ...
            correctThroughput(c,condition);

    end

end

summaryTable = table( ...
    channelColumn, ...
    conditionColumn, ...
    outageProbabilityColumn, ...
    berColumn, ...
    avgBitsColumn, ...
    spectralEfficiencyColumn, ...
    throughputColumn, ...
    correctThroughputColumn, ...
    'VariableNames',{ ...
    'Channel', ...
    'CSI_Type', ...
    'OutageProbability', ...
    'OverallBER', ...
    'AverageBitsPerSymbol', ...
    'SpectralEfficiency', ...
    'AverageThroughput_bps', ...
    'EstimatedCorrectThroughput_bps'});

fprintf('\n========== CSI COMPARISON ==========\n');

disp(summaryTable);

%% 7. Save Results

resultsFolder = fullfile(projectRoot,'results');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

writetable(summaryTable, ...
    fullfile(resultsFolder, ...
    'perfect_vs_imperfect_csi.csv'));

fprintf('\nCSI comparison results saved.\n');

fprintf('\nImperfect CSI simulation completed.\n');
