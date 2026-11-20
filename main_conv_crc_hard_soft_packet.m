clc;
clear;
close all;

%% =========================================================
% MILESTONE 27
% STATISTICAL VALIDATION OF PACKET-LEVEL CONVOLUTIONAL FEC
%
% Systems:
% 1. Uncoded BPSK + CRC-16
% 2. Convolutional (7,5) + Hard Viterbi + CRC-16
% 3. Convolutional (7,5) + Soft Viterbi + CRC-16
%
% Channel: AWGN
% Modulation: BPSK
%
% Metrics:
% - Payload BER and packet-cluster 95% CI
% - Channel BER
% - PER and Wilson 95% CI
% - CRC Failure Rate and Wilson 95% CI
% - Detected / Undetected / CRC-only errors
% - CRC-accepted payload throughput
% - Correct payload goodput
%
% Statistical note:
% BER confidence intervals are calculated from per-packet BER
% samples (packets are the independent sampling units).
% PER and CRC intervals use Wilson score intervals.
% When all packet BER samples are identical, a conservative
% Hoeffding bound is used instead of reporting a zero-width CI.
%% =========================================================

%% 1. PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

rng(2026,'twister');

%% 2. CONFIGURATION

payloadLength = 1024;
crcLength = 16;
packetLength = payloadLength + crcLength;

numPackets = 5000;
EbN0_dB = 0:2:12;
numSNR = numel(EbN0_dB);

symbolRate = 1e6;

%% 3. CONVOLUTIONAL CODE CONFIGURATION

nominalCodeRate = 1/2;
tailBits = 2;
codedBitsPerPacket = 2*(packetLength + tailBits);
effectiveCodeRate = packetLength/codedBitsPerPacket;
symbolAmplitude = sqrt(effectiveCodeRate);

%% 4. DISPLAY CONFIGURATION

fprintf('\n============================================\n');
fprintf('PACKET-LEVEL STATISTICAL VALIDATION\n');
fprintf('============================================\n');
fprintf('Payload length: %d bits\n',payloadLength);
fprintf('CRC length: %d bits\n',crcLength);
fprintf('Packet length: %d bits\n',packetLength);
fprintf('Number of packets per SNR: %d\n',numPackets);
fprintf('Convolutional code: (7,5)\n');
fprintf('Nominal code rate: %.6f\n',nominalCodeRate);
fprintf('Effective code rate: %.8f\n',effectiveCodeRate);
fprintf('Coded bits per packet: %d\n',codedBitsPerPacket);
fprintf('BPSK amplitude: %.8f\n',symbolAmplitude);
fprintf('Channel: AWGN\n');
fprintf('Eb/N0 range: %d to %d dB\n',EbN0_dB(1),EbN0_dB(end));
fprintf('Confidence level: 95%%\n');

%% 5. PREALLOCATE RESULT ARRAYS

% Main metrics
UncodedBER = zeros(numSNR,1);
UncodedChannelBER = zeros(numSNR,1);
UncodedPER = zeros(numSNR,1);
UncodedCRCFailureRate = zeros(numSNR,1);
UncodedDetectedPER = zeros(numSNR,1);
UncodedUndetectedPER = zeros(numSNR,1);
UncodedCRCOnlyRate = zeros(numSNR,1);

HardBER = zeros(numSNR,1);
HardChannelBER = zeros(numSNR,1);
HardPER = zeros(numSNR,1);
HardCRCFailureRate = zeros(numSNR,1);
HardDetectedPER = zeros(numSNR,1);
HardUndetectedPER = zeros(numSNR,1);
HardCRCOnlyRate = zeros(numSNR,1);

SoftBER = zeros(numSNR,1);
SoftChannelBER = zeros(numSNR,1);
SoftPER = zeros(numSNR,1);
SoftCRCFailureRate = zeros(numSNR,1);
SoftDetectedPER = zeros(numSNR,1);
SoftUndetectedPER = zeros(numSNR,1);
SoftCRCOnlyRate = zeros(numSNR,1);

