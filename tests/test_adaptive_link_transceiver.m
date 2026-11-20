
clc;
clear;
close all;

rng(42);

%% PROJECT PATH

testDir = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testDir);

addpath(genpath(projectRoot));

rehash;

fprintf('Starting Adaptive Link Transceiver Tests...\n\n');

%% REQUIRED FUNCTIONS

requiredFunctions = {
    'append_crc16'
    'convolutional_encoder'
    'block_interleaver'
    'block_deinterleaver'
    'get_modulation_constellation'
    'digital_modulator'
    'soft_demapper_llr'
    'viterbi_decoder_soft_llr'
    'adaptive_link_transmitter'
    'adaptive_link_receiver'
};

for k = 1:numel(requiredFunctions)

    assert(exist(requiredFunctions{k}, 'file') == 2, ...
        'Required function not found: %s', requiredFunctions{k});

end

%% CONFIGURATION

payloadLength = 1024;

modulations = {'BPSK', 'QPSK', '16QAM'};

depths = [4 16];

numFadingBlocks = 4;

N0 = 1e-4;

%% TEST 1: BPSK WITH DEPTH 4 AND 16

for depth = depths

    payload = randi([0 1], payloadLength, 1);

    [txSymbols, txInfo] = adaptive_link_transmitter( ...
        payload, 'BPSK', depth, numFadingBlocks);

    hBlocks = [
        0.35 + 0.10i
        0.60 - 0.20i
        0.90 + 0.15i
        1.10 - 0.25i
    ];

    symbolsPerBlock = numel(txSymbols) / numFadingBlocks;

    h = repelem(hBlocks, symbolsPerBlock, 1);

    rxSymbols = h .* txSymbols;

    [decodedPayload, rxInfo] = adaptive_link_receiver( ...
        rxSymbols, h, N0, txInfo);

    assert(isequal(payload(:), decodedPayload(:)));
    assert(rxInfo.CRCCorrect);
    assert(txInfo.InterleaverDepth == depth);

end

fprintf('Test 1 passed: BPSK with Depth 4 and 16.\n');

%% TEST 2: QPSK WITH DEPTH 4 AND 16

for depth = depths

    payload = randi([0 1], payloadLength, 1);

    [txSymbols, txInfo] = adaptive_link_transmitter( ...
        payload, 'QPSK', depth, numFadingBlocks);

    hBlocks = [
        0.35 + 0.10i
        0.60 - 0.20i
        0.90 + 0.15i
        1.10 - 0.25i
    ];

    symbolsPerBlock = numel(txSymbols) / numFadingBlocks;

    h = repelem(hBlocks, symbolsPerBlock, 1);

    rxSymbols = h .* txSymbols;

    [decodedPayload, rxInfo] = adaptive_link_receiver( ...
        rxSymbols, h, N0, txInfo);

    assert(isequal(payload(:), decodedPayload(:)));
    assert(rxInfo.CRCCorrect);
    assert(txInfo.InterleaverDepth == depth);

end

fprintf('Test 2 passed: QPSK with Depth 4 and 16.\n');

%% TEST 3: 16-QAM WITH DEPTH 4 AND 16

for depth = depths

    payload = randi([0 1], payloadLength, 1);

    [txSymbols, txInfo] = adaptive_link_transmitter( ...
        payload, '16QAM', depth, numFadingBlocks);

    hBlocks = [
        0.35 + 0.10i
        0.60 - 0.20i
        0.90 + 0.15i
        1.10 - 0.25i
    ];

    symbolsPerBlock = numel(txSymbols) / numFadingBlocks;

    h = repelem(hBlocks, symbolsPerBlock, 1);

    rxSymbols = h .* txSymbols;

    [decodedPayload, rxInfo] = adaptive_link_receiver( ...
        rxSymbols, h, N0, txInfo);

    assert(isequal(payload(:), decodedPayload(:)));
    assert(rxInfo.CRCCorrect);
    assert(txInfo.InterleaverDepth == depth);

end

fprintf('Test 3 passed: 16-QAM with Depth 4 and 16.\n');

%% TEST 4: ACTUAL AWGN TRANSMISSION

payload = randi([0 1], payloadLength, 1);

[txSymbols, txInfo] = adaptive_link_transmitter( ...
    payload, '16QAM', 16, numFadingBlocks);

% Flat channel with unit gain.

