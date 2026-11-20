clc;
clear;
close all;

%% =========================================================
% MILESTONE 23
% UNCODED vs HAMMING vs CONVOLUTIONAL CODE
%
% Channel: AWGN
% Modulation: BPSK
%
% Systems:
% 1. Uncoded BPSK
% 2. Hamming (7,4) + BPSK
% 3. Convolutional (7,5) + Viterbi + BPSK
%
% Metrics:
% - Uncoded BER
% - Coded Channel BER
% - Decoded Information BER
% - Hamming Codeword Error Rate
% - Decoder Correction Attempt Rate
% - Viterbi Final Path Metric
% - Estimated Information Goodput
% - Empirical and theoretical Coding Gain
%
%% =========================================================

%% 1. PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

rng(2026,'twister');

%% 2. SIMULATION CONFIGURATION

numInfoBits = 200000;

EbN0_dB = 0:1:8;

symbolRate = 1e6;

hammingRate = 4/7;

nominalConvRate = 1/2;

numSNR = numel(EbN0_dB);

numHammingWords = numInfoBits/4;

assert(mod(numInfoBits,4)==0);

%% 3. EFFECTIVE CODE RATES

% Hamming has no termination overhead.

hammingEffectiveRate = hammingRate;

% Convolutional encoder adds two zero tail bits.
% Two output bits are generated per input bit.

convEncodedLength = 2*(numInfoBits+2);

convEffectiveRate = numInfoBits/convEncodedLength;

fprintf('\n============================================\n');
fprintf('FEC PERFORMANCE COMPARISON\n');
fprintf('============================================\n');

fprintf('Information bits: %d\n',numInfoBits);

fprintf('Channel: AWGN\n');
fprintf('Modulation: BPSK\n');

fprintf('Eb/N0 range: %d to %d dB\n', ...
    EbN0_dB(1),EbN0_dB(end));

fprintf('\nCODE RATES:\n');

fprintf('Uncoded: 1.000000\n');

fprintf('Hamming (7,4): %.8f\n', ...
    hammingEffectiveRate);

fprintf('Convolutional nominal: %.8f\n', ...
    nominalConvRate);

fprintf('Convolutional effective: %.8f\n', ...
    convEffectiveRate);

%% 4. GENERATE INFORMATION DATA

infoBits = generate_bits(numInfoBits);

%% 5. UNCODED BPSK

uncodedTxBits = infoBits;

uncodedTxSymbols = bpsk_modulator(uncodedTxBits);

%% 6. HAMMING ENCODER

hammingTxBits = hamming74_encoder(infoBits);

hammingTxSymbols = ...
    sqrt(hammingEffectiveRate)* ...
    bpsk_modulator(hammingTxBits);

assert(numel(hammingTxBits)==numInfoBits*7/4);

%% 7. CONVOLUTIONAL ENCODER

convTxBits = convolutional_encoder(infoBits);

convTxSymbols = ...
    sqrt(convEffectiveRate)* ...
    bpsk_modulator(convTxBits);

assert(numel(convTxBits)==convEncodedLength);

fprintf('\nAll transmitters initialized successfully.\n');

%% 8. PREALLOCATE RESULTS

UncodedBER = zeros(numSNR,1);
UncodedTheory = zeros(numSNR,1);

HammingChannelBER = zeros(numSNR,1);
HammingDecodedBER = zeros(numSNR,1);
HammingTheory = zeros(numSNR,1);

HammingCodewordErrorRate = zeros(numSNR,1);

HammingCorrectionAttemptRate = zeros(numSNR,1);

HammingSingleErrorSuccessRate = nan(numSNR,1);

ConvChannelBER = zeros(numSNR,1);
ConvDecodedBER = zeros(numSNR,1);

ConvFinalPathMetric = zeros(numSNR,1);

UncodedGoodput = zeros(numSNR,1);
HammingGoodput = zeros(numSNR,1);
ConvGoodput = zeros(numSNR,1);

%% 9. MAIN SIMULATION

