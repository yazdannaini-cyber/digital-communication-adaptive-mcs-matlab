
function [per,numPacketErrors] = calculate_per(packetErrorFlags)

    % =========================================
    % PACKET ERROR RATE CALCULATOR
    % =========================================

    %% 1. Validate Input Type

    if ~(isnumeric(packetErrorFlags) || ...
         islogical(packetErrorFlags))

        error('Input must be numeric or logical.');

    end

    %% 2. Validate Input Dimensions

    if isempty(packetErrorFlags) || ...
       ~isvector(packetErrorFlags)

        error('Input must be a non-empty vector.');

    end

    %% 3. Validate Real and Finite Values

    if ~isreal(packetErrorFlags) || ...
       any(~isfinite(double(packetErrorFlags(:))))

        error('Input must contain finite real values.');

    end

    %% 4. Validate Binary Flags

    if any(packetErrorFlags(:) ~= 0 & ...
           packetErrorFlags(:) ~= 1)

        error('Packet error flags must contain 0 or 1.');

    end

    %% 5. Count Packet Errors

    numPacketErrors = sum(packetErrorFlags(:));

    %% 6. Calculate PER

    per = numPacketErrors/numel(packetErrorFlags);

end
