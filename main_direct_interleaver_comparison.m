
clc;
clear;
close all;
rng(20261120);

%% PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

fprintf('\nMILESTONE 29.7: DIRECT INTERLEAVER COMPARISON\n');
fprintf('============================================\n');

%% SIMULATION CONFIGURATION

payloadLength = 1024;
crcLength = 16;
packetLength = payloadLength + crcLength;

numPackets = 5000;

% Focus on the SNR region where interleaving differences were observed.
EbN0_dB = [4 6 8 10 12];

channelTypes = {'Rayleigh', 'Rician'};
K_dB = 6;

numFadingBlocks = 4;
interleaverDepths = [4 16];

numSystems = 2;
numChannels = numel(channelTypes);
numSNR = numel(EbN0_dB);

systemNames = ["Depth-4 Interleaving"; "Depth-16 Interleaving"];

symbolRate = 1e6;

%% CODING CONFIGURATION

memoryBits = 2;

codedLength = 2 * (packetLength + memoryBits);

% Add padding so the sequence is divisible by both 4 and 16.
paddingLength = mod(-codedLength, 16);

transmissionLength = codedLength + paddingLength;

fadingBlockLength = transmissionLength / numFadingBlocks;

effectiveCodeRate = packetLength / transmissionLength;

symbolAmplitude = sqrt(effectiveCodeRate);

payloadGrossRate = symbolRate * payloadLength / transmissionLength;

assert(mod(transmissionLength, 4) == 0);
assert(mod(transmissionLength, 16) == 0);

fprintf('Payload length       : %d bits\n', payloadLength);
fprintf('CRC length           : %d bits\n', crcLength);
fprintf('Packet length        : %d bits\n', packetLength);
fprintf('Coded length         : %d bits\n', codedLength);
fprintf('Padding length       : %d bits\n', paddingLength);
fprintf('Transmission length  : %d bits\n', transmissionLength);
fprintf('Fading blocks        : %d\n', numFadingBlocks);
fprintf('Symbols per block    : %d\n', fadingBlockLength);
fprintf('Effective code rate  : %.6f\n', effectiveCodeRate);
fprintf('Packets per point    : %d\n\n', numPackets);

%% REQUIRED FUNCTIONS

requiredFunctions = {
    'append_crc16'
    'convolutional_encoder'
    'block_interleaver'
    'block_deinterleaver'
    'viterbi_decoder_soft_variable_amplitude'
};

for k = 1:numel(requiredFunctions)

    assert(exist(requiredFunctions{k}, 'file') == 2, ...
        'Required function not found: %s', requiredFunctions{k});

end

%% INTERLEAVER VALIDATION

probe = (1:transmissionLength).';

for depth = interleaverDepths

    interleavedProbe = block_interleaver(probe, depth);

    recoveredProbe = block_deinterleaver( ...
        interleavedProbe, depth);

    assert(isequal(probe, recoveredProbe), ...
        'Round-trip test failed for interleaver depth %d.', depth);

end

fprintf('Depth-4 and Depth-16 interleaver tests passed.\n');

%% RESULT ARRAYS

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

% Paired packet-level data.

packetErrorStore = false( ...
    numPackets, numSystems, numChannels, numSNR);

crcFailureStore = false( ...
    numPackets, numSystems, numChannels, numSNR);

correctPacketStore = false( ...
    numPackets, numSystems, numChannels, numSNR);

%% MAIN SIMULATION

