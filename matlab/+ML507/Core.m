classdef Core < handle
    % Core   Handles the convolute functionality of the fpga.
    % Never use directly. Use ML507.core instead!
    %
    % Core Properties:
    %   scale_sch - fft scaling schedule
    %   scale_schi - ifft scaling schedule
    %   scale_cmul - cmul scaling
    %   L - L for overlap add
    %   n - (i)fft length
    %   iq - iq demodulation
    %   circular - circular convolution
    %   ov_fft - fft overflow status
    %   ov_ifft - ifft overflow status
    %   ov_cmul - cmul overflow status
    %
    % Core Methods:
    %   reset - Reset core module
    %   run - Execute convolution
    %
    % See also ML507
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (SetAccess = immutable)
        % SCALE_SCH - fft scaling schedule
        %   Scaling for the six fft stages. Every stage can be scaled by 0,
        %   1 or 2 bit. The different stages can be accessed with indexing.
        scale_sch;
        % SCALE_SCHi - ifft scaling schedule
        %   Scaling for the six ifft stages. Every stage can be scaled by 0,
        %   1 or 2 bit. The different stages can be accessed with indexing.
        scale_schi;
    end
    
    properties (Dependent)
        % SCALE_CMUL - cmul scaling schedule
        %   Scaling for the cmul operation. Can be 1-4 Bit.
        scale_cmul;
        % L - L for overlap add
        %   Needs to be smaller than fft length!
        L;
        % N - (i)fft length
        %   fft length. Can be 8, 16, 32, 64, 128, 256, 512, 1024, 2048,
        %   4096.
        n;
        % IQ - iq demodulation
        %   1 for enabling iq demodulation.
        iq;
        % CIRCULAR - circular convolution
        %   1 ... circular convolution
        %   0 ... linear convolution
        circular;
    end
    
    properties (Dependent, SetAccess = private)
        % OV_FFT - fft overflow status
        % Gets set after every run
        % See also RUN
        ov_fft;
        % OV_IFFT - ifft overflow status
        % Gets set after every run
        % See also RUN
        ov_ifft;
        % OV_CMUL - cmul overflow status
        % Gets set after every run
        % See also RUN
        ov_cmul;        
    end
    
    methods
        function obj = Core(ml)
            obj.ml = ml;
            obj.scale_sch = ML507.Schedule(ml, 'core/scale_sch');
            obj.scale_schi = ML507.Schedule(ml, 'core/scale_schi');
        end
        
        function delete(obj)
            delete(obj.scale_sch);
            delete(obj.scale_schi);
        end
        
        function varargout = run(obj)
            % RUN  Execute convolution
            %   error = RUN() returns 0 if successful
            %   [fft, ifft, cmul] = RUN() returns more detailed status for fft, ifft and cmul.
            %       Those values are 0 in case of success.
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
            % RESET     Resets the core module
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
            value = obj.ml.query('core/circular');
        end
        function set.circular(obj, value)
            obj.ml.setValue('core/circular', value);
        end
        
        function value = get.scale_cmul(obj)
            value = obj.ml.query('core/scale_cmul');
        end
        function set.scale_cmul(obj, value)
            obj.ml.setValue('core/scale_cmul', value);
        end
    end
end