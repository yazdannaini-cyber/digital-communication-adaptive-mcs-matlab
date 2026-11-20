
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

rng(42);

%% Parameters

N = 200000;

NMSE_dB = -20;

targetNMSE = 10^(NMSE_dB/10);

%% Generate Rayleigh Channel

hTrue = generate_block_fading_coefficients( ...
    N,'Rayleigh');

%% Estimate Channel

[hEstimate,errorSamples] = ...
    estimate_channel(hTrue,NMSE_dB);

%% Test 1: Output Dimensions

assert(numel(hEstimate)==N);

assert(numel(errorSamples)==N);

fprintf('Test 1 passed: Output dimensions.\n');

%% Test 2: Estimation Equation

assert(max(abs(hEstimate-hTrue-errorSamples))<1e-12);

fprintf('Test 2 passed: Estimation equation.\n');

%% Test 3: Measured NMSE

measuredNMSE = ...
    mean(abs(hEstimate-hTrue).^2) / ...
    mean(abs(hTrue).^2);

assert(abs(measuredNMSE-targetNMSE)/targetNMSE<0.02);

fprintf('Test 3 passed: NMSE verification.\n');

%% Test 4: Zero-Mean Estimation Error

measuredErrorMean = mean(errorSamples);

meanTolerance = ...
    5*sqrt(targetNMSE/N);

assert(abs(real(measuredErrorMean))<meanTolerance);

assert(abs(imag(measuredErrorMean))<meanTolerance);

fprintf('Test 4 passed: Estimation error mean.\n');

%% Test 5: Noise Dimension Statistics

errorVarianceI = var(real(errorSamples),1);

errorVarianceQ = var(imag(errorSamples),1);

expectedVariance = targetNMSE/2;

assert(abs(errorVarianceI-expectedVariance)/ ...
    expectedVariance<0.02);

assert(abs(errorVarianceQ-expectedVariance)/ ...
    expectedVariance<0.02);

fprintf('Test 5 passed: Complex estimation error statistics.\n');

%% Test 6: Perfect Estimation Approximation

[hPerfect,ePerfect] = ...
    estimate_channel(hTrue,-100);

assert(max(abs(hPerfect-hTrue))<1e-4);

fprintf('Test 6 passed: High-accuracy estimation.\n');

%% Test 7: Invalid NMSE

invalidDetected = false;

try

    estimate_channel(hTrue,NaN);

catch

    invalidDetected=true;

end

assert(invalidDetected);

fprintf('Test 7 passed: Invalid NMSE detection.\n');

%% Display Results

fprintf('\n========== CHANNEL ESTIMATION RESULTS ==========\n');

fprintf('Target NMSE: %.8f\n',targetNMSE);

fprintf('Measured NMSE: %.8f\n',measuredNMSE);

fprintf('Measured I error variance: %.8f\n',errorVarianceI);

fprintf('Measured Q error variance: %.8f\n',errorVarianceQ);

fprintf('\nAll channel estimation tests passed.\n');
