classdef Z132
    properties (SetAccess = immutable)
        open;
        short;
        match;
    end
    
    methods
        function obj = Z132(f)
            Z0 = 50;
            w = 2*pi*f;
            c = 300e6;
            lambda = c/f;
            beta = 2*pi/lambda;
            
            obj.match = (50-Z0)/(50+Z0);
            
            C = 50e-15 + f/1e9*0.15e-15 - (f/1e9)^2*0.008e-15 + (f/1e9)^3 * 0.00036e-15;
            Zopen = 1i/(w*C);
            lopen = 8.51e-3;
            Zopen = 50*(Zopen + 1i*50*tan(beta*lopen*2))/(50 * 1i*Zopen*tan(beta*lopen*2));
            obj.open = (Zopen-Z0)/(Zopen+Z0);
            
            L = 8.5e-12;
            Zshort = 1i*w*L;
            lshort = 9.15e-3;
            Zshort = 50*(Zshort + 1i*50*tan(beta*lshort*2))/(50 * 1i*Zshort*tan(beta*lshort*2));
            obj.short = (Zshort-Z0)/(Zshort+Z0);
        end
    end
    
end

