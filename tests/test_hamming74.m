clc;
clear;
close all;

%% Project setup
 testFolder = fileparts(mfilename('fullpath'));
 projectRoot = fileparts(testFolder);
 addpath(genpath(projectRoot));

fprintf('\n============================================\n');
fprintf('HAMMING (7,4) CHANNEL CODING TESTS\n');
fprintf('============================================\n');

%% Test 1: Generator matrix dimensions
G = hamming74_generator_matrix();
assert(isequal(size(G),[4 7]));
fprintf('Test 1 passed: Generator matrix dimensions.\n');

%% Test 2: Parity-check matrix dimensions
H = hamming74_parity_check_matrix();
assert(isequal(size(H),[3 7]));
fprintf('Test 2 passed: Parity-check matrix dimensions.\n');

%% Test 3: Orthogonality condition H*G'' = 0 over GF(2)
assert(isequal(mod(H*G.',2),zeros(3,4)));
fprintf('Test 3 passed: H*G'' orthogonality.\n');

%% Test 4: Known message encoding
knownMessage = [1 0 1 1];
expectedCodeword = [1 0 1 1 0 1 0];
actualCodeword = hamming74_encoder(knownMessage);
assert(isequal(actualCodeword,expectedCodeword));
fprintf('Test 4 passed: Known Hamming codeword.\n');

%% Test 5: Valid codeword has zero syndrome
syndrome = mod(H*actualCodeword.',2);
assert(isequal(syndrome,[0;0;0]));
fprintf('Test 5 passed: Valid codeword has zero syndrome.\n');

%% Test 6: Decode a clean codeword
[decoded,corrected,errorPosition,syndromes] = ...
    hamming74_decoder(actualCodeword);
assert(isequal(decoded,knownMessage));
assert(isequal(corrected,actualCodeword));
assert(errorPosition == 0);
assert(isequal(syndromes,zeros(3,1)));
fprintf('Test 6 passed: Error-free decoding.\n');

%% Test 7: Correct every possible single-bit error
for bitPosition = 1:7
    corrupted = actualCodeword;
    corrupted(bitPosition) = 1-corrupted(bitPosition);

    [decoded,corrected,errorPosition,syndromes] = ...
        hamming74_decoder(corrupted);

    assert(isequal(decoded,knownMessage));
    assert(isequal(corrected,actualCodeword));
    assert(errorPosition == bitPosition);
    assert(isequal(syndromes,H(:,bitPosition)));
end
fprintf('Test 7 passed: All 7 single-bit error positions corrected.\n');

%% Test 8: Multiple message blocks encode/decode
messageBlocks = [1 0 1 1, 0 0 0 0, 1 1 1 1, 0 1 0 1];
encodedBlocks = hamming74_encoder(messageBlocks);
[decodedBlocks,correctedBlocks,errorPositions] = ...
    hamming74_decoder(encodedBlocks);
assert(isequal(decodedBlocks,messageBlocks));
assert(isequal(correctedBlocks,encodedBlocks));
assert(all(errorPositions == 0));
fprintf('Test 8 passed: Multiple-block encoding and decoding.\n');

%% Test 9: Correct one error in each of multiple blocks
corruptedBlocks = encodedBlocks;
corruptedBlocks(1)  = 1-corruptedBlocks(1);   % bit 1 of word 1
corruptedBlocks(10) = 1-corruptedBlocks(10);  % bit 3 of word 2
corruptedBlocks(28) = 1-corruptedBlocks(28);  % bit 7 of word 4

[decodedBlocks,correctedBlocks,errorPositions] = ...
    hamming74_decoder(corruptedBlocks);
assert(isequal(decodedBlocks,messageBlocks));
assert(isequal(correctedBlocks,encodedBlocks));
assert(isequal(errorPositions,[1 3 0 7]));
fprintf('Test 9 passed: Independent single-bit correction across blocks.\n');

%% Test 10: Column-vector input support
columnMessage = knownMessage.';
columnCodeword = hamming74_encoder(columnMessage);
[decodedColumn,correctedColumn] = hamming74_decoder(columnCodeword.');
assert(isequal(decodedColumn,knownMessage));
assert(isequal(correctedColumn,expectedCodeword));
fprintf('Test 10 passed: Column-vector input support.\n');

%% Test 11: Encoder rejects invalid block length
invalidDetected = false;
try
    hamming74_encoder([1 0 1]);
catch
    invalidDetected = true;
end
assert(invalidDetected);
fprintf('Test 11 passed: Invalid encoder input length detection.\n');

%% Test 12: Decoder rejects invalid block length
invalidDetected = false;
try
    hamming74_decoder([1 0 1 0 1 0]);
catch
    invalidDetected = true;
end
assert(invalidDetected);
fprintf('Test 12 passed: Invalid decoder input length detection.\n');

%% Test 13: Encoder rejects non-binary values
invalidDetected = false;
try
    hamming74_encoder([0 1 2 0]);
catch
    invalidDetected = true;
end
assert(invalidDetected);
fprintf('Test 13 passed: Non-binary encoder input detection.\n');

%% Test 14: Decoder rejects non-binary values
invalidDetected = false;
try
    hamming74_decoder([0 1 0 1 0 2 1]);
catch
    invalidDetected = true;
end
assert(invalidDetected);
fprintf('Test 14 passed: Non-binary decoder input detection.\n');

%% Test 15: Decoder rejects NaN input
invalidDetected = false;
try
    hamming74_decoder([0 1 0 1 0 NaN 1]);
catch
    invalidDetected = true;
end
assert(invalidDetected);
fprintf('Test 15 passed: Non-finite decoder input detection.\n');

fprintf('\nAll Hamming (7,4) tests passed successfully.\n');
