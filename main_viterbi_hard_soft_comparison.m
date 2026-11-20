clc;
clear;
close all;

%% =========================================================
% MILESTONE 25
% HARD vs SOFT DECISION VITERBI
%
% Code: Convolutional (7,5)
% Constraint Length: 3
% Modulation: BPSK
% Channel: AWGN
%
% Systems:
% 1. Uncoded BPSK
% 2. Convolutional + Hard Viterbi
% 3. Convolutional + Soft Viterbi
%
%% =========================================================

%% 1. PROJECT SETUP

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

rng(2026,'twister');

%% 2. CONFIGURATION

numInfoBits = 200000;

EbN0_dB = 0:1:8;

symbolRate = 1e6;

numSNR = numel(EbN0_dB);

%% 3. ENCODER AND ENERGY CONFIGURATION

infoBits = generate_bits(numInfoBits);

codedBits = convolutional_encoder(infoBits);

convRate = numInfoBits/numel(codedBits);

symbolAmplitude = sqrt(convRate);

fprintf('\n============================================\n');
fprintf('HARD vs SOFT VITERBI PERFORMANCE ANALYSIS\n');
fprintf('============================================\n');

fprintf('Information bits: %d\n',numInfoBits);
fprintf('Coded bits: %d\n',numel(codedBits));
fprintf('Effective code rate: %.8f\n',convRate);
fprintf('Symbol amplitude: %.8f\n',symbolAmplitude);
fprintf('Channel: AWGN\n');
fprintf('Modulation: BPSK\n');

%% 4. TRANSMITTER SIGNALS

uncodedSymbols = bpsk_modulator(infoBits);

codedSymbols = symbolAmplitude* ...
    bpsk_modulator(codedBits);

%% 5. PREALLOCATE RESULTS

UncodedBER = zeros(numSNR,1);
UncodedTheory = zeros(numSNR,1);

CodedChannelBER = zeros(numSNR,1);
CodedChannelTheory = zeros(numSNR,1);

HardDecodedBER = zeros(numSNR,1);
SoftDecodedBER = zeros(numSNR,1);

HardPathMetric = zeros(numSNR,1);
SoftPathMetric = zeros(numSNR,1);

HardGoodput = zeros(numSNR,1);
SoftGoodput = zeros(numSNR,1);
UncodedGoodput = zeros(numSNR,1);

%% 6. MAIN SIMULATION

