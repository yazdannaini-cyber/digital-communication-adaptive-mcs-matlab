
function [modeIndex, modeName] = ...
    select_adaptive_modulation(instantaneousEsN0_dB,thresholds)

    % =========================================
    % ADAPTIVE MODULATION SELECTOR
    %
    % Output:
    % 0 = OUTAGE
    % 1 = BPSK
    % 2 = QPSK
    % 3 = 16-QAM
    % =========================================

    %% 1. Validate SNR

    if ~isnumeric(instantaneousEsN0_dB) || ...
       ~isreal(instantaneousEsN0_dB) || ...
       ~isscalar(instantaneousEsN0_dB) || ...
       isnan(instantaneousEsN0_dB) || ...
       instantaneousEsN0_dB == Inf

        error('SNR must be a valid real scalar.');

    end

    %% 2. Validate Threshold Structure

    if ~isstruct(thresholds) || ...
       ~isfield(thresholds,'requiredEsN0_dB') || ...
       ~isfield(thresholds,'modulationNames')

        error('Invalid threshold structure.');

    end

    snrThresholds = thresholds.requiredEsN0_dB;

    if ~isnumeric(snrThresholds) || ...
       ~isvector(snrThresholds) || ...
       isempty(snrThresholds) || ...
       any(~isfinite(snrThresholds)) || ...
       any(diff(snrThresholds) <= 0)

        error('Modulation thresholds must be finite and increasing.');

    end

    %% 3. Find Highest Supported Modulation

    selectedMode = find( ...
        instantaneousEsN0_dB >= snrThresholds, ...
        1,'last');

    %% 4. Handle Outage

    if isempty(selectedMode)

        modeIndex = 0;

        modeName = 'OUTAGE';

    else

        modeIndex = selectedMode;

        modeName = ...
            thresholds.modulationNames{modeIndex};

    end

end
