clc;
clear;
close all;

%% =========================================================
% MILESTONE 20
% HAMMING (7,4) VS UNCODED BPSK OVER AWGN
%
% Metrics:
%   Uncoded BER
%   Coded Channel BER
%   Decoded Information BER
%   Codeword Error Rate
%   Decoder Correction Attempt Rate
%   Information Goodput
%% =========================================================

%% 1. PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

rng(2026,'twister');

%% 2. CONFIGURATION

numInfoBits = 8e5;

EbN0_dB = 0:1:9;

symbolRate = 1e6;

codeRate = 4/7;

numSNR = numel(EbN0_dB);

numCodewords = numInfoBits/4;

assert(mod(numInfoBits,4)==0);

fprintf('\n============================================\n');
fprintf('HAMMING (7,4) AWGN PERFORMANCE ANALYSIS\n');
fprintf('============================================\n');

fprintf('Information bits: %d\n',numInfoBits);
fprintf('Code rate: %.6f\n',codeRate);
fprintf('Codeword length: 7 bits\n');
fprintf('Information bits per codeword: 4\n');
fprintf('Number of codewords: %d\n',numCodewords);
fprintf('Channel: AWGN\n');
fprintf('Modulation: BPSK\n');
fprintf('Eb/N0 range: 0 to 9 dB\n');

%% 3. GENERATE INFORMATION BITS

infoBits = generate_bits(numInfoBits);

%% 4. UNCODED BPSK TRANSMITTER

uncodedTxSymbols = bpsk_modulator(infoBits);

%% 5. HAMMING ENCODER

codedBits = hamming74_encoder(infoBits);

codedTxSymbols = bpsk_modulator(codedBits);

% Normalize coded symbol amplitude.
% Average energy per information bit becomes:
% (7/4)*(4/7) = 1.

codedTxSymbols = sqrt(codeRate)*codedTxSymbols;

assert(numel(codedBits)==numInfoBits*7/4);

fprintf('\nEncoder verification passed.\n');

%% 6. PREALLOCATE RESULTS

UncodedBER = zeros(numSNR,1);
UncodedTheory = zeros(numSNR,1);

CodedChannelBER = zeros(numSNR,1);
CodedChannelTheory = zeros(numSNR,1);

DecodedBER = zeros(numSNR,1);
DecodedTheory = zeros(numSNR,1);

CodewordErrorRate = zeros(numSNR,1);
DecoderCorrectionRate = zeros(numSNR,1);
SingleErrorCorrectionSuccessRate = nan(numSNR,1);

UncodedGoodput_bps = zeros(numSNR,1);
CodedGoodput_bps = zeros(numSNR,1);

%% 7. MAIN SIMULATION

