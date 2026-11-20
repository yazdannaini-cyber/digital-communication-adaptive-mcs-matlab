
function [txSymbols, txInfo] = adaptive_link_transmitter( ...
    payloadBits, modulation, interleaverDepth, numFadingBlocks)
%ADAPTIVE_LINK_TRANSMITTER Integrated digital communications transmitter.
%
% Processing:
%   Payload -> CRC -> Convolutional Encoder
%   -> Padding -> Interleaver -> Modulation
%
% Inputs:
%   payloadBits       : Binary information payload.
%   modulation        : BPSK, QPSK or 16QAM.
%   interleaverDepth  : 4 or 16.
%   numFadingBlocks   : Number of independent channel blocks.
%
% Outputs:
%   txSymbols : Modulated complex symbols.
%   txInfo    : Metadata required by the receiver.
%
% The effective payload rate is used for Eb/N0 normalization.
% Padding bits are transmitted but are not information bits.

    %% Validate payload

    if ~isnumeric(payloadBits) || ...
            ~isvector(payloadBits) || isempty(payloadBits)

        error('payloadBits must be a non-empty numeric vector.');

    end

    payload = double(payloadBits(:));

    if any(~isfinite(payload)) || ...
            any(payload ~= 0 & payload ~= 1)

        error('payloadBits must contain binary values.');

    end

    %% Validate interleaver depth

    if ~isscalar(interleaverDepth) || ...
            ~ismember(interleaverDepth, [4 16])

        error('interleaverDepth must be 4 or 16.');

    end

    %% Validate fading block count

    if ~isscalar(numFadingBlocks) || ...
            ~isfinite(numFadingBlocks) || ...
            numFadingBlocks < 1 || ...
            numFadingBlocks ~= floor(numFadingBlocks)

        error('numFadingBlocks must be a positive integer.');

    end

    %% Determine modulation order

    [constellation, bitLabels] = ...
        get_modulation_constellation(modulation);

    bitsPerSymbol = size(bitLabels, 2);

    %% Add CRC

    packetBits = append_crc16(payload);

    packetBits = double(packetBits(:));

    %% Convolutional encoding

    codedBits = convolutional_encoder(packetBits);

    codedBits = double(codedBits(:));

    %% Padding
    %
    % Ensure:
    % 1. Interleaver depth divides transmission length.
    % 2. Bits per symbol divides transmission length.
    % 3. Number of modulation symbols is divisible by fading blocks.
    %
    % Using 16 as the maximum supported interleaver depth
    % produces a common transmission length for all profiles.

    paddingQuantum = lcm( ...
        16, bitsPerSymbol * numFadingBlocks);

    paddingLength = mod(-numel(codedBits), paddingQuantum);

    paddedBits = [
        codedBits
        zeros(paddingLength, 1)
    ];

    %% Interleaving

    interleavedBits = block_interleaver( ...
        paddedBits, interleaverDepth);

    interleavedBits = double(interleavedBits(:));

    %% Effective payload code rate

    effectivePayloadRate = ...
        numel(payload) / numel(paddedBits);

    %% Energy normalization

    symbolAmplitude = sqrt( ...
        effectivePayloadRate * bitsPerSymbol);

    %% Modulation

    [txSymbols, actualBitsPerSymbol] = ...
        digital_modulator( ...
            interleavedBits, modulation, symbolAmplitude);

    if actualBitsPerSymbol ~= bitsPerSymbol
        error('Modulator bit ordering or size inconsistency.');
    end

    %% Validate frame dimensions

    numSymbols = numel(txSymbols);

    if mod(numSymbols, numFadingBlocks) ~= 0
        error('Number of symbols must be divisible by fading blocks.');
    end

    %% Create receiver metadata

    txInfo = struct();

    txInfo.Modulation = upper(string(modulation));

    txInfo.BitsPerSymbol = bitsPerSymbol;

    txInfo.InterleaverDepth = interleaverDepth;

    txInfo.NumFadingBlocks = numFadingBlocks;

    txInfo.PayloadLength = numel(payload);

    txInfo.PacketLength = numel(packetBits);

    txInfo.CodedLength = numel(codedBits);

    txInfo.PaddingLength = paddingLength;

    txInfo.TransmissionBitLength = numel(paddedBits);

    txInfo.NumSymbols = numSymbols;

    txInfo.SymbolAmplitude = symbolAmplitude;

    txInfo.EffectivePayloadRate = effectivePayloadRate;

    txInfo.NominalConvolutionalRate = 1/2;

    txInfo.PayloadBits = payload;

    txInfo.PacketBits = packetBits;

    txInfo.CodedBits = codedBits;

    txInfo.InterleavedBits = interleavedBits;

end
