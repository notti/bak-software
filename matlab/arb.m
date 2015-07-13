ml507 = ML507();
oszi = Scope('TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR', 2, 1);
smbv = SMBV('TCPIP0::128.131.85.233::inst0::INSTR');

%%

fsample  = 100e6;
spacing  = 1e6;
carriers = 3;
fc = (-(carriers-1)/2 : (carriers-1)/2) * spacing;

t = (0 : fsample/spacing-1) / fsample;

crest_limit = 6;
crest = inf;

while crest > crest_limit
    ph = rand(size(fc)) * 2*pi;
    [t_m, ph_m] = meshgrid(t, ph);
    s_orig = sum( exp(1i*(2*pi*diag(fc)*t_m + ph_m)) );
    crest = 20*log10(max(abs(s_orig))/rms(s_orig));
end

fprintf('Crestfactor = %.2fdB\n', crest);

scale = max([max(real(s_orig)) imag(max(s_orig))]);
s = int16(s_orig.*32767./scale);

ml507.depth = length(s);
ml507.transmitter.resync();
ml507.out_inactive = s;
ml507.transmitter.toggle();
ml507.transmitter.mul = 32767;

%%

center = 900e6;

resa = 50e-3;
resb = 50e-3;

freqs = center + fc;

N = 20;

xopen = zeros(N, length(freqs));
xshort = zeros(N, length(freqs));
xmatch = zeros(N, length(freqs));

fprintf('Connect open ');
pause();

for i=1:N
    fprintf('.');
    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
    xopen(i,:) = manyRho(xincrement, a, b, freqs);
end

fprintf('\nConnect short');
pause();

for i=1:N
    fprintf('.');
    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
    xshort(i,:) = manyRho(xincrement, a, b, freqs);
end

fprintf('\nConnect match');
pause();

for i=1:N
    fprintf('.');
    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
    xmatch(i,:) = manyRho(xincrement, a, b, freqs);
end

fprintf('\n');

xopen = mean(xopen);
xshort = mean(xshort);
xmatch = mean(xmatch);

[open, short, match] = arrayfun(@calcZ132, freqs);

[S11, S12, S22] = arrayfun(@calcErrorBoxM, xopen, xshort, xmatch, open, short, match);

%%

while true
    pause();
    
    x = zeros(N, length(freqs));
    for i=1:N
        fprintf('.');
        [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
        x(i,:) = manyRho(xincrement, a, b, freqs);
    end
    
    x = mean(x);

    Gl = arrayfun(@calcGl, S11, S12, S22, x);
    Z = 50 .* (1+Gl)./(1-Gl)
    %fprintf('G = %.2f j%.2f; Z = %.2f j%.2f\n', real(Gl), imag(Gl), real(Z), imag(Z));
    %[mean(abs(20*log10(abs(Gl))-20*log10(abs(Gl_genau)))) mean(abs(angle(Gl)-angle(Gl_genau)))]
    %plot([freqs_0 freqs_5 freqs_10 freqs.'],[20*log10(abs(Gl_0)) 20*log10(abs(Gl_5)) 20*log10(abs(Gl_10)) 20*log10(abs(Gl))]);
end

%%

delete(ml507);
delete(oszi);
delete(smbv);