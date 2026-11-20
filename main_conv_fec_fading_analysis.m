
clc;
clear;
close all;

%% =========================================================
% MILESTONE 28
% FEC PERFORMANCE OVER RAYLEIGH AND RICIAN FADING
%
% Systems:
% 1. Uncoded BPSK + CRC-16
% 2. Convolutional (7,5) + Hard Viterbi + CRC-16
% 3. Convolutional (7,5) + Soft Viterbi + CRC-16
%
% Channel Models:
% 1. Rayleigh block fading
% 2. Rician block fading
%
% Assumptions:
% - One flat-fading coefficient per packet
% - Independent fading between packets
% - Perfect CSI at receiver
% - Coherent detection
% - Complex AWGN
%
% Metrics:
% - Payload BER
% - Channel BER
% - PER
% - CRC Failure Rate
% - Detected / Undetected Errors
% - CRC-only Failures
% - Correct Payload Goodput
% - 95% Confidence Intervals
%
%% =========================================================

%% 1. PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

rng(2026,'twister');

%% 2. SIMULATION CONFIGURATION

payloadLength = 1024;
crcLength = 16;
packetLength = payloadLength + crcLength;

numPackets = 1000;

EbN0_dB = 0:2:12;
numSNR = numel(EbN0_dB);

symbolRate = 1e6;

channelTypes = {'Rayleigh','Rician'};
numChannels = numel(channelTypes);

ricianK_dB = 6;

%% 3. CONVOLUTIONAL CODE CONFIGURATION

tailBits = 2;

codedBitsPerPacket = 2*(packetLength+tailBits);

effectiveCodeRate = packetLength/codedBitsPerPacket;

symbolAmplitude = sqrt(effectiveCodeRate);

numSystems = 3;

systemNames = { ...
    'Uncoded BPSK + CRC', ...
    'Hard Viterbi + CRC', ...
    'Soft Viterbi + CRC'};

fprintf('\n============================================\n');
fprintf('FEC PERFORMANCE OVER FADING CHANNELS\n');
fprintf('============================================\n');

fprintf('Payload length: %d bits\n',payloadLength);
fprintf('CRC length: %d bits\n',crcLength);
fprintf('Packet length: %d bits\n',packetLength);

fprintf('Number of packets: %d\n',numPackets);

fprintf('Convolutional code: (7,5)\n');
fprintf('Nominal code rate: 0.5\n');
fprintf('Effective code rate: %.8f\n',effectiveCodeRate);

fprintf('Coded bits per packet: %d\n',codedBitsPerPacket);

fprintf('Modulation: BPSK\n');

fprintf('Rician K-factor: %.2f dB\n',ricianK_dB);

fprintf('Perfect CSI: Enabled\n');

fprintf('Eb/N0 range: %d to %d dB\n', ...
    EbN0_dB(1),EbN0_dB(end));

%% 4. RESULT STORAGE

numRows = numChannels*numSNR*numSystems;

System = strings(numRows,1);
Channel = strings(numRows,1);

EbN0 = zeros(numRows,1);

AverageChannelPower = zeros(numRows,1);

PayloadBER = zeros(numRows,1);
ChannelBER = zeros(numRows,1);

PER = zeros(numRows,1);
CRCFailureRate = zeros(numRows,1);

DetectedPER = zeros(numRows,1);
UndetectedPER = zeros(numRows,1);
CRCOnlyFailureRate = zeros(numRows,1);

PacketErrors = zeros(numRows,1);
CRCFailures = zeros(numRows,1);

DetectedErrors = zeros(numRows,1);
UndetectedErrors = zeros(numRows,1);
CRCOnlyFailures = zeros(numRows,1);

CRCAcceptedThroughput = zeros(numRows,1);
CorrectPayloadGoodput = zeros(numRows,1);

%% 5. CONFIDENCE INTERVAL STORAGE

BER_Lower95 = zeros(numRows,1);
BER_Upper95 = zeros(numRows,1);

PER_Lower95 = zeros(numRows,1);
PER_Upper95 = zeros(numRows,1);

