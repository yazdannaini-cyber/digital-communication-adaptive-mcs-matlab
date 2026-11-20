
clc;
clear;
close all;

%% =========================================================
% MILESTONE 21
% CRC-16 + HAMMING (7,4) OVER AWGN
%
% Systems:
%   1. Uncoded BPSK + CRC-16
%   2. BPSK + Hamming (7,4) + CRC-16
%
% Metrics:
%   Payload BER
%   Pre-decoder Channel BER
%   PER
%   CRC Failure Rate
%   Detected Packet Error Rate
%   Undetected Packet Error Rate
%   CRC-only Failure Rate
%   Codeword Error Rate
%   Decoder Correction Attempt Rate
%   Single-bit Correction Success Rate
%   Correct Payload Goodput
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

numPackets = 5000;

EbN0_dB = 0:2:14;
numSNR = numel(EbN0_dB);

symbolRate = 1e6;

codeRate = 4/7;

bitsPerSymbol = 1;

codewordsPerPacket = packetLength/4;
codedBitsPerPacket = codewordsPerPacket*7;

assert(mod(packetLength,4)==0);

fprintf('\n');
fprintf('============================================\n');
fprintf('CRC + HAMMING PACKET PERFORMANCE ANALYSIS\n');
fprintf('============================================\n');

fprintf('Payload length: %d bits\n',payloadLength);
fprintf('CRC length: %d bits\n',crcLength);
fprintf('Packet length: %d bits\n',packetLength);

fprintf('Hamming code: (7,4)\n');
fprintf('Code rate: %.6f\n',codeRate);

fprintf('Codewords per packet: %d\n',codewordsPerPacket);
fprintf('Coded bits per packet: %d\n',codedBitsPerPacket);

fprintf('Number of packets: %d\n',numPackets);
fprintf('SNR range: %d to %d dB\n', ...
    EbN0_dB(1),EbN0_dB(end));

fprintf('Channel: AWGN\n');
fprintf('Modulation: BPSK\n');

%% 3. PREALLOCATE RESULTS

UncodedPayloadBER = zeros(numSNR,1);
UncodedChannelBER = zeros(numSNR,1);
UncodedPER = zeros(numSNR,1);
UncodedCRCFailureRate = zeros(numSNR,1);
UncodedDetectedPER = zeros(numSNR,1);
UncodedUndetectedPER = zeros(numSNR,1);
UncodedCRCOnlyFailureRate = zeros(numSNR,1);

UncodedPacketErrors = zeros(numSNR,1);
UncodedCRCFailures = zeros(numSNR,1);
UncodedDetectedErrors = zeros(numSNR,1);
UncodedUndetectedErrors = zeros(numSNR,1);
UncodedCRCOnlyFailures = zeros(numSNR,1);

CodedPayloadBER = zeros(numSNR,1);
CodedChannelBER = zeros(numSNR,1);
CodedPER = zeros(numSNR,1);
CodedCRCFailureRate = zeros(numSNR,1);
CodedDetectedPER = zeros(numSNR,1);
CodedUndetectedPER = zeros(numSNR,1);
CodedCRCOnlyFailureRate = zeros(numSNR,1);

CodedPacketErrors = zeros(numSNR,1);
CodedCRCFailures = zeros(numSNR,1);
CodedDetectedErrors = zeros(numSNR,1);
CodedUndetectedErrors = zeros(numSNR,1);
CodedCRCOnlyFailures = zeros(numSNR,1);

CodewordErrorRate = zeros(numSNR,1);
DecoderCorrectionAttemptRate = zeros(numSNR,1);
SingleErrorCorrectionSuccessRate = nan(numSNR,1);

UncodedPayloadGrossRate = zeros(numSNR,1);
CodedPayloadGrossRate = zeros(numSNR,1);

UncodedCRCAcceptedRate = zeros(numSNR,1);
CodedCRCAcceptedRate = zeros(numSNR,1);

UncodedGoodput = zeros(numSNR,1);
CodedGoodput = zeros(numSNR,1);

