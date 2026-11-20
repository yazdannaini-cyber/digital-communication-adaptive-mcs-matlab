function ber = theoretical_hamming74_ber(EbN0_dB,codeRate)

% =========================================================
% THEORETICAL BER OF HAMMING (7,4)
% Hard-decision BPSK decoding over AWGN
%
% Exact enumeration of all 128 possible channel error
% patterns for each Hamming codeword.
% =========================================================

    if ~isnumeric(EbN0_dB) || ...
       isempty(EbN0_dB) || ...
       any(~isfinite(EbN0_dB(:))) || ...
       ~isreal(EbN0_dB)

        error('EbN0_dB must contain finite real values.');

    end

    if ~isscalar(codeRate) || ...
       ~isfinite(codeRate) || ...
       codeRate <= 0 || codeRate > 1

        error('Invalid code rate.');

    end

    H = hamming74_parity_check_matrix();

    EbN0_dB = EbN0_dB(:).';

    ber = zeros(size(EbN0_dB));

    errorPatterns = dec2bin(0:127,7)-'0';

    for snrIndex = 1:numel(EbN0_dB)

        gamma = 10^(EbN0_dB(snrIndex)/10);

        % Hard-decision coded channel BER

        p = 0.5*erfc(sqrt(codeRate*gamma));

        currentBER = 0;

        for k = 1:size(errorPatterns,1)

            errorVector = errorPatterns(k,:).';

            errorWeight = sum(errorVector);

            syndrome = mod(H*errorVector,2);

            residualError = errorVector;

            % Syndrome-based single-bit correction

            if any(syndrome)

                position = find( ...
                    all(bsxfun(@eq,H,syndrome),1), ...
                    1,'first');

                if isempty(position)
                    error('Invalid syndrome.');
                end

                residualError(position) = ...
                    1-residualError(position);

            end

            % Information positions are 1 through 4

            informationErrors = sum(residualError(1:4));

            % Probability of this error pattern

            patternProbability = ...
                p^errorWeight*(1-p)^(7-errorWeight);

            currentBER = currentBER + ...
                (informationErrors/4)*patternProbability;

        end

        ber(snrIndex) = currentBER;

    end

end