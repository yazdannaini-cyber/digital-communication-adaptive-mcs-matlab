
clc;
clear;
close all;

%% =========================================
% ROBUST ADAPTIVE MODULATION
% SAFETY MARGIN ANALYSIS
%
% Rayleigh / Rician Block Fading
% BPSK / QPSK / 16-QAM
% Imperfect CSI
% ==========================================

%% 1. Project Setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

%% 2. Simulation Parameters

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

%% 3. AMC Thresholds

thresholds = calculate_amc_thresholds(targetBER);

modulationNames = thresholds.modulationNames;

bitsPerSymbol = thresholds.bitsPerSymbol;

numModes = numel(modulationNames);

%% 4. Reproducible Random Data

rng(1616,'twister');

% One common payload per block for all margins

baseBits = cell(numBlocks,1);

for b = 1:numBlocks

    baseBits{b} = ...
        randi([0 1],1,4*symbolsPerBlock);

end

% Unit-power complex Gaussian noise samples
% Reused for every margin and both channels

noiseUnit = ...
    (randn(numBlocks,symbolsPerBlock) + ...
     1i*randn(numBlocks,symbolsPerBlock))/sqrt(2);

gammaEs = 10^(averageEsN0_dB/10);

noiseScale = sqrt(1/gammaEs);

%% 5. Initialize Statistics

modeBlocks = zeros(numChannels,numMargins,numModes);

modeBits = zeros(numChannels,numMargins,numModes);

modeErrors = zeros(numChannels,numMargins,numModes);

modeSymbols = zeros(numChannels,numMargins,numModes);

modeSymbolErrors = zeros(numChannels,numMargins,numModes);

outageBlocks = zeros(numChannels,numMargins);

overallBER = zeros(numChannels,numMargins);

overallSER = zeros(numChannels,numMargins);

averageBitsPerSymbol = zeros(numChannels,numMargins);

spectralEfficiency = zeros(numChannels,numMargins);

grossThroughput = zeros(numChannels,numMargins);

correctThroughput = zeros(numChannels,numMargins);

conditionalBER = NaN(numChannels,numMargins,numModes);

%% 6. Run Simulation

