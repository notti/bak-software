classdef Trigger < handle
    % Trigger   Handles the trigger functionality of the fpga.
    % Never use directly. Use ML507.trigger instead!
    %
    % Trigger Properties:
    %   type - Trigger type
    %
    % Trigger Methods:
    %   reset - Reset trigger module
    %   arm - Arm the trigger
    %   fire - Fire the manual trigger
    %
    % See also ML507
  
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        % TYPE  trigger type
        % 'int' ... internal (manual) trigger
        % 'ext' ... external trigger
        type;
    end
    
    methods
        function obj = Trigger(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            % RESET     Resets the trigger module
            obj.ml.do('trigger/rst');
        end
        
        function arm(obj)
            % ARM   Arm the trigger
            % This does not wait for trigger firing.
            %
            % See also FIRE.
            obj.ml.do('trigger/arm');
        end

        function fire(obj)
            % FIRE  Fire the manual trigger
            % 
            % See also ARM.
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