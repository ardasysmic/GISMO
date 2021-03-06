function iceweb2017(thissubnet, ds, ChannelTagList, ...
    snum, enum, nummins, products, PARAMS, paths)
    debug.printfunctionstack('>');

    % load state
    statefile = sprintf('iceweb_%s_state.mat',thissubnet);
    if exist(statefile, 'file') && ~strcmp(PARAMS.runmode, 'test')
        load(statefile)
    end

    % end time
    if enum==0
        enum = utnow - delaymins/1440;
    end
    
      
    % loop one day at a time
    for dnum = floor(snum):ceil(enum)
        disp(datestr(dnum))
        
%         % figure out which channeltags are active for this day?            
%         ctags_thisday = get_channeltags_thisday(ds, ctags, dnum); % subset to channeltags valid
%         if isempty(todaysites)
%             continue;
%         end
        
%         % subset to sites for which the files pointed to by the
%         % wfdisc table, actually exist
%         m = listMiniseedFiles(ds, chantag, dnum, dnum+1);
%         ctags_thisday = ctags_thisday([m.exists]==2);
        
        % get timewindow for this day
        timewindows = get_timewindow(min([enum dnum+1]), nummins, max([dnum snum]));

        if ~strcmp(PARAMS.runmode,'test')
            % loop over timewindows
            for count = 1:length(timewindows.start)
                this_timewindow.start = timewindows.start(count);	
                this_timewindow.stop = timewindows.stop(count);	
                iceweb_helper(paths, PARAMS, newsubnets, this_timewindow, ds, products);
            end
        end
    end
    debug.printfunctionstack('<');
end


