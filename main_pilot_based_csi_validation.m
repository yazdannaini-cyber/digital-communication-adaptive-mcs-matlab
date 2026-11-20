
clc;
clear;
close all;

%% =========================================================
%  MILESTONE 32
%  PILOT-BASED LS CHANNEL ESTIMATION
%
%  Compare:
%       1. Perfect CSI receiver
%       2. Pilot-based LS estimated CSI receiver
%
%  Selected profiles:
%       Taken from deep boundary validation
%
%  Channel:
%       Rayleigh / Rician
%
%  Channel model:
%       Four-block fading
%
%  Pilot:
%       16 known BPSK symbols per fading block
%
%  Statistical evaluation:
%       BER, PER, Wilson CI
%       Channel estimation NMSE
%       Exact paired McNemar test
%       Holm-Bonferroni correction
%% =========================================================

fprintf('\n');
fprintf('===============================================\n');
fprintf(' PILOT-BASED CHANNEL ESTIMATION VALIDATION\n');
fprintf('===============================================\n\n');

%% 1. Project setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));
rehash;

%% 2. Load selected boundary profiles

boundaryPath = fullfile( ...
    projectRoot, ...
    'results', ...
    'boundary_mcs_validation.mat');

assert(exist(boundaryPath,'file') == 2, ...
    'Boundary validation file not found.');

S = load(boundaryPath, ...
    'SelectedProfileValidation', ...
    'boundaryConfig');

SelectedProfiles = S.SelectedProfileValidation;
boundaryConfig = S.boundaryConfig;

assert(height(SelectedProfiles) == 9, ...
    'Expected nine selected boundary profiles.');

%% 3. Configuration

payloadLength = 1024;

numPackets = 3000;

numFadingBlocks = 4;

pilotLength = 16;

validationSeed = 20261123;

ricianKFactor_dB = boundaryConfig.RicianKFactor_dB;

targetPER = boundaryConfig.TargetPER;

rng(validationSeed,'twister');

fprintf('Payload length       : %d bits\n',payloadLength);
fprintf('Packets per profile  : %d\n',numPackets);
fprintf('Fading blocks        : %d\n',numFadingBlocks);
fprintf('Pilots per block     : %d\n',pilotLength);
fprintf('Total pilots/packet  : %d\n', ...
    numFadingBlocks*pilotLength);
fprintf('Operating points     : %d\n',height(SelectedProfiles));
fprintf('Random seed          : %d\n',validationSeed);
fprintf('Target PER           : %.3f\n\n',targetPER);

%% 4. Common independent payload bank

payloadBank = randi( ...
    [0 1],payloadLength,numPackets);

%% 5. Preallocation

numPoints = height(SelectedProfiles);

Channel = strings(numPoints,1);

EbN0_dB = zeros(numPoints,1);

Modulation = strings(numPoints,1);

InterleaverDepth = zeros(numPoints,1);

PilotLengthPerBlock = zeros(numPoints,1);

TotalPilotSymbols = zeros(numPoints,1);

DataSymbols = zeros(numPoints,1);

PilotOverheadPercent = zeros(numPoints,1);

PerfectCSI_BER = zeros(numPoints,1);
PerfectCSI_PER = zeros(numPoints,1);

PerfectCSI_PER_Lower95 = zeros(numPoints,1);
PerfectCSI_PER_Upper95 = zeros(numPoints,1);

EstimatedCSI_BER = zeros(numPoints,1);
EstimatedCSI_PER = zeros(numPoints,1);

EstimatedCSI_PER_Lower95 = zeros(numPoints,1);
EstimatedCSI_PER_Upper95 = zeros(numPoints,1);

ChannelEstimationNMSE = zeros(numPoints,1);
ChannelEstimationNMSE_dB = zeros(numPoints,1);

IdealSpectralEfficiency = zeros(numPoints,1);
PilotSpectralEfficiency = zeros(numPoints,1);

PerfectCSI_QoS = false(numPoints,1);
EstimatedCSI_QoS = false(numPoints,1);

QoS_Status_Changed = false(numPoints,1);

PerfectCSI_PacketErrors = false(numPoints,numPackets);
EstimatedCSI_PacketErrors = false(numPoints,numPackets);

PerfectCSI_BitErrors = zeros(numPoints,1);
EstimatedCSI_BitErrors = zeros(numPoints,1);

%% 6. Main simulation

