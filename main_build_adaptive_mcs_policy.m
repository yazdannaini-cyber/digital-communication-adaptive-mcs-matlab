clc;
clear;
close all;

%% =========================================================
%  MILESTONE 31.7
%  BUILD UPDATED ADAPTIVE MCS POLICY
%
%  Uses empirical calibration data.
%
%  QoS target:
%       PER upper 95% confidence bound <= 0.20
%
%  First-column readiness limit:
%       2 ms
%
%  Best-effort fallback PER margin:
%       0.02
%% =========================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf(' UPDATED ADAPTIVE MCS POLICY GENERATION\n');
fprintf('=============================================\n\n');

%% 1. Project setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));

rehash;

%% 2. Load empirical calibration data

calibrationPath = fullfile( ...
    projectRoot, ...
    'results', ...
    'mcs_profile_calibration.mat');

if exist(calibrationPath, 'file') ~= 2

    error('Calibration file not found: %s', calibrationPath);

end

S = load( ...
    calibrationPath, ...
    'ProfileTable', ...
    'calibrationConfig');

if ~isfield(S, 'ProfileTable')

    error('ProfileTable is missing from calibration MAT file.');

end

if ~isfield(S, 'calibrationConfig')

    error('calibrationConfig is missing from calibration MAT file.');

end

ProfileTable = S.ProfileTable;

calibrationConfig = S.calibrationConfig;

%% 3. Policy parameters

targetPER = calibrationConfig.TargetPER;

maxFirstColumnReady_ms = 2.0;

fallbackPERMargin = 0.02;

fprintf('Target PER                 : %.3f\n', targetPER);

fprintf('Maximum first-column time  : %.3f ms\n', ...
    maxFirstColumnReady_ms);

fprintf('Fallback PER margin        : %.3f\n', ...
    fallbackPERMargin);

fprintf('Calibration rows           : %d\n', ...
    height(ProfileTable));

%% 4. Generate adaptive MCS policy

[AdaptivePolicy, SelectedProfiles] = ...
    build_adaptive_mcs_policy( ...
        ProfileTable, ...
        targetPER, ...
        maxFirstColumnReady_ms, ...
        fallbackPERMargin);

%% 5. Display policy table

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ADAPTIVE MCS POLICY\n');
fprintf('=============================================\n\n');

fprintf('Number of operating points: %d\n\n', ...
    height(AdaptivePolicy));

disp(AdaptivePolicy);

%% 6. Create results directory

resultsDir = fullfile(projectRoot, 'results');

if exist(resultsDir, 'dir') ~= 7

    mkdir(resultsDir);

end

%% 7. Save policy CSV

csvPath = fullfile( ...
    resultsDir, ...
    'adaptive_mcs_policy.csv');

writetable(AdaptivePolicy, csvPath);

%% 8. Save policy MAT

matPath = fullfile( ...
    resultsDir, ...
    'adaptive_mcs_policy.mat');

save( ...
    matPath, ...
    'AdaptivePolicy', ...
    'SelectedProfiles', ...
    'targetPER', ...
    'maxFirstColumnReady_ms', ...
    'fallbackPERMargin');

%% 9. Display QoS summary

fprintf('\n');
fprintf('=============================================\n');
fprintf(' QOS SUMMARY\n');
fprintf('=============================================\n\n');

for k = 1:height(AdaptivePolicy)

    fprintf([ ...
        '%-9s | %2.0f dB | %-6s | Depth %2.0f | ', ...
        'PER Upper95 = %.4f | QoS: %d | %s\n'], ...
        char(AdaptivePolicy.Channel(k)), ...
        AdaptivePolicy.EbN0_dB(k), ...
        char(AdaptivePolicy.SelectedModulation(k)), ...
        AdaptivePolicy.SelectedInterleaverDepth(k), ...
        AdaptivePolicy.PER_Upper95(k), ...
        AdaptivePolicy.QoS_Met(k), ...
        char(AdaptivePolicy.SelectionMode(k)));

end

%% 10. Summary statistics

numOperatingPoints = height(AdaptivePolicy);

numQoSPoints = sum(AdaptivePolicy.QoS_Met);

numDelayPoints = sum(AdaptivePolicy.Delay_Met);

fprintf('\n');
fprintf('=============================================\n');
fprintf(' POLICY SUMMARY\n');
fprintf('=============================================\n');

fprintf('Total operating points : %d\n', numOperatingPoints);

fprintf('QoS-compliant points   : %d / %d\n', ...
    numQoSPoints, numOperatingPoints);

fprintf('Delay-compliant points : %d / %d\n', ...
    numDelayPoints, numOperatingPoints);

fprintf('Average selected PER   : %.5f\n', ...
    mean(AdaptivePolicy.CalibrationPER));

fprintf('Average PER Upper95    : %.5f\n', ...
    mean(AdaptivePolicy.PER_Upper95));

fprintf('Average spectral eff.  : %.5f bit/s/Hz\n', ...
    mean(AdaptivePolicy.EffectiveSpectralEfficiency));

%% 11. Confirm saved files

fprintf('\n');
fprintf('Policy CSV saved:\n%s\n', csvPath);

fprintf('\n');
fprintf('Policy MAT saved:\n%s\n', matPath);

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ADAPTIVE MCS POLICY GENERATED SUCCESSFULLY\n');
fprintf('=============================================\n');