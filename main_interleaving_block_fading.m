
clc;
clear;
close all;
rng(2026);

%% Project Setup

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

fprintf('\nMILESTONE 29: INTERLEAVING & BLOCK FADING\n');
fprintf('========================================\n');

%% Simulation Configuration

payloadLength = 1024;
crcLength = 16;
packetLength = payloadLength + crcLength;

numPackets = 1000;
EbN0_dB = 0:2:12;

channelTypes = {'Rayleigh', 'Rician'};
K_dB = 6;

numBlocks = 4;
numSystems = 3;
numChannels = numel(channelTypes);
numSNR = numel(EbN0_dB);

symbolRate = 1e6;

systemNames = [
    "Single Block Fading"
    "4-Block Fading"
    "4-Block Fading + Interleaving"
];

%% Coding Configuration

memoryBits = 2;

codedLength = 2 * (packetLength + memoryBits);

effectiveCodeRate = packetLength / codedLength;

symbolAmplitude = sqrt(effectiveCodeRate);

assert(mod(codedLength, numBlocks) == 0, ...
    'Coded length must be divisible by number of fading blocks.');

blockLength = codedLength / numBlocks;

payloadGrossRate = symbolRate * payloadLength / codedLength;

fprintf('Payload length       : %d bits\n', payloadLength);
fprintf('CRC length           : %d bits\n', crcLength);
fprintf('Packet length        : %d bits\n', packetLength);
fprintf('Coded length         : %d symbols\n', codedLength);
fprintf('Effective code rate  : %.6f\n', effectiveCodeRate);
fprintf('Number of fading blocks: %d\n', numBlocks);
fprintf('Symbols per block    : %d\n', blockLength);
fprintf('Number of packets    : %d\n\n', numPackets);

%% Validate Required Functions

assert(exist('append_crc16', 'file') == 2, ...
    'append_crc16.m not found.');

assert(exist('convolutional_encoder', 'file') == 2, ...
    'convolutional_encoder.m not found.');

assert(exist('block_interleaver', 'file') == 2, ...
    'block_interleaver.m not found.');

assert(exist('block_deinterleaver', 'file') == 2, ...
    'block_deinterleaver.m not found.');

assert(exist('viterbi_decoder_soft_variable_amplitude', 'file') == 2, ...
    'Variable-amplitude Viterbi decoder not found.');

%% Result Arrays

payloadBER = zeros(numSystems, numChannels, numSNR);
channelBER = zeros(numSystems, numChannels, numSNR);

PER = zeros(numSystems, numChannels, numSNR);
CRCFailureRate = zeros(numSystems, numChannels, numSNR);

DetectedPER = zeros(numSystems, numChannels, numSNR);
UndetectedPER = zeros(numSystems, numChannels, numSNR);
CRCOnlyFailureRate = zeros(numSystems, numChannels, numSNR);

CRCAcceptedThroughput = zeros(numSystems, numChannels, numSNR);
CorrectPayloadGoodput = zeros(numSystems, numChannels, numSNR);

AverageChannelPower = zeros(numSystems, numChannels, numSNR);

BER_Lower95 = zeros(numSystems, numChannels, numSNR);
BER_Upper95 = zeros(numSystems, numChannels, numSNR);

PER_Lower95 = zeros(numSystems, numChannels, numSNR);
PER_Upper95 = zeros(numSystems, numChannels, numSNR);

CRC_Lower95 = zeros(numSystems, numChannels, numSNR);
CRC_Upper95 = zeros(numSystems, numChannels, numSNR);

PacketErrors = zeros(numSystems, numChannels, numSNR);
CRCFailures = zeros(numSystems, numChannels, numSNR);

%% Main Simulation