for pointIndex = 1:numPoints

    channelType = lower( ...
        string(SelectedProfiles.Channel(pointIndex)));

    currentSNR = ...
        SelectedProfiles.EbN0_dB(pointIndex);

    modulation = char( ...
        SelectedProfiles.Modulation(pointIndex));

    interleaverDepth = ...
        SelectedProfiles.InterleaverDepth(pointIndex);

    N0 = 10^(-currentSNR/10);

    fprintf('\n===============================================\n');
    fprintf('%s | %s | %d dB | Depth %d\n', ...
        upper(channelType), ...
        modulation, ...
        currentSNR, ...
        interleaverDepth);
    fprintf('===============================================\n');

    %% Generate independent fading realization

    fadingBank = local_generate_fading( ...
        channelType, ...
        numFadingBlocks, ...
        numPackets, ...
        ricianKFactor_dB);

    totalPerfectBitErrors = 0;
    totalEstimatedBitErrors = 0;

    perfectPacketErrors = false(1,numPackets);
    estimatedPacketErrors = false(1,numPackets);

    nmseNumerator = 0;
    nmseDenominator = 0;

    %% Packet simulation

    for packetIndex = 1:numPackets

        payloadBits = payloadBank(:,packetIndex);

        %% Generate data symbols

        [txSymbols,txInfo] = ...
            adaptive_link_transmitter( ...
                payloadBits, ...
                modulation, ...
                interleaverDepth, ...
                numFadingBlocks);

        txSymbols = txSymbols(:);

        numDataSymbols = numel(txSymbols);

        if mod(numDataSymbols,numFadingBlocks) ~= 0
            error('Data symbol count is not divisible by fading blocks.');
        end

        symbolsPerBlock = ...
            numDataSymbols/numFadingBlocks;

        %% Energy normalization including pilots

        totalPilotSymbols = ...
            numFadingBlocks*pilotLength;

        totalFrameSymbols = ...
            numDataSymbols+totalPilotSymbols;

        oldAmplitude = txInfo.SymbolAmplitude;

        newAmplitude = sqrt( ...
            payloadLength/totalFrameSymbols);

        scaleFactor = newAmplitude/oldAmplitude;

        pilotDataSymbols = txSymbols.*scaleFactor;

        pilotTxInfo = txInfo;

        pilotTxInfo.SymbolAmplitude = newAmplitude;

        %% Common data noise for both receiver branches

        dataNoise = sqrt(N0/2)*( ...
            randn(numDataSymbols,1) + ...
            1i*randn(numDataSymbols,1));

        %% Allocate arrays

        perfectRx = zeros(numDataSymbols,1);

        estimatedRx = zeros(numDataSymbols,1);

        hTrueSymbols = zeros(numDataSymbols,1);

        hEstimatedSymbols = zeros(numDataSymbols,1);

        hBlocks = fadingBank(:,packetIndex);

        %% Process each fading block

        for blockIndex = 1:numFadingBlocks

            firstIndex = ...
                (blockIndex-1)*symbolsPerBlock+1;

            lastIndex = ...
                blockIndex*symbolsPerBlock;

            indices = firstIndex:lastIndex;

            h = hBlocks(blockIndex);

            %% Data transmission: perfect CSI reference

            perfectRx(indices) = ...
                txSymbols(indices).*h + dataNoise(indices);

            %% Known pilot transmission

            pilotSymbols = ones(pilotLength,1);

            pilotTx = newAmplitude.*pilotSymbols;

            pilotNoise = sqrt(N0/2)*( ...
                randn(pilotLength,1) + ...
                1i*randn(pilotLength,1));

            pilotRx = ...
                pilotTx.*h + pilotNoise;

            %% Least Squares channel estimation

            hHat = ...
                sum(conj(pilotTx).*pilotRx) / ...
                sum(abs(pilotTx).^2);

            %% Estimated CSI data transmission

            estimatedRx(indices) = ...
                pilotDataSymbols(indices).*h + dataNoise(indices);

            hTrueSymbols(indices) = h;

            hEstimatedSymbols(indices) = hHat;

            %% Channel estimation error

            nmseNumerator = nmseNumerator + ...
                abs(hHat-h)^2;

            nmseDenominator = nmseDenominator + ...
                abs(h)^2;

        end

        %% Perfect CSI receiver

        decodedPerfect = adaptive_link_receiver( ...
            perfectRx, ...
            hTrueSymbols, ...
            N0, ...
            txInfo);

        decodedPerfect = decodedPerfect(:);

        %% Estimated CSI receiver

        % First-order effective-noise inflation.
        % LS estimation error variance per block is approximately:
        % N0/(pilotLength*newAmplitude^2).
        % This produces an approximate 1+1/pilotLength
        % uncertainty factor for the LLR demapper.

        effectiveNoiseVariance = ...
            N0*(1+1/pilotLength);

        decodedEstimated = adaptive_link_receiver( ...
            estimatedRx, ...
            hEstimatedSymbols, ...
            effectiveNoiseVariance, ...
            pilotTxInfo);

        decodedEstimated = decodedEstimated(:);

        %% Calculate payload bit errors

        if numel(decodedPerfect) ~= payloadLength

            perfectBitErrors = payloadLength;
            perfectPacketError = true;

        else

            perfectBitErrors = sum( ...
                decodedPerfect ~= payloadBits);

            perfectPacketError = perfectBitErrors > 0;

        end

        if numel(decodedEstimated) ~= payloadLength

            estimatedBitErrors = payloadLength;
            estimatedPacketError = true;

        else

            estimatedBitErrors = sum( ...
                decodedEstimated ~= payloadBits);

            estimatedPacketError = estimatedBitErrors > 0;

        end

        totalPerfectBitErrors = ...
            totalPerfectBitErrors+perfectBitErrors;

        totalEstimatedBitErrors = ...
            totalEstimatedBitErrors+estimatedBitErrors;

        perfectPacketErrors(packetIndex) = perfectPacketError;

        estimatedPacketErrors(packetIndex) = estimatedPacketError;

    end

    %% Calculate metrics

    numPerfectErrors = sum(perfectPacketErrors);

    numEstimatedErrors = sum(estimatedPacketErrors);

    perfectBER = ...
        totalPerfectBitErrors/(payloadLength*numPackets);

    estimatedBER = ...
        totalEstimatedBitErrors/(payloadLength*numPackets);

    perfectPER = numPerfectErrors/numPackets;

    estimatedPER = numEstimatedErrors/numPackets;

    [perfectLower,perfectUpper] = ...
        local_wilson(numPerfectErrors,numPackets);

    [estimatedLower,estimatedUpper] = ...
        local_wilson(numEstimatedErrors,numPackets);

    nmse = nmseNumerator/nmseDenominator;

    %% Spectral efficiency

    [probeSymbols,~] = adaptive_link_transmitter( ...
        payloadBank(:,1), ...
        modulation, ...
        interleaverDepth, ...
        numFadingBlocks);

    dataSymbolCount = numel(probeSymbols);

    totalFrameSymbols = ...
        dataSymbolCount+numFadingBlocks*pilotLength;

    idealEfficiency = payloadLength/dataSymbolCount;

    pilotEfficiency = payloadLength/totalFrameSymbols;

    %% Save point results

    Channel(pointIndex) = channelType;

    EbN0_dB(pointIndex) = currentSNR;

    Modulation(pointIndex) = string(modulation);

    InterleaverDepth(pointIndex) = interleaverDepth;

    PilotLengthPerBlock(pointIndex) = pilotLength;

    TotalPilotSymbols(pointIndex) = ...
        numFadingBlocks*pilotLength;

    DataSymbols(pointIndex) = dataSymbolCount;

    PilotOverheadPercent(pointIndex) = ...
        100*(numFadingBlocks*pilotLength)/totalFrameSymbols;

    PerfectCSI_BER(pointIndex) = perfectBER;

    PerfectCSI_PER(pointIndex) = perfectPER;

    PerfectCSI_PER_Lower95(pointIndex) = perfectLower;

    PerfectCSI_PER_Upper95(pointIndex) = perfectUpper;

    EstimatedCSI_BER(pointIndex) = estimatedBER;

    EstimatedCSI_PER(pointIndex) = estimatedPER;

    EstimatedCSI_PER_Lower95(pointIndex) = estimatedLower;

    EstimatedCSI_PER_Upper95(pointIndex) = estimatedUpper;

    ChannelEstimationNMSE(pointIndex) = nmse;

    ChannelEstimationNMSE_dB(pointIndex) = ...
        10*log10(max(nmse,realmin));

    IdealSpectralEfficiency(pointIndex) = idealEfficiency;

    PilotSpectralEfficiency(pointIndex) = pilotEfficiency;

    PerfectCSI_QoS(pointIndex) = perfectUpper <= targetPER;

    EstimatedCSI_QoS(pointIndex) = estimatedUpper <= targetPER;

    QoS_Status_Changed(pointIndex) = ...
        PerfectCSI_QoS(pointIndex) ~= ...
        EstimatedCSI_QoS(pointIndex);

    PerfectCSI_PacketErrors(pointIndex,:) = perfectPacketErrors;

    EstimatedCSI_PacketErrors(pointIndex,:) = estimatedPacketErrors;

    PerfectCSI_BitErrors(pointIndex) = totalPerfectBitErrors;

    EstimatedCSI_BitErrors(pointIndex) = totalEstimatedBitErrors;

    %% Progress

    fprintf('Perfect CSI PER : %.4f | Upper95: %.4f\n', ...
        perfectPER,perfectUpper);

    fprintf('Estimated CSI PER: %.4f | Upper95: %.4f\n', ...
        estimatedPER,estimatedUpper);

    fprintf('Channel NMSE    : %.2f dB\n', ...
        10*log10(max(nmse,realmin)));

    fprintf('Pilot overhead  : %.2f %%\n', ...
        PilotOverheadPercent(pointIndex));

    fprintf('Estimated QoS   : %d\n', ...
        EstimatedCSI_QoS(pointIndex));

