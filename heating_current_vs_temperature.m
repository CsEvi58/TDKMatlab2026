clear
clc
close all

% Select folder
base = uigetdir(pwd, 'Choose folder with heating cycle CSV files');

if isequal(base,0)
    return
end

files = dir(fullfile(base, '*_heating_cycles.csv'));

% Read results
animalName = strings(0,1);
recording = strings(0,1);
current_mA = [];
delta_T = [];

for k = 1:length(files)

    name = files(k).name;

    % Accept only final TE2 and TE9 measurement files
    token = regexp(name, ...
        '^(TE2|TE9)_thermovoltage_-(4|6|8)_(\d{6})_heating_cycles\.csv$', ...
        'tokens','once');

    if isempty(token)
        continue
    end

    T = readtable(fullfile(base,name));

    % One value per recording: mean of five heating cycles
    if height(T) ~= 5
        fprintf('Skipped (not 5 cycles): %s\n',name)
        continue
    end

    animalName(end+1,1) = string(token{1});
    recording(end+1,1) = string(name);
    current_mA(end+1,1) = str2double(token{2});
    delta_T(end+1,1) = mean(T.delta_T);

end

% Save measurement results
results = table(animalName,recording,current_mA,delta_T);

writetable(results,fullfile(base,'heating_temperature_results.csv'));

disp(results)

% Calculate summary statistics
animals = {'TE2','TE9'};
currents = [4 6 8];

summary_animal = strings(0,1);
summary_current = [];
n = [];
mean_delta = [];
sd_delta = [];

for a = 1:2

    for c = 1:3

        idx = animalName == animals{a} & ...
              current_mA == currents(c);

        values = delta_T(idx);

        if isempty(values)
            continue
        end

        summary_animal(end+1,1) = animals{a};
        summary_current(end+1,1) = currents(c);
        n(end+1,1) = length(values);
        mean_delta(end+1,1) = mean(values);
        sd_delta(end+1,1) = std(values);

    end
end

summary = table(summary_animal,summary_current, ...
    n,mean_delta,sd_delta);

writetable(summary,fullfile(base,'heating_temperature_summary.csv'));

disp(summary)


% Create final figure
figure('Color','w','Position',[100 100 1050 650])

for a = 1:2

    ax = subplot(2,1,a);
    hold on

    means = nan(1,3);

    for c = 1:3

        idx = animalName == animals{a} & ...
              current_mA == currents(c);

        values = delta_T(idx);

        if isempty(values)
            continue
        end

        x = currents(c);

        % Spread individual measurements horizontally
        x_points = x + linspace(-0.25,0.25,length(values))';

        scatter(x_points,values,55, ...
            [0.5 0.5 0.5],'LineWidth',1.3)

        % Calculate mean and standard deviation
        means(c) = mean(values);
        sd = std(values);

        % Mean and SD
        errorbar(x,means(c),sd, ...
            'ko','MarkerFaceColor','k', ...
            'LineWidth',1.5,'CapSize',15, ...
            'MarkerSize',8)

    end

    % Connect mean values
    plot(currents,means,'k-','LineWidth',1.3)

    xlim([3 9])
    ylim([1.5 7])

    xticks([4 6 8])
    xticklabels({'-4','-6','-8'})

    xlabel('Heating current (mA)')
    ylabel('Temperature increase (°C)')
    title(animals{a})

    grid on
    box off

    if a == 1
        label = '(a)';
    else
        label = '(b)';
    end

    text(ax,-0.07,1.04,label,'Units','normalized', ...
        'FontWeight','bold','FontSize',13,'Clipping','off')

    ax.Toolbar.Visible = 'off';

end


% Save figure
exportgraphics(gcf,fullfile(base, ...
    'heating_temperature_final.png'),'Resolution',300);

disp('Final heating temperature figure saved.')
