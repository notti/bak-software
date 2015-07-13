classdef Transmitter < handle
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    properties (Dependent)
        mul;
        dc_balance;
        sat;
        ovfl;
        shift;
    end
    
    methods
        function obj = Transmitter(ml)
            obj.ml = ml;
        end
        
        function reset(obj)
            obj.ml.do('transmitter/rst');
        end
        
        function toggle(obj)
            obj.ml.do('transmitter/toggle');
            fgetl(obj.ml.comm);
        end

        function resync(obj)
            obj.ml.do('transmitter/resync');
        end

        function deskew(obj)
            obj.ml.do('transmitter/deskew');
        end
        
        function value = get.ovfl(obj)
            value = obj.ml.query('transmitter/ovfl');
        end
        
        function value = get.mul(obj)
            value = obj.ml.query('transmitter/muli') + 1i*obj.ml.query('transmitter/mulq');
        end
        function set.mul(obj, value)
            obj.ml.setValue('transmitter/muli', real(value));
            obj.ml.setValue('transmitter/mulq', imag(value));
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

