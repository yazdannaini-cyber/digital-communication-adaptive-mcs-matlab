
function [payloadBits,crcOK,receivedCRC,expectedCRC] = ...
    verify_crc16(packetBits)

    % =========================================
    % CRC-16 PACKET VERIFICATION
    % =========================================

    %% 1. Validate Input

    if ~(isnumeric(packetBits) || islogical(packetBits)) || ...
       isempty(packetBits) || ...
       ~isvector(packetBits)

        error('Packet must be a non-empty numeric vector.');

    end

    %% 2. Convert Input

    packetBits = double(packetBits(:).');

    %% 3. Validate Binary Data

    if ~isreal(packetBits) || ...
       any(~isfinite(packetBits)) || ...
       any(packetBits ~= 0 & packetBits ~= 1)

        error('Packet must contain finite binary values.');

    end

    %% 4. Validate Packet Length

    if numel(packetBits) <= 16

        error('Packet must contain payload and 16 CRC bits.');

    end

    %% 5. Separate Payload and CRC

    payloadBits = packetBits(1:end-16);

    crcBits = packetBits(end-15:end);

    %% 6. Reconstruct Received CRC

    receivedCRC = uint16(0);

    for k = 1:16

        receivedCRC = bitshift(receivedCRC,1);

        if crcBits(k) == 1

            receivedCRC = bitor( ...
                receivedCRC,uint16(1));

        end

    end

    %% 7. Calculate Expected CRC

    expectedCRC = crc16_ccitt(payloadBits);

    %% 8. Verify CRC

    crcOK = (receivedCRC == expectedCRC);

end