for channelIndex = 1:numChannels

    channelType = channelTypes{channelIndex};

    fprintf('\n========================================\n');
    fprintf('CHANNEL: %s\n', upper(channelType));
    fprintf('========================================\n');

    for snrIndex = 1:numSNR

        currentEbN0 = EbN0_dB(snrIndex);

        gammaB = 10^(currentEbN0 / 10);
        N0 = 1 / gammaB;

        noiseSigma = sqrt(N0 / 2);

        fprintf('\nEb/N0 = %2d dB\n', currentEbN0);

        %% Packet-Level Storage

        packetBER = zeros(numPackets, numSystems);

        packetErrorFlags = false(numPackets, numSystems);
        crcFailureFlags = false(numPackets, numSystems);

        detectedFlags = false(numPackets, numSystems);
        undetectedFlags = false(numPackets, numSystems);
        crcOnlyFlags = false(numPackets, numSystems);

        channelErrorCounts = zeros(1, numSystems);
        channelPowerSums = zeros(1, numSystems);

        %% Packet Loop

        for packetIndex = 1:numPackets

            %% Generate Payload and CRC

            payload = randi([0 1], payloadLength, 1);

            packetBits = append_crc16(payload);
            packetBits = double(packetBits(:));

            if numel(packetBits) ~= packetLength
                error('Unexpected packet length from append_crc16.');
            end

            %% Convolutional Encoding

            codedBits = convolutional_encoder(packetBits);
            codedBits = double(codedBits(:));

            if numel(codedBits) ~= codedLength
                error('Unexpected convolutional encoder output length.');
            end

            %% Generate Four Independent Fading Coefficients

            hBlocks = generate_fading_blocks( ...
                channelType, numBlocks, K_dB);

            %% Generate Common Noise Samples

            noise = noiseSigma .* ...
                (randn(codedLength, 1) + ...
                 1i * randn(codedLength, 1));

            %% Evaluate Three Transmission Systems

            for systemIndex = 1:numSystems

                %% Prepare Transmitted Sequence

                if systemIndex == 3

                    % Interleaved transmission

                    txBits = block_interleaver( ...
                        codedBits, numBlocks);

                    txBits = txBits(:);

                else

                    % Original coded sequence

                    txBits = codedBits;

                end

                %% Assign Channel Coefficients

                if systemIndex == 1

                    % Single block fading

                    hVector = repmat( ...
                        hBlocks(1), codedLength, 1);

                else

                    % Four independent consecutive fading blocks

                    hVector = repelem( ...
                        hBlocks, blockLength, 1);

                end

                %% BPSK Modulation

                txSymbols = symbolAmplitude .* ...
                    (1 - 2 * double(txBits));

                %% Channel Transmission

                rxSymbols = hVector .* txSymbols + noise;

                %% Perfect CSI Equalization

                channelMagnitude = abs(hVector);

                safeMagnitude = channelMagnitude;
                safeMagnitude(safeMagnitude == 0) = eps;

                % Normalize by channel magnitude.
                % This produces constant real-noise variance.

                rxSoft = real(conj(hVector) .* rxSymbols) ...
                    ./ safeMagnitude;

                % Expected amplitude after equalization.

                amplitudeVector = ...
                    symbolAmplitude .* channelMagnitude;

                %% Hard Decisions for Channel BER

                hardBits = double(rxSoft < 0);

                %% Deinterleaving

                if systemIndex == 3

                    rxSoft = block_deinterleaver( ...
                        rxSoft, numBlocks);

                    amplitudeVector = block_deinterleaver( ...
                        amplitudeVector, numBlocks);

                    hardBits = block_deinterleaver( ...
                        hardBits, numBlocks);

                end

                rxSoft = rxSoft(:);
                amplitudeVector = amplitudeVector(:);
                hardBits = hardBits(:);

                %% Soft-Decision Viterbi Decoding

                decodedPacket = ...
                    viterbi_decoder_soft_variable_amplitude( ...
                        rxSoft, amplitudeVector);

                decodedPacket = double(decodedPacket(:));

                if numel(decodedPacket) ~= packetLength
                    error('Unexpected decoded packet length.');
                end

                %% Calculate Payload BER

                decodedPayload = decodedPacket(1:payloadLength);

                bitErrors = nnz(decodedPayload ~= payload);

                packetBER(packetIndex, systemIndex) = ...
                    bitErrors / payloadLength;

                %% Packet Error Detection

                payloadError = (bitErrors > 0);

                packetErrorFlags(packetIndex, systemIndex) = ...
                    payloadError;

                %% CRC Verification

                expectedPacket = append_crc16(decodedPayload);
                expectedPacket = double(expectedPacket(:));

                crcValid = isequal(decodedPacket, expectedPacket);

                crcFailureFlags(packetIndex, systemIndex) = ...
                    ~crcValid;

                %% Detected / Undetected Errors

                detectedFlags(packetIndex, systemIndex) = ...
                    payloadError && ~crcValid;

                undetectedFlags(packetIndex, systemIndex) = ...
                    payloadError && crcValid;

                crcOnlyFlags(packetIndex, systemIndex) = ...
                    ~payloadError && ~crcValid;

                %% Channel BER

                channelErrorCounts(systemIndex) = ...
                    channelErrorCounts(systemIndex) + ...
                    nnz(hardBits ~= codedBits);

                %% Average Channel Power

                channelPowerSums(systemIndex) = ...
                    channelPowerSums(systemIndex) + ...
                    mean(abs(hVector).^2);

            end

        end

        %% Aggregate Performance Metrics

        for systemIndex = 1:numSystems

            packetBERValues = packetBER(:, systemIndex);

            packetErrors = packetErrorFlags(:, systemIndex);
            crcFailures = crcFailureFlags(:, systemIndex);

            detectedErrors = detectedFlags(:, systemIndex);
            undetectedErrors = undetectedFlags(:, systemIndex);
            crcOnlyErrors = crcOnlyFlags(:, systemIndex);

            payloadBER(systemIndex, channelIndex, snrIndex) = ...
                mean(packetBERValues);

            channelBER(systemIndex, channelIndex, snrIndex) = ...
                channelErrorCounts(systemIndex) / ...
                (numPackets * codedLength);

            PER(systemIndex, channelIndex, snrIndex) = ...
                mean(packetErrors);

            CRCFailureRate(systemIndex, channelIndex, snrIndex) = ...
                mean(crcFailures);

            DetectedPER(systemIndex, channelIndex, snrIndex) = ...
                mean(detectedErrors);

            UndetectedPER(systemIndex, channelIndex, snrIndex) = ...
                mean(undetectedErrors);

            CRCOnlyFailureRate(systemIndex, channelIndex, snrIndex) = ...
                mean(crcOnlyErrors);

            PacketErrors(systemIndex, channelIndex, snrIndex) = ...
                sum(packetErrors);

            CRCFailures(systemIndex, channelIndex, snrIndex) = ...
                sum(crcFailures);

            AverageChannelPower(systemIndex, channelIndex, snrIndex) = ...
                channelPowerSums(systemIndex) / numPackets;


            %% Throughput and Goodput

            acceptedPackets = sum(~crcFailures);

            % A packet contributes to correct goodput only if:
            % 1. Its payload is error-free.
            % 2. Its CRC verification is successful.

            correctPackets = sum(~packetErrors & ~crcFailures);

            CRCAcceptedThroughput(systemIndex, channelIndex, snrIndex) = ...
                payloadGrossRate * acceptedPackets / numPackets;

            CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex) = ...
                payloadGrossRate * correctPackets / numPackets;


            %% Confidence Intervals

            [berLow, berHigh] = packet_mean_ci( ...
                packetBERValues, packetErrors);

            [perLow, perHigh] = wilson_ci( ...
                sum(packetErrors), numPackets);

            [crcLow, crcHigh] = wilson_ci( ...
                sum(crcFailures), numPackets);

            BER_Lower95(systemIndex, channelIndex, snrIndex) = berLow;
            BER_Upper95(systemIndex, channelIndex, snrIndex) = berHigh;

            PER_Lower95(systemIndex, channelIndex, snrIndex) = perLow;
            PER_Upper95(systemIndex, channelIndex, snrIndex) = perHigh;

            CRC_Lower95(systemIndex, channelIndex, snrIndex) = crcLow;
            CRC_Upper95(systemIndex, channelIndex, snrIndex) = crcHigh;

            fprintf('%-34s | BER: %.5g | PER: %.4f | Goodput: %.2f\n', ...
                systemNames(systemIndex), ...
                payloadBER(systemIndex, channelIndex, snrIndex), ...
                PER(systemIndex, channelIndex, snrIndex), ...
                CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex));

        end

    end

