
clc;
clear;
close all;
rng(20261120);

%% PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

fprintf('\nMILESTONE 29.6: INTERLEAVING DEPTH COMPARISON\n');
fprintf('============================================\n');

%% SIMULATION CONFIGURATION

payloadLength = 1024;
crcLength = 16;
packetLength = payloadLength + crcLength;

numPackets = 1000;
EbN0_dB = 0:2:12;

channelTypes = {'Rayleigh', 'Rician'};
K_dB = 6;

numFadingBlocks = 4;
interleaverDepths = [4 16];

numSystems = 4;
numChannels = numel(channelTypes);
numSNR = numel(EbN0_dB);

symbolRate = 1e6;

systemNames = [
    "Single Block Fading"
    "4-Block Fading"
    "4-Block + Depth-4 Interleaving"
    "4-Block + Depth-16 Interleaving"
];

%% CODING AND PADDING

memoryBits = 2;

codedLength = 2 * (packetLength + memoryBits);

% Padding is added after convolutional encoding.
paddingLength = mod(-codedLength, 16);

transmissionLength = codedLength + paddingLength;

fadingBlockLength = transmissionLength / numFadingBlocks;

effectiveCodeRate = packetLength / transmissionLength;

symbolAmplitude = sqrt(effectiveCodeRate);

payloadGrossRate = symbolRate * payloadLength / transmissionLength;

fprintf('Payload bits            : %d\n', payloadLength);
fprintf('CRC bits                : %d\n', crcLength);
fprintf('Packet bits             : %d\n', packetLength);
fprintf('Convolutional coded bits: %d\n', codedLength);
fprintf('Padding bits            : %d\n', paddingLength);
fprintf('Transmission length     : %d\n', transmissionLength);
fprintf('Fading blocks           : %d\n', numFadingBlocks);
fprintf('Symbols per fading block: %d\n', fadingBlockLength);
fprintf('Effective code rate     : %.6f\n', effectiveCodeRate);
fprintf('Interleaver depths      : 4 and 16\n');
fprintf('Number of packets       : %d\n\n', numPackets);

assert(mod(transmissionLength, 4) == 0);
assert(mod(transmissionLength, 16) == 0);

%% REQUIRED FUNCTION CHECKS

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

%% INTERLEAVER ROUND-TRIP CHECKS

probe = (1:transmissionLength).';

for depth = interleaverDepths

    temp = block_interleaver(probe, depth);
    recovered = block_deinterleaver(temp, depth);

    assert(isequal(probe, recovered), ...
        'Interleaver round-trip failed for depth %d.', depth);

end

fprintf('Interleaver depth-4 and depth-16 checks passed.\n');

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

% Store packet-level outcomes for paired statistical tests.

packetErrorStore = false( ...
    numPackets, numSystems, numChannels, numSNR);

