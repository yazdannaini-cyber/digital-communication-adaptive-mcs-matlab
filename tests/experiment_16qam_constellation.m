
clc;
clear;
close all;

%% Project Setup

testFolder = fileparts(mfilename('fullpath'));

projectRoot = fileparts(testFolder);

addpath(genpath(projectRoot));

%% Generate All 16 Bit Combinations

bitWords = dec2bin(0:15, 4);

allBits = reshape(bitWords.' - '0', 1, []);

%% Modulation

symbols = qam16_modulator(allBits);

%% Plot Constellation

figure('Color', 'w');

scatter(real(symbols), imag(symbols), ...
    80, 'filled');

hold on;

%% Add Bit Labels

labels = cellstr(bitWords);

for k = 1:numel(symbols)

    text(real(symbols(k)) + 0.025, ...
         imag(symbols(k)) + 0.025, ...
         labels{k}, ...
         'FontSize', 9);

end

%% Decision Boundaries

threshold = 2/sqrt(10);

xline(-threshold, '--r');

xline(0, '--k');

xline(threshold, '--r');

yline(-threshold, '--r');

yline(0, '--k');

yline(threshold, '--r');

%% Figure Settings

grid on;

axis equal;

xlabel('In-phase (I)');

ylabel('Quadrature (Q)');

title('16-QAM Gray-Mapped Constellation');

xlim([-1.2 1.2]);

ylim([-1.2 1.2]);

%% Save Figure

figuresFolder = fullfile(projectRoot, ...
                         'results', ...
                         'figures');

if ~exist(figuresFolder, 'dir')

    mkdir(figuresFolder);

end

exportgraphics(gcf, ...
    fullfile(figuresFolder, ...
    'qam16_constellation.png'), ...
    'Resolution', 300);

fprintf('16-QAM constellation figure saved.\n');
