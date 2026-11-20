
clc;
clear;
close all;

rng(20261121);

%% PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

fprintf('\nMILESTONE 30.2: ADAPTIVE INTERLEAVING SIMULATION\n');
fprintf('================================================\n');

%% CONFIGURATION

payloadLength = 1024;
crcLength = 16;
packetLength = payloadLength + crcLength;

numPackets = 5000;

EbN0_dB = [4 6 8 10 12];

channelTypes = {'Rayleigh', 'Rician'};
K_dB = 6;

numFadingBlocks = 4;

depths = [4 16];

numSystems = 3;
numChannels = numel(channelTypes);
numSNR = numel(EbN0_dB);

targetPER = 0.20;

symbolRate = 1e6;

systemNames = [
    "Fixed Depth 4"
    "Fixed Depth 16"
    "Adaptive Interleaving"
];

%% CODING CONFIGURATION

memoryBits = 2;

codedLength = 2 * (packetLength + memoryBits);

paddingLength = mod(-codedLength, 16);

transmissionLength = codedLength + paddingLength;

fadingBlockLength = transmissionLength / numFadingBlocks;

effectiveCodeRate = packetLength / transmissionLength;

symbolAmplitude = sqrt(effectiveCodeRate);

payloadGrossRate = symbolRate * ...
    payloadLength / transmissionLength;

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
fprintf('Target PER           : %.3f\n', targetPER);
fprintf('Number of packets    : %d\n\n', numPackets);

%% VERIFY REQUIRED FUNCTIONS

requiredFunctions = {
    'append_crc16'
    'convolutional_encoder'
    'block_interleaver'
    'block_deinterleaver'
    'viterbi_decoder_soft_variable_amplitude'
    'select_interleaver_depth'
};

for k = 1:numel(requiredFunctions)

    assert(exist(requiredFunctions{k}, 'file') == 2, ...
        'Required function not found: %s', requiredFunctions{k});

end

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

PacketErrors = zeros(numSystems, numChannels, numSNR);

%% PACKET-LEVEL STORAGE

packetErrorStore = false( ...
    numPackets, numSystems, numChannels, numSNR);

correctPacketStore = false( ...
    numPackets, numSystems, numChannels, numSNR);

%% CONTROLLER STORAGE

selectedDepthMatrix = zeros(numChannels, numSNR);

targetMetMatrix = false(numChannels, numSNR);

depth4BoundMatrix = zeros(numChannels, numSNR);

depth16BoundMatrix = zeros(numChannels, numSNR);

controllerReason = strings(numChannels, numSNR);

%% MAIN SIMULATION

