
clc;
clear;
close all;

%% =========================================================
% MILESTONE 34
% AWGN PERFORMANCE COMPARISON OF CHANNEL CODING SCHEMES
%
% Systems:
%   1. Uncoded BPSK + CRC
%   2. Convolutional + Soft Viterbi
%   3. LDPC + Normalized Min-Sum
%   4. Polar + Successive Cancellation
%
% All schemes use:
%   Payload = 48 bits
%   CRC = 16 bits
%   Information block = 64 bits
%   BPSK
%   AWGN
%
% Eb/N0 is defined per information payload bit.
%
% Normalization:
%   Total transmitted energy per packet = payloadLength
%
% Metrics:
%   BER, PER, CRC failure, undetected PER,
%   effective payload spectral efficiency,
%   LDPC convergence rate and iterations.
%% =========================================================

fprintf('\n');
fprintf('===============================================\n');
fprintf(' FEC PERFORMANCE COMPARISON OVER AWGN\n');
fprintf('===============================================\n\n');

%% 1. Project setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));
rehash;

requiredFunctions = {
    'append_crc16'
    'convolutional_encoder'
    'viterbi_decoder_soft'
    'ldpc_encoder'
    'ldpc_min_sum_decoder'
    'polar_encoder'
    'polar_sc_decoder'
    'polar_reliability_sequence'
};

for k = 1:numel(requiredFunctions)

    if exist(requiredFunctions{k},'file') ~= 2

        error('Required function not found: %s', ...
            requiredFunctions{k});

    end

end

%% 2. Simulation configuration

payloadLength = 48;

crcLength = 16;

informationLength = payloadLength + crcLength;

K = 64;

N = 128;

numPackets = 1000;

EbN0dBList = 0:2:10;

maxLDPCIterations = 20;

ldpcNormalizationFactor = 0.8;

polarDesignEbN0dB = 2;

confidenceLevel = 0.95;

randomSeed = 20261125;

rng(randomSeed,'twister');

fprintf('Payload bits           : %d\n',payloadLength);
fprintf('CRC bits               : %d\n',crcLength);
fprintf('Information block      : %d\n',informationLength);
fprintf('LDPC/Polar N            : %d\n',N);
fprintf('LDPC/Polar K            : %d\n',K);
fprintf('Packets per SNR         : %d\n',numPackets);
fprintf('Eb/N0 range             : %d to %d dB\n', ...
    EbN0dBList(1),EbN0dBList(end));

%% 3. System definitions

systemNames = {
    'Uncoded-BPSK'
    'Convolutional-Viterbi'
    'LDPC-Normalized-MinSum'
    'Polar-SC'
};

numSystems = numel(systemNames);

numSNR = numel(EbN0dBList);

%% 4. Construct Polar reliability sequence

[polarInfoIndices,polarFrozenMask,polarReliability] = ...
    polar_reliability_sequence( ...
        N,K,polarDesignEbN0dB);

assert(numel(polarInfoIndices) == K);

assert(sum(~polarFrozenMask) == K);

%% 5. Generate common payload bank

payloadBank = randi( ...
    [0 1],payloadLength,numPackets);

%% 6. Preallocate results

numRows = numSystems*numSNR;

System = strings(numRows,1);

EbN0_dB = zeros(numRows,1);

BER = zeros(numRows,1);

PER = zeros(numRows,1);

PER_Lower95 = zeros(numRows,1);

PER_Upper95 = zeros(numRows,1);

PacketErrors = zeros(numRows,1);

NumPackets = zeros(numRows,1);

CRCFailureRate = zeros(numRows,1);

CRCOnlyFailureRate = zeros(numRows,1);

UndetectedPER = zeros(numRows,1);

CRCFailures = zeros(numRows,1);

CRCOnlyFailures = zeros(numRows,1);

UndetectedErrors = zeros(numRows,1);

CodedBitsPerPacket = zeros(numRows,1);

NominalCodeRate = zeros(numRows,1);

EffectivePayloadRate = zeros(numRows,1);

EffectivePayloadSpectralEfficiency = zeros(numRows,1);

CorrectPayloadSpectralEfficiency = zeros(numRows,1);

AverageLDPCIterations = nan(numRows,1);

LDPCConvergenceRate = nan(numRows,1);

%% 7. Main simulation

rowIndex = 0;

