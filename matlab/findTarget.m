function [ Gl, mul ] = findTarget( ml507, target, Gl_fun, p, mul)
    if target == 0
        if nargin < 5
            mul = 0;
        end
        diff = 0;
    else
        if nargin < 5
            mul = 32767;
        end
        diff = 1;
    end
    
    while true
        if target == 0
            mul = mul + diff*32767;
            ml507.transmitter.mul = mul;
        else
            mul = mul * exp(1i*angle(diff)) * abs(diff);
            ml507.transmitter.mul = mul;
        end
        
        pause(p);

        Gl = 1/Gl_fun();
        if target == 0
            diff = Gl;
        else
            diff = target/Gl;
        end
        
        if (target == 0 && abs(diff) < 0.001) || ...
           (abs(abs(diff) - 1) < 0.001 && abs(angle(diff)/pi*180) < 0.25)
            break
        end
    end
end

