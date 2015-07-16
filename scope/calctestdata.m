load('testdataUnknown.mat');


[open, short, match] = calcZ132(900e6);
[S11, S12, S22] = calcErrorBoxM(xopen, xshort, xmatch, open, short, match);

Gl = calcGl(S11,S12,S22,x);
Z = 50 * (1+Gl)/(1-Gl);
fprintf('G = %.2f j%.2f; Z = %.2f j%.2f\n', real(Gl), imag(Gl), real(Z), imag(Z));
