
clc;
clear;
close all;

%% =========================================================
%  MILESTONE 31.6
%  Independent Validation of Adaptive MCS Policy
%
%  Independent random payload, fading and AWGN realizations.
%
%  Six fixed profiles:
%       BPSK   - Depth 4
%       BPSK   - Depth 16
%       QPSK   - Depth 4
%       QPSK   - Depth 16
%       16QAM  - Depth 4
%       16QAM  - Depth 16
%
%  Adaptive policy is evaluated by selecting its corresponding
%  independently simulated fixed-profile result.
%
%  Fixed global baselines:
%       BPSK-D16
%       QPSK-D16
%       16QAM-D16
%% =========================================================

fprintf('\n');
fprintf('===============================================\n');
fprintf(' INDEPENDENT ADAPTIVE MCS VALIDATION\n');
fprintf('===============================================\n\n');

%% 1. Project setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));
rehash;

%% 2. Load calibration data and policy

calibrationPath = fullfile( ...
    projectRoot, 'results', 'mcs_profile_calibration.mat');

policyPath = fullfile( ...
    projectRoot, 'results', 'adaptive_mcs_policy.mat');

if exist(calibrationPath, 'file') ~= 2
    error('Calibration file not found.');
end

if exist(policyPath, 'file') ~= 2
    error('Adaptive MCS policy file not found.');
end

cal = load(calibrationPath, 'ProfileTable', 'calibrationConfig');

pol = load(policyPath, ...
    'AdaptivePolicy', ...
    'targetPER', ...
    'maxFirstColumnReady_ms');

ProfileTable = cal.ProfileTable;
calibrationConfig = cal.calibrationConfig;

AdaptivePolicy = pol.AdaptivePolicy;
targetPER = pol.targetPER;
maxFirstColumnReady_ms = pol.maxFirstColumnReady_ms;

%% 3. Independent validation configuration

payloadLength = 1024;

numValidationPackets = 500;

validationSeed = 20261121;

EbN0dBList = unique(AdaptivePolicy.EbN0_dB, 'stable').';

channelTypes = {'rayleigh', 'rician'};

modulationTypes = {'BPSK', 'QPSK', '16QAM'};

interleaverDepths = [4 16];

numFadingBlocks = 4;

ricianKFactor_dB = calibrationConfig.RicianKFactor_dB;

confidenceLevel = 0.95;

% Independent random realizations.
rng(validationSeed, 'twister');

payloadBank = randi( ...
    [0 1], payloadLength, numValidationPackets);

fprintf('Validation seed       : %d\n', validationSeed);
fprintf('Validation packets    : %d\n', numValidationPackets);
fprintf('Payload length        : %d bits\n', payloadLength);
fprintf('Independent test points: %d\n', ...
    numel(channelTypes) * numel(EbN0dBList));

%% 4. Determine maximum symbol count

[probeSymbols, ~] = adaptive_link_transmitter( ...
    payloadBank(:,1), ...
    'BPSK', ...
    4, ...
    numFadingBlocks);

maxNumSymbols = numel(probeSymbols);

fprintf('Maximum symbol count  : %d\n', maxNumSymbols);

%% 5. Preallocate result arrays

numRows = numel(channelTypes) * ...
          numel(EbN0dBList) * ...
          numel(modulationTypes) * ...
          numel(interleaverDepths);

Channel = strings(numRows,1);
Modulation = strings(numRows,1);

EbN0_dB = zeros(numRows,1);
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

%% 6. Independent channel simulations

rowIndex = 0;

