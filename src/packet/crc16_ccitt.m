
function crc = crc16_ccitt(bits)

    % =========================================
    % CRC-16/CCITT-FALSE
    %
    % Polynomial: 0x1021
    % Initial:    0xFFFF
    % RefIn:      false
    % RefOut:     false
    % XorOut:     0x0000
    % =========================================

    %% 1. Validate Input Type

    if ~(isnumeric(bits) || islogical(bits))

        error('Input must be numeric or logical.');

    end

    %% 2. Validate Input Dimensions

    if isempty(bits) || ~isvector(bits)

        error('Input must be a non-empty vector.');

    end

    %% 3. Validate Real and Finite Values

    if ~isreal(bits) || ...
       any(~isfinite(double(bits(:))))

        error('Input must contain finite real values.');

    end

    %% 4. Validate Binary Values

    if any(bits(:) ~= 0 & bits(:) ~= 1)

        error('Input must contain binary values only.');

    end

    %% 5. Convert Input

    bits = double(bits(:).');

    %% 6. Initialize CRC Register

    crc = uint16(hex2dec('FFFF'));

    polynomial = uint16(hex2dec('1021'));

    %% 7. Process Bits MSB First

    for k = 1:numel(bits)

        mostSignificantBit = ...
            bitget(crc,16) ~= 0;

        feedback = xor( ...
            mostSignificantBit, ...
            bits(k) == 1);

        % Shift CRC register left

        crc = bitshift(crc,1);

        % Apply generator polynomial

        if feedback

            crc = bitxor(crc,polynomial);

        end

    end

end
