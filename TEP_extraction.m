% Script to extract TEPs from preprocessed TMS-EEG data
% Version: May 27, 2024
% Emile d'Angremont
% Based on TEP_plots.m script by Timo van Hattem

% To do:
% - add option 'all' for ROI
% - add option of no peak of interest
% (- possibility to add SD to grand mean plot)
% (- add save option for figures)
% (- build in default windows for peaks)
% (- add option to create figure for individual LMFP)

%% Clean workspace
clear
close all
clc 

%% Set path
path = uigetdir([],'select TMS-EEG directory on personal Scratch');%path to personal scratch folder, change accordingly to user
cd(path);
codepath = [path '/code'];
%datapath = [path '/data/processed'];
datapath = uigetdir([],'select processed data directory with subject folders');
resultspath = [path '/results'];
addpath(genpath(datapath));
addpath(codepath); 
addpath([codepath '/eeglab2023.0']);
fprintf('Paths added!\n')

eeglab nogui;

%% Initialize variables
br = input('Which stimulated brain region? (lDLPFC/rDLPFC/M1/preSMA)\n','s'); %input brain region of interest
cons = input("And which condition(s)? (e.g. {'SP', 'D2', 'D10'})\n"); %input condition
roi = input("What is your region of interest? (e.g. {'F1', 'F3'})\n"); % ADD OPTION: 'all'
tep_p = input("What positive peaks are you interested in? (e.g. [60, 180])\n");
tep_n = input("What negative peaks are you interested in? (e.g. [45, 100])\n");
tep_pwin = zeros(length(tep_p),2);
tep_nwin = zeros(length(tep_n),2);
for i=1:length(tep_p)
    win = input(sprintf('What window do you want to use for P%d? (e.g. [%d %d])\n',...
        tep_p(i),tep_p(i)-10,tep_p(i)+10));
    tep_pwin(i,:) = win;
end
for i=1:length(tep_n)
    win = input(sprintf('What window do you want to use for N%d? (e.g. [%d %d])\n',...
        tep_n(i),tep_n(i)-10,tep_n(i)+10));
    tep_nwin(i,:) = win;
end
% lmfp = input("") select range manually?
lmfp_win = [25 80; 81 270];

subjects = dir(fullfile(datapath,'TC*'));
%cons = {'SP','D2','D10'};

%% Make TEP master file
n_peaks = numel(tep_p)+numel(tep_n);
n_lmfp = size(lmfp_win,1);
K = numel(subjects)*numel(cons)*(n_peaks+n_lmfp); 
N = numel(subjects)*numel(cons);
TEP_master = struct('ppn',cell(1,K),'br',cell(1,K),'con',cell(1,K),...
    'analysis',cell(1,K),'peak',cell(1,K),'found',cell(1,K),...
    'lat',cell(1,K),'amp',cell(1,K)); % 'area',cell(1,K);
EEG_all = struct('ppn',cell(1,N),'br',cell(1,N),'con',cell(1,N),...
    'data',cell(1,N),'LMFP',cell(1,N));
p = input('Do you want to make plots for all subjects/conditions? (y/n)\n','s');
a = input('Do you want to make a grand mean plot? (y/n)\n','s');
b = input('Do you want to perform additional baseline correction? (y/n)\n','s');
k = 1;n=1;
for i=1:numel(subjects)
    DATAIN = fullfile(datapath,subjects(i).name,br);
    for j=1:numel(cons)
        if isfile(fullfile(DATAIN, [subjects(i).name, '_preprocessed_', br, '_', cons{j},'.set']))
            EEG = pop_loadset('filename', [subjects(i).name, '_preprocessed_', br, '_', cons{j},'.set'], 'filepath', DATAIN);
            labels = {EEG.chanlocs.labels};
            urchan = [EEG.chanlocs.urchan]; 
            roi_idx = urchan(matches(labels,roi));
            switch b
                case 'y'
                    EEG = pop_rmbase(EEG, [-110 -15]);
            end
            EEG = pop_tesa_tepextract(EEG, 'ROI', 'elecs', roi, 'tepName', br);
%             EEG = pop_tesa_tepextract(EEG, 'GMFA', 'tepName', br); % GMFA = std(mean(EEG.data,3)), i.e. standard deviation across electrodes at each time point
            if numel(tep_p)>0
                EEG = pop_tesa_peakanalysis(EEG, 'ROI', 'positive', tep_p, tep_pwin, 'method', 'largest', 'samples', 5, 'tepName', br);
%                 EEG = pop_tesa_peakanalysis(EEG, 'GMFA', 'positive', tep_p, tep_pwin, 'method', 'largest', 'samples', 5, 'tepName', br);
            end
            if numel(tep_n)>0
                EEG = pop_tesa_peakanalysis(EEG, 'ROI', 'negative', tep_n, tep_nwin, 'method', 'largest', 'samples', 5, 'tepName', br);
