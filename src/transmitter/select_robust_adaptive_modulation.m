
function [modeIndex,modeName,guardedSNR_dB] = ...
    select_robust_adaptive_modulation( ...
    estimatedSNR_dB,safetyMargin_dB,thresholds)

    % =========================================
    % ROBUST ADAPTIVE MODULATION SELECTOR
    %
    % Estimated SNR - Safety Margin
    % =========================================

    %% 1. Validate Estimated SNR

    if ~isnumeric(estimatedSNR_dB) || ...
       ~isreal(estimatedSNR_dB) || ...
       ~isscalar(estimatedSNR_dB) || ...
       isnan(estimatedSNR_dB) || ...
       estimatedSNR_dB == Inf

        error('Estimated SNR must be a valid real scalar.');

    end

    %% 2. Validate Safety Margin

    if ~isnumeric(safetyMargin_dB) || ...
       ~isreal(safetyMargin_dB) || ...
       ~isscalar(safetyMargin_dB) || ...
       ~isfinite(safetyMargin_dB) || ...
       safetyMargin_dB < 0

        error('Safety margin must be a finite non-negative scalar.');

    end

    %% 3. Apply Safety Margin

    guardedSNR_dB = ...
        estimatedSNR_dB-safetyMargin_dB;

    %% 4. Select Modulation Using Existing Controller

    [modeIndex,modeName] = ...
        select_adaptive_modulation( ...
        guardedSNR_dB,thresholds);

end
