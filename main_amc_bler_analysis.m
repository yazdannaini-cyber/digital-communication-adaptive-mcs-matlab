
clc;
clear;
close all;

%% =====================================================
% ROBUST ADAPTIVE MODULATION - BLER PERFORMANCE ANALYSIS
%
% Modulations:
% BPSK / QPSK / 16-QAM
%
% Channels:
% Rayleigh / Rician
%
% CSI:
% Imperfect CSI
%
% Performance Metrics:
% BER / SER / BLER / Throughput / Spectral Efficiency
% ======================================================

%% 1. PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

%% 2. SYSTEM PARAMETERS

targetBER = 1e-3;

averageEsN0_dB = 20;

NMSE_dB = -20;

K_dB = 6;

numBlocks = 5000;

symbolsPerBlock = 200;

symbolRate = 1e6;

rolloff = 0.25;

safetyMargins_dB = 0:1:6;

channelNames = {'Rayleigh','Rician'};

numChannels = numel(channelNames);

numMargins = numel(safetyMargins_dB);

%% 3. AMC THRESHOLDS

thresholds = calculate_amc_thresholds(targetBER);

modulationNames = thresholds.modulationNames;

bitsPerSymbol = thresholds.bitsPerSymbol;

numModes = numel(bitsPerSymbol);

fprintf('Adaptive Modulation BLER Analysis\n');

fprintf('Target BER: %.4e\n',targetBER);

fprintf('Average Es/N0: %.2f dB\n',averageEsN0_dB);

fprintf('Channel Estimation NMSE: %.2f dB\n',NMSE_dB);

fprintf('Rician K-factor: %.2f dB\n',K_dB);

fprintf('Number of blocks: %d\n',numBlocks);

fprintf('Symbols per block: %d\n',symbolsPerBlock);

%% 4. RANDOM DATA GENERATION

rng(1616,'twister');

% Common payload for all safety margins

baseBits = cell(numBlocks,1);

for b = 1:numBlocks

    baseBits{b} = ...
        randi([0 1],1,4*symbolsPerBlock);

end

% Common complex Gaussian noise samples

noiseUnit = ...
    (randn(numBlocks,symbolsPerBlock) + ...
     1i*randn(numBlocks,symbolsPerBlock))/sqrt(2);

gammaEs = 10^(averageEsN0_dB/10);

noiseScale = sqrt(1/gammaEs);

%% 5. INITIALIZE STATISTICS

% Dimensions:
% 1 = Channel
% 2 = Safety Margin
% 3 = Modulation

modeBlockCount = ...
    zeros(numChannels,numMargins,numModes);

modeBits = ...
    zeros(numChannels,numMargins,numModes);

modeErrors = ...
    zeros(numChannels,numMargins,numModes);

modeSymbolErrors = ...
    zeros(numChannels,numMargins,numModes);

modeBlockErrors = ...
    zeros(numChannels,numMargins,numModes);

outageBlocks = zeros(numChannels,numMargins);

transmittedBlocks = zeros(numChannels,numMargins);

totalBitErrors = zeros(numChannels,numMargins);

totalSymbolErrors = zeros(numChannels,numMargins);

totalBits = zeros(numChannels,numMargins);

totalTransmittedSymbols = zeros(numChannels,numMargins);

overallBER = NaN(numChannels,numMargins);

overallSER = NaN(numChannels,numMargins);

overallBLER = NaN(numChannels,numMargins);

modeBER = NaN(numChannels,numMargins,numModes);

modeSER = NaN(numChannels,numMargins,numModes);

modeBLER = NaN(numChannels,numMargins,numModes);

averageBitsPerSymbol = zeros(numChannels,numMargins);

spectralEfficiency = zeros(numChannels,numMargins);

grossThroughput = zeros(numChannels,numMargins);

correctThroughput = zeros(numChannels,numMargins);

outageProbability = zeros(numChannels,numMargins);

%% 6. MAIN SIMULATION

