
function decodedBits = viterbi_decoder_soft_llr(llr)
%VITERBI_DECODER_SOFT_LLR Soft-decision Viterbi decoder using LLR inputs.
%
% Code:
%   Rate 1/2 convolutional code.
%   Constraint length K = 3.
%   Generator polynomials [7 5] octal.
%   Four trellis states.
%   Two zero termination bits expected.
%
% Input:
%   llr : Real-valued LLR column or row vector.
%         Positive LLR favors bit 0.
%         Negative LLR favors bit 1.
%
% Output:
%   decodedBits : Recovered information bits without tail bits.
%
% Branch metric:
%   sum(max(0, (2*codedBit-1).*LLR))
%
% Lower path metric is better.

    %% Validate input

    if ~isnumeric(llr) || ...
            ~isvector(llr) || isempty(llr)

        error('LLR input must be a non-empty numeric vector.');

    end

    if ~isreal(llr) || any(~isfinite(llr(:)))

        error('LLR input must contain finite real values.');

    end

    originalWasRow = isrow(llr);

    llr = double(llr(:));

    N = numel(llr);

    if mod(N, 2) ~= 0

        error('LLR length must be even for a rate-1/2 code.');

    end

    numSteps = N / 2;

    if numSteps < 3

        error('At least three trellis steps are required.');

    end

    %% Trellis initialization

    numStates = 4;

    pathMetric = inf(numStates, 1);

    % Initial state = 00

    pathMetric(1) = 0;

    predecessorHistory = zeros( ...
        numSteps + 1, numStates, 'uint8');

    inputHistory = zeros( ...
        numSteps + 1, numStates, 'uint8');

    %% Forward recursion

    for k = 1:numSteps

        nextMetric = inf(numStates, 1);

        llrPair = llr(2*k-1 : 2*k);

        for state = 0:3

            if isinf(pathMetric(state + 1))
                continue;
            end

            % State representation:
            % state = 2*previousBit1 + previousBit2

            previousBit1 = floor(state / 2);

            previousBit2 = mod(state, 2);

            for inputBit = 0:1

                %% Convolutional encoder outputs

                % Generator polynomial 7 octal

                outputBit1 = mod( ...
                    inputBit + previousBit1 + previousBit2, 2);

                % Generator polynomial 5 octal

                outputBit2 = mod( ...
                    inputBit + previousBit2, 2);

                outputPair = [outputBit1; outputBit2];

                %% LLR branch metric

                branchMetric = sum(max( ...
                    0, (2*outputPair - 1) .* llrPair));

                %% Next state

                nextState = ...
                    2*inputBit + previousBit1;

                candidateMetric = ...
                    pathMetric(state + 1) + branchMetric;

                %% Survivor path selection

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

    %% Remove two termination bits

    decodedBits = decodedWithTail(1:end-2);

    if originalWasRow
        decodedBits = decodedBits.';
    end

end
