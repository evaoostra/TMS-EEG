%% PREPROCESSING TMS-EEG DATA 1/2
%
% Timo van Hattem
% Last Updated: 29-9-2023
% Adjusted by Emile d'Angremont, March 2024
%
% INPUT: Curry8 files of raw EEG recordings (*.cdt)
% OUTPUT: raw epochs (*.set)
%% Clean workspace
clear
close all
clc

%% Set path
path = uigetdir([],'select TMS-EEG directory on personal Scratch');%path to personal scratch folder, change accordingly to user
cd(path);
codepath = [path '/code/'];
datapath = [path '/data/'];
%addpath('/data/anw/anw-gold/NP/projects/data_TIPICCO/TMS_EEG/tvh/eeglab2023.0/');
%addpath(genpath('/data/anw/anw-gold/NP/projects/data_TIPICCO/TMS_EEG/tvh/eeglab2023.0/FastICA_25/'));
addpath(genpath(datapath));
addpath(codepath); 
addpath([codepath '/eeglab2023.0']); 
% addpath(genpath('/scratch/anw/edangremont/TMS-EEG/code/eeglab2023.0/FastICA_25/')); 
fprintf('Paths added!\n')

%% Initialize variables
ppn = input('What is the subject ID?\n','s'); %input subject number
br = input('And which brain region? (lDLPFC/rDLPFC/M1/preSMA)\n','s'); %input brain region of interest
% set input and output paths
DATAIN = [datapath, '/raw/', ppn, '/', br, '/'];
%DATAIN = ['/scratch/anw/tvanhattem/analysis_tvh/TMSEEG_data/convert/', ppn, '/', br, '/'];
DATAOUT = [datapath '/processed/', ppn, '/', br, '/'];
if isfile([DATAOUT, ppn, '_rawepochs_', br, '_SP.set'])
    answ = input('Preprocessing step 1 seems to be done already for this brain region, do you want to redo it? (y/n)\n','s');
    switch answ
        case 'n'
            answ2 = input('Do you want to continue with preprocessing part 2? (y/n)\n','s');
            switch answ2
                case 'y'
                    preprocessing_2;
                    return
                case 'n'
                    disp('OK, bye!');
                    return
            end
    end
end

%% Import data
eeglab;close;
checkset = dir(fullfile(DATAIN, '*.set'));
if ~isempty(checkset)
    EEG = pop_loadset('filename', checkset.name, 'filepath', DATAIN);
else
    EEG = loadcurry([DATAIN, dir(fullfile(DATAIN, '*.cdt')).name], 'KeepTriggerChannel', 'False', 'CurryLocations', 'False'); %load raw file (*.cdt)
end
%EEG = pop_biosig(); %for loading convert file
fprintf('N_events start processing: %d\nPlease add to Excel file and press a key to continue\n', length(EEG.event)); % manually add to excel file
pause;

%% Load channel locations
EEG = pop_chanedit(EEG,'lookup',[codepath '/eeglab2023.0/plugins/dipfit/standard_BEM/elec/standard_1020.elc']);

%% Remove unused electrodes
EEG = pop_select(EEG, 'nochannel', 63:68); %remove channel 31, 32, VEOG, HEOG, EKG, EMG
EEG.allchan = EEG.chanlocs; %save original information / changes in final dataset

%% Automated removal bad electrodes step 1
EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion',5,'Highpass', 'off','ChannelCriterion',0.8,...
    'LineNoiseCriterion',4,'BurstCriterion','off','WindowCriterion','off'); % should these parameters be saved somewhere?
rejchan_one = setdiff({EEG.allchan.labels}, {EEG.chanlocs.labels});
fprintf('Rejected channels step 1: ');
fprintf('%s ',rejchan_one{:}); % manually add to excel file
fprintf('\nPlease add to Excel file and press a key to continue\n');
pause;

%% Automated removal bad electrodes step 2
EEG = pop_rejchan(EEG, 'elec', 1:size(EEG.data,1), 'threshold', 4, 'norm', 'on', 'measure', 'kurt'); % based on kurtosis
rejchan_two = setdiff(setdiff({EEG.allchan.labels}, {EEG.chanlocs.labels}),rejchan_one);
fprintf('Recjected channels step 2: ');
fprintf('%s ',rejchan_two{:}); % manually add to excel file
fprintf('\nPlease add to Excel file and press a key to continue\n');
EEG.rejchan = [rejchan_one rejchan_two];
pause;

%% Fix latency of events in D2 and D10 condition (from marker on conditioning pulse to marker on test pulse)
EEG.oldeventlatency = [EEG.event.latency]; %save original information / changes in final dataset
disp('Fixing latencies');
for i = 1:size(EEG.event,2)
    if EEG.event(i).type == 3
        EEG.event(i).latency = EEG.event(i).latency + 21;
        EEG.urevent(i).latency = EEG.urevent(i).latency + 21;
    elseif EEG.event(i).type == 5
        EEG.event(i).latency = EEG.event(i).latency + 101;
        EEG.urevent(i).latency = EEG.urevent(i).latency + 101;
    end
end

%% Epoch segmentation
EEG = pop_epoch(EEG, {'1', '3', '5'}, [-1.5 1.5]);