for c = 1:numChannels

    channelType = channelNames{c};

    fprintf('\n====================================\n');

    fprintf('CHANNEL: %s\n',channelType);

    %% Generate Common Actual Channel Coefficients

    hTrue = generate_block_fading_coefficients( ...
        numBlocks,channelType,K_dB);

    %% Generate Common Channel Estimates

    hEstimate = estimate_channel( ...
        hTrue,NMSE_dB);

    %% Safety Margin Sweep

    for g = 1:numMargins

        margin = safetyMargins_dB(g);

        fprintf('\n====================================\n');

        fprintf('Safety Margin = %.1f dB\n',margin);

        %% Initialize Per-Margin Counters

        blockErrorFlags = false(numBlocks,1);

        transmittedBlockMask = false(numBlocks,1);

        currentBitErrors = 0;

        currentSymbolErrors = 0;

        currentTotalBits = 0;

        currentTotalSymbols = 0;

        %% Process Each Block

        for b = 1:numBlocks

            %% 1. Estimate Instantaneous Channel SNR

            estimatedChannelPower = abs(hEstimate(b))^2;

            if estimatedChannelPower <= 0

                estimatedSNR_dB = -Inf;

            else

                estimatedSNR_dB = ...
                    averageEsN0_dB + ...
                    10*log10(estimatedChannelPower);

            end

            %% 2. Robust Modulation Selection

            [mode,modeName] = ...
                select_robust_adaptive_modulation( ...
                estimatedSNR_dB,margin,thresholds);

            %% 3. Outage Detection

            if mode == 0

                outageBlocks(c,g) = ...
                    outageBlocks(c,g)+1;

                continue;

            end

            %% 4. Determine Modulation Parameters

            currentBitsPerSymbol = bitsPerSymbol(mode);

            currentNumberOfBits = ...
                currentBitsPerSymbol*symbolsPerBlock;

            %% 5. Generate Common Payload Prefix

            txBits = ...
                baseBits{b}(1:currentNumberOfBits);

            %% 6. Modulation

            switch mode

                case 1

                    txSymbols = bpsk_modulator(txBits);

                case 2

                    txSymbols = qpsk_modulator(txBits);

                case 3

                    txSymbols = qam16_modulator(txBits);

                otherwise

                    error('Invalid modulation index.');

            end

            %% 7. Actual Block Fading Channel

            noise = noiseScale*noiseUnit(b,:);

            rxSymbols = ...
                hTrue(b)*txSymbols + noise;

            %% 8. Equalization Using Estimated CSI

            equalizedSymbols = ...
                coherent_equalizer( ...
                rxSymbols,hEstimate(b));

            %% 9. Demodulation

            switch mode

                case 1

                    rxBits = ...
                        bpsk_demodulator(equalizedSymbols);

                case 2

                    rxBits = ...
                        qpsk_demodulator(equalizedSymbols);

                case 3

                    rxBits = ...
                        qam16_demodulator(equalizedSymbols);

            end

            %% 10. Calculate Bit Errors

            [~,bitErrors] = ...
                calculate_ber(txBits,rxBits);

            %% 11. Calculate Symbol Errors

            [~,symbolErrors] = ...
                calculate_ser( ...
                txBits,rxBits,currentBitsPerSymbol);

            %% 12. Block Error Detection

            transmittedBlockMask(b) = true;

            blockErrorFlags(b) = (bitErrors > 0);

            %% 13. Accumulate Per-Modulation Statistics

            modeBlockCount(c,g,mode) = ...
                modeBlockCount(c,g,mode)+1;

            modeBits(c,g,mode) = ...
                modeBits(c,g,mode)+currentNumberOfBits;

            modeErrors(c,g,mode) = ...
                modeErrors(c,g,mode)+bitErrors;

            modeSymbolErrors(c,g,mode) = ...
                modeSymbolErrors(c,g,mode)+symbolErrors;

            if bitErrors > 0

                modeBlockErrors(c,g,mode) = ...
                    modeBlockErrors(c,g,mode)+1;

            end

            %% 14. Accumulate Overall Statistics

            currentBitErrors = ...
                currentBitErrors+bitErrors;

            currentSymbolErrors = ...
                currentSymbolErrors+symbolErrors;

            currentTotalBits = ...
                currentTotalBits+currentNumberOfBits;

            currentTotalSymbols = ...
                currentTotalSymbols+symbolsPerBlock;

        end

        %% 7. FINAL METRIC CALCULATIONS

        %% 1. Transmitted Block Count

        transmittedBlocks(c,g) = ...
            sum(transmittedBlockMask);

        %% 2. BER

        totalBitErrors(c,g) = currentBitErrors;

        totalBits(c,g) = currentTotalBits;

        if currentTotalBits > 0

            overallBER(c,g) = ...
                currentBitErrors/currentTotalBits;

        end

        %% 3. SER

        totalSymbolErrors(c,g) = currentSymbolErrors;

        totalTransmittedSymbols(c,g) = currentTotalSymbols;

        if currentTotalSymbols > 0

            overallSER(c,g) = ...
                currentSymbolErrors/currentTotalSymbols;

        end

        %% 4. BLER

        if transmittedBlocks(c,g) > 0

            [overallBLER(c,g),~] = ...
                calculate_bler( ...
                blockErrorFlags(transmittedBlockMask));

        end

        %% 5. Outage Probability

        outageProbability(c,g) = ...
            outageBlocks(c,g)/numBlocks;

        %% 6. Conditional BER / SER / BLER

        for m = 1:numModes

            if modeBlockCount(c,g,m) > 0

                modeBER(c,g,m) = ...
                    modeErrors(c,g,m)/modeBits(c,g,m);

                modeSER(c,g,m) = ...
                    modeSymbolErrors(c,g,m)/ ...
                    (modeBlockCount(c,g,m)*symbolsPerBlock);

                modeBLER(c,g,m) = ...
                    modeBlockErrors(c,g,m)/modeBlockCount(c,g,m);

            end

        end

        %% 7. Average Bits per Available Symbol

        totalAvailableSymbols = ...
            numBlocks*symbolsPerBlock;

        averageBitsPerSymbol(c,g) = ...
            currentTotalBits/totalAvailableSymbols;

        %% 8. Spectral Efficiency

        spectralEfficiency(c,g) = ...
            averageBitsPerSymbol(c,g)/(1+rolloff);

        %% 9. Throughput

        grossThroughput(c,g) = ...
            symbolRate*averageBitsPerSymbol(c,g);

        correctThroughput(c,g) = ...
            symbolRate*(currentTotalBits-currentBitErrors) / ...
            totalAvailableSymbols;

        %% 10. DISPLAY RESULTS

        fprintf('Outage probability: %.6f\n', ...
            outageProbability(c,g));

        fprintf('Transmitted blocks: %d\n', ...
            transmittedBlocks(c,g));

        fprintf('Erroneous blocks: %d\n', ...
            modeBlockErrors(c,g,1)+ ...
            modeBlockErrors(c,g,2)+ ...
            modeBlockErrors(c,g,3));

        fprintf('Overall BER: %.8e\n',overallBER(c,g));

        fprintf('Overall SER: %.8e\n',overallSER(c,g));

        fprintf('Overall BLER: %.8e\n',overallBLER(c,g));

        fprintf('Average bits/symbol: %.6f\n', ...
            averageBitsPerSymbol(c,g));

        fprintf('Spectral efficiency: %.6f bit/s/Hz\n', ...
            spectralEfficiency(c,g));

        fprintf('Average throughput: %.6f Mbps\n', ...
            grossThroughput(c,g)/1e6);

        fprintf('Estimated correct throughput: %.6f Mbps\n', ...
            correctThroughput(c,g)/1e6);

        %% Per-Modulation Results

        fprintf('\nMODULATION PERFORMANCE:\n');

        for m = 1:numModes

            fprintf('\n%s:\n',modulationNames{m});

            fprintf('Selected blocks: %d\n', ...
                modeBlockCount(c,g,m));

            fprintf('Conditional BER: %.8e\n', ...
                modeBER(c,g,m));

            fprintf('Conditional SER: %.8e\n', ...
                modeSER(c,g,m));

            fprintf('Conditional BLER: %.8e\n', ...
                modeBLER(c,g,m));

        end

    end

