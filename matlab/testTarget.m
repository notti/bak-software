ml507 = ML507();
oszi = Scope('TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR', 2, 1);
smbv = SMBV('TCPIP0::128.131.85.233::inst0::INSTR');
%trig = ZVLTrigger('ASRL1::INSTR');
%zvl = ZVL('TCPIP0::128.131.85.229::inst0::INSTR');

%%

ml507.depth = 10000;
ml507.transmitter.resync();
ml507.out_inactive = ones(1, 20000)*32767 + ones(1, 20000)*32767i;
ml507.transmitter.toggle();
ml507.transmitter.mul = 32767;
ml507.transmitter.shift = 2;
%%

f = designfilt('lowpassfir','FilterOrder',4096-1,'CutoffFrequency',25e6,'SampleRate',100e6,'Window','hamming');
H = fft(impz(f)).';
ml507.H = int16(H.*32767./max([max(real(H)) max(imag(H))]));

%%

center = 900e6;

resa = 80e-3;
resb = 80e-3;

freqs = center;

N = 20;

xopen = zeros(20, length(freqs));
xshort = zeros(20, length(freqs));
xmatch = zeros(20, length(freqs));

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

%%

xopen = mean(xopen);
xshort = mean(xshort);
xmatch = mean(xmatch);

[open, short, match] = arrayfun(@(x) calcZ132(x, 'male'), freqs);

[S11, S12, S22] = arrayfun(@calcErrorBoxM, xopen, xshort, xmatch, open, short, match);

%%

oszi.trigger_chan = 1;

resa = 50e-3;
resb = 50e-3;

freqs = 900e6;

target = 0.5*exp(1i*30/180*pi);
%target = 0;

%zvl.freerun();
%zvl.single();
%ml507.run();
ml507.transmitter.mul = 32767;

diff = 1;
tic
while true
    mul = ml507.transmitter.mul * exp(1i*angle(diff)) * abs(diff);
    ml507.transmitter.mul = mul;
    fprintf('mul = %.2f<%.2f;\n', abs(mul), angle(mul)/pi*180);
%    pause(1);

    
    [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
    x = manyRho(xincrement, a, b, freqs);

    Gl = 1/calcGl(S11, S12, S22, x);
    diff = target/Gl;
    fprintf('VNA Gl = %.2f<%.2f; diff = %.2f<%.2f; ', abs(Gl), angle(Gl)/pi*180, abs(diff), angle(diff)/pi*180);
    if (abs(abs(diff) - 1) < 0.01) && (angle(diff) < 1)
        fprintf('\n');
        Gl
        break
    end
    %Z = 50 .* (1+Gl)./(1-Gl)
    %fprintf('G = %.2f j%.2f; Z = %.2f j%.2f\n', real(Gl), imag(Gl), real(Z), imag(Z));
    %[mean(abs(20*log10(abs(Gl))-20*log10(abs(Gl_genau)))) mean(abs(angle(Gl)-angle(Gl_genau)))]
    %plot([freqs_0 freqs_5 freqs_10 freqs.'],[20*log10(abs(Gl_0)) 20*log10(abs(Gl_5)) 20*log10(abs(Gl_10)) 20*log10(abs(Gl))]);
    
    %fprintf(trig.handle, '*TRG;*WAI;*TRG;*WAI;');
end
toc
%%

delete(ml507);
delete(oszi);
delete(smbv);