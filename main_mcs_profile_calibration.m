clc;
clear;
close all;

%% =========================================================
%  MILESTONE 31.4
%  Empirical Adaptive MCS Profile Calibration
%
%  Modulation:
%       BPSK, QPSK, 16QAM
%
%  Interleaver depth:
%       4, 16
%
%  Channel:
%       Rayleigh, Rician
%
%  FEC:
%       Convolutional code, rate 1/2
%
%  Packet:
%       Payload + CRC-16 + convolutional coding + padding
%
%  CSI:
%       Perfect channel state information
%
%  Eb/N0:
%       Defined per information payload bit
%% =========================================================

fprintf('\n');
fprintf('===============================================\n');
fprintf(' MCS PROFILE CALIBRATION\n');
fprintf('===============================================\n\n');

%% 1. Project setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));
rehash;

requiredFunctions = {
    'adaptive_link_transmitter'
    'adaptive_link_receiver'
    'select_adaptive_link_profile'
    'get_modulation_constellation'
    'block_interleaver'
    'block_deinterleaver'
};

for k = 1:numel(requiredFunctions)

    if exist(requiredFunctions{k}, 'file') ~= 2
        error('Required function not found: %s', ...
            requiredFunctions{k});
    end

end

%% 2. Simulation configuration

payloadLength = 1024;

% 500 packets per operating point.
% Use 50 for a quick software/debugging run.
numPackets = 500;

EbN0dBList = 4:2:20;

channelTypes = {'rayleigh', 'rician'};

modulationTypes = {'BPSK', 'QPSK', '16QAM'};

interleaverDepths = [4, 16];

numFadingBlocks = 4;

ricianKFactor_dB = 6;

targetPER = 0.20;

symbolRate = 1e6;

confidenceLevel = 0.95;

rng(20261120, 'twister');

fprintf('Payload length       : %d bits\n', payloadLength);
fprintf('Packets per point    : %d\n', numPackets);
fprintf('Eb/N0 range          : %d to %d dB\n', ...
    EbN0dBList(1), EbN0dBList(end));
fprintf('Number of channels   : %d\n', numel(channelTypes));
fprintf('Number of MCS profiles: %d\n', ...
    numel(modulationTypes) * numel(interleaverDepths));
fprintf('Fading blocks        : %d\n', numFadingBlocks);
fprintf('Target PER           : %.3f\n\n', targetPER);

%% 3. Generate a common payload bank

payloadBank = randi( ...
    [0 1], payloadLength, numPackets);

%% 4. Determine maximum transmission length

[probeSymbols, probeInfo] = adaptive_link_transmitter( ...
    payloadBank(:,1), ...
    'BPSK', ...
    4, ...
    numFadingBlocks);

maxNumSymbols = numel(probeSymbols);

fprintf('Maximum symbol count : %d\n', maxNumSymbols);

%% 5. Prepare profile processing-cost measurements

numModulations = numel(modulationTypes);
numDepths = numel(interleaverDepths);

processingCostMatrix = zeros(numModulations, numDepths);

firstColumnReadyMatrix = zeros(numModulations, numDepths);

spectralEfficiencyMatrix = zeros(numModulations, numDepths);

codeRateMatrix = zeros(numModulations, numDepths);

bitsPerSymbolMatrix = zeros(numModulations, numDepths);

fprintf('\nMeasuring local processing costs...\n');

for m = 1:numModulations

    for d = 1:numDepths

        modulation = modulationTypes{m};
        depth = interleaverDepths(d);

        [processingCostMatrix(m,d), ...
         firstColumnReadyMatrix(m,d), ...
         spectralEfficiencyMatrix(m,d), ...
         codeRateMatrix(m,d), ...
         bitsPerSymbolMatrix(m,d)] = ...
            local_measure_profile_cost( ...
                payloadBank(:,1), ...
                modulation, ...
                depth, ...
                numFadingBlocks, ...
                symbolRate);

        fprintf('%-6s | Depth %2d | Processing %.6f ms | First-column %.6f ms\n', ...
            modulation, ...
            depth, ...
            processingCostMatrix(m,d), ...
            firstColumnReadyMatrix(m,d));

    end

end

%% 6. Preallocate calibration results

numRows = numel(channelTypes) * ...
          numel(EbN0dBList) * ...
          numModulations * ...
          numDepths;

Channel = cell(numRows,1);
Modulation = cell(numRows,1);