end

%% 7. Construct results table

PilotResults = table( ...
    Channel, ...
    EbN0_dB, ...
    Modulation, ...
    InterleaverDepth, ...
    PilotLengthPerBlock, ...
    TotalPilotSymbols, ...
    DataSymbols, ...
    PilotOverheadPercent, ...
    PerfectCSI_BER, ...
    PerfectCSI_PER, ...
    PerfectCSI_PER_Lower95, ...
    PerfectCSI_PER_Upper95, ...
    EstimatedCSI_BER, ...
    EstimatedCSI_PER, ...
    EstimatedCSI_PER_Lower95, ...
    EstimatedCSI_PER_Upper95, ...
    ChannelEstimationNMSE, ...
    ChannelEstimationNMSE_dB, ...
    IdealSpectralEfficiency, ...
    PilotSpectralEfficiency, ...
    PerfectCSI_QoS, ...
    EstimatedCSI_QoS, ...
    QoS_Status_Changed);

%% 8. Paired McNemar comparisons

McNemar_p = zeros(numPoints,1);

PerfectError_EstimatedCorrect = zeros(numPoints,1);

PerfectCorrect_EstimatedError = zeros(numPoints,1);

DiscordantPackets = zeros(numPoints,1);

for k = 1:numPoints

    pErr = PerfectCSI_PacketErrors(k,:);

    eErr = EstimatedCSI_PacketErrors(k,:);

    b = sum(pErr & ~eErr);

    c = sum(~pErr & eErr);

    PerfectError_EstimatedCorrect(k) = b;

    PerfectCorrect_EstimatedError(k) = c;

    DiscordantPackets(k) = b+c;

    McNemar_p(k) = local_mcnemar(b,c);

