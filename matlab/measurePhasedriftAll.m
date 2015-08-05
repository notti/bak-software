obj1.handle = visa('agilent', 'TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR');
set(obj1.handle,'InputBufferSize', 1e7);
set(obj1.handle,'Timeout', 10);
fopen(obj1.handle);
obj2.handle = visa('agilent', 'USB0::0x0957::0x1755::MY48040122::0::INSTR');
set(obj2.handle,'InputBufferSize', 1e7);
set(obj2.handle,'Timeout', 10);
fopen(obj2.handle);

%%

fprintf(obj1.handle, ':SINGLE');

fprintf(obj1.handle, ':WAVEFORM:FORMAT BYTE');
fprintf(obj1.handle, ':WAVEFORM:POINTS:MODE RAW');
fprintf(obj1.handle, ':WAVEFORM:POINTS RAW');
fprintf(obj1.handle, ':ACQUIRE:TYPE NORMAL');
fprintf(obj1.handle, ':ACQUIRE:COMPLETE 100');

fprintf(obj2.handle, ':SINGLE');
fprintf(obj2.handle, ':WAVEFORM:FORMAT BYTE');
fprintf(obj2.handle, ':WAVEFORM:POINTS:MODE RAW');
fprintf(obj2.handle, ':WAVEFORM:POINTS RAW');
fprintf(obj2.handle, ':ACQUIRE:TYPE NORMAL');
fprintf(obj2.handle, ':ACQUIRE:COMPLETE 100');
%%

fprintf(obj1.handle, ':TIMEBASE:SCALE %gs', 10e-6);
fprintf(obj2.handle, ':TIMEBASE:SCALE %gs', 10e-6);

freqs1 = [900e6, 830e6, 100e6, 10e6];
freqs2 = [10e6, 900e6];

res = [];
data = zeros(1,length(freqs1)+length(freqs2));
j = -1;
x = now;

while true
%    pause(1);
    while now < x + 10/24/3600
        pause((x-now)*24*60*60+10);
    end
    fprintf(obj2.handle, ':DIGITIZE CHAN1,CHAN2');
    fprintf(obj1.handle, ':DIGITIZE CHAN1,CHAN2,CHAN3,CHAN4');
    x = now;
    for i = 1:length(freqs1)
        fprintf(obj1.handle, ':WAVEFORM:SOURCE CHAN%d', i);
        preambleBlock = query(obj1.handle, ':WAVEFORM:PREAMBLE?');
        preambleBlock = strsplit(preambleBlock, ',');
        xincrement = str2double(preambleBlock{5});
        fprintf(obj1.handle,':WAVEFORM:DATA?');
        raw = binblockread(obj1.handle);
        fread(obj1.handle, 1);
        
        dlen = length(raw);
        df = 1/xincrement/dlen;
        data(i) = sum(raw.'.*exp(-2i*pi*freqs1(i)/df*(1:dlen)/dlen));
    end
    for i = 1:length(freqs2)
        fprintf(obj2.handle, ':WAVEFORM:SOURCE CHAN%d', i);
        preambleBlock = query(obj2.handle, ':WAVEFORM:PREAMBLE?');
        preambleBlock = strsplit(preambleBlock, ',');
        xincrement = str2double(preambleBlock{5});
        fprintf(obj2.handle,':WAVEFORM:DATA?');
        raw = binblockread(obj2.handle);
        fread(obj2.handle, 1);
        
        dlen = length(raw);
        df = 1/xincrement/dlen;
        data(i+4) = sum(raw.'.*exp(-2i*pi*freqs2(i)/df*(1:dlen)/dlen));
    end
    res(end+1,:) = [x data];
    
    shift1 = repmat(angle(res(:,5))/freqs1(4),1,4).*repmat(freqs1,size(res,1),1);
    shift2 = repmat(angle(res(:,6))/freqs2(1),1,2).*repmat(freqs2,size(res,1),1);

    corrected = [res(:,1) unwrap(angle(res(:,2:5)))-shift1 unwrap(angle(res(:,6:7)))-shift2];
    corrected(:,[2:4 7]) = rem(corrected(:,[2:4 7]),pi);

    plot(corrected(:,1),corrected(:,[2:4 7])*180/pi);
    legend('vna', 'smiq', 'smgu', 'smbv', 'Location', 'northoutside', 'Orientation', 'horizontal');

%    plot(res(:,1),unwrap(angle(res(:,2:7)))*180/pi,'x-');
%    legend('vna', 'smiq', 'smgu', 'trig1', 'trig2', 'smbv', 'Location', 'northoutside', 'Orientation', 'horizontal');
    %plot(res(:,1),unwrap(angle(res(:,[5 6])))*180/pi,'x-');
    %legend('trig1', 'trig2', 'Location', 'northoutside', 'Orientation', 'horizontal');
    j = j + 1;
    if mod(j, 10) == 0
        save('testdata/phasedriftAll.mat', 'res', 'corrected', 'freqs1', 'freqs2');
    end
    if mod(j, 360) == 0
        sendmail(email, 'phase drift measurement', 'another one just in!', ['testdata/phasedriftAll.mat']);
    end
end