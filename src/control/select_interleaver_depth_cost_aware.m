
function [selectedDepth, decision] = ...
    select_interleaver_depth_cost_aware( ...
    channelType, EbN0_dB, targetPER, maxDelayMs, costProfile)
%SELECT_INTERLEAVER_DEPTH_COST_AWARE
% QoS- and cost-aware adaptive interleaver selection.
%
% Inputs:
%   channelType : Rayleigh or Rician
%   EbN0_dB     : calibrated SNR point
%   targetPER   : maximum acceptable PER
%   maxDelayMs  : maximum first-column readiness delay
%   costProfile : output of measure_interleaver_cost
%
% Outputs:
%   selectedDepth
%   decision structure

    %% Validate inputs

    if nargin ~= 5
        error('Five input arguments are required.');
    end

    if ~isscalar(maxDelayMs) || ...
            ~isfinite(maxDelayMs) || maxDelayMs <= 0

        error('maxDelayMs must be positive and finite.');

    end

    requiredFields = {
        'Depths'
        'TotalProcessingTimeMs'
        'FirstColumnReadyMs'
        'StreamingBufferBits'
        'StreamingBufferBytes'
        'TotalCostScoreMs'
    };

    if ~isstruct(costProfile) || ~isscalar(costProfile)
        error('costProfile must be a scalar structure.');
    end

    for k = 1:numel(requiredFields)

        if ~isfield(costProfile, requiredFields{k})
            error('Missing costProfile field: %s', requiredFields{k});
        end

    end

    depths = double(costProfile.Depths(:).');

    processingTime = ...
        double(costProfile.TotalProcessingTimeMs(:).');

    delay = ...
        double(costProfile.FirstColumnReadyMs(:).');

    bufferBits = ...
        double(costProfile.StreamingBufferBits(:).');

    bufferBytes = ...
        double(costProfile.StreamingBufferBytes(:).');

    costScore = ...
        double(costProfile.TotalCostScoreMs(:).');

    n = numel(depths);

    if n == 0 || ...
            any([numel(processingTime), numel(delay), ...
                 numel(bufferBits), numel(bufferBytes), ...
                 numel(costScore)] ~= n)

        error('Cost profile arrays must have matching lengths.');

    end

    if any(~isfinite([depths processingTime delay ...
                      bufferBits bufferBytes costScore])) || ...
            any(processingTime < 0) || ...
            any(delay < 0) || ...
            any(bufferBits < 0) || ...
            any(bufferBytes < 0) || ...
            any(costScore < 0)

        error('Invalid cost profile values.');

    end

    if any(~ismember(depths, [4 16])) || ...
            numel(unique(depths)) ~= n

        error('This controller supports unique depths 4 and 16 only.');

    end

    %% Get QoS calibration bounds

    [~, qosDecision] = ...
        select_interleaver_depth( ...
            channelType, EbN0_dB, targetPER);

    qosBounds = [
        qosDecision.depth4Upper95
        qosDecision.depth16Upper95
    ];

    %% Map candidate depths to QoS bounds

    candidateBounds = zeros(1, n);

    for k = 1:n

        if depths(k) == 4
            candidateBounds(k) = qosBounds(1);
        else
            candidateBounds(k) = qosBounds(2);
        end

    end

    %% Feasibility checks

    qosFeasible = candidateBounds <= targetPER;

    latencyFeasible = delay <= maxDelayMs;

    jointFeasible = qosFeasible & latencyFeasible;

    %% Decision logic

    if any(jointFeasible)

        candidates = find(jointFeasible);

        [~, localIndex] = min(costScore(candidates));

        selectedIndex = candidates(localIndex);

        reason = ...
            'QoS and latency satisfied; lowest-cost feasible depth selected.';

    elseif any(latencyFeasible)

        candidates = find(latencyFeasible);

        % Reliability-oriented fallback:
        % choose the candidate with the smallest upper PER bound.

        bestBound = min(candidateBounds(candidates));

        bestCandidates = candidates( ...
            candidateBounds(candidates) == bestBound);

        % Break ties by cost.

        [~, localIndex] = min(costScore(bestCandidates));

        selectedIndex = bestCandidates(localIndex);

        reason = ...
            ['QoS not met by any latency-feasible depth; ', ...
             'best PER bound selected.'];

    else

        % Neither depth satisfies the delay constraint.
        % Choose the least delayed option.

        bestDelay = min(delay);

        candidates = find(delay == bestDelay);

        [~, localIndex] = min(costScore(candidates));

        selectedIndex = candidates(localIndex);

        reason = ...
            ['No depth satisfies the delay constraint; ', ...
             'minimum-delay fallback selected.'];

    end

    %% Output decision report

    selectedDepth = depths(selectedIndex);

    decision = struct();

    decision.channelType = qosDecision.channelType;

    decision.EbN0_dB = EbN0_dB;

    decision.targetPER = targetPER;

    decision.maxDelayMs = maxDelayMs;

    decision.selectedDepth = selectedDepth;

    decision.selectedPERUpper95 = ...
        candidateBounds(selectedIndex);

    decision.targetMet = ...
        qosFeasible(selectedIndex);

    decision.delayMet = ...
        latencyFeasible(selectedIndex);

    decision.processingTimeMs = ...
        processingTime(selectedIndex);

    decision.firstColumnReadyMs = ...
        delay(selectedIndex);

    decision.streamingBufferBits = ...
        bufferBits(selectedIndex);

    decision.streamingBufferBytes = ...
        bufferBytes(selectedIndex);

    decision.costScoreMs = ...
        costScore(selectedIndex);

    decision.reason = reason;

    decision.qosFeasibleDepths = depths(qosFeasible);

    decision.latencyFeasibleDepths = depths(latencyFeasible);

end