% Throughput
UncodedGoodput = zeros(numSNR,1);
HardGoodput = zeros(numSNR,1);
SoftGoodput = zeros(numSNR,1);

UncodedAcceptedRate = zeros(numSNR,1);
HardAcceptedRate = zeros(numSNR,1);
SoftAcceptedRate = zeros(numSNR,1);

% Integer counters
UncodedPacketErrors = zeros(numSNR,1);
HardPacketErrors = zeros(numSNR,1);
SoftPacketErrors = zeros(numSNR,1);

UncodedCRCFailures = zeros(numSNR,1);
HardCRCFailures = zeros(numSNR,1);
SoftCRCFailures = zeros(numSNR,1);

% Packet-level BER confidence intervals
UncodedBER_CI_Lower = zeros(numSNR,1);
UncodedBER_CI_Upper = zeros(numSNR,1);
HardBER_CI_Lower = zeros(numSNR,1);
HardBER_CI_Upper = zeros(numSNR,1);
SoftBER_CI_Lower = zeros(numSNR,1);
SoftBER_CI_Upper = zeros(numSNR,1);

% PER Wilson confidence intervals
UncodedPER_CI_Lower = zeros(numSNR,1);
UncodedPER_CI_Upper = zeros(numSNR,1);
HardPER_CI_Lower = zeros(numSNR,1);
HardPER_CI_Upper = zeros(numSNR,1);
SoftPER_CI_Lower = zeros(numSNR,1);
SoftPER_CI_Upper = zeros(numSNR,1);

% CRC failure Wilson confidence intervals
UncodedCRC_CI_Lower = zeros(numSNR,1);
UncodedCRC_CI_Upper = zeros(numSNR,1);
HardCRC_CI_Lower = zeros(numSNR,1);
HardCRC_CI_Upper = zeros(numSNR,1);
SoftCRC_CI_Lower = zeros(numSNR,1);
SoftCRC_CI_Upper = zeros(numSNR,1);

%% 6. MAIN SIMULATION

confidenceZ = 1.95996398454005;

