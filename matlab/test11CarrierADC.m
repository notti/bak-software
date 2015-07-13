%load('testdata/11CarrierADC.mat');

Nf = 4096;
L = 2240;
Nh = Nf-L+1;

t = (1/100e6*(1:length(x))).';
iqdemod = x.*(sin(2*pi*t*30e6)+1i*cos(2*pi*t*30e6));

%subplot(4,1,1);
%plot(20*log10(abs(fftshift(fft(x)))));
%subplot(4,1,2);
%plot(20*log10(abs(fftshift(fft(iqdemod)))));

%% filter

f = designfilt('lowpassfir','FilterOrder',Nf-1,'CutoffFrequency',25e6,'SampleRate',100e6,'Window','hamming');
iqdemod_filtered = filter(f, iqdemod);
%subplot(2,1,1);
plot(20*log10(abs(fftshift(fft(iqdemod_filtered)))));

%% conv

Nx = length(x);
Nx1 = L*ceil(Nx/L);

%H = [fft(impz(f)).' zeros(1,Nf-L)];
H=fft(impz(f)).';
iqdemod_extended = [iqdemod.' zeros(1,Nx1 - Nx)];
y = zeros(1,Nx1+Nh-1);
for m= 1:L:Nx-L+1;
    y1 = ifft(fft(iqdemod_extended(m:m+L-1),Nf).*H);
    y(m:m+Nf-1)=y(m:m+Nf-1)+y1;
end
y(1:Nf-L-1) = y(1:Nf-L-1) + y(Nx+1:Nx+Nf-L-1);
y = y(1:length(iqdemod));
%subplot(2,1,2);
hold on;
plot(20*log10(abs(fftshift(fft(y)))),'g');
