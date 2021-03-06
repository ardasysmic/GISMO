function eev(obj, eventnum)
    % CATALOG.EEV - Browse an Catalog object one event at a time.
    %  catalogObject.EEV() Browse through an Catalog object one event
    %  at a time in a similar way to the Seisan program 'eev'.

    if ~exist('eventnum','var')
        eventnum = 1;
    end

    while 1,

        % don't beyond start or end of this catalogObject object
        if eventnum<1
            eventnum=1;
        end
        if eventnum>numel(obj.otime)
            eventnum=numel(obj.otime);
        end           
        % display line for this event
        dstr=datestr(obj.otime(eventnum),31);
        subclass=obj.etype{eventnum};
        mag=obj.mag(eventnum);
        outstr=sprintf('%s %7.2f %7.2f %7.2 %5.1f %s %s',dstr, obj.lon(eventnum), obj.lat(eventnum), obj.depth(eventnum), mag, obj.magtype{eventnum}, subclass);
        choice=input([outstr,':  ?'],'s');           

        % process choice
        if isempty(choice)
            eventnum=eventnum+1; % ENTER goes to next event 

        elseif (choice(1)=='c') % CLASSIFY
            classify_event(datenum);
% ^^ does this line need obj.otime?

        elseif (choice(1)=='f') % FORWARD N EVENTS
            num=1;
            if length(choice)>1
                num=str2num(choice(2:end));
            end
            eventnum=eventnum+num; 

        elseif (choice(1)=='b') % BACKWARD N EVENTS
            num=1;
            if length(choice)>1
                num=str2num(choice(2:end));
            end
            eventnum=eventnum-num;

        elseif (choice(1)=='t') % JUMP TO TIME
            month=1;dd=1;hr=0;
            if length(choice)>4
                year=str2num(choice(2:5));
            end
            if length(choice)>6
                month=str2num(choice(6:7));
            end
            if length(choice)>8
                dd=str2num(choice(8:9));
            end
            if length(choice)>10
                hr=str2num(choice(10:11));
            end
            jumptime=datenum(year,month,dd,hr,0,0);
            eventnum = min(find(obj.otime >= jumptime));

        elseif (choice(1)=='s') % SUMMARISE - SHOW S FILE or similar data 
            fprintf('\nTime:\t\t%s\n',dstr);
            fprintf('Longitude:\t%7.2f degrees\n',obj.lon(eventnum));
            fprintf('Latitude:\t%7.2f degrees\n',obj.lat(eventnum));
            fprintf('Depth:\t\t%7.2f km\n',obj.depth(eventnum));
            fprintf('Magnitude:\t%7.2f\n',obj.mag(eventnum));
            fprintf('Magnitude Type:\t%s\n',obj.magtype{eventnum});
            fprintf('Event Type:\t%s\n',obj.etype{eventnum});
            fprintf('\n');

        elseif (choice(1)=='x') % CLOSE ALL
            close all;

        elseif (choice=='q') % QUIT
            break;

        elseif (choice(1)=='h') % HELP
            disp(' ');
            disp('Options:');
            disp('________');
            disp(' ');
            disp('b[num]            - go backward 1 event (or N events)');
            disp('c                 - classify');
            %disp('e                 - edit/generate S-file');
            disp('f[num]            - go forward 1 event (or N events)');
            disp('h                 - this help');
            %disp('p                 - plot');
            disp('s                 - summarise');
            disp('tYYYY[MM[DD[HH]]] - jump to date/hour specified');
            disp('x                 - close all figure windows');
            disp('q                 - quit');
            disp(' ');
        end
    end
end  
