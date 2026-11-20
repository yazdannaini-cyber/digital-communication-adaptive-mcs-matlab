
function [bler, numBlockErrors] = calculate_bler(blockErrorFlags)

    % =========================================
    % BLOCK ERROR RATE CALCULATOR
    %
    % Input:
    % 0 = Successful block
    % 1 = Erroneous block
    % =========================================

    %% 1. Validate Input Type

    if ~(isnumeric(blockErrorFlags) || ...
         islogical(blockErrorFlags))

        error('Input must be numeric or logical.');

    end

    %% 2. Validate Input Dimensions

    if isempty(blockErrorFlags) || ...
       ~isvector(blockErrorFlags)

        error('Input must be a non-empty vector.');

    end

    %% 3. Validate Finite Values

    if ~isreal(blockErrorFlags) || ...
       any(~isfinite(blockErrorFlags(:)))

        error('Input must contain finite real values.');

    end

    %% 4. Validate Binary Flags

    if any(blockErrorFlags(:) ~= 0 & ...
           blockErrorFlags(:) ~= 1)

        error('Block error flags must contain only 0 or 1.');

    end

    %% 5. Convert to Logical Vector

    blockErrorFlags = logical(blockErrorFlags(:));

    %% 6. Count Erroneous Blocks

    numBlockErrors = sum(blockErrorFlags);

    %% 7. Calculate BLER

    totalBlocks = numel(blockErrorFlags);

    bler = numBlockErrors/totalBlocks;

end
