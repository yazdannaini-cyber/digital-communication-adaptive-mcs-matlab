
clc;
clear;
close all;

%% PROJECT PATH

testDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testDir);

addpath(genpath(projectRoot));
rehash;

fprintf('Starting Adaptive Link Profile Tests...\n\n');

%% SYNTHETIC TEST CALIBRATION TABLE
%
% IMPORTANT:
% These values are deliberately synthetic.
% They test controller logic only.
% They are NOT measured communication-system results.

Channel = [
    "Rician"
    "Rician"
    "Rician"
    "Rayleigh"
    "Rayleigh"
    "Rayleigh"
    "Rician"
    "Rician"
];

EbN0_dB = [
    10; 10; 10;
     8;  8;  8;
    12; 12
];

Modulation = [
    "BPSK"
    "QPSK"
    "16QAM"
    "BPSK"
    "QPSK"
    "16QAM"
    "BPSK"
    "QPSK"
];

BitsPerSymbol = [
    1; 2; 4;
    1; 2; 4;
    1; 2
];

CodeRate = 0.5 * ones(8, 1);

InterleaverDepth = [
    4; 4; 16;
    4; 16; 4;
    4; 4
];

PER_Upper95 = [
    0.15; 0.14; 0.18;
    0.35; 0.40; 0.55;
    0.08; 0.08
];

ProcessingCost_ms = [
    0.007; 0.006; 0.003;
    0.007; 0.003; 0.006;
    0.005; 0.002
];

FirstColumnReady_ms = [
    1.573; 1.573; 1.966;
    1.573; 1.966; 1.573;
    1.573; 1.573
];

EffectiveSpectralEfficiency = [
    0.49; 0.98; 1.96;
    0.49; 0.98; 1.96;
    0.49; 0.49
];

profileTable = table( ...
    Channel, EbN0_dB, Modulation, ...
    BitsPerSymbol, CodeRate, InterleaverDepth, ...
    PER_Upper95, ProcessingCost_ms, ...
    FirstColumnReady_ms, EffectiveSpectralEfficiency);

%% Test 1: Highest spectral efficiency among feasible profiles

[profile, decision] = ...
    select_adaptive_link_profile( ...
        'Rician', 10, 0.20, 2.0, profileTable);

assert(profile.Modulation == "16QAM");
assert(profile.InterleaverDepth == 16);
assert(decision.QoSMet);
assert(decision.DelayMet);

fprintf('Test 1 passed: Highest feasible spectral efficiency.\n');

%% Test 2: QoS fallback

[profile, decision] = ...
    select_adaptive_link_profile( ...
        'Rayleigh', 8, 0.20, 2.0, profileTable);

assert(profile.Modulation == "BPSK");
assert(decision.QoSMet == false);
assert(decision.DelayMet);

fprintf('Test 2 passed: Best PER fallback.\n');

%% Test 3: Delay-constrained selection

[profile, decision] = ...
    select_adaptive_link_profile( ...
        'Rician', 10, 0.20, 1.6, profileTable);

assert(profile.Modulation == "QPSK");
assert(profile.InterleaverDepth == 4);
assert(decision.QoSMet);
assert(decision.DelayMet);

fprintf('Test 3 passed: Delay-constrained profile selection.\n');

%% Test 4: No profile meets delay

[profile, decision] = ...
    select_adaptive_link_profile( ...
        'Rician', 10, 0.20, 1.0, profileTable);

assert(profile.Modulation == "QPSK");
assert(~decision.DelayMet);

fprintf('Test 4 passed: Minimum-delay fallback.\n');

%% Test 5: Processing-cost tie-breaker

[profile, decision] = ...
    select_adaptive_link_profile( ...
        'Rician', 12, 0.20, 2.0, profileTable);

assert(profile.Modulation == "QPSK");
assert(decision.QoSMet);
assert(decision.DelayMet);

fprintf('Test 5 passed: Processing-cost tie-breaker.\n');

%% Test 6: Unsupported operating point

errorDetected = false;

try

    select_adaptive_link_profile( ...
        'Rician', 7, 0.20, 2.0, profileTable);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 6 passed: Missing calibration detection.\n');

%% Test 7: Unsupported channel

errorDetected = false;

try

    select_adaptive_link_profile( ...
        'AWGN', 10, 0.20, 2.0, profileTable);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 7 passed: Unsupported channel detection.\n');

%% Test 8: Invalid target PER

errorDetected = false;

try

    select_adaptive_link_profile( ...
        'Rician', 10, 1.0, 2.0, profileTable);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 8 passed: Invalid QoS target detection.\n');

%% Test 9: Missing calibration column

errorDetected = false;

invalidTable = removevars(profileTable, 'CodeRate');

try

    select_adaptive_link_profile( ...
        'Rician', 10, 0.20, 2.0, invalidTable);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 9 passed: Missing table field detection.\n');

fprintf('\nAll Adaptive Link Profile Tests Passed Successfully.\n');