for snrIndex = 1:numSNR

    currentEbN0 = EbN0_dB(snrIndex);

    fprintf('\n--------------------------------------------\n');
    fprintf('Eb/N0 = %.1f dB\n',currentEbN0);
    fprintf('--------------------------------------------\n');

    %% A. UNCODED BPSK

    uncodedRx = awgn_channel( ...
        uncodedSymbols,currentEbN0,1,1);

    uncodedRxBits = bpsk_demodulator(uncodedRx);

    uncodedBER = ...
        nnz(infoBits ~= uncodedRxBits)/numInfoBits;

    %% B. CODED BPSK CHANNEL

    codedRx = awgn_channel( ...
        codedSymbols,currentEbN0,1,1);

    %% C. CHANNEL BER

    codedRxHardBits = bpsk_demodulator(codedRx);

    channelErrors = ...
        nnz(codedBits ~= codedRxHardBits);

    codedChannelBER = channelErrors/numel(codedBits);

    %% D. HARD-DECISION VITERBI

    [hardDecoded,hardMetric] = ...
        viterbi_decoder_hard(codedRxHardBits);

    hardDecoded = hardDecoded(:).';

    hardErrors = nnz(infoBits ~= hardDecoded);

    hardBER = hardErrors/numInfoBits;

    %% E. SOFT-DECISION VITERBI

    % IMPORTANT:
    % Use the original analog received samples.
    % Do not apply hard decisions before decoding.

    [softDecoded,softMetric] = ...
        viterbi_decoder_soft(codedRx,symbolAmplitude);

    softDecoded = softDecoded(:).';

    softErrors = nnz(infoBits ~= softDecoded);

    softBER = softErrors/numInfoBits;

    %% F. THEORETICAL CHANNEL BER

    gamma = 10^(currentEbN0/10);

    uncodedTheory = ...
        0.5*erfc(sqrt(gamma));

    codedChannelTheory = ...
        0.5*erfc(sqrt(convRate*gamma));

    %% G. INFORMATION GOODPUT

    uncodedGoodput = ...
        symbolRate*(1-uncodedBER);

    hardGoodput = ...
        symbolRate*convRate*(1-hardBER);

    softGoodput = ...
        symbolRate*convRate*(1-softBER);

    %% H. SAVE RESULTS

    UncodedBER(snrIndex) = uncodedBER;
    UncodedTheory(snrIndex) = uncodedTheory;

    CodedChannelBER(snrIndex) = codedChannelBER;
    CodedChannelTheory(snrIndex) = codedChannelTheory;

    HardDecodedBER(snrIndex) = hardBER;
    SoftDecodedBER(snrIndex) = softBER;

    HardPathMetric(snrIndex) = hardMetric;
    SoftPathMetric(snrIndex) = softMetric;

    UncodedGoodput(snrIndex) = uncodedGoodput;
    HardGoodput(snrIndex) = hardGoodput;
    SoftGoodput(snrIndex) = softGoodput;

    %% I. DISPLAY RESULTS

    fprintf('Uncoded BER: %.8e\n',uncodedBER);

    fprintf('Uncoded theoretical BER: %.8e\n', ...
        uncodedTheory);

    fprintf('Coded Channel BER: %.8e\n',codedChannelBER);

    fprintf('Coded Channel theoretical BER: %.8e\n', ...
        codedChannelTheory);

    fprintf('\nHARD-DECISION VITERBI:\n');

    fprintf('Decoded BER: %.8e\n',hardBER);
    fprintf('Final Path Metric: %.0f\n',hardMetric);
    fprintf('Goodput: %.6f Mbps\n',hardGoodput/1e6);

    fprintf('\nSOFT-DECISION VITERBI:\n');

    fprintf('Decoded BER: %.8e\n',softBER);
    fprintf('Final Path Metric: %.6f\n',softMetric);
    fprintf('Goodput: %.6f Mbps\n',softGoodput/1e6);

end

%% 7. RESULTS TABLE

resultsTable = table( ...
    EbN0_dB(:), ...
    UncodedBER, ...
    UncodedTheory, ...
    CodedChannelBER, ...
    CodedChannelTheory, ...
    HardDecodedBER, ...
    SoftDecodedBER, ...
    HardPathMetric, ...
    SoftPathMetric, ...
    UncodedGoodput, ...
    HardGoodput, ...
    SoftGoodput, ...
    'VariableNames',{ ...
    'EbN0_dB', ...
    'UncodedBER', ...
    'UncodedTheoreticalBER', ...
    'CodedChannelBER', ...
    'CodedChannelTheoreticalBER', ...
    'HardDecodedBER', ...
    'SoftDecodedBER', ...
    'HardPathMetric', ...
    'SoftPathMetric', ...
    'UncodedGoodput_bps', ...
    'HardGoodput_bps', ...
    'SoftGoodput_bps'});

fprintf('\n============================================\n');
fprintf('HARD vs SOFT VITERBI SUMMARY\n');
fprintf('============================================\n');

disp(resultsTable);

%% 8. EMPIRICAL CODING GAIN

targetBER = 1e-3;

uncodedRequiredSNR = estimate_required_snr( ...
    EbN0_dB,UncodedBER,targetBER);

hardRequiredSNR = estimate_required_snr( ...
    EbN0_dB,HardDecodedBER,targetBER);

softRequiredSNR = estimate_required_snr( ...
    EbN0_dB,SoftDecodedBER,targetBER);

fprintf('\n============================================\n');
fprintf('EMPIRICAL CODING GAIN\n');
fprintf('============================================\n');

fprintf('Target BER: %.2e\n',targetBER);

fprintf('Uncoded required Eb/N0: %.4f dB\n', ...
    uncodedRequiredSNR);

fprintf('Hard Viterbi required Eb/N0: %.4f dB\n', ...
    hardRequiredSNR);

fprintf('Soft Viterbi required Eb/N0: %.4f dB\n', ...
    softRequiredSNR);

fprintf('Hard Viterbi gain: %.4f dB\n', ...
    uncodedRequiredSNR-hardRequiredSNR);

