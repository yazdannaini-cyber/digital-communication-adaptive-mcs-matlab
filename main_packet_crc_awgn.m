clc;
clear;
close all;

%% =========================================================
% PACKET-LEVEL DIGITAL COMMUNICATION SIMULATION
%
% Modulations:
%   BPSK, QPSK, 16-QAM
%
% Channel:
%   AWGN
%
% Error detection:
%   CRC-16/CCITT-FALSE
%
% Metrics:
%   Payload BER
%   Packet Error Rate (PER)
%   CRC Failure Rate
%   Detected Packet Error Rate
%   Undetected Packet Error Rate
%   CRC-only Failure Rate
%   Payload Gross Throughput
%   CRC-Accepted Payload Throughput
%   Correct Payload Goodput
%
% Definitions:
%   PER = packets with at least one payload bit error / all packets
%
%   CRC Failure Rate = packets rejected by CRC / all packets
%
%   CRC-only failure = payload has no bit error, but CRC check fails
%
%   Undetected error = payload is corrupted, but CRC check passes
%
%   Correct Payload Goodput excludes both corrupted payload packets
%   and CRC-only rejected packets.
%% =========================================================

%% 1. PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

rng(42,'twister');

%% 2. SIMULATION CONFIGURATION

payloadLength = 1024;
crcLength = 16;
packetLength = payloadLength + crcLength;

numPackets = 5000;
EbN0_dB = 0:2:14;

modulations = {'BPSK','QPSK','16-QAM'};
numModulations = numel(modulations);
numSNR = numel(EbN0_dB);

symbolRate = 1e6;       % symbols/second

% Raised-cosine rolloff is not used in the bit-rate calculation below.
% symbolRate is assumed to be the actual transmitted symbol rate.

fprintf('\n');
fprintf('============================================\n');
fprintf('PACKET-LEVEL CRC PERFORMANCE ANALYSIS\n');
fprintf('============================================\n');
fprintf('Payload length: %d bits\n',payloadLength);
fprintf('CRC length: %d bits\n',crcLength);
fprintf('Packet length: %d bits\n',packetLength);
fprintf('Number of packets: %d\n',numPackets);
fprintf('SNR range: %g to %g dB\n',EbN0_dB(1),EbN0_dB(end));
fprintf('Channel: AWGN\n');
fprintf('CRC: CRC-16/CCITT-FALSE\n');

%% 3. PREALLOCATE RESULTS

totalResults = numModulations*numSNR;

Modulation = strings(totalResults,1);
EbN0 = zeros(totalResults,1);

PayloadBER = zeros(totalResults,1);
PER = zeros(totalResults,1);
CRCFailureRate = zeros(totalResults,1);
DetectedPacketErrorRate = zeros(totalResults,1);
UndetectedPacketErrorRate = zeros(totalResults,1);
CRCOnlyFailureRate = zeros(totalResults,1);

PacketErrors = zeros(totalResults,1);
CRCFailures = zeros(totalResults,1);
DetectedErrors = zeros(totalResults,1);
UndetectedErrors = zeros(totalResults,1);
CRCOnlyFailures = zeros(totalResults,1);

AverageBitsPerSymbol = zeros(totalResults,1);
GrossThroughput_bps = zeros(totalResults,1);
PayloadGrossThroughput_bps = zeros(totalResults,1);
CRCAcceptedPayloadThroughput_bps = zeros(totalResults,1);
CorrectPayloadGoodput_bps = zeros(totalResults,1);
BitLevelEstimatedPayloadRate_bps = zeros(totalResults,1);

%% 4. MAIN SIMULATION

resultIndex = 0;