for snrIndex = 1:numSNR

    currentEbN0 = EbN0_dB(snrIndex);

    fprintf('\n--------------------------------------------\n');
    fprintf('Eb/N0 = %.1f dB\n',currentEbN0);
    fprintf('--------------------------------------------\n');

    %% =========================================
    % A. UNCODED BPSK
    %% =========================================

    uncodedRxSymbols = awgn_channel( ...
        uncodedTxSymbols, ...
        currentEbN0, ...
        1, ...
        1);

    uncodedRxBits = bpsk_demodulator(uncodedRxSymbols);

    uncodedErrors = nnz(uncodedTxBits ~= uncodedRxBits);

    uncodedBER = uncodedErrors/numInfoBits;

    %% =========================================
    % B. HAMMING (7,4)
    %% =========================================

    hammingRxSymbols = awgn_channel( ...
        hammingTxSymbols, ...
        currentEbN0, ...
        1, ...
        1);

    hammingRxBits = bpsk_demodulator(hammingRxSymbols);

    %% Channel BER before decoding

    hammingChannelErrors = ...
        nnz(hammingTxBits ~= hammingRxBits);

    hammingChannelBER = ...
        hammingChannelErrors/numel(hammingTxBits);

    %% Hamming decoding

    [hammingDecodedBits,~,hammingErrorPositions] = ...
        hamming74_decoder(hammingRxBits);

    hammingDecodedBits = hammingDecodedBits(:).';

    hammingDecodedErrors = ...
        nnz(infoBits ~= hammingDecodedBits);

    hammingDecodedBER = ...
        hammingDecodedErrors/numInfoBits;

    %% Codeword error rate before decoding

    hammingTxMatrix = reshape(hammingTxBits,7,[]);

    hammingRxMatrix = reshape(hammingRxBits,7,[]);

    hammingChannelErrorsPerWord = ...
        sum(hammingTxMatrix ~= hammingRxMatrix,1);

    hammingCodewordErrors = ...
        sum(hammingChannelErrorsPerWord > 0);

    hammingCodewordErrorRate = ...
        hammingCodewordErrors/numHammingWords;

    %% Decoder correction attempts

    hammingCorrectionAttempts = ...
        sum(hammingErrorPositions(:)>0);

    hammingCorrectionAttemptRate = ...
        hammingCorrectionAttempts/numHammingWords;

    %% Single-bit correction success

    hammingSingleErrorMask = ...
        hammingChannelErrorsPerWord == 1;

    infoTxMatrix = reshape(infoBits,4,[]);

    infoHammingDecodedMatrix = ...
        reshape(hammingDecodedBits,4,[]);

    hammingDecodedWordErrors = any( ...
        infoTxMatrix ~= infoHammingDecodedMatrix,1);

    numberSingleErrorWords = sum(hammingSingleErrorMask);

    if numberSingleErrorWords > 0

        successfulSingleCorrections = sum( ...
            hammingSingleErrorMask & ...
            ~hammingDecodedWordErrors);

        hammingSingleErrorSuccessRate = ...
            successfulSingleCorrections/numberSingleErrorWords;

    else

        hammingSingleErrorSuccessRate = NaN;

    end

    %% =========================================
    % C. CONVOLUTIONAL CODE + VITERBI
    %% =========================================

    convRxSymbols = awgn_channel( ...
        convTxSymbols, ...
        currentEbN0, ...
        1, ...
        1);

    convRxBits = bpsk_demodulator(convRxSymbols);

    %% Channel BER before decoding

    convChannelErrors = nnz(convTxBits ~= convRxBits);

    convChannelBER = convChannelErrors/numel(convTxBits);

    %% Hard-decision Viterbi decoding

    [convDecodedBits,convPathMetric] = ...
        viterbi_decoder_hard(convRxBits);

    convDecodedBits = convDecodedBits(:).';

    %% Decoded information BER

    convDecodedErrors = nnz(infoBits ~= convDecodedBits);

    convDecodedBER = convDecodedErrors/numInfoBits;

    %% =========================================
    % D. THEORETICAL BER
    %% =========================================

    gamma = 10^(currentEbN0/10);

    uncodedTheory = ...
        0.5*erfc(sqrt(gamma));

    hammingTheory = ...
        theoretical_hamming74_ber(currentEbN0,hammingRate);

    %% =========================================
    % E. INFORMATION GOODPUT
    %% =========================================

    uncodedGoodput = ...
        symbolRate*(1-uncodedBER);

    hammingGoodput = ...
        symbolRate*hammingEffectiveRate* ...
        (1-hammingDecodedBER);

    convGoodput = ...
        symbolRate*convEffectiveRate* ...
        (1-convDecodedBER);

    %% =========================================
    % F. STORE RESULTS
    %% =========================================

    UncodedBER(snrIndex) = uncodedBER;

    UncodedTheory(snrIndex) = uncodedTheory;

    HammingChannelBER(snrIndex) = hammingChannelBER;

    HammingDecodedBER(snrIndex) = hammingDecodedBER;

    HammingTheory(snrIndex) = hammingTheory;

    HammingCodewordErrorRate(snrIndex) = ...
        hammingCodewordErrorRate;

    HammingCorrectionAttemptRate(snrIndex) = ...
        hammingCorrectionAttemptRate;

    HammingSingleErrorSuccessRate(snrIndex) = ...
        hammingSingleErrorSuccessRate;

    ConvChannelBER(snrIndex) = convChannelBER;

    ConvDecodedBER(snrIndex) = convDecodedBER;

    ConvFinalPathMetric(snrIndex) = convPathMetric;

    UncodedGoodput(snrIndex) = uncodedGoodput;

    HammingGoodput(snrIndex) = hammingGoodput;

    ConvGoodput(snrIndex) = convGoodput;

    %% =========================================
    % G. DISPLAY RESULTS
    %% =========================================

    fprintf('\nUNCODED BPSK:\n');

    fprintf('BER: %.8e\n',uncodedBER);

    fprintf('Theoretical BER: %.8e\n',uncodedTheory);

    fprintf('Goodput: %.6f Mbps\n',uncodedGoodput/1e6);

    fprintf('\nHAMMING (7,4):\n');

    fprintf('Channel BER: %.8e\n',hammingChannelBER);

    fprintf('Decoded BER: %.8e\n',hammingDecodedBER);

    fprintf('Theoretical Decoded BER: %.8e\n',hammingTheory);

    fprintf('Codeword Error Rate: %.8e\n',hammingCodewordErrorRate);

    fprintf('Correction Attempt Rate: %.8e\n', ...
        hammingCorrectionAttemptRate);

    fprintf('Single-bit Correction Success: %.8e\n', ...
        hammingSingleErrorSuccessRate);

    fprintf('Goodput: %.6f Mbps\n',hammingGoodput/1e6);

    fprintf('\nCONVOLUTIONAL (7,5) + VITERBI:\n');

    fprintf('Channel BER: %.8e\n',convChannelBER);

    fprintf('Decoded BER: %.8e\n',convDecodedBER);

    fprintf('Final Viterbi Path Metric: %.0f\n',convPathMetric);

    fprintf('Goodput: %.6f Mbps\n',convGoodput/1e6);

