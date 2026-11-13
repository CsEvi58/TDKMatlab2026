clear
clc
close all

% Select the recording folder
folder = uigetdir(pwd, 'Select seizure recording folder');

if isequal(folder, 0)
    disp('Folder selection cancelled')
    return
end

S = load(fullfile(folder,'lfp_1kHz_uV.mat'));

lfp = S.lfp;
t = S.t;
Fs = S.Fs;
channelNames = S.channelNames;

% Select LFP channel
ch = 5;  % A-016

% Find laser stimulation
fid = fopen(fullfile(folder,'analogin.dat'),'r','ieee-le');

laser_on = [];
laser_off = [];
samples_read = 0;
previous_high = false;

while ~feof(fid) && isempty(laser_off)

    analog = fread(fid,[2 20000*30],'uint16');

    if isempty(analog)
        break
    end

    high = analog(1,:) > 30000;

    % Detect laser onset
    if isempty(laser_on)
        on = find(~[previous_high high(1:end-1)] & high,1);

        if ~isempty(on)
            laser_on = samples_read + on;
        end
    end

    % Detect laser offset
    if ~isempty(laser_on)
        first = max(1,laser_on-samples_read);
        off = find(~high(first:end),1);

        if ~isempty(off)
            laser_off = samples_read + first + off - 1;
        end
    end

    previous_high = high(end);
    samples_read = samples_read + length(high);

end

fclose(fid);

if isempty(laser_on) || isempty(laser_off)
    error('Laser stimulation not found.')
end

laser_start = (laser_on-1)/20000;
stim_duration = (laser_off-laser_on)/20000;

fprintf('Laser onset: %.2f s\n',laser_start)
fprintf('Stimulation duration: %.2f s\n',stim_duration)

% Select LFP segment
% Time relative to laser onset
t_rel = t-laser_start;

% Show 30 seconds before and 70 seconds after stimulation
idx = t_rel>=-30 & t_rel<=70;

time = t_rel(idx);
signal = double(lfp(ch,idx));

% Remove DC offset
signal = signal-mean(signal);

% Filter LFP (1-80 Hz)
[b,a] = butter(4,[1 80]/(Fs/2),'bandpass');
signal = filtfilt(b,a,signal);
 
% Calculate spectrogram
% 1-second windows with 80% overlap
[~,f,ts,P] = spectrogram(signal, ...
    Fs,round(0.8*Fs),1024,Fs);

ts = ts+time(1);

% Calculate RMS in 1-second windows
window = Fs;
nWindows = floor(length(signal)/window);

rmsValues = zeros(nWindows,1);
rmsTime = zeros(nWindows,1);

for k = 1:nWindows

    idxWindow = (k-1)*window+1:k*window;

    x = signal(idxWindow);

    rmsValues(k) = sqrt(mean(x.^2));
    rmsTime(k) = mean(time(idxWindow));

end

% Plot results
fig = figure('Color','w','Position',[100 100 1100 750]);

tiledlayout(2,1,'TileSpacing','loose','Padding','loose')

% Spectrogram
ax1 = nexttile;

imagesc(ts,f,10*log10(P+eps))
axis xy
ylim([1 80])
xlim([-30 70])
colorbar

xlabel('Time from stimulation onset (s)')
ylabel('Frequency (Hz)')
title(['LFP spectrogram - ' channelNames{ch}])

hold on
xline(0,'w','Laser on','LineWidth',1.5, ...
    'LabelVerticalAlignment','bottom', ...
    'LabelColor','k')

xline(stim_duration,'w--','Laser off','LineWidth',1.2, ...
    'LabelVerticalAlignment','bottom', ...
    'LabelColor','k')

text(ax1,-0.07,1.04,'(a)','Units','normalized', ...
    'FontWeight','bold','FontSize',13,'Clipping','off')

% RMS over time
ax2 = nexttile;
hold on

plot(rmsTime,rmsValues,'k','LineWidth',1.5)

xline(0,'b','Laser on','LineWidth',1.5, ...
    'LabelVerticalAlignment','top')

xline(stim_duration,'b--','Laser off','LineWidth',1.2, ...
    'LabelVerticalAlignment','top')

xlabel('Time from stimulation onset (s)')
ylabel('LFP RMS (\muV)')
title('Time-resolved LFP RMS')

xlim([-30 70])
grid on
box off

text(ax2,-0.07,1.04,'(b)','Units','normalized', ...
    'FontWeight','bold','FontSize',13,'Clipping','off')

ax1.Toolbar.Visible = 'off';
ax2.Toolbar.Visible = 'off';

% Save figure
exportgraphics(fig,fullfile(folder, ...
    'seizure_spectrogram_rms.png'),'Resolution',300);

disp('Seizure analysis figure saved.')

% Compare RMS between periods
periods = [-15 -5;
            18 28;
            55 65];

names = {'Before','Seizure activity','After'};

meanRMS = zeros(3,1);

for k = 1:3
    idxPeriod = rmsTime >= periods(k,1) & ...
                rmsTime < periods(k,2);

    meanRMS(k) = mean(rmsValues(idxPeriod));
end

% Relative changes
ratio = meanRMS(2) / meanRMS(1);

fprintf('\nLFP RMS comparison - %s\n', channelNames{ch})
fprintf('Before: %.2f uV\n', meanRMS(1))
fprintf('During activity: %.2f uV\n', meanRMS(2))
fprintf('After: %.2f uV\n', meanRMS(3))
fprintf('Activity / baseline ratio: %.2f\n', ratio)

% Save numerical results
results = table(string(names'), meanRMS, ...
    'VariableNames', {'Period','Mean_RMS_uV'});

writetable(results, fullfile(folder,'seizure_rms_comparison.csv'));