for channelIndex = 1:numChannels

    channelType = channelTypes{channelIndex};

    fprintf('\n============================================\n');
    fprintf('CHANNEL: %s\n', upper(channelType));
    fprintf('============================================\n');

    for snrIndex = 1:numSNR

        currentEbN0 = EbN0_dB(snrIndex);

        gammaB = 10^(currentEbN0 / 10);
        N0 = 1 / gammaB;

        noiseSigma = sqrt(N0 / 2);

        fprintf('\nEb/N0 = %d dB\n', currentEbN0);

        %% PACKET-LEVEL STORAGE

        packetBER = zeros(numPackets, numSystems);

        packetErrorFlags = false(numPackets, numSystems);
        crcFailureFlags = false(numPackets, numSystems);
        correctPacketFlags = false(numPackets, numSystems);

        detectedFlags = false(numPackets, numSystems);
        undetectedFlags = false(numPackets, numSystems);
        crcOnlyFlags = false(numPackets, numSystems);

        channelErrorCounts = zeros(1, numSystems);
        channelPowerSums = zeros(1, numSystems);

        %% PACKET LOOP

        for packetIndex = 1:numPackets

            %% 1. Generate common payload and CRC

            payload = randi([0 1], payloadLength, 1);

            packetBits = append_crc16(payload);
            packetBits = double(packetBits(:));

            if numel(packetBits) ~= packetLength
                error('Unexpected packet length.');
            end

            %% 2. Convolutional encoding

            codedBits = convolutional_encoder(packetBits);
            codedBits = double(codedBits(:));

            if numel(codedBits) ~= codedLength
                error('Unexpected convolutional encoder output length.');
            end

            %% 3. Add common padding

            codedPadded = [
                codedBits
                zeros(paddingLength, 1)
            ];

            %% 4. Generate common four-block fading channel

            hBlocks = generate_fading_blocks( ...
                channelType, numFadingBlocks, K_dB);

            hVector = repelem( ...
                hBlocks, fadingBlockLength, 1);

            %% 5. Generate common noise

            noise = noiseSigma .* ...
                (randn(transmissionLength, 1) + ...
                 1i * randn(transmissionLength, 1));

            %% 6. Compare Depth 4 and Depth 16

            for systemIndex = 1:numSystems

                depth = interleaverDepths(systemIndex);

                %% Interleaving

                txBits = block_interleaver(codedPadded, depth);
                txBits = double(txBits(:));

                %% BPSK modulation

                txSymbols = symbolAmplitude .* ...
                    (1 - 2 * txBits);

                %% Four-block fading channel

                rxSymbols = hVector .* txSymbols + noise;

                %% Perfect-CSI equalization

                channelMagnitude = abs(hVector);

                safeMagnitude = channelMagnitude;
                safeMagnitude(safeMagnitude == 0) = eps;

                rxSoft = real(conj(hVector) .* rxSymbols) ...
                    ./ safeMagnitude;

                amplitudeVector = ...
                    symbolAmplitude .* channelMagnitude;

                %% Deinterleaving

                rxSoft = block_deinterleaver(rxSoft, depth);

                amplitudeVector = block_deinterleaver( ...
                    amplitudeVector, depth);

                rxSoft = rxSoft(:);
                amplitudeVector = amplitudeVector(:);

                %% Remove padding

                rxSoft = rxSoft(1:codedLength);
                amplitudeVector = amplitudeVector(1:codedLength);

                %% Channel BER before FEC decoding

                hardCodedBits = double(rxSoft < 0);

                channelErrorCounts(systemIndex) = ...
                    channelErrorCounts(systemIndex) + ...
                    nnz(hardCodedBits ~= codedBits);

                %% Soft Viterbi decoding

                decodedPacket = ...
                    viterbi_decoder_soft_variable_amplitude( ...
                        rxSoft, amplitudeVector);

                decodedPacket = double(decodedPacket(:));

                if numel(decodedPacket) ~= packetLength
                    error('Unexpected decoded packet length.');
                end

                %% Payload BER

                decodedPayload = decodedPacket(1:payloadLength);

                bitErrors = nnz(decodedPayload ~= payload);

                packetBER(packetIndex, systemIndex) = ...
                    bitErrors / payloadLength;

                payloadError = bitErrors > 0;

                packetErrorFlags(packetIndex, systemIndex) = ...
                    payloadError;

                %% CRC verification

                expectedPacket = append_crc16(decodedPayload);
                expectedPacket = double(expectedPacket(:));

                crcValid = isequal(decodedPacket, expectedPacket);

                crcFailureFlags(packetIndex, systemIndex) = ...
                    ~crcValid;

                %% Error classification

                detectedFlags(packetIndex, systemIndex) = ...
                    payloadError && ~crcValid;

                undetectedFlags(packetIndex, systemIndex) = ...
                    payloadError && crcValid;

                crcOnlyFlags(packetIndex, systemIndex) = ...
                    ~payloadError && ~crcValid;

                %% Correct packet

                correctPacketFlags(packetIndex, systemIndex) = ...
                    ~payloadError && crcValid;

                %% Channel power

                channelPowerSums(systemIndex) = ...
                    channelPowerSums(systemIndex) + ...
                    mean(abs(hVector).^2);

            end

        end

        %% AGGREGATE PERFORMANCE METRICS

        for systemIndex = 1:numSystems

            packetBERValues = packetBER(:, systemIndex);

            packetErrors = packetErrorFlags(:, systemIndex);
            crcFailures = crcFailureFlags(:, systemIndex);

            detectedErrors = detectedFlags(:, systemIndex);
            undetectedErrors = undetectedFlags(:, systemIndex);
            crcOnlyErrors = crcOnlyFlags(:, systemIndex);

            correctPackets = correctPacketFlags(:, systemIndex);

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
            correctPacketCount = sum(correctPackets);

            CRCAcceptedThroughput(systemIndex, channelIndex, snrIndex) = ...
                payloadGrossRate * acceptedPackets / numPackets;

            CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex) = ...
                payloadGrossRate * correctPacketCount / numPackets;

            %% Individual confidence intervals

            [BER_Lower95(systemIndex, channelIndex, snrIndex), ...
             BER_Upper95(systemIndex, channelIndex, snrIndex)] = ...
                packet_mean_ci(packetBERValues, packetErrors);

            [PER_Lower95(systemIndex, channelIndex, snrIndex), ...
             PER_Upper95(systemIndex, channelIndex, snrIndex)] = ...
                wilson_ci(sum(packetErrors), numPackets);

            [CRC_Lower95(systemIndex, channelIndex, snrIndex), ...
             CRC_Upper95(systemIndex, channelIndex, snrIndex)] = ...
                wilson_ci(sum(crcFailures), numPackets);

            fprintf('%-24s | BER: %.6g | PER: %.4f | Goodput: %.2f\n', ...
                systemNames(systemIndex), ...
                payloadBER(systemIndex, channelIndex, snrIndex), ...
                PER(systemIndex, channelIndex, snrIndex), ...
                CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex));

        end

        %% Store paired packet outcomes

        packetErrorStore(:, :, channelIndex, snrIndex) = ...
            packetErrorFlags;

        crcFailureStore(:, :, channelIndex, snrIndex) = ...
            crcFailureFlags;

        correctPacketStore(:, :, channelIndex, snrIndex) = ...
            correctPacketFlags;

    end
