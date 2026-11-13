clear
clc
close all

% Select files
[f1,p1] = uigetfile('*.csv','Choose TE2 RMS results');
if isequal(f1,0), return, end

[f2,p2] = uigetfile('*.csv','Choose TE9 RMS results');
if isequal(f2,0), return, end

T = [readtable(fullfile(p1,f1)); ...
     readtable(fullfile(p2,f2))];

% Settings
animals = {'TE2','TE9'};
currents = [-4 -6 -8];

channels = {'A-008','A-010','A-014','A-015', ...
            'A-016','A-017','A-021','A-023'};

colors = [0.45 0.45 0.45; ...
          0.10 0.40 0.75];

% Electrode groups
W_channels = [1 2 7 8];
Si_channels = [3 4 5 6];

groups = {W_channels,Si_channels};
groupNames = {'W','Si'};

% Mean RMS ratio for each recording and channel
[G,rec,animal,current,channel] = findgroups( ...
    string(T.Recording),string(T.Animal), ...
    T.Current_mA,string(T.channel));

meanRatio = splitapply(@mean,T.rms_ratio,G);

R = table(rec,animal,current,channel,meanRatio, ...
    'VariableNames',{'Recording','Animal','Current_mA', ...
    'Channel','Mean_RMS_ratio'});

% Mean and SD across recordings
[G,animal,current,channel] = findgroups( ...
    R.Animal,R.Current_mA,R.Channel);

avg = splitapply(@mean,R.Mean_RMS_ratio,G);
sd = splitapply(@std,R.Mean_RMS_ratio,G);
n = splitapply(@numel,R.Mean_RMS_ratio,G);

summary = table(animal,current,channel,avg,sd,n, ...
    'VariableNames',{'Animal','Current_mA','Channel', ...
    'Mean_RMS_ratio','SD_RMS_ratio','N'});

% Plot W and Si electrodes separately
for g = 1:2

    fig = figure('Color','w','Position',[100 100 1100 750]);

    t = tiledlayout(2,2, ...
        'TileSpacing','loose','Padding','loose');

    selectedChannels = groups{g};

    for k = 1:4

        ch = selectedChannels(k);

        ax = nexttile;
        hold on

        for a = 1:2
            for c = 1:3

                idx = R.Animal==animals{a} & ...
                      R.Current_mA==currents(c) & ...
                      R.Channel==channels{ch};

                values = R.Mean_RMS_ratio(idx);

                if isempty(values)
                    continue
                end

                x = c + (a-1.5)*0.24;

                % Individual recordings
                plot(x*ones(size(values)),values,'o', ...
                    'Color',colors(a,:), ...
                    'MarkerFaceColor',colors(a,:), ...
                    'MarkerSize',5, ...
                    'HandleVisibility','off')

                % Mean and standard deviation
                errorbar(x,mean(values),std(values),'o', ...
                    'Color',colors(a,:), ...
                    'MarkerFaceColor',colors(a,:), ...
                    'LineWidth',1.5, ...
                    'MarkerSize',8, ...
                    'CapSize',10, ...
                    'HandleVisibility','off')

            end
        end

        % Ratio = 1 means no change
        yline(1,'k--','LineWidth',0.8, ...
            'HandleVisibility','off')

        xticks(1:3)
        xticklabels({'-4','-6','-8'})
        xlim([0.5 3.5])

        xlabel('Heating current (mA)')
        ylabel('RMS ratio')
        title(channels{ch})

        grid on
        box off
        ax.Toolbar.Visible = 'off';

        % Legend in every panel
        h1 = plot(nan,nan,'o', ...
            'Color',colors(1,:), ...
            'MarkerFaceColor',colors(1,:), ...
            'MarkerSize',7);

        h2 = plot(nan,nan,'o', ...
            'Color',colors(2,:), ...
            'MarkerFaceColor',colors(2,:), ...
            'MarkerSize',7);

        legend([h1 h2],{'TE2','TE9'}, ...
            'Location','southoutside', ...
            'Orientation','horizontal', ...
            'FontSize',10);

    end

    title(t,[groupNames{g} ...
        ' electrodes - High-frequency RMS ratio during heating'])

    exportgraphics(fig,fullfile(p1, ...
        ['heating_lfp_rms_' groupNames{g} '.png']), ...
        'Resolution',300);

end

% Save results
writetable(R,fullfile(p1, ...
    'heating_lfp_rms_recordings.csv'));

writetable(summary,fullfile(p1, ...
    'heating_lfp_rms_summary.csv'));

disp(summary)
disp('RMS summary completed.')