end

%% Build Result Tables

totalRows = numSystems * numChannels * numSNR;

resultSystem = strings(totalRows, 1);
resultChannel = strings(totalRows, 1);
resultEbN0 = zeros(totalRows, 1);

resultPower = zeros(totalRows, 1);
resultPayloadBER = zeros(totalRows, 1);
resultChannelBER = zeros(totalRows, 1);

resultPER = zeros(totalRows, 1);
resultCRCFailure = zeros(totalRows, 1);

resultDetectedPER = zeros(totalRows, 1);
resultUndetectedPER = zeros(totalRows, 1);
resultCRCOnly = zeros(totalRows, 1);

resultPacketErrors = zeros(totalRows, 1);
resultCRCFailures = zeros(totalRows, 1);

resultCRCAccepted = zeros(totalRows, 1);
resultGoodput = zeros(totalRows, 1);

ciBERLow = zeros(totalRows, 1);
ciBERHigh = zeros(totalRows, 1);

ciPERLow = zeros(totalRows, 1);
ciPERHigh = zeros(totalRows, 1);

ciCRCLow = zeros(totalRows, 1);
ciCRCHigh = zeros(totalRows, 1);

rowIndex = 0;

for channelIndex = 1:numChannels

    for snrIndex = 1:numSNR

        for systemIndex = 1:numSystems

            rowIndex = rowIndex + 1;

            resultSystem(rowIndex) = systemNames(systemIndex);
            resultChannel(rowIndex) = string(channelTypes{channelIndex});

            resultEbN0(rowIndex) = EbN0_dB(snrIndex);

            resultPower(rowIndex) = ...
                AverageChannelPower(systemIndex, channelIndex, snrIndex);

            resultPayloadBER(rowIndex) = ...
                payloadBER(systemIndex, channelIndex, snrIndex);

            resultChannelBER(rowIndex) = ...
                channelBER(systemIndex, channelIndex, snrIndex);

            resultPER(rowIndex) = ...
                PER(systemIndex, channelIndex, snrIndex);

            resultCRCFailure(rowIndex) = ...
                CRCFailureRate(systemIndex, channelIndex, snrIndex);

            resultDetectedPER(rowIndex) = ...
                DetectedPER(systemIndex, channelIndex, snrIndex);

            resultUndetectedPER(rowIndex) = ...
                UndetectedPER(systemIndex, channelIndex, snrIndex);

            resultCRCOnly(rowIndex) = ...
                CRCOnlyFailureRate(systemIndex, channelIndex, snrIndex);

            resultPacketErrors(rowIndex) = ...
                PacketErrors(systemIndex, channelIndex, snrIndex);

            resultCRCFailures(rowIndex) = ...
                CRCFailures(systemIndex, channelIndex, snrIndex);

            resultCRCAccepted(rowIndex) = ...
                CRCAcceptedThroughput(systemIndex, channelIndex, snrIndex);

            resultGoodput(rowIndex) = ...
                CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex);

            ciBERLow(rowIndex) = BER_Lower95(systemIndex, channelIndex, snrIndex);
            ciBERHigh(rowIndex) = BER_Upper95(systemIndex, channelIndex, snrIndex);

            ciPERLow(rowIndex) = PER_Lower95(systemIndex, channelIndex, snrIndex);
            ciPERHigh(rowIndex) = PER_Upper95(systemIndex, channelIndex, snrIndex);

            ciCRCLow(rowIndex) = CRC_Lower95(systemIndex, channelIndex, snrIndex);
            ciCRCHigh(rowIndex) = CRC_Upper95(systemIndex, channelIndex, snrIndex);

        end
    end
