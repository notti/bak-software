classdef Trigger < handle
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        type;
    end
    
    methods
        function obj = Trigger(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            obj.ml.do('trigger/rst');
        end
        
        function arm(obj)
            obj.ml.do('trigger/arm');
            fgetl(obj.ml.comm);
        end

        function fire(obj)
            obj.ml.do('trigger/fire');
        end
        
        function value = get.type(obj)
            value = obj.ml.query('trigger/type');
            if value == 0
                value = 'int';
            else
                value = 'ext';
            end
        end
        function set.type(obj, value)
            if strcmp(value, 'int')
                value = 0;
            else
                value = 1;
            end
            obj.ml.setValue('trigger/type', value);
        end
    end
    
end

