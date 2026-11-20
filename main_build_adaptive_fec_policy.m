
clc;
clear;
close all;

%% Project setup

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));
rehash;

%% Load FEC comparison results

resultPath = fullfile(projectRoot, ...
    'results','fec_awgn_comparison.mat');

if exist(resultPath,'file') ~= 2
    error('FEC comparison file not found.');
end

S = load(resultPath,'FECResults','fecConfig');

FECResults = S.FECResults;

%% QoS target

targetPER = 0.10;

%% Build adaptive FEC policy

[AdaptiveFECPolicy,SelectedFECProfiles] = ...
    build_adaptive_fec_policy(FECResults,targetPER);

%% Display

fprintf('\n');
fprintf('=============================================\n');
fprintf(' ADAPTIVE FEC POLICY\n');
fprintf('=============================================\n');

fprintf('Target PER: %.3f\n',targetPER);

disp(AdaptiveFECPolicy);

%% Summary

fprintf('\nQoS-compliant points: %d / %d\n', ...
    sum(AdaptiveFECPolicy.QoS_Met), ...
    height(AdaptiveFECPolicy));

fprintf('FEC enabled points: %d / %d\n', ...
    sum(AdaptiveFECPolicy.FEC_Enabled), ...
    height(AdaptiveFECPolicy));

%% Save results

resultsDir = fullfile(projectRoot,'results');

csvPath = fullfile(resultsDir,'adaptive_fec_policy.csv');

matPath = fullfile(resultsDir,'adaptive_fec_policy.mat');

writetable(AdaptiveFECPolicy,csvPath);

save(matPath, ...
    'AdaptiveFECPolicy', ...
    'SelectedFECProfiles', ...
    'targetPER');

fprintf('\nPolicy CSV:\n%s\n',csvPath);

fprintf('\nPolicy MAT:\n%s\n',matPath);

fprintf('\nAdaptive FEC policy generated successfully.\n');