for snrIndex = 1:numSNR

    currentEbN0 = EbN0_dB(snrIndex);

    fprintf('\n============================================\n');
    fprintf('Eb/N0 = %.1f dB\n',currentEbN0);
    fprintf('============================================\n');

    %% INITIALIZE COUNTERS

    ucBitErrors = 0;
    ucChannelErrors = 0;
    ucPacketErrors = 0;
    ucCRCFailures = 0;
    ucDetected = 0;
    ucUndetected = 0;
    ucCRCOnly = 0;

    hardBitErrors = 0;
    hardChannelErrors = 0;
    hardPacketErrors = 0;
    hardCRCFailures = 0;
    hardDetected = 0;
    hardUndetected = 0;
    hardCRCOnly = 0;

    softBitErrors = 0;
    softChannelErrors = 0;
    softPacketErrors = 0;
    softCRCFailures = 0;
    softDetected = 0;
    softUndetected = 0;
    softCRCOnly = 0;

    %% PER-PACKET BER SAMPLES
    % Each entry is the fraction of erroneous payload bits
    % in one independently generated packet.

    ucPacketBER = zeros(numPackets,1);
    hardPacketBER = zeros(numPackets,1);
    softPacketBER = zeros(numPackets,1);

    %% PACKET TRANSMISSION LOOP

    for packetIndex = 1:numPackets

        %% A. GENERATE PAYLOAD AND CRC

        payloadBits = generate_bits(payloadLength);
        txPacket = append_crc16(payloadBits);

        %% =====================================
        % SYSTEM 1: UNCODED BPSK + CRC
        %% =====================================

        ucTxSymbols = bpsk_modulator(txPacket);

        ucRxSymbols = awgn_channel( ...
            ucTxSymbols,currentEbN0,1,1);

        ucRxPacket = bpsk_demodulator(ucRxSymbols);

        ucChannelErrors = ucChannelErrors + ...
            nnz(txPacket(:) ~= ucRxPacket(:));

        [ucRxPayload,ucCRCOK] = verify_crc16(ucRxPacket);

        ucErrors = nnz(payloadBits(:) ~= ucRxPayload(:));
        ucBitErrors = ucBitErrors + ucErrors;
        ucPacketBER(packetIndex) = ucErrors/payloadLength;

        ucPacketError = (ucErrors > 0);

        if ucPacketError
            ucPacketErrors = ucPacketErrors + 1;
        end

        if ~ucCRCOK
            ucCRCFailures = ucCRCFailures + 1;
        end

        if ucPacketError && ~ucCRCOK
            ucDetected = ucDetected + 1;
        elseif ucPacketError && ucCRCOK
            ucUndetected = ucUndetected + 1;
        elseif ~ucPacketError && ~ucCRCOK
            ucCRCOnly = ucCRCOnly + 1;
        end

        %% =====================================
        % COMMON CONVOLUTIONAL TRANSMITTER
        %% =====================================

        txCodedBits = convolutional_encoder(txPacket);

        if numel(txCodedBits) ~= codedBitsPerPacket
            error('Unexpected convolutional output length.');
        end

        codedTxSymbols = symbolAmplitude * ...
            bpsk_modulator(txCodedBits);

        codedRxSymbols = awgn_channel( ...
            codedTxSymbols,currentEbN0,1,1);

        % Same analog channel samples feed both decoders.
        codedRxHardBits = bpsk_demodulator(codedRxSymbols);

        channelErrorCount = nnz( ...
            txCodedBits(:) ~= codedRxHardBits(:));

        %% =====================================
        % SYSTEM 2: HARD VITERBI + CRC
        %% =====================================

        hardDecodedPacket = ...
            viterbi_decoder_hard(codedRxHardBits);

        hardDecodedPacket = hardDecodedPacket(:).';

        [hardRxPayload,hardCRCOK] = ...
            verify_crc16(hardDecodedPacket);

        hardErrors = nnz(payloadBits(:) ~= hardRxPayload(:));
        hardBitErrors = hardBitErrors + hardErrors;
        hardPacketBER(packetIndex) = hardErrors/payloadLength;

        hardPacketError = (hardErrors > 0);

        if hardPacketError
            hardPacketErrors = hardPacketErrors + 1;
        end

        if ~hardCRCOK
            hardCRCFailures = hardCRCFailures + 1;
        end

        if hardPacketError && ~hardCRCOK
            hardDetected = hardDetected + 1;
        elseif hardPacketError && hardCRCOK
            hardUndetected = hardUndetected + 1;
        elseif ~hardPacketError && ~hardCRCOK
            hardCRCOnly = hardCRCOnly + 1;
        end

        %% =====================================
        % SYSTEM 3: SOFT VITERBI + CRC
        %% =====================================

        % IMPORTANT: use the original analog samples.
        % Do not pass hard decisions to the soft decoder.

        softDecodedPacket = viterbi_decoder_soft( ...
            codedRxSymbols,symbolAmplitude);

        softDecodedPacket = softDecodedPacket(:).';

        [softRxPayload,softCRCOK] = ...
            verify_crc16(softDecodedPacket);

        softErrors = nnz(payloadBits(:) ~= softRxPayload(:));
        softBitErrors = softBitErrors + softErrors;
        softPacketBER(packetIndex) = softErrors/payloadLength;

        softPacketError = (softErrors > 0);

        if softPacketError
            softPacketErrors = softPacketErrors + 1;
        end

        if ~softCRCOK
            softCRCFailures = softCRCFailures + 1;
        end

        if softPacketError && ~softCRCOK
            softDetected = softDetected + 1;
        elseif softPacketError && softCRCOK
            softUndetected = softUndetected + 1;
        elseif ~softPacketError && ~softCRCOK
            softCRCOnly = softCRCOnly + 1;
        end

        % The same coded channel error count applies to both decoders.
        hardChannelErrors = hardChannelErrors + channelErrorCount;
        softChannelErrors = softChannelErrors + channelErrorCount;

    end

    %% 7. PERFORMANCE METRICS

    totalPayloadBits = numPackets*payloadLength;
    totalPacketBits = numPackets*packetLength;
    totalCodedBits = numPackets*codedBitsPerPacket;

    % Uncoded
    ucBER = ucBitErrors/totalPayloadBits;
    ucChannelBER = ucChannelErrors/totalPacketBits;
    ucPER = ucPacketErrors/numPackets;
    ucCRCFailureRate = ucCRCFailures/numPackets;
    ucDetectedRate = ucDetected/numPackets;
    ucUndetectedRate = ucUndetected/numPackets;
    ucCRCOnlyRate = ucCRCOnly/numPackets;

    % Hard Viterbi
    hardBER = hardBitErrors/totalPayloadBits;
    hardChannelBER = hardChannelErrors/totalCodedBits;
    hardPER = hardPacketErrors/numPackets;
    hardCRCFailureRate = hardCRCFailures/numPackets;
    hardDetectedRate = hardDetected/numPackets;
    hardUndetectedRate = hardUndetected/numPackets;
    hardCRCOnlyRate = hardCRCOnly/numPackets;

    % Soft Viterbi
    softBER = softBitErrors/totalPayloadBits;
    softChannelBER = softChannelErrors/totalCodedBits;
    softPER = softPacketErrors/numPackets;
    softCRCFailureRate = softCRCFailures/numPackets;
    softDetectedRate = softDetected/numPackets;
    softUndetectedRate = softUndetected/numPackets;
    softCRCOnlyRate = softCRCOnly/numPackets;

    %% 8. THROUGHPUT

    uncodedGrossPayloadRate = ...
        symbolRate*(payloadLength/packetLength);

    codedGrossPayloadRate = ...
        symbolRate*effectiveCodeRate*(payloadLength/packetLength);

    ucAccepted = uncodedGrossPayloadRate* ...
        (numPackets-ucCRCFailures)/numPackets;

    hardAccepted = codedGrossPayloadRate* ...
        (numPackets-hardCRCFailures)/numPackets;

    softAccepted = codedGrossPayloadRate* ...
        (numPackets-softCRCFailures)/numPackets;

    ucGoodPackets = numPackets-ucPacketErrors-ucCRCOnly;
    hardGoodPackets = numPackets-hardPacketErrors-hardCRCOnly;
    softGoodPackets = numPackets-softPacketErrors-softCRCOnly;

    ucGoodput = uncodedGrossPayloadRate*ucGoodPackets/numPackets;
    hardGoodput = codedGrossPayloadRate*hardGoodPackets/numPackets;
    softGoodput = codedGrossPayloadRate*softGoodPackets/numPackets;

    %% 9. STATISTICAL CONFIDENCE INTERVALS

    % Packet-cluster BER intervals.
    [UncodedBER_CI_Lower(snrIndex),UncodedBER_CI_Upper(snrIndex)] = ...
        packet_mean_ci(ucPacketBER,confidenceZ);

    [HardBER_CI_Lower(snrIndex),HardBER_CI_Upper(snrIndex)] = ...
        packet_mean_ci(hardPacketBER,confidenceZ);

    [SoftBER_CI_Lower(snrIndex),SoftBER_CI_Upper(snrIndex)] = ...
        packet_mean_ci(softPacketBER,confidenceZ);

    % Wilson intervals for PER.
    [UncodedPER_CI_Lower(snrIndex),UncodedPER_CI_Upper(snrIndex)] = ...
        wilson_ci(ucPacketErrors,numPackets,confidenceZ);

    [HardPER_CI_Lower(snrIndex),HardPER_CI_Upper(snrIndex)] = ...
        wilson_ci(hardPacketErrors,numPackets,confidenceZ);

    [SoftPER_CI_Lower(snrIndex),SoftPER_CI_Upper(snrIndex)] = ...
        wilson_ci(softPacketErrors,numPackets,confidenceZ);

    % Wilson intervals for CRC failure rate.
    [UncodedCRC_CI_Lower(snrIndex),UncodedCRC_CI_Upper(snrIndex)] = ...
        wilson_ci(ucCRCFailures,numPackets,confidenceZ);

    [HardCRC_CI_Lower(snrIndex),HardCRC_CI_Upper(snrIndex)] = ...
        wilson_ci(hardCRCFailures,numPackets,confidenceZ);

    [SoftCRC_CI_Lower(snrIndex),SoftCRC_CI_Upper(snrIndex)] = ...
        wilson_ci(softCRCFailures,numPackets,confidenceZ);

    %% 10. STORE MAIN RESULTS

    UncodedBER(snrIndex) = ucBER;
    UncodedChannelBER(snrIndex) = ucChannelBER;
    UncodedPER(snrIndex) = ucPER;
    UncodedCRCFailureRate(snrIndex) = ucCRCFailureRate;
    UncodedDetectedPER(snrIndex) = ucDetectedRate;
    UncodedUndetectedPER(snrIndex) = ucUndetectedRate;
    UncodedCRCOnlyRate(snrIndex) = ucCRCOnlyRate;

    HardBER(snrIndex) = hardBER;
    HardChannelBER(snrIndex) = hardChannelBER;
    HardPER(snrIndex) = hardPER;
    HardCRCFailureRate(snrIndex) = hardCRCFailureRate;
    HardDetectedPER(snrIndex) = hardDetectedRate;
    HardUndetectedPER(snrIndex) = hardUndetectedRate;
    HardCRCOnlyRate(snrIndex) = hardCRCOnlyRate;

    SoftBER(snrIndex) = softBER;
    SoftChannelBER(snrIndex) = softChannelBER;
    SoftPER(snrIndex) = softPER;
    SoftCRCFailureRate(snrIndex) = softCRCFailureRate;
    SoftDetectedPER(snrIndex) = softDetectedRate;
    SoftUndetectedPER(snrIndex) = softUndetectedRate;
    SoftCRCOnlyRate(snrIndex) = softCRCOnlyRate;

    UncodedGoodput(snrIndex) = ucGoodput;
    HardGoodput(snrIndex) = hardGoodput;
    SoftGoodput(snrIndex) = softGoodput;

    UncodedAcceptedRate(snrIndex) = ucAccepted;
    HardAcceptedRate(snrIndex) = hardAccepted;
    SoftAcceptedRate(snrIndex) = softAccepted;

    UncodedPacketErrors(snrIndex) = ucPacketErrors;
    HardPacketErrors(snrIndex) = hardPacketErrors;
    SoftPacketErrors(snrIndex) = softPacketErrors;

    UncodedCRCFailures(snrIndex) = ucCRCFailures;
    HardCRCFailures(snrIndex) = hardCRCFailures;
    SoftCRCFailures(snrIndex) = softCRCFailures;

    %% 11. DISPLAY SNR RESULTS

    fprintf('\nUNCODED BPSK + CRC:\n');
    fprintf('Payload BER: %.8e\n',ucBER);
    fprintf('Payload BER 95%% CI: [%.8e, %.8e]\n', ...
        UncodedBER_CI_Lower(snrIndex),UncodedBER_CI_Upper(snrIndex));
    fprintf('PER: %.8e\n',ucPER);
    fprintf('PER 95%% CI: [%.8e, %.8e]\n', ...
        UncodedPER_CI_Lower(snrIndex),UncodedPER_CI_Upper(snrIndex));
    fprintf('CRC Failure Rate: %.8e\n',ucCRCFailureRate);
    fprintf('CRC 95%% CI: [%.8e, %.8e]\n', ...
        UncodedCRC_CI_Lower(snrIndex),UncodedCRC_CI_Upper(snrIndex));
    fprintf('Correct Payload Goodput: %.6f Mbps\n',ucGoodput/1e6);

    fprintf('\nHARD VITERBI + CRC:\n');
    fprintf('Payload BER: %.8e\n',hardBER);
    fprintf('Payload BER 95%% CI: [%.8e, %.8e]\n', ...
        HardBER_CI_Lower(snrIndex),HardBER_CI_Upper(snrIndex));
    fprintf('PER: %.8e\n',hardPER);
    fprintf('PER 95%% CI: [%.8e, %.8e]\n', ...
        HardPER_CI_Lower(snrIndex),HardPER_CI_Upper(snrIndex));
    fprintf('CRC Failure Rate: %.8e\n',hardCRCFailureRate);
    fprintf('CRC 95%% CI: [%.8e, %.8e]\n', ...
        HardCRC_CI_Lower(snrIndex),HardCRC_CI_Upper(snrIndex));
    fprintf('Correct Payload Goodput: %.6f Mbps\n',hardGoodput/1e6);

    fprintf('\nSOFT VITERBI + CRC:\n');
    fprintf('Payload BER: %.8e\n',softBER);
    fprintf('Payload BER 95%% CI: [%.8e, %.8e]\n', ...
        SoftBER_CI_Lower(snrIndex),SoftBER_CI_Upper(snrIndex));
    fprintf('PER: %.8e\n',softPER);
    fprintf('PER 95%% CI: [%.8e, %.8e]\n', ...
        SoftPER_CI_Lower(snrIndex),SoftPER_CI_Upper(snrIndex));
    fprintf('CRC Failure Rate: %.8e\n',softCRCFailureRate);
    fprintf('CRC 95%% CI: [%.8e, %.8e]\n', ...
        SoftCRC_CI_Lower(snrIndex),SoftCRC_CI_Upper(snrIndex));
    fprintf('Correct Payload Goodput: %.6f Mbps\n',softGoodput/1e6);