EbN0_dB = zeros(numRows,1);
BitsPerSymbol = zeros(numRows,1);
CodeRate = zeros(numRows,1);
InterleaverDepth = zeros(numRows,1);

BER = zeros(numRows,1);
PER = zeros(numRows,1);

PER_Lower95 = zeros(numRows,1);
PER_Upper95 = zeros(numRows,1);

PacketErrors = zeros(numRows,1);
NumPackets = zeros(numRows,1);

ProcessingCost_ms = zeros(numRows,1);
FirstColumnReady_ms = zeros(numRows,1);
EffectiveSpectralEfficiency = zeros(numRows,1);

%% 7. Main calibration loop

rowIndex = 0;

fprintf('\n');
fprintf('===============================================\n');
fprintf(' STARTING CHANNEL CALIBRATION\n');
fprintf('===============================================\n');

for channelIndex = 1:numel(channelTypes)

    channelType = channelTypes{channelIndex};

    fprintf('\n-----------------------------------------------\n');
    fprintf('CHANNEL: %s\n', upper(channelType));
    fprintf('-----------------------------------------------\n');

    %% Generate common fading and noise realizations

    fadingBank = local_generate_fading_bank( ...
        channelType, ...
        numFadingBlocks, ...
        numPackets, ...
        ricianKFactor_dB);

    noiseBank = ( ...
        randn(maxNumSymbols, numPackets) + ...
        1i * randn(maxNumSymbols, numPackets)) / sqrt(2);

    %% Eb/N0 loop

    for snrIndex = 1:numel(EbN0dBList)

        currentEbN0dB = EbN0dBList(snrIndex);

        N0 = 10^(-currentEbN0dB/10);

        fprintf('\nEb/N0 = %2d dB\n', currentEbN0dB);

        %% Modulation loop

        for m = 1:numModulations

            modulation = modulationTypes{m};

            %% Interleaver-depth loop

            for d = 1:numDepths

                depth = interleaverDepths(d);

                packetErrors = 0;
                totalBitErrors = 0;

                fprintf('  %-6s | Depth %2d | ', ...
                    modulation, depth);

                %% Packet loop

                for packetIndex = 1:numPackets

                    payloadBits = payloadBank(:,packetIndex);

                    %% Transmitter

                    [txSymbols, txInfo] = ...
                        adaptive_link_transmitter( ...
                            payloadBits, ...
                            modulation, ...
                            depth, ...
                            numFadingBlocks);

                    txSymbols = txSymbols(:);

                    numSymbols = numel(txSymbols);

                    if mod(numSymbols, numFadingBlocks) ~= 0
                        error('Symbol count is not divisible by fading blocks.');
                    end

                    %% Block fading channel

                    symbolsPerBlock = ...
                        numSymbols / numFadingBlocks;

                    hBlocks = fadingBank(:,packetIndex);

                    hSymbols = repelem( ...
                        hBlocks, ...
                        symbolsPerBlock);

                    hSymbols = hSymbols(:);

                    %% Complex AWGN

                    noise = sqrt(N0) .* ...
                        noiseBank(1:numSymbols,packetIndex);

                    %% Received signal

                    rxSymbols = ...
                        txSymbols .* hSymbols + noise;

                    %% Receiver

                    [decodedPayload, rxDiagnostics] = ...
                        adaptive_link_receiver( ...
                            rxSymbols, ...
                            hSymbols, ...
                            N0, ...
                            txInfo);

                    decodedPayload = decodedPayload(:);

                    %% Payload error calculation

                    if numel(decodedPayload) ~= payloadLength

                        bitErrors = payloadLength;
                        packetError = true;

                    else

                        bitErrors = sum( ...
                            decodedPayload ~= payloadBits);

                        packetError = bitErrors > 0;

                    end

                    totalBitErrors = ...
                        totalBitErrors + bitErrors;

                    packetErrors = ...
                        packetErrors + double(packetError);

                end

                %% Calculate metrics

                measuredBER = totalBitErrors / ...
                    (payloadLength * numPackets);

                measuredPER = packetErrors / numPackets;

                [perLower, perUpper] = ...
                    local_wilson_interval( ...
                        packetErrors, ...
                        numPackets, ...
                        confidenceLevel);

                %% Store this profile

                rowIndex = rowIndex + 1;

                Channel{rowIndex} = channelType;

                Modulation{rowIndex} = modulation;

                EbN0_dB(rowIndex) = currentEbN0dB;

                BitsPerSymbol(rowIndex) = ...
                    bitsPerSymbolMatrix(m,d);

                CodeRate(rowIndex) = ...
                    codeRateMatrix(m,d);

                InterleaverDepth(rowIndex) = depth;

                BER(rowIndex) = measuredBER;

                PER(rowIndex) = measuredPER;

                PER_Lower95(rowIndex) = perLower;

                PER_Upper95(rowIndex) = perUpper;

                PacketErrors(rowIndex) = packetErrors;

                NumPackets(rowIndex) = numPackets;

                ProcessingCost_ms(rowIndex) = ...
                    processingCostMatrix(m,d);

                FirstColumnReady_ms(rowIndex) = ...
                    firstColumnReadyMatrix(m,d);

                EffectiveSpectralEfficiency(rowIndex) = ...
                    spectralEfficiencyMatrix(m,d);

                fprintf('BER = %.5e | PER = %.4f | PER Upper95 = %.4f\n', ...
                    measuredBER, ...
                    measuredPER, ...
                    perUpper);

            end

        end

    end