end

%% 8. BUILD SUMMARY TABLE

numSummaryRows = numChannels*numMargins;

channelColumn = strings(numSummaryRows,1);

marginColumn = zeros(numSummaryRows,1);

outageColumn = zeros(numSummaryRows,1);

transmittedColumn = zeros(numSummaryRows,1);

berColumn = NaN(numSummaryRows,1);

serColumn = NaN(numSummaryRows,1);

blerColumn = NaN(numSummaryRows,1);

avgBitsColumn = zeros(numSummaryRows,1);

spectralColumn = zeros(numSummaryRows,1);

throughputColumn = zeros(numSummaryRows,1);

correctThroughputColumn = zeros(numSummaryRows,1);

row = 0;

for c = 1:numChannels

    for g = 1:numMargins

        row = row+1;

        channelColumn(row) = channelNames{c};

        marginColumn(row) = safetyMargins_dB(g);

        outageColumn(row) = outageProbability(c,g);

        transmittedColumn(row) = transmittedBlocks(c,g);

        berColumn(row) = overallBER(c,g);

        serColumn(row) = overallSER(c,g);

        blerColumn(row) = overallBLER(c,g);

        avgBitsColumn(row) = averageBitsPerSymbol(c,g);

        spectralColumn(row) = spectralEfficiency(c,g);

        throughputColumn(row) = grossThroughput(c,g);

        correctThroughputColumn(row) = ...
            correctThroughput(c,g);

    end