for channelIndex = 1:numChannels

    channelType = channelTypes{channelIndex};

    fprintf('\n============================================\n');
    fprintf('CHANNEL: %s\n', upper(channelType));
    fprintf('============================================\n');

    for snrIndex = 1:numSNR

        currentEbN0 = EbN0_dB(snrIndex);

        %% ADAPTIVE CONTROLLER

        [adaptiveDepth, decision] = ...
            select_interleaver_depth( ...
                channelType, currentEbN0, targetPER);

        selectedDepthMatrix(channelIndex, snrIndex) = adaptiveDepth;

        targetMetMatrix(channelIndex, snrIndex) = decision.targetMet;

        depth4BoundMatrix(channelIndex, snrIndex) = ...
            decision.depth4Upper95;

        depth16BoundMatrix(channelIndex, snrIndex) = ...
            decision.depth16Upper95;

        controllerReason(channelIndex, snrIndex) = ...
            string(decision.reason);

        fprintf('\nEb/N0 = %d dB\n', currentEbN0);

        fprintf('Adaptive depth = %d\n', adaptiveDepth);

        if decision.targetMet
            fprintf('QoS target: SATISFIED\n');
        else
            fprintf('QoS target: NOT SATISFIED\n');
        end

        gammaB = 10^(currentEbN0 / 10);

        N0 = 1 / gammaB;

        noiseSigma = sqrt(N0 / 2);

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

            %% Generate payload

            payload = randi([0 1], payloadLength, 1);

            %% Append CRC

            packetBits = append_crc16(payload);

            packetBits = double(packetBits(:));

            if numel(packetBits) ~= packetLength
                error('Unexpected packet length.');
            end

            %% Convolutional encoding

            codedBits = convolutional_encoder(packetBits);

            codedBits = double(codedBits(:));

            if numel(codedBits) ~= codedLength
                error('Unexpected coded length.');
            end

            %% Add padding

            codedPadded = [
                codedBits
                zeros(paddingLength, 1)
            ];

            %% Generate common fading blocks

            hBlocks = generate_fading_blocks( ...
                channelType, numFadingBlocks, K_dB);

            hVector = repelem( ...
                hBlocks, fadingBlockLength, 1);

            %% Generate common channel noise

            noise = noiseSigma .* ...
                (randn(transmissionLength, 1) + ...
                 1i * randn(transmissionLength, 1));

            %% Evaluate all systems

            for systemIndex = 1:numSystems

                %% Select interleaver depth

                switch systemIndex

                    case 1
                        selectedDepth = 4;

                    case 2
                        selectedDepth = 16;

                    case 3
                        selectedDepth = adaptiveDepth;

                end

                %% Interleaving

                txBits = block_interleaver( ...
                    codedPadded, selectedDepth);

                txBits = double(txBits(:));

                %% BPSK modulation

                txSymbols = symbolAmplitude .* ...
                    (1 - 2 * txBits);

                %% Four-block fading channel

                rxSymbols = hVector .* txSymbols + noise;

                %% Perfect CSI equalization

                channelMagnitude = abs(hVector);

                safeMagnitude = channelMagnitude;

                safeMagnitude(safeMagnitude == 0) = eps;

                rxSoft = real(conj(hVector) .* rxSymbols) ...
                    ./ safeMagnitude;

                amplitudeVector = ...
                    symbolAmplitude .* channelMagnitude;

                %% Deinterleaving

                rxSoft = block_deinterleaver( ...
                    rxSoft, selectedDepth);

                amplitudeVector = block_deinterleaver( ...
                    amplitudeVector, selectedDepth);

                rxSoft = rxSoft(:);

                amplitudeVector = amplitudeVector(:);

                %% Remove padding

                rxSoft = rxSoft(1:codedLength);

                amplitudeVector = amplitudeVector(1:codedLength);

                %% Channel BER before decoding

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

        %% AGGREGATE METRICS

        for systemIndex = 1:numSystems

            packetErrors = packetErrorFlags(:, systemIndex);

            crcFailures = crcFailureFlags(:, systemIndex);

            correctPackets = correctPacketFlags(:, systemIndex);

            payloadBER(systemIndex, channelIndex, snrIndex) = ...
                mean(packetBER(:, systemIndex));

            channelBER(systemIndex, channelIndex, snrIndex) = ...
                channelErrorCounts(systemIndex) / ...
                (numPackets * codedLength);

            PER(systemIndex, channelIndex, snrIndex) = ...
                mean(packetErrors);

            CRCFailureRate(systemIndex, channelIndex, snrIndex) = ...
                mean(crcFailures);

            DetectedPER(systemIndex, channelIndex, snrIndex) = ...
                mean(detectedFlags(:, systemIndex));

            UndetectedPER(systemIndex, channelIndex, snrIndex) = ...
                mean(undetectedFlags(:, systemIndex));

            CRCOnlyFailureRate(systemIndex, channelIndex, snrIndex) = ...
                mean(crcOnlyFlags(:, systemIndex));

            PacketErrors(systemIndex, channelIndex, snrIndex) = ...
                sum(packetErrors);

            AverageChannelPower(systemIndex, channelIndex, snrIndex) = ...
                channelPowerSums(systemIndex) / numPackets;

            %% Throughput and Goodput

            acceptedPackets = sum(~crcFailures);

            correctPacketCount = sum(correctPackets);

            CRCAcceptedThroughput(systemIndex, channelIndex, snrIndex) = ...
                payloadGrossRate * acceptedPackets / numPackets;

            CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex) = ...
                payloadGrossRate * correctPacketCount / numPackets;

            %% Confidence intervals

            [BER_Lower95(systemIndex, channelIndex, snrIndex), ...
             BER_Upper95(systemIndex, channelIndex, snrIndex)] = ...
                packet_mean_ci( ...
                    packetBER(:, systemIndex), packetErrors);

            [PER_Lower95(systemIndex, channelIndex, snrIndex), ...
             PER_Upper95(systemIndex, channelIndex, snrIndex)] = ...
                wilson_ci(sum(packetErrors), numPackets);

        end

        %% STORE PAIRED RESULTS

        packetErrorStore(:, :, channelIndex, snrIndex) = ...
            packetErrorFlags;

        correctPacketStore(:, :, channelIndex, snrIndex) = ...
            correctPacketFlags;

        %% ADAPTIVE CONSISTENCY CHECK

        if adaptiveDepth == 4

            referenceSystem = 1;

        else

            referenceSystem = 2;

        end

        assert(isequal( ...
            packetErrorFlags(:, 3), ...
            packetErrorFlags(:, referenceSystem)), ...
            'Adaptive PER consistency check failed.');

        assert(isequal( ...
            correctPacketFlags(:, 3), ...
            correctPacketFlags(:, referenceSystem)), ...
            'Adaptive Goodput consistency check failed.');

        fprintf('\n');

        for systemIndex = 1:numSystems

            fprintf('%-25s | BER: %.6g | PER: %.4f | Goodput: %.2f\n', ...
                systemNames(systemIndex), ...
                payloadBER(systemIndex, channelIndex, snrIndex), ...
                PER(systemIndex, channelIndex, snrIndex), ...
                CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex));

        end

    end
