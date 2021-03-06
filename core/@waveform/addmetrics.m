function w = addmetrics(w, maxTimeDiff)
%ADDMETRICS
% addmetrics(w) will compute some amplitude, energy and frequency metrics
% for each waveform in waveform vector w, and add them to the 'metrics'
% structure for that waveform
%
% addmetrics(w, maxTimeDiff) is a slight variation where the max and min
% found will correspond to the maximum peak to peak variation found within
% a maxTimeDiff timewindow. (If not given, the max and min are for the whole
% waveform). Note that maxTimeDiff should be about 1 to a few periods of the 
% signal you are interested in.
%
% TO DO: a more efficient 1 period algorithm could use findpeaks, see
% bottom of the m-file

    SECONDS_PER_DAY = 86400;
    maxTime = -1;
    minTime = -1;
    maxAmp = -1;
    minAmp = -1;
    p2p = -1;
    stdev = -1;
    energy = -1;
    amp = -ones(size(w));
    Nw = numel(w);

    for wavnum=1:Nw
        fprintf('.');
        clear metrics
        
        %thisW = detrend(fillgaps(w(wavnum),'interp')); % make sure there is no trend or offset
        thisW = clean(w(wavnum));
        wstart = get(thisW,'start'); % waveform start time
        wend = get(thisW,'end'); % waveform end time
        wstd = std(thisW); % waveform standard deviation - for noise estimation
        fs = get(thisW,'freq');
        y = get(thisW,'data');
        u = get(thisW,'units');
        
%         %% THIS IS THE START OF AN ATTEMPT TO FIND THE EVENT START AND END TIME BY RUNNING AN STA/LTA
%         close all
%         %plot(thisW)
%         % set the STA/LTA detector
%         sta_seconds = 0.7; % STA time window 0.7 seconds
%         lta_seconds = 10.0; % LTA time window 7 seconds
%         thresh_on = 2.0; % Event triggers "ON" with STA/LTA ratio exceeds 3
%         thresh_off = 1.0; % Event triggers "OFF" when STA/LTA ratio drops below 1.5
%         minimum_event_duration_seconds = 1.0; % Trigger must be on at least 2 secs
%         pre_trigger_seconds = 0; % Do not pad before trigger
%         post_trigger_seconds = 0; % Do not pad after trigger
%         event_detection_params = [sta_seconds lta_seconds thresh_on thresh_off ...
%             minimum_event_duration_seconds];
%         [cobj,sta,lta,sta_to_lta] = Detection.sta_lta(thisW, 'edp', event_detection_params, ...
%             'lta_mode', 'frozen');
% %         h3 = drumplot(thisW, 'mpl', 1, 'catalog', cobj);
% %         plot(h3)
%         input('any key')
%         % Several events may be detected. Need to pick the one at the
%         % expected time, considering the travel time

        
        % WHAT TYPE OF MAXIMUM & MINIMUM DO WE WANT?
        if exist('maxTimeDiff', 'var')
            % compute largest peak to peak amplitude
            % (Note a different algorithm could be added here, using
            % findpeaks)
            metrics.maxTimeDiff = maxTimeDiff;
            
            % Define time window
            numSamples = length(y);
            seconds_end_offset   = (wend   - wstart) * SECONDS_PER_DAY;
            sample_to_end_at   = min( [round( seconds_end_offset   * fs) numSamples]);

            % Loop over subwindows
            % find p2p amplitude in each, compare to highest p2p found so far
            N = round(fs * maxTimeDiff); 

            % COMPUTING AMPLITUDE METRICS
            try
            [vamin, vamax] = running_min_max(y, N);
            vap2p = vamax-vamin; % biggest peak to peak in each timewindow of length N
            [maxap2p, maxap2pindex] = max(vap2p);         
            amin = vamin(maxap2pindex);
            amax = vamax(maxap2pindex);
            amaxindex = find(y==amax);
            aminindex = find(y==amin);
            catch
            [amax, amaxindex] = max(thisW);
            [amin, aminindex] = min(thisW);               
            end
            
        else
            [amax, amaxindex] = max(thisW);
            [amin, aminindex] = min(thisW);
        end
        
        maxSecs = amaxindex/fs;
        minSecs = aminindex/fs;
        maxTime = wstart + maxSecs/SECONDS_PER_DAY;
        minTime = wstart + minSecs/SECONDS_PER_DAY;
        p2p = amax - amin;        
        amp(wavnum) = round(nanmax(abs([amax amin])), 4, 'significant');
        stdev = round(wstd, 4, 'significant'); % stdev of whole trace - noise level estimate
        energy = round(sum(y.^2)/fs, 4, 'significant'); % round to 4 sigfigs

        % ADD ALL METRICS TO THE WAVEFORM OBJECT
        metrics.minTime = minTime;
        metrics.maxTime = maxTime;
        metrics.minAmp = round(amin, 4, 'significant');
        metrics.maxAmp = round(amax, 4, 'significant');
        metrics.stdev = round(stdev, 4, 'significant');
        metrics.energy = round(energy, 4, 'significant');
        metrics.units = u;
        thisW = addfield(thisW, 'metrics', metrics);
        w(wavnum) = thisW;
        
        if mod(wavnum,30) == 0
            fprintf('\nDone %d out of %d\n',wavnum, Nw);
        end

    end
    %fprintf('\n(Complete)\n');
end


function [amin,amax]=running_min_max(y, N)
    startsamp=1;
    for endsamp=1:N
        amax(endsamp) = max(y(startsamp:endsamp));
        amin(endsamp) = min(y(startsamp:endsamp));
    end
    for startsamp=2:length(y)-N+1
        endsamp=startsamp+N-1;
        amax(endsamp) = max(y(startsamp:endsamp));
        amin(endsamp) = min(y(startsamp:endsamp));
    end
end

function [amin, aminindex, amax, amaxindex] = find_biggest_peak2peak(y, N)
% SKELETON: NOT USED
% there are options in findpeaks to ignore small adjacent peaks i should be
% using here but don't
    [pos_pks, pos_locs] = findpeaks(y);
    [neg_pks, neg_locs] = findpeaks(-y);
    % now we just need to look for neg_pks which occur within 
end