%                 EEG = pop_tesa_peakanalysis(EEG, 'GMFA', 'positive', tep_n, tep_nwin, 'method', 'largest', 'samples', 5, 'tepName', br);
            end
            TEP_amp = tesa_peakoutput(EEG, 'winType', 'individual', 'calcType', 'amplitude', 'tablePlot', 'off');
            %TEP_area = tesa_peakoutput(EEG, 'winType', 'individual', 'calcType', 'area', 'tablePlot', 'off','averageWin',5);
            [TEP_master(k:k+n_peaks+n_lmfp-1).ppn] = deal(subjects(i).name); 
            [TEP_master(k:k+n_peaks+n_lmfp-1).br] = deal(br);
            [TEP_master(k:k+n_peaks+n_lmfp-1).con] = deal(cons{j});
            [TEP_master(k:k+n_peaks-1).analysis] = deal(TEP_amp.analysis);
            [TEP_master(k:k+n_peaks-1).peak] = deal(TEP_amp.peak);
            [TEP_master(k:k+n_peaks-1).found] = deal(TEP_amp.found);
            [TEP_master(k:k+n_peaks-1).lat] = deal(TEP_amp.lat);
            [TEP_master(k:k+n_peaks-1).amp] = deal(TEP_amp.amp);
            %[TEP_master(k:k+n_peaks-1).GMFA] = deal(TEP_area.area);
            % calculate LMFP
            data_all = mean(EEG.data,3); % average over epochs
            V_i = data_all(roi_idx,:);
            V_mean = mean(data_all,1);
            % LMFP = sqrt(sum((V_i-V_mean).^2)/numel(roi)); 
            % since average signal is already ref, it doesn't make much 
            % sense to add it here, so we just do root mean square
            LMFP = sqrt(sum(V_i.^2,1)/size(V_i,1));
            [TEP_master(k+n_peaks:k+n_peaks+n_lmfp-1).analysis] = deal('LMFP');
            [TEP_master(k+n_peaks:k+n_peaks+n_lmfp-1).lat] = deal('LMFP');
            for l=1:n_lmfp
                TEP_master(k+n_peaks+l-1).lat=lmfp_win(l,:);
                win_begin = find(EEG.times==lmfp_win(l,1));
                win_end = find(EEG.times==lmfp_win(l,2));
                TEP_master(k+n_peaks+l-1).amp=sum(LMFP(win_begin:win_end));
            end
            switch a
                case 'y'
                    EEG_all(n).ppn = subjects(i).name;
                    EEG_all(n).br = br;
                    EEG_all(n).con = cons{j};
                    EEG_all(n).data = EEG.ROI.(br).tseries;
                    EEG_all(n).LMFP = LMFP;
            end
            switch p
                case 'y'
                    pop_tesa_plot(EEG,'tepType','ROI','tepName',br,'CI','on','plotPeak','on');
                    h=gca; title([h.Title.String,sprintf(' (%s, %s)',subjects(i).name,cons{j})]);
            end
            k = k+n_peaks+n_lmfp; n = n+1;
        else
            warning("%s does not exist for subject %s and brain region %s",cons{j},subjects(i).name,br);
            TEP_master(end-n_peaks-n_lmfp+1:end) = []; % remove fows that are not needed
            EEG_all(end) = [];
        end
    end
end

%% Create grand mean
switch a
    case 'y'
        s = input("Do you want to include the peaks in your plot? (y/n)\n", 's');
        figure;
        for i=1:numel(cons)
            idx = matches({EEG_all.con},cons{i});
            data_all = cat(1,EEG_all(idx).data);
            data_mean = mean(data_all,1);
            %data_std = std(data_all,[],1);
            plot(EEG.times,data_mean);
            hold on
            % plot peaks
            switch s
                case 'y'
                    for j=1:length(tep_p)
                        win_begin = find(EEG.times==tep_pwin(j,1));
                        win_end = find(EEG.times==tep_pwin(j,2));
                        [peak,lat] = max(data_mean(win_begin:win_end));
                        t = EEG.times(win_begin+lat-1);
                        plot(t,peak,'*','MarkerEdgeColor','r');
                        text(t+5,peak,sprintf('Amp: %.2f\nLat: %d',peak,t));
                    end
                    for j=1:length(tep_n)
                        win_begin = find(EEG.times==tep_nwin(j,1));
                        win_end = find(EEG.times==tep_nwin(j,2));
                        [peak,lat] = min(data_mean(win_begin:win_end));
                        t = EEG.times(win_begin+lat-1);
                        plot(t,peak,'*','MarkerEdgeColor','r');
                        text(t+5,peak,sprintf('Amp: %.2f\nLat: %d',peak,t));
                    end
            end
        end
        hold off
        title([br ' Grand Mean']);
        xlim([-100 500]);xlabel('Time (ms)');ylabel('Amplitude (\muV)');
        xline(0,'Color', 'red', 'LineStyle', '--'); legend(cons);
        % LMFP
        figure;
        for i=1:numel(cons)
            idx = matches({EEG_all.con},cons{i});
            lmfp_all = cat(1,EEG_all(idx).LMFP);
            lmfp_mean = mean(lmfp_all,1);
            plot(EEG.times,lmfp_mean);
            hold on
            for j=1:n_lmfp
                win_begin = find(EEG.times==lmfp_win(j,1));
                win_end = find(EEG.times==lmfp_win(j,2));
                area(EEG.times(win_begin:win_end),lmfp_mean(win_begin:win_end));
            end
        end
        hold off
        title([br ' Grand Mean LMFP']);
        xlim([-100 500]);xlabel('Time (ms)');ylabel('RMS');
        xline(0,'Color', 'red', 'LineStyle', '--'); legend(cons);
        % butterfly plot
        for i=1:numel(cons)
            figure;
            for j=1:numel(EEG_all)
                plot(EEG.times,EEG_all(j).data);
                hold on
            end
            hold off
            title([br ' Butterfly']);
            xlim([-100 500]);xlabel('Time (ms)');ylabel('Amplitude (\muV)');
            xline(0,'Color', 'red', 'LineStyle', '--');
        end
end

%% Save results
s = input("Do you want to save the output? (y/n)\n","s");
switch s
    case 'y'
        if ~isfolder(resultspath);mkdir(resultspath);end
        save([resultspath, '/TEP_data.mat'], 'TEP_master');
        disp('Output saved!')
end