CRC_Lower95 = zeros(numRows,1);
CRC_Upper95 = zeros(numRows,1);

%% 6. SIMULATION PARAMETERS

uncodedGrossPayloadRate = ...
    symbolRate*(payloadLength/packetLength);

codedGrossPayloadRate = ...
    symbolRate*effectiveCodeRate*(payloadLength/packetLength);

confidenceZ = 1.95996398454005;

rowIndex = 0;

%% =========================================================
% 7. MAIN SIMULATION
%% =========================================================

for channelIndex = 1:numChannels

    channelType = channelTypes{channelIndex};

    fprintf('\n\n');
    fprintf('============================================\n');
    fprintf('CHANNEL: %s\n',upper(channelType));
    fprintf('============================================\n');

    for snrIndex = 1:numSNR

        currentEbN0 = EbN0_dB(snrIndex);

        gamma = 10^(currentEbN0/10);

        % AWGN noise spectral density:
        % Information-bit energy is normalized to 1.

        N0 = 1/gamma;

        noiseSigma = sqrt(N0/2);

        fprintf('\n--------------------------------------------\n');
        fprintf('Eb/N0 = %.1f dB\n',currentEbN0);
        fprintf('--------------------------------------------\n');

        %% A. INITIALIZE COUNTERS

        payloadBitErrors = zeros(numSystems,1);

        channelBitErrors = zeros(numSystems,1);

        packetErrorCounts = zeros(numSystems,1);

        crcFailureCounts = zeros(numSystems,1);

        detectedCounts = zeros(numSystems,1);

        undetectedCounts = zeros(numSystems,1);

        crcOnlyCounts = zeros(numSystems,1);

        packetBERSamples = zeros(numPackets,numSystems);

        channelPowerSum = 0;

        %% =================================================
        % B. PACKET TRANSMISSION LOOP
        %% =================================================

        for packetIndex = 1:numPackets

            %% 1. GENERATE INFORMATION PAYLOAD

            payloadBits = generate_bits(payloadLength);

            %% 2. APPEND CRC

            txPacket = append_crc16(payloadBits);

            %% 3. GENERATE BLOCK FADING COEFFICIENT

            % Same channel coefficient is used for all three
            % systems within the current packet.

            h = generate_packet_fading( ...
                channelType,ricianK_dB);

            channelPowerSum = channelPowerSum + abs(h)^2;

            channelPower = abs(h)^2;

            %% =================================================
            % SYSTEM 1: UNCODED BPSK + CRC
            %% =================================================

            %% Transmitter

            uncodedTxSymbols = bpsk_modulator(txPacket);

            %% Channel

            uncodedNoise = noiseSigma*( ...
                randn(1,packetLength) + ...
                1i*randn(1,packetLength));

            uncodedRxSymbols = ...
                h*uncodedTxSymbols + uncodedNoise;

            %% Coherent matched-filter statistic

            uncodedStatistic = real( ...
                conj(h).*uncodedRxSymbols);

            %% Hard Demodulation

            uncodedRxPacket = ...
                bpsk_demodulator(uncodedStatistic);

            %% Channel Errors

            uncodedChannelErrors = ...
                nnz(txPacket ~= uncodedRxPacket);

            channelBitErrors(1) = ...
                channelBitErrors(1) + uncodedChannelErrors;

            %% CRC Verification

            [uncodedRxPayload,uncodedCRCOK] = ...
                verify_crc16(uncodedRxPacket);

            %% Payload Errors

            uncodedErrors = ...
                nnz(payloadBits ~= uncodedRxPayload);

            payloadBitErrors(1) = ...
                payloadBitErrors(1) + uncodedErrors;

            packetBERSamples(packetIndex,1) = ...
                uncodedErrors/payloadLength;

            uncodedPacketError = (uncodedErrors > 0);

            %% Packet Classification

            if uncodedPacketError

                packetErrorCounts(1) = ...
                    packetErrorCounts(1)+1;

            end

            if ~uncodedCRCOK

                crcFailureCounts(1) = ...
                    crcFailureCounts(1)+1;

            end

            if uncodedPacketError && ~uncodedCRCOK

                detectedCounts(1) = detectedCounts(1)+1;

            elseif uncodedPacketError && uncodedCRCOK

                undetectedCounts(1) = undetectedCounts(1)+1;

            elseif ~uncodedPacketError && ~uncodedCRCOK

                crcOnlyCounts(1) = crcOnlyCounts(1)+1;

            end

            %% =================================================
            % CONVOLUTIONAL TRANSMITTER
            %% =================================================

            %% 1. ENCODING

            txCodedBits = convolutional_encoder(txPacket);

            if numel(txCodedBits) ~= codedBitsPerPacket

                error('Unexpected convolutional output length.');

            end

            %% 2. BPSK MODULATION

            codedTxSymbols = ...
                symbolAmplitude* ...
                bpsk_modulator(txCodedBits);

            %% 3. FADING + AWGN

            codedNoise = noiseSigma*( ...
                randn(1,codedBitsPerPacket) + ...
                1i*randn(1,codedBitsPerPacket));

            codedRxSymbols = ...
                h*codedTxSymbols + codedNoise;

            %% 4. COHERENT MATCHED-FILTER STATISTIC

            % z = real(conj(h)*y)
            %
            % Expected received amplitude:
            % A_effective = A*|h|^2
            %
            % Since h is constant during the packet,
            % the effective noise variance is also constant
            % across all trellis sections.

            codedStatistic = real( ...
                conj(h).*codedRxSymbols);

            effectiveSoftAmplitude = ...
                symbolAmplitude*channelPower;

            %% 5. CHANNEL HARD DECISIONS

            codedRxHardBits = ...
                bpsk_demodulator(codedStatistic);

            codedChannelErrors = ...
                nnz(txCodedBits ~= codedRxHardBits);

            channelBitErrors(2) = ...
                channelBitErrors(2)+codedChannelErrors;

            channelBitErrors(3) = ...
                channelBitErrors(3)+codedChannelErrors;

            %% =================================================
            % SYSTEM 2: HARD VITERBI
            %% =================================================

            [hardDecodedPacket,~] = ...
                viterbi_decoder_hard(codedRxHardBits);

            hardDecodedPacket = hardDecodedPacket(:).';

            %% CRC Verification

            [hardRxPayload,hardCRCOK] = ...
                verify_crc16(hardDecodedPacket);

            %% Payload Errors

            hardErrors = ...
                nnz(payloadBits ~= hardRxPayload);

            payloadBitErrors(2) = ...
                payloadBitErrors(2)+hardErrors;

            packetBERSamples(packetIndex,2) = ...
                hardErrors/payloadLength;

            hardPacketError = (hardErrors > 0);

            %% Packet Classification

            if hardPacketError

                packetErrorCounts(2) = ...
                    packetErrorCounts(2)+1;

            end

            if ~hardCRCOK

                crcFailureCounts(2) = ...
                    crcFailureCounts(2)+1;

            end

            if hardPacketError && ~hardCRCOK

                detectedCounts(2) = detectedCounts(2)+1;

            elseif hardPacketError && hardCRCOK

                undetectedCounts(2) = undetectedCounts(2)+1;

            elseif ~hardPacketError && ~hardCRCOK

                crcOnlyCounts(2) = crcOnlyCounts(2)+1;

            end

            %% =================================================
            % SYSTEM 3: SOFT VITERBI
            %% =================================================

            % The original matched-filter samples are supplied.
            % No hard-decision operation is performed here.

            [softDecodedPacket,~] = ...
                viterbi_decoder_soft( ...
                    codedStatistic,effectiveSoftAmplitude);

            softDecodedPacket = softDecodedPacket(:).';

            %% CRC Verification

            [softRxPayload,softCRCOK] = ...
                verify_crc16(softDecodedPacket);

            %% Payload Errors

            softErrors = ...
                nnz(payloadBits ~= softRxPayload);

            payloadBitErrors(3) = ...
                payloadBitErrors(3)+softErrors;

            packetBERSamples(packetIndex,3) = ...
                softErrors/payloadLength;

            softPacketError = (softErrors > 0);

            %% Packet Classification

            if softPacketError

                packetErrorCounts(3) = ...
                    packetErrorCounts(3)+1;

            end

            if ~softCRCOK

                crcFailureCounts(3) = ...
                    crcFailureCounts(3)+1;

            end

            if softPacketError && ~softCRCOK

                detectedCounts(3) = detectedCounts(3)+1;

            elseif softPacketError && softCRCOK

                undetectedCounts(3) = undetectedCounts(3)+1;

            elseif ~softPacketError && ~softCRCOK

                crcOnlyCounts(3) = crcOnlyCounts(3)+1;

            end

        end

        %% =================================================
        % C. CALCULATE PERFORMANCE METRICS
        %% =================================================

        totalPayloadBits = numPackets*payloadLength;

        totalUncodedBits = numPackets*packetLength;

        totalCodedBits = numPackets*codedBitsPerPacket;

        totalTransmittedBits = [ ...
            totalUncodedBits; ...
            totalCodedBits; ...
            totalCodedBits];

        grossPayloadRates = [ ...
            uncodedGrossPayloadRate; ...
            codedGrossPayloadRate; ...
            codedGrossPayloadRate];

        %% Average Channel Power

        averageChannelPower = channelPowerSum/numPackets;

        %% System Metrics

        for systemIndex = 1:numSystems

            %% BER

            currentBER = ...
                payloadBitErrors(systemIndex)/totalPayloadBits;

            currentChannelBER = ...
                channelBitErrors(systemIndex)/ ...
                totalTransmittedBits(systemIndex);

            %% PER

            currentPER = ...
                packetErrorCounts(systemIndex)/numPackets;

            currentCRCFailure = ...
                crcFailureCounts(systemIndex)/numPackets;

            currentDetected = ...
                detectedCounts(systemIndex)/numPackets;

            currentUndetected = ...
                undetectedCounts(systemIndex)/numPackets;

            currentCRCOnly = ...
                crcOnlyCounts(systemIndex)/numPackets;

            %% CRC-Accepted Throughput

            acceptedPackets = ...
                numPackets-crcFailureCounts(systemIndex);

            acceptedThroughput = ...
                grossPayloadRates(systemIndex)* ...
                acceptedPackets/numPackets;

            %% Correct Payload Goodput

            goodPackets = ...
                numPackets - ...
                packetErrorCounts(systemIndex) - ...
                crcOnlyCounts(systemIndex);

            correctGoodput = ...
                grossPayloadRates(systemIndex)* ...
                goodPackets/numPackets;

            %% BER Confidence Interval

            [berLower,berUpper] = ...
                packet_mean_ci( ...
                    packetBERSamples(:,systemIndex), ...
                    packetErrorCounts(systemIndex), ...
                    numPackets,confidenceZ);

            %% PER Confidence Interval

            [perLower,perUpper] = ...
                wilson_ci( ...
                    packetErrorCounts(systemIndex), ...
                    numPackets,confidenceZ);

            %% CRC Confidence Interval

            [crcLower,crcUpper] = ...
                wilson_ci( ...
                    crcFailureCounts(systemIndex), ...
                    numPackets,confidenceZ);

            %% SAVE RESULT ROW

            rowIndex = rowIndex+1;

            System(rowIndex) = string(systemNames{systemIndex});

            Channel(rowIndex) = string(channelType);

            EbN0(rowIndex) = currentEbN0;

            AverageChannelPower(rowIndex) = averageChannelPower;

            PayloadBER(rowIndex) = currentBER;

            ChannelBER(rowIndex) = currentChannelBER;

            PER(rowIndex) = currentPER;

            CRCFailureRate(rowIndex) = currentCRCFailure;

            DetectedPER(rowIndex) = currentDetected;

            UndetectedPER(rowIndex) = currentUndetected;

            CRCOnlyFailureRate(rowIndex) = currentCRCOnly;

            PacketErrors(rowIndex) = ...
                packetErrorCounts(systemIndex);

            CRCFailures(rowIndex) = ...
                crcFailureCounts(systemIndex);

            DetectedErrors(rowIndex) = ...
                detectedCounts(systemIndex);

            UndetectedErrors(rowIndex) = ...
                undetectedCounts(systemIndex);

            CRCOnlyFailures(rowIndex) = ...
                crcOnlyCounts(systemIndex);

            CRCAcceptedThroughput(rowIndex) = ...
                acceptedThroughput;

            CorrectPayloadGoodput(rowIndex) = ...
                correctGoodput;

            BER_Lower95(rowIndex) = berLower;

            BER_Upper95(rowIndex) = berUpper;

            PER_Lower95(rowIndex) = perLower;

            PER_Upper95(rowIndex) = perUpper;

            CRC_Lower95(rowIndex) = crcLower;

            CRC_Upper95(rowIndex) = crcUpper;

        end

        %% =================================================
        % D. DISPLAY CURRENT SNR RESULTS
        %% =================================================

        fprintf('\nChannel: %s | Eb/N0: %.1f dB\n', ...
            channelType,currentEbN0);

        fprintf('Average channel power: %.6f\n', ...
            averageChannelPower);

        for systemIndex = 1:numSystems

            currentPER = ...
                packetErrorCounts(systemIndex)/numPackets;

            currentBER = ...
                payloadBitErrors(systemIndex)/totalPayloadBits;

            fprintf('\n%s\n',systemNames{systemIndex});

            fprintf('Payload BER: %.8e\n',currentBER);

            fprintf('Channel BER: %.8e\n', ...
                channelBitErrors(systemIndex)/ ...
                totalTransmittedBits(systemIndex));

            fprintf('PER: %.8e\n',currentPER);

            fprintf('CRC Failure Rate: %.8e\n', ...
                crcFailureCounts(systemIndex)/numPackets);

            fprintf('Packet Errors: %d / %d\n', ...
                packetErrorCounts(systemIndex),numPackets);

            fprintf('CRC Failures: %d / %d\n', ...
                crcFailureCounts(systemIndex),numPackets);

            fprintf('Detected Errors: %d\n', ...
                detectedCounts(systemIndex));

            fprintf('Undetected Errors: %d\n', ...
                undetectedCounts(systemIndex));

            fprintf('CRC-only Failures: %d\n', ...
                crcOnlyCounts(systemIndex));

            fprintf('Correct Payload Goodput: %.6f Mbps\n', ...
                CorrectPayloadGoodput(rowIndex-numSystems+systemIndex)/1e6);

        end

    end