for c = 1:numChannels

    channelType = channelNames{c};

    fprintf('\n====================================\n');

    fprintf('CHANNEL: %s\n',channelType);

    %% Generate Common Channel and Estimates

    hTrue = generate_block_fading_coefficients( ...
        numBlocks,channelType,K_dB);

    hEstimate = estimate_channel(hTrue,NMSE_dB);

    %% Sweep Safety Margins

    for g = 1:numMargins

        margin = safetyMargins_dB(g);

        fprintf('\nSafety Margin = %.1f dB\n',margin);

        totalBitErrors = 0;

        totalSymbolErrors = 0;

        totalBits = 0;

        totalTransmittedSymbols = 0;

        %% Process Blocks

        for b = 1:numBlocks

            %% Estimated Channel Quality

            if abs(hEstimate(b)) <= 0

                estimatedSNR_dB = -Inf;

            else

                estimatedSNR_dB = ...
                    averageEsN0_dB + ...
                    10*log10(abs(hEstimate(b))^2);

            end

            %% Robust Modulation Selection

            [mode,~] = select_robust_adaptive_modulation( ...
                estimatedSNR_dB,margin,thresholds);

            %% Outage

            if mode==0

                outageBlocks(c,g) = ...
                    outageBlocks(c,g)+1;

                continue;

            end

            %% Bits per Symbol

            currentK = bitsPerSymbol(mode);

            currentNumberOfBits = ...
                currentK*symbolsPerBlock;

            %% Common Payload Prefix

            txBits = ...
                baseBits{b}(1:currentNumberOfBits);

            %% Modulation

            switch mode

                case 1

                    txSymbols = bpsk_modulator(txBits);

                case 2

                    txSymbols = qpsk_modulator(txBits);

                case 3

                    txSymbols = qam16_modulator(txBits);

            end

            %% Actual Channel

            noise = noiseScale*noiseUnit(b,:);

            rxSymbols = ...
                hTrue(b)*txSymbols + noise;

            %% Equalization with Estimated Channel

            equalizedSymbols = ...
                coherent_equalizer(rxSymbols,hEstimate(b));

            %% Demodulation

            switch mode

                case 1

                    rxBits = bpsk_demodulator(equalizedSymbols);

                case 2

                    rxBits = qpsk_demodulator(equalizedSymbols);

                case 3

                    rxBits = qam16_demodulator(equalizedSymbols);

            end

            %% BER and SER

            [~,bitErrors] = ...
                calculate_ber(txBits,rxBits);

            [~,symbolErrors] = ...
                calculate_ser(txBits,rxBits,currentK);

            %% Accumulate Mode Statistics

            modeBlocks(c,g,mode) = ...
                modeBlocks(c,g,mode)+1;

            modeBits(c,g,mode) = ...
                modeBits(c,g,mode)+currentNumberOfBits;

            modeErrors(c,g,mode) = ...
                modeErrors(c,g,mode)+bitErrors;

            modeSymbols(c,g,mode) = ...
                modeSymbols(c,g,mode)+symbolsPerBlock;

            modeSymbolErrors(c,g,mode) = ...
                modeSymbolErrors(c,g,mode)+symbolErrors;

            %% Accumulate Overall Statistics

            totalBitErrors = totalBitErrors+bitErrors;

            totalSymbolErrors = ...
                totalSymbolErrors+symbolErrors;

            totalBits = totalBits+currentNumberOfBits;

            totalTransmittedSymbols = ...
                totalTransmittedSymbols+symbolsPerBlock;

        end

        %% Overall BER

        if totalBits>0

            overallBER(c,g) = totalBitErrors/totalBits;

        else

            overallBER(c,g) = NaN;

        end

        %% Overall SER

        if totalTransmittedSymbols>0

            overallSER(c,g) = ...
                totalSymbolErrors/totalTransmittedSymbols;

        else

            overallSER(c,g) = NaN;

        end

        %% Throughput Includes Outage Time

        availableSymbols = ...
            numBlocks*symbolsPerBlock;

        averageBitsPerSymbol(c,g) = ...
            totalBits/availableSymbols;

        grossThroughput(c,g) = ...
            symbolRate*averageBitsPerSymbol(c,g);

        correctThroughput(c,g) = ...
            symbolRate*(totalBits-totalBitErrors)/ ...
            availableSymbols;

        spectralEfficiency(c,g) = ...
            averageBitsPerSymbol(c,g)/(1+rolloff);

        %% Conditional BER per Modulation

        for m = 1:numModes

            if modeBits(c,g,m)>0

                conditionalBER(c,g,m) = ...
                    modeErrors(c,g,m)/modeBits(c,g,m);

            end

        end

        %% Display

        fprintf('Outage probability: %.6f\n', ...
            outageBlocks(c,g)/numBlocks);

        fprintf('Overall BER: %.8e\n',overallBER(c,g));

        fprintf('Overall SER: %.8e\n',overallSER(c,g));

        fprintf('Average bits/symbol: %.6f\n', ...
            averageBitsPerSymbol(c,g));

        fprintf('Spectral efficiency: %.6f bit/s/Hz\n', ...
            spectralEfficiency(c,g));

        fprintf('Average throughput: %.6f Mbps\n', ...
            grossThroughput(c,g)/1e6);

        fprintf('Correct throughput: %.6f Mbps\n', ...
            correctThroughput(c,g)/1e6);

    end

end

%% 7. Build Summary Table

numRows = numChannels*numMargins;

channelColumn = strings(numRows,1);

marginColumn = zeros(numRows,1);

outageColumn = zeros(numRows,1);

berColumn = zeros(numRows,1);

serColumn = zeros(numRows,1);

avgBitsColumn = zeros(numRows,1);

spectralColumn = zeros(numRows,1);

throughputColumn = zeros(numRows,1);

correctThroughputColumn = zeros(numRows,1);

row = 0;