end

%% 10. RESULTS TABLE

resultsTable = table( ...
    EbN0_dB(:), ...
    UncodedBER, ...
    UncodedTheory, ...
    HammingChannelBER, ...
    HammingDecodedBER, ...
    HammingTheory, ...
    HammingCodewordErrorRate, ...
    HammingCorrectionAttemptRate, ...
    HammingSingleErrorSuccessRate, ...
    ConvChannelBER, ...
    ConvDecodedBER, ...
    ConvFinalPathMetric, ...
    UncodedGoodput, ...
    HammingGoodput, ...
    ConvGoodput, ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'UncodedBER', ...
    'UncodedTheoreticalBER', ...
    'HammingChannelBER', ...
    'HammingDecodedBER', ...
    'HammingTheoreticalBER', ...
    'HammingCodewordErrorRate', ...
    'HammingCorrectionAttemptRate', ...
    'HammingSingleErrorSuccessRate', ...
    'ConvolutionalChannelBER', ...
    'ConvolutionalDecodedBER', ...
    'ViterbiPathMetric', ...
    'UncodedGoodput_bps', ...
    'HammingGoodput_bps', ...
    'ConvolutionalGoodput_bps'});

fprintf('\n============================================\n');
fprintf('FINAL FEC COMPARISON SUMMARY\n');
fprintf('============================================\n');

disp(resultsTable);

%% 11. EMPIRICAL CODING GAIN

targetBER = 1e-3;

uncodedRequiredSNR = estimate_required_snr( ...
    EbN0_dB,UncodedBER,targetBER);

hammingRequiredSNR = estimate_required_snr( ...
    EbN0_dB,HammingDecodedBER,targetBER);

convRequiredSNR = estimate_required_snr( ...
    EbN0_dB,ConvDecodedBER,targetBER);

