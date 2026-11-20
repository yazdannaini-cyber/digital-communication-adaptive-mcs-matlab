
function ber = theoretical_ber_16qam_fading( ...
    EbN0_dB, channelType, K_dB)

    % =========================================
    % THEORETICAL GRAY-CODED 16-QAM BER
    % AWGN / RAYLEIGH / RICIAN
    % =========================================

    if nargin < 3 || isempty(K_dB)
        K_dB = 6;
    end

    %% Validate Eb/N0

    if ~isnumeric(EbN0_dB) || ...
       ~isreal(EbN0_dB) || isempty(EbN0_dB) || ...
       any(~isfinite(EbN0_dB(:)))

        error('EbN0_dB must contain finite real values.');

    end

    %% Validate Channel Type

    if ~(ischar(channelType) || ...
       (isstring(channelType) && isscalar(channelType)))

        error('Channel type must be a string or character vector.');

    end

    channelType = lower(strtrim(char(channelType)));

    validChannels = {'awgn','rayleigh','rician'};

    if ~ismember(channelType,validChannels)

        error('Unsupported channel type.');

    end

    %% Validate Rician K-factor

    if ~isnumeric(K_dB) || ...
       ~isreal(K_dB) || ...
       ~isscalar(K_dB) || ...
       ~isfinite(K_dB)

        error('K_dB must be a finite real scalar.');

    end

    %% Convert Parameters

    gamma = 10.^(EbN0_dB/10);

    if any(~isfinite(gamma(:))) || any(gamma(:) <= 0)

        error('EbN0 is outside the supported numerical range.');

    end

    %% Gaussian Q-function

    Q = @(x) 0.5*erfc(x/sqrt(2));

    %% Calculate BER

    ber = zeros(size(gamma));

    for k = 1:numel(gamma)

        currentGamma = gamma(k);

        switch channelType

            case 'awgn'

                a = sqrt(0.8*currentGamma);

                ber(k) = ...
                    0.75*Q(a) + ...
                    0.50*Q(3*a) - ...
                    0.25*Q(5*a);

            case 'rayleigh'

                % Rayleigh amplitude PDF
                pdf = @(r) 2*r.*exp(-r.^2);

                conditionalBER = @(r) ...
                    qam16_conditional_ber( ...
                    r,currentGamma,Q);

                ber(k) = integral( ...
                    @(r) conditionalBER(r).*pdf(r), ...
                    0,Inf, ...
                    'RelTol',1e-8, ...
                    'AbsTol',1e-12);

            case 'rician'

                K = 10^(K_dB/10);

                if ~isfinite(K)
                    error('K-factor exceeds numerical range.');
                end

                % Normalized Rician amplitude PDF
                pdf = @(r) ...
                    2*(K+1).*r .* ...
                    exp(-(sqrt(K+1).*r-sqrt(K)).^2) .* ...
                    besseli(0, ...
                    2*r*sqrt(K*(K+1)),1);

                conditionalBER = @(r) ...
                    qam16_conditional_ber( ...
                    r,currentGamma,Q);

                ber(k) = integral( ...
                    @(r) conditionalBER(r).*pdf(r), ...
                    0,Inf, ...
                    'RelTol',1e-8, ...
                    'AbsTol',1e-12);

        end

    end

end


function p = qam16_conditional_ber(r,gamma,Q)

    a = sqrt(0.8*gamma).*r;

    p = 0.75*Q(a) + ...
        0.50*Q(3*a) - ...
        0.25*Q(5*a);

end
