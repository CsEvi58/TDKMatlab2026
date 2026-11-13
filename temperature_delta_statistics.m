clear
clc

% Select folder containing temperature results
base = uigetdir(pwd, 'Select folder containing temperature_results_A.csv');

if isequal(base, 0)
    disp('Folder selection cancelled')
    return
end

% Load results
T = readtable(fullfile(base, 'temperature_results_A.csv'));

% Calculate summary statistics
animals = {'TE2', 'TE9'};

for k = 1:2

    idx = strcmp(T.animalName, animals{k});
    dT = T.delta_T(idx);

    fprintf('\n%s\n', animals{k})
    fprintf('n = %d\n', length(dT))
    fprintf('Mean = %.3f C\n', mean(dT))
    fprintf('SD = %.3f C\n', std(dT))
    fprintf('Min = %.3f C\n', min(dT))
    fprintf('Max = %.3f C\n', max(dT))

end