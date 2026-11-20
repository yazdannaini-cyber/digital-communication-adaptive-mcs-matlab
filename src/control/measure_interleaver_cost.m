
function costProfile = measure_interleaver_cost( ...
    numBits, symbolRate, depths)
%MEASURE_INTERLEAVER_COST Measure processing and buffering costs.
%
% Inputs:
%   numBits    : Number of bits in one interleaver frame.
%   symbolRate : Input symbol rate in symbols/second.
%   depths     : Interleaver depths, e.g. [4 16].
%
% Outputs:
%   costProfile: Structure containing timing and buffering metrics.
%
% Timing:
%   MATLAB execution time is measured using TIMEIT when available.
%
% Structural model:
%   First-column readiness assumes a streaming row-write,
%   column-read rectangular block interleaver.
%
%   This is not a measured hardware end-to-end latency.

    %% Input validation

    if nargin ~= 3
        error('Three inputs are required.');
    end

    if ~isscalar(numBits) || ~isfinite(numBits) || ...
            numBits < 1 || numBits ~= floor(numBits)

        error('numBits must be a positive integer.');

    end

    if ~isscalar(symbolRate) || ~isfinite(symbolRate) || ...
            symbolRate <= 0

        error('symbolRate must be a positive finite value.');

    end

    if ~isvector(depths) || isempty(depths)
        error('depths must be a non-empty vector.');
    end

    depths = double(depths(:).');

    if any(~isfinite(depths)) || ...
            any(depths < 2) || ...
            any(depths ~= floor(depths)) || ...
            any(depths > numBits)

        error('All depths must be valid integers.');
    end

    if numel(unique(depths)) ~= numel(depths)
        error('Depth values must be unique.');
    end

    if any(mod(numBits, depths) ~= 0)
        error('numBits must be divisible by every depth.');
    end

    %% Generate representative test data

    data = randi([0 1], numBits, 1);

    numDepths = numel(depths);

    interleaverTimeMs = zeros(1, numDepths);
    deinterleaverTimeMs = zeros(1, numDepths);

    firstColumnReadyMs = zeros(1, numDepths);

    streamingBufferBits = zeros(1, numDepths);
    streamingBufferBytes = zeros(1, numDepths);

    numColumns = zeros(1, numDepths);

    frameDurationMs = ...
        (numBits / symbolRate) * 1000;

    %% Benchmark each depth

    for k = 1:numDepths

        depth = depths(k);

        columns = numBits / depth;

        numColumns(k) = columns;

        %% Interleaver benchmark

        interleavedData = block_interleaver(data, depth);

        fInterleaver = @() block_interleaver(data, depth);

        interleaverTimeMs(k) = ...
            local_benchmark(fInterleaver) * 1000;

        %% Deinterleaver benchmark

        fDeinterleaver = ...
            @() block_deinterleaver(interleavedData, depth);

        deinterleaverTimeMs(k) = ...
            local_benchmark(fDeinterleaver) * 1000;

        %% Round-trip validation

        recoveredData = block_deinterleaver( ...
            interleavedData, depth);

        assert(isequal(data, recoveredData), ...
            'Interleaver round-trip failed at depth %d.', depth);

        %% Structural buffering model

        % Number of symbols required for the first complete
        % output column to become available.

        firstColumnReadySymbols = ...
            (depth - 1) * columns + 1;

        firstColumnReadyMs(k) = ...
            (firstColumnReadySymbols / symbolRate) * 1000;

        % Streaming storage estimate:
        % retain the previously received rows until their
        % corresponding output-column data become available.

        streamingBufferBits(k) = ...
            (depth - 1) * columns;

        streamingBufferBytes(k) = ...
            ceil(streamingBufferBits(k) / 8);

    end

    %% Total software processing cost

    totalProcessingTimeMs = ...
        interleaverTimeMs + deinterleaverTimeMs;

    %% Combined relative cost score

    % Both quantities are expressed in milliseconds.
    % This is a comparison score, not physical end-to-end latency.

    totalCostScoreMs = ...
        firstColumnReadyMs + totalProcessingTimeMs;

    %% Output structure

    costProfile = struct();

    costProfile.NumBits = numBits;
    costProfile.SymbolRate = symbolRate;

    costProfile.Depths = depths;

    costProfile.NumColumns = numColumns;

    costProfile.InterleaverTimeMs = interleaverTimeMs;
    costProfile.DeinterleaverTimeMs = deinterleaverTimeMs;

    costProfile.TotalProcessingTimeMs = ...
        totalProcessingTimeMs;

    costProfile.FirstColumnReadyMs = ...
        firstColumnReadyMs;

    costProfile.StreamingBufferBits = ...
        streamingBufferBits;

    costProfile.StreamingBufferBytes = ...
        streamingBufferBytes;

    costProfile.FrameDurationMs = ...
        repmat(frameDurationMs, 1, numDepths);

    costProfile.TotalCostScoreMs = ...
        totalCostScoreMs;

end

%% LOCAL BENCHMARK FUNCTION

function elapsedSeconds = local_benchmark(fun)

    % Warm-up call.
    fun();

    if exist('timeit', 'file') == 2 || ...
            exist('timeit', 'builtin') == 5

        elapsedSeconds = timeit(fun);

    else

        % Fallback benchmark.

        repetitions = 200;

        timerValue = tic;

        for k = 1:repetitions
            fun();
        end

        elapsedSeconds = toc(timerValue) / repetitions;

    end

    if ~isfinite(elapsedSeconds) || elapsedSeconds < 0
        error('Invalid benchmark timing result.');
    end

end