end

%% BUILD PERFORMANCE SUMMARY TABLE

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

resultGoodput = zeros(totalRows, 1);
resultAcceptedThroughput = zeros(totalRows, 1);

resultPower = zeros(totalRows, 1);

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

            resultGoodput(rowIndex) = ...
                CorrectPayloadGoodput(systemIndex, channelIndex, snrIndex);

            resultAcceptedThroughput(rowIndex) = ...
                CRCAcceptedThroughput(systemIndex, channelIndex, snrIndex);

            resultPower(rowIndex) = ...
                AverageChannelPower(systemIndex, channelIndex, snrIndex);

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


%% BUILD CONTROLLER DECISION TABLE

controllerRows = numChannels * numSNR;

controllerChannel = strings(controllerRows, 1);
controllerEbN0 = zeros(controllerRows, 1);

controllerDepth = zeros(controllerRows, 1);
controllerTarget = zeros(controllerRows, 1);

controllerMet = false(controllerRows, 1);

controllerDepth4Bound = zeros(controllerRows, 1);
controllerDepth16Bound = zeros(controllerRows, 1);

% Use a separate variable for the table column.
% Do not overwrite the original controllerReason matrix.

controllerReasonColumn = strings(controllerRows, 1);

controllerRow = 0;

for channelIndex = 1:numChannels

    for snrIndex = 1:numSNR

        controllerRow = controllerRow + 1;

        controllerChannel(controllerRow) = ...
            string(channelTypes{channelIndex});

        controllerEbN0(controllerRow) = EbN0_dB(snrIndex);

        controllerDepth(controllerRow) = ...
            selectedDepthMatrix(channelIndex, snrIndex);

        controllerTarget(controllerRow) = targetPER;

        controllerMet(controllerRow) = ...
            targetMetMatrix(channelIndex, snrIndex);

        controllerDepth4Bound(controllerRow) = ...
            depth4BoundMatrix(channelIndex, snrIndex);

        controllerDepth16Bound(controllerRow) = ...
            depth16BoundMatrix(channelIndex, snrIndex);

        controllerReasonColumn(controllerRow) = ...
            controllerReason(channelIndex, snrIndex);

    end
end

controllerTable = table( ...
    controllerChannel, controllerEbN0, ...
    controllerTarget, controllerDepth, controllerMet, ...
    controllerDepth4Bound, controllerDepth16Bound, ...
    controllerReasonColumn, ...
    'VariableNames', { ...
    'Channel', 'EbN0', 'TargetPER', 'SelectedDepth', ...
    'TargetMet', 'Depth4Upper95', 'Depth16Upper95', 'Reason'});

%% MACRO-AVERAGE PERFORMANCE

meanBER = mean(reshape(payloadBER, numSystems, []), 2);

meanPER = mean(reshape(PER, numSystems, []), 2);

meanGoodput = mean(reshape( ...
    CorrectPayloadGoodput, numSystems, []), 2);

macroTable = table( ...
    systemNames, meanBER, meanPER, meanGoodput, ...
    'VariableNames', { ...
    'System', 'MacroAverageBER', 'MacroAveragePER', ...
    'MacroAverageGoodput'});

%% DISPLAY RESULTS

fprintf('\n\nFINAL ADAPTIVE INTERLEAVING PERFORMANCE SUMMARY\n');
fprintf('================================================\n');

disp(summaryTable);

fprintf('\nADAPTIVE CONTROLLER DECISIONS\n');
fprintf('=============================\n');

disp(controllerTable);

