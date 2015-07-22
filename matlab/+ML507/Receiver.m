classdef Receiver < handle
    % Receiver   Handles the receiver of the fpga.
    % Never use directly. Use ML507.receiver instead!
    %
    % Receiver Properties:
    %   valid - selected input has valid data
    %   input - input select
    %
    % Receiver Methods:
    %   reset - Reset receiver module
    %
    % See also ML507
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        % INPUT - input select
        % Switching inputs also resets the transmitter.
        % 0 ... GTX0 (SATA 1)
        % 1 ... GTX1 (SATA 2)
        input;
    end
    
    properties (Dependent, SetAccess = private)
        % VALID     selected input has valid data
        valid;
    end
    
    methods
        function obj = Receiver(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            % RESET     Resets the receiver module
            % Warning: This resets EVERY receiver and therefor invalidates
            % the datastream. This also causes a reset for the transmitter.
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