UncodedTheory = zeros(numSNR,1);
CodedChannelTheory = zeros(numSNR,1);
CodedPayloadTheory = zeros(numSNR,1);

%% 4. MAIN SIMULATION

for snrIndex = 1:numSNR

    currentEbN0 = EbN0_dB(snrIndex);

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('Eb/N0 = %.1f dB\n',currentEbN0);
    fprintf('============================================\n');

    %% -----------------------------------------
    % INITIALIZE UNCODED COUNTERS
    %% -----------------------------------------

    ucPayloadErrors = 0;
    ucChannelErrors = 0;

    ucPacketErrors = 0;
    ucCRCFailures = 0;

    ucDetected = 0;
    ucUndetected = 0;
    ucCRCOnly = 0;

    %% -----------------------------------------
    % INITIALIZE CODED COUNTERS
    %% -----------------------------------------

    cPayloadErrors = 0;
    cChannelErrors = 0;

    cPacketErrors = 0;
    cCRCFailures = 0;

    cDetected = 0;
    cUndetected = 0;
    cCRCOnly = 0;

    %% -----------------------------------------
    % HAMMING COUNTERS
    %% -----------------------------------------

    totalCodewordErrors = 0;
    totalCorrectionAttempts = 0;

    totalSingleErrorWords = 0;
    totalSuccessfulSingleCorrections = 0;

    %% =========================================
    % PACKET TRANSMISSION LOOP
    %% =========================================

    for packetIndex = 1:numPackets

        %% A. GENERATE PAYLOAD

        payloadBits = generate_bits(payloadLength);

        %% B. APPEND CRC

        txPacket = append_crc16(payloadBits);

        %% =====================================
        % SYSTEM 1: UNCODED BPSK + CRC
        %% =====================================

        %% 1. BPSK Modulation

        ucTxSymbols = bpsk_modulator(txPacket);

        %% 2. AWGN Channel

        ucRxSymbols = awgn_channel( ...
            ucTxSymbols, ...
            currentEbN0, ...
            bitsPerSymbol, ...
            1);

        %% 3. BPSK Demodulation

        ucRxPacket = bpsk_demodulator(ucRxSymbols);

        %% 4. Channel Bit Errors

        ucChannelErrors = ucChannelErrors + ...
            sum(txPacket ~= ucRxPacket);

        %% 5. CRC Verification

        [ucRxPayload,ucCRCOK] = ...
            verify_crc16(ucRxPacket);

        %% 6. Payload Errors

        ucBitErrors = sum(payloadBits ~= ucRxPayload);

        ucPayloadErrors = ucPayloadErrors + ucBitErrors;

        ucPacketError = (ucBitErrors > 0);

        %% 7. Packet Classification

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
        % SYSTEM 2: CRC + HAMMING + BPSK
        %% =====================================

        %% 1. HAMMING ENCODER

        txCodedBits = hamming74_encoder(txPacket);

        if numel(txCodedBits) ~= codedBitsPerPacket

            error('Unexpected Hamming encoded packet length.');

        end

        %% 2. BPSK MODULATION

        cTxSymbols = bpsk_modulator(txCodedBits);

        % Energy normalization per pre-FEC bit

        cTxSymbols = sqrt(codeRate)*cTxSymbols;

        %% 3. AWGN CHANNEL

        cRxSymbols = awgn_channel( ...
            cTxSymbols, ...
            currentEbN0, ...
            bitsPerSymbol, ...
            1);

        %% 4. BPSK DEMODULATION

        cRxBits = bpsk_demodulator(cRxSymbols);

  %% 5. CHANNEL BIT ERRORS BEFORE DECODING

packetChannelErrors = nnz( ...
    txCodedBits(:) ~= cRxBits(:));

