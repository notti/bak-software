% scope_analyze2.m
%
% (verbesserte Version)

%% init 
oszi.handle = visa('agilent','TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR');
set(oszi.handle,'InputBufferSize',1e7);
set(oszi.handle,'Timeout',120);
fopen(oszi.handle);

%% measure


fprintf('Reading data from oscilloscope...');
fprintf(oszi.handle,':STOP');
fprintf(oszi.handle,'WAVEFORM:SOURCE CHAN1');
signal_len = str2double(query(oszi.handle,':ACQUIRE:POINTS?'));
xscale     = str2double(query(oszi.handle,':WAVEFORM:XINCREMENT?'));

fprintf(oszi.handle,':WAVEFORM:FORMAT BYTE');
fprintf(oszi.handle,':WAVEFORM:POINTS:MODE RAW');
fprintf(oszi.handle,':WAVEFORM:POINTS RAW');

fprintf(oszi.handle,':DIG');

fprintf(oszi.handle,':WAVEFORM:DATA?');
y = binblockread(oszi.handle);

xscale     = str2num(query(oszi.handle,':WAVEFORM:XINCREMENT?'));           % hat beim ersten Auslesen oft Probleme!

fprintf('\b\b Done.\n');


plot(y);

y = y - mean(y);

Y = fft(y.*hann(length(y)));

df = (1/xscale)/length(y);

[~, ind] = max(Y);

(length(Y) - ind + 1)*df

%% cleanup
fclose(oszi.handle);
delete(oszi.handle);
