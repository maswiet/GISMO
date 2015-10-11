classdef Trace < TraceData
   % Trace is the new waveform
   
   properties(Dependent)
      network % network code
      station % station code
      location % location code
      channel % channel code
      start % start time (text)
      sampletimes
   end
   
   properties
      history = {'created', now}; % history for Trace {'what', when}
      UserData = struct(); % structure containing user-defined fields
   end
   
   properties(Hidden)
      mat_starttime % start time in matlab-time
      channelInfo % channelTag
                    %struct that mirrors UserData, but contains two fields:
                    %   allowed_type: a class name (or empty). If this
                    %   exist, then when data is assigned to UserData, it
                    %   will be type-checked.
                    %   min_count, max_count: if empty,any sized array can be
                    %   assigned to this field.  If a single number, then
                    %   eac assignment must have exactly this number of values.
                    %   if [min max], then any number of values between min
      UserDataRules %   and max inclusive may be assigned to this.
   end
   
   methods
      function obj = Trace(varargin)
         obj@TraceData(varargin{:});
         switch nargin
            case 1
               if isa(varargin{1}, 'waveform')
                  obj.channelInfo = get(varargin{1},'channeltag');
                  obj.mat_starttime = get(varargin{1}, 'start');
                  obj.history = get(varargin{1},'history');
                  miscFields = get(varargin{1},'misc_fields');
                  for n = 1: numel(miscFields)
                     obj.UserData.(miscFields{n})= get(varargin{1},miscFields{n});
                  end
               end
         end %switch
      end
      
      function N = get.network(obj)
         N = obj.channelInfo.network;
      end
      
      function S = get.station(obj)
         S = obj.channelInfo.station;
      end
      
      function L = get.location(obj)
         L = obj.channelInfo.location;
      end
      
      function C = get.channel(obj)
         C = obj.channelInfo.channel;
      end
      
      function T = get.start(obj)
         T = datestr(obj.mat_starttime,'yyyy-mm-dd HH:MM:SS.FFF');
      end
      
 
      function val = get.sampletimes(obj)
         assert(numel(obj) == 1, 'only works on one at a time');
         sampPerSec = obj.samplefreq;
         matstep = datenum(0,0,0,0,0, 1 / sampPerSec);
         val = (0:(numel(obj.data)-1)) .* matstep + obj.mat_starttime;
         val = val(:);
      end
      
      function obj = align(obj, alignTime, newFrequency, method)
         error('unimplemented function');
      end
      
      %% Handling User-defined fields
      %TODO: Guarentee or document how the userfield things work for
      %multiple trace objects. First thought: They should be performed
      %individually, on a single object
      %
      % waveform/delfield has been replaced by using matlab's rmfield:
      % T.UserData = rmfield(T.UserData, 'fieldToDelete');
      
      % isfield is not implemented because matlab's can be used:
      % isfield(T.UserData,'something');
      
      function T = set.UserData(T, val)
         %sets UserData fields for a trace object
         % T.UserData.myfield = value;
         %
         % to impose constraings on the values that this field can
         % retrieve, use: Trace.SetUserDataRule(myfield,...)
         %
         % to delete the field:
         % T.UserData = rmfield(T.UserData, 'fieldToRemove');
         % see also Trace.SetUserDataRule, rmfield
         fn = fieldnames(val);
         for f = 1:numel(fn);
            testUserField(T, fn{f}, val.(fn{f}))
         end
         T.UserData = val;
      end
      
      function testUserField(obj, fn, value)
         if ~isfield(obj.UserDataRules,fn) 
            return;
         end
         if ~isfield(obj.UserData,fn)
            if exist('value','var')
               % continue on
            else
               return
            end
         end
         rules = obj.UserDataRules.(fn);
         if ~rules.inUse
            return
         end
         if ~exist('value','var')
           value = obj.UserData.(fn);
         end
         % test the type
         if ~isempty(rules.allowed_type) && ...
               ~isa(value, rules.allowed_type)
            error('User-defined field [%s] requires input of class [%s], but value was a [%s]',...
               fn, rules.allowed_type, class(value));
         end
         % test the number of items
         if ~isempty(rules.min_count) && numel(value) < rules.min_count
            error('User-defined field [%s]: Size of value [%d] is too small. Min allowed size is %d',...
               fn, numel(value), rules.min_count);
         end
         if ~isempty(rules.max_count) && numel(value) > rules.max_count
            error('User-defined field [%s]: Size of value [%d] is too big. Max allowed size is %d',...
               fn, numel(value), rules.max_count);
         end
         % test the value (only works for numeric types)
         if ~isempty(rules.min_value) && value < rules.min_value
            error('User-defined field [%s]: Assigned value [%f] is too small. Min allowed is %f',...
               fn, value, rules.min_value);
         end
         if ~isempty(rules.max_value) && value >rules.max_value
            error('User-defined field [%s]: Assigned value [%f] is too big. Max allowed is %f',...
               fn, value, rules.max_value);
         end
      end
      
      function T = setUserDataRule(T, fieldname, allowedType, allowedCount, allowedRange) 
         % setUserDataRule creates rules that govern setting various userdata fields.
         % T = T.setUserData(fieldname, classname) will have the class
         % checked each time a value is assigned to the UserData
         % field T.UserData.fieldname.
         %
         % T = T.setUserDataRule(fieldname, classname, count) controls the
         % array size for any assignments to T.UserData.fieldname.  count
         % may be a single number N or a range [nMin nMax]
         % for any value assigned to T.UserData.fieldname,
         %    numel(value) == N or Nmin <= numel(value) <= Nmax
         %
         % T = T.setUserDataRule(fieldname, classname, count, range)
         % for numeric classes, range will specify the min/max values. 
         %
         % T = T.setUserDataRule(fieldname) will clear the constraints.
         % examples:
         % T = T.setUserDataRule('height','double',1, [0 inf]); will ensure
         % that height will always be a scalar positive double
         % ...setUserDataRule('code','char',[1 4]) will ensure that any
         % assignments to T.UserData.code will be a string between 1 and 4
         % characters in length.
         %
         assert(ischar(fieldname))
         if ~exist('allowedType', 'var')
            T.UserDataRules.(fieldname).inUse = false;
            return
         else
            T.UserDataRules.(fieldname).inUse = true;
         end
         %add the rules to UserDataRules
         if ischar(allowedType) || isempty(allowedType)
            T.UserDataRules.(fieldname).allowed_type = allowedType;
         else
            error('AllowedType must be a class name or empty');
         end
         
         if ~exist('allowedCount', 'var')
            allowedCount = [];
         end
         if isnumeric(allowedCount)
            switch numel(allowedCount)
               case 0
                  T.UserDataRules.(fieldname).min_count = -inf;
                  T.UserDataRules.(fieldname).max_count = inf;
               case 1
                  T.UserDataRules.(fieldname).min_count = allowedCount;
                  T.UserDataRules.(fieldname).max_count = allowedCount;
               case 2
                  T.UserDataRules.(fieldname).min_count = allowedCount(1);
                  T.UserDataRules.(fieldname).max_count = allowedCount(2);
               otherwise
                  error('allowedCount must be either empty, or numeric with 1 or 2 values');
            end
         else
            error('allowedCount must be either empty, or numeric with 1 or 2 values');
         end
         
         if ~exist('allowedRange', 'var') || strcmp(allowedType,'char') 
            allowedRange = [];
         end
         if isnumeric(allowedRange)
            switch numel(allowedRange)
               case 0
                  T.UserDataRules.(fieldname).min_value = [];
                  T.UserDataRules.(fieldname).max_value = [];
               case 2
                  T.UserDataRules.(fieldname).min_value = allowedRange(1);
                  T.UserDataRules.(fieldname).max_value = allowedRange(2);
               otherwise
                  error('allowedRange must be either empty, or [min max]');
            end
         else
            error('allowedRange must be either empty, or [min max]');
         end
      end
      
      %%
      %function stack
      %function binstack
      %function combine
      %function extract
      %function gettimerange
      %function ismember
      %function isvertical (?) don't like this.
      
      %function calib_apply
      %function calib_remove
      
      %function plot
      %function legend
      %function linkedplot
      
         
      %function addhistory
      %function clearhistory
      %function history
      
      function varargout = plot(T, varargin)
         %PLOT plots a waveform object
         %   h = plot(waveform)
         %   Plots a waveform object, handling the title and axis labeling.  The
         %      output parameter h is optional.  If u, thto the waveform
         %   plots will be returned.  These can be used to change properties of the
         %   plotted waveforms.
         %
         %   h = plot(waveform, ...)
         %   Plots a waveform object, passing additional parameters to matlab's PLOT
         %   routine.
         %
         %   h = plot(waveform, 'xunit', xvalue, ...)
         %   sets the xunit property of the graph, which is used to determine how
         %   the times of the waveform are interpereted.  Possible values for XVALUE
         %   are 's', 'm', 'h', 'd', 'doy', 'date'.
         %
         %        'seconds' - seconds
         %        'minutes' - minutes
         %        'hours' - hours
         %        'day_of_year' - day of year
         %        'date' - full date
         %
         %   for multiple waveforms, specifying XUNITs of 's', 'm', and 'h' will
         %   cause all the waveforms to be plotted starting at 0.  An XUNIT of
         %   'date' will force all waveforms to plot starting at their starttimes.
         %
         %   the default XUNIT is seconds
         %
         %  For the following examples:
         %  % W is a waveform, and W2 is a smaller waveform (from within W)
         %  W = waveform('SSLN','SHZ','04/02/2005 01:00:00', '04/02/2005 01:10:00');
         %  W2 = extract(W,'date','04/02/2005 01:06:10','04/02/2005 01:06:33');
         %
         % EXAMPLE 1:
         %   % This example plots the waveforms at their absolute times...
         %   plot(W,'xunit','date'); % plots the waveform in blue
         %   hold on;
         %   h = plot(W2,'xunit','date', 'r', 'linewidth', 1);
         %          %plots your other waveform in red, and with a wider line
         %
         % EXAMPLE 2:
         %   % This example plots the waveforms, starting at time 0
         %   plot(W); % plots the waveform in blue with seconds on the x axis
         %   hold on;
         %   plot(W2,'xunit','s', 'color', [.5 .5 .5]);  % plots your other
         %                                       % waveform, starting in unison
         %                                       % with the prev waveform, then
         %                                       % change the color of the new
         %                                       % plot to grey (RGB)
         %
         %  For a list of properties you can set (such as color, linestyle, etc...)
         %  type get(h) after plotting something.
         %
         %  also, now Y can be autoscaled with the property pair: 'autoscale',true
         %  although it only works for single waveforms...
         %
         %  see also DATETICK, WAVEFORM/EXTRACT, PLOT
         
         % AUTHOR: Celso Reyes, Geophysical Institute, Univ. of Alaska Fairbanks
         %
         % modified 11/17/2008 by Jason Amundson (amundson@gi.alaska.edu) to allow
         % for "day of year" flag
         %
         % 11/25/2008 changed how parameters are parsed, fixing a bug where you
         % could not specify both an Xunit and a plot-style ('.', for example)
         %
         % individual frequencies used instead of assumed to be equal
         
         
         if isscalar(T),
            yunit = T.units;
         else
            yunit = arrayfun(@(tr) tr.units, T, 'UniformOutput',false); %
         end
         
         %Look for an odd number of arguments beyond the first.  If there are an odd
         %number, then it is expected that the first argument is the formatting
         %string.
         [formString, proplist] = getformatstring(varargin);
         hasExtraArg = ~isempty(formString);
         [isfound, useAutoscale, proplist] = getproperty('autoscale',proplist,false);
         [isfound, xunit, proplist] = getproperty('xunit',proplist,'s');
         [isfound, currFontSize, proplist] = getproperty('fontsize',proplist,8);
         
         [xunit, xfactor] = parse_xunit(xunit);
         
         switch lower(xunit)
            case 'date'
               % we need the actual times...
               for n=1:numel(T)
                  tv(n) = {T(n).sampletimes};
               end
               % preAllocate Xvalues
               tvl = zeros(size(tv));
               for n=1:numel(tv)
                  tvl(n) = numel(tv{n}); %tvl : TimeVectorLength
               end
               
               Xvalues = nan(max(tvl),numel(T)); %fill empties with NaN (no plot)
               
               for n=1:numel(tv)
                  Xvalues(1:tvl(n),n) = tv{n};
               end
               
               
            case 'day of year'
               startvec = datevec(get(T,'start'));
               dec31 = datenum([startvec(1)-1,12,31,0,0,0]); % 12/31/xxxx of previous year in Matlab format
               startdoy = datenum(get(T,'start')) - dec31;
               
               dl = zeros(size(T));
               for n=1:numel(T)
                  dl(n) = get(T(n),'data_length'); %dl : DataLength
               end
               
               Xvalues = nan(max(dl),numel(T));
               
               freqs = get(T,'freq');
               for n=1:numel(T)
                  Xvalues(1:dl(n),n) = (1:dl(n))./ freqs(n) ./ ...
                     xfactor + startdoy(n) - 1./freqs(n)./xfactor;
               end
               
            otherwise,
               longest = max(arrayfun(@(tr) numel(tr.data), T));
               Xvalues = nan(longest, numel(T));
               for n=1:numel(T)
                  dl = numel(T(n).data);
                  Xvalues(1:dl,n) = (1:dl) ./ T(n).samplefreq ./ xfactor;
               end
         end
         
         if hasExtraArg
            varargin = [varargin(1),property2varargin(proplist)];
         else
            varargin = property2varargin(proplist);
         end
         % %
         
         h = plot(Xvalues, double(T,'nan') , varargin{:} );
         
         if useAutoscale
            yunit = autoscale(h, yunit);
         end
         
         yh = ylabel(yunit,'fontsize',currFontSize);
         
         xh = xlabel(xunit,'fontsize',currFontSize);
         switch lower(xunit)
            case 'date'
               datetick('keepticks','keeplimits');
         end
         if isscalar(T)
            th = title(sprintf('%s (%s) - starting %s',...
               T.station, T.channel, T.start),'interpreter','none');
         else
            th = title(sprintf('Multiple waves.  wave(1) = %s (%s) - starting %s',...
               T(1).station, T(1).channel, T(1).start),'interpreter','none');
         end;
         
         
         
         set(th,'fontsize',currFontSize);
         set(gca,'fontsize',currFontSize);
         %% return the graphics handles if desired
         if nargout >= 1,
            varargout(1) = {h};
         end
         
         % return additional information in a structure: when varargout ==2
         plothandles.title = th;
         plothandles.xunits = xh;
         plothandles.yunits = yh;
         if nargout ==2,
            varargout(2) = {plothandles};
         end
         
         function [isfound, foundvalue, properties] = getproperty(desiredproperty,properties,defaultvalue)
            %GETPROPERTY returns a property value from a property list, or a default
            %  value if none is available
            %[isfound, foundvalue, properties] =
            %      getproperty(desiredproperty,properties,defaultvalue)
            %
            % returns a property value (if found) from a property list, removing that
            % property pair from the list.  only removes the first encountered property
            % name.
            
            pmask = strcmpi(desiredproperty,properties.name);
            isfound = any(pmask);
            if isfound
               foundlist = find(pmask);
               foundidx = foundlist(1);
               foundvalue = properties.val{foundidx};
               properties.name(foundidx) = [];
               properties.val(foundidx) = [];
            else
               if exist('defaultvalue','var')
                  foundvalue = defaultvalue;
               else
                  foundvalue = [];
               end
               % do nothing to properties...
            end
         end
         
         function [formString, proplist] = getformatstring(arglist)
            hasExtraArg = mod(numel(arglist),2);
            if hasExtraArg
               proplist =  parseargs(arglist(2:end));
            formString = arglist{1};
            else
               proplist =  parseargs(arglist);
               formString = '';
            end
         end
         
         function c = property2varargin(properties)
            %PROPERTY2VARARGIN makes a cell array from properties
            %  c = property2varargin(properties)
            % properties is a structure with fields "name" and "val"
            c = {};
            c(1:2:numel(properties.name)*2) = properties.name;
            c(2:2:numel(properties.name)*2) = properties.val;
         end
         function [properties] = parseargs(arglist)
            % PARSEARGS creates a structure of parameternames and values from arglist
            %  [properties] = parseargs(arglist)
            % parse the incoming arguments, returning a cell with each parameter name
            % as well as a cell for each parameter value pair.  parseargs will also
            % doublecheck to ensure that all pnames are actually strings... otherwise,
            % there will be a mis-parse.
            %check to make sure these are name-value pairs
            %
            % see also waveform/private/getproperty, waveform/private/property2varargin
            
            argcount = numel(arglist);
            evenArgumentCount = mod(argcount,2) == 0;
            if ~evenArgumentCount
               error('Waveform:parseargs:propertyMismatch',...
                  'Odd number of arguments means that these arguments cannot be parameter name-value pairs');
            end
            
            %assign these to output variables
            properties.name = arglist(1:2:argcount);
            properties.val = arglist(2:2:argcount);
            
            for i=1:numel(properties.name)
               if ~ischar(properties.name{i})
                  error('Waveform:parseargs:invalidPropertyName',...
                     'All property names must be strings.');
               end
            end
         end
         function [unitName, secondMultiplier] = parse_xunit(unitName)
            % PARSE_XUNIT returns a labelname and a multiplier for an incoming xunit
            % value.  This routine was removed to centralize this function
            % [unitName, secondMultiplier] = parse_xunit(unitName)
            secsPerMinute = 60;
            secsPerHour = 3600;
            secsPerDay = 3600*24;
            
            switch lower(unitName)
               case {'m','minutes'}
                  unitName = 'Minutes';
                  secondMultiplier = secsPerMinute;
               case {'h','hours'}
                  unitName = 'Hours';
                  secondMultiplier = secsPerHour;
               case {'d','days'}
                  unitName = 'Days';
                  secondMultiplier = secsPerDay;
               case {'doy','day_of_year'}
                  unitName = 'Day of Year';
                  secondMultiplier = secsPerDay;
               case 'date',
                  unitName = 'Date';
                  secondMultiplier = nan; %inconsequential!
               case {'s','seconds'}
                  unitName = 'Seconds';
                  secondMultiplier = 1;
                  
               otherwise,
                  unitName = 'Seconds';
                  secondMultiplier = 1;
            end
         end
      end %plot
      
   end
end
