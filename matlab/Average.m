classdef Average < handle
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        active;
        width;
    end
    
    properties (Dependent, SetAccess = private)
        err;
    end
    
    methods
        function obj = Average(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            obj.ml.do('average/rst');
        end
        
        function value = get.active(obj)
            value = obj.ml.query('average/active');
        end
        
        function value = get.width(obj)
            value = obj.ml.query('average/width');
        end
        function set.width(obj, value)
            obj.ml.setValue('average/width', value);
        end
        
        function value = get.err(obj)
            value = obj.ml.query('average/err');
        end
    end
    
end

