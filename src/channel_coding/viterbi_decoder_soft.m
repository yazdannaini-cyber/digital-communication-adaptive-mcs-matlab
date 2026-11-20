function [decodedBits, finalPathMetric] = ...
    viterbi_decoder_soft(receivedSamples, symbolAmplitude)

% =========================================================
% SOFT-DECISION VITERBI DECODER
%
% Code Rate: 1/2
% Constraint Length: 3
% Generators: [7 5] Octal
% Number of States: 4
%
% Modulation: BPSK
% Metric: Squared Euclidean Distance
%
% Initial State: 00
% Final State:   00
% Tail Bits:     2
% =========================================================

%% 1. Validate Input

if ~isnumeric(receivedSamples)
    error('Input must be numeric.');
end

if isempty(receivedSamples) || ~isvector(receivedSamples)
    error('Input must be a non-empty vector.');
end

if ~isreal(receivedSamples) || ...
   any(~isfinite(receivedSamples(:)))

    error('Received samples must be finite real values.');

end

%% 2. Symbol Amplitude

if nargin < 2 || isempty(symbolAmplitude)
    symbolAmplitude = 1;
end

if ~isnumeric(symbolAmplitude) || ...
   ~isreal(symbolAmplitude) || ...
   ~isscalar(symbolAmplitude) || ...
   ~isfinite(symbolAmplitude) || ...
   symbolAmplitude <= 0

    error('Symbol amplitude must be a positive finite scalar.');

end

%% 3. Convert Input

receivedSamples = double(receivedSamples(:).');

%% 4. Validate Length

if mod(numel(receivedSamples),2) ~= 0
    error('Received sample count must be even.');
end

numSteps = numel(receivedSamples)/2;

if numSteps < 3
    error('Insufficient samples for terminated decoding.');
end

%% 5. Trellis Configuration

numStates = 4;

%% 6. Initialize Path Metrics

pathMetrics = inf(numStates,numSteps+1);

% Initial state = 00

pathMetrics(1,1) = 0;

%% 7. Survivor Storage

predecessorStates = -ones(numStates,numSteps);

predecessorInputs = -ones(numStates,numSteps);

%% 8. VITERBI FORWARD PROCESSING

for t = 1:numSteps

    rxPair = receivedSamples(2*t-1:2*t);

    for state = 0:numStates-1

        stateMSB = floor(state/2);

        stateLSB = mod(state,2);

        currentMetric = pathMetrics(state+1,t);

        if ~isfinite(currentMetric)
            continue;
        end

        %% Try Both Input Bits

        for u = 0:1

            % Generator 7: 111

            v0 = mod(u + stateMSB + stateLSB,2);

            % Generator 5: 101

            v1 = mod(u + stateLSB,2);

            expectedBits = [v0 v1];

            %% BPSK Expected Symbols

            expectedSymbols = ...
                symbolAmplitude*(1-2*expectedBits);

            %% Soft Branch Metric

            branchMetric = sum( ...
                (rxPair-expectedSymbols).^2);

            %% Next State

            nextState = 2*u + stateMSB;

            %% Candidate Metric

            candidateMetric = ...
                currentMetric + branchMetric;

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
    error('No valid path to terminated final state.');
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

%% 11. INITIAL STATE VALIDATION

if state ~= 0
    error('Traceback did not reach initial state.');
end

%% 12. REMOVE TAIL BITS

decodedBits = decodedFull(1:end-2);

end