cChannelErrors = cChannelErrors + packetChannelErrors;

        %% 6. CODEWORD ERROR COUNT BEFORE DECODING

        txCodeMatrix = reshape(txCodedBits,7,[]);
        rxCodeMatrix = reshape(cRxBits,7,[]);

        channelErrorsPerWord = ...
            sum(txCodeMatrix ~= rxCodeMatrix,1);

        codewordErrorFlags = channelErrorsPerWord > 0;

        totalCodewordErrors = totalCodewordErrors + ...
            sum(codewordErrorFlags);

        %% 7. HAMMING DECODER

        [decodedPacket,~,errorPositions] = ...
            hamming74_decoder(cRxBits);

        decodedPacket = decodedPacket(:).';

        if numel(decodedPacket) ~= packetLength

            error('Decoded packet length mismatch.');

        end

        %% 8. DECODER CORRECTION ATTEMPTS

        correctionAttempts = sum(errorPositions(:) > 0);

        totalCorrectionAttempts = ...
            totalCorrectionAttempts + correctionAttempts;

        %% 9. SINGLE-BIT CORRECTION SUCCESS

        txInfoMatrix = reshape(txPacket,4,[]);

        decodedInfoMatrix = reshape(decodedPacket,4,[]);

        decodedWordErrors = any( ...
            txInfoMatrix ~= decodedInfoMatrix,1);

        singleErrorWords = channelErrorsPerWord == 1;

        totalSingleErrorWords = totalSingleErrorWords + ...
            sum(singleErrorWords);

        successfulSingleCorrections = ...
            singleErrorWords & ~decodedWordErrors;

        totalSuccessfulSingleCorrections = ...
            totalSuccessfulSingleCorrections + ...
            sum(successfulSingleCorrections);

        %% 10. CRC VERIFICATION AFTER DECODING

        [cRxPayload,cCRCOK] = ...
            verify_crc16(decodedPacket);

        %% 11. PAYLOAD ERRORS AFTER DECODING

        cBitErrors = sum(payloadBits ~= cRxPayload);

        cPayloadErrors = cPayloadErrors + cBitErrors;

        cPacketError = (cBitErrors > 0);

        %% 12. PACKET CLASSIFICATION

        if cPacketError

            cPacketErrors = cPacketErrors + 1;

        end

        if ~cCRCOK

            cCRCFailures = cCRCFailures + 1;

        end

        if cPacketError && ~cCRCOK

            cDetected = cDetected + 1;

        elseif cPacketError && cCRCOK

            cUndetected = cUndetected + 1;

        elseif ~cPacketError && ~cCRCOK

            cCRCOnly = cCRCOnly + 1;

        end

    end

    %% =========================================
    % PERFORMANCE METRICS
    %% =========================================

    totalPayloadBits = numPackets*payloadLength;
    totalPacketBits = numPackets*packetLength;
    totalCodedBits = numPackets*codedBitsPerPacket;

    %% A. UNCODED METRICS

    ucBER = ucPayloadErrors/totalPayloadBits;

    ucChannelBER = ucChannelErrors/totalPacketBits;

    ucPER = ucPacketErrors/numPackets;

    ucCRCFailure = ucCRCFailures/numPackets;

    ucDetectedRate = ucDetected/numPackets;

    ucUndetectedRate = ucUndetected/numPackets;

    ucCRCOnlyRate = ucCRCOnly/numPackets;

    %% B. CODED METRICS

    cBER = cPayloadErrors/totalPayloadBits;

    cChannelBER = cChannelErrors/totalCodedBits;

    cPER = cPacketErrors/numPackets;

    cCRCFailure = cCRCFailures/numPackets;

    cDetectedRate = cDetected/numPackets;

    cUndetectedRate = cUndetected/numPackets;

    cCRCOnlyRate = cCRCOnly/numPackets;

    %% C. HAMMING METRICS

    cCodewordErrorRate = ...
        totalCodewordErrors/(numPackets*codewordsPerPacket);

    correctionAttemptRate = ...
        totalCorrectionAttempts/(numPackets*codewordsPerPacket);

    if totalSingleErrorWords > 0

        singleCorrectionSuccess = ...
            totalSuccessfulSingleCorrections/totalSingleErrorWords;

    else

        singleCorrectionSuccess = NaN;

    end

    %% D. PAYLOAD GROSS THROUGHPUT

    % Includes CRC overhead and FEC overhead in transmission time.
    % Excludes both overheads from delivered information rate.

    ucGrossPayloadRate = ...
        symbolRate*(payloadLength/packetLength);

    cGrossPayloadRate = ...
        symbolRate*codeRate*(payloadLength/packetLength);

    %% E. CRC-ACCEPTED PAYLOAD THROUGHPUT

    ucAcceptedRate = ucGrossPayloadRate* ...
        (numPackets-ucCRCFailures)/numPackets;

    cAcceptedRate = cGrossPayloadRate* ...
        (numPackets-cCRCFailures)/numPackets;

    %% F. CORRECT PAYLOAD GOODPUT

    % Exclude corrupted payload packets and CRC-only rejected packets.
    % Undetected errors are included in PacketErrors.

    ucGoodPackets = ...
        numPackets-ucPacketErrors-ucCRCOnly;

    cGoodPackets = ...
        numPackets-cPacketErrors-cCRCOnly;

    ucGoodput = ucGrossPayloadRate* ...
        ucGoodPackets/numPackets;

    cGoodput = cGrossPayloadRate* ...
        cGoodPackets/numPackets;

    %% G. THEORETICAL BER

    gamma = 10^(currentEbN0/10);

    ucTheory = 0.5*erfc(sqrt(gamma));

    cChannelTheory = ...
        0.5*erfc(sqrt(codeRate*gamma));

    cPayloadTheory = ...
        theoretical_hamming74_ber(currentEbN0,codeRate);

    %% H. SAVE UNCODED RESULTS

    UncodedPayloadBER(snrIndex) = ucBER;
    UncodedChannelBER(snrIndex) = ucChannelBER;
    UncodedPER(snrIndex) = ucPER;
    UncodedCRCFailureRate(snrIndex) = ucCRCFailure;

    UncodedDetectedPER(snrIndex) = ucDetectedRate;
    UncodedUndetectedPER(snrIndex) = ucUndetectedRate;
    UncodedCRCOnlyFailureRate(snrIndex) = ucCRCOnlyRate;

    UncodedPacketErrors(snrIndex) = ucPacketErrors;
    UncodedCRCFailures(snrIndex) = ucCRCFailures;
    UncodedDetectedErrors(snrIndex) = ucDetected;
    UncodedUndetectedErrors(snrIndex) = ucUndetected;
    UncodedCRCOnlyFailures(snrIndex) = ucCRCOnly;

    %% I. SAVE CODED RESULTS

    CodedPayloadBER(snrIndex) = cBER;
    CodedChannelBER(snrIndex) = cChannelBER;
    CodedPER(snrIndex) = cPER;
    CodedCRCFailureRate(snrIndex) = cCRCFailure;

    CodedDetectedPER(snrIndex) = cDetectedRate;
    CodedUndetectedPER(snrIndex) = cUndetectedRate;
    CodedCRCOnlyFailureRate(snrIndex) = cCRCOnlyRate;

    CodedPacketErrors(snrIndex) = cPacketErrors;
    CodedCRCFailures(snrIndex) = cCRCFailures;
    CodedDetectedErrors(snrIndex) = cDetected;
    CodedUndetectedErrors(snrIndex) = cUndetected;
    CodedCRCOnlyFailures(snrIndex) = cCRCOnly;

    CodewordErrorRate(snrIndex) = cCodewordErrorRate;
    DecoderCorrectionAttemptRate(snrIndex) = correctionAttemptRate;

    SingleErrorCorrectionSuccessRate(snrIndex) = ...
        singleCorrectionSuccess;

    %% J. SAVE THROUGHPUT

    UncodedPayloadGrossRate(snrIndex) = ucGrossPayloadRate;
    CodedPayloadGrossRate(snrIndex) = cGrossPayloadRate;

    UncodedCRCAcceptedRate(snrIndex) = ucAcceptedRate;
    CodedCRCAcceptedRate(snrIndex) = cAcceptedRate;

    UncodedGoodput(snrIndex) = ucGoodput;
    CodedGoodput(snrIndex) = cGoodput;

    %% K. SAVE THEORY

    UncodedTheory(snrIndex) = ucTheory;
    CodedChannelTheory(snrIndex) = cChannelTheory;
    CodedPayloadTheory(snrIndex) = cPayloadTheory;

    %% =========================================
    % DISPLAY RESULTS
    %% =========================================

    fprintf('\nUNCODED BPSK + CRC:\n');

    fprintf('Payload BER: %.8e\n',ucBER);
    fprintf('Channel BER: %.8e\n',ucChannelBER);
    fprintf('PER: %.8e\n',ucPER);
    fprintf('CRC Failure Rate: %.8e\n',ucCRCFailure);
    fprintf('Detected Errors: %d\n',ucDetected);
    fprintf('Undetected Errors: %d\n',ucUndetected);
    fprintf('CRC-only Failures: %d\n',ucCRCOnly);
    fprintf('Correct Payload Goodput: %.6f Mbps\n',ucGoodput/1e6);

    fprintf('\nCRC + HAMMING + BPSK:\n');

    fprintf('Payload BER: %.8e\n',cBER);
    fprintf('Coded Channel BER: %.8e\n',cChannelBER);
    fprintf('PER: %.8e\n',cPER);
    fprintf('CRC Failure Rate: %.8e\n',cCRCFailure);

    fprintf('Detected Errors: %d\n',cDetected);
    fprintf('Undetected Errors: %d\n',cUndetected);
    fprintf('CRC-only Failures: %d\n',cCRCOnly);

    fprintf('Codeword Error Rate: %.8e\n',cCodewordErrorRate);

    fprintf('Decoder Correction Attempt Rate: %.8e\n', ...
        correctionAttemptRate);

    fprintf('Single-bit Correction Success Rate: %.8e\n', ...
        singleCorrectionSuccess);

    fprintf('Correct Payload Goodput: %.6f Mbps\n',cGoodput/1e6);

    fprintf('\nTHEORETICAL REFERENCE:\n');

    fprintf('Uncoded BPSK BER: %.8e\n',ucTheory);
    fprintf('Coded Channel BER: %.8e\n',cChannelTheory);
    fprintf('Decoded Hamming BER: %.8e\n',cPayloadTheory);

