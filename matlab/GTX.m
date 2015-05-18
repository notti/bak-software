classdef GTX < handle
    properties (Access = protected, Hidden = true)
        ml;
        id;
    end
    
    properties (Dependent)
        enable;
        polarity;
        descramble;
        rxeqmix;
        data_valid;
    end
    
    methods
        function obj = GTX(ml)
            if nargin ~= 0
                obj(2) = GTX;
                for i = 1:2
                    obj(i).id = sprintf('gtx%d', i-1);
                    obj(i).ml = ml;
                end
            end
        end
        
        function value = get.data_valid(obj)
            value = obj.ml.query(strcat(obj.id, '/data_valid'));
        end
        
        function value = get.enable(obj)
            value = obj.ml.query(strcat(obj.id, '/enable'));
        end
        function set.enable(obj, value)
            obj.ml.setValue(strcat(obj.id, '/enable'), value);
        end
       
        function value = get.polarity(obj)
            value = obj.ml.query(strcat(obj.id, '/polarity'));
        end
        function set.polarity(obj, value)
            obj.ml.setValue(strcat(obj.id, '/polarity'), value);
        end
        
        function value = get.descramble(obj)
            value = obj.ml.query(strcat(obj.id, '/descramble'));
        end
        function set.descramble(obj, value)
            obj.ml.setValue(strcat(obj.id, '/descramble'), value);
        end
        
        function value = get.rxeqmix(obj)
            value = obj.ml.query(strcat(obj.id, '/rxeqmix'));
        end
        function set.rxeqmix(obj, value)
            obj.ml.setValue(strcat(obj.id, '/rxeqmix'), value);
        end
    end
    
end