end

summaryTable = table( ...
    resultSystem, resultChannel, resultEbN0, resultPower, ...
    resultPayloadBER, resultChannelBER, resultPER, resultCRCFailure, ...
    resultDetectedPER, resultUndetectedPER, resultCRCOnly, ...
    resultPacketErrors, resultCRCFailures, ...
    resultCRCAccepted, resultGoodput, ...
    'VariableNames', { ...
    'System', 'Channel', 'EbN0', 'AverageChannelPower', ...
    'PayloadBER', 'ChannelBER', 'PER', 'CRCFailureRate', ...
    'DetectedPER', 'UndetectedPER', 'CRCOnlyFailureRate', ...
    'PacketErrors', 'CRCFailures', ...
    'CRCAcceptedThroughput', 'CorrectPayloadGoodput'});

confidenceTable = table( ...
    resultSystem, resultChannel, resultEbN0, ...
    ciBERLow, ciBERHigh, ciPERLow, ciPERHigh, ...
    ciCRCLow, ciCRCHigh, ...
    'VariableNames', { ...
    'System', 'Channel', 'EbN0', ...
    'BER_Lower95', 'BER_Upper95', ...
    'PER_Lower95', 'PER_Upper95', ...
    'CRC_Lower95', 'CRC_Upper95'});

