
oszi = Scope('TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR', 2, 1);
smbv = SMBV('TCPIP0::128.131.85.233::inst0::INSTR');

%%

%control zvl to do a sweep of half bins

resa = 40e-3;
resb = 40e-3;

freqs = 900e6;

%offset = 60e3;
%num = 101;
%center = 900e6;

%loffset = 2e3;
%N = 31;

%freqs = ((1:num)-floor(num/2)-1)*offset+center;

%xopen = zeros(N, length(freqs));
%xshort = zeros(N, length(freqs));
%xmatch = zeros(N, length(freqs));

fprintf('Connect open ');
pause();

%for i=1:N
%    fprintf('.');
%    smbv.freq = center + (i-1)*loffset;
%    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
%    xopen(i,:) = manyRho(xincrement, a, b, freqs + (i-1)*loffset);
%end

[xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
xopen = manyRho(xincrement, a, b, freqs);

fprintf('\nConnect short');
pause();

%for i=1:N
%    fprintf('.');
%    smbv.freq = center + (i-1)*loffset;
%    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
%    xshort(i,:) = manyRho(xincrement, a, b, freqs + (i-1)*loffset);
%end

[xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
xshort = manyRho(xincrement, a, b, freqs);

fprintf('\nConnect match');
pause();
%for i=1:N
%    fprintf('.');
%    smbv.freq = center + (i-1)*loffset;
%    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
%    xmatch(i,:) = manyRho(xincrement, a, b, freqs + (i-1)*loffset);
%end

[xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
xmatch = manyRho(xincrement, a, b, freqs);

fprintf('\n');

%open = zeros(N, length(freqs));
%short = zeros(N, length(freqs));
%match = zeros(N, length(freqs));

%for i=1:N
%    [open(i,:), short(i,:), match(i,:)] = arrayfun(@calcZ132, freqs);
%end

[open, short, match] = arrayfun(@calcZ132, freqs);

[S11, S12, S22] = arrayfun(@calcErrorBoxM, xopen, xshort, xmatch, open, short, match);

%%

while true
    pause();
    %x = zeros(N, length(freqs));
    %for i=1:N
    %    fprintf('.');
    %    smbv.freq = center + (i-1)*loffset;
    %    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
    %    x(i,:) = manyRho(xincrement, a, b, freqs + (i-1)*loffset);
    %end
    
    x = zeros(N, length(freqs));
    smbv.freq = center;
    for i=1:N
        fprintf('.');
        [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
        x(i,:) = manyRho(xincrement, a, b, freqs);
    end
    
    %[xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
    %x(i,:) = manyRho(xincrement, a, b, freqs + (i-1)*loffset);
    
    Gl = arrayfun(@calcGl, S11, S12, S22, x);
    Z = 50 .* (1+Gl)./(1-Gl)
    %fprintf('G = %.2f j%.2f; Z = %.2f j%.2f\n', real(Gl), imag(Gl), real(Z), imag(Z));
    %[mean(abs(20*log10(abs(Gl))-20*log10(abs(Gl_genau)))) mean(abs(angle(Gl)-angle(Gl_genau)))]
    %plot([freqs_0 freqs_5 freqs_10 freqs.'],[20*log10(abs(Gl_0)) 20*log10(abs(Gl_5)) 20*log10(abs(Gl_10)) 20*log10(abs(Gl))]);
end


%%

resa = 40e-3;
resb = 40e-3;

N = 20;

offset = 200e3;
num = 21;
center = 900e6;
freqs = ((1:num)-floor(num/2)-1)*offset+center;
%freqs = [center-60e3 center+60e3];
%freqs = [-600e3 -330e3 -270e3 -120e3 -30e3 30e3 120e3 270e3 330e3 600e3]+center;
freqs = 900e6;

for j=1:11
    freqs = 900e6 + (j-1)*1e3;
    smbv.freq = freqs;
    
    a = zeros(N, 200000);
    b = zeros(N, 200000);
    x = zeros(N, length(freqs));

    for i=1:N
        fprintf('.');
        [xincrement, a(i,:), b(i,:)] = oszi.acquireAB(resa,resb,10e-6);
        x(i,:) = manyRho(xincrement, a(i,:).', b(i,:).', freqs);
    end

    absf=(mean(abs(x))-min(abs(x)))./mean(abs(x));
    anglef=(mean(angle(x))-min(angle(x)));
    [~, m] = max(absf);
    fprintf('\n%g: %g %g\n', freqs, absf(m), anglef(m));
end