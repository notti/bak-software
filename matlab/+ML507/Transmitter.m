classdef Transmitter < handle
    % Transmitter   Handles the transmitter of the fpga.
    % Never use directly. Use ML507.transmitter instead!
    %
    % Transmitter Properties:
    %   mul - output multiplier
    %   sat - enable saturation of the output multiplier
    %   ovfl - output multiplier overflow
    %   shift - output multiplier shifter
    %   dc_balance - enable dc balance of the transmitter
    %
    % Transmitter Methods:
    %   reset - reset transmitter module
    %   resync - resynchronize transmitter to configured depth
    %   toggle - toggles output buffer
    %   deskew - send deskew sequence
    %
    % See also ML507
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        % MUL - output multiplier
        % Complex valued output multiplier. Value gets converted to int16
        % (-32768 to 32767). Value needs prescaling to achieve full range.
        mul;
        % DC_BALANCE - enable dc balance of the transmitter
        dc_balance;
        % SAT - enable saturation of the output multiplier
        sat;
        % OVFL - output multiplier overflow
        % 1 if an overflow occured. Writing a value resets the overflow
        % status.
        ovfl;
        % SHIFT - output multiplier shifter
        % Output can be shifted between 0 and 15 bits resulting in a 17 -
        % shift bit shift.
        shift;
    end
    
    methods
        function obj = Transmitter(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            % RESET     Resets the transmitter module
            obj.ml.do('transmitter/rst');
        end
        
        function toggle(obj)
            % TOGGLE    toggles output buffer
            % Changes the current active output buffer.
            obj.ml.do('transmitter/toggle');
        end

        function resync(obj)
            % RESYNC    resynchronize transmitter to configured depth
            % Needs to be called after changing depth
            obj.ml.do('transmitter/resync');
        end

        function deskew(obj)
            % DESKEW    send deskew sequence
            obj.ml.do('transmitter/deskew');
        end
        
        function value = get.ovfl(obj)
            value = obj.ml.query('transmitter/ovfl');
        end
        
        function value = get.mul(obj)
            value = obj.ml.query('transmitter/muli') + 1i*obj.ml.query('transmitter/mulq');
        end
        function set.mul(obj, value)
            obj.ml.setValue('transmitter/muli', int16(real(value)));
            obj.ml.setValue('transmitter/mulq', int16(imag(value)));
        end
             
        function value = get.dc_balance(obj)
            value = obj.ml.query('transmitter/dc_balance');
        end
        function set.dc_balance(obj, value)
            obj.ml.setValue('transmitter/dc_balance', value);
        end
                
        function value = get.sat(obj)
            value = obj.ml.query('transmitter/sat');
        end
        function set.sat(obj, value)
            obj.ml.setValue('transmitter/sat', value);
        end
        
        function value = get.shift(obj)
            value = obj.ml.query('transmitter/shift');
        end
        function set.shift(obj, value)
            obj.ml.setValue('transmitter/shift', value);
        end
    end 
end