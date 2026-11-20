
clc;
clear;
close all;

%% =========================================================
%  MILESTONE 31.9
%  DEEP INDEPENDENT VALIDATION OF BOUNDARY MCS PROFILES
%
%  Validation packets: 3000 per profile and operating point
%
%  Rayleigh:
%       16, 18, 20 dB
%
%  Rician:
%       10, 12, 14, 16, 18, 20 dB
%
%  Profiles:
%       BPSK-D4, BPSK-D16
%       QPSK-D4, QPSK-D16
%       16QAM-D4, 16QAM-D16
%
%  Statistical analysis:
%       BER, PER, Wilson 95% CI
%       Paired exact McNemar test
%       Holm-Bonferroni correction
%
%  CSI: Perfect CSI
%  FEC: Convolutional code (7,5), rate 1/2
%% =========================================================

fprintf('\n');
fprintf('===============================================\n');
fprintf(' DEEP INDEPENDENT MCS VALIDATION\n');
fprintf('===============================================\n\n');

%% 1. Project setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));
rehash;

%% 2. Load calibration and policy data

calibrationPath = fullfile( ...
    projectRoot, 'results', 'mcs_profile_calibration.mat');

policyPath = fullfile( ...
    projectRoot, 'results', 'adaptive_mcs_policy.mat');

assert(exist(calibrationPath,'file') == 2, ...
    'Calibration file not found.');

assert(exist(policyPath,'file') == 2, ...
    'Adaptive policy file not found.');

C = load(calibrationPath, ...
    'ProfileTable', 'calibrationConfig');

P = load(policyPath, 'AdaptivePolicy');

ProfileTable = C.ProfileTable;
calibrationConfig = C.calibrationConfig;
AdaptivePolicy = P.AdaptivePolicy;

%% 3. Validation configuration

payloadLength = 1024;

numPackets = 3000;

validationSeed = 20261122;

numFadingBlocks = 4;

ricianKFactor_dB = calibrationConfig.RicianKFactor_dB;

targetPER = calibrationConfig.TargetPER;

confidenceLevel = 0.95;

channelList = [
    "rayleigh"
    "rayleigh"
    "rayleigh"
    "rician"
    "rician"
    "rician"
    "rician"
    "rician"
    "rician"
];

EbN0List = [
    16
    18
    20
    10
    12
    14
    16
    18
    20
];

modulationTypes = {'BPSK','QPSK','16QAM'};

interleaverDepths = [4 16];

numProfiles = ...
    numel(modulationTypes) * numel(interleaverDepths);

numOperatingPoints = numel(EbN0List);

numRows = numOperatingPoints * numProfiles;

rng(validationSeed,'twister');

fprintf('Payload length       : %d bits\n',payloadLength);
fprintf('Packets per profile  : %d\n',numPackets);
fprintf('Operating points     : %d\n',numOperatingPoints);
fprintf('Profiles per point   : %d\n',numProfiles);
fprintf('Total profile runs   : %d\n',numRows*numPackets);
fprintf('Random seed          : %d\n',validationSeed);
fprintf('Target PER           : %.3f\n\n',targetPER);

%% 4. Generate independent payload bank

payloadBank = randi( ...
    [0 1],payloadLength,numPackets);

%% 5. Generate common fading banks
% Each packet has four independently generated fading blocks.
% The same packet fading is reused across profiles and SNR points
% of the same channel to support paired comparisons.

rayleighFadingBank = ( ...
    randn(numFadingBlocks,numPackets) + ...
    1i*randn(numFadingBlocks,numPackets)) / sqrt(2);

K = 10^(ricianKFactor_dB/10);

ricianLOS = sqrt(K/(K+1));

ricianScatter = sqrt(1/(K+1));

ricianScattered = ( ...
    randn(numFadingBlocks,numPackets) + ...
    1i*randn(numFadingBlocks,numPackets)) / sqrt(2);

ricianFadingBank = ...
    ricianLOS + ricianScatter.*ricianScattered;

%% 6. Determine maximum transmission length

[probeSymbols,~] = adaptive_link_transmitter( ...
    payloadBank(:,1), ...
    'BPSK', ...
    4, ...
    numFadingBlocks);

maxNumSymbols = numel(probeSymbols);

