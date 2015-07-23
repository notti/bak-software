classdef ML507 < handle
    % ML507   Class to control the fpga.
    %
    % ML507 Properties:
    %   gtx - gtx submodules 1 and 2
    %   receiver - receiver submodule
    %   average - average submodule
    %   trigger - trigger submodule
    %   core - core submodule
    %   transmitter - transmitter submodule
    %   depth - number of samples
    %   inbuf - input buffer
    %   H - filter
    %   out_inactive - inactive output buffer
    %   out_active - active output buffer
    %   running - automatic mode active
    %   verbose - print events to console
    %
    % ML507 Methods:
    %   acquire - arm trigger and wait for average to finish
    %   run - start automatic mode
    %   stop - stop automatic mode
    %   single - do a single acquire, convolute, toggle run
    %   shutdown - shutdown device
    %
    % See also AVERAGE, GTX, TRANSMITTER, RECEIVER, CORE, TRIGGER
    properties (Access = protected, Hidden = true)
        comm;
        comma;
    end
    
    properties
        % VERBOSE   print events to console
        verbose;
    end
    
    properties (SetAccess = immutable)
        gtx;
        receiver;
        average;
        trigger;
        core;
        transmitter;
    end
    
    properties (Dependent)
        % DEPTH      number of samples
        % Needs to be between 1 and floor((49152/core.L))*core.L
        depth;
        % inbuf     input buffer
        % Complex valued input buffer. Can be read and written. Values get
        % converted to int16 (-32768 to 32767). Values need prescaling to
        % achieve full range.
        inbuf;
        % H     filter
        % Complex valued fourier transformed filter. Can be read and
        % written. Values get converted to int16 (-32768 to 32767). Values
        % need prescaling to achieve full range.
        H;
        % OUT_INACTIVE  inactive output buffer
        % Complex valued inactive output buffer. Can be read and written.
        % Values get converted to int16 (-32768 to 32767). Values need
        % prescaling to achieve full range.
        out_inactive;
    end
    
    properties (Dependent, SetAccess = private)
        % OUT_ACTIVE    active output buffer
        % Complex valued active output buffer. Can only be read.
        out_active;
        % RUNNING   automatic mode active
        running;
    end
    
    events
        auto_start;
        auto_stop;
        stream_valid;
        stream_invalid;
        tx_toggled;
        avg_done;
        core_done;
        tx_ovfl;
    end
    
    methods
        function obj = ML507(varargin)
            % ML507     Constructs a handle for communication with the fpga
            p = inputParser;
            % This is kinda dumb address check, but otherwise parse will
            % mistake a parameter name as an address
            validAddress = @(x) ischar(x) && ~isempty(strfind(x, '.'));
            addOptional(p, 'address', '192.168.2.2', validAddress);
            addOptional(p, 'port', 8000, @isnumeric);
            addOptional(p, 'verbose', false, @islogical);
            parse(p, varargin{:});
            obj.verbose = p.Results.verbose;
            obj.comm = tcpip(p.Results.address, p.Results.port, ...
                'InputBufferSize', 49*1024*2*2, ...
                'OutputBufferSize', 49*1024*2*2, 'ByteOrder', 'bigEndian');
            obj.comma = tcpip(p.Results.address, p.Results.port+1);
            obj.comma.BytesAvailableFcn = @(com,event)getInterrupts(obj,com);
            fopen(obj.comm);
            fopen(obj.comma);
            obj.gtx = ML507.GTX(obj);
            obj.receiver = ML507.Receiver(obj);
            obj.average = ML507.Average(obj);
            obj.trigger = ML507.Trigger(obj);
            obj.core = ML507.Core(obj);
            obj.transmitter = ML507.Transmitter(obj);
            function getInterrupts(obj, com)
                line = fgetl(com);
                if obj.verbose
                    fprintf('intr %s from device\n', line);
                end
                try
                    notify(obj, line);
                end
            end
        end
        
        function delete(obj)
            delete(obj.gtx);
            delete(obj.receiver);
            delete(obj.average);
            delete(obj.trigger);
            delete(obj.core);
            delete(obj.transmitter);
            fclose(obj.comma);
            delete(obj.comma);
            fclose(obj.comm);
            delete(obj.comm);
        end
    end
    
    methods (Hidden = true)
        function value = query(obj, which)
            fprintf(obj.comm, 'get %s\n', which);
            value = str2double(fgetl(obj.comm));
        end
        
        function setValue(obj, which, value)
            fprintf(obj.comm, sprintf('set %s %d', which, value));
            fgetl(obj.comm);
        end
        
        function do(obj, which)
            fprintf(obj.comm, sprintf('do %s', which));
            status = fgetl(obj.comm);
            if strcmp(status, 'OK') ~= 1
                me = MException('ML507:Error', 'Failure executing %s (timeout)', which);
                throw(me);
            end
        end
    end
    
    methods
        function acquire(obj)
        % ACQUIRE   arm trigger and wait for average to finish
            obj.do('acquire');
        end

        function run(obj)
        % RUN   start automatic mode
            obj.do('auto/run');
        end
        
        function stop(obj)
        % STOP  stop automatic mode
            obj.do('auto/stop');
        end
        
        function single(obj)
        % SINGLE    do a single acquire, convolute, toggle run
            obj.do('auto/single');
        end
        
        function shutdown(obj)
        % SHUTDOWN  shutdown the device
            fprintf(obj.comm, 'shutdown');
        end
    end
    
    methods
        function set.depth(obj, value)
            obj.setValue('depth', value);
            obj.transmitter.resync();
        end
        function value = get.depth(obj)
            value = obj.query('depth');
        end
        
        function set.inbuf(obj, value)
            len = length(value);
            fprintf(obj.comm, sprintf('write emce0 %d', len*2)); %2B/value
            fwrite(obj.comm, value, 'int16');
            fgetl(obj.comm);
        end
        function value = get.inbuf(obj)
            len = obj.depth;
            fprintf(obj.comm, sprintf('read emce0 %d', len*2)); %2B/value
            value = fread(obj.comm, len, 'int16');
        end
        
        function set.H(obj, value)
            len = length(value);
            fprintf(obj.comm, sprintf('write emce1 %d', len*4)); %2B/value i/q
            fwrite(obj.comm, reshape([imag(value);real(value)],1,[]), 'int16');
            fgetl(obj.comm);
        end
        function value = get.H(obj)
            len = obj.core.n;
            fprintf(obj.comm, sprintf('read emce1 %d', len*4)); %2B/value i/q
            value = fread(obj.comm, [2, len], 'int16');
            value = value(2,:) + value(1,:)*1i;
        end
        
        function set.out_inactive(obj, value)
            len = length(value);
            fprintf(obj.comm, sprintf('write emce2 %d', len*4)); %2B/value i/q
            fwrite(obj.comm, reshape([imag(value);real(value)],1,[]), 'int16');
            fgetl(obj.comm);
        end
        function value = get.out_inactive(obj)
            len = obj.depth;
            fprintf(obj.comm, sprintf('read emce2 %d', len*4)); %2B/value i/q
            value = fread(obj.comm, [2, len], 'int16');
            value = value(2,:) + value(1,:)*1i;
        end
        
        function value = get.out_active(obj)
            len = obj.depth;
            fprintf(obj.comm, sprintf('read emce3 %d', len*4)); %2B/value i/q
            value = fread(obj.comm, [2, len], 'int16');
            value = value(2,:) + value(1,:)*1i;
        end
        
        function value = get.running(obj)
            value = obj.query('auto/run');
        end
    end 
end