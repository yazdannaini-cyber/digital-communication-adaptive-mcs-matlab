function codedBits = convolutional_encoder(bits)

% =========================================================
% CONVOLUTIONAL ENCODER
%
% Code Rate: 1/2
% Constraint Length: 3
% Generators: [7 5] Octal
% Memory: 2
% Termination: Two zero tail bits
%
% Output order: [v0 v1]
% =========================================================

%% 1. Validate Input Type

if ~(isnumeric(bits) || islogical(bits))
    error('Input must be numeric or logical.');
end

%% 2. Validate Dimensions

if isempty(bits) || ~isvector(bits)
    error('Input must be a non-empty vector.');
end

%% 3. Validate Finite Binary Input

if ~isreal(bits) || ...
   any(~isfinite(double(bits(:))))

    error('Input must contain finite real values.');

end

bits = double(bits(:).');

if any(bits ~= 0 & bits ~= 1)
    error('Input must contain binary values only.');
end

%% 4. Add Tail Bits

tailBits = [0 0];

inputBits = [bits tailBits];

%% 5. Initialize Encoder State

stateMSB = 0;
stateLSB = 0;

numSteps = numel(inputBits);

codedBits = zeros(1,2*numSteps);

%% 6. Encoding Process

for k = 1:numSteps

    u = inputBits(k);

    % Generator 7: 111

    v0 = mod(u + stateMSB + stateLSB,2);

    % Generator 5: 101

    v1 = mod(u + stateLSB,2);

    % Store output bits

    codedBits(2*k-1) = v0;

    codedBits(2*k) = v1;

    % Update shift register

    stateLSB = stateMSB;

    stateMSB = u;

end

%% 7. Final State Verification

if stateMSB ~= 0 || stateLSB ~= 0
    error('Encoder termination failed.');
end

end