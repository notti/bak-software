classdef Core < handle
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        %scale missing
        L;
        n;
        iq;
        circular;
        ov_fft;
        ov_ifft;
        ov_cmul;
    end
    
    methods
        function obj = Core(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            obj.ml.do('core/rst');
        end
        
        function value = get.ov_fft(obj)
            value = obj.ml.query('core/ov_fft');
        end

        function value = get.ov_ifft(obj)
            value = obj.ml.query('core/ov_ifft');
        end

        function value = get.ov_cmul(obj)
            value = obj.ml.query('core/ov_cmul');
        end
        
        function value = get.L(obj)
            value = obj.ml.query('core/L');
        end
        function set.L(obj, value)
            obj.ml.setValue('core/L', value);
        end
        
        function value = get.n(obj)
            value = obj.ml.query('core/n');
        end
        function set.n(obj, value)
            obj.ml.setValue('core/n', value);
        end
        
        function value = get.iq(obj)
            value = obj.ml.query('core/iq');
        end
        function set.iq(obj, value)
            obj.ml.setValue('core/iq', value);
        end
        
        function value = get.circular(obj)
            value = obj.ml.query('core/L');
        end
        function set.circular(obj, value)
            obj.ml.setValue('core/L', value);
        end
    end
    
end

