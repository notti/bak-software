obj.handle = visa('agilent', 'TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR');
set(obj.handle,'InputBufferSize', 1e7);
set(obj.handle,'Timeout', 10);
fopen(obj.handle);

%%

fprintf(obj.handle, ':SINGLE');

fprintf(obj.handle, ':WAVEFORM:FORMAT BYTE');
fprintf(obj.handle, ':WAVEFORM:POINTS:MODE RAW');
fprintf(obj.handle, ':WAVEFORM:POINTS RAW');
fprintf(obj.handle, ':ACQUIRE:TYPE NORMAL');
fprintf(obj.handle, ':ACQUIRE:COMPLETE 100');

%%

fprintf(obj.handle, ':TIMEBASE:SCALE %gs', 10e-6);

freqs = [900e6, 830e6, 100e6, 900e6];

res = [];
data = zeros(1,4);
j = -1;
x = now;

while true
    while now < x + 10/24/3600
        pause((x-now)*24*60*60+10);
    end
    fprintf(obj.handle, ':DIGITIZE CHAN1,CHAN2,CHAN3,CHAN4');
    x = now;
    for i = 1:4
        fprintf(obj.handle, ':WAVEFORM:SOURCE CHAN%d', i);
        preambleBlock = query(obj.handle, ':WAVEFORM:PREAMBLE?');
        preambleBlock = strsplit(preambleBlock, ',');
        xincrement = str2double(preambleBlock{5});
        fprintf(obj.handle,':WAVEFORM:DATA?');
        raw = binblockread(obj.handle);
        fread(obj.handle, 1);

        dlen = length(raw);
        df = 1/xincrement/dlen;
        data(i) = sum(raw.'.*exp(-2i*pi*freqs(i)/df*(1:dlen)/dlen));
    end
    res(end+1,:) = [x angle(data)];
    plot(res(:,1),unwrap(res(:,2:5))*180/pi,'x-');
    legend('smbv', 'smiq', 'smgu', 'vna', 'Location', 'northoutside', 'Orientation', 'horizontal');
    j = j + 1;
    if mod(j, 10) == 0
        save('testdata/phasedriftAll.mat', 'res');
    end
    if mod(j, 60) == 0
        sendmail(email, 'phase drift measurement', 'another one just in!', ['testdata/phasedriftAll.mat']);
    end
end