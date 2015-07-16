function Gl = calcGl( S11, S12, S22, x )
    Gl = (S11 - 1/x)/(S11*S22-S22*1/x-S12);
end

