clear
clc

% Select the main recording folder (TE2 or TE9)
mainFolder = uigetdir(pwd, 'Select TE2 or TE9 recording folder');

if isequal(mainFolder, 0)
    disp('Folder selection cancelled')
    return
end

% Recording settings
Fs_original = 20000;
Fs = 1000;
nChannels = 8;

channelNames = {'A-008', 'A-010', 'A-014', 'A-015', ...
                'A-016', 'A-017', 'A-021', 'A-023'};

% Find measurement folders
measurements = dir(mainFolder);
measurements = measurements([measurements.isdir]);
measurements = measurements(~ismember({measurements.name}, {'.','..'}));

for k = 1:length(measurements)

    measurementFolder = fullfile(mainFolder, measurements(k).name);
    inputFile = fullfile(measurementFolder, 'amplifier.dat');
    outputFile = fullfile(measurementFolder, 'lfp_1kHz_uV.mat');
    figureFile = fullfile(measurementFolder, 'lfp_preview_uV.png');

    fprintf('\nMeasurement %d/%d: %s\n', ...
        k, length(measurements), measurements(k).name)

    if ~isfile(inputFile)
        disp('No amplifier.dat - skipped')
        continue
    end

    if isfile(outputFile)
        disp('Already processed - skipped')
        continue
    end

    % Check amplifier file size
    info = dir(inputFile);
    nSamples = info.bytes / (2*nChannels);

    if mod(nSamples,1) ~= 0
        disp('Wrong file size - skipped')
        continue
    end

    % Check time file size
    timeFile = fullfile(measurementFolder, 'time.dat');
    timeStatus = 'Not checked';

    if isfile(timeFile)
        infoTime = dir(timeFile);
        nTime = infoTime.bytes / 4;

        if nTime == nSamples
            timeStatus = 'Same number of samples';
        else
            timeStatus = 'Different number of samples';
        end
    else
        timeStatus = 'No time.dat';
    end

    disp(timeStatus)

    % Prepare output matrix
    nNew = ceil(nSamples/20);
    lfp = zeros(nChannels, nNew, 'single');

    % Read and downsample the 8 channels
    for ch = 1:nChannels

        fid = fopen(inputFile, 'r', 'ieee-le');
        fseek(fid, 2*(ch-1), 'bof');

        raw = fread(fid, nSamples, ...
            'int16=>double', 2*(nChannels-1));

        fclose(fid);

        raw = raw * 0.195;       % Convert to microvolts
        y = resample(raw, 1, 20); % 20 kHz to 1 kHz

        lfp(ch,1:length(y)) = single(y);

        clear raw y

        fprintf('Channel %d/%d done\n', ch, nChannels)
    end

    % Time axis
    t = (0:size(lfp,2)-1)/Fs;

    % Save processed data
    save(outputFile, 'lfp', 'Fs', 'Fs_original', ...
        't', 'channelNames', 'timeStatus', '-v7.3')

    % Plot first 10 seconds
    figure('Visible', 'off')

    idx = 1:min(10*Fs, size(lfp,2));

    for ch = 1:nChannels
        subplot(nChannels,1,ch)
        plot(t(idx), lfp(ch,idx))
        ylabel([channelNames{ch} ' (uV)'])
        grid on

        if ch == 1
            title('LFP - first 10 seconds')
        end
    end

    xlabel('Time (s)')
    saveas(gcf, figureFile)
    close(gcf)

    clear lfp t
    disp('Done')
end

disp('All folders checked')