end

summaryTable = table( ...
    channelColumn, ...
    marginColumn, ...
    outageColumn, ...
    transmittedColumn, ...
    berColumn, ...
    serColumn, ...
    blerColumn, ...
    avgBitsColumn, ...
    spectralColumn, ...
    throughputColumn, ...
    correctThroughputColumn, ...
    'VariableNames',{ ...
    'Channel', ...
    'SafetyMargin_dB', ...
    'OutageProbability', ...
    'TransmittedBlocks', ...
    'OverallBER', ...
    'OverallSER', ...
    'OverallBLER', ...
    'AverageBitsPerSymbol', ...
    'SpectralEfficiency', ...
    'GrossThroughput_bps', ...
    'EstimatedCorrectThroughput_bps'});

fprintf('\n========== BLER PERFORMANCE SUMMARY ==========\n');

disp(summaryTable);

%% 9. BUILD MODULATION USAGE TABLE

usageRows = numChannels*numMargins*numModes;

usageChannel = strings(usageRows,1);

usageMargin = zeros(usageRows,1);

usageModulation = strings(usageRows,1);

usageBlocks = zeros(usageRows,1);

usageFraction = zeros(usageRows,1);

conditionalBER = NaN(usageRows,1);

conditionalSER = NaN(usageRows,1);

conditionalBLER = NaN(usageRows,1);

row = 0;

for c = 1:numChannels

    for g = 1:numMargins

        for m = 1:numModes

            row = row+1;

            usageChannel(row) = channelNames{c};

            usageMargin(row) = safetyMargins_dB(g);

            usageModulation(row) = modulationNames{m};

            usageBlocks(row) = modeBlockCount(c,g,m);

            usageFraction(row) = ...
                modeBlockCount(c,g,m)/numBlocks;

            conditionalBER(row) = modeBER(c,g,m);

            conditionalSER(row) = modeSER(c,g,m);

            conditionalBLER(row) = modeBLER(c,g,m);

        end

    end

end

