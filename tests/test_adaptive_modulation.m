
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

rng(42);

%% Test 1: AMC Thresholds

targetBER = 1e-3;

thresholds = calculate_amc_thresholds(targetBER);

assert(numel(thresholds.requiredEsN0_dB)==3);

assert(all(diff(thresholds.requiredEsN0_dB)>0));

fprintf('Test 1 passed: AMC threshold calculation.\n');

%% Test 2: BPSK/QPSK Threshold Difference

thresholdDifference = ...
    thresholds.requiredEsN0_dB(2) - ...
    thresholds.requiredEsN0_dB(1);

assert(abs(thresholdDifference-10*log10(2))<1e-8);

fprintf('Test 2 passed: BPSK/QPSK threshold relationship.\n');

%% Test 3: Outage Detection

[mode,name] = select_adaptive_modulation( ...
    thresholds.requiredEsN0_dB(1)-1,thresholds);

assert(mode==0);

assert(strcmp(name,'OUTAGE'));

fprintf('Test 3 passed: Outage detection.\n');

%% Test 4: BPSK Selection

[mode,name] = select_adaptive_modulation( ...
    thresholds.requiredEsN0_dB(1),thresholds);

assert(mode==1);

assert(strcmp(name,'BPSK'));

fprintf('Test 4 passed: BPSK selection.\n');

%% Test 5: QPSK Selection

[mode,name] = select_adaptive_modulation( ...
    thresholds.requiredEsN0_dB(2),thresholds);

assert(mode==2);

assert(strcmp(name,'QPSK'));

fprintf('Test 5 passed: QPSK selection.\n');

%% Test 6: 16-QAM Selection

[mode,name] = select_adaptive_modulation( ...
    thresholds.requiredEsN0_dB(3),thresholds);

assert(mode==3);

assert(strcmp(name,'16-QAM'));

fprintf('Test 6 passed: 16-QAM selection.\n');

%% Test 7: Rayleigh Block Fading

hRayleigh = generate_block_fading_coefficients( ...
    200000,'Rayleigh');

assert(numel(hRayleigh)==200000);

assert(abs(mean(abs(hRayleigh).^2)-1)<0.02);

fprintf('Test 7 passed: Rayleigh block channel.\n');

%% Test 8: Rician Block Fading

hRician = generate_block_fading_coefficients( ...
    200000,'Rician',6);

assert(numel(hRician)==200000);

assert(abs(mean(abs(hRician).^2)-1)<0.02);

fprintf('Test 8 passed: Rician block channel.\n');

%% Test 9: Block Channel Equation and Noise

tx = ones(1,100000);

h = 0.8+0.2i;

[rx,noise,noiseVariance] = ...
    block_fading_channel(tx,h,15,1);

assert(max(abs(rx-h.*tx-noise))<1e-12);

assert(abs(var(real(noise),1)-noiseVariance)/ ...
    noiseVariance<0.02);

assert(abs(var(imag(noise),1)-noiseVariance)/ ...
    noiseVariance<0.02);

fprintf('Test 9 passed: Block channel and noise.\n');

%% Test 10: Scalar Channel Equalization

equalized = coherent_equalizer(rx,h);

assert(max(abs(equalized-(tx+noise/h)))<1e-12);

fprintf('Test 10 passed: Scalar channel equalization.\n');

%% Test 11: Invalid Threshold Input

invalidDetected = false;

try

    select_adaptive_modulation(NaN,thresholds);

catch

    invalidDetected=true;

end

assert(invalidDetected);

fprintf('Test 11 passed: Invalid SNR detection.\n');

%% Display Thresholds

fprintf('\n========== AMC THRESHOLDS ==========\n');

disp(table( ...
    string(thresholds.modulationNames(:)), ...
    thresholds.bitsPerSymbol(:), ...
    thresholds.requiredEbN0_dB(:), ...
    thresholds.requiredEsN0_dB(:), ...
    'VariableNames',{ ...
    'Modulation', ...
    'BitsPerSymbol', ...
    'RequiredEbN0_dB', ...
    'RequiredEsN0_dB'}));

fprintf('\nAll adaptive modulation tests passed.\n');