%% Display Results

fprintf('\n\nFINAL INTERLEAVING PERFORMANCE SUMMARY\n');
fprintf('======================================\n');

disp(summaryTable);

fprintf('\n95%% CONFIDENCE INTERVAL SUMMARY\n');
fprintf('================================\n');

disp(confidenceTable);

%% Save Results

resultsDir = fullfile(projectRoot, 'results');

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

writetable(summaryTable, ...
    fullfile(resultsDir, 'interleaving_performance_summary.csv'));

writetable(confidenceTable, ...
    fullfile(resultsDir, 'interleaving_confidence_intervals.csv'));

save(fullfile(resultsDir, 'milestone29_interleaving_results.mat'), ...
    'summaryTable', 'confidenceTable', ...
    'payloadBER', 'channelBER', 'PER', 'CRCFailureRate', ...
    'DetectedPER', 'UndetectedPER', 'CRCOnlyFailureRate', ...
    'CRCAcceptedThroughput', 'CorrectPayloadGoodput', ...
    'AverageChannelPower', 'EbN0_dB', 'systemNames', ...
    'channelTypes', 'numPackets', 'K_dB', 'effectiveCodeRate');

%% BER Plot

berFloor = 1 / (numPackets * payloadLength);

figure('Name', 'Interleaving - Payload BER');

for channelIndex = 1:numChannels

    subplot(1, 2, channelIndex);
    hold on;
    grid on;

    for systemIndex = 1:numSystems

        values = squeeze(payloadBER(systemIndex, channelIndex, :)).';
        values = max(values, berFloor);

        semilogy(EbN0_dB, values, '-o', 'LineWidth', 1.5);

    end

    xlabel('E_b/N_0 (dB)');
    ylabel('Payload BER');

    title(channelTypes{channelIndex});

    legend(cellstr(systemNames), 'Location', 'southwest');

end

saveas(gcf, fullfile(resultsDir, 'interleaving_payload_ber.png'));

%% PER Plot

perFloor = 1 / numPackets;

figure('Name', 'Interleaving - Packet Error Rate');

for channelIndex = 1:numChannels

    subplot(1, 2, channelIndex);
    hold on;
    grid on;

    for systemIndex = 1:numSystems

        values = squeeze(PER(systemIndex, channelIndex, :)).';
        values = max(values, perFloor);

        semilogy(EbN0_dB, values, '-o', 'LineWidth', 1.5);

    end

    xlabel('E_b/N_0 (dB)');
    ylabel('PER');

    title(channelTypes{channelIndex});

    legend(cellstr(systemNames), 'Location', 'southwest');

