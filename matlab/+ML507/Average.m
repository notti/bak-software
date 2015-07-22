classdef Average < handle
    % Average   Handles the averaging component of the fpga.
    % Never use directly. Use ML507.average instead!
    %
    % Average Properties:
    %   width - log2 of number of samples for averaging
    %   active - component status
    %   err - error flag of averaging
    %
    % Average Methods:
    %   reset - reset averaging module
    %
    % See also ML507
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        % WIDTH     number of samples for averaging
        % Can be 0 (off), 1, 2, 3
        width;
    end
    
    properties (Dependent, SetAccess = private)
        % ACTIVE    component status
        % 1 while component is active
        active;
        % ERR   error flag of averaging
        % 1 if an error occured during averaging
        err;
    end
    
    methods
        function obj = Average(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            % RESET     Resets the averaging module
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