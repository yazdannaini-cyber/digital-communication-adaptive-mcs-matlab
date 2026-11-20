function [decodedBits,finalPathMetric] = ...
    viterbi_decoder_hard(receivedBits)

% =========================================================
% HARD-DECISION VITERBI DECODER
%
% Code Rate: 1/2
% Constraint Length: 3
% Generators: [7 5] Octal
% Number of States: 4
%
% Assumptions:
%   Initial encoder state = 0
%   Final encoder state = 0
%   Two zero tail bits were appended
%
% =========================================================

%% 1. Validate Input Type

if ~(isnumeric(receivedBits) || islogical(receivedBits))
    error('Input must be numeric or logical.');
end

%% 2. Validate Input Dimensions

if isempty(receivedBits) || ~isvector(receivedBits)
    error('Input must be a non-empty vector.');
end

%% 3. Validate Finite Binary Values

if ~isreal(receivedBits) || ...
   any(~isfinite(double(receivedBits(:))))

    error('Input must contain finite real values.');

end

receivedBits = double(receivedBits(:).');

if any(receivedBits ~= 0 & receivedBits ~= 1)
    error('Received bits must be binary.');
end

%% 4. Validate Length

if mod(numel(receivedBits),2) ~= 0
    error('Received coded sequence length must be even.');
end

numSteps = numel(receivedBits)/2;

% At least one information bit plus two tail bits

if numSteps < 3
    error('Insufficient coded bits for terminated decoding.');
end

%% 5. Trellis Configuration

numStates = 4;

% State representation:
%
% state = 2*stateMSB + stateLSB
%
% State 0 = 00
% State 1 = 01
% State 2 = 10
% State 3 = 11

%% 6. Initialize Path Metrics

pathMetrics = inf(numStates,numSteps+1);

% Initial state is zero

pathMetrics(1,1) = 0;

%% 7. Survivor Storage

predecessorStates = -ones(numStates,numSteps);

predecessorInputs = -ones(numStates,numSteps);

%% 8. VITERBI FORWARD PROCESSING

for t = 1:numSteps

    rxPair = receivedBits(2*t-1:2*t);

    for state = 0:numStates-1

        stateMSB = floor(state/2);

        stateLSB = mod(state,2);

        currentMetric = pathMetrics(state+1,t);

        if ~isfinite(currentMetric)
            continue;
        end

        %% Try Both Possible Input Bits

        for u = 0:1

            % Expected encoder output

            v0 = mod(u + stateMSB + stateLSB,2);

            v1 = mod(u + stateLSB,2);

            expectedPair = [v0 v1];

            %% Branch Metric

            branchMetric = sum(expectedPair ~= rxPair);

            %% Next State

            nextState = 2*u + stateMSB;

            %% Candidate Path Metric

            candidateMetric = currentMetric + branchMetric;

            %% Add-Compare-Select

            if candidateMetric < ...
                    pathMetrics(nextState+1,t+1)

                pathMetrics(nextState+1,t+1) = ...
                    candidateMetric;

                predecessorStates(nextState+1,t) = state;

                predecessorInputs(nextState+1,t) = u;

            end

        end

    end

end

%% 9. FORCE FINAL STATE TO ZERO

finalState = 0;

finalPathMetric = pathMetrics(finalState+1,end);

if ~isfinite(finalPathMetric)

    error('No valid path to the terminated final state.');

end

%% 10. TRACEBACK

decodedFull = zeros(1,numSteps);

state = finalState;

for t = numSteps:-1:1

    stateIndex = state+1;

    previousState = predecessorStates(stateIndex,t);

    inputBit = predecessorInputs(stateIndex,t);

    if previousState < 0 || inputBit < 0

        error('Invalid traceback path.');

    end

    decodedFull(t) = inputBit;

    state = previousState;

end

%% 11. INITIAL STATE VERIFICATION

if state ~= 0

    error('Traceback did not reach the initial state.');

end

%% 12. REMOVE TWO TAIL BITS

decodedBits = decodedFull(1:end-2);

end