for modIndex = 1:numModulations

    modulationType = modulations{modIndex};

    %% Bits per Symbol
    switch modulationType
        case 'BPSK'
            bitsPerSymbol = 1;
        case 'QPSK'
            bitsPerSymbol = 2;
        case '16-QAM'
            bitsPerSymbol = 4;
        otherwise
            error('Unsupported modulation type: %s',modulationType);
    end

    if mod(packetLength,bitsPerSymbol) ~= 0
        error('Packet length must be divisible by bits per symbol.');
    end

    symbolsPerPacket = packetLength/bitsPerSymbol;

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('MODULATION: %s\n',modulationType);
    fprintf('============================================\n');
    fprintf('Bits per symbol: %d\n',bitsPerSymbol);
    fprintf('Symbols per packet: %d\n',symbolsPerPacket);

    for snrIndex = 1:numSNR

        currentEbN0 = EbN0_dB(snrIndex);

        %% Error counters
        totalPayloadBitErrors = 0;
        totalPacketErrors = 0;
        totalCRCFailures = 0;
        totalDetectedErrors = 0;
        totalUndetectedErrors = 0;
        totalCRCOnlyFailures = 0;

        packetErrorFlags = false(1,numPackets);

        %% Packet transmission loop
        for packetIndex = 1:numPackets

            % 1. Generate information payload
            payloadBits = generate_bits(payloadLength);

            % 2. Append CRC-16
            txPacket = append_crc16(payloadBits);

            if numel(txPacket) ~= packetLength
                error('Transmitted packet length mismatch.');
            end

            % 3. Modulation
            switch modulationType
                case 'BPSK'
                    txSymbols = bpsk_modulator(txPacket);
                case 'QPSK'
                    txSymbols = qpsk_modulator(txPacket);
                case '16-QAM'
                    txSymbols = qam16_modulator(txPacket);
            end

            if numel(txSymbols) ~= symbolsPerPacket
                error('Modulated packet length mismatch.');
            end

            % 4. AWGN channel
            % The channel function uses Eb/N0 and the normalized
            % average symbol energy Es = 1.
            rxSymbols = awgn_channel( ...
                txSymbols,currentEbN0,bitsPerSymbol,1);

            % 5. Demodulation
            switch modulationType
                case 'BPSK'
                    rxPacket = bpsk_demodulator(rxSymbols);
                case 'QPSK'
                    rxPacket = qpsk_demodulator(rxSymbols);
                case '16-QAM'
                    rxPacket = qam16_demodulator(rxSymbols);
            end

            rxPacket = double(rxPacket(:).');

            if numel(rxPacket) ~= packetLength
                error('Received packet length mismatch.');
            end

            % 6. Extract received payload and measure payload errors
            rxPayload = rxPacket(1:payloadLength);
            bitErrors = sum(payloadBits ~= rxPayload);
            totalPayloadBitErrors = totalPayloadBitErrors + bitErrors;

            % 7. Define packet error using payload corruption
            packetError = (bitErrors > 0);
            packetErrorFlags(packetIndex) = packetError;

            if packetError
                totalPacketErrors = totalPacketErrors + 1;
            end

            % 8. Verify received CRC
            [~,crcOK] = verify_crc16(rxPacket);

            if ~crcOK
                totalCRCFailures = totalCRCFailures + 1;
            end

            % 9. Classify each packet into exactly one of four cases
            if packetError && ~crcOK
                % Corrupted payload; CRC detects the error.
                totalDetectedErrors = totalDetectedErrors + 1;

            elseif packetError && crcOK
                % Corrupted payload; CRC fails to detect the error.
                totalUndetectedErrors = totalUndetectedErrors + 1;

            elseif ~packetError && ~crcOK
                % Payload is correct, but the received CRC field is wrong.
                totalCRCOnlyFailures = totalCRCOnlyFailures + 1;
            end

        end % packet loop

        %% 5. PERFORMANCE METRICS

        totalPayloadBits = numPackets*payloadLength;

        payloadBER = totalPayloadBitErrors/totalPayloadBits;
        per = totalPacketErrors/numPackets;
        crcFailureRate = totalCRCFailures/numPackets;
        detectedRate = totalDetectedErrors/numPackets;
        undetectedRate = totalUndetectedErrors/numPackets;
        crcOnlyFailureRate = totalCRCOnlyFailures/numPackets;

        %% 6. THROUGHPUT METRICS

        % Gross physical bit rate includes payload and CRC bits.
        grossBitRate = symbolRate*bitsPerSymbol;

        % Useful payload rate excludes the CRC overhead.
        payloadGrossBitRate = grossBitRate * ...
            (payloadLength/packetLength);

        % Payload rate in packets accepted by the CRC.
        % This rate can include undetected corrupted packets.
        % Use integer packet counts before division. This avoids a tiny
        % negative goodput caused by floating-point rounding when PER and
        % CRC-only failure rate sum mathematically to exactly one.
        crcAcceptedPacketCount = numPackets - totalCRCFailures;
        crcAcceptedPayloadRate = payloadGrossBitRate * ...
            (crcAcceptedPacketCount/numPackets);

        % Correctly delivered payload goodput excludes:
        % (1) all packets with payload errors, including undetected errors;
        % (2) packets with correct payload but corrupted CRC.
        % PacketErrors and CRCOnlyFailures are disjoint categories.
        correctPayloadPacketCount = numPackets - ...
            totalPacketErrors - totalCRCOnlyFailures;

        if correctPayloadPacketCount < 0
            error('Invalid packet counts: correct payload packet count is negative.');
        end

        correctPayloadGoodput = payloadGrossBitRate * ...
            (correctPayloadPacketCount/numPackets);

        % Bit-level estimate, retained only as a comparison metric.
        % It is not packet-delivery goodput.
        bitLevelEstimatedPayloadRate = payloadGrossBitRate * ...
            (1-payloadBER);

        %% 7. STORE RESULTS

        resultIndex = resultIndex+1;

        Modulation(resultIndex) = string(modulationType);
        EbN0(resultIndex) = currentEbN0;

        PayloadBER(resultIndex) = payloadBER;
        PER(resultIndex) = per;
        CRCFailureRate(resultIndex) = crcFailureRate;
        DetectedPacketErrorRate(resultIndex) = detectedRate;
        UndetectedPacketErrorRate(resultIndex) = undetectedRate;
        CRCOnlyFailureRate(resultIndex) = crcOnlyFailureRate;

        PacketErrors(resultIndex) = totalPacketErrors;
        CRCFailures(resultIndex) = totalCRCFailures;
        DetectedErrors(resultIndex) = totalDetectedErrors;
        UndetectedErrors(resultIndex) = totalUndetectedErrors;
        CRCOnlyFailures(resultIndex) = totalCRCOnlyFailures;

        AverageBitsPerSymbol(resultIndex) = bitsPerSymbol;
        GrossThroughput_bps(resultIndex) = grossBitRate;
        PayloadGrossThroughput_bps(resultIndex) = payloadGrossBitRate;
        CRCAcceptedPayloadThroughput_bps(resultIndex) = ...
            crcAcceptedPayloadRate;
        CorrectPayloadGoodput_bps(resultIndex) = ...
            correctPayloadGoodput;
        BitLevelEstimatedPayloadRate_bps(resultIndex) = ...
            bitLevelEstimatedPayloadRate;

        %% 8. PRINT CURRENT RESULTS

        fprintf('\n');
        fprintf('--------------------------------------------\n');
        fprintf('Eb/N0 = %.1f dB\n',currentEbN0);
        fprintf('Payload BER: %.8e\n',payloadBER);
        fprintf('PER: %.8e\n',per);
        fprintf('CRC Failure Rate: %.8e\n',crcFailureRate);
        fprintf('Detected Packet Error Rate: %.8e\n',detectedRate);
        fprintf('Undetected Packet Error Rate: %.8e\n',undetectedRate);
        fprintf('CRC Only Failure Rate: %.8e\n',crcOnlyFailureRate);

        fprintf('Packet Errors: %d / %d\n', ...
            totalPacketErrors,numPackets);
        fprintf('CRC Failures: %d / %d\n', ...
            totalCRCFailures,numPackets);
        fprintf('Detected Errors: %d\n',totalDetectedErrors);
        fprintf('Undetected Errors: %d\n',totalUndetectedErrors);
        fprintf('CRC-only Failures: %d\n',totalCRCOnlyFailures);

        fprintf('Gross Throughput: %.6f Mbps\n',grossBitRate/1e6);
        fprintf('Payload Gross Throughput: %.6f Mbps\n', ...
            payloadGrossBitRate/1e6);
        fprintf('CRC-Accepted Payload Throughput: %.6f Mbps\n', ...
            crcAcceptedPayloadRate/1e6);
        fprintf('Correct Payload Goodput: %.6f Mbps\n', ...
            correctPayloadGoodput/1e6);
        fprintf('Bit-Level Estimated Payload Rate: %.6f Mbps\n', ...
            bitLevelEstimatedPayloadRate/1e6);

    end % SNR loop
end % modulation loop

%% 9. CREATE RESULTS TABLE

resultsTable = table( ...
    Modulation, ...
    EbN0, ...
    PayloadBER, ...
    PER, ...
    CRCFailureRate, ...
    DetectedPacketErrorRate, ...
    UndetectedPacketErrorRate, ...
    CRCOnlyFailureRate, ...
    PacketErrors, ...
    CRCFailures, ...
    DetectedErrors, ...
    UndetectedErrors, ...
    CRCOnlyFailures, ...
    AverageBitsPerSymbol, ...
    GrossThroughput_bps, ...
    PayloadGrossThroughput_bps, ...
    CRCAcceptedPayloadThroughput_bps, ...
    CorrectPayloadGoodput_bps, ...
    BitLevelEstimatedPayloadRate_bps);

%% 10. DISPLAY RESULTS

fprintf('\n');
fprintf('============================================\n');
fprintf('FINAL PACKET PERFORMANCE SUMMARY\n');
fprintf('============================================\n');
disp(resultsTable);

%% 11. SAVE RESULTS

resultsFolder = fullfile(projectRoot,'results');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

writetable(resultsTable, ...
    fullfile(resultsFolder,'packet_crc_awgn_summary.csv'));

save(fullfile(resultsFolder,'packet_crc_awgn_results.mat'), ...
    'resultsTable','EbN0_dB','modulations','payloadLength', ...
    'crcLength','packetLength','numPackets','symbolRate');

fprintf('\nResults saved successfully.\n');

%% 12. PLOT PAYLOAD BER

figure('Name','Payload BER','Color','w');
hold on;
grid on;

for k = 1:numModulations
    selected = Modulation == string(modulations{k});
    semilogy(EbN0(selected),PayloadBER(selected), ...
        '-o','LineWidth',1.5,'MarkerSize',6);
end

xlabel('E_b/N_0 (dB)');
ylabel('Payload BER');
title('Payload BER Performance');
legend(modulations,'Location','southwest');
saveas(gcf,fullfile(resultsFolder,'packet_payload_ber.png'));

%% 13. PLOT PER

figure('Name','Packet Error Rate','Color','w');
hold on;
grid on;

for k = 1:numModulations
    selected = Modulation == string(modulations{k});
    semilogy(EbN0(selected),PER(selected), ...
        '-s','LineWidth',1.5,'MarkerSize',6);
end

xlabel('E_b/N_0 (dB)');
ylabel('Packet Error Rate');
title('Packet Error Rate Performance');
legend(modulations,'Location','southwest');
saveas(gcf,fullfile(resultsFolder,'packet_per.png'));

%% 14. PLOT CRC FAILURE RATE

figure('Name','CRC Failure Rate','Color','w');
hold on;
grid on;

for k = 1:numModulations
    selected = Modulation == string(modulations{k});
    semilogy(EbN0(selected),CRCFailureRate(selected), ...
        '-d','LineWidth',1.5,'MarkerSize',6);
end

xlabel('E_b/N_0 (dB)');
ylabel('CRC Failure Rate');
title('CRC Failure Rate Performance');
legend(modulations,'Location','southwest');
saveas(gcf,fullfile(resultsFolder,'packet_crc_failure_rate.png'));

%% 15. PLOT UNDETECTED PACKET ERROR RATE

figure('Name','Undetected Packet Error Rate','Color','w');
hold on;
grid on;

for k = 1:numModulations
    selected = Modulation == string(modulations{k});
    semilogy(EbN0(selected),UndetectedPacketErrorRate(selected), ...
        '-^','LineWidth',1.5,'MarkerSize',6);
end

xlabel('E_b/N_0 (dB)');
ylabel('Undetected Packet Error Rate');
title('Undetected Packet Error Rate Performance');
legend(modulations,'Location','southwest');
saveas(gcf,fullfile(resultsFolder,'packet_undetected_error_rate.png'));

%% 16. PLOT CORRECT PAYLOAD GOODPUT

figure('Name','Correct Payload Goodput','Color','w');
hold on;
grid on;

for k = 1:numModulations
    selected = Modulation == string(modulations{k});
    plot(EbN0(selected),CorrectPayloadGoodput_bps(selected)/1e6, ...
        '-o','LineWidth',1.5,'MarkerSize',6);
end

xlabel('E_b/N_0 (dB)');
ylabel('Correct Payload Goodput (Mbps)');
title('Correct Payload Goodput Performance');
legend(modulations,'Location','southeast');
saveas(gcf,fullfile(resultsFolder,'packet_correct_payload_goodput.png'));

%% 17. FINAL CONSISTENCY VALIDATION

% Each payload-corrupted packet is either detected or undetected.
assert(all(PacketErrors == DetectedErrors + UndetectedErrors), ...
    'Packet error classification mismatch.');

% Each CRC failure is either a detected payload error or a CRC-only failure.
assert(all(CRCFailures == DetectedErrors + CRCOnlyFailures), ...
    'CRC failure classification mismatch.');

% Every packet belongs to exactly one of the four classification cases:
% detected, undetected, CRC-only failure, or completely correct.
completelyCorrectPackets = numPackets - ...
    DetectedErrors - UndetectedErrors - CRCOnlyFailures;

assert(all(completelyCorrectPackets >= 0), ...
    'Invalid packet classification counts.');

assert(all(DetectedErrors + UndetectedErrors + ...
    CRCOnlyFailures + completelyCorrectPackets == numPackets), ...
    'Total packet classification mismatch.');

% Rate consistency checks.
assert(all(PER >= 0 & PER <= 1), 'Invalid PER values.');
assert(all(PayloadBER >= 0 & PayloadBER <= 1), ...
    'Invalid BER values.');
assert(all(CRCFailureRate >= 0 & CRCFailureRate <= 1), ...
    'Invalid CRC failure rate.');
assert(all(isfinite(CorrectPayloadGoodput_bps)), ...
    'Goodput contains NaN or Inf values.');
assert(all(CorrectPayloadGoodput_bps >= 0), ...
    'Invalid goodput values: goodput must be nonnegative.');

% Goodput must not exceed the gross payload rate.
assert(all(CorrectPayloadGoodput_bps <= ...
    PayloadGrossThroughput_bps + 1e-9), ...
    'Goodput cannot exceed payload gross throughput.');

fprintf('\n');
fprintf('============================================\n');
fprintf('FINAL VALIDATION PASSED\n');
fprintf('============================================\n');
fprintf('Packet error classification: PASSED\n');
fprintf('CRC failure classification: PASSED\n');
fprintf('Total packet classification: PASSED\n');
fprintf('PER range validation: PASSED\n');
fprintf('BER range validation: PASSED\n');
fprintf('CRC failure rate validation: PASSED\n');
fprintf('Goodput consistency validation: PASSED\n');
fprintf('\nPACKET CRC SIMULATION COMPLETED SUCCESSFULLY.\n');
fprintf('All tables and figures saved in: %s\n',resultsFolder);