for snrIndex = 1:numSNR

    currentEbN0dB = EbN0dBList(snrIndex);

    N0 = 10^(-currentEbN0dB/10);

    fprintf('\n');
    fprintf('===============================================\n');
    fprintf(' Eb/N0 = %2d dB\n',currentEbN0dB);
    fprintf('===============================================\n');

    for systemIndex = 1:numSystems

        currentSystem = systemNames{systemIndex};

        fprintf('\n%-25s\n',currentSystem);

        totalBitErrors = 0;

        packetErrors = 0;

        crcFailures = 0;

        crcOnlyFailures = 0;

        undetectedErrors = 0;

        ldpcIterations = zeros(numPackets,1);

        ldpcConverged = false(numPackets,1);

        %% Packet loop

        for packetIndex = 1:numPackets

            payloadBits = payloadBank(:,packetIndex);

            %% Append CRC

            packetBits = append_crc16(payloadBits);

            packetBits = double(packetBits(:));

            if numel(packetBits) ~= informationLength

                error('CRC output length must equal 64 bits.');

            end

            if any(packetBits ~= 0 & packetBits ~= 1)

                error('CRC output contains non-binary values.');

            end

            %% Encode

            switch currentSystem

                case 'Uncoded-BPSK'

                    codedBits = packetBits;

                case 'Convolutional-Viterbi'

                    codedBits = convolutional_encoder(packetBits);

                case 'LDPC-Normalized-MinSum'

                    codedBits = ldpc_encoder(packetBits,K);

                case 'Polar-SC'

                    codedBits = polar_encoder( ...
                        packetBits,polarInfoIndices,N);

                otherwise

                    error('Unsupported FEC system.');

            end

            codedBits = double(codedBits(:));

            if any(codedBits ~= 0 & codedBits ~= 1)

                error('Encoder produced non-binary values.');

            end

            %% Information-energy normalization

            numberOfCodedBits = numel(codedBits);

            symbolAmplitude = sqrt( ...
                payloadLength/numberOfCodedBits);

            %% BPSK modulation

            txSymbols = symbolAmplitude.*(1-2*codedBits);

            % Total packet energy must equal payloadLength.

            packetEnergy = sum(abs(txSymbols).^2);

            if abs(packetEnergy-payloadLength) > 1e-9

                error('Packet energy normalization failed.');

            end

            %% Real BPSK AWGN channel

            noise = sqrt(N0/2).*randn(size(txSymbols));

            rxSymbols = txSymbols+noise;

            %% Decode

            switch currentSystem

                case 'Uncoded-BPSK'

                    decodedPacket = double(rxSymbols < 0);

                case 'Convolutional-Viterbi'

                    decodedPacket = ...
                        viterbi_decoder_soft( ...
                            rxSymbols,symbolAmplitude);

                case 'LDPC-Normalized-MinSum'

                    % Positive LLR favors bit zero.

                    channelLLR = ...
                        4*symbolAmplitude.*rxSymbols/N0;

                    [decodedPacket,~,decoderInfo] = ...
                        ldpc_min_sum_decoder( ...
                            channelLLR, ...
                            maxLDPCIterations, ...
                            ldpcNormalizationFactor, ...
                            K);

                    ldpcIterations(packetIndex) = ...
                        decoderInfo.Iterations(1);

                    ldpcConverged(packetIndex) = ...
                        decoderInfo.Converged(1);

                case 'Polar-SC'

                    channelLLR = ...
                        4*symbolAmplitude.*rxSymbols/N0;

                    decodedPacket = ...
                        polar_sc_decoder( ...
                            channelLLR,polarFrozenMask);

            end

            decodedPacket = double(decodedPacket(:));

            %% Validate decoder output

            if numel(decodedPacket) ~= informationLength

                error(['%s returned %d bits instead of %d. ', ...
                    'Check decoder termination and output length.'], ...
                    currentSystem, ...
                    numel(decodedPacket), ...
                    informationLength);

            end

            %% Extract payload

            decodedPayload = decodedPacket(1:payloadLength);

            %% Payload errors

            bitErrors = sum(decodedPayload ~= payloadBits);

            packetError = bitErrors > 0;

            %% CRC verification

            expectedPacket = ...
                append_crc16(decodedPayload);

            expectedPacket = double(expectedPacket(:));

            crcValid = isequal(expectedPacket,decodedPacket);

            crcFailure = ~crcValid;

            crcOnlyFailure = ~packetError && crcFailure;

            undetectedError = packetError && crcValid;

            %% Accumulate results

            totalBitErrors = totalBitErrors+bitErrors;

            packetErrors = packetErrors+double(packetError);

            crcFailures = crcFailures+double(crcFailure);

            crcOnlyFailures = ...
                crcOnlyFailures+double(crcOnlyFailure);

            undetectedErrors = ...
                undetectedErrors+double(undetectedError);

        end

        %% Calculate performance metrics

        measuredBER = ...
            totalBitErrors/(payloadLength*numPackets);

        measuredPER = packetErrors/numPackets;

        [perLower,perUpper] = ...
            local_wilson(packetErrors,numPackets);

        %% Save one result row

        rowIndex = rowIndex+1;

        System(rowIndex) = string(currentSystem);

        EbN0_dB(rowIndex) = currentEbN0dB;

        BER(rowIndex) = measuredBER;

        PER(rowIndex) = measuredPER;

        PER_Lower95(rowIndex) = perLower;

        PER_Upper95(rowIndex) = perUpper;

        PacketErrors(rowIndex) = packetErrors;

        NumPackets(rowIndex) = numPackets;

        CRCFailureRate(rowIndex) = crcFailures/numPackets;

        CRCOnlyFailureRate(rowIndex) = ...
            crcOnlyFailures/numPackets;

        UndetectedPER(rowIndex) = ...
            undetectedErrors/numPackets;

        CRCFailures(rowIndex) = crcFailures;

        CRCOnlyFailures(rowIndex) = crcOnlyFailures;

        UndetectedErrors(rowIndex) = undetectedErrors;

        CodedBitsPerPacket(rowIndex) = numberOfCodedBits;

        NominalCodeRate(rowIndex) = ...
            informationLength/numberOfCodedBits;

        EffectivePayloadRate(rowIndex) = ...
            payloadLength/numberOfCodedBits;

        EffectivePayloadSpectralEfficiency(rowIndex) = ...
            EffectivePayloadRate(rowIndex);

        CorrectPayloadSpectralEfficiency(rowIndex) = ...
            EffectivePayloadRate(rowIndex)*(1-measuredPER);

        if strcmp(currentSystem,'LDPC-Normalized-MinSum')

            AverageLDPCIterations(rowIndex) = ...
                mean(ldpcIterations);

            LDPCConvergenceRate(rowIndex) = ...
                mean(ldpcConverged);

        end

        %% Progress display

        fprintf(['BER = %.4e | PER = %.4f | ', ...
            'PER Upper95 = %.4f | CRC failure = %.4f\n'], ...
            measuredBER, ...
            measuredPER, ...
            perUpper, ...
            CRCFailureRate(rowIndex));

        if strcmp(currentSystem,'LDPC-Normalized-MinSum')

            fprintf('Mean iterations = %.2f | Convergence rate = %.4f\n', ...
                AverageLDPCIterations(rowIndex), ...
                LDPCConvergenceRate(rowIndex));

        end

    end

