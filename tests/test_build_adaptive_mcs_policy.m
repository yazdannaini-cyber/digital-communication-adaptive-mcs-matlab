
clc;
clear;

%% =========================================================
%  ADAPTIVE MCS POLICY TEST SUITE
%  Supports extended SNR calibration ranges.
%% =========================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ADAPTIVE MCS POLICY TEST SUITE\n');
fprintf('=============================================\n\n');

%% 1. Project setup

projectRoot = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(projectRoot));
rehash;

%% 2. Load calibration data

calibrationPath = fullfile( ...
    projectRoot, 'results', 'mcs_profile_calibration.mat');

assert(exist(calibrationPath, 'file') == 2, ...
    'Calibration file does not exist.');

S = load(calibrationPath, ...
    'ProfileTable', 'calibrationConfig');

ProfileTable = S.ProfileTable;

targetPER = S.calibrationConfig.TargetPER;

maxReady_ms = 2.0;

fallbackPERMargin = 0.02;

%% 3. Build policy

[policyTable, selectedRows] = ...
    build_adaptive_mcs_policy( ...
        ProfileTable, ...
        targetPER, ...
        maxReady_ms, ...
        fallbackPERMargin);

channelNames = lower(strtrim(string(ProfileTable.Channel)));

modulationNames = upper(strtrim(string(ProfileTable.Modulation)));

%% TEST 1: Expected operating-point count

expectedOperatingPoints = ...
    numel(unique(channelNames)) * ...
    numel(unique(ProfileTable.EbN0_dB));

assert(height(policyTable) == expectedOperatingPoints, ...
    'Incorrect number of operating points.');

fprintf('Test 1 passed: Operating-point count.\n');

%% TEST 2: Expected selected-row count

assert(height(selectedRows) == height(policyTable), ...
    'Selected calibration rows do not match policy rows.');

fprintf('Test 2 passed: Selected-row count.\n');

%% TEST 3: Selected profile mapping

assert(all(lower(strtrim(string(selectedRows.Channel))) == ...
    policyTable.Channel), ...
    'Selected channel mapping mismatch.');

assert(all(selectedRows.EbN0_dB == policyTable.EbN0_dB), ...
    'Selected SNR mapping mismatch.');

assert(all(upper(strtrim(string(selectedRows.Modulation))) == ...
    policyTable.SelectedModulation), ...
    'Selected modulation mapping mismatch.');

assert(all(selectedRows.InterleaverDepth == ...
    policyTable.SelectedInterleaverDepth), ...
    'Selected interleaver mapping mismatch.');

fprintf('Test 3 passed: Selected-profile mapping.\n');

%% TEST 4: Readiness constraints

assert(all(policyTable.FirstColumnReady_ms >= 0), ...
    'Negative readiness time found.');

assert(all(policyTable.Delay_Met == ...
    (policyTable.FirstColumnReady_ms <= maxReady_ms)), ...
    'Readiness flags are inconsistent.');

fprintf('Test 4 passed: Readiness constraints.\n');

%% TEST 5: QoS flag consistency

assert(all(~policyTable.QoS_Met | ...
    (policyTable.PER_Upper95 <= targetPER)), ...
    'QoS declared satisfied with an invalid PER bound.');

fprintf('Test 5 passed: QoS confidence-bound consistency.\n');

%% TEST 6: Validate the selection rule at every operating point