fprintf('\n============================================\n');
fprintf('EMPIRICAL CODING GAIN AT BER = %.1e\n',targetBER);
fprintf('============================================\n');

fprintf('Uncoded required Eb/N0: %.4f dB\n', ...
    uncodedRequiredSNR);

fprintf('Hamming required Eb/N0: %.4f dB\n', ...
    hammingRequiredSNR);

fprintf('Convolutional required Eb/N0: %.4f dB\n', ...
    convRequiredSNR);

fprintf('Hamming empirical gain: %.4f dB\n', ...
    uncodedRequiredSNR-hammingRequiredSNR);

fprintf('Convolutional empirical gain: %.4f dB\n', ...
    uncodedRequiredSNR-convRequiredSNR);

%% 12. THEORETICAL HAMMING CODING GAIN

uncodedTheoryRequiredSNR = estimate_required_snr( ...
    EbN0_dB,UncodedTheory,targetBER);

hammingTheoryRequiredSNR = estimate_required_snr( ...
    EbN0_dB,HammingTheory,targetBER);

fprintf('\n============================================\n');
fprintf('THEORETICAL HAMMING CODING GAIN\n');
fprintf('============================================\n');

fprintf('Uncoded required Eb/N0: %.4f dB\n', ...
    uncodedTheoryRequiredSNR);

fprintf('Hamming required Eb/N0: %.4f dB\n', ...
    hammingTheoryRequiredSNR);

fprintf('Theoretical Hamming gain: %.4f dB\n', ...
    uncodedTheoryRequiredSNR-hammingTheoryRequiredSNR);

%% 13. SAVE RESULTS

resultsFolder = fullfile(projectRoot,'results');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

writetable(resultsTable, ...
    fullfile(resultsFolder,'fec_comparison_awgn.csv'));

save(fullfile(resultsFolder,'fec_comparison_awgn.mat'), ...
    'resultsTable', ...
    'EbN0_dB', ...
    'numInfoBits', ...
    'hammingEffectiveRate', ...
    'convEffectiveRate', ...
    'targetBER');

%% 14. BER COMPARISON

berFloor = 0.5/numInfoBits;

figure;

semilogy(EbN0_dB,max(UncodedBER,berFloor), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB,max(HammingDecodedBER,berFloor), ...
    '-s','LineWidth',1.5);

semilogy(EbN0_dB,max(ConvDecodedBER,berFloor), ...
    '-^','LineWidth',1.5);

semilogy(EbN0_dB,UncodedTheory, ...
    '--','LineWidth',1.3);

semilogy(EbN0_dB,HammingTheory, ...
    ':','LineWidth',1.8);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('Information BER');

title('Uncoded vs Hamming vs Convolutional Coding');

legend( ...
    'Uncoded BPSK Simulation', ...
    'Hamming (7,4) Simulation', ...
    'Convolutional + Viterbi Simulation', ...
    'Uncoded BPSK Theory', ...
    'Hamming Theory', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'fec_ber_comparison.png'));

%% 15. CODED CHANNEL BER VS DECODED BER

figure;

semilogy(EbN0_dB,max(HammingChannelBER,berFloor), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB,max(HammingDecodedBER,berFloor), ...
    '-s','LineWidth',1.5);

semilogy(EbN0_dB,max(ConvChannelBER,berFloor), ...
    '-^','LineWidth',1.5);

semilogy(EbN0_dB,max(ConvDecodedBER,berFloor), ...
    '-d','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('BER');

title('Channel BER Before and After Decoding');

legend( ...
    'Hamming Channel BER', ...
    'Hamming Decoded BER', ...
    'Convolutional Channel BER', ...
    'Convolutional Decoded BER', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'fec_decoder_comparison.png'));

%% 16. GOODPUT COMPARISON

figure;

plot(EbN0_dB,UncodedGoodput/1e6, ...
    '-o','LineWidth',1.5);

hold on;

plot(EbN0_dB,HammingGoodput/1e6, ...
    '-s','LineWidth',1.5);