end

%% 8. Construct final results table

FECResults = table( ...
    System, ...
    EbN0_dB, ...
    BER, ...
    PER, ...
    PER_Lower95, ...
    PER_Upper95, ...
    PacketErrors, ...
    NumPackets, ...
    CRCFailureRate, ...
    CRCOnlyFailureRate, ...
    UndetectedPER, ...
    CRCFailures, ...
    CRCOnlyFailures, ...
    UndetectedErrors, ...
    CodedBitsPerPacket, ...
    NominalCodeRate, ...
    EffectivePayloadRate, ...
    EffectivePayloadSpectralEfficiency, ...
    CorrectPayloadSpectralEfficiency, ...
    AverageLDPCIterations, ...
    LDPCConvergenceRate);

%% 9. Configuration metadata

fecConfig = struct();

fecConfig.PayloadLength = payloadLength;

fecConfig.CRCLength = crcLength;

fecConfig.InformationLength = informationLength;

fecConfig.LDPC_N = N;

fecConfig.LDPC_K = K;

fecConfig.Polar_N = N;

fecConfig.Polar_K = K;

fecConfig.NumPackets = numPackets;

fecConfig.EbN0dBList = EbN0dBList;

fecConfig.RandomSeed = randomSeed;

fecConfig.Channel = 'AWGN';

fecConfig.Modulation = 'BPSK';

fecConfig.LDPCDecoder = 'Normalized Min-Sum';