crcFailureStore = false( ...
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

        detectedFlags = false(numPackets, numSystems);
        undetectedFlags = false(numPackets, numSystems);
        crcOnlyFlags = false(numPackets, numSystems);

        channelErrorCounts = zeros(1, numSystems);
        channelPowerSums = zeros(1, numSystems);

        %% PACKET LOOP

        for packetIndex = 1:numPackets

            %% Generate payload and CRC

            payload = randi([0 1], payloadLength, 1);

            packetBits = append_crc16(payload);
            packetBits = double(packetBits(:));

            if numel(packetBits) ~= packetLength
                error('Unexpected packet length.');
            end

            %% Convolutional encoding

            codedBits = convolutional_encoder(packetBits);
            codedBits = double(codedBits(:));

            if numel(codedBits) ~= codedLength
                error('Unexpected convolutional encoder output length.');
            end

            %% Add padding after encoding

            codedPadded = [
                codedBits
                zeros(paddingLength, 1)
            ];

            if numel(codedPadded) ~= transmissionLength
                error('Incorrect padded sequence length.');
            end

            %% Generate four independent fading coefficients

            hBlocks = generate_fading_blocks( ...
                channelType, numFadingBlocks, K_dB);

            %% Generate common complex AWGN

            noise = noiseSigma .* ...
                (randn(transmissionLength, 1) + ...
                 1i * randn(transmissionLength, 1));

            %% Evaluate all four systems

            for systemIndex = 1:numSystems

                %% 1. Prepare transmitted sequence

                switch systemIndex

                    case {1, 2}

                        txBits = codedPadded;

                    case 3

                        txBits = block_interleaver( ...
                            codedPadded, interleaverDepths(1));

                        txBits = txBits(:);

                    case 4

                        txBits = block_interleaver( ...
                            codedPadded, interleaverDepths(2));

                        txBits = txBits(:);

                end

                %% 2. Assign fading coefficients

                if systemIndex == 1

                    % One fading coefficient for the entire packet.

                    hVector = repmat( ...
                        hBlocks(1), transmissionLength, 1);

                else

                    % Four independent consecutive fading blocks.

                    hVector = repelem( ...
                        hBlocks, fadingBlockLength, 1);

                end

                %% 3. BPSK modulation

                txSymbols = symbolAmplitude .* ...
                    (1 - 2 * double(txBits));

                %% 4. Channel

                rxSymbols = hVector .* txSymbols + noise;

                %% 5. Perfect-CSI equalization

                channelMagnitude = abs(hVector);

                safeMagnitude = channelMagnitude;
                safeMagnitude(safeMagnitude == 0) = eps;

                % Equalized real-valued soft samples.
                % Their noise variance is N0/2.

                rxSoft = real(conj(hVector) .* rxSymbols) ...
                    ./ safeMagnitude;

                % Expected sample amplitude for each coded bit.

                amplitudeVector = ...
                    symbolAmplitude .* channelMagnitude;

                %% 6. Deinterleave when required

                if systemIndex == 3

                    rxSoft = block_deinterleaver( ...
                        rxSoft, interleaverDepths(1));

                    amplitudeVector = block_deinterleaver( ...
                        amplitudeVector, interleaverDepths(1));

                elseif systemIndex == 4

                    rxSoft = block_deinterleaver( ...
                        rxSoft, interleaverDepths(2));

                    amplitudeVector = block_deinterleaver( ...
                        amplitudeVector, interleaverDepths(2));

                end

                rxSoft = rxSoft(:);
                amplitudeVector = amplitudeVector(:);

                %% 7. Remove padding before decoding

                rxSoft = rxSoft(1:codedLength);
                amplitudeVector = amplitudeVector(1:codedLength);

                %% 8. Channel BER before FEC decoding

                hardCodedBits = double(rxSoft < 0);

                channelErrorCounts(systemIndex) = ...
                    channelErrorCounts(systemIndex) + ...
                    nnz(hardCodedBits ~= codedBits);

                %% 9. Soft Viterbi decoding

                decodedPacket = ...
                    viterbi_decoder_soft_variable_amplitude( ...
                        rxSoft, amplitudeVector);

                decodedPacket = double(decodedPacket(:));

                if numel(decodedPacket) ~= packetLength
                    error('Unexpected decoded packet length.');
                end

                %% 10. Payload BER

                decodedPayload = decodedPacket(1:payloadLength);

                bitErrors = nnz(decodedPayload ~= payload);

                packetBER(packetIndex, systemIndex) = ...
                    bitErrors / payloadLength;

                payloadError = bitErrors > 0;

                packetErrorFlags(packetIndex, systemIndex) = ...
                    payloadError;

                %% 11. CRC verification

                expectedPacket = append_crc16(decodedPayload);
                expectedPacket = double(expectedPacket(:));

                crcValid = isequal(decodedPacket, expectedPacket);

                crcFailureFlags(packetIndex, systemIndex) = ...
                    ~crcValid;

                %% 12. Error classification

                detectedFlags(packetIndex, systemIndex) = ...
                    payloadError && ~crcValid;

                undetectedFlags(packetIndex, systemIndex) = ...
                    payloadError && crcValid;

                crcOnlyFlags(packetIndex, systemIndex) = ...
                    ~payloadError && ~crcValid;

                %% 13. Average channel power

                channelPowerSums(systemIndex) = ...
                    channelPowerSums(systemIndex) + ...
                    mean(abs(hVector).^2);

            end

        end

        %% AGGREGATE METRICS

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

            %% Throughput and correct goodput

            acceptedPackets = sum(~crcFailures);

            correctPackets = sum(~packetErrors & ~crcFailures);

            CRCAcceptedThroughput(systemIndex, channelIndex, snrIndex) = ...
                payloadGrossRate * acceptedPackets / numPackets;

            CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex) = ...
                payloadGrossRate * correctPackets / numPackets;

            %% Confidence intervals

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

            fprintf('%-38s | BER: %.5g | PER: %.4f | Goodput: %.2f\n', ...
                systemNames(systemIndex), ...
                payloadBER(systemIndex, channelIndex, snrIndex), ...
                PER(systemIndex, channelIndex, snrIndex), ...
                CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex));

        end

        %% Save paired packet outcomes

        packetErrorStore(:, :, channelIndex, snrIndex) = ...
            packetErrorFlags;

        crcFailureStore(:, :, channelIndex, snrIndex) = ...
            crcFailureFlags;

    end
