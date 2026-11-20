
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

%% Calculate Thresholds

thresholds = calculate_amc_thresholds(1e-3);

%% Test 1: Zero Margin Must Match Original Selector

testSNR = thresholds.requiredEsN0_dB(2)+0.5;

[modeOriginal,~] = ...
    select_adaptive_modulation(testSNR,thresholds);

[modeRobust,~,guardedSNR] = ...
    select_robust_adaptive_modulation( ...
    testSNR,0,thresholds);

assert(modeOriginal==modeRobust);

assert(guardedSNR==testSNR);

fprintf('Test 1 passed: Zero margin compatibility.\n');

%% Test 2: Safety Margin Reduces Modulation Order

[modeOriginal,~] = ...
    select_adaptive_modulation(testSNR,thresholds);

[modeRobust,~,~] = ...
    select_robust_adaptive_modulation( ...
    testSNR,1,thresholds);

assert(modeOriginal==2);

assert(modeRobust==1);

fprintf('Test 2 passed: Conservative modulation selection.\n');

%% Test 3: High SNR with Zero Margin

[mode,~] = select_robust_adaptive_modulation( ...
    30,0,thresholds);

assert(mode==3);

fprintf('Test 3 passed: 16-QAM selection.\n');

%% Test 4: High SNR with Large Margin

[mode,~] = select_robust_adaptive_modulation( ...
    30,15,thresholds);

assert(mode==2);

fprintf('Test 4 passed: Margin effect on modulation order.\n');

%% Test 5: Outage Detection

[mode,name] = select_robust_adaptive_modulation( ...
    thresholds.requiredEsN0_dB(1)-0.1, ...
    0,thresholds);

assert(mode==0);

assert(strcmp(name,'OUTAGE'));

fprintf('Test 5 passed: Outage detection.\n');

%% Test 6: Negative Margin Detection

invalidDetected = false;

try

    select_robust_adaptive_modulation( ...
        20,-1,thresholds);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 6 passed: Invalid margin detection.\n');

%% Test 7: NaN Detection

invalidDetected = false;

try

    select_robust_adaptive_modulation( ...
        NaN,2,thresholds);

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 7 passed: Invalid SNR detection.\n');

%% Final Results

fprintf('\nAll robust AMC selector tests passed.\n');