fprintf('Maximum symbol count : %d\n\n',maxNumSymbols);

%% 7. Preallocate result variables

Channel = strings(numRows,1);

EbN0_dB = zeros(numRows,1);

Modulation = strings(numRows,1);

BitsPerSymbol = zeros(numRows,1);

CodeRate = zeros(numRows,1);

InterleaverDepth = zeros(numRows,1);

BER = zeros(numRows,1);

PER = zeros(numRows,1);

PER_Lower95 = zeros(numRows,1);

PER_Upper95 = zeros(numRows,1);

PacketErrors = zeros(numRows,1);

NumPackets = zeros(numRows,1);

EffectiveSpectralEfficiency = zeros(numRows,1);

CalibrationPER = zeros(numRows,1);

CalibrationPER_Upper95 = zeros(numRows,1);

CalibrationQoS_Met = false(numRows,1);

WasSelectedByCalibrationPolicy = false(numRows,1);

% Store individual packet-error outcomes.
% Rows correspond exactly to ValidationResults rows.
PacketErrorMatrix = false(numRows,numPackets);

%% 8. Main independent validation

rowIndex = 0;

for pointIndex = 1:numOperatingPoints

    currentChannel = channelList(pointIndex);

    currentEbN0dB = EbN0List(pointIndex);

    N0 = 10^(-currentEbN0dB/10);

    fprintf('\n');
    fprintf('===============================================\n');
    fprintf('CHANNEL: %s | Eb/N0: %d dB\n', ...
        upper(currentChannel),currentEbN0dB);
    fprintf('===============================================\n');

    %% Select channel fading bank

    if currentChannel == "rayleigh"

        fadingBank = rayleighFadingBank;

    elseif currentChannel == "rician"

        fadingBank = ricianFadingBank;

    else

        error('Unsupported channel type.');

    end

    %% Generate common noise realizations for this operating point

    noiseBank = ( ...
        randn(maxNumSymbols,numPackets) + ...
        1i*randn(maxNumSymbols,numPackets)) / sqrt(2);

    %% Evaluate all six profiles

    for m = 1:numel(modulationTypes)

        modulation = modulationTypes{m};

        for d = 1:numel(interleaverDepths)

            depth = interleaverDepths(d);

            totalBitErrors = 0;

            packetErrorVector = false(1,numPackets);

            fprintf('%-6s | Depth %2d | ',modulation,depth);

            %% Packet simulation

            for packetIndex = 1:numPackets

                payloadBits = payloadBank(:,packetIndex);

                %% Transmitter

                [txSymbols,txInfo] = ...
                    adaptive_link_transmitter( ...
                        payloadBits, ...
                        modulation, ...
                        depth, ...
                        numFadingBlocks);

                txSymbols = txSymbols(:);

                numSymbols = numel(txSymbols);

                if numSymbols > maxNumSymbols

                    error('Unexpected transmission length.');

                end

                if mod(numSymbols,numFadingBlocks) ~= 0

                    error('Transmission length is not divisible by fading blocks.');

                end

                %% Block fading

                symbolsPerBlock = ...
                    numSymbols/numFadingBlocks;

                hBlocks = fadingBank(:,packetIndex);

                hSymbols = repelem( ...
                    hBlocks,symbolsPerBlock);

                hSymbols = hSymbols(:);

                %% Complex AWGN

                noise = sqrt(N0).* ...
                    noiseBank(1:numSymbols,packetIndex);

                %% Received signal

                rxSymbols = ...
                    txSymbols.*hSymbols + noise;

                %% Receiver

                decodedPayload = adaptive_link_receiver( ...
                    rxSymbols, ...
                    hSymbols, ...
                    N0, ...
                    txInfo);

                decodedPayload = decodedPayload(:);

                %% Packet and bit errors

                if numel(decodedPayload) ~= payloadLength

                    bitErrors = payloadLength;

                    packetError = true;

                else

                    bitErrors = sum( ...
                        decodedPayload ~= payloadBits);

                    packetError = bitErrors > 0;

                end

                totalBitErrors = ...
                    totalBitErrors + bitErrors;

                packetErrorVector(packetIndex) = packetError;

            end

            %% Calculate metrics

            packetErrors = sum(packetErrorVector);

            measuredBER = totalBitErrors / ...
                (payloadLength*numPackets);

            measuredPER = packetErrors/numPackets;

            [perLower,perUpper] = ...
                local_wilson_interval( ...
                    packetErrors,numPackets);

            %% Store profile result

            rowIndex = rowIndex+1;

            Channel(rowIndex) = currentChannel;

            EbN0_dB(rowIndex) = currentEbN0dB;

            Modulation(rowIndex) = string(modulation);

            BitsPerSymbol(rowIndex) = txInfo.BitsPerSymbol;

            CodeRate(rowIndex) = ...
                txInfo.NominalConvolutionalRate;

            InterleaverDepth(rowIndex) = depth;

            BER(rowIndex) = measuredBER;

            PER(rowIndex) = measuredPER;

            PER_Lower95(rowIndex) = perLower;

            PER_Upper95(rowIndex) = perUpper;

            PacketErrors(rowIndex) = packetErrors;

            NumPackets(rowIndex) = numPackets;

            EffectiveSpectralEfficiency(rowIndex) = ...
                payloadLength/numSymbols;

            PacketErrorMatrix(rowIndex,:) = packetErrorVector;

            %% Match calibration result

            calibrationChannels = ...
                lower(strtrim(string(ProfileTable.Channel)));

            calibrationModulations = ...
                upper(strtrim(string(ProfileTable.Modulation)));

            calibrationHit = ...
                calibrationChannels == currentChannel & ...
                ProfileTable.EbN0_dB == currentEbN0dB & ...
                calibrationModulations == upper(string(modulation)) & ...
                ProfileTable.InterleaverDepth == depth;

            if nnz(calibrationHit) ~= 1

                error('Calibration profile mapping is not unique.');

            end

            calRow = find(calibrationHit,1);

            CalibrationPER(rowIndex) = ...
                ProfileTable.PER(calRow);

            CalibrationPER_Upper95(rowIndex) = ...
                ProfileTable.PER_Upper95(calRow);

            CalibrationQoS_Met(rowIndex) = ...
                ProfileTable.PER_Upper95(calRow) <= targetPER;

            %% Check whether the old policy selected this profile

            policyChannels = ...
                lower(strtrim(string(AdaptivePolicy.Channel)));

            policyModulations = ...
                upper(strtrim(string(AdaptivePolicy.SelectedModulation)));

            policyHit = ...
                policyChannels == currentChannel & ...
                AdaptivePolicy.EbN0_dB == currentEbN0dB & ...
                policyModulations == upper(string(modulation)) & ...
                AdaptivePolicy.SelectedInterleaverDepth == depth;

            WasSelectedByCalibrationPolicy(rowIndex) = any(policyHit);

            %% Progress

            fprintf('BER = %.5e | PER = %.4f | Upper95 = %.4f\n', ...
                measuredBER,measuredPER,perUpper);

        end

    end

    clear noiseBank;