end

%% 5. CREATE COMPARISON TABLE

System = [ ...
    repmat("Uncoded BPSK + CRC",numSNR,1); ...
    repmat("BPSK + Hamming + CRC",numSNR,1)];

EbN0 = [EbN0_dB(:); EbN0_dB(:)];

PayloadBER = [UncodedPayloadBER; CodedPayloadBER];

ChannelBER = [UncodedChannelBER; CodedChannelBER];

PER = [UncodedPER; CodedPER];

CRCFailureRate = [ ...
    UncodedCRCFailureRate; CodedCRCFailureRate];

DetectedPER = [UncodedDetectedPER; CodedDetectedPER];

UndetectedPER = [ ...
    UncodedUndetectedPER; CodedUndetectedPER];

CRCOnlyFailureRate = [ ...
    UncodedCRCOnlyFailureRate; CodedCRCOnlyFailureRate];

PacketErrors = [UncodedPacketErrors; CodedPacketErrors];

CRCFailures = [UncodedCRCFailures; CodedCRCFailures];

DetectedErrors = [UncodedDetectedErrors; CodedDetectedErrors];

UndetectedErrors = [ ...
    UncodedUndetectedErrors; CodedUndetectedErrors];

CRCOnlyFailures = [ ...
    UncodedCRCOnlyFailures; CodedCRCOnlyFailures];

