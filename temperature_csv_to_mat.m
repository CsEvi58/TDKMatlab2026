
clear
clc

% Select the main temperature folder (TE2 or TE9)
mainFolder = uigetdir(pwd, 'Select TE2 or TE9 temperature folder');

if isequal(mainFolder, 0)
    disp('Folder selection cancelled')
    return
end

% Find measurement folders
measurements = dir(mainFolder);
measurements = measurements([measurements.isdir]);
measurements = measurements(~ismember({measurements.name}, {'.','..'}));

for i = 1:length(measurements)

    path = fullfile(mainFolder, measurements(i).name);

    % Find temperature CSV
    files = dir(fullfile(path, 'log_Resistance_Temperature_*.csv'));

    if isempty(files)
        disp(['No CSV: ' measurements(i).name])
        continue
    end

    % Read temperature data
    T = readmatrix(fullfile(path, files(1).name), 'Delimiter', ',');

    temp_time = T(:,1);
    temp_C = T(:,3);
    temp_data = [temp_time temp_C];

    % Save MAT file
    matFile = fullfile(path, 'temperature_data.mat');
    save(matFile, 'temp_data')

    disp(['Done: ' measurements(i).name])

end

disp('All temperature files converted')
