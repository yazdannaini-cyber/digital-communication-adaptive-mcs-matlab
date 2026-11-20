
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFolder);
addpath(genpath(projectRoot));

%% Parameters

EbN0_dB = 0:2:12;

K_dB = 6;

%% Theoretical BER

berAWGN = theoretical_ber_16qam_fading( ...
    EbN0_dB,'AWGN');

berRayleigh = theoretical_ber_16qam_fading( ...
    EbN0_dB,'Rayleigh');

berRician = theoretical_ber_16qam_fading( ...
    EbN0_dB,'Rician',K_dB);

%% Test 1: Output Dimensions

assert(isequal(size(berAWGN),size(EbN0_dB)));

assert(isequal(size(berRayleigh),size(EbN0_dB)));

assert(isequal(size(berRician),size(EbN0_dB)));

fprintf('Test 1 passed: Output dimensions.\n');

%% Test 2: Valid BER Range

assert(all(berAWGN >= 0 & berAWGN <= 0.5));

assert(all(berRayleigh >= 0 & berRayleigh <= 0.5));

assert(all(berRician >= 0 & berRician <= 0.5));

fprintf('Test 2 passed: Valid BER range.\n');

%% Test 3: Monotonicity

assert(all(diff(berAWGN) < 0));

assert(all(diff(berRayleigh) < 0));

assert(all(diff(berRician) < 0));

fprintf('Test 3 passed: Monotonic BER behavior.\n');

%% Test 4: Fading Performance

assert(all(berRayleigh > berAWGN));

assert(all(berRician > berAWGN));

assert(all(berRician < berRayleigh));

fprintf('Test 4 passed: Channel performance ordering.\n');

%% Test 5: High K-factor Approximation

berHighK = theoretical_ber_16qam_fading( ...
    6,'Rician',30);

berAWGN6 = theoretical_ber_16qam_fading( ...
    6,'AWGN');

assert(abs(berHighK-berAWGN6)/berAWGN6 < 0.02);

fprintf('Test 5 passed: High-K AWGN approximation.\n');

%% Test 6: Invalid Channel

invalidDetected = false;

try

    theoretical_ber_16qam_fading(6,'Unknown');

catch

    invalidDetected = true;

end

assert(invalidDetected);

fprintf('Test 6 passed: Invalid channel detection.\n');

%% Display Results

fprintf('\n========== 16-QAM FADING THEORY ==========\n');

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

fprintf('\nAll 16-QAM fading theory tests passed.\n');
