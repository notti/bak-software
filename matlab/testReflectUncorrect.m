ml507 = ML507();
trig = ZVLTrigger('ASRL1::INSTR');
zvl = ZVL('TCPIP0::128.131.85.229::inst0::INSTR');

%%

f = designfilt('lowpassfir','FilterOrder',4096-1,'CutoffFrequency',25e6,'SampleRate',100e6,'Window','hamming');
H = fft(impz(f)).';
ml507.H = int16(H.*32767./max([max(real(H)) max(imag(H))]));

%%

ml507 = ML507();

zvl.freerun();
zvl.single();

while true
    if ml507.single() ~= 0
        break
    end
    trig.trigger(); trig.wait();
    pause(0.1);
end
