classdef VNA < handle
    properties% (Access = protected, Hidden = true)
        handle
    end
    
    properties (Dependent)
        freq;
        y;
    end
    
    methods
        function obj = VNA(address, port)
            obj.handle = visa('agilent', address);
            set(obj.handle,'InputBufferSize', 1e7);
            set(obj.handle,'Timeout', 10);
            fopen(obj.handle);
            
            tracename = sprintf('S%d%d', port, port);
            
            fprintf(obj.handle, 'SOUR:POW -10');
            fprintf(obj.handle, 'SENS:FOM:RANG:SWE:TYPE CW');
            fprintf(obj.handle, 'CALC:PAR:DEL:ALL');
            fprintf(obj.handle, 'CALC:PAR:DEF:EXT ''reflection'', ''%s''', tracename);
            fprintf(obj.handle, 'CALC:PAR:SEL ''reflection''');
            fprintf(obj.handle, 'DISP:WIND:TRAC:FEED ''reflection''');
        end
        
        function delete(obj)
            fclose(obj.handle);
            delete(obj.handle);
        end
        
        function set.freq(obj, value)
            fprintf(obj.handle, 'SENS:FOM:RANG:FREQ:CW %g', value);
        end
        
        function value = get.freq(obj)
            value = query(obj.handle, 'SENS:FOM:RANG:FREQ:CW?');
        end
        
        function value = get.y(obj)
            value = mean(cell2mat(textscan(query(obj.handle, 'CALC:DATA? SDATA'), '%f %f', 'Delimiter', ',')));
            value = value(1) + 1i*value(2);
        end
    end
    
end

