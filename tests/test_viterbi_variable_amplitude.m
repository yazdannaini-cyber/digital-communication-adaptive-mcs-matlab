
clc;
clear;
rng(42);

fprintf('Starting Variable-Amplitude Viterbi Tests...\n\n');

%% Test 1: Noiseless decoding with constant amplitude

N = 1000;

data = randi([0 1], N, 1);
codedBits = convolutional_encoder(data);
codedBits = codedBits(:);

A = 0.8;

received = A .* (1 - 2*double(codedBits));

decoded = viterbi_decoder_soft_variable_amplitude(received, A);

assert(isequal(data(:), decoded(:)));

fprintf('Test 1 passed: Noiseless constant-amplitude decoding.\n');

%% Test 2: Noiseless decoding with variable amplitude

amplitude = 0.1 + 0.9*rand(numel(codedBits), 1);

received = amplitude .* (1 - 2*double(codedBits));

decoded = viterbi_decoder_soft_variable_amplitude( ...
    received, amplitude);

assert(isequal(data(:), decoded(:)));

fprintf('Test 2 passed: Noiseless variable-amplitude decoding.\n');

%% Test 3: Four independent fading blocks with interleaving

numRows = 4;

codedInterleaved = block_interleaver(codedBits, numRows);
codedInterleaved = codedInterleaved(:);

blockLength = numel(codedInterleaved) / numRows;

blockAmplitudes = [0.15; 0.45; 0.75; 0.95];

amplitudeInterleaved = repelem( ...
    blockAmplitudes, blockLength, 1);

receivedInterleaved = amplitudeInterleaved .* ...
    (1 - 2*double(codedInterleaved));

% Deinterleave received samples and their corresponding amplitudes.

receivedOriginal = block_deinterleaver( ...
    receivedInterleaved, numRows);

amplitudeOriginal = block_deinterleaver( ...
    amplitudeInterleaved, numRows);

receivedOriginal = receivedOriginal(:);
amplitudeOriginal = amplitudeOriginal(:);

decoded = viterbi_decoder_soft_variable_amplitude( ...
    receivedOriginal, amplitudeOriginal);

assert(isequal(data(:), decoded(:)));

fprintf('Test 3 passed: Four-block fading amplitude recovery.\n');

%% Test 4: Row-vector input support

rowData = data.';

rowCoded = convolutional_encoder(rowData);
rowCoded = rowCoded(:).';

rowAmplitude = 0.2 + 0.8*rand(size(rowCoded));

rowReceived = rowAmplitude .* ...
    (1 - 2*double(rowCoded));

rowDecoded = viterbi_decoder_soft_variable_amplitude( ...
    rowReceived, rowAmplitude);

assert(isrow(rowDecoded));
assert(isequal(rowData(:), rowDecoded(:)));

fprintf('Test 4 passed: Row-vector support.\n');

%% Test 5: Invalid amplitude length

errorDetected = false;

try
    viterbi_decoder_soft_variable_amplitude( ...
        received, amplitude(1:end-1));
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 5 passed: Invalid amplitude length detection.\n');

%% Test 6: Invalid odd received-sample length

errorDetected = false;

try
    viterbi_decoder_soft_variable_amplitude([1 0 1], 1);
catch
    errorDetected = true;
end

assert(errorDetected);

fprintf('Test 6 passed: Invalid received length detection.\n');

fprintf('\nAll Variable-Amplitude Viterbi Tests Passed Successfully.\n');
