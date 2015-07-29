ml507 = ML507.ML507();
oszi = Scope('TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR', 2, 1);
smbv = SMBV('TCPIP0::128.131.85.233::inst0::INSTR');

%%

span = 25e6;
center = 900e6;
resa = 50e-3;
resb = 50e-3;

%single carrier
ml507.out_inactive = ones(1, 20000)*32767;
ml507.transmitter.toggle();
ml507.transmitter.shift = 2;
ml507.transmitter.mul=32767;
smbv.pow = 0;

%get frequencyresolution of data and calculate frequencies on the grid for
%the given range
[xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);

dfreq = 1/xincrement/length(a);

start = floor((center - span/2)/dfreq);
stop = ceil((center + span/2)/dfreq);
step = floor((stop-start)/21);

freqs = start:step:stop;
if freqs(end) ~= stop
    freqs(end+1) = stop;
end

freqs = freqs.*dfreq;

%measure open short match
data = zeros([3 length(freqs)]);
msg = {'open' 'short' 'match'};
N = 10;

for which = 1:3
    fprintf('connect %s and press <enter>', cell2mat(msg(which)));
    pause();
    fprintf('\n');
    for i = 1:numel(freqs)
        smbv.freq = freqs(i);
        tmp = zeros(1, N);
        for j = 1:N
            [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
            tmp(j) = manyRho(xincrement, a, b, freqs(i));
        end
        data(which, i) = mean(tmp);
    end
end

fprintf('done.\n');

%%

%now interpolate data, to cover every possible frequency point
freqs_interp = (start:stop).*dfreq;

dataa = zeros(3, length(freqs_interp));
datam = zeros(3, length(freqs_interp));
datap = zeros(3, length(freqs_interp));

%split into magnitude and angle for interpolation.
%linear interpolation of the complex values would result in magnitude
%errors caused by possible phase jumps
for i = 1:3
    dataa(i,:) = interp1(freqs, unwrap(angle(data(i,:))), freqs_interp, 'linear');
    datam(i,:) = interp1(freqs, abs(data(i,:)), freqs_interp, 'linear');
    datap(i,:) = datam(i,:) .* exp(1i*dataa(i,:));
end


% calculate error box with interpolated calibration data
[open, short, match] = arrayfun(@(x) calcZ132(x, 'female'), freqs_interp);
[S11, S12, S22] = arrayfun(@calcErrorBoxM, datap(1,:), datap(2,:), datap(3,:), open, short, match);

%%

resa = 50e-3;
resb = 50e-3;

N=100;
testfreqs = reshape([freqs(1:end-1);freqs(1:end-1)+dfreq/2;freqs(1:end-1)+(step/2*dfreq)],1,length(freqs)*3-3);
testfreqs(end) = freqs(end);
powers = -15:5:0;

results = zeros(length(powers), length(testfreqs), N);

for i = 1:length(powers)
    p = powers(i);
    smbv.pow = p;
    for j = 1:length(testfreqs)
        f = testfreqs(j);
        nf = floor(f/dfreq)-start+1;
        smbv.freq = f;
        fprintf('%gdbm %gHz ', p, f);
        tic
        for k = 1:N
            [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
            x = manyRho(xincrement, a, b, f);
            results(i,j,k) = calcGl(S11(nf), S12(nf), S22(nf), x);
            fprintf('.');
        end
        save('testdata/vnaAccuracy.mat', 'results', 'testfreqs', 'powers');
        fprintf('\n');
        toc
        sendmail(email, 'messung', 'reflect', ['testdata/vnaAccuracy.mat']);
    end
end


%%

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
ml507.run();

%%

oszi.trigger_chan = 1;
vna.continuous(201, 100e-3);
resa = 50e-3;
resb = 50e-3;

N=100;
testfreqs = reshape([freqs;freqs+dfreq/2;freqs+(step/2*dfreq)],1,length(freqs)*3);
[X, Y] = meshgrid(logspace(log10(1), log10(0.1), 10),[1 -1 1i]);
targets = reshape(X.*Y, 1, numel(X));

results = zeros(length(targets), length(testfreqs), N, 2);

for t = 1:length(targets)
    target = targets(t);
    for i = 1:length(testfreqs)
        f = testfreqs(i);
        nf = floor(f/dfreq)-start+1;
        vna.freq = f;
        fprintf('%gHz ', f);
        mul = 32767;
        for j = 1:N
            [Gl, mul] = findTarget(ml507, target, @()1/mean(vna.y), 0.1, mul);
            [xincrement, a, b] = oszi.acquireAB(resa,resb,10e-6);
            results(t, i, j, 1) = Gl;
            x=manyRho(xincrement, a, b, f);
            Gl = 1/calcGl(S11(nf), S12(nf), S22(nf), x);
            results(t, i, j, 2) = Gl;
            fprintf('.');
        end
        save('testdata/vnaAccuracy.mat', 'results', 'testfreqs', 'targets');
        fprintf('\n');
    end
end