%% Baseline correction
EEG = pop_rmbase(EEG, [-800 -110]);
%pop_eegplot(EEG,1,1,1);

%% Seperate epochs on condition
EEG_SP = pop_select(EEG, 'trial', find([EEG.event.type] == 1));
EEG_D2 = pop_select(EEG, 'trial', find([EEG.event.type] == 3));
EEG_D10 = pop_select(EEG, 'trial', find([EEG.event.type] == 5));

%% Save additional information for later checks
EEG_SP.rawepochs = EEG_SP.epoch;
EEG_SP.rawurevents = EEG_SP.urevent;

EEG_D2.rawepochs = EEG_D2.epoch;
EEG_D2.rawurevents = EEG_D2.urevent;

EEG_D10.rawepochs = EEG_D10.epoch;
EEG_D10.rawurevents = EEG_D10.urevent;

%% Manually check for true presence of TMS-pulse at given marker SP
EEG_pulsecheck_SP = epoch2continuous(EEG_SP);
EEG_pulsecheck_SP = tesa_findpulse(EEG_pulsecheck_SP, 'PZ', 'refract', 10, 'rate', 2e4, 'tmsLabel', 'SP'); % CZ, but PZ can be used if CZ was already filtered out
xticks([EEG_SP.event.latency]);xticklabels([EEG_SP.event.epoch]);
EEG_SP.pulseinfo = EEG_pulsecheck_SP.event;
answ = input(sprintf('Is number of single pulses detected equal to %d (y/n)?\n',EEG_SP.trials),'s');
switch answ
    case 'n'
        epochs = input('Please enter the epochs without TMS artefact (e.g. [43, 55] or [43:46]):\n');
        EEG_SP = pop_select(EEG_SP, 'notrial', epochs); %if missing visible TMS artefact at given markers, delete epochs in question
end
% pop_eegplot(EEG_pulsecheck_SP,1,1,1);

%% Manually check for true presence of TMS-pulse at given marker D2
EEG_pulsecheck_D2 = epoch2continuous(EEG_D2);
EEG_pulsecheck_D2 = tesa_findpulse(EEG_pulsecheck_D2, 'PZ', 'refract', 2, 'rate', 2e4, 'paired', 'yes', 'ISI', 2);
xticks([EEG_D2.event.latency]);xticklabels([EEG_D2.event.epoch]);
EEG_D2.pulseinfo = EEG_pulsecheck_D2.event;
answ = input(sprintf('Is number of test pulses (2ms ISI) detected equal to %d (y/n)?\n',EEG_D2.trials),'s');
switch answ
    case 'n'
        eps = input('Please enter the epochs without TMS artefact (e.g. [43, 55] or [43:46]):\n');
        EEG_D2 = pop_select(EEG_D2, 'notrial', eps); %if missing visible TMS artefact at given markers, delete epochs in question
end
% pop_eegplot(EEG_pulsecheck_D2,1,1,1);

%% Manually check for true presence of TMS-pulse at given marker D10
EEG_pulsecheck_D10 = epoch2continuous(EEG_D10);
EEG_pulsecheck_D10 = tesa_findpulse(EEG_pulsecheck_D10, 'PZ', 'refract', 10, 'rate', 2e4, 'paired', 'yes', 'ISI', 10);
xticks([EEG_D10.event.latency]);xticklabels([EEG_D10.event.epoch]);
EEG_D10.pulseinfo = EEG_pulsecheck_D10.event;
answ = input(sprintf('Is number of test pulses (10ms ISI) detected equal to %d (y/n)?\n',EEG_D10.trials),'s');
switch answ
    case 'n'
        eps = input('Please enter the epochs without TMS artefact (e.g. [43, 55] or [43:46]):\n');
        EEG_D10 = pop_select(EEG_D10, 'notrial', eps); %if missing visible TMS artefact at given markers, delete epochs in question
end
% pop_eegplot(EEG_pulsecheck_D10,1,1,1);

%% Number of raw epochs per condition
fprintf('N_rawepochs (SP/D2/D10): %d/%d/%d\nPlease add to Excel file and press a key to continue\n', length(EEG_SP.epoch),... % klopt dit nu?
    length(EEG_D2.epoch), length(EEG_D10.epoch));
pause;

%% Seperate epochs for conditions and save
mkdir(DATAOUT);
pop_saveset(EEG_SP, 'filename', [ppn, '_rawepochs_', br, '_SP.set'], 'filepath', DATAOUT);
pop_saveset(EEG_D2, 'filename', [ppn, '_rawepochs_', br, '_D2.set'], 'filepath', DATAOUT);
pop_saveset(EEG_D10, 'filename', [ppn, '_rawepochs_', br, '_D10.set'], 'filepath', DATAOUT);

close all;
answ = input('Preprocessing part 1 is done! Do you immediately want to continue with part 2? (y/n)\n','s');
switch answ
    case 'y'
        preprocessing_2;
    case 'n'
        answ2 = input('Do you want to continue with a different brain area or subject? (y/n)\n','s');
        switch answ2
            case 'y'
                preprocessing_1;
            case 'n'
                disp('OK, bye!');
        end
end