end

%% BUILD SYSTEM SUMMARY TABLE

totalRows = numSystems * numChannels * numSNR;

resultSystem = strings(totalRows, 1);
resultChannel = strings(totalRows, 1);
resultEbN0 = zeros(totalRows, 1);

resultBER = zeros(totalRows, 1);
resultChannelBER = zeros(totalRows, 1);
resultPER = zeros(totalRows, 1);
resultCRC = zeros(totalRows, 1);

resultDetected = zeros(totalRows, 1);
resultUndetected = zeros(totalRows, 1);
resultCRCOnly = zeros(totalRows, 1);

resultPower = zeros(totalRows, 1);
resultGoodput = zeros(totalRows, 1);
resultAcceptedThroughput = zeros(totalRows, 1);

resultBERLow = zeros(totalRows, 1);
resultBERHigh = zeros(totalRows, 1);
resultPERLow = zeros(totalRows, 1);
resultPERHigh = zeros(totalRows, 1);

rowIndex = 0;

for channelIndex = 1:numChannels

    for snrIndex = 1:numSNR

        for systemIndex = 1:numSystems

            rowIndex = rowIndex + 1;

            resultSystem(rowIndex) = systemNames(systemIndex);
            resultChannel(rowIndex) = string(channelTypes{channelIndex});
            resultEbN0(rowIndex) = EbN0_dB(snrIndex);

            resultBER(rowIndex) = ...
                payloadBER(systemIndex, channelIndex, snrIndex);

            resultChannelBER(rowIndex) = ...
                channelBER(systemIndex, channelIndex, snrIndex);

            resultPER(rowIndex) = ...
                PER(systemIndex, channelIndex, snrIndex);

            resultCRC(rowIndex) = ...
                CRCFailureRate(systemIndex, channelIndex, snrIndex);

            resultDetected(rowIndex) = ...
                DetectedPER(systemIndex, channelIndex, snrIndex);

            resultUndetected(rowIndex) = ...
                UndetectedPER(systemIndex, channelIndex, snrIndex);

            resultCRCOnly(rowIndex) = ...
                CRCOnlyFailureRate(systemIndex, channelIndex, snrIndex);

            resultPower(rowIndex) = ...
                AverageChannelPower(systemIndex, channelIndex, snrIndex);

            resultGoodput(rowIndex) = ...
                CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex);

            resultAcceptedThroughput(rowIndex) = ...
                CRCAcceptedThroughput(systemIndex, channelIndex, snrIndex);

            resultBERLow(rowIndex) = ...
                BER_Lower95(systemIndex, channelIndex, snrIndex);

            resultBERHigh(rowIndex) = ...
                BER_Upper95(systemIndex, channelIndex, snrIndex);

            resultPERLow(rowIndex) = ...
                PER_Lower95(systemIndex, channelIndex, snrIndex);

            resultPERHigh(rowIndex) = ...
                PER_Upper95(systemIndex, channelIndex, snrIndex);

        end
    end
