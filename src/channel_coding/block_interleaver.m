
function interleaved = block_interleaver(inputData, numRows)
%BLOCK_INTERLEAVER Rectangular block interleaver.
% Writes input data row-wise and reads it column-wise.
%
% inputData : row or column vector
% numRows   : number of rows in the interleaver matrix
% interleaved: interleaved column or row vector

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

    % Write row-wise into the matrix.
    interleaverMatrix = reshape(data, numCols, numRows).';

    % Read column-wise.
    interleaved = interleaverMatrix(:);

    if originalWasRow
        interleaved = interleaved.';
    end
end