fprintf('Soft Viterbi gain: %.4f dB\n', ...
    uncodedRequiredSNR-softRequiredSNR);

fprintf('Soft vs Hard gain: %.4f dB\n', ...
    hardRequiredSNR-softRequiredSNR);

%% 9. SAVE RESULTS

resultsFolder = fullfile(projectRoot,'results');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

writetable(resultsTable, ...
    fullfile(resultsFolder,'viterbi_hard_soft_summary.csv'));

save(fullfile(resultsFolder,'viterbi_hard_soft_results.mat'), ...
    'resultsTable','EbN0_dB','numInfoBits', ...
    'convRate','targetBER');

%% 10. BER COMPARISON

berFloor = 0.5/numInfoBits;

figure;

semilogy(EbN0_dB,max(UncodedBER,berFloor), ...
    '-o','LineWidth',1.5);

hold on;

semilogy(EbN0_dB,max(HardDecodedBER,berFloor), ...
    '-s','LineWidth',1.5);

semilogy(EbN0_dB,max(SoftDecodedBER,berFloor), ...
    '-^','LineWidth',1.5);

semilogy(EbN0_dB,UncodedTheory, ...
    '--','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('Information BER');

title('Hard vs Soft Decision Viterbi');

legend( ...
    'Uncoded BPSK', ...
    'Hard-Decision Viterbi', ...
    'Soft-Decision Viterbi', ...
    'Uncoded BPSK Theory', ...
    'Location','southwest');

saveas(gcf, ...
    fullfile(resultsFolder,'viterbi_hard_soft_ber.png'));

%% 11. GOODPUT COMPARISON

figure;

plot(EbN0_dB,UncodedGoodput/1e6, ...
    '-o','LineWidth',1.5);

hold on;

plot(EbN0_dB,HardGoodput/1e6, ...
    '-s','LineWidth',1.5);

plot(EbN0_dB,SoftGoodput/1e6, ...
    '-^','LineWidth',1.5);

grid on;

xlabel('E_b/N_0 (dB)');
ylabel('Information Goodput (Mbps)');

title('Hard vs Soft Viterbi Goodput');

legend( ...
    'Uncoded BPSK', ...
    'Hard Viterbi', ...
    'Soft Viterbi', ...
    'Location','southeast');

saveas(gcf, ...
    fullfile(resultsFolder,'viterbi_hard_soft_goodput.png'));

%% 12. FINAL VALIDATION

assert(all(UncodedBER>=0 & UncodedBER<=1));

assert(all(CodedChannelBER>=0 & CodedChannelBER<=1));

assert(all(HardDecodedBER>=0 & HardDecodedBER<=1));

assert(all(SoftDecodedBER>=0 & SoftDecodedBER<=1));

assert(all(UncodedGoodput>=0));

assert(all(HardGoodput>=0));

assert(all(SoftGoodput>=0));

assert(all(HardGoodput<=symbolRate*convRate+eps));

assert(all(SoftGoodput<=symbolRate*convRate+eps));

assert(all(isfinite(HardPathMetric)));

assert(all(isfinite(SoftPathMetric)));

% Both decoders must return the original information length.

assert(numel(hardDecoded)==numInfoBits);

assert(numel(softDecoded)==numInfoBits);

fprintf('\n============================================\n');
fprintf('FINAL VALIDATION PASSED\n');
fprintf('============================================\n');

fprintf('Uncoded BER validation: PASSED\n');
fprintf('Hard Viterbi validation: PASSED\n');
fprintf('Soft Viterbi validation: PASSED\n');
fprintf('Goodput validation: PASSED\n');
fprintf('Path metric validation: PASSED\n');

fprintf('\nAll results saved successfully.\n');

fprintf('Results directory: %s\n',resultsFolder);

fprintf('\nMILESTONE 25 COMPLETED.\n');


%% =========================================================
% LOCAL FUNCTION
% EMPIRICAL REQUIRED SNR AT TARGET BER
%% =========================================================

function requiredSNR = estimate_required_snr(snr,ber,targetBER)

    requiredSNR = NaN;

    snr = snr(:);
    ber = ber(:);

    for k = 2:numel(snr)

        if ber(k-1)>targetBER && ...
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