for channelIndex = 1:numel(channelTypes)

    channelType = channelTypes{channelIndex};

    fprintf('\n');
    fprintf('-----------------------------------------------\n');
    fprintf('VALIDATION CHANNEL: %s\n', upper(channelType));
    fprintf('-----------------------------------------------\n');

    % New independent fading realizations for validation.
    fadingBank = local_generate_fading_bank( ...
        channelType, ...
        numFadingBlocks, ...
        numValidationPackets, ...
        ricianKFactor_dB);

    % New independent AWGN realizations.
    noiseBank = ( ...
        randn(maxNumSymbols, numValidationPackets) + ...
        1i * randn(maxNumSymbols, numValidationPackets)) / sqrt(2);

    for snrIndex = 1:numel(EbN0dBList)

        currentEbN0dB = EbN0dBList(snrIndex);

        N0 = 10^(-currentEbN0dB/10);

        fprintf('\nEb/N0 = %2.0f dB\n', currentEbN0dB);

        for m = 1:numel(modulationTypes)

            modulation = modulationTypes{m};

            for d = 1:numel(interleaverDepths)

                depth = interleaverDepths(d);

                packetErrors = 0;
                totalBitErrors = 0;

                fprintf('  %-6s | Depth %2d | ', modulation, depth);

                %% Packet loop

                for packetIndex = 1:numValidationPackets

                    payloadBits = payloadBank(:,packetIndex);

                    %% Transmitter

                    [txSymbols, txInfo] = ...
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

                    if mod(numSymbols, numFadingBlocks) ~= 0
                        error('Symbol count must be divisible by fading blocks.');
                    end

                    %% Block fading

                    symbolsPerBlock = ...
                        numSymbols / numFadingBlocks;

                    hBlocks = fadingBank(:,packetIndex);

                    hSymbols = repelem( ...
                        hBlocks, symbolsPerBlock);

                    hSymbols = hSymbols(:);

                    %% Independent AWGN

                    noise = sqrt(N0) .* ...
                        noiseBank(1:numSymbols,packetIndex);

                    %% Received signal

                    rxSymbols = ...
                        txSymbols .* hSymbols + noise;

                    %% Receiver

                    decodedPayload = adaptive_link_receiver( ...
                        rxSymbols, ...
                        hSymbols, ...
                        N0, ...
                        txInfo);

                    decodedPayload = decodedPayload(:);

                    %% Payload error counting

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

                    packetErrors = ...
                        packetErrors + double(packetError);

                end

                %% Metrics

                measuredBER = totalBitErrors / ...
                    (payloadLength * numValidationPackets);

                measuredPER = ...
                    packetErrors / numValidationPackets;

                [perLower, perUpper] = ...
                    local_wilson_interval( ...
                        packetErrors, ...
                        numValidationPackets);

                %% Save result in memory

                rowIndex = rowIndex + 1;

                Channel(rowIndex) = string(channelType);
                Modulation(rowIndex) = string(modulation);

                EbN0_dB(rowIndex) = currentEbN0dB;

                BitsPerSymbol(rowIndex) = txInfo.BitsPerSymbol;

                CodeRate(rowIndex) = ...
                    txInfo.NominalConvolutionalRate;

                InterleaverDepth(rowIndex) = depth;

                BER(rowIndex) = measuredBER;
                PER(rowIndex) = measuredPER;

                PER_Lower95(rowIndex) = perLower;
                PER_Upper95(rowIndex) = perUpper;

                PacketErrors(rowIndex) = packetErrors;
                NumPackets(rowIndex) = numValidationPackets;

                EffectiveSpectralEfficiency(rowIndex) = ...
                    payloadLength / numSymbols;

                fprintf('BER = %.5e | PER = %.4f | Upper95 = %.4f\n', ...
                    measuredBER, measuredPER, perUpper);

            end

        end

    end

end

%% 7. Construct independent validation table

QoS_Met_Validation = PER_Upper95 <= targetPER;

ValidationResults = table( ...
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
    QoS_Met_Validation);

%% 8. Evaluate the previously selected adaptive profiles

adaptiveIndices = zeros(height(AdaptivePolicy),1);

for k = 1:height(AdaptivePolicy)

    hit = ...
        ValidationResults.Channel == AdaptivePolicy.Channel(k) & ...
        ValidationResults.EbN0_dB == AdaptivePolicy.EbN0_dB(k) & ...
        ValidationResults.Modulation == AdaptivePolicy.SelectedModulation(k) & ...
        ValidationResults.InterleaverDepth == ...
            AdaptivePolicy.SelectedInterleaverDepth(k);

    matchingRows = find(hit);

    if numel(matchingRows) ~= 1
        error('Could not uniquely locate adaptive profile at row %d.', k);
    end

    adaptiveIndices(k) = matchingRows;

end

AdaptiveValidation = ValidationResults(adaptiveIndices,:);

% Preserve corresponding calibration results for comparison.
AdaptiveValidation.CalibrationPER = ...
    AdaptivePolicy.CalibrationPER;

AdaptiveValidation.CalibrationPER_Upper95 = ...
    AdaptivePolicy.PER_Upper95;

AdaptiveValidation.CalibrationQoS_Met = ...
    AdaptivePolicy.QoS_Met;

AdaptiveValidation.QoS_Status_Changed = ...
    AdaptiveValidation.CalibrationQoS_Met ~= ...
    AdaptiveValidation.QoS_Met_Validation;

%% 9. Build fixed-baseline comparisons

baselineNames = [
    "Adaptive MCS"
    "Fixed BPSK-D16"
    "Fixed QPSK-D16"
    "Fixed 16QAM-D16"
];

