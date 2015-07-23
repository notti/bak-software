function [ Gl, mul ] = findTarget( ml507, target, Gl_fun, p, status )
    if target == 0
        mul = 0;
        diff = 0;
    else
        mul = 32767;
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
        
        status();
        
        if (target == 0 && abs(diff) < 0.001) || ...
           (abs(abs(diff) - 1) < 0.001 && abs(angle(diff)/pi*180) < 0.25)
            break
        end
    end
end

