% GB_BIDS   This script convertes the raw data to BIDS format

% Initialization
% --------------

clc
clear all
close all
dbstop if error

% Directories 
% -----------

% Add SPM 12, JSONLAB and dicm2nii to Matlab path
addpath(fullfile(userpath, 'GitHub', 'spm12'))
addpath(fullfile(userpath, 'GitHub', 'jsonlab'))
addpath(fullfile(userpath, 'GitHub', 'dicm2nii'))

% fMRI data
if ispc
    src_dir_fMRI = fullfile('G:', 'Pilot_P8_MRT');  % For Windows
elseif isunix
    src_dir_fMRI = fullfile('/Volumes', 'Pilot_P8_MRT');  % For Mac
else
    error('Unsupported platform');
end
subj_dirs_fMRI = {['00001']};

% BIDS directory
if ispc
    bids_dir = fullfile('G:', 'Pilot_P8_MRT', 'BIDS');  % For Windows
elseif isunix
    bids_dir = fullfile('/Volumes', 'Pilot_P8_MRT', 'BIDS');  % For Mac
else
    error('Unsupported platform');
end

% TODO: nochmal checken ob wir das auch brauchen                                                
bids_rn = 'README_bids_data.md';

% Subject specific run numbering
subj_runs = {[10 12 14 16 19]};

% Create main BIDS folder
if exist(bids_dir, 'dir')
    rmdir(bids_dir,'s')
    mkdir(bids_dir)
else
    mkdir(bids_dir)
end

% BIDS object 
% -----------

% Bids variables
bids_vars = [];
bids_vars.src_dir_fMRI = src_dir_fMRI; 
bids_vars.bids_dir = bids_dir;
bids_vars.bids_rn = bids_rn;
bids_vars.num_subs = 1;
bids_vars.subj_dir_fMRI = subj_dirs_fMRI;

% Bids object instance
bids = gb_bidsobj(bids_vars);

% BIDS conversion
% ---------------

% Cycle over participants
for i = 1:numel(subj_dirs_fMRI)
    
    % Update participant information
    bids.s = i; 
    bids.subj_dir_fMRI = subj_dirs_fMRI{i}; 
    bids.run = subj_runs{i};
    
    % Subject-wise BIDS conversion
    bids.bids_conv_part();
    
end

% Add group-level supplementary information 
% -----------------------------------------

bids.bids_suppl();