for c = 1:numChannels

    for g = 1:numMargins

        row = row+1;

        channelColumn(row) = channelNames{c};

        marginColumn(row) = safetyMargins_dB(g);

        outageColumn(row) = ...
            outageBlocks(c,g)/numBlocks;

        berColumn(row) = overallBER(c,g);

        serColumn(row) = overallSER(c,g);

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
    berColumn, ...
    serColumn, ...
    avgBitsColumn, ...
    spectralColumn, ...
    throughputColumn, ...
    correctThroughputColumn, ...
    'VariableNames',{ ...
    'Channel', ...
    'SafetyMargin_dB', ...
    'OutageProbability', ...
    'OverallBER', ...
    'OverallSER', ...
    'AverageBitsPerSymbol', ...
    'SpectralEfficiency', ...
    'GrossThroughput_bps', ...
    'EstimatedCorrectThroughput_bps'});

fprintf('\n========== SAFETY MARGIN RESULTS ==========\n');

disp(summaryTable);

%% 8. Build Modulation Usage Table

usageRows = numChannels*numMargins*numModes;

usageChannel = strings(usageRows,1);

usageMargin = zeros(usageRows,1);

usageModulation = strings(usageRows,1);

usageBlocks = zeros(usageRows,1);

usageFraction = zeros(usageRows,1);

usageBER = NaN(usageRows,1);

row = 0;

for c = 1:numChannels

    for g = 1:numMargins

        for m = 1:numModes

            row = row+1;

            usageChannel(row) = channelNames{c};

            usageMargin(row) = safetyMargins_dB(g);

            usageModulation(row) = modulationNames{m};

            usageBlocks(row) = modeBlocks(c,g,m);

            usageFraction(row) = modeBlocks(c,g,m)/numBlocks;

            usageBER(row) = conditionalBER(c,g,m);

        end

    end

end

usageTable = table( ...
    usageChannel, ...
    usageMargin, ...
    usageModulation, ...
    usageBlocks, ...
    usageFraction, ...
    usageBER, ...
    'VariableNames',{ ...
    'Channel', ...
    'SafetyMargin_dB', ...
    'Modulation', ...
    'SelectedBlocks', ...
    'BlockFraction', ...
    'ConditionalBER'});

fprintf('\n========== MODULATION USAGE ==========\n');

disp(usageTable);

%% 9. Plot Overall BER

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

title('Robust Adaptive Modulation: BER vs Safety Margin');

legend('Rayleigh','Rician','BER Target', ...
    'Location','best');

%% 10. Plot Average Throughput

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

%% 11. Plot Outage Probability

figure('Color','w');

plot(safetyMargins_dB, ...
    outageBlocks(1,:)/numBlocks,'o-', ...
    'LineWidth',1.8);

hold on;

plot(safetyMargins_dB, ...
    outageBlocks(2,:)/numBlocks,'s-', ...
    'LineWidth',1.8);

grid on;

xlabel('Safety Margin (dB)');

ylabel('Outage Probability');

title('Outage Probability vs Safety Margin');

legend('Rayleigh','Rician','Location','best');

%% 12. Save Results

resultsFolder = fullfile(projectRoot,'results');

figuresFolder = fullfile(resultsFolder,'figures');

if ~exist(figuresFolder,'dir')
    mkdir(figuresFolder);
end

exportgraphics(figure(1), ...
    fullfile(figuresFolder,'amc_ber_vs_margin.png'), ...
    'Resolution',300);

exportgraphics(figure(2), ...
    fullfile(figuresFolder,'amc_throughput_vs_margin.png'), ...
    'Resolution',300);

exportgraphics(figure(3), ...
    fullfile(figuresFolder,'amc_outage_vs_margin.png'), ...
    'Resolution',300);

writetable(summaryTable, ...
    fullfile(resultsFolder,'amc_margin_summary.csv'));

writetable(usageTable, ...
    fullfile(resultsFolder,'amc_margin_usage.csv'));

fprintf('\nAll safety margin results saved.\n');

fprintf('\nRobust AMC simulation completed.\n');
