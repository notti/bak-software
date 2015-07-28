ml507 = ML507.ML507('verbose', true);
vna = VNA('GPIB0::16::INSTR', 3);

f = designfilt('lowpassfir','FilterOrder',4096-1,'CutoffFrequency',25e6,'SampleRate',100e6,'Window','hamming');
H_orig = fft(impz(f)).';
ml507.H = int16(H_orig.*32767./max([max(real(H_orig)) max(imag(H_orig))]));

ml507.depth = 20000;
ml507.transmitter.mul = 32767;
ml507.transmitter.shift = 5;
ml507.core.n = 4096;
ml507.core.L = 2000;
ml507.core.scale_sch(1:6) = [2 0 0 0 0 0];
ml507.core.scale_schi(1:6) = [2 1 0 0 0 0];
ml507.core.scale_cmul = 1;
ml507.core.iq = 1;
ml507.core.circular = 1;
ml507.transmitter.resync();
ml507.trigger.arm();
ml507.trigger.fire();

if ~ml507.running
    ml507.run();
end

vna.continuous(201, 100e-3);
vna.freq = 900e6;

%%

findTarget(ml507, 1, @()1/mean(vna.y), 0.1);

i = 1;

x = now;

result = [];
while true
    while now < x + 10/24/3600
        pause((x-now)*24*60*60+10);
    end
    y = mean(vna.y);
    x = now;
    result(end+1,:) = [x mean(vna.y)];
    fprintf('%s %g<%g\n', datestr(x), abs(y), angle(y)*180/pi);
    i = i + 1;
    if mod(i, 10) == 0
        save('testdata/phasedrift.mat', 'result');
    end
end