PayloadGrossThroughput = [ ...
    UncodedPayloadGrossRate; CodedPayloadGrossRate];

CRCAcceptedThroughput = [ ...
    UncodedCRCAcceptedRate; CodedCRCAcceptedRate];

CorrectPayloadGoodput = [UncodedGoodput; CodedGoodput];

resultsTable = table( ...
    System, ...
    EbN0, ...
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
    PayloadGrossThroughput, ...
    CRCAcceptedThroughput, ...
    CorrectPayloadGoodput);

fprintf('\n');
fprintf('============================================\n');
fprintf('FINAL CRC + HAMMING PERFORMANCE SUMMARY\n');
fprintf('============================================\n');

disp(resultsTable);

%% 6. HAMMING PERFORMANCE TABLE

hammingTable = table( ...
    EbN0_dB(:), ...
    CodewordErrorRate, ...
    DecoderCorrectionAttemptRate, ...
    SingleErrorCorrectionSuccessRate, ...
    CodedChannelBER, ...
    CodedPayloadBER, ...
    CodedPayloadTheory, ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'CodewordErrorRate', ...
    'CorrectionAttemptRate', ...
    'SingleErrorSuccessRate', ...
    'CodedChannelBER', ...
    'DecodedPayloadBER', ...
    'TheoreticalDecodedBER'});

