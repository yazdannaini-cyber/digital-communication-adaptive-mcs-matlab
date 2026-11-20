
clc;
clear;

fprintf('Starting Block Interleaver Tests...\n\n');

%% Test 1: Basic round-trip
data = randi([0 1], 2084, 1);

interleaved = block_interleaver(data, 4);
recovered = block_deinterleaver(interleaved, 4);

assert(isequal(data, recovered));
fprintf('Test 1 passed: Interleaver-Deinterleaver round-trip.\n');

%% Test 2: Output length
assert(numel(interleaved) == numel(data));
fprintf('Test 2 passed: Output length preserved.\n');

%% Test 3: Interleaving changes the order
testData = (1:20).';

interleavedTest = block_interleaver(testData, 4);

assert(~isequal(testData, interleavedTest));
fprintf('Test 3 passed: Data order changed.\n');

%% Test 4: Row vector support
rowData = 1:20;

rowInterleaved = block_interleaver(rowData, 4);
rowRecovered = block_deinterleaver(rowInterleaved, 4);

assert(isrow(rowInterleaved));
assert(isrow(rowRecovered));
assert(isequal(rowData, rowRecovered));

fprintf('Test 4 passed: Row vector support.\n');

%% Test 5: Column vector support
columnData = (1:20).';

columnInterleaved = block_interleaver(columnData, 4);
columnRecovered = block_deinterleaver(columnInterleaved, 4);

assert(iscolumn(columnInterleaved));
assert(iscolumn(columnRecovered));
assert(isequal(columnData, columnRecovered));

fprintf('Test 5 passed: Column vector support.\n');

%% Test 6: Invalid input length
errorDetected = false;

try
    block_interleaver(1:10, 4);
catch
    errorDetected = true;
end

assert(errorDetected);
fprintf('Test 6 passed: Invalid input length detection.\n');

%% Test 7: Invalid number of rows
errorDetected = false;

try
    block_interleaver(data, 1);
catch
    errorDetected = true;
end

assert(errorDetected);
fprintf('Test 7 passed: Invalid number of rows detection.\n');

fprintf('\nAll Block Interleaver tests passed successfully.\n');