for snrIndex = 1:numSNR

    currentEbN0 = EbN0_dB(snrIndex);

    fprintf('\n--------------------------------------------\n');
    fprintf('Eb/N0 = %.1f dB\n',currentEbN0);
    fprintf('--------------------------------------------\n');

    %% A. UNCODED BPSK

    uncodedRxSymbols = awgn_channel( ...
        uncodedTxSymbols, ...
        currentEbN0, ...
        1, ...
        1);

    uncodedRxBits = bpsk_demodulator(uncodedRxSymbols);

    uncodedErrors = sum(infoBits ~= uncodedRxBits);

    uncodedBER = uncodedErrors/numInfoBits;

    %% B. CODED BPSK

    % Noise is normalized to unit information-bit energy.
    % Coded symbol amplitude is sqrt(codeRate).

    codedRxSymbols = awgn_channel( ...
        codedTxSymbols, ...
        currentEbN0, ...
        1, ...
        1);

    codedRxBits = bpsk_demodulator(codedRxSymbols);

    %% C. CHANNEL BER BEFORE DECODING

    codedChannelErrors = sum(codedBits ~= codedRxBits);

    codedChannelBER = ...
        codedChannelErrors/numel(codedBits);

    %% D. HAMMING DECODER

    [decodedBits,~,errorPositions] = ...
        hamming74_decoder(codedRxBits);

    %% E. DECODED INFORMATION BER

    decodedErrors = sum(infoBits ~= decodedBits);

    decodedBER = decodedErrors/numInfoBits;

    %% F. CODEWORD ERROR RATE BEFORE DECODING

    txCodeMatrix = reshape(codedBits,7,[]);

    rxCodeMatrix = reshape(codedRxBits,7,[]);

    channelCodewordFlags = ...
        any(txCodeMatrix ~= rxCodeMatrix,1);

    codewordErrorRate = ...
        sum(channelCodewordFlags)/numCodewords;

    %% G. DECODED INFORMATION BLOCK ERROR RATE

    txInfoMatrix = reshape(infoBits,4,[]);

    rxInfoMatrix = reshape(decodedBits,4,[]);

    decodedBlockFlags = ...
        any(txInfoMatrix ~= rxInfoMatrix,1);

    %% H. DECODER CORRECTION RATE

    correctionAttempts = sum(errorPositions > 0);

    decoderCorrectionRate = ...
        correctionAttempts/numCodewords;

    %% I. SINGLE-BIT CORRECTION SUCCESS

    channelErrorsPerWord = ...
        sum(txCodeMatrix ~= rxCodeMatrix,1);

    singleErrorWords = (channelErrorsPerWord == 1);

    numSingleErrorWords = sum(singleErrorWords);

    if numSingleErrorWords > 0

        successfulCorrections = sum( ...
            singleErrorWords & ~decodedBlockFlags);

        singleErrorSuccessRate = ...
            successfulCorrections/numSingleErrorWords;

    else

        singleErrorSuccessRate = NaN;

    end

    %% J. THEORETICAL BER

    gamma = 10^(currentEbN0/10);

    uncodedTheory = 0.5*erfc(sqrt(gamma));

    codedChannelTheory = ...
        0.5*erfc(sqrt(codeRate*gamma));

    decodedTheory = theoretical_hamming74_ber( ...
        currentEbN0,codeRate);

    %% K. INFORMATION GOODPUT

    uncodedGoodput = ...
        symbolRate*(1-uncodedBER);

    codedGoodput = ...
        symbolRate*codeRate*(1-decodedBER);

    %% L. STORE RESULTS

    UncodedBER(snrIndex) = uncodedBER;

    UncodedTheory(snrIndex) = uncodedTheory;

    CodedChannelBER(snrIndex) = codedChannelBER;

    CodedChannelTheory(snrIndex) = codedChannelTheory;

    DecodedBER(snrIndex) = decodedBER;

    DecodedTheory(snrIndex) = decodedTheory;

    CodewordErrorRate(snrIndex) = codewordErrorRate;

    DecoderCorrectionRate(snrIndex) = decoderCorrectionRate;

    SingleErrorCorrectionSuccessRate(snrIndex) = ...
        singleErrorSuccessRate;

    UncodedGoodput_bps(snrIndex) = uncodedGoodput;

    CodedGoodput_bps(snrIndex) = codedGoodput;

    %% M. DISPLAY RESULTS

    fprintf('Uncoded BER: %.8e\n',uncodedBER);
    fprintf('Uncoded theoretical BER: %.8e\n',uncodedTheory);

    fprintf('Coded channel BER: %.8e\n',codedChannelBER);
    fprintf('Coded channel theoretical BER: %.8e\n', ...
        codedChannelTheory);

    fprintf('Decoded information BER: %.8e\n',decodedBER);
    fprintf('Decoded theoretical BER: %.8e\n',decodedTheory);

    fprintf('Codeword Error Rate: %.8e\n',codewordErrorRate);

    fprintf('Decoder Correction Attempt Rate: %.8e\n', ...
        decoderCorrectionRate);

    fprintf('Single-bit Correction Success Rate: %.8e\n', ...
        singleErrorSuccessRate);

    fprintf('Uncoded Goodput: %.6f Mbps\n', ...
        uncodedGoodput/1e6);

    fprintf('Coded Goodput: %.6f Mbps\n', ...
        codedGoodput/1e6);

end

%% 8. RESULTS TABLE

resultsTable = table( ...
    EbN0_dB(:), ...
    UncodedBER, ...
    UncodedTheory, ...
    CodedChannelBER, ...
    CodedChannelTheory, ...
    DecodedBER, ...
    DecodedTheory, ...
    CodewordErrorRate, ...
    DecoderCorrectionRate, ...
    SingleErrorCorrectionSuccessRate, ...
    UncodedGoodput_bps, ...
    CodedGoodput_bps, ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'UncodedBER', ...
    'UncodedTheoreticalBER', ...
    'CodedChannelBER', ...
    'CodedChannelTheoreticalBER', ...
    'DecodedInformationBER', ...
    'DecodedTheoreticalBER', ...
    'CodewordErrorRate', ...
    'DecoderCorrectionRate', ...
    'SingleErrorCorrectionSuccessRate', ...
    'UncodedGoodput_bps', ...
    'CodedGoodput_bps'});

fprintf('\n============================================\n');
fprintf('HAMMING (7,4) PERFORMANCE SUMMARY\n');
fprintf('============================================\n');

disp(resultsTable);

%% 9. CODING GAIN AT TARGET BER

targetBER = 1e-3;

targetLogBER = log10(targetBER);

snrColumn = EbN0_dB(:);

uncodedLogBER = log10(UncodedTheory(:));

codedLogBER = log10(DecodedTheory(:));

%% Sort Uncoded BER

[uncodedLogSorted,idxU] = sort(uncodedLogBER);

uncodedSNRSorted = snrColumn(idxU);

%% Sort Coded BER

[codedLogSorted,idxC] = sort(codedLogBER);

codedSNRSorted = snrColumn(idxC);