end

summaryTable = table( ...
    resultSystem, resultChannel, resultEbN0, ...
    resultBER, resultBERLow, resultBERHigh, ...
    resultChannelBER, resultPER, resultPERLow, resultPERHigh, ...
    resultCRC, resultDetected, resultUndetected, resultCRCOnly, ...
    resultPower, resultAcceptedThroughput, resultGoodput, ...
    'VariableNames', { ...
    'System', 'Channel', 'EbN0', ...
    'PayloadBER', 'BER_Lower95', 'BER_Upper95', ...
    'ChannelBER', 'PER', 'PER_Lower95', 'PER_Upper95', ...
    'CRCFailureRate', 'DetectedPER', 'UndetectedPER', ...
    'CRCOnlyFailureRate', 'AverageChannelPower', ...
    'CRCAcceptedThroughput', 'CorrectPayloadGoodput'});

%% DIRECT PAIRED COMPARISON: DEPTH 16 VS DEPTH 4

numComparisons = numChannels * numSNR;

pairedChannel = strings(numComparisons, 1);
pairedEbN0 = zeros(numComparisons, 1);

pairedPER4 = zeros(numComparisons, 1);
pairedPER16 = zeros(numComparisons, 1);
pairedPERDelta = zeros(numComparisons, 1);

pairedPERDeltaLow = zeros(numComparisons, 1);
pairedPERDeltaHigh = zeros(numComparisons, 1);

baselineFailCandidateSuccess = zeros(numComparisons, 1);
baselineSuccessCandidateFail = zeros(numComparisons, 1);

mcnemarP = ones(numComparisons, 1);

pairedGoodput4 = zeros(numComparisons, 1);
pairedGoodput16 = zeros(numComparisons, 1);
pairedGoodputDelta = zeros(numComparisons, 1);

pairedGoodputDeltaLow = zeros(numComparisons, 1);
pairedGoodputDeltaHigh = zeros(numComparisons, 1);

comparisonRow = 0;