function iceweb_helper(paths, PARAMS, subnets, tw, ds, products)
    debug.printfunctionstack('>');

    MILLISECOND_IN_DAYS = (1 / 86400000);

    makeSamFiles = false;
    makeSoundFiles = true; 


    snum = tw.start;
    enum = tw.stop - MILLISECOND_IN_DAYS; % try to skip last sample

    % load state
    statefile = sprintf('iceweb_%s_state.mat',subnet);
    if exist(statefile, 'file')
        load(statefile)
        if snum < snum0 
            continue
        end
    end
		
    % save state
    ds0=ds; sites0=sites; snum0=snum; enum0=enum; subnet0 = subnet;
    save(statefile, 'ds0', 'sites0', 'snum0', 'enum0', 'subnet0');
    clear ds0 sites0 snum0 enum0 subnet0
           



    %% Save raw waveform data to 1 hour MAT file
    dv = datevec(snum);
    yyyy = dv(1);
    jjj = floor(snum - datenum(yyyy,1,1) + 1);
    hh = dv(4);
    wavematdir = 'wavemat';
    wavrawmat = sprintf('%s/%s/%04d/%03d/%s.%04d.%03d.%02d.raw.mat',wavematdir,subnet,yyyy,jjj,subnet,yyyy,jjj,hh);
    if ~exist(wavrawmat,'file')
        %% Get waveform data
        debug.print_debug(0, sprintf('%s %s: Getting waveforms for %s from %s to %s at %s',mfilename, datestr(utnow), subnet , datestr(snum), datestr(enum)));
        w = waveform_wrapper(ds, ChannelTagList, snum, enum);
        mkdir(fileparts(wavmatfile));
        disp(sprintf('Saving waveform data to %s',wavrawmat));
        save(wavrawmat);   
    end

    % continue

    % Save the cleaned waveform data to MAT file
    wavcleanmat = sprintf('%s/%s/%04d/%03d/%s.%04d.%03d.%02d.clean.mat',wavematdir,subnet,yyyy,jjj,subnet,yyyy,jjj,hh);
    if ~exist(wavcleanmat,'file')

        % Eliminate empty waveform objects
        w = waveform_remove_empty(w);
        if numel(w)==0
            debug.print_debug(0, 'No waveform data returned - skipping');
            continue
        end

        % Clean the waveforms
        w = fillgaps(w, 'interp');
        w = detrend(w);

        % Apply calibs which should be stored within sites structure to
        % waveform objects to convert from counts to real physical
        % units
        w = apply_calib(w, sites);

        % Pad all waveforms to same start/end
        [wsnum wenum] = gettimerange(w); % assume gaps already filled, signal
        w = pad(w, min([snum wsnum]), max([enum wenum]), 0);

        % Apply filter to all signals
        w = apply_filter(w, PARAMS);

        mkdir(fileparts(wavmatfile));
        disp(sprintf('Saving waveform data to %s',wavcleanmat));
        save(wavcleanmat);   
    end
    
    %% ICEWEB PRODUCTS
    
    % WAVEFORM PLOT
    if products.waveform_plot.doit
        close all
        plot_panels(w)
        [spdir,spbase,spext] = fileparts(spectrogramFilename);
        fname = fullfile('plots', 'waveforms', subnet, sprintf('%s.png',datestr(snum,31)) );
        orient tall;
        saveImageFile(fname, 72); % this should make directory tree too
    end
    
    % RSAM
    if products.rsam.doit
        for measure = products.rsam.measures
            rsamobj = waveform2rsam(w);
            rsamobj.save_to_bob_file(fullfile('data', 'rsam', subnet, 'SSSS.CCC.YYYY.MMMM.bob'));
        end
    end
    
  
    % CREATE & SAVE HELICORDER PLOT
    if products.helicorders.doit 
        close all
        for wi=1:numel(w)
            heliplot = helicorder(w(wi),'mpl',3);
            build(heliplot)
            ct = get(w(wi),'channeltag');
            helicorderFilename = fullfile(spdir, sprintf('heli_%s_%s.%s.%s',spbase,ct.station,ct.channel,spext));
            orient tall;
            saveImageFile(helicorderFilename, 72);
            clear ct helicorderFilename
        end
        clear wi
    end
            

    % PLOT SPECTROGRAMS
    if products.spectrograms.doit
        debug.print_debug(1, sprintf('Creating %s',spectrogramFilename))
        waveSp = w;

		% restrict spectrogram to Z channels only
		w2=[];
		for wi=1:numel(w)
			ct=get(w(wi),'channeltag');
			if strfind(ct.channel,'Z')
				w2 = [w2 w(wi)];
			end
        end
        waveSp = w2;
        
        % split into 10-minute timewindows
        for someloopover10mintimewindows
            % make 10-minute spectrogram
            close all
            spectrogramFraction = 0.75;
            [sgresult, Tcell, Fcell, Ycell] = spectrogram_iceweb(PARAMS.spectralobject, waveSp, spectrogramFraction, extended_spectralobject_colormap);
            clear w2 wi ct
            
            if sgresult > 0 % sgresult = number of waveforms for which a spectrogram was successfully plotted
                % SAVE SPECTROGRAM PLOT TO IMAGE FILE AND CREATE THUMBNAIL
                orient tall;

                if saveImageFile(spectrogramFilename, 72)

                    fileinfo = dir(spectrogramFilename); % getting a weird Index exceeds matrix dimensions error here.
                    debug.print_debug(0, sprintf('%s %s: spectrogram PNG size is %d',mfilename, datestr(utnow), fileinfo.bytes));	

                    % make thumbnails
                    makespectrogramthumbnails(spectrogramFilename, spectrogramFraction);

                end

                % save spectral data
                if products.spectral_data.doit
                    frequency_index_divider = 5.0; % Hz
                    for spi = 1:numel(Fcell)
                        thisY = Ycell{spi};
                        thisF = Fcell{spi};
                        thisT = Tcell{spi};
                        sta = get(w(spi),'station');
                        chan = get(w(spi),'channel');

                        % peakF and meanF for each spectrogram window
                        [Ymax,imax] = max(thisY);
                        PEAK_F = thisF(imax);
                        MEAN_F = (thisF' * thisY)./sum(thisY);

                        % frequency index for each spectrogram window
                        fUpperIndices = find(thisF > frequency_index_divider);
                        fLowerIndices = find(thisF < frequency_index_divider);                    
                        fupper = sum(thisY(fUpperIndices,:));
                        flower = sum(thisY(fLowerIndices,:));
                        F_INDEX = log2(fupper ./ flower);

                        % Peak spectral value in each frequency bin - or in
                        % each minute?

                        % Now downsample to 1 sample per minute
                        dnum = unique(floorminute(thisT));
                        for k=1:length(dnum)
                            p = find(floorminute(thisT) == dnum(k));
                            downsampled_peakf(k) = nanmean(PEAK_F(p));
                            downsampled_meanf(k) = nanmean(MEAN_F(p));  
                            downsampled_findex(k) = nanmean(F_INDEX(p));
                            suby = thisY(:,p);
                            if size(suby,2) == 1
                                            max_in_each_freq_band(:,k) = suby;
                            else
                                            max_in_each_freq_band(:,k) = max(suby');
                            end
                        end

        %                 % Plot for verification
        %                 close all
        %                 subplot(2,1,1),plot(dnum,downsampled_peakf,':');datetick('x');
        %                 hold on
        %                 plot(dnum,downsampled_meanf);datetick('x');
        %                 subplot(2,1,2),plot(dnum,downsampled_findex);datetick('x');
        %                 anykey = input('Press any key to continue');

                        % Save data
                        r1 = rsam(dnum, downsampled_peakf, 'sta', sta, ...
                            'chan', chan, 'measure', 'peakf', ...
                            'units', 'Hz', 'snum', min(dnum), 'enum', max(dnum));
                        r1.save_to_bob_file(fullfile('spectrograms', subnet, 'SSSS.CCC.YYYY.peakf'))

                        r2 = rsam(dnum, downsampled_meanf, 'sta', sta, ...
                            'chan', chan, 'measure', 'meanf', ...
                            'units', 'Hz', 'snum', min(dnum), 'enum', max(dnum));
                        r2.save_to_bob_file(fullfile('spectrograms', subnet, 'SSSS.CCC.YYYY.meanf'))

                        r3 = rsam(dnum, downsampled_findex, 'sta', sta, ...
                            'chan', chan, 'measure', 'findex', ...
                            'units', 'none', 'snum', min(dnum), 'enum', max(dnum));
                        r3.save_to_bob_file(fullfile('spectrograms', subnet, 'SSSS.CCC.YYYY.findex')) 

                        specdatafilename = fullfile('data', 'spectral', subnet, datestr(min(dnum),'yyyy/mm/dd'), sprintf( '%s_%s_%s.mat', datestr(min(dnum),30), sta, chan) );
                        specdatadir = fileparts(specdatafilename); % make the directory in case it does not exist
                        mkdir(specdatadir); % make the directory in case it does not exist
                        save(specdatafilename, 'dnum', 'max_in_each_freq_band') 
                        clear r1 r2 r3 k p   downsampled_peakf downsampled_meanf ...
                            downsampled_findex fUpperIndices fLowerIndices flower ...
                            fupper F_INDEX PEAK_F MEAN_F Ymax imax thisY thisF thisT ...
                            suby max_in_each_freq_band

                    end
                end
            end
        end
    end

    % SOUND FILES
    if products.soundfiles.doit
        try
            % 20120221 Added a "sound file" like 201202211259.sound which simply records order of stachans in waveform object so
            % php script can match spectrogram panel with appropriate wav file 
            % 20121101 GTHO COmment: Could replace use of bnameroot below with strrep, since it is just used to change file extensions
            % e.g. strrep(spectrogramFilename, '.png', sprintf('_%s_%s.wav', sta, chan)) 
            soundfileroot = fullfile('soundfiles', subnet, datestr(get(w(c),'start'),31), 
            [dname, bnameroot, bnameext] = fileparts(soundfileroot);
            soundfilelist = sprintf('%s.sound',soundfileroot);
            fsound = fopen(soundfilelist,'a');
            for c=1:length(w)
                soundfilename = fullfile('soundfiles', sprintf('%s_%s_%s.wav',bnameroot, get(w(c),'station'), get(w(c), 'channel')  ) );
                fprintf(fsound,'%s\n', soundfilename);  
                debug.print_debug(0, sprintf('Writing to %s',soundfilename)); 
                isSuccessful = waveform2sound(w(c), 60, soundfilename)
            end
            fclose(fsound);
        end
    end

    debug.printfunctionstack('<');
end

