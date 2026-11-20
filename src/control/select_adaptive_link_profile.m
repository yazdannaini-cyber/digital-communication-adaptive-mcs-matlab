
function [selectedProfile, decision] = ...
    select_adaptive_link_profile( ...
    channelType, EbN0_dB, targetPER, maxDelayMs, profileTable)
%SELECT_ADAPTIVE_LINK_PROFILE
% Select an adaptive modulation, coding and interleaving profile.
%
% Required profileTable columns:
%   Channel
%   EbN0_dB
%   Modulation
%   BitsPerSymbol
%   CodeRate
%   InterleaverDepth
%   PER_Upper95
%   ProcessingCost_ms
%   FirstColumnReady_ms
%   EffectiveSpectralEfficiency
%
% Selection policy:
%   1. Find profiles satisfying QoS and delay constraints.
%   2. Select maximum spectral efficiency.
%   3. Break ties using processing cost and readiness delay.
%
% Fallback:
%   If QoS cannot be satisfied, select the lowest PER bound
%   among latency-feasible profiles.
%   If no profile satisfies latency, select the minimum-delay
%   profile and explicitly report the constraint violation.

    %% Validate argument count

    if nargin ~= 5
        error('Exactly five inputs are required.');
    end


%% Validate channel type

if isstring(channelType)

    if ~isscalar(channelType)
        error('channelType must be a scalar string.');
    end

    channelType = char(channelType);

end

if ~ischar(channelType) || isempty(channelType) || ~isrow(channelType)
    error('channelType must be a character vector or scalar string.');
end

% Normalize channel name
channelType = lower(strtrim(channelType));

% Supported channel types
validChannels = {'rayleigh', 'rician'};

% Check channel name
if ~any(strcmp(channelType, validChannels))
    error('Unsupported channel type. Use Rayleigh or Rician.');