end

HolmAdjusted_p = local_holm(McNemar_p);

SignificantAfterHolm = HolmAdjusted_p < 0.05;

PairwiseCSIComparison = table( ...
    Channel, ...
    EbN0_dB, ...
    PerfectCSI_PER, ...
    EstimatedCSI_PER, ...
    EstimatedCSI_PER-PerfectCSI_PER, ...
    PerfectError_EstimatedCorrect, ...
    PerfectCorrect_EstimatedError, ...
    DiscordantPackets, ...
    McNemar_p, ...
    HolmAdjusted_p, ...
    SignificantAfterHolm, ...
    'VariableNames', {
        'Channel'
        'EbN0_dB'
        'PerfectCSI_PER'
        'EstimatedCSI_PER'
        'DeltaPER_Estimated_minus_Perfect'
        'PerfectError_EstimatedCorrect'
        'PerfectCorrect_EstimatedError'
        'DiscordantPackets'
        'McNemar_p'
        'HolmAdjusted_p'
        'SignificantAfterHolm'
    });

%% 9. Validation configuration

pilotConfig = struct();

pilotConfig.PayloadLength = payloadLength;

pilotConfig.NumPackets = numPackets;

pilotConfig.RandomSeed = validationSeed;

pilotConfig.NumFadingBlocks = numFadingBlocks;

pilotConfig.PilotLengthPerBlock = pilotLength;

pilotConfig.TotalPilotSymbols = ...
    numFadingBlocks*pilotLength;

pilotConfig.RicianKFactor_dB = ricianKFactor_dB;

pilotConfig.TargetPER = targetPER;

