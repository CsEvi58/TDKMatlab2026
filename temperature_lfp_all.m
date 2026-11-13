clear
clc
close all

% Select folder containing TE2 and TE9 recording folders
base = uigetdir(pwd, 'Select folder containing TE2 and TE9 recording folders');

if isequal(base, 0)
    disp('Folder selection cancelled')
    return
end

mainFolders = {
    fullfile(base, 'TE2_thermoprobe_2025')
    fullfile(base, 'TE9_thermoprobe_2025')
};

Fs = 20000;

% Process both animals
for animal = 1:2

    folders = dir(fullfile(mainFolders{animal}, 'TE*'));
    folders = folders([folders.isdir]);

    for m = 1:length(folders)

        folder = fullfile(mainFolders{animal}, folders(m).name);
        fprintf('\nProcessing: %s\n', folders(m).name);

        % Check files
        if ~isfile(fullfile(folder, 'lfp_1kHz_uV.mat')) || ...
           ~isfile(fullfile(folder, 'temperature_aligned.mat')) || ...
           ~isfile(fullfile(folder, 'analogin.dat'))
            disp('Missing files. Skipping.')
            continue
        end

        % Load LFP
        load(fullfile(folder, 'lfp_1kHz_uV.mat'), ...
            'lfp', 't', 'channelNames')

        % Load temperature
        load(fullfile(folder, 'temperature_aligned.mat'), 'temp_aligned')

        temp_time = temp_aligned(:,1);
        temp_C = temp_aligned(:,2);

        % Find first laser onset and offset
        fid = fopen(fullfile(folder, 'analogin.dat'), 'r', 'ieee-le');

        laser_on = [];
        laser_off = [];
        samples_read = 0;
        previous_high = false;

        while ~feof(fid) && isempty(laser_off)

            analog = fread(fid, [2, Fs*30], 'uint16');

            if isempty(analog)
                break
            end

            laser_high = analog(1,:) > 30000;

            % Find onset
            if isempty(laser_on)
                on = find(~[previous_high laser_high(1:end-1)] & ...
                           laser_high, 1, 'first');

                if ~isempty(on)
                    laser_on = samples_read + on;
                end
            end

            % Find offset
            if ~isempty(laser_on)
                first = max(1, laser_on - samples_read);
                off = find(~laser_high(first:end), 1, 'first');

                if ~isempty(off)
                    laser_off = samples_read + first + off - 1;
                end
            end

            previous_high = laser_high(end);
            samples_read = samples_read + length(laser_high);

        end

        fclose(fid);

        if isempty(laser_on) || isempty(laser_off)
            disp('Laser not found. Skipping.')
            clear lfp t temp_aligned
            continue
        end

        laser_start = (laser_on-1)/Fs;
        stim_duration = (laser_off-laser_on)/Fs;

        % Select time window
        idx = t >= laser_start-30 & t <= laser_start+150;
        idx_temp = temp_time >= laser_start-30 & ...
                   temp_time <= laser_start+150;

        t_lfp = t(idx) - laser_start;
        t_temp = temp_time(idx_temp) - laser_start;

        % Create figure
        fig = figure('Color','w', ...
            'Position',[100 100 1200 700], ...
            'Visible','off');

        tiledlayout(2,1,'TileSpacing','compact','Padding','compact')

        % Top panel: LFP
        ax1 = nexttile;
        hold on

        offset = 3000;

        for ch = 1:8
            plot(t_lfp, lfp(ch,idx) + (8-ch)*offset, 'k')
        end

        yticks((0:7)*offset)
        yticklabels(fliplr(channelNames))
        ylabel('LFP channels')
        title('LFP and temperature')
        xlim([-30 150])
        grid on
        box off

        text(-0.065,1.04,'(a)','Units','normalized', ...
            'FontWeight','bold','FontSize',13,'Clipping','off')

        % Bottom panel: temperature
        ax2 = nexttile;
        hold on

        plot(t_temp, temp_C(idx_temp), 'r', 'LineWidth',1.5)
        ylabel('Temperature (°C)')
        xlabel('Time from stimulation onset (s)')
        xlim([-30 150])
        grid on
        box off

        text(-0.065,1.04,'(b)','Units','normalized', ...
            'FontWeight','bold','FontSize',13,'Clipping','off')

        % Stimulation markers
        axesList = [ax1 ax2];

        for k = 1:2
            axes(axesList(k))
            yl = ylim;

            h = patch([0 stim_duration stim_duration 0], ...
                [yl(1) yl(1) yl(2) yl(2)], ...
                'b','FaceAlpha',0.08,'EdgeColor','none');

            uistack(h,'bottom')
            xline(0,'b','LineWidth',1.5)

            % Laser onset label
            text(1/6,-0.09,'Laser on', ...
                'Units','normalized', ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','top', ...
                'Color','b','FontSize',11,'Clipping','off')
        end

        % Save figure
        outputFile = fullfile(folder, 'temperature_lfp_plot_2panel.png');

        exportgraphics(fig, outputFile, 'Resolution',300)
        close(fig)

        clear lfp t temp_aligned

        disp('Figure saved.')
    end
end

disp('All measurements processed.')
