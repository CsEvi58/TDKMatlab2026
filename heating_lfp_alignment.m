clear
clc
close all

% Settings
Fs = 20000;
nChannels = 8;

channelNames = {'A-008','A-010','A-014','A-015', ...
                'A-016','A-017','A-021','A-023'};

% Select files
[vfile,vpath] = uigetfile('*.csv','Choose thermovoltage CSV');
if isequal(vfile,0), return, end

[tfile,tpath] = uigetfile('*.txt','Choose MATLAB times TXT');
if isequal(tfile,0), return, end

[afile,apath] = uigetfile('*.dat','Choose amplifier.dat');
if isequal(afile,0), return, end

amp_file = fullfile(apath,afile);

% Read voltage and measurement time
txt = fileread(fullfile(tpath,tfile));

token = regexp(txt,'lasted\s+([\d\.]+)\s+seconds', ...
    'tokens','once');

if isempty(token)
    error('Measurement time not found.')
end

duration = str2double(token{1});

lines = splitlines(string(fileread(fullfile(vpath,vfile))));
V = str2double(lines);
V = V(isfinite(V));

tV = linspace(0,duration,length(V))';

% Find current switches
I = nan(size(V));

I(abs(V)>=0.05 & abs(V)<1.0) = 1;
I(abs(V)>=1.0 & abs(V)<1.8) = 4;
I(abs(V)>=1.8 & abs(V)<2.5) = 6;
I(abs(V)>=2.5) = 8;

% Remove short false changes
dt = median(diff(tV));
w = max(3,round(1/dt));

heating = movmedian(double(I>1),w)>0.5;

switch_times = tV(find(diff(heating)~=0)+1);

fprintf('Current switches: %d\n',length(switch_times))

if length(switch_times)~=10
    error('Expected 10 current switches.')
end

% Initial time alignment
info = dir(amp_file);
amp_duration = info.bytes/(2*nChannels*Fs);

initial_shift = amp_duration-duration;

% Find amplifier artefacts
corrections = -20:0.05:20;
scores = zeros(10,length(corrections));

fid = fopen(amp_file,'r','ieee-le');

for k = 1:10

    expected = switch_times(k)+initial_shift;
    t0 = expected-21;

    if t0<0 || t0+42>amp_duration
        continue
    end

    % Read amplifier around the expected switch
    fseek(fid,floor(t0*Fs)*nChannels*2,'bof');

    amp = fread(fid,[nChannels 42*Fs],'int16=>double');

    if size(amp,2)<42*Fs
        continue
    end

    % Find large amplitudes
    amp = amp-median(amp,2);
    artefact = max(abs(amp),[],1);

    % Maximum amplitude in 20 ms intervals
    block = round(0.02*Fs);
    nb = floor(length(artefact)/block);

    artefact = reshape(artefact(1:nb*block),block,nb);
    peaks = max(artefact,[],1);

    peaks = peaks/max(median(peaks),1);

    t = t0-expected+((1:nb)-0.5)*block/Fs;

    scores(k,:) = interp1(t,peaks,corrections,'nearest',0);

end

fclose(fid);

% Calculate automatic time shift
scores = movmax(scores,9,2);
combined = median(log(1+scores),1);

[~,idx] = max(combined);

auto_shift = corrections(idx);
total_shift = initial_shift+auto_shift;

switch_aligned = switch_times+total_shift;

fprintf('Initial shift: %.2f s\n',initial_shift)
fprintf('Automatic correction: %.2f s\n',auto_shift)
fprintf('Total shift: %.2f s\n',total_shift)

% Plot complete recording
% Read every 200th sample for plotting
fid = fopen(amp_file,'r','ieee-le');

amp = fread(fid,[nChannels Inf], ...
    '8*int16=>double',(200-1)*nChannels*2);

fclose(fid);

amp = amp*0.195;
tAmp = (0:size(amp,2)-1)/100;

% Animal name
if contains(upper(vfile),'TE2')
    animal = 'TE2';
elseif contains(upper(vfile),'TE9')
    animal = 'TE9';
else
    animal = '';
end

figure('Color','w','Position',[100 100 1200 700])

% Top panel: amplifier channels
ax1 = subplot(2,1,1);
hold on

offset = 3000;

for ch = 1:nChannels

    signal = amp(ch,:)-median(amp(ch,:));

    plot(tAmp,signal+(nChannels-ch)*offset, ...
        'k','LineWidth',0.5)
end

for k = 1:length(switch_aligned)
    xline(switch_aligned(k),'r','LineWidth',1)
end

yticks((0:7)*offset)
yticklabels(fliplr(channelNames))

xlabel('Time (s)')
ylabel('LFP channels')
title([animal ' - LFP and heating current alignment'])

xlim([0 amp_duration])
grid on
box off

text(ax1,-0.08,1.04,'(a)','Units','normalized', ...
    'FontWeight','bold','FontSize',13,'Clipping','off')

% Bottom panel: current
ax2 = subplot(2,1,2);

plot(tV+total_shift,I,'b','LineWidth',1)
hold on

for k = 1:length(switch_aligned)
    xline(switch_aligned(k),'r','LineWidth',1)
end

xlabel('Time (s)')
ylabel('Current magnitude (mA)')
yticks([1 4 6 8])
ylim([0 9])
xlim([0 amp_duration])

grid on
box off

text(ax2,-0.08,1.04,'(b)','Units','normalized', ...
    'FontWeight','bold','FontSize',13,'Clipping','off')

ax1.Toolbar.Visible = 'off';
ax2.Toolbar.Visible = 'off';

% Save alignment and figure
[~,name,~] = fileparts(vfile);

save(fullfile(vpath,[name '_lfp_alignment.mat']), ...
    'total_shift','switch_aligned','switch_times');

exportgraphics(gcf,fullfile(vpath, ...
    [name '_lfp_alignment.png']),'Resolution',300);

disp('Alignment and figure saved.')