fprintf('\n');
fprintf('============================================\n');
fprintf('HAMMING DECODER PERFORMANCE\n');
fprintf('============================================\n');

disp(hammingTable);

%% 7. SAVE RESULTS

resultsFolder = fullfile(projectRoot,'results');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

writetable(resultsTable, ...
    fullfile(resultsFolder,'crc_hamming_packet_summary.csv'));

writetable(hammingTable, ...
    fullfile(resultsFolder,'hamming_decoder_packet_summary.csv'));

save(fullfile(resultsFolder,'crc_hamming_packet_results.mat'), ...
    'resultsTable','hammingTable','EbN0_dB', ...
    'payloadLength','crcLength','packetLength', ...
    'numPackets','codeRate');

fprintf('\nAll tables saved successfully.\n');

%% 8. PLOT PAYLOAD BER

figure;

semilogy(EbN0_dB, ...
    max(UncodedPayloadBER,0.5/(numPackets*payloadLength)), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB, ...
    max(CodedPayloadBER,0.5/(numPackets*payloadLength)), ...
    '-s','LineWidth',1.5);

semilogy(EbN0_dB,UncodedTheory, ...
    '--','LineWidth',1.5);

semilogy(EbN0_dB,CodedPayloadTheory, ...
    ':','LineWidth',1.8);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('Payload BER');

title('CRC + Hamming: Payload BER Performance');

legend( ...
    'Uncoded + CRC Simulation', ...
    'Hamming + CRC Simulation', ...
    'Uncoded BPSK Theory', ...
    'Hamming Theory', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'crc_hamming_payload_ber.png'));

%% 9. PLOT PER

figure;

semilogy(EbN0_dB, ...
    max(UncodedPER,0.5/numPackets), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB, ...
    max(CodedPER,0.5/numPackets), ...
    '-s','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('Packet Error Rate');

title('Packet Error Rate: Uncoded vs Hamming');

legend( ...
    'Uncoded + CRC', ...
    'Hamming + CRC', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'crc_hamming_per.png'));

%% 10. PLOT CRC FAILURE RATE

figure;

semilogy(EbN0_dB, ...
    max(UncodedCRCFailureRate,0.5/numPackets), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB, ...
    max(CodedCRCFailureRate,0.5/numPackets), ...
    '-s','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('CRC Failure Rate');

title('CRC Failure Rate');

legend( ...
    'Uncoded + CRC', ...
    'Hamming + CRC', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'crc_hamming_failure_rate.png'));

%% 11. PLOT CORRECT PAYLOAD GOODPUT

figure;

plot(EbN0_dB,UncodedGoodput/1e6, ...
    '-o','LineWidth',1.5);

hold on;