for channelIndex = 1:numChannels

    for snrIndex = 1:numSNR

        comparisonRow = comparisonRow + 1;

        % System 1 = Depth 4
        % System 2 = Depth 16

        error4 = packetErrorStore(:, 1, channelIndex, snrIndex);
        error16 = packetErrorStore(:, 2, channelIndex, snrIndex);

        correct4 = correctPacketStore(:, 1, channelIndex, snrIndex);
        correct16 = correctPacketStore(:, 2, channelIndex, snrIndex);

        %% Paired McNemar test for PER

        b = sum(error4 & ~error16);
        c = sum(~error4 & error16);

        mcnemarP(comparisonRow) = ...
            mcnemar_exact_pvalue(b, c);

        %% Paired PER difference

        perDifferenceSamples = ...
            double(error16) - double(error4);

        pairedPER4(comparisonRow) = mean(error4);
        pairedPER16(comparisonRow) = mean(error16);

        pairedPERDelta(comparisonRow) = ...
            mean(perDifferenceSamples);

        [pairedPERDeltaLow(comparisonRow), ...
         pairedPERDeltaHigh(comparisonRow)] = ...
            paired_mean_ci(perDifferenceSamples);

        %% Paired correct Goodput difference

        goodputDifferenceSamples = ...
            payloadGrossRate .* ...
            (double(correct16) - double(correct4));

        pairedGoodput4(comparisonRow) = ...
            payloadGrossRate * mean(correct4);

        pairedGoodput16(comparisonRow) = ...
            payloadGrossRate * mean(correct16);

        pairedGoodputDelta(comparisonRow) = ...
            mean(goodputDifferenceSamples);

        [pairedGoodputDeltaLow(comparisonRow), ...
         pairedGoodputDeltaHigh(comparisonRow)] = ...
            paired_mean_ci(goodputDifferenceSamples);

        %% Store labels and discordant pairs

        pairedChannel(comparisonRow) = string(channelTypes{channelIndex});
        pairedEbN0(comparisonRow) = EbN0_dB(snrIndex);

        baselineFailCandidateSuccess(comparisonRow) = b;
        baselineSuccessCandidateFail(comparisonRow) = c;

    end
end

%% HOLM-BONFERRONI CORRECTION

[pSorted, sortIndex] = sort(mcnemarP);

holmSorted = zeros(numComparisons, 1);
runningMaximum = 0;

for k = 1:numComparisons

    adjustedValue = ...
        (numComparisons - k + 1) * pSorted(k);

    runningMaximum = max(runningMaximum, adjustedValue);

    holmSorted(k) = min(1, runningMaximum);

end

holmP = ones(numComparisons, 1);
holmP(sortIndex) = holmSorted;

holmConclusion = strings(numComparisons, 1);

for k = 1:numComparisons

    if holmP(k) < 0.05 && ...
            baselineFailCandidateSuccess(k) > ...
            baselineSuccessCandidateFail(k)

        holmConclusion(k) = "Significant improvement";

    elseif holmP(k) < 0.05

        holmConclusion(k) = "Significant difference, not an improvement";

    else

        holmConclusion(k) = "No significant difference after Holm";

    end
end

%% PAIRED COMPARISON TABLE

pairedTable = table( ...
    pairedChannel, pairedEbN0, ...
    pairedPER4, pairedPER16, pairedPERDelta, ...
    pairedPERDeltaLow, pairedPERDeltaHigh, ...
    baselineFailCandidateSuccess, ...
    baselineSuccessCandidateFail, ...
    mcnemarP, holmP, holmConclusion, ...
    pairedGoodput4, pairedGoodput16, pairedGoodputDelta, ...
    pairedGoodputDeltaLow, pairedGoodputDeltaHigh, ...
    'VariableNames', { ...
    'Channel', 'EbN0', ...
    'PER_Depth4', 'PER_Depth16', 'PER_Delta_16_minus_4', ...
    'PER_Delta_Lower95', 'PER_Delta_Upper95', ...
    'Depth4Fail_Depth16Success', ...
    'Depth4Success_Depth16Fail', ...
    'McNemar_PValue', 'McNemar_HolmPValue', 'HolmConclusion', ...
    'Goodput_Depth4', 'Goodput_Depth16', ...
    'Goodput_Delta_16_minus_4_bps', ...
    'Goodput_Delta_Lower95_bps', ...
    'Goodput_Delta_Upper95_bps'});

%% DISPLAY

fprintf('\n\nDIRECT INTERLEAVER PERFORMANCE SUMMARY\n');
fprintf('=======================================\n');

