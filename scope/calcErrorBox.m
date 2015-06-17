function [ S11, S12, S22 ] = calcErrorBox( xo, xs, xm, Go, Gs, Gm )
    S22 = ((1/xm-Gm/Go*1/xo)*(1-Gs/Go) + (Gs/Go*1/xo-1/xm)*(1-Gm/Go)) / ...
        (Gs*(1/xo-1/xs)*(1-Gm/Go)-Gm*(1/xo-1/xm)*(1-Gs/Go));
    S11 = (1/xm - Gm/Go*1/xo + S22*Gm*(1/xo-1/xm)) / ...
        (1 - Gm/Go);
    S12 = 1/(Go*xo) - S22*1/xo - S11*1/Go + S11*S22;
end