plot(EbN0_dB,CodedGoodput/1e6, ...
    '-s','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('Correct Payload Goodput (Mbps)');

title('CRC + Hamming Goodput Comparison');

legend( ...
    'Uncoded BPSK + CRC', ...
    'Hamming (7,4) + CRC', ...
    'Location','southeast');

saveas(gcf, ...
    fullfile(resultsFolder,'crc_hamming_goodput.png'));

%% 12. PLOT CHANNEL BER AND DECODER BER

figure;

semilogy(EbN0_dB, ...
    max(CodedChannelBER,0.5/(numPackets*codedBitsPerPacket)), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB, ...
    max(CodedPayloadBER,0.5/(numPackets*payloadLength)), ...
    '-s','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('BER');

title('Hamming: Before and After Decoding');

legend( ...
    'Coded Channel BER', ...
    'Decoded Payload BER', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'hamming_before_after_decoding.png'));

%% 13. FINAL VALIDATION

% Packet error classification

assert(all(UncodedPacketErrors == ...
    UncodedDetectedErrors + UncodedUndetectedErrors));

assert(all(CodedPacketErrors == ...
    CodedDetectedErrors + CodedUndetectedErrors));

% CRC failure classification

assert(all(UncodedCRCFailures == ...
    UncodedDetectedErrors + UncodedCRCOnlyFailures));

assert(all(CodedCRCFailures == ...
    CodedDetectedErrors + CodedCRCOnlyFailures));

% Packet count classification

assert(all(UncodedDetectedErrors + ...
    UncodedUndetectedErrors + ...
    UncodedCRCOnlyFailures <= numPackets));

assert(all(CodedDetectedErrors + ...
    CodedUndetectedErrors + ...
    CodedCRCOnlyFailures <= numPackets));

% Metric ranges

assert(all(UncodedPayloadBER >= 0 & UncodedPayloadBER <= 1));

assert(all(CodedPayloadBER >= 0 & CodedPayloadBER <= 1));

assert(all(UncodedPER >= 0 & UncodedPER <= 1));

assert(all(CodedPER >= 0 & CodedPER <= 1));

assert(all(UncodedCRCFailureRate >= 0 & UncodedCRCFailureRate <= 1));

assert(all(CodedCRCFailureRate >= 0 & CodedCRCFailureRate <= 1));

% Goodput validation

assert(all(UncodedGoodput >= 0));

assert(all(CodedGoodput >= 0));

assert(all(UncodedGoodput <= UncodedPayloadGrossRate + eps));

assert(all(CodedGoodput <= CodedPayloadGrossRate + eps));

% Correction metrics

assert(all(CodewordErrorRate >= 0 & CodewordErrorRate <= 1));

assert(all(DecoderCorrectionAttemptRate >= 0 & ...
    DecoderCorrectionAttemptRate <= 1));

validSuccessRates = SingleErrorCorrectionSuccessRate( ...
    ~isnan(SingleErrorCorrectionSuccessRate));

assert(all(validSuccessRates >= 0 & validSuccessRates <= 1));

fprintf('\n');
fprintf('============================================\n');
fprintf('FINAL VALIDATION PASSED\n');
fprintf('============================================\n');

fprintf('Uncoded packet classification: PASSED\n');
fprintf('Coded packet classification: PASSED\n');
fprintf('CRC failure classification: PASSED\n');
fprintf('Packet count validation: PASSED\n');
fprintf('BER/PER validation: PASSED\n');
fprintf('Goodput validation: PASSED\n');
fprintf('Hamming correction metrics: PASSED\n');

fprintf('\nAll CRC + Hamming results saved successfully.\n');

fprintf('Results directory: %s\n',resultsFolder);

fprintf('\nMILESTONE 21 COMPLETED.\n');


%% =========================================================
% LOCAL FUNCTION
% THEORETICAL HAMMING (7,4) HARD-DECISION BER
%% =========================================================

function ber = theoretical_hamming74_ber(EbN0_dB,codeRate)

    H = hamming74_parity_check_matrix();

    gamma = 10^(EbN0_dB/10);

    p = 0.5*erfc(sqrt(codeRate*gamma));

    errorPatterns = dec2bin(0:127,7)-'0';

    ber = 0;

    for k = 1:size(errorPatterns,1)

        errorVector = errorPatterns(k,:).';

        errorWeight = sum(errorVector);

        syndrome = mod(H*errorVector,2);

        correctedError = errorVector;

        if any(syndrome)

            position = find( ...
                all(bsxfun(@eq,H,syndrome),1), ...
                1,'first');

            if isempty(position)
                error('Invalid syndrome.');
            end

            correctedError(position) = ...
                1-correctedError(position);

        end

        informationErrors = sum(correctedError(1:4));

        patternProbability = ...
            p^errorWeight*(1-p)^(7-errorWeight);

        ber = ber + ...
            (informationErrors/4)*patternProbability;

    end

end
