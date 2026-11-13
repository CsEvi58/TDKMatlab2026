clear
clc
close all

% Settings
Fs = 20000;
nChannels = 8;

channelNames = {'A-008','A-010','A-014','A-015', ...
                'A-016','A-017','A-021','A-023'};

% High-pass filter above 200 Hz
[b,a] = butter(4,200/(Fs/2),'high');

% Select main folder
rootFolder = uigetdir(pwd,'Choose main measurements folder');

if isequal(rootFolder,0)
    return
end

% Find all alignment files in subfolders
files = dir(fullfile(rootFolder,'**','*_lfp_alignment.mat'));

fprintf('Measurements found: %d\n',length(files))

allResults = table();

% Process all measurements
for m = 1:length(files)

    folder = files(m).folder;
    matName = files(m).name;

    ampFile = fullfile(folder,'amplifier.dat');
    matFile = fullfile(folder,matName);

    fprintf('\nMeasurement %d/%d: %s\n', ...
        m,length(files),matName)

    if ~isfile(ampFile)
        fprintf('Amplifier file missing. Skipped.\n')
        continue
    end

    % Load saved time alignment
    S = load(matFile);
    switches = S.switch_aligned;

    if length(switches)~=10
        fprintf('Incorrect number of switches. Skipped.\n')
        continue
    end

    % Amplifier recording duration
    info = dir(ampFile);
    ampDuration = info.bytes/(2*nChannels*Fs);

    % Calculate RMS ratios
    cycle = [];
    channel = strings(0,1);

    rms_baseline = [];
    rms_heating = [];
    rms_ratio = [];

    fid = fopen(ampFile,'r','ieee-le');

    for k = 1:5

        % Heating starts and ends
        heatStartTime = switches(2*k-1);
        heatEndTime = switches(2*k);

        % Middle 60 seconds of the 120-second periods
        baseStart = heatStartTime-90;
        heatStart = heatStartTime+30;

        % Check the time windows
        valid = baseStart>=0 && ...
                heatStart+60<=heatEndTime && ...
                heatStart+60<=ampDuration;

        if k>1
            valid = valid && baseStart>=switches(2*k-2);
        end

        if ~valid
            fprintf('Cycle %d skipped.\n',k)
            continue
        end

        % Read baseline (60 s)
        fseek(fid,round(baseStart*Fs)*nChannels*2,'bof');
        base = fread(fid,[nChannels 60*Fs],'int16=>double');

        % Read heating (60 s)
        fseek(fid,round(heatStart*Fs)*nChannels*2,'bof');
        heat = fread(fid,[nChannels 60*Fs],'int16=>double');

        if size(base,2)~=60*Fs || size(heat,2)~=60*Fs
            fprintf('Cycle %d could not be read.\n',k)
            continue
        end

        % Convert to microvolts
        base = base*0.195;
        heat = heat*0.195;

        for ch = 1:nChannels

            % High-pass filtering
            x0 = filtfilt(b,a,base(ch,:));
            x1 = filtfilt(b,a,heat(ch,:));

            % RMS calculation
            R0 = sqrt(mean(x0.^2));
            R1 = sqrt(mean(x1.^2));

            % Heating-to-baseline RMS ratio
            if R0 > 0
                ratio = R1/R0;
            else
                ratio = NaN;
            end

            cycle(end+1,1) = k;
            channel(end+1,1) = string(channelNames{ch});

            rms_baseline(end+1,1) = R0;
            rms_heating(end+1,1) = R1;
            rms_ratio(end+1,1) = ratio;

        end

        fprintf('Cycle %d completed.\n',k)

    end

    fclose(fid);

    if isempty(cycle)
        fprintf('No valid cycles. Measurement skipped.\n')
        continue
    end

    % Save results
    [~,name] = fileparts(matName);
    name = strrep(name,'_lfp_alignment','');

    % Extract animal and heating current from filename
    animal = regexp(name,'TE\d+','match','once');
    currentText = regexp(name,'_-([468])_','tokens','once');

    if isempty(animal)
        animal = 'Unknown';
    end

    current_mA = NaN;
    if ~isempty(currentText)
        current_mA = -str2double(currentText{1});
    end

    results = table(cycle,channel,rms_baseline, ...
        rms_heating,rms_ratio);

    results.Recording = repmat(string(name),height(results),1);
    results.Animal = repmat(string(animal),height(results),1);
    results.Current_mA = repmat(current_mA,height(results),1);

    writetable(results,fullfile(folder,[name '_lfp_rms.csv']));

    allResults = [allResults; results];

    % Plot RMS ratios
    meanRatio = nan(1,8);

    for ch = 1:8

        idx = channel==channelNames{ch};

        meanRatio(ch) = mean(rms_ratio(idx),'omitnan');

    end

    fig = figure('Visible','off','Color','w', ...
        'Position',[100 100 1000 500]);

    plot(1:8,meanRatio,'bo-', ...
        'LineWidth',1.5, ...
        'MarkerFaceColor','b')

    hold on
    yline(1,'k--','LineWidth',1)

    xticks(1:8)
    xticklabels(channelNames)

    xlabel('LFP channel')
    ylabel('RMS ratio (heating / baseline)')
    title([animal ' - ' num2str(current_mA) ' mA heating'])

    grid on
    box off

    ax = gca;
    ax.Toolbar.Visible = 'off';

    exportgraphics(fig,fullfile(folder, ...
        [name '_lfp_rms.png']),'Resolution',300);

    close(fig)

    fprintf('Measurement saved.\n')

end

% Save combined results
if ~isempty(allResults)

    writetable(allResults, ...
        fullfile(rootFolder,'heating_lfp_rms_all.csv'));

    fprintf('\nCompleted measurements: %d\n', ...
        length(unique(allResults.Recording)))

    disp('All RMS results saved.')

else

    disp('No results calculated.')

end
