classdef ML507 < handle
    properties %(Access = protected, Hidden = true)
        comm;
    end
    
    properties
        gtx;
        receiver;
        average;
        trigger;
        core;
        transmitter;
    end
    
    properties (Dependent)
        depth;
        stream_valid;
        input;
        inbuf;
        H;
        out_inactive;
        out_active;
    end
    
    methods
        function obj = ML507(address, port)
            if nargin < 2
                port = 8000;
            end
            if nargin < 1
                address = '192.168.2.2';
            end
            obj.comm = tcpip(address, port, 'InputBufferSize', 49*1024*2*2, 'OutputBufferSize', 49*1024*2*2, 'ByteOrder', 'bigEndian');
            obj.comm.UserData.mode = 1;
            obj.comm.BytesAvailableFcn = @getInterrupts;
            fopen(obj.comm);
            obj.gtx = GTX(obj);
            obj.receiver = Receiver(obj);
            obj.average = Average(obj);
            obj.trigger = Trigger(obj);
            obj.core = Core(obj);
            obj.transmitter = Transmitter(obj);
            
            function getInterrupts(obj, event)
                if obj.BytesAvailable
                    line = fgetl(obj);
                    fprintf('intr %s from device\n', line);
                end
            end
        end
        
        function delete(obj)
            fclose(obj.comm);
            delete(obj.comm);
        end
        
        function error = overlap_add(obj)
            obj.core.run();
            error = obj.core.ov_ifft + obj.core.ov_ifft + obj.core.ov_ifft;
        end
        
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
            fgetl(obj.comm);
        end
        
        function overflow = single(obj)
            overflow = 0;
            fprintf(obj.comm, 'single');
            fgetl(obj.comm);
            status = fgetl(obj.comm);
            if strcmp(status, 'OVERFLOW');
                overflow = 1;
            end
        end
        
        function run(obj)
            fprintf(obj.comm, 'run');
            fgetl(obj.comm);
        end
        
        function overflow = stop(obj)
            overflow = 0;
            fprintf(obj.comm, 'stop');
            fgetl(obj.comm);
            status = fgetl(obj.comm);
            if strcmp(status, 'OVERFLOW');
                overflow = 1;
            end
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
    end
    
end

