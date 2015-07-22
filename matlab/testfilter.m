ml507 = ML507.ML507();

%%

f = designfilt('lowpassfir','FilterOrder',4096-1,'CutoffFrequency',25e6,'SampleRate',100e6,'Window','hamming');
H = fft(impz(f)).';
ml507.H = int16(H.*32767./max([max(real(H)) max(imag(H))]));

%%

ml507.depth = 20000;
ml507.transmitter.mul = 32767;
ml507.transmitter.shift = 4;
ml507.core.n = 4096;
ml507.core.L = 2000;
ml507.core.scale_sch(1:6) = [2 0 0 0 0 0];
ml507.core.scale_schi(1:6) = [2 1 0 0 0 0];
ml507.core.scale_cmul = 2;
ml507.core.iq = 1;
ml507.core.circular = 1;

%%
