load('vnaAccuracy.mat');

params = dlmread('tuner.s1p','\t',6,0);
freqs = params(:,1);
iabs = interp1(freqs, params(:,2), testfreqs);
iangle = interp1(freqs, params(:,3), testfreqs);

v = mean(results,3);
m = 20*log10(abs(v));
a = 180/pi*angle(v);

mdiff = abs((abs(v) - 10.^(repmat(iabs,4,1)/20))); %./repmat(iabs,4,1))*100;
adiff = abs(a - repmat(iangle,4,1));

merr = std(abs(results),0,3)/sqrt(size(results,3))*1.96;
aerr = std(180/pi*angle(results),0,3)/sqrt(size(results,3))*1.96;

subplot(2,2,1);
plot(mdiff.');
legend(strcat('p=',strtrim(cellstr(num2str(powers.')))));
title('magnitude diff');
subplot(2,2,2);
plot(adiff.');
legend(strcat('p=',strtrim(cellstr(num2str(powers.')))));
title('angle diff');

subplot(2,2,3);
plot(merr.');
legend(strcat('p=',strtrim(cellstr(num2str(powers.')))));
title('magnitude var');
subplot(2,2,4);
plot(aerr.');
legend(strcat('p=',strtrim(cellstr(num2str(powers.')))));
title('angle var');