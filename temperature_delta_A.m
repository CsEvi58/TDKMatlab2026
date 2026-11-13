
clear
clc

% Select the main folder containing both animals
base = uigetdir(pwd, 'Select folder containing TE2 and TE9');

if isequal(base, 0)
    disp('Folder selection cancelled')
    return
end

mainFolders = {
    fullfile(base, 'TE2_thermoprobe_2025')
    fullfile(base, 'TE9_thermoprobe_2025')
};

Fs = 20000;

% Results
animalName = strings(0,1);
recording = strings(0,1);
date = NaT(0,1);
baseline_T = [];
peak_T = [];
delta_T = [];
time_to_peak = [];

% Process both animals
for animal = 1:2

    folders = dir(fullfile(mainFolders{animal}, 'TE*'));
    folders = folders([folders.isdir]);

    for m = 1:length(folders)

        folder = fullfile(mainFolders{animal}, folders(m).name);

        % Check files
        if ~isfile(fullfile(folder, 'temperature_aligned.mat')) || ...
           ~isfile(fullfile(folder, 'analogin.dat'))
            continue
        end

        % Load temperature
        S = load(fullfile(folder, 'temperature_aligned.mat'));

        temp_time = S.temp_aligned(:,1);
        temp_C = S.temp_aligned(:,2);

        % Find laser onset
        fid = fopen(fullfile(folder, 'analogin.dat'), 'r', 'ieee-le');

        laser_on = [];
        samples_read = 0;
        previous_high = false;

        while ~feof(fid) && isempty(laser_on)

            analog = fread(fid, [2, Fs*30], 'uint16');

            if isempty(analog)
                break
            end

            high = analog(1,:) > 30000;

            on = find(~[previous_high high(1:end-1)] & high, 1);

            if ~isempty(on)
                laser_on = samples_read + on;
            end

            previous_high = high(end);
            samples_read = samples_read + length(high);
        end

        fclose(fid);

        if isempty(laser_on)
            fprintf('No laser: %s\n', folders(m).name)
            continue
        end

        % Time relative to stimulation
        laser_start = (laser_on-1)/Fs;
        t_rel = temp_time - laser_start;

        % Baseline and peak windows
        idx_base = t_rel >= -30 & t_rel < 0;
        idx_peak = t_rel >= 0 & t_rel <= 90;

        if ~any(idx_base) || ~any(idx_peak)
            fprintf('Missing temperature data: %s\n', folders(m).name)
            continue
        end

        % Temperature features
        T0 = mean(temp_C(idx_base));

        peak_values = temp_C(idx_peak);
        peak_times = t_rel(idx_peak);

        [Tmax, peak_idx] = max(peak_values);

        % Store results
        animalName(end+1,1) = string(folders(m).name(1:3));
        recording(end+1,1) = string(folders(m).name);

        date(end+1,1) = datetime(folders(m).name(5:10), ...
            'InputFormat', 'yyMMdd');

        baseline_T(end+1,1) = T0;
        peak_T(end+1,1) = Tmax;
        delta_T(end+1,1) = Tmax-T0;
        time_to_peak(end+1,1) = peak_times(peak_idx);

        fprintf('%s: Delta T = %.3f C\n', ...
            folders(m).name, Tmax-T0)
    end
end

% Create results table
results = table(animalName, recording, date, ...
    baseline_T, peak_T, delta_T, time_to_peak);

% Save results
writetable(results, fullfile(base, 'temperature_results_A.csv'));

disp('Temperature results saved.')
disp(results)
