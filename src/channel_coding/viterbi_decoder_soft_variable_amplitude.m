
function decodedBits = viterbi_decoder_soft_variable_amplitude( ...
    receivedSamples, symbolAmplitude)
%VITERBI_DECODER_SOFT_VARIABLE_AMPLITUDE
% Soft-decision Viterbi decoder for a rate-1/2 convolutional code.
%
% Generator polynomials: [7 5] octal
% Constraint length: 3
% Number of states: 4
% Two zero tail bits are expected.
%
% receivedSamples:
%   Real-valued soft samples, two samples per trellis step.
%
% symbolAmplitude:
%   Either a positive scalar or a nonnegative vector with one
%   amplitude per received sample.
%
% The expected BPSK sample for each coded bit is:
%   amplitude(k) * (1 - 2*codedBit(k))
%
% Output:
%   Decoded information bits, excluding the two tail bits.

    %% Input validation

    if ~isvector(receivedSamples) || isempty(receivedSamples)
        error('receivedSamples must be a non-empty vector.');
    end

    if ~isreal(receivedSamples) || any(~isfinite(receivedSamples(:)))
        error('receivedSamples must contain finite real values.');
    end

    if ~isvector(symbolAmplitude) && ~isscalar(symbolAmplitude)
        error('symbolAmplitude must be a scalar or vector.');
    end

    if isempty(symbolAmplitude) || ...
            any(~isfinite(symbolAmplitude(:))) || ...
            any(symbolAmplitude(:) < 0)
        error('symbolAmplitude must contain finite nonnegative values.');
    end

    originalWasRow = isrow(receivedSamples);

    rx = double(receivedSamples(:));
    amplitude = double(symbolAmplitude(:));

    N = numel(rx);

    if mod(N, 2) ~= 0
        error('Received sample length must be even.');
    end

    if isscalar(amplitude)
        amplitude = repmat(amplitude, N, 1);
    elseif numel(amplitude) ~= N
        error('Amplitude vector length must match received sample length.');
    end

    numSteps = N / 2;

    if numSteps < 3
        error('At least three trellis steps are required.');
    end

    %% Trellis initialization

    numStates = 4;

    pathMetric = inf(numStates, 1);
    pathMetric(1) = 0;  % Initial state = 00

    predecessorHistory = zeros(numSteps + 1, numStates, 'uint8');
    inputHistory = zeros(numSteps + 1, numStates, 'uint8');

    %% Viterbi forward recursion

    for k = 1:numSteps

        nextMetric = inf(numStates, 1);

        rxPair = rx(2*k-1 : 2*k);
        ampPair = amplitude(2*k-1 : 2*k);

        for state = 0:3

            if isinf(pathMetric(state + 1))
                continue;
            end

            % State definition:
            % state = 2*previousBit1 + previousBit2

            previousBit1 = floor(state / 2);
            previousBit2 = mod(state, 2);

            for inputBit = 0:1

                % Generator polynomial [7 5] octal

                outputBit1 = mod( ...
                    inputBit + previousBit1 + previousBit2, 2);

                outputBit2 = mod( ...
                    inputBit + previousBit2, 2);

                % BPSK mapping: 0 -> +1, 1 -> -1

                expectedPair = ampPair .* ...
                    (1 - 2*[outputBit1; outputBit2]);

                % Squared Euclidean branch metric

                branchMetric = sum((rxPair - expectedPair).^2);

                % Next state

                nextState = 2*inputBit + previousBit1;

                candidateMetric = ...
                    pathMetric(state + 1) + branchMetric;

                if candidateMetric < nextMetric(nextState + 1)

                    nextMetric(nextState + 1) = candidateMetric;

                    predecessorHistory(k + 1, nextState + 1) = ...
                        uint8(state);

                    inputHistory(k + 1, nextState + 1) = ...
                        uint8(inputBit);
                end
            end
        end

        pathMetric = nextMetric;
    end

    %% Force final state to zero

    finalState = 0;

    if isinf(pathMetric(finalState + 1))
        error('No valid trellis path found.');
    end

    %% Traceback

    decodedWithTail = zeros(numSteps, 1);

    state = finalState;

    for k = numSteps:-1:1

        decodedWithTail(k) = ...
            double(inputHistory(k + 1, state + 1));

        state = double( ...
            predecessorHistory(k + 1, state + 1));
    end

    %% Remove two zero tail bits

    decodedBits = decodedWithTail(1:end-2);

    if originalWasRow
        decodedBits = decodedBits.';
    end
end
