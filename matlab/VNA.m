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
            set(obj.handle,'Timeout', 30);
            fopen(obj.handle);
            
            tracename = sprintf('S%d%d', port, port);
            
            fprintf(obj.handle, 'SOUR:POW -10');
            fprintf(obj.handle, 'CALC:PAR:DEL:ALL');
            fprintf(obj.handle, 'CALC:PAR:DEF:EXT ''reflection'', ''%s''', tracename);
            fprintf(obj.handle, 'CALC:PAR:SEL ''reflection''');
            fprintf(obj.handle, 'DISP:WIND:TRAC:FEED ''reflection''');
            fprintf(obj.handle, 'TRIG:SOUR MAN');
        end
        
        function delete(obj)
            fclose(obj.handle);
            delete(obj.handle);
        end
        
        function continuous(obj, steps, time)
            fprintf(obj.handle, 'SENS:SWE:POIN %d', steps);
            fprintf(obj.handle, 'SENS:SWE:GEN ANAL');
            fprintf(obj.handle, 'SENS:FOM:RANG:SWE:TYPE CW');
            fprintf(obj.handle, 'SENS:SWE:TIME %g', time);
        end
        
        function linear(obj, start, stop, steps, wait)
            fprintf(obj.handle, 'SENS:SWE:TYPE LIN');
            fprintf(obj.handle, 'SENS:FREQ:STAR %g', start);
            fprintf(obj.handle, 'SENS:FREQ:STOP %g', stop);
            fprintf(obj.handle, 'SENS:SWE:POIN %d', steps);
            fprintf(obj.handle, 'SENS:SWE:GEN STEP');
            fprintf(obj.handle, 'SENS:SWE:DWEL %g', wait);
            fprintf(obj.handle, 'SENS:SWE:TIME:AUTO 1');
        end
        
        function set.freq(obj, value)
            fprintf(obj.handle, 'SENS:FOM:RANG:FREQ:CW %g', value);
        end
        
        function value = get.freq(obj)
            value = query(obj.handle, 'SENS:FOM:RANG:FREQ:CW?');
        end
        
        function value = get.y(obj)
            fprintf(obj.handle, 'INIT:IMM; *OPC?');
            fgets(obj.handle);
            value = cell2mat(textscan(query(obj.handle, 'CALC:DATA? SDATA'), '%f %f', 'Delimiter', ','));
            value = value(:,1) + 1i*value(:,2);
        end
    end
    
end

