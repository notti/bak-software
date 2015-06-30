function x = calcX( S11, S12, S22, Gl )
    x = 1/(S11 + (Gl*S12)/(1-Gl*S22));
end

