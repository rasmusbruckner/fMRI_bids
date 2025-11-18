% GB_BIDS   This script converts the raw data to BIDS format

% Initialization
% --------------

clear; close all; clc;
dbstop if error

% Directories
% -----------

% % Add toolboxes
addpath(fullfile(userpath, 'spm12'))
addpath(fullfile(userpath, 'jsonlab'))
addpath(fullfile(userpath, 'dicm2nii'))

% flag for if you want to redo the entire conversion
redo_conversion = true;

% File paths
src_dir_fMRI = fullfile("G:\1_RU5389\1_DICOMs"); % raw data
subj_dirs_fMRI = { ...
    'CCNB_12719_Predator', 'CCNB_12746_Predator', 'CCNB_12748_Predator', ...
    'CCNB_12754_Predator', 'CCNB_12842_Predator', 'CCNB_12856_Predator', ...
    'CCNB_12866_Predator', 'CCNB_12867_Predator', 'CCNB_12885_Predator', ...
    'CCNB_12886_Predator', 'CCNB_12901_Predator', 'CCNB_12907_Predator', ...
    'CCNB_12958_Predator', 'CCNB_12977_Predator', 'CCNB_12985_Predator', ...
    'CCNB_13014_Predator', 'CCNB_12514_Predator', 'CCNB_12593_Predator', ...
    'CCNB_12597_Predator', 'CCNB_12640_Predator', 'CCNB_12641_Predator', ...
    'CCNB_12689_Predator', 'CCNB_12705_Predator', 'CCNB_12718_Predator' ...
    };
bids_dir = fullfile("G:\1_RU5389\2_BIDS"); % BIDS folder

% TODO: nochmal checken ob wir das auch brauchen
bids_rn = 'README_bids_data.md';

% Subject specific run numbering
subj_runs = { ...
    [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23], ...
    [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23], ...
    [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23], ...
    [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23], ...
    [14 17 20 23], [14 17 20 23], [14 17 20 23], [14 17 20 23] ...
    };

% Create main BIDS folder
if ~exist(bids_dir, 'dir')
    mkdir(bids_dir)
end

% BIDS object
% -----------

% Bids variables
bids_vars = [];
bids_vars.src_dir_fMRI = src_dir_fMRI;
bids_vars.bids_dir = bids_dir;
bids_vars.bids_rn = bids_rn;
bids_vars.num_subs = length(subj_dirs_fMRI);
bids_vars.subj_dir_fMRI = subj_dirs_fMRI;
bids_vars.redo_conversion = redo_conversion;

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
    if redo_conversion || ~exist(fullfile(bids_dir, sprintf('sub-%02d', i)), 'dir')
        bids.bids_conv_part();
    else
        fprintf('Skipping subject %d (already converted)\n', i);
    end

end

% Add group-level supplementary information
% -----------------------------------------

bids.bids_suppl();