end

%% BUILD SUMMARY TABLE

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

%% PAIRED MCNEMAR TESTS

% System 2: four-block fading without interleaving.
% Systems 3 and 4 are compared against this baseline.

pairedSystem = strings(2 * numChannels * numSNR, 1);
pairedChannel = strings(2 * numChannels * numSNR, 1);
pairedEbN0 = zeros(2 * numChannels * numSNR, 1);

pairedPERDelta = zeros(2 * numChannels * numSNR, 1);

baselineFailCandidateSuccess = zeros(2 * numChannels * numSNR, 1);
baselineSuccessCandidateFail = zeros(2 * numChannels * numSNR, 1);

pairedPValue = ones(2 * numChannels * numSNR, 1);
pairedConclusion = strings(2 * numChannels * numSNR, 1);

pairedRow = 0;

for channelIndex = 1:numChannels

    for snrIndex = 1:numSNR

        baselineErrors = packetErrorStore(:, 2, channelIndex, snrIndex);

        for candidateIndex = 3:4

            candidateErrors = packetErrorStore( ...
                :, candidateIndex, channelIndex, snrIndex);

            pairedRow = pairedRow + 1;

            b = sum(baselineErrors & ~candidateErrors);
            c = sum(~baselineErrors & candidateErrors);

            pValue = mcnemar_exact_pvalue(b, c);

            deltaPER = ...
                PER(candidateIndex, channelIndex, snrIndex) - ...
                PER(2, channelIndex, snrIndex);

            pairedSystem(pairedRow) = systemNames(candidateIndex);
            pairedChannel(pairedRow) = string(channelTypes{channelIndex});
            pairedEbN0(pairedRow) = EbN0_dB(snrIndex);

            pairedPERDelta(pairedRow) = deltaPER;

            baselineFailCandidateSuccess(pairedRow) = b;
            baselineSuccessCandidateFail(pairedRow) = c;

            pairedPValue(pairedRow) = pValue;

            if pValue < 0.05 && b > c

                pairedConclusion(pairedRow) = ...
                    "Significant PER improvement";

            elseif pValue < 0.05 && c > b

                pairedConclusion(pairedRow) = ...
                    "Significant PER degradation";

            else

                pairedConclusion(pairedRow) = ...
                    "No significant paired difference";

            end

        end
    end
end

pairedTable = table( ...
    pairedSystem, pairedChannel, pairedEbN0, ...
    pairedPERDelta, ...
    baselineFailCandidateSuccess, ...
    baselineSuccessCandidateFail, ...
    pairedPValue, pairedConclusion, ...
    'VariableNames', { ...
    'CandidateSystem', 'Channel', 'EbN0', ...
    'PER_Difference_vs_4Block', ...
    'BaselineFail_CandidateSuccess', ...
    'BaselineSuccess_CandidateFail', ...
    'McNemar_PValue', 'Conclusion'});

%% HOLM-BONFERRONI MULTIPLE-TEST CORRECTION

pRaw = pairedTable.McNemar_PValue;

numTests = numel(pRaw);

[pSorted, sortIndex] = sort(pRaw);

adjustedSorted = zeros(numTests, 1);

runningMaximum = 0;

for k = 1:numTests

    adjustedValue = ...
        (numTests - k + 1) * pSorted(k);

    runningMaximum = max(runningMaximum, adjustedValue);

    adjustedSorted(k) = min(1, runningMaximum);

end

pHolm = ones(numTests, 1);

pHolm(sortIndex) = adjustedSorted;

pairedTable.McNemar_HolmPValue = pHolm;

pairedTable.HolmConclusion = repmat( ...
    "No significant difference after Holm correction", ...
    numTests, 1);

significant = pHolm < 0.05;

pairedTable.HolmConclusion(significant) = ...
    "Significant after Holm correction";

fprintf('\nHOLM-BONFERRONI CORRECTED MCNEMAR RESULTS\n');
fprintf('=========================================\n');

disp(pairedTable);


%% DISPLAY RESULTS

fprintf('\n\nFINAL INTERLEAVING DEPTH PERFORMANCE SUMMARY\n');
fprintf('=============================================\n');

disp(summaryTable);

