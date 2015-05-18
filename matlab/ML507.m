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
    end
    
    methods
        function obj = ML507(address, port)
            if nargin < 2
                port = 8000;
            end
            if nargin < 1
                address = '192.168.2.2';
            end
            obj.comm = tcpip(address, port, 'InputBufferSize', 49*1024*2*2, 'OutputBufferSize', 49*1024*2*2, 'ByteOrder', 'b');
            fopen(obj.comm);
            obj.gtx = GTX(obj);
            obj.receiver = Receiver(obj);
            obj.average = Average(obj);
            obj.trigger = Trigger(obj);
            obj.core = Core(obj);
            obj.transmitter = Transmitter(obj);
        end
        
        function delete(obj)
            fclose(obj.comm);
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
    end
    
    methods
        function set.depth(obj, value)
            obj.setValue('depth', value);
            obj.average.reset();
        end
        function value = get.depth(obj)
            value = obj.query('depth');
        end
        
        function set.inbuf(obj, value)
            len = obj.depth;
            fprintf(obj.comm, sprintf('write emce0 %d', len*2));
            fwrite(obj.comm, value, 'int16');
            fgetl(obj.comm);
        end
        function value = get.inbuf(obj)
            len = obj.depth;
            fprintf(obj.comm, sprintf('read emce0 %d', len*2));
            value = fread(obj.comm, len, 'int16');
        end
    end
    
end

