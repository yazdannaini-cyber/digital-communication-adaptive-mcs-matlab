
function ber = theoretical_ber_rician_bpsk(EbN0_dB,K_dB)

    % =========================================
    % THEORETICAL BPSK BER OVER RICIAN FADING
    %
    % Supports:
    % - Scalar K-factor
    % - Vector K-factor
    % - Scalar Eb/N0
    % - Vector Eb/N0
    %
    % Perfect CSI and coherent detection
    % Average channel power = 1
    % =========================================

    %% 1. Default K-factor

    if nargin < 2 || isempty(K_dB)
        K_dB = 6;
    end

    %% 2. Validate Eb/N0

    if ~isnumeric(EbN0_dB) || ...
       ~isreal(EbN0_dB) || ...
       isempty(EbN0_dB) || ...
       ~isvector(EbN0_dB) || ...
       any(~isfinite(EbN0_dB(:)))

        error('EbN0_dB must contain finite real values.');

    end

    %% 3. Validate K-factor

    if ~isnumeric(K_dB) || ...
       ~isreal(K_dB) || ...
       isempty(K_dB) || ...
       ~isvector(K_dB) || ...
       any(~isfinite(K_dB(:)))

        error('K_dB must contain finite real scalar or vector values.');

    end

    %% 4. Convert to Linear Scale

    gamma = 10.^(double(EbN0_dB(:))/10);

    K_values = 10.^(double(K_dB(:))/10);

    if any(~isfinite(gamma)) || ...
       any(gamma <= 0) || ...
       any(~isfinite(K_values))

        error('Input values exceed the supported numerical range.');

    end

    %% 5. Initialize Result Matrix

    % Rows: Eb/N0 values
    % Columns: K-factor values

    berMatrix = zeros(numel(gamma),numel(K_values));

    %% 6. Gaussian Q-function

    Q = @(x) 0.5*erfc(x/sqrt(2));

    %% 7. Numerical BER Integration

    for i = 1:numel(gamma)

        currentGamma = gamma(i);

        for j = 1:numel(K_values)

            K = K_values(j);

            % Conditional BPSK BER

            conditionalBER = @(r) ...
                0.5*erfc(sqrt(currentGamma).*r);

            % Normalized Rician amplitude PDF

            ricianPDF = @(r) ...
                2*(K+1).*r .* ...
                exp(-(sqrt(K+1).*r-sqrt(K)).^2) .* ...
                besseli(0, ...
                2*r*sqrt(K*(K+1)),1);

            % Average BER

            integrand = @(r) ...
                conditionalBER(r).*ricianPDF(r);

            berMatrix(i,j) = integral( ...
                integrand,0,Inf, ...
                'RelTol',1e-9, ...
                'AbsTol',1e-12);

        end

    end

    %% 8. Restore Output Dimensions

    if isscalar(K_dB)

        % One K-factor, multiple Eb/N0 values

        ber = reshape(berMatrix,size(EbN0_dB));

    elseif isscalar(EbN0_dB)

        % One Eb/N0 value, multiple K-factors

        ber = reshape(berMatrix,size(K_dB));

    else

        % Multiple Eb/N0 and K-factor values
        % Rows correspond to Eb/N0
        % Columns correspond to K-factor

        ber = berMatrix;

    end

end