pilotConfig.ConfidenceLevel = 0.95;

pilotConfig.ChannelEstimation = 'Least Squares';

pilotConfig.PilotModulation = 'Known BPSK symbols';

pilotConfig.CSIReference = 'Perfect CSI with no pilots';

pilotConfig.EbN0Definition = ...
    'Energy per information payload bit';

pilotConfig.EstimatorVarianceCompensation = ...
    'Approximate factor 1+1/PilotLength';

%% 10. Save results

resultsDir = fullfile(projectRoot,'results');

if exist(resultsDir,'dir') ~= 7
    mkdir(resultsDir);
end

writetable( ...
    PilotResults, ...
    fullfile(resultsDir,'pilot_csi_validation.csv'));

writetable( ...
    PairwiseCSIComparison, ...
    fullfile(resultsDir,'pilot_csi_paired_comparison.csv'));

save( ...
    fullfile(resultsDir,'pilot_csi_validation.mat'), ...
    'PilotResults', ...
    'PairwiseCSIComparison', ...
    'PerfectCSI_PacketErrors', ...
    'EstimatedCSI_PacketErrors', ...
    'pilotConfig');

%% 11. Display main table

fprintf('\n');
fprintf('===============================================\n');
fprintf(' PILOT-BASED CSI VALIDATION RESULTS\n');
fprintf('===============================================\n\n');

disp(PilotResults);

%% 12. Display paired comparison

fprintf('\n');
fprintf('===============================================\n');
fprintf(' PERFECT CSI VS ESTIMATED CSI\n');
fprintf('===============================================\n\n');

disp(PairwiseCSIComparison);

%% 13. Summary

fprintf('\n');
fprintf('===============================================\n');
fprintf(' PILOT CSI SUMMARY\n');
fprintf('===============================================\n');

fprintf('Perfect CSI QoS points : %d / %d\n', ...
    sum(PerfectCSI_QoS),numPoints);

fprintf('Estimated CSI QoS points: %d / %d\n', ...
    sum(EstimatedCSI_QoS),numPoints);

fprintf('QoS status changes     : %d\n', ...
    sum(QoS_Status_Changed));

fprintf('Mean channel NMSE       : %.2f dB\n', ...
    mean(ChannelEstimationNMSE_dB));

fprintf('Mean pilot overhead     : %.2f %%\n', ...
    mean(PilotOverheadPercent));

fprintf('Significant paired changes: %d / %d\n', ...
    sum(SignificantAfterHolm),numPoints);

fprintf('\nResults saved successfully.\n');


%% =========================================================
% LOCAL FUNCTION: Fading generation
%% =========================================================

function h = local_generate_fading( ...
    channelType,numBlocks,numPackets,KdB)

    switch lower(char(channelType))

        case 'rayleigh'

            h = ( ...
                randn(numBlocks,numPackets) + ...
                1i*randn(numBlocks,numPackets))/sqrt(2);

        case 'rician'

            K = 10^(KdB/10);

            los = sqrt(K/(K+1));

            scatter = sqrt(1/(K+1));

            g = ( ...
                randn(numBlocks,numPackets) + ...
                1i*randn(numBlocks,numPackets))/sqrt(2);

            h = los+scatter*g;

        otherwise

            error('Unsupported channel type.');

    end

end


%% =========================================================
% LOCAL FUNCTION: Wilson 95% confidence interval
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


%% =========================================================
% LOCAL FUNCTION: Exact McNemar
%% =========================================================

function p = local_mcnemar(b,c)

    n = b+c;

    if n == 0
        p = 1;
        return;
    end

    k = min(b,c);

    x = 0:k;

    logProb = ...
        gammaln(n+1)- ...
        gammaln(x+1)- ...
        gammaln(n-x+1)- ...
        n*log(2);

    peak = max(logProb);

    tail = exp(peak)*sum(exp(logProb-peak));

    p = min(1,2*tail);

end


%% =========================================================
% LOCAL FUNCTION: Holm correction
%% =========================================================

function adjusted = local_holm(pValues)

    pValues = pValues(:);

    m = numel(pValues);

    [sortedP,order] = sort(pValues);

    adjustedSorted = zeros(m,1);

    runningMax = 0;

    for k = 1:m

        value = (m-k+1)*sortedP(k);

        runningMax = max(runningMax,value);

        adjustedSorted(k) = min(1,runningMax);

    end

    adjusted = zeros(m,1);

    adjusted(order) = adjustedSorted;

end
