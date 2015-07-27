ml507 = ML507.ML507('verbose', true);
vna = VNA('GPIB0::16::INSTR', 3);

%%

center = 900e6;
nfft = 4096;
sample = 100e6;

%%

f = designfilt('lowpassfir','FilterOrder',4096-1,'CutoffFrequency',25e6,'SampleRate',100e6,'Window','hamming');
H_orig = fft(impz(f)).';
ml507.H = int16(H_orig.*32767./max([max(real(H_orig)) max(imag(H_orig))]));

ml507.depth = 20000;
ml507.transmitter.mul = 32767;
ml507.transmitter.shift = 5;
ml507.core.n = nfft;
ml507.core.L = 2000;
ml507.core.scale_sch(1:6) = [2 0 0 0 0 0];
ml507.core.scale_schi(1:6) = [2 1 0 0 0 0];
ml507.core.scale_cmul = 1;
ml507.core.iq = 1;
ml507.core.circular = 1;
ml507.transmitter.resync();
ml507.trigger.arm();
ml507.trigger.fire();

%%

if ~ml507.running
    ml507.run();
end

vna.continuous(201, 100e-3);

ml507.H = int16(H_orig.*32767./max([max(real(H_orig)) max(imag(H_orig))]));

targets = [-1 1 1i -1i];
freqs = (-13:13)*1e6;

multipliers = zeros(length(freqs), length(targets));

tic
    for i = 1:length(freqs)
        vna.freq = freqs(i) + center;
        for j = 1:length(targets)
            [~, mul] = findTarget(ml507, targets(j), @()1/mean(vna.y), 0.1);
            multipliers(i,j) = mul./(targets(j)*32767);
            fprintf('%d/%d\n', (i-1)*length(targets)+j, length(freqs)*length(targets));
        end
    end
toc

numtargets = length(targets);

H = zeros(numtargets + numtargets/2, length(H_orig));

for i=1:numtargets
    H(i,:) = modifyFilter(H_orig, freqs, sample, nfft, multipliers(:,i));
end
for i=numtargets+1:(numtargets+numtargets/2)
    H(i,:) = modifyFilter(H_orig, freqs, sample, nfft, mean([multipliers(:,(i-numtargets-1)*2+1) multipliers(:,(i-numtargets-1*2)+2)],2));
end

ml507.transmitter.mul = 32767;

%%

ml507.transmitter.mul = 0;
vna.linear(895e6, 905e6, 11, 0.5);
vna.y;
ml507.transmitter.mul = 32767;

vals = linspace(-1,1,11);
[valsx, valsy] = meshgrid(vals,vals);
vals = valsx+1i*valsy;

results = zeros([size(H,1) size(vals) 11]);

tic
    for i = 1:size(H, 1)
        ml507.H = int16(H(i,:).*32767./max([max(real(H(i,:))) max(imag(H(i,:)))]));
        for j = 1:size(vals, 1)
            for k = 1:size(vals, 2)
                ml507.transmitter.mul = vals(j, k)*32767;
                results(i, j, k, :) = vna.y;
                fprintf('%d/%d\n', (i-1)*size(vals, 1)*size(vals, 2)+(j-1)*size(vals, 2)+k, size(H, 1)*size(vals, 1)*size(vals, 2));
            end
        end
    end
toc

%%

for i = 1:size(results, 1)
    subplot(2,3,i);
    smithchart(reshape(results(i,:,:,:),[size(results,2)*size(results,3) size(results,4)]).');
end