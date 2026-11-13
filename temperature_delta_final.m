clear
clc
close all

% Select folder containing temperature_results_A.csv
base = uigetdir(pwd, 'Select folder containing temperature_results_A.csv');

if isequal(base, 0)
    disp('Folder selection cancelled')
    return
end

% Load results
T = readtable(fullfile(base, 'temperature_results_A.csv'));

% Convert dates
dates = datetime(T.date);

% Create figure
figure('Color','w','Position',[100 100 1100 650])
tiledlayout(2,1,'TileSpacing','compact','Padding','compact')

animals = {'TE2','TE9'};

for k = 1:2

    ax = nexttile;
    hold on

    % Select animal
    idx = strcmp(T.animalName, animals{k});

    % Plot temperature increase
    scatter(dates(idx), T.delta_T(idx), 55, 'filled')

    title(animals{k})
    ylabel('Temperature increase (°C)')

    xlim([datetime(2025,7,1) datetime(2025,10,1)])
    ylim([0 0.7])

    xticks(datetime(2025,[7 8 9 10],1))
    xtickformat('MMM')

    grid on
    box off

    % Panel label
    if k == 1
        label = '(a)';
    else
        label = '(b)';
    end

    text(ax,-0.065,1.04,label,'Units','normalized', ...
        'FontWeight','bold','FontSize',13, ...
        'Clipping','off')
end

xlabel('Measurement date')

% Save figure
exportgraphics(gcf,fullfile(base, ...
    'temperature_delta_final.png'),'Resolution',300)

disp('Final Delta T figure saved.')
