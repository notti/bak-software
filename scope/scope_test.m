oszi = visa('agilent','TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR');
set(oszi,'InputBufferSize',1e7);
set(oszi,'Timeout', 10);
fopen(oszi);

fprintf(oszi,'*RST');
pause(0.1);
fprintf(oszi,':SINGLE');
fprintf(oszi,':TRIGGER:EDGE:SOURCE CHAN1 ');
fprintf(oszi,':TRIGGER:EDGE:LEVEL 0V');
fprintf(oszi,':TRIGGER:EDGE:SLOPE POS');
fprintf(oszi,':TRIGGER:SWEEP NORMAL');
fprintf(oszi,':TIMEBASE:REFCLOCK ON'); %external ref clock

fprintf(oszi,':CHANNEL1:IMPEDANCE FIFTY');
fprintf(oszi,':CHANNEL1:DISPLAY ON');
fprintf(oszi,':CHANNEL2:IMPEDANCE FIFTY');
fprintf(oszi,':CHANNEL2:DISPLAY ON');
fprintf(oszi,':WAVEFORM:FORMAT BYTE');
fprintf(oszi,':WAVEFORM:POINTS:MODE RAW');
fprintf(oszi,':WAVEFORM:POINTS RAW');
fprintf(oszi,':ACQUIRE:TYPE NORMAL');
fprintf(oszi,':ACQUIRE:COMPLETE 100');

%% meas_setup

fprintf(oszi,':CHANNEL1:RANGE 16mV');
fprintf(oszi,':CHANNEL1:OFFSET 0V');
fprintf(oszi,':CHANNEL2:RANGE 16mV');
fprintf(oszi,':CHANNEL2:OFFSET 0V');

fprintf(oszi,':TIMEBASE:SCALE 10us');

%% start 
fprintf(oszi,':DIGITIZE CHAN1,CHAN2');

fprintf(oszi,':WAVEFORM:SOURCE CHAN1');
preambleBlock = query(oszi,':WAVEFORM:PREAMBLE?');
fprintf(oszi,':WAVEFORM:DATA?');
a = binblockread(oszi);
fread(oszi, 1);

fprintf(oszi,':WAVEFORM:SOURCE CHAN2');
preambleBlock = query(oszi,':WAVEFORM:PREAMBLE?');

fprintf(oszi,':WAVEFORM:DATA?');
b = binblockread(oszi);
fread(oszi, 1);

xscale     = str2num(query(oszi,':WAVEFORM:XINCREMENT?'));

%

a = a - mean(a);
b = b - mean(b);

subplot(2,2,1);
plot(a);
subplot(2,2,2);
plot(b);

A = fft(a.*hann(length(a)));
B = fft(b.*hann(length(b)));

dfa = (1/xscale)/length(A);
dfb = (1/xscale)/length(B);

[~, inda] = max(abs(A(1:length(A)/2+1)));
[~, indb] = max(abs(B(1:length(A)/2+1)));

%matlab starts with 1...
fa = (inda - 1)*dfa;
fb = (indb - 1)*dfb;

subplot(2,2,3);
plot(mag2db(abs(A)));
subplot(2,2,4);
plot(mag2db(abs(B)));

x = A(inda)/B(indb);

diff = angle(B(inda))-angle(A(indb));

fprintf('fa: %.2fMHz fb: %.2fMHz a: %.2f<%.2f b: %.2f<%.2f diff: %.2f a/b: %.2f+j%.2f %.2f<%.2f\n', fa/1e6, fb/1e6, abs(A(inda)), angle(A(inda))/pi*180, abs(B(indb)), angle(B(indb))/pi*180, diff/pi*180, real(x), imag(x), abs(x), angle(x)/pi*180);
match_raw(k) = x;
k = k+1
%% cleanup

fclose(oszi);
delete(oszi);