end

%% 12. CREATE MAIN RESULTS TABLE

System = [ ...
    repmat("Uncoded BPSK + CRC",numSNR,1); ...
    repmat("Hard Viterbi + CRC",numSNR,1); ...
    repmat("Soft Viterbi + CRC",numSNR,1)];

EbN0 = [EbN0_dB(:);EbN0_dB(:);EbN0_dB(:)];

PayloadBER = [UncodedBER;HardBER;SoftBER];
ChannelBER = [UncodedChannelBER;HardChannelBER;SoftChannelBER];
PER = [UncodedPER;HardPER;SoftPER];
CRCFailureRate = [UncodedCRCFailureRate;HardCRCFailureRate;SoftCRCFailureRate];
DetectedPER = [UncodedDetectedPER;HardDetectedPER;SoftDetectedPER];
UndetectedPER = [UncodedUndetectedPER;HardUndetectedPER;SoftUndetectedPER];
CRCOnlyFailureRate = [UncodedCRCOnlyRate;HardCRCOnlyRate;SoftCRCOnlyRate];
PacketErrors = [UncodedPacketErrors;HardPacketErrors;SoftPacketErrors];
CRCFailures = [UncodedCRCFailures;HardCRCFailures;SoftCRCFailures];
CRCAcceptedThroughput = [UncodedAcceptedRate;HardAcceptedRate;SoftAcceptedRate];
CorrectPayloadGoodput = [UncodedGoodput;HardGoodput;SoftGoodput];