end

%% 8. Construct calibration table

ProfileTable = table( ...
    Channel, ...
    EbN0_dB, ...
    Modulation, ...
    BitsPerSymbol, ...
    CodeRate, ...
    InterleaverDepth, ...
    BER, ...
    PER, ...
    PER_Lower95, ...
    PER_Upper95, ...
    PacketErrors, ...
    NumPackets, ...
    ProcessingCost_ms, ...
    FirstColumnReady_ms, ...
    EffectiveSpectralEfficiency);

%% 9. Save calibration configuration

calibrationConfig = struct();

calibrationConfig.PayloadLength = payloadLength;
calibrationConfig.NumPackets = numPackets;
calibrationConfig.EbN0dBList = EbN0dBList;
calibrationConfig.ChannelTypes = channelTypes;
calibrationConfig.ModulationTypes = modulationTypes;
calibrationConfig.InterleaverDepths = interleaverDepths;
calibrationConfig.NumFadingBlocks = numFadingBlocks;
calibrationConfig.RicianKFactor_dB = ricianKFactor_dB;
calibrationConfig.TargetPER = targetPER;
calibrationConfig.SymbolRate = symbolRate;
calibrationConfig.ConfidenceLevel = confidenceLevel;

calibrationConfig.CSI = 'Perfect CSI';

calibrationConfig.EbN0Definition = ...
    'Energy per information payload bit';

%% 10. Save results

resultsDir = fullfile(projectRoot, 'results');

figuresDir = fullfile(resultsDir, 'figures');

if exist(resultsDir, 'dir') ~= 7
    mkdir(resultsDir);
end

if exist(figuresDir, 'dir') ~= 7
    mkdir(figuresDir);
end

csvPath = fullfile( ...
    resultsDir, ...
    'mcs_profile_calibration.csv');

matPath = fullfile( ...
    resultsDir, ...
    'mcs_profile_calibration.mat');

writetable(ProfileTable, csvPath);

save(matPath, ...
    'ProfileTable', ...
    'calibrationConfig');

%% 11. Display final table

fprintf('\n');
fprintf('===============================================\n');
fprintf(' FINAL MCS CALIBRATION TABLE\n');
fprintf('===============================================\n');

disp(ProfileTable);

%% 12. Plot PER performance

figure('Name', 'MCS Profile PER Calibration');

for channelIndex = 1:numel(channelTypes)

    channelType = channelTypes{channelIndex};

    subplot(1,2,channelIndex);

    hold on;
    grid on;

    for m = 1:numModulations

        modulation = modulationTypes{m};

        for d = 1:numDepths

            depth = interleaverDepths(d);

            selectedRows = ...
                strcmp(ProfileTable.Channel, channelType) & ...
                strcmp(ProfileTable.Modulation, modulation) & ...
                ProfileTable.InterleaverDepth == depth;

            currentTable = ProfileTable(selectedRows,:);

            [sortedSNR, order] = ...
                sort(currentTable.EbN0_dB);

            sortedPER = currentTable.PER(order);

            % Plotting floor only; stored PER values remain unchanged.
            plotPER = max(sortedPER, 0.5/numPackets);

            semilogy( ...
                sortedSNR, ...
                plotPER, ...
                '-o', ...
                'LineWidth', 1.2, ...
                'DisplayName', ...
                sprintf('%s - Depth %d', modulation, depth));

        end

    end

    xlabel('E_b/N_0 (dB)');
    ylabel('Packet Error Rate');

    title(upper(channelType));

    legend('Location', 'best');

    ylim([max(0.5/numPackets,1e-4), 1]);