for k = 1:height(policyTable)

    currentChannel = policyTable.Channel(k);
    currentSNR = policyTable.EbN0_dB(k);

    group = find( ...
        channelNames == currentChannel & ...
        ProfileTable.EbN0_dB == currentSNR);

    latencyCandidates = group( ...
        ProfileTable.FirstColumnReady_ms(group) <= maxReady_ms);

    selectedRow = selectedRows(k,:);

    if isempty(latencyCandidates)

        % No profile meets the readiness constraint.
        [~, bestLocal] = min( ...
            ProfileTable.FirstColumnReady_ms(group));

        bestRow = group(bestLocal);

        assert(policyTable.Delay_Met(k) == false, ...
            'Readiness fallback was not marked correctly.');

        assert(selectedRows.FirstColumnReady_ms(k) == ...
            ProfileTable.FirstColumnReady_ms(bestRow), ...
            'Readiness fallback did not choose minimum readiness.');

    else

        qosCandidates = latencyCandidates( ...
            ProfileTable.PER_Upper95(latencyCandidates) <= targetPER);

        if ~isempty(qosCandidates)

            % QoS-compliant branch:
            % selected profile must meet QoS and maximize efficiency.

            assert(policyTable.QoS_Met(k), ...
                'QoS-compliant candidate existed but was not selected.');

            bestEfficiency = max( ...
                ProfileTable.EffectiveSpectralEfficiency(qosCandidates));

            assert(abs( ...
                selectedRow.EffectiveSpectralEfficiency - bestEfficiency) ...
                < 1e-10, ...
                'QoS branch did not maximize spectral efficiency.');

        else

            % Best-effort branch:
            % selected profile must remain within the configured
            % PER margin and maximize efficiency in that candidate set.

            assert(~policyTable.QoS_Met(k), ...
                'QoS was incorrectly declared satisfied.');

            minPERUpper = min( ...
                ProfileTable.PER_Upper95(latencyCandidates));

            eligible = latencyCandidates( ...
                ProfileTable.PER_Upper95(latencyCandidates) ...
                <= minPERUpper + fallbackPERMargin + 1e-12);

            assert( ...
                selectedRow.PER_Upper95 <= ...
                minPERUpper + fallbackPERMargin + 1e-12, ...
                'Fallback candidate violates PER margin.');

            bestEfficiency = max( ...
                ProfileTable.EffectiveSpectralEfficiency(eligible));

            assert(abs( ...
                selectedRow.EffectiveSpectralEfficiency - bestEfficiency) ...
                < 1e-10, ...
                'Fallback branch did not maximize spectral efficiency.');

        end

    end

end

fprintf('Test 6 passed: Selection logic at all operating points.\n');

%% TEST 7: Fallback PER margin

fallbackRows = ~policyTable.QoS_Met & policyTable.Delay_Met;

assert(all(policyTable.PER_Upper95(fallbackRows) <= ...
    policyTable.FallbackPERLimit_Upper95(fallbackRows) + 1e-12), ...
    'Fallback PER margin violation.');

assert(all(policyTable.FallbackPERLimit_Upper95(fallbackRows) <= 1), ...
    'Fallback PER limit exceeds one.');

fprintf('Test 7 passed: Fallback PER margin.\n');

%% TEST 8: Supported modulation types

validModulations = ["BPSK","QPSK","16QAM"];

assert(all(ismember( ...
    policyTable.SelectedModulation, validModulations)), ...
    'Unsupported modulation selected.');

fprintf('Test 8 passed: Supported modulation types.\n');

%% TEST 9: Positive effective spectral efficiency

assert(all(policyTable.EffectiveSpectralEfficiency > 0), ...
    'Invalid effective spectral efficiency.');

fprintf('Test 9 passed: Spectral efficiency.\n');

%% TEST 10: Default fallback margin

[defaultPolicy, ~] = ...
    build_adaptive_mcs_policy( ...
        ProfileTable, ...
        targetPER, ...
        maxReady_ms);

assert(height(defaultPolicy) == height(policyTable), ...
    'Default policy has incorrect dimensions.');

assert(all(defaultPolicy.SelectedModulation == ...
    policyTable.SelectedModulation), ...
    'Default fallback margin changed modulation selection.');

assert(all(defaultPolicy.SelectedInterleaverDepth == ...
    policyTable.SelectedInterleaverDepth), ...
    'Default fallback margin changed depth selection.');

fprintf('Test 10 passed: Default fallback margin.\n');

%% TEST 11: Invalid fallback margin must be rejected

invalidInputCaught = false;

try

    build_adaptive_mcs_policy( ...
        ProfileTable, ...
        targetPER, ...
        maxReady_ms, ...
        -0.01);

catch

    invalidInputCaught = true;

end

assert(invalidInputCaught, ...
    'Invalid fallback margin was not rejected.');

fprintf('Test 11 passed: Invalid input rejection.\n');

%% FINAL REPORT

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ALL 11 ADAPTIVE MCS POLICY TESTS PASSED\n');
fprintf('=============================================\n');