resultsTable = table( ...
    System,EbN0,PayloadBER,ChannelBER,PER,CRCFailureRate, ...
    DetectedPER,UndetectedPER,CRCOnlyFailureRate, ...
    PacketErrors,CRCFailures,CRCAcceptedThroughput,CorrectPayloadGoodput);

fprintf('\n============================================\n');
fprintf('FINAL PACKET PERFORMANCE SUMMARY\n');
fprintf('============================================\n');
disp(resultsTable);

%% 13. CREATE CONFIDENCE INTERVAL SUMMARY TABLE

CI_System = System;
CI_EbN0 = EbN0;

BER_Lower95 = [UncodedBER_CI_Lower;HardBER_CI_Lower;SoftBER_CI_Lower];
BER_Upper95 = [UncodedBER_CI_Upper;HardBER_CI_Upper;SoftBER_CI_Upper];

PER_Lower95 = [UncodedPER_CI_Lower;HardPER_CI_Lower;SoftPER_CI_Lower];
PER_Upper95 = [UncodedPER_CI_Upper;HardPER_CI_Upper;SoftPER_CI_Upper];

CRC_Lower95 = [UncodedCRC_CI_Lower;HardCRC_CI_Lower;SoftCRC_CI_Lower];
CRC_Upper95 = [UncodedCRC_CI_Upper;HardCRC_CI_Upper;SoftCRC_CI_Upper];