fprintf('\nMACRO-AVERAGE PERFORMANCE\n');
fprintf('=========================\n');

disp(macroTable);

%% SAVE RESULTS

resultsDir = fullfile(projectRoot, 'results');

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

writetable(summaryTable, ...
    fullfile(resultsDir, 'adaptive_interleaving_summary.csv'));

writetable(controllerTable, ...
    fullfile(resultsDir, 'adaptive_controller_decisions.csv'));

writetable(macroTable, ...
    fullfile(resultsDir, 'adaptive_macro_performance.csv'));

save(fullfile(resultsDir, 'milestone30_adaptive_results.mat'), ...
    'summaryTable', 'controllerTable', 'macroTable', ...
    'payloadBER', 'channelBER', 'PER', 'CRCFailureRate', ...
    'DetectedPER', 'UndetectedPER', 'CRCOnlyFailureRate', ...
    'CRCAcceptedThroughput', 'CorrectPayloadGoodput', ...
    'AverageChannelPower', 'packetErrorStore', ...
    'correctPacketStore', 'selectedDepthMatrix', ...
    'targetMetMatrix', 'EbN0_dB', 'channelTypes', ...
    'numPackets', 'targetPER', 'K_dB', ...
    'effectiveCodeRate');

%% PER FIGURE

perFloor = 1 / numPackets;

figure('Name', 'Adaptive Interleaving - PER');

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
    ylabel('Packet Error Rate');

    title(channelTypes{channelIndex});

    legend(cellstr(systemNames), 'Location', 'southwest');

end

saveas(gcf, fullfile(resultsDir, 'adaptive_interleaving_per.png'));

%% BER FIGURE

berFloor = 1 / (numPackets * payloadLength);

figure('Name', 'Adaptive Interleaving - BER');

for channelIndex = 1:numChannels

    subplot(1, 2, channelIndex);
    hold on;
    grid on;

    for systemIndex = 1:numSystems

        values = squeeze(payloadBER(systemIndex, channelIndex, :)).';

        semilogy(EbN0_dB, max(values, berFloor), ...
            '-o', 'LineWidth', 1.5);

    end

    xlabel('E_b/N_0 (dB)');
    ylabel('Payload BER');

    title(channelTypes{channelIndex});

    legend(cellstr(systemNames), 'Location', 'southwest');

end

saveas(gcf, fullfile(resultsDir, 'adaptive_interleaving_ber.png'));

%% GOODPUT FIGURE

figure('Name', 'Adaptive Interleaving - Goodput');

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

saveas(gcf, fullfile(resultsDir, 'adaptive_interleaving_goodput.png'));

%% ADAPTIVE DEPTH FIGURE

figure('Name', 'Adaptive Interleaver Selection');

imagesc(EbN0_dB, 1:numChannels, selectedDepthMatrix);

colorbar;

yticks(1:numChannels);
yticklabels(channelTypes);

xlabel('E_b/N_0 (dB)');
ylabel('Channel Type');

title('Selected Interleaver Depth');

saveas(gcf, fullfile(resultsDir, 'adaptive_depth_selection.png'));

%% FINAL VALIDATION

assert(all(resultGoodput <= resultAcceptedThroughput + 1e-8), ...
    'Correct Goodput cannot exceed CRC-accepted throughput.');

assert(all(resultPER >= 0 & resultPER <= 1), ...
    'Invalid PER detected.');

assert(all(resultBER >= 0 & resultBER <= 1), ...
    'Invalid BER detected.');

assert(all(selectedDepthMatrix(:) == 4 | ...
           selectedDepthMatrix(:) == 16), ...
    'Unsupported adaptive depth detected.');

assert(all(controllerDepth == 4 | controllerDepth == 16), ...
    'Invalid controller output.');

% Verify that the adaptive system exactly follows the controller.

for channelIndex = 1:numChannels

    for snrIndex = 1:numSNR

        if selectedDepthMatrix(channelIndex, snrIndex) == 4
            referenceSystem = 1;
        else
            referenceSystem = 2;
        end

        assert( ...
            isequal( ...
                packetErrorStore(:, 3, channelIndex, snrIndex), ...
                packetErrorStore(:, referenceSystem, channelIndex, snrIndex)), ...
            'Adaptive controller consistency failed.');

    end
end

fprintf('\nAll final validation tests passed.\n');
fprintf('Milestone 30.2 completed successfully.\n');
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

            error('Unsupported fading channel.');

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
