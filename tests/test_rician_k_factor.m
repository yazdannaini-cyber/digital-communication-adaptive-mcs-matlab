
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFolder);
addpath(genpath(projectRoot));

%% Parameters

EbN0_dB = 6;

K_dB_list = [-20 -10 0 3 6 10 20 30];

%% Calculate Rician BER

berRician = theoretical_ber_rician_bpsk( ...
    EbN0_dB,K_dB_list);

%% Calculate Reference Values

berRayleigh = theoretical_ber_rayleigh_bpsk(EbN0_dB);

berAWGN = 0.5*erfc(sqrt(10^(EbN0_dB/10)));

%% Test 1: Output Dimensions

assert(numel(berRician) == numel(K_dB_list));

fprintf('Test 1 passed: Output dimensions.\n');

%% Test 2: Valid BER Range

assert(all(berRician >= 0 & berRician <= 0.5));

fprintf('Test 2 passed: Valid BER range.\n');

%% Test 3: BER Decreases with K

assert(all(diff(berRician) < 0));

fprintf('Test 3 passed: Monotonic K-factor behavior.\n');

%% Test 4: Low K Approaches Rayleigh

relativeRayleighDifference = ...
    abs(berRician(1)-berRayleigh)/berRayleigh;

assert(relativeRayleighDifference < 0.02);

fprintf('Test 4 passed: Low-K Rayleigh approximation.\n');

%% Test 5: High K Approaches AWGN

relativeAWGNDifference = ...
    abs(berRician(end)-berAWGN)/berAWGN;

assert(relativeAWGNDifference < 0.02);

fprintf('Test 5 passed: High-K AWGN approximation.\n');

%% Display Results

fprintf('\n========== RICIAN K-FACTOR THEORY ==========\n');

disp(table( ...
    K_dB_list(:), ...
    10.^(K_dB_list(:)/10), ...
    berRician(:), ...
    'VariableNames',{ ...
    'K_dB', ...
    'K_linear', ...
    'Theoretical_BER'}));

fprintf('\nAll Rician K-factor tests passed.\n');
