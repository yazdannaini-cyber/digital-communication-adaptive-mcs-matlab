
function [selectedDepth, decision] = ...
    select_interleaver_depth(channelType, EbN0_dB, targetPER)
%SELECT_INTERLEAVER_DEPTH QoS-based adaptive interleaver controller.
%
% Inputs:
%   channelType : 'Rayleigh' or 'Rician'
%   EbN0_dB     : estimated operating Eb/N0 in dB
%   targetPER   : required maximum PER, between 0 and 1
%
% Outputs:
%   selectedDepth : 4 or 16
%   decision      : struct containing selection information
%
% Policy:
%   Select the smallest supported depth whose calibrated 95% PER
%   upper confidence bound meets targetPER.
%
%   If neither depth meets the target, select depth 16 as the
%   reliability-oriented fallback and report targetMet = false.
%
% Calibration range:
%   Eb/N0 = [4 6 8 10 12] dB
%
% Calibration data:
%   Upper 95% PER confidence bounds from Milestone 29.7.

    %% Input validation

    if nargin ~= 3
        error(['Three inputs are required: channelType, ', ...
               'EbN0_dB, and targetPER.']);
    end

    if isstring(channelType)
        if ~isscalar(channelType)
            error('channelType must be a scalar string or character vector.');
        end
        channelType = char(channelType);
    end

    if ~ischar(channelType) || isempty(channelType)
        error('channelType must be Rayleigh or Rician.');
    end

    if ~isscalar(EbN0_dB) || ~isfinite(EbN0_dB)
        error('EbN0_dB must be a finite scalar.');
    end

    if ~isscalar(targetPER) || ~isfinite(targetPER) || ...
            targetPER <= 0 || targetPER >= 1
        error('targetPER must be strictly between 0 and 1.');
    end

    %% Calibration grid

    snrGrid = [4 6 8 10 12];

    channelType = lower(strtrim(channelType));

    switch channelType

        case 'rayleigh'

            channelIndex = 1;

        case 'rician'

            channelIndex = 2;

        otherwise

            error('Unsupported channel type. Use Rayleigh or Rician.');

    end

    %% Calibration: upper 95% PER confidence bounds
    %
    % Rows:
    %   1 = Rayleigh
    %   2 = Rician
    %
    % Columns:
    %   Eb/N0 = 4, 6, 8, 10, 12 dB

    depth4Upper95 = [
        0.94985, 0.84211, 0.69812, 0.55059, 0.39113;
        0.86546, 0.58904, 0.32781, 0.17473, 0.089513
    ];

    depth16Upper95 = [
        0.94985, 0.83665, 0.68784, 0.54161, 0.37804;
        0.85379, 0.56434, 0.31467, 0.16981, 0.085553
    ];

    %% Find exact supported SNR point

    snrIndex = find(abs(snrGrid - EbN0_dB) < 1e-9, 1);

    if isempty(snrIndex)

        error(['Eb/N0 = %.3f dB is outside the calibrated grid. ', ...
               'Supported values are 4, 6, 8, 10, and 12 dB.'], ...
               EbN0_dB);

    end

    %% Retrieve calibrated confidence bounds

    depth4Bound = depth4Upper95(channelIndex, snrIndex);
    depth16Bound = depth16Upper95(channelIndex, snrIndex);

    %% QoS-based depth selection

    if depth4Bound <= targetPER

        selectedDepth = 4;

        targetMet = true;

        reason = ...
            'Depth 4 satisfies the target; minimum supported depth selected.';

    elseif depth16Bound <= targetPER

        selectedDepth = 16;

        targetMet = true;

        reason = ...
            'Depth 4 fails the target; Depth 16 satisfies it.';

    else

        selectedDepth = 16;

        targetMet = false;

        reason = ...
            ['Neither depth satisfies the target; ', ...
             'Depth 16 selected as reliability-oriented fallback.'];

    end

    %% Decision report

    decision = struct();

    decision.channelType = channelType;
    decision.EbN0_dB = EbN0_dB;
    decision.targetPER = targetPER;

    decision.depth4Upper95 = depth4Bound;
    decision.depth16Upper95 = depth16Bound;

    decision.selectedDepth = selectedDepth;
    decision.targetMet = targetMet;

    decision.reason = reason;

    decision.calibrationGrid_dB = snrGrid;

end
