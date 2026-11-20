
clc;
clear;
close all;

rng(42);

%% PROJECT PATH

testDir = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testDir);

addpath(genpath(projectRoot));

rehash;

fprintf('Starting Soft Demapper and LLR Viterbi Tests...\n\n');

%% REQUIRED FUNCTIONS

requiredFunctions = {
    'get_modulation_constellation'
    'soft_demapper_llr'
    'viterbi_decoder_soft_llr'
    'convolutional_encoder'
};

for k = 1:numel(requiredFunctions)

    assert(exist(requiredFunctions{k}, 'file') == 2, ...
        'Required function not found: %s', requiredFunctions{k});

end

%% TEST CONFIGURATION

modulations = {'BPSK', 'QPSK', '16QAM'};

numInformationBits = 1024;

noiseVariance = 0.02;

%% TEST 1: BPSK CONSTELLATION

[constellation, labels] = ...
    get_modulation_constellation('BPSK');

assert(isequal(labels, [0; 1]));

assert(abs(constellation(1) - 1) < 1e-12);

assert(abs(constellation(2) + 1) < 1e-12);

assert(abs(mean(abs(constellation).^2) - 1) < 1e-12);

fprintf('Test 1 passed: BPSK constellation.\n');

%% TEST 2: QPSK CONSTELLATION

[constellation, labels] = ...
    get_modulation_constellation('QPSK');

expectedQPSK = [
    (1 + 1i)/sqrt(2)
    (1 - 1i)/sqrt(2)
    (-1 + 1i)/sqrt(2)
    (-1 - 1i)/sqrt(2)
];

assert(isequal(labels, [
    0 0
    0 1
    1 0
    1 1
]));

assert(max(abs(constellation - expectedQPSK)) < 1e-12);

assert(abs(mean(abs(constellation).^2) - 1) < 1e-12);

fprintf('Test 2 passed: QPSK Gray constellation.\n');

%% TEST 3: 16-QAM CONSTELLATION

[constellation, labels] = ...
    get_modulation_constellation('16QAM');

assert(numel(constellation) == 16);

assert(size(labels, 2) == 4);

assert(abs(mean(abs(constellation).^2) - 1) < 1e-12);

assert(numel(unique(constellation)) == 16);

fprintf('Test 3 passed: 16-QAM Gray constellation.\n');

%% TEST 4: END-TO-END BPSK

run_modulation_test( ...
    'BPSK', numInformationBits, noiseVariance);

fprintf('Test 4 passed: BPSK + Soft Demapper + LLR Viterbi.\n');

%% TEST 5: END-TO-END QPSK

run_modulation_test( ...
    'QPSK', numInformationBits, noiseVariance);

fprintf('Test 5 passed: QPSK + Soft Demapper + LLR Viterbi.\n');

%% TEST 6: END-TO-END 16-QAM

run_modulation_test( ...
    '16QAM', numInformationBits, noiseVariance);

fprintf('Test 6 passed: 16-QAM + Soft Demapper + LLR Viterbi.\n');

%% TEST 7: Variable Noise Variance

data = randi([0 1], numInformationBits, 1);

codedBits = convolutional_encoder(data);

codedBits = double(codedBits(:));

[constellation, labels] = ...
    get_modulation_constellation('16QAM');

groups = reshape(codedBits, 4, []).';

symbolIndices = ...
    groups * [8; 4; 2; 1] + 1;

txSymbols = constellation(symbolIndices);

% Different noise variance for every symbol.
varianceVector = 0.01 + 0.04*rand(numel(txSymbols), 1);

% Noiseless received symbols with symbol-dependent variance.
rxSymbols = txSymbols;

llr = soft_demapper_llr( ...
    rxSymbols, '16QAM', varianceVector);

decoded = viterbi_decoder_soft_llr(llr);

assert(isequal(data(:), decoded(:)));

fprintf('Test 7 passed: Variable noise variance handling.\n');

%% TEST 8: LLR POLARITY

testBits = [
    0
    1
    1
    0
];