end

sgtitle('Adaptive MCS Profile Calibration');

saveas( ...
    gcf, ...
    fullfile(figuresDir, 'mcs_profile_per_calibration.png'));

%% 13. Calibration completion

fprintf('\n');
fprintf('===============================================\n');
fprintf(' CALIBRATION COMPLETED\n');
fprintf('===============================================\n');

fprintf('CSV file:\n%s\n\n', csvPath);

fprintf('MAT file:\n%s\n\n', matPath);

fprintf('PER target: %.3f\n', targetPER);

fprintf('Number of calibration rows: %d\n', height(ProfileTable));

fprintf('\nAll calibration profiles were processed.\n');


%% =========================================================
%  LOCAL FUNCTIONS
%% =========================================================

function fadingBank = local_generate_fading_bank( ...
    channelType, numBlocks, numPackets, ricianKFactor_dB)

    switch lower(channelType)

        case 'rayleigh'

            fadingBank = ( ...
                randn(numBlocks,numPackets) + ...
                1i*randn(numBlocks,numPackets)) / sqrt(2);

        case 'rician'

            K = 10^(ricianKFactor_dB/10);

            LOSComponent = sqrt(K/(K+1));

            scatteredPower = sqrt(1/(K+1));

            scatteredComponent = ( ...
                randn(numBlocks,numPackets) + ...
                1i*randn(numBlocks,numPackets)) / sqrt(2);

            fadingBank = ...
                LOSComponent + ...
                scatteredPower .* scatteredComponent;

        otherwise

            error('Unsupported channel type: %s', channelType);

    end

end


function [processingCost_ms, ...
          firstColumnReady_ms, ...
          effectiveSpectralEfficiency, ...
          codeRate, ...
          bitsPerSymbol] = ...
          local_measure_profile_cost( ...
              payloadBits, ...
              modulation, ...
              depth, ...
              numFadingBlocks, ...
              symbolRate)

    %% Warm-up

    [txSymbols, txInfo] = adaptive_link_transmitter( ...
        payloadBits, ...
        modulation, ...
        depth, ...
        numFadingBlocks);

    h = ones(size(txSymbols));

    adaptive_link_receiver( ...
        txSymbols, ...
        h, ...
        1e-9, ...
        txInfo);

    %% Benchmark

    repetitions = 15;

    timerStart = tic;

    for k = 1:repetitions

        [txSymbols, txInfo] = adaptive_link_transmitter( ...
            payloadBits, ...
            modulation, ...
            depth, ...
            numFadingBlocks);

        h = ones(size(txSymbols));

        adaptive_link_receiver( ...
            txSymbols, ...
            h, ...
            1e-9, ...
            txInfo);

    end

    elapsedTime = toc(timerStart);

    processingCost_ms = ...
        (elapsedTime / repetitions) * 1000;

    %% Interleaver first-column readiness

    bitsPerSymbol = txInfo.BitsPerSymbol;

    transmissionLength = txInfo.TransmissionBitLength;

    if mod(transmissionLength, depth) ~= 0
        error('Transmission length is not divisible by interleaver depth.');
    end

    columns = transmissionLength / depth;

    firstColumnBits = (depth - 1) * columns + 1;

    % Interleaver input is a coded-bit stream.
    % At fixed symbol rate, coded-bit rate = bps * symbolRate.

    codedBitRate = bitsPerSymbol * symbolRate;

    firstColumnReady_ms = ...
        (firstColumnBits / codedBitRate) * 1000;

    %% Effective spectral efficiency

    effectiveSpectralEfficiency = ...
        numel(payloadBits) / numel(txSymbols);

    %% Nominal FEC code rate

    codeRate = txInfo.NominalConvolutionalRate;

end


function [lowerBound, upperBound] = ...
    local_wilson_interval(errors, trials, confidenceLevel)

    if trials <= 0
        error('Number of trials must be positive.');
    end

    if confidenceLevel ~= 0.95
        error('This implementation currently supports 95%% confidence only.');
    end

    z = 1.959963984540054;

    p = errors / trials;

    denominator = 1 + z^2/trials;

    center = (p + z^2/(2*trials)) / denominator;

    halfWidth = ...
        (z / denominator) * ...
        sqrt(p*(1-p)/trials + z^2/(4*trials^2));

    lowerBound = max(0, center-halfWidth);

    upperBound = min(1, center+halfWidth);

end