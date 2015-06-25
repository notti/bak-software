
oszi = Scope('TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR', 2, 1);

%%

resa = 40e-3;
resb = 40e-3;

fprintf('Connect open\n');
pause();
[xopen, aopen, bopen] = oszi.acquire(resa,resb,10e-6);
fprintf('Connect short\n');
pause();
[xshort, ashort, bshort] = oszi.acquire(resa,resb,10e-6);
fprintf('Connect match\n');
pause();
[xmatch, amatch, bmatch] = oszi.acquire(resa,resb,10e-6);


[open, short, match] = calcZ132(900e6);
[S11, S12, S22] = calcErrorBoxM(xopen, xshort, xmatch, open, short, match);

%%

while true
    pause();
    [x, a, b] = oszi.acquireRho(resa,resb,10e-6);
    Gl = calcGl(S11,S12,S22,x);
    Z = 50 * (1+Gl)/(1-Gl);
    fprintf('G = %.2f j%.2f; Z = %.2f j%.2f\n', real(Gl), imag(Gl), real(Z), imag(Z));
end
