clear
clc

% Select the main temperature folder (TE2 or TE9)
mainFolder = uigetdir(pwd, 'Select TE2 or TE9 temperature folder');

if isequal(mainFolder, 0)
    disp('Folder selection cancelled')
    return
end

% Recording settings
Fs = 20000;

% Find measurement folders
measurements = dir(mainFolder);
measurements = measurements([measurements.isdir]);
measurements = measurements(~ismember({measurements.name}, {'.','..'}));

for i = 1:length(measurements)

    path = fullfile(mainFolder, measurements(i).name);

    tempFile = fullfile(path, 'temperature_data.mat');
    digitalFile = fullfile(path, 'digitalin.dat');

    fprintf('\nMeasurement %d/%d: %s\n', ...
        i, length(measurements), measurements(i).name)

    if ~isfile(tempFile) || ~isfile(digitalFile)
        disp('Missing file - skipped')
        continue
    end

    % Load temperature data
    load(tempFile, 'temp_data');

    temp_time = temp_data(:,1);
    temp_C = temp_data(:,2);

    % Read digital input
    fid = fopen(digitalFile, 'r', 'ieee-le');
    digital = fread(fid, Inf, '*uint16');
    fclose(fid);

    % Get DIN-10
    din10 = bitget(digital, 11);

    % Find first LOW
    firstLow = find(din10 == 0, 1, 'first');

    if isempty(firstLow)
        disp('No LOW event - skipped')
        continue
    end

    % Calculate time shift
    t0 = (firstLow - 1)/Fs;

    % Align temperature
    temp_time_aligned = temp_time - temp_time(1) + t0;
    temp_aligned = [temp_time_aligned temp_C];

    % Save aligned temperature
    save(fullfile(path, 'temperature_aligned.mat'), ...
        'temp_aligned', 't0')

    fprintf('Temperature start: %.3f s\n', t0)
    disp('Done')

    clear temp_data temp_aligned digital din10
end

disp('All measurements checked')
