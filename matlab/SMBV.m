classdef SMBV < handle
    properties (Access = protected, Hidden = true)
        handle
    end
    
    properties (Dependent)
        freq;
        pow;
        rf;
    end
    
    methods
        function obj = SMBV(address)
            obj.handle = visa('agilent', address);
            set(obj.handle,'InputBufferSize', 1e7);
            set(obj.handle,'Timeout', 10);
            fopen(obj.handle);
        end
        function delete(obj)
            fclose(obj.handle);
            delete(obj.handle);
        end
    end
    
    methods
        function set.freq(obj, value)
            fprintf(obj.handle, ':FREQ %f', value);
        end
        function value = get.freq(obj)
            value = str2double(query(obj.handle, ':FREQ?'));
        end

        function set.pow(obj, value)
            fprintf(obj.handle, ':POW %f', value);
        end
        function value = get.pow(obj)
            value = str2double(query(obj.handle, ':POW?'));
        end

        function set.rf(obj, value)
            if value
                value = 'ON';
            else
                value = 'OFF';
            end
            fprintf(obj.handle, ':OUTP %s', value);
        end
        function value = get.rf(obj)
            value = str2double(query(obj.handle, ':OUTP?'));
        end

    end
end

