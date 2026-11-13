
clear
clc
close all

% Select files
[csv_file, csv_path] = uigetfile('*.csv', ...
    'Choose thermovoltage CSV');

if isequal(csv_file, 0)
    return
end

[txt_file, txt_path] = uigetfile('*.txt', ...
    'Choose MATLAB times TXT');

if isequal(txt_file, 0)
    return
end

% Read measurement duration
txt = fileread(fullfile(txt_path, txt_file));

token = regexp(txt, ...
    'lasted\s+([\d\.]+)\s+seconds', 'tokens', 'once');

if isempty(token)
    error('Measurement duration was not found.')
end

total_time = str2double(token{1});

% Read voltage data
file_text = fileread(fullfile(csv_path, csv_file));
lines = splitlines(string(file_text));
lines = strip(lines);
lines(lines == "") = [];

Vt = str2double(lines);
Vt = Vt(isfinite(Vt));
Vt = Vt(:);

N = length(Vt);
time_s = linspace(0, total_time, N)';

fprintf('Imported voltage samples: %d\n', N)
fprintf('Measurement duration: %.1f s\n', total_time)

% Calculate resistance and detect current
Rt = nan(N,1);
current_mA = nan(N,1);

for i = 1:N

    voltage = abs(Vt(i));

    if voltage < 0.05
        continue

    elseif voltage < 1.0
        current_mA(i) = 1;

    elseif voltage < 1.8
        current_mA(i) = 4;

    elseif voltage < 2.5
        current_mA(i) = 6;

    else
        current_mA(i) = 8;
    end

    Rt(i) = voltage / (current_mA(i)*1e-3);
end

% Sensor calibration
sensor_text = upper(string(fullfile(csv_path,csv_file)));

if contains(sensor_text,"TE2")

    R0 = 316.5034078103537922;
    TCR = 0.0025496306309295;
    animal = 'TE2';

elseif contains(sensor_text,"TE9")

    R0 = 341.2272853676663544;
    TCR = 0.0020431379350270;
    animal = 'TE9';

else
    error('TE2 or TE9 was not found in the file path.')
end

temperature_C = (Rt ./ R0 - 1) ./ TCR;

% Detect heating periods
% Smooth current detection over approximately 1 second
dt = median(diff(time_s));
window = max(3,round(1/dt));

if mod(window,2) == 0
    window = window + 1;
end

heating = current_mA > 1;
heating = movmedian(double(heating),window) > 0.5;

% Find start and end of each heating period
changes = diff([false; heating; false]);

starts = find(changes == 1);
ends = find(changes == -1) - 1;

% Calculate temperature increase in each cycle
cycle = [];
heating_current = [];
baseline_T = [];
heating_T = [];
delta_T = [];

for k = 1:length(starts)

    t_start = time_s(starts(k));
    t_end = time_s(ends(k));
    duration = t_end - t_start;

    % Heating periods should last approximately 2 minutes
    if duration < 90 || duration > 150
        continue
    end

    % Middle 60 seconds of the preceding 1 mA period
    idx_base = time_s >= t_start-90 & ...
           time_s < t_start-30;

    % Middle 60 seconds of the heating period
    idx_heat = time_s >= t_start+30 & ...
           time_s < t_start+90;

    % Check that enough valid samples are present
    valid_base = idx_base & current_mA == 1;
    valid_heat = idx_heat & heating;

    if sum(valid_base) < 5 || sum(valid_heat) < 5
        continue
    end

    if sum(valid_base) < 0.8*sum(idx_base) || ...
       sum(valid_heat) < 0.8*sum(idx_heat)
        continue
    end

    T0 = mean(temperature_C(valid_base),'omitnan');
    T1 = mean(temperature_C(valid_heat),'omitnan');

    current_values = current_mA(starts(k):ends(k));
    current_values = current_values(isfinite(current_values));

    if isempty(current_values)
        continue
    end

    I = mode(current_values);

    cycle(end+1,1) = length(cycle)+1;
    heating_current(end+1,1) = I;
    baseline_T(end+1,1) = T0;
    heating_T(end+1,1) = T1;
    delta_T(end+1,1) = T1-T0;

end

% Save results
results = table(cycle,heating_current,baseline_T, ...
    heating_T,delta_T);

[~,csv_name,~] = fileparts(csv_file);

output_file = fullfile(csv_path, ...
    [csv_name '_heating_cycles.csv']);

writetable(results,output_file);

disp(results)

if isempty(delta_T)
    warning('No complete heating cycles were found.')
    return
end

mean_delta = mean(delta_T);
sd_delta = std(delta_T);

fprintf('\nAnimal: %s\n',animal)
fprintf('Heating current: -%d mA\n',mode(heating_current))
fprintf('Valid heating cycles: %d\n',length(delta_T))
fprintf('Mean Delta T: %.3f C\n',mean_delta)
fprintf('SD: %.3f C\n',sd_delta)

if length(delta_T) ~= 5
    fprintf('Note: 5 heating cycles were expected.\n')
end

% Plot temperature and current
figure('Color','w','Position',[100 100 1100 650])

% Top panel
ax1 = subplot(2,1,1);

plot(time_s,temperature_C,'k','LineWidth',1)
xlabel('Time (s)')
ylabel('Temperature (°C)')
title(sprintf('%s - Heating experiment',animal))
ylim([30 42])
grid on
box off

text(ax1,-0.07,1.04,'(a)','Units','normalized', ...
    'FontWeight','bold','FontSize',13,'Clipping','off')

% Bottom panel
ax2 = subplot(2,1,2);

plot(time_s,current_mA,'b')
xlabel('Time (s)')
ylabel('Current magnitude (mA)')
yticks([1 4 6 8])
ylim([0 9])
grid on
box off

text(ax2,-0.07,1.04,'(b)','Units','normalized', ...
    'FontWeight','bold','FontSize',13,'Clipping','off')

% Save figure
figure_file = fullfile(csv_path, ...
    [csv_name '_heating_temperature.png']);

ax1.Toolbar.Visible = 'off';
ax2.Toolbar.Visible = 'off';

exportgraphics(gcf,figure_file,'Resolution',300);

disp('Results and figure saved.')