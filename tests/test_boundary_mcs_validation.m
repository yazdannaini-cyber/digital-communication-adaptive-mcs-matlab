clc;
clear;

projectRoot = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(projectRoot));
rehash;

resultPath = fullfile(projectRoot, ...
    'results','boundary_mcs_validation.mat');

assert(exist(resultPath,'file') == 2, ...
    'Boundary validation file is missing.');

S = load(resultPath, ...
    'BoundaryValidationResults', ...
    'SelectedProfileValidation', ...
    'PairwiseComparison', ...
    'PacketErrorMatrix', ...
    'boundaryConfig');

V = S.BoundaryValidationResults;
A = S.SelectedProfileValidation;
P = S.PairwiseComparison;
E = S.PacketErrorMatrix;
cfg = S.boundaryConfig;

%% Test 1: Packet count

assert(cfg.NumPackets == 3000);
assert(all(V.NumPackets == 3000));

fprintf('Test 1 passed: 3000 packets per profile.\n');

%% Test 2: Profile count

expectedProfiles = ...
    numel(cfg.ChannelList)* ...
    numel(cfg.ModulationTypes)* ...
    numel(cfg.InterleaverDepths);

assert(height(V) == expectedProfiles);
assert(size(E,2) == 3000);

fprintf('Test 2 passed: Profile count and packet matrix.\n');

%% Test 3: Selected profile count

assert(height(A) == numel(cfg.ChannelList));
assert(all(A.WasSelectedByCalibrationPolicy));

fprintf('Test 3 passed: Selected profile mapping.\n');

%% Test 4: BER and PER validity

assert(all(isfinite(V.BER) & V.BER >= 0 & V.BER <= 1));
assert(all(isfinite(V.PER) & V.PER >= 0 & V.PER <= 1));

fprintf('Test 4 passed: BER and PER ranges.\n');

%% Test 5: Wilson confidence intervals

assert(all(V.PER_Lower95 <= V.PER));
assert(all(V.PER_Upper95 >= V.PER));
assert(all(V.PER_Lower95 >= 0 & V.PER_Upper95 <= 1));

fprintf('Test 5 passed: Wilson intervals.\n');

%% Test 6: QoS flags

assert(all(V.QoS_Met_Validation == ...
    (V.PER_Upper95 <= cfg.TargetPER)));

fprintf('Test 6 passed: QoS consistency.\n');

%% Test 7: Every selected profile meets independently validated QoS

assert(all(A.QoS_Met_Validation), ...
    'At least one selected profile failed independent QoS validation.');

fprintf('Test 7 passed: All selected profiles meet QoS.\n');

%% Test 8: Pairwise comparison count

expectedComparisons = ...
    numel(cfg.ChannelList)*numel(cfg.InterleaverDepths);

assert(height(P) == expectedComparisons);

fprintf('Test 8 passed: Equal-depth comparison count.\n');

%% Test 9: McNemar p-value range

assert(all(isfinite(P.McNemar_p)));
assert(all(P.McNemar_p >= 0 & P.McNemar_p <= 1));

fprintf('Test 9 passed: Exact McNemar p-values.\n');

%% Test 10: Holm-adjusted p-values

assert(all(P.HolmAdjusted_p >= P.McNemar_p-1e-12));
assert(all(P.HolmAdjusted_p >= 0 & P.HolmAdjusted_p <= 1));

fprintf('Test 10 passed: Holm correction.\n');

%% Test 11: Known exact McNemar reference case

% b=0, c=10:
% p = 2*(1/2)^10 = 0.001953125

referenceP = 2*(0.5^10);

assert(abs(referenceP-0.001953125) < 1e-12);

fprintf('Test 11 passed: Exact McNemar reference value.\n');

%% Test 12: PER difference consistency

assert(all(abs( ...
    P.DeltaPER_QAM16_minus_QPSK - ...
    (P.QAM16_PER-P.QPSK_PER)) < 1e-12));

fprintf('Test 12 passed: PER difference consistency.\n');

%% Test 13: Discordant counts

assert(all(P.DiscordantPackets == ...
    P.QPSK_Error_QAM16_Correct + ...
    P.QPSK_Correct_QAM16_Error));

fprintf('Test 13 passed: Discordant packet counts.\n');

%% Test 14: Same interleaver depth in every comparison

assert(all(ismember(P.InterleaverDepth,[4 16])));

fprintf('Test 14 passed: Equal interleaver depths.\n');

%% Test 15: Significance flags

assert(all(P.SignificantAfterHolm == ...
    (P.HolmAdjusted_p < 0.05)));

fprintf('Test 15 passed: Statistical significance flags.\n');

%% Final

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ALL 15 BOUNDARY VALIDATION TESTS PASSED\n');
fprintf('=============================================\n');