confidenceTable = table( ...
    CI_System,CI_EbN0, ...
    BER_Lower95,BER_Upper95, ...
    PER_Lower95,PER_Upper95, ...
    CRC_Lower95,CRC_Upper95);

fprintf('\n============================================\n');
fprintf('95%% CONFIDENCE INTERVAL SUMMARY\n');
fprintf('============================================\n');
disp(confidenceTable);

%% 14. CREATE RESULTS DIRECTORY AND SAVE TABLES

resultsFolder = fullfile(projectRoot,'results');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

writetable(resultsTable, ...
    fullfile(resultsFolder,'conv_crc_packet_summary.csv'));

writetable(confidenceTable, ...
    fullfile(resultsFolder,'fec_confidence_intervals.csv'));

save(fullfile(resultsFolder,'conv_crc_statistical_results.mat'), ...
    'resultsTable','confidenceTable','EbN0_dB','numPackets', ...
    'payloadLength','crcLength','packetLength','effectiveCodeRate');

fprintf('\nResults tables saved successfully.\n');

%% 15. PLOT PER WITH 95% WILSON INTERVALS

perFloor = 0.5/numPackets;

figure;

errorbar(EbN0_dB(:), ...
    max(UncodedPER,perFloor), ...
    max(UncodedPER-UncodedPER_CI_Lower,0), ...
    max(UncodedPER_CI_Upper-UncodedPER,0), ...
    '-o','LineWidth',1.3);

