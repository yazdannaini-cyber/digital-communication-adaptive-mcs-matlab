clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

rng(42);

%% Simulation Settings

N = 200000;

EbN0_dB_list = [0 2 4 6 8 10 12];

% Generate BPSK signal

bits = generate_bits(N);

txSymbols = bpsk_modulator(bits);

%% Test 1: AWGN Channel

fprintf('Starting AWGN tests...\n\n');

for i = 1:length(EbN0_dB_list)

    EbN0_dB = EbN0_dB_list(i);

    [rxSymbols, noise, noiseVariance] = ...
        awgn_channel(txSymbols, EbN0_dB);

    % Check signal length

    assert(numel(rxSymbols) == N);

    % Check noise length

    assert(numel(noise) == N);

    % Check channel equation

    assert(max(abs(rxSymbols - txSymbols - noise)) < 1e-12);

    % Theoretical noise statistics

    theoreticalMean = 0;

    theoreticalVariance = noiseVariance;

    % Measured noise statistics

    measuredMean = mean(noise);

    measuredVariance = var(noise, 1);

    % Mean tolerance: five standard errors

    meanTolerance = 5 * sqrt(noiseVariance / N);

    % Variance tolerance: 2 percent

    varianceRelativeError = ...
        abs(measuredVariance - theoreticalVariance) / ...
        theoreticalVariance;

    % Assertions

    assert(abs(measuredMean - theoreticalMean) < meanTolerance, ...
        'Noise mean test failed.');

    assert(varianceRelativeError < 0.02, ...
        'Noise variance test failed.');

    fprintf(['Eb/N0 = %2d dB | ', ...
             'Theory Var = %.5f | ', ...
             'Measured Var = %.5f | ', ...
             'Mean = %.5f\n'], ...
             EbN0_dB, ...
             theoreticalVariance, ...
             measuredVariance, ...
             measuredMean);

    % Keep 6 dB noise for visualization

    if EbN0_dB == 6

        noiseForPlot = noise;

        varianceForPlot = noiseVariance;

    end

end

fprintf('\nAll AWGN statistical tests passed.\n');

%% Test 2: Invalid SNR Input

invalidDetected = false;

try

    awgn_channel(txSymbols, [0 5]);

catch

    invalidDetected = true;

end

assert(invalidDetected, ...
    'Invalid SNR input was not detected.');

fprintf('Invalid SNR test passed.\n');

%% Test 3: Invalid BPSK Symbols

invalidDetected = false;

try

    awgn_channel([1 NaN -1], 6);

catch

    invalidDetected = true;

end

assert(invalidDetected, ...
    'Invalid BPSK symbols were not detected.');

fprintf('Invalid symbol test passed.\n');

%% Noise Distribution Visualization

sigma = sqrt(varianceForPlot);

x = linspace(-5*sigma, 5*sigma, 500);

theoreticalPDF = ...
    (1 / (sqrt(2*pi)*sigma)) .* ...
    exp(-(x.^2)/(2*varianceForPlot));

figure;

histogram(noiseForPlot, 100, ...
    'Normalization', 'pdf');

hold on;

plot(x, theoreticalPDF, 'LineWidth', 2);

grid on;

xlabel('Noise Amplitude');

ylabel('Probability Density');

title('AWGN Distribution - Eb/N0 = 6 dB');

legend('Simulated Noise', 'Theoretical Gaussian PDF');

%% Save Figure

figuresFolder = fullfile(projectRoot, ...
                         'results', ...
                         'figures');

if ~exist(figuresFolder, 'dir')

    mkdir(figuresFolder);

end

saveas(gcf, fullfile(figuresFolder, ...
       'awgn_noise_distribution.png'));

fprintf('\nAWGN figure saved successfully.\n');

fprintf('\nAll AWGN tests completed successfully.\n');