disp(summaryTable);

fprintf('\nDIRECT PAIRED DEPTH-16 VS DEPTH-4 COMPARISON\n');
fprintf('============================================\n');

disp(pairedTable);

%% SAVE RESULTS

resultsDir = fullfile(projectRoot, 'results');

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

writetable(summaryTable, ...
    fullfile(resultsDir, 'direct_interleaver_summary.csv'));

writetable(pairedTable, ...
    fullfile(resultsDir, 'direct_interleaver_paired_comparison.csv'));

save(fullfile(resultsDir, 'milestone29_direct_depth_comparison.mat'), ...
    'summaryTable', 'pairedTable', ...
    'payloadBER', 'channelBER', 'PER', 'CRCFailureRate', ...
    'DetectedPER', 'UndetectedPER', 'CRCOnlyFailureRate', ...
    'CRCAcceptedThroughput', 'CorrectPayloadGoodput', ...
    'AverageChannelPower', 'packetErrorStore', ...
    'crcFailureStore', 'correctPacketStore', ...
    'EbN0_dB', 'channelTypes', 'interleaverDepths', ...
    'numPackets', 'K_dB', 'effectiveCodeRate');

%% PER PLOT

perFloor = 1 / numPackets;

figure('Name', 'Direct Interleaver PER Comparison');

for channelIndex = 1:numChannels

    subplot(1, 2, channelIndex);
    hold on;
    grid on;

    for systemIndex = 1:numSystems

        values = squeeze(PER(systemIndex, channelIndex, :)).';

        semilogy(EbN0_dB, max(values, perFloor), ...
            '-o', 'LineWidth', 1.5);

    end

    xlabel('E_b/N_0 (dB)');
    ylabel('PER');
    title(channelTypes{channelIndex});

    legend(cellstr(systemNames), 'Location', 'southwest');

end

saveas(gcf, fullfile(resultsDir, 'direct_interleaver_per.png'));

%% GOODPUT PLOT

figure('Name', 'Direct Interleaver Goodput Comparison');

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

saveas(gcf, fullfile(resultsDir, 'direct_interleaver_goodput.png'));

%% FINAL VALIDATION

assert(all(resultGoodput <= resultAcceptedThroughput + 1e-8), ...
    'Correct Goodput cannot exceed CRC-accepted throughput.');

assert(all(resultPER >= 0 & resultPER <= 1), ...
    'Invalid PER values detected.');

assert(all(resultBER >= 0 & resultBER <= 1), ...
    'Invalid BER values detected.');

assert(all(holmP >= 0 & holmP <= 1), ...
    'Invalid Holm-adjusted p-values detected.');

assert(all(pairedGoodputDeltaLow <= pairedGoodputDeltaHigh), ...
    'Invalid Goodput confidence intervals.');

assert(all(pairedPERDeltaLow <= pairedPERDeltaHigh), ...
    'Invalid PER confidence intervals.');

fprintf('\nAll final validation tests passed.\n');
fprintf('Milestone 29.7 completed successfully.\n');
fprintf('Results saved in the results folder.\n');

%% LOCAL FUNCTIONS

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

            radius = sqrt(log(2 / 0.05) / (2 * n));

        end

        lowerBound = max(0, mu - radius);
        upperBound = min(1, mu + radius);

    end
end

function [lowerBound, upperBound] = paired_mean_ci(differences)

    differences = differences(:);

    n = numel(differences);
    mu = mean(differences);

    sampleStd = std(differences, 0);

    if sampleStd > 0

        radius = 1.96 * sampleStd / sqrt(n);

    else

        % Conservative bound for a variable in [-1, 1].

        radius = 2 * sqrt(log(2 / 0.05) / (2 * n));

    end

    lowerBound = mu - radius;
    upperBound = mu + radius;

end

function pValue = mcnemar_exact_pvalue(b, c)

    n = b + c;

    if n == 0

        pValue = 1;
        return;

    end

    k = min(b, c);

    lowerTail = betainc(0.5, n - k, k + 1);

    pValue = min(1, 2 * lowerTail);

end