hold on;

errorbar(EbN0_dB(:), ...
    max(HardPER,perFloor), ...
    max(HardPER-HardPER_CI_Lower,0), ...
    max(HardPER_CI_Upper-HardPER,0), ...
    '-s','LineWidth',1.3);

errorbar(EbN0_dB(:), ...
    max(SoftPER,perFloor), ...
    max(SoftPER-SoftPER_CI_Lower,0), ...
    max(SoftPER_CI_Upper-SoftPER,0), ...
    '-^','LineWidth',1.3);

grid on;
set(gca,'YScale','log');
xlabel('E_b/N_0 (dB)');
ylabel('Packet Error Rate');
title('PER with 95% Wilson Confidence Intervals');
legend('Uncoded + CRC','Hard Viterbi + CRC','Soft Viterbi + CRC', ...
    'Location','southwest');

saveas(gcf,fullfile(resultsFolder,'conv_crc_per_95ci.png'));

%% 16. PLOT GOODPUT

figure;
plot(EbN0_dB,UncodedGoodput/1e6,'-o','LineWidth',1.5);
hold on;
plot(EbN0_dB,HardGoodput/1e6,'-s','LineWidth',1.5);
plot(EbN0_dB,SoftGoodput/1e6,'-^','LineWidth',1.5);
grid on;
xlabel('E_b/N_0 (dB)');
ylabel('Correct Payload Goodput (Mbps)');
title('Packet-Level Correct Payload Goodput');
legend('Uncoded + CRC','Hard Viterbi + CRC','Soft Viterbi + CRC', ...
    'Location','southeast');
saveas(gcf,fullfile(resultsFolder,'conv_crc_goodput.png'));

%% 17. STATISTICAL VALIDATION

% Packet classification
assert(all(UncodedPacketErrors == round( ...
    UncodedDetectedPER*numPackets + UncodedUndetectedPER*numPackets)));
assert(all(HardPacketErrors == round( ...
    HardDetectedPER*numPackets + HardUndetectedPER*numPackets)));
assert(all(SoftPacketErrors == round( ...
    SoftDetectedPER*numPackets + SoftUndetectedPER*numPackets)));

% CRC failure classification
assert(all(UncodedCRCFailures == ...
    round(UncodedDetectedPER*numPackets) + round(UncodedCRCOnlyRate*numPackets)));
