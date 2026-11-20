
function thresholds = calculate_amc_thresholds(targetBER)

    % =========================================
    % ADAPTIVE MODULATION THRESHOLD CALCULATOR
    %
    % Modulations:
    % BPSK, QPSK, 16-QAM
    %
    % Fixed average symbol energy
    % =========================================

    %% 1. Validate Target BER

    if ~isnumeric(targetBER) || ...
       ~isreal(targetBER) || ...
       ~isscalar(targetBER) || ...
       ~isfinite(targetBER) || ...
       targetBER <= 0 || targetBER >= 0.1

        error('Target BER must be between 0 and 0.1.');

    end

    %% 2. Modulation Parameters

    names = {'BPSK','QPSK','16-QAM'};

    bitsPerSymbol = [1 2 4];

    numModes = numel(bitsPerSymbol);

    requiredEbN0_dB = zeros(1,numModes);

    %% 3. Gaussian Q-function

    Q = @(x) 0.5*erfc(x/sqrt(2));

    %% 4. Find Required Eb/N0 Using Bisection

    for m = 1:numModes

        lowerBound = -20;

        upperBound = 40;

        for iteration = 1:100

            midPoint = ...
                (lowerBound+upperBound)/2;

            gamma = 10^(midPoint/10);

            %% Theoretical BER

            if m == 1 || m == 2

                currentBER = ...
                    0.5*erfc(sqrt(gamma));

            else

                a = sqrt(0.8*gamma);

                currentBER = ...
                    0.75*Q(a) + ...
                    0.50*Q(3*a) - ...
                    0.25*Q(5*a);

            end

            %% Bisection Update

            if currentBER > targetBER

                lowerBound = midPoint;

            else

                upperBound = midPoint;

            end

        end

        requiredEbN0_dB(m) = ...
            (lowerBound+upperBound)/2;

    end

    %% 5. Convert Required Eb/N0 to Es/N0

    requiredEsN0_dB = ...
        requiredEbN0_dB + 10*log10(bitsPerSymbol);

    %% 6. Create Threshold Structure

    thresholds.targetBER = targetBER;

    thresholds.modulationNames = names;

    thresholds.bitsPerSymbol = bitsPerSymbol;

    thresholds.requiredEbN0_dB = requiredEbN0_dB;

    thresholds.requiredEsN0_dB = requiredEsN0_dB;

end