fprintf('\n95%% CONFIDENCE INTERVAL SUMMARY\n');
fprintf('================================\n');

disp(confidenceTable);

fprintf('\nPAIRED MCNEMAR TEST SUMMARY\n');
fprintf('==========================\n');

disp(pairedTable);

%% SAVE RESULTS

resultsDir = fullfile(projectRoot, 'results');

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

writetable(summaryTable, ...
    fullfile(resultsDir, 'interleaving_depth_summary.csv'));

writetable(confidenceTable, ...
    fullfile(resultsDir, 'interleaving_depth_confidence_intervals.csv'));

writetable(pairedTable, ...
    fullfile(resultsDir, 'interleaving_depth_mcnemar_tests.csv'));

save(fullfile(resultsDir, 'milestone29_depth_comparison.mat'), ...
    'summaryTable', 'confidenceTable', 'pairedTable', ...
    'payloadBER', 'channelBER', 'PER', 'CRCFailureRate', ...
    'DetectedPER', 'UndetectedPER', 'CRCOnlyFailureRate', ...
    'CRCAcceptedThroughput', 'CorrectPayloadGoodput', ...
    'AverageChannelPower', 'packetErrorStore', 'crcFailureStore', ...
    'EbN0_dB', 'systemNames', 'channelTypes', ...
    'numPackets', 'K_dB', 'interleaverDepths', ...
    'codedLength', 'paddingLength', 'transmissionLength', ...
    'effectiveCodeRate');

%% PAYLOAD BER FIGURE

berFloor = 1 / (numPackets * payloadLength);

figure('Name', 'Interleaving Depth - Payload BER');

for channelIndex = 1:numChannels

    subplot(1, 2, channelIndex);
    hold on;
    grid on;

    for systemIndex = 1:numSystems

        values = squeeze( ...
            payloadBER(systemIndex, channelIndex, :)).';

        values = max(values, berFloor);

        semilogy(EbN0_dB, values, '-o', 'LineWidth', 1.5);

    end

    xlabel('E_b/N_0 (dB)');
    ylabel('Payload BER');
    title(channelTypes{channelIndex});

    legend(cellstr(systemNames), 'Location', 'southwest');

end

saveas(gcf, fullfile(resultsDir, 'interleaving_depth_payload_ber.png'));

%% PACKET ERROR RATE FIGURE

perFloor = 1 / numPackets;

figure('Name', 'Interleaving Depth - PER');

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
    ylabel('Packet Error Rate');
    title(channelTypes{channelIndex});

    legend(cellstr(systemNames), 'Location', 'southwest');

end

saveas(gcf, fullfile(resultsDir, 'interleaving_depth_per.png'));

%% CORRECT GOODPUT FIGURE

figure('Name', 'Interleaving Depth - Correct Goodput');

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

saveas(gcf, fullfile(resultsDir, 'interleaving_depth_goodput.png'));

%% FINAL VALIDATION

assert(all(resultGoodput <= resultCRCAccepted + 1e-8), ...
    'Correct Goodput cannot exceed CRC-accepted throughput.');

assert(all(abs(resultPER - ...
    resultDetectedPER - resultUndetectedPER) < 1e-10), ...
    'PER classification inconsistency detected.');

assert(all(abs(resultCRCFailure - ...
    resultDetectedPER - resultCRCOnly) < 1e-10), ...
    'CRC failure classification inconsistency detected.');

assert(all(resultPER >= 0 & resultPER <= 1), ...
    'Invalid PER values detected.');

assert(all(resultPayloadBER >= 0 & resultPayloadBER <= 1), ...
    'Invalid payload BER values detected.');

assert(all(pairedPValue >= 0 & pairedPValue <= 1), ...
    'Invalid McNemar p-values detected.');

fprintf('\nAll final validation tests passed.\n');
fprintf('Milestone 29.6 completed successfully.\n');
fprintf('All CSV, MAT and figure files saved in results folder.\n');

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

            radius = sqrt(log(2 / 0.05) / (2 * n));

        end

        lowerBound = max(0, mu - radius);
        upperBound = min(1, mu + radius);

    end

end

function pValue = mcnemar_exact_pvalue(b, c)

    % Exact two-sided McNemar test using the binomial distribution.
    % b: baseline failed, candidate succeeded.
    % c: baseline succeeded, candidate failed.

    n = b + c;

    if n == 0
        pValue = 1;
        return;
    end

    k = min(b, c);

    lowerTail = betainc(0.5, n - k, k + 1);

    pValue = min(1, 2 * lowerTail);

end
