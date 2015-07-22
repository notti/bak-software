classdef Core < handle
    % Core Class for handling Core stuff
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        scale_sch;
        scale_schi;
        scale_cmul;
        L;
        n;
        iq;
        circular;
    end
    
    properties (Dependent, SetAccess = private)
        ov_fft;
        ov_ifft;
        ov_cmul;        
    end
    
    methods
        function obj = Core(ml)
            obj.ml = ml;
        end
        
        function varargout = run(obj)
            % RUN  Execute convolution
            %   error = RUN returns 0 if successful
            %   [fft, ifft, cmul] = RUN returns 0 if fft, ifft and cmul were successful
            obj.ml.do('core/start');
            if nargout == 1
                varargout{1} = obj.ov_fft + obj.ov_ifft + obj.ov_cmul;
            elseif nargout == 3
                varargout{1} = obj.ov_fft;
                varargout{2} = obj.ov_ifft;
                varargout{3} = obj.ov_cmul;
            elseif nargout ~= 0
                error('invalid syntax');
            end
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
        
        function value = get.scale_cmul(obj)
            value = obj.ml.query('core/scale_cmul');
        end
        function set.scale_cmul(obj, value)
            obj.ml.setValue('core/scale_cmul', value);
        end
    end
    
end

