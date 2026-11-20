clc;
clear;

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
rehash;

%% Load existing 3000-packet results

resultPath = fullfile(projectRoot, ...
    'results', 'boundary_mcs_validation.mat');

assert(exist(resultPath,'file') == 2, ...
    'Boundary validation file not found.');

S = load(resultPath, ...
    'BoundaryValidationResults', ...
    'PacketErrorMatrix', ...
    'boundaryConfig');

T = S.BoundaryValidationResults;
E = S.PacketErrorMatrix;

assert(size(E,1) == height(T), ...
    'Packet error matrix row mismatch.');

%% Identify operating points

pointLabels = string(T.Channel) + "_" + string(T.EbN0_dB);

firstRows = find([true; ...
    pointLabels(2:end) ~= pointLabels(1:end-1)]);

numPoints = numel(firstRows);
depths = [4 16];

numComparisons = numPoints * numel(depths);

%% Preallocate

Channel = strings(numComparisons,1);
EbN0_dB = zeros(numComparisons,1);
InterleaverDepth = zeros(numComparisons,1);

QPSK_PER = zeros(numComparisons,1);
QAM16_PER = zeros(numComparisons,1);

DeltaPER_QAM16_minus_QPSK = zeros(numComparisons,1);

QPSK_Error_QAM16_Correct = zeros(numComparisons,1);
QPSK_Correct_QAM16_Error = zeros(numComparisons,1);

DiscordantPackets = zeros(numComparisons,1);

McNemar_p = zeros(numComparisons,1);

%% Perform paired comparisons at equal interleaver depths

r = 0;

for p = 1:numPoints

    currentChannel = T.Channel(firstRows(p));
    currentSNR = T.EbN0_dB(firstRows(p));

    for d = 1:numel(depths)

        depth = depths(d);

        qpskHit = ...
            T.Channel == currentChannel & ...
            T.EbN0_dB == currentSNR & ...
            T.Modulation == "QPSK" & ...
            T.InterleaverDepth == depth;

        qamHit = ...
            T.Channel == currentChannel & ...
            T.EbN0_dB == currentSNR & ...
            T.Modulation == "16QAM" & ...
            T.InterleaverDepth == depth;

        assert(nnz(qpskHit) == 1 && nnz(qamHit) == 1, ...
            'Could not uniquely match comparison profiles.');

        qpskRow = find(qpskHit,1);
        qamRow = find(qamHit,1);

        qpskErrors = E(qpskRow,:);
        qamErrors = E(qamRow,:);

        % Discordant paired packet outcomes
        b = sum(qpskErrors & ~qamErrors);
        c = sum(~qpskErrors & qamErrors);

        r = r+1;

        Channel(r) = currentChannel;
        EbN0_dB(r) = currentSNR;
        InterleaverDepth(r) = depth;

        QPSK_PER(r) = T.PER(qpskRow);
        QAM16_PER(r) = T.PER(qamRow);

        DeltaPER_QAM16_minus_QPSK(r) = ...
            T.PER(qamRow)-T.PER(qpskRow);

        QPSK_Error_QAM16_Correct(r) = b;
        QPSK_Correct_QAM16_Error(r) = c;

        DiscordantPackets(r) = b+c;

        McNemar_p(r) = local_exact_mcnemar(b,c);

    end

end

%% Holm-Bonferroni correction across all 18 comparisons

HolmAdjusted_p = local_holm_adjust(McNemar_p);

SignificantAfterHolm = HolmAdjusted_p < 0.05;

%% Construct comparison table

PairwiseComparison = table( ...
    Channel, ...
    EbN0_dB, ...
    InterleaverDepth, ...
    QPSK_PER, ...
    QAM16_PER, ...
    DeltaPER_QAM16_minus_QPSK, ...
    QPSK_Error_QAM16_Correct, ...
    QPSK_Correct_QAM16_Error, ...
    DiscordantPackets, ...
    McNemar_p, ...
    HolmAdjusted_p, ...
    SignificantAfterHolm);

%% Save corrected statistical results

csvPath = fullfile(projectRoot, ...
    'results', 'boundary_mcs_pairwise_comparison.csv');

writetable(PairwiseComparison,csvPath);

save(resultPath,'PairwiseComparison','-append');

%% Display

fprintf('\n');
fprintf('===============================================\n');
fprintf(' CORRECTED PAIRED MCS COMPARISON\n');
fprintf('===============================================\n\n');

disp(PairwiseComparison);

fprintf('\nNumber of significant comparisons after Holm: %d / %d\n', ...
    sum(SignificantAfterHolm),numComparisons);

fprintf('Results saved successfully.\n');

%% =========================================================
% Exact two-sided McNemar test
%% =========================================================

function p = local_exact_mcnemar(b,c)

    n = b+c;

    if n == 0
        p = 1;
        return;
    end

    k = min(b,c);

    % Correct exact two-sided test:
    % 2 * P(X <= min(b,c)), X ~ Binomial(n,0.5)

    x = 0:k;

    logProb = ...
        gammaln(n+1) - ...
        gammaln(x+1) - ...
        gammaln(n-x+1) - ...
        n*log(2);

    maxLog = max(logProb);

    lowerTail = ...
        exp(maxLog)*sum(exp(logProb-maxLog));

    p = min(1,2*lowerTail);

end

%% =========================================================
% Holm-Bonferroni correction
%% =========================================================

function adjustedP = local_holm_adjust(pValues)

    pValues = pValues(:);

    m = numel(pValues);

    [sortedP,order] = sort(pValues);

    adjustedSorted = zeros(m,1);

    runningMaximum = 0;

    for k = 1:m

        currentValue = (m-k+1)*sortedP(k);

        runningMaximum = max(runningMaximum,currentValue);

        adjustedSorted(k) = min(1,runningMaximum);

    end

    adjustedP = zeros(m,1);

    adjustedP(order) = adjustedSorted;

end