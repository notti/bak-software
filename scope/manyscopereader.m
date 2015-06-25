
oszi = Scope('TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR', 2, 1);

%%

resa = 40e-3;
resb = 40e-3;

offset = 60e3;
num = 101;
center = 900e6;

freqs = ((1:num)-floor(num/2)-1)*offset+center;
%freqs = 900e6;

fprintf('Connect open\n');
pause();
[xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
xopen = manyRho(xincrement, a, b, freqs);
fprintf('Connect short\n');
pause();
[xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
xshort = manyRho(xincrement, a, b, freqs);
fprintf('Connect match\n');
pause();
[xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
xmatch = manyRho(xincrement, a, b, freqs);


[open, short, match] = arrayfun(@calcZ132, freqs);
[S11, S12, S22] = arrayfun(@calcErrorBoxM, xopen, xshort, xmatch, open.', short.', match.');

%%

while true
    pause();
    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
    x = manyRho(xincrement, a, b, freqs);
    Gl = arrayfun(@calcGl, S11, S12, S22, x);
    Gl
    Z = 50 .* (1+Gl)./(1-Gl)
    %fprintf('G = %.2f j%.2f; Z = %.2f j%.2f\n', real(Gl), imag(Gl), real(Z), imag(Z));
end
