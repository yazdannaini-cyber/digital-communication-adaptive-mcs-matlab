
clc;
clear;
close all;

projectRoot = fileparts(mfilename('fullpath'));

resultsDir = fullfile(projectRoot,'results');

figuresDir = fullfile(resultsDir,'figures');

S = load(fullfile(resultsDir, ...
    'fec_awgn_comparison.mat'),'FECResults');

T = S.FECResults;

systems = unique(T.System,'stable');

if exist(figuresDir,'dir') ~= 7
    mkdir(figuresDir);
end

%% PER plot

fig = figure('Visible','off','Color','w');

ax = axes(fig);

hold(ax,'on');
grid(ax,'on');

for k = 1:numel(systems)

    hit = T.System == systems(k);

    current = T(hit,:);

    [snrValues,order] = sort(current.EbN0_dB);

    perValues = current.PER(order);

    perValues = max(perValues,0.5/current.NumPackets(1));

    semilogy(ax,snrValues,perValues,'-o', ...
        'LineWidth',1.5, ...
        'DisplayName',char(systems(k)));

end

xlabel(ax,'E_b/N_0 (dB)');
ylabel(ax,'Packet Error Rate');

title(ax,'FEC PER Comparison over AWGN');

legend(ax,'Location','southwest');

perPath = fullfile(figuresDir, ...
    'fec_awgn_per_comparison.png');

try
    exportgraphics(ax,perPath,'Resolution',200);
catch
    print(fig,perPath,'-dpng','-r200');
end

close(fig);

%% BER plot

fig = figure('Visible','off','Color','w');

ax = axes(fig);

hold(ax,'on');
grid(ax,'on');

for k = 1:numel(systems)

    hit = T.System == systems(k);

    current = T(hit,:);

    [snrValues,order] = sort(current.EbN0_dB);

    berValues = current.BER(order);

    berValues = max(berValues, ...
        0.5/(max(current.NumPackets)*48));

    semilogy(ax,snrValues,berValues,'-s', ...
        'LineWidth',1.5, ...
        'DisplayName',char(systems(k)));

end

xlabel(ax,'E_b/N_0 (dB)');
ylabel(ax,'Payload BER');

title(ax,'FEC BER Comparison over AWGN');

legend(ax,'Location','southwest');

berPath = fullfile(figuresDir, ...
    'fec_awgn_ber_comparison.png');

try
    exportgraphics(ax,berPath,'Resolution',200);
catch
    print(fig,berPath,'-dpng','-r200');
end

close(fig);

fprintf('\nFEC figures regenerated successfully.\n');

fprintf('%s\n',perPath);
fprintf('%s\n',berPath);