end

saveas(gcf, fullfile(resultsDir, 'interleaving_per.png'));

%% Goodput Plot

figure('Name', 'Interleaving - Correct Payload Goodput');

for channelIndex = 1:numChannels

    subplot(1, 2, channelIndex);
    hold on;
    grid on;

    for systemIndex = 1:numSystems

        values = squeeze( ...
            CorrectPayloadGoodput(systemIndex, channelIndex, :)).';

        plot(EbN0_dB, values, '-o', 'LineWidth', 1.5);

    end

    xlabel('E_b/N_0 (dB)');
    ylabel('Correct Payload Goodput (bit/s)');

    title(channelTypes{channelIndex});

    legend(cellstr(systemNames), 'Location', 'best');

end

saveas(gcf, fullfile(resultsDir, 'interleaving_goodput.png'));


%% Final Validation

% Correct payload goodput must not exceed CRC-accepted throughput.

assert(all(resultGoodput <= resultCRCAccepted + 1e-8), ...
    'Correct Goodput cannot exceed CRC-accepted throughput.');

% PER must equal detected plus undetected packet errors.

assert(all(abs(resultPER - ...
    resultDetectedPER - resultUndetectedPER) < 1e-10), ...
    'PER classification inconsistency detected.');

% CRC failure must equal detected plus CRC-only failures.

assert(all(abs(resultCRCFailure - ...
    resultDetectedPER - resultCRCOnly) < 1e-10), ...
    'CRC failure classification inconsistency detected.');

assert(all(resultPER >= 0 & resultPER <= 1), ...
    'Invalid PER values detected.');

assert(all(resultPayloadBER >= 0 & resultPayloadBER <= 1), ...
    'Invalid payload BER values detected.');

fprintf('\nAll final validation tests passed.\n');
fprintf('Milestone 29 simulation completed successfully.\n');
fprintf('CSV, MAT and figure files saved in results folder.\n');

%% Local Functions

function hBlocks = generate_fading_blocks(channelType, numBlocks, K_dB)

    z = (randn(numBlocks, 1) + ...
         1i * randn(numBlocks, 1)) / sqrt(2);

    switch lower(channelType)

        case 'rayleigh'

            hBlocks = z;

        case 'rician'

            K = 10^(K_dB / 10);

            hLOS = sqrt(K / (K + 1));

            hScatter = sqrt(1 / (K + 1)) .* z;

            hBlocks = hLOS + hScatter;

        otherwise

            error('Unsupported channel type.');

    end
end

function [lowerBound, upperBound] = wilson_ci(errors, total)

    if total <= 0
        error('Total sample count must be positive.');
    end

    z = 1.95996398454005;

    p = errors / total;

    denominator = 1 + z^2 / total;

    center = (p + z^2 / (2 * total)) / denominator;

    radius = z * sqrt( ...
        p * (1 - p) / total + z^2 / (4 * total^2)) ...
        / denominator;

    lowerBound = max(0, center - radius);
    upperBound = min(1, center + radius);

end

function [lowerBound, upperBound] = packet_mean_ci(values, packetErrors)

    values = values(:);
    packetErrors = packetErrors(:);

    n = numel(values);

    mu = mean(values);

    if all(values == 0)

        [~, upperBound] = wilson_ci(sum(packetErrors), n);
        lowerBound = 0;

    else

        sampleStd = std(values, 0);

        if sampleStd > 0

            radius = 1.96 * sampleStd / sqrt(n);

        else

            % Conservative Hoeffding bound for a bounded
            % packet-level BER estimator.

            radius = sqrt(log(2 / 0.05) / (2 * n));

        end

        lowerBound = max(0, mu - radius);
        upperBound = min(1, mu + radius);

    end

end