end

%% 9. Construct independent validation table

QoS_Met_Validation = PER_Upper95 <= targetPER;

BoundaryValidationResults = table( ...
    Channel, ...
    EbN0_dB, ...
    Modulation, ...
    BitsPerSymbol, ...
    CodeRate, ...
    InterleaverDepth, ...
    BER, ...
    PER, ...
    PER_Lower95, ...
    PER_Upper95, ...
    PacketErrors, ...
    NumPackets, ...
    EffectiveSpectralEfficiency, ...
    QoS_Met_Validation, ...
    CalibrationPER, ...
    CalibrationPER_Upper95, ...
    CalibrationQoS_Met, ...
    WasSelectedByCalibrationPolicy);

%% 10. Select the profile used by the calibration policy

SelectedProfileValidation = ...
    BoundaryValidationResults( ...
        BoundaryValidationResults.WasSelectedByCalibrationPolicy,:);

if height(SelectedProfileValidation) ~= numOperatingPoints

    error('Expected exactly one calibration-selected profile per operating point.');

end

%% 11. Paired comparison: QPSK-D16 vs 16QAM-D4

% Positive DeltaPER means 16QAM has higher PER.
% Negative DeltaPER means 16QAM has lower PER.

pairChannel = strings(numOperatingPoints,1);

pairEbN0 = zeros(numOperatingPoints,1);

qpskPER = zeros(numOperatingPoints,1);

qamPER = zeros(numOperatingPoints,1);

deltaPER = zeros(numOperatingPoints,1);

qpskError_qamCorrect = zeros(numOperatingPoints,1);

qpskCorrect_qamError = zeros(numOperatingPoints,1);

discordantPackets = zeros(numOperatingPoints,1);

mcnemarP = zeros(numOperatingPoints,1);

pairIndex = 0;

for pointIndex = 1:numOperatingPoints

    currentChannel = channelList(pointIndex);

    currentSNR = EbN0List(pointIndex);

    %% Find QPSK-D16

    qpskHit = ...
        Channel == currentChannel & ...
        EbN0_dB == currentSNR & ...
        Modulation == "QPSK" & ...
        InterleaverDepth == 16;

    %% Find 16QAM-D4

    qamHit = ...
        Channel == currentChannel & ...
        EbN0_dB == currentSNR & ...
        Modulation == "16QAM" & ...
        InterleaverDepth == 4;

    if nnz(qpskHit) ~= 1 || nnz(qamHit) ~= 1

        error('Pairwise comparison profile missing.');

    end

    qpskRow = find(qpskHit,1);

    qamRow = find(qamHit,1);

    qpskErrors = PacketErrorMatrix(qpskRow,:);

    qamErrors = PacketErrorMatrix(qamRow,:);

    %% Discordant packet outcomes

    % QPSK error, 16QAM correct
    b = sum(qpskErrors & ~qamErrors);

    % QPSK correct, 16QAM error
    c = sum(~qpskErrors & qamErrors);

    pairIndex = pairIndex+1;

    pairChannel(pairIndex) = currentChannel;

    pairEbN0(pairIndex) = currentSNR;

    qpskPER(pairIndex) = PER(qpskRow);

    qamPER(pairIndex) = PER(qamRow);

    deltaPER(pairIndex) = ...
        PER(qamRow)-PER(qpskRow);

    qpskError_qamCorrect(pairIndex) = b;

    qpskCorrect_qamError(pairIndex) = c;

    discordantPackets(pairIndex) = b+c;

    mcnemarP(pairIndex) = ...
        local_exact_mcnemar_p(b,c);

end

%% 12. Holm-Bonferroni multiple-comparison correction

holmAdjustedP = local_holm_adjust(mcnemarP);

PairwiseComparison = table( ...
    pairChannel, ...
    pairEbN0, ...
    qpskPER, ...
    qamPER, ...
    deltaPER, ...
    qpskError_qamCorrect, ...
    qpskCorrect_qamError, ...
    discordantPackets, ...
    mcnemarP, ...
    holmAdjustedP, ...
    'VariableNames', {
        'Channel'
        'EbN0_dB'
        'QPSK_D16_PER'
        'QAM16_D4_PER'
        'DeltaPER_16QAM_minus_QPSK'
        'QPSK_Error_16QAM_Correct'
        'QPSK_Correct_16QAM_Error'
        'DiscordantPackets'
        'McNemar_p'
        'HolmAdjusted_p'
    });

%% 13. Save configuration

boundaryConfig = struct();

boundaryConfig.PayloadLength = payloadLength;

boundaryConfig.NumPackets = numPackets;

boundaryConfig.RandomSeed = validationSeed;

boundaryConfig.ChannelList = channelList;

boundaryConfig.EbN0List = EbN0List;

boundaryConfig.ModulationTypes = modulationTypes;

boundaryConfig.InterleaverDepths = interleaverDepths;

boundaryConfig.NumFadingBlocks = numFadingBlocks;

boundaryConfig.RicianKFactor_dB = ricianKFactor_dB;

boundaryConfig.TargetPER = targetPER;

boundaryConfig.ConfidenceLevel = confidenceLevel;

boundaryConfig.CSI = 'Perfect CSI';

boundaryConfig.EbN0Definition = ...
    'Energy per information payload bit';

boundaryConfig.PairedComparison = ...
    'QPSK-D16 versus 16QAM-D4';

boundaryConfig.MultipleComparisonCorrection = ...
    'Holm-Bonferroni';

%% 14. Save result files

resultsDir = fullfile(projectRoot,'results');