testSymbols = 1 - 2*double(testBits);

llr = soft_demapper_llr( ...
    testSymbols, 'BPSK', 0.01);

hardBits = double(llr < 0);

assert(isequal(hardBits, testBits));

assert(all(llr(testBits == 0) > 0));

assert(all(llr(testBits == 1) < 0));

fprintf('Test 8 passed: Positive and negative LLR conventions.\n');

%% TEST 9: Row-vector input support

data = randi([0 1], numInformationBits, 1);

codedBits = convolutional_encoder(data);

codedBits = double(codedBits(:));

[constellation, labels] = ...
    get_modulation_constellation('QPSK');

groups = reshape(codedBits, 2, []).';

symbolIndices = groups * [2; 1] + 1;

txSymbols = constellation(symbolIndices);

rowSymbols = txSymbols.';

llr = soft_demapper_llr( ...
    rowSymbols, 'QPSK', noiseVariance);

decoded = viterbi_decoder_soft_llr(llr.');

assert(isrow(decoded));

assert(isequal(data(:), decoded(:)));

fprintf('Test 9 passed: Row-vector input support.\n');

%% TEST 10: Odd LLR Length Detection

errorDetected = false;

try

    viterbi_decoder_soft_llr([1 -1 2]);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 10 passed: Invalid LLR length detection.\n');

%% TEST 11: Invalid Noise Variance Detection

errorDetected = false;

try

    soft_demapper_llr([1 1i], 'QPSK', 0);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 11 passed: Invalid noise variance detection.\n');


%% TEST 12: Legacy Hard-Demapper Compatibility

[constellation, labels] = ...
    get_modulation_constellation('QPSK');

expectedBits = reshape(labels.', [], 1);

if exist('qpsk_demodulator', 'file') == 2

    legacyBits = qpsk_demodulator(constellation);

    assert(isequal(double(legacyBits(:)), expectedBits));

    fprintf('Test 12 passed: Existing QPSK demapper mapping.\n');

else

    fprintf('Test 12 skipped: qpsk_demodulator not found.\n');

end

[constellation, labels] = ...
    get_modulation_constellation('16QAM');

expectedBits = reshape(labels.', [], 1);

if exist('qam16_demodulator', 'file') == 2

    legacyBits = qam16_demodulator(constellation);

    assert(isequal(double(legacyBits(:)), expectedBits));

    fprintf('Test 13 passed: Existing 16-QAM demapper mapping.\n');

else

    fprintf('Test 13 skipped: qam16_demodulator not found.\n');

end


%% LOCAL FUNCTION

function run_modulation_test( ...
    modulation, numInformationBits, noiseVariance)

    %% Generate information bits

    data = randi([0 1], numInformationBits, 1);

    %% Convolutional encoding

    codedBits = convolutional_encoder(data);

    codedBits = double(codedBits(:));

    %% Obtain constellation

    [constellation, labels] = ...
        get_modulation_constellation(modulation);

    bitsPerSymbol = size(labels, 2);

    %% Group coded bits

    if mod(numel(codedBits), bitsPerSymbol) ~= 0

        error('Coded bit length is not divisible by bits per symbol.');

    end

    bitGroups = reshape( ...
        codedBits, bitsPerSymbol, []).';

    %% Binary label to symbol index

    weights = 2.^(bitsPerSymbol-1:-1:0).';

    symbolIndices = bitGroups * weights + 1;

    txSymbols = constellation(symbolIndices);

    txSymbols = txSymbols(:);

    %% Noiseless transmission

    rxSymbols = txSymbols;

    %% Soft demapping

    llr = soft_demapper_llr( ...
        rxSymbols, modulation, noiseVariance);

    %% Hard decision consistency

    hardBits = double(llr < 0);

    assert(isequal(hardBits, codedBits));

    %% LLR Viterbi decoding

    decoded = viterbi_decoder_soft_llr(llr);

    %% Verify complete recovery

    assert(isequal(data(:), decoded(:)));

    %% Verify output length

    assert(numel(decoded) == numInformationBits);

end