plot(EbN0_dB,ConvGoodput/1e6, ...
    '-^','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('Estimated Information Goodput (Mbps)');

title('Goodput Comparison');

legend( ...
    'Uncoded BPSK', ...
    'Hamming (7,4)', ...
    'Convolutional (7,5)', ...
    'Location','southeast');

saveas(gcf, ...
    fullfile(resultsFolder,'fec_goodput_comparison.png'));

%% 17. FINAL VALIDATION

% BER ranges

assert(all(UncodedBER>=0 & UncodedBER<=1));

assert(all(HammingChannelBER>=0 & HammingChannelBER<=1));

assert(all(HammingDecodedBER>=0 & HammingDecodedBER<=1));

assert(all(ConvChannelBER>=0 & ConvChannelBER<=1));

assert(all(ConvDecodedBER>=0 & ConvDecodedBER<=1));

% Goodput ranges

assert(all(UncodedGoodput>=0));

assert(all(HammingGoodput>=0));

assert(all(ConvGoodput>=0));

assert(all(UncodedGoodput<=symbolRate+eps));

assert(all(HammingGoodput<=symbolRate*hammingEffectiveRate+eps));

assert(all(ConvGoodput<=symbolRate*convEffectiveRate+eps));

% Hamming correction metrics

assert(all(HammingCodewordErrorRate>=0 & ...
    HammingCodewordErrorRate<=1));

assert(all(HammingCorrectionAttemptRate>=0 & ...
    HammingCorrectionAttemptRate<=1));

validRates = HammingSingleErrorSuccessRate( ...
    ~isnan(HammingSingleErrorSuccessRate));

assert(all(validRates>=0 & validRates<=1));

% Convolutional output length and data recovery length

assert(numel(convDecodedBits)==numInfoBits);

assert(numel(hammingDecodedBits)==numInfoBits);

% Check theoretical values

assert(all(isfinite(UncodedTheory)));

assert(all(isfinite(HammingTheory)));

assert(all(UncodedTheory>=0 & UncodedTheory<=1));

assert(all(HammingTheory>=0 & HammingTheory<=1));

fprintf('\n============================================\n');
fprintf('FINAL VALIDATION PASSED\n');
fprintf('============================================\n');

fprintf('Uncoded BER validation: PASSED\n');
fprintf('Hamming BER validation: PASSED\n');
fprintf('Convolutional BER validation: PASSED\n');
fprintf('Decoder output length validation: PASSED\n');
fprintf('Goodput validation: PASSED\n');
fprintf('Coding rate validation: PASSED\n');

fprintf('\nAll FEC comparison results saved.\n');

fprintf('Results directory: %s\n',resultsFolder);

fprintf('\nMILESTONE 23 COMPLETED.\n');


%% =========================================================
% LOCAL FUNCTION 1
% THEORETICAL HAMMING (7,4) HARD-DECISION BER
%% =========================================================

function ber = theoretical_hamming74_ber(EbN0_dB,codeRate)

    H = [ ...
        1 1 0 1 1 0 0;
        1 0 1 1 0 1 0;
        0 1 1 1 0 0 1];

    gamma = 10^(EbN0_dB/10);

    p = 0.5*erfc(sqrt(codeRate*gamma));

    errorPatterns = dec2bin(0:127,7)-'0';

    ber = 0;

    for k = 1:size(errorPatterns,1)

        errorVector = errorPatterns(k,:).';

        errorWeight = sum(errorVector);

        syndrome = mod(H*errorVector,2);

        correctedError = errorVector;

        if any(syndrome)

            position = find( ...
                all(bsxfun(@eq,H,syndrome),1), ...
                1,'first');

            if isempty(position)
                error('Invalid syndrome.');
            end

            correctedError(position) = ...
                1-correctedError(position);

        end

        informationErrors = sum(correctedError(1:4));

        patternProbability = ...
            p^errorWeight*(1-p)^(7-errorWeight);

        ber = ber + ...
            (informationErrors/4)*patternProbability;

    end

end


%% =========================================================
% LOCAL FUNCTION 2
% ESTIMATE REQUIRED SNR FOR TARGET BER
% Log-domain interpolation between measured points
%% =========================================================

function requiredSNR = estimate_required_snr(snr,ber,targetBER)

    requiredSNR = NaN;

    snr = snr(:);
    ber = ber(:);

    for k = 2:numel(snr)

        if ber(k-1)>=targetBER && ...
           ber(k)<=targetBER && ...
           ber(k-1)>0 && ber(k)>0

            x1 = log10(ber(k-1));
            x2 = log10(ber(k));

            targetLog = log10(targetBER);

            requiredSNR = snr(k-1) + ...
                (targetLog-x1)*(snr(k)-snr(k-1))/(x2-x1);

            return;

        end

    end

end