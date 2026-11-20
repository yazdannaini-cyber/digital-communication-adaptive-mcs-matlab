
clc;
clear;
close all;

%% =========================================
% ADAPTIVE DIGITAL MODULATION
%
% BPSK / QPSK / 16-QAM
% Rayleigh and Rician Block Fading
%
% Perfect CSI at transmitter and receiver
% Fixed average symbol energy
% Fixed average Es/N0
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

%% 2. System Parameters

targetBER = 1e-3;

averageEsN0_dB = 20;

K_dB = 6;

numBlocks = 5000;

symbolsPerBlock = 200;

symbolRate = 1e6;

rolloff = 0.25;

channelNames = {'Rayleigh','Rician'};

numChannels = numel(channelNames);

rng(1401,'twister');

%% 3. Calculate AMC Thresholds

thresholds = calculate_amc_thresholds(targetBER);

modulationNames = thresholds.modulationNames;

bitsPerSymbol = thresholds.bitsPerSymbol;

numModes = numel(modulationNames);

fprintf('Adaptive Modulation Simulation\n');

fprintf('Target BER: %.4e\n',targetBER);

fprintf('Average Es/N0: %.2f dB\n',averageEsN0_dB);

fprintf('Number of blocks: %d\n',numBlocks);

fprintf('Symbols per block: %d\n',symbolsPerBlock);

%% 4. Display Thresholds

thresholdTable = table( ...
    string(modulationNames(:)), ...
    bitsPerSymbol(:), ...
    thresholds.requiredEbN0_dB(:), ...
    thresholds.requiredEsN0_dB(:), ...
    'VariableNames',{ ...
    'Modulation', ...
    'BitsPerSymbol', ...
    'RequiredEbN0_dB', ...
    'RequiredEsN0_dB'});

fprintf('\n========== MODULATION THRESHOLDS ==========\n');

disp(thresholdTable);

%% 5. Initialize Result Arrays

outageBlocks = zeros(numChannels,1);

modeBlockCount = zeros(numChannels,numModes);

modeBits = zeros(numChannels,numModes);

modeErrors = zeros(numChannels,numModes);

modeSymbols = zeros(numChannels,numModes);

modeSymbolErrors = zeros(numChannels,numModes);

overallBER = zeros(numChannels,1);

overallSER = zeros(numChannels,1);

averageBitsPerSymbol = zeros(numChannels,1);

spectralEfficiency = zeros(numChannels,1);

grossThroughput = zeros(numChannels,1);

correctThroughput = zeros(numChannels,1);

outageProbability = zeros(numChannels,1);

%% 6. Run Adaptive Simulation

