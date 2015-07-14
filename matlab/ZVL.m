classdef ZVL
    properties (Access = protected, Hidden = true)
        handle
    end
    
    methods
        function obj = ZVL(address)
           obj.handle = visa('agilent', address);
           set(obj.handle,'InputBufferSize', 1e7);
           set(obj.handle,'Timeout', 10);
           fopen(obj.handle);
            
           fprintf(obj.handle, 'SYST:DISP:UPD ON');
        end
        
        function freerun(obj)
            fprintf(obj.handle, 'TRIG:SOUR IMM');
        end
         
        function single(obj)
            fprintf(obj.handle, 'TRIG:SOUR EXT');
        end
         
        function delete(obj)
            fclose(obj.handle);
            delete(obj.handle);
        end
    end
    
end

