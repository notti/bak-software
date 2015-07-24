ml507 = ML507.ML507('verbose', true);
vna = VNA('GPIB0::16::INSTR', 3);

%%

center = 900e6;
nfft = 4096;
sample = 100e6;

%%

f = designfilt('lowpassfir','FilterOrder',4096-1,'CutoffFrequency',25e6,'SampleRate',100e6,'Window','hamming');
H = fft(impz(f)).';
H_orig = H;
ml507.H = int16(H.*32767./max([max(real(H)) max(imag(H))]));

ml507.depth = 20000;
ml507.transmitter.mul = 32767;
ml507.transmitter.shift = 4;
ml507.core.n = nfft;
ml507.core.L = 2000;
ml507.core.scale_sch(1:6) = [2 0 0 0 0 0];
ml507.core.scale_schi(1:6) = [2 1 0 0 0 0];
ml507.core.scale_cmul = 2;
ml507.core.iq = 1;
ml507.core.circular = 1;
ml507.transmitter.resync();

%%

if ~ml507.running
    ml507.run();
end

vna.continuous(201, 100e-3);

targets = [-1 1 1i];
freqs = (-12:12)*1e6;

multipliers = zeros(length(freqs), length(targets));

l=2;

fprintf('\n');
tic
for i = 1:length(freqs)
    vna.freq = freqs(i) + center;
    for j = 1:length(targets)
        [~, mul] = findTarget(ml507, targets(j), @()1/mean(vna.y), 0.1, @status);
        multipliers(i,j) = mul;
        done = ((i-1)*length(targets)+j);
        for x=1:l
            fprintf('\b');
        end
        l=fprintf('[%*s] % 2.0f%% X',-numel(multipliers),repmat('.',1,done),done/numel(multipliers)*100);
    end
end

fprintf('\n');
toc
%%

which = 2;

fstep = sample/nfft;

freqs_interp = (-floor(12e6/fstep):floor(12e6/fstep))*fstep;
multinterpa = interp1(freqs, unwrap(angle(multipliers(:,which))), freqs_interp, 'linear');
multinterpm = interp1(freqs, abs(multipliers(:,which)), freqs_interp, 'linear');
multinterp = multinterpm .* exp(1i*multinterpa);

figure(1);
subplot(2,1,1);
cla;
hold on;
plot(freqs,unwrap(angle(multipliers(:,which))),'x');
plot(freqs_interp,unwrap(angle(multinterp)));
subplot(2,1,2);
cla;
hold on;
plot(freqs,abs(multipliers(:,which)),'x');
plot(freqs_interp,abs(multinterp));

multinterp = multinterp./(targets(which)*32767);

zero = floor(length(freqs_interp)/2)+1;

H = fft(impz(f)).';
H(1:zero) = H(1:zero).*multinterp(zero:end);
H(end-zero+2:end) = H(end-zero+2:end).*multinterp(1:zero-1);

figure(2);
subplot(2,1,1);
cla;
plot([unwrap(angle(fftshift(H))).' unwrap(angle(fftshift(H_orig))).'])
subplot(2,1,2);
cla;
plot([abs(fftshift(H)).' abs(fftshift(H_orig)).'])

ml507.H = int16(H.*32767./max([max(real(H)) max(imag(H))]));
ml507.transmitter.mul = 32767;

%%

vna.linear(895e6, 905e6, 11, 0.5);

vals = linspace(-1,1,11);
[valsx, valsy] = meshgrid(vals,vals);
vals = valsx+1i*valsy;

results = zeros([size(vals) 11]);

tic

l = 1;
fprintf('\n ');

for i = 1:size(vals, 1)
    for j = 1:size(vals, 2)
        ml507.transmitter.mul = vals(i, j)*32767;
        results(i, j, :) = vna.y;
        for x=1:l
            fprintf('\b');
        end
        done = ((i-1)*size(vals, 2)+j);
        l=fprintf('[%*s] % 2.0f%%',-floor(numel(vals)/2),repmat('.',1,floor(done/2)),done/numel(vals)*100);
    end
end

fprintf('\n');

toc

figure;
smithchart(reshape(results(:,:,:),[size(results,1)*size(results,2) size(results,3)]).');