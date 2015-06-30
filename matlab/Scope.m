classdef Scope < handle
    properties (Access = protected, Hidden = true)
        handle
    end
    
    properties
        chana;
        chanb;
    end
    
    methods
        function obj = Scope(address, a, b)
            obj.chana = a;
            obj.chanb = b;
            obj.handle = visa('agilent', address);
            set(obj.handle,'InputBufferSize', 1e7);
            set(obj.handle,'Timeout', 10);
            fopen(obj.handle);

            %Reset
            fprintf(obj.handle, '*RST');

            %external ref clock
            fprintf(obj.handle, ':TIMEBASE:REFCLOCK ON');

            %Basic settings needed for every measurement
            fprintf(obj.handle, ':SINGLE');
            fprintf(obj.handle, ':TRIGGER:EDGE:SOURCE CHAN%d', a);
            fprintf(obj.handle, ':TRIGGER:EDGE:LEVEL 0V');
            fprintf(obj.handle, ':TRIGGER:EDGE:SLOPE POS');
            fprintf(obj.handle, ':TRIGGER:SWEEP NORMAL');

            fprintf(obj.handle, ':CHANNEL1:IMPEDANCE FIFTY');
            fprintf(obj.handle, ':CHANNEL1:DISPLAY ON');
            fprintf(obj.handle, ':CHANNEL1:OFFSET 0V');
            
            fprintf(obj.handle, ':CHANNEL2:IMPEDANCE FIFTY');
            fprintf(obj.handle, ':CHANNEL2:DISPLAY ON');
            fprintf(obj.handle, ':CHANNEL2:OFFSET 0V');
            
            fprintf(obj.handle, ':WAVEFORM:FORMAT BYTE');
            fprintf(obj.handle, ':WAVEFORM:POINTS:MODE RAW');
            fprintf(obj.handle, ':WAVEFORM:POINTS RAW');
            fprintf(obj.handle, ':ACQUIRE:TYPE NORMAL');
            fprintf(obj.handle, ':ACQUIRE:COMPLETE 100');
        end
        
        function delete(obj)
            fclose(obj.handle);
            delete(obj.handle);
        end
        
        function [xincrement, data] = acquireChan(obj, chan)
            fprintf(obj.handle, ':WAVEFORM:SOURCE CHAN%d', chan);
            preambleBlock = query(obj.handle, ':WAVEFORM:PREAMBLE?');
            fprintf(obj.handle,':WAVEFORM:DATA?');
            data = binblockread(obj.handle);
            fread(obj.handle, 1); %absorb trailing newline; without this
                                  %'COMMAND INTERRUPTED' error occurs
            
            if ismember(0, data)
                throw(MException('Scope::acquireChan:DataHole',...
                    ['Data hole in acquired waveform. This should '...
                    'never happen in single shot']));
            end
            if ismember(255, data) || ismember(1, data)
                throw(MException('Scope::acquireChan:Clipped',...
                    'Data clipped at display border'));
            end
            
            preambleBlock = strsplit(preambleBlock, ',');
            xincrement = str2double(preambleBlock{5});
            yincrement = str2double(preambleBlock{8});
            yorigin = str2double(preambleBlock{9});
            yreference = str2double(preambleBlock{10});
            
            data = (data - yreference)*yincrement + yorigin;
        end
        
        function [xincrement, a, b] = acquireAB(obj, rangea, rangeb, scale)
            %setup
            fprintf(obj.handle, ':CHANNEL1:RANGE %gV', rangea);
            fprintf(obj.handle, ':CHANNEL2:RANGE %gV', rangeb);
            fprintf(obj.handle, ':TIMEBASE:SCALE %gs', scale);
            
            %aqcuire a buffer full of data
            fprintf(obj.handle, ':DIGITIZE CHAN1,CHAN2');

            [xincrement, a] = obj.acquireChan(obj.chana);
            [~, b] = obj.acquireChan(obj.chanb);
        end
        
        function [xincrement, x] = acquireRho(obj, rangea, rangeb, scale)
            [xincrement, a, b] = obj.acquireAB(rangea, rangeb, scale);
            
            a = a - mean(a);
            b = b - mean(b);

            A = fft(a.*hann(length(a)));
            B = fft(b.*hann(length(b)));

            dfa = (1/xincrement)/length(A);
            dfb = (1/xincrement)/length(B);

            [~, inda] = max(abs(A(1:length(A)/2+1)));
            [~, indb] = max(abs(B(1:length(A)/2+1)));

            fa = (inda - 1)*dfa;
            fb = (indb - 1)*dfb;

            x = A(inda)/B(indb);

            diff = angle(B(inda))-angle(A(indb));
            
            fprintf('fa: %.2fMHz fb: %.2fMHz a: %.2f<%.2f b: %.2f<%.2f diff: %.2f a/b: %.2f+j%.2f %.2f<%.2f\n', fa/1e6, fb/1e6, abs(A(inda)), angle(A(inda))/pi*180, abs(B(indb)), angle(B(indb))/pi*180, diff/pi*180, real(x), imag(x), abs(x), angle(x)/pi*180);
        end
    end
    
end

