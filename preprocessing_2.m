%% PREPROCESSING TMS-EEG DATA 2/2
%
% Timo van Hattem
% Adjusted by Emile d'Angremont
% Version: 15-05-2024 (this version includes the introduction of the FCz electrode)

% INPUT: raw epochs (*.set)
% OUTPUT: clean epochs (*.set)

%% Clean workspace
clear
close all
clc 

%% Set path
path = uigetdir([],'select TMS-EEG directory on personal Scratch');%path to personal scratch folder, change accordingly to user
cd(path);
codepath = [path '/code'];
datapath = [path '/data'];
%addpath('/data/anw/anw-gold/NP/projects/data_TIPICCO/TMS_EEG/tvh/eeglab2023.0/');
%addpath(genpath('/data/anw/anw-gold/NP/projects/data_TIPICCO/TMS_EEG/tvh/eeglab2023.0/FastICA_25/'));
addpath(genpath(datapath));
addpath(codepath); 
addpath([codepath '/eeglab2023.0']);
addpath(genpath([codepath '/eeglab2023.0/FastICA_25/'])); 
fprintf('Paths added!\n')

%% Initialize variables
ppn = input('What is the subject ID?\n','s'); %input subject number
br = input('And which brain region? (lDLPFC/rDLPFC/M1/preSMA)\n','s'); %input brain region of interest
con = input('And which condition? (SP/D2/D10)\n','s'); %input condition

%set input and output paths
DATAIN = [datapath, '/processed/', ppn, '/', br, '/'];
DATAOUT = [datapath, '/processed/', ppn, '/', br, '/'];
if isfile([DATAOUT, ppn, '_preprocessed_', br, '_', con, '.set'])
    answ = input('Preprocessing seems to be done already for this condition, do you want to redo it? (y/n)\n','s');
    switch answ
        case 'n'
            disp('OK, bye!');
            return
    end
end

%% Import data
eeglab nogui;
EEG = pop_loadset('filename', [ppn, '_rawepochs_', br, '_', con, '.set'], 'filepath', DATAIN);%load raw epochs (*.set)

%% Remove TMS artefact 
if strcmpi(con, 'SP')
    EEG = pop_tesa_removedata(EEG, [-5 15]);
elseif strcmpi(con, 'D2')
    EEG = pop_tesa_removedata(EEG, [-7 15]); %includes TMS artefact of conditioning pulse
elseif strcmpi(con, 'D10')
    EEG = pop_tesa_removedata(EEG, [-15 15]); %includes TMS artefact of conditioning pulse
end

%% Interpolate 
EEG = pop_tesa_interpdata(EEG, 'cubic', [1 1]);

%% Downsample
EEG = pop_resample(EEG, 1000);

%% Automated removal bad epochs
EEG = pop_jointprob(EEG,1,1:size(EEG,1),3,3,0,1,0,[],0); % based on joint probability
EEG.rejepoch = setdiff([EEG.rawepochs.eventurevent],[EEG.epoch.eventurevent]); % NB this does something different. Do we want the event or the eventurevent?%save original information / changes in final dataset
rejepoch_one = length(EEG.rejepoch);
fprintf('Number of automatically rejected epochs: %d\nPlease add to Excel file and press a key to continue\n', rejepoch_one);
pause;

%% Manual trial rejection 1/2
% trial rejection
disp('Please select epochs to remove');
pop_eegplot(EEG,1,1,1);
uiwait;close;
% rejepochs = EEG.reject.rejmanual;
% EEG = pop_select(EEG, 'notrial', rejepochs);
% Rejected epochs?
EEG.rejepoch = setdiff([EEG.rawepochs.eventurevent], [EEG.epoch.eventurevent]);
rejepoch_two = length(EEG.rejepoch)-rejepoch_one;
fprintf('Number of manually rejected epochs: %d\nPlease add to Excel file and press a key to continue\n', rejepoch_two);
pause;

%% bad channel rejection
answ = input('Do you want to reject additional channels? (y/n)\n','s');
switch answ
    case 'y'
        chans = input("Please enter the channels you want to reject (e.g. {'TP9'} or {'TP9', 'TP10'}):\n");
        EEG = pop_select(EEG, 'nochannel', chans);
    case 'n'
        chans = {};
end
EEG.rejchan = setdiff({EEG.allchan.labels},{EEG.chanlocs.labels});
fprintf('Manually recjected channels: ');
fprintf('%s ',chans{:}); % manually add to excel file
fprintf('\nPlease add to Excel file and press a key to continue\n');
pause;

%% Remove data
if strcmpi(con, 'SP')
    EEG = pop_tesa_removedata(EEG, [-5 15]);
elseif strcmpi(con, 'D2')
    EEG = pop_tesa_removedata(EEG, [-7 15]); %includes TMS artefact of conditioning pulse
elseif strcmpi(con, 'D10')
    EEG = pop_tesa_removedata(EEG, [-15 15]); %includes TMS artefact of conditioning pulse
end

%% ICA round 1
EEG = pop_tesa_fastica(EEG, 'approach', 'symm', 'g', 'tanh', 'stabilization', 'on');
EEG = pop_tesa_compselect(EEG,'compCheck','on','remove','on','saveWeights','off', 'figSize','medium','plotTimeX',[-200 500],'plotFreqX',[1 100],'freqScale', 'log', 'tmsMuscle','on','tmsMuscleThresh',8,'tmsMuscleWin',[15 30],'tmsMuscleFeedback','off','blink','off','blinkThresh',2.5,'blinkElecs',{'Fp1','Fp2'},'blinkFeedback','off','move','off','moveThresh',2,'moveElecs',{'F7','F8'},'moveFeedback','off','muscle','off','muscleThresh',-0.31,'muscleFreqIn',[7 70],'muscleFreqEx',[48 52],'muscleFeedback','off','elecNoise','off','elecNoiseThresh',4,'elecNoiseFeedback','off' );

