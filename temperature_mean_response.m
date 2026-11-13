clear
clc
close all

% Select folder containing temperature results
base = uigetdir(pwd, 'Select folder containing temperature_results_A.csv');

if isequal(base, 0)
    disp('Folder selection cancelled')
    return
end

% Load recording list
T = readtable(fullfile(base, 'temperature_results_A.csv'));

% Settings
Fs = 20000;
common_t = -30:0.5:150;

animals = {'TE2','TE9'};
mainFolders = {
    fullfile(base, 'TE2_thermoprobe_2025')
    fullfile(base, 'TE9_thermoprobe_2025')
};

% Create figure
figure('Color','w','Position',[100 100 1100 700])
tiledlayout(2,1,'TileSpacing','compact','Padding','compact')

for animal = 1:2

    % Select recordings
    idx = find(strcmp(T.animalName, animals{animal}));
    all_traces = [];

    for m = 1:length(idx)

        name = string(T.recording(idx(m)));
        folder = fullfile(mainFolders{animal}, name);

        % Load temperature
        S = load(fullfile(folder,'temperature_aligned.mat'));
        temp_time = S.temp_aligned(:,1);
        temp_C = S.temp_aligned(:,2);

        % Find laser onset
        fid = fopen(fullfile(folder,'analogin.dat'),'r','ieee-le');

        laser_on = [];
        samples_read = 0;
        previous_high = false;

        while ~feof(fid) && isempty(laser_on)

            analog = fread(fid,[2 Fs*30],'uint16');

            if isempty(analog)
                break
            end

            high = analog(1,:) > 30000;

            on = find(~[previous_high high(1:end-1)] & high,1);

            if ~isempty(on)
                laser_on = samples_read + on;
            end

            previous_high = high(end);
            samples_read = samples_read + length(high);
        end

        fclose(fid);

        if isempty(laser_on)
            continue
        end

        % Time relative to stimulation
        laser_start = (laser_on-1)/Fs;
        t_rel = temp_time - laser_start;

        % Baseline normalization
        idx_base = t_rel >= -30 & t_rel < 0;

        if ~any(idx_base)
            continue
        end

        T0 = mean(temp_C(idx_base));
        temp_delta = temp_C - T0;

        % Interpolate to common time
        trace = interp1(t_rel,temp_delta,common_t,'linear',NaN);

        all_traces(end+1,:) = trace;
    end

    % Calculate mean and SD
    mean_T = mean(all_traces,1,'omitnan');
    sd_T = std(all_traces,0,1,'omitnan');

    % Create panel
    ax = nexttile;
    hold on

    xlim([-30 150])
    ylim([-0.2 0.9])

    % Laser stimulation
    patch([0 15 15 0],[-0.2 -0.2 0.9 0.9], ...
        'b','FaceAlpha',0.08,'EdgeColor','none')

    % Mean +/- SD
    fill([common_t fliplr(common_t)], ...
        [mean_T+sd_T fliplr(mean_T-sd_T)], ...
        [0.75 0.75 0.75], ...
        'FaceAlpha',0.4,'EdgeColor','none')

    % Mean temperature response
    plot(common_t,mean_T,'k','LineWidth',2)

    xline(0,'b','LineWidth',1.5)
    yline(0,'k:','LineWidth',1)

    title(sprintf('%s (n = %d)',animals{animal},size(all_traces,1)))
    ylabel('Temperature change (°C)')
    grid on
    box off

    % Panel label
    if animal == 1
        label = '(a)';
    else
        label = '(b)';
    end

    text(ax,-0.065,1.04,label,'Units','normalized', ...
        'FontWeight','bold','FontSize',13,'Clipping','off')
end

xlabel('Time from stimulation onset (s)')

% Save figure
exportgraphics(gcf,fullfile(base, ...
    'temperature_mean_response.png'),'Resolution',300)

disp('Mean temperature response figure saved.')