assert(all(HardCRCFailures == ...
    round(HardDetectedPER*numPackets) + round(HardCRCOnlyRate*numPackets)));
assert(all(SoftCRCFailures == ...
    round(SoftDetectedPER*numPackets) + round(SoftCRCOnlyRate*numPackets)));

% Metric ranges
assert(all(PayloadBER >= 0 & PayloadBER <= 1));
assert(all(ChannelBER >= 0 & ChannelBER <= 1));
assert(all(PER >= 0 & PER <= 1));
assert(all(CRCFailureRate >= 0 & CRCFailureRate <= 1));

% Confidence interval ordering and range
assert(all(BER_Lower95 <= BER_Upper95));
assert(all(PER_Lower95 <= PER_Upper95));
assert(all(CRC_Lower95 <= CRC_Upper95));
assert(all(BER_Lower95 >= 0 & BER_Upper95 <= 1));
assert(all(PER_Lower95 >= 0 & PER_Upper95 <= 1));
assert(all(CRC_Lower95 >= 0 & CRC_Upper95 <= 1));

% Goodput bounds
assert(all(CorrectPayloadGoodput >= 0));
assert(all(CRCAcceptedThroughput >= 0));

uncodedGrossPayloadRate = symbolRate*(payloadLength/packetLength);
codedGrossPayloadRate = symbolRate*effectiveCodeRate*(payloadLength/packetLength);

assert(all(UncodedGoodput <= uncodedGrossPayloadRate+eps));
assert(all(HardGoodput <= codedGrossPayloadRate+eps));
assert(all(SoftGoodput <= codedGrossPayloadRate+eps));

fprintf('\n============================================\n');
fprintf('FINAL VALIDATION PASSED\n');
fprintf('============================================\n');
fprintf('Packet classification: PASSED\n');
fprintf('CRC failure classification: PASSED\n');
fprintf('BER/PER range validation: PASSED\n');
fprintf('Goodput validation: PASSED\n');
fprintf('BER confidence interval validation: PASSED\n');
fprintf('PER Wilson interval validation: PASSED\n');
fprintf('CRC Wilson interval validation: PASSED\n');
fprintf('\nAll statistical results saved.\n');
fprintf('Results directory: %s\n',resultsFolder);
fprintf('MILESTONE 27 COMPLETED.\n');

%% =========================================================
% LOCAL FUNCTION 1: WILSON SCORE CONFIDENCE INTERVAL
%% =========================================================

function [lower,upper] = wilson_ci(successes,total,z)

    if ~isscalar(total) || total <= 0 || ...
       ~isscalar(successes) || successes < 0 || ...
       successes > total || fix(successes) ~= successes
        error('Invalid Wilson confidence interval inputs.');
    end

    p = successes/total;
    denominator = 1 + z^2/total;
    center = (p + z^2/(2*total))/denominator;

    halfWidth = z*sqrt( ...
        p*(1-p)/total + z^2/(4*total^2))/denominator;

    lower = max(0,center-halfWidth);
    upper = min(1,center+halfWidth);

end

%% =========================================================
% LOCAL FUNCTION 2: PACKET-CLUSTER BER CONFIDENCE INTERVAL
%% =========================================================

function [lower,upper] = packet_mean_ci(packetBER,z)

    packetBER = double(packetBER(:));

    n = numel(packetBER);

    if n < 2 || any(~isfinite(packetBER)) || ...
       any(packetBER < 0 | packetBER > 1)
        error('Invalid packet BER samples.');
    end

    meanBER = mean(packetBER);
    sampleStd = std(packetBER,0);

    if sampleStd > 0
        % Large-sample normal approximation using packets as clusters.
        halfWidth = z*sampleStd/sqrt(n);
    else
        % Conservative two-sided Hoeffding bound for a degenerate
        % sample (for example, zero observed errors in every packet).
        alpha = 0.05;
        halfWidth = sqrt(log(2/alpha)/(2*n));
    end

    lower = max(0,meanBER-halfWidth);
    upper = min(1,meanBER+halfWidth);

end