numMethods = numel(baselineNames);

MeanBER = zeros(numMethods,1);
MeanPER = zeros(numMethods,1);
MeanPER_Upper95 = zeros(numMethods,1);

MeanSpectralEfficiency = zeros(numMethods,1);

QoS_OperatingPoints = zeros(numMethods,1);
TotalOperatingPoints = zeros(numMethods,1);

for methodIndex = 1:numMethods

    switch methodIndex

        case 1

            currentTable = AdaptiveValidation;

        case 2

            currentTable = ValidationResults( ...
                ValidationResults.Modulation == "BPSK" & ...
                ValidationResults.InterleaverDepth == 16,:);

        case 3

            currentTable = ValidationResults( ...
                ValidationResults.Modulation == "QPSK" & ...
                ValidationResults.InterleaverDepth == 16,:);

        case 4

            currentTable = ValidationResults( ...
                ValidationResults.Modulation == "16QAM" & ...
                ValidationResults.InterleaverDepth == 16,:);

    end

    if height(currentTable) ~= ...
            numel(channelTypes) * numel(EbN0dBList)

        error('Unexpected number of rows in baseline: %s', ...
            baselineNames(methodIndex));

    end

    MeanBER(methodIndex) = mean(currentTable.BER);

    MeanPER(methodIndex) = mean(currentTable.PER);

    % This is the mean of point-wise upper confidence bounds,
    % not a single global 95%% confidence interval.
    MeanPER_Upper95(methodIndex) = ...
        mean(currentTable.PER_Upper95);

    MeanSpectralEfficiency(methodIndex) = ...
        mean(currentTable.EffectiveSpectralEfficiency);

    QoS_OperatingPoints(methodIndex) = ...
        sum(currentTable.QoS_Met_Validation);

    TotalOperatingPoints(methodIndex) = ...
        height(currentTable);

end

ValidationSummary = table( ...
    baselineNames, ...
    MeanBER, ...
    MeanPER, ...
    MeanPER_Upper95, ...
    MeanSpectralEfficiency, ...
    QoS_OperatingPoints, ...
    TotalOperatingPoints, ...
    'VariableNames', {
        'Method'
        'MeanBER'
        'MeanPER'
        'MeanPointwisePER_Upper95'
        'MeanEffectiveSpectralEfficiency'
        'QoS_OperatingPoints'
        'TotalOperatingPoints'
    });

%% 10. Internal consistency checks

expectedProfiles = ...
    numel(channelTypes) * ...
    numel(EbN0dBList) * ...
    numel(modulationTypes) * ...
    numel(interleaverDepths);

expectedOperatingPoints = ...
    numel(channelTypes) * numel(EbN0dBList);

assert(height(ValidationResults) == expectedProfiles, ...
    'Unexpected number of independent profile measurements.');

assert(height(AdaptiveValidation) == expectedOperatingPoints, ...
    'Unexpected number of adaptive operating points.');

assert(all(AdaptiveValidation.InterleaverDepth == ...
    AdaptivePolicy.SelectedInterleaverDepth), ...
    'Adaptive interleaver-depth mapping mismatch.');

assert(all(AdaptiveValidation.Modulation == ...
    AdaptivePolicy.SelectedModulation), ...
    'Adaptive modulation mapping mismatch.');

fprintf('Internal consistency checks passed.\n');
%% 11. Save validation configuration

validationConfig = struct();

validationConfig.PayloadLength = payloadLength;
validationConfig.NumPackets = numValidationPackets;
validationConfig.RandomSeed = validationSeed;

validationConfig.EbN0dBList = EbN0dBList;
validationConfig.ChannelTypes = channelTypes;

validationConfig.ModulationTypes = modulationTypes;
validationConfig.InterleaverDepths = interleaverDepths;

validationConfig.NumFadingBlocks = numFadingBlocks;
validationConfig.RicianKFactor_dB = ricianKFactor_dB;

validationConfig.TargetPER = targetPER;
validationConfig.ConfidenceLevel = confidenceLevel;

validationConfig.CSI = 'Perfect CSI';

validationConfig.EbN0Definition = ...
    'Energy per information payload bit';

validationConfig.DataDescription = ...
    'Independent payload, fading and AWGN realizations';

%% 12. Save outputs

resultsDir = fullfile(projectRoot, 'results');
figuresDir = fullfile(resultsDir, 'figures');

if exist(resultsDir,'dir') ~= 7
    mkdir(resultsDir);
end