for c = 1:numChannels

    channelType = channelNames{c};

    fprintf('\n====================================\n');

    fprintf('CHANNEL: %s\n',channelType);

    %% Generate One Channel Coefficient per Block

    hBlocks = generate_block_fading_coefficients( ...
        numBlocks,channelType,K_dB);

    totalBitErrors = 0;

    totalSymbolErrors = 0;

    totalBits = 0;

    totalTransmittedSymbols = 0;

    %% Block Processing

    for b = 1:numBlocks

        h = hBlocks(b);

        %% Estimate Instantaneous Es/N0

        channelPower = abs(h)^2;

        if channelPower <= 0

            instantaneousEsN0_dB = -Inf;

        else

            instantaneousEsN0_dB = ...
                averageEsN0_dB + 10*log10(channelPower);

        end

        %% Select Modulation

        [mode,modeName] = ...
            select_adaptive_modulation( ...
            instantaneousEsN0_dB,thresholds);

        %% Outage Handling

        if mode==0

            outageBlocks(c) = outageBlocks(c)+1;

            continue;

        end

        %% Determine Bits per Symbol

        currentBitsPerSymbol = bitsPerSymbol(mode);

        %% Generate Information Bits

        currentNumberOfBits = ...
            symbolsPerBlock*currentBitsPerSymbol;

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

        %% Block Fading Channel

        [rxSymbols,noise,noiseVariance] = ...
            block_fading_channel( ...
            txSymbols,h,averageEsN0_dB,1);

        %% Coherent Equalization

        equalizedSymbols = ...
            coherent_equalizer(rxSymbols,h);

        %% Demodulation

        switch mode

            case 1

                rxBits = bpsk_demodulator(equalizedSymbols);

            case 2

                rxBits = qpsk_demodulator(equalizedSymbols);

            case 3

                rxBits = qam16_demodulator(equalizedSymbols);

        end

        %% BER Calculation

        [~,bitErrors] = ...
            calculate_ber(txBits,rxBits);

        %% SER Calculation

        [~,symbolErrors] = ...
            calculate_ser( ...
            txBits,rxBits,currentBitsPerSymbol);

        %% Accumulate Mode Statistics

        modeBlockCount(c,mode) = ...
            modeBlockCount(c,mode)+1;

        modeBits(c,mode) = ...
            modeBits(c,mode)+currentNumberOfBits;

        modeErrors(c,mode) = ...
            modeErrors(c,mode)+bitErrors;

        modeSymbols(c,mode) = ...
            modeSymbols(c,mode)+symbolsPerBlock;

        modeSymbolErrors(c,mode) = ...
            modeSymbolErrors(c,mode)+symbolErrors;

        %% Accumulate Total Statistics

        totalBitErrors = totalBitErrors+bitErrors;

        totalSymbolErrors = ...
            totalSymbolErrors+symbolErrors;

        totalBits = totalBits+currentNumberOfBits;

        totalTransmittedSymbols = ...
            totalTransmittedSymbols+symbolsPerBlock;

    end

    %% Calculate Overall Performance

    if totalBits > 0

        overallBER(c) = totalBitErrors/totalBits;

    else

        overallBER(c) = NaN;

    end

    if totalTransmittedSymbols > 0

        overallSER(c) = ...
            totalSymbolErrors/totalTransmittedSymbols;

    else

        overallSER(c) = NaN;

    end

    %% Average Spectral Efficiency

    totalAvailableSymbols = ...
        numBlocks*symbolsPerBlock;

    averageBitsPerSymbol(c) = ...
        totalBits/totalAvailableSymbols;

    spectralEfficiency(c) = ...
        averageBitsPerSymbol(c)/(1+rolloff);

    %% Throughput

    grossThroughput(c) = ...
        symbolRate*averageBitsPerSymbol(c);

    correctThroughput(c) = ...
        symbolRate*(totalBits-totalBitErrors) / ...
        totalAvailableSymbols;

    %% Outage Probability

    outageProbability(c) = ...
        outageBlocks(c)/numBlocks;

    %% Display Channel Results

    fprintf('\nMode selection results:\n');

    for m = 1:numModes

        if modeBits(c,m)>0

            modeBER = modeErrors(c,m)/modeBits(c,m);

        else

            modeBER = NaN;

        end

        fprintf('%s: %d blocks | BER = %.6e\n', ...
            modulationNames{m}, ...
            modeBlockCount(c,m), ...
            modeBER);

    end

    fprintf('\nOutage probability: %.6f\n', ...
        outageProbability(c));

    fprintf('Overall BER: %.8e\n',overallBER(c));

    fprintf('Overall SER: %.8e\n',overallSER(c));

    fprintf('Average bits/symbol: %.6f\n', ...
        averageBitsPerSymbol(c));

    fprintf('Spectral efficiency: %.6f bit/s/Hz\n', ...
        spectralEfficiency(c));

    fprintf('Gross throughput: %.6f Mbps\n', ...
        grossThroughput(c)/1e6);

    fprintf('Estimated correct throughput: %.6f Mbps\n', ...
        correctThroughput(c)/1e6);

end

%% 7. Create Summary Table