h = ones(numel(txSymbols), 1);

noise = sqrt(N0/2) .* ...
    (randn(size(txSymbols)) + 1i*randn(size(txSymbols)));

rxSymbols = h .* txSymbols + noise;

[decodedPayload, rxInfo] = adaptive_link_receiver( ...
    rxSymbols, h, N0, txInfo);

assert(isequal(payload(:), decodedPayload(:)));
assert(rxInfo.CRCCorrect);

fprintf('Test 4 passed: 16-QAM transmission over AWGN.\n');

%% TEST 5: FOUR-BLOCK FADING WITH AWGN

payload = randi([0 1], payloadLength, 1);

[txSymbols, txInfo] = adaptive_link_transmitter( ...
    payload, 'QPSK', 16, numFadingBlocks);

hBlocks = [
    0.35 + 0.10i
    0.60 - 0.20i
    0.90 + 0.15i
    1.10 - 0.25i
];

symbolsPerBlock = numel(txSymbols) / numFadingBlocks;

h = repelem(hBlocks, symbolsPerBlock, 1);

noise = sqrt(N0/2) .* ...
    (randn(size(txSymbols)) + 1i*randn(size(txSymbols)));

rxSymbols = h .* txSymbols + noise;

[decodedPayload, rxInfo] = adaptive_link_receiver( ...
    rxSymbols, h, N0, txInfo);

assert(isequal(payload(:), decodedPayload(:)));
assert(rxInfo.CRCCorrect);

fprintf('Test 5 passed: QPSK over four-block fading and AWGN.\n');

%% TEST 6: FRAME LENGTH VALIDATION

for modulationIndex = 1:numel(modulations)

    modulation = modulations{modulationIndex};

    for depth = depths

        payload = randi([0 1], payloadLength, 1);

        [txSymbols, txInfo] = adaptive_link_transmitter( ...
            payload, modulation, depth, numFadingBlocks);

        assert(mod(txInfo.TransmissionBitLength, depth) == 0);

        assert(mod(txInfo.TransmissionBitLength, ...
            txInfo.BitsPerSymbol) == 0);

        assert(mod(txInfo.NumSymbols, numFadingBlocks) == 0);

        assert(numel(txSymbols) == txInfo.NumSymbols);

    end
end

fprintf('Test 6 passed: Frame length and padding validation.\n');

%% TEST 7: EFFECTIVE ENERGY RATE

payload = randi([0 1], payloadLength, 1);

[txSymbols, txInfo] = adaptive_link_transmitter( ...
    payload, 'QPSK', 4, numFadingBlocks);

expectedRate = ...
    payloadLength / txInfo.TransmissionBitLength;

assert(abs(txInfo.EffectivePayloadRate - expectedRate) < 1e-12);

expectedAmplitude = sqrt( ...
    expectedRate * txInfo.BitsPerSymbol);

assert(abs(txInfo.SymbolAmplitude - expectedAmplitude) < 1e-12);

fprintf('Test 7 passed: Payload-energy normalization.\n');

%% TEST 8: INVALID INTERLEAVER DEPTH

errorDetected = false;

try

    adaptive_link_transmitter( ...
        payload, 'BPSK', 8, numFadingBlocks);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 8 passed: Invalid depth detection.\n');

%% TEST 9: INVALID MODULATION

errorDetected = false;

try

    adaptive_link_transmitter( ...
        payload, '64QAM', 4, numFadingBlocks);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 9 passed: Unsupported modulation detection.\n');

%% TEST 10: RECEIVER SYMBOL LENGTH MISMATCH

payload = randi([0 1], payloadLength, 1);

[txSymbols, txInfo] = adaptive_link_transmitter( ...
    payload, 'BPSK', 4, numFadingBlocks);

errorDetected = false;

try

    adaptive_link_receiver( ...
        txSymbols(1:end-1), ...
        ones(numel(txSymbols)-1, 1), ...
        N0, txInfo);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 10 passed: Receiver frame-length validation.\n');

%% TEST 11: INVALID NOISE VARIANCE

errorDetected = false;

try

    adaptive_link_receiver( ...
        txSymbols, ...
        ones(numel(txSymbols), 1), ...
        0, txInfo);

catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 11 passed: Invalid noise variance detection.\n');

fprintf('\nAll Adaptive Link Transceiver Tests Passed Successfully.\n');