fecConfig.LDPCMaxIterations = maxLDPCIterations;

fecConfig.LDPCNormalizationFactor = ...
    ldpcNormalizationFactor;

fecConfig.PolarDecoder = 'Successive Cancellation';

fecConfig.PolarConstruction = ...
    'Bhattacharyya parameter construction';

fecConfig.PolarDesignEbN0_dB = polarDesignEbN0dB;

fecConfig.EbN0Definition = ...
    'Energy per information payload bit';

fecConfig.PacketEnergy = payloadLength;

fecConfig.ConfidenceLevel = confidenceLevel;

%% 10. Save results

resultsDir = fullfile(projectRoot,'results');

figuresDir = fullfile(resultsDir,'figures');

if exist(resultsDir,'dir') ~= 7
    mkdir(resultsDir);
end

if exist(figuresDir,'dir') ~= 7
    mkdir(figuresDir);
end

csvPath = fullfile(resultsDir,'fec_awgn_comparison.csv');

matPath = fullfile(resultsDir,'fec_awgn_comparison.mat');

writetable(FECResults,csvPath);

save(matPath, ...
    'FECResults', ...
    'fecConfig', ...
    'polarInfoIndices', ...
    'polarFrozenMask', ...
    'polarReliability');

%% 11. Plot PER curves

figure('Name','FEC PER Comparison');

hold on;
grid on;

for systemIndex = 1:numSystems

    hit = FECResults.System == string(systemNames{systemIndex});

    current = FECResults(hit,:);

    [sortedSNR,order] = sort(current.EbN0_dB);

    sortedPER = current.PER(order);

    plotPER = max(sortedPER,0.5/numPackets);

    semilogy( ...
        sortedSNR, ...
        plotPER, ...
        '-o', ...
        'LineWidth',1.5, ...
        'DisplayName',systemNames{systemIndex});

end

xlabel('E_b/N_0 (dB)');

ylabel('Packet Error Rate');

title('Channel Coding Comparison over AWGN');

legend('Location','southwest');

ylim([max(0.5/numPackets,1e-4),1]);

saveas(gcf,fullfile(figuresDir,'fec_awgn_per_comparison.png'));

%% 12. Plot BER curves

figure('Name','FEC BER Comparison');

hold on;
grid on;

for systemIndex = 1:numSystems

    hit = FECResults.System == string(systemNames{systemIndex});

    current = FECResults(hit,:);

    [sortedSNR,order] = sort(current.EbN0_dB);

    sortedBER = current.BER(order);

    plotBER = max(sortedBER,0.5/(payloadLength*numPackets));

    semilogy( ...
        sortedSNR, ...
        plotBER, ...
        '-s', ...
        'LineWidth',1.5, ...
        'DisplayName',systemNames{systemIndex});

end

xlabel('E_b/N_0 (dB)');

ylabel('Payload BER');

title('Payload BER Comparison over AWGN');

legend('Location','southwest');

ylim([max(0.5/(payloadLength*numPackets),1e-6),1]);

saveas(gcf,fullfile(figuresDir,'fec_awgn_ber_comparison.png'));

%% 13. Display final table

fprintf('\n');
fprintf('===============================================\n');
fprintf(' FINAL FEC COMPARISON RESULTS\n');
fprintf('===============================================\n\n');

disp(FECResults);

%% 14. Completion

fprintf('\n');
fprintf('===============================================\n');
fprintf(' FEC COMPARISON COMPLETED\n');
fprintf('===============================================\n');

fprintf('CSV:\n%s\n\n',csvPath);

fprintf('MAT:\n%s\n\n',matPath);

fprintf('PER figure:\n%s\n\n', ...
    fullfile(figuresDir,'fec_awgn_per_comparison.png'));

fprintf('BER figure:\n%s\n\n', ...
    fullfile(figuresDir,'fec_awgn_ber_comparison.png'));


%% =========================================================
% LOCAL FUNCTION: Wilson 95%% confidence interval
%% =========================================================

function [lower,upper] = local_wilson(errors,trials)

    z = 1.959963984540054;

    p = errors/trials;

    denominator = 1+z^2/trials;

    center = ...
        (p+z^2/(2*trials))/denominator;

    half = ...
        (z/denominator)* ...
        sqrt(p*(1-p)/trials+z^2/(4*trials^2));

    lower = max(0,center-half);

    upper = min(1,center+half);

end
