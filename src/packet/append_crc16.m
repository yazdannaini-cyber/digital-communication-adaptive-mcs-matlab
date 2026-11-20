
function [packetBits,crcValue] = append_crc16(payloadBits)

    % =========================================
    % APPEND CRC-16 TO INFORMATION PAYLOAD
    % CRC bits are appended MSB first
    % =========================================

    %% Validate Payload

    if ~(isnumeric(payloadBits) || islogical(payloadBits)) || ...
       isempty(payloadBits) || ...
       ~isvector(payloadBits)

        error('Payload must be a non-empty numeric vector.');

    end

    %% Convert to Row Vector

    payloadBits = double(payloadBits(:).');

    %% Calculate CRC

    crcValue = crc16_ccitt(payloadBits);

    %% Convert CRC to 16 Bits

    crcBits = zeros(1,16);

    for k = 1:16

        crcBits(k) = double(bitget(crcValue,17-k));

    end

    %% Append CRC

    packetBits = [payloadBits crcBits];

end
