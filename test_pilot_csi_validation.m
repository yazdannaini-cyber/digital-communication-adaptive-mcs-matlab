clc;
clear;

projectRoot = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(projectRoot));
rehash;

resultPath = fullfile(projectRoot, ...
    'results','pilot_csi_validation.mat');

assert(exist(resultPath,'file') == 2, ...
    'Pilot CSI result file is missing.');

S = load(resultPath, ...
    'PilotResults', ...
    'PairwiseCSIComparison', ...
    'PerfectCSI_PacketErrors', ...
    'EstimatedCSI_PacketErrors', ...
    'pilotConfig');

T = S.PilotResults;
P = S.PairwiseCSIComparison;

%% Test 1: Nine operating points

assert(height(T) == 9);
fprintf('Test 1 passed: Nine operating points.\n');

%% Test 2: 3000 packets

assert(S.pilotConfig.NumPackets == 3000);
fprintf('Test 2 passed: Packet count.\n');

%% Test 3: Pilot configuration

assert(S.pilotConfig.PilotLengthPerBlock == 16);
assert(S.pilotConfig.TotalPilotSymbols == 64);
fprintf('Test 3 passed: Pilot configuration.\n');

%% Test 4: Channel estimation NMSE

assert(all(isfinite(T.ChannelEstimationNMSE)));
assert(all(T.ChannelEstimationNMSE >= 0));
fprintf('Test 4 passed: Channel NMSE.\n');

%% Test 5: PER ranges

assert(all(T.PerfectCSI_PER >= 0 & T.PerfectCSI_PER <= 1));
assert(all(T.EstimatedCSI_PER >= 0 & T.EstimatedCSI_PER <= 1));
fprintf('Test 5 passed: PER ranges.\n');

%% Test 6: Confidence intervals

assert(all(T.PerfectCSI_PER_Lower95 <= T.PerfectCSI_PER));
assert(all(T.PerfectCSI_PER_Upper95 >= T.PerfectCSI_PER));

assert(all(T.EstimatedCSI_PER_Lower95 <= T.EstimatedCSI_PER));
assert(all(T.EstimatedCSI_PER_Upper95 >= T.EstimatedCSI_PER));
fprintf('Test 6 passed: Wilson intervals.\n');

%% Test 7: QoS flags

assert(all(T.PerfectCSI_QoS == ...
    (T.PerfectCSI_PER_Upper95 <= S.pilotConfig.TargetPER)));

assert(all(T.EstimatedCSI_QoS == ...
    (T.EstimatedCSI_PER_Upper95 <= S.pilotConfig.TargetPER)));

fprintf('Test 7 passed: QoS flags.\n');

%% Test 8: Pilot overhead

assert(all(T.PilotOverheadPercent > 0));
assert(all(T.PilotOverheadPercent < 100));
fprintf('Test 8 passed: Pilot overhead.\n');

%% Test 9: Spectral efficiency

assert(all(T.PilotSpectralEfficiency > 0));

assert(all(T.PilotSpectralEfficiency < ...
    T.IdealSpectralEfficiency));

fprintf('Test 9 passed: Pilot spectral efficiency.\n');

%% Test 10: Paired comparison count

assert(height(P) == 9);
fprintf('Test 10 passed: Paired comparison count.\n');

%% Test 11: Statistical values

assert(all(P.McNemar_p >= 0 & P.McNemar_p <= 1));

assert(all(P.HolmAdjusted_p >= P.McNemar_p-1e-12));

fprintf('Test 11 passed: Statistical comparison.\n');

%% Test 12: Packet error matrices

assert(isequal(size(S.PerfectCSI_PacketErrors),[9 3000]));

assert(isequal(size(S.EstimatedCSI_PacketErrors),[9 3000]));

fprintf('Test 12 passed: Packet-level data preservation.\n');

fprintf('\n=============================================\n');
fprintf(' ALL 12 PILOT CSI TESTS PASSED\n');
fprintf('=============================================\n');