end

%% =========================================================
% 8. CREATE SUMMARY TABLE
%% =========================================================

resultsTable = table( ...
    System, ...
    Channel, ...
    EbN0, ...
    AverageChannelPower, ...
    PayloadBER, ...
    ChannelBER, ...
    PER, ...
    CRCFailureRate, ...
    DetectedPER, ...
    UndetectedPER, ...
    CRCOnlyFailureRate, ...
    PacketErrors, ...
    CRCFailures, ...
    DetectedErrors, ...
    UndetectedErrors, ...
    CRCOnlyFailures, ...
    CRCAcceptedThroughput, ...
    CorrectPayloadGoodput);

fprintf('\n============================================\n');
fprintf('FINAL FADING PERFORMANCE SUMMARY\n');
fprintf('============================================\n');

disp(resultsTable);

%% =========================================================
% 9. CREATE CONFIDENCE INTERVAL TABLE
%% =========================================================

confidenceTable = table( ...
    System, ...
    Channel, ...
    EbN0, ...
    BER_Lower95, ...
    BER_Upper95, ...
    PER_Lower95, ...
    PER_Upper95, ...
    CRC_Lower95, ...
    CRC_Upper95);

fprintf('\n============================================\n');
fprintf('95%% CONFIDENCE INTERVAL SUMMARY\n');
fprintf('============================================\n');

disp(confidenceTable);

%% =========================================================
% 10. SAVE RESULTS
%% =========================================================

resultsFolder = fullfile(projectRoot,'results');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

writetable(resultsTable, ...
    fullfile(resultsFolder,'fec_fading_summary.csv'));

writetable(confidenceTable, ...
    fullfile(resultsFolder,'fec_fading_confidence_intervals.csv'));

save(fullfile(resultsFolder,'fec_fading_results.mat'), ...
    'resultsTable', ...
    'confidenceTable', ...
    'EbN0_dB', ...
    'channelTypes', ...
    'ricianK_dB', ...
    'numPackets', ...
    'effectiveCodeRate');

fprintf('\nAll fading result tables saved successfully.\n');

%% =========================================================
% 11. PLOT PAYLOAD BER
%% =========================================================

berFloor = 0.5/(numPackets*payloadLength);

figure;

hold on;
grid on;

styles = {'-o','-s','-^','--o','--s','--^'};

legendNames = { ...
    'Rayleigh - Uncoded', ...
    'Rayleigh - Hard Viterbi', ...
    'Rayleigh - Soft Viterbi', ...
    'Rician - Uncoded', ...
    'Rician - Hard Viterbi', ...
    'Rician - Soft Viterbi'};

plotIndex = 0;

for channelIndex = 1:numChannels

    for systemIndex = 1:numSystems

        plotIndex = plotIndex+1;

        mask = ...
            Channel == string(channelTypes{channelIndex}) & ...
            System == string(systemNames{systemIndex});

        semilogy( ...
            EbN0_dB, ...
            max(PayloadBER(mask),berFloor), ...
            styles{plotIndex}, ...
            'LineWidth',1.5);

    end

end

xlabel('E_b/N_0 (dB)');
ylabel('Payload BER');

title('FEC Performance over Fading Channels');

legend(legendNames,'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'fec_fading_payload_ber.png'));

%% =========================================================
% 12. PLOT PER
%% =========================================================

perFloor = 0.5/numPackets;

figure;

hold on;
grid on;

for channelIndex = 1:numChannels

    for systemIndex = 1:numSystems

        plotIndex = (channelIndex-1)*numSystems+systemIndex;

        mask = ...
            Channel == string(channelTypes{channelIndex}) & ...
            System == string(systemNames{systemIndex});

        semilogy( ...
            EbN0_dB, ...
            max(PER(mask),perFloor), ...
            styles{plotIndex}, ...
            'LineWidth',1.5);

    end

end

xlabel('E_b/N_0 (dB)');
ylabel('Packet Error Rate');

title('Packet Error Rate over Fading Channels');

legend(legendNames,'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'fec_fading_per.png'));

%% =========================================================
% 13. PLOT CORRECT PAYLOAD GOODPUT
%% =========================================================

figure;

hold on;
grid on;

for channelIndex = 1:numChannels

    for systemIndex = 1:numSystems

        plotIndex = (channelIndex-1)*numSystems+systemIndex;

        mask = ...
            Channel == string(channelTypes{channelIndex}) & ...
            System == string(systemNames{systemIndex});

        plot( ...
            EbN0_dB, ...
            CorrectPayloadGoodput(mask)/1e6, ...
            styles{plotIndex}, ...
            'LineWidth',1.5);

    end

end

xlabel('E_b/N_0 (dB)');
ylabel('Correct Payload Goodput (Mbps)');

title('Goodput over Rayleigh and Rician Channels');

legend(legendNames,'Location','southeast');

saveas(gcf, ...
    fullfile(resultsFolder,'fec_fading_goodput.png'));

%% =========================================================
% 14. FINAL VALIDATION
%% =========================================================

% Packet classification

assert(all(PacketErrors == ...
    DetectedErrors+UndetectedErrors));

% CRC classification

assert(all(CRCFailures == ...
    DetectedErrors+CRCOnlyFailures));

% PER and CRC ranges

assert(all(PER>=0 & PER<=1));

assert(all(CRCFailureRate>=0 & CRCFailureRate<=1));

% BER ranges

assert(all(PayloadBER>=0 & PayloadBER<=1));

assert(all(ChannelBER>=0 & ChannelBER<=1));

% Goodput ranges

assert(all(CorrectPayloadGoodput>=0));

assert(all(CRCAcceptedThroughput>=0));

assert(all(CorrectPayloadGoodput<= ...
    CRCAcceptedThroughput+eps | ...
    abs(CorrectPayloadGoodput-CRCAcceptedThroughput)<eps));

% Confidence interval checks

assert(all(BER_Lower95<=BER_Upper95));

assert(all(PER_Lower95<=PER_Upper95));

assert(all(CRC_Lower95<=CRC_Upper95));

assert(all(BER_Lower95>=0 & BER_Upper95<=1));

assert(all(PER_Lower95>=0 & PER_Upper95<=1));

assert(all(CRC_Lower95>=0 & CRC_Upper95<=1));

% Channel power must be positive

assert(all(AverageChannelPower>=0));

fprintf('\n============================================\n');
fprintf('FINAL VALIDATION PASSED\n');
fprintf('============================================\n');

fprintf('Packet classification: PASSED\n');
fprintf('CRC classification: PASSED\n');
fprintf('BER/PER validation: PASSED\n');
fprintf('Goodput validation: PASSED\n');
fprintf('Confidence interval validation: PASSED\n');
fprintf('Channel power validation: PASSED\n');

fprintf('\nAll FEC fading results saved successfully.\n');

fprintf('Results directory: %s\n',resultsFolder);

fprintf('\nMILESTONE 28 COMPLETED.\n');


%% =========================================================
% LOCAL FUNCTION 1
% GENERATE BLOCK FADING COEFFICIENT
%% =========================================================

function h = generate_packet_fading(channelType,K_dB)

    switch lower(channelType)

        case 'rayleigh'

            h = (randn+1i*randn)/sqrt(2);

        case 'rician'

            K = 10^(K_dB/10);

            los = sqrt(K/(K+1));

            scatter = sqrt(1/(K+1))* ...
                (randn+1i*randn)/sqrt(2);

            h = los+scatter;

        otherwise

            error('Unsupported fading channel.');

    end

end


%% =========================================================
% LOCAL FUNCTION 2
% WILSON SCORE CONFIDENCE INTERVAL
%% =========================================================

function [lower,upper] = wilson_ci(successes,total,z)

    if total<=0 || ...
       successes<0 || ...
       successes>total

        error('Invalid Wilson CI input.');

    end

    p = successes/total;

    denominator = 1+z^2/total;

    center = ...
        (p+z^2/(2*total))/denominator;

    halfWidth = ...
        z*sqrt(p*(1-p)/total+z^2/(4*total^2)) ...
        /denominator;

    lower = max(0,center-halfWidth);

    upper = min(1,center+halfWidth);

    if lower<1e-12
        lower = 0;
    end

    if 1-upper<1e-12
        upper = 1;
    end

end


%% =========================================================
% LOCAL FUNCTION 3
% PACKET-LEVEL BER CONFIDENCE INTERVAL
%% =========================================================

function [lower,upper] = ...
    packet_mean_ci(packetBER,packetErrors,numPackets,z)

    packetBER = double(packetBER(:));

    if numel(packetBER)~=numPackets || ...
       any(~isfinite(packetBER)) || ...
       any(packetBER<0 | packetBER>1)

        error('Invalid packet BER samples.');

    end

    meanBER = mean(packetBER);

    sampleStd = std(packetBER,0);

    if sampleStd>0

        standardError = sampleStd/sqrt(numPackets);

        halfWidth = z*standardError;

        lower = max(0,meanBER-halfWidth);

        upper = min(1,meanBER+halfWidth);

    elseif packetErrors==0

        % When no packet errors are observed,
        % use the Wilson upper bound for PER.
        % Packet BER is bounded by packet error indicator.

        [~,upper] = wilson_ci(0,numPackets,z);

        lower = 0;

    else

        % Conservative fallback

        halfWidth = sqrt(log(40)/(2*numPackets));

        lower = max(0,meanBER-halfWidth);

        upper = min(1,meanBER+halfWidth);

    end

end