usageTable = table( ...
    usageChannel, ...
    usageMargin, ...
    usageModulation, ...
    usageBlocks, ...
    usageFraction, ...
    conditionalBER, ...
    conditionalSER, ...
    conditionalBLER, ...
    'VariableNames',{ ...
    'Channel', ...
    'SafetyMargin_dB', ...
    'Modulation', ...
    'SelectedBlocks', ...
    'BlockFraction', ...
    'ConditionalBER', ...
    'ConditionalSER', ...
    'ConditionalBLER'});

fprintf('\n========== MODULATION USAGE SUMMARY ==========\n');

disp(usageTable);

%% 10. PLOT OVERALL BER

figure('Color','w');

semilogy(safetyMargins_dB,overallBER(1,:), ...
    'o-','LineWidth',1.8,'MarkerSize',7);

hold on;

semilogy(safetyMargins_dB,overallBER(2,:), ...
    's-','LineWidth',1.8,'MarkerSize',7);

yline(targetBER,'--','Target BER');

grid on;

xlabel('Safety Margin (dB)');

ylabel('Overall BER');

title('BER vs Safety Margin');

legend('Rayleigh','Rician','BER Target', ...
    'Location','best');

%% 11. PLOT OVERALL BLER

figure('Color','w');

semilogy(safetyMargins_dB,overallBLER(1,:), ...
    'o-','LineWidth',1.8,'MarkerSize',7);

hold on;

semilogy(safetyMargins_dB,overallBLER(2,:), ...
    's-','LineWidth',1.8,'MarkerSize',7);

grid on;

xlabel('Safety Margin (dB)');

ylabel('Overall BLER');

title('BLER vs Safety Margin');

legend('Rayleigh','Rician','Location','best');

%% 12. PLOT THROUGHPUT

figure('Color','w');

plot(safetyMargins_dB,grossThroughput(1,:)/1e6, ...
    'o-','LineWidth',1.8,'MarkerSize',7);

hold on;

plot(safetyMargins_dB,grossThroughput(2,:)/1e6, ...
    's-','LineWidth',1.8,'MarkerSize',7);

grid on;

xlabel('Safety Margin (dB)');

ylabel('Average Throughput (Mbps)');

title('Throughput vs Safety Margin');

legend('Rayleigh','Rician','Location','best');

%% 13. PLOT OUTAGE PROBABILITY

figure('Color','w');

plot(safetyMargins_dB,outageProbability(1,:), ...
    'o-','LineWidth',1.8,'MarkerSize',7);

hold on;

plot(safetyMargins_dB,outageProbability(2,:), ...
    's-','LineWidth',1.8,'MarkerSize',7);

grid on;

xlabel('Safety Margin (dB)');

ylabel('Outage Probability');

title('Outage Probability vs Safety Margin');

legend('Rayleigh','Rician','Location','best');

%% 14. SAVE RESULTS

resultsFolder = fullfile(projectRoot,'results');

figuresFolder = fullfile(resultsFolder,'figures');

if ~exist(figuresFolder,'dir')

    mkdir(figuresFolder);

end

%% Save Figures

figure(1);

exportgraphics(gcf, ...
    fullfile(figuresFolder,'amc_ber_vs_margin.png'), ...
    'Resolution',300);

figure(2);

exportgraphics(gcf, ...
    fullfile(figuresFolder,'amc_bler_vs_margin.png'), ...
    'Resolution',300);

figure(3);

exportgraphics(gcf, ...
    fullfile(figuresFolder,'amc_throughput_vs_margin.png'), ...
    'Resolution',300);

figure(4);

exportgraphics(gcf, ...
    fullfile(figuresFolder,'amc_outage_vs_margin.png'), ...
    'Resolution',300);

%% Save CSV Tables

writetable(summaryTable, ...
    fullfile(resultsFolder,'amc_margin_summary.csv'));

writetable(usageTable, ...
    fullfile(resultsFolder,'amc_margin_usage.csv'));

fprintf('\n====================================\n');

fprintf('All BLER performance results saved.\n');

fprintf('Summary table saved successfully.\n');

fprintf('Modulation usage table saved successfully.\n');

fprintf('All four figures saved successfully.\n');

fprintf('\nAdaptive modulation BLER analysis completed.\n');
