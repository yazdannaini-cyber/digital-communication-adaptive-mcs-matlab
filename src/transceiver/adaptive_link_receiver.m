
function [decodedPayload, rxInfo] = adaptive_link_receiver( ...
    rxSymbols, channelCoefficients, noiseVariance, txInfo)
%ADAPTIVE_LINK_RECEIVER Integrated digital communications receiver.
%
% Processing:
%   CSI Equalization -> Soft Demapping
%   -> Deinterleaving -> Soft Viterbi
%   -> CRC Verification
%
% Inputs:
%   rxSymbols          : Complex received modulation symbols.
%   channelCoefficients : True or estimated channel coefficient per symbol.
%   noiseVariance      : Complex AWGN variance before fading.
%   txInfo             : Metadata from adaptive_link_transmitter.
%
% Outputs:
%   decodedPayload : Recovered payload bits.
%   rxInfo         : Receiver diagnostics and decoded packet.
%
% LLR convention:
%   Positive LLR favors bit 0.
%   Negative LLR favors bit 1.

    %% Validate received symbols

    if ~isnumeric(rxSymbols) || ...
            ~isvector(rxSymbols) || isempty(rxSymbols)

        error('rxSymbols must be a non-empty numeric vector.');

    end

    rx = double(rxSymbols(:));

    if any(~isfinite(real(rx))) || ...
            any(~isfinite(imag(rx)))

        error('Received symbols must be finite.');

    end

    %% Validate channel coefficients

    if ~isnumeric(channelCoefficients) || ...
            ~isvector(channelCoefficients) || ...
            isempty(channelCoefficients)

        error('Channel coefficients must be a non-empty numeric vector.');

    end

    h = double(channelCoefficients(:));

    if numel(h) ~= numel(rx)

        error('One channel coefficient is required per received symbol.');

    end

    if any(~isfinite(real(h))) || any(~isfinite(imag(h)))

        error('Channel coefficients must be finite.');

    end

    channelPower = abs(h).^2;

    if any(channelPower <= realmin)

        error('Channel coefficient is too close to zero for equalization.');

    end

    %% Validate noise variance

    if ~isscalar(noiseVariance) || ...
            ~isreal(noiseVariance) || ...
            ~isfinite(noiseVariance) || ...
            noiseVariance <= 0

        error('noiseVariance must be a positive finite scalar.');

    end

    %% Validate transmitter metadata

    requiredFields = {
        'Modulation'
        'BitsPerSymbol'
        'InterleaverDepth'
        'PayloadLength'
        'PacketLength'
        'CodedLength'
        'PaddingLength'
        'TransmissionBitLength'
        'NumSymbols'
        'SymbolAmplitude'
    };

    if ~isstruct(txInfo) || ~isscalar(txInfo)

        error('txInfo must be a scalar structure.');

    end

    for k = 1:numel(requiredFields)

        if ~isfield(txInfo, requiredFields{k})

            error('Missing transmitter metadata: %s', ...
                requiredFields{k});

        end
    end

    if numel(rx) ~= txInfo.NumSymbols

        error('Received symbol count does not match txInfo.');

    end

    %% Perfect CSI or estimated CSI equalization

    rxEqualized = rx ./ h;

    %% Normalize modulation amplitude

    amplitude = txInfo.SymbolAmplitude;

    if ~isscalar(amplitude) || ...
            ~isfinite(amplitude) || amplitude <= 0

        error('Invalid transmitter symbol amplitude.');

    end

    rxNormalized = rxEqualized ./ amplitude;

    %% Noise variance after equalization and amplitude normalization

    normalizedNoiseVariance = ...
        noiseVariance ./ (channelPower .* amplitude^2);

    %% Soft demapping

    llrInterleaved = soft_demapper_llr( ...
        rxNormalized, ...
        txInfo.Modulation, ...
        normalizedNoiseVariance);

    llrInterleaved = llrInterleaved(:);

    if numel(llrInterleaved) ~= txInfo.TransmissionBitLength

        error('Unexpected number of generated LLR values.');

    end

    %% Deinterleaving

    llrOriginal = block_deinterleaver( ...
        llrInterleaved, txInfo.InterleaverDepth);

    llrOriginal = llrOriginal(:);

    %% Remove padding LLRs

    llrCoded = llrOriginal(1:txInfo.CodedLength);

    %% Soft Viterbi decoding

    decodedPacket = viterbi_decoder_soft_llr(llrCoded);

    decodedPacket = double(decodedPacket(:));

    if numel(decodedPacket) ~= txInfo.PacketLength

        error('Unexpected decoded packet length.');

    end

    %% Extract payload

    decodedPayload = ...
        decodedPacket(1:txInfo.PayloadLength);

    %% CRC verification

    expectedPacket = append_crc16(decodedPayload);

    expectedPacket = double(expectedPacket(:));

    crcValid = isequal(decodedPacket, expectedPacket);

    %% Receiver diagnostics

    rxInfo = struct();

    rxInfo.DecodedPacket = decodedPacket;

    rxInfo.CRCCorrect = crcValid;

    rxInfo.Modulation = txInfo.Modulation;

    rxInfo.InterleaverDepth = txInfo.InterleaverDepth;

    rxInfo.NumSymbols = numel(rx);

    rxInfo.NumLLR = numel(llrInterleaved);

    rxInfo.MeanChannelPower = mean(channelPower);

    rxInfo.MeanEqualizedNoiseVariance = ...
        mean(noiseVariance ./ channelPower);

    rxInfo.MeanNormalizedNoiseVariance = ...
        mean(normalizedNoiseVariance);

    rxInfo.LLR = llrCoded;

end
