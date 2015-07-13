classdef ZVLTrigger < handle
    properties % (Access = protected, Hidden = true)
        handle
    end
    
    methods
        function obj = ZVLTrigger(address)
            obj.handle = visa('agilent', address);
            fopen(obj.handle);
            
            fprintf(obj.handle, '*CLS');
            fprintf(obj.handle, '*RST');
            fprintf(obj.handle, 'OUTP:LOAD 50');
            fprintf(obj.handle, 'BM:NCYC 1');
            fprintf(obj.handle, 'TRIG:SOUR BUS');
            fprintf(obj.handle, 'BM:STAT ON');
            fprintf(obj.handle, 'FUNC:SHAP SQU');
            fprintf(obj.handle, 'VOLT 3.0');
            fprintf(obj.handle, 'VOLT:OFFS 1.5');
            fprintf(obj.handle, 'FREQ 1.0E+6');
        end
        
        function delete(obj)
            fclose(obj.handle);
            delete(obj.handle);
        end
        
        function trigger(obj)
            fprintf(obj.handle, '*TRG');
        end
        
        function wait(obj)
            fprintf(obj.handle, '*WAI');
        end
    end
    
end

