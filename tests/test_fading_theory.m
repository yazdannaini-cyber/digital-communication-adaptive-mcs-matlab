
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

%% Parameters

EbN0_dB = 0:2:20;

K_dB = 6;

%% Calculate Theoretical BER

berRayleigh = ...
    theoretical_ber_rayleigh_bpsk(EbN0_dB);

berRician = ...
    theoretical_ber_rician_bpsk(EbN0_dB,K_dB);

berAWGN = ...
    0.5*erfc(sqrt(10.^(EbN0_dB/10)));

%% Test 1: Output Length

assert(numel(berRayleigh) == numel(EbN0_dB));

assert(numel(berRician) == numel(EbN0_dB));

fprintf('Test 1 passed: Output dimensions.\n');

%% Test 2: Valid BER Range

assert(all(berRayleigh >= 0 & berRayleigh <= 0.5));

assert(all(berRician >= 0 & berRician <= 0.5));

fprintf('Test 2 passed: Valid BER range.\n');

%% Test 3: Monotonic Behavior

assert(all(diff(berRayleigh) < 0));

assert(all(diff(berRician) < 0));

assert(all(diff(berAWGN) < 0));

fprintf('Test 3 passed: Monotonic BER behavior.\n');

%% Test 4: Rayleigh Performance

assert(all(berRayleigh > berAWGN));

fprintf('Test 4 passed: Rayleigh vs AWGN behavior.\n');

%% Test 5: Rician and Rayleigh Comparison

assert(all(berRician < berRayleigh));

fprintf('Test 5 passed: Rician vs Rayleigh behavior.\n');

%% Test 6: Rician Approximation at High K

berHighK = theoretical_ber_rician_bpsk(6,30);

berAt6dB = 0.5*erfc(sqrt(10^(6/10)));

assert(abs(berHighK-berAt6dB)/berAt6dB < 0.02);

fprintf('Test 6 passed: High-K AWGN approximation.\n');

%% Display Results

fprintf('\n========== THEORETICAL FADING BER ==========\n');

disp(table( ...
    EbN0_dB(:), ...
    berAWGN(:), ...
    berRayleigh(:), ...
    berRician(:), ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'AWGN_BER', ...
    'Rayleigh_BER', ...
    'Rician_BER'}));

fprintf('\nAll fading theory tests passed successfully.\n');