if exist(resultsDir,'dir') ~= 7
    mkdir(resultsDir);
end

writetable( ...
    BoundaryValidationResults, ...
    fullfile(resultsDir,'boundary_mcs_validation_all_profiles.csv'));

writetable( ...
    SelectedProfileValidation, ...
    fullfile(resultsDir,'boundary_mcs_validation_selected.csv'));

writetable( ...
    PairwiseComparison, ...
    fullfile(resultsDir,'boundary_mcs_pairwise_comparison.csv'));

save( ...
    fullfile(resultsDir,'boundary_mcs_validation.mat'), ...
    'BoundaryValidationResults', ...
    'SelectedProfileValidation', ...
    'PairwiseComparison', ...
    'PacketErrorMatrix', ...
    'boundaryConfig');

%% 15. Display selected-profile results

fprintf('\n');
fprintf('===============================================\n');
fprintf(' CALIBRATION-SELECTED PROFILE VALIDATION\n');
fprintf('===============================================\n\n');

disp(SelectedProfileValidation);

%% 16. Display all pairwise comparisons

fprintf('\n');
fprintf('===============================================\n');
fprintf(' PAIRED QPSK-D16 VS 16QAM-D4\n');
fprintf('===============================================\n\n');

disp(PairwiseComparison);

%% 17. Display QoS changes

fprintf('\n');
fprintf('===============================================\n');
fprintf(' QOS STATUS COMPARISON\n');
fprintf('===============================================\n');

fprintf('Calibration QoS points: %d / %d\n', ...
    sum(BoundaryValidationResults.CalibrationQoS_Met( ...
        BoundaryValidationResults.WasSelectedByCalibrationPolicy)), ...
    numOperatingPoints);

fprintf('Independent QoS points: %d / %d\n', ...
    sum(SelectedProfileValidation.QoS_Met_Validation), ...
    numOperatingPoints);

fprintf('Selected profiles failing independent QoS: %d\n', ...
    sum(~SelectedProfileValidation.QoS_Met_Validation));

fprintf('\n');
fprintf('===============================================\n');
fprintf(' BOUNDARY VALIDATION COMPLETED\n');
fprintf('===============================================\n');

fprintf('\nResults saved in:\n%s\n',resultsDir);


%% =========================================================
%  LOCAL FUNCTION 1: Wilson confidence interval
%% =========================================================

function [lowerBound,upperBound] = ...
    local_wilson_interval(errors,trials)

    if trials <= 0
        error('Trials must be positive.');
    end

    z = 1.959963984540054;

    p = errors/trials;

    denominator = 1+z^2/trials;

    center = ...
        (p+z^2/(2*trials))/denominator;

    halfWidth = ...
        (z/denominator)* ...
        sqrt(p*(1-p)/trials+z^2/(4*trials^2));

    lowerBound = max(0,center-halfWidth);

    upperBound = min(1,center+halfWidth);

end


%% =========================================================
%  LOCAL FUNCTION 2: Exact two-sided McNemar test
%% =========================================================

function pValue = local_exact_mcnemar_p(b,c)

    n = b+c;

    if n == 0

        pValue = 1;

        return;

    end

    k = min(b,c);

    x = k:n;

    % Exact binomial probabilities under H0: p = 0.5.
    logProb = ...
        gammaln(n+1) - ...
        gammaln(x+1) - ...
        gammaln(n-x+1) - ...
        n*log(2);

    maxLog = max(logProb);

    upperTail = ...
        exp(maxLog)*sum(exp(logProb-maxLog));

    pValue = min(1,2*upperTail);

end


%% =========================================================
%  LOCAL FUNCTION 3: Holm-Bonferroni correction
%% =========================================================

function adjustedP = local_holm_adjust(pValues)

    pValues = pValues(:);

    m = numel(pValues);

    [sortedP,order] = sort(pValues);

    adjustedSorted = zeros(m,1);

    runningMaximum = 0;

    for k = 1:m

        currentAdjusted = ...
            (m-k+1)*sortedP(k);

        runningMaximum = ...
            max(runningMaximum,currentAdjusted);

        adjustedSorted(k) = min(1,runningMaximum);

    end

    adjustedP = zeros(m,1);

    adjustedP(order) = adjustedSorted;

end
