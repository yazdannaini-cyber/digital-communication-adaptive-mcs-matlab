function [policyTable, selectedRows] = ...
    build_adaptive_mcs_policy( ...
        profileTable, ...
        targetPER, ...
        maxFirstColumnReady_ms, ...
        fallbackPERMargin)
%BUILD_ADAPTIVE_MCS_POLICY Build an empirical adaptive MCS policy.
%
% Inputs:
%   profileTable
%       Empirical calibration table.
%
%   targetPER
%       Maximum permitted PER upper confidence bound.
%
%   maxFirstColumnReady_ms
%       Maximum allowed first-column readiness time.
%
%   fallbackPERMargin
%       Allowed PER upper-bound difference from the best
%       latency-feasible profile when QoS cannot be achieved.
%       Default = 0.02.
%
% Outputs:
%   policyTable
%       One selected MCS profile per channel/SNR operating point.
%
%   selectedRows
%       Original calibration rows selected by the policy.
%
% Selection logic:
%   1. Select QoS-compliant profiles if available.
%   2. Among QoS-compliant profiles, maximize spectral efficiency.
%   3. If QoS is unavailable, find the best latency-feasible PER.
%   4. Keep profiles within fallbackPERMargin of that PER.
%   5. Maximize spectral efficiency within that set.
%   6. If no profile satisfies the readiness constraint,
%      select the profile with minimum readiness time.
%
% Important:
%   Best-effort selection does NOT imply that the QoS target
%   has been achieved.

    %% =====================================================
    %  1. Input validation
    %% =====================================================

    if nargin < 3
        error(['Three inputs are required: profileTable, ', ...
            'targetPER and maxFirstColumnReady_ms.']);
    end

    if nargin < 4 || isempty(fallbackPERMargin)
        fallbackPERMargin = 0.02;
    end

    if ~istable(profileTable) || isempty(profileTable)
        error('profileTable must be a non-empty MATLAB table.');
    end

    validateattributes(targetPER, {'numeric'}, ...
        {'scalar','real','finite','>=',0,'<=',1});

    validateattributes(maxFirstColumnReady_ms, {'numeric'}, ...
        {'scalar','real','finite','positive'});

    validateattributes(fallbackPERMargin, {'numeric'}, ...
        {'scalar','real','finite','>=',0,'<=',1});

    %% =====================================================
    %  2. Check required table variables
    %% =====================================================

    requiredVariables = {
        'Channel'
        'EbN0_dB'
        'Modulation'
        'BitsPerSymbol'
        'CodeRate'
        'InterleaverDepth'
        'BER'
        'PER'
        'PER_Upper95'
        'ProcessingCost_ms'
        'FirstColumnReady_ms'
        'EffectiveSpectralEfficiency'
    };

    missingVariables = setdiff( ...
        requiredVariables, ...
        profileTable.Properties.VariableNames);

    if ~isempty(missingVariables)

        error('Missing profile table variables: %s', ...
            strjoin(missingVariables, ', '));

    end

    %% =====================================================
    %  3. Validate numeric variables
    %% =====================================================

    numericVariables = {
        'EbN0_dB'
        'BitsPerSymbol'
        'CodeRate'
        'InterleaverDepth'
        'BER'
        'PER'
        'PER_Upper95'
        'ProcessingCost_ms'
        'FirstColumnReady_ms'
        'EffectiveSpectralEfficiency'
    };

    for k = 1:numel(numericVariables)

        variableName = numericVariables{k};

        values = profileTable.(variableName);

        if ~isnumeric(values) || ...
                ~isreal(values) || ...
                ~isvector(values) || ...
                numel(values) ~= height(profileTable) || ...
                any(~isfinite(values))

            error('Invalid numeric variable: %s', variableName);

        end

    end

    %% =====================================================
    %  4. Validate numerical ranges
    %% =====================================================

    if any(profileTable.BitsPerSymbol <= 0 | ...
            mod(profileTable.BitsPerSymbol,1) ~= 0)

        error('BitsPerSymbol must contain positive integers.');

    end

    if any(profileTable.CodeRate <= 0 | ...
            profileTable.CodeRate > 1)

        error('CodeRate must be between 0 and 1.');

    end

    if any(profileTable.InterleaverDepth <= 0 | ...
            mod(profileTable.InterleaverDepth,1) ~= 0)

        error('InterleaverDepth must contain positive integers.');

    end

    if any(profileTable.BER < 0 | profileTable.BER > 1)

        error('BER must be between 0 and 1.');

    end

    if any(profileTable.PER < 0 | profileTable.PER > 1)

        error('PER must be between 0 and 1.');

    end

    if any(profileTable.PER_Upper95 < 0 | ...
            profileTable.PER_Upper95 > 1)

        error('PER_Upper95 must be between 0 and 1.');

    end

    if any(profileTable.ProcessingCost_ms < 0)

        error('ProcessingCost_ms cannot be negative.');

    end

    if any(profileTable.FirstColumnReady_ms < 0)

        error('FirstColumnReady_ms cannot be negative.');

    end

    if any(profileTable.EffectiveSpectralEfficiency <= 0)

        error('EffectiveSpectralEfficiency must be positive.');

    end

    %% =====================================================
    %  5. Normalize text variables
    %% =====================================================

    channelNames = lower(strtrim(string(profileTable.Channel)));

    modulationNames = upper(strtrim(string(profileTable.Modulation)));

    if any(ismissing(channelNames)) || any(channelNames == "")

        error('Channel contains missing or empty values.');

    end

    if any(ismissing(modulationNames)) || any(modulationNames == "")

        error('Modulation contains missing or empty values.');

    end

    validChannels = ["rayleigh","rician"];

    validModulations = ["BPSK","QPSK","16QAM"];

    if any(~ismember(channelNames, validChannels))

        error('Unsupported channel type found in profileTable.');

    end

    if any(~ismember(modulationNames, validModulations))

        error('Unsupported modulation found in profileTable.');

    end

    %% =====================================================
    %  6. Check duplicate operating profiles
    %% =====================================================

    keyTable = table( ...
        channelNames, ...
        profileTable.EbN0_dB, ...
        modulationNames, ...
        profileTable.InterleaverDepth, ...
        'VariableNames', {
            'Channel'
            'EbN0_dB'
            'Modulation'
            'InterleaverDepth'
        });

    if height(unique(keyTable)) ~= height(keyTable)

        error(['Duplicate channel/SNR/modulation/depth ', ...
            'profiles found in calibration table.']);

    end

    %% =====================================================
    %  7. Determine operating points
    %% =====================================================

    channelValues = unique(channelNames, 'stable');

    snrValues = unique(profileTable.EbN0_dB, 'sorted');

    %% =====================================================
    %  8. Initialize output variables
    %% =====================================================

    outChannel = strings(0,1);

    outEbN0 = zeros(0,1);

    outModulation = strings(0,1);

    outBitsPerSymbol = zeros(0,1);

    outCodeRate = zeros(0,1);

    outDepth = zeros(0,1);

    outBER = zeros(0,1);

    outPER = zeros(0,1);

    outPERUpper = zeros(0,1);

    outMinimumFeasiblePERUpper = zeros(0,1);

    outFallbackPERLimit = zeros(0,1);

    outProcessingCost = zeros(0,1);

    outFirstColumnReady = zeros(0,1);

    outSpectralEfficiency = zeros(0,1);

    outQoSMet = false(0,1);

    outDelayMet = false(0,1);

    outSelectionMode = strings(0,1);

    selectedIndices = zeros(0,1);

    %% =====================================================
    %  9. Main profile selection
    %% =====================================================

    for c = 1:numel(channelValues)

        for s = 1:numel(snrValues)

            currentChannel = channelValues(c);

            currentSNR = snrValues(s);

            %% Find all profiles for this operating point

            groupIndices = find( ...
                channelNames == currentChannel & ...
                profileTable.EbN0_dB == currentSNR);

            if isempty(groupIndices)
                continue;
            end

            %% Apply first-column readiness constraint

            readiness = ...
                profileTable.FirstColumnReady_ms(groupIndices);

            latencyLocal = find( ...
                readiness <= maxFirstColumnReady_ms);

            latencyCandidates = ...
                groupIndices(latencyLocal);

            %% Initialize diagnostics

            minimumFeasiblePERUpper = NaN;

            fallbackPERLimit = NaN;

            %% Find QoS-compliant profiles

            if ~isempty(latencyCandidates)

                latencyPERUpper = ...
                    profileTable.PER_Upper95(latencyCandidates);

                minimumFeasiblePERUpper = min(latencyPERUpper);

                fallbackPERLimit = min( ...
                    1, ...
                    minimumFeasiblePERUpper + fallbackPERMargin);

                qosLocal = latencyPERUpper <= targetPER;

                qosCandidates = latencyCandidates(qosLocal);

            else

                qosCandidates = zeros(0,1);

            end

            %% =================================================
            %  CASE 1: QoS-compliant candidates exist
            %% =================================================

            if ~isempty(qosCandidates)

                keys = [
                    -profileTable.EffectiveSpectralEfficiency(qosCandidates), ...
                     profileTable.ProcessingCost_ms(qosCandidates), ...
                     profileTable.FirstColumnReady_ms(qosCandidates), ...
                     profileTable.PER_Upper95(qosCandidates)
                ];

                [~, order] = sortrows(keys, [1 2 3 4]);

                selectedIndex = qosCandidates(order(1));

                qosMet = true;

                delayMet = true;

                selectionMode = "QoS-compliant";

            %% =================================================
            %  CASE 2: QoS unavailable, use PER-tolerant fallback
            %% =================================================

            elseif ~isempty(latencyCandidates)

                % Keep all candidates whose PER upper bound
                % is within the configured margin of the best.

                localPER = ...
                    profileTable.PER_Upper95(latencyCandidates);

                nearBestMask = ...
                    localPER <= fallbackPERLimit + 1e-12;

                nearBestCandidates = ...
                    latencyCandidates(nearBestMask);

                if isempty(nearBestCandidates)

                    error('Fallback candidate selection unexpectedly empty.');

                end

                % Among near-best reliability candidates,
                % maximize spectral efficiency.

                keys = [
                    -profileTable.EffectiveSpectralEfficiency(nearBestCandidates), ...
                     profileTable.ProcessingCost_ms(nearBestCandidates), ...
                     profileTable.FirstColumnReady_ms(nearBestCandidates), ...
                     profileTable.PER_Upper95(nearBestCandidates)
                ];

                [~, order] = sortrows(keys, [1 2 3 4]);

                selectedIndex = nearBestCandidates(order(1));

                qosMet = false;

                delayMet = true;

                selectionMode = "Best-effort: QoS not met";

            %% =================================================
            %  CASE 3: No profile meets readiness constraint
            %% =================================================

            else

                keys = [
                    profileTable.FirstColumnReady_ms(groupIndices), ...
                    profileTable.PER_Upper95(groupIndices), ...
                    profileTable.ProcessingCost_ms(groupIndices), ...
                   -profileTable.EffectiveSpectralEfficiency(groupIndices)
                ];

                [~, order] = sortrows(keys, [1 2 3 4]);

                selectedIndex = groupIndices(order(1));

                qosMet = false;

                delayMet = false;

                selectionMode = "Readiness fallback";

            end

            %% =================================================
            %  Store selected profile
            %% =================================================

            outChannel(end+1,1) = currentChannel;

            outEbN0(end+1,1) = currentSNR;

            outModulation(end+1,1) = ...
                modulationNames(selectedIndex);

            outBitsPerSymbol(end+1,1) = ...
                profileTable.BitsPerSymbol(selectedIndex);

            outCodeRate(end+1,1) = ...
                profileTable.CodeRate(selectedIndex);

            outDepth(end+1,1) = ...
                profileTable.InterleaverDepth(selectedIndex);

            outBER(end+1,1) = ...
                profileTable.BER(selectedIndex);

            outPER(end+1,1) = ...
                profileTable.PER(selectedIndex);

            outPERUpper(end+1,1) = ...
                profileTable.PER_Upper95(selectedIndex);

            outMinimumFeasiblePERUpper(end+1,1) = ...
                minimumFeasiblePERUpper;

            outFallbackPERLimit(end+1,1) = ...
                fallbackPERLimit;

            outProcessingCost(end+1,1) = ...
                profileTable.ProcessingCost_ms(selectedIndex);

            outFirstColumnReady(end+1,1) = ...
                profileTable.FirstColumnReady_ms(selectedIndex);

            outSpectralEfficiency(end+1,1) = ...
                profileTable.EffectiveSpectralEfficiency(selectedIndex);

            outQoSMet(end+1,1) = qosMet;

            outDelayMet(end+1,1) = delayMet;

            outSelectionMode(end+1,1) = selectionMode;

            selectedIndices(end+1,1) = selectedIndex;

        end

    end

    %% =====================================================
    %  10. Construct final policy table
    %% =====================================================

    policyTable = table( ...
        outChannel, ...
        outEbN0, ...
        outModulation, ...
        outBitsPerSymbol, ...
        outCodeRate, ...
        outDepth, ...
        outBER, ...
        outPER, ...
        outPERUpper, ...
        outMinimumFeasiblePERUpper, ...
        outFallbackPERLimit, ...
        outProcessingCost, ...
        outFirstColumnReady, ...
        outSpectralEfficiency, ...
        outQoSMet, ...
        outDelayMet, ...
        outSelectionMode, ...
        'VariableNames', {
            'Channel'
            'EbN0_dB'
            'SelectedModulation'
            'BitsPerSymbol'
            'CodeRate'
            'SelectedInterleaverDepth'
            'CalibrationBER'
            'CalibrationPER'
            'PER_Upper95'
            'MinimumFeasiblePER_Upper95'
            'FallbackPERLimit_Upper95'
            'ProcessingCost_ms'
            'FirstColumnReady_ms'
            'EffectiveSpectralEfficiency'
            'QoS_Met'
            'Delay_Met'
            'SelectionMode'
        });

    %% Original selected calibration rows

    selectedRows = profileTable(selectedIndices,:);

end