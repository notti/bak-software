function [open, short, match] = calcZ132(f, type)
    Z0 = 50;
    w = 2*pi*f;
    c = 299792458;
    lambda = c/f;
    beta = 2*pi/lambda;

    match = (50-Z0)/(50+Z0);

    C = 50e-15 + (f/1e9) * 0.15e-15 - (f/1e9)^2 * 0.008e-15 + (f/1e9)^3 * 0.00036e-15;
    Zopen = 1/(1i*w*C);
    lopen = 8.51e-3;
    Zopen = Z0*(Zopen + 1i*Z0*tan(beta*lopen))/(Z0 + 1i*Zopen*tan(beta*lopen));
    open = (Zopen-Z0)/(Zopen+Z0);
    

    if strcmp(type, 'female')
        L = 8.5e-12;
    else
        L = 14e-12 - (f/1e9)*0.08e-12 + (f/1e9)^2 * 0.003e-12 - (f/1e9)^3 * 0.00002e-12;
    end
    Zshort = 1i*w*L;
    lshort = 9.15e-3;
    Zshort = Z0*(Zshort + 1i*Z0*tan(beta*lshort))/(Z0 + 1i*Zshort*tan(beta*lshort));
    short = (Zshort-Z0)/(Zshort+Z0);
end

