classdef Receiver < handle
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        valid;
        input;
    end
    
    methods
        function obj = Receiver(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            obj.ml.do('receiver/rst');
        end
        
        function value = get.valid(obj)
            value = obj.ml.query('receiver/stream_valid');
        end
        
        function value = get.input(obj)
            value = obj.ml.query('receiver/input_select');
        end
        function set.input(obj, value)
            obj.ml.setValue('receiver/input_select', value);
        end
    end
    
end