%% Interpolate 
EEG = pop_tesa_interpdata(EEG, 'cubic', [10 10]);

%% Filtering
EEG = pop_tesa_filtbutter(EEG, 1, 80, 4, 'bandpass'); %bandpass filter 1-80 Hz)
EEG = pop_tesa_filtbutter(EEG, 48, 52, 4, 'bandstop' ); %notch filter 48-52 Hz

%% SOUND
%EEG = pop_tesa_sound(EEG, 'lambdaValue', 0.1, 'iter', 5);

%% Manual trial rejection 2/2
disp('Please select epochs to remove');
pop_eegplot(EEG,1,1,0);
uiwait;close;
% rejepochs = EEG.reject.rejmanual;
% EEG = pop_select(EEG, 'notrial', rejepochs);
answ = input('Do you want to reject any epochs? (y/n)\n','s');
switch answ
    case 'y'
        epochs = input('Please enter the epochs to reject (e.g. [5] or [5, 15]\n');
        EEG = pop_select(EEG, 'notrial', epochs);
end
% Rejected epochs?
EEG.rejepoch = setdiff([EEG.rawepochs.eventurevent], [EEG.epoch.eventurevent]);
rejepoch_three = length(EEG.rejepoch)-rejepoch_one-rejepoch_two;
fprintf('Number of manually rejected epochs: %d\nPlease add to Excel file and press a key to continue\n', rejepoch_three);
pause;

%% Remove data around TMS-puls and add constant amplitude
if strcmpi(con, 'SP')
    EEG = pop_tesa_removedata(EEG, [-5 15]);
elseif strcmpi(con, 'D2')
    EEG = pop_tesa_removedata(EEG, [-7 15]);
elseif strcmpi(con, 'D10')
    EEG = pop_tesa_removedata(EEG, [-15 15]);
end

%% ICA round 2
EEG = pop_tesa_fastica(EEG, 'approach', 'symm', 'g', 'tanh', 'stabilization', 'on');
EEG = pop_tesa_compselect(EEG,'compCheck','on','remove','on','saveWeights','off', 'figSize','medium','plotTimeX',[-200 500],'plotFreqX',[1 100],'freqScale', 'log', 'tmsMuscle','on','tmsMuscleThresh',8,'tmsMuscleWin',[15 30],'tmsMuscleFeedback','off','blink','on','blinkThresh',2.5,'blinkElecs',{'AF7','AF8'},'blinkFeedback','off','move','on','moveThresh',2,'moveElecs',{'F7','F8'},'moveFeedback','off','muscle','on','muscleThresh',-0.31,'muscleFreqIn',[7 70],'muscleFreqEx',[48 52],'muscleFeedback','off','elecNoise','on','elecNoiseThresh',4,'elecNoiseFeedback','off' );

%% Interpolate data around TMS-pulse
EEG = pop_tesa_interpdata(EEG, 'cubic', [10 10]); 

%% Number of epochs and channels after processing
fprintf('N_epochs (%s): %d\n', con, length(EEG.epoch));
fprintf('N_channels (%s): %d\n', con, length(EEG.chanlocs));
fprintf('Please add to Excel file and press a key to continue\n');
pause;
%% Interpolate removed channels
EEG = pop_interp(EEG, EEG.allchan, 'spherical');

%% Rereference data to average of all electrodes
% FCz (old reference) should be added to data
fcz_struct = pop_chanedit(struct(labels='FCZ',type=[],X=27.39,Y=-0.3671,Z=88.668),'convert','cart2all');
[EEG.chanlocs(:).ref] = deal('FCZ');
EEG = pop_reref(EEG, [], 'refloc', fcz_struct);
EEG = pop_chanedit(EEG,'changefield',{numel(EEG.chanlocs), 'urchan', numel(EEG.chanlocs)});
%pop_eegplot(EEG,1,1,1)

%% Plot results
switch br
    case 'rDLPFC'
        pop_tesa_plot(EEG, 'elec', 'F4', 'tepType', 'data', 'xlim', [-100 400], 'ylim', [-20 20], 'CI', 'on', 'plotPeak', 'off');
    case 'lDLPFC'
        pop_tesa_plot(EEG, 'elec', 'F3', 'tepType', 'data', 'xlim', [-100 400], 'ylim', [-20 20], 'CI', 'on', 'plotPeak', 'off');
    case 'M1'
        pop_tesa_plot(EEG, 'elec', 'C3', 'tepType', 'data', 'xlim', [-100 400], 'ylim', [-20 20], 'CI', 'on', 'plotPeak', 'off');
    case 'preSMA'
        pop_tesa_plot(EEG, 'elec', 'FZ', 'tepType', 'data', 'xlim', [-100 400], 'ylim', [-20 20], 'CI', 'on', 'plotPeak', 'off');
end
answ = input('Are you happy with the results? (y/n)\n','s');
switch answ
    case 'y'
        close;
    case 'n'
        answ2 = input('Do you want to start over? (y/n)\n','s');
        switch answ2
            case 'y'
                preprocessing_2;
        end
end

%% Save dataset
pop_saveset(EEG, 'filename', [ppn, '_preprocessed_', br, '_', con, '.set'], 'filepath', DATAOUT);
answ = input('Preprocessing part 2 is done! Do you want to continue with a different condition? (y/n)\n','s');
switch answ
    case 'y'
        preprocessing_2;
    case 'n'
        answ2 = input('Do you want to continue with a different brain area or subject? (y/n)\n','s');
        switch answ2
            case 'y'
                preprocessing_1;
            case 'n'
                disp('OK, bye!')
        end
end