end


    %% Validate numeric inputs

    if ~isscalar(EbN0_dB) || ~isfinite(EbN0_dB)
        error('EbN0_dB must be a finite scalar.');
    end

    if ~isscalar(targetPER) || ~isfinite(targetPER) || ...
            targetPER <= 0 || targetPER >= 1
        error('targetPER must be between zero and one.');
    end

    if ~isscalar(maxDelayMs) || ~isfinite(maxDelayMs) || ...
            maxDelayMs <= 0
        error('maxDelayMs must be positive and finite.');
    end

    %% Validate profile table

    if ~istable(profileTable) || isempty(profileTable)
        error('profileTable must be a non-empty MATLAB table.');
    end

    requiredColumns = {
        'Channel'
        'EbN0_dB'
        'Modulation'
        'BitsPerSymbol'
        'CodeRate'
        'InterleaverDepth'
        'PER_Upper95'
        'ProcessingCost_ms'
        'FirstColumnReady_ms'
        'EffectiveSpectralEfficiency'
    };

    tableColumns = profileTable.Properties.VariableNames;

    for k = 1:numel(requiredColumns)

        if ~ismember(requiredColumns{k}, tableColumns)

            error('Missing profile table column: %s', ...
                requiredColumns{k});

        end
    end

    %% Validate categorical data

    channelValues = lower(strtrim(string(profileTable.Channel)));

    modulationValues = upper(strtrim(string(profileTable.Modulation)));

    if any(ismissing(channelValues)) || ...
            any(channelValues == "")

        error('Invalid channel names in profile table.');

    end

    if any(ismissing(modulationValues)) || ...
            any(modulationValues == "")

        error('Invalid modulation names in profile table.');

    end

    supportedModulations = ["BPSK", "QPSK", "16QAM"];

    if any(~ismember(modulationValues, supportedModulations))

        error('Unsupported modulation in profile table.');

    end

    %% Validate numerical table fields

    numericColumns = {
        'EbN0_dB'
        'BitsPerSymbol'
        'CodeRate'
        'InterleaverDepth'
        'PER_Upper95'
        'ProcessingCost_ms'
        'FirstColumnReady_ms'
        'EffectiveSpectralEfficiency'
    };

    for k = 1:numel(numericColumns)

        values = profileTable.(numericColumns{k});

        if ~isnumeric(values) || ~isreal(values) || ...
                any(~isfinite(values(:)))

            error('Invalid numeric column: %s', numericColumns{k});

        end

    end

    bitsPerSymbol = profileTable.BitsPerSymbol;
    codeRate = profileTable.CodeRate;
    depth = profileTable.InterleaverDepth;

    perBound = profileTable.PER_Upper95;
    processing = profileTable.ProcessingCost_ms;
    readiness = profileTable.FirstColumnReady_ms;
    efficiency = profileTable.EffectiveSpectralEfficiency;

    if any(bitsPerSymbol <= 0 | ...
            bitsPerSymbol ~= floor(bitsPerSymbol))

        error('BitsPerSymbol must contain positive integers.');

    end

    if any(codeRate <= 0 | codeRate > 1)
        error('CodeRate must be in the interval (0,1].');
    end

    if any(depth <= 0 | depth ~= floor(depth))
        error('InterleaverDepth must contain positive integers.');
    end

    if any(~ismember(depth, [4 16]))
        error('Only interleaver depths 4 and 16 are supported.');
    end

    if any(perBound < 0 | perBound > 1)
        error('PER_Upper95 must be between zero and one.');
    end

    if any(processing < 0 | readiness < 0 | efficiency <= 0)
        error('Invalid processing, readiness or efficiency value.');
    end

    %% Find candidates for requested operating point

    matchingRows = ...
        channelValues == channelType & ...
        abs(profileTable.EbN0_dB - EbN0_dB) < 1e-9;

    candidateIndices = find(matchingRows);

    if isempty(candidateIndices)

        error(['No calibrated profiles found for %s ', ...
               'at Eb/N0 = %.3f dB.'], channelType, EbN0_dB);

    end

    %% Evaluate constraints

    qosFeasible = perBound(candidateIndices) <= targetPER;

    delayFeasible = readiness(candidateIndices) <= maxDelayMs;

    jointlyFeasible = qosFeasible & delayFeasible;

    %% Selection logic

    if any(jointlyFeasible)

        candidates = candidateIndices(jointlyFeasible);

        % First priority: maximum spectral efficiency.

        bestEfficiency = max(efficiency(candidates));

        candidates = candidates( ...
            abs(efficiency(candidates) - bestEfficiency) < 1e-12);

        % Second priority: minimum software processing time.

        bestProcessing = min(processing(candidates));

        candidates = candidates( ...
            abs(processing(candidates) - bestProcessing) < 1e-12);

        % Third priority: minimum readiness delay.

        [~, index] = min(readiness(candidates));

        selectedIndex = candidates(index);

        reason = ...
            "QoS and delay satisfied; maximum spectral efficiency selected.";

    elseif any(delayFeasible)

        candidates = candidateIndices(delayFeasible);

        % Reliability-oriented fallback.

        bestPER = min(perBound(candidates));

        candidates = candidates( ...
            abs(perBound(candidates) - bestPER) < 1e-12);

        % Break ties using spectral efficiency.

        bestEfficiency = max(efficiency(candidates));

        candidates = candidates( ...
            abs(efficiency(candidates) - bestEfficiency) < 1e-12);

        % Final tie-breaker.

        [~, index] = min(processing(candidates));

        selectedIndex = candidates(index);

        reason = ...
            "No profile satisfies QoS; best latency-feasible PER selected.";

    else

        % No candidate satisfies delay.

        candidates = candidateIndices;

        bestDelay = min(readiness(candidates));

        candidates = candidates( ...
            abs(readiness(candidates) - bestDelay) < 1e-12);

        % Break ties using the best PER.

        bestPER = min(perBound(candidates));

        candidates = candidates( ...
            abs(perBound(candidates) - bestPER) < 1e-12);

        [~, index] = min(processing(candidates));

        selectedIndex = candidates(index);

        reason = ...
            "No profile satisfies delay; minimum-delay fallback selected.";

    end

    %% Return selected table row

    selectedProfile = profileTable(selectedIndex, :);

    %% Build decision report

    decision = struct();

    decision.Channel = channelType;
    decision.EbN0_dB = EbN0_dB;

    decision.TargetPER = targetPER;
    decision.MaxDelay_ms = maxDelayMs;

    decision.CandidateCount = numel(candidateIndices);

    decision.SelectedRow = selectedIndex;

    decision.SelectedModulation = ...
        char(modulationValues(selectedIndex));

    decision.SelectedBitsPerSymbol = ...
        bitsPerSymbol(selectedIndex);

    decision.SelectedCodeRate = ...
        codeRate(selectedIndex);

    decision.SelectedInterleaverDepth = ...
        depth(selectedIndex);

    decision.SelectedPERUpper95 = ...
        perBound(selectedIndex);

    decision.SelectedProcessingCost_ms = ...
        processing(selectedIndex);

    decision.SelectedReadiness_ms = ...
        readiness(selectedIndex);

    decision.SelectedSpectralEfficiency = ...
        efficiency(selectedIndex);

    decision.QoSMet = ...
        perBound(selectedIndex) <= targetPER;

    decision.DelayMet = ...
        readiness(selectedIndex) <= maxDelayMs;

    decision.Reason = char(reason);

end
