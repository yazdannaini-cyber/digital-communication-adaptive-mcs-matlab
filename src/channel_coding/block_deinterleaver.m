
function deinterleaved = block_deinterleaver(inputData, numRows)
%BLOCK_DEINTERLEAVER Inverse of block_interleaver.
%
% inputData    : row or column vector
% numRows      : same number of rows used by the interleaver
% deinterleaved: restored original vector

    if ~isvector(inputData) || isempty(inputData)
        error('Input must be a non-empty vector.');
    end

    if ~isscalar(numRows) || ~isfinite(numRows) || ...
            numRows < 2 || numRows ~= floor(numRows)
        error('numRows must be an integer greater than or equal to 2.');
    end

    originalWasRow = isrow(inputData);
    data = inputData(:);

    N = numel(data);

    if mod(N, numRows) ~= 0
        error('Input length must be divisible by numRows.');
    end

    numCols = N / numRows;

    % Reconstruct the interleaver matrix.
    interleaverMatrix = reshape(data, numRows, numCols);

    % Read row-wise to recover the original sequence.
    deinterleaved = interleaverMatrix.';
    deinterleaved = deinterleaved(:);

    if originalWasRow
        deinterleaved = deinterleaved.';
    end
end
