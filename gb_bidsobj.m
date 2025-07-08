classdef gb_bidsobj
    % GB_BIDSOBJ Gabor-bandit BIDS conversion class definition file
    %   This class contains properties and methods to convert the fMRI raw data
    %   into BIDS format.
    
    properties
        src_dir_fMRI;  % fMRI source directory
        subj_dir_fMRI;  % Participant specific data location
        bids_dir;  % Bids directory
        s;  % Participant number
        run;  % Current run
        num_subs;  % Number of subjects
        bids_rn;  % Readme: Todo: nochmal checken wofür genau
    end
    
    methods
        
        function bidsobj = gb_bidsobj(init)
            % GB_BIDSOBJ Gabor-bandit BIDS object
            %   This function creates a task object of class gb_taskobj based
            %   on the initialization input structure.
            
            % Set variable task properties based on input structure
            bidsobj.src_dir_fMRI = init.src_dir_fMRI;
            bidsobj.bids_dir = init.bids_dir;
            bidsobj.num_subs = init.num_subs;
            bidsobj.bids_rn = init.bids_rn;
            
            % Initialize other properties
            bidsobj.s = nan; 
            bidsobj.subj_dir_fMRI = nan; 
            bidsobj.run = nan;            
        end
        
        function bidsobj = bids_conv_part(bidsobj)
            % BIDS_CONV  Bids conversion 
            %   This function converts the raw fMRI data of a single
            %   subject to BIDS format.
            
            % Create participant directory in the main BIDS folder
            % ----------------------------------------------------
            
            % Define index su for correct filename specification
            if bidsobj.s <10
                su = strcat(num2str(0),num2str(bidsobj.s));
            else
                su = num2str(bidsobj.s);
            end

            % Create directory
            subj_bids = fullfile(bidsobj.bids_dir, ['sub-', num2str(su)]);
            mkdir(subj_bids);

            % T1 data conversion

            % T1 source directory
            t1_src = fullfile(bidsobj.src_dir_fMRI, bidsobj.subj_dir_fMRI, 'DICOM', 'T1w_MPR_1mm_27_MR');

            % check if T1 data available
            if exist(t1_src, 'dir')

                % create anatomy directory
                t1_bids = [subj_bids, filesep 'anat' filesep];
                mkdir(t1_bids);

                % convert dicom to nifti using the dicm2nii package
                dicm2nii(t1_src, t1_bids)

                % rename NIFTI
                movefile(fullfile(t1_bids, 'T1w_MPR_1mm.nii.gz'), fullfile(t1_bids, [['sub-',su], '_T1w.nii.gz']));

                % create *T1w.json file
                % ---------------------------------------------------------------------

                % load header data
                metadata = load(fullfile(t1_bids, 'dcmHeaders.mat'));
                metadata = metadata.h.T1w_MPR_1mm;

                % convert units: date, elapsed time
                [bidsobj, metadata_un] = conv_unit(bidsobj, metadata);

                % remove/correct fields with identifiers
                [bidsobj, metadata_nid] = rem_ident(bidsobj, metadata_un);

                % save *T1w.json file
                savejson('',metadata_nid, fullfile(t1_bids, [['sub-',su] '_T1w.json']));
                delete(fullfile(t1_bids, 'dcmHeaders.mat'))

                % inform user
                fprintf(['saving *T1w.json file ' ['sub-',su] '\n'])

                % clear variables
                clearvars metadata metadata_un metadata_nid

            end
            
            % EPI data conversion
            % -------------------
            
            % Create functional directory
            epi_bids = [subj_bids, filesep 'func' filesep];
            mkdir(epi_bids)
            
            % Cycle over runs
            for r = [14 17 20 23];

                % EPI source directory
                epi_src = fullfile(bidsobj.src_dir_fMRI, bidsobj.subj_dir_fMRI, 'DICOM', ['ep2d_func_task-Predator_dir-AP_bold_', num2str(r), '_MR']);

                % Convert dicom to nifti using the dicm2nii package
                dicm2nii(epi_src, epi_bids);

                % Rename NIFTI
                movefile(fullfile(epi_bids, 'ep2d_func_task_Predator_dir_AP_bold.nii.gz'), fullfile(epi_bids, [['sub-', su] '_Predator_run-0' num2str(r) '_bold.nii.gz']));
                
                % Create *bold.json file
                % ----------------------
                
                % Load header data
                metadata = load(fullfile(epi_bids, 'dcmHeaders.mat'));
                fn = 'ep2d_func_task_Predator_dir_AP_bold'; % Extract the filename without the extension
                metadata = metadata.h.(fn);
                %%% Needed for correct slice time for spm. From dicm2nii
                spm_sec = ((0.5 - metadata.SliceTiming) * metadata.RepetitionTime) / 1000;
                [~, spm_order] = sort(-metadata.SliceTiming);
                metadata.SliceTiming = spm_sec;
                metadata.SliceOrder = spm_order;

                % Convert units: date, elapsed time
                [bidsobj, metadata_un] = conv_unit(bidsobj, metadata);

                % Remove/correct fields with identifiers
                [bidsobj, metadata_nid] = rem_ident(bidsobj, metadata_un);

                % Add missing fields
                [bidsobj, metadata_comp] = add_fields(bidsobj, metadata_nid);

                % save *bold.json file
                savejson('',metadata_comp, fullfile(epi_bids, [['sub-',su] '_Predaotr_run-0' num2str(r) '_bold.json']));
                delete(fullfile(epi_bids, 'dcmHeaders.mat'))
                
                % Inform user
                fprintf(['saving *bold.json file ' ['sub-',su] [' run-', num2str(r)] '\n'])
                
                % Clear variables
                clearvars metadata metadata_un metadata_nid metadata_comp epi_src
                
            end
            
        end
        
        function [bidsobj, metadata_un] = conv_unit(bidsobj, metadata_orig)
            % CONV_UNIT Conversion of units
            %   This function converts the dates and elapsed time into formats required
            %   by BIDS:
            %       - Date and time: YYYY-MM-DDThh:mm:ss
            %       - Elapsed time:  ms to seconds
            %
            % Inputs
            %       metadata_orig: original metadata as created by dicm2nii, input
            %                      structure with fields
            %
            % Outputs
            %       metadata_un: unit corrected metadata, input structure with fields
            
            % Convert date and time
            % ---------------------
            
            YYYY = metadata_orig.AcquisitionDateTime(1:4);
            MM = metadata_orig.AcquisitionDateTime(5:6);
            DD = metadata_orig.AcquisitionDateTime(7:8);
            hh = metadata_orig.AcquisitionDateTime(9:10);
            mm = metadata_orig.AcquisitionDateTime(11:12);
            ss = metadata_orig.AcquisitionDateTime(13:14);
            
            fields_dates_mod = {'StudyDate'
                'SeriesDate'
                'ContentDate'
                'InstanceCreationDate'
                'CSAImageHeaderVersion'
                'CSASeriesHeaderVersion'
                'PerformedProcedureStepStartDate'
                'AcquisitionDateTime'};
            
            for dm = 1:numel(fields_dates_mod)
                if dm == numel(fields_dates_mod)
                    metadata_orig.(fields_dates_mod{dm}) = strcat(YYYY,'-',MM,'-',DD,'T',hh,':',mm,':',ss);
                else
                    metadata_orig.(fields_dates_mod{dm}) = strcat(YYYY,'-',MM,'-',DD);
                end
            end
            
            % Convert ms to seconds
            metadata_orig.RepetitionTime = metadata_orig.RepetitionTime/1000;
            metadata_orig.EchoTime = metadata_orig.EchoTime/1000;
            if isfield (metadata_orig, 'InversionTime')
                metadata_orig.InversionTime = metadata_orig.InversionTime/1000;         
            end
            
            % Return unit-corrected metadata
            metadata_un = metadata_orig;
            
        end
        
        function [bidsobj, metadata_nid] = rem_ident(bidsobj, metadata_un)
            % REM_IDENT Remove fields with identifiers
            %   This function removes all fields with identifiers (for the
            %   treasure hunt task this includes the string 'schatz') and replaces the
            %   year in those fields that contain the date of data collection (for the
            %   treasure hunt task this corresponds to 2014).
            %
            % Inputs
            %       metadata_un: unit corrected metadata
            %
            % Outputs
            %       metadata_id: metadata without identifiers
            %
            % Copyright (C) Lilla Horvath, Dirk Ostwald
            % -------------------------------------------------------------------------
            
            % TODO: checken was auf uns überhaupt zutrifft!!!
            
            % get names of structure fields
            all_fields_0 = fieldnames(metadata_un);
            
            % cycle over fields of the metadata
            for mf_0 = 1:length(all_fields_0)
                
                % remove id on the first field level
                if ischar(metadata_un.(all_fields_0{mf_0}))
                    
                    if ~isempty(regexpi(metadata_un.(all_fields_0{mf_0}),'2014','match'))
                        metadata_un.(all_fields_0{mf_0}) = regexprep(metadata_un.(all_fields_0{mf_0}),'2014','1900');
                    end
                    
                    if ~isempty(regexpi(metadata_un.(all_fields_0{mf_0}),'schatz','match'))
                        metadata_un = rmfield(metadata_un, all_fields_0{mf_0});
                    end
                    
                    % remove id on the second field level
                elseif isstruct(metadata_un.(all_fields_0{mf_0}))
                    
                    all_fields_1 = fieldnames(metadata_un.(all_fields_0{mf_0}));
                    
                    for mf_1 = 1:length(all_fields_1)
                        
                        if ischar(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}))
                            
                            if ~isempty(regexpi(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}),'2014','match'))
                                metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}) = regexprep(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}),'2014','1900');
                            end
                            
                            if ~isempty(regexpi(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}),'schatz','match'))
                                metadata_un.(all_fields_0{mf_0}) = rmfield(metadata_un.(all_fields_0{mf_0}), all_fields_1{mf_1});
                            end
                            
                            % remove id on the third field level
                        elseif isstruct(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}))
                            
                            all_fields_2 = fieldnames(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}));
                            
                            for mf_2 = 1:length(all_fields_2)
                                if ischar(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}).(all_fields_2{mf_2}))
                                    
                                    if ~isempty(regexpi(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}).(all_fields_2{mf_2}),'2014','match'))
                                        metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}).(all_fields_2{mf_2}) = regexprep(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}).(all_fields_2{mf_2}),'2014','1900');
                                    end
                                    
                                    if ~isempty(regexpi(metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}).(all_fields_2{mf_2}),'schatz','match'))
                                        metadata_un.(all_fields_0{mf_0}).(all_fields_1{mf_1}) = rmfield(metadata_un.(all_fields_0{mf_0}).all_fields_1{mf_1}, all_fields_2{mf_2});
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            % remove additional identifiers and redundant information
            rf = {'PatientBirthDate', 'AcquisitionDateTime'};
            metadata_un = rmfield(metadata_un, rf);
            
            % return metadata without identifiers
            metadata_nid = metadata_un;
            
        end
        
        function [bidsobj, metadata_comp] = add_fields(bidsobj, metadata_nid)
            % ADD_FIELDS Add missing information to metadata
            %   This function adds important missing fields to the metadata.
            %
            %   Inputs
            %       metadata_nid:  metadata without identifiers
            %
            %   Outputs
            %       metadata_comp: complemented metadata
            
            % Hier auch checken, was wir brauchen!
            metadata_nid.NumberOfVolumesDiscardedByScanner = 0;
            metadata_nid.NumberOfVolumesDiscardedByUser = 3;
            metadata_nid.TaskName = 'gb';
            metadata_nid.TaskDescription = 'Gabor-Bandit';
            
            % Return complemented metadata
            metadata_comp = metadata_nid;
        end
        
        function bidsobj = bids_suppl(bidsobj)
            % BIDS_SUPPL Add supplementary information 
            %   This function adds supplementary information to the
            %   dataset.
            %
    
            % Copy stimulus directory 
            % -----------------------
            % copy the directory containing the visual stimuli image files to the
            % group-level BIDS folder
            
            % copyfile(stim_source, fullfile(bids_dir, 'stimuli'))
            
            % Create participants.tsv file 
            % ----------------------------
            
            % Initialize participant data array
            participants = cell(bidsobj.num_subs, 4);

            for i = 1:bidsobj.num_subs
                if i<10
                    participants(i,1) = {['sub-0' num2str(i)]};
                else
                    participants(i,1) = {['sub-' num2str(i)]};
                end
            end
            
            % Add age
            %participants(:,2) = num2cell([24, 29, 22, 24, 25, 26, 29, 25, 30, 29, 30, 23, 29, 29, 30, 26, 26, 26, 33]);
            participants(:,2) = num2cell([24]);
            
            % Add sex
            %participants(:,3) = [{'Female'}; {'Male'}; {'Female'}; {'Female'}; {'Female'}; {'Male'}; {'Male'}; {'Female'}; {'Female'}; {'Female'}; {'Male'}; {'Male'}; {'Male'}; {'Female'}; {'Male'}; {'Male'}; {'Female'}; {'Female'}; {'Male'}];
            participants(:,3) = [{'Female'}];
            
            % Add reported handedness
            %participants(:,4) = [{'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}; {'Both, Left preference'}; {'Right'}; {'Right'}; {'Right'}; {'Right'}];
            participants(:,4) = [{'Right'}];
            
            % Convert participants cell array to table format
            participants_t = cell2table(participants, 'VariableNames', {'participant_id', 'age', 'sex', 'handedness'});
            
            % Events.csv and .tsv filenames
            participants_csv = fullfile(bidsobj.bids_dir, 'participants.csv');
            participants_tsv = fullfile(bidsobj.bids_dir, 'participants.tsv');
            
            % Save
            writetable(participants_t, participants_csv, 'Delimiter', '\t');            
            copyfile(participants_csv, participants_tsv);                              
            delete(participants_csv);                         
            
            % 3 Create dataset_description.json file 
            % --------------------------------------
            
            % Initialize dataset descriptor array
            metadata_dataset = [];
            
            % Add fields
            metadata_dataset.Name             = 'Gabor-Bandit: behavioral, anatomical and functional MRI data set';
            % metadata_dataset.BIDSVersion      = '1.1.1';
            % metadata_dataset.License      = ask Dirk!
            metadata_dataset.Authors          = 'Rasmus Bruckner, Felix Molter, Hauke R. Heekeren, Dirk Ostwald';
            metadata_dataset.HowToAcknowledge = 'Please cite this paper if you use the dataset: https.XXX'; 
            % metadata_dataset.Funding      = ask Dirk!
            % metadata_dataset.DatasetDOI    = add when available
            
            % Save as .json file
            savejson('', metadata_dataset, fullfile(bidsobj.bids_dir, 'dataset_description.json'));
            
            % -------------------------- (4) add README file --------------------------
            % add the dataset README file that specifies further details of the dataset
            % (.md file created outside the Matlab environment)
            
            % copyfile(fullfile(stim_source, '..', '..', bids_rn), fullfile(bids_dir, 'README.md'))
            
        end
    end
    
end