summaryTable = table( ...
    string(channelNames(:)), ...
    outageBlocks, ...
    outageProbability, ...
    overallBER, ...
    overallSER, ...
    averageBitsPerSymbol, ...
    spectralEfficiency, ...
    grossThroughput, ...
    correctThroughput, ...
    'VariableNames',{ ...
    'Channel', ...
    'OutageBlocks', ...
    'OutageProbability', ...
    'OverallBER', ...
    'OverallSER', ...
    'AverageBitsPerSymbol', ...
    'SpectralEfficiency', ...
    'GrossThroughput_bps', ...
    'EstimatedCorrectThroughput_bps'});

fprintf('\n========== ADAPTIVE SYSTEM SUMMARY ==========\n');

disp(summaryTable);

%% 8. Create Mode Usage Table

modeFractions = modeBlockCount/numBlocks;

modeBER = NaN(numChannels,numModes);

for c = 1:numChannels

    for m = 1:numModes

        if modeBits(c,m)>0

            modeBER(c,m) = ...
                modeErrors(c,m)/modeBits(c,m);

        end

    end

end

channelColumn = strings(numChannels*numModes,1);

modulationColumn = strings(numChannels*numModes,1);

selectedBlocks = zeros(numChannels*numModes,1);

blockFraction = zeros(numChannels*numModes,1);

conditionalBER = NaN(numChannels*numModes,1);

row = 0;

for c = 1:numChannels

    for m = 1:numModes

        row = row+1;

        channelColumn(row) = channelNames{c};

        modulationColumn(row) = modulationNames{m};

        selectedBlocks(row) = modeBlockCount(c,m);

        blockFraction(row) = modeFractions(c,m);

        conditionalBER(row) = modeBER(c,m);

    end

end

modeTable = table( ...
    channelColumn, ...
    modulationColumn, ...
    selectedBlocks, ...
    blockFraction, ...
    conditionalBER, ...
    'VariableNames',{ ...
    'Channel', ...
    'Modulation', ...
    'SelectedBlocks', ...
    'BlockFraction', ...
    'ConditionalBER'});

fprintf('\n========== MODULATION USAGE ==========\n');

disp(modeTable);

%% 9. Plot Modulation Selection

figure('Color','w');

bar(categorical(channelNames), ...
    [modeFractions,outageProbability], ...
    'stacked');

grid on;

ylabel('Fraction of Total Blocks');

title('Adaptive Modulation Selection Probability');

legend('BPSK','QPSK','16-QAM','Outage', ...
    'Location','bestoutside');

ylim([0 1]);

%% 10. Plot Spectral Efficiency

figure('Color','w');

bar(categorical(channelNames),spectralEfficiency);

grid on;

ylabel('Spectral Efficiency (bit/s/Hz)');

title('Average Adaptive Spectral Efficiency');

%% 11. Save Results

resultsFolder = fullfile(projectRoot,'results');

figuresFolder = fullfile(resultsFolder,'figures');

if ~exist(figuresFolder,'dir')
    mkdir(figuresFolder);
end

exportgraphics(figure(1), ...
    fullfile(figuresFolder, ...
    'adaptive_modulation_selection.png'), ...
    'Resolution',300);

exportgraphics(figure(2), ...
    fullfile(figuresFolder, ...
    'adaptive_spectral_efficiency.png'), ...
    'Resolution',300);

writetable(summaryTable, ...
    fullfile(resultsFolder, ...
    'adaptive_modulation_summary.csv'));

writetable(modeTable, ...
    fullfile(resultsFolder, ...
    'adaptive_modulation_usage.csv'));

writetable(thresholdTable, ...
    fullfile(resultsFolder, ...
    'adaptive_modulation_thresholds.csv'));

fprintf('\nAdaptive modulation figures saved.\n');

fprintf('Adaptive modulation tables saved.\n');

fprintf('\nAdaptive modulation simulation completed.\n');
