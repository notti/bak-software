% scope_analyze2.m
%
% (verbesserte Version)

%% init 
oszi.handle = visa('agilent','TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR');
set(oszi.handle,'InputBufferSize',1e7);
set(oszi.handle,'Timeout', 30);
fopen(oszi.handle);

fprintf(oszi.handle, '*CLS');

% measure


fprintf('Reading data from oscilloscope...');
%fprintf(oszi.handle,':RUN');
fprintf(oszi.handle,':STOP');
%fprintf(oszi.handle,':SINGLE');

signal_len = str2double(query(oszi.handle,':ACQUIRE:POINTS?'));
xscale     = str2double(query(oszi.handle,':WAVEFORM:XINCREMENT?'));

fprintf(oszi.handle,':ACQUIRE:TYPE NORMAL');
fprintf(oszi.handle,':ACQUIRE:COMPLETE 100');

fprintf(oszi.handle,':DIG CHAN1,CHAN2');



fprintf(oszi.handle,':WAVEFORM:SOURCE CHAN1');
fprintf(oszi.handle,':WAVEFORM:FORMAT BYTE');
fprintf(oszi.handle,':WAVEFORM:POINTS:MODE RAW');
%fprintf(oszi.handle,':WAVEFORM:POINTS RAW');


fprintf(oszi.handle,':WAVEFORM:DATA?');
a = binblockread(oszi.handle);

fprintf(oszi.handle,':WAVEFORM:SOURCE CHAN2');

fprintf(oszi.handle,':WAVEFORM:DATA?');
b = binblockread(oszi.handle);




xscale     = str2num(query(oszi.handle,':WAVEFORM:XINCREMENT?'));           % hat beim ersten Auslesen oft Probleme!

fprintf('\b\b Done.\n');

if ismember(0, a) || ismember(255, a) || ismember(1, a)
    fprintf('Error in CHAN1');
end

if ismember(0, b) || ismember(255, b) || ismember(1, b)
    fprintf('Error in CHAN2');
end


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

%% cleanup

fprintf(oszi.handle,':RUN');
fclose(oszi.handle);
delete(oszi.handle);
