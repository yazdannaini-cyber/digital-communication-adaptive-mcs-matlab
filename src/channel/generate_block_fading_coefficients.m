
function h = generate_block_fading_coefficients( ...
    numBlocks,channelType,K_dB)

    % =========================================
    % BLOCK FADING COEFFICIENT GENERATOR
    %
    % One channel coefficient per block
    % Average channel power = 1
    % =========================================

    %% 1. Default K-factor

    if nargin < 3 || isempty(K_dB)

        K_dB = 6;

    end

    %% 2. Validate Number of Blocks

    if ~isnumeric(numBlocks) || ...
       ~isreal(numBlocks) || ...
       ~isscalar(numBlocks) || ...
       ~isfinite(numBlocks) || ...
       numBlocks < 1 || ...
       fix(numBlocks) ~= numBlocks

        error('numBlocks must be a positive integer.');

    end

    %% 3. Validate Channel Type

    if ~(ischar(channelType) || ...
       (isstring(channelType) && isscalar(channelType)))

        error('Channel type must be a valid string.');

    end

    channelType = lower(strtrim(char(channelType)));

    %% 4. Generate Fading Coefficients

    switch channelType

        case 'rayleigh'

            h = (randn(numBlocks,1) + ...
                 1i*randn(numBlocks,1))/sqrt(2);

        case 'rician'

            if ~isnumeric(K_dB) || ...
               ~isreal(K_dB) || ...
               ~isscalar(K_dB) || ...
               ~isfinite(K_dB)

                error('Invalid Rician K-factor.');

            end

            K = 10^(K_dB/10);

            if ~isfinite(K)

                error('K-factor outside numerical range.');

            end

            hLOS = sqrt(K/(K+1));

            hScatter = ...
                (randn(numBlocks,1) + ...
                 1i*randn(numBlocks,1))/sqrt(2);

            h = hLOS + ...
                sqrt(1/(K+1))*hScatter;

        otherwise

            error('Unsupported fading channel.');

    end

end