if exist(figuresDir,'dir') ~= 7
    mkdir(figuresDir);
end

writetable( ...
    ValidationResults, ...
    fullfile(resultsDir, 'adaptive_mcs_validation_all_profiles.csv'));

writetable( ...
    AdaptiveValidation, ...
    fullfile(resultsDir, 'adaptive_mcs_validation_selected.csv'));

writetable( ...
    ValidationSummary, ...
    fullfile(resultsDir, 'adaptive_mcs_validation_summary.csv'));

save( ...
    fullfile(resultsDir, 'adaptive_mcs_validation.mat'), ...
    'ValidationResults', ...
    'AdaptiveValidation', ...
    'ValidationSummary', ...
    'validationConfig');

%% 13. Plot independent PER results

figure('Name','Independent MCS Validation');

for channelIndex = 1:numel(channelTypes)

    channelType = string(channelTypes{channelIndex});

    subplot(1,2,channelIndex);

    hold on;
    grid on;

    for m = 1:numel(modulationTypes)

        for d = 1:numel(interleaverDepths)

            modulation = string(modulationTypes{m});
            depth = interleaverDepths(d);

            hit = ...
                ValidationResults.Channel == channelType & ...
                ValidationResults.Modulation == modulation & ...
                ValidationResults.InterleaverDepth == depth;

            currentTable = ValidationResults(hit,:);

            [sortedSNR, order] = sort(currentTable.EbN0_dB);

            sortedPER = currentTable.PER(order);

            plotPER = max(sortedPER, 0.5/numValidationPackets);

            semilogy( ...
                sortedSNR, ...
                plotPER, ...
                '-o', ...
                'LineWidth',1.2, ...
                'DisplayName', ...
                sprintf('%s-D%d', modulation, depth));

        end

    end

    yline(targetPER, '--', 'Target PER');

    xlabel('E_b/N_0 (dB)');
    ylabel('Packet Error Rate');

    title(upper(channelType));

    legend('Location','best');

    ylim([max(0.5/numValidationPackets,1e-4), 1]);

end

sgtitle('Independent Adaptive MCS Validation');

saveas( ...
    gcf, ...
    fullfile(figuresDir, 'adaptive_mcs_validation_per.png'));

%% 14. Display final results

fprintf('\n');
fprintf('===============================================\n');
fprintf(' ADAPTIVE MCS INDEPENDENT VALIDATION\n');
fprintf('===============================================\n');

disp(AdaptiveValidation);

fprintf('\n');
fprintf('===============================================\n');
fprintf(' FIXED BASELINE COMPARISON\n');
fprintf('===============================================\n');

disp(ValidationSummary);

fprintf('\n');
fprintf('Calibration QoS vs Independent Validation QoS:\n');

fprintf('Calibration QoS points: %d / %d\n', ...
    sum(AdaptiveValidation.CalibrationQoS_Met), ...
    height(AdaptiveValidation));

fprintf('Validation QoS points : %d / %d\n', ...
    sum(AdaptiveValidation.QoS_Met_Validation), ...
    height(AdaptiveValidation));

fprintf('\nValidation files saved in:\n%s\n', resultsDir);

fprintf('\nIndependent validation completed.\n');


%% =========================================================
%  LOCAL FUNCTIONS
%% =========================================================

function fadingBank = local_generate_fading_bank( ...
    channelType, numBlocks, numPackets, ricianKFactor_dB)

    switch lower(channelType)

        case 'rayleigh'

            fadingBank = ( ...
                randn(numBlocks,numPackets) + ...
                1i*randn(numBlocks,numPackets)) / sqrt(2);

        case 'rician'

            K = 10^(ricianKFactor_dB/10);

            LOSComponent = sqrt(K/(K+1));

            scatteredPower = sqrt(1/(K+1));

            scatteredComponent = ( ...
                randn(numBlocks,numPackets) + ...
                1i*randn(numBlocks,numPackets)) / sqrt(2);

            fadingBank = ...
                LOSComponent + ...
                scatteredPower .* scatteredComponent;

        otherwise

            error('Unsupported channel type: %s', channelType);

    end

end


function [lowerBound, upperBound] = ...
    local_wilson_interval(errors, trials)

    z = 1.959963984540054;

    p = errors/trials;

    denominator = 1 + z^2/trials;

    center = (p + z^2/(2*trials)) / denominator;

    halfWidth = ...
        (z/denominator) * ...
        sqrt(p*(1-p)/trials + z^2/(4*trials^2));

    lowerBound = max(0, center-halfWidth);

    upperBound = min(1, center+halfWidth);

end
