
function [hEstimate, estimationError] = ...
    estimate_channel(hTrue, NMSE_dB)

    % =========================================
    % ADDITIVE COMPLEX GAUSSIAN CHANNEL ESTIMATOR
    %
    % hEstimate = hTrue + estimationError
    %
    % NMSE = E[|hEstimate-hTrue|^2] / E[|hTrue|^2]
    %
    % Assumption:
    % Average channel power = 1
    % =========================================

    %% 1. Validate True Channel

    if ~isnumeric(hTrue) || ...
       isempty(hTrue) || ...
       any(~isfinite(real(hTrue(:)))) || ...
       any(~isfinite(imag(hTrue(:))))

        error('True channel must contain finite numeric values.');

    end

    %% 2. Validate NMSE

    if ~isnumeric(NMSE_dB) || ...
       ~isreal(NMSE_dB) || ...
       ~isscalar(NMSE_dB) || ...
       ~isfinite(NMSE_dB)

        error('NMSE_dB must be a finite real scalar.');

    end

    %% 3. Convert NMSE from dB to Linear

    NMSE_linear = 10^(NMSE_dB/10);

    if ~isfinite(NMSE_linear)

        error('NMSE is outside the supported numerical range.');

    end

    %% 4. Generate Complex Gaussian Estimation Error

    estimationError = ...
        sqrt(NMSE_linear/2) .* ...
        (randn(size(hTrue)) + ...
         1i*randn(size(hTrue)));

    %% 5. Calculate Estimated Channel

    hEstimate = hTrue + estimationError;

end
