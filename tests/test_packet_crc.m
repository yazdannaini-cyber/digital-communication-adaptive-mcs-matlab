
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

%% Test 1: CRC Reference Vector

testBytes = uint8('123456789');

testBits = zeros(1,8*numel(testBytes));

for k = 1:numel(testBytes)

    positions = (k-1)*8+(1:8);

    testBits(positions) = ...
        double(bitget(testBytes(k),8:-1:1));

end

crc = crc16_ccitt(testBits);

expectedCRC = uint16(hex2dec('29B1'));

assert(crc == expectedCRC);

fprintf('Test 1 passed: CRC reference vector.\n');

%% Test 2: CRC Value Range

assert(crc >= 0 && crc <= 65535);

fprintf('Test 2 passed: CRC output range.\n');

%% Test 3: Append CRC

payload = randi([0 1],1,1024);

[packet,crcValue] = append_crc16(payload);

assert(numel(packet)==1040);

assert(numel(packet)-numel(payload)==16);

fprintf('Test 3 passed: CRC append operation.\n');

%% Test 4: Payload Preservation

assert(isequal(packet(1:1024),payload));

fprintf('Test 4 passed: Payload preservation.\n');

%% Test 5: CRC Verification

[recoveredPayload,crcOK,receivedCRC,expectedCRC] = ...
    verify_crc16(packet);

assert(crcOK);

assert(isequal(recoveredPayload,payload));

assert(receivedCRC==expectedCRC);

assert(receivedCRC==crcValue);

fprintf('Test 5 passed: Valid packet verification.\n');

%% Test 6: Payload Error Detection

corruptedPacket = packet;

corruptedPacket(10) = 1-corruptedPacket(10);

[~,crcOK] = verify_crc16(corruptedPacket);

assert(~crcOK);

fprintf('Test 6 passed: Payload corruption detection.\n');

%% Test 7: CRC Field Error Detection

corruptedPacket = packet;

corruptedPacket(end) = 1-corruptedPacket(end);

[~,crcOK] = verify_crc16(corruptedPacket);

assert(~crcOK);

fprintf('Test 7 passed: CRC field corruption detection.\n');

%% Test 8: Column Vector Support

columnPacket = packet.';

[recoveredPayload,crcOK] = verify_crc16(columnPacket);

assert(crcOK);

assert(isequal(recoveredPayload,payload));

fprintf('Test 8 passed: Column vector support.\n');

%% Test 9: PER Calculation

flags = [0 1 0 0 1 1 0 0];

[per,numErrors] = calculate_per(flags);

assert(numErrors==3);

assert(per==3/8);

fprintf('Test 9 passed: PER calculation.\n');

%% Test 10: Zero Packet Errors

[per,numErrors] = calculate_per([0 0 0 0]);

assert(per==0);

assert(numErrors==0);

fprintf('Test 10 passed: Zero packet errors.\n');

%% Test 11: Invalid CRC Input

invalidDetected = false;

try

    crc16_ccitt([0 1 2 0]);

catch

    invalidDetected=true;

end

assert(invalidDetected);

fprintf('Test 11 passed: Invalid CRC input detection.\n');

%% Test 12: Invalid Packet Length

invalidDetected = false;

try

    verify_crc16([0 1 1 0]);

catch

    invalidDetected=true;

end

assert(invalidDetected);

fprintf('Test 12 passed: Invalid packet length detection.\n');

%% Final Result

fprintf('\nAll packet CRC and PER tests passed successfully.\n');
