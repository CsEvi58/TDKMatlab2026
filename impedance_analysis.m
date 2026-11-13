clear
clc
close all

% Select folders
folder1 = uigetdir(pwd,'Choose TE2 impedance folder');
if isequal(folder1,0), return, end

folder2 = uigetdir(pwd,'Choose TE9 impedance folder');
if isequal(folder2,0), return, end

folders = {folder1,folder2};
animals = {'TE2','TE9'};

colors = [0.45 0.45 0.45; ...
          0.10 0.40 0.75];

% Read impedance measurements
allData = table();

for a = 1:2

    files = dir(fullfile(folders{a},'**', ...
        [animals{a} '_Z_1kHz_*.csv']));

    fprintf('%s: %d files found\n',animals{a},length(files))

    for i = 1:length(files)

        filename = files(i).name;
        filepath = fullfile(files(i).folder,filename);

        T = readtable(filepath,'VariableNamingRule','preserve');

        % Keep enabled channels
        T = T(T{:,4}==1,:);

        % Read measurement date from filename
        dateText = regexp(filename,'_(\d{6})\.csv$', ...
            'tokens','once');

        if isempty(dateText)
            continue
        end

        date = datetime(dateText{1},'InputFormat','yyMMdd');

        % Create a simple results table
        n = height(T);

        data = table( ...
            repmat(string(animals{a}),n,1), ...
            repmat(date,n,1), ...
            string(T{:,1}), ...
            T{:,5}/1000, ...
            'VariableNames', ...
            {'Animal','Date','Channel','Impedance_kOhm'});

        allData = [allData; data];

    end
end

if isempty(allData)
    error('No impedance measurements found.')
end

allData = sortrows(allData,{'Animal','Date','Channel'});

% Electrode groups
W_channels = {'A-008','A-010','A-021','A-023'};
Si_channels = {'A-014','A-015','A-016','A-017'};

groups = {W_channels,Si_channels};
groupNames = {'W','Si'};

% Maximum displayed impedance in kOhm
% Larger values are marked with stars
yLimits = [1000 2000];


% Plot impedance over time
for a = 1:2

    for g = 1:2

        fig = figure('Color','w', ...
            'Position',[100 100 1100 750]);

        t = tiledlayout(2,2, ...
            'TileSpacing','loose','Padding','loose');

        for ch = 1:4

            ax = nexttile;
            hold on

            % Select animal and channel
            idx = allData.Animal==animals{a} & ...
                  allData.Channel==groups{g}{ch};

            data = allData(idx,:);
            data = sortrows(data,'Date');

            dates = data.Date;
            impedance = data.Impedance_kOhm;

            % Find values above the displayed range
            high = impedance > yLimits(g);

            % Show only values within the range
            impedance(high) = NaN;

            plot(dates,impedance,'-o', ...
                'Color',colors(a,:), ...
                'MarkerFaceColor',colors(a,:), ...
                'LineWidth',1.2, ...
                'MarkerSize',6);

            % Mark high values with stars
            plot(dates(high), ...
                0.95*yLimits(g)*ones(sum(high),1),'*', ...
                'Color',colors(a,:), ...
                'MarkerSize',10, ...
                'LineWidth',1.2);

            title(groups{g}{ch})
            xlabel('Date')
            ylabel('Impedance at 1 kHz (k\Omega)')

            ylim([0 yLimits(g)])

            grid on
            box off
            ax.Toolbar.Visible = 'off';

        end

        title(t,[animals{a} ' - ' groupNames{g} ...
            ' electrodes - Impedance over time'])

        exportgraphics(fig,fullfile(folder1, ...
            [animals{a} '_impedance_' groupNames{g} '.png']), ...
            'Resolution',300);

    end

end


% Save data
writetable(allData,fullfile(folder1, ...
    'impedance_all.csv'));

disp('Impedance analysis completed.')