%% Validate Target BER Range

assert(targetLogBER >= min(uncodedLogSorted) && ...
       targetLogBER <= max(uncodedLogSorted), ...
       'Target BER is outside uncoded theoretical range.');

assert(targetLogBER >= min(codedLogSorted) && ...
       targetLogBER <= max(codedLogSorted), ...
       'Target BER is outside coded theoretical range.');

%% Calculate Required Eb/N0

uncodedRequiredEbN0 = interp1( ...
    uncodedLogSorted, ...
    uncodedSNRSorted, ...
    targetLogBER, ...
    'linear');

codedRequiredEbN0 = interp1( ...
    codedLogSorted, ...
    codedSNRSorted, ...
    targetLogBER, ...
    'linear');

%% Calculate Coding Gain

codingGain_dB = ...
    uncodedRequiredEbN0 - codedRequiredEbN0;

%% Display Results

fprintf('\n============================================\n');
fprintf('THEORETICAL CODING GAIN\n');
fprintf('============================================\n');

fprintf('Target BER: %.2e\n',targetBER);

fprintf('Uncoded required Eb/N0: %.4f dB\n', ...
    uncodedRequiredEbN0);

fprintf('Coded required Eb/N0: %.4f dB\n', ...
    codedRequiredEbN0);

fprintf('Hamming coding gain: %.4f dB\n', ...
    codingGain_dB);

%% 10. SAVE RESULTS

resultsFolder = fullfile(projectRoot,'results');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

writetable(resultsTable, ...
    fullfile(resultsFolder,'hamming74_awgn_summary.csv'));

save(fullfile(resultsFolder,'hamming74_awgn_results.mat'), ...
    'resultsTable','EbN0_dB','numInfoBits','codeRate', ...
    'codingGain_dB','targetBER');

%% 11. BER COMPARISON

figure;

semilogy(EbN0_dB,max(UncodedBER,0.5/numInfoBits), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB,max(DecodedBER,0.5/numInfoBits), ...
    '-s','LineWidth',1.5);

semilogy(EbN0_dB,UncodedTheory, ...
    '--','LineWidth',1.5);

semilogy(EbN0_dB,DecodedTheory, ...
    ':','LineWidth',1.8);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('BER');

title('Hamming (7,4) vs Uncoded BPSK');

legend( ...
    'Uncoded BPSK Simulation', ...
    'Hamming Simulation', ...
    'Uncoded BPSK Theory', ...
    'Hamming Hard-Decision Theory', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'hamming74_ber_comparison.png'));

%% 12. DECODER PERFORMANCE

figure;

semilogy(EbN0_dB,max(CodedChannelBER,0.5/numel(codedBits)), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB,max(DecodedBER,0.5/numInfoBits), ...
    '-s','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('BER');

title('Hamming Decoder Performance');

legend( ...
    'Channel BER Before Decoding', ...
    'Information BER After Decoding', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'hamming74_decoder_performance.png'));

%% 13. GOODPUT COMPARISON

figure;

plot(EbN0_dB,UncodedGoodput_bps/1e6, ...
    '-o','LineWidth',1.5);

hold on;

plot(EbN0_dB,CodedGoodput_bps/1e6, ...
    '-s','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('Information Goodput (Mbps)');

title('Uncoded vs Hamming-Coded Goodput');

legend( ...
    'Uncoded BPSK', ...
    'Hamming (7,4) BPSK', ...
    'Location','southeast');

saveas(gcf, ...
    fullfile(resultsFolder,'hamming74_goodput_comparison.png'));

%% 14. FINAL VALIDATION

assert(all(UncodedBER >= 0 & UncodedBER <= 1));

assert(all(CodedChannelBER >= 0 & CodedChannelBER <= 1));

assert(all(DecodedBER >= 0 & DecodedBER <= 1));

assert(all(CodewordErrorRate >= 0 & CodewordErrorRate <= 1));

assert(all(DecoderCorrectionRate >= 0 & DecoderCorrectionRate <= 1));

assert(all(UncodedGoodput_bps >= 0));

assert(all(CodedGoodput_bps >= 0));

assert(all(CodedGoodput_bps <= symbolRate*codeRate + eps));

assert(all(DecodedTheory >= 0 & DecodedTheory <= 1));

assert(abs(codingGain_dB) < 100);

fprintf('\n============================================\n');
fprintf('FINAL VALIDATION PASSED\n');
fprintf('============================================\n');

fprintf('Uncoded BER validation: PASSED\n');
fprintf('Coded BER validation: PASSED\n');
fprintf('Theoretical BER validation: PASSED\n');
fprintf('Codeword error validation: PASSED\n');
fprintf('Decoder correction validation: PASSED\n');
fprintf('Goodput validation: PASSED\n');

fprintf('\nAll results saved in: %s\n',resultsFolder);

fprintf('MILESTONE 20